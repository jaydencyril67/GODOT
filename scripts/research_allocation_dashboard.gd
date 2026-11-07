extends Control

signal back_requested
signal strategy_changed(strategy: Dictionary)
signal component_priorities_changed(priorities: Dictionary)

const DEPARTMENTS := ["Hardware", "Software", "Extras"]
const DEPARTMENT_COMPONENTS := {
	"Hardware": [
		"Display", "Processor", "Front Camera", "Rear Camera",
		"Charging System", "RAM", "Internal Storage", "Cooling System"
	],
	"Software": ["Battery", "Wi-Fi", "Bluetooth", "Mobile Internet"],
	"Extras": ["Phone Case", "Protection Glass", "Power Bank", "Charger", "Wireless Earbuds", "Smartwatch"]
}
const PRIORITY_LEVELS := ["Low", "High", "Extreme"]

const TEXT_MAIN := Color("#f0f5f1")
const TEXT_MUTED := Color("#9eafa4")
const ACCENT := Color("#9bd6a7")
const DEPARTMENT_COLORS := {
	"Hardware": Color("#42c7ee"),
	"Software": Color("#b58aff"),
	"Extras": Color("#ffb45c")
}
const PANEL := Color(0.025, 0.055, 0.041, 0.97)
const PANEL_BORDER := Color(0.25, 0.43, 0.31, 0.85)


