class_name Specimen
extends CharacterBody3D

signal sleep_entered
signal action_performed(action_id: String)


@onready var controller: SpecimenController = $SpecimenController
@onready var visuals: Node3D = $Visuals
@onready var child_placeholder: MeshInstance3D = $Visuals/ChildPlaceholder
@onready var tells: Node = $BehavioralTells
@onready var egg: MeshInstance3D = $Egg
@onready var audio_player: SpecimenAudio = get_node_or_null("AudioStreamPlayer3D") as SpecimenAudio

# Idle breathing parameters (Egg phase)
var base_egg_scale: Vector3
var breathe_time: float = 0.0

# Movement and pathfinding
@export var speed: float = 3.0
## external_player: Player node reference for tracking behaviors (APPROACH_PLAYER, MIRROR_PLAYER, etc.).
## Assigned in the Inspector by the scene that instantiates this Specimen. Points outside the scene subtree.
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
var is_sleeping: bool = false
var _deep_sleeping: bool = false

# Material duplicate for reactive coloring
var egg_material: StandardMaterial3D
var child_material: StandardMaterial3D

# PLACEHOLDER: Temporary morphology tracking. Will be replaced by real Child/Adult models later.
var _last_morphology = null

# PLACEHOLDER: Temporary dynamic primitive mesh generation. Will load actual glTF models when they are ready.
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

	# Timer for periodic target refresh during player-tracking actions (Rule 44)
	_tracking_timer = Timer.new()
	_tracking_timer.name = "TrackingTimer"
	_tracking_timer.wait_time = 1.0
	_tracking_timer.timeout.connect(_on_tracking_timer_timeout)
	add_child(_tracking_timer)

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
		# PLACEHOLDER: Temporary morphology initial state tracking.
		_last_morphology = profile.morphology
		update_morphology()
		if profile.phase == SpecimenProfile.Phase.EGG:
			if egg: egg.visible = true
			if visuals: visuals.visible = false
		else:
			if egg: egg.visible = false
			if visuals: visuals.visible = true
	sleep_tube_pos = global_position

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
		
	# Handle sleep navigation and deep sleep state (Milestone 8)
	if is_sleeping:
		if _deep_sleeping:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			return
		else:
			_current_action = "SLEEP"
			_refresh_nav_target("SLEEP")
			if global_position.distance_to(sleep_tube_pos) < 1.0 or nav_agent.is_navigation_finished():
				_deep_sleeping = true
				velocity.x = 0.0
				velocity.z = 0.0
				if child_material:
					var sleep_tween = create_tween()
					sleep_tween.tween_property(child_material, "emission_energy_multiplier", 0.05, 1.0)
				move_and_slide()
				return
		
	if transition_timer > 0.0:
		transition_timer -= delta
		# Move forward with small constant velocity during morphology shift
		velocity.x = transition_velocity.x
		velocity.z = transition_velocity.z
		# Rotate visuals rapidly around Y-axis (spins)
		visuals.rotate_y(delta * 15.0)
		if transition_timer <= 0.0:
			visuals.rotation.y = 0.0
	else:
		var move_dir = Vector3.ZERO
		if nav_agent and not nav_agent.is_navigation_finished():
			var next_path_pos = nav_agent.get_next_path_position()
			var diff = next_path_pos - global_position
			diff.y = 0.0
			if diff.length() > 0.05:
				move_dir = diff.normalized()
				
		# Rotate visuals to face target/player smoothly
		if _current_action == "MIRROR_PLAYER":
			var player_pos = _get_player_position()
			if player_pos != Vector3.ZERO:
				var dir_to_player = (player_pos - global_position).normalized()
				var target_rot_y = atan2(-dir_to_player.x, -dir_to_player.z)
				visuals.rotation.y = rotate_toward(visuals.rotation.y, target_rot_y, delta * 8.0)
		elif move_dir != Vector3.ZERO:
			# Rotate visuals to face movement direction smoothly
			var target_rot_y = atan2(-move_dir.x, -move_dir.z)
			visuals.rotation.y = rotate_toward(visuals.rotation.y, target_rot_y, delta * 8.0)
		else:
			# Specific static rotation behaviors when not moving
			if _current_action == "REFUSE_INTERACTION":
				# Turn away from glass (+X direction)
				var target_rot_y = atan2(-1.0, 0.0)
				visuals.rotation.y = rotate_toward(visuals.rotation.y, target_rot_y, delta * 8.0)
			elif _current_action in ["VOCALIZE", "DISPLAY"]:
				# Turn to face the player if available
				var player_pos = _get_player_position()
				if player_pos != Vector3.ZERO:
					var dir_to_player = (player_pos - global_position).normalized()
					var target_rot_y = atan2(-dir_to_player.x, -dir_to_player.z)
					visuals.rotation.y = rotate_toward(visuals.rotation.y, target_rot_y, delta * 8.0)

		# Apply normal pathing velocity
		var target_vel = move_dir * speed
		velocity.x = target_vel.x
		velocity.z = target_vel.z
		
	move_and_slide()

