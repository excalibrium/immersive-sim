extends Node
class_name SignalTaskCompleter

## Generic Glue Layer component.
## Listens to a specific signal on a target node to complete a task.

const COMMON_SIGNALS = ["state_changed", "collected", "interacted", "body_entered"]

@export var target_node: Node
@export_enum("state_changed", "collected", "interacted", "body_entered", "CUSTOM") var signal_type: int = 0
@export var custom_signal: String = ""
@export var task_data: TaskData

func _ready():
	if not target_node:
		push_error("SignalTaskCompleter: No target_node assigned on ", name)
		return
		
	if not task_data:
		push_error("SignalTaskCompleter: No task_data resource assigned on ", name)
		return

	# Resolve signal name
	var signal_name = ""
	if signal_type < COMMON_SIGNALS.size():
		signal_name = COMMON_SIGNALS[signal_type]
	else:
		signal_name = custom_signal

	if signal_name == "":
		push_error("SignalTaskCompleter: No signal name resolved on ", name)
		return

	# (Rule 27 & Validation): Verify the duck-typed signal exists to prevent silent failure.
	if not target_node.has_signal(signal_name):
		push_error("SignalTaskCompleter: Node '%s' has no signal '%s'" % [target_node.name, signal_name])
		return

	target_node.connect(signal_name, _on_signal_emitted)

func _on_signal_emitted(_arg1 = null, _arg2 = null, _arg3 = null):
	# Using optional arguments to support signals with 0-3 parameters.
	if task_data and Game.objectives:
		Game.objectives.update_task(task_data.task_id, true)
