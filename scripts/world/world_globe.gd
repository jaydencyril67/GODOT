extends Node3D

signal back_requested

const RADIUS := 1.0
const START_DISTANCE := 3.65
const MIN_DISTANCE := 1.08
const MAX_DISTANCE := START_DISTANCE
const COUNTRY_ZOOM_DISTANCE := 3.25
const PROVINCE_ZOOM_DISTANCE := 1.82
const DRAG_ROTATION_SENSITIVITY := 0.00159375
const WHEEL_ZOOM_STEP := 0.19635
const BUTTON_ZOOM_STEP := 0.2142
const PINCH_ZOOM_SENSITIVITY := 0.0044625
const MAGNIFY_ZOOM_SENSITIVITY := 0.6375
const GEOBOUNDARIES_ROOT := "https://www.geoboundaries.org/api/current/gbOpen"
const COUNTRY_BOUNDARIES_URL := "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
const NASA_WMS_ROOT := "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi"
const OVERVIEW_URL := NASA_WMS_ROOT + "?service=WMS&request=GetMap&version=1.1.1&layers=BlueMarble_ShadedRelief_Bathymetry&styles=default&format=image/jpeg&srs=EPSG:4326&bbox=-180,-90,180,90&width=4096&height=2048&time=default"
const CACHE_ROOT := "user://digitalworld/globe"

const CLOUD_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;
uniform sampler2D cloud_noise : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	vec2 drift = vec2(TIME * 0.00035, 0.0);
	float broad = texture(cloud_noise, UV * vec2(1.8, 1.0) + drift).r;
	float detail = texture(cloud_noise, UV * vec2(3.6, 2.0) - drift * 0.35).r;
	float density = broad * 0.84 + detail * 0.16;
	float cloud = smoothstep(0.56, 0.74, density);
	ALBEDO = vec3(0.91, 0.95, 1.0);
	ALPHA = cloud * 0.09;
}
"""

const ATMOSPHERE_SHADER := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.8);
	ALBEDO = vec3(0.12, 0.42, 0.92);
	ALPHA = rim * 0.28;
}
"""


var planet_root: Node3D
var earth_instance: MeshInstance3D
var earth_material: StandardMaterial3D
var cloud_shell: MeshInstance3D
var camera: Camera3D
var target_distance := START_DISTANCE
var dragging := false
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var country_features: Array = []
var country_boundaries_loaded := false
var country_boundaries_loading := false
var country_boundary_node: MeshInstance3D
var country_label_nodes: Array[Label3D] = []
var province_boundary_nodes: Array[MeshInstance3D] = []
var province_label_nodes: Array[Label3D] = []
var focused_country_iso := ""
var focused_country_name := ""
var region_request_generation := 0
var region_check_elapsed := 0.0
var status_label: Label
var overview_texture: Texture2D
var debug_toggle: Button
var debug_panel: PanelContainer
var debug_text: Label
var debug_copy_button: Button
var debug_messages: Array[String] = []
var debug_failure_count := 0
var country_cache_retry_used := false
var last_debug_country_state := ""


func _ready() -> void:
	_build_space_environment()
	_build_planet()
	_build_interface()
	_debug_event("Globe scene initialized; online assets are being checked.")
	_load_overview_map()
	_load_country_boundaries()
	set_process(true)


