extends SceneTree

const MainGameScript = preload("res://scripts/digitalworld_game.gd")

var game: Node


func _initialize() -> void:
	call_deferred("_run_transition_checks")


func _run_transition_checks() -> void:
	game = MainGameScript.new()
	root.add_child(game)
	await process_frame

	# Model an existing Level 1 company so the headquarters is constructed
	# during the initial loading screen and visible on Home.
	game.career = {
		"company_name": "Smoke Test Mobiles",
		"balance": 10000000.0,
		"research_points": 0,
		"research_points_progress": 0.0
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

	# Phone research must be a dark CanvasLayer overlay over the retained
	# Research page. Selecting Charge Port changes the detail panel in-place;
	# it must not replace the Worksite or navigate to another scene.
	var research_page_layer = game.ui_layer
	game._show_research_phone()
	if game.current_screen != "research_phone" or not is_instance_valid(game.phone_research_worksite):
		_fail("Phone research did not open its research overlay.")
		return
	if not is_instance_valid(research_page_layer) or not research_page_layer.visible:
		_fail("Phone research replaced or hid the underlying Research page layer.")
		return
	var research_worksite = game.phone_research_worksite
	var research_canvas = research_worksite.get_node_or_null("PhoneResearchInterface")
	if not is_instance_valid(research_canvas) or not is_instance_valid(research_canvas.get_node_or_null("PhoneResearchRoot/DigitalWorld_Obsidian_Background")):
		_fail("Phone research is missing its full-screen dark overlay layer.")
		return
	research_worksite._on_research_feature_selected("Charge Port")
	if game.phone_research_worksite != research_worksite or research_worksite.research_detail_feature != "Charge Port" or game.current_screen != "research_phone":
		_fail("Charge Port research navigated away instead of opening in the existing dark research layer.")
		return
	game._return_from_research_phone()
	if game.current_screen != "research" or game.ui_layer != research_page_layer or not research_page_layer.visible:
		_fail("Closing phone research did not reveal the original Research page.")
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
