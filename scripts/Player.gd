extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 14.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var max_slope_angle: float = 50.0
@export var floor_snap: float = 0.6

@export var hud_node_path: NodePath

# Player movement and resource collection
var max_health = 100.0
var max_stamina = 100.0

# Current health and stamina values
var current_health = 100.0
var current_stamina = 100.0

# Stamina and health costs/regen rates
var stamina_jump_cost = 20.0
var stamina_regen_rate = 15.0
var health_regen_rate = 2.0

# Track for unstuck functionality
var last_position = Vector3.ZERO
var unstuck_cooldown = 0.0

# Resource collection cooldowns for manual collection (inventory items)
var manual_collection_cooldowns = {}

# Collision indicators for blacksmith buildings
var collision_indicators = []
var blacksmith_buildings = []
var collision_visibility_distance = 5.0  # Distance at which collision indicators become visible

# Equipment System - Clean and Simple
var current_weapon_model = null  # Currently equipped weapon model
var current_weapon_type = ""     # Currently equipped weapon filename

# Death and respawn variables
var is_dead: bool = false
var respawn_timer: float = 0.0
var respawn_cooldown: float = 10.0
var spawn_position: Vector3

@onready var ground_ray = $RayCast3D
@onready var head = $Head
var hud = null

var pitch := 0.0
var tile_times: Dictionary = {}
var tile_collect_cooldown: Dictionary = {}  # Track cooldown timers for manual collection
var current_tile: String = ""

const MAX_TILE_TIME := 100.0  # Tile bar currency maxes at 100
const MANUAL_COLLECT_REQUIREMENT := 6.0  # Manual collection requires 6 seconds
const MANUAL_COLLECT_COOLDOWN := 6.0  # Cooldown between manual collections

const TILE_TYPES := {
	"HexTile_Grass": Color(0.3, 0.8, 0.3),
	"HexTile_Plains": Color(0.8, 0.8, 0.3),
	"HexTile_Wheat": Color(0.9, 0.7, 0.2),
	"HexTile_Water": Color(0.2, 0.4, 0.9),
	"HexTile_BlacksmithBuilding": Color(0.8, 0.4, 0.2),
}

const TILE_ITEM_ICONS := {
	"HexTile_Grass": "res://images/icons/grass_icon.png",
	"HexTile_Plains": "res://images/icons/plains_icon.png", 
	"HexTile_Wheat": "res://images/icons/wheat_icon.png",
	"HexTile_Water": "res://images/icons/water_icon.png",
	"HexTile_BlacksmithBuilding": "res://images/icons/blacksmith_icon.png",
}

func _ready():
	# Add player to group for easy detection by enemies
	add_to_group("player")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = floor_snap
	
	current_health = max_health
	current_stamina = max_stamina
	spawn_position = global_position
	
	for tile_type in TILE_TYPES.keys():
		tile_times[tile_type] = 0.0
		tile_collect_cooldown[tile_type] = 0.0  # Start with no cooldown
	
	# Create red collision visualization for blacksmith buildings
	create_blacksmith_collision_indicators()
	
	var main_scene = get_tree().current_scene
	if main_scene:
		hud = main_scene.get_node_or_null("HUD")
		
		if hud != null:
			await get_tree().process_frame
			hud.update_tiles(tile_times)
			hud.update_health(current_health, max_health)
			hud.update_stamina(current_stamina, max_stamina)
			
			# Add starting resources for testing (100 of each)
			hud.add_item_to_inventory("Grass Item", TILE_ITEM_ICONS.get("HexTile_Grass", ""), 100)
			hud.add_item_to_inventory("Plains Item", TILE_ITEM_ICONS.get("HexTile_Plains", ""), 100)
			hud.add_item_to_inventory("Wheat Item", TILE_ITEM_ICONS.get("HexTile_Wheat", ""), 100)
			hud.add_item_to_inventory("Water Item", TILE_ITEM_ICONS.get("HexTile_Water", ""), 100)
			print("Added 100 of each resource for testing")
			
