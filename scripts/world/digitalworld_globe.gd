extends Node3D

signal back_requested

const EARTH_TEXTURE: Texture2D = preload("res://assets/globe/earth_blue_marble.jpg")
const CLOUD_TEXTURE: Texture2D = preload("res://assets/globe/earth_clouds.jpg")
const COUNTRY_DATA_PATH := "res://assets/globe/natural_earth_countries.json"
const COUNTRY_DATA_50M_PATH := "res://assets/globe/natural_earth_countries_50m.json"
const COUNTRY_DATA_10M_PATH := "res://assets/globe/natural_earth_countries_10m.json"
const EARTH_RADIUS := 1.6
const DRAG_SENSITIVITY := 0.00075
const ROTATION_SMOOTHING := 8.5
const ROTATION_INPUT_LIMIT := 60.0
const ZOOM_MIN := 1.9
const ZOOM_MAX := 7.2
const COUNTRY_BOUNDARY_ZOOM_THRESHOLD := 5.1
const COUNTRY_LABEL_ZOOM_THRESHOLDS := [4.5, 3.8, 3.0]

var earth_pivot: Node3D
var globe_camera: Camera3D
var _zoom_distance := 4.9
var _zoom_target_distance := 4.9
var _zoom_settle_elapsed := 0.0
var _geography_refresh_pending := false
var _touch_points: Dictionary = {}
var _previous_pinch_distance := 0.0
var _mouse_dragging := false
var _rotation_target := Vector2.ZERO
var cloud_layer: MeshInstance3D
var country_boundaries: MeshInstance3D
var country_labels: Array[Label3D] = []
var state_boundaries: MeshInstance3D
var _country_geography_loaded := false
var _country_geography_tier := ""
var _country_feature_data: Array = []
var _country_building := false
var _state_geography_loaded := false
var _state_geography_continent := ""
var _state_building := false
var _state_refresh_elapsed := 0.0

var _debug_panel_label: Label
var _debug_panel: PanelContainer
var _debug_load_stage := "Waiting for globe startup"
var _debug_last_error := "None"
var _debug_dataset_path := "Not selected"
var _debug_asset_bytes := 0
var _debug_parsed_features := 0
var _debug_rendered_segments := 0
var _debug_country_labels := 0
var _debug_state_features := 0
var _debug_state_segments := 0
var _debug_parse_format := "Unknown"


