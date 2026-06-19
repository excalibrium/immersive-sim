extends Node3D
class_name DecalProjector

## Reusable screen-space decal projection component using Godot's native Decal node.
## Manages a pool of native Decal nodes. Does not know about specific
## items or gameplay — receives positions via spawn_decal() and handles
## pooling, fading, and cleanup internally.

signal decal_spawned(position: Vector3)

@export var pool_size: int = 64
@export var decal_texture: Texture2D
@export var decal_scale: Vector3 = Vector3(0.3, 2.0, 0.6)
@export var fade_delay: float = 0.5
@export var fade_duration: float = 1.5
@export var speed_stretch_factor: float = 0.15
@export var max_stretch: float = 3.0	
@export_flags_3d_render var cull_mask: int = 1048575 # Default: all layers
@export_range(0.0, 1.0) var normal_fade: float = 0.5

var _pool: Array[Decal] = []
var _pool_index: int = 0
var _active_tweens: Dictionary = {} # Decal -> Tween

func _ready() -> void:
	call_deferred("_initialize_pool")

func _exit_tree() -> void:
	for tween in _active_tweens.values():
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	for decal in _pool:
		if is_instance_valid(decal):
			decal.queue_free()
	_pool.clear()

func _initialize_pool() -> void:
	if not decal_texture:
		push_warning("DecalProjector: No decal_texture assigned, pool not created.")
		return

	for i in range(pool_size):
		var decal := Decal.new()
		decal.texture_albedo = decal_texture
		decal.size = decal_scale
		decal.cull_mask = cull_mask
		decal.normal_fade = normal_fade
		decal.modulate = Color(1.0, 1.0, 1.0, 0.118)
		decal.visible = false
		decal.top_level = true
		
		add_child(decal)
		_pool.append(decal)


## Places a projected decal at [world_pos] with the given [yaw_rotation]
## (radians, Y-axis only) and velocity-based [speed] stretch.
func spawn_decal(world_pos: Vector3, yaw_rotation: float, speed: float) -> void:
	if _pool.is_empty():
		return

	var decal := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()

	# Kill any running tween on this decal to recycle cleanly
	if _active_tweens.has(decal):
		var old_tween = _active_tweens[decal]
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		_active_tweens.erase(decal)

	# Position and orient the projector box
	decal.global_position = world_pos
	decal.global_rotation = Vector3(0.0, yaw_rotation, 0.0)

	# Velocity-based X stretch, clamped
	var stretch := 1.0 + speed * speed_stretch_factor
	stretch = clampf(stretch, 1.0, max_stretch)
	decal.size = Vector3(decal_scale.x * stretch, decal_scale.y, decal_scale.z)

	# Reset opacity and make visible
	decal.albedo_mix = 1.0
	decal.visible = true

	# Fade out tween
	var tween := create_tween()
	_active_tweens[decal] = tween
	tween.tween_property(decal, "albedo_mix", 0.0, fade_duration).set_delay(fade_delay)
	tween.tween_callback(func():
		decal.visible = false
		_active_tweens.erase(decal)
	)

	decal_spawned.emit(world_pos)
