extends Control

signal back_requested
signal project_commission_requested(request: Dictionary)
signal project_approve_requested(project_id: String, results: Array)
signal project_reject_requested(project_id: String, review_note: String)

const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")

const TEXT_MAIN := Color("#EEE9DF")
const TEXT_MUTED := Color("#AAA49A")
const ACCENT := Color("#C58A3A")
const SUCCESS := Color("#7FA88A")
const INFO := Color("#A7A49D")
const ORANGE := Color("#ffb45c")

const COMPONENT_LABELS := ["Screen Tech", "Phone Thickness", "Border Radius"]
const COMPONENT_VALUES := ["Screen Technology", "Phone Thickness", "Border Radius"]

var company_balance := 0.0
var staff_employees: Array = []
var research_projects: Array = []
var research_technologies: Dictionary = {}
var research_history: Array = []

var page_root: VBoxContainer
var body: MarginContainer
var body_content: VBoxContainer
var capital_value_label: Label
var company_name := "YOUR COMPANY"
var selected_component_index := 0
var component_buttons: Array[Button] = []
var estimate_label: Label
var start_button: Button
var assigned_staff_ids: Array[String] = []
var active_progress_bar: ProgressBar
var active_progress_label: Label
var active_remaining_label: Label
var active_project_id := ""
var creation_mode := false
var ui_scale := 1.0
var _last_layout_key := ""


func configure(data: Dictionary, _existing_pop_alert: Node = null) -> void:
	company_name = str(data.get("company_name", "Your Company"))
	company_balance = maxf(0.0, float(data.get("balance", 0.0)))
	if is_instance_valid(capital_value_label):
		capital_value_label.text = _format_currency(company_balance)
	staff_employees = data.get("staff_employees", []).duplicate(true)
	research_projects = data.get("research_projects", []).duplicate(true)
	research_technologies = data.get("research_technologies", {}).duplicate(true)
	research_history = data.get("research_history", []).duplicate(true)
	if is_node_ready():
		_render_scene()


func _ready() -> void:
	ui_scale = _calculate_ui_scale()
	_last_layout_key = _get_layout_key()
	resized.connect(_on_dashboard_resized)
	_build_shell()
	_render_scene()


func _calculate_ui_scale() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var width_scale := viewport_size.x / 1152.0
	var height_scale := viewport_size.y / 648.0
	return clampf(minf(width_scale, height_scale), 0.68, 1.0)


func _get_layout_key() -> String:
	var viewport_size := get_viewport_rect().size
	return "%d:%d:%.2f" % [
		1 if viewport_size.x < 900.0 else 0,
		1 if viewport_size.y < 560.0 else 0,
		_calculate_ui_scale()
	]


func _on_dashboard_resized() -> void:
	var next_key := _get_layout_key()
	if next_key == _last_layout_key:
		return
	ui_scale = _calculate_ui_scale()
	_last_layout_key = next_key
	_render_scene()


func _scaled(value: float) -> float:
	return maxf(1.0, value * ui_scale)


func _scaled_font(value: int) -> int:
	return maxi(9, roundi(float(value) * ui_scale))


func _is_narrow_layout() -> bool:
	return get_viewport_rect().size.x < 900.0


func _needs_vertical_scroll() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x < 900.0 or viewport_size.y < 560.0


func _new_main_row() -> BoxContainer:
	var row: BoxContainer
	if _is_narrow_layout():
		row = VBoxContainer.new()
	else:
		row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", roundi(_scaled(14.0)))
	return row


