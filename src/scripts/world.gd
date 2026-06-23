extends Node3D

## Level Controller for the main World.
## Initializes the GameSession and acts as the 'Objective Giver'.

const RS = preload("res://src/scripts/conditioning/reinforcement_system.gd")

@onready var crosshair = $UI/Crosshair
@onready var player = $Player
@onready var specimen: Specimen = $Specimen
@onready var monitor_panel = $MonitorPanel
@onready var lights: LightSystem = $Lights
@onready var audio = $Audio

## Sibling exports with lookups as fallback
@export var player_interactor: PlayerInteractor
@export var radial_ui: InteractionRadial
@export var specimen_interactable: Interactable

@export_group("Tutorial Settings")
@export var start_in_tutorial: bool = true
@export var tutorial_start_pos: Vector3 = Vector3(-32.0, 1.0, -10.2)

var reinforcement_system: ReinforcementSystem = null
var cycle_manager: CycleManager = null
var ap_label: Control = null
var _is_interacting_with_bed: bool = false
var _current_action_conditioned: bool = false
var _tutorial_panel: PanelContainer = null
var _tutorial_label: Label = null
var _deck_enter_area: Area3D = null

func _enter_tree():
	# 0. Initialize Game Session early so children can access it in _ready
	# Use .duplicate(true) to ensure each playthrough has its own mutable state
	Game.session = GameSession.new().duplicate(true)
	EnvironmentBridge.start_run()
	SpecimenBridge.start_run()

func _exit_tree():
	EnvironmentBridge.end_run()
	SpecimenBridge.end_run()

func _ready():
	if not player_interactor:
		player_interactor = player.find_child("PlayerInteractor") as PlayerInteractor
	if player_interactor:
		crosshair.setup(player_interactor)
		
	var held_item_ui = $UI.get_node_or_null("HeldItemUI")
	if held_item_ui and player:
		held_item_ui.setup(player)
		
	# Instantiate systems dynamically for prototype testing
	reinforcement_system = RS.new()
	add_child(reinforcement_system)

	# Load and instantiate AP HUD Label from scene
	var ap_label_scene = load("res://src/scenes/ui/APLabel.tscn")
	ap_label = ap_label_scene.instantiate()
	$UI.add_child(ap_label)

	# Instantiate CycleManager
	# Instantiate CycleManager script dynamically
	var cycle_manager_script = load("res://src/scripts/systems/cycle_manager.gd")
	cycle_manager = cycle_manager_script.new()
	cycle_manager.name = "CycleManager"
	
	# Inject dynamic system dependencies downward (Call Down, Signal Up)
	cycle_manager.external_specimen = specimen
	cycle_manager.external_lights = lights
	
	# Connect ap_changed before adding child to receive initial value
	cycle_manager.ap_changed.connect(func(new_ap: int):
		if ap_label:
			ap_label.update_ap(new_ap)
	)
	
	add_child(cycle_manager)

	# Connect MonitorPanel cycle end and shop signals
	if monitor_panel:
		monitor_panel.end_cycle_requested.connect(_on_monitor_panel_end_cycle_requested)
		if monitor_panel.has_signal("shop_opened"):
			monitor_panel.shop_opened.connect(_on_monitor_panel_shop_opened)
		if monitor_panel.has_signal("object_purchased"):
			monitor_panel.object_purchased.connect(_on_monitor_panel_object_purchased)

	# Connect Radial UI events if present in the tree
	if not radial_ui:
		radial_ui = find_child("RadialUI") as InteractionRadial
	if radial_ui:
		radial_ui.subaction_selected.connect(func(category, subaction_id):
			_is_interacting_with_bed = false
			_on_subaction_selected(category, subaction_id)
		)
		radial_ui.ignored.connect(func():
			_is_interacting_with_bed = false
		)
		
	# Connect to global InteractionBus autoload
	var bus = get_node_or_null("/root/InteractionBus")
	if bus:
		bus.connect("bed_sleep_requested", _on_bed_sleep_requested)
		
	# Connect Specimen interaction to open the Radial UI
	if not specimen_interactable and specimen:
		specimen_interactable = specimen.find_child("Interactable") as Interactable
		
	if specimen_interactable and radial_ui:
		specimen_interactable.interacted.connect(func(_interactor):
			var log_data = []
			var energy = 0.0
			var max_energy = 0.0
			if SpecimenBridge.profile:
				log_data = SpecimenBridge.profile.action_log
				energy = SpecimenBridge.profile.energy
				max_energy = SpecimenBridge.profile.get_max_energy()
			
			var config = _get_specimen_radial_config()
			radial_ui.open_menu(log_data, energy, max_energy, config, specimen._current_action if specimen else "")
		)

	# Connect Specimen actions to update Radial UI real-time logs
	if specimen and radial_ui:
		specimen.action_performed.connect(func(_action_id: String):
			_current_action_conditioned = false
			if radial_ui.is_menu_open and SpecimenBridge.profile:
				if _is_interacting_with_bed:
					_update_bed_radial_ui()
				else:
					var profile = SpecimenBridge.profile
					var config = _get_specimen_radial_config()
					radial_ui.update_realtime_data(profile.action_log, profile.energy, profile.get_max_energy(), config, specimen._current_action)
		)
		specimen.sleep_entered.connect(func():
			if radial_ui.is_menu_open and SpecimenBridge.profile:
				if _is_interacting_with_bed:
					_update_bed_radial_ui()
				else:
					var profile = SpecimenBridge.profile
					var config = _get_specimen_radial_config()
					radial_ui.update_realtime_data(profile.action_log, profile.energy, profile.get_max_energy(), config, specimen._current_action)
		)
		
	# Propagate phase transitions to specimen to control dynamic visual loops (set_process)
	if cycle_manager and specimen:
		cycle_manager.phase_transitioned.connect(func(new_phase: int):
			specimen._on_phase_transitioned(new_phase)
		)

	# Sibling connection for environmental audio and light system transitions
	if lights and audio:
		lights.dimmed.connect(audio.dim_noises)
		lights.snapped_out.connect(audio.snap_noises_out)
		lights.faded_on.connect(audio.fade_noises_on)
	
	# Instantiate and set up CorporateObjectivesManager
	var corp_manager_script = load("res://src/scripts/systems/corporate_objectives_manager.gd")
	var corp_manager = corp_manager_script.new()
	corp_manager.name = "CorporateObjectivesManager"
	corp_manager.cycle_manager = cycle_manager
	corp_manager.specimen = specimen
	add_child(corp_manager)
	
	if start_in_tutorial:
		player.global_position = tutorial_start_pos
		player.global_rotation = Vector3(0, -PI/2, 0) # Face +X (corridor direction)
		
		# Hide core gameplay HUD elements initially
		if ap_label:
			ap_label.visible = false
		var obj_list = $UI.get_node_or_null("ObjectiveList")
		if obj_list:
			obj_list.visible = false
		var inv_ui = $UI.get_node_or_null("InventoryUI")
		if inv_ui:
			inv_ui.visible = false
		if held_item_ui:
			held_item_ui.visible = false
			
		_setup_tutorial()
	else:
		if cycle_manager:
			cycle_manager.start_cycle()


