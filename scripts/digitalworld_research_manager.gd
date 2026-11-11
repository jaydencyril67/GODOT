extends RefCounted
class_name DigitalWorldResearchManager

const ScreenTechnologySystem = preload("res://scripts/screen_technology_system.gd")

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
const FRONT_CAMERA_MODEL_COUNT := 8
const SCREEN_WIDTH_RESEARCH_LEVELS := 8
const SCREEN_HEIGHT_RESEARCH_LEVELS := 9
const COMPONENT_CATALOGUE := [
	"Screen Technology",
	"Screen Width",
	"Screen Height",
	"Phone Thickness",
	"Border Radius",
	"Speakers",
	"Charge Port",
	"Home Button",
	"Front Camera",
	"RAM",
	"Internal Storage",
	"RAM Technology",
	"Mobile Network",
	"Wi-Fi",
	"Bluetooth"
]

const MOBILE_NETWORK_SEQUENCE := [
	{"generation": "1G", "generation_name": "Analog Cellular", "technology": "AMPS"},
	{"generation": "1G", "generation_name": "Analog Cellular", "technology": "NMT"},
	{"generation": "1G", "generation_name": "Analog Cellular", "technology": "TACS"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "GSM"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "IS-95 (cdmaOne)"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "D-AMPS (IS-136)"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "GPRS"},
	{"generation": "2G", "generation_name": "Digital Cellular", "technology": "EDGE"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "UMTS / WCDMA"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "CDMA2000"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "TD-SCDMA"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "HSPA"},
	{"generation": "3G", "generation_name": "Mobile Broadband", "technology": "HSPA+"},
	{"generation": "4G", "generation_name": "High-Speed Mobile Broadband", "technology": "LTE"},
	{"generation": "4G", "generation_name": "High-Speed Mobile Broadband", "technology": "LTE-Advanced"},
	{"generation": "4G", "generation_name": "High-Speed Mobile Broadband", "technology": "LTE-Advanced Pro"},
	{"generation": "5G", "generation_name": "New Radio", "technology": "5G NSA"},
	{"generation": "5G", "generation_name": "New Radio", "technology": "5G SA"},
	{"generation": "5G", "generation_name": "New Radio", "technology": "5G-Advanced"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "6G (IMT-2030)"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "Terahertz Communications"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "AI-Native Networking"},
	{"generation": "6G", "generation_name": "Next-Generation Wireless", "technology": "Integrated Sensing and Communication"}
]


static func get_mobile_network_step_count() -> int:
	return MOBILE_NETWORK_SEQUENCE.size()


static func get_mobile_network_entry(index: int) -> Dictionary:
	if index < 0 or index >= MOBILE_NETWORK_SEQUENCE.size():
		return {}
	var entry: Dictionary = MOBILE_NETWORK_SEQUENCE[index].duplicate(true)
	entry["index"] = index
	return entry


static func get_mobile_network_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Mobile Network", 0)),
		0,
		MOBILE_NETWORK_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= MOBILE_NETWORK_SEQUENCE.size():
		return {}
	return get_mobile_network_entry(target_index)


const WIFI_SEQUENCE := [
	{"generation": "Wi-Fi 1", "generation_name": "Wireless LAN", "technology": "802.11b"},
	{"generation": "Wi-Fi 2", "generation_name": "Wireless LAN", "technology": "802.11a"},
	{"generation": "Wi-Fi 3", "generation_name": "Wireless LAN", "technology": "802.11g"},
	{"generation": "Wi-Fi 4", "generation_name": "Wireless LAN", "technology": "802.11n"},
	{"generation": "Wi-Fi 5", "generation_name": "Wireless LAN", "technology": "802.11ac"},
	{"generation": "Wi-Fi 6", "generation_name": "High-Efficiency WLAN", "technology": "802.11ax"},
	{"generation": "Wi-Fi 6E", "generation_name": "6 GHz Extension", "technology": "802.11ax (6 GHz)"},
	{"generation": "Wi-Fi 7", "generation_name": "Extremely High Throughput", "technology": "802.11be"},
	{"generation": "Wi-Fi 8", "generation_name": "Ultra High Reliability · Under Development", "technology": "802.11bn"}
]


