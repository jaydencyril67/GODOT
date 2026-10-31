extends Control

signal back_requested
signal hire_requested(candidate_id: String)
signal dismiss_requested(employee_id: String)
signal assignment_requested(employee_id: String, department: String)

const DEPARTMENTS := ["Development", "Marketing", "Research"]
const BG := Color("#071d32")
const PANEL := Color(0.055, 0.17, 0.28, 0.94)
const BORDER := Color(0.35, 0.72, 0.94, 0.72)
const WHITE := Color("#f2f9ff")
const MUTED := Color("#a9c9dc")

var mode := "office"
var candidates: Array = []
var employees: Array = []
var capacity := 3
var company_name := "YOUR COMPANY"
var company_balance := 0.0
var market_filter := "All Departments"
var content: VBoxContainer
var staff_scroll: ScrollContainer
var staff_scroll_tween: Tween
var staff_touch_index := -1
var staff_touch_start := Vector2.ZERO
var staff_touch_dragging := false
var staff_touch_velocity_y := 0.0


func open(screen_mode: String, candidate_data: Array, employee_data: Array, staff_capacity: int, business_name: String, balance: float) -> void:
	mode = screen_mode
	candidates = candidate_data.duplicate(true)
	employees = employee_data.duplicate(true)
	capacity = maxi(0, staff_capacity)
	company_name = business_name
	company_balance = balance
	_build()


func update_balance(amount: float) -> void:
	company_balance = amount
	_build()


func _build() -> void:
	if is_instance_valid(staff_scroll_tween) and staff_scroll_tween.is_running():
		staff_scroll_tween.kill()
	staff_touch_index = -1
	staff_touch_dragging = false
	staff_touch_velocity_y = 0.0
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 900.0

	var background := TextureRect.new()
	background.name = "DigitalWorld_Shared_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load("res://assets/digitalworld-landing.png")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.075, 0.12, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.name = "StaffSceneScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = false
	scroll.scroll_deadzone = 8
	scroll.clip_contents = true
	staff_scroll = scroll
	add_child(scroll)

	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("margin_left", 18 if compact else 42)
	outer.add_theme_constant_override("margin_right", 18 if compact else 42)
	outer.add_theme_constant_override("margin_top", 18 if compact else 28)
	outer.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(outer)

	var page := VBoxContainer.new()
	page.name = "StaffSceneContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 15 if compact else 18)
	outer.add_child(page)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	page.add_child(header)
	header.add_child(_label("DIGITALWORLD  /  OFFICE", 11 if compact else 13, Color("#a9e3ff")))

	var hero_row := HBoxContainer.new()
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_theme_constant_override("separation", 12)
	header.add_child(hero_row)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(heading)
	var title_text := "STAFF MARKET" if mode == "market" else ("STAFF MANAGEMENT" if mode == "management" else "OFFICE")
	var title := _label(title_text, 27 if compact else 36, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label(company_name.to_upper() + "  /  AVAILABLE BALANCE  " + _money(company_balance), 11 if compact else 12, Color("#c7eaff")))
	var back := _button("BACK TO HQ", false)
	back.custom_minimum_size = Vector2(112 if compact else 126, 44 if compact else 50)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func(): back_requested.emit())
	hero_row.add_child(back)

	# The page-level ScrollContainer owns vertical scrolling. A second nested
	# ScrollContainer here can collapse to zero height inside the VBox on mobile,
	# making both candidate and employee lists appear empty.
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	page.add_child(content)

	# Dedicated screens: no navigation switcher between market and management.
	if mode == "market":
		_build_market()
	else:
		_build_management()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(staff_scroll) or not visible:
		return
	var viewport := get_viewport()
	var scroll_rect := staff_scroll.get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed:
			if scroll_rect.has_point(event.position):
				staff_touch_index = event.index
				staff_touch_start = event.position
				staff_touch_dragging = false
				staff_touch_velocity_y = 0.0
		else:
			if event.index == staff_touch_index:
				if staff_touch_dragging:
					var fling_distance := clampf(staff_touch_velocity_y * 0.10, -420.0, 420.0)
					var target := clampi(roundi(float(staff_scroll.scroll_vertical) - fling_distance), 0, _staff_max_scroll())
					_animate_staff_scroll(target, 0.24)
					viewport.set_input_as_handled()
				staff_touch_index = -1
				staff_touch_dragging = false
				staff_touch_velocity_y = 0.0
	elif event is InputEventScreenDrag and event.index == staff_touch_index:
		if not staff_touch_dragging and staff_touch_start.distance_to(event.position) >= 9.0:
			staff_touch_dragging = true
		if staff_touch_dragging:
			staff_scroll.scroll_vertical = clampi(staff_scroll.scroll_vertical - roundi(event.relative.y), 0, _staff_max_scroll())
			staff_touch_velocity_y = event.velocity.y
			viewport.set_input_as_handled()
	elif event is InputEventMouseButton and not OS.has_feature("android"):
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP) and scroll_rect.has_point(event.position):
			var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			var target := clampi(staff_scroll.scroll_vertical + direction * 132, 0, _staff_max_scroll())
			_animate_staff_scroll(target, 0.22)
			viewport.set_input_as_handled()