func _process_egg_visuals(delta: float) -> void:
	# 1. Determine breathing rate based on chamber health status
	var is_distressed = false
	var env = EnvironmentBridge.profile
	if env:
		is_distressed = not env.is_heat_optimal() or not env.is_moisture_optimal()
		
	var breathe_speed = 3.5 if is_distressed else 1.5
	var breathe_amplitude = 0.08 if is_distressed else 0.03
	
	breathe_time += delta * breathe_speed
	var scale_factor = 1.0 + sin(breathe_time) * breathe_amplitude
	egg.scale = base_egg_scale * scale_factor
	
	# 2. Reactive color change
	if egg_material:
		if is_distressed:
			# Distress warning color: pulse red/amber
			var pulse = (sin(breathe_time * 2.0) + 1.0) * 0.5
			var warning_color = Color(0.9, 0.15, 0.1).lerp(Color(0.9, 0.5, 0.1), pulse)
			egg_material.albedo_color = Color(0.9, 0.4, 0.3)
			egg_material.emission = warning_color
			egg_material.emission_energy_multiplier = 1.5
		else:
			# Calm optimal color: neutral white/light-blue
			egg_material.albedo_color = Color(0.9, 0.9, 0.95)
			egg_material.emission = Color(0.1, 0.15, 0.2)
			egg_material.emission_energy_multiplier = 0.3

func _process_child_visuals(delta: float) -> void:
	# Reactive styling based on specimen profile state
	var profile = SpecimenBridge.profile
	if profile and child_material:
		# PLACEHOLDER: Temporary morphology check. Will be replaced by real Child/Adult model swap when ready.
		if profile.morphology != _last_morphology:
			_last_morphology = profile.morphology
			update_morphology()
			
			# Trigger 2.0 second fast spin transition with constant forward velocity
			transition_timer = 2.0
			transition_velocity = -global_transform.basis.z * 1.5
			
			var target_scale = Vector3.ONE * clamp(profile.neural_plasticity / 50.0, 0.5, 1.5)
			var pop_tween = create_tween()
			pop_tween.tween_property(visuals, "scale", target_scale * 1.3, 0.15)\
				.set_trans(Tween.TRANS_BACK)\
				.set_ease(Tween.EASE_OUT)
			pop_tween.tween_property(visuals, "scale", target_scale, 0.25)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN_OUT)
		else:
			# Scale child based on neural plasticity
			var target_scale = Vector3.ONE * clamp(profile.neural_plasticity / 50.0, 0.5, 1.5)
			visuals.scale = visuals.scale.lerp(target_scale, delta * 2.0)
		
		# Color based on threat_indexing (purple/magenta if high, clinical cyan if low)
		var threat_ratio = profile.threat_indexing / 100.0
		var base_color = Color(0.2, 0.6, 0.9).lerp(Color(0.8, 0.1, 0.7), threat_ratio)
		child_material.albedo_color = base_color
		
		# Emission intensity based on reward_schema
		var reward_intensity = clamp((profile.reward_schema + 50.0) / 100.0, 0.0, 1.0)
		child_material.emission = base_color * reward_intensity
		child_material.emission_energy_multiplier = reward_intensity * 2.0

func hatch() -> void:
	var profile = SpecimenBridge.profile
	if not profile or profile.phase != SpecimenProfile.Phase.EGG:
		return
		
	# Update state
	profile.phase = SpecimenProfile.Phase.CHILD
	# PLACEHOLDER: Temporary morphology update on hatching.
	_last_morphology = profile.morphology
	update_morphology()
	
	# Shake the egg before scaling down
	var base_egg_rot = egg.rotation
	var shake_tween = create_tween().set_loops(4)
	shake_tween.tween_property(egg, "rotation:z", base_egg_rot.z + 0.1, 0.07)
	shake_tween.tween_property(egg, "rotation:z", base_egg_rot.z - 0.1, 0.07)
	shake_tween.tween_callback(func(): egg.rotation = base_egg_rot)
	
	# Chain the actual scale transition
	var transition_tween = create_tween().set_parallel(true)
	# Scale egg down to zero
	transition_tween.tween_property(egg, "scale", Vector3.ZERO, 0.8)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
		
	# Scale visuals up
	visuals.visible = true
	visuals.scale = Vector3.ZERO
	transition_tween.tween_property(visuals, "scale", Vector3.ONE, 0.8)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
		
	# On completion, activate the controller
	transition_tween.chain().tween_callback(func():
		egg.visible = false
		controller.activate()
		# Trigger Tells update if exists
		if tells.has_method("update_tells"):
			tells.update_tells()
		print("Specimen has hatched into a CHILD!")
	)

