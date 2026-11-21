extends SceneTree

const PhoneResearchDashboardScene: PackedScene = preload("res://scenes/research_allocation_dashboard.tscn")
const CameraResearchDashboardScene: PackedScene = preload("res://scenes/camera_research_dashboard.tscn")
const ProcessorResearchDashboardScene: PackedScene = preload("res://scenes/processor_research_dashboard.tscn")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var host := Node.new()
	root.add_child(host)

	var sample_projects: Array[Dictionary] = [
		{
			"id": "RDP-PHONE-ACTIVE",
			"component": "RAM",
			"status": ResearchManagerScript.STATUS_ACTIVE,
			"staff_ids": ["phone_researcher"]
		},
		{
			"id": "RDP-CAMERA-ACTIVE",
			"component": "Rear Camera MP",
			"status": ResearchManagerScript.STATUS_ACTIVE,
			"staff_ids": ["camera_researcher"]
		},
		{
			"id": "RDP-CAMERA-COUNT-ACTIVE",
			"component": "Rear Camera Count",
			"status": ResearchManagerScript.STATUS_ACTIVE,
			"staff_ids": ["camera_count_researcher"]
		},
		{
			"id": "RDP-PHONE-PENDING",
			"component": "Charging Speed",
			"status": ResearchManagerScript.STATUS_AWAITING_VALIDATION,
			"staff_ids": []
		},
		{
			"id": "RDP-PROCESSOR-ACTIVE",
			"component": "Control Unit",
			"status": ResearchManagerScript.STATUS_ACTIVE,
			"staff_ids": ["processor_researcher"]
		},
		{
			"id": "RDP-PROCESSOR-CPU-ACTIVE",
			"component": "CPU Cores",
			"status": ResearchManagerScript.STATUS_ACTIVE,
			"staff_ids": ["processor_researcher"]
		},
		{
			"id": "RDP-PROCESSOR-PENDING",
			"component": "Security Processing Unit",
			"status": ResearchManagerScript.STATUS_AWAITING_VALIDATION,
			"staff_ids": []
		},
		{
			"id": "RDP-CAMERA-PENDING",
			"component": "Front Camera MP",
			"status": ResearchManagerScript.STATUS_AWAITING_VALIDATION,
			"staff_ids": []
		},
		{
			"id": "RDP-CAMERA-FLASH-PENDING",
			"component": "Rear Flash Count",
			"status": ResearchManagerScript.STATUS_AWAITING_VALIDATION,
			"staff_ids": []
		}
	]
	var dashboard_data := {
		"company_name": "Research Dashboard Smoke Test",
		"balance": 5000000.0,
		"staff_employees": [
			{"id": "phone_researcher", "full_name": "Phone Researcher", "department": "Research"},
			{"id": "camera_researcher", "full_name": "Camera Researcher", "department": "Research"},
			{"id": "camera_count_researcher", "full_name": "Camera Count Researcher", "department": "Research"},
			{"id": "processor_researcher", "full_name": "Processor Researcher", "department": "Research"}
		],
		"research_projects": sample_projects,
		"research_technologies": {},
		"research_component_levels": {},
		"research_history": []
	}

	var phone_dashboard := PhoneResearchDashboardScene.instantiate() as Control
	host.add_child(phone_dashboard)
	await process_frame
	phone_dashboard.call("configure", dashboard_data)
	if not _has_full_dashboard_shell(phone_dashboard):
		_fail("Phone Research is missing part of its established dashboard structure.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(phone_dashboard.call("_get_active_projects")) != ["RDP-PHONE-ACTIVE"]:
		_fail("Phone Research is displaying a Camera active project or hiding a Phone active project.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(phone_dashboard.call("_get_pending_validation_projects")) != ["RDP-PHONE-PENDING"]:
		_fail("Phone Research is displaying a Camera validation project or hiding a Phone validation project.")
		host.queue_free()
		quit(1)
		return
	if not _has_active_staff(phone_dashboard, ["phone_researcher", "camera_researcher", "camera_count_researcher", "processor_researcher"]):
		_fail("Phone Research lost the shared staff-availability lock for an active Camera project.")
		host.queue_free()
		quit(1)
		return
	phone_dashboard.call("_open_creation_scene")
	var phone_options: Array = phone_dashboard.get("component_buttons")
	var phone_labels := _button_labels(phone_options)
	if phone_labels.has("FRONT CAMERA MP") or phone_labels.has("REAR CAMERA MP") or phone_labels.has("REAR CAMERA COUNT") or phone_labels.has("REAR FLASH COUNT") or not phone_labels.has("RAM"):
		_fail("Phone Research still exposes a camera-only category or lost its normal Phone categories.")
		host.queue_free()
		quit(1)
		return

	var camera_dashboard := CameraResearchDashboardScene.instantiate() as Control
	host.add_child(camera_dashboard)
	await process_frame
	camera_dashboard.call("configure", dashboard_data)
	if not _has_full_dashboard_shell(camera_dashboard):
		_fail("Camera Research did not reproduce the full Phone Research dashboard structure.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(camera_dashboard.call("_get_active_projects")) != ["RDP-CAMERA-COUNT-ACTIVE", "RDP-CAMERA-ACTIVE"]:
		_fail("Camera Research is displaying a Phone active project or hiding a Camera active project.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(camera_dashboard.call("_get_pending_validation_projects")) != ["RDP-CAMERA-FLASH-PENDING", "RDP-CAMERA-PENDING"]:
		_fail("Camera Research is displaying a Phone validation project or hiding a Camera validation project.")
		host.queue_free()
		quit(1)
		return
	if not _has_active_staff(camera_dashboard, ["phone_researcher", "camera_researcher", "camera_count_researcher", "processor_researcher"]):
		_fail("Camera Research lost the shared staff-availability lock for an active Phone project.")
		host.queue_free()
		quit(1)
		return
	camera_dashboard.call("_open_creation_scene")
	var camera_options: Array = camera_dashboard.get("component_buttons")
	var camera_labels := _button_labels(camera_options)
	var expected_camera_labels: Array[String] = [
		"REAR CAMERA MP",
		"FRONT CAMERA MP",
		"NIGHT MODE",
		"REAR CAMERA COUNT",
		"REAR FLASH COUNT",
		"PORTRAIT MODE",
		"MACRO PHOTOGRAPHY",
		"ULTRA-WIDE PHOTOGRAPHY",
		"TELEPHOTO PHOTOGRAPHY",
		"PANORAMA PHOTOGRAPHY",
		"RAW PHOTOGRAPHY",
		"BURST PHOTOGRAPHY",
		"HDR PHOTOGRAPHY",
		"SUPER SLOW-MOTION RECORDING",
		"TIME-LAPSE RECORDING",
		"HYPERLAPSE RECORDING",
		"CINEMATIC VIDEO"
	]
	if camera_labels != expected_camera_labels:
		_fail("Camera Research must expose both camera MP projects, both rear-hardware capacity projects, and all 12 one-time camera unlocks in the approved order.")
		host.queue_free()
		quit(1)
		return
	if not _check_camera_one_time_research() or not _check_night_mode_research() or not _check_rear_hardware_count_research():
		host.queue_free()
		quit(1)
		return
	if not camera_dashboard.has_signal("project_commission_requested") or not camera_dashboard.has_signal("project_approve_requested") or not camera_dashboard.has_signal("project_retry_requested") or not camera_dashboard.has_signal("project_cancel_requested"):
		_fail("Camera Research is missing one or more of the full R&D management signals.")
		host.queue_free()
		quit(1)
		return

	var processor_dashboard := ProcessorResearchDashboardScene.instantiate() as Control
	host.add_child(processor_dashboard)
	await process_frame
	processor_dashboard.call("configure", dashboard_data)
	if not _has_full_dashboard_shell(processor_dashboard):
		_fail("Processor Research did not reproduce the full Phone Research dashboard structure.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(processor_dashboard.call("_get_active_projects")) != ["RDP-PROCESSOR-CPU-ACTIVE", "RDP-PROCESSOR-ACTIVE"]:
		_fail("Processor Research is displaying a Phone or Camera active project, or hiding its own active project.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(processor_dashboard.call("_get_pending_validation_projects")) != ["RDP-PROCESSOR-PENDING"]:
		_fail("Processor Research is displaying a Phone or Camera validation project, or hiding its own validation project.")
		host.queue_free()
		quit(1)
		return
	if not _has_active_staff(processor_dashboard, ["phone_researcher", "camera_researcher", "camera_count_researcher", "processor_researcher"]):
		_fail("Processor Research lost the shared staff-availability lock for active Phone or Camera projects.")
		host.queue_free()
		quit(1)
		return
	processor_dashboard.call("_open_creation_scene")
	var processor_options: Array = processor_dashboard.get("component_buttons")
	var processor_labels := _button_labels(processor_options)
	var expected_processor_labels: Array[String] = [
		"CPU CORES",
		"INSTRUCTION SCHEDULER",
		"PROCESSOR DESIGN",
		"L1 CACHE",
		"L2 CACHE",
		"L3 CACHE",
		"CONTROL UNIT",
		"INSTRUCTION DECODER",
		"INSTRUCTION FETCH UNIT",
		"BRANCH PREDICTION UNIT",
		"MEMORY MANAGEMENT UNIT",
		"TRANSLATION LOOKASIDE BUFFER",
		"INTERNAL BUS",
		"RING BUS / INTERCONNECT FABRIC",
		"SYSTEM AGENT",
		"I/O CONTROLLER",
		"CLOCK DISTRIBUTION NETWORK",
		"VOLTAGE REGULATOR INTERFACE",
		"THERMAL SENSOR",
		"DEBUG AND TEST UNIT",
		"SECURITY PROCESSING UNIT"
	]
	if processor_labels != expected_processor_labels:
		_fail("Processor Research must expose its approved research components in the correct order.")
		host.queue_free()
		quit(1)
		return
	if not _check_processor_technology_research() or not _check_processor_cpu_core_research() or not _check_processor_instruction_scheduler_research() or not _check_processor_cache_research() or not _check_processor_design_research():
		host.queue_free()
		quit(1)
		return
	if not processor_dashboard.has_signal("project_commission_requested") or not processor_dashboard.has_signal("project_approve_requested") or not processor_dashboard.has_signal("project_retry_requested") or not processor_dashboard.has_signal("project_cancel_requested"):
		_fail("Processor Research is missing one or more of the full R&D management signals.")
		host.queue_free()
		quit(1)
		return

	host.queue_free()
	await process_frame
	print("PHONE_CAMERA_PROCESSOR_RESEARCH_DASHBOARD_SMOKE_TEST: PASS")
	quit(0)


func _check_rear_hardware_count_research() -> bool:
	var test_career := {
		"staff_employees": [
			{"id": "count_researcher", "department": "Research", "efficiency": 90}
		],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	var expected_days := {
		"Rear Camera Count": 360.0,
		"Rear Flash Count": 200.0
	}
	for component_value in ["Rear Camera Count", "Rear Flash Count"]:
		var component := str(component_value)
		var expected_duration := float(expected_days[component])
		if not ResearchManagerScript.COMPONENT_CATALOGUE.has(component):
			_fail("%s is missing from the shared research catalogue." % component)
			return false
		if not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(component, 1), expected_duration):
			_fail("%s lost its existing research duration." % component)
			return false
		var expected_points := expected_duration * ResearchManagerScript.TECHNOLOGY_POINTS_PER_RESEARCH_DAY
		if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 1.0), expected_points):
			_fail("%s is not using the shared Technology Points conversion." % component)
			return false

		for level in range(5):
			var levels: Dictionary = {}
			levels[component] = level
			var target: Dictionary = ResearchManagerScript.get_rear_camera_count_research_target(levels) if component == "Rear Camera Count" else ResearchManagerScript.get_rear_flash_count_research_target(levels)
			var maximum := ResearchManagerScript.get_rear_camera_count_max_for_level(level) if component == "Rear Camera Count" else ResearchManagerScript.get_rear_flash_count_max_for_level(level)
			if level == 4:
				if not target.is_empty() or maximum != 5:
					_fail("%s did not stop at its five-module maximum." % component)
					return false
			elif int(target.get("index", -1)) != level + 1 or int(target.get("max_count", -1)) != level + 2 or maximum != level + 1:
				_fail("%s did not unlock exactly one additional module per approval." % component)
				return false

		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": component,
			"staff_ids": ["count_researcher"]
		}, 1000.0)
		if not bool(commission.get("ok", false)):
			_fail("%s could not be commissioned from Camera Research: %s" % [component, str(commission.get("error", ""))])
			return false
		var project: Dictionary = commission.get("project", {})
		var expected_target := "2 cameras" if component == "Rear Camera Count" else "2 flashes"
		if int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != expected_target or not is_equal_approx(float(project.get("required_research_days", 0.0)), expected_duration):
			_fail("%s did not commission the next capacity target with its assigned research duration." % component)
			return false
		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": component,
			"metric": "Maximum number of supported rear hardware modules",
			"value": expected_target
		}], 2000.0)
		if not bool(approval.get("ok", false)) or int(test_career["research_component_levels"].get(component, 0)) != 1:
			_fail("%s approval did not save the first additional module unlock." % component)
			return false
	return true


