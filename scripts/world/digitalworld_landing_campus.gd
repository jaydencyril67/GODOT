extends Node3D

signal cinematic_reveal_finished

# A lightweight, procedural corporate arrival scene built for mobile.
# The cinematic corporate environment is built from real 3D geometry.
const EMERALD := Color("#36a85b")
const EMERALD_LIGHT := Color("#b8f5c3")
const OBSIDIAN := Color("#090d11")
const DARK_METAL := Color("#171e22")
const GLASS := Color("#263b35")

var camera_rig: Node3D
var landing_camera: Camera3D
var animated_emissive_materials: Array[StandardMaterial3D] = []
var active_tweens: Array[Tween] = []


func _ready() -> void:
	_build_environment()
	_build_corporate_district()
	_animate_architecture()
	_play_opening_cinematic()


func _exit_tree() -> void:
	# Kill every animation before its target nodes are removed. This prevents
	# orphaned infinite tweens when the landing world is replaced by Home.
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
	environment.background_color = Color("#05090a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a3d9ae")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	camera_rig = Node3D.new()
	camera_rig.name = "Cinematic_Camera_Rig"
	camera_rig.rotation_degrees.y = -1.8
	add_child(camera_rig)

	landing_camera = Camera3D.new()
	landing_camera.name = "Corporate_Arrival_Camera"
	landing_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	landing_camera.size = 50.0
	landing_camera.position = Vector3(30.0, 25.0, 34.0)
	camera_rig.add_child(landing_camera)
	landing_camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	landing_camera.current = true

	var key_light := DirectionalLight3D.new()
	key_light.name = "Soft_Architectural_Key_Light"
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key_light.light_color = Color("#d9f4df")
	key_light.light_energy = 1.08
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 65.0
	add_child(key_light)

	var emerald_fill := OmniLight3D.new()
	emerald_fill.name = "Emerald_Environmental_Fill"
	emerald_fill.position = Vector3(-9.0, 8.0, 7.0)
	emerald_fill.light_color = Color("#62d883")
	emerald_fill.light_energy = 1.15
	emerald_fill.omni_range = 26.0
	add_child(emerald_fill)


func _build_corporate_district() -> void:
	var ground_material := _material(Color("#10171a"), 0.94)
	var road_material := _material(Color("#080c0f"), 0.98)
	var path_material := _material(Color("#202a28"), 0.88)
	var emerald_material := _emissive_material(EMERALD, Color("#238c45"), 0.78)
	var soft_emerald := _emissive_material(EMERALD_LIGHT, Color("#6edc87"), 0.46)
	var landscape_material := _material(Color("#14231b"), 0.96)
	var dark_metal_material := _material(DARK_METAL, 0.52, 0.58)

	_add_box(self, Vector3(100.0, 0.5, 100.0), Vector3(0.0, -0.35, 0.0), ground_material, "Obsidian_Corporate_Ground")
	_add_box(self, Vector3(5.2, 0.08, 76.0), Vector3(0.0, -0.06, 0.0), road_material, "Central_Arrival_Avenue")
	_add_box(self, Vector3(72.0, 0.08, 4.4), Vector3(0.0, -0.05, 0.0), road_material, "Corporate_Cross_Avenue")
	_add_box(self, Vector3(2.1, 0.10, 72.0), Vector3(-9.0, 0.0, 0.0), path_material, "West_Illuminated_Walkway")
	_add_box(self, Vector3(2.1, 0.10, 72.0), Vector3(9.0, 0.0, 0.0), path_material, "East_Illuminated_Walkway")
	_add_box(self, Vector3(70.0, 0.10, 1.8), Vector3(0.0, 0.0, -8.0), path_material, "North_Walkway")
	_add_box(self, Vector3(70.0, 0.10, 1.8), Vector3(0.0, 0.0, 8.0), path_material, "South_Walkway")

	# The headquarters remains the visual landmark; nearby buildings frame it.
	_build_tower(Vector3(-7.0, 0.0, -5.0), 9.0, 18.0, 8.0, "HEADQUARTERS", true)
	_build_tower(Vector3(10.0, 0.0, -8.0), 7.0, 11.0, 7.0, "INNOVATION", false)
	_build_tower(Vector3(8.0, 0.0, 9.0), 10.0, 8.0, 8.0, "PRODUCTION", false)
	_build_tower(Vector3(-10.0, 0.0, 10.0), 7.0, 7.0, 6.0, "DESIGN STUDIO", false)

	for x in [-19.0, 19.0]:
		for z in [-17.0, -3.0, 12.0, 25.0]:
			_add_box(self, Vector3(5.0, 0.32, 4.0), Vector3(x, 0.10, z), landscape_material, "Landscape_Planter")
			_add_box(self, Vector3(0.13, 1.65, 0.13), Vector3(x, 0.95, z), dark_metal_material, "Architectural_Light_Post")
			_add_box(self, Vector3(0.34, 0.12, 0.34), Vector3(x, 1.82, z), soft_emerald, "Emerald_Light_Cap")

	for x in [-2.72, 2.72]:
		_add_box(self, Vector3(0.07, 0.025, 76.0), Vector3(x, 0.02, 0.0), emerald_material, "Emerald_Road_Inlay")
	for z in [-2.25, 2.25]:
		_add_box(self, Vector3(72.0, 0.025, 0.07), Vector3(0.0, 0.025, z), emerald_material, "Emerald_Road_Inlay")

	_build_headquarters_halo()
	_add_floating_light_motes()


