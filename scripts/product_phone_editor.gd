extends Node3D

signal back_requested
signal research_upgrade_requested(research_id: String)

const PHONE_SIZE := Vector3(1.45, 2.92, 0.22)
const ROTATION_STEP := deg_to_rad(10.0)
# Deliberately low so a normal finger movement makes a controlled turn.
const DRAG_SENSITIVITY := 0.0024

var phone_body: MeshInstance3D
var phone_screen: MeshInstance3D
var home_button_type := "Circle Home Button"
var home_button_enabled := false
const HOME_BUTTON_TYPES := ["Circle Home Button", "Oval Home Button", "Square Home Button", "Recent · Home · Back (Physical)", "On-screen"]
var home_button_option_buttons: Dictionary = {}
var screen_enabled := false
var bezel_width := 0.10
var bezel_height := 0.20
var bezel_width_value_label: Label
var bezel_height_value_label: Label
var screen_shape_mode := "Flat screen"
var side_curve_enabled := false
var vertical_curve_enabled := false
var screen_shape_buttons: Dictionary = {}
var side_curve_toggle: Button
var vertical_curve_toggle: Button
var selected_screen_type := "TFT LCD"
var screen_enable_checkbox: CheckBox
var screen_type_buttons: Dictionary = {}
const SCREEN_TYPE_ORDER := ["TFT LCD", "LED-LCD", "IPS LCD", "Mini-LED LCD", "OLED", "AMOLED", "Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"]
var preview_camera: Camera3D
var preview_container: SubViewportContainer
var research_mode := false
var research_content_panel: Control
var research_balance_label: Label
var research_levels: Dictionary = {}
var research_balance := 0.0
var research_item_cards: Dictionary = {}
var research_view := "HARDWARE"
var left_tools_page := 0
var left_tools_previous_button: Button
var left_tools_next_button: Button
var left_tools_scroll: ScrollContainer
var preview_mouse_dragging := false
var border_radius_level := 0
var border_radius_value_label: Label
var phone_thickness_level := 0
var phone_thickness_value_label: Label
var speaker_count := 0
var speaker_count_value_label: Label
var charge_port_type := "None"
var charge_port_opening_points := PackedVector2Array()
var charge_port_value_label: Label
var power_button_enabled := false
var volume_button_enabled := false
var power_button_y := 0.72
var volume_button_y := 0.34
var side_button_length_scale := 1.35
var power_button_position_label: Label
var volume_button_position_label: Label
var side_button_length_label: Label
var active_feature_panel: Control
var right_tools_content: VBoxContainer


func _ready() -> void:
	if research_mode:
		_build_research_ui()
	else:
		_build_editor_ui()


func _build_editor_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PhoneEditorInterface"
	layer.layer = 50
	add_child(layer)

	var root := Control.new()
	root.name = "PhoneEditorRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	# Match the shared background and overlay used by the other game pages.
	var background := TextureRect.new()
	background.name = "DigitalWorld_Shared_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load("res://assets/digitalworld-landing.png")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shared_Background_Overlay"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.035, 0.065, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var page_margin := MarginContainer.new()
	page_margin.name = "PhoneEditorPageMargin"
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 22)
	page_margin.add_theme_constant_override("margin_right", 22)
	page_margin.add_theme_constant_override("margin_top", 20)
	page_margin.add_theme_constant_override("margin_bottom", 20)
	root.add_child(page_margin)

	var layout := HBoxContainer.new()
	layout.name = "PhoneEditorMainLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	page_margin.add_child(layout)

	# Balanced panel widths adapt to compact and wide viewports.
	var compact_layout := get_viewport().get_visible_rect().size.x < 900.0
	page_margin.add_theme_constant_override("margin_left", 10 if compact_layout else 22)
	page_margin.add_theme_constant_override("margin_right", 10 if compact_layout else 22)
	layout.add_theme_constant_override("separation", 8 if compact_layout else 18)
	var left_tools_panel := _make_tools_card("PhoneEditorLeftToolsCard", true)
	left_tools_panel.custom_minimum_size.x = 190.0 if compact_layout else 245.0
	left_tools_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(left_tools_panel)

	var preview_panel := _make_glass_panel(Color(0.22, 0.53, 0.72, 0.24))
	preview_panel.name = "PhonePreviewCard"
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size.x = 170 if compact_layout else 220
	preview_panel.size_flags_stretch_ratio = 1.45
	layout.add_child(preview_panel)

	var preview_stack := VBoxContainer.new()
	preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_stack.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_stack)

	preview_container = SubViewportContainer.new()
	preview_container.name = "RotatablePhonePreview"
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_container.add_child(_get_preview_viewport())
	preview_stack.add_child(preview_container)

	# Navigation controls sit over the top corners of the 3D preview.
	var preview_navigation := HBoxContainer.new()
	preview_navigation.name = "PhonePreviewPanelNavigation"
	preview_navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	preview_navigation.offset_left = 12.0
	preview_navigation.offset_top = 12.0
	preview_navigation.offset_right = -12.0
	preview_navigation.offset_bottom = 60.0
	preview_navigation.add_theme_constant_override("separation", 8)
	preview_navigation.mouse_filter = Control.MOUSE_FILTER_PASS
	preview_panel.add_child(preview_navigation)

	left_tools_previous_button = Button.new()
	left_tools_previous_button.name = "PreviousToolsPageButton"
	left_tools_previous_button.text = "←"
	left_tools_previous_button.custom_minimum_size = Vector2(44, 44)
	left_tools_previous_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_tools_previous_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_tools_previous_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(left_tools_previous_button, 25)
	_style_staff_button(left_tools_previous_button, false)
	left_tools_previous_button.pressed.connect(_on_left_tools_previous_pressed)
	preview_navigation.add_child(left_tools_previous_button)

	var navigation_spacer := Control.new()
	navigation_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_navigation.add_child(navigation_spacer)

	left_tools_next_button = Button.new()
	left_tools_next_button.name = "NextToolsPageButton"
	left_tools_next_button.text = "→"
	left_tools_next_button.custom_minimum_size = Vector2(44, 44)
	left_tools_next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	left_tools_next_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_tools_next_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(left_tools_next_button, 25)
	_style_staff_button(left_tools_next_button, false)
	left_tools_next_button.pressed.connect(_on_left_tools_next_pressed)
	preview_navigation.add_child(left_tools_next_button)
	_update_left_tools_navigation_buttons()

	var right_tools_panel := _make_tools_card("PhoneEditorRightToolsCard", false)
	right_tools_panel.custom_minimum_size.x = 190.0 if compact_layout else 245.0
	right_tools_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(right_tools_panel)
	right_tools_content = VBoxContainer.new()
	right_tools_content.name = "PhoneEditorRightToolsContent"
	right_tools_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_tools_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_tools_content.add_theme_constant_override("separation", 14)
	right_tools_panel.add_child(right_tools_content)
	var initial_hint := _make_label("SELECT A FEATURE", 18, Color("#c7eaff"))
	initial_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_tools_content.add_child(initial_hint)


func _apply_research_typography(control: Control, font_size: int) -> void:
	# Keep the existing STIX variable font and strengthen its weight consistently.
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 0.7
	control.add_theme_font_override("font", stix_font)
	control.add_theme_font_size_override("font_size", font_size)


func _build_research_ui() -> void:
	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var layer := CanvasLayer.new()
	layer.name = "PhoneResearchInterface"
	layer.layer = 50
	add_child(layer)

	var root := Control.new()
	root.name = "PhoneResearchRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var background := TextureRect.new()
	background.name = "DigitalWorld_Shared_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load("res://assets/digitalworld-landing.png")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shared_Background_Overlay"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.035, 0.065, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var outer := MarginContainer.new()
	outer.name = "PhoneResearchPageMargin"
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("margin_left", 18 if compact else 42)
	outer.add_theme_constant_override("margin_right", 18 if compact else 42)
	outer.add_theme_constant_override("margin_top", 18 if compact else 28)
	outer.add_theme_constant_override("margin_bottom", 24)
	root.add_child(outer)

	var page := VBoxContainer.new()
	page.name = "PhoneResearchPageContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 15 if compact else 18)
	outer.add_child(page)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	page.add_child(header)
	header.add_child(_make_label("DIGITALWORLD  /  RESEARCH  /  PHONE", 11 if compact else 13, Color("#a9e3ff")))

	var hero_row := HBoxContainer.new()
	hero_row.name = "PhoneResearchHeroRow"
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_theme_constant_override("separation", 12)
	header.add_child(hero_row)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(heading)
	heading.add_child(_make_label("PHONE DESIGN RESEARCH", 27 if compact else 36, Color.WHITE))
	research_balance_label = _make_label("AVAILABLE BALANCE  " + _format_research_money(research_balance), 11 if compact else 12, Color("#c7eaff"))
	heading.add_child(research_balance_label)

	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(104 if compact else 120, 46 if compact else 50)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_research_typography(back_button, 15 if compact else 16)
	_style_staff_back_button(back_button)
	back_button.pressed.connect(_on_back_pressed)
	hero_row.add_child(back_button)

	var research_content := VBoxContainer.new()
	research_content.name = "PhoneDesignResearchContent"
	research_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	research_content.add_theme_constant_override("separation", 12)
	page.add_child(research_content)
	_build_design_research_content(research_content)


func set_research_data(levels: Dictionary, balance: float) -> void:
	research_levels = levels.duplicate(true)
	research_balance = balance
	if is_instance_valid(research_balance_label):
		research_balance_label.text = "AVAILABLE BALANCE  " + _format_research_money(research_balance)
	if is_instance_valid(research_content_panel):
		_refresh_design_research_cards()


func _build_design_research_content(parent: Control) -> void:
	research_content_panel = parent
	for child in parent.get_children():
		child.hide()
		child.queue_free()
	research_item_cards.clear()

	var compact := get_viewport().get_visible_rect().size.x < 900.0
	_build_research_view_selector(parent, compact)

	if research_view == "HARDWARE":
		_build_hardware_research_grid(parent, compact)
	elif research_view == "SOFTWARE":
		_build_software_research_grid(parent, compact)
	else:
		_build_extras_research_content(parent, compact)


func _get_hardware_research_features() -> Array:
	return [
		"Screen Tech", "Power/Volume Buttons", "Thickness", "Screen Width",
		"Screen Size", "Screen Type", "Border Radius", "Speakers",
		"Charge Port", "Front Camera", "Rare Camera", "Style Pen",
		"Side Button", "Home Button", "Body Frame", "Phone Width",
		"Phone Height", "Sim/Memory Slot", "Protection", "Refresh Rate",
		"Back Panel Material", "Frame Material", "Body Finish & Colour",
		"Cooling System Design"
	]


func _get_software_research_features() -> Array:
	return [
		"RAM", "Internal Storage", "RAM Technology", "Battery",
		"Charging Speed", "Wireless Charge", "Bluetooth", "WiFi",
		"Network", "NFC", "GPS", "USB Connectivity", "Sensors",
		"Front Camera", "Rare Camera", "Memory Clock", "AI Processing",
		"Data Encryption"
	]


func _get_extras_research_features() -> Array:
	return [
		"Box Package", "Phone Case", "Charger", "Charger Speed",
		"Protection Glass", "Wireless Earbuds", "Smartwatch", "Power Bank",
		"USB Cable", "Camera Lens Protector", "Phone Stand", "SIM Ejector Tool"
	]


func _build_hardware_research_grid(parent: Control, compact: bool) -> void:
	_build_research_feature_grid(parent, compact, "HARDWARE FEATURES", "Hardware", _get_hardware_research_features())


func _build_software_research_grid(parent: Control, compact: bool) -> void:
	_build_research_feature_grid(parent, compact, "SOFTWARE FEATURES", "Software", _get_software_research_features())


