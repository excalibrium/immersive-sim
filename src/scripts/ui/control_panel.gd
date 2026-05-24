extends WorldPanel

## Controller for the Incubator Chamber's Control Panel.
## Inherits 3D barycentric projection logic and adds environmental state interaction.

enum Mode {
	HEAT,
	MOISTURE
}

var active_mode: Mode = Mode.MOISTURE

var _blink_timer: Timer
var _blink_state: bool = false

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
	
	# Setup blink timer for non-optimal values warning blink
	_blink_timer = Timer.new()
	_blink_timer.wait_time = 0.4
	_blink_timer.autostart = true
	_blink_timer.timeout.connect(_on_blink_timeout)
	add_child(_blink_timer)
	
	# Connect to environmental signals
	var profile = EnvironmentBridge.profile
	if profile:
		profile.heat_changed.connect(_on_environment_changed)
		profile.moisture_changed.connect(_on_environment_changed)
	
	_update_ui()

func _exit_tree() -> void:
	var profile = EnvironmentBridge.profile
	if profile:
		if profile.heat_changed.is_connected(_on_environment_changed):
			profile.heat_changed.disconnect(_on_environment_changed)
		if profile.moisture_changed.is_connected(_on_environment_changed):
			profile.moisture_changed.disconnect(_on_environment_changed)

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
			
		Mode.HEAT:
			chosen_level_label.text = "%d°C" % round(profile.heat)
			too_high_label.visible = profile.is_heat_too_high()
			too_low_label.visible = profile.is_heat_too_low()
			
	# Blinking/Modulation warning logic for Moisture
	if not profile.is_moisture_optimal():
		moisture_percentage_label.modulate = Color(1.0, 0.25, 0.25) if _blink_state else Color(0.4, 0.1, 0.1)
	else:
		if active_mode == Mode.MOISTURE:
			moisture_percentage_label.modulate = Color(1.0, 1.0, 1.0)
		else:
			moisture_percentage_label.modulate = Color(0.5, 0.5, 0.5)

	# Blinking/Modulation warning logic for Heat
	if not profile.is_heat_optimal():
		heat_degree_label.modulate = Color(1.0, 0.25, 0.25) if _blink_state else Color(0.4, 0.1, 0.1)
	else:
		if active_mode == Mode.HEAT:
			heat_degree_label.modulate = Color(1.0, 1.0, 1.0)
		else:
			heat_degree_label.modulate = Color(0.5, 0.5, 0.5)

func _on_environment_changed(_new_value: float) -> void:
	_update_ui()

func _on_blink_timeout() -> void:
	_blink_state = not _blink_state
	var profile = EnvironmentBridge.profile
	if profile and (not profile.is_heat_optimal() or not profile.is_moisture_optimal()):
		_update_ui()

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
