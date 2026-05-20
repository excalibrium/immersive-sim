class_name Specimen
extends CharacterBody3D

@onready var controller: SpecimenController = $SpecimenController
@onready var visuals: Node3D = $Visuals
@onready var tells: Node = $BehavioralTells

func _ready() -> void:
	controller.action_performed.connect(_on_action_performed)

func _on_action_performed(action_id: String) -> void:
	# Pass down instructions to visuals, audio, or tells based on the action
	print("Specimen performed action: ", action_id)
