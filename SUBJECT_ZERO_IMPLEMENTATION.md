# Subject Zero — Phase 1 Core Systems Implementation Plan

Implements the specimen behavioral variable system, action pool, interaction UI, conditioning mechanics, and cycle structure. This is the foundational layer everything else runs on. Build this before any character art or Phase 2 content.

---

## Proposed Changes

---

### [globals] SpecimenProfile Resource

**File:** `res://resources/specimen_profile.gd`

The mutable runtime state of the specimen. Fresh instance created at run start. Passed everywhere via a thin Autoload bridge. Never saved to disk as a shared `.tres` — instantiated in code only.

```gdscript
class_name SpecimenProfile
extends Resource

# --- Primary Variables ---
var neural_plasticity: float   # rolled at run start, randf_range(20.0, 80.0)
var threat_indexing: float = 0.0
var reward_schema: float = 0.0
var identity_coherence: float = 50.0
var resonance_frequency: float = 0.0

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

# --- Audit Flags ---
var audit_1_complete: bool = false
var audit_2_cycles: int = 0
var audit_3_results: Array = []
var audit_4_complete: bool = false
var audit_5_complete: bool = false

# --- Ruthlessness Accumulator ---
# increments on PUNISH, decrements on REINFORCE, clamps 0-100
var ruthlessness: float = 0.0

# --- Init ---
func initialize(plasticity_roll: float) -> void:
    neural_plasticity = plasticity_roll

# --- Variable Delta ---
func apply_delta(variable: String, delta: float) -> void:
    match variable:
        "neural_plasticity":
            neural_plasticity = clamp(neural_plasticity + delta, 0.0, 100.0)
        "threat_indexing":
            threat_indexing = clamp(threat_indexing + delta, 0.0, 100.0)
        "reward_schema":
            reward_schema = clamp(reward_schema + delta, -50.0, 50.0)
        "identity_coherence":
            identity_coherence = clamp(identity_coherence + delta, 0.0, 100.0)
        "resonance_frequency":
            resonance_frequency = clamp(resonance_frequency + delta, 0.0, 100.0)

# --- Action Weight ---
func apply_action_weight(action_id: String, delta: float) -> void:
    if not action_pool.has(action_id):
        return
    action_pool[action_id] = max(action_pool[action_id] + delta, 1.0)  # floor 1.0

# --- Action Log ---
func log_action(action_id: String) -> void:
    action_log.push_front(action_id)
    if action_log.size() > 3:
        action_log.pop_back()

# --- Activity Rate ---
# Total weight sum drives actions per minute
func get_total_weight() -> float:
    var total = 0.0
    for w in action_pool.values():
        total += w
    return total

# --- Ending Determination ---
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
```

---

### [globals] SpecimenBridge Autoload

**File:** `res://autoloads/specimen_bridge.gd`

Thin bridge per Manifesto rule 33. Holds reference to current profile. Does not own state. Profile lives and dies with the run.

```gdscript
# specimen_bridge.gd
extends Node

var profile: SpecimenProfile = null

func start_run() -> void:
    profile = SpecimenProfile.new()
    profile.initialize(randf_range(20.0, 80.0))

func end_run() -> void:
    profile = null
```

Register in Project Settings → Autoloads as `SpecimenBridge`.

Access anywhere: `SpecimenBridge.profile.apply_delta("threat_indexing", 5.0)`

---

### [globals] Action Definitions Resource

**File:** `res://resources/action_definitions.gd`

Maps action IDs to their primary and secondary variable targets. Single source of truth.

