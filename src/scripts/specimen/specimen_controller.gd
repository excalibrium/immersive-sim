class_name SpecimenController
extends Node

signal action_selected(action_id: String)

# Containment chamber boundaries for clamping target positions
const CELL_MIN_X = 18.0
const CELL_MAX_X = 34.0
const CELL_MIN_Z = -18.0
const CELL_MAX_Z = -2.0

@export var base_action_interval : float = 16.0
# Current active action ID
var active_action: String = ""

var action_timer: Timer

func _ready() -> void:
	action_timer = Timer.new()
	action_timer.name = "ActionTimer"
	add_child(action_timer)
	action_timer.timeout.connect(_on_action_timer_timeout)
	
	if SpecimenBridge.profile and SpecimenBridge.profile.phase == SpecimenProfile.Phase.EGG:
		action_timer.stop()
		set_process(false)
	else:
		_update_action_rate()

func activate() -> void:
	set_process(true)
	_update_action_rate()
	active_action = "PLAY"
	action_selected.emit(active_action)

func deactivate() -> void:
	set_process(false)
	action_timer.stop()

func confirm_action(action_id: String) -> void:
	active_action = action_id
	_update_action_rate()

func _update_action_rate() -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	# Higher total weight = more frequent actions
	var base_interval = base_action_interval
	var min_interval = 2.0
	var normalized = profile.get_total_weight() / 125.0  # 100 = baseline
	action_timer.wait_time = max(base_interval / normalized, min_interval)
	
	if action_timer.is_stopped() and is_processing():
		action_timer.start()

func _on_action_timer_timeout() -> void:
	if not SpecimenBridge.profile or SpecimenBridge.profile.phase == SpecimenProfile.Phase.EGG:
		action_timer.stop()
		return
		
	var action_id = _select_action()
	action_selected.emit(action_id)

func _select_action() -> String:
	var profile = SpecimenBridge.profile
	var pool = profile.action_pool
	var total = profile.get_total_weight()
	var roll = randf() * total
	var cumulative = 0.0
	for action_id in pool:
		cumulative += pool[action_id]
		if roll <= cumulative:
			return action_id
	# Fallback just in case floating point imprecision causes loop to finish without return
	return pool.keys().back()

