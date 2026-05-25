extends SpecimenState
class_name SleepState

enum SleepLocation {
	TUBE,
	RANDOM_CORNER
}

@export var sleep_location_type: SleepLocation = SleepLocation.TUBE

static func calculate_target(current_pos: Vector3, sleep_tube_pos: Vector3, corners_xz: Array[Vector2], rand_index: int, is_early: bool) -> Vector3:
	if is_early:
		var corner = corners_xz[rand_index]
		return Vector3(corner.x, current_pos.y, corner.y)
	return sleep_tube_pos

func enter(context: SpecimenStateMachine.StateContext) -> void:
	specimen.is_sleeping = true
	specimen._deep_sleeping = false
	
	var is_early = (sleep_location_type == SleepLocation.RANDOM_CORNER)
	var rand_idx = randi() % corners_xz_count()
	var target = calculate_target(
		context.global_position,
		context.sleep_tube_pos,
		Specimen.CORNERS_XZ,
		rand_idx,
		is_early
	)
	specimen._sleep_destination = target
	specimen.nav_agent.target_position = target
	
	var duration = 1.5 if is_early else 1.0
	specimen.apply_emission_dim(0.05, duration)

func physics_update(_context: SpecimenStateMachine.StateContext, _delta: float) -> void:
	if specimen._deep_sleeping:
		return
		
	if specimen.global_position.distance_to(specimen._sleep_destination) < 1.0 or specimen.nav_agent.is_navigation_finished():
		specimen._deep_sleeping = true
		specimen.velocity = Vector3.ZERO
		specimen.apply_emission_dim(0.05, 1.0)
		specimen.set_physics_process(false)
		specimen.set_process(false)

static func corners_xz_count() -> int:
	return Specimen.CORNERS_XZ.size()
