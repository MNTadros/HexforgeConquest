extends Control

@onready var back_button = $Panel/VBoxContainer/BackButton
@onready var volume_slider = $Panel/VBoxContainer/AudioControls/MasterVolumeSlider
@onready var volume_label = $Panel/VBoxContainer/AudioControls/VolumeLabel
@onready var fullscreen_check = $Panel/VBoxContainer/FullscreenCheck
@onready var vsync_check = $Panel/VBoxContainer/VsyncCheck

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons and controls
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if volume_slider:
		volume_slider.value_changed.connect(_on_master_volume_changed)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
		
	# Set initial values
	if volume_slider:
		volume_slider.value = 1.0  # Set to max volume initially
		_update_volume_label(volume_slider.value)
	if fullscreen_check:
		fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if vsync_check:
		vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

# Return to pause menu or close if called from main menu
func _on_back_pressed():
	var parent_node = get_parent()
	if parent_node.has_method("_close_settings"):
		parent_node._close_settings()
	else:
		queue_free()

# Called by volume slider
func _on_master_volume_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_update_volume_label(value)

func _update_volume_label(value: float):
	if volume_label:
		var percentage = int(value * 100)
		volume_label.text = "Master Volume: " + str(percentage) + "%"

# Called by fullscreen toggle
func _on_fullscreen_toggled(pressed: bool):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED)

# Called by vsync toggle
func _on_vsync_toggled(pressed: bool):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED)
