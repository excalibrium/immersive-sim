extends Node
class_name SpecimenState

signal finished(transition_key: String)

# Reference to the state machine
var state_machine: SpecimenStateMachine = null

# Reference to the main specimen actor
var specimen: Specimen = null

# The Action handled by this state
@export var action_type: SpecimenStateMachine.Action

# Whether this state automatically rotates visuals toward movement direction
var auto_rotate_visuals: bool = true

func enter(_context: SpecimenStateMachine.StateContext) -> void:
	pass

func exit() -> void:
	pass

func update(_context: SpecimenStateMachine.StateContext, _delta: float) -> void:
	pass

func physics_update(_context: SpecimenStateMachine.StateContext, _delta: float) -> void:
	pass

func handle_navigation_finished(_context: SpecimenStateMachine.StateContext) -> void:
	pass

func handle_tracking_timeout(_context: SpecimenStateMachine.StateContext) -> void:
	pass
