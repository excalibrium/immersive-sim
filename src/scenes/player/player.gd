extends CharacterBody3D

# --- CONSTANTS ---
const RUN_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const CROUCH_HEIGHT = 1.0
const STAND_HEIGHT = 2.0

# --- STATE MACHINE ---
enum State { RUNNING, SPRINTING, CROUCHING, CLIMBING, WALL_RUNNING }
var current_state: State = State.RUNNING

# --- NODES ---
@export var camera_3d : Camera3D
@onready var collision_shape : CollisionShape3D = $CollisionShape3D

# --- MOVEMENT VARIABLES ---
var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0
var coyote_time: float = 0.1
var coyote_timer: float = 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Fallback if not assigned in inspector
	if not camera_3d:
		camera_3d = get_node_or_null("Camera3D")

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if camera_3d:
			camera_3d.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	# Release mouse / Open Pause Menu
	if event.is_action_pressed("ui_cancel"):
		if TimeManager.time_scale > 0.0:
			var pause_menu_scene = load("res://src/scenes/ui/PauseMenu.tscn")
			var pause_menu = pause_menu_scene.instantiate()
			get_tree().root.add_child(pause_menu)
		else:
			# If already paused, we don't spawn another one
			pass

func _physics_process(delta: float) -> void:
	if TimeManager.time_scale <= 0.0:
		return
		
	var scaled_delta = TimeManager.get_scaled_delta(delta)
	
	# Add the gravity.
	if not is_on_floor() and current_state != State.CLIMBING:
		velocity += get_gravity() * scaled_delta

	# Handle jump buffer (uses real delta for consistent responsiveness)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	# State Transitions (uses real delta for camera smoothness)
	_update_state(delta)

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var target_speed = RUN_SPEED
	match current_state:
		State.SPRINTING:
			target_speed = SPRINT_SPEED
		State.CROUCHING:
			target_speed = CROUCH_SPEED
		State.CLIMBING:
			target_speed = RUN_SPEED

	# Apply time scale to target speed
	var final_speed = target_speed * TimeManager.time_scale

	if direction:
		velocity.x = direction.x * final_speed
		velocity.z = direction.z * final_speed
	else:
		velocity.x = move_toward(velocity.x, 0, final_speed)
		velocity.z = move_toward(velocity.z, 0, final_speed)

	_handle_states(delta)
	
	move_and_slide()

func _update_state(delta: float):
	if current_state == State.CLIMBING or current_state == State.WALL_RUNNING:
		return

	if Input.is_action_pressed("crouch"):
		current_state = State.CROUCHING
	elif Input.is_action_pressed("sprint") and is_on_floor():
		current_state = State.SPRINTING
	else:
		current_state = State.RUNNING
	
	# Handle height change
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var target_height = STAND_HEIGHT
		if current_state == State.CROUCHING:
			target_height = CROUCH_HEIGHT
		
		var prev_height = collision_shape.shape.height
		collision_shape.shape.height = move_toward(prev_height, target_height, delta * 8.0)
		
		# Keep feet on the ground by offsetting position
		var height_diff = prev_height - collision_shape.shape.height
		position.y -= height_diff / 2.0
		
		if camera_3d:
			# Keep camera 0.5 units below the top of the capsule
			camera_3d.position.y = (collision_shape.shape.height / 2.0) - 0.5
	
func _handle_states(delta: float):
	match current_state:
		State.RUNNING, State.SPRINTING, State.CROUCHING:
			_apply_movement_logic(delta)
		State.CLIMBING:
			_state_climbing(delta)
		State.WALL_RUNNING:
			_state_wall_running(delta)

func _apply_movement_logic(delta: float):
	if is_on_floor():
		coyote_timer = coyote_time
		if jump_buffer_timer > 0.0:
			_jump()
	else:
		coyote_timer -= delta
		# Late coyote jump
		if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			_jump()

func _jump():
	# Scaling jump velocity ensures the player jumps at the same "game speed" 
	# but moves at the correct "real speed" for the current time scale.
	velocity.y = JUMP_VELOCITY * TimeManager.time_scale
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

func _state_climbing(delta: float):
	# Basic climbing logic
	velocity.y = 0
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.y != 0:
		velocity.y = -input_dir.y * RUN_SPEED * TimeManager.time_scale
	
	if is_on_floor() and input_dir.y >= 0:
		current_state = State.RUNNING

func _state_wall_running(delta: float):
	# Placeholder for wall running
	if is_on_floor():
		current_state = State.RUNNING
