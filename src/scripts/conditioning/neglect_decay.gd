class_name NeglectDecay
extends Node

const DECAY_RATE = 0.5      # per cycle per unaddressed action
const WEIGHT_FLOOR = 1.0

# Call this at cycle end before lights out
func apply_cycle_decay(addressed_actions: Array) -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	for action_id in profile.action_pool:
		if action_id not in addressed_actions:
			var current = profile.action_pool[action_id]
			profile.action_pool[action_id] = max(
				current - DECAY_RATE, WEIGHT_FLOOR
			)