func _mount_screen_root(content: VBoxContainer) -> void:
	if _needs_vertical_scroll():
		var scroll := ScrollContainer.new()
		scroll.name = "ResearchDashboardResponsiveScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		body.add_child(scroll)
		scroll.add_child(content)
	else:
		body.add_child(content)


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "ResearchManagementBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#111315")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.075, 0.065, 0.052, 0.28)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	var frame := MarginContainer.new()
	frame.name = "ResearchManagementFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", roundi(_scaled(22.0)))
	frame.add_theme_constant_override("margin_right", roundi(_scaled(22.0)))
	frame.add_theme_constant_override("margin_top", roundi(_scaled(16.0)))
	frame.add_theme_constant_override("margin_bottom", roundi(_scaled(16.0)))
	add_child(frame)

	page_root = VBoxContainer.new()
	page_root.name = "ResearchManagementPage"
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", roundi(_scaled(10.0)))
	frame.add_child(page_root)

	var top_bar := HBoxContainer.new()
	top_bar.name = "ResearchTopBar"
	top_bar.custom_minimum_size = Vector2(0.0, _scaled(64.0))
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_bar.add_theme_constant_override("separation", roundi(_scaled(18.0)))
	page_root.add_child(top_bar)

	var back := _button("‹  BACK", false, TEXT_MAIN)
	back.custom_minimum_size = Vector2(_scaled(116.0), _scaled(48.0))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_requested.emit())
	top_bar.add_child(back)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 1)
	top_bar.add_child(title_stack)

	var section_title := _label("RESEARCH & DEVELOPMENT", 20, TEXT_MAIN)
	section_title.add_theme_font_size_override("font_size", _scaled_font(20))
	title_stack.add_child(section_title)
	title_stack.add_child(_label(company_name.to_upper(), 11, TEXT_MUTED))

	var capital_stack := VBoxContainer.new()
	capital_stack.custom_minimum_size.x = _scaled(190.0)
	capital_stack.size_flags_horizontal = Control.SIZE_SHRINK_END
	capital_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	capital_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	capital_stack.add_theme_constant_override("separation", 1)
	top_bar.add_child(capital_stack)
	var capital_caption := _label("AVAILABLE CAPITAL", 10, TEXT_MUTED)
	capital_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capital_caption.custom_minimum_size.x = _scaled(180.0)
	capital_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	capital_stack.add_child(capital_caption)
	capital_value_label = _label(_format_currency(company_balance), 17, ACCENT)
	capital_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capital_value_label.custom_minimum_size.x = _scaled(180.0)
	capital_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	capital_stack.add_child(capital_value_label)

	var separator := ColorRect.new()
	separator.color = Color("#3B3832")
	separator.custom_minimum_size.y = 1
	separator.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_root.add_child(separator)

	body = MarginContainer.new()
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
	component_buttons.clear()

	var active_project := _get_active_project()
	if not active_project.is_empty():
		_build_active_research(active_project)
	elif creation_mode:
		_build_creation_scene()
	else:
		_build_empty_scene()

func _build_empty_scene() -> void:
	body_content = _new_screen_root()
	_mount_screen_root(body_content)

	var page_heading := HBoxContainer.new()
	page_heading.custom_minimum_size.y = _scaled(62.0)
	page_heading.add_theme_constant_override("separation", roundi(_scaled(18.0)))
	body_content.add_child(page_heading)

	var heading_spacer := Control.new()
	heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_heading.add_child(heading_spacer)

	var status := _label("NO ACTIVE PROJECT", 12, ACCENT)
	status.custom_minimum_size.x = _scaled(150.0)
	status.size_flags_horizontal = Control.SIZE_SHRINK_END
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	page_heading.add_child(status)

	var main_row := _new_main_row()
	body_content.add_child(main_row)

	var launch_panel := _add_panel(main_row, 1.55)
	launch_panel.add_child(_label("NEW PROJECT", 18, ACCENT))

	var target_heading := _label("RESEARCH TARGET", 13, TEXT_MUTED)
	launch_panel.add_child(target_heading)
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 8)
	launch_panel.add_child(target_row)
	_add_target_tile(target_row, "SCREEN TECH", "")
	_add_target_tile(target_row, "THICKNESS", "")
	_add_target_tile(target_row, "BORDER RADIUS", "")

	var create := _button("COMMISSION A PROJECT  〉", true, ACCENT)
	create.name = "CreateResearchButton"
	create.custom_minimum_size = Vector2(260, 56)
	create.pressed.connect(_open_creation_scene)
	launch_panel.add_child(create)

	var capacity_panel := _add_panel(main_row, 0.82)
	capacity_panel.add_child(_label("RESEARCH CAPACITY", 15, TEXT_MAIN))
	var workforce := _get_workforce_summary()
	var available_staff := int(workforce.get("available_staff_count", 0))
	var total_staff := int(workforce.get("staff_count", 0))
	_add_large_metric(capacity_panel, str(available_staff), "AVAILABLE RESEARCHERS", ACCENT)
	var capacity_divider := ColorRect.new()
	capacity_divider.color = Color("#3B3832")
	capacity_divider.custom_minimum_size.y = 1
	capacity_panel.add_child(capacity_divider)
	_add_large_metric(capacity_panel, "%.0f%%" % float(workforce.get("available_efficiency", 0.0)), "AVAILABLE STAFF EFFICIENCY", TEXT_MAIN)
	_add_large_metric(capacity_panel, str(total_staff), "TOTAL RESEARCH STAFF", TEXT_MUTED)

