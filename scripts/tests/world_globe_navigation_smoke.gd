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
		_fail("The Earth surface texture did not import or load.")
		return

	var initial_rotation: Vector3 = (globe.get("earth_pivot") as Node3D).rotation
	globe.call("rotate_globe", Vector2(18.0, 12.0))
	var rotated: Vector3 = (globe.get("earth_pivot") as Node3D).rotation
	if rotated.is_equal_approx(initial_rotation):
		_fail("The globe rotation method did not change the Earth orientation.")
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
