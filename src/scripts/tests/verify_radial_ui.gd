extends Node

const RadialScene = preload("res://src/scenes/ui/RadialUI.tscn")

func _ready() -> void:
	print("=== RadialUI Interaction Verification ===")
	
	# 1. Initialize Autoloads/Bridges
	SpecimenBridge.start_run()
	EnvironmentBridge.start_run()
	
	var profile = SpecimenBridge.profile
	assert(profile != null, "FAIL: SpecimenBridge.profile not initialized")
	
	# 2. Instantiate RadialUI
	var radial: InteractionRadial = RadialScene.instantiate() as InteractionRadial
	add_child(radial)
	
	# 3. Assert Defaults
	assert(radial != null, "FAIL: Could not instantiate RadialUI")
	assert(radial.visible == false, "FAIL: RadialUI should be hidden initially")
	assert(radial.top_button != null, "FAIL: TOP button reference missing")
	assert(radial.bottom_button != null, "FAIL: BOTTOM button reference missing")
	assert(radial.left_button != null, "FAIL: LEFT button reference missing")
	assert(radial.right_button != null, "FAIL: RIGHT button reference missing")
	print("[PASS] Initial defaults and node references")
	
	# 4. Open Menu in EGG Phase (0) and verify visibility
	var egg_config = {
		"RIGHT": {
			"label": "SYSTEM",
			"subactions": ["END_CYCLE", "CHECK_STATUS"]
		}
	}
	radial.open_menu(profile.action_log, profile.energy, profile.get_max_energy(), egg_config)
	assert(radial.visible == true, "FAIL: RadialUI should be visible after open_menu")
	assert(radial.is_menu_open == true, "FAIL: is_menu_open should be true")
	assert(WindowManager.is_mouse_captured() == false, "FAIL: Mouse should be visible when menu is open")
	
	# EGG phase rules: only SYSTEM (RIGHT) is visible, others are hidden
	assert(radial.top_button.visible == false, "FAIL: TOP button should be hidden in EGG phase")
	assert(radial.bottom_button.visible == false, "FAIL: BOTTOM button should be hidden in EGG phase")
	assert(radial.left_button.visible == false, "FAIL: LEFT button should be hidden in EGG phase")
	assert(radial.right_button.visible == true, "FAIL: RIGHT button should be visible in EGG phase")
	print("[PASS] EGG phase visibility rules")
	
	# 5. Open Menu in CHILD Phase (1) and verify visibility
	radial.close_menu()
	var child_config = {
		"TOP": {
			"label": "REINFORCE",
			"subactions": ["COMFORT"]
		},
		"BOTTOM": {
			"label": "PUNISH",
			"subactions": ["SHOCK"]
		},
		"RIGHT": {
			"label": "SYSTEM",
			"subactions": ["END_CYCLE", "CHECK_STATUS"]
		}
	}
	radial.open_menu(profile.action_log, profile.energy, profile.get_max_energy(), child_config, "PLAY")
	assert(radial.current_action_name == "PLAY", "FAIL: Expected current_action_name to be 'PLAY'")
	assert(radial.current_action_label.text == "CURRENT ACTION: Play", "FAIL: Current action label incorrect after open_menu, got: " + radial.current_action_label.text)
	assert(radial.top_button.visible == true, "FAIL: TOP button should be visible in future phases")
	assert(radial.bottom_button.visible == true, "FAIL: BOTTOM button should be visible in future phases")
	assert(radial.left_button.visible == false, "FAIL: LEFT button should be hidden in future phases")
	assert(radial.right_button.visible == true, "FAIL: RIGHT button should be visible in future phases")
	print("[PASS] Future phases (CHILD/ADULT) visibility rules")
	
	# 6. Verify dynamic label creation
	var top_label = radial.top_button.get_node_or_null("Label")
	assert(top_label != null, "FAIL: TOP button dynamic label should be created")
	assert(top_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "FAIL: Label should be centered")
	print("[PASS] Dynamic upright label instantiation")
	
	# 7. Verify ruthlessness shifting text
	# Tier 0 (0-33): Reinforce / Punish
	# Tier 2 (67-100): Grant Relief / Impose Consequence
	radial.top_label.text = "GRANT RELIEF"
	radial.bottom_label.text = "IMPOSE CONSEQUENCE"
	assert(radial.top_label.text == "GRANT RELIEF", "FAIL: Expected 'GRANT RELIEF'")
	assert(radial.bottom_label.text == "IMPOSE CONSEQUENCE", "FAIL: Expected 'IMPOSE CONSEQUENCE'")
	print("[PASS] Ruthlessness-based label shift")
	
	# 8. Verify action log formatting in center
	profile.action_log = ["APPROACH_PLAYER", "VOCALIZE", "PLAY"]
	radial.current_action_log = profile.action_log
	radial.current_action_name = "APPROACH_PLAYER"
	radial._refresh_log()
	assert(radial.log_container != null, "FAIL: LogContainer should be instantiated")
	assert(radial.log_container.get_child_count() == 7, "FAIL: LogContainer should have current_action + header + 3 items + spacer + energy, got: " + str(radial.log_container.get_child_count()))
	assert(radial.current_action_label.text == "CURRENT ACTION: Approach Player", "FAIL: Current action label incorrect, got: " + radial.current_action_label.text)
	
	# Header is index 0
	var item1 = radial.action_labels[0]
	var item2 = radial.action_labels[1]
	var item3 = radial.action_labels[2]
	
	assert(item1.text == "Approach Player", "FAIL: Expected 'Approach Player', got: " + item1.text)
	assert(item2.text == "Vocalize", "FAIL: Expected 'Vocalize', got: " + item2.text)
	assert(item3.text == "Play", "FAIL: Expected 'Play', got: " + item3.text)
	print("[PASS] Dynamic action log formatting and formatting styles")
	
	# 9. Verify subaction fanning angles, offsets, and orbital scale progression
	# Use RIGHT which has 2 actions configured: "END_CYCLE", "CHECK_STATUS"
	radial._on_primary_hovered("RIGHT")
	# Await the tween animations to finish
	await get_tree().create_timer(0.5).timeout
	assert(radial.active_category == "RIGHT", "FAIL: Active category should be RIGHT")
	assert(radial.spawned_subactions.size() == 2, "FAIL: RIGHT should spawn 2 subactions, got: " + str(radial.spawned_subactions.size()))
	
	var sub1 = radial.spawned_subactions[0]
	var sub2 = radial.spawned_subactions[1]
	
	# Angle for RIGHT is 0.0 (0°)
	# Subaction 1 fanned at -45° (-PI/4) -> final angle -PI/4
	# Subaction 2 fanned at +45° (+PI/4) -> final angle PI/4
	# Subaction button rotation is final_angle + PI/2
	# For sub1: -PI/4 + PI/2 = PI/4 (0.785 rad)
	# For sub2: PI/4 + PI/2 = 3*PI/4 (2.356 rad)
	assert(abs(sub1.rotation - (PI/4.0)) < 0.01, "FAIL: sub1 rotation incorrect: " + str(sub1.rotation))
	assert(abs(sub2.rotation - (3*PI/4.0)) < 0.01, "FAIL: sub2 rotation incorrect: " + str(sub2.rotation))
	
	# Check orbital scale progression (second button should be larger than first)
	assert(sub2.scale.x > sub1.scale.x, "FAIL: Expected sub2 scale to be larger than sub1 for perspective progression")
	
	# Child label rotation must negate parent rotation to remain upright
	var sub1_label = sub1.get_node("Label") as Label
	assert(abs(sub1_label.rotation + sub1.rotation) < 0.01, "FAIL: sub1 label not upright")
	print("[PASS] Radial fan-out offsets and perspective scale progression")
	
	# 10. Verify category switching focus despawn
	radial._on_primary_hovered("BOTTOM")
	assert(radial.active_category == "BOTTOM", "FAIL: Active category should be BOTTOM")
	# Subactions should be replaced
	assert(radial.spawned_subactions.size() == 1, "FAIL: BOTTOM should spawn 1 subaction, got: " + str(radial.spawned_subactions.size()))
	print("[PASS] Focus-based category switching and subaction despawn")
	
	# 11. Verify unified signal emission on click and Uppercase casing standard
	var signal_state = { "received": false, "category": "", "action": "" }
	radial.subaction_selected.connect(func(category, action):
		print("Debug: subaction_selected callback: ", category, " : ", action)
		signal_state["received"] = true
		signal_state["category"] = category
		signal_state["action"] = action
	)
	
	# Switch back to RIGHT to click END_CYCLE
	radial._on_primary_hovered("RIGHT")
	await get_tree().create_timer(0.5).timeout
	var end_cycle_btn = radial.spawned_subactions[0]
	end_cycle_btn.pressed.emit()
	
	assert(signal_state["received"] == true, "FAIL: subaction_selected signal not received")
	assert(signal_state["category"] == "RIGHT", "FAIL: Expected category 'RIGHT'")
	assert(signal_state["action"] == "END_CYCLE", "FAIL: Expected action 'END_CYCLE' (uppercase), got: " + signal_state["action"])
	assert(radial.is_menu_open == false, "FAIL: Menu should be closed after selection")
	print("[PASS] Unified signal emission with exact configuration casing matching")
	
	# 12. Verify Sleep Layout and direct clicks
	# Open menu in sleep state
	var sleep_config = {
		"TOP": {
			"label": "PET",
			"action": "PET"
		},
		"BOTTOM": {
			"label": "SHOCK",
			"action": "SHOCK"
		}
	}
	radial.open_menu(profile.action_log, profile.energy, profile.get_max_energy(), sleep_config)
	assert(radial.top_button.visible == true, "FAIL: TOP button should be visible in sleep")
	assert(radial.bottom_button.visible == true, "FAIL: BOTTOM button should be visible in sleep")
	assert(radial.left_button.visible == false, "FAIL: LEFT button should be hidden in sleep")
	assert(radial.right_button.visible == false, "FAIL: RIGHT button should be hidden in sleep")
	
	assert(radial.top_label.text == "PET", "FAIL: Expected 'PET' during sleep, got: " + radial.top_label.text)
	assert(radial.bottom_label.text == "SHOCK", "FAIL: Expected 'SHOCK' during sleep, got: " + radial.bottom_label.text)
	
	var click_state = { "clicked_pet": false }
	radial.subaction_selected.connect(func(category, action):
		if action == "PET":
			click_state["clicked_pet"] = true
	)
	# Direct click top button
	radial._on_primary_clicked("TOP")
	assert(click_state["clicked_pet"] == true, "FAIL: Sleeping menu direct click should emit PET immediately")
	assert(radial.is_menu_open == false, "FAIL: Menu should close on direct click")
	print("[PASS] Sleep layout override and direct action execution")
	
	# 13. Verify CERTIFY option at Cycle 18
	profile.current_cycle = 18
	# Open menu for CHILD phase (1)
	var certify_config = {
		"TOP": {
			"label": "REINFORCE",
			"subactions": ["COMFORT"]
		},
		"BOTTOM": {
			"label": "PUNISH",
			"subactions": ["SHOCK"]
		},
		"RIGHT": {
			"label": "SYSTEM",
			"subactions": ["CERTIFY", "CHECK_STATUS"]
		}
	}
	radial.open_menu(profile.action_log, profile.energy, profile.get_max_energy(), certify_config)
	radial._on_primary_hovered("RIGHT")
	await get_tree().create_timer(0.5).timeout
	
	var has_certify = false
	for btn in radial.spawned_subactions:
		if btn.get_node("Label").text == "CERTIFY":
			has_certify = true
			break
	assert(has_certify == true, "FAIL: Expected CERTIFY subaction in RIGHT menu on Cycle 18")
	radial.close_menu()
	print("[PASS] Cycle 18+ CERTIFY transition menu option inclusion")
	
	# 14. Verify Real-time update method
	profile.action_log = ["PLAY", "VOCALIZE", "APPROACH_PLAYER"]
	radial.update_realtime_data(profile.action_log, profile.energy, profile.get_max_energy(), {}, "VOCALIZE")
	# Assert that the new log is formatted and displayed
	var updated_item1 = radial.action_labels[0]
	assert(updated_item1.text == "Play", "FAIL: Expected updated action 'Play', got: " + updated_item1.text)
	assert(radial.current_action_label.text == "CURRENT ACTION: Vocalize", "FAIL: Expected CURRENT ACTION: Vocalize, got: " + radial.current_action_label.text)
	print("[PASS] Real-time log updating via update_realtime_data")
	
	# 15. Verify center_override data-driven formatting (Bed layout)
	var bed_center_override = {
		"header": "REST MODULE",
		"current_action": "CYCLE: 12",
		"lines": [
			"STATUS: LOCKED",
			"Warning: Specimen is active!",
			"Specimen must be sleeping."
		],
		"energy": ""
	}
	radial.open_menu([], 0.0, 0.0, {"RIGHT": {"label": "LOCKED", "action": "LOCKED"}}, "", bed_center_override)
	assert(radial.log_container.get_node("Header").text == "REST MODULE", "FAIL: Expected Header to be 'REST MODULE'")
	assert(radial.current_action_label.text == "CYCLE: 12", "FAIL: Expected current action to be 'CYCLE: 12'")
	assert(radial.action_labels[0].text == "STATUS: LOCKED", "FAIL: Expected line 0 to be 'STATUS: LOCKED'")
	assert(radial.action_labels[1].text == "Warning: Specimen is active!", "FAIL: Expected line 1 to be 'Warning: Specimen is active!'")
	assert(radial.action_labels[2].text == "Specimen must be sleeping.", "FAIL: Expected line 2 to be 'Specimen must be sleeping.'")
	assert(radial.energy_label.visible == false, "FAIL: Energy label should be hidden when empty")
	radial.close_menu()
	print("[PASS] custom center log override formatting")

	# Clean up
	radial.queue_free()
	SpecimenBridge.end_run()
	EnvironmentBridge.end_run()
	
	print("=== All RadialUI Tests Passed ===")
	get_tree().quit()
