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

# Health and stamina variables
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
var current_health: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_rate: float = 15.0
var stamina_jump_cost: float = 20.0
var health_regen_rate: float = 2.0

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
var current_tile: String = ""

const MAX_TILE_TIME := 10.0

const TILE_TYPES := {
	"HexTile_Grass": Color(0.3, 0.8, 0.3),
	"HexTile_Plains": Color(0.8, 0.8, 0.3),
	"HexTile_Wheat": Color(0.9, 0.7, 0.2),
	"HexTile_Water": Color(0.2, 0.4, 0.9),
}

const TILE_ITEM_ICONS := {
	"HexTile_Grass": "res://images/icons/grass_icon.png",
	"HexTile_Plains": "res://images/icons/plains_icon.png", 
	"HexTile_Wheat": "res://images/icons/wheat_icon.png",
	"HexTile_Water": "res://images/icons/water_icon.png",
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = floor_snap
	
	current_health = max_health
	current_stamina = max_stamina
	spawn_position = global_position
	
	for tile_type in TILE_TYPES.keys():
		tile_times[tile_type] = 0.0
	
	var main_scene = get_tree().current_scene
	if main_scene:
		hud = main_scene.get_node_or_null("HUD")
		
		if hud != null:
			await get_tree().process_frame
			hud.update_tiles(tile_times)
			hud.update_health(current_health, max_health)
			hud.update_stamina(current_stamina, max_stamina)
			
func _input(event):
	if is_dead:
		return
		
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	
	if event.is_action_pressed("unstuck"):
		take_damage(current_health)
	
	if event.is_action_pressed("collect_resource"):
		print("R key pressed - attempting to collect resource")
		collect_resource_from_current_tile()
	
	for i in range(6):
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
				tile_times[tile_name] = clamp(tile_times[tile_name] + delta, 0, MAX_TILE_TIME)
	else:
		current_tile = ""

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

# Health functions
func take_damage(amount: float):
	current_health = max(0, current_health - amount)
	if hud != null:
		hud.update_health(current_health, max_health)
	
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
	if hud == null or slot_index < 0 or slot_index >= 6:
		return
	
	if slot_index < len(hud.inventory_slots):
		var slot_data = hud.inventory_slots[slot_index]
		if slot_data.item_count > 0:
			use_item(slot_data.item_type, 1)

func collect_resource_from_current_tile():
	print("Collect resource called - Current tile: ", current_tile)
	
	if current_tile == "" or hud == null:
		print("Cannot collect: current_tile is empty or hud is null")
		if hud != null:
			hud.show_collection_popup("No tile detected!", Color.RED)
		return
	
	var tile_time = tile_times.get(current_tile, 0.0)
	print("Tile time for ", current_tile, ": ", tile_time, " / ", MAX_TILE_TIME)
	
	var tile_has_resource = tile_time >= MAX_TILE_TIME
	if not tile_has_resource:
		print("Cannot collect: tile time not maxed (", tile_time, " < ", MAX_TILE_TIME, ")")
		var time_remaining = MAX_TILE_TIME - tile_time
		if hud != null:
			hud.show_collection_popup("Still searching... " + str(int(time_remaining)) + "s left", Color.YELLOW)
		return
	
	print("Collecting resource from ", current_tile)
	
	# Reset tile time after collection
	tile_times[current_tile] = 0.0
	
	# Apply tile-specific effects and add items to inventory
	match current_tile:
		"HexTile_Grass":
			# Grass: Remove health
			print("Collecting grass - removing 20 health")
			take_damage(20.0)
			if hud != null:
				var success = hud.add_item_to_inventory("Grass", TILE_ITEM_ICONS.get("HexTile_Grass", ""), 1)
				print("Added grass to inventory: ", success)
				hud.show_collection_popup("Collected Grass! (-20 HP)", Color.GREEN)
		
		"HexTile_Plains":
			# Plains: Remove stamina
			print("Collecting plains - removing 30 stamina")
			current_stamina = max(0, current_stamina - 30.0)
			if hud != null:
				hud.update_stamina(current_stamina, max_stamina)
				var success = hud.add_item_to_inventory("Plains", TILE_ITEM_ICONS.get("HexTile_Plains", ""), 1)
				print("Added plains to inventory: ", success)
				hud.show_collection_popup("Collected Plains! (-30 Stamina)", Color.GREEN)
		
		"HexTile_Wheat":
			# Wheat: Restore stamina
			print("Collecting wheat - restoring 40 stamina")
			current_stamina = min(max_stamina, current_stamina + 40.0)
			if hud != null:
				hud.update_stamina(current_stamina, max_stamina)
				var success = hud.add_item_to_inventory("Wheat", TILE_ITEM_ICONS.get("HexTile_Wheat", ""), 1)
				print("Added wheat to inventory: ", success)
				hud.show_collection_popup("Collected Wheat! (+40 Stamina)", Color.GREEN)
		
		"HexTile_Water":
			# Water: Restore health
			print("Collecting water - restoring 30 health")
			heal(30.0)
			if hud != null:
				var success = hud.add_item_to_inventory("Water", TILE_ITEM_ICONS.get("HexTile_Water", ""), 1)
				print("Added water to inventory: ", success)
				hud.show_collection_popup("Collected Water! (+30 HP)", Color.GREEN)
	
	# Update HUD with new tile times
	if hud != null:
		hud.update_tiles(tile_times)
