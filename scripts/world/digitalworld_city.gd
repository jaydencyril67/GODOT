extends Node3D
class_name DigitalWorldCity

# Fully procedural city. Every structure is built from native Godot geometry.
const GRID_COLUMNS := 5
const GRID_ROWS := 6
const PLOT_SPACING := 12.5
const CITY_HALF_WIDTH := 34.0
const CITY_HALF_DEPTH := 40.0

var traffic: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var animation_clock := 0.0
var city_camera: Camera3D
var player_body: CharacterBody3D
var player_speed := 5.2
var player_yaw := 0.0
var player_pitch := -0.08
var joystick_input := Vector2.ZERO
var joystick_touch_index := -1
var look_touch_index := -1
var joystick_origin := Vector2.ZERO
var joystick_default_position := Vector2.ZERO
var joystick_base: Panel
var joystick_knob: Panel
var mouse_looking := false
var camera_position := Vector3(0.0, 14.0, 48.0)
var camera_yaw := 0.0
var camera_pitch := -0.20
var mouse_orbiting := false
var mouse_panning := false
var touch_points: Dictionary = {}
var pinch_distance := 0.0
var last_touch_midpoint := Vector2.ZERO
var materials: Dictionary = {}
var facade_noise: Texture2D
var pavement_noise: Texture2D
var facade_normal: Texture2D
var pavement_normal: Texture2D

func _ready() -> void:
	_build_city()
	_add_first_person_hud()

func _process(delta: float) -> void:
	animation_clock += delta
	for vehicle in traffic:
		var node: Node3D = vehicle["node"]
		node.position.x += float(vehicle["speed"]) * float(vehicle["direction"]) * delta
		if node.position.x > CITY_HALF_WIDTH + 5.0:
			node.position.x = -CITY_HALF_WIDTH - 5.0
		elif node.position.x < -CITY_HALF_WIDTH - 5.0:
			node.position.x = CITY_HALF_WIDTH + 5.0
	for person in walkers:
		var node: Node3D = person["node"]
		node.position.x += float(person["speed"]) * delta
		if node.position.x > CITY_HALF_WIDTH:
			node.position.x = -CITY_HALF_WIDTH
		var phase := animation_clock * 7.0 + float(person["phase"])
		(person["left_leg"] as Node3D).rotation.z = sin(phase) * 0.24
		(person["right_leg"] as Node3D).rotation.z = -sin(phase) * 0.24
		(person["left_arm"] as Node3D).rotation.z = -sin(phase) * 0.17
		(person["right_arm"] as Node3D).rotation.z = sin(phase) * 0.17

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_body):
		return
	var input_vector := joystick_input
	# Keep desktop keyboard movement available for editor testing.
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x = -1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x = 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y = -1.0
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y = 1.0
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var move_direction := player_body.global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	move_direction.y = 0.0
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()
	player_body.velocity.x = move_direction.x * player_speed
	player_body.velocity.z = move_direction.z * player_speed
	if not player_body.is_on_floor():
		player_body.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	elif player_body.velocity.y < 0.0:
		player_body.velocity.y = -0.1
	player_body.move_and_slide()

func _build_city() -> void:
	_create_material_library()
	_create_procedural_surface_textures()
	_create_environment()
	_create_camera()
	_add_city_ground()
	_add_road_network()
	_add_junction_details()
	_add_all_buildings()
	_add_urban_landscape()
	_add_traffic()
	_add_pedestrians()

func _create_material_library() -> void:
	materials = {
		"ground": _mat(Color("#77796f"), 0.98),
		"asphalt": _mat(Color("#242a2e"), 0.96),
		"asphalt_worn": _mat(Color("#343a3d"), 0.98),
		"sidewalk": _mat(Color("#b8b8ae"), 0.92),
		"curb": _mat(Color("#d2d0c6"), 0.88),
		"lane": _mat(Color("#e5d6a5"), 0.78),
		"white": _mat(Color("#edf0e9"), 0.82),
		"concrete": _mat(Color("#b8b9b1"), 0.9),
		"dark_metal": _mat(Color("#303b40"), 0.42, 0.72),
		"metal": _mat(Color("#78878b"), 0.34, 0.78),
		"glass": _glass_mat(),
		"storefront": _mat(Color("#26383d"), 0.22, 0.38),
		"window_frame": _mat(Color("#26343a"), 0.38, 0.62),
		"roof": _mat(Color("#59666a"), 0.72, 0.28),
		"soil": _mat(Color("#655e4f"), 1.0),
		"trunk": _mat(Color("#594235"), 0.98),
		"leaf_a": _mat(Color("#345c42"), 0.94),
		"leaf_b": _mat(Color("#55764b"), 0.94),
		"car_tire": _mat(Color("#171b1d"), 0.96),
		"rubber": _mat(Color("#22282b"), 0.96),
		"lamp": _emissive_mat(Color("#ffe4ad"), 1.5),
		"red": _emissive_mat(Color("#ed3e32"), 2.0),
		"amber": _emissive_mat(Color("#ffb52e"), 1.8),
		"green": _emissive_mat(Color("#43d58a"), 1.8)
	}

