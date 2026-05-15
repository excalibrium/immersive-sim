extends Node3D

## Level Controller for the main World.
## Initializes the GameSession and acts as the 'Objective Giver'.

@onready var crosshair = $UI/Crosshair
@onready var player = $Player
@onready var keycard = $Keycard
@onready var keycard_collectible = $Keycard/Collectible

func _ready():
	# 0. Initialize Game Session
	Game.session = GameSession.new()
	
	var interactor = player.find_child("PlayerInteractor")
	if interactor:
		crosshair.setup(interactor)
		
	if keycard_collectible:
		keycard_collectible.collected.connect(keycard.queue_free)
	
	# Small delay to ensure Managers have registered themselves to Game bridge
	await get_tree().process_frame
	
	_initialize_level()

func _initialize_level():
	# 1. Setup Level-Specific Task Pool
	var task1 = TaskData.new()
	task1.task_id = "security_keycard"
	task1.description_key = "TASK_FIND_KEYCARD"
	
	var task2 = TaskData.new()
	task2.task_id = "OPEN_SECURITY_DOOR"
	task2.description_key = "TASK_OPEN_SECURITY_DOOR"
	
	Game.session.global_task_pool.assign([task1, task2])
	
	# 2. Setup Level Objectives
	var main_obj = ObjectiveData.new()
	main_obj.objective_id = "LEVEL_01_MAIN"
	main_obj.title_key = "OBJECTIVE_INFILTRATE_BASE"
	main_obj.tasks.assign([task1.duplicate_task(), task2.duplicate_task()])
	
	# 3. Give initial objective
	if Game.objectives:
		Game.objectives.add_objective(main_obj)
