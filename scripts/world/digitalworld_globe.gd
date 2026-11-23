extends Node3D

signal back_requested

const EARTH_TEXTURE: Texture2D = preload("res://assets/globe/earth_blue_marble.jpg")
const CLOUD_TEXTURE: Texture2D = preload("res://assets/globe/earth_clouds.jpg")
const COUNTRY_DATA_PATH := "res://assets/globe/natural_earth_countries.json"
const COUNTRY_DATA_50M_PATH := "res://assets/globe/natural_earth_countries_50m.json"
const COUNTRY_DATA_10M_PATH := "res://assets/globe/natural_earth_countries_10m.json"
const EARTH_RADIUS := 1.6
const DRAG_SENSITIVITY := 0.00075
const ROTATION_SMOOTHING := 12.0
const ROTATION_POINTER_SMOOTHING := 36.0
const ROTATION_MAX_POINTER_STEP := 28.0
const TRACKBALL_RADIUS_FACTOR := 0.72
const ZOOM_SMOOTHING := 4.2
const PINCH_ZOOM_SENSITIVITY := 0.0035
const ZOOM_MIN := 1.9
const ZOOM_MAX := 7.2
const COUNTRY_BOUNDARY_ZOOM_THRESHOLD := 5.1
const COUNTRY_LABEL_ZOOM_THRESHOLDS := [4.5, 3.8, 3.0]
const COUNTRY_TAP_DRAG_THRESHOLD := 12.0
const STATE_DATA_PATH_FORMAT := "res://assets/globe/natural_earth_states_10m_%s.json"
const STATE_DATA_CONTINENTS := ["africa", "antarctica", "asia", "europe", "north_america", "oceania", "south_america", "other"]

var earth_pivot: Node3D
var globe_camera: Camera3D
var _zoom_distance := 4.9
var _zoom_target_distance := 4.9
var _zoom_settle_elapsed := 0.0
var _geography_refresh_pending := false
var _touch_points: Dictionary = {}
var _touch_start_positions: Dictionary = {}
var _touch_tap_eligible: Dictionary = {}
var _previous_pinch_distance := 0.0
var _mouse_dragging := false
var _mouse_press_position := Vector2.ZERO
var _mouse_tap_eligible := false
var _rotation_drag_active := false
var _rotation_pointer_position := Vector2.ZERO
var _rotation_pointer_target := Vector2.ZERO
var _rotation_current := Quaternion.IDENTITY
var _rotation_target := Quaternion.IDENTITY
var cloud_layer: MeshInstance3D
var country_boundaries: MeshInstance3D
var country_labels: Array[Label3D] = []
var _country_features: Array = []
var _country_geography_loaded := false
var _country_subdivision_overlay: CanvasLayer
var _country_subdivision_list: GridContainer
var _country_subdivision_search: LineEdit
var _country_subdivision_count_label: Label
var _selected_subdivision_entries: Array[Dictionary] = []
var _selected_country_name := ""
var _subdivision_request_id := 0
var _country_geography_tier := ""
var _country_building := false

var _debug_load_stage := "Waiting for globe startup"
var _debug_last_error := "None"
var _debug_dataset_path := "Not selected"
var _debug_asset_bytes := 0
var _debug_parsed_features := 0
var _debug_rendered_segments := 0
var _debug_country_labels := 0
var _debug_parse_format := "Unknown"


func _ready() -> void:
	_build_environment()
	_build_starfield()
	_build_earth()
	_rotation_current = earth_pivot.quaternion
	_rotation_target = _rotation_current
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

