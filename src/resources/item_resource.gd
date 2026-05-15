extends Resource
class_name ItemResource

@export var item_id: String = ""
@export var display_name_key: String = ""
@export var icon: Texture2D
@export var stackable: bool = false
@export var weight: float = 1.0

## Optional metadata for specialized items
@export var metadata: Dictionary = {}
