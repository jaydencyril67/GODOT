extends RefCounted
class_name DigitalWorldResearchManager

# Research follows the in-game calendar. Assigned staff efficiency shortens the base journey.
const BASE_RESEARCH_DURATION_DAYS := 30.0
const MIN_RESEARCH_DURATION_DAYS := 1.0
const STATUS_ACTIVE := "active"
const STATUS_AWAITING_VALIDATION := "awaiting_validation"
const STATUS_APPROVED := "approved"
const STATUS_REJECTED := "rejected"
const STATUS_SUCCESSFUL := "successful"
const STATUS_UNSUCCESSFUL := "unsuccessful"
const RESEARCH_SUCCESS_CHANCE := 0.70
const STATUS_CANCELLED := "cancelled"
const COMPONENT_CATALOGUE := [
	"Screen Technology",
	"Phone Thickness",
	"Border Radius",
	"Speakers",
	"Charge Port"
]


static func normalize_component(component_value: String) -> String:
	var component := component_value.strip_edges()
	if component == "Screen Tech":
		return "Screen Technology"
	return component


static func ensure_state(career: Dictionary) -> void:
	var projects_value: Variant = career.get("research_projects", [])
	if not (projects_value is Array):
		career["research_projects"] = []
	var projects: Array = career.get("research_projects", [])
	for index in range(projects.size()):
		if not (projects[index] is Dictionary):
			continue
		var project: Dictionary = projects[index]
		if not project.has("required_research_days"):
			var team_efficiency := maxf(0.0, float(project.get("team_efficiency", 0.0)))
			var migrated_duration := maxf(MIN_RESEARCH_DURATION_DAYS, BASE_RESEARCH_DURATION_DAYS - team_efficiency / 100.0)
			var old_required_hours := maxf(0.001, float(project.get("work_required_hours", 120.0)))
			var old_completed_hours := clampf(float(project.get("work_completed_hours", 0.0)) / old_required_hours, 0.0, 1.0)
			project["required_research_days"] = migrated_duration
			project["completed_research_days"] = migrated_duration * old_completed_hours
			project["estimated_duration_days"] = migrated_duration
		project.erase("work_required_hours")
		project.erase("work_completed_hours")
		project.erase("daily_work_hours")
		projects[index] = project
	career["research_projects"] = projects
	var component_levels_value: Variant = career.get("research_component_levels", {})
	if not (component_levels_value is Dictionary):
		career["research_component_levels"] = {}
	var technologies_value: Variant = career.get("research_technologies", {})
	if not (technologies_value is Dictionary):
		career["research_technologies"] = {}
	var next_id := maxi(1, int(career.get("next_research_project_id", 1)))
	career["next_research_project_id"] = next_id


static func get_workforce_summary(career: Dictionary) -> Dictionary:
	ensure_state(career)
	var total_staff := 0
	var available_staff := 0
	var total_efficiency := 0.0
	var available_efficiency := 0.0
	var occupied_ids := _get_active_project_staff_ids(career)

	for employee_value in career.get("staff_employees", []):
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("department", "")) != "Research":
			continue
		var employee_id := str(employee.get("id", ""))
		var efficiency := float(clampi(int(employee.get("efficiency", 0)), 0, 100))
		total_staff += 1
		total_efficiency += efficiency
		if employee_id.is_empty() or occupied_ids.has(employee_id):
			continue
		available_staff += 1
		available_efficiency += efficiency

	return {
		"staff_count": total_staff,
		"available_staff_count": available_staff,
		"total_efficiency": total_efficiency,
		"available_efficiency": available_efficiency
	}


static func estimate_research(component_value: String, requested_staff: Array, employees: Array) -> Dictionary:
	var component := normalize_component(component_value)
	if not COMPONENT_CATALOGUE.has(component):
		return _failure("Choose an available research component.")

	var selected_ids: Array[String] = []
	var team_efficiency := 0.0
	var staff_count := 0
	for staff_value in requested_staff:
		var staff_id := str(staff_value).strip_edges()
		if staff_id.is_empty() or selected_ids.has(staff_id):
			continue
		for employee_value in employees:
			if not (employee_value is Dictionary):
				continue
			var employee: Dictionary = employee_value
			if str(employee.get("id", "")) != staff_id or str(employee.get("department", "")) != "Research":
				continue
			selected_ids.append(staff_id)
			team_efficiency += float(clampi(int(employee.get("efficiency", 0)), 0, 100))
			staff_count += 1
			break

	if staff_count == 0:
		return _failure("Assign at least one available Research employee.")

	var average_efficiency := team_efficiency / float(staff_count)
	var expected_days := maxf(
		MIN_RESEARCH_DURATION_DAYS,
		BASE_RESEARCH_DURATION_DAYS - team_efficiency / 100.0
	)
	# Team size increases speed; average staff efficiency determines the success chance.
	# The chance is capped below 100% so research always retains some uncertainty.
	var success_chance := clampf(50.0 + average_efficiency * 0.45, 50.0, 95.0)
	return {
		"ok": true,
		"component": component,
		"staff_ids": selected_ids,
		"staff_count": staff_count,
		"team_efficiency": team_efficiency,
		"average_efficiency": average_efficiency,
		"expected_duration_days": expected_days,
		"success_chance": success_chance
	}


