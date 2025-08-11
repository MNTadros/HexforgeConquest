extends Node

# =======================================
# GAME TIMER AND STATS MANAGER
# =======================================

@export var game_duration: float = 360  # 6 minutes

# Game state
var time_remaining: float
var is_active: bool = true

# Player stats
var enemies_killed: int = 0
var damage_taken: float = 0.0
var damage_dealt: float = 0.0
var resources_collected: int = 0

# UI reference
var hud: CanvasLayer = null

# =======================================
# CORE FUNCTIONS
# =======================================

func _ready():
	add_to_group("game_manager")
	time_remaining = game_duration
	await get_tree().process_frame
	hud = get_tree().current_scene.get_node_or_null("HUD")
	print("GameManager: 6-minute timer started")

func _process(delta):
	if not is_active:
		return
	
	time_remaining -= delta
	update_hud_timer()
	
	if time_remaining <= 0.0:
		time_remaining = 0.0
		game_over()

func update_hud_timer():
	if hud and hud.has_method("update_timer"):
		hud.update_timer(time_remaining)

# =======================================
# GAME OVER SYSTEM
# =======================================

func game_over():
	is_active = false
	create_game_over_screen()

func create_game_over_screen():
	# Create fullscreen overlay
	var screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow input when paused
	
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	
	# Main panel
	var panel = create_main_panel()
	screen.add_child(panel)
	
	# Add to scene and pause
	get_tree().current_scene.add_child(screen)
	get_tree().paused = true
	
	# Free the cursor so user can interact with UI
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func create_main_panel() -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(500, 400)  # Larger panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250  # Half of width (500/2)
	panel.offset_right = 250
	panel.offset_top = -200   # Half of height (400/2)
	panel.offset_bottom = 200
	
	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 25)
	
	# Add margins for better spacing
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	
	# Title
	content.add_child(create_title())
	
	# Stats
	content.add_child(create_stats_display())
	
	# Buttons
	content.add_child(create_buttons())
	
	margin.add_child(content)
	panel.add_child(margin)
	return panel

func create_title() -> Label:
	var title = Label.new()
	title.text = "TIME'S UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.RED)
	return title

func create_stats_display() -> VBoxContainer:
	var stats = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	
	stats.add_child(create_stat_label("Enemies Killed: " + str(enemies_killed)))
	stats.add_child(create_stat_label("Damage Taken: " + str(int(damage_taken))))
	stats.add_child(create_stat_label("Damage Dealt: " + str(int(damage_dealt))))
	stats.add_child(create_stat_label("Resources Collected: " + str(resources_collected)))
	stats.add_child(create_stat_label("Survival Time: " + format_time(game_duration - time_remaining)))
	
	return stats

func create_stat_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label

func create_buttons() -> HBoxContainer:
	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 20)
	
	# Main menu button
	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(150, 50)
	menu_btn.pressed.connect(go_to_main_menu)
	container.add_child(menu_btn)
	
	return container

# =======================================
# UTILITY FUNCTIONS
# =======================================

func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func restart_game():
	get_tree().paused = false
	# Reset mouse capture before reloading scene
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()

func quit_game():
	print("Quit button pressed! Exiting game...")
	get_tree().quit()

func go_to_main_menu():
	print("Main Menu button pressed!")
	get_tree().paused = false
	# Keep cursor visible for main menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# =======================================
# STATS TRACKING (called by other systems)
# =======================================

func add_enemy_kill():
	enemies_killed += 1

func add_damage_taken(amount: float):
	damage_taken += amount

func add_damage_dealt(amount: float):
	damage_dealt += amount

func add_resource_collected():
	resources_collected += 1

# End game early (for other win/lose conditions)
func trigger_game_end():
	game_over()
