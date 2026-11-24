extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/atlas_executive_office.tscn") as PackedScene
	if packed_scene == null:
		_fail("The Atlas executive office preview scene could not be loaded.")
		return

	var office_preview := packed_scene.instantiate()
	root.add_child(office_preview)
	await process_frame

	var office := office_preview.find_child("AtlasExecutiveOffice", true, false) as Node3D
	if office == null:
		_fail("The downloaded Atlas GLB was not instantiated in the preview.")
		return

	var office_meshes := office.find_children("*", "MeshInstance3D", true, false)
	if office_meshes.size() < 20:
		_fail("The Atlas office preview does not contain the expected furnished 3D geometry.")
		return

	var office_bounds_value: Variant = office_preview.get("office_bounds")
	if not (office_bounds_value is AABB):
		_fail("The office preview did not calculate its interior bounds.")
		return
	var office_bounds: AABB = office_bounds_value
	if office_bounds.size.x <= 1.0 or office_bounds.size.y <= 1.0 or office_bounds.size.z <= 1.0:
		_fail("The imported office bounds are too small for a walkable interior.")

	var player := office_preview.find_child("FirstPersonPlayer", true, false) as CharacterBody3D
	if player == null:
		_fail("The office is missing its first-person CharacterBody3D controller.")
		return

	var player_collision := player.find_child("PlayerCapsule", true, false) as CollisionShape3D
	if player_collision == null or not (player_collision.shape is CapsuleShape3D):
		_fail("The first-person player is missing its capsule collision shape.")
		return

	var camera := player.find_child("OfficeFirstPersonCamera", true, false) as Camera3D
	if camera == null or not camera.current or not is_equal_approx(camera.position.y, 1.60):
		_fail("The active office camera must be positioned at first-person eye height.")
		return

	var collision_body := office_preview.find_child("AtlasOfficeCollision", true, false) as StaticBody3D
	var collision_shape := office_preview.find_child("AtlasOfficeCollisionShape", true, false) as CollisionShape3D
	if collision_body == null or collision_shape == null or not (collision_shape.shape is ConcavePolygonShape3D):
		_fail("The office geometry is missing its combined walkable collision mesh.")
		return

	var joystick_base := office_preview.find_child("MovementJoystickBase", true, false) as Panel
	var joystick_thumb := office_preview.find_child("MovementJoystickThumb", true, false) as Panel
	if joystick_base == null or joystick_thumb == null:
		_fail("The office is missing the mobile movement joystick.")
		return
	if not is_equal_approx(joystick_base.size.x, 259.2):
		_fail("The movement joystick base must remain 1.8 times its original size.")
		return

	if office_preview.find_child("LookPad", true, false) == null:
		_fail("The right-side look control is missing.")
		return
	if office_preview.find_child("LookHintLabel", true, false) != null:
		_fail("The right look circle must remain free of LOOK text.")
		return
	if office_preview.find_child("FirstPersonModeLabel", true, false) != null:
		_fail("The first-person mode label should not appear on screen.")
		return
	if office_preview.find_child("OfficeBackButton", true, false) == null:
		_fail("The office preview is missing its Back button.")
		return

	if office_preview.find_child("LargeEmptyRoom", true, false) != null:
		_fail("The old second empty room is still being created.")
		return
	if office_preview.find_child("EmptyRoomAsset", true, false) != null:
		_fail("The old empty-room model is still being created.")
		return
	if office_preview.find_child("GlassExitDoorPane", true, false) != null:
		_fail("The old procedural glass-door room should no longer be part of this preview.")
		return

	var constants: Dictionary = office_preview.get_script().get_script_constant_map()
	if float(constants.get("WALK_SPEED", 0.0)) <= 0.0 or float(constants.get("LOOK_SENSITIVITY", 0.0)) <= 0.0:
		_fail("Walking speed and look sensitivity must remain positive.")
		return

	var pad_center: Vector2 = office_preview.get("move_pad_center")
	var joystick_radius := float(constants["JOYSTICK_RADIUS"])
	office_preview.call("_set_move_joystick", pad_center + Vector2(0.0, -joystick_radius))
	var movement_input: Vector2 = office_preview.get("joystick_vector")
	if movement_input.y >= -0.9:
		_fail("Pushing the left joystick forward must produce forward movement input.")
		return
	office_preview.call("_reset_move_joystick")

	var starting_yaw := player.rotation.y
	office_preview.call("_apply_look", Vector2(30.0, -20.0))
	if is_equal_approx(player.rotation.y, starting_yaw) or camera.rotation.x <= 0.0:
		_fail("The right-side look control must rotate the player view.")
		return

	var back_requested := false
	office_preview.back_requested.connect(func() -> void:
		back_requested = true
	)
	office_preview.call("_request_back")
	if not back_requested:
		_fail("The Back button signal must be emitted so the game can return to the landing page.")
		return

	office_preview.queue_free()
	await process_frame
	print("ATLAS_EXECUTIVE_OFFICE_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("ATLAS_EXECUTIVE_OFFICE_SMOKE_TEST: FAIL - %s" % message)
	quit(1)
