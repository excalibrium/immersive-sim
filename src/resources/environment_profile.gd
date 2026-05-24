extends Resource
class_name EnvironmentProfile

## Containment environment profile.
## Stores active levels of heat and moisture, with validation constraints.

# Optimal/Best target ranges
const HEAT_MIN_BEST: float = 30.0
const HEAT_MAX_BEST: float = 36.0
const MOISTURE_MIN_BEST: float = 60.0
const MOISTURE_MAX_BEST: float = 70.0

# Physical operating ranges
const HEAT_MIN_LIMIT: float = 15.0
const HEAT_MAX_LIMIT: float = 45.0
const MOISTURE_MIN_LIMIT: float = 0.0
const MOISTURE_MAX_LIMIT: float = 100.0

signal heat_changed(new_heat: float)
signal moisture_changed(new_moisture: float)

@export var heat: float = 20.0:
	set(val):
		var old = heat
		heat = clamp(val, HEAT_MIN_LIMIT, HEAT_MAX_LIMIT)
		if heat != old:
			heat_changed.emit(heat)
			emit_changed()

@export var moisture: float = 50.0:
	set(val):
		var old = moisture
		moisture = clamp(val, MOISTURE_MIN_LIMIT, MOISTURE_MAX_LIMIT)
		if moisture != old:
			moisture_changed.emit(moisture)
			emit_changed()

## Adjusts heat level and clamps to operating bounds.
func change_heat(delta: float) -> void:
	self.heat += delta

## Adjusts moisture level and clamps to operating bounds.
func change_moisture(delta: float) -> void:
	self.moisture += delta

func is_heat_too_high() -> bool:
	return heat > HEAT_MAX_BEST

func is_heat_too_low() -> bool:
	return heat < HEAT_MIN_BEST

func is_moisture_too_high() -> bool:
	return moisture > MOISTURE_MAX_BEST

func is_moisture_too_low() -> bool:
	return moisture < MOISTURE_MIN_BEST

func is_heat_optimal() -> bool:
	return heat >= HEAT_MIN_BEST and heat <= HEAT_MAX_BEST

func is_moisture_optimal() -> bool:
	return moisture >= MOISTURE_MIN_BEST and moisture <= MOISTURE_MAX_BEST

# --- Passive Drift ---
# Heat drops (cooling), moisture evaporates. Applied once per cycle end.
const DRIFT_HEAT: float = -1.0
const DRIFT_MOISTURE: float = -5.0

## Applies ambient drift. Called at cycle end by EnvironmentBridge.
func drift() -> void:
	change_heat(DRIFT_HEAT)
	change_moisture(DRIFT_MOISTURE)

