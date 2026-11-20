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
		"REAR CAMERA COUNT",
		"REAR FLASH COUNT",
		"PORTRAIT MODE",
		"MACRO PHOTOGRAPHY",
		"ULTRA-WIDE PHOTOGRAPHY",
		"TELEPHOTO PHOTOGRAPHY",
		"PANORAMA PHOTOGRAPHY",
		"RAW PHOTOGRAPHY",
		"BURST PHOTOGRAPHY",
		"SUPER SLOW-MOTION RECORDING",
		"TIME-LAPSE RECORDING",
		"HYPERLAPSE RECORDING",
		"CINEMATIC VIDEO"
	]
	if camera_labels != expected_camera_labels:
		_fail("Camera Research must expose both camera MP projects, both rear-hardware capacity projects, and all 11 one-time camera unlocks in the approved order.")
		host.queue_free()
		quit(1)
		return
	if not _check_camera_one_time_research() or not _check_rear_hardware_count_research():
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
	if _project_ids(processor_dashboard.call("_get_active_projects")) != ["RDP-PROCESSOR-ACTIVE"]:
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
		_fail("Processor Research must expose only the 15 approved Processor Technologies in their approved order.")
		host.queue_free()
		quit(1)
		return
	if not _check_processor_technology_research():
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
		"Super Slow-Motion Recording": 370.0,
		"Time-Lapse Recording": 290.0,
		"Hyperlapse Recording": 340.0,
		"Cinematic Video": 360.0
	}
	if ResearchManagerScript.CAMERA_SENSOR_COMPONENTS.size() != 11:
		_fail("Camera research must contain exactly the 11 approved one-time unlock features.")
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
		if expected_days < 240.0 or expected_days > 370.0 or not ResearchManagerScript.COMPONENT_CATALOGUE.has(feature):
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
	print("PHONE_CAMERA_RESEARCH_DASHBOARD_SMOKE_TEST: FAIL — " + message)