func _check_camera_one_time_research() -> bool:
	var expected_durations := {
		"Portrait Mode": 260.0,
		"Macro Photography": 250.0,
		"Ultra-Wide Photography": 270.0,
		"Telephoto Photography": 310.0,
		"Panorama Photography": 280.0,
		"RAW Photography": 320.0,
		"Burst Photography": 240.0,
		"HDR Photography": 210.0,
		"Super Slow-Motion Recording": 370.0,
		"Time-Lapse Recording": 290.0,
		"Hyperlapse Recording": 340.0,
		"Cinematic Video": 360.0
	}
	if ResearchManagerScript.CAMERA_SENSOR_COMPONENTS.size() != 12:
		_fail("Camera research must contain exactly the 12 approved one-time unlock features.")
		return false

	var test_career := {
		"staff_employees": [
			{"id": "camera_unlock_researcher", "department": "Research", "efficiency": 90}
		],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	for feature_value in ResearchManagerScript.CAMERA_SENSOR_COMPONENTS:
		var feature := str(feature_value)
		var expected_days := float(expected_durations.get(feature, -1.0))
		if expected_days < 210.0 or expected_days > 370.0 or not ResearchManagerScript.COMPONENT_CATALOGUE.has(feature):
			_fail("%s is missing its approved one-time research duration or catalogue entry." % feature)
			return false
		var actual_days := ResearchManagerScript.get_component_research_duration_days(feature, 1)
		var expected_points := expected_days * ResearchManagerScript.TECHNOLOGY_POINTS_PER_RESEARCH_DAY
		var actual_points := ResearchManagerScript.get_technology_points_for_progress(feature, 1.0)
		if not is_equal_approx(actual_days, expected_days) or not is_equal_approx(actual_points, expected_points):
			_fail("%s does not use its assigned duration and the shared Technology Points conversion." % feature)
			return false

		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": feature,
			"staff_ids": ["camera_unlock_researcher"]
		}, 1000.0)
		if not bool(commission.get("ok", false)):
			_fail("%s could not be commissioned as a one-time camera unlock: %s" % [feature, str(commission.get("error", ""))])
			return false
		var project: Dictionary = commission.get("project", {})
		if int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != feature or not is_equal_approx(float(project.get("required_research_days", 0.0)), expected_days):
			_fail("%s research project did not preserve its one-time target or fixed duration." % feature)
			return false

		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": feature,
			"metric": "Camera feature functionality and integration",
			"value": feature
		}], 2000.0)
		if not bool(approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get(feature, 0)) != 1:
			_fail("%s approval did not persist its one-time camera feature unlock: %s" % [feature, str(approval.get("error", ""))])
			return false
		var duplicate := ResearchManagerScript.commission_project(test_career, {
			"component": feature,
			"staff_ids": ["camera_unlock_researcher"]
		}, 3000.0)
		if bool(duplicate.get("ok", false)):
			_fail("%s could be commissioned again after its one-time unlock was approved." % feature)
			return false
	return true



