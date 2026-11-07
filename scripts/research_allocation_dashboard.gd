extends Control

signal back_requested
signal project_commission_requested(request: Dictionary)
signal project_approve_requested(project_id: String, results: Array)
signal project_reject_requested(project_id: String, review_note: String)

const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")
const DEPARTMENT_COMPONENTS := {
	"Hardware": [
		"Phone Type", "Phone Thickness", "Border Radius", "Screen Technology",
		"Screen Size", "Screen Type", "Power & Volume Buttons", "Speakers",
		"Charging Port", "Side Buttons", "Home Button", "Device Colour",
		"Front Camera", "Back Design", "Rear Camera"
	],
	"Software": [
		"RAM Technology", "RAM", "Internal Storage", "Mobile Internet", "Wi-Fi",
		"Bluetooth", "Battery", "Charging Speed", "Wireless Charging", "Sensors",
		"Front Camera Megapixels", "Rear Camera Megapixels", "Memory Clock",
		"Refresh Rate", "Cooling System"
	],
	"Extras": [
		"Box Package", "Phone Case", "Charger", "Protection Glass",
		"Wireless Earbuds", "Smartwatch", "Power Bank"
	]
}

const TEXT_MAIN := Color("#f0f5f1")
const TEXT_MUTED := Color("#9eafa4")
const ACCENT := Color("#9bd6a7")
const BLUE := Color("#42c7ee")
const PURPLE := Color("#b58aff")
const ORANGE := Color("#ffb45c")
const GREEN := Color("#70d48b")
const PANEL := Color(0.025, 0.055, 0.041, 0.97)
const PANEL_BORDER := Color(0.25, 0.43, 0.31, 0.85)

var company_name := "Your Company"
var company_balance := 0.0
var staff_employees: Array = []
var research_projects: Array = []
var research_technologies: Dictionary = {}
var research_history: Array = []

var page_root: VBoxContainer
var project_list: VBoxContainer
var workspace: PanelContainer
var workspace_content: VBoxContainer
var staff_count_label: Label
var available_staff_label: Label
var active_projects_label: Label
var review_projects_label: Label
var balance_label: Label
var selected_project_id := ""
var selected_components: Array[String] = []
var selected_staff_ids: Array[String] = []
var staff_checkboxes: Dictionary = {}
var component_option: OptionButton
var component_summary_label: Label
var project_title_input: LineEdit
var project_objective_input: TextEdit
var project_budget_input: LineEdit
var project_work_hours_input: LineEdit
var review_component_option: OptionButton
var review_metric_input: LineEdit
var review_value_input: LineEdit
var review_unit_input: LineEdit
var review_notes_input: TextEdit
var review_rejection_input: LineEdit
var pending_results: Array[Dictionary] = []
var feedback_label: Label
var project_progress_bar: ProgressBar
var project_progress_label: Label
var selected_project_status := ""


func configure(data: Dictionary, _existing_pop_alert: Node = null) -> void:
	company_name = str(data.get("company_name", "Your Company"))
	company_balance = maxf(0.0, float(data.get("balance", 0.0)))
	staff_employees = data.get("staff_employees", []).duplicate(true)
	research_projects = data.get("research_projects", []).duplicate(true)
	research_technologies = data.get("research_technologies", {}).duplicate(true)
	research_history = data.get("research_history", []).duplicate(true)
	if is_node_ready():
		_refresh_dashboard()


func _ready() -> void:
	_build_dashboard()
	_refresh_dashboard()


func _build_dashboard() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.y < 560.0 or viewport_size.x < 900.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "ResearchManagementBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#050a08")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.025, 0.085, 0.055, 0.34)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	var frame := MarginContainer.new()
	frame.name = "ResearchManagementFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 12 if compact else 28)
	frame.add_theme_constant_override("margin_right", 12 if compact else 28)
	frame.add_theme_constant_override("margin_top", 8 if compact else 18)
	frame.add_theme_constant_override("margin_bottom", 8 if compact else 16)
	add_child(frame)

	page_root = VBoxContainer.new()
	page_root.name = "ResearchManagementPage"
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", 7 if compact else 12)
	frame.add_child(page_root)

	_build_header(compact)
	_build_workforce_summary(compact)

	var body := HBoxContainer.new()
	body.name = "ResearchManagementBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10 if compact else 16)
	page_root.add_child(body)

	_build_project_column(body, compact)
	_build_workspace(body)

	feedback_label = _label("", 10, ACCENT)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_root.add_child(feedback_label)


