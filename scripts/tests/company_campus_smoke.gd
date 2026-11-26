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
	var campus_generated := false
	var clock_toggle_requested := false
	campus.setup_completed.connect(func(): campus_generated = true)
	campus.game_clock_toggle_requested.connect(func(): clock_toggle_requested = true)
	root.add_child(campus)
	while not campus_generated:
		await process_frame

	if not bool(campus.get_meta("career_home_scene", false)) or not bool(campus.get_meta("campus_generation_complete", false)):
		_fail("The campus did not complete its generated career-home setup.")
		return
	var career_status := campus.find_child("CampusCareerStatusBar", true, false) as PanelContainer
	var company_insignia := campus.find_child("CampusCompanyInsignia", true, false) as TextureRect
	var company_name_label := campus.find_child("CampusCompanyName", true, false) as Label
	var balance_label := campus.find_child("CampusBalanceValue", true, false) as Label
	var date_label := campus.find_child("CampusDateValue", true, false) as Label
	var clock_button := campus.find_child("CampusGameClockControl", true, false) as Button
	if career_status == null or company_insignia == null or company_insignia.texture == null or company_name_label == null or balance_label == null or date_label == null or clock_button == null:
		_fail("The career home is missing the company insignia, name, balance, date, or game clock control.")
		return
	if company_name_label.text != "TEST MOBILES" or balance_label.text != "$25,000" or date_label.text != "2nd Jan 2020" or clock_button.text != "▶  PLAY":
		_fail("The campus career HUD did not display the configured saved company details.")
		return
	campus.call("update_career_hud", "UPDATED MOBILE CO", "$32,500", "3rd Jan 2020", false)
	if company_name_label.text != "UPDATED MOBILE CO" or balance_label.text != "$32,500" or date_label.text != "3rd Jan 2020" or clock_button.text != "Ⅱ  PAUSE":
		_fail("The career HUD did not update when the active company balance, date, or clock state changed.")
		return
	clock_button.emit_signal("pressed")
	if not clock_toggle_requested:
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
	if campus.get_meta("movement_response", "") != "direct_analog_slide_no_acceleration_ramp":
		_fail("Player movement must use direct continuous joystick velocity without an acceleration ramp.")
		return
	var full_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2(0.0, 1.0))
	var half_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2(0.0, 0.5))
	var diagonal_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2(0.7071068, 0.7071068))
	var released_input_velocity: Vector3 = campus.call("_calculate_horizontal_velocity", Vector2.ZERO)
	if not is_equal_approx(full_input_velocity.length(), 1.5):
		_fail("Full joystick input must produce the calibrated 1.5 m/s slide speed.")
		return
	if not is_equal_approx(half_input_velocity.length(), 0.75):
		_fail("Half joystick input must produce exactly half speed, without squared analog input.")
		return
	if not is_equal_approx(diagonal_input_velocity.length(), 1.5):
		_fail("Diagonal movement must remain normalized and must not move faster.")
		return
	if released_input_velocity.length_squared() > 0.000001:
		_fail("Releasing the joystick must stop horizontal movement directly, without glide steps.")
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
	var explore_back_button := campus.find_child("ExploreBackToHomeButton", true, false) as Button
	var explore_status_label := campus.find_child("ExploreStatusLabel", true, false) as Label
	var worksite_app_view := campus.find_child("WorksiteAppScreen", true, false) as Control
	var worksite_app_icon := campus.find_child("WorksiteAppIcon", true, false) as Button
	var research_app_view := campus.find_child("ResearchAppScreen", true, false) as Control
	var research_app_icon := campus.find_child("ResearchAppIcon", true, false) as Button
	var staffs_app_view := campus.find_child("StaffsAppScreen", true, false) as Control
	var staffs_app_icon := campus.find_child("StaffsAppIcon", true, false) as Button
	var create_app_icon := campus.find_child("CreateAppIcon", true, false) as Button
	var products_app_icon := campus.find_child("ProductsAppIcon", true, false) as Button
	var marketing_app_icon := campus.find_child("MarketingAppIcon", true, false) as Button
	var media_app_icon := campus.find_child("MediaAppIcon", true, false) as Button
	var office_app_icon := campus.find_child("OfficeAppIcon", true, false) as Button
	var statistics_app_icon := campus.find_child("StatisticsAppIcon", true, false) as Button
	if phone_button == null or first_action_button == null or second_action_button == null or fourth_action_button == null or phone_device == null or phone_viewport == null or phone_model == null or phone_screen_ui == null or phone_home_view == null or explore_app_view == null or explore_app_icon == null or explore_back_button == null or explore_status_label == null or worksite_app_view == null or worksite_app_icon == null or research_app_view == null or research_app_icon == null or staffs_app_view == null or staffs_app_icon == null or create_app_icon == null or products_app_icon == null or marketing_app_icon == null or media_app_icon == null or office_app_icon == null or statistics_app_icon == null or player == null:
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
	if worksite_app_icon.tooltip_text != "Open Worksite" or research_app_icon.tooltip_text != "Open Research" or staffs_app_icon.tooltip_text != "Open Staffs":
		_fail("The Worksite, Research, and Staffs app launch icons are missing from the phone home screen.")
		return
	if int(phone_screen_ui.get_meta("home_app_count", 0)) != 10:
		_fail("The phone home screen must contain the ten career navigation apps.")
		return
	var app_grid := campus.find_child("PhoneHomeAppGrid", true, false) as GridContainer
	if app_grid == null or app_grid.columns != 3:
		_fail("The campus phone must arrange the full app collection in a three-column grid.")
		return
	var app_route_requests: Array[String] = []
	campus.worksite_launch_requested.connect(func(worksite_id: String): app_route_requests.append("worksite:" + worksite_id))
	campus.research_launch_requested.connect(func(research_id: String): app_route_requests.append("research:" + research_id))
	campus.staff_launch_requested.connect(func(staff_screen_id: String): app_route_requests.append("staffs:" + staff_screen_id))
	campus.legacy_app_launch_requested.connect(func(app_id: String): app_route_requests.append("legacy:" + app_id))
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
	if campus.find_children("ExploreSectionButton_*", "Button", true, false).size() != 8:
		_fail("The Explore app must list all eight campus sections.")
		return
	for section_index in range(8):
		var section_button := campus.find_child("ExploreSectionButton_%02d" % (section_index + 1), true, false) as Button
		if section_button == null or int(section_button.get_meta("campus_section_index", -1)) != section_index:
			_fail("The Explore destination list is missing or has an incorrect section index.")
			return

	var seventh_section_button := campus.find_child("ExploreSectionButton_07", true, false) as Button
	seventh_section_button.emit_signal("pressed")
	if int(campus.get_meta("last_explore_section", 0)) != 7 or int(player.get_meta("last_explore_section_index", -1)) != 6:
		_fail("Selecting a campus destination did not record the chosen section.")
		return
	if player.global_position != Vector3(100.0, 0.0, -150.0) or player.velocity != Vector3.ZERO:
		_fail("The Explore app did not transport the player to the selected section center.")
		return
	if not explore_status_label.text.contains("Logistics & Warehouses"):
		_fail("The Explore app did not confirm arrival at the selected section.")
		return

	explore_back_button.emit_signal("pressed")
	if not phone_home_view.visible or explore_app_view.visible or phone_screen_ui.get_meta("active_app") != "home":
		_fail("The Explore app back control did not return to the phone home screen.")
		return
	phone_button.emit_signal("pressed")
	if phone_device.visible or phone_screen_ui.visible:
		_fail("The phone launcher cannot close the handset display.")
		return

	for option_id in ["Phone", "Camera", "Os", "Processor"]:
		phone_button.emit_signal("pressed")
		worksite_app_icon.emit_signal("pressed")
		var worksite_option := campus.find_child("WorksiteOption_" + option_id, true, false) as Button
		if worksite_option == null or not worksite_app_view.visible:
			_fail("The Worksite app did not show the %s workspace option." % option_id)
			return
		worksite_option.emit_signal("pressed")
		if app_route_requests.back() != "worksite:" + option_id.to_lower() or phone_device.visible or phone_screen_ui.visible:
			_fail("Selecting %s Worksite did not emit the correct scene request and close the phone." % option_id)
			return

	for option_id in ["Hub", "Phone", "Camera", "Processor"]:
		phone_button.emit_signal("pressed")
		research_app_icon.emit_signal("pressed")
		var research_option := campus.find_child("ResearchOption_" + option_id, true, false) as Button
		if research_option == null or not research_app_view.visible:
			_fail("The Research app is missing the %s destination." % option_id)
			return
		research_option.emit_signal("pressed")
		if app_route_requests.back() != "research:" + option_id.to_lower() or phone_device.visible or phone_screen_ui.visible:
			_fail("Selecting %s Research did not emit the correct scene request and close the phone." % option_id)
			return

	for option_id in ["Market", "Management"]:
		phone_button.emit_signal("pressed")
		staffs_app_icon.emit_signal("pressed")
		var staff_option := campus.find_child("StaffsOption_" + option_id, true, false) as Button
		if staff_option == null or not staffs_app_view.visible:
			_fail("The Staffs app is missing the %s destination." % option_id)
			return
		staff_option.emit_signal("pressed")
		if app_route_requests.back() != "staffs:" + option_id.to_lower() or phone_device.visible or phone_screen_ui.visible:
			_fail("Selecting %s did not emit the correct staff scene request and close the phone." % option_id)
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
	if player.global_position != Vector3(-100.0, 0.0, 150.0) or not phone_home_view.visible:
		_fail("The Office app did not take the player to the corporate office section.")
		return

	create_app_icon.emit_signal("pressed")
	if app_route_requests.back() != "legacy:create" or phone_device.visible or phone_screen_ui.visible:
		_fail("The Create app did not request the existing product-creation scene and close the phone.")
		return
	if phone_screen_ui.get_meta("active_app") != "home" or not phone_home_view.visible:
		_fail("External app launches did not leave the phone at its home screen.")
		return

	print("COMPANY_CAMPUS_SMOKE_TEST: PASS")
	campus.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("COMPANY_CAMPUS_SMOKE_TEST: FAIL: " + message)
	quit(1)