func _check_night_mode_research() -> bool:
	var component := ResearchManagerScript.NIGHT_MODE_COMPONENT
	if not ResearchManagerScript.COMPONENT_CATALOGUE.has(component) or ResearchManagerScript.CAMERA_SENSOR_COMPONENTS.has(component):
		_fail("Night Mode must be a continuous research component, separate from the 12 one-time camera unlocks.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(component, 1), 352.0):
		_fail("The initial Night Mode unlock must take exactly 352 research days.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(component, 2), 105.0):
		_fail("Each Night Mode quality upgrade must take exactly 105 research days.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 1.0), 3.52):
		_fail("Night Mode initial unlock is not wired to the shared 3.52 TP duration conversion.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 2.0), 4.57):
		_fail("Night Mode quality Level 1 is not adding its 1.05 TP duration budget.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 31.0), 35.02):
		_fail("The complete Night Mode unlock and 30 quality upgrades must total 35.02 TP.")
		return false

	var test_career := {
		"staff_employees": [
			{"id": "night_mode_researcher", "department": "Research", "efficiency": 90}
		],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	var first_result := ResearchManagerScript.commission_project(test_career, {
		"component": component,
		"staff_ids": ["night_mode_researcher"]
	}, 1000.0)
	if not bool(first_result.get("ok", false)):
		_fail("The initial Night Mode research project could not be commissioned.")
		return false
	var first_project: Dictionary = first_result.get("project", {})
	if int(first_project.get("research_target_index", -1)) != 1 or str(first_project.get("research_target", "")) != "Night Mode Unlock" or not is_equal_approx(float(first_project.get("required_research_days", 0.0)), 352.0):
		_fail("Night Mode did not start with the 352-day initial unlock target.")
		return false
	var projects: Array = test_career.get("research_projects", [])
	var first_id := str(first_project.get("id", ""))
	for index in range(projects.size()):
		var project: Dictionary = projects[index]
		if str(project.get("id", "")) == first_id:
			project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
			projects[index] = project
			test_career["research_projects"] = projects
			break
	var first_approval := ResearchManagerScript.approve_project(test_career, first_id, [{
		"component": component,
		"metric": "Low-light camera mode validation",
		"value": "Night Mode Unlock"
	}], 2000.0)
	if not bool(first_approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get(component, 0)) != 1:
		_fail("Approving the initial Night Mode research did not unlock Night Mode at research level 1.")
		return false

	var quality_result := ResearchManagerScript.commission_project(test_career, {
		"component": component,
		"staff_ids": ["night_mode_researcher"]
	}, 3000.0)
	if not bool(quality_result.get("ok", false)):
		_fail("Night Mode Quality Level 1 could not be commissioned after the initial unlock.")
		return false
	var quality_project: Dictionary = quality_result.get("project", {})
	if int(quality_project.get("research_target_index", -1)) != 2 or str(quality_project.get("research_target", "")) != "Night Mode Quality Level 1" or not is_equal_approx(float(quality_project.get("required_research_days", 0.0)), 105.0):
		_fail("Night Mode did not advance to its first 105-day quality upgrade.")
		return false
	projects = test_career.get("research_projects", [])
	var quality_id := str(quality_project.get("id", ""))
	for index in range(projects.size()):
		var project: Dictionary = projects[index]
		if str(project.get("id", "")) == quality_id:
			project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
			projects[index] = project
			test_career["research_projects"] = projects
			break
	var quality_approval := ResearchManagerScript.approve_project(test_career, quality_id, [{
		"component": component,
		"metric": "Night Mode image quality",
		"value": "Night Mode Quality Level 1"
	}], 4000.0)
	if not bool(quality_approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get(component, 0)) != 2:
		_fail("Approving Night Mode Quality Level 1 did not advance its stored research level to 2.")
		return false
	var next_target := ResearchManagerScript.get_night_mode_research_target(test_career.get("research_component_levels", {}))
	if int(next_target.get("index", -1)) != 3 or str(next_target.get("technology", "")) != "Night Mode Quality Level 2":
		_fail("Night Mode did not offer Quality Level 2 as its next research target.")
		return false
	if not ResearchManagerScript.get_night_mode_research_target({"Night Mode": 31}).is_empty():
		_fail("Night Mode did not stop after its 30 quality upgrades.")
		return false
	return true


func _check_processor_technology_research() -> bool:
	var expected_durations := {
		"Control Unit": 120.0,
		"Instruction Decoder": 130.0,
		"Instruction Fetch Unit": 140.0,
		"Branch Prediction Unit": 150.0,
		"Memory Management Unit": 160.0,
		"Translation Lookaside Buffer": 170.0,
		"Internal Bus": 180.0,
		"Ring Bus / Interconnect Fabric": 190.0,
		"System Agent": 210.0,
		"I/O Controller": 220.0,
		"Clock Distribution Network": 230.0,
		"Voltage Regulator Interface": 240.0,
		"Thermal Sensor": 250.0,
		"Debug and Test Unit": 265.0,
		"Security Processing Unit": 280.0
	}
	if ResearchManagerScript.PROCESSOR_TECHNOLOGIES.size() != 15:
		_fail("Processor Research must contain exactly 15 approved Processor Technologies.")
		return false
	var test_career := {
		"staff_employees": [
			{"id": "processor_unlock_researcher", "department": "Research", "efficiency": 90}
		],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	for feature_value in ResearchManagerScript.PROCESSOR_TECHNOLOGIES:
		var feature := str(feature_value)
		var expected_days := float(expected_durations.get(feature, -1.0))
		if expected_days < 120.0 or expected_days > 280.0 or not ResearchManagerScript.COMPONENT_CATALOGUE.has(feature):
			_fail("%s is missing its assigned 120–280 day research duration or catalogue entry." % feature)
			return false
		var actual_days := ResearchManagerScript.get_component_research_duration_days(feature, 1)
		var expected_points := expected_days * ResearchManagerScript.TECHNOLOGY_POINTS_PER_RESEARCH_DAY
		var actual_points := ResearchManagerScript.get_technology_points_for_progress(feature, 1.0)
		if not is_equal_approx(actual_days, expected_days) or not is_equal_approx(actual_points, expected_points):
			_fail("%s does not use its assigned duration and the shared Technology Points conversion." % feature)
			return false
		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": feature,
			"staff_ids": ["processor_unlock_researcher"]
		}, 1000.0)
		if not bool(commission.get("ok", false)):
			_fail("%s could not be commissioned as a Processor Technology unlock: %s" % [feature, str(commission.get("error", ""))])
			return false
		var project: Dictionary = commission.get("project", {})
		if int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != feature or not is_equal_approx(float(project.get("required_research_days", 0.0)), expected_days):
			_fail("%s project did not preserve its one-time target or assigned research duration." % feature)
			return false
		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		if feature == "Control Unit":
			var wrong_approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
				"component": feature,
				"metric": "Processor subsystem functionality and architecture integration",
				"value": "Incorrect technology"
			}], 1500.0)
			if bool(wrong_approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get(feature, 0)) > 0:
				_fail("Processor Research approved a result that did not match the assigned technology.")
				return false
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": feature,
			"metric": "Processor subsystem functionality and architecture integration",
			"value": feature
		}], 2000.0)
		if not bool(approval.get("ok", false)) or int(test_career.get("research_component_levels", {}).get(feature, 0)) != 1:
			_fail("%s approval did not persist its one-time processor unlock: %s" % [feature, str(approval.get("error", ""))])
			return false
		var duplicate := ResearchManagerScript.commission_project(test_career, {
			"component": feature,
			"staff_ids": ["processor_unlock_researcher"]
		}, 3000.0)
		if bool(duplicate.get("ok", false)):
			_fail("%s could be commissioned again after its one-time unlock was approved." % feature)
			return false
	return true


