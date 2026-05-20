extends Node
class_name Pickupable

## Component that makes a RigidBody3D pickupable by the player.
## Should be a child of or linked to a RigidBody3D.

signal picked_up
signal dropped

## The physical body that will be picked up and carried.
@export var body: RigidBody3D

## The associated interactable node that highlights this object.
@export var interactable: Interactable

## Force applied when throwing. Typical range is 5.0 (weak nudge) to 30.0 (strong launch).
@export_range(0.0, 100.0, 0.5) var throw_force: float = 10.0

func _ready() -> void:
	if not body:
		body = get_parent() as RigidBody3D
	
	if not body:
		push_error("Pickupable on ", name, " has no RigidBody3D link.")
	
	if not interactable:
		# Try to find an interactable sibling in the parent
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is Interactable:
					interactable = child
					break
	
	if not interactable:
		push_warning("Pickupable on ", name, " has no Interactable link.")
	else:
		# Register ourselves as the denial provider if not explicitly configured
		if not interactable.denial_provider:
			interactable.denial_provider = self

## Called by PlayerInteractor/Interactable to check if the player can lift this object.
func is_interaction_denied(by_whom: Node = null) -> bool:
	var strength: float = 50.0
	if by_whom is Player:
		strength = by_whom.get_lift_strength()
	elif by_whom and by_whom.has_method("get_lift_strength"):
		strength = by_whom.get_lift_strength()
	elif by_whom and "player_strength" in by_whom:
		strength = 50.0 * by_whom.player_strength
	return not can_pickup(strength)

func can_pickup(lift_strength: float = 50.0) -> bool:
	if not body:
		return false
	return body.mass <= lift_strength

func on_picked_up() -> void:
	picked_up.emit()

func on_dropped() -> void:
	dropped.emit()
