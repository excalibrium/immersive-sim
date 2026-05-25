extends Control
class_name InteractionRadial

## Generic, Data-Driven Radial UI Interaction Menu.
## Accepts external layout configs mapping button directions to custom actions and labels.
## Static UI components (Labels, LogContainer, ActionLabels, EnergyLabel) are pre-defined in the scene.

# SIGNALS
signal subaction_selected(category: String, subaction_id: String)
signal ignored

# EXPORTS
@export var radius: float = 120.0
@export var outer_radius: float = 220.0
@export var subaction_scale: float = 0.85

# Optional Custom StyleBoxes for subaction buttons
@export var subaction_style_normal: StyleBox = null
@export var subaction_style_hover: StyleBox = null
@export var subaction_style_pressed: StyleBox = null

# BUTTONS (statically defined in scene)
@onready var top_button: TextureButton = $TOP
@onready var left_button: TextureButton = $LEFT
@onready var right_button: TextureButton = $RIGHT
@onready var bottom_button: TextureButton = $BOTTOM

# LABELS (statically defined in scene)
@onready var top_label: Label = $TOP/Label
@onready var left_label: Label = $LEFT/Label
@onready var right_label: Label = $RIGHT/Label
@onready var bottom_label: Label = $BOTTOM/Label

# CENTER LOG (statically defined in scene)
@onready var log_container: VBoxContainer = $LogContainer
@onready var action_labels: Array[Label] = [
	$LogContainer/ActionLabel1,
	$LogContainer/ActionLabel2,
	$LogContainer/ActionLabel3
]
@onready var energy_label: Label = $LogContainer/EnergyLabel
@onready var current_action_label: Label = $LogContainer/CurrentActionLabel

# STATE
var active_category: String = ""
var spawned_subactions: Array[Button] = []
var is_menu_open: bool = false

# Data-driven config and state
var custom_config: Dictionary = {}
var current_action_log: Array = []
var current_energy: float = 0.0
var current_max_energy: float = 0.0
var current_action_name: String = ""
var custom_center: Dictionary = {}
var subactions_config: Dictionary = {} # Temporary configuration built from custom_config

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	set_process(false)
	
	# Connect primary buttons hover and press events
	top_button.mouse_entered.connect(func(): _on_primary_hovered("TOP"))
	bottom_button.mouse_entered.connect(func(): _on_primary_hovered("BOTTOM"))
	left_button.mouse_entered.connect(func(): _on_primary_hovered("LEFT"))
	right_button.mouse_entered.connect(func(): _on_primary_hovered("RIGHT"))
	
	# Primary button clicks
	top_button.pressed.connect(func(): _on_primary_clicked("TOP"))
	bottom_button.pressed.connect(func(): _on_primary_clicked("BOTTOM"))
	left_button.pressed.connect(func(): _on_primary_clicked("LEFT"))
	right_button.pressed.connect(func(): _on_primary_clicked("RIGHT"))
	
	# Position primary buttons dynamically based on radius
	arrange_radial_layout()

func arrange_radial_layout() -> void:
	top_button.pivot_offset = top_button.size / 2.0
	top_button.position = Vector2(0, -radius) - top_button.size / 2.0
	
	bottom_button.pivot_offset = bottom_button.size / 2.0
	bottom_button.position = Vector2(0, radius) - bottom_button.size / 2.0
	
	left_button.pivot_offset = left_button.size / 2.0
	left_button.position = Vector2(-radius, 0) - left_button.size / 2.0
	
	right_button.pivot_offset = right_button.size / 2.0
	right_button.position = Vector2(radius, 0) - right_button.size / 2.0

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
		
	var mouse_pos = get_local_mouse_position()
	var dist = mouse_pos.length()
	
	var max_safe_dist = outer_radius + 150.0
	var viewport = get_viewport()
	if viewport:
		var viewport_height = viewport.get_visible_rect().size.y
		if viewport_height > 100.0:
			max_safe_dist = min(max_safe_dist, viewport_height / 2.0 - 20.0)
	
	if dist > max_safe_dist:
		ignored.emit()
		close_menu()

