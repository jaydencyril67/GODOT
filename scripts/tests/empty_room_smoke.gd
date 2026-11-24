extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/empty_room.tscn") as PackedScene
	if packed_scene == null:
		_fail("The empty room preview scene could not be loaded.")
		return

	var room_preview := packed_scene.instantiate()
	root.add_child(room_preview)
	await process_frame

	var room_asset := room_preview.find_child("EmptyRoomAsset", true, false)
	if room_asset == null:
		_fail("The Blender-compatible room asset was not instantiated.")
		return

	var room_meshes := room_asset.find_children("*", "MeshInstance3D", true, false)
	var room_mesh := room_meshes[0] as MeshInstance3D if not room_meshes.is_empty() else null
	if room_mesh == null or room_mesh.mesh == null or room_mesh.mesh.get_surface_count() != 6:
		_fail("The imported room must contain exactly six architectural surfaces: floor, four walls and ceiling.")
		return

	var camera := room_preview.find_child("EmptyRoomCamera", true, false) as Camera3D
	if camera == null or not camera.current:
		_fail("The empty room preview did not activate its inspection camera.")
		return
	if room_preview.find_child("EmptyRoomBackButton", true, false) == null:
		_fail("The empty room preview is missing its Back button.")
		return
	if room_preview.find_child("HiddenCeilingFill", true, false) == null:
		_fail("The empty room preview is missing its soft interior lighting.")
		return

	var room_constants: Dictionary = room_preview.get_script().get_script_constant_map()
	if float(room_constants.get("CAMERA_MIN_DISTANCE", 0.0)) >= float(room_constants.get("CAMERA_MAX_DISTANCE", 0.0)):
		_fail("The room inspection camera zoom range is invalid.")
		return

	room_preview.call("_set_zoom", 1.0)
	if float(camera.position.z) < float(room_constants["CAMERA_MIN_DISTANCE"]):
		_fail("Room preview zoom must respect the minimum camera distance.")
		return
	room_preview.call("_set_zoom", 10.0)
	if float(camera.position.z) > float(room_constants["CAMERA_MAX_DISTANCE"]):
		_fail("Room preview zoom must respect the maximum camera distance.")
		return

	room_preview.queue_free()
	await process_frame
	print("EMPTY_ROOM_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("EMPTY_ROOM_SMOKE_TEST: FAIL - %s" % message)
	quit(1)
