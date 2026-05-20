extends Node3D

## A 3D panel that displays a SubViewport and handles mouse interaction.
## Works with the Interactable component to focus/unfocus.

@export var mesh: MeshInstance3D
@export var area: StaticBody3D
@export var viewport: SubViewport
@export var close_btn: Button
@export var interactable: Interactable
@export var pause_world: bool = false

var is_focused: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# MeshDataTool cache for barycentric UV projection on complex 3D meshes
var _cached_mdt: MeshDataTool = null
var _has_mesh_cache: bool = false

func _ready():
	if not interactable:
		interactable = find_child("Interactable")

	if interactable:
		interactable.interacted.connect(_on_interactable_interacted)

	if close_btn:
		close_btn.pressed.connect(_unfocus)

	# Ensure viewport is updated
	viewport.set_update_mode(SubViewport.UPDATE_WHEN_VISIBLE)
	
	# Cache mesh data for fast runtime query
	_cache_mesh_data()

func _cache_mesh_data():
	if mesh and mesh.mesh:
		_cached_mdt = MeshDataTool.new()
		# Surface 0 is standard for single-material UI panels
		if _cached_mdt.create_from_surface(mesh.mesh, 0) == OK:
			_has_mesh_cache = true

func _on_interactable_interacted(_interactor: Node):
	if not is_focused:
		_focus()
	else:
		_unfocus()

func _focus():
	is_focused = true
	WindowManager.push_mouse_state(WindowManager.MouseState.VISIBLE)
	if pause_world:
		TimeManager.time_scale = 0.0

func _unfocus():
	is_focused = false
	WindowManager.pop_mouse_state()
	if pause_world:
		TimeManager.time_scale = 1.0

func _input(event: InputEvent):
	if not is_focused:
		return
		
	if event.is_action_pressed("back"):
		_unfocus()
		get_viewport().set_input_as_handled()
		return

	# Handle mouse events
	if event is InputEventMouse:
		_handle_mouse_event(event)

func _handle_mouse_event(event: InputEventMouse):
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 100.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result and result.collider == area:
		var local_point = mesh.to_local(result.position)
		var uv = _get_uv_from_collision(result, local_point, camera)
		
		# Convert UV to viewport coordinates
		var viewport_pos = uv * Vector2(viewport.size)
		
		# Clone the event and update its position
		var cloned_event = event.duplicate()
		cloned_event.position = viewport_pos
		if cloned_event is InputEventMouseMotion:
			cloned_event.relative = viewport_pos - last_mouse_pos
			last_mouse_pos = viewport_pos
			
		viewport.push_input(cloned_event)