class AllocationDial extends Control:
	signal allocation_changed(value: float)
	signal steering_released

	var department := ""
	var accent := Color("#42c7ee")
	var allocation := 0.0
	var _dragging := false
	var _last_angle := 0.0

	func setup(department_name: String, accent_color: Color, initial_value: float, diameter: float) -> void:
		department = department_name
		accent = accent_color
		allocation = clampf(initial_value, 0.0, 100.0)
		custom_minimum_size = Vector2(diameter, diameter)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		queue_redraw()

	func set_allocation(value: float) -> void:
		allocation = clampf(value, 0.0, 100.0)
		queue_redraw()

	func _draw() -> void:
		if size.x < 20.0 or size.y < 20.0:
			return
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.465
		draw_circle(centre + Vector2(0, 6), radius + 1.0, Color(0.0, 0.0, 0.0, 0.48))
		draw_circle(centre, radius, Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.96))
		draw_circle(centre, radius - 10.0, Color("#09120f"))
		draw_arc(centre, radius - 5.0, 0.0, TAU, 100, Color(accent.r, accent.g, accent.b, 0.28), 2.0, true)
		draw_arc(centre, radius - 17.0, 0.0, TAU, 100, Color(0.85, 1.0, 0.88, 0.10), 1.0, true)
		for tick in range(36):
			var angle := -PI * 0.5 + TAU * float(tick) / 36.0
			var outer := centre + Vector2(cos(angle), sin(angle)) * (radius - 2.0)
			var inner := centre + Vector2(cos(angle), sin(angle)) * (radius - (10.0 if tick % 3 == 0 else 6.0))
			draw_line(inner, outer, Color(accent.r, accent.g, accent.b, 0.45 if tick % 3 == 0 else 0.20), 1.3, true)
		var end_angle := -PI * 0.5 + TAU * allocation / 100.0
		if allocation > 0.05:
			draw_arc(centre, radius - 5.0, -PI * 0.5, end_angle, 100, accent, 7.0, true)
		var pointer := centre + Vector2(cos(end_angle), sin(end_angle)) * (radius - 5.0)
		draw_circle(pointer, 8.0, Color("#06100b"))
		draw_circle(pointer, 5.0, accent)
		draw_arc(centre, radius - 23.0, -PI * 0.5, TAU * 0.5, 60, Color(1.0, 1.0, 1.0, 0.045), 1.0, true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _begin_steering(event.position):
					accept_event()
			elif _dragging:
				_end_steering()
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_steer(event.position)
			accept_event()
		elif event is InputEventScreenTouch:
			if event.pressed:
				if _begin_steering(event.position):
					accept_event()
			elif _dragging:
				_end_steering()
				accept_event()
		elif event is InputEventScreenDrag and _dragging:
			_steer(event.position)
			accept_event()

	func _begin_steering(point: Vector2) -> bool:
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.465
		var distance := point.distance_to(centre)
		if distance < radius * 0.64 or distance > radius * 1.08:
			return false
		_dragging = true
		_last_angle = atan2(point.y - centre.y, point.x - centre.x)
		return true

	func _steer(point: Vector2) -> void:
		var centre := size * 0.5
		var angle := atan2(point.y - centre.y, point.x - centre.x)
		var delta := wrapf(angle - _last_angle, -PI, PI)
		_last_angle = angle
		if absf(delta) < 0.0005:
			return
		allocation = clampf(allocation + delta * (100.0 / TAU), 0.0, 100.0)
		queue_redraw()
		allocation_changed.emit(allocation)

	func _end_steering() -> void:
		_dragging = false
		steering_released.emit()


var company_name := "Your Company"
var research_points := 0
var strategy: Dictionary = {"Hardware": 60, "Software": 30, "Extras": 10}
var component_priorities: Dictionary = {}
var research_history: Array = []
var allocation_dials: Dictionary = {}
var focus_summary_labels: Dictionary = {}
var priority_component_buttons: Array[Button] = []
var priority_type_buttons: Array[Button] = []
var pending_priority_rows: Array[Dictionary] = []
var pending_department := ""
var pop_alert: Node
var history_overlay: Control
var _updating_strategy := false


func configure(data: Dictionary, existing_pop_alert: Node = null) -> void:
	company_name = str(data.get("company_name", "Your Company"))
	research_points = maxi(0, int(data.get("research_points", 0)))
	pop_alert = existing_pop_alert
	var incoming_strategy: Dictionary = data.get("research_strategy", {})
	for department in DEPARTMENTS:
		strategy[department] = clampi(int(incoming_strategy.get(department, strategy[department])), 0, 100)
	_normalize_loaded_strategy()
	_load_component_priorities(data.get("research_component_priorities", {}))
	research_history = data.get("research_history", []).duplicate(true)


func _ready() -> void:
	_build_dashboard()


func _build_dashboard() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.y < 520.0 or viewport_size.x < 760.0
	var dial_size := clampf(minf(viewport_size.x / 4.7, viewport_size.y * 0.52), 174.0, 310.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "ResearchDashboardBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#050a08")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.name = "ResearchDashboardAtmosphere"
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.025, 0.085, 0.055, 0.34)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	var frame := MarginContainer.new()
	frame.name = "ResearchDashboardFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 14 if compact else 34)
	frame.add_theme_constant_override("margin_right", 14 if compact else 34)
	frame.add_theme_constant_override("margin_top", 8 if compact else 22)
	frame.add_theme_constant_override("margin_bottom", 8 if compact else 18)
	add_child(frame)

	var page := VBoxContainer.new()
	page.name = "CompanyResearchAllocationDashboard"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 4 if compact else 12)
	frame.add_child(page)

	var header := HBoxContainer.new()
	header.name = "ResearchDashboardHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)
	title_stack.add_child(_label("COMPANY RESEARCH  /  COMMAND", 9 if compact else 11, ACCENT))
	var title := _label("Research Allocation", 19 if compact else 29, TEXT_MAIN)
	title_stack.add_child(title)

	var company_label := _label(company_name.to_upper(), 8 if compact else 10, TEXT_MUTED)
	company_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(company_label)
	var points_label := _label("RP  %s" % _format_number(research_points), 10 if compact else 13, Color("#c7eacb"))
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(points_label)

	var history_button := _button("HISTORY", false, ACCENT, compact)
	history_button.pressed.connect(_show_history)
	header.add_child(history_button)
	var back_button := _button("BACK  ‹", false, TEXT_MAIN, compact)
	back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(back_button)

	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(0.55, 0.82, 0.61, 0.22)
	page.add_child(separator)

	var instruction := _label("STEER EACH DEPARTMENT RING TO REBALANCE YOUR RESEARCH FORCE", 8 if compact else 11, TEXT_MUTED)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(instruction)

	var body := HBoxContainer.new()
	body.name = "ResearchDashboardBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 18 if compact else 46)
	page.add_child(body)

	for department in DEPARTMENTS:
		_add_department_dial(body, department, dial_size, compact)

	var footer := HBoxContainer.new()
	footer.name = "ResearchDashboardFooter"
	footer.add_theme_constant_override("separation", 8)
	page.add_child(footer)
	var total_caption := _label("TOTAL ALLOCATION", 9 if compact else 11, TEXT_MUTED)
	footer.add_child(total_caption)
	var total_spacer := Control.new()
	total_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(total_spacer)
	var total_label := _label("100%  •  ALLOCATION BALANCED", 9 if compact else 11, ACCENT)
	total_label.name = "StrategyTotalLabel"
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(total_label)


