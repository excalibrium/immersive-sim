extends Node3D
class_name PlayerPickup

## Logic for picking up, carrying, and throwing RigidBody3D objects.
## Listens for 'primary_action' (hold click) to carry, and Right Click to throw.

signal carry_weight_changed(new_mass: float)

## The player interactor component used to find targets.
@export var interactor: PlayerInteractor

## The camera node. Orientation and position are calculated relative to this.
@export var camera_3d: Camera3D

## [DEPRECATED] Marker node for hold position. Use camera_3d and default_hold_distance instead.
@export var hold_position: Node3D

## How quickly the object tries to reach the hold position.
## Typical range: 50.0 (soft/elastic) to 300.0 (rigid/stiff).
@export_range(0.0, 500.0, 1.0) var stiffness: float = 120.0

## How much the object's linear movement is dampened to prevent wobbly oscillation.
## Typical range: 5.0 to 30.0.
@export_range(0.0, 50.0, 0.1) var damping: float = 18.0

## Base maximum force the player can apply (arm strength). Mass will resist this.
## Typical range: 200.0 to 1000.0.
@export_range(0.0, 2000.0, 10.0) var max_force: float = 500.0

## Distance at which the "grip" breaks if the object is stuck behind walls or too heavy.
## Typical range: 1.5 to 5.0 meters.
@export_range(0.5, 10.0, 0.1) var break_distance: float = 2.5

## How strongly the player's wrist tries to align the object with the camera orientation.
## Typical range: 10.0 (slow/loose alignment) to 100.0 (quick/snappy alignment).
@export_range(0.0, 200.0, 1.0) var torque_stiffness: float = 30.0

## How much rotational swing is dampened to prevent spin oscillation.
## Typical range: 1.0 to 20.0.
@export_range(0.0, 50.0, 0.1) var torque_damping: float = 8.0

## Base maximum wrist torque the player can apply. Mass and gravity will resist this.
## Typical range: 20.0 to 200.0.
@export_range(0.0, 500.0, 5.0) var max_torque: float = 100.0

## Frame-rate independent rotational damping multiplier applied each frame to stabilize rotation.
## Typical range: 0.85 to 0.99. Lower values damp rotation faster.
@export_range(0.5, 1.0, 0.01) var held_angular_damping: float = 0.95

## Default distance at which the object is held in front of the camera.
## Typical range: 1.0 to 3.0 meters.
@export_range(0.5, 10.0, 0.1) var default_hold_distance: float = 2.0

## Minimum distance the object can be scrolled closer to the player.
## Typical range: 0.5 to 1.5 meters.
@export_range(0.2, 5.0, 0.1) var min_hold_distance: float = 1.0

## Maximum distance the object can be scrolled away from the player.
## Typical range: 3.0 to 8.0 meters.
@export_range(1.0, 15.0, 0.1) var max_hold_distance: float = 5.0

## How fast scroll wheel adjustments change the holding distance.
## Typical range: 0.05 to 0.5.
@export_range(0.01, 1.0, 0.01) var zoom_speed: float = 0.15

## If true, scrolling up brings the object closer (standard zoom behavior).
## If false, scrolling up pushes the object away.
@export var scroll_up_brings_closer: bool = true

## Multiplier for gravity droop scaling based on weight and grab offset.
## Typical range: 0.01 to 0.2.
@export_range(0.0, 1.0, 0.01) var droop_multiplier: float = 0.05

## Maximum blend strength towards downward hanging direction (droop limit).
## Typical range: 0.0 (no droop) to 1.0 (fully hanging down).
@export_range(0.0, 1.0, 0.05) var max_droop: float = 0.75

@onready var character: Player = get_parent() as Player

var held_body: RigidBody3D = null
var current_pickup: Pickupable = null
var hold_distance: float = 2.0
var grab_offset: Vector3 = Vector3.ZERO
var grab_relative_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	# Resolve camera node fallback dynamically
	if not camera_3d:
		if character and character.camera_3d:
			camera_3d = character.camera_3d
		elif hold_position:
			camera_3d = hold_position.get_parent() as Camera3D
	
	hold_distance = default_hold_distance