func _create_procedural_surface_textures() -> void:
	# Runtime-generated surface breakup keeps the city self-contained: no texture
	# packs or imported building materials are required.
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
	var facade_normal_texture := NoiseTexture2D.new()
	facade_normal_texture.width = 256
	facade_normal_texture.height = 256
	facade_normal_texture.seamless = true
	facade_normal_texture.as_normal_map = true
	facade_normal_texture.bump_strength = 0.22
	facade_normal_texture.noise = noise
	facade_normal = facade_normal_texture
	var pavement := NoiseTexture2D.new()
	pavement.width = 256
	pavement.height = 256
	pavement.seamless = true
	var pavement_generator := FastNoiseLite.new()
	pavement_generator.noise_type = FastNoiseLite.TYPE_SIMPLEX
	pavement_generator.frequency = 0.075
	pavement_generator.fractal_octaves = 3
	pavement.noise = pavement_generator
	pavement_noise = pavement
	var pavement_normal_texture := NoiseTexture2D.new()
	pavement_normal_texture.width = 256
	pavement_normal_texture.height = 256
	pavement_normal_texture.seamless = true
	pavement_normal_texture.as_normal_map = true
	pavement_normal_texture.bump_strength = 0.32
	pavement_normal_texture.noise = pavement_generator
	pavement_normal = pavement_normal_texture
	for key in ["concrete", "sidewalk"]:
		var surface: StandardMaterial3D = materials[key]
		surface.albedo_texture = facade_noise
		surface.uv1_scale = Vector3(3.5, 3.5, 1.0)
		surface.normal_enabled = true
		surface.normal_texture = facade_normal
		surface.normal_scale = 0.28
		surface.roughness_texture = facade_noise
	var road: StandardMaterial3D = materials["asphalt"]
	road.albedo_texture = pavement_noise
	road.uv1_scale = Vector3(8.0, 8.0, 1.0)
	road.normal_enabled = true
	road.normal_texture = pavement_normal
	road.normal_scale = 0.34
	road.roughness_texture = pavement_noise
	var soil: StandardMaterial3D = materials["soil"]
	soil.albedo_texture = pavement_noise
	soil.uv1_scale = Vector3(5.0, 5.0, 1.0)
	soil.normal_enabled = true
	soil.normal_texture = pavement_normal
	soil.normal_scale = 0.22

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#477fa7")
	sky_material.sky_horizon_color = Color("#c4d5d9")
	sky_material.ground_bottom_color = Color("#343c40")
	sky_material.ground_horizon_color = Color("#89999a")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.ambient_light_sky_contribution = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a9bdc5")
	environment.fog_density = 0.0018
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Late_Afternoon_Sun"
	sun.rotation_degrees = Vector3(-43.0, -31.0, 0.0)
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

func _create_camera() -> void:
	# The player owns the camera so looking around never moves the player in a circle.
	player_body = CharacterBody3D.new()
	player_body.name = "First_Person_Player"
	player_body.position = Vector3(0.0, 0.22, 0.0)
	player_body.floor_snap_length = 0.28
	player_body.floor_max_angle = deg_to_rad(48.0)
	player_body.safe_margin = 0.03
	var body_shape := CollisionShape3D.new()
	body_shape.name = "Player_Capsule_Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	body_shape.shape = capsule
	body_shape.position = Vector3(0.0, 0.9, 0.0)
	player_body.add_child(body_shape)
	add_child(player_body)

	city_camera = Camera3D.new()
	city_camera.name = "First_Person_Camera"
	city_camera.fov = 76.0
	city_camera.near = 0.06
	city_camera.far = 650.0
	city_camera.position = Vector3(0.0, 1.62, 0.0)
	player_body.add_child(city_camera)
	city_camera.current = true
	player_body.rotation.y = player_yaw
	city_camera.rotation.x = player_pitch

func _add_city_ground() -> void:
	_box(self, "City_Ground_Base", Vector3(82.0, 0.8, 94.0), Vector3(0.0, -0.48, 0.0), materials["ground"])
	_box(self, "City_Topsoil_Surface", Vector3(80.0, 0.08, 92.0), Vector3(0.0, -0.04, 0.0), materials["soil"])
	_add_box_collision(self, "City_Ground_Collision", Vector3(80.0, 0.08, 92.0), Vector3(0.0, -0.015, 0.0))

