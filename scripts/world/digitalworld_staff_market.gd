extends Control

signal back_requested
signal headquarters_requested
signal hire_requested(candidate_id: String)
signal dismiss_requested(employee_id: String)
signal assignment_requested(employee_id: String, department: String)

const DEPARTMENTS := ["Development", "Research", "Marketing", "Finance", "Operations", "Human Resources"]
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


func open(screen_mode: String, candidate_data: Array, employee_data: Array, staff_capacity: int, business_name: String, balance: float) -> void:
	mode = screen_mode
	candidates = candidate_data.duplicate(true)
	employees = employee_data.duplicate(true)
	capacity = maxi(0, staff_capacity)
	company_name = business_name
	company_balance = balance
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var glow := ColorRect.new()
	glow.color = Color(0.035, 0.32, 0.52, 0.18)
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 0.36
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 16)
	outer.add_theme_constant_override("margin_right", 16)
	outer.add_theme_constant_override("margin_top", 12)
	outer.add_theme_constant_override("margin_bottom", 94)
	add_child(outer)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	outer.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	page.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var eyebrow := _label(company_name.to_upper() + "  /  OFFICE", 10, Color("#83d5ff"))
	heading.add_child(eyebrow)
	var title_text := "STAFF MARKET" if mode == "market" else ("STAFF MANAGEMENT" if mode == "management" else "OFFICE")
	heading.add_child(_label(title_text, 25, WHITE))
	var back := _button("BACK", false)
	back.custom_minimum_size = Vector2(78, 44)
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 7)
	page.add_child(tabs)
	_add_tab(tabs, "OFFICE", mode == "office", "office")
	_add_tab(tabs, "STAFF MARKET", mode == "market", "market")
	_add_tab(tabs, "MY STAFF", mode == "management", "management")
	_add_tab(tabs, "HEADQUARTERS", false, "headquarters")

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	if mode == "office":
		_build_office()
	elif mode == "market":
		_build_market()
	else:
		_build_management()


func _add_tab(parent: HBoxContainer, caption: String, active: bool, target: String) -> void:
	var button := _button(caption, active)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(func():
		if target == "headquarters":
			headquarters_requested.emit()
		else:
			mode = target
			_build()
	)
	parent.add_child(button)


func _build_office() -> void:
	content.add_child(_label("COMPANY WORKFORCE", 12, Color("#8bdcff")))
	content.add_child(_label("Manage your headquarters and build the team behind your company.", 15, WHITE))
	_add_stat_card("EMPLOYEES", "%d / %d" % [employees.size(), capacity], "Your current headquarters capacity")
	_add_stat_card("MARKET CANDIDATES", str(candidates.size()), "Available people waiting to be hired")
	_add_stat_card("MONTHLY PAYROLL", _money(_total_payroll()), "Current salary commitment")
	var market := _button("EXPLORE STAFF MARKET", true)
	market.custom_minimum_size.y = 58
	market.pressed.connect(func(): mode = "market"; _build())
	content.add_child(market)
	var team := _button("MANAGE MY STAFF", false)
	team.custom_minimum_size.y = 54
	team.pressed.connect(func(): mode = "management"; _build())
	content.add_child(team)
	var hq := _button("HEADQUARTERS BUILDINGS", false)
	hq.custom_minimum_size.y = 54
	hq.pressed.connect(func(): headquarters_requested.emit())
	content.add_child(hq)


func _build_market() -> void:
	_add_stat_card("AVAILABLE CANDIDATES", "%d / 50" % candidates.size(), "The market gradually replenishes after hires")
	_add_stat_card("OPEN POSITIONS", "%d" % maxi(0, capacity - employees.size()), "Based on your owned headquarters level")
	_add_stat_card("MONTHLY PAYROLL", _money(_total_payroll()), "Salary cost if all current employees are retained")
	var filter := OptionButton.new()
	filter.add_item("All Departments")
	for department in DEPARTMENTS:
		filter.add_item(department)
	filter.custom_minimum_size.y = 42
	filter.add_theme_font_size_override("font_size", 13)
	filter.item_selected.connect(func(index: int):
		market_filter = "All Departments" if index == 0 else DEPARTMENTS[index - 1]
		_build()
	)
	for i in range(filter.item_count):
		if filter.get_item_text(i) == market_filter:
			filter.select(i)
	content.add_child(filter)
	for candidate in candidates:
		if market_filter != "All Departments" and str(candidate.get("department", "")) != market_filter:
			continue
		content.add_child(_candidate_card(candidate))
	if content.get_child_count() <= 4:
		content.add_child(_label("No candidates match this department filter.", 14, MUTED))