func _open_creation_scene() -> void:
	creation_mode = true
	selected_component_index = 0
	assigned_staff_ids.clear()
	_render_scene()

func _build_creation_scene() -> void:
	body_content = _new_screen_root()
	_mount_screen_root(body_content)

	var page_heading := HBoxContainer.new()
	page_heading.custom_minimum_size.y = _scaled(58.0)
	page_heading.add_theme_constant_override("separation", 16)
	body_content.add_child(page_heading)
	var heading := _label("NEW PROJECT", 22, TEXT_MAIN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_heading.add_child(heading)

	var main_row := _new_main_row()
	body_content.add_child(main_row)

	var setup_panel := _add_panel(main_row, 1.12)
	setup_panel.add_child(_label("01  /  TARGET", 13, ACCENT))

	var component_row := HBoxContainer.new()
	component_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_row.add_theme_constant_override("separation", 8)
	setup_panel.add_child(component_row)
	for index in range(COMPONENT_LABELS.size()):
		var component_button := Button.new()
		component_button.name = "ResearchComponentOption" if index == 0 else "ResearchComponentOption_%d" % index
		component_button.text = COMPONENT_LABELS[index].to_upper()
		component_button.custom_minimum_size = Vector2(0, _scaled(88.0))
		component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		component_button.size_flags_vertical = Control.SIZE_FILL
		component_button.focus_mode = Control.FOCUS_NONE
		component_button.add_theme_font_size_override("font_size", _scaled_font(16))
		component_button.pressed.connect(_on_component_selected.bind(index))
		component_row.add_child(component_button)
		component_buttons.append(component_button)
	_update_component_button_styles()


	var team_panel := _add_panel(main_row, 0.96)
	var team_heading := HBoxContainer.new()
	team_panel.add_child(team_heading)
	var team_title := _label("02  /  STAFF", 13, ACCENT)
	team_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_heading.add_child(team_title)
	team_heading.add_child(_label("%d STAFF" % int(_get_workforce_summary().get("staff_count", 0)), 11, TEXT_MUTED))

	var staff_scroll := ScrollContainer.new()
	staff_scroll.name = "ResearchStaffScroll"
	staff_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	staff_scroll.custom_minimum_size = Vector2(0.0, _scaled(220.0 if not _is_narrow_layout() else 190.0))
	staff_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	team_panel.add_child(staff_scroll)
	var staff_list := VBoxContainer.new()
	staff_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	staff_list.add_theme_constant_override("separation", roundi(_scaled(9.0)))
	staff_scroll.add_child(staff_list)
	_build_staff_choices(staff_list)

	estimate_label = _label("DURATION  —     SUCCESS  —", 17, TEXT_MAIN)
	estimate_label.custom_minimum_size.y = _scaled(34.0)
	team_panel.add_child(estimate_label)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 12)
	body_content.add_child(actions)
	var cancel := _button("CANCEL", false, TEXT_MUTED)
	cancel.custom_minimum_size = Vector2(_scaled(150.0), _scaled(54.0))
	cancel.pressed.connect(_close_creation_scene)
	actions.add_child(cancel)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	start_button = _button("START RESEARCH  〉", true, ACCENT)
	start_button.name = "StartResearchButton"
	start_button.custom_minimum_size = Vector2(_scaled(260.0), _scaled(54.0))
	start_button.disabled = true
	start_button.pressed.connect(_on_start_research_pressed)
	actions.add_child(start_button)
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
		var selected := assigned_staff_ids.has(employee_id)
		var unavailable := employee_id.is_empty() or occupied_ids.has(employee_id)
		var staff_row := HBoxContainer.new()
		staff_row.custom_minimum_size = Vector2(0.0, _scaled(58.0))
		staff_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		staff_row.add_theme_constant_override("separation", roundi(_scaled(14.0)))
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("#29251E") if selected else Color("#202326")
		row_style.border_color = ACCENT if selected else Color("#49463F")
		row_style.set_border_width_all(1 if selected else 1)
		row_style.set_corner_radius_all(7)
		row_style.content_margin_left = roundi(_scaled(12.0))
		row_style.content_margin_right = roundi(_scaled(12.0))
		row_style.content_margin_top = roundi(_scaled(5.0))
		row_style.content_margin_bottom = roundi(_scaled(5.0))
		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", row_style)
		staff_row.add_child(row_panel)
		var row_content := HBoxContainer.new()
		row_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_content.add_theme_constant_override("separation", roundi(_scaled(12.0)))
		row_panel.add_child(row_content)
		var check_button := Button.new()
		check_button.custom_minimum_size = Vector2(_scaled(34.0), _scaled(34.0))
		check_button.disabled = unavailable
		check_button.text = "✓" if selected else ""
		check_button.add_theme_font_size_override("font_size", _scaled_font(21))
		check_button.add_theme_color_override("font_color", Color("#17191B"))
		check_button.focus_mode = Control.FOCUS_NONE
		var check_normal := StyleBoxFlat.new()
		check_normal.bg_color = ACCENT if selected else Color("#17191B")
		check_normal.border_color = ACCENT if selected else Color("#777064")
		check_normal.set_border_width_all(2)
		check_normal.set_corner_radius_all(6)
		var check_hover := check_normal.duplicate() as StyleBoxFlat
		check_hover.bg_color = Color("#D7A653") if selected else Color("#303336")
		check_button.add_theme_stylebox_override("normal", check_normal)
		check_button.add_theme_stylebox_override("hover", check_hover)
		check_button.add_theme_stylebox_override("pressed", check_hover)
		row_content.add_child(check_button)
		var staff_label := _label("%s   ·   %d%% EFFICIENCY" % [employee_name, efficiency], 19, TEXT_MAIN)
		staff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		staff_label.add_theme_font_size_override("font_size", _scaled_font(19))
		var staff_font := FontVariation.new()
		staff_font.base_font = staff_label.get_theme_font("font")
		staff_font.variation_embolden = 0.65
		staff_label.add_theme_font_override("font", staff_font)
		if unavailable:
			staff_label.add_theme_color_override("font_color", TEXT_MUTED)
		row_content.add_child(staff_label)
		check_button.pressed.connect(_on_staff_toggled.bind(not selected, employee_id))
		parent.add_child(staff_row)
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
	var estimate_valid := bool(estimate.get("ok", false))
	if estimate_valid:
		estimate_label.text = "ESTIMATED DURATION  %s IN-GAME DAYS\nESTIMATED SUCCESS CHANCE  %.0f%%" % [
			_format_research_days(float(estimate.get("expected_duration_days", 0.0))),
			float(estimate.get("success_chance", 0.0))
		]
		estimate_label.add_theme_color_override("font_color", ACCENT)
	else:
		estimate_label.text = str(estimate.get("error", "Assign researchers to see the estimate."))
		estimate_label.add_theme_color_override("font_color", TEXT_MUTED)
	start_button.disabled = not estimate_valid