func _add_road_network() -> void:
	for row_edge in range(GRID_ROWS + 1):
		var z := (float(row_edge) - 3.0) * PLOT_SPACING
		_box(self, "East_West_Asphalt_Road", Vector3(80.0, 0.045, 3.5), Vector3(0.0, 0.025, z), materials["asphalt"])
		_add_box_collision(self, "East_West_Road_Collision", Vector3(80.0, 0.045, 3.5), Vector3(0.0, 0.025, z))
		_box(self, "North_Sidewalk", Vector3(80.0, 0.13, 1.35), Vector3(0.0, 0.09, z - 2.45), materials["sidewalk"])
		_box(self, "South_Sidewalk", Vector3(80.0, 0.13, 1.35), Vector3(0.0, 0.09, z + 2.45), materials["sidewalk"])
		_box(self, "North_Curb", Vector3(80.0, 0.16, 0.16), Vector3(0.0, 0.12, z - 1.86), materials["curb"])
		_box(self, "South_Curb", Vector3(80.0, 0.16, 0.16), Vector3(0.0, 0.12, z + 1.86), materials["curb"])
		for dash in range(16):
			_box(self, "Broken_Centre_Lane_Marking", Vector3(2.0, 0.018, 0.075), Vector3(-37.0 + float(dash) * 5.0, 0.06, z), materials["lane"])
	for col_edge in range(GRID_COLUMNS + 1):
		var x := (float(col_edge) - 2.5) * PLOT_SPACING
		_box(self, "North_South_Asphalt_Road", Vector3(3.5, 0.05, 92.0), Vector3(x, 0.035, 0.0), materials["asphalt"])
		_add_box_collision(self, "North_South_Road_Collision", Vector3(3.5, 0.05, 92.0), Vector3(x, 0.035, 0.0))
		_box(self, "West_Sidewalk", Vector3(1.35, 0.13, 92.0), Vector3(x - 2.45, 0.09, 0.0), materials["sidewalk"])
		_box(self, "East_Sidewalk", Vector3(1.35, 0.13, 92.0), Vector3(x + 2.45, 0.09, 0.0), materials["sidewalk"])
		_box(self, "West_Curb", Vector3(0.16, 0.16, 92.0), Vector3(x - 1.86, 0.12, 0.0), materials["curb"])
		_box(self, "East_Curb", Vector3(0.16, 0.16, 92.0), Vector3(x + 1.86, 0.12, 0.0), materials["curb"])
		for dash in range(18):
			_box(self, "Broken_Centre_Lane_Marking", Vector3(0.075, 0.018, 2.0), Vector3(x, 0.065, -43.0 + float(dash) * 5.0), materials["lane"])

func _add_junction_details() -> void:
	for center in [Vector3(-6.25, 0.0, 0.0), Vector3(6.25, 0.0, 0.0)]:
		_add_crosswalk(center, true)
	for center in [Vector3(0.0, 0.0, -6.25), Vector3(0.0, 0.0, 6.25)]:
		_add_crosswalk(center, false)
	for point in [Vector3(-7.0, 0.0, -1.9), Vector3(7.0, 0.0, 1.9), Vector3(-19.5, 0.0, 23.1), Vector3(19.5, 0.0, -23.1)]:
		_add_traffic_signal(point)
	for point in [Vector3(-8.4, 0.0, -1.9), Vector3(8.4, 0.0, 1.9), Vector3(-18.0, 0.0, 24.8), Vector3(18.0, 0.0, -24.8)]:
		_add_manhole(point)
	for point in [Vector3(-8.0, 0.0, -2.65), Vector3(8.0, 0.0, 2.65), Vector3(-20.5, 0.0, 21.8), Vector3(20.5, 0.0, -21.8)]:
		_add_storm_drain(point)

func _add_all_buildings() -> void:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var index := row * GRID_COLUMNS + col
			var plot := Vector3(
				(float(col) - 2.0) * PLOT_SPACING + sin(float(row) * 0.72) * 0.42,
				0.0,
				(float(row) - 2.5) * PLOT_SPACING + sin(float(col) * 0.63) * 0.38
			)
			_build_procedural_building(index, plot)

