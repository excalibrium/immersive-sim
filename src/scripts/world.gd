extends Node3D

## Level Controller for the main World.
## Initializes the GameSession and acts as the 'Objective Giver'.

@onready var crosshair = $UI/Crosshair
@onready var player = $Player

func _enter_tree():
	# 0. Initialize Game Session early so children can access it in _ready
	# Use .duplicate(true) to ensure each playthrough has its own mutable state
	Game.session = GameSession.new().duplicate(true)
	EnvironmentBridge.start_run()
	SpecimenBridge.start_run()

func _exit_tree():
	EnvironmentBridge.end_run()
	SpecimenBridge.end_run()

func _ready():
	var interactor = player.find_child("PlayerInteractor")
	if interactor:
		crosshair.setup(interactor)