func _process(delta: float) -> void:
	# Earth, country geometry, labels and cloud shell share one quaternion
	# orientation. This prevents independent layer drift and Euler-axis locking.
	if is_instance_valid(earth_pivot):
		_update_drag_rotation(delta)
		var rotation_blend := 1.0 - exp(-delta * ROTATION_SMOOTHING)
		_rotation_current = _rotation_current.slerp(_rotation_target, rotation_blend).normalized()
		earth_pivot.quaternion = _rotation_current


	# Ease the camera toward the pinch-selected distance. This is a damped,
	# finite settle (not inertia): once the target is reached, zoom stops.
	if is_instance_valid(globe_camera) and not is_equal_approx(_zoom_distance, _zoom_target_distance):
		var zoom_blend := 1.0 - exp(-delta * ZOOM_SMOOTHING)
		_zoom_distance = lerpf(_zoom_distance, _zoom_target_distance, zoom_blend)
		if absf(_zoom_target_distance - _zoom_distance) < 0.001:
			_zoom_distance = _zoom_target_distance
		_update_camera_position()
		_update_country_label_visibility()

	# Wait until pinch input settles before parsing data or constructing meshes.
	if _geography_refresh_pending:
		_zoom_settle_elapsed += delta
		if _zoom_settle_elapsed >= 0.28 and is_equal_approx(_zoom_distance, _zoom_target_distance):
			_geography_refresh_pending = false
			_zoom_settle_elapsed = 0.0
			_refresh_geography_for_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_country_subdivision_overlay):
		if event.is_action_pressed("ui_cancel"):
			_close_country_subdivision_overlay()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
			_touch_start_positions[touch.index] = touch.position
			_touch_tap_eligible[touch.index] = true
			if _touch_points.size() == 1:
				_rotation_pointer_position = touch.position
				_rotation_pointer_target = touch.position
				_rotation_drag_active = true
			elif _touch_points.size() == 2:
				_rotation_drag_active = false
				_previous_pinch_distance = _get_pinch_distance()
			if _touch_points.size() >= 2:
				for pointer_key in _touch_tap_eligible.keys():
					_touch_tap_eligible[pointer_key] = false
		else:
			var can_select_country: bool = (
				_touch_points.size() == 1
				and bool(_touch_tap_eligible.get(touch.index, false))
				and _touch_start_positions.get(touch.index, touch.position).distance_to(touch.position) <= COUNTRY_TAP_DRAG_THRESHOLD
			)
			if can_select_country:
				_select_country_at_screen_position(touch.position)
			_touch_points.erase(touch.index)
			_touch_start_positions.erase(touch.index)
			_touch_tap_eligible.erase(touch.index)
			_previous_pinch_distance = 0.0
			if _touch_points.size() == 1:
				var remaining_key = _touch_points.keys()[0]
				_rotation_pointer_position = _touch_points[remaining_key]
				_rotation_pointer_target = _rotation_pointer_position
				_rotation_drag_active = true
			else:
				_rotation_drag_active = false
				_rotation_pointer_target = _rotation_pointer_position
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touch_points.has(drag.index):
			_touch_points[drag.index] = drag.position
			var touch_start: Vector2 = _touch_start_positions.get(drag.index, drag.position)
			if touch_start.distance_to(drag.position) > COUNTRY_TAP_DRAG_THRESHOLD:
				_touch_tap_eligible[drag.index] = false
		if _touch_points.size() >= 2:
			var pinch_distance := _get_pinch_distance()
			if _previous_pinch_distance > 0.0:
				zoom_globe((_previous_pinch_distance - pinch_distance) * PINCH_ZOOM_SENSITIVITY)
			_previous_pinch_distance = pinch_distance
		elif _rotation_drag_active:
			_rotation_pointer_target = drag.position
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_mouse_dragging = true
				_mouse_press_position = mouse_button.position
				_mouse_tap_eligible = true
				_rotation_pointer_position = mouse_button.position
				_rotation_pointer_target = mouse_button.position
				_rotation_drag_active = true
			else:
				var is_country_tap := (
					_mouse_dragging
					and _mouse_tap_eligible
					and _mouse_press_position.distance_to(mouse_button.position) <= COUNTRY_TAP_DRAG_THRESHOLD
				)
				_mouse_dragging = false
				_mouse_tap_eligible = false
				_rotation_drag_active = false
				_rotation_pointer_target = _rotation_pointer_position
				if is_country_tap:
					_select_country_at_screen_position(mouse_button.position)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_globe(-0.12)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_globe(0.12)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_dragging:
		var mouse_motion := event as InputEventMouseMotion
		if _mouse_press_position.distance_to(mouse_motion.position) > COUNTRY_TAP_DRAG_THRESHOLD:
			_mouse_tap_eligible = false
		_rotation_pointer_target = mouse_motion.position
		get_viewport().set_input_as_handled()