func _check_processor_cpu_core_research() -> bool:
	const COMPONENT := "CPU Cores"
	if not ResearchManagerScript.COMPONENT_CATALOGUE.has(COMPONENT) or not ResearchManagerScript.PROCESSOR_RESEARCH_COMPONENTS.has(COMPONENT):
		_fail("CPU Cores is missing from the processor research catalogue or routing group.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(COMPONENT, 1), 750.0):
		_fail("Every CPU Core upgrade must use a fixed 750-day research duration.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 0.5), 3.75) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 1.0), 7.50) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 2.0), 15.00):
		_fail("CPU Cores is not using the shared duration-based Technology Points conversion.")
		return false

	var first_target: Dictionary = ResearchManagerScript.get_cpu_cores_research_target({})
	if int(first_target.get("index", -1)) != 2 or str(first_target.get("technology", "")) != "2 Cores" or int(first_target.get("core_count", -1)) != 2:
		_fail("CPU Cores did not begin with the expected 1-to-2 core research target.")
		return false
	var penultimate_target: Dictionary = ResearchManagerScript.get_cpu_cores_research_target({"CPU Cores": 28})
	if int(penultimate_target.get("index", -1)) != 30 or str(penultimate_target.get("technology", "")) != "30 Cores" or not ResearchManagerScript.get_cpu_cores_research_target({"CPU Cores": 29}).is_empty() or ResearchManagerScript.get_cpu_cores_max_for_level(29) != 30:
		_fail("CPU Cores does not stop cleanly at its maximum of 30 cores.")
		return false

	var test_career := {
		"staff_employees": [{"id": "cpu_core_researcher", "department": "Research", "efficiency": 90}],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	for expected_core_count in [2, 3]:
		var target: Dictionary = ResearchManagerScript.get_cpu_cores_research_target(test_career["research_component_levels"])
		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": COMPONENT,
			"staff_ids": ["cpu_core_researcher"]
		}, 1000.0 + float(expected_core_count))
		if not bool(commission.get("ok", false)):
			_fail("CPU Cores research could not be commissioned: %s" % str(commission.get("error", "")))
			return false
		var project: Dictionary = commission.get("project", {})
		var expected_target := "%d Cores" % expected_core_count
		if int(target.get("index", -1)) != expected_core_count or int(project.get("research_target_index", -1)) != expected_core_count or str(project.get("research_target", "")) != expected_target or not is_equal_approx(float(project.get("required_research_days", 0.0)), 750.0):
			_fail("CPU Cores research did not preserve the next sequential target or 750-day duration.")
			return false
		var duplicate := ResearchManagerScript.commission_project(test_career, {
			"component": COMPONENT,
			"staff_ids": ["cpu_core_researcher"]
		}, 1100.0)
		if bool(duplicate.get("ok", false)):
			_fail("CPU Cores allowed a duplicate project while the next core upgrade was already in progress.")
			return false
		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": COMPONENT,
			"metric": "Supported CPU core count",
			"value": expected_target
		}], 2000.0 + float(expected_core_count))
		if not bool(approval.get("ok", false)) or int(test_career["research_component_levels"].get(COMPONENT, 0)) != expected_core_count - 1:
			_fail("Approving the %s target did not persist the next CPU Core research level: %s" % [expected_target, str(approval.get("error", ""))])
			return false
	return true