func _build_procedural_building(index: int, plot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Procedural_Architecture_%02d" % (index + 1)
	root.position = plot
	add_child(root)

	var style := index % 5
	var floor_count: int = int([4, 7, 10, 13, 6][style]) + (index % 3)
	var floor_height := 2.75
	var ground_height := 3.25
	var width := 7.7 + float(index % 3) * 0.22
	var depth := 7.7 + float((index + 1) % 3) * 0.18
	var height := ground_height + float(floor_count - 1) * floor_height
	# One simple invisible collider per building keeps mobile physics inexpensive.
	_add_box_collision(root, "Building_Solid_Collision", Vector3(width + 0.7, height + 0.42, depth + 0.7), Vector3(0.0, (height + 0.42) * 0.5, 0.0))
	var wall_colors := [Color("#c2c0b5"), Color("#b9a991"), Color("#aab9bd"), Color("#c6c8c2"), Color("#9eaeb1")]
	var accent_colors := [Color("#34464c"), Color("#665548"), Color("#263e4b"), Color("#4b5554"), Color("#34444a")]
	var wall := _mat(wall_colors[style], 0.86, 0.04)
	var podium := _mat(wall_colors[style].darkened(0.28), 0.72, 0.12)
	var accent := _mat(accent_colors[style], 0.42, 0.48)
	var roof := _mat(Color("#525e62"), 0.78, 0.26)
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

	_box(root, "Architectural_Foundation_Plinth", Vector3(width + 0.7, 0.42, depth + 0.7), Vector3(0.0, 0.21, 0.0), materials["concrete"])
	_box(root, "Continuous_Concrete_Building_Envelope", Vector3(width, height, depth), Vector3(0.0, height * 0.5 + 0.42, 0.0), wall)
	_box(root, "Ground_Floor_Commercial_Podium", Vector3(width + 0.12, ground_height, depth + 0.12), Vector3(0.0, ground_height * 0.5 + 0.42, 0.0), podium)

	# Four elevations share the same procedural window grammar, but vary by style.
	for side in range(4):
		var angle := float(side) * PI * 0.5
		_add_facade_windows(root, angle, width, depth, floor_count, ground_height, floor_height, style)
		_add_facade_pilasters(root, angle, width, depth, height, accent, style)
		_add_facade_microdetails(root, angle, width, depth, floor_count, ground_height, floor_height, style, accent)
		if style == 1 or style == 4:
			_add_balcony_stack(root, angle, floor_count, ground_height, floor_height, width, depth, accent)

	# Floor plates, cornices and a layered roof silhouette.
	for floor_index in range(1, floor_count):
		var y := 0.42 + ground_height + float(floor_index - 1) * floor_height
		_box(root, "Expressed_Floor_Slab", Vector3(width + 0.22, 0.11, depth + 0.22), Vector3(0.0, y, 0.0), accent)
	_box(root, "Roof_Cornice", Vector3(width + 0.55, 0.28, depth + 0.55), Vector3(0.0, height + 0.54, 0.0), accent)
	_box(root, "Rooftop_Service_Penthouse", Vector3(width * 0.38, 1.15, depth * 0.38), Vector3(-width * 0.18, height + 1.23, -depth * 0.16), roof)
	_box(root, "Rooftop_HVAC_Equipment", Vector3(1.25, 0.55, 0.9), Vector3(width * 0.2, height + 0.92, depth * 0.18), materials["metal"])
	_box(root, "Rooftop_Parapet_Front", Vector3(width + 0.35, 0.62, 0.18), Vector3(0.0, height + 0.92, depth * 0.5), accent)
	_box(root, "Rooftop_Parapet_Back", Vector3(width + 0.35, 0.62, 0.18), Vector3(0.0, height + 0.92, -depth * 0.5), accent)
	_add_main_entrance(root, width, depth, ground_height, accent)
	_add_rooftop_service_details(root, width, depth, height, roof, accent)
	if style == 0 or style == 2:
		_add_vertical_fins(root, height, accent, width, depth)

func _add_facade_windows(parent: Node3D, angle: float, width: float, depth: float, floors: int, ground_height: float, floor_height: float, style: int) -> void:
	var basis := Basis(Vector3.UP, angle)
	var facade_depth := depth * 0.5 + 0.095
	var columns := 3 if style == 2 else 2
	var spacing := (width - 1.0) / float(columns)
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.28 if columns == 2 else 0.92, 1.48, 0.16)
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(1.06 if columns == 2 else 0.72, 1.20, 0.10)
	var sill_mesh := BoxMesh.new()
	sill_mesh.size = Vector3(1.34 if columns == 2 else 0.98, 0.10, 0.20)
	var frame_mm := MultiMesh.new()
	frame_mm.transform_format = MultiMesh.TRANSFORM_3D
	frame_mm.mesh = frame_mesh
	var glass_mm := MultiMesh.new()
	glass_mm.transform_format = MultiMesh.TRANSFORM_3D
	glass_mm.mesh = glass_mesh
	var sill_mm := MultiMesh.new()
	sill_mm.transform_format = MultiMesh.TRANSFORM_3D
	sill_mm.mesh = sill_mesh
	var frame_transforms: Array[Transform3D] = []
	var glass_transforms: Array[Transform3D] = []
	var sill_transforms: Array[Transform3D] = []
	for floor_index in range(1, floors):
		var y := 0.42 + ground_height + float(floor_index - 1) * floor_height + 1.38
		for column in range(columns):
			var x := (float(column) - float(columns - 1) * 0.5) * spacing
			var origin := basis * Vector3(x, y, facade_depth)
			frame_transforms.append(Transform3D(basis, origin))
			glass_transforms.append(Transform3D(basis, basis * Vector3(x, y, facade_depth + 0.045)))
			sill_transforms.append(Transform3D(basis, basis * Vector3(x, y - 0.72, facade_depth + 0.06)))
	frame_mm.instance_count = frame_transforms.size()
	glass_mm.instance_count = glass_transforms.size()
	sill_mm.instance_count = sill_transforms.size()
	for i in range(frame_transforms.size()):
		frame_mm.set_instance_transform(i, frame_transforms[i])
		glass_mm.set_instance_transform(i, glass_transforms[i])
		sill_mm.set_instance_transform(i, sill_transforms[i])
	_add_multimesh(parent, "Repeated_Window_Recess_Frames", frame_mm, materials["window_frame"])
	_add_multimesh(parent, "Low_E_Mirror_Glazing", glass_mm, materials["glass"])
	_add_multimesh(parent, "Cast_Window_Sills", sill_mm, materials["metal"])