```gdscript
class_name ActionDefinitions
extends Resource

# action_id : { primary, secondary, secondary_weight }
const ACTIONS = {
    "APPROACH_PLAYER":    { "primary": "resonance_frequency",  "secondary": "threat_indexing",    "sw": 0.5 },
    "RETREAT":            { "primary": "threat_indexing",      "secondary": "reward_schema",       "sw": 0.5 },
    "VOCALIZE":           { "primary": "identity_coherence",   "secondary": "",                    "sw": 0.0 },
    "INVESTIGATE":        { "primary": "neural_plasticity",    "secondary": "",                    "sw": 0.0 },
    "DISPLAY":            { "primary": "threat_indexing",      "secondary": "identity_coherence",  "sw": 0.5 },
    "PLAY":               { "primary": "identity_coherence",   "secondary": "resonance_frequency", "sw": 0.5 },
    "WASTE_BEHAVIOR":     { "primary": "reward_schema",        "secondary": "",                    "sw": 0.0 },
    "SLEEP_EARLY":        { "primary": "reward_schema",        "secondary": "neural_plasticity",   "sw": 0.3 },
    "MIRROR_PLAYER":      { "primary": "resonance_frequency",  "secondary": "identity_coherence",  "sw": 0.5 },
    "REFUSE_INTERACTION": { "primary": "identity_coherence",   "secondary": "threat_indexing",     "sw": 0.5 },
}
```

---

### [specimen] Action Selection System

**File:** `res://specimen/specimen_controller.gd`

Drives specimen behavior. Polls action pool at intervals derived from total weight. Logs each action to profile. Emits signal upward — never calls UI directly.

```gdscript
class_name SpecimenController
extends Node

signal action_performed(action_id: String)

# Timer drives action frequency
@onready var action_timer: Timer = $ActionTimer

func _ready() -> void:
    action_timer.timeout.connect(_on_action_timer_timeout)
    _update_action_rate()

# Recalculate interval when total weight changes
func _update_action_rate() -> void:
    var profile = SpecimenBridge.profile
    if not profile:
        return
    # Higher total weight = more frequent actions
    # Tune these constants during playtesting
    var base_interval = 8.0
    var min_interval = 2.0
    var normalized = profile.get_total_weight() / 100.0  # 100 = baseline
    action_timer.wait_time = max(base_interval / normalized, min_interval)

func _on_action_timer_timeout() -> void:
    var action_id = _select_action()
    SpecimenBridge.profile.log_action(action_id)
    action_performed.emit(action_id)
    _update_action_rate()

# Weighted random selection
func _select_action() -> String:
    var profile = SpecimenBridge.profile
    var pool = profile.action_pool
    var total = profile.get_total_weight()
    var roll = randf() * total
    var cumulative = 0.0
    for action_id in pool:
        cumulative += pool[action_id]
        if roll <= cumulative:
            return action_id
    return pool.keys().back()
```

---

### [conditioning] Reinforcement System

**File:** `res://conditioning/reinforcement_system.gd`

Applies recency-weighted deltas to action pool and variables when player reinforces or punishes. Receives the current action log from profile. Never touches UI.

```gdscript
class_name ReinforcementSystem
extends Node

# Recency weights for log positions [most recent, second, third]
const RECENCY_WEIGHTS = [10.0, 5.0, 2.0]
const RUTHLESSNESS_DELTA = 5.0

func reinforce() -> void:
    _apply_conditioning(1.0)
    SpecimenBridge.profile.ruthlessness = max(
        SpecimenBridge.profile.ruthlessness - RUTHLESSNESS_DELTA, 0.0
    )

func punish() -> void:
    _apply_conditioning(-1.0)
    SpecimenBridge.profile.ruthlessness = min(
        SpecimenBridge.profile.ruthlessness + RUTHLESSNESS_DELTA, 100.0
    )

func _apply_conditioning(direction: float) -> void:
    var profile = SpecimenBridge.profile
    var log = profile.action_log

    for i in range(log.size()):
        var action_id = log[i]
        var weight_delta = RECENCY_WEIGHTS[i] * direction

        # Apply to action pool weight
        profile.apply_action_weight(action_id, weight_delta)

        # Apply to primary variable
        var action_def = ActionDefinitions.ACTIONS[action_id]
        var primary = action_def["primary"]
        var variable_delta = (weight_delta * 0.1)  # tune during playtesting
        profile.apply_delta(primary, variable_delta)

        # Apply to secondary variable if present
        if action_def["secondary"] != "":
            profile.apply_delta(
                action_def["secondary"],
                variable_delta * action_def["sw"]
            )
```

