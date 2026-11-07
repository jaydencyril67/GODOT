extends Control

signal back_requested
signal project_commission_requested(request: Dictionary)
signal project_approve_requested(project_id: String, results: Array)
signal project_reject_requested(project_id: String, review_note: String)

const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")

const TEXT_MAIN := Color("#f0f5f1")
const TEXT_MUTED := Color("#9eafa4")
const ACCENT := Color("#9bd6a7")
const GREEN := Color("#70d48b")
const BLUE := Color("#42c7ee")
const ORANGE := Color("#ffb45c")

const COMPONENT_LABELS := ["Screen Tech", "Phone Thickness", "Border Radius"]
const COMPONENT_VALUES := ["Screen Technology", "Phone Thickness", "Border Radius"]

var company_balance := 0.0
var staff_employees: Array = []
var research_projects: Array = []
var research_technologies: Dictionary = {}
var research_history: Array = []

var page_root: VBoxContainer
var body: CenterContainer
var body_content: VBoxContainer
var component_option: OptionButton
var investment_input: LineEdit
var estimate_label: Label
var start_button: Button
var assigned_staff_ids: Array[String] = []
var active_progress_bar: ProgressBar
var active_progress_label: Label
var active_remaining_label: Label
var active_project_id := ""
var creation_mode := false


func configure(data: Dictionary, _existing_pop_alert: Node = null) -> void:
	company_balance = maxf(0.0, float(data.get("balance", 0.0)))
	staff_employees = data.get("staff_employees", []).duplicate(true)
	research_projects = data.get("research_projects", []).duplicate(true)
	research_technologies = data.get("research_technologies", {}).duplicate(true)
	research_history = data.get("research_history", []).duplicate(true)
	if is_node_ready():
		_render_scene()


func _ready() -> void:
	_build_shell()
	_render_scene()


func _build_shell() -> void:
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
	frame.add_theme_constant_override("margin_left", 22)
	frame.add_theme_constant_override("margin_right", 22)
	frame.add_theme_constant_override("margin_top", 16)
	frame.add_theme_constant_override("margin_bottom", 16)
	add_child(frame)

	page_root = VBoxContainer.new()
	page_root.name = "ResearchManagementPage"
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", 8)
	frame.add_child(page_root)

	var top_bar := HBoxContainer.new()
	top_bar.name = "ResearchTopBar"
	page_root.add_child(top_bar)

	var back := _button("‹  BACK", false, TEXT_MAIN)
	back.custom_minimum_size = Vector2(112, 42)
	back.pressed.connect(func(): back_requested.emit())
	top_bar.add_child(back)

	var section_title := _label("RESEARCH", 13, ACCENT)
	section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	section_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(section_title)

	body = CenterContainer.new()
	body.name = "ResearchManagementBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_child(body)


func _render_scene() -> void:
	if not is_instance_valid(body):
		return
	_clear_body()
	active_project_id = ""
	active_progress_bar = null
	active_progress_label = null
	active_remaining_label = null

	var active_project := _get_active_project()
	if not active_project.is_empty():
		_build_active_research(active_project)
	elif creation_mode:
		_build_creation_scene()
	else:
		_build_empty_scene()


func _build_empty_scene() -> void:
	body_content = _new_center_content()
	body.add_child(body_content)

	body_content.add_child(_label("NO ACTIVE RESEARCHES", 27, TEXT_MAIN))
	var create := _button("CREATE RESEARCH", true, GREEN)
	create.name = "CreateResearchButton"
	create.custom_minimum_size = Vector2(260, 58)
	create.pressed.connect(_open_creation_scene)
	body_content.add_child(create)


func _open_creation_scene() -> void:
	creation_mode = true
	assigned_staff_ids.clear()
	_render_scene()


