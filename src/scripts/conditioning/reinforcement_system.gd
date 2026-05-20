class_name ReinforcementSystem
extends Node

# Recency weights for log positions [most recent, second, third]
const RECENCY_WEIGHTS = [10.0, 5.0, 2.0]
const RUTHLESSNESS_DELTA = 5.0

func reinforce() -> void:
	_apply_conditioning(1.0)
	if SpecimenBridge.profile:
		SpecimenBridge.profile.ruthlessness = max(
			SpecimenBridge.profile.ruthlessness - RUTHLESSNESS_DELTA, 0.0
		)

func punish() -> void:
	_apply_conditioning(-1.0)
	if SpecimenBridge.profile:
		SpecimenBridge.profile.ruthlessness = min(
			SpecimenBridge.profile.ruthlessness + RUTHLESSNESS_DELTA, 100.0
		)

func _apply_conditioning(direction: float) -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	var log_list = profile.action_log

	for i in range(log_list.size()):
		var action_id = log_list[i]
		var weight_delta = RECENCY_WEIGHTS[i] * direction

		# Apply to action pool weight
		profile.apply_action_weight(action_id, weight_delta)

		# Apply to primary variable
		var action_def = ActionDefinitions.ACTIONS[action_id]
		var primary = action_def["primary"]
		var variable_delta = (weight_delta * 0.1)  # tune during playtesting
		profile.apply_delta(primary, variable_delta)

		# Apply to secondary variable if present
		if action_def["secondary"] != "":
			profile.apply_delta(
				action_def["secondary"],
				variable_delta * action_def["sw"]
			)
