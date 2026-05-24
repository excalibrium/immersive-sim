extends Node3D

## Level Controller for the main World.
## Initializes the GameSession and acts as the 'Objective Giver'.

const RS = preload("res://src/scripts/conditioning/reinforcement_system.gd")
const ND = preload("res://src/scripts/conditioning/neglect_decay.gd")

@onready var crosshair = $UI/Crosshair
@onready var player = $Player
@onready var specimen = $Specimen
@onready var monitor_panel = $MonitorPanel
@onready var lights = $Lights

var reinforcement_system: ReinforcementSystem = null
var neglect_decay: NeglectDecay = null
var cycle_manager: Node = null
var ap_label: Label = null

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
	var interactor = player.find_child("PlayerInteractor")
	if interactor:
		crosshair.setup(interactor)
		
	# Instantiate systems dynamically for prototype testing
	reinforcement_system = RS.new()
	neglect_decay = ND.new()
	add_child(reinforcement_system)
	add_child(neglect_decay)

	# Load and instantiate AP HUD Label from scene
	var ap_label_scene = load("res://src/scenes/ui/APLabel.tscn")
	ap_label = ap_label_scene.instantiate()
	$UI.add_child(ap_label)

	# Instantiate CycleManager
	# Instantiate CycleManager script dynamically
	var cycle_manager_script = load("res://src/scripts/systems/cycle_manager.gd")
	cycle_manager = cycle_manager_script.new()
	cycle_manager.name = "CycleManager"
	
	# Connect ap_changed before adding child to receive initial value
	cycle_manager.ap_changed.connect(func(new_ap: int):
		if ap_label:
			ap_label.update_ap(new_ap)
	)
	
	add_child(cycle_manager)

	# Connect MonitorPanel cycle end signal
	if monitor_panel:
		monitor_panel.end_cycle_requested.connect(_on_monitor_panel_end_cycle_requested)

	# Connect Radial UI events if present in the tree
	var radial_ui = find_child("RadialUI")
	if radial_ui:
		radial_ui.subaction_selected.connect(_on_subaction_selected)
		
	# Connect Specimen interaction to open the Radial UI
	var specimen_interactable = specimen.find_child("Interactable")
	if specimen_interactable and radial_ui:
		specimen_interactable.interacted.connect(func(_interactor):
			var r = 0.0
			var log_data = []
			var phase = 0 # Default to EGG
			if SpecimenBridge.profile:
				r = SpecimenBridge.profile.ruthlessness
				log_data = SpecimenBridge.profile.action_log
				phase = SpecimenBridge.profile.phase
			radial_ui.open_menu(r, log_data, phase, specimen.is_sleeping)
		)

	# Connect Specimen actions to update Radial UI real-time logs
	if specimen and radial_ui:
		specimen.action_performed.connect(func(_action_id: String):
			if radial_ui.is_menu_open and SpecimenBridge.profile:
				radial_ui.update_realtime_data(SpecimenBridge.profile.action_log)
		)
		specimen.sleep_entered.connect(func():
			radial_ui.transition_to_sleep_layout()
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
				neglect_decay.apply_cycle_decay([])
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
	print("Action Log: ", profile.action_log)
	print("---------------------------------------------")

func _apply_conditioning_with_energy(type: String) -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	# Consume AP
	if cycle_manager:
		cycle_manager.spend_ap(1) # Conditioning costs 1 AP
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
		else:
			if reinforcement_system:
				reinforcement_system.punish()
				
		# If energy hits 0, trigger sleep
		if profile.energy <= 0.0 and specimen and not specimen.is_sleeping:
			specimen.enter_sleep()
			
	if lights and lights.has_method("update_hue_from_reward"):
		lights.update_hue_from_reward(profile.reward_schema)
			
	_print_status()

func _on_subaction_selected(category: String, action_type: String) -> void:
	print("Radial UI: subaction selected - Category: ", category, ", Type: ", action_type)
	var action_upper = action_type.to_upper()
	
	match category:
		"TOP":
			if action_upper == "PET":
				if specimen:
					specimen.apply_sleep_interaction("PET")
				if cycle_manager:
					cycle_manager.spend_ap(1)
				_print_status()
			else:
				_apply_conditioning_with_energy("REINFORCE")
		"BOTTOM":
			if action_upper == "SHOCK":
				if specimen:
					specimen.apply_sleep_interaction("SHOCK")
				if cycle_manager:
					cycle_manager.spend_ap(2)
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
					neglect_decay.apply_cycle_decay([])
					profile.current_cycle += 1
				_print_status()
			elif action_upper == "CERTIFY":
				if cycle_manager:
					cycle_manager.trigger_certify_sequence()
			elif action_upper == "CHECK_STATUS":
				_print_status()

func _on_monitor_panel_end_cycle_requested() -> void:
	var profile = SpecimenBridge.profile
	if cycle_manager:
		cycle_manager.end_cycle()
	elif profile:
		EnvironmentBridge.process_cycle_end(profile)
		if neglect_decay:
			neglect_decay.apply_cycle_decay([])
		profile.current_cycle += 1
	_print_status()
