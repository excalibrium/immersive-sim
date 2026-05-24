extends Label
class_name APLabel

## Formats and updates the AP text readout.
func update_ap(new_ap: int) -> void:
	var cycle = 1
	if SpecimenBridge.profile:
		cycle = SpecimenBridge.profile.current_cycle
	text = "CYCLE " + str(cycle) + " | AP: " + str(new_ap) + " / 10"
