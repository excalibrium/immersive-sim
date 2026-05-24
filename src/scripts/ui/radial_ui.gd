extends Control
class_name InteractionRadial

## Nested Radial UI Interaction Menu.
## Inner ring: 4 primary categories (TOP: Reinforce, BOTTOM: Punish, LEFT: Environment, RIGHT: System).
## Outer ring: fanned-out subactions centered on the parent button's heading.
## Upright labels are dynamically generated, and recent actions are logged in the center.

# SIGNALS
signal subaction_selected(category: String, subaction_id: String)
signal ignored

# ARCHITECTURE RULES:
# - Call Down, Signal Up: Emits event signals; doesn't call systems directly (Rule 6).
# - Decoupled Signals: A single generic signal prevents domain coupling (Rule 7).
# - Symmetric constraint: Only 2 or 4 buttons should be shown at the same time for visual balance.
# - Timer rule: Tweening is used for animations, avoiding process tick accumulation (Rule 44).

# EXPORTS
@export var radius: float = 120.0
@export var outer_radius: float = 220.0
@export var subaction_scale: float = 0.85

# Optional Custom StyleBoxes for subaction buttons (Rule 18 / Theme Guidelines)
@export var subaction_style_normal: StyleBox = null
@export var subaction_style_hover: StyleBox = null
@export var subaction_style_pressed: StyleBox = null

# Subaction contents mapping using uppercase translation keys
@export var subactions_config: Dictionary = {
	"TOP": ["COMFORT"],
	"BOTTOM": ["SHOCK"],
	"RIGHT": ["END_CYCLE", "CHECK_STATUS"]
}

# BUTTONS (typed correctly per Rule 12 type hints)
@onready var top_button: TextureButton = $TOP
@onready var left_button: TextureButton = $LEFT
@onready var right_button: TextureButton = $RIGHT
@onready var bottom_button: TextureButton = $BOTTOM

# STATE
var active_category: String = ""
var spawned_subactions: Array[Button] = []
var log_container: VBoxContainer = null
var is_menu_open: bool = false
var current_ruthlessness: float = 0.0
var current_action_log: Array = []
var current_is_sleeping: bool = false

func _ready() -> void:
	# Ensure Control is hidden initially
	visible = false
	modulate.a = 0.0
	set_process(false)
	
	# Connect primary buttons hover and press events
	top_button.mouse_entered.connect(func(): _on_primary_hovered("TOP"))
	bottom_button.mouse_entered.connect(func(): _on_primary_hovered("BOTTOM"))
	left_button.mouse_entered.connect(func(): _on_primary_hovered("LEFT"))
	right_button.mouse_entered.connect(func(): _on_primary_hovered("RIGHT"))
	
	# Primary button clicks (fallback or cancel behavior)
	top_button.pressed.connect(func(): _on_primary_clicked("TOP"))
	bottom_button.pressed.connect(func(): _on_primary_clicked("BOTTOM"))
	left_button.pressed.connect(func(): _on_primary_clicked("LEFT"))
	right_button.pressed.connect(func(): _on_primary_clicked("RIGHT"))
	
	# Position primary buttons dynamically based on radius
	arrange_radial_layout()

## Arranges primary buttons along their respective axes.
## Non-uniform sliced textures are shifted along their main axis rather than rotated to avoid distortion.
func arrange_radial_layout() -> void:
	# TOP
	top_button.pivot_offset = top_button.size / 2.0
	top_button.position = Vector2(0, -radius) - top_button.size / 2.0
	_ensure_button_label(top_button, "REINFORCE")
	
	# BOTTOM
	bottom_button.pivot_offset = bottom_button.size / 2.0
	bottom_button.position = Vector2(0, radius) - bottom_button.size / 2.0
	_ensure_button_label(bottom_button, "PUNISH")
	
	# LEFT
	left_button.pivot_offset = left_button.size / 2.0
	left_button.position = Vector2(-radius, 0) - left_button.size / 2.0
	_ensure_button_label(left_button, "ENVIRONMENT")
	
	# RIGHT
	right_button.pivot_offset = right_button.size / 2.0
	right_button.position = Vector2(radius, 0) - right_button.size / 2.0
	_ensure_button_label(right_button, "SYSTEM")

func _process(_delta: float) -> void:
	# Bypass mouse bounding check in headless test runs
	if DisplayServer.get_name() == "headless":
		return
		
	# Bounding check: If mouse drifts too far away, close the menu
	# Viewport-aware boundaries prevent screen border capture bugs on smaller resolutions.
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