func _build_header(compact: bool) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	page_root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	header.add_child(title_stack)
	title_stack.add_child(_label("COMPANY OPERATIONS  /  INNOVATION", 8 if compact else 10, ACCENT))
	title_stack.add_child(_label("Research & Development", 18 if compact else 27, TEXT_MAIN))

	balance_label = _label(_format_currency(company_balance), 12 if compact else 15, GREEN)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(balance_label)

	var back := _button("BACK  ‹", false, TEXT_MAIN, compact)
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)


func _build_workforce_summary(compact: bool) -> void:
	var panel := _panel()
	panel.name = "ResearchWorkforceSummary"
	page_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8 if compact else 18)
	panel.add_child(_padded(row, compact))

	staff_count_label = _metric(row, "RESEARCH STAFF", "0", compact)
	available_staff_label = _metric(row, "AVAILABLE", "0", compact)
	active_projects_label = _metric(row, "ACTIVE PROJECTS", "0", compact)
	review_projects_label = _metric(row, "AWAITING REVIEW", "0", compact)


func _build_project_column(parent: HBoxContainer, compact: bool) -> void:
	var panel := _panel()
	panel.name = "ResearchProjectsPanel"
	panel.custom_minimum_size.x = 250 if compact else 310
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.82
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(_padded(content, compact))

	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label("PROJECT PORTFOLIO", 10 if compact else 12, TEXT_MAIN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var new_button := _button("+ NEW", true, GREEN, compact)
	new_button.pressed.connect(_show_new_project_form)
	heading.add_child(new_button)

	var scroll := ScrollContainer.new()
	scroll.name = "ResearchProjectListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	project_list = VBoxContainer.new()
	project_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_list.add_theme_constant_override("separation", 5)
	scroll.add_child(project_list)


func _build_workspace(parent: HBoxContainer) -> void:
	workspace = _panel()
	workspace.name = "ResearchWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_stretch_ratio = 1.35
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(workspace)
	var scroll := ScrollContainer.new()
	scroll.name = "ResearchWorkspaceScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workspace.add_child(scroll)
	workspace_content = VBoxContainer.new()
	workspace_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_padded(workspace_content, true))


func _refresh_dashboard() -> void:
	if not is_instance_valid(workspace_content) or not is_instance_valid(project_list):
		return
	balance_label.text = _format_currency(company_balance)
	var workforce := ResearchManagerScript.get_workforce_summary({
		"staff_employees": staff_employees,
		"research_projects": research_projects
	})
	staff_count_label.text = str(workforce.get("staff_count", 0))
	available_staff_label.text = str(workforce.get("available_staff_count", 0))
	active_projects_label.text = str(_count_projects_with_status("active"))
	review_projects_label.text = str(_count_projects_with_status("awaiting_validation"))
	_rebuild_project_list()
	if selected_project_id.is_empty():
		_show_new_project_form()
	else:
		var project := _find_project(selected_project_id)
		if project.is_empty():
			selected_project_id = ""
			_show_new_project_form()
		else:
			_show_project_details(project)


