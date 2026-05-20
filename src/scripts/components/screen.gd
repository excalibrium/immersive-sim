extends Node

signal state_changed(is_open: bool)

@export var interactable: Interactable
@export var screen: Control

var is_open : bool = false

func _ready():
	await get_tree().process_frame
	
	if not interactable:
		# Fallback to parent if not assigned
		interactable = get_parent() as Interactable
	
	if interactable:
		interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node):
	toggle()

func toggle():
	is_open = !is_open
	state_changed.emit(is_open)
	screen.show() if is_open else screen.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) if is_open else Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("SCREEN_TOGGLED: ", "OPEN" if is_open else "CLOSED")