func _staff_max_scroll() -> int:
	if not is_instance_valid(staff_scroll):
		return 0
	var bar := staff_scroll.get_v_scroll_bar()
	return maxi(0, roundi(bar.max_value - bar.page))


func _animate_staff_scroll(target: int, duration: float) -> void:
	if not is_instance_valid(staff_scroll):
		return
	if is_instance_valid(staff_scroll_tween) and staff_scroll_tween.is_running():
		staff_scroll_tween.kill()
	staff_scroll_tween = staff_scroll.create_tween()
	staff_scroll_tween.set_trans(Tween.TRANS_QUAD)
	staff_scroll_tween.set_ease(Tween.EASE_OUT)
	staff_scroll_tween.tween_property(staff_scroll, "scroll_vertical", target, duration)


func _build_market() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var compact := viewport_width < 900.0
	var stats := GridContainer.new()
	stats.columns = 1 if compact else 3
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 8)
	content.add_child(stats)
	_add_stat_card_to(stats, "AVAILABLE CANDIDATES", "%d / 50" % candidates.size(), "The candidate market refreshes every in-game month")
	_add_stat_card_to(stats, "OPEN POSITIONS", str(maxi(0, capacity - employees.size())), "Based on your HQ hiring capacity")
	_add_stat_card_to(stats, "MONTHLY PAYROLL", _money(_total_payroll()), "Current salary commitment")

	var filter_panel := _card()
	var filter_margin := _margin(filter_panel, 14, 14, 10, 10)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 12)
	filter_margin.add_child(filter_row)
	var filter_label := _label("DEPARTMENT", 12, WHITE)
	filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(filter_label)
	var filter := OptionButton.new()
	filter.add_item("All Departments")
	for department in DEPARTMENTS:
		filter.add_item(department)
	filter.custom_minimum_size = Vector2(175 if compact else 220, 44)
	filter.add_theme_font_size_override("font_size", 16)
	_style_option_button(filter)
	filter.item_selected.connect(func(index: int):
		market_filter = "All Departments" if index == 0 else DEPARTMENTS[index - 1]
		_build()
	)
	for i in range(filter.item_count):
		if filter.get_item_text(i) == market_filter:
			filter.select(i)
	filter_row.add_child(filter)
	content.add_child(filter_panel)

	var list_heading := _label("AVAILABLE CANDIDATES", 20 if compact else 22, WHITE)
	content.add_child(list_heading)
	var candidate_list := GridContainer.new()
	candidate_list.name = "Staff_Candidate_Grid"
	candidate_list.columns = 2
	candidate_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_list.add_theme_constant_override("h_separation", 12)
	candidate_list.add_theme_constant_override("v_separation", 12)
	content.add_child(candidate_list)
	var visible_count := 0
	for candidate in candidates:
		if market_filter != "All Departments" and str(candidate.get("department", "")) != market_filter:
			continue
		candidate_list.add_child(_candidate_card(candidate))
		visible_count += 1
	if visible_count == 0:
		candidate_list.add_child(_glass_card_message("NO MATCHING CANDIDATES", "Try another department filter to see more people."))



