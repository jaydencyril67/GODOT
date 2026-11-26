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

	var sections := campus.get_node_or_null("Campus_Sections") as Node3D
	if sections == null or int(sections.get_meta("section_count", 0)) != 8:
		_fail("The campus does not contain all eight planned sections.")
		return
	if sections.get_meta("layout", "") != "four_columns_two_rows":
		_fail("The campus section layout is not the planned 4 by 2 arrangement.")
		return
	for section_index in range(1, 9):
		var section := sections.get_node_or_null("Section_%02d" % section_index) as Node3D
		if section == null or str(section.get_meta("section_name", "")).is_empty():
			_fail("Campus section %d or its name metadata is missing." % section_index)
			return
		var section_sign := section.get_node_or_null("SectionSign/SectionName") as Label3D
		if section_sign == null or section_sign.text.is_empty():
			_fail("Campus section %d does not have a visible 3D sign." % section_index)
			return

	var fences := campus.get_node_or_null("Campus_Wooden_Fences") as Node3D
	if fences == null or not bool(fences.get_meta("wooden_fence", false)):
		_fail("The wooden campus fence system is missing.")
		return
	var fence_posts := fences.get_node_or_null("Fence_Posts") as MultiMeshInstance3D
	var fence_rails := fences.get_node_or_null("Fence_Rails") as MultiMeshInstance3D
	var fence_pickets := fences.get_node_or_null("Fence_Vertical_Pickets") as MultiMeshInstance3D
	var fence_collisions := fences.get_node_or_null("Fence_Collisions") as StaticBody3D
	if fence_posts == null or fence_rails == null or fence_pickets == null or fence_collisions == null:
		_fail("The hybrid wooden fence posts, rails, pickets, or collision body are missing.")
		return
	if fences.get_meta("fence_style", "") != "hybrid_post_rail_vertical_picket":
		_fail("The campus fence is not the upgraded hybrid timber picket style.")
		return
	if fence_posts.multimesh == null or fence_posts.multimesh.instance_count < 500:
		_fail("The wooden fence post instances are missing or incomplete.")
		return
	if fence_rails.multimesh == null or fence_rails.multimesh.instance_count < 120:
		_fail("The wooden fence rail instances are missing or incomplete.")
		return
	if fence_pickets.multimesh == null or fence_pickets.multimesh.instance_count < 20000:
		_fail("The vertical wooden picket panels are missing or incomplete.")
		return
	if fence_collisions.get_child_count() < 32 or not bool(fence_collisions.get_meta("blocks_player", false)):
		_fail("The wooden fence boundaries do not have complete player-blocking collision.")
		return

	var clouds := campus.get_node_or_null("Campus_Clouds") as MultiMeshInstance3D
	if clouds == null or clouds.multimesh == null:
		_fail("The campus 3D cloud layer is missing.")
		return
	if int(clouds.get_meta("cloud_cluster_count", 0)) != 22 or clouds.multimesh.instance_count < 120:
		_fail("The campus cloud layer does not contain the expected instanced cloud formations.")
		return
	var world_environment := campus.get_node_or_null("Campus_World_Environment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		_fail("The campus sky environment did not load.")
		return
	if world_environment.environment.background_mode != Environment.BG_SKY or world_environment.environment.sky == null:
		_fail("The campus does not have a sky background.")
		return
	if not (world_environment.environment.sky.sky_material is ProceduralSkyMaterial):
		_fail("The campus sky is not using the upgraded procedural sky material.")
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
	if int(grass.get_meta("instance_count", 0)) != 7600:
		_fail("The hybrid grass instance budget changed unexpectedly.")
		return
	if int(grass.get_meta("maintained_core_instance_count", 0)) != 5472 or int(grass.get_meta("natural_edge_instance_count", 0)) != 2128:
		_fail("The maintained and natural grass zone counts are incorrect.")
		return
	var near_grass := campus.get_node_or_null("NearPlayer_Grass") as MultiMeshInstance3D
	if near_grass == null or near_grass.multimesh == null:
		_fail("The near-player grass layer is missing.")
		return
	if near_grass.multimesh.instance_count != 900 or not bool(near_grass.get_meta("follows_player", false)):
		_fail("The near-player grass layer is not configured to follow the player.")
		return
	var tree_trunks := campus.get_node_or_null("Campus_Tree_Trunks") as MultiMeshInstance3D
	var tree_canopies := campus.get_node_or_null("Campus_Tree_Canopies") as MultiMeshInstance3D
	if tree_trunks == null or tree_canopies == null:
		_fail("The campus tree trunks or canopies are missing.")
		return
	if tree_trunks.multimesh == null or tree_canopies.multimesh == null:
		_fail("The campus tree MultiMeshes were not created.")
		return
	if tree_trunks.multimesh.instance_count != 44 or tree_canopies.multimesh.instance_count != 44:
		_fail("The campus should contain 44 instanced trees.")
		return
	var player := campus.get_node_or_null("PlayerCharacter") as CharacterBody3D
	if player == null or player.get_node_or_null("Humanoid_Collision") == null:
		_fail("The first playable humanoid character or its collision body is missing.")
		return
	if player.collision_layer != 1 or player.collision_mask != 1:
		_fail("The player collision layer and mask are not configured to collide with campus fences.")
		return
	await physics_frame
	var fence_ray := PhysicsRayQueryParameters3D.create(
		Vector3(-398.0, 0.80, 50.0),
		Vector3(-390.0, 0.80, 50.0)
	)
	fence_ray.collision_mask = 1
	fence_ray.collide_with_bodies = true
	fence_ray.collide_with_areas = false
	var fence_hit := campus.get_world_3d().direct_space_state.intersect_ray(fence_ray)
	if fence_hit.is_empty() or fence_hit.get("collider") != fence_collisions:
		_fail("A physics ray passed through a solid wooden fence section.")
		return
	var camera := campus.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		_fail("The first-person player camera is missing.")
		return
	if campus.get_meta("camera_perspective", "") != "first_person_eye_only":
		_fail("The campus camera is not configured for strict eye-only first-person view.")
		return
	if not is_equal_approx(camera.global_position.y - player.global_position.y, 1.62):
		_fail("The first-person camera is not positioned at eye height.")
		return
	if player.get_child_count() != 1 or player.get_node_or_null("Humanoid_Collision") == null:
		_fail("The player must contain only its collision capsule, with no visible body parts.")
		return
	if player.find_child("*", true, false) is MeshInstance3D:
		_fail("A visible player body mesh remains in the eye-only first-person setup.")
		return

	var joystick := campus.find_child("MovementJoystick", true, false) as Control
	if joystick == null or joystick.custom_minimum_size.x < 190.0:
		_fail("The left movement joystick is missing or too small.")
		return
	if campus.find_child("BackToMenuButton", true, false) == null:
		_fail("The campus scene has no return-to-menu button.")
		return

	var phone_button := campus.find_child("PhoneButton", true, false) as Button
	var phone_device := campus.find_child("PhoneDevice", true, false) as Panel
	var phone_screen := campus.find_child("PhoneScreen", true, false) as Panel
	if phone_button == null or phone_device == null or phone_screen == null:
		_fail("The phone launcher, handset, or blank display is missing.")
		return
	if phone_button.custom_minimum_size.x >= joystick.custom_minimum_size.x or phone_button.custom_minimum_size.y >= joystick.custom_minimum_size.y:
		_fail("The phone launcher must be substantially smaller than the movement joystick.")
		return
	if phone_button.mouse_filter != Control.MOUSE_FILTER_STOP or phone_device.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("The phone controls must capture their own touches without disabling the joystick.")
		return
	if phone_device.visible or bool(phone_device.get_meta("screen_powered", true)) or bool(phone_screen.get_meta("screen_powered", true)):
		_fail("The phone must start hidden and powered off.")
		return
	var phone_style := phone_screen.get_theme_stylebox("panel") as StyleBoxFlat
	if phone_style == null or phone_style.bg_color != Color.BLACK:
		_fail("The powered-off phone screen is not completely black.")
		return
	var handset_ratio := phone_device.size.x / maxf(phone_device.size.y, 1.0)
	if handset_ratio < 0.43 or handset_ratio > 0.49 or phone_device.size.y < get_root().get_visible_rect().size.y * 0.82:
		_fail("The opened handset is not a near-full-height, realistic portrait phone shape.")
		return
	if phone_device.position.x <= joystick.position.x + joystick.size.x:
		_fail("The phone handset overlaps the left movement joystick.")
		return
	phone_button.emit_signal("pressed")
	if not phone_device.visible:
		_fail("Tapping the small phone launcher did not display the handset.")
		return
	phone_button.emit_signal("pressed")
	if phone_device.visible:
		_fail("The phone launcher cannot close the handset after opening it.")
		return

	print("COMPANY_CAMPUS_SMOKE_TEST: PASS")
	campus.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("COMPANY_CAMPUS_SMOKE_TEST: FAIL: " + message)
	quit(1)
