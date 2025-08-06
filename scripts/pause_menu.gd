extends CanvasLayer

@onready var resume_button = $Panel/VBoxContainer/Resume
@onready var quit_button = $Panel/VBoxContainer/Quit

func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	visible = false

func _on_resume_pressed():
	print("Resume pressed!")
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_quit_pressed():
	print("Quit pressed!")
	get_tree().quit()
