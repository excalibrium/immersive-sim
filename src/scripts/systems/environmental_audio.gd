class_name EnvironmentalAudio
extends Node3D

## Component to manage environmental audio levels, including silencing lights on blackout.

## Prefix used to discover light hum audio players.
@export var light_noise_prefix: String = "Light_"

## Volume level in dB that represents complete silence.
@export var silent_db: float = -80.0

var light_noises: Array[AudioStreamPlayer3D] = []
var light_noise_base_volumes: Dictionary = {} # AudioStreamPlayer3D -> float
var volume_tween: Tween = null

func _ready() -> void:
	# Discover and cache all child AudioStreamPlayer3D nodes that start with the configured prefix
	for child in get_children():
		if child is AudioStreamPlayer3D and child.name.begins_with(light_noise_prefix):
			light_noises.append(child)
			light_noise_base_volumes[child] = child.volume_db
## Slowly dims all light hum noises down to silence.
func dim_noises(duration: float) -> void:
	if volume_tween:
		volume_tween.kill()
		volume_tween = null
		
	if duration <= 0.0:
		snap_noises_out()
		return
		
	volume_tween = create_tween().set_parallel(true)
	for player in light_noises:
		volume_tween.tween_property(player, "volume_db", silent_db, duration)
## Instantly mutes all light hum noises.
func snap_noises_out() -> void:
	if volume_tween:
		volume_tween.kill()
		volume_tween = null
		
	for player in light_noises:
		player.volume_db = silent_db
## Fades light hum noises back to their default volume levels.
func fade_noises_on(duration: float) -> void:
	if volume_tween:
		volume_tween.kill()
		volume_tween = null

	if duration <= 0.0:
		for player in light_noises:
			var base = light_noise_base_volumes.get(player, 0.0)
			player.volume_db = base
		return
		
	volume_tween = create_tween().set_parallel(true)
	for player in light_noises:
		var base = light_noise_base_volumes.get(player, 0.0)
		volume_tween.tween_property(player, "volume_db", base, duration)
