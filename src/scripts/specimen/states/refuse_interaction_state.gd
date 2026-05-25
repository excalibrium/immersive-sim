extends SpecimenState
class_name RefuseInteractionState

static func calculate_target(current_pos: Vector3) -> Vector3:
	return current_pos

func _init() -> void:
	auto_rotate_visuals = false

func enter(context: SpecimenStateMachine.StateContext) -> void:
	specimen.nav_agent.target_position = calculate_target(context.global_position)

func physics_update(_context: SpecimenStateMachine.StateContext, delta: float) -> void:
	specimen.turn_away_from_glass(delta)
