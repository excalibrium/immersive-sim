extends Node
class_name ObjectiveGiverGlue

## Glue Layer Component.
## Connects ObjectiveGiver (Function) to ObjectiveManager (Global).

@export var objective_giver: ObjectiveGiver

func _ready():
	if not objective_giver:
		objective_giver = get_parent() as ObjectiveGiver
	
	if objective_giver:
		objective_giver.objectives_ready.connect(_on_objectives_ready)
		
		# (Rule 11 Exception): Connecting to Autoload signal in _ready.
		# This is explicit coupling to the global ObjectiveManager.
		if Game.objectives:
			Game.objectives.objective_completed.connect(_on_objective_completed)

func _on_objectives_ready(objectives: Array[ObjectiveData]):
	for obj in objectives:
		if Game.objectives:
			Game.objectives.add_objective(obj)

func _on_objective_completed(_objective: ObjectiveData):
	if objective_giver and objective_giver.delivery_mode == ObjectiveGiver.DeliveryMode.SEQUENTIAL:
		# If we are in sequential mode, trigger the next one automatically
		objective_giver.trigger_delivery()