func _rebuild_project_list() -> void:
	for child in project_list.get_children():
		child.queue_free()
	var ordered_statuses := ["active", "awaiting_validation", "rejected", "approved"]
	var titles := {
		"active": "IN DEVELOPMENT",
		"awaiting_validation": "READY FOR REVIEW",
		"rejected": "NOT APPROVED",
		"approved": "APPROVED DISCOVERIES"
	}
	for status in ordered_statuses:
		var section_projects: Array = []
		for project_value in research_projects:
			if project_value is Dictionary and str(project_value.get("status", "")) == status:
				section_projects.append(project_value)
		if section_projects.is_empty():
			continue
		var section_label := _label(titles[status], 8, _status_color(status))
		project_list.add_child(section_label)
		for project in section_projects:
			var button := Button.new()
			button.text = "%s\n%s  ·  %s" % [
				str(project.get("title", "Research project")),
				str(project.get("id", "")),
				_status_text(status)
			]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = 48
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			button.add_theme_font_size_override("font_size", 9)
			button.add_theme_color_override("font_color", TEXT_MAIN)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			var selected := str(project.get("id", "")) == selected_project_id
			button.add_theme_stylebox_override("normal", _button_style(selected, _status_color(status)))
			button.add_theme_stylebox_override("hover", _button_style(true, _status_color(status)))
			button.pressed.connect(_select_project.bind(str(project.get("id", ""))))
			project_list.add_child(button)
	if project_list.get_child_count() == 0:
		var empty := _label("No research projects yet.\nCommission your company's first R&D project.", 10, TEXT_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.y = 54
		project_list.add_child(empty)


func _select_project(project_id: String) -> void:
	selected_project_id = project_id
	pending_results.clear()
	_refresh_dashboard()


func _show_new_project_form() -> void:
	selected_project_id = ""
	selected_components.clear()
	selected_staff_ids.clear()
	pending_results.clear()
	_clear_workspace()
	var compact := get_viewport_rect().size.y < 560.0
	workspace_content.add_child(_label("COMMISSION RESEARCH", 10 if compact else 12, ACCENT))
	workspace_content.add_child(_label("Create a funded R&D project", 17 if compact else 22, TEXT_MAIN))
	workspace_content.add_child(_label("Define the technical objective, approve a budget and assign available Research employees.", 9 if compact else 11, TEXT_MUTED))

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_content.add_child(form)

	project_title_input = _line_edit("e.g. Improve IPS display contrast", false)
	form.add_child(_field_block(form, "PROJECT NAME", project_title_input))

	component_option = OptionButton.new()
	component_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_option.add_item("Choose a component")
	for department in DEPARTMENT_COMPONENTS:
		for component in DEPARTMENT_COMPONENTS[department]:
			component_option.add_item("%s  /  %s" % [department, component])
	_apply_option_style(component_option)
	var component_row := HBoxContainer.new()
	component_row.add_theme_constant_override("separation", 6)
	component_row.add_child(component_option)
	var add_component_button := _button("ADD", true, BLUE, compact)
	add_component_button.pressed.connect(_add_selected_component)
	component_row.add_child(add_component_button)
	form.add_child(_field_block(form, "TECHNOLOGY COMPONENTS", component_row))

	component_summary_label = _label("No components selected.", 9, TEXT_MUTED)
	component_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(component_summary_label)

	project_objective_input = TextEdit.new()
	project_objective_input.placeholder_text = "Describe what the research should improve or discover..."
	project_objective_input.custom_minimum_size.y = 54
	project_objective_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_objective_input.add_theme_font_size_override("font_size", 10)
	form.add_child(_field_block(form, "RESEARCH OBJECTIVE", project_objective_input))

	var finance_row := HBoxContainer.new()
	finance_row.add_theme_constant_override("separation", 8)
	project_budget_input = _line_edit("Approved project budget", true)
	project_budget_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_work_hours_input = _line_edit("Estimated engineering hours", true)
	project_work_hours_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finance_row.add_child(_field_block(null, "PROJECT BUDGET", project_budget_input))
	finance_row.add_child(_field_block(null, "ESTIMATED WORK (HOURS)", project_work_hours_input))
	form.add_child(finance_row)

	form.add_child(_label("ASSIGN AVAILABLE RESEARCH EMPLOYEES", 9, ACCENT))
	_add_staff_assignment_controls(form, compact)

	var commission := _button("APPROVE BUDGET & COMMISSION PROJECT", true, GREEN, compact)
	commission.custom_minimum_size.y = 38
	commission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commission.pressed.connect(_on_commission_pressed)
	form.add_child(commission)


func _add_staff_assignment_controls(parent: VBoxContainer, compact: bool) -> void:
	selected_staff_ids.clear()
	staff_checkboxes.clear()
	var occupied := _active_project_staff_ids()
	var found_staff := false
	for employee_value in staff_employees:
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("department", "")) != "Research":
			continue
		found_staff = true
		var employee_id := str(employee.get("id", ""))
		var name := str(employee.get("full_name", employee.get("name", "Research employee")))
		var position := str(employee.get("position", "Research staff"))
		var efficiency := clampi(int(employee.get("efficiency", 0)), 0, 100)
		var checkbox := CheckBox.new()
		checkbox.text = "%s  ·  %s  ·  %d%%" % [name, position, efficiency]
		checkbox.disabled = employee_id.is_empty() or occupied.has(employee_id)
		checkbox.add_theme_font_size_override("font_size", 9 if compact else 10)
		checkbox.add_theme_color_override("font_color", TEXT_MAIN)
		checkbox.add_theme_color_override("font_disabled_color", TEXT_MUTED)
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.toggled.connect(_on_staff_assignment_toggled.bind(employee_id))
		parent.add_child(checkbox)
		staff_checkboxes[employee_id] = checkbox
	if not found_staff:
		parent.add_child(_label("No employees are currently assigned to the Research department. Assign researchers through Staff Management first.", 9, TEXT_MUTED))


