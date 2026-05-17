extends Node3D

## Level Controller for the main World.
## Initializes the GameSession and acts as the 'Objective Giver'.

@onready var crosshair = $UI/Crosshair
@onready var player = $Player
@onready var keycard = $Keycard
@onready var keycard_collectible = $Keycard/Collectible
@onready var button_activator = $seg2/WallButton/ButtonActivator
@onready var sliding_door_comp = $seg2/SlidingDoor/DoorLeaf/SlidingDoorComp

func _enter_tree():
	# 0. Initialize Game Session early so children can access it in _ready
	# Use .duplicate(true) to ensure each playthrough has its own mutable state
	Game.session = GameSession.new().duplicate(true)

func _ready():
	var interactor = player.find_child("PlayerInteractor")
	if interactor:
		crosshair.setup(interactor)