func _build_creation_scene() -> void:
	body_content = _new_center_content()
	body_content.add_child(_label("CREATE RESEARCH", 26, TEXT_MAIN))
	var subtitle := _label("Choose one component and build your research team.", 14, TEXT_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_content.add_child(subtitle)

	var component_title := _label("COMPONENT TO RESEARCH", 12, ACCENT)
	body_content.add_child(component_title)
	component_option = OptionButton.new()
	component_option.name = "ResearchComponentOption"
	component_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_option.custom_minimum_size.y = 48
	for index in range(COMPONENT_LABELS.size()):
		component_option.add_item(COMPONENT_LABELS[index], index)
	component_option.select(0)
	component_option.item_selected.connect(_on_research_setup_changed)
	_style_option(component_option)
	body_content.add_child(component_option)

	var investment_title := _label("CEO INVESTMENT", 12, ACCENT)
	body_content.add_child(investment_title)
	investment_input = LineEdit.new()
	investment_input.name = "ResearchInvestmentInput"
	investment_input.placeholder_text = "Enter amount to invest"
	investment_input.custom_minimum_size.y = 48
	investment_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	investment_input.text_changed.connect(_on_research_setup_changed)
	_style_input(investment_input)
	body_content.add_child(investment_input)

	var balance_line := _label("AVAILABLE FUNDS  " + _format_currency(company_balance), 12, TEXT_MUTED)
	body_content.add_child(balance_line)

	body_content.add_child(_label("ASSIGN RESEARCHERS", 12, ACCENT))
	var staff_list := VBoxContainer.new()
	staff_list.add_theme_constant_override("separation", 5)
	body_content.add_child(staff_list)
	_build_staff_choices(staff_list)

	estimate_label = _label("Select researchers to calculate the estimated time and success chance.", 13, TEXT_MUTED)
	estimate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_content.add_child(estimate_label)

	start_button = _button("START RESEARCH", true, GREEN)
	start_button.name = "StartResearchButton"
	start_button.custom_minimum_size.y = 54
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.disabled = true
	start_button.pressed.connect(_on_start_research_pressed)
	body_content.add_child(start_button)

	var cancel := _button("CANCEL", false, TEXT_MUTED)
	cancel.pressed.connect(_close_creation_scene)
	body_content.add_child(cancel)
	_update_research_estimate()


func _build_staff_choices(parent: VBoxContainer) -> void:
	var occupied_ids := _active_project_staff_ids()
	var found_staff := false
	for employee_value in staff_employees:
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("department", "")) != "Research":
			continue
		found_staff = true
		var employee_id := str(employee.get("id", ""))
		var employee_name := str(employee.get("full_name", employee.get("name", "Research employee")))
		var efficiency := clampi(int(employee.get("efficiency", 0)), 0, 100)
		var checkbox := CheckBox.new()
		checkbox.text = "%s   ·   %d%% efficiency" % [employee_name, efficiency]
		checkbox.disabled = employee_id.is_empty() or occupied_ids.has(employee_id)
		checkbox.add_theme_font_size_override("font_size", 16)
		checkbox.add_theme_color_override("font_color", TEXT_MAIN)
		checkbox.add_theme_color_override("font_disabled_color", TEXT_MUTED)
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.button_pressed = assigned_staff_ids.has(employee_id)
		checkbox.toggled.connect(_on_staff_toggled.bind(employee_id))
		parent.add_child(checkbox)
	if not found_staff:
		var empty_staff := _label("No Research employees are available. Assign employees to the Research department first.", 13, ORANGE)
		empty_staff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(empty_staff)


func _on_staff_toggled(checked: bool, employee_id: String) -> void:
	if checked:
		if not assigned_staff_ids.has(employee_id):
			assigned_staff_ids.append(employee_id)
	else:
		assigned_staff_ids.erase(employee_id)
	_update_research_estimate()


func _on_research_setup_changed(_value = null) -> void:
	_update_research_estimate()