func _on_start_research_pressed() -> void:
	if assigned_staff_ids.is_empty():
		_set_estimate_error("Assign at least one Research employee.")
		return
	var request := {
		"component": _selected_component(),
		"staff_ids": assigned_staff_ids.duplicate()
	}
	project_commission_requested.emit(request)


func _set_estimate_error(message: String) -> void:
	if is_instance_valid(estimate_label):
		estimate_label.text = message
		estimate_label.add_theme_color_override("font_color", ORANGE)


func _selected_component() -> String:
	var index := clampi(selected_component_index, 0, COMPONENT_VALUES.size() - 1)
	return COMPONENT_VALUES[index]

func _close_creation_scene() -> void:
	creation_mode = false
	assigned_staff_ids.clear()
	_render_scene()


func _build_active_research(project: Dictionary) -> void:
	creation_mode = false
	active_project_id = str(project.get("id", ""))
	body_content = _new_screen_root()
	_mount_screen_root(body_content)

	var page_heading := HBoxContainer.new()
	page_heading.custom_minimum_size.y = _scaled(58.0)
	page_heading.add_child(_label("RESEARCH IN DEVELOPMENT", 25, TEXT_MAIN))
	var heading_spacer := Control.new()
	heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_heading.add_child(heading_spacer)
	page_heading.add_child(_label("PROJECT  " + active_project_id, 12, ACCENT))
	body_content.add_child(page_heading)

	var completed_days := maxf(0.0, float(project.get("completed_research_days", 0.0)))
	var required_days := maxf(1.0, float(project.get("required_research_days", 30.0)))
	var progress := clampf(completed_days / required_days, 0.0, 1.0)
	var remaining_days := maxf(0.0, required_days - completed_days)

	var main_row := _new_main_row()
	body_content.add_child(main_row)

	var progress_panel := _add_panel(main_row, 1.55)

	var component_name := str(project.get("component", project.get("title", "Research project")))
	if component_name == "Screen Technology":
		component_name = "Screen Tech"
	progress_panel.add_child(_label(component_name.to_upper(), 31, TEXT_MAIN))
	var progress_row := HBoxContainer.new()
	progress_panel.add_child(progress_row)
	var progress_title := _label("PROJECT COMPLETION", 12, TEXT_MUTED)
	progress_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress_title)
	active_progress_label = _label("%d%%" % roundi(progress * 100.0), 20, ACCENT)
	progress_row.add_child(active_progress_label)

	active_progress_bar = ProgressBar.new()
	active_progress_bar.min_value = 0.0
	active_progress_bar.max_value = 100.0
	active_progress_bar.value = progress * 100.0
	active_progress_bar.show_percentage = false
	active_progress_bar.custom_minimum_size.y = _scaled(24.0)
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color("#303336")
	progress_track.set_corner_radius_all(5)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = ACCENT
	progress_fill.set_corner_radius_all(5)
	active_progress_bar.add_theme_stylebox_override("background", progress_track)
	active_progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_panel.add_child(active_progress_bar)

	active_remaining_label = _label("%s IN-GAME DAYS REMAINING" % _format_research_days(remaining_days), 17, TEXT_MAIN)
	progress_panel.add_child(active_remaining_label)

	var pause_reason := str(project.get("pause_reason", "")).strip_edges()
	if not pause_reason.is_empty():
		var pause_label := _label("PROJECT PAUSED  /  " + pause_reason, 13, ORANGE)
		pause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		progress_panel.add_child(pause_label)

	var details_panel := _add_panel(main_row, 0.86)
	details_panel.add_child(_label("PROJECT DATA", 14, TEXT_MAIN))
	_add_large_metric(details_panel, "%.0f%%" % float(project.get("success_chance", 0.0)), "SUCCESS", TEXT_MAIN)
	var detail_divider := ColorRect.new()
	detail_divider.color = Color("#3B3832")
	detail_divider.custom_minimum_size.y = 1
	details_panel.add_child(detail_divider)
	details_panel.add_child(_label("STAFF", 11, TEXT_MUTED))
	var assigned_names: Array[String] = []
	for staff_id_value in project.get("staff_ids", []):
		var employee := _find_employee(str(staff_id_value))
		if not employee.is_empty():
			assigned_names.append(str(employee.get("full_name", employee.get("name", "Researcher"))))
	if assigned_names.is_empty():
		details_panel.add_child(_label("No assigned researchers found.", 13, TEXT_MUTED))
	else:
		for employee_name in assigned_names:
			details_panel.add_child(_label("•  " + employee_name, 14, TEXT_MAIN))