## Opens the radial menu, loading recent action logs and resetting mouse states.
## Accepts specimen developmental phase (0: EGG, 1: CHILD, 2: ADULT) to restrict button visibility.
func open_menu(ruthlessness: float, action_log: Array, phase: int = 0, is_sleeping: bool = false) -> void:
	if is_menu_open:
		return
	is_menu_open = true
	set_process(true)
	
	current_ruthlessness = ruthlessness
	current_action_log = action_log
	current_is_sleeping = is_sleeping
	
	visible = true
	active_category = ""
	_despawn_subactions()
	
	# Dynamically include CERTIFY action if Cycle 18+ and phase is CHILD (1)
	var profile = SpecimenBridge.profile
	if profile and profile.current_cycle >= 18 and phase == 1:
		subactions_config["RIGHT"] = ["CERTIFY", "CHECK_STATUS"]
	else:
		subactions_config["RIGHT"] = ["END_CYCLE", "CHECK_STATUS"]
		
	_refresh_labels()
	_refresh_log()
	
	# Determine button visibility based on sleep state and phase
	if current_is_sleeping:
		# Sleep state shows only PET (TOP) and SHOCK (BOTTOM)
		top_button.visible = true
		bottom_button.visible = true
		left_button.visible = false
		right_button.visible = false
	elif phase == 0: # EGG
		top_button.visible = false
		bottom_button.visible = false
		left_button.visible = false
		right_button.visible = true
	else: # CHILD, ADULT
		top_button.visible = true
		bottom_button.visible = true
		left_button.visible = false
		right_button.visible = true
	
	# Unlock mouse cursor via stack-based WindowManager
	WindowManager.push_mouse_state(WindowManager.MouseState.VISIBLE)
	
	# Animate menu fade and scale-in from center
	var active_buttons: Array[TextureButton] = []
	if top_button.visible:
		active_buttons.append(top_button)
	if bottom_button.visible:
		active_buttons.append(bottom_button)
	if left_button.visible:
		active_buttons.append(left_button)
	if right_button.visible:
		active_buttons.append(right_button)
		
	for btn in active_buttons:
		btn.scale = Vector2.ZERO
		btn.modulate.a = 0.0
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	for btn in active_buttons:
		tween.tween_property(btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, 0.3)

## Closes the menu, animating buttons back to the center and popping the mouse state.
func close_menu() -> void:
	if not is_menu_open:
		return
	is_menu_open = false
	set_process(false)
	
	_despawn_subactions()
	
	# Animate collapse
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
	
	# Lock mouse cursor back
	WindowManager.pop_mouse_state()

## Dynamically updates the action log and energy display in real-time.
func update_realtime_data(action_log: Array) -> void:
	current_action_log = action_log
	_refresh_log()

## Transitions the open menu layout to the sleep state dynamically.
func transition_to_sleep_layout() -> void:
	if not is_menu_open:
		return
	current_is_sleeping = true
	
	if SpecimenBridge.profile:
		current_action_log = SpecimenBridge.profile.action_log
	
	# Update buttons visibility (sleep state shows only TOP and BOTTOM)
	top_button.visible = true
	bottom_button.visible = true
	left_button.visible = false
	right_button.visible = false
	
	_refresh_labels()
	_despawn_subactions()
	_refresh_log()

func _refresh_labels() -> void:
	if current_is_sleeping:
		_set_btn_label(top_button, tr("PET"))
		_set_btn_label(bottom_button, tr("SHOCK"))
		_set_btn_label(left_button, "")
		_set_btn_label(right_button, "")
		return

	var r = current_ruthlessness
		
	var tier = 0
	if r >= 67.0:
		tier = 2
	elif r >= 34.0:
		tier = 1
		
	var reinforce_labels = ["REINFORCE", "REWARD", "GRANT RELIEF"]
	var punish_labels = ["PUNISH", "CORRECT", "IMPOSE CONSEQUENCE"]
	
	_set_btn_label(top_button, tr(reinforce_labels[tier]))
	_set_btn_label(bottom_button, tr(punish_labels[tier]))
	_set_btn_label(left_button, tr("ENVIRONMENT"))
	_set_btn_label(right_button, tr("SYSTEM"))

func _ensure_log_container() -> void:
	if not log_container:
		log_container = VBoxContainer.new()
		log_container.name = "LogContainer"
		add_child(log_container)
		
		# Center it relative to parent
		log_container.anchors_preset = PRESET_CENTER
		log_container.grow_horizontal = GROW_DIRECTION_BOTH
		log_container.grow_vertical = GROW_DIRECTION_BOTH
		
		# Title label
		var header = Label.new()
		header.text = "RECENT ACTIONS"
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 9)
		header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))
		header.add_theme_color_override("font_outline_color", Color.BLACK)
		header.add_theme_constant_override("outline_size", 2)
		log_container.add_child(header)

