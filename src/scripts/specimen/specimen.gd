class_name Specimen
extends CharacterBody3D

signal sleep_entered
signal action_performed(action_id: String)

# Containment chamber boundaries for clamping target positions
const CELL_MIN_X = 18.0
const CELL_MAX_X = 34.0
const CELL_MIN_Z = -18.0
const CELL_MAX_Z = -2.0

const CORNERS_XZ: Array[Vector2] = [
	Vector2(CELL_MIN_X, CELL_MIN_Z),
	Vector2(CELL_MIN_X, CELL_MAX_Z),
	Vector2(CELL_MAX_X, CELL_MIN_Z),
	Vector2(CELL_MAX_X, CELL_MAX_Z)
]

@onready var controller: SpecimenController = $SpecimenController
@onready var state_machine: SpecimenStateMachine = $SpecimenStateMachine
@onready var visuals: Node3D = $Visuals
@onready var child_placeholder: MeshInstance3D = $Visuals/ChildPlaceholder
@onready var tells: Node = $BehavioralTells
@onready var egg: MeshInstance3D = $Egg
@onready var audio_player: SpecimenAudio = get_node_or_null("AudioStreamPlayer3D") as SpecimenAudio
@onready var interactable: Interactable = get_node_or_null("Interactable")

# Idle breathing parameters (Egg phase)
var base_egg_scale: Vector3
var breathe_time: float = 0.0

# Movement and pathfinding
@export var speed: float = 3.0
## external_player: Player node reference for tracking behaviors.
@export var external_player: Node3D
var nav_agent: NavigationAgent3D
var _tracking_timer: Timer
var _current_action: String = ""
var transition_timer: float = 0.0
var _mirror_player_start: Vector3 = Vector3.ZERO
var _mirror_specimen_start: Vector3 = Vector3.ZERO
var transition_velocity: Vector3 = Vector3.ZERO

# Sleep State Configuration
var sleep_tube_pos: Vector3 = Vector3.ZERO
var _sleep_destination: Vector3 = Vector3.ZERO
var is_sleeping: bool = false
var _deep_sleeping: bool = false

# Material duplicate for reactive coloring
var egg_material: StandardMaterial3D
var child_material: StandardMaterial3D

# PLACEHOLDER: Temporary morphology tracking. Will be replaced by real Child/Adult models later.
var _last_morphology = null

func _get_reward_intensity() -> float:
	var profile = SpecimenBridge.profile
	if not profile:
		return 0.5
	return clamp((profile.reward_schema + 50.0) / 100.0, 0.0, 1.0)

func _get_target_scale() -> Vector3:
	var profile = SpecimenBridge.profile
	if not profile:
		return Vector3.ONE
	return Vector3.ONE * clamp(profile.neural_plasticity / 50.0, 0.5, 1.5)

func _rotate_visuals_toward(target_rot_y: float, delta: float) -> void:
	visuals.rotation.y = rotate_toward(visuals.rotation.y, target_rot_y, delta * 8.0)

# PLACEHOLDER: Temporary dynamic primitive mesh generation.
func update_morphology() -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	var new_mesh: Mesh
	match profile.morphology:
		SpecimenProfile.Morphology.CUBE:
			var box = BoxMesh.new()
			box.size = Vector3(0.4, 0.4, 0.4)
			new_mesh = box
		SpecimenProfile.Morphology.SPHERE:
			var sphere = SphereMesh.new()
			sphere.radius = 0.2
			sphere.height = 0.4
			new_mesh = sphere
		SpecimenProfile.Morphology.CYLINDER:
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.2
			cylinder.bottom_radius = 0.2
			cylinder.height = 0.4
			new_mesh = cylinder
		SpecimenProfile.Morphology.TORUS:
			var torus = TorusMesh.new()
			torus.outer_radius = 0.25
			torus.inner_radius = 0.1
			new_mesh = torus
		_: # Capsule (default)
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.2
			capsule.height = 0.4
			new_mesh = capsule
			
	child_placeholder.mesh = new_mesh
	
	if child_material:
		child_placeholder.set_surface_override_material(0, child_material)

