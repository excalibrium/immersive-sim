extends WorldPanel

signal end_cycle_requested
signal shop_opened
signal object_purchased(item_key: String, scene_path: String, spawn_pos: Vector3, spawn_rot: Vector3)

# --- UI Node References ---
@onready var end_cycle_label: Label = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer/NinePatchRect/END_CYCLE_LABEL
@onready var end_cycle_btn: Button = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer/NinePatchRect/Button
@onready var reports_label: Label = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer2/NinePatchRect/REPORTS_LABEL
@onready var reports_btn: Button = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer2/NinePatchRect/Button

# Shop elements
@onready var main_menu_panel: NinePatchRect = $SubViewport/MarginContainer/NinePatchRect
@onready var shop_btn: Button = $SubViewport/MarginContainer/NinePatchRect/GridContainer/VBoxContainer4/NinePatchRect/Button
@onready var shop_window: MarginContainer = $SubViewport/MarginContainer/ShopWindow
@onready var shop_container: MarginContainer = $SubViewport/MarginContainer/ShopWindow/MarginContainerin

const SHOP_ITEMS = {
	"food_bowl": {
		"name": "Food Bowl",
		"cost": 2,
		"description": "A simple bowl to hold specimen nutrients.",
		"scene_path": "res://src/scenes/level/objects/food_bowl.tscn",
		"spawn_position": Vector3(22.0, -1.72, -5.0),
		"spawn_rotation": Vector3(0.0, 0.0, 0.0)
	},
	"bed": {
		"name": "Bed",
		"cost": 5,
		"description": "A cozy resting module for the specimen.",
		"scene_path": "res://src/scenes/level/objects/bed.tscn",
		"spawn_position": Vector3(20.0, -1.72, -15.0),
		"spawn_rotation": Vector3(0.0, 0.0, 0.0)
	},
	"play_ground": {
		"name": "Play Ground",
		"cost": 8,
		"description": "A recreational module to stimulate play behavior.",
		"scene_path": "res://src/scenes/level/objects/play_ground.tscn",
		"spawn_position": Vector3(19.0, -1.765, -4.3),
		"spawn_rotation": Vector3(0.0, 0.0, 0.0)
	},
	"sleeping_dome": {
		"name": "Sleeping Dome",
		"cost": 10,
		"description": "An enclosed shelter for secure sleep cycles.",
		"scene_path": "res://src/scenes/level/objects/sleeping_dome.tscn",
		"spawn_position": Vector3(30.0, -1.72, -15.0),
		"spawn_rotation": Vector3(0.0, 0.0, 0.0)
	},
	"automatic_feeder": {
		"name": "Automatic Feeder",
		"cost": 12,
		"description": "Automated nutritional dispensing unit.",
		"scene_path": "res://src/scenes/level/objects/automatic_feeder.tscn",
		"spawn_position": Vector3(22.0, -1.72, -8.0),
		"spawn_rotation": Vector3(0.0, 0.0, 0.0)
	},
	"vacuum_cleaner_robot": {
		"name": "Vacuum Cleaner Robot",
		"cost": 15,
		"description": "A roaming robot to keep the cell clean.",
		"scene_path": "res://src/scenes/level/objects/vacuum_cleaner_robot.tscn",
		"spawn_position": Vector3(32.0, -1.72, -5.0),
		"spawn_rotation": Vector3(0.0, 0.0, 0.0)
	}
}

var _spawned_items: Array = []

func _ready() -> void:
	super._ready()
	if end_cycle_btn:
		end_cycle_btn.pressed.connect(_on_end_cycle_btn_pressed)
	
	if shop_window:
		shop_window.visible = false
		
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_btn_pressed)
		
	if Game.session:
		Game.session.credits_changed.connect(func(_new_credits):
			if shop_window and shop_window.visible:
				_build_shop_ui()
		)
		
	_update_ui()

func _update_ui() -> void:
	pass

func _on_end_cycle_btn_pressed() -> void:
	end_cycle_requested.emit()

func _on_shop_btn_pressed() -> void:
	shop_opened.emit()

func update_spawned_items(spawned_keys: Array) -> void:
	_spawned_items = spawned_keys
	if main_menu_panel:
		main_menu_panel.visible = false
	if shop_window:
		shop_window.visible = true
		_build_shop_ui()

func _build_shop_ui() -> void:
	if not shop_container:
		return
		
	# Clear previous children
	for child in shop_container.get_children():
		child.queue_free()
		
	var main_layout = VBoxContainer.new()
	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_container.add_child(main_layout)
	
	# Header Layout
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.add_child(header)
	
	var title = Label.new()
	title.text = "CHAMBER EQUIPMENT SHOP"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.65, 0.2)) # Amber color
	header.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var credits_label = Label.new()
	var current_credits = Game.session.credits if Game.session else 10
	credits_label.text = "CREDS: " + str(current_credits)
	credits_label.add_theme_font_size_override("font_size", 22)
	credits_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4)) # Green color
	header.add_child(credits_label)
	
	var sep1 = HSeparator.new()
	main_layout.add_child(sep1)
	
	# Scroll area for items
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	main_layout.add_child(scroll)
	
	var item_grid = GridContainer.new()
	item_grid.columns = 2
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid.add_theme_constant_override("h_separation", 32)
	item_grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(item_grid)
	
	# Populate items
	for item_key in SHOP_ITEMS.keys():
		var item = SHOP_ITEMS[item_key]
		var item_panel = PanelContainer.new()
		item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_grid.add_child(item_panel)
		
		var item_layout = VBoxContainer.new()
		item_layout.add_theme_constant_override("separation", 6)
		
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 16)
		margin_container.add_theme_constant_override("margin_top", 12)
		margin_container.add_theme_constant_override("margin_right", 16)
		margin_container.add_theme_constant_override("margin_bottom", 12)
		item_panel.add_child(margin_container)
		margin_container.add_child(item_layout)
		
		var name_lbl = Label.new()
		name_lbl.text = item.name
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_layout.add_child(name_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_layout.add_child(desc_lbl)
		
		var cost_lbl = Label.new()
		cost_lbl.text = str(item.cost) + " CREDS"
		cost_lbl.add_theme_font_size_override("font_size", 15)
		cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.65, 0.2))
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_layout.add_child(cost_lbl)
		
		var buy_btn = Button.new()
		buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		buy_btn.custom_minimum_size = Vector2(140, 35)
		
		# Check if already spawned
		if item_key in _spawned_items:
			buy_btn.text = "BOUGHT"
			buy_btn.disabled = true
		else:
			buy_btn.text = "PURCHASE"
			if current_credits < item.cost:
				buy_btn.disabled = true
				buy_btn.text = "LOCKED"
			else:
				buy_btn.pressed.connect(func():
					_on_purchase_clicked(item_key, item)
				)
		item_layout.add_child(buy_btn)
		
	var sep2 = HSeparator.new()
	main_layout.add_child(sep2)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "BACK TO MAIN SYSTEM"
	close_btn.custom_minimum_size = Vector2(250, 45)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func():
		shop_window.visible = false
		if main_menu_panel:
			main_menu_panel.visible = true
	)
	main_layout.add_child(close_btn)

func _on_purchase_clicked(item_key: String, item: Dictionary) -> void:
	if not Game.session:
		return
	if Game.session.credits >= item.cost:
		Game.session.credits -= item.cost
		object_purchased.emit(item_key, item.scene_path, item.spawn_position, item.spawn_rotation)