func _ready() -> void:
	_build_environment()
	_build_starfield()
	_build_earth()
	_rotation_target = Vector2(earth_pivot.rotation.y, earth_pivot.rotation.x)
	_build_camera()
	_update_country_label_visibility()
	_build_interface()
	# Load the compact country layer on entry so the globe never opens as an
	# unlabelled satellite sphere while waiting for the first pinch gesture.
	call_deferred("_build_country_geography")


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
	globe_camera.fov = 38.0
	globe_camera.near = 0.03
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

	var debug_button := Button.new()
	debug_button.name = "Globe_Debug_Toggle"
	debug_button.text = "DEBUG"
	debug_button.position = Vector2(-112.0, 18.0)
	debug_button.anchor_left = 1.0
	debug_button.anchor_right = 1.0
	debug_button.custom_minimum_size = Vector2(94.0, 48.0)
	debug_button.focus_mode = Control.FOCUS_NONE
	debug_button.add_theme_font_size_override("font_size", 13)
	debug_button.add_theme_color_override("font_color", Color("#dcecff"))
	debug_button.add_theme_stylebox_override("normal", back_style)
	debug_button.add_theme_stylebox_override("hover", back_style)
	debug_button.add_theme_stylebox_override("pressed", back_style)
	root.add_child(debug_button)

	_debug_panel = PanelContainer.new()
	_debug_panel.name = "Globe_Debug_Panel"
	_debug_panel.anchor_left = 1.0
	_debug_panel.anchor_right = 1.0
	_debug_panel.position = Vector2(-minf(350.0, get_viewport().get_visible_rect().size.x - 20.0), 76.0)
	_debug_panel.custom_minimum_size = Vector2(330.0, 280.0)
	_debug_panel.size = Vector2(330.0, 280.0)
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var debug_style := StyleBoxFlat.new()
	debug_style.bg_color = Color(0.008, 0.018, 0.035, 0.94)
	debug_style.border_color = Color("#4c789f")
	debug_style.set_border_width_all(1)
	debug_style.set_corner_radius_all(10)
	debug_style.content_margin_left = 12
	debug_style.content_margin_right = 12
	debug_style.content_margin_top = 10
	debug_style.content_margin_bottom = 10
	_debug_panel.add_theme_stylebox_override("panel", debug_style)
	root.add_child(_debug_panel)

	_debug_panel_label = Label.new()
	_debug_panel_label.name = "Globe_Debug_Readout"
	_debug_panel_label.add_theme_font_size_override("font_size", 11)
	_debug_panel_label.add_theme_color_override("font_color", Color("#d7e6f5"))
	_debug_panel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var debug_content := VBoxContainer.new()
	debug_content.add_theme_constant_override("separation", 8)
	_debug_panel.add_child(debug_content)
	debug_content.add_child(_debug_panel_label)

	var copy_debug_button := Button.new()
	copy_debug_button.name = "Globe_Debug_Copy_Button"
	copy_debug_button.text = "COPY DIAGNOSTICS"
	copy_debug_button.custom_minimum_size = Vector2(0.0, 38.0)
	copy_debug_button.focus_mode = Control.FOCUS_NONE
	copy_debug_button.add_theme_font_size_override("font_size", 12)
	copy_debug_button.add_theme_color_override("font_color", Color("#dcecff"))
	copy_debug_button.add_theme_stylebox_override("normal", back_style)
	copy_debug_button.add_theme_stylebox_override("hover", back_style)
	copy_debug_button.add_theme_stylebox_override("pressed", back_style)
	copy_debug_button.pressed.connect(func() -> void:
		_update_debug_panel()
		DisplayServer.clipboard_set(_debug_panel_label.text)
		copy_debug_button.text = "COPIED TO CLIPBOARD"
	)
	debug_content.add_child(copy_debug_button)

	debug_button.pressed.connect(func() -> void:
		_debug_panel.visible = not _debug_panel.visible
		_update_debug_panel()
	)
	_update_debug_panel()



func _process(delta: float) -> void:
	_update_debug_panel()
	if is_instance_valid(cloud_layer):
		cloud_layer.rotation.y += delta * 0.0008

	# Smooth globe orientation independently from touch input sampling.
	# This filters small finger-direction changes and keeps movement consistent
	# across the full zoom range.
	if is_instance_valid(earth_pivot):
		var rotation_blend := 1.0 - exp(-delta * ROTATION_SMOOTHING)
		earth_pivot.rotation.y = lerp_angle(earth_pivot.rotation.y, _rotation_target.x, rotation_blend)
		earth_pivot.rotation.x = lerpf(earth_pivot.rotation.x, _rotation_target.y, rotation_blend)


	# Wait until pinch input settles before parsing data or constructing meshes.
	if _geography_refresh_pending:
		_zoom_settle_elapsed += delta
		if _zoom_settle_elapsed >= 0.28 and is_equal_approx(_zoom_distance, _zoom_target_distance):
			_geography_refresh_pending = false
			_zoom_settle_elapsed = 0.0
			_refresh_geography_for_zoom()


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
				zoom_globe((_previous_pinch_distance - pinch_distance) * 0.008)
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
	# Limit sudden input spikes, then accumulate into a target orientation.
	# The target is smoothed in _process(), avoiding jitter from event-by-event
	# axis switching while preserving precise horizontal and vertical control.
	var stable_delta := pointer_delta.limit_length(ROTATION_INPUT_LIMIT)
	var zoom_factor := clampf(_zoom_distance / 4.9, 0.58, 1.0)
	var rotation_step := stable_delta * DRAG_SENSITIVITY * zoom_factor
	_rotation_target.x = wrapf(_rotation_target.x + rotation_step.x, -PI, PI)
	_rotation_target.y = clampf(_rotation_target.y - rotation_step.y, -1.25, 1.25)

func zoom_globe(distance_delta: float) -> void:
	# Pinch movement directly controls the camera; there is no glide after release.
	_zoom_distance = clampf(_zoom_distance + distance_delta, ZOOM_MIN, ZOOM_MAX)
	_zoom_target_distance = _zoom_distance
	_update_camera_position()
	_update_country_label_visibility()
	_zoom_settle_elapsed = 0.0
	_geography_refresh_pending = true


