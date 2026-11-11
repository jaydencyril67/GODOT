extends SceneTree

const MainGameScript = preload("res://scripts/digitalworld_game.gd")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")
const ScreenTechnologySystem = preload("res://scripts/screen_technology_system.gd")

var game: Node


func _initialize() -> void:
	call_deferred("_run_transition_checks")


func _run_transition_checks() -> void:
	if not _run_screen_technology_checks():
		return
	game = MainGameScript.new()
	root.add_child(game)
	await process_frame

	# Model an existing Level 1 company so the headquarters is constructed
	# during the initial loading screen and visible on Home.
	game.career = {
		"company_name": "Smoke Test Mobiles",
		"balance": 10000000.0,
		"staff_employees": [{
			"id": "researcher_smoke_01",
			"full_name": "Research Test Engineer",
			"department": "Research",
			"position": "Research Engineer",
			"efficiency": 100,
			"monthly_salary": 250000.0
		}],
		"research_projects": [],
		"research_technologies": {},
		"next_research_project_id": 1
	}
	game.upgrade_level = 1
	game.selected_upgrade = 1

	await game._show_home_scene()
	var initial_home_ready: bool = await _wait_for_headquarters()
	if not initial_home_ready:
		_fail("Initial Home scene did not create its headquarters.")
		return
	var headquarters = game.world_root
	await headquarters.setup_completed
	var original_building = headquarters.building_root
	if not is_instance_valid(original_building):
		_fail("The loading screen did not construct the owned headquarters.")
		return

	# Opening and closing Office changes its controls and camera, not the building.
	game._show_office_hub()
	if game.current_screen != "headquarters" or not headquarters.visible or headquarters.home_mode:
		_fail("Office did not open the active headquarters scene.")
		return
	if game.world_root != headquarters or headquarters.building_root != original_building:
		_fail("Opening Office reconstructed the headquarters instead of reusing it.")
		return

	game._return_home_from_headquarters()
	if game.current_screen != "home" or not headquarters.visible or not headquarters.home_mode:
		_fail("Returning from Office did not restore Home.")
		return
	if game.world_root != headquarters or headquarters.building_root != original_building:
		_fail("Returning from Office replaced the live headquarters building.")
		return

	# Create hides the live world but must not dispose of or rebuild it.
	game._show_create_scene()
	if game.world_root != headquarters or headquarters.visible:
		_fail("Create did not preserve and hide the existing headquarters scene.")
		return
	if headquarters.building_root != original_building:
		_fail("Opening Create replaced the headquarters building.")
		return
	game._return_to_home()
	if game.current_screen != "home" or game.world_root != headquarters or not headquarters.visible:
		_fail("Returning from Create did not restore the original Home scene.")
		return
	if headquarters.building_root != original_building:
		_fail("Returning from Create rebuilt the headquarters building.")
		return

	# Research follows the same retained-world lifecycle as Create.
	game._show_research_scene()
	if game.world_root != headquarters or headquarters.visible:
		_fail("Research did not preserve and hide the existing headquarters scene.")
		return
	if headquarters.building_root != original_building:
		_fail("Opening Research replaced the headquarters building.")
		return

	# Phone now opens the company R&D management centre.
	# The dashboard overlays the existing Research page without rebuilding it.
	var research_page_layer = game.ui_layer
	game._on_research_category_pressed("PHONE")
	if game.current_screen != "research_allocation" or not is_instance_valid(game.research_allocation_dashboard):
		_fail("Phone did not open the R&D management centre.")
		return
	if not is_instance_valid(research_page_layer) or not research_page_layer.visible:
		_fail("Opening the R&D centre hid or replaced the underlying Research page.")
		return
	var dashboard = game.research_allocation_dashboard
	if not dashboard.has_signal("project_commission_requested") or not dashboard.has_signal("project_approve_requested") or not dashboard.has_signal("project_reject_requested"):
		_fail("R&D dashboard project management signals are missing.")
		return
	if not is_instance_valid(dashboard.get_node_or_null("ResearchManagementFrame/ResearchManagementPage/ResearchManagementBody")):
		_fail("The new R&D management workspace did not build.")
		return
	if dashboard.find_child("CreateResearchButton", true, false) == null:
		_fail("The empty research scene did not show its Create Research button.")
		return
	dashboard.call("_open_creation_scene")
	await process_frame
	for control_name in ["ResearchComponentOption", "ResearchNextButton"]:
		if dashboard.find_child(control_name, true, false) == null:
			_fail("The component-selection step is missing %s." % control_name)
			return
	if dashboard.find_child("ResearchStaffScroll", true, false) != null:
		_fail("Staff selection appeared before the component-selection step was completed.")
		return
	dashboard.call("_open_staff_selection_step")
	await process_frame
	for control_name in ["ResearchStaffScroll", "ResearchCreateButton"]:
		if dashboard.find_child(control_name, true, false) == null:
			_fail("The staff-selection step is missing %s." % control_name)
			return
	if dashboard.find_child("ResearchComponentOption", true, false) != null:
		_fail("Component selection remained visible during the staff-selection step.")
		return
	if dashboard.find_child("ResearchInvestmentInput", true, false) != null:
		_fail("Research creation still shows a separate upfront investment field.")
		return
	dashboard.call("_close_creation_scene")
	if dashboard.find_child("HardwareAllocationDial", true, false) != null:
		_fail("The old department percentage dial is still present.")
		return
	var workforce: Dictionary = game.get_research_workforce_summary()
	if int(workforce.get("staff_count", 0)) != 1 or int(workforce.get("available_staff_count", 0)) != 1:
		_fail("The R&D centre did not identify the available Research employee.")
		return

	var duration_test_employees: Array = [
		{"id": "researcher_50", "department": "Research", "efficiency": 50},
		{"id": "researcher_100", "department": "Research", "efficiency": 100},
		{"id": "unassigned_researcher", "department": "Research", "efficiency": 100}
	]
	var single_staff_estimate: Dictionary = ResearchManagerScript.estimate_research("Screen Tech", ["researcher_50"], duration_test_employees)
	if not bool(single_staff_estimate.get("ok", false)) or not is_equal_approx(float(single_staff_estimate.get("expected_duration_days", 0.0)), 29.5):
		_fail("A single 50% assigned researcher did not reduce the 30-day journey by half a day.")
		return
	var combined_staff_estimate: Dictionary = ResearchManagerScript.estimate_research("Screen Tech", ["researcher_50", "researcher_100"], duration_test_employees)
	if not bool(combined_staff_estimate.get("ok", false)) or not is_equal_approx(float(combined_staff_estimate.get("expected_duration_days", 0.0)), 28.5):
		_fail("Combined efficiency from the assigned researchers did not reduce the research duration correctly.")
		return
	var maximum_efficiency_staff: Array = []
	var maximum_efficiency_ids: Array[String] = []
	for staff_index in range(30):
		var staff_id := "researcher_max_%02d" % staff_index
		maximum_efficiency_ids.append(staff_id)
		maximum_efficiency_staff.append({"id": staff_id, "department": "Research", "efficiency": 100})
	var minimum_duration_estimate: Dictionary = ResearchManagerScript.estimate_research("Screen Tech", maximum_efficiency_ids, maximum_efficiency_staff)
	if not bool(minimum_duration_estimate.get("ok", false)) or not is_equal_approx(float(minimum_duration_estimate.get("expected_duration_days", 0.0)), 1.0):
		_fail("Research duration did not respect its one-day minimum.")
		return

	var estimate: Dictionary = ResearchManagerScript.estimate_research("Screen Tech", ["researcher_smoke_01"], game.career.get("staff_employees", []))
	if not bool(estimate.get("ok", false)) or not is_equal_approx(float(estimate.get("expected_duration_days", 0.0)), 29.0) or not is_equal_approx(float(estimate.get("success_chance", 0.0)), 95.0):
		_fail("A 100% assigned researcher did not produce a 29-day estimate and the expected success chance.")
		return

	var commission_result: Dictionary = game.commission_research_project({
		"component": "Screen Tech",
		"staff_ids": ["researcher_smoke_01"]
	})
	if not bool(commission_result.get("ok", false)):
		_fail("A valid R&D project could not be commissioned: %s" % str(commission_result.get("error", "")))
		return
	if absf(float(game.career.get("balance", 0.0)) - 10000000.0) > 0.1:
		_fail("Starting research incorrectly deducted a separate project fee from company funds.")
		return
	var created_project: Dictionary = commission_result.get("project", {})
	# Keep this smoke test deterministic: validation-path coverage must not depend on an RNG roll.
	var commissioned_projects: Array = game.career.get("research_projects", [])
	commissioned_projects[0]["success_chance"] = 100.0
	game.career["research_projects"] = commissioned_projects
	if not is_equal_approx(float(created_project.get("required_research_days", 0.0)), 29.0):
		_fail("The commissioned project did not store its 29-day calendar duration.")
		return
	var early_completed_ids: Array = ResearchManagerScript.advance_projects(game.career, 86400.0 * 28.0, game.game_date_unix + 86400.0 * 28.0)
	var stored_projects: Array = game.career.get("research_projects", [])
	if not early_completed_ids.is_empty() or stored_projects.is_empty() or str(stored_projects[0].get("status", "")) != "active":
		_fail("Research completed before its 29-day calendar duration elapsed.")
		return
	if not is_equal_approx(float(stored_projects[0].get("completed_research_days", 0.0)), 28.0):
		_fail("Research calendar progress did not advance by 28 in-game days.")
		return
	var completed_ids: Array = ResearchManagerScript.advance_projects(game.career, 86400.0, game.game_date_unix + 86400.0 * 29.0)
	if completed_ids.is_empty():
		_fail("The assigned research team did not complete after the full 29-day calendar duration.")
		return
	stored_projects = game.career.get("research_projects", [])
	if stored_projects.is_empty() or str(stored_projects[0].get("status", "")) != "awaiting_validation":
		_fail("Completed R&D work did not move into technical validation.")
		return
	var project_id := str(created_project.get("id", ""))
	if int(game.career.get("research_component_levels", {}).get("Screen Technology", 0)) != 0:
		_fail("R&D unlocked a technology before technical validation was approved.")
		return
	var approval_result: Dictionary = game.approve_research_project(project_id, [{
		"component": "Screen Technology",
		"metric": "Display contrast",
		"value": "Improved test sample",
		"unit": "",
		"notes": "Recorded after prototype testing."
	}])
	if not bool(approval_result.get("ok", false)):
		_fail("A completed R&D project could not pass technical validation: %s" % str(approval_result.get("error", "")))
		return
	if int(game.career.get("research_component_levels", {}).get("Screen Technology", 0)) != 1:
		_fail("Technical approval did not unlock the next screen technology level.")
		return
	var screen_history: Array = game.career.get("research_technologies", {}).get("Screen Technology", [])
	if screen_history.size() != 1 or str(screen_history[0].get("metric", "")) != "Display contrast":
		_fail("Approved R&D findings were not stored in the company's technology records.")
		return
	dashboard.call("configure", game._get_research_dashboard_data())

	game._return_from_research_allocation_dashboard()
	if game.current_screen != "research" or game.ui_layer != research_page_layer or not research_page_layer.visible:
		_fail("Closing the R&D centre did not reveal the original Research page.")
		return
	if is_instance_valid(game.research_allocation_dashboard):
		_fail("Closing the R&D centre did not dispose of its dashboard scene.")
		return

	game._return_home_from_research()
	if game.current_screen != "home" or game.world_root != headquarters or not headquarters.visible:
		_fail("Returning from Research did not restore the original Home scene.")
		return
	if headquarters.building_root != original_building:
		_fail("Returning from Research rebuilt the headquarters building.")
		return

	# Reopening Office after standalone pages must still reuse the same building.
	game._show_office_hub()
	if game.current_screen != "headquarters" or not headquarters.visible:
		_fail("Office failed after returning from Research.")
		return
	if headquarters.building_root != original_building:
		_fail("Reopening Office after Research rebuilt the headquarters.")
		return

	# An Office tier preview may create temporary geometry, but returning Home
	# must restore the original loading-screen HQ node instead of rebuilding it.
	headquarters._show_next_level()
	if headquarters.building_root == original_building or not is_instance_valid(original_building):
		_fail("Office tier preview did not keep the original HQ safely cached.")
		return
	game._return_home_from_headquarters()
	if headquarters.building_root != original_building or not is_instance_valid(original_building):
		_fail("Returning Home from a tier preview rebuilt the original HQ.")
		return

	# Every company tier must rebuild all five buildings as distinct architecture.
	var architecture_valid: bool = await _verify_architectural_progression(headquarters)
	if not architecture_valid:
		return

	print("HOME_OFFICE_TRANSITION_SMOKE_TEST: PASS")
	quit(0)