func _select_country_at_screen_position(screen_position: Vector2) -> void:
	if not _country_geography_loaded or _country_features.is_empty():
		return
	if is_instance_valid(_country_subdivision_overlay):
		return
	var coordinates := _screen_to_globe_coordinates(screen_position)
	if coordinates.x < -90.0 or coordinates.x > 90.0 or coordinates.y < -180.0 or coordinates.y > 180.0:
		return
	var country := _find_country_feature_at(coordinates.x, coordinates.y)
	if not country.is_empty():
		call_deferred("_open_country_subdivision_overlay", country)


func _screen_to_globe_coordinates(screen_position: Vector2) -> Vector2:
	# Convert the pointer ray into a surface coordinate. The first sphere hit
	# is always the visible hemisphere, so taps on the far side cannot select
	# a country hidden behind the Earth.
	if not is_instance_valid(globe_camera) or not is_instance_valid(earth_pivot):
		return Vector2(999.0, 999.0)
	var ray_origin := globe_camera.project_ray_origin(screen_position)
	var ray_direction := globe_camera.project_ray_normal(screen_position).normalized()
	var relative_origin := ray_origin - earth_pivot.global_position
	var projection := relative_origin.dot(ray_direction)
	var constant := relative_origin.length_squared() - EARTH_RADIUS * EARTH_RADIUS
	var discriminant := projection * projection - constant
	if discriminant < 0.0:
		return Vector2(999.0, 999.0)
	var hit_distance := -projection - sqrt(discriminant)
	if hit_distance < 0.0:
		hit_distance = -projection + sqrt(discriminant)
	if hit_distance < 0.0:
		return Vector2(999.0, 999.0)
	var local_hit := earth_pivot.to_local(ray_origin + ray_direction * hit_distance).normalized()
	var latitude := rad_to_deg(asin(clampf(local_hit.y, -1.0, 1.0)))
	var longitude := wrapf(rad_to_deg(atan2(local_hit.x, local_hit.z)) - 180.0, -180.0, 180.0)
	return Vector2(latitude, longitude)


func _find_country_feature_at(latitude: float, longitude: float) -> Dictionary:
	for feature_variant in _country_features:
		if not feature_variant is Dictionary:
			continue
		var feature: Dictionary = feature_variant
		if _point_is_inside_country_feature(latitude, longitude, feature):
			return feature
	return {}


func _point_is_inside_country_feature(latitude: float, longitude: float, feature: Dictionary) -> bool:
	var inside := false
	for ring_variant in feature.get("r", []):
		if ring_variant is Array and _point_is_inside_geographic_ring(latitude, longitude, ring_variant):
			# Natural Earth stores outer rings and holes as separate parts.
			# Even-odd parity preserves islands and excludes interior lakes.
			inside = not inside
	return inside


func _point_is_inside_geographic_ring(latitude: float, longitude: float, ring: Array) -> bool:
	if ring.size() < 3:
		return false
	var inside := false
	var previous: Array = ring[ring.size() - 1]
	for current_variant in ring:
		if not current_variant is Array:
			previous = current_variant if current_variant is Array else previous
			continue
		var current: Array = current_variant
		if previous.size() >= 2 and current.size() >= 2:
			var longitude_a := _longitude_near(float(previous[0]), longitude)
			var longitude_b := _longitude_near(float(current[0]), longitude)
			var latitude_a := float(previous[1])
			var latitude_b := float(current[1])
			if (latitude_a > latitude) != (latitude_b > latitude):
				var crossing_longitude := longitude_a + (
					(longitude_b - longitude_a) * (latitude - latitude_a) / (latitude_b - latitude_a)
				)
				if longitude < crossing_longitude:
					inside = not inside
		previous = current
	return inside


