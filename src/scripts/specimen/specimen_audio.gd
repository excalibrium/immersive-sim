class_name SpecimenAudio
extends AudioStreamPlayer3D

# Vocalization audio pools, tiered by identity_coherence (assigned in Inspector)
@export var vocalize_incoherent: Array[AudioStream] = [
	preload("res://src/assets/audio/sfx/specimen_audio_incoherent_1.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_incoherent_2.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_incoherent_3.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_incoherent_4.wav"),
]
@export var vocalize_sentence: Array[AudioStream] = [
	preload("res://src/assets/audio/sfx/specimen_audio_sentence_1.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_sentence_2.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_sentence_3.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_sentence_4.wav"),
]
@export var vocalize_complex: Array[AudioStream] = [
	preload("res://src/assets/audio/sfx/specimen_audio_complex_sentence_1.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_complex_sentence_2.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_complex_sentence_3.wav"),
	preload("res://src/assets/audio/sfx/specimen_audio_complex_sentence_4.wav"),
]

## Plays a vocalization audio stream from the appropriate pool based on identity coherence.
func play_vocalize(identity_coherence: float) -> void:
	var pool: Array[AudioStream] = []
	if identity_coherence < SpecimenProfile.COHERENCE_TIER_LOW:
		pool = vocalize_incoherent
	elif identity_coherence < SpecimenProfile.COHERENCE_TIER_HIGH:
		pool = vocalize_sentence
	else:
		pool = vocalize_complex
		
	if not pool.is_empty():
		stream = pool.pick_random()
		play()
