extends Node

## Manages UI states and mouse modes.
## Uses a stack to handle overlapping UI elements correctly.

enum MouseState { CAPTURED, VISIBLE }

signal mouse_state_changed(state: MouseState)

var _state_stack: Array[MouseState] = []

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	# Initial state
	push_mouse_state(MouseState.VISIBLE)

func push_mouse_state(state: MouseState):
	_state_stack.push_back(state)
	_apply_state()

func pop_mouse_state():
	if _state_stack.size() > 1:
		_state_stack.pop_back()
		_apply_state()

func reset_to_state(state: MouseState):
	_state_stack.clear()
	push_mouse_state(state)

func _apply_state():
	var current_state = _state_stack.back()
	
	match current_state:
		MouseState.CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		MouseState.VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
	mouse_state_changed.emit(current_state)

func is_mouse_captured() -> bool:
	return _state_stack.back() == MouseState.CAPTURED