func _add_department_dial(parent: HBoxContainer, department: String, diameter: float, compact: bool) -> void:
	var group := VBoxContainer.new()
	group.name = department + "DepartmentControl"
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 4 if compact else 8)
	parent.add_child(group)

	var dial := AllocationDial.new()
	dial.name = department + "AllocationDial"
	dial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dial.setup(department, DEPARTMENT_COLORS[department], int(strategy[department]), diameter)
	dial.allocation_changed.connect(_on_allocation_dial_changed.bind(department))
	dial.steering_released.connect(_commit_strategy)
	group.add_child(dial)
	allocation_dials[department] = dial

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dial.add_child(centre)

	var centre_stack := VBoxContainer.new()
	centre_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	centre_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centre_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centre_stack.add_theme_constant_override("separation", 1)
	centre_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(centre_stack)

	var department_label := _label(department.to_upper(), 12 if compact else 16, DEPARTMENT_COLORS[department])
	department_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	department_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre_stack.add_child(department_label)

	var percentage_label := _label("%d%%" % int(strategy[department]), 27 if compact else 38, TEXT_MAIN)
	percentage_label.name = department + "Percentage"
	percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percentage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre_stack.add_child(percentage_label)
	dial.set_meta("percentage_label", percentage_label)

	var set_priority_button := _button("SET PRIORITY", true, DEPARTMENT_COLORS[department], compact)
	set_priority_button.custom_minimum_size = Vector2(120 if compact else 146, 32 if compact else 38)
	set_priority_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	set_priority_button.pressed.connect(_open_priority_editor.bind(department))
	centre_stack.add_child(set_priority_button)

	var focus_label := _label("NO SPECIAL FOCUS  •  NORMAL", 8 if compact else 9, TEXT_MUTED)
	focus_label.custom_minimum_size = Vector2(diameter + 26.0, 38.0 if compact else 48.0)
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(focus_label)
	focus_summary_labels[department] = focus_label
	_refresh_department_focus_summary(department)


func _on_allocation_dial_changed(value: float, changed_department: String) -> void:
	_apply_allocation_value(value, changed_department, false)


func _apply_allocation_value(value: float, changed_department: String, commit: bool = false) -> void:
	if _updating_strategy or not strategy.has(changed_department):
		return
	var fixed_value := clampi(roundi(value), 0, 100)
	var remaining := 100 - fixed_value
	var other_departments: Array[String] = []
	for department in DEPARTMENTS:
		if department != changed_department:
			other_departments.append(department)
	var other_total := 0
	for department in other_departments:
		other_total += int(strategy[department])

	_updating_strategy = true
	strategy[changed_department] = fixed_value
	if other_total <= 0:
		strategy[other_departments[0]] = int(floor(float(remaining) * 0.5))
		strategy[other_departments[1]] = remaining - int(strategy[other_departments[0]])
	else:
		var first_share := roundi(float(remaining) * float(strategy[other_departments[0]]) / float(other_total))
		first_share = clampi(first_share, 0, remaining)
		strategy[other_departments[0]] = first_share
		strategy[other_departments[1]] = remaining - first_share

	for department in DEPARTMENTS:
		if allocation_dials.has(department) and is_instance_valid(allocation_dials[department]):
			var dial: AllocationDial = allocation_dials[department]
			dial.set_allocation(float(strategy[department]))
			var percentage_label: Label = dial.get_meta("percentage_label") as Label
			if is_instance_valid(percentage_label):
				percentage_label.text = "%d%%" % int(strategy[department])
	_updating_strategy = false
	if commit:
		_commit_strategy()


func _commit_strategy() -> void:
	strategy_changed.emit(strategy.duplicate(true))


