extends Label
class_name APLabel

func _ready() -> void:
	update_ap(10)

## Formats and updates the AP text readout.
func update_ap(new_ap: int) -> void:
	var cycle = 1
	if SpecimenBridge.profile:
		cycle = SpecimenBridge.profile.current_cycle
	
	if cycle < 0:
		visible = false
	else:
		visible = true
		text = "CYCLE " + str(cycle) + " | AP: " + str(new_ap) + " / 10"
