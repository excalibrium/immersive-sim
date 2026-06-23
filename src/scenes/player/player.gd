extends CharacterBody3D
class_name Player

# --- CONSTANTS ---
const RUN_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5
var mouse_sensitivity = 0.002
var joy_sensitivity = 0.03
const CROUCH_HEIGHT = 0.72
const STAND_HEIGHT = 1.8

# --- STATE MACHINE ---
enum State { RUNNING, SPRINTING, CROUCHING, CLIMBING, WALL_RUNNING }
var current_state: State = State.RUNNING

# --- PLAYER STATS / STRENGTH ---
@export var player_strength: float = 1.0

# --- CARRYING MODIFIERS ---
var carry_speed_modifier: float = 1.0
var carry_can_sprint: bool = true
var carry_can_jump: bool = true

# --- HELD ITEM SYSTEM ---
signal held_item_changed(new_item: ItemResource)
var active_item_id: String = ""
var player_pickup: PlayerPickup = null

# --- CAMERA SHAKE SYSTEM ---
var timed_shake_intensity: float = 0.0
var timed_shake_timer: float = 0.0
var timed_shake_initial: float = 0.0
var continuous_shake_intensity: float = 0.0


# --- NODES ---
@export var camera_3d : Camera3D
@export var camera_bob_component : Node
@export var footstep_audio_component : Node3D
@onready var camera_pivot : Node3D = $CameraPivot
@onready var collision_shape : CollisionShape3D = $CollisionShape3D
@onready var held_item_visuals : Node3D = $CameraPivot/Camera3D/HeldItemVisuals

# --- MOVEMENT VARIABLES ---
var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0
var coyote_time: float = 0.1
var coyote_timer: float = 0.0

func _ready():
	# WindowManager handles initial mouse mode
	
	# Load settings
	mouse_sensitivity = Settings.get_input_setting("mouse_sensitivity")
	joy_sensitivity = Settings.get_input_setting("joy_sensitivity")
	Settings.setting_changed.connect(_on_setting_changed)
	
	# Fallback if not assigned in inspector
	if not camera_3d:
		camera_3d = get_node_or_null("CameraPivot/Camera3D")
		
	if camera_bob_component:
		camera_bob_component.footstep_stepped.connect(_on_footstep_stepped)
		
	# Connect to PlayerPickup component if present in subtree
	var pickup_node = find_child("PlayerPickup")
	if pickup_node:
		player_pickup = pickup_node as PlayerPickup
		pickup_node.carry_weight_changed.connect(_on_carry_weight_changed)
		
	# Connect to inventory manager
	if Game.inventory:
		Game.inventory.inventory_updated.connect(_on_inventory_updated)
	else:
		_connect_inventory_deferred.call_deferred()


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "input":
		if key == "mouse_sensitivity":
			mouse_sensitivity = value
		elif key == "joy_sensitivity":
			joy_sensitivity = value

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and WindowManager.is_mouse_captured():
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera_pivot:
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	# Scroll or use held item (only if not carrying a physics object)
	if WindowManager.is_mouse_captured() and player_pickup and player_pickup.held_body == null:
		if event.is_action_pressed("carry_zoom_in"):
			_scroll_held_item(1)
		elif event.is_action_pressed("carry_zoom_out"):
			_scroll_held_item(-1)
		elif event.is_action_pressed("primary_action"):
			use_held_item()
	
	# Release mouse / Open Pause Menu
	if event.is_action_pressed("back"):
		if WindowManager.is_mouse_captured():
			var pause_menu_scene = load("res://src/scenes/ui/PauseMenu.tscn")
			var pause_menu = pause_menu_scene.instantiate()
			get_tree().root.add_child(pause_menu)

func _physics_process(delta: float) -> void:
	if TimeManager.time_scale <= 0.0:
		return
		
	var scaled_delta = TimeManager.get_scaled_delta(delta)
	
	_handle_joypad_look(delta)
	
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

	# Apply time scale to target speed and incorporate carry penalties
	var final_speed = target_speed * TimeManager.time_scale * carry_speed_modifier
	
	# Determine acceleration (low air control vs high ground control)
	var accel = 100.0 if is_on_floor() else 5.0

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * final_speed, accel * scaled_delta)
		velocity.z = move_toward(velocity.z, direction.z * final_speed, accel * scaled_delta)
	else:
		velocity.x = move_toward(velocity.x, 0, accel * scaled_delta)
		velocity.z = move_toward(velocity.z, 0, accel * scaled_delta)

	_handle_states(delta)
	
	move_and_slide()
	
	if camera_bob_component:
		camera_bob_component.update_bob(velocity, is_on_floor(), delta)
	
	_update_camera_shake(delta)


