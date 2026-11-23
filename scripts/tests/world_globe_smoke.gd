extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/world_globe.tscn") as PackedScene
	if packed_scene == null:
		_fail("The standalone globe scene could not be loaded.")
		return

	var globe := packed_scene.instantiate()
	root.add_child(globe)
	await process_frame

	var camera := globe.find_child("GlobeCamera", true, false) as Camera3D
	var earth := globe.find_child("EarthSurface", true, false) as MeshInstance3D
	var clouds := globe.find_child("ProceduralCloudDeck", true, false) as MeshInstance3D
	var atmosphere := globe.find_child("BlueAtmosphericRim", true, false) as MeshInstance3D
	var admin_panel := globe.find_child("ZoomOnlyAdministrativeData", true, false) as PanelContainer

	if camera == null or not camera.current:
		_fail("The globe scene did not activate its dedicated camera.")
		return
	if earth == null or earth.mesh == null or earth.mesh.get_surface_count() == 0:
		_fail("The globe is missing its rendered Earth sphere.")
		return
	if clouds == null or clouds.mesh == null:
		_fail("The separate cloud shell is missing.")
		return
	if atmosphere == null or atmosphere.mesh == null:
		_fail("The atmospheric rim is missing.")
		return
	if admin_panel == null or admin_panel.visible:
		_fail("Country and province controls must remain hidden at the initial globe zoom.")
		return

	globe.call("_set_zoom", 2.8)
	await process_frame
	if not admin_panel.visible:
		_fail("Country and province controls did not appear after zooming in.")
		return

	globe.queue_free()
	await process_frame
	print("WORLD_GLOBE_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("WORLD_GLOBE_SMOKE_TEST: FAIL: " + message)
	quit(1)
