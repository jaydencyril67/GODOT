extends Node3D
class_name DigitalWorldCity

signal headquarters_requested

# The expansion map remains a separate environment with the original footprint.
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

func _ready() -> void:
	_create_material_library()
	_create_environment()
	_create_camera()
	_add_tycoon_ground()
	_add_expansion_slots()
	_create_map_navigation()

func _create_material_library() -> void:
	materials = {
		"ground": _mat(Color("#668b58"), 0.98),
		"plot_base": _mat(Color("#78966a"), 0.96),
		"plot_border": _mat(Color("#c5d2c2"), 0.82, 0.08),
		"plot_marker": _emissive_mat(Color("#8fc8e8"), 1.15)
	}

func _create_map_navigation() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Expansion_Map_Interface"
	layer.layer = 10
	add_child(layer)

	var heading := PanelContainer.new()
	heading.name = "Expansion_Map_Heading"
	heading.anchor_left = 0.0
	heading.anchor_top = 0.0
	heading.anchor_right = 0.0
	heading.anchor_bottom = 0.0
	heading.offset_left = 16.0
	heading.offset_top = 16.0
	heading.offset_right = 270.0
	heading.offset_bottom = 78.0
	var heading_style := StyleBoxFlat.new()
	heading_style.bg_color = Color(0.035, 0.12, 0.19, 0.88)
	heading_style.border_color = Color("#397da5")
	heading_style.set_border_width_all(1)
	heading_style.set_corner_radius_all(10)
	heading_style.content_margin_left = 14.0
	heading_style.content_margin_right = 14.0
	heading_style.content_margin_top = 8.0
	heading_style.content_margin_bottom = 8.0
	heading.add_theme_stylebox_override("panel", heading_style)
	var heading_label := Label.new()
	heading_label.text = "COMPANY EXPANSION MAP"
	heading_label.add_theme_font_size_override("font_size", 15)
	heading_label.add_theme_color_override("font_color", Color("#eaf6ff"))
	heading.add_child(heading_label)
	layer.add_child(heading)

	var headquarters_button := Button.new()
	headquarters_button.name = "Open_Headquarters_Button"
	headquarters_button.text = "HEADQUARTERS  ↗"
	headquarters_button.anchor_left = 1.0
	headquarters_button.anchor_top = 0.0
	headquarters_button.anchor_right = 1.0
	headquarters_button.anchor_bottom = 0.0
	headquarters_button.offset_left = -218.0
	headquarters_button.offset_top = 16.0
	headquarters_button.offset_right = -16.0
	headquarters_button.offset_bottom = 68.0
	headquarters_button.add_theme_font_size_override("font_size", 14)
	headquarters_button.add_theme_color_override("font_color", Color("#ffffff"))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("#155477")
	button_style.border_color = Color("#8bd6ff")
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(10)
	headquarters_button.add_theme_stylebox_override("normal", button_style)
	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#217fa9")
	headquarters_button.add_theme_stylebox_override("hover", hover_style)
	headquarters_button.pressed.connect(func(): headquarters_requested.emit())
	layer.add_child(headquarters_button)

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

func _unhandled_input(event: InputEvent) -> void:
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

func _mat(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.metallic_specular = 0.62
	return material

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color, 0.24, 0.05)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
