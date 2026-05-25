extends SpecimenState
class_name MirrorPlayerState

static func calculate_target(current_pos: Vector3, player_pos: Vector3, player_start: Vector3, specimen_start: Vector3, min_x: float, max_x: float, min_z: float, max_z: float) -> Vector3:
	if player_pos != Vector3.ZERO:
		var p_start = player_start
		var s_start = specimen_start
		if p_start == Vector3.ZERO and s_start == Vector3.ZERO:
			p_start = player_pos
			s_start = current_pos
		
		var target = p_start + s_start - player_pos
		return Vector3(
			clamp(target.x, min_x, max_x),
			current_pos.y,
			clamp(target.z, min_z, max_z)
		)
	else:
		return Vector3(
			(min_x + max_x) / 2.0,
			current_pos.y,
			(min_z + max_z) / 2.0
		)

func _init() -> void:
	auto_rotate_visuals = false

func enter(context: SpecimenStateMachine.StateContext) -> void:
	specimen._mirror_player_start = context.player_pos
	specimen._mirror_specimen_start = context.global_position
	_update_target(context)
	specimen._tracking_timer.start()

func exit() -> void:
	specimen._tracking_timer.stop()

func handle_tracking_timeout(context: SpecimenStateMachine.StateContext) -> void:
	_update_target(context)

func physics_update(context: SpecimenStateMachine.StateContext, delta: float) -> void:
	if context.player_pos != Vector3.ZERO:
		specimen.look_at_position(context.player_pos, delta)

func _update_target(context: SpecimenStateMachine.StateContext) -> void:
	var target = calculate_target(
		context.global_position,
		context.player_pos,
		specimen._mirror_player_start,
		specimen._mirror_specimen_start,
		Specimen.CELL_MIN_X,
		Specimen.CELL_MAX_X,
		Specimen.CELL_MIN_Z,
		Specimen.CELL_MAX_Z
	)
	specimen.nav_agent.target_position = target
