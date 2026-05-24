extends WorldPanel

signal end_cycle_requested

# --- UI Node References ---
@onready var end_cycle_label: Label = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer/NinePatchRect/END_CYCLE_LABEL
@onready var end_cycle_btn: Button = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer/NinePatchRect/Button
@onready var reports_label: Label = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer2/NinePatchRect/REPORTS_LABEL
@onready var reports_btn: Button = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer2/NinePatchRect/Button

func _ready() -> void:
	super._ready()
	if end_cycle_btn:
		end_cycle_btn.pressed.connect(_on_end_cycle_btn_pressed)
	_update_ui()

func _update_ui() -> void:
	pass

func _on_end_cycle_btn_pressed() -> void:
	end_cycle_requested.emit()