func _add_facade_microdetails(parent: Node3D, angle: float, width: float, depth: float, floors: int, ground_height: float, floor_height: float, style: int, accent: Material) -> void:
	var basis := Basis(Vector3.UP, angle)
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
		band_transforms.append(Transform3D(basis, basis * Vector3(0.0, floor_y + 0.08, facade_z)))
		var window_y := floor_y + 1.38
		for column in range(columns):
			var x := (float(column) - float(columns - 1) * 0.5) * spacing
			mullion_transforms.append(Transform3D(basis, basis * Vector3(x, window_y, facade_z + 0.07)))
			transom_transforms.append(Transform3D(basis, basis * Vector3(x, window_y, facade_z + 0.075)))
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
	var shop := _box(parent, "Ground_Floor_Recessed_Storefront_Glazing", Vector3(width * 0.68, 1.9, 0.075), basis * Vector3(0.0, 1.62, facade_z + 0.015), materials["storefront"])
	shop.rotation.y = angle
	var canopy := _box(parent, "Ground_Floor_Continuous_Shop_Canopy", Vector3(width * 0.82, 0.11, 0.62), basis * Vector3(0.0, 2.85, facade_z + 0.22), materials["dark_metal"])
	canopy.rotation.y = angle

func _add_rooftop_service_details(parent: Node3D, width: float, depth: float, height: float, roof: Material, accent: Material) -> void:
	for side in range(4):
		var angle := float(side) * PI * 0.5
		var basis := Basis(Vector3.UP, angle)
		var rail := _box(parent, "Roof_Parapet_Return", Vector3(width + 0.35, 0.62, 0.18), basis * Vector3(0.0, height + 0.92, depth * 0.5), accent)
		rail.rotation.y = angle
	for i in range(3):
		var x := -1.55 + float(i) * 1.55
		_box(parent, "Rooftop_Mechanical_Condenser", Vector3(0.82, 0.48, 0.72), Vector3(x, height + 0.88, depth * 0.12), roof)
		_box(parent, "Condenser_Front_Grille", Vector3(0.62, 0.28, 0.035), Vector3(x, height + 0.88, depth * 0.12 + 0.38), materials["dark_metal"])
		_cylinder(parent, "Condenser_Fan_Hub", 0.12, 0.12, 0.045, Vector3(x, height + 1.14, depth * 0.12), materials["metal"])
	_box(parent, "Roof_Service_Cable_Tray", Vector3(width * 0.7, 0.07, 0.12), Vector3(0.0, height + 0.7, -depth * 0.32), materials["dark_metal"])

func _add_facade_pilasters(parent: Node3D, angle: float, width: float, depth: float, height: float, material: Material, style: int) -> void:
	var basis := Basis(Vector3.UP, angle)
	for x in [-width * 0.5 + 0.16, width * 0.5 - 0.16]:
		var pos := basis * Vector3(x, height * 0.5 + 0.42, depth * 0.5 + 0.12)
		var pilaster := _box(parent, "Facade_Corner_Pilaster", Vector3(0.22 if style != 3 else 0.34, height, 0.24), pos, material)
		pilaster.rotation.y = angle
	if style == 0 or style == 2:
		for x in [-1.35, 1.35]:
			var pos := basis * Vector3(x, height * 0.5 + 0.42, depth * 0.5 + 0.2)
			var fin := _box(parent, "Vertical_Aluminium_Sunshade", Vector3(0.10, height, 0.18), pos, material)
			fin.rotation.y = angle

func _add_balcony_stack(parent: Node3D, angle: float, floors: int, ground_height: float, floor_height: float, width: float, depth: float, material: Material) -> void:
	var basis := Basis(Vector3.UP, angle)
	var y_offset := 0.42
	for floor_index in range(1, floors):
		if floor_index % 2 == 0:
			var y := y_offset + ground_height + float(floor_index - 1) * floor_height + 0.12
			var p := basis * Vector3(0.0, y, depth * 0.5 + 0.55)
			var balcony := _box(parent, "Cantilevered_Balcony_Slab", Vector3(width * 0.62, 0.13, 0.95), p, materials["concrete"])
			balcony.rotation.y = angle
			var rail_pos := basis * Vector3(0.0, y + 0.52, depth * 0.5 + 0.98)
			var rail := _box(parent, "Balcony_Glass_Railing", Vector3(width * 0.62, 0.78, 0.055), rail_pos, materials["glass"])
			rail.rotation.y = angle

func _add_vertical_fins(parent: Node3D, height: float, material: Material, width: float, depth: float) -> void:
	for side in range(4):
		var angle := float(side) * PI * 0.5
		var basis := Basis(Vector3.UP, angle)
		for x in [-1.55, 1.55]:
			var p := basis * Vector3(x, height * 0.5 + 0.42, depth * 0.5 + 0.2)
			var fin := _box(parent, "Full_Height_Facade_Fin", Vector3(0.13, height, 0.22), p, material)
			fin.rotation.y = angle