func _on_staff_assignment_toggled(checked: bool, employee_id: String) -> void:
	if checked:
		if not selected_staff_ids.has(employee_id):
			selected_staff_ids.append(employee_id)
	else:
		selected_staff_ids.erase(employee_id)


func _add_selected_component() -> void:
	if not is_instance_valid(component_option) or component_option.selected <= 0:
		return
	var selected_text := component_option.get_item_text(component_option.selected)
	var component := selected_text.get_slice("  /  ", 1)
	if component.is_empty():
		return
	if selected_components.has(component):
		_set_feedback("That component is already included in this project.", false)
		return
	selected_components.append(component)
	_update_component_summary()


func _update_component_summary() -> void:
	if not is_instance_valid(component_summary_label):
		return
	if selected_components.is_empty():
		component_summary_label.text = "No components selected."
		component_summary_label.add_theme_color_override("font_color", TEXT_MUTED)
	else:
		component_summary_label.text = "SELECTED:  " + _join_values(selected_components, "   ·   ")
		component_summary_label.add_theme_color_override("font_color", ACCENT)


func _on_commission_pressed() -> void:
	var budget_text := project_budget_input.text.strip_edges().replace(",", "")
	var hours_text := project_work_hours_input.text.strip_edges().replace(",", "")
	if selected_components.is_empty():
		_set_feedback("Select at least one technology component.", false)
		return
	if not budget_text.is_valid_float() or float(budget_text) <= 0.0:
		_set_feedback("Enter a valid project budget greater than zero.", false)
		return
	if not hours_text.is_valid_float() or float(hours_text) <= 0.0:
		_set_feedback("Enter a valid engineering-work estimate greater than zero.", false)
		return
	if selected_staff_ids.is_empty():
		_set_feedback("Assign at least one available Research employee.", false)
		return
	var request := {
		"title": project_title_input.text.strip_edges(),
		"components": selected_components.duplicate(),
		"objective": project_objective_input.text.strip_edges(),
		"budget": float(budget_text),
		"required_work_hours": float(hours_text),
		"staff_ids": selected_staff_ids.duplicate(),
		"project_type": "technology_improvement"
	}
	project_commission_requested.emit(request)


