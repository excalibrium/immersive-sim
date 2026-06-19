extends Node3D
class_name ItemVisual

## Base class for all first-person held item visual scenes.
## Handles initial appear animations and looping idle transitions.

@export var animation_player: AnimationPlayer
@export var appear_animation: String = "appear"
@export var idle_animation: String = "idle"

func _ready() -> void:
	if animation_player:
		if appear_animation != "" and animation_player.has_animation(appear_animation):
			animation_player.play(appear_animation)
			if idle_animation != "" and animation_player.has_animation(idle_animation):
				animation_player.queue(idle_animation)
		elif idle_animation != "" and animation_player.has_animation(idle_animation):
			animation_player.play(idle_animation)
