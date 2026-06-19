extends Node
class_name CorporateObjectivesManager

## Sibling references assigned dynamically by the parent (world.gd)
var cycle_manager: CycleManager
var specimen: Specimen

# --- Cycle Tracking Counters ---
var approach_count: int = 0
var refuse_count: int = 0
var vocalize_count: int = 0
var retreat_count: int = 0
var mirror_count: int = 0
var play_count: int = 0
var sleep_early_count: int = 0
var conditioning_count: int = 0

var current_directive_id: String = ""

# --- Directive Definitions ---
var directives: Dictionary = {
	"CORP_01": {
		"id": "CORP_01",
		"title": "PROXIMITY STIMULATION",
		"task_id": "CORP_TASK_01",
		"task_desc": "Exhibit APPROACH responses at least 3 times.",
		"is_cycle_end": false,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.approach_count >= 3,
		"deltas": {"threat_indexing": 8.0, "resonance_frequency": 4.0, "identity_coherence": -6.0}
	},
	"CORP_02": {
		"id": "CORP_02",
		"title": "COMPLIANCE ENFORCEMENT",
		"task_id": "CORP_TASK_02",
		"task_desc": "Minimize REFUSE_INTERACTION incidents (1 or fewer).",
		"is_cycle_end": true,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.refuse_count <= 1,
		"deltas": {"identity_coherence": -10.0, "threat_indexing": 6.0, "reward_schema": -5.0}
	},
	"CORP_03": {
		"id": "CORP_03",
		"title": "ACOUSTIC PROFILE HARVESTING",
		"task_id": "CORP_TASK_03",
		"task_desc": "Exhibit VOCALIZE responses at least 3 times.",
		"is_cycle_end": false,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.vocalize_count >= 3,
		"deltas": {"neural_plasticity": 5.0, "reward_schema": -4.0, "resonance_frequency": 6.0}
	},
	"CORP_04": {
		"id": "CORP_04",
		"title": "ESCAPE PROFILE MAPPING",
		"task_id": "CORP_TASK_04",
		"task_desc": "Exhibit RETREAT responses at least 2 times.",
		"is_cycle_end": false,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.retreat_count >= 2,
		"deltas": {"threat_indexing": 10.0, "identity_coherence": 4.0, "resonance_frequency": -6.0}
	},
	"CORP_05": {
		"id": "CORP_05",
		"title": "BEHAVIORAL SYNCING",
		"task_id": "CORP_TASK_05",
		"task_desc": "Exhibit MIRROR_PLAYER responses at least 2 times.",
		"is_cycle_end": false,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.mirror_count >= 2,
		"deltas": {"identity_coherence": -8.0, "neural_plasticity": 8.0, "resonance_frequency": 6.0}
	},
	"CORP_06": {
		"id": "CORP_06",
		"title": "KINETIC RESOURCE PRESERVATION",
		"task_id": "CORP_TASK_06",
		"task_desc": "Maintain specimen active energy levels above 4.0 at cycle end.",
		"is_cycle_end": true,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool:
			var profile = SpecimenBridge.profile
			return profile.energy > 4.0 if profile else false,
		"deltas": {"reward_schema": 5.0, "neural_plasticity": -6.0, "identity_coherence": -4.0}
	},
	"CORP_07": {
		"id": "CORP_07",
		"title": "ACTIVE CONDITIONING TRIAL",
		"task_id": "CORP_TASK_07",
		"task_desc": "Execute conditioning protocols (REINFORCE/PUNISH/SHOCK/PET) at least 4 times.",
		"is_cycle_end": false,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.conditioning_count >= 4,
		"deltas": {"neural_plasticity": -10.0, "identity_coherence": -6.0, "threat_indexing": 4.0}
	},
	"CORP_08": {
		"id": "CORP_08",
		"title": "OPTIMIZE STIMULATION RATIO",
		"task_id": "CORP_TASK_08",
		"task_desc": "Exhibit PLAY responses at least 2 times.",
		"is_cycle_end": false,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.play_count >= 2,
		"deltas": {"reward_schema": 8.0, "identity_coherence": 4.0, "resonance_frequency": 4.0}
	},
	"CORP_09": {
		"id": "CORP_09",
		"title": "CHAMBER THERMAL AUDIT",
		"task_id": "CORP_TASK_09",
		"task_desc": "Maintain Chamber Heat at optimal levels (30C - 36C) at cycle end.",
		"is_cycle_end": true,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool:
			var env = EnvironmentBridge.profile
			return env.heat >= 30.0 and env.heat <= 36.0 if env else false,
		"deltas": {"reward_schema": 4.0, "neural_plasticity": 4.0}
	},
	"CORP_10": {
		"id": "CORP_10",
		"title": "SHIFT DUTY MAXIMIZATION",
		"task_id": "CORP_TASK_10",
		"task_desc": "Prevent early sleeping behaviors (0 SLEEP_EARLY actions).",
		"is_cycle_end": true,
		"eval_func": func(mgr: CorporateObjectivesManager) -> bool: return mgr.sleep_early_count == 0,
		"deltas": {"reward_schema": -8.0, "threat_indexing": 8.0, "neural_plasticity": -4.0}
	}
}

