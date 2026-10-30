extends Node3D
class_name DigitalWorldHeadquarters

signal map_requested
signal preview_level_changed(level: int)

const MAX_LEVEL := 10
const LEVEL_CONFIGS := [
	{"name": "Workshop", "floors": 1, "width": 12.4, "depth": 9.4, "ground_height": 4.2, "floor_height": 3.0, "style": 0},
	{"name": "Small Office", "floors": 2, "width": 9.4, "depth": 8.6, "ground_height": 3.4, "floor_height": 2.8, "style": 1},
	{"name": "Business Office", "floors": 4, "width": 10.0, "depth": 9.0, "ground_height": 3.5, "floor_height": 2.8, "style": 1},
	{"name": "Corporate Office", "floors": 6, "width": 10.4, "depth": 9.5, "ground_height": 3.55, "floor_height": 2.85, "style": 2},
	{"name": "Commercial Tower", "floors": 9, "width": 10.8, "depth": 9.7, "ground_height": 3.6, "floor_height": 2.85, "style": 2},
	{"name": "Business Tower", "floors": 12, "width": 11.0, "depth": 10.0, "ground_height": 3.65, "floor_height": 2.9, "style": 2},
	{"name": "Enterprise Tower", "floors": 15, "width": 11.4, "depth": 10.2, "ground_height": 3.7, "floor_height": 2.95, "style": 3},
	{"name": "Corporate Skyscraper", "floors": 18, "width": 11.8, "depth": 10.6, "ground_height": 3.75, "floor_height": 3.0, "style": 3},
	{"name": "Grand Headquarters", "floors": 22, "width": 12.5, "depth": 11.0, "ground_height": 3.8, "floor_height": 3.0, "style": 4},
	{"name": "Global Headquarters", "floors": 26, "width": 13.2, "depth": 11.4, "ground_height": 3.9, "floor_height": 3.0, "style": 4}
]

var preview_level: int = 1
var owned_level: int = 1
var company_name := "YOUR COMPANY"
var building_root: Node3D
var hq_camera: Camera3D
var level_info_label: Label
var owned_info_label: Label
var previous_level_button: Button
var next_level_button: Button
var camera_target := Vector3.ZERO
var camera_distance := 38.0
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
	owned_level = clampi(owned_level, 1, MAX_LEVEL)
	_create_material_library()
	_create_procedural_surface_textures()
	_create_environment()
	_create_presentation_stage()
	var building_height := _build_procedural_building(preview_level)
	_create_camera(building_height)
	_create_preview_interface()

