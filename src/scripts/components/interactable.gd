extends Node3D
class_name Interactable

## Base component for interactive objects.

signal interacted(interactor: Node)
signal focused
signal unfocused

@export var interact_text_key: String = "INTERACT_USE"
@export var priority: int = 0 # Higher value = higher priority for the interactor

## Callback to check if interaction is currently denied
var get_denied_status: Callable = func(): return false

func interact(interactor: Node):
	interacted.emit(interactor)

func is_denied() -> bool:
	return get_denied_status.call()

func focus():
	focused.emit()

func unfocus():
	unfocused.emit()
