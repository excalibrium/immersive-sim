@tool
extends SceneTree

func _init():
	var result = []
	var ik = TwoBoneIK3D.new()
	if ik:
		result.append("TwoBoneIK3D properties:")
		var properties = ik.get_property_list()
		for prop in properties:
			var name = prop["name"]
			var val = ik.get(name)
			result.append("  Property: " + name + " = " + str(val) + " (Type: " + str(prop["type"]) + ")")
	else:
		result.append("Failed to instantiate TwoBoneIK3D")
		
	var file = FileAccess.open("res://twoboneik_properties.txt", FileAccess.WRITE)
	if file:
		file.store_string("\n".join(result))
		file.close()
	quit()