func _add_main_entrance(parent: Node3D, width: float, depth: float, ground_height: float, accent: Material) -> void:
	var z := depth * 0.5 + 0.16
	_box(parent, "Entrance_Portal_Frame", Vector3(1.65, 2.7, 0.22), Vector3(0.0, 1.78, z), accent)
	_box(parent, "Entrance_Glazed_Door", Vector3(1.34, 2.38, 0.10), Vector3(0.0, 1.78, z + 0.08), materials["glass"])
	_box(parent, "Entrance_Canopy", Vector3(2.7, 0.16, 1.0), Vector3(0.0, 3.05, z + 0.42), materials["metal"])
	_box(parent, "Entrance_Steps", Vector3(2.4, 0.18, 0.7), Vector3(0.0, 0.09, z + 0.52), materials["concrete"])

func _add_urban_landscape() -> void:
	for row in range(GRID_ROWS + 1):
		var z := (float(row) - 2.5) * PLOT_SPACING
		for x in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
			_add_streetlight(Vector3(x, 0.0, z - 2.55))
	for col in range(GRID_COLUMNS + 1):
		var x := (float(col) - 2.5) * PLOT_SPACING
		for z in [-30.0, -15.0, 15.0, 30.0]:
			if col % 2 == 0:
				_add_streetlight(Vector3(x + 2.55, 0.0, z))
	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			if (row + col) % 3 == 0:
				var p := Vector3((float(col) - 2.0) * PLOT_SPACING - 4.35, 0.0, (float(row) - 2.5) * PLOT_SPACING - 4.45)
				_add_procedural_tree(p, 0.88 + float((row + col) % 2) * 0.16)

func _add_procedural_tree(position: Vector3, scale: float) -> void:
	var tree := Node3D.new()
	tree.name = "Procedural_Street_Tree"
	tree.position = position
	tree.scale = Vector3.ONE * scale
	add_child(tree)
	_cylinder(tree, "Tree_Trunk", 0.12, 0.18, 1.8, Vector3(0.0, 0.9, 0.0), materials["trunk"])
	var branch_a := _cylinder(tree, "Tree_Branch_Left", 0.045, 0.075, 1.05, Vector3(-0.32, 1.65, 0.0), materials["trunk"])
	branch_a.rotation.z = -0.62
	var branch_b := _cylinder(tree, "Tree_Branch_Right", 0.045, 0.075, 1.0, Vector3(0.34, 1.72, 0.08), materials["trunk"])
	branch_b.rotation.z = 0.58
	_sphere(tree, "Tree_Canopy_Lower", 0.92, Vector3(0.0, 2.0, 0.0), materials["leaf_a"])
	_sphere(tree, "Tree_Canopy_Upper", 0.68, Vector3(0.0, 2.75, 0.0), materials["leaf_b"])
	_sphere(tree, "Tree_Canopy_Side_A", 0.58, Vector3(0.52, 2.18, 0.1), materials["leaf_a"])
	_sphere(tree, "Tree_Canopy_Side_B", 0.55, Vector3(-0.5, 2.25, -0.1), materials["leaf_b"])
	_sphere(tree, "Tree_Canopy_Back", 0.54, Vector3(0.05, 2.2, -0.48), materials["leaf_b"])
	_sphere(tree, "Tree_Canopy_Front", 0.5, Vector3(-0.08, 2.12, 0.48), materials["leaf_a"])
	_sphere(tree, "Tree_Canopy_Crown_Left", 0.42, Vector3(-0.42, 2.78, 0.18), materials["leaf_a"])
	_sphere(tree, "Tree_Canopy_Crown_Right", 0.4, Vector3(0.4, 2.72, -0.16), materials["leaf_b"])