func _update_camera_zoom() -> void:
	_zoom_target_distance = _zoom_distance
	_update_camera_position()
	_update_country_label_visibility()


func _update_camera_position() -> void:
	if not is_instance_valid(globe_camera):
		return
	globe_camera.position = Vector3(0.0, 0.0, _zoom_distance)
	globe_camera.look_at(Vector3.ZERO, Vector3.UP)


func _refresh_geography_for_zoom() -> void:
	var desired_country_path := _resolve_country_data_path()
	var desired_tier := "110m"
	if desired_country_path == COUNTRY_DATA_50M_PATH:
		desired_tier = "50m"
	elif desired_country_path == COUNTRY_DATA_10M_PATH:
		desired_tier = "10m"
	if _zoom_distance <= COUNTRY_BOUNDARY_ZOOM_THRESHOLD:
		if not _country_geography_loaded or _country_geography_tier != desired_tier:
			_build_country_geography()

func _read_geography_data(path: String, compressed: bool = false) -> Variant:
	_debug_load_stage = "Opening " + path.get_file()
	_debug_dataset_path = path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_debug_last_error = "Open failed (FileAccess error " + str(FileAccess.get_open_error()) + ")"
		push_warning("Geographic data could not be opened: " + path)
		return null

	_debug_asset_bytes = file.get_length()
	var source_bytes := file.get_buffer(file.get_length())
	var is_gzip := compressed or (
		source_bytes.size() >= 2
		and source_bytes[0] == 0x1f
		and source_bytes[1] == 0x8b
	)
	_debug_parse_format = "GZIP" if is_gzip else "Plain JSON"
	if is_gzip:
		_debug_load_stage = "Decompressing " + path.get_file()
		var decompressed_bytes := source_bytes.decompress_dynamic(128 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
		if decompressed_bytes.is_empty():
			_debug_last_error = "GZIP decompression returned 0 bytes"
			push_warning("Compressed geographic data could not be decompressed: " + path)
			return null
		source_bytes = decompressed_bytes

	_debug_load_stage = "Parsing " + path.get_file()
	var source_text := source_bytes.get_string_from_utf8()
	var parser := JSON.new()
	var parse_error := parser.parse(source_text)
	if parse_error != OK:
		_debug_last_error = "JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		push_warning("Geographic JSON parse failed: " + path + " - " + _debug_last_error)
		return null
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not parsed.has("features") or not parsed["features"] is Array:
		_debug_last_error = "JSON parsed, but root.features is missing or not an Array"
		push_warning("Geographic data is malformed: " + path)
		return null
	_debug_parsed_features = parsed["features"].size()
	_debug_last_error = "None"
	return parsed


func _resolve_country_data_path() -> String:
	# Admin-0 country outlines do not need 1:10m geometry. The global 10m
	# dataset is expensive to turn into one ImmediateMesh on mobile and can
	# keep the entire layer invisible until hundreds of thousands of vertices
	# have been emitted. Keep country borders at 1:50m; 1:10m is reserved for
	# the selected Admin-1 state/province chunk at close zoom.
	if FileAccess.file_exists(COUNTRY_DATA_50M_PATH):
		return COUNTRY_DATA_50M_PATH
	return COUNTRY_DATA_PATH


func _build_country_geography() -> void:
	if _country_building:
		return
	_country_building = true
	_debug_load_stage = "Selecting country dataset"
	_debug_last_error = "None"
	var requested_data_path := _resolve_country_data_path()
	var candidate_paths: Array[String] = []
	if requested_data_path == COUNTRY_DATA_10M_PATH:
		candidate_paths = [COUNTRY_DATA_10M_PATH, COUNTRY_DATA_50M_PATH, COUNTRY_DATA_PATH]
	elif requested_data_path == COUNTRY_DATA_50M_PATH:
		candidate_paths = [COUNTRY_DATA_50M_PATH, COUNTRY_DATA_PATH]
	else:
		candidate_paths = [COUNTRY_DATA_PATH]

	# Never let a missing/corrupt country asset blank the globe.
	# Prefer the mobile-friendly 50m Admin-0 set, then fall back to 110m.
	var parsed: Variant = null
	var data_path := ""
	for candidate_path in candidate_paths:
		if not FileAccess.file_exists(candidate_path):
			_debug_last_error = "Missing asset: " + candidate_path.get_file()
			push_warning("Globe geography asset is missing: " + candidate_path)
			continue
		var candidate_data: Variant = _read_geography_data(candidate_path)
		if candidate_data is Dictionary and candidate_data.get("features", []) is Array and not candidate_data["features"].is_empty():
			parsed = candidate_data
			data_path = candidate_path
			break
		push_warning("Globe geography asset has no usable features: " + candidate_path)

	if parsed == null:
		_debug_load_stage = "COUNTRY LOAD FAILED"
		if _debug_last_error == "None":
			_debug_last_error = "No dataset candidate contained usable features"
		push_warning("No usable country geography dataset could be loaded; tried: " + str(candidate_paths))
		_country_building = false
		return

	var tier := "110m"
	if data_path == COUNTRY_DATA_50M_PATH:
		tier = "50m"
	elif data_path == COUNTRY_DATA_10M_PATH:
		tier = "10m"
	if _country_geography_loaded and _country_geography_tier == tier:
		_country_building = false
		return
	_country_feature_data.clear()	if is_instance_valid(country_boundaries):
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
	border_material.albedo_color = Color(0.60, 0.67, 0.76, 0.84)
	border_material.roughness = 1.0
	border_material.metallic = 0.0
	border_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_material.no_depth_test = false
	border_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_debug_load_stage = "Building country boundary mesh (" + tier + ")"
	_debug_dataset_path = data_path
	country_boundaries = null
	var feature_count := 0
	var segment_count := 0
	var chunk_segment_count := 0
	var chunk_mesh := ImmediateMesh.new()
	chunk_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, border_material)
	# Publish small mesh chunks progressively instead of holding the entire
	# 50m dataset in one ImmediateMesh until the very end.
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
				_append_geographic_segment(
					chunk_mesh,
					float(point_a[1]),
					float(point_a[0]),
					float(point_b[1]),
					float(point_b[0]),
					EARTH_RADIUS * 1.0007
				)
				segment_count += 1
				chunk_segment_count += 1
				if segment_count % 1500 == 0:
					_debug_rendered_segments = segment_count
					_debug_load_stage = "Building country mesh (%s): %d segments" % [tier, segment_count]
					await get_tree().process_frame
					if not is_inside_tree() or _resolve_country_data_path() != requested_data_path:
						chunk_mesh.surface_end()
						if is_instance_valid(country_boundaries):
							country_boundaries.queue_free()
							country_boundaries = null
						_country_building = false
						return
				if chunk_segment_count >= 6000:
					chunk_mesh.surface_end()
					_attach_country_mesh_chunk(chunk_mesh)
					chunk_mesh = ImmediateMesh.new()
					chunk_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, border_material)
					chunk_segment_count = 0
	if chunk_segment_count > 0:
		chunk_mesh.surface_end()
		_attach_country_mesh_chunk(chunk_mesh)
	else:
		chunk_mesh.surface_end()
	if is_instance_valid(country_boundaries):
		country_boundaries.visible = _zoom_distance <= COUNTRY_BOUNDARY_ZOOM_THRESHOLD
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

	_country_geography_loaded = feature_count > 0 and segment_count > 0
	_debug_parsed_features = feature_count
	_debug_rendered_segments = segment_count
	_debug_country_labels = country_labels.size()
	_debug_load_stage = "COUNTRIES READY" if _country_geography_loaded else "COUNTRY GEOMETRY EMPTY"
	if segment_count == 0:
		_debug_last_error = "Features parsed, but 0 boundary segments were generated. Check feature.r coordinate schema."
	_country_geography_tier = tier
	_country_building = false
	# Labels are created asynchronously too; apply the settled zoom tier now.
	_update_country_label_visibility()
	if feature_count == 0:
		push_warning("Natural Earth country data contained no country features.")


