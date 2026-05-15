extends Control

@export var objective_item_scene: PackedScene

@onready var objective_container: VBoxContainer = %ObjectiveContainer

func _ready():
	# Connect to ObjectiveManager signals
	if Game.objectives:
		Game.objectives.objective_added.connect(_on_objective_added)
		Game.objectives.task_updated.connect(_on_task_updated)
		Game.objectives.objective_completed.connect(_on_objective_completed)
	
	# Clear placeholder children
	for child in objective_container.get_children():
		child.queue_free()
	
	# Initial load
	if Game.objectives:
		for objective in Game.objectives.get_active_objectives():
			_add_objective_item(objective)

func _on_objective_added(objective: ObjectiveData):
	_add_objective_item(objective)

func _on_task_updated(objective: ObjectiveData, _task: TaskData):
	_refresh_objective_item(objective)

func _on_objective_completed(objective: ObjectiveData):
	_refresh_objective_item(objective)

func _add_objective_item(objective: ObjectiveData):
	if not objective_item_scene:
		push_error("OBJECTIVE_ITEM_SCENE_NOT_SET")
		return
		
	var item = objective_item_scene.instantiate()
	objective_container.add_child(item)
	item.set_meta("objective_id", objective.objective_id)
	item.setup(objective)

func _refresh_objective_item(objective: ObjectiveData):
	for child in objective_container.get_children():
		if child.get_meta("objective_id") == objective.objective_id:
			if child.has_method("refresh_ui"):
				child.refresh_ui()
			return
