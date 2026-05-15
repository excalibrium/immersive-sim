extends Node

## Global Time Manager for custom time scaling.
## Avoids Engine.time_scale to allow granular control over what gets slowed down.

signal time_scale_changed(new_scale: float)

@export var time_scale: float = 1.0:
	set(value):
		time_scale = value
		time_scale_changed.emit(time_scale)

## Returns the delta value multiplied by the current global time scale.
func get_scaled_delta(delta: float) -> float:
	return delta * time_scale

## Handy for objects that should only be partially affected or have their own dilation.
func get_custom_scaled_delta(delta: float, local_dilation: float) -> float:
	return delta * time_scale * local_dilation
