extends Node3D

signal back_requested

const RADIUS := 1.0
const START_DISTANCE := 3.65
const MIN_DISTANCE := 1.42
const MAX_DISTANCE := 7.0
const ADMIN_ZOOM_DISTANCE := 3.05
const GEOBOUNDARIES_ROOT := "https://www.geoboundaries.org/api/current/gbOpen"
const NASA_WMS_ROOT := "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi"
const OVERVIEW_URL := NASA_WMS_ROOT + "?service=WMS&request=GetMap&version=1.1.1&layers=BlueMarble_ShadedRelief_Bathymetry&styles=&format=image/jpeg&srs=EPSG:4326&bbox=-180,-90,180,90&width=2048&height=1024"
const CACHE_ROOT := "user://digitalworld/globe"

const EARTH_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D earth_map : source_color;
void fragment() {
	vec3 surface = texture(earth_map, UV).rgb;
	ALBEDO = surface;
	ROUGHNESS = 0.92;
}
"""

const CLOUD_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform sampler2D cloud_noise : source_color;
void fragment() {
	vec2 drift = vec2(TIME * 0.0008, 0.0);
	float density = texture(cloud_noise, UV * vec2(2.5, 1.65) + drift).r;
	float cloud = smoothstep(0.54, 0.73, density);
	ALBEDO = vec3(0.91, 0.95, 1.0);
	ALPHA = cloud * 0.20;
}
"""

const ATMOSPHERE_SHADER := """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2);
	ALBEDO = vec3(0.12, 0.42, 0.92);
	ALPHA = rim * 0.42;
}
"""

