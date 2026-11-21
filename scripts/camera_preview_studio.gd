extends Node

signal scene_changed(scene_index: int, scene_name: String)
signal photo_captured(photo_index: int)

const SCENES := [
	{"name": "Colour & Texture Lab", "kind": "tabletop", "sky": "#9AA9B4", "ground": "#4E5960", "accent": "#E7A34F"},
	{"name": "Portrait Studio", "kind": "portrait", "sky": "#9A8A80", "ground": "#5D4C46", "accent": "#D7A17C"},
	{"name": "Macro Botanicals", "kind": "macro", "sky": "#B6C8B0", "ground": "#52634D", "accent": "#E1A5C5"},
	{"name": "Glass & Metal", "kind": "tabletop", "sky": "#8F9BA7", "ground": "#4C5862", "accent": "#B9D8E5"},
	{"name": "Greenhouse", "kind": "forest", "sky": "#91AE9A", "ground": "#394F3D", "accent": "#A9CF76"},
	{"name": "City Skyline", "kind": "architecture", "sky": "#81A6C8", "ground": "#424D59", "accent": "#F0C77D"},
	{"name": "Old Town Street", "kind": "street", "sky": "#B8A18A", "ground": "#51473F", "accent": "#D7A06D"},
	{"name": "Neon District", "kind": "neon", "sky": "#252D55", "ground": "#171D32", "accent": "#F06AB8"},
	{"name": "Coastal Cliffs", "kind": "coast", "sky": "#86B6C7", "ground": "#536B71", "accent": "#D6C39A"},
	{"name": "Mountain Pass", "kind": "mountains", "sky": "#93AFC6", "ground": "#59665C", "accent": "#C5B08C"},
	{"name": "Waterfall Basin", "kind": "coast", "sky": "#789DA7", "ground": "#344F50", "accent": "#A9D6DD"},
	{"name": "Snow Pine Grove", "kind": "forest", "sky": "#A9C1D2", "ground": "#65717A", "accent": "#DCE8ED"},
	{"name": "Desert Caravan", "kind": "mountains", "sky": "#D4A46E", "ground": "#9A6B45", "accent": "#E8CC91"},
	{"name": "Night Market", "kind": "street", "sky": "#34364B", "ground": "#282633", "accent": "#F1A64F"},
	{"name": "Candlelit Room", "kind": "tabletop", "sky": "#51413C", "ground": "#292421", "accent": "#F5B65E"},
	{"name": "Star Observatory", "kind": "stars", "sky": "#111C38", "ground": "#141B2A", "accent": "#A7C7FF"},
	{"name": "Rainy Avenue", "kind": "street", "sky": "#536473", "ground": "#303B44", "accent": "#91B5C9"},
	{"name": "Sports Arena", "kind": "architecture", "sky": "#8CA3B5", "ground": "#48545E", "accent": "#DDAA61"},
	{"name": "Luxury Gallery", "kind": "gallery", "sky": "#AAA49A", "ground": "#5D5851", "accent": "#D6C39A"},
	{"name": "Industrial Workshop", "kind": "industrial", "sky": "#64727B", "ground": "#3B4449", "accent": "#D38B45"},
	{"name": "Food Photography", "kind": "food", "sky": "#BDAA91", "ground": "#645344", "accent": "#E5A45B"},
	{"name": "Jewellery Macro", "kind": "macro", "sky": "#626D7B", "ground": "#303947", "accent": "#E9D18B"},
	{"name": "Automobile Studio", "kind": "vehicle", "sky": "#939DA5", "ground": "#42494F", "accent": "#C5D0D6"},
	{"name": "Autumn Park", "kind": "forest", "sky": "#B99A77", "ground": "#6D5138", "accent": "#D68A42"},
	{"name": "Festival Lights", "kind": "neon", "sky": "#473B62", "ground": "#29233C", "accent": "#F17F9E"},
	{"name": "Museum Sculpture", "kind": "gallery", "sky": "#A5A9A8", "ground": "#565B59", "accent": "#C9B38C"},
	{"name": "Harbour Morning", "kind": "coast", "sky": "#8BB9C8", "ground": "#4C6871", "accent": "#D8C49B"},
	{"name": "Rooftop Sunset", "kind": "architecture", "sky": "#D28F72", "ground": "#55484B", "accent": "#F0C17D"},
	{"name": "Textile & Leather Lab", "kind": "tabletop", "sky": "#9D978B", "ground": "#514A42", "accent": "#C58D62"},
	{"name": "Low-Light Café", "kind": "food", "sky": "#443A38", "ground": "#282321", "accent": "#D79A55"}
]

