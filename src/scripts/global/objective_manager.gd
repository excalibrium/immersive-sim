extends Node
class_name ObjectiveManager

## Objective Manager Node.
## Handles active objectives, randomization pools, and task status in Game.session.

signal objective_added(objective: ObjectiveData)
signal objective_completed(objective: ObjectiveData)
signal task_updated(objective: ObjectiveData, task: TaskData)
signal objectives_updated(active: Array[ObjectiveData])

func _ready():
	Game.objectives = self

## Adds a random objective from the premade pool.
func add_premade_random():
	assert(Game.session != null, "Attempted to access Objectives without an active Game Session.")
	if Game.session.premade_pool.is_empty():
		push_warning("PREMADE_POOL_IS_EMPTY")
		return
	
	var random_objective = Game.session.premade_pool.pick_random().duplicate_objective()
	_add_objective(random_objective)

## Creates a new objective with a title key and N random tasks from the global pool.
func create_procedural(title_key: String, task_count: int = 2):
	assert(Game.session != null, "Attempted to access Objectives without an active Game Session.")
	if Game.session.global_task_pool.is_empty():
		push_warning("GLOBAL_TASK_POOL_IS_EMPTY")
		return
	
	var new_objective = ObjectiveData.new()
	new_objective.objective_id = "PROCEDURAL_" + str(Time.get_ticks_msec())
	new_objective.title_key = title_key
	
	var temp_pool = Game.session.global_task_pool.duplicate()
	for i in range(min(task_count, temp_pool.size())):
		var random_task = temp_pool.pick_random()
		temp_pool.erase(random_task)
		new_objective.tasks.append(random_task.duplicate_task())
	
	_add_objective(new_objective)

## Manual addition of an objective.
func add_objective(objective: ObjectiveData):
	_add_objective(objective.duplicate_objective())

func _add_objective(objective: ObjectiveData):
	assert(Game.session != null, "Attempted to access Objectives without an active Game Session.")
	Game.session.active_objectives.append(objective)
	objective_added.emit(objective)
	objectives_updated.emit(Game.session.active_objectives)
	print("OBJECTIVE_ADDED: ", objective.title_key)

## Updates a task's status by its task_id.
func update_task(task_id: String, completed: bool):
	assert(Game.session != null, "Attempted to access Objectives without an active Game Session.")
	
	var session = Game.session
	var objective_to_move: ObjectiveData = null
	
	for objective in session.active_objectives:
		for task in objective.tasks:
			if task.task_id == task_id:
				task.is_completed = completed
				task_updated.emit(objective, task)
				print("TASK_UPDATED: ", task_id, " | STATUS: ", completed)
				
				if objective.is_objective_completed():
					objective_to_move = objective
				break
		if objective_to_move:
			break
	
	if objective_to_move:
		if not objective_to_move.is_repeatable:
			session.active_objectives.erase(objective_to_move)
			session.completed_objectives.append(objective_to_move)
		
		session.credits += 10
		objective_completed.emit(objective_to_move)
		objectives_updated.emit(session.active_objectives)
		print("OBJECTIVE_COMPLETED: ", objective_to_move.title_key)
	elif not objective_to_move: # If we found the task but didn't complete objective, still emit update for UI checkboxes
		# Check if we actually found the task (this is a bit messy with the loop above)
		# Let's just always emit update if we are here and found something
		objectives_updated.emit(session.active_objectives)
		return

	if not objective_to_move:
		push_warning("TASK_ID_NOT_FOUND: " + task_id)

func get_active_objectives() -> Array[ObjectiveData]:
	if Game.session:
		return Game.session.active_objectives
	var empty: Array[ObjectiveData] = []
	return empty