func _add_panel(parent: Control, stretch_ratio: float = 1.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch_ratio
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1A1D1F")
	panel_style.border_color = Color("#45423B")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(9)
	panel_style.content_margin_left = roundi(_scaled(18.0))
	panel_style.content_margin_right = roundi(_scaled(18.0))
	panel_style.content_margin_top = roundi(_scaled(16.0))
	panel_style.content_margin_bottom = roundi(_scaled(16.0))
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", roundi(_scaled(11.0)))
	panel.add_child(content)
	return content


func _add_target_tile(parent: HBoxContainer, title: String, description: String) -> void:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 3)
	parent.add_child(tile)
	tile.add_child(_label(title, 12, TEXT_MAIN))
	tile.add_child(_label(description, 11, TEXT_MUTED))


func _add_large_metric(parent: VBoxContainer, value: String, caption: String, color: Color) -> void:
	var metric := VBoxContainer.new()
	metric.add_theme_constant_override("separation", roundi(_scaled(2.0)))
	parent.add_child(metric)
	var value_label := _label(value, 26, color)
	value_label.add_theme_font_size_override("font_size", _scaled_font(26))
	metric.add_child(value_label)
	metric.add_child(_label(caption, 10, TEXT_MUTED))


func _get_workforce_summary() -> Dictionary:
	return ResearchManagerScript.get_workforce_summary({
		"staff_employees": staff_employees,
		"research_projects": research_projects
	})


