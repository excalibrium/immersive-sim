extends MainLoop

## Scratch verification script for drift and consequence systems.
## Run with: godot.exe --headless --script res://src/scripts/tests/verify_environment_systems.gd

const ECS = preload("res://src/scripts/systems/environment_consequence_system.gd")

func _process(_delta: float) -> bool:
	print("=== Environment Systems Verification ===")
	print("")
	_test_drift()
	_test_consequence_heat_too_low()
	_test_consequence_heat_too_high()
	_test_consequence_moisture_too_low()
	_test_consequence_moisture_too_high()
	_test_consequence_optimal_no_penalty()
	_test_action_pool_basics()
	_test_crystallisation_window()
	print("")
	print("=== All tests passed ===")
	return true  # signals quit

func _test_drift() -> void:
	var env = EnvironmentProfile.new()
	env.heat = 30.0
	env.moisture = 65.0
	env.drift()
	assert(env.heat == 29.0, "FAIL: drift heat expected 29.0, got %s" % env.heat)
	assert(env.moisture == 60.0, "FAIL: drift moisture expected 60.0, got %s" % env.moisture)
	print("[PASS] drift: heat 30->29, moisture 65->60")

func _test_consequence_heat_too_low() -> void:
	var env = EnvironmentProfile.new()
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	spec.reward_schema = 0.0
	env.heat = 20.0
	env.moisture = 65.0
	ECS.apply_consequences(env, spec)
	assert(spec.reward_schema == -2.0, "FAIL: heat too low, reward_schema expected -2.0, got %s" % spec.reward_schema)
	print("[PASS] consequence: heat too low -> reward_schema -2.0")

func _test_consequence_heat_too_high() -> void:
	var env = EnvironmentProfile.new()
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	spec.reward_schema = 0.0
	env.heat = 40.0
	env.moisture = 65.0
	ECS.apply_consequences(env, spec)
	assert(spec.reward_schema == -2.0, "FAIL: heat too high, reward_schema expected -2.0, got %s" % spec.reward_schema)
	print("[PASS] consequence: heat too high -> reward_schema -2.0")

func _test_consequence_moisture_too_low() -> void:
	var env = EnvironmentProfile.new()
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	env.heat = 33.0
	env.moisture = 30.0
	ECS.apply_consequences(env, spec)
	assert(spec.neural_plasticity == 48.0, "FAIL: moisture too low, neural_plasticity expected 48.0, got %s" % spec.neural_plasticity)
	print("[PASS] consequence: moisture too low -> neural_plasticity -2.0 (50->48)")

func _test_consequence_moisture_too_high() -> void:
	var env = EnvironmentProfile.new()
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	env.heat = 33.0
	env.moisture = 80.0
	ECS.apply_consequences(env, spec)
	assert(spec.identity_coherence == 48.0, "FAIL: moisture too high, identity_coherence expected 48.0, got %s" % spec.identity_coherence)
	print("[PASS] consequence: moisture too high -> identity_coherence -2.0 (50->48)")

func _test_consequence_optimal_no_penalty() -> void:
	var env = EnvironmentProfile.new()
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	spec.reward_schema = 0.0
	env.heat = 33.0
	env.moisture = 65.0
	ECS.apply_consequences(env, spec)
	assert(spec.reward_schema == 0.0, "FAIL: optimal range, reward_schema should be 0.0, got %s" % spec.reward_schema)
	assert(spec.neural_plasticity == 50.0, "FAIL: optimal range, neural_plasticity should be 50.0, got %s" % spec.neural_plasticity)
	assert(spec.identity_coherence == 50.0, "FAIL: optimal range, identity_coherence should be 50.0, got %s" % spec.identity_coherence)
	print("[PASS] consequence: optimal range -> no penalties applied")

func _test_action_pool_basics() -> void:
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	assert(spec.get_total_weight() == 100.0, "FAIL: total weight expected 100.0, got %s" % spec.get_total_weight())
	spec.apply_action_weight("RETREAT", 5.0)
	assert(spec.action_pool["RETREAT"] == 15.0, "FAIL: RETREAT weight expected 15.0, got %s" % spec.action_pool["RETREAT"])
	spec.apply_action_weight("RETREAT", -100.0)
	assert(spec.action_pool["RETREAT"] == 1.0, "FAIL: RETREAT weight should floor at 1.0, got %s" % spec.action_pool["RETREAT"])
	spec.log_action("VOCALIZE")
	spec.log_action("PLAY")
	spec.log_action("RETREAT")
	spec.log_action("DISPLAY")
	assert(spec.action_log.size() == 3, "FAIL: action log should max at 3, got %s" % spec.action_log.size())
	assert(spec.action_log[0] == "DISPLAY", "FAIL: most recent should be DISPLAY, got %s" % spec.action_log[0])
	print("[PASS] action pool: weight adjustment, floor, and log rotation")

func _test_crystallisation_window() -> void:
	var spec = SpecimenProfile.new()
	spec.initialize(50.0)
	spec.current_cycle = 15
	spec.apply_delta("threat_indexing", 10.0)
	assert(spec.threat_indexing == 7.0, "FAIL: crystallisation delta expected 7.0, got %s" % spec.threat_indexing)
	spec.current_cycle = 18
	spec.apply_delta("threat_indexing", 10.0)
	assert(spec.threat_indexing == 17.0, "FAIL: post-crystallisation delta expected 17.0, got %s" % spec.threat_indexing)
	print("[PASS] crystallisation window: 30%% reduction applied in cycles 14-17")
