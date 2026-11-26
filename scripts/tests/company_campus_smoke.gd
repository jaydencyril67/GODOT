extends SceneTree

const CompanyCampusScene: PackedScene = preload("res://scenes/company_campus.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campus := CompanyCampusScene.instantiate() as Node3D
	if campus == null:
		_fail("The Company Campus scene could not be instantiated.")
		return
	root.add_child(campus)
	await process_frame
	await process_frame

	var dimensions: Vector2 = campus.get_meta("map_dimensions", Vector2.ZERO)
	if dimensions != Vector2(800.0, 600.0):
		_fail("The campus footprint is not 800 m × 600 m.")
		return
	if not is_equal_approx(float(campus.get_meta("map_area_square_metres", 0.0)), 480000.0):
		_fail("The campus area metadata is incorrect.")
		return

	var terrain := campus.get_node_or_null("Terrain") as MeshInstance3D
	if terrain == null or terrain.mesh == null:
		_fail("The campus grass terrain did not load.")
		return
	var player := campus.get_node_or_null("PlayerCharacter") as CharacterBody3D
	if player == null or player.get_node_or_null("Humanoid_Collision") == null:
		_fail("The first playable humanoid character or its collision body is missing.")
		return
	if (campus.get_node_or_null("PlayerCamera") as Camera3D) == null:
		_fail("The third-person player camera is missing.")
		return

	var joystick := campus.find_child("MovementJoystick", true, false) as Control
	if joystick == null or joystick.custom_minimum_size.x < 190.0:
		_fail("The left movement joystick is missing or too small.")
		return
	if campus.find_child("CameraLookHint", true, false) == null:
		_fail("The right-side camera look instruction is missing.")
		return
	if campus.find_child("BackToMenuButton", true, false) == null:
		_fail("The campus scene has no return-to-menu button.")
		return

	print("COMPANY_CAMPUS_SMOKE_TEST: PASS")
	campus.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("COMPANY_CAMPUS_SMOKE_TEST: FAIL: " + message)
	quit(1)
