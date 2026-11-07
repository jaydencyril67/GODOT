extends RefCounted
class_name DigitalWorldResearchManager

# A research employee contributes productive engineering hours, not abstract points.
# One fully efficient researcher contributes eight productive hours per in-game day.
const PRODUCTIVE_HOURS_PER_DAY := 8.0
const STATUS_ACTIVE := "active"
const STATUS_AWAITING_VALIDATION := "awaiting_validation"
const STATUS_APPROVED := "approved"
const STATUS_REJECTED := "rejected"
const STATUS_CANCELLED := "cancelled"
const COMPONENT_CATALOGUE := [
	"Phone Type", "Phone Thickness", "Border Radius", "Screen Technology",
	"Screen Size", "Screen Type", "Power & Volume Buttons", "Speakers",
	"Charging Port", "Side Buttons", "Home Button", "Device Colour",
	"Front Camera", "Back Design", "Rear Camera",
	"RAM Technology", "RAM", "Internal Storage", "Mobile Internet", "Wi-Fi",
	"Bluetooth", "Battery", "Charging Speed", "Wireless Charging", "Sensors",
	"Front Camera Megapixels", "Rear Camera Megapixels", "Memory Clock",
	"Refresh Rate", "Cooling System",
	"Box Package", "Phone Case", "Charger", "Protection Glass",
	"Wireless Earbuds", "Smartwatch", "Power Bank"
]


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


static func commission_project(career: Dictionary, request: Dictionary, game_time_unix: float) -> Dictionary:
	ensure_state(career)

	var components: Array[String] = []
	var requested_components: Variant = request.get("components", [])
	if requested_components is Array:
		for component_value in requested_components:
			var component := str(component_value).strip_edges()
			if not component.is_empty() and not components.has(component):
				components.append(component)
	var single_component := str(request.get("component", "")).strip_edges()
	if components.is_empty() and not single_component.is_empty():
		components.append(single_component)
	if components.is_empty():
		return _failure("Choose at least one technology component for this project.")
	for component in components:
		if not COMPONENT_CATALOGUE.has(component):
			return _failure("The selected component is not part of the company's technology catalogue: " + component)

	var title := str(request.get("title", "")).strip_edges()
	if title.is_empty():
		var component_titles := ""
		for component in components:
			if not component_titles.is_empty():
				component_titles += ", "
			component_titles += component
		title = "Research: " + component_titles

	var budget := float(request.get("budget", 0.0))
	if budget <= 0.0:
		return _failure("A research project must have a positive approved budget.")

	var required_work_hours := float(request.get("required_work_hours", 0.0))
	if required_work_hours <= 0.0:
		return _failure("The project needs a valid engineering-work estimate.")

	var requested_staff: Variant = request.get("staff_ids", [])
	if not (requested_staff is Array) or requested_staff.is_empty():
		return _failure("Assign at least one Research department employee.")

	var occupied_ids := _get_active_project_staff_ids(career)
	var valid_staff_ids: Array[String] = []
	for staff_value in requested_staff:
		var staff_id := str(staff_value).strip_edges()
		if staff_id.is_empty() or valid_staff_ids.has(staff_id):
			continue
		var employee := _find_employee(career, staff_id)
		if employee.is_empty() or str(employee.get("department", "")) != "Research":
			return _failure("Every assigned employee must be an existing Research department employee.")
		if occupied_ids.has(staff_id):
			return _failure("An assigned employee is already working on another active research project.")
		valid_staff_ids.append(staff_id)
	if valid_staff_ids.is_empty():
		return _failure("Assign at least one available Research department employee.")

	var balance := float(career.get("balance", 0.0))
	if balance < budget:
		return _failure("The company does not have enough available funds for this project.")

	var project_id := "RDP-%06d" % int(career.get("next_research_project_id", 1))
	career["next_research_project_id"] = int(career.get("next_research_project_id", 1)) + 1
	career["balance"] = balance - budget

	var project := {
		"id": project_id,
		"title": title,
		"components": components,
		"objective": str(request.get("objective", "")).strip_edges(),
		"project_type": str(request.get("project_type", "technology_improvement")),
		"budget": budget,
		"work_required_hours": required_work_hours,
		"work_completed_hours": 0.0,
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
		return _failure("Add at least one validated technology result before approving the project.")

	var project_components: Array = project.get("components", [])
	var technologies: Dictionary = career.get("research_technologies", {})
	var approved_results: Array = []
	for result_value in results:
		if not (result_value is Dictionary):
			return _failure("Every research result must be a structured technology record.")
		var result: Dictionary = result_value.duplicate(true)
		var component := str(result.get("component", "")).strip_edges()
		var metric := str(result.get("metric", "")).strip_edges()
		var value := str(result.get("value", "")).strip_edges()
		if component.is_empty() or not project_components.has(component):
			return _failure("Each result must refer to a component included in this project.")
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
