extends SceneTree

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const GlobeScene: PackedScene = preload("res://scenes/world_globe.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var globe := GlobeScene.instantiate() as Node3D
	root.add_child(globe)
	await process_frame

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
	var country_borders := globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
	if country_borders != null:
		_fail("Country boundary geometry must remain unloaded at the far globe zoom.")
		return
	var country_labels := globe.get("country_labels") as Array
	if not country_labels.is_empty():
		_fail("Country labels must remain unloaded at the far globe zoom.")
		return
	var equator_west: Vector3 = globe.call("_geo_to_globe_position", 0.0, -180.0, 1.0)
	var equator_east: Vector3 = globe.call("_geo_to_globe_position", 0.0, 0.0, 1.0)
	if equator_west.distance_to(Vector3(0.0, 0.0, 1.0)) > 0.001 or equator_east.distance_to(Vector3(0.0, 0.0, -1.0)) > 0.001:
		_fail("Geographic longitude registration does not match the equirectangular Earth texture seam.")
		return
	globe.call("zoom_globe", -0.6)
	var country_layer_ready := await _wait_for_country_layer(globe, "50m", 15.0)
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
	var detailed_country_layer_ready := await _wait_for_country_layer(globe, "10m", 20.0)
	country_borders = globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
	country_labels = globe.get("country_labels") as Array
	if FileAccess.file_exists("res://assets/globe/natural_earth_countries_10m.json"):
		if not detailed_country_layer_ready or country_borders == null or str(country_borders.get_meta("geographic_resolution")) != "10m":
			_fail("Close country zoom must switch to the detailed 1:10m country dataset.")
			return
		if int(country_borders.get_meta("country_feature_count", 0)) < 250:
			_fail("The 1:10m country dataset did not load the expected global country set.")
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
	await _wait_for_state_layer(globe, 15.0)
	var export_config := FileAccess.get_file_as_string("res://export_presets.cfg")
	if not export_config.contains("*.json"):
		_fail("Android exports must include the compressed country and state geography assets.")
		return
	var state_layer := globe.find_child("State_Province_Boundaries", true, false) as MeshInstance3D
	var has_state_chunks := false
	for continent in ["africa", "asia", "europe", "north_america", "south_america", "oceania", "other"]:
		if FileAccess.file_exists("res://assets/globe/natural_earth_states_10m_" + continent + ".json"):
			has_state_chunks = true
			break
	if has_state_chunks and state_layer == null:
		_fail("The close zoom did not load the state/province chunk for the camera's continent.")
		return
	if state_layer != null:
		if state_layer.mesh == null or not state_layer.visible:
			_fail("State/province boundaries must load only at the close geographic zoom level.")
			return
		if str(state_layer.get_meta("continent")) != "antarctica" and int(state_layer.get_meta("state_feature_count", 0)) < 10:
			_fail("The selected Admin-1 continent chunk did not load state/province features.")
			return
		if str(state_layer.get_meta("geographic_resolution")) != "10m_admin1":
			_fail("The state/province layer is not using the 1:10m Admin-1 dataset.")
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

	var pivot := globe.get("earth_pivot") as Node3D
	var initial_rotation: Vector3 = pivot.rotation
	globe.call("rotate_globe", Vector2(18.0, 12.0))
	var horizontal_rotation: Vector3 = pivot.rotation
	if horizontal_rotation.y <= initial_rotation.y:
		_fail("Dragging right must rotate the globe in the same direction as the phone worksite.")
		return
	if not is_equal_approx(horizontal_rotation.x, initial_rotation.x):
		_fail("A diagonal drag must stay locked to its dominant horizontal axis.")
		return
	if not is_equal_approx(horizontal_rotation.y - initial_rotation.y, 18.0 * 0.0024):
		_fail("Globe drag sensitivity must match the phone worksite's stable rotation sensitivity.")
		return
	globe.call("rotate_globe", Vector2(0.0, 12.0))
	var vertical_rotation: Vector3 = pivot.rotation
	if vertical_rotation.x >= horizontal_rotation.x:
		_fail("Dragging down must move the visible globe surface downward.")
		return
	globe.call("rotate_globe", Vector2(-18.0, 0.0))
	if pivot.rotation.y >= vertical_rotation.y:
		_fail("Dragging left must reverse the horizontal rotation direction.")
		return
	var initial_zoom := float(globe.call("get_zoom_distance"))
	globe.call("zoom_globe", -0.5)
	if float(globe.get("_zoom_target_distance")) >= initial_zoom:
		_fail("The globe zoom method did not move the camera closer.")
		return
	globe.call("zoom_globe", -100.0)
	var closest_zoom := float(globe.get("_zoom_target_distance"))
	if not is_equal_approx(closest_zoom, 2.25):
		_fail("The close zoom limit must allow a detailed country-level view.")
		return
	globe.call("zoom_globe", 100.0)
	var farthest_zoom := float(globe.get("_zoom_target_distance"))
	if not is_equal_approx(farthest_zoom, 7.2):
		_fail("The far zoom limit must keep the Earth comfortably large on screen.")
		return
	if country_borders.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		_fail("Country boundaries must use visible surface ribbons, not sub-pixel line primitives.")
		return
	var border_material := country_borders.mesh.surface_get_material(0) as StandardMaterial3D
	if border_material == null or border_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		_fail("Country boundaries must be shaded and integrated with the Earth surface, not bright unshaded strokes.")
		return
	if absf(border_material.albedo_color.r - border_material.albedo_color.g) > 0.08 or border_material.albedo_color.b < border_material.albedo_color.g:
		_fail("Country boundaries must use the restrained cool-grey Google Earth inspired palette.")
		return
	if not str(country_borders.get_meta("cartographic_style")).begins_with("subtle_google_earth_inspired_admin0"):
		_fail("The country boundary layer is missing its intended cartographic style metadata.")
		return
	if float(country_borders.get_meta("surface_radius")) > 1.603:
		_fail("Country boundaries are floating too far above the Earth surface.")
		return
	if country_labels.is_empty() or (country_labels[0] as Label3D).font_size > 44:
		_fail("Country names must use the quieter, smaller geographic label treatment.")
		return

	globe.queue_free()
	await process_frame

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
	print("WORLD_GLOBE_NAVIGATION_SMOKE_TEST: PASS")
	quit()


func _wait_for_country_layer(globe: Node3D, expected_tier: String, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		await create_timer(0.1).timeout
		elapsed += 0.1
		var layer := globe.find_child("Country_Boundaries", true, false) as MeshInstance3D
		if layer != null and layer.mesh != null and layer.mesh.get_surface_count() > 0 and layer.visible:
			if str(layer.get_meta("geographic_resolution")) == expected_tier:
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
