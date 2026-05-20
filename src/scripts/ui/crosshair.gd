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

func setup(interactor: PlayerInteractor):
	_interactor = interactor
	_interactor.target_state_changed.connect(_on_target_state_changed)

func _on_mouse_state_changed(_state):
	_update_visibility()

func _update_visibility():
	visible = WindowManager.is_mouse_captured()

func _process(_delta: float):
	if not _interactor or not _interactor.current_target:
		if label:
			label.text = ""
		return
		
	var target = _interactor.current_target
	var pickupable = _find_pickupable(target)
	
	if label:
		if pickupable:
			var mass = pickupable.body.mass if pickupable.body else 0.0
			var player_node = _interactor.get_parent()
			var strength = 50.0
			
			if player_node and "player_strength" in player_node:
				if player_node.has_method("get_lift_strength"):
					strength = player_node.get_lift_strength()
				else:
					strength = 50.0 * player_node.player_strength
					
			if mass <= strength:
				label.text = "Hold [LMB] to Carry\nWeight: %.1f kg" % mass
			else:
				label.text = "[TOO HEAVY]\nWeight: %.1f kg" % mass
		else:
			# Format standard interact text nicely
			var key = target.interact_text_key
			var clean_text = ""
			match key:
				"INTERACT_DOOR_USE": clean_text = "Press [E] to Open Door"
				"INTERACT_DOOR_UNLOCK": clean_text = "Press [E] to Unlock Door"
				"INTERACT_PRESS_BUTTON": clean_text = "Press [E] to Activate Button"
				"INTERACT_USE": clean_text = "Press [E] to Use"
				_:
					# Fallback format: "INTERACT_SOMETHING_COOL" -> "Something Cool"
					var stripped = key.replace("INTERACT_", "").replace("_", " ")
					clean_text = "Press [E] to " + stripped.capitalize()
			label.text = clean_text

func _on_target_state_changed(state: int):
	match state:
		0: # NONE
			texture = default_texture
		1: # INTERACTABLE
			texture = interactable_texture
		2: # DENIED
			texture = denied_texture

func _find_pickupable(node: Node) -> Pickupable:
	if not node: return null
	if node is Pickupable:
		return node
	for child in node.get_children():
		if child is Pickupable:
			return child
			
	var parent = node.get_parent()
	if not parent: return null
	
	for child in parent.get_children():
		if child is Pickupable:
			return child
	return null
