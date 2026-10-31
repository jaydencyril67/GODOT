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
var content: VBoxContainer
var staff_scroll: ScrollContainer
var staff_scroll_tween: Tween
var staff_horizontal_tween: Tween
var staff_horizontal_rows: Array[ScrollContainer] = []
var staff_active_horizontal_scroll: ScrollContainer
var staff_touch_index := -1
var staff_touch_start := Vector2.ZERO
var staff_touch_dragging := false
var staff_touch_axis := ""
var staff_touch_velocity := Vector2.ZERO


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
	if is_instance_valid(staff_horizontal_tween) and staff_horizontal_tween.is_running():
		staff_horizontal_tween.kill()
	staff_horizontal_rows.clear()
	staff_active_horizontal_scroll = null
	staff_touch_index = -1
	staff_touch_dragging = false
	staff_touch_axis = ""
	staff_touch_velocity = Vector2.ZERO
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
	header.add_child(_label("DIGITALWORLD  /  STAFF", 11 if compact else 13, Color("#a9e3ff")))

	var hero_row := HBoxContainer.new()
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_theme_constant_override("separation", 12)
	header.add_child(hero_row)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(heading)
	var title_text := "STAFF MARKET" if mode == "market" else "MY STAFF"
	var title := _label(title_text, 27 if compact else 36, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label(company_name.to_upper() + "  /  AVAILABLE BALANCE  " + _money(company_balance), 11 if compact else 12, Color("#c7eaff")))
	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(104 if compact else 120, 46 if compact else 50)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.add_theme_font_size_override("font_size", 13 if compact else 14)
	_style_create_glass_button(back_button)
	back_button.pressed.connect(func(): back_requested.emit())
	hero_row.add_child(back_button)

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
				staff_touch_axis = ""
				staff_touch_velocity = Vector2.ZERO
				staff_active_horizontal_scroll = _staff_horizontal_scroll_at(event.position)
		else:
			if event.index == staff_touch_index:
				if staff_touch_dragging:
					if staff_touch_axis == "horizontal" and is_instance_valid(staff_active_horizontal_scroll):
						var horizontal_target := clampi(roundi(float(staff_active_horizontal_scroll.scroll_horizontal) - staff_touch_velocity.x * 0.10), 0, _staff_horizontal_max_scroll(staff_active_horizontal_scroll))
						_animate_staff_horizontal_scroll(staff_active_horizontal_scroll, horizontal_target, 0.24)
					elif staff_touch_axis == "vertical":
						var vertical_target := clampi(roundi(float(staff_scroll.scroll_vertical) - staff_touch_velocity.y * 0.10), 0, _staff_max_scroll())
						_animate_staff_scroll(vertical_target, 0.24)
					viewport.set_input_as_handled()
				staff_touch_index = -1
				staff_touch_dragging = false
				staff_touch_axis = ""
				staff_touch_velocity = Vector2.ZERO
				staff_active_horizontal_scroll = null

	elif event is InputEventScreenDrag and event.index == staff_touch_index:
		var drag_delta: Vector2 = event.position - staff_touch_start
		if staff_touch_axis == "" and drag_delta.length() >= 9.0:
			staff_touch_dragging = true
			if is_instance_valid(staff_active_horizontal_scroll) and absf(drag_delta.x) > absf(drag_delta.y):
				staff_touch_axis = "horizontal"
			else:
				staff_touch_axis = "vertical"
		if staff_touch_dragging:
			if staff_touch_axis == "horizontal" and is_instance_valid(staff_active_horizontal_scroll):
				staff_active_horizontal_scroll.scroll_horizontal = clampi(staff_active_horizontal_scroll.scroll_horizontal - roundi(event.relative.x), 0, _staff_horizontal_max_scroll(staff_active_horizontal_scroll))
			elif staff_touch_axis == "vertical":
				staff_scroll.scroll_vertical = clampi(staff_scroll.scroll_vertical - roundi(event.relative.y), 0, _staff_max_scroll())
			staff_touch_velocity = event.velocity
			viewport.set_input_as_handled()

	elif event is InputEventMouseButton and not OS.has_feature("android"):
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP) and scroll_rect.has_point(event.position):
			var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			var target := clampi(staff_scroll.scroll_vertical + direction * 132, 0, _staff_max_scroll())
			_animate_staff_scroll(target, 0.22)
			viewport.set_input_as_handled()


