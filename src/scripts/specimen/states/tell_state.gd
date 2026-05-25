extends SpecimenState
class_name TellState

enum TellType {
	VOCALIZE,
	DISPLAY
}

@export var tell_type: TellType = TellType.VOCALIZE

static func calculate_target(current_pos: Vector3) -> Vector3:
	return current_pos

func _init() -> void:
	auto_rotate_visuals = false

func enter(context: SpecimenStateMachine.StateContext) -> void:
	specimen.nav_agent.target_position = calculate_target(context.global_position)
	
	var profile = SpecimenBridge.profile
	var coherence = profile.identity_coherence if profile else 50.0
	
	if tell_type == TellType.VOCALIZE:
		specimen.play_vocalize_tell(coherence)
	elif tell_type == TellType.DISPLAY:
		specimen.play_display_tell()

func physics_update(context: SpecimenStateMachine.StateContext, delta: float) -> void:
	if context.player_pos != Vector3.ZERO:
		specimen.look_at_position(context.player_pos, delta)
