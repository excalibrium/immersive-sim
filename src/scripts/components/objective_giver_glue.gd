extends ObjectiveGiver
class_name ObjectiveGiverGlue

## Glue Layer Component.
## Connects ObjectiveGiver (Function) to ObjectiveManager (Global).

func _ready():
	# Connect to our own signal before calling parent's _ready() to avoid race conditions if give_on_ready is true.
	objectives_ready.connect(_on_objectives_ready)
	
	if Game.objectives:
		Game.objectives.objective_completed.connect(_on_objective_completed)
		
	super._ready()

func _on_objectives_ready(objectives: Array[ObjectiveData]):
	for obj in objectives:
		if Game.objectives:
			Game.objectives.add_objective(obj)

func _on_objective_completed(_objective: ObjectiveData):
	if delivery_mode == DeliveryMode.SEQUENTIAL:
		# If we are in sequential mode, trigger the next one automatically
		trigger_delivery()