func _get_uv_from_collision(result: Dictionary, local_point: Vector3, camera: Camera3D) -> Vector2:
	var mesh_res = mesh.mesh
	if not mesh_res:
		return Vector2.ZERO

	# Method 1: Barycentric interpolation (Works on curved/complex 3D meshes if using a ConcavePolygonShape3D)
	if "face_index" in result and result.face_index >= 0 and _has_mesh_cache:
		if result.face_index < _cached_mdt.get_face_count():
			var v1 = _cached_mdt.get_face_vertex(result.face_index, 0)
			var v2 = _cached_mdt.get_face_vertex(result.face_index, 1)
			var v3 = _cached_mdt.get_face_vertex(result.face_index, 2)
			
			var p1 = _cached_mdt.get_vertex(v1)
			var p2 = _cached_mdt.get_vertex(v2)
			var p3 = _cached_mdt.get_vertex(v3)
			
			var uv1 = _cached_mdt.get_vertex_uv(v1)
			var uv2 = _cached_mdt.get_vertex_uv(v2)
			var uv3 = _cached_mdt.get_vertex_uv(v3)
			
			var bary = Geometry3D.get_triangle_barycentric_coords(local_point, p1, p2, p3)
			return (uv1 * bary.x) + (uv2 * bary.y) + (uv3 * bary.z)

	# Method 2: Box collision shape projection (accurate mapping for primitive BoxShape3D on arbitrary meshes)
	if interactable and interactable.shape is BoxShape3D:
		var box_size = interactable.shape.size
		var half_size = box_size * 0.5
		
		# Compute transform of interactable relative to the visual mesh
		var interactable_to_mesh = mesh.global_transform.affine_inverse() * interactable.global_transform
		
		# Transform the box corners to mesh local space to find the bounding box bounds
		var c_min = interactable_to_mesh * -half_size
		var c_max = interactable_to_mesh * half_size
		
		var local_min = Vector3(
			min(c_min.x, c_max.x),
			min(c_min.y, c_max.y),
			min(c_min.z, c_max.z)
		)
		var local_max = Vector3(
			max(c_min.x, c_max.x),
			max(c_min.y, c_max.y),
			max(c_min.z, c_max.z)
		)
		var local_box_size = local_max - local_min
		
		var min_size = local_box_size.x
		var min_axis = 0
		if local_box_size.y < min_size:
			min_size = local_box_size.y
			min_axis = 1
		if local_box_size.z < min_size:
			min_size = local_box_size.z
			min_axis = 2
			
		# Get camera transform to detect flips
		var cam_transform = camera.global_transform
		var cam_right = cam_transform.basis.x.normalized()
		var cam_up = cam_transform.basis.y.normalized()
		
		var h_axis_global = Vector3.ZERO
		var v_axis_global = Vector3.ZERO
		
		match min_axis:
			0: # YZ plane (normal along X)
				h_axis_global = mesh.global_transform.basis.z.normalized()
				v_axis_global = mesh.global_transform.basis.y.normalized()
			1: # XZ plane (normal along Y)
				h_axis_global = mesh.global_transform.basis.x.normalized()
				v_axis_global = mesh.global_transform.basis.z.normalized()
			2: # XY plane (normal along Z)
				h_axis_global = mesh.global_transform.basis.x.normalized()
				v_axis_global = mesh.global_transform.basis.y.normalized()
				
		var flip_x = h_axis_global.dot(cam_right) < 0.0
		var flip_y = v_axis_global.dot(cam_up) < 0.0

		var uv = Vector2.ZERO
		match min_axis:
			0: # Flat on YZ plane (normal along X)
				var u_ratio = (local_point.z - local_min.z) / local_box_size.z if local_box_size.z > 0.0 else 0.5
				var v_ratio = (local_point.y - local_min.y) / local_box_size.y if local_box_size.y > 0.0 else 0.5
				uv.x = 1.0 - u_ratio if flip_x else u_ratio
				uv.y = v_ratio if flip_y else 1.0 - v_ratio
			1: # Flat on XZ plane (normal along Y)
				var u_ratio = (local_point.x - local_min.x) / local_box_size.x if local_box_size.x > 0.0 else 0.5
				var v_ratio = (local_point.z - local_min.z) / local_box_size.z if local_box_size.z > 0.0 else 0.5
				uv.x = 1.0 - u_ratio if flip_x else u_ratio
				uv.y = 1.0 - v_ratio if flip_y else v_ratio
			2: # Flat on XY plane (normal along Z, e.g. QuadMesh/screens)
				var u_ratio = (local_point.x - local_min.x) / local_box_size.x if local_box_size.x > 0.0 else 0.5
				var v_ratio = (local_point.y - local_min.y) / local_box_size.y if local_box_size.y > 0.0 else 0.5
				uv.x = 1.0 - u_ratio if flip_x else u_ratio
				uv.y = v_ratio if flip_y else 1.0 - v_ratio
				
		return uv

	# Method 3: Fallback to Planar AABB projection (Works for QuadMesh, PlaneMesh, BoxMesh, flat surfaces)
	var aabb = mesh_res.get_aabb()
	var size = aabb.size
	
	# Determine the smallest axis (the thickness/flat axis)
	var min_size = size.x
	var min_axis = 0
	if size.y < min_size:
		min_size = size.y
		min_axis = 1
	if size.z < min_size:
		min_size = size.z
		min_axis = 2
		
	# Get camera transform to detect flips
	var cam_transform = camera.global_transform
	var cam_right = cam_transform.basis.x.normalized()
	var cam_up = cam_transform.basis.y.normalized()
	
	var h_axis_global = Vector3.ZERO
	var v_axis_global = Vector3.ZERO
	
	match min_axis:
		0: # YZ plane (normal along X)
			h_axis_global = mesh.global_transform.basis.z.normalized()
			v_axis_global = mesh.global_transform.basis.y.normalized()
		1: # XZ plane (normal along Y, e.g. PlaneMesh)
			h_axis_global = mesh.global_transform.basis.x.normalized()
			v_axis_global = mesh.global_transform.basis.z.normalized()
		2: # XY plane (normal along Z, e.g. QuadMesh)
			h_axis_global = mesh.global_transform.basis.x.normalized()
			v_axis_global = mesh.global_transform.basis.y.normalized()
			
	var flip_x = h_axis_global.dot(cam_right) < 0.0
	var flip_y = v_axis_global.dot(cam_up) < 0.0

	var uv = Vector2.ZERO
	match min_axis:
		0: # Flat on YZ plane (normal along X)
			var u_ratio = (local_point.z - aabb.position.z) / size.z if size.z > 0.0 else 0.5
			var v_ratio = (local_point.y - aabb.position.y) / size.y if size.y > 0.0 else 0.5
			uv.x = 1.0 - u_ratio if flip_x else u_ratio
			uv.y = v_ratio if flip_y else 1.0 - v_ratio
		1: # Flat on XZ plane (normal along Y, e.g. PlaneMesh)
			var u_ratio = (local_point.x - aabb.position.x) / size.x if size.x > 0.0 else 0.5
			var v_ratio = (local_point.z - aabb.position.z) / size.z if size.z > 0.0 else 0.5
			uv.x = 1.0 - u_ratio if flip_x else u_ratio
			uv.y = 1.0 - v_ratio if flip_y else v_ratio
		2: # Flat on XY plane (normal along Z, e.g. QuadMesh)
			var u_ratio = (local_point.x - aabb.position.x) / size.x if size.x > 0.0 else 0.5
			var v_ratio = (local_point.y - aabb.position.y) / size.y if size.y > 0.0 else 0.5
			uv.x = 1.0 - u_ratio if flip_x else u_ratio
			uv.y = v_ratio if flip_y else 1.0 - v_ratio
			
	return uv
