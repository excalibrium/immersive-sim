extends MarginContainer

@onready var icon_rect: TextureRect = %Icon
@onready var label: Label = %Label

func setup(item: ItemResource) -> void:
	if item.icon:
		icon_rect.texture = item.icon
	
	# MACRO_CASE: label beneath in MACRO_CASE
	label.text = item.display_name_key.to_upper()
