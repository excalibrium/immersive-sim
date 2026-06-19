extends Label
class_name APLabel

var last_ap: int = 10

func _ready() -> void:
	update_ap(10)
	if Game.session:
		Game.session.credits_changed.connect(_on_credits_changed)

func _on_credits_changed(_new_credits: int) -> void:
	update_ap(last_ap)

## Formats and updates the AP text readout.
func update_ap(new_ap: int) -> void:
	last_ap = new_ap
	var cycle = 1
	if SpecimenBridge.profile:
		cycle = SpecimenBridge.profile.current_cycle
	
	var credits = 10
	if Game.session:
		credits = Game.session.credits
	
	if cycle < 0:
		visible = false
	else:
		visible = true
		text = "CYCLE " + str(cycle) + " | AP: " + str(new_ap) + " / 10\nCREDS: " + str(credits)
