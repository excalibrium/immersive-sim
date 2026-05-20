extends "res://src/scripts/ui/world_panel.gd"

## Controller for the Incubator Chamber's Control Panel.
## Inherits 3D barycentric projection logic and adds environmental state interaction.

enum Mode {
	HEAT,
	MOISTURE
}

var active_mode: Mode = Mode.MOISTURE

# --- UI Node References ---
@onready var moisture_percentage_label: Label = $TempControlViewport/MarginContainer/Control/MarginContainer/HBoxContainer/moisture_VBox/bottom/HBoxContainer/VBoxContainer/MOISTURE_PERCENTAGE
@onready var moisture_select_btn: Button = $TempControlViewport/MarginContainer/Control/MarginContainer/HBoxContainer/moisture_VBox/bottom/moisture
@onready var heat_degree_label: Label = $TempControlViewport/MarginContainer/Control/MarginContainer/HBoxContainer/heat_VBox/bottom/HBoxContainer/VBoxContainer/HEAT_DEGREE
@onready var heat_select_btn: Button = $TempControlViewport/MarginContainer/Control/MarginContainer/HBoxContainer/heat_VBox/bottom/moisture

@onready var too_high_label: Label = $TempControlViewport/MarginContainer/Control/MarginContainer/MarginContainer/VBoxContainer/TOOHIGHLabel
@onready var too_low_label: Label = $TempControlViewport/MarginContainer/Control/MarginContainer/MarginContainer/VBoxContainer/TOOLOWLabel
@onready var chosen_level_label: Label = $TempControlViewport/MarginContainer/Control/MarginContainer/MarginContainer/VBoxContainer/ChosenLevelLabel

@onready var increase_btn: Button = $TempControlViewport/MarginContainer/Control/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/increase
@onready var decrease_btn: Button = $TempControlViewport/MarginContainer/Control/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/decrease

func _ready() -> void:
	# Call parent ready to cache mesh and setup area interaction
	super._ready()
	
	# Connect UI buttons
	moisture_select_btn.pressed.connect(_on_moisture_select_pressed)
	heat_select_btn.pressed.connect(_on_heat_select_pressed)
	increase_btn.pressed.connect(_on_increase_pressed)
	decrease_btn.pressed.connect(_on_decrease_pressed)
	
	_update_ui()

func _update_ui() -> void:
	var profile = EnvironmentBridge.profile
	if not profile:
		return
		
	# Update environmental labels
	moisture_percentage_label.text = "%d%%" % round(profile.moisture)
	heat_degree_label.text = "%d°C" % round(profile.heat)
	
	# Update active mode highlight and labels
	match active_mode:
		Mode.MOISTURE:
			chosen_level_label.text = "%d%%" % round(profile.moisture)
			too_high_label.visible = profile.is_moisture_too_high()
			too_low_label.visible = profile.is_moisture_too_low()
			
			# Visual hint: modulate active mode select buttons/labels
			moisture_percentage_label.modulate = Color(1.0, 1.0, 1.0)
			heat_degree_label.modulate = Color(0.5, 0.5, 0.5)
			
		Mode.HEAT:
			chosen_level_label.text = "%d°C" % round(profile.heat)
			too_high_label.visible = profile.is_heat_too_high()
			too_low_label.visible = profile.is_heat_too_low()
			
			moisture_percentage_label.modulate = Color(0.5, 0.5, 0.5)
			heat_degree_label.modulate = Color(1.0, 1.0, 1.0)

func _on_moisture_select_pressed() -> void:
	active_mode = Mode.MOISTURE
	_update_ui()

func _on_heat_select_pressed() -> void:
	active_mode = Mode.HEAT
	_update_ui()

func _on_increase_pressed() -> void:
	var profile = EnvironmentBridge.profile
	if not profile:
		return
		
	match active_mode:
		Mode.MOISTURE:
			profile.change_moisture(5.0)
		Mode.HEAT:
			profile.change_heat(1.0)
			
	_update_ui()

func _on_decrease_pressed() -> void:
	var profile = EnvironmentBridge.profile
	if not profile:
		return
		
	match active_mode:
		Mode.MOISTURE:
			profile.change_moisture(-5.0)
		Mode.HEAT:
			profile.change_heat(-1.0)
			
	_update_ui()
