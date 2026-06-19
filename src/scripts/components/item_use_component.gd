extends Node
class_name ItemUseComponent

## Component that manages animating and triggering custom item use logic.
## Should be added to the first-person visual scene of the item.

signal item_used(player: Player)

@export var animation_player: AnimationPlayer
@export var use_animation: String = "use"
@export var idle_animation: String = "idle"

func _ready() -> void:
	pass

func trigger_use(player: Player) -> void:
	if animation_player and animation_player.has_animation(use_animation):
		animation_player.play(use_animation)
		# Ensure we return to idle after use
		if animation_player.has_animation(idle_animation):
			animation_player.queue(idle_animation)
			
	item_used.emit(player)