func _input(event):
	if is_dead:
		return
	
	# Check if crafting menu is open - only block player movement, allow UI input
	if hud != null and hud.crafting_menu != null and hud.crafting_menu.visible:
		# Block specific player input actions, but allow UI input to pass through
		if event.is_action_pressed("move_forward") or event.is_action_pressed("move_back") or \
		   event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or \
		   event.is_action_pressed("move_backward") or event.is_action_pressed("jump") or \
		   event.is_action_pressed("unstuck") or event.is_action_pressed("collect_resource") or \
		   event.is_action_pressed("open_crafting") or \
		   (event.is_action_pressed("use_item_1") or event.is_action_pressed("use_item_2") or \
			event.is_action_pressed("use_item_3") or event.is_action_pressed("use_item_4") or \
			event.is_action_pressed("use_item_5") or event.is_action_pressed("use_item_6") or \
			event.is_action_pressed("use_item_7") or event.is_action_pressed("use_item_8") or \
			event.is_action_pressed("use_item_9")) or \
		   event is InputEventMouseMotion:
			return  # Block player actions and mouse look when crafting menu is open
		# Allow all other input (UI input) to pass through to the crafting menu
		return
		
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	
	if event.is_action_pressed("unstuck"):
		take_damage(current_health)
	
	if event.is_action_pressed("collect_resource"):
		print("R key pressed - attempting to collect resource")
		collect_resource_from_current_tile()
	
	if event.is_action_pressed("open_crafting"):
		print("C key pressed - attempting to open crafting")
		if current_tile == "HexTile_BlacksmithBuilding":
			if hud != null and hud.has_method("show_crafting_menu"):
				hud.show_crafting_menu()
		else:
			if hud != null and hud.has_method("show_collection_popup"):
				hud.show_collection_popup("Find a Blacksmith Building to craft!", Color.YELLOW)
	
	if event.is_action_pressed("equip_weapon"):
		print("T key pressed - equipping first available weapon")
		equip_first_available_weapon()
	
	if event.is_action_pressed("unequip_weapon"):
		print("Y key pressed - unequipping current weapon")
		if current_weapon_model != null:
			unequip_weapon()
			if hud != null:
				hud.show_collection_popup("Weapon unequipped!", Color.ORANGE)
		else:
			if hud != null:
				hud.show_collection_popup("No weapon equipped!", Color.YELLOW)
	
	# Test enemy spawning (F key)
	if event.is_action_pressed("ui_accept") and Input.is_action_pressed("ui_cancel"):
		print("F key pressed - spawning test enemy")
		spawn_test_enemy()
	
	for i in range(9):
		if Input.is_action_just_pressed("use_item_" + str(i + 1)):
			use_item_from_slot(i)
	
	if not get_tree().paused and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = pitch

func _toggle_pause():
	if get_tree().paused:
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if hud != null:
			hud.show_pause_menu(false)
	else:
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if hud != null:
			hud.show_pause_menu(true)

