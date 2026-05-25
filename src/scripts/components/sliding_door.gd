extends AbstractDoor
class_name SlidingDoor

## Sliding door implementation.

@export var open_offset: Vector3 = Vector3(0, 2.5, 0)
var target_position: Vector3
var base_position: Vector3

func _ready():
	await super._ready() # Ensure base setup is done
	
	var parent = get_parent() as Node3D
	if parent:
		base_position = parent.position
		target_position = base_position

func toggle():
	super.toggle()
	target_position = base_position + open_offset if is_open else base_position

func _apply_animation(delta: float) -> bool:
	var parent = get_parent() as Node3D
	if parent:
		parent.position = parent.position.move_toward(target_position, delta * animation_speed)
		return parent.position.is_equal_approx(target_position)
	return true
