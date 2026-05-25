extends Node
class_name SpecimenStateMachine

signal state_transitioned(action: Action)

enum Action {
	APPROACH_PLAYER,
	RETREAT,
	VOCALIZE,
	INVESTIGATE,
	DISPLAY,
	PLAY,
	WASTE_BEHAVIOR,
	SLEEP_EARLY,
	MIRROR_PLAYER,
	REFUSE_INTERACTION,
	SLEEP
}

class StateContext:
	var global_position: Vector3 = Vector3.ZERO
	var player_pos: Vector3 = Vector3.ZERO
	var placed_objects: Array[Node3D] = []
	var player_start: Vector3 = Vector3.ZERO
	var specimen_start: Vector3 = Vector3.ZERO
	var sleep_tube_pos: Vector3 = Vector3.ZERO

# The active state
var current_state: SpecimenState = null

# Map of action enum to state nodes
var states: Dictionary = {}

# Reference to the specimen actor
@onready var specimen: Specimen = get_parent() as Specimen

func _ready() -> void:
	if not specimen:
		specimen = get_parent() as Specimen
		
	for child in get_children():
		if child is SpecimenState:
			child.state_machine = self
			child.specimen = specimen
			states[child.action_type] = child
			child.finished.connect(_on_state_finished.bind(child))

func transition_to(action: Action) -> void:
	if not states.has(action):
		push_error("StateMachine: state not found for action: " + str(action))
		return
		
	if current_state:
		current_state.exit()
		
	current_state = states[action]
	
	# Construct fresh context for enter
	var context = specimen.get_state_context()
	current_state.enter(context)
	state_transitioned.emit(action)

func _on_state_finished(transition_key: String, _state: SpecimenState) -> void:
	# Clean transition handling on state finished events
	if transition_key == "wake_up":
		transition_to(Action.PLAY)

static func action_to_string(action: Action) -> String:
	match action:
		Action.APPROACH_PLAYER: return "APPROACH_PLAYER"
		Action.RETREAT: return "RETREAT"
		Action.VOCALIZE: return "VOCALIZE"
		Action.INVESTIGATE: return "INVESTIGATE"
		Action.DISPLAY: return "DISPLAY"
		Action.PLAY: return "PLAY"
		Action.WASTE_BEHAVIOR: return "WASTE_BEHAVIOR"
		Action.SLEEP_EARLY: return "SLEEP_EARLY"
		Action.MIRROR_PLAYER: return "MIRROR_PLAYER"
		Action.REFUSE_INTERACTION: return "REFUSE_INTERACTION"
		Action.SLEEP: return "SLEEP"
		_: return ""

static func string_to_action(action_id: String) -> Action:
	match action_id:
		"APPROACH_PLAYER": return Action.APPROACH_PLAYER
		"RETREAT": return Action.RETREAT
		"VOCALIZE": return Action.VOCALIZE
		"INVESTIGATE": return Action.INVESTIGATE
		"DISPLAY": return Action.DISPLAY
		"PLAY": return Action.PLAY
		"WASTE_BEHAVIOR": return Action.WASTE_BEHAVIOR
		"SLEEP_EARLY": return Action.SLEEP_EARLY
		"MIRROR_PLAYER": return Action.MIRROR_PLAYER
		"REFUSE_INTERACTION": return Action.REFUSE_INTERACTION
		"SLEEP": return Action.SLEEP
		_: return Action.PLAY # Default fallback