func _build_research_feature_grid(parent: Control, compact: bool, section_caption: String, grid_prefix: String, features: Array) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / maxf(viewport_size.y, 1.0)
	var columns := 6 if aspect_ratio >= 1.55 else (5 if aspect_ratio >= 1.2 else 3)
	var short_screen := viewport_size.y < 430.0
	var card_height := 58.0 if short_screen else (82.0 if compact else 104.0)

	var section := VBoxContainer.new()
	section.name = grid_prefix + "ResearchSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	parent.add_child(section)

	var section_title := _make_label(section_caption, 13 if compact else 16, Color("#b9eaff"))
	section.add_child(section_title)

	var grid := GridContainer.new()
	grid.name = grid_prefix + "ResearchFeatureGrid"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8 if compact else 12)
	grid.add_theme_constant_override("v_separation", 7 if compact else 10)
	section.add_child(grid)

	for feature_value in features:
		var feature_name := str(feature_value)
		var card := _make_staff_style_card()
		card.name = feature_name.replace("/", "_").replace(" ", "") + "_" + grid_prefix + "Card"
		card.custom_minimum_size = Vector2(0, card_height)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(card)

		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_left", 5 if short_screen else 9)
		margin.add_theme_constant_override("margin_right", 5 if short_screen else 9)
		margin.add_theme_constant_override("margin_top", 3 if short_screen else 7)
		margin.add_theme_constant_override("margin_bottom", 3 if short_screen else 7)
		card.add_child(margin)

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 3 if short_screen else 5)
		margin.add_child(content)

		var feature_label := _make_label(feature_name.to_upper(), 9 if short_screen else (10 if compact else 12), Color.WHITE)
		feature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feature_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		feature_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feature_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		feature_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(feature_label)

		var dummy_button := Button.new()
		dummy_button.name = "DummyFeatureButton"
		dummy_button.text = "SELECT"
		dummy_button.custom_minimum_size.y = 25 if short_screen else 32
		dummy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(dummy_button, 11 if short_screen else 12)
		_style_staff_button(dummy_button, false)
		# Intentionally no pressed signal: these are placeholder buttons for now.
		content.add_child(dummy_button)

	# Keep every category at the same row count as Hardware. Empty trailing
	# cells preserve the Hardware card height without stretching shorter grids.
	if grid_prefix != "Hardware":
		var hardware_row_count := ceili(24.0 / float(columns))
		var target_grid_slots := hardware_row_count * columns
		var spacer_count := maxi(0, target_grid_slots - features.size())
		for spacer_index in range(spacer_count):
			var spacer := Control.new()
			spacer.name = grid_prefix + "ResearchEmptySlot" + str(spacer_index + 1)
			spacer.custom_minimum_size = Vector2(0, card_height)
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(spacer)


func _build_extras_research_content(parent: Control, compact: bool) -> void:
	_build_research_feature_grid(parent, compact, "EXTRAS & ACCESSORIES", "Extras", _get_extras_research_features())



func _build_research_view_selector(parent: Control, compact: bool) -> void:
	var selector := HBoxContainer.new()
	selector.name = "PhoneResearchDepartmentSelector"
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.alignment = BoxContainer.ALIGNMENT_END
	selector.add_theme_constant_override("separation", 7 if compact else 10)
	parent.add_child(selector)

	for view_name in ["HARDWARE", "SOFTWARE", "EXTRAS"]:
		var button := Button.new()
		button.text = view_name
		button.custom_minimum_size = Vector2(112 if compact else 148, 40 if compact else 46)
		_apply_research_typography(button, 12 if compact else 14)
		_style_staff_button(button, research_view == view_name)
		button.pressed.connect(_on_research_view_selected.bind(view_name))
		selector.add_child(button)


func _on_research_view_selected(view_name: String) -> void:
	if not ["HARDWARE", "SOFTWARE", "EXTRAS"].has(view_name):
		return
	if research_view == view_name:
		return
	research_view = view_name
	if is_instance_valid(research_content_panel):
		_build_design_research_content(research_content_panel)


func _refresh_design_research_cards() -> void:
	for research_id in research_item_cards:
		var entry: Dictionary = research_item_cards[research_id]
		var level := clampi(int(research_levels.get(research_id, 1)), 1, 20)
		var cost := 250000.0 * float(level)
		var level_label: Label = entry["level"]
		var upgrade_button: Button = entry["button"]
		level_label.text = "CURRENT LEVEL: %d / 20" % level
		if level >= 20:
			upgrade_button.text = "MAXIMUM LEVEL"
			upgrade_button.disabled = true
		else:
			upgrade_button.text = "UPGRADE TO %d  •  %s" % [level + 1, _format_research_money(cost)]
			upgrade_button.disabled = research_balance < cost


func _format_research_money(amount: float) -> String:
	var digits := str(roundi(amount))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted


func _on_design_research_upgrade_pressed(research_id: String) -> void:
	research_upgrade_requested.emit(research_id)


func _make_staff_style_card() -> PanelContainer:
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


func _style_staff_button(button: Button, primary: bool) -> void:
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
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#a9c9dc"))


func _style_staff_back_button(button: Button) -> void:
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
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)


func _make_tools_card(card_name: String, include_controls: bool) -> PanelContainer:
	var tools_panel := _make_glass_panel(Color(0.28, 0.61, 0.80, 0.30))
	tools_panel.name = card_name
	tools_panel.custom_minimum_size.x = 273
	tools_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if not include_controls:
		return tools_panel

	var tools_scroll := ScrollContainer.new()
	tools_scroll.name = card_name + "Scroll"
	left_tools_scroll = tools_scroll
	tools_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var vertical_bar := tools_scroll.get_v_scroll_bar()
	vertical_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	vertical_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools_panel.add_child(tools_scroll)

	var tools_content := VBoxContainer.new()
	tools_content.name = card_name + "Pages"
	tools_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tools_content.add_theme_constant_override("separation", 8)
	tools_content.mouse_filter = Control.MOUSE_FILTER_PASS
	tools_scroll.add_child(tools_content)

	var page_feature_lists := [
		_get_hardware_research_features(),
		_get_software_research_features(),
		_get_extras_research_features()
	]
	for page_index in range(page_feature_lists.size()):
		var page_grid := GridContainer.new()
		page_grid.name = card_name + "ButtonPage" + str(page_index + 1)
		page_grid.columns = 2
		page_grid.mouse_filter = Control.MOUSE_FILTER_PASS
		page_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		page_grid.add_theme_constant_override("h_separation", 8)
		page_grid.add_theme_constant_override("v_separation", 8)
		page_grid.visible = page_index == 0
		tools_content.add_child(page_grid)

		for feature_name in page_feature_lists[page_index]:
			_add_tool_button(page_grid, str(feature_name))

	left_tools_page = 0
	return tools_panel


