extends Node3D
class_name Gun

signal fired
signal ammo_changed(current: int, max_ammo: int)
signal reloaded

@export var damage: float = 15.0
@export var fire_rate: float = 0.12 # Seconds between shots
@export var max_ammo: int = 30

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle: Marker3D = $barrelholder/Muzzle
@onready var muzzle_flash_light: OmniLight3D = $barrelholder/Muzzle/MuzzleFlashLight

var current_ammo: int = max_ammo
var _fire_timer: float = 0.0

func _ready() -> void:
	current_ammo = max_ammo
	ammo_changed.emit(current_ammo, max_ammo)
	if muzzle_flash_light:
		muzzle_flash_light.visible = false

func _process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta

func can_shoot() -> bool:
	return _fire_timer <= 0.0 and current_ammo > 0

func shoot() -> bool:
	if not can_shoot():
		if current_ammo <= 0:
			reload()
		return false
	
	current_ammo -= 1
	_fire_timer = fire_rate
	
	ammo_changed.emit(current_ammo, max_ammo)
	fired.emit()
	
	# Play recoil animation
	if animation_player:
		animation_player.stop()
		animation_player.play("fire")
	
	# Muzzle flash visual
	_trigger_muzzle_flash()
	
	return true

func reload() -> void:
	# For now, instant reload
	current_ammo = max_ammo
	ammo_changed.emit(current_ammo, max_ammo)
	reloaded.emit()

func _trigger_muzzle_flash() -> void:
	if muzzle_flash_light:
		muzzle_flash_light.visible = true
		# Hide the light after 0.05 seconds (50ms)
		var timer = get_tree().create_timer(0.05)
		timer.timeout.connect(func(): muzzle_flash_light.visible = false)
