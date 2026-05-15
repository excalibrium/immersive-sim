extends Node3D
class_name Door

## A modular door component.
## Handles locking, unlocking, and opening/closing animations.

signal state_changed(is_open: bool)
signal locked_interact_attempted

@export var interactable: Interactable
@export var is_locked: bool = false
@export var required_item_id: String = ""
@export var open_rotation: float = 90.0
@export var animation_speed: float = 5.0

var is_open: bool = false
var target_rotation: float = 0.0

func _ready():
	if not interactable:
		interactable = get_parent() as Interactable
	
	if interactable:
		interactable.interacted.connect(_on_interacted)
		interactable.get_denied_status = _check_if_denied
		_update_interact_text()

func _check_if_denied() -> bool:
	if is_locked and required_item_id != "" and not Game.inventory.has_item(required_item_id):
		return true
	return false
func _process(delta: float):
	# The door visuals and collision are on the parent (DoorLeaf).
	# This script is attached to a component node, so it must rotate the parent.
	var parent = get_parent() as Node3D
	if parent:
		parent.rotation.y = rotate_toward(parent.rotation.y, deg_to_rad(target_rotation), delta * animation_speed)

func _on_interacted(_interactor: Node):
	if is_locked:
		if required_item_id != "" and Game.inventory.has_item(required_item_id):
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
	target_rotation = open_rotation if is_open else 0.0
	state_changed.emit(is_open)
	print("DOOR_TOGGLED: ", "OPEN" if is_open else "CLOSED")

func _update_interact_text():
	if interactable:
		interactable.interact_text_key = "INTERACT_DOOR_UNLOCK" if is_locked else "INTERACT_DOOR_USE"
