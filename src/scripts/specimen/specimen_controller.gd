class_name SpecimenController
extends Node

signal action_selected(action_id: String)


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
