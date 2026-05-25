extends Interactable
class_name Pickupable

## Component that makes a RigidBody3D pickupable by the player.
## Should be a child of or linked to a RigidBody3D.

signal picked_up
signal dropped

const DEFAULT_LIFT_STRENGTH: float = 50.0

## The physical body that will be picked up and carried.
@export var body: RigidBody3D

## Force applied when throwing. Typical range is 5.0 (weak nudge) to 30.0 (strong launch).
@export_range(0.0, 100.0, 0.5) var throw_force: float = 10.0

func _ready() -> void:
	if not body:
		body = get_parent() as RigidBody3D

func is_denied(by_whom: Node = null) -> bool:
	var strength: float = DEFAULT_LIFT_STRENGTH
	if by_whom and by_whom.has_method("get_lift_strength"):
		strength = by_whom.get_lift_strength()
	return not can_pickup(strength)

func can_pickup(lift_strength: float = DEFAULT_LIFT_STRENGTH) -> bool:
	if not body:
		return false
	return body.mass <= lift_strength

func on_picked_up() -> void:
	picked_up.emit()

func on_dropped() -> void:
	dropped.emit()

func get_interaction_prompt_data(by_whom: Node = null) -> Dictionary:
	var mass = body.mass if body else 0.0
	return {
		"action": "carry",
		"text_key": interact_text_key,
		"is_denied": is_denied(by_whom),
		"details": {
			"mass": mass
		}
	}
