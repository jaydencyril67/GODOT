extends SceneTree

const MainGameScript = preload("res://scripts/digitalworld_game.gd")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")
const ScreenTechnologySystem = preload("res://scripts/screen_technology_system.gd")

var game: Node


func _initialize() -> void:
	call_deferred("_run_transition_checks")


func _run_memory_clock_progression_checks() -> bool:
	var expected_milestones: Dictionary = {
		0: 200,
		20: 1066,
		40: 2133,
		60: 4266,
		80: 6400,
		100: 10700,
		120: 14400
	}
	for level_value in expected_milestones.keys():
		var level := int(level_value)
		var expected_speed := int(expected_milestones[level_value])
		if ResearchManagerScript.get_memory_clock_speed_for_level(level) != expected_speed:
			_fail("Memory Clock level %d did not resolve to its expected speed." % level)
			return false
	var previous_speed := ResearchManagerScript.get_memory_clock_speed_for_level(0)
	for level in range(1, ResearchManagerScript.MEMORY_CLOCK_MAX_RESEARCH_LEVEL + 1):
		var next_speed := ResearchManagerScript.get_memory_clock_speed_for_level(level)
		if next_speed <= previous_speed:
			_fail("Memory Clock speeds did not increase at every research level.")
			return false
		previous_speed = next_speed
	var expected_research_ceilings: Array[int] = [20, 40, 60, 60, 80, 100, 120]
	for technology_level in range(expected_research_ceilings.size()):
		if ResearchManagerScript.get_memory_clock_research_ceiling_for_ram_technology_level(technology_level) != expected_research_ceilings[technology_level]:
			_fail("RAM Technology level %d did not unlock the correct Memory Clock research ceiling." % technology_level)
			return false
	if ResearchManagerScript.get_memory_clock_max_level_for_ram_technology("LPDDR4X") != 60:
		_fail("LPDDR4X did not share LPDDR4's Memory Clock hardware limit.")
		return false
	if ResearchManagerScript.get_memory_clock_max_level_for_ram_technology("LPDDR6") != 120:
		_fail("LPDDR6 did not receive the final Memory Clock hardware limit.")
		return false
	return true


func _run_charging_speed_progression_checks() -> bool:
	if ResearchManagerScript.get_charging_speed_max_for_level(0) != 1:
		_fail("Charging Speed Level 1 did not start at 1W.")
		return false
	if ResearchManagerScript.get_charging_speed_max_for_level(1) != 4:
		_fail("The first Charging Speed research upgrade did not unlock 4W.")
		return false
	if ResearchManagerScript.get_charging_speed_max_for_level(65) != 196:
		_fail("Charging Speed Level 66 did not unlock 196W.")
		return false
	if ResearchManagerScript.get_charging_speed_max_for_level(66) != 200:
		_fail("Charging Speed Level 67 did not reach exactly 200W.")
		return false

	for upgrade_count in range(ResearchManagerScript.CHARGING_SPEED_RESEARCH_UPGRADES + 1):
		var expected_maximum := 200 if upgrade_count == 66 else 1 + upgrade_count * 3
		if ResearchManagerScript.get_charging_speed_max_for_level(upgrade_count) != expected_maximum:
			_fail("Charging Speed upgrade %d produced the wrong maximum." % upgrade_count)
			return false

	var first_target: Dictionary = ResearchManagerScript.get_charging_speed_research_target({})
	if int(first_target.get("index", -1)) != 2 or str(first_target.get("technology", "")) != "4W":
		_fail("The first Charging Speed research target was not Level 2 at 4W.")
		return false
	var final_target: Dictionary = ResearchManagerScript.get_charging_speed_research_target({"Charging Speed": 65})
	if int(final_target.get("index", -1)) != 67 or str(final_target.get("technology", "")) != "200W":
		_fail("The final Charging Speed research target did not unlock 200W at Level 67.")
		return false
	if not ResearchManagerScript.get_charging_speed_research_target({"Charging Speed": 66}).is_empty():
		_fail("Charging Speed still offered research after reaching 200W.")
		return false

	var test_career: Dictionary = {
		"staff_employees": [{
			"id": "charging_speed_researcher",
			"department": "Research",
			"efficiency": 100
		}],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	var commission: Dictionary = ResearchManagerScript.commission_project(test_career, {
		"component": "Charging Speed",
		"staff_ids": ["charging_speed_researcher"]
	}, 1000.0)
	if not bool(commission.get("ok", false)):
		_fail("Charging Speed could not be commissioned through the existing research pipeline.")
		return false
	var project: Dictionary = commission.get("project", {})
	if str(project.get("research_target", "")) != "4W" or int(project.get("research_target_index", -1)) != 2:
		_fail("The commissioned Charging Speed project did not store its exact 4W target.")
		return false
	var duplicate_commission: Dictionary = ResearchManagerScript.commission_project(test_career, {
		"component": "Charging Speed",
		"staff_ids": ["charging_speed_researcher"]
	}, 1000.0)
	if bool(duplicate_commission.get("ok", false)):
		_fail("A duplicate Charging Speed project was allowed for the same research target.")
		return false

	var projects: Array = test_career.get("research_projects", [])
	projects[0]["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
	test_career["research_projects"] = projects
	var invalid_approval: Dictionary = ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
		"component": "Charging Speed",
		"metric": "Maximum wired charging speed",
		"value": "5W"
	}], 2000.0)
	if bool(invalid_approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get("Charging Speed", 0)) != 0:
		_fail("Charging Speed accepted a validation result that did not match its assigned target.")
		return false
	var approval: Dictionary = ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
		"component": "Charging Speed",
		"metric": "Maximum wired charging speed",
		"value": "4W"
	}], 2000.0)
	if not bool(approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get("Charging Speed", 0)) != 1:
		_fail("Approved Charging Speed research did not unlock the next research level.")
		return false
	var next_target: Dictionary = ResearchManagerScript.get_charging_speed_research_target(test_career.get("research_component_levels", {}))
	if str(next_target.get("technology", "")) != "7W":
		_fail("The next Charging Speed research target did not advance from 4W to 7W.")
		return false
	return true


