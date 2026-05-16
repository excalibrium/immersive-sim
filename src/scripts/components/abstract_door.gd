extends Node
class_name AbstractDoor

## Base class for all door types. 
## Handles interaction, locking logic, and state management.

signal state_changed(is_open: bool)
signal locked_interact_attempted

@export var interactable: Interactable
@export var is_locked: bool = false
@export var required_item_id: String = ""
@export var animation_speed: float = 5.0

var is_open: bool = false

func _ready():
	# (Rule 38): Never assume a sibling is ready. 
	# Await a frame to ensure @export dependencies are fully initialized.
	await get_tree().process_frame
	
	if not interactable:
		# Fallback to parent if not assigned
		interactable = get_parent() as Interactable
	
	if interactable:
		interactable.interacted.connect(_on_interacted)
		interactable.get_denied_status = _check_if_denied
		_update_interact_text()

func _process(delta: float):
	_apply_animation(delta)

## Virtual method: Must be overridden by subclasses.
func _apply_animation(_delta: float):
	push_error("AbstractDoor: _apply_animation() not implemented in subclass: ", name)

func _check_if_denied() -> bool:
	if is_locked and required_item_id != "" and Game.inventory:
		return not Game.inventory.has_item(required_item_id)
	return false

func _on_interacted(_interactor: Node):
	if is_locked:
		if required_item_id != "" and Game.inventory and Game.inventory.has_item(required_item_id):
			is_locked = false
			print("DOOR_UNLOCKED_WITH_ITEM: ", required_item_id)
			_update_interact_text()
			toggle()
		else:
			print("DOOR_LOCKED")
			locked_interact_attempted.emit()
	else:
		toggle()

func toggle():
	is_open = !is_open
	state_changed.emit(is_open)
	print("DOOR_TOGGLED: ", "OPEN" if is_open else "CLOSED")

func _update_interact_text():
	if interactable:
		interactable.interact_text_key = "INTERACT_DOOR_UNLOCK" if is_locked else "INTERACT_DOOR_USE"
