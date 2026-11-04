extends Node3D
class_name DigitalWorldHeadquarters

signal preview_level_changed(level: int)
signal setup_progress(message: String, progress: float)
signal setup_completed
signal back_requested
signal upgrade_requested(level: int)
signal downgrade_requested(level: int, refund_percent: int)
signal staff_market_requested
signal staff_management_requested

const MAX_LEVEL := 10
const STAFF_CAPACITIES := [3, 7, 13, 20, 30, 42, 55, 75, 100, 130]
const UPGRADE_COSTS := [3000000, 10000000, 15000000, 22000000, 30000000, 40000000, 52000000, 63000000, 75000000, 100000000]
const MONTHLY_RENTS := [150000, 500000, 750000, 1100000, 1500000, 2000000, 2600000, 3150000, 3750000, 5000000]
const LEVEL_CONFIGS := [
	{"name": "Workshop", "floors": 1, "width": 12.4, "depth": 9.4, "ground_height": 4.2, "floor_height": 3.0, "style": 0},
	{"name": "Workshop & Office", "floors": 2, "width": 13.2, "depth": 10.0, "ground_height": 3.6, "floor_height": 2.9, "style": 1},
	{"name": "Small Office Building", "floors": 3, "width": 14.4, "depth": 11.0, "ground_height": 3.6, "floor_height": 2.9, "style": 1},
	{"name": "Modern Office", "floors": 4, "width": 15.6, "depth": 12.0, "ground_height": 3.7, "floor_height": 2.95, "style": 2},
	{"name": "Large Office", "floors": 5, "width": 16.8, "depth": 13.0, "ground_height": 3.8, "floor_height": 2.95, "style": 2},
	{"name": "Corporate Headquarters", "floors": 6, "width": 18.0, "depth": 14.0, "ground_height": 3.8, "floor_height": 3.0, "style": 3},
	{"name": "Modern Glass Offices", "floors": 7, "width": 19.2, "depth": 15.0, "ground_height": 3.9, "floor_height": 3.0, "style": 3},
	{"name": "Large Glass Headquarters", "floors": 8, "width": 20.4, "depth": 16.0, "ground_height": 3.9, "floor_height": 3.0, "style": 4},
	{"name": "Grand Glass Headquarters", "floors": 9, "width": 21.8, "depth": 17.0, "ground_height": 4.0, "floor_height": 3.0, "style": 4},
	{"name": "Massive Glass Headquarters", "floors": 10, "width": 23.0, "depth": 18.0, "ground_height": 4.0, "floor_height": 3.0, "style": 4}
]

var preview_level: int = 1
var owned_level: int = 0
var company_name := "YOUR COMPANY"
var company_balance := 10000000.0
var upgrade_cost_label: Label
var monthly_rent_label: Label
var available_balance_label: Label
var building_root: Node3D
var compound_facilities_root: Node3D
var compound_facilities_level: int = -1
var hq_camera: Camera3D
var level_info_label: Label
var staff_capacity_label: Label
var preview_interface_layer: CanvasLayer
var owned_info_label: Label
var previous_level_button: Button
var next_level_button: Button
var upgrade_button: Button
var downgrade_button: Button
var downgrade_refund_percent := 55
var home_mode := false
var camera_target := Vector3.ZERO
var camera_distance := 38.0
var camera_max_distance := 36.0
var camera_yaw := 0.62
var camera_pitch := 0.24
var mouse_orbiting := false
var mouse_panning := false
var touch_points: Dictionary = {}
var materials: Dictionary = {}
var facade_noise: Texture2D
var facade_normal: Texture2D

func _ready() -> void:
	preview_level = clampi(preview_level, 1, MAX_LEVEL)
	owned_level = clampi(owned_level, 0, MAX_LEVEL)

	setup_progress.emit("Initializing game...", 8.0)
	await get_tree().process_frame

	setup_progress.emit("Loading company data...", 20.0)
	await get_tree().process_frame

	_create_material_library()
	_create_procedural_surface_textures()

	setup_progress.emit("Setting up scenes...", 38.0)
	await get_tree().process_frame

	_create_environment()
	_create_presentation_stage()

	setup_progress.emit("Constructing your headquarters...", 58.0)
	await get_tree().process_frame

	var building_height := 4.2
	if not home_mode or owned_level > 0:
		building_height = _build_procedural_building(preview_level)

	setup_progress.emit("Preparing camera and interface...", 88.0)
	await get_tree().process_frame

	_create_camera(building_height)
	_create_preview_interface()
	await get_tree().process_frame

	setup_progress.emit("Headquarters ready!", 100.0)
	setup_completed.emit()

func _create_material_library() -> void:
	materials = {
		"concrete": _mat(Color("#b8b9b1"), 0.9),
		"dark_metal": _mat(Color("#252b30"), 0.42, 0.72),
		"metal": _mat(Color("#78878b"), 0.34, 0.78),
		"glass": _glass_mat(),
		"storefront": _mat(Color("#252b30"), 0.22, 0.38),
		"window_frame": _mat(Color("#30383d"), 0.38, 0.62),
		"glass_reflection": _mat(Color("#aebdca"), 0.12, 0.32),
		"window_gasket": _mat(Color("#11171c"), 0.72, 0.18),
		"roof": _mat(Color("#59636b"), 0.72, 0.28),
		"lamp": _emissive_mat(Color("#ffe4ad"), 1.5),
		"hq_sign": _mat(Color("#12351b"), 0.32, 0.48),
		"hq_accent": _emissive_mat(Color("#50c96b"), 1.8),
		"workshop_cladding": _mat(Color("#9ba3a5"), 0.72, 0.22),
		"workshop_shutter": _mat(Color("#30383d"), 0.65, 0.42),
		"glass_mullion": _mat(Color("#303a43"), 0.28, 0.82),
		"glass_spandrel": _mat(Color("#202a33"), 0.22, 0.58)
	}

func _create_procedural_surface_textures() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.52
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	facade_noise = texture
	var normal_texture := NoiseTexture2D.new()
	normal_texture.width = 256
	normal_texture.height = 256
	normal_texture.seamless = true
	normal_texture.as_normal_map = true
	normal_texture.bump_strength = 0.22
	normal_texture.noise = noise
	facade_normal = normal_texture

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#627b91")
	sky_material.sky_horizon_color = Color("#d8dfe5")
	sky_material.ground_bottom_color = Color("#343b42")
	sky_material.ground_horizon_color = Color("#aeb8c1")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material

	# Home gets a clean deep-emerald world background, not a blue studio sky.
	# Keep the original sky as the ambient/reflection source so the building's
	# material response and natural colour remain the same.
	environment.background_mode = Environment.BG_SKY

	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.ambient_light_sky_contribution = 0.88
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment = environment
	add_child(world)

	# The original key and fill lights are deliberately unchanged.
	var sun := DirectionalLight3D.new()
	sun.name = "Headquarters_Key_Light"
	sun.rotation_degrees = Vector3(-43.0, -31.0, 0.0)
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "Headquarters_Fill_Light"
	fill.position = Vector3(-18.0, 15.0, 12.0)
	fill.light_color = Color("#c3d0d9")
	fill.light_energy = 1.1
	fill.omni_range = 42.0
	fill.shadow_enabled = false
	add_child(fill)


func _create_presentation_stage() -> void:
	# The HQ is built into a real property. There is no raised showroom deck or trim plinth.
	var compound := Node3D.new()
	compound.name = "Company_Compound"
	add_child(compound)

	var outer_ground_mesh := PlaneMesh.new()
	outer_ground_mesh.size = Vector2(190.0, 190.0)
	var outer_ground := MeshInstance3D.new()
	outer_ground.name = "Surrounding_Landscape"
	outer_ground.mesh = outer_ground_mesh
	outer_ground.position = Vector3(0.0, -0.12, 0.0)
	var outer_material := _mat(Color("#172d1b"), 0.98)
	outer_material.albedo_texture = facade_noise
	outer_material.uv1_scale = Vector3(24.0, 24.0, 1.0)
	outer_material.normal_enabled = true
	outer_material.normal_texture = facade_normal
	outer_material.normal_scale = 0.08
	outer_ground.material_override = outer_material
	outer_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	compound.add_child(outer_ground)

	var site_mesh := PlaneMesh.new()
	site_mesh.size = Vector2(70.0, 66.0)
	var site_ground := MeshInstance3D.new()
	site_ground.name = "Continuous_Compound_Grass"
	site_ground.mesh = site_mesh
	site_ground.position = Vector3(0.0, -0.075, 0.0)
	var grass_material := _mat(Color("#24452a"), 0.98)
	grass_material.albedo_texture = facade_noise
	grass_material.uv1_scale = Vector3(17.0, 17.0, 1.0)
	grass_material.normal_enabled = true
	grass_material.normal_texture = facade_normal
	grass_material.normal_scale = 0.11
	site_ground.material_override = grass_material
	site_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	compound.add_child(site_ground)

	_create_compound_roads(compound)
	_create_compound_perimeter(compound)
	_create_compound_gate(compound)
	_create_compound_parking(compound)
	_create_compound_landscape(compound)
	_create_compound_lighting(compound)

	# Facilities are created once and shown in the upgrade preview. The Home
	# compound reveals them after the first headquarters purchase.
	compound_facilities_root = Node3D.new()
	compound_facilities_root.name = "Operational_And_Support_Facilities"
	compound.add_child(compound_facilities_root)
	_update_compound_facilities_visibility()


func _create_compound_roads(parent: Node3D) -> void:
	var asphalt := _mat(Color("#24292d"), 0.94)
	asphalt.albedo_texture = facade_noise
	asphalt.uv1_scale = Vector3(8.0, 8.0, 1.0)
	var asphalt_edge := _mat(Color("#3c4247"), 0.9)
	var paving := _mat(Color("#858b8f"), 0.92)
	var paving_light := _mat(Color("#a3a5a3"), 0.9)
	var road_marking := _mat(Color("#e0dfcc"), 0.86)

	_box(parent, "Main_Entrance_Drive", Vector3(8.0, 0.055, 25.0), Vector3(0.0, 0.015, 18.0), asphalt)
	_box(parent, "Entrance_Apron", Vector3(13.0, 0.055, 6.0), Vector3(0.0, 0.015, 27.0), asphalt)
	_box(parent, "West_Service_Road", Vector3(5.2, 0.055, 43.0), Vector3(-23.0, 0.015, 2.0), asphalt)
	_box(parent, "West_Service_Yard_Connection", Vector3(11.0, 0.055, 5.2), Vector3(-18.0, 0.015, -3.0), asphalt)
	_box(parent, "East_Service_Access", Vector3(5.0, 0.055, 24.0), Vector3(23.5, 0.015, 4.0), asphalt)

	# Low kerbs define road edges without lifting the compound onto a platform.
	for side in [-1.0, 1.0]:
		_box(parent, "Driveway_Kerb", Vector3(0.22, 0.16, 25.0), Vector3(side * 4.12, 0.06, 18.0), asphalt_edge)
		_box(parent, "Driveway_Edge_Marking", Vector3(0.075, 0.018, 22.0), Vector3(side * 3.72, 0.054, 17.0), road_marking)

	_box(parent, "Main_Entrance_Pedestrian_Walk", Vector3(2.8, 0.07, 5.5), Vector3(0.0, 0.035, 8.0), paving)
	_box(parent, "Front_Entry_Landing", Vector3(7.5, 0.07, 2.0), Vector3(0.0, 0.035, 6.1), paving_light)
	for index in range(7):
		var z := 6.0 + float(index) * 0.72
		_box(parent, "Walkway_Paver_Joint", Vector3(2.65, 0.012, 0.035), Vector3(0.0, 0.078, z), asphalt_edge)

	# A service path connects the loading side of the workshop to the west lane.
	_box(parent, "Production_Service_Apron", Vector3(9.5, 0.055, 6.0), Vector3(-16.0, 0.015, -6.0), asphalt)
	_box(parent, "Research_Service_Paving", Vector3(8.0, 0.055, 5.0), Vector3(16.0, 0.015, -6.5), asphalt)


func _create_compound_perimeter(parent: Node3D) -> void:
	var fence_material := _mat(Color("#30383d"), 0.54, 0.68)
	var fence_post_material := _mat(Color("#59636b"), 0.62, 0.52)
	_add_fence_run(parent, Vector3(-31.0, 0.0, -29.0), Vector3(31.0, 0.0, -29.0), fence_material, fence_post_material)
	_add_fence_run(parent, Vector3(-31.0, 0.0, -29.0), Vector3(-31.0, 0.0, 29.0), fence_material, fence_post_material)
	_add_fence_run(parent, Vector3(31.0, 0.0, -29.0), Vector3(31.0, 0.0, 29.0), fence_material, fence_post_material)
	_add_fence_run(parent, Vector3(-31.0, 0.0, 29.0), Vector3(-5.6, 0.0, 29.0), fence_material, fence_post_material)
	_add_fence_run(parent, Vector3(5.6, 0.0, 29.0), Vector3(31.0, 0.0, 29.0), fence_material, fence_post_material)


func _add_fence_run(parent: Node3D, start_point: Vector3, end_point: Vector3, fence_material: Material, post_material: Material) -> void:
	var delta := end_point - start_point
	var distance := Vector2(delta.x, delta.z).length()
	var segment_count := maxi(1, int(ceil(distance / 4.0)))
	var along_x := absf(delta.x) >= absf(delta.z)
	var rotation_y := 0.0 if along_x else PI * 0.5
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(distance, 0.085, 0.12)
	for rail_height in [0.52, 1.40]:
		var rail := MeshInstance3D.new()
		rail.name = "Perimeter_Fence_Rail"
		rail.mesh = rail_mesh
		rail.position = (start_point + end_point) * 0.5 + Vector3(0.0, rail_height, 0.0)
		rail.rotation.y = rotation_y
		rail.material_override = fence_material
		parent.add_child(rail)

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.18, 1.78, 0.18)
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	posts.mesh = post_mesh
	posts.instance_count = segment_count + 1
	for index in range(segment_count + 1):
		var point := start_point.lerp(end_point, float(index) / float(segment_count))
		posts.set_instance_transform(index, Transform3D(Basis.IDENTITY, point + Vector3(0.0, 0.89, 0.0)))
	_add_multimesh(parent, "Perimeter_Fence_Posts", posts, post_material)

	var picket_mesh := BoxMesh.new()
	picket_mesh.size = Vector3(0.065, 1.24, 0.075)
	var picket_count := int(floor(distance / 0.78))
	var pickets := MultiMesh.new()
	pickets.transform_format = MultiMesh.TRANSFORM_3D
	pickets.mesh = picket_mesh
	pickets.instance_count = picket_count
	for index in range(picket_count):
		var t := (float(index) + 0.5) / float(picket_count)
		var point := start_point.lerp(end_point, t)
		pickets.set_instance_transform(index, Transform3D(Basis(Vector3.UP, rotation_y), point + Vector3(0.0, 0.91, 0.0)))
	_add_multimesh(parent, "Perimeter_Fence_Pickets", pickets, fence_material)


