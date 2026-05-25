extends Node3D
class_name Interactable

## Base component for interactive objects.

signal interacted(interactor: Node)
signal focused
signal unfocused

@export var interact_text_key: String = "INTERACT_USE"
@export var priority: int = 0 # Higher value = higher priority for the interactor

## Callback to check if interaction is currently denied.
## By default, returns false. Can be customized by other scripts.
var get_denied_status: Callable = func(_by_whom: Node = null) -> bool: return false

## Callback to supply custom interaction prompt data.
## By default, returns an empty Dictionary. Can be customized by other scripts.
var get_custom_prompt_data: Callable = func(_by_whom: Node = null) -> Dictionary: return {}

func interact(interactor: Node):
	interacted.emit(interactor)

func is_denied(by_whom: Node = null) -> bool:
	if get_denied_status.is_valid():
		return get_denied_status.call(by_whom)
	return false

func focus():
	focused.emit()

func unfocus():
	unfocused.emit()

func get_interaction_prompt_data(by_whom: Node = null) -> Dictionary:
	if get_custom_prompt_data.is_valid():
		var custom_data = get_custom_prompt_data.call(by_whom)
		if not custom_data.is_empty():
			return custom_data
			
	return {
		"action": "interact",
		"text_key": interact_text_key,
		"is_denied": is_denied(by_whom)
	}
