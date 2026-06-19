extends Node3D
class_name Poop

@export var meshes : Array[MeshInstance3D]

var health: float = 1.0
var is_dying: bool = false
var digest_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("poop")
	for mesh in meshes:
		mesh.hide()
	meshes.pick_random().show()
	
	# Set initial scale based on health
	_update_scale(false)
	
	# Setup digest timer to check for neighbors
	digest_timer = Timer.new()
	digest_timer.wait_time = 1.5
	digest_timer.autostart = true
	digest_timer.timeout.connect(_check_digestion)
	add_child(digest_timer)

func _check_digestion() -> void:
	if is_dying:
		return
		
	var poops = get_tree().get_nodes_in_group("poop")
	var closest_poop: Poop = null
	var closest_dist: float = 9999.0
	
	for other in poops:
		if other == self or not (other is Poop) or other.is_dying:
			continue
			
		var dist = global_position.distance_to(other.global_position)
		if dist < 3.0:
			if dist < closest_dist:
				closest_dist = dist
				closest_poop = other
				
	if closest_poop:
		var we_digest = false
		if health > closest_poop.health:
			we_digest = true
		elif health < closest_poop.health:
			we_digest = false
		else:
			# Tie-breaker using instance ID
			we_digest = self.get_instance_id() < closest_poop.get_instance_id()
			
		if we_digest:
			_digest(closest_poop)

func _digest(other: Poop) -> void:
	other.die_by_digestion()
	health += 1.0
	_update_scale(true)

func die_by_digestion() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("poop")
	if digest_timer:
		digest_timer.stop()
		
	# Bouncy scale down to zero before deletion
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func take_damage(amount: float) -> void:
	if is_dying:
		return
		
	health -= amount
	if health <= 0.0:
		die_by_damage()
	else:
		_update_scale(true)

func die_by_damage() -> void:
	if is_dying:
		return
	is_dying = true
	remove_from_group("poop")
	if digest_timer:
		digest_timer.stop()
		
	# Bouncy scale down to zero on broom sweep
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _update_scale(animate: bool) -> void:
	var target_scale = Vector3.ONE * health
	if animate:
		var tween = create_tween()
		tween.tween_property(self, "scale", target_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale = target_scale
