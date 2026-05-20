extends CanvasLayer

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_button: Button = %MenuButton

func _ready() -> void:
	# Ensure game is paused when this menu is open
	TimeManager.time_scale = 0.0
	WindowManager.push_mouse_state(WindowManager.MouseState.VISIBLE)
	
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	resume_button.grab_focus()

func _on_resume_pressed() -> void:
	TimeManager.time_scale = 1.0
	WindowManager.pop_mouse_state()
	queue_free()

func _on_settings_pressed() -> void:
	var settings_scene = load("res://src/scenes/ui/SettingsMenu.tscn")
	var menu = settings_scene.instantiate()
	add_child(menu)
	menu.back_pressed.connect(func(): menu.queue_free())

func _on_menu_pressed() -> void:
	TimeManager.time_scale = 1.0
	get_tree().change_scene_to_file("res://src/scenes/title_screen/TitleScreen.tscn")
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Only close if we are the top-most CanvasLayer in this branch
		# In this simple setup, we just check if we have any children that might be blocking
		# But since we added _unhandled_input to SettingsMenu and it calls set_input_as_handled,
		# this is technically a safety measure.
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
