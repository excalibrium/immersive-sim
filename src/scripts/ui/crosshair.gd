extends TextureRect

@export var default_texture: Texture2D
@export var interactable_texture: Texture2D
@export var denied_texture: Texture2D

func _ready():
	# Set initial texture
	texture = default_texture

func setup(interactor: PlayerInteractor):
	interactor.target_state_changed.connect(_on_target_state_changed)

func _on_target_state_changed(state: int):
	match state:
		0: # NONE
			texture = default_texture
		1: # INTERACTABLE
			texture = interactable_texture
		2: # DENIED
			texture = denied_texture