static func commission_project(career: Dictionary, request: Dictionary, game_time_unix: float) -> Dictionary:
	ensure_state(career)

	for project_value in career.get("research_projects", []):
		if project_value is Dictionary and str(project_value.get("status", "")) == STATUS_ACTIVE:
			return _failure("Finish the active research before starting another project.")

	var component := normalize_component(str(request.get("component", "")))
	if component.is_empty():
		var requested_components: Variant = request.get("components", [])
		if requested_components is Array and not requested_components.is_empty():
			component = normalize_component(str(requested_components[0]))
	if not COMPONENT_CATALOGUE.has(component):
		return _failure("Choose an available research component.")

	var requested_staff: Variant = request.get("staff_ids", [])
	if not (requested_staff is Array) or requested_staff.is_empty():
		return _failure("Assign at least one available Research employee.")

	var occupied_ids := _get_active_project_staff_ids(career)
	var valid_staff_ids: Array[String] = []
	for staff_value in requested_staff:
		var staff_id := str(staff_value).strip_edges()
		if staff_id.is_empty() or valid_staff_ids.has(staff_id):
			continue
		var employee := _find_employee(career, staff_id)
		if employee.is_empty() or str(employee.get("department", "")) != "Research":
			return _failure("Every assigned person must be a Research department employee.")
		if occupied_ids.has(staff_id):
			return _failure("An assigned researcher is already working on another active project.")
		valid_staff_ids.append(staff_id)

	var estimate := estimate_research(component, valid_staff_ids, career.get("staff_employees", []))
	if not bool(estimate.get("ok", false)):
		return _failure(str(estimate.get("error", "The research team could not be calculated.")))

	var project_id := "RDP-%06d" % int(career.get("next_research_project_id", 1))
	career["next_research_project_id"] = int(career.get("next_research_project_id", 1)) + 1
	var project := {
		"id": project_id,
		"title": "Research: " + component,
		"component": component,
		"components": [component],
		"objective": "",
		"project_type": "technology_improvement",
		"required_research_days": float(estimate.get("expected_duration_days", BASE_RESEARCH_DURATION_DAYS)),
		"completed_research_days": 0.0,
		"estimated_duration_days": float(estimate.get("expected_duration_days", BASE_RESEARCH_DURATION_DAYS)),
		"team_efficiency": float(estimate.get("team_efficiency", 0.0)),
		"average_efficiency": float(estimate.get("average_efficiency", 0.0)),
		"success_chance": float(estimate.get("success_chance", 50.0)),
		"staff_ids": valid_staff_ids,
		"status": STATUS_ACTIVE,
		"pause_reason": "",
		"created_at_unix": game_time_unix,
		"completed_at_unix": 0.0,
		"approved_at_unix": 0.0,
		"approved_results": []
	}
	var projects: Array = career.get("research_projects", [])
	projects.append(project)
	career["research_projects"] = projects
	return {"ok": true, "project": project.duplicate(true)}


