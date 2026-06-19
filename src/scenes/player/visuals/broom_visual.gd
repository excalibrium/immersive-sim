extends ItemVisual

@onready var item_use_component: ItemUseComponent = $ItemUseComponent
@export var decal_projector: DecalProjector
@export var marker_3d: Marker3D

@export var axis_lock: bool = false

var player_reference: Player = null
var is_sweeping: bool = false
var last_marker_pos: Vector3 = Vector3.ZERO
var is_first_frame: bool = true
var broom_pos := Vector3.ZERO
var accumulated_distance: float = 0.0
const DECAL_SPACING = 0.04 # Spawn a decal every 4cm of movement
const FLOOR_RAY_UP_OFFSET = 1.0 # Start ray 1m above marker
const FLOOR_RAY_DOWN_DISTANCE = 3.0 # Cast 3m downward total

func _ready() -> void:
	super()
	if item_use_component:
		item_use_component.item_used.connect(_on_item_used)
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if axis_lock:
		global_rotation.x = 0.0
		position.y = 0.0

	var direction = $Broom.global_position - broom_pos

	if direction.length_squared() > 0.001:
		$Broom/BroomMesh.global_rotation = Vector3(0.0,atan2(direction.x, direction.z),0.0)

	broom_pos = $Broom.global_position
	if is_sweeping and marker_3d and player_reference:
		var current_pos := marker_3d.global_position
		if is_first_frame:
			last_marker_pos = current_pos
			is_first_frame = false
			accumulated_distance = 0.0
			return

		var dist_moved := current_pos.distance_to(last_marker_pos)
		accumulated_distance += dist_moved

		var velocity_vec := (current_pos - last_marker_pos) / delta
		var speed := velocity_vec.length()

		if accumulated_distance >= DECAL_SPACING:
			_try_spawn_decal(current_pos, speed)
			accumulated_distance = fmod(accumulated_distance, DECAL_SPACING)

		last_marker_pos = current_pos
	else:
		is_first_frame = true
func _on_item_used(player: Player) -> void:
	player_reference = player
	is_sweeping = true

	var sweep_point := Vector3(global_position.x, player.global_position.y, global_position.z)
	var swept_any := false

	for poop in player.get_tree().get_nodes_in_group("poop"):
		var dist : float = poop.global_position.distance_to(sweep_point)
		if dist < 2.5:
			var dir_to_poop = (poop.global_position - player.global_position).normalized()
			var forward := -player.camera_3d.global_transform.basis.z.normalized()
			if forward.dot(dir_to_poop) > 0.4:
				if poop.has_method("take_damage"):
					poop.take_damage(1.0)
				else:
					poop.queue_free()
				swept_any = true

	if swept_any:
		print("BroomVisual: Poop cleaned!")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "use":
		is_sweeping = false

func _try_spawn_decal(marker_pos: Vector3, speed: float) -> void:
	if not decal_projector:
		return

	# Raycast downward from above the marker to find the actual floor surface
	var space := get_world_3d().direct_space_state
	var ray_origin := Vector3(marker_pos.x, marker_pos.y + FLOOR_RAY_UP_OFFSET, marker_pos.z)
	var ray_end := Vector3(marker_pos.x, marker_pos.y - FLOOR_RAY_DOWN_DISTANCE, marker_pos.z)
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1) # Layer 1 = environment
	if player_reference:
		query.exclude = [player_reference.get_rid()]
		
	var result := space.intersect_ray(query)

	if result.is_empty():
		return # No floor found, skip

	var floor_pos: Vector3 = result.position
	var yaw := marker_3d.global_rotation.y

	decal_projector.spawn_decal(floor_pos, yaw, speed)
