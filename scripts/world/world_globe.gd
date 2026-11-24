extends Node3D

signal back_requested

const RADIUS := 1.0
const START_DISTANCE := 3.65
const MIN_DISTANCE := 1.42
const MAX_DISTANCE := 7.0
const PROVINCE_ZOOM_DISTANCE := 2.35
const GEOBOUNDARIES_ROOT := "https://www.geoboundaries.org/api/current/gbOpen"
const COUNTRY_BOUNDARIES_URL := "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
const NASA_WMS_ROOT := "https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi"
const OVERVIEW_URL := NASA_WMS_ROOT + "?service=WMS&request=GetMap&version=1.1.1&layers=BlueMarble_ShadedRelief_Bathymetry&styles=default&format=image/jpeg&srs=EPSG:4326&bbox=-180,-90,180,90&width=2048&height=1024&time=default"
const CACHE_ROOT := "user://digitalworld/globe"

const EARTH_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D earth_map : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	vec3 surface = texture(earth_map, UV).rgb;
	ALBEDO = surface;
	ROUGHNESS = 0.88;
	SPECULAR = 0.12;
	EMISSION = surface * 0.035;
}
"""

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
	ALPHA = cloud * 0.13;
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
var earth_material: ShaderMaterial
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
var province_boundary_nodes: Array[MeshInstance3D] = []
var focused_country_iso := ""
var focused_country_name := ""
var region_request_generation := 0
var region_check_elapsed := 0.0
var status_label: Label
var overview_texture: Texture2D


func _ready() -> void:
	_build_space_environment()
	_build_planet()
	_build_interface()
	_load_overview_map()
	_load_country_boundaries()
	set_process(true)


func _process(delta: float) -> void:
	if not dragging:
		planet_root.rotate_y(delta * 0.012)
	camera.position.z = lerpf(camera.position.z, target_distance, minf(delta * 5.0, 1.0))
	camera.look_at(Vector3.ZERO, Vector3.UP)
	region_check_elapsed += delta
	if region_check_elapsed >= 0.28:
		region_check_elapsed = 0.0
		_update_administrative_layers()


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
	if not _is_province_zoom_active():
		for node in province_boundary_nodes:
			if is_instance_valid(node):
				node.visible = false


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
	cloud_noise.frequency = 0.9
	cloud_noise.fractal_octaves = 5
	cloud_noise.fractal_gain = 0.50
	var noise_texture := NoiseTexture2D.new()
	noise_texture.width = 1024
	noise_texture.height = 512
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
	attribution.text = "NASA Blue Marble imagery  ·  Country outlines: Natural Earth  ·  Regional boundaries: geoBoundaries (CC BY 4.0)"
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
		if cached_image != null and not cached_image.is_empty() and _apply_overview_image(cached_image):
			status_label.text = "CACHED EARTH IMAGERY  ·  CHECKING FOR AN UPDATE"
	_request_bytes(OVERVIEW_URL, cache_path, 12 * 1024 * 1024, func(result: int, response_code: int, body: PackedByteArray) -> void:
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			if overview_texture == null:
				status_label.text = "NASA MAP UNAVAILABLE  ·  CHECK YOUR CONNECTION"
			return
		var image := Image.new()
		if image.load_jpg_from_buffer(body) != OK or image.get_width() < 512 or image.get_height() < 256:
			if overview_texture == null:
				status_label.text = "NASA MAP RESPONSE IS INVALID  ·  CHECK YOUR CONNECTION"
			return
		if not _apply_overview_image(image):
			if overview_texture == null:
				status_label.text = "NASA MAP COULD NOT BE APPLIED"
			return
		status_label.text = "NASA BLUE MARBLE  ·  DRAG TO ROTATE  ·  PINCH TO ZOOM"
	, true)


func _apply_overview_image(image: Image) -> bool:
	if image.is_empty() or image.get_width() < 512 or image.get_height() < 256:
		return false
	var prepared_image := image.duplicate()
	prepared_image.generate_mipmaps()
	overview_texture = ImageTexture.create_from_image(prepared_image)
	earth_material.set_shader_parameter("earth_map", overview_texture)
	return true


func _load_country_boundaries() -> void:
	country_boundaries_loading = true
	status_label.text = "LOADING WORLD COUNTRY BOUNDARIES…"
	var cache_path := CACHE_ROOT + "/natural_earth_admin0.geojson"
	_request_bytes(COUNTRY_BOUNDARIES_URL, cache_path, 12 * 1024 * 1024, _on_country_boundaries_loaded)


func _on_country_boundaries_loaded(result: int, response_code: int, body: PackedByteArray) -> void:
	country_boundaries_loading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "COUNTRY OUTLINES UNAVAILABLE  ·  CHECK YOUR CONNECTION"
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not _apply_country_boundaries(parsed):
		status_label.text = "COUNTRY OUTLINE DATA COULD NOT BE READ"
		return
	status_label.text = "%d COUNTRY OUTLINES  ·  ZOOM IN FOR STATES / PROVINCES" % country_features.size()


func _apply_country_boundaries(geojson: Dictionary) -> bool:
	var features: Variant = geojson.get("features", [])
	if not features is Array or features.is_empty():
		return false
	var next_node := _add_boundary_mesh(geojson, Color("#B9D9F6"), 1.006, "WorldCountryBoundaries")
	if next_node == null:
		return false
	if is_instance_valid(country_boundary_node):
		country_boundary_node.queue_free()
	country_boundary_node = next_node
	country_features = features
	country_boundaries_loaded = true
	return true


func _is_province_zoom_active() -> bool:
	return target_distance <= PROVINCE_ZOOM_DISTANCE


func _update_administrative_layers() -> void:
	var show_provinces := _is_province_zoom_active()
	for node in province_boundary_nodes:
		if is_instance_valid(node):
			node.visible = show_provinces
	if not show_provinces or not country_boundaries_loaded:
		return

	var feature := _find_country_at_front()
	if feature.is_empty():
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
	region_request_generation += 1
	var generation := region_request_generation
	_clear_province_boundaries()
	status_label.text = "LOADING %s STATES / PROVINCES…" % focused_country_name.to_upper()
	_request_country_provinces(iso, generation)


func _find_country_at_front() -> Dictionary:
	if country_features.is_empty() or not is_instance_valid(planet_root):
		return {}
	var local_direction := (planet_root.global_transform.basis.inverse() * Vector3.BACK).normalized()
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
			status_label.text = "%s REGIONAL DATA IS UNAVAILABLE" % focused_country_name.to_upper()
			return
		var metadata: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not metadata is Dictionary:
			status_label.text = "%s REGIONAL DATA COULD NOT BE READ" % focused_country_name.to_upper()
			return
		var geojson_url := str(metadata.get("simplifiedGeometryGeoJSON", metadata.get("gjDownloadURL", "")))
		if geojson_url.is_empty():
			status_label.text = "%s HAS NO PUBLISHED ADM1 DATASET" % focused_country_name.to_upper()
			return
		var geometry_cache := CACHE_ROOT + "/automatic_adm1_" + iso + "_geometry.json"
		_request_bytes(geojson_url, geometry_cache, 24 * 1024 * 1024, func(geo_result: int, geo_code: int, geo_body: PackedByteArray) -> void:
			if generation != region_request_generation or not _is_province_zoom_active():
				return
			if geo_result != HTTPRequest.RESULT_SUCCESS or geo_code != 200:
				status_label.text = "%s REGIONAL BOUNDARIES COULD NOT BE DOWNLOADED" % focused_country_name.to_upper()
				return
			var geojson: Variant = JSON.parse_string(geo_body.get_string_from_utf8())
			if not geojson is Dictionary:
				status_label.text = "%s REGIONAL DATA FORMAT IS INVALID" % focused_country_name.to_upper()
				return
			_apply_province_boundaries(geojson)
		)
	)


func _apply_province_boundaries(geojson: Dictionary) -> bool:
	var features: Variant = geojson.get("features", [])
	if not features is Array or features.is_empty():
		status_label.text = "%s HAS NO STATE / PROVINCE FEATURES" % focused_country_name.to_upper()
		return false
	var node := _add_boundary_mesh(geojson, Color("#73BDFF"), 1.009, "AutomaticStateProvinceBoundaries")
	if node == null:
		status_label.text = "%s REGIONAL OUTLINES COULD NOT BE DRAWN" % focused_country_name.to_upper()
		return false
	node.visible = _is_province_zoom_active()
	province_boundary_nodes.append(node)
	status_label.text = "%s  ·  %d STATES / PROVINCES" % [focused_country_name.to_upper(), features.size()]
	return true


func _clear_province_boundaries() -> void:
	for node in province_boundary_nodes:
		if is_instance_valid(node):
			node.queue_free()
	province_boundary_nodes.clear()


func _add_boundary_mesh(geojson: Dictionary, color: Color, radius: float, node_name: String) -> MeshInstance3D:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = color
	line_material.emission_enabled = true
	line_material.emission = color
	line_material.emission_energy_multiplier = 0.65
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
