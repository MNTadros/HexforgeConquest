extends Control

@onready var back_button = $Panel/VBoxContainer/Back
@onready var audio_button = $Panel/VBoxContainer/Audio
@onready var graphics_button = $Panel/VBoxContainer/Graphics

# Extra UI nodes for settings panels
@onready var audio_panel = $AudioPanel
@onready var graphics_panel = $GraphicsPanel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons
	back_button.pressed.connect(_on_back_pressed)
	audio_button.pressed.connect(_show_audio_settings)
	graphics_button.pressed.connect(_show_graphics_settings)

	# Hide subpanels at start
	audio_panel.visible = false
	graphics_panel.visible = false

# Return to pause menu
func _on_back_pressed():
	get_parent()._close_settings()

# Show audio settings
func _show_audio_settings():
	_hide_all_panels()
	audio_panel.visible = true

# Show graphics settings
func _show_graphics_settings():
	_hide_all_panels()
	graphics_panel.visible = true

# Hide all submenus
func _hide_all_panels():
	audio_panel.visible = false
	graphics_panel.visible = false

# Called by a slider in audio panel
func _on_master_volume_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

# Called by fullscreen toggle
func _on_fullscreen_toggled(pressed: bool):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)

# Called by vsync toggle
func _on_vsync_toggled(pressed: bool):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED)
