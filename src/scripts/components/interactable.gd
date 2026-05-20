extends Node3D
class_name Interactable

## Base component for interactive objects.

signal interacted(interactor: Node)
signal focused
signal unfocused

@export var interact_text_key: String = "INTERACT_USE"
@export var priority: int = 0 # Higher value = higher priority for the interactor
## Optional node that provides custom interaction denial logic (must implement is_interaction_denied).
@export var denial_provider: Node

## Callback to check if interaction is currently denied.
## By default, returns false. Can be customized by other scripts.
var get_denied_status: Callable = func(_by_whom: Node = null) -> bool: return false

func _ready():
	# If no denial provider is assigned, automatically look for a sibling component that supports it
	if not denial_provider:
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child != self and child.has_method("is_interaction_denied"):
					denial_provider = child
					break

func interact(interactor: Node):
	interacted.emit(interactor)

func is_denied(by_whom: Node = null) -> bool:
	if denial_provider and denial_provider.has_method("is_interaction_denied"):
		return denial_provider.is_interaction_denied(by_whom)
	if get_denied_status.is_valid():
		return get_denied_status.call(by_whom)
	return false

func focus():
	focused.emit()

func unfocus():
	unfocused.emit()
