extends Control
class_name HeldItemUI

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var panel_container: PanelContainer = %PanelContainer

var _player: Player = null
var _current_tween: Tween = null

func _ready() -> void:
	# Start with EMPTY state visual
	_update_ui(null, false)

func setup(player: Player) -> void:
	_player = player
	if _player:
		# Disconnect old player if setup is called multiple times
		if _player.is_connected("held_item_changed", _on_held_item_changed):
			_player.held_item_changed.disconnect(_on_held_item_changed)
			
		_player.held_item_changed.connect(_on_held_item_changed)
		_update_ui(_player.get_held_item(), false)

func _on_held_item_changed(new_item: ItemResource) -> void:
	_update_ui(new_item, true)

func _update_ui(item: ItemResource, animate: bool) -> void:
	if not is_inside_tree():
		return
		
	if item:
		name_label.text = item.display_name_key.to_upper()
		if item.icon:
			icon_rect.texture = item.icon
			icon_rect.visible = true
		else:
			icon_rect.visible = false
	else:
		name_label.text = "EMPTY"
		icon_rect.visible = false
		
	if animate:
		_animate_transition()

func _animate_transition() -> void:
	if _current_tween:
		_current_tween.kill()
		
	_current_tween = create_tween()
	
	# Scale and fade visual feedback on selection change
	panel_container.scale = Vector2(0.92, 0.92)
	panel_container.pivot_offset = panel_container.size / 2.0
	
	# Transition scale back to 1.0 and modulate color
	_current_tween.set_parallel(true)
	_current_tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Flash the border or color of the panel with a subtle glow highlight
	panel_container.modulate = Color(1.4, 1.4, 1.4, 1.0)
	_current_tween.tween_property(panel_container, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