func _run_transition_checks() -> void:
	if not _run_screen_technology_checks():
		return
	if not _run_charging_speed_progression_checks():
		return
	if not _run_memory_clock_progression_checks():
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
	for control_name in ["ResearchComponentOption", "ResearchComponentOption_1", "ResearchNextButton"]:
		if dashboard.find_child(control_name, true, false) == null:
			_fail("The component-selection step is missing %s." % control_name)
			return
	var ram_component_option := dashboard.find_child("ResearchComponentOption_1", true, false) as Button
	if not ram_component_option.text.contains("RAM TECH"):
		_fail("RAM Technology is missing from the R&D component selector.")
		return
	var mobile_network_component_option := dashboard.find_child("ResearchComponentOption_9", true, false) as Button
	if not is_instance_valid(mobile_network_component_option) or not mobile_network_component_option.text.contains("MOBILE NETWORK"):
		_fail("Mobile Network is missing from the R&D component selector.")
		return
	if not mobile_network_component_option.tooltip_text.contains("NMT"):
		_fail("The Mobile Network research selector did not identify its next technology.")
		return
	var wifi_component_option := dashboard.find_child("ResearchComponentOption_10", true, false) as Button
	if not is_instance_valid(wifi_component_option) or not wifi_component_option.text.contains("WI-FI"):
		_fail("Wi-Fi is missing from the R&D component selector.")
		return
	if not wifi_component_option.tooltip_text.contains("Wi-Fi 2 (802.11a)"):
		_fail("The Wi-Fi research selector did not identify Wi-Fi 2 as its first research target.")
		return
	var bluetooth_component_option := dashboard.find_child("ResearchComponentOption_11", true, false) as Button
	if not is_instance_valid(bluetooth_component_option) or not bluetooth_component_option.text.contains("BLUETOOTH"):
		_fail("Bluetooth is missing from the R&D component selector.")
		return
	if not bluetooth_component_option.tooltip_text.contains("Bluetooth 1.1"):
		_fail("Bluetooth research did not identify Bluetooth 1.1 as its first target.")
		return
	var cooling_component_option := dashboard.find_child("ResearchComponentOption_14", true, false) as Button
	if not is_instance_valid(cooling_component_option) or not cooling_component_option.text.contains("COOLING SYSTEM"):
		_fail("Cooling System Design is missing from the R&D component selector.")
		return
	if not cooling_component_option.tooltip_text.contains("Graphite Sheet"):
		_fail("Cooling System Design did not identify Graphite Sheet as its first research target.")
		return
	var memory_clock_component_option := dashboard.find_child("ResearchComponentOption_15", true, false) as Button
	if not is_instance_valid(memory_clock_component_option) or not memory_clock_component_option.text.contains("MEMORY CLOCK"):
		_fail("Memory Clock is missing from the R&D component selector.")
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
	var ram_estimate: Dictionary = ResearchManagerScript.estimate_research("RAM Technology", ["researcher_100"], duration_test_employees)
	if not bool(ram_estimate.get("ok", false)):
		_fail("RAM Technology could not be selected as an R&D research component.")
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

	var ram_commission: Dictionary = game.commission_research_project({
		"component": "RAM Technology",
		"staff_ids": ["researcher_smoke_01"]
	})
	if not bool(ram_commission.get("ok", false)):
		_fail("A RAM Technology research project could not be commissioned: %s" % str(ram_commission.get("error", "")))
		return
	var ram_project: Dictionary = ram_commission.get("project", {})
	var ram_projects: Array = game.career.get("research_projects", [])
	for project_index in range(ram_projects.size()):
		if str(ram_projects[project_index].get("id", "")) == str(ram_project.get("id", "")):
			ram_projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = ram_projects
	var ram_completed_ids: Array = ResearchManagerScript.advance_projects(game.career, 86400.0 * 29.0, game.game_date_unix + 86400.0 * 29.0)
	if not ram_completed_ids.has(str(ram_project.get("id", ""))):
		_fail("The RAM Technology project did not complete after its estimated 29-day duration.")
		return
	var ram_validation: Dictionary = game.approve_research_project(str(ram_project.get("id", "")), [{
		"component": "RAM Technology",
		"metric": "Memory data rate",
		"value": "Validated next-generation prototype",
		"unit": "",
		"notes": "Recorded after memory-subsystem testing."
	}])
	if not bool(ram_validation.get("ok", false)):
		_fail("A completed RAM Technology project could not pass technical validation: %s" % str(ram_validation.get("error", "")))
		return
	if int(game.career.get("research_component_levels", {}).get("RAM Technology", 0)) != 1:
		_fail("Technical approval did not unlock the next RAM Technology generation.")
		return

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("Memory Clock"):
		_fail("Memory Clock is missing from the R&D component catalogue.")
		return
	var memory_clock_levels: Dictionary = game.career.get("research_component_levels", {})
	var unlocked_ram_technology_level := int(memory_clock_levels.get("RAM Technology", 0))
	memory_clock_levels["RAM Technology"] = 0
	memory_clock_levels["Memory Clock"] = 20
	game.career["research_component_levels"] = memory_clock_levels
	var locked_memory_clock_commission: Dictionary = game.commission_research_project({
		"component": "Memory Clock",
		"staff_ids": ["researcher_smoke_01"]
	})
	if bool(locked_memory_clock_commission.get("ok", false)):
		_fail("Memory Clock research exceeded LPDDR2's 20-level research block before a newer RAM technology was unlocked.")
		return
	memory_clock_levels["RAM Technology"] = unlocked_ram_technology_level
	memory_clock_levels["Memory Clock"] = 0
	game.career["research_component_levels"] = memory_clock_levels
	var memory_clock_commission: Dictionary = game.commission_research_project({
		"component": "Memory Clock",
		"staff_ids": ["researcher_smoke_01"]
	})
	if not bool(memory_clock_commission.get("ok", false)):
		_fail("A Memory Clock research project could not be commissioned: %s" % str(memory_clock_commission.get("error", "")))
		return
	var memory_clock_project: Dictionary = memory_clock_commission.get("project", {})
	var previous_memory_clock_staff: Array = game.career.get("staff_employees", []).duplicate(true)
	var memory_clock_test_staff: Array = previous_memory_clock_staff.duplicate(true)
	memory_clock_test_staff.append({
		"id": "researcher_memory_clock_02",
		"full_name": "Second Memory Research Engineer",
		"department": "Research",
		"position": "Research Engineer",
		"efficiency": 100,
		"monthly_salary": 250000.0
	})
	game.career["staff_employees"] = memory_clock_test_staff
	var duplicate_memory_clock_commission: Dictionary = game.commission_research_project({
		"component": "Memory Clock",
		"staff_ids": ["researcher_memory_clock_02"]
	})
	game.career["staff_employees"] = previous_memory_clock_staff
	if bool(duplicate_memory_clock_commission.get("ok", false)):
		_fail("A second Memory Clock project was allowed while one was already active.")
		return
	var memory_clock_projects: Array = game.career.get("research_projects", [])
	for project_index in range(memory_clock_projects.size()):
		if str(memory_clock_projects[project_index].get("id", "")) == str(memory_clock_project.get("id", "")):
			memory_clock_projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = memory_clock_projects
	var memory_clock_completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not memory_clock_completed_ids.has(str(memory_clock_project.get("id", ""))):
		_fail("The Memory Clock research project did not complete after its estimated duration.")
		return
	var memory_clock_validation: Dictionary = game.approve_research_project(str(memory_clock_project.get("id", "")), [{
		"component": "Memory Clock",
		"metric": "Highest validated memory transfer speed",
		"value": "Next available speed step",
		"unit": "MT/s",
		"notes": "Validated as the next stage of the shared Memory Clock progression."
	}])
	if not bool(memory_clock_validation.get("ok", false)):
		_fail("A completed Memory Clock project could not pass technical validation: %s" % str(memory_clock_validation.get("error", "")))
		return
	if int(game.career.get("research_component_levels", {}).get("Memory Clock", 0)) != 1:
		_fail("Technical approval did not unlock the first Memory Clock research level.")
		return
	var saved_memory_clock_level := int(game.career.get("research_component_levels", {}).get("Memory Clock", 0))
	var saved_ram_technology_level := int(game.career.get("research_component_levels", {}).get("RAM Technology", 0))
	var research_levels: Dictionary = game.career.get("research_component_levels", {})
	research_levels["RAM Technology"] = 6
	research_levels["Memory Clock"] = ResearchManagerScript.MEMORY_CLOCK_MAX_RESEARCH_LEVEL
	game.career["research_component_levels"] = research_levels
	var maximum_memory_clock_commission: Dictionary = game.commission_research_project({
		"component": "Memory Clock",
		"staff_ids": ["researcher_smoke_01"]
	})
	if bool(maximum_memory_clock_commission.get("ok", false)):
		_fail("Memory Clock research continued beyond its 120-level maximum.")
		return
	research_levels["RAM Technology"] = saved_ram_technology_level
	research_levels["Memory Clock"] = saved_memory_clock_level
	game.career["research_component_levels"] = research_levels

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("RAM"):
		_fail("RAM capacity is missing from the R&D component catalogue.")
		return
	var ram_capacity_commission: Dictionary = game.commission_research_project({
		"component": "RAM",
		"staff_ids": ["researcher_smoke_01"]
	})
	if not bool(ram_capacity_commission.get("ok", false)):
		_fail("A RAM capacity research project could not be commissioned: %s" % str(ram_capacity_commission.get("error", "")))
		return
	var ram_capacity_project: Dictionary = ram_capacity_commission.get("project", {})
	var ram_capacity_projects: Array = game.career.get("research_projects", [])
	for project_index in range(ram_capacity_projects.size()):
		if str(ram_capacity_projects[project_index].get("id", "")) == str(ram_capacity_project.get("id", "")):
			ram_capacity_projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = ram_capacity_projects
	var ram_capacity_completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not ram_capacity_completed_ids.has(str(ram_capacity_project.get("id", ""))):
		_fail("The RAM capacity project did not complete after its estimated 29-day duration.")
		return
	if int(game.career.get("research_component_levels", {}).get("RAM", 0)) != 0:
		_fail("RAM capacity unlocked before its completed project passed technical validation.")
		return
	var ram_capacity_validation: Dictionary = game.approve_research_project(str(ram_capacity_project.get("id", "")), [{
		"component": "RAM",
		"metric": "Maximum validated RAM capacity",
		"value": "12 GB",
		"unit": "",
		"notes": "Validated memory-density and package-capacity improvement."
	}])
	if not bool(ram_capacity_validation.get("ok", false)):
		_fail("A completed RAM capacity project could not pass technical validation: %s" % str(ram_capacity_validation.get("error", "")))
		return
	if int(game.career.get("research_component_levels", {}).get("RAM", 0)) != 1:
		_fail("Technical approval did not unlock the next RAM capacity tier.")
		return

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("Internal Storage"):
		_fail("Internal Storage is missing from the R&D component catalogue.")
		return
	var storage_commission: Dictionary = game.commission_research_project({
		"component": "Internal Storage",
		"staff_ids": ["researcher_smoke_01"]
	})
	if not bool(storage_commission.get("ok", false)):
		_fail("An Internal Storage research project could not be commissioned: %s" % str(storage_commission.get("error", "")))
		return
	var storage_project: Dictionary = storage_commission.get("project", {})
	var storage_projects: Array = game.career.get("research_projects", [])
	for project_index in range(storage_projects.size()):
		if str(storage_projects[project_index].get("id", "")) == str(storage_project.get("id", "")):
			storage_projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = storage_projects
	var storage_completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not storage_completed_ids.has(str(storage_project.get("id", ""))):
		_fail("The Internal Storage project did not complete after its estimated 29-day duration.")
		return
	if int(game.career.get("research_component_levels", {}).get("Internal Storage", 0)) != 0:
		_fail("Internal Storage unlocked before its completed project passed technical validation.")
		return
	var storage_validation: Dictionary = game.approve_research_project(str(storage_project.get("id", "")), [{
		"component": "Internal Storage",
		"metric": "Maximum validated internal storage capacity",
		"value": "4 GB",
		"unit": "",
		"notes": "Validated storage-density improvement beyond the 2 GB baseline."
	}])
	if not bool(storage_validation.get("ok", false)):
		_fail("A completed Internal Storage project could not pass technical validation: %s" % str(storage_validation.get("error", "")))
		return
	if int(game.career.get("research_component_levels", {}).get("Internal Storage", 0)) != 1:
		_fail("Technical approval did not unlock the next Internal Storage capacity tier.")
		return

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("Mobile Network"):
		_fail("Mobile Network is missing from the R&D component catalogue.")
		return
	if not _complete_mobile_network_research_project("NMT", "1G"):
		return
	if not _complete_mobile_network_research_project("TACS", "1G"):
		return
	var next_mobile_target: Dictionary = ResearchManagerScript.get_mobile_network_research_target(
		game.career.get("research_component_levels", {})
	)
	if str(next_mobile_target.get("generation", "")) != "2G" or str(next_mobile_target.get("technology", "")) != "GSM":
		_fail("Completing the 1G technologies did not advance the next Mobile Network research target to 2G GSM.")
		return

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("Wi-Fi"):
		_fail("Wi-Fi is missing from the R&D component catalogue.")
		return
	var starting_wifi_entry: Dictionary = ResearchManagerScript.get_wifi_entry(0)
	if str(starting_wifi_entry.get("generation", "")) != "Wi-Fi 1" or str(starting_wifi_entry.get("technology", "")) != "802.11b":
		_fail("Wi-Fi research does not start from Wi-Fi 1 (802.11b).")
		return
	if ResearchManagerScript.get_wifi_step_count() != 9:
		_fail("The Wi-Fi research progression does not contain all nine planned stages.")
		return
	var initial_wifi_target: Dictionary = ResearchManagerScript.get_wifi_research_target(
		game.career.get("research_component_levels", {})
	)
	if str(initial_wifi_target.get("generation", "")) != "Wi-Fi 2" or str(initial_wifi_target.get("technology", "")) != "802.11a":
		_fail("Wi-Fi 1 was not treated as the baseline before Wi-Fi 2 research.")
		return
	var wifi_staff: Array = game.career.get("staff_employees", []).duplicate(true)
	wifi_staff.append({
		"id": "researcher_wifi_01",
		"full_name": "Wireless Network Research Engineer",
		"department": "Research",
		"position": "Research Engineer",
		"efficiency": 100,
		"monthly_salary": 250000.0
	})
	game.career["staff_employees"] = wifi_staff
	if not _complete_wifi_research_project("802.11a", "Wi-Fi 2"):
		return

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("Bluetooth"):
		_fail("Bluetooth is missing from the R&D component catalogue.")
		return
	var expected_bluetooth_versions := [
		"Bluetooth 1.0b", "Bluetooth 1.1", "Bluetooth 1.2",
		"Bluetooth 2.0 + EDR", "Bluetooth 2.1 + EDR", "Bluetooth 3.0 + HS",
		"Bluetooth 4.0", "Bluetooth 4.1", "Bluetooth 4.2",
		"Bluetooth 5.0", "Bluetooth 5.1", "Bluetooth 5.2", "Bluetooth 5.3", "Bluetooth 5.4",
		"Bluetooth 6.0", "Bluetooth 6.1", "Bluetooth 6.2", "Bluetooth 6.3", "Bluetooth 7.0"
	]
	if ResearchManagerScript.get_bluetooth_step_count() != expected_bluetooth_versions.size():
		_fail("Bluetooth does not contain all 19 planned Core Specification versions.")
		return
	for bluetooth_index in range(expected_bluetooth_versions.size()):
		var bluetooth_entry: Dictionary = ResearchManagerScript.get_bluetooth_entry(bluetooth_index)
		if str(bluetooth_entry.get("technology", "")) != expected_bluetooth_versions[bluetooth_index]:
			_fail("Bluetooth version %d is missing or out of chronological order." % (bluetooth_index + 1))
			return
	var first_bluetooth_target: Dictionary = ResearchManagerScript.get_bluetooth_research_target(
		game.career.get("research_component_levels", {})
	)
	if str(first_bluetooth_target.get("technology", "")) != "Bluetooth 1.1":
		_fail("Bluetooth 1.0b was not treated as the baseline before Bluetooth 1.1 research.")
		return
	var final_bluetooth_target: Dictionary = ResearchManagerScript.get_bluetooth_research_target({
		"Bluetooth": expected_bluetooth_versions.size() - 1
	})
	if not final_bluetooth_target.is_empty():
		_fail("Bluetooth research still offers another version after Bluetooth 7.0.")
		return
	var bluetooth_staff: Array = game.career.get("staff_employees", []).duplicate(true)
	bluetooth_staff.append({
		"id": "researcher_bluetooth_01",
		"full_name": "Bluetooth Research Engineer",
		"department": "Research",
		"position": "Research Engineer",
		"efficiency": 100,
		"monthly_salary": 250000.0
	})
	game.career["staff_employees"] = bluetooth_staff
	if not _complete_bluetooth_research_project("Bluetooth 1.1"):
		return

	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("Cooling System Design"):
		_fail("Cooling System Design is missing from the research manager catalogue.")
		return
	if ResearchManagerScript.get_cooling_system_step_count() != 12:
		_fail("The heat-removal progression does not contain all twelve planned options.")
		return
	var first_cooling_target: Dictionary = ResearchManagerScript.get_cooling_system_research_target(
		game.career.get("research_component_levels", {})
	)
	if str(first_cooling_target.get("technology", "")) != "Graphite Sheet":
		_fail("No Dedicated Cooling was not treated as the baseline before Graphite Sheet research.")
		return
	var cooling_staff: Array = game.career.get("staff_employees", []).duplicate(true)
	cooling_staff.append({
		"id": "researcher_cooling_01",
		"full_name": "Thermal Systems Research Engineer",
		"department": "Research",
		"position": "Research Engineer",
		"efficiency": 100,
		"monthly_salary": 250000.0
	})
	game.career["staff_employees"] = cooling_staff
	var cooling_commission: Dictionary = game.commission_research_project({
		"component": "Cooling System Design",
		"staff_ids": ["researcher_cooling_01"]
	})
	if not bool(cooling_commission.get("ok", false)):
		_fail("A Cooling System Design research project could not be commissioned: %s" % str(cooling_commission.get("error", "")))
		return
	var cooling_project: Dictionary = cooling_commission.get("project", {})
	var cooling_projects: Array = game.career.get("research_projects", [])
	for project_index in range(cooling_projects.size()):
		if str(cooling_projects[project_index].get("id", "")) == str(cooling_project.get("id", "")):
			cooling_projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = cooling_projects
	var cooling_completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not cooling_completed_ids.has(str(cooling_project.get("id", ""))):
		_fail("The Cooling System Design project did not complete after its estimated 29-day duration.")
		return
	var cooling_validation: Dictionary = game.approve_research_project(str(cooling_project.get("id", "")), [{
		"component": "Cooling System Design",
		"metric": "Heat removal technology",
		"value": "Graphite Sheet",
		"unit": "",
		"notes": "Validated the first heat-removal option."
	}])
	if not bool(cooling_validation.get("ok", false)):
		_fail("A completed Cooling System Design project could not pass technical validation: %s" % str(cooling_validation.get("error", "")))
		return
	if int(game.career.get("research_component_levels", {}).get("Cooling System Design", 0)) != 1:
		_fail("Technical approval did not unlock Graphite Sheet for the heat-removal selector.")
		return
	var second_cooling_target: Dictionary = ResearchManagerScript.get_cooling_system_research_target(
		game.career.get("research_component_levels", {})
	)
	if str(second_cooling_target.get("technology", "")) != "Graphite + Copper Foil":
		_fail("Approving Graphite Sheet did not advance the next heat-removal research target.")
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