func _candidate_card(candidate: Dictionary) -> Control:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var card := _card()
	card.custom_minimum_size = Vector2(0, 420 if compact else 390)
	var margin := _margin(card, 10, 10, 11, 11)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 11)
	margin.add_child(stack)
	stack.add_child(_label(str(candidate.get("full_name", "Candidate")).to_upper(), 18 if compact else 20, WHITE))
	stack.add_child(_label(str(candidate.get("position", "Specialist")).to_upper(), 13, Color("#b9eaff")))
	stack.add_child(_label("COUNTRY  " + str(candidate.get("country", "International")).to_upper(), 11, Color("#c7e2f3")))
	stack.add_child(_label(str(candidate.get("rarity", "STANDARD")).to_upper(), 12, Color("#d5f2ff")))
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator_color", Color(0.72, 0.91, 1.0, 0.42))
	stack.add_child(divider)
	stack.add_child(_label("DEPARTMENT  " + str(candidate.get("department", "Unassigned")).to_upper(), 12, WHITE))
	stack.add_child(_label("AGE  %d YEARS   /   EXPERIENCE  %s YEARS" % [int(candidate.get("age", 0)), str(candidate.get("experience", 0))], 12, MUTED))
	var metrics := GridContainer.new()
	metrics.columns = 2 if compact else 3
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 6)
	metrics.add_theme_constant_override("v_separation", 6)
	stack.add_child(metrics)
	_add_metric(metrics, "ABILITY", int(candidate.get("ability", 0)))
	_add_metric(metrics, "EFFICIENCY", int(candidate.get("efficiency", 0)))
	stack.add_child(_label("EDUCATION  " + str(candidate.get("education", "—")), 12, MUTED))
	stack.add_child(_label("MONTHLY SALARY", 12, Color("#a9e3ff")))
	stack.add_child(_label(_money(float(candidate.get("monthly_salary", 0.0))), 21, WHITE))
	var hire := _button("HIRE CANDIDATE", true)
	hire.custom_minimum_size.y = 48
	hire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire.disabled = employees.size() >= capacity
	hire.pressed.connect(func(): hire_requested.emit(str(candidate.get("id", ""))))
	stack.add_child(hire)
	if employees.size() >= capacity:
		stack.add_child(_label("HQ CAPACITY REACHED", 12, Color("#ffd0b8")))
	return card

func _build_management() -> void:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var stats := GridContainer.new()
	stats.columns = 1 if compact else 2
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 8)
	content.add_child(stats)
	_add_stat_card_to(stats, "TEAM SIZE", "%d / %d" % [employees.size(), capacity], "Employees on your company roster")
	_add_stat_card_to(stats, "MONTHLY PAYROLL", _money(_total_payroll()), "Total salary expense at monthly billing")
	content.add_child(_label("YOUR EMPLOYEES", 17 if compact else 19, WHITE))
	var employee_list := GridContainer.new()
	employee_list.name = "Staff_Employee_Grid"
	employee_list.columns = 2
	employee_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	employee_list.add_theme_constant_override("h_separation", 12)
	employee_list.add_theme_constant_override("v_separation", 12)
	content.add_child(employee_list)
	if employees.is_empty():
		employee_list.add_child(_glass_card_message("YOUR TEAM IS EMPTY", "Visit the Staff Market to recruit your first team members."))
	return
	for employee in employees:
		employee_list.add_child(_employee_card(employee))



func _employee_card(employee: Dictionary) -> Control:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var card := _card()
	card.custom_minimum_size = Vector2(0, 450 if compact else 420)
	var margin := _margin(card, 10, 10, 11, 11)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	stack.add_child(_label(str(employee.get("full_name", "Employee")).to_upper(), 18 if compact else 20, WHITE))
	stack.add_child(_label(str(employee.get("position", "Staff")).to_upper(), 13, Color("#b9eaff")))
	stack.add_child(_label("COUNTRY  " + str(employee.get("country", "International")).to_upper(), 11, Color("#c7e2f3")))
	stack.add_child(_label("DEPARTMENT  " + str(employee.get("department", "UNASSIGNED")).to_upper(), 12, WHITE))
	stack.add_child(_label("AGE  %d YEARS   /   EXPERIENCE  %s YEARS" % [int(employee.get("age", 0)), str(employee.get("experience", 0))], 12, MUTED))
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator_color", Color(0.72, 0.91, 1.0, 0.42))
	stack.add_child(divider)
	var metrics := GridContainer.new()
	metrics.columns = 2 if compact else 3
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 6)
	metrics.add_theme_constant_override("v_separation", 6)
	stack.add_child(metrics)
	_add_metric(metrics, "ABILITY", int(employee.get("ability", 0)))
	_add_metric(metrics, "EFFICIENCY", int(employee.get("efficiency", 0)))
	_add_metric(metrics, "EXPERIENCE", int(employee.get("experience", 0)))
	stack.add_child(_label("MONTHLY SALARY", 12, Color("#a9e3ff")))
	stack.add_child(_label(_money(float(employee.get("monthly_salary", 0.0))), 21, WHITE))
	var assignment := OptionButton.new()
	for department in DEPARTMENTS:
		assignment.add_item(department)
	for i in range(assignment.item_count):
		if assignment.get_item_text(i) == str(employee.get("department", "")):
			assignment.select(i)
	assignment.custom_minimum_size.y = 46
	assignment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(assignment)
	assignment.item_selected.connect(func(index: int): assignment_requested.emit(str(employee.get("id", "")), DEPARTMENTS[index]))
	stack.add_child(assignment)
	var dismiss := _button("DISMISS", false)
	dismiss.custom_minimum_size.y = 46
	dismiss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dismiss.pressed.connect(func(): dismiss_requested.emit(str(employee.get("id", ""))))
	stack.add_child(dismiss)
	return card