func _ready() -> void:
	# Setup dynamic NavigationAgent3D
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	nav_agent.path_desired_distance = 0.8
	nav_agent.target_desired_distance = 0.8
	add_child(nav_agent)

	# Timer for periodic target refresh
	_tracking_timer = Timer.new()
	_tracking_timer.name = "TrackingTimer"
	_tracking_timer.wait_time = 1.0
	_tracking_timer.timeout.connect(_on_tracking_timer_timeout)
	add_child(_tracking_timer)

	if interactable:
		interactable.get_custom_prompt_data = _on_get_custom_prompt_data

	if controller:
		controller.action_selected.connect(_on_action_selected)
	if nav_agent:
		nav_agent.navigation_finished.connect(_on_navigation_finished)
	
	if egg:
		base_egg_scale = egg.scale
		# Duplicate materials so we don't cause shared-resource modifications
		if egg.get_active_material(0):
			egg_material = egg.get_active_material(0).duplicate()
			egg.set_surface_override_material(0, egg_material)
			egg_material.emission_enabled = true
			egg_material.emission = Color(0, 0, 0)
			egg_material.emission_energy_multiplier = 1.0
	
	if child_placeholder:
		if child_placeholder.get_active_material(0):
			child_material = child_placeholder.get_active_material(0).duplicate()
			child_placeholder.set_surface_override_material(0, child_material)
		else:
			child_material = StandardMaterial3D.new()
			child_placeholder.set_surface_override_material(0, child_material)
			child_material.roughness = 0.5
			child_material.emission_enabled = true

	# Set up initial visibility and morphology
	var profile = SpecimenBridge.profile
	if profile:
		_last_morphology = profile.morphology
		update_morphology()
		if profile.phase == SpecimenProfile.Phase.EGG:
			if egg: egg.visible = true
			if visuals: visuals.visible = false
		else:
			if egg: egg.visible = false
			if visuals: visuals.visible = true
	sleep_tube_pos = global_position
	
	# Initialize processing states based on phase to eliminate idle loop overhead
	if profile:
		set_physics_process(profile.phase != SpecimenProfile.Phase.EGG)
		set_process(profile.phase != SpecimenProfile.Phase.ADULT)
	else:
		set_physics_process(false)
		set_process(false)

func _process(delta: float) -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	if profile.phase == SpecimenProfile.Phase.EGG:
		_process_egg_visuals(delta)
	elif profile.phase == SpecimenProfile.Phase.CHILD:
		_process_child_visuals(delta)

func _physics_process(delta: float) -> void:
	var profile = SpecimenBridge.profile
	if not profile or profile.phase == SpecimenProfile.Phase.EGG:
		return
		
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = -0.1
		
	# State machine updates behavior context and runs custom state updates
	if state_machine and state_machine.current_state:
		var context = get_state_context()
		state_machine.current_state.physics_update(context, delta)
		
	if transition_timer > 0.0:
		transition_timer -= delta
		velocity.x = transition_velocity.x
		velocity.z = transition_velocity.z
		visuals.rotate_y(delta * 15.0)
		if transition_timer <= 0.0:
			visuals.rotation.y = 0.0
	else:
		if not _deep_sleeping:
			var move_dir = Vector3.ZERO
			if nav_agent and not nav_agent.is_navigation_finished():
				var next_path_pos = nav_agent.get_next_path_position()
				var diff = next_path_pos - global_position
				diff.y = 0.0
				if diff.length() > 0.05:
					move_dir = diff.normalized()
					
			var target_vel = move_dir * speed
			velocity.x = target_vel.x
			velocity.z = target_vel.z
			
			if move_dir != Vector3.ZERO:
				var auto_rotate = true
				if state_machine and state_machine.current_state:
					auto_rotate = state_machine.current_state.auto_rotate_visuals
				if auto_rotate:
					var target_rot_y = atan2(-move_dir.x, -move_dir.z)
					_rotate_visuals_toward(target_rot_y, delta)
					
	move_and_slide()