func _geographic_edge_key(latitude_a: float, longitude_a: float, latitude_b: float, longitude_b: float) -> String:
	var point_a := "%.3f,%.3f" % [latitude_a, longitude_a]
	var point_b := "%.3f,%.3f" % [latitude_b, longitude_b]
	if point_a < point_b:
		return point_a + "|" + point_b
	return point_b + "|" + point_a


func _attach_country_mesh_chunk(chunk_mesh: ImmediateMesh) -> void:
	if chunk_mesh == null or chunk_mesh.get_surface_count() == 0:
		return
	var chunk_instance := MeshInstance3D.new()
	chunk_instance.mesh = chunk_mesh
	chunk_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if not is_instance_valid(country_boundaries):
		chunk_instance.name = "Country_Boundaries"
		country_boundaries = chunk_instance
		country_boundaries.visible = _zoom_distance <= COUNTRY_BOUNDARY_ZOOM_THRESHOLD
		earth_pivot.add_child(country_boundaries)
	else:
		chunk_instance.name = "Country_Boundary_Chunk"
		country_boundaries.add_child(chunk_instance)


func _append_geographic_segment(
	mesh: ImmediateMesh,
	latitude_a: float,
	longitude_a: float,
	latitude_b: float,
	longitude_b: float,
	radius: float
) -> void:
	# Render boundaries as narrow, shaded surface ribbons rather than GPU
	# one-pixel line primitives. One-pixel lines become almost invisible on
	# dense phone displays; ribbons retain a restrained cartographic edge.
	var direction_a := _geo_to_globe_position(latitude_a, longitude_a, 1.0).normalized()
	var direction_b := _geo_to_globe_position(latitude_b, longitude_b, 1.0).normalized()
	var tangent := direction_b - direction_a
	if tangent.length_squared() < 0.0000001:
		return
	tangent = tangent.normalized()
	var half_width := 0.0035 if radius < EARTH_RADIUS * 1.0008 else 0.0026
	var side_a := tangent.cross(direction_a).normalized() * half_width
	var side_b := tangent.cross(direction_b).normalized() * half_width
	var a_left := direction_a * radius + side_a
	var a_right := direction_a * radius - side_a
	var b_left := direction_b * radius + side_b
	var b_right := direction_b * radius - side_b

	# Two outward-facing triangles form a thin ribbon following the sphere.
	mesh.surface_set_normal(direction_a)
	mesh.surface_add_vertex(a_left)
	mesh.surface_set_normal(direction_a)
	mesh.surface_add_vertex(a_right)
	mesh.surface_set_normal(direction_b)
	mesh.surface_add_vertex(b_left)
	mesh.surface_set_normal(direction_b)
	mesh.surface_add_vertex(b_left)
	mesh.surface_set_normal(direction_a)
	mesh.surface_add_vertex(a_right)
	mesh.surface_set_normal(direction_b)
	mesh.surface_add_vertex(b_right)


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



