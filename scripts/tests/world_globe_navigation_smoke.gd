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
	if country_borders == null or country_borders.mesh == null or country_borders.mesh.get_surface_count() == 0:
		_fail("Natural Earth country boundary geometry was not rendered.")
		return
	if country_borders.visible:
		_fail("Country boundaries must remain hidden at the far globe zoom.")
		return
	var equator_west: Vector3 = globe.call("_geo_to_globe_position", 0.0, -180.0, 1.0)
	var equator_east: Vector3 = globe.call("_geo_to_globe_position", 0.0, 0.0, 1.0)
	if equator_west.distance_to(Vector3(0.0, 0.0, 1.0)) > 0.001 or equator_east.distance_to(Vector3(0.0, 0.0, -1.0)) > 0.001:
		_fail("Geographic longitude registration does not match the equirectangular Earth texture seam.")
		return
	var country_labels := globe.get("country_labels") as Array
	if country_labels.size() < 150:
		_fail("The Natural Earth country label layer did not load the expected country set.")
		return
	var far_visible_count := 0
	for label_variant in country_labels:
		var country_label := label_variant as Label3D
		if country_label != null and country_label.visible:
			far_visible_count += 1
	if far_visible_count != 0:
		_fail("Country labels must remain hidden at the far globe zoom.")
		return
	globe.call("zoom_globe", -0.6)
	if not country_borders.visible:
		_fail("Country boundaries must appear after the camera enters country zoom.")
		return
	var country_zoom_visible_count := 0
	for label_variant in country_labels:
		var country_label := label_variant as Label3D
		if country_label != null and country_label.visible:
			country_zoom_visible_count += 1
	if country_zoom_visible_count == 0:
		_fail("Priority country names must appear at country zoom.")
		return
	globe.call("zoom_globe", -0.9)
	var close_visible_count := 0
	for label_variant in country_labels:
		var country_label := label_variant as Label3D
		if country_label != null and country_label.visible:
			close_visible_count += 1
	if close_visible_count <= country_zoom_visible_count:
		_fail("Zooming closer must progressively reveal more country names.")
		return
	globe.call("zoom_globe", 1.5)
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
	if float(globe.call("get_zoom_distance")) >= initial_zoom:
		_fail("The globe zoom method did not move the camera closer.")
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


func _fail(message: String) -> void:
	push_error(message)
	print("WORLD_GLOBE_NAVIGATION_SMOKE_TEST: FAIL: " + message)
	quit(1)
