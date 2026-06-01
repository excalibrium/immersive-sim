extends Node
class_name CycleManager

signal ap_changed(new_ap: int)
signal cycle_started(cycle_num: int)
signal cycle_ended(cycle_num: int)
signal phase_transitioned(new_phase: int)

@export var certify_duration: float = 5.0
@export var ap_depletion_dim_duration: float = 3.0
@export var start_cycle_fade_duration: float = 2.0

const DECAY_RATE = 0.5
const WEIGHT_FLOOR = 1.0

var current_ap: int = 10
var addressed_actions: Array = []
var individuation_boost_total: float = 0.0 # Capped at 15.0
var is_transitioning: bool = false
var is_cycle_active: bool = false

## external_specimen: Specimen sibling node. Assigned in inspector.
@export var external_specimen: Specimen
## external_lights: LightSystem sibling node. Assigned in inspector.
@export var external_lights: LightSystem

func start_cycle() -> void:
	current_ap = 10
	addressed_actions.clear()
	is_transitioning = false
	is_cycle_active = true
	
	var profile = SpecimenBridge.profile
	if profile:
		if profile.current_cycle == -1:
			profile.current_cycle = 0
		# Specimen energy: get_max_energy() (Rule 18 / Runtime state)
		profile.energy = profile.get_max_energy()
		print("CycleManager: Started Cycle ", profile.current_cycle, " | AP: ", current_ap, " | Energy: ", profile.energy)
		
		# Auto-hatch at Cycle 5 if still EGG
		if profile.current_cycle >= 5 and profile.phase == SpecimenProfile.Phase.EGG:
			if is_instance_valid(external_specimen):
				external_specimen.hatch()
				phase_transitioned.emit(SpecimenProfile.Phase.CHILD)
				
	ap_changed.emit(current_ap)
	cycle_started.emit(profile.current_cycle if profile else 1)
	
	# Fade lights on for the start of the cycle
	if is_instance_valid(external_lights):
		if profile:
			external_lights.update_hue_from_reward(profile.reward_schema, 0.0) # Snap hue instantly
		external_lights.fade_lights_on(start_cycle_fade_duration)

func spend_ap(amount: int) -> bool:
	if current_ap < amount:
		print("CycleManager: Not enough AP! Required: ", amount, " | Available: ", current_ap)
		return false
	current_ap -= amount
	ap_changed.emit(current_ap)
	print("CycleManager: Spent ", amount, " AP | Remaining: ", current_ap)
	
	if current_ap == 0 and not is_transitioning:
		_trigger_depleted_ap_transition()
	return true

func _trigger_depleted_ap_transition() -> void:
	is_transitioning = true
	print("CycleManager: AP depleted to 0. Initiating slow light dimming...")
	
	if is_instance_valid(external_lights) and ap_depletion_dim_duration > 0.0:
		var tween = external_lights.dim_lights_slow(ap_depletion_dim_duration)
		if tween:
			await tween.finished
	else:
		if is_instance_valid(external_lights):
			external_lights.snap_lights_out()
			
	is_transitioning = false

func apply_cycle_decay(addressed: Array) -> void:
	var profile = SpecimenBridge.profile
	if not profile:
		return
	for action_id in profile.action_pool:
		if action_id not in addressed:
			var current = profile.action_pool[action_id]
			profile.action_pool[action_id] = max(
				current - DECAY_RATE, WEIGHT_FLOOR
			)

func end_cycle() -> void:
	if not is_cycle_active:
		return
	is_cycle_active = false
	current_ap = 0
	ap_changed.emit(0)
	is_transitioning = false
	var profile = SpecimenBridge.profile
	if not profile:
		return
		
	print("CycleManager: Ending Cycle ", profile.current_cycle)
	
	if is_instance_valid(external_lights):
		if not external_lights.is_lights_dimmed():
			external_lights.snap_lights_out()
			
	cycle_ended.emit(profile.current_cycle)
	
	# 1. Neglect decay
	apply_cycle_decay(addressed_actions)
		
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
	if is_instance_valid(external_specimen) and external_specimen.is_sleeping:
		external_specimen.wake_up()
 
	# 4. Cycle counter increment
	profile.current_cycle += 1
	
	# 5. Phase transition check
	if profile.current_cycle >= 5 and profile.phase == SpecimenProfile.Phase.EGG:
		if is_instance_valid(external_specimen):
			external_specimen.hatch()
			phase_transitioned.emit(SpecimenProfile.Phase.CHILD)

## Triggers the non-skippable CERTIFY sequence to progress to ADULT phase.
func trigger_certify_sequence() -> void:
	var profile = SpecimenBridge.profile
	if not profile or profile.phase != SpecimenProfile.Phase.CHILD:
		return
		
	print("CycleManager: CERTIFY sequence initiated.")
	current_ap = 0
	ap_changed.emit(0)
	
	# 1. Visual egg revert
	if is_instance_valid(external_specimen):
		if is_instance_valid(external_specimen.controller) and is_instance_valid(external_specimen.controller.action_timer):
			external_specimen.controller.action_timer.stop()
		external_specimen.is_sleeping = false
		external_specimen.velocity = Vector3.ZERO
		
		# Return visuals to egg state
		if is_instance_valid(external_specimen.visuals):
			external_specimen.visuals.visible = false
		if is_instance_valid(external_specimen.egg):
			external_specimen.egg.visible = true
			external_specimen.egg.scale = external_specimen.base_egg_scale
		if external_specimen.egg_material:
			external_specimen.egg_material.emission_energy_multiplier = 0.5
			external_specimen.egg_material.albedo_color = Color(0.9, 0.9, 0.95)
			external_specimen.egg_material.emission = Color(0.1, 0.15, 0.2)
			
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
		if is_instance_valid(external_specimen):
			# Shake
			var shake = create_tween().set_loops(4)
			shake.tween_property(external_specimen.egg, "rotation:z", 0.15, 0.06)
			shake.tween_property(external_specimen.egg, "rotation:z", -0.15, 0.06)
			
			# Crack scale-down / visuals reveal
			var crack = create_tween().set_parallel(true)
			crack.tween_property(external_specimen.egg, "scale", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			external_specimen.visuals.visible = true
			external_specimen.visuals.scale = Vector3.ZERO
			crack.tween_property(external_specimen.visuals, "scale", Vector3.ONE * 1.5, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
			crack.chain().tween_callback(func():
				if is_instance_valid(external_specimen):
					external_specimen.egg.visible = false
					if is_instance_valid(external_specimen.controller):
						external_specimen.controller.activate()
				profile.phase = SpecimenProfile.Phase.ADULT
				phase_transitioned.emit(SpecimenProfile.Phase.ADULT)
				print("CycleManager: Specimen has emerged into an ADULT! Phase 2 begins.")
				canvas.queue_free()
			)
		else:
			profile.phase = SpecimenProfile.Phase.ADULT
			phase_transitioned.emit(SpecimenProfile.Phase.ADULT)
			canvas.queue_free()
	)
