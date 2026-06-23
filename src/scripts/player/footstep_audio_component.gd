extends Node3D
class_name FootstepAudioComponent

# --- CONFIGURABLE EXPORTS ---
@export var step_sounds: Array[AudioStream] = [
	preload("res://src/assets/audio/sfx/steps/metal/step_metal_1.wav"),
	preload("res://src/assets/audio/sfx/steps/metal/step_metal_2.wav"),
	preload("res://src/assets/audio/sfx/steps/metal/step_metal_3.wav"),
	preload("res://src/assets/audio/sfx/steps/metal/step_metal_4.wav")
]
@export var volume_db: float = -12.0
@export var pitch_min: float = 0.85
@export var pitch_max: float = 1.15
@export var audio_bus: StringName = &"Master"

# --- RUNTIME STATE ---
var _players: Array[AudioStreamPlayer3D] = []
var _next_player_index: int = 0
var _last_sound_index: int = -1

func _ready() -> void:
	# Instantiate two players for polyphony / overlap
	for i in range(2):
		var p = AudioStreamPlayer3D.new()
		p.volume_db = volume_db
		p.bus = audio_bus
		p.max_distance = 25.0
		p.unit_size = 5.0
		add_child(p)
		_players.append(p)

## Selects a random step sound (preventing consecutive repeats) and plays it with randomized pitch.
func play_footstep() -> void:
	if step_sounds.is_empty():
		return
		
	var index = randi() % step_sounds.size()
	if step_sounds.size() > 1 and index == _last_sound_index:
		index = (index + 1) % step_sounds.size()
	_last_sound_index = index
	
	var sound = step_sounds[index]
	
	var player = _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	
	player.stream = sound
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()