func _on_component_selected(index: int) -> void:
	selected_component_index = clampi(index, 0, COMPONENT_VALUES.size() - 1)
	_update_component_button_styles()
	_update_research_estimate()


func _update_component_button_styles() -> void:
	for index in range(component_buttons.size()):
		var button := component_buttons[index]
		var selected := index == selected_component_index
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#554021") if selected else Color("#222628")
		normal.border_color = ACCENT if selected else Color("#49463F")
		normal.set_border_width_all(2 if selected else 1)
		normal.set_corner_radius_all(7)
		normal.content_margin_left = 9
		normal.content_margin_right = 9
		normal.content_margin_top = 12
		normal.content_margin_bottom = 12
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#624A29") if selected else Color("#2B3032")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)



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
	if is_instance_valid(capital_value_label):
		capital_value_label.text = _format_currency(company_balance)
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
	var completed_days := maxf(0.0, float(active_project.get("completed_research_days", 0.0)))
	var required_days := maxf(1.0, float(active_project.get("required_research_days", 30.0)))
	var progress := clampf(completed_days / required_days, 0.0, 1.0)
	var remaining_days := maxf(0.0, required_days - completed_days)
	if is_instance_valid(active_progress_bar):
		active_progress_bar.value = progress * 100.0
	if is_instance_valid(active_progress_label):
		active_progress_label.text = "%d%%" % roundi(progress * 100.0)
	if is_instance_valid(active_remaining_label):
		active_remaining_label.text = "%s IN-GAME DAYS REMAINING" % _format_research_days(remaining_days)


func _clear_body() -> void:
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func _new_screen_root() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.name = "ResearchSceneContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", roundi(_scaled(12.0)))
	return content

func _label(value: String, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", _scaled_font(font_size))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(value: String, primary: bool, accent: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", _scaled_font(17))
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#805821") if primary else Color("#202326")
	normal.border_color = accent
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = roundi(_scaled(14.0))
	normal.content_margin_right = roundi(_scaled(14.0))
	normal.content_margin_top = roundi(_scaled(9.0))
	normal.content_margin_bottom = roundi(_scaled(9.0))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#956A2E") if primary else Color("#2A2E30")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", _scaled_font(16))
	option.add_theme_color_override("font_color", TEXT_MAIN)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#202326")
	style.border_color = Color("#514B40")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = roundi(_scaled(10.0))
	style.content_margin_right = roundi(_scaled(10.0))
	option.add_theme_stylebox_override("normal", style)
	option.add_theme_stylebox_override("hover", style)
	option.add_theme_stylebox_override("pressed", style)


func _style_input(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", _scaled_font(22))
	input.add_theme_color_override("font_color", TEXT_MAIN)
	input.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#202326")
		style.border_color = Color("#514B40") if state == "normal" else ACCENT
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = roundi(_scaled(14.0))
		style.content_margin_right = roundi(_scaled(14.0))
		style.content_margin_top = roundi(_scaled(10.0))
		style.content_margin_bottom = roundi(_scaled(10.0))
		input.add_theme_stylebox_override(state, style)

func _format_research_days(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


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