func _show_project_details(project: Dictionary) -> void:
	_clear_workspace()
	var status := str(project.get("status", "active"))
	var compact := get_viewport_rect().size.y < 560.0
	workspace_content.add_child(_label("RESEARCH PROJECT  /  %s" % str(project.get("id", "")), 9, ACCENT))
	workspace_content.add_child(_label(str(project.get("title", "Research project")), 17 if compact else 22, TEXT_MAIN))
	workspace_content.add_child(_label(_status_text(status).to_upper(), 9, _status_color(status)))

	var body_text := "Components: " + _join_values(project.get("components", []), ", ")
	workspace_content.add_child(_label(body_text, 9, TEXT_MUTED))
	var objective := str(project.get("objective", ""))
	if not objective.is_empty():
		var objective_label := _label(objective, 9, TEXT_MUTED)
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		workspace_content.add_child(objective_label)

	var required_hours := maxf(0.0, float(project.get("work_required_hours", 0.0)))
	var completed_hours := maxf(0.0, float(project.get("work_completed_hours", 0.0)))
	var progress := clampf(completed_hours / required_hours, 0.0, 1.0) if required_hours > 0.0 else 0.0
	var progress_row := HBoxContainer.new()
	selected_project_status = status
	var progress_label := _label("ENGINEERING WORK", 8, TEXT_MUTED)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress_label)
	project_progress_label = _label("%d%%" % roundi(progress * 100.0), 10, ACCENT)
	progress_row.add_child(project_progress_label)
	workspace_content.add_child(progress_row)
	project_progress_bar = ProgressBar.new()
	project_progress_bar.min_value = 0.0
	project_progress_bar.max_value = 100.0
	project_progress_bar.value = progress * 100.0
	project_progress_bar.show_percentage = false
	project_progress_bar.custom_minimum_size.y = 8
	workspace_content.add_child(project_progress_bar)
	workspace_content.add_child(_label("%.1f / %.1f engineering hours completed" % [completed_hours, required_hours], 8, TEXT_MUTED))

	var assigned_names: Array[String] = []
	for staff_id_value in project.get("staff_ids", []):
		var employee := _find_employee(str(staff_id_value))
		if not employee.is_empty():
			assigned_names.append(str(employee.get("full_name", employee.get("name", staff_id_value))))
	workspace_content.add_child(_label("Assigned team: " + (_join_values(assigned_names, ", ") if not assigned_names.is_empty() else "No current team members"), 9, TEXT_MUTED))
	workspace_content.add_child(_label("Approved budget: %s" % _format_currency(float(project.get("budget", 0.0))), 9, TEXT_MUTED))

	var pause_reason := str(project.get("pause_reason", ""))
	if not pause_reason.is_empty():
		var paused_label := _label("PAUSED  ·  " + pause_reason, 9, ORANGE)
		paused_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		workspace_content.add_child(paused_label)

	if status == "awaiting_validation":
		_build_validation_panel(project, compact)
	elif status == "approved":
		_build_approved_results_panel(project)
	elif status == "rejected":
		workspace_content.add_child(_label("Review note: " + str(project.get("review_note", "No review note recorded.")), 9, TEXT_MUTED))


func _build_validation_panel(project: Dictionary, compact: bool) -> void:
	var divider := HSeparator.new()
	workspace_content.add_child(divider)
	workspace_content.add_child(_label("TECHNICAL VALIDATION", 10, ACCENT))
	workspace_content.add_child(_label("Record measured findings from the completed project before approving its technology outcome.", 9, TEXT_MUTED))

	review_component_option = OptionButton.new()
	review_component_option.add_item("Select researched component")
	for component in project.get("components", []):
		review_component_option.add_item(str(component))
	_apply_option_style(review_component_option)
	workspace_content.add_child(_field_block(null, "COMPONENT", review_component_option))

	review_metric_input = _line_edit("e.g. Display brightness", false)
	workspace_content.add_child(_field_block(null, "MEASURED ATTRIBUTE", review_metric_input))
	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 6)
	review_value_input = _line_edit("Measured value", false)
	review_value_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_unit_input = _line_edit("Unit (optional)", false)
	review_unit_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_row.add_child(review_value_input)
	result_row.add_child(review_unit_input)
	workspace_content.add_child(_field_block(null, "RESULT", result_row))

	review_notes_input = TextEdit.new()
	review_notes_input.placeholder_text = "Test conditions, comparison with existing technology, reliability notes..."
	review_notes_input.custom_minimum_size.y = 42
	review_notes_input.add_theme_font_size_override("font_size", 9)
	workspace_content.add_child(_field_block(null, "TEST NOTES", review_notes_input))

	var add_result := _button("ADD VALIDATED FINDING", false, BLUE, compact)
	add_result.pressed.connect(_add_validation_result)
	workspace_content.add_child(add_result)

	var results_summary := _label(_format_pending_results(), 9, TEXT_MUTED)
	results_summary.name = "PendingResearchResultsSummary"
	results_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace_content.add_child(results_summary)

	review_rejection_input = _line_edit("Reason for rejection (if not approved)", false)
	workspace_content.add_child(review_rejection_input)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	workspace_content.add_child(actions)
	var approve := _button("APPROVE RESULTS", true, GREEN, compact)
	approve.disabled = pending_results.is_empty()
	approve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	approve.pressed.connect(_on_approve_project_pressed.bind(str(project.get("id", ""))))
	actions.add_child(approve)
	var reject := _button("REJECT FINDINGS", false, ORANGE, compact)
	reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reject.pressed.connect(_on_reject_project_pressed.bind(str(project.get("id", ""))))
	actions.add_child(reject)