func _update_research_estimate() -> void:
	if not is_instance_valid(estimate_label) or not is_instance_valid(start_button):
		return
	var component := _selected_component()
	var estimate := ResearchManagerScript.estimate_research(component, assigned_staff_ids, staff_employees)
	var investment_text := investment_input.text.strip_edges().replace(",", "") if is_instance_valid(investment_input) else ""
	var valid_investment := investment_text.is_valid_float() and float(investment_text) > 0.0 and float(investment_text) <= company_balance
	var estimate_valid := bool(estimate.get("ok", false))
	if estimate_valid:
		estimate_label.text = "ESTIMATED DURATION  %d IN-GAME DAYS\nESTIMATED SUCCESS CHANCE  %.0f%%" % [
			int(estimate.get("expected_duration_days", 0)),
			float(estimate.get("success_chance", 0.0))
		]
		estimate_label.add_theme_color_override("font_color", ACCENT)
	else:
		estimate_label.text = str(estimate.get("error", "Assign researchers to see the estimate."))
		estimate_label.add_theme_color_override("font_color", TEXT_MUTED)
	start_button.disabled = not estimate_valid or not valid_investment


func _on_start_research_pressed() -> void:
	var investment_text := investment_input.text.strip_edges().replace(",", "")
	if assigned_staff_ids.is_empty():
		_set_estimate_error("Assign at least one Research employee.")
		return
	if not investment_text.is_valid_float() or float(investment_text) <= 0.0:
		_set_estimate_error("Enter a valid research investment.")
		return
	if float(investment_text) > company_balance:
		_set_estimate_error("The investment is higher than the company's available funds.")
		return
	var request := {
		"component": _selected_component(),
		"budget": float(investment_text),
		"staff_ids": assigned_staff_ids.duplicate()
	}
	project_commission_requested.emit(request)


func _set_estimate_error(message: String) -> void:
	if is_instance_valid(estimate_label):
		estimate_label.text = message
		estimate_label.add_theme_color_override("font_color", ORANGE)


func _selected_component() -> String:
	if not is_instance_valid(component_option):
		return COMPONENT_VALUES[0]
	var index := clampi(component_option.selected, 0, COMPONENT_VALUES.size() - 1)
	return COMPONENT_VALUES[index]


func _close_creation_scene() -> void:
	creation_mode = false
	assigned_staff_ids.clear()
	_render_scene()


func _build_active_research(project: Dictionary) -> void:
	creation_mode = false
	active_project_id = str(project.get("id", ""))
	body_content = _new_center_content()
	body.add_child(body_content)

	var active_heading := _label("ACTIVE RESEARCH", 13, ACCENT)
	active_heading.name = "ActiveResearchHeading"
	body_content.add_child(active_heading)
	body_content.add_child(_label(str(project.get("component", project.get("title", "Research project"))), 27, TEXT_MAIN))

	var completed_hours := maxf(0.0, float(project.get("work_completed_hours", 0.0)))
	var required_hours := maxf(1.0, float(project.get("work_required_hours", 1.0)))
	var progress := clampf(completed_hours / required_hours, 0.0, 1.0)

	var progress_row := HBoxContainer.new()
	var progress_title := _label("RESEARCH PROGRESS", 12, TEXT_MUTED)
	progress_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress_title)
	active_progress_label = _label("%d%%" % roundi(progress * 100.0), 15, ACCENT)
	progress_row.add_child(active_progress_label)
	body_content.add_child(progress_row)

	active_progress_bar = ProgressBar.new()
	active_progress_bar.min_value = 0.0
	active_progress_bar.max_value = 100.0
	active_progress_bar.value = progress * 100.0
	active_progress_bar.show_percentage = false
	active_progress_bar.custom_minimum_size.y = 17
	body_content.add_child(active_progress_bar)

	var daily_hours := maxf(0.1, float(project.get("daily_work_hours", 0.0)))
	var remaining_hours := maxf(0.0, required_hours - completed_hours)
	var remaining_days := int(ceil(remaining_hours / daily_hours))
	active_remaining_label = _label("%d IN-GAME DAYS REMAINING" % remaining_days, 13, TEXT_MUTED)
	body_content.add_child(active_remaining_label)

	body_content.add_child(_label("SUCCESS CHANCE  %.0f%%" % float(project.get("success_chance", 0.0)), 16, GREEN))
	body_content.add_child(_label("INVESTMENT  %s" % _format_currency(float(project.get("budget", 0.0))), 13, TEXT_MUTED))

	var assigned_names: Array[String] = []
	for staff_id_value in project.get("staff_ids", []):
		var employee := _find_employee(str(staff_id_value))
		if not employee.is_empty():
			assigned_names.append(str(employee.get("full_name", employee.get("name", "Researcher"))))
	body_content.add_child(_label("RESEARCH TEAM  " + _join_values(assigned_names, ", "), 13, TEXT_MUTED))


