extends SceneTree

var back_requested_seen := false

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/gaussian_splat_office.tscn") as PackedScene
	if packed_scene == null:
		_fail("The Gaussian Splat office scene could not be loaded.")
		return

	var preview := packed_scene.instantiate()
	root.add_child(preview)
	await process_frame
	await physics_frame
	await process_frame

	var splat := preview.find_child("OfficeGaussianSplat", true, false) as VisualInstance3D
	if splat == null:
		_fail("The new office did not instantiate its GaussianSplatNode.")
		return

	var gaussian: Resource = splat.get("gaussian")
	if gaussian == null or int(gaussian.get("point_count")) != 750000:
		_fail("The office did not load the expected 750,000-point Gaussian resource.")
		return

	var bounds_value: Variant = gaussian.get("aabb")
	if not (bounds_value is AABB):
		_fail("The Gaussian resource has no valid spatial bounds.")
		return
	var bounds: AABB = bounds_value
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0 or bounds.size.z <= 1.0:
		_fail("The imported Gaussian environment bounds are too small: %s" % bounds)
		return

	var player := preview.find_child("FirstPersonPlayer", true, false) as CharacterBody3D
	var camera := preview.find_child("OfficeFirstPersonCamera", true, false) as Camera3D
	if player == null or camera == null or not camera.current:
		_fail("The Gaussian office is missing its active first-person player camera.")
		return

	var floor_body := preview.find_child("GaussianSplatOfficeFallbackFloor", true, false) as StaticBody3D
	var floor_shape := preview.find_child("GaussianSplatOfficeFallbackFloorShape", true, false) as CollisionShape3D
	if floor_body == null or floor_shape == null or not (floor_shape.shape is WorldBoundaryShape3D):
		_fail("The Gaussian office is missing its dedicated invisible walkable floor.")
		return

	for wall_name in ["SplatNorthBoundary", "SplatSouthBoundary", "SplatWestBoundary", "SplatEastBoundary"]:
		if preview.find_child(wall_name, true, false) == null:
			_fail("Missing collision-only room boundary: " + wall_name)
			return

	for frame_index in range(60):
		await physics_frame
	if not player.is_on_floor() or player.global_position.y < -0.02:
		_fail("The first-person player did not settle on the Gaussian office safety floor.")
		return

	var joystick_base := preview.find_child("MovementJoystickBase", true, false) as Panel
	var joystick_thumb := preview.find_child("MovementJoystickThumb", true, false) as Panel
	if joystick_base == null or joystick_thumb == null or not is_equal_approx(joystick_base.size.x, 259.2):
		_fail("The mobile movement joystick is missing or has the wrong size.")
		return
	if preview.find_child("LookPad", true, false) == null:
		_fail("The right-side look control is missing.")
		return
	if preview.find_child("LookHintLabel", true, false) != null or preview.find_child("FirstPersonModeLabel", true, false) != null:
		_fail("Obsolete look/first-person labels must remain absent.")
		return
	if preview.find_child("OfficeBackButton", true, false) == null:
		_fail("The Gaussian office is missing its Back button.")
		return

	back_requested_seen = false
	preview.connect("back_requested", Callable(self, "_on_back_requested"))
	preview.call("_request_back")
	if not back_requested_seen:
		_fail("The Gaussian office Back signal did not fire.")
		return

	preview.queue_free()
	await process_frame
	print("GAUSSIAN_SPLAT_OFFICE_SMOKE_TEST: PASS")
	quit()


func _on_back_requested() -> void:
	back_requested_seen = true


func _fail(message: String) -> void:
	push_error(message)
	print("GAUSSIAN_SPLAT_OFFICE_SMOKE_TEST: FAIL - %s" % message)
	quit(1)