func _create_material_library() -> void:
	materials = {
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
		"hq_accent": _emissive_mat(Color("#50b9e8"), 1.8),
		"stage_ground": _mat(Color("#263f4c"), 0.92),
		"stage_deck": _mat(Color("#405b68"), 0.72, 0.22),
		"stage_trim": _emissive_mat(Color("#4daed5"), 1.2),
		"workshop_cladding": _mat(Color("#8d9b9d"), 0.72, 0.22),
		"workshop_shutter": _mat(Color("#394b52"), 0.65, 0.42)
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
	environment.ambient_light_energy = 0.72
	environment.ambient_light_sky_contribution = 0.88
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world.environment = environment
	add_child(world)

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
	fill.light_color = Color("#8bcfff")
	fill.light_energy = 1.1
	fill.omni_range = 42.0
	fill.shadow_enabled = false
	add_child(fill)

func _create_presentation_stage() -> void:
	var ground := _box(self, "Headquarters_Studio_Ground", Vector3(90.0, 0.7, 90.0), Vector3(0.0, -0.55, 0.0), materials["stage_ground"])
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(self, "Headquarters_Presentation_Deck", Vector3(22.0, 0.24, 22.0), Vector3(0.0, -0.12, 0.0), materials["stage_deck"])
	_box(self, "Deck_Trim_Front", Vector3(22.1, 0.07, 0.14), Vector3(0.0, 0.035, 11.0), materials["stage_trim"])
	_box(self, "Deck_Trim_Back", Vector3(22.1, 0.07, 0.14), Vector3(0.0, 0.035, -11.0), materials["stage_trim"])
	_box(self, "Deck_Trim_Left", Vector3(0.14, 0.07, 22.1), Vector3(-11.0, 0.035, 0.0), materials["stage_trim"])
	_box(self, "Deck_Trim_Right", Vector3(0.14, 0.07, 22.1), Vector3(11.0, 0.035, 0.0), materials["stage_trim"])

func _create_camera(building_height: float) -> void:
	camera_target = Vector3(0.0, building_height * 0.46, 0.0)
	camera_distance = maxf(29.0, building_height * 1.78)
	camera_yaw = 0.62
	camera_pitch = 0.24
	hq_camera = Camera3D.new()
	hq_camera.name = "Headquarters_Preview_Camera"
	hq_camera.fov = 52.0
	hq_camera.near = 0.1
	hq_camera.far = 650.0
	add_child(hq_camera)
	hq_camera.current = true
	_update_camera_transform()

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
		Color("#34464c"), Color("#665548"), Color("#263e4b"), Color("#4b5554"), Color("#34444a")
	]
	var wall := _mat(wall_colors[style], 0.86, 0.04)
	if level == 1:
		wall.albedo_color = Color("#8d9b9d")
		wall.roughness = 0.72
		wall.metallic = 0.22
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

	_box(building_root, "Architectural_Foundation_Plinth", Vector3(width + 0.7, 0.42, depth + 0.7), Vector3(0.0, 0.21, 0.0), materials["concrete"])
	_box(building_root, "Main_Architectural_Envelope", Vector3(width, height, depth), Vector3(0.0, height * 0.5 + 0.42, 0.0), wall)
	_box(building_root, "Ground_Floor_Podium", Vector3(width + 0.12, ground_height, depth + 0.12), Vector3(0.0, ground_height * 0.5 + 0.42, 0.0), podium)

	if level == 1:
		_add_workshop_features(building_root, width, depth, height)
	else:
		for side in range(4):
			var angle := float(side) * PI * 0.5
			_add_facade_windows(building_root, angle, width, depth, floor_count, ground_height, floor_height, style)
			_add_facade_pilasters(building_root, angle, width, depth, height, accent, style)
			_add_facade_microdetails(building_root, angle, width, depth, floor_count, ground_height, floor_height, style, accent)
		_add_main_entrance(building_root, width, depth, ground_height, accent)

	for floor_index in range(1, floor_count):
		var floor_y := 0.42 + ground_height + float(floor_index - 1) * floor_height
		_box(building_root, "Expressed_Floor_Slab", Vector3(width + 0.22, 0.11, depth + 0.22), Vector3(0.0, floor_y, 0.0), accent)

	if level > 1:
		_box(building_root, "Roof_Cornice", Vector3(width + 0.55, 0.28, depth + 0.55), Vector3(0.0, height + 0.54, 0.0), accent)
		_box(building_root, "Rooftop_Service_Penthouse", Vector3(width * 0.38, 1.15, depth * 0.38), Vector3(-width * 0.18, height + 1.23, -depth * 0.16), roof)
		_box(building_root, "Rooftop_HVAC_Equipment", Vector3(1.25, 0.55, 0.9), Vector3(width * 0.2, height + 0.92, depth * 0.18), materials["metal"])
		_add_rooftop_service_details(building_root, width, depth, height, roof, accent)
		if level >= 4:
			_add_vertical_fins(building_root, height, accent, width, depth)
		_add_level_silhouette_features(building_root, level, width, depth, height, accent, roof)

	_box(building_root, "Company_Headquarters_Sign", Vector3(width * 0.55, 0.42, 0.12), Vector3(0.0, ground_height + 0.48, depth * 0.5 + 0.24), materials["hq_sign"])
	_box(building_root, "Company_Sign_Accent", Vector3(width * 0.48, 0.045, 0.035), Vector3(0.0, ground_height + 0.25, depth * 0.5 + 0.31), materials["hq_accent"])
	return height

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
	var crown_height := 0.0
	if level == 2 or level == 3:
		var floors: int = int(LEVEL_CONFIGS[level - 1]["floors"])
		var floor_height: float = float(LEVEL_CONFIGS[level - 1]["floor_height"])
		var ground_height: float = float(LEVEL_CONFIGS[level - 1]["ground_height"])
		for floor_index in range(1, floors):
			var y := 0.42 + ground_height + float(floor_index - 1) * floor_height + 0.35
			_box(parent, "Lowrise_Front_Balcony_Slab", Vector3(width * 0.76, 0.12, 0.72), Vector3(0.0, y, depth * 0.5 + 0.23), materials["concrete"])
			_box(parent, "Lowrise_Balcony_Glass_Rail", Vector3(width * 0.72, 0.72, 0.055), Vector3(0.0, y + 0.40, depth * 0.5 + 0.56), materials["glass"])
	if level >= 6:
		for side in [-1.0, 1.0]:
			var fin_x := side * (width * 0.5 + 0.18)
			_box(parent, "Tower_Outer_Corner_Fin", Vector3(0.26, height * 0.94, 0.36), Vector3(fin_x, height * 0.5 + 0.42, depth * 0.5 + 0.10), accent)
	if level >= 8:
		crown_height = 2.0 + float(level - 8) * 0.55
		var crown_width := width * (0.78 if level < 10 else 0.68)
		var crown_depth := depth * (0.78 if level < 10 else 0.70)
		_box(parent, "Distinctive_Stepback_Crown", Vector3(crown_width, crown_height, crown_depth), Vector3(0.0, height + crown_height * 0.5, 0.0), accent)
		_box(parent, "Crown_Glazed_Band", Vector3(crown_width * 0.88, 0.32, crown_depth * 0.88), Vector3(0.0, height + crown_height * 0.62, 0.0), materials["glass"])
		_box(parent, "Crown_Roof_Cap", Vector3(crown_width + 0.42, 0.22, crown_depth + 0.42), Vector3(0.0, height + crown_height, 0.0), roof)
	if level >= 9:
		for side in [-1.0, 1.0]:
			_box(parent, "Crown_Vertical_Blade", Vector3(0.16, crown_height, 0.20), Vector3(side * width * 0.23, height + 1.4, depth * 0.40), materials["hq_accent"])
	if level == 10:
		_cylinder(parent, "Global_Headquarters_Crown_Mast", 0.12, 0.20, 7.5, Vector3(0.0, height + crown_height + 3.85, 0.0), materials["metal"])
		_box(parent, "Global_Headquarters_Crown_Light", Vector3(0.72, 0.28, 0.72), Vector3(0.0, height + crown_height + 7.7, 0.0), materials["hq_accent"])