func _process(delta: float) -> void:
	if not dragging:
		camera.position.z = lerpf(camera.position.z, target_distance, minf(delta * 5.0, 1.0))
	camera.look_at(Vector3.ZERO, Vector3.UP)
	region_check_elapsed += delta
	if region_check_elapsed >= 0.28:
		region_check_elapsed = 0.0
		_update_administrative_layers()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(target_distance - WHEEL_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(target_distance + WHEEL_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		_drag_planet(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			dragging = true
			last_pinch_distance = _get_pinch_distance()
		else:
			touch_points.erase(event.index)
			dragging = not touch_points.is_empty()
			last_pinch_distance = _get_pinch_distance()
	elif event is InputEventScreenDrag:
		if touch_points.has(event.index):
			touch_points[event.index] = event.position
			if touch_points.size() >= 2:
				var next_distance := _get_pinch_distance()
				if last_pinch_distance > 0.0 and next_distance > 0.0:
					_set_zoom(target_distance + (last_pinch_distance - next_distance) * PINCH_ZOOM_SENSITIVITY)
				last_pinch_distance = next_distance
			else:
				_drag_planet(event.relative)
	elif event is InputEventMagnifyGesture:
		var adjusted_factor: float = 1.0 + (float(event.factor) - 1.0) * MAGNIFY_ZOOM_SENSITIVITY
		_set_zoom(target_distance / maxf(adjusted_factor, 0.1))


func _get_pinch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
	var touch_ids := touch_points.keys()
	var first_point: Vector2 = touch_points[touch_ids[0]]
	var second_point: Vector2 = touch_points[touch_ids[1]]
	return first_point.distance_to(second_point)


func _get_drag_rotation_sensitivity() -> float:
	var zoom_range := maxf(MAX_DISTANCE - MIN_DISTANCE, 0.001)
	var zoom_progress := clampf((target_distance - MIN_DISTANCE) / zoom_range, 0.0, 1.0)
	var sensitivity_progress := pow(zoom_progress, 1.25)
	return DRAG_ROTATION_SENSITIVITY * lerpf(0.28, 1.0, sensitivity_progress)


func _drag_planet(relative: Vector2) -> void:
	var sensitivity := _get_drag_rotation_sensitivity()
	planet_root.rotate_y(relative.x * sensitivity)
	planet_root.rotate_x(relative.y * sensitivity)
	planet_root.rotation.x = clampf(planet_root.rotation.x, -1.48, 1.48)


func _set_zoom(distance: float) -> void:
	target_distance = clampf(distance, MIN_DISTANCE, MAX_DISTANCE)
	# Apply zoom immediately so touch-pinch movement is reflected while fingers are still moving.
	if is_instance_valid(camera):
		camera.position.z = target_distance
	if is_instance_valid(country_boundary_node):
		country_boundary_node.visible = _is_country_zoom_active()
	var show_provinces := _is_province_zoom_active()
	for node in province_boundary_nodes:
		if is_instance_valid(node):
			node.visible = show_provinces
	for label in province_label_nodes:
		if is_instance_valid(label):
			label.visible = show_provinces
	_refresh_globe_label_visibility()
	_refresh_debug_panel()


func _build_space_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#030711")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8292A8")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	camera = Camera3D.new()
	camera.name = "GlobeCamera"
	camera.position = Vector3(0.0, 0.0, START_DISTANCE)
	camera.fov = 39.0
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	camera.current = true

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "SolarKeyLight"
	sunlight.rotation_degrees = Vector3(-24.0, -34.0, 0.0)
	sunlight.light_color = Color("#FFF2D6")
	sunlight.light_energy = 1.55
	sunlight.shadow_enabled = false
	add_child(sunlight)



func _add_starfield() -> void:
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.006
	star_mesh.height = 0.012
	star_mesh.radial_segments = 5
	star_mesh.rings = 3
	var star_material := StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.albedo_color = Color("#B9CBE8")
	star_mesh.material = star_material

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = star_mesh
	multi.instance_count = 260
	for index in range(multi.instance_count):
		var direction := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()
		var star_scale := randf_range(0.45, 1.45)
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * star_scale), direction * 17.0))
	var stars := MultiMeshInstance3D.new()
	stars.name = "DistantStars"
	stars.multimesh = multi
	add_child(stars)


func _build_planet() -> void:
	planet_root = Node3D.new()
	planet_root.name = "RotatingEarth"
	add_child(planet_root)

	earth_instance = MeshInstance3D.new()
	earth_instance.name = "EarthSurface"
	earth_instance.mesh = _build_sphere_mesh(RADIUS, 160, 80)
	earth_material = StandardMaterial3D.new()
	earth_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	earth_material.albedo_color = Color.WHITE
	earth_material.roughness = 0.92
	earth_material.metallic = 0.0
	earth_material.specular = 0.18
	earth_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var fallback_ocean := Image.create(2, 2, false, Image.FORMAT_RGB8)
	fallback_ocean.fill(Color("#0B3556"))
	earth_material.albedo_texture = ImageTexture.create_from_image(fallback_ocean)
	earth_instance.material_override = earth_material
	earth_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(earth_instance)

	_debug_event("3D Earth surface ready.") atmosphere.")


