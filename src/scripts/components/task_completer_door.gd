extends Node
class_name TaskCompleterDoor

@export var door: Door
@export var task_id: String

func _ready():
	if not door:
		door = get_parent() as Door
	if door:
		door.state_changed.connect(_on_door_state_changed)

func _on_door_state_changed(is_open: bool):
	if is_open and task_id != "" and Game.objectives:
		Game.objectives.update_task(task_id, true)
