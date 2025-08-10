extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 10.0
@export var deceleration: float = 14.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var max_slope_angle: float = 50.0
@export var floor_snap: float = 0.6

@onready var ground_ray = $RayCast3D
@onready var head = $Head
var hud = null

var pitch := 0.0
var tile_times: Dictionary = {} # Time spent on each tile
var current_tile: String = ""

const MAX_TILE_TIME := 10.0

const TILE_TYPES := {
	"HexTile_Grass": Color(0.3, 0.8, 0.3),
	"HexTile_Plains": Color(0.8, 0.8, 0.3),
	"HexTile_Wheat": Color(0.9, 0.7, 0.2),
	"HexTile_Water": Color(0.2, 0.4, 0.9),
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_max_angle = deg_to_rad(max_slope_angle)
	floor_snap_length = floor_snap
	
	for tile_type in TILE_TYPES.keys():
		tile_times[tile_type] = 0.0
	
	var main_scene = get_tree().current_scene
	if main_scene:
		hud = main_scene.get_node_or_null("HUD")
		
		# Wait a frame to ensure all nodes are ready, then send initial tile times
		if hud != null:
			await get_tree().process_frame
			hud.update_tiles(tile_times)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	
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
	
	# --- Movement ---
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

	# --- Gravity & Tile Detection ---
	if ground_ray.is_colliding():
		var collider = ground_ray.get_collider()
		if collider:
			var tile_name = collider.name
			if tile_name in TILE_TYPES:
				current_tile = tile_name
				# Only increment if we already have this tile in our dictionary
				if tile_times.has(tile_name):
					tile_times[tile_name] = clamp(tile_times[tile_name] + delta, 0, MAX_TILE_TIME)
	else:
		current_tile = ""

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	else:
		velocity.y = -0.01

	move_and_slide()

	# --- Send tile times to HUD ---
	if hud != null:
		hud.update_tiles(tile_times)
