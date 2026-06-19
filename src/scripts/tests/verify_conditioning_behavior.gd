extends Node

const RS = preload("res://src/scripts/conditioning/reinforcement_system.gd")
const CM = preload("res://src/scripts/systems/cycle_manager.gd")
const SC = preload("res://src/scripts/specimen/specimen_controller.gd")

func _ready() -> void:
	print("=== Conditioning & Behavior Verification ===")
	_test_reinforcement()
	_test_neglect_decay()
	_test_specimen_controller()
	print("=== All tests passed ===")
	get_tree().quit()

func _test_reinforcement() -> void:
	SpecimenBridge.start_run()
	var profile = SpecimenBridge.profile
	profile.ruthlessness = 50.0
	profile.action_log = ["VOCALIZE", "RETREAT", "WASTE_BEHAVIOR"]
	
	var rs = RS.new()
	add_child(rs) # Must add to tree for finding parent, etc. if needed
	rs.reinforce()
	
	assert(profile.ruthlessness == 45.0, "FAIL: ruthlessness expected 45.0")
	assert(profile.action_pool["VOCALIZE"] == 14.0, "FAIL: VOCALIZE expected 14.0, got %s" % profile.action_pool["VOCALIZE"])
	assert(profile.identity_coherence == 50.4, "FAIL: identity_coherence expected 50.4, got %s" % profile.identity_coherence)
	print("[PASS] Reinforcement mechanics")
	SpecimenBridge.end_run()
	rs.queue_free()

func _test_neglect_decay() -> void:
	SpecimenBridge.start_run()
	var profile = SpecimenBridge.profile
	var cm = CM.new()
	add_child(cm)
	profile.action_pool["VOCALIZE"] = 1.2
	cm.apply_cycle_decay(["RETREAT"])
	
	assert(profile.action_pool["VOCALIZE"] == 1.0, "FAIL: VOCALIZE expected 1.0, got %s" % profile.action_pool["VOCALIZE"])
	assert(profile.action_pool["RETREAT"] == 10.0, "FAIL: RETREAT expected 10.0")
	print("[PASS] Neglect decay mechanics")
	SpecimenBridge.end_run()
	cm.queue_free()

func _test_specimen_controller() -> void:
	SpecimenBridge.start_run()
	var sc = SC.new()
	add_child(sc)
	var action_id = sc._select_action()
	assert(ActionDefinitions.ACTIONS.has(action_id), "FAIL: Invalid action_id returned: %s" % action_id)
	print("[PASS] Specimen controller action selection")
	SpecimenBridge.end_run()
	sc.queue_free()