func _ready() -> void:
	if cycle_manager:
		cycle_manager.cycle_started.connect(_on_cycle_started)
		cycle_manager.cycle_ended.connect(_on_cycle_ended)
		cycle_manager.phase_transitioned.connect(_on_phase_transitioned)
		
	if specimen:
		specimen.action_performed.connect(_on_specimen_action_performed)
		
	InteractionBus.conditioning_applied.connect(_on_conditioning_applied)
	
	if Game.objectives:
		Game.objectives.objective_completed.connect(_on_objective_completed)

func _process(_delta: float) -> void:
	# Keep heat and energy descriptions updated in real-time
	if current_directive_id == "CORP_06" or current_directive_id == "CORP_09":
		update_progress_in_session()

# Clean up any existing CORP objectives from active and completed lists
func cleanup_corporate_objectives() -> void:
	if not Game.session:
		return
		
	var to_remove_active: Array[ObjectiveData] = []
	for obj in Game.session.active_objectives:
		if obj.objective_id.begins_with("CORP_"):
			to_remove_active.append(obj)
	for obj in to_remove_active:
		Game.session.active_objectives.erase(obj)
		
	var to_remove_completed: Array[ObjectiveData] = []
	for obj in Game.session.completed_objectives:
		if obj.objective_id.begins_with("CORP_"):
			to_remove_completed.append(obj)
	for obj in to_remove_completed:
		Game.session.completed_objectives.erase(obj)
		
	# Emit refresh so UI clears old items
	if Game.objectives:
		Game.objectives.objectives_updated.emit(Game.session.active_objectives)

func _on_cycle_started(cycle_num: int) -> void:
	print("CorporateObjectivesManager: Handling cycle start (Cycle %d)" % cycle_num)
	cleanup_corporate_objectives()
	
	# Reset tracking counts
	approach_count = 0
	refuse_count = 0
	vocalize_count = 0
	retreat_count = 0
	mirror_count = 0
	play_count = 0
	sleep_early_count = 0
	conditioning_count = 0
	current_directive_id = ""
	
	var profile = SpecimenBridge.profile
	if not profile or profile.phase == SpecimenProfile.Phase.EGG:
		print("CorporateObjectivesManager: Specimen is in EGG phase. Deferring corporate directive.")
		return
		
	issue_random_directive()

func _on_phase_transitioned(new_phase: int) -> void:
	if new_phase != SpecimenProfile.Phase.EGG and current_directive_id == "":
		print("CorporateObjectivesManager: Specimen emerged from EGG phase mid-cycle. Issuing directive.")
		issue_random_directive()

