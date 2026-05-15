extends Node
class_name TaskCompleterCollectible

@export var collectible: Collectible
@export var task_id: String

func _ready():
	if not collectible:
		collectible = get_parent() as Collectible
	if collectible:
		collectible.collected.connect(_on_collected)

func _on_collected():
	if task_id != "" and Game.objectives:
		Game.objectives.update_task(task_id, true)
