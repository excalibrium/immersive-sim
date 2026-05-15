extends Node

## The Global Bridge.
## Provides access to managers that live within the current level.

var session: GameSession
var inventory: Node # Will be InventoryManager
var objectives: Node # Will be ObjectiveManager

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