func _longitude_near(value: float, reference: float) -> float:
	var adjusted := value
	while adjusted - reference > 180.0:
		adjusted -= 360.0
	while adjusted - reference < -180.0:
		adjusted += 360.0
	return adjusted


func _normalise_country_match_name(value: String) -> String:
	return value.strip_edges().to_lower().replace(".", "").replace(",", "").replace(" ", "")


func _open_country_subdivision_overlay(country: Dictionary) -> void:
	_subdivision_request_id += 1
	var request_id := _subdivision_request_id
	_selected_country_name = str(country.get("n", "Unknown"))
	_selected_subdivision_entries.clear()
	_build_country_subdivision_overlay(_selected_country_name)
	_set_country_subdivision_message("Loading state and province records…")
	await get_tree().process_frame
	if request_id != _subdivision_request_id or not is_instance_valid(_country_subdivision_overlay):
		return

	var continent_key := str(country.get("continent", "other")).strip_edges().to_lower().replace(" ", "_")
	if not STATE_DATA_CONTINENTS.has(continent_key):
		continent_key = "other"
	var state_data_path := STATE_DATA_PATH_FORMAT % continent_key
	var parsed_states: Variant = _read_geography_data(state_data_path)
	if request_id != _subdivision_request_id or not is_instance_valid(_country_subdivision_overlay):
		return
	if not parsed_states is Dictionary:
		_set_country_subdivision_message("State and province records could not be loaded for this country.")
		_update_country_subdivision_count(0)
		return

	var country_code := str(country.get("c", "")).strip_edges()
	var country_match_name := _normalise_country_match_name(_selected_country_name)
	var matching_entries: Array[Dictionary] = []
	var seen_names: Dictionary = {}
	for state_variant in parsed_states.get("features", []):
		if not state_variant is Dictionary:
			continue
		var state: Dictionary = state_variant
		var state_code := str(state.get("c", "")).strip_edges()
		if country_code.is_empty() or state_code != country_code:
			continue
		_append_country_subdivision_entry(state, matching_entries, seen_names)

	# Admin-0 name is a conservative fallback for a small number of Natural
	# Earth records whose disputed-territory codes do not line up across scales.
	if matching_entries.is_empty():
		for state_variant in parsed_states.get("features", []):
			if not state_variant is Dictionary:
				continue
			var state: Dictionary = state_variant
			if _normalise_country_match_name(str(state.get("a", ""))) == country_match_name:
				_append_country_subdivision_entry(state, matching_entries, seen_names)

	matching_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("n", "")).to_lower() < str(b.get("n", "")).to_lower()
	)
	_selected_subdivision_entries = matching_entries
	_update_country_subdivision_count(matching_entries.size())
	if matching_entries.is_empty():
		_set_country_subdivision_message("No state or province records are available for %s." % _selected_country_name)
	else:
		_filter_country_subdivision_list("")


func _append_country_subdivision_entry(state: Dictionary, entries: Array[Dictionary], seen_names: Dictionary) -> void:
	var subdivision_name := str(state.get("n", "")).strip_edges()
	if subdivision_name.is_empty() or subdivision_name == "Unknown":
		return
	var key := subdivision_name.to_lower()
	if seen_names.has(key):
		return
	seen_names[key] = true
	entries.append({"n": subdivision_name})


