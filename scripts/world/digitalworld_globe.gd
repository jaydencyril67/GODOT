extends Node3D

signal back_requested

const EARTH_TEXTURE: Texture2D = preload("res://assets/globe/earth_blue_marble.jpg")
const CLOUD_TEXTURE: Texture2D = preload("res://assets/globe/earth_clouds.jpg")
const COUNTRY_DATA_PATH := "res://assets/globe/natural_earth_countries.json"
const COUNTRY_DATA_50M_PATH := "res://assets/globe/natural_earth_countries_50m.json.gz"
const COUNTRY_DATA_10M_PATH := "res://assets/globe/natural_earth_countries_10m.json.gz"
const STATE_DATA_10M_PATH := "res://assets/globe/natural_earth_states_10m.json.gz"
const EARTH_RADIUS := 1.6
const DRAG_SENSITIVITY := 0.0024
const ZOOM_MIN := 2.25
const ZOOM_MAX := 7.2
const COUNTRY_BOUNDARY_ZOOM_THRESHOLD := 4.5
const COUNTRY_LABEL_ZOOM_THRESHOLDS := [4.5, 3.8, 3.2]

var earth_pivot: Node3D
var globe_camera: Camera3D
var _zoom_distance := 4.9
var _touch_points: Dictionary = {}
var _previous_pinch_distance := 0.0
var _mouse_dragging := false
var cloud_layer: MeshInstance3D
var country_boundaries: MeshInstance3D
var country_labels: Array[Label3D] = []
var state_boundaries: MeshInstance3D
var _country_geography_loaded := false
var _country_geography_tier := ""
var _country_feature_data: Array = []
var _state_geography_loaded := false
var _state_geography_continent := ""
var _state_refresh_elapsed := 0.0


func _ready() -> void:
	_build_environment()
	_build_starfield()
	_build_earth()
	_build_camera()
	_update_country_label_visibility()
	_build_interface()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#020711")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8daac8")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Earth_Sunlight"
	sunlight.rotation_degrees = Vector3(-24.0, -32.0, -18.0)
	sunlight.light_color = Color("#fff0d7")
	sunlight.light_energy = 1.65
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 12.0
	add_child(sunlight)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "Soft_Ocean_Fill"
	fill_light.rotation_degrees = Vector3(18.0, 145.0, 0.0)
	fill_light.light_color = Color("#3b75a8")
	fill_light.light_energy = 0.18
	fill_light.shadow_enabled = false
	add_child(fill_light)


func _build_starfield() -> void:
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.012
	star_mesh.height = 0.024
	star_mesh.radial_segments = 6
	star_mesh.rings = 4

	var star_material := StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.albedo_color = Color("#b9cce5")
	star_mesh.material = star_material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = star_mesh
	multimesh.instance_count = 220

	var random := RandomNumberGenerator.new()
	random.seed = 847291
	for index in range(multimesh.instance_count):
		var direction := Vector3(
			random.randf_range(-1.0, 1.0),
			random.randf_range(-1.0, 1.0),
			random.randf_range(-1.0, 1.0)
		).normalized()
		var distance := random.randf_range(13.0, 24.0)
		var star_transform := Transform3D(Basis(), direction * distance)
		multimesh.set_instance_transform(index, star_transform)

	var stars := MultiMeshInstance3D.new()
	stars.name = "Distant_Stars"
	stars.multimesh = multimesh
	add_child(stars)


