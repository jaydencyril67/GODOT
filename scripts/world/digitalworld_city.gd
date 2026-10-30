extends Node3D
class_name DigitalWorldCity

# Phone Tycoon world: one company headquarters and empty expansion land.
# The original map footprint is preserved at 82 x 94 world units.
const MAP_WIDTH := 82.0
const MAP_DEPTH := 94.0

var city_camera: Camera3D
var camera_target := Vector3(0.0, 7.0, 0.0)
var camera_distance := 112.0
var camera_yaw := 0.62
var camera_pitch := 0.48
var mouse_orbiting := false
var mouse_panning := false
var touch_points: Dictionary = {}
var materials: Dictionary = {}
var facade_noise: Texture2D
var facade_normal: Texture2D

func _ready() -> void:
	_build_tycoon_map()
	_create_bottom_navigation()

func _build_tycoon_map() -> void:
	_create_material_library()
	_create_procedural_surface_textures()
	_create_environment()
	_create_camera()
	_add_tycoon_ground()
	_add_expansion_slots()
	_add_headquarters()


func _create_bottom_navigation() -> void:
	# A viewport-anchored navigation bar stays fixed to the bottom of the screen.
	var layer := CanvasLayer.new()
	layer.name = "Tycoon_Bottom_Navigation_Layer"
	layer.layer = 10
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "Fixed_Bottom_Navigation"
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8.0
	panel.offset_top = -78.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#102638")
	panel_style.border_color = Color("#397da5")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 7.0
	panel_style.content_margin_right = 7.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)

	var row := HBoxContainer.new()
	row.name = "Navigation_Buttons_Row"
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)

	var button_names: Array[String] = [
		"Create",
		"Products",
		"Research",
		"Marketing",
		"Media",
		"Office",
		"Statistics"
	]
	for button_name in button_names:
		var button := Button.new()
		button.name = button_name + "_Button"
		button.text = button_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Color("#eaf6ff"))
		button.add_theme_color_override("font_hover_color", Color("#ffffff"))
		button.add_theme_color_override("font_pressed_color", Color("#ffffff"))

		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#1c4560")
		normal.set_corner_radius_all(8)
		normal.content_margin_left = 2.0
		normal.content_margin_right = 2.0
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#28698e")
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color("#1686bd")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		row.add_child(button)

