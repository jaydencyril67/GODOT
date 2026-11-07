extends RefCounted
class_name DigitalWorldResearchManager

# Research is measured in real engineering hours, never research points.
const PRODUCTIVE_HOURS_PER_DAY := 8.0
const BASE_RESEARCH_WORK_HOURS := 120.0
const STATUS_ACTIVE := "active"
const STATUS_AWAITING_VALIDATION := "awaiting_validation"
const STATUS_APPROVED := "approved"
const STATUS_REJECTED := "rejected"
const STATUS_CANCELLED := "cancelled"
const COMPONENT_CATALOGUE := [
	"Screen Technology",
	"Phone Thickness",
	"Border Radius"
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
		"available_efficiency": available_efficiency,
		"productive_hours_per_game_day": available_efficiency / 100.0 * PRODUCTIVE_HOURS_PER_DAY
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
	var daily_work_hours := (team_efficiency / 100.0) * PRODUCTIVE_HOURS_PER_DAY
	if daily_work_hours <= 0.0:
		return _failure("The assigned research team needs positive efficiency.")

	var expected_days := maxi(1, int(ceil(BASE_RESEARCH_WORK_HOURS / daily_work_hours)))
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
		"daily_work_hours": daily_work_hours,
		"work_required_hours": BASE_RESEARCH_WORK_HOURS,
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
		return _failure("Choose Screen Tech, Phone Thickness or Border Radius.")

	var budget := float(request.get("budget", 0.0))
	if budget <= 0.0:
		return _failure("Enter a research investment greater than zero.")

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

	var balance := float(career.get("balance", 0.0))
	if balance < budget:
		return _failure("The company does not have enough available funds for this research investment.")

	var project_id := "RDP-%06d" % int(career.get("next_research_project_id", 1))
	career["next_research_project_id"] = int(career.get("next_research_project_id", 1)) + 1
	career["balance"] = balance - budget

	var project := {
		"id": project_id,
		"title": "Research: " + component,
		"component": component,
		"components": [component],
		"objective": "",
		"project_type": "technology_improvement",
		"budget": budget,
		"work_required_hours": float(estimate.get("work_required_hours", BASE_RESEARCH_WORK_HOURS)),
		"work_completed_hours": 0.0,
		"daily_work_hours": float(estimate.get("daily_work_hours", 0.0)),
		"estimated_duration_days": int(estimate.get("expected_duration_days", 1)),
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
		var team_efficiency := 0.0
		for employee_value in employees:
			if not (employee_value is Dictionary):
				continue
			var employee: Dictionary = employee_value
			var employee_id := str(employee.get("id", ""))
			if not staff_ids.has(employee_id) or str(employee.get("department", "")) != "Research":
				continue
			team_efficiency += float(clampi(int(employee.get("efficiency", 0)), 0, 100))

		if team_efficiency <= 0.0:
			project["pause_reason"] = "No assigned Research employees are currently available."
			continue

		project["pause_reason"] = ""
		var productive_hours := (team_efficiency / 100.0) * PRODUCTIVE_HOURS_PER_DAY * game_days
		var required_hours := float(project.get("work_required_hours", 0.0))
		var completed_hours := float(project.get("work_completed_hours", 0.0))
		completed_hours = minf(required_hours, completed_hours + productive_hours)
		project["work_completed_hours"] = completed_hours

		if required_hours > 0.0 and completed_hours >= required_hours:
			project["status"] = STATUS_AWAITING_VALIDATION
			project["completed_at_unix"] = game_time_unix
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