func get_zoom_distance() -> float:
	return _zoom_distance


func _update_debug_panel() -> void:
	if not is_instance_valid(_debug_panel_label):
		return
	var country_visible := is_instance_valid(country_boundaries) and country_boundaries.visible
	var country_mesh_surfaces := 0
	if is_instance_valid(country_boundaries) and country_boundaries.mesh != null:
		country_mesh_surfaces = country_boundaries.mesh.get_surface_count()
	_debug_panel_label.text = (
		"GLOBE / GEOGRAPHY DIAGNOSTICS\n"
		+ "Stage: " + _debug_load_stage + "\n"
		+ "Zoom: %.2f (target %.2f)\n" % [_zoom_distance, _zoom_target_distance]
		+ "Country busy/loaded: %s / %s\n" % [str(_country_building), str(_country_geography_loaded)]
		+ "Dataset: " + _debug_dataset_path.get_file() + " [" + _debug_parse_format + "]\n"
		+ "File bytes: " + str(_debug_asset_bytes) + "\n"
		+ "Features: " + str(_debug_parsed_features) + " | Segments: " + str(_debug_rendered_segments) + "\n"
		+ "Labels: " + str(_debug_country_labels) + " | Mesh surfaces: " + str(country_mesh_surfaces) + "\n"
		+ "Country visible: " + str(country_visible) + "\n"
		+ "Last error: " + _debug_last_error
	)