static func advance_projects(career: Dictionary, in_game_seconds: float, game_time_unix: float) -> Array[String]:
	ensure_state(career)
	var completed_project_ids: Array[String] = []
	if in_game_seconds <= 0.0:
		return completed_project_ids

	var employees: Array = career.get("staff_employees", [])
	var projects: Array = career.get("research_projects", [])
	var game_days := in_game_seconds / 86400.0

	for project_value in projects:
		if not (project_value is Dictionary):
			continue
		var project: Dictionary = project_value
		if str(project.get("status", "")) != STATUS_ACTIVE:
			continue

		var staff_ids: Array = project.get("staff_ids", [])
		var has_assigned_researcher := false
		for employee_value in employees:
			if not (employee_value is Dictionary):
				continue
			var employee: Dictionary = employee_value
			var employee_id := str(employee.get("id", ""))
			if staff_ids.has(employee_id) and str(employee.get("department", "")) == "Research":
				has_assigned_researcher = true
				break

		if not has_assigned_researcher:
			project["pause_reason"] = "No assigned Research employees are currently available."
			continue

		project["pause_reason"] = ""
		var required_days := maxf(MIN_RESEARCH_DURATION_DAYS, float(project.get("required_research_days", BASE_RESEARCH_DURATION_DAYS)))
		var completed_days := maxf(0.0, float(project.get("completed_research_days", 0.0)))
		completed_days = minf(required_days, completed_days + game_days)
		project["completed_research_days"] = completed_days

		if completed_days >= required_days:
			project["completed_at_unix"] = game_time_unix
			var success_roll := randf()
			var successful := success_roll < RESEARCH_SUCCESS_CHANCE
			project["success_roll"] = success_roll
			project["success_chance"] = RESEARCH_SUCCESS_CHANCE * 100.0
			if successful:
				project["status"] = STATUS_SUCCESSFUL
				var component := normalize_component(str(project.get("component", "")))
				var component_levels: Dictionary = career.get("research_component_levels", {})
				if component in ["Phone Thickness", "Border Radius"]:
					component_levels[component] = mini(20, int(component_levels.get(component, 0)) + 1)
				elif component == "Speakers":
					component_levels[component] = mini(11, int(component_levels.get(component, 0)) + 1)
				elif component == "Charge Port":
					# The first port is the baseline; each success unlocks the next port.
					component_levels[component] = mini(4, int(component_levels.get(component, 0)) + 1)
				career["research_component_levels"] = component_levels
			else:
				project["status"] = STATUS_UNSUCCESSFUL
			completed_project_ids.append(str(project.get("id", "")))

	career["research_projects"] = projects
	return completed_project_ids


static func approve_project(career: Dictionary, project_id: String, results: Array, game_time_unix: float) -> Dictionary:
	ensure_state(career)
	var projects: Array = career.get("research_projects", [])
	var project_index := _find_project_index(projects, project_id)
	if project_index < 0:
		return _failure("Research project not found.")

	var project: Dictionary = projects[project_index]
	if str(project.get("status", "")) != STATUS_AWAITING_VALIDATION:
		return _failure("Only completed projects awaiting validation can be approved.")
	if results.is_empty():
		return _failure("Add at least one validated technology result before approving.")

	var project_components: Array = project.get("components", [])
	var technologies: Dictionary = career.get("research_technologies", {})
	var approved_results: Array = []
	for result_value in results:
		if not (result_value is Dictionary):
			return _failure("Every research result must be a structured technology record.")
		var result: Dictionary = result_value.duplicate(true)
		var component := normalize_component(str(result.get("component", "")))
		var metric := str(result.get("metric", "")).strip_edges()
		var value := str(result.get("value", "")).strip_edges()
		if component.is_empty() or not project_components.has(component):
			return _failure("Each result must refer to the component included in this project.")
		if metric.is_empty() or value.is_empty():
			return _failure("Each approved finding must include a measured attribute and result value.")
		var component_history: Array = technologies.get(component, [])
		component_history.append(result)
		technologies[component] = component_history
		approved_results.append(result)

	project["status"] = STATUS_APPROVED
	project["approved_at_unix"] = game_time_unix
	project["approved_results"] = approved_results
	projects[project_index] = project
	career["research_projects"] = projects
	career["research_technologies"] = technologies
	return {"ok": true, "project": project.duplicate(true)}


static func reject_project(career: Dictionary, project_id: String, review_note: String) -> Dictionary:
	ensure_state(career)
	var projects: Array = career.get("research_projects", [])
	var project_index := _find_project_index(projects, project_id)
	if project_index < 0:
		return _failure("Research project not found.")
	var project: Dictionary = projects[project_index]
	if str(project.get("status", "")) != STATUS_AWAITING_VALIDATION:
		return _failure("Only completed projects awaiting validation can be rejected.")
	project["status"] = STATUS_REJECTED
	project["review_note"] = review_note.strip_edges()
	projects[project_index] = project
	career["research_projects"] = projects
	return {"ok": true, "project": project.duplicate(true)}


static func _get_active_project_staff_ids(career: Dictionary) -> Array[String]:
	var occupied_ids: Array[String] = []
	for project_value in career.get("research_projects", []):
		if not (project_value is Dictionary):
			continue
		var project: Dictionary = project_value
		if str(project.get("status", "")) != STATUS_ACTIVE:
			continue
		for staff_value in project.get("staff_ids", []):
			var staff_id := str(staff_value)
			if not staff_id.is_empty() and not occupied_ids.has(staff_id):
				occupied_ids.append(staff_id)
	return occupied_ids


static func _find_employee(career: Dictionary, employee_id: String) -> Dictionary:
	for employee_value in career.get("staff_employees", []):
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("id", "")) == employee_id:
			return employee
	return {}


static func _find_project_index(projects: Array, project_id: String) -> int:
	for index in range(projects.size()):
		var project_value: Variant = projects[index]
		if project_value is Dictionary and str(project_value.get("id", "")) == project_id:
			return index
	return -1


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