func _check_processor_instruction_scheduler_research() -> bool:
	const COMPONENT := "Instruction Scheduler"
	const EXPECTED_CAPACITIES: Array[int] = [8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 320, 384, 448, 500]
	if not ResearchManagerScript.COMPONENT_CATALOGUE.has(COMPONENT) or not ResearchManagerScript.PROCESSOR_RESEARCH_COMPONENTS.has(COMPONENT):
		_fail("Instruction Scheduler is missing from the processor research catalogue or routing group.")
		return false
	if ResearchManagerScript.INSTRUCTION_SCHEDULER_ENTRY_LEVELS != EXPECTED_CAPACITIES or ResearchManagerScript.INSTRUCTION_SCHEDULER_MAX_RESEARCH_LEVEL != 13:
		_fail("Instruction Scheduler does not expose the approved 14-capacity progression from 8 to 500 entries.")
		return false
	if ResearchManagerScript.get_instruction_scheduler_entries_for_level(0) != 8 or ResearchManagerScript.get_instruction_scheduler_entries_for_level(13) != 500:
		_fail("Instruction Scheduler did not preserve its 8-entry baseline or 500-entry maximum.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(COMPONENT, 1), 270.0):
		_fail("Every Instruction Scheduler capacity upgrade must use a fixed 270-day research duration.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 0.5), 1.35) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 1.0), 2.70) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 13.0), 35.10):
		_fail("Instruction Scheduler is not using the shared 270-day Technology Points conversion.")
		return false

	var first_target: Dictionary = ResearchManagerScript.get_instruction_scheduler_research_target({})
	var final_target: Dictionary = ResearchManagerScript.get_instruction_scheduler_research_target({COMPONENT: 12})
	if int(first_target.get("index", -1)) != 1 or str(first_target.get("technology", "")) != "16 Entries" or int(first_target.get("entry_count", -1)) != 16:
		_fail("Instruction Scheduler did not begin with the expected 8-to-16-entry research upgrade.")
		return false
	if int(final_target.get("index", -1)) != 13 or str(final_target.get("technology", "")) != "500 Entries" or not ResearchManagerScript.get_instruction_scheduler_research_target({COMPONENT: 13}).is_empty():
		_fail("Instruction Scheduler did not stop cleanly at its 500-entry maximum.")
		return false

	var test_career := {
		"staff_employees": [{"id": "scheduler_researcher", "department": "Research", "efficiency": 90}],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	for expected_level in range(1, EXPECTED_CAPACITIES.size()):
		var target: Dictionary = ResearchManagerScript.get_instruction_scheduler_research_target(test_career["research_component_levels"])
		var expected_entries := EXPECTED_CAPACITIES[expected_level]
		var expected_target := "%d Entries" % expected_entries
		if int(target.get("index", -1)) != expected_level or str(target.get("technology", "")) != expected_target:
			_fail("Instruction Scheduler did not produce the next ordered target: %s." % expected_target)
			return false
		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": COMPONENT,
			"staff_ids": ["scheduler_researcher"]
		}, 5000.0 + float(expected_level))
		if not bool(commission.get("ok", false)):
			_fail("Instruction Scheduler research could not be commissioned: %s" % str(commission.get("error", "")))
			return false
		var project: Dictionary = commission.get("project", {})
		if int(project.get("research_target_index", -1)) != expected_level or str(project.get("research_target", "")) != expected_target or not is_equal_approx(float(project.get("required_research_days", 0.0)), 270.0):
			_fail("Instruction Scheduler project did not preserve its ordered target or fixed 270-day duration.")
			return false
		var duplicate := ResearchManagerScript.commission_project(test_career, {
			"component": COMPONENT,
			"staff_ids": ["scheduler_researcher"]
		}, 5100.0)
		if bool(duplicate.get("ok", false)):
			_fail("Instruction Scheduler allowed a duplicate project while the next upgrade was active.")
			return false
		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": COMPONENT,
			"metric": "Instruction scheduler entry capacity",
			"value": expected_target
		}], 6000.0 + float(expected_level))
		if not bool(approval.get("ok", false)) or int(test_career["research_component_levels"].get(COMPONENT, 0)) != expected_level:
			_fail("Approving %s did not persist the corresponding scheduler research level: %s" % [expected_target, str(approval.get("error", ""))])
			return false
	return true