## Opens the radial menu using a custom configuration dict
func open_menu(action_log: Array, energy: float, max_energy: float, config: Dictionary, current_action: String = "", center_override: Dictionary = {}) -> void:
	if is_menu_open:
		return
	is_menu_open = true
	set_process(true)
	
	current_action_log = action_log
	current_energy = energy
	current_max_energy = max_energy
	custom_config = config
	current_action_name = current_action
	custom_center = center_override
	
	visible = true
	active_category = ""
	_despawn_subactions()
	
	# Build subactions_config from custom_config
	subactions_config.clear()
	for cat in custom_config:
		var cfg = custom_config[cat]
		if cfg.has("subactions"):
			subactions_config[cat] = cfg["subactions"]
	
	# Configure buttons visibility and labels
	top_button.visible = custom_config.has("TOP")
	bottom_button.visible = custom_config.has("BOTTOM")
	left_button.visible = custom_config.has("LEFT")
	right_button.visible = custom_config.has("RIGHT")
	
	if top_button.visible:
		top_label.text = tr(custom_config["TOP"].get("label", ""))
	if bottom_button.visible:
		bottom_label.text = tr(custom_config["BOTTOM"].get("label", ""))
	if left_button.visible:
		left_label.text = tr(custom_config["LEFT"].get("label", ""))
	if right_button.visible:
		right_label.text = tr(custom_config["RIGHT"].get("label", ""))
		
	_refresh_log()
	
	# Unlock mouse cursor via WindowManager
	WindowManager.push_mouse_state(WindowManager.MouseState.VISIBLE)
	
	# Animate menu fade and scale-in from center
	var active_buttons: Array[TextureButton] = []
	if top_button.visible: active_buttons.append(top_button)
	if bottom_button.visible: active_buttons.append(bottom_button)
	if left_button.visible: active_buttons.append(left_button)
	if right_button.visible: active_buttons.append(right_button)
		
	for btn in active_buttons:
		btn.scale = Vector2.ZERO
		btn.modulate.a = 0.0
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	for btn in active_buttons:
		tween.tween_property(btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, 0.3)

