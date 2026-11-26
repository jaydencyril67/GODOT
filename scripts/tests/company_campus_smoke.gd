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
	if terrain.get_meta("grass_layout", "") != "hybrid_maintained_core_natural_perimeter":
		_fail("The campus terrain is not configured for hybrid grass zones.")
		return
	var grass := campus.get_node_or_null("Hybrid_Grass_Clumps") as MultiMeshInstance3D
	if grass == null or grass.multimesh == null:
		_fail("The hybrid grass instances are missing.")
		return
	if int(grass.get_meta("instance_count", 0)) != 5600:
		_fail("The hybrid grass instance budget changed unexpectedly.")
	if int(grass.get_meta("maintained_core_instance_count", 0)) != 4032 or int(grass.get_meta("natural_edge_instance_count", 0)) != 1568:
		_fail("The maintained and natural grass zone counts are incorrect.")
		return
	var player := campus.get_node_or_null("PlayerCharacter") as CharacterBody3D
	if player == null or player.get_node_or_null("Humanoid_Collision") == null:
		_fail("The first playable humanoid character or its collision body is missing.")
		return
	var camera := campus.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		_fail("The first-person player camera is missing.")
		return
	if campus.get_meta("camera_perspective", "") != "first_person_hybrid":
		_fail("The campus camera is not configured for hybrid first-person view.")
		return
	if not is_equal_approx(camera.global_position.y - player.global_position.y, 1.62):
		_fail("The first-person camera is not positioned at eye height.")
		return
	var head_visual := player.get_node_or_null("HumanoidVisual/HeadVisual_FirstPersonHidden") as Node3D
	if head_visual == null or head_visual.visible:
		_fail("The first-person head mesh should be hidden to prevent camera clipping.")
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
