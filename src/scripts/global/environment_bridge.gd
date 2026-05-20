extends Node

## Thin autoload bridge to access the active EnvironmentProfile.
## Manages run initialization (including randomized initial state).

var profile: EnvironmentProfile = null

## Instantiates a fresh environment profile and randomizes values.
func start_run() -> void:
	profile = EnvironmentProfile.new()
	
	# Snapped to 5% increments for moisture
	var initial_moisture = snapped(randf_range(20.0, 90.0), 5.0)
	# Snapped to 1°C increments for heat
	var initial_heat = snapped(randf_range(15.0, 45.0), 1.0)
	
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
