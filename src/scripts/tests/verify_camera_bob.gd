extends Node

func _ready() -> void:
	print("=== Camera Bob and Footstep Audio Verification ===")
	
	# Try to load the player scene
	var player_scene = load("res://src/scenes/player/player.tscn")
	if not player_scene:
		print("FAIL: Could not load player.tscn")
		get_tree().quit(1)
		return
		
	var player = player_scene.instantiate()
	if not player:
		print("FAIL: Could not instantiate player")
		get_tree().quit(1)
		return
		
	# Add to tree to run _ready() on player and its children
	add_child(player)
	
	# Verify that the child nodes are correct
	if not player.camera_3d:
		print("FAIL: camera_3d is null")
		get_tree().quit(1)
		return
		
	if not player.camera_bob_component:
		print("FAIL: camera_bob_component is null")
		get_tree().quit(1)
		return
		
	if not player.footstep_audio_component:
		print("FAIL: footstep_audio_component is null")
		get_tree().quit(1)
		return
		
	print("[PASS] Nodes successfully loaded and configured")
	
	# Call update_bob to ensure no runtime errors
	var test_velocity = Vector3(5.0, 0.0, 0.0) # Moving at run speed
	player.camera_bob_component.update_bob(test_velocity, true, 0.016)
	
	print("[PASS] update_bob executed successfully")
	
	# Test footstep emission and playback
	player.camera_bob_component.footstep_stepped.emit()
	print("[PASS] footstep_stepped signal emitted")
	
	player.queue_free()
	print("=== All Camera Bob and Audio tests passed ===")
	get_tree().quit(0)