func _rebuild_preview() -> void:
	if is_instance_valid(building_root):
		building_root.queue_free()
	building_root = null
	var height := _build_procedural_building(preview_level)
	camera_target = Vector3(0.0, height * 0.46, 0.0)
	camera_distance = maxf(29.0, height * 1.78)
	_update_camera_transform()
	_refresh_preview_interface()
	preview_level_changed.emit(preview_level)

func _show_previous_level() -> void:
	if preview_level <= 1:
		return
	preview_level -= 1
	_rebuild_preview()

func _show_next_level() -> void:
	if preview_level >= MAX_LEVEL:
		return
	preview_level += 1
	_rebuild_preview()

func _create_preview_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Headquarters_Preview_Interface"
	layer.layer = 20
	add_child(layer)

	var map_button := Button.new()
	map_button.name = "Back_To_Expansion_Map"
	map_button.text = "‹  EXPANSION MAP"
	map_button.anchor_left = 0.0
	map_button.anchor_top = 0.0
	map_button.anchor_right = 0.0
	map_button.anchor_bottom = 0.0
	map_button.offset_left = 16.0
	map_button.offset_top = 16.0
	map_button.offset_right = 204.0
	map_button.offset_bottom = 68.0
	map_button.add_theme_font_size_override("font_size", 13)
	_style_preview_button(map_button, false)
	map_button.pressed.connect(func(): map_requested.emit())
	layer.add_child(map_button)

	var header := PanelContainer.new()
	header.name = "Headquarters_Level_Header"
	header.anchor_left = 0.5
	header.anchor_top = 0.0
	header.anchor_right = 0.5
	header.anchor_bottom = 0.0
	header.offset_left = -188.0
	header.offset_top = 14.0
	header.offset_right = 188.0
	header.offset_bottom = 124.0
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.035, 0.12, 0.19, 0.90)
	header_style.border_color = Color("#4aa5d3")
	header_style.set_border_width_all(1)
	header_style.set_corner_radius_all(12)
	header_style.content_margin_left = 14.0
	header_style.content_margin_right = 14.0
	header_style.content_margin_top = 8.0
	header_style.content_margin_bottom = 8.0
	header.add_theme_stylebox_override("panel", header_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	header.add_child(stack)
	var title := Label.new()
	title.text = "HEADQUARTERS PREVIEW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#9edfff"))
	stack.add_child(title)
	var company_label := Label.new()
	company_label.text = company_name.to_upper()
	company_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	company_label.add_theme_font_size_override("font_size", 10)
	company_label.add_theme_color_override("font_color", Color("#c6e6f6"))
	company_label.clip_text = true
	stack.add_child(company_label)
	level_info_label = Label.new()
	level_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_info_label.add_theme_font_size_override("font_size", 19)
	level_info_label.add_theme_color_override("font_color", Color("#ffffff"))
	stack.add_child(level_info_label)
	owned_info_label = Label.new()
	owned_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_info_label.add_theme_font_size_override("font_size", 10)
	owned_info_label.add_theme_color_override("font_color", Color("#c6e6f6"))
	stack.add_child(owned_info_label)
	layer.add_child(header)

	previous_level_button = _create_side_level_button(layer, "Previous_Level_Button", "‹", true)
	previous_level_button.pressed.connect(_show_previous_level)
	next_level_button = _create_side_level_button(layer, "Next_Level_Button", "›", false)
	next_level_button.pressed.connect(_show_next_level)

	var bottom_layer := PanelContainer.new()
	bottom_layer.name = "Fixed_Bottom_Navigation"
	bottom_layer.anchor_left = 0.0
	bottom_layer.anchor_top = 1.0
	bottom_layer.anchor_right = 1.0
	bottom_layer.anchor_bottom = 1.0
	bottom_layer.offset_left = 8.0
	bottom_layer.offset_top = -78.0
	bottom_layer.offset_right = -8.0
	bottom_layer.offset_bottom = -8.0
	var bottom_style := StyleBoxFlat.new()
	bottom_style.bg_color = Color("#102638")
	bottom_style.border_color = Color("#397da5")
	bottom_style.set_border_width_all(1)
	bottom_style.set_corner_radius_all(12)
	bottom_style.content_margin_left = 7.0
	bottom_style.content_margin_right = 7.0
	bottom_style.content_margin_top = 6.0
	bottom_style.content_margin_bottom = 6.0
	bottom_layer.add_theme_stylebox_override("panel", bottom_style)
	layer.add_child(bottom_layer)

	var row := HBoxContainer.new()
	row.name = "Navigation_Buttons_Row"
	row.add_theme_constant_override("separation", 5)
	bottom_layer.add_child(row)
	for button_name in ["Create", "Products", "Research", "Marketing", "Media", "Office", "Statistics"]:
		var button := Button.new()
		button.name = button_name + "_Button"
		button.text = button_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.add_theme_font_size_override("font_size", 12)
		_style_preview_button(button, false)
		row.add_child(button)

	_refresh_preview_interface()

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
		var config: Dictionary = LEVEL_CONFIGS[preview_level - 1]
		level_info_label.text = "LEVEL %02d / %02d  ·  %s" % [preview_level, MAX_LEVEL, str(config["name"]).to_upper()]
	if is_instance_valid(owned_info_label):
		var owned_name: String = str(LEVEL_CONFIGS[owned_level - 1]["name"])
		var preview_status := "CURRENT COMPANY LEVEL"
		if preview_level != owned_level:
			preview_status = "PREVIEW ONLY  ·  CURRENT LEVEL: %02d" % owned_level
		owned_info_label.text = "%s  ·  %s" % [preview_status, owned_name.to_upper()]
	if is_instance_valid(previous_level_button):
		previous_level_button.disabled = preview_level <= 1
	if is_instance_valid(next_level_button):
		next_level_button.disabled = preview_level >= MAX_LEVEL

func _style_preview_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#155477") if primary else Color(0.035, 0.12, 0.19, 0.90)
		if state == "hover":
			style.bg_color = Color("#217fa9") if primary else Color("#1b5574")
		elif state == "pressed":
			style.bg_color = Color("#0c3c58")
		elif state == "disabled":
			style.bg_color = Color(0.10, 0.18, 0.22, 0.55)
		style.border_color = Color("#8bd6ff") if primary else Color("#4aa5d3")
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
	var scale := camera_distance * 0.0016
	var camera_right := hq_camera.global_transform.basis.x
	camera_target -= camera_right * relative.x * scale
	camera_target += Vector3.UP * relative.y * scale
	camera_target.x = clampf(camera_target.x, -24.0, 24.0)
	camera_target.z = clampf(camera_target.z, -24.0, 24.0)
	camera_target.y = clampf(camera_target.y, 0.0, 150.0)
	_update_camera_transform()

func _zoom_camera(amount: float) -> void:
	camera_distance = clampf(camera_distance + amount, 12.0, 260.0)
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
