extends Node
class_name ObjectiveGiver

## Component to give an objective to the player.
## Can be triggered by interaction, area entry, or code.

@export var objective: ObjectiveData
@export var interactable: Interactable
@export var give_on_ready: bool = false
@export var once_only: bool = true

var _has_given: bool = false

func _ready():
	if not interactable:
		interactable = get_parent() as Interactable
		
	if interactable:
		interactable.interacted.connect(_on_interacted)
		
	if give_on_ready:
		give_objective()

func _on_interacted(_interactor: Node):
	give_objective()

func give_objective():
	if once_only and _has_given:
		return
		
	if objective and Game.objectives:
		Game.objectives.add_objective(objective)
		_has_given = true
		print("OBJECTIVE_GIVEN: ", objective.title_key)