func _add_streetlight(position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Procedural_Streetlight"
	root.position = position
	add_child(root)
	_cylinder(root, "Tapered_Lamp_Post", 0.045, 0.075, 4.6, Vector3(0.0, 2.3, 0.0), materials["dark_metal"])
	_box(root, "Cantilever_Lamp_Arm", Vector3(0.95, 0.07, 0.07), Vector3(0.38, 4.48, 0.0), materials["metal"])
	_box(root, "LED_Luminaire_Housing", Vector3(0.48, 0.13, 0.32), Vector3(0.78, 4.38, 0.0), materials["dark_metal"])
	_box(root, "LED_Luminaire_Diffuser", Vector3(0.39, 0.025, 0.24), Vector3(0.78, 4.30, 0.0), materials["lamp"])

func _add_traffic() -> void:
	var lanes: Array[float] = [-25.0, 0.0, 25.0]
	for index in range(10):
		var direction := 1.0 if index % 2 == 0 else -1.0
		var car := _make_procedural_car(index)
		car.position = Vector3(-31.0 + float(index) * 6.8, 0.12, lanes[index % 3] + (0.58 if direction > 0.0 else -0.58))
		car.rotation.y = -PI * 0.5 if direction > 0.0 else PI * 0.5
		add_child(car)
		traffic.append({"node": car, "speed": 3.0 + float(index % 3) * 0.65, "direction": direction})

func _make_procedural_car(index: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Procedural_Traffic_Vehicle_%02d" % (index + 1)
	var paint_colors := [Color("#d8dce0"), Color("#263d50"), Color("#a84a38"), Color("#c5a45d"), Color("#3c6257")]
	var paint := _mat(paint_colors[index % paint_colors.size()], 0.28, 0.52)
	_box(car, "Stamped_Vehicle_Body", Vector3(1.85, 0.48, 0.92), Vector3(0.0, 0.54, 0.0), paint)
	_box(car, "Passenger_Cabin", Vector3(1.02, 0.48, 0.78), Vector3(-0.12, 0.99, 0.0), materials["glass"])
	for x in [-0.58, 0.58]:
		for z in [-0.49, 0.49]:
			var tyre := _cylinder(car, "Rubber_Tyre", 0.22, 0.22, 0.13, Vector3(x, 0.30, z), materials["rubber"])
			tyre.rotation.x = PI * 0.5
			var hub := _cylinder(car, "Alloy_Wheel_Hub", 0.105, 0.105, 0.145, Vector3(x, 0.30, z * 1.08), materials["metal"])
			hub.rotation.x = PI * 0.5
	for z in [-0.27, 0.27]:
		_box(car, "LED_Headlamp", Vector3(0.08, 0.12, 0.16), Vector3(0.94, 0.57, z), materials["lamp"])
		_box(car, "Rear_Lamp", Vector3(0.08, 0.12, 0.16), Vector3(-0.94, 0.57, z), materials["red"])
	return car

func _add_pedestrians() -> void:
	var lanes: Array[float] = [-27.5, -2.5, 22.5]
	for index in range(14):
		var person := _make_procedural_pedestrian(index)
		person["node"].position = Vector3(-32.0 + float(index) * 4.7, 0.0, lanes[index % 3])
		add_child(person["node"])
		walkers.append(person)

func _make_procedural_pedestrian(index: int) -> Dictionary:
	var person := Node3D.new()
	person.name = "Procedural_Pedestrian_%02d" % (index + 1)
	var skin_colors := [Color("#8d6048"), Color("#a87555"), Color("#684631")]
	var skin := _mat(skin_colors[index % skin_colors.size()], 0.9)
	var clothing_colors := [Color("#355d72"), Color("#754b42"), Color("#465e49"), Color("#6d6384")]
	var clothes := _mat(clothing_colors[index % clothing_colors.size()], 0.88)
	var trousers := _mat(Color("#30383d"), 0.94)
	_sphere(person, "Pedestrian_Head", 0.16, Vector3(0.0, 1.48, 0.0), skin)
	_capsule(person, "Pedestrian_Torso", 0.19, 0.62, Vector3(0.0, 1.0, 0.0), clothes)
	var left_leg := _capsule(person, "Pedestrian_Left_Leg", 0.07, 0.44, Vector3(-0.09, 0.48, 0.0), trousers)
	var right_leg := _capsule(person, "Pedestrian_Right_Leg", 0.07, 0.44, Vector3(0.09, 0.48, 0.0), trousers)
	var left_arm := _capsule(person, "Pedestrian_Left_Arm", 0.055, 0.4, Vector3(-0.23, 1.0, 0.0), clothes)
	var right_arm := _capsule(person, "Pedestrian_Right_Arm", 0.055, 0.4, Vector3(0.23, 1.0, 0.0), clothes)
	return {"node": person, "left_leg": left_leg, "right_leg": right_leg, "left_arm": left_arm, "right_arm": right_arm, "speed": 0.65 + float(index % 4) * 0.12, "phase": float(index) * 0.7}

func _add_traffic_signal(position: Vector3) -> void:
	var root := Node3D.new()
	root.position = position
	add_child(root)
	_cylinder(root, "Signal_Support_Pole", 0.07, 0.09, 3.3, Vector3(0.0, 1.65, 0.0), materials["dark_metal"])
	for side in [-1.0, 1.0]:
		_box(root, "Signal_Housing", Vector3(0.34, 1.0, 0.24), Vector3(0.0, 2.45, side * 0.28), materials["dark_metal"])
		_sphere(root, "Red_Signal_Lens", 0.095, Vector3(0.0, 2.76, side * 0.43), materials["red"])
		_sphere(root, "Amber_Signal_Lens", 0.095, Vector3(0.0, 2.45, side * 0.43), materials["amber"])
		_sphere(root, "Green_Signal_Lens", 0.095, Vector3(0.0, 2.14, side * 0.43), materials["green"])

func _add_crosswalk(center: Vector3, horizontal: bool) -> void:
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.22, 0.025, 2.7) if horizontal else Vector3(2.7, 0.025, 0.22)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = stripe
	batch.instance_count = 7
	for i in range(7):
		var offset := float(i - 3) * 0.42
		var p := center + (Vector3(offset, 0.11, 0.0) if horizontal else Vector3(0.0, 0.11, offset))
		batch.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	_add_multimesh(self, "Zebra_Crossing_Stripes", batch, materials["white"])

func _add_manhole(position: Vector3) -> void:
	_cylinder(self, "Cast_Iron_Manhole_Cover", 0.38, 0.38, 0.045, position + Vector3.UP * 0.12, materials["dark_metal"])
	for i in range(4):
		var angle := float(i) * PI * 0.5
		_cylinder(self, "Manhole_Bolt", 0.025, 0.025, 0.018, position + Vector3(0.29 * cos(angle), 0.15, 0.29 * sin(angle)), materials["metal"])

func _add_storm_drain(position: Vector3) -> void:
	_box(self, "Storm_Drain_Frame", Vector3(1.05, 0.055, 0.42), position + Vector3.UP * 0.13, materials["dark_metal"])
	for i in range(7):
		var offset := (float(i) - 3.0) * 0.052
		_box(self, "Storm_Drain_Slat", Vector3(0.92, 0.025, 0.018), position + Vector3(0.0, 0.166, offset), materials["metal"])

func _add_multimesh(parent: Node3D, node_name: String, batch: MultiMesh, material: Material) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)

