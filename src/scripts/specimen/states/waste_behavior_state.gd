extends SpecimenState
class_name WasteBehaviorState

static func calculate_target(current_pos: Vector3, corners_xz: Array[Vector2], rand_index: int) -> Vector3:
	var corner = corners_xz[rand_index]
	return Vector3(corner.x, current_pos.y, corner.y)

func enter(context: SpecimenStateMachine.StateContext) -> void:
	specimen.apply_emission_dim(0.2, 1.0)
	
	var rand_idx = randi() % Specimen.CORNERS_XZ.size()
	var target = calculate_target(context.global_position, Specimen.CORNERS_XZ, rand_idx)
	specimen.nav_agent.target_position = target
