extends Resource
class_name TaskData

@export var task_id: String = ""
@export var description_key: String = ""
@export var is_completed: bool = false

func duplicate_task() -> TaskData:
	var new_task = TaskData.new()
	new_task.task_id = task_id
	new_task.description_key = description_key
	new_task.is_completed = is_completed
	return new_task