func _process_egg_visuals(delta: float) -> void:
	var is_distressed = false
	var env = EnvironmentBridge.profile
	if env:
		is_distressed = not env.is_heat_optimal() or not env.is_moisture_optimal()
		
	var breathe_speed = 3.5 if is_distressed else 1.5
	var breathe_amplitude = 0.08 if is_distressed else 0.03
	
	breathe_time += delta * breathe_speed
	var scale_factor = 1.0 + sin(breathe_time) * breathe_amplitude
	egg.scale = base_egg_scale * scale_factor
	
	if egg_material:
		if is_distressed:
			var pulse = (sin(breathe_time * 2.0) + 1.0) * 0.5
			var warning_color = Color(0.9, 0.15, 0.1).lerp(Color(0.9, 0.5, 0.1), pulse)
			egg_material.albedo_color = Color(0.9, 0.4, 0.3)
			egg_material.emission = warning_color
			egg_material.emission_energy_multiplier = 1.5
		else:
			egg_material.albedo_color = Color(0.9, 0.9, 0.95)
			egg_material.emission = Color(0.1, 0.15, 0.2)
			egg_material.emission_energy_multiplier = 0.3

func _process_child_visuals(delta: float) -> void:
	var profile = SpecimenBridge.profile
	if profile and child_material:
		if profile.morphology != _last_morphology:
			_last_morphology = profile.morphology
			update_morphology()
			
			transition_timer = 2.0
			transition_velocity = -global_transform.basis.z * 1.5
			
			var target_scale = _get_target_scale()
			var pop_tween = create_tween()
			pop_tween.tween_property(visuals, "scale", target_scale * 1.3, 0.15)\
				.set_trans(Tween.TRANS_BACK)\
				.set_ease(Tween.EASE_OUT)
			pop_tween.tween_property(visuals, "scale", target_scale, 0.25)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN_OUT)
		else:
			var target_scale = _get_target_scale()
			visuals.scale = visuals.scale.lerp(target_scale, delta * 2.0)
		
		var threat_ratio = profile.threat_indexing / 100.0
		var base_color = Color(0.2, 0.6, 0.9).lerp(Color(0.8, 0.1, 0.7), threat_ratio)
		child_material.albedo_color = base_color
		
		var reward_intensity = _get_reward_intensity()
		child_material.emission = base_color * reward_intensity
		child_material.emission_energy_multiplier = reward_intensity * 2.0

func hatch() -> void:
	var profile = SpecimenBridge.profile
	if not profile or profile.phase != SpecimenProfile.Phase.EGG:
		return
		
	profile.phase = SpecimenProfile.Phase.CHILD
	
	set_physics_process(true)
	set_process(true)
	
	_last_morphology = profile.morphology
	update_morphology()
	
	var base_egg_rot = egg.rotation
	var shake_tween = create_tween().set_loops(4)
	shake_tween.tween_property(egg, "rotation:z", base_egg_rot.z + 0.1, 0.07)
	shake_tween.tween_property(egg, "rotation:z", base_egg_rot.z - 0.1, 0.07)
	shake_tween.tween_callback(func(): egg.rotation = base_egg_rot)
	
	var transition_tween = create_tween().set_parallel(true)
	transition_tween.tween_property(egg, "scale", Vector3.ZERO, 0.8)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
		
	visuals.visible = true
	visuals.scale = Vector3.ZERO
	transition_tween.tween_property(visuals, "scale", Vector3.ONE, 0.8)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	transition_tween.chain().tween_callback(func():
		egg.visible = false
		controller.activate()
		if tells.has_method("update_tells"):
			tells.update_tells()
		print("Specimen has hatched into a CHILD!")
	)

func _get_player_position() -> Vector3:
	if external_player and is_instance_valid(external_player):
		return external_player.global_position
	return Vector3.ZERO

func _find_placed_objects_in_cell() -> Array[Node3D]:
	var objects: Array[Node3D] = []
	if not is_inside_tree():
		return objects
	var root = get_tree().root
	if root:
		_collect_rigid_bodies_in_cell(root, objects)
	return objects

func _collect_rigid_bodies_in_cell(node: Node, out_list: Array[Node3D]) -> void:
	if node is RigidBody3D:
		var pos = node.global_position
		if pos.x >= CELL_MIN_X and pos.x <= CELL_MAX_X \
				and pos.z >= CELL_MIN_Z and pos.z <= CELL_MAX_Z:
			out_list.append(node)
	for child in node.get_children():
		_collect_rigid_bodies_in_cell(child, out_list)

