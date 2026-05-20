extends Node3D
class_name PlayerInteractor

## Centralized interaction logic for the player.
## Combines Raycast (precision) and Area3D (proximity) to find the best target.

enum State { NONE, INTERACTABLE, DENIED }

signal target_state_changed(state: State)

@export var raycast: RayCast3D
@export var proximity_area: Area3D

var current_target: Interactable = null
var current_state: State = State.NONE

func _physics_process(_delta: float):
	if TimeManager.time_scale <= 0.0:
		return
		
	var new_target = _find_best_target()
	var new_state = State.NONE
	
	if new_target:
		new_state = State.DENIED if new_target.is_denied(get_parent()) else State.INTERACTABLE
	
	if new_target != current_target:
		if current_target:
			current_target.unfocus()
		
		current_target = new_target
		
		if current_target:
			current_target.focus()
	
	if new_state != current_state:
		current_state = new_state
		target_state_changed.emit(current_state)

func _unhandled_input(event: InputEvent):
	if TimeManager.time_scale <= 0.0:
		return
		
	if event.is_action_pressed("interact"):
		if current_target:
			current_target.interact(get_parent()) # Pass the player node

func _find_best_target() -> Interactable:
	# 1. Check Raycast (highest priority)
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		var interactable = _get_interactable_from_node(collider)
		if interactable:
			return interactable
	
	# 2. Check Area3D (proximity priority)
	if proximity_area:
		var areas = proximity_area.get_overlapping_areas()
		var bodies = proximity_area.get_overlapping_bodies()
		
		var candidates: Array[Interactable] = []
		
		for a in areas:
			var i = _get_interactable_from_node(a)
			if i: candidates.append(i)
		
		for b in bodies:
			var i = _get_interactable_from_node(b)
			if i: candidates.append(i)
		
		if candidates.size() > 0:
			# Sort by priority export on Interactable
			candidates.sort_custom(func(a, b): return a.priority > b.priority)
			return candidates[0]
			
	return null

func _get_interactable_from_node(node: Node) -> Interactable:
	if not node: return null
	
	# Check if node is an Interactable
	if node is Interactable:
		return node
		
	# Check children for Interactable component
	for child in node.get_children():
		if child is Interactable:
			return child
			
	return null