func _complete_mobile_network_research_project(expected_technology: String, expected_generation: String) -> bool:
	var project: Dictionary = {}
	for project_value in game.career.get("research_projects", []):
		if not (project_value is Dictionary):
			continue
		var existing_project: Dictionary = project_value
		if str(existing_project.get("component", "")) == "Mobile Network" and str(existing_project.get("research_target", "")) == expected_technology and str(existing_project.get("status", "")) == ResearchManagerScript.STATUS_ACTIVE:
			project = existing_project.duplicate(true)
			break
	if project.is_empty():
		var commission: Dictionary = game.commission_research_project({
			"component": "Mobile Network",
			"staff_ids": ["researcher_smoke_01"]
		})
		if not bool(commission.get("ok", false)):
			_fail("A Mobile Network research project could not be commissioned: %s" % str(commission.get("error", "")))
			return false
		project = commission.get("project", {})
	if str(project.get("research_target", "")) != expected_technology or str(project.get("research_generation", "")) != expected_generation:
		_fail("Mobile Network research did not automatically target %s in %s." % [expected_technology, expected_generation])
		return false
	if expected_technology == "NMT":
		var original_staff: Array = game.career.get("staff_employees", []).duplicate(true)
		var expanded_staff := original_staff.duplicate(true)
		expanded_staff.append({
			"id": "researcher_smoke_02",
			"full_name": "Second Research Engineer",
			"department": "Research",
			"position": "Research Engineer",
			"efficiency": 100,
			"monthly_salary": 250000.0
		})
		game.career["staff_employees"] = expanded_staff
		var duplicate_commission: Dictionary = game.commission_research_project({
			"component": "Mobile Network",
			"staff_ids": ["researcher_smoke_02"]
		})
		game.career["staff_employees"] = original_staff
		if bool(duplicate_commission.get("ok", false)):
			_fail("A second Mobile Network project was allowed to target the same in-progress technology.")
			return false
	var projects: Array = game.career.get("research_projects", [])
	for project_index in range(projects.size()):
		if str(projects[project_index].get("id", "")) == str(project.get("id", "")):
			projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = projects
	var completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not completed_ids.has(str(project.get("id", ""))):
		_fail("The Mobile Network project for %s did not complete." % expected_technology)
		return false
	var validation: Dictionary = game.approve_research_project(str(project.get("id", "")), [{
		"component": "Mobile Network",
		"metric": "Validated mobile network technology",
		"value": expected_technology,
		"unit": "",
		"notes": "Technology validated as the next stage in the mobile network progression."
	}])
	if not bool(validation.get("ok", false)):
		_fail("The Mobile Network project for %s could not pass technical validation: %s" % [expected_technology, str(validation.get("error", ""))])
		return false
	var expected_level := int(project.get("research_target_index", -1))
	if int(game.career.get("research_component_levels", {}).get("Mobile Network", 0)) != expected_level:
		_fail("Approval did not unlock the researched Mobile Network technology.")
		return false
	var next_target: Dictionary = ResearchManagerScript.get_mobile_network_research_target(
		game.career.get("research_component_levels", {})
	)
	var auto_next_project: Dictionary = validation.get("auto_next_project", {})
	if next_target.is_empty():
		if not auto_next_project.is_empty():
			_fail("Mobile Network research continued beyond the final technology.")
			return false
	else:
		if auto_next_project.is_empty():
			_fail("The next Mobile Network technology was not started automatically after approval.")
			return false
		if str(auto_next_project.get("research_target", "")) != str(next_target.get("technology", "")) or str(auto_next_project.get("research_generation", "")) != str(next_target.get("generation", "")):
			_fail("Automatic Mobile Network research did not start the next technology in sequence.")
			return false
	return true