func _create_material_library() -> void:
	materials = {
		"ground": _mat(Color("#668b58"), 0.98),
		"plot_base": _mat(Color("#78966a"), 0.96),
		"plot_border": _mat(Color("#c5d2c2"), 0.82, 0.08),
		"plot_marker": _emissive_mat(Color("#8fc8e8"), 1.15),
		"concrete": _mat(Color("#b8b9b1"), 0.9),
		"dark_metal": _mat(Color("#263941"), 0.42, 0.72),
		"metal": _mat(Color("#78878b"), 0.34, 0.78),
		"glass": _glass_mat(),
		"storefront": _mat(Color("#26383d"), 0.22, 0.38),
		"window_frame": _mat(Color("#26343a"), 0.38, 0.62),
		"glass_reflection": _mat(Color("#a8d2df"), 0.12, 0.32),
		"window_gasket": _mat(Color("#111b20"), 0.72, 0.18),
		"roof": _mat(Color("#59666a"), 0.72, 0.28),
		"lamp": _emissive_mat(Color("#ffe4ad"), 1.5),
		"hq_sign": _mat(Color("#123b56"), 0.32, 0.48),
		"hq_accent": _emissive_mat(Color("#50b9e8"), 1.8)
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
	sun.name = "Tycoon_Sun"
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
	city_camera = Camera3D.new()
	city_camera.name = "Tycoon_Free_Camera"
	city_camera.fov = 58.0
	city_camera.near = 0.1
	city_camera.far = 650.0
	add_child(city_camera)
	city_camera.current = true
	_update_camera_transform()

func _add_tycoon_ground() -> void:
	_box(self, "Tycoon_Map_Base", Vector3(MAP_WIDTH, 0.8, MAP_DEPTH), Vector3(0.0, -0.48, 0.0), materials["ground"])
	_box(self, "Continuous_Empty_Grass_Field", Vector3(80.0, 0.08, 92.0), Vector3(0.0, -0.04, 0.0), materials["plot_base"])

func _add_expansion_slots() -> void:
	# Twelve empty, buildable plots. These are ground markings only, not buildings.
	var x_positions: Array[float] = [-25.0, 0.0, 25.0]
	var z_positions: Array[float] = [-34.0, -11.0, 11.0, 34.0]
	var slot_number := 0
	for z in z_positions:
		for x in x_positions:
			slot_number += 1
			_add_expansion_slot(slot_number, Vector3(x, 0.0, z))

func _add_expansion_slot(slot_number: int, center: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Empty_Expansion_Slot_%02d" % slot_number
	root.position = center
	add_child(root)
	var size := 9.0
	var y := 0.035
	_box(root, "Unbuilt_Plot_Surface", Vector3(size, 0.045, size), Vector3(0.0, y, 0.0), materials["plot_base"])
	_box(root, "Plot_Border_North", Vector3(size, 0.12, 0.16), Vector3(0.0, y + 0.06, -size * 0.5), materials["plot_border"])
	_box(root, "Plot_Border_South", Vector3(size, 0.12, 0.16), Vector3(0.0, y + 0.06, size * 0.5), materials["plot_border"])
	_box(root, "Plot_Border_West", Vector3(0.16, 0.12, size), Vector3(-size * 0.5, y + 0.06, 0.0), materials["plot_border"])
	_box(root, "Plot_Border_East", Vector3(0.16, 0.12, size), Vector3(size * 0.5, y + 0.06, 0.0), materials["plot_border"])
	for corner_x in [-1.0, 1.0]:
		for corner_z in [-1.0, 1.0]:
			_box(root, "Expansion_Corner_Marker", Vector3(0.22, 0.32, 0.22), Vector3(corner_x * (size * 0.5 - 0.2), 0.22, corner_z * (size * 0.5 - 0.2)), materials["plot_marker"])

func _add_headquarters() -> void:
	_build_procedural_building(2, Vector3.ZERO)
	var sign_z := 4.15
	_box(self, "Headquarters_Company_Sign", Vector3(4.0, 0.72, 0.18), Vector3(0.0, 3.55, sign_z), materials["hq_sign"])
	_box(self, "Headquarters_Sign_Accent", Vector3(3.45, 0.055, 0.035), Vector3(0.0, 3.27, sign_z + 0.105), materials["hq_accent"])

func _build_procedural_building(index: int, plot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Company_Headquarters"
	root.position = plot
	add_child(root)

	var style := 2
	var floor_count: int = 12
	var floor_height := 2.75
	var ground_height := 3.25
	var width := 7.7 + float(index % 3) * 0.22
	var depth := 7.7 + float((index + 1) % 3) * 0.18
	var height := ground_height + float(floor_count - 1) * floor_height
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
	_box(root, "Headquarters_Lobby_Podium", Vector3(width + 0.12, ground_height, depth + 0.12), Vector3(0.0, ground_height * 0.5 + 0.42, 0.0), podium)

	# Four elevations share the same procedural window grammar, but vary by style.
	for side in range(4):
		var angle := float(side) * PI * 0.5
		_add_facade_windows(root, angle, width, depth, floor_count, ground_height, floor_height, style)
		_add_facade_pilasters(root, angle, width, depth, height, accent, style)
		_add_facade_microdetails(root, angle, width, depth, floor_count, ground_height, floor_height, style, accent)

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
			frame_transforms.append(Transform3D(basis, basis * Vector3(x, y, facade_depth)))
			gasket_transforms.append(Transform3D(basis, basis * Vector3(x, y, facade_depth + 0.035)))
			glass_transforms.append(Transform3D(basis, basis * Vector3(x, y, facade_depth + 0.075)))
			sill_transforms.append(Transform3D(basis, basis * Vector3(x, y - 0.72, facade_depth + 0.06)))
			head_transforms.append(Transform3D(basis, basis * Vector3(x, y + 0.72, facade_depth + 0.055)))
			# Narrow highlights simulate reflected sky on the glazing without texture-heavy materials.
			reflection_transforms.append(Transform3D(basis, basis * Vector3(x - (0.30 if columns == 2 else 0.20), y, facade_depth + 0.132)))
			highlight_transforms.append(Transform3D(basis, basis * Vector3(x + (0.10 if columns == 2 else 0.06), y + 0.48, facade_depth + 0.132)))
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
	# Touch: one finger orbits; two fingers pan and pinch to zoom.
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
	# Desktop: right-drag orbit, middle-drag pan, mouse wheel zoom.
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
	camera_pitch = clampf(camera_pitch + relative.y * 0.0035, 0.12, 1.25)
	_update_camera_transform()

func _pan_camera(relative: Vector2) -> void:
	if not is_instance_valid(city_camera):
		return
	var scale := camera_distance * 0.0018
	var camera_right := city_camera.global_transform.basis.x
	camera_target -= camera_right * relative.x * scale
	camera_target += Vector3.UP * relative.y * scale
	camera_target.x = clampf(camera_target.x, -55.0, 55.0)
	camera_target.z = clampf(camera_target.z, -60.0, 60.0)
	camera_target.y = clampf(camera_target.y, 0.0, 35.0)
	_update_camera_transform()

func _zoom_camera(amount: float) -> void:
	camera_distance = clampf(camera_distance + amount, 48.0, 170.0)
	_update_camera_transform()

func _update_camera_transform() -> void:
	if not is_instance_valid(city_camera):
		return
	var horizontal_distance := cos(camera_pitch) * camera_distance
	var camera_offset := Vector3(
		sin(camera_yaw) * horizontal_distance,
		sin(camera_pitch) * camera_distance,
		cos(camera_yaw) * horizontal_distance
	)
	city_camera.global_position = camera_target + camera_offset
	city_camera.look_at(camera_target, Vector3.UP)
