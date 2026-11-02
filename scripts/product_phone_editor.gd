extends Node3D

signal back_requested
signal research_upgrade_requested(research_id: String)

const PHONE_SIZE := Vector3(1.45, 2.92, 0.22)
const ROTATION_STEP := deg_to_rad(10.0)
# Deliberately low so a normal finger movement makes a controlled turn.
const DRAG_SENSITIVITY := 0.0024

class DeviceColorSpectrum extends Control:
	signal color_changed(color: Color)
	var hue := 0.0
	var saturation := 1.0
	var brightness := 1.0
	var spectrum_texture: ImageTexture
	var dragging := false

	func _ready() -> void:
		# Keep the minimum height configured by the color panel; do not overwrite it here.
		mouse_filter = Control.MOUSE_FILTER_STOP
		_rebuild_spectrum()
		queue_redraw()

	func set_hue(value: float) -> void:
		hue = fposmod(value, 1.0)
		_rebuild_spectrum()
		queue_redraw()

	func set_color_value(color: Color) -> void:
		var next_hue := color.h
		if not is_equal_approx(hue, next_hue):
			hue = next_hue
			_rebuild_spectrum()
		saturation = color.s
		brightness = color.v
		queue_redraw()

	func _rebuild_spectrum() -> void:
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in range(128):
			for x in range(128):
				image.set_pixel(x, y, Color.from_hsv(hue, float(x) / 127.0, 1.0 - float(y) / 127.0))
		spectrum_texture = ImageTexture.create_from_image(image)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if spectrum_texture:
			draw_texture_rect(spectrum_texture, rect, false)
		draw_rect(rect, Color("#7fa9c4"), false, 1.0)
		var cursor := Vector2(saturation * size.x, (1.0 - brightness) * size.y)
		draw_circle(cursor, 7.0, Color("#071522"))
		draw_arc(cursor, 7.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
		draw_circle(cursor, 2.0, Color.WHITE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				_update_from_position(event.position)
				accept_event()
		elif event is InputEventMouseMotion and dragging:
			_update_from_position(event.position)
			accept_event()
		elif event is InputEventScreenTouch:
			dragging = event.pressed
			if dragging:
				_update_from_position(event.position)
				accept_event()
		elif event is InputEventScreenDrag and dragging:
			_update_from_position(event.position)
			accept_event()

	func _update_from_position(point: Vector2) -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		saturation = clampf(point.x / size.x, 0.0, 1.0)
		brightness = 1.0 - clampf(point.y / size.y, 0.0, 1.0)
		queue_redraw()
		color_changed.emit(Color.from_hsv(hue, saturation, brightness))


class DeviceHueBar extends Control:
	signal hue_changed(hue: float)
	var hue := 0.0
	var dragging := false

	func _ready() -> void:
		# 1.5x the original 22 px hue strip height for a taller, easier target.
		custom_minimum_size = Vector2(0, 33)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()

	func set_hue(value: float) -> void:
		hue = fposmod(value, 1.0)
		queue_redraw()

	func _draw() -> void:
		var segments := 72
		var segment_width := size.x / float(segments)
		for i in range(segments):
			var x := float(i) * segment_width
			draw_rect(Rect2(x, 2.0, segment_width + 1.0, maxf(1.0, size.y - 4.0)), Color.from_hsv(float(i) / float(segments - 1), 1.0, 1.0))
		var marker_x := hue * size.x
		draw_line(Vector2(marker_x, 0.0), Vector2(marker_x, size.y), Color("#071522"), 5.0)
		draw_line(Vector2(marker_x, 0.0), Vector2(marker_x, size.y), Color.WHITE, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				_update_hue(event.position.x)
				accept_event()
		elif event is InputEventMouseMotion and dragging:
			_update_hue(event.position.x)
			accept_event()
		elif event is InputEventScreenTouch:
			dragging = event.pressed
			if dragging:
				_update_hue(event.position.x)
				accept_event()
		elif event is InputEventScreenDrag and dragging:
			_update_hue(event.position.x)
			accept_event()

	func _update_hue(x: float) -> void:
		if size.x <= 0.0:
			return
		hue = clampf(x / size.x, 0.0, 1.0)
		queue_redraw()
		hue_changed.emit(hue)


var phone_body: MeshInstance3D
var phone_screen: MeshInstance3D
var home_button_type := "Circle Home Button"
var home_button_enabled := false
var front_camera_enabled := false
var front_camera_style := "Punch-Hole"
const FRONT_CAMERA_STYLES := ["Bezel Camera", "Waterdrop Notch", "Punch-Hole", "Side Punch-Hole", "Dual Punch-Hole", "Pop-Up Camera", "Dynamic Island", "Under-Display Camera"]
var front_camera_option_buttons: Dictionary = {}
var rear_camera_modules: Array[Dictionary] = []
var rear_flash_modules: Array[Dictionary] = []
var rear_camera_selected_index := -1
var rear_flash_selected_index := -1
var rear_hardware_mode := "CAMERA"
var next_rear_camera_id := 1
var next_rear_flash_id := 1
var rear_hardware_item_label: Label
var rear_hardware_size_label: Label
var rear_hardware_size_slider: HSlider
var rear_hardware_add_button: Button
var rear_hardware_remove_button: Button
var rear_hardware_previous_button: Button
var rear_hardware_next_button: Button
const HOME_BUTTON_TYPES := ["Circle Home Button", "Oval Home Button", "Square Home Button", "Recent · Home · Back (Physical)", "On-screen"]
var home_button_option_buttons: Dictionary = {}
var screen_enabled := false
var bezel_width := 0.10
var bezel_height := 0.20
var bezel_width_value_label: Label
var bezel_height_value_label: Label
var bezel_height_slider: VSlider
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
var preview_stack: VBoxContainer
var software_summary_panel: PanelContainer
var software_value_labels: Dictionary = {}
var selected_ram_capacity := "Not set"
var selected_rom_capacity := "Not set"
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
var phone_thickness_level := 10
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
var camera_side_button_enabled := false
var camera_side_button_y := 0.12
var sound_button_enabled := false
var sim_tray_enabled := false
var sim_tray_y := -0.58
var style_pen_enabled := false
var camera_side_button_position_label: Label
var sim_tray_position_label: Label
var side_button_length_scale := 1.35
var power_button_position_label: Label
var volume_button_position_label: Label
var side_button_length_label: Label
var active_feature_panel: Control
var right_tools_content: VBoxContainer
var device_body_color := Color("#a5adb6")
var device_gradient_enabled := false
var device_gradient_color := Color("#536dfe")
var device_gradient_direction := 0 # 0 vertical, 1 horizontal, 2 diagonal, 3 radial
var gradient_color_edit_mode := false
var back_design_gradient_color_edit_mode := false
var gradient_direction_button: Button
var gradient_direction_popup: PanelContainer
var gradient_direction_items: VBoxContainer
var device_color_hex_label: Label
var back_design_boxes: Array[Dictionary] = []
var selected_back_design_box := -1
var next_back_design_box_id := 1
var back_design_selection_button: Button
var back_design_selection_popup: PanelContainer
var back_design_selection_scroll: ScrollContainer
var back_design_selection_items: VBoxContainer
var back_design_size_label: Label
var back_design_border_label: Label
var back_design_border_slider: HSlider
var back_design_mode := "MOVE"
var back_design_size_action := "EXPAND"
var back_design_color_mode := false


func _ready() -> void:
	if research_mode:
		_build_research_ui()
	else:
		_build_editor_ui()


func _build_editor_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PhoneEditorInterface"
	# Keep this editor above all persistent game CanvasLayers (including the
	# prepared staff interface) while it is the active full-screen tool.
	layer.layer = 80
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

	preview_stack = VBoxContainer.new()
	preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_stack.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_stack)
	_build_software_summary_panel()

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
		"Screen Tech", "Power/Volume Buttons", "Thickness", "Device Color",
		"Screen Size", "Screen Type", "Border Radius", "Speakers",
		"Charge Port", "Front Camera", "Rare Camera",
		"Side Button", "Home Button", "Back Design", "Phone Width",
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
	# SubViewportContainer.stretch sizes this viewport to the actual preview panel.
	# Render the 3D buffer slightly above panel resolution, then downsample for
	# cleaner edges without re-enabling the MSAA mode that caused mobile flicker.
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 1.25
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.own_world_3d = true

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	# Keep the preview background navy, but use a separate studio sky for
	# image-based ambient light and PBR reflections on the frame and glass.
	var studio_sky := Sky.new()
	var studio_sky_material := ProceduralSkyMaterial.new()
	studio_sky_material.sky_top_color = Color("#1b3e5c")
	studio_sky_material.sky_horizon_color = Color("#dceaf5")
	studio_sky_material.ground_horizon_color = Color("#718ba4")
	studio_sky_material.ground_bottom_color = Color("#102236")
	studio_sky_material.sky_energy_multiplier = 0.85
	studio_sky_material.ground_energy_multiplier = 0.65
	studio_sky_material.sun_angle_max = 0.0
	studio_sky_material.sun_curve = 0.08
	studio_sky.sky_material = studio_sky_material
	studio_sky.radiance_size = Sky.RADIANCE_SIZE_128

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.13, 0.22, 0.0)
	environment.sky = studio_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var preview_world := Node3D.new()
	preview_world.name = "PhonePreviewWorld"
	viewport.add_child(preview_world)

	phone_body = MeshInstance3D.new()
	phone_body.name = "Plain_Phone_Body"
	phone_body.mesh = _create_rounded_phone_mesh(0.0, PackedVector2Array())
	var body_material := _create_device_body_material()

	# The phone body is generated dynamically from a triangulated outline.
	# Keep both sides drawable so a winding/triangulation edge case at the
	# unrounded (level 0) rectangle cannot make the chassis vanish while rotating.
	# Depth testing still ensures only the nearest visible surface is shown.
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
	key_light.light_color = Color("#f3f8ff")
	key_light.light_energy = 0.82
	# The preview parts do not cast shadows, so a shadow map adds cost without
	# improving the product silhouette.
	key_light.shadow_enabled = false
	preview_world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(18.0, 142.0, -8.0)
	rim_light.light_color = Color("#80caff")
	rim_light.light_energy = 0.28
	rim_light.shadow_enabled = false
	preview_world.add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#83cfff")
	fill_light.light_energy = 0.16
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
	button.text = feature_name
	button.tooltip_text = feature_name
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
	if feature_name in ["Screen Tech", "Screen Size", "Screen Type", "Border Radius", "Thickness", "Device Color", "Speakers", "Charge Port", "Power/Volume Buttons", "Side Button", "Home Button", "Front Camera", "Rare Camera", "Rear Camera", "Back Design", "RAM"]:
		button.pressed.connect(_on_tool_feature_pressed.bind(feature_name))
	# Other feature buttons remain untouched until their systems are implemented.
	parent.add_child(button)


func _on_tool_feature_pressed(feature_name: String) -> void:
	_close_back_design_selection_popup()
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
	elif feature_name == "Device Color":
		_show_device_color_controls()
	elif feature_name == "Speakers":
		_show_speaker_controls()
	elif feature_name == "Charge Port":
		_show_charge_port_controls()
	elif feature_name == "Power/Volume Buttons":
		_show_power_volume_controls()
	elif feature_name == "Side Button":
		_show_side_button_controls()
	elif feature_name == "Home Button":
		_show_home_button_controls()
	elif feature_name == "Front Camera":
		_show_front_camera_controls()
	elif feature_name in ["Rare Camera", "Rear Camera"]:
		_show_rear_camera_controls()
	elif feature_name == "Back Design":
		_show_back_design_controls()
	elif feature_name == "RAM":
		_show_ram_controls()
	elif feature_name in ["ROM", "Internal Storage", "Storage"]:
		_show_rom_controls()



func _show_device_color_controls(return_to_back_design: bool = false) -> void:
	_close_back_design_selection_popup()
	back_design_color_mode = return_to_back_design
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "DeviceColorControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if return_to_back_design else Control.SIZE_SHRINK_BEGIN
	var color_viewport_size := get_viewport().get_visible_rect().size
	var compact_color_ui := color_viewport_size.y < 760.0 or color_viewport_size.x < 900.0
	active_feature_panel.add_theme_constant_override("separation", 6 if compact_color_ui else 8)
	right_tools_content.add_child(active_feature_panel)

	if return_to_back_design:
		var color_header := HBoxContainer.new()
		color_header.add_theme_constant_override("separation", 6)
		active_feature_panel.add_child(color_header)
		var back_button := Button.new()
		back_button.text = "‹"
		back_button.custom_minimum_size = Vector2(34, 32)
		back_button.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(back_button, 25)
		_style_staff_button(back_button, false)
		back_button.pressed.connect(_show_back_design_controls)
		color_header.add_child(back_button)
		var color_title := _make_label("BACK DESIGN COLOR", 16, Color("#c7eaff"))
		color_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		color_header.add_child(color_title)
	else:
		var title := _make_label("DEVICE COLOR", 18, Color("#c7eaff"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(title)
	if return_to_back_design and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		var use_device_color_row := HBoxContainer.new()
		use_device_color_row.name = "UseDeviceColorRow"
		use_device_color_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use_device_color_row.add_theme_constant_override("separation", 9)
		active_feature_panel.add_child(use_device_color_row)
		var use_device_color_label := _make_label("USE DEVICE COLOR", 13, Color("#d8eaf5"))
		use_device_color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use_device_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		use_device_color_row.add_child(use_device_color_label)
		var use_device_color := TextureButton.new()
		use_device_color.name = "UseDeviceColor"
		use_device_color.custom_minimum_size = Vector2(36, 36)
		use_device_color.size_flags_horizontal = Control.SIZE_SHRINK_END
		use_device_color.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		use_device_color.ignore_texture_size = true
		use_device_color.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		use_device_color.texture_normal = _make_side_button_checkbox_icon(false)
		use_device_color.texture_hover = _make_side_button_checkbox_icon(false)
		use_device_color.texture_pressed = _make_side_button_checkbox_icon(true)
		use_device_color.toggle_mode = true
		use_device_color.button_pressed = bool(back_design_boxes[selected_back_design_box].get("use_device_color", true))
		use_device_color.focus_mode = Control.FOCUS_NONE
		use_device_color.mouse_filter = Control.MOUSE_FILTER_STOP
		use_device_color.toggled.connect(_on_back_design_use_device_color_toggled)
		use_device_color_row.add_child(use_device_color)
		_set_back_design_custom_color_controls_enabled(not use_device_color.button_pressed)
		if not use_device_color.button_pressed:
			var box_gradient_toggle_row := HBoxContainer.new()
			box_gradient_toggle_row.name = "BackBoxGradientToggleRow"
			box_gradient_toggle_row.add_theme_constant_override("separation", 8)
			active_feature_panel.add_child(box_gradient_toggle_row)
			var box_gradient_label := _make_label("ENABLE GRADIENT", 13, Color("#d8eaf5"))
			box_gradient_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box_gradient_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box_gradient_toggle_row.add_child(box_gradient_label)
			var box_gradient_toggle := TextureButton.new()
			box_gradient_toggle.name = "EnableBackBoxGradient"
			box_gradient_toggle.custom_minimum_size = Vector2(36, 36)
			box_gradient_toggle.ignore_texture_size = true
			box_gradient_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			box_gradient_toggle.texture_normal = _make_side_button_checkbox_icon(false)
			box_gradient_toggle.texture_hover = _make_side_button_checkbox_icon(false)
			box_gradient_toggle.texture_pressed = _make_side_button_checkbox_icon(true)
			box_gradient_toggle.toggle_mode = true
			box_gradient_toggle.button_pressed = bool(back_design_boxes[selected_back_design_box].get("gradient_enabled", false))
			box_gradient_toggle.focus_mode = Control.FOCUS_NONE
			box_gradient_toggle.toggled.connect(_on_back_box_gradient_toggled)
			box_gradient_toggle_row.add_child(box_gradient_toggle)
			var box_gradient_options := VBoxContainer.new()
			box_gradient_options.name = "BackBoxGradientOptions"
			box_gradient_options.add_theme_constant_override("separation", 7)
			active_feature_panel.add_child(box_gradient_options)
			var box_target_row := HBoxContainer.new()
			box_target_row.name = "BackBoxGradientColorTargets"
			box_target_row.add_theme_constant_override("separation", 7)
			box_gradient_options.add_child(box_target_row)
			var box_base_target := Button.new()
			box_base_target.name = "EditBackBoxColor"
			box_base_target.text = "BOX COLOR"
			box_base_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box_base_target.custom_minimum_size.y = 38
			_style_staff_button(box_base_target, not back_design_gradient_color_edit_mode)
			box_base_target.pressed.connect(_on_back_box_gradient_color_target_selected.bind(false))
			box_target_row.add_child(box_base_target)
			var box_gradient_target := Button.new()
			box_gradient_target.name = "EditBackBoxGradientColor"
			box_gradient_target.text = "GRADIENT COLOR"
			box_gradient_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box_gradient_target.custom_minimum_size.y = 38
			_style_staff_button(box_gradient_target, back_design_gradient_color_edit_mode)
			box_gradient_target.pressed.connect(_on_back_box_gradient_color_target_selected.bind(true))
			box_target_row.add_child(box_gradient_target)
			gradient_direction_button = Button.new()
			gradient_direction_button.name = "BackBoxGradientDirection"
			gradient_direction_button.text = _gradient_direction_name(int(back_design_boxes[selected_back_design_box].get("gradient_direction", 0))) + "  ▼"
			gradient_direction_button.custom_minimum_size.y = 40
			gradient_direction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gradient_direction_button.focus_mode = Control.FOCUS_NONE
			_apply_research_typography(gradient_direction_button, 13)
			_style_staff_button(gradient_direction_button, false)
			gradient_direction_button.pressed.connect(_toggle_gradient_direction_popup)
			box_gradient_options.add_child(gradient_direction_button)
			gradient_direction_popup = PanelContainer.new()
			gradient_direction_popup.name = "GradientDirectionCustomDropdown"
			gradient_direction_popup.visible = false
			gradient_direction_popup.z_index = 110
			gradient_direction_popup.mouse_filter = Control.MOUSE_FILTER_STOP
			var box_popup_style := StyleBoxFlat.new()
			box_popup_style.bg_color = Color("#071d2d")
			box_popup_style.border_color = Color("#65caff")
			box_popup_style.set_border_width_all(2)
			box_popup_style.set_corner_radius_all(12)
			box_popup_style.content_margin_left = 8
			box_popup_style.content_margin_right = 8
			box_popup_style.content_margin_top = 8
			box_popup_style.content_margin_bottom = 8
			gradient_direction_popup.add_theme_stylebox_override("panel", box_popup_style)
			gradient_direction_items = VBoxContainer.new()
			gradient_direction_items.add_theme_constant_override("separation", 6)
			gradient_direction_popup.add_child(gradient_direction_items)
			var box_editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
			if is_instance_valid(box_editor_root): box_editor_root.add_child(gradient_direction_popup)
			else: active_feature_panel.add_child(gradient_direction_popup)
			_rebuild_gradient_direction_popup()
			box_gradient_options.visible = bool(back_design_boxes[selected_back_design_box].get("gradient_enabled", false))
			if not box_gradient_options.visible:
				back_design_gradient_color_edit_mode = false

	if not return_to_back_design:
		var gradient_toggle_row := HBoxContainer.new()
		gradient_toggle_row.name = "EnableDeviceGradientRow"
		gradient_toggle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gradient_toggle_row.add_theme_constant_override("separation", 8)
		active_feature_panel.add_child(gradient_toggle_row)
		var gradient_toggle_label := _make_label("ENABLE GRADIENT", 13, Color("#d8eaf5"))
		gradient_toggle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gradient_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gradient_toggle_row.add_child(gradient_toggle_label)
		var gradient_toggle := TextureButton.new()
		gradient_toggle.name = "EnableDeviceGradient"
		gradient_toggle.custom_minimum_size = Vector2(36, 36)
		gradient_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
		gradient_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gradient_toggle.ignore_texture_size = true
		gradient_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		gradient_toggle.texture_normal = _make_side_button_checkbox_icon(false)
		gradient_toggle.texture_hover = _make_side_button_checkbox_icon(false)
		gradient_toggle.texture_pressed = _make_side_button_checkbox_icon(true)
		gradient_toggle.toggle_mode = true
		gradient_toggle.button_pressed = device_gradient_enabled
		gradient_toggle.focus_mode = Control.FOCUS_NONE
		gradient_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		gradient_toggle.pressed.connect(_on_device_gradient_toggle_pressed.bind(gradient_toggle))
		gradient_toggle_row.add_child(gradient_toggle)
		var gradient_options := VBoxContainer.new()
		gradient_options.name = "GradientOptions"
		gradient_options.add_theme_constant_override("separation", 7)
		active_feature_panel.add_child(gradient_options)
		var color_target_row := HBoxContainer.new()
		color_target_row.name = "GradientColorTargets"
		color_target_row.add_theme_constant_override("separation", 7)
		gradient_options.add_child(color_target_row)
		var base_color_target := Button.new()
		base_color_target.name = "EditDeviceColor"
		base_color_target.text = "DEVICE COLOR"
		base_color_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		base_color_target.custom_minimum_size.y = 38
		_style_staff_button(base_color_target, not gradient_color_edit_mode)
		base_color_target.pressed.connect(_on_gradient_color_target_selected.bind(false))
		color_target_row.add_child(base_color_target)
		var gradient_color_target := Button.new()
		gradient_color_target.name = "EditGradientColor"
		gradient_color_target.text = "GRADIENT COLOR"
		gradient_color_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gradient_color_target.custom_minimum_size.y = 38
		_style_staff_button(gradient_color_target, gradient_color_edit_mode)
		gradient_color_target.pressed.connect(_on_gradient_color_target_selected.bind(true))
		color_target_row.add_child(gradient_color_target)
		gradient_direction_button = Button.new()
		gradient_direction_button.name = "GradientDirection"
		gradient_direction_button.text = _gradient_direction_name(device_gradient_direction) + "  ▼"
		gradient_direction_button.custom_minimum_size.y = 40
		gradient_direction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gradient_direction_button.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(gradient_direction_button, 13)
		_style_staff_button(gradient_direction_button, false)
		gradient_direction_button.pressed.connect(_toggle_gradient_direction_popup)
		gradient_options.add_child(gradient_direction_button)
		gradient_direction_popup = PanelContainer.new()
		gradient_direction_popup.name = "GradientDirectionCustomDropdown"
		gradient_direction_popup.visible = false
		gradient_direction_popup.z_index = 110
		gradient_direction_popup.mouse_filter = Control.MOUSE_FILTER_STOP
		var direction_popup_style := StyleBoxFlat.new()
		direction_popup_style.bg_color = Color("#071d2d")
		direction_popup_style.border_color = Color("#65caff")
		direction_popup_style.set_border_width_all(2)
		direction_popup_style.set_corner_radius_all(12)
		direction_popup_style.content_margin_left = 8
		direction_popup_style.content_margin_right = 8
		direction_popup_style.content_margin_top = 8
		direction_popup_style.content_margin_bottom = 8
		gradient_direction_popup.add_theme_stylebox_override("panel", direction_popup_style)
		gradient_direction_items = VBoxContainer.new()
		gradient_direction_items.add_theme_constant_override("separation", 6)
		gradient_direction_popup.add_child(gradient_direction_items)
		var editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
		if is_instance_valid(editor_root):
			editor_root.add_child(gradient_direction_popup)
		else:
			active_feature_panel.add_child(gradient_direction_popup)
		_rebuild_gradient_direction_popup()
		gradient_options.visible = device_gradient_enabled

	var spectrum_heading := _make_label("COLOR SPECTRUM", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(spectrum_heading)
	var spectrum := DeviceColorSpectrum.new()
	spectrum.name = "DeviceColorSpectrum"
	spectrum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spectrum_height := clampf(color_viewport_size.y * 0.22, 145.0, 190.0) * 1.5 / 1.3
	spectrum.custom_minimum_size = Vector2(0, spectrum_height)
	spectrum.set_color_value(_get_active_color_picker_color())
	spectrum.color_changed.connect(_on_device_body_color_changed)
	active_feature_panel.add_child(spectrum)

	var hue_heading := _make_label("HUE", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(hue_heading)
	var hue_bar := DeviceHueBar.new()
	hue_bar.name = "DeviceColorHue"
	hue_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hue_bar.set_hue(_get_active_color_picker_color().h)
	hue_bar.hue_changed.connect(_on_device_color_hue_changed)
	active_feature_panel.add_child(hue_bar)

	var selected_row := HBoxContainer.new()
	selected_row.name = "SelectedDeviceColor"
	selected_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_row.add_theme_constant_override("separation", 10)
	active_feature_panel.add_child(selected_row)
	var selected_swatch := ColorRect.new()
	selected_swatch.name = "SelectedColorSwatch"
	selected_swatch.custom_minimum_size = Vector2(42, 34)
	selected_swatch.color = _get_active_color_picker_color()
	selected_row.add_child(selected_swatch)
	device_color_hex_label = _make_label("#" + _get_active_color_picker_color().to_html(false).to_upper(), 14, Color("#e5f6ff"))
	device_color_hex_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	device_color_hex_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selected_row.add_child(device_color_hex_label)

	var hex_heading := _make_label("HEX CODE", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(hex_heading)
	var hex_row := HBoxContainer.new()
	hex_row.name = "CustomHexEntry"
	hex_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_row.add_theme_constant_override("separation", 7)
	active_feature_panel.add_child(hex_row)
	var hex_input := LineEdit.new()
	hex_input.name = "DeviceColorHexInput"
	hex_input.placeholder_text = "#RRGGBB"
	hex_input.text = _get_active_color_picker_color().to_html(false).to_upper()
	hex_input.max_length = 7
	hex_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_input.custom_minimum_size = Vector2(0, 40)
	hex_input.clear_button_enabled = true
	hex_input.add_theme_color_override("font_color", Color("#edf8ff"))
	hex_input.add_theme_color_override("font_placeholder_color", Color("#7893a5"))
	hex_input.add_theme_color_override("caret_color", Color("#75d5ff"))
	var hex_normal := StyleBoxFlat.new()
	hex_normal.bg_color = Color("#101d29")
	hex_normal.set_corner_radius_all(8)
	hex_normal.set_border_width_all(1)
	hex_normal.border_color = Color("#31516a")
	hex_normal.content_margin_left = 10.0
	hex_normal.content_margin_right = 10.0
	var hex_focus := hex_normal.duplicate() as StyleBoxFlat
	hex_focus.border_color = Color("#64caff")
	hex_focus.set_border_width_all(2)
	hex_input.add_theme_stylebox_override("normal", hex_normal)
	hex_input.add_theme_stylebox_override("focus", hex_focus)
	hex_input.add_theme_stylebox_override("read_only", hex_normal)
	hex_row.add_child(hex_input)
	var apply_button := Button.new()
	apply_button.name = "ApplyDeviceHex"
	apply_button.text = "APPLY"
	apply_button.custom_minimum_size = Vector2(68, 40)
	apply_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(apply_button, 12)
	var apply_normal := StyleBoxFlat.new()
	apply_normal.bg_color = Color("#17496a")
	apply_normal.set_corner_radius_all(8)
	apply_normal.set_border_width_all(1)
	apply_normal.border_color = Color("#4da9d8")
	var apply_hover := apply_normal.duplicate() as StyleBoxFlat
	apply_hover.bg_color = Color("#20658e")
	apply_button.add_theme_stylebox_override("normal", apply_normal)
	apply_button.add_theme_stylebox_override("hover", apply_hover)
	apply_button.add_theme_color_override("font_color", Color("#effaff"))
	hex_row.add_child(apply_button)
	apply_button.pressed.connect(_on_device_color_hex_submitted.bind(hex_input))
	hex_input.text_submitted.connect(_on_device_color_hex_text_submitted)
	if return_to_back_design:
		_add_back_design_flexible_space(active_feature_panel)


func _get_active_color_picker_color() -> Color:
	if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		var box: Dictionary = back_design_boxes[selected_back_design_box]
		if bool(box.get("use_device_color", true)):
			return device_body_color
		if back_design_gradient_color_edit_mode:
			return Color(box.get("gradient_color", Color("#536dfe")))
		return Color(box.get("custom_color", device_body_color))
	if gradient_color_edit_mode and not back_design_color_mode:
		return device_gradient_color
	return device_body_color


func _set_back_design_custom_color_controls_enabled(enabled: bool) -> void:
	if not is_instance_valid(active_feature_panel): return
	for node_name in ["DeviceColorSpectrum", "DeviceColorHue", "CustomHexEntry"]:
		var control := active_feature_panel.get_node_or_null(node_name) as Control
		if is_instance_valid(control):
			control.modulate.a = 1.0 if enabled else 0.38
			control.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _on_back_design_use_device_color_toggled(enabled: bool) -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size(): return
	back_design_boxes[selected_back_design_box]["use_device_color"] = enabled
	_set_back_design_custom_color_controls_enabled(not enabled)
	_refresh_back_design_boxes()
	var swatch := active_feature_panel.get_node_or_null("SelectedDeviceColor/SelectedColorSwatch") as ColorRect
	if is_instance_valid(swatch): swatch.color = _get_active_color_picker_color()
	if is_instance_valid(device_color_hex_label): device_color_hex_label.text = "#" + _get_active_color_picker_color().to_html(false).to_upper()


func _on_device_color_hue_changed(hue: float) -> void:
	var spectrum := active_feature_panel.get_node_or_null("DeviceColorSpectrum") as DeviceColorSpectrum if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(spectrum):
		spectrum.set_hue(hue)
		_on_device_body_color_changed(Color.from_hsv(hue, spectrum.saturation, spectrum.brightness))


func _on_device_rgb_channel_changed(value: float, channel: String) -> void:
	var updated := _get_active_color_picker_color()
	if channel == "R":
		updated.r = value / 255.0
	elif channel == "G":
		updated.g = value / 255.0
	else:
		updated.b = value / 255.0
	_on_device_body_color_changed(updated)


func _on_device_color_hex_text_submitted(value: String) -> void:
	_apply_device_color_hex(value)


func _on_device_color_hex_submitted(hex_input: LineEdit) -> void:
	if is_instance_valid(hex_input):
		_apply_device_color_hex(hex_input.text)


func _apply_device_color_hex(value: String) -> void:
	var hex_value := value.strip_edges().trim_prefix("#")
	if not Color.html_is_valid(hex_value):
		if is_instance_valid(device_color_hex_label):
			device_color_hex_label.text = "INVALID HEX CODE"
			device_color_hex_label.add_theme_color_override("font_color", Color("#ff7373"))
		return
	_on_device_body_color_changed(Color.from_string("#" + hex_value, _get_active_color_picker_color()))


func _create_device_body_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 solid_color : source_color = vec4(0.647, 0.678, 0.714, 1.0);
uniform vec4 gradient_color : source_color = vec4(0.325, 0.427, 0.996, 1.0);
uniform bool gradient_enabled = false;
uniform int gradient_direction : hint_range(0, 3) = 0;
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	// The front face is authored with an outward +Z normal and stays solid.
	// The rear (-Z) face and all perimeter faces receive the gradient.
	if (local_normal.z > 0.5 || !gradient_enabled) {
		ALBEDO = solid_color.rgb;
	} else {
		vec2 p = local_position.xy / vec2(0.95, 2.0) + vec2(0.5);
		float t = p.y;
		if (gradient_direction == 1) {
			t = p.x;
		} else if (gradient_direction == 2) {
			t = clamp((p.x + p.y) * 0.5, 0.0, 1.0);
		} else if (gradient_direction == 3) {
			t = clamp(length((p - vec2(0.5)) * vec2(1.0, 1.8)) * 1.4142, 0.0, 1.0);
		}
		vec3 gradient_rgb = mix(solid_color.rgb, gradient_color.rgb, clamp(t, 0.0, 1.0));
		ALBEDO = gradient_rgb;
	}
	// Separate the satin back/front finish from the polished metal rail.
	// The side-wall normals are smoothly interpolated by the phone mesh.
	float edge_factor = 1.0 - smoothstep(0.05, 0.95, abs(local_normal.z));
	METALLIC = mix(0.16, 0.78, edge_factor);
	ROUGHNESS = mix(0.42, 0.25, edge_factor);
	SPECULAR = mix(0.62, 0.90, edge_factor);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("solid_color", device_body_color)
	material.set_shader_parameter("gradient_color", device_gradient_color)
	material.set_shader_parameter("gradient_enabled", device_gradient_enabled)
	material.set_shader_parameter("gradient_direction", device_gradient_direction)
	return material


func _on_back_box_gradient_toggled(enabled: bool) -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size(): return
	back_design_boxes[selected_back_design_box]["gradient_enabled"] = enabled
	if not enabled: back_design_gradient_color_edit_mode = false
	_refresh_back_design_boxes()
	var options := active_feature_panel.get_node_or_null("BackBoxGradientOptions") as Control
	if is_instance_valid(options): options.visible = enabled
	_refresh_device_color_editor_controls()


func _on_back_box_gradient_color_target_selected(use_gradient_color: bool) -> void:
	back_design_gradient_color_edit_mode = use_gradient_color
	_refresh_device_color_editor_controls()


func _on_device_gradient_toggle_pressed(toggle: TextureButton) -> void:
	_on_device_gradient_toggled(toggle.button_pressed)


func _on_gradient_color_target_selected(use_gradient_color: bool) -> void:
	gradient_color_edit_mode = use_gradient_color
	_refresh_device_color_editor_controls()


func _refresh_device_color_editor_controls() -> void:
	if not is_instance_valid(active_feature_panel): return
	var selected_color := _get_active_color_picker_color()
	var spectrum := active_feature_panel.get_node_or_null("DeviceColorSpectrum") as DeviceColorSpectrum
	if is_instance_valid(spectrum): spectrum.set_color_value(selected_color)
	var hue_bar := active_feature_panel.get_node_or_null("DeviceColorHue") as DeviceHueBar
	if is_instance_valid(hue_bar): hue_bar.set_hue(selected_color.h)
	var swatch := active_feature_panel.get_node_or_null("SelectedDeviceColor/SelectedColorSwatch") as ColorRect
	if is_instance_valid(swatch): swatch.color = selected_color
	if is_instance_valid(device_color_hex_label):
		device_color_hex_label.text = "#" + selected_color.to_html(false).to_upper()
		device_color_hex_label.add_theme_color_override("font_color", Color("#e5f6ff"))
	var base_button := active_feature_panel.get_node_or_null("GradientOptions/GradientColorTargets/EditDeviceColor") as Button
	var gradient_button := active_feature_panel.get_node_or_null("GradientOptions/GradientColorTargets/EditGradientColor") as Button
	if is_instance_valid(base_button): _style_staff_button(base_button, not gradient_color_edit_mode)
	if is_instance_valid(gradient_button): _style_staff_button(gradient_button, gradient_color_edit_mode)
	var box_base_button := active_feature_panel.get_node_or_null("BackBoxGradientOptions/BackBoxGradientColorTargets/EditBackBoxColor") as Button
	var box_gradient_button := active_feature_panel.get_node_or_null("BackBoxGradientOptions/BackBoxGradientColorTargets/EditBackBoxGradientColor") as Button
	if is_instance_valid(box_base_button): _style_staff_button(box_base_button, not back_design_gradient_color_edit_mode)
	if is_instance_valid(box_gradient_button): _style_staff_button(box_gradient_button, back_design_gradient_color_edit_mode)


func _gradient_direction_name(index: int) -> String:
	var names := ["VERTICAL", "HORIZONTAL", "DIAGONAL", "RADIAL"]
	return names[clampi(index, 0, names.size() - 1)]


func _get_active_gradient_direction() -> int:
	if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		return int(back_design_boxes[selected_back_design_box].get("gradient_direction", 0))
	return device_gradient_direction


func _toggle_gradient_direction_popup() -> void:
	if not is_instance_valid(gradient_direction_popup): return
	gradient_direction_popup.visible = not gradient_direction_popup.visible
	if gradient_direction_popup.visible:
		call_deferred("_position_gradient_direction_popup")


func _position_gradient_direction_popup() -> void:
	if not is_instance_valid(gradient_direction_popup) or not is_instance_valid(gradient_direction_button):
		return
	if not gradient_direction_popup.visible: return
	var viewport_rect := get_viewport().get_visible_rect()
	var button_rect := gradient_direction_button.get_global_rect()
	var popup_width := minf(button_rect.size.x, viewport_rect.size.x - 12.0)
	var popup_height := minf(gradient_direction_items.get_combined_minimum_size().y + 20.0, viewport_rect.size.y * 0.4)
	var below := viewport_rect.end.y - (button_rect.position.y + button_rect.size.y) - 8.0
	var above := button_rect.position.y - viewport_rect.position.y - 8.0
	var open_below := below >= popup_height or below >= above
	var available := below if open_below else above
	popup_height = minf(popup_height, available)
	if popup_height <= 0.0:
		gradient_direction_popup.visible = false
		return
	gradient_direction_popup.custom_minimum_size = Vector2(popup_width, popup_height)
	gradient_direction_popup.size = Vector2(popup_width, popup_height)
	var popup_y := button_rect.end.y + 6.0 if open_below else button_rect.position.y - popup_height - 6.0
	gradient_direction_popup.global_position = Vector2(clampf(button_rect.position.x, viewport_rect.position.x + 6.0, viewport_rect.end.x - popup_width - 6.0), popup_y)


func _rebuild_gradient_direction_popup() -> void:
	if not is_instance_valid(gradient_direction_items): return
	for child in gradient_direction_items.get_children():
		child.queue_free()
	var names := ["VERTICAL", "HORIZONTAL", "DIAGONAL", "RADIAL"]
	for index in range(names.size()):
		var item := Button.new()
		item.text = names[index] + ("   ✓ SELECTED" if index == _get_active_gradient_direction() else "")
		item.custom_minimum_size = Vector2(0, 46)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#10334a")
		style.border_color = Color("#285b78")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		item.add_theme_stylebox_override("normal", style)
		item.add_theme_stylebox_override("hover", style)
		item.add_theme_stylebox_override("pressed", style)
		item.add_theme_color_override("font_color", Color("#e8f7ff"))
		item.pressed.connect(_select_gradient_direction.bind(index))
		gradient_direction_items.add_child(item)


func _select_gradient_direction(index: int) -> void:
	var selected_direction := clampi(index, 0, 3)
	if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		back_design_boxes[selected_back_design_box]["gradient_direction"] = selected_direction
		_refresh_back_design_boxes()
	else:
		device_gradient_direction = selected_direction
		if is_instance_valid(phone_body):
			phone_body.material_override = _create_device_body_material()
	if is_instance_valid(gradient_direction_button):
		gradient_direction_button.text = _gradient_direction_name(selected_direction) + "  ▼"
	_rebuild_gradient_direction_popup()
	if is_instance_valid(gradient_direction_popup):
		gradient_direction_popup.visible = false


func _on_device_gradient_toggled(enabled: bool) -> void:
	device_gradient_enabled = enabled
	if is_instance_valid(active_feature_panel):
		var options := active_feature_panel.get_node_or_null("GradientOptions") as Control
		if is_instance_valid(options):
			options.visible = enabled
	if is_instance_valid(phone_body):
		phone_body.material_override = _create_device_body_material()


func _on_device_body_color_changed(color: Color) -> void:
	var selected_color := Color(color.r, color.g, color.b, 1.0)
	if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		if bool(back_design_boxes[selected_back_design_box].get("use_device_color", true)): return
		if back_design_gradient_color_edit_mode:
			back_design_boxes[selected_back_design_box]["gradient_color"] = selected_color
		else:
			back_design_boxes[selected_back_design_box]["custom_color"] = selected_color
		_refresh_back_design_boxes()
	elif gradient_color_edit_mode:
		device_gradient_color = selected_color
	else:
		device_body_color = selected_color
	if not back_design_color_mode and is_instance_valid(phone_body):
		phone_body.material_override = _create_device_body_material()
	if is_instance_valid(device_color_hex_label):
		device_color_hex_label.text = "#" + _get_active_color_picker_color().to_html(false).to_upper()
		device_color_hex_label.add_theme_color_override("font_color", Color("#d8f1ff"))
	if is_instance_valid(active_feature_panel):
		var swatch := active_feature_panel.get_node_or_null("SelectedDeviceColor/SelectedColorSwatch") as ColorRect
		if is_instance_valid(swatch):
			swatch.color = _get_active_color_picker_color()
		var spectrum := active_feature_panel.get_node_or_null("DeviceColorSpectrum") as DeviceColorSpectrum
		if is_instance_valid(spectrum):
			spectrum.set_color_value(_get_active_color_picker_color())
		var hue_bar := active_feature_panel.get_node_or_null("DeviceColorHue") as DeviceHueBar
		if is_instance_valid(hue_bar):
			hue_bar.set_hue(_get_active_color_picker_color().h)
		var hex_input := active_feature_panel.get_node_or_null("CustomHexEntry/DeviceColorHexInput") as LineEdit
		if is_instance_valid(hex_input):
			hex_input.text = _get_active_color_picker_color().to_html(false).to_upper()
	_refresh_back_design_boxes()
	_refresh_phone_side_buttons()


func _show_back_design_controls() -> void:
	_close_back_design_selection_popup()
	if is_instance_valid(back_design_selection_popup):
		back_design_selection_popup.queue_free()
		back_design_selection_popup = null
		back_design_selection_scroll = null
		back_design_selection_items = null
	back_design_color_mode = false
	if not is_instance_valid(right_tools_content): return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y < 760.0 or viewport_size.x < 900.0
	var tight := viewport_size.y < 620.0 or viewport_size.x < 600.0
	# Keep the tap targets comfortably sized at every breakpoint. Remaining
	# panel height is distributed between flexible gaps, never into the controls.
	var control_height := 40.0 if tight else (43.0 if compact else 47.0)
	var slider_height := 32.0 if tight else (36.0 if compact else 40.0)
	var section_gap := 3 if tight else (4 if compact else 6)
	var label_size := 11 if tight else 12
	var button_font_size := 12 if tight else (13 if compact else 14)
	for child in right_tools_content.get_children(): child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BackDesignControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", section_gap)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("BACK DESIGN", 17 if compact else 18, Color("#c7eaff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	_add_back_design_flexible_space(active_feature_panel)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(actions)
	var add_button := Button.new()
	add_button.text = "+ ADD BOX"
	add_button.custom_minimum_size.y = control_height
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(add_button, button_font_size)
	_style_staff_button(add_button, true)
	add_button.pressed.connect(_add_back_design_box)
	actions.add_child(add_button)
	var remove_button := Button.new()
	remove_button.text = "− REMOVE"
	remove_button.custom_minimum_size.y = control_height
	remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(remove_button, button_font_size)
	_style_staff_button(remove_button, false)
	remove_button.pressed.connect(_remove_selected_back_design_box)
	actions.add_child(remove_button)
	_add_back_design_flexible_space(active_feature_panel)

	var selector_label := _make_label("SELECT RAISED SECTION", label_size, Color("#a9e3ff"))
	active_feature_panel.add_child(selector_label)
	back_design_selection_button = Button.new()
	back_design_selection_button.name = "BackDesignBoxSelector"
	back_design_selection_button.text = "CHOOSE RAISED BOX  ▼"
	back_design_selection_button.custom_minimum_size.y = control_height
	back_design_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_design_selection_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(back_design_selection_button, button_font_size)
	_style_staff_button(back_design_selection_button, true)
	var selector_idle := StyleBoxFlat.new()
	selector_idle.bg_color = Color("#10334a")
	selector_idle.border_color = Color("#65a9ca")
	selector_idle.set_border_width_all(1)
	selector_idle.set_corner_radius_all(9)
	back_design_selection_button.add_theme_stylebox_override("hover", selector_idle)
	back_design_selection_button.add_theme_stylebox_override("pressed", selector_idle)
	back_design_selection_button.add_theme_stylebox_override("focus", selector_idle)
	back_design_selection_button.pressed.connect(_toggle_back_design_selection_popup)
	active_feature_panel.add_child(back_design_selection_button)
	back_design_selection_popup = PanelContainer.new()
	back_design_selection_popup.name = "BackDesignCustomDropdown"
	back_design_selection_popup.visible = false
	back_design_selection_popup.z_index = 100
	back_design_selection_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var dropdown_panel_style := StyleBoxFlat.new()
	dropdown_panel_style.bg_color = Color("#071d2d")
	dropdown_panel_style.border_color = Color("#65caff")
	dropdown_panel_style.set_border_width_all(2)
	dropdown_panel_style.set_corner_radius_all(12)
	dropdown_panel_style.content_margin_left = 8
	dropdown_panel_style.content_margin_right = 8
	dropdown_panel_style.content_margin_top = 8
	dropdown_panel_style.content_margin_bottom = 8
	back_design_selection_popup.add_theme_stylebox_override("panel", dropdown_panel_style)
	back_design_selection_scroll = ScrollContainer.new()
	back_design_selection_scroll.name = "BackDesignDropdownScroll"
	back_design_selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_design_selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	back_design_selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	back_design_selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	back_design_selection_scroll.follow_focus = false
	back_design_selection_scroll.scroll_deadzone = 2
	back_design_selection_scroll.clip_contents = true
	back_design_selection_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	var dropdown_scroll_bar := back_design_selection_scroll.get_v_scroll_bar()
	dropdown_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	dropdown_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_design_selection_popup.add_child(back_design_selection_scroll)
	back_design_selection_items = VBoxContainer.new()
	back_design_selection_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_design_selection_items.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back_design_selection_items.add_theme_constant_override("separation", 7)
	back_design_selection_scroll.add_child(back_design_selection_items)
	# Keep the dropdown outside the VBox layout so it overlays the panel.
	var editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
	if is_instance_valid(editor_root):
		editor_root.add_child(back_design_selection_popup)
	else:
		active_feature_panel.add_child(back_design_selection_popup)
	_add_back_design_flexible_space(active_feature_panel)

	var modes := HBoxContainer.new()
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(modes)
	for mode in ["SIZE", "MOVE"]:
		var mode_button := Button.new()
		mode_button.text = mode
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.custom_minimum_size.y = control_height
		_apply_research_typography(mode_button, button_font_size)
		_style_staff_button(mode_button, back_design_mode == mode)
		mode_button.pressed.connect(_set_back_design_mode.bind(mode))
		modes.add_child(mode_button)
	_add_back_design_flexible_space(active_feature_panel)

	var pad := GridContainer.new()
	pad.name = "BackDesignDirectionPad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 5 if tight else 7)
	pad.add_theme_constant_override("v_separation", 5 if tight else 7)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(pad)
	_add_back_design_pad_spacer(pad)
	var shrinking := back_design_mode == "SIZE" and back_design_size_action == "SHRINK"
	_add_back_design_pad_button(pad, "↓" if shrinking else "↑", Vector2i(0, 1))
	_add_back_design_pad_spacer(pad)
	_add_back_design_pad_button(pad, "→" if shrinking else "←", Vector2i(-1, 0))
	if back_design_mode == "SIZE":
		var center_button := Button.new()
		center_button.text = back_design_size_action
		center_button.custom_minimum_size = Vector2(44, 38) if tight else (Vector2(48, 42) if compact else Vector2(54, 46))
		center_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_apply_research_typography(center_button, 12 if tight else 13)
		_style_staff_button(center_button, back_design_size_action == "EXPAND")
		center_button.pressed.connect(_toggle_back_design_size_action)
		pad.add_child(center_button)
	else:
		var center := _make_label("MOVE", 13 if tight else 14, Color("#c7eaff"))
		center.custom_minimum_size = Vector2(44, 38) if tight else (Vector2(48, 42) if compact else Vector2(54, 46))
		center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pad.add_child(center)
	_add_back_design_pad_button(pad, "←" if shrinking else "→", Vector2i(1, 0))
	_add_back_design_pad_spacer(pad)
	_add_back_design_pad_button(pad, "↑" if shrinking else "↓", Vector2i(0, -1))
	_add_back_design_pad_spacer(pad)
	_add_back_design_flexible_space(active_feature_panel)

	back_design_size_label = _make_label("", label_size, Color("#d8eaf5"))
	active_feature_panel.add_child(back_design_size_label)
	var border_heading := _make_label("CORNER BORDER", label_size, Color("#a9e3ff"))
	active_feature_panel.add_child(border_heading)
	back_design_border_slider = HSlider.new()
	back_design_border_slider.min_value = 0.0
	back_design_border_slider.max_value = 0.45
	back_design_border_slider.step = 0.01
	back_design_border_slider.custom_minimum_size = Vector2(0, slider_height)
	back_design_border_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_back_design_slider(back_design_border_slider)
	back_design_border_slider.value_changed.connect(_on_back_design_border_changed)
	active_feature_panel.add_child(back_design_border_slider)
	back_design_border_label = _make_label("", label_size, Color("#d8eaf5"))
	active_feature_panel.add_child(back_design_border_label)
	var color_button := Button.new()
	color_button.name = "BackDesignColorButton"
	color_button.text = "●  BODY COLOR"
	color_button.custom_minimum_size.y = control_height
	color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(color_button, button_font_size)
	_style_staff_button(color_button, false)
	color_button.pressed.connect(_show_device_color_controls.bind(true))
	active_feature_panel.add_child(color_button)
	_refresh_back_design_panel()


func _add_back_design_flexible_space(parent: Control) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func _toggle_back_design_selection_popup() -> void:
	if not is_instance_valid(back_design_selection_popup):
		return
	back_design_selection_popup.visible = not back_design_selection_popup.visible
	if back_design_selection_popup.visible:
		call_deferred("_position_back_design_selection_popup")


func _close_back_design_selection_popup() -> void:
	if is_instance_valid(back_design_selection_popup):
		back_design_selection_popup.visible = false


func _position_back_design_selection_popup() -> void:
	if not is_instance_valid(back_design_selection_popup) or not is_instance_valid(back_design_selection_button):
		return
	if not back_design_selection_popup.visible:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var button_rect := back_design_selection_button.get_global_rect()
	var side_gap := 6.0
	var viewport_padding := 6.0
	var popup_width := minf(button_rect.size.x, viewport_rect.size.x - viewport_padding * 2.0)
	var content_height := back_design_selection_items.get_combined_minimum_size().y + 20.0 if is_instance_valid(back_design_selection_items) else 64.0
	var desired_height := minf(maxf(content_height, 64.0), viewport_rect.size.y * 0.45)

	# Keep the popup attached to its selector. Open below when it fits; otherwise
	# open above. If neither side has enough room, use the side with more space
	# and let the ScrollContainer handle the remaining options.
	var available_above := maxf(0.0, button_rect.position.y - viewport_rect.position.y - side_gap - viewport_padding)
	var button_bottom := button_rect.position.y + button_rect.size.y
	var available_below := maxf(0.0, viewport_rect.end.y - button_bottom - side_gap - viewport_padding)
	var open_below := available_below >= desired_height or available_below >= available_above
	var available_height := available_below if open_below else available_above
	var popup_height := minf(desired_height, available_height)
	if popup_height <= 0.0:
		back_design_selection_popup.visible = false
		return

	back_design_selection_popup.custom_minimum_size = Vector2(popup_width, popup_height)
	back_design_selection_popup.size = Vector2(popup_width, popup_height)
	if is_instance_valid(back_design_selection_scroll):
		back_design_selection_scroll.custom_minimum_size.y = maxf(40.0, popup_height - 20.0)
	var popup_y := button_bottom + side_gap if open_below else button_rect.position.y - popup_height - side_gap
	var max_popup_x := viewport_rect.end.x - popup_width - viewport_padding
	var popup_x := clampf(button_rect.position.x, viewport_rect.position.x + viewport_padding, max_popup_x)
	var popup_global_position := Vector2(popup_x, popup_y)
	# button_rect is already in canvas/global UI coordinates. Assign the popup's
	# global position directly; converting through PhoneEditorRoot shifts it
	# because that control is offset/scaled inside the editor interface.
	back_design_selection_popup.global_position = popup_global_position


func _rebuild_back_design_selection_popup() -> void:
	if not is_instance_valid(back_design_selection_items):
		return
	for child in back_design_selection_items.get_children():
		child.queue_free()
	for index in range(back_design_boxes.size()):
		var box: Dictionary = back_design_boxes[index]
		var item := Button.new()
		item.text = "RAISED BOX  %d%s" % [int(box["id"]), "   ✓ SELECTED" if index == selected_back_design_box else ""]
		item.custom_minimum_size = Vector2(0, 48)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.focus_mode = Control.FOCUS_NONE
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_theme_font_size_override("font_size", 15)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#10334a")
		normal.border_color = Color("#285b78")
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(8)
		normal.content_margin_left = 14
		item.add_theme_stylebox_override("normal", normal)
		item.add_theme_stylebox_override("hover", normal)
		item.add_theme_stylebox_override("pressed", normal)
		item.add_theme_stylebox_override("focus", normal)
		item.add_theme_color_override("font_color", Color("#e8f7ff"))
		item.pressed.connect(_select_back_design_box.bind(index))
		back_design_selection_items.add_child(item)
	back_design_selection_button.disabled = back_design_boxes.is_empty()
	if selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		var selected: Dictionary = back_design_boxes[selected_back_design_box]
		back_design_selection_button.text = "RAISED BOX  %d  ▼" % int(selected["id"])
	else:
		back_design_selection_button.text = "CHOOSE RAISED BOX  ▼"
	if back_design_boxes.is_empty():
		back_design_selection_button.text = "ADD A BOX TO SELECT"
		back_design_selection_popup.visible = false
	elif back_design_selection_popup.visible:
		call_deferred("_position_back_design_selection_popup")


func _style_back_design_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#102f46")
	track.border_color = Color("#477f9e")
	track.set_border_width_all(1)
	track.set_corner_radius_all(8)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#a9e7ff")
	grabber.border_color = Color.WHITE
	grabber.set_border_width_all(2)
	grabber.set_corner_radius_all(20)
	grabber.content_margin_left = 5
	grabber.content_margin_right = 5
	grabber.content_margin_top = 5
	grabber.content_margin_bottom = 5
	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color.WHITE
	grabber_hover.border_color = Color("#65caff")
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_filter = Control.MOUSE_FILTER_STOP


func _add_back_design_pad_spacer(parent: GridContainer) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 620.0 or viewport_size.x < 600.0
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 38) if tight else Vector2(48, 42)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)

func _add_back_design_pad_button(parent: GridContainer, caption: String, direction: Vector2i) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 620.0 or viewport_size.x < 600.0
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(44, 38) if tight else Vector2(48, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(button, 22 if not tight else 20)
	_style_staff_button(button, true)
	button.pressed.connect(_on_back_design_pad_pressed.bind(direction))
	parent.add_child(button)

func _set_back_design_mode(mode: String) -> void:
	back_design_mode = mode
	_show_back_design_controls()

func _toggle_back_design_size_action() -> void:
	back_design_size_action = "SHRINK" if back_design_size_action == "EXPAND" else "EXPAND"
	_show_back_design_controls()

func _add_back_design_box() -> void:
	var box_size := Vector2(0.34, 0.34)
	var half := box_size * 0.5
	var body_half := Vector2(PHONE_SIZE.x * 0.5, PHONE_SIZE.y * 0.5)
	var min_x := -body_half.x + half.x
	var max_x := body_half.x - half.x
	var min_y := -body_half.y + half.y
	var max_y := body_half.y - half.y
	var placed := false
	# Scan the usable back in small steps so a new box occupies an actually free spot.
	var y := max_y
	while y >= min_y and not placed:
		var x := min_x
		while x <= max_x and not placed:
			var box_position := Vector2(x, y)
			if _back_design_position_is_free(box_position, box_size, -1):
				back_design_boxes.append({"id": next_back_design_box_id, "position": box_position, "size": box_size, "border": 0.08, "use_device_color": true, "custom_color": device_body_color})
				selected_back_design_box = back_design_boxes.size() - 1
				next_back_design_box_id += 1
				placed = true
			x += 0.08
		y -= 0.08
	if placed:
		_refresh_back_design_boxes()
		_refresh_back_design_panel()

func _remove_selected_back_design_box() -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size(): return
	back_design_boxes.remove_at(selected_back_design_box)
	selected_back_design_box = mini(selected_back_design_box, back_design_boxes.size() - 1)
	_refresh_back_design_boxes()
	_refresh_back_design_panel()

func _select_back_design_box(index: int) -> void:
	if index < 0 or index >= back_design_boxes.size():
		return
	selected_back_design_box = index
	if is_instance_valid(back_design_selection_popup):
		back_design_selection_popup.visible = false
	_refresh_back_design_boxes()
	_refresh_back_design_panel()

func _back_design_position_is_free(box_position: Vector2, box_size: Vector2, ignore_index: int) -> bool:
	var half := box_size * 0.5
	# The phone body and other raised boxes are the only placement constraints.
	if absf(box_position.x) + half.x > PHONE_SIZE.x * 0.5: return false
	if absf(box_position.y) + half.y > PHONE_SIZE.y * 0.5: return false
	for index in range(back_design_boxes.size()):
		if index == ignore_index: continue
		var other: Dictionary = back_design_boxes[index]
		var other_half: Vector2 = other["size"] * 0.5
		var other_position: Vector2 = other["position"]
		if absf(box_position.x - other_position.x) < half.x + other_half.x and absf(box_position.y - other_position.y) < half.y + other_half.y: return false
	return true

func _on_back_design_pad_pressed(direction: Vector2i) -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size():
		return
	var box: Dictionary = back_design_boxes[selected_back_design_box]
	var box_position: Vector2 = box["position"]
	var box_size: Vector2 = box["size"]
	# Convert the visible D-pad direction through the camera and phone
	# transforms. This accounts for the mirrored back face and any preview
	# rotation, so LEFT always means screen-left and UP always means screen-up.
	var local_basis := phone_body.global_transform.basis.inverse()
	var camera_right_local := local_basis * preview_camera.global_transform.basis.x
	var camera_up_local := local_basis * preview_camera.global_transform.basis.y
	var local_direction_3d := camera_right_local * float(direction.x) + camera_up_local * float(direction.y)
	var local_direction := Vector2(local_direction_3d.x, local_direction_3d.y)
	if local_direction.length_squared() < 0.000001:
		return
	local_direction = local_direction.normalized()
	if back_design_mode == "MOVE":
		var next_position := box_position + local_direction * 0.04
		if _back_design_position_is_free(next_position, box_size, selected_back_design_box):
			box["position"] = next_position
	else:
		# Each arrow edits the corresponding visible edge. EXPAND adds size;
		# SHRINK removes size. The selected edge remains anchored in place.
		var half := box_size * 0.5
		var next_position := box_position
		var next_half := half
		var step := 0.025 if back_design_size_action == "EXPAND" else -0.025
		# A resize arrow changes the nearest visible edge, not a diagonal corner.
		if absf(local_direction.x) >= absf(local_direction.y):
			local_direction = Vector2(signf(local_direction.x), 0.0)
		else:
			local_direction = Vector2(0.0, signf(local_direction.y))
		if local_direction.x < 0.0:
			next_position.x -= step * 0.5
			next_half.x += step * 0.5
		elif local_direction.x > 0.0:
			next_position.x += step * 0.5
			next_half.x += step * 0.5
		elif local_direction.y > 0.0:
			next_position.y += step * 0.5
			next_half.y += step * 0.5
		elif local_direction.y < 0.0:
			next_position.y -= step * 0.5
			next_half.y += step * 0.5
		var next_size := next_half * 2.0
		if next_size.x > 0.001 and next_size.y > 0.001 and _back_design_position_is_free(next_position, next_size, selected_back_design_box):
			box["position"] = next_position
			box["size"] = next_size
	back_design_boxes[selected_back_design_box] = box
	_refresh_back_design_boxes()
	_refresh_back_design_panel()

func _on_back_design_border_changed(value: float) -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size(): return
	back_design_boxes[selected_back_design_box]["border"] = value
	_refresh_back_design_boxes()
	if is_instance_valid(back_design_border_label): back_design_border_label.text = "ROUNDING  %.0f%%" % (value / 0.45 * 100.0)

func _refresh_back_design_panel() -> void:
	if not is_instance_valid(back_design_selection_button):
		return
	_rebuild_back_design_selection_popup()
	var has_box := selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size()
	if has_box:
		var selected: Dictionary = back_design_boxes[selected_back_design_box]
		var size: Vector2 = selected["size"]
		back_design_size_label.text = "SIZE  %.2f × %.2f" % [size.x, size.y]
		back_design_border_slider.set_value_no_signal(float(selected["border"]))
		back_design_border_label.text = "ROUNDING  %.0f%%" % (float(selected["border"]) / 0.45 * 100.0)
	else:
		back_design_size_label.text = "ADD A BOX TO BEGIN"
		back_design_border_slider.set_value_no_signal(0.0)
		back_design_border_label.text = "NO BOX SELECTED"

func _make_back_design_mesh(box_size: Vector2, corner_radius: float, depth: float) -> ArrayMesh:
	var outline := PackedVector2Array()
	var radius := clampf(corner_radius, 0.001, minf(box_size.x, box_size.y) * 0.48)
	var centers := [Vector2(box_size.x * 0.5 - radius, box_size.y * 0.5 - radius), Vector2(-box_size.x * 0.5 + radius, box_size.y * 0.5 - radius), Vector2(-box_size.x * 0.5 + radius, -box_size.y * 0.5 + radius), Vector2(box_size.x * 0.5 - radius, -box_size.y * 0.5 + radius)]
	for corner in range(4):
		for segment in range(5):
			var angle := float(corner) * PI * 0.5 + float(segment) / 4.0 * PI * 0.5
			outline.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	var indices := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer_z := -depth
	for index in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var c: Vector2 = outline[indices[index + 2]]
		_add_phone_mesh_triangle(surface, Vector3(a.x, a.y, outer_z), Vector3(b.x, b.y, outer_z), Vector3(c.x, c.y, outer_z), Vector3(0, 0, -1))
		_add_phone_mesh_triangle(surface, Vector3(a.x, a.y, 0), Vector3(c.x, c.y, 0), Vector3(b.x, b.y, 0), Vector3(0, 0, 1))
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[next]
		var normal := Vector3((b - a).y, -(b - a).x, 0).normalized()
		var fa := Vector3(a.x, a.y, outer_z)
		var fb := Vector3(b.x, b.y, outer_z)
		var ba := Vector3(a.x, a.y, 0)
		var bb := Vector3(b.x, b.y, 0)
		_add_phone_mesh_triangle(surface, fa, ba, bb, normal)
		_add_phone_mesh_triangle(surface, fa, bb, fb, normal)
	return surface.commit()

func _create_back_design_box_material(box: Dictionary, box_size: Vector2, selected: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 solid_color : source_color = vec4(0.2, 0.3, 0.4, 1.0);
uniform vec4 gradient_color : source_color = vec4(0.325, 0.427, 0.996, 1.0);
uniform bool gradient_enabled = false;
uniform int gradient_direction : hint_range(0, 3) = 0;
uniform vec2 box_size = vec2(0.8, 0.8);
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	if (local_normal.z > 0.5 || !gradient_enabled) {
		ALBEDO = solid_color.rgb;
	} else {
		vec2 p = local_position.xy / max(box_size, vec2(0.001)) + vec2(0.5);
		float t = p.y;
		if (gradient_direction == 1) {
			t = p.x;
		} else if (gradient_direction == 2) {
			t = clamp((p.x + p.y) * 0.5, 0.0, 1.0);
		} else if (gradient_direction == 3) {
			t = clamp(length((p - vec2(0.5)) * vec2(1.0, 1.8)) * 1.4142, 0.0, 1.0);
		}
		ALBEDO = mix(solid_color.rgb, gradient_color.rgb, clamp(t, 0.0, 1.0));
	}
	METALLIC = 0.34;
	ROUGHNESS = 0.48;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var base_color: Color = Color(box.get("custom_color", device_body_color))
	base_color = base_color.lightened(0.045) if selected else base_color.darkened(0.10)
	material.set_shader_parameter("solid_color", base_color)
	material.set_shader_parameter("gradient_color", Color(box.get("gradient_color", Color("#536dfe"))))
	material.set_shader_parameter("gradient_enabled", bool(box.get("gradient_enabled", false)))
	material.set_shader_parameter("gradient_direction", int(box.get("gradient_direction", 0)))
	material.set_shader_parameter("box_size", box_size)
	return material


func _refresh_back_design_boxes() -> void:
	if not is_instance_valid(phone_body): return
	var old_root := phone_body.get_node_or_null("BackDesignRaisedSections")
	if is_instance_valid(old_root): old_root.free()
	if back_design_boxes.is_empty():
		_refresh_rear_hardware_visuals()
		return
	var root := Node3D.new()
	root.name = "BackDesignRaisedSections"
	phone_body.add_child(root)
	var phone_depth := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
	for index in range(back_design_boxes.size()):
		var box: Dictionary = back_design_boxes[index]
		var size: Vector2 = box["size"]
		var raised := MeshInstance3D.new()
		raised.name = "RaisedBackBox_%d" % int(box["id"])
		raised.mesh = _make_back_design_mesh(size, minf(size.x, size.y) * float(box["border"]), 0.035 / 1.10 / 1.5)
		var material := StandardMaterial3D.new()
		var box_uses_device_color := bool(box.get("use_device_color", true))
		var box_color: Color = device_body_color if box_uses_device_color else Color(box.get("custom_color", device_body_color))
		if box_uses_device_color:
			material.albedo_color = box_color.lightened(0.045) if index == selected_back_design_box else box_color.darkened(0.10)
			material.metallic = 0.34
			material.roughness = 0.48
			raised.material_override = material
		else:
			raised.material_override = _create_back_design_box_material(box, size, index == selected_back_design_box)
		raised.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var box_center: Vector2 = box["position"]
		raised.position = Vector3(box_center.x, box_center.y, -phone_depth * 0.5)
		root.add_child(raised)
	_refresh_rear_hardware_visuals()

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

	bezel_height_slider = VSlider.new()
	bezel_height_slider.name = "ScreenHeightSlider"
	bezel_height_slider.min_value = 0.02
	bezel_height_slider.max_value = 0.345 - _minimum_screen_height_bezel()
	bezel_height_slider.step = 0.001
	bezel_height = clampf(bezel_height, _minimum_screen_height_bezel(), 0.325)
	bezel_height_slider.value = 0.345 - bezel_height
	bezel_height_slider.tick_count = 14
	bezel_height_slider.custom_minimum_size = Vector2(64, 250)
	bezel_height_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bezel_height_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bezel_height_slider.value_changed.connect(_on_bezel_height_changed)
	_style_feature_slider(bezel_height_slider)
	height_column.add_child(bezel_height_slider)

	bezel_width = 0.17 - width_slider.value
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
	bezel_height = clampf(0.345 - value, _minimum_screen_height_bezel(), 0.325)
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


func _minimum_screen_height_bezel() -> float:
	# The bezel camera occupies a small permanent strip of the handset frame.
	# Because the display remains centred, half of this reserve is the minimum
	# top/bottom bezel thickness required to keep the camera on the phone.
	return 0.07 if front_camera_enabled and front_camera_style == "Bezel Camera" else 0.02


func _update_bezel_height_slider_limit() -> void:
	if not is_instance_valid(bezel_height_slider):
		return
	var minimum_bezel := _minimum_screen_height_bezel()
	bezel_height = clampf(bezel_height, minimum_bezel, 0.325)
	bezel_height_slider.max_value = 0.345 - minimum_bezel
	bezel_height_slider.set_value_no_signal(0.345 - bezel_height)
	_update_bezel_value_labels()


func _is_screen_height_max() -> bool:
	return bezel_height <= _minimum_screen_height_bezel() + 0.0005


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
	const CORNER_SEGMENTS := 24
	for corner_index in range(4):
		var center: Vector2 = centers[corner_index]
		var start_angle := float(corner_index) * PI * 0.5
		for segment in range(CORNER_SEGMENTS + 1):
			var angle := start_angle + float(segment) / float(CORNER_SEGMENTS) * PI * 0.5
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
		var side_normal := Vector3(edge.y, -edge.x, 0.0).normalized()
		var previous_a: Vector2 = outline[(index - 1 + outline.size()) % outline.size()]
		var previous_edge := a - previous_a
		var previous_normal := Vector3(previous_edge.y, -previous_edge.x, 0.0).normalized()
		var next_b: Vector2 = outline[(next_index + 1) % outline.size()]
		var next_edge := next_b - b
		var next_normal := Vector3(next_edge.y, -next_edge.x, 0.0).normalized()
		var normal_a := (previous_normal + side_normal).normalized()
		var normal_b := (side_normal + next_normal).normalized()
		var front_a := Vector3(a.x, a.y, front_z)
		var front_b := Vector3(b.x, b.y, front_z)
		var back_a := Vector3(a.x, a.y, back_z)
		var back_b := Vector3(b.x, b.y, back_z)
		_add_phone_mesh_triangle_with_normals(surface, front_a, back_a, back_b, normal_a, normal_a, normal_b)
		_add_phone_mesh_triangle_with_normals(surface, front_a, back_b, front_b, normal_a, normal_b, normal_b)
	return surface.commit()


func _create_curved_screen_mesh(width: float, height: float, corner_radius: float, curve_sides: bool, curve_vertical: bool) -> ArrayMesh:
	# Keep the curved glass on the same rounded-rectangle footprint as the
	# handset. The edge bend changes depth only; it must not square off corners.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const X_SEGMENTS := 48
	const Y_SEGMENTS := 80
	const SIDE_BEND := 0.028
	const VERTICAL_BEND := 0.028
	var half_width := width * 0.5
	var half_height := height * 0.5
	var radius := clampf(corner_radius, 0.0, minf(half_width, half_height))
	var corner_x := half_width - radius
	var corner_y := half_height - radius
	var points: Array[Vector3] = []
	for y_index in range(Y_SEGMENTS + 1):
		var v := float(y_index) / float(Y_SEGMENTS)
		var raw_y := (0.5 - v) * height
		for x_index in range(X_SEGMENTS + 1):
			var u := float(x_index) / float(X_SEGMENTS)
			var raw_x := (u - 0.5) * width
			var x := raw_x
			var y := raw_y
			# Project grid samples outside the rounded corner arcs onto the
			# exact radius. This gives the curved mesh the same corner profile
			# as the phone body instead of a rectangular glass silhouette.
			if radius > 0.0001 and absf(raw_x) > corner_x and absf(raw_y) > corner_y:
				var corner_center := Vector2(signf(raw_x) * corner_x, signf(raw_y) * corner_y)
				var corner_offset := Vector2(raw_x, raw_y) - corner_center
				if corner_offset.length_squared() > radius * radius:
					corner_offset = corner_offset.normalized() * radius
					x = corner_center.x + corner_offset.x
					y = corner_center.y + corner_offset.y
			var side_drop := 0.0
			var vertical_drop := 0.0
			if curve_sides:
				side_drop = SIDE_BEND * pow(absf(x / maxf(half_width, 0.001)), 6.0)
			if curve_vertical:
				vertical_drop = VERTICAL_BEND * pow(absf(y / maxf(half_height, 0.001)), 6.0)
			# Blend the two edge curves instead of stacking their depth.
			var z := -maxf(side_drop, vertical_drop)
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
	# Merge identical grid vertices before normal generation so adjacent
	# triangles share averaged normals instead of producing a faceted glass panel.
	surface.index()
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
		_refresh_phone_home_button()
		return

	var display := MeshInstance3D.new()
	display.name = "PhoneDisplayPanel"
	# Keep a consistent, slimmer lower rail for physical keys and give the
	# top rail the exact same height. The glass is inset evenly on all sides.
	# Symmetrical bezels consume the outer edges; the display fills the remaining area.
	var screen_width := PHONE_SIZE.x if screen_shape_mode == "Curve screen" and side_curve_enabled else maxf(0.30, PHONE_SIZE.x - bezel_width * 2.0)
	var screen_height := PHONE_SIZE.y if screen_shape_mode == "Curve screen" and vertical_curve_enabled else maxf(0.60, PHONE_SIZE.y - bezel_height * 2.0)
	# The display inherits the phone's exact outer corner radius so curved
	# glass and frame stay visually aligned as Border Radius is upgraded.
	var screen_radius := 0.32 * float(border_radius_level) / 6.0
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
	var current_depth := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
	var curved_display := screen_shape_mode == "Curve screen" and (side_curve_enabled or vertical_curve_enabled)
	display.position = Vector3(0.0, 0.0, current_depth * 0.5 + (0.0315 if curved_display else 0.0035))
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	phone_body.add_child(display)
	phone_screen = display
	_refresh_front_camera(display, screen_width, screen_height)
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

	_refresh_phone_home_button()

func _show_front_camera_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "FrontCameraControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("FRONT CAMERA", 19, Color("#c7eaff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	var enable_row := HBoxContainer.new()
	enable_row.name = "FrontCameraEnablementRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 9)
	active_feature_panel.add_child(enable_row)

	var enable_toggle := Button.new()
	enable_toggle.name = "FrontCameraEnablement"
	enable_toggle.toggle_mode = true
	enable_toggle.button_pressed = front_camera_enabled
	enable_toggle.text = "✓" if front_camera_enabled else ""
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
	enable_toggle.toggled.connect(_on_front_camera_enablement_toggled)
	enable_row.add_child(enable_toggle)

	var enable_label := _make_label("Front Camera Enablement", 14, Color.WHITE)
	enable_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enable_row.add_child(enable_label)

	var style_list := VBoxContainer.new()
	style_list.name = "FrontCameraStyles"
	style_list.add_theme_constant_override("separation", 7)
	active_feature_panel.add_child(style_list)

	front_camera_option_buttons.clear()
	for index in range(FRONT_CAMERA_STYLES.size()):
		var style_name: String = FRONT_CAMERA_STYLES[index]
		var option := Button.new()
		option.name = "FrontCamera_" + style_name.replace(" ", "").replace("-", "")
		option.text = style_name
		option.custom_minimum_size = Vector2(0, 42)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(option, 12)
		_style_screen_type_option(option, mini(index + 2, 9), style_name == front_camera_style)
		option.disabled = not front_camera_enabled
		option.pressed.connect(_on_front_camera_style_selected.bind(style_name))
		style_list.add_child(option)
		front_camera_option_buttons[style_name] = option


func _on_front_camera_enablement_toggled(enabled: bool) -> void:
	front_camera_enabled = enabled
	_update_bezel_height_slider_limit()
	_refresh_phone_screen()
	var toggle := active_feature_panel.get_node_or_null("FrontCameraEnablementRow/FrontCameraEnablement") if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(toggle):
		toggle.text = "✓" if enabled else ""
	for style_name in front_camera_option_buttons:
		var option: Button = front_camera_option_buttons[style_name]
		option.disabled = not enabled


func _on_front_camera_style_selected(style_name: String) -> void:
	if not FRONT_CAMERA_STYLES.has(style_name):
		return
	front_camera_style = style_name
	_update_bezel_height_slider_limit()
	_refresh_phone_screen()
	for option_name in front_camera_option_buttons:
		var option: Button = front_camera_option_buttons[option_name]
		_style_screen_type_option(option, mini(FRONT_CAMERA_STYLES.find(option_name) + 2, 9), option_name == front_camera_style)


func _front_camera_screen_surface_z(x: float, y: float, screen_width: float, screen_height: float) -> float:
	# Match the exact depth profile used by _create_curved_screen_mesh so
	# side-mounted lenses sit just above the glass instead of floating over
	# the flat centre plane when either screen edge is curved.
	if screen_shape_mode != "Curve screen":
		return 0.0
	var side_drop := 0.0
	var vertical_drop := 0.0
	if side_curve_enabled:
		side_drop = 0.028 * pow(absf(x / maxf(screen_width * 0.5, 0.001)), 6.0)
	if vertical_curve_enabled:
		vertical_drop = 0.028 * pow(absf(y / maxf(screen_height * 0.5, 0.001)), 6.0)
	return -maxf(side_drop, vertical_drop)


func _side_camera_safe_y(fallback_y: float) -> float:
	# Enforce an exact, cumulative downward movement of 0.012 units per
	# border-radius level. Level 0 keeps the normal top inset unchanged.
	return fallback_y - (0.012 * float(border_radius_level))


func _refresh_front_camera(display: MeshInstance3D, screen_width: float, screen_height: float) -> void:
	if not front_camera_enabled:
		return

	var camera_root := Node3D.new()
	camera_root.name = "FrontCameraAssembly"
	display.add_child(camera_root)

	# All placements use the actual screen's top edge and a small, consistent
	# stand-off from the glass. This keeps the camera centred and aligned when
	# the user changes screen dimensions or bezel settings.
	var top_edge := screen_height * 0.5
	var top_inset := clampf(screen_height * 0.035, 0.055, 0.095)
	# Standard front-camera styles keep a fixed top inset. Border Radius
	# adjustments are applied only inside the Side Punch-Hole style below.
	var camera_y := top_edge - top_inset
	camera_root.set_meta("camera_y", camera_y)
	var front_z := 0.014

	var cutout_material := StandardMaterial3D.new()
	cutout_material.albedo_color = Color("#020407")
	cutout_material.roughness = 0.20
	cutout_material.metallic = 0.08
	cutout_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color("#142d49")
	lens_material.metallic = 0.72
	lens_material.roughness = 0.13
	lens_material.emission_enabled = true
	lens_material.emission = Color("#102c4c")
	lens_material.emission_energy_multiplier = 0.10

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("#46515e")
	ring_material.metallic = 0.82
	ring_material.roughness = 0.24

	match front_camera_style:
		"Bezel Camera":
			# Place the lens in the actual top bezel, centred between the display
			# edge and handset edge. The height slider is capped so this strip
			# always remains available without shifting or clipping the display.
			var bezel_camera_y := top_edge + bezel_height * 0.5
			# The camera assembly is parented to the raised display mesh. Offset
			# its lens back through that display offset so the bezel ring seats on
			# the handset's actual front plane instead of hovering above it.
			# Seat the bezel lens on the handset's front face. The display is
			# raised above that face (and may be raised further for curved screens),
			# so cancel only that display offset rather than moving behind the body.
			var phone_front_z := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0) * 0.5
			var bezel_seated_z := phone_front_z - display.position.z
			_add_front_camera_lens(camera_root, Vector3(0.0, bezel_camera_y, bezel_seated_z), 0.032, cutout_material, lens_material, ring_material)
		"Waterdrop Notch":
			# Restore the original compact oval glass with the selfie camera
			# sitting just beneath its centre; no oversized teardrop geometry.
			_add_camera_cutout(camera_root, "WaterdropNotchCutout", Vector2(0.19, 0.105), Vector2(0.0, 0.0), front_z, cutout_material)
			_add_front_camera_lens(camera_root, Vector3(0.0, camera_y - 0.020, front_z + 0.008), 0.025, cutout_material, lens_material, ring_material)
		"Punch-Hole":
			# Single, small circular opening centred on the top safe area.
			_add_front_camera_lens(camera_root, Vector3(0.0, camera_y, front_z), 0.038, cutout_material, lens_material, ring_material)
		"Side Punch-Hole":
			# Keep the camera in a consistent side section of the display instead
			# of using a fixed edge inset that changes its apparent position when
			# the screen expands for a side curve.
			var side_lens_radius := 0.037
			var side_camera_x := -screen_width * (0.40 if border_radius_level == 0 else 0.36)
			# Side-camera positioning starts from the unbordered top inset.
			# The helper then applies only a gradual, capped correction per level.
			var side_camera_base_y := top_edge - top_inset
			var side_camera_y := _side_camera_safe_y(side_camera_base_y)
			var side_camera_z := front_z + _front_camera_screen_surface_z(side_camera_x, side_camera_y, screen_width, screen_height)
			_add_front_camera_lens(camera_root, Vector3(side_camera_x, side_camera_y, side_camera_z), side_lens_radius, cutout_material, lens_material, ring_material)
		"Dual Punch-Hole":
			# Two distinct, evenly spaced circular openings centred at the top.
			var dual_spacing := 0.052
			_add_front_camera_lens(camera_root, Vector3(-dual_spacing, camera_y, front_z), 0.030, cutout_material, lens_material, ring_material)
			_add_front_camera_lens(camera_root, Vector3(dual_spacing, camera_y, front_z), 0.030, cutout_material, lens_material, ring_material)
		"Pop-Up Camera":
			# Centre the physical module on the handset's top edge and reduce
			# its previous width by exactly 50%.
			var popup_x := 0.0
			var popup_y := PHONE_SIZE.y * 0.5 + 0.055
			var popup_width := 0.15
			# camera_root is parented to the display, so cancel the display front-face offset.
			# This places the pop-up housing on the phone body\'s Z centre.
			var popup_center_z := -display.position.z
			var popup_housing := MeshInstance3D.new()
			popup_housing.name = "PopUpCameraHousing"
			popup_housing.mesh = _create_rounded_panel_mesh(popup_width, 0.13, 0.035, 0.045)
			popup_housing.position = Vector3(popup_x, popup_y, popup_center_z)
			popup_housing.material_override = ring_material
			popup_housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			camera_root.add_child(popup_housing)
			_add_front_camera_lens(camera_root, Vector3(popup_x, popup_y, popup_center_z + 0.022), 0.038, cutout_material, lens_material, ring_material)
		"Dynamic Island":
			# iPhone 17 Pro Max-inspired compact, deep-black capsule. Keep the
			# opening narrow relative to the display, with a true semicircular end.
			var island_height := 0.105
			var island_width := minf(0.36, screen_width * 0.34)
			var island_y := top_edge - top_inset
			var island_glass := StandardMaterial3D.new()
			island_glass.albedo_color = Color("#010204")
			island_glass.metallic = 0.12
			island_glass.roughness = 0.12
			island_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			var island_mesh := MeshInstance3D.new()
			island_mesh.name = "DynamicIslandCutout"
			island_mesh.mesh = _create_rounded_panel_mesh(island_width, island_height, 0.008, island_height * 0.5)
			island_mesh.position = Vector3(0.0, island_y, front_z)
			island_mesh.material_override = island_glass
			island_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			camera_root.add_child(island_mesh)
			# The camera glass is almost invisible inside the black capsule;
			# avoid the bright metallic lens ring used by ordinary punch-holes.
			var island_lens_ring := StandardMaterial3D.new()
			island_lens_ring.albedo_color = Color("#05080d")
			island_lens_ring.metallic = 0.18
			island_lens_ring.roughness = 0.16
			var island_lens := StandardMaterial3D.new()
			island_lens.albedo_color = Color("#10223a")
			island_lens.metallic = 0.58
			island_lens.roughness = 0.10
			island_lens.emission_enabled = true
			island_lens.emission = Color("#07172b")
			island_lens.emission_energy_multiplier = 0.06
			_add_front_camera_lens(camera_root, Vector3(island_width * 0.28, island_y, front_z + 0.014), 0.023, island_glass, island_lens, island_lens_ring)
			_add_camera_sensor_dot(camera_root, Vector3(-island_width * 0.25, island_y, front_z + 0.014), 0.009, island_lens_ring)
		"Under-Display Camera":
			# The lens sits beneath the panel: show only a very subtle optical
			# window, not a punched-out black hole.
			var hidden_lens := MeshInstance3D.new()
			hidden_lens.name = "UnderDisplayCameraOpticalWindow"
			var hidden_mesh := CylinderMesh.new()
			hidden_mesh.top_radius = 0.026
			hidden_mesh.bottom_radius = 0.026
			hidden_mesh.height = 0.0015
			hidden_mesh.radial_segments = 40
			hidden_lens.mesh = hidden_mesh
			hidden_lens.rotation_degrees.x = 90.0
			hidden_lens.position = Vector3(0.0, camera_y, front_z)
			var hidden_material := StandardMaterial3D.new()
			hidden_material.albedo_color = Color(0.025, 0.055, 0.085, 0.22)
			hidden_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hidden_material.roughness = 0.28
			hidden_lens.material_override = hidden_material
			camera_root.add_child(hidden_lens)


func _add_camera_cutout(parent: Node3D, node_name: String, cutout_size: Vector2, offset: Vector2, front_z: float, material: Material) -> void:
	var cutout := MeshInstance3D.new()
	cutout.name = node_name
	cutout.mesh = _create_rounded_panel_mesh(cutout_size.x, cutout_size.y, 0.006, cutout_size.y * 0.49)
	cutout.position = Vector3(offset.x, 0.0, front_z)
	# The parent is attached to the screen mesh; its vertical offset is supplied
	# by the caller through the cutout's local position.
	cutout.position.y = parent.get_meta("camera_y", 0.0) + offset.y
	cutout.material_override = material
	cutout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cutout)


func _add_camera_sensor_dot(parent: Node3D, dot_position: Vector3, radius: float, material: Material) -> void:
	var dot := MeshInstance3D.new()
	dot.name = "FrontCameraProximitySensor"
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	dot.mesh = mesh
	dot.position = dot_position
	dot.material_override = material
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dot)


func _add_front_camera_lens(parent: Node3D, lens_position: Vector3, radius: float, _dark_material: Material, lens_material: Material, ring_material: Material) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "FrontCameraLensRing"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = radius
	ring_mesh.bottom_radius = radius
	ring_mesh.height = 0.008
	ring_mesh.radial_segments = 32
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90.0
	ring.position = lens_position
	ring.material_override = ring_material
	parent.add_child(ring)

	var lens := MeshInstance3D.new()
	lens.name = "FrontCameraLens"
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = radius * 0.68
	lens_mesh.bottom_radius = radius * 0.68
	lens_mesh.height = 0.006
	lens_mesh.radial_segments = 32
	lens.mesh = lens_mesh
	lens.rotation_degrees.x = 90.0
	lens.position = lens_position + Vector3(0.0, 0.0, 0.006)
	lens.material_override = lens_material
	parent.add_child(lens)


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




func _show_rear_camera_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()

	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "RearCameraFlashControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y < 760.0 or viewport_size.x < 900.0
	var tight := viewport_size.y < 620.0 or viewport_size.x < 600.0
	var control_height := 40.0 if tight else (43.0 if compact else 47.0)
	var slider_height := 32.0 if tight else (36.0 if compact else 40.0)
	var section_gap := 4 if tight else (5 if compact else 7)
	active_feature_panel.add_theme_constant_override("separation", section_gap)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("REAR CAMERA & FLASH", 16 if compact else 18, Color("#c7eaff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	_add_back_design_flexible_space(active_feature_panel)

	var mode_row := HBoxContainer.new()
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(mode_row)
	for mode in ["CAMERA", "FLASH"]:
		var mode_button := Button.new()
		mode_button.text = mode
		mode_button.custom_minimum_size.y = control_height
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(mode_button, 12 if tight else 13)
		_style_staff_button(mode_button, rear_hardware_mode == mode)
		mode_button.pressed.connect(_set_rear_hardware_mode.bind(mode))
		mode_row.add_child(mode_button)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(actions)
	rear_hardware_add_button = Button.new()
	rear_hardware_add_button.text = "+ ADD CAMERA" if rear_hardware_mode == "CAMERA" else "+ ADD FLASH"
	rear_hardware_add_button.custom_minimum_size.y = control_height
	rear_hardware_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(rear_hardware_add_button, 11 if tight else 12)
	_style_staff_button(rear_hardware_add_button, true)
	rear_hardware_add_button.pressed.connect(_add_rear_hardware_module)
	actions.add_child(rear_hardware_add_button)

	rear_hardware_remove_button = Button.new()
	rear_hardware_remove_button.text = "− REMOVE"
	rear_hardware_remove_button.custom_minimum_size.y = control_height
	rear_hardware_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(rear_hardware_remove_button, 11 if tight else 12)
	_style_staff_button(rear_hardware_remove_button, false)
	rear_hardware_remove_button.pressed.connect(_remove_rear_hardware_module)
	actions.add_child(rear_hardware_remove_button)
	_add_back_design_flexible_space(active_feature_panel)

	var selection_row := HBoxContainer.new()
	selection_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_theme_constant_override("separation", 5)
	active_feature_panel.add_child(selection_row)

	rear_hardware_previous_button = Button.new()
	rear_hardware_previous_button.text = "‹"
	rear_hardware_previous_button.custom_minimum_size = Vector2(38, control_height)
	rear_hardware_previous_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(rear_hardware_previous_button, 22)
	_style_staff_button(rear_hardware_previous_button, false)
	rear_hardware_previous_button.pressed.connect(_cycle_rear_hardware_selection.bind(-1))
	selection_row.add_child(rear_hardware_previous_button)

	rear_hardware_item_label = _make_label("", 11 if tight else 12, Color("#d8eaf5"))
	rear_hardware_item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rear_hardware_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_row.add_child(rear_hardware_item_label)

	rear_hardware_next_button = Button.new()
	rear_hardware_next_button.text = "›"
	rear_hardware_next_button.custom_minimum_size = Vector2(38, control_height)
	rear_hardware_next_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(rear_hardware_next_button, 22)
	_style_staff_button(rear_hardware_next_button, false)
	rear_hardware_next_button.pressed.connect(_cycle_rear_hardware_selection.bind(1))
	selection_row.add_child(rear_hardware_next_button)
	_add_back_design_flexible_space(active_feature_panel)

	var move_heading := _make_label("MOVE " + rear_hardware_mode, 11 if tight else 12, Color("#a9e3ff"))
	move_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(move_heading)

	var pad := GridContainer.new()
	pad.name = "RearHardwareDirectionPad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 5 if tight else 7)
	pad.add_theme_constant_override("v_separation", 5 if tight else 7)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(pad)
	_add_back_design_pad_spacer(pad)
	_add_rear_hardware_pad_button(pad, "↑", Vector2i(0, 1), tight)
	_add_back_design_pad_spacer(pad)
	_add_rear_hardware_pad_button(pad, "←", Vector2i(-1, 0), tight)
	var center := _make_label("MOVE", 11 if tight else 13, Color("#c7eaff"))
	center.custom_minimum_size = Vector2(44, 38) if tight else Vector2(48, 42)
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pad.add_child(center)
	_add_rear_hardware_pad_button(pad, "→", Vector2i(1, 0), tight)
	_add_back_design_pad_spacer(pad)
	_add_rear_hardware_pad_button(pad, "↓", Vector2i(0, -1), tight)
	_add_back_design_pad_spacer(pad)
	_add_back_design_flexible_space(active_feature_panel)

	var size_heading := _make_label("MODULE SIZE", 11 if tight else 12, Color("#a9e3ff"))
	active_feature_panel.add_child(size_heading)
	rear_hardware_size_slider = HSlider.new()
	rear_hardware_size_slider.min_value = 0.04 if rear_hardware_mode == "CAMERA" else 0.025
	rear_hardware_size_slider.max_value = 0.17 if rear_hardware_mode == "CAMERA" else 0.10
	rear_hardware_size_slider.step = 0.005
	rear_hardware_size_slider.custom_minimum_size = Vector2(0, slider_height)
	rear_hardware_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_back_design_slider(rear_hardware_size_slider)
	rear_hardware_size_slider.value_changed.connect(_on_rear_hardware_size_changed)
	active_feature_panel.add_child(rear_hardware_size_slider)

	rear_hardware_size_label = _make_label("", 11 if tight else 12, Color("#d8eaf5"))
	rear_hardware_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(rear_hardware_size_label)
	_refresh_rear_hardware_panel()


func _add_rear_hardware_pad_button(parent: GridContainer, caption: String, direction: Vector2i, tight: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(44, 38) if tight else Vector2(48, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(button, 22 if not tight else 20)
	_style_staff_button(button, true)
	button.pressed.connect(_on_rear_hardware_pad_pressed.bind(direction))
	parent.add_child(button)


func _set_rear_hardware_mode(mode: String) -> void:
	if mode not in ["CAMERA", "FLASH"]:
		return
	rear_hardware_mode = mode
	_show_rear_camera_controls()


func _get_rear_hardware_modules() -> Array[Dictionary]:
	return rear_flash_modules if rear_hardware_mode == "FLASH" else rear_camera_modules


func _get_rear_hardware_selected_index() -> int:
	return rear_flash_selected_index if rear_hardware_mode == "FLASH" else rear_camera_selected_index


func _set_rear_hardware_selected_index(index: int) -> void:
	if rear_hardware_mode == "FLASH":
		rear_flash_selected_index = index
	else:
		rear_camera_selected_index = index


func _get_rear_hardware_default_size() -> float:
	return 0.060 if rear_hardware_mode == "FLASH" else 0.105


func _add_rear_hardware_module() -> void:
	var module_size := _get_rear_hardware_default_size()
	var spawn_position := _find_rear_hardware_spawn_position(rear_hardware_mode, module_size)
	if spawn_position.x > 900.0:
		return
	if rear_hardware_mode == "FLASH":
		rear_flash_modules.append({"id": next_rear_flash_id, "position": spawn_position, "size": module_size})
		rear_flash_selected_index = rear_flash_modules.size() - 1
		next_rear_flash_id += 1
	else:
		rear_camera_modules.append({"id": next_rear_camera_id, "position": spawn_position, "size": module_size})
		rear_camera_selected_index = rear_camera_modules.size() - 1
		next_rear_camera_id += 1
	_refresh_rear_hardware_visuals()
	_refresh_rear_hardware_panel()


func _remove_rear_hardware_module() -> void:
	var selected_index := _get_rear_hardware_selected_index()
	var modules := _get_rear_hardware_modules()
	if selected_index < 0 or selected_index >= modules.size():
		return
	modules.remove_at(selected_index)
	_set_rear_hardware_selected_index(mini(selected_index, modules.size() - 1))
	if rear_hardware_mode == "FLASH":
		rear_flash_modules = modules
	else:
		rear_camera_modules = modules
	_refresh_rear_hardware_visuals()
	_refresh_rear_hardware_panel()


func _cycle_rear_hardware_selection(direction: int) -> void:
	var modules := _get_rear_hardware_modules()
	if modules.is_empty():
		return
	var next_index := posmod(_get_rear_hardware_selected_index() + direction, modules.size())
	_set_rear_hardware_selected_index(next_index)
	_refresh_rear_hardware_panel()


func _find_rear_hardware_spawn_position(kind: String, module_size: float) -> Vector2:
	for row in range(8):
		for column in range(3):
			var candidate := Vector2.ZERO
			if kind == "FLASH":
				candidate = Vector2(0.38, 1.18 - float(row) * 0.22)
			else:
				candidate = Vector2(-0.46 + float(column) * 0.29, 1.18 - float(row) * 0.30)
			if _rear_module_position_is_free(candidate, module_size, kind, -1):
				return candidate
	return Vector2(1000.0, 1000.0)


func _rear_module_position_is_free(candidate_position: Vector2, module_size: float, kind: String, ignore_index: int) -> bool:
	# The only placement limits are the physical phone-back boundary and
	# keeping every camera/flash separate from every other hardware module.
	# Back Design boxes are NOT placement zones or obstacles: hardware can
	# cross their edges freely in either direction.
	var extent := module_size * 1.22
	if absf(candidate_position.x) + extent > PHONE_SIZE.x * 0.5 - 0.025:
		return false
	if absf(candidate_position.y) + extent > PHONE_SIZE.y * 0.5 - 0.025:
		return false
	for index in range(rear_camera_modules.size()):
		if kind == "CAMERA" and index == ignore_index:
			continue
		var other: Dictionary = rear_camera_modules[index]
		var other_position: Vector2 = other["position"]
		var other_size := float(other["size"])
		if candidate_position.distance_to(other_position) < (module_size + other_size) * 1.18 + 0.025:
			return false
	for index in range(rear_flash_modules.size()):
		if kind == "FLASH" and index == ignore_index:
			continue
		var other: Dictionary = rear_flash_modules[index]
		var other_position: Vector2 = other["position"]
		var other_size := float(other["size"])
		if candidate_position.distance_to(other_position) < (module_size + other_size) * 1.18 + 0.025:
			return false
	return true


func _on_rear_hardware_pad_pressed(direction: Vector2i) -> void:
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	if selected_index < 0 or selected_index >= modules.size() or not is_instance_valid(phone_body) or not is_instance_valid(preview_camera):
		return
	var module: Dictionary = modules[selected_index]
	var module_position: Vector2 = module["position"]
	var module_size := float(module["size"])
	# Match Back Design: pad directions are converted through the preview
	# camera and phone transforms, so the arrows follow the visible phone face.
	var local_basis := phone_body.global_transform.basis.inverse()
	var camera_right_local := local_basis * preview_camera.global_transform.basis.x
	var camera_up_local := local_basis * preview_camera.global_transform.basis.y
	var local_direction_3d := camera_right_local * float(direction.x) + camera_up_local * float(direction.y)
	var local_direction := Vector2(local_direction_3d.x, local_direction_3d.y)
	if local_direction.length_squared() < 0.000001:
		return
	local_direction = local_direction.normalized()
	var next_position := module_position + local_direction * 0.04
	# Move in small continuous steps across the flat back and raised
	# Back Design geometry. Only the phone edge and other hardware can block it.
	if not _rear_module_position_is_free(next_position, module_size, rear_hardware_mode, selected_index):
		return
	module["position"] = next_position
	if rear_hardware_mode == "FLASH":
		rear_flash_modules[selected_index] = module
	else:
		rear_camera_modules[selected_index] = module
	_refresh_rear_hardware_visuals()
	_refresh_rear_hardware_panel()


func _on_rear_hardware_size_changed(value: float) -> void:
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	if selected_index < 0 or selected_index >= modules.size():
		return
	var module: Dictionary = modules[selected_index]
	var module_position: Vector2 = module["position"]
	var next_size := clampf(value, 0.025, 0.17)
	if not _rear_module_position_is_free(module_position, next_size, rear_hardware_mode, selected_index):
		_refresh_rear_hardware_panel()
		return
	module["size"] = next_size
	if rear_hardware_mode == "FLASH":
		rear_flash_modules[selected_index] = module
	else:
		rear_camera_modules[selected_index] = module
	_refresh_rear_hardware_visuals()
	_refresh_rear_hardware_panel()


func _refresh_rear_hardware_panel() -> void:
	if not is_instance_valid(rear_hardware_item_label):
		return
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	var kind_name := "FLASH" if rear_hardware_mode == "FLASH" else "CAMERA"
	var has_selection := selected_index >= 0 and selected_index < modules.size()
	if has_selection:
		var selected: Dictionary = modules[selected_index]
		rear_hardware_item_label.text = "%s  %02d / %02d" % [kind_name, selected_index + 1, modules.size()]
		rear_hardware_size_slider.set_value_no_signal(float(selected["size"]))
		rear_hardware_size_label.text = "SIZE  %.3f" % float(selected["size"])
	else:
		rear_hardware_item_label.text = "NO %s ADDED" % kind_name
		rear_hardware_size_slider.set_value_no_signal(_get_rear_hardware_default_size())
		rear_hardware_size_label.text = "ADD A %s TO BEGIN" % kind_name
	rear_hardware_size_slider.disabled = not has_selection
	rear_hardware_remove_button.disabled = not has_selection
	rear_hardware_previous_button.disabled = modules.size() < 2
	rear_hardware_next_button.disabled = modules.size() < 2
	rear_hardware_add_button.text = "+ ADD CAMERA" if rear_hardware_mode == "CAMERA" else "+ ADD FLASH"
	rear_hardware_remove_button.text = "− REMOVE CAMERA" if rear_hardware_mode == "CAMERA" else "− REMOVE FLASH"


func _rear_hardware_support_surface_z(module_position: Vector2, _module_size: float) -> float:
	var phone_depth := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
	var surface_z := -phone_depth * 0.5
	# Let the module climb onto / descend from a raised box as its centre
	# crosses the box edge. Do not require its whole footprint to fit inside.
	for box in back_design_boxes:
		var box_position: Vector2 = box["position"]
		var half: Vector2 = box["size"] * 0.5
		var centre_is_over_box := absf(module_position.x - box_position.x) <= half.x and absf(module_position.y - box_position.y) <= half.y
		if centre_is_over_box:
			# Raised Back Design mesh extrudes toward the outside of the rear face.
			return surface_z - (0.035 / 1.10 / 1.5)
	return surface_z


func _refresh_rear_hardware_visuals() -> void:
	if not is_instance_valid(phone_body):
		return
	var previous := phone_body.get_node_or_null("RearCameraFlashHardware")
	if is_instance_valid(previous):
		previous.free()
	if rear_camera_modules.is_empty() and rear_flash_modules.is_empty():
		return
	var root := Node3D.new()
	root.name = "RearCameraFlashHardware"
	phone_body.add_child(root)
	for camera_index in range(rear_camera_modules.size()):
		var module: Dictionary = rear_camera_modules[camera_index]
		var module_position: Vector2 = module["position"]
		var module_size := float(module["size"])
		var support_z := _rear_hardware_support_surface_z(module_position, module_size)
		# One permanent Samsung Galaxy-inspired rear-camera appearance.
		# Selection, movement, resizing and refreshes must never swap its style.
		var housing_material := StandardMaterial3D.new()
		housing_material.albedo_color = Color("#05070a")
		housing_material.metallic = 0.88
		housing_material.roughness = 0.20
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color("#171d25")
		ring_material.metallic = 0.94
		ring_material.roughness = 0.14
		var lens_material := StandardMaterial3D.new()
		lens_material.albedo_color = Color("#03070d")
		lens_material.metallic = 0.62
		lens_material.roughness = 0.075
		lens_material.clearcoat_enabled = true
		lens_material.clearcoat = 0.9
		lens_material.clearcoat_roughness = 0.06
		var module_id := int(module["id"])
		# Reduce the complete raised stack to two-thirds of its former height.
		# Scale that shallow profile with the size slider so larger modules gain
		# a little more relief and smaller modules become flatter.
		var camera_depth_scale := (module_size / 0.08) / 1.5
		var camera_layer := func(depth: float) -> float: return depth * camera_depth_scale
		_add_rear_hardware_disc(root, "RearCamera_%d_Housing" % module_id, Vector3(module_position.x, module_position.y, support_z - camera_layer.call(0.010)), module_size * 1.22, camera_layer.call(0.020), housing_material)
		_add_rear_hardware_disc(root, "RearCamera_%d_Rim" % module_id, Vector3(module_position.x, module_position.y, support_z - camera_layer.call(0.021)), module_size * 1.04, camera_layer.call(0.006), ring_material)
		_add_rear_hardware_disc(root, "RearCamera_%d_Gasket" % module_id, Vector3(module_position.x, module_position.y, support_z - camera_layer.call(0.025)), module_size * 0.88, camera_layer.call(0.003), housing_material)
		_add_rear_hardware_disc(root, "RearCamera_%d_Lens" % module_id, Vector3(module_position.x, module_position.y, support_z - camera_layer.call(0.030)), module_size * 0.72, camera_layer.call(0.007), lens_material)
		var optical_core := StandardMaterial3D.new()
		optical_core.albedo_color = Color("#010308")
		optical_core.metallic = 0.18
		optical_core.roughness = 0.045
		optical_core.clearcoat_enabled = true
		optical_core.clearcoat = 1.0
		optical_core.clearcoat_roughness = 0.035
		_add_rear_hardware_disc(root, "RearCamera_%d_OpticalCore" % module_id, Vector3(module_position.x, module_position.y, support_z - camera_layer.call(0.034)), module_size * 0.38, camera_layer.call(0.0025), optical_core)
		var lens_glint := StandardMaterial3D.new()
		lens_glint.albedo_color = Color(0.30, 0.43, 0.58, 0.24)
		lens_glint.metallic = 0.22
		lens_glint.roughness = 0.055
		lens_glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_add_rear_hardware_disc(root, "RearCamera_%d_GlassGlint" % module_id, Vector3(module_position.x - module_size * 0.13, module_position.y + module_size * 0.13, support_z - camera_layer.call(0.036)), module_size * 0.12, camera_layer.call(0.001), lens_glint)

	for flash_index in range(rear_flash_modules.size()):
		var flash_module: Dictionary = rear_flash_modules[flash_index]
		var flash_position: Vector2 = flash_module["position"]
		var flash_size := float(flash_module["size"])
		var flash_support_z := _rear_hardware_support_surface_z(flash_position, flash_size)
		var flash_is_selected := rear_hardware_mode == "FLASH" and flash_index == rear_flash_selected_index
		var flash_housing_material := StandardMaterial3D.new()
		flash_housing_material.albedo_color = Color("#303943")
		flash_housing_material.metallic = 0.78
		flash_housing_material.roughness = 0.24
		var flash_rim_material := StandardMaterial3D.new()
		flash_rim_material.albedo_color = Color("#65caff") if flash_is_selected else Color("#aab4bd")
		flash_rim_material.metallic = 0.76
		flash_rim_material.roughness = 0.24
		var flash_diffuser_material := StandardMaterial3D.new()
		flash_diffuser_material.albedo_color = Color("#fff1cf")
		flash_diffuser_material.roughness = 0.24
		flash_diffuser_material.emission_enabled = true
		flash_diffuser_material.emission = Color("#ffe5ad")
		flash_diffuser_material.emission_energy_multiplier = 0.18
		var flash_module_id := int(flash_module["id"])
		# Match the camera's reduced, size-responsive shallow profile.
		var flash_depth_scale := (flash_size / 0.08) / 1.5
		var flash_layer := func(depth: float) -> float: return depth * flash_depth_scale
		_add_rear_hardware_disc(root, "RearFlash_%d_Housing" % flash_module_id, Vector3(flash_position.x, flash_position.y, flash_support_z - flash_layer.call(0.009)), flash_size * 1.22, flash_layer.call(0.018), flash_housing_material)
		_add_rear_hardware_disc(root, "RearFlash_%d_Rim" % flash_module_id, Vector3(flash_position.x, flash_position.y, flash_support_z - flash_layer.call(0.019)), flash_size * 1.04, flash_layer.call(0.006), flash_rim_material)
		_add_rear_hardware_disc(root, "RearFlash_%d_Gasket" % flash_module_id, Vector3(flash_position.x, flash_position.y, flash_support_z - flash_layer.call(0.022)), flash_size * 0.86, flash_layer.call(0.0025), flash_housing_material)
		_add_rear_hardware_disc(root, "RearFlash_%d_Diffuser" % flash_module_id, Vector3(flash_position.x, flash_position.y, flash_support_z - flash_layer.call(0.027)), flash_size * 0.70, flash_layer.call(0.006), flash_diffuser_material)
		var led_center_material := StandardMaterial3D.new()
		led_center_material.albedo_color = Color("#fff9e9")
		led_center_material.roughness = 0.18
		led_center_material.emission_enabled = true
		led_center_material.emission = Color("#fff0c8")
		led_center_material.emission_energy_multiplier = 0.32
		_add_rear_hardware_disc(root, "RearFlash_%d_LEDCore" % flash_module_id, Vector3(flash_position.x, flash_position.y, flash_support_z - flash_layer.call(0.031)), flash_size * 0.38, flash_layer.call(0.002), led_center_material)


func _add_rear_hardware_disc(parent: Node3D, node_name: String, disc_position: Vector3, radius: float, height: float, material: Material) -> void:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	disc.mesh = mesh
	disc.rotation_degrees.x = -90.0
	disc.position = disc_position
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)


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
	# Home controls belong to the handset, not the display. Their X/Y position
	# is fixed to the device, so changing screen height never moves them.
	if not home_button_enabled or home_button_type == "On-screen":
		return

	var button_root := Node3D.new()
	button_root.name = "PhoneHomeButton"
	phone_body.add_child(button_root)
	# Keep the home marking close to the handset's bottom edge.
	var center_y := -PHONE_SIZE.y * 0.5 + 0.11
	var current_depth := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
	var body_front_z := current_depth * 0.5
	var button_surface_z := body_front_z + 0.0008

	# When the screen reaches this fixed device position, rest the marking on
	# the actual glass surface. Otherwise it sits directly on the exposed body.
	if is_instance_valid(phone_screen):
		var screen_width := PHONE_SIZE.x if screen_shape_mode == "Curve screen" and side_curve_enabled else maxf(0.30, PHONE_SIZE.x - bezel_width * 2.0)
		var screen_height := PHONE_SIZE.y if screen_shape_mode == "Curve screen" and vertical_curve_enabled else maxf(0.60, PHONE_SIZE.y - bezel_height * 2.0)
		var is_over_screen := absf(center_y) <= screen_height * 0.5
		if is_over_screen:
			var curved_display := screen_shape_mode == "Curve screen" and (side_curve_enabled or vertical_curve_enabled)
			var glass_surface_z := _front_camera_screen_surface_z(0.0, center_y, screen_width, screen_height)
			button_surface_z = phone_screen.position.z + glass_surface_z + (0.0036 if not curved_display else 0.0008)

	# Dark, unshaded markings remain legible on the light silver device body
	# and on the darker display without becoming raised physical keys.
	var icon_material := StandardMaterial3D.new()
	icon_material.albedo_color = Color("#263746")
	icon_material.roughness = 0.48
	icon_material.metallic = 0.12
	icon_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	var bezel_material := StandardMaterial3D.new()
	bezel_material.albedo_color = Color("#aebdca")
	bezel_material.metallic = 0.78
	bezel_material.roughness = 0.24
	var inset_material := StandardMaterial3D.new()
	inset_material.albedo_color = Color("#101c28")
	inset_material.metallic = 0.32
	inset_material.roughness = 0.28
	var highlight_material := StandardMaterial3D.new()
	highlight_material.albedo_color = Color("#e2f1fb")
	highlight_material.metallic = 0.82
	highlight_material.roughness = 0.18

	if home_button_type == "Recent · Home · Back (Physical)":
		for line_index in range(3):
			var recent_line := MeshInstance3D.new()
			recent_line.name = "RecentNavigationLine"
			var line_mesh := BoxMesh.new()
			line_mesh.size = Vector3(0.075, 0.009, 0.0008)
			recent_line.mesh = line_mesh
			recent_line.position = Vector3(-0.34, center_y + (float(line_index) - 1.0) * 0.025, button_surface_z)
			recent_line.material_override = icon_material
			recent_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			button_root.add_child(recent_line)

		var home_key_bezel := MeshInstance3D.new()
		home_key_bezel.name = "PhysicalNavigationHomeKeyBezel"
		var home_bezel_mesh := CylinderMesh.new()
		home_bezel_mesh.top_radius = 0.051
		home_bezel_mesh.bottom_radius = 0.051
		home_bezel_mesh.height = 0.010
		home_bezel_mesh.radial_segments = 48
		home_key_bezel.mesh = home_bezel_mesh
		home_key_bezel.rotation_degrees.x = 90.0
		home_key_bezel.position = Vector3(0.0, center_y, button_surface_z + 0.004)
		home_key_bezel.material_override = bezel_material
		home_key_bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		button_root.add_child(home_key_bezel)

		var home_key_inset := MeshInstance3D.new()
		home_key_inset.name = "PhysicalNavigationHomeKeyInset"
		var home_inset_mesh := CylinderMesh.new()
		home_inset_mesh.top_radius = 0.046
		home_inset_mesh.bottom_radius = 0.046
		home_inset_mesh.height = 0.006
		home_inset_mesh.radial_segments = 48
		home_key_inset.mesh = home_inset_mesh
		home_key_inset.rotation_degrees.x = 90.0
		home_key_inset.position = Vector3(0.0, center_y, button_surface_z + 0.009)
		home_key_inset.material_override = inset_material
		home_key_inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		button_root.add_child(home_key_inset)

		var home_key := MeshInstance3D.new()
		home_key.name = "PhysicalNavigationHomeKey"
		var home_mesh := CylinderMesh.new()
		home_mesh.top_radius = 0.044
		home_mesh.bottom_radius = 0.044
		home_mesh.height = 0.003
		home_mesh.radial_segments = 48
		home_key.mesh = home_mesh
		home_key.rotation_degrees.x = 90.0
		home_key.position = Vector3(0.0, center_y, button_surface_z + 0.013)
		home_key.material_override = icon_material
		home_key.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		button_root.add_child(home_key)

		for segment in range(2):
			var back_stroke := MeshInstance3D.new()
			back_stroke.name = "BackNavigationChevron"
			var stroke_mesh := BoxMesh.new()
			stroke_mesh.size = Vector3(0.055, 0.009, 0.0008)
			back_stroke.mesh = stroke_mesh
			back_stroke.position = Vector3(0.34 + (0.008 if segment == 0 else -0.008), center_y + (0.018 if segment == 0 else -0.018), button_surface_z)
			back_stroke.rotation_degrees.z = -35.0 if segment == 0 else 35.0
			back_stroke.material_override = icon_material
			back_stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			button_root.add_child(back_stroke)
		return

	var is_circle := home_button_type == "Circle Home Button"
	var is_oval := home_button_type == "Oval Home Button"
	var mark_width := 0.21 if is_oval else (0.146 if is_circle else 0.11)
	var mark_height := 0.065 if is_oval else (0.146 if is_circle else 0.11)
	var mark_radius := mark_height * 0.48 if is_oval or is_circle else 0.008
	# A thin metallic bezel, recessed dark insert and glass-like key face give
	# the original button silhouette a tactile, manufactured finish.
	var bezel := MeshInstance3D.new()
	bezel.name = "HomeButtonMetalBezel"
	if is_circle:
		var bezel_mesh := CylinderMesh.new()
		bezel_mesh.top_radius = 0.082
		bezel_mesh.bottom_radius = 0.082
		bezel_mesh.height = 0.010
		bezel_mesh.radial_segments = 64
		bezel.mesh = bezel_mesh
		bezel.rotation_degrees.x = 90.0
	else:
		bezel.mesh = _create_rounded_panel_mesh(mark_width + 0.014, mark_height + 0.014, 0.010, mark_radius + 0.007)
	bezel.position = Vector3(0.0, center_y, button_surface_z + 0.004)
	bezel.material_override = bezel_material
	bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	button_root.add_child(bezel)

	var inset := MeshInstance3D.new()
	inset.name = "HomeButtonRecess"
	if is_circle:
		var inset_mesh := CylinderMesh.new()
		inset_mesh.top_radius = 0.075
		inset_mesh.bottom_radius = 0.075
		inset_mesh.height = 0.006
		inset_mesh.radial_segments = 64
		inset.mesh = inset_mesh
		inset.rotation_degrees.x = 90.0
	else:
		inset.mesh = _create_rounded_panel_mesh(mark_width + 0.002, mark_height + 0.002, 0.006, mark_radius + 0.001)
	inset.position = Vector3(0.0, center_y, button_surface_z + 0.009)
	inset.material_override = inset_material
	inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	button_root.add_child(inset)

	var home_mark := MeshInstance3D.new()
	home_mark.name = "FlatHomeButtonMark"
	if is_circle:
		var circle_mesh := CylinderMesh.new()
		circle_mesh.top_radius = 0.073
		circle_mesh.bottom_radius = 0.073
		circle_mesh.height = 0.003
		circle_mesh.radial_segments = 64
		home_mark.mesh = circle_mesh
		home_mark.rotation_degrees.x = 90.0
	else:
		home_mark.mesh = _create_rounded_panel_mesh(mark_width, mark_height, 0.003, mark_radius)
	home_mark.position = Vector3(0.0, center_y, button_surface_z + 0.013)
	home_mark.material_override = icon_material
	home_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	button_root.add_child(home_mark)


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

func _show_side_button_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "SideButtonControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 12)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("SIDE BUTTONS", 21, Color("#c7eaff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)
	var description := _make_label("Add tactile controls and a SIM tray to the phone frame.", 12, Color("#d8eaf5"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	_add_optional_side_feature_row("SIDE BUTTON", "camera", camera_side_button_enabled, true, camera_side_button_y)
	_add_optional_side_feature_row("SOUND BUTTON", "sound", sound_button_enabled, false, volume_button_y)
	_add_optional_side_feature_row("SIM TRAY", "sim", sim_tray_enabled, true, sim_tray_y)
	_add_optional_side_feature_row("STYLE PEN (S PEN)", "style_pen", style_pen_enabled, false, 0.0)


func _add_optional_side_feature_row(caption: String, feature: String, enabled: bool, with_position: bool, position_y: float) -> void:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.48, 0.66, 0.22)
	style.border_color = Color(0.55, 0.80, 0.94, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	section.add_theme_stylebox_override("panel", style)
	active_feature_panel.add_child(section)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	section.add_child(content)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(header)
	var label := _make_label(caption, 17, Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(label)
	# Reuse the exact custom TextureButton checkbox artwork and sizing used
	# by the Power and Volume controls for a consistent editor UI.
	var toggle := TextureButton.new()
	toggle.name = "Custom" + feature.capitalize() + "ButtonCheckbox"
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
	toggle.pressed.connect(_on_optional_side_feature_toggle_pressed.bind(toggle, feature))
	header.add_child(toggle)

	if with_position:
		var position_caption := _make_label("POSITION ON PHONE SIDE", 12, Color("#c7eaff"))
		content.add_child(position_caption)
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		controls.add_theme_constant_override("separation", 10)
		content.add_child(controls)
		var down := Button.new()
		down.text = "−"
		down.custom_minimum_size = Vector2(58, 44)
		_apply_research_typography(down, 24)
		_style_staff_button(down, false)
		down.pressed.connect(_on_optional_side_feature_position_step.bind(feature, -1))
		controls.add_child(down)
		var value_label := _make_label("%d%%" % roundi(position_y / 1.20 * 100.0), 15, Color("#a9e3ff"))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(value_label)
		var up := Button.new()
		up.text = "+"
		up.custom_minimum_size = Vector2(58, 44)
		_apply_research_typography(up, 24)
		_style_staff_button(up, false)
		up.pressed.connect(_on_optional_side_feature_position_step.bind(feature, 1))
		controls.add_child(up)
		if feature == "camera":
			camera_side_button_position_label = value_label
		else:
			sim_tray_position_label = value_label


func _on_optional_side_feature_toggle_pressed(toggle: TextureButton, feature: String) -> void:
	_on_optional_side_feature_toggled(toggle.button_pressed, feature)


func _on_optional_side_feature_toggled(enabled: bool, feature: String) -> void:
	match feature:
		"camera":
			camera_side_button_enabled = enabled
		"sound":
			sound_button_enabled = enabled
		"sim":
			sim_tray_enabled = enabled
		"style_pen":
			style_pen_enabled = enabled
	_refresh_phone_side_buttons()
	if feature == "style_pen":
		_refresh_phone_speakers()


func _on_optional_side_feature_position_step(feature: String, direction: int) -> void:
	if feature == "camera":
		camera_side_button_y = clampf(camera_side_button_y + float(direction) * 0.06, -1.20, 1.20)
		if is_instance_valid(camera_side_button_position_label):
			camera_side_button_position_label.text = "%d%%" % roundi(camera_side_button_y / 1.20 * 100.0)
	else:
		sim_tray_y = clampf(sim_tray_y + float(direction) * 0.06, -1.20, 1.20)
		if is_instance_valid(sim_tray_position_label):
			sim_tray_position_label.text = "%d%%" % roundi(sim_tray_y / 1.20 * 100.0)
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

	# Match the keys to the selected body finish, with a darker seam for definition.
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = device_body_color.darkened(0.22)
	frame_material.metallic = 0.42
	frame_material.roughness = 0.34
	var key_material := StandardMaterial3D.new()
	key_material.albedo_color = device_body_color.lightened(0.07)
	key_material.metallic = 0.32
	key_material.roughness = 0.30

	var current_depth := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
	var key_radius := clampf(current_depth * 0.27, 0.018, 0.036)
	var key_length := 0.30 * side_button_length_scale
	var single_key_length := key_length * 0.46
	if power_button_enabled:
		_add_phone_side_button(button_root, "PowerButton", 1.0, power_button_y, single_key_length, key_radius, frame_material, key_material)
	if volume_button_enabled:
		var rocker_gap := 0.018
		_add_phone_side_button(button_root, "VolumeUpButton", -1.0, volume_button_y + single_key_length * 0.52 + rocker_gap, single_key_length, key_radius, frame_material, key_material)
		_add_phone_side_button(button_root, "VolumeDownButton", -1.0, volume_button_y - single_key_length * 0.52 - rocker_gap, single_key_length, key_radius, frame_material, key_material)
	if camera_side_button_enabled:
		_add_phone_side_button(button_root, "QuickCameraSideButton", 1.0, camera_side_button_y, 0.19, key_radius * 0.88, frame_material, key_material)
	if sound_button_enabled:
		# Reduce the complete rounded key length (including its capsule ends)
		# by 1.2x, rather than only shortening the straight center section.
		var sound_button_radius := key_radius * 0.78
		var sound_button_width := maxf(sound_button_radius * 1.35, 0.024)
		var sound_button_length := maxf(0.0, (0.105 + sound_button_width) / 1.2 - sound_button_width)
		_add_phone_side_button(button_root, "SoundActionButton", -1.0, volume_button_y + single_key_length + 0.15, sound_button_length, sound_button_radius, frame_material, key_material)
	if sim_tray_enabled:
		_add_phone_sim_tray(button_root, -1.0, sim_tray_y, frame_material, key_material)
	if style_pen_enabled:
		_add_phone_style_pen(button_root, current_depth, key_material)


func _add_phone_style_pen(parent: Node3D, _current_depth: float, _key_material: Material) -> void:
	# Keep every speaker at its authored position. Move only the S-Pen marker
	# along the bottom-left perimeter until it clears the left speaker row.
	# At larger corner radii it follows the rounded corner, with its circular
	# face kept tangent to the frame instead of hanging outside the chassis.
	var corner_radius := 0.32 * float(border_radius_level) / 6.0
	var bottom_y := -PHONE_SIZE.y * 0.5
	var left_edge := -PHONE_SIZE.x * 0.5
	var circle_radius := 0.025
	var edge_inset := 0.004
	var speaker_radius := 0.012
	var speaker_clearance := 0.008
	var marker_position := Vector2(left_edge + corner_radius + circle_radius + 0.012, bottom_y + edge_inset)
	var marker_rotation := 0.0
	var found_position := false

	# Recalculate the existing left-speaker coordinates only for collision
	# testing; this does not change, move, or resize any speaker opening.
	var left_count := int(ceil(float(speaker_count) * 0.5))
	var reserved_port_half_width := 0.115
	var edge_margin := 0.035
	var hole_spacing := 0.045
	var left_speaker_positions: Array[float] = []
	for index in range(left_count):
		left_speaker_positions.append(-(reserved_port_half_width + edge_margin + float(left_count - 1 - index) * hole_spacing))

	var required_clearance := circle_radius + speaker_radius + speaker_clearance
	if corner_radius > 0.08:
		# Walk from the bottom tangent around the lower-left corner toward the
		# left rail. Each candidate remains inset from the rounded body outline.
		var arc_center := Vector2(left_edge + corner_radius, bottom_y + corner_radius)
		var arc_path_radius := corner_radius - edge_inset
		for step in range(1, 91):
			var angle := -PI * 0.5 - deg_to_rad(float(step) * 1.0)
			var candidate := arc_center + Vector2(cos(angle), sin(angle)) * arc_path_radius
			var clear := true
			for speaker_x in left_speaker_positions:
				var speaker_center := Vector2(speaker_x, bottom_y + 0.0045)
				if candidate.distance_to(speaker_center) < required_clearance:
					clear = false
					break
			if clear:
				marker_position = candidate
				marker_rotation = rad_to_deg(angle - PI * 0.5)
				found_position = true
				break

	# On square/small-radius phones, or if the arc is not needed, use the
	# straight bottom rail. If a future speaker layout blocks it, keep trying
	# progressively farther along the rail without changing speaker positions.
	if not found_position:
		var straight_start_x := left_edge + corner_radius + circle_radius + 0.012
		var straight_end_x := 0.0
		var candidate_steps := 80
		for step in range(candidate_steps + 1):
			var candidate_x := lerpf(straight_start_x, straight_end_x, float(step) / float(candidate_steps))
			var candidate := Vector2(candidate_x, bottom_y + edge_inset)
			var clear := true
			for speaker_x in left_speaker_positions:
				var speaker_center := Vector2(speaker_x, bottom_y + 0.0045)
				if candidate.distance_to(speaker_center) < required_clearance:
					clear = false
					break
			if clear:
				marker_position = candidate
				marker_rotation = 0.0
				found_position = true
				break

	# Never draw the marker in an invalid location. Hiding it is safer than
	# letting it overlap a speaker or protrude beyond the phone body.
	if not found_position and speaker_count > 0:
		return

	var circle_material := StandardMaterial3D.new()
	# The S-Pen end is a fixed black hardware detail, not a surface that
	# participates in the phone's front-light ray, scene lighting, or fog.
	circle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	circle_material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	circle_material.metallic = 0.0
	circle_material.roughness = 1.0
	circle_material.disable_receive_shadows = true
	circle_material.disable_fog = true
	# The marker can be seen from either side while the phone is rotated.
	circle_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var end_marker := MeshInstance3D.new()
	end_marker.name = "StylePenBlackCircleEnd"
	var circle_mesh := CylinderMesh.new()
	circle_mesh.top_radius = circle_radius
	circle_mesh.bottom_radius = circle_radius
	# The center is inset by 0.004 from the perimeter. Make the cylinder
	# slightly thicker than twice that inset so its outer cap projects about
	# 0.003 beyond the bottom edge instead of sitting coplanar with the body.
	# This removes depth-buffer fighting as the unbordered phone is tilted.
	circle_mesh.height = 0.014
	circle_mesh.radial_segments = 40
	end_marker.mesh = circle_mesh
	# Keep the S-Pen marker on the phone's bottom edge, centered through
	# the frame thickness. Its orientation follows the bottom/rounded edge.
	end_marker.position = Vector3(marker_position.x, marker_position.y, 0.0)
	end_marker.rotation_degrees.z = marker_rotation
	end_marker.material_override = circle_material
	end_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(end_marker)


func _add_phone_sim_tray(parent: Node3D, side_sign: float, position_y: float, frame_material: Material, key_material: Material) -> void:
	var edge := PHONE_SIZE.x * 0.5
	var slot := MeshInstance3D.new()
	slot.name = "SimTrayOuterSeam"
	var slot_mesh := BoxMesh.new()
	slot_mesh.size = Vector3(0.006, 0.205, 0.034)
	slot.mesh = slot_mesh
	slot.material_override = frame_material
	slot.position = Vector3(side_sign * (edge + 0.001), position_y, 0.0)
	slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(slot)

	var tray_face := MeshInstance3D.new()
	tray_face.name = "SimTrayFace"
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.004, 0.178, 0.021)
	tray_face.mesh = face_mesh
	tray_face.material_override = key_material
	tray_face.position = Vector3(side_sign * (edge + 0.004), position_y, 0.0)
	tray_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tray_face)

	var eject_hole := MeshInstance3D.new()
	eject_hole.name = "SimTrayEjectPinhole"
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 0.006
	hole_mesh.bottom_radius = 0.006
	hole_mesh.height = 0.003
	hole_mesh.radial_segments = 20
	eject_hole.mesh = hole_mesh
	eject_hole.rotation_degrees.z = 90.0
	eject_hole.position = Vector3(side_sign * (edge + 0.007), position_y - 0.065, 0.0)
	eject_hole.material_override = frame_material
	eject_hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(eject_hole)


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
	# A flattened capsule gives the button the softly rounded ends and edges
	# of a real handset key instead of the sharp corners of a plain box.
	var key_mesh := CapsuleMesh.new()
	key_mesh.radius = button_width * 0.5
	key_mesh.height = maxf(length + button_width, button_width * 2.0)
	key_mesh.radial_segments = 24
	key_mesh.rings = 6
	key.mesh = key_mesh
	key.scale = Vector3(button_depth / button_width, 1.0, 1.0)
	key.material_override = key_material
	# Center the shallow rounded key just beyond the side plane.
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

	# Keep the speaker layout fixed and independent of optional hardware.
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
	var current_phone_depth := lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
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
	_refresh_back_design_boxes()
	_refresh_phone_side_buttons()
	_refresh_phone_home_button()
	_refresh_phone_screen()
	_refresh_phone_speakers()
	_refresh_back_design_boxes()
	_refresh_rear_hardware_visuals()
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
	phone_size.z = lerpf(0.08, PHONE_SIZE.z, float(phone_thickness_level) / 10.0)
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
		# Dense quarter-circle tessellation keeps the chassis silhouette smooth at oblique rotation angles.
		var corner_segments := 48
		for corner_index in range(4):
			var center: Vector2 = corner_centers[corner_index]
			var start_angle := float(corner_index) * PI * 0.5
			# Include both tangent endpoints of every quarter-circle. These
			# exact points create the straight bottom rail segment that the
			# charging-port aperture cuts into at every border-radius level.
			for segment in range(corner_segments + 1):
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
			# Blend adjacent perimeter normals at rounded-corner vertices. This
			# keeps the side rail visually continuous instead of faceted per segment.
			var normal_a := side_normal
			var normal_b := side_normal
			if radius > 0.0001:
				var previous_a: Vector2 = outline[(index - 1 + outline.size()) % outline.size()]
				var previous_edge_a := a - previous_a
				var previous_normal_a := Vector3(previous_edge_a.y, -previous_edge_a.x, 0.0).normalized()
				var next_b: Vector2 = outline[(next_index + 1) % outline.size()]
				var next_edge_b := next_b - b
				var next_normal_b := Vector3(next_edge_b.y, -next_edge_b.x, 0.0).normalized()
				normal_a = (previous_normal_a + side_normal).normalized()
				normal_b = (side_normal + next_normal_b).normalized()
			_add_phone_mesh_triangle_with_normals(surface, front_a, back_a, back_b, normal_a, normal_a, normal_b)
			_add_phone_mesh_triangle_with_normals(surface, front_a, back_b, front_b, normal_a, normal_b, normal_b)

	return surface.commit()

func _add_phone_mesh_triangle_with_normals(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal_a: Vector3, normal_b: Vector3, normal_c: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal_a + normal_b + normal_c) > 0.0:
		var swap_vertex := b
		b = c
		c = swap_vertex
		var swap_normal := normal_b
		normal_b = normal_c
		normal_c = swap_normal
	surface.set_normal(normal_a.normalized())
	surface.add_vertex(a)
	surface.set_normal(normal_b.normalized())
	surface.add_vertex(b)
	surface.set_normal(normal_c.normalized())
	surface.add_vertex(c)

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



func _build_software_summary_panel() -> void:
	software_summary_panel = _make_glass_panel(Color(0.10, 0.31, 0.48, 0.58))
	software_summary_panel.name = "PhoneSoftwareSpecificationPanel"
	software_summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	software_summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	software_summary_panel.visible = false
	preview_stack.add_child(software_summary_panel)

	var content := VBoxContainer.new()
	content.name = "SoftwareSpecificationContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	software_summary_panel.add_child(content)

	var heading := _make_label("SOFTWARE SPECIFICATIONS", 19, Color("#c7eaff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var subtitle := _make_label("DEVICE CONFIGURATION", 11, Color("#a9c9dc"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	content.add_child(HSeparator.new())

	software_value_labels.clear()
	var specifications := [
		["RAM", selected_ram_capacity],
		["ROM", selected_rom_capacity],
		["BATTERY", "Not set"],
		["CHIPSET", "Not set"],
		["OPERATING SYSTEM", "Not set"],
		["RAM TECHNOLOGY", "Not set"],
		["STORAGE TYPE", "Not set"],
		["CONNECTIVITY", "Not set"]
	]
	for specification in specifications:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)
		var name_label := _make_label(str(specification[0]) + ":", 13, Color("#d8f1ff"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value_label := _make_label(str(specification[1]), 13, Color.WHITE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		software_value_labels[str(specification[0])] = value_label
	var hint := _make_label("Choose a software feature from the left panel to configure this device.", 11, Color("#a9c9dc"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


func _show_ram_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "RAMSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT RAM", 18, Color("#c7eaff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Physical memory capacity", 11, Color("#a9c9dc"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)
	var current := _make_label("CURRENT: " + selected_ram_capacity.to_upper(), 13, Color.WHITE)
	current.name = "CurrentRAMSelectionLabel"
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(current)

	var scroll := ScrollContainer.new()
	scroll.name = "RAMOptionsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	active_feature_panel.add_child(scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	scroll.add_child(options)
	for capacity in ["2 GB", "3 GB", "4 GB", "6 GB", "8 GB", "12 GB", "16 GB", "18 GB", "24 GB", "32 GB"]:
		var option := Button.new()
		option.name = "RAMOption_" + capacity.replace(" ", "")
		option.text = capacity + ("   ✓ SELECTED" if selected_ram_capacity == capacity else "")
		option.custom_minimum_size.y = 43
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 14)
		_style_staff_button(option, selected_ram_capacity == capacity)
		option.pressed.connect(_on_ram_capacity_selected.bind(capacity))
		options.add_child(option)


func _on_ram_capacity_selected(capacity: String) -> void:
	if not ["2 GB", "3 GB", "4 GB", "6 GB", "8 GB", "12 GB", "16 GB", "18 GB", "24 GB", "32 GB"].has(capacity):
		return
	selected_ram_capacity = capacity
	if software_value_labels.has("RAM") and is_instance_valid(software_value_labels["RAM"]):
		var ram_label: Label = software_value_labels["RAM"]
		ram_label.text = capacity
	_show_ram_controls()


func _show_rom_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ROMSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT ROM", 18, Color("#c7eaff"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Internal storage capacity", 11, Color("#a9c9dc"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)
	var current := _make_label("CURRENT: " + selected_rom_capacity.to_upper(), 13, Color.WHITE)
	current.name = "CurrentROMSelectionLabel"
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(current)

	var scroll := ScrollContainer.new()
	scroll.name = "ROMOptionsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	active_feature_panel.add_child(scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	scroll.add_child(options)
	for capacity in ["16 GB", "32 GB", "64 GB", "128 GB", "256 GB", "512 GB", "1 TB", "2 TB"]:
		var option := Button.new()
		option.name = "ROMOption_" + capacity.replace(" ", "")
		option.text = capacity + ("   ✓ SELECTED" if selected_rom_capacity == capacity else "")
		option.custom_minimum_size.y = 43
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 14)
		_style_staff_button(option, selected_rom_capacity == capacity)
		option.pressed.connect(_on_rom_capacity_selected.bind(capacity))
		options.add_child(option)


func _on_rom_capacity_selected(capacity: String) -> void:
	if not ["16 GB", "32 GB", "64 GB", "128 GB", "256 GB", "512 GB", "1 TB", "2 TB"].has(capacity):
		return
	selected_rom_capacity = capacity
	if software_value_labels.has("ROM") and is_instance_valid(software_value_labels["ROM"]):
		var rom_label: Label = software_value_labels["ROM"]
		rom_label.text = capacity
	_show_rom_controls()


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
	if is_instance_valid(preview_container):
		preview_container.visible = left_tools_page != 1
	if is_instance_valid(software_summary_panel):
		software_summary_panel.visible = left_tools_page == 1
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
