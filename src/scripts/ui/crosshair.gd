extends TextureRect

@export var default_texture: Texture2D
@export var interactable_texture: Texture2D
@export var denied_texture: Texture2D

@onready var label: Label = $InteractionLabel

var _interactor: PlayerInteractor = null

func _ready():
	texture = default_texture
	if label:
		label.text = ""
	
	WindowManager.mouse_state_changed.connect(_on_mouse_state_changed)
	_update_visibility()

func setup(interactor: PlayerInteractor) -> void:
	_interactor = interactor
	_interactor.target_state_changed.connect(_on_target_state_changed)
	_interactor.target_prompt_changed.connect(_on_target_prompt_changed)

func _on_mouse_state_changed(_state) -> void:
	_update_visibility()

func _update_visibility() -> void:
	visible = WindowManager.is_mouse_captured()

func _on_target_state_changed(state: int) -> void:
	match state:
		0: # NONE
			texture = default_texture
		1: # INTERACTABLE
			texture = interactable_texture
		2: # DENIED
			texture = denied_texture

func _on_target_prompt_changed(data: Dictionary) -> void:
	if not label:
		return
		
	if data.is_empty():
		label.text = ""
		return
		
	if data.has("prompt_text_override"):
		label.text = data["prompt_text_override"]
		return
		
	var action = data.get("action", "interact")
	var key_text = _get_action_button_text(action)
	var is_denied = data.get("is_denied", false)
	
	if action == "carry":
		var mass = data.get("details", {}).get("mass", 0.0)
		if is_denied:
			label.text = "[TOO HEAVY]\nWeight: %.1f kg" % mass
		else:
			label.text = "Hold [%s] to Carry\nWeight: %.1f kg" % [key_text, mass]
	else:
		var text_key = data.get("text_key", "INTERACT_USE")
		var clean_text = ""
		match text_key:
			"INTERACT_DOOR_USE": clean_text = "Open Door"
			"INTERACT_DOOR_UNLOCK": clean_text = "Unlock Door"
			"INTERACT_PRESS_BUTTON": clean_text = "Activate Button"
			"INTERACT_USE": clean_text = "Use"
			_:
				# Fallback format: "INTERACT_SOMETHING_COOL" -> "Something Cool"
				var stripped = text_key.replace("INTERACT_", "").replace("_", " ")
				clean_text = stripped.capitalize()
		
		label.text = "Press [%s] to %s" % [key_text, clean_text]

func _get_action_button_text(action_name: String) -> String:
	# Fallback/specific mapping for the primary carry action
	if action_name == "carry":
		action_name = "primary_action"
		
	if not InputMap.has_action(action_name):
		return "Key"
		
	var events = InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
		elif event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				_: return "Mouse " + str(event.button_index)
	return "Key"