## Returns the player's global position using the external_player export reference.
## Returns Vector3.ZERO if no player is assigned or the reference is invalid.
func _get_player_position() -> Vector3:
	if external_player and is_instance_valid(external_player):
		return external_player.global_position
	return Vector3.ZERO

## Finds RigidBody3D nodes currently located inside the containment cell boundaries.
# FIXME: architecture debt — replace with Area3D detection or a placed-objects tracking system (Rule 50)
func _find_placed_objects_in_cell() -> Array:
	var objects: Array = []
	if not is_inside_tree():
		return objects
	var root = get_tree().root
	if root:
		_collect_rigid_bodies_in_cell(root, objects)
	return objects

func _collect_rigid_bodies_in_cell(node: Node, out_list: Array) -> void:
	if node is RigidBody3D:
		var pos = node.global_position
		if pos.x >= SpecimenController.CELL_MIN_X and pos.x <= SpecimenController.CELL_MAX_X \
				and pos.z >= SpecimenController.CELL_MIN_Z and pos.z <= SpecimenController.CELL_MAX_Z:
			out_list.append(node)
	for child in node.get_children():
		_collect_rigid_bodies_in_cell(child, out_list)

## Computes the pathfinding target for the current action and sets it on the nav agent.
func _refresh_nav_target(action_id: String) -> void:
	if action_id == "SLEEP":
		if nav_agent:
			nav_agent.target_position = sleep_tube_pos
		return
		
	var player_pos = _get_player_position()
	var placed_objects = _find_placed_objects_in_cell()
	var target: Vector3
	if action_id == "MIRROR_PLAYER":
		if controller:
			target = controller.get_target_position(
				action_id, 
				global_position, 
				player_pos, 
				placed_objects, 
				_mirror_player_start, 
				_mirror_specimen_start
			)
		else:
			target = global_position
	else:
		if controller:
			target = controller.get_target_position(action_id, global_position, player_pos, placed_objects)
		else:
			target = global_position
	if nav_agent:
		nav_agent.target_position = target

## Periodic refresh for player-tracking actions (APPROACH_PLAYER, MIRROR_PLAYER).
func _on_tracking_timer_timeout() -> void:
	_refresh_nav_target(_current_action)

func _on_navigation_finished() -> void:
	if _current_action == "PLAY":
		_refresh_nav_target(_current_action)

func _on_action_selected(action_id: String) -> void:
	_on_action_performed(action_id)

