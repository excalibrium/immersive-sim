extends SpecimenState
class_name PlayState

static func calculate_target(current_pos: Vector3, rand_pos: Vector3) -> Vector3:
	return rand_pos

func enter(context: SpecimenStateMachine.StateContext) -> void:
	specimen.play_play_tell()
	_update_target(context)

func handle_navigation_finished(context: SpecimenStateMachine.StateContext) -> void:
	_update_target(context)

func _update_target(context: SpecimenStateMachine.StateContext) -> void:
	var rand_pos = Vector3(
		randf_range(Specimen.CELL_MIN_X, Specimen.CELL_MAX_X),
		context.global_position.y,
		randf_range(Specimen.CELL_MIN_Z, Specimen.CELL_MAX_Z)
	)
	var target = calculate_target(context.global_position, rand_pos)
	specimen.nav_agent.target_position = target