func _candidate_card(candidate: Dictionary) -> Control:
	var card := _card()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)
	var top := HBoxContainer.new()
	stack.add_child(top)
	var name_stack := VBoxContainer.new()
	name_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_stack)
	name_stack.add_child(_label(str(candidate.get("full_name", "Candidate")), 17, WHITE))
	name_stack.add_child(_label("%s  •  %d years old  •  %s" % [candidate.get("gender", "Not specified"), int(candidate.get("age", 0)), candidate.get("department", "")], 11, MUTED))
	var tier := _label(str(candidate.get("rarity", "STANDARD")).to_upper(), 10, Color("#8bdcff"))
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(tier)
	stack.add_child(_label(str(candidate.get("position", "Specialist")) + "  |  " + str(candidate.get("experience", 0)) + " years experience", 12, Color("#c9e8f8")))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	stack.add_child(stats)
	stats.add_child(_label("ABILITY  %d/100" % int(candidate.get("ability", 0)), 11, WHITE))
	stats.add_child(_label("EFFICIENCY  %d/100" % int(candidate.get("efficiency", 0)), 11, WHITE))
	stats.add_child(_label("POTENTIAL  %d/100" % int(candidate.get("potential", 0)), 11, WHITE))
	stack.add_child(_label("Education: %s   •   Personality: %s" % [candidate.get("education", "—"), candidate.get("personality", "—")], 11, MUTED))
	stack.add_child(_label("Requested salary: %s / month" % _money(float(candidate.get("monthly_salary", 0.0))), 13, Color("#a8e8ff")))
	var hire := _button("HIRE CANDIDATE", true)
	hire.disabled = employees.size() >= capacity
	hire.custom_minimum_size.y = 44
	hire.pressed.connect(func(): hire_requested.emit(str(candidate.get("id", ""))))
	stack.add_child(hire)
	if employees.size() >= capacity:
		stack.add_child(_label("Headquarters capacity reached. Upgrade your office to hire more staff.", 10, Color("#ffc4a8")))
	return card


func _build_management() -> void:
	_add_stat_card("TEAM SIZE", "%d / %d" % [employees.size(), capacity], "Employees currently on your company roster")
	_add_stat_card("MONTHLY PAYROLL", _money(_total_payroll()), "Total salary expense at the next monthly billing")
	if employees.is_empty():
		content.add_child(_label("Your company has no employees yet. Visit the Staff Market to recruit your first team members.", 14, MUTED))
	for employee in employees:
		content.add_child(_employee_card(employee))


func _employee_card(employee: Dictionary) -> Control:
	var card := _card()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)
	stack.add_child(_label(str(employee.get("full_name", "Employee")), 17, WHITE))
	stack.add_child(_label("%s  •  %s  •  %d years old" % [employee.get("position", "Staff"), employee.get("department", "Unassigned"), int(employee.get("age", 0))], 11, MUTED))
	stack.add_child(_label("Ability %d  |  Efficiency %d  |  Experience %d years" % [int(employee.get("ability", 0)), int(employee.get("efficiency", 0)), int(employee.get("experience", 0))], 12, WHITE))
	stack.add_child(_label("Monthly salary: %s" % _money(float(employee.get("monthly_salary", 0.0))), 12, Color("#a8e8ff")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)
	var assignment := OptionButton.new()
	for department in DEPARTMENTS:
		assignment.add_item(department)
	for i in range(assignment.item_count):
		if assignment.get_item_text(i) == str(employee.get("department", "")):
			assignment.select(i)
	assignment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assignment.item_selected.connect(func(index: int): assignment_requested.emit(str(employee.get("id", "")), DEPARTMENTS[index]))
	row.add_child(assignment)
	var dismiss := _button("DISMISS", false)
	dismiss.pressed.connect(func(): dismiss_requested.emit(str(employee.get("id", ""))))
	row.add_child(dismiss)
	return card


func _add_stat_card(caption: String, value: String, detail: String) -> void:
	var card := _card()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	card.add_child(stack)
	stack.add_child(_label(caption, 10, Color("#8bdcff")))
	stack.add_child(_label(value, 22, WHITE))
	stack.add_child(_label(detail, 10, MUTED))
	content.add_child(card)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card


func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#167eb5") if primary else Color(0.24, 0.48, 0.64, 0.56)
		if state == "hover":
			style.bg_color = Color("#279ed4")
		elif state == "pressed":
			style.bg_color = Color("#0c5c91")
		elif state == "disabled":
			style.bg_color = Color(0.20, 0.29, 0.35, 0.55)
		style.border_color = Color(0.72, 0.91, 1.0, 0.88)
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _total_payroll() -> float:
	var total := 0.0
	for employee in employees:
		total += float(employee.get("monthly_salary", 0.0))
	return total


func _money(amount: float) -> String:
	return "$" + String.num_int64(roundi(amount)).reverse().substr(0, 0) if false else _format_money(roundi(amount))


func _format_money(amount: int) -> String:
	var digits := str(amount)
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits.substr(i, 1)
	return "$" + result
