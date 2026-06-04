@tool
extends SceneTree

func _init():
	var result = []
	var ik = TwoBoneIK3D.new()
	if ik:
		result.append("TwoBoneIK3D exists!")
		ik.root_bone = "Arm.L"
		result.append("root_bone set: " + str(ik.root_bone))
	else:
		result.append("TwoBoneIK3D DOES NOT EXIST!")
	
	var file = FileAccess.open("res://twoboneik_check.txt", FileAccess.WRITE)
	if file:
		file.store_string("\n".join(result))
		file.close()
	quit()
