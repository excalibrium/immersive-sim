extends Node

func _ready() -> void:
	print("--- VERIFY POOP SYSTEMS ---")
	
	# Load poop scene
	var poop_scene = load("res://src/scenes/level/objects/poop.tscn")
	if not poop_scene:
		print("FAIL: Failed to load poop.tscn")
		get_tree().quit(1)
		return
		
	# Test 1: Spawning a poop, checking its initial health and scale
	print("Test 1: Initial poop properties")
	var poop1 = poop_scene.instantiate()
	add_child(poop1)
	poop1.global_position = Vector3(0, 0, 0)
	
	# Give it a frame to process _ready()
	await get_tree().process_frame
	
	if poop1.health != 1.0:
		print("FAIL: Initial health is ", poop1.health, ", expected 1.0")
		get_tree().quit(1)
		return
	if poop1.scale != Vector3.ONE:
		print("FAIL: Initial scale is ", poop1.scale, ", expected ", Vector3.ONE)
		get_tree().quit(1)
		return
	print("PASS: Initial poop properties verified.")

	# Test 2: take_damage behavior
	print("Test 2: take_damage behavior")
	poop1.take_damage(0.5)
	# Wait for scale tween to finish/settle
	await get_tree().create_timer(0.6).timeout
	if poop1.health != 0.5:
		print("FAIL: Health after damage is ", poop1.health, ", expected 0.5")
		get_tree().quit(1)
		return
	if poop1.scale.x > 0.7 or poop1.scale.x < 0.3:
		print("FAIL: Scale after damage is ", poop1.scale, ", expected approx ", Vector3.ONE * 0.5)
		get_tree().quit(1)
		return
	print("PASS: Damage scaling verified.")
		
	# Test 3: take_damage to death
	print("Test 3: Damage to death")
	poop1.take_damage(0.5)
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(poop1) and not poop1.is_queued_for_deletion():
		print("FAIL: Poop not deleted after health <= 0")
		get_tree().quit(1)
		return
	print("PASS: Poop damage and destruction verified.")

	# Test 4: Digestion
	print("Test 4: Digestion of nearby poop")
	var p_eater = poop_scene.instantiate()
	var p_food = poop_scene.instantiate()
	add_child(p_eater)
	add_child(p_food)
	
	# Position them 1 meter apart (within 3m threshold)
	p_eater.global_position = Vector3(0, 0, 0)
	p_food.global_position = Vector3(1, 0, 0)
	
	# Wait for _ready() and digestion timers (they check every 1.5 seconds)
	await get_tree().create_timer(2.0).timeout
	
	# One of them should have digested the other
	var eater_valid = is_instance_valid(p_eater) and not p_eater.is_queued_for_deletion()
	var food_valid = is_instance_valid(p_food) and not p_food.is_queued_for_deletion()
	
	if eater_valid and food_valid:
		print("FAIL: Neither poop was digested after 2 seconds")
		get_tree().quit(1)
		return
		
	var survivor = p_eater if eater_valid else p_food
	
	if survivor.health != 2.0:
		print("FAIL: Survivor health is ", survivor.health, ", expected 2.0")
		get_tree().quit(1)
		return
		
	print("PASS: Digestion verified. Survivor health: ", survivor.health)
	
	print("--- ALL TESTS PASSED ---")
	get_tree().quit(0)