func _unhandled_input(event: InputEvent) -> void:
	if not WindowManager.is_mouse_captured():
		return
		
	if event.is_action_pressed("primary_action"):
		_try_pickup()
	elif event.is_action_released("primary_action"):
		_release()
	elif event is InputEventMouseButton and event.pressed:
		if held_body:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_throw()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if scroll_up_brings_closer:
					hold_distance = clamp(hold_distance - zoom_speed, min_hold_distance, max_hold_distance)
				else:
					hold_distance = clamp(hold_distance + zoom_speed, min_hold_distance, max_hold_distance)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if scroll_up_brings_closer:
					hold_distance = clamp(hold_distance + zoom_speed, min_hold_distance, max_hold_distance)
				else:
					hold_distance = clamp(hold_distance - zoom_speed, min_hold_distance, max_hold_distance)
				get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if not held_body:
		return

	var camera_node = camera_3d
	if not camera_node:
		camera_node = hold_position if hold_position else self

	# Calculate target position for the grab point in front of the camera
	var target_pos = camera_node.global_position - camera_node.global_transform.basis.z * hold_distance
	
	# Transform the local grab offset into global coordinates relative to body center
	var global_grab_offset = held_body.to_global(grab_offset) - held_body.global_position
	
	# The target position of the body's center of mass is shifted by the grab offset
	var target_center_pos = target_pos - global_grab_offset
	var current_pos = held_body.global_position
	
	# Check for break condition using distance from grab point to target position
	var current_grab_pos = current_pos + global_grab_offset
	var dist = current_grab_pos.distance_to(target_pos)
	if dist > break_distance:
		_release()
		return

	# Calculate linear spring-damper force pulling the center of mass to target center
	# Use an effective mass floor of 1.0 kg for acceleration scaling (keeps lightweight items stable)
	var effective_mass = max(held_body.mass, 1.0)
	var dir = target_center_pos - current_pos
	var spring_force = dir * stiffness
	var velocity = held_body.linear_velocity
	var damping_force = velocity * damping
	var total_force = (spring_force - damping_force) * (held_body.mass / effective_mass)

	# Apply Dynamic Arm Strength Limit
	var strength_limit = max_force
	if character:
		strength_limit = max_force * character.player_strength

	if total_force.length() > strength_limit:
		total_force = total_force.normalized() * strength_limit

	# Always apply force centrally to prevent any linear-vs-rotational physics engine jitter
	held_body.apply_central_force(total_force)

	# Get the actual computed inertia of the body
	var body_inertia = _get_body_inertia(held_body)

	# Inertia factor to keep angular acceleration stable for tiny items
	var min_inertia = 0.1
	var effective_inertia = Vector3(
		max(body_inertia.x, min_inertia),
		max(body_inertia.y, min_inertia),
		max(body_inertia.z, min_inertia)
	)

	# Procedural Droop: Tilt the target orientation downwards based on mass and grab offset.
	# This creates a stable, physics-safe hanging effect without torque feedback loops.
	var droop_strength = clamp(held_body.mass * grab_offset.length() * droop_multiplier, 0.0, max_droop)
	
	# Calculate target basis from initial relative rotation to camera
	var target_basis = camera_node.global_transform.basis * grab_relative_basis
	var target_up = target_basis.y
	var target_forward = -target_basis.z
	
	if droop_strength > 0.0:
		target_forward = target_forward.lerp(Vector3.DOWN, droop_strength).normalized()
		var target_right = target_forward.cross(target_basis.y).normalized()
		if target_right == Vector3.ZERO:
			target_right = target_forward.cross(target_basis.x).normalized()
		target_up = target_right.cross(target_forward).normalized()
		target_basis = Basis(target_right, target_up, -target_forward)

	# Wrist Alignment Torque (Quaternion PD Controller to keep it oriented with camera)
	# Calculate the rotation difference: target = diff * current => diff = target * current.inverse
	var rotation_difference: Basis = target_basis * held_body.global_transform.basis.inverse()
	var error_quaternion: Quaternion = rotation_difference.get_rotation_quaternion().normalized()
	
	var angle = error_quaternion.get_angle()
	var axis = error_quaternion.get_axis()
	
	if angle > PI:
		angle -= 2.0 * PI
		
	var alignment_torque = axis * angle * torque_stiffness
	var damping_torque = held_body.angular_velocity * torque_damping
	var desired_torque = alignment_torque - damping_torque

	# Transform the torque to local space to scale by the principal moments of inertia
	var local_torque = held_body.global_transform.basis.inverse() * desired_torque
	local_torque = local_torque * effective_inertia
	
	# Transform the computed torque back to global space
	var total_torque = held_body.global_transform.basis * local_torque

	var torque_limit = max_torque
	if character:
		torque_limit = max_torque * character.player_strength

	if total_torque.length() > torque_limit:
		total_torque = total_torque.normalized() * torque_limit

	held_body.apply_torque(total_torque)

	# Apply additional rotational damping (stabilizing)
	held_body.angular_velocity *= held_angular_damping

