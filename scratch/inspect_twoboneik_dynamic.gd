@tool
extends SceneTree

func _init():
	var result = []
	var ik = TwoBoneIK3D.new()
	if ik:
		ik.setting_count = 1
		result.append("TwoBoneIK3D dynamic properties after setting_count = 1:")
		var properties = ik.get_property_list()
		for prop in properties:
			var name = prop["name"]
			# Only check properties that aren't built-in metadata
			if "/" in name or "setting" in name or "bone" in name or "target" in name or "pole" in name:
				var val = ik.get(name)
				result.append("  Property: " + name + " = " + str(val) + " (Type: " + str(prop["type"]) + ")")
	else:
		result.append("Failed to instantiate TwoBoneIK3D")
		
	var file = FileAccess.open("res://twoboneik_dynamic_properties.txt", FileAccess.WRITE)
	if file:
		file.store_string("\n".join(result))
		file.close()
	quit()