func _create_compound_gate(parent: Node3D) -> void:
	var stone := _mat(Color("#7d8183"), 0.88)
	var dark_metal := _mat(Color("#252b30"), 0.48, 0.72)
	_box(parent, "Main_Gate_Pillar_Left", Vector3(0.82, 3.25, 0.82), Vector3(-5.45, 1.625, 29.0), stone)
	_box(parent, "Main_Gate_Pillar_Right", Vector3(0.82, 3.25, 0.82), Vector3(5.45, 1.625, 29.0), stone)
	_box(parent, "Gate_Pillar_Cap_Left", Vector3(1.0, 0.18, 1.0), Vector3(-5.45, 3.32, 29.0), materials["metal"])
	_box(parent, "Gate_Pillar_Cap_Right", Vector3(1.0, 0.18, 1.0), Vector3(5.45, 3.32, 29.0), materials["metal"])
	_box(parent, "Company_Entrance_Sign_Frame", Vector3(10.2, 0.58, 0.40), Vector3(0.0, 3.0, 29.0), dark_metal)
	_box(parent, "Company_Entrance_Sign_Emerald_Line", Vector3(9.6, 0.045, 0.035), Vector3(0.0, 2.70, 29.22), materials["hq_accent"])
	var sign := Label3D.new()
	sign.name = "Company_Compound_Entrance_Sign"
	sign.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	sign.text = company_name.to_upper().substr(0, 26) if not company_name.is_empty() else "YOUR COMPANY"
	sign.font_size = 34
	sign.pixel_size = 0.009
	sign.modulate = Color("#f2f6ed")
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.position = Vector3(0.0, 3.06, 29.24)
	sign.rotation.y = PI
	parent.add_child(sign)
	# The sliding leaves are parked open against the fence, leaving a clear vehicle entrance.
	for side in [-1.0, 1.0]:
		_box(parent, "Open_Sliding_Gate_Leaf", Vector3(3.3, 1.7, 0.11), Vector3(side * 8.0, 0.95, 29.0), dark_metal)
		for bar in range(1, 8):
			var x: float = float(side) * (6.45 + float(bar) * 0.42)
			_box(parent, "Gate_Leaf_Vertical_Bar", Vector3(0.055, 1.65, 0.14), Vector3(x, 0.95, 29.0), materials["metal"])


func _create_compound_facilities(parent: Node3D, level: int) -> void:
	_create_compound_facility(parent, "Production_And_Assembly", "PRODUCTION & ASSEMBLY", Vector3(-17.0, 0.0, -12.0), Vector3(10.5, 4.1, 8.0), level, "production")
	_create_compound_facility(parent, "Research_And_Test_Lab", "RESEARCH & TEST LAB", Vector3(16.5, 0.0, -12.0), Vector3(10.0, 4.0, 8.0), level, "research")
	_create_compound_facility(parent, "Utilities_Building", "UTILITIES", Vector3(23.0, 0.0, -1.0), Vector3(6.5, 3.0, 5.0), level, "utilities")
	_create_compound_facility(parent, "Security_Gatehouse", "SECURITY", Vector3(-17.0, 0.0, 22.0), Vector3(6.0, 3.0, 4.6), level, "security")



func _create_compound_facility(parent: Node3D, node_name: String, sign_text: String, center: Vector3, dimensions: Vector3, level: int, facility_type: String) -> void:
	var width: float = dimensions.x
	var depth: float = dimensions.z
	var heights: Array[float] = []
	var wall_color := Color("#929ba0")
	match facility_type:
		"production":
			heights = [3.55, 3.72, 3.92, 4.08, 4.25, 4.42, 4.62, 4.82, 5.02, 5.24]
			wall_color = Color("#8f999d")
		"research":
			heights = [3.10, 3.28, 3.48, 3.68, 3.88, 4.08, 4.28, 4.48, 4.68, 4.90]
			wall_color = Color("#b7c0c3")
		"utilities":
			heights = [2.45, 2.55, 2.66, 2.78, 2.90, 3.02, 3.14, 3.26, 3.38, 3.52]
			wall_color = Color("#838d91")
		"security":
			heights = [2.55, 2.72, 2.90, 3.08, 3.26, 3.44, 3.62, 3.80, 3.98, 4.18]
			wall_color = Color("#a0a8aa")
	var height: float = heights[level - 1]
	var wall := _mat(wall_color, 0.82, 0.12)
	wall.albedo_texture = facade_noise
	wall.uv1_scale = Vector3(2.5, 2.5, 1.0)
	wall.normal_enabled = true
	wall.normal_texture = facade_normal
	wall.normal_scale = 0.12
	var roof := _mat(Color("#505a63"), 0.78, 0.32)

	var width_profiles: Dictionary = {
		"production": [1.00, 0.86, 0.92, 0.80, 0.96, 0.78, 0.88, 0.98, 0.82, 0.92],
		"research": [0.96, 0.88, 0.92, 0.82, 0.98, 0.86, 0.94, 0.84, 0.88, 0.96],
		"utilities": [0.90, 0.82, 0.94, 0.88, 0.80, 0.92, 0.84, 0.98, 0.86, 0.94],
		"security": [0.98, 0.88, 0.84, 0.80, 0.94, 0.86, 0.78, 0.96, 0.84, 0.92]
	}
	var depth_profiles: Dictionary = {
		"production": [0.96, 0.88, 0.90, 0.82, 0.94, 0.86, 0.90, 0.80, 0.92, 0.86],
		"research": [0.92, 0.84, 0.94, 0.88, 0.82, 0.92, 0.86, 0.96, 0.84, 0.90],
		"utilities": [0.88, 0.96, 0.84, 0.92, 0.86, 0.98, 0.88, 0.82, 0.94, 0.90],
		"security": [0.94, 0.86, 0.96, 0.84, 0.92, 0.88, 0.98, 0.82, 0.90, 0.86]
	}
	var core_width: float = width * float(width_profiles[facility_type][level - 1])
	var core_depth: float = depth * float(depth_profiles[facility_type][level - 1])
	var front_z: float = center.z + core_depth * 0.5 + 0.13
	var glazed_core: bool = facility_type == "research" or (facility_type == "security" and level >= 7)
	_add_facility_mass(parent, "%s_Level_%02d_Core_Mass" % [node_name, level], center, Vector3(core_width, height, core_depth), wall, roof, glazed_core)
	_build_facility_level_massing(parent, node_name, center, width, depth, height, level, facility_type, wall, roof)

	match facility_type:
		"production":
			_build_production_facility(parent, node_name, center, core_width, core_depth, height, center.z + core_depth * 0.5 + 0.13, level)
		"research":
			_build_research_facility(parent, node_name, center, core_width, core_depth, height, center.z + core_depth * 0.5 + 0.13, level)
		"utilities":
			_build_utilities_facility(parent, node_name, center, core_width, core_depth, height, level)
		"security":
			_build_security_facility(parent, node_name, center, core_width, core_depth, height, center.z + core_depth * 0.5 + 0.13, level)

	_facility_box(parent, node_name + "_Sign_Plaque", Vector3(core_width * 0.72, 0.42, 0.08), Vector3(center.x, height - 0.42, front_z + 0.14), materials["dark_metal"])
	var sign := Label3D.new()
	sign.name = node_name + "_Facility_Sign"
	sign.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	sign.text = sign_text
	sign.font_size = 22
	sign.pixel_size = 0.009
	sign.modulate = Color("#eef4e9")
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.position = Vector3(center.x, height - 0.40, front_z + 0.20)
	sign.rotation.y = PI
	parent.add_child(sign)


func _add_facility_mass(parent: Node3D, node_name: String, center: Vector3, dimensions: Vector3, wall: Material, roof: Material, glazed: bool = false) -> Node3D:
	var mass_root := Node3D.new()
	mass_root.name = node_name
	mass_root.position = center
	parent.add_child(mass_root)
	var width: float = dimensions.x
	var height: float = dimensions.y
	var depth: float = dimensions.z
	_facility_box(mass_root, node_name + "_Foundation", Vector3(width + 0.38, 0.18, depth + 0.38), Vector3(0.0, 0.09, 0.0), materials["concrete"])
	_facility_box(mass_root, node_name + "_Envelope", Vector3(width, height, depth), Vector3(0.0, height * 0.5 + 0.18, 0.0), wall)
	_facility_box(mass_root, node_name + "_Roof_Cap", Vector3(width + 0.30, 0.20, depth + 0.30), Vector3(0.0, height + 0.28, 0.0), roof)
	var front_z: float = depth * 0.5 + 0.065
	var window_y: float = minf(height * 0.64, height - 0.42)
	var window_height: float = minf(0.78, maxf(0.34, height * 0.27))
	for index in range(3):
		var x: float = (float(index) - 1.0) * width * 0.27
		var frame_material: Material = materials["window_frame"]
		_facility_box(mass_root, node_name + "_Window_Frame", Vector3(width * 0.20, window_height + 0.18, 0.10), Vector3(x, window_y, front_z), frame_material)
		_facility_box(mass_root, node_name + "_Window_Glazing", Vector3(width * 0.16, window_height, 0.045), Vector3(x, window_y, front_z + 0.07), materials["glass"])
	if glazed:
		_facility_box(mass_root, node_name + "_Glazed_Corner", Vector3(width * 0.22, height * 0.72, 0.055), Vector3(width * 0.36, height * 0.58 + 0.18, depth * 0.5 + 0.08), materials["glass"])
	return mass_root


func _build_facility_level_massing(parent: Node3D, node_name: String, center: Vector3, width: float, depth: float, height: float, level: int, facility_type: String, wall: Material, roof: Material) -> void:
	var side: float = -1.0 if level % 2 == 0 else 1.0
	var module_wall: Material = wall
	var module_roof: Material = roof
	var module_glass: bool = facility_type == "research"
	var module_width_factor: float = 0.30
	var module_height_factor: float = 0.58
	var module_depth_factor: float = 0.48
	match facility_type:
		"production":
			module_width_factor = 0.34
			module_height_factor = 0.62
			module_depth_factor = 0.58
			module_wall = _mat(Color("#7d898f"), 0.84, 0.12)
		"research":
			module_width_factor = 0.28
			module_height_factor = 0.72
			module_depth_factor = 0.52
			module_glass = true
			module_wall = _mat(Color("#aeb9bf"), 0.72, 0.16)
		"utilities":
			module_width_factor = 0.24
			module_height_factor = 0.50
			module_depth_factor = 0.44
			module_wall = _mat(Color("#737f85"), 0.78, 0.28)
		"security":
			module_width_factor = 0.28
			module_height_factor = 0.72
			module_depth_factor = 0.46
			module_glass = true
			module_wall = _mat(Color("#969fa4"), 0.76, 0.18)

	var module_position := center
	var module_size := Vector3(width * module_width_factor, height * module_height_factor, depth * module_depth_factor)
	match level:
		1:
			module_position += Vector3(-side * width * 0.34, 0.0, -depth * 0.14)
			module_size = Vector3(width * module_width_factor, height * 0.52, depth * 0.58)
		2:
			module_position += Vector3(side * width * 0.34, 0.0, depth * 0.20)
			module_size = Vector3(width * 0.32, height * 0.68, depth * 0.46)
		3:
			module_position += Vector3(-side * width * 0.33, 0.0, -depth * 0.20)
			module_size = Vector3(width * 0.28, height * 0.78, depth * 0.54)
		4:
			module_position += Vector3(side * width * 0.16, height * 0.54, -depth * 0.10)
			module_size = Vector3(width * 0.62, height * 0.38, depth * 0.60)
		5:
			module_position += Vector3(0.0, height * 0.48, -depth * 0.34)
			module_size = Vector3(width * 0.68, height * 0.42, depth * 0.32)
		6:
			module_position += Vector3(side * width * 0.34, height * 0.24, -depth * 0.12)
			module_size = Vector3(width * 0.25, height * 0.96, depth * 0.34)
		7:
			module_position += Vector3(-side * width * 0.30, height * 0.48, depth * 0.12)
			module_size = Vector3(width * 0.32, height * 0.40, depth * 0.54)
			_add_facility_mass(parent, node_name + "_Level_07_Opposite_Wing", center + Vector3(side * width * 0.30, height * 0.40, -depth * 0.10), Vector3(width * 0.28, height * 0.46, depth * 0.48), module_wall, module_roof, module_glass)
		8:
			module_position += Vector3(0.0, height * 0.62, -depth * 0.08)
			module_size = Vector3(width * 0.78, height * 0.18, depth * 0.24)
		9:
			module_position += Vector3(-side * width * 0.26, height * 0.58, -depth * 0.08)
			module_size = Vector3(width * 0.27, height * 0.43, depth * 0.42)
			_add_facility_mass(parent, node_name + "_Level_09_Twin_Upper_Pod", center + Vector3(side * width * 0.26, height * 0.56, -depth * 0.08), Vector3(width * 0.25, height * 0.40, depth * 0.40), module_wall, module_roof, module_glass)
		10:
			module_position += Vector3(0.0, height * 0.56, -depth * 0.08)
			module_size = Vector3(width * 0.72, height * 0.40, depth * 0.50)
			_add_facility_mass(parent, node_name + "_Level_10_Flagship_Wing", center + Vector3(-side * width * 0.30, height * 0.34, depth * 0.10), Vector3(width * 0.34, height * 0.64, depth * 0.48), module_wall, module_roof, module_glass)

	if facility_type == "utilities":
		module_size.x *= 0.82
		module_size.z *= 0.90
	elif facility_type == "security":
		module_size.x *= 0.92
	elif facility_type == "research":
		module_size.z *= 1.08
	elif facility_type == "production":
		module_size.x *= 1.08

	var module_name := "%s_Level_%02d_Architectural_Module" % [node_name, level]
	_add_facility_mass(parent, module_name, module_position, module_size, module_wall, module_roof, module_glass)


