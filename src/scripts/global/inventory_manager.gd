extends Node
class_name InventoryManager

## Inventory Manager Node.
## Stores items in the Game.session and handles basic add/remove operations.

signal item_added(item: ItemResource)
signal item_removed(item: ItemResource)
signal inventory_updated

func _ready():
	Game.inventory = self

func add_item(item: ItemResource):
	assert(Game.session != null, "Attempted to access Inventory without an active Game Session.")
	Game.session.items.append(item)
	item_added.emit(item)
	inventory_updated.emit()
	print("ITEM_ADDED: ", item.display_name_key)

func remove_item(item_id: String) -> bool:
	assert(Game.session != null, "Attempted to access Inventory without an active Game Session.")
	
	var items = Game.session.items
	for i in range(items.size()):
		if items[i].item_id == item_id:
			var removed_item = items[i]
			items.remove_at(i)
			item_removed.emit(removed_item)
			inventory_updated.emit()
			print("ITEM_REMOVED: ", item_id)
			return true
	return false

func has_item(item_id: String) -> bool:
	assert(Game.session != null, "Attempted to access Inventory without an active Game Session.")
	
	for item in Game.session.items:
		if item.item_id == item_id:
			return true
	return false

func get_items() -> Array[ItemResource]:
	if Game.session:
		return Game.session.items
	var empty: Array[ItemResource] = []
	return empty
