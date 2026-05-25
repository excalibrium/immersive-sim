extends Node3D
class_name PlayerInteractor

## Centralized interaction logic for the player.
## Combines Raycast (precision) and Area3D (proximity) to find the best target.

enum State { NONE, INTERACTABLE, DENIED }

signal target_state_changed(state: State)
signal target_prompt_changed(prompt_data: Dictionary)

@export var raycast: RayCast3D
@export var proximity_area: Area3D

var current_target: Interactable = null
var current_state: State = State.NONE

func _ready() -> void:
	if Settings.has_signal("setting_changed"):
		Settings.setting_changed.connect(_on_settings_changed)

func _on_settings_changed(section: String, key: String, _value: Variant) -> void:
	if section == "input" and (key == "keybind" or key == "keybinds"):
		_push_prompt_update()

func _push_prompt_update() -> void:
	if current_target:
		var prompt_data = current_target.get_interaction_prompt_data(get_parent())
		target_prompt_changed.emit(prompt_data)
	else:
		target_prompt_changed.emit({})

func _physics_process(_delta: float):
	if TimeManager.time_scale <= 0.0 or not WindowManager.is_mouse_captured():
		# Clear target if mouse is visible (UI is open)
		if current_target:
			current_target.unfocus()
			current_target = null
			current_state = State.NONE
			target_state_changed.emit(current_state)
			target_prompt_changed.emit({})
		return
		
	var new_target = _find_best_target()
	var new_state = State.NONE
	
	if new_target:
		new_state = State.DENIED if new_target.is_denied(get_parent()) else State.INTERACTABLE
	
	var target_changed = (new_target != current_target)
	
	if target_changed:
		if current_target:
			current_target.unfocus()
		
		current_target = new_target
		
		if current_target:
			current_target.focus()
	
	var state_changed = (new_state != current_state)
	if state_changed:
		current_state = new_state
		target_state_changed.emit(current_state)
		
	if target_changed or state_changed or current_target != null:
		_push_prompt_update()

func _unhandled_input(event: InputEvent):
	if TimeManager.time_scale <= 0.0 or not WindowManager.is_mouse_captured():
		return
		
	if event.is_action_pressed("interact"):
		if current_target:
			current_target.interact(get_parent()) # Pass the player node

func _find_best_target() -> Interactable:
	# 1. Check Raycast (highest priority)
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		if Input.is_action_just_pressed("interact"):
			print("Debug: Player interact raycast hit: ", collider.name, " (", collider.get_path(), ")")
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