const MIN_ZOOM := 1.0
const MAX_ZOOM := 5.0

var test_viewport: SubViewport
var test_world: Node3D
var test_scene_root: Node3D
var test_environment: Environment
var test_key_light: DirectionalLight3D
var test_fill_light: OmniLight3D
var test_camera: Camera3D

var screen_viewport: SubViewport
var screen_root: Control
var screen_feed: TextureRect
var screen_scene_label: Label
var screen_mode_label: Label
var screen_zoom_label: Label
var screen_photo_label: Label

var current_scene_index := 0
var zoom_level := 1.0
var night_mode_enabled := false
var night_mode_quality_level := 0
var gallery_open := false
var captured_photos: Array[Texture2D] = []


func _ready() -> void:
	_build_test_camera()
	_build_phone_camera_interface()
	_build_scene(current_scene_index)
	_update_screen_labels()


func get_screen_texture() -> Texture2D:
	if not is_instance_valid(screen_viewport):
		return null
	return screen_viewport.get_texture()


func get_scene_name() -> String:
	return str(SCENES[current_scene_index].get("name", "Camera Test Scene"))


func get_scene_count() -> int:
	return SCENES.size()


func next_scene() -> void:
	current_scene_index = (current_scene_index + 1) % SCENES.size()
	_build_scene(current_scene_index)
	_update_screen_labels()
	scene_changed.emit(current_scene_index, get_scene_name())


func zoom_camera(delta: float) -> void:
	zoom_level = clampf(zoom_level + delta, MIN_ZOOM, MAX_ZOOM)
	if is_instance_valid(test_camera):
		test_camera.fov = 52.0 / zoom_level
	_update_screen_labels()


func set_night_mode(enabled: bool, quality_level: int) -> void:
	# The initial unlock already enables usable Night Mode; upgrades improve its output.
	night_mode_quality_level = clampi(quality_level, 0, 30)
	night_mode_enabled = enabled
	if is_instance_valid(test_environment):
		test_environment.ambient_light_energy = 0.16 if night_mode_enabled else 0.78
		test_environment.tonemap_exposure = 1.25 + float(night_mode_quality_level) * 0.055 if night_mode_enabled else 1.0
	if is_instance_valid(test_key_light):
		test_key_light.light_energy = 0.18 if night_mode_enabled else 1.10
	if is_instance_valid(test_fill_light):
		test_fill_light.light_energy = 0.08 if night_mode_enabled else 0.34
	_update_screen_labels()


func capture_photo(source_image: Image = null) -> Texture2D:
	if not is_instance_valid(test_viewport):
		return null
	var captured_image: Image = source_image
	if captured_image == null:
		# Headless CI has no readable viewport texture; live gameplay always reads
		# the actual rendered 3D scene from the camera viewport.
		if DisplayServer.get_name() == "headless":
			return null
		var viewport_texture := test_viewport.get_texture()
		if viewport_texture == null:
			return null
		captured_image = viewport_texture.get_image()
	if captured_image == null or captured_image.is_empty():
		return null
	captured_image = captured_image.duplicate()
	captured_image.convert(Image.FORMAT_RGBA8)
	var photo := ImageTexture.create_from_image(captured_image)
	captured_photos.append(photo)
	gallery_open = false
	_update_screen_labels()
	photo_captured.emit(captured_photos.size())
	return photo


func open_gallery() -> Texture2D:
	if captured_photos.is_empty():
		return null
	gallery_open = true
	var latest_photo := captured_photos[captured_photos.size() - 1]
	screen_feed.texture = latest_photo
	_update_screen_labels()
	return latest_photo


