extends Resource
class_name ActionDefinitions

## Single source of truth for specimen action-to-variable mappings.
## Each action targets a primary variable and optionally a secondary variable
## with a secondary weight multiplier.

# action_id : { primary, secondary, sw (secondary weight) }
const ACTIONS: Dictionary = {
	"APPROACH_PLAYER":    { "primary": "resonance_frequency",  "secondary": "threat_indexing",     "sw": 0.5 },
	"RETREAT":            { "primary": "threat_indexing",      "secondary": "reward_schema",       "sw": 0.5 },
	"VOCALIZE":           { "primary": "identity_coherence",   "secondary": "reward_schema",       "sw": 0.0 },
	"INVESTIGATE":        { "primary": "neural_plasticity",    "secondary": "reward_schema",       "sw": 0.0 },
	"DISPLAY":            { "primary": "threat_indexing",      "secondary": "identity_coherence",  "sw": 0.5 },
	"PLAY":               { "primary": "identity_coherence",   "secondary": "resonance_frequency", "sw": 0.5 },
	"WASTE_BEHAVIOR":     { "primary": "reward_schema",        "secondary": "reward_schema",       "sw": 0.0 },
	"SLEEP_EARLY":        { "primary": "reward_schema",        "secondary": "neural_plasticity",   "sw": 0.3 },
	"MIRROR_PLAYER":      { "primary": "resonance_frequency",  "secondary": "identity_coherence",  "sw": 0.5 },
	"REFUSE_INTERACTION": { "primary": "identity_coherence",   "secondary": "threat_indexing",     "sw": 0.5 },
}
