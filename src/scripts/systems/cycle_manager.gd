extends Node
class_name CycleManager

signal ap_changed(new_ap: int)
signal cycle_started(cycle_num: int)
signal cycle_ended(cycle_num: int)
signal phase_transitioned(new_phase: int)

@export var certify_duration: float = 5.0
@export var ap_depletion_dim_duration: float = 3.0
@export var start_cycle_fade_duration: float = 2.0

var current_ap: int = 10
var addressed_actions: Array = []
var individuation_boost_total: float = 0.0 # Capped at 15.0
var is_transitioning: bool = false

@onready var world = get_parent()

var neglect_decay: NeglectDecay = null
var reinforcement_system: ReinforcementSystem = null
var specimen: Specimen = null

func _ready() -> void:
	# Find core systems dynamically from parent world node (Rule 11)
	neglect_decay = world.find_child("NeglectDecay") as NeglectDecay
	reinforcement_system = world.find_child("ReinforcementSystem") as ReinforcementSystem
	specimen = world.find_child("Specimen") as Specimen
	
	# Initial cycle startup
	start_cycle()

func start_cycle() -> void:
	current_ap = 10
	addressed_actions.clear()
	is_transitioning = false
	
	var profile = SpecimenBridge.profile
	if profile:
		# Specimen energy: 5 + current_cycle * 2 (Rule 18 / Runtime state)
		profile.energy = 5.0 + float(profile.current_cycle) * 2.0
		print("CycleManager: Started Cycle ", profile.current_cycle, " | AP: ", current_ap, " | Energy: ", profile.energy)
		
		# Auto-hatch at Cycle 5 if still EGG
		if profile.current_cycle >= 5 and profile.phase == SpecimenProfile.Phase.EGG:
			if specimen:
				specimen.hatch()
				phase_transitioned.emit(SpecimenProfile.Phase.CHILD)
				
	ap_changed.emit(current_ap)
	cycle_started.emit(profile.current_cycle if profile else 1)
	
	# Fade lights on for the start of the cycle
	var lights = world.get_node_or_null("Lights")
	if lights and lights.has_method("fade_lights_on") and lights.has_method("update_hue_from_reward"):
		if profile:
			lights.update_hue_from_reward(profile.reward_schema, 0.0) # Snap hue instantly
		lights.fade_lights_on(start_cycle_fade_duration)

func spend_ap(amount: int) -> void:
	current_ap = max(current_ap - amount, 0)
	ap_changed.emit(current_ap)
	print("CycleManager: Spent ", amount, " AP | Remaining: ", current_ap)
	
	if current_ap == 0 and not is_transitioning:
		_trigger_depleted_ap_transition()

func _trigger_depleted_ap_transition() -> void:
	is_transitioning = true
	print("CycleManager: AP depleted to 0. Initiating slow light dimming...")
	
	var lights = world.get_node_or_null("Lights")
	if lights and lights.has_method("dim_lights_slow") and ap_depletion_dim_duration > 0.0:
		var tween = lights.dim_lights_slow(ap_depletion_dim_duration)
		if tween:
			await tween.finished
	else:
		if lights and lights.has_method("snap_lights_out"):
			lights.snap_lights_out()
			
	end_cycle()

func end_cycle() -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	print("CycleManager: Ending Cycle ", profile.current_cycle)
	
	var lights = world.get_node_or_null("Lights")
	if lights and lights.has_method("snap_lights_out") and lights.has_method("is_lights_dimmed"):
		if not lights.is_lights_dimmed():
			lights.snap_lights_out()
			
	cycle_ended.emit(profile.current_cycle)
	
	# 1. Neglect decay
	if neglect_decay:
		neglect_decay.apply_cycle_decay(addressed_actions)
		
	# 2. Environment drift and consequences
	EnvironmentBridge.process_cycle_end(profile)
	
	# 3. Individuation window check (cycles 9-13)
	if profile.current_cycle >= 9 and profile.current_cycle <= 13:
		if profile.identity_coherence >= 34.0 and individuation_boost_total < 15.0:
			var remaining_cap = 15.0 - individuation_boost_total
			var refuse_boost = min(2.0, remaining_cap)
			profile.apply_action_weight("REFUSE_INTERACTION", refuse_boost)
			individuation_boost_total += refuse_boost
			
			remaining_cap = 15.0 - individuation_boost_total
			var vocal_boost = min(1.5, remaining_cap)
			profile.apply_action_weight("VOCALIZE", vocal_boost)
			individuation_boost_total += vocal_boost
			print("CycleManager: Individuation boost applied. Cumulative boost: ", individuation_boost_total, "/15.0")

	# If specimen is sleeping, wake it naturally at cycle end
	if specimen and specimen.is_sleeping:
		specimen.wake_up()

	# 4. Cycle counter increment
	profile.current_cycle += 1
	
	# 5. Phase transition check
	if profile.current_cycle >= 5 and profile.phase == SpecimenProfile.Phase.EGG:
		if specimen:
			specimen.hatch()
			phase_transitioned.emit(SpecimenProfile.Phase.CHILD)
			
	# Start next cycle
	start_cycle()

