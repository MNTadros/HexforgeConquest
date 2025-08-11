extends Node3D

# Spawner configuration
@export var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
@export var max_enemies: int = 20
@export var spawn_interval: float = 1.0
@export var spawn_radius: float = 25.0

# Internal tracking
var current_enemies: int = 0
var spawn_timer: float = 0.0
var player: CharacterBody3D = null
var spawn_points: Array[Vector3] = []

func _ready():
	player = get_tree().get_first_node_in_group("player")
	setup_spawn_points()
	spawn_initial_enemies()

func setup_spawn_points():
	# Create circle of spawn points around origin
	var point_count = 8
	for i in range(point_count):
		var angle = (i * 2 * PI) / point_count
		var x = cos(angle) * spawn_radius
		var z = sin(angle) * spawn_radius
		spawn_points.append(Vector3(x, 5, z))

func spawn_initial_enemies():
	var initial_count = min(3, max_enemies)
	for i in range(initial_count):
		spawn_enemy()

func _process(delta):
	spawn_timer += delta
	
	# Spawn new enemy if conditions are met
	if spawn_timer >= spawn_interval and current_enemies < max_enemies:
		if can_spawn_enemy():
			spawn_enemy()
			spawn_timer = 0.0

func can_spawn_enemy() -> bool:
	# Don't spawn if no player or player is dead
	if player == null or player.is_dead:
		return false
	
	# Don't spawn if player is too close to spawn points
	for spawn_point in spawn_points:
		var distance = player.global_position.distance_to(spawn_point)
		if distance < 5.0:
			return false
	
	return true

func spawn_enemy():
	if enemy_scene == null or spawn_points.is_empty():
		return
	
	# Choose random spawn point with slight offset
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var random_offset = Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
	var final_position = spawn_point + random_offset
	
	# Create and place enemy
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = final_position
	
	current_enemies += 1
	print("Spawned enemy at: ", final_position, " (Total: ", current_enemies, ")")
	
	# Track enemy death
	var check_timer = Timer.new()
	check_timer.wait_time = 2.0
	check_timer.timeout.connect(_check_enemy_count)
	add_child(check_timer)
	check_timer.start()

func _check_enemy_count():
	# Update actual enemy count
	var alive_enemies = get_tree().get_nodes_in_group("enemies")
	var actual_count = 0
	
	for enemy in alive_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			actual_count += 1
	
	current_enemies = actual_count
