extends Node

const SC = preload("res://src/scripts/specimen/specimen_controller.gd")
const RS = preload("res://src/scripts/conditioning/reinforcement_system.gd")
const CM = preload("res://src/scripts/systems/cycle_manager.gd")

const ApproachPlayerState = preload("res://src/scripts/specimen/states/approach_player_state.gd")
const MirrorPlayerState = preload("res://src/scripts/specimen/states/mirror_player_state.gd")


func _ready() -> void:
	print("=== Specimen Integration & Morphology Verification ===")
	
	# 1. Initialize Autoloads/Bridges
	SpecimenBridge.start_run()
	EnvironmentBridge.start_run()
	
	var profile = SpecimenBridge.profile
	var env = EnvironmentBridge.profile
	
	# 2. Load and Instantiate Specimen Scene
	var specimen_scene = load("res://src/scenes/specimen/specimen.tscn")
	var specimen = specimen_scene.instantiate()
	add_child(specimen)
	
	# 3. Assert Egg Phase Defaults
	assert(profile.phase == SpecimenProfile.Phase.EGG, "FAIL: Should start in EGG phase")
	assert(specimen.egg.visible == true, "FAIL: Egg mesh should be visible")
	assert(specimen.visuals.visible == false, "FAIL: Visuals node should be hidden")
	assert(specimen.controller.action_timer.is_stopped(), "FAIL: Controller timer should be stopped in EGG phase")
	print("[PASS] Egg phase defaults and controller guard")
	
	# 4. Trigger Hatching and await the tween transition (takes 0.8s)
	print("Hatching specimen...")
	specimen.hatch()
	
	await get_tree().create_timer(1.2).timeout
	print("DEBUG: Specimen Position: ", specimen.global_position)
	print("DEBUG: Specimen Target: ", specimen.nav_agent.target_position)
	print("DEBUG: Navigation Finished: ", specimen.nav_agent.is_navigation_finished())
	print("DEBUG: Path points: ", specimen.nav_agent.get_current_navigation_path())
	
	# 5. Assert Post-Hatch Child Phase
	assert(profile.phase == SpecimenProfile.Phase.CHILD, "FAIL: Phase should be CHILD after hatch")
	assert(specimen.egg.visible == false, "FAIL: Egg mesh should be hidden after hatch")
	assert(specimen.visuals.visible == true, "FAIL: Visuals node should be visible after hatch")
	assert(not specimen.controller.action_timer.is_stopped(), "FAIL: Controller timer should be running in CHILD phase")
	print("[PASS] Hatching tween transition and controller activation")
	
	# 6. Test Morphology changes
	# PLACEHOLDER: Verification of temporary primitive morphology shape configuration.
	assert(profile.morphology == SpecimenProfile.Morphology.CAPSULE, "FAIL: Default morphology should be CAPSULE")
	assert(specimen.child_placeholder.mesh is CapsuleMesh, "FAIL: Default mesh should be CapsuleMesh")
	
	profile.morphology = SpecimenProfile.Morphology.CUBE
	specimen.update_morphology()
	assert(specimen.child_placeholder.mesh is BoxMesh, "FAIL: Mesh should update to BoxMesh")
	
	profile.morphology = SpecimenProfile.Morphology.SPHERE
	specimen.update_morphology()
	assert(specimen.child_placeholder.mesh is SphereMesh, "FAIL: Mesh should update to SphereMesh")
	
	profile.morphology = SpecimenProfile.Morphology.CYLINDER
	specimen.update_morphology()
	assert(specimen.child_placeholder.mesh is CylinderMesh, "FAIL: Mesh should update to CylinderMesh")
	
	profile.morphology = SpecimenProfile.Morphology.TORUS
	specimen.update_morphology()
	assert(specimen.child_placeholder.mesh is TorusMesh, "FAIL: Mesh should update to TorusMesh")
	print("[PASS] Morphology dynamic mesh updates")
	
	# 7. Test Reinforcement integration
	var rs = RS.new()
	add_child(rs)
	profile.action_log = ["VOCALIZE"]
	rs.reinforce()
	assert(profile.action_pool["VOCALIZE"] > 10.0, "FAIL: Reinforce did not increase action pool weight")
	print("[PASS] Reinforcement system integration")
	rs.queue_free()
	
	# 8. Test Cycle progress and neglect decay integration
	var cm = CM.new()
	add_child(cm)
	var prev_heat = env.heat
	EnvironmentBridge.process_cycle_end(profile)
	cm.apply_cycle_decay([])
	profile.current_cycle += 1
	
	assert(env.heat != prev_heat, "FAIL: Environmental drift was not applied at cycle end")
	assert(profile.action_pool["VOCALIZE"] < 20.0, "FAIL: Neglect decay was not applied to unaddressed action")
	print("[PASS] Cycle transition: drift and neglect decay integration")
	cm.queue_free()
	
	# 9. Verify Action Target Mapping
	# Ensure calculate_target produces coordinates inside boundaries
	profile.phase = SpecimenProfile.Phase.CHILD
	var target_pos = ApproachPlayerState.calculate_target(specimen.global_position, Vector3.ZERO, Specimen.CELL_MIN_X, Specimen.CELL_MAX_X, Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z)
	assert(target_pos.x >= Specimen.CELL_MIN_X and target_pos.x <= Specimen.CELL_MAX_X, "FAIL: target X out of cell boundaries")
	assert(target_pos.z >= Specimen.CELL_MIN_Z and target_pos.z <= Specimen.CELL_MAX_Z, "FAIL: target Z out of cell boundaries")
	print("[PASS] Action-to-target pathfinding boundary clamping")
	
	# 9b. Verify Target Caching (signal-driven, not per-frame)
	# Reset energy to high value to prevent sleep during standard tests
	profile.energy = 50.0
	# Simulate an action being performed and verify the target is cached on the nav agent
	specimen._on_action_performed("PLAY")
	assert(specimen._current_action == "PLAY", "FAIL: _current_action should be cached from signal")
	var cached_target = specimen.nav_agent.target_position
	# The target should be within cell boundaries
	assert(cached_target.x >= Specimen.CELL_MIN_X and cached_target.x <= Specimen.CELL_MAX_X, "FAIL: cached target X out of bounds")
	assert(cached_target.z >= Specimen.CELL_MIN_Z and cached_target.z <= Specimen.CELL_MAX_Z, "FAIL: cached target Z out of bounds")
	# Verify tracking timer is stopped for non-tracking actions
	assert(specimen._tracking_timer.is_stopped(), "FAIL: tracking timer should be stopped for PLAY action")
	print("[PASS] Signal-driven target caching and tracking timer control")
	
	# 9c. Verify MIRROR_PLAYER Midpoint Reflection
	var p_start = Vector3(20.0, 0.0, -8.0)
	var s_start = Vector3(30.0, 0.0, -12.0)
	
	# Scenario A: player moves closer to specimen (X: 20 -> 22, Z: -8 -> -6)
	var p_pos_a = Vector3(22.0, 0.0, -6.0)
	var target_a = MirrorPlayerState.calculate_target(s_start, p_pos_a, p_start, s_start, Specimen.CELL_MIN_X, Specimen.CELL_MAX_X, Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z)
	assert(abs(target_a.x - 28.0) < 0.01, "FAIL: MIRROR_PLAYER reflected X should be 28.0, got: " + str(target_a.x))
	assert(abs(target_a.z - (-14.0)) < 0.01, "FAIL: MIRROR_PLAYER reflected Z should be -14.0, got: " + str(target_a.z))
	
	# Scenario B: out-of-bounds reflection (should clamp)
	var p_pos_b = Vector3(5.0, 0.0, 20.0)
	var target_b = MirrorPlayerState.calculate_target(s_start, p_pos_b, p_start, s_start, Specimen.CELL_MIN_X, Specimen.CELL_MAX_X, Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z)
	assert(abs(target_b.x - Specimen.CELL_MAX_X) < 0.01, "FAIL: MIRROR_PLAYER reflected X should clamp to CELL_MAX_X")
	assert(abs(target_b.z - Specimen.CELL_MIN_Z) < 0.01, "FAIL: MIRROR_PLAYER reflected Z should clamp to CELL_MIN_Z")
	
	# Scenario C: fallback if starts are omitted (should fallback to s_start using p_pos_a as start)
	var target_c = MirrorPlayerState.calculate_target(s_start, p_pos_a, Vector3.ZERO, Vector3.ZERO, Specimen.CELL_MIN_X, Specimen.CELL_MAX_X, Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z)
	assert(abs(target_c.x - s_start.x) < 0.01, "FAIL: MIRROR_PLAYER fallback X should match s_start")
	assert(abs(target_c.z - s_start.z) < 0.01, "FAIL: MIRROR_PLAYER fallback Z should match s_start")
	
	# Scenario D: verify tracking timer starts for MIRROR_PLAYER
	specimen._on_action_performed("MIRROR_PLAYER")
	assert(specimen._current_action == "MIRROR_PLAYER", "FAIL: _current_action should be MIRROR_PLAYER")
	assert(not specimen._tracking_timer.is_stopped(), "FAIL: tracking timer should be running for MIRROR_PLAYER")
	print("[PASS] MIRROR_PLAYER midpoint reflection and fallback logic")
	
	# 10. Verify Morphology Transition Velocity and Visual Spin

	var initial_rot_y = specimen.visuals.rotation.y
	profile.morphology = SpecimenProfile.Morphology.SPHERE
	specimen.update_morphology()
	# Trigger morphology change to trigger spin transition
	profile.morphology = SpecimenProfile.Morphology.CUBE
	specimen._process_child_visuals(0.01) # Trigger the change detection
	assert(specimen.transition_timer > 0.0, "FAIL: transition_timer should be started on morphology change")
	assert(specimen.transition_velocity.length() > 0.0, "FAIL: transition forward velocity should be set")
	
	var old_timer = specimen.transition_timer
	specimen._physics_process(0.1)
	assert(specimen.transition_timer < old_timer, "FAIL: transition_timer should decay")
	assert(abs(specimen.velocity.x - specimen.transition_velocity.x) < 0.01, "FAIL: velocity.x should match transition_velocity")
	assert(abs(specimen.velocity.z - specimen.transition_velocity.z) < 0.01, "FAIL: velocity.z should match transition_velocity")
	assert(specimen.visuals.rotation.y != initial_rot_y, "FAIL: visuals should rotate during transition")
	print("[PASS] Morphology transition physics: velocity and Y-rotation spin")
	
	# 11. Verify Custom Interaction Prompt text with "Current Action"
	# Case A: Default/No Action in EGG phase
	var egg_specimen = specimen_scene.instantiate()
	add_child(egg_specimen)
	assert(egg_specimen.interactable != null, "FAIL: egg_specimen should have an interactable")
	var prompt_data_egg = egg_specimen.interactable.get_interaction_prompt_data()
	assert(prompt_data_egg.has("prompt_text_override"), "FAIL: prompt_data_egg should have prompt_text_override")
	assert("Current Action: None" in prompt_data_egg["prompt_text_override"], "FAIL: Expected 'Current Action: None' in egg phase, got: " + prompt_data_egg["prompt_text_override"])
	
	# Case B: After action is performed (e.g. PLAY)
	egg_specimen.hatch()
	await get_tree().create_timer(1.2).timeout
	egg_specimen._on_action_performed("PLAY")
	var prompt_data_play = egg_specimen.interactable.get_interaction_prompt_data()
	assert(prompt_data_play.has("prompt_text_override"), "FAIL: prompt_data_play should have prompt_text_override")
	assert("Current Action: Play" in prompt_data_play["prompt_text_override"], "FAIL: Expected 'Current Action: Play', got: " + prompt_data_play["prompt_text_override"])
	
	# Case C: After sleep action (e.g. SLEEP_EARLY)
	egg_specimen._on_action_performed("SLEEP_EARLY")
	var prompt_data_sleep = egg_specimen.interactable.get_interaction_prompt_data()
	assert(prompt_data_sleep.has("prompt_text_override"), "FAIL: prompt_data_sleep should have prompt_text_override")
	assert("Current Action: Sleep Early" in prompt_data_sleep["prompt_text_override"], "FAIL: Expected 'Current Action: Sleep Early', got: " + prompt_data_sleep["prompt_text_override"])

	egg_specimen.queue_free()
	print("[PASS] Custom interaction prompt dynamically displays Current Action")

	# Clean up
	specimen.queue_free()
	SpecimenBridge.end_run()
	EnvironmentBridge.end_run()
	
	print("=== All Integration & Morphology Tests Passed ===")
	get_tree().quit()