func _get_active_project() -> Dictionary:
	for index in range(research_projects.size() - 1, -1, -1):
		var value: Variant = research_projects[index]
		if value is Dictionary and str(value.get("status", "")) == "active":
			return value
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


func _find_employee(employee_id: String) -> Dictionary:
	for employee_value in staff_employees:
		if employee_value is Dictionary and str(employee_value.get("id", "")) == employee_id:
			return employee_value
	return {}


func update_live_progress(projects: Array, balance: float, employees: Array) -> void:
	research_projects = projects.duplicate(true)
	company_balance = maxf(0.0, balance)
	staff_employees = employees.duplicate(true)
	if not is_node_ready():
		return
	var active_project := _get_active_project()
	if active_project.is_empty():
		if not creation_mode and not active_project_id.is_empty():
			_render_scene()
		return
	if str(active_project.get("id", "")) != active_project_id:
		_render_scene()
		return
	var completed_hours := maxf(0.0, float(active_project.get("work_completed_hours", 0.0)))
	var required_hours := maxf(1.0, float(active_project.get("work_required_hours", 1.0)))
	var progress := clampf(completed_hours / required_hours, 0.0, 1.0)
	var daily_hours := maxf(0.1, float(active_project.get("daily_work_hours", 0.0)))
	var remaining_days := int(ceil(maxf(0.0, required_hours - completed_hours) / daily_hours))
	if is_instance_valid(active_progress_bar):
		active_progress_bar.value = progress * 100.0
	if is_instance_valid(active_progress_label):
		active_progress_label.text = "%d%%" % roundi(progress * 100.0)
	if is_instance_valid(active_remaining_label):
		active_remaining_label.text = "%d IN-GAME DAYS REMAINING" % remaining_days


func _clear_body() -> void:
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func _new_center_content() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.name = "ResearchSceneContent"
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 15)
	content.custom_minimum_size.x = minf(520.0, maxf(300.0, get_viewport_rect().size.x - 72.0))
	return content


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(value: String, primary: bool, accent: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#24402d") if primary else Color("#111b15")
	normal.border_color = accent
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#31563d") if primary else Color("#1a2a20")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", 16)
	option.add_theme_color_override("font_color", TEXT_MAIN)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#101b15")
	style.border_color = Color("#41624a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	option.add_theme_stylebox_override("normal", style)
	option.add_theme_stylebox_override("hover", style)
	option.add_theme_stylebox_override("pressed", style)


func _style_input(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 17)
	input.add_theme_color_override("font_color", TEXT_MAIN)
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#101b15")
		style.border_color = Color("#41624a") if state == "normal" else ACCENT
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		input.add_theme_stylebox_override(state, style)


func _format_currency(value: float) -> String:
	return "₦" + _format_number(value)


func _format_number(value: float) -> String:
	var whole := str(int(round(value)))
	var formatted := ""
	for index in range(whole.length()):
		if index > 0 and (whole.length() - index) % 3 == 0:
			formatted += ","
		formatted += whole.substr(index, 1)
	return formatted


func _join_values(values: Array, separator: String) -> String:
	var result := ""
	for value in values:
		if not result.is_empty():
			result += separator
		result += str(value)
	return result
