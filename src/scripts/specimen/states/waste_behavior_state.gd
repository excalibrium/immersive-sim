extends SpecimenState
class_name WasteBehaviorState

var _pooped: bool = false

static func calculate_target(current_pos: Vector3, corners_xz: Array[Vector2], rand_index: int) -> Vector3:
	var corner = corners_xz[rand_index]
	return Vector3(corner.x, current_pos.y, corner.y)

func enter(context: SpecimenStateMachine.StateContext) -> void:
	_pooped = false
	specimen.apply_emission_dim(0.2, 1.0)
	
	var rand_idx = randi() % Specimen.CORNERS_XZ.size()
	var target = calculate_target(context.global_position, Specimen.CORNERS_XZ, rand_idx)
	specimen.nav_agent.target_position = target

func handle_navigation_finished(context: SpecimenStateMachine.StateContext) -> void:
	if not _pooped:
		_pooped = true
		_spawn_poop()
		specimen.restore_standard_emission()

func _spawn_poop() -> void:
	var poop_scene = load("res://src/scenes/level/objects/poop.tscn")
	if not poop_scene:
		push_error("WasteBehaviorState: Failed to load poop.tscn")
		return
		
	var poop = poop_scene.instantiate() as Node3D
	if not poop:
		push_error("WasteBehaviorState: Failed to instantiate poop")
		return
		
	var parent_node = specimen.get_parent()
	var objects_root = parent_node.get_node_or_null("Objects") if parent_node else null
	if not objects_root:
		objects_root = parent_node
		
	if objects_root:
		objects_root.add_child(poop)
		poop.global_position = specimen.global_position
		print("WasteBehaviorState: Spawned poop at ", poop.global_position)
