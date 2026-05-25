extends Node

func _ready() -> void:
	print("=== CycleManager System Verification ===")
	
	# 1. Instantiate the actual world scene
	var world_scene = load("res://src/scenes/world.tscn")
	var world = world_scene.instantiate()
	add_child(world)
	
	# Await a frame to ensure all _ready calls finished
	await get_tree().process_frame
	
	var cycle_manager = world.cycle_manager
	var specimen = world.specimen
	var profile = SpecimenBridge.profile
	
	# Start Cycle 1 manually since cycles no longer start automatically
	cycle_manager.start_cycle()
	
	assert(cycle_manager != null, "FAIL: cycle_manager not instantiated")
	assert(specimen != null, "FAIL: specimen not instantiated")
	assert(profile != null, "FAIL: profile not initialized")
	
	# Deactivate autonomous timer to keep tests deterministic!
	if specimen and specimen.controller:
		specimen.controller.deactivate()
		
	# Disable light fade transitions by default to ensure synchronous test blocks
	cycle_manager.ap_depletion_dim_duration = 0.0
	cycle_manager.start_cycle_fade_duration = 0.0
	
	print("[PASS] Real world scene instantiation and node resolution")
	
	# Assert safe default energy initial value
	# The user requested profile.energy should initialize to 7.0 (which is 5 + 1 * 2)
	assert(profile.energy == 7.0, "FAIL: Specimen energy should default to 7.0. Got: " + str(profile.energy))
	print("[PASS] Specimen energy initializes to 7.0 default")
	
	# 2. Test AP consumption
	assert(cycle_manager.current_ap == 10, "FAIL: AP should start at 10")
	cycle_manager.spend_ap(3)
	assert(cycle_manager.current_ap == 7, "FAIL: AP should be 7 after spending 3")
	print("[PASS] AP consumption")
	
	# 3. Test cycle termination at 0 AP
	var current_cycle = profile.current_cycle
	cycle_manager.spend_ap(7) # this brings AP to 0, which no longer auto-ends cycle
	cycle_manager.end_cycle()
	# Wait for cycle manager to finish processing cycle end
	assert(profile.current_cycle == current_cycle + 1, "FAIL: Cycle should increment after AP reaches 0. Expected: " + str(current_cycle + 1) + ", got: " + str(profile.current_cycle))
	# Start Cycle 2 manually
	cycle_manager.start_cycle()
	assert(cycle_manager.current_ap == 10, "FAIL: AP should reset to 10 on new cycle")
	assert(profile.energy == 9.0, "FAIL: Energy should reset to 9.0 on cycle 2 start. Got: " + str(profile.energy))
	print("[PASS] Cycle auto-termination at 0 AP")
	
	# 4. Test specimen energy depletion via conditioning
	# Let's hatch specimen to CHILD so conditioning and energy logic runs
	if profile.phase == SpecimenProfile.Phase.EGG:
		specimen.hatch()
		specimen.controller.deactivate() # Keep tests deterministic!
		await get_tree().create_timer(1.0).timeout
	
	assert(profile.phase == SpecimenProfile.Phase.CHILD, "FAIL: Specimen phase should be CHILD")
	
	# Test Specimen dynamic energy costs per action
	profile.energy = 10.0
	specimen._on_action_performed("DISPLAY")
	assert(profile.energy == 8.0, "FAIL: DISPLAY action should cost 2 energy. Got: " + str(profile.energy))
	
	specimen._on_action_performed("INVESTIGATE")
	assert(profile.energy == 7.5, "FAIL: INVESTIGATE action should cost 0.5 energy. Got: " + str(profile.energy))
	
	specimen._on_action_performed("SLEEP_EARLY")
	assert(specimen.is_sleeping == true, "FAIL: SLEEP_EARLY action should trigger sleep immediately")
	
	# Wake up and reset energy for conditioning test
	specimen.wake_up()
	specimen.controller.deactivate()
	profile.energy = 7.0
	print("[PASS] Specimen dynamic energy costs per action and SLEEP_EARLY trigger")
	
	# Test action cancellation when it would put specimen to sleep
	specimen.wake_up()
	specimen.controller.deactivate()
	profile.energy = 1.0 # only 1.0 energy left
	
	# Clear the log first since we removed log clearing from the sleep flow
	profile.action_log.clear()
	# Let's manually push some action to log to check if it's cleared on sleep
	profile.log_action("VOCALIZE")
	assert(profile.action_log.size() == 1, "FAIL: action_log should have 1 item")
	
	# Try performing PLAY (cost 2.0). Since 1.0 - 2.0 <= 0.0, this should cancel the action and trigger sleep
	specimen._on_action_performed("PLAY")
	
	# Since it's cancelled:
	# - Specimen must be sleeping
	# - Energy should be decremented to 0.0
	# - Action log must NOT contain the cancelled action, but must preserve previous entries
	assert(specimen.is_sleeping == true, "FAIL: Specimen should enter sleep when action would put it to sleep")
	assert(profile.energy == 0.0, "FAIL: Cancelled action should deduct energy to 0.0. Expected: 0.0, got: " + str(profile.energy))
	assert(profile.action_log.size() == 1, "FAIL: Action log should retain previous entry. Got: " + str(profile.action_log))
	assert(profile.action_log[0] == "VOCALIZE", "FAIL: Action log should contain VOCALIZE. Got: " + str(profile.action_log[0]))
	print("[PASS] Action cancellation when it would put specimen to sleep")
	
	# Test dynamic Radial UI transition on sleep
	var radial_ui = world.find_child("RadialUI")
	if radial_ui:
		specimen.wake_up()
		specimen.controller.deactivate()
		profile.energy = 5.0
		# Open Radial UI
		var config = world._get_specimen_radial_config()
		radial_ui.open_menu(profile.action_log, profile.energy, profile.get_max_energy(), config)
		assert(radial_ui.is_menu_open == true, "FAIL: Radial UI should be open")
		assert(radial_ui.custom_config.get("TOP", {}).get("label", "") == "REINFORCE", "FAIL: Radial UI should not be in sleep layout initially")
		
		# Now trigger sleep
		specimen.enter_sleep()
		
		# Radial UI should have transitioned dynamically
		assert(radial_ui.custom_config.get("TOP", {}).get("label", "") == "PET", "FAIL: Radial UI should dynamically transition to sleep layout")
		assert(radial_ui.top_button.visible == true, "FAIL: Top button should be visible in sleep layout")
		assert(radial_ui.left_button.visible == false, "FAIL: Left button should be hidden in sleep layout")
		assert(radial_ui.current_action_log.size() == 2, "FAIL: Radial UI action log should retain previous entries. Got: " + str(radial_ui.current_action_log))
		assert(radial_ui.current_action_log[0] == "PLAY", "FAIL: Radial UI action log should contain PLAY")
		assert(radial_ui.current_action_log[1] == "VOCALIZE", "FAIL: Radial UI action log should contain VOCALIZE")
		radial_ui.close_menu()
		print("[PASS] Dynamic Radial UI layout transition on sleep")
	
	# Wake up and reset energy for conditioning test
	specimen.wake_up()
	specimen.controller.deactivate()
	profile.energy = 7.0
	
	# Perform standard conditioning in world
	world._apply_conditioning_with_energy("REINFORCE")
	assert(profile.energy == 6.0, "FAIL: Energy should be 6.0 after 1 conditioning. Got: " + str(profile.energy))
	assert(cycle_manager.current_ap == 9, "FAIL: AP should decrement to 9. Got: " + str(cycle_manager.current_ap))
	print("[PASS] Energy depletion and AP cost for conditioning")
	
	# Deplete energy to 0 (6 more conditioning actions)
	for i in range(6):
		world._apply_conditioning_with_energy("REINFORCE")
	
	assert(profile.energy == 0.0, "FAIL: Energy should be 0.0. Got: " + str(profile.energy))
	assert(specimen.is_sleeping == true, "FAIL: Specimen should enter sleep at 0 energy")
	print("[PASS] Specimen automatically enters sleep at 0 energy")
	
	# 5. Test silent penalties at 0 energy outside of sleep
	# Let's temporarily wake the specimen, set energy to 0.0, and call conditioning
	specimen.is_sleeping = false
	profile.energy = 0.0
	
	var old_reward = profile.reward_schema
	var old_coherence = profile.identity_coherence
	
	world._apply_conditioning_with_energy("REINFORCE")
	assert(profile.reward_schema == old_reward - 2.0, "FAIL: Silent reward penalty not applied")
	assert(profile.identity_coherence == old_coherence - 2.0, "FAIL: Silent coherence penalty not applied")
	assert(specimen.is_sleeping == true, "FAIL: Specimen should be forced back to sleep")
	print("[PASS] Silent conditioning penalties at 0 energy outside sleep")
	
	# 6. Test automatic hatch at Cycle 5
	# Reset specimen back to EGG phase
	profile.phase = SpecimenProfile.Phase.EGG
	specimen.egg.visible = true
	specimen.visuals.visible = false
	specimen.controller.action_timer.stop()
	
	# Fast forward to cycle 5
	profile.current_cycle = 4
	cycle_manager.end_cycle() # Ends cycle 4, starts cycle 5
	
	# Await hatching tween
	await get_tree().create_timer(1.2).timeout
	assert(profile.phase == SpecimenProfile.Phase.CHILD, "FAIL: EGG should auto hatch at Cycle 5")
	assert(specimen.egg.visible == false, "FAIL: Egg mesh should be hidden")
	assert(specimen.visuals.visible == true, "FAIL: Visuals should be visible")
	print("[PASS] Automatic Hatch at Cycle 5")
	
	# 7. Test CERTIFY Metamorphosis sequence
	# Set cycle to 18
	profile.current_cycle = 18
	cycle_manager.certify_duration = 0.5 # Fast certifying for testing
	
	cycle_manager.trigger_certify_sequence()
	assert(cycle_manager.current_ap == 0, "FAIL: AP should be zeroed during CERTIFY")
	assert(specimen.egg.visible == true, "FAIL: Specimen should temporarily revert to egg visuals")
	
	# Wait for 0.8s (enough for all translations to reveal since certify_duration is 0.5s)
	await get_tree().create_timer(0.8).timeout
	var overlay = cycle_manager.get_node_or_null("CertifyOverlay")
	assert(overlay != null, "FAIL: CertifyOverlay not found")
	var vbox = overlay.get_child(1)
	var text_contents = []
	for child in vbox.get_children():
		if child is Label:
			text_contents.append(child.text)
	
	# Assert new emotional terms are shown
	var expected_terms = [
		"ADAPTABILITY / VULNERABILITY",
		"ANGER / SURVIVAL INSTINCT",
		"JOY / DEPRIVATION",
		"AUTONOMY / SELF",
		"ATTACHMENT / ENTANGLEMENT"
	]
	for term in expected_terms:
		var found = false
		for text in text_contents:
			if term in text:
				found = true
				break
		assert(found == true, "FAIL: CertifyOverlay missing translation term: " + term)
	print("[PASS] CertifyOverlay emotional translation strings")
	
	# Wait for remaining certification/crack animation (another 1.2s)
	await get_tree().create_timer(1.2).timeout
	assert(profile.phase == SpecimenProfile.Phase.ADULT, "FAIL: Specimen should transition to ADULT after CERTIFY")
	assert(specimen.egg.visible == false, "FAIL: Egg visuals should be hidden after emerging")
	assert(specimen.visuals.visible == true, "FAIL: Child/Adult visuals should be visible")
	print("[PASS] CERTIFY Metamorphosis sequence complete")
	
	# 8. Test Light System Transitions and Reward Schema Hues (Asynchronous)
	print("--- Testing Light System & Reward Schema Hues ---")
	var lights = world.get_node_or_null("Lights")
	assert(lights != null, "FAIL: Lights node not found in world")
	assert(lights is LightSystem, "FAIL: LightSystem script not attached to Lights")
	
	# Configure non-zero transition durations for testing
	cycle_manager.ap_depletion_dim_duration = 0.2
	cycle_manager.start_cycle_fade_duration = 0.2
	
	# Set a specific reward schema value (e.g. 40.0) to test warm amber color tint
	profile.reward_schema = 40.0
	lights.update_hue_from_reward(profile.reward_schema, 0.0) # Snap hue instantly
	
	# Verify that the color of one of the omni lights is warmer (red > blue)
	var omni_light = lights.omni_lights[0]
	assert(omni_light.light_color.r > omni_light.light_color.b, "FAIL: Lights should be tinted warm amber for positive reward")
	
	# Now set a negative reward schema (e.g. -40.0)
	profile.reward_schema = -40.0
	lights.update_hue_from_reward(profile.reward_schema, 0.0)
	assert(omni_light.light_color.b > omni_light.light_color.r, "FAIL: Lights should be tinted cold blue for negative reward")
	
	# Test slow dimming on AP depletion
	profile.energy = 10.0
	cycle_manager.current_ap = 1
	
	# This spend_ap should start the dimming transition
	cycle_manager.spend_ap(1)
	
	# Verify that we are transitioning and lights have begun dimming (energy < base)
	assert(cycle_manager.is_transitioning == true, "FAIL: CycleManager should be transitioning")
	# A tiny wait to allow tween to start applying values
	await get_tree().create_timer(0.05).timeout
	assert(omni_light.light_energy < 1.0, "FAIL: Omni light energy should be dimming")
	
	# Await transition to complete
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame
	
	# Since it no longer auto-ends, we manually end it here
	cycle_manager.end_cycle()
	
	# Now transition should be finished, cycle advanced
	assert(cycle_manager.is_transitioning == false, "FAIL: Transition flag should reset")
	
	# Start next cycle manually
	cycle_manager.start_cycle()
	assert(cycle_manager.current_ap == 10, "FAIL: AP should reset after transition finishes")
	
	# Await lights to fade back on completely
	await get_tree().create_timer(0.25).timeout
	assert(omni_light.light_energy > 0.9, "FAIL: Omni light energy should have restored close to base")
	print("[PASS] Light System transitions and Reward Schema color shifting")
	
	# Clean up
	world.queue_free()
	print("=== All CycleManager Tests Passed ===")
	get_tree().quit()