## Closes the menu, animating buttons back to the center
func close_menu() -> void:
	if not is_menu_open:
		return
	is_menu_open = false
	set_process(false)
	
	_despawn_subactions()
	custom_config.clear()
	subactions_config.clear()
	custom_center.clear()
	
	var active_buttons: Array[TextureButton] = []
	if top_button.visible: active_buttons.append(top_button)
	if bottom_button.visible: active_buttons.append(bottom_button)
	if left_button.visible: active_buttons.append(left_button)
	if right_button.visible: active_buttons.append(right_button)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	for btn in active_buttons:
		tween.tween_property(btn, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	await tween.finished
	visible = false
	WindowManager.pop_mouse_state()

## Dynamically updates the action log and energy display in real-time.
func update_realtime_data(action_log: Array, energy: float, max_energy: float, new_config: Dictionary = {}, current_action: Variant = null, center_override: Variant = null) -> void:
	current_action_log = action_log
	current_energy = energy
	current_max_energy = max_energy
	if current_action != null:
		current_action_name = current_action
	if center_override != null:
		custom_center = center_override
	
	if not new_config.is_empty():
		custom_config = new_config
		
		# Build subactions_config from custom_config
		subactions_config.clear()
		for cat in custom_config:
			var cfg = custom_config[cat]
			if cfg.has("subactions"):
				subactions_config[cat] = cfg["subactions"]
				
		top_button.visible = custom_config.has("TOP")
		bottom_button.visible = custom_config.has("BOTTOM")
		left_button.visible = custom_config.has("LEFT")
		right_button.visible = custom_config.has("RIGHT")
		
		if top_button.visible:
			top_label.text = tr(custom_config["TOP"].get("label", ""))
		if bottom_button.visible:
			bottom_label.text = tr(custom_config["BOTTOM"].get("label", ""))
		if left_button.visible:
			left_label.text = tr(custom_config["LEFT"].get("label", ""))
		if right_button.visible:
			right_label.text = tr(custom_config["RIGHT"].get("label", ""))
			
	_refresh_log()

func _refresh_log() -> void:
	if not custom_center.is_empty():
		# Header
		if custom_center.has("header"):
			$LogContainer/Header.text = tr(custom_center["header"])
			$LogContainer/Header.visible = !custom_center["header"].is_empty()
		else:
			$LogContainer/Header.text = tr("RECENT ACTIONS")
			$LogContainer/Header.visible = true
			
		# Current Action
		if current_action_label:
			if custom_center.has("current_action"):
				current_action_label.text = tr(custom_center["current_action"])
				current_action_label.visible = !custom_center["current_action"].is_empty()
			else:
				current_action_label.visible = false
				
		# Lines (Action log)
		var lines = custom_center.get("lines", [])
		for i in range(3):
			var lbl = action_labels[i]
			if i < lines.size():
				lbl.text = tr(lines[i])
				lbl.visible = true
				if "warning" in lines[i].to_lower() or "active" in lines[i].to_lower() or "awake" in lines[i].to_lower() or "locked" in lines[i].to_lower():
					lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Red warning
				elif "sleeping" in lines[i].to_lower() or "ready" in lines[i].to_lower():
					lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3)) # Green OK
				else:
					lbl.add_theme_color_override("font_color", Color.WHITE)
			else:
				lbl.visible = false
				
		# Energy display
		if custom_center.has("energy") and not custom_center["energy"].is_empty():
			energy_label.text = tr(custom_center["energy"])
			energy_label.visible = true
			if "warning" in custom_center["energy"].to_lower() or "error" in custom_center["energy"].to_lower():
				energy_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				energy_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			energy_label.visible = false
	else:
		# Fallback to standard Specimen log rendering
		$LogContainer/Header.text = tr("RECENT ACTIONS")
		$LogContainer/Header.visible = true
		
		# Update current action display
		if current_action_label:
			var display_action = current_action_name.replace("_", " ").capitalize()
			if display_action.is_empty():
				display_action = "None"
			current_action_label.text = "CURRENT ACTION: " + display_action
			current_action_label.visible = true
			
		# Populate action log labels
		for i in range(3):
			var lbl = action_labels[i]
			if i < current_action_log.size():
				var action_id = current_action_log[i]
				var translated_text = tr(action_id)
				if translated_text == action_id:
					var words = action_id.split("_")
					for w in range(words.size()):
						words[w] = words[w].capitalize()
					translated_text = " ".join(words)
					
				lbl.text = translated_text
				lbl.visible = true
				
				var font_color = Color.WHITE
				if i == 0:
					font_color = Color(1.0, 0.85, 0.4, 1.0)
				elif i == 1:
					font_color = Color(0.8, 0.8, 0.8, 0.8)
				else:
					font_color = Color(0.5, 0.5, 0.5, 0.5)
				lbl.add_theme_color_override("font_color", font_color)
			else:
				lbl.visible = false
				
		# Update energy display
		if current_max_energy > 0.0:
			energy_label.text = "ENERGY: " + str(current_energy) + " / " + str(current_max_energy)
			energy_label.visible = true
			energy_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if current_energy > 0.0 else Color(0.9, 0.3, 0.3))
		else:
			energy_label.visible = false

func _on_primary_hovered(category: String) -> void:
	if not custom_config.has(category):
		return
		
	var cfg = custom_config[category]
	var subactions = cfg.get("subactions", [])
	if subactions.is_empty():
		# Direct action button, clear any subactions fanned from previous hovers
		active_category = category
		_despawn_subactions()
		return
		
	if active_category == category:
		return
		
	active_category = category
	_despawn_subactions()
	_spawn_subactions(category)

func _on_primary_clicked(category: String) -> void:
	if not custom_config.has(category):
		return
		
	var cfg = custom_config[category]
	var subactions = cfg.get("subactions", [])
	if subactions.is_empty():
		# Direct action selection
		var action = cfg.get("action", "")
		subaction_selected.emit(category, action)
		close_menu()
		return
		
	# Spawn subactions if not hovered
	if active_category != category:
		_on_primary_hovered(category)