---

### [conditioning] Neglect Decay System

**File:** `res://conditioning/neglect_decay.gd`

Runs once per cycle end. Decays unaddressed action weights toward 1.0. Neglect is mechanical — it never announces itself.

```gdscript
class_name NeglectDecay
extends Node

const DECAY_RATE = 0.5      # per cycle per unaddressed action
const WEIGHT_FLOOR = 1.0

# Call this at cycle end before lights out
func apply_cycle_decay(addressed_actions: Array) -> void:
    var profile = SpecimenBridge.profile
    for action_id in profile.action_pool:
        if action_id not in addressed_actions:
            var current = profile.action_pool[action_id]
            profile.action_pool[action_id] = max(
                current - DECAY_RATE, WEIGHT_FLOOR
            )
```

`addressed_actions` is built by the interaction system — every action the player responded to during the cycle. Anything not in that array decays.

---

### [UI] Interaction Radial Menu

**File:** `res://ui/interaction_radial.gd`

Shows 3-action log. Presents REINFORCE/PUNISH/IGNORE. Button labels shift based on ruthlessness. Emits signals upward — never calls reinforcement system directly.

```gdscript
class_name InteractionRadial
extends Control

signal reinforce_requested
signal punish_requested
signal ignored  # player closed without acting

# Label sets by ruthlessness tier
# ruthlessness 0-33: neutral, 34-66: cold, 67-100: cruel
const REINFORCE_LABELS = ["REINFORCE", "REWARD", "GRANT RELIEF"]
const PUNISH_LABELS    = ["PUNISH", "CORRECT", "IMPOSE CONSEQUENCE"]

@onready var log_entries: Array = [$LogEntry0, $LogEntry1, $LogEntry2]
@onready var reinforce_btn: Button = $ReinforceButton
@onready var punish_btn: Button = $PunishButton

func open_menu() -> void:
    _refresh_log()
    _refresh_labels()
    visible = true

func close_menu() -> void:
    visible = false
    ignored.emit()

func _refresh_log() -> void:
    var log = SpecimenBridge.profile.action_log
    for i in range(log_entries.size()):
        if i < log.size():
            log_entries[i].text = log[i]
            log_entries[i].visible = true
        else:
            log_entries[i].visible = false

func _refresh_labels() -> void:
    var r = SpecimenBridge.profile.ruthlessness
    var tier = 0
    if r >= 67.0:
        tier = 2
    elif r >= 34.0:
        tier = 1
    reinforce_btn.text = REINFORCE_LABELS[tier]
    punish_btn.text = PUNISH_LABELS[tier]

func _on_reinforce_pressed() -> void:
    reinforce_requested.emit()
    close_menu()

func _on_punish_pressed() -> void:
    punish_requested.emit()
    close_menu()
```

> [!IMPORTANT]
> The label shift is never explained to the player. Do not add tooltips or tutorial text around this. The realization should be gradual and self-generated.

---

### [cycle] Cycle Manager

**File:** `res://cycle/cycle_manager.gd`

Owns the AP pool and lights-out logic. Orchestrates cycle start/end. Connects subsystems — nothing connects itself per Manifesto rule 11.

