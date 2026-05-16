extends Node
class_name ButtonActivator

## Component that calls a method on target nodes when its interactable is used.

@export var interactable: Interactable
@export var target_nodes: Array[Node]
@export var toggle_method: String = "toggle"

func _ready():
	if not interactable:
		interactable = get_parent() as Interactable
	
	if interactable:
		interactable.interacted.connect(_on_interacted)
		interactable.interact_text_key = "INTERACT_PRESS_BUTTON"

func _on_interacted(_interactor: Node):
	for target in target_nodes:
		if target and target.has_method(toggle_method):
			target.call(toggle_method)
