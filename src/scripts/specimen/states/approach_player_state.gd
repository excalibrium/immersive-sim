extends SpecimenState
class_name ApproachPlayerState

static func calculate_target(current_pos: Vector3, player_pos: Vector3, min_x: float, max_x: float, min_z: float, max_z: float) -> Vector3:
	if player_pos != Vector3.ZERO:
		return Vector3(
			clamp(player_pos.x, min_x, max_x),
			current_pos.y,
			clamp(player_pos.z, min_z, max_z)
		)
	else:
		# Fallback to the front glass center
		return Vector3(min_x, current_pos.y, (min_z + max_z) / 2.0)

func enter(context: SpecimenStateMachine.StateContext) -> void:
	_update_target(context)
	specimen._tracking_timer.start()

func exit() -> void:
	specimen._tracking_timer.stop()

func handle_tracking_timeout(context: SpecimenStateMachine.StateContext) -> void:
	_update_target(context)

func _update_target(context: SpecimenStateMachine.StateContext) -> void:
	var target = calculate_target(
		context.global_position,
		context.player_pos,
		Specimen.CELL_MIN_X,
		Specimen.CELL_MAX_X,
		Specimen.CELL_MIN_Z,
		Specimen.CELL_MAX_Z
	)
	specimen.nav_agent.target_position = target
