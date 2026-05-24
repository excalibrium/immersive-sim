extends Node

func _ready() -> void:
	print("--- SCRATCH RUN WORLD ---")
	var world_scene = load("res://src/scenes/world.tscn")
	var world = world_scene.instantiate()
	add_child(world)
	
	var specimen = world.get_node("Specimen")
	print("Specimen starting position: ", specimen.global_position)
	
	# Let physics settle first
	await get_tree().create_timer(0.5).timeout
	
	print("Hatching specimen now!")
	specimen.hatch()
	
	# Print diagnostics every second for 15 seconds
	for i in range(15):
		await get_tree().create_timer(1.0).timeout
		print("T = ", i + 1, "s")
		print("  Action: ", specimen._current_action)
		print("  Position: ", specimen.global_position)
		print("  On Floor: ", specimen.is_on_floor())
		print("  Target: ", specimen.nav_agent.target_position if specimen.nav_agent else "N/A")
		print("  Nav Finished: ", specimen.nav_agent.is_navigation_finished() if specimen.nav_agent else "N/A")
		if specimen.nav_agent:
			var path = specimen.nav_agent.get_current_navigation_path()
			print("  Path size: ", path.size())
			print("  Path: ", path)
		else:
			print("  No Nav Agent")
		print("  Velocity: ", specimen.velocity)
		
	print("--- SCRATCH RUN COMPLETED ---")
	get_tree().quit()