func _setup_tutorial() -> void:
	# 1. Create a tutorial panel dynamically at the bottom center of the HUD
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.theme = load("res://src/resources/theme/hud_theme.tres")
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	_tutorial_panel.add_child(margin_container)
	
	_tutorial_label = Label.new()
	_tutorial_label.name = "TutorialLabel"
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_label.add_theme_font_size_override("font_size", 18)
	margin_container.add_child(_tutorial_label)
	
	$UI.add_child(_tutorial_panel)
	_tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 80)
	_tutorial_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorial_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	_tutorial_label.text = "RESEARCH ACCESS TUNNEL\nUse WASD to move, Mouse to look around."
	
	# Chain message fade animations using a Tween
	var tween = create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(_tutorial_panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		if _tutorial_label and _tutorial_panel:
			_tutorial_label.text = "Proceed to the main observation deck."
			_tutorial_panel.modulate.a = 0.0
	)
	tween.tween_property(_tutorial_panel, "modulate:a", 1.0, 0.5)
	
	# 2. Create DeckEnterArea programmatically to detect player entrance
	_deck_enter_area = Area3D.new()
	_deck_enter_area.name = "DeckEnterArea"
	_deck_enter_area.collision_layer = 0
	_deck_enter_area.collision_mask = 1 # Player layer
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2.0, 4.0, 6.0) # Width, height, length covering the corridor entrance
	col_shape.shape = box_shape
	
	_deck_enter_area.add_child(col_shape)
	add_child(_deck_enter_area)
	
	# Position at the entrance of the observation room
	_deck_enter_area.global_position = Vector3(-21.5, 1.0, -10.2)
	_deck_enter_area.body_entered.connect(_on_deck_entered)


