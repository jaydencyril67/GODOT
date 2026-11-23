extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const GlobeScene: PackedScene = preload("res://scenes/world_globe.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var globe := GlobeScene.instantiate() as Node3D
	root.add_child(globe)
	await process_frame
	print("WORLD_GLOBE_SMOKE: globe scene instantiated")

	var earth := globe.find_child("Earth_Surface", true, false) as MeshInstance3D
	var camera := globe.find_child("Globe_Camera", true, false) as Camera3D
	var back_button := globe.find_child("Globe_Back_Button", true, false) as Button
	if earth == null or earth.mesh == null:
		_fail("The standalone globe scene did not create its Earth sphere.")
		return
	if camera == null or not camera.current:
		_fail("The globe scene did not activate its own camera.")
		return
	if back_button == null:
		_fail("The globe scene is missing its back-to-menu control.")
		return
	var earth_material := earth.material_override as StandardMaterial3D
	if earth_material == null or earth_material.albedo_texture == null:
		_fail("The NASA Blue Marble Earth surface texture did not import or load.")
		return
	if earth_material.albedo_texture.get_width() < 2048 or earth_material.albedo_texture.get_height() < 1024:
		_fail("The Earth surface texture is below the required 2K equirectangular resolution.")
		return
	print("WORLD_GLOBE_SMOKE: waiting for initial country geometry")
	var country_layer_ready := await _wait_for_country_layer(globe, "50m", 15.0)
	print("WORLD_GLOBE_SMOKE: initial country geometry wait finished")
	var country_borders := globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
	if not country_layer_ready or country_borders == null or country_borders.mesh == null or country_borders.mesh.get_surface_count() == 0 or not country_borders.visible:
		_fail("The base country dataset must load and remain visible when the globe first opens.")
		return
	var country_labels := globe.get("country_labels") as Array
	if country_labels.size() < 150:
		_fail("The initial country dataset did not create the expected country label set.")
		return

	# Country taps should open a research-style directory without adding
	# subdivision boundary meshes to the globe.
	var nigeria: Dictionary = globe.call("_find_country_feature_at", 9.0, 8.0)
	if nigeria.is_empty() or str(nigeria.get("n", "")) != "Nigeria":
		_fail("Country coordinate hit-testing did not identify Nigeria.")
		return
	print("WORLD_GLOBE_SMOKE: opening Nigeria subdivision directory")
	await globe.call("_open_country_subdivision_overlay", nigeria)
	print("WORLD_GLOBE_SMOKE: Nigeria subdivision directory loaded")
	var subdivision_overlay := globe.find_child("Country_Subdivision_Overlay", true, false) as CanvasLayer
	var subdivision_entries: Array = globe.get("_selected_subdivision_entries")
	if subdivision_overlay == null or subdivision_entries.size() < 30:
		_fail("Selecting Nigeria did not show its complete state/province directory.")
		return
	if globe.find_child("Country_Subdivision_Search", true, false) == null:
		_fail("The country subdivision overlay is missing its directory search field.")
		return
	globe.call("_close_country_subdivision_overlay")
	await process_frame
	if globe.find_child("Country_Subdivision_Overlay", true, false) != null:
		_fail("The country subdivision overlay did not close cleanly.")
		return
	var equator_west: Vector3 = globe.call("_geo_to_globe_position", 0.0, -180.0, 1.0)
	var equator_east: Vector3 = globe.call("_geo_to_globe_position", 0.0, 0.0, 1.0)
	if equator_west.distance_to(Vector3(0.0, 0.0, 1.0)) > 0.001 or equator_east.distance_to(Vector3(0.0, 0.0, -1.0)) > 0.001:
		_fail("Geographic longitude registration does not match the equirectangular Earth texture seam.")
		return
	globe.call("zoom_globe", -0.6)
	print("WORLD_GLOBE_SMOKE: checking country zoom")
	if not await _wait_for_zoom_settled(globe, 4.3, 5.0):
		_fail("The eased globe camera did not settle at country zoom.")
		return
	country_layer_ready = await _wait_for_country_layer(globe, "50m", 15.0)
	country_borders = globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
	country_labels = globe.get("country_labels") as Array
	if not country_layer_ready or country_borders == null or country_borders.mesh == null or country_borders.mesh.get_surface_count() == 0 or not country_borders.visible:
		_fail("Country boundary geometry must load and become visible at country zoom.")
		return
	if country_labels.size() < 150:
		_fail("The Natural Earth country label layer did not load the expected country set.")
		return
	var country_zoom_visible_count := 0
	for label_variant in country_labels:
		var country_label := label_variant as Label3D
		if country_label != null and country_label.visible:
			country_zoom_visible_count += 1
	if country_zoom_visible_count == 0 or country_zoom_visible_count >= country_labels.size():
		_fail("Country zoom must reveal only priority country names.")
		return
	globe.call("zoom_globe", -0.9)
	print("WORLD_GLOBE_SMOKE: checking close country zoom")
	if not await _wait_for_zoom_settled(globe, 3.4, 5.0):
		_fail("The eased globe camera did not settle at close country zoom.")
		return
	var detailed_country_layer_ready := await _wait_for_country_layer(globe, "50m", 15.0)
	country_borders = globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
	country_labels = globe.get("country_labels") as Array
	if not detailed_country_layer_ready or country_borders == null or str(country_borders.get_meta("geographic_resolution", "")) != "50m":
		_fail("Close country zoom must retain the mobile-friendly 1:50m Admin-0 dataset.")
		return
	var close_visible_count := 0
	for label_variant in country_labels:
		var country_label := label_variant as Label3D
		if country_label != null and country_label.visible:
			close_visible_count += 1
	if close_visible_count <= country_zoom_visible_count:
		_fail("Zooming closer must progressively reveal more country names.")
		return
	globe.call("zoom_globe", -0.3)
	var export_config := FileAccess.get_file_as_string("res://export_presets.cfg")
	if not export_config.contains("*.json"):
		_fail("Android exports must include the compressed country geography assets.")
		return
	if globe.find_child("State_Province_Boundaries", true, false) != null:
		_fail("The globe must remain country-only; state/province boundary nodes are not permitted.")
		return
	country_borders = globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
	country_labels = globe.get("country_labels") as Array
	var clouds := globe.find_child("Earth_Cloud_Layer", true, false) as MeshInstance3D
	if clouds == null or clouds.material_override == null:
		_fail("The separate NASA cloud layer was not created.")
		return
	var cloud_material := clouds.material_override as ShaderMaterial
	if cloud_material == null or cloud_material.get_shader_parameter("cloud_texture") == null:
		_fail("The NASA cloud texture was not assigned to the cloud shader.")
		return

	print("WORLD_GLOBE_SMOKE: checking rotation and zoom controls")
	var rotation_target_before: Quaternion = globe.get("_rotation_target")
	globe.call("rotate_globe", Vector2(18.0, 12.0))
	var rotation_target_after: Quaternion = globe.get("_rotation_target")
	if absf(rotation_target_after.dot(rotation_target_before)) >= 0.999999:
		_fail("A drag must change the globe's full 3D quaternion orientation.")
		return
	if not is_equal_approx(rotation_target_after.length(), 1.0):
		_fail("Globe trackball orientation must remain a normalized quaternion.")
		return
	globe.call("_rotate_globe_from_points", Vector2(300.0, 300.0), Vector2(350.0, 320.0))
	var trackball_rotation: Quaternion = globe.get("_rotation_target")
	if absf(trackball_rotation.dot(rotation_target_after)) >= 0.999999:
		_fail("Position-based virtual trackball input did not rotate the Earth.")
		return

	# Raw pointer events are filtered at frame cadence, and a single frame is
	# prevented from consuming an arbitrarily large input jump.
	var pointer_start := Vector2(300.0, 300.0)
	var pointer_target := Vector2(380.0, 300.0)
	globe.set("_rotation_pointer_position", pointer_start)
	globe.set("_rotation_pointer_target", pointer_target)
	globe.set("_rotation_drag_active", true)
	globe.call("_update_drag_rotation", 1.0 / 60.0)
	var filtered_pointer: Vector2 = globe.get("_rotation_pointer_position")
	if filtered_pointer.distance_to(pointer_start) <= 0.0 or filtered_pointer.distance_to(pointer_target) <= 0.0:
		_fail("Globe drag input must be progressively filtered rather than snapping to each raw touch event.")
		return
	if filtered_pointer.distance_to(pointer_start) > 28.0:
		_fail("A single globe rotation frame exceeded the maximum filtered pointer step.")
		return
	globe.set("_rotation_drag_active", false)
	var stopped_pointer: Vector2 = globe.get("_rotation_pointer_position")
	globe.call("_update_drag_rotation", 1.0 / 60.0)
	var stopped_pointer_after: Vector2 = globe.get("_rotation_pointer_position")
	if stopped_pointer_after != stopped_pointer:
		_fail("Globe rotation input must stop immediately when dragging ends.")
		return

	var initial_zoom := float(globe.call("get_zoom_distance"))
	globe.call("zoom_globe", -0.5)
	if float(globe.get("_zoom_target_distance")) >= initial_zoom:
		_fail("The globe zoom method did not move the camera closer.")
		return
	if not float(globe.get("_zoom_distance")) > float(globe.get("_zoom_target_distance")):
		_fail("Globe zoom must ease toward its target instead of jumping instantly.")
		return
	globe.call("zoom_globe", -100.0)
	var closest_zoom := float(globe.get("_zoom_target_distance"))
	if not is_equal_approx(closest_zoom, 1.9):
		_fail("The close zoom limit must allow a detailed country-level view.")
		return
	globe.call("zoom_globe", 100.0)
	var farthest_zoom := float(globe.get("_zoom_target_distance"))
	if not is_equal_approx(farthest_zoom, 7.2):
		_fail("The far zoom limit must keep the Earth comfortably large on screen.")
		return
	# ImmediateMesh does not expose a surface primitive-type getter in Godot 4.7.
	# The globe builder explicitly creates its boundary ribbons with TRIANGLES;
	# validate the resulting shaded material and cartographic metadata below.
	var border_material := country_borders.mesh.surface_get_material(0) as StandardMaterial3D
	if border_material == null or border_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		_fail("Country boundaries must be shaded and integrated with the Earth surface, not bright unshaded strokes.")
		return
	if absf(border_material.albedo_color.r - border_material.albedo_color.g) > 0.08 or border_material.albedo_color.b < border_material.albedo_color.g:
		_fail("Country boundaries must use the restrained cool-grey Google Earth inspired palette.")
		return
	if not str(country_borders.get_meta("cartographic_style", "")).begins_with("subtle_google_earth_inspired_admin0"):
		_fail("The country boundary layer is missing its intended cartographic style metadata.")
		return
	if float(country_borders.get_meta("surface_radius", 0.0)) > 1.603:
		_fail("Country boundaries are floating too far above the Earth surface.")
		return
	if country_labels.is_empty() or (country_labels[0] as Label3D).font_size > 44:
		_fail("Country names must use the quieter, smaller geographic label treatment.")
		return

	globe.queue_free()
	await process_frame

	print("WORLD_GLOBE_SMOKE: globe checks passed; checking landing navigation")
	var game := MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(1.25).timeout
	var explore_button := game.find_child("Landing_Explore_World_Button", true, false) as Button
	if explore_button == null:
		_fail("The landing page is missing its Explore World button.")
		return
	explore_button.pressed.emit()
	await process_frame
	if str(game.get("current_screen")) != "globe" or game.get("globe_world") == null:
		_fail("The landing-page Explore World button did not open the separate globe scene.")
		return
	var opened_globe := game.get("globe_world") as Node3D
	opened_globe.call("emit_signal", "back_requested")
	await process_frame
	if str(game.get("current_screen")) != "menu" or game.get("landing_world") == null:
		_fail("The globe back control did not restore the landing page.")
		return

	game.queue_free()
	await process_frame
	print("WORLD_GLOBE_SMOKE: landing navigation checks passed")
	print("WORLD_GLOBE_NAVIGATION_SMOKE_TEST: PASS")
	quit()


func _wait_for_country_layer(globe: Node3D, expected_tier: String, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		await create_timer(0.1).timeout
		elapsed += 0.1
		var layer := globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
		if layer != null and layer.mesh != null and layer.mesh.get_surface_count() > 0 and layer.visible:
			if str(layer.get_meta("geographic_resolution", "")) == expected_tier:
				return true
	return false


func _wait_for_zoom_settled(globe: Node3D, expected_distance: float, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		await create_timer(0.05).timeout
		elapsed += 0.05
		var current_distance := float(globe.call("get_zoom_distance"))
		var target_distance := float(globe.get("_zoom_target_distance"))
		if absf(current_distance - expected_distance) < 0.002 and absf(current_distance - target_distance) < 0.002:
			return true
	return false

func _wait_for_state_layer(globe: Node3D, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		await create_timer(0.1).timeout
		elapsed += 0.1
		var layer := globe.find_child("State_Province_Boundaries", true, false) as MeshInstance3D
		if layer != null and layer.mesh != null and layer.mesh.get_surface_count() > 0 and layer.visible:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	print("WORLD_GLOBE_NAVIGATION_SMOKE_TEST: FAIL: " + message)
	quit(1)