func _build_earth() -> void:
	earth_pivot = Node3D.new()
	earth_pivot.name = "Earth_Rotation_Pivot"
	earth_pivot.rotation_degrees = Vector3(-7.0, -22.0, 0.0)
	add_child(earth_pivot)

	var earth_mesh := SphereMesh.new()
	earth_mesh.radius = EARTH_RADIUS
	earth_mesh.height = EARTH_RADIUS * 2.0
	earth_mesh.radial_segments = 256
	earth_mesh.rings = 128

	var earth_material := StandardMaterial3D.new()
	earth_material.albedo_texture = EARTH_TEXTURE
	earth_material.albedo_color = Color.WHITE
	earth_material.roughness = 0.96
	earth_material.metallic = 0.0
	earth_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	earth_material.cull_mode = BaseMaterial3D.CULL_BACK

	var earth_surface := MeshInstance3D.new()
	earth_surface.name = "Earth_Surface"
	earth_surface.mesh = earth_mesh
	earth_surface.material_override = earth_material
	earth_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	earth_surface.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	earth_pivot.add_child(earth_surface)

	# NASA Blue Marble cloud coverage is rendered on its own slightly elevated shell.
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = EARTH_RADIUS * 1.009
	cloud_mesh.height = EARTH_RADIUS * 2.018
	cloud_mesh.radial_segments = 192
	cloud_mesh.rings = 96

	var cloud_shader := Shader.new()
	cloud_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	float coverage = texture(cloud_texture, UV).r;
	float cloud_alpha = smoothstep(0.16, 0.58, coverage) * 0.72;
	ALBEDO = vec3(0.91, 0.94, 1.0);
	ROUGHNESS = 1.0;
	ALPHA = cloud_alpha;
}
"""
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = cloud_shader
	cloud_material.set_shader_parameter("cloud_texture", CLOUD_TEXTURE)

	cloud_layer = MeshInstance3D.new()
	cloud_layer.name = "Earth_Cloud_Layer"
	cloud_layer.mesh = cloud_mesh
	cloud_layer.material_override = cloud_material
	cloud_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_layer.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	earth_pivot.add_child(cloud_layer)

	var atmosphere_mesh := SphereMesh.new()
	atmosphere_mesh.radius = EARTH_RADIUS * 1.035
	atmosphere_mesh.height = EARTH_RADIUS * 2.07
	atmosphere_mesh.radial_segments = 96
	atmosphere_mesh.rings = 48

	var atmosphere_shader := Shader.new()
	atmosphere_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	ALBEDO = vec3(0.12, 0.38, 0.82);
	ALPHA = rim * 0.42;
}
"""
	var atmosphere_material := ShaderMaterial.new()
	atmosphere_material.shader = atmosphere_shader

	var atmosphere := MeshInstance3D.new()
	atmosphere.name = "Earth_Atmosphere_Rim"
	atmosphere.mesh = atmosphere_mesh
	atmosphere.material_override = atmosphere_material
	atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	atmosphere.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	earth_pivot.add_child(atmosphere)


func _build_camera() -> void:
	globe_camera = Camera3D.new()
	globe_camera.name = "Globe_Camera"
	globe_camera.fov = 42.0
	globe_camera.near = 0.1
	globe_camera.far = 80.0
	add_child(globe_camera)
	globe_camera.current = true
	_update_camera_zoom()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Globe_Interface"
	layer.layer = 40
	add_child(layer)

	var root := Control.new()
	root.name = "Globe_Interface_Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var back_button := Button.new()
	back_button.name = "Globe_Back_Button"
	back_button.text = "←  BACK TO MENU"
	back_button.position = Vector2(18.0, 18.0)
	back_button.custom_minimum_size = Vector2(174.0, 48.0)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_color_override("font_color", Color("#f3eee4"))
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.025, 0.045, 0.075, 0.92)
	back_style.border_color = Color("#527ca8")
	back_style.set_border_width_all(1)
	back_style.set_corner_radius_all(12)
	back_style.content_margin_left = 12
	back_style.content_margin_right = 12
	back_button.add_theme_stylebox_override("normal", back_style)
	back_button.add_theme_stylebox_override("hover", back_style)
	back_button.add_theme_stylebox_override("pressed", back_style)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	root.add_child(back_button)

	var title := Label.new()
	title.name = "Globe_Title"
	title.text = "THE WORLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26.0
	title.offset_bottom = 62.0
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#edf3fb"))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Globe_Subtitle"
	subtitle.text = "SATELLITE EARTH  •  ZOOM TO EXPLORE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 62.0
	subtitle.offset_bottom = 88.0
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color("#88a7c8"))
	root.add_child(subtitle)

	var controls_hint := Label.new()
	controls_hint.name = "Globe_Controls_Hint"
	controls_hint.text = "DRAG TO ROTATE     •     PINCH TO ZOOM"
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls_hint.offset_top = -54.0
	controls_hint.offset_bottom = -22.0
	controls_hint.add_theme_font_size_override("font_size", 10)
	controls_hint.add_theme_color_override("font_color", Color("#9aafc7"))
	root.add_child(controls_hint)


