extends SceneTree

const PhoneResearchDashboardScene: PackedScene = preload("res://scenes/research_allocation_dashboard.tscn")
const CameraResearchDashboardScene: PackedScene = preload("res://scenes/camera_research_dashboard.tscn")
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
			"id": "RDP-PHONE-PENDING",
			"component": "Charging Speed",
			"status": ResearchManagerScript.STATUS_AWAITING_VALIDATION,
			"staff_ids": []
		},
		{
			"id": "RDP-CAMERA-PENDING",
			"component": "Front Camera MP",
			"status": ResearchManagerScript.STATUS_AWAITING_VALIDATION,
			"staff_ids": []
		}
	]
	var dashboard_data := {
		"company_name": "Research Dashboard Smoke Test",
		"balance": 5000000.0,
		"staff_employees": [
			{"id": "phone_researcher", "full_name": "Phone Researcher", "department": "Research"},
			{"id": "camera_researcher", "full_name": "Camera Researcher", "department": "Research"}
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
	if not _has_active_staff(phone_dashboard, ["phone_researcher", "camera_researcher"]):
		_fail("Phone Research lost the shared staff-availability lock for an active Camera project.")
		host.queue_free()
		quit(1)
		return
	phone_dashboard.call("_open_creation_scene")
	var phone_options: Array = phone_dashboard.get("component_buttons")
	var phone_labels := _button_labels(phone_options)
	if phone_labels.has("FRONT CAMERA MP") or phone_labels.has("REAR CAMERA MP") or not phone_labels.has("RAM"):
		_fail("Phone Research still exposes a Camera MP category or lost its normal Phone categories.")
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
	if _project_ids(camera_dashboard.call("_get_active_projects")) != ["RDP-CAMERA-ACTIVE"]:
		_fail("Camera Research is displaying a Phone active project or hiding a Camera active project.")
		host.queue_free()
		quit(1)
		return
	if _project_ids(camera_dashboard.call("_get_pending_validation_projects")) != ["RDP-CAMERA-PENDING"]:
		_fail("Camera Research is displaying a Phone validation project or hiding a Camera validation project.")
		host.queue_free()
		quit(1)
		return
	if not _has_active_staff(camera_dashboard, ["phone_researcher", "camera_researcher"]):
		_fail("Camera Research lost the shared staff-availability lock for an active Phone project.")
		host.queue_free()
		quit(1)
		return
	camera_dashboard.call("_open_creation_scene")
	var camera_options: Array = camera_dashboard.get("component_buttons")
	var camera_labels := _button_labels(camera_options)
	if camera_labels != ["REAR CAMERA MP", "FRONT CAMERA MP"]:
		_fail("Camera Research must expose only Rear Camera MP and Front Camera MP, in that order.")
		host.queue_free()
		quit(1)
		return
	if not camera_dashboard.has_signal("project_commission_requested") or not camera_dashboard.has_signal("project_approve_requested") or not camera_dashboard.has_signal("project_retry_requested") or not camera_dashboard.has_signal("project_cancel_requested"):
		_fail("Camera Research is missing one or more of the full R&D management signals.")
		host.queue_free()
		quit(1)
		return

	host.queue_free()
	await process_frame
	print("PHONE_CAMERA_RESEARCH_DASHBOARD_SMOKE_TEST: PASS")
	quit(0)


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
