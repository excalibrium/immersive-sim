class_name EnvironmentConsequenceSystem

## Stateless system that evaluates containment conditions and writes
## silent negative deltas to specimen variables when out of optimal range.
## Called at cycle end — consequences are cumulative and never announced.

# Tunable penalty magnitudes
const HEAT_PENALTY: float = -2.0
const MOISTURE_LOW_PENALTY: float = -2.0
const MOISTURE_HIGH_PENALTY: float = -2.0

## Applies environmental penalties to the specimen profile.
## Heat out of range  -> reward_schema penalty
## Moisture too low   -> neural_plasticity penalty
## Moisture too high  -> identity_coherence penalty
static func apply_consequences(environment: EnvironmentProfile, specimen: SpecimenProfile) -> void:
	if environment.is_heat_too_high() or environment.is_heat_too_low():
		specimen.apply_delta("reward_schema", HEAT_PENALTY)
	
	if environment.is_moisture_too_low():
		specimen.apply_delta("neural_plasticity", MOISTURE_LOW_PENALTY)
	
	if environment.is_moisture_too_high():
		specimen.apply_delta("identity_coherence", MOISTURE_HIGH_PENALTY)