func _has_full_dashboard_shell(dashboard: Control) -> bool:
	return dashboard.has_signal("back_requested") \
		and dashboard.has_signal("project_commission_requested") \
		and dashboard.has_signal("project_approve_requested") \
		and dashboard.has_signal("project_retry_requested") \
		and dashboard.has_signal("project_cancel_requested") \
		and is_instance_valid(dashboard.get_node_or_null("ResearchManagementFrame/ResearchManagementPage/ResearchManagementBody"))


func _has_active_staff(dashboard: Control, expected_ids: Array[String]) -> bool:
	var assigned_ids: Array = dashboard.call("_active_project_staff_ids")
	for employee_id in expected_ids:
		if not assigned_ids.has(employee_id):
			return false
	return true


func _project_ids(projects: Array) -> Array[String]:
	var ids: Array[String] = []
	for project_value in projects:
		if project_value is Dictionary:
			ids.append(str(project_value.get("id", "")))
	return ids


func _button_labels(buttons: Array) -> Array[String]:
	var labels: Array[String] = []
	for button_value in buttons:
		if button_value is Button:
			labels.append(str(button_value.text))
	return labels


func _fail(message: String) -> void:
	push_error(message)
	print("PHONE_CAMERA_PROCESSOR_RESEARCH_DASHBOARD_SMOKE_TEST: FAIL — " + message)