func _on_deck_entered(body: Node3D) -> void:
	if not body is Player:
		return
		
	# Queue free the trigger to prevent re-triggering
	if _deck_enter_area:
		_deck_enter_area.queue_free()
		_deck_enter_area = null
		
	# Start cycle manager
	if cycle_manager:
		cycle_manager.start_cycle()
		
	# Reveal core gameplay HUD elements
	var held_item_ui = $UI.get_node_or_null("HeldItemUI")
	if ap_label:
		ap_label.visible = true
	var obj_list = $UI.get_node_or_null("ObjectiveList")
	if obj_list:
		obj_list.visible = true
	var inv_ui = $UI.get_node_or_null("InventoryUI")
	if inv_ui:
		inv_ui.visible = true
	if held_item_ui:
		held_item_ui.visible = true
		
	# Show deck connection notification
	if _tutorial_label and _tutorial_panel:
		_tutorial_label.text = "OBSERVATION DECK CONNECTED\nCycle 1 Initialized."
		_tutorial_panel.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_interval(4.0)
		tween.tween_property(_tutorial_panel, "modulate:a", 0.0, 1.0)
		tween.finished.connect(func():
			if _tutorial_panel:
				_tutorial_panel.queue_free()
				_tutorial_panel = null
				_tutorial_label = null
		)



func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
		
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	match event.keycode:
		KEY_P:
			if profile.phase == SpecimenProfile.Phase.EGG:
				print("Debug: Hatching Specimen...")
				specimen.hatch()
			else:
				print("Debug: Specimen is already hatched.")
		KEY_M:
			if profile.phase != SpecimenProfile.Phase.EGG:
				# PLACEHOLDER: Cycle through temporary morphology shapes for stress testing.
				profile.morphology = ((profile.morphology + 1) % 5) as SpecimenProfile.Morphology
				print("Debug: Cycled Specimen Morphology to: ", SpecimenProfile.Morphology.keys()[profile.morphology])
			else:
				print("Debug: Cannot cycle morphology in EGG phase.")
		KEY_I:
			print("Debug: Triggering Reinforce...")
			_apply_conditioning_with_energy("REINFORCE")
		KEY_O:
			print("Debug: Triggering Punish...")
			_apply_conditioning_with_energy("PUNISH")
		KEY_U:
			print("Debug: Triggering Cycle End...")
			if cycle_manager:
				cycle_manager.end_cycle()
			else:
				EnvironmentBridge.process_cycle_end(profile)
				for action_id in profile.action_pool:
					profile.action_pool[action_id] = max(profile.action_pool[action_id] - 0.5, 1.0)
				profile.current_cycle += 1
			_print_status()

func _print_status() -> void:
	var profile = SpecimenBridge.profile
	var env = EnvironmentBridge.profile
	if not profile or not env:
		return
	print("--- CURRENT RUN STATE (Cycle ", profile.current_cycle, ") ---")
	# PLACEHOLDER: Displaying temporary morphology shape in state log.
	print("Phase: ", SpecimenProfile.Phase.keys()[profile.phase], ", Morphology: ", SpecimenProfile.Morphology.keys()[profile.morphology])
	print("Environment: Heat = ", env.heat, "°C (Optimal: ", env.is_heat_optimal(), "), Moisture = ", env.moisture, "% (Optimal: ", env.is_moisture_optimal(), ")")
	print("Specimen Vars: Plasticity = ", profile.neural_plasticity, ", Coherence = ", profile.identity_coherence, ", Resonance = ", profile.resonance_frequency, ", Threat = ", profile.threat_indexing, ", Reward = ", profile.reward_schema)
	print("Ruthlessness: ", profile.ruthlessness, " | Energy: ", profile.energy)
	if cycle_manager:
		print("Cycle AP: ", cycle_manager.current_ap)
	print("Action Pool Weights: ", profile.action_pool)
	if specimen and is_instance_valid(specimen.controller):
		print("Action Boredom: ", specimen.controller.action_boredom)
	print("Action Log: ", profile.action_log)
	print("---------------------------------------------")

