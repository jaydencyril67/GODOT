extends Node3D

signal back_requested
signal research_upgrade_requested(research_id: String)

const PHONE_SIZE := Vector3(1.45, 2.92, 0.20)
const ROTATION_STEP := deg_to_rad(10.0)
# Deliberately low so a normal finger movement makes a controlled turn.
const DRAG_SENSITIVITY := 0.0024

var phone_body: MeshInstance3D
var preview_camera: Camera3D
var preview_container: SubViewportContainer
var research_mode := false
var research_content_panel: Control
var research_balance_label: Label
var research_levels: Dictionary = {}
var research_balance := 0.0
var research_item_cards: Dictionary = {}
var research_view := "HARDWARE"


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

	# Matching tool cards flank the centered 3D preview.
	layout.add_child(_make_tools_card("PhoneEditorLeftToolsCard", true))

	var preview_panel := _make_glass_panel(Color(0.22, 0.53, 0.72, 0.24))
	preview_panel.name = "PhonePreviewCard"
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size.x = 220
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
	preview_container.gui_input.connect(_on_preview_gui_input)
	preview_container.add_child(_get_preview_viewport())
	preview_stack.add_child(preview_container)

	layout.add_child(_make_tools_card("PhoneEditorRightToolsCard", false))


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
	back_button.add_theme_font_size_override("font_size", 13 if compact else 14)
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
		var empty_state := CenterContainer.new()
		empty_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
		parent.add_child(empty_state)
		empty_state.add_child(_make_label("SOFTWARE RESEARCH  •  COMING SOON", 15 if compact else 18, Color("#c7eaff")))
	else:
		_build_extras_research_content(parent, compact)


func _build_hardware_research_grid(parent: Control, compact: bool) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / maxf(viewport_size.y, 1.0)
	var columns := 6 if aspect_ratio >= 1.55 else (5 if aspect_ratio >= 1.2 else 3)
	var short_screen := viewport_size.y < 430.0
	var card_height := 58.0 if short_screen else (82.0 if compact else 104.0)

	var section := VBoxContainer.new()
	section.name = "HardwareResearchSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	parent.add_child(section)

	var section_title := _make_label("HARDWARE FEATURES", 13 if compact else 16, Color("#b9eaff"))
	section.add_child(section_title)

	var grid := GridContainer.new()
	grid.name = "HardwareResearchFeatureGrid"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8 if compact else 12)
	grid.add_theme_constant_override("v_separation", 7 if compact else 10)
	section.add_child(grid)

	var features := [
		"Screen Tech",
		"Power/Volume Buttons",
		"Thickness",
		"Screen Width",
		"Screen Height",
		"Screen Type",
		"Border Radius",
		"Speakers",
		"Charge Port",
		"Front Camera",
		"Rare Camera",
		"Style Pen",
		"Side Button",
		"Audio Output",
		"Body Frame",
		"Phone Width",
		"Phone Height",
		"Sim/Memory Slot"
	]

	for feature_name in features:
		var card := _make_staff_style_card()
		card.name = feature_name.replace("/", "_").replace(" ", "") + "_HardwareCard"
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
		dummy_button.add_theme_font_size_override("font_size", 9 if short_screen else 10)
		_style_staff_button(dummy_button, false)
		# Intentionally no pressed signal: these are placeholder buttons for now.
		content.add_child(dummy_button)