func _complete_wifi_research_project(expected_technology: String, expected_generation: String) -> bool:
	var project: Dictionary = {}
	for project_value in game.career.get("research_projects", []):
		if not (project_value is Dictionary):
			continue
		var existing_project: Dictionary = project_value
		if str(existing_project.get("component", "")) == "Wi-Fi" and str(existing_project.get("research_target", "")) == expected_technology and str(existing_project.get("status", "")) == ResearchManagerScript.STATUS_ACTIVE:
			project = existing_project.duplicate(true)
			break
	if project.is_empty():
		var commission: Dictionary = game.commission_research_project({
			"component": "Wi-Fi",
			"staff_ids": ["researcher_wifi_01"]
		})
		if not bool(commission.get("ok", false)):
			_fail("A Wi-Fi research project could not be commissioned: %s" % str(commission.get("error", "")))
			return false
		project = commission.get("project", {})
	if str(project.get("research_target", "")) != expected_technology or str(project.get("research_generation", "")) != expected_generation:
		_fail("Wi-Fi research did not automatically target %s in %s." % [expected_technology, expected_generation])
		return false

	var projects: Array = game.career.get("research_projects", [])
	for project_index in range(projects.size()):
		if str(projects[project_index].get("id", "")) == str(project.get("id", "")):
			projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = projects
	var completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not completed_ids.has(str(project.get("id", ""))):
		_fail("The Wi-Fi project for %s did not complete." % expected_technology)
		return false
	var validation: Dictionary = game.approve_research_project(str(project.get("id", "")), [{
		"component": "Wi-Fi",
		"metric": "Validated Wi-Fi IEEE standard",
		"value": expected_technology,
		"unit": "",
		"notes": "IEEE standard validated as the next stage in the Wi-Fi generation progression."
	}])
	if not bool(validation.get("ok", false)):
		_fail("The Wi-Fi project for %s could not pass technical validation: %s" % [expected_technology, str(validation.get("error", ""))])
		return false
	var expected_level := int(project.get("research_target_index", -1))
	if int(game.career.get("research_component_levels", {}).get("Wi-Fi", 0)) != expected_level:
		_fail("Technical approval did not unlock the researched Wi-Fi generation.")
		return false
	var next_target: Dictionary = ResearchManagerScript.get_wifi_research_target(
		game.career.get("research_component_levels", {})
	)
	var auto_next_project: Dictionary = validation.get("auto_next_project", {})
	if next_target.is_empty():
		if not auto_next_project.is_empty():
			_fail("Wi-Fi research continued beyond the final generation.")
			return false
	else:
		if auto_next_project.is_empty():
			_fail("The next Wi-Fi generation was not started automatically after approval.")
			return false
		if str(auto_next_project.get("research_target", "")) != str(next_target.get("technology", "")) or str(auto_next_project.get("research_generation", "")) != str(next_target.get("generation", "")):
			_fail("Automatic Wi-Fi research did not start the next generation in sequence.")
			return false
	return true


