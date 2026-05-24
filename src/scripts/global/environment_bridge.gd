extends Node

## Thin autoload bridge to access the active EnvironmentProfile.
## Manages run initialization (including randomized initial state).

var profile: EnvironmentProfile = null

## Instantiates a fresh environment profile and randomizes values.
func start_run() -> void:
	profile = EnvironmentProfile.new()
	
	# Snapped to 5% increments for moisture, always starting "too high" (> MOISTURE_MAX_BEST)
	var initial_moisture = snapped(randf_range(EnvironmentProfile.MOISTURE_MAX_BEST + 5.0, EnvironmentProfile.MOISTURE_MAX_LIMIT), 5.0)
	# Snapped to 1°C increments for heat, always starting "too high" (> HEAT_MAX_BEST)
	var initial_heat = snapped(randf_range(EnvironmentProfile.HEAT_MAX_BEST + 1.0, EnvironmentProfile.HEAT_MAX_LIMIT), 1.0)
	
	profile.moisture = initial_moisture
	profile.heat = initial_heat

## Processes cycle-end environmental effects: passive drift and specimen consequences.
func process_cycle_end(specimen_profile: SpecimenProfile) -> void:
	if not profile:
		return
	profile.drift()
	EnvironmentConsequenceSystem.apply_consequences(profile, specimen_profile)

## Disposes of the active environment profile.
func end_run() -> void:
	profile = null
