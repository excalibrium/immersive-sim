extends Node
class_name AnimationToggle

## Component that toggles between two states when interacted, playing one-shot animations.

signal state_changed(is_state_1: bool)

@export var interactable: Interactable
@export var animation_player: AnimationPlayer

@export var state_0_animation: String = "close"
@export var state_1_animation: String = "open"

@export var state_0_text_key: String = "INTERACT_ACTIVATE"
@export var state_1_text_key: String = "INTERACT_DEACTIVATE"

## If true, the state 0 animation plays on ready. If false, the visuals snap to the end of state 0 animation immediately.
@export var play_on_start: bool = false

var is_state_1: bool = false

func _ready() -> void:
	# (Rule 38): Never assume a sibling is ready.
	# Await a frame to ensure @export dependencies are fully initialized.
	await get_tree().process_frame
	
	# Fallback resolution of dependencies
	if not is_instance_valid(interactable):
		if is_instance_valid(get_parent()):
			if get_parent() is Interactable:
				interactable = get_parent()
			else:
				interactable = get_parent().find_child("*", true, false) as Interactable
				if not interactable:
					for child in get_parent().get_children():
						if child is Interactable:
							interactable = child
							break
							
	if not is_instance_valid(animation_player):
		if is_instance_valid(get_parent()):
			animation_player = get_parent().find_child("*", true, false) as AnimationPlayer
			if not animation_player:
				for child in get_parent().get_children():
					if child is AnimationPlayer:
						animation_player = child
						break

	if is_instance_valid(interactable):
		interactable.interacted.connect(_on_interacted)
		
	# Apply initial state (always state 0/false initially, snapping if play_on_start is false)
	set_state(false, play_on_start)

func _on_interacted(_interactor: Node) -> void:
	toggle()

func toggle() -> void:
	set_state(not is_state_1, true)

func set_state(to_state_1: bool, play_anim: bool = true) -> void:
	is_state_1 = to_state_1
	
	var anim_name = state_1_animation if is_state_1 else state_0_animation
	
	if is_instance_valid(animation_player) and anim_name != "":
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
			if not play_anim:
				var anim = animation_player.get_animation(anim_name)
				if anim:
					# Snap to the end of the one-shot animation
					animation_player.advance(anim.length)
		else:
			push_warning("AnimationToggle: AnimationPlayer is missing animation: ", anim_name)
			
	_update_interactable_text()
	state_changed.emit(is_state_1)

func _update_interactable_text() -> void:
	if is_instance_valid(interactable):
		interactable.interact_text_key = state_1_text_key if is_state_1 else state_0_text_key