## Calculates the target position for pathfinding based on the current action.
## This is a pure mapping function — all context data is passed in via parameters.
## The parent (Specimen) is responsible for gathering player_pos and placed_objects.
##
## Mappings of the 10 actions:
## 1. APPROACH_PLAYER: Pathfinds towards the player's position (clamped inside boundaries). Represents seeking contact.
## 2. RETREAT: Pathfinds away from the player, moving to the back wall of the cell. Represents fear or distress.
## 3. VOCALIZE: Stops moving, triggers audio/visual tell, representing attention-seeking.
## 4. INVESTIGATE: Picks a random location/placed object in the cell and pathfinds to it. Represents cognitive curiosity.
## 5. DISPLAY: Stops in place and performs a threatening visual pulse. Represents self-assertion.
## 6. PLAY: Picks random waypoints, pathfinds to them, and spins or moves erratically. Represents playfulness.
## 7. WASTE_BEHAVIOR: Stops moving, wanders to a corner, aimless idle behaviors. Represents depression/low motivation.
## 8. SLEEP_EARLY: Walks to a corner, dims emission light, and enters sleep state. Represents low reward or energy recovery.
## 9. MIRROR_PLAYER: Mimics player movement along the viewing window glass. Represents high resonance. (Future: There wasn't any glass. it should take the center point between the player and itself and should mimic the player then.)
## 10. REFUSE_INTERACTION: Turns away from the glass (opposite of player heading) and remains static. Represents stubbornness.
func get_target_position(action_id: String, current_pos: Vector3, player_pos: Vector3, placed_objects: Array, player_start: Vector3 = Vector3.ZERO, specimen_start: Vector3 = Vector3.ZERO) -> Vector3:
	var has_player = player_pos != Vector3.ZERO
	match action_id:
		"APPROACH_PLAYER":
			# APPROACH_PLAYER: Pathfinds towards the player's position (clamped inside boundaries). Represents seeking contact.
			if has_player:
				return Vector3(
					clamp(player_pos.x, CELL_MIN_X, CELL_MAX_X),
					current_pos.y,
					clamp(player_pos.z, CELL_MIN_Z, CELL_MAX_Z)
				)
			else:
				# Fallback to the front glass center
				return Vector3(CELL_MIN_X, current_pos.y, (CELL_MIN_Z + CELL_MAX_Z) / 2.0)
				
		"RETREAT":
			# RETREAT: Pathfinds away from the player, moving to the back wall of the cell. Represents fear or distress.
			var target_z = current_pos.z
			if has_player:
				# Move Z away from the player's Z coordinate
				target_z = clamp(2.0 * current_pos.z - player_pos.z, CELL_MIN_Z, CELL_MAX_Z)
			else:
				target_z = randf_range(CELL_MIN_Z, CELL_MAX_Z)
			return Vector3(CELL_MAX_X, current_pos.y, target_z)
			
		"VOCALIZE":
			# VOCALIZE: Stops moving, triggers audio/visual tell, representing attention-seeking.
			return current_pos
			
		"INVESTIGATE":
			# INVESTIGATE: Picks a random location/placed object in the cell and pathfinds to it. Represents cognitive curiosity.
			if not placed_objects.is_empty():
				var chosen_obj = placed_objects.pick_random()
				if chosen_obj is Node3D:
					return Vector3(
						clamp(chosen_obj.global_position.x, CELL_MIN_X, CELL_MAX_X),
						current_pos.y,
						clamp(chosen_obj.global_position.z, CELL_MIN_Z, CELL_MAX_Z)
					)
			return Vector3(
				randf_range(CELL_MIN_X, CELL_MAX_X),
				current_pos.y,
				randf_range(CELL_MIN_Z, CELL_MAX_Z)
			)
				
		"DISPLAY":
			# DISPLAY: Stops in place and performs a threatening visual pulse. Represents self-assertion.
			return current_pos
			
		"PLAY":
			# PLAY: Picks random waypoints, pathfinds to them, and spins or moves erratically. Represents playfulness.
			return Vector3(
				randf_range(CELL_MIN_X, CELL_MAX_X),
				current_pos.y,
				randf_range(CELL_MIN_Z, CELL_MAX_Z)
			)
			
		"WASTE_BEHAVIOR":
			# WASTE_BEHAVIOR: Stops moving, wanders to a corner, aimless idle behaviors. Represents depression/low motivation.
			var corners = [
				Vector3(CELL_MIN_X, current_pos.y, CELL_MIN_Z),
				Vector3(CELL_MIN_X, current_pos.y, CELL_MAX_Z),
				Vector3(CELL_MAX_X, current_pos.y, CELL_MIN_Z),
				Vector3(CELL_MAX_X, current_pos.y, CELL_MAX_Z)
			]
			return corners.pick_random()
			
		"SLEEP_EARLY":
			# SLEEP_EARLY: Walks to a corner, dims emission light, and enters sleep state. Represents low reward or energy recovery.
			var corners = [
				Vector3(CELL_MIN_X, current_pos.y, CELL_MIN_Z),
				Vector3(CELL_MIN_X, current_pos.y, CELL_MAX_Z),
				Vector3(CELL_MAX_X, current_pos.y, CELL_MIN_Z),
				Vector3(CELL_MAX_X, current_pos.y, CELL_MAX_Z)
			]
			return corners.pick_random()
			
		"MIRROR_PLAYER":
			# MIRROR_PLAYER: Mimics player movement. Represents high resonance.
			if has_player:
				var p_start = player_start
				var s_start = specimen_start
				if p_start == Vector3.ZERO and s_start == Vector3.ZERO:
					# Fallback if starting coordinates were not provided/cached
					p_start = player_pos
					s_start = current_pos
				
				var target = p_start + s_start - player_pos
				return Vector3(
					clamp(target.x, CELL_MIN_X, CELL_MAX_X),
					current_pos.y,
					clamp(target.z, CELL_MIN_Z, CELL_MAX_Z)
				)
			else:
				# Fallback to the center of the cell
				return Vector3(
					(CELL_MIN_X + CELL_MAX_X) / 2.0,
					current_pos.y,
					(CELL_MIN_Z + CELL_MAX_Z) / 2.0
				)
				
		"REFUSE_INTERACTION":
			# REFUSE_INTERACTION: Turns away from the glass (opposite of player heading) and remains static. Represents stubbornness.
			return current_pos
			
		_:
			return current_pos

## Returns true if the given action tracks the player and needs periodic target refreshing.
func is_tracking_action(action_id: String) -> bool:
	return action_id in ["APPROACH_PLAYER", "MIRROR_PLAYER"]
