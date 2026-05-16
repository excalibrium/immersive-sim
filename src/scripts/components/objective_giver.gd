extends Node
class_name ObjectiveGiver

## Function Layer Component.
## Manages a list of objectives and emits them based on delivery mode.

enum DeliveryMode { SEQUENTIAL, BATCH, MANUAL }

signal objectives_ready(objectives: Array[ObjectiveData])

@export var objectives: Array[ObjectiveData]
@export var delivery_mode: DeliveryMode = DeliveryMode.SEQUENTIAL
@export var interactable: Interactable
@export var give_on_ready: bool = false
@export var once_only: bool = true

var _current_index: int = 0
var _has_given: bool = false

func _ready():
	if not interactable:
		interactable = get_parent() as Interactable
	
	if interactable:
		interactable.interacted.connect(_on_interacted)
		
	if give_on_ready:
		trigger_delivery()

func _on_interacted(_interactor: Node):
	trigger_delivery()

func trigger_delivery():
	if once_only and _has_given and delivery_mode != DeliveryMode.SEQUENTIAL:
		return
	
	match delivery_mode:
		DeliveryMode.BATCH:
			objectives_ready.emit(objectives)
			_has_given = true
		DeliveryMode.SEQUENTIAL:
			_give_next_sequential()
		DeliveryMode.MANUAL:
			# Expects external call to give_index() or similar
			pass

func _give_next_sequential():
	if _current_index < objectives.size():
		var obj = objectives[_current_index]
		objectives_ready.emit([obj] as Array[ObjectiveData])
		_current_index += 1
		if _current_index >= objectives.size():
			_has_given = true

func reset():
	_current_index = 0
	_has_given = false
