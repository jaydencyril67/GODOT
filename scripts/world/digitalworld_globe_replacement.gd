extends "res://scripts/world/digitalworld_globe.gd"
## Android replacement globe powered by the pinned godot-3dtiles GDExtension.
## The legacy globe remains the editor fallback until the Android extension is packaged.

const EXTENSION_PATH := "res://addons/godot-3dtiles.gdextension"
const IMAGERY_URL := "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
const WGS84_EQUATORIAL_RADIUS := 6378137.0
const WGS84_POLAR_RADIUS := 6356752.314245
const COUNTRY_RADIUS_SCALE := WGS84_EQUATORIAL_RADIUS / EARTH_RADIUS

var _native_globe_ready := false
var _native_camera: Camera3D
var _native_georeference: Node3D
var _native_imagery_layer: Node3D
var _native_globe: Node3D
var _tap_points: Dictionary = {}
var _tap_eligible: Dictionary = {}
var _mouse_tap_position := Vector2.ZERO
var _mouse_tap_active := false


func _ready() -> void:
	_native_globe_ready = _load_native_extension()
	if not _native_globe_ready:
		_debug_load_stage = "Native globe unavailable; using legacy editor fallback"
	super._ready()
	if _native_globe_ready:
		_zoom_distance = 3.7
		_update_country_label_visibility()


func _load_native_extension() -> bool:
	if ClassDB.class_exists("Globe3D") and ClassDB.class_exists("GlobeCameraController"):
		return true
	if not FileAccess.file_exists(EXTENSION_PATH):
		return false
	var result := GDExtensionManager.load_extension(EXTENSION_PATH)
	if result != GDExtensionManager.LOAD_STATUS_OK and not ClassDB.class_exists("Globe3D"):
		push_warning("Android globe extension could not be loaded: %s" % str(result))
		return false
	return ClassDB.class_exists("Globe3D") and ClassDB.class_exists("GlobeTileLayer") and ClassDB.class_exists("GlobeCameraController") and ClassDB.class_exists("Georeference3D") and ClassDB.class_exists("EarthCenteredEarthFixed")


func _build_earth() -> void:
	if not _native_globe_ready:
		super._build_earth()
		return

	# Anchor the engine's ENU frame at the equator. The native controller can then
	# rebase this shared frame around the camera without losing country overlays.
	var origin := ClassDB.instantiate("EarthCenteredEarthFixed") as Resource
	origin.set("ecef_x", WGS84_EQUATORIAL_RADIUS)
	origin.set("ecef_y", 0.0)
	origin.set("ecef_z", 0.0)
	_native_georeference = ClassDB.instantiate("Georeference3D") as Node3D
	_native_georeference.name = "Earth_Georeference"
	_native_georeference.set("origin_authority", origin)
	_native_georeference.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(_native_georeference)

	earth_pivot = Node3D.new()
	earth_pivot.name = "Earth_Geography_Pivot"
	_native_georeference.add_child(earth_pivot)

	_native_globe = ClassDB.instantiate("Globe3D") as Node3D
	_native_globe.name = "WGS84_Globe"
	_native_globe.set("radial_segments", 192)
	_native_globe.set("rings", 96)
	_native_globe.set("albedo_texture", EARTH_TEXTURE)
	_native_globe.set("show_graticule", false)
	_native_globe.set("show_atmosphere", true)
	_native_globe.set("atmosphere_intensity", 48.0)
	_native_globe.set("atmosphere_color", Color("#79b9ff"))
	_native_georeference.add_child(_native_globe)

	_native_imagery_layer = ClassDB.instantiate("GlobeTileLayer") as Node3D
	_native_imagery_layer.name = "Satellite_Imagery_Tiles"
	_native_imagery_layer.set("url_template", IMAGERY_URL)
	_native_imagery_layer.set("maximum_screen_space_error", 3.5)
	_native_imagery_layer.set("maximum_level", 16)
	_native_imagery_layer.set("tile_cache_size", 180)
	_native_imagery_layer.set("max_concurrent_requests", 4)
	_native_imagery_layer.set("attribution", "Esri, Maxar, Earthstar Geographics, and the GIS User Community")
	_native_imagery_layer.set("print_telemetry", false)
	_native_imagery_layer.set("show_tile_bounds", false)
	_native_georeference.add_child(_native_imagery_layer)

func _build_interface() -> void:
	super._build_interface()
	if not _native_globe_ready:
		return
	var root := get_node_or_null("Globe_Interface/Globe_Interface_Root") as Control
	if root == null:
		return
	var attribution := Label.new()
	attribution.name = "Satellite_Imagery_Attribution"
	attribution.text = "Satellite imagery © Esri, Maxar, Earthstar Geographics, and the GIS User Community"
	attribution.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	attribution.offset_left = 12.0
	attribution.offset_top = -28.0
	attribution.offset_right = 520.0
	attribution.offset_bottom = -8.0
	attribution.add_theme_font_size_override("font_size", 10)
	attribution.add_theme_color_override("font_color", Color("#d5deea"))
	attribution.add_theme_color_override("font_shadow_color", Color("#06101c"))
	attribution.add_theme_constant_override("shadow_offset_x", 1)
	attribution.add_theme_constant_override("shadow_offset_y", 1)
	attribution.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(attribution)


