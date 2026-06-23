extends Node
class_name CameraBobComponent

# --- SIGNALS ---
signal footstep_stepped

# --- CONFIGURABLE EXPORTS ---
@export_group("Walk Bob")
@export var bob_enabled: bool = true
@export var bob_intensity: float = 1.0
@export var bob_speed_multiplier: float = 1.0
@export var base_cycles_per_second: float = 1.25 # Stride frequency at RUN_SPEED (5.0)
@export var sway_y_amplitude: float = 0.04
@export var sway_x_amplitude: float = 0.012
@export var target_camera: Camera3D

@export_group("Idle Sway")
@export var idle_enabled: bool = true
@export var idle_frequency: float = 2.0 # Breathing speed
@export var idle_y_amplitude: float = 0.006 # Vertical breathing sway amplitude
@export var idle_x_amplitude: float = 0.0015 # Pitch breathing tilt amplitude

# --- RUNTIME STATE ---
var continuous_phase: float = 0.0
var idle_phase: float = 0.0

## Updates the bob cycle and offsets target camera local translation/rotation.
func update_bob(velocity: Vector3, is_on_floor: bool, delta: float) -> void:
	if not bob_enabled or not target_camera:
		return
		
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()
	
	# 1. Calculate Idle Sway (breathing)
	var idle_y = 0.0
	var idle_x_rot = 0.0
	if idle_enabled:
		idle_phase = fmod(idle_phase + delta * idle_frequency, 2.0 * PI)
		idle_y = sin(idle_phase) * idle_y_amplitude
		idle_x_rot = cos(idle_phase) * idle_x_amplitude
		
	# 2. Calculate Walk Bob
	var walk_y = 0.0
	var walk_x_rot = 0.0
	
	# Determine transition blending between walk and idle states
	var walk_ratio = clamp(speed / 5.0, 0.0, 1.0) if is_on_floor else 0.0
	var idle_ratio = 1.0 - walk_ratio
	
	if is_on_floor and speed > 0.1:
		# Accumulate phase based on speed relative to RUN_SPEED (5.0)
		var phase_speed = (speed / 5.0) * base_cycles_per_second * 2.0 * PI
		
		var prev_step_count = floor((continuous_phase - PI/2.0) / PI)
		continuous_phase += phase_speed * delta * bob_speed_multiplier
		var current_step_count = floor((continuous_phase - PI/2.0) / PI)
		
		# If the stride phase crossed the step contact angle (PI/2 + k*PI), trigger a step
		if current_step_count > prev_step_count:
			footstep_stepped.emit()
			
		# Head bob offsets (Y position goes down twice per cycle, X rotation/pitch sways once)
		walk_y = -abs(sin(continuous_phase)) * sway_y_amplitude
		walk_x_rot = -cos(2.0 * continuous_phase) * sway_x_amplitude
		
	# 3. Blend and Apply
	var target_y = (idle_y * idle_ratio + walk_y * walk_ratio) * bob_intensity
	var target_x_rot = (idle_x_rot * idle_ratio + walk_x_rot * walk_ratio) * bob_intensity
	
	# Smoothly interpolate offsets
	target_camera.position.y = lerp(target_camera.position.y, target_y, 10.0 * delta)
	target_camera.rotation.x = lerp(target_camera.rotation.x, target_x_rot, 10.0 * delta)