func _build_sphere_mesh(radius: float, longitude_segments: int, latitude_segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lat_index in range(latitude_segments):
		var lat_top := PI * 0.5 - PI * float(lat_index) / float(latitude_segments)
		var lat_bottom := PI * 0.5 - PI * float(lat_index + 1) / float(latitude_segments)
		for lon_index in range(longitude_segments):
			var lon_left := TAU * float(lon_index) / float(longitude_segments) - PI
			var lon_right := TAU * float(lon_index + 1) / float(longitude_segments) - PI
			var p00 := _geo_to_sphere(rad_to_deg(lon_left), rad_to_deg(lat_top), radius)
			var p01 := _geo_to_sphere(rad_to_deg(lon_right), rad_to_deg(lat_top), radius)
			var p10 := _geo_to_sphere(rad_to_deg(lon_left), rad_to_deg(lat_bottom), radius)
			var p11 := _geo_to_sphere(rad_to_deg(lon_right), rad_to_deg(lat_bottom), radius)
			_add_surface_vertex(surface, p00, Vector2(float(lon_index) / longitude_segments, float(lat_index) / latitude_segments))
			_add_surface_vertex(surface, p01, Vector2(float(lon_index + 1) / longitude_segments, float(lat_index) / latitude_segments))
			_add_surface_vertex(surface, p10, Vector2(float(lon_index) / longitude_segments, float(lat_index + 1) / latitude_segments))
			_add_surface_vertex(surface, p01, Vector2(float(lon_index + 1) / longitude_segments, float(lat_index) / latitude_segments))
			_add_surface_vertex(surface, p11, Vector2(float(lon_index + 1) / longitude_segments, float(lat_index + 1) / latitude_segments))
			_add_surface_vertex(surface, p10, Vector2(float(lon_index) / longitude_segments, float(lat_index + 1) / latitude_segments))
	surface.index()
	return surface.commit()


func _add_surface_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_normal(point.normalized())
	surface.set_uv(uv)
	surface.add_vertex(point)


func _geo_to_sphere(longitude: float, latitude: float, radius: float) -> Vector3:
	var lon := deg_to_rad(longitude)
	var lat := deg_to_rad(latitude)
	return Vector3(
		radius * cos(lat) * sin(lon),
		radius * sin(lat),
		radius * cos(lat) * cos(lon)
	)


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GlobeInterface"
	layer.layer = 30
	add_child(layer)

	var back := Button.new()
	back.name = "GlobeBackButton"
	back.text = "‹  BACK"
	back.position = Vector2(16.0, 14.0)
	back.custom_minimum_size = Vector2(92.0, 46.0)
	back.pressed.connect(func() -> void: back_requested.emit())
	_style_button(back, false)
	layer.add_child(back)

	# Keep the internal status target available for network/data callbacks,
	# but never display loading or diagnostic text over the globe.
	status_label = Label.new()
	status_label.name = "HiddenGlobeStatus"
	status_label.visible = false
	layer.add_child(status_label)


func _build_debug_panel(layer: CanvasLayer) -> void:
	var overlay := Control.new()
	overlay.name = "GlobeDiagnosticsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	debug_panel = PanelContainer.new()
	debug_panel.name = "GlobeDiagnosticsPanel"
	debug_panel.anchor_left = 1.0
	debug_panel.anchor_right = 1.0
	debug_panel.anchor_top = 0.0
	debug_panel.anchor_bottom = 0.0
	debug_panel.offset_left = -306.0
	debug_panel.offset_top = 62.0
	debug_panel.offset_right = -12.0
	debug_panel.offset_bottom = 292.0
	debug_panel.visible = false
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(debug_panel)

	var panel_layout := VBoxContainer.new()
	panel_layout.add_theme_constant_override("separation", 6)
	debug_panel.add_child(panel_layout)

	var panel_header := HBoxContainer.new()
	panel_header.add_theme_constant_override("separation", 8)
	panel_layout.add_child(panel_header)

	var panel_title := Label.new()
	panel_title.text = "LIVE GLOBE DIAGNOSTICS"
	panel_title.add_theme_font_size_override("font_size", 12)
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_header.add_child(panel_title)

	debug_copy_button = Button.new()
	debug_copy_button.text = "COPY"
	debug_copy_button.custom_minimum_size = Vector2(62, 28)
	debug_copy_button.pressed.connect(_copy_debug_report)
	_style_button(debug_copy_button, false)
	panel_header.add_child(debug_copy_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(270, 184)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_layout.add_child(scroll)

	debug_text = Label.new()
	debug_text.custom_minimum_size = Vector2(266, 0)
	debug_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(debug_text)
	_refresh_debug_panel()


func _toggle_debug_panel() -> void:
	if not is_instance_valid(debug_panel):
		return
	debug_panel.visible = not debug_panel.visible
	debug_toggle.text = "CLOSE" if debug_panel.visible else "DEBUG"
	_refresh_debug_panel()


func _copy_debug_report() -> void:
	if not is_instance_valid(debug_text) or not is_instance_valid(debug_copy_button):
		return
	DisplayServer.clipboard_set(debug_text.text)
	debug_copy_button.text = "COPIED"


func _debug_event(message: String, failed: bool = false) -> void:
	var entry := ("[FAIL] " if failed else "[INFO] ") + message
	debug_messages.append(entry)
	if failed:
		debug_failure_count += 1
	while debug_messages.size() > 12:
		debug_messages.pop_front()
	print("GLOBE_DIAGNOSTICS: " + entry)
	_refresh_debug_panel()


func _refresh_debug_panel() -> void:
	if not is_instance_valid(debug_text):
		return
	var earth_ready := is_instance_valid(earth_instance) and earth_instance.mesh != null and earth_instance.mesh.get_surface_count() > 0
	var cloud_ready := is_instance_valid(cloud_shell) and cloud_shell.mesh != null
	var atmosphere_ready := is_instance_valid(planet_root) and is_instance_valid(planet_root.get_node_or_null("BlueAtmosphericRim"))
	var map_state := "LOADED" if overview_texture != null else "FALLBACK / WAITING"
	var country_state := "LOADED (%d features)" % country_features.size() if country_boundaries_loaded else ("LOADING" if country_boundaries_loading else "NOT LOADED")
	var country_expected := _is_country_zoom_active()
	var country_actual := is_instance_valid(country_boundary_node) and country_boundary_node.visible
	var country_layer_state := "WAITING FOR DATA" if not country_boundaries_loaded else ("OK / VISIBLE" if country_actual and country_expected else ("OK / HIDDEN" if not country_actual and not country_expected else "MISMATCH: expected %s" % ("VISIBLE" if country_expected else "HIDDEN")))
	var country_names_state := "OK (%d labels)" % country_label_nodes.size() if not country_boundaries_loaded or not country_label_nodes.is_empty() else "FAIL: no country names generated"
	var province_ready := not province_boundary_nodes.is_empty()
	var province_expected := _is_province_zoom_active()
	var province_actual := province_ready and is_instance_valid(province_boundary_nodes[0]) and province_boundary_nodes[0].visible
	var province_layer_state := "WAITING FOR COUNTRY / DATA" if not province_ready and province_expected else ("NOT NEEDED AT THIS ZOOM" if not province_expected and not province_ready else ("OK / VISIBLE" if province_actual and province_expected else ("OK / HIDDEN" if not province_actual and not province_expected else "MISMATCH: expected %s" % ("VISIBLE" if province_expected else "HIDDEN"))))
	var province_names_state := "OK (%d labels)" % province_label_nodes.size() if not province_ready or not province_label_nodes.is_empty() else "FAIL: no region names generated"
	var lines := PackedStringArray([
		"3D Earth mesh: %s" % ("READY" if earth_ready else "FAILED"),
		"Lit material: %s" % ("STANDARD PBR" if earth_material is StandardMaterial3D else "FAILED"),
		"Cloud shell: %s" % ("READY" if cloud_ready else "FAILED"),
		"Atmosphere: %s" % ("READY" if atmosphere_ready else "FAILED"),
		"NASA imagery: " + map_state,
		"Country dataset: " + country_state,
		"Country borders: " + country_layer_state,
		"Country names: " + country_names_state,
		"State/province layer: " + province_layer_state,
		"State/province names: " + province_names_state,
		"Zoom target: %.2f (country <= %.2f / regions <= %.2f)" % [target_distance, COUNTRY_ZOOM_DISTANCE, PROVINCE_ZOOM_DISTANCE],
		"Rotation: manual drag %.6f to %.6f by zoom / auto-rotation disabled" % [DRAG_ROTATION_SENSITIVITY * 0.28, DRAG_ROTATION_SENSITIVITY],
		"Zoom input: wheel %.3f / buttons %.3f / pinch %.5f / magnify %.2f" % [WHEEL_ZOOM_STEP, BUTTON_ZOOM_STEP, PINCH_ZOOM_SENSITIVITY, MAGNIFY_ZOOM_SENSITIVITY],
		"Failures recorded: %d" % debug_failure_count,
		"",
		"RECENT EVENTS:"
	])
	for entry in debug_messages:
		lines.append(entry)
	debug_text.text = "\n".join(lines)


func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#F4F7FC"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#214C79") if primary else Color("#111C2B")
	style.border_color = Color("#5D94D1") if primary else Color("#34465D")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("#2D6297") if primary else Color("#1C2B3D")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _load_overview_map() -> void:
	var cache_path := CACHE_ROOT + "/earth_overview_4k.jpg"
	if FileAccess.file_exists(cache_path):
		var cached_image := Image.load_from_file(cache_path)
		if cached_image != null and not cached_image.is_empty() and _apply_overview_image(cached_image):
			status_label.text = "CACHED EARTH IMAGERY  ·  CHECKING FOR AN UPDATE"
			_debug_event("Cached Earth imagery restored.")
		elif cached_image == null or cached_image.is_empty():
			_debug_event("Cached Earth imagery could not be decoded; requesting a fresh image.", true)
	_debug_event("NASA Blue Marble imagery request started.")
	_request_bytes(OVERVIEW_URL, cache_path, 32 * 1024 * 1024, func(result: int, response_code: int, body: PackedByteArray) -> void:
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			_debug_event("NASA WMS request failed (result %d, HTTP %d); keeping the lit fallback globe." % [result, response_code], true)
			if overview_texture == null:
				status_label.text = "NASA MAP UNAVAILABLE  ·  CHECK YOUR CONNECTION"
			return
		var image := Image.new()
		if image.load_jpg_from_buffer(body) != OK or image.get_width() < 512 or image.get_height() < 256:
			_debug_event("NASA WMS response was not a usable 512x256+ JPEG image.", true)
			if overview_texture == null:
				status_label.text = "NASA MAP RESPONSE IS INVALID  ·  CHECK YOUR CONNECTION"
			return
		if not _apply_overview_image(image):
			_debug_event("Decoded NASA imagery could not be applied to the Earth material.", true)
			if overview_texture == null:
				status_label.text = "NASA MAP COULD NOT BE APPLIED"
			return
		_debug_event("NASA Blue Marble texture loaded (%d x %d)." % [image.get_width(), image.get_height()])
		status_label.text = "NASA BLUE MARBLE  ·  DRAG TO ROTATE  ·  PINCH TO ZOOM"
	, true)


func _apply_overview_image(image: Image) -> bool:
	if image.is_empty() or image.get_width() < 512 or image.get_height() < 256:
		return false
	var prepared_image := image.duplicate()
	prepared_image.generate_mipmaps()
	overview_texture = ImageTexture.create_from_image(prepared_image)
	if not is_instance_valid(earth_material):
		return false
	earth_material.albedo_texture = overview_texture
	return true


func _load_country_boundaries() -> void:
	country_boundaries_loading = true
	_debug_event("Loading Natural Earth country boundaries.")
	status_label.text = "LOADING WORLD COUNTRY BOUNDARIES…"
	var cache_path := CACHE_ROOT + "/natural_earth_admin0.geojson"
	_request_bytes(COUNTRY_BOUNDARIES_URL, cache_path, 12 * 1024 * 1024, _on_country_boundaries_loaded)


func _on_country_boundaries_loaded(result: int, response_code: int, body: PackedByteArray) -> void:
	country_boundaries_loading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_debug_event("Country dataset request failed (result %d, HTTP %d)." % [result, response_code], true)
		status_label.text = "COUNTRY OUTLINES UNAVAILABLE  ·  CHECK YOUR CONNECTION"
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not _apply_country_boundaries(parsed):
		if not country_cache_retry_used:
			country_cache_retry_used = true
			country_boundaries_loading = true
			_debug_event("Cached country dataset is invalid; retrying from the online source.", true)
			_request_bytes(COUNTRY_BOUNDARIES_URL, CACHE_ROOT + "/natural_earth_admin0.geojson", 12 * 1024 * 1024, _on_country_boundaries_loaded, true)
			return
		_debug_event("Country dataset JSON could not be parsed or had no usable features.", true)
		status_label.text = "COUNTRY OUTLINE DATA COULD NOT BE READ"
		return
	_debug_event("Country dataset loaded: %d features." % country_features.size())
	status_label.text = "%d COUNTRY OUTLINES  ·  ZOOM IN FOR STATES / PROVINCES" % country_features.size()


func _apply_country_boundaries(geojson: Dictionary) -> bool:
	var features: Variant = geojson.get("features", [])
	if not features is Array or features.is_empty():
		return false
	var next_node := _add_boundary_mesh(geojson, Color("#AFCFEA"), 1.012, "WorldCountryBoundaries")
	if next_node == null:
		return false
	if is_instance_valid(country_boundary_node):
		country_boundary_node.queue_free()
	country_boundary_node = next_node
	country_boundary_node.visible = _is_country_zoom_active()
	country_features = features
	country_boundaries_loaded = true
	_create_country_labels(features)
	_refresh_globe_label_visibility()
	_debug_event("Country overlays prepared; hidden until the country zoom threshold.")
	return true


func _is_country_zoom_active() -> bool:
	return target_distance <= COUNTRY_ZOOM_DISTANCE


func _is_province_zoom_active() -> bool:
	return target_distance <= PROVINCE_ZOOM_DISTANCE


func _update_administrative_layers() -> void:
	_refresh_globe_label_visibility()
	var show_countries := _is_country_zoom_active()
	if is_instance_valid(country_boundary_node):
		country_boundary_node.visible = show_countries
	var show_provinces := _is_province_zoom_active()
	for node in province_boundary_nodes:
		if is_instance_valid(node):
			node.visible = show_provinces
	if not show_provinces or not country_boundaries_loaded:
		return

	var feature := _find_country_at_front()
	if feature.is_empty():
		for node in province_boundary_nodes:
			if is_instance_valid(node):
				node.visible = false
		for label in province_label_nodes:
			if is_instance_valid(label):
				label.visible = false
		if last_debug_country_state != "NO COUNTRY":
			_debug_event("Deep zoom has no country centered beneath the camera; regional layer is waiting.")
			last_debug_country_state = "NO COUNTRY"
		status_label.text = "ZOOM ONTO A COUNTRY TO LOAD ITS REGIONS"
		return
	var properties: Dictionary = feature.get("properties", {})
	var iso := str(properties.get("ADM0_A3", "")).strip_edges()
	if iso.length() != 3 or iso == "-99":
		iso = str(properties.get("ISO_A3_EH", "")).strip_edges()
	if iso.length() != 3 or iso == "-99":
		status_label.text = "REGIONAL BOUNDARIES UNAVAILABLE FOR THIS AREA"
		return

	if iso == focused_country_iso:
		return

	focused_country_iso = iso
	focused_country_name = str(properties.get("ADMIN", properties.get("NAME", "Selected country")))
	last_debug_country_state = iso
	_debug_event("Deep zoom target: %s (%s); requesting ADM1 regions." % [focused_country_name, iso])
	region_request_generation += 1
	var generation := region_request_generation
	_clear_province_boundaries()
	status_label.text = "LOADING %s STATES / PROVINCES…" % focused_country_name.to_upper()
	_request_country_provinces(iso, generation)


func _find_country_at_front() -> Dictionary:
	if country_features.is_empty() or not is_instance_valid(planet_root):
		return {}
	var local_direction := planet_root.to_local(camera.global_position).normalized()
	var longitude := rad_to_deg(atan2(local_direction.x, local_direction.z))
	var latitude := rad_to_deg(asin(clampf(local_direction.y, -1.0, 1.0)))

	for item in country_features:
		if not item is Dictionary:
			continue
		var feature: Dictionary = item
		var bounds: Array = feature.get("bbox", [])
		if bounds.size() >= 4:
			if longitude < float(bounds[0]) or longitude > float(bounds[2]) or latitude < float(bounds[1]) or latitude > float(bounds[3]):
				continue
		var geometry: Dictionary = feature.get("geometry", {})
		if _geometry_contains_point(geometry, longitude, latitude):
			return feature
	return {}


func _geometry_contains_point(geometry: Dictionary, longitude: float, latitude: float) -> bool:
	var coordinates: Variant = geometry.get("coordinates", [])
	match str(geometry.get("type", "")):
		"Polygon":
			return _polygon_contains_point(coordinates, longitude, latitude)
		"MultiPolygon":
			if coordinates is Array:
				for polygon in coordinates:
					if _polygon_contains_point(polygon, longitude, latitude):
						return true
	return false


func _polygon_contains_point(polygon: Variant, longitude: float, latitude: float) -> bool:
	if not polygon is Array or polygon.is_empty():
		return false
	var rings: Array = polygon
	if not _point_in_ring(rings[0], longitude, latitude):
		return false
	for hole_index in range(1, rings.size()):
		if _point_in_ring(rings[hole_index], longitude, latitude):
			return false
	return true


func _point_in_ring(ring: Variant, longitude: float, latitude: float) -> bool:
	if not ring is Array or ring.size() < 4:
		return false
	var inside := false
	var previous_index: int = ring.size() - 1
	for index in range(ring.size()):
		var current: Array = ring[index]
		var previous: Array = ring[previous_index]
		if current.size() >= 2 and previous.size() >= 2:
			var current_lon := float(current[0])
			var current_lat := float(current[1])
			var previous_lon := float(previous[0])
			var previous_lat := float(previous[1])
			if (current_lat > latitude) != (previous_lat > latitude):
				var intersection_lon := (previous_lon - current_lon) * (latitude - current_lat) / (previous_lat - current_lat) + current_lon
				if longitude < intersection_lon:
					inside = not inside
		previous_index = index
	return inside


func _request_country_provinces(iso: String, generation: int) -> void:
	var metadata_cache := CACHE_ROOT + "/automatic_adm1_" + iso + ".json"
	var metadata_url := GEOBOUNDARIES_ROOT + "/" + iso + "/ADM1/"
	_request_bytes(metadata_url, metadata_cache, 3 * 1024 * 1024, func(result: int, response_code: int, body: PackedByteArray) -> void:
		if generation != region_request_generation or not _is_province_zoom_active():
			return
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			_debug_event("%s ADM1 metadata request failed (result %d, HTTP %d)." % [focused_country_name, result, response_code], true)
			status_label.text = "%s REGIONAL DATA IS UNAVAILABLE" % focused_country_name.to_upper()
			return
		var metadata: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not metadata is Dictionary:
			_debug_event("%s ADM1 metadata response was not valid JSON." % focused_country_name, true)
			status_label.text = "%s REGIONAL DATA COULD NOT BE READ" % focused_country_name.to_upper()
			return
		var geojson_url := str(metadata.get("simplifiedGeometryGeoJSON", metadata.get("gjDownloadURL", "")))
		if geojson_url.is_empty():
			_debug_event("%s has no ADM1 download URL in geoBoundaries metadata." % focused_country_name, true)
			status_label.text = "%s HAS NO PUBLISHED ADM1 DATASET" % focused_country_name.to_upper()
			return
		var geometry_cache := CACHE_ROOT + "/automatic_adm1_" + iso + "_geometry.json"
		_request_bytes(geojson_url, geometry_cache, 24 * 1024 * 1024, func(geo_result: int, geo_code: int, geo_body: PackedByteArray) -> void:
			if generation != region_request_generation or not _is_province_zoom_active():
				return
			if geo_result != HTTPRequest.RESULT_SUCCESS or geo_code != 200:
				_debug_event("%s ADM1 geometry download failed (result %d, HTTP %d)." % [focused_country_name, geo_result, geo_code], true)
				status_label.text = "%s REGIONAL BOUNDARIES COULD NOT BE DOWNLOADED" % focused_country_name.to_upper()
				return
			var geojson: Variant = JSON.parse_string(geo_body.get_string_from_utf8())
			if not geojson is Dictionary:
				_debug_event("%s ADM1 geometry response was not valid GeoJSON." % focused_country_name, true)
				status_label.text = "%s REGIONAL DATA FORMAT IS INVALID" % focused_country_name.to_upper()
				return
			_apply_province_boundaries(geojson)
		)
	)


func _apply_province_boundaries(geojson: Dictionary) -> bool:
	var features: Variant = geojson.get("features", [])
	if not features is Array or features.is_empty():
		_debug_event("%s ADM1 dataset returned no state/province features." % focused_country_name, true)
		status_label.text = "%s HAS NO STATE / PROVINCE FEATURES" % focused_country_name.to_upper()
		return false
	var node := _add_boundary_mesh(geojson, Color("#55B5E9"), 1.019, "AutomaticStateProvinceBoundaries")
	if node == null:
		_debug_event("%s ADM1 features could not be converted into a boundary mesh." % focused_country_name, true)
		status_label.text = "%s REGIONAL OUTLINES COULD NOT BE DRAWN" % focused_country_name.to_upper()
		return false
	node.visible = _is_province_zoom_active()
	province_boundary_nodes.append(node)
	_create_province_labels(features)
	_refresh_globe_label_visibility()
	if province_label_nodes.is_empty():
		_debug_event("%s ADM1 geometry loaded, but no usable state/province label locations were created." % focused_country_name, true)
	else:
		_debug_event("%s ADM1 layer ready: %d regions and %d labels." % [focused_country_name, features.size(), province_label_nodes.size()])
	status_label.text = "%s  ·  %d STATES / PROVINCES" % [focused_country_name.to_upper(), features.size()]
	return true


func _clear_province_boundaries() -> void:
	for node in province_boundary_nodes:
		if is_instance_valid(node):
			node.queue_free()
	province_boundary_nodes.clear()
	for label in province_label_nodes:
		if is_instance_valid(label):
			label.queue_free()
	province_label_nodes.clear()


func _create_country_labels(features: Array) -> void:
	for label in country_label_nodes:
		if is_instance_valid(label):
			label.queue_free()
	country_label_nodes.clear()
	for item in features:
		if not item is Dictionary:
			continue
		var feature: Dictionary = item
		var properties: Dictionary = feature.get("properties", {})
		var country_name := str(properties.get("NAME", properties.get("ADMIN", ""))).strip_edges()
		if country_name.is_empty():
			continue
		if not properties.has("LABEL_X") or not properties.has("LABEL_Y"):
			continue
		var longitude := float(properties.get("LABEL_X", 0.0))
		var latitude := float(properties.get("LABEL_Y", 0.0))
		var label := _make_globe_label(country_name, longitude, latitude, 1.016, 18, 0.00085)
		label.set_meta("natural_earth_label_rank", int(properties.get("LABELRANK", 7)))
		label.name = "CountryName_" + str(properties.get("ADM0_A3", country_name)).replace(" ", "_")
		country_label_nodes.append(label)


func _create_province_labels(features: Array) -> void:
	for label in province_label_nodes:
		if is_instance_valid(label):
			label.queue_free()
	province_label_nodes.clear()
	for item in features:
		if not item is Dictionary:
			continue
		var feature: Dictionary = item
		var properties: Dictionary = feature.get("properties", {})
		var region_name := _administrative_feature_name(properties)
		if region_name.is_empty():
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var label_point := _administrative_label_point(properties, geometry)
		if label_point.x < -180.0 or label_point.x > 180.0 or label_point.y < -90.0 or label_point.y > 90.0:
			continue
		var label := _make_globe_label(region_name, label_point.x, label_point.y, 1.022, 11, 0.00055)
		label.name = "ProvinceName_" + str(province_label_nodes.size() + 1)
		province_label_nodes.append(label)


func _administrative_feature_name(properties: Dictionary) -> String:
	for key in ["shapeName", "name", "NAME_1", "name_1", "NAME", "admin", "region"]:
		if properties.has(key):
			var value := str(properties[key]).strip_edges()
			if not value.is_empty():
				return value
	return ""


func _administrative_label_point(properties: Dictionary, geometry: Dictionary) -> Vector2:
	var longitude_keys := ["label_x", "LABEL_X", "longitude", "LONGITUDE"]
	var latitude_keys := ["label_y", "LABEL_Y", "latitude", "LATITUDE"]
	for index in range(longitude_keys.size()):
		var lon_key: String = longitude_keys[index]
		var lat_key: String = latitude_keys[index]
		if properties.has(lon_key) and properties.has(lat_key):
			return Vector2(float(properties[lon_key]), float(properties[lat_key]))
	return _geometry_label_point(geometry)


func _geometry_label_point(geometry: Dictionary) -> Vector2:
	var geometry_type := str(geometry.get("type", ""))
	var coordinates: Variant = geometry.get("coordinates", [])
	var best_center := Vector2.ZERO
	var best_area := -1.0
	if geometry_type == "Polygon":
		var polygon_result := _polygon_label_centroid(coordinates)
		return polygon_result.get("center", Vector2.ZERO)
	if geometry_type == "MultiPolygon" and coordinates is Array:
		for polygon in coordinates:
			var polygon_result := _polygon_label_centroid(polygon)
			var area := float(polygon_result.get("area", 0.0))
			if area > best_area:
				best_area = area
				best_center = polygon_result.get("center", Vector2.ZERO)
	return best_center


func _polygon_label_centroid(polygon: Variant) -> Dictionary:
	if not polygon is Array or polygon.is_empty():
		return {}
	var rings: Array = polygon
	var outer_ring: Variant = rings[0]
	if not outer_ring is Array or outer_ring.size() < 4:
		return {}
	var twice_area := 0.0
	var centroid_x := 0.0
	var centroid_y := 0.0
	var average := Vector2.ZERO
	var point_count := 0
	for index in range(outer_ring.size() - 1):
		var current: Array = outer_ring[index]
		var next: Array = outer_ring[index + 1]
		if current.size() < 2 or next.size() < 2:
			continue
		var x0 := float(current[0])
		var y0 := float(current[1])
		var x1 := float(next[0])
		var y1 := float(next[1])
		var cross := x0 * y1 - x1 * y0
		twice_area += cross
		centroid_x += (x0 + x1) * cross
		centroid_y += (y0 + y1) * cross
		average += Vector2(x0, y0)
		point_count += 1
	if absf(twice_area) < 0.000001:
		if point_count == 0:
			return {}
		return {"center": average / float(point_count), "area": 0.0}
	var center := Vector2(centroid_x / (3.0 * twice_area), centroid_y / (3.0 * twice_area))
	return {"center": center, "area": absf(twice_area) * 0.5}


func _make_globe_label(label_text: String, longitude: float, latitude: float, radius: float, font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.text = label_text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 2 if font_size <= 11 else 3
	label.outline_modulate = Color("#07111F")
	label.modulate = Color("#F1F7FF")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = _geo_to_sphere(longitude, latitude, radius)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(label)
	return label


func _refresh_globe_label_visibility() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(planet_root):
		return
	var camera_direction := planet_root.to_local(camera.global_position).normalized()
	var show_countries := _is_country_zoom_active()
	var country_rank_limit := 6
	if target_distance <= 2.75:
		country_rank_limit = 8
	if target_distance <= 2.20:
		country_rank_limit = 11
	for label in country_label_nodes:
		if not is_instance_valid(label):
			continue
		var rank := int(label.get_meta("natural_earth_label_rank", 7))
		var on_front := label.position.normalized().dot(camera_direction) > 0.08
		label.visible = show_countries and on_front and rank <= country_rank_limit
	var show_provinces := _is_province_zoom_active()
	for label in province_label_nodes:
		if not is_instance_valid(label):
			continue
		label.visible = show_provinces and label.position.normalized().dot(camera_direction) > 0.05


func _add_boundary_mesh(geojson: Dictionary, color: Color, radius: float, node_name: String) -> MeshInstance3D:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.albedo_color = Color(color.r, color.g, color.b, 0.72)
	line_material.emission_enabled = true
	line_material.emission = Color(color.r, color.g, color.b, 0.72)
	line_material.emission_energy_multiplier = 0.22
	lines.set_material(line_material)
	var features: Array = geojson.get("features", [])
	for feature in features:
		if not feature is Dictionary:
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var rings: Array = []
		_collect_rings(geometry.get("coordinates", []), rings)
		for ring in rings:
			if ring.size() < 2:
				continue
			for point_index in range(ring.size() - 1):
				var a: Array = ring[point_index]
				var b: Array = ring[point_index + 1]
				if a.size() < 2 or b.size() < 2:
					continue
				var point_a := _geo_to_sphere(float(a[0]), float(a[1]), radius)
				var point_b := _geo_to_sphere(float(b[0]), float(b[1]), radius)
				lines.set_normal(point_a.normalized())
				lines.add_vertex(point_a)
				lines.set_normal(point_b.normalized())
				lines.add_vertex(point_b)
	var mesh := lines.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(instance)
	return instance

func _collect_rings(value: Variant, output: Array) -> void:
	if not value is Array:
		return
	var array_value: Array = value
	if array_value.size() > 1 and array_value[0] is Array:
		var first: Array = array_value[0]
		if first.size() >= 2 and typeof(first[0]) in [TYPE_FLOAT, TYPE_INT]:
			output.append(array_value)
			return
	for item in array_value:
		_collect_rings(item, output)


func _request_bytes(url: String, cache_path: String, body_limit: int, completed: Callable, refresh_cache: bool = false) -> void:
	if not refresh_cache and not cache_path.is_empty() and FileAccess.file_exists(cache_path):
		var cached := FileAccess.open(cache_path, FileAccess.READ)
		if cached != null:
			var cached_body := cached.get_buffer(cached.get_length())
			cached.close()
			completed.call(HTTPRequest.RESULT_SUCCESS, 200, cached_body)
			return
	var request := HTTPRequest.new()
	request.timeout = 45.0
	request.body_size_limit = body_limit
	add_child(request)
	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and not cache_path.is_empty():
			_write_cache(cache_path, body)
		completed.call(result, response_code, body)
	)
	var error := request.request(url)
	if error != OK:
		request.queue_free()
		completed.call(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedByteArray())


func _write_cache(path: String, body: PackedByteArray) -> void:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(body)
	file.close()