func _build_camera() -> void:
	if not _native_globe_ready:
		super._build_camera()
		return
	_native_camera = ClassDB.instantiate("GlobeCameraController") as Camera3D
	_native_camera.name = "Globe_Camera_Controller"
	_native_camera.fov = 45.0
	_native_camera.set("inertia_enabled", false)
	_native_camera.set("rotate_speed_scale", 0.72)
	_native_camera.set("zoom_speed_scale", 0.62)
	_native_camera.set("manage_clip", true)
	add_child(_native_camera)
	_native_camera.current = true
	_native_camera.call("orbit_to", 0.0, 18.0, 18000000.0)
	globe_camera = _native_camera


func _process(delta: float) -> void:
	if not _native_globe_ready:
		super._process(delta)
		return
	if is_instance_valid(_native_camera):
		_zoom_distance = clampf(float(_native_camera.call("get_distance")) / WGS84_EQUATORIAL_RADIUS, ZOOM_MIN, ZOOM_MAX)
		for label in country_labels:
			if is_instance_valid(label):
				var label_scale := COUNTRY_RADIUS_SCALE
				label.scale = Vector3.ONE * label_scale
	_update_country_label_visibility()


func _input(event: InputEvent) -> void:
	if not _native_globe_ready or is_instance_valid(_country_subdivision_overlay):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_tap_points[touch.index] = touch.position
			_tap_eligible[touch.index] = true
			if _tap_points.size() > 1:
				for key in _tap_eligible.keys():
					_tap_eligible[key] = false
		else:
			var is_tap := _tap_points.size() == 1 and bool(_tap_eligible.get(touch.index, false))
			_tap_points.erase(touch.index)
			_tap_eligible.erase(touch.index)
			if is_tap and _tap_is_on_globe(touch.position):
				call_deferred("_select_country_at_screen_position", touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _tap_points.has(drag.index) and _tap_points[drag.index].distance_to(drag.position) > COUNTRY_TAP_DRAG_THRESHOLD:
			_tap_eligible[drag.index] = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_tap_active = true
			_mouse_tap_position = event.position
		else:
			var is_tap := _mouse_tap_active and _mouse_tap_position.distance_to(event.position) <= COUNTRY_TAP_DRAG_THRESHOLD
			_mouse_tap_active = false
			if is_tap and _tap_is_on_globe(event.position):
				call_deferred("_select_country_at_screen_position", event.position)
	elif event is InputEventMouseMotion and _mouse_tap_active:
		if _mouse_tap_position.distance_to(event.position) > COUNTRY_TAP_DRAG_THRESHOLD:
			_mouse_tap_active = false


func _tap_is_on_globe(screen_position: Vector2) -> bool:
	if screen_position.y < 82.0 and screen_position.x < 220.0:
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _native_globe_ready or is_instance_valid(_country_subdivision_overlay):
		super._unhandled_input(event)


func _screen_to_globe_coordinates(screen_position: Vector2) -> Vector2:
	if not _native_globe_ready or not is_instance_valid(_native_camera):
		return super._screen_to_globe_coordinates(screen_position)
	var ray_origin := _native_camera.project_ray_origin(screen_position)
	var ray_direction := _native_camera.project_ray_normal(screen_position).normalized()
	var centre: Vector3 = _native_camera.call("resolve_ellipsoid_center")
	var relative_origin := ray_origin - centre
	# With the georeference's ENU frame, the polar axis maps to world -Z.
	var inv_a2 := 1.0 / (WGS84_EQUATORIAL_RADIUS * WGS84_EQUATORIAL_RADIUS)
	var inv_b2 := 1.0 / (WGS84_POLAR_RADIUS * WGS84_POLAR_RADIUS)
	var qa := (ray_direction.x * ray_direction.x + ray_direction.y * ray_direction.y) * inv_a2 + ray_direction.z * ray_direction.z * inv_b2
	var qb := 2.0 * ((relative_origin.x * ray_direction.x + relative_origin.y * ray_direction.y) * inv_a2 + relative_origin.z * ray_direction.z * inv_b2)
	var qc := (relative_origin.x * relative_origin.x + relative_origin.y * relative_origin.y) * inv_a2 + relative_origin.z * relative_origin.z * inv_b2 - 1.0
	var discriminant := qb * qb - 4.0 * qa * qc
	if discriminant < 0.0:
		return Vector2(999.0, 999.0)
	var hit_distance := (-qb - sqrt(discriminant)) / (2.0 * qa)
	if hit_distance < 0.0:
		hit_distance = (-qb + sqrt(discriminant)) / (2.0 * qa)
	if hit_distance < 0.0:
		return Vector2(999.0, 999.0)
	var hit := relative_origin + ray_direction * hit_distance
	var latitude := rad_to_deg(atan2(-hit.z * inv_b2, Vector2(hit.x, hit.y).length() * inv_a2))
	var longitude := wrapf(rad_to_deg(atan2(hit.x, hit.y)), -180.0, 180.0)
	return Vector2(latitude, longitude)

func _geo_to_globe_position(latitude: float, longitude: float, radius: float) -> Vector3:
	if not _native_globe_ready:
		return super._geo_to_globe_position(latitude, longitude, radius)
	var lat := deg_to_rad(clampf(latitude, -90.0, 90.0))
	var lon := deg_to_rad(wrapf(longitude, -180.0, 180.0))
	var adjusted_radius := EARTH_RADIUS + (radius - EARTH_RADIUS) * 0.02
	var scale_factor := adjusted_radius / EARTH_RADIUS
	var horizontal := WGS84_EQUATORIAL_RADIUS * scale_factor * cos(lat)
	# Local ENU coordinates for an origin at (WGS84_A, 0, 0).
	return Vector3(
		horizontal * sin(lon),
		WGS84_POLAR_RADIUS * scale_factor * sin(lat),
		horizontal * cos(lon) - WGS84_EQUATORIAL_RADIUS
	)

func _append_geographic_segment(mesh: ImmediateMesh, latitude_a: float, longitude_a: float, latitude_b: float, longitude_b: float, radius: float) -> void:
	if not _native_globe_ready:
		super._append_geographic_segment(mesh, latitude_a, longitude_a, latitude_b, longitude_b, radius)
		return
	var a := _geo_to_globe_position(latitude_a, longitude_a, radius)
	var b := _geo_to_globe_position(latitude_b, longitude_b, radius)
	var lat_a := deg_to_rad(latitude_a)
	var lon_a := deg_to_rad(longitude_a)
	var lat_b := deg_to_rad(latitude_b)
	var lon_b := deg_to_rad(longitude_b)
	var normal_a := Vector3(cos(lat_a) * sin(lon_a), sin(lat_a), cos(lat_a) * cos(lon_a)).normalized()
	var normal_b := Vector3(cos(lat_b) * sin(lon_b), sin(lat_b), cos(lat_b) * cos(lon_b)).normalized()
	var tangent := b - a
	if tangent.length_squared() < 0.01:
		return
	tangent = tangent.normalized()
	var side_a := tangent.cross(normal_a).normalized() * 2800.0
	var side_b := tangent.cross(normal_b).normalized() * 2800.0
	mesh.surface_set_normal(normal_a)
	mesh.surface_add_vertex(a + side_a)
	mesh.surface_set_normal(normal_a)
	mesh.surface_add_vertex(a - side_a)
	mesh.surface_set_normal(normal_b)
	mesh.surface_add_vertex(b + side_b)
	mesh.surface_set_normal(normal_b)
	mesh.surface_add_vertex(b + side_b)
	mesh.surface_set_normal(normal_a)
	mesh.surface_add_vertex(a - side_a)
	mesh.surface_set_normal(normal_b)
	mesh.surface_add_vertex(b - side_b)

func _update_country_label_visibility() -> void:
	if not _native_globe_ready:
		super._update_country_label_visibility()
		return
	var height := 10000000.0
	if is_instance_valid(_native_camera):
		height = float(_native_camera.call("camera_height_above_ellipsoid"))
	var max_rank := 2 if height < 22000000.0 else -1
	if height < 9000000.0:
		max_rank = 4
	if height < 3500000.0:
		max_rank = 7
	for label in country_labels:
		if is_instance_valid(label):
			label.visible = max_rank >= 0 and int(label.get_meta("natural_earth_label_rank", 5)) <= max_rank


func zoom_globe(distance_delta: float) -> void:
	if not _native_globe_ready or not is_instance_valid(_native_camera):
		super.zoom_globe(distance_delta)
		return
	var current_distance := float(_native_camera.call("get_distance"))
	var next_distance := current_distance * exp(distance_delta * 0.42)
	_native_camera.call("set_distance", next_distance)
	_zoom_distance = clampf(next_distance / WGS84_EQUATORIAL_RADIUS, ZOOM_MIN, ZOOM_MAX)
	_update_country_label_visibility()


func get_zoom_distance() -> float:
	if _native_globe_ready and is_instance_valid(_native_camera):
		return clampf(float(_native_camera.call("get_distance")) / WGS84_EQUATORIAL_RADIUS, ZOOM_MIN, ZOOM_MAX)
	return super.get_zoom_distance()
