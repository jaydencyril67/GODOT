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
	if not _has_godot_clockwise_front_faces(earth.mesh):
		_fail("Earth surface triangles are wound backwards and will be culled from outside.")
		return
	var detail_mesh := globe.call("_build_geo_patch", -20.0, 20.0, -12.0, 12.0, 1.0045, 12, 8) as ArrayMesh
	if detail_mesh == null or not _has_godot_clockwise_front_faces(detail_mesh):
		_fail("Zoomed regional texture patches are wound backwards and will be culled.")
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


func _has_godot_clockwise_front_faces(mesh: ArrayMesh) -> bool:
	if mesh.get_surface_count() == 0:
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or indices.size() < 3 or indices.size() % 3 != 0:
		return false
	var clockwise_faces := 0
	var counterclockwise_faces := 0
	for offset in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[offset]]
		var b: Vector3 = vertices[indices[offset + 1]]
		var c: Vector3 = vertices[indices[offset + 2]]
		var face_direction := (b - a).cross(c - a).dot((a + b + c) / 3.0)
		if face_direction < -0.0000001:
			clockwise_faces += 1
		elif face_direction > 0.0000001:
			counterclockwise_faces += 1
	return clockwise_faces > 0 and counterclockwise_faces == 0


func _fail(message: String) -> void:
	push_error(message)
	print("WORLD_GLOBE_SMOKE_TEST: FAIL: " + message)
	quit(1)