func _build_country_subdivision_overlay(country_name: String) -> void:
	if is_instance_valid(_country_subdivision_overlay):
		_country_subdivision_overlay.queue_free()
	_country_subdivision_overlay = CanvasLayer.new()
	_country_subdivision_overlay.name = "Country_Subdivision_Overlay"
	_country_subdivision_overlay.layer = 60
	add_child(_country_subdivision_overlay)

	var viewport_size := get_viewport().get_visible_rect().size
	var narrow := viewport_size.x < viewport_size.y * 1.25
	var ui_scale := clampf(minf(viewport_size.x / 1152.0, viewport_size.y / 648.0), 0.68, 1.0)

	# This is a full research-style page, not a dialog over the globe. The page
	# occupies the complete viewport and has its own navigation back to Earth.
	var page_background := ColorRect.new()
	page_background.name = "Country_Subdivision_Page_Background"
	page_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_background.color = Color("#101315")
	page_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_country_subdivision_overlay.add_child(page_background)

	var panel := PanelContainer.new()
	panel.name = "Country_Subdivision_Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#101315")
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", panel_style)
	_country_subdivision_overlay.add_child(panel)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", roundi((18.0 if narrow else 42.0) * ui_scale))
	inner_margin.add_theme_constant_override("margin_right", roundi((18.0 if narrow else 42.0) * ui_scale))
	inner_margin.add_theme_constant_override("margin_top", roundi((18.0 if narrow else 28.0) * ui_scale))
	inner_margin.add_theme_constant_override("margin_bottom", roundi((16.0 if narrow else 24.0) * ui_scale))
	panel.add_child(inner_margin)

	var content := VBoxContainer.new()
	content.name = "Country_Subdivision_Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", roundi(10.0 * ui_scale))
	inner_margin.add_child(content)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var eyebrow := Label.new()
	eyebrow.text = "WORLD REGION DIRECTORY"
	eyebrow.add_theme_font_size_override("font_size", maxi(10, roundi(12.0 * ui_scale)))
	eyebrow.add_theme_color_override("font_color", Color("#C58A3A"))
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(eyebrow)

	var close_button := Button.new()
	close_button.name = "Country_Subdivision_Close_Button"
	close_button.text = "←  BACK TO WORLD"
	close_button.custom_minimum_size = Vector2(roundi(156.0 * ui_scale), roundi(42.0 * ui_scale))
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", maxi(10, roundi(12.0 * ui_scale)))
	close_button.add_theme_color_override("font_color", Color("#EEE9DF"))
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color("#202326")
	close_style.border_color = Color("#72552F")
	close_style.set_border_width_all(1)
	close_style.set_corner_radius_all(7)
	close_style.content_margin_left = 10
	close_style.content_margin_right = 10
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_style)
	close_button.pressed.connect(_close_country_subdivision_overlay)
	header.add_child(close_button)

	var title := Label.new()
	title.name = "Country_Subdivision_Country_Name"
	title.text = country_name.to_upper()
	title.add_theme_font_size_override("font_size", maxi(20, roundi(30.0 * ui_scale)))
	title.add_theme_color_override("font_color", Color("#EEE9DF"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)

	var section := Label.new()
	section.text = "STATES & PROVINCES"
	section.add_theme_font_size_override("font_size", maxi(11, roundi(14.0 * ui_scale)))
	section.add_theme_color_override("font_color", Color("#C58A3A"))
	content.add_child(section)

	_country_subdivision_count_label = Label.new()
	_country_subdivision_count_label.name = "Country_Subdivision_Count"
	_country_subdivision_count_label.text = "LOADING DIRECTORY"
	_country_subdivision_count_label.add_theme_font_size_override("font_size", maxi(10, roundi(11.0 * ui_scale)))
	_country_subdivision_count_label.add_theme_color_override("font_color", Color("#AAA49A"))
	content.add_child(_country_subdivision_count_label)

	_country_subdivision_search = LineEdit.new()
	_country_subdivision_search.name = "Country_Subdivision_Search"
	_country_subdivision_search.placeholder_text = "Search states or provinces"
	_country_subdivision_search.clear_button_enabled = true
	_country_subdivision_search.custom_minimum_size.y = roundi(42.0 * ui_scale)
	_country_subdivision_search.add_theme_font_size_override("font_size", maxi(12, roundi(14.0 * ui_scale)))
	_country_subdivision_search.add_theme_color_override("font_color", Color("#EEE9DF"))
	_country_subdivision_search.add_theme_color_override("font_placeholder_color", Color("#AAA49A"))
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color("#202326")
	search_style.border_color = Color("#514B40")
	search_style.set_border_width_all(1)
	search_style.set_corner_radius_all(7)
	search_style.content_margin_left = 12
	search_style.content_margin_right = 12
	_country_subdivision_search.add_theme_stylebox_override("normal", search_style)
	_country_subdivision_search.add_theme_stylebox_override("focus", search_style)
	_country_subdivision_search.text_changed.connect(_filter_country_subdivision_list)
	content.add_child(_country_subdivision_search)

	var scroll := ScrollContainer.new()
	scroll.name = "Country_Subdivision_Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	content.add_child(scroll)

	_country_subdivision_list = GridContainer.new()
	_country_subdivision_list.name = "Country_Subdivision_List"
	_country_subdivision_list.columns = 5
	_country_subdivision_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_country_subdivision_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_country_subdivision_list.add_theme_constant_override("h_separation", roundi(10.0 * ui_scale))
	_country_subdivision_list.add_theme_constant_override("v_separation", roundi(8.0 * ui_scale))
	scroll.add_child(_country_subdivision_list)

func _filter_country_subdivision_list(query: String) -> void:
	if not is_instance_valid(_country_subdivision_list):
		return
	for child in _country_subdivision_list.get_children():
		_country_subdivision_list.remove_child(child)
		child.queue_free()
	var normalized_query := query.strip_edges().to_lower()
	var visible_index := 0
	for entry in _selected_subdivision_entries:
		var subdivision_name := str(entry.get("n", ""))
		if not normalized_query.is_empty() and not subdivision_name.to_lower().contains(normalized_query):
			continue
		visible_index += 1
		_add_country_subdivision_card(subdivision_name, visible_index)
	if visible_index == 0:
		var empty_label := Label.new()
		empty_label.text = "No matching states or provinces." if not _selected_subdivision_entries.is_empty() else "No subdivision records to display."
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color("#AAA49A"))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size.y = 58.0
		_country_subdivision_list.add_child(empty_label)