func return_to_camera() -> void:
	gallery_open = false
	if is_instance_valid(screen_feed) and is_instance_valid(test_viewport):
		screen_feed.texture = test_viewport.get_texture()
	_update_screen_labels()


func has_photos() -> bool:
	return not captured_photos.is_empty()


func get_photo_count() -> int:
	return captured_photos.size()


func _build_test_camera() -> void:
	test_viewport = SubViewport.new()
	test_viewport.name = "CameraTestSceneViewport"
	test_viewport.size = Vector2i(480, 960)
	test_viewport.own_world_3d = true
	test_viewport.transparent_bg = false
	test_viewport.msaa_3d = Viewport.MSAA_2X
	test_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(test_viewport)

	test_world = Node3D.new()
	test_world.name = "CameraTestSceneWorld"
	test_viewport.add_child(test_world)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "CameraTestWorldEnvironment"
	test_environment = Environment.new()
	test_environment.background_mode = Environment.BG_COLOR
	test_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	test_environment.ambient_light_energy = 0.78
	test_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = test_environment
	test_world.add_child(world_environment)

	test_key_light = DirectionalLight3D.new()
	test_key_light.name = "CameraTestKeyLight"
	test_key_light.rotation_degrees = Vector3(-35.0, -22.0, 0.0)
	test_key_light.light_color = Color("#FFF1DB")
	test_key_light.light_energy = 1.10
	test_key_light.shadow_enabled = true
	test_world.add_child(test_key_light)

	test_fill_light = OmniLight3D.new()
	test_fill_light.name = "CameraTestFillLight"
	test_fill_light.position = Vector3(-2.0, 2.7, 2.0)
	test_fill_light.light_color = Color("#D5E4F2")
	test_fill_light.light_energy = 0.34
	test_fill_light.omni_range = 10.0
	test_world.add_child(test_fill_light)

	test_camera = Camera3D.new()
	test_camera.name = "CameraTestCaptureCamera"
	test_camera.position = Vector3(0.0, 1.45, 6.2)
	test_camera.fov = 52.0
	test_camera.near = 0.05
	test_camera.far = 120.0
	test_world.add_child(test_camera)
	test_camera.look_at(Vector3(0.0, 1.25, 0.0), Vector3.UP)
	test_camera.current = true