func get_state_context() -> SpecimenStateMachine.StateContext:
	var context = SpecimenStateMachine.StateContext.new()
	context.global_position = global_position
	context.player_pos = _get_player_position()
	context.placed_objects = _find_placed_objects_in_cell()
	context.player_start = _mirror_player_start
	context.specimen_start = _mirror_specimen_start
	context.sleep_tube_pos = sleep_tube_pos
	return context

func play_vocalize_tell(identity_coherence: float) -> void:
	if audio_player:
		audio_player.play_vocalize(identity_coherence)
	if child_material:
		var vocal_tween = create_tween()
		vocal_tween.tween_property(child_material, "emission_energy_multiplier", 4.0, 0.1)
		vocal_tween.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.1)
		vocal_tween.tween_property(child_material, "emission_energy_multiplier", 4.0, 0.1)
		vocal_tween.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.3)

func play_display_tell() -> void:
	if visuals:
		var pulse_tween = create_tween()
		var base_scale = _get_target_scale()
		pulse_tween.tween_property(visuals, "scale", base_scale * 1.4, 0.2)\
			.set_trans(Tween.TRANS_ELASTIC)\
			.set_ease(Tween.EASE_OUT)
		pulse_tween.tween_property(visuals, "scale", base_scale, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	
	if child_material:
		var flare_tween = create_tween()
		flare_tween.tween_property(child_material, "emission_energy_multiplier", 6.0, 0.2)
		flare_tween.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.4)

func play_play_tell() -> void:
	if visuals:
		var play_tween = create_tween()
		play_tween.tween_property(visuals, "rotation:y", visuals.rotation.y + (PI * 2.0), 0.6)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN_OUT)
	if child_material:
		var play_flare = create_tween()
		play_flare.tween_property(child_material, "emission_energy_multiplier", 3.0, 0.2)
		play_flare.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.4)

func apply_emission_dim(energy_multiplier: float, duration: float) -> void:
	if child_material:
		var dim_tween = create_tween()
		dim_tween.tween_property(child_material, "emission_energy_multiplier", energy_multiplier, duration)

func restore_standard_emission() -> void:
	if child_material:
		var reward_intensity = _get_reward_intensity()
		var restore_tween = create_tween()
		restore_tween.tween_property(child_material, "emission_energy_multiplier", reward_intensity * 2.0, 0.5)

func look_at_position(target_pos: Vector3, delta: float) -> void:
	var dir = (target_pos - global_position).normalized()
	var target_rot_y = atan2(-dir.x, -dir.z)
	_rotate_visuals_toward(target_rot_y, delta)

func turn_away_from_glass(delta: float) -> void:
	var target_rot_y = atan2(-1.0, 0.0)
	_rotate_visuals_toward(target_rot_y, delta)

func _on_tracking_timer_timeout() -> void:
	if state_machine and state_machine.current_state:
		var context = get_state_context()
		state_machine.current_state.handle_tracking_timeout(context)

func _on_navigation_finished() -> void:
	if state_machine and state_machine.current_state:
		var context = get_state_context()
		state_machine.current_state.handle_navigation_finished(context)

func _on_action_selected(action_id: String) -> void:
	_on_action_performed(action_id)