func _build_extras_research_content(parent: Control, compact: bool) -> void:
	var section := VBoxContainer.new()
	section.name = "ExtrasResearchSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	section.add_child(_make_label("EXTRAS", 14 if compact else 17, Color("#b9eaff")))

	var card := _make_staff_style_card()
	card.name = "camera_module_ResearchCard"
	card.custom_minimum_size = Vector2(250 if compact else 320, 220)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	section.add_child(card)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	stack.add_child(_make_label("EXTRAS", 9, Color("#a9e3ff")))
	stack.add_child(_make_label("CAMERA-MODULE DESIGN", 16 if compact else 18, Color.WHITE))
	var detail := _make_label("Research the shape and arrangement of the visible camera housing.", 11, Color("#c7e2f3"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(detail)

	var level_label := _make_label("CURRENT LEVEL: 1 / 20", 12, Color("#d8efff"))
	level_label.name = "ResearchLevel"
	stack.add_child(level_label)

	var upgrade_button := Button.new()
	upgrade_button.name = "UpgradeResearch"
	upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_button.custom_minimum_size.y = 42
	upgrade_button.add_theme_font_size_override("font_size", 12)
	_style_staff_button(upgrade_button, true)
	upgrade_button.pressed.connect(_on_design_research_upgrade_pressed.bind("camera_module"))
	stack.add_child(upgrade_button)
	research_item_cards["camera_module"] = {"level": level_label, "button": upgrade_button}
	_refresh_design_research_cards()

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
		button.add_theme_font_size_override("font_size", 10 if compact else 12)
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
	tools_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_panel.add_child(tools_scroll)

	var tools_content := VBoxContainer.new()
	tools_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_content.add_theme_constant_override("separation", 12)
	tools_scroll.add_child(tools_content)


	var rotation_grid := GridContainer.new()
	rotation_grid.name = card_name + "RotationControls"
	rotation_grid.columns = 2
	rotation_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotation_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rotation_grid.add_theme_constant_override("h_separation", 8)
	rotation_grid.add_theme_constant_override("v_separation", 8)
	tools_content.add_child(rotation_grid)

	# Standard rotation and zoom controls (10-degree rotation steps).
	_add_tool_button(rotation_grid, "X −", _rotate_axis.bind(Vector3.RIGHT, -1.0))
	_add_tool_button(rotation_grid, "X +", _rotate_axis.bind(Vector3.RIGHT, 1.0))
	_add_tool_button(rotation_grid, "Y −", _rotate_axis.bind(Vector3.UP, -1.0))
	_add_tool_button(rotation_grid, "Y +", _rotate_axis.bind(Vector3.UP, 1.0))
	_add_tool_button(rotation_grid, "RESET ROTATION", _reset_phone_rotation)
	_add_tool_button(rotation_grid, "ZOOM IN", _zoom_camera.bind(-0.35))
	_add_tool_button(rotation_grid, "ZOOM OUT", _zoom_camera.bind(0.35))

	# Additional precision controls: 5-degree rotation and finer zoom steps.
	_add_tool_button(rotation_grid, "X − 5°", _rotate_axis_fine.bind(Vector3.RIGHT, -1.0))
	_add_tool_button(rotation_grid, "X + 5°", _rotate_axis_fine.bind(Vector3.RIGHT, 1.0))
	_add_tool_button(rotation_grid, "Y − 5°", _rotate_axis_fine.bind(Vector3.UP, -1.0))
	_add_tool_button(rotation_grid, "Y + 5°", _rotate_axis_fine.bind(Vector3.UP, 1.0))
	_add_tool_button(rotation_grid, "FINE ZOOM IN", _zoom_camera.bind(-0.15))
	_add_tool_button(rotation_grid, "FINE ZOOM OUT", _zoom_camera.bind(0.15))
	_add_tool_button(rotation_grid, "RESET ZOOM", _reset_camera_zoom)

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
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var preview_world := Node3D.new()
	preview_world.name = "PhonePreviewWorld"
	viewport.add_child(preview_world)

	phone_body = MeshInstance3D.new()
	phone_body.name = "Plain_Phone_Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = PHONE_SIZE
	phone_body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#62686e")
	body_material.metallic = 0.18
	body_material.roughness = 0.42
	phone_body.material_override = body_material
	preview_world.add_child(phone_body)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	preview_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#83cfff")
	fill_light.light_energy = 0.7
	fill_light.omni_range = 8.0
	preview_world.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0.0, 0.0, 5.2)
	preview_camera.current = true
	preview_camera.fov = 38.0
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	preview_world.add_child(preview_camera)
	return viewport


func _add_tool_button(parent: GridContainer, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.60, 0.84, 0.96, 0.25)
		if state == "hover":
			style.bg_color = Color(0.76, 0.92, 1.0, 0.38)
		elif state == "pressed":
			style.bg_color = Color(0.35, 0.68, 0.88, 0.48)
		style.border_color = Color(0.91, 0.98, 1.0, 0.92)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)


func _make_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_rotate_phone_from_drag(motion.relative)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_rotate_phone_from_drag(drag.relative)


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
