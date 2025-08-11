extends Control

var animation_player: AnimationPlayer
var color_rect: ColorRect
var settings_panel: Control
var volume_slider: HSlider
var volume_label: Label
var fullscreen_check: CheckBox
var vsync_check: CheckBox

var transition_out = false

func _ready():
	# Get node references safely
	animation_player = get_node_or_null("AnimationPlayer")
	color_rect = get_node_or_null("ColorRect")
	settings_panel = get_node_or_null("SettingsPanel")
	volume_slider = get_node_or_null("SettingsPanel/SettingsContainer/VBoxContainer/MasterVolumeSlider")
	volume_label = get_node_or_null("SettingsPanel/SettingsContainer/VBoxContainer/VolumeLabel")
	fullscreen_check = get_node_or_null("SettingsPanel/SettingsContainer/VBoxContainer/FullscreenCheck")
	vsync_check = get_node_or_null("SettingsPanel/SettingsContainer/VBoxContainer/VsyncCheck")
	
	# Debug what we found
	print("=== MainMenu Node Debug ===")
	print("Animation player: ", animation_player)
	print("Color rect: ", color_rect)
	print("Settings panel: ", settings_panel)
	
	# Start fade in animation
	if animation_player:
		animation_player.play("fade_in")
		print("Started fade_in animation")
	else:
		print("WARNING: AnimationPlayer not found!")
	
	# Initialize settings values
	_initialize_settings()
	
	# Note: Button signals are connected via the scene file, no need to connect manually
	print("MainMenu ready - signals should be connected via scene file")

func _initialize_settings():
	if volume_slider:
		volume_slider.value = 1.0
		_update_volume_label(volume_slider.value)
	if fullscreen_check:
		fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if vsync_check:
		vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

func _input(event):
	if event.is_action_pressed("ui_cancel") and settings_panel and settings_panel.visible:
		_close_settings()

func _on_animation_finished(anim_name):
	if anim_name == "fade_in":
		if animation_player:
			animation_player.play("idle")

func _on_play_button_pressed():
	print("Play button pressed!")
	transition_to_game()

func _on_settings_button_pressed():
	print("Settings button pressed!")
	_open_settings()

func _open_settings():
	if settings_panel:
		settings_panel.visible = true
		print("Settings panel opened")

func _close_settings():
	if settings_panel:
		settings_panel.visible = false
		print("Settings panel closed")

func _on_settings_back_pressed():
	print("Settings back button pressed!")
	_close_settings()

func _update_volume_label(value: float):
	if volume_label:
		var percentage = int(value * 100)
		volume_label.text = "Master Volume: " + str(percentage) + "%"

func _on_volume_changed(value: float):
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	_update_volume_label(value)

func _on_fullscreen_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(pressed: bool):
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_quit_button_pressed():
	print("Quit button pressed!")
	if OS.has_feature("web"):
		# In web builds, show a message instead of quitting
		color_rect.visible = true
		var label = Label.new()
		label.text = "Thank you for playing!\nYou may close this tab now."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchors_preset = Control.PRESET_FULL_RECT
		color_rect.add_child(label)
	else:
		get_tree().quit()

func transition_to_game():
	if transition_out:
		return
	
	transition_out = true
	
	# Simple fade to black transition
	color_rect.visible = true
	color_rect.color = Color(0, 0, 0, 0)
	
	var tween = create_tween()
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 1), 0.8)
	tween.tween_callback(start_game_scene)

func start_game_scene():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
