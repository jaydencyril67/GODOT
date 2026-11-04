extends Node3D

signal cinematic_reveal_finished

# A compact premium 3D hero composition for the landing page.
# This deliberately contains no city, streets, campus, or surrounding buildings.
const EMERALD := Color("#36a85b")
const EMERALD_LIGHT := Color("#b8f5c3")
const OBSIDIAN := Color("#090d11")
const DARK_METAL := Color("#171e22")
const GLASS := Color("#344653")

var landing_camera: Camera3D
var animated_emissive_materials: Array[StandardMaterial3D] = []
var active_tweens: Array[Tween] = []


func _ready() -> void:
	_build_environment()
	_build_hero_design()
	_animate_architecture()
	_play_opening_cinematic()


func _exit_tree() -> void:
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	active_tweens.clear()


func _track_tween(tween: Tween) -> Tween:
	active_tweens.append(tween)
	return tween


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#050a08")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c3d2c8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	landing_camera = Camera3D.new()
	landing_camera.name = "Landing_Hero_Camera"
	landing_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	landing_camera.size = 25.0
	landing_camera.position = Vector3(8.5, 7.0, 20.0)
	add_child(landing_camera)
	landing_camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	landing_camera.current = true

	var key_light := DirectionalLight3D.new()
	key_light.name = "Soft_Hero_Key_Light"
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_color = Color("#e5f0e8")
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 40.0
	add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.name = "Emerald_Rim_Light"
	rim_light.position = Vector3(-8.0, 5.0, -3.0)
	rim_light.light_color = EMERALD_LIGHT
	rim_light.light_energy = 1.05
	rim_light.omni_range = 24.0
	add_child(rim_light)


func _build_hero_design() -> void:
	var stage_material := _material(Color("#101a15"), 0.78, 0.42)
	var dark_metal := _material(DARK_METAL, 0.34, 0.72)
	var phone_body := _material(Color("#aebbb2"), 0.24, 0.82)
	var screen_material := _material(Color("#07120d"), 0.16, 0.38)
	var glass_material := _material(GLASS, 0.12, 0.48)
	var emerald := _emissive_material(EMERALD, Color("#238c45"), 0.78)
	var soft_emerald := _emissive_material(EMERALD_LIGHT, Color("#6edc87"), 0.54)
	var white_glint := _emissive_material(Color("#e4ffe9"), Color("#b7ffd0"), 0.38)
	animated_emissive_materials.append(emerald)
	animated_emissive_materials.append(soft_emerald)

	# A single sculptural presentation stage, not an environment or city.
	_add_cylinder(self, 8.2, 0.42, Vector3(0.0, -0.18, 0.0), stage_material, "Floating_Obsidian_Podium")
	_add_cylinder(self, 5.9, 0.08, Vector3(0.0, 0.08, 0.0), dark_metal, "Upper_Podium_Disc")

	# Oversized premium smartphone sculpture, angled as the landing-page hero.
	var device := Node3D.new()
	device.name = "Digital_World_Phone_Sculpture"
	device.position = Vector3(0.0, 1.1, 0.0)
	device.rotation_degrees = Vector3(-7.0, -18.0, -13.0)
	add_child(device)

	_add_box(device, Vector3(6.15, 12.0, 0.62), Vector3.ZERO, dark_metal, "Precision_Machined_Frame")
	_add_box(device, Vector3(5.98, 11.82, 0.52), Vector3(0.0, 0.0, 0.035), phone_body, "Satin_Titanium_Back")
	_add_box(device, Vector3(5.72, 11.48, 0.045), Vector3(0.0, 0.0, 0.305), screen_material, "Obsidian_Display")

	# Layered display graphics create depth without text or a flat background image.
	_add_box(device, Vector3(4.65, 0.045, 0.025), Vector3(0.0, 2.55, 0.34), emerald, "Display_Upper_Accent")
	_add_box(device, Vector3(3.75, 0.035, 0.025), Vector3(0.0, -2.7, 0.34), soft_emerald, "Display_Lower_Accent")
	_add_box(device, Vector3(0.055, 6.9, 0.025), Vector3(-2.12, 0.0, 0.34), glass_material, "Display_Left_Glass_Line")
	_add_box(device, Vector3(0.055, 6.9, 0.025), Vector3(2.12, 0.0, 0.34), glass_material, "Display_Right_Glass_Line")
	_add_box(device, Vector3(1.25, 0.11, 0.04), Vector3(0.0, 5.35, 0.36), dark_metal, "Earpiece")
	_add_sphere(device, 0.105, Vector3(0.88, 5.34, 0.37), white_glint, "Front_Camera_Lens")

	# Distinctive rear camera island is visible as part of the sculpture's edge.
	var camera_island := _add_box(device, Vector3(1.62, 2.35, 0.12), Vector3(-1.78, 4.12, -0.34), dark_metal, "Rear_Camera_Island")
	camera_island.rotation_degrees.z = -5.0
	for lens_position in [Vector3(-2.12, 4.78, -0.43), Vector3(-1.42, 4.78, -0.43), Vector3(-2.12, 3.95, -0.43)]:
		_add_sphere(device, 0.23, lens_position, glass_material, "Rear_Camera_Lens")
		_add_sphere(device, 0.095, lens_position + Vector3(0.0, 0.0, -0.10), white_glint, "Lens_Reflection")
	_add_sphere(device, 0.13, Vector3(-1.42, 3.95, -0.43), soft_emerald, "Camera_Flash")



func _animate_architecture() -> void:
	for material in animated_emissive_materials:
		var pulse := _track_tween(create_tween().set_loops())
		pulse.tween_property(material, "emission_energy_multiplier", 0.62, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(material, "emission_energy_multiplier", 0.38, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_opening_cinematic() -> void:
	# Keep the hero camera completely stationary: no zoom, dolly, or camera drift.
	# The landing-page text and menu retain their existing entrance transitions.
	var reveal_signal_tween := _track_tween(create_tween())
	reveal_signal_tween.tween_interval(1.0)
	reveal_signal_tween.tween_callback(func() -> void:
		cinematic_reveal_finished.emit()
	)


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color, glow: Color, strength: float) -> StandardMaterial3D:
	var material := _material(color, 0.3, 0.62)
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = strength
	return material


func _add_box(parent: Node3D, size: Vector3, local_position: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, radius: float, height: float, local_position: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 96
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_torus(parent: Node3D, outer_radius: float, inner_radius: float, material: Material, local_position: Vector3, local_rotation: Vector3, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.outer_radius = outer_radius
	mesh.inner_radius = inner_radius
	mesh.rings = 64
	mesh.ring_segments = 10
	instance.mesh = mesh
	instance.position = local_position
	instance.rotation_degrees = local_rotation
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, radius: float, local_position: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
