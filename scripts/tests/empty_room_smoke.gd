extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/empty_room.tscn") as PackedScene
	if packed_scene == null:
		_fail("The empty room scene could not be loaded.")
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
		_fail("The room must retain its six architectural surfaces: floor, four walls and ceiling.")
		return

	var player := room_preview.find_child("FirstPersonPlayer", true, false) as CharacterBody3D
	if player == null:
		_fail("The room is missing its first-person CharacterBody3D controller.")
		return

	var player_collision := player.find_child("PlayerCapsule", true, false) as CollisionShape3D
	if player_collision == null or not (player_collision.shape is CapsuleShape3D):
		_fail("The first-person player is missing its capsule collision shape.")
		return

	var camera := player.find_child("EmptyRoomCamera", true, false) as Camera3D
	if camera == null or not camera.current or not is_equal_approx(camera.position.y, 1.60):
		_fail("The first-person camera must be active and positioned at eye height.")
		return

	var room_colliders := room_preview.find_children("*", "StaticBody3D", true, false)
	if room_colliders.size() < 9:
		_fail("The floor, walls, ceiling and closed glass exit door must have collision bodies.")
		return

	var floor_material := room_mesh.get_surface_override_material(0) as StandardMaterial3D
	var wall_material := room_mesh.get_surface_override_material(1) as StandardMaterial3D
	if floor_material == null or floor_material.albedo_texture == null:
		_fail("The room floor is missing its subtle procedural texture.")
		return
	if wall_material == null or wall_material.albedo_texture == null:
		_fail("The room walls are missing their subtle plaster texture.")
		return

	var glass_door := room_preview.find_child("GlassExitDoorPane", true, false) as MeshInstance3D
	if glass_door == null or glass_door.mesh == null:
		_fail("The room is missing its glass exit door pane.")
		return
	var glass_material := glass_door.material_override as StandardMaterial3D
	if glass_material == null or glass_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		_fail("The exit door pane must use a translucent glass material.")
		return
	if room_preview.find_child("GlassExitDoorFrameLeft", true, false) == null or room_preview.find_child("ExitDoorPullHandle", true, false) == null:
		_fail("The glass exit door is missing its frame or pull handle.")
		return
	if room_preview.find_child("ExitSignText", true, false) == null:
		_fail("The glass door is missing its EXIT sign.")
		return
	if room_preview.find_child("GlassExitDoorCollision", true, false) == null:
		_fail("The closed glass exit door must block the player until it is opened.")
		return

	if room_preview.find_child("MovementJoystickBase", true, false) == null:
		_fail("The room is missing the left movement joystick.")
		return
	if room_preview.find_child("MovementJoystickThumb", true, false) == null:
		_fail("The movement joystick is missing its movable thumb.")
		return
	if room_preview.find_child("LookPad", true, false) == null or room_preview.find_child("LookHintLabel", true, false) == null:
		_fail("The room is missing the right-side look control.")
		return
	if room_preview.find_child("EmptyRoomBackButton", true, false) == null:
		_fail("The first-person room is missing its Back button.")
		return
	if room_preview.find_child("HiddenCeilingFill", true, false) == null:
		_fail("The room is missing its soft interior lighting.")
		return

	var room_constants: Dictionary = room_preview.get_script().get_script_constant_map()
	if float(room_constants.get("WALK_SPEED", 0.0)) <= 0.0 or float(room_constants.get("LOOK_SENSITIVITY", 0.0)) <= 0.0:
		_fail("Walking speed and look sensitivity must be positive.")
		return

	var starting_position := player.global_position
	var pad_center: Vector2 = room_preview.get("move_pad_center")
	var joystick_radius := float(room_constants["JOYSTICK_RADIUS"])
	room_preview.call("_set_move_joystick", pad_center + Vector2(0.0, -joystick_radius))
	var movement_input: Vector2 = room_preview.get("joystick_vector")
	if movement_input.y >= -0.9:
		_fail("Pushing the left joystick forward must produce forward movement input.")
		return

	await physics_frame
	if player.global_position.z >= starting_position.z:
		_fail("The first-person controller did not move forward when the joystick was pushed.")
		return
	room_preview.call("_reset_move_joystick")

	var starting_yaw := player.rotation.y
	room_preview.call("_apply_look", Vector2(30.0, -20.0))
	if is_equal_approx(player.rotation.y, starting_yaw) or camera.rotation.x <= 0.0:
		_fail("The right-side look control must rotate the player view.")
		return

	room_preview.queue_free()
	await process_frame
	print("EMPTY_ROOM_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("EMPTY_ROOM_SMOKE_TEST: FAIL - %s" % message)
	quit(1)