func _apply_conditioning_with_energy(type: String) -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	if _current_action_conditioned:
		print("World: Current action already conditioned. Ignoring.")
		return
		
	# Consume AP
	if cycle_manager:
		if not cycle_manager.spend_ap(1):
			print("World: Action blocked! AP is depleted.")
			return
		# Add to addressed actions for neglect decay
		var last = profile.action_log
		if last.size() > 0:
			cycle_manager.addressed_actions.append(last[0])
		else:
			# Fallback if no action logged yet
			cycle_manager.addressed_actions.append("VOCALIZE")

	# Check energy
	if profile.energy <= 0.0:
		# Apply silent penalties with no prints
		profile.reward_schema = clamp(profile.reward_schema - 2.0, -50.0, 50.0)
		profile.identity_coherence = clamp(profile.identity_coherence - 2.0, 0.0, 100.0)
		if specimen and not specimen.is_sleeping:
			specimen.enter_sleep()
	else:
		# Decrement energy
		profile.energy = max(profile.energy - 1.0, 0.0)
		
		# Apply normal conditioning
		if type == "REINFORCE":
			if reinforcement_system:
				reinforcement_system.reinforce()
			InteractionBus.conditioning_applied.emit("REINFORCE")
		else:
			if reinforcement_system:
				reinforcement_system.punish()
			InteractionBus.conditioning_applied.emit("PUNISH")
			
		_current_action_conditioned = true

				
		# If energy hits 0, trigger sleep
		if profile.energy <= 0.0 and specimen and not specimen.is_sleeping:
			specimen.enter_sleep()
			
	if lights:
		lights.update_hue_from_reward(profile.reward_schema)
			
	_print_status()

func _on_subaction_selected(category: String, action_type: String) -> void:
	print("Radial UI: subaction selected - Category: ", category, ", Type: ", action_type)
	var action_upper = action_type.to_upper()
	
	match category:
		"TOP":
			if action_upper == "PET":
				if cycle_manager:
					if not cycle_manager.spend_ap(1):
						print("World: Action blocked! AP is depleted.")
						return
				if specimen:
					specimen.apply_sleep_interaction("PET")
				InteractionBus.conditioning_applied.emit("PET")
				_print_status()
			else:
				_apply_conditioning_with_energy("REINFORCE")
		"BOTTOM":
			if action_upper == "SHOCK":
				if cycle_manager:
					if not cycle_manager.spend_ap(2):
						print("World: Action blocked! AP is depleted.")
						return
				if specimen:
					specimen.apply_sleep_interaction("SHOCK")
				InteractionBus.conditioning_applied.emit("SHOCK")
				_print_status()
			else:
				_apply_conditioning_with_energy("PUNISH")
		"LEFT":
			var env = EnvironmentBridge.profile
			if env:
				if action_upper == "HEAT" or action_upper == "HEAT_CONTROL":
					env.change_heat(2.0)
				elif action_upper == "MOISTURE" or action_upper == "MOISTURE_CONTROL":
					env.change_moisture(10.0)
				_print_status()
		"RIGHT":
			var profile = SpecimenBridge.profile
			if action_upper == "END_CYCLE" and profile:
				if cycle_manager:
					cycle_manager.end_cycle()
				else:
					EnvironmentBridge.process_cycle_end(profile)
					for action_id in profile.action_pool:
						profile.action_pool[action_id] = max(profile.action_pool[action_id] - 0.5, 1.0)
					profile.current_cycle += 1
				_print_status()
			elif action_upper == "CERTIFY":
				if cycle_manager:
					cycle_manager.trigger_certify_sequence()
			elif action_upper == "CHECK_STATUS":
				_print_status()
			elif action_upper == "SLEEP":
				if cycle_manager:
					if profile:
						if profile.current_cycle < 0:
							cycle_manager.start_cycle()
						else:
							if cycle_manager.is_cycle_active:
								cycle_manager.end_cycle()
								await get_tree().create_timer(0.5).timeout
								cycle_manager.start_cycle()
							else:
								cycle_manager.start_cycle()
				_print_status()

func _on_monitor_panel_end_cycle_requested() -> void:
	var profile = SpecimenBridge.profile
	if cycle_manager:
		cycle_manager.end_cycle()
	elif profile:
		EnvironmentBridge.process_cycle_end(profile)
		for action_id in profile.action_pool:
			profile.action_pool[action_id] = max(profile.action_pool[action_id] - 0.5, 1.0)
		profile.current_cycle += 1
	_print_status()

func _on_bed_sleep_requested() -> void:
	_is_interacting_with_bed = true
	_update_bed_radial_ui()