func _add_country_subdivision_card(subdivision_name: String, index: int) -> void:
	var card := PanelContainer.new()
	card.name = "Country_Subdivision_Card_%03d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 58.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#1B1E20")
	card_style.border_color = Color("#514936")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.content_margin_left = 11
	card_style.content_margin_right = 11
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	_country_subdivision_list.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)

	var number_label := Label.new()
	number_label.text = "%02d" % index
	number_label.custom_minimum_size.x = 24.0
	number_label.add_theme_font_size_override("font_size", 12)
	number_label.add_theme_color_override("font_color", Color("#C58A3A"))
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number_label)

	var name_label := Label.new()
	name_label.text = subdivision_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color("#EEE9DF"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)


func _set_country_subdivision_message(message: String) -> void:
	if not is_instance_valid(_country_subdivision_list):
		return
	for child in _country_subdivision_list.get_children():
		_country_subdivision_list.remove_child(child)
		child.queue_free()
	var message_label := Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 13)
	message_label.add_theme_color_override("font_color", Color("#AAA49A"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.y = 66.0
	_country_subdivision_list.add_child(message_label)


func _update_country_subdivision_count(count: int) -> void:
	if not is_instance_valid(_country_subdivision_count_label):
		return
	var noun := "STATE / PROVINCE" if count == 1 else "STATES / PROVINCES"
	_country_subdivision_count_label.text = "%d %s" % [count, noun]


func _on_country_subdivision_backdrop_input(event: InputEvent) -> void:
	var close_requested := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_requested = true
	elif event is InputEventScreenTouch and event.pressed:
		close_requested = true
	if close_requested:
		_close_country_subdivision_overlay()


func _close_country_subdivision_overlay() -> void:
	_subdivision_request_id += 1
	if is_instance_valid(_country_subdivision_overlay):
		_country_subdivision_overlay.queue_free()
	_country_subdivision_overlay = null
	_country_subdivision_list = null
	_country_subdivision_search = null
	_country_subdivision_count_label = null
	_selected_subdivision_entries.clear()
	_selected_country_name = ""



func _get_pinch_distance() -> float:
	if _touch_points.size() < 2:
		return 0.0
	var keys := _touch_points.keys()
	var first_position: Vector2 = _touch_points[keys[0]]
	var second_position: Vector2 = _touch_points[keys[1]]
	return first_position.distance_to(second_position)


func _update_drag_rotation(delta: float) -> void:
	# Touch events do not arrive at perfectly even intervals on every Android
	# device. Filter the pointer path at render cadence so one delayed event
	# cannot become a visible rotational jump.
	if not _rotation_drag_active:
		return
	var remaining := _rotation_pointer_target - _rotation_pointer_position
	if remaining.length_squared() < 0.0001:
		return
	var blend := 1.0 - exp(-maxf(delta, 0.0) * ROTATION_POINTER_SMOOTHING)
	var pointer_step := remaining * blend
	if pointer_step.length() > ROTATION_MAX_POINTER_STEP:
		pointer_step = pointer_step.normalized() * ROTATION_MAX_POINTER_STEP
	var next_position := _rotation_pointer_position + pointer_step
	_apply_trackball_rotation(_rotation_pointer_position, next_position)
	_rotation_pointer_position = next_position


func _trackball_vector(screen_position: Vector2) -> Vector3:
	var viewport_size := get_viewport().get_visible_rect().size
	var radius := maxf(1.0, minf(viewport_size.x, viewport_size.y) * TRACKBALL_RADIUS_FACTOR)
	var centered := screen_position - viewport_size * 0.5
	var x := centered.x / radius
	var y := -centered.y / radius
	var distance_squared := x * x + y * y
	var z := 0.0
	if distance_squared <= 0.5:
		z = sqrt(1.0 - distance_squared)
	else:
		z = 0.5 / sqrt(distance_squared)
	return Vector3(x, y, z).normalized()


func _apply_trackball_rotation(previous_position: Vector2, current_position: Vector2) -> void:
	if not is_instance_valid(earth_pivot) or not is_instance_valid(globe_camera):
		return
	if previous_position.distance_squared_to(current_position) < 0.0001:
		return
	var previous_vector := _trackball_vector(previous_position)
	var current_vector := _trackball_vector(current_position)
	var camera_rotation := Quaternion(previous_vector, current_vector)
	var camera_basis := globe_camera.global_basis.orthonormalized()
	var world_rotation := Quaternion(camera_basis) * camera_rotation * Quaternion(camera_basis.inverse())
	_rotation_target = (world_rotation * _rotation_target).normalized()


func _rotate_globe_from_points(previous_position: Vector2, current_position: Vector2) -> void:
	_apply_trackball_rotation(previous_position, current_position)


func rotate_globe(pointer_delta: Vector2) -> void:
	# Compatibility entry point for scripted controls and smoke tests. Real
	# pointer input uses the full position-based virtual trackball above.
	if not is_instance_valid(earth_pivot) or pointer_delta.length_squared() < 0.0001:
		return
	var zoom_factor := clampf(_zoom_distance / 4.9, 0.58, 1.0)
	var angle := pointer_delta.length() * DRAG_SENSITIVITY * zoom_factor
	var camera_axis := Vector3(pointer_delta.y, pointer_delta.x, 0.0).normalized()
	var camera_basis := globe_camera.global_basis.orthonormalized()
	var world_axis := (camera_basis * camera_axis).normalized()
	var world_rotation := Quaternion(world_axis, angle)
	_rotation_target = (world_rotation * _rotation_target).normalized()


func zoom_globe(distance_delta: float) -> void:
	# Accumulate finger movement into a bounded target, then ease toward it.
	# There is no momentum: the camera stops as soon as it reaches this target.
	_zoom_target_distance = clampf(_zoom_target_distance + distance_delta, ZOOM_MIN, ZOOM_MAX)
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
	_country_features = parsed["features"]
	if _country_geography_loaded and _country_geography_tier == tier:
		_country_building = false
		return
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
