extends SceneTree

func _init():
	var res = ResourceLoader.load("res://src/scenes/world.tscn")
	var file = FileAccess.open("res://test_out.txt", FileAccess.WRITE)
	if res:
		file.store_string("SUCCESS")
	else:
		file.store_string("FAILED")
	file.close()
	quit()