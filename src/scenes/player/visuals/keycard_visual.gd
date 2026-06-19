extends ItemVisual

@onready var item_use_component: ItemUseComponent = $ItemUseComponent

func _ready() -> void:
	super()
	if item_use_component:
		item_use_component.item_used.connect(_on_item_used)

func _on_item_used(player: Player) -> void:
	print("KeycardVisual: Keycard swipe/present action triggered!")