func _run_screen_technology_checks() -> bool:
	var state: Dictionary = ScreenTechnologySystem.create_state()
	if ScreenTechnologySystem.get_technology_name(0) != "TFT LCD":
		_fail("Screen technology did not start at TFT LCD.")
		return false

	var visual_state: Dictionary = ScreenTechnologySystem.create_state()
	var base_profile: Dictionary = ScreenTechnologySystem.get_visual_profile(visual_state)
	var base_color: Color = base_profile["albedo_color"]
	ScreenTechnologySystem.upgrade(visual_state)
	var darkness_profile: Dictionary = ScreenTechnologySystem.get_visual_profile(visual_state)
	var darkness_color: Color = darkness_profile["albedo_color"]
	if is_equal_approx(base_color.r, darkness_color.r):
		_fail("Darkness upgrades did not change the screen's black depth.")
		return false
	if not is_equal_approx(float(base_profile["roughness"]), float(darkness_profile["roughness"])) or not is_equal_approx(float(base_profile["specular"]), float(darkness_profile["specular"])):
		_fail("A darkness upgrade changed another screen quality.")
		return false

	ScreenTechnologySystem.upgrade(visual_state)
	var shininess_profile: Dictionary = ScreenTechnologySystem.get_visual_profile(visual_state)
	var shininess_color: Color = shininess_profile["albedo_color"]
	if not is_equal_approx(darkness_color.r, shininess_color.r) or is_equal_approx(float(darkness_profile["roughness"]), float(shininess_profile["roughness"])):
		_fail("A shininess upgrade did not independently refine the screen finish.")
		return false
	if not is_equal_approx(float(darkness_profile["specular"]), float(shininess_profile["specular"])):
		_fail("A shininess upgrade changed reflection reduction.")
		return false

	ScreenTechnologySystem.upgrade(visual_state)
	var reflection_profile: Dictionary = ScreenTechnologySystem.get_visual_profile(visual_state)
	var reflection_color: Color = reflection_profile["albedo_color"]
	if is_equal_approx(float(shininess_profile["specular"]), float(reflection_profile["specular"])):
		_fail("Reflection reduction did not change its own screen property.")
		return false
	if not is_equal_approx(shininess_color.r, reflection_color.r) or not is_equal_approx(float(shininess_profile["roughness"]), float(reflection_profile["roughness"])):
		_fail("A reflection reduction upgrade changed another screen quality.")
		return false

	var expected_order := ["darkness", "shininess", "reflection_reduction"]
	for click_index in range(9):
		var result: Dictionary = ScreenTechnologySystem.upgrade(state)
		if str(result.get("quality", "")) != expected_order[click_index % 3]:
			_fail("Screen qualities did not upgrade in the required rotating order.")
			return false
		if click_index < 8 and bool(result.get("technology_unlocked", false)):
			_fail("A screen technology unlocked before all three qualities reached their milestone.")
			return false

	if int(state.get("darkness", 0)) != 3 or int(state.get("shininess", 0)) != 3 or int(state.get("reflection_reduction", 0)) != 3:
		_fail("The first screen milestone did not require all three qualities at level 3.")
		return false
	if str(ScreenTechnologySystem.get_technology_name(int(state.get("technology_milestone", 0)))) != "LED-LCD":
		_fail("The first complete screen milestone did not unlock LED-LCD.")
		return false

	for _click_index in range(90):
		ScreenTechnologySystem.upgrade(state)
	if int(state.get("darkness", 0)) != 33 or int(state.get("shininess", 0)) != 33 or int(state.get("reflection_reduction", 0)) != 33:
		_fail("Screen quality progression stopped increasing after the named technology milestones.")
		return false
	if str(ScreenTechnologySystem.get_technology_name(int(state.get("technology_milestone", 0)))) != "MicroLED Generation 3":
		_fail("Screen technology naming did not continue beyond MicroLED.")
		return false
	if ScreenTechnologySystem.get_next_milestone_requirement(state) != 36:
		_fail("The next screen milestone did not continue beyond the previous level.")
		return false
	return true