```gdscript
class_name CycleManager
extends Node

signal cycle_started(cycle_number: int)
signal cycle_ended(cycle_number: int)
signal action_points_changed(remaining: int)
signal lights_out

const MAX_AP = 10              # tune during playtesting
const INDIVIDUATION_START = 9
const INDIVIDUATION_END = 13

var current_ap: int = MAX_AP
var addressed_actions: Array = []

@onready var neglect_decay: NeglectDecay = $NeglectDecay
@onready var reinforcement: ReinforcementSystem = $ReinforcementSystem
@onready var radial: InteractionRadial = $InteractionRadial

func _ready() -> void:
    radial.reinforce_requested.connect(_on_reinforce)
    radial.punish_requested.connect(_on_punish)
    radial.ignored.connect(_on_ignored)

func start_cycle() -> void:
    current_ap = MAX_AP
    addressed_actions.clear()
    cycle_started.emit(SpecimenBridge.profile.current_cycle)
    action_points_changed.emit(current_ap)

func spend_ap(amount: int = 1) -> bool:
    if current_ap <= 0:
        return false
    current_ap -= amount
    action_points_changed.emit(current_ap)
    if current_ap <= 0:
        end_cycle()
    return true

func end_cycle() -> void:
    neglect_decay.apply_cycle_decay(addressed_actions)
    _apply_individuation_window()
    lights_out.emit()
    cycle_ended.emit(SpecimenBridge.profile.current_cycle)
    SpecimenBridge.profile.current_cycle += 1

func _on_reinforce() -> void:
    if not spend_ap():
        return
    var last = SpecimenBridge.profile.action_log
    if last.size() > 0:
        addressed_actions.append(last[0])
    reinforcement.reinforce()

func _on_punish() -> void:
    if not spend_ap():
        return
    var last = SpecimenBridge.profile.action_log
    if last.size() > 0:
        addressed_actions.append(last[0])
    reinforcement.punish()

func _on_ignored() -> void:
    pass  # no AP spent, no action addressed, decay will apply

# Individuation window: cycles 9-13
# She attempts to find her voice here
# REFUSE_INTERACTION gets a passive weight boost if IDENTITY_COHERENCE is developing
func _apply_individuation_window() -> void:
    var cycle = SpecimenBridge.profile.current_cycle
    if cycle < INDIVIDUATION_START or cycle > INDIVIDUATION_END:
        return
    var profile = SpecimenBridge.profile
    if profile.identity_coherence >= 34.0:
        # She is reaching for a self — passive assertion emerges
        profile.apply_action_weight("REFUSE_INTERACTION", 2.0)
        profile.apply_action_weight("VOCALIZE", 1.5)
```

---

### [cycle] Developmental Window Reference

No code required. Reference for tuning and writing decisions.

| Cycles | Window | What happens |
|---|---|---|
| 1–4 | Neonatal | Pure stimulus response. All actions near baseline weight. |
| 5–8 | Imprinting | `RESONANCE_FREQUENCY` most volatile. Attachment patterns begin. |
| 9–13 | Individuation | She reaches for a self. `REFUSE_INTERACTION` and `VOCALIZE` get passive boosts if `IDENTITY_COHERENCE` ≥ 34. **Most critical window.** |
| 14–17 | Crystallisation | Variable delta multipliers reduce by 30%. Changes are expensive now. |
| 18–20 | Pre-metamorphosis | Audit 5. Translation sequence. Phase 2 trigger. |

> [!WARNING]
> The individuation window boost to REFUSE_INTERACTION is the mechanic players will most instinctively suppress. This is intentional. Never tell the player what suppressing it costs.

---

### [behavioral_tells] Phase 1 Observable Feedback

**File:** `res://specimen/behavioral_tells.gd`

Drives all observable Phase 1 feedback without character models. Reads profile each cycle. No hidden variables are surfaced directly.

```gdscript
class_name BehavioralTells
extends Node

@export var external_containment_light: OmniLight3D  # flag per Manifesto rule 12
@export var external_activity_pulse: AnimationPlayer
@export var external_audio_player: AudioStreamPlayer

func update_tells() -> void:
    var profile = SpecimenBridge.profile
    _update_lighting(profile)
    _update_pulse(profile)
    _update_audio(profile)

# REWARD_SCHEMA drives cell color temperature
# Positive: warm amber. Negative: cold blue-white. Neutral: clinical white.
func _update_lighting(profile: SpecimenProfile) -> void:
    var t = (profile.reward_schema + 50.0) / 100.0  # normalize 0-1
    var warm = Color(1.0, 0.75, 0.4)
    var cold = Color(0.7, 0.85, 1.0)
    external_containment_light.light_color = cold.lerp(warm, t)

# THREAT_INDEXING drives pulse rate
# High: fast pulse synchronized with player movement
# Low: slow, irregular
func _update_pulse(profile: SpecimenProfile) -> void:
    var speed = lerp(0.3, 2.0, profile.threat_indexing / 100.0)
    external_activity_pulse.speed_scale = speed

# IDENTITY_COHERENCE drives vocalization consistency
# High: recognizable pattern. Low: fragments, interruptions.
func _update_audio(profile: SpecimenProfile) -> void:
    # Implementation depends on audio system
    # Pass coherence value to audio bus effect or vocalization sequencer
    pass
```