func _check_processor_cache_research() -> bool:
	var cache_specs: Array[Dictionary] = [
		{"component": "L2 Cache", "base_kb": 128, "increment_kb": 128, "maximum_kb": 19200},
		{"component": "L3 Cache", "base_kb": 1024, "increment_kb": 1024, "maximum_kb": 153600}
	]
	for spec in cache_specs:
		var component := str(spec.get("component", ""))
		var base_kb := int(spec.get("base_kb", 0))
		var increment_kb := int(spec.get("increment_kb", 0))
		var maximum_kb := int(spec.get("maximum_kb", 0))
		if not ResearchManagerScript.COMPONENT_CATALOGUE.has(component) or not ResearchManagerScript.PROCESSOR_RESEARCH_COMPONENTS.has(component):
			_fail("%s is missing from the processor research catalogue or routing group." % component)
			return false
		var maximum_level := ResearchManagerScript.L2_CACHE_MAX_RESEARCH_LEVEL if component == "L2 Cache" else ResearchManagerScript.L3_CACHE_MAX_RESEARCH_LEVEL
		if maximum_level != 149 or not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(component, 1), 10.0):
			_fail("%s does not use the 150-level, 10-day cache research progression." % component)
			return false
		if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 0.5), 0.05) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 1.0), 0.10) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(component, 149.0), 14.90):
			_fail("%s is not using the shared duration-based Technology Points conversion." % component)
			return false

		var first_target: Dictionary
		var final_target: Dictionary
		if component == "L2 Cache":
			first_target = ResearchManagerScript.get_l2_cache_research_target({})
			final_target = ResearchManagerScript.get_l2_cache_research_target({component: 148})
			if not ResearchManagerScript.get_l2_cache_research_target({component: 149}).is_empty():
				_fail("L2 Cache did not stop at its 19,200 KB maximum.")
				return false
		else:
			first_target = ResearchManagerScript.get_l3_cache_research_target({})
			final_target = ResearchManagerScript.get_l3_cache_research_target({component: 148})
			if not ResearchManagerScript.get_l3_cache_research_target({component: 149}).is_empty():
				_fail("L3 Cache did not stop at its 153,600 KB maximum.")
				return false
		var first_capacity := base_kb + increment_kb
		if int(first_target.get("index", -1)) != 1 or int(first_target.get("capacity_kb", -1)) != first_capacity or str(first_target.get("technology", "")) != "%d KB" % first_capacity:
			_fail("%s did not begin at the expected first capacity upgrade." % component)
			return false
		if int(final_target.get("index", -1)) != 149 or int(final_target.get("capacity_kb", -1)) != maximum_kb or str(final_target.get("technology", "")) != "%d KB" % maximum_kb:
			_fail("%s did not reach its expected final capacity at research level 149." % component)
			return false

		var test_career := {
			"staff_employees": [{"id": "cache_researcher", "department": "Research", "efficiency": 90}],
			"research_projects": [],
			"research_component_levels": {},
			"research_technologies": {},
			"next_research_project_id": 1
		}
		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": component,
			"staff_ids": ["cache_researcher"]
		}, 7000.0)
		if not bool(commission.get("ok", false)):
			_fail("%s research could not be commissioned: %s" % [component, str(commission.get("error", ""))])
			return false
		var project: Dictionary = commission.get("project", {})
		if int(project.get("research_target_index", -1)) != 1 or str(project.get("research_target", "")) != str(first_target.get("technology", "")) or not is_equal_approx(float(project.get("required_research_days", 0.0)), 10.0):
			_fail("%s project did not preserve its ordered target or 10-day duration." % component)
			return false
		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": component,
			"metric": "Validated %s capacity" % component,
			"value": str(first_target.get("technology", ""))
		}], 8000.0)
		if not bool(approval.get("ok", false)) or int(test_career["research_component_levels"].get(component, 0)) != 1:
			_fail("Approving the first %s target did not persist its research level: %s" % [component, str(approval.get("error", ""))])
			return false

	return true


