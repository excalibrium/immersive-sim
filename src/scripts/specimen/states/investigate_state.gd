extends SpecimenState
class_name InvestigateState

static func calculate_target(current_pos: Vector3, placed_objects: Array[Node3D], fallback_rand_pos: Vector3, min_x: float, max_x: float, min_z: float, max_z: float) -> Vector3:
	if not placed_objects.is_empty():
		var chosen_obj = placed_objects.pick_random()
		if chosen_obj and is_instance_valid(chosen_obj):
			return Vector3(
				clamp(chosen_obj.global_position.x, min_x, max_x),
				current_pos.y,
				clamp(chosen_obj.global_position.z, min_z, max_z)
			)
	return fallback_rand_pos

func enter(context: SpecimenStateMachine.StateContext) -> void:
	var fallback_pos = Vector3(
		randf_range(Specimen.CELL_MIN_X, Specimen.CELL_MAX_X),
		context.global_position.y,
		randf_range(Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z)
	)
	var target = calculate_target(
		context.global_position,
		context.placed_objects,
		fallback_pos,
		Specimen.CELL_MIN_X,
		Specimen.CELL_MAX_X,
		Specimen.CELL_MIN_Z,
		Specimen.CELL_MAX_Z
	)
	specimen.nav_agent.target_position = target
