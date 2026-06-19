extends Node

const AnimationToggle = preload("res://src/scripts/components/animation_toggle.gd")
const Interactable = preload("res://src/scripts/components/interactable.gd")

func _ready() -> void:
	print("=== Running AnimationToggle Verification Tests ===")
	
	# 1. Prepare programmatically defined AnimationPlayer and Animations
	var anim_player = AnimationPlayer.new()
	var library = AnimationLibrary.new()
	
	var anim_open = Animation.new()
	anim_open.length = 1.0
	library.add_animation("open", anim_open)
	
	var anim_close = Animation.new()
	anim_close.length = 0.5
	library.add_animation("close", anim_close)
	
	anim_player.add_animation_library("", library)
	add_child(anim_player)
	
	# 2. Prepare Interactable node
	var interactable = Interactable.new()
	add_child(interactable)
	
	# 3. Instantiate AnimationToggle component
	var toggle = AnimationToggle.new()
	toggle.interactable = interactable
	toggle.animation_player = anim_player
	toggle.state_0_animation = "close"
	toggle.state_1_animation = "open"
	toggle.state_0_text_key = "TURN_ON"
	toggle.state_1_text_key = "TURN_OFF"
	toggle.play_on_start = false # snap immediately
	add_child(toggle)
	
	# Wait for ready and post-ready process_frame in AnimationToggle
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Assert initial state
	assert(toggle.is_state_1 == false, "FAIL: Should initialize to state 0 (false)")
	assert(interactable.interact_text_key == "TURN_ON", "FAIL: Should set interact text to state_0_text_key")
	assert(anim_player.assigned_animation == "close", "FAIL: Should have run close animation")
	print("[PASS] Initial state snapped correctly")
	
	# Connect to state_changed signal to count events
	var signal_events = []
	toggle.state_changed.connect(func(is_state_1):
		signal_events.append(is_state_1)
	)
	
	# 4. Trigger first interaction (transition to state 1 / open)
	interactable.interact(self)
	
	assert(toggle.is_state_1 == true, "FAIL: Should toggle to state 1 (true)")
	assert(interactable.interact_text_key == "TURN_OFF", "FAIL: Should update interact text to state_1_text_key")
	assert(anim_player.assigned_animation == "open", "FAIL: Should have run open animation")
	assert(signal_events.size() == 1, "FAIL: Should have emitted state_changed once")
	assert(signal_events[0] == true, "FAIL: Emitted state should be true")
	print("[PASS] Toggled to state 1 successfully")
	
	# 5. Trigger second interaction (transition back to state 0 / close)
	interactable.interact(self)
	
	assert(toggle.is_state_1 == false, "FAIL: Should toggle back to state 0 (false)")
	assert(interactable.interact_text_key == "TURN_ON", "FAIL: Should update interact text back to state_0_text_key")
	assert(anim_player.assigned_animation == "close", "FAIL: Should have run close animation")
	assert(signal_events.size() == 2, "FAIL: Should have emitted state_changed twice")
	assert(signal_events[1] == false, "FAIL: Emitted state should be false")
	print("[PASS] Toggled back to state 0 successfully")
	
	# 6. Test fallback dependency resolution (auto-discovery)
	# Create a parent node with children
	var parent_node = Node.new()
	add_child(parent_node)
	
	var child_interactable = Interactable.new()
	parent_node.add_child(child_interactable)
	
	var child_anim_player = AnimationPlayer.new()
	var child_library = AnimationLibrary.new()
	child_library.add_animation("open", anim_open)
	child_library.add_animation("close", anim_close)
	child_anim_player.add_animation_library("", child_library)
	parent_node.add_child(child_anim_player)
	
	var auto_toggle = AnimationToggle.new()
	auto_toggle.state_0_animation = "close"
	auto_toggle.state_1_animation = "open"
	parent_node.add_child(auto_toggle)
	
	# Wait for ready and fallback detection
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert(auto_toggle.interactable == child_interactable, "FAIL: Fallback should have auto-resolved interactable sibling/parent")
	assert(auto_toggle.animation_player == child_anim_player, "FAIL: Fallback should have auto-resolved animation_player sibling/parent")
	print("[PASS] Fallback dependency resolution resolved successfully")
	
	# Clean up test nodes
	interactable.queue_free()
	anim_player.queue_free()
	toggle.queue_free()
	parent_node.queue_free()
	
	print("=== All AnimationToggle Tests Passed ===")
	get_tree().quit()
