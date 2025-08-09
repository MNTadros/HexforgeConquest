extends CanvasLayer

@onready var resume_button = $Panel/VBoxContainer/Resume
@onready var settings_button = $Panel/VBoxContainer/Settings
@onready var quit_button = $Panel/VBoxContainer/Quit
@onready var settings_menu = $SettingsMenu

var is_paused: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	settings_menu.visible = false
	visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_menu.visible:
			_close_settings()
		elif is_paused:
			_resume_game()
		else:
			_pause_game()

func _pause_game():
	is_paused = true
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume_game():
	is_paused = false
	visible = false
	settings_menu.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed():
	_resume_game()

func _on_settings_pressed():
	settings_menu.visible = true
	$Panel.visible = false

func _close_settings():
	settings_menu.visible = false
	$Panel.visible = true

func _on_quit_pressed():
	# Multiplayer-safe quit (uncomment later)
	# if multiplayer.multiplayer_peer:
	#     multiplayer.multiplayer_peer.disconnect_peer()

	get_tree().quit()
