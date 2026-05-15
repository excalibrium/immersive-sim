extends Resource
class_name GameSession

## Holds all data for a single game session.
## This resource is created when a level starts and destroyed when it ends.

@export var items: Array[ItemResource] = []
@export var active_objectives: Array[ObjectiveData] = []

@export var premade_pool: Array[ObjectiveData] = []
@export var global_task_pool: Array[TaskData] = []