func _refresh_log() -> void:
	_ensure_log_container()
	
	# Clear previous log labels (keep header)
	for child in log_container.get_children():
		if child != log_container.get_child(0):
			log_container.remove_child(child)
			child.queue_free()
			
	var action_log = current_action_log
		
	for i in range(action_log.size()):
		var action_id = action_log[i]
		var label = Label.new()
		
		# Check if a translation exists. If translation matches the key, fallback to formatting.
		var translated_text = tr(action_id)
		if translated_text == action_id:
			var words = action_id.split("_")
			for w in range(words.size()):
				words[w] = words[w].capitalize()
			translated_text = " ".join(words)
			
		label.text = translated_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Premium styling (warm glow highlight on most recent)
		var font_size = 13
		var color = Color.WHITE
		if i == 0:
			font_size = 13
			color = Color(1.0, 0.85, 0.4, 1.0)
		elif i == 1:
			font_size = 11
			color = Color(0.8, 0.8, 0.8, 0.8)
		else:
			font_size = 9
			color = Color(0.5, 0.5, 0.5, 0.5)
			
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		log_container.add_child(label)
		
	# Energy readout display (Milestone 8)
	var profile = SpecimenBridge.profile
	if profile:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		log_container.add_child(spacer)
		
		var max_e = 5 + profile.current_cycle * 2
		var energy_label = Label.new()
		energy_label.text = "ENERGY: " + str(profile.energy) + " / " + str(max_e)
		energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		energy_label.add_theme_font_size_override("font_size", 10)
		energy_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if profile.energy > 0.0 else Color(0.9, 0.3, 0.3))
		energy_label.add_theme_color_override("font_outline_color", Color.BLACK)
		energy_label.add_theme_constant_override("outline_size", 3)
		log_container.add_child(energy_label)

func _on_primary_hovered(category: String) -> void:
	if current_is_sleeping:
		return
		
	if active_category == category:
		return
	
	active_category = category
	_despawn_subactions()
	_spawn_subactions(category)

func _on_primary_clicked(category: String) -> void:
	if current_is_sleeping:
		# Direct action selection when sleeping (Milestone 8)
		var value = "PET" if category == "TOP" else "SHOCK"
		subaction_selected.emit(category, value)
		close_menu()
		return
		
	# Primary click triggers subaction spawn/toggle if not hovered
	if active_category != category:
		_on_primary_hovered(category)

func _spawn_subactions(category: String) -> void:
	if not subactions_config.has(category):
		return
		
	var list = subactions_config[category]
	var count = list.size()
	if count == 0:
		return
		
	# Find parent button properties for fanned layout
	var parent_btn: TextureButton = get_node(NodePath(category))
	var parent_pos = parent_btn.position + parent_btn.size / 2.0
	
	# Direction angles
	var base_angles = {
		"TOP": -PI / 2.0,       # UP
		"BOTTOM": PI / 2.0,     # DOWN
		"LEFT": PI,             # LEFT
		"RIGHT": 0.0            # RIGHT
	}
	var base_angle = base_angles[category]
	
	for i in range(count):
		var text = list[i]
		
		# Fan angle math:
		# 1 subaction: 0 offset.
		# 2 subactions: ±45° offset.
		# 3 subactions: -45°, 0°, +45° offset.
		var angle_offset = 0.0
		if count == 2:
			angle_offset = -PI / 4.0 if i == 0 else PI / 4.0
		elif count == 3:
			angle_offset = lerp(-PI / 4.0, PI / 4.0, float(i) / 2.0)
		elif count > 3:
			angle_offset = lerp(-PI / 4.0, PI / 4.0, float(i) / float(count - 1))
			
		var final_angle = base_angle + angle_offset
		
		# Create button node
		var btn = Button.new()
		btn.text = "" # Text goes in a child label to keep it upright
		btn.size = Vector2(84, 84)
		btn.custom_minimum_size = Vector2(84, 84)
		btn.pivot_offset = btn.size / 2.0
		
		# Style subactions (Fallback to glassmorphic dark styling if no exports assigned)
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
			style_hover.border_color = Color(0.9, 0.65, 0.2, 0.9) # Amber glow
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
		
		# Set positioning and rotation
		btn.rotation = final_angle + PI / 2.0
		var target_dir = Vector2.from_angle(final_angle)
		var target_pos = target_dir * outer_radius - btn.size / 2.0
		
		# Spawn animation: start at parent button pos with scale/alpha at 0
		btn.position = parent_pos - btn.size / 2.0
		btn.scale = Vector2.ZERO
		btn.modulate.a = 0.0
		
		# Upright label child (negates parent rotation)
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
		
		# Hook click signal
		btn.pressed.connect(_on_subaction_clicked.bind(category, text))
		
		add_child(btn)
		spawned_subactions.append(btn)
		
		# Perspective scale progression: outer buttons get slightly larger based on index
		var perspective_scale = subaction_scale * (1.0 + (float(i) * 0.05))
		
		# Tween spawn animation
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "position", target_pos, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "scale", Vector2(perspective_scale, perspective_scale), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, 0.25)

func _despawn_subactions() -> void:
	# Clear active category fanned buttons
	for btn in spawned_subactions:
		if is_instance_valid(btn):
			btn.queue_free()
	spawned_subactions.clear()

func _on_subaction_clicked(category: String, subaction_name: String) -> void:
	# Preserve UPPERCASE format matching configuration config values exactly
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

func _ensure_button_label(btn: TextureButton, default_text: String) -> Label:
	var label = btn.get_node_or_null("Label")
	if not label:
		label = Label.new()
		label.name = "Label"
		btn.add_child(label)
		
		# Setup centering bounds covering the full button area
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
		
		# Style
		label.text = default_text
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_font_size_override("font_size", 12)
	return label

func _set_btn_label(btn: TextureButton, text: String) -> void:
	var label = _ensure_button_label(btn, text)
	label.text = text
