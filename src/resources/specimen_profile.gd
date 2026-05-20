extends Resource
class_name SpecimenProfile

## Biological runtime state of the specimen.
## Instantiated dynamically during a run and managed via SpecimenBridge.
## Never saved to disk as a shared .tres — instantiated in code only.

enum Phase {
	EGG,
	CHILD,
	ADULT
}

@export var phase: Phase = Phase.EGG

# --- Primary Variables ---
@export var neural_plasticity: float = 0.0
@export var threat_indexing: float = 0.0
@export var reward_schema: float = 0.0
@export var identity_coherence: float = 50.0
@export var resonance_frequency: float = 0.0

# --- Cycle Tracking ---
var current_cycle: int = 1
var current_phase: int = 1

# --- Action Pool ---
# Dictionary of action_id : weight (float, floor 1.0)
var action_pool: Dictionary = {
	"APPROACH_PLAYER":    10.0,
	"RETREAT":            10.0,
	"VOCALIZE":           10.0,
	"INVESTIGATE":        10.0,
	"DISPLAY":            10.0,
	"PLAY":               10.0,
	"WASTE_BEHAVIOR":     10.0,
	"SLEEP_EARLY":        10.0,
	"MIRROR_PLAYER":      10.0,
	"REFUSE_INTERACTION": 10.0,
}

# --- Action Log (last 3) ---
var action_log: Array = []  # max 3 entries, most recent first

# --- Ruthlessness Accumulator ---
# Increments on PUNISH, decrements on REINFORCE, clamps 0-100.
# Drives UI label shifts only — does not directly write to behavioral variables.
var ruthlessness: float = 0.0

## Initializes the profile with run-start plasticity.
func initialize(plasticity_roll: float) -> void:
	neural_plasticity = plasticity_roll

## Applies delta changes with strict bounding limits.
## Crystallisation window (cycles 14-17) reduces deltas by 30%.
func apply_delta(variable: String, delta: float) -> void:
	var effective_delta = delta
	if current_cycle >= 14 and current_cycle <= 17:
		effective_delta *= 0.7
	
	match variable:
		"neural_plasticity":
			neural_plasticity = clamp(neural_plasticity + effective_delta, 0.0, 100.0)
		"threat_indexing":
			threat_indexing = clamp(threat_indexing + effective_delta, 0.0, 100.0)
		"reward_schema":
			reward_schema = clamp(reward_schema + effective_delta, -50.0, 50.0)
		"identity_coherence":
			identity_coherence = clamp(identity_coherence + effective_delta, 0.0, 100.0)
		"resonance_frequency":
			resonance_frequency = clamp(resonance_frequency + effective_delta, 0.0, 100.0)

## Adjusts action pool weight for a given action. Floor is 1.0.
func apply_action_weight(action_id: String, delta: float) -> void:
	if not action_pool.has(action_id):
		return
	action_pool[action_id] = max(action_pool[action_id] + delta, 1.0)

## Logs an action to the recency buffer. Max 3 entries, most recent first.
func log_action(action_id: String) -> void:
	action_log.push_front(action_id)
	if action_log.size() > 3:
		action_log.pop_back()

## Total weight sum across the action pool. Drives action frequency.
func get_total_weight() -> float:
	var total = 0.0
	for w in action_pool.values():
		total += w
	return total

## Evaluates variable thresholds to determine the narrative ending.
## Should only be called once at Audit 5. Do not poll during Phase 1.
func determine_ending() -> String:
	if identity_coherence >= 98.0:
		return "Y_COHERENCE_CASCADE"
	if resonance_frequency >= 95.0:
		return "X_CONTAMINATION"
	if neural_plasticity >= 67.0 and _is_mid(threat_indexing) and _is_mid(identity_coherence):
		return "E_NULL"
	
	if threat_indexing >= 67.0 and identity_coherence >= 67.0:
		var base = "A2_TRANSACTIONAL" if reward_schema >= -17.0 else "A1_SYSTEMATIC"
		return base + ("_RESONANT" if resonance_frequency >= 67.0 else "")
	
	if threat_indexing >= 67.0 and identity_coherence < 34.0:
		return "B1_ECHO" if resonance_frequency >= 67.0 else "B2_STATIC"
	
	if threat_indexing < 34.0 and identity_coherence >= 67.0:
		return "C1_DEPARTURE" if reward_schema > 17.0 else "C2_DISPLACEMENT"
	
	if _is_mid(threat_indexing) and identity_coherence < 34.0 and resonance_frequency >= 67.0:
		return "D1_ATTACHMENT" if reward_schema > 17.0 else "D2_HOSTAGE"
	
	return "E_NULL"

func _is_mid(value: float) -> bool:
	return value >= 34.0 and value < 67.0