const PATCH_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D detail_map : source_color;
void fragment() {
	ALBEDO = texture(detail_map, UV).rgb;
	ROUGHNESS = 0.95;
}
"""

var planet_root: Node3D
var earth_instance: MeshInstance3D
var earth_material: ShaderMaterial
var cloud_shell: MeshInstance3D
var camera: Camera3D
var target_distance := START_DISTANCE
var dragging := false
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var country_catalog_loaded := false
var country_catalog_loading := false
var selection_generation := 0
var selected_country_iso := ""
var selected_country_name := ""
var state_records: Array[Dictionary] = []
var boundary_nodes: Array[Node3D] = []
var detail_patch: MeshInstance3D
var selected_state_marker: Label3D
var country_select: OptionButton
var province_select: OptionButton
var admin_panel: PanelContainer
var retry_button: Button
var country_catalog_attempted := false
var status_label: Label
var overview_texture: Texture2D


func _ready() -> void:
	_build_space_environment()
	_build_planet()
	_build_interface()
	_load_overview_map()
	_update_admin_visibility()
	set_process(true)


func _process(delta: float) -> void:
	if not dragging:
		planet_root.rotate_y(delta * 0.012)
	camera.position.z = lerpf(camera.position.z, target_distance, minf(delta * 5.0, 1.0))
	camera.look_at(Vector3.ZERO, Vector3.UP)
	_update_admin_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(target_distance - 0.34)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(target_distance + 0.34)
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
					_set_zoom(target_distance + (last_pinch_distance - next_distance) * 0.008)
				last_pinch_distance = next_distance
			else:
				_drag_planet(event.relative)
	elif event is InputEventMagnifyGesture:
		_set_zoom(target_distance / maxf(event.factor, 0.1))


func _get_pinch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
	var touch_ids := touch_points.keys()
	var first_point: Vector2 = touch_points[touch_ids[0]]
	var second_point: Vector2 = touch_points[touch_ids[1]]
	return first_point.distance_to(second_point)


func _drag_planet(relative: Vector2) -> void:
	planet_root.rotate_y(relative.x * 0.005)
	planet_root.rotate_x(relative.y * 0.005)
	planet_root.rotation.x = clampf(planet_root.rotation.x, -1.48, 1.48)


func _set_zoom(distance: float) -> void:
	target_distance = clampf(distance, MIN_DISTANCE, MAX_DISTANCE)
	if target_distance <= ADMIN_ZOOM_DISTANCE and not country_catalog_loaded and not country_catalog_loading:
		_load_country_catalog()


func _build_space_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#030711")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#66758C")
	environment.ambient_light_energy = 0.20
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
	sunlight.light_energy = 1.35
	sunlight.shadow_enabled = false
	add_child(sunlight)

	_add_starfield()


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
		var scale := randf_range(0.45, 1.45)
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), direction * 17.0))
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
	earth_material = ShaderMaterial.new()
	var earth_shader := Shader.new()
	earth_shader.code = EARTH_SHADER
	earth_material.shader = earth_shader
	var fallback_ocean := Image.create(2, 2, false, Image.FORMAT_RGB8)
	fallback_ocean.fill(Color("#0B3556"))
	earth_material.set_shader_parameter("earth_map", ImageTexture.create_from_image(fallback_ocean))
	earth_instance.material_override = earth_material
	earth_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(earth_instance)

	var cloud_noise := FastNoiseLite.new()
	cloud_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cloud_noise.frequency = 1.8
	cloud_noise.fractal_octaves = 4
	cloud_noise.fractal_gain = 0.48
	var noise_texture := NoiseTexture2D.new()
	noise_texture.width = 512
	noise_texture.height = 256
	noise_texture.seamless = true
	noise_texture.noise = cloud_noise

	cloud_shell = MeshInstance3D.new()
	cloud_shell.name = "ProceduralCloudDeck"
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.014
	cloud_mesh.height = 2.028
	cloud_mesh.radial_segments = 128
	cloud_mesh.rings = 64
	cloud_shell.mesh = cloud_mesh
	var cloud_material := ShaderMaterial.new()
	var cloud_shader := Shader.new()
	cloud_shader.code = CLOUD_SHADER
	cloud_material.shader = cloud_shader
	cloud_material.set_shader_parameter("cloud_noise", noise_texture)
	cloud_shell.material_override = cloud_material
	cloud_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(cloud_shell)

	var atmosphere := MeshInstance3D.new()
	atmosphere.name = "BlueAtmosphericRim"
	var atmosphere_mesh := SphereMesh.new()
	atmosphere_mesh.radius = 1.037
	atmosphere_mesh.height = 2.074
	atmosphere_mesh.radial_segments = 96
	atmosphere_mesh.rings = 48
	atmosphere.mesh = atmosphere_mesh
	var atmosphere_material := ShaderMaterial.new()
	var atmosphere_shader := Shader.new()
	atmosphere_shader.code = ATMOSPHERE_SHADER
	atmosphere_material.shader = atmosphere_shader
	atmosphere.material_override = atmosphere_material
	atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(atmosphere)


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
			_add_surface_vertex(surface, p10, Vector2(float(lon_index) / longitude_segments, float(lat_index + 1) / latitude_segments))
			_add_surface_vertex(surface, p01, Vector2(float(lon_index + 1) / longitude_segments, float(lat_index) / latitude_segments))
			_add_surface_vertex(surface, p01, Vector2(float(lon_index + 1) / longitude_segments, float(lat_index) / latitude_segments))
			_add_surface_vertex(surface, p10, Vector2(float(lon_index) / longitude_segments, float(lat_index + 1) / latitude_segments))
			_add_surface_vertex(surface, p11, Vector2(float(lon_index + 1) / longitude_segments, float(lat_index + 1) / latitude_segments))
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

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	layer.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var back := Button.new()
	back.text = "‹  BACK"
	back.custom_minimum_size = Vector2(92, 46)
	back.pressed.connect(func() -> void: back_requested.emit())
	_style_button(back, false)
	header.add_child(back)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)

	var title := Label.new()
	title.text = "EARTH  /  LIVE ATLAS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#F0F4FB"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A planet-sized view of our world"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color("#8E9EB8"))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(subtitle)

	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(42, 44)
	zoom_out.pressed.connect(func() -> void: _set_zoom(target_distance + 0.36))
	_style_button(zoom_out, false)
	header.add_child(zoom_out)

	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(42, 44)
	zoom_in.pressed.connect(func() -> void: _set_zoom(target_distance - 0.36))
	_style_button(zoom_in, true)
	header.add_child(zoom_in)

	admin_panel = PanelContainer.new()
	admin_panel.name = "ZoomOnlyAdministrativeData"
	admin_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.035, 0.07, 0.90)
	panel_style.border_color = Color("#4976A8", 0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	admin_panel.add_theme_stylebox_override("panel", panel_style)
	layout.add_child(admin_panel)

	var selectors := VBoxContainer.new()
	selectors.add_theme_constant_override("separation", 6)
	admin_panel.add_child(selectors)

	var selector_title := Label.new()
	selector_title.text = "EXPLORE ADMINISTRATIVE BOUNDARIES"
	selector_title.add_theme_font_size_override("font_size", 10)
	selector_title.add_theme_color_override("font_color", Color("#A9C9EF"))
	selectors.add_child(selector_title)

	country_select = OptionButton.new()
	country_select.custom_minimum_size = Vector2(0, 42)
	country_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_select.add_item("Loading country index…")
	country_select.disabled = true
	country_select.item_selected.connect(_on_country_selected)
	selectors.add_child(country_select)

	province_select = OptionButton.new()
	province_select.custom_minimum_size = Vector2(0, 42)
	province_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	province_select.add_item("Select a country first")
	province_select.disabled = true
	province_select.item_selected.connect(_on_province_selected)
	selectors.add_child(province_select)

	retry_button = Button.new()
	retry_button.text = "RETRY WORLD DATA"
	retry_button.visible = false
	retry_button.custom_minimum_size = Vector2(0, 38)
	retry_button.pressed.connect(_on_retry_pressed)
	_style_button(retry_button, false)
	selectors.add_child(retry_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(footer_spacer)

	status_label = Label.new()
	status_label.text = "DRAG TO ROTATE  ·  PINCH OR SCROLL TO ZOOM"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color("#B8C9DF"))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(status_label)

	var attribution := Label.new()
	attribution.text = "NASA GIBS / NASA ESDIS imagery  ·  geoBoundaries gbOpen (CC BY 4.0)"
	attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attribution.add_theme_font_size_override("font_size", 9)
	attribution.add_theme_color_override("font_color", Color("#72839D"))
	attribution.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(attribution)


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
	var cache_path := CACHE_ROOT + "/earth_overview.jpg"
	if FileAccess.file_exists(cache_path):
		var cached_image := Image.load_from_file(cache_path)
		if cached_image != null and not cached_image.is_empty():
			_apply_overview_image(cached_image)
			status_label.text = "CACHED EARTH IMAGERY  ·  CHECKING FOR AN UPDATE"
	_request_bytes(OVERVIEW_URL, cache_path, 12 * 1024 * 1024, func(result: int, response_code: int, body: PackedByteArray) -> void:
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			if overview_texture == null:
				status_label.text = "NASA MAP UNAVAILABLE  ·  CHECK YOUR CONNECTION"
			return
		var image := Image.new()
		if image.load_jpg_from_buffer(body) != OK:
			if overview_texture == null:
				status_label.text = "NASA MAP COULD NOT BE DECODED"
			return
		_apply_overview_image(image)
		status_label.text = "NASA BLUE MARBLE  ·  DRAG TO ROTATE  ·  PINCH TO ZOOM"
	, true)


func _apply_overview_image(image: Image) -> void:
	overview_texture = ImageTexture.create_from_image(image)
	earth_material.set_shader_parameter("earth_map", overview_texture)


func _update_admin_visibility() -> void:
	if not is_instance_valid(admin_panel):
		return
	var should_show := target_distance <= ADMIN_ZOOM_DISTANCE
	admin_panel.visible = should_show
	if should_show and not country_catalog_loaded and not country_catalog_loading and not country_catalog_attempted:
		_load_country_catalog()


func _load_country_catalog() -> void:
	country_catalog_attempted = true
	country_catalog_loading = true
	retry_button.visible = false
	status_label.text = "LOADING COUNTRY INDEX…"
	var cache_path := CACHE_ROOT + "/countries_adm0.json"
	_request_bytes(GEOBOUNDARIES_ROOT + "/ALL/ADM0/", cache_path, 18 * 1024 * 1024, _on_country_catalog_loaded)


func _on_country_catalog_loaded(result: int, response_code: int, body: PackedByteArray) -> void:
	country_catalog_loading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "COUNTRY INDEX UNAVAILABLE  ·  USE RETRY"
		retry_button.visible = true
		country_select.clear()
		country_select.add_item("Country index unavailable")
		country_select.disabled = true
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Array:
		status_label.text = "COUNTRY INDEX FORMAT NOT RECOGNISED"
		retry_button.visible = true
		return
	var countries: Array[Dictionary] = []
	for item in parsed:
		if item is Dictionary:
			var name := str(item.get("boundaryName", "")).strip_edges()
			var iso := str(item.get("boundaryISO", "")).strip_edges()
			if not name.is_empty() and iso.length() == 3:
				countries.append({"name": name, "iso": iso})
	countries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]).nocasecmp_to(str(b["name"])) < 0)
	country_select.clear()
	country_select.add_item("Choose a country…")
	country_select.set_item_metadata(0, "")
	for country in countries:
		country_select.add_item(str(country["name"]))
		country_select.set_item_metadata(country_select.item_count - 1, str(country["iso"]))
	country_select.disabled = countries.is_empty()
	country_catalog_loaded = not countries.is_empty()
	retry_button.visible = countries.is_empty()
	status_label.text = "%d COUNTRIES AVAILABLE  ·  SELECT ONE TO LOAD ITS REGIONS" % countries.size()


func _on_retry_pressed() -> void:
	if not selected_country_iso.is_empty():
		for index in range(1, country_select.item_count):
			if str(country_select.get_item_metadata(index)) == selected_country_iso:
				_on_country_selected(index)
				return
	country_catalog_attempted = false
	_load_country_catalog()


func _on_country_selected(index: int) -> void:
	if index <= 0:
		return
	var iso := str(country_select.get_item_metadata(index))
	if iso.length() != 3:
		return
	selection_generation += 1
	var generation := selection_generation
	selected_country_iso = iso
	selected_country_name = country_select.get_item_text(index)
	retry_button.visible = false
	_clear_boundaries()
	province_select.clear()
	province_select.add_item("Loading states / provinces…")
	province_select.disabled = true
	status_label.text = "LOADING %s BOUNDARIES…" % selected_country_name.to_upper()

	var adm0_cache := CACHE_ROOT + "/adm0_" + iso + ".json"
	var adm1_cache := CACHE_ROOT + "/adm1_" + iso + ".json"
	_request_boundary_metadata(iso, "ADM0", adm0_cache, generation)
	_request_boundary_metadata(iso, "ADM1", adm1_cache, generation)


func _request_boundary_metadata(iso: String, level: String, cache_path: String, generation: int) -> void:
	var url := GEOBOUNDARIES_ROOT + "/" + iso + "/" + level + "/"
	_request_bytes(url, cache_path, 3 * 1024 * 1024, func(result: int, response_code: int, body: PackedByteArray) -> void:
		if generation != selection_generation:
			return
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			if level == "ADM1":
				province_select.clear()
				province_select.add_item("No regional dataset available")
				province_select.disabled = true
			status_label.text = "%s BOUNDARY METADATA UNAVAILABLE  ·  USE RETRY" % level
			retry_button.visible = true
			return
		var metadata: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not metadata is Dictionary:
			retry_button.visible = true
			status_label.text = "%s METADATA FORMAT NOT RECOGNISED  ·  USE RETRY" % level
			return
		var geojson_url := str(metadata.get("simplifiedGeometryGeoJSON", metadata.get("gjDownloadURL", "")))
		if geojson_url.is_empty():
			retry_button.visible = true
			status_label.text = "%s DATASET HAS NO GEOMETRY URL  ·  USE RETRY" % level
			return
		var geojson_cache := CACHE_ROOT + "/" + level.to_lower() + "_" + iso + "_geometry.json"
		_request_bytes(geojson_url, geojson_cache, 22 * 1024 * 1024, func(geo_result: int, geo_code: int, geo_body: PackedByteArray) -> void:
			if generation != selection_generation:
				return
			if geo_result != HTTPRequest.RESULT_SUCCESS or geo_code != 200:
				status_label.text = "%s BOUNDARIES COULD NOT BE DOWNLOADED  ·  USE RETRY" % level
				retry_button.visible = true
				return
			var geojson: Variant = JSON.parse_string(geo_body.get_string_from_utf8())
			if not geojson is Dictionary:
				retry_button.visible = true
				status_label.text = "%s GEOMETRY FORMAT NOT RECOGNISED  ·  USE RETRY" % level
				return
			if level == "ADM0":
				_process_country_geojson(geojson)
			else:
				_process_province_geojson(geojson)
		)
	)


func _process_country_geojson(geojson: Dictionary) -> void:
	var features: Array = geojson.get("features", [])
	if features.is_empty():
		retry_button.visible = true
		status_label.text = "COUNTRY GEOMETRY IS EMPTY  ·  USE RETRY"
		return
	var stats := _geojson_stats(geojson)
	_add_boundary_mesh(geojson, Color("#C8E4FF"), 1.006, "CountryBoundary")
	if not stats.is_empty():
		_focus_geo(stats.get("center", Vector2.ZERO), 2.55)
		_request_detail_map(stats)
	status_label.text = "%s COUNTRY OUTLINE LOADED" % selected_country_name.to_upper()


func _process_province_geojson(geojson: Dictionary) -> void:
	var features: Array = geojson.get("features", [])
	state_records.clear()
	for feature in features:
		if not feature is Dictionary:
			continue
		var geometry: Dictionary = feature.get("geometry", {})
		var stats := _geometry_stats(geometry.get("coordinates", []))
		if stats.is_empty():
			continue
		var properties: Dictionary = feature.get("properties", {})
		var state_name := _feature_name(properties)
		if state_name.is_empty():
			state_name = "Region %d" % (state_records.size() + 1)
		state_records.append({"name": state_name, "center": stats["center"], "bounds": stats})
	_add_boundary_mesh(geojson, Color("#69B9FF"), 1.009, "ProvinceBoundaries")
	province_select.clear()
	province_select.add_item("Choose a state / province…")
	province_select.set_item_metadata(0, -1)
	for index in range(state_records.size()):
		province_select.add_item(str(state_records[index]["name"]))
		province_select.set_item_metadata(index + 1, index)
	province_select.disabled = state_records.is_empty()
	status_label.text = "%s  ·  %d STATES / PROVINCES LOADED" % [selected_country_name.to_upper(), state_records.size()]


func _feature_name(properties: Dictionary) -> String:
	for key in ["shapeName", "name", "NAME_1", "name_1", "NAME", "admin", "region"]:
		if properties.has(key):
			var value := str(properties[key]).strip_edges()
			if not value.is_empty():
				return value
	return ""


func _on_province_selected(index: int) -> void:
	if index <= 0:
		return
	var record_index := int(province_select.get_item_metadata(index))
	if record_index < 0 or record_index >= state_records.size():
		return
	var record: Dictionary = state_records[record_index]
	var center: Vector2 = record["center"]
	_focus_geo(center, 1.78)
	_update_state_marker(str(record["name"]), center)
	_request_detail_map(record["bounds"])
	status_label.text = "%s  /  %s" % [selected_country_name.to_upper(), str(record["name"]).to_upper()]


func _focus_geo(center: Vector2, distance: float) -> void:
	var direction := _geo_to_sphere(center.x, center.y, 1.0).normalized()
	planet_root.rotation = Quaternion(direction, Vector3.BACK).get_euler()
	target_distance = clampf(distance, MIN_DISTANCE, MAX_DISTANCE)


func _update_state_marker(label_text: String, center: Vector2) -> void:
	if is_instance_valid(selected_state_marker):
		selected_state_marker.queue_free()
	selected_state_marker = Label3D.new()
	selected_state_marker.name = "SelectedAdministrativeLabel"
	selected_state_marker.text = label_text.to_upper()
	selected_state_marker.font_size = 25
	selected_state_marker.pixel_size = 0.003
	selected_state_marker.outline_size = 5
	selected_state_marker.modulate = Color("#E8F4FF")
	selected_state_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	selected_state_marker.position = _geo_to_sphere(center.x, center.y, 1.026)
	planet_root.add_child(selected_state_marker)


func _clear_boundaries() -> void:
	for node in boundary_nodes:
		if is_instance_valid(node):
			node.queue_free()
	boundary_nodes.clear()
	if is_instance_valid(detail_patch):
		detail_patch.queue_free()
	detail_patch = null
	if is_instance_valid(selected_state_marker):
		selected_state_marker.queue_free()
	selected_state_marker = null
	state_records.clear()


func _add_boundary_mesh(geojson: Dictionary, color: Color, radius: float, node_name: String) -> void:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = color
	line_material.emission_enabled = true
	line_material.emission = color
	line_material.emission_energy_multiplier = 0.7
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
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(instance)
	boundary_nodes.append(instance)


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


func _geojson_stats(geojson: Dictionary) -> Dictionary:
	var all_points: Array[Vector2] = []
	var features: Array = geojson.get("features", [])
	for feature in features:
		if feature is Dictionary:
			_collect_coordinates(feature.get("geometry", {}).get("coordinates", []), all_points)
	return _points_stats(all_points)


func _geometry_stats(coordinates: Variant) -> Dictionary:
	var points: Array[Vector2] = []
	_collect_coordinates(coordinates, points)
	return _points_stats(points)


func _collect_coordinates(value: Variant, output: Array[Vector2]) -> void:
	if not value is Array:
		return
	var array_value: Array = value
	if array_value.size() >= 2 and typeof(array_value[0]) in [TYPE_FLOAT, TYPE_INT] and typeof(array_value[1]) in [TYPE_FLOAT, TYPE_INT]:
		output.append(Vector2(float(array_value[0]), float(array_value[1])))
		return
	for item in array_value:
		_collect_coordinates(item, output)


func _points_stats(points: Array[Vector2]) -> Dictionary:
	if points.is_empty():
		return {}
	var min_lon := 180.0
	var max_lon := -180.0
	var min_lat := 90.0
	var max_lat := -90.0
	var center := Vector2.ZERO
	for point in points:
		min_lon = minf(min_lon, point.x)
		max_lon = maxf(max_lon, point.x)
		min_lat = minf(min_lat, point.y)
		max_lat = maxf(max_lat, point.y)
		center += point
	center /= float(points.size())
	var padding_lon := maxf((max_lon - min_lon) * 0.08, 0.15)
	var padding_lat := maxf((max_lat - min_lat) * 0.08, 0.15)
	return {
		"center": center,
		"west": maxf(-180.0, min_lon - padding_lon),
		"east": minf(180.0, max_lon + padding_lon),
		"south": maxf(-89.0, min_lat - padding_lat),
		"north": minf(89.0, max_lat + padding_lat)
	}


func _request_detail_map(bounds: Dictionary) -> void:
	if bounds.is_empty():
		return
	var west := float(bounds.get("west", -180.0))
	var east := float(bounds.get("east", 180.0))
	var south := float(bounds.get("south", -80.0))
	var north := float(bounds.get("north", 80.0))
	if east - west < 0.1 or north - south < 0.1:
		return
	var width := 1280
	var height := clampi(int(float(width) * (north - south) / (east - west)), 256, 1600)
	var bbox := "%.5f,%.5f,%.5f,%.5f" % [west, south, east, north]
	var url := NASA_WMS_ROOT + "?service=WMS&request=GetMap&version=1.1.1&layers=BlueMarble_ShadedRelief_Bathymetry&styles=&format=image/jpeg&srs=EPSG:4326&bbox=" + bbox + "&width=%d&height=%d" % [width, height]
	var cache_key := selected_country_iso + "_" + str(roundi(west * 10.0)) + "_" + str(roundi(south * 10.0)) + "_" + str(roundi(east * 10.0)) + "_" + str(roundi(north * 10.0))
	var cache_path := CACHE_ROOT + "/detail_" + cache_key + ".jpg"
	_request_bytes(url, cache_path, 12 * 1024 * 1024, func(result: int, response_code: int, body: PackedByteArray) -> void:
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			return
		var image := Image.new()
		if image.load_jpg_from_buffer(body) != OK:
			return
		_apply_detail_patch(image, west, east, south, north)
	)


func _apply_detail_patch(image: Image, west: float, east: float, south: float, north: float) -> void:
	if is_instance_valid(detail_patch):
		detail_patch.queue_free()
	var detail_mesh := _build_geo_patch(west, east, south, north, 1.0045, 32, 20)
	detail_patch = MeshInstance3D.new()
	detail_patch.name = "ZoomedSatelliteDetail"
	detail_patch.mesh = detail_mesh
	var detail_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = PATCH_SHADER
	detail_material.shader = shader
	detail_material.set_shader_parameter("detail_map", ImageTexture.create_from_image(image))
	detail_patch.material_override = detail_material
	detail_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	planet_root.add_child(detail_patch)


func _build_geo_patch(west: float, east: float, south: float, north: float, radius: float, x_segments: int, y_segments: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(y_segments):
		var v0 := float(y) / float(y_segments)
		var v1 := float(y + 1) / float(y_segments)
		var lat0 := lerpf(north, south, v0)
		var lat1 := lerpf(north, south, v1)
		for x in range(x_segments):
			var u0 := float(x) / float(x_segments)
			var u1 := float(x + 1) / float(x_segments)
			var lon0 := lerpf(west, east, u0)
			var lon1 := lerpf(west, east, u1)
			var p00 := _geo_to_sphere(lon0, lat0, radius)
			var p01 := _geo_to_sphere(lon1, lat0, radius)
			var p10 := _geo_to_sphere(lon0, lat1, radius)
			var p11 := _geo_to_sphere(lon1, lat1, radius)
			_add_surface_vertex(surface, p00, Vector2(u0, v0))
			_add_surface_vertex(surface, p10, Vector2(u0, v1))
			_add_surface_vertex(surface, p01, Vector2(u1, v0))
			_add_surface_vertex(surface, p01, Vector2(u1, v0))
			_add_surface_vertex(surface, p10, Vector2(u0, v1))
			_add_surface_vertex(surface, p11, Vector2(u1, v1))
	surface.index()
	return surface.commit()


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
