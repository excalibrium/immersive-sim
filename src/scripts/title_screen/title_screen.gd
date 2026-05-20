extends Control

## A portable Title Screen implementation.
## Contains 'New Game' and 'Exit' functionality.

@export_file("*.tscn") var start_world_path: String = "res://src/scenes/world.tscn"

@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton

func _ready() -> void:
	# Connect signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Focus the first button for controller support
	new_game_button.grab_focus()

func _on_new_game_pressed() -> void:
	print("Starting new game...")
	
	# Global logic reset
	TimeManager.time_scale = 1.0
	WindowManager.reset_to_state(WindowManager.MouseState.CAPTURED)
		
	get_tree().change_scene_to_file(start_world_path)

func _on_settings_pressed() -> void:
	print("Opening settings...")
	var settings_scene = load("res://src/scenes/ui/SettingsMenu.tscn")
	var menu = settings_scene.instantiate()
	add_child(menu)
	menu.back_pressed.connect(func(): menu.queue_free())

func _on_exit_pressed() -> void:
	print("Exiting game...")
	get_tree().quit()