static func get_wifi_step_count() -> int:
	return WIFI_SEQUENCE.size()


static func get_wifi_entry(index: int) -> Dictionary:
	if index < 0 or index >= WIFI_SEQUENCE.size():
		return {}
	var entry: Dictionary = WIFI_SEQUENCE[index].duplicate(true)
	entry["index"] = index
	return entry


static func get_wifi_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Wi-Fi", 0)),
		0,
		WIFI_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= WIFI_SEQUENCE.size():
		return {}
	return get_wifi_entry(target_index)


static func get_bluetooth_research_target(component_levels: Dictionary) -> Dictionary:
	var current_level := clampi(
		int(component_levels.get("Bluetooth", 0)),
		0,
		BLUETOOTH_SEQUENCE.size() - 1
	)
	var target_index := current_level + 1
	if target_index >= BLUETOOTH_SEQUENCE.size():
		return {}
	return get_bluetooth_entry(target_index)


const BLUETOOTH_SEQUENCE := [
	{"generation": "Bluetooth 1.0b", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 1.0b"},
	{"generation": "Bluetooth 1.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 1.1"},
	{"generation": "Bluetooth 1.2", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 1.2"},
	{"generation": "Bluetooth 2.0 + EDR", "generation_name": "Enhanced Data Rate", "technology": "Bluetooth 2.0 + EDR"},
	{"generation": "Bluetooth 2.1 + EDR", "generation_name": "Secure Simple Pairing", "technology": "Bluetooth 2.1 + EDR"},
	{"generation": "Bluetooth 3.0 + HS", "generation_name": "High Speed", "technology": "Bluetooth 3.0 + HS"},
	{"generation": "Bluetooth 4.0", "generation_name": "Bluetooth Low Energy", "technology": "Bluetooth 4.0"},
	{"generation": "Bluetooth 4.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 4.1"},
	{"generation": "Bluetooth 4.2", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 4.2"},
	{"generation": "Bluetooth 5.0", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.0"},
	{"generation": "Bluetooth 5.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.1"},
	{"generation": "Bluetooth 5.2", "generation_name": "LE Audio foundation", "technology": "Bluetooth 5.2"},
	{"generation": "Bluetooth 5.3", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.3"},
	{"generation": "Bluetooth 5.4", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 5.4"},
	{"generation": "Bluetooth 6.0", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.0"},
	{"generation": "Bluetooth 6.1", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.1"},
	{"generation": "Bluetooth 6.2", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.2"},
	{"generation": "Bluetooth 6.3", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 6.3"},
	{"generation": "Bluetooth 7.0", "generation_name": "Bluetooth Core Specification", "technology": "Bluetooth 7.0"}
]


static func get_bluetooth_step_count() -> int:
	return BLUETOOTH_SEQUENCE.size()


static func get_bluetooth_entry(index: int) -> Dictionary:
	if index < 0 or index >= BLUETOOTH_SEQUENCE.size():
		return {}
	var entry: Dictionary = BLUETOOTH_SEQUENCE[index].duplicate(true)
	entry["index"] = index
	return entry


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

	var ordered_target: Dictionary = {}
	if component == "Mobile Network":
		ordered_target = get_mobile_network_research_target(career.get("research_component_levels", {}))
	elif component == "Wi-Fi":
		ordered_target = get_wifi_research_target(career.get("research_component_levels", {}))
	elif component == "Bluetooth":
		ordered_target = get_bluetooth_research_target(career.get("research_component_levels", {}))
	if component in ["Mobile Network", "Wi-Fi", "Bluetooth"]:
		if ordered_target.is_empty():
			return _failure("All %s technologies in the progression have already been researched." % component)
		var target_index := int(ordered_target.get("index", -1))
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_project: Dictionary = existing_project_value
			if str(existing_project.get("component", "")) != component:
				continue
			if int(existing_project.get("research_target_index", -1)) != target_index:
				continue
			if str(existing_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("The next %s technology already has a project in progress or awaiting validation." % component)

	if component in ["Screen Width", "Screen Height"]:
		for existing_project_value in career.get("research_projects", []):
			if not (existing_project_value is Dictionary):
				continue
			var existing_project: Dictionary = existing_project_value
			if str(existing_project.get("component", "")) == component and str(existing_project.get("status", "")) in [STATUS_ACTIVE, STATUS_AWAITING_VALIDATION]:
				return _failure("%s already has a research project in progress or awaiting validation." % component)

	var project_title := "Research: " + component
	var project_objective := ""
	if not ordered_target.is_empty():
		var target_technology := str(ordered_target.get("technology", ""))
		var target_generation := str(ordered_target.get("generation", ""))
		project_title = "Research: %s - %s" % [component, target_technology]
		if component == "Bluetooth":
			project_title = "Research: %s" % target_technology
			project_objective = "Develop and validate %s for mobile-device connectivity." % target_technology
		elif component == "Mobile Network":
			project_objective = "Develop and validate %s for %s mobile networks." % [target_technology, target_generation]
		elif component == "Wi-Fi":
			project_objective = "Develop and validate IEEE %s for %s wireless networks." % [target_technology, target_generation]
	elif component in ["Screen Width", "Screen Height"]:
		project_objective = "Develop and validate improved %s for mobile phone displays." % component.to_lower()

	var project_id := "RDP-%06d" % int(career.get("next_research_project_id", 1))
	career["next_research_project_id"] = int(career.get("next_research_project_id", 1)) + 1
	var project := {
		"id": project_id,
		"title": project_title,
		"component": component,
		"components": [component],
		"objective": project_objective,
		"research_target_index": int(ordered_target.get("index", -1)),
		"research_target": str(ordered_target.get("technology", "")),
		"research_generation": str(ordered_target.get("generation", "")),
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
			var project_success_chance := clampf(float(project.get("success_chance", RESEARCH_SUCCESS_CHANCE * 100.0)) / 100.0, 0.0, 1.0)
			var successful := success_roll < project_success_chance
			project["success_roll"] = success_roll
			project["success_chance"] = project_success_chance * 100.0
			if successful:
				project["status"] = STATUS_AWAITING_VALIDATION

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

	var component := normalize_component(str(project.get("component", "")))
	var component_levels: Dictionary = career.get("research_component_levels", {})
	var mobile_network_target_index := -1
	var wifi_target_index := -1
	var bluetooth_target_index := -1
	if component == "Mobile Network":
		mobile_network_target_index = int(project.get("research_target_index", -1))
		var expected_target_index := int(component_levels.get(component, 0)) + 1
		if mobile_network_target_index != expected_target_index:
			return _failure("This Mobile Network project is no longer the next technology in the research sequence.")
		var expected_target := get_mobile_network_entry(mobile_network_target_index)
		if expected_target.is_empty() or str(project.get("research_target", "")) != str(expected_target.get("technology", "")):
			return _failure("The Mobile Network project target does not match the current research sequence.")
	elif component == "Wi-Fi":
		wifi_target_index = int(project.get("research_target_index", -1))
		var expected_wifi_index := int(component_levels.get(component, 0)) + 1
		if wifi_target_index != expected_wifi_index:
			return _failure("This Wi-Fi project is no longer the next technology in the research sequence.")
		var expected_wifi_target := get_wifi_entry(wifi_target_index)
		if expected_wifi_target.is_empty() or str(project.get("research_target", "")) != str(expected_wifi_target.get("technology", "")):
			return _failure("The Wi-Fi project target does not match the current research sequence.")
	elif component == "Bluetooth":
		bluetooth_target_index = int(project.get("research_target_index", -1))
		var expected_bluetooth_index := int(component_levels.get(component, 0)) + 1
		if bluetooth_target_index != expected_bluetooth_index:
			return _failure("This Bluetooth project is no longer the next technology in the research sequence.")
		var expected_bluetooth_target := get_bluetooth_entry(bluetooth_target_index)
		if expected_bluetooth_target.is_empty() or str(project.get("research_target", "")) != str(expected_bluetooth_target.get("technology", "")):
			return _failure("The Bluetooth project target does not match the current research sequence.")

	if results.is_empty():
		return _failure("Add at least one validated technology result before approving.")

	var project_components: Array = project.get("components", [])
	var technologies: Dictionary = career.get("research_technologies", {})
	var approved_results: Array = []
	for result_value in results:
		if not (result_value is Dictionary):
			return _failure("Every research result must be a structured technology record.")
		var result: Dictionary = result_value.duplicate(true)
		var result_component := normalize_component(str(result.get("component", "")))
		var metric := str(result.get("metric", "")).strip_edges()
		var value := str(result.get("value", "")).strip_edges()
		if result_component.is_empty() or not project_components.has(result_component):
			return _failure("Each result must refer to the component included in this project.")
		if metric.is_empty() or value.is_empty():
			return _failure("Each approved finding must include a measured attribute and result value.")
		if result_component == "Mobile Network" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Mobile Network technology assigned to this project.")
		if result_component == "Wi-Fi" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Wi-Fi IEEE standard assigned to this project.")
		if result_component == "Bluetooth" and value != str(project.get("research_target", "")):
			return _failure("Validate the exact Bluetooth version assigned to this project.")
		var component_history: Array = technologies.get(result_component, [])
		component_history.append(result)
		technologies[result_component] = component_history
		approved_results.append(result)

	project["status"] = STATUS_APPROVED
	project["approved_at_unix"] = game_time_unix
	project["approved_results"] = approved_results
	if component in ["Phone Thickness", "Border Radius"]:
		component_levels[component] = mini(20, int(component_levels.get(component, 0)) + 1)
	elif component == "Speakers":
		component_levels[component] = mini(11, int(component_levels.get(component, 0)) + 1)
	elif component == "Charge Port":
		# The first port is the baseline; each approval unlocks the next port.
		component_levels[component] = mini(4, int(component_levels.get(component, 0)) + 1)
	elif component == "Home Button":
		# Circle is the baseline; each approval unlocks the next home-button design.
		component_levels[component] = mini(4, int(component_levels.get(component, 0)) + 1)
	elif component == "Screen Technology":
		# TFT LCD is the baseline; each approval unlocks the next listed display technology.
		component_levels[component] = mini(
			ScreenTechnologySystem.TECHNOLOGY_NAMES.size() - 1,
			int(component_levels.get(component, 0)) + 1
		)
	elif component == "Screen Width":
		# Each approval expands the maximum selectable display width by one tier.
		component_levels[component] = mini(SCREEN_WIDTH_RESEARCH_LEVELS, int(component_levels.get(component, 0)) + 1)
	elif component == "Screen Height":
		# Each approval expands the maximum selectable display height by one tier.
		component_levels[component] = mini(SCREEN_HEIGHT_RESEARCH_LEVELS, int(component_levels.get(component, 0)) + 1)
	elif component == "Front Camera":
		# Bezel Camera is the baseline; each approval unlocks the next design in chronological order.
		component_levels[component] = mini(
			FRONT_CAMERA_MODEL_COUNT - 1,
			int(component_levels.get(component, 0)) + 1
		)
	elif component == "RAM":
		# 8 GB is the baseline ceiling; each approval unlocks the next supported capacity tier.
		component_levels[component] = mini(6, int(component_levels.get(component, 0)) + 1)
	elif component == "Internal Storage":
		# 2 GB is the baseline; each approval unlocks the next tier, up to 2 TB.
		component_levels[component] = mini(10, int(component_levels.get(component, 0)) + 1)
	elif component == "RAM Technology":
		# LPDDR2 is the baseline; six approvals unlock the remaining six RAM generations.
		component_levels[component] = mini(6, int(component_levels.get(component, 0)) + 1)
	elif component == "Mobile Network":
		# Each approved project unlocks exactly the next technology in the generation sequence.
		component_levels[component] = mobile_network_target_index
	elif component == "Wi-Fi":
		# Wi-Fi 1 is the starting baseline; each approval unlocks the next Wi-Fi generation.
		component_levels[component] = wifi_target_index
	elif component == "Bluetooth":
		# Bluetooth 1.0b is the baseline; each approval unlocks the next Core Specification version.
		component_levels[component] = bluetooth_target_index
	career["research_component_levels"] = component_levels
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
