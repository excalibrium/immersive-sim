class_name LightSystem
extends Node3D

## System to control room lights, cycle transitions, and reward schema-based color shifting.

# Constants for default values
const DEFAULT_LAMP_EMISSION_MULT: float = 128.0

# References and cached base settings
var omni_lights: Array[OmniLight3D] = []
var directional_light: DirectionalLight3D = null
var lamp_material: StandardMaterial3D = null

var omni_base_energies: Dictionary = {} # OmniLight3D -> float
var dir_base_energy: float = 1.0
var lamp_base_emission_mult: float = DEFAULT_LAMP_EMISSION_MULT

# Current tween references
var energy_tween: Tween = null
var color_tween: Tween = null

func _ready() -> void:
	# 1. Discover and cache all OmniLight3D nodes in our subtree
	_find_omni_lights(self)
	for light in omni_lights:
		omni_base_energies[light] = light.light_energy
		
	# 2. Discover DirectionalLight3D in our sibling/parent path
	var parent = get_parent()
	if parent:
		directional_light = parent.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if directional_light:
			dir_base_energy = directional_light.light_energy
			
	# 3. Setup duplicated lamp material to avoid mutating disk resource
	_setup_lamp_material()
	
	# Start in a clean, default state: set process to false as we only need Tweens
	set_process(false)
	
	# Initial configuration: snap lights off so they can fade on smoothly on cycle start
	snap_lights_out()

func _find_omni_lights(node: Node) -> void:
	if node is OmniLight3D:
		omni_lights.append(node)
	for child in node.get_children():
		_find_omni_lights(child)

func _find_mesh_instances(node: Node, list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		list.append(node)
	for child in node.get_children():
		_find_mesh_instances(child, list)

func _setup_lamp_material() -> void:
	var mesh_instances: Array[MeshInstance3D] = []
	_find_mesh_instances(self, mesh_instances)
	if mesh_instances.is_empty():
		return

	# Find the first MeshInstance3D that has a valid StandardMaterial3D
	var base_mat: StandardMaterial3D = null
	for mi in mesh_instances:
		if mi.mesh and mi.mesh.material is StandardMaterial3D:
			base_mat = mi.mesh.material
			break

	if base_mat:
		lamp_material = base_mat.duplicate() as StandardMaterial3D
		lamp_base_emission_mult = lamp_material.emission_energy_multiplier
		# Override material on all meshes in our subtree so they share this instance
		for mi in mesh_instances:
			mi.material_override = lamp_material
	else:
		# If no material on the mesh, check material override
		for mi in mesh_instances:
			if mi.material_override is StandardMaterial3D:
				lamp_material = mi.material_override.duplicate() as StandardMaterial3D
				lamp_base_emission_mult = lamp_material.emission_energy_multiplier
				break
		if lamp_material:
			for mi in mesh_instances:
				mi.material_override = lamp_material

## Calculates the color matching the reward_schema value (-50.0 to 50.0)
func get_color_for_reward(reward: float) -> Color:
	var t: float = 0.0
	if reward >= 0.0:
		t = clamp(reward / 50.0, 0.0, 1.0)
		# Lerp from white to warm amber/orange
		return Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.7, 0.35), t)
	else:
		t = clamp(abs(reward) / 50.0, 0.0, 1.0)
		# Lerp from white to cold blue/cyan
		return Color(1.0, 1.0, 1.0).lerp(Color(0.4, 0.75, 1.0), t)

## Tweens light colors and emission color based on the specimen's reward schema.
func update_hue_from_reward(reward_schema: float, duration: float = 1.0) -> Tween:
	var target_color = get_color_for_reward(reward_schema)
	
	if color_tween:
		color_tween.kill()
		color_tween = null
		
	if duration <= 0.0:
		for light in omni_lights:
			light.light_color = target_color
		if directional_light:
			directional_light.light_color = target_color
		if lamp_material:
			lamp_material.emission = target_color
		return null
		
	color_tween = create_tween().set_parallel(true)
	
	# Tween lights
	for light in omni_lights:
		color_tween.tween_property(light, "light_color", target_color, duration)
	if directional_light:
		color_tween.tween_property(directional_light, "light_color", target_color, duration)
		
	# Tween ceiling lamp emission color
	if lamp_material:
		color_tween.tween_property(lamp_material, "emission", target_color, duration)
		
	return color_tween

## Slowly dims all room lights and emission to 0.0 energy.
func dim_lights_slow(duration: float) -> Tween:
	if energy_tween:
		energy_tween.kill()
		energy_tween = null
		
	if duration <= 0.0:
		snap_lights_out()
		return null
		
	energy_tween = create_tween().set_parallel(true)
	
	for light in omni_lights:
		energy_tween.tween_property(light, "light_energy", 0.0, duration)
	if directional_light:
		energy_tween.tween_property(directional_light, "light_energy", 0.0, duration)
	if lamp_material:
		energy_tween.tween_property(lamp_material, "emission_energy_multiplier", 0.0, duration)
		
	return energy_tween

## Instantly snaps all room lights and emission to 0.0 energy.
func snap_lights_out() -> void:
	if energy_tween:
		energy_tween.kill()
		energy_tween = null
		
	for light in omni_lights:
		light.light_energy = 0.0
	if directional_light:
		directional_light.light_energy = 0.0
	if lamp_material:
		lamp_material.emission_energy_multiplier = 0.0

## Fades all room lights and emission back to their cached base energy levels.
func fade_lights_on(duration: float) -> Tween:
	if energy_tween:
		energy_tween.kill()
		energy_tween = null
		
	if duration <= 0.0:
		for light in omni_lights:
			var base = omni_base_energies.get(light, 1.0)
			light.light_energy = base
		if directional_light:
			directional_light.light_energy = dir_base_energy
		if lamp_material:
			lamp_material.emission_energy_multiplier = lamp_base_emission_mult
		return null
		
	energy_tween = create_tween().set_parallel(true)
	
	for light in omni_lights:
		var base = omni_base_energies.get(light, 1.0)
		energy_tween.tween_property(light, "light_energy", base, duration)
	if directional_light:
		energy_tween.tween_property(directional_light, "light_energy", dir_base_energy, duration)
	if lamp_material:
		energy_tween.tween_property(lamp_material, "emission_energy_multiplier", lamp_base_emission_mult, duration)
		
	return energy_tween

## Helper check to see if lights are currently completely dimmed.
func is_lights_dimmed() -> bool:
	if lamp_material and lamp_material.emission_energy_multiplier > 0.01:
		return false
	for light in omni_lights:
		if light.light_energy > 0.01:
			return false
	if directional_light and directional_light.light_energy > 0.01:
		return false
	return true