func _physics_process(delta):
	if get_tree().paused:
		return
	
	# Check if crafting menu is open - if so, don't process movement
	if hud != null and hud.crafting_menu != null and hud.crafting_menu.visible:
		return
	
	if is_dead:
		respawn_timer -= delta
		if hud != null:
			hud.show_death_screen(true, respawn_timer)
		
		if respawn_timer <= 0.0:
			respawn_player()
		return
	
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x

	input_dir.y = 0
	input_dir = input_dir.normalized()

	var current_horizontal = velocity
	current_horizontal.y = 0

	var target_horizontal = input_dir * speed
	var accel_rate = acceleration if input_dir != Vector3.ZERO else deceleration
	current_horizontal = current_horizontal.lerp(target_horizontal, accel_rate * delta)

	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.z

	if ground_ray.is_colliding():
		var collider = ground_ray.get_collider()
		if collider:
			var tile_name = collider.name
			if tile_name in TILE_TYPES:
				current_tile = tile_name
				if not tile_times.has(tile_name):
					tile_times[tile_name] = 0.0
					tile_collect_cooldown[tile_name] = 0.0
				
				tile_times[tile_name] = clamp(tile_times[tile_name] + delta, 0, MAX_TILE_TIME)
	else:
		current_tile = ""
	
	# Update all tile collection cooldowns
	for tile_name in tile_collect_cooldown.keys():
		if tile_collect_cooldown[tile_name] > 0.0:
			tile_collect_cooldown[tile_name] = max(0.0, tile_collect_cooldown[tile_name] - delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and current_stamina >= stamina_jump_cost:
		velocity.y = jump_velocity
		current_stamina -= stamina_jump_cost
		if hud != null:
			hud.update_stamina(current_stamina, max_stamina)
	else:
		velocity.y = -0.01

	move_and_slide()

	if current_stamina < max_stamina:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
		if hud != null:
			hud.update_stamina(current_stamina, max_stamina)

	if current_health < max_health:
		current_health = min(max_health, current_health + health_regen_rate * delta)
		if hud != null:
			hud.update_health(current_health, max_health)

	if hud != null:
		hud.update_tiles(tile_times)
	
	# Update collision indicator visibility based on distance
	update_collision_indicator_visibility()

# Health functions
func take_damage(amount: float):
	current_health = max(0, current_health - amount)
	if hud != null:
		hud.update_health(current_health, max_health)
	
	# Report damage taken to game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.add_damage_taken(amount)
	
	if current_health <= 0:
		die()

func heal(amount: float):
	current_health = min(max_health, current_health + amount)
	if hud != null:
		hud.update_health(current_health, max_health)

func die():
	if is_dead:
		return
		
	is_dead = true
	respawn_timer = respawn_cooldown
	velocity = Vector3.ZERO
	
	if hud != null:
		hud.show_death_screen(true, respawn_timer)

func respawn_player():
	is_dead = false
	respawn_timer = 0.0
	current_health = max_health
	current_stamina = max_stamina
	global_position = spawn_position
	
	if hud != null:
		hud.show_death_screen(false, 0.0)
		hud.update_health(current_health, max_health)
		hud.update_stamina(current_stamina, max_stamina)

func use_item(item_type: String, amount: int = 1) -> bool:
	if hud == null:
		return false
	
	var item_count = hud.get_item_count(item_type)
	if item_count >= amount:
		hud.remove_item_from_inventory(item_type, amount)
		return true
	
	return false

func use_item_from_slot(slot_index: int):
	if hud == null or slot_index < 0 or slot_index >= 9:
		return
	
	if slot_index < len(hud.inventory_slots):
		var slot_data = hud.inventory_slots[slot_index]
		if slot_data.item_count > 0:
			var item_type = slot_data.item_type
			
			# Check if this is an equipment item that can be equipped/unequipped
			if is_weapon_type(item_type):
				toggle_weapon_equipment(item_type)
				return  # Don't consume equipment items
			
			# Apply item effects for consumable items only
			match item_type:
				"Health Potion":
					print("Using Health Potion - restoring 50 health")
					heal(50.0)
					if hud != null:
						hud.show_collection_popup("Used Health Potion! (+50 HP)", Color.GREEN)
				"Stamina Elixir":
					print("Using Stamina Elixir - restoring 75 stamina")
					current_stamina = min(max_stamina, current_stamina + 75.0)
					if hud != null:
						hud.update_stamina(current_stamina, max_stamina)
						hud.show_collection_popup("Used Stamina Elixir! (+75 Stamina)", Color.BLUE)
				"Wooden Arrow":
					# Arrows are consumable but don't have an immediate effect
					if hud != null:
						hud.show_collection_popup("Used Wooden Arrow! (For ranged combat)", Color.CYAN)
				"Arrow Bundle":
					# Arrow bundles are consumable but don't have an immediate effect
					if hud != null:
						hud.show_collection_popup("Used Arrow Bundle! (For ranged combat)", Color.CYAN)
				_:
					# Default behavior for other consumable items
					if hud != null:
						hud.show_collection_popup("Used " + item_type + "!", Color.YELLOW)
			
			# Remove the item from inventory (only for consumables)
			use_item(item_type, 1)

func collect_resource_from_current_tile():
	print("Collect resource called - Current tile: ", current_tile)
	
	# Check if player is actually on a tile
	if current_tile == "" or hud == null:
		print("Cannot collect: current_tile is empty or hud is null")
		if hud != null:
			hud.show_collection_popup("No tile detected!", Color.RED)
		return
	
	# Check if the tile type is valid for collection
	if not current_tile in TILE_TYPES:
		print("Cannot collect: invalid tile type")
		if hud != null:
			hud.show_collection_popup("Invalid tile!", Color.RED)
		return
	
	var tile_time = tile_times.get(current_tile, 0.0)
	var cooldown_time = tile_collect_cooldown.get(current_tile, 0.0)
	print("Tile time for ", current_tile, ": ", tile_time, " / ", MAX_TILE_TIME)
	print("Collection cooldown: ", cooldown_time, "s remaining")
	
	# Manual collection requires 6 seconds, regardless of tile bar max (100)
	var tile_has_resource = tile_time >= MANUAL_COLLECT_REQUIREMENT
	var cooldown_ready = cooldown_time <= 0.0
	
	if not tile_has_resource:
		print("Cannot collect: tile time not enough (", tile_time, " < ", MANUAL_COLLECT_REQUIREMENT, ")")
		var time_remaining = MANUAL_COLLECT_REQUIREMENT - tile_time
		if hud != null:
			hud.show_collection_popup("Still searching... " + str(int(time_remaining)) + "s left", Color.YELLOW)
		return
	
	if not cooldown_ready:
		print("Cannot collect: manual collection on cooldown")
		if hud != null:
			hud.show_collection_popup("Cooldown active! " + str(int(cooldown_time)) + "s remaining", Color.ORANGE)
		return
	
	print("Collecting resource from ", current_tile)
	
	# Apply tile-specific effects and add items to inventory
	match current_tile:
		"HexTile_Grass":
			# Grass: Remove health
			print("Collecting grass - removing 20 health")
			take_damage(20.0)
			if hud != null:
				var success = hud.add_item_to_inventory("Grass Item", TILE_ITEM_ICONS.get("HexTile_Grass", ""), 1)
				print("Added grass item to inventory: ", success)
				hud.show_collection_popup("Collected Grass! (-20 HP)", Color.GREEN)
		
		"HexTile_Plains":
			# Plains: Remove stamina
			print("Collecting plains - removing 30 stamina")
			current_stamina = max(0, current_stamina - 30.0)
			if hud != null:
				hud.update_stamina(current_stamina, max_stamina)
				var success = hud.add_item_to_inventory("Plains Item", TILE_ITEM_ICONS.get("HexTile_Plains", ""), 1)
				print("Added plains item to inventory: ", success)
				hud.show_collection_popup("Collected Plains! (-30 Stamina)", Color.GREEN)
		
		"HexTile_Wheat":
			# Wheat: Restore stamina
			print("Collecting wheat - restoring 40 stamina")
			current_stamina = min(max_stamina, current_stamina + 40.0)
			if hud != null:
				hud.update_stamina(current_stamina, max_stamina)
				var success = hud.add_item_to_inventory("Wheat Item", TILE_ITEM_ICONS.get("HexTile_Wheat", ""), 1)
				print("Added wheat item to inventory: ", success)
				hud.show_collection_popup("Collected Wheat! (+40 Stamina)", Color.GREEN)
		
		"HexTile_Water":
			# Water: Restore health
			print("Collecting water - restoring 30 health")
			heal(30.0)
			if hud != null:
				var success = hud.add_item_to_inventory("Water Item", TILE_ITEM_ICONS.get("HexTile_Water", ""), 1)
				print("Added water item to inventory: ", success)
				hud.show_collection_popup("Collected Water! (+30 HP)", Color.GREEN)
		
		"HexTile_BlacksmithBuilding":
			# Blacksmith Building: Collect iron
			print("Collecting iron from blacksmith building")
			if hud != null:
				var success = hud.add_item_to_inventory("Iron", TILE_ITEM_ICONS.get("HexTile_BlacksmithBuilding", ""), 1)
				print("Added iron to inventory: ", success)
				hud.show_collection_popup("Collected Iron! (Press C to craft)", Color.GREEN)
	
	# Report resource collected to game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.add_resource_collected()
	
	# Set cooldown timer for this tile
	tile_collect_cooldown[current_tile] = MANUAL_COLLECT_COOLDOWN
	print("Started ", MANUAL_COLLECT_COOLDOWN, "s cooldown for ", current_tile)
	
	# Update HUD with new tile times
	if hud != null:
		hud.update_tiles(tile_times)

# Function to create red collision visualization for blacksmith buildings
func create_blacksmith_collision_indicators():
	# Find all blacksmith building nodes in the scene
	var buildings = get_tree().get_nodes_in_group("blacksmith_buildings")
	if buildings.is_empty():
		# If no group exists, search by name pattern
		buildings = find_nodes_by_pattern("HexTile_BlacksmithBuilding")
	
	for building in buildings:
		if building is StaticBody3D or building is RigidBody3D or building is CharacterBody3D:
			blacksmith_buildings.append(building)
			create_red_collision_indicator(building)

func find_nodes_by_pattern(pattern: String) -> Array:
	var found_nodes = []
	# Search through all nodes in the scene
	_search_nodes_recursive(get_tree().current_scene, pattern, found_nodes)
	return found_nodes

func _search_nodes_recursive(node: Node, pattern: String, found_nodes: Array):
	if node.name.contains(pattern):
		found_nodes.append(node)
	
	for child in node.get_children():
		_search_nodes_recursive(child, pattern, found_nodes)

func create_red_collision_indicator(body_node: Node3D):
	# Find collision shapes in the body
	for child in body_node.get_children():
		if child is CollisionShape3D:
			var collision_shape = child as CollisionShape3D
			var shape = collision_shape.shape
			
			if shape != null:
				# Create a MeshInstance3D to visualize the collision
				var mesh_instance = MeshInstance3D.new()
				var material = StandardMaterial3D.new()
				material.albedo_color = Color.RED
				material.flags_transparent = true
				material.albedo_color.a = 0.3  # Semi-transparent
				material.flags_unshaded = true
				material.no_depth_test = true
				
				# Create appropriate mesh based on collision shape type
				var mesh: Mesh
				if shape is BoxShape3D:
					var box_mesh = BoxMesh.new()
					var box_shape = shape as BoxShape3D
					box_mesh.size = box_shape.size
					mesh = box_mesh
				elif shape is SphereShape3D:
					var sphere_mesh = SphereMesh.new()
					var sphere_shape = shape as SphereShape3D
					sphere_mesh.radius = sphere_shape.radius
					sphere_mesh.height = sphere_shape.radius * 2
					mesh = sphere_mesh
				elif shape is CapsuleShape3D:
					var capsule_mesh = CapsuleMesh.new()
					var capsule_shape = shape as CapsuleShape3D
					capsule_mesh.radius = capsule_shape.radius
					capsule_mesh.height = capsule_shape.height
					mesh = capsule_mesh
				else:
					# For other shapes, create a simple box
					var box_mesh = BoxMesh.new()
					box_mesh.size = Vector3(1, 1, 1)
					mesh = box_mesh
				
				mesh_instance.mesh = mesh
				mesh_instance.material_override = material
				mesh_instance.position = collision_shape.position
				mesh_instance.rotation = collision_shape.rotation
				mesh_instance.scale = collision_shape.scale
				
				# Start invisible - will be shown when player is close
				mesh_instance.visible = false
				
				# Add the red indicator to the body
				body_node.add_child(mesh_instance)
				
				# Store reference to the indicator with its parent building
				collision_indicators.append({"indicator": mesh_instance, "building": body_node})
				print("Created red collision indicator for: ", body_node.name)

# Function to update collision indicator visibility based on distance to player
func update_collision_indicator_visibility():
	for indicator_data in collision_indicators:
		var building = indicator_data["building"]
		var indicator = indicator_data["indicator"]
		
		# Check if building and indicator are still valid
		if not is_instance_valid(building) or not is_instance_valid(indicator):
			continue
			
		# Calculate distance between player and building
		var distance = global_position.distance_to(building.global_position)
		
		# Show indicator if player is close enough, hide if too far
		indicator.visible = distance <= collision_visibility_distance

# =======================================
# EQUIPMENT SYSTEM - CLEAN AND SIMPLE
# =======================================

# Weapon type definitions
const WEAPON_TYPES = [
	"Dagger", "One-Handed Sword", "Two-Handed Sword", 
	"One-Handed Axe", "Two-Handed Axe", "Staff", 
	"Wand", "One-Handed Crossbow", "Two-Handed Crossbow"
]

const WEAPON_FILE_MAP = {
	"Dagger": "dagger",
	"One-Handed Sword": "sword_1handed", 
	"Two-Handed Sword": "sword_2handed",
	"One-Handed Axe": "axe_1handed",
	"Two-Handed Axe": "axe_2handed",
	"Staff": "staff",
	"Wand": "wand",
	"One-Handed Crossbow": "crossbow_1handed",
	"Two-Handed Crossbow": "crossbow_2handed"
}

# Check if an item type is a weapon
func is_weapon_type(item_type: String) -> bool:
	return item_type in WEAPON_TYPES

# Check if a weapon is available in inventory
func has_weapon_in_inventory(weapon_type: String) -> bool:
	if hud == null:
		return false
	return hud.get_item_count(weapon_type) > 0

# Get currently equipped weapon type name (empty if none)
func get_equipped_weapon_type() -> String:
	if current_weapon_model != null and current_weapon_type != "":
		return get_weapon_type_from_filename(current_weapon_type)
	return ""

# Toggle weapon equipment (equip if unequipped, unequip if equipped)
func toggle_weapon_equipment(weapon_type: String):
	if not has_weapon_in_inventory(weapon_type):
		if hud != null:
			hud.show_collection_popup("Weapon not in inventory!", Color.RED)
		return
	
	var currently_equipped = get_equipped_weapon_type()
	
	if currently_equipped == weapon_type:
		# Same weapon is equipped, unequip it
		unequip_weapon()
		if hud != null:
			hud.show_collection_popup(weapon_type + " unequipped!", Color.ORANGE)
	else:
		# Different weapon or no weapon equipped, equip this one
		equip_weapon_by_type(weapon_type)
		if hud != null:
			hud.show_collection_popup(weapon_type + " equipped!", Color.GREEN)

# Equip first available weapon from inventory
func equip_first_available_weapon():
	if hud == null:
		return
	
	for weapon_type in WEAPON_TYPES:
		if has_weapon_in_inventory(weapon_type):
			equip_weapon_by_type(weapon_type)
			if hud != null:
				hud.show_collection_popup(weapon_type + " equipped!", Color.GREEN)
			return
	
	# No weapons found
	if hud != null:
		hud.show_collection_popup("No weapons in inventory!", Color.RED)

# Equip weapon by type name
func equip_weapon_by_type(weapon_type: String):
	if not weapon_type in WEAPON_FILE_MAP:
		print("Unknown weapon type: ", weapon_type)
		return
	
	var weapon_filename = WEAPON_FILE_MAP[weapon_type]
	equip_weapon_by_filename(weapon_filename)

# Equip weapon by filename
func equip_weapon_by_filename(weapon_filename: String):
	print("Equipping weapon: ", weapon_filename)
	
	# Unequip current weapon first
	unequip_weapon()
	
	# Load and instantiate weapon model
	var weapon_scene = load("res://addons/KayKit_Adventurers/Assets/gltf/" + weapon_filename + ".gltf")
	if weapon_scene == null:
		print("Failed to load weapon scene: ", weapon_filename)
		return
	
	current_weapon_model = weapon_scene.instantiate()
	current_weapon_type = weapon_filename
	
	# Create hand node if needed
	var hand_node = head.get_node_or_null("RightHand")
	if hand_node == null:
		hand_node = Node3D.new()
		hand_node.name = "RightHand"
		head.add_child(hand_node)
		hand_node.position = Vector3(0.6, -0.2, -0.8)
	
	# Attach weapon to hand
	hand_node.add_child(current_weapon_model)
	
	# Position weapon correctly
	position_weapon(current_weapon_model, weapon_filename)
	
	print("Weapon equipped successfully: ", weapon_filename)

# Unequip current weapon
func unequip_weapon():
	if current_weapon_model != null:
		print("Unequipping weapon: ", current_weapon_type)
		current_weapon_model.queue_free()
		current_weapon_model = null
		current_weapon_type = ""

# Position weapon based on type
func position_weapon(weapon_model: Node3D, weapon_filename: String):
	if "sword" in weapon_filename:
		weapon_model.position = Vector3(0.2, 0.1, 0.3)
		weapon_model.rotation_degrees = Vector3(-10, 45, 0)
	elif "axe" in weapon_filename:
		weapon_model.position = Vector3(0.2, 0.1, 0.2)
		weapon_model.rotation_degrees = Vector3(-15, 30, 0)
	elif "dagger" in weapon_filename:
		weapon_model.position = Vector3(0.1, 0.05, 0.25)
		weapon_model.rotation_degrees = Vector3(-5, 60, 0)
	elif "staff" in weapon_filename:
		weapon_model.position = Vector3(0.3, 0.2, 0.0)
		weapon_model.rotation_degrees = Vector3(0, 0, -15)
	elif "wand" in weapon_filename:
		weapon_model.position = Vector3(0.15, 0.05, 0.2)
		weapon_model.rotation_degrees = Vector3(0, 15, 0)
	elif "crossbow" in weapon_filename:
		weapon_model.position = Vector3(0.25, 0.15, 0.1)
		weapon_model.rotation_degrees = Vector3(-5, 25, 0)
	else:
		# Default positioning
		weapon_model.position = Vector3(0.2, 0.1, 0.3)
		weapon_model.rotation_degrees = Vector3(-10, 45, 0)

# Get weapon type name from filename
func get_weapon_type_from_filename(filename: String) -> String:
	for weapon_type in WEAPON_FILE_MAP.keys():
		if WEAPON_FILE_MAP[weapon_type] == filename:
			return weapon_type
	return ""

# Test function to spawn an enemy
func spawn_test_enemy():
	var enemy_scene = load("res://scenes/Enemy.tscn")
	if enemy_scene == null:
		print("Failed to load enemy scene")
		if hud != null:
			hud.show_collection_popup("Failed to load enemy scene!", Color.RED)
		return
	
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	
	# Spawn enemy 5 units away from player
	var spawn_offset = Vector3(5, 0, 5)
	enemy.global_position = global_position + spawn_offset
	
	print("Test enemy spawned at: ", enemy.global_position)
	if hud != null:
		hud.show_collection_popup("Enemy spawned nearby!", Color.YELLOW)
