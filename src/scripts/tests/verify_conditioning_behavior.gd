extends MainLoop

const RS = preload("res://src/scripts/conditioning/reinforcement_system.gd")
const ND = preload("res://src/scripts/conditioning/neglect_decay.gd")
const SC = preload("res://src/scripts/specimen/specimen_controller.gd")

func _process(_delta: float) -> bool:
	print("=== Conditioning & Behavior Verification ===")
	_test_reinforcement()
	_test_neglect_decay()
	_test_specimen_controller()
	print("=== All tests passed ===")
	return true

func _test_reinforcement() -> void:
	SpecimenBridge.start_run()
	var profile = SpecimenBridge.profile
	profile.ruthlessness = 50.0
	profile.action_log = ["VOCALIZE", "RETREAT", "PLAY"]
	
	var rs = RS.new()
	rs.reinforce()
	
	assert(profile.ruthlessness == 45.0, "FAIL: ruthlessness expected 45.0")
	assert(profile.action_pool["VOCALIZE"] == 20.0, "FAIL: VOCALIZE expected 20.0, got %s" % profile.action_pool["VOCALIZE"])
	assert(profile.identity_coherence == 51.0, "FAIL: identity_coherence expected 51.0")
	print("[PASS] Reinforcement mechanics")
	SpecimenBridge.end_run()
	rs.free()

func _test_neglect_decay() -> void:
	SpecimenBridge.start_run()
	var profile = SpecimenBridge.profile
	var nd = ND.new()
	profile.action_pool["VOCALIZE"] = 1.2
	nd.apply_cycle_decay(["RETREAT"])
	
	assert(profile.action_pool["VOCALIZE"] == 1.0, "FAIL: VOCALIZE expected 1.0, got %s" % profile.action_pool["VOCALIZE"])
	assert(profile.action_pool["RETREAT"] == 10.0, "FAIL: RETREAT expected 10.0")
	print("[PASS] Neglect decay mechanics")
	SpecimenBridge.end_run()
	nd.free()

func _test_specimen_controller() -> void:
	SpecimenBridge.start_run()
	var sc = SC.new()
	var action_id = sc._select_action()
	assert(ActionDefinitions.ACTIONS.has(action_id), "FAIL: Invalid action_id returned: %s" % action_id)
	print("[PASS] Specimen controller action selection")
	SpecimenBridge.end_run()
	sc.free()
