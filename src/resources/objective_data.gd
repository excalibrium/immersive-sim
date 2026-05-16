extends Resource
class_name ObjectiveData

@export var objective_id: String = ""
@export var title_key: String = ""
@export var tasks: Array[TaskData] = []
@export var is_repeatable: bool = false

func duplicate_objective() -> ObjectiveData:
	var new_objective = ObjectiveData.new()
	new_objective.objective_id = objective_id
	new_objective.title_key = title_key
	new_objective.is_repeatable = is_repeatable
	
	var duplicated_tasks: Array[TaskData] = []
	for task in tasks:
		duplicated_tasks.append(task.duplicate_task())
	new_objective.tasks.assign(duplicated_tasks)
	
	return new_objective

func is_objective_completed() -> bool:
	for task in tasks:
		if not task.is_completed:
			return false
	return true
