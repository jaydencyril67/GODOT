extends Node3D

# Lightweight, procedural landing campus. The detailed interactive campus will
# grow from these reusable building and environment helpers.
const GOLD := Color("#d6ad62")
const GOLD_LIGHT := Color("#f3d79a")
const OBSIDIAN := Color("#090b10")
const DARK_METAL := Color("#171b22")
const GLASS := Color("#26313a")

func _ready() -> void:
	_build_environment()
	_build_campus()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#07090e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b8a47e")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.name = "Isometric_Landing_Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 47.0
	camera.position = Vector3(30.0, 25.0, 34.0)
	camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.name = "Warm_Architectural_Key_Light"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("#f5dfb4")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65.0
	add_child(sun)

	var gold_fill := OmniLight3D.new()
	gold_fill.position = Vector3(-9.0, 8.0, 7.0)
	gold_fill.light_color = Color("#d7a34e")
	gold_fill.light_energy = 1.35
	gold_fill.omni_range = 22.0
	add_child(gold_fill)


func _build_campus() -> void:
	var ground_material := _material(Color("#10141a"), 0.94)
	var road_material := _material(Color("#080a0e"), 0.98)
	var path_material := _material(Color("#292b2e"), 0.88)
	var gold_material := _emissive_material(GOLD, Color("#c18b35"), 0.85)
	var soft_gold := _emissive_material(Color("#e8c987"), Color("#d4a653"), 0.48)
	var green_material := _material(Color("#17231f"), 0.96)

	_add_box(self, Vector3(100.0, 0.5, 100.0), Vector3(0.0, -0.35, 0.0), ground_material, "Obsidian_Campus_Ground")
	_add_box(self, Vector3(5.2, 0.08, 76.0), Vector3(0.0, -0.06, 0.0), road_material, "Central_Campus_Avenue")
	_add_box(self, Vector3(72.0, 0.08, 4.4), Vector3(0.0, -0.05, 0.0), road_material, "Cross_Campus_Avenue")
	_add_box(self, Vector3(2.1, 0.10, 72.0), Vector3(-9.0, 0.0, 0.0), path_material, "West_Golden_Walkway")
	_add_box(self, Vector3(2.1, 0.10, 72.0), Vector3(9.0, 0.0, 0.0), path_material, "East_Golden_Walkway")
	_add_box(self, Vector3(70.0, 0.10, 1.8), Vector3(0.0, 0.0, -8.0), path_material, "North_Walkway")
	_add_box(self, Vector3(70.0, 0.10, 1.8), Vector3(0.0, 0.0, 8.0), path_material, "South_Walkway")

	# The headquarters is the visual anchor of the campus.
	_build_tower(Vector3(-7.0, 0.0, -5.0), 9.0, 18.0, 8.0, "HEADQUARTERS", true)
	_build_tower(Vector3(10.0, 0.0, -8.0), 7.0, 11.0, 7.0, "RESEARCH", false)
	_build_tower(Vector3(8.0, 0.0, 9.0), 10.0, 8.0, 8.0, "PRODUCTION", false)
	_build_tower(Vector3(-10.0, 0.0, 10.0), 7.0, 7.0, 6.0, "DESIGN CENTRE", false)

	# Low planting beds and warm campus bollards give the scene scale.
	for x in [-19.0, 19.0]:
		for z in [-17.0, -3.0, 12.0, 25.0]:
			_add_box(self, Vector3(5.0, 0.32, 4.0), Vector3(x, 0.10, z), green_material, "Landscape_Bed")
			_add_box(self, Vector3(0.13, 1.65, 0.13), Vector3(x, 0.95, z), DARK_METAL, "Campus_Light_Post")
			_add_box(self, Vector3(0.34, 0.12, 0.34), Vector3(x, 1.82, z), soft_gold, "Campus_Light_Cap")

	# Fine gold inlays make the road geometry read as designed architecture.
	for z in [-35.0, 35.0]:
		_add_box(self, Vector3(0.07, 0.025, 76.0), Vector3(2.72, 0.02, z * 0.0), gold_material, "Road_Inlay")
	for x in [-31.0, 31.0]:
		_add_box(self, Vector3(72.0, 0.025, 0.07), Vector3(x * 0.0, 0.025, 2.25), gold_material, "Road_Inlay")


func _build_tower(origin: Vector3, width: float, height: float, depth: float, title: String, landmark: bool) -> void:
	var root := Node3D.new()
	root.name = title.replace(" ", "_")
	root.position = origin
	add_child(root)

	var base_mat := _material(Color("#20252c"), 0.72, 0.42)
	var body_mat := _material(GLASS if landmark else DARK_METAL, 0.28, 0.58)
	var dark_glass := _material(Color("#17232d"), 0.18, 0.46)
	var gold := _emissive_material(GOLD, Color("#b98232"), 0.72)
	var warm := _emissive_material(GOLD_LIGHT, Color("#e2b75d"), 0.42)

	_add_box(root, Vector3(width + 1.6, 0.7, depth + 1.6), Vector3(0.0, 0.35, 0.0), base_mat, "Raised_Stone_Plinth")
	_add_box(root, Vector3(width + 0.8, 1.15, depth + 0.8), Vector3(0.0, 1.0, 0.0), gold, "Illuminated_Base_Rim")
	_add_box(root, Vector3(width, height, depth), Vector3(0.0, height * 0.5 + 1.5, 0.0), body_mat, "Main_Architectural_Volume")
	_add_box(root, Vector3(width + 0.3, 0.18, depth + 0.3), Vector3(0.0, height + 1.55, 0.0), gold, "Roof_Light_Line")

	var floors := maxi(3, int(height / 2.5))
	for floor_index in range(floors):
		var y := 2.2 + float(floor_index) * (height / float(floors))
		_add_box(root, Vector3(width - 0.75, 0.075, 0.08), Vector3(0.0, y, depth * 0.5 + 0.06), warm, "Front_Window_Light")
		_add_box(root, Vector3(0.08, 0.075, depth - 0.55), Vector3(width * 0.5 + 0.06, y, 0.0), warm, "Side_Window_Light")

	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.20, height + 0.3, 0.22), Vector3(side * (width * 0.5 - 0.45), height * 0.5 + 1.5, depth * 0.5 + 0.12), gold, "Facade_Gold_Fin")

	_add_box(root, Vector3(width * 0.48, 2.5, 0.18), Vector3(0.0, 2.25, depth * 0.5 + 0.14), dark_glass, "Entry_Glazing")
	_add_box(root, Vector3(width * 0.60, 0.18, 1.65), Vector3(0.0, 3.65, depth * 0.5 + 0.75), gold, "Entry_Canopy")

	var sign := Label3D.new()
	sign.name = "Building_Sign"
	sign.text = title
	sign.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	sign.font_size = 30 if landmark else 22
	sign.pixel_size = 0.012
	sign.modulate = GOLD_LIGHT
	sign.position = Vector3(0.0, 4.2, depth * 0.5 + 0.28)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.outline_size = 5
	sign.outline_modulate = Color("#090b10")
	root.add_child(sign)

	if landmark:
		_add_box(root, Vector3(width * 0.52, 0.24, depth + 0.65), Vector3(0.0, height + 2.1, 0.0), warm, "Headquarters_Crown")
		_add_box(root, Vector3(0.22, 4.2, 0.22), Vector3(0.0, height + 4.3, 0.0), gold, "Gold_Spire")


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