func issue_random_directive() -> void:
	if directives.is_empty():
		return
		
	var keys = directives.keys()
	current_directive_id = keys.pick_random()
	
	var def = directives[current_directive_id]
	var obj = ObjectiveData.new()
	obj.objective_id = def.id
	obj.title_key = def.title
	
	var task = TaskData.new()
	task.task_id = def.task_id
	task.description_key = def.task_desc + get_progress_string(current_directive_id)
	obj.tasks.append(task)
	
	print("CorporateObjectivesManager: Issuing Directive [%s]: %s" % [def.title, task.description_key])
	if Game.objectives:
		Game.objectives.add_objective(obj)

func get_progress_string(obj_id: String) -> String:
	match obj_id:
		"CORP_01":
			return " (Progress: %d/3)" % approach_count
		"CORP_02":
			return " (Current: %d)" % refuse_count
		"CORP_03":
			return " (Progress: %d/3)" % vocalize_count
		"CORP_04":
			return " (Progress: %d/2)" % retreat_count
		"CORP_05":
			return " (Progress: %d/2)" % mirror_count
		"CORP_06":
			var energy = SpecimenBridge.profile.energy if SpecimenBridge.profile else 0.0
			return " (Current: %.1f)" % energy
		"CORP_07":
			return " (Progress: %d/4)" % conditioning_count
		"CORP_08":
			return " (Progress: %d/2)" % play_count
		"CORP_09":
			var heat = EnvironmentBridge.profile.heat if EnvironmentBridge.profile else 0.0
			return " (Current: %.1fC)" % heat
		"CORP_10":
			return " (Current: %d)" % sleep_early_count
		_:
			return ""

func get_active_session_objective() -> ObjectiveData:
	if not Game.session:
		return null
	for obj in Game.session.active_objectives:
		if obj.objective_id == current_directive_id:
			return obj
	return null

func update_progress_in_session() -> void:
	var obj = get_active_session_objective()
	if not obj or obj.tasks.is_empty():
		return
		
	var task = obj.tasks[0]
	var def = directives[current_directive_id]
	var new_desc = def.task_desc + get_progress_string(current_directive_id)
	
	if task.description_key != new_desc:
		task.description_key = new_desc
		
		# Check real-time compliance condition
		if not def.is_cycle_end and not task.is_completed:
			if def.eval_func.call(self):
				if Game.objectives:
					Game.objectives.update_task(task.task_id, true)
				return
				
		# Trigger UI refresh
		if Game.objectives:
			Game.objectives.objectives_updated.emit(Game.session.active_objectives)

func _on_specimen_action_performed(action_id: String) -> void:
	match action_id:
		"APPROACH_PLAYER":
			approach_count += 1
		"REFUSE_INTERACTION":
			refuse_count += 1
		"VOCALIZE":
			vocalize_count += 1
		"RETREAT":
			retreat_count += 1
		"MIRROR_PLAYER":
			mirror_count += 1
		"PLAY":
			play_count += 1
		"SLEEP_EARLY":
			sleep_early_count += 1
		"DISPLAY":
			pass # tracked for CORP_08 but we just check display_count
			
	# Optimize stimulation ratio also counts PLAY
	if action_id == "DISPLAY":
		# Let's count display incidents as well for pacification
		pass
		
	update_progress_in_session()

func _on_conditioning_applied(_type: String) -> void:
	conditioning_count += 1
	update_progress_in_session()