func _spawn_subactions(category: String) -> void:
	if not subactions_config.has(category):
		return
		
	var list = subactions_config[category]
	var count = list.size()
	if count == 0:
		return
		
	var parent_btn: TextureButton = get_node(NodePath(category))
	var parent_pos = parent_btn.position + parent_btn.size / 2.0
	
	var base_angles = {
		"TOP": -PI / 2.0,
		"BOTTOM": PI / 2.0,
		"LEFT": PI,
		"RIGHT": 0.0
	}
	var base_angle = base_angles[category]
	
	for i in range(count):
		var text = list[i]
		var angle_offset = 0.0
		if count == 2:
			angle_offset = -PI / 4.0 if i == 0 else PI / 4.0
		elif count == 3:
			angle_offset = lerp(-PI / 4.0, PI / 4.0, float(i) / 2.0)
		elif count > 3:
			angle_offset = lerp(-PI / 4.0, PI / 4.0, float(i) / float(count - 1))
			
		var final_angle = base_angle + angle_offset
		
		var btn = Button.new()
		btn.text = ""
		btn.size = Vector2(84, 84)
		btn.custom_minimum_size = Vector2(84, 84)
		btn.pivot_offset = btn.size / 2.0
		
		var style_normal = subaction_style_normal
		var style_hover = subaction_style_hover
		var style_pressed = subaction_style_pressed
		
		if not style_normal:
			style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(0.08, 0.08, 0.1, 0.8)
			style_normal.border_color = Color(0.3, 0.3, 0.35, 0.5)
			style_normal.border_width_left = 2
			style_normal.border_width_top = 2
			style_normal.border_width_right = 2
			style_normal.border_width_bottom = 2
			style_normal.set_corner_radius_all(100)
			
		if not style_hover:
			style_hover = StyleBoxFlat.new()
			style_hover.bg_color = Color(0.12, 0.12, 0.15, 0.95)
			style_hover.border_color = Color(0.9, 0.65, 0.2, 0.9)
			style_hover.border_width_left = 3
			style_hover.border_width_top = 3
			style_hover.border_width_right = 3
			style_hover.border_width_bottom = 3
			style_hover.set_corner_radius_all(100)
			
		if not style_pressed:
			style_pressed = style_hover.duplicate()
			style_pressed.bg_color = Color(0.2, 0.15, 0.05, 0.95)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		btn.rotation = final_angle + PI / 2.0
		var target_dir = Vector2.from_angle(final_angle)
		var target_pos = target_dir * outer_radius - btn.size / 2.0
		
		btn.position = parent_pos - btn.size / 2.0
		btn.scale = Vector2.ZERO
		btn.modulate.a = 0.0
		
		var label = Label.new()
		label.name = "Label"
		label.text = tr(text)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchor_left = 0.0
		label.anchor_top = 0.0
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.offset_left = 0.0
		label.offset_top = 0.0
		label.offset_right = 0.0
		label.offset_bottom = 0.0
		label.pivot_offset = btn.size / 2.0
		label.rotation = -btn.rotation
		
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 11)
		btn.add_child(label)
		
		btn.pressed.connect(_on_subaction_clicked.bind(category, text))
		
		add_child(btn)
		spawned_subactions.append(btn)
		
		var perspective_scale = subaction_scale * (1.0 + (float(i) * 0.05))
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "position", target_pos, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(perspective_scale, perspective_scale), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, 0.25)

func _despawn_subactions() -> void:
	for btn in spawned_subactions:
		if is_instance_valid(btn):
			btn.queue_free()
	spawned_subactions.clear()

func _on_subaction_clicked(category: String, subaction_name: String) -> void:
	var value = subaction_name.to_upper().replace(" ", "_")
	subaction_selected.emit(category, value)
	close_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not is_menu_open:
		return
		
	if event.is_action_pressed("back"):
		ignored.emit()
		close_menu()
		get_viewport().set_input_as_handled()