func _build_phone_camera_interface() -> void:
	screen_viewport = SubViewport.new()
	screen_viewport.name = "PhoneCameraAppViewport"
	screen_viewport.size = Vector2i(480, 960)
	screen_viewport.disable_3d = true
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(screen_viewport)

	screen_root = Control.new()
	screen_root.name = "PhoneCameraAppScreen"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_viewport.add_child(screen_root)

	screen_feed = TextureRect.new()
	screen_feed.name = "LiveCameraFeed"
	screen_feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_feed.texture = test_viewport.get_texture()
	screen_feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_feed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	screen_feed.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen_root.add_child(screen_feed)

	var top_shade := ColorRect.new()
	top_shade.name = "CameraStatusShade"
	top_shade.color = Color(0.02, 0.025, 0.035, 0.62)
	top_shade.anchor_right = 1.0
	top_shade.offset_bottom = 104.0
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(top_shade)

	var bottom_shade := ColorRect.new()
	bottom_shade.name = "CameraControlsShade"
	bottom_shade.color = Color(0.015, 0.02, 0.025, 0.78)
	bottom_shade.anchor_left = 0.0
	bottom_shade.anchor_top = 1.0
	bottom_shade.anchor_right = 1.0
	bottom_shade.anchor_bottom = 1.0
	bottom_shade.offset_top = -170.0
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(bottom_shade)

	screen_scene_label = _screen_label("CAMERA", 25, Color.WHITE)
	screen_scene_label.position = Vector2(22.0, 20.0)
	screen_scene_label.size = Vector2(330.0, 38.0)
	screen_root.add_child(screen_scene_label)

	screen_mode_label = _screen_label("DAY", 18, Color("#F6D08B"))
	screen_mode_label.position = Vector2(22.0, 66.0)
	screen_mode_label.size = Vector2(180.0, 28.0)
	screen_root.add_child(screen_mode_label)

	screen_zoom_label = _screen_label("1.0x", 22, Color.WHITE)
	screen_zoom_label.position = Vector2(390.0, 22.0)
	screen_zoom_label.size = Vector2(70.0, 32.0)
	screen_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen_root.add_child(screen_zoom_label)

	var reticle_horizontal := ColorRect.new()
	reticle_horizontal.name = "FocusReticleHorizontal"
	reticle_horizontal.color = Color(1.0, 1.0, 1.0, 0.62)
	reticle_horizontal.anchor_left = 0.5
	reticle_horizontal.anchor_top = 0.5
	reticle_horizontal.anchor_right = 0.5
	reticle_horizontal.anchor_bottom = 0.5
	reticle_horizontal.offset_left = -22.0
	reticle_horizontal.offset_right = 22.0
	reticle_horizontal.offset_top = -0.75
	reticle_horizontal.offset_bottom = 0.75
	reticle_horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(reticle_horizontal)

	var reticle_vertical := ColorRect.new()
	reticle_vertical.name = "FocusReticleVertical"
	reticle_vertical.color = Color(1.0, 1.0, 1.0, 0.62)
	reticle_vertical.anchor_left = 0.5
	reticle_vertical.anchor_top = 0.5
	reticle_vertical.anchor_right = 0.5
	reticle_vertical.anchor_bottom = 0.5
	reticle_vertical.offset_left = -0.75
	reticle_vertical.offset_right = 0.75
	reticle_vertical.offset_top = -22.0
	reticle_vertical.offset_bottom = 22.0
	reticle_vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(reticle_vertical)

	var shutter_ring := Panel.new()
	shutter_ring.name = "CameraShutterIndicator"
	shutter_ring.anchor_left = 0.5
	shutter_ring.anchor_top = 1.0
	shutter_ring.anchor_right = 0.5
	shutter_ring.anchor_bottom = 1.0
	shutter_ring.offset_left = -38.0
	shutter_ring.offset_right = 38.0
	shutter_ring.offset_top = -132.0
	shutter_ring.offset_bottom = -56.0
	shutter_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shutter_style := StyleBoxFlat.new()
	shutter_style.bg_color = Color(0.92, 0.92, 0.90, 0.96)
	shutter_style.border_color = Color(0.12, 0.14, 0.16, 0.95)
	shutter_style.set_border_width_all(5)
	shutter_style.set_corner_radius_all(40)
	shutter_ring.add_theme_stylebox_override("panel", shutter_style)
	screen_root.add_child(shutter_ring)

	screen_photo_label = _screen_label("READY", 17, Color("#E9E5DC"))
	screen_photo_label.anchor_left = 0.0
	screen_photo_label.anchor_top = 1.0
	screen_photo_label.anchor_right = 1.0
	screen_photo_label.anchor_bottom = 1.0
	screen_photo_label.offset_left = 18.0
	screen_photo_label.offset_right = -18.0
	screen_photo_label.offset_top = -43.0
	screen_photo_label.offset_bottom = -12.0
	screen_photo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_root.add_child(screen_photo_label)