func _open_priority_editor(department: String) -> void:
	if not is_instance_valid(pop_alert) or not pop_alert.has_method("show_custom_prompt"):
		push_error("The existing DigitalWorld pop-alert system was not provided to the research dashboard.")
		return
	pending_department = department
	pending_priority_rows.clear()
	for component in DEPARTMENT_COMPONENTS[department]:
		if component_priorities.has(component) and pending_priority_rows.size() < 3:
			pending_priority_rows.append({
				"component": component,
				"priority": str(component_priorities[component])
			})
	while pending_priority_rows.size() < 3:
		pending_priority_rows.append({"component": "", "priority": ""})

	priority_component_buttons.clear()
	priority_type_buttons.clear()
	var compact := get_viewport_rect().size.x < 700.0
	var editor := VBoxContainer.new()
	editor.name = "DepartmentPriorityEditor"
	editor.custom_minimum_size.x = minf(650.0, maxf(230.0, get_viewport_rect().size.x - 64.0))
	editor.add_theme_constant_override("separation", 8)

	var helper := _label("Choose up to three components. Each selected component can have its own focus level.", 10 if compact else 12, TEXT_MUTED)
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	editor.add_child(helper)

	for slot_index in range(3):
		var row := HBoxContainer.new()
		row.name = "PrioritySlot%d" % (slot_index + 1)
		row.add_theme_constant_override("separation", 8)
		editor.add_child(row)

		var slot_number := _label("%02d" % (slot_index + 1), 10, DEPARTMENT_COLORS[department])
		slot_number.custom_minimum_size.x = 24
		slot_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(slot_number)

		var component_button := _button("SELECT COMPONENT", false, DEPARTMENT_COLORS[department], compact)
		component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		component_button.custom_minimum_size.y = 42
		component_button.pressed.connect(_open_component_picker.bind(slot_index))
		row.add_child(component_button)
		priority_component_buttons.append(component_button)

		var priority_button := _button("SELECT PRIORITY", false, ACCENT, compact)
		priority_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		priority_button.custom_minimum_size.y = 42
		priority_button.disabled = str(pending_priority_rows[slot_index].get("component", "")).is_empty()
		priority_button.pressed.connect(_open_priority_picker.bind(slot_index))
		row.add_child(priority_button)
		priority_type_buttons.append(priority_button)

	_refresh_priority_editor_rows()
	pop_alert.call(
		"show_custom_prompt",
		"%s PRIORITY FOCUS" % department.to_upper(),
		"Set the department's component research priorities.",
		editor,
		"SAVE PRIORITIES",
		Callable(self, "_save_department_priorities")
	)


func _refresh_priority_editor_rows() -> void:
	for index in range(mini(3, priority_component_buttons.size())):
		var component := str(pending_priority_rows[index].get("component", ""))
		var priority := str(pending_priority_rows[index].get("priority", ""))
		var component_button: Button = priority_component_buttons[index]
		var priority_button: Button = priority_type_buttons[index]
		component_button.text = component if not component.is_empty() else "SELECT COMPONENT"
		priority_button.text = priority.to_upper() if not priority.is_empty() else "SELECT PRIORITY"
		priority_button.disabled = component.is_empty()


func _open_component_picker(slot_index: int) -> void:
	if not is_instance_valid(pop_alert) or not pop_alert.has_method("show_custom_picker"):
		return
	var selected_elsewhere: Array[String] = []
	for index in range(pending_priority_rows.size()):
		if index == slot_index:
			continue
		var existing := str(pending_priority_rows[index].get("component", ""))
		if not existing.is_empty():
			selected_elsewhere.append(existing)

	var options: Array[String] = []
	for component in DEPARTMENT_COMPONENTS[pending_department]:
		if not selected_elsewhere.has(component):
			options.append(component)
	var current_component := str(pending_priority_rows[slot_index].get("component", ""))
	pop_alert.call(
		"show_custom_picker",
		options,
		"SELECT %s COMPONENT" % pending_department.to_upper(),
		current_component,
		Callable(self, "_on_priority_component_selected").bind(slot_index)
	)


func _on_priority_component_selected(component: String, slot_index: int) -> void:
	pending_priority_rows[slot_index]["component"] = component
	if str(pending_priority_rows[slot_index].get("priority", "")).is_empty():
		pending_priority_rows[slot_index]["priority"] = "High"
	_refresh_priority_editor_rows()


func _open_priority_picker(slot_index: int) -> void:
	if not is_instance_valid(pop_alert) or not pop_alert.has_method("show_custom_picker"):
		return
	if str(pending_priority_rows[slot_index].get("component", "")).is_empty():
		return
	pop_alert.call(
		"show_custom_picker",
		PRIORITY_LEVELS,
		"SELECT PRIORITY TYPE",
		str(pending_priority_rows[slot_index].get("priority", "High")),
		Callable(self, "_on_priority_type_selected").bind(slot_index)
	)


func _on_priority_type_selected(priority: String, slot_index: int) -> void:
	pending_priority_rows[slot_index]["priority"] = priority
	_refresh_priority_editor_rows()


func _save_department_priorities() -> void:
	if not DEPARTMENT_COMPONENTS.has(pending_department):
		return
	var updated_priorities := component_priorities.duplicate(true)
	for component in DEPARTMENT_COMPONENTS[pending_department]:
		updated_priorities.erase(component)

	var saved_count := 0
	for row in pending_priority_rows:
		var component := str(row.get("component", ""))
		var priority := str(row.get("priority", ""))
		if component.is_empty() or not PRIORITY_LEVELS.has(priority):
			continue
		if saved_count >= 3:
			break
		updated_priorities[component] = priority
		saved_count += 1

	component_priorities = updated_priorities
	_refresh_department_focus_summary(pending_department)
	component_priorities_changed.emit(component_priorities.duplicate(true))


