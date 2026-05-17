extends Control

@export var item_ui_scene: PackedScene

@onready var item_container: VBoxContainer = %ItemContainer

func _ready() -> void:
	if Game.inventory:
		Game.inventory.inventory_updated.connect(_on_inventory_updated)
	
	# Clear placeholder children
	for child in item_container.get_children():
		child.queue_free()
	
	_on_inventory_updated()

func _on_inventory_updated() -> void:
	# Clear existing
	for child in item_container.get_children():
		child.queue_free()
	
	var items = Game.inventory.get_items()
	
	# Visibility: if there are no items it should disappear, if there are any items, it should appear
	visible = not items.is_empty()
	
	for item in items:
		if not item_ui_scene: continue
		var inst = item_ui_scene.instantiate()
		item_container.add_child(inst)
		if inst.has_method("setup"):
			inst.setup(item)
