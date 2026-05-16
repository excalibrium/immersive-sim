extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var task_container: VBoxContainer = %TaskContainer

var objective_data: ObjectiveData

func setup(data: ObjectiveData, is_priority: bool = true):
	objective_data = data
	refresh_ui(is_priority)

func refresh_ui(is_priority: bool = true):
	if not objective_data:
		return
	
	title_label.text = objective_data.title_key
	
	# Clear tasks
	for child in task_container.get_children():
		child.queue_free()
	
	task_container.visible = is_priority
	if not is_priority:
		return
	
	# Add tasks
	for task in objective_data.tasks:
		var task_label = Label.new()
		var status = "[X] " if task.is_completed else "[ ] "
		task_label.text = status + task.description_key
		
		if task.is_completed:
			task_label.modulate = Color.GRAY
		
		task_container.add_child(task_label)
