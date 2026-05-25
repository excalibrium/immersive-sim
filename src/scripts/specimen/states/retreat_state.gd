extends SpecimenState
class_name RetreatState

static func calculate_target(current_pos: Vector3, player_pos: Vector3, fallback_rand_z: float, min_x: float, max_x: float, min_z: float, max_z: float) -> Vector3:
	var target_z = current_pos.z
	if player_pos != Vector3.ZERO:
		target_z = clamp(2.0 * current_pos.z - player_pos.z, min_z, max_z)
	else:
		target_z = fallback_rand_z
	return Vector3(max_x, current_pos.y, target_z)

func enter(context: SpecimenStateMachine.StateContext) -> void:
	var target = calculate_target(
		context.global_position,
		context.player_pos,
		randf_range(Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z),
		Specimen.CELL_MIN_X,
		Specimen.CELL_MAX_X,
		Specimen.CELL_MIN_Z,
		Specimen.CELL_MAX_Z
	)
	specimen.nav_agent.target_position = target
