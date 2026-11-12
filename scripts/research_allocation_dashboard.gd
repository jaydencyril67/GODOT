extends Control

signal back_requested
signal project_commission_requested(request: Dictionary)
signal project_approve_requested(project_id: String, results: Array)
signal project_retry_requested(project_id: String)
signal project_cancel_requested(project_id: String)

const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")

const TEXT_MAIN := Color("#EEE9DF")
const TEXT_MUTED := Color("#AAA49A")
const ACCENT := Color("#C58A3A")
const SUCCESS := Color("#7FA88A")
const INFO := Color("#A7A49D")
const ORANGE := Color("#ffb45c")

const COMPONENT_LABELS := ["Screen Tech", "RAM Tech", "RAM", "Internal Storage", "Phone Thickness", "Border Radius", "Charge Port", "Home Button", "Speakers", "Speaker Quality", "Front Camera", "Mobile Network", "Wi-Fi", "Bluetooth", "Screen Width", "Screen Height", "Refresh Rate", "Cooling System", "Phone Type", "Memory Clock", "Curve Horizontal", "Curve Vertical", "Curve Both", "Battery Capacity", "Power Bank", "Charging Speed", "Wireless Charge", "Fingerprint", "Face ID", "NFC", "Accelerometer", "Gyroscope", "Proximity", "Ambient Light", "Magnetometer", "Barometer", "GNSS / GPS", "Front Camera MP", "Rear Camera MP", "Rear Camera Count", "Rear Flash Count", "Back Raised Design", "Device Color", "Side Button", "Sound Button", "Style Pen", "Button Length", "Power Position", "Volume Position", "Phone Case", "Protection Glass", "Smartwatch", "Wireless Earbuds", "Box Package", "Charger"]
const COMPONENT_VALUES := ["Screen Technology", "RAM Technology", "RAM", "Internal Storage", "Phone Thickness", "Border Radius", "Charge Port", "Home Button", "Speakers", "Speaker Quality", "Front Camera", "Mobile Network", "Wi-Fi", "Bluetooth", "Screen Width", "Screen Height", "Refresh Rate", "Cooling System Design", "Phone Type", "Memory Clock", "Curved Screen Horizontal", "Curved Screen Vertical", "Curved Screen Both", "Battery Capacity", "Power Bank", "Charging Speed", "Wireless Charging", "Fingerprint Sensor", "Face Recognition / Face ID", "NFC Controller", "Accelerometer", "Gyroscope", "Proximity Sensor", "Ambient Light Sensor", "Magnetometer / Compass", "Barometer", "GNSS / GPS Receiver", "Front Camera MP", "Rear Camera MP", "Rear Camera Count", "Rear Flash Count", "Back Raised Design", "Device Color", "Side Button", "Sound Button", "Style Pen (S Pen)", "Power/Volume Button Length", "Power Button Position", "Volume Button Position", "Phone Case", "Protection Glass", "Smartwatch", "Wireless Earbuds", "Box Package", "Charger"]

var company_balance := 0.0
var staff_employees: Array = []
var research_projects: Array = []
var research_technologies: Dictionary = {}
var research_component_levels: Dictionary = {}
var research_history: Array = []

var page_root: VBoxContainer
var body: MarginContainer
var body_content: VBoxContainer
var capital_value_label: Label
var company_name := "YOUR COMPANY"
var selected_component_index := 0
var component_buttons: Array[Button] = []
var component_page_grids: Array[GridContainer] = []
var component_page_index := 0
var component_page_indicator: Label
var component_page_previous: Button
var component_page_next: Button
var component_page_viewport: Control
var component_swipe_start := Vector2.ZERO
var component_swipe_active := false
var staff_page_grids: Array[GridContainer] = []
var staff_page_index := 0
var staff_page_indicator: Label
var staff_page_previous: Button
var staff_page_next: Button
var staff_page_viewport: Control
var staff_swipe_start := Vector2.ZERO
var staff_swipe_active := false
var estimate_label: Label
var start_button: Button
var assigned_staff_ids: Array[String] = []
var rendered_project_signature := ""
var frame_container: MarginContainer
var top_bar_grid: GridContainer

var active_project_id := ""
var creation_mode := false
var creation_step := 1
var ui_scale := 1.0
var _last_layout_key := ""
var existing_pop_alert: Node
var game_date_unix := 0.0


func configure(data: Dictionary, pop_alert: Node = null) -> void:
	# A data-only refresh must not discard the alert instance supplied at creation.
	# Otherwise the first completed action breaks every later findings popup.
	if pop_alert != null:
		existing_pop_alert = pop_alert
	game_date_unix = float(data.get("game_date_unix", game_date_unix))
	company_name = str(data.get("company_name", "Your Company"))
	company_balance = maxf(0.0, float(data.get("balance", 0.0)))
	if is_instance_valid(capital_value_label):
		capital_value_label.text = _format_currency(company_balance)
	staff_employees = data.get("staff_employees", []).duplicate(true)
	research_projects = data.get("research_projects", []).duplicate(true)
	research_technologies = data.get("research_technologies", {}).duplicate(true)
	research_component_levels = data.get("research_component_levels", {}).duplicate(true)
	research_history = data.get("research_history", []).duplicate(true)
	if is_node_ready():
		_render_scene()


func _ready() -> void:
	ui_scale = _calculate_ui_scale()
	_last_layout_key = _get_layout_key()
	resized.connect(_on_dashboard_resized)
	_build_shell()
	_apply_shell_layout()
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
	return "%d:%.2f:%d:%d" % [
		1 if viewport_size.x < viewport_size.y * 1.25 else 0,
		_calculate_ui_scale(),
		_responsive_grid_columns(190.0, 4),
		_responsive_grid_columns(190.0, 4)
	]


func _on_dashboard_resized() -> void:
	ui_scale = _calculate_ui_scale()
	var next_key := _get_layout_key()
	_apply_shell_layout()
	if next_key == _last_layout_key:
		return
	_last_layout_key = next_key
	_render_scene()


func _responsive_grid_columns(minimum_cell_width: float, maximum_columns: int) -> int:
	var viewport_width := get_viewport_rect().size.x
	var horizontal_insets := _scaled(52.0)
	var gap := _scaled(12.0)
	var available_width := maxf(1.0, viewport_width - horizontal_insets)
	var cell_width := maxf(1.0, _scaled(minimum_cell_width))
	return clampi(floori((available_width + gap) / (cell_width + gap)), 1, maximum_columns)


func _apply_shell_layout() -> void:
	var narrow := _is_narrow_layout()
	if is_instance_valid(frame_container):
		var horizontal_margin := roundi(_scaled(12.0 if narrow else 22.0))
		var vertical_margin := roundi(_scaled(10.0 if narrow else 16.0))
		frame_container.add_theme_constant_override("margin_left", horizontal_margin)
		frame_container.add_theme_constant_override("margin_right", horizontal_margin)
		frame_container.add_theme_constant_override("margin_top", vertical_margin)
		frame_container.add_theme_constant_override("margin_bottom", vertical_margin)
	if is_instance_valid(top_bar_grid):
		top_bar_grid.columns = 1 if narrow else 3
		top_bar_grid.add_theme_constant_override("h_separation", roundi(_scaled(12.0 if narrow else 18.0)))
		top_bar_grid.add_theme_constant_override("v_separation", roundi(_scaled(8.0)))
	if is_instance_valid(page_root):
		page_root.add_theme_constant_override("separation", roundi(_scaled(10.0)))