## Triggers the non-skippable CERTIFY sequence to progress to ADULT phase.
func trigger_certify_sequence() -> void:
	var profile = SpecimenBridge.profile
	if not profile or profile.phase != SpecimenProfile.Phase.CHILD:
		return
		
	print("CycleManager: CERTIFY sequence initiated.")
	current_ap = 0
	ap_changed.emit(0)
	
	# 1. Visual egg revert
	if specimen:
		specimen.controller.action_timer.stop()
		specimen.is_sleeping = false
		specimen.velocity = Vector3.ZERO
		
		# Return visuals to egg state
		specimen.visuals.visible = false
		specimen.egg.visible = true
		specimen.egg.scale = specimen.base_egg_scale
		if specimen.egg_material:
			specimen.egg_material.emission_energy_multiplier = 0.5
			specimen.egg_material.albedo_color = Color(0.9, 0.9, 0.95)
			specimen.egg_material.emission = Color(0.1, 0.15, 0.2)
			
	# 2. Spawn clinical-to-emotional translation overlay (non-skippable)
	var canvas = CanvasLayer.new()
	canvas.name = "CertifyOverlay"
	canvas.layer = 100 # Draw over normal UI
	add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.05, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	# Translation texts configuration
	var translations = [
		{"clinical": "NEURAL PLASTICITY",    "emotional": "ADAPTABILITY / VULNERABILITY"},
		{"clinical": "THREAT INDEXING",      "emotional": "ANGER / SURVIVAL INSTINCT"},
		{"clinical": "REWARD SCHEMA",        "emotional": "JOY / DEPRIVATION"},
		{"clinical": "IDENTITY COHERENCE",   "emotional": "AUTONOMY / SELF"},
		{"clinical": "RESONANCE FREQUENCY",  "emotional": "ATTACHMENT / ENTANGLEMENT"}
	]
	
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(container)
	
	var title = Label.new()
	title.text = "CERTIFYING SPECIMEN INDIVIDUATION..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.65, 0.2)) # Amber glow
	container.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer)
	
	var labels: Array[Label] = []
	for trans in translations:
		var lbl = Label.new()
		lbl.text = "Initializing variable: " + trans["clinical"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		container.add_child(lbl)
		labels.append(lbl)
		
	# Animate translations sequential reveal over the duration
	var step_time = certify_duration / float(translations.size())
	var anim_tween = create_tween()
	
	for i in range(translations.size()):
		var lbl = labels[i]
		var trans = translations[i]
		
		# Fade in clinical, then translate to emotional
		anim_tween.tween_interval(step_time * 0.3)
		anim_tween.tween_callback(func():
			lbl.text = trans["clinical"] + " ➔ " + trans["emotional"]
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.add_theme_font_size_override("font_size", 15)
		)
		anim_tween.tween_interval(step_time * 0.7)
		
	# 3. Metamorphosis completion: egg cracks, set ADULT
	anim_tween.chain().tween_callback(func():
		print("CycleManager: Translation complete. Cracking egg...")
		# Shake visual revert
		if specimen:
			# Shake
			var shake = create_tween().set_loops(4)
			shake.tween_property(specimen.egg, "rotation:z", 0.15, 0.06)
			shake.tween_property(specimen.egg, "rotation:z", -0.15, 0.06)
			
			# Crack scale-down / visuals reveal
			var crack = create_tween().set_parallel(true)
			crack.tween_property(specimen.egg, "scale", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			specimen.visuals.visible = true
			specimen.visuals.scale = Vector3.ZERO
			crack.tween_property(specimen.visuals, "scale", Vector3.ONE * 1.5, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
			crack.chain().tween_callback(func():
				specimen.egg.visible = false
				profile.phase = SpecimenProfile.Phase.ADULT
				specimen.controller.activate()
				phase_transitioned.emit(SpecimenProfile.Phase.ADULT)
				print("CycleManager: Specimen has emerged into an ADULT! Phase 2 begins.")
				canvas.queue_free()
			)
		else:
			profile.phase = SpecimenProfile.Phase.ADULT
			phase_transitioned.emit(SpecimenProfile.Phase.ADULT)
			canvas.queue_free()
	)
