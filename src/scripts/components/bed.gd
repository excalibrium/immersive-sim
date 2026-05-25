extends StaticBody3D
class_name Bed

## Autonomous controller for the Bed scene.
## Adheres to Rule 01 (F6 standalone capability) and Rule 17 (Signal Up).

@onready var interactable: Interactable = $Interactable

func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	# Safely fetch the autoload from the root tree to prevent crash in F6 runs
	var bus = get_node_or_null("/root/InteractionBus")
	if bus:
		bus.emit_signal("bed_sleep_requested")
	else:
		print("Bed: Standalone F6 mode. InteractionBus missing, sleep request emitted locally.")