func _process(delta: float) -> void:
	if is_instance_valid(cloud_layer):
		cloud_layer.rotation.y += delta * 0.0008
	if _zoom_distance <= 3.2 and _state_geography_loaded:
		_state_refresh_elapsed += delta
		if _state_refresh_elapsed >= 0.45:
			_state_refresh_elapsed = 0.0
			if _get_nearest_country_continent() != _state_geography_continent:
				_build_state_geography()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
			if _touch_points.size() == 2:
				_previous_pinch_distance = _get_pinch_distance()
		else:
			_touch_points.erase(touch.index)
			_previous_pinch_distance = 0.0
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touch_points.has(drag.index):
			_touch_points[drag.index] = drag.position
		if _touch_points.size() >= 2:
			var pinch_distance := _get_pinch_distance()
			if _previous_pinch_distance > 0.0:
				zoom_globe((_previous_pinch_distance - pinch_distance) * 0.012)
			_previous_pinch_distance = pinch_distance
		else:
			rotate_globe(drag.relative)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = mouse_button.pressed
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_globe(-0.35)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_globe(0.35)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_dragging:
		rotate_globe((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()


func _get_pinch_distance() -> float:
	if _touch_points.size() < 2:
		return 0.0
	var keys := _touch_points.keys()
	var first_position: Vector2 = _touch_points[keys[0]]
	var second_position: Vector2 = _touch_points[keys[1]]
	return first_position.distance_to(second_position)


func rotate_globe(pointer_delta: Vector2) -> void:
	if not is_instance_valid(earth_pivot):
		return
	# Match the phone worksite: lock each drag to its dominant axis for controlled,
	# predictable movement instead of combining pitch and yaw on diagonal gestures.
	if absf(pointer_delta.x) >= absf(pointer_delta.y):
		earth_pivot.rotation.y += pointer_delta.x * DRAG_SENSITIVITY
	else:
		earth_pivot.rotation.x = clampf(
			earth_pivot.rotation.x - pointer_delta.y * DRAG_SENSITIVITY,
			-1.25,
			1.25
		)


func zoom_globe(distance_delta: float) -> void:
	_zoom_distance = clampf(_zoom_distance + distance_delta, ZOOM_MIN, ZOOM_MAX)
	_update_camera_zoom()


func _update_camera_zoom() -> void:
	if not is_instance_valid(globe_camera):
		return
	globe_camera.position = Vector3(0.0, 0.0, _zoom_distance)
	globe_camera.look_at(Vector3.ZERO, Vector3.UP)
	_update_country_label_visibility()


func _read_geography_data(path: String) -> Variant:
	var file: FileAccess
	if path.ends_with(".gz"):
		file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	else:
		file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Geographic data could not be opened: " + path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("features"):
		push_warning("Geographic data is malformed: " + path)
		return null
	return parsed


func _resolve_country_data_path() -> String:
	if _zoom_distance <= 3.8 and FileAccess.file_exists(COUNTRY_DATA_10M_PATH):
		return COUNTRY_DATA_10M_PATH
	if FileAccess.file_exists(COUNTRY_DATA_50M_PATH):
		return COUNTRY_DATA_50M_PATH
	return COUNTRY_DATA_PATH


func _build_country_geography() -> void:
	var data_path := _resolve_country_data_path()
	var tier := "110m"
	if data_path == COUNTRY_DATA_50M_PATH:
		tier = "50m"
	elif data_path == COUNTRY_DATA_10M_PATH:
		tier = "10m"
	if _country_geography_loaded and _country_geography_tier == tier:
		return

	var parsed: Variant = _read_geography_data(data_path)
	if parsed == null:
		return
	_country_feature_data = parsed["features"]
	if is_instance_valid(country_boundaries):
		earth_pivot.remove_child(country_boundaries)
		country_boundaries.queue_free()
	for old_label in country_labels:
		if is_instance_valid(old_label):
			old_label.queue_free()
	country_labels.clear()
	_country_geography_loaded = false

	# Google-Earth-inspired cartographic styling: quiet cool-grey boundaries,
	# shaded by globe lighting and depth-tested against the satellite terrain.
	var border_material := StandardMaterial3D.new()
	border_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	border_material.albedo_color = Color(0.62, 0.66, 0.70, 0.68)
	border_material.roughness = 1.0
	border_material.metallic = 0.0
	border_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_material.no_depth_test = false
	border_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var border_mesh := ImmediateMesh.new()
	border_mesh.surface_begin(Mesh.PRIMITIVE_LINES, border_material)
	var feature_count := 0
	var segment_count := 0
	var drawn_boundary_edges: Dictionary = {}
	for feature_variant in parsed["features"]:
		if not feature_variant is Dictionary:
			continue
		var feature: Dictionary = feature_variant
		feature_count += 1
		for ring_variant in feature.get("r", []):
			if not ring_variant is Array:
				continue
			var ring: Array = ring_variant
			if ring.size() < 2:
				continue
			for point_index in range(ring.size()):
				var point_a: Array = ring[point_index]
				var point_b: Array = ring[(point_index + 1) % ring.size()]
				if point_a.size() < 2 or point_b.size() < 2:
					continue
				if absf(float(point_b[0]) - float(point_a[0])) > 180.0:
					continue
				var edge_key := _geographic_edge_key(
					float(point_a[1]), float(point_a[0]),
					float(point_b[1]), float(point_b[0])
				)
				if drawn_boundary_edges.has(edge_key):
					continue
				drawn_boundary_edges[edge_key] = true
				_append_geographic_segment(
					border_mesh,
					float(point_a[1]),
					float(point_a[0]),
					float(point_b[1]),
					float(point_b[0]),
					EARTH_RADIUS * 1.0007
				)
				segment_count += 1
	border_mesh.surface_end()

	country_boundaries = MeshInstance3D.new()
	country_boundaries.name = "Country_Boundaries"
	country_boundaries.mesh = border_mesh
	country_boundaries.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	country_boundaries.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	country_boundaries.visible = false
	earth_pivot.add_child(country_boundaries)
	country_boundaries.set_meta("country_feature_count", feature_count)
	country_boundaries.set_meta("geographic_segment_count", segment_count)
	country_boundaries.set_meta("surface_radius", EARTH_RADIUS * 1.0007)
	country_boundaries.set_meta("cartographic_style", "subtle_google_earth_inspired_admin0_" + tier)
	country_boundaries.set_meta("geographic_resolution", tier)

	for feature_variant in parsed["features"]:
		if not feature_variant is Dictionary:
			continue
		var feature: Dictionary = feature_variant
		var label := Label3D.new()
		label.name = "Country_Label_" + str(feature.get("n", "Unknown")).replace(" ", "_")
		label.text = str(feature.get("n", ""))
		label.position = _geo_to_globe_position(float(feature.get("y", 0.0)), float(feature.get("x", 0.0)), EARTH_RADIUS * 1.014)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.font_size = 40
		label.pixel_size = 0.00042
		label.modulate = Color(0.91, 0.94, 0.97, 0.92)
		label.outline_size = 4
		label.outline_modulate = Color(0.015, 0.025, 0.045, 0.82)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.set_meta("natural_earth_label_rank", int(feature.get("rank", 5)))
		earth_pivot.add_child(label)
		country_labels.append(label)

	_country_geography_loaded = feature_count > 0
	_country_geography_tier = tier
	if feature_count == 0:
		push_warning("Natural Earth country data contained no country features.")


func _get_nearest_country_continent() -> String:
	if _country_feature_data.is_empty():
		return "other"
	var camera_direction := earth_pivot.to_local(globe_camera.global_position).normalized()
	var best_dot := -2.0
	var best_continent := "other"
	for feature_variant in _country_feature_data:
		if not feature_variant is Dictionary:
			continue
		var feature: Dictionary = feature_variant
		var direction := _geo_to_globe_position(
			float(feature.get("y", 0.0)),
			float(feature.get("x", 0.0)),
			1.0
		).normalized()
		var facing_score := camera_direction.dot(direction)
		if facing_score > best_dot:
			best_dot = facing_score
			best_continent = str(feature.get("continent", "other")).to_lower().replace(" ", "_")
	if best_continent not in ["africa", "asia", "europe", "north_america", "south_america", "oceania", "antarctica"]:
		best_continent = "other"
	return best_continent


func _build_state_geography() -> void:
	var continent := _get_nearest_country_continent()
	if _state_geography_loaded and _state_geography_continent == continent:
		return
	var state_path := "res://assets/globe/natural_earth_states_10m_" + continent + ".json.gz"
	if not FileAccess.file_exists(state_path):
		if is_instance_valid(state_boundaries):
			earth_pivot.remove_child(state_boundaries)
			state_boundaries.queue_free()
		state_boundaries = null
		_state_geography_loaded = false
		_state_geography_continent = continent
		return
	var parsed: Variant = _read_geography_data(state_path)
	if parsed == null:
		return

	var state_material := StandardMaterial3D.new()
	state_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	state_material.albedo_color = Color(0.48, 0.55, 0.62, 0.48)
	state_material.roughness = 1.0
	state_material.metallic = 0.0
	state_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	state_material.no_depth_test = false
	state_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var state_mesh := ImmediateMesh.new()
	state_mesh.surface_begin(Mesh.PRIMITIVE_LINES, state_material)
	var feature_count := 0
	var segment_count := 0
	var drawn_edges: Dictionary = {}
	for feature_variant in parsed["features"]:
		if not feature_variant is Dictionary:
			continue
		var feature: Dictionary = feature_variant
		feature_count += 1
		for ring_variant in feature.get("r", []):
			if not ring_variant is Array:
				continue
			var ring: Array = ring_variant
			if ring.size() < 2:
				continue
			for point_index in range(ring.size()):
				var point_a: Array = ring[point_index]
				var point_b: Array = ring[(point_index + 1) % ring.size()]
				if point_a.size() < 2 or point_b.size() < 2:
					continue
				if absf(float(point_b[0]) - float(point_a[0])) > 180.0:
					continue
				var edge_key := _geographic_edge_key(
					float(point_a[1]), float(point_a[0]),
					float(point_b[1]), float(point_b[0])
				)
				if drawn_edges.has(edge_key):
					continue
				drawn_edges[edge_key] = true
				_append_geographic_segment(
					state_mesh,
					float(point_a[1]),
					float(point_a[0]),
					float(point_b[1]),
					float(point_b[0]),
					EARTH_RADIUS * 1.0009
				)
				segment_count += 1
	state_mesh.surface_end()

	if is_instance_valid(state_boundaries):
		earth_pivot.remove_child(state_boundaries)
		state_boundaries.queue_free()
	state_boundaries = MeshInstance3D.new()
	state_boundaries.name = "State_Province_Boundaries"
	state_boundaries.mesh = state_mesh
	state_boundaries.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	state_boundaries.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	state_boundaries.visible = _zoom_distance <= 3.2
	earth_pivot.add_child(state_boundaries)
	state_boundaries.set_meta("state_feature_count", feature_count)
	state_boundaries.set_meta("geographic_segment_count", segment_count)
	state_boundaries.set_meta("geographic_resolution", "10m_admin1")
	state_boundaries.set_meta("continent", continent)
	_state_geography_loaded = feature_count > 0
	_state_geography_continent = continent


func _geographic_edge_key(latitude_a: float, longitude_a: float, latitude_b: float, longitude_b: float) -> String:
	var point_a := "%.3f,%.3f" % [latitude_a, longitude_a]
	var point_b := "%.3f,%.3f" % [latitude_b, longitude_b]
	if point_a < point_b:
		return point_a + "|" + point_b
	return point_b + "|" + point_a


func _append_geographic_segment(
	mesh: ImmediateMesh,
	latitude_a: float,
	longitude_a: float,
	latitude_b: float,
	longitude_b: float,
	radius: float
) -> void:
	var direction_a := _geo_to_globe_position(latitude_a, longitude_a, 1.0).normalized()
	var direction_b := _geo_to_globe_position(latitude_b, longitude_b, 1.0).normalized()
	var angular_distance := rad_to_deg(direction_a.angle_to(direction_b))
	var subdivisions := maxi(1, ceili(angular_distance / 0.5))
	for step in range(subdivisions):
		var start_weight := float(step) / float(subdivisions)
		var end_weight := float(step + 1) / float(subdivisions)
		var start_direction := direction_a.slerp(direction_b, start_weight).normalized()
		var end_direction := direction_a.slerp(direction_b, end_weight).normalized()
		mesh.surface_add_vertex(start_direction * radius)
		mesh.surface_add_vertex(end_direction * radius)


func _geo_to_globe_position(latitude: float, longitude: float, radius: float) -> Vector3:
	# The equirectangular Blue Marble texture starts at 180°W on its left
	# edge. Godot's SphereMesh seam is at UV x=0, so rotate geographic
	# longitude by 180° to keep vector data registered to the satellite map.
	var latitude_radians := deg_to_rad(clampf(latitude, -90.0, 90.0))
	var longitude_radians := deg_to_rad(wrapf(longitude + 180.0, -180.0, 180.0))
	var horizontal_radius := cos(latitude_radians) * radius
	return Vector3(
		sin(longitude_radians) * horizontal_radius,
		sin(latitude_radians) * radius,
		cos(longitude_radians) * horizontal_radius
	)


func _update_country_label_visibility() -> void:
	# Load only the geographic level justified by the current camera zoom.
	var show_boundaries := _zoom_distance <= COUNTRY_BOUNDARY_ZOOM_THRESHOLD
	if show_boundaries:
		_build_country_geography()
	if is_instance_valid(country_boundaries):
		country_boundaries.visible = show_boundaries

	var max_label_rank := -1
	if _zoom_distance <= COUNTRY_LABEL_ZOOM_THRESHOLDS[0]:
		max_label_rank = 2
	if _zoom_distance <= COUNTRY_LABEL_ZOOM_THRESHOLDS[1]:
		max_label_rank = 4
	if _zoom_distance <= COUNTRY_LABEL_ZOOM_THRESHOLDS[2]:
		max_label_rank = 7
	for label in country_labels:
		if is_instance_valid(label):
			label.visible = max_label_rank >= 0 and int(label.get_meta("natural_earth_label_rank", 5)) <= max_label_rank

	var show_states := _zoom_distance <= 3.2
	if show_states and not _state_geography_loaded and FileAccess.file_exists(STATE_DATA_10M_PATH):
		_build_state_geography()
	if is_instance_valid(state_boundaries):
		state_boundaries.visible = show_states



func get_zoom_distance() -> float:
	return _zoom_distance