func _handle_joypad_look(delta: float):
	if not WindowManager.is_mouse_captured():
		return
		
	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir.length() > 0:
		rotate_y(-look_dir.x * joy_sensitivity)
		if camera_pivot:
			camera_pivot.rotate_x(-look_dir.y * joy_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _update_state(delta: float):
	if current_state == State.CLIMBING or current_state == State.WALL_RUNNING:
		return

	if Input.is_action_pressed("crouch"):
		current_state = State.CROUCHING
	elif Input.is_action_pressed("sprint") and is_on_floor() and carry_can_sprint:
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
		
		if camera_pivot:
			# Keep camera pivot 0.5 units below the top of the capsule
			camera_pivot.position.y = (collision_shape.shape.height / 2.0) - 0.13
	
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
		if jump_buffer_timer > 0.0 and carry_can_jump:
			_jump()
	else:
		coyote_timer -= delta
		# Late coyote jump
		if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and carry_can_jump:
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

# --- PUBLIC INTERACTION API ---
func get_lift_strength() -> float:
	return 50.0 * player_strength

# --- CAMERA SHAKE SYSTEM IMPLEMENTATION ---
func apply_camera_shake(intensity: float, duration: float):
	timed_shake_intensity = intensity
	timed_shake_timer = duration
	timed_shake_initial = duration

func set_continuous_shake(intensity: float):
	continuous_shake_intensity = intensity

func _update_camera_shake(delta: float):
	if not camera_3d:
		return
		
	var total_shake = continuous_shake_intensity
	
	if timed_shake_timer > 0.0:
		timed_shake_timer -= delta
		var decay_factor = timed_shake_timer / timed_shake_initial
		total_shake += timed_shake_intensity * decay_factor
		if timed_shake_timer <= 0.0:
			timed_shake_intensity = 0.0
			timed_shake_initial = 0.0
			
	if total_shake > 0.0:
		camera_3d.h_offset = randf_range(-total_shake, total_shake)
		camera_3d.v_offset = randf_range(-total_shake, total_shake)
	else:
		camera_3d.h_offset = 0.0
		camera_3d.v_offset = 0.0

# --- CARRY SYSTEM CALLBACK ---
func _on_carry_weight_changed(mass: float):
	var strength = get_lift_strength()
	
	if mass <= 0.0:
		carry_speed_modifier = 1.0
		carry_can_sprint = true
		carry_can_jump = true
		set_continuous_shake(0.0)
	elif mass <= 5.0:
		# Lightweight category
		carry_speed_modifier = 1.0
		carry_can_sprint = true
		carry_can_jump = true
		set_continuous_shake(0.0)
	elif mass <= 20.0:
		# Medium weight category
		carry_speed_modifier = 0.8
		carry_can_sprint = false
		carry_can_jump = true
		set_continuous_shake(0.0)
	else:
		# Heavy weight category
		carry_speed_modifier = 0.5
		carry_can_sprint = false
		carry_can_jump = false
		# Continuous tremble to represent lifting tension close to max capacity
		var strain_ratio = clamp(mass / strength, 0.0, 1.0)
		set_continuous_shake(lerp(0.0, 0.008, strain_ratio))

# --- HELD ITEM SYSTEM FUNCTIONS ---
func _connect_inventory_deferred() -> void:
	if Game.inventory:
		Game.inventory.inventory_updated.connect(_on_inventory_updated)
		_on_inventory_updated()
		_update_held_item_visuals()

func _on_inventory_updated() -> void:
	# Verify that the active item is still in the inventory
	if active_item_id != "":
		var found = false
		if Game.inventory:
			for item in Game.inventory.get_items():
				if item.item_id == active_item_id:
					found = true
					break
		if not found:
			active_item_id = ""
			held_item_changed.emit(null)
			_update_held_item_visuals()

func get_held_item() -> ItemResource:
	if active_item_id == "" or not Game.inventory:
		return null
	for item in Game.inventory.get_items():
		if item.item_id == active_item_id:
			return item
	return null

func _scroll_held_item(direction: int) -> void:
	if not Game.inventory:
		return
		
	var items = Game.inventory.get_items()
	
	# Filter duplicates to have unique scrollable options
	var unique_items: Array[ItemResource] = []
	var seen_ids = {}
	for item in items:
		if not seen_ids.has(item.item_id):
			seen_ids[item.item_id] = true
			unique_items.append(item)
			
	var total_options = unique_items.size() + 1
	
	var current_index = 0
	if active_item_id != "":
		for i in range(unique_items.size()):
			if unique_items[i].item_id == active_item_id:
				current_index = i + 1
				break
				
	var new_index = (current_index + direction) % total_options
	if new_index < 0:
		new_index += total_options
		
	var old_id = active_item_id
	if new_index == 0:
		active_item_id = ""
	else:
		active_item_id = unique_items[new_index - 1].item_id
		
	if active_item_id != old_id:
		held_item_changed.emit(get_held_item())
		_update_held_item_visuals()
		get_viewport().set_input_as_handled()

func _update_held_item_visuals() -> void:
	if not held_item_visuals:
		return
		
	# Clear existing children
	for child in held_item_visuals.get_children():
		child.queue_free()
		
	var item = get_held_item()
	if item and item.visual_scene:
		var inst = item.visual_scene.instantiate()
		held_item_visuals.add_child(inst)

func use_held_item() -> void:
	if not held_item_visuals or held_item_visuals.get_child_count() == 0:
		return
		
	var active_visual = held_item_visuals.get_child(0)
	if active_visual:
		var use_comp = active_visual.get_node_or_null("ItemUseComponent")
		if use_comp and use_comp.has_method("trigger_use"):
			use_comp.trigger_use(self)

func _on_footstep_stepped() -> void:
	if is_on_floor() and current_state != State.CLIMBING:
		if footstep_audio_component:
			footstep_audio_component.play_footstep()