func _on_action_performed(action_id: String) -> void:
	var action = SpecimenStateMachine.string_to_action(action_id)
	var profile = SpecimenBridge.profile
	
	if profile and not is_sleeping:
		var cost = 1.0
		match action:
			SpecimenStateMachine.Action.DISPLAY, SpecimenStateMachine.Action.PLAY:
				cost = 2.0
			SpecimenStateMachine.Action.APPROACH_PLAYER, SpecimenStateMachine.Action.RETREAT, \
			SpecimenStateMachine.Action.VOCALIZE, SpecimenStateMachine.Action.MIRROR_PLAYER, \
			SpecimenStateMachine.Action.REFUSE_INTERACTION:
				cost = 1.0
			SpecimenStateMachine.Action.INVESTIGATE, SpecimenStateMachine.Action.WASTE_BEHAVIOR:
				cost = 0.5
			SpecimenStateMachine.Action.SLEEP_EARLY:
				cost = 0.0
		
		var energy_depleted = (profile.energy - cost) <= 0.0
		
		# Deduct energy
		profile.energy = max(profile.energy - cost, 0.0)
		
		if action != SpecimenStateMachine.Action.SLEEP_EARLY and not energy_depleted:
			profile.log_action(action_id)
			if controller:
				controller.confirm_action(action_id)
			action_performed.emit(action_id)
			print("Specimen performed action: ", action_id, " | Energy cost: ", cost, " | Remaining energy: ", profile.energy)
			
		elif action == SpecimenStateMachine.Action.SLEEP_EARLY:
			if controller:
				controller.confirm_action(action_id)
			action_performed.emit(action_id)
			print("Specimen performed action: ", action_id, " | Energy cost: 0.0 | Remaining energy: ", profile.energy)
			
			enter_sleep(SpecimenStateMachine.Action.SLEEP_EARLY)
			return
			
		elif energy_depleted:
			print("Specimen action cancelled due to energy depletion. Entering sleep.")
			enter_sleep(SpecimenStateMachine.Action.SLEEP)
			return
			
	_current_action = action_id
	state_machine.transition_to(action)

func enter_sleep(action: SpecimenStateMachine.Action = SpecimenStateMachine.Action.SLEEP) -> void:
	if is_sleeping:
		return
	is_sleeping = true
	_deep_sleeping = false
	_current_action = SpecimenStateMachine.action_to_string(action)
	if controller:
		controller.deactivate()
		controller.active_action = _current_action
		
	state_machine.transition_to(action)
	sleep_entered.emit()
	print("Specimen: Entering SLEEP state via action: ", _current_action, "... Walking to destination: ", _sleep_destination)

func wake_up() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	_deep_sleeping = false
	_current_action = "PLAY"
	set_physics_process(true)
	
	var profile = SpecimenBridge.profile
	if profile:
		profile.energy = profile.get_max_energy()
		restore_standard_emission()
		if profile.phase != SpecimenProfile.Phase.ADULT:
			set_process(true)
			
	if controller:
		controller.activate()
		
	state_machine.transition_to(SpecimenStateMachine.Action.PLAY)
	print("Specimen: Woke up! Resuming actions. Energy restored to: ", profile.energy if profile else 0.0)

func apply_sleep_interaction(action_type: String) -> void:
	var profile = SpecimenBridge.profile
	if not profile or not is_sleeping:
		return
		
	if action_type == "PET":
		profile.apply_delta("resonance_frequency", 4.0)
		profile.apply_delta("reward_schema", 3.0)
		profile.apply_delta("identity_coherence", 1.0)
		print("Specimen: Received PET during sleep.")
		
	elif action_type == "SHOCK":
		profile.apply_delta("reward_schema", -8.0)
		profile.apply_delta("identity_coherence", -5.0)
		profile.apply_delta("resonance_frequency", 3.0)
		print("Specimen: Received SHOCK during sleep. Waking up immediately.")
		wake_up()

func _on_phase_transitioned(new_phase: SpecimenProfile.Phase) -> void:
	if new_phase == SpecimenProfile.Phase.CHILD:
		set_physics_process(true)
		set_process(true)
	elif new_phase == SpecimenProfile.Phase.ADULT:
		set_physics_process(true)
		set_process(false)

func _on_get_custom_prompt_data(_by_whom: Node = null) -> Dictionary:
	var action_name = _current_action
	var display_action = action_name.replace("_", " ").capitalize()
	if display_action == "":
		display_action = "None"
		
	var key_text = "E"
	if InputMap.has_action("interact"):
		var events = InputMap.action_get_events("interact")
		for event in events:
			if event is InputEventKey:
				key_text = OS.get_keycode_string(event.physical_keycode)
				break
			elif event is InputEventMouseButton:
				match event.button_index:
					MOUSE_BUTTON_LEFT: key_text = "LMB"
					MOUSE_BUTTON_RIGHT: key_text = "RMB"
					MOUSE_BUTTON_MIDDLE: key_text = "MMB"
					_: key_text = "Mouse " + str(event.button_index)
				break
				
	return {
		"prompt_text_override": "Press [%s] to Condition Specimen\nCurrent Action: %s" % [key_text, display_action]
	}