func _update_bed_radial_ui() -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	var specimen_sleeping = true
	if specimen and not specimen.is_sleeping and profile.phase != SpecimenProfile.Phase.EGG:
		specimen_sleeping = false
		
	var config = {
		"RIGHT": {
			"label": "SLEEP",
			"action": "SLEEP"
		}
	}
	var center_override = {
		"header": "REST MODULE",
		"current_action": "NOT STARTED" if profile.current_cycle < 0 else "CYCLE: " + str(profile.current_cycle),
		"lines": [],
		"energy": ""
	}
	
	if specimen_sleeping:
		center_override["lines"] = [
			"STATUS: READY",
			"Specimen is sleeping.",
			"Select SLEEP to advance cycle."
		]
	else:
		center_override["lines"] = [
			"STATUS: READY",
			"Warning: Specimen is active!",
			"Select SLEEP to advance cycle."
		]
		
	if radial_ui:
		radial_ui.open_menu([], 0.0, 0.0, config, "", center_override)

func _get_specimen_radial_config() -> Dictionary:
	var profile = SpecimenBridge.profile
	if not profile:
		return {}
		
	# If sleeping
	if specimen and specimen.is_sleeping:
		return {
			"TOP": {
				"label": "PET",
				"action": "PET"
			},
			"BOTTOM": {
				"label": "SHOCK",
				"action": "SHOCK"
			}
		}
		
	# If Egg
	if profile.phase == SpecimenProfile.Phase.EGG:
		return {
			"RIGHT": {
				"label": "SYSTEM",
				"subactions": ["END_CYCLE", "CHECK_STATUS"]
			}
		}
		
	# Awake CHILD/ADULT
	# Compute ruthlessness labels
	var r = profile.ruthlessness
	var tier = 0
	if r >= SpecimenProfile.COHERENCE_TIER_HIGH:
		tier = 2
	elif r >= SpecimenProfile.COHERENCE_TIER_LOW:
		tier = 1
		
	var reinforce_labels = ["REINFORCE", "REWARD", "GRANT RELIEF"]
	var punish_labels = ["PUNISH", "CORRECT", "IMPOSE CONSEQUENCE"]
	
	var right_subactions = ["END_CYCLE", "CHECK_STATUS"]
	if profile.current_cycle >= 18 and profile.phase == SpecimenProfile.Phase.CHILD:
		right_subactions = ["CERTIFY", "CHECK_STATUS"]
		
	if _current_action_conditioned:
		return {
			"TOP": {
				"label": "RATED",
				"disabled": true
			},
			"BOTTOM": {
				"label": "RATED",
				"disabled": true
			},
			"RIGHT": {
				"label": "SYSTEM",
				"subactions": right_subactions
			}
		}
		
	return {
		"TOP": {
			"label": reinforce_labels[tier],
			"subactions": ["COMFORT"]
		},
		"BOTTOM": {
			"label": punish_labels[tier],
			"subactions": ["SHOCK"]
		},
		"RIGHT": {
			"label": "SYSTEM",
			"subactions": right_subactions
		}
	}


func _on_monitor_panel_shop_opened() -> void:
	var spawned_keys = []
	var objects_root = get_node_or_null("Objects")
	if objects_root:
		for child in objects_root.get_children():
			spawned_keys.append(child.name)
	if monitor_panel:
		monitor_panel.update_spawned_items(spawned_keys)

func _on_monitor_panel_object_purchased(item_key: String, scene_path: String, spawn_pos: Vector3, spawn_rot: Vector3) -> void:
	print("World: Spawning purchased object: ", item_key, " from ", scene_path)
	var scene = load(scene_path)
	if not scene:
		push_error("Failed to load scene: " + scene_path)
		return
		
	var obj = scene.instantiate() as Node3D
	if not obj:
		push_error("Failed to instantiate scene: " + scene_path)
		return
		
	var objects_root = get_node_or_null("Objects")
	if not objects_root:
		push_error("Failed to find Objects root node in world scene.")
		obj.queue_free()
		return
		
	# Spawn at configured position and rotation
	obj.name = item_key
	obj.global_rotation_degrees = spawn_rot
	objects_root.add_child(obj)
	obj.global_position = spawn_pos
	print("World: Successfully spawned ", obj.name, " at ", obj.global_position, " with rotation ", obj.global_rotation_degrees)
	
	# Update shop with the new list of spawned items
	_on_monitor_panel_shop_opened()
