extends Node

const COM = preload("res://src/scripts/systems/corporate_objectives_manager.gd")
const CM = preload("res://src/scripts/systems/cycle_manager.gd")

func _ready() -> void:
	print("=== Corporate Objectives Verification ===")
	
	# Initialise bridges
	SpecimenBridge.start_run()
	EnvironmentBridge.start_run()
	
	# Setup Game Session and ObjectiveManager
	Game.session = GameSession.new()
	var obj_mgr = ObjectiveManager.new()
	add_child(obj_mgr)
	
	# Instantiate CycleManager and CorporateObjectivesManager
	var cycle_mgr = CM.new()
	add_child(cycle_mgr)
	
	var corp_mgr = COM.new()
	corp_mgr.cycle_manager = cycle_mgr
	add_child(corp_mgr)
	
	_test_egg_phase_exclusivity(corp_mgr, cycle_mgr)
	_test_mid_cycle_hatching(corp_mgr, cycle_mgr)
	_test_real_time_tracking(corp_mgr)
	_test_cycle_end_evaluation_and_cleanup(corp_mgr, cycle_mgr)
	
	# Cleanup
	corp_mgr.queue_free()
	cycle_mgr.queue_free()
	obj_mgr.queue_free()
	EnvironmentBridge.end_run()
	SpecimenBridge.end_run()
	Game.session = null
	
	print("=== All Corporate Objectives tests passed ===")
	get_tree().quit()

func _test_egg_phase_exclusivity(corp_mgr: CorporateObjectivesManager, cycle_mgr: CycleManager) -> void:
	var profile = SpecimenBridge.profile
	profile.phase = SpecimenProfile.Phase.EGG
	
	cycle_mgr.start_cycle()
	
	assert(corp_mgr.current_directive_id == "", "FAIL: Should not issue corporate directive in EGG phase")
	assert(Game.session.active_objectives.is_empty(), "FAIL: Active objectives list should be empty")
	print("[PASS] Egg phase exclusivity")

func _test_mid_cycle_hatching(corp_mgr: CorporateObjectivesManager, cycle_mgr: CycleManager) -> void:
	var profile = SpecimenBridge.profile
	assert(corp_mgr.current_directive_id == "", "Setup verification")
	
	# Trigger transition mid-cycle
	cycle_mgr.phase_transitioned.emit(SpecimenProfile.Phase.CHILD)
	profile.phase = SpecimenProfile.Phase.CHILD
	
	assert(corp_mgr.current_directive_id != "", "FAIL: Directive should be issued immediately on hatching mid-cycle")
	assert(Game.session.active_objectives.size() == 1, "FAIL: Active objective should be added to Game session")
	print("[PASS] Mid-cycle hatching directive issuance")

func _test_real_time_tracking(corp_mgr: CorporateObjectivesManager) -> void:
	# Let's force active directive to CORP_01 (PROXIMITY STIMULATION) to verify real-time completion
	corp_mgr.cleanup_corporate_objectives()
	corp_mgr.current_directive_id = "CORP_01"
	
	var def = corp_mgr.directives["CORP_01"]
	var obj = ObjectiveData.new()
	obj.objective_id = def.id
	obj.title_key = def.title
	var task = TaskData.new()
	task.task_id = def.task_id
	task.description_key = def.task_desc
	obj.tasks.append(task)
	Game.objectives.add_objective(obj)
	
	# Track progress
	assert(corp_mgr.approach_count == 0, "Initial verify")
	
	# Simulate specimen actions
	corp_mgr._on_specimen_action_performed("APPROACH_PLAYER")
	assert(corp_mgr.approach_count == 1, "Verify count increment")
	
	var active_obj = corp_mgr.get_active_session_objective()
	assert(active_obj != null, "Must be active")
	assert(active_obj.tasks[0].description_key.contains("(Progress: 1/3)"), "FAIL: Progress description text not updated: " + active_obj.tasks[0].description_key)
	
	# Emulate two more approach actions
	corp_mgr._on_specimen_action_performed("APPROACH_PLAYER")
	corp_mgr._on_specimen_action_performed("APPROACH_PLAYER")
	
	# CORP_01 should now be completed in real-time
	assert(corp_mgr.get_active_session_objective() == null, "FAIL: CORP_01 should be completed and moved out of active_objectives")
	assert(Game.session.completed_objectives.size() == 1, "FAIL: CORP_01 should be in completed_objectives list")
	
	# Verify variable deltas written: threat_indexing += 8, resonance_frequency += 4, identity_coherence -= 6
	var profile = SpecimenBridge.profile
	assert(profile.threat_indexing == 8.0, "FAIL: threat_indexing delta")
	assert(profile.resonance_frequency == 4.0, "FAIL: resonance_frequency delta")
	assert(profile.identity_coherence == 44.0, "FAIL: identity_coherence delta (initial 50 - 6)")
	
	print("[PASS] Real-time tracking and delta variable writing")

func _test_cycle_end_evaluation_and_cleanup(corp_mgr: CorporateObjectivesManager, cycle_mgr: CycleManager) -> void:
	# Let's force active directive to CORP_02 (COMPLIANCE ENFORCEMENT, cycle-end)
	corp_mgr.cleanup_corporate_objectives()
	var profile = SpecimenBridge.profile
	profile.phase = SpecimenProfile.Phase.CHILD
	profile.identity_coherence = 50.0
	profile.threat_indexing = 0.0
	profile.reward_schema = 0.0
	
	corp_mgr.current_directive_id = "CORP_02"
	var def = corp_mgr.directives["CORP_02"]
	var obj = ObjectiveData.new()
	obj.objective_id = def.id
	obj.title_key = def.title
	var task = TaskData.new()
	task.task_id = def.task_id
	task.description_key = def.task_desc
	obj.tasks.append(task)
	Game.objectives.add_objective(obj)
	
	# Under threshold (refuse_count is 0 <= 1) -> Success
	cycle_mgr.cycle_ended.emit(profile.current_cycle)
	
	# Objective should be completed at cycle end
	assert(Game.session.completed_objectives.size() == 2, "FAIL: CORP_02 should be completed. Completed count expected 2, got %d" % Game.session.completed_objectives.size())
	assert(profile.identity_coherence == 40.0, "FAIL: identity_coherence expected 40.0 (50 - 10)")
	assert(profile.threat_indexing == 6.0, "FAIL: threat_indexing expected 6.0 (0 + 6)")
	assert(profile.reward_schema == -5.0, "FAIL: reward_schema expected -5.0 (0 - 5)")
	
	# Now verify clean up rollover works for next cycle
	cycle_mgr.start_cycle()
	
	# Completed CORP objectives must be removed from completed list during start_cycle to keep session clean
	for completed_obj in Game.session.completed_objectives:
		assert(not completed_obj.objective_id.begins_with("CORP_"), "FAIL: Completed list should be cleaned of CORP objectives at start of cycle")
	
	print("[PASS] Cycle-end evaluation and session cleanup")