func _add_stat_card(caption: String, value: String, detail: String) -> void:
	_add_stat_card_to(content, caption, value, detail)


func _add_stat_card_to(parent: Control, caption: String, value: String, detail: String) -> void:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _margin(card, 12, 12, 10, 10)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	stack.add_child(_label(caption, 10, Color("#a9e3ff")))
	stack.add_child(_label(value, 21, WHITE))
	stack.add_child(_label(detail, 9, MUTED))
	parent.add_child(card)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.66, 0.88, 0.27)
	style.border_color = Color(0.86, 0.97, 1.0, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.16, 0.34, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 5)
	style.anti_aliasing = true
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var glass_gradient := Gradient.new()
	glass_gradient.set_color(0, Color(0.92, 0.98, 1.0, 0.30))
	glass_gradient.set_color(1, Color(0.76, 0.91, 1.0, 0.0))
	var glass_texture := GradientTexture2D.new()
	glass_texture.gradient = glass_gradient
	glass_texture.fill_from = Vector2(0.0, 0.0)
	glass_texture.fill_to = Vector2(0.0, 1.0)
	var reflection := TextureRect.new()
	reflection.name = "Glass_Reflection"
	reflection.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	reflection.offset_bottom = 70.0
	reflection.texture = glass_texture
	reflection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reflection.stretch_mode = TextureRect.STRETCH_SCALE
	reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(reflection)
	return card


func _margin(parent: Control, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _add_metric(parent: GridContainer, caption: String, value: int) -> void:
	var metric := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.89, 0.98, 0.10)
	style.border_color = Color(0.72, 0.91, 1.0, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	metric.add_theme_stylebox_override("panel", style)
	metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var metric_stack := VBoxContainer.new()
	metric_stack.add_theme_constant_override("separation", 1)
	metric.add_child(metric_stack)
	metric_stack.add_child(_label(caption, 8, Color("#a9e3ff")))
	metric_stack.add_child(_label("%d / 100" % value, 11, WHITE))
	parent.add_child(metric)


func _glass_card_message(title_text: String, detail: String) -> Control:
	var card := _card()
	var margin := _margin(card, 18, 18, 16, 16)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	stack.add_child(_label(title_text, 14, WHITE))
	stack.add_child(_label(detail, 11, MUTED))
	return card


func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.60, 0.84, 0.96, 0.25) if primary else Color(0.72, 0.89, 0.98, 0.14)
		if state == "hover":
			style.bg_color = Color(0.76, 0.92, 1.0, 0.36)
		elif state == "pressed":
			style.bg_color = Color(0.35, 0.68, 0.88, 0.42)
		elif state == "disabled":
			style.bg_color = Color(0.35, 0.49, 0.59, 0.20)
		style.border_color = Color(0.91, 0.98, 1.0, 0.96)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.12, 0.28, 0.32)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _style_option_button(button: OptionButton) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.34, 0.68, 0.88, 0.24)
		if state == "hover":
			style.bg_color = Color(0.48, 0.78, 0.96, 0.34)
		elif state == "pressed":
			style.bg_color = Color(0.25, 0.58, 0.82, 0.42)
		style.border_color = Color(0.86, 0.97, 1.0, 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", maxi(roundi(float(size) * 1.18), 15))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _total_payroll() -> float:
	var total := 0.0
	for employee in employees:
		total += float(employee.get("monthly_salary", 0.0))
	return total


func _money(amount: float) -> String:
	return _format_money(roundi(amount))


func _format_money(amount: int) -> String:
	var digits := str(amount)
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits.substr(i, 1)
	return "$" + result
