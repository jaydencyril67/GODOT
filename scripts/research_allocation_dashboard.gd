extends Control

signal back_requested
signal strategy_changed(strategy: Dictionary)
signal component_priority_changed(component: String, priority: String)

const DEPARTMENTS := ["Hardware", "Software", "Extras"]
const COMPONENTS := [
	"Battery", "Display", "Processor", "Front Camera", "Rear Camera",
	"Charging System", "Wi-Fi", "Bluetooth", "Mobile Internet", "RAM",
	"Internal Storage", "Cooling System", "Phone Case", "Protection Glass",
	"Power Bank", "Charger", "Wireless Earbuds", "Smartwatch"
]
const PRIORITY_LEVELS := ["Low", "Normal", "High", "Very High"]

var company_name := "Your Company"
var research_points := 0
var strategy: Dictionary = {"Hardware": 60, "Software": 30, "Extras": 10}
var component_priorities: Dictionary = {}
var research_history: Array = []
var strategy_sliders: Dictionary = {}
var strategy_value_labels: Dictionary = {}
var priority_component_picker: OptionButton
var priority_level_picker: OptionButton
var priority_rows: VBoxContainer
var history_overlay: Control
var history_list: VBoxContainer
var _updating_strategy := false

const TEXT_MAIN := Color("#f0f5f1")
const TEXT_MUTED := Color("#9eafa4")
const ACCENT := Color("#9bd6a7")
const PANEL := Color(0.025, 0.055, 0.041, 0.96)
const PANEL_BORDER := Color(0.25, 0.43, 0.31, 0.85)

func configure(data: Dictionary) -> void:
	company_name = str(data.get("company_name", "Your Company"))
	research_points = maxi(0, int(data.get("research_points", 0)))
	var incoming_strategy: Dictionary = data.get("research_strategy", {})
	for department in DEPARTMENTS:
		strategy[department] = clampi(int(incoming_strategy.get(department, strategy[department])), 0, 100)
	_normalize_loaded_strategy()
	component_priorities = data.get("research_component_priorities", {}).duplicate(true)
	research_history = data.get("research_history", []).duplicate(true)

func _ready() -> void:
	_build_dashboard()

func _build_dashboard() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 900.0 or viewport_size.y < 520.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "ResearchDashboardBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#070b0a")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var frame := MarginContainer.new()
	frame.name = "ResearchDashboardFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 12 if compact else 30)
	frame.add_theme_constant_override("margin_right", 12 if compact else 30)
	frame.add_theme_constant_override("margin_top", 8 if compact else 18)
	frame.add_theme_constant_override("margin_bottom", 8 if compact else 18)
	add_child(frame)

	var page := VBoxContainer.new()
	page.name = "CompanyResearchAllocationDashboard"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8 if compact else 14)
	frame.add_child(page)

	var header := HBoxContainer.new()
	header.name = "ResearchDashboardHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	page.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)
	var eyebrow := _label("COMPANY RESEARCH  /  STRATEGY", 9 if compact else 11, ACCENT)
	title_stack.add_child(eyebrow)
	var title := _label("Research Allocation", 19 if compact else 28, TEXT_MAIN)
	title_stack.add_child(title)

	var points_label := _label("RP  %s" % _format_number(research_points), 11 if compact else 13, Color("#c7eacb"))
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(points_label)

	var history_button := _button("RECENT RESEARCH", compact, false)
	history_button.pressed.connect(_show_history)
	header.add_child(history_button)

	var back_button := _button("BACK  ‹", compact, false)
	back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(back_button)

	var body := HBoxContainer.new()
	body.name = "ResearchDashboardBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8 if compact else 14)
	page.add_child(body)

	var strategy_card := _panel()
	strategy_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strategy_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(strategy_card)
	var strategy_content := VBoxContainer.new()
	strategy_content.add_theme_constant_override("separation", 5 if compact else 9)
	strategy_card.add_child(_padded(strategy_content, compact))
	strategy_content.add_child(_label("01  /  COMPANY STRATEGY", 9 if compact else 11, ACCENT))
	strategy_content.add_child(_label("Set your research investment", 13 if compact else 17, TEXT_MAIN))
	var strategy_note := _label("These department shares must always total 100%.", 9 if compact else 11, TEXT_MUTED)
	strategy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strategy_content.add_child(strategy_note)
	for department in DEPARTMENTS:
		_add_strategy_row(strategy_content, department, compact)
	var total_row := HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 4)
	strategy_content.add_child(total_row)
	total_row.add_child(_label("TOTAL ALLOCATION", 9 if compact else 10, TEXT_MUTED))
	var total_spacer := Control.new()
	total_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_spacer)
	var total_label := _label("100%", 12 if compact else 14, ACCENT)
	total_label.name = "StrategyTotalLabel"
	total_row.add_child(total_label)

	var priority_card := _panel()
	priority_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	priority_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(priority_card)
	var priority_content := VBoxContainer.new()
	priority_content.add_theme_constant_override("separation", 5 if compact else 9)
	priority_card.add_child(_padded(priority_content, compact))
	priority_content.add_child(_label("02  /  COMPONENT PRIORITIES", 9 if compact else 11, ACCENT))
	priority_content.add_child(_label("Spotlight important technology", 13 if compact else 17, TEXT_MAIN))
	var priority_note := _label("Give a component more attention without splitting department percentages. Other components keep researching.", 9 if compact else 11, TEXT_MUTED)
	priority_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	priority_content.add_child(priority_note)

	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 6)
	priority_content.add_child(selector_row)
	priority_component_picker = OptionButton.new()
	priority_component_picker.name = "PriorityComponentPicker"
	priority_component_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for component in COMPONENTS:
		priority_component_picker.add_item(component)
	selector_row.add_child(priority_component_picker)
	priority_level_picker = OptionButton.new()
	priority_level_picker.name = "PriorityLevelPicker"
	priority_level_picker.custom_minimum_size.x = 112 if compact else 142
	for level in PRIORITY_LEVELS:
		priority_level_picker.add_item(level)
	selector_row.add_child(priority_level_picker)
	var apply_button := _button("SET PRIORITY", compact, true)
	apply_button.pressed.connect(_apply_component_priority)
	priority_content.add_child(apply_button)

	var priority_caption := _label("ACTIVE FOCUS", 9 if compact else 10, TEXT_MUTED)
	priority_content.add_child(priority_caption)
	priority_rows = VBoxContainer.new()
	priority_rows.name = "ActiveComponentPriorities"
	priority_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	priority_rows.add_theme_constant_override("separation", 3)
	priority_content.add_child(priority_rows)
	_refresh_priority_rows()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	page.add_child(footer)
	var company_label := _label(company_name.to_upper(), 9 if compact else 10, TEXT_MUTED)
	company_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(company_label)
	var info_label := _label("RESEARCHERS DISCOVER  •  YOU SET THE DIRECTION", 8 if compact else 10, ACCENT)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(info_label)