func _complete_bluetooth_research_project(expected_version: String) -> bool:
	var project: Dictionary = {}
	for project_value in game.career.get("research_projects", []):
		if not (project_value is Dictionary):
			continue
		var existing_project: Dictionary = project_value
		if str(existing_project.get("component", "")) == "Bluetooth" and str(existing_project.get("research_target", "")) == expected_version and str(existing_project.get("status", "")) == ResearchManagerScript.STATUS_ACTIVE:
			project = existing_project.duplicate(true)
			break
	if project.is_empty():
		var commission: Dictionary = game.commission_research_project({
			"component": "Bluetooth",
			"staff_ids": ["researcher_bluetooth_01"]
		})
		if not bool(commission.get("ok", false)):
			_fail("A Bluetooth research project could not be commissioned: %s" % str(commission.get("error", "")))
			return false
		project = commission.get("project", {})
	if str(project.get("research_target", "")) != expected_version:
		_fail("Bluetooth research did not target %s." % expected_version)
		return false
	var projects: Array = game.career.get("research_projects", [])
	for project_index in range(projects.size()):
		if str(projects[project_index].get("id", "")) == str(project.get("id", "")):
			projects[project_index]["success_chance"] = 100.0
			break
	game.career["research_projects"] = projects
	var completed_ids: Array[String] = ResearchManagerScript.advance_projects(
		game.career,
		86400.0 * 29.0,
		game.game_date_unix + 86400.0 * 29.0
	)
	if not completed_ids.has(str(project.get("id", ""))):
		_fail("The Bluetooth project for %s did not complete." % expected_version)
		return false
	var validation: Dictionary = game.approve_research_project(str(project.get("id", "")), [{
		"component": "Bluetooth",
		"metric": "Validated Bluetooth Core Specification",
		"value": expected_version,
		"unit": "",
		"notes": "Bluetooth version validated as the next stage in the phone connectivity progression."
	}])
	if not bool(validation.get("ok", false)):
		_fail("Bluetooth %s could not pass technical validation: %s" % [expected_version, str(validation.get("error", ""))])
		return false
	var expected_level := int(project.get("research_target_index", -1))
	if int(game.career.get("research_component_levels", {}).get("Bluetooth", 0)) != expected_level:
		_fail("Technical approval did not unlock the researched Bluetooth version.")
		return false
	var next_target: Dictionary = ResearchManagerScript.get_bluetooth_research_target(
		game.career.get("research_component_levels", {})
	)
	var auto_next_project: Dictionary = validation.get("auto_next_project", {})
	if next_target.is_empty():
		if not auto_next_project.is_empty():
			_fail("Bluetooth research continued beyond the final version.")
			return false
	else:
		if auto_next_project.is_empty():
			_fail("The next Bluetooth version was not started automatically after approval.")
			return false
		if str(auto_next_project.get("research_target", "")) != str(next_target.get("technology", "")):
			_fail("Automatic Bluetooth research did not start the next version in sequence.")
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