func _add_validation_result() -> void:
	if not is_instance_valid(review_component_option) or review_component_option.selected <= 0:
		_set_feedback("Choose a component included in this project.", false)
		return
	var metric := review_metric_input.text.strip_edges()
	var value := review_value_input.text.strip_edges()
	if metric.is_empty() or value.is_empty():
		_set_feedback("Enter the measured attribute and result value.", false)
		return
	var component := review_component_option.get_item_text(review_component_option.selected)
	var result := {
		"component": component,
		"metric": metric,
		"value": value,
		"unit": review_unit_input.text.strip_edges(),
		"notes": review_notes_input.text.strip_edges(),
		"recorded_at_unix": Time.get_unix_time_from_system()
	}
	pending_results.append(result)
	_show_project_details(_find_project(selected_project_id))
	_set_feedback("Validated finding added. Add any other measurements before approving.", true)


func _format_pending_results() -> String:
	if pending_results.is_empty():
		return "No validated findings recorded yet."
	var lines: Array[String] = ["FINDINGS TO APPROVE"]
	for result in pending_results:
		lines.append("%s  ·  %s: %s %s" % [
			str(result.get("component", "")),
			str(result.get("metric", "")),
			str(result.get("value", "")),
			str(result.get("unit", ""))
		])
	return _join_values(lines, "\n")


func _on_approve_project_pressed(project_id: String) -> void:
	project_approve_requested.emit(project_id, pending_results.duplicate(true))


func _on_reject_project_pressed(project_id: String) -> void:
	var note := review_rejection_input.text.strip_edges() if is_instance_valid(review_rejection_input) else ""
	project_reject_requested.emit(project_id, note)


func _build_approved_results_panel(project: Dictionary) -> void:
	workspace_content.add_child(HSeparator.new())
	workspace_content.add_child(_label("APPROVED TECHNOLOGY FINDINGS", 10, GREEN))
	var results: Array = project.get("approved_results", [])
	if results.is_empty():
		workspace_content.add_child(_label("No structured findings were stored for this project.", 9, TEXT_MUTED))
		return
	for result in results:
		if not (result is Dictionary):
			continue
		var line := "%s  ·  %s: %s %s" % [
			str(result.get("component", "")),
			str(result.get("metric", "")),
			str(result.get("value", "")),
			str(result.get("unit", ""))
		]
		var result_label := _label(line, 9, TEXT_MAIN)
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		workspace_content.add_child(result_label)
		var notes := str(result.get("notes", ""))
		if not notes.is_empty():
			var notes_label := _label(notes, 8, TEXT_MUTED)
			notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			workspace_content.add_child(notes_label)


func _find_project(project_id: String) -> Dictionary:
	for project_value in research_projects:
		if project_value is Dictionary and str(project_value.get("id", "")) == project_id:
			return project_value
	return {}


func _find_employee(employee_id: String) -> Dictionary:
	for employee_value in staff_employees:
		if employee_value is Dictionary and str(employee_value.get("id", "")) == employee_id:
			return employee_value
	return {}


func _active_project_staff_ids() -> Array[String]:
	var occupied: Array[String] = []
	for project_value in research_projects:
		if not (project_value is Dictionary) or str(project_value.get("status", "")) != "active":
			continue
		for staff_id_value in project_value.get("staff_ids", []):
			var staff_id := str(staff_id_value)
			if not staff_id.is_empty() and not occupied.has(staff_id):
				occupied.append(staff_id)
	return occupied


func _count_projects_with_status(status: String) -> int:
	var count := 0
	for project_value in research_projects:
		if project_value is Dictionary and str(project_value.get("status", "")) == status:
			count += 1
	return count


func _clear_workspace() -> void:
	project_progress_bar = null
	project_progress_label = null
	selected_project_status = ""
	for child in workspace_content.get_children():
		child.queue_free()