func _add_strategy_row(parent: VBoxContainer, department: String, compact: bool) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	parent.add_child(row)
	var heading := HBoxContainer.new()
	row.add_child(heading)
	var name_label := _label(department, 10 if compact else 12, TEXT_MAIN)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)
	var value_label := _label("%d%%" % int(strategy[department]), 10 if compact else 12, ACCENT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(value_label)
	strategy_value_labels[department] = value_label
	var slider := HSlider.new()
	slider.name = department + "AllocationSlider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = int(strategy[department])
	slider.custom_minimum_size.y = 18 if compact else 24
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_strategy_slider_changed.bind(department))
	row.add_child(slider)
	strategy_sliders[department] = slider

func _on_strategy_slider_changed(value: float, changed_department: String) -> void:
	if _updating_strategy:
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
		var slider: HSlider = strategy_sliders[department]
		slider.set_value_no_signal(float(strategy[department]))
		var value_label: Label = strategy_value_labels[department]
		value_label.text = "%d%%" % int(strategy[department])
	_updating_strategy = false
	strategy_changed.emit(strategy.duplicate(true))

func _apply_component_priority() -> void:
	var component := priority_component_picker.get_item_text(priority_component_picker.selected)
	var priority := priority_level_picker.get_item_text(priority_level_picker.selected)
	component_priorities[component] = priority
	_refresh_priority_rows()
	component_priority_changed.emit(component, priority)

func _refresh_priority_rows() -> void:
	if not is_instance_valid(priority_rows):
		return
	for child in priority_rows.get_children():
		child.queue_free()
	var active: Array[String] = []
	for component in component_priorities:
		var priority := str(component_priorities[component])
		if priority != "Normal":
			active.append(str(component))
	active.sort()
	if active.is_empty():
		var empty := _label("No special focus set. All components remain active at normal priority.", 9, TEXT_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		priority_rows.add_child(empty)
		return
	for component in active.slice(0, 4):
		var row := HBoxContainer.new()
		priority_rows.add_child(row)
		var component_label := _label(component, 9, TEXT_MAIN)
		component_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(component_label)
		row.add_child(_label(str(component_priorities[component]).to_upper(), 9, ACCENT))

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
	var card := _panel()
	card.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 28.0, 680.0), minf(get_viewport_rect().size.y - 28.0, 440.0))
	centre.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(_padded(content, true))
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label("RECENT RESEARCH", 16, TEXT_MAIN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("CLOSE  ×", true, false)
	close.pressed.connect(func(): history_overlay.queue_free(); history_overlay = null)
	header.add_child(close)
	var hint := _label("Completed discoveries and research milestones will appear here.", 10, TEXT_MUTED)
	content.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	history_list = VBoxContainer.new()
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
	style.set_corner_radius_all(12)
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

func _button(value: String, compact: bool, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(96 if compact else 138, 32 if compact else 42)
	button.add_theme_font_size_override("font_size", 9 if compact else 11)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#23452f") if primary else Color("#111d17")
	normal.border_color = Color("#80bd8b") if primary else PANEL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("#315b3d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	return button

func _format_number(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return formatted
