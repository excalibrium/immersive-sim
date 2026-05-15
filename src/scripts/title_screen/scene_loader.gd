extends Node

## A simple scene loader with basic transition support.
## Can be used as an Autoload (Singleton) in Godot.

signal loading_started(path: String)
signal loading_finished(path: String)

func load_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneLoader: Scene path does not exist: %s" % path)
		return
		
	emit_signal("loading_started", path)
	
	# Simple blocking load for portability
	get_tree().change_scene_to_file(path)
	
	emit_signal("loading_finished", path)