func update_live_progress(projects: Array, balance: float, employees: Array) -> void:
	research_projects = projects.duplicate(true)
	company_balance = maxf(0.0, balance)
	staff_employees = employees.duplicate(true)
	if not is_node_ready() or not is_instance_valid(project_list):
		return
	balance_label.text = _format_currency(company_balance)
	var workforce := ResearchManagerScript.get_workforce_summary({
		"staff_employees": staff_employees,
		"research_projects": research_projects
	})
	staff_count_label.text = str(workforce.get("staff_count", 0))
	available_staff_label.text = str(workforce.get("available_staff_count", 0))
	active_projects_label.text = str(_count_projects_with_status("active"))
	review_projects_label.text = str(_count_projects_with_status("awaiting_validation"))
	_rebuild_project_list()
	if selected_project_id.is_empty():
		return
	var selected_project := _find_project(selected_project_id)
	if selected_project.is_empty():
		return
	var next_status := str(selected_project.get("status", "active"))
	if next_status != selected_project_status:
		_show_project_details(selected_project)
		return
	var required_hours := maxf(0.0, float(selected_project.get("work_required_hours", 0.0)))
	var completed_hours := maxf(0.0, float(selected_project.get("work_completed_hours", 0.0)))
	var progress := clampf(completed_hours / required_hours, 0.0, 1.0) if required_hours > 0.0 else 0.0
	if is_instance_valid(project_progress_bar):
		project_progress_bar.value = progress * 100.0
	if is_instance_valid(project_progress_label):
		project_progress_label.text = "%d%%" % roundi(progress * 100.0)


func _set_feedback(message: String, success: bool) -> void:
	if is_instance_valid(feedback_label):
		feedback_label.text = message
		feedback_label.add_theme_color_override("font_color", GREEN if success else ORANGE)


func _metric(parent: HBoxContainer, caption: String, value: String, compact: bool) -> Label:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 1)
	parent.add_child(group)
	group.add_child(_label(caption, 7 if compact else 8, TEXT_MUTED))
	var value_label := _label(value, 15 if compact else 19, TEXT_MAIN)
	group.add_child(value_label)
	return value_label


func _field_block(_parent: Variant, caption: String, field: Control) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(_label(caption, 7, TEXT_MUTED))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_child(field)
	return block


func _line_edit(placeholder: String, numeric: bool) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.clear_button_enabled = true
	input.custom_minimum_size.y = 32
	input.add_theme_font_size_override("font_size", 10)
	if numeric:
		input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_apply_line_edit_style(input)
	return input


func _apply_line_edit_style(input: LineEdit) -> void:
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#101b15")
		style.border_color = Color("#41624a") if state == "normal" else ACCENT
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		input.add_theme_stylebox_override(state, style)
	input.add_theme_color_override("font_color", TEXT_MAIN)
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)


func _apply_option_style(option: OptionButton) -> void:
	option.custom_minimum_size.y = 32
	option.add_theme_font_size_override("font_size", 9)
	option.add_theme_color_override("font_color", TEXT_MAIN)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101b15")
	style.border_color = Color("#41624a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 7
	style.content_margin_right = 7
	option.add_theme_stylebox_override("normal", style)
	option.add_theme_stylebox_override("hover", style)
	option.add_theme_stylebox_override("pressed", style)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _padded(content: Control, compact: bool) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6 if compact else 10)
	margin.add_theme_constant_override("margin_right", 6 if compact else 10)
	margin.add_theme_constant_override("margin_top", 5 if compact else 8)
	margin.add_theme_constant_override("margin_bottom", 5 if compact else 8)
	margin.add_child(content)
	return margin


func _button(value: String, primary: bool, accent: Color, compact: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(76 if compact else 100, 30 if compact else 36)
	button.add_theme_font_size_override("font_size", 8 if compact else 10)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(primary, accent))
	button.add_theme_stylebox_override("hover", _button_style(true, accent))
	button.add_theme_stylebox_override("pressed", _button_style(true, accent))
	return button


func _button_style(primary: bool, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.94) if primary else Color("#101b15")
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88 if primary else 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _status_text(status: String) -> String:
	match status:
		"active": return "In development"
		"awaiting_validation": return "Awaiting validation"
		"approved": return "Approved"
		"rejected": return "Not approved"
		_: return status.capitalize()


func _status_color(status: String) -> Color:
	match status:
		"active": return BLUE
		"awaiting_validation": return ORANGE
		"approved": return GREEN
		"rejected": return Color("#df7777")
		_: return TEXT_MUTED


func _join_values(values: Array, separator: String) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return separator.join(PackedStringArray(parts))


func _format_currency(amount: float) -> String:
	var digits := str(roundi(amount))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted
