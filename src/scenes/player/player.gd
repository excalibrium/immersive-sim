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

# --- SHOOTER & IK NODES ---
@onready var skeleton: Skeleton3D = $PlayerModel/Armature/Skeleton3D
@onready var left_hand_ik: IKModifier3D = $PlayerModel/Armature/Skeleton3D/LeftHandIK
@onready var right_hand_ik: TwoBoneIK3D = $PlayerModel/Armature/Skeleton3D/RightHandIK
@onready var neck_attachment: BoneAttachment3D = $PlayerModel/Armature/Skeleton3D/NeckAttachment
@onready var handL_attachment: BoneAttachment3D = $PlayerModel/Armature/Skeleton3D/HandLAttachment
@onready var gun: Gun = $"Camera3D/GunAnchor/74ka"
@onready var shoot_raycast: RayCast3D = $Camera3D/ShootRayCast
@onready var anim_player: AnimationPlayer = $PlayerModel/AnimationPlayer

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
		
	# Dynamic IK setup from gun markers
	if gun and left_hand_ik and right_hand_ik:
		var hand_l = gun.get_node_or_null("barrelholder/barrel/hand_L")
		if hand_l:
			left_hand_ik.set_target_node(0, left_hand_ik.get_path_to(hand_l))
			
		var hand_r = gun.get_node_or_null("barrelholder/handle/hand_R")
		if hand_r:
			right_hand_ik.set_target_node(0, right_hand_ik.get_path_to(hand_r))
			
	# Start idle animation
	if anim_player:
		anim_player.play("gun_idle")

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

func _process(delta: float) -> void:
	if TimeManager.time_scale <= 0.0:
		return
		
	# 1. Update Camera Position to follow Neck Bone
	if neck_attachment and camera_3d:
		# Add 0.15m vertical offset to neck attachment to position at eye level
		camera_3d.global_position = neck_attachment.global_position + Vector3(0, 0.15, 0)
	# 2. Hide Head Bone to prevent camera clipping (do every frame to override animation rest poses)
	if skeleton:
		var head_bone = skeleton.find_bone("Head")
		if head_bone != -1:
			skeleton.set_bone_pose_scale(head_bone, Vector3.ZERO)
			
	# 3. Update Model Animations
	_update_animations()

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
	
	# Determine acceleration (low air control vs high ground control)
	var accel = 100.0 if is_on_floor() else 5.0

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * final_speed, accel * scaled_delta)
		velocity.z = move_toward(velocity.z, direction.z * final_speed, accel * scaled_delta)
	else:
		velocity.x = move_toward(velocity.x, 0, accel * scaled_delta)
		velocity.z = move_toward(velocity.z, 0, accel * scaled_delta)

	_handle_states(delta)
	
	# Handle shooting input
	if Input.is_action_pressed("shoot"):
		_shoot_gun()
		
	# Handle reload input
	if Input.is_key_pressed(KEY_R):
		if gun and gun.current_ammo < gun.max_ammo:
			gun.reload()
	
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
		
		# Dynamically scale and position the player model based on height
		if has_node("PlayerModel"):
			var model = $PlayerModel
			model.scale.y = collision_shape.shape.height / STAND_HEIGHT
			model.position.y = -collision_shape.shape.height / 2.0
	
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
	velocity.y = JUMP_VELOCITY * TimeManager.time_scale
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

func _state_climbing(delta: float):
	velocity.y = 0
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.y != 0:
		velocity.y = -input_dir.y * RUN_SPEED * TimeManager.time_scale
	
	if is_on_floor() and input_dir.y >= 0:
		current_state = State.RUNNING

func _state_wall_running(delta: float):
	if is_on_floor():
		current_state = State.RUNNING

func _update_animations() -> void:
	if not anim_player:
		return
		
	if current_state == State.CLIMBING:
		if anim_player.current_animation != "Wallrun":
			anim_player.play("Wallrun")
		anim_player.speed_scale = 1.0
	elif not is_on_floor():
		if anim_player.current_animation != "Fall":
			anim_player.play("Fall")
		anim_player.speed_scale = 1.0
	elif velocity.length() > 0.1:
		if anim_player.current_animation != "Run":
			anim_player.play("Run")
		anim_player.speed_scale = 1.5 if current_state == State.SPRINTING else 1.0
	else:
		if anim_player.current_animation != "gun_idle":
			anim_player.play("gun_idle")
		anim_player.speed_scale = 1.0

func _shoot_gun() -> void:
	if not gun:
		return
		
	if gun.shoot():
		# Spawn tracers and do hitscan hit detection from the camera raycast
		var muzzle_pos = gun.muzzle.global_position
		var hit_pos = muzzle_pos + (-camera_3d.global_basis.z * 100.0) # Default path if miss
		var hit_normal = camera_3d.global_basis.z
		
		if shoot_raycast:
			shoot_raycast.force_raycast_update()
			if shoot_raycast.is_colliding():
				hit_pos = shoot_raycast.get_collision_point()
				hit_normal = shoot_raycast.get_collision_normal()
				
				# Damage interface
				var collider = shoot_raycast.get_collider()
				if collider and collider.has_method("take_damage"):
					collider.take_damage(gun.damage)
					
				# Spawn spark particles at collision point
				_spawn_impact_effect(hit_pos, hit_normal)
				
		# Spawn glowing bullet tracer
		_spawn_tracer(muzzle_pos, hit_pos)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var tracer = MeshInstance3D.new()
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(tracer)
	else:
		get_tree().root.add_child(tracer)
		
	var dist = from.distance_to(to)
	if dist < 0.01:
		tracer.queue_free()
		return
		
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.008
	cylinder.bottom_radius = 0.008
	cylinder.height = dist
	cylinder.radial_segments = 4
	tracer.mesh = cylinder
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.8) # Bright orange-yellow tracer
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat
	
	# Align tracer stretch
	tracer.global_position = from.lerp(to, 0.5)
	tracer.look_at(to, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	
	# Quickly fade out and clean up
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(tracer.queue_free)

func _spawn_impact_effect(pos: Vector3, normal: Vector3) -> void:
	var impact = Node3D.new()
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(impact)
	else:
		get_tree().root.add_child(impact)
		
	impact.global_position = pos
	
	if not normal.is_equal_approx(Vector3.UP) and not normal.is_equal_approx(Vector3.DOWN):
		impact.look_at(pos + normal, Vector3.UP)
	else:
		impact.look_at(pos + normal, Vector3.FORWARD)
		
	var particles = CPUParticles3D.new()
	impact.add_child(particles)
	
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.25
	particles.explosiveness = 1.0
	particles.spread = 30.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 4.5
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, 0.03)
	particles.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.65, 0.15) # Gold sparks
	particles.material_override = mat
	
	# Clean up after particles lifetime
	var timer = get_tree().create_timer(0.35)
	timer.timeout.connect(impact.queue_free)
