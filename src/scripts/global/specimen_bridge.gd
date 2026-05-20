extends Node

## Thin autoload bridge to access the active SpecimenProfile.
## Ensures lifetime is bound to the run/level session.

var profile: SpecimenProfile = null

## Instantiates a fresh specimen profile.
func start_run() -> void:
	profile = SpecimenProfile.new()
	profile.initialize(randf_range(20.0, 80.0))

## Disposes of the active specimen profile.
func end_run() -> void:
	profile = null
