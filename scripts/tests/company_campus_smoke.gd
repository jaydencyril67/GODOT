extends SceneTree

const CompanyCampusScene: PackedScene = preload("res://scenes/company_campus.tscn")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campus := CompanyCampusScene.instantiate() as Node3D
	if campus == null:
		_fail("The Company Campus scene could not be instantiated.")
		return
	var insignia_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	insignia_image.fill(Color("#D2A15C"))
	campus.call("configure_career_hud", "TEST MOBILES", ImageTexture.create_from_image(insignia_image), "$25,000", "2nd Jan 2020", true)
	var observed_signals := {"campus_generated": false, "clock_toggle_requested": false}
	var progress_updates: Array[Dictionary] = []
	campus.setup_progress.connect(func(message: String, progress: float):
		progress_updates.append({"message": message, "progress": progress})
	)
	campus.setup_completed.connect(func(): observed_signals["campus_generated"] = true)
	campus.game_clock_toggle_requested.connect(func(): observed_signals["clock_toggle_requested"] = true)
	root.add_child(campus)
	while not bool(observed_signals["campus_generated"]):
		await process_frame

	if not bool(campus.get_meta("career_home_scene", false)) or not bool(campus.get_meta("campus_generation_complete", false)):
		_fail("The campus did not complete its generated career-home setup.")
		return
	if progress_updates.size() < 100:
		_fail("Campus initialization did not report progress for every bounded world-generation batch.")
		return
	var last_progress_by_stage: Dictionary = {}
	for update in progress_updates:
		var stage_message := str(update.get("message", ""))
		var stage_progress := float(update.get("progress", -1.0))
		if stage_progress < float(last_progress_by_stage.get(stage_message, -1.0)) - 0.01:
			_fail("The campus progress bar moved backwards within the same initialization stage: " + stage_message)
			return
		last_progress_by_stage[stage_message] = stage_progress
	var campus_controls_layer := campus.get_node_or_null("Campus_Controls_Layer") as CanvasLayer
	if campus_controls_layer == null or campus_controls_layer.visible:
		_fail("Campus HUD and touch controls must remain hidden while startup preparation is active.")
		return
	campus.call("set_career_home_overlay_visible", true)
	if not campus_controls_layer.visible:
		_fail("The campus HUD and touch controls could not be revealed after startup preparation.")
		return
	var career_status := campus.find_child("CampusCareerStatusBar", true, false) as HBoxContainer
	if career_status == null or career_status.has_theme_stylebox_override("panel"):
		_fail("The campus career HUD must be a transparent layout with no shared background card.")
		return
	var hud_spacer := campus.find_child("CampusCareerHudAlignmentSpacer", true, false) as Control
	if hud_spacer == null or hud_spacer.get_parent() != career_status or hud_spacer.get_index() != 2 or (hud_spacer.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
		_fail("The campus HUD must place an expanding alignment spacer between the left company identity and right-side status controls.")
		return
	if career_status.anchor_left != 0.0 or career_status.anchor_right != 1.0 or not is_equal_approx(career_status.offset_left, 14.0) or not is_equal_approx(career_status.offset_right, -14.0):
		_fail("The campus HUD must span the top edge with consistent left and right screen margins.")
		return
	for card_name in ["CampusCompanyInsigniaFrame", "CampusCompanyIdentityCard", "CampusBalanceCard", "CampusDateCard", "CampusGameClockCard"]:
		var hud_card := campus.find_child(card_name, true, false) as PanelContainer
		if hud_card == null:
			_fail("The independent campus HUD card is missing: " + card_name)
			return
	var company_insignia := campus.find_child("CampusCompanyInsignia", true, false) as TextureRect
	var company_identity_card := campus.find_child("CampusCompanyIdentityCard", true, false) as PanelContainer
	var company_name_label := campus.find_child("CampusCompanyName", true, false) as Label
	var balance_label := campus.find_child("CampusBalanceValue", true, false) as Label
	var date_label := campus.find_child("CampusDateValue", true, false) as Label
	var clock_button := campus.find_child("CampusGameClockControl", true, false) as Button
	if career_status == null or company_insignia == null or company_insignia.texture == null or company_identity_card == null or company_name_label == null or balance_label == null or date_label == null or clock_button == null:
		_fail("The career home is missing the company insignia, company identity card, name, balance, date, or game clock control.")
		return
	if company_name_label.text != "TEST MOBILES" or balance_label.text != "$25,000" or date_label.text != "2nd Jan 2020" or clock_button.text != "▶  PLAY":
		_fail("The campus career HUD did not display the configured saved company details.")
		return
	if (company_identity_card.size_flags_horizontal & Control.SIZE_EXPAND) != 0 or company_identity_card.custom_minimum_size.x > 232.1:
		_fail("The company identity card must fit its name instead of expanding across the remaining HUD width.")
		return
	var short_company_card_width := company_identity_card.custom_minimum_size.x
	campus.call("update_career_hud", "INTERNATIONAL TECHNOLOGY HOLDINGS GROUP", "$32,500", "3rd Jan 2020", false)
	var long_company_card_width := company_identity_card.custom_minimum_size.x
	if long_company_card_width <= short_company_card_width or long_company_card_width > 232.1:
		_fail("The company identity card width did not adapt to the longer company name within its maximum width.")
		return
	campus.call("update_career_hud", "UPDATED MOBILE CO", "$32,500", "3rd Jan 2020", false)
	if company_name_label.text != "UPDATED MOBILE CO" or balance_label.text != "$32,500" or date_label.text != "3rd Jan 2020" or clock_button.text != "Ⅱ  PAUSE":
		_fail("The career HUD did not update when the active company balance, date, or clock state changed.")
		return
	campus_controls_layer.visible = false
	await process_frame
	await process_frame
	if not campus_controls_layer.visible:
		_fail("The active campus did not restore its touch controls after an unexpected CanvasLayer visibility loss.")
		return
	for visibility_cycle in range(3):
		campus.call("set_career_home_overlay_visible", false)
		if campus_controls_layer.visible:
			_fail("The campus control layer did not hide during a suspended screen transition.")
			return
		campus.call("set_career_home_overlay_visible", true)
		if not campus_controls_layer.visible:
			_fail("The campus control layer did not restore after a suspended screen transition.")
			return
	clock_button.emit_signal("pressed")
	if not bool(observed_signals["clock_toggle_requested"]):
		_fail("The campus Pause/Play control did not forward the career clock request.")
		return

	var dimensions: Vector2 = campus.get_meta("map_dimensions", Vector2.ZERO)
	if dimensions != Vector2(800.0, 600.0):
		_fail("The campus footprint is not 800 m × 600 m.")
		return
	if not is_equal_approx(float(campus.get_meta("map_area_square_metres", 0.0)), 480000.0):
		_fail("The campus area metadata is incorrect.")
		return

	var sections := campus.get_node_or_null("Campus_Sections") as Node3D
	if sections == null or int(sections.get_meta("section_count", 0)) != 16:
		_fail("The campus does not contain all sixteen planned plots.")
		return
	if sections.get_meta("layout", "") != "four_columns_four_rows" or int(sections.get_meta("grid_columns", 0)) != 4 or int(sections.get_meta("grid_rows", 0)) != 4:
		_fail("The campus plot layout is not the planned 4 by 4 arrangement.")
		return
	var expected_columns := [-300.0, -100.0, 100.0, 300.0]
	var expected_rows := [225.0, 75.0, -75.0, -225.0]
	for section_index in range(1, 17):
		var zero_based_index := section_index - 1
		var row_index := floori(float(zero_based_index) / 4.0)
		var column_index := zero_based_index % 4
		var section := sections.get_node_or_null("Section_%02d" % section_index) as Node3D
		if section == null or str(section.get_meta("section_name", "")).is_empty():
			_fail("Campus plot %d or its name metadata is missing." % section_index)
			return
		if str(section.get_meta("property_id", "")) != "LAND-%02d" % section_index or not bool(section.get_meta("is_individual_land_parcel", false)):
			_fail("Campus plot %d is not represented as its own independent parcel." % section_index)
			return
		if not is_equal_approx(float(section.get_meta("property_area_square_metres", 0.0)), 25944.0):
			_fail("Campus plot %d has an incorrect independently measured area." % section_index)
			return
		if section.position.distance_to(Vector3(expected_columns[column_index], 0.0, expected_rows[row_index])) > 0.001:
			_fail("Campus plot %d is not in its expected 4 by 4 grid position." % section_index)
			return
		if bool(section.get_meta("access_granted", false)) != (section_index == 1):
			_fail("Only Plot 1 should have starter access when a new career begins.")
			return
		var section_sign := section.get_node_or_null("SectionSign/SectionName") as Label3D
		if section_sign == null or not section_sign.text.contains("PLOT %02d" % section_index):
			_fail("Campus plot %d does not have its own visible plot sign." % section_index)
			return
		var expected_sides: Array[String] = []
		if column_index > 0:
			expected_sides.append("west")
		if column_index < 3:
			expected_sides.append("east")
		if row_index > 0:
			expected_sides.append("north")
		if row_index < 3:
			expected_sides.append("south")
		var actual_sides: Array = section.get_meta("entrance_sides", [])
		if actual_sides != expected_sides:
			_fail("Plot %d has an outward-facing entrance or is missing an inward-facing entrance." % section_index)
			return

	var asphalt_roads := campus.get_node_or_null("Campus_Asphalt_Roads") as MeshInstance3D
	var road_markings := campus.get_node_or_null("Campus_Road_Markings") as MultiMeshInstance3D
	if asphalt_roads == null or asphalt_roads.mesh == null or int(asphalt_roads.get_meta("road_corridor_count", 0)) != 6 or int(asphalt_roads.get_meta("asphalt_surface_quad_count", 0)) != 15:
		_fail("The six-corridor merged asphalt road network is missing or incomplete.")
		return
	if road_markings == null or road_markings.multimesh == null or int(road_markings.get_meta("dash_count", 0)) < 100 or int(road_markings.get_meta("dash_count", 0)) > 500:
		_fail("The lightweight instanced asphalt road markings are missing or exceed their intended budget.")
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
	if fence_rails.multimesh == null or fence_rails.multimesh.instance_count < 100:
		_fail("The wooden fence rail instances are missing or incomplete.")
		return
	if fence_pickets.multimesh == null or fence_pickets.multimesh.instance_count < 25000:
		_fail("The vertical wooden picket panels are missing or incomplete.")
		return
	if fence_collisions.get_child_count() < 80 or not bool(fence_collisions.get_meta("blocks_player", false)):
		_fail("The wooden plot boundaries do not have complete player-blocking collision.")
		return

	var property_gates := fences.get_node_or_null("Property_Gates") as Node3D
	if property_gates == null or property_gates.get_child_count() != 48 or int(property_gates.get_meta("gate_count", 0)) != 48 or int(property_gates.get_meta("locked_gate_count", 0)) != 46:
		_fail("The campus must have 48 individual internal-facing plot gates, with only Plot 1's two entrances open.")
		return

	var expected_gate_total := 0
	for parcel_number in range(1, 17):
		var zero_based_index := parcel_number - 1
		var row_index := floori(float(zero_based_index) / 4.0)
		var column_index := zero_based_index % 4
		var center := Vector3(expected_columns[column_index], 0.0, expected_rows[row_index])
		var expected_sides: Array[String] = []
		if column_index > 0:
			expected_sides.append("west")
		if column_index < 3:
			expected_sides.append("east")
		if row_index > 0:
			expected_sides.append("north")
		if row_index < 3:
			expected_sides.append("south")
		for side in expected_sides:
			expected_gate_total += 1
			var gate_name := "PropertyGate_%02d_%s" % [parcel_number, side.capitalize()]
			var property_gate := property_gates.get_node_or_null(gate_name) as StaticBody3D
			var gate_collision := property_gate.get_node_or_null("GateCollision") as CollisionShape3D if is_instance_valid(property_gate) else null
			var gate_mesh := property_gate.get_node_or_null("GateMesh") as MeshInstance3D if is_instance_valid(property_gate) else null
			if property_gate == null or gate_collision == null or gate_mesh == null or gate_mesh.mesh == null:
				_fail("Plot %02d is missing its own physical 3D %s gate or blocking collision." % [parcel_number, side])
				return
			var should_be_locked := parcel_number != 1
			if property_gate.visible != should_be_locked or gate_collision.disabled == should_be_locked:
				_fail("Plot %02d has an incorrect initial gate visibility or collision state." % parcel_number)
				return
			if str(property_gate.get_meta("property_id", "")) != "LAND-%02d" % parcel_number or str(property_gate.get_meta("entrance_side", "")) != side or not bool(property_gate.get_meta("faces_campus_interior", false)) or bool(property_gate.get_meta("gate_locked", false)) != should_be_locked:
				_fail("Plot %02d has a wrongly assigned or outward-facing gate." % parcel_number)
				return
			var expected_gate_position := center
			var expected_gate_yaw := 0.0
			match side:
				"north":
					expected_gate_position += Vector3(0.0, 0.0, 69.0)
					expected_gate_yaw = 0.0
				"south":
					expected_gate_position += Vector3(0.0, 0.0, -69.0)
					expected_gate_yaw = PI
				"east":
					expected_gate_position += Vector3(94.0, 0.0, 0.0)
					expected_gate_yaw = PI * 0.5
				"west":
					expected_gate_position += Vector3(-94.0, 0.0, 0.0)
					expected_gate_yaw = -PI * 0.5
			if property_gate.position.distance_to(expected_gate_position) > 0.001 or not is_equal_approx(property_gate.rotation.y, expected_gate_yaw):
				_fail("Plot %02d's %s gate is not mounted on its own inward-facing plot boundary." % [parcel_number, side])
				return
	if expected_gate_total != 48:
		_fail("The internal plot gate count does not total 48, or an outer-perimeter gate was added.")
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
	var grass_instances := grass.multimesh
	for grass_index in range(grass_instances.instance_count):
		var grass_position := grass_instances.get_instance_transform(grass_index).origin
		if bool(campus.call("_is_on_asphalt_road", grass_position.x, grass_position.z)):
			_fail("Grass clumps must remain off the asphalt corridors so the roads stay visibly paved.")
			return
	if campus.get_node_or_null("NearPlayer_Grass") != null or bool(campus.get_meta("movement_grass_follow_enabled", true)):
		_fail("Player movement must not trigger or carry a regenerating near-player grass layer.")
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
	var tree_collisions := campus.get_node_or_null("Campus_Tree_Collisions") as StaticBody3D
	if tree_collisions == null or tree_collisions.get_child_count() != 44 or int(tree_collisions.get_meta("tree_collision_count", 0)) != 44:
		_fail("Every campus tree trunk must have a blocking physics collider.")
		return
	var player := campus.get_node_or_null("PlayerCharacter") as CharacterBody3D
	if player == null or player.get_node_or_null("Humanoid_Collision") == null:
		_fail("The first playable humanoid character or its collision body is missing.")
		return
	if player.collision_layer != 1 or player.collision_mask != 1:
		_fail("The player collision layer and mask are not configured to collide with campus fences.")
		return
	if player.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
		_fail("The campus player must explicitly use physics transform interpolation.")
		return
	if player.position.distance_to(Vector3(-366.0, 0.0, 0.0)) > 0.001 or campus.get_meta("player_spawn_zone", "") != "central_dividing_aisle":
		_fail("The player must spawn on the central dividing aisle, outside every land parcel.")
		return
	if not is_equal_approx(float(campus.get_meta("central_dividing_aisle_width_metres", 0.0)), 12.0):
		_fail("The central dividing aisle must preserve the full 12-metre separation between plot rows.")
		return
	if not is_equal_approx(float(campus.get("camera_yaw")), PI * 0.5) or campus.get_meta("player_spawn_heading", "") != "east_along_central_aisle":
		_fail("The player must initially face along the central aisle toward the opposing gate rows.")
		return
	if not bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)):
		_fail("Project-wide physics interpolation must be enabled for smooth rendered movement.")
		return
	if campus.get_meta("movement_response", "") != "direct_constant_speed_no_deadzone_no_acceleration":
		_fail("Player movement must use direct continuous joystick velocity without an acceleration ramp.")
		return
	var full_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2(0.0, 1.0))
	var slight_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2(0.0, 0.001))
	var diagonal_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2(0.7071068, 0.7071068))
	var released_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2.ZERO)
	if not is_equal_approx(full_input_velocity.length(), 2.0):
		_fail("Full joystick input must produce the calibrated 2.0 m/s slide speed.")
		return
	if not is_equal_approx(full_input_velocity.x, 2.0) or not is_equal_approx(full_input_velocity.z, 0.0):
		_fail("Forward movement must follow the central dividing aisle east-west instead of entering either plot row.")
		return
	if not is_equal_approx(slight_input_velocity.length(), 2.0):
		_fail("Any non-zero joystick input, however small, must immediately produce the full 1.5 m/s speed.")
		return
	if not is_equal_approx(diagonal_input_velocity.length(), 2.0):
		_fail("Diagonal movement must remain normalized and must not move faster.")
		return
	if released_input_velocity.length_squared() > 0.000001:
		_fail("Releasing the joystick must stop horizontal movement directly, without glide steps.")
		return
	await physics_frame
	await process_frame
	var aisle_clear_ray := PhysicsRayQueryParameters3D.create(Vector3(-360.0, 0.80, 0.0), Vector3(-348.0, 0.80, 0.0))
	aisle_clear_ray.collision_mask = 1
	aisle_clear_ray.collide_with_bodies = true
	aisle_clear_ray.collide_with_areas = false
	var aisle_clear_hit := campus.get_world_3d().direct_space_state.intersect_ray(aisle_clear_ray)
	if not aisle_clear_hit.is_empty():
		_fail("A perimeter tree or fence collision blocks the central dividing aisle near the starting point.")
		return
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
	var gate_ray := PhysicsRayQueryParameters3D.create(Vector3(-100.0, 1.0, 150.0), Vector3(-100.0, 1.0, 162.0))
	gate_ray.collision_mask = 1
	gate_ray.collide_with_bodies = true
	gate_ray.collide_with_areas = false
	var gate_hit := campus.get_world_3d().direct_space_state.intersect_ray(gate_ray)
	var expected_gate := property_gates.get_node_or_null("PropertyGate_02_South")
	if gate_hit.is_empty() or gate_hit.get("collider") != expected_gate:
		_fail("A physics ray passed through Plot 2's own gate on its south-facing internal fence.")
		return
	var camera := campus.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		_fail("The first-person player camera is missing.")
		return
	if camera.get_parent() != campus or camera.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
		_fail("The first-person camera must remain independent and follow the interpolated player transform manually.")
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
	if not is_equal_approx(float(joystick.get_meta("knob_radius", 0.0)), 44.2) or not is_equal_approx(float(joystick.get_meta("knob_scale_factor", 0.0)), 1.3):
		_fail("The joystick inner knob must be enlarged to exactly 1.3 times its previous radius.")
		return
	if campus.find_child("BackToMenuButton", true, false) != null:
		_fail("The campus overlay must not display a return-to-menu button.")
		return

	var phone_button := campus.find_child("PhoneButton", true, false) as Button
	var first_action_button := campus.find_child("PhoneActionButton1", true, false) as Button
	var second_action_button := campus.find_child("PhoneActionButton2", true, false) as Button
	var fourth_action_button := campus.find_child("PhoneActionButton4", true, false) as Button
	var phone_device := campus.find_child("PhoneDevice", true, false) as SubViewportContainer
	var phone_viewport := campus.find_child("CampusPhoneModelViewport", true, false) as SubViewport
	var phone_model := campus.find_child("CampusOSWorksiteHandsetModel", true, false) as Node3D
	var phone_screen_ui := campus.find_child("PhoneScreenUI", true, false) as Panel
	var phone_home_view := campus.find_child("PhoneHomeScreen", true, false) as Control
	var explore_app_view := campus.find_child("ExploreAppScreen", true, false) as Control
	var explore_app_icon := campus.find_child("ExploreAppIcon", true, false) as Button
	var project_app_icon := campus.find_child("ProjectAppIcon", true, false) as Button
	var explore_back_button := campus.find_child("ExploreBackToHomeButton", true, false) as Button
	var explore_status_label := campus.find_child("ExploreStatusLabel", true, false) as Label
	var worksite_app_icon := campus.find_child("WorksiteAppIcon", true, false) as Button
	var research_app_icon := campus.find_child("ResearchAppIcon", true, false) as Button
	var staffs_app_icon := campus.find_child("StaffsAppIcon", true, false) as Button
	var products_app_icon := campus.find_child("ProductsAppIcon", true, false) as Button
	var marketing_app_icon := campus.find_child("MarketingAppIcon", true, false) as Button
	var media_app_icon := campus.find_child("MediaAppIcon", true, false) as Button
	var office_app_icon := campus.find_child("OfficeAppIcon", true, false) as Button
	var statistics_app_icon := campus.find_child("StatisticsAppIcon", true, false) as Button
	if phone_button == null or first_action_button == null or second_action_button == null or fourth_action_button == null or phone_device == null or phone_viewport == null or phone_model == null or phone_screen_ui == null or phone_home_view == null or explore_app_view == null or explore_app_icon == null or project_app_icon == null or explore_back_button == null or explore_status_label == null or worksite_app_icon == null or research_app_icon == null or staffs_app_icon == null or products_app_icon == null or marketing_app_icon == null or media_app_icon == null or office_app_icon == null or statistics_app_icon == null or player == null:
		_fail("The phone controls, powered display UI, Explore app, player, or shared OS Worksite handset model is missing.")
		return
	var phone_controls: Array[Button] = [
		first_action_button,
		second_action_button,
		phone_button,
		fourth_action_button
	]
	if phone_controls[2] != phone_button or not bool(phone_button.get_meta("phone_toggle", false)):
		_fail("The phone toggle must occupy the third position in the four-button stack.")
		return
	for control_button in phone_controls:
		if control_button.custom_minimum_size != Vector2(54.0, 54.0) or control_button.size != Vector2(54.0, 54.0):
			_fail("All four right-side controls must match the existing 54-by-54 phone toggle size.")
			return
		if control_button.mouse_filter != Control.MOUSE_FILTER_STOP:
			_fail("Each right-side button must capture its own touch input.")
			return
	for placeholder_button in [first_action_button, second_action_button, fourth_action_button]:
		if not bool(placeholder_button.get_meta("functionless", false)) or not placeholder_button.get_signal_connection_list("pressed").is_empty():
			_fail("The three reserved buttons must remain functionless until assigned.")
			return
	for button_index in range(1, phone_controls.size()):
		var previous_button := phone_controls[button_index - 1]
		var current_button := phone_controls[button_index]
		if not is_equal_approx(current_button.position.x, phone_controls[0].position.x) or current_button.position.y < previous_button.position.y + 54.0:
			_fail("The four phone controls must form a non-overlapping vertical stack.")
			return
	if phone_button.custom_minimum_size.x >= joystick.custom_minimum_size.x or phone_button.custom_minimum_size.y >= joystick.custom_minimum_size.y:
		_fail("The phone controls must remain substantially smaller than the movement joystick.")
		return
	if phone_device.position.x + phone_device.size.x > phone_controls[0].position.x - 20.0:
		_fail("The handset must sit left of the control stack with a visible separation.")
		return
	var campus_viewport_height := campus.get_viewport().get_visible_rect().size.y
	var phone_top_gap := phone_device.position.y
	var phone_bottom_gap := campus_viewport_height - phone_device.position.y - phone_device.size.y
	if phone_top_gap > 2.1 or phone_bottom_gap > 2.1 or float(phone_device.get_meta("screen_height_ratio", 0.0)) < 0.99:
		var campus_overlay := campus.find_child("CampusOverlay", true, false) as Control
		var overlay_size := campus_overlay.size if campus_overlay != null else Vector2.ZERO
		_fail(
			"The campus handset must nearly fill the landscape screen height with only a two-pixel top and bottom gap. "
			+ "top=%.2f bottom=%.2f viewport_h=%.2f overlay_h=%.2f handset_y=%.2f handset_h=%.2f ratio=%.4f"
			% [phone_top_gap, phone_bottom_gap, campus_viewport_height, overlay_size.y, phone_device.position.y, phone_device.size.y, float(phone_device.get_meta("screen_height_ratio", 0.0))]
		)
		return
	if phone_button.mouse_filter != Control.MOUSE_FILTER_STOP or phone_device.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("The phone controls must capture their own touches without disabling the joystick.")
		return
	if phone_device.visible or phone_screen_ui.visible or not bool(phone_device.get_meta("screen_powered", false)) or not bool(phone_screen_ui.get_meta("screen_powered", false)):
		_fail("The handset must start hidden while its screen system is powered and ready.")
		return
	if not phone_home_view.visible or explore_app_view.visible or phone_screen_ui.get_meta("active_app") != "home":
		_fail("The phone must boot to its home screen before an app is opened.")
		return
	if explore_app_icon.text.is_empty() or explore_app_icon.tooltip_text != "Open Explore":
		_fail("The phone home screen does not contain a launchable Explore app icon.")
		return
	if project_app_icon.tooltip_text != "Open Project":
		_fail("The Project app launch icon is missing from the campus phone home screen.")
		return
	if worksite_app_icon.tooltip_text != "Open Worksite" or research_app_icon.tooltip_text != "Open Research" or staffs_app_icon.tooltip_text != "Open Staffs":
		_fail("The Worksite, Research, and Staffs app launch icons are missing from the phone home screen.")
		return
	if int(phone_screen_ui.get_meta("home_app_count", 0)) != 10:
		_fail("The phone home screen must contain the ten current career navigation apps.")
		return
	var app_grid := campus.find_child("PhoneHomeAppGrid", true, false) as GridContainer
	if app_grid == null or app_grid.columns != 3:
		_fail("The campus phone must arrange the full app collection in a three-column grid.")
		return
	var app_route_requests: Array[String] = []
	campus.worksite_launch_requested.connect(func(worksite_id: String): app_route_requests.append("worksite:" + worksite_id))
	campus.research_launch_requested.connect(func(research_id: String): app_route_requests.append("research:" + research_id))
	campus.project_launch_requested.connect(func(): app_route_requests.append("project"))
	campus.staff_launch_requested.connect(func(staff_screen_id: String): app_route_requests.append("staffs:" + staff_screen_id))

	var phone_viewport_ratio := float(phone_viewport.size.x) / maxf(float(phone_viewport.size.y), 1.0)
	if not phone_viewport.transparent_bg or phone_viewport_ratio < 0.49 or phone_viewport_ratio > 0.51:
		_fail("The handset must render in its own transparent, portrait SubViewport matching the physical handset ratio.")
		return

	var chassis := phone_model.find_child("PhoneChassis", true, false) as MeshInstance3D
	var inset := phone_model.find_child("DisplayInsetFrame", true, false) as MeshInstance3D
	var screen := phone_model.find_child("PhoneScreenSurface", true, false) as MeshInstance3D
	var power_key := phone_model.find_child("PowerButton", true, false) as MeshInstance3D
	var volume_up := phone_model.find_child("VolumeUpButton", true, false) as MeshInstance3D
	var volume_down := phone_model.find_child("VolumeDownButton", true, false) as MeshInstance3D
	var phone_camera := phone_model.find_child("PhonePreviewCamera", true, false) as Camera3D
	if chassis == null or inset == null or screen == null or power_key == null or volume_up == null or volume_down == null or phone_camera == null:
		_fail("The campus phone does not contain the shared OS Worksite chassis, glass, side keys, and fixed preview camera.")
		return
	if power_key.position.x <= 0.0 or volume_up.position.x >= 0.0 or volume_down.position.x >= 0.0:
		_fail("Campus phone volume keys must sit on the handset edge directly opposite the power key.")
		return
	var volume_pair_center_y := (volume_up.position.y + volume_down.position.y) * 0.5
	if not is_equal_approx(volume_pair_center_y, power_key.position.y) or volume_up.position.y <= power_key.position.y or volume_down.position.y >= power_key.position.y or not is_equal_approx(volume_up.position.y - volume_down.position.y, 0.24):
		_fail("Campus phone volume keys are not raised and centered opposite the power key.")
		return

	var body_bounds := chassis.mesh.get_aabb()
	if not is_equal_approx(body_bounds.size.x, 1.45) or not is_equal_approx(body_bounds.size.y, 2.92) or not is_equal_approx(body_bounds.size.z, 0.13):
		_fail("The campus handset no longer matches the physical OS Worksite phone dimensions.")
		return
	var screen_material := screen.material_override as StandardMaterial3D
	if screen_material == null or screen_material.albedo_texture == null or screen_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		_fail("The 3D phone glass is missing its powered-off screen texture.")
		return
	var screen_image := (screen_material.albedo_texture as ImageTexture).get_image()
	if screen_image.get_pixel(0, 0) == Color.BLACK:
		_fail("The powered-on handset display still uses a fully black screen texture.")
		return
	if phone_model.rotation != Vector3.ZERO or phone_camera.position != Vector3(0.0, 0.0, 4.6) or phone_camera.basis != Basis.IDENTITY:
		_fail("The shared handset camera and model must remain fixed and non-rotatable.")
		return
	if not bool(phone_device.get_meta("phone_fixed", false)) or not bool(phone_model.get_meta("rotation_locked", false)):
		_fail("The opened handset must be marked as a fixed, non-rotatable phone.")
		return

	var handset_ratio := phone_device.size.x / maxf(phone_device.size.y, 1.0)
	if handset_ratio < 0.49 or handset_ratio > 0.51 or phone_device.size.y < get_root().get_visible_rect().size.y * 0.95:
		_fail("The opened handset is not using the shared OS Worksite handset proportions.")
		return
	if phone_device.position.x <= joystick.position.x + joystick.size.x:
		_fail("The phone handset overlaps the left movement joystick.")
		return
	phone_button.emit_signal("pressed")
	if not phone_device.visible or not phone_screen_ui.visible:
		_fail("Tapping the phone launcher did not display the powered handset screen.")
		return
	if phone_model.rotation != Vector3.ZERO:
		_fail("Opening the phone changed the fixed handset orientation.")
		return

	explore_app_icon.emit_signal("pressed")
	if phone_home_view.visible or not explore_app_view.visible or phone_screen_ui.get_meta("active_app") != "Explore":
		_fail("Tapping the Explore icon did not launch the app inside the phone.")
		return
	if campus.find_children("ExploreSectionButton_*", "Button", true, false).size() != 16:
		_fail("The Explore app must list all sixteen campus plots.")
		return
	for section_index in range(16):
		var section_button := campus.find_child("ExploreSectionButton_%02d" % (section_index + 1), true, false) as Button
		if section_button == null or int(section_button.get_meta("campus_section_index", -1)) != section_index:
			_fail("The Explore destination list is missing or has an incorrect section index.")
			return
		var expected_access_text := "OPEN" if section_index == 0 else "LOCKED"
		if not section_button.text.contains(expected_access_text):
			_fail("The Explore list must visibly label each parcel as OPEN or LOCKED without hiding it.")
			return

	var seventh_section_button := campus.find_child("ExploreSectionButton_07", true, false) as Button
	var starter_player_position := player.global_position
	seventh_section_button.emit_signal("pressed")
	if str(campus.get_meta("last_locked_land_request", "")) != "LAND-07":
		_fail("Selecting a locked parcel did not register the access restriction.")
		return
	if player.global_position != starter_player_position or player.velocity != Vector3.ZERO:
		_fail("The Explore app bypassed a locked land entrance and transported the player into an unacquired parcel.")
		return
	if not explore_status_label.text.contains("LAND-07") or not explore_status_label.text.contains("locked"):
		_fail("The Explore app did not explain why the selected parcel is inaccessible.")
		return

	explore_back_button.emit_signal("pressed")
	if not phone_home_view.visible or explore_app_view.visible or phone_screen_ui.get_meta("active_app") != "home":
		_fail("The Explore app back control did not return to the phone home screen.")
		return
	phone_button.emit_signal("pressed")
	if phone_device.visible or phone_screen_ui.visible:
		_fail("The phone launcher cannot close the handset display.")
		return

	for removed_page_name in ["WorksiteAppScreen", "ResearchAppScreen", "StaffsAppScreen"]:
		if campus.find_child(removed_page_name, true, false) != null:
			_fail("The %s legacy in-phone chooser should not exist; its gateway now opens as a standalone screen." % removed_page_name)
			return

	phone_button.emit_signal("pressed")
	worksite_app_icon.emit_signal("pressed")
	if app_route_requests.back() != "worksite:create" or phone_device.visible or phone_screen_ui.visible or not phone_home_view.visible:
		_fail("Worksite did not launch its standalone Create gateway directly from the campus phone.")
		return

	phone_button.emit_signal("pressed")
	research_app_icon.emit_signal("pressed")
	if app_route_requests.back() != "research:hub" or phone_device.visible or phone_screen_ui.visible or not phone_home_view.visible:
		_fail("Research did not launch its standalone gateway directly from the campus phone.")
		return

	phone_button.emit_signal("pressed")
	staffs_app_icon.emit_signal("pressed")
	if app_route_requests.back() != "staffs:hub" or phone_device.visible or phone_screen_ui.visible or not phone_home_view.visible:
		_fail("Staffs did not launch its standalone gateway directly from the campus phone.")
		return

	phone_button.emit_signal("pressed")
	products_app_icon.emit_signal("pressed")
	if not (campus.find_child("ProductsAppScreen", true, false) as Control).visible:
		_fail("The Products app did not open inside the phone.")
		return
	campus.find_child("ProductsBackToHomeButton", true, false).emit_signal("pressed")
	marketing_app_icon.emit_signal("pressed")
	if not (campus.find_child("MarketingAppScreen", true, false) as Control).visible:
		_fail("The Marketing app did not open inside the phone.")
		return
	campus.find_child("MarketingBackToHomeButton", true, false).emit_signal("pressed")
	media_app_icon.emit_signal("pressed")
	if not (campus.find_child("MediaAppScreen", true, false) as Control).visible:
		_fail("The Media app did not open inside the phone.")
		return
	campus.find_child("MediaBackToHomeButton", true, false).emit_signal("pressed")
	statistics_app_icon.emit_signal("pressed")
	if not (campus.find_child("StatisticsAppScreen", true, false) as Control).visible:
		_fail("The Statistics app did not open inside the phone.")
		return
	campus.find_child("StatisticsBackToHomeButton", true, false).emit_signal("pressed")
	office_app_icon.emit_signal("pressed")
	if player.global_position != starter_player_position or not explore_app_view.visible or not explore_status_label.text.contains("LAND-02"):
		_fail("The Office shortcut bypassed the locked corporate-office land gate instead of showing the access restriction.")
		return

	var seventh_gate := property_gates.get_node_or_null("PropertyGate_07_North") as StaticBody3D
	var seventh_gate_collision := seventh_gate.get_node_or_null("GateCollision") as CollisionShape3D if is_instance_valid(seventh_gate) else null
	if not bool(campus.call("set_land_parcel_access", "LAND-07", true, "rented")):
		_fail("The parcel access API rejected a valid rental access update.")
		return
	var seventh_section := sections.get_node_or_null("Section_07") as Node3D
	var seventh_explore_button := campus.find_child("ExploreSectionButton_07", true, false) as Button
	var opened_seventh_gate_count := 0
	for gate_value in property_gates.get_children():
		var gate := gate_value as StaticBody3D
		if is_instance_valid(gate) and str(gate.get_meta("property_id", "")) == "LAND-07":
			opened_seventh_gate_count += 1
			var collision := gate.get_node_or_null("GateCollision") as CollisionShape3D
			if gate.visible or collision == null or not collision.disabled:
				_fail("Granting Plot 7 access did not open and disable all of its individual gates.")
				return
	if opened_seventh_gate_count != 4 or seventh_gate.visible or not seventh_gate_collision.disabled or not bool(seventh_section.get_meta("access_granted", false)) or not seventh_explore_button.text.contains("OPEN"):
		_fail("Granting Plot 7 access did not open its four gates, disable their colliders, and refresh Explore.")
		return
	if not bool(campus.call("set_land_parcel_access", "LAND-07", false, "not_acquired")):
		_fail("The parcel access API could not re-lock an inactive parcel.")
		return
	var relocked_seventh_gate_count := 0
	for gate_value in property_gates.get_children():
		var gate := gate_value as StaticBody3D
		if is_instance_valid(gate) and str(gate.get_meta("property_id", "")) == "LAND-07":
			relocked_seventh_gate_count += 1
			var collision := gate.get_node_or_null("GateCollision") as CollisionShape3D
			if not gate.visible or collision == null or collision.disabled:
				_fail("Re-locking Plot 7 did not restore all four visible blocking gates.")
				return
	if relocked_seventh_gate_count != 4 or not seventh_gate.visible or seventh_gate_collision.disabled or bool(seventh_section.get_meta("access_granted", true)) or not seventh_explore_button.text.contains("LOCKED"):
		_fail("Re-locking Plot 7 did not restore its four gates and locked Explore status.")
		return
	if bool(campus.call("set_land_parcel_access", "LAND-01", false, "not_acquired")):
		_fail("The campus access API allowed the currently active starter plot to be locked.")
		return
	for starter_side in ["East", "South"]:
		var starter_gate := property_gates.get_node_or_null("PropertyGate_01_%s" % starter_side) as StaticBody3D
		var starter_collision := starter_gate.get_node_or_null("GateCollision") as CollisionShape3D if is_instance_valid(starter_gate) else null
		if starter_gate == null or starter_gate.visible or starter_collision == null or not starter_collision.disabled:
			_fail("Rejecting a lock on Plot 1 changed one of its open internal entrances.")
			return
	if not bool(sections.get_node("Section_01").get_meta("access_granted", false)):
		_fail("Rejecting a lock on the active starter plot changed its access state.")
		return

	project_app_icon.emit_signal("pressed")
	if app_route_requests.back() != "project" or phone_device.visible or phone_screen_ui.visible:
		_fail("The Project app did not request its standalone scene and close the phone.")
		return
	if phone_screen_ui.get_meta("active_app") != "home" or not phone_home_view.visible:
		_fail("Launching Project did not leave the phone on its home screen.")
		return

	print("COMPANY_CAMPUS_SMOKE_TEST: PASS")
	campus.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("COMPANY_CAMPUS_SMOKE_TEST: FAIL: " + message)
	quit(1)