func _build_production_facility(parent: Node3D, node_name: String, center: Vector3, width: float, depth: float, height: float, front_z: float, level: int) -> void:
	var roof := _mat(Color("#505a63"), 0.78, 0.32)
	var shutter_width: float = width * 0.43
	_facility_box(parent, node_name + "_Loading_Door_Frame", Vector3(shutter_width + 0.28, 2.76, 0.16), Vector3(center.x, 1.62, front_z), materials["dark_metal"])
	_facility_box(parent, node_name + "_Roller_Shutter", Vector3(shutter_width, 2.58, 0.07), Vector3(center.x, 1.61, front_z + 0.10), materials["workshop_shutter"])
	for slat in range(8):
		_facility_box(parent, node_name + "_Shutter_Slat", Vector3(shutter_width * 0.98, 0.035, 0.035), Vector3(center.x, 0.52 + float(slat) * 0.30, front_z + 0.15), materials["metal"])
	_facility_box(parent, node_name + "_Staff_Door", Vector3(0.78, 2.20, 0.09), Vector3(center.x - width * 0.36, 1.34, front_z + 0.08), materials["dark_metal"])
	for index in range(3):
		var wx: float = center.x + (float(index) - 1.0) * width * 0.29
		_facility_box(parent, node_name + "_Clerestory_Frame", Vector3(width * 0.18, 0.62, 0.10), Vector3(wx, height - 0.72, front_z), materials["window_frame"])
		_facility_box(parent, node_name + "_Clerestory_Glass", Vector3(width * 0.15, 0.45, 0.045), Vector3(wx, height - 0.72, front_z + 0.07), materials["glass"])
	for rib in range(4 + level):
		var x: float = center.x + (float(rib) - float(3 + level) * 0.5) * (width / float(4 + level))
		_facility_box(parent, node_name + "_Roof_Rib", Vector3(0.045, 0.06, depth + 0.32), Vector3(x, height + 0.49, center.z), materials["metal"])
	if level == 1:
		_facility_box(parent, node_name + "_Workshop_Roof_Lantern", Vector3(width * 0.34, 0.45, 1.05), Vector3(center.x, height + 0.56, center.z - depth * 0.20), materials["window_frame"])
		_facility_box(parent, node_name + "_Lantern_Glazing", Vector3(width * 0.30, 0.28, 0.90), Vector3(center.x, height + 0.57, center.z - depth * 0.20), materials["glass"])
	elif level == 2:
		_facility_box(parent, node_name + "_Loading_Canopy", Vector3(width * 0.66, 0.16, 1.35), Vector3(center.x, 3.10, front_z + 0.58), materials["dark_metal"])
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Canopy_Support", Vector3(0.09, 1.10, 0.09), Vector3(center.x + side * width * 0.29, 2.52, front_z + 1.10), materials["metal"])
	elif level == 3:
		_facility_box(parent, node_name + "_Raised_Clerestory", Vector3(width * 0.58, 0.78, depth * 0.34), Vector3(center.x, height + 0.72, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Clerestory_Glazing", Vector3(width * 0.54, 0.55, depth * 0.30), Vector3(center.x, height + 0.73, center.z - depth * 0.08), materials["glass"])
	elif level == 4:
		_facility_box(parent, node_name + "_Raised_Quality_Office", Vector3(width * 0.42, 1.05, depth * 0.42), Vector3(center.x + width * 0.22, height + 0.72, center.z - depth * 0.14), materials["window_frame"])
		_facility_box(parent, node_name + "_Quality_Office_Glass", Vector3(width * 0.39, 0.72, depth * 0.39), Vector3(center.x + width * 0.22, height + 0.78, center.z - depth * 0.14), materials["glass"])
	elif level == 5:
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Sawtooth_Roof_Monitor", Vector3(width * 0.28, 0.68, depth * 0.34), Vector3(center.x + side * width * 0.22, height + 0.68, center.z - depth * 0.10), materials["window_frame"], Vector3(0.0, 0.0, side * -8.0))
			_facility_box(parent, node_name + "_Sawtooth_Glazing", Vector3(width * 0.24, 0.40, depth * 0.30), Vector3(center.x + side * width * 0.22, height + 0.72, center.z - depth * 0.10), materials["glass"], Vector3(0.0, 0.0, side * -8.0))
	elif level == 6:
		_facility_box(parent, node_name + "_Process_Service_Tower", Vector3(1.65, 2.35, 1.65), Vector3(center.x + width * 0.39, height + 1.10, center.z - depth * 0.27), materials["window_frame"])
		for tier in range(3):
			_facility_box(parent, node_name + "_Tower_Window", Vector3(1.30, 0.12, 0.045), Vector3(center.x + width * 0.39, height + 0.35 + float(tier) * 0.65, center.z - depth * 0.27 + 0.85), materials["glass"])
	elif level == 7:
		_facility_box(parent, node_name + "_Automation_Mezzanine", Vector3(width * 0.72, 1.0, depth * 0.32), Vector3(center.x - width * 0.08, height + 0.70, center.z - depth * 0.18), materials["window_frame"])
		_facility_box(parent, node_name + "_Mezzanine_Glazing", Vector3(width * 0.68, 0.68, depth * 0.28), Vector3(center.x - width * 0.08, height + 0.72, center.z - depth * 0.18), materials["glass"])
		_facility_box(parent, node_name + "_Cladding_Fin", Vector3(0.16, height + 1.0, 0.24), Vector3(center.x - width * 0.43, (height + 1.0) * 0.5 + 0.22, front_z + 0.10), materials["metal"])
	elif level == 8:
		_facility_box(parent, node_name + "_Upper_Automation_Hall", Vector3(width * 0.56, 1.30, depth * 0.58), Vector3(center.x + width * 0.17, height + 0.84, center.z - depth * 0.12), roof)
		_facility_box(parent, node_name + "_Upper_Hall_Glass_Band", Vector3(width * 0.49, 0.30, 0.06), Vector3(center.x + width * 0.17, height + 0.78, center.z + depth * 0.18), materials["glass"])
	elif level == 9:
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Twin_Process_Housing", Vector3(width * 0.25, 1.12, depth * 0.38), Vector3(center.x + side * width * 0.27, height + 0.70, center.z - depth * 0.12), roof)
			_cylinder(parent, node_name + "_Process_Exhaust", 0.22, 0.30, 1.55, Vector3(center.x + side * width * 0.27, height + 1.80, center.z - depth * 0.24), materials["metal"])
	elif level == 10:
		_facility_box(parent, node_name + "_Flagship_Glazed_Office", Vector3(width * 0.42, 1.65, depth * 0.54), Vector3(center.x - width * 0.22, height + 0.92, center.z - depth * 0.10), materials["window_frame"])
		_facility_box(parent, node_name + "_Flagship_Office_Glass", Vector3(width * 0.38, 1.30, depth * 0.50), Vector3(center.x - width * 0.22, height + 0.96, center.z - depth * 0.10), materials["glass"])
		_facility_box(parent, node_name + "_High_Bay_Monitor", Vector3(width * 0.22, 1.10, depth * 0.30), Vector3(center.x + width * 0.28, height + 0.80, center.z - depth * 0.12), materials["window_frame"])
		_facility_box(parent, node_name + "_Flagship_Loading_Canopy", Vector3(width * 0.58, 0.18, 1.20), Vector3(center.x, 3.40, front_z + 0.60), materials["metal"])


func _build_research_facility(parent: Node3D, node_name: String, center: Vector3, width: float, depth: float, height: float, front_z: float, level: int) -> void:
	for index in range(3):
		var wx: float = center.x + (float(index) - 1.0) * width * 0.29
		_facility_box(parent, node_name + "_Window_Frame", Vector3(width * 0.19, 1.42, 0.12), Vector3(wx, 2.10, front_z), materials["window_frame"])
		_facility_box(parent, node_name + "_Window_Glazing", Vector3(width * 0.16, 1.18, 0.045), Vector3(wx, 2.10, front_z + 0.08), materials["glass"])
	_facility_box(parent, node_name + "_Glass_Entry", Vector3(0.86, 2.20, 0.06), Vector3(center.x, 1.38, front_z + 0.12), materials["glass"])
	if level == 1:
		_facility_box(parent, node_name + "_Lab_Roof_Lantern", Vector3(width * 0.28, 0.44, depth * 0.24), Vector3(center.x, height + 0.56, center.z - depth * 0.12), materials["window_frame"])
	elif level == 2:
		_facility_box(parent, node_name + "_Glass_Entry_Vestibule", Vector3(width * 0.42, 1.45, 1.15), Vector3(center.x, 0.95, front_z + 0.62), materials["glass"])
		_facility_box(parent, node_name + "_Vestibule_Canopy", Vector3(width * 0.50, 0.14, 1.38), Vector3(center.x, 1.78, front_z + 0.64), materials["metal"])
	elif level == 3:
		_facility_box(parent, node_name + "_Central_Glass_Atrium", Vector3(width * 0.34, 1.55, depth * 0.42), Vector3(center.x, height + 0.88, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Atrium_Glazing", Vector3(width * 0.30, 1.30, depth * 0.38), Vector3(center.x, height + 0.90, center.z - depth * 0.08), materials["glass"])
	elif level == 4:
		_facility_box(parent, node_name + "_Corner_Research_Tower", Vector3(2.25, 2.10, 2.1), Vector3(center.x - width * 0.32, height + 1.12, center.z - depth * 0.20), materials["window_frame"])
		_facility_box(parent, node_name + "_Corner_Tower_Glass", Vector3(2.00, 1.76, 0.06), Vector3(center.x - width * 0.32, height + 1.14, center.z + depth * 0.86), materials["glass"])
	elif level == 5:
		_facility_box(parent, node_name + "_Cantilevered_Upper_Lab", Vector3(width * 0.68, 1.15, depth * 0.58), Vector3(center.x + width * 0.12, height + 0.76, center.z - depth * 0.06), materials["window_frame"])
		_facility_box(parent, node_name + "_Cantilever_Glass_Band", Vector3(width * 0.62, 0.66, 0.045), Vector3(center.x + width * 0.12, height + 0.78, center.z + depth * 0.24), materials["glass"])
	elif level == 6:
		_facility_box(parent, node_name + "_North_Lab_Wing", Vector3(width * 0.34, 1.42, depth * 0.48), Vector3(center.x - width * 0.27, height + 0.88, center.z - depth * 0.06), materials["concrete"])
		_facility_box(parent, node_name + "_South_Lab_Wing", Vector3(width * 0.34, 1.05, depth * 0.40), Vector3(center.x + width * 0.27, height + 0.70, center.z + depth * 0.08), materials["window_frame"])
	elif level == 7:
		_facility_box(parent, node_name + "_Glazed_Upper_Lab", Vector3(width * 0.78, 0.82, depth * 0.44), Vector3(center.x, height + 0.62, center.z - depth * 0.08), materials["glass"])
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Glass_Facade_Fin", Vector3(0.12, height + 1.0, 0.22), Vector3(center.x + side * width * 0.43, height * 0.5 + 0.65, front_z + 0.12), materials["metal"])
	elif level == 8:
		_facility_box(parent, node_name + "_Elevated_Research_Bridge", Vector3(width * 0.72, 0.82, depth * 0.28), Vector3(center.x, height + 0.70, center.z - depth * 0.24), materials["window_frame"])
		_facility_box(parent, node_name + "_Bridge_Glazing", Vector3(width * 0.66, 0.52, 0.045), Vector3(center.x, height + 0.72, center.z - depth * 0.08), materials["glass"])
	elif level == 9:
		_facility_box(parent, node_name + "_Research_Tower", Vector3(width * 0.40, 2.25, depth * 0.48), Vector3(center.x + width * 0.20, height + 1.25, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Tower_Full_Glazing", Vector3(width * 0.35, 1.92, depth * 0.44), Vector3(center.x + width * 0.20, height + 1.26, center.z - depth * 0.08), materials["glass"])
	elif level == 10:
		_facility_box(parent, node_name + "_Signature_Atrium", Vector3(width * 0.34, 2.10, depth * 0.46), Vector3(center.x, height + 1.35, center.z - depth * 0.06), materials["window_frame"])
		_facility_box(parent, node_name + "_Signature_Atrium_Glass", Vector3(width * 0.30, 1.82, depth * 0.42), Vector3(center.x, height + 1.37, center.z - depth * 0.06), materials["glass"])
		_facility_box(parent, node_name + "_Research_East_Wing", Vector3(width * 0.31, 1.00, depth * 0.46), Vector3(center.x + width * 0.32, height + 0.64, center.z - depth * 0.08), materials["concrete"])
		_facility_box(parent, node_name + "_Research_West_Wing", Vector3(width * 0.31, 1.36, depth * 0.38), Vector3(center.x - width * 0.32, height + 0.82, center.z - depth * 0.10), materials["window_frame"])


func _build_utilities_facility(parent: Node3D, node_name: String, center: Vector3, width: float, depth: float, height: float, level: int) -> void:
	for index in range(4):
		var z: float = center.z + (float(index) - 1.5) * 0.62
		_facility_box(parent, node_name + "_Mechanical_Louvre", Vector3(0.07, 0.58, 0.42), Vector3(center.x + width * 0.5 + 0.06, 1.10, z), materials["dark_metal"])
	if level == 1:
		_facility_box(parent, node_name + "_Exhaust_Hood", Vector3(1.0, 0.32, 0.8), Vector3(center.x, height + 0.58, center.z), materials["metal"])
	elif level == 2:
		_facility_box(parent, node_name + "_Switchgear_Cabinet", Vector3(1.45, 1.25, 1.15), Vector3(center.x - width * 0.18, 0.85, center.z - depth * 0.52), materials["metal"])
	elif level == 3:
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Outdoor_Transformer", Vector3(1.05, 1.25, 0.95), Vector3(center.x + side * width * 0.27, 0.74, center.z - depth * 0.56), materials["metal"])
	elif level == 4:
		_facility_box(parent, node_name + "_Cooling_Plant_Housing", Vector3(width * 0.56, 1.05, depth * 0.48), Vector3(center.x, height + 0.72, center.z - depth * 0.12), materials["metal"])
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Cooling_Plant_Grille", Vector3(0.06, 0.72, depth * 0.34), Vector3(center.x + side * width * 0.28, height + 0.72, center.z - depth * 0.12), materials["dark_metal"])
	elif level == 5:
		for side in [-1.0, 1.0]:
			_cylinder(parent, node_name + "_Pipe_Riser", 0.09, 0.09, height + 1.8, Vector3(center.x + side * width * 0.30, (height + 1.8) * 0.5 + 0.22, center.z - depth * 0.20), materials["metal"])
		_facility_box(parent, node_name + "_Pipe_Gantry", Vector3(width * 0.74, 0.16, 0.20), Vector3(center.x, height + 0.85, center.z - depth * 0.20), materials["metal"])
	elif level == 6:
		_cylinder(parent, node_name + "_Thermal_Storage_Tank", 0.95, 1.05, 2.75, Vector3(center.x - width * 0.22, 1.60, center.z - depth * 0.58), materials["metal"])
		_facility_box(parent, node_name + "_Tank_Access_Platform", Vector3(2.45, 0.14, 1.35), Vector3(center.x - width * 0.22, 2.96, center.z - depth * 0.58), materials["dark_metal"])
	elif level == 7:
		for side in [-1.0, 1.0]:
			_cylinder(parent, node_name + "_Exhaust_Stack", 0.20, 0.28, 3.5, Vector3(center.x + side * width * 0.25, height + 1.90, center.z - depth * 0.20), materials["metal"])
	elif level == 8:
		_facility_box(parent, node_name + "_Transformer_Bank", Vector3(width * 0.70, 0.82, depth * 0.44), Vector3(center.x, height + 0.72, center.z - depth * 0.10), materials["metal"])
		for row in range(5):
			_facility_box(parent, node_name + "_Transformer_Cooling_Fin", Vector3(0.07, 0.58, depth * 0.34), Vector3(center.x - width * 0.28 + float(row) * width * 0.14, height + 0.72, center.z + depth * 0.15), materials["dark_metal"])
	elif level == 9:
		for side in [-1.0, 1.0]:
			_cylinder(parent, node_name + "_Energy_Storage_Tank", 0.72, 0.82, 2.7, Vector3(center.x + side * width * 0.25, 1.55, center.z - depth * 0.55), materials["metal"])
			_cylinder(parent, node_name + "_Tank_Neck", 0.16, 0.16, 0.62, Vector3(center.x + side * width * 0.25, 3.20, center.z - depth * 0.55), materials["dark_metal"])
		_facility_box(parent, node_name + "_Service_Pipe_Bridge", Vector3(width * 0.78, 0.14, 0.18), Vector3(center.x, height + 0.70, center.z - depth * 0.18), materials["metal"])
	elif level == 10:
		_facility_box(parent, node_name + "_Energy_Control_Room", Vector3(width * 0.56, 1.20, depth * 0.46), Vector3(center.x, height + 0.78, center.z - depth * 0.10), materials["window_frame"])
		_facility_box(parent, node_name + "_Energy_Control_Glazing", Vector3(width * 0.51, 0.82, 0.045), Vector3(center.x, height + 0.80, center.z + depth * 0.14), materials["glass"])
		for side in [-1.0, 1.0]:
			_cylinder(parent, node_name + "_Storage_Vessel", 0.66, 0.78, 2.95, Vector3(center.x + side * width * 0.32, 1.68, center.z - depth * 0.55), materials["metal"])
			_cylinder(parent, node_name + "_Vent_Stack", 0.13, 0.19, 3.6, Vector3(center.x + side * width * 0.38, height + 1.95, center.z - depth * 0.18), materials["dark_metal"])


func _build_security_facility(parent: Node3D, node_name: String, center: Vector3, width: float, depth: float, height: float, front_z: float, level: int) -> void:
	_facility_box(parent, node_name + "_Observation_Window_Frame", Vector3(width * 0.78, 0.90, 0.10), Vector3(center.x, height - 0.82, front_z + 0.04), materials["window_frame"])
	_facility_box(parent, node_name + "_Observation_Glazing", Vector3(width * 0.72, 0.68, 0.045), Vector3(center.x, height - 0.82, front_z + 0.11), materials["glass"])
	_facility_box(parent, node_name + "_Access_Door", Vector3(0.72, 2.15, 0.09), Vector3(center.x - width * 0.32, 1.30, front_z + 0.08), materials["dark_metal"])
	if level == 1:
		_facility_box(parent, node_name + "_Guard_Booth_Eave", Vector3(width + 0.55, 0.14, depth + 0.45), Vector3(center.x, height + 0.48, center.z), materials["metal"])
	elif level == 2:
		_facility_box(parent, node_name + "_Checkpoint_Canopy", Vector3(width + 1.10, 0.16, depth * 0.55), Vector3(center.x, height + 0.60, front_z + 0.60), materials["metal"])
		for side in [-1.0, 1.0]:
			_facility_box(parent, node_name + "_Canopy_Column", Vector3(0.12, 2.40, 0.12), Vector3(center.x + side * width * 0.48, 1.30, front_z + 1.10), materials["metal"])
	elif level == 3:
		_facility_box(parent, node_name + "_Raised_Observation_Bay", Vector3(width * 0.72, 1.05, depth * 0.62), Vector3(center.x, height + 0.72, center.z - depth * 0.12), materials["window_frame"])
		_facility_box(parent, node_name + "_Raised_Bay_Glass", Vector3(width * 0.66, 0.78, depth * 0.56), Vector3(center.x, height + 0.74, center.z - depth * 0.12), materials["glass"])
	elif level == 4:
		_facility_box(parent, node_name + "_Control_Tower", Vector3(width * 0.42, 1.85, depth * 0.48), Vector3(center.x + width * 0.24, height + 1.08, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Control_Tower_Glass", Vector3(width * 0.38, 1.48, depth * 0.44), Vector3(center.x + width * 0.24, height + 1.10, center.z - depth * 0.08), materials["glass"])
	elif level == 5:
		_facility_box(parent, node_name + "_Cantilevered_Command_Room", Vector3(width * 0.76, 1.10, depth * 0.52), Vector3(center.x - width * 0.10, height + 0.78, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Command_Room_Glass", Vector3(width * 0.70, 0.78, depth * 0.48), Vector3(center.x - width * 0.10, height + 0.80, center.z - depth * 0.08), materials["glass"])
	elif level == 6:
		_facility_box(parent, node_name + "_Operations_Wing", Vector3(width * 0.42, 1.00, depth * 0.60), Vector3(center.x + width * 0.28, 0.75, center.z - depth * 0.04), materials["concrete"])
		_facility_box(parent, node_name + "_Operations_Wing_Window", Vector3(width * 0.35, 0.55, 0.045), Vector3(center.x + width * 0.28, 0.84, front_z + 0.08), materials["glass"])
	elif level == 7:
		_facility_box(parent, node_name + "_Surveillance_Tower", Vector3(width * 0.38, 2.45, depth * 0.46), Vector3(center.x + width * 0.25, height + 1.36, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Surveillance_Tower_Glass", Vector3(width * 0.34, 2.10, depth * 0.42), Vector3(center.x + width * 0.25, height + 1.38, center.z - depth * 0.08), materials["glass"])
	elif level == 8:
		_facility_box(parent, node_name + "_Security_Command_Penthouse", Vector3(width * 0.68, 1.40, depth * 0.60), Vector3(center.x, height + 0.92, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Penthouse_Glazing", Vector3(width * 0.62, 1.04, depth * 0.55), Vector3(center.x, height + 0.94, center.z - depth * 0.08), materials["glass"])
	elif level == 9:
		_facility_box(parent, node_name + "_Dual_Level_Control_Block", Vector3(width * 0.44, 2.55, depth * 0.46), Vector3(center.x - width * 0.20, height + 1.40, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Dual_Level_Control_Glass", Vector3(width * 0.40, 2.20, depth * 0.42), Vector3(center.x - width * 0.20, height + 1.42, center.z - depth * 0.08), materials["glass"])
		_facility_box(parent, node_name + "_Upper_Security_Link", Vector3(width * 0.64, 0.42, 0.44), Vector3(center.x + width * 0.12, height + 0.84, center.z - depth * 0.25), materials["metal"])
	elif level == 10:
		_facility_box(parent, node_name + "_Flagship_Control_Tower", Vector3(width * 0.48, 2.90, depth * 0.48), Vector3(center.x + width * 0.20, height + 1.58, center.z - depth * 0.08), materials["window_frame"])
		_facility_box(parent, node_name + "_Flagship_Control_Glass", Vector3(width * 0.44, 2.55, depth * 0.44), Vector3(center.x + width * 0.20, height + 1.60, center.z - depth * 0.08), materials["glass"])
		_facility_box(parent, node_name + "_Security_Command_Canopy", Vector3(width + 0.90, 0.18, depth * 0.62), Vector3(center.x, height + 0.54, front_z + 0.35), materials["metal"])
		_facility_box(parent, node_name + "_Security_Operations_Wing", Vector3(width * 0.38, 1.15, depth * 0.48), Vector3(center.x - width * 0.30, height + 0.72, center.z - depth * 0.08), materials["concrete"])


func _facility_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := _box(parent, node_name, size, position, material)
	part.rotation_degrees = rotation_degrees
	return part
func _create_compound_parking(parent: Node3D) -> void:
	var asphalt := _mat(Color("#252b27"), 0.94)
	var parking_line := _mat(Color("#d7d8c8"), 0.82)
	var wheel_stop := _mat(Color("#8b9083"), 0.9)
	_box(parent, "Staff_Visitor_Parking_Surface", Vector3(18.0, 0.055, 13.0), Vector3(16.0, 0.015, 13.2), asphalt)
	for slot in range(6):
		var x := 8.8 + float(slot) * 2.85
		_box(parent, "Parking_Bay_Line", Vector3(0.075, 0.025, 5.4), Vector3(x, 0.055, 13.0), parking_line)
		_box(parent, "Parking_Wheel_Stop", Vector3(2.15, 0.12, 0.16), Vector3(x + 1.35, 0.09, 17.1), wheel_stop)
	_box(parent, "Parking_Front_Line", Vector3(17.0, 0.025, 0.075), Vector3(16.0, 0.055, 10.2), parking_line)
	_box(parent, "Parking_Rear_Line", Vector3(17.0, 0.025, 0.075), Vector3(16.0, 0.055, 15.8), parking_line)
	_box(parent, "Parking_Access_Connector", Vector3(5.2, 0.055, 6.0), Vector3(6.2, 0.015, 15.0), asphalt)


func _create_compound_landscape(parent: Node3D) -> void:
	for tree_position in [
		Vector3(-27.0, 0.0, -22.0), Vector3(-27.0, 0.0, 0.0), Vector3(-27.0, 0.0, 19.0),
		Vector3(27.0, 0.0, -22.0), Vector3(28.0, 0.0, 1.0), Vector3(28.0, 0.0, 23.0),
		Vector3(-9.0, 0.0, -24.0), Vector3(9.0, 0.0, -24.0)
	]:
		_add_compound_tree(parent, tree_position, 1.0 if tree_position.x < 0.0 else 0.92)

	var hedge_material := _mat(Color("#24462a"), 0.96)
	var planter_material := _mat(Color("#62696b"), 0.82, 0.24)
	for side in [-1.0, 1.0]:
		_box(parent, "Front_Landscape_Planter", Vector3(4.6, 0.42, 1.0), Vector3(side * 8.0, 0.21, 6.4), planter_material)
		_box(parent, "Front_Clipped_Hedge", Vector3(4.2, 0.72, 0.72), Vector3(side * 8.0, 0.67, 6.4), hedge_material)
		_box(parent, "Office_Side_Hedge", Vector3(0.95, 0.70, 7.0), Vector3(side * 8.2, 0.35, -0.2), hedge_material)
	_box(parent, "Rear_Green_Buffer", Vector3(45.0, 0.65, 1.0), Vector3(0.0, 0.32, -25.0), hedge_material)
	for shrub_index in range(5):
		var x := -25.0 + float(shrub_index) * 2.5
		_add_compound_shrub(parent, Vector3(x, 0.0, 26.0))
		_add_compound_shrub(parent, Vector3(-x, 0.0, -26.0))


func _add_compound_tree(parent: Node3D, position: Vector3, scale_factor: float) -> void:
	var bark := _mat(Color("#594a37"), 0.94)
	var foliage := _mat(Color("#24472a"), 0.96)
	var foliage_light := _mat(Color("#315b35"), 0.96)
	_cylinder(parent, "Landscape_Tree_Trunk", 0.15 * scale_factor, 0.25 * scale_factor, 2.8 * scale_factor, position + Vector3(0.0, 1.4 * scale_factor, 0.0), bark)
	_add_compound_sphere(parent, "Tree_Canopy_Center", 1.25 * scale_factor, position + Vector3(0.0, 3.2 * scale_factor, 0.0), foliage, Vector3(1.0, 0.95, 1.0))
	_add_compound_sphere(parent, "Tree_Canopy_Left", 0.86 * scale_factor, position + Vector3(-0.72 * scale_factor, 2.85 * scale_factor, 0.12 * scale_factor), foliage_light, Vector3(1.0, 1.0, 0.95))
	_add_compound_sphere(parent, "Tree_Canopy_Right", 0.90 * scale_factor, position + Vector3(0.68 * scale_factor, 2.92 * scale_factor, -0.12 * scale_factor), foliage, Vector3(1.0, 1.0, 0.95))


func _add_compound_shrub(parent: Node3D, position: Vector3) -> void:
	var foliage := _mat(Color("#2d5732"), 0.98)
	_add_compound_sphere(parent, "Landscape_Shrub", 0.52, position + Vector3(0.0, 0.42, 0.0), foliage, Vector3(1.25, 0.78, 0.88))


func _add_compound_sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: Material, shape_scale: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	instance.mesh = mesh
	instance.position = position
	instance.scale = shape_scale
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)


func _create_compound_lighting(parent: Node3D) -> void:
	var pole_material := _mat(Color("#343b41"), 0.48, 0.78)
	for side in [-1.0, 1.0]:
		for z in [12.0, 23.0]:
			var pole_position := Vector3(side * 6.2, 0.0, z)
			_cylinder(parent, "Compound_Path_Light_Pole", 0.055, 0.075, 3.2, pole_position + Vector3(0.0, 1.6, 0.0), pole_material)
			_box(parent, "Compound_Path_Light_Head", Vector3(0.42, 0.16, 0.28), pole_position + Vector3(0.0, 3.18, 0.0), materials["lamp"])
	var gate_light := OmniLight3D.new()
	gate_light.name = "Gate_Entrance_Light"
	gate_light.position = Vector3(0.0, 3.3, 26.5)
	gate_light.light_color = Color("#e4e8eb")
	gate_light.light_energy = 1.1
	gate_light.omni_range = 12.0
	gate_light.shadow_enabled = false
	parent.add_child(gate_light)

func _create_camera(building_height: float) -> void:
	_configure_camera_framing(building_height)
	camera_yaw = 0.62
	camera_pitch = 0.42 if home_mode else 0.24
	hq_camera = Camera3D.new()
	hq_camera.name = "Headquarters_Preview_Camera"
	hq_camera.fov = 52.0
	hq_camera.near = 0.1
	hq_camera.far = 650.0
	add_child(hq_camera)
	hq_camera.current = true
	_update_camera_transform()

func _configure_camera_framing(building_height: float) -> void:
	var config: Dictionary = LEVEL_CONFIGS[preview_level - 1]
	var building_width: float = float(config["width"])
	var building_depth: float = float(config["depth"])
	# Include the rooftop service equipment and parapet in the camera's framing bounds.
	var framing_height: float = building_height + 4.4
	var framing_center_y: float = 0.21 + framing_height * 0.5
	# Home shows the company grounds as well as the building; keep the camera close enough
	# to read the architecture while exposing the entrance, drive and nearby facilities.
	if home_mode:
		camera_target = Vector3(0.0, maxf(1.7, framing_center_y * 0.82), -1.0)
	else:
		camera_target = Vector3(0.0, framing_center_y, 0.0)
	# A bounding-sphere fit keeps the entire building visible at every camera yaw and pitch.
	# Vertical FOV is the limiting dimension on the landscape phone viewport.
	var half_width: float = building_width * 0.5 + 0.7
	var half_depth: float = building_depth * 0.5 + 0.7
	var half_height: float = framing_height * 0.5
	var framing_radius := Vector3(half_width, half_height, half_depth).length()
	var half_fov_radians := deg_to_rad(hq_camera.fov * 0.5) if is_instance_valid(hq_camera) else deg_to_rad(26.0)
	var fit_distance: float = framing_radius / sin(half_fov_radians)
	# The compound needs more breathing room than a single showroom building.
	camera_max_distance = maxf(27.0, fit_distance * 1.30) if home_mode else maxf(18.0, fit_distance * 1.18)
	# Reset on both initial load and every level switch to the calculated site/building view.
	camera_distance = camera_max_distance


func _build_procedural_building(level: int) -> float:
	var config: Dictionary = LEVEL_CONFIGS[clampi(level, 1, MAX_LEVEL) - 1]
	var floor_count: int = int(config["floors"])
	var style: int = int(config["style"])
	var width: float = float(config["width"])
	var depth: float = float(config["depth"])
	var ground_height: float = float(config["ground_height"])
	var floor_height: float = float(config["floor_height"])
	var height: float = ground_height + float(floor_count - 1) * floor_height

	building_root = Node3D.new()
	building_root.name = "Company_Headquarters_Level_%02d" % level
	add_child(building_root)

	var wall_colors: Array[Color] = [
		Color("#c2c0b5"), Color("#b9a991"), Color("#aab9bd"), Color("#c6c8c2"), Color("#9eaeb1")
	]
	var accent_colors: Array[Color] = [
		Color("#59636b"), Color("#665548"), Color("#303a43"), Color("#656b70"), Color("#505a63")
	]
	var wall := _mat(wall_colors[style], 0.86, 0.04)
	if style >= 3:
		wall = _mat(Color("#263139"), 0.28, 0.48)
	if level == 1:
		wall.albedo_color = Color("#8d9b9d")
		wall.roughness = 0.72
		wall.metallic = 0.22
	var podium := _mat(wall_colors[style].darkened(0.28), 0.72, 0.12)
	var accent := _mat(accent_colors[style], 0.42, 0.48)
	var roof := _mat(Color("#59636b"), 0.78, 0.26)
	wall.albedo_texture = facade_noise
	wall.uv1_scale = Vector3(2.8, 2.8, 1.0)
	wall.normal_enabled = true
	wall.normal_texture = facade_normal
	wall.normal_scale = 0.24
	wall.roughness_texture = facade_noise
	podium.albedo_texture = facade_noise
	podium.uv1_scale = Vector3(3.2, 3.2, 1.0)
	podium.normal_enabled = true
	podium.normal_texture = facade_normal
	podium.normal_scale = 0.3
	roof.albedo_texture = facade_noise
	roof.uv1_scale = Vector3(2.0, 2.0, 1.0)
	roof.normal_enabled = true
	roof.normal_texture = facade_normal
	roof.normal_scale = 0.2

	# Each purchased tier is a different architectural composition. The old
	# one-box envelope is deliberately gone: levels are rebuilt from distinct
	# wings, cores, atria, towers and bridges instead of simply stacking floors.
	match level:
		1:
			_create_headquarters_mass(building_root, "HQ_L01_Industrial_Workshop", Vector3.ZERO, Vector3(width, height, depth), 1, 0, false, wall, podium, accent, roof)
			_add_workshop_features(building_root, width, depth, height)
		2:
			_create_headquarters_mass(building_root, "HQ_L02_LShaped_Admin_Block", Vector3(-width * 0.12, 0.0, -depth * 0.02), Vector3(width * 0.68, height, depth * 0.96), 2, 1, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L02_Production_Wing", Vector3(width * 0.30, 0.0, depth * 0.14), Vector3(width * 0.38, height * 0.68, depth * 0.54), 2, 0, false, wall, podium, accent, roof)
		3:
			# Three blocks form a real U-shaped headquarters around an open court.
			_create_headquarters_mass(building_root, "HQ_L03_West_Lab_Wing", Vector3(-width * 0.30, 0.0, depth * 0.07), Vector3(width * 0.32, height, depth * 0.92), 3, 2, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L03_East_Office_Wing", Vector3(width * 0.30, 0.0, depth * 0.07), Vector3(width * 0.32, height, depth * 0.92), 3, 2, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L03_Rear_Connector", Vector3(0.0, 0.0, -depth * 0.34), Vector3(width * 0.78, height * 0.76, depth * 0.34), 2, 1, false, wall, podium, accent, roof)
		4:
			# A broad low podium supports an offset executive tower and a cantilever.
			_create_headquarters_mass(building_root, "HQ_L04_Stone_Podium", Vector3.ZERO, Vector3(width * 0.96, ground_height, depth * 0.94), 1, 0, false, podium, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L04_Offset_Office_Tower", Vector3(-width * 0.11, 0.0, -depth * 0.02), Vector3(width * 0.58, height * 0.86, depth * 0.70), 4, 2, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L04_Cantilevered_Executive_Wing", Vector3(width * 0.20, height * 0.56, -depth * 0.08), Vector3(width * 0.44, height * 0.30, depth * 0.54), 2, 3, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L04_Garden_Side_Wing", Vector3(width * 0.32, 0.0, depth * 0.23), Vector3(width * 0.28, height * 0.46, depth * 0.42), 2, 1, false, wall, podium, accent, roof)
		5:
			# A cross-shaped plan with a glazed atrium at its centre.
			_create_headquarters_mass(building_root, "HQ_L05_Central_Atrium_Tower", Vector3.ZERO, Vector3(width * 0.42, height, depth * 0.46), 5, 3, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L05_West_Executive_Wing", Vector3(-width * 0.31, 0.0, 0.0), Vector3(width * 0.34, height * 0.54, depth * 0.78), 3, 2, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L05_East_Operations_Wing", Vector3(width * 0.31, 0.0, 0.0), Vector3(width * 0.34, height * 0.48, depth * 0.78), 3, 2, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L05_Front_Forum_Wing", Vector3(0.0, 0.0, depth * 0.29), Vector3(width * 0.40, height * 0.40, depth * 0.30), 2, 1, false, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L05_Rear_Forum_Wing", Vector3(0.0, 0.0, -depth * 0.29), Vector3(width * 0.40, height * 0.40, depth * 0.30), 2, 1, false, wall, podium, accent, roof)
		6:
			# Two different-height towers are joined by an elevated glazed bridge.
			_create_headquarters_mass(building_root, "HQ_L06_Shared_Podium", Vector3.ZERO, Vector3(width * 0.94, ground_height, depth * 0.90), 1, 0, false, podium, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L06_West_Tower", Vector3(-width * 0.22, 0.0, 0.0), Vector3(width * 0.40, height * 0.78, depth * 0.78), 4, 3, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L06_East_Tower", Vector3(width * 0.22, 0.0, -depth * 0.02), Vector3(width * 0.40, height, depth * 0.78), 6, 3, true, wall, podium, accent, roof)
			_box(building_root, "HQ_L06_Sky_Bridge", Vector3(width * 0.48, 1.12, depth * 0.24), Vector3(0.0, height * 0.62, 0.0), materials["glass"])
		7:
			# An octagonal glass rotunda replaces the rectangular tower language.
			_create_hq_round_tower(building_root, "HQ_L07_Octagonal_Glass_Rotunda", Vector3(-width * 0.08, 0.0, -depth * 0.02), width * 0.205, height, 12)
			_create_headquarters_mass(building_root, "HQ_L07_South_Forum_Wing", Vector3(width * 0.27, 0.0, depth * 0.12), Vector3(width * 0.42, height * 0.42, depth * 0.66), 3, 2, false, podium, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L07_Glass_Link", Vector3(width * 0.15, height * 0.28, -depth * 0.02), Vector3(width * 0.30, height * 0.16, depth * 0.24), 1, 3, true, wall, podium, accent, roof)
		8:
			# Offset high-rise wings use visibly different heights and floor plates.
			_create_headquarters_mass(building_root, "HQ_L08_West_Glass_Tower", Vector3(-width * 0.23, 0.0, -depth * 0.05), Vector3(width * 0.38, height, depth * 0.54), 8, 3, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L08_East_Solid_Tower", Vector3(width * 0.22, 0.0, depth * 0.08), Vector3(width * 0.34, height * 0.76, depth * 0.62), 6, 2, false, wall, podium, accent, roof)
			_box(building_root, "HQ_L08_Upper_Sky_Lobby", Vector3(width * 0.54, 1.35, depth * 0.22), Vector3(0.0, height * 0.66, -depth * 0.04), materials["glass"])
			_create_headquarters_mass(building_root, "HQ_L08_Entrance_Pavilion", Vector3(0.0, 0.0, depth * 0.28), Vector3(width * 0.58, height * 0.28, depth * 0.24), 2, 1, false, podium, podium, accent, roof)
		9:
			# Three independent towers make a skyline, not one taller slab.
			_create_headquarters_mass(building_root, "HQ_L09_Central_Signature_Tower", Vector3(0.0, 0.0, -depth * 0.04), Vector3(width * 0.28, height, depth * 0.44), 9, 4, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L09_West_Tower", Vector3(-width * 0.29, 0.0, depth * 0.02), Vector3(width * 0.27, height * 0.78, depth * 0.54), 7, 3, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L09_East_Tower", Vector3(width * 0.29, 0.0, depth * 0.02), Vector3(width * 0.27, height * 0.88, depth * 0.50), 8, 2, false, wall, podium, accent, roof)
			_box(building_root, "HQ_L09_West_Sky_Bridge", Vector3(width * 0.34, 0.92, depth * 0.20), Vector3(-width * 0.14, height * 0.46, 0.0), materials["glass"])
			_box(building_root, "HQ_L09_East_Sky_Bridge", Vector3(width * 0.34, 0.92, depth * 0.20), Vector3(width * 0.14, height * 0.64, 0.0), materials["glass"])
		10:
			# Flagship tier: a circular atrium, two unequal wings and a large shared podium.
			_create_headquarters_mass(building_root, "HQ_L10_Flagship_Podium", Vector3.ZERO, Vector3(width * 0.96, ground_height, depth * 0.94), 1, 1, false, podium, podium, accent, roof)
			_create_hq_round_tower(building_root, "HQ_L10_Central_Glass_Atrium", Vector3(0.0, 0.0, -depth * 0.02), width * 0.19, height, 16)
			_create_headquarters_mass(building_root, "HQ_L10_West_Research_Wing", Vector3(-width * 0.29, 0.0, 0.03), Vector3(width * 0.34, height * 0.72, depth * 0.66), 7, 3, true, wall, podium, accent, roof)
			_create_headquarters_mass(building_root, "HQ_L10_East_Operations_Wing", Vector3(width * 0.29, 0.0, depth * 0.04), Vector3(width * 0.34, height * 0.58, depth * 0.70), 6, 2, false, wall, podium, accent, roof)
			_box(building_root, "HQ_L10_Atrium_Sky_Bridge", Vector3(width * 0.52, 1.15, depth * 0.20), Vector3(0.0, height * 0.54, 0.0), materials["glass"])

	# These recognizable tier details are retained, but they now decorate a
	# genuinely different base design at every level.
	if level > 1:
		_add_level_silhouette_features(building_root, level, width, depth, height, accent, roof)
	_box(building_root, "Company_Headquarters_Sign", Vector3(width * 0.55, 0.42, 0.12), Vector3(0.0, ground_height + 0.48, depth * 0.5 + 0.24), materials["hq_sign"])
	_box(building_root, "Company_Sign_Accent", Vector3(width * 0.48, 0.045, 0.035), Vector3(0.0, ground_height + 0.25, depth * 0.5 + 0.31), materials["hq_accent"])
	return height


func _create_headquarters_mass(parent: Node3D, node_name: String, origin: Vector3, dimensions: Vector3, floors: int, style: int, glass_facade: bool, wall: Material, podium: Material, accent: Material, roof: Material) -> Node3D:
	var mass_root := Node3D.new()
	mass_root.name = node_name
	mass_root.position = origin
	parent.add_child(mass_root)

	var width: float = dimensions.x
	var height: float = dimensions.y
	var depth: float = dimensions.z
	var facade_floors: int = maxi(2, floors)
	var podium_height: float = minf(height * 0.42, 3.15)
	var upper_floor_height: float = maxf(0.8, (height - podium_height) / float(facade_floors - 1))

	_box(mass_root, node_name + "_Foundation", Vector3(width + 0.50, 0.36, depth + 0.50), Vector3(0.0, 0.18, 0.0), materials["concrete"])
	_box(mass_root, node_name + "_Architectural_Mass", Vector3(width, height, depth), Vector3(0.0, height * 0.5 + 0.36, 0.0), wall)
	_box(mass_root, node_name + "_Ground_Floor_Podium", Vector3(width + 0.10, podium_height, depth + 0.10), Vector3(0.0, podium_height * 0.5 + 0.36, 0.0), podium)
	_box(mass_root, node_name + "_Roof_Slab", Vector3(width + 0.34, 0.24, depth + 0.34), Vector3(0.0, height + 0.48, 0.0), roof)

	if glass_facade:
		_add_glass_curtain_wall(mass_root, width, depth, facade_floors, podium_height, upper_floor_height)
	else:
		for side in range(4):
			var angle := float(side) * PI * 0.5
			_add_facade_windows(mass_root, angle, width, depth, facade_floors, podium_height, upper_floor_height, style)
			_add_facade_pilasters(mass_root, angle, width, depth, height, accent, style)

	for floor_index in range(1, floors):
		var floor_y := 0.42 + podium_height + float(floor_index - 1) * upper_floor_height
		_box(mass_root, node_name + "_Expressed_Floor_Slab", Vector3(width + 0.18, 0.10, depth + 0.18), Vector3(0.0, floor_y, 0.0), accent)
	return mass_root


func _create_hq_round_tower(parent: Node3D, node_name: String, origin: Vector3, radius: float, height: float, radial_segments: int) -> Node3D:
	var tower_root := Node3D.new()
	tower_root.name = node_name
	tower_root.position = origin
	parent.add_child(tower_root)
	_cylinder(tower_root, node_name + "_Foundation", radius + 0.42, radius + 0.42, 0.34, Vector3(0.0, 0.17, 0.0), materials["concrete"])

	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = radius
	shell_mesh.bottom_radius = radius
	shell_mesh.height = height
	shell_mesh.radial_segments = radial_segments
	var shell := MeshInstance3D.new()
	shell.name = node_name + "_Glazed_Shell"
	shell.mesh = shell_mesh
	shell.position = Vector3(0.0, height * 0.5 + 0.34, 0.0)
	shell.material_override = materials["glass"]
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	tower_root.add_child(shell)

	for index in range(radial_segments):
		var angle := TAU * float(index) / float(radial_segments)
		var mullion := _box(tower_root, node_name + "_Vertical_Aluminium_Mullion", Vector3(0.075, height, 0.12), Vector3(cos(angle) * radius, height * 0.5 + 0.34, sin(angle) * radius), materials["glass_mullion"])
		mullion.rotation.y = -angle
		for floor_index in range(1, maxi(2, int(round(height / 3.2)))):
			if index == 0:
				_cylinder(tower_root, node_name + "_Glazing_Floor_Band", radius + 0.055, radius + 0.055, 0.075, Vector3(0.0, 0.34 + float(floor_index) * height / float(maxi(2, int(round(height / 3.2)))), 0.0), materials["glass_spandrel"])
	_cylinder(tower_root, node_name + "_Roof_Crown", radius + 0.24, radius + 0.24, 0.24, Vector3(0.0, height + 0.48, 0.0), materials["metal"])
	return tower_root

func _add_workshop_features(parent: Node3D, width: float, depth: float, height: float) -> void:
	var front_z := depth * 0.5 + 0.16
	_box(parent, "Workshop_Loading_Bay_Frame", Vector3(width * 0.48, 2.9, 0.22), Vector3(0.0, 1.78, front_z), materials["dark_metal"])
	_box(parent, "Workshop_Rollup_Shutter", Vector3(width * 0.45, 2.72, 0.08), Vector3(0.0, 1.76, front_z + 0.14), materials["workshop_shutter"])
	for slat in range(9):
		var y := 0.55 + float(slat) * 0.28
		_box(parent, "Workshop_Shutter_Slat", Vector3(width * 0.43, 0.035, 0.035), Vector3(0.0, y, front_z + 0.20), materials["metal"])
	_box(parent, "Workshop_Personnel_Door", Vector3(0.95, 2.45, 0.12), Vector3(-width * 0.36, 1.62, front_z + 0.12), materials["dark_metal"])
	_box(parent, "Workshop_Door_Glazing", Vector3(0.58, 0.82, 0.035), Vector3(-width * 0.36, 2.05, front_z + 0.20), materials["glass"])
	for side in [-1.0, 1.0]:
		_box(parent, "Workshop_Clerestory_Frame", Vector3(1.62, 0.72, 0.10), Vector3(side * width * 0.29, height - 0.95, front_z + 0.02), materials["window_frame"])
		_box(parent, "Workshop_Clerestory_Glass", Vector3(1.45, 0.58, 0.08), Vector3(side * width * 0.29, height - 0.95, front_z + 0.07), materials["glass"])
	var roof_panel := _box(parent, "Workshop_Metal_Roof_Cap", Vector3(width + 0.75, 0.28, depth + 0.75), Vector3(0.0, height + 0.35, 0.0), materials["roof"])
	roof_panel.rotation_degrees.z = -1.2
	for rib in range(7):
		var x := (float(rib) - 3.0) * (width / 7.0)
		_box(parent, "Workshop_Roof_Rib", Vector3(0.055, 0.07, depth + 0.55), Vector3(x, height + 0.51, 0.0), materials["metal"])
	_box(parent, "Workshop_Front_Canopy", Vector3(width * 0.58, 0.16, 1.15), Vector3(0.0, 3.45, front_z + 0.52), materials["dark_metal"])

func _add_level_silhouette_features(parent: Node3D, level: int, width: float, depth: float, height: float, accent: Material, roof: Material) -> void:
	# Each tier has a different architectural massing profile, rather than only stacking a floor.
	if level == 1:
		_facility_box(parent, "Workshop_Raised_Roof_Monitor", Vector3(width * 0.42, 0.58, depth * 0.24), Vector3(0.0, height + 0.66, -depth * 0.12), materials["window_frame"])
		_facility_box(parent, "Workshop_Monitor_Glazing", Vector3(width * 0.38, 0.38, depth * 0.20), Vector3(0.0, height + 0.68, -depth * 0.12), materials["glass"])
		_box(parent, "Workshop_Extraction_Stack", Vector3(0.48, 0.90, 0.48), Vector3(width * 0.34, height + 0.78, -depth * 0.28), materials["metal"])
	elif level == 2:
		_facility_box(parent, "Level02_External_Stair_Core", Vector3(width * 0.20, height * 0.76, depth * 0.30), Vector3(-width * 0.34, 0.42 + height * 0.48, -depth * 0.20), roof)
		for tier in range(2):
			_facility_box(parent, "Level02_Stair_Core_Glazing", Vector3(width * 0.18, 0.72, 0.05), Vector3(-width * 0.34, 1.45 + float(tier) * 1.55, depth * 0.5 + 0.22), materials["glass"])
		_facility_box(parent, "Level02_Entry_Canopy", Vector3(width * 0.72, 0.18, 1.25), Vector3(0.0, 3.65, depth * 0.5 + 0.64), accent)
	elif level == 3:
		_facility_box(parent, "Level03_Corner_Penthouse", Vector3(width * 0.38, 1.50, depth * 0.42), Vector3(width * 0.24, height + 1.15, -depth * 0.16), roof)
		_facility_box(parent, "Level03_Penthouse_Glass", Vector3(width * 0.34, 1.14, depth * 0.38), Vector3(width * 0.24, height + 1.17, -depth * 0.16), materials["glass"])
		_facility_box(parent, "Level03_Roof_Terrace_Canopy", Vector3(width * 0.66, 0.14, depth * 0.36), Vector3(-width * 0.14, height + 0.68, depth * 0.14), materials["metal"])
	elif level == 4:
		_facility_box(parent, "Level04_Cantilevered_Executive_Block", Vector3(width * 0.76, 1.18, depth * 0.60), Vector3(-width * 0.08, height + 0.78, -depth * 0.08), roof)
		_facility_box(parent, "Level04_Executive_Glazing_Band", Vector3(width * 0.70, 0.48, 0.055), Vector3(-width * 0.08, height + 0.82, depth * 0.23), materials["glass"])
		_facility_box(parent, "Level04_Deep_Entrance_Canopy", Vector3(width * 0.58, 0.20, 1.60), Vector3(0.0, 3.90, depth * 0.5 + 0.72), accent)
	elif level == 5:
		_facility_box(parent, "Level05_Central_Atrium_Tower", Vector3(width * 0.34, 2.25, depth * 0.38), Vector3(0.0, height + 1.43, -depth * 0.12), materials["window_frame"])
		_facility_box(parent, "Level05_Atrium_Glazing", Vector3(width * 0.30, 1.96, depth * 0.34), Vector3(0.0, height + 1.45, -depth * 0.12), materials["glass"])
		for side in [-1.0, 1.0]:
			_facility_box(parent, "Level05_Stepback_Terrace_Wall", Vector3(width * 0.30, 0.46, depth * 0.24), Vector3(side * width * 0.32, height + 0.22, depth * 0.18), accent)
	elif level == 6:
		for side in [-1.0, 1.0]:
			_facility_box(parent, "Level06_Twin_Structural_Core", Vector3(width * 0.20, 2.05, depth * 0.40), Vector3(side * width * 0.34, height + 1.30, -depth * 0.12), roof)
			_facility_box(parent, "Level06_Core_Window_Slot", Vector3(width * 0.16, 1.60, 0.05), Vector3(side * width * 0.34, height + 1.30, depth * 0.09), materials["glass"])
		_facility_box(parent, "Level06_Crown_Bridge", Vector3(width * 0.60, 0.34, depth * 0.32), Vector3(0.0, height + 2.46, -depth * 0.12), accent)
	elif level == 7:
		_facility_box(parent, "Level07_Glazed_Corner_Atrium", Vector3(width * 0.42, 2.65, depth * 0.46), Vector3(-width * 0.23, height + 1.60, -depth * 0.10), materials["window_frame"])
		_facility_box(parent, "Level07_Atrium_Glass", Vector3(width * 0.38, 2.35, depth * 0.42), Vector3(-width * 0.23, height + 1.62, -depth * 0.10), materials["glass"])
		_facility_box(parent, "Level07_Suspended_Entry_Canopy", Vector3(width * 0.76, 0.16, 1.55), Vector3(0.0, 4.30, depth * 0.5 + 0.70), materials["metal"])
	elif level == 8:
		_facility_box(parent, "Level08_East_Upper_Wing", Vector3(width * 0.46, 1.25, depth * 0.62), Vector3(width * 0.25, height + 0.78, -depth * 0.08), roof)
		_facility_box(parent, "Level08_West_Glass_Wing", Vector3(width * 0.38, 1.75, depth * 0.46), Vector3(-width * 0.27, height + 1.04, -depth * 0.12), materials["window_frame"])
		_facility_box(parent, "Level08_West_Wing_Glazing", Vector3(width * 0.34, 1.40, depth * 0.42), Vector3(-width * 0.27, height + 1.06, -depth * 0.12), materials["glass"])
		_facility_box(parent, "Level08_Sky_Lobby_Link", Vector3(width * 0.35, 0.60, depth * 0.18), Vector3(0.0, height + 0.75, depth * 0.18), materials["glass"])
	elif level == 9:
		for side in [-1.0, 1.0]:
			_facility_box(parent, "Level09_Crown_Tower", Vector3(width * 0.25, 2.30, depth * 0.38), Vector3(side * width * 0.26, height + 1.40, -depth * 0.12), materials["window_frame"])
			_facility_box(parent, "Level09_Crown_Tower_Glass", Vector3(width * 0.21, 1.95, depth * 0.34), Vector3(side * width * 0.26, height + 1.42, -depth * 0.12), materials["glass"])
		_facility_box(parent, "Level09_Sky_Lounge_Bridge", Vector3(width * 0.64, 0.58, depth * 0.24), Vector3(0.0, height + 1.22, depth * 0.10), accent)
		_facility_box(parent, "Level09_Roof_Halo", Vector3(width * 0.78, 0.18, depth * 0.70), Vector3(0.0, height + 2.72, -depth * 0.08), materials["metal"])
	elif level == 10:
		_facility_box(parent, "Level10_West_Flagship_Wing", Vector3(width * 0.36, 1.85, depth * 0.62), Vector3(-width * 0.31, height + 1.08, -depth * 0.08), roof)
		_facility_box(parent, "Level10_East_Glazed_Wing", Vector3(width * 0.34, 2.35, depth * 0.54), Vector3(width * 0.31, height + 1.34, -depth * 0.08), materials["window_frame"])
		_facility_box(parent, "Level10_East_Wing_Glazing", Vector3(width * 0.30, 2.02, depth * 0.50), Vector3(width * 0.31, height + 1.36, -depth * 0.08), materials["glass"])
		_facility_box(parent, "Level10_Central_Crown_Tower", Vector3(width * 0.30, 3.20, depth * 0.38), Vector3(0.0, height + 2.10, -depth * 0.10), materials["window_frame"])
		_facility_box(parent, "Level10_Crown_Glazing", Vector3(width * 0.26, 2.84, depth * 0.34), Vector3(0.0, height + 2.12, -depth * 0.10), materials["glass"])
		_facility_box(parent, "Level10_Cantilevered_Crown_Cap", Vector3(width * 0.72, 0.20, depth * 0.52), Vector3(0.0, height + 3.82, -depth * 0.10), accent)
func _rebuild_preview() -> void:
	if is_instance_valid(building_root):
		building_root.queue_free()
	building_root = null
	var height := 4.2
	if not home_mode or owned_level > 0:
		height = _build_procedural_building(preview_level)
	_update_compound_facilities_visibility()
	_configure_camera_framing(height)
	_update_camera_transform()
	_refresh_preview_interface()
	preview_level_changed.emit(preview_level)

func _show_previous_level() -> void:
	if preview_level <= 1:
		return
	preview_level -= 1
	_update_downgrade_refund_roll()
	_rebuild_preview()

func _show_next_level() -> void:
	if preview_level >= MAX_LEVEL:
		return
	preview_level = mini(preview_level + 1, MAX_LEVEL)
	_update_downgrade_refund_roll()
	_rebuild_preview()


func _update_downgrade_refund_roll() -> void:
	if preview_level < owned_level:
		downgrade_refund_percent = randi_range(50, 60)

func _create_preview_interface() -> void:
	preview_interface_layer = CanvasLayer.new()
	preview_interface_layer.name = "Headquarters_Preview_Interface"
	preview_interface_layer.layer = 20
	add_child(preview_interface_layer)
	var layer := preview_interface_layer

	# Home intentionally has no text overlay above the building. The Buildings
	# page gets one clean, bold architectural level title instead of the old card.	
	level_info_label = null
	owned_info_label = null
	if not home_mode:
		level_info_label = Label.new()
		level_info_label.name = "Office_Building_Level_Hero"
		level_info_label.anchor_left = 0.08
		level_info_label.anchor_top = 0.0
		level_info_label.anchor_right = 0.92
		level_info_label.anchor_bottom = 0.0
		level_info_label.offset_top = 20.0
		level_info_label.offset_bottom = 82.0
		level_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_preview_typography(level_info_label, 36)
		level_info_label.add_theme_color_override("font_color", Color("#ffffff"))
		level_info_label.add_theme_color_override("font_outline_color", Color("#062b18"))
		level_info_label.add_theme_constant_override("outline_size", 5)
		level_info_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.025, 0.10, 0.95))
		level_info_label.add_theme_constant_override("shadow_offset_x", 2)
		level_info_label.add_theme_constant_override("shadow_offset_y", 4)
		var hero_font := FontVariation.new()
		hero_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		hero_font.variation_embolden = 1.0
		level_info_label.add_theme_font_override("font", hero_font)
		layer.add_child(level_info_label)

		staff_capacity_label = Label.new()
		staff_capacity_label.name = "Office_Building_Staff_Capacity"
		staff_capacity_label.anchor_left = 0.12
		staff_capacity_label.anchor_top = 0.0
		staff_capacity_label.anchor_right = 0.88
		staff_capacity_label.anchor_bottom = 0.0
		staff_capacity_label.offset_top = 78.0
		staff_capacity_label.offset_bottom = 116.0
		staff_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		staff_capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_apply_preview_typography(staff_capacity_label, 23)
		staff_capacity_label.add_theme_color_override("font_color", Color("#d8f3dc"))
		staff_capacity_label.add_theme_color_override("font_outline_color", Color("#062b18"))
		staff_capacity_label.add_theme_constant_override("outline_size", 4)
		var staff_font := FontVariation.new()
		staff_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		staff_font.variation_embolden = 0.7
		staff_capacity_label.add_theme_font_override("font", staff_font)
		layer.add_child(staff_capacity_label)

		var staff_market_button := Button.new()
		staff_market_button.name = "Headquarters_Staff_Market_Button"
		staff_market_button.text = "STAFF MARKET"
		staff_market_button.anchor_left = 1.0
		staff_market_button.anchor_top = 0.0
		staff_market_button.anchor_right = 1.0
		staff_market_button.anchor_bottom = 0.0
		staff_market_button.offset_left = -340.0
		staff_market_button.offset_top = 20.0
		staff_market_button.offset_right = -196.0
		staff_market_button.offset_bottom = 64.0
		_apply_preview_typography(staff_market_button, 15)
		_style_preview_button(staff_market_button, true)
		staff_market_button.pressed.connect(func(): staff_market_requested.emit())
		layer.add_child(staff_market_button)

		var staff_management_button := Button.new()
		staff_management_button.name = "Headquarters_Staff_Management_Button"
		staff_management_button.text = "STAFF MANAGEMENT"
		staff_management_button.anchor_left = 1.0
		staff_management_button.anchor_top = 0.0
		staff_management_button.anchor_right = 1.0
		staff_management_button.anchor_bottom = 0.0
		staff_management_button.offset_left = -188.0
		staff_management_button.offset_top = 20.0
		staff_management_button.offset_right = -44.0
		staff_management_button.offset_bottom = 64.0
		_apply_preview_typography(staff_management_button, 15)
		_style_preview_button(staff_management_button, false)
		staff_management_button.pressed.connect(func(): staff_management_requested.emit())
		layer.add_child(staff_management_button)

	if not home_mode:
		previous_level_button = _create_side_level_button(layer, "Previous_Level_Button", "‹", true)
		previous_level_button.pressed.connect(_show_previous_level)
		next_level_button = _create_side_level_button(layer, "Next_Level_Button", "›", false)
		next_level_button.pressed.connect(_show_next_level)

		var back_button := _create_bottom_action_button(layer, "Back", false)
		back_button.name = "Headquarters_Back_Button"
		back_button.anchor_left = 0.0
		back_button.anchor_top = 1.0
		back_button.anchor_right = 0.0
		back_button.anchor_bottom = 1.0
		back_button.offset_left = 18.0
		back_button.offset_top = -76.0
		back_button.offset_right = 146.0
		back_button.offset_bottom = -18.0
		back_button.pressed.connect(func(): back_requested.emit())

		upgrade_button = _create_bottom_action_button(layer, "Upgrade", true)
		upgrade_button.name = "Headquarters_Upgrade_Button"
		upgrade_button.anchor_left = 1.0
		upgrade_button.anchor_top = 1.0
		upgrade_button.anchor_right = 1.0
		upgrade_button.anchor_bottom = 1.0
		upgrade_button.offset_left = -146.0
		upgrade_button.offset_top = -76.0
		upgrade_button.offset_right = -18.0
		upgrade_button.offset_bottom = -18.0
		upgrade_button.pressed.connect(func(): upgrade_requested.emit(preview_level))

		downgrade_button = _create_bottom_action_button(layer, "Downgrade", false)
		downgrade_button.name = "Headquarters_Downgrade_Button"
		downgrade_button.anchor_left = 1.0
		downgrade_button.anchor_top = 1.0
		downgrade_button.anchor_right = 1.0
		downgrade_button.anchor_bottom = 1.0
		downgrade_button.offset_left = -284.0
		downgrade_button.offset_top = -76.0
		downgrade_button.offset_right = -156.0
		downgrade_button.offset_bottom = -18.0
		downgrade_button.pressed.connect(func(): downgrade_requested.emit(preview_level, downgrade_refund_percent))

		var cost_panel := PanelContainer.new()
		cost_panel.name = "Headquarters_Upgrade_Finance_Panel"
		cost_panel.anchor_left = 1.0
		cost_panel.anchor_top = 1.0
		cost_panel.anchor_right = 1.0
		cost_panel.anchor_bottom = 1.0
		cost_panel.offset_left = -286.0
		cost_panel.offset_top = -174.0
		cost_panel.offset_right = -18.0
		cost_panel.offset_bottom = -84.0
		var cost_style := StyleBoxFlat.new()
		cost_style.bg_color = Color(0.018, 0.075, 0.035, 0.90)
		cost_style.border_color = Color(0.35, 0.72, 0.91, 0.78)
		cost_style.set_border_width_all(1)
		cost_style.set_corner_radius_all(10)
		cost_style.content_margin_left = 10.0
		cost_style.content_margin_right = 10.0
		cost_style.content_margin_top = 6.0
		cost_style.content_margin_bottom = 6.0
		cost_panel.add_theme_stylebox_override("panel", cost_style)
		layer.add_child(cost_panel)

		var finance_stack := VBoxContainer.new()
		finance_stack.add_theme_constant_override("separation", 3)
		cost_panel.add_child(finance_stack)

		upgrade_cost_label = Label.new()
		upgrade_cost_label.name = "Headquarters_Upgrade_Cost"
		_apply_preview_typography(upgrade_cost_label, 17)
		upgrade_cost_label.add_theme_color_override("font_color", Color("#ffffff"))
		upgrade_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		finance_stack.add_child(upgrade_cost_label)

		monthly_rent_label = Label.new()
		monthly_rent_label.name = "Headquarters_Monthly_Rent"
		_apply_preview_typography(monthly_rent_label, 15)
		monthly_rent_label.add_theme_color_override("font_color", Color("#f4d58a"))
		monthly_rent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		finance_stack.add_child(monthly_rent_label)

		available_balance_label = Label.new()
		available_balance_label.name = "Headquarters_Available_Balance"
		_apply_preview_typography(available_balance_label, 15)
		available_balance_label.add_theme_color_override("font_color", Color("#b9e8c1"))
		available_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		finance_stack.add_child(available_balance_label)

	_refresh_preview_interface()


func _apply_preview_typography(control: Control, font_size: int) -> void:
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 0.7
	control.add_theme_font_override("font", stix_font)
	control.add_theme_font_size_override("font_size", font_size)


func _create_bottom_action_button(parent: Node, caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(128.0, 58.0)
	_apply_preview_typography(button, 16)
	_style_preview_button(button, primary)
	parent.add_child(button)
	return button


func set_home_mode(active: bool) -> void:
	# Returning from Staff must not reconstruct the same building and compound.
	# Only a real Home/Office mode change rebuilds the preview and its controls.
	if home_mode == active:
		return

	home_mode = active
	camera_pitch = 0.42 if active else 0.24
	preview_level = maxi(owned_level, 1)
	_update_compound_facilities_visibility()

	# Dispose of the old mode's interface before creating the new one. Reset every
	# reference so no freed control can be updated by the next preview refresh.
	if is_instance_valid(preview_interface_layer):
		preview_interface_layer.queue_free()
	preview_interface_layer = null
	level_info_label = null
	staff_capacity_label = null
	owned_info_label = null
	previous_level_button = null
	next_level_button = null
	upgrade_button = null
	downgrade_button = null
	upgrade_cost_label = null
	monthly_rent_label = null
	available_balance_label = null

	_rebuild_preview()
	_create_preview_interface()


func set_owned_level(level: int) -> void:
	owned_level = clampi(level, 0, MAX_LEVEL)
	if home_mode:
		preview_level = maxi(owned_level, 1)
	_update_compound_facilities_visibility()
	_rebuild_preview()


func _update_compound_facilities_visibility() -> void:
	if not is_instance_valid(compound_facilities_root):
		return
	var should_show := not home_mode or owned_level > 0
	compound_facilities_root.visible = should_show
	if not should_show:
		return

	var compound_level: int = maxi(owned_level, 1) if home_mode else clampi(preview_level, 1, MAX_LEVEL)
	if compound_facilities_level == compound_level and compound_facilities_root.get_child_count() > 0:
		return

	for existing_building in compound_facilities_root.get_children():
		existing_building.free()
	_create_compound_facilities(compound_facilities_root, compound_level)
	compound_facilities_level = compound_level

func set_preview_active(active: bool) -> void:
	# CanvasLayer is rendered independently of the Node3D visibility tree, so
	# hide both the 3D preview and its interface while another screen is open.
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(preview_interface_layer):
		preview_interface_layer.visible = active


func _create_side_level_button(parent: Node, node_name: String, glyph: String, left_side: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = glyph
	button.tooltip_text = "Preview previous headquarters level" if left_side else "Preview next headquarters level"
	button.anchor_left = 0.0 if left_side else 1.0
	button.anchor_top = 0.5
	button.anchor_right = 0.0 if left_side else 1.0
	button.anchor_bottom = 0.5
	button.offset_left = 16.0 if left_side else -88.0
	button.offset_top = -42.0
	button.offset_right = 88.0 if left_side else -16.0
	button.offset_bottom = 42.0
	button.add_theme_font_size_override("font_size", 44)
	_style_preview_button(button, true)
	parent.add_child(button)
	return button

func _refresh_preview_interface() -> void:
	if is_instance_valid(level_info_label):
		level_info_label.text = "%s  /  LEVEL %d" % [str(LEVEL_CONFIGS[preview_level - 1]["name"]).to_upper(), preview_level]
	if is_instance_valid(staff_capacity_label):
		staff_capacity_label.text = "STAFF CAPACITY: %d WORKERS" % _get_staff_capacity(preview_level)
	if is_instance_valid(previous_level_button):
		previous_level_button.disabled = preview_level <= 1
	if is_instance_valid(next_level_button):
		next_level_button.disabled = preview_level >= MAX_LEVEL
	var upgrade_cost := get_upgrade_cost(preview_level)
	var can_afford_upgrade := company_balance >= upgrade_cost
	var downgrade_refund := float(get_upgrade_cost(owned_level)) * float(downgrade_refund_percent) / 100.0
	if is_instance_valid(upgrade_button):
		upgrade_button.text = "PURCHASED" if preview_level <= owned_level and owned_level > 0 else "PURCHASE"
	if is_instance_valid(upgrade_cost_label):
		if preview_level < owned_level:
			upgrade_cost_label.text = "DOWNGRADE REFUND (%d%%): %s" % [downgrade_refund_percent, _format_money(downgrade_refund)]
			upgrade_cost_label.add_theme_color_override("font_color", Color("#8ff0bd"))
		elif preview_level == owned_level and owned_level > 0:
			upgrade_cost_label.text = "CURRENT HEADQUARTERS"
			upgrade_cost_label.add_theme_color_override("font_color", Color("#b9e8c1"))
		else:
			var cost_caption := "PURCHASE COST" if owned_level == 0 and preview_level == 1 else "UPGRADE COST"
			upgrade_cost_label.text = "%s: %s" % [cost_caption, _format_money(upgrade_cost)]
			upgrade_cost_label.add_theme_color_override("font_color", Color("#ffffff") if can_afford_upgrade else Color("#ffb5a8"))
	if is_instance_valid(monthly_rent_label):
		monthly_rent_label.text = "MONTHLY RENT: %s" % _format_money(get_monthly_rent(preview_level))
	if is_instance_valid(available_balance_label):
		available_balance_label.text = "BALANCE: %s" % _format_money(company_balance)
		available_balance_label.add_theme_color_override("font_color", Color("#b9e8c1") if can_afford_upgrade or preview_level <= owned_level else Color("#ffb5a8"))
	if is_instance_valid(upgrade_button):
		upgrade_button.disabled = preview_level <= owned_level or not can_afford_upgrade
	if is_instance_valid(downgrade_button):
		downgrade_button.disabled = owned_level <= 0 or preview_level >= owned_level


func _get_staff_capacity(level: int) -> int:
	return STAFF_CAPACITIES[clampi(level, 1, MAX_LEVEL) - 1]


static func get_staff_capacity(level: int) -> int:
	if level <= 0:
		return 0
	return STAFF_CAPACITIES[clampi(level, 1, MAX_LEVEL) - 1]


static func get_upgrade_cost(level: int) -> int:
	return UPGRADE_COSTS[clampi(level, 1, MAX_LEVEL) - 1]


static func get_monthly_rent(level: int) -> float:
	return float(MONTHLY_RENTS[clampi(level, 1, MAX_LEVEL) - 1])


func set_company_balance(amount: float) -> void:
	company_balance = maxf(0.0, amount)
	_refresh_preview_interface()


func _format_money(amount: float) -> String:
	var digits := str(roundi(amount))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted


func _style_preview_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#155c2b") if primary else Color(0.035, 0.12, 0.045, 0.90)
		if state == "hover":
			style.bg_color = Color("#21843a") if primary else Color("#1b5b2a")
		elif state == "pressed":
			style.bg_color = Color("#0c3c19")
		elif state == "disabled":
			style.bg_color = Color(0.10, 0.18, 0.22, 0.55)
		style.border_color = Color("#8bd696") if primary else Color("#4aa85b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 7.0
		style.content_margin_bottom = 7.0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#8ea4ad"))

func _unhandled_input(event: InputEvent) -> void:
	# Preview camera: one-finger orbit; two-finger pan and pinch zoom.
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
		return
	if event is InputEventScreenDrag and touch_points.has(event.index):
		if touch_points.size() == 1:
			_orbit_camera(event.relative)
		elif touch_points.size() >= 2:
			var old_points := touch_points.values()
			var old_midpoint := ((old_points[0] as Vector2) + (old_points[1] as Vector2)) * 0.5
			var old_distance := (old_points[0] as Vector2).distance_to(old_points[1] as Vector2)
			touch_points[event.index] = event.position
			var new_points := touch_points.values()
			var new_midpoint := ((new_points[0] as Vector2) + (new_points[1] as Vector2)) * 0.5
			var new_distance := (new_points[0] as Vector2).distance_to(new_points[1] as Vector2)
			_pan_camera(new_midpoint - old_midpoint)
			_zoom_camera((old_distance - new_distance) * 0.12)
		touch_points[event.index] = event.position
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-7.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(7.0)
		return
	if event is InputEventMouseMotion:
		if mouse_orbiting:
			_orbit_camera(event.relative)
		elif mouse_panning:
			_pan_camera(event.relative)

func _orbit_camera(relative: Vector2) -> void:
	camera_yaw -= relative.x * 0.0045
	camera_pitch = clampf(camera_pitch + relative.y * 0.0035, 0.12, 1.22)
	_update_camera_transform()

func _pan_camera(relative: Vector2) -> void:
	if not is_instance_valid(hq_camera):
		return
	var pan_scale := camera_distance * 0.0016
	var camera_right := hq_camera.global_transform.basis.x
	camera_target -= camera_right * relative.x * pan_scale
	camera_target += Vector3.UP * relative.y * pan_scale
	camera_target.x = clampf(camera_target.x, -32.0, 32.0)
	camera_target.z = clampf(camera_target.z, -32.0, 32.0)
	camera_target.y = clampf(camera_target.y, 0.0, 150.0)
	_update_camera_transform()

func _zoom_camera(amount: float) -> void:
	camera_distance = clampf(camera_distance + amount, 10.0, camera_max_distance)
	_update_camera_transform()

func _update_camera_transform() -> void:
	if not is_instance_valid(hq_camera):
		return
	var horizontal_distance := cos(camera_pitch) * camera_distance
	var camera_offset := Vector3(
		sin(camera_yaw) * horizontal_distance,
		sin(camera_pitch) * camera_distance,
		cos(camera_yaw) * horizontal_distance
	)
	hq_camera.global_position = camera_target + camera_offset
	hq_camera.look_at(camera_target, Vector3.UP)

func _add_glass_curtain_wall(parent: Node3D, width: float, depth: float, floors: int, ground_height: float, floor_height: float) -> void:
	# A continuous glazed skin wraps all four sides; repeated panels and mullions are batched for mobile.
	for side in range(4):
		var angle := float(side) * PI * 0.5
		var side_basis := Basis(Vector3.UP, angle)
		var side_width: float = width if side % 2 == 0 else depth
		var side_depth: float = depth if side % 2 == 0 else width
		var columns: int = maxi(4, int(round(side_width / 3.2)))
		var panel_width: float = side_width / float(columns)
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(panel_width - 0.10, 1.0, 0.10)
		var spandrel_mesh := BoxMesh.new()
		spandrel_mesh.size = Vector3(panel_width - 0.10, 0.16, 0.13)
		var vertical_mesh := BoxMesh.new()
		vertical_mesh.size = Vector3(0.085, ground_height + float(floors - 1) * floor_height, 0.20)
		var horizontal_mesh := BoxMesh.new()
		horizontal_mesh.size = Vector3(side_width, 0.075, 0.18)
		var panels := MultiMesh.new()
		panels.transform_format = MultiMesh.TRANSFORM_3D
		panels.mesh = panel_mesh
		var spandrels := MultiMesh.new()
		spandrels.transform_format = MultiMesh.TRANSFORM_3D
		spandrels.mesh = spandrel_mesh
		var verticals := MultiMesh.new()
		verticals.transform_format = MultiMesh.TRANSFORM_3D
		verticals.mesh = vertical_mesh
		var horizontals := MultiMesh.new()
		horizontals.transform_format = MultiMesh.TRANSFORM_3D
		horizontals.mesh = horizontal_mesh
		var panel_transforms: Array[Transform3D] = []
		var spandrel_transforms: Array[Transform3D] = []
		var vertical_transforms: Array[Transform3D] = []
		var horizontal_transforms: Array[Transform3D] = []
		var facade_z: float = side_depth * 0.5 + 0.13
		for floor_index in range(floors):
			var row_height: float = ground_height if floor_index == 0 else floor_height
			var row_center: float = 0.42 + (ground_height * 0.5 if floor_index == 0 else ground_height + float(floor_index - 1) * floor_height + floor_height * 0.5)
			var panel_basis := side_basis.scaled(Vector3(1.0, row_height - 0.24, 1.0))
			for column in range(columns):
				var x: float = (float(column) - float(columns - 1) * 0.5) * panel_width
				panel_transforms.append(Transform3D(panel_basis, side_basis * Vector3(x, row_center, facade_z)))
				spandrel_transforms.append(Transform3D(side_basis, side_basis * Vector3(x, row_center - row_height * 0.5 + 0.13, facade_z + 0.045)))
		for column in range(columns + 1):
			var x: float = (float(column) - float(columns) * 0.5) * panel_width
			vertical_transforms.append(Transform3D(side_basis, side_basis * Vector3(x, (ground_height + float(floors - 1) * floor_height) * 0.5 + 0.42, facade_z + 0.075)))
		for floor_index in range(floors + 1):
			var y: float = 0.42 + ground_height + float(floor_index - 1) * floor_height if floor_index > 0 else 0.42
			horizontal_transforms.append(Transform3D(side_basis, side_basis * Vector3(0.0, y, facade_z + 0.08)))
		panels.instance_count = panel_transforms.size()
		spandrels.instance_count = spandrel_transforms.size()
		verticals.instance_count = vertical_transforms.size()
		horizontals.instance_count = horizontal_transforms.size()
		for i in range(panel_transforms.size()):
			panels.set_instance_transform(i, panel_transforms[i])
			spandrels.set_instance_transform(i, spandrel_transforms[i])
		for i in range(vertical_transforms.size()):
			verticals.set_instance_transform(i, vertical_transforms[i])
		for i in range(horizontal_transforms.size()):
			horizontals.set_instance_transform(i, horizontal_transforms[i])
		_add_multimesh(parent, "Glass_Curtain_Panels_Side_%d" % side, panels, materials["glass"])
		_add_multimesh(parent, "Glass_Spandrel_Bands_Side_%d" % side, spandrels, materials["glass_spandrel"])
		_add_multimesh(parent, "Aluminium_Curtain_Mullions_Side_%d" % side, verticals, materials["glass_mullion"])
		_add_multimesh(parent, "Glass_Floor_Transoms_Side_%d" % side, horizontals, materials["glass_mullion"])

func _add_facade_windows(parent: Node3D, angle: float, width: float, depth: float, floors: int, ground_height: float, floor_height: float, style: int) -> void:
	var facade_basis := Basis(Vector3.UP, angle)
	var facade_depth := depth * 0.5 + 0.095
	var columns := 3 if style == 2 else 2
	var spacing := (width - 1.0) / float(columns)
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.28 if columns == 2 else 0.92, 1.48, 0.16)
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(1.06 if columns == 2 else 0.72, 1.20, 0.10)
	var sill_mesh := BoxMesh.new()
	sill_mesh.size = Vector3(1.34 if columns == 2 else 0.98, 0.10, 0.20)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(1.30 if columns == 2 else 0.94, 0.065, 0.17)
	var gasket_mesh := BoxMesh.new()
	gasket_mesh.size = Vector3(1.12 if columns == 2 else 0.78, 1.26, 0.035)
	var reflection_mesh := BoxMesh.new()
	reflection_mesh.size = Vector3(0.055, 1.00, 0.018)
	var highlight_mesh := BoxMesh.new()
	highlight_mesh.size = Vector3(0.72 if columns == 2 else 0.48, 0.025, 0.018)
	var frame_mm := MultiMesh.new()
	frame_mm.transform_format = MultiMesh.TRANSFORM_3D
	frame_mm.mesh = frame_mesh
	var glass_mm := MultiMesh.new()
	glass_mm.transform_format = MultiMesh.TRANSFORM_3D
	glass_mm.mesh = glass_mesh
	var sill_mm := MultiMesh.new()
	sill_mm.transform_format = MultiMesh.TRANSFORM_3D
	sill_mm.mesh = sill_mesh
	var head_mm := MultiMesh.new()
	head_mm.transform_format = MultiMesh.TRANSFORM_3D
	head_mm.mesh = head_mesh
	var gasket_mm := MultiMesh.new()
	gasket_mm.transform_format = MultiMesh.TRANSFORM_3D
	gasket_mm.mesh = gasket_mesh
	var reflection_mm := MultiMesh.new()
	reflection_mm.transform_format = MultiMesh.TRANSFORM_3D
	reflection_mm.mesh = reflection_mesh
	var highlight_mm := MultiMesh.new()
	highlight_mm.transform_format = MultiMesh.TRANSFORM_3D
	highlight_mm.mesh = highlight_mesh
	var frame_transforms: Array[Transform3D] = []
	var glass_transforms: Array[Transform3D] = []
	var sill_transforms: Array[Transform3D] = []
	var head_transforms: Array[Transform3D] = []
	var gasket_transforms: Array[Transform3D] = []
	var reflection_transforms: Array[Transform3D] = []
	var highlight_transforms: Array[Transform3D] = []
	for floor_index in range(1, floors):
		var y := 0.42 + ground_height + float(floor_index - 1) * floor_height + 1.38
		for column in range(columns):
			var x := (float(column) - float(columns - 1) * 0.5) * spacing
			frame_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x, y, facade_depth)))
			gasket_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x, y, facade_depth + 0.035)))
			glass_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x, y, facade_depth + 0.075)))
			sill_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x, y - 0.72, facade_depth + 0.06)))
			head_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x, y + 0.72, facade_depth + 0.055)))
			# Narrow highlights simulate reflected sky on the glazing without texture-heavy materials.
			reflection_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x - (0.30 if columns == 2 else 0.20), y, facade_depth + 0.132)))
			highlight_transforms.append(Transform3D(facade_basis, facade_basis * Vector3(x + (0.10 if columns == 2 else 0.06), y + 0.48, facade_depth + 0.132)))
	frame_mm.instance_count = frame_transforms.size()
	glass_mm.instance_count = glass_transforms.size()
	sill_mm.instance_count = sill_transforms.size()
	head_mm.instance_count = head_transforms.size()
	gasket_mm.instance_count = gasket_transforms.size()
	reflection_mm.instance_count = reflection_transforms.size()
	highlight_mm.instance_count = highlight_transforms.size()
	for i in range(frame_transforms.size()):
		frame_mm.set_instance_transform(i, frame_transforms[i])
		glass_mm.set_instance_transform(i, glass_transforms[i])
		sill_mm.set_instance_transform(i, sill_transforms[i])
		head_mm.set_instance_transform(i, head_transforms[i])
		gasket_mm.set_instance_transform(i, gasket_transforms[i])
		reflection_mm.set_instance_transform(i, reflection_transforms[i])
		highlight_mm.set_instance_transform(i, highlight_transforms[i])
	_add_multimesh(parent, "Deep_Window_Recess_Frames", frame_mm, materials["window_frame"])
	_add_multimesh(parent, "Dark_Inner_Window_Gaskets", gasket_mm, materials["window_gasket"])
	_add_multimesh(parent, "Low_E_Reflective_Glazing", glass_mm, materials["glass"])
	_add_multimesh(parent, "Cast_Window_Sills", sill_mm, materials["metal"])
	_add_multimesh(parent, "Window_Head_Trim", head_mm, materials["window_frame"])
	_add_multimesh(parent, "Vertical_Sky_Reflection_Strips", reflection_mm, materials["glass_reflection"])
	_add_multimesh(parent, "Upper_Glazing_Reflection_Highlights", highlight_mm, materials["glass_reflection"])

func _add_facade_microdetails(parent: Node3D, angle: float, width: float, depth: float, floors: int, ground_height: float, floor_height: float, style: int, accent: Material) -> void:
	var rotation_basis := Basis(Vector3.UP, angle)
	var facade_z := depth * 0.5 + 0.19
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(width + 0.24, 0.075, 0.13)
	var mullion_mesh := BoxMesh.new()
	mullion_mesh.size = Vector3(0.045, 1.18, 0.055)
	var transoms_mesh := BoxMesh.new()
	transoms_mesh.size = Vector3(1.08, 0.045, 0.06)
	var bands := MultiMesh.new()
	bands.transform_format = MultiMesh.TRANSFORM_3D
	bands.mesh = band_mesh
	var mullions := MultiMesh.new()
	mullions.transform_format = MultiMesh.TRANSFORM_3D
	mullions.mesh = mullion_mesh
	var transoms := MultiMesh.new()
	transoms.transform_format = MultiMesh.TRANSFORM_3D
	transoms.mesh = transoms_mesh
	var band_transforms: Array[Transform3D] = []
	var mullion_transforms: Array[Transform3D] = []
	var transom_transforms: Array[Transform3D] = []
	var columns := 3 if style == 2 else 2
	var spacing := (width - 1.0) / float(columns)
	for floor_index in range(1, floors):
		var floor_y := 0.42 + ground_height + float(floor_index - 1) * floor_height
		band_transforms.append(Transform3D(rotation_basis, rotation_basis * Vector3(0.0, floor_y + 0.08, facade_z)))
		var window_y := floor_y + 1.38
		for column in range(columns):
			var x := (float(column) - float(columns - 1) * 0.5) * spacing
			mullion_transforms.append(Transform3D(rotation_basis, rotation_basis * Vector3(x, window_y, facade_z + 0.07)))
			transom_transforms.append(Transform3D(rotation_basis, rotation_basis * Vector3(x, window_y, facade_z + 0.075)))
	bands.instance_count = band_transforms.size()
	mullions.instance_count = mullion_transforms.size()
	transoms.instance_count = transom_transforms.size()
	for i in range(band_transforms.size()):
		bands.set_instance_transform(i, band_transforms[i])
	for i in range(mullion_transforms.size()):
		mullions.set_instance_transform(i, mullion_transforms[i])
	for i in range(transom_transforms.size()):
		transoms.set_instance_transform(i, transom_transforms[i])
	_add_multimesh(parent, "Continuous_Facade_Shadow_Reveal_Bands", bands, accent)
	_add_multimesh(parent, "Precision_Window_Vertical_Mullions", mullions, materials["metal"])
	_add_multimesh(parent, "Precision_Window_Transoms", transoms, materials["window_frame"])
	# A dark recessed shopfront gives the street level a distinct, believable scale.
	var shop := _box(parent, "Ground_Floor_Recessed_Storefront_Glazing", Vector3(width * 0.68, 1.9, 0.075), rotation_basis * Vector3(0.0, 1.62, facade_z + 0.015), materials["storefront"])
	shop.rotation.y = angle
	var canopy := _box(parent, "Ground_Floor_Continuous_Shop_Canopy", Vector3(width * 0.82, 0.11, 0.62), rotation_basis * Vector3(0.0, 2.85, facade_z + 0.22), materials["dark_metal"])
	canopy.rotation.y = angle

func _add_rooftop_service_details(parent: Node3D, width: float, depth: float, height: float, roof: Material, accent: Material) -> void:
	for side in range(4):
		var angle := float(side) * PI * 0.5
		var side_basis := Basis(Vector3.UP, angle)
		var rail := _box(parent, "Roof_Parapet_Return", Vector3(width + 0.35, 0.62, 0.18), side_basis * Vector3(0.0, height + 0.92, depth * 0.5), accent)
		rail.rotation.y = angle
	for i in range(3):
		var x := -1.55 + float(i) * 1.55
		_box(parent, "Rooftop_Mechanical_Condenser", Vector3(0.82, 0.48, 0.72), Vector3(x, height + 0.88, depth * 0.12), roof)
		_box(parent, "Condenser_Front_Grille", Vector3(0.62, 0.28, 0.035), Vector3(x, height + 0.88, depth * 0.12 + 0.38), materials["dark_metal"])
		_cylinder(parent, "Condenser_Fan_Hub", 0.12, 0.12, 0.045, Vector3(x, height + 1.14, depth * 0.12), materials["metal"])
	_box(parent, "Roof_Service_Cable_Tray", Vector3(width * 0.7, 0.07, 0.12), Vector3(0.0, height + 0.7, -depth * 0.32), materials["dark_metal"])

func _add_facade_pilasters(parent: Node3D, angle: float, width: float, depth: float, height: float, material: Material, style: int) -> void:
	var facade_basis := Basis(Vector3.UP, angle)
	for x in [-width * 0.5 + 0.16, width * 0.5 - 0.16]:
		var pos := facade_basis * Vector3(x, height * 0.5 + 0.42, depth * 0.5 + 0.12)
		var pilaster := _box(parent, "Facade_Corner_Pilaster", Vector3(0.22 if style != 3 else 0.34, height, 0.24), pos, material)
		pilaster.rotation.y = angle
	if style == 0 or style == 2:
		for x in [-1.35, 1.35]:
			var pos := facade_basis * Vector3(x, height * 0.5 + 0.42, depth * 0.5 + 0.2)
			var fin := _box(parent, "Vertical_Aluminium_Sunshade", Vector3(0.10, height, 0.18), pos, material)
			fin.rotation.y = angle

func _add_vertical_fins(parent: Node3D, height: float, material: Material, _width: float, depth: float) -> void:
	for side in range(4):
		var angle := float(side) * PI * 0.5
		var rotation_basis := Basis(Vector3.UP, angle)
		for x in [-1.55, 1.55]:
			var p := rotation_basis * Vector3(x, height * 0.5 + 0.42, depth * 0.5 + 0.2)
			var fin := _box(parent, "Full_Height_Facade_Fin", Vector3(0.13, height, 0.22), p, material)
			fin.rotation.y = angle

func _add_main_entrance(parent: Node3D, _width: float, depth: float, _ground_height: float, accent: Material) -> void:
	var z := depth * 0.5 + 0.16
	# A layered portal, paired glazed leaves and a separate transom read as a real lobby entrance.
	_box(parent, "Entrance_Portal_Frame", Vector3(1.78, 2.86, 0.24), Vector3(0.0, 1.78, z), accent)
	_box(parent, "Entrance_Recess_Shadow", Vector3(1.48, 2.52, 0.045), Vector3(0.0, 1.76, z + 0.135), materials["window_gasket"])
	_box(parent, "Entrance_Door_Leaf_Left", Vector3(0.60, 2.30, 0.075), Vector3(-0.315, 1.61, z + 0.17), materials["window_frame"])
	_box(parent, "Entrance_Door_Leaf_Right", Vector3(0.60, 2.30, 0.075), Vector3(0.315, 1.61, z + 0.17), materials["window_frame"])
	_box(parent, "Entrance_Left_Glazed_Panel", Vector3(0.40, 1.54, 0.025), Vector3(-0.315, 1.78, z + 0.215), materials["glass"])
	_box(parent, "Entrance_Right_Glazed_Panel", Vector3(0.40, 1.54, 0.025), Vector3(0.315, 1.78, z + 0.215), materials["glass"])
	for side in [-1.0, 1.0]:
		_box(parent, "Entrance_Door_Outer_Stile", Vector3(0.045, 2.22, 0.045), Vector3(side * 0.59, 1.61, z + 0.225), materials["metal"])
		_box(parent, "Entrance_Door_Inner_Stile", Vector3(0.035, 2.22, 0.045), Vector3(side * 0.035, 1.61, z + 0.225), materials["metal"])
		_box(parent, "Entrance_Door_Kick_Plate", Vector3(0.48, 0.22, 0.025), Vector3(side * 0.315, 0.43, z + 0.245), materials["metal"])
		_box(parent, "Entrance_Pull_Handle", Vector3(0.035, 0.42, 0.045), Vector3(side * 0.075, 1.28, z + 0.255), materials["metal"])
	_box(parent, "Entrance_Central_Door_Meeting_Stile", Vector3(0.035, 2.28, 0.055), Vector3(0.0, 1.61, z + 0.23), materials["dark_metal"])
	_box(parent, "Entrance_Transom_Frame", Vector3(1.34, 0.28, 0.08), Vector3(0.0, 2.91, z + 0.17), materials["metal"])
	_box(parent, "Entrance_Transom_Glass", Vector3(1.20, 0.18, 0.025), Vector3(0.0, 2.91, z + 0.22), materials["glass"])
	_box(parent, "Entrance_Threshold", Vector3(1.52, 0.07, 0.32), Vector3(0.0, 0.12, z + 0.22), materials["metal"])
	_box(parent, "Entrance_Canopy", Vector3(2.7, 0.16, 1.0), Vector3(0.0, 3.18, z + 0.48), materials["metal"])
	for side in [-1.0, 1.0]:
		var canopy_brace := _box(parent, "Entrance_Canopy_Bracket", Vector3(0.07, 0.48, 0.48), Vector3(side * 1.02, 2.94, z + 0.55), materials["dark_metal"])
		canopy_brace.rotation.z = side * -0.42
		_box(parent, "Entrance_Wall_Light_Housing", Vector3(0.22, 0.28, 0.12), Vector3(side * 1.05, 2.15, z + 0.13), materials["dark_metal"])
		_box(parent, "Entrance_Wall_Light_Diffuser", Vector3(0.14, 0.18, 0.035), Vector3(side * 1.05, 2.15, z + 0.205), materials["lamp"])
	_box(parent, "Entrance_Upper_Step", Vector3(2.15, 0.14, 0.48), Vector3(0.0, 0.16, z + 0.48), materials["concrete"])
	_box(parent, "Entrance_Lower_Step", Vector3(2.4, 0.14, 0.62), Vector3(0.0, 0.07, z + 0.91), materials["concrete"])
	_box(parent, "Entrance_Step_Nosing", Vector3(2.4, 0.035, 0.08), Vector3(0.0, 0.235, z + 0.48), materials["metal"])

func _add_multimesh(parent: Node3D, node_name: String, batch: MultiMesh, material: Material) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)

func _box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _glass_mat() -> StandardMaterial3D:
	var material := _mat(Color(0.34, 0.43, 0.52), 0.16, 0.42)
	material.metallic_specular = 0.92
	material.clearcoat_enabled = true
	material.clearcoat = 0.72
	material.clearcoat_roughness = 0.12
	return material

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color, 0.24, 0.05)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _mat(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.metallic_specular = 0.62
	return material