func _on_action_performed(action_id: String) -> void:
	var profile = SpecimenBridge.profile
	if profile and not is_sleeping:
		var cost = 1.0
		match action_id:
			"DISPLAY", "PLAY":
				cost = 2.0
			"APPROACH_PLAYER", "RETREAT", "VOCALIZE", "MIRROR_PLAYER", "REFUSE_INTERACTION":
				cost = 1.0
			"INVESTIGATE", "WASTE_BEHAVIOR":
				cost = 0.5
			"SLEEP_EARLY":
				cost = 0.0
		
		if action_id == "SLEEP_EARLY" or (profile.energy - cost) <= 0.0:
			profile.energy = max(profile.energy - cost, 0.0)
			enter_sleep()
			return
			
		profile.energy = max(profile.energy - cost, 0.0)
		profile.log_action(action_id)
		if controller:
			controller.confirm_action(action_id)
		action_performed.emit(action_id)
		print("Specimen performed action: ", action_id, " | Energy cost: ", cost, " | Remaining energy: ", profile.energy)
			
	_current_action = action_id
	
	if action_id == "MIRROR_PLAYER":
		_mirror_player_start = _get_player_position()
		_mirror_specimen_start = global_position
		
	# Compute and cache the navigation target once per action selection
	_refresh_nav_target(action_id)
	
	# Start or stop the tracking timer based on whether this action needs periodic updates
	if controller and controller.is_tracking_action(action_id):
		_tracking_timer.start()
	else:
		_tracking_timer.stop()
	
	# Reset/apply visual tells and states based on action
	match action_id:
		"DISPLAY":
			# Threatening visual pulse: scale up and down, and bright emission flare
			if visuals:
				var pulse_tween = create_tween()
				var base_scale = visuals.scale
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
				
		"VOCALIZE":
			# Audio/visual tell: play a vocalization clip tiered by identity_coherence,
			# then double-flash emission.
			var profile_v = SpecimenBridge.profile
			if profile_v and audio_player and audio_player.has_method("play_vocalize"):
				audio_player.play_vocalize(profile_v.identity_coherence)
			if child_material:
				var vocal_tween = create_tween()
				vocal_tween.tween_property(child_material, "emission_energy_multiplier", 4.0, 0.1)
				vocal_tween.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.1)
				vocal_tween.tween_property(child_material, "emission_energy_multiplier", 4.0, 0.1)
				vocal_tween.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.3)
				
		"PLAY":
			# Playful spin rotation
			if visuals:
				var play_tween = create_tween()
				play_tween.tween_property(visuals, "rotation:y", visuals.rotation.y + (PI * 2.0), 0.6)\
					.set_trans(Tween.TRANS_BACK)\
					.set_ease(Tween.EASE_IN_OUT)
			if child_material:
				var play_flare = create_tween()
				play_flare.tween_property(child_material, "emission_energy_multiplier", 3.0, 0.2)
				play_flare.tween_property(child_material, "emission_energy_multiplier", 1.0, 0.4)
				
		"SLEEP_EARLY":
			# Dim emission energy significantly to indicate sleeping
			if child_material:
				var sleep_tween = create_tween()
				sleep_tween.tween_property(child_material, "emission_energy_multiplier", 0.05, 1.5)
				
		"WASTE_BEHAVIOR":
			# Dim emission slightly to indicate low motivation/sadness
			if child_material:
				var waste_tween = create_tween()
				waste_tween.tween_property(child_material, "emission_energy_multiplier", 0.2, 1.0)
				
		_:
			# Standard actions: restore standard emission intensity based on reward schema
			if child_material:
				var reward_intensity = 1.0
				if profile:
					reward_intensity = clamp((profile.reward_schema + 50.0) / 100.0, 0.0, 1.0)
				var restore_tween = create_tween()
				restore_tween.tween_property(child_material, "emission_energy_multiplier", reward_intensity * 2.0, 0.5)

func enter_sleep() -> void:
	if is_sleeping:
		return
	is_sleeping = true
	_deep_sleeping = false
	_current_action = "SLEEP"
	if controller:
		controller.deactivate()
		controller.active_action = "SLEEP"
		
	sleep_entered.emit()
	print("Specimen: Entering SLEEP state... Walking to sleep tube.")

func wake_up() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	_deep_sleeping = false
	_current_action = "PLAY"
	
	# Restore energy to max
	var profile = SpecimenBridge.profile
	if profile:
		profile.energy = 5.0 + float(profile.current_cycle) * 2.0
		# Restore standard emission intensity
		if child_material:
			var reward_intensity = clamp((profile.reward_schema + 50.0) / 100.0, 0.0, 1.0)
			child_material.emission_energy_multiplier = reward_intensity * 2.0
			
	if controller:
		controller.activate()
	print("Specimen: Woke up! Resuming actions. Energy restored to: ", profile.energy if profile else 0.0)

func apply_sleep_interaction(action_type: String) -> void:
	var profile = SpecimenBridge.profile
	if not profile or not is_sleeping:
		return
		
	if action_type == "PET":
		# PET: resonance_frequency +4.0, reward_schema +3.0, identity_coherence +1.0, costs 1 AP
		profile.apply_delta("resonance_frequency", 4.0)
		profile.apply_delta("reward_schema", 3.0)
		profile.apply_delta("identity_coherence", 1.0)
		print("Specimen: Received PET during sleep.")
		
	elif action_type == "SHOCK":
		# SHOCK: reward_schema -8.0, identity_coherence -5.0, resonance_frequency +3.0, forces wake, costs 2 AP
		profile.apply_delta("reward_schema", -8.0)
		profile.apply_delta("identity_coherence", -5.0)
		profile.apply_delta("resonance_frequency", 3.0)
		print("Specimen: Received SHOCK during sleep. Waking up immediately.")
		wake_up()