func _load_component_priorities(incoming: Dictionary) -> void:
	component_priorities.clear()
	for department in DEPARTMENTS:
		var saved_for_department := 0
		for component in DEPARTMENT_COMPONENTS[department]:
			if not incoming.has(component) or saved_for_department >= 3:
				continue
			var saved_priority := str(incoming[component])
			if saved_priority == "Very High":
				saved_priority = "Extreme"
			if not PRIORITY_LEVELS.has(saved_priority):
				continue
			component_priorities[component] = saved_priority
			saved_for_department += 1


func _refresh_department_focus_summary(department: String) -> void:
	if not focus_summary_labels.has(department):
		return
	var label: Label = focus_summary_labels[department]
	if not is_instance_valid(label):
		return
	var lines: Array[String] = []
	for component in DEPARTMENT_COMPONENTS[department]:
		if component_priorities.has(component):
			lines.append("%s  ·  %s" % [component, str(component_priorities[component]).to_upper()])
	if lines.is_empty():
		label.text = "NO SPECIAL FOCUS  •  NORMAL"
		label.add_theme_color_override("font_color", TEXT_MUTED)
	else:
		label.text = "\n".join(lines)
		label.add_theme_color_override("font_color", DEPARTMENT_COLORS[department])


func _show_history() -> void:
	if is_instance_valid(history_overlay):
		history_overlay.queue_free()
	history_overlay = Control.new()
	history_overlay.name = "RecentResearchHistoryOverlay"
	history_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	history_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(history_overlay)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.0, 0.015, 0.01, 0.88)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	history_overlay.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	history_overlay.add_child(centre)

	var panel := _panel()
	panel.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 28.0, 680.0), minf(get_viewport_rect().size.y - 28.0, 440.0))
	centre.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(_padded(content, true))

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label("RECENT RESEARCH", 16, TEXT_MAIN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("CLOSE  ×", false, TEXT_MAIN, true)
	close.pressed.connect(_close_history)
	header.add_child(close)

	var hint := _label("Completed discoveries and research milestones will appear here.", 10, TEXT_MUTED)
	content.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var history_list := VBoxContainer.new()
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_list.add_theme_constant_override("separation", 6)
	scroll.add_child(history_list)

	if research_history.is_empty():
		var empty := _label("No research discoveries recorded yet.", 12, TEXT_MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		history_list.add_child(empty)
	else:
		for entry in research_history.slice(maxi(0, research_history.size() - 20), research_history.size()).duplicate():
			var item := _panel()
			history_list.add_child(item)
			var item_content := VBoxContainer.new()
			item_content.add_theme_constant_override("separation", 2)
			item.add_child(_padded(item_content, true))
			item_content.add_child(_label(str(entry.get("title", "Research milestone")), 11, TEXT_MAIN))
			item_content.add_child(_label(str(entry.get("detail", entry.get("description", ""))), 9, TEXT_MUTED))
			item_content.add_child(_label(str(entry.get("date", "")), 8, ACCENT))


func _close_history() -> void:
	if is_instance_valid(history_overlay):
		history_overlay.queue_free()
	history_overlay = null


func _normalize_loaded_strategy() -> void:
	var total := int(strategy["Hardware"]) + int(strategy["Software"]) + int(strategy["Extras"])
	if total == 100:
		return
	if total <= 0:
		strategy = {"Hardware": 60, "Software": 30, "Extras": 10}
		return
	var hardware := roundi(100.0 * float(strategy["Hardware"]) / float(total))
	var software := roundi(100.0 * float(strategy["Software"]) / float(total))
	strategy = {"Hardware": hardware, "Software": software, "Extras": 100 - hardware - software}


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _padded(content: Control, compact: bool) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7 if compact else 13)
	margin.add_theme_constant_override("margin_right", 7 if compact else 13)
	margin.add_theme_constant_override("margin_top", 6 if compact else 10)
	margin.add_theme_constant_override("margin_bottom", 6 if compact else 10)
	margin.add_child(content)
	return margin


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _button(value: String, primary: bool, accent: Color, compact: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(88 if compact else 112, 32 if compact else 40)
	button.add_theme_font_size_override("font_size", 9 if compact else 11)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.94) if primary else Color("#101b15")
		if state == "hover":
			style.bg_color = Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 0.98) if primary else Color("#1a2b20")
		elif state == "pressed":
			style.bg_color = Color("#07100b")
		elif state == "disabled":
			style.bg_color = Color("#0d1510")
		style.border_color = Color(accent.r, accent.g, accent.b, 0.92 if primary else 0.58)
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		button.add_theme_stylebox_override(state, style)
	return button


func _format_number(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return formatted
