extends Node
class_name Collectible

## Component that handles picking up an item and adding it to the inventory.
## Must be a child of or linked to an Interactable node.

signal collected

@export var item_data: ItemResource
@export var interactable: Interactable

## The node to be freed when this item is collected (usually the visual representation).
@export var visual_root: Node

func _ready():
	if not interactable:
		interactable = get_parent() as Interactable
	
	if interactable:
		interactable.interacted.connect(_on_interacted)
	else:
		push_warning("Collectible on ", get_parent().name, " has no Interactable link.")

func _on_interacted(_interactor: Node):
	if item_data and Game.inventory:
		Game.inventory.add_item(item_data)
		collected.emit()
		
		if visual_root:
			visual_root.queue_free()