func _try_pickup() -> void:
	if not interactor or not interactor.current_target:
		return
		
	var target = interactor.current_target
	var pickupable = _find_pickupable(target)
	
	if pickupable:
		var limit = 50.0
		if character:
			limit = character.get_lift_strength()
			
		if pickupable.can_pickup(limit):
			held_body = pickupable.body
			current_pickup = pickupable
			
			var camera_node = camera_3d
			if not camera_node:
				camera_node = hold_position if hold_position else self
				
			# Calculate grab offset to ensure it pivots around the click point
			var ray = interactor.raycast
			if ray and ray.is_colliding() and (ray.get_collider() == held_body or held_body.is_ancestor_of(ray.get_collider())):
				var hit_point = ray.get_collision_point()
				grab_offset = held_body.to_local(hit_point)
				hold_distance = clamp(camera_node.global_position.distance_to(hit_point), min_hold_distance, max_hold_distance)
			else:
				# Smooth camera-ray projection fallback if grabbed via proximity area
				var dist = camera_node.global_position.distance_to(held_body.global_position)
				var estimated_hit = camera_node.global_position - camera_node.global_transform.basis.z * dist
				grab_offset = held_body.to_local(estimated_hit)
				hold_distance = clamp(dist, min_hold_distance, max_hold_distance)
			
			# Setup physics state
			held_body.gravity_scale = 1.0
			held_body.sleeping = false
			
			# Save initial relative rotation to camera to prevent snapping
			var camera_basis = camera_node.global_transform.basis
			var body_basis = held_body.global_transform.basis
			grab_relative_basis = camera_basis.inverse() * body_basis

			# Disable collisions with carrying character to avoid glitches
			if character:
				held_body.add_collision_exception_with(character)
			
			current_pickup.on_picked_up()
			carry_weight_changed.emit(held_body.mass)
		else:
			# Straining shake feedback if player tried to lift something too heavy
			if character and character.has_method("apply_camera_shake"):
				character.apply_camera_shake(0.04, 0.2)

func _release() -> void:
	if not held_body:
		return
	
	held_body.gravity_scale = 1.0
	
	# Restore collision exception
	if character:
		held_body.remove_collision_exception_with(character)
	
	if current_pickup:
		current_pickup.on_dropped()
		
	held_body = null
	current_pickup = null
	carry_weight_changed.emit(0.0)

func _throw() -> void:
	if not held_body or not current_pickup:
		return
		
	var body_ref = held_body
	var pickup_ref = current_pickup
	
	var camera_node = camera_3d
	if not camera_node:
		camera_node = hold_position if hold_position else self
		
	var dir = -camera_node.global_transform.basis.z.normalized()
	
	# Calculate throw speed scaled by player strength and item mass
	var strength = 1.0
	if character:
		strength = character.player_strength
		
	var base_force = pickup_ref.throw_force * strength
	var mass_factor = max(body_ref.mass, 1.0)
	var throw_speed = (base_force * 1.2) / sqrt(mass_factor)
	
	# Inherit character movement velocity and add the throw velocity
	var char_vel = character.velocity if character else Vector3.ZERO
	body_ref.linear_velocity = char_vel + dir * throw_speed
	
	# Give a subtle, mass-scaled rotation tumble
	var spin_speed = 1.0 / sqrt(mass_factor)
	body_ref.angular_velocity = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized() * spin_speed
	
	# Release first to restore collision and reset states
	_release()
	
	# Throw physical kickback shake
	if character and character.has_method("apply_camera_shake"):
		var shake_strength = clamp(base_force * 0.002, 0.015, 0.04)
		character.apply_camera_shake(shake_strength, 0.15)

func _find_pickupable(node: Node) -> Pickupable:
	if not node:
		return null
	if node is Pickupable:
		return node
	if node is Interactable and node.denial_provider is Pickupable:
		return node.denial_provider
		
	for child in node.get_children():
		if child is Pickupable:
			return child
			
	var parent = node.get_parent()
	if not parent:
		return null
	
	for child in parent.get_children():
		if child is Pickupable:
			return child
	return null

func _get_body_inertia(body: RigidBody3D) -> Vector3:
	if not body:
		return Vector3.ONE
		
	# If a manual override is set on the RigidBody3D, use it
	if body.inertia != Vector3.ZERO:
		return body.inertia
		
	# Query the physics direct state to get the auto-computed inertia diagonal
	var state = PhysicsServer3D.body_get_direct_state(body.get_rid())
	if state:
		var inv_inertia = state.inverse_inertia
		if inv_inertia.x > 0.0 and inv_inertia.y > 0.0 and inv_inertia.z > 0.0:
			return Vector3(1.0 / inv_inertia.x, 1.0 / inv_inertia.y, 1.0 / inv_inertia.z)
			
	# Fallback: estimate inertia based on bounding shape and mass
	return Vector3.ONE * body.mass