func _build_tower(origin: Vector3, width: float, height: float, depth: float, title: String, landmark: bool) -> void:
	var root := Node3D.new()
	root.name = title.replace(" ", "_")
	root.position = origin
	add_child(root)

	var base_material := _material(Color("#202a2c"), 0.72, 0.42)
	var body_material := _material(GLASS if landmark else DARK_METAL, 0.28, 0.58)
	var dark_glass := _material(Color("#172b25"), 0.18, 0.46)
	var emerald := _emissive_material(EMERALD, Color("#238c45"), 0.76)
	var soft_light := _emissive_material(EMERALD_LIGHT, Color("#79e995"), 0.46)
	animated_emissive_materials.append(emerald)
	animated_emissive_materials.append(soft_light)

	_add_box(root, Vector3(width + 1.6, 0.7, depth + 1.6), Vector3(0.0, 0.35, 0.0), base_material, "Raised_Stone_Plinth")
	_add_box(root, Vector3(width + 0.8, 1.15, depth + 0.8), Vector3(0.0, 1.0, 0.0), emerald, "Illuminated_Base_Rim")
	_add_box(root, Vector3(width, height, depth), Vector3(0.0, height * 0.5 + 1.5, 0.0), body_material, "Main_Architectural_Volume")
	_add_box(root, Vector3(width + 0.3, 0.18, depth + 0.3), Vector3(0.0, height + 1.55, 0.0), emerald, "Roof_Light_Line")

	var floors := maxi(3, int(height / 2.5))
	for floor_index in range(floors):
		var y := 2.2 + float(floor_index) * (height / float(floors))
		_add_box(root, Vector3(width - 0.75, 0.075, 0.08), Vector3(0.0, y, depth * 0.5 + 0.06), soft_light, "Front_Window_Light")
		_add_box(root, Vector3(0.08, 0.075, depth - 0.55), Vector3(width * 0.5 + 0.06, y, 0.0), soft_light, "Side_Window_Light")

	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.20, height + 0.3, 0.22), Vector3(side * (width * 0.5 - 0.45), height * 0.5 + 1.5, depth * 0.5 + 0.12), emerald, "Facade_Illuminated_Fin")

	_add_box(root, Vector3(width * 0.48, 2.5, 0.18), Vector3(0.0, 2.25, depth * 0.5 + 0.14), dark_glass, "Entry_Glazing")
	_add_box(root, Vector3(width * 0.60, 0.18, 1.65), Vector3(0.0, 3.65, depth * 0.5 + 0.75), emerald, "Entry_Canopy")

	var sign := Label3D.new()
	sign.name = "Building_Sign"
	sign.text = title
	sign.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	sign.font_size = 30 if landmark else 22
	sign.pixel_size = 0.012
	sign.modulate = EMERALD_LIGHT
	sign.position = Vector3(0.0, 4.2, depth * 0.5 + 0.28)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.outline_size = 5
	sign.outline_modulate = Color("#090d11")
	root.add_child(sign)

	if landmark:
		_add_box(root, Vector3(width * 0.52, 0.24, depth + 0.65), Vector3(0.0, height + 2.1, 0.0), soft_light, "Headquarters_Crown")
		_add_box(root, Vector3(0.22, 4.2, 0.22), Vector3(0.0, height + 4.3, 0.0), emerald, "Emerald_Spire")
		var scanner_material := _emissive_material(Color("#c9ffd2"), Color("#54e77a"), 0.66)
		var scanner := _add_box(root, Vector3(width + 0.18, 0.055, 0.10), Vector3(0.0, 2.25, depth * 0.5 + 0.18), scanner_material, "Moving_Facade_Scan")
		var scanner_tween := _track_tween(create_tween().set_loops())
		scanner_tween.tween_property(scanner, "position:y", height + 1.2, 3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		scanner_tween.tween_property(scanner, "position:y", 2.25, 3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_headquarters_halo() -> void:
	var halo_root := Node3D.new()
	halo_root.name = "Headquarters_Holographic_Halo"
	halo_root.position = Vector3(-7.0, 22.0, -5.0)
	add_child(halo_root)

	var ring_material := _emissive_material(Color("#6bdc87"), Color("#36bd60"), 0.42)
	var horizontal_ring := _make_torus(5.7, 5.60, ring_material)
	horizontal_ring.position.y = 0.2
	halo_root.add_child(horizontal_ring)

	var angled_ring := _make_torus(6.25, 6.15, ring_material)
	angled_ring.rotation_degrees = Vector3(62.0, 0.0, 14.0)
	halo_root.add_child(angled_ring)

	var halo_tween := _track_tween(create_tween().set_loops())
	halo_tween.tween_property(halo_root, "rotation_degrees:y", 360.0, 38.0).from(0.0).set_trans(Tween.TRANS_LINEAR)


func _make_torus(outer_radius: float, inner_radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = outer_radius
	torus.inner_radius = inner_radius
	torus.rings = 48
	torus.ring_segments = 8
	instance.mesh = torus
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _add_floating_light_motes() -> void:
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.045
	mote_mesh.height = 0.09
	var mote_material := _emissive_material(Color("#88f4a0"), Color("#3be36c"), 0.72)
	mote_mesh.material = mote_material

	for index in range(12):
		var angle := float(index) * TAU / 12.0
		var orbit_radius := 13.0 + float(index % 3) * 2.0
		var mote := MeshInstance3D.new()
		mote.name = "Floating_Atmosphere_Light_%02d" % index
		mote.mesh = mote_mesh
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.position = Vector3(cos(angle) * orbit_radius, 0.55 + float(index % 4) * 0.32, sin(angle) * orbit_radius)
		add_child(mote)

		var float_tween := _track_tween(create_tween().set_loops())
		var start_y := mote.position.y
		var rise_time := 2.8 + float(index % 4) * 0.35
		float_tween.tween_property(mote, "position:y", start_y + 0.72, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		float_tween.tween_property(mote, "position:y", start_y - 0.18, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_architecture() -> void:
	for material in animated_emissive_materials:
		var pulse := _track_tween(create_tween().set_loops())
		pulse.tween_property(material, "emission_energy_multiplier", 0.58, 2.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(material, "emission_energy_multiplier", 0.36, 2.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_opening_cinematic() -> void:
	# Start directly on the corporate world while retaining the cinematic camera reveal.
	var camera_tween := _track_tween(create_tween().set_parallel(true))
	camera_tween.tween_property(landing_camera, "size", 44.5, 4.5).from(50.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(camera_rig, "rotation_degrees:y", 0.0, 4.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var reveal_signal_tween := _track_tween(create_tween())
	reveal_signal_tween.tween_interval(3.55)
	reveal_signal_tween.tween_callback(func() -> void:
		cinematic_reveal_finished.emit()
	)

	var camera_drift := _track_tween(create_tween().set_loops())
	camera_drift.tween_interval(4.6)
	camera_drift.tween_property(camera_rig, "rotation_degrees:y", 0.28, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_drift.tween_property(camera_rig, "rotation_degrees:y", -0.28, 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


func _add_box(parent: Node3D, size: Vector3, position: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance
