extends AbstractDoor
class_name Door

## Rotating door implementation.

@export var open_rotation: float = 90.0
var target_rotation: float = 0.0

func toggle():
	super.toggle() # Handle base state and signal
	target_rotation = open_rotation if is_open else 0.0
 
func _apply_animation(delta: float) -> bool:
	var parent = get_parent() as Node3D
	if parent:
		var target_rad = deg_to_rad(target_rotation)
		parent.rotation.y = rotate_toward(parent.rotation.y, target_rad, delta * animation_speed)
		return is_equal_approx(parent.rotation.y, target_rad)
	return true