func _wait_for_headquarters() -> bool:
	for _frame_index in range(180):
		if is_instance_valid(game.world_root):
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error("HOME_OFFICE_TRANSITION_SMOKE_TEST: " + message)
	quit(1)


func _verify_architectural_progression(headquarters) -> bool:
	var hq_signatures: Array[String] = [
		"Workshop_Raised_Roof_Monitor",
		"Level02_External_Stair_Core",
		"Level03_Corner_Penthouse",
		"Level04_Cantilevered_Executive_Block",
		"Level05_Central_Atrium_Tower",
		"Level06_Twin_Structural_Core",
		"Level07_Glazed_Corner_Atrium",
		"Level08_East_Upper_Wing",
		"Level09_Crown_Tower",
		"Level10_Central_Crown_Tower"
	]
	var hq_massing_signatures: Array[String] = [
		"HQ_L01_Industrial_Workshop",
		"HQ_L02_LShaped_Admin_Block",
		"HQ_L03_West_Lab_Wing",
		"HQ_L04_Offset_Office_Tower",
		"HQ_L05_Central_Atrium_Tower",
		"HQ_L06_West_Tower",
		"HQ_L07_Octagonal_Glass_Rotunda",
		"HQ_L08_West_Glass_Tower",
		"HQ_L09_Central_Signature_Tower",
		"HQ_L10_Central_Glass_Atrium"
	]
	var facility_roots: Dictionary = {
		"production": "Production_And_Assembly",
		"research": "Research_And_Test_Lab",
		"utilities": "Utilities_Building",
		"security": "Security_Gatehouse"
	}
	var facility_signatures: Array[Dictionary] = [
		{"production": "Production_And_Assembly_Workshop_Roof_Lantern", "research": "Research_And_Test_Lab_Lab_Roof_Lantern", "utilities": "Utilities_Building_Exhaust_Hood", "security": "Security_Gatehouse_Guard_Booth_Eave"},
		{"production": "Production_And_Assembly_Loading_Canopy", "research": "Research_And_Test_Lab_Glass_Entry_Vestibule", "utilities": "Utilities_Building_Switchgear_Cabinet", "security": "Security_Gatehouse_Checkpoint_Canopy"},
		{"production": "Production_And_Assembly_Raised_Clerestory", "research": "Research_And_Test_Lab_Central_Glass_Atrium", "utilities": "Utilities_Building_Outdoor_Transformer", "security": "Security_Gatehouse_Raised_Observation_Bay"},
		{"production": "Production_And_Assembly_Raised_Quality_Office", "research": "Research_And_Test_Lab_Corner_Research_Tower", "utilities": "Utilities_Building_Cooling_Plant_Housing", "security": "Security_Gatehouse_Control_Tower"},
		{"production": "Production_And_Assembly_Sawtooth_Roof_Monitor", "research": "Research_And_Test_Lab_Cantilevered_Upper_Lab", "utilities": "Utilities_Building_Pipe_Riser", "security": "Security_Gatehouse_Cantilevered_Command_Room"},
		{"production": "Production_And_Assembly_Process_Service_Tower", "research": "Research_And_Test_Lab_North_Lab_Wing", "utilities": "Utilities_Building_Thermal_Storage_Tank", "security": "Security_Gatehouse_Operations_Wing"},
		{"production": "Production_And_Assembly_Automation_Mezzanine", "research": "Research_And_Test_Lab_Glazed_Upper_Lab", "utilities": "Utilities_Building_Exhaust_Stack", "security": "Security_Gatehouse_Surveillance_Tower"},
		{"production": "Production_And_Assembly_Upper_Automation_Hall", "research": "Research_And_Test_Lab_Elevated_Research_Bridge", "utilities": "Utilities_Building_Transformer_Bank", "security": "Security_Gatehouse_Security_Command_Penthouse"},
		{"production": "Production_And_Assembly_Twin_Process_Housing", "research": "Research_And_Test_Lab_Research_Tower", "utilities": "Utilities_Building_Energy_Storage_Tank", "security": "Security_Gatehouse_Dual_Level_Control_Block"},
		{"production": "Production_And_Assembly_Flagship_Glazed_Office", "research": "Research_And_Test_Lab_Signature_Atrium", "utilities": "Utilities_Building_Energy_Control_Room", "security": "Security_Gatehouse_Flagship_Control_Tower"}
	]

	var previous_footprints: Dictionary = {}
	var previous_heights: Dictionary = {}
	var seen_architecture_signatures: Dictionary = {}
	for level in range(1, 11):
		headquarters.set_owned_level(level)
		await process_frame
		if headquarters.compound_facilities_level != level:
			_fail("Compound facilities did not update to headquarters level %d." % level)
			return false
		if not is_instance_valid(headquarters.building_root) or not is_instance_valid(headquarters.building_root.get_node_or_null(hq_signatures[level - 1])):
			_fail("Headquarters level %d did not build its unique architectural form." % level)
			return false
		if not is_instance_valid(headquarters.building_root.get_node_or_null(hq_massing_signatures[level - 1])):
			_fail("Headquarters level %d reused a generic building shell." % level)
			return false
		var expected: Dictionary = facility_signatures[level - 1]
		for facility_type in ["production", "research", "utilities", "security"]:
			var signature_name: String = str(expected[facility_type])
			if not is_instance_valid(headquarters.compound_facilities_root.find_child(signature_name, true, false)):
				_fail("%s facility did not build its unique level %d structure." % [facility_type, level])
				return false
			var facility_root: String = str(facility_roots[facility_type])
			var core_name := "%s_Level_%02d_Core_Mass" % [facility_root, level]
			var module_name := "%s_Level_%02d_Architectural_Module" % [facility_root, level]
			var facility_core = headquarters.compound_facilities_root.get_node_or_null(core_name)
			if not is_instance_valid(facility_core):
				_fail("%s facility level %d did not rebuild its own core mass." % [facility_type, level])
				return false
			var facility_module = facility_core.get_node_or_null(module_name)
			if not is_instance_valid(facility_module):
				_fail("%s facility level %d did not build its dedicated architectural module." % [facility_type, level])
				return false
			var structure_signature: String = str(facility_module.get_meta("structure_signature", ""))
			if structure_signature.is_empty():
				_fail("%s facility level %d is missing its structural design identity." % [facility_type, level])
				return false
			var structure_key: String = structure_signature
			if seen_architecture_signatures.has(structure_key):
				_fail("%s facility level %d reused an earlier level's main architectural structure." % [facility_type, level])
				return false
			seen_architecture_signatures[structure_key] = true
			if facility_module.get_child_count() < 4:
				_fail("%s facility level %d has too little independent structural massing." % [facility_type, level])
				return false
			var footprint: Vector2 = facility_core.get_meta("footprint", Vector2.ZERO)
			var main_height: float = float(facility_core.get_meta("main_height", 0.0))
			var facility_identity: String = str(facility_core.get_meta("facility_type", ""))
			if facility_identity != facility_type:
				_fail("%s facility level %d has incorrect architectural identity metadata." % [facility_type, level])
				return false
			var previous_footprint: Vector2 = previous_footprints.get(facility_type, Vector2.ZERO)
			var previous_height: float = float(previous_heights.get(facility_type, 0.0))
			if footprint.x <= previous_footprint.x or footprint.y <= previous_footprint.y or main_height <= previous_height:
				_fail("%s facility did not grow in both footprint and height at level %d." % [facility_type, level])
				return false
			previous_footprints[facility_type] = footprint
			previous_heights[facility_type] = main_height
	return true