func _scaled(value: float) -> float:
	return maxf(1.0, value * ui_scale)


func _scaled_font(value: int) -> int:
	return maxi(9, roundi(float(value) * ui_scale))


func _is_narrow_layout() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x < viewport_size.y * 1.25


func _needs_vertical_scroll() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x < viewport_size.y * 1.25


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

	frame_container = MarginContainer.new()
	frame_container.name = "ResearchManagementFrame"
	frame_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame_container)

	page_root = VBoxContainer.new()
	page_root.name = "ResearchManagementPage"
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_container.add_child(page_root)

	top_bar_grid = GridContainer.new()
	top_bar_grid.name = "ResearchTopBar"
	top_bar_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	page_root.add_child(top_bar_grid)

	var back := _button("‹  BACK", false, TEXT_MAIN)
	back.custom_minimum_size = Vector2(_scaled(116.0), _scaled(48.0))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_requested.emit())
	top_bar_grid.add_child(back)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 1)
	top_bar_grid.add_child(title_stack)

	var section_title := _label("RESEARCH & DEVELOPMENT", 20, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	section_title.add_theme_font_size_override("font_size", _scaled_font(20))
	section_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(section_title)

	var capital_stack := VBoxContainer.new()
	capital_stack.custom_minimum_size.x = _scaled(190.0)
	capital_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capital_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	capital_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	capital_stack.add_theme_constant_override("separation", 1)
	top_bar_grid.add_child(capital_stack)
	var capital_caption := _label("AVAILABLE CAPITAL", 10, TEXT_MUTED)
	capital_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capital_caption.custom_minimum_size.x = _scaled(180.0)
	capital_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	capital_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capital_stack.add_child(capital_caption)
	capital_value_label = _label(_format_currency(company_balance), 17, ACCENT)
	capital_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capital_value_label.custom_minimum_size.x = _scaled(180.0)
	capital_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	capital_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	component_buttons.clear()

	if creation_mode:
		if creation_step == 1:
			_build_component_selection_scene()
		else:
			_build_staff_selection_scene()
		return


	var active_projects := _get_active_projects()
	var pending_projects := _get_pending_validation_projects()
	if not active_projects.is_empty() or not pending_projects.is_empty():
		_build_active_research(active_projects, pending_projects)
	else:
		_build_empty_scene()

func _build_empty_scene() -> void:
	body_content = _new_screen_root()
	_mount_screen_root(body_content)

	var center := CenterContainer.new()
	center.name = "NoActiveContractCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_content.add_child(center)

	var empty_state := VBoxContainer.new()
	empty_state.name = "NoActiveContractContent"
	empty_state.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	empty_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	empty_state.add_theme_constant_override("separation", roundi(_scaled(22.0)))
	center.add_child(empty_state)

	var status := _label("NO ACTIVE CONTRACT", 26, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	status.add_theme_font_size_override("font_size", _scaled_font(26))
	status.custom_minimum_size.x = _scaled(320.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status_font := FontVariation.new()
	status_font.base_font = status.get_theme_font("font")
	status_font.variation_embolden = 0.8
	status.add_theme_font_override("font", status_font)
	empty_state.add_child(status)

	var create := _button("CREATE NEW", true, ACCENT)
	create.name = "CreateResearchButton"
	create.custom_minimum_size = Vector2(_scaled(300.0), _scaled(64.0))
	create.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(_open_creation_scene)
	empty_state.add_child(create)

func _get_pending_validation_projects() -> Array[Dictionary]:
	var pending_projects: Array[Dictionary] = []
	# Newest completed projects appear first for technical review.
	for index in range(research_projects.size() - 1, -1, -1):
		var project_value: Variant = research_projects[index]
		if project_value is Dictionary and str(project_value.get("status", "")) in [ResearchManagerScript.STATUS_AWAITING_VALIDATION, ResearchManagerScript.STATUS_UNSUCCESSFUL]:
			pending_projects.append(project_value)
	return pending_projects


func _find_research_project(project_id: String) -> Dictionary:
	for project_value in research_projects:
		if project_value is Dictionary and str(project_value.get("id", "")) == project_id:
			return project_value
	return {}


func open_validation_review(project_id: String) -> void:
	var project := _find_research_project(project_id)
	if project.is_empty():
		return
	var status := str(project.get("status", ""))
	if status not in [ResearchManagerScript.STATUS_AWAITING_VALIDATION, ResearchManagerScript.STATUS_UNSUCCESSFUL]:
		return
	var components: Array = project.get("components", [project.get("component", "Research")])
	var component_lines := PackedStringArray()
	for component_value in components:
		component_lines.append("• " + str(component_value))
	var successful := status == ResearchManagerScript.STATUS_AWAITING_VALIDATION
	var details := VBoxContainer.new()
	details.name = "ResearchFindingsSummary"
	details.add_theme_constant_override("separation", 12)
	details.add_child(_label("COMPONENTS INVESTIGATED", 12, TEXT_MUTED))
	var component_label := _label("\\n".join(component_lines), 17, TEXT_MAIN)
	component_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(component_label)
	details.add_child(_label("RESEARCH RESULT", 12, TEXT_MUTED))
	var result_label := _label("SUCCESS" if successful else "FAILED", 24, SUCCESS if successful else ORANGE)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(result_label)
	if is_instance_valid(existing_pop_alert):
		var action_text := "APPROVE" if successful else "RETRY"
		var action := Callable(self, "_request_findings_approval").bind(project_id) if successful else Callable(self, "_request_research_retry").bind(project_id)
		existing_pop_alert.call("show_custom_prompt", "RESEARCH FINDINGS", "", details, action_text, action)


func _request_findings_approval(project_id: String) -> void:
	var project := _find_research_project(project_id)
	if project.is_empty() or str(project.get("status", "")) != ResearchManagerScript.STATUS_AWAITING_VALIDATION:
		return
	var component := str(project.get("component", "Research"))
	var result := {
		"component": component,
		"metric": _default_validation_metric(component),
		"value": str(project.get("research_target", "")).strip_edges() if not str(project.get("research_target", "")).strip_edges().is_empty() else "Research completed successfully"
	}
	project_approve_requested.emit(project_id, [result])


func _request_research_retry(project_id: String) -> void:
	var project := _find_research_project(project_id)
	if project.is_empty() or str(project.get("status", "")) != ResearchManagerScript.STATUS_UNSUCCESSFUL:
		return
	project_retry_requested.emit(project_id)


func _default_validation_metric(component: String) -> String:
	if ResearchManagerScript.PHONE_SENSOR_COMPONENTS.has(component):
		return "Sensor functionality and integration"
	if ResearchManagerScript.SIDE_BUTTON_COMPONENTS.has(component):
		return "Physical side-feature functionality and integration"
	if component == ResearchManagerScript.POWER_VOLUME_BUTTON_LENGTH_COMPONENT:
		return "Minimum power and volume button length"
	if ResearchManagerScript.POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(component):
		return "Available button edge placements"
	match component:
		"Charging Speed":
			return "Maximum wired charging speed"
		"Wireless Charging":
			return "Maximum wireless charging speed"
		"Front Camera MP":
			return "Maximum front camera resolution"
		"Rear Camera MP":
			return "Maximum rear camera resolution"
		"Rear Camera Count":
			return "Maximum number of rear cameras"
		"Rear Flash Count":
			return "Maximum number of rear flashes"
		"Back Raised Design":
			return "Maximum number of raised back-design boxes"
		"Device Color":
			return "Gradient device finish"
		"Phone Case":
			return "Phone case design or finish"
		"Protection Glass":
			return "Normal or side-angle privacy screen protection"
		"Battery Capacity":
			return "Maximum battery capacity"
		"Power Bank":
			return "Maximum selectable power bank capacity"
		"Screen Technology":
			return "Display technology"
		"RAM Technology":
			return "RAM technology"
		"Mobile Network":
			return "Mobile network standard"
		"Wi-Fi":
			return "Wi-Fi standard"
		"Bluetooth":
			return "Bluetooth version"
		"Cooling System Design":
			return "Cooling system design"
		"Phone Type":
			return "Phone chassis type"
		"Refresh Rate":
			return "Maximum selectable display refresh rate"
		"Speakers":
			return "Maximum number of supported speakers"
		"Speaker Quality":
			return "Overall speaker reproduction quality"
		_:
			return "Validated %s result" % component.to_lower()


func _open_creation_scene() -> void:
	creation_mode = true
	creation_step = 1
	selected_component_index = 0
	assigned_staff_ids.clear()
	_render_scene()


func complete_creation_flow() -> void:
	creation_mode = false
	creation_step = 1
	assigned_staff_ids.clear()


func _build_component_selection_scene() -> void:
	body_content = _new_screen_root()
	body.add_child(body_content)

	var heading := _label("SELECT COMPONENT", 26, TEXT_MAIN)
	heading.custom_minimum_size.y = _scaled(58.0)
	body_content.add_child(heading)

	component_page_grids.clear()
	component_page_index = 0
	component_buttons.clear()
	# Five components per row and four rows per page gives 20 slots,
	# keeping the 54-component catalogue within exactly three pages.
	var columns := 5
	var rows_per_page := 4
	var page_capacity := columns * rows_per_page

	component_page_viewport = VBoxContainer.new()
	component_page_viewport.name = "ResearchComponentPages"
	component_page_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	component_page_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	component_page_viewport.add_theme_constant_override("separation", 0)
	body_content.add_child(component_page_viewport)

	for index in range(COMPONENT_LABELS.size()):
		if index % page_capacity == 0:
			var page_grid := GridContainer.new()
			page_grid.name = "ResearchComponentPage_%d" % component_page_grids.size()
			page_grid.columns = columns
			page_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			page_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			page_grid.add_theme_constant_override("h_separation", roundi(_scaled(10.0)))
			page_grid.add_theme_constant_override("v_separation", roundi(_scaled(10.0)))
			page_grid.visible = component_page_grids.is_empty()
			component_page_grids.append(page_grid)
			component_page_viewport.add_child(page_grid)
		var component_button := Button.new()
		component_button.name = "ResearchComponentOption" if index == 0 else "ResearchComponentOption_%d" % index
		component_button.text = COMPONENT_LABELS[index].to_upper()
		component_button.custom_minimum_size = Vector2(_scaled(180.0), _scaled(58.0))
		component_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		component_button.focus_mode = Control.FOCUS_NONE
		component_button.clip_text = true
		component_button.add_theme_font_size_override("font_size", _scaled_font(18))
		if COMPONENT_VALUES[index] == "Mobile Network":
			var mobile_target: Dictionary = ResearchManagerScript.get_mobile_network_research_target(research_component_levels)
			if mobile_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next technology: %s (%s — %s)" % [
					str(mobile_target.get("technology", "")),
					str(mobile_target.get("generation", "")),
					str(mobile_target.get("generation_name", ""))
				]
		elif COMPONENT_VALUES[index] == "Wi-Fi":
			var wifi_target: Dictionary = ResearchManagerScript.get_wifi_research_target(research_component_levels)
			if wifi_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next technology: %s (%s)" % [
					str(wifi_target.get("generation", "")),
					str(wifi_target.get("technology", ""))
				]
		elif COMPONENT_VALUES[index] == "Bluetooth":
			var bluetooth_target: Dictionary = ResearchManagerScript.get_bluetooth_research_target(research_component_levels)
			if bluetooth_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next technology: %s" % str(bluetooth_target.get("technology", ""))
		elif COMPONENT_VALUES[index] == "Cooling System Design":
			var cooling_target: Dictionary = ResearchManagerScript.get_cooling_system_research_target(research_component_levels)
			if cooling_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next technology: %s" % str(cooling_target.get("technology", ""))
		elif COMPONENT_VALUES[index] in ["Phone Type", "Refresh Rate", "Speakers", "Speaker Quality", ResearchManagerScript.POWER_VOLUME_BUTTON_LENGTH_COMPONENT, "Phone Case", "Protection Glass", "Power Bank", "Smartwatch", "Wireless Earbuds", "Box Package"]:
			var component_name := str(COMPONENT_VALUES[index])
			var current_level := int(research_component_levels.get(component_name, 0))
			var maximum_level := 0
			match component_name:
				"Phone Type":
					var phone_type_target: Dictionary = ResearchManagerScript.get_phone_type_research_target(research_component_levels)
					maximum_level = ResearchManagerScript.PHONE_TYPE_SEQUENCE.size() - 1
					if phone_type_target.is_empty():
						component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
						component_button.disabled = true
					else:
						component_button.tooltip_text = "Next phone design: %s" % str(phone_type_target.get("technology", ""))
				"Refresh Rate":
					maximum_level = ResearchManagerScript.REFRESH_RATE_RESEARCH_LEVELS
					component_button.tooltip_text = "Next approval increases the maximum selectable refresh rate by 8 Hz."
				"Speakers":
					maximum_level = 11
					component_button.tooltip_text = "Next approval unlocks support for %d speakers." % mini(12, current_level + 2)
				"Speaker Quality":
					var speaker_quality_target: Dictionary = ResearchManagerScript.get_speaker_quality_research_target(research_component_levels)
					maximum_level = ResearchManagerScript.SPEAKER_QUALITY_SEQUENCE.size() - 1
					if speaker_quality_target.is_empty():
						component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — PROFESSIONAL AUDIO"
						component_button.disabled = true
					else:
						component_button.tooltip_text = "Next quality generation: %s" % str(speaker_quality_target.get("technology", ""))
				ResearchManagerScript.POWER_VOLUME_BUTTON_LENGTH_COMPONENT:
					var button_length_target: Dictionary = ResearchManagerScript.get_power_volume_button_length_research_target(research_component_levels)
					maximum_level = ResearchManagerScript.POWER_VOLUME_BUTTON_LENGTH_MAX_LEVEL
					if button_length_target.is_empty():
						component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — BUTTON LENGTH 55%"
						component_button.disabled = true
					else:
						component_button.tooltip_text = "Next slider minimum: %s" % str(button_length_target.get("technology", ""))
				"Phone Case":
					var phone_case_target: Dictionary = ResearchManagerScript.get_phone_case_research_target(research_component_levels)
					maximum_level = ResearchManagerScript.PHONE_CASE_RESEARCH_SEQUENCE.size()
					if phone_case_target.is_empty():
						component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — GRADIENT CASE FINISH UNLOCKED"
						component_button.disabled = true
					else:
						component_button.tooltip_text = "Next phone-case unlock: %s" % str(phone_case_target.get("technology", ""))
				"Protection Glass":
					var protection_glass_target: Dictionary = ResearchManagerScript.get_protection_glass_research_target(research_component_levels)
					maximum_level = ResearchManagerScript.PROTECTION_GLASS_RESEARCH_SEQUENCE.size()
					if protection_glass_target.is_empty():
						component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — NORMAL AND PRIVACY GLASS UNLOCKED"
						component_button.disabled = true
					else:
						component_button.tooltip_text = "Next protection-glass unlock: %s" % str(protection_glass_target.get("technology", ""))
				"Smartwatch":
					maximum_level = 1
					component_button.tooltip_text = "One approved research project unlocks the Smartwatch accessory."
				"Wireless Earbuds":
					maximum_level = 1
					component_button.tooltip_text = "One approved research project unlocks the Wireless Earbuds accessory."
				"Box Package":
					maximum_level = 1
					component_button.tooltip_text = "One approved research project unlocks all Box Package customization controls."
				"Power Bank":
					var power_bank_target: Dictionary = ResearchManagerScript.get_power_bank_research_target(research_component_levels)
					maximum_level = ResearchManagerScript.POWER_BANK_MAX_RESEARCH_LEVEL
					if power_bank_target.is_empty():
						component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 25,000 mAh"
						component_button.disabled = true
					elif current_level == 0:
						component_button.tooltip_text = "First approval unlocks the Power Bank at 5,000 mAh."
					else:
						component_button.tooltip_text = "Next slider maximum: %s" % str(power_bank_target.get("technology", ""))
			if current_level >= maximum_level:
				if component_name != "Power Bank":
					component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
				component_button.disabled = true
			for project_value in research_projects:
				if not (project_value is Dictionary):
					continue
				var component_project: Dictionary = project_value
				if str(component_project.get("component", "")) == component_name and str(component_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
					component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
					component_button.disabled = true
					break
		elif ResearchManagerScript.PHONE_SENSOR_COMPONENTS.has(str(COMPONENT_VALUES[index])) or ResearchManagerScript.SIDE_BUTTON_COMPONENTS.has(str(COMPONENT_VALUES[index])) or ResearchManagerScript.POWER_VOLUME_BUTTON_POSITION_COMPONENTS.has(str(COMPONENT_VALUES[index])):
			var unlock_component := str(COMPONENT_VALUES[index])
			var component_researched := int(research_component_levels.get(unlock_component, 0)) >= 1
			var component_project_in_progress := false
			for project_value in research_projects:
				if not (project_value is Dictionary):
					continue
				var unlock_project: Dictionary = project_value
				if str(unlock_project.get("component", "")) == unlock_component and str(unlock_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
					component_project_in_progress = true
					break
			component_button.disabled = component_researched or component_project_in_progress
			if component_researched:
				component_button.tooltip_text = "RESEARCH APPROVED — FEATURE UNLOCKED"
			elif component_project_in_progress:
				component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
			else:
				component_button.tooltip_text = "Commission a separate company-funded project to unlock this feature."
		elif COMPONENT_VALUES[index] in ["Curved Screen Horizontal", "Curved Screen Vertical", "Curved Screen Both"]:
			var curved_component: String = str(COMPONENT_VALUES[index])
			var already_researched := int(research_component_levels.get(curved_component, 0)) >= 1
			var project_in_progress := false
			for project_value in research_projects:
				if not (project_value is Dictionary):
					continue
				var project: Dictionary = project_value
				if str(project.get("component", "")) == curved_component and str(project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
					project_in_progress = true
					break
			component_button.disabled = already_researched or project_in_progress
			if already_researched:
				component_button.tooltip_text = "RESEARCH APPROVED"
			elif project_in_progress:
				component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS"
			else:
				component_button.tooltip_text = "Research unlocks this curved-screen design."
		elif COMPONENT_VALUES[index] == "Battery Capacity":
			var battery_target: Dictionary = ResearchManagerScript.get_battery_capacity_research_target(research_component_levels)
			if battery_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 8,000 mAh"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next slider maximum: %s" % str(battery_target.get("technology", ""))
		elif COMPONENT_VALUES[index] == "Charger":
			var charger_target: Dictionary = ResearchManagerScript.get_charger_research_target(research_component_levels)
			if charger_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 200W"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next Charger research: %s" % str(charger_target.get("technology", ""))
				var charger_target_index := int(charger_target.get("index", -1))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var charger_project: Dictionary = project_value
					if str(charger_project.get("component", "")) == "Charger" and int(charger_project.get("research_target_index", -1)) == charger_target_index and str(charger_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "CHARGER RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Charging Speed":
			var charging_target: Dictionary = ResearchManagerScript.get_charging_speed_research_target(research_component_levels)
			if charging_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 200W"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next slider maximum: %s" % str(charging_target.get("technology", ""))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var charging_project: Dictionary = project_value
					if str(charging_project.get("component", "")) == "Charging Speed" and str(charging_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Wireless Charging":
			var wireless_target: Dictionary = ResearchManagerScript.get_wireless_charging_research_target(research_component_levels)
			if wireless_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 200W"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next wireless charging maximum: %s" % str(wireless_target.get("technology", ""))
				if int(research_component_levels.get("Wireless Charging", 0)) == 0:
					component_button.tooltip_text = "First approval unlocks wireless charging at 1W."
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var wireless_project: Dictionary = project_value
					if str(wireless_project.get("component", "")) == "Wireless Charging" and str(wireless_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Front Camera MP":
			var front_camera_mp_target: Dictionary = ResearchManagerScript.get_front_camera_mp_research_target(research_component_levels)
			if front_camera_mp_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 300MP"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next front camera resolution ceiling: %s" % str(front_camera_mp_target.get("technology", ""))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var front_camera_mp_project: Dictionary = project_value
					if str(front_camera_mp_project.get("component", "")) == "Front Camera MP" and str(front_camera_mp_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Rear Camera MP":
			var rear_camera_mp_target: Dictionary = ResearchManagerScript.get_rear_camera_mp_research_target(research_component_levels)
			if rear_camera_mp_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 400MP"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next rear camera resolution ceiling: %s" % str(rear_camera_mp_target.get("technology", ""))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var rear_camera_mp_project: Dictionary = project_value
					if str(rear_camera_mp_project.get("component", "")) == "Rear Camera MP" and str(rear_camera_mp_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Rear Camera Count":
			var rear_camera_count_target: Dictionary = ResearchManagerScript.get_rear_camera_count_research_target(research_component_levels)
			if rear_camera_count_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 5 CAMERAS"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next rear camera capacity: %s" % str(rear_camera_count_target.get("technology", ""))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var rear_camera_count_project: Dictionary = project_value
					if str(rear_camera_count_project.get("component", "")) == "Rear Camera Count" and str(rear_camera_count_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Rear Flash Count":
			var rear_flash_count_target: Dictionary = ResearchManagerScript.get_rear_flash_count_research_target(research_component_levels)
			if rear_flash_count_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 5 FLASHES"
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Next rear flash capacity: %s" % str(rear_flash_count_target.get("technology", ""))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var rear_flash_count_project: Dictionary = project_value
					if str(rear_flash_count_project.get("component", "")) == "Rear Flash Count" and str(rear_flash_count_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Back Raised Design":
			var back_raised_design_target: Dictionary = ResearchManagerScript.get_back_raised_design_research_target(research_component_levels)
			if back_raised_design_target.is_empty():
				component_button.tooltip_text = "MAXIMUM RESEARCH REACHED — 20 RAISED BOXES"
				component_button.disabled = true
			else:
				if int(research_component_levels.get("Back Raised Design", 0)) == 0:
					component_button.tooltip_text = "First approval unlocks the Back Raised Design controls and one raised box."
				else:
					component_button.tooltip_text = "Next raised-box capacity: %s" % str(back_raised_design_target.get("technology", ""))
				for project_value in research_projects:
					if not (project_value is Dictionary):
						continue
					var back_raised_design_project: Dictionary = project_value
					if str(back_raised_design_project.get("component", "")) == "Back Raised Design" and str(back_raised_design_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
						component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
						component_button.disabled = true
						break
		elif COMPONENT_VALUES[index] == "Device Color":
			var device_color_researched := int(research_component_levels.get("Device Color", 0)) >= 1
			var device_color_project_in_progress := false
			for project_value in research_projects:
				if not (project_value is Dictionary):
					continue
				var device_color_project: Dictionary = project_value
				if str(device_color_project.get("component", "")) == "Device Color" and str(device_color_project.get("status", "")) in [ResearchManagerScript.STATUS_ACTIVE, ResearchManagerScript.STATUS_AWAITING_VALIDATION]:
					device_color_project_in_progress = true
					break
			component_button.disabled = device_color_researched or device_color_project_in_progress
			if device_color_researched:
				component_button.tooltip_text = "RESEARCH APPROVED — GRADIENT DEVICE FINISH UNLOCKED"
			elif device_color_project_in_progress:
				component_button.tooltip_text = "RESEARCH ALREADY IN PROGRESS OR AWAITING VALIDATION"
			else:
				component_button.tooltip_text = "One company-funded approval unlocks gradient finishes. Solid colours remain available by default."
		elif COMPONENT_VALUES[index] == "Memory Clock":
			var memory_clock_level := int(research_component_levels.get("Memory Clock", 0))
			var ram_technology_level := int(research_component_levels.get("RAM Technology", 0))
			var memory_clock_research_ceiling := ResearchManagerScript.get_memory_clock_research_ceiling_for_ram_technology_level(ram_technology_level)
			if memory_clock_level >= memory_clock_research_ceiling:
				if memory_clock_research_ceiling >= ResearchManagerScript.MEMORY_CLOCK_MAX_RESEARCH_LEVEL:
					component_button.tooltip_text = "MAXIMUM RESEARCH REACHED"
				else:
					component_button.tooltip_text = "Unlock a newer RAM Technology to continue."
				component_button.disabled = true
			else:
				component_button.tooltip_text = "Research unlocks the next available memory speed."
		component_button.pressed.connect(_on_component_selected.bind(index))
		component_page_grids[component_page_grids.size() - 1].add_child(component_button)
		component_buttons.append(component_button)
	_update_component_button_styles()
	_build_component_page_navigation()
	_show_component_page(0)

	var actions: BoxContainer = VBoxContainer.new() if _is_narrow_layout() else HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	actions.add_theme_constant_override("separation", roundi(_scaled(12.0)))
	body_content.add_child(actions)
	var cancel := _button("CANCEL", false, TEXT_MUTED)
	cancel.custom_minimum_size = Vector2(_scaled(150.0), _scaled(54.0))
	cancel.pressed.connect(_close_creation_scene)
	var next := _button("NEXT  〉", true, ACCENT)
	next.name = "ResearchNextButton"
	next.custom_minimum_size = Vector2(_scaled(220.0), _scaled(54.0))
	next.pressed.connect(_open_staff_selection_step)
	if _is_narrow_layout():
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(cancel)
		actions.add_child(next)
	else:
		actions.add_child(cancel)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(spacer)
		actions.add_child(next)


func _build_component_page_navigation() -> void:
	var navigation := HBoxContainer.new()
	navigation.name = "ResearchComponentPageNavigation"
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", roundi(_scaled(14.0)))
	body_content.add_child(navigation)

	component_page_previous = _button("‹", false, TEXT_MUTED)
	component_page_previous.custom_minimum_size = Vector2(_scaled(42.0), _scaled(34.0))
	component_page_previous.pressed.connect(_show_previous_component_page)
	navigation.add_child(component_page_previous)

	component_page_indicator = _label("", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	component_page_indicator.custom_minimum_size.x = _scaled(92.0)
	navigation.add_child(component_page_indicator)

	component_page_next = _button("›", false, TEXT_MUTED)
	component_page_next.custom_minimum_size = Vector2(_scaled(42.0), _scaled(34.0))
	component_page_next.pressed.connect(_show_next_component_page)
	navigation.add_child(component_page_next)


func _show_component_page(page_index: int) -> void:
	if component_page_grids.is_empty():
		return
	component_page_index = clampi(page_index, 0, component_page_grids.size() - 1)
	for index in range(component_page_grids.size()):
		component_page_grids[index].visible = index == component_page_index
	if is_instance_valid(component_page_indicator):
		component_page_indicator.text = "PAGE %d / %d" % [component_page_index + 1, component_page_grids.size()]
	if is_instance_valid(component_page_previous):
		component_page_previous.disabled = component_page_index <= 0
	if is_instance_valid(component_page_next):
		component_page_next.disabled = component_page_index >= component_page_grids.size() - 1


func _show_previous_component_page() -> void:
	_show_component_page(component_page_index - 1)


func _show_next_component_page() -> void:
	_show_component_page(component_page_index + 1)


func _finish_component_swipe(end_position: Vector2) -> void:
	if not component_swipe_active:
		return
	component_swipe_active = false
	var delta := end_position - component_swipe_start
	if absf(delta.x) < 55.0 or absf(delta.x) <= absf(delta.y) * 1.2:
		return
	if delta.x < 0.0:
		_show_next_component_page()
	else:
		_show_previous_component_page()


func _input(event: InputEvent) -> void:
	if not creation_mode:
		return
	var active_viewport: Control
	if creation_step == 1 and is_instance_valid(component_page_viewport):
		active_viewport = component_page_viewport
	elif creation_step == 2 and is_instance_valid(staff_page_viewport):
		active_viewport = staff_page_viewport
	else:
		return
	var page_rect := active_viewport.get_global_rect()
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and page_rect.has_point(touch.position):
			if creation_step == 1:
				component_swipe_start = touch.position
				component_swipe_active = true
			else:
				staff_swipe_start = touch.position
				staff_swipe_active = true
		elif not touch.pressed:
			if creation_step == 1:
				_finish_component_swipe(touch.position)
			else:
				_finish_staff_swipe(touch.position)
	elif event is InputEventScreenDrag:
		# Complete page changes on touch release to avoid changing pages mid-drag.
		pass
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and page_rect.has_point(mouse_button.position):
			if creation_step == 1:
				component_swipe_start = mouse_button.position
				component_swipe_active = true
			else:
				staff_swipe_start = mouse_button.position
				staff_swipe_active = true
		elif not mouse_button.pressed:
			if creation_step == 1:
				_finish_component_swipe(mouse_button.position)
			else:
				_finish_staff_swipe(mouse_button.position)


func _open_staff_selection_step() -> void:
	creation_step = 2
	assigned_staff_ids.clear()
	_render_scene()


func _build_staff_selection_scene() -> void:
	body_content = _new_screen_root()
	body.add_child(body_content)

	var heading := _label("SELECT RESEARCH STAFF", 26, TEXT_MAIN)
	heading.custom_minimum_size.y = _scaled(58.0)
	body_content.add_child(heading)

	staff_page_grids.clear()
	staff_page_index = 0
	staff_page_viewport = VBoxContainer.new()
	staff_page_viewport.name = "ResearchStaffScroll"
	staff_page_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff_page_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	staff_page_viewport.add_theme_constant_override("separation", 0)
	body_content.add_child(staff_page_viewport)
	_build_staff_choices()

	_build_staff_page_navigation()
	_show_staff_page(0)

	var actions: BoxContainer = VBoxContainer.new() if _is_narrow_layout() else HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	actions.add_theme_constant_override("separation", roundi(_scaled(12.0)))
	body_content.add_child(actions)
	var back_step := _button("‹  BACK", false, TEXT_MUTED)
	back_step.custom_minimum_size = Vector2(_scaled(150.0), _scaled(54.0))
	back_step.pressed.connect(_return_to_component_step)
	start_button = _button("CREATE RESEARCH", true, ACCENT)
	start_button.name = "ResearchCreateButton"
	start_button.custom_minimum_size = Vector2(_scaled(260.0), _scaled(54.0))
	start_button.disabled = true
	start_button.pressed.connect(_on_start_research_pressed)
	if _is_narrow_layout():
		back_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(back_step)
		actions.add_child(start_button)
	else:
		actions.add_child(back_step)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(spacer)
		actions.add_child(start_button)
	_update_research_estimate()


func _return_to_component_step() -> void:
	creation_step = 1
	_render_scene()

func _build_staff_choices() -> void:
	var occupied_ids := _active_project_staff_ids()
	var columns := 5
	var page_capacity := columns * 4
	var eligible_count := 0
	for employee_value in staff_employees:
		if employee_value is Dictionary and str(employee_value.get("department", "")) == "Research":
			eligible_count += 1
	if eligible_count == 0:
		var empty_grid := _create_staff_page_grid()
		var empty_label := _label("NO RESEARCH STAFF AVAILABLE", 18, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.custom_minimum_size.y = _scaled(68.0)
		empty_grid.add_child(empty_label)
		return
	var staff_index := 0
	for employee_value in staff_employees:
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("department", "")) != "Research":
			continue
		if staff_index % page_capacity == 0:
			_create_staff_page_grid()
		var parent := staff_page_grids[staff_page_grids.size() - 1]
		staff_index += 1
		var employee_id := str(employee.get("id", ""))
		var employee_name := str(employee.get("full_name", employee.get("name", "Research employee")))
		var selected := assigned_staff_ids.has(employee_id)
		var unavailable := employee_id.is_empty() or occupied_ids.has(employee_id)

		var staff_button := Button.new()
		staff_button.name = "ResearchStaff_%s" % employee_id.validate_node_name()
		staff_button.text = employee_name.to_upper()
		staff_button.custom_minimum_size = Vector2(_scaled(190.0), _scaled(68.0))
		staff_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		staff_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		staff_button.disabled = unavailable
		staff_button.focus_mode = Control.FOCUS_NONE
		staff_button.clip_text = true
		staff_button.add_theme_font_size_override("font_size", _scaled_font(17))
		staff_button.add_theme_color_override("font_color", TEXT_MAIN)
		staff_button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#554021") if selected else Color("#222628")
		normal.border_color = ACCENT if selected else Color("#49463F")
		normal.set_border_width_all(3 if selected else 1)
		normal.set_corner_radius_all(8)
		normal.content_margin_left = roundi(_scaled(10.0))
		normal.content_margin_right = roundi(_scaled(10.0))
		normal.content_margin_top = roundi(_scaled(10.0))
		normal.content_margin_bottom = roundi(_scaled(10.0))
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#624A29") if selected else Color("#303638")
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color("#70512B")
		staff_button.add_theme_stylebox_override("normal", normal)
		staff_button.add_theme_stylebox_override("hover", hover)
		staff_button.add_theme_stylebox_override("pressed", pressed)
		staff_button.add_theme_stylebox_override("disabled", normal)
		staff_button.pressed.connect(_on_staff_toggled.bind(not selected, employee_id))
		parent.add_child(staff_button)


func _create_staff_page_grid() -> GridContainer:
	var page_grid := GridContainer.new()
	page_grid.name = "ResearchStaffPage_%d" % staff_page_grids.size()
	page_grid.columns = 5
	page_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	page_grid.add_theme_constant_override("h_separation", roundi(_scaled(10.0)))
	page_grid.add_theme_constant_override("v_separation", roundi(_scaled(10.0)))
	page_grid.visible = staff_page_grids.is_empty()
	staff_page_grids.append(page_grid)
	staff_page_viewport.add_child(page_grid)
	return page_grid


func _build_staff_page_navigation() -> void:
	var navigation := HBoxContainer.new()
	navigation.name = "ResearchStaffPageNavigation"
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", roundi(_scaled(14.0)))
	body_content.add_child(navigation)

	staff_page_previous = _button("‹", false, TEXT_MUTED)
	staff_page_previous.custom_minimum_size = Vector2(_scaled(42.0), _scaled(34.0))
	staff_page_previous.pressed.connect(_show_previous_staff_page)
	navigation.add_child(staff_page_previous)

	staff_page_indicator = _label("", 12, TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	staff_page_indicator.custom_minimum_size.x = _scaled(92.0)
	navigation.add_child(staff_page_indicator)

	staff_page_next = _button("›", false, TEXT_MUTED)
	staff_page_next.custom_minimum_size = Vector2(_scaled(42.0), _scaled(34.0))
	staff_page_next.pressed.connect(_show_next_staff_page)
	navigation.add_child(staff_page_next)


func _show_staff_page(page_index: int) -> void:
	if staff_page_grids.is_empty():
		return
	staff_page_index = clampi(page_index, 0, staff_page_grids.size() - 1)
	for index in range(staff_page_grids.size()):
		staff_page_grids[index].visible = index == staff_page_index
	if is_instance_valid(staff_page_indicator):
		staff_page_indicator.text = "PAGE %d / %d" % [staff_page_index + 1, staff_page_grids.size()]
	if is_instance_valid(staff_page_previous):
		staff_page_previous.disabled = staff_page_index <= 0
	if is_instance_valid(staff_page_next):
		staff_page_next.disabled = staff_page_index >= staff_page_grids.size() - 1


func _show_previous_staff_page() -> void:
	_show_staff_page(staff_page_index - 1)


func _show_next_staff_page() -> void:
	_show_staff_page(staff_page_index + 1)


func _finish_staff_swipe(end_position: Vector2) -> void:
	if not staff_swipe_active:
		return
	staff_swipe_active = false
	var delta := end_position - staff_swipe_start
	if absf(delta.x) < 55.0 or absf(delta.x) <= absf(delta.y) * 1.2:
		return
	if delta.x < 0.0:
		_show_next_staff_page()
	else:
		_show_previous_staff_page()


func _on_staff_toggled(checked: bool, employee_id: String) -> void:
	if checked:
		if not assigned_staff_ids.has(employee_id):
			assigned_staff_ids.append(employee_id)
	else:
		assigned_staff_ids.erase(employee_id)
	_render_scene()


func _on_research_setup_changed(_value = null) -> void:
	_update_research_estimate()


func _update_research_estimate() -> void:
	if not is_instance_valid(start_button):
		return
	var component := _selected_component()
	var target_index := -1
	if component == "Wireless Charging":
		var wireless_target: Dictionary = ResearchManagerScript.get_wireless_charging_research_target(research_component_levels)
		target_index = int(wireless_target.get("index", -1))
	var estimate := ResearchManagerScript.estimate_research(component, assigned_staff_ids, staff_employees, target_index)
	start_button.disabled = not bool(estimate.get("ok", false))


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
	creation_step = 1
	assigned_staff_ids.clear()
	_render_scene()


func _build_active_research(projects: Array[Dictionary], pending_projects: Array[Dictionary] = []) -> void:
	body_content = _new_screen_root()
	body_content.name = "ResearchProjectsOverview"
	# Keep the project header and Create button fixed while the project sections scroll.
	body.add_child(body_content)

	if _is_narrow_layout():
		var narrow_header := VBoxContainer.new()
		narrow_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		narrow_header.add_theme_constant_override("separation", roundi(_scaled(8.0)))
		body_content.add_child(narrow_header)
		var narrow_title := _label("RESEARCH PROJECTS", 22, TEXT_MAIN)
		narrow_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		narrow_header.add_child(narrow_title)
		var narrow_actions := HBoxContainer.new()
		narrow_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		narrow_header.add_child(narrow_actions)
		var create_button := _button("CREATE NEW", true, ACCENT)
		create_button.name = "CreateResearchWhileActiveButton"
		create_button.custom_minimum_size = Vector2(_scaled(144.0), _scaled(64.0))
		create_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		create_button.pressed.connect(_open_creation_scene)
		narrow_actions.add_child(create_button)
	else:
		var page_heading := HBoxContainer.new()
		page_heading.custom_minimum_size.y = _scaled(58.0)
		page_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var page_title := _label("RESEARCH PROJECTS", 22, TEXT_MAIN)
		page_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		page_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		page_heading.add_child(page_title)
		var heading_spacer := Control.new()
		heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_heading.add_child(heading_spacer)
		var create_button := _button("CREATE NEW", true, ACCENT)
		create_button.name = "CreateResearchWhileActiveButton"
		create_button.custom_minimum_size = Vector2(_scaled(144.0), _scaled(64.0))
		create_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		create_button.pressed.connect(_open_creation_scene)
		page_heading.add_child(create_button)
		body_content.add_child(page_heading)

	var project_scroll := ScrollContainer.new()
	project_scroll.name = "ResearchProjectsScroll"
	project_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	project_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	project_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body_content.add_child(project_scroll)

	var project_list := VBoxContainer.new()
	project_list.name = "ResearchProjectsList"
	project_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	project_list.add_theme_constant_override("separation", roundi(_scaled(12.0)))
	project_scroll.add_child(project_list)

	if not pending_projects.is_empty():
		project_list.add_child(_label("COMPLETED RESEARCH", 17, ACCENT))
		var validation_grid := GridContainer.new()
		validation_grid.name = "ResearchValidationGrid"
		validation_grid.columns = 3
		validation_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		validation_grid.add_theme_constant_override("h_separation", roundi(_scaled(12.0)))
		validation_grid.add_theme_constant_override("v_separation", roundi(_scaled(12.0)))
		project_list.add_child(validation_grid)
		for pending_project in pending_projects:
			_build_validation_project_card(pending_project, validation_grid)

	if not projects.is_empty():
		project_list.add_child(_label("IN DEVELOPMENT", 17, TEXT_MAIN))
		var active_grid := GridContainer.new()
		active_grid.name = "ResearchInDevelopmentGrid"
		active_grid.columns = 3
		active_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_grid.add_theme_constant_override("h_separation", roundi(_scaled(12.0)))
		active_grid.add_theme_constant_override("v_separation", roundi(_scaled(12.0)))
		project_list.add_child(active_grid)
		for project in projects:
			_build_active_research_project(project, active_grid)

	rendered_project_signature = _get_project_status_signature()


func _build_validation_project_card(project: Dictionary, parent: Control) -> void:
	var project_id := str(project.get("id", ""))
	var component := str(project.get("component", "Research"))
	var card := PanelContainer.new()
	card.name = "PendingValidationCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1B1E20")
	panel_style.border_color = Color("#72552F")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = roundi(_scaled(14.0))
	panel_style.content_margin_right = roundi(_scaled(14.0))
	panel_style.content_margin_top = roundi(_scaled(12.0))
	panel_style.content_margin_bottom = roundi(_scaled(12.0))
	card.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(_scaled(5.0)))
	card.add_child(content)
	content.add_child(_label(component.to_upper(), 18, TEXT_MAIN))
	content.add_child(_label("PROJECT  " + project_id, 11, ACCENT))
	var target := str(project.get("research_target", "")).strip_edges()
	if not target.is_empty():
		var target_label := _label("TARGET  " + target, 15, TEXT_MAIN)
		target_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(target_label)
	var successful := str(project.get("status", "")) == ResearchManagerScript.STATUS_AWAITING_VALIDATION
	var completion_note := _label("RESEARCH SUCCESSFUL — awaiting approval." if successful else "RESEARCH FAILED — retry available.", 12, SUCCESS if successful else ORANGE)
	completion_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(completion_note)

	var review_button := _button("VIEW FINDINGS  ›", true, ACCENT)
	review_button.name = "ReviewValidationButton"
	review_button.custom_minimum_size = Vector2(_scaled(172.0), _scaled(40.0))
	review_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	review_button.pressed.connect(open_validation_review.bind(project_id))
	content.add_child(review_button)


func _build_active_research_project(project: Dictionary, parent: Control) -> void:
	var project_id := str(project.get("id", ""))
	var component_name := str(project.get("component", project.get("title", "Research project")))
	if component_name == "Screen Technology":
		component_name = "Screen Tech"

	var card := PanelContainer.new()
	card.name = "ActiveResearchProjectCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_active_research_project_input.bind(project_id))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1B1E20")
	panel_style.border_color = Color("#514936")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = roundi(_scaled(14.0))
	panel_style.content_margin_right = roundi(_scaled(14.0))
	panel_style.content_margin_top = roundi(_scaled(12.0))
	panel_style.content_margin_bottom = roundi(_scaled(12.0))
	card.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(card)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", roundi(_scaled(7.0)))
	card.add_child(content)

	var component_label := _label(component_name.to_upper(), 18, TEXT_MAIN)
	component_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(component_label)
	content.add_child(_label("PROJECT  " + project_id, 11, ACCENT))

	var target := str(project.get("research_target", "")).strip_edges()
	if not target.is_empty():
		var target_label := _label("TARGET  " + target, 13, TEXT_MUTED)
		target_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(target_label)

	var required_days := maxf(1.0, float(project.get("required_research_days", project.get("estimated_duration_days", 1.0))))
	var completed_days := clampf(float(project.get("completed_research_days", 0.0)), 0.0, required_days)
	var progress_bar := ProgressBar.new()
	progress_bar.name = "ResearchProjectProgressBar"
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = (completed_days / required_days) * 100.0
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.custom_minimum_size.y = _scaled(9.0)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color("#343638")
	progress_background.set_corner_radius_all(5)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = ACCENT
	progress_fill.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("background", progress_background)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	content.add_child(progress_bar)

	var pause_reason := str(project.get("pause_reason", "")).strip_edges()
	if not pause_reason.is_empty():
		var pause_label := _label("PROJECT PAUSED  /  " + pause_reason, 12, ORANGE)
		pause_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(pause_label)


func _on_active_research_project_input(event: InputEvent, project_id: String) -> void:
	var clicked := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked = true
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true
	if clicked:
		show_active_research_details(project_id)
		accept_event()


func show_active_research_details(project_id: String) -> void:
	if not is_instance_valid(existing_pop_alert):
		push_warning("The existing alert component is unavailable; research details were not opened.")
		return
	var project := _find_research_project(project_id)
	if project.is_empty() or str(project.get("status", "")) != ResearchManagerScript.STATUS_ACTIVE:
		return
	var required_days := maxf(1.0, float(project.get("required_research_days", project.get("estimated_duration_days", 1.0))))
	var completed_days := clampf(float(project.get("completed_research_days", 0.0)), 0.0, required_days)
	var duration_percent := clampf((completed_days / required_days) * 100.0, 0.0, 100.0)
	var remaining_days := maxf(0.0, required_days - completed_days)
	var start_unix := float(project.get("created_at_unix", game_date_unix))
	var expected_finish_unix := game_date_unix + remaining_days * 86400.0
	var details := VBoxContainer.new()
	details.name = "ActiveResearchDetails"
	details.add_theme_constant_override("separation", 10)
	for detail in [
		"RESEARCH DURATION COMPLETED   %.1f%%" % duration_percent,
		"START DATE   %s" % _format_research_date(start_unix),
		"EXPECTED FINISH   %s" % _format_research_date(expected_finish_unix)
	]:
		var line := _label(detail, 15, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(line)
	var project_name := str(project.get("component", "Research"))
	existing_pop_alert.call(
		"show_custom_prompt",
		project_name.to_upper() + " RESEARCH",
		"Current research schedule and duration progress.",
		details,
		"CANCEL RESEARCH",
		Callable(self, "_request_project_cancellation").bind(project_id)
	)


func _format_research_date(timestamp: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%02d %s %04d" % [
		int(date.get("day", 1)),
		["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][clampi(int(date.get("month", 1)) - 1, 0, 11)],
		int(date.get("year", 1970))
	]


func _request_project_cancellation(project_id: String) -> void:
	project_cancel_requested.emit(project_id)


func _add_panel(parent: Control, stretch_ratio: float = 1.0) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_stretch_ratio = stretch_ratio
	content.add_theme_constant_override("separation", roundi(_scaled(10.0)))
	parent.add_child(content)
	return content


func _add_target_tile(parent: HBoxContainer, title: String, description: String) -> void:
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 3)
	parent.add_child(tile)
	tile.add_child(_label(title, 12, TEXT_MAIN))
	if not description.is_empty():
		var description_label := _label(description, 11, TEXT_MUTED)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		tile.add_child(description_label)


func _add_large_metric(parent: VBoxContainer, value: String, caption: String, color: Color) -> void:
	var metric := VBoxContainer.new()
	metric.add_theme_constant_override("separation", roundi(_scaled(2.0)))
	parent.add_child(metric)
	var value_label := _label(value, 22, color)
	value_label.add_theme_font_size_override("font_size", _scaled_font(22))
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
		normal.content_margin_top = 8
		normal.content_margin_bottom = 8
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#624A29") if selected else Color("#2B3032")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)



func _get_active_projects() -> Array[Dictionary]:
	var active_projects: Array[Dictionary] = []
	# Newest projects appear first while all active projects remain visible.
	for index in range(research_projects.size() - 1, -1, -1):
		var value: Variant = research_projects[index]
		if value is Dictionary and str(value.get("status", "")) == "active":
			active_projects.append(value)
	return active_projects


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


func update_live_progress(projects: Array, balance: float, employees: Array, current_game_date_unix: float = -1.0) -> void:
	if current_game_date_unix >= 0.0:
		game_date_unix = current_game_date_unix
	research_projects = projects.duplicate(true)
	company_balance = maxf(0.0, balance)
	if is_instance_valid(capital_value_label):
		capital_value_label.text = _format_currency(company_balance)
	staff_employees = employees.duplicate(true)
	if not is_node_ready() or creation_mode:
		return

	# Refresh the visual progress bars as research time advances, without
	# displaying numerical completion percentages or staff details.
	if _get_project_status_signature() != rendered_project_signature:
		_render_scene()


func _get_project_status_signature() -> String:
	var parts: PackedStringArray = []
	for project_value in research_projects:
		if project_value is Dictionary:
			parts.append("%s:%s:%.3f:%.3f:%s" % [
				str(project_value.get("id", "")),
				str(project_value.get("status", "")),
				float(project_value.get("completed_research_days", 0.0)),
				float(project_value.get("required_research_days", project_value.get("estimated_duration_days", 0.0))),
				str(project_value.get("pause_reason", ""))
			])
	return "|".join(parts)


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
	# Preserve whole words in tight rows. SMART can split short words into
	# one character per line when a container is temporarily too narrow.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
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