> [!IMPORTANT]
> Build these tells before commissioning character art. If they produce a legible behavioral portrait after 10 cycles with zero character models, the variable system is working. If they don't, fix the system first.

---

### [run] Run Initializer

**File:** `res://run/run_initializer.gd`

Creates the profile, shows the plasticity reveal, starts cycle 1. One job.

```gdscript
class_name RunInitializer
extends Node

signal run_ready

@onready var cycle_manager: CycleManager = $CycleManager

func begin_run() -> void:
    SpecimenBridge.start_run()
    var plasticity = SpecimenBridge.profile.neural_plasticity
    # Show plasticity value to player — just the number, no explanation
    # UI implementation separate
    _show_plasticity_reveal(plasticity)

func _show_plasticity_reveal(value: float) -> void:
    # Display: "NEURAL PLASTICITY INDEX: [value]"
    # No tooltip. No explanation. Just the number.
    # await player acknowledgement
    run_ready.emit()
    cycle_manager.start_cycle()

func end_run() -> void:
    SpecimenBridge.end_run()
```

---

## Edge Case & Integration Notes

> [!WARNING]
> `SpecimenBridge.profile` can be null before `start_run()` is called. Every system that accesses it must guard: `if not SpecimenBridge.profile: return`. Add this check to `_ready()` in any node that reads from the profile.

> [!WARNING]
> The crystallisation window (cycles 14–17) requires a delta multiplier reduction of ~30% on all `apply_delta` calls. Implement as a modifier in `SpecimenProfile.apply_delta()` that checks `current_cycle` before applying. Do not scatter this logic across systems.

> [!IMPORTANT]
> `determine_ending()` should only be called once — at Audit 5. Do not poll it during Phase 1. Calling it mid-run for debugging is fine but leave a `# DEBUG` comment so it gets removed.

> [!IMPORTANT]
> The ruthlessness accumulator drives UI label shifts only. It does not directly write to any behavioral variable. If you find yourself wanting to connect it to the variable system, stop — that's a different mechanic and needs its own design pass.

> [!WARNING]
> Individuation window passive boosts to `REFUSE_INTERACTION` stack across cycles 9–13. Cap the total boost at +15.0 across the window or the action becomes dominant by cycle 13 regardless of player input. That removes player agency in the most critical window.

> [!IMPORTANT]
> All signal names follow Manifesto rule 47: past tense. `cycle_ended`, `action_performed`, `reinforce_requested`. Handler methods prefixed `_on_`. Do not name signals as commands.

---

## Build Order

1. `SpecimenProfile` resource — no dependencies
2. `SpecimenBridge` autoload — depends on profile
3. `ActionDefinitions` resource — no dependencies
4. `ReinforcementSystem` — depends on profile + definitions
5. `NeglectDecay` — depends on profile
6. `SpecimenController` — depends on profile + timer
7. `CycleManager` — connects all conditioning systems
8. `BehavioralTells` — depends on profile, no other systems
9. `InteractionRadial` — depends on profile for log + ruthlessness
10. `RunInitializer` — depends on everything above

**Milestone after step 8:** Run 10 cycles using only keyboard input to manually fire actions. Do the behavioral tells produce a legible portrait? If yes, continue. If no, fix the variable system before touching UI.
