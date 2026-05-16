extends Control

@export var objective_item_scene: PackedScene

@onready var objective_container: VBoxContainer = %ObjectiveContainer

func _ready():
	# Connect to ObjectiveManager signals
	if Game.objectives:
		Game.objectives.objectives_updated.connect(_on_objectives_updated)
	
	# Clear placeholder children
	for child in objective_container.get_children():
		child.queue_free()
	
	# Initial load
	if Game.objectives:
		_on_objectives_updated(Game.objectives.get_active_objectives())

func _on_objectives_updated(active: Array[ObjectiveData]):
	# Clear existing
	for child in objective_container.get_children():
		child.queue_free()
	
	for i in range(active.size()):
		var objective = active[i]
		_add_objective_item(objective, i)

func _add_objective_item(objective: ObjectiveData, index: int):
	if not objective_item_scene:
		push_error("OBJECTIVE_ITEM_SCENE_NOT_SET")
		return
		
	var item = objective_item_scene.instantiate()
	objective_container.add_child(item)
	
	# Visual Hierarchy Logic
	var is_priority = (index == 0)
	var scale_factor = 1.0
	var alpha = 1.0
	
	if index == 1:
		scale_factor = 0.85
		alpha = 0.7
	elif index >= 2:
		scale_factor = 0.7
		alpha = 0.4
	
	item.modulate.a = alpha
	item.custom_minimum_size *= scale_factor # Simple scaling
	item.scale = Vector2(scale_factor, scale_factor)
	
	item.setup(objective, is_priority)