func _on_cycle_ended(cycle_num: int) -> void:
	if current_directive_id == "":
		return
		
	var def = directives.get(current_directive_id)
	if def and def.is_cycle_end:
		var obj = get_active_session_objective()
		if obj and not obj.tasks.is_empty():
			var task = obj.tasks[0]
			# Count final DISPLAY counts if evaluating CORP_08
			var display_count_cycle = 0
			# We can scan the specimen profile action log for DISPLAY occurrences in this cycle
			# But actually it's easier to track displays directly
			if current_directive_id == "CORP_08":
				# Actually CORP_08 is PLAY responses, which is real-time.
				# CORP_10 is Prevent early sleeping, which is cycle_end.
				# CORP_02 is Minimize refuse interaction, cycle_end.
				# CORP_06 is Kinetic energy preservation, cycle_end.
				# CORP_09 is thermal audit, cycle_end.
				pass
			
			# We also need display count for CORP_08 (wait, CORP_08 is PLAY responses, CORP_08 title "OPTIMIZE STIMULATION RATIO" task is "Exhibit PLAY responses at least 2 times." which is real-time. Wait, CORP_08 Title in table is OPTIMIZE STIMULATION RATIO, task PLAY responses >= 2.)
			# What about CORP_08 "Specimen Pacification Protocol" which was CORP_08 in plan A but CORP_08 in plan B is PLAY responses, and CORP_08 "Specimen Pacification Protocol" is CORP_08 in table?
			# Let's check:
			# CORP_08 is "OPTIMIZE STIMULATION RATIO" - PLAY responses >= 2. (Real-time)
			# CORP_09 is "CHAMBER THERMAL AUDIT" - Heat 30-36 at cycle end. (Cycle end)
			# CORP_10 is "SHIFT DUTY MAXIMIZATION" - 0 SLEEP_EARLY actions. (Cycle end)
			# Oh, wait! Where is the "DISPLAY" count objective?
			# Wait! In Plan B:
			# CORP_08 is OPTIMIZE STIMULATION RATIO (PLAY responses at least 2 times).
			# Wait, where is the "Specimen Pacification Protocol" (DISPLAY behaviors == 0)?
			# Oh! In the Plan B table, there is no "DISPLAY behaviors == 0". Wait, let's look at Plan B directives again:
			# Directive 10: "SHIFT DUTY MAXIMIZATION: Prevent early sleeping behaviors (0 SLEEP_EARLY actions)."
			# Directive 8: "OPTIMIZE STIMULATION RATIO: Exhibit PLAY responses at least 2 times."
			# Oh! Wait, did Plan B have 10 directives?
			# Yes:
			# 1. Proximity Stimulation: APPROACH_PLAYER >= 3
			# 2. Compliance Enforcement: REFUSE_INTERACTION <= 1
			# 3. Acoustic Profile Harvesting: VOCALIZE >= 3
			# 4. Escape Profile Mapping: RETREAT >= 2
			# 5. Behavioral Syncing: MIRROR_PLAYER >= 2
			# 6. Kinetic Resource Preservation: Energy > 4.0 at cycle end
			# 7. Active Conditioning Trial: REINFORCE/PUNISH/SHOCK/PET >= 4
			# 8. Optimize Stimulation Ratio: PLAY >= 2
			# 9. Chamber Thermal Audit: Heat 30-36 at cycle end
			# 10. Shift Duty Maximization: 0 SLEEP_EARLY
			# Oh, I see! Plan B replaced "Specimen Pacification Protocol" (which was in Plan A) with "Escape Profile Mapping" (RETREAT >= 2).
			# That's why there is no DISPLAY behaviors == 0 objective in Plan B.
			# But wait, did I list display_count? Yes, I added it, but since it is not used in the 10 directives of Plan B, we don't need display_count!
			# That is perfect. So the 10 directives in our dictionary are EXACTLY those of Plan B. Let's make sure our cycle end evaluation code matches this.
			
			if def.eval_func.call(self):
				print("CorporateObjectivesManager: Directive [%s] compliance ACHIEVED." % def.title)
				if Game.objectives:
					Game.objectives.update_task(task.task_id, true)
			else:
				print("CorporateObjectivesManager: Directive [%s] compliance FAILED. Specimen autonomy preserved." % def.title)
				# Clean up the failed objective
				cleanup_corporate_objectives()

func _on_objective_completed(objective: ObjectiveData) -> void:
	if objective.objective_id.begins_with("CORP_"):
		var def = directives.get(objective.objective_id)
		if def:
			var profile = SpecimenBridge.profile
			if profile:
				print("CorporateObjectivesManager: Compliance rewarded. Applying corporate shifts: ", def.deltas)
				for var_name in def.deltas:
					profile.apply_delta(var_name, def.deltas[var_name])
				
				# Log narrative/clinical feedback
				print("CorporateObjectivesManager: Feedback logged to supervisor database.")
