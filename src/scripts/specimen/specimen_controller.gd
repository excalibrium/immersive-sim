class_name SpecimenController
extends Node

signal action_selected(action_id: String)


@export var base_action_interval : float = 16.0
# Current active action ID
var active_action: String = ""

var action_timer: Timer

# Boredom tracking dictionary (Rule 18 / Runtime selection concerns)
var action_boredom: Dictionary = {
	"APPROACH_PLAYER":    0.0,
	"RETREAT":            0.0,
	"VOCALIZE":           0.0,
	"INVESTIGATE":        0.0,
	"DISPLAY":            0.0,
	"PLAY":               0.0,
	"WASTE_BEHAVIOR":     0.0,
	"SLEEP_EARLY":        0.0,
	"MIRROR_PLAYER":      0.0,
	"REFUSE_INTERACTION": 0.0,
}

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
	# Halve boredom values at cycle start
	for a in action_boredom:
		action_boredom[a] = action_boredom[a] * 0.5
	active_action = "PLAY"
	action_selected.emit(active_action)

func deactivate() -> void:
	set_process(false)
	action_timer.stop()

func confirm_action(action_id: String) -> void:
	active_action = action_id
	_update_action_rate()
	_update_boredom(action_id)

func _update_boredom(action_id: String) -> void:
	if not action_boredom.has(action_id):
		return
	# Decay all other actions
	for a in action_boredom:
		if a != action_id:
			action_boredom[a] = max(action_boredom[a] - 0.15, 0.0)
			
	# Increase boredom for the performed action
	var repeat_multiplier = 1.0
	var profile = SpecimenBridge.profile
	if profile and profile.action_log.size() > 1 and profile.action_log[1] == action_id:
		repeat_multiplier = 1.8
		
	action_boredom[action_id] = clamp(action_boredom[action_id] + 0.3 * repeat_multiplier, 0.0, 1.0)

func _update_action_rate() -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	# Dampened APM scaling
	var base_interval = base_action_interval
	var ratio = profile.get_total_weight() / 110.0 # 110.0 is the baseline sum of weights
	var factor = sqrt(ratio)
	# Clamp between 6.0 and 20.0 seconds to balance APM
	action_timer.wait_time = clamp(base_interval / factor, 6.0, 20.0)
	
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
	
	# Compute modified weights based on boredom
	var modified_weights = {}
	var total = 0.0
	for action_id in pool:
		var base_w = pool[action_id]
		var b_val = action_boredom.get(action_id, 0.0)
		var factor = clamp(1.0 - b_val, 0.1, 1.0)
		var w = base_w * factor
		modified_weights[action_id] = w
		total += w
		
	var roll = randf() * total
	var cumulative = 0.0
	for action_id in modified_weights:
		cumulative += modified_weights[action_id]
		if roll <= cumulative:
			return action_id
	# Fallback just in case floating point imprecision causes loop to finish without return
	return pool.keys().back()