func _make_glass_panel(fill_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = Color(0.86, 0.97, 1.0, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.16, 0.34, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = true
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _get_preview_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PhonePreviewViewport"
	viewport.size = Vector2i(1200, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.13, 0.22, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c7e8ff")
	environment.ambient_light_energy = 0.24
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var preview_world := Node3D.new()
	preview_world.name = "PhonePreviewWorld"
	viewport.add_child(preview_world)

	phone_body = MeshInstance3D.new()
	phone_body.name = "Plain_Phone_Body"
	phone_body.mesh = _create_rounded_phone_mesh(0.0, PackedVector2Array())
	var body_material := StandardMaterial3D.new()
	# Use a restrained silver-white base. Preview lighting is balanced below
	# so the rendered face keeps this colour instead of clipping to pure white.
	body_material.albedo_color = Color("#a5adb6")
	body_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	body_material.metallic = 0.0
	body_material.roughness = 0.94
	# This is a closed solid mesh with outward-facing, correctly wound
	# triangles. Cull its back faces instead of shading interior backfaces
	# with automatically inverted normals.
	body_material.cull_mode = BaseMaterial3D.CULL_BACK
	phone_body.material_override = body_material
	_refresh_phone_side_buttons()
	_refresh_phone_home_button()
	_refresh_phone_screen()
	# The preview contains only the phone body, so it has no useful external
	# shadow to cast. Prevent the custom rounded perimeter from self-shadowing
	# and producing large shadow-map artifacts as its radius changes.
	phone_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview_world.add_child(phone_body)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	# Keep the key light soft enough to avoid a sharp reflected streak
	# across the silver-white front face.
	key_light.light_energy = 0.62
	key_light.shadow_enabled = true
	preview_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#83cfff")
	# A restrained fill preserves edge definition without adding a
	# second bright reflection across the body.
	fill_light.light_energy = 0.12
	fill_light.omni_range = 8.0
	preview_world.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0.0, 0.0, 5.2)
	preview_camera.current = true
	preview_camera.fov = 38.0
	preview_world.add_child(preview_camera)
	return viewport


func _add_tool_button(parent: GridContainer, feature_name: String) -> void:
	var button := Button.new()
	button.text = "SCREEN WIDTH\nWAITING" if feature_name == "Screen Width" else feature_name
	button.tooltip_text = "Screen width adjustment — waiting" if feature_name == "Screen Width" else feature_name
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Make feature names larger and heavier while keeping the app's STIX font.
	var button_font := FontVariation.new()
	button_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	button_font.variation_embolden = 1.2
	button.add_theme_font_override("font", button_font)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.60, 0.84, 0.96, 0.25)
		if state == "hover":
			style.bg_color = Color(0.76, 0.92, 1.0, 0.38)
		elif state == "pressed" or state == "focus":
			style.bg_color = Color(0.60, 0.84, 0.96, 0.25)
		style.border_color = Color(0.91, 0.98, 1.0, 0.92)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		button.add_theme_stylebox_override(state, style)
	if feature_name in ["Screen Tech", "Screen Size", "Screen Type", "Border Radius", "Thickness", "Speakers", "Charge Port", "Power/Volume Buttons", "Home Button"]:
		button.pressed.connect(_on_tool_feature_pressed.bind(feature_name))
	# Other feature buttons remain untouched until their systems are implemented.
	parent.add_child(button)


func _on_tool_feature_pressed(feature_name: String) -> void:
	if feature_name == "Screen Tech":
		_show_screen_tech_controls()
	elif feature_name == "Screen Size":
		_show_screen_size_controls()
	elif feature_name == "Screen Type":
		_show_screen_type_controls()
	elif feature_name == "Border Radius":
		_show_border_radius_controls()
	elif feature_name == "Thickness":
		_show_thickness_controls()
	elif feature_name == "Speakers":
		_show_speaker_controls()
	elif feature_name == "Charge Port":
		_show_charge_port_controls()
	elif feature_name == "Power/Volume Buttons":
		_show_power_volume_controls()
	elif feature_name == "Home Button":
		_show_home_button_controls()



func _show_screen_size_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ScreenSizeControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 12)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("SCREEN SIZE", 18, Color("#c7eaff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var explanation := _make_label("Adjust the display width and height independently.", 12, Color("#d8eaf5"))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(explanation)

	var sliders_row := HBoxContainer.new()
	sliders_row.name = "ScreenSizeSliders"
	sliders_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sliders_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sliders_row.add_theme_constant_override("separation", 8)
	active_feature_panel.add_child(sliders_row)

	var width_column := VBoxContainer.new()
	width_column.name = "ScreenWidthColumn"
	width_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	width_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	width_column.alignment = BoxContainer.ALIGNMENT_CENTER
	width_column.add_theme_constant_override("separation", 6)
	sliders_row.add_child(width_column)

	var width_heading := _make_label("WIDTH", 13, Color.WHITE)
	width_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	width_column.add_child(width_heading)

	bezel_width_value_label = _make_label("", 11, Color("#d8eaf5"))
	bezel_width_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	width_column.add_child(bezel_width_value_label)

	var width_slider := VSlider.new()
	width_slider.name = "ScreenWidthSlider"
	width_slider.min_value = 0.02
	width_slider.max_value = 0.15
	width_slider.step = 0.001
	width_slider.value = 0.17 - clampf(bezel_width, 0.02, 0.15)
	width_slider.tick_count = 14
	width_slider.custom_minimum_size = Vector2(64, 250)
	width_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	width_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	width_slider.value_changed.connect(_on_bezel_width_changed)
	_style_feature_slider(width_slider)
	width_column.add_child(width_slider)

	var height_column := VBoxContainer.new()
	height_column.name = "ScreenHeightColumn"
	height_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	height_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	height_column.alignment = BoxContainer.ALIGNMENT_CENTER
	height_column.add_theme_constant_override("separation", 6)
	sliders_row.add_child(height_column)

	var height_heading := _make_label("HEIGHT", 13, Color.WHITE)
	height_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height_column.add_child(height_heading)

	bezel_height_value_label = _make_label("", 11, Color("#d8eaf5"))
	bezel_height_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height_column.add_child(bezel_height_value_label)

	var height_slider := VSlider.new()
	height_slider.name = "ScreenHeightSlider"
	height_slider.min_value = 0.02
	height_slider.max_value = 0.325
	height_slider.step = 0.001
	height_slider.value = 0.345 - clampf(bezel_height, 0.02, 0.325)
	height_slider.tick_count = 14
	height_slider.custom_minimum_size = Vector2(64, 250)
	height_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	height_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	height_slider.value_changed.connect(_on_bezel_height_changed)
	_style_feature_slider(height_slider)
	height_column.add_child(height_slider)

	bezel_width = 0.17 - width_slider.value
	bezel_height = 0.345 - height_slider.value
	_update_bezel_value_labels()
	_refresh_screen_type_controls()


func _on_bezel_width_changed(value: float) -> void:
	# The slider represents screen size: moving it up must reduce the bezel.
	bezel_width = clampf(0.17 - value, 0.02, 0.15)
	_update_bezel_value_labels()
	_refresh_phone_screen()
	_refresh_screen_type_controls()


func _on_bezel_height_changed(value: float) -> void:
	# The slider represents screen size: moving it up must reduce the bezel.
	bezel_height = clampf(0.345 - value, 0.02, 0.325)
	_update_bezel_value_labels()
	_refresh_phone_screen()
	_refresh_screen_type_controls()


func _update_bezel_value_labels() -> void:
	# PHONE_SIZE maps to an approximately 75 mm-wide handset.
	const MODEL_UNITS_TO_MM := 75.0 / 1.45
	if is_instance_valid(bezel_width_value_label):
		bezel_width_value_label.text = "%.1f mm" % ((PHONE_SIZE.x - bezel_width * 2.0) * MODEL_UNITS_TO_MM)
	if is_instance_valid(bezel_height_value_label):
		bezel_height_value_label.text = "%.1f mm" % ((PHONE_SIZE.y - bezel_height * 2.0) * MODEL_UNITS_TO_MM)


func _show_screen_type_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ScreenTypeControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 12)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("SCREEN TYPE", 18, Color("#c7eaff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)
	var description := _make_label("Choose a flat display or a curved edge design.", 12, Color("#d8eaf5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	var choices := VBoxContainer.new()
	choices.name = "ScreenShapeChoices"
	choices.add_theme_constant_override("separation", 8)
	active_feature_panel.add_child(choices)
	screen_shape_buttons.clear()
	for mode in ["Flat screen", "Curve screen"]:
		var option := Button.new()
		option.name = mode.replace(" ", "") + "Option"
		option.text = mode
		option.custom_minimum_size = Vector2(0, 44)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		option.toggle_mode = true
		option.button_pressed = screen_shape_mode == mode
		_apply_research_typography(option, 13)
		_style_screen_type_option(option, 0 if mode == "Flat screen" else 5, screen_shape_mode == mode)
		option.pressed.connect(_on_screen_shape_selected.bind(mode))
		choices.add_child(option)
		screen_shape_buttons[mode] = option

	var curve_options := VBoxContainer.new()
	curve_options.name = "CurveOptions"
	curve_options.add_theme_constant_override("separation", 9)
	active_feature_panel.add_child(curve_options)

	side_curve_toggle = _make_curve_toggle("SideCurveToggle", "Side curve", side_curve_enabled)
	curve_options.add_child(side_curve_toggle)
	side_curve_toggle.toggled.connect(_on_side_curve_toggled)
	vertical_curve_toggle = _make_curve_toggle("VerticalCurveToggle", "Up & bottom curve", vertical_curve_enabled)
	curve_options.add_child(vertical_curve_toggle)
	vertical_curve_toggle.toggled.connect(_on_vertical_curve_toggled)

	_refresh_screen_type_controls()


func _make_curve_toggle(node_name: String, label_text: String, enabled: bool) -> Button:
	var toggle := Button.new()
	toggle.name = node_name
	toggle.text = ("✓  " if enabled else "□  ") + label_text
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.custom_minimum_size = Vector2(0, 40)
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(toggle, 12)
	return toggle


func _on_screen_shape_selected(mode: String) -> void:
	if mode == "Curve screen" and not (_is_screen_width_max() or _is_screen_height_max()):
		return
	screen_shape_mode = mode
	if mode == "Flat screen":
		side_curve_enabled = false
		vertical_curve_enabled = false
	_refresh_screen_type_controls()
	_refresh_phone_screen()


func _on_side_curve_toggled(enabled: bool) -> void:
	if enabled and not _is_screen_width_max():
		_refresh_screen_type_controls()
		return
	side_curve_enabled = enabled
	_refresh_screen_type_controls()
	_refresh_phone_screen()


func _on_vertical_curve_toggled(enabled: bool) -> void:
	if enabled and not _is_screen_height_max():
		_refresh_screen_type_controls()
		return
	vertical_curve_enabled = enabled
	_refresh_screen_type_controls()
	_refresh_phone_screen()


func _is_screen_width_max() -> bool:
	return bezel_width <= 0.0205


func _is_screen_height_max() -> bool:
	return bezel_height <= 0.0205


func _refresh_screen_type_controls() -> void:
	if not is_instance_valid(active_feature_panel) or active_feature_panel.name != "ScreenTypeControls":
		return
	var width_max := _is_screen_width_max()
	var height_max := _is_screen_height_max()
	var curve_allowed := width_max or height_max
	if screen_shape_mode == "Curve screen" and not curve_allowed:
		screen_shape_mode = "Flat screen"
		side_curve_enabled = false
		vertical_curve_enabled = false
	for mode in screen_shape_buttons:
		var option: Button = screen_shape_buttons[mode]
		option.button_pressed = screen_shape_mode == mode
		option.disabled = mode == "Curve screen" and not curve_allowed
		_style_screen_type_option(option, 0 if mode == "Flat screen" else 5, screen_shape_mode == mode)
	if is_instance_valid(side_curve_toggle):
		side_curve_toggle.disabled = screen_shape_mode != "Curve screen" or not width_max
		side_curve_toggle.button_pressed = side_curve_enabled
		side_curve_toggle.text = ("✓  " if side_curve_enabled else "□  ") + "Side curve"
	if is_instance_valid(vertical_curve_toggle):
		vertical_curve_toggle.disabled = screen_shape_mode != "Curve screen" or not height_max
		vertical_curve_toggle.button_pressed = vertical_curve_enabled
		vertical_curve_toggle.text = ("✓  " if vertical_curve_enabled else "□  ") + "Up & bottom curve"


func _show_screen_tech_controls() -> void:
	# Remove the full-height empty-state hint and any previous feature controls
	# so Screen Tech starts at the top of the right-hand panel.
	for child in right_tools_content.get_children():
		right_tools_content.remove_child(child)
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ScreenTechControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("SCREEN TECHNOLOGY", 18, Color("#c7eaff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	# Custom checkbox: a compact toggle square beside its label, styled to
	# match the editor rather than using Godot's default CheckBox artwork.
	var enable_row := HBoxContainer.new()
	enable_row.name = "ScreenEnablementRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 9)
	active_feature_panel.add_child(enable_row)

	var enable_toggle := Button.new()
	enable_toggle.name = "ScreenEnablement"
	enable_toggle.toggle_mode = true
	enable_toggle.button_pressed = screen_enabled
	enable_toggle.text = "✓" if screen_enabled else ""
	enable_toggle.custom_minimum_size = Vector2(30, 30)
	enable_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enable_toggle.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(enable_toggle, 17)
	for state in ["normal", "hover", "pressed", "focus"]:
		var toggle_style := StyleBoxFlat.new()
		toggle_style.bg_color = Color("#17415b") if state != "hover" else Color("#205a78")
		if state == "pressed" or state == "focus":
			toggle_style.bg_color = Color("#147eaa")
		toggle_style.border_color = Color("#8fd8ff")
		toggle_style.set_border_width_all(2)
		toggle_style.set_corner_radius_all(7)
		enable_toggle.add_theme_stylebox_override(state, toggle_style)
	enable_toggle.add_theme_color_override("font_color", Color.WHITE)
	enable_toggle.toggled.connect(_on_screen_enablement_toggled)
	enable_row.add_child(enable_toggle)

	var enable_label := _make_label("Screen Enablement", 14, Color.WHITE)
	enable_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enable_row.add_child(enable_label)

	var type_grid := GridContainer.new()
	type_grid.name = "ScreenTypeOptions"
	type_grid.columns = 1
	type_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_grid.add_theme_constant_override("h_separation", 7)
	type_grid.add_theme_constant_override("v_separation", 7)
	active_feature_panel.add_child(type_grid)

	screen_type_buttons.clear()
	for index in range(SCREEN_TYPE_ORDER.size()):
		var type_name: String = SCREEN_TYPE_ORDER[index]
		var option := Button.new()
		option.name = "ScreenType_" + type_name.replace(" ", "").replace("-", "")
		option.text = "%02d   %s" % [index + 1, type_name]
		option.custom_minimum_size = Vector2(0, 42.0)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(option, 12)
		_style_screen_type_option(option, index, type_name == selected_screen_type)
		option.pressed.connect(_on_screen_type_selected.bind(type_name))
		type_grid.add_child(option)
		screen_type_buttons[type_name] = option
	_refresh_screen_type_buttons()

func _on_screen_enablement_toggled(enabled: bool) -> void:
	screen_enabled = enabled
	_refresh_phone_screen()
	var toggle := active_feature_panel.get_node_or_null("ScreenEnablementRow/ScreenEnablement") if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(toggle):
		toggle.text = "✓" if enabled else ""
	_refresh_screen_type_buttons()


func _on_screen_type_selected(type_name: String) -> void:
	selected_screen_type = type_name
	_refresh_phone_screen()
	_refresh_screen_type_buttons()


func _style_screen_type_option(option: Button, rank: int, selected: bool) -> void:
	var tier_colors := [
		Color("#315064"), Color("#2c485c"), Color("#273f54"), Color("#20364b"),
		Color("#192d42"), Color("#14263a"), Color("#102136"), Color("#0c1c30"),
		Color("#09172a"), Color("#071426")
	]
	var accent := Color("#79b9d8").lerp(Color("#b9a0ff"), float(rank) / 9.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tier_colors[rank]
		if selected:
			style.bg_color = tier_colors[rank].lightened(0.24)
		if state == "hover":
			style.bg_color = tier_colors[rank].lightened(0.16)
		elif state == "pressed":
			style.bg_color = tier_colors[rank].lightened(0.30)
		elif state == "disabled":
			style.bg_color = tier_colors[rank].darkened(0.25)
		style.border_color = accent if not selected else Color("#e4f7ff")
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.10, 0.22, 0.38)
		style.shadow_size = 9 if selected else 5
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		option.add_theme_stylebox_override(state, style)
	option.add_theme_color_override("font_color", Color.WHITE)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_pressed_color", Color.WHITE)
	option.add_theme_color_override("font_disabled_color", Color("#8da8b8"))


func _refresh_screen_type_buttons() -> void:
	for index in range(SCREEN_TYPE_ORDER.size()):
		var type_name: String = SCREEN_TYPE_ORDER[index]
		if not screen_type_buttons.has(type_name):
			continue
		var option: Button = screen_type_buttons[type_name]
		_style_screen_type_option(option, index, type_name == selected_screen_type)
		option.disabled = not screen_enabled


func _create_rounded_panel_mesh(width: float, height: float, depth: float, corner_radius: float) -> Mesh:
	# A true rounded-rectangle extrusion keeps the glass and button outlines
	# smooth instead of placing square BoxMeshes over the curved phone face.
	var half_width := width * 0.5
	var half_height := height * 0.5
	var radius := clampf(corner_radius, 0.001, minf(half_width, half_height))
	var centers := [
		Vector2(half_width - radius, half_height - radius),
		Vector2(-half_width + radius, half_height - radius),
		Vector2(-half_width + radius, -half_height + radius),
		Vector2(half_width - radius, -half_height + radius)
	]
	var outline := PackedVector2Array()
	for corner_index in range(4):
		var center: Vector2 = centers[corner_index]
		var start_angle := float(corner_index) * PI * 0.5
		for segment in range(8):
			var angle := start_angle + float(segment) / 8.0 * PI * 0.5
			outline.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		var fallback := BoxMesh.new()
		fallback.size = Vector3(width, height, depth)
		return fallback
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front_z := depth * 0.5
	var back_z := -depth * 0.5
	for index in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var c: Vector2 = outline[indices[index + 2]]
		_add_phone_mesh_triangle(surface, Vector3(a.x, a.y, front_z), Vector3(b.x, b.y, front_z), Vector3(c.x, c.y, front_z), Vector3.BACK)
		_add_phone_mesh_triangle(surface, Vector3(a.x, a.y, back_z), Vector3(c.x, c.y, back_z), Vector3(b.x, b.y, back_z), Vector3.FORWARD)
	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[next_index]
		var edge := b - a
		var normal := Vector3(edge.y, -edge.x, 0.0).normalized()
		var front_a := Vector3(a.x, a.y, front_z)
		var front_b := Vector3(b.x, b.y, front_z)
		var back_a := Vector3(a.x, a.y, back_z)
		var back_b := Vector3(b.x, b.y, back_z)
		_add_phone_mesh_triangle(surface, front_a, back_a, back_b, normal)
		_add_phone_mesh_triangle(surface, front_a, back_b, front_b, normal)
	return surface.commit()


func _create_curved_screen_mesh(width: float, height: float, _corner_radius: float, curve_sides: bool, curve_vertical: bool) -> ArrayMesh:
	# Subdivided glass surface: the selected edges gently roll down toward the
	# handset frame instead of ending as a flat panel.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const X_SEGMENTS := 24
	const Y_SEGMENTS := 40
	const SIDE_BEND := 0.028
	const VERTICAL_BEND := 0.028
	var points: Array[Vector3] = []
	for y_index in range(Y_SEGMENTS + 1):
		var v := float(y_index) / float(Y_SEGMENTS)
		var y := (0.5 - v) * height
		for x_index in range(X_SEGMENTS + 1):
			var u := float(x_index) / float(X_SEGMENTS)
			var x := (u - 0.5) * width
			var z := 0.0
			if curve_sides:
				z -= SIDE_BEND * pow(abs(x / maxf(width * 0.5, 0.001)), 6.0)
			if curve_vertical:
				z -= VERTICAL_BEND * pow(abs(y / maxf(height * 0.5, 0.001)), 6.0)
			points.append(Vector3(x, y, z))
	for y_index in range(Y_SEGMENTS):
		for x_index in range(X_SEGMENTS):
			var top_left := y_index * (X_SEGMENTS + 1) + x_index
			var top_right := top_left + 1
			var bottom_left := top_left + X_SEGMENTS + 1
			var bottom_right := bottom_left + 1
			surface.add_vertex(points[top_left])
			surface.add_vertex(points[bottom_left])
			surface.add_vertex(points[top_right])
			surface.add_vertex(points[top_right])
			surface.add_vertex(points[bottom_left])
			surface.add_vertex(points[bottom_right])
	surface.generate_normals()
	return surface.commit()


func _refresh_phone_screen() -> void:
	if not is_instance_valid(phone_body):
		return
	var previous := phone_body.get_node_or_null("PhoneDisplayPanel")
	if is_instance_valid(previous):
		previous.free()
	phone_screen = null
	if not screen_enabled:
		return

	var display := MeshInstance3D.new()
	display.name = "PhoneDisplayPanel"
	# Keep a consistent, slimmer lower rail for physical keys and give the
	# top rail the exact same height. The glass is inset evenly on all sides.
	# Symmetrical bezels consume the outer edges; the display fills the remaining area.
	var screen_width := PHONE_SIZE.x if screen_shape_mode == "Curve screen" and side_curve_enabled else maxf(0.30, PHONE_SIZE.x - bezel_width * 2.0)
	var screen_height := PHONE_SIZE.y if screen_shape_mode == "Curve screen" and vertical_curve_enabled else maxf(0.60, PHONE_SIZE.y - bezel_height * 2.0)
	var screen_radius := maxf(0.018, 0.32 * float(border_radius_level) / 6.0 - 0.04)
	if screen_shape_mode == "Curve screen" and (side_curve_enabled or vertical_curve_enabled):
		display.mesh = _create_curved_screen_mesh(screen_width, screen_height, screen_radius, side_curve_enabled, vertical_curve_enabled)
	else:
		display.mesh = _create_rounded_panel_mesh(screen_width, screen_height, 0.006, screen_radius)

	var display_material := StandardMaterial3D.new()
	display_material.metallic = 0.02
	display_material.roughness = 0.20
	display_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	display_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The panel gets progressively darker as the technology tier rises.
	# Flagship OLED-family and MicroLED finishes stay close in tone but use
	# lower roughness and stronger specular response for a polished black-glass look.
	var screen_colors := {
		"TFT LCD": Color("#263746"),
		"LED-LCD": Color("#223342"),
		"IPS LCD": Color("#1d2d3d"),
		"Mini-LED LCD": Color("#172535"),
		"OLED": Color("#111b28"),
		"AMOLED": Color("#0e1723"),
		"Super AMOLED": Color("#0b131f"),
		"Dynamic AMOLED": Color("#09111d"),
		"LTPO AMOLED": Color("#080f1b"),
		"MicroLED": Color("#070d18")
	}
	var screen_roughness := {
		"TFT LCD": 0.30,
		"LED-LCD": 0.27,
		"IPS LCD": 0.24,
		"Mini-LED LCD": 0.19,
		"OLED": 0.15,
		"AMOLED": 0.11,
		"Super AMOLED": 0.075,
		"Dynamic AMOLED": 0.060,
		"LTPO AMOLED": 0.045,
		"MicroLED": 0.035
	}
	display_material.albedo_color = screen_colors.get(selected_screen_type, Color("#0e1723"))
	display_material.roughness = screen_roughness.get(selected_screen_type, 0.12)
	display_material.metallic = 0.18 if selected_screen_type in ["Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"] else 0.04
	display_material.metallic_specular = 0.85 if selected_screen_type in ["Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"] else 0.55
	display_material.emission_enabled = true
	display_material.emission = display_material.albedo_color
	display_material.emission_energy_multiplier = 0.025
	display.material_override = display_material
	var current_depth := lerpf(PHONE_SIZE.z, 0.08, float(phone_thickness_level) / 10.0)
	display.position = Vector3(0.0, 0.0, current_depth * 0.5 + 0.0035)
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	phone_body.add_child(display)
	phone_screen = display
	if home_button_enabled and home_button_type == "On-screen":
		# Keep the on-screen navigation control generic; OS-specific styles
		# are intentionally reserved for the later operating-system system.
		var home_indicator := MeshInstance3D.new()
		home_indicator.name = "GenericOnScreenHomeIndicator"
		var indicator_mesh := BoxMesh.new()
		indicator_mesh.size = Vector3(0.18, 0.018, 0.002)
		home_indicator.mesh = indicator_mesh
		var indicator_material := StandardMaterial3D.new()
		indicator_material.albedo_color = Color(0.88, 0.94, 1.0, 0.88)
		indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		indicator_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		indicator_material.roughness = 0.8
		home_indicator.material_override = indicator_material
		home_indicator.position = Vector3(0.0, -screen_height * 0.5 + 0.075, 0.004)
		home_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		display.add_child(home_indicator)


func _style_feature_slider(meter: VSlider) -> void:
	# A high-contrast vertical track and a large silver-blue draggable thumb.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#173d59")
	track.border_color = Color("#8fd8ff")
	track.set_border_width_all(2)
	track.set_corner_radius_all(8)
	track.content_margin_left = 5
	track.content_margin_right = 5
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	meter.add_theme_stylebox_override("slider", track)

	var grabber_gradient := Gradient.new()
	grabber_gradient.set_color(0, Color("#f4fbff"))
	grabber_gradient.set_color(1, Color("#65bce9"))
	var grabber_texture := GradientTexture2D.new()
	grabber_texture.gradient = grabber_gradient
	grabber_texture.width = 28
	grabber_texture.height = 28
	grabber_texture.fill_from = Vector2(0.0, 0.0)
	grabber_texture.fill_to = Vector2(1.0, 1.0)
	meter.add_theme_icon_override("grabber", grabber_texture)
	meter.add_theme_icon_override("grabber_highlight", grabber_texture)
	meter.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	meter.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	meter.focus_mode = Control.FOCUS_NONE
	meter.mouse_filter = Control.MOUSE_FILTER_STOP
	meter.editable = true


func _show_border_radius_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BorderRadiusControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 14)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("BORDER RADIUS", 19, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var description := _make_label("Adjust the curvature of the phone's outer corners", 12, Color("#c7eaff"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	var meter_row := HBoxContainer.new()
	meter_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_row.add_theme_constant_override("separation", 12)
	active_feature_panel.add_child(meter_row)

	var level_labels := VBoxContainer.new()
	level_labels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_labels.alignment = BoxContainer.ALIGNMENT_CENTER
	level_labels.add_theme_constant_override("separation", 0)
	meter_row.add_child(level_labels)

	for level in range(6, -1, -1):
		var level_label := _make_label(str(level), 14, Color("#d8f1ff"))
		level_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_labels.add_child(level_label)

	var meter := VSlider.new()
	meter.name = "BorderRadiusLevelMeter"
	meter.min_value = 0
	meter.max_value = 6
	meter.step = 1
	meter.value = border_radius_level
	meter.tick_count = 7
	meter.custom_minimum_size = Vector2(76, 290)
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.value_changed.connect(_on_border_radius_level_changed)
	_style_feature_slider(meter)
	meter_row.add_child(meter)

	border_radius_value_label = _make_label("LEVEL %d / 6" % border_radius_level, 16, Color("#a9e3ff"))
	border_radius_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(border_radius_value_label)



func _show_thickness_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ThicknessControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 14)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("PHONE THICKNESS", 19, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var description := _make_label("Make the phone body slimmer or thicker", 12, Color("#c7eaff"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	var meter_row := HBoxContainer.new()
	meter_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_row.add_theme_constant_override("separation", 12)
	active_feature_panel.add_child(meter_row)

	var level_labels := VBoxContainer.new()
	level_labels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_labels.alignment = BoxContainer.ALIGNMENT_CENTER
	level_labels.add_theme_constant_override("separation", 0)
	meter_row.add_child(level_labels)

	for level in range(10, -1, -1):
		var level_label := _make_label(str(level), 14, Color("#d8f1ff"))
		level_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_labels.add_child(level_label)

	var meter := VSlider.new()
	meter.name = "PhoneThicknessLevelMeter"
	meter.min_value = 0
	meter.max_value = 10
	meter.step = 1
	meter.value = phone_thickness_level
	meter.tick_count = 11
	meter.custom_minimum_size = Vector2(64, 290)
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.value_changed.connect(_on_phone_thickness_level_changed)
	_style_feature_slider(meter)
	meter_row.add_child(meter)

	phone_thickness_value_label = _make_label("LEVEL %d / 10" % phone_thickness_level, 16, Color("#a9e3ff"))
	phone_thickness_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(phone_thickness_value_label)


func _show_power_volume_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "PowerVolumeControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 12)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("POWER & VOLUME", 22, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	_add_side_button_controls("POWER BUTTON", "right", power_button_enabled, power_button_y)
	_add_side_button_controls("VOLUME ROCKER", "left", volume_button_enabled, volume_button_y)

	var divider := HSeparator.new()
	active_feature_panel.add_child(divider)
	var length_title := _make_label("BUTTON LENGTH", 17, Color("#d8f1ff"))
	length_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(length_title)
	var length_slider := HSlider.new()
	length_slider.name = "BothSideButtonLengthSlider"
	length_slider.min_value = 0.55
	length_slider.max_value = 1.35
	length_slider.step = 0.05
	length_slider.value = side_button_length_scale
	length_slider.custom_minimum_size = Vector2(0, 54)
	length_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	length_slider.value_changed.connect(_on_side_button_length_changed)
	_style_horizontal_feature_slider(length_slider)
	active_feature_panel.add_child(length_slider)
	side_button_length_label = _make_label("LENGTH  %d%%" % roundi(side_button_length_scale * 100.0), 17, Color("#a9e3ff"))
	side_button_length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(side_button_length_label)


func _show_home_button_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "HomeButtonControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("HOME BUTTON", 19, Color("#c7eaff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var enable_row := HBoxContainer.new()
	enable_row.name = "HomeButtonEnablementRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 9)
	active_feature_panel.add_child(enable_row)

	var enable_toggle := Button.new()
	enable_toggle.name = "HomeButtonEnablement"
	enable_toggle.toggle_mode = true
	enable_toggle.button_pressed = home_button_enabled
	enable_toggle.text = "✓" if home_button_enabled else ""
	enable_toggle.custom_minimum_size = Vector2(30, 30)
	enable_toggle.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(enable_toggle, 17)
	for state in ["normal", "hover", "pressed", "focus"]:
		var toggle_style := StyleBoxFlat.new()
		toggle_style.bg_color = Color("#17415b") if state != "hover" else Color("#205a78")
		if state == "pressed" or state == "focus":
			toggle_style.bg_color = Color("#147eaa")
		toggle_style.border_color = Color("#8fd8ff")
		toggle_style.set_border_width_all(2)
		toggle_style.set_corner_radius_all(7)
		enable_toggle.add_theme_stylebox_override(state, toggle_style)
	enable_toggle.add_theme_color_override("font_color", Color.WHITE)
	enable_toggle.toggled.connect(_on_home_button_enablement_toggled)
	enable_row.add_child(enable_toggle)

	var enable_label := _make_label("Home Button Enablement", 14, Color.WHITE)
	enable_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enable_row.add_child(enable_label)

	var type_grid := GridContainer.new()
	type_grid.name = "HomeButtonTypes"
	type_grid.columns = 1
	type_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_grid.add_theme_constant_override("v_separation", 7)
	active_feature_panel.add_child(type_grid)

	home_button_option_buttons.clear()
	for index in range(HOME_BUTTON_TYPES.size()):
		var type_name: String = HOME_BUTTON_TYPES[index]
		var option := Button.new()
		option.name = "HomeButton_" + type_name.replace(" ", "")
		option.text = type_name
		option.custom_minimum_size = Vector2(0, 44)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(option, 13)
		_style_screen_type_option(option, mini(index, 9), type_name == home_button_type)
		option.pressed.connect(_on_home_button_type_selected.bind(type_name))
		option.disabled = not home_button_enabled
		type_grid.add_child(option)
		home_button_option_buttons[type_name] = option


func _on_home_button_enablement_toggled(enabled: bool) -> void:
	home_button_enabled = enabled
	_refresh_phone_home_button()
	if home_button_type == "On-screen":
		_refresh_phone_screen()
	var toggle := active_feature_panel.get_node_or_null("HomeButtonEnablementRow/HomeButtonEnablement") if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(toggle):
		toggle.text = "✓" if enabled else ""
	for option_name in home_button_option_buttons:
		var option: Button = home_button_option_buttons[option_name]
		option.disabled = not enabled


func _on_home_button_type_selected(type_name: String) -> void:
	home_button_type = type_name
	_refresh_phone_home_button()
	_refresh_phone_screen()
	for option_name in home_button_option_buttons:
		var option: Button = home_button_option_buttons[option_name]
		_style_screen_type_option(option, mini(HOME_BUTTON_TYPES.find(option_name), 9), option_name == home_button_type)


func _refresh_phone_home_button() -> void:
	if not is_instance_valid(phone_body):
		return
	var previous := phone_body.get_node_or_null("PhoneHomeButton")
	if is_instance_valid(previous):
		previous.free()
	# Home controls are absent until the user explicitly enables them.
	if not home_button_enabled:
		return
	# On-screen is the only software-rendered option. The physical navigation
	# layout below is built directly on the lower hardware bezel.
	if home_button_type == "On-screen":
		return

	var button_root := Node3D.new()
	button_root.name = "PhoneHomeButton"
	phone_body.add_child(button_root)
	var center_y := -PHONE_SIZE.y * 0.5 + 0.10
	# Nudge only the circular and square physical keys very slightly upward.
	if home_button_type == "Circle Home Button" or home_button_type == "Square Home Button":
		center_y += 0.02
	var front_z := lerpf(PHONE_SIZE.z, 0.08, float(phone_thickness_level) / 10.0) * 0.5
	var button_material := StandardMaterial3D.new()
	button_material.albedo_color = Color("#89939e")
	button_material.metallic = 0.34
	button_material.roughness = 0.38
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color("#202a34")
	dark_material.metallic = 0.16
	dark_material.roughness = 0.52

	if home_button_type == "Recent · Home · Back (Physical)":
		# Classic Android hardware navigation row: Recent on the left,
		# Home in the centre, and Back on the right, all outside the display.
		var recent_material := StandardMaterial3D.new()
		recent_material.albedo_color = Color("#c5d0da")
		recent_material.roughness = 0.7
		for line_index in range(3):
			var recent_line := MeshInstance3D.new()
			recent_line.name = "RecentNavigationLine"
			var line_mesh := BoxMesh.new()
			line_mesh.size = Vector3(0.075, 0.009, 0.003)
			recent_line.mesh = line_mesh
			recent_line.position = Vector3(-0.34, center_y + (float(line_index) - 1.0) * 0.025, front_z + 0.006)
			recent_line.material_override = recent_material
			button_root.add_child(recent_line)

		var home_key := MeshInstance3D.new()
		home_key.name = "PhysicalNavigationHomeKey"
		var home_mesh := CylinderMesh.new()
		home_mesh.top_radius = 0.044
		home_mesh.bottom_radius = 0.044
		home_mesh.height = 0.006
		home_mesh.radial_segments = 32
		home_key.mesh = home_mesh
		home_key.rotation_degrees.x = 90.0
		home_key.position = Vector3(0.0, center_y, front_z + 0.007)
		home_key.material_override = recent_material
		button_root.add_child(home_key)

		for segment in range(2):
			var back_stroke := MeshInstance3D.new()
			back_stroke.name = "BackNavigationChevron"
			var stroke_mesh := BoxMesh.new()
			stroke_mesh.size = Vector3(0.055, 0.009, 0.003)
			back_stroke.mesh = stroke_mesh
			back_stroke.position = Vector3(0.34 + (0.008 if segment == 0 else -0.008), center_y + (0.018 if segment == 0 else -0.018), front_z + 0.006)
			back_stroke.rotation_degrees.z = -35.0 if segment == 0 else 35.0
			back_stroke.material_override = recent_material
			button_root.add_child(back_stroke)
		return

	if home_button_type == "Circle Home Button":
		var ring := MeshInstance3D.new()
		ring.name = "RoundHomeButtonBezel"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.092
		ring_mesh.bottom_radius = 0.092
		ring_mesh.height = 0.014
		ring_mesh.radial_segments = 48
		ring.mesh = ring_mesh
		ring.rotation_degrees.x = 90.0
		ring.position = Vector3(0.0, center_y, front_z + 0.006)
		ring.material_override = button_material
		button_root.add_child(ring)
		var face := MeshInstance3D.new()
		face.name = "RoundHomeButtonFace"
		var face_mesh := CylinderMesh.new()
		face_mesh.top_radius = 0.073
		face_mesh.bottom_radius = 0.073
		face_mesh.height = 0.010
		face_mesh.radial_segments = 48
		face.mesh = face_mesh
		face.rotation_degrees.x = 90.0
		face.position = Vector3(0.0, center_y, front_z + 0.014)
		face.material_override = dark_material
		button_root.add_child(face)
	else:
		# The oval follows the OPPO F1s-style pill; the square is a distinct
		# squared physical key. Both sit entirely within the lower bezel.
		var backing := MeshInstance3D.new()
		backing.name = "HomeButtonBezel"
		var is_oval := home_button_type == "Oval Home Button"
		var is_square := home_button_type == "Square Home Button"
		var backing_width := 0.25 if is_oval else 0.15
		var backing_height := 0.105 if is_oval else 0.15
		var backing_radius := backing_height * 0.48 if is_oval else (0.012 if is_square else 0.035)
		backing.mesh = _create_rounded_panel_mesh(backing_width, backing_height, 0.012, backing_radius)
		backing.position = Vector3(0.0, center_y, front_z + 0.004)
		backing.material_override = button_material
		button_root.add_child(backing)

		var face := MeshInstance3D.new()
		face.name = "HomeButtonFace"
		var face_width := 0.21 if is_oval else 0.11
		var face_height := 0.065 if is_oval else 0.11
		var face_radius := face_height * 0.48 if is_oval else (0.008 if is_square else 0.026)
		face.mesh = _create_rounded_panel_mesh(face_width, face_height, 0.010, face_radius)
		face.position = Vector3(0.0, center_y, front_z + 0.012)
		face.material_override = dark_material
		button_root.add_child(face)


func _make_side_button_checkbox_icon(checked: bool) -> Texture2D:
	var image := Image.new()
	var svg := ""
	if checked:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect x="2.5" y="2.5" width="31" height="31" rx="7" fill="#72c9f4" fill-opacity="0.30" stroke="#dff6ff" stroke-width="2.5"/><path d="M9 18.5l6 6L27.5 12" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/></svg>"""
	else:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect x="2.5" y="2.5" width="31" height="31" rx="7" fill="#d8f2ff" fill-opacity="0.10" stroke="#dff6ff" stroke-width="2.5"/></svg>"""
	var error := image.load_svg_from_string(svg)
	if error != OK:
		push_warning("Could not create side-button checkbox icon")
		return null
	return ImageTexture.create_from_image(image)


func _add_side_button_controls(caption: String, side: String, enabled: bool, position_y: float) -> void:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Keep the complete control stack inside the panel on compact screens.
	# The panel's own margins are additional to the VBox content height.
	section.custom_minimum_size = Vector2(0.0, 184.0)
	var section_style := StyleBoxFlat.new()
	section_style.bg_color = Color(0.20, 0.48, 0.66, 0.25)
	section_style.border_color = Color(0.55, 0.80, 0.94, 0.55)
	section_style.set_border_width_all(1)
	section_style.set_corner_radius_all(12)
	section_style.content_margin_left = 12
	section_style.content_margin_right = 12
	section_style.content_margin_top = 9
	section_style.content_margin_bottom = 9
	section.add_theme_stylebox_override("panel", section_style)
	active_feature_panel.add_child(section)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.y = 158.0
	content.add_theme_constant_override("separation", 8)
	section.add_child(content)
	var heading_row := HBoxContainer.new()
	heading_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	heading_row.custom_minimum_size.y = 40.0
	heading_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(heading_row)
	var heading := _make_label(caption, 18, Color("#ffffff"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading_row.add_child(heading)
	# A dedicated TextureButton gives us a fully custom checkbox with an exact-size hit area.
	var toggle := TextureButton.new()
	toggle.name = "Custom" + ("Power" if side == "right" else "Volume") + "ButtonCheckbox"
	toggle.custom_minimum_size = Vector2(36, 36)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.pressed.connect(_on_side_button_toggle_pressed.bind(toggle, side))
	heading_row.add_child(toggle)
	var position_title := _make_label("VERTICAL POSITION", 14, Color("#c7eaff"))
	position_title.custom_minimum_size.y = 22.0
	content.add_child(position_title)
	var position_row := HBoxContainer.new()
	position_row.custom_minimum_size.y = 54.0
	position_row.alignment = BoxContainer.ALIGNMENT_CENTER
	position_row.add_theme_constant_override("separation", 12)
	content.add_child(position_row)
	var down := Button.new()
	down.text = "−"
	down.custom_minimum_size = Vector2(64, 54)
	_apply_research_typography(down, 27)
	_style_staff_button(down, false)
	down.pressed.connect(_on_side_button_position_step.bind(side, -1))
	position_row.add_child(down)
	var position_label := _make_label("%d%%" % roundi(position_y / 1.20 * 100.0), 17, Color("#a9e3ff"))
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position_row.add_child(position_label)
	var up := Button.new()
	up.text = "+"
	up.custom_minimum_size = Vector2(64, 54)
	_apply_research_typography(up, 27)
	_style_staff_button(up, false)
	up.pressed.connect(_on_side_button_position_step.bind(side, 1))
	position_row.add_child(up)
	if side == "right":
		power_button_position_label = position_label
	else:
		volume_button_position_label = position_label


func _on_side_button_toggle_pressed(toggle: TextureButton, side: String) -> void:
	_on_side_button_toggled(toggle.button_pressed, side)


func _on_side_button_toggled(enabled: bool, side: String) -> void:
	if side == "right":
		power_button_enabled = enabled
	else:
		volume_button_enabled = enabled
	_refresh_phone_side_buttons()


func _on_side_button_position_step(side: String, direction: int) -> void:
	if side == "right":
		power_button_y = clampf(power_button_y + float(direction) * 0.06, -1.20, 1.20)
		if is_instance_valid(power_button_position_label):
			power_button_position_label.text = "%d%%" % roundi(power_button_y / 1.20 * 100.0)
	else:
		volume_button_y = clampf(volume_button_y + float(direction) * 0.06, -1.20, 1.20)
		if is_instance_valid(volume_button_position_label):
			volume_button_position_label.text = "%d%%" % roundi(volume_button_y / 1.20 * 100.0)
	_refresh_phone_side_buttons()


func _on_side_button_length_changed(value: float) -> void:
	side_button_length_scale = clampf(value, 0.55, 1.35)
	if is_instance_valid(side_button_length_label):
		side_button_length_label.text = "LENGTH  %d%%" % roundi(side_button_length_scale * 100.0)
	_refresh_phone_side_buttons()


func _style_horizontal_feature_slider(meter: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#173d59")
	track.border_color = Color("#8fd8ff")
	track.set_border_width_all(2)
	track.set_corner_radius_all(8)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	meter.add_theme_stylebox_override("slider", track)
	meter.focus_mode = Control.FOCUS_NONE
	meter.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh_phone_side_buttons() -> void:
	if not is_instance_valid(phone_body):
		return
	var previous := phone_body.get_node_or_null("PhoneSideButtons")
	if is_instance_valid(previous):
		previous.free()
	var button_root := Node3D.new()
	button_root.name = "PhoneSideButtons"
	phone_body.add_child(button_root)
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color("#9da6af")
	frame_material.metallic = 0.06
	frame_material.roughness = 0.86
	var key_material := StandardMaterial3D.new()
	key_material.albedo_color = Color("#a8b0b9")
	key_material.metallic = 0.08
	key_material.roughness = 0.82
	var current_depth := lerpf(PHONE_SIZE.z, 0.08, float(phone_thickness_level) / 10.0)
	var key_radius := clampf(current_depth * 0.27, 0.018, 0.036)
	var key_length := 0.30 * side_button_length_scale
	var single_key_length := key_length * 0.46
	if power_button_enabled:
		_add_phone_side_button(button_root, "PowerButton", 1.0, power_button_y, single_key_length, key_radius, frame_material, key_material)
	if volume_button_enabled:
		# A real volume rocker is represented by two separate tactile keys.
		var rocker_gap := 0.018
		var half_key_length := single_key_length
		_add_phone_side_button(button_root, "VolumeUpButton", -1.0, volume_button_y + half_key_length * 0.52 + rocker_gap, half_key_length, key_radius, frame_material, key_material)
		_add_phone_side_button(button_root, "VolumeDownButton", -1.0, volume_button_y - half_key_length * 0.52 - rocker_gap, half_key_length, key_radius, frame_material, key_material)


func _add_phone_side_button(parent: Node3D, node_name: String, side_sign: float, position_y: float, length: float, radius: float, frame_material: Material, key_material: Material) -> void:
	# Keep the recess below the frame surface and give the actual key a
	# clearly visible, subtle 1.2 mm stand-off. The previous 0.5 mm projection
	# was too shallow to read in the 3D preview, making the buttons look flush.
	var unit_per_mm := PHONE_SIZE.y / 150.0
	var button_depth := (1.2 * unit_per_mm) / 0.95
	var button_width := maxf(radius * 1.35, 0.024)
	var side_edge := PHONE_SIZE.x * 0.5

	var backing := MeshInstance3D.new()
	backing.name = node_name + "Recess"
	var recess_mesh := BoxMesh.new()
	recess_mesh.size = Vector3(radius * 0.5, length + radius * 0.7, button_width * 1.45)
	backing.mesh = recess_mesh
	backing.material_override = frame_material
	backing.position = Vector3(side_sign * (side_edge - radius * 0.35), position_y, 0.0)
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(backing)

	var key := MeshInstance3D.new()
	key.name = node_name
	var key_mesh := BoxMesh.new()
	key_mesh.size = Vector3(button_depth, maxf(length, radius * 2.0), button_width)
	key.mesh = key_mesh
	key.material_override = key_material
	# Center the thin key just beyond the side plane, leaving only a shallow
	# tactile surface exposed rather than a raised block.
	key.position = Vector3(side_sign * (side_edge + button_depth * 0.45), position_y, 0.0)
	key.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(key)

func _show_speaker_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "SpeakerControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 14)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("PHONE SPEAKERS", 19, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var description := _make_label("Choose how many speaker openings appear along the bottom edge", 12, Color("#c7eaff"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	var meter_row := HBoxContainer.new()
	meter_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_row.add_theme_constant_override("separation", 12)
	active_feature_panel.add_child(meter_row)

	var level_labels := VBoxContainer.new()
	level_labels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_labels.alignment = BoxContainer.ALIGNMENT_CENTER
	level_labels.add_theme_constant_override("separation", 0)
	meter_row.add_child(level_labels)

	for level in range(12, -1, -1):
		var level_label := _make_label(str(level), 14, Color("#d8f1ff"))
		level_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_labels.add_child(level_label)

	var meter := VSlider.new()
	meter.name = "SpeakerCountLevelMeter"
	meter.min_value = 0
	meter.max_value = 12
	meter.step = 1
	meter.value = speaker_count
	meter.tick_count = 13
	meter.custom_minimum_size = Vector2(76, 290)
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.value_changed.connect(_on_speaker_count_changed)
	_style_feature_slider(meter)
	meter_row.add_child(meter)

	speaker_count_value_label = _make_label("SPEAKERS %d / 12" % speaker_count, 16, Color("#a9e3ff"))
	speaker_count_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(speaker_count_value_label)


func _on_speaker_count_changed(value: float) -> void:
	speaker_count = clampi(roundi(value), 0, 12)
	if is_instance_valid(speaker_count_value_label):
		speaker_count_value_label.text = "SPEAKERS %d / 12" % speaker_count
	_refresh_phone_speakers()


func _refresh_phone_speakers() -> void:
	if not is_instance_valid(phone_body):
		return

	var previous_set := phone_body.get_node_or_null("PhoneSpeakerOpenings")
	if is_instance_valid(previous_set):
		previous_set.free()
	if speaker_count <= 0:
		return

	var speaker_set := Node3D.new()
	speaker_set.name = "PhoneSpeakerOpenings"
	phone_body.add_child(speaker_set)

	# Fixed center clearance for every supported connector. Speaker placement
	# never reads charge_port_type or port dimensions, so port edits cannot
	# move, resize, or reshape these circles.
	var bottom_y := -PHONE_SIZE.y * 0.5
	var reserved_port_half_width := 0.115
	var edge_margin := 0.035
	var hole_spacing := 0.045
	var hole_radius := 0.012
	var left_count := int(ceil(float(speaker_count) * 0.5))
	var right_count := speaker_count - left_count
	var positions: Array[float] = []

	for index in range(left_count):
		positions.append(-(reserved_port_half_width + edge_margin + float(left_count - 1 - index) * hole_spacing))
	for index in range(right_count):
		positions.append(reserved_port_half_width + edge_margin + float(index) * hole_spacing)

	var hole_material := StandardMaterial3D.new()
	# Unshaded + pure black albedo keeps the speaker faces black under every
	# scene light. No metallic/specular response or received shadows are used.
	hole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole_material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	hole_material.metallic = 0.0
	hole_material.roughness = 1.0
	hole_material.disable_receive_shadows = true
	hole_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for index in range(positions.size()):
		var opening := MeshInstance3D.new()
		opening.name = "Opening_%02d" % (index + 1)
		var disc := CylinderMesh.new()
		disc.top_radius = hole_radius
		disc.bottom_radius = hole_radius
		disc.height = 0.012
		disc.radial_segments = 32
		opening.mesh = disc
		opening.material_override = hole_material
		# Only 1.5 mm projects beyond the bottom plane; 10.5 mm is embedded
		# inside the frame so the black circular face stays attached.
		opening.position = Vector3(positions[index], bottom_y + 0.0045, 0.0)
		opening.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		speaker_set.add_child(opening)


func _show_charge_port_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()

	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ChargePortControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("CHARGING PORT", 19, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var description := _make_label("Five established phone connector types", 12, Color("#c7eaff"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	var selected_label := _make_label("SELECTED: " + charge_port_type.to_upper(), 13, Color("#a9e3ff"))
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(selected_label)
	charge_port_value_label = selected_label

	var port_scroll := ScrollContainer.new()
	port_scroll.name = "ChargePortOptionsScroll"
	port_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	port_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	port_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	active_feature_panel.add_child(port_scroll)

	var options := GridContainer.new()
	options.name = "ChargePortOptionsGrid"
	options.columns = 1
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("v_separation", 7)
	port_scroll.add_child(options)

	var port_types := [
		"None",
		"USB Type-C",
		"Apple Lightning",
		"Micro-USB (Micro-B)",
		"Mini-USB (Mini-B)",
		"DC Barrel Jack"
	]
	for port_type in port_types:
		var option_button := Button.new()
		option_button.name = "ChargePort_" + port_type.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
		option_button.text = port_type
		option_button.tooltip_text = port_type
		option_button.custom_minimum_size = Vector2(0, 44)
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_research_typography(option_button, 13)
		_style_staff_button(option_button, port_type == charge_port_type)
		option_button.pressed.connect(_on_charge_port_selected.bind(port_type))
		options.add_child(option_button)


func _on_charge_port_selected(port_type: String) -> void:
	charge_port_type = port_type
	if is_instance_valid(charge_port_value_label):
		charge_port_value_label.text = "SELECTED: " + charge_port_type.to_upper()
	# Rebuild the receptacle first so its exact aperture is used when the
	# phone's bottom frame mesh is regenerated.
	_refresh_phone_charge_port()
	var radius := 0.32 * float(border_radius_level) / 6.0
	phone_body.mesh = _create_rounded_phone_mesh(radius, charge_port_opening_points)



func _make_port_outline(width: float, height: float, corner_radius: float, segments: int = 5) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := minf(corner_radius, minf(width, height) * 0.5)
	var centers := [
		Vector2(width * 0.5 - radius, height * 0.5 - radius),
		Vector2(-width * 0.5 + radius, height * 0.5 - radius),
		Vector2(-width * 0.5 + radius, -height * 0.5 + radius),
		Vector2(width * 0.5 - radius, -height * 0.5 + radius)
	]
	for corner in range(4):
		var start_angle := float(corner) * PI * 0.5
		for step in range(segments + 1):
			var angle := start_angle + float(step) / float(segments) * PI * 0.5
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _port_polygon_ray_intersection(points: PackedVector2Array, direction: Vector2) -> Vector2:
	var nearest_distance := 1.0e20
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		var edge_start := points[index]
		var edge := points[next_index] - edge_start
		var denominator := direction.cross(edge)
		if absf(denominator) < 0.000001:
			continue
		var distance := edge_start.cross(edge) / denominator
		var edge_weight := edge_start.cross(direction) / denominator
		if distance > 0.0 and edge_weight >= -0.0001 and edge_weight <= 1.0001:
			nearest_distance = minf(nearest_distance, distance)
	if nearest_distance >= 1.0e19:
		return Vector2.ZERO
	return direction * nearest_distance


func _resample_port_outline_by_angle(points: PackedVector2Array, side_half_width: float, side_half_height: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var angles: Array[float] = []
	var sample_count := 64
	for index in range(sample_count):
		angles.append(PI * 2.0 * float(index) / float(sample_count))
	# Include the four exact handset-frame corner directions so the mapped
	# outer contour reaches every corner without leaving tiny uncovered wedges.
	var corner_angle := atan2(side_half_height, side_half_width)
	angles.append(corner_angle)
	angles.append(PI - corner_angle)
	angles.append(PI + corner_angle)
	angles.append(PI * 2.0 - corner_angle)
	angles.sort()

	var result := PackedVector2Array()
	var previous_angle := -1.0
	for angle in angles:
		if absf(angle - previous_angle) < 0.00001:
			continue
		previous_angle = angle
		var direction := Vector2(cos(angle), sin(angle))
		var boundary_point := _port_polygon_ray_intersection(points, direction)
		if boundary_point != Vector2.ZERO:
			result.append(boundary_point)
	return result if result.size() >= 3 else points


func _make_port_face(points: PackedVector2Array, face_y: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		return mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[index]]
		var b: Vector2 = points[indices[index + 1]]
		var c: Vector2 = points[indices[index + 2]]
		surface.set_normal(Vector3(0.0, -1.0, 0.0))
		surface.add_vertex(Vector3(a.x, face_y, a.y))
		surface.set_normal(Vector3(0.0, -1.0, 0.0))
		surface.add_vertex(Vector3(b.x, face_y, b.y))
		surface.set_normal(Vector3(0.0, -1.0, 0.0))
		surface.add_vertex(Vector3(c.x, face_y, c.y))
	surface.commit(mesh)
	return mesh


func _add_port_detail(parent: Node3D, node_name: String, points: PackedVector2Array, face_y: float, material: Material) -> void:
	var detail := MeshInstance3D.new()
	detail.name = node_name
	detail.mesh = _make_port_face(points, face_y)
	detail.material_override = material
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(detail)


func _make_port_ring_mesh(opening_points: PackedVector2Array, scale_factor: float, face_y: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if opening_points.size() < 3:
		return mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, -1.0, 0.0)
	for index in range(opening_points.size()):
		var next_index := (index + 1) % opening_points.size()
		var inner_a := opening_points[index]
		var inner_b := opening_points[next_index]
		var outer_a := inner_a * scale_factor
		var outer_b := inner_b * scale_factor
		_add_phone_mesh_triangle(surface, Vector3(outer_a.x, face_y, outer_a.y), Vector3(outer_b.x, face_y, outer_b.y), Vector3(inner_b.x, face_y, inner_b.y), normal)
		_add_phone_mesh_triangle(surface, Vector3(outer_a.x, face_y, outer_a.y), Vector3(inner_b.x, face_y, inner_b.y), Vector3(inner_a.x, face_y, inner_a.y), normal)
	return surface.commit()


func _add_port_ring(parent: Node3D, node_name: String, opening_points: PackedVector2Array, scale_factor: float, face_y: float, material: Material) -> void:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	ring.mesh = _make_port_ring_mesh(opening_points, scale_factor, face_y)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)


func _make_port_cavity_walls(points: PackedVector2Array, mouth_y: float, back_y: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if points.size() < 3:
		return mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		var a := points[index]
		var b := points[next_index]
		var inward := -((a + b) * 0.5).normalized()
		var wall_normal := Vector3(inward.x, 0.0, inward.y).normalized()
		var mouth_a := Vector3(a.x, mouth_y, a.y)
		var mouth_b := Vector3(b.x, mouth_y, b.y)
		var back_a := Vector3(a.x, back_y, a.y)
		var back_b := Vector3(b.x, back_y, b.y)
		_add_phone_mesh_triangle(surface, mouth_a, mouth_b, back_b, wall_normal)
		_add_phone_mesh_triangle(surface, mouth_a, back_b, back_a, wall_normal)
	return surface.commit()


func _add_port_cavity_walls(parent: Node3D, node_name: String, points: PackedVector2Array, mouth_y: float, back_y: float, material: Material) -> void:
	var walls := MeshInstance3D.new()
	walls.name = node_name
	walls.mesh = _make_port_cavity_walls(points, mouth_y, back_y)
	walls.material_override = material
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(walls)

func _refresh_phone_charge_port() -> void:
	if not is_instance_valid(phone_body):
		return
	var previous_port := phone_body.get_node_or_null("PhoneChargingPort")
	if is_instance_valid(previous_port):
		previous_port.free()
	charge_port_opening_points = PackedVector2Array()
	if charge_port_type == "None":
		return

	# Connector openings are sized from published receptacle dimensions and
	# scaled against a 150 mm reference handset height.
	var unit_per_mm := PHONE_SIZE.y / 150.0
	var port_width := 8.34 * unit_per_mm
	var port_height := 2.56 * unit_per_mm
	var shape := "rounded"
	var contact_count := 0
	var circular := false

	match charge_port_type:
		"USB Type-C":
			contact_count = 12
		"Apple Lightning":
			port_width = 6.7 * unit_per_mm
			port_height = 1.5 * unit_per_mm
			contact_count = 8
		"Micro-USB (Micro-B)":
			port_width = 6.85 * unit_per_mm
			port_height = 1.85 * unit_per_mm
			shape = "micro"
			contact_count = 5
		"Mini-USB (Mini-B)":
			port_width = 6.9 * unit_per_mm
			port_height = 3.1 * unit_per_mm
			shape = "mini"
			contact_count = 5
		"DC Barrel Jack":
			port_width = 3.5 * unit_per_mm
			port_height = port_width
			circular = true

	var inner_points := PackedVector2Array()
	if circular:
		# Barrel sockets have a visible insulating bore inside a circular metal sleeve.
		inner_points = _make_port_outline(port_width * 0.62, port_height * 0.62, port_width * 0.31, 12)
	elif shape == "micro":
		# Micro-B has the characteristic shallow trapezoid, wider at its mouth.
		inner_points = PackedVector2Array([
			Vector2(-port_width * 0.46, -port_height * 0.42),
			Vector2(port_width * 0.46, -port_height * 0.42),
			Vector2(port_width * 0.42, port_height * 0.42),
			Vector2(-port_width * 0.42, port_height * 0.42)
		])
	elif shape == "mini":
		# Mini-B is taller and more strongly tapered than Micro-B.
		inner_points = PackedVector2Array([
			Vector2(-port_width * 0.45, -port_height * 0.41),
			Vector2(port_width * 0.45, -port_height * 0.41),
			Vector2(port_width * 0.30, port_height * 0.41),
			Vector2(-port_width * 0.30, port_height * 0.41)
		])
	elif shape == "micro_usb_3":
		# SuperSpeed Micro-B joins a Micro-B section to a wider side extension.
		inner_points = PackedVector2Array([
			Vector2(-port_width * 0.5, -port_height * 0.38),
			Vector2(port_width * 0.16, -port_height * 0.38),
			Vector2(port_width * 0.16, -port_height * 0.5),
			Vector2(port_width * 0.5, -port_height * 0.5),
			Vector2(port_width * 0.5, port_height * 0.5),
			Vector2(port_width * 0.16, port_height * 0.5),
			Vector2(port_width * 0.16, port_height * 0.38),
			Vector2(-port_width * 0.5, port_height * 0.38)
		])
	else:
		var opening_width_ratio := 0.95
		var opening_height_ratio := 0.84
		if charge_port_type == "USB Type-C":
			opening_width_ratio = 1.0
			opening_height_ratio = 1.0
		elif charge_port_type == "Apple Lightning":
			opening_width_ratio = 0.94
			opening_height_ratio = 0.80
		inner_points = _make_port_outline(port_width * opening_width_ratio, port_height * opening_height_ratio, port_height * opening_height_ratio * 0.38, 8)

	# Fit the complete mouth and its metal lip inside the handset's actual
	# bottom rail. If the frame is very thin, the whole aperture scales evenly.
	var current_phone_depth := lerpf(PHONE_SIZE.z, 0.08, float(phone_thickness_level) / 10.0)
	var half_phone_depth := current_phone_depth * 0.5
	var current_corner_radius := 0.32 * float(border_radius_level) / 6.0
	var flat_bottom_half_width := PHONE_SIZE.x * 0.5 - current_corner_radius
	var profile_fit := 1.0
	for point in inner_points:
		if absf(point.x) > 0.00001:
			profile_fit = minf(profile_fit, (flat_bottom_half_width - 0.025) / (absf(point.x) * 1.12))
		if absf(point.y) > 0.00001:
			profile_fit = minf(profile_fit, (half_phone_depth - 0.004) / (absf(point.y) * 1.12))
	profile_fit = clampf(profile_fit, 0.01, 1.0)
	var fitted_opening := PackedVector2Array()
	for point in inner_points:
		fitted_opening.append(point * profile_fit)
	inner_points = fitted_opening
	port_width *= profile_fit
	port_height *= profile_fit
	# Add points along the connector profile so the full bottom-edge surface
	# can wrap cleanly around small trapezoidal and stepped receptacle shapes.
	inner_points = _resample_port_outline_by_angle(inner_points, flat_bottom_half_width, half_phone_depth)
	charge_port_opening_points = inner_points.duplicate()

	var port_root := Node3D.new()
	port_root.name = "PhoneChargingPort"
	phone_body.add_child(port_root)
	var bottom_y := -PHONE_SIZE.y * 0.5
	var mouth_y := bottom_y + 0.0001
	var recess_depth := minf(6.2 * unit_per_mm, PHONE_SIZE.y * 0.08)
	var back_y := bottom_y + recess_depth
	var contact_face_y := bottom_y + recess_depth * 0.54

	var bezel_material := StandardMaterial3D.new()
	bezel_material.albedo_color = Color("#8a929a")
	bezel_material.metallic = 0.86
	bezel_material.roughness = 0.27
	bezel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gasket_material := StandardMaterial3D.new()
	gasket_material.albedo_color = Color("#20262c")
	gasket_material.metallic = 0.22
	gasket_material.roughness = 0.74
	gasket_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cavity_material := StandardMaterial3D.new()
	cavity_material.albedo_color = Color("#030507")
	cavity_material.roughness = 0.96
	cavity_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cavity_wall_material := StandardMaterial3D.new()
	cavity_wall_material.albedo_color = Color("#343b43")
	cavity_wall_material.metallic = 0.76
	cavity_wall_material.roughness = 0.42
	cavity_wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if circular:
		cavity_wall_material.albedo_color = Color("#818990")
		cavity_wall_material.metallic = 0.88
		cavity_wall_material.roughness = 0.34
	var tongue_material := StandardMaterial3D.new()
	# Connector tongues and contact beds are insulating polymer, not bare metal.
	tongue_material.albedo_color = Color("#414951")
	tongue_material.metallic = 0.08
	tongue_material.roughness = 0.68
	tongue_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var contact_material := StandardMaterial3D.new()
	contact_material.albedo_color = Color("#d5a64f")
	contact_material.metallic = 0.78
	contact_material.roughness = 0.29
	contact_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Actual aperture: the phone frame mesh is cut around this profile. These
	# details now sit down inside the recess rather than on the exterior face.
	var bezel_scale := 1.12 if not circular else 1.22
	_add_port_ring(port_root, "MachinedMetalPortLip", inner_points, bezel_scale, bottom_y - 0.00035, bezel_material)
	_add_port_ring(port_root, "DarkInnerGasket", inner_points, 1.045, bottom_y - 0.00055, gasket_material)
	_add_port_cavity_walls(port_root, "RecessedMetalSideWalls", inner_points, mouth_y, back_y, cavity_wall_material)
	_add_port_detail(port_root, "DeepDarkPortInterior", inner_points, back_y + 0.00015, cavity_material)

	if charge_port_type == "USB Type-C":
		var tongue_points := _make_port_outline(port_width * 0.72, port_height * 0.20, port_height * 0.10, 6)
		_add_port_detail(port_root, "USBCTongue", tongue_points, contact_face_y, tongue_material)
		for row in range(2):
			for contact_index in range(contact_count):
				var x := (float(contact_index) - float(contact_count - 1) * 0.5) * (port_width * 0.66 / float(contact_count))
				var z := (1.0 if row == 0 else -1.0) * port_height * 0.105
				var pad := _make_port_outline(port_width * 0.035, port_height * 0.055, port_height * 0.02, 3)
				var shifted := PackedVector2Array()
				for point in pad:
					shifted.append(point + Vector2(x, z))
				_add_port_detail(port_root, "USBCContact_%d_%d" % [row, contact_index], shifted, contact_face_y - 0.0002, contact_material)
	elif charge_port_type == "Apple Lightning":
		for row in range(2):
			for contact_index in range(contact_count):
				var x := (float(contact_index) - float(contact_count - 1) * 0.5) * port_width * 0.075
				var z := (1.0 if row == 0 else -1.0) * port_height * 0.25
				var pad := _make_port_outline(port_width * 0.035, port_height * 0.12, port_width * 0.01, 3)
				var shifted := PackedVector2Array()
				for point in pad:
					shifted.append(point + Vector2(x, z))
				_add_port_detail(port_root, "LightningContact_%d_%d" % [row, contact_index], shifted, contact_face_y - 0.0002, contact_material)
	elif charge_port_type in ["Micro-USB (Micro-B)", "Mini-USB (Mini-B)"]:
		var pitch_mm := 0.65 if charge_port_type == "Micro-USB (Micro-B)" else 0.80
		var micro_contact_pitch := pitch_mm * unit_per_mm * profile_fit
		var micro_contact_span := micro_contact_pitch * 4.0
		var bed_width := minf(port_width * 0.62, micro_contact_span * 1.40)
		var bed_height := port_height * (0.48 if charge_port_type == "Micro-USB (Micro-B)" else 0.42)
		var insert_bed := _make_port_outline(bed_width, bed_height, bed_height * 0.20, 5)
		_add_port_detail(port_root, "InsulatingContactBed", insert_bed, contact_face_y, tongue_material)
		var micro_pad_width := micro_contact_pitch * 0.66
		var pad_height := maxf(port_height * 0.13, 0.002)
		for contact_index in range(5):
			var x := (float(contact_index) - 2.0) * micro_contact_pitch
			var pad := _make_port_outline(micro_pad_width, pad_height, pad_height * 0.18, 3)
			var shifted := PackedVector2Array()
			for point in pad:
				shifted.append(point + Vector2(x, 0.0))
			_add_port_detail(port_root, "Contact_%02d" % contact_index, shifted, contact_face_y - 0.0002, contact_material)
	elif contact_count > 0:
		var generic_contact_span := port_width * 0.68
		var generic_contact_pitch := generic_contact_span / float(contact_count)
		var generic_contact_width := generic_contact_pitch * 0.66
		var contact_height := maxf(port_height * 0.11, 0.002)
		for contact_index in range(contact_count):
			var x := (float(contact_index) - float(contact_count - 1) * 0.5) * generic_contact_pitch
			var pad := _make_port_outline(generic_contact_width, contact_height, contact_height * 0.18, 3)
			var shifted := PackedVector2Array()
			for point in pad:
				shifted.append(point + Vector2(x, 0.0))
			_add_port_detail(port_root, "Contact_%02d" % contact_index, shifted, contact_face_y - 0.0002, contact_material)

	if circular:
		var barrel_pin := MeshInstance3D.new()
		barrel_pin.name = "BarrelCenterTerminal"
		var pin_mesh := CylinderMesh.new()
		pin_mesh.top_radius = port_width * 0.075
		pin_mesh.bottom_radius = port_width * 0.075
		pin_mesh.height = minf(0.012, recess_depth * 0.18)
		pin_mesh.radial_segments = 20
		barrel_pin.mesh = pin_mesh
		barrel_pin.material_override = contact_material
		barrel_pin.position = Vector3(0.0, back_y - pin_mesh.height * 0.5 - 0.001, 0.0)
		barrel_pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		port_root.add_child(barrel_pin)


func _on_phone_thickness_level_changed(value: float) -> void:
	phone_thickness_level = clampi(roundi(value), 0, 10)
	if is_instance_valid(phone_thickness_value_label):
		phone_thickness_value_label.text = "LEVEL %d / 10" % phone_thickness_level
	_refresh_phone_mesh()


func _refresh_phone_mesh() -> void:
	if not is_instance_valid(phone_body):
		return
	var radius := 0.32 * float(border_radius_level) / 6.0
	# Refresh the fitted aperture first: thickness upgrades can change how much
	# room a connector has inside the bottom rail.
	_refresh_phone_charge_port()
	phone_body.mesh = _create_rounded_phone_mesh(radius, charge_port_opening_points)
	_refresh_phone_side_buttons()
	_refresh_phone_home_button()
	_refresh_phone_screen()
func _on_border_radius_level_changed(value: float) -> void:
	border_radius_level = clampi(roundi(value), 0, 6)
	if is_instance_valid(border_radius_value_label):
		border_radius_value_label.text = "LEVEL %d / 6" % border_radius_level
	_refresh_phone_mesh()


func _add_phone_bottom_edge_with_port(surface: SurfaceTool, phone_size: Vector3, port_opening: PackedVector2Array, flat_bottom_half_width: float) -> void:
	var half_size := phone_size * 0.5
	var opening := port_opening
	var mouth_y := -half_size.y
	var bottom_normal := Vector3(0.0, -1.0, 0.0)
	# Project each aperture point radially onto the perimeter of the complete
	# bottom rail. The resulting triangle strip leaves a genuine opening in
	# the frame instead of drawing a dark decal over a solid box.
	var outer_points := PackedVector3Array()
	for point in opening:
		var scale_x := flat_bottom_half_width / maxf(absf(point.x), 0.000001)
		var scale_z := half_size.z / maxf(absf(point.y), 0.000001)
		var ray_scale := minf(scale_x, scale_z)
		var outer := point * ray_scale
		outer_points.append(Vector3(outer.x, mouth_y, outer.y))

	for index in range(opening.size()):
		var next_index := (index + 1) % opening.size()
		var outer_a := outer_points[index]
		var outer_b := outer_points[next_index]
		var inner_a := Vector3(opening[index].x, mouth_y, opening[index].y)
		var inner_b := Vector3(opening[next_index].x, mouth_y, opening[next_index].y)
		_add_phone_mesh_triangle(surface, outer_a, outer_b, inner_b, bottom_normal)
		_add_phone_mesh_triangle(surface, outer_a, inner_b, inner_a, bottom_normal)


func _create_rounded_phone_mesh(radius: float, port_opening: PackedVector2Array) -> Mesh:
	var phone_size := PHONE_SIZE
	# Level 10 reaches an ultra-slim 0.08-unit body.
	phone_size.z = lerpf(PHONE_SIZE.z, 0.08, float(phone_thickness_level) / 10.0)
	var half_size := phone_size * 0.5
	var outline := PackedVector2Array()

	if radius <= 0.0001:
		outline = PackedVector2Array([
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y)
		])
	else:
		# Round only the phone's front/back outline. Keep the front and rear
		# faces flat and preserve a straight extrusion through the thickness.
		var corner_radius := clampf(radius, 0.0, minf(half_size.x, half_size.y) - 0.001)
		var corner_centers := [
			Vector2(half_size.x - corner_radius, half_size.y - corner_radius),
			Vector2(-half_size.x + corner_radius, half_size.y - corner_radius),
			Vector2(-half_size.x + corner_radius, -half_size.y + corner_radius),
			Vector2(half_size.x - corner_radius, -half_size.y + corner_radius)
		]
		var corner_segments := 8
		for corner_index in range(4):
			var center: Vector2 = corner_centers[corner_index]
			var start_angle := float(corner_index) * PI * 0.5
			for segment in range(corner_segments):
				var angle := start_angle + float(segment) / float(corner_segments) * PI * 0.5
				outline.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)

	var triangle_indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if triangle_indices.is_empty():
		var fallback_body := BoxMesh.new()
		fallback_body.size = phone_size
		return fallback_body

	var front_z := half_size.z
	var back_z := -half_size.z
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build the two broad glass-facing surfaces with outward normals.
	for index in range(0, triangle_indices.size(), 3):
		var a2: Vector2 = outline[triangle_indices[index]]
		var b2: Vector2 = outline[triangle_indices[index + 1]]
		var c2: Vector2 = outline[triangle_indices[index + 2]]
		var front_a := Vector3(a2.x, a2.y, front_z)
		var front_b := Vector3(b2.x, b2.y, front_z)
		var front_c := Vector3(c2.x, c2.y, front_z)
		var back_a := Vector3(a2.x, a2.y, back_z)
		var back_b := Vector3(b2.x, b2.y, back_z)
		var back_c := Vector3(c2.x, c2.y, back_z)
		_add_phone_mesh_triangle(surface, front_a, front_b, front_c, Vector3(0.0, 0.0, 1.0))
		_add_phone_mesh_triangle(surface, back_a, back_c, back_b, Vector3(0.0, 0.0, -1.0))

	# Build the perimeter. Only the straight bottom rail is interrupted by
	# the connector aperture; all other sides remain continuous.
	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[next_index]
		var is_bottom_edge := absf(a.y + half_size.y) < 0.0001 and absf(b.y + half_size.y) < 0.0001
		if is_bottom_edge and port_opening.size() >= 3:
			var flat_bottom_half_width := maxf(absf(a.x), absf(b.x))
			_add_phone_bottom_edge_with_port(surface, phone_size, port_opening, flat_bottom_half_width)
		else:
			var edge := b - a
			var side_normal := Vector3(edge.y, -edge.x, 0.0).normalized()
			var front_a := Vector3(a.x, a.y, front_z)
			var front_b := Vector3(b.x, b.y, front_z)
			var back_a := Vector3(a.x, a.y, back_z)
			var back_b := Vector3(b.x, b.y, back_z)
			_add_phone_mesh_triangle(surface, front_a, back_a, back_b, side_normal)
			_add_phone_mesh_triangle(surface, front_a, back_b, front_b, side_normal)

	return surface.commit()

func _add_phone_mesh_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward_normal: Vector3) -> void:
	var normal := outward_normal.normalized()
	# Godot expects clockwise triangle winding for front faces. With
	# outward normals, the vertex cross product must therefore point in
	# the opposite direction. The previous comparison reversed every face.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.set_normal(normal)
	surface.add_vertex(b)
	surface.set_normal(normal)
	surface.add_vertex(c)


func _on_left_tools_previous_pressed() -> void:
	_set_left_tools_page(left_tools_page - 1)


func _on_left_tools_next_pressed() -> void:
	_set_left_tools_page(left_tools_page + 1)


func _update_left_tools_navigation_buttons() -> void:
	if is_instance_valid(left_tools_previous_button):
		left_tools_previous_button.disabled = left_tools_page <= 0
	if is_instance_valid(left_tools_next_button):
		left_tools_next_button.disabled = left_tools_page >= 2


func _set_left_tools_page(requested_page: int) -> void:
	left_tools_page = clampi(requested_page, 0, 2)
	_update_left_tools_navigation_buttons()
	var tools_content := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot/PhoneEditorPageMargin/PhoneEditorMainLayout/PhoneEditorLeftToolsCard/PhoneEditorLeftToolsCardScroll/PhoneEditorLeftToolsCardPages")
	if not is_instance_valid(tools_content):
		return
	for page_index in range(3):
		var page_grid := tools_content.get_node_or_null("PhoneEditorLeftToolsCardButtonPage" + str(page_index + 1))
		if is_instance_valid(page_grid):
			page_grid.visible = page_index == left_tools_page

func _make_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	_apply_research_typography(label, font_size + 2)
	label.add_theme_color_override("font_color", color)
	return label


func _input(event: InputEvent) -> void:
	if research_mode or not is_instance_valid(preview_container):
		return

	var preview_rect := preview_container.get_global_rect()
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			preview_mouse_dragging = mouse_button.pressed and preview_rect.has_point(mouse_button.position)
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if preview_mouse_dragging and (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_rotate_phone_from_drag(mouse_motion.relative)
	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		if preview_rect.has_point(screen_drag.position):
			_rotate_phone_from_drag(screen_drag.relative)


func _rotate_phone_from_drag(delta: Vector2) -> void:
	if not is_instance_valid(phone_body):
		return

	# Lock each movement to one of four directions: left/right OR up/down.
	# Horizontal drag turns the front toward the drag; vertical drag tilts
	# the top edge down when dragging down, and up when dragging up.
	if absf(delta.x) >= absf(delta.y):
		phone_body.rotation.y += delta.x * DRAG_SENSITIVITY
	else:
		phone_body.rotation.x += delta.y * DRAG_SENSITIVITY


func _rotate_axis(axis: Vector3, direction: float) -> void:
	if not is_instance_valid(phone_body):
		return
	if axis == Vector3.RIGHT:
		phone_body.rotation.x += ROTATION_STEP * direction
	elif axis == Vector3.UP:
		phone_body.rotation.y += ROTATION_STEP * direction


func _rotate_axis_fine(axis: Vector3, direction: float) -> void:
	if not is_instance_valid(phone_body):
		return
	var fine_step := deg_to_rad(5.0)
	if axis == Vector3.RIGHT:
		phone_body.rotation.x += fine_step * direction
	elif axis == Vector3.UP:
		phone_body.rotation.y += fine_step * direction


func _reset_phone_rotation() -> void:
	if is_instance_valid(phone_body):
		phone_body.rotation = Vector3.ZERO


func _zoom_camera(distance_change: float) -> void:
	if not is_instance_valid(preview_camera):
		return
	preview_camera.position.z = clampf(preview_camera.position.z + distance_change, 3.0, 7.5)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _reset_camera_zoom() -> void:
	if not is_instance_valid(preview_camera):
		return
	preview_camera.position = Vector3(0.0, 0.0, 5.2)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _on_back_pressed() -> void:
	back_requested.emit()