func _check_processor_design_research() -> bool:
	const COMPONENT := "Processor Design"
	if not ResearchManagerScript.COMPONENT_CATALOGUE.has(COMPONENT) or not ResearchManagerScript.PROCESSOR_RESEARCH_COMPONENTS.has(COMPONENT):
		_fail("Processor Design is missing from the Processor Research catalogue or routing group.")
		return false
	if ResearchManagerScript.PHONE_SENSOR_COMPONENTS.has(COMPONENT) or ResearchManagerScript.CAMERA_SENSOR_COMPONENTS.has(COMPONENT):
		_fail("Processor Design was incorrectly classified as Phone or Camera research.")
		return false
	if ResearchManagerScript.get_processor_design_max_for_level(0) != 1 or ResearchManagerScript.get_processor_design_max_for_level(29) != 30:
		_fail("Processor Design did not preserve Design 01 as the default or the 30-design maximum.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_component_research_duration_days(COMPONENT, 2), 2100.0):
		_fail("Each new Processor Design must use a fixed 2,100-day research duration.")
		return false
	if not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 0.5), 10.5) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 1.0), 21.0) or not is_equal_approx(ResearchManagerScript.get_technology_points_for_progress(COMPONENT, 29.0), 609.0):
		_fail("Processor Design is not using the shared duration-based Technology Points conversion.")
		return false

	var first_target: Dictionary = ResearchManagerScript.get_processor_design_research_target({})
	var final_target: Dictionary = ResearchManagerScript.get_processor_design_research_target({COMPONENT: 28})
	if int(first_target.get("index", -1)) != 2 or str(first_target.get("technology", "")) != "Design 02" or int(first_target.get("design_count", -1)) != 2:
		_fail("Processor Design did not begin with the expected Design 01-to-02 unlock.")
		return false
	if int(final_target.get("index", -1)) != 30 or str(final_target.get("technology", "")) != "Design 30" or not ResearchManagerScript.get_processor_design_research_target({COMPONENT: 29}).is_empty():
		_fail("Processor Design did not stop cleanly at its 30-design maximum.")
		return false

	var test_career := {
		"staff_employees": [{"id": "processor_design_researcher", "department": "Research", "efficiency": 90}],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	for expected_design_count in range(2, ResearchManagerScript.PROCESSOR_DESIGN_MAX_COUNT + 1):
		var target: Dictionary = ResearchManagerScript.get_processor_design_research_target(test_career["research_component_levels"])
		var expected_target := "Design %02d" % expected_design_count
		if int(target.get("index", -1)) != expected_design_count or str(target.get("technology", "")) != expected_target:
			_fail("Processor Design did not produce the next ordered unlock: %s." % expected_target)
			return false
		var commission := ResearchManagerScript.commission_project(test_career, {
			"component": COMPONENT,
			"staff_ids": ["processor_design_researcher"]
		}, 7000.0 + float(expected_design_count))
		if not bool(commission.get("ok", false)):
			_fail("Processor Design research could not be commissioned: %s" % str(commission.get("error", "")))
			return false
		var project: Dictionary = commission.get("project", {})
		if str(project.get("component", "")) != COMPONENT or int(project.get("research_target_index", -1)) != expected_design_count or str(project.get("research_target", "")) != expected_target or not is_equal_approx(float(project.get("required_research_days", 0.0)), 2100.0):
			_fail("Processor Design project did not preserve its Processor Research target or fixed 2,100-day duration.")
			return false
		var duplicate := ResearchManagerScript.commission_project(test_career, {
			"component": COMPONENT,
			"staff_ids": ["processor_design_researcher"]
		}, 7100.0)
		if bool(duplicate.get("ok", false)):
			_fail("Processor Design allowed a duplicate project while the next design unlock was active.")
			return false
		for project_index in range(test_career["research_projects"].size()):
			var saved_project: Dictionary = test_career["research_projects"][project_index]
			if str(saved_project.get("id", "")) == str(project.get("id", "")):
				saved_project["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
				test_career["research_projects"][project_index] = saved_project
				break
		var approval := ResearchManagerScript.approve_project(test_career, str(project.get("id", "")), [{
			"component": COMPONENT,
			"metric": "Available processor design",
			"value": expected_target
		}], 7200.0 + float(expected_design_count))
		if not bool(approval.get("ok", false)) or int(test_career["research_component_levels"].get(COMPONENT, 0)) != expected_design_count - 1:
			_fail("Approving %s did not persist the next Processor Design unlock: %s" % [expected_target, str(approval.get("error", ""))])
			return false
	return true