func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 12
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _glass_mat() -> StandardMaterial3D:
	var material := _mat(Color(0.32, 0.55, 0.66), 0.16, 0.42)
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

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var viewport_size := get_viewport().get_visible_rect().size
		if event.pressed:
			if event.position.x < viewport_size.x * 0.46 and event.position.y > viewport_size.y * 0.35 and joystick_touch_index == -1:
				joystick_touch_index = event.index
				joystick_origin = event.position
				joystick_base.position = event.position - joystick_base.size * 0.5
				joystick_base.visible = true
				_update_joystick(Vector2.ZERO)
			elif event.position.x >= viewport_size.x * 0.46 and look_touch_index == -1:
				look_touch_index = event.index
		else:
			if event.index == joystick_touch_index:
				joystick_touch_index = -1
				joystick_input = Vector2.ZERO
				joystick_base.position = joystick_default_position
				_update_joystick_visual()
			if event.index == look_touch_index:
				look_touch_index = -1
		return
	if event is InputEventScreenDrag:
		if event.index == joystick_touch_index:
			_update_joystick((event.position - joystick_origin) / 58.0)
			get_viewport().set_input_as_handled()
		elif event.index == look_touch_index:
			_look_camera(event.relative)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_looking = event.pressed
		return
	if event is InputEventMouseMotion and mouse_looking:
		_look_camera(event.relative)
		return

func _look_camera(relative: Vector2) -> void:
	if not is_instance_valid(player_body) or not is_instance_valid(city_camera):
		return
	player_yaw -= relative.x * 0.0042
	player_pitch = clampf(player_pitch - relative.y * 0.0034, -1.32, 1.32)
	player_body.rotation.y = player_yaw
	city_camera.rotation.x = player_pitch

func _update_joystick(value: Vector2) -> void:
	joystick_input = value.limit_length(1.0)
	_update_joystick_visual()

func _update_joystick_visual() -> void:
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(44.0, 44.0) + joystick_input * 42.0

func _add_box_collision(parent: Node3D, node_name: String, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _add_first_person_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "First_Person_Mobile_Controls"
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.name = "Touch_Control_Overlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	joystick_base = Panel.new()
	joystick_base.name = "Movement_Joystick_Base"
	joystick_base.size = Vector2(144.0, 144.0)
	joystick_base.position = Vector2(28.0, get_viewport().get_visible_rect().size.y - 172.0)
	joystick_default_position = joystick_base.position
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_theme_stylebox_override("panel", _circle_style(Color(0.10, 0.20, 0.27, 0.38), Color(0.78, 0.91, 1.0, 0.62), 3))
	root.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "Movement_Joystick_Knob"
	joystick_knob.size = Vector2(56.0, 56.0)
	joystick_knob.position = Vector2(44.0, 44.0)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.add_theme_stylebox_override("panel", _circle_style(Color(0.56, 0.82, 0.96, 0.78), Color(1.0, 1.0, 1.0, 0.92), 2))
	joystick_base.add_child(joystick_knob)

	var look_hint := Label.new()
	look_hint.name = "Look_Control_Hint"
	look_hint.text = "DRAG RIGHT SIDE TO LOOK"
	look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	look_hint.add_theme_font_size_override("font_size", 11)
	look_hint.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 0.76))
	look_hint.anchor_left = 1.0
	look_hint.anchor_top = 1.0
	look_hint.anchor_right = 1.0
	look_hint.anchor_bottom = 1.0
	look_hint.offset_left = -250.0
	look_hint.offset_top = -34.0
	look_hint.offset_right = -20.0
	look_hint.offset_bottom = -14.0
	look_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(look_hint)

	var crosshair := Label.new()
	crosshair.name = "First_Person_Center_Marker"
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 18)
	crosshair.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8.0, -12.0)
	crosshair.size = Vector2(16.0, 24.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

func _circle_style(fill: Color, outline: Color, outline_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(outline_width)
	style.set_corner_radius_all(72)
	style.anti_aliasing = true
	return style