func _screen_label(value: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_scene(scene_index: int) -> void:
	if is_instance_valid(test_scene_root):
		test_scene_root.free()
	var scene: Dictionary = SCENES[clampi(scene_index, 0, SCENES.size() - 1)]
	test_scene_root = Node3D.new()
	test_scene_root.name = "CameraTestScene_%02d" % (scene_index + 1)
	test_world.add_child(test_scene_root)

	test_environment.background_color = Color(str(scene.get("sky", "#8096A5")))
	test_environment.ambient_light_color = Color(str(scene.get("ground", "#56616A")))
	var ground_colour := Color(str(scene.get("ground", "#56616A")))
	var accent_colour := Color(str(scene.get("accent", "#D0A46B")))
	var kind := str(scene.get("kind", "tabletop"))

	_add_box(test_scene_root, "StudioGround", Vector3(0.0, -0.16, -1.0), Vector3(18.0, 0.28, 18.0), ground_colour, 0.05, 0.72)
	_add_box(test_scene_root, "StudioBackdrop", Vector3(0.0, 3.4, -7.2), Vector3(18.0, 7.0, 0.24), Color(str(scene.get("sky", "#8096A5"))).darkened(0.18), 0.0, 0.92)
	_add_box(test_scene_root, "CalibrationObject", Vector3(-2.0, 0.65, 0.0), Vector3(0.72, 1.3, 0.52), Color("#D6D8D9"), 0.15, 0.34)
	_add_sphere(test_scene_root, "ColourReferenceSphere", Vector3(0.0, 0.68, -0.1), 0.58, accent_colour, 0.18, 0.26)
	_add_cylinder(test_scene_root, "TextureReferenceCylinder", Vector3(1.65, 0.62, 0.15), 0.44, 1.24, Color("#718FA2"), 0.62, 0.24)

	match kind:
		"portrait":
			_build_portrait_subject(test_scene_root, accent_colour)
		"macro":
			_build_macro_subject(test_scene_root, accent_colour, scene_index)
		"architecture":
			_build_architecture_subject(test_scene_root, accent_colour, scene_index)
		"street":
			_build_street_subject(test_scene_root, accent_colour, scene_index)
		"forest":
			_build_forest_subject(test_scene_root, accent_colour, scene_index)
		"mountains":
			_build_mountain_subject(test_scene_root, accent_colour, scene_index)
		"coast":
			_build_coast_subject(test_scene_root, accent_colour, scene_index)
		"stars":
			_build_star_subject(test_scene_root, accent_colour)
		"gallery":
			_build_gallery_subject(test_scene_root, accent_colour, scene_index)
		"industrial":
			_build_industrial_subject(test_scene_root, accent_colour)
		"food":
			_build_food_subject(test_scene_root, accent_colour, scene_index)
		"vehicle":
			_build_vehicle_subject(test_scene_root, accent_colour)
		_:
			_build_tabletop_subject(test_scene_root, accent_colour, scene_index)

	_apply_night_mode_lighting()


func _build_portrait_subject(parent: Node3D, accent: Color) -> void:
	_add_sphere(parent, "PortraitShoulders", Vector3(0.0, 0.55, -1.45), 1.12, accent.darkened(0.25))
	_add_sphere(parent, "PortraitHead", Vector3(0.0, 1.95, -1.15), 0.68, Color("#B98262"))
	_add_sphere(parent, "PortraitHair", Vector3(0.0, 2.38, -1.2), 0.61, Color("#28272A"))
	_add_sphere(parent, "PortraitEyeLeft", Vector3(-0.23, 2.02, -0.55), 0.065, Color("#22252A"))
	_add_sphere(parent, "PortraitEyeRight", Vector3(0.23, 2.02, -0.55), 0.065, Color("#22252A"))
	_add_box(parent, "PortraitBackdropPanel", Vector3(0.0, 2.0, -3.2), Vector3(3.4, 4.7, 0.12), accent.darkened(0.42))


func _build_macro_subject(parent: Node3D, accent: Color, seed: int) -> void:
	for flower_index in range(5):
		var x := -1.75 + float(flower_index) * 0.86
		var height := 1.1 + float((flower_index + seed) % 3) * 0.42
		_add_cylinder(parent, "MacroStem_%d" % flower_index, Vector3(x, height * 0.5, -1.15), 0.035, height, Color("#477A4E"))
		_add_sphere(parent, "MacroFlowerCore_%d" % flower_index, Vector3(x, height + 0.12, -1.15), 0.16, Color("#E8C45A"))
		for petal_index in range(6):
			var angle := TAU * float(petal_index) / 6.0
			_add_sphere(parent, "MacroPetal_%d_%d" % [flower_index, petal_index], Vector3(x + cos(angle) * 0.22, height + 0.12 + sin(angle) * 0.22, -1.15), 0.15, accent)
	_add_sphere(parent, "MacroLeafLeft", Vector3(-1.0, 0.55, -0.9), 0.38, Color("#568B55"))
	_add_sphere(parent, "MacroLeafRight", Vector3(1.15, 0.72, -1.25), 0.34, Color("#6C9E5F"))


func _build_architecture_subject(parent: Node3D, accent: Color, seed: int) -> void:
	for building_index in range(8):
		var x := -3.2 + float(building_index) * 0.92
		var floors := 3 + ((building_index + seed) % 5)
		var height := float(floors) * 0.64
		var width := 0.72
		_add_box(parent, "Tower_%d" % building_index, Vector3(x, height * 0.5 - 0.02, -2.3 - float(building_index % 3) * 0.4), Vector3(width, height, 0.72), Color("#657987").lerp(accent, float(building_index % 3) * 0.12), 0.25, 0.3)
		for floor_index in range(floors):
			for side_index in range(2):
				_add_box(parent, "TowerWindow_%d_%d_%d" % [building_index, floor_index, side_index], Vector3(x - 0.18 + float(side_index) * 0.36, 0.28 + float(floor_index) * 0.64, -1.91 - float(building_index % 3) * 0.4), Vector3(0.13, 0.22, 0.035), accent.lightened(0.12), 0.18, 0.18)
	_add_box(parent, "ArchitecturePlaza", Vector3(0.0, 0.08, -0.45), Vector3(7.5, 0.14, 2.2), Color("#9A9A91"), 0.12, 0.45)


func _build_street_subject(parent: Node3D, accent: Color, seed: int) -> void:
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		for building_index in range(3):
			var height := 2.2 + float((building_index + seed) % 3) * 0.82
			var x: float = side * (2.2 + float(building_index) * 1.0)
			_add_box(parent, "StreetBuilding_%s_%d" % [str(side), building_index], Vector3(x, height * 0.5, -2.0 - float(building_index) * 0.7), Vector3(1.1, height, 1.2), accent.darkened(0.28 + float(building_index) * 0.06), 0.05, 0.55)
			_add_box(parent, "StreetShopfront_%s_%d" % [str(side), building_index], Vector3(x, 0.65, -1.36 - float(building_index) * 0.7), Vector3(0.75, 0.78, 0.05), accent.lightened(0.10), 0.0, 0.2)
	_add_box(parent, "StreetRoad", Vector3(0.0, 0.04, 0.0), Vector3(2.5, 0.08, 12.0), Color("#30353A"), 0.12, 0.64)
	for line_index in range(5):
		_add_box(parent, "RoadMarking_%d" % line_index, Vector3(0.0, 0.09, -4.0 + float(line_index) * 1.9), Vector3(0.10, 0.015, 0.8), Color("#E3D7B5"), 0.0, 0.4)


func _build_forest_subject(parent: Node3D, accent: Color, seed: int) -> void:
	for tree_index in range(9):
		var x := -3.5 + float(tree_index % 3) * 3.2
		var z := -3.6 + float(tree_index / 3) * 2.1
		var height := 2.2 + float((tree_index + seed) % 4) * 0.38
		_add_cylinder(parent, "TreeTrunk_%d" % tree_index, Vector3(x, height * 0.38, z), 0.16, height * 0.76, Color("#654934"))
		_add_sphere(parent, "TreeCanopy_%d" % tree_index, Vector3(x, height * 0.84, z), 0.9 + float(tree_index % 2) * 0.18, accent.lerp(Color("#477A56"), 0.45), 0.0, 0.82)
	_add_sphere(parent, "ForegroundPlant", Vector3(-1.4, 0.35, 1.5), 0.42, Color("#91B56E"))


func _build_mountain_subject(parent: Node3D, accent: Color, seed: int) -> void:
	for mountain_index in range(5):
		var x := -3.8 + float(mountain_index) * 1.9
		var height := 2.5 + float((mountain_index + seed) % 3) * 0.9
		_add_cone(parent, "MountainPeak_%d" % mountain_index, Vector3(x, height * 0.48, -3.7 - float(mountain_index % 2)), 1.7, height, accent.darkened(float(mountain_index) * 0.07))
	_add_box(parent, "MountainTrail", Vector3(0.0, 0.08, 1.0), Vector3(2.2, 0.12, 4.5), Color("#A58C68"))


func _build_coast_subject(parent: Node3D, accent: Color, seed: int) -> void:
	_add_box(parent, "OceanPlane", Vector3(0.0, 0.02, -1.2), Vector3(14.0, 0.10, 9.0), Color("#3E879A"), 0.48, 0.22)
	for cliff_index in range(6):
		var x := -4.0 + float(cliff_index) * 1.6
		var height := 1.3 + float((cliff_index + seed) % 4) * 0.6
		_add_sphere(parent, "CoastalRock_%d" % cliff_index, Vector3(x, height * 0.45, -3.3 - float(cliff_index % 2)), 0.85 + height * 0.18, accent.darkened(0.2), 0.04, 0.9)


func _build_star_subject(parent: Node3D, accent: Color) -> void:
	_add_sphere(parent, "ObservatoryMoon", Vector3(1.7, 3.0, -5.0), 0.72, Color("#D4D8E4"), 0.05, 0.18)
	for star_index in range(48):
		var x := -4.2 + float((star_index * 17) % 84) * 0.1
		var y := 1.0 + float((star_index * 29) % 58) * 0.1
		var z := -5.9 - float(star_index % 4) * 0.12
		_add_sphere(parent, "Star_%02d" % star_index, Vector3(x, y, z), 0.025 + float(star_index % 3) * 0.012, accent.lightened(float(star_index % 4) * 0.1), 0.0, 0.05)


func _build_gallery_subject(parent: Node3D, accent: Color, seed: int) -> void:
	for column_index in range(4):
		var x := -3.2 + float(column_index) * 2.1
		_add_box(parent, "GalleryColumn_%d" % column_index, Vector3(x, 1.65, -3.2), Vector3(0.24, 3.3, 0.24), Color("#D7D0C3"), 0.12, 0.62)
		_add_box(parent, "GalleryArtwork_%d" % column_index, Vector3(x, 1.9, -2.95), Vector3(1.2, 1.55, 0.10), accent.lerp(Color("#6D8795"), float(column_index) * 0.15), 0.08, 0.48)
	_add_cylinder(parent, "GallerySculpture", Vector3(0.0, 0.8, -0.8), 0.58, 1.6 + float(seed % 2) * 0.5, Color("#B7AC98"), 0.62, 0.22)


func _build_industrial_subject(parent: Node3D, accent: Color) -> void:
	for index in range(5):
		var x := -3.0 + float(index) * 1.5
		_add_cylinder(parent, "IndustrialTank_%d" % index, Vector3(x, 1.1, -2.4), 0.48, 2.2, Color("#647A83"), 0.62, 0.28)
		_add_box(parent, "IndustrialWarningBand_%d" % index, Vector3(x, 1.05, -1.9), Vector3(0.99, 0.18, 0.05), accent, 0.25, 0.3)
	_add_cylinder(parent, "IndustrialPipe", Vector3(0.0, 2.65, -3.4), 0.10, 6.4, Color("#A8B3B5"), 0.72, 0.24)


func _build_food_subject(parent: Node3D, accent: Color, seed: int) -> void:
	_add_cylinder(parent, "FoodPlate", Vector3(0.0, 0.19, -0.75), 1.42, 0.10, Color("#E7E4DD"), 0.18, 0.2)
	for food_index in range(7):
		var angle := TAU * float(food_index) / 7.0
		var radius := 0.46 + float(food_index % 2) * 0.22
		var item_position := Vector3(cos(angle) * radius, 0.48, -0.75 + sin(angle) * radius)
		_add_sphere(parent, "FoodItem_%d" % food_index, item_position, 0.28, accent.lerp(Color("#6B9B56"), float((food_index + seed) % 3) * 0.18))
	_add_box(parent, "Tabletop", Vector3(0.0, -0.04, -0.75), Vector3(4.5, 0.14, 3.5), Color("#694C36"), 0.12, 0.72)


func _build_vehicle_subject(parent: Node3D, accent: Color) -> void:
	_add_box(parent, "VehicleBody", Vector3(0.0, 0.82, -1.2), Vector3(3.8, 0.76, 1.65), accent, 0.7, 0.24)
	_add_box(parent, "VehicleCabin", Vector3(0.0, 1.45, -1.25), Vector3(2.15, 0.72, 1.32), Color("#6B8797"), 0.55, 0.16)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		for axle_value in [-1.0, 1.0]:
			var axle: float = float(axle_value)
			_add_cylinder(parent, "VehicleWheel_%s_%s" % [str(side), str(axle)], Vector3(side * 1.5, 0.45, -1.2 + axle * 0.58), 0.39, 0.22, Color("#202326"), 0.10, 0.9)


func _build_tabletop_subject(parent: Node3D, accent: Color, seed: int) -> void:
	_add_box(parent, "TableSurface", Vector3(0.0, 0.34, -0.7), Vector3(5.8, 0.18, 4.0), Color("#755940"), 0.16, 0.58)
	for item_index in range(6):
		var x := -2.1 + float(item_index) * 0.84
		var y := 0.83 + float((item_index + seed) % 3) * 0.22
		if item_index % 3 == 0:
			_add_sphere(parent, "TableObject_%d" % item_index, Vector3(x, y, -0.8), 0.38, accent.lerp(Color("#DCE1E4"), float(item_index) * 0.08), 0.28, 0.28)
		elif item_index % 3 == 1:
			_add_box(parent, "TableObject_%d" % item_index, Vector3(x, y, -0.8), Vector3(0.52, 0.68, 0.52), accent.darkened(0.14), 0.12, 0.48)
		else:
			_add_cylinder(parent, "TableObject_%d" % item_index, Vector3(x, y, -0.8), 0.27, 0.62, accent.lightened(0.12), 0.32, 0.30)


func _apply_night_mode_lighting() -> void:
	if not is_instance_valid(test_environment):
		return
	test_environment.ambient_light_energy = 0.16 if night_mode_enabled else 0.78
	test_environment.tonemap_exposure = 1.25 + float(night_mode_quality_level) * 0.055 if night_mode_enabled else 1.0
	if is_instance_valid(test_key_light):
		test_key_light.light_energy = 0.18 if night_mode_enabled else 1.10
	if is_instance_valid(test_fill_light):
		test_fill_light.light_energy = 0.08 if night_mode_enabled else 0.34


func _add_box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3, colour: Color, metallic: float = 0.0, roughness: float = 0.62) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _make_material(colour, metallic, roughness, false)
	instance.position = position_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, position_value: Vector3, radius: float, colour: Color, metallic: float = 0.0, roughness: float = 0.55) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	instance.mesh = mesh
	instance.material_override = _make_material(colour, metallic, roughness, false)
	instance.position = position_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, position_value: Vector3, radius: float, height: float, colour: Color, metallic: float = 0.0, roughness: float = 0.55) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	instance.mesh = mesh
	instance.material_override = _make_material(colour, metallic, roughness, false)
	instance.position = position_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_cone(parent: Node3D, node_name: String, position_value: Vector3, radius: float, height: float, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := PrismMesh.new()
	mesh.size = Vector3(radius * 2.0, height, radius * 2.0)
	instance.mesh = mesh
	instance.material_override = _make_material(colour, 0.02, 0.88, false)
	instance.position = position_value
	parent.add_child(instance)
	return instance


func _make_material(colour: Color, metallic: float, roughness: float, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 1.6
	return material


func _update_screen_labels() -> void:
	if is_instance_valid(screen_scene_label):
		screen_scene_label.text = get_scene_name().to_upper()
	if is_instance_valid(screen_mode_label):
		screen_mode_label.text = "NIGHT MODE  •  LEVEL %d" % night_mode_quality_level if night_mode_enabled else "DAY MODE"
	if is_instance_valid(screen_zoom_label):
		screen_zoom_label.text = "%.1fx" % zoom_level
	if is_instance_valid(screen_photo_label):
		if gallery_open:
			screen_photo_label.text = "GALLERY  •  PHOTO %02d" % captured_photos.size()
		elif captured_photos.is_empty():
			screen_photo_label.text = "READY  •  TAP CAPTURE"
		else:
			screen_photo_label.text = "READY  •  %d PHOTO%s SAVED" % [captured_photos.size(), "" if captured_photos.size() == 1 else "S"]
		screen_photo_label.add_theme_color_override("font_color", Color("#F6D08B") if gallery_open else Color("#E9E5DC"))