func _staff_horizontal_scroll_at(position: Vector2) -> ScrollContainer:
	for row in staff_horizontal_rows:
		if is_instance_valid(row) and row.get_global_rect().has_point(position):
			return row
	return null


func _staff_horizontal_max_scroll(row: ScrollContainer) -> int:
	if not is_instance_valid(row):
		return 0
	var bar := row.get_h_scroll_bar()
	return maxi(0, roundi(bar.max_value - bar.page))


func _animate_staff_horizontal_scroll(row: ScrollContainer, target: int, duration: float) -> void:
	if not is_instance_valid(row):
		return
	if is_instance_valid(staff_horizontal_tween) and staff_horizontal_tween.is_running():
		staff_horizontal_tween.kill()
	staff_horizontal_tween = row.create_tween()
	staff_horizontal_tween.set_trans(Tween.TRANS_QUAD)
	staff_horizontal_tween.set_ease(Tween.EASE_OUT)
	staff_horizontal_tween.tween_property(row, "scroll_horizontal", target, duration)


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
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	for department in DEPARTMENTS:
		_build_department_candidate_row(department, compact)


func _build_department_candidate_row(department: String, compact: bool) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	content.add_child(section)

	var heading := _label(department.to_upper(), 16 if compact else 18, Color("#b9eaff"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(heading)

	var horizontal_scroll := ScrollContainer.new()
	horizontal_scroll.name = "Market_" + department.replace(" ", "") + "_HorizontalRow"
	horizontal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll.custom_minimum_size.y = 366 if compact else 356
	horizontal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	horizontal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	horizontal_scroll.follow_focus = false
	horizontal_scroll.clip_contents = true
	section.add_child(horizontal_scroll)
	staff_horizontal_rows.append(horizontal_scroll)

	var candidate_row := HBoxContainer.new()
	candidate_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	candidate_row.add_theme_constant_override("separation", 10)
	horizontal_scroll.add_child(candidate_row)

	var department_count := 0
	var market_card_width := _market_candidate_card_width(compact)
	for candidate in candidates:
		if str(candidate.get("department", "")) != department:
			continue
		var candidate_card := _candidate_card(candidate)
		candidate_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		candidate_card.custom_minimum_size.x = market_card_width
		candidate_row.add_child(candidate_card)
		department_count += 1

	if department_count == 0:
		var empty_card := _glass_card_message("NO " + department.to_upper() + " CANDIDATES", "New candidates for this department will appear here.")
		empty_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		empty_card.custom_minimum_size = Vector2(market_card_width, 340 if compact else 330)
		candidate_row.add_child(empty_card)


func _market_candidate_card_width(compact: bool) -> float:
	# Show three complete candidate cards and part of the fourth at the
	# initial leftmost position, so users can immediately discover swiping.
	var viewport_width := get_viewport().get_visible_rect().size.x
	var page_margins := 36.0 if compact else 84.0
	var row_gap_allowance := 30.0
	return maxf(1.0, (viewport_width - page_margins - row_gap_allowance) / 3.5)


func _candidate_card(candidate: Dictionary) -> Control:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var card := _card()
	card.custom_minimum_size = Vector2(290 if compact else 320, 300 if compact else 290)
	var margin := _margin(card, 9, 9, 8, 8)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	stack.add_child(_label(str(candidate.get("full_name", "Candidate")).to_upper(), 18 if compact else 20, WHITE))
	stack.add_child(_label(str(candidate.get("position", "Specialist")).to_upper(), 13, Color("#b9eaff")))
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 8)
	stack.add_child(identity_row)
	var country_label := _label(str(candidate.get("country", "International")).to_upper(), 11, Color("#c7e2f3"))
	country_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(country_label)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator_color", Color(0.72, 0.91, 1.0, 0.42))
	stack.add_child(divider)
	stack.add_child(_label("DEPARTMENT  " + str(candidate.get("department", "Unassigned")).to_upper(), 12, WHITE))
	stack.add_child(_label("AGE  %d YEARS   /   EXPERIENCE  %s YEARS" % [int(candidate.get("age", 0)), str(candidate.get("experience", 0))], 12, MUTED))

	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("h_separation", 6)
	metrics.add_theme_constant_override("v_separation", 4)
	stack.add_child(metrics)
	_add_metric(metrics, "ABILITY", int(candidate.get("ability", 0)))
	_add_metric(metrics, "EFFICIENCY", int(candidate.get("efficiency", 0)))
	stack.add_child(_label("EDUCATION  " + str(candidate.get("education", "—")), 12, MUTED))

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	stack.add_child(action_row)
	var salary_stack := VBoxContainer.new()
	salary_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salary_stack.add_theme_constant_override("separation", 1)
	action_row.add_child(salary_stack)
	salary_stack.add_child(_label("MONTHLY SALARY", 12, Color("#a9e3ff")))
	salary_stack.add_child(_label(_money(float(candidate.get("monthly_salary", 0.0))), 21, WHITE))
	var hire := _button("HIRE", true)
	hire.custom_minimum_size = Vector2(104, 46)
	hire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hire.disabled = employees.size() >= capacity
	hire.pressed.connect(func(): hire_requested.emit(str(candidate.get("id", ""))))
	action_row.add_child(hire)
	if employees.size() >= capacity:
		stack.add_child(_label("HQ CAPACITY REACHED", 12, Color("#ffd0b8")))
	return card


func _build_management() -> void:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	content.add_child(_label("YOUR EMPLOYEES", 17 if compact else 19, WHITE))
	for department in DEPARTMENTS:
		_build_department_employee_row(department, compact)


func _build_department_employee_row(department: String, compact: bool) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 7)
	content.add_child(section)

	var heading := _label(department.to_upper(), 16 if compact else 18, Color("#b9eaff"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(heading)

	var horizontal_scroll := ScrollContainer.new()
	horizontal_scroll.name = "Staff_" + department.replace(" ", "") + "_HorizontalRow"
	horizontal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll.custom_minimum_size.y = 462 if compact else 432
	horizontal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	horizontal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	horizontal_scroll.follow_focus = false
	horizontal_scroll.clip_contents = true
	section.add_child(horizontal_scroll)
	staff_horizontal_rows.append(horizontal_scroll)

	var employee_row := HBoxContainer.new()
	employee_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	employee_row.add_theme_constant_override("separation", 12)
	horizontal_scroll.add_child(employee_row)

	var department_count := 0
	for employee in employees:
		if str(employee.get("department", "")) != department:
			continue
		var employee_card := _employee_card(employee)
		employee_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		employee_card.custom_minimum_size.x = 300 if compact else 340
		employee_row.add_child(employee_card)
		department_count += 1

	if department_count == 0:
		var empty_card := _glass_card_message("NO " + department.to_upper() + " STAFF", "Employees assigned to this department will appear here.")
		empty_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		empty_card.custom_minimum_size = Vector2(300 if compact else 340, 450 if compact else 420)
		employee_row.add_child(empty_card)



func _employee_card(employee: Dictionary) -> Control:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var card := _card()
	card.custom_minimum_size = Vector2(300 if compact else 340, 450 if compact else 420)
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


func _style_create_glass_button(button: Button) -> void:
	# Exact non-primary glass treatment used by Create Your Product.
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.72, 0.89, 0.98, 0.14)
		if state == "hover":
			style.bg_color = Color(0.76, 0.92, 1.0, 0.36)
		elif state == "pressed":
			style.bg_color = Color(0.35, 0.68, 0.88, 0.42)
		style.border_color = Color(0.91, 0.98, 1.0, 0.96)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.12, 0.28, 0.32)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))


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
