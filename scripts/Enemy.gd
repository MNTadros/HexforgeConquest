extends CharacterBody3D

# Core enemy properties
@export var speed: float = 2.0
@export var follow_distance: float = 15.0
@export var attack_distance: float = 2.0
@export var damage: float = 15.0
@export var attack_cooldown: float = 1.5
@export var max_health: float = 70.0

# Internal variables
var current_health: float
var player: CharacterBody3D = null
var attack_timer: float = 0.0
var is_dead: bool = false

# Node references
@onready var navigation_agent = $NavigationAgent3D
@onready var attack_area = $AttackArea
@onready var health_bar = $HealthBar3D
@onready var skeleton_model = $SkeletonModel
@onready var animation_player = null

# Animation system
enum AnimationState { IDLE, WALKING, ATTACKING, DYING }
var current_animation_state = AnimationState.IDLE

func _ready():
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	# Setup navigation and attack area
	navigation_agent.target_desired_distance = attack_distance
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	
	# Initialize animations and health bar
	setup_animations()
	update_health_bar()

func setup_animations():
	# Find AnimationPlayer in skeleton model
	animation_player = find_animation_player_recursive(skeleton_model)
	
	if animation_player != null:
		play_animation(AnimationState.IDLE)
	else:
		print("No AnimationPlayer found - animations disabled")

func find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = find_animation_player_recursive(child)
		if result != null:
			return result
	return null

func play_animation(state: AnimationState):
	# Don't interrupt attack or death animations
	if current_animation_state == AnimationState.ATTACKING and state != AnimationState.DYING:
		return
	if current_animation_state == AnimationState.DYING:
		return
	
	if animation_player == null:
		return
	
	var anim_name = ""
	match state:
		AnimationState.IDLE:
			anim_name = get_available_animation(["Idle", "Unarmed_Idle"])
		AnimationState.WALKING:
			anim_name = get_available_animation(["Walking_A", "Walking_B", "Running_A"])
		AnimationState.ATTACKING:
			anim_name = get_available_animation(["1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A"])
		AnimationState.DYING:
			anim_name = get_available_animation(["Death_A", "Death_B"])
	
	if anim_name != "":
		current_animation_state = state
		animation_player.play(anim_name)

func get_available_animation(names: Array) -> String:
	if animation_player == null:
		return ""
	
	var available_animations = animation_player.get_animation_list()
	for name in names:
		if name in available_animations:
			return name
	return ""

func _physics_process(delta):
	if is_dead:
		return
	
	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0
	
	# Follow player if in range
	if player != null and not player.is_dead:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player <= follow_distance:
			move_towards_player(delta)
		else:
			stop_moving(delta)
	else:
		stop_moving(delta)
	
	move_and_slide()

func move_towards_player(delta):
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	# Face the player
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
	
	# Play walking animation
	if current_animation_state != AnimationState.WALKING:
		play_animation(AnimationState.WALKING)

func stop_moving(delta):
	velocity.x = 0
	velocity.z = 0
	
	# Play idle animation
	if current_animation_state != AnimationState.IDLE:
		play_animation(AnimationState.IDLE)

func _on_attack_area_body_entered(body):
	if body == player and not is_dead:
		print("Player entered attack range")

func _on_attack_area_body_exited(body):
	if body == player:
		print("Player left attack range")

func attack_player():
	if player == null or is_dead or attack_timer > 0:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= attack_distance:
		# Play attack animation and deal damage
		play_animation(AnimationState.ATTACKING)
		
		if player.has_method("take_damage"):
			player.take_damage(damage)
			
			# Report damage dealt to game manager
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			if game_manager:
				game_manager.add_damage_dealt(damage)
		
		attack_timer = attack_cooldown
		
		# Wait for attack animation, then return to movement
		if animation_player != null:
			var attack_anim = get_available_animation(["1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A"])
			if attack_anim != "":
				var duration = animation_player.get_animation(attack_anim).length
				await get_tree().create_timer(duration * 0.8).timeout
		
		# Reset state and resume movement
		current_animation_state = AnimationState.IDLE

func take_damage(amount: float):
	if is_dead:
		return
	
	current_health = max(0, current_health - amount)
	update_health_bar()
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector3.ZERO
	
	# Drop resources before reporting kill
	drop_resources()
	
	# Report kill to game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.add_enemy_kill()
	
	# Play death animation
	play_animation(AnimationState.DYING)
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	
	# Wait for death animation, then remove
	var death_duration = 2.0
	if animation_player != null:
		var death_anim = get_available_animation(["Death_A", "Death_B"])
		if death_anim != "":
			death_duration = animation_player.get_animation(death_anim).length
	
	await get_tree().create_timer(death_duration).timeout
	queue_free()

func drop_resources():
	# Define possible resource drops
	var resource_types = [
		"Grass Item",
		"Plains Item", 
		"Wheat Item",
		"Water Item",
		"Iron"
	]
	
	# Define resource icons (matching the player's TILE_ITEM_ICONS)
	var resource_icons = {
		"Grass Item": "res://images/icons/grass_icon.png",
		"Plains Item": "res://images/icons/plains_icon.png",
		"Wheat Item": "res://images/icons/wheat_icon.png", 
		"Water Item": "res://images/icons/water_icon.png",
		"Iron": "res://images/icons/blacksmith_icon.png"
	}
	
	# Find the player to add resources to their inventory
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		print("No player found - cannot drop resources")
		return
	
	# Get the player's HUD for inventory access
	var hud = null
	var main_scene = get_tree().current_scene
	if main_scene:
		hud = main_scene.get_node_or_null("HUD")
	
	if hud == null:
		print("No HUD found - cannot drop resources")
		return
	
	# Randomly drop 1-4 resources
	var num_drops = randi_range(1, 4)
	print("Skeleton dropping ", num_drops, " resources")
	
	var total_message = "Skeleton dropped: "
	var dropped_items = []
	
	for i in range(num_drops):
		# Pick a random resource type
		var resource_type = resource_types[randi() % resource_types.size()]
		var resource_icon = resource_icons.get(resource_type, "")
		
		# Add to player's inventory
		var success = hud.add_item_to_inventory(resource_type, resource_icon, 1)
		if success:
			dropped_items.append(resource_type)
			print("Dropped: ", resource_type)
		else:
			print("Failed to drop: ", resource_type, " (inventory full?)")
	
	# Show a collection popup with all dropped items
	if dropped_items.size() > 0 and hud.has_method("show_collection_popup"):
		if dropped_items.size() == 1:
			total_message += dropped_items[0]
		elif dropped_items.size() == 2:
			total_message += dropped_items[0] + " and " + dropped_items[1]
		else:
			for j in range(dropped_items.size()):
				if j == dropped_items.size() - 1:
					total_message += "and " + dropped_items[j]
				else:
					total_message += dropped_items[j] + ", "
		
		hud.show_collection_popup(total_message, Color.GOLD)

func update_health_bar():
	if health_bar == null:
		return
	
	var health_percentage = current_health / max_health
	health_bar.scale.x = health_percentage
	
	# Update health bar color
	var material = health_bar.get_surface_override_material(0)
	if material == null:
		material = StandardMaterial3D.new()
		health_bar.set_surface_override_material(0, material)
	
	if health_percentage > 0.6:
		material.albedo_color = Color.GREEN
	elif health_percentage > 0.3:
		material.albedo_color = Color.YELLOW
	else:
		material.albedo_color = Color.RED

func _on_timer_timeout():
	# Attack if player is in range
	if player != null and not is_dead:
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_distance:
			attack_player()
