extends Node3D

signal back_requested
signal research_upgrade_requested(research_id: String)
signal worksite_nested_color_view_opened

const PHONE_SIZE := Vector3(1.45, 2.92, 0.22)
const ROTATION_STEP := deg_to_rad(10.0)
# Deliberately low so a normal finger movement makes a controlled turn.
const DRAG_SENSITIVITY := 0.0024


func _active_phone_size() -> Vector3:
	var size := PHONE_SIZE
	if selected_phone_type == "Fold":
		size.x *= 1.5
	return size

class ScreenTechGlassReflection extends Control:
	var accent := Color("#9bd6a7")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 4.0 or size.y <= 4.0:
			return
		for i in range(32):
			var x0 := size.x * float(i) / 32.0
			var x1 := size.x * float(i + 1) / 32.0
			var mid := (float(i) + 0.5) / 32.0
			var highlight := exp(-pow((mid - 0.34) / 0.29, 2.0))
			draw_line(Vector2(x0, 1.2), Vector2(x1, 1.2), Color(0.97, 1.0, 0.98, 0.09 + 0.30 * highlight), 1.2, true)
		draw_line(Vector2(1.2, 9.0), Vector2(1.2, maxf(9.0, size.y - 9.0)), Color(accent.r, accent.g, accent.b, 0.24), 1.0, true)
		draw_line(Vector2(size.x - 1.2, 9.0), Vector2(size.x - 1.2, maxf(9.0, size.y - 9.0)), Color(accent.r, accent.g, accent.b, 0.24), 1.0, true)
		draw_line(Vector2(12.0, size.y - 2.0), Vector2(size.x - 12.0, size.y - 2.0), Color(0.72, 0.88, 0.76, 0.10), 1.0, true)


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
		draw_rect(rect, Color("#7fae88"), false, 1.0)
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
var worksite_creation_mode := false
var selected_phone_type := "Standard"
var fold_angle_degrees := 0.0
var fold_target_angle_degrees := 0.0
var preview_touch_points: Dictionary = {}
var fold_pinch_active := false
var fold_pinch_start_distance := 0.0
var fold_pinch_start_angle := 0.0
const MAX_FOLD_ANGLE_DEGREES := 180.0
const FOLD_PINCH_ANGLE_SENSITIVITY := 115.0
const FOLD_ANGLE_SMOOTHING := 20.0
var home_button_type := "Circle Home Button"
var home_button_enabled := false
var front_camera_enabled := false
var front_camera_megapixels := 12
var front_camera_secondary_megapixels := 12
const CAMERA_MEGAPIXEL_STEPS := [2, 5, 8, 10, 12, 13, 16, 20, 24, 32, 40, 48, 50, 64, 108, 200]
const MEMORY_CLOCK_STEPS := [400, 533, 667, 800, 933, 1067, 1200, 1375, 1600, 1867, 2133, 2750, 3200, 3733, 4267]
const MAX_REAR_CAMERAS := 5
const MAX_REAR_FLASHES := 5
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
var rear_hardware_selection_button: Button
var rear_hardware_selection_popup: PanelContainer
var rear_hardware_popup_layer: CanvasLayer
var rear_hardware_selection_scroll: ScrollContainer
var rear_hardware_selection_items: VBoxContainer
var rear_hardware_size_label: Label
var rear_hardware_size_slider: HSlider
var rear_hardware_add_button: Button
var rear_hardware_remove_button: Button
var rear_hardware_previous_button: Button
var rear_hardware_next_button: Button
const HOME_BUTTON_TYPES := ["Circle Home Button", "Oval Home Button", "Square Home Button", "Recent · Home · Back (Physical)", "On-screen"]
var home_button_option_buttons: Dictionary = {}
var screen_enabled := false
var screen_protector_enabled := false
var screen_protector_finish := "Ultra Clear"
var screen_protector_thickness := 0.006
var screen_protector_thickness_label: Label
var screen_protector_building := false
var screen_protector_build_token := 0
var active_screen_protector_build_tweens: Array[Tween] = []
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
var phone_case_preview: Node3D
var phone_case_shell: CSGPolygon3D
var charger_preview: Node3D
var smartwatch_preview: Node3D
var power_bank_preview: Node3D
var wireless_earbuds_preview: Node3D
var wireless_earbuds_enabled := false
var wireless_earbuds_preview_mode := false
var wireless_earbuds_body_color := Color("#e8edf2")
var wireless_earbuds_color_mode := false
var power_bank_preview_mode := false
var power_bank_enabled := false
var power_bank_capacity_mah := 10000
var power_bank_capacity_value_label: Label
var power_bank_body_color := Color("#303943")
var power_bank_color_name := "Graphite"
var smartwatch_enabled := false
var smartwatch_body_color := Color("#303943")
var smartwatch_color_name := "Graphite"
var charger_enabled := false
var charger_wattage := 30
var charger_plug_type := "UK"
var charger_cable_type := "USB-C to USB-C"
var charger_cable_enabled := false
var charger_body_color := Color("#e8edf2")
var charger_wattage_label: Label
var charger_wattage_slider: VSlider
var charger_preview_mode := false
var charger_controls_page := "HOME"
var charger_color_mode := false
var power_bank_color_mode := false
var smartwatch_color_mode := false
var phone_case_custom_enabled := false
var phone_case_building := false
var phone_case_built := false
var phone_case_sync_queued := false
var phone_case_build_token := 0
var phone_case_color_mode := false
var phone_case_color := Color("#293744")
var phone_case_gradient_color := Color("#3d77a8")
var phone_case_gradient_enabled := false
var phone_case_gradient_direction := 0
var phone_case_gradient_color_edit_mode := false
const PHONE_CASE_DESIGN_NAMES := ["Smooth", "Carbon Weave", "Hex Pattern", "Racing Stripes", "Grip Ridges"]
var phone_case_design_style := 0
var preview_stack: VBoxContainer
var software_summary_panel: PanelContainer
var software_value_labels: Dictionary = {}
var selected_ram_capacity := "Not set"
var selected_refresh_rate := "Not set"
var selected_memory_clock := "Not set"
var memory_clock_slider: VSlider
var memory_clock_value_label: Label
var selected_cooling_system := "Not set"
var selected_ram_technology := "Not set"
var selected_rom_capacity := "Not set"
var selected_battery_capacity := "Not set"
var selected_charging_speed := 2
var selected_wireless_charge_enabled := false
var selected_wireless_charging_speed := 5
var wireless_charge_enable_checkbox: Button
var wireless_charging_speed_slider: VSlider
var wireless_charging_speed_value_label: Label
var selected_bluetooth_version := "Not set"
var selected_wifi_standard := "Not set"
var selected_mobile_network := "Not set"
var selected_phone_sensors: Dictionary = {
	"Fingerprint Sensor": true,
	"Face Recognition / Face ID": false,
	"NFC Controller": false,
	"Accelerometer": true,
	"Gyroscope": true,
	"Proximity Sensor": true,
	"Ambient Light Sensor": true,
	"Magnetometer / Compass": true,
	"Barometer": false,
	"GNSS / GPS Receiver": true
}
var charging_speed_value_label: Label
var charging_speed_slider: VSlider
var charging_speed_decrease_button: Button
var charging_speed_increase_button: Button
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
var smartwatch_preview_mode := false
var border_radius_level := 0
var border_radius_value_label: Label
var phone_thickness_level := 12
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
var back_box_gradient_popup: PanelContainer
var gradient_direction_items: VBoxContainer
var gradient_popup_layer: CanvasLayer
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
var back_design_gradient_enabled_without_box := false
var box_package_preview: Node3D
var box_package_lid: Node3D
var box_package_preview_mode := false
var box_package_enabled := true
var box_package_open := false
var box_package_position_target := "LOGO"
var box_package_position_step := 0.08
var box_package_color_mode := false
var box_package_color := Color("#e8edf2")
var box_package_logo_visible := true
var box_package_name_visible := true
var box_company_name := "YOUR COMPANY"
var box_company_logo_id := 1
var box_package_logo_position := Vector2(0.0, 0.66)
var box_package_name_position := Vector2(0.0, -0.62)
var box_package_logo_sprite: Sprite3D
var box_package_name_label: Label3D


func set_company_branding(company_name: String, logo_id: int) -> void:
	box_company_name = company_name.strip_edges()
	if box_company_name.is_empty():
		box_company_name = "YOUR COMPANY"
	box_company_logo_id = clampi(logo_id, 1, 50)
	if is_instance_valid(box_package_preview):
		_refresh_box_package_branding()


func _exit_tree() -> void:
	# A cancelled screen-protector build must not leave a looping tween alive
	# after the editor or its preview nodes are removed.
	for tween in active_screen_protector_build_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	active_screen_protector_build_tweens.clear()


func _ready() -> void:
	if research_mode:
		_build_research_ui()
	else:
		_build_editor_ui()


func _process(delta: float) -> void:
	if box_package_preview_mode or selected_phone_type == "Standard":
		return
	var fold_angle_delta := fold_target_angle_degrees - fold_angle_degrees
	if absf(fold_angle_delta) <= 0.02:
		if not is_equal_approx(fold_angle_degrees, fold_target_angle_degrees):
			fold_angle_degrees = fold_target_angle_degrees
			_apply_phone_fold_angle()
		return
	# Exponential damping gives the fold a smooth, frame-rate-independent
	# response while still allowing the two-finger gesture to control the angle.
	var blend := 1.0 - exp(-FOLD_ANGLE_SMOOTHING * delta)
	fold_angle_degrees = lerpf(fold_angle_degrees, fold_target_angle_degrees, blend)
	if absf(fold_target_angle_degrees - fold_angle_degrees) < 0.12:
		fold_angle_degrees = fold_target_angle_degrees
	_apply_phone_fold_angle()


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
	var background := ColorRect.new()
	background.name = "DigitalWorld_Obsidian_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#07090e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shared_Background_Overlay"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.010, 0.015, 0.58)
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
	var initial_hint := _make_label("SELECT A FEATURE", 18, Color("#c7eacb"))
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

	var background := ColorRect.new()
	background.name = "DigitalWorld_Obsidian_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#07090e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shared_Background_Overlay"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.010, 0.015, 0.58)
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
	research_balance_label = _make_label("AVAILABLE BALANCE  " + _format_research_money(research_balance), 11 if compact else 12, Color("#c7eacb"))
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
		"Phone Type", "Screen Tech", "Power/Volume Buttons", "Thickness",
		"Device Color", "Screen Size", "Screen Type", "Border Radius",
		"Speakers", "Charge Port", "Front Camera", "Rare Camera",
		"Side Button", "Home Button", "Back Design"
	]


func _get_software_research_features() -> Array:
	return [
		"RAM", "Internal Storage", "RAM Technology", "Battery",
		"Charging Speed", "Wireless Charge", "Bluetooth", "WiFi",
		"Network", "Sensors", "Front Camera MP", "Rear Camera MP",
		"Memory Clock", "Refresh Rate", "Cooling System Design"
	]


func _get_extras_research_features() -> Array:
	return [
		"Box Package", "Phone Case", "Charger",
		"Protection Glass", "Wireless Earbuds", "Smartwatch", "Power Bank",
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
	phone_body.mesh = _create_phone_chassis_mesh(0.0, PackedVector2Array())
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
	_build_phone_case_preview(phone_body)
	charger_preview = Node3D.new()
	charger_preview.name = "ChargerAccessoryPreview"
	charger_preview.visible = false
	preview_world.add_child(charger_preview)
	smartwatch_preview = Node3D.new()
	smartwatch_preview.name = "SmartwatchAccessoryPreview"
	smartwatch_preview.visible = false
	preview_world.add_child(smartwatch_preview)
	power_bank_preview = Node3D.new()
	power_bank_preview.name = "PowerBankAccessoryPreview"
	power_bank_preview.visible = false
	preview_world.add_child(power_bank_preview)
	wireless_earbuds_preview = Node3D.new()
	wireless_earbuds_preview.name = "WirelessEarbudsAccessoryPreview"
	wireless_earbuds_preview.visible = false
	preview_world.add_child(wireless_earbuds_preview)
	_build_box_package_preview(preview_world)
	_rebuild_charger_preview()
	_rebuild_smartwatch_preview()
	_rebuild_power_bank_preview()
	_rebuild_earbuds_preview()
	_rebuild_box_package_preview()

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
	rim_light.light_color = Color("#a3d9ae")
	rim_light.light_energy = 0.28
	rim_light.shadow_enabled = false
	preview_world.add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#a3d9ae")
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
	if feature_name in ["Screen Tech", "Screen Size", "Screen Type", "Border Radius", "Thickness", "Device Color", "Speakers", "Charge Port", "Power/Volume Buttons", "Side Button", "Home Button", "Front Camera", "Rare Camera", "Rear Camera", "Front Camera MP", "Rear Camera MP", "Back Design", "RAM", "ROM", "Internal Storage", "RAM Technology", "Battery", "Charging Speed", "Wireless Charge", "Bluetooth", "WiFi", "Network", "Sensors", "Refresh Rate", "Memory Clock", "Cooling System Design", "Phone Type", "Phone Case", "Protection Glass", "Charger", "Charging Cable", "Smartwatch", "Power Bank", "Wireless Earbuds", "Box Package"]:
		button.pressed.connect(_on_tool_feature_pressed.bind(feature_name))
	# Other feature buttons remain untouched until their systems are implemented.
	parent.add_child(button)


func _on_tool_feature_pressed(feature_name: String) -> void:
	_close_rear_hardware_selection_popup()
	_close_back_design_selection_popup()
	_set_charger_preview_mode(false)
	if feature_name == "Box Package":
		_set_box_package_preview_mode(true)
		_show_box_package_controls()
		return
	if box_package_preview_mode:
		_set_box_package_preview_mode(false)
	if feature_name == "Wireless Earbuds":
		_set_smartwatch_preview_mode(false)
		_set_power_bank_preview_mode(false)
		_set_earbuds_preview_mode(true)
		_show_earbuds_controls()
		return
	if feature_name == "Smartwatch":
		_set_power_bank_preview_mode(false)
		_set_smartwatch_preview_mode(true)
		_show_smartwatch_controls()
		return
	if feature_name == "Power Bank":
		_set_smartwatch_preview_mode(false)
		_set_power_bank_preview_mode(true)
		_show_power_bank_controls()
		return
	if feature_name == "Phone Case":
		_show_phone_case_controls()
		return
	if feature_name == "Protection Glass":
		_show_screen_protector_controls()
		return
	if feature_name == "Charger":
		_set_charger_preview_mode(true)
		_show_charger_controls()
		return
	if feature_name == "Charging Cable":
		# Opening the cable editor must not silently enable the charger.
		_set_charger_preview_mode(true)
		_rebuild_charger_preview()
		_show_charger_controls("CABLE")
		return
	if feature_name == "Phone Type":
		_show_phone_type_controls()
	elif feature_name == "Screen Tech":
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
	elif feature_name == "Front Camera MP":
		_show_front_camera_mp_controls()
	elif feature_name == "Rear Camera MP":
		_show_rear_camera_mp_controls()
	elif feature_name == "Back Design":
		_show_back_design_controls()
	elif feature_name == "RAM":
		_show_ram_controls()
	elif feature_name == "RAM Technology":
		_show_ram_technology_controls()
	elif feature_name in ["ROM", "Internal Storage", "Storage"]:
		_show_rom_controls()
	elif feature_name == "Battery":
		_show_battery_controls()
	elif feature_name == "Charging Speed":
		_show_charging_speed_controls()
	elif feature_name == "Wireless Charge":
		_show_wireless_charge_controls()
	elif feature_name == "Bluetooth":
		_show_bluetooth_controls()
	elif feature_name == "WiFi":
		_show_wifi_controls()
	elif feature_name == "Network":
		_show_mobile_network_controls()
	elif feature_name == "Sensors":
		_show_sensor_controls()
	elif feature_name == "Refresh Rate":
		_show_refresh_rate_controls()
	elif feature_name == "Memory Clock":
		_show_memory_clock_controls()
	elif feature_name == "Cooling System Design":
		_show_cooling_system_controls()



func _show_phone_type_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "PhoneTypeControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("PHONE TYPE", 19, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Choose the chassis architecture. Foldables get a separated frame, a precision hinge and independent inner / outer displays.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	for phone_type in ["Standard", "Flip", "Fold"]:
		var option := Button.new()
		option.name = "PhoneType_" + phone_type
		option.text = phone_type.to_upper() + ("     ✓ SELECTED" if selected_phone_type == phone_type else "")
		option.custom_minimum_size = Vector2(0, 50)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(option, 14)
		_style_staff_button(option, selected_phone_type == phone_type)
		option.pressed.connect(_on_phone_type_selected.bind(phone_type))
		active_feature_panel.add_child(option)

	var note_text := "Standard uses one rigid display chassis." if selected_phone_type == "Standard" else ("Flip uses a horizontal clamshell hinge and a compact cover display." if selected_phone_type == "Flip" else "Fold uses a book-style centre hinge, a wide inner display and a full-height cover display.")
	var note := _make_label(note_text, 12, Color("#a8dcb0"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(note)


func _on_phone_type_selected(phone_type: String) -> void:
	if not ["Standard", "Flip", "Fold"].has(phone_type):
		return
	if selected_phone_type == phone_type:
		_show_phone_type_controls()
		return
	selected_phone_type = phone_type
	fold_target_angle_degrees = fold_angle_degrees
	fold_pinch_active = false
	preview_touch_points.clear()
	_refresh_phone_mesh()
	if software_value_labels.has("PHONE TYPE") and is_instance_valid(software_value_labels["PHONE TYPE"]):
		var phone_type_label: Label = software_value_labels["PHONE TYPE"]
		phone_type_label.text = selected_phone_type
	_show_phone_type_controls()
	_refresh_screen_type_buttons()


func _ensure_gradient_popup_layer() -> CanvasLayer:
	if not is_instance_valid(gradient_popup_layer):
		gradient_popup_layer = CanvasLayer.new()
		gradient_popup_layer.name = "GradientPopupOverlay"
		gradient_popup_layer.layer = 80
		add_child(gradient_popup_layer)
	return gradient_popup_layer


func _close_worksite_back_design_color_view() -> void:
	# Close overlays that live outside the mounted color panel so they cannot
	# intercept input after the wizard moves to another step.
	_close_back_design_selection_popup()
	if is_instance_valid(back_box_gradient_popup):
		back_box_gradient_popup.queue_free()
		back_box_gradient_popup = null
	if is_instance_valid(gradient_direction_popup):
		gradient_direction_popup.queue_free()
		gradient_direction_popup = null
	if is_instance_valid(back_design_selection_popup):
		back_design_selection_popup.queue_free()
		back_design_selection_popup = null
		back_design_selection_scroll = null
		back_design_selection_items = null
	back_design_color_mode = false
	back_design_gradient_color_edit_mode = false


func _show_device_color_controls(return_to_back_design: bool = false, for_phone_case: bool = false, for_charger: bool = false, for_smartwatch: bool = false, for_power_bank: bool = false, for_earbuds: bool = false, for_box_package: bool = false) -> void:
	_close_back_design_selection_popup()
	if is_instance_valid(back_box_gradient_popup):
		back_box_gradient_popup.queue_free()
		back_box_gradient_popup = null
	if is_instance_valid(gradient_direction_popup):
		gradient_direction_popup.queue_free()
		gradient_direction_popup = null
	back_design_color_mode = return_to_back_design
	# New Worksite raised boxes always open with independent base and gradient colors.
	# This also normalizes boxes carried over from older saved editor state.
	if return_to_back_design and worksite_creation_mode and not back_design_boxes.is_empty():
		if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size():
			selected_back_design_box = back_design_boxes.size() - 1
		back_design_boxes[selected_back_design_box]["use_device_color"] = false
	phone_case_color_mode = for_phone_case
	charger_color_mode = for_charger
	smartwatch_color_mode = for_smartwatch
	power_bank_color_mode = for_power_bank
	wireless_earbuds_color_mode = for_earbuds
	box_package_color_mode = for_box_package
	var panel_host := active_feature_panel.get_parent() as Control if is_instance_valid(active_feature_panel) else right_tools_content
	if not is_instance_valid(panel_host):
		panel_host = right_tools_content
	if not is_instance_valid(panel_host):
		return
	if is_instance_valid(active_feature_panel) and active_feature_panel.get_parent() == panel_host:
		panel_host.remove_child(active_feature_panel)
		active_feature_panel.queue_free()
	if panel_host == right_tools_content:
		for old_child in right_tools_content.get_children():
			old_child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BoxPackageColorControls" if for_box_package else ("ChargerColorControls" if for_charger else ("PhoneCaseColorControls" if for_phone_case else ("SmartwatchColorControls" if for_smartwatch else ("PowerBankColorControls" if for_power_bank else ("WirelessEarbudsColorControls" if for_earbuds else "DeviceColorControls")))))
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if panel_host != right_tools_content else (Control.SIZE_EXPAND_FILL if return_to_back_design else Control.SIZE_SHRINK_BEGIN)
	var color_viewport_size := get_viewport().get_visible_rect().size
	var compact_color_ui := color_viewport_size.y < 760.0 or color_viewport_size.x < 900.0
	active_feature_panel.add_theme_constant_override("separation", 6 if compact_color_ui else 8)
	panel_host.add_child(active_feature_panel)

	if return_to_back_design or for_phone_case or for_charger or for_smartwatch or for_power_bank or for_earbuds or for_box_package:
		var color_header := HBoxContainer.new()
		color_header.add_theme_constant_override("separation", 6)
		active_feature_panel.add_child(color_header)
		var back_button := Button.new()
		back_button.text = "‹"
		back_button.custom_minimum_size = Vector2(34, 32)
		back_button.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(back_button, 25)
		if return_to_back_design:
			_style_back_design_button(back_button, false)
		else:
			_style_staff_button(back_button, false)
		back_button.pressed.connect(_show_box_package_controls if for_box_package else (_show_charger_controls if for_charger else (_show_phone_case_controls if for_phone_case else (_show_smartwatch_controls if for_smartwatch else (_show_power_bank_controls if for_power_bank else (_show_earbuds_controls if for_earbuds else _show_back_design_controls))))))
		color_header.add_child(back_button)
		var color_heading := "BOX PACKAGE COLOR" if for_box_package else ("CHARGER COLOR" if for_charger else ("CASE COLOR" if for_phone_case else ("SMART WATCH COLOR" if for_smartwatch else ("POWER BANK COLOR" if for_power_bank else ("WIRELESS EARBUDS COLOR" if for_earbuds else "BACK DESIGN COLOR")))))
		var color_title := _make_label(color_heading, 16, Color("#c7eacb"))
		color_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		color_header.add_child(color_title)
	else:
		var title := _make_label("DEVICE COLOR", 18, Color("#c7eacb"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(title)
	var back_design_toggle_row: HBoxContainer
	if return_to_back_design and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		back_design_toggle_row = HBoxContainer.new()
		back_design_toggle_row.name = "BackDesignColorTogglesRow"
		back_design_toggle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back_design_toggle_row.add_theme_constant_override("separation", 18)
		active_feature_panel.add_child(back_design_toggle_row)
		var use_device_color_group := HBoxContainer.new()
		use_device_color_group.name = "UseDeviceColorRow"
		use_device_color_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use_device_color_group.add_theme_constant_override("separation", 6)
		back_design_toggle_row.add_child(use_device_color_group)
		var use_device_color_label := _make_label("USE DEVICE COLOR", 13, Color("#d8eaf5"))
		use_device_color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use_device_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		use_device_color_group.add_child(use_device_color_label)
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
		use_device_color.button_pressed = bool(back_design_boxes[selected_back_design_box].get("use_device_color", not worksite_creation_mode))
		use_device_color.focus_mode = Control.FOCUS_NONE
		use_device_color.mouse_filter = Control.MOUSE_FILTER_STOP
		use_device_color.toggled.connect(_on_back_design_use_device_color_toggled)
		use_device_color_group.add_child(use_device_color)
		_set_back_design_custom_color_controls_enabled(not use_device_color.button_pressed)
		if not use_device_color.button_pressed:
			back_design_gradient_color_edit_mode = false

	if (not return_to_back_design and not for_charger and not for_smartwatch and not for_power_bank and not for_box_package) or (return_to_back_design and worksite_creation_mode and (back_design_boxes.is_empty() or (selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size() and not bool(back_design_boxes[selected_back_design_box].get("use_device_color", false))))) or (return_to_back_design and not worksite_creation_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size() and not bool(back_design_boxes[selected_back_design_box].get("use_device_color", true))):
		var gradient_toggle_row := HBoxContainer.new()
		gradient_toggle_row.name = "EnableDeviceGradientRow"
		gradient_toggle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gradient_toggle_row.add_theme_constant_override("separation", 6)
		if return_to_back_design and is_instance_valid(back_design_toggle_row):
			back_design_toggle_row.add_child(gradient_toggle_row)
		else:
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
		gradient_toggle.button_pressed = (bool(back_design_boxes[selected_back_design_box].get("gradient_enabled", false)) if selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size() else back_design_gradient_enabled_without_box) if return_to_back_design else (phone_case_gradient_enabled if for_phone_case else device_gradient_enabled)
		gradient_toggle.focus_mode = Control.FOCUS_NONE
		gradient_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		if return_to_back_design:
			gradient_toggle.toggled.connect(_on_back_box_gradient_toggled)
		else:
			gradient_toggle.pressed.connect(_on_device_gradient_toggle_pressed.bind(gradient_toggle))
		gradient_toggle_row.add_child(gradient_toggle)
		var gradient_options := VBoxContainer.new()
		gradient_options.name = "GradientOptions"
		gradient_options.add_theme_constant_override("separation", 7)
		active_feature_panel.add_child(gradient_options)
		gradient_direction_button = Button.new()
		gradient_direction_button.name = "GradientDirection"
		gradient_direction_button.text = _gradient_direction_name(_get_active_gradient_direction()) + "  ▼"
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
		direction_popup_style.bg_color = Color("#07190d")
		direction_popup_style.border_color = Color("#65d783")
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
		_ensure_gradient_popup_layer().add_child(gradient_direction_popup)
		_rebuild_gradient_direction_popup()
		gradient_options.visible = (bool(back_design_boxes[selected_back_design_box].get("gradient_enabled", false)) if selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size() else back_design_gradient_enabled_without_box) if return_to_back_design else (phone_case_gradient_enabled if for_phone_case else device_gradient_enabled)

	var picker_columns := HBoxContainer.new()
	picker_columns.name = "DeviceColorPickerColumns"
	picker_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_columns.add_theme_constant_override("separation", 12)
	active_feature_panel.add_child(picker_columns)
	var has_valid_back_box := selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size()
	var uses_dual_color_pickers := (
		not for_charger
		and not for_smartwatch
		and not for_power_bank
		and not for_earbuds
		and not for_box_package
		and (
			not return_to_back_design
			or (
				worksite_creation_mode
				and (
					back_design_boxes.is_empty()
					or (has_valid_back_box and not bool(back_design_boxes[selected_back_design_box].get("use_device_color", false)))
				)
			)
			or (
				not worksite_creation_mode
				and has_valid_back_box
				and not bool(back_design_boxes[selected_back_design_box].get("use_device_color", true))
			)
		)
	)
	var normal_picker := _build_device_color_picker_panel(false, color_viewport_size)
	picker_columns.add_child(normal_picker)
	if uses_dual_color_pickers:
		var gradient_picker := _build_device_color_picker_panel(true, color_viewport_size)
		picker_columns.add_child(gradient_picker)
		var gradient_picker_enabled := (bool(back_design_boxes[selected_back_design_box].get("gradient_enabled", false)) if selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size() else back_design_gradient_enabled_without_box) if return_to_back_design else (phone_case_gradient_enabled if for_phone_case else device_gradient_enabled)
		_set_device_gradient_picker_enabled(gradient_picker, gradient_picker_enabled)
	if return_to_back_design and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		_set_back_design_custom_color_controls_enabled(not bool(back_design_boxes[selected_back_design_box].get("use_device_color", not worksite_creation_mode)))
	if return_to_back_design:
		_add_back_design_flexible_space(active_feature_panel)
		if worksite_creation_mode:
			worksite_nested_color_view_opened.emit()


func _get_active_color_picker_color() -> Color:
	if box_package_color_mode:
		return box_package_color
	if charger_color_mode:
		return charger_body_color
	if smartwatch_color_mode:
		return smartwatch_body_color
	if power_bank_color_mode:
		return power_bank_body_color
	if wireless_earbuds_color_mode:
		return wireless_earbuds_body_color
	if phone_case_color_mode:
		return phone_case_gradient_color if phone_case_gradient_color_edit_mode else phone_case_color
	if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		var box: Dictionary = back_design_boxes[selected_back_design_box]
		if bool(box.get("use_device_color", not worksite_creation_mode)):
			return device_body_color
		if back_design_gradient_color_edit_mode:
			return Color(box.get("gradient_color", Color("#536dfe")))
		return Color(box.get("custom_color", device_body_color))
	if gradient_color_edit_mode and not back_design_color_mode:
		return device_gradient_color
	return device_body_color


func _set_back_design_custom_color_controls_enabled(enabled: bool) -> void:
	if not is_instance_valid(active_feature_panel): return
	for node_name in ["DeviceColorPickerColumns", "GradientOptions"]:
		var control := active_feature_panel.get_node_or_null(node_name) as Control
		if is_instance_valid(control):
			control.modulate.a = 1.0 if enabled else 0.38
			control.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _on_back_design_use_device_color_toggled(enabled: bool) -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size(): return
	back_design_boxes[selected_back_design_box]["use_device_color"] = enabled
	_set_back_design_custom_color_controls_enabled(not enabled)
	_refresh_back_design_boxes()
	if is_instance_valid(device_color_hex_label): device_color_hex_label.text = "#" + _get_active_color_picker_color().to_html(false).to_upper()


func _on_device_color_hue_changed(hue: float) -> void:
	var spectrum := active_feature_panel.get_node_or_null("DeviceColorSpectrum") as DeviceColorSpectrum if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(spectrum):
		spectrum.set_hue(hue)
		_on_device_body_color_changed(Color.from_hsv(hue, spectrum.saturation, spectrum.brightness))



func _build_device_color_picker_panel(use_gradient_color: bool, viewport_size: Vector2) -> VBoxContainer:
	var picker := VBoxContainer.new()
	picker.name = "GradientColorPicker" if use_gradient_color else "NormalColorPicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picker.add_theme_constant_override("separation", 5)
	var heading := _make_label("GRADIENT" if use_gradient_color else "NORMAL", 14, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker.add_child(heading)
	var special_color_mode := back_design_color_mode or charger_color_mode or smartwatch_color_mode or power_bank_color_mode or wireless_earbuds_color_mode or box_package_color_mode
	var selected_color: Color
	if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		var selected_box: Dictionary = back_design_boxes[selected_back_design_box]
		selected_color = Color(selected_box.get("gradient_color", Color("#536dfe"))) if use_gradient_color else Color(selected_box.get("custom_color", device_body_color))
	elif special_color_mode:
		selected_color = _get_active_color_picker_color()
	else:
		selected_color = phone_case_gradient_color if phone_case_color_mode and use_gradient_color else (phone_case_color if phone_case_color_mode else (device_gradient_color if use_gradient_color else device_body_color))
	picker.add_child(_make_label("COLOR SPECTRUM", 11, Color("#a9e3ff")))
	var spectrum := DeviceColorSpectrum.new()
	spectrum.name = "DeviceColorSpectrum"
	spectrum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectrum.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.22, 125.0, 175.0))
	spectrum.set_color_value(selected_color)
	spectrum.color_changed.connect(_on_color_picker_panel_changed.bind(use_gradient_color))
	picker.add_child(spectrum)
	picker.add_child(_make_label("HUE", 11, Color("#a9e3ff")))
	var hue_bar := DeviceHueBar.new()
	hue_bar.name = "DeviceColorHue"
	hue_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hue_bar.set_hue(selected_color.h)
	hue_bar.hue_changed.connect(_on_color_picker_panel_hue_changed.bind(use_gradient_color))
	picker.add_child(hue_bar)
	var selected_label := _make_label("#" + selected_color.to_html(false).to_upper(), 12, Color("#e5f6ff"))
	selected_label.name = "SelectedColorHex"
	picker.add_child(selected_label)
	if not use_gradient_color:
		device_color_hex_label = selected_label
	picker.add_child(_make_label("HEX CODE", 11, Color("#a9e3ff")))
	var hex_row := HBoxContainer.new()
	hex_row.name = "CustomHexEntry"
	hex_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_row.add_theme_constant_override("separation", 5)
	picker.add_child(hex_row)
	var hex_input := LineEdit.new()
	hex_input.name = "DeviceColorHexInput"
	hex_input.placeholder_text = "#RRGGBB"
	hex_input.text = selected_color.to_html(false).to_upper()
	hex_input.max_length = 7
	hex_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_input.custom_minimum_size = Vector2(0, 36)
	hex_input.add_theme_color_override("font_color", Color("#edf8ff"))
	hex_input.add_theme_color_override("font_placeholder_color", Color("#78937c"))
	hex_input.add_theme_color_override("caret_color", Color("#75d58a"))
	var hex_normal := StyleBoxFlat.new()
	hex_normal.bg_color = Color("#101d13")
	hex_normal.set_corner_radius_all(7)
	hex_normal.set_border_width_all(1)
	hex_normal.border_color = Color("#315a38")
	hex_normal.content_margin_left = 7.0
	hex_normal.content_margin_right = 7.0
	var hex_focus := hex_normal.duplicate() as StyleBoxFlat
	hex_focus.border_color = Color("#64d783")
	hex_focus.set_border_width_all(2)
	hex_input.add_theme_stylebox_override("normal", hex_normal)
	hex_input.add_theme_stylebox_override("focus", hex_focus)
	hex_input.add_theme_stylebox_override("read_only", hex_normal)
	hex_row.add_child(hex_input)
	var apply_button := Button.new()
	apply_button.name = "ApplyDeviceHex"
	apply_button.text = "APPLY"
	apply_button.custom_minimum_size = Vector2(58, 36)
	apply_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(apply_button, 11)
	var apply_normal := StyleBoxFlat.new()
	apply_normal.bg_color = Color("#174b28")
	apply_normal.set_corner_radius_all(7)
	apply_normal.set_border_width_all(1)
	apply_normal.border_color = Color("#4dbb6a")
	var apply_hover := apply_normal.duplicate() as StyleBoxFlat
	apply_hover.bg_color = Color("#206b35")
	apply_button.add_theme_stylebox_override("normal", apply_normal)
	apply_button.add_theme_stylebox_override("hover", apply_hover)
	apply_button.add_theme_color_override("font_color", Color("#effaff"))
	hex_row.add_child(apply_button)
	apply_button.pressed.connect(_on_color_picker_hex_submitted.bind(hex_input, use_gradient_color))
	hex_input.text_submitted.connect(_on_color_picker_hex_text_submitted.bind(use_gradient_color))
	return picker


func _set_device_gradient_picker_enabled(picker: Control, enabled: bool) -> void:
	if not is_instance_valid(picker):
		return
	picker.modulate.a = 1.0 if enabled else 0.38
	for child in picker.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		if child is BaseButton:
			(child as BaseButton).disabled = not enabled
		elif child is LineEdit:
			(child as LineEdit).editable = enabled
	picker.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _on_color_picker_panel_changed(color: Color, use_gradient_color: bool) -> void:
	_on_gradient_color_target_selected(use_gradient_color)
	_on_device_body_color_changed(color)


func _on_color_picker_panel_hue_changed(hue: float, use_gradient_color: bool) -> void:
	_on_gradient_color_target_selected(use_gradient_color)
	var picker_name := "GradientColorPicker" if use_gradient_color else "NormalColorPicker"
	var picker := active_feature_panel.get_node_or_null("DeviceColorPickerColumns/" + picker_name) if is_instance_valid(active_feature_panel) else null
	var spectrum := picker.get_node_or_null("DeviceColorSpectrum") as DeviceColorSpectrum if is_instance_valid(picker) else null
	if is_instance_valid(spectrum):
		spectrum.set_hue(hue)
		_on_device_body_color_changed(Color.from_hsv(hue, spectrum.saturation, spectrum.brightness))


func _on_color_picker_hex_submitted(hex_input: LineEdit, use_gradient_color: bool) -> void:
	if not is_instance_valid(hex_input):
		return
	_on_gradient_color_target_selected(use_gradient_color)
	_apply_device_color_hex(hex_input.text)


func _on_color_picker_hex_text_submitted(value: String, use_gradient_color: bool) -> void:
	_on_gradient_color_target_selected(use_gradient_color)
	_apply_device_color_hex(value)


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


func _create_device_body_material(geometry_offset: Vector2 = Vector2.ZERO, mesh_size_override: Vector3 = Vector3.ZERO) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 solid_color : source_color = vec4(0.647, 0.678, 0.714, 1.0);
uniform vec4 gradient_color : source_color = vec4(0.325, 0.427, 0.996, 1.0);
uniform bool gradient_enabled = false;
uniform int gradient_direction : hint_range(0, 3) = 0;
uniform vec2 geometry_offset = vec2(0.0);
uniform bool charging_port_inner_walls_enabled = false;
uniform vec4 charging_port_bounds = vec4(0.0);
uniform float charging_port_bottom_y = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	bool is_charging_port_inner_wall = charging_port_inner_walls_enabled
		&& abs(local_position.y - charging_port_bottom_y) < 0.0005
		&& abs(local_normal.y) < 0.25
		&& local_position.x >= charging_port_bounds.x - 0.001
		&& local_position.x <= charging_port_bounds.z + 0.001
		&& local_position.z >= charging_port_bounds.y - 0.001
		&& local_position.z <= charging_port_bounds.w + 0.001;
	if (is_charging_port_inner_wall) {
		// These faces are the actual cut walls of the phone chassis, not the
		// separate port inserts. Keep them black and completely non-reflective.
		ALBEDO = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		// The front face is authored with an outward +Z normal and stays solid.
		// The rear (-Z) face and all perimeter faces receive the gradient.
		if (local_normal.z > 0.5 || !gradient_enabled) {
			ALBEDO = solid_color.rgb;
		} else {
			vec2 p = (local_position.xy + geometry_offset) / vec2(0.95, 2.0) + vec2(0.5);
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
		// Preserve the existing finish everywhere except the charging-port walls.
		float edge_factor = 1.0 - smoothstep(0.05, 0.95, abs(local_normal.z));
		METALLIC = mix(0.16, 0.78, edge_factor);
		ROUGHNESS = mix(0.42, 0.25, edge_factor);
		SPECULAR = mix(0.62, 0.90, edge_factor);
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("solid_color", device_body_color)
	material.set_shader_parameter("gradient_color", device_gradient_color)
	material.set_shader_parameter("gradient_enabled", device_gradient_enabled)
	material.set_shader_parameter("gradient_direction", device_gradient_direction)
	material.set_shader_parameter("geometry_offset", geometry_offset)
	var port_mesh_size := mesh_size_override if mesh_size_override.x > 0.0 and mesh_size_override.y > 0.0 else _active_phone_size()
	if charge_port_type != "None" and charge_port_opening_points.size() >= 3:
		var port_min := Vector2(INF, INF)
		var port_max := Vector2(-INF, -INF)
		for point in charge_port_opening_points:
			port_min.x = minf(port_min.x, point.x)
			port_min.y = minf(port_min.y, point.y)
			port_max.x = maxf(port_max.x, point.x)
			port_max.y = maxf(port_max.y, point.y)
		material.set_shader_parameter("charging_port_inner_walls_enabled", true)
		material.set_shader_parameter("charging_port_bounds", Vector4(port_min.x, port_min.y, port_max.x, port_max.y))
		material.set_shader_parameter("charging_port_bottom_y", -port_mesh_size.y * 0.5)
	return material


func _on_back_box_gradient_toggled(enabled: bool) -> void:
	if selected_back_design_box < 0 or selected_back_design_box >= back_design_boxes.size():
		if worksite_creation_mode:
			back_design_gradient_enabled_without_box = enabled
			if not enabled:
				back_design_gradient_color_edit_mode = false
				if is_instance_valid(gradient_direction_popup):
					gradient_direction_popup.visible = false
			var empty_gradient_options := active_feature_panel.get_node_or_null("GradientOptions") as Control if is_instance_valid(active_feature_panel) else null
			if is_instance_valid(empty_gradient_options):
				empty_gradient_options.visible = enabled
			var empty_gradient_picker := active_feature_panel.get_node_or_null("DeviceColorPickerColumns/GradientColorPicker") as Control if is_instance_valid(active_feature_panel) else null
			if is_instance_valid(empty_gradient_picker):
				_set_device_gradient_picker_enabled(empty_gradient_picker, enabled)
		return
	back_design_boxes[selected_back_design_box]["gradient_enabled"] = enabled
	if not enabled:
		back_design_gradient_color_edit_mode = false
		if is_instance_valid(gradient_direction_popup):
			gradient_direction_popup.visible = false
	_refresh_back_design_boxes()
	var gradient_options := active_feature_panel.get_node_or_null("GradientOptions") as Control if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(gradient_options):
		gradient_options.visible = enabled
	var gradient_picker := active_feature_panel.get_node_or_null("DeviceColorPickerColumns/GradientColorPicker") as Control if is_instance_valid(active_feature_panel) else null
	if is_instance_valid(gradient_picker):
		_set_device_gradient_picker_enabled(gradient_picker, enabled)
	_refresh_device_color_editor_controls()

func _create_back_box_gradient_popup(open_on_create: bool) -> void:
	if is_instance_valid(back_box_gradient_popup):
		back_box_gradient_popup.queue_free()
		back_box_gradient_popup = null
	var editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
	if not is_instance_valid(editor_root):
		return
	back_box_gradient_popup = PanelContainer.new()
	back_box_gradient_popup.name = "BackBoxGradientOptions"
	back_box_gradient_popup.visible = open_on_create
	back_box_gradient_popup.z_index = 120
	back_box_gradient_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color("#07190d")
	popup_style.border_color = Color("#65d783")
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(12)
	popup_style.content_margin_left = 10
	popup_style.content_margin_right = 10
	popup_style.content_margin_top = 9
	popup_style.content_margin_bottom = 9
	back_box_gradient_popup.add_theme_stylebox_override("panel", popup_style)
	editor_root.add_child(back_box_gradient_popup)

	var popup_content := VBoxContainer.new()
	popup_content.add_theme_constant_override("separation", 8)
	back_box_gradient_popup.add_child(popup_content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	popup_content.add_child(header)
	var title := _make_label("GRADIENT EDITOR", 13, Color("#c7eacb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(32, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(close_button, 15)
	_style_staff_button(close_button, false)
	close_button.pressed.connect(_close_back_box_gradient_popup)
	header.add_child(close_button)

	var box_target_row := HBoxContainer.new()
	box_target_row.name = "BackBoxGradientColorTargets"
	box_target_row.add_theme_constant_override("separation", 7)
	popup_content.add_child(box_target_row)
	var box_base_target := Button.new()
	box_base_target.name = "EditBackBoxColor"
	box_base_target.text = "BOX COLOR"
	box_base_target.custom_minimum_size.y = 42
	box_base_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_staff_button(box_base_target, not back_design_gradient_color_edit_mode)
	box_base_target.pressed.connect(_on_back_box_gradient_color_target_selected.bind(false))
	box_target_row.add_child(box_base_target)
	var box_gradient_target := Button.new()
	box_gradient_target.name = "EditBackBoxGradientColor"
	box_gradient_target.text = "GRADIENT COLOR"
	box_gradient_target.custom_minimum_size.y = 42
	box_gradient_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	popup_content.add_child(gradient_direction_button)

	gradient_direction_popup = PanelContainer.new()
	gradient_direction_popup.name = "GradientDirectionCustomDropdown"
	gradient_direction_popup.visible = false
	gradient_direction_popup.z_index = 130
	gradient_direction_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var direction_style := StyleBoxFlat.new()
	direction_style.bg_color = Color("#07190d")
	direction_style.border_color = Color("#65d783")
	direction_style.set_border_width_all(2)
	direction_style.set_corner_radius_all(12)
	direction_style.content_margin_left = 8
	direction_style.content_margin_right = 8
	direction_style.content_margin_top = 8
	direction_style.content_margin_bottom = 8
	gradient_direction_popup.add_theme_stylebox_override("panel", direction_style)
	gradient_direction_items = VBoxContainer.new()
	gradient_direction_items.add_theme_constant_override("separation", 6)
	gradient_direction_popup.add_child(gradient_direction_items)
	editor_root.add_child(gradient_direction_popup)
	_rebuild_gradient_direction_popup()
	if open_on_create:
		call_deferred("_position_back_box_gradient_popup")


func _position_back_box_gradient_popup() -> void:
	if not is_instance_valid(back_box_gradient_popup) or not back_box_gradient_popup.visible:
		return
	var editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
	var toggle_row := active_feature_panel.get_node_or_null("BackBoxGradientToggleRow") as Control if is_instance_valid(active_feature_panel) else null
	if not is_instance_valid(editor_root) or not is_instance_valid(toggle_row):
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var anchor_rect := toggle_row.get_global_rect()
	var panel_width := minf(maxf(anchor_rect.size.x, 260.0), viewport_rect.size.x - 16.0)
	back_box_gradient_popup.custom_minimum_size = Vector2(panel_width, 0.0)
	back_box_gradient_popup.size = back_box_gradient_popup.get_combined_minimum_size()
	var panel_height := back_box_gradient_popup.size.y
	var panel_x := clampf(anchor_rect.position.x, viewport_rect.position.x + 8.0, viewport_rect.end.x - panel_width - 8.0)
	var below_y := anchor_rect.end.y + 8.0
	var panel_y := below_y if below_y + panel_height <= viewport_rect.end.y - 8.0 else maxf(viewport_rect.position.y + 8.0, anchor_rect.position.y - panel_height - 8.0)
	back_box_gradient_popup.global_position = Vector2(panel_x, panel_y)


func _close_back_box_gradient_popup() -> void:
	if is_instance_valid(back_box_gradient_popup):
		back_box_gradient_popup.visible = false
	if is_instance_valid(gradient_direction_popup):
		gradient_direction_popup.visible = false


func _on_back_box_gradient_color_target_selected(use_gradient_color: bool) -> void:
	back_design_gradient_color_edit_mode = use_gradient_color
	_refresh_device_color_editor_controls()


func _on_device_gradient_toggle_pressed(toggle: TextureButton) -> void:
	_on_device_gradient_toggled(toggle.button_pressed)


func _on_gradient_color_target_selected(use_gradient_color: bool) -> void:
	if back_design_color_mode:
		back_design_gradient_color_edit_mode = use_gradient_color
	elif phone_case_color_mode:
		phone_case_gradient_color_edit_mode = use_gradient_color
	else:
		gradient_color_edit_mode = use_gradient_color
	_refresh_device_color_editor_controls()


func _refresh_device_color_editor_controls() -> void:
	if not is_instance_valid(active_feature_panel): return
	for use_gradient_color in [false, true]:
		var picker_name := "GradientColorPicker" if use_gradient_color else "NormalColorPicker"
		var picker := active_feature_panel.get_node_or_null("DeviceColorPickerColumns/" + picker_name)
		if not is_instance_valid(picker):
			continue
		var special_color_mode := back_design_color_mode or charger_color_mode or smartwatch_color_mode or power_bank_color_mode or wireless_earbuds_color_mode or box_package_color_mode
		var selected_color: Color
		if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
			var selected_box: Dictionary = back_design_boxes[selected_back_design_box]
			selected_color = Color(selected_box.get("gradient_color", Color("#536dfe"))) if use_gradient_color else Color(selected_box.get("custom_color", device_body_color))
		elif special_color_mode:
			selected_color = _get_active_color_picker_color()
		else:
			selected_color = phone_case_gradient_color if phone_case_color_mode and use_gradient_color else (phone_case_color if phone_case_color_mode else (device_gradient_color if use_gradient_color else device_body_color))
		var spectrum := picker.get_node_or_null("DeviceColorSpectrum") as DeviceColorSpectrum
		if is_instance_valid(spectrum): spectrum.set_color_value(selected_color)
		var hue_bar := picker.get_node_or_null("DeviceColorHue") as DeviceHueBar
		if is_instance_valid(hue_bar): hue_bar.set_hue(selected_color.h)
		var hex_label := picker.get_node_or_null("SelectedColorHex") as Label
		if is_instance_valid(hex_label):
			hex_label.text = "#" + selected_color.to_html(false).to_upper()
			hex_label.add_theme_color_override("font_color", Color("#e5f6ff"))
		var hex_input := picker.get_node_or_null("CustomHexEntry/DeviceColorHexInput") as LineEdit
		if is_instance_valid(hex_input):
			hex_input.text = selected_color.to_html(false).to_upper()
		var picker_enabled: bool = not use_gradient_color or (bool(back_design_boxes[selected_back_design_box].get("gradient_enabled", false)) if back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size() else (phone_case_gradient_enabled if phone_case_color_mode else device_gradient_enabled))
		_set_device_gradient_picker_enabled(picker, picker_enabled)
	var base_button := active_feature_panel.get_node_or_null("GradientOptions/GradientColorTargets/EditDeviceColor") as Button
	var gradient_button := active_feature_panel.get_node_or_null("GradientOptions/GradientColorTargets/EditGradientColor") as Button
	var selected_gradient_edit := phone_case_gradient_color_edit_mode if phone_case_color_mode else gradient_color_edit_mode
	if is_instance_valid(base_button): _style_staff_button(base_button, not selected_gradient_edit)
	if is_instance_valid(gradient_button): _style_staff_button(gradient_button, selected_gradient_edit)
	var box_base_button: Button = null
	var box_gradient_button: Button = null
	if is_instance_valid(back_box_gradient_popup):
		box_base_button = back_box_gradient_popup.get_node_or_null("BackBoxGradientColorTargets/EditBackBoxColor") as Button
		box_gradient_button = back_box_gradient_popup.get_node_or_null("BackBoxGradientColorTargets/EditBackBoxGradientColor") as Button
	if is_instance_valid(box_base_button): _style_staff_button(box_base_button, not back_design_gradient_color_edit_mode)
	if is_instance_valid(box_gradient_button): _style_staff_button(box_gradient_button, back_design_gradient_color_edit_mode)


func _gradient_direction_name(index: int) -> String:
	var names := ["VERTICAL", "HORIZONTAL", "DIAGONAL", "RADIAL"]
	return names[clampi(index, 0, names.size() - 1)]


func _get_active_gradient_direction() -> int:
	if phone_case_color_mode:
		return phone_case_gradient_direction
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
		style.bg_color = Color("#10351b")
		style.border_color = Color("#285c35")
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
	if phone_case_color_mode:
		phone_case_gradient_direction = selected_direction
		_refresh_phone_case_material()
	elif back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		back_design_boxes[selected_back_design_box]["gradient_direction"] = selected_direction
		_refresh_back_design_boxes()
	else:
		device_gradient_direction = selected_direction
		if is_instance_valid(phone_body):
			phone_body.material_override = _create_device_body_material()
			_refresh_foldable_frame_materials()
	if is_instance_valid(gradient_direction_button):
		gradient_direction_button.text = _gradient_direction_name(selected_direction) + "  ▼"
	_rebuild_gradient_direction_popup()
	if is_instance_valid(gradient_direction_popup):
		gradient_direction_popup.visible = false


func _on_device_gradient_toggled(enabled: bool) -> void:
	if phone_case_color_mode:
		phone_case_gradient_enabled = enabled
		if not enabled:
			phone_case_gradient_color_edit_mode = false
		_refresh_phone_case_material()
	else:
		device_gradient_enabled = enabled
		if is_instance_valid(phone_body):
			phone_body.material_override = _create_device_body_material()
			_refresh_foldable_frame_materials()
	if is_instance_valid(active_feature_panel):
		var options := active_feature_panel.get_node_or_null("GradientOptions") as Control
		if is_instance_valid(options):
			options.visible = enabled
		var gradient_picker := active_feature_panel.get_node_or_null("DeviceColorPickerColumns/GradientColorPicker") as Control
		_set_device_gradient_picker_enabled(gradient_picker, enabled)
	_refresh_device_color_editor_controls()


func _on_device_body_color_changed(color: Color) -> void:
	var selected_color := Color(color.r, color.g, color.b, 1.0)
	if charger_color_mode:
		charger_body_color = selected_color
		_rebuild_charger_preview()
	elif smartwatch_color_mode:
		smartwatch_body_color = selected_color
		_rebuild_smartwatch_preview()
	elif power_bank_color_mode:
		power_bank_body_color = selected_color
		_rebuild_power_bank_preview()
	elif wireless_earbuds_color_mode:
		wireless_earbuds_body_color = selected_color
		_rebuild_earbuds_preview()
	elif box_package_color_mode:
		box_package_color = selected_color
		_refresh_box_package_material()
	elif phone_case_color_mode:
		if phone_case_gradient_color_edit_mode:
			phone_case_gradient_color = selected_color
		else:
			phone_case_color = selected_color
		_refresh_phone_case_material()
	elif back_design_color_mode and selected_back_design_box >= 0 and selected_back_design_box < back_design_boxes.size():
		if bool(back_design_boxes[selected_back_design_box].get("use_device_color", not worksite_creation_mode)): return
		if back_design_gradient_color_edit_mode:
			back_design_boxes[selected_back_design_box]["gradient_color"] = selected_color
		else:
			back_design_boxes[selected_back_design_box]["custom_color"] = selected_color
		_refresh_back_design_boxes()
	elif gradient_color_edit_mode:
		device_gradient_color = selected_color
	else:
		device_body_color = selected_color
	if not phone_case_color_mode and not box_package_color_mode and not charger_color_mode and not power_bank_color_mode and not smartwatch_color_mode and not wireless_earbuds_color_mode and not back_design_color_mode and is_instance_valid(phone_body):
		phone_body.material_override = _create_device_body_material()
		_refresh_foldable_frame_materials()
	if is_instance_valid(device_color_hex_label):
		device_color_hex_label.text = "#" + _get_active_color_picker_color().to_html(false).to_upper()
		device_color_hex_label.add_theme_color_override("font_color", Color("#d8f1ff"))
	if is_instance_valid(active_feature_panel):
		_refresh_device_color_editor_controls()
	if not phone_case_color_mode and not box_package_color_mode and not charger_color_mode:
		_refresh_back_design_boxes()
		_refresh_phone_side_buttons()


func _show_back_design_controls() -> void:
	_close_back_design_selection_popup()
	if is_instance_valid(back_box_gradient_popup):
		back_box_gradient_popup.queue_free()
		back_box_gradient_popup = null
	if is_instance_valid(gradient_direction_popup):
		gradient_direction_popup.queue_free()
		gradient_direction_popup = null
	if is_instance_valid(back_design_selection_popup):
		back_design_selection_popup.queue_free()
		back_design_selection_popup = null
		back_design_selection_scroll = null
		back_design_selection_items = null
	back_design_color_mode = false

	var panel_host := active_feature_panel.get_parent() as Control if is_instance_valid(active_feature_panel) else right_tools_content
	if not is_instance_valid(panel_host):
		panel_host = right_tools_content
	if not is_instance_valid(panel_host):
		return
	if is_instance_valid(active_feature_panel) and active_feature_panel.get_parent() == panel_host:
		panel_host.remove_child(active_feature_panel)
		active_feature_panel.queue_free()
	if panel_host == right_tools_content:
		for old_child in right_tools_content.get_children():
			old_child.queue_free()

	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 560.0 or viewport_size.x < 520.0
	var control_height := 40.0 if tight else 44.0
	var button_font_size := 12 if tight else 13

	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BackDesignControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 7 if tight else 9)
	panel_host.add_child(active_feature_panel)

	var heading := _make_label("BACK DESIGN", 16, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	# Match the Rare Camera hierarchy: mode tabs first, then selector,
	# horizontal adjustment, and the controller with Add/Remove flanking it.
	var top_controls := HBoxContainer.new()
	top_controls.name = "BackDesignTopControls"
	top_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_controls.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(top_controls)

	for mode in ["SIZE", "MOVE"]:
		var mode_button := Button.new()
		mode_button.name = "BackDesignMode%s" % mode.capitalize()
		mode_button.text = mode
		mode_button.custom_minimum_size = Vector2(0, 36 if tight else 39)
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(mode_button, button_font_size)
		_style_back_design_button(mode_button, back_design_mode == mode)
		mode_button.pressed.connect(_set_back_design_mode.bind(mode))
		top_controls.add_child(mode_button)

	var color_button := Button.new()
	color_button.name = "BackDesignColorButton"
	color_button.text = "COLOR"
	color_button.custom_minimum_size = Vector2(0, 36 if tight else 39)
	color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(color_button, button_font_size)
	_style_back_design_button(color_button, false)
	color_button.pressed.connect(_show_device_color_controls.bind(true))
	top_controls.add_child(color_button)

	back_design_selection_button = Button.new()
	back_design_selection_button.name = "BackDesignBoxSelector"
	back_design_selection_button.text = "CHOOSE RAISED BOX  ▼"
	back_design_selection_button.custom_minimum_size = Vector2(0, control_height)
	back_design_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_design_selection_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(back_design_selection_button, button_font_size)
	_style_back_design_button(back_design_selection_button, true)
	back_design_selection_button.pressed.connect(_toggle_back_design_selection_popup)
	active_feature_panel.add_child(back_design_selection_button)

	back_design_selection_popup = PanelContainer.new()
	back_design_selection_popup.name = "BackDesignCustomDropdown"
	back_design_selection_popup.visible = false
	back_design_selection_popup.z_index = 4096
	back_design_selection_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var dropdown_panel_style := StyleBoxFlat.new()
	dropdown_panel_style.bg_color = Color("#07190d")
	dropdown_panel_style.border_color = Color("#65d783")
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
	var editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
	if is_instance_valid(editor_root):
		editor_root.add_child(back_design_selection_popup)
	else:
		active_feature_panel.add_child(back_design_selection_popup)

	var rounding_section := VBoxContainer.new()
	rounding_section.name = "BackDesignRoundingSection"
	rounding_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounding_section.add_theme_constant_override("separation", 3)
	active_feature_panel.add_child(rounding_section)
	var rounding_header := HBoxContainer.new()
	rounding_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounding_section.add_child(rounding_header)
	var rounding_heading := _make_label("ROUND", 10, Color("#b9d9bf"))
	rounding_header.add_child(rounding_heading)
	back_design_border_label = _make_label("NO BOX SELECTED", 10, Color("#dce9df"))
	back_design_border_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_design_border_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounding_header.add_child(back_design_border_label)

	back_design_border_slider = HSlider.new()
	back_design_border_slider.name = "BackDesignHorizontalRoundingSlider"
	back_design_border_slider.min_value = 0.0
	back_design_border_slider.max_value = 0.45
	back_design_border_slider.step = 0.01
	back_design_border_slider.custom_minimum_size = Vector2(0, 24)
	back_design_border_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_design_border_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_back_design_slider(back_design_border_slider)
	back_design_border_slider.value_changed.connect(_on_back_design_border_changed)
	rounding_section.add_child(back_design_border_slider)

	back_design_size_label = _make_label("ADD A BOX TO BEGIN", 10, Color("#dce9df"))
	back_design_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_design_size_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	active_feature_panel.add_child(back_design_size_label)

	var pad_control_row := HBoxContainer.new()
	pad_control_row.name = "BackDesignPadWithManagement"
	pad_control_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_control_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_theme_constant_override("separation", 10 if tight else 14)
	active_feature_panel.add_child(pad_control_row)

	_make_editor_icon_button(pad_control_row, "BackDesignAddButton", "+", "Add raised box", Callable(self, "_add_back_design_box"), control_height, true)

	var pad_center := CenterContainer.new()
	pad_center.name = "BackDesignDirectionControllerCenter"
	pad_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_child(pad_center)
	var pad_shell := PanelContainer.new()
	pad_shell.name = "BackDesignDirectionController"
	pad_shell.custom_minimum_size = Vector2(204, 204) if not tight else Vector2(184, 184)
	var pad_shell_style := StyleBoxFlat.new()
	pad_shell_style.bg_color = Color("#0b2112")
	pad_shell_style.border_color = Color("#477d53")
	pad_shell_style.set_border_width_all(1)
	pad_shell_style.set_corner_radius_all(16)
	pad_shell_style.content_margin_left = 8
	pad_shell_style.content_margin_right = 8
	pad_shell_style.content_margin_top = 8
	pad_shell_style.content_margin_bottom = 8
	pad_shell.add_theme_stylebox_override("panel", pad_shell_style)
	pad_center.add_child(pad_shell)

	var pad := GridContainer.new()
	pad.name = "BackDesignDirectionPad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 18 if not tight else 16)
	pad.add_theme_constant_override("v_separation", 6)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad_shell.add_child(pad)
	_add_back_design_pad_spacer(pad)
	var shrinking := back_design_mode == "SIZE" and back_design_size_action == "SHRINK"
	_add_back_design_pad_button(pad, "↑" if not shrinking else "↓", Vector2i(0, 1))
	_add_back_design_pad_spacer(pad)
	_add_back_design_pad_button(pad, "←" if not shrinking else "→", Vector2i(-1, 0))
	var size_action_button := Button.new()
	size_action_button.name = "BackDesignSizeActionButton"
	size_action_button.text = ("EXPAND" if back_design_size_action == "EXPAND" else "SHRINK") if back_design_mode == "SIZE" else "MOVE"
	size_action_button.custom_minimum_size = Vector2(76, 42)
	size_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_research_typography(size_action_button, 10 if tight else 11)
	_style_back_design_button(size_action_button, true)
	if back_design_mode == "SIZE":
		size_action_button.pressed.connect(_toggle_back_design_size_action)
	else:
		size_action_button.pressed.connect(_set_back_design_mode.bind("MOVE"))
	pad.add_child(size_action_button)
	_add_back_design_pad_button(pad, "→" if not shrinking else "←", Vector2i(1, 0))
	_add_back_design_pad_spacer(pad)
	_add_back_design_pad_button(pad, "↓" if not shrinking else "↑", Vector2i(0, -1))
	_add_back_design_pad_spacer(pad)

	_make_editor_icon_button(pad_control_row, "BackDesignRemoveButton", "−", "Remove selected box", Callable(self, "_remove_selected_back_design_box"), control_height, false)
	_refresh_back_design_panel()


func _apply_worksite_back_hardware_panel_layout() -> void:
	# Raised Back Design now owns its complete layout in its builder. This
	# worksite hook remains only to clean up any legacy rear-hardware spacer.
	if not worksite_creation_mode or not is_instance_valid(active_feature_panel):
		return
	if active_feature_panel.name == "BackDesignControls":
		return
	var rear_spacer := active_feature_panel.find_child("RearHardwareControllerFlexSpace", true, false) as Control
	if is_instance_valid(rear_spacer):
		var spacer_parent := rear_spacer.get_parent()
		if is_instance_valid(spacer_parent):
			spacer_parent.remove_child(rear_spacer)
		rear_spacer.queue_free()


func _make_editor_icon_button(parent: Control, node_name: String, caption: String, tooltip: String, pressed_callback: Callable, diameter: float, active: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(button, 19 if diameter >= 44.0 else 17)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#174326") if active else Color("#102b19")
		if state == "hover":
			style.bg_color = Color("#205632")
		elif state == "pressed":
			style.bg_color = Color("#2d7040")
		elif state == "disabled":
			style.bg_color = Color("#17251a")
		style.border_color = Color("#75b983") if active else Color("#4e8058")
		style.set_border_width_all(1)
		style.set_corner_radius_all(int(diameter * 0.5))
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#e5f4e7"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#91aa95"))
	button.pressed.connect(pressed_callback)
	parent.add_child(button)
	return button




func _make_editor_control_card(parent: Control, card_name: String, heading_text: String, tight: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = card_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#0d1710")
	panel_style.border_color = Color("#263e2b")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10 if tight else 12
	panel_style.content_margin_bottom = 10 if tight else 12
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7 if tight else 9)
	panel.add_child(content)

	var heading := _make_label(heading_text, 11 if tight else 12, Color("#a8cfad"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(heading)
	return content


func _add_back_design_flexible_space(parent: Control) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func _toggle_back_design_selection_popup() -> void:
	if not is_instance_valid(back_design_selection_popup):
		return
	if back_design_boxes.is_empty():
		_rebuild_back_design_selection_popup()
		return
	_rebuild_back_design_selection_popup()
	back_design_selection_popup.visible = not back_design_selection_popup.visible
	if back_design_selection_popup.visible:
		back_design_selection_popup.move_to_front()
		call_deferred("_position_back_design_selection_popup")


func _close_back_design_selection_popup() -> void:
	if is_instance_valid(back_design_selection_popup):
		back_design_selection_popup.visible = false


func _position_back_design_selection_popup() -> void:
	if not is_instance_valid(back_design_selection_popup) or not is_instance_valid(back_design_selection_button):
		return
	if not back_design_selection_popup.visible:
		return
	var popup_parent := back_design_selection_popup.get_parent() as Control
	if not is_instance_valid(popup_parent):
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var button_rect := back_design_selection_button.get_global_rect()
	var viewport_padding := 8.0
	var side_gap := 6.0
	var viewport_size := viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var popup_width := clampf(button_rect.size.x, 160.0, viewport_size.x - viewport_padding * 2.0)
	var content_height := back_design_selection_items.get_combined_minimum_size().y + 20.0 if is_instance_valid(back_design_selection_items) else 80.0
	var desired_height := minf(maxf(content_height, 80.0), viewport_size.y * 0.48)
	var available_above := maxf(0.0, button_rect.position.y - viewport_rect.position.y - side_gap - viewport_padding)
	var button_bottom := button_rect.position.y + button_rect.size.y
	var available_below := maxf(0.0, viewport_rect.end.y - button_bottom - side_gap - viewport_padding)
	var open_below := available_below >= desired_height or available_below >= available_above
	# Never silently close the selector because the worksite's scroll position
	# leaves little room. Use a compact overlay and clamp it inside the viewport.
	var popup_height := minf(desired_height, maxf(80.0, viewport_size.y - viewport_padding * 2.0))
	back_design_selection_popup.custom_minimum_size = Vector2(popup_width, popup_height)
	back_design_selection_popup.size = Vector2(popup_width, popup_height)
	if is_instance_valid(back_design_selection_scroll):
		back_design_selection_scroll.custom_minimum_size = Vector2(0.0, maxf(48.0, popup_height - 20.0))
	var popup_y := button_bottom + side_gap if open_below else button_rect.position.y - popup_height - side_gap
	popup_y = clampf(popup_y, viewport_rect.position.y + viewport_padding, viewport_rect.end.y - popup_height - viewport_padding)
	var max_popup_x := viewport_rect.end.x - popup_width - viewport_padding
	var popup_x := clampf(button_rect.position.x, viewport_rect.position.x + viewport_padding, max_popup_x)
	# Convert viewport/global coordinates into the actual popup parent's
	# local space. This works for both the worksite panel and legacy editor.
	back_design_selection_popup.position = popup_parent.to_local(Vector2(popup_x, popup_y))
	back_design_selection_popup.move_to_front()

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
		for state in ["normal", "hover", "pressed", "focus"]:
			var option_style := StyleBoxFlat.new()
			option_style.bg_color = Color("#12351c") if state != "pressed" else Color("#285c35")
			if state == "hover":
				option_style.bg_color = Color("#1c4728")
			option_style.border_color = Color("#4d8d5b")
			option_style.set_border_width_all(1)
			option_style.set_corner_radius_all(8)
			option_style.content_margin_left = 14
			item.add_theme_stylebox_override(state, option_style)
		item.add_theme_color_override("font_color", Color("#e5f4e7"))
		item.add_theme_color_override("font_hover_color", Color("#ffffff"))
		item.add_theme_color_override("font_pressed_color", Color("#ffffff"))
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


func _style_back_design_button(button: Button, active: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#174326") if active else Color("#102b19")
		if state == "hover":
			style.bg_color = Color("#205632")
		elif state == "pressed":
			style.bg_color = Color("#2d7040")
		elif state == "disabled":
			style.bg_color = Color("#17251a")
		style.border_color = Color("#5c9b69") if active else Color("#3e7049")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#e5f4e7"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#91aa95"))


func _style_back_design_slider(slider: Slider) -> void:
	_style_custom_slider(slider)


func _add_back_design_pad_spacer(parent: GridContainer) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 560.0 or viewport_size.x < 520.0
	var diameter := 64.0 if tight else 72.0
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(diameter, diameter)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func _add_back_design_pad_button(parent: GridContainer, caption: String, direction: Vector2i) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 620.0 or viewport_size.x < 600.0
	_add_editor_direction_pad_button(parent, caption, direction, tight, Callable(self, "_on_back_design_pad_pressed"))


func _add_editor_direction_pad_button(parent: GridContainer, caption: String, direction: Vector2i, tight: bool, pressed_callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	var diameter := 64.0 if tight else 72.0
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_research_typography(button, 29 if not tight else 27)
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var circle_style := StyleBoxFlat.new()
		circle_style.bg_color = Color("#173c22")
		if state == "hover":
			circle_style.bg_color = Color("#205632")
		elif state == "pressed":
			circle_style.bg_color = Color("#285c35")
		elif state == "disabled":
			circle_style.bg_color = Color("#17251a")
		circle_style.border_color = Color("#75b983")
		circle_style.set_border_width_all(1)
		circle_style.set_corner_radius_all(int(diameter * 0.5))
		circle_style.content_margin_left = 0
		circle_style.content_margin_right = 0
		circle_style.content_margin_top = 0
		circle_style.content_margin_bottom = 0
		button.add_theme_stylebox_override(state, circle_style)
	button.add_theme_color_override("font_color", Color("#eff8f0"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.pressed.connect(pressed_callback.bind(direction))
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
	var body_half := Vector2(_active_phone_size().x * 0.5, _active_phone_size().y * 0.5)
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
				back_design_boxes.append({"id": next_back_design_box_id, "position": box_position, "size": box_size, "border": 0.08, "use_device_color": not worksite_creation_mode, "custom_color": device_body_color, "gradient_color": device_gradient_color, "gradient_enabled": back_design_gradient_enabled_without_box if worksite_creation_mode else false, "gradient_direction": device_gradient_direction})
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
	if absf(box_position.x) + half.x > _active_phone_size().x * 0.5: return false
	if absf(box_position.y) + half.y > _active_phone_size().y * 0.5: return false
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
	_restore_foldable_accessories_from_group("BackDesignRaisedSections")
	var old_root := phone_body.get_node_or_null("BackDesignRaisedSections")
	if is_instance_valid(old_root): old_root.free()
	if back_design_boxes.is_empty():
		_refresh_rear_hardware_visuals()
		_route_foldable_accessories()
		return
	var root := Node3D.new()
	root.name = "BackDesignRaisedSections"
	phone_body.add_child(root)
	var phone_depth := _phone_depth_for_thickness_level()
	for index in range(back_design_boxes.size()):
		var box: Dictionary = back_design_boxes[index]
		var size: Vector2 = box["size"]
		var raised := MeshInstance3D.new()
		raised.name = "RaisedBackBox_%d" % int(box["id"])
		raised.mesh = _make_back_design_mesh(size, minf(size.x, size.y) * float(box["border"]), 0.035 / 1.10 / 1.5)
		var material := StandardMaterial3D.new()
		var box_uses_device_color := bool(box.get("use_device_color", not worksite_creation_mode))
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
	_route_foldable_accessories()

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

	var title := _make_label("SCREEN SIZE", 18, Color("#c7eacb"))
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
	width_slider.custom_minimum_size = Vector2(64, 320)
	width_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	width_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	width_slider.value_changed.connect(_on_bezel_width_changed)
	_style_custom_slider(width_slider)
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
	bezel_height_slider.custom_minimum_size = Vector2(64, 320)
	bezel_height_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bezel_height_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bezel_height_slider.value_changed.connect(_on_bezel_height_changed)
	_style_custom_slider(bezel_height_slider)
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
	# _active_phone_size() maps to an approximately 75 mm-wide handset.
	const MODEL_UNITS_TO_MM := 75.0 / 1.45
	if is_instance_valid(bezel_width_value_label):
		bezel_width_value_label.text = "%.1f mm" % ((_active_phone_size().x - bezel_width * 2.0) * MODEL_UNITS_TO_MM)
	if is_instance_valid(bezel_height_value_label):
		bezel_height_value_label.text = "%.1f mm" % ((_active_phone_size().y - bezel_height * 2.0) * MODEL_UNITS_TO_MM)


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

	var title := _make_label("SCREEN TYPE", 18, Color("#c7eacb"))
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


func _add_screen_enablement_row(parent: Control, row_name: String, toggle_name: String, label_text: String, enabled: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)

	var toggle := Button.new()
	toggle.name = toggle_name
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.text = "✓" if enabled else ""
	toggle.custom_minimum_size = Vector2(34, 34)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(toggle, 17)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#174b28") if state != "hover" else Color("#205d37")
		if state == "pressed" or state == "focus":
			style.bg_color = Color("#168343")
		style.border_color = Color("#8fd8a1")
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		toggle.add_theme_stylebox_override(state, style)
	toggle.add_theme_color_override("font_color", Color.WHITE)
	toggle.toggled.connect(callback)
	row.add_child(toggle)

	var label := _make_label(label_text, 14, Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)


func _show_screen_tech_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ScreenTechControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var title := _make_label("SCREEN TECHNOLOGY", 18, Color("#c7eacb"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)

	_add_screen_enablement_row(active_feature_panel, "ScreenEnablementRow", "ScreenEnablement", "Enable Screen", screen_enabled, Callable(self, "_on_screen_enablement_toggled"))

	var type_grid := GridContainer.new()
	type_grid.name = "ScreenTypeOptions"
	type_grid.columns = 2
	type_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_grid.add_theme_constant_override("h_separation", 8)
	type_grid.add_theme_constant_override("v_separation", 6)
	active_feature_panel.add_child(type_grid)

	screen_type_buttons.clear()
	for index in range(SCREEN_TYPE_ORDER.size()):
		var type_name: String = SCREEN_TYPE_ORDER[index]
		var option := Button.new()
		option.name = "ScreenType_" + type_name.replace(" ", "").replace("-", "")
		option.text = "%02d   %s" % [index + 1, type_name]
		option.custom_minimum_size = Vector2(0, 50.0)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		var screen_font := FontVariation.new()
		screen_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		screen_font.variation_embolden = 1.5
		option.add_theme_font_override("font", screen_font)
		option.add_theme_font_size_override("font_size", 17)
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


func _style_screen_type_option(option: Button, _rank: int, selected: bool) -> void:
	# Match the worksite's dark translucent glass buttons and green brand rim.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.075, 0.16, 0.095, 0.88) if selected else Color(0.12, 0.15, 0.13, 0.76)
		if state == "hover":
			style.bg_color = Color(0.12, 0.25, 0.15, 0.94) if selected else Color(0.19, 0.23, 0.20, 0.88)
		elif state == "pressed":
			style.bg_color = Color(0.055, 0.12, 0.07, 0.98) if selected else Color(0.08, 0.11, 0.09, 0.94)
		elif state == "disabled":
			style.bg_color = Color(0.10, 0.13, 0.11, 0.58)
		style.border_color = Color(0.68, 0.91, 0.73, 0.78) if selected else Color(0.78, 0.85, 0.80, 0.34)
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(12)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		style.shadow_size = 9 if selected else 7
		style.shadow_offset = Vector2(0, 3)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.anti_aliasing = true
		option.add_theme_stylebox_override(state, style)
	option.add_theme_color_override("font_color", Color("#ffffff") if selected else Color("#e5eee7"))
	option.add_theme_color_override("font_hover_color", Color("#ffffff"))
	option.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	option.add_theme_color_override("font_disabled_color", Color("#7c897f"))
	var reflection := option.get_node_or_null("ScreenTechGlassReflection") as ScreenTechGlassReflection
	if not is_instance_valid(reflection):
		reflection = ScreenTechGlassReflection.new()
		reflection.name = "ScreenTechGlassReflection"
		option.add_child(reflection)
	reflection.accent = Color("#9bd6a7") if selected else Color("#c5d0c8")
	reflection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reflection.queue_redraw()


func _refresh_screen_type_buttons() -> void:
	for index in range(SCREEN_TYPE_ORDER.size()):
		var type_name: String = SCREEN_TYPE_ORDER[index]
		if not screen_type_buttons.has(type_name):
			continue
		var option: Button = screen_type_buttons[type_name]
		if not is_instance_valid(option):
			continue
		_style_screen_type_option(option, index, type_name == selected_screen_type)
		option.disabled = not screen_enabled


func _create_rounded_panel_mesh(width: float, height: float, depth: float, corner_radius: float, corner_mask: int = 15) -> Mesh:
	# A true rounded-rectangle extrusion keeps the glass and button outlines
	# smooth. Foldable halves pass a corner mask so only the four corners on
	# the complete device perimeter are rounded; hinge-side corners stay square.
	var half_width := width * 0.5
	var half_height := height * 0.5
	var radius := clampf(corner_radius, 0.001, minf(half_width, half_height))
	var corner_points := [
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height),
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height)
	]
	var outline := PackedVector2Array()
	var rounded_outline_points: Array[bool] = []
	const CORNER_SEGMENTS := 24
	for corner_index in range(4):
		var corner_point: Vector2 = corner_points[corner_index]
		var should_round := (corner_mask & (1 << corner_index)) != 0 and radius > 0.0001
		if should_round:
			var center := Vector2(
				signf(corner_point.x) * (half_width - radius),
				signf(corner_point.y) * (half_height - radius)
			)
			var start_angle := float(corner_index) * PI * 0.5
			for segment in range(CORNER_SEGMENTS + 1):
				var angle := start_angle + float(segment) / float(CORNER_SEGMENTS) * PI * 0.5
				outline.append(center + Vector2(cos(angle), sin(angle)) * radius)
				rounded_outline_points.append(true)
		else:
			outline.append(corner_point)
			rounded_outline_points.append(false)

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
		var normal_a := side_normal
		var normal_b := side_normal
		if rounded_outline_points[index]:
			var previous_a: Vector2 = outline[(index - 1 + outline.size()) % outline.size()]
			var previous_edge := a - previous_a
			var previous_normal := Vector3(previous_edge.y, -previous_edge.x, 0.0).normalized()
			normal_a = (previous_normal + side_normal).normalized()
		if rounded_outline_points[next_index]:
			var next_b: Vector2 = outline[(next_index + 1) % outline.size()]
			var next_edge := next_b - b
			var next_normal := Vector3(next_edge.y, -next_edge.x, 0.0).normalized()
			normal_b = (side_normal + next_normal).normalized()
		var front_a := Vector3(a.x, a.y, front_z)
		var front_b := Vector3(b.x, b.y, front_z)
		var back_a := Vector3(a.x, a.y, back_z)
		var back_b := Vector3(b.x, b.y, back_z)
		_add_phone_mesh_triangle_with_normals(surface, front_a, back_a, back_b, normal_a, normal_a, normal_b)
		_add_phone_mesh_triangle_with_normals(surface, front_a, back_b, front_b, normal_a, normal_b, normal_b)
	return surface.commit()

func _create_curved_screen_mesh(width: float, height: float, corner_radius: float, curve_sides: bool, curve_vertical: bool, curve_left: bool = true, curve_right: bool = true, curve_top: bool = true, curve_bottom: bool = true, corner_mask: int = 15) -> ArrayMesh:
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
			var corner_index := 0 if raw_x > 0.0 and raw_y > 0.0 else 1 if raw_x < 0.0 and raw_y > 0.0 else 2 if raw_x < 0.0 and raw_y < 0.0 else 3
			if radius > 0.0001 and (corner_mask & (1 << corner_index)) != 0 and absf(raw_x) > corner_x and absf(raw_y) > corner_y:
				var corner_center := Vector2(signf(raw_x) * corner_x, signf(raw_y) * corner_y)
				var corner_offset := Vector2(raw_x, raw_y) - corner_center
				if corner_offset.length_squared() > radius * radius:
					corner_offset = corner_offset.normalized() * radius
					x = corner_center.x + corner_offset.x
					y = corner_center.y + corner_offset.y
			var side_drop := 0.0
			var vertical_drop := 0.0
			if curve_sides:
				if curve_left and x < 0.0:
					side_drop = maxf(side_drop, SIDE_BEND * pow(absf(x / maxf(half_width, 0.001)), 6.0))
				if curve_right and x > 0.0:
					side_drop = maxf(side_drop, SIDE_BEND * pow(absf(x / maxf(half_width, 0.001)), 6.0))
			if curve_vertical:
				if curve_top and y > 0.0:
					vertical_drop = maxf(vertical_drop, VERTICAL_BEND * pow(absf(y / maxf(half_height, 0.001)), 6.0))
				if curve_bottom and y < 0.0:
					vertical_drop = maxf(vertical_drop, VERTICAL_BEND * pow(absf(y / maxf(half_height, 0.001)), 6.0))
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


func _get_screen_protector_cutouts(screen_width: float, screen_height: float) -> Array[Dictionary]:
	var cutouts: Array[Dictionary] = []
	if not front_camera_enabled:
		return cutouts

	var top_edge := screen_height * 0.5
	var top_inset := clampf(screen_height * 0.035, 0.055, 0.095)
	var camera_y := top_edge - top_inset
	match front_camera_style:
		"Waterdrop Notch":
			cutouts.append({
				"shape": "rounded_rect",
				"center": Vector2(0.0, camera_y),
				"size": Vector2(0.198, 0.113),
				"radius": 0.052
			})
		"Punch-Hole":
			cutouts.append({"shape": "circle", "center": Vector2(0.0, camera_y), "radius": 0.044})
		"Side Punch-Hole":
			var side_camera_x := -screen_width * (0.40 if border_radius_level == 0 else 0.36)
			var side_camera_y := _side_camera_safe_y(camera_y)
			cutouts.append({"shape": "circle", "center": Vector2(side_camera_x, side_camera_y), "radius": 0.043})
		"Dual Punch-Hole":
			var dual_spacing := 0.052
			cutouts.append({"shape": "circle", "center": Vector2(-dual_spacing, camera_y), "radius": 0.036})
			cutouts.append({"shape": "circle", "center": Vector2(dual_spacing, camera_y), "radius": 0.036})
		"Dynamic Island":
			var island_height := 0.113
			var island_width := minf(0.368, screen_width * 0.34 + 0.008)
			var island_y := top_edge - top_inset
			cutouts.append({
				"shape": "rounded_rect",
				"center": Vector2(0.0, island_y),
				"size": Vector2(island_width, island_height),
				"radius": island_height * 0.5
			})
		# Bezel and pop-up cameras sit outside the display. Under-display
		# cameras need no physical protector opening.
	return cutouts


func _screen_protector_point_is_cut_out(point: Vector2, cutouts: Array[Dictionary]) -> bool:
	for cutout in cutouts:
		var centre: Vector2 = cutout["center"]
		if str(cutout["shape"]) == "circle":
			var circle_radius := float(cutout["radius"])
			if point.distance_squared_to(centre) <= circle_radius * circle_radius:
				return true
		else:
			var size: Vector2 = cutout["size"]
			var corner_radius := float(cutout["radius"])
			var delta := (point - centre).abs()
			var corner_delta := Vector2(maxf(delta.x - size.x * 0.5 + corner_radius, 0.0), maxf(delta.y - size.y * 0.5 + corner_radius, 0.0))
			if corner_delta.length_squared() <= corner_radius * corner_radius:
				return true
	return false


func _screen_protector_surface_point(raw_x: float, raw_y: float, width: float, height: float, radius: float, curve_sides: bool, curve_vertical: bool, thickness: float, corner_mask: int = 15, curve_left: bool = true, curve_right: bool = true, curve_top: bool = true, curve_bottom: bool = true) -> Vector3:
	var half_width := width * 0.5
	var half_height := height * 0.5
	var x := raw_x
	var y := raw_y
	var corner_x := half_width - radius
	var corner_y := half_height - radius
	var in_top_right := raw_x > corner_x and raw_y > corner_y and (corner_mask & 1) != 0
	var in_top_left := raw_x < -corner_x and raw_y > corner_y and (corner_mask & 2) != 0
	var in_bottom_left := raw_x < -corner_x and raw_y < -corner_y and (corner_mask & 4) != 0
	var in_bottom_right := raw_x > corner_x and raw_y < -corner_y and (corner_mask & 8) != 0
	var should_round := radius > 0.0001 and (in_top_right or in_top_left or in_bottom_left or in_bottom_right)
	if should_round:
		var corner_center := Vector2(signf(raw_x) * corner_x, signf(raw_y) * corner_y)
		var corner_offset := Vector2(raw_x, raw_y) - corner_center
		if corner_offset.length_squared() > radius * radius:
			corner_offset = corner_offset.normalized() * radius
			x = corner_center.x + corner_offset.x
			y = corner_center.y + corner_offset.y
	var side_drop := 0.0
	var vertical_drop := 0.0
	if curve_sides:
		if curve_left and x < 0.0:
			side_drop = maxf(side_drop, 0.028 * pow(absf(x / maxf(half_width, 0.001)), 6.0))
		if curve_right and x > 0.0:
			side_drop = maxf(side_drop, 0.028 * pow(absf(x / maxf(half_width, 0.001)), 6.0))
	if curve_vertical:
		if curve_top and y > 0.0:
			vertical_drop = maxf(vertical_drop, 0.028 * pow(absf(y / maxf(half_height, 0.001)), 6.0))
		if curve_bottom and y < 0.0:
			vertical_drop = maxf(vertical_drop, 0.028 * pow(absf(y / maxf(half_height, 0.001)), 6.0))
	var surface_z := -maxf(side_drop, vertical_drop)
	if not curve_sides and not curve_vertical:
		# The flat display is a 0.006-unit panel; its front face is at +0.003.
		surface_z = 0.003
	return Vector3(x, y, surface_z + thickness)

func _add_screen_protector_edge(surface: SurfaceTool, base_a: Vector3, base_b: Vector3, top_a: Vector3, top_b: Vector3, outward_normal: Vector3) -> void:
	# Build the clear-glass sidewall between the fitted underside and polished top.
	_add_phone_mesh_triangle(surface, base_a, top_a, top_b, outward_normal)
	_add_phone_mesh_triangle(surface, base_a, top_b, base_b, outward_normal)


func _create_screen_protector_mesh_async(width: float, height: float, corner_radius: float, curve_sides: bool, curve_vertical: bool, cutouts: Array[Dictionary], thickness: float, corner_mask: int = 15, curve_left: bool = true, curve_right: bool = true, curve_top: bool = true, curve_bottom: bool = true) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The dense grid follows the exact screen outline and curve. The top and
	# underside are separated by the real modelled protector thickness.
	const X_SEGMENTS := 88
	const Y_SEGMENTS := 148
	const EDGE_GAP := 0.00025
	var half_width := width * 0.5
	var half_height := height * 0.5
	var radius := clampf(corner_radius, 0.0, minf(half_width, half_height))
	var base_points: Array[Vector3] = []
	var top_points: Array[Vector3] = []
	for y_index in range(Y_SEGMENTS + 1):
		var v := float(y_index) / float(Y_SEGMENTS)
		var raw_y := (0.5 - v) * height
		for x_index in range(X_SEGMENTS + 1):
			var u := float(x_index) / float(X_SEGMENTS)
			var raw_x := (u - 0.5) * width
			base_points.append(_screen_protector_surface_point(raw_x, raw_y, width, height, radius, curve_sides, curve_vertical, EDGE_GAP, corner_mask, curve_left, curve_right, curve_top, curve_bottom))
			top_points.append(_screen_protector_surface_point(raw_x, raw_y, width, height, radius, curve_sides, curve_vertical, EDGE_GAP + thickness, corner_mask, curve_left, curve_right, curve_top, curve_bottom))
		if y_index % 8 == 7:
			await get_tree().process_frame

	var cutout_mask := PackedByteArray()
	cutout_mask.resize(X_SEGMENTS * Y_SEGMENTS)
	for y_index in range(Y_SEGMENTS):
		for x_index in range(X_SEGMENTS):
			var top_left := y_index * (X_SEGMENTS + 1) + x_index
			var top_right := top_left + 1
			var bottom_left := top_left + X_SEGMENTS + 1
			var bottom_right := bottom_left + 1
			var cell_center := Vector2(
				(top_points[top_left].x + top_points[top_right].x + top_points[bottom_left].x + top_points[bottom_right].x) * 0.25,
				(top_points[top_left].y + top_points[top_right].y + top_points[bottom_left].y + top_points[bottom_right].y) * 0.25
			)
			var cell_index := y_index * X_SEGMENTS + x_index
			if _screen_protector_point_is_cut_out(cell_center, cutouts):
				cutout_mask[cell_index] = 1
				continue
			surface.add_vertex(top_points[top_left])
			surface.add_vertex(top_points[bottom_left])
			surface.add_vertex(top_points[top_right])
			surface.add_vertex(top_points[top_right])
			surface.add_vertex(top_points[bottom_left])
			surface.add_vertex(top_points[bottom_right])
		if y_index % 8 == 7:
			await get_tree().process_frame

	# Close the outer glass perimeter so the thickness is visible edge-on.
	for x_index in range(X_SEGMENTS):
		var top_left := x_index
		var top_right := top_left + 1
		_add_screen_protector_edge(surface, base_points[top_left], base_points[top_right], top_points[top_left], top_points[top_right], Vector3.UP)
		var bottom_left := Y_SEGMENTS * (X_SEGMENTS + 1) + x_index
		var bottom_right := bottom_left + 1
		_add_screen_protector_edge(surface, base_points[bottom_right], base_points[bottom_left], top_points[bottom_right], top_points[bottom_left], Vector3.DOWN)
	for y_index in range(Y_SEGMENTS):
		var left_top := y_index * (X_SEGMENTS + 1)
		var left_bottom := left_top + X_SEGMENTS + 1
		_add_screen_protector_edge(surface, base_points[left_bottom], base_points[left_top], top_points[left_bottom], top_points[left_top], Vector3.LEFT)
		var right_top := y_index * (X_SEGMENTS + 1) + X_SEGMENTS
		var right_bottom := right_top + X_SEGMENTS + 1
		_add_screen_protector_edge(surface, base_points[right_top], base_points[right_bottom], top_points[right_top], top_points[right_bottom], Vector3.RIGHT)

	# Add the inner cut walls around each camera/sensor opening.
	for y_index in range(Y_SEGMENTS):
		for x_index in range(X_SEGMENTS):
			var cell_index := y_index * X_SEGMENTS + x_index
			if cutout_mask[cell_index] == 0:
				continue
			var row_start := y_index * (X_SEGMENTS + 1)
			var row_below := row_start + X_SEGMENTS + 1
			if x_index > 0 and cutout_mask[cell_index - 1] == 0:
				_add_screen_protector_edge(surface, base_points[row_start + x_index], base_points[row_below + x_index], top_points[row_start + x_index], top_points[row_below + x_index], Vector3.RIGHT)
			if x_index < X_SEGMENTS - 1 and cutout_mask[cell_index + 1] == 0:
				_add_screen_protector_edge(surface, base_points[row_below + x_index + 1], base_points[row_start + x_index + 1], top_points[row_below + x_index + 1], top_points[row_start + x_index + 1], Vector3.LEFT)
			if y_index > 0 and cutout_mask[cell_index - X_SEGMENTS] == 0:
				_add_screen_protector_edge(surface, base_points[row_start + x_index + 1], base_points[row_start + x_index], top_points[row_start + x_index + 1], top_points[row_start + x_index], Vector3.DOWN)
			if y_index < Y_SEGMENTS - 1 and cutout_mask[cell_index + X_SEGMENTS] == 0:
				_add_screen_protector_edge(surface, base_points[row_below + x_index], base_points[row_below + x_index + 1], top_points[row_below + x_index], top_points[row_below + x_index + 1], Vector3.UP)

	surface.index()
	surface.generate_normals()
	return surface.commit()

func _create_screen_protector_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.94, 0.98, 1.0, 0.055)
	material.metallic = 0.0
	material.roughness = 0.12
	material.metallic_specular = 0.22
	material.clearcoat_enabled = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	match screen_protector_finish:
		"Matte":
			material.albedo_color = Color(0.83, 0.91, 0.97, 0.10)
			material.roughness = 0.78
			material.metallic_specular = 0.08
			material.clearcoat_enabled = false
		"Anti-Reflective":
			material.albedo_color = Color(0.90, 0.96, 1.0, 0.045)
			material.roughness = 0.62
			material.metallic_specular = 0.035
			material.metallic = 0.0
			material.clearcoat_enabled = false
		_:
			material.roughness = 0.12
			material.metallic_specular = 0.22
	return material


func _build_screen_protector(display: MeshInstance3D, screen_width: float, screen_height: float, screen_radius: float, curved_display: bool, shared_token: int = -1, include_camera_cutouts: bool = true, corner_mask: int = 15, curve_left: bool = true, curve_right: bool = true, curve_top: bool = true, curve_bottom: bool = true) -> void:
	if not screen_protector_enabled or not is_instance_valid(display):
		return
	if shared_token < 0:
		screen_protector_build_token += 1
		shared_token = screen_protector_build_token
	screen_protector_building = true
	var token := shared_token
	var placeholder := MeshInstance3D.new()
	placeholder.name = "TemperedGlassBuildPreview"
	placeholder.mesh = _create_rounded_panel_mesh(screen_width, screen_height, 0.002, screen_radius, corner_mask)
	var preview_material := StandardMaterial3D.new()
	preview_material.albedo_color = Color(0.45, 0.78, 0.96, 0.10)
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.roughness = 0.8
	preview_material.metallic_specular = 0.04
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	placeholder.material_override = preview_material
	placeholder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.add_child(placeholder)
	var build_tween := create_tween()
	active_screen_protector_build_tweens.append(build_tween)
	build_tween.set_loops()
	build_tween.tween_property(placeholder, "scale", Vector3(1.0, 0.985, 1.0), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	build_tween.tween_property(placeholder, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	call_deferred("_build_screen_protector_async", display, screen_width, screen_height, screen_radius, curved_display, token, placeholder, build_tween, include_camera_cutouts, corner_mask, curve_left, curve_right, curve_top, curve_bottom)


func _build_screen_protector_async(display: MeshInstance3D, screen_width: float, screen_height: float, screen_radius: float, curved_display: bool, token: int, placeholder: MeshInstance3D, build_tween: Tween, include_camera_cutouts: bool = true, corner_mask: int = 15, curve_left: bool = true, curve_right: bool = true, curve_top: bool = true, curve_bottom: bool = true) -> void:
	var curve_sides := curved_display and side_curve_enabled
	var curve_vertical := curved_display and vertical_curve_enabled
	var cutouts := _get_screen_protector_cutouts(screen_width, screen_height) if include_camera_cutouts else []
	var generated_mesh: ArrayMesh = await _create_screen_protector_mesh_async(screen_width, screen_height, screen_radius, curve_sides, curve_vertical, cutouts, screen_protector_thickness, corner_mask, curve_left, curve_right, curve_top, curve_bottom)
	if token != screen_protector_build_token or not screen_protector_enabled or not is_instance_valid(display):
		if is_instance_valid(build_tween) and build_tween.is_valid():
			build_tween.kill()
		active_screen_protector_build_tweens.erase(build_tween)
		if is_instance_valid(placeholder):
			placeholder.queue_free()
		return
	if is_instance_valid(build_tween) and build_tween.is_valid():
		build_tween.kill()
	active_screen_protector_build_tweens.erase(build_tween)
	if is_instance_valid(placeholder):
		placeholder.queue_free()
	var protector := MeshInstance3D.new()
	protector.name = "TemperedGlassScreenProtector"
	protector.mesh = generated_mesh
	protector.material_override = _create_screen_protector_material()
	protector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	protector.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	display.add_child(protector)
	screen_protector_building = false
	_show_screen_protector_controls()


func _on_screen_protector_toggled(enabled: bool) -> void:
	screen_protector_enabled = enabled
	screen_protector_build_token += 1
	screen_protector_building = enabled
	_refresh_phone_screen()
	_show_screen_protector_controls()


func _on_screen_protector_finish_selected(finish_name: String) -> void:
	if not ["Ultra Clear", "Matte", "Anti-Reflective"].has(finish_name):
		return
	screen_protector_finish = finish_name
	_refresh_phone_screen()
	_show_screen_protector_controls()


func _on_screen_protector_thickness_changed(value: float) -> void:
	screen_protector_thickness = clampf(value, 0.003, 0.009)
	_update_screen_protector_thickness_label()
	_refresh_phone_screen()


func _update_screen_protector_thickness_label() -> void:
	if is_instance_valid(screen_protector_thickness_label):
		var thickness_mm := screen_protector_thickness * 75.0 / _active_phone_size().x
		screen_protector_thickness_label.text = "GLASS THICKNESS  %.2f mm" % thickness_mm


func _rebuild_smartwatch_preview() -> void:
	if not is_instance_valid(smartwatch_preview):
		return
	for child in smartwatch_preview.get_children():
		child.free()

	# Premium smartwatch CMF: anodised metal shell, a separate polished
	# display lip, deep OLED glass and a soft-touch elastomer strap.
	var case_material := _charger_material(smartwatch_body_color, 0.68, 0.27)
	var bezel_material := _charger_material(smartwatch_body_color.lightened(0.075), 0.82, 0.20)
	var case_shadow_material := _charger_material(smartwatch_body_color.darkened(0.28), 0.72, 0.31)
	var strap_material := _charger_material(smartwatch_body_color.darkened(0.035), 0.0, 0.76)
	var glass_material := _charger_material(Color("#03070c"), 0.08, 0.065)
	var screen_material := _charger_material(Color("#050b13"), 0.04, 0.10)
	var steel_material := _charger_material(Color("#b9c4ce"), 0.91, 0.22)
	var dark_steel_material := _charger_material(Color("#48535e"), 0.86, 0.30)
	var accent_material := _charger_material(Color("#65d7c4"), 0.28, 0.22)

	# Main case and the very small step that separates the metal chassis from
	# the glass. The screen is intentionally almost edge-to-edge.
	var case := MeshInstance3D.new()
	case.name = "SmartwatchAnodisedCase"
	case.mesh = _create_rounded_panel_mesh(0.88, 1.06, 0.235, 0.225)
	case.material_override = case_material
	smartwatch_preview.add_child(case)

	var case_midframe := MeshInstance3D.new()
	case_midframe.name = "SmartwatchCaseMidframe"
	case_midframe.mesh = _create_rounded_panel_mesh(0.884, 1.045, 0.055, 0.215)
	case_midframe.position.z = -0.012
	case_midframe.material_override = case_shadow_material
	smartwatch_preview.add_child(case_midframe)

	var display_lip := MeshInstance3D.new()
	display_lip.name = "PrecisionMachinedDisplayLip"
	display_lip.mesh = _create_rounded_panel_mesh(0.825, 1.005, 0.024, 0.195)
	display_lip.position.z = 0.122
	display_lip.material_override = bezel_material
	smartwatch_preview.add_child(display_lip)

	var glass := MeshInstance3D.new()
	glass.name = "EdgeToEdgeOLEDGlass"
	glass.mesh = _create_rounded_panel_mesh(0.795, 0.972, 0.012, 0.183)
	glass.position.z = 0.141
	glass.material_override = glass_material
	smartwatch_preview.add_child(glass)

	var screen := MeshInstance3D.new()
	screen.name = "OLEDDisplaySurface"
	screen.mesh = _create_rounded_panel_mesh(0.774, 0.951, 0.003, 0.177)
	screen.position.z = 0.149
	screen.material_override = screen_material
	smartwatch_preview.add_child(screen)

	# A restrained digital watch face replaces the oversized floating analogue
	# dial. Labels are genuine 3D text and remain part of the rotating model.
	_add_accessory_label(smartwatch_preview, "WatchFaceDate", "TUE 03", 15, 0.0040, Color("#9fb4c8"), Vector3(0.0, 0.315, 0.156))
	_add_accessory_label(smartwatch_preview, "WatchFaceTime", "10:09", 55, 0.0037, Color("#f4f8ff"), Vector3(0.0, 0.075, 0.157))
	_add_accessory_label(smartwatch_preview, "WatchFaceMetric", "ACTIVITY     76%", 10, 0.0037, Color("#9eb0c4"), Vector3(0.035, -0.285, 0.157))
	var activity_ring: MeshInstance3D = _add_charger_torus(smartwatch_preview, "ActivityRing", 0.063, 0.009, Vector3(-0.245, -0.285, 0.159), accent_material)
	activity_ring.rotation = Vector3.ZERO
	_add_charger_box(smartwatch_preview, "WatchFaceSeparator", Vector3(0.53, 0.004, 0.002), Vector3(0.0, -0.185, 0.158), _charger_material(Color("#273747"), 0.08, 0.54))

	# Realistic side controls: a small knurled digital crown and a separate
	# elongated action button, both seated into the case flank.
	var crown := _add_charger_cylinder(smartwatch_preview, "DigitalCrown", 0.045, 0.092, Vector3(0.465, 0.115, 0.006), steel_material, 40)
	crown.rotation_degrees.z = 90.0
	var crown_rim: MeshInstance3D = _add_charger_torus(smartwatch_preview, "DigitalCrownRim", 0.044, 0.0045, Vector3(0.465, 0.115, 0.006), dark_steel_material)
	crown_rim.rotation.y = PI * 0.5
	var crown_cap := _add_charger_cylinder(smartwatch_preview, "DigitalCrownEndCap", 0.035, 0.008, Vector3(0.514, 0.115, 0.006), steel_material, 36)
	crown_cap.rotation_degrees.z = 90.0
	var side_button := MeshInstance3D.new()
	side_button.name = "SmartwatchActionButton"
	side_button.mesh = _create_rounded_panel_mesh(0.042, 0.145, 0.040, 0.019)
	side_button.position = Vector3(0.459, -0.175, 0.004)
	side_button.material_override = dark_steel_material
	smartwatch_preview.add_child(side_button)
	_add_charger_box(smartwatch_preview, "ActionButtonInset", Vector3(0.008, 0.085, 0.006), Vector3(0.481, -0.175, 0.004), steel_material)

	# Two-piece buckle strap: each half follows a smooth wrist arc and
	# the tips meet beneath a real metal pin buckle on the rear of the watch.
	var upper_anchors := PackedVector3Array([
		Vector3(0.0, 0.485, -0.035),
		Vector3(0.0, 0.61, -0.16),
		Vector3(0.0, 0.70, -0.36),
		Vector3(0.0, 0.66, -0.57),
		Vector3(0.0, 0.46, -0.77),
		Vector3(0.0, 0.25, -0.88),
		Vector3(0.0, 0.105, -0.91)
	])
	var lower_anchors := PackedVector3Array([
		Vector3(0.0, -0.485, -0.035),
		Vector3(0.0, -0.61, -0.16),
		Vector3(0.0, -0.70, -0.36),
		Vector3(0.0, -0.66, -0.57),
		Vector3(0.0, -0.46, -0.77),
		Vector3(0.0, -0.25, -0.88),
		Vector3(0.0, -0.105, -0.91)
	])
	var upper_route := _create_smartwatch_smooth_route(upper_anchors, 24)
	var lower_route := _create_smartwatch_smooth_route(lower_anchors, 24)
	var upper_band := MeshInstance3D.new()
	upper_band.name = "SmoothPerforatedBuckleStrap"
	upper_band.mesh = _create_smartwatch_band_mesh(upper_route, 0.455, 0.075)
	upper_band.material_override = strap_material
	smartwatch_preview.add_child(upper_band)
	var lower_band := MeshInstance3D.new()
	lower_band.name = "SmoothBuckleStrapTail"
	lower_band.mesh = _create_smartwatch_band_mesh(lower_route, 0.455, 0.075)
	lower_band.material_override = strap_material
	smartwatch_preview.add_child(lower_band)

	var upper_pin := _add_charger_cylinder(smartwatch_preview, "UpperBandSpringBar", 0.018, 0.47, Vector3(0.0, 0.485, -0.018), steel_material, 24)
	upper_pin.rotation_degrees.z = 90.0
	var lower_pin := _add_charger_cylinder(smartwatch_preview, "LowerBandSpringBar", 0.018, 0.47, Vector3(0.0, -0.485, -0.018), steel_material, 24)
	lower_pin.rotation_degrees.z = 90.0

	# The buckle frame lies flat against the outer rear strap surface (X/Y),
	# not edge-on. Its pin reaches toward the adjustment holes in the long half.
	var buckle_z := -0.956
	_add_charger_box(smartwatch_preview, "BandBuckleTopRail", Vector3(0.52, 0.022, 0.022), Vector3(0.0, 0.14, buckle_z), steel_material)
	_add_charger_box(smartwatch_preview, "BandBuckleBottomRail", Vector3(0.52, 0.022, 0.022), Vector3(0.0, -0.14, buckle_z), steel_material)
	_add_charger_box(smartwatch_preview, "BandBuckleLeftRail", Vector3(0.022, 0.28, 0.022), Vector3(-0.249, 0.0, buckle_z), steel_material)
	_add_charger_box(smartwatch_preview, "BandBuckleRightRail", Vector3(0.022, 0.28, 0.022), Vector3(0.249, 0.0, buckle_z), steel_material)
	_add_charger_box(smartwatch_preview, "BandBuckleTongue", Vector3(0.014, 0.15, 0.014), Vector3(0.0, 0.065, buckle_z - 0.012), dark_steel_material)

	# Dark recessed-looking sizing holes follow the same curve as the long strap.
	var hole_material := _charger_material(Color("#17212a"), 0.0, 0.92)
	for hole_index in range(5):
		var hole_y := 0.30 - float(hole_index) * 0.05
		var hole_z := -0.878 - float(hole_index) * 0.008
		var adjustment_hole := _add_charger_cylinder(smartwatch_preview, "BandAdjustmentHole_%d" % hole_index, 0.014, 0.008, Vector3(0.0, hole_y, hole_z), hole_material, 24)
		adjustment_hole.rotation_degrees.x = 90.0


func _create_smartwatch_smooth_route(anchors: PackedVector3Array, steps_per_segment: int = 20) -> PackedVector3Array:
	var route := PackedVector3Array()
	if anchors.size() < 2:
		return anchors
	for segment_index in range(anchors.size() - 1):
		var p0: Vector3 = anchors[maxi(segment_index - 1, 0)]
		var p1: Vector3 = anchors[segment_index]
		var p2: Vector3 = anchors[segment_index + 1]
		var p3: Vector3 = anchors[mini(segment_index + 2, anchors.size() - 1)]
		for sample_index in range(steps_per_segment + 1):
			if segment_index > 0 and sample_index == 0:
				continue
			var t := float(sample_index) / float(steps_per_segment)
			var t2 := t * t
			var t3 := t2 * t
			var point := (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t3) * 0.5
			route.append(point)
	return route


func _create_smartwatch_band_mesh(points: PackedVector3Array, width: float, thickness: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if points.size() < 2:
		return mesh
	const BAND_SEGMENTS := 28
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	for point_index in range(points.size()):
		var previous_point := points[maxi(point_index - 1, 0)]
		var following_point := points[mini(point_index + 1, points.size() - 1)]
		var tangent := (following_point - previous_point).normalized()
		if tangent.length_squared() < 0.000001:
			tangent = Vector3.UP
		var width_axis := Vector3.RIGHT
		var thickness_axis := tangent.cross(width_axis).normalized()
		if thickness_axis.length_squared() < 0.000001:
			thickness_axis = Vector3.BACK
		var taper := lerpf(1.0, 0.985, float(point_index) / float(points.size() - 1))
		var ring := PackedVector3Array()
		var normals := PackedVector3Array()
		for side in range(BAND_SEGMENTS):
			var angle := TAU * float(side) / float(BAND_SEGMENTS)
			var width_radius := width * 0.5 * taper
			var thickness_radius := thickness * 0.5
			var radial := (width_axis * (cos(angle) / maxf(width_radius, 0.0001)) + thickness_axis * (sin(angle) / maxf(thickness_radius, 0.0001))).normalized()
			var offset := width_axis * cos(angle) * width_radius
			offset += thickness_axis * sin(angle) * thickness_radius
			ring.append(points[point_index] + offset)
			normals.append(radial)
		rings.append(ring)
		ring_normals.append(normals)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(rings.size() - 1):
		for side in range(BAND_SEGMENTS):
			var next_side := (side + 1) % BAND_SEGMENTS
			var a: Vector3 = rings[ring_index][side]
			var b: Vector3 = rings[ring_index + 1][side]
			var c: Vector3 = rings[ring_index + 1][next_side]
			var d: Vector3 = rings[ring_index][next_side]
			var normal_a: Vector3 = ring_normals[ring_index][side]
			var normal_b: Vector3 = ring_normals[ring_index + 1][side]
			var normal_c: Vector3 = ring_normals[ring_index + 1][next_side]
			var normal_d: Vector3 = ring_normals[ring_index][next_side]
			_add_phone_mesh_triangle_with_normals(surface, a, b, c, normal_a, normal_b, normal_c)
			_add_phone_mesh_triangle_with_normals(surface, a, c, d, normal_a, normal_c, normal_d)
	var start_tangent := (points[1] - points[0]).normalized()
	var end_tangent := (points[points.size() - 1] - points[points.size() - 2]).normalized()
	for side in range(BAND_SEGMENTS):
		var next_side := (side + 1) % BAND_SEGMENTS
		_add_phone_mesh_triangle(surface, points[0], rings[0][next_side], rings[0][side], -start_tangent)
		var last_ring := rings.size() - 1
		_add_phone_mesh_triangle(surface, points[points.size() - 1], rings[last_ring][side], rings[last_ring][next_side], end_tangent)
	return surface.commit()


func _add_accessory_label(parent: Node3D, node_name: String, label_text: String, font_size_value: int, pixel_scale: float, text_color: Color, label_position: Vector3) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = label_text
	label.font_size = font_size_value
	label.pixel_size = pixel_scale
	label.modulate = text_color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = label_position
	parent.add_child(label)
	return label


func _show_smartwatch_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "SmartwatchControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SMART WATCH", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Add a 3D smartwatch accessory to the product preview. Drag the centre preview to inspect it.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	var enable_row := HBoxContainer.new()
	enable_row.name = "SmartwatchEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(enable_row)
	var enable_label := _make_label("ENABLE SMART WATCH", 13, Color("#e6f5ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)
	var toggle := TextureButton.new()
	toggle.name = "EnableSmartwatchModel"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = smartwatch_enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(_on_smartwatch_enabled_toggled)
	enable_row.add_child(toggle)

	if smartwatch_enabled:
		var color_button := Button.new()
		color_button.name = "OpenSmartwatchDeviceColorEditor"
		color_button.text = "CUSTOMIZE SMART WATCH COLOR  ›"
		color_button.custom_minimum_size = Vector2(0, 46)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(color_button, 13)
		_style_staff_button(color_button, false)
		color_button.pressed.connect(_show_device_color_controls.bind(false, false, false, true, false))
		active_feature_panel.add_child(color_button)


func _on_smartwatch_enabled_toggled(enabled: bool) -> void:
	smartwatch_enabled = enabled
	_rebuild_smartwatch_preview()
	_set_smartwatch_preview_mode(true)
	_show_smartwatch_controls()


func _on_smartwatch_color_selected(color_name: String, color: Color) -> void:
	smartwatch_color_name = color_name
	smartwatch_body_color = color
	_rebuild_smartwatch_preview()
	_set_smartwatch_preview_mode(true)
	_show_device_color_controls(false, false, false, true, false)


func _rebuild_earbuds_preview() -> void:
	if not is_instance_valid(wireless_earbuds_preview):
		return
	for child in wireless_earbuds_preview.get_children():
		child.free()

	# Compact, softly rounded closed AirPods-style charging case. Keep the
	# housing continuous and cut the USB-C mouth out of the bottom wall itself.
	var shell_material := _charger_material(wireless_earbuds_body_color, 0.15, 0.26)
	var lid_edge_material := _charger_material(wireless_earbuds_body_color.darkened(0.10), 0.22, 0.30)
	var lid_material := _charger_material(wireless_earbuds_body_color.lightened(0.035), 0.12, 0.22)
	var seam_material := _charger_material(Color("#111820"), 0.08, 0.76)
	var metal_material := _charger_material(Color("#b8c4ce"), 0.88, 0.22)
	var led_material := _charger_material(Color("#e9f3e8"), 0.04, 0.20)
	led_material.emission_enabled = true
	led_material.emission = Color("#eaffdf")
	led_material.emission_energy_multiplier = 0.12

	# The CSG combiner makes the port a true opening through the lower shell.
	# A dark insert alone would leave the original plastic wall blocking it.
	var housing := CSGCombiner3D.new()
	housing.name = "ClosedAirPodsStyleHousingWithCutUSBPort"
	housing.use_collision = false
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wireless_earbuds_preview.add_child(housing)

	var case_body := CSGMesh3D.new()
	case_body.name = "ClosedEarbudsCaseMainShell"
	case_body.operation = CSGShape3D.OPERATION_UNION
	case_body.mesh = _create_rounded_panel_mesh(1.30, 1.08, 0.42, 0.34)
	case_body.material = shell_material
	housing.add_child(case_body)

	# USB-C dimensions are kept proportional to the case. The cutter passes
	# from the outside bottom edge into the body, leaving room for a deep insert.
	var port_width := 0.205
	var port_height := 0.064
	var port_cut_depth := 0.30
	var bottom_edge_y := -0.54
	var port_cutter := CSGMesh3D.new()
	port_cutter.name = "BottomUSBCThroughHousingCut"
	port_cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
	port_cutter.mesh = _create_rounded_panel_mesh(
		port_width * 1.04,
		port_height * 1.08,
		port_cut_depth,
		port_height * 0.36
	)
	port_cutter.rotation.x = PI * 0.5
	# Extend slightly past the outer skin to avoid a coplanar CSG cap.
	port_cutter.position = Vector3(0.0, bottom_edge_y + port_cut_depth * 0.5 - 0.012, 0.0)
	housing.add_child(port_cutter)

	# The lid sits flush to the rounded body and has a fine perimeter break.
	# Its slightly crowned-looking edge and thin dark split keep the silhouette
	# close to a real compact wireless-earbuds charging case.
	var lid_bezel := MeshInstance3D.new()
	lid_bezel.name = "ClosedLidPerimeterBezel"
	lid_bezel.mesh = _create_rounded_panel_mesh(1.275, 0.545, 0.022, 0.255)
	lid_bezel.material_override = lid_edge_material
	lid_bezel.position = Vector3(0.0, 0.226, 0.211)
	wireless_earbuds_preview.add_child(lid_bezel)

	var lid_face := MeshInstance3D.new()
	lid_face.name = "ClosedLidSatinFace"
	lid_face.mesh = _create_rounded_panel_mesh(1.245, 0.518, 0.018, 0.242)
	lid_face.material_override = lid_material
	lid_face.position = Vector3(0.0, 0.229, 0.232)
	wireless_earbuds_preview.add_child(lid_face)

	var lid_seam := MeshInstance3D.new()
	lid_seam.name = "ContinuousClosedLidSeam"
	lid_seam.mesh = _create_rounded_panel_mesh(1.105, 0.008, 0.004, 0.004)
	lid_seam.material_override = seam_material
	lid_seam.position = Vector3(0.0, -0.050, 0.238)
	wireless_earbuds_preview.add_child(lid_seam)

	# Rear hinge barrel and two end collars are visible from a rotated view.
	var hinge := _add_charger_cylinder(
		wireless_earbuds_preview, "RearLidHingeBarrel", 0.022, 0.70,
		Vector3(0.0, 0.468, -0.190), metal_material, 40
	)
	hinge.rotation_degrees.z = 90.0
	for hinge_side in range(2):
		var hinge_cap := _add_charger_cylinder(
			wireless_earbuds_preview,
			"RearHingeEndCap_%d" % hinge_side,
			0.030,
			0.045,
			Vector3(-0.355 if hinge_side == 0 else 0.355, 0.468, -0.190),
			lid_edge_material,
			32
		)
		hinge_cap.rotation_degrees.z = 90.0

	# Small rear setup button and subtle front battery indicator.
	var pairing_button_ring := _add_charger_cylinder(
		wireless_earbuds_preview, "RearPairingButtonBezel", 0.041, 0.010,
		Vector3(0.0, -0.245, -0.212), seam_material, 32
	)
	pairing_button_ring.rotation_degrees.x = -90.0
	var pairing_button := _add_charger_cylinder(
		wireless_earbuds_preview, "RearPairingButton", 0.025, 0.008,
		Vector3(0.0, -0.245, -0.220), lid_material, 32
	)
	pairing_button.rotation_degrees.x = -90.0

	var led_bezel := _add_charger_cylinder(
		wireless_earbuds_preview, "FrontStatusLightRecess", 0.022, 0.008,
		Vector3(0.0, -0.342, 0.211), seam_material, 32
	)
	led_bezel.rotation_degrees.x = 90.0
	var status_led := _add_charger_cylinder(
		wireless_earbuds_preview, "FrontBatteryStatusLED", 0.009, 0.006,
		Vector3(0.0, -0.342, 0.218), led_material, 32
	)
	status_led.rotation_degrees.x = 90.0

	# Reuse the same machined lip, deep cavity walls, black floor, USB-C
	# insulating tongue and contact details as the phone/charger port system.
	_add_charger_recessed_port(
		wireless_earbuds_preview,
		"USB-C",
		Vector3(0.0, bottom_edge_y, 0.0),
		metal_material,
		Vector3.ZERO,
		"BottomUSBCDeepRecessedPort",
		Vector2(port_width, port_height),
		0.115
	)

	wireless_earbuds_preview.position = Vector3(0.0, -0.015, 0.0)


func _set_earbuds_preview_mode(enabled: bool) -> void:
	var entering_earbuds_preview := enabled and not wireless_earbuds_preview_mode
	_set_charger_preview_mode(false)
	_set_smartwatch_preview_mode(false)
	_set_power_bank_preview_mode(false)
	wireless_earbuds_preview_mode = enabled
	if entering_earbuds_preview and is_instance_valid(wireless_earbuds_preview):
		# Start on a three-quarter product angle; subsequent touch drags remain free.
		wireless_earbuds_preview.rotation_degrees = Vector3(-7.0, -16.0, 0.0)
	if is_instance_valid(phone_body):
		phone_body.visible = not enabled
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible = not enabled and phone_case_custom_enabled and phone_case_built and not phone_case_building and left_tools_page != 1
	if is_instance_valid(charger_preview):
		charger_preview.visible = not enabled and charger_preview_mode and (charger_enabled or (charger_cable_enabled and not _charger_device_connector().is_empty()))
	if is_instance_valid(wireless_earbuds_preview):
		wireless_earbuds_preview.visible = enabled and wireless_earbuds_enabled
	if is_instance_valid(preview_camera):
		preview_camera.position = Vector3(0.0, 0.0, 3.55 if enabled else 5.2)
		preview_camera.fov = 35.0 if enabled else 38.0
		preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _show_earbuds_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "WirelessEarbudsControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("WIRELESS EARBUDS", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Add a rotatable 3D wireless earbuds case with the lid fully closed and the earbuds stored inside.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	var enable_row := HBoxContainer.new()
	enable_row.name = "WirelessEarbudsEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(enable_row)
	var enable_label := _make_label("ENABLE EARBUDS CASE", 13, Color("#e6f5ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)
	var toggle := TextureButton.new()
	toggle.name = "EnableWirelessEarbudsModel"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = wireless_earbuds_enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(_on_earbuds_enabled_toggled)
	enable_row.add_child(toggle)

	if wireless_earbuds_enabled:
		var color_button := Button.new()
		color_button.name = "OpenWirelessEarbudsDeviceColorEditor"
		color_button.text = "CUSTOMIZE CASE COLOR  ›"
		color_button.custom_minimum_size = Vector2(0, 46)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(color_button, 13)
		_style_staff_button(color_button, false)
		color_button.pressed.connect(_show_device_color_controls.bind(false, false, false, false, false, true))
		active_feature_panel.add_child(color_button)


func _on_earbuds_enabled_toggled(enabled: bool) -> void:
	wireless_earbuds_enabled = enabled
	_rebuild_earbuds_preview()
	_set_earbuds_preview_mode(true)
	_show_earbuds_controls()


func _rebuild_power_bank_preview() -> void:
	if not is_instance_valid(power_bank_preview):
		return
	for child in power_bank_preview.get_children():
		child.free()

	# A slim consumer power bank needs a continuous rounded shell, a visible
	# housing seam and restrained controls—not a stack of flat display slabs.
	var housing_material := _charger_material(power_bank_body_color, 0.20, 0.36)
	var cover_material := _charger_material(power_bank_body_color.lightened(0.035), 0.12, 0.43)
	var frame_material := _charger_material(power_bank_body_color.darkened(0.25), 0.52, 0.30)
	var screen_material := _charger_material(Color("#101923"), 0.10, 0.13)
	var metal_material := _charger_material(Color("#abb8c4"), 0.88, 0.23)
	var indicator_material := _charger_material(Color("#6ed8c4"), 0.22, 0.28)

	# The shell and midframe are combined as CSG so both USB apertures are
	# physically removed from the end wall. A visual cavity laid over a solid
	# mesh is not a real recess: the untouched shell face would still block it.
	var housing_shell := CSGCombiner3D.new()
	housing_shell.name = "PowerBankHousingWithOpenUSBPorts"
	housing_shell.use_collision = false
	housing_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	power_bank_preview.add_child(housing_shell)

	var housing := CSGMesh3D.new()
	housing.name = "PowerBankRoundedAluminiumHousing"
	housing.operation = CSGShape3D.OPERATION_UNION
	housing.mesh = _create_rounded_panel_mesh(1.14, 1.96, 0.255, 0.235)
	housing.material = housing_material
	housing_shell.add_child(housing)

	var lower_frame := CSGMesh3D.new()
	lower_frame.name = "PowerBankPerimeterMidframe"
	lower_frame.operation = CSGShape3D.OPERATION_UNION
	lower_frame.mesh = _create_rounded_panel_mesh(1.145, 1.95, 0.055, 0.225)
	lower_frame.position.z = -0.012
	lower_frame.material = frame_material
	housing_shell.add_child(lower_frame)

	# Match the actual inner contour used by the port inserts. These cutters
	# pass through the front shell and the perimeter frame, and stop just
	# behind the recessed port floors so neither layer can seal the openings.
	var usb_c_cutout := CSGMesh3D.new()
	usb_c_cutout.name = "USB_C_ThroughHousingAperture"
	usb_c_cutout.operation = CSGShape3D.OPERATION_SUBTRACTION
	usb_c_cutout.mesh = _create_rounded_panel_mesh(0.17 * 0.96, 0.075 * 0.88, 0.125, 0.075 * 0.30)
	usb_c_cutout.rotation.x = -PI * 0.5
	usb_c_cutout.position = Vector3(-0.235, 0.92375, 0.0)
	housing_shell.add_child(usb_c_cutout)

	var usb_a_cutout := CSGMesh3D.new()
	usb_a_cutout.name = "USB_A_ThroughHousingAperture"
	usb_a_cutout.operation = CSGShape3D.OPERATION_SUBTRACTION
	usb_a_cutout.mesh = _create_rounded_panel_mesh(0.235 * 0.96, 0.092 * 0.88, 0.125, 0.092 * 0.30)
	usb_a_cutout.rotation.x = -PI * 0.5
	usb_a_cutout.position = Vector3(0.205, 0.92375, 0.0)
	housing_shell.add_child(usb_a_cutout)

	var front_cover := MeshInstance3D.new()
	front_cover.name = "PowerBankSoftTouchFrontCover"
	front_cover.mesh = _create_rounded_panel_mesh(1.105, 1.925, 0.022, 0.218)
	front_cover.position.z = 0.132
	front_cover.material_override = cover_material
	power_bank_preview.add_child(front_cover)

	# Subtle recessed charge readout, with a real percentage label and small
	# status indicators. The screen remains small relative to the full body.
	var display_bezel := MeshInstance3D.new()
	display_bezel.name = "PowerBankDisplayBezel"
	display_bezel.mesh = _create_rounded_panel_mesh(0.43, 0.225, 0.018, 0.065)
	display_bezel.position = Vector3(0.0, 0.605, 0.151)
	display_bezel.material_override = frame_material
	power_bank_preview.add_child(display_bezel)

	var display := MeshInstance3D.new()
	display.name = "PowerBankInsetOLED"
	display.mesh = _create_rounded_panel_mesh(0.397, 0.192, 0.008, 0.052)
	display.position = Vector3(0.0, 0.605, 0.165)
	display.material_override = screen_material
	power_bank_preview.add_child(display)
	_add_accessory_label(power_bank_preview, "PowerBankChargePercentage", "86%", 25, 0.0030, Color("#e9f4ff"), Vector3(0.0, 0.605, 0.173))

	for indicator_index in range(4):
		var indicator := _add_charger_cylinder(power_bank_preview, "PowerBankStatusLED_%d" % indicator_index, 0.012, 0.008, Vector3(-0.045 + float(indicator_index) * 0.03, 0.385, 0.151), indicator_material if indicator_index < 3 else frame_material, 20)
		indicator.rotation_degrees.x = 90.0

	_add_accessory_label(power_bank_preview, "PowerBankCapacityMark", _format_power_bank_capacity(power_bank_capacity_mah), 13, 0.0035, Color("#a9c7d9"), Vector3(0.0, -0.64, 0.147))

	# A small tactile power key is fitted to the side wall, with a metal edge.
	var side_button := _add_charger_cylinder(power_bank_preview, "PowerBankSidePowerButton", 0.043, 0.032, Vector3(0.574, 0.39, 0.0), frame_material, 32)
	side_button.rotation_degrees.z = 90.0
	var side_button_face := _add_charger_cylinder(power_bank_preview, "PowerBankSideButtonFace", 0.028, 0.008, Vector3(0.594, 0.39, 0.0), metal_material, 32)
	side_button_face.rotation_degrees.z = 90.0

	# Reuse the real deep-port construction used by the charger and phone:
	# machined metal ring, insulating gasket, extruded cavity walls, recessed
	# black floor and connector-specific tongue/contact details. The local port
	# normal is flipped toward the power bank's +Y end face.
	_add_charger_recessed_port(power_bank_preview, "USB-C", Vector3(-0.235, 0.98, 0.0), metal_material, Vector3(0.0, 0.0, PI), "PowerBankUSBCRecessedPort", Vector2(0.17, 0.075), 0.11)
	_add_charger_recessed_port(power_bank_preview, "USB-A", Vector3(0.205, 0.98, 0.0), metal_material, Vector3(0.0, 0.0, PI), "PowerBankUSBARecessedPort", Vector2(0.235, 0.092), 0.11)

func _set_power_bank_preview_mode(enabled: bool) -> void:
	power_bank_preview_mode = enabled
	if is_instance_valid(wireless_earbuds_preview):
		wireless_earbuds_preview.visible = false
	wireless_earbuds_preview_mode = false
	if is_instance_valid(phone_body):
		phone_body.visible = not enabled and not smartwatch_preview_mode and not charger_preview_mode
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible = not enabled and not smartwatch_preview_mode and not charger_preview_mode and phone_case_custom_enabled and phone_case_built and not phone_case_building and left_tools_page != 1
	if is_instance_valid(charger_preview):
		charger_preview.visible = not enabled and not smartwatch_preview_mode and charger_preview_mode and (charger_enabled or (charger_cable_enabled and not _charger_device_connector().is_empty()))
	if is_instance_valid(smartwatch_preview):
		smartwatch_preview.visible = not enabled and smartwatch_preview_mode and smartwatch_enabled
	if is_instance_valid(power_bank_preview):
		power_bank_preview.visible = enabled and power_bank_enabled
	if is_instance_valid(preview_camera):
		preview_camera.position = Vector3(0.0, 0.0, 4.15 if enabled else 5.2)
		preview_camera.fov = 38.0
		preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _show_power_bank_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "PowerBankControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("POWER BANK", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Add a rotatable 3D power bank to the centre preview. Choose its finish below.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	var enable_row := HBoxContainer.new()
	enable_row.name = "PowerBankEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(enable_row)
	var enable_label := _make_label("ENABLE POWER BANK", 13, Color("#e6f5ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)
	var toggle := TextureButton.new()
	toggle.name = "EnablePowerBankModel"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = power_bank_enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(_on_power_bank_enabled_toggled)
	enable_row.add_child(toggle)

	if power_bank_enabled:
		var capacity_heading := _make_label("BATTERY CAPACITY", 14, Color("#a9e3ff"))
		capacity_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(capacity_heading)

		power_bank_capacity_value_label = _make_label(_format_power_bank_capacity(power_bank_capacity_mah), 22, Color("#e6f5ff"))
		power_bank_capacity_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(power_bank_capacity_value_label)

		var capacity_slider := VSlider.new()
		capacity_slider.name = "PowerBankCapacitySlider"
		capacity_slider.min_value = 10000
		capacity_slider.max_value = 25000
		capacity_slider.step = 500
		capacity_slider.value = power_bank_capacity_mah
		capacity_slider.tick_count = 31
		capacity_slider.custom_minimum_size = Vector2(76, 270)
		capacity_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
		capacity_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		capacity_slider.focus_mode = Control.FOCUS_NONE
		capacity_slider.value_changed.connect(_on_power_bank_capacity_changed)
		_style_custom_slider(capacity_slider)
		active_feature_panel.add_child(capacity_slider)

		var range_row := HBoxContainer.new()
		range_row.name = "PowerBankCapacityRange"
		range_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		range_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var minimum := _make_label("10,000 mAh", 11, Color("#a9c9dc"))
		minimum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		range_row.add_child(minimum)
		var maximum := _make_label("25,000 mAh", 11, Color("#a9c9dc"))
		maximum.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		maximum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		range_row.add_child(maximum)
		active_feature_panel.add_child(range_row)

		var color_button := Button.new()
		color_button.name = "OpenPowerBankDeviceColorEditor"
		color_button.text = "CUSTOMIZE POWER BANK COLOR  ›"
		color_button.custom_minimum_size = Vector2(0, 46)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(color_button, 13)
		_style_staff_button(color_button, false)
		color_button.pressed.connect(_show_device_color_controls.bind(false, false, false, false, true))
		active_feature_panel.add_child(color_button)


func _on_power_bank_enabled_toggled(enabled: bool) -> void:
	power_bank_enabled = enabled
	_rebuild_power_bank_preview()
	_set_power_bank_preview_mode(true)
	_show_power_bank_controls()


func _format_power_bank_capacity(capacity: int) -> String:
	return "%s mAh" % _format_integer_with_commas(capacity)


func _format_integer_with_commas(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return formatted


func _on_power_bank_capacity_changed(value: float) -> void:
	power_bank_capacity_mah = clampi(roundi(value / 500.0) * 500, 10000, 25000)
	if is_instance_valid(power_bank_capacity_value_label):
		power_bank_capacity_value_label.text = _format_power_bank_capacity(power_bank_capacity_mah)
	_rebuild_power_bank_preview()
	_set_power_bank_preview_mode(true)


func _on_power_bank_color_selected(color_name: String, color: Color) -> void:
	power_bank_color_name = color_name
	power_bank_body_color = color
	_rebuild_power_bank_preview()
	_set_power_bank_preview_mode(true)
	_show_device_color_controls(false, false, false, false, true)


func _charger_material(color: Color, metallic: float = 0.0, roughness: float = 0.32) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.clearcoat_enabled = true
	material.clearcoat = 0.35
	material.clearcoat_roughness = 0.18
	return material


func _add_charger_torus(parent: Node3D, node_name: String, radius: float, tube_radius: float, local_position: Vector3, material: Material) -> MeshInstance3D:
	# A real swept torus keeps the smartwatch activity ring and crown rim
	# continuous and smooth instead of approximating them with flat geometry.
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - tube_radius)
	mesh.outer_radius = radius + tube_radius
	mesh.rings = 48
	mesh.ring_segments = 12
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func _add_charger_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func _add_charger_cylinder(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, material: Material, radial_segments: int = 24) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


func _add_charger_recessed_port(parent: Node3D, output_connector: String, face_position: Vector3, metal_material: Material, face_rotation: Vector3 = Vector3(-1.5707963, 0.0, 0.0), port_node_name: String = "ChargerRecessedOutputPort", port_dimensions: Vector2 = Vector2.ZERO, recess_depth_override: float = 0.0) -> void:
	# Use the same machined lip, gasket, extruded cavity walls and recessed
	# contact floor as the phone's charging port. Rotate the phone-port
	# construction axis so its opening faces the charger's front (+Z).
	var unit_per_mm := _active_phone_size().y / 150.0
	var default_width := 8.34 * unit_per_mm if output_connector == "USB-C" else 12.0 * unit_per_mm
	var default_height := 2.56 * unit_per_mm if output_connector == "USB-C" else 4.5 * unit_per_mm
	var port_width := port_dimensions.x if port_dimensions.x > 0.0 else default_width
	var port_height := port_dimensions.y if port_dimensions.y > 0.0 else default_height
	var inner_points := _make_port_outline(port_width * 0.96, port_height * 0.88, port_height * 0.30, 10)

	var port_root := Node3D.new()
	port_root.name = port_node_name
	port_root.position = face_position
	port_root.rotation = face_rotation
	parent.add_child(port_root)

	var bezel_material: Material = metal_material
	var gasket_material := _charger_material(Color("#252c34"), 0.16, 0.72)
	var cavity_wall_material := _charger_material(Color("#59636d"), 0.82, 0.40)
	var cavity_material := _charger_material(Color("#030609"), 0.0, 0.98)
	var tongue_material := _charger_material(Color("#414b55"), 0.06, 0.70)
	var contact_material := _charger_material(Color("#d8ad5b"), 0.82, 0.26)

	var mouth_depth := 0.0001
	var recess_depth := recess_depth_override if recess_depth_override > 0.0 else 0.088
	var contact_depth := recess_depth * 0.56
	_add_port_ring(port_root, "MachinedPortMetalLip", inner_points, 1.16, -0.0007, bezel_material)
	_add_port_ring(port_root, "PortDarkInsulatingGasket", inner_points, 1.045, -0.0004, gasket_material)
	_add_port_cavity_walls(port_root, "DeepRecessedPortSideWalls", inner_points, mouth_depth, recess_depth, cavity_wall_material)
	_add_port_detail(port_root, "DeepBlackPortFloor", inner_points, recess_depth + 0.0002, cavity_material)

	if output_connector == "USB-C":
		var tongue_points := _make_port_outline(port_width * 0.72, port_height * 0.20, port_height * 0.095, 8)
		_add_port_detail(port_root, "USBCTongue", tongue_points, contact_depth, tongue_material)
		for row in range(2):
			for contact_index in range(12):
				var x := (float(contact_index) - 5.5) * (port_width * 0.66 / 12.0)
				var vertical := (1.0 if row == 0 else -1.0) * port_height * 0.105
				var pad := _make_port_outline(port_width * 0.035, port_height * 0.055, port_height * 0.018, 3)
				var shifted := PackedVector2Array()
				for point in pad:
					shifted.append(point + Vector2(x, vertical))
				_add_port_detail(port_root, "USBCRecessContact_%d_%d" % [row, contact_index], shifted, contact_depth - 0.0002, contact_material)
	else:
		# USB-A has a wider rectangular cavity and a low insulating contact bed.
		var tongue_points := _make_port_outline(port_width * 0.72, port_height * 0.30, port_height * 0.12, 7)
		var tongue_shifted := PackedVector2Array()
		for point in tongue_points:
			tongue_shifted.append(point + Vector2(0.0, -port_height * 0.16))
		_add_port_detail(port_root, "USBAInsulatingTongue", tongue_shifted, contact_depth, tongue_material)
		for contact_index in range(4):
			var x := (float(contact_index) - 1.5) * port_width * 0.145
			var pad := _make_port_outline(port_width * 0.105, port_height * 0.075, port_height * 0.025, 3)
			var shifted := PackedVector2Array()
			for point in pad:
				shifted.append(point + Vector2(x, -port_height * 0.16))
			_add_port_detail(port_root, "USBARecessContact_%d" % contact_index, shifted, contact_depth - 0.0002, contact_material)


func _append_charger_bezier(points: PackedVector3Array, start: Vector3, control_a: Vector3, control_b: Vector3, finish: Vector3, steps: int = 16) -> PackedVector3Array:
	var result := points
	for step in range(steps + 1):
		if not result.is_empty() and step == 0:
			continue
		var t := float(step) / float(steps)
		var inverse := 1.0 - t
		var point := start * (inverse * inverse * inverse)
		point += control_a * (3.0 * inverse * inverse * t)
		point += control_b * (3.0 * inverse * t * t)
		point += finish * (t * t * t)
		result.append(point)
	return result


func _create_charger_cable_tube_mesh(points: PackedVector3Array, radius: float, radial_segments: int = 14) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if points.size() < 2:
		return mesh

	# Parallel-transport the tube frame along the whole route. This keeps the
	# circular section stable through the U-bend instead of twisting or pinching.
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var previous_tangent := Vector3.ZERO
	var axis_a := Vector3.ZERO
	for index in range(points.size()):
		var previous_point := points[maxi(index - 1, 0)]
		var following_point := points[mini(index + 1, points.size() - 1)]
		var tangent := (following_point - previous_point).normalized()
		if tangent.length_squared() < 0.000001:
			tangent = previous_tangent if previous_tangent.length_squared() > 0.000001 else Vector3.FORWARD

		if index == 0:
			var reference := Vector3.UP
			if absf(tangent.dot(reference)) > 0.92:
				reference = Vector3.RIGHT
			axis_a = tangent.cross(reference).normalized()
		else:
			var turn_axis := previous_tangent.cross(tangent)
			var turn_length := turn_axis.length()
			var tangent_dot := clampf(previous_tangent.dot(tangent), -1.0, 1.0)
			if turn_length > 0.000001:
				axis_a = axis_a.rotated(turn_axis / turn_length, atan2(turn_length, tangent_dot))
			axis_a = (axis_a - tangent * axis_a.dot(tangent)).normalized()
			if axis_a.length_squared() < 0.000001:
				var fallback := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
				axis_a = tangent.cross(fallback).normalized()

		var axis_b := tangent.cross(axis_a).normalized()
		previous_tangent = tangent
		var ring := PackedVector3Array()
		var normals := PackedVector3Array()
		for side in range(radial_segments):
			var angle := TAU * float(side) / float(radial_segments)
			var normal := (axis_a * cos(angle) + axis_b * sin(angle)).normalized()
			ring.append(points[index] + normal * radius)
			normals.append(normal)
		rings.append(ring)
		ring_normals.append(normals)

	# A continuous triangle strip joins every ring. End caps are added below so
	# even a visible cable end cannot appear as a hollow, cut-off tube.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(rings.size() - 1):
		for side in range(radial_segments):
			var next_side := (side + 1) % radial_segments
			var a: Vector3 = rings[index][side]
			var b: Vector3 = rings[index + 1][side]
			var c: Vector3 = rings[index + 1][next_side]
			var d: Vector3 = rings[index][next_side]
			var normal_ab := (ring_normals[index][side] + ring_normals[index + 1][side] + ring_normals[index + 1][next_side]).normalized()
			var normal_ac := (ring_normals[index][side] + ring_normals[index + 1][next_side] + ring_normals[index][next_side]).normalized()
			_add_phone_mesh_triangle(surface, a, b, c, normal_ab)
			_add_phone_mesh_triangle(surface, a, c, d, normal_ac)

	var start_tangent := (points[1] - points[0]).normalized()
	var end_tangent := (points[points.size() - 1] - points[points.size() - 2]).normalized()
	for side in range(radial_segments):
		var next_side := (side + 1) % radial_segments
		_add_phone_mesh_triangle(surface, points[0], rings[0][next_side], rings[0][side], -start_tangent)
		var last_ring_index := rings.size() - 1
		_add_phone_mesh_triangle(surface, points[points.size() - 1], rings[last_ring_index][side], rings[last_ring_index][next_side], end_tangent)

	return surface.commit()


func _create_charger_connector_profile_mesh(width: float, height: float, depth: float, connector_type: String) -> ArrayMesh:
	var outline := PackedVector2Array()
	if connector_type == "Micro-USB":
		# Micro-B is shallow with near-straight sides and a slight taper.
		outline = PackedVector2Array([
			Vector2(-width * 0.46, -height * 0.42),
			Vector2(width * 0.46, -height * 0.42),
			Vector2(width * 0.43, height * 0.24),
			Vector2(width * 0.37, height * 0.50),
			Vector2(-width * 0.37, height * 0.50),
			Vector2(-width * 0.43, height * 0.24)
		])
	else:
		# Mini-B is taller and more strongly trapezoidal, unlike the rounded
		# capsule silhouette reserved for USB-C.
		outline = PackedVector2Array([
			Vector2(-width * 0.45, -height * 0.50),
			Vector2(width * 0.45, -height * 0.50),
			Vector2(width * 0.42, -height * 0.32),
			Vector2(width * 0.31, height * 0.50),
			Vector2(-width * 0.31, height * 0.50),
			Vector2(-width * 0.42, -height * 0.32)
		])
	var indices := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front_z := depth * 0.5
	var back_z := -depth * 0.5
	for index in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var d: Vector2 = outline[indices[index + 2]]
		_add_phone_mesh_triangle(surface, Vector3(a.x, a.y, front_z), Vector3(b.x, b.y, front_z), Vector3(d.x, d.y, front_z), Vector3.BACK)
		_add_phone_mesh_triangle(surface, Vector3(a.x, a.y, back_z), Vector3(d.x, d.y, back_z), Vector3(b.x, b.y, back_z), Vector3.FORWARD)
	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[next_index]
		var edge := b - a
		var side_normal := Vector3(edge.y, -edge.x, 0.0).normalized()
		var front_a := Vector3(a.x, a.y, front_z)
		var front_b := Vector3(b.x, b.y, front_z)
		var back_a := Vector3(a.x, a.y, back_z)
		var back_b := Vector3(b.x, b.y, back_z)
		_add_phone_mesh_triangle(surface, front_a, back_a, back_b, side_normal)
		_add_phone_mesh_triangle(surface, front_a, back_b, front_b, side_normal)
	return surface.commit()


func _create_charger_dc_barrel_mesh(outer_radius: float, inner_radius: float, front_z: float, rear_z: float, radial_segments: int = 40) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(radial_segments):
		var next_index := (index + 1) % radial_segments
		var angle_a := TAU * float(index) / float(radial_segments)
		var angle_b := TAU * float(next_index) / float(radial_segments)
		var outer_normal := Vector3(cos((angle_a + angle_b) * 0.5), sin((angle_a + angle_b) * 0.5), 0.0)
		var ofa := Vector3(cos(angle_a) * outer_radius, sin(angle_a) * outer_radius, front_z)
		var ofb := Vector3(cos(angle_b) * outer_radius, sin(angle_b) * outer_radius, front_z)
		var ora := Vector3(cos(angle_a) * outer_radius, sin(angle_a) * outer_radius, rear_z)
		var orb := Vector3(cos(angle_b) * outer_radius, sin(angle_b) * outer_radius, rear_z)
		_add_phone_mesh_triangle(surface, ofa, ora, orb, outer_normal)
		_add_phone_mesh_triangle(surface, ofa, orb, ofb, outer_normal)
		var ifa := Vector3(cos(angle_a) * inner_radius, sin(angle_a) * inner_radius, front_z)
		var ifb := Vector3(cos(angle_b) * inner_radius, sin(angle_b) * inner_radius, front_z)
		var ira := Vector3(cos(angle_a) * inner_radius, sin(angle_a) * inner_radius, rear_z)
		var irb := Vector3(cos(angle_b) * inner_radius, sin(angle_b) * inner_radius, rear_z)
		_add_phone_mesh_triangle(surface, ifa, ifb, irb, -outer_normal)
		_add_phone_mesh_triangle(surface, ifa, irb, ira, -outer_normal)
		_add_phone_mesh_triangle(surface, ofa, ofb, ifb, Vector3.BACK)
		_add_phone_mesh_triangle(surface, ofa, ifb, ifa, Vector3.BACK)
		_add_phone_mesh_triangle(surface, ora, irb, orb, Vector3.FORWARD)
		_add_phone_mesh_triangle(surface, ora, ira, irb, Vector3.FORWARD)
	return surface.commit()


func _add_charger_cable_connector(parent: Node3D, node_name: String, connector_type: String, local_position: Vector3, direction: Vector3, shell_material: Material, metal_material: Material) -> Node3D:
	var connector := Node3D.new()
	connector.name = node_name
	connector.position = local_position
	var forward := direction.normalized()
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.94:
		up = Vector3.FORWARD
	connector.basis = Basis.looking_at(forward, up)
	parent.add_child(connector)

	var tip_width := 0.142
	var tip_height := 0.044
	match connector_type:
		"USB-A":
			tip_width = 0.205
			tip_height = 0.060
		"Lightning":
			tip_width = 0.070
			tip_height = 0.018
		"Micro-USB":
			tip_width = 0.130
			tip_height = 0.035
		"Mini-USB":
			tip_width = 0.132
			tip_height = 0.060
		"DC Barrel":
			tip_width = 0.074
			tip_height = 0.074

	# Build the connector as three physically overlapping sections: a metal
	# plug shell, a moulded grip, and a flexible strain-relief boot.
	var grip_width := maxf(tip_width * 1.06, 0.108)
	var grip_height := maxf(tip_height * 1.55, 0.055)
	var grip := MeshInstance3D.new()
	grip.name = "MouldedConnectorGrip"
	grip.mesh = _create_rounded_panel_mesh(grip_width, grip_height, 0.135, minf(grip_height * 0.36, 0.025))
	grip.material_override = shell_material
	# Pull the moulded rubber grip forward so it visibly overlaps the
	# shortened metal shell instead of leaving a long exposed metal neck.
	grip.position = Vector3(0.0, 0.0, 0.085)
	grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	connector.add_child(grip)

	var relief_width := maxf(tip_width * 0.72, 0.078)
	var relief_height := maxf(tip_height * 1.22, 0.052)
	var relief := MeshInstance3D.new()
	relief.name = "FlexibleCableStrainRelief"
	relief.mesh = _create_rounded_panel_mesh(relief_width, relief_height, 0.145, minf(relief_height * 0.40, 0.022))
	relief.material_override = shell_material
	relief.position = Vector3(0.0, 0.0, 0.215)
	relief.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	connector.add_child(relief)

	var groove_material := _charger_material(Color("#202832"), 0.05, 0.76)
	for groove_index in range(4):
		var groove := MeshInstance3D.new()
		groove.name = "StrainReliefFlexGroove_%d" % groove_index
		groove.mesh = _create_rounded_panel_mesh(relief_width * 1.025, relief_height * 1.035, 0.006, minf(relief_height * 0.42, 0.023))
		groove.material_override = groove_material
		groove.position = Vector3(0.0, 0.0, 0.160 + float(groove_index) * 0.035)
		groove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		connector.add_child(groove)

	# The old plug detail was a flat outline with no shell depth, which rendered
	# like a disconnected silver sliver. This rounded extrusion now runs back
	# into the grip, while its inset face and contacts sit directly on the tip.
	# Shorten the exposed metal plug by 25%, keeping its front face fixed.
	# The rubber grip now reaches farther over the rear of the metal shell.
	var front_face_z := -0.106
	var shell_depth := 0.120
	var shell := MeshInstance3D.new()
	shell.name = "ContinuousMetalPlugShell"
	if connector_type in ["Micro-USB", "Mini-USB"]:
		shell.mesh = _create_charger_connector_profile_mesh(tip_width, tip_height, shell_depth, connector_type)
	else:
		shell.mesh = _create_rounded_panel_mesh(tip_width, tip_height, shell_depth, minf(tip_height * 0.40, tip_width * 0.22))
	shell.material_override = metal_material
	shell.visible = connector_type != "DC Barrel"
	shell.position = Vector3(0.0, 0.0, front_face_z + shell_depth * 0.5)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	connector.add_child(shell)

	var face_material := _charger_material(Color("#080d12"), 0.02, 0.94)
	var inner_metal := _charger_material(Color("#909da7"), 0.82, 0.26)
	var contact_material := _charger_material(Color("#d9b66d"), 0.90, 0.22)

	if connector_type == "DC Barrel":
		# Hollow sleeve runs from the exposed nose back inside the rubber grip.
		# This single continuous shell replaces the detached short cylinder.
		var barrel := MeshInstance3D.new()
		barrel.name = "ContinuousHollowDCBarrelSleeve"
		var dc_socket_inner_diameter := 3.5 * (_active_phone_size().y / 150.0) * 0.62
		var dc_outer_radius := dc_socket_inner_diameter * 0.94 * 0.5
		var dc_inner_radius := dc_outer_radius * 0.54
		barrel.mesh = _create_charger_dc_barrel_mesh(dc_outer_radius, dc_inner_radius, -0.195, 0.055, 48)
		barrel.material_override = metal_material
		barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		connector.add_child(barrel)
		var barrel_insulator := _add_charger_cylinder(connector, "DCBarrelDarkInsulator", dc_inner_radius * 0.92, 0.004, Vector3(0.0, 0.0, -0.170), face_material, 32)
		barrel_insulator.rotation_degrees.x = 90.0
		var centre_pin := _add_charger_cylinder(connector, "DCBarrelCentreContact", dc_inner_radius * 0.36, 0.135, Vector3(0.0, 0.0, -0.1275), contact_material, 24)
		centre_pin.rotation_degrees.x = 90.0
	elif connector_type == "Lightning":
		var blade := MeshInstance3D.new()
		blade.name = "LightningMetalBlade"
		blade.mesh = _create_rounded_panel_mesh(tip_width * 0.88, tip_height * 0.80, 0.004, tip_height * 0.20)
		blade.material_override = contact_material
		blade.position = Vector3(0.0, 0.0, front_face_z - 0.002)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		connector.add_child(blade)
	else:
		var inset := MeshInstance3D.new()
		inset.name = "RecessedPlugFace"
		inset.mesh = _create_rounded_panel_mesh(tip_width * 0.82, tip_height * 0.62, 0.003, tip_height * 0.16)
		inset.material_override = face_material
		inset.position = Vector3(0.0, 0.0, front_face_z)
		inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		connector.add_child(inset)

		if connector_type == "USB-C":
			var tongue := MeshInstance3D.new()
			tongue.name = "USBCTongue"
			tongue.mesh = _create_rounded_panel_mesh(tip_width * 0.70, maxf(tip_height * 0.18, 0.006), 0.002, 0.0025)
			tongue.material_override = inner_metal
			tongue.position = Vector3(0.0, 0.0, front_face_z - 0.0025)
			tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			connector.add_child(tongue)
			for contact_index in range(12):
				var contact := MeshInstance3D.new()
				contact.name = "USBPlugContact_%d" % contact_index
				var contact_width := maxf(tip_width * 0.035, 0.0038)
				var contact_height := maxf(tip_height * 0.13, 0.0035)
				contact.mesh = _create_rounded_panel_mesh(contact_width, contact_height, 0.0015, minf(contact_height * 0.35, 0.0015))
				contact.material_override = contact_material
				var contact_x := (float(contact_index) - 5.5) * (tip_width * 0.70 / 12.0)
				contact.position = Vector3(contact_x, 0.0, front_face_z - 0.0044)
				contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				connector.add_child(contact)
		elif connector_type == "USB-A":
			var tongue := MeshInstance3D.new()
			tongue.name = "USBAInsulatingTongue"
			tongue.mesh = _create_rounded_panel_mesh(tip_width * 0.72, tip_height * 0.30, 0.002, 0.003)
			tongue.material_override = inner_metal
			tongue.position = Vector3(0.0, -tip_height * 0.12, front_face_z - 0.0025)
			tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			connector.add_child(tongue)
			for contact_index in range(4):
				var contact := MeshInstance3D.new()
				contact.name = "USBAPlugContact_%d" % contact_index
				contact.mesh = _create_rounded_panel_mesh(tip_width * 0.09, tip_height * 0.12, 0.0015, 0.001)
				contact.material_override = contact_material
				var contact_x := (float(contact_index) - 1.5) * tip_width * 0.145
				contact.position = Vector3(contact_x, -tip_height * 0.12, front_face_z - 0.0044)
				contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				connector.add_child(contact)
		elif connector_type in ["Micro-USB", "Mini-USB"]:
			var trapezoid_recess := MeshInstance3D.new()
			trapezoid_recess.name = "TrapezoidPlugRecess"
			trapezoid_recess.mesh = _create_charger_connector_profile_mesh(tip_width * 0.76, tip_height * 0.58, 0.003, connector_type)
			trapezoid_recess.material_override = face_material
			trapezoid_recess.position = Vector3(0.0, 0.0, front_face_z - 0.0005)
			trapezoid_recess.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			connector.add_child(trapezoid_recess)
			var tongue := MeshInstance3D.new()
			tongue.name = "FiveContactInsulatingTongue"
			tongue.mesh = _create_rounded_panel_mesh(tip_width * 0.55, tip_height * 0.16, 0.0025, 0.0015)
			tongue.material_override = inner_metal
			tongue.position = Vector3(0.0, 0.0, front_face_z - 0.003)
			tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			connector.add_child(tongue)
			for contact_index in range(5):
				var contact := MeshInstance3D.new()
				contact.name = "USBContact_%d" % contact_index
				contact.mesh = _create_rounded_panel_mesh(tip_width * 0.045, tip_height * 0.10, 0.0012, 0.0008)
				contact.material_override = contact_material
				var contact_x := (float(contact_index) - 2.0) * (tip_width * 0.55 / 5.0)
				contact.position = Vector3(contact_x, 0.0, front_face_z - 0.005)
				contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				connector.add_child(contact)

	return connector


func _build_charger_cable(geometry_parent: Node3D, _output_connector: String) -> Node3D:
	# A short, clean U-shaped lead with one continuous cable jacket.
	var cable_group := Node3D.new()
	cable_group.name = "StandaloneShortUCable"
	geometry_parent.add_child(cable_group)

	# The adapter and cable share one finish source. Changing the charger
	# colour therefore recolours the rubber jacket and both moulded connector
	# housings on the next preview rebuild; metal contacts remain metallic.
	var shared_finish := charger_body_color
	var cable_material := _charger_material(shared_finish, 0.0, 0.48)
	var connector_shell := _charger_material(shared_finish, 0.0, 0.34)
	var connector_metal := _charger_material(Color("#c8d1d9"), 0.94, 0.16)
	var device_connector := _charger_device_connector()
	var output_connector := _charger_output_connector()

	var cable_plane_y := 0.035
	var left_head := Vector3(-0.34, cable_plane_y, 0.16)
	var right_head := Vector3(0.34, cable_plane_y, 0.16)
	var left_forward := Vector3(-0.22, 0.0, 1.0).normalized()
	var right_forward := Vector3(0.22, 0.0, 1.0).normalized()
	_add_charger_cable_connector(cable_group, "First_" + output_connector.replace("-", "") + "_CableHead", output_connector, left_head, left_forward, connector_shell, connector_metal)
	_add_charger_cable_connector(cable_group, "Second_" + device_connector.replace("-", "") + "_CableHead", device_connector, right_head, right_forward, connector_shell, connector_metal)

	# The tube centreline begins inside the middle of each strain-relief boot.
	# Its tangent is explicitly aligned with each connector's local cable axis.
	var boot_overlap := 0.245
	var left_boot_exit := left_head - left_forward * boot_overlap
	var right_boot_exit := right_head - right_forward * boot_overlap

	# For each end, the first/last Bezier tangent points directly out of its
	# boot. The previous fixed X offsets pulled the cord sideways out of the
	# boots and produced the two visible end gaps.
	var u_depth := 0.42
	var control_a := left_boot_exit - left_forward * u_depth
	var control_b := right_boot_exit - right_forward * u_depth
	var route := _append_charger_bezier(
		PackedVector3Array(),
		left_boot_exit,
		control_a,
		control_b,
		right_boot_exit,
		128
	)

	var cable := MeshInstance3D.new()
	cable.name = "SingleUnbrokenShortUCableJacket"
	cable.mesh = _create_charger_cable_tube_mesh(route, 0.022, 40)
	cable.material_override = cable_material
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cable_group.add_child(cable)

	return cable_group


func _charger_device_connector() -> String:
	# The phone's actual charging-port selection is authoritative. The cable's
	# device-side plug must never be inferred from a stale cable menu choice.
	match charge_port_type:
		"USB Type-C":
			return "USB-C"
		"Apple Lightning":
			return "Lightning"
		"Micro-USB (Micro-B)":
			return "Micro-USB"
		"Mini-USB (Mini-B)":
			return "Mini-USB"
		"DC Barrel Jack":
			return "DC Barrel"
		_:
			return ""


func _charger_cable_options_for_phone() -> Array[String]:
	var phone_connector := _charger_device_connector()
	if phone_connector.is_empty():
		return []
	return ["USB-C to " + phone_connector, "USB-A to " + phone_connector]


func _rebuild_charger_preview() -> void:
	if not is_instance_valid(charger_preview):
		return
	for child in charger_preview.get_children():
		child.free()

	# Keep the adapter and cable on independent local pivots. Their transforms
	# switch between bold single-product framing and the diagonal complete-set
	# composition used by the product reference.
	var cable_is_compatible := charger_cable_enabled and not _charger_device_connector().is_empty()
	var combined_layout := charger_enabled and cable_is_compatible
	var charger_scale := 0.72 if combined_layout else 1.0
	var charger_geometry := Node3D.new()
	charger_geometry.name = "ChargerGeometryPivot"
	charger_geometry.scale = Vector3.ONE * charger_scale
	charger_geometry.position = Vector3(-0.43, 0.27, 0.0) if combined_layout else Vector3.ZERO
	if combined_layout:
		charger_geometry.rotation_degrees = Vector3(-12.0, -20.0, -22.0)
	charger_preview.add_child(charger_geometry)

	# The actual mesh coordinates are centred at local X=0.88. Put them under
	# a centred child so combined-view rotation turns the adapter in place.
	var charger_model := Node3D.new()
	charger_model.name = "ChargerModelGeometry"
	charger_model.position = Vector3(-0.88, 0.0, 0.0)
	charger_geometry.add_child(charger_model)

	var shell_material := _charger_material(charger_body_color, 0.02, 0.22)
	var face_material := _charger_material(charger_body_color.lightened(0.035), 0.03, 0.20)
	var seam_material := _charger_material(Color("#8795a3"), 0.42, 0.27)
	var metal_material := _charger_material(Color("#c8d1d9"), 0.88, 0.19)
	var accent_material := _charger_material(Color("#78d9ff"), 0.18, 0.16)

	# Build the housing as a CSG shell so the adapter socket is a genuine
	# aperture through the front fascia, not a dark panel laid over solid plastic.
	var output_connector := _charger_output_connector()
	var unit_per_mm := _active_phone_size().y / 150.0
	var port_width := 8.34 * unit_per_mm if output_connector == "USB-C" else 12.0 * unit_per_mm
	var port_height := 2.56 * unit_per_mm if output_connector == "USB-C" else 4.5 * unit_per_mm
	var shell_combiner := CSGCombiner3D.new()
	shell_combiner.name = "ChargerHousingWithRealPortCutout"
	shell_combiner.use_collision = false
	shell_combiner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	charger_model.add_child(shell_combiner)

	var body_shell := CSGMesh3D.new()
	body_shell.name = "ChargerAdapterBody"
	body_shell.operation = CSGShape3D.OPERATION_UNION
	body_shell.mesh = _create_rounded_panel_mesh(0.58, 0.78, 0.29, 0.105)
	body_shell.material = shell_material
	body_shell.position = Vector3(0.88, 0.0, 0.0)
	shell_combiner.add_child(body_shell)

	var front_fascia := CSGMesh3D.new()
	front_fascia.name = "AdapterFacePlate"
	front_fascia.operation = CSGShape3D.OPERATION_UNION
	front_fascia.mesh = _create_rounded_panel_mesh(0.535, 0.725, 0.012, 0.088)
	front_fascia.material = face_material
	front_fascia.position = Vector3(0.88, 0.0, 0.151)
	shell_combiner.add_child(front_fascia)

	var port_cutter := CSGMesh3D.new()
	port_cutter.name = "RoundedPhysicalChargingPortCut"
	port_cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
	port_cutter.mesh = _create_rounded_panel_mesh(port_width * 0.96, port_height * 0.88, 0.22, port_height * 0.30)
	port_cutter.position = Vector3(0.88, 0.015, 0.16)
	shell_combiner.add_child(port_cutter)

	_add_charger_box(charger_model, "HousingSeam", Vector3(0.535, 0.009, 0.008), Vector3(0.88, -0.255, 0.158), seam_material)

	# Machined socket walls and contacts are nested inside the newly cut opening.
	_add_charger_recessed_port(charger_model, output_connector, Vector3(0.88, 0.015, 0.159), metal_material)

	# A restrained status LED and clear wattage marking on the front fascia.
	_add_charger_cylinder(charger_model, "StatusIndicator", 0.012, 0.004, Vector3(0.88, 0.245, 0.160), accent_material, 24)
	var wattage_label := Label3D.new()
	wattage_label.name = "ChargerWattageMark"
	wattage_label.text = "%dW" % charger_wattage
	wattage_label.font_size = 54
	wattage_label.pixel_size = 0.0017
	wattage_label.modulate = Color("#687786")
	wattage_label.position = Vector3(0.88, -0.145, 0.160)
	wattage_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	charger_model.add_child(wattage_label)

	# Real plug geometry sits on the rear face and projects away from the shell.
	match charger_plug_type:
		"UK":
			_add_charger_box(charger_model, "UKLiveProng", Vector3(0.042, 0.145, 0.17), Vector3(0.78, -0.105, -0.23), metal_material)
			_add_charger_box(charger_model, "UKNeutralProng", Vector3(0.042, 0.145, 0.17), Vector3(0.98, -0.105, -0.23), metal_material)
			_add_charger_box(charger_model, "UKEarthProng", Vector3(0.042, 0.155, 0.17), Vector3(0.88, 0.135, -0.23), metal_material)
		"EU":
			var eu_left := _add_charger_cylinder(charger_model, "EUProngLeft", 0.029, 0.17, Vector3(0.81, 0.0, -0.225), metal_material, 32)
			var eu_right := _add_charger_cylinder(charger_model, "EUProngRight", 0.029, 0.17, Vector3(0.95, 0.0, -0.225), metal_material, 32)
			eu_left.rotation_degrees.x = 90.0
			eu_right.rotation_degrees.x = 90.0
		"US":
			_add_charger_box(charger_model, "USProngLeft", Vector3(0.035, 0.15, 0.17), Vector3(0.81, 0.0, -0.23), metal_material)
			_add_charger_box(charger_model, "USProngRight", Vector3(0.035, 0.15, 0.17), Vector3(0.95, 0.0, -0.23), metal_material)
		"Universal":
			_add_charger_box(charger_model, "UniversalProngLeft", Vector3(0.035, 0.15, 0.17), Vector3(0.81, 0.0, -0.23), metal_material)
			_add_charger_box(charger_model, "UniversalProngRight", Vector3(0.035, 0.15, 0.17), Vector3(0.95, 0.0, -0.23), metal_material)

	# The wall adapter and cable are independent systems. In the complete-set
	# view the cable sits lower-right; alone it is centred and enlarged.
	charger_geometry.visible = charger_enabled
	if cable_is_compatible:
		var cable_group := _build_charger_cable(charger_preview, output_connector)
		if combined_layout:
			cable_group.position = Vector3(0.42, -0.31, 0.015)
			cable_group.scale = Vector3.ONE * 0.84
			cable_group.rotation_degrees = Vector3(0.0, 0.0, -3.0)
		else:
			cable_group.position = Vector3.ZERO
			cable_group.scale = Vector3.ONE * (1.08 if not charger_enabled else 1.0)
			cable_group.rotation = Vector3.ZERO
	_update_charger_preview_framing()


func _update_charger_preview_framing() -> void:
	if not is_instance_valid(charger_preview):
		return
	var cable_is_compatible := charger_cable_enabled and not _charger_device_connector().is_empty()
	var combined_layout := charger_enabled and cable_is_compatible
	charger_preview.scale = Vector3.ONE * (1.45 if combined_layout else 1.8)
	charger_preview.visible = charger_preview_mode and (charger_enabled or cable_is_compatible)
	if not is_instance_valid(preview_camera):
		return
	preview_camera.fov = 42.0 if combined_layout else 38.0
	var camera_distance := 4.45 if combined_layout else (4.0 if cable_is_compatible and not charger_enabled else 3.65)
	preview_camera.position = Vector3(0.0, 0.0, camera_distance if charger_preview_mode else 5.2)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _set_smartwatch_preview_mode(enabled: bool) -> void:
	_set_power_bank_preview_mode(false)
	if is_instance_valid(wireless_earbuds_preview):
		wireless_earbuds_preview.visible = false
	wireless_earbuds_preview_mode = false
	smartwatch_preview_mode = enabled
	if is_instance_valid(phone_body):
		phone_body.visible = not enabled and not charger_preview_mode
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible = not enabled and not charger_preview_mode and phone_case_custom_enabled and phone_case_built and not phone_case_building and left_tools_page != 1
	if is_instance_valid(charger_preview):
		charger_preview.visible = not enabled and charger_preview_mode and (charger_enabled or (charger_cable_enabled and not _charger_device_connector().is_empty()))
	if is_instance_valid(smartwatch_preview):
		smartwatch_preview.visible = enabled and smartwatch_enabled
	if is_instance_valid(preview_camera):
		preview_camera.position = Vector3(0.0, 0.0, 4.05 if enabled else 5.2)
		preview_camera.fov = 38.0
		preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _set_charger_preview_mode(enabled: bool) -> void:
	charger_preview_mode = enabled
	if is_instance_valid(wireless_earbuds_preview):
		wireless_earbuds_preview.visible = false
	wireless_earbuds_preview_mode = false
	_set_power_bank_preview_mode(false)
	_set_smartwatch_preview_mode(false)
	if is_instance_valid(phone_body):
		phone_body.visible = not enabled
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible = not enabled and phone_case_custom_enabled and phone_case_built and not phone_case_building and left_tools_page != 1
	if is_instance_valid(charger_preview):
		charger_preview.position = Vector3.ZERO
		if not enabled:
			charger_preview.rotation = Vector3.ZERO
	_update_charger_preview_framing()


func _on_charger_wattage_changed(value: float) -> void:
	# Adapter output is an independent product specification; it must never
	# change the phone's own wired charging capability.
	charger_wattage = clampi(roundi(value), 2, 200)
	if is_instance_valid(charger_wattage_label):
		charger_wattage_label.text = "%d W" % charger_wattage
	_rebuild_charger_preview()


func _on_charger_enabled_toggled(enabled: bool) -> void:
	charger_enabled = enabled
	_rebuild_charger_preview()


func _on_charger_wattage_selected(value: int) -> void:
	charger_wattage = clampi(value, 2, 200)
	_rebuild_charger_preview()
	_show_charger_controls("POWER")


func _on_charger_plug_selected(value: String) -> void:
	if not ["UK", "EU", "US", "Universal"].has(value):
		return
	charger_plug_type = value
	_rebuild_charger_preview()
	_show_charger_controls("PLUG")


func _charger_output_connector() -> String:
	return "USB-A" if charger_cable_type.begins_with("USB-A") else "USB-C"


func _on_charger_cable_enabled_toggled(enabled: bool) -> void:
	charger_cable_enabled = enabled and not _charger_device_connector().is_empty()
	_rebuild_charger_preview()
	var return_page := "HOME" if charger_controls_page == "HOME" else "CABLE"
	_show_charger_controls(return_page)


func _on_charger_cable_selected(value: String) -> void:
	if not _charger_cable_options_for_phone().has(value):
		return
	charger_cable_type = value
	_rebuild_charger_preview()
	_show_charger_controls("CABLE")


func _on_charger_color_selected(value: String) -> void:
	match value:
		"Pearl White":
			charger_body_color = Color("#e8edf2")
		"Graphite":
			charger_body_color = Color("#303943")
		"Midnight Black":
			charger_body_color = Color("#111820")
	_rebuild_charger_preview()
	_show_charger_controls("FINISH")


func _show_charger_controls(page: String = "HOME") -> void:
	if not is_instance_valid(right_tools_content):
		return
	charger_controls_page = page
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ChargerControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	if page != "HOME":
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		active_feature_panel.add_child(header)
		var back := Button.new()
		back.name = "ChargerSettingsBack"
		back.text = "‹"
		back.custom_minimum_size = Vector2(42, 40)
		back.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(back, 24)
		_style_staff_button(back, false)
		back.pressed.connect(_show_charger_controls.bind("HOME"))
		header.add_child(back)
		var page_title := _make_label("CHARGER " + page, 16, Color("#c7eacb"))
		page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(page_title)

		match page:
			"PLUG":
				var plug_heading := _make_label("WALL PLUG STANDARD", 13, Color("#a9e3ff"))
				active_feature_panel.add_child(plug_heading)
				for plug_name in ["UK", "EU", "US", "Universal"]:
					var plug_button := Button.new()
					plug_button.name = "ChargerPlug_" + plug_name
					plug_button.text = plug_name + ("   ✓  SELECTED" if charger_plug_type == plug_name else "")
					plug_button.custom_minimum_size = Vector2(0, 48)
					plug_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					plug_button.focus_mode = Control.FOCUS_NONE
					_apply_research_typography(plug_button, 13)
					_style_staff_button(plug_button, charger_plug_type == plug_name)
					plug_button.pressed.connect(_on_charger_plug_selected.bind(plug_name))
					active_feature_panel.add_child(plug_button)
				var plug_note := _make_label("Changes the physical wall-pin layout on the 3D adapter.", 11, Color("#a9c9dc"))
				plug_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				active_feature_panel.add_child(plug_note)
			"CABLE":
				var cable_heading := _make_label("PHYSICAL CHARGING CABLE", 13, Color("#a9e3ff"))
				active_feature_panel.add_child(cable_heading)
				var cable_enable_row := HBoxContainer.new()
				cable_enable_row.name = "ChargingCableEnableRow"
				cable_enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				active_feature_panel.add_child(cable_enable_row)
				var cable_enable_label := _make_label("ENABLE PHYSICAL CABLE", 13, Color("#e6f5ff"))
				cable_enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cable_enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cable_enable_row.add_child(cable_enable_label)
				var cable_toggle := TextureButton.new()
				cable_toggle.name = "EnableChargingCableModel"
				cable_toggle.custom_minimum_size = Vector2(40, 40)
				cable_toggle.ignore_texture_size = true
				cable_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				cable_toggle.texture_normal = _make_side_button_checkbox_icon(false)
				cable_toggle.texture_hover = _make_side_button_checkbox_icon(false)
				cable_toggle.texture_pressed = _make_side_button_checkbox_icon(true)
				cable_toggle.toggle_mode = true
				cable_toggle.button_pressed = charger_cable_enabled
				cable_toggle.focus_mode = Control.FOCUS_NONE
				cable_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
				cable_toggle.toggled.connect(_on_charger_cable_enabled_toggled)
				cable_enable_row.add_child(cable_toggle)
				var compatible_cable_options := _charger_cable_options_for_phone()
				for cable_name in compatible_cable_options:
					var cable_button := Button.new()
					cable_button.name = "ChargerCable_" + cable_name.replace(" ", "").replace("-", "")
					cable_button.text = cable_name + ("   ✓  SELECTED" if charger_cable_type == cable_name else "")
					cable_button.custom_minimum_size = Vector2(0, 48)
					cable_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cable_button.focus_mode = Control.FOCUS_NONE
					_apply_research_typography(cable_button, 13)
					_style_staff_button(cable_button, charger_cable_type == cable_name)
					cable_button.pressed.connect(_on_charger_cable_selected.bind(cable_name))
					active_feature_panel.add_child(cable_button)
				var cable_note_text := "A short U-shaped cable with a phone-side plug that matches the selected charging port."
				if charge_port_type == "None":
					cable_note_text = "Choose a phone charging port first. The cable connector options will then match it automatically."
				var cable_note := _make_label(cable_note_text, 11, Color("#a9c9dc"))
				cable_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				active_feature_panel.add_child(cable_note)
			"POWER":
				var wattage_heading := _make_label("OUTPUT POWER", 13, Color("#a9e3ff"))
				active_feature_panel.add_child(wattage_heading)
				charger_wattage_label = _make_label("%d W" % charger_wattage, 32, Color.WHITE)
				charger_wattage_label.name = "ChargerOutputWattageValue"
				charger_wattage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				active_feature_panel.add_child(charger_wattage_label)
				var wattage_range := _make_label("2W  —  200W  ·  INDEPENDENT ADAPTER OUTPUT", 11, Color("#a9c9dc"))
				wattage_range.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				active_feature_panel.add_child(wattage_range)
				var slider_row := HBoxContainer.new()
				slider_row.name = "ChargerWattageVerticalSliderRow"
				slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
				slider_row.add_theme_constant_override("separation", 12)
				active_feature_panel.add_child(slider_row)
				var minimum := _make_label("2W", 11, Color("#a9c9dc"))
				minimum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slider_row.add_child(minimum)
				charger_wattage_slider = VSlider.new()
				charger_wattage_slider.name = "ChargerOutputVerticalSlider"
				charger_wattage_slider.min_value = 2
				charger_wattage_slider.max_value = 200
				charger_wattage_slider.step = 1
				charger_wattage_slider.value = charger_wattage
				charger_wattage_slider.custom_minimum_size = Vector2(52, 245)
				charger_wattage_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
				charger_wattage_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				charger_wattage_slider.focus_mode = Control.FOCUS_NONE
				charger_wattage_slider.tick_count = 0
				charger_wattage_slider.value_changed.connect(_on_charger_wattage_changed)
				_style_custom_slider(charger_wattage_slider)
				slider_row.add_child(charger_wattage_slider)
				var maximum := _make_label("200W", 11, Color("#a9c9dc"))
				maximum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slider_row.add_child(maximum)
			"FINISH":
				_show_device_color_controls(false, false, true)
		return

	var heading := _make_label("CHARGER ADAPTER", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Configure the adapter one setting at a time. Drag the centre preview to inspect every side.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)
	var enable_row := HBoxContainer.new()
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(enable_row)
	var enable_label := _make_label("ENABLE CHARGER MODEL", 13, Color("#e6f5ff"))
	enable_row.add_child(enable_label)
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var toggle := TextureButton.new()
	toggle.name = "EnableChargerPreview"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = charger_enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(_on_charger_enabled_toggled)
	enable_row.add_child(toggle)

	var home_cable_enable_row := HBoxContainer.new()
	home_cable_enable_row.name = "HomeChargingCableEnableRow"
	home_cable_enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(home_cable_enable_row)
	var home_cable_enable_label := _make_label("ENABLE PHYSICAL CABLE", 13, Color("#e6f5ff"))
	home_cable_enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_cable_enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_cable_enable_row.add_child(home_cable_enable_label)
	var home_cable_toggle := TextureButton.new()
	home_cable_toggle.name = "EnableChargingCableModelHome"
	home_cable_toggle.custom_minimum_size = Vector2(40, 40)
	home_cable_toggle.ignore_texture_size = true
	home_cable_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	home_cable_toggle.texture_normal = _make_side_button_checkbox_icon(false)
	home_cable_toggle.texture_hover = _make_side_button_checkbox_icon(false)
	home_cable_toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	home_cable_toggle.toggle_mode = true
	home_cable_toggle.button_pressed = charger_cable_enabled
	home_cable_toggle.focus_mode = Control.FOCUS_NONE
	home_cable_toggle.toggled.connect(_on_charger_cable_enabled_toggled)
	home_cable_enable_row.add_child(home_cable_toggle)

	var plug_option := Button.new()
	plug_option.name = "OpenChargerPlugSettings"
	plug_option.text = "PLUG STANDARD     ›     " + charger_plug_type
	plug_option.custom_minimum_size = Vector2(0, 48)
	plug_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plug_option.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(plug_option, 13)
	_style_staff_button(plug_option, false)
	plug_option.pressed.connect(_show_charger_controls.bind("PLUG"))
	active_feature_panel.add_child(plug_option)

	var cable_option := Button.new()
	cable_option.name = "OpenChargerCableSettings"
	cable_option.text = "CABLE TYPE     ›     " + charger_cable_type
	cable_option.custom_minimum_size = Vector2(0, 48)
	cable_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cable_option.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(cable_option, 13)
	_style_staff_button(cable_option, false)
	cable_option.pressed.connect(_show_charger_controls.bind("CABLE"))
	active_feature_panel.add_child(cable_option)

	var power_option := Button.new()
	power_option.name = "OpenChargerPowerSettings"
	power_option.text = "OUTPUT POWER     ›     %d W" % charger_wattage
	power_option.custom_minimum_size = Vector2(0, 48)
	power_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_option.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(power_option, 13)
	_style_staff_button(power_option, false)
	power_option.pressed.connect(_show_charger_controls.bind("POWER"))
	active_feature_panel.add_child(power_option)

	var finish_name := "Pearl White" if charger_body_color == Color("#e8edf2") else ("Graphite" if charger_body_color == Color("#303943") else "Midnight Black")
	var finish_option := Button.new()
	finish_option.name = "OpenChargerFinishSettings"
	finish_option.text = "ADAPTER COLOR     ›     " + finish_name
	finish_option.custom_minimum_size = Vector2(0, 48)
	finish_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finish_option.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(finish_option, 13)
	_style_staff_button(finish_option, false)
	finish_option.pressed.connect(_show_device_color_controls.bind(false, false, true))
	active_feature_panel.add_child(finish_option)


func _show_screen_protector_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ScreenProtectorControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("PROTECTION GLASS", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("A precision-cut tempered-glass layer fitted to the active display and front-camera layout.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	var enable_row := HBoxContainer.new()
	enable_row.name = "ScreenProtectorEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 9)
	active_feature_panel.add_child(enable_row)
	var enable_label := _make_label("INSTALL PROTECTION GLASS", 13, Color("#e6f5ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)
	var toggle := TextureButton.new()
	toggle.name = "EnableProtectionGlass"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = screen_protector_enabled
	toggle.disabled = not screen_enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(_on_screen_protector_toggled)
	enable_row.add_child(toggle)

	if not screen_enabled:
		var screen_hint := _make_label("Enable the screen first. Protection glass will fit the active display surfaces.", 12, Color("#f1ca82"))
		screen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		active_feature_panel.add_child(screen_hint)
		return

	if not screen_protector_enabled:
		var disabled_note := _make_label("Switch on protection glass to install the fitted 3D layer.", 12, Color("#a9c9dc"))
		disabled_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		active_feature_panel.add_child(disabled_note)
		return

	var finish_heading := _make_label("GLASS FINISH", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(finish_heading)
	for finish_name in ["Ultra Clear", "Matte", "Anti-Reflective"]:
		var finish_button := Button.new()
		finish_button.name = "ProtectorFinish_" + finish_name.replace("-", "").replace(" ", "")
		finish_button.text = finish_name.to_upper() + ("   ✓" if screen_protector_finish == finish_name else "")
		finish_button.custom_minimum_size = Vector2(0, 42)
		finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		finish_button.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(finish_button, 12)
		_style_staff_button(finish_button, screen_protector_finish == finish_name)
		finish_button.pressed.connect(_on_screen_protector_finish_selected.bind(finish_name))
		active_feature_panel.add_child(finish_button)

	var thickness_heading := _make_label("GLASS THICKNESS", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(thickness_heading)
	screen_protector_thickness_label = _make_label("", 12, Color("#d8eaf5"))
	screen_protector_thickness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(screen_protector_thickness_label)
	var thickness_slider := HSlider.new()
	thickness_slider.name = "ProtectionGlassThicknessSlider"
	thickness_slider.min_value = 0.003
	thickness_slider.max_value = 0.009
	thickness_slider.step = 0.0005
	thickness_slider.value = screen_protector_thickness
	thickness_slider.custom_minimum_size = Vector2(0, 38)
	thickness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_custom_slider(thickness_slider)
	thickness_slider.value_changed.connect(_on_screen_protector_thickness_changed)
	active_feature_panel.add_child(thickness_slider)
	_update_screen_protector_thickness_label()

	if screen_protector_building:
		# Match the Phone Case build card exactly: same framed panel, typography,
		# animated shader shimmer and supporting build note.
		var panel := PanelContainer.new()
		panel.name = "ProtectionGlassBuildLoading"
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#0c2a16")
		style.border_color = Color("#2d7540")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", style)
		active_feature_panel.add_child(panel)
		var loading := VBoxContainer.new()
		loading.add_theme_constant_override("separation", 9)
		panel.add_child(loading)
		var text_label := _make_label("Building protection glass", 16, Color("#eaf8ff"))
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loading.add_child(text_label)
		var shimmer := ColorRect.new()
		shimmer.name = "ProtectionGlassBuildShimmer"
		shimmer.custom_minimum_size = Vector2(0, 12)
		shimmer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.10,0.30,0.44,1.0);
uniform vec4 shine_color : source_color = vec4(0.48,0.82,1.0,1.0);
void fragment(){
	float sweep=fract(UV.x*1.25-TIME*0.72);
	float shine=smoothstep(0.02,0.18,sweep)*(1.0-smoothstep(0.22,0.42,sweep));
	COLOR=mix(base_color,shine_color,shine*0.9);
}
"""
		var shimmer_material := ShaderMaterial.new()
		shimmer_material.shader = shader
		shimmer.material = shimmer_material
		loading.add_child(shimmer)
		var building_note := _make_label("Matching the display shape, curves and front-camera cutouts…", 11, Color("#a9d9ad"))
		building_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		building_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		loading.add_child(building_note)
	var cutout_note := _make_label("CAMERA & SENSOR CUTOUTS  ·  AUTO-FITTED", 11, Color("#8bd696"))
	cutout_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cutout_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(cutout_note)


func _refresh_phone_screen() -> void:
	if not is_instance_valid(phone_body):
		return
	var foldable_protector_token := -1
	if selected_phone_type != "Standard" and screen_protector_enabled:
		screen_protector_build_token += 1
		foldable_protector_token = screen_protector_build_token
	var previous := phone_body.get_node_or_null("PhoneDisplayPanel")
	if is_instance_valid(previous):
		previous.free()
	var old_moving_display := phone_body.find_child("PhoneFoldableMovingDisplay", true, false)
	if is_instance_valid(old_moving_display):
		old_moving_display.free()
	var previous_outer := phone_body.find_child("PhoneOuterDisplayPanel", true, false)
	if is_instance_valid(previous_outer):
		previous_outer.free()
	phone_screen = null
	if not screen_enabled:
		_refresh_phone_home_button()
		return
	if selected_phone_type != "Standard":
		_build_foldable_inner_screens(foldable_protector_token)
		_refresh_phone_home_button()
		_build_phone_outer_display(foldable_protector_token)
		_route_foldable_accessories()
		_apply_phone_fold_angle()
		_queue_phone_case_sync()
		return

	var display := MeshInstance3D.new()
	display.name = "PhoneDisplayPanel"
	# Keep a consistent, slimmer lower rail for physical keys and give the
	# top rail the exact same height. The glass is inset evenly on all sides.
	# Symmetrical bezels consume the outer edges; the display fills the remaining area.
	var screen_width := _active_phone_size().x if screen_shape_mode == "Curve screen" and side_curve_enabled else maxf(0.30, _active_phone_size().x - bezel_width * 2.0)
	var screen_height := _active_phone_size().y if screen_shape_mode == "Curve screen" and vertical_curve_enabled else maxf(0.60, _active_phone_size().y - bezel_height * 2.0)
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
	var current_depth := _phone_depth_for_thickness_level()
	var curved_display := screen_shape_mode == "Curve screen" and (side_curve_enabled or vertical_curve_enabled)
	display.position = Vector3(0.0, 0.0, current_depth * 0.5 + (0.0315 if curved_display else 0.0035))
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	phone_body.add_child(display)
	phone_screen = display
	if selected_phone_type != "Standard":
		_add_foldable_inner_crease(display, screen_width, screen_height)
	_refresh_front_camera(display, screen_width, screen_height)
	if screen_protector_enabled:
		_build_screen_protector(display, screen_width, screen_height, screen_radius, curved_display)
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
	_build_phone_outer_display()
	_route_foldable_accessories()
	_queue_phone_case_sync()


func _add_foldable_inner_crease(display: MeshInstance3D, screen_width: float, screen_height: float) -> void:
	var crease := MeshInstance3D.new()
	crease.name = "FoldableInnerDisplayCrease"
	var crease_mesh := BoxMesh.new()
	if selected_phone_type == "Fold":
		crease_mesh.size = Vector3(0.009, screen_height * 0.97, 0.002)
	else:
		crease_mesh.size = Vector3(screen_width * 0.97, 0.009, 0.002)
	crease.mesh = crease_mesh
	var crease_material := StandardMaterial3D.new()
	crease_material.albedo_color = Color(0.018, 0.030, 0.045, 0.23)
	crease_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crease_material.roughness = 0.18
	crease_material.metallic = 0.12
	crease.material_override = crease_material
	crease.position.z = 0.004
	crease.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.add_child(crease)

	var highlight := MeshInstance3D.new()
	highlight.name = "FoldableCreaseHighlight"
	var highlight_mesh := BoxMesh.new()
	if selected_phone_type == "Fold":
		highlight_mesh.size = Vector3(0.0015, screen_height * 0.94, 0.001)
		highlight.position.x = 0.009
	else:
		highlight_mesh.size = Vector3(screen_width * 0.94, 0.0015, 0.001)
		highlight.position.y = 0.009
	highlight.mesh = highlight_mesh
	var highlight_material := StandardMaterial3D.new()
	highlight_material.albedo_color = Color(0.56, 0.78, 0.91, 0.22)
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.roughness = 0.22
	highlight.material_override = highlight_material
	highlight.position.z = 0.0055
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display.add_child(highlight)


func _build_phone_outer_display(shared_protector_token: int = -1) -> void:
	if not is_instance_valid(phone_body) or not screen_enabled or selected_phone_type == "Standard":
		return
	var outer_root := Node3D.new()
	outer_root.name = "PhoneOuterDisplayPanel"
	var outer_parent: Node = phone_body
	if selected_phone_type == "Fold":
		# Place the Fold cover display on the fixed (left) chassis leaf.
		var fixed_half := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableFixedHalf")
		if is_instance_valid(fixed_half):
			outer_parent = fixed_half
	else:
		# Flip keeps its cover display attached to the moving leaf.
		var moving_half := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableMovingHalf")
		if is_instance_valid(moving_half):
			outer_parent = moving_half
	outer_parent.add_child(outer_root)

	var panel_width: float
	var panel_height: float
	var center_x := 0.0
	var center_y := 0.0
	var chassis_layout := _get_foldable_segment_layout()
	var fixed_offset: Vector3 = chassis_layout["fixed_offset"]
	var moving_offset: Vector3 = chassis_layout["moving_offset"]
	if selected_phone_type == "Fold":
		panel_width = (_active_phone_size().x - 0.014) * 0.5 - 0.12
		panel_height = _active_phone_size().y - 0.20
		center_x = fixed_offset.x
	else:
		panel_width = _active_phone_size().x - 0.18
		panel_height = (_active_phone_size().y - 0.014) * 0.5 - 0.12
		center_y = moving_offset.y
	panel_width = maxf(0.28, panel_width)
	panel_height = maxf(0.42, panel_height)
	var current_depth := _phone_depth_for_thickness_level()
	# The cover display is rotated 180 degrees to face outward. That
	# rotation mirrors left/right corner indices, so Fold must use the
	# opposite half-mask; Flip's top/bottom mask is unchanged by it.
	# The cover glass is turned outward. Fold's cover is now on the fixed
	# leaf, so its local corner mask must be the opposite of the fixed frame;
	# Flip remains on the moving leaf and uses that leaf's own outside corners.
	var outer_corner_mask := _foldable_half_corner_mask(true)
	var radius := minf(0.32 * float(border_radius_level) / 6.0, minf(panel_width, panel_height) * 0.45)

	var bezel := MeshInstance3D.new()
	bezel.name = "OuterDisplayBezel"
	bezel.mesh = _create_rounded_panel_mesh(panel_width + 0.035, panel_height + 0.035, 0.008, radius + 0.012, outer_corner_mask)
	var bezel_material := StandardMaterial3D.new()
	bezel_material.albedo_color = Color("#202b36")
	bezel_material.metallic = 0.44
	bezel_material.roughness = 0.25
	bezel.material_override = bezel_material
	bezel.rotation.y = PI
	bezel.position = Vector3(center_x, center_y, -current_depth * 0.5 - 0.002)
	bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outer_root.add_child(bezel)

	var glass := MeshInstance3D.new()
	glass.name = "OuterDisplayGlass"
	glass.mesh = _create_rounded_panel_mesh(panel_width, panel_height, 0.004, radius, outer_corner_mask)
	var glass_material := StandardMaterial3D.new()
	var screen_colors := {
		"TFT LCD": Color("#263746"), "LED-LCD": Color("#223342"),
		"IPS LCD": Color("#1d2d3d"), "Mini-LED LCD": Color("#172535"),
		"OLED": Color("#111b28"), "AMOLED": Color("#0e1723"),
		"Super AMOLED": Color("#0b131f"), "Dynamic AMOLED": Color("#09111d"),
		"LTPO AMOLED": Color("#080f1b"), "MicroLED": Color("#070d18")
	}
	glass_material.albedo_color = screen_colors.get(selected_screen_type, Color("#0e1723"))
	glass_material.roughness = 0.075 if selected_screen_type in ["Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"] else 0.15
	glass_material.metallic = 0.10
	glass_material.metallic_specular = 0.82
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.emission_enabled = true
	glass_material.emission = glass_material.albedo_color
	glass_material.emission_energy_multiplier = 0.025
	glass.material_override = glass_material
	glass.rotation.y = PI
	glass.position = Vector3(center_x, center_y, -current_depth * 0.5 - 0.008)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outer_root.add_child(glass)
	if screen_protector_enabled:
		_build_screen_protector(glass, panel_width, panel_height, radius, false, shared_protector_token, false, outer_corner_mask)

	# Use the same configurable front-camera assembly as the inner display.
	# Because the cover glass is rotated 180 degrees to face outward, parenting
	# the assembly to the glass keeps the lens, notch, island and sensors on the
	# visible outer-screen surface with the selected camera style and dimensions.
	_refresh_front_camera(glass, panel_width, panel_height)


func _build_foldable_inner_screens(shared_protector_token: int = -1) -> void:
	var panels := phone_body.get_node_or_null("PhoneFoldablePanels")
	if not is_instance_valid(panels):
		_refresh_foldable_hardware()
		panels = phone_body.get_node_or_null("PhoneFoldablePanels")
	if not is_instance_valid(panels):
		return
	var fixed_half := panels.get_node_or_null("PhoneFoldableFixedHalf")
	var moving_half := panels.get_node_or_null("PhoneFoldableMovingHalf")
	if not is_instance_valid(fixed_half) or not is_instance_valid(moving_half):
		return

	var full_width := maxf(0.30, _active_phone_size().x - bezel_width * 2.0)
	var full_height := maxf(0.60, _active_phone_size().y - bezel_height * 2.0)
	# Keep the two inner glass edges anchored to the hinge. Screen WIDTH may
	# move only the outside edges; it must never pull either hinge-side edge
	# away from the centre seam. Screen HEIGHT keeps its existing behaviour.
	# Keep only a physically plausible hairline at the fold. The matching
	# OLED bridge below fills this tolerance so the open device reads as one
	# continuous panel instead of two separate screens.
	const INNER_HINGE_SCREEN_GAP := 0.018
	var hinge_half_gap := INNER_HINGE_SCREEN_GAP * 0.5
	var segment_width := full_width
	var segment_height := full_height
	var fixed_offset := Vector3.ZERO
	var moving_offset := Vector3.ZERO
	if selected_phone_type == "Fold":
		# Book-style Fold: anchor the left/right inner edges at +/- hinge_half_gap.
		segment_width = maxf(0.30, (full_width - INNER_HINGE_SCREEN_GAP) * 0.5)
		var fixed_inner_edge := -hinge_half_gap
		var moving_inner_edge := hinge_half_gap
		fixed_offset.x = fixed_inner_edge - segment_width * 0.5
		moving_offset.x = moving_inner_edge + segment_width * 0.5
	else:
		# Clamshell Flip: preserve the existing height split and its hinge gap.
		# Width changes only the two outside (left/right) edges of both displays.
		segment_height = maxf(0.60, (full_height - INNER_HINGE_SCREEN_GAP) * 0.5)
		var fixed_inner_edge := -hinge_half_gap
		var moving_inner_edge := hinge_half_gap
		fixed_offset.y = fixed_inner_edge - segment_height * 0.5
		moving_offset.y = moving_inner_edge + segment_height * 0.5

	var current_depth := _phone_depth_for_thickness_level()
	var screen_radius := 0.32 * float(border_radius_level) / 6.0
	var foldable_curve_active := screen_shape_mode == "Curve screen" and (side_curve_enabled or vertical_curve_enabled)
	# Match Standard-phone Curve screen sizing: enabled curve directions run
	# right to the physical outer chassis edge (no inset bezel). The hinge-side
	# edge remains a straight seam between the two independent display halves.
	if foldable_curve_active:
		if selected_phone_type == "Fold" and vertical_curve_enabled:
			segment_height = full_height
			fixed_offset.y = 0.0
			moving_offset.y = 0.0
		elif selected_phone_type == "Flip" and side_curve_enabled:
			segment_width = full_width
			fixed_offset.x = 0.0
			moving_offset.x = 0.0
	# Standard's curved display sits at this same front-glass offset.
	var glass_z := current_depth * 0.5 + (0.0315 if foldable_curve_active else 0.0035)
	var fixed_corner_mask := _foldable_half_corner_mask(false)
	var moving_corner_mask := _foldable_half_corner_mask(true)
	var colors := {
		"TFT LCD": Color("#263746"), "LED-LCD": Color("#223342"),
		"IPS LCD": Color("#1d2d3d"), "Mini-LED LCD": Color("#172535"),
		"OLED": Color("#111b28"), "AMOLED": Color("#0e1723"),
		"Super AMOLED": Color("#0b131f"), "Dynamic AMOLED": Color("#09111d"),
		"LTPO AMOLED": Color("#080f1b"), "MicroLED": Color("#070d18")
	}
	var roughness := {
		"TFT LCD": 0.30, "LED-LCD": 0.27, "IPS LCD": 0.24,
		"Mini-LED LCD": 0.19, "OLED": 0.15, "AMOLED": 0.11,
		"Super AMOLED": 0.075, "Dynamic AMOLED": 0.060,
		"LTPO AMOLED": 0.045, "MicroLED": 0.035
	}
	var display_material := StandardMaterial3D.new()
	display_material.albedo_color = colors.get(selected_screen_type, Color("#0e1723"))
	display_material.roughness = roughness.get(selected_screen_type, 0.12)
	display_material.metallic = 0.18 if selected_screen_type in ["Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"] else 0.04
	display_material.metallic_specular = 0.85 if selected_screen_type in ["Super AMOLED", "Dynamic AMOLED", "LTPO AMOLED", "MicroLED"] else 0.55
	display_material.emission_enabled = true
	display_material.emission = display_material.albedo_color
	display_material.emission_energy_multiplier = 0.025
	display_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var display_root := Node3D.new()
	display_root.name = "PhoneDisplayPanel"
	phone_body.add_child(display_root)
	var fixed_display := MeshInstance3D.new()
	fixed_display.name = "FixedInnerDisplay"
	# Curves belong only to the outside perimeter of the complete handset.
	# The edge touching the hinge must stay flat on both halves.
	var fixed_curve_left := selected_phone_type == "Fold"
	var fixed_curve_right := selected_phone_type == "Flip"
	var fixed_curve_top := selected_phone_type == "Flip"
	var fixed_curve_bottom := selected_phone_type == "Flip"
	if foldable_curve_active:
		fixed_display.mesh = _create_curved_screen_mesh(segment_width, segment_height, screen_radius, side_curve_enabled, vertical_curve_enabled, fixed_curve_left, fixed_curve_right, fixed_curve_top, fixed_curve_bottom, fixed_corner_mask)
	else:
		fixed_display.mesh = _create_rounded_panel_mesh(segment_width, segment_height, 0.006, screen_radius, fixed_corner_mask)
	fixed_display.material_override = display_material
	fixed_display.position = fixed_offset + Vector3(0.0, 0.0, glass_z)
	fixed_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display_root.add_child(fixed_display)
	var moving_display := MeshInstance3D.new()
	moving_display.name = "PhoneFoldableMovingDisplay"
	var moving_curve_left := selected_phone_type == "Flip"
	var moving_curve_right := selected_phone_type == "Fold"
	var moving_curve_top := selected_phone_type == "Flip"
	var moving_curve_bottom := selected_phone_type == "Flip"
	if foldable_curve_active:
		moving_display.mesh = _create_curved_screen_mesh(segment_width, segment_height, screen_radius, side_curve_enabled, vertical_curve_enabled, moving_curve_left, moving_curve_right, moving_curve_top, moving_curve_bottom, moving_corner_mask)
	else:
		moving_display.mesh = _create_rounded_panel_mesh(segment_width, segment_height, 0.006, screen_radius, moving_corner_mask)
	moving_display.material_override = display_material
	moving_display.position = moving_offset + Vector3(0.0, 0.0, glass_z)
	moving_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moving_half.add_child(moving_display)
	phone_screen = fixed_display

	# The two physical display leaves retain their own meshes for folding, but
	# a glass-matched OLED bridge fills the tiny hinge tolerance when fully
	# open. This removes the dark chassis/hinge stripe from the viewing area.
	var inner_bridge := MeshInstance3D.new()
	inner_bridge.name = "ContinuousInnerDisplayBridge"
	if selected_phone_type == "Fold":
		inner_bridge.mesh = _create_rounded_panel_mesh(INNER_HINGE_SCREEN_GAP, segment_height, 0.006, 0.001, 0)
	else:
		inner_bridge.mesh = _create_rounded_panel_mesh(segment_width, INNER_HINGE_SCREEN_GAP, 0.006, 0.001, 0)
	inner_bridge.material_override = display_material
	inner_bridge.position = Vector3(0.0, 0.0, glass_z)
	inner_bridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display_root.add_child(inner_bridge)

	# Keep a natural fold line, but reduce it to a very fine, low-contrast
	# crease. The previous broad dark strip made the two panels look detached.
	var crease := MeshInstance3D.new()
	crease.name = "PhoneFoldableInnerCrease"
	var crease_mesh := BoxMesh.new()
	if selected_phone_type == "Fold":
		crease_mesh.size = Vector3(0.0012, segment_height * 0.96, 0.001)
	else:
		crease_mesh.size = Vector3(segment_width * 0.96, 0.0012, 0.001)
	crease.mesh = crease_mesh
	var crease_material := StandardMaterial3D.new()
	crease_material.albedo_color = Color(0.018, 0.030, 0.045, 0.12)
	crease_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crease_material.roughness = 0.24
	crease_material.metallic = 0.04
	crease.material_override = crease_material
	crease.position = Vector3(0.0, 0.0, glass_z + 0.004)
	crease.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display_root.add_child(crease)
	var crease_glint := MeshInstance3D.new()
	crease_glint.name = "PhoneFoldableCreaseHighlight"
	var glint_mesh := BoxMesh.new()
	if selected_phone_type == "Fold":
		glint_mesh.size = Vector3(0.00045, segment_height * 0.94, 0.0005)
		crease_glint.position.x = 0.0010
	else:
		glint_mesh.size = Vector3(segment_width * 0.94, 0.00045, 0.0005)
		crease_glint.position.y = 0.0010
	crease_glint.mesh = glint_mesh
	var glint_material := StandardMaterial3D.new()
	glint_material.albedo_color = Color(0.56, 0.78, 0.91, 0.08)
	glint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glint_material.roughness = 0.24
	crease_glint.material_override = glint_material
	crease_glint.position.z = glass_z + 0.006
	crease_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	display_root.add_child(crease_glint)
	var camera_display := moving_display if selected_phone_type == "Flip" else fixed_display
	_refresh_front_camera(camera_display, segment_width, segment_height)
	if screen_protector_enabled:
		var shared_token := shared_protector_token
		if shared_token < 0:
			screen_protector_build_token += 1
			shared_token = screen_protector_build_token
		var fixed_has_camera_cutout := selected_phone_type != "Flip"
		var moving_has_camera_cutout := selected_phone_type == "Flip"
		_build_screen_protector(fixed_display, segment_width, segment_height, screen_radius, foldable_curve_active, shared_token, fixed_has_camera_cutout, fixed_corner_mask, fixed_curve_left, fixed_curve_right, fixed_curve_top, fixed_curve_bottom)
		_build_screen_protector(moving_display, segment_width, segment_height, screen_radius, foldable_curve_active, shared_token, moving_has_camera_cutout, moving_corner_mask, moving_curve_left, moving_curve_right, moving_curve_top, moving_curve_bottom)


func _camera_mp_from_slider_index(index: int) -> int:
	return CAMERA_MEGAPIXEL_STEPS[clampi(index, 0, CAMERA_MEGAPIXEL_STEPS.size() - 1)]


func _camera_mp_slider_index(megapixels: int) -> int:
	var closest_index := 0
	var closest_distance := 2147483647
	for index in range(CAMERA_MEGAPIXEL_STEPS.size()):
		var distance := absi(CAMERA_MEGAPIXEL_STEPS[index] - megapixels)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _style_camera_mp_slider(slider: VSlider) -> void:
	_style_custom_slider(slider)


func _make_camera_mp_slider_card(title_text: String, current_mp: int, callback: Callable) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(34, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 2)
	var title := _make_label(title_text, 11, Color("#c7eacb"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	card.add_child(title)
	var value_label := _make_label("%d MP" % current_mp, 12, Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(value_label)
	var high_label := _make_label("%d" % CAMERA_MEGAPIXEL_STEPS[CAMERA_MEGAPIXEL_STEPS.size() - 1], 9, Color("#91b8cc"))
	high_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(high_label)
	var slider := VSlider.new()
	slider.min_value = 0
	slider.max_value = CAMERA_MEGAPIXEL_STEPS.size() - 1
	slider.step = 1
	slider.value = _camera_mp_slider_index(current_mp)
	slider.custom_minimum_size = Vector2(30, 245)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_camera_mp_slider(slider)
	slider.value_changed.connect(func(value: float) -> void:
		var megapixels := _camera_mp_from_slider_index(roundi(value))
		value_label.text = "%d MP" % megapixels
		callback.call(megapixels)
	)
	card.add_child(slider)
	var low_label := _make_label("%d" % CAMERA_MEGAPIXEL_STEPS[0], 9, Color("#91b8cc"))
	low_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(low_label)
	return card


func _show_front_camera_mp_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "FrontCameraMegapixelControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 6)
	right_tools_content.add_child(active_feature_panel)
	var heading := _make_label("FRONT CAMERA MP", 16, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	if not front_camera_enabled:
		var hint := _make_label("Enable the front camera in HARDWARE.", 13, Color("#d8eaf5"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(hint)
		return
	var row := HBoxContainer.new()
	row.name = "FrontCameraMegapixelSliderRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)
	active_feature_panel.add_child(row)
	row.add_child(_make_camera_mp_slider_card("01", front_camera_megapixels, func(megapixels: int) -> void:
		front_camera_megapixels = megapixels
		_update_camera_software_summary()
	))
	if front_camera_style == "Dual Punch-Hole":
		row.add_child(_make_camera_mp_slider_card("02", front_camera_secondary_megapixels, func(megapixels: int) -> void:
			front_camera_secondary_megapixels = megapixels
			_update_camera_software_summary()
		))


func _show_rear_camera_mp_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "RearCameraMegapixelControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 4)
	right_tools_content.add_child(active_feature_panel)
	var heading := _make_label("REAR CAMERA MP", 16, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	if rear_camera_modules.is_empty():
		var hint := _make_label("Add rear cameras in HARDWARE.", 13, Color("#d8eaf5"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(hint)
		return
	var slider_row := HBoxContainer.new()
	slider_row.name = "RearCameraMegapixelSliders"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 2)
	active_feature_panel.add_child(slider_row)
	for camera_index in range(rear_camera_modules.size()):
		var camera_data: Dictionary = rear_camera_modules[camera_index]
		var camera_id := int(camera_data.get("id", camera_index + 1))
		var megapixels := int(camera_data.get("mp", 12))
		slider_row.add_child(_make_camera_mp_slider_card("%02d" % (camera_index + 1), megapixels, func(next_mp: int) -> void:
			for module_index in range(rear_camera_modules.size()):
				if int(rear_camera_modules[module_index].get("id", -1)) == camera_id:
					rear_camera_modules[module_index]["mp"] = next_mp
					break
			_update_camera_software_summary()
		))


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

	var title := _make_label("FRONT CAMERA", 19, Color("#c7eacb"))
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
		toggle_style.bg_color = Color("#174b28") if state != "hover" else Color("#205d37")
		if state == "pressed" or state == "focus":
			toggle_style.bg_color = Color("#168343")
		toggle_style.border_color = Color("#8fd8a1")
		toggle_style.set_border_width_all(2)
		toggle_style.set_corner_radius_all(7)
		enable_toggle.add_theme_stylebox_override(state, toggle_style)
	enable_toggle.add_theme_color_override("font_color", Color.WHITE)
	enable_toggle.toggled.connect(_on_front_camera_enablement_toggled)
	enable_row.add_child(enable_toggle)

	var enable_label := _make_label("Front Camera Enablement", 14, Color.WHITE)
	enable_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enable_row.add_child(enable_label)

	var style_list := GridContainer.new()
	style_list.name = "FrontCameraStyles"
	style_list.columns = 2
	style_list.add_theme_constant_override("h_separation", 7)
	style_list.add_theme_constant_override("v_separation", 7)
	style_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_update_camera_software_summary()
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
	_update_camera_software_summary()
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
			var phone_front_z := _phone_depth_for_thickness_level() * 0.5
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
			var popup_y := _active_phone_size().y * 0.5 + 0.055
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


func _style_custom_slider(slider: Slider) -> void:
	# One premium DigitalWorld slider treatment for every horizontal and vertical control.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#123b20")
	track.border_color = Color("#8fd8a1")
	track.set_border_width_all(2)
	track.set_corner_radius_all(12)
	track.content_margin_left = 6
	track.content_margin_right = 6
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)

	var grabber_gradient := Gradient.new()
	grabber_gradient.set_color(0, Color("#ffffff"))
	grabber_gradient.set_color(1, Color("#65c982"))
	var grabber_texture := GradientTexture2D.new()
	grabber_texture.gradient = grabber_gradient
	grabber_texture.width = 32
	grabber_texture.height = 32
	grabber_texture.fill_from = Vector2(0.0, 0.0)
	grabber_texture.fill_to = Vector2(1.0, 1.0)
	slider.add_theme_icon_override("grabber", grabber_texture)
	slider.add_theme_icon_override("grabber_highlight", grabber_texture)
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.editable = true




func _show_rear_camera_controls() -> void:
	_close_rear_hardware_selection_popup()
	if is_instance_valid(rear_hardware_selection_popup):
		rear_hardware_selection_popup.queue_free()
		rear_hardware_selection_popup = null
		rear_hardware_selection_scroll = null
		rear_hardware_selection_items = null
	if is_instance_valid(rear_hardware_popup_layer):
		rear_hardware_popup_layer.queue_free()
		rear_hardware_popup_layer = null

	var panel_host := active_feature_panel.get_parent() as Control if is_instance_valid(active_feature_panel) else right_tools_content
	if not is_instance_valid(panel_host):
		panel_host = right_tools_content
	if not is_instance_valid(panel_host):
		return
	if is_instance_valid(active_feature_panel) and active_feature_panel.get_parent() == panel_host:
		panel_host.remove_child(active_feature_panel)
		active_feature_panel.queue_free()
	if panel_host == right_tools_content:
		for old_child in right_tools_content.get_children():
			old_child.queue_free()

	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 560.0 or viewport_size.x < 520.0
	var control_height := 40.0 if tight else 44.0
	var button_font_size := 12 if tight else 13

	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "RearCameraFlashControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 7 if tight else 9)
	panel_host.add_child(active_feature_panel)

	var heading := _make_label("REAR CAMERA & FLASH", 16, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	# Mode switchers lead the workspace so Camera/Flash is the first decision.
	var modes := HBoxContainer.new()
	modes.name = "RearHardwareModeSwitchers"
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(modes)
	for mode in ["CAMERA", "FLASH"]:
		var mode_button := Button.new()
		mode_button.name = "RearHardwareMode%s" % mode.capitalize()
		mode_button.text = mode
		mode_button.custom_minimum_size = Vector2(0, 36 if tight else 39)
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.focus_mode = Control.FOCUS_NONE
		_apply_research_typography(mode_button, button_font_size)
		_style_back_design_button(mode_button, rear_hardware_mode == mode)
		mode_button.pressed.connect(_set_rear_hardware_mode.bind(mode))
		modes.add_child(mode_button)

	# Component management follows the mode switchers.
	var management := HBoxContainer.new()
	management.name = "RearHardwareManagementStrip"
	management.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	management.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(management)

	rear_hardware_selection_button = Button.new()
	rear_hardware_selection_button.name = "RearHardwareItemSelector"
	rear_hardware_selection_button.text = "CAMERA  ▼" if rear_hardware_mode == "CAMERA" else "FLASH  ▼"
	rear_hardware_selection_button.custom_minimum_size = Vector2(0, control_height)
	rear_hardware_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(rear_hardware_selection_button, button_font_size)
	_style_back_design_button(rear_hardware_selection_button, true)
	rear_hardware_selection_button.pressed.connect(_toggle_rear_hardware_selection_popup)
	management.add_child(rear_hardware_selection_button)

	rear_hardware_selection_popup = PanelContainer.new()
	rear_hardware_selection_popup.name = "RearHardwareItemDropdown"
	rear_hardware_selection_popup.visible = false
	rear_hardware_selection_popup.z_index = 4096
	rear_hardware_selection_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var dropdown_style := StyleBoxFlat.new()
	dropdown_style.bg_color = Color("#07190d")
	dropdown_style.border_color = Color("#65d783")
	dropdown_style.set_border_width_all(2)
	dropdown_style.set_corner_radius_all(12)
	dropdown_style.content_margin_left = 8
	dropdown_style.content_margin_right = 8
	dropdown_style.content_margin_top = 8
	dropdown_style.content_margin_bottom = 8
	rear_hardware_selection_popup.add_theme_stylebox_override("panel", dropdown_style)
	rear_hardware_selection_scroll = ScrollContainer.new()
	rear_hardware_selection_scroll.name = "RearHardwareDropdownScroll"
	rear_hardware_selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rear_hardware_selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rear_hardware_selection_scroll.follow_focus = false
	rear_hardware_selection_scroll.scroll_deadzone = 2
	rear_hardware_selection_scroll.clip_contents = true
	rear_hardware_selection_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	var dropdown_scroll_bar := rear_hardware_selection_scroll.get_v_scroll_bar()
	dropdown_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	dropdown_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rear_hardware_selection_popup.add_child(rear_hardware_selection_scroll)
	rear_hardware_selection_items = VBoxContainer.new()
	rear_hardware_selection_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_items.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rear_hardware_selection_items.add_theme_constant_override("separation", 7)
	rear_hardware_selection_scroll.add_child(rear_hardware_selection_items)
	if worksite_creation_mode:
		# The legacy editor CanvasLayer is deliberately hidden in the new worksite.
		# Host the dropdown on its own visible layer so it can overlay the cached
		# step panel instead of being trapped beneath the hidden interface.
		rear_hardware_popup_layer = CanvasLayer.new()
		rear_hardware_popup_layer.name = "RearHardwareDropdownLayer"
		rear_hardware_popup_layer.layer = 60
		add_child(rear_hardware_popup_layer)
		rear_hardware_popup_layer.add_child(rear_hardware_selection_popup)
	else:
		var editor_root := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
		if is_instance_valid(editor_root):
			editor_root.add_child(rear_hardware_selection_popup)
		else:
			active_feature_panel.add_child(rear_hardware_selection_popup)

	# Size is now a full-width horizontal control directly below management.
	var size_section := VBoxContainer.new()
	size_section.name = "RearHardwareSizeSection"
	size_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_section.add_theme_constant_override("separation", 3)
	active_feature_panel.add_child(size_section)
	var size_header := HBoxContainer.new()
	size_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_section.add_child(size_header)
	var size_heading := _make_label("SIZE", 10, Color("#b9d9bf"))
	size_header.add_child(size_heading)
	rear_hardware_size_label = _make_label("ADD A COMPONENT TO BEGIN", 11, Color("#dce9df"))
	rear_hardware_size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rear_hardware_size_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	size_header.add_child(rear_hardware_size_label)

	rear_hardware_size_slider = HSlider.new()
	rear_hardware_size_slider.name = "RearHardwareHorizontalSizeSlider"
	rear_hardware_size_slider.min_value = 0.04 if rear_hardware_mode == "CAMERA" else 0.025
	rear_hardware_size_slider.max_value = 0.17 if rear_hardware_mode == "CAMERA" else 0.10
	rear_hardware_size_slider.step = 0.005
	rear_hardware_size_slider.custom_minimum_size = Vector2(0, 24)
	rear_hardware_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_size_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_back_design_slider(rear_hardware_size_slider)
	rear_hardware_size_slider.value_changed.connect(_on_rear_hardware_size_changed)
	size_section.add_child(rear_hardware_size_slider)

	# Keep the movement pad close to the size control and flank it with
	# the add/remove controls, vertically centred against the pad.
	var pad_control_row := HBoxContainer.new()
	pad_control_row.name = "RearHardwarePadWithManagement"
	pad_control_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_control_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_theme_constant_override("separation", 10 if tight else 14)
	active_feature_panel.add_child(pad_control_row)

	rear_hardware_add_button = _make_editor_icon_button(pad_control_row, "RearHardwareAddButton", "+", "Add camera or flash", Callable(self, "_add_rear_hardware_module"), control_height, true)

	var pad_center := CenterContainer.new()
	pad_center.name = "RearHardwareDirectionControllerCenter"
	pad_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_child(pad_center)
	var pad_shell := PanelContainer.new()
	pad_shell.name = "RearHardwareDirectionController"
	pad_shell.custom_minimum_size = Vector2(204, 204) if not tight else Vector2(184, 184)
	var pad_shell_style := StyleBoxFlat.new()
	pad_shell_style.bg_color = Color("#0b2112")
	pad_shell_style.border_color = Color("#477d53")
	pad_shell_style.set_border_width_all(1)
	pad_shell_style.set_corner_radius_all(16)
	pad_shell_style.content_margin_left = 8
	pad_shell_style.content_margin_right = 8
	pad_shell_style.content_margin_top = 8
	pad_shell_style.content_margin_bottom = 8
	pad_shell.add_theme_stylebox_override("panel", pad_shell_style)
	pad_center.add_child(pad_shell)

	var pad := GridContainer.new()
	pad.name = "RearHardwareDirectionPad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 18 if not tight else 16)
	pad.add_theme_constant_override("v_separation", 6)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad_shell.add_child(pad)
	_add_back_design_pad_spacer(pad)
	_add_rear_hardware_pad_button(pad, "↑", Vector2i(0, 1), tight)
	_add_back_design_pad_spacer(pad)
	_add_rear_hardware_pad_button(pad, "←", Vector2i(-1, 0), tight)
	var pad_center_button := Button.new()
	pad_center_button.name = "RearHardwareMoveCenterButton"
	pad_center_button.text = "MOVE"
	pad_center_button.custom_minimum_size = Vector2(64, 38)
	pad_center_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad_center_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_research_typography(pad_center_button, 10 if tight else 11)
	_style_back_design_button(pad_center_button, true)
	pad_center_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(pad_center_button)
	_add_rear_hardware_pad_button(pad, "→", Vector2i(1, 0), tight)
	_add_back_design_pad_spacer(pad)
	_add_rear_hardware_pad_button(pad, "↓", Vector2i(0, -1), tight)
	_add_back_design_pad_spacer(pad)

	rear_hardware_remove_button = _make_editor_icon_button(pad_control_row, "RearHardwareRemoveButton", "−", "Remove selected component", Callable(self, "_remove_rear_hardware_module"), control_height, false)
	_refresh_rear_hardware_panel()
func _add_rear_hardware_pad_button(parent: GridContainer, caption: String, direction: Vector2i, tight: bool) -> void:
	_add_editor_direction_pad_button(parent, caption, direction, tight, Callable(self, "_on_rear_hardware_pad_pressed"))


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
	if rear_hardware_mode == "CAMERA" and rear_camera_modules.size() >= MAX_REAR_CAMERAS:
		_refresh_rear_hardware_panel()
		return
	if rear_hardware_mode == "FLASH" and rear_flash_modules.size() >= MAX_REAR_FLASHES:
		_refresh_rear_hardware_panel()
		return
	var module_size := _get_rear_hardware_default_size()
	var spawn_position := _find_rear_hardware_spawn_position(rear_hardware_mode, module_size)
	if spawn_position.x > 900.0:
		return
	if rear_hardware_mode == "FLASH":
		rear_flash_modules.append({"id": next_rear_flash_id, "position": spawn_position, "size": module_size})
		rear_flash_selected_index = rear_flash_modules.size() - 1
		next_rear_flash_id += 1
	else:
		rear_camera_modules.append({"id": next_rear_camera_id, "position": spawn_position, "size": module_size, "mp": 12})
		rear_camera_selected_index = rear_camera_modules.size() - 1
		next_rear_camera_id += 1
	_refresh_rear_hardware_visuals()
	_refresh_rear_hardware_panel()
	_update_camera_software_summary()


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
	_update_camera_software_summary()


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
	if absf(candidate_position.x) + extent > _active_phone_size().x * 0.5 - 0.025:
		return false
	if absf(candidate_position.y) + extent > _active_phone_size().y * 0.5 - 0.025:
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


func _toggle_rear_hardware_selection_popup() -> void:
	if not is_instance_valid(rear_hardware_selection_popup):
		return
	_rebuild_rear_hardware_selection_popup()
	if _get_rear_hardware_modules().is_empty():
		return
	rear_hardware_selection_popup.visible = not rear_hardware_selection_popup.visible
	if rear_hardware_selection_popup.visible:
		rear_hardware_selection_popup.move_to_front()
		call_deferred("_position_rear_hardware_selection_popup")


func _close_rear_hardware_selection_popup() -> void:
	if is_instance_valid(rear_hardware_selection_popup):
		rear_hardware_selection_popup.visible = false


func _position_rear_hardware_selection_popup() -> void:
	if not is_instance_valid(rear_hardware_selection_popup) or not is_instance_valid(rear_hardware_selection_button):
		return
	if not rear_hardware_selection_popup.visible:
		return
	var popup_parent: Control
	if not worksite_creation_mode:
		popup_parent = get_node_or_null("PhoneEditorInterface/PhoneEditorRoot") as Control
		if not is_instance_valid(popup_parent):
			return
	var viewport_rect := get_viewport().get_visible_rect()
	var button_rect := rear_hardware_selection_button.get_global_rect()
	var padding := 8.0
	var gap := 6.0
	var viewport_size := viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var popup_width := clampf(button_rect.size.x, 160.0, viewport_size.x - padding * 2.0)
	var content_height := rear_hardware_selection_items.get_combined_minimum_size().y + 20.0 if is_instance_valid(rear_hardware_selection_items) else 80.0
	var desired_height := minf(maxf(content_height, 80.0), viewport_size.y * 0.48)
	var button_bottom := button_rect.position.y + button_rect.size.y
	var above := maxf(0.0, button_rect.position.y - viewport_rect.position.y - gap - padding)
	var below := maxf(0.0, viewport_rect.end.y - button_bottom - gap - padding)
	var open_below := below >= desired_height or below >= above
	var popup_height := minf(desired_height, maxf(80.0, viewport_size.y - padding * 2.0))
	rear_hardware_selection_popup.custom_minimum_size = Vector2(popup_width, popup_height)
	rear_hardware_selection_popup.size = Vector2(popup_width, popup_height)
	if is_instance_valid(rear_hardware_selection_scroll):
		rear_hardware_selection_scroll.custom_minimum_size = Vector2(0.0, maxf(48.0, popup_height - 20.0))
	var popup_y := button_bottom + gap if open_below else button_rect.position.y - popup_height - gap
	popup_y = clampf(popup_y, viewport_rect.position.y + padding, viewport_rect.end.y - popup_height - padding)
	var popup_x := clampf(button_rect.position.x, viewport_rect.position.x + padding, viewport_rect.end.x - popup_width - padding)
	var popup_viewport_position := Vector2(popup_x, popup_y)
	if worksite_creation_mode:
		# CanvasLayer controls use viewport coordinates directly.
		rear_hardware_selection_popup.position = popup_viewport_position
	else:
		rear_hardware_selection_popup.position = popup_parent.to_local(popup_viewport_position)
	rear_hardware_selection_popup.move_to_front()


func _rebuild_rear_hardware_selection_popup() -> void:
	if not is_instance_valid(rear_hardware_selection_items) or not is_instance_valid(rear_hardware_selection_button):
		return
	for child in rear_hardware_selection_items.get_children():
		child.queue_free()
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	var kind_name := "FLASH" if rear_hardware_mode == "FLASH" else "CAMERA"
	for index in range(modules.size()):
		var module: Dictionary = modules[index]
		var item := Button.new()
		item.text = "%s  %02d%s" % [kind_name, int(module["id"]), "   ✓ SELECTED" if index == selected_index else ""]
		item.custom_minimum_size = Vector2(0, 48)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.focus_mode = Control.FOCUS_NONE
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_theme_font_size_override("font_size", 15)
		for state in ["normal", "hover", "pressed", "focus"]:
			var item_style := StyleBoxFlat.new()
			item_style.bg_color = Color("#12351c") if state != "pressed" else Color("#285c35")
			if state == "hover":
				item_style.bg_color = Color("#1c4728")
			item_style.border_color = Color("#4d8d5b")
			item_style.set_border_width_all(1)
			item_style.set_corner_radius_all(8)
			item_style.content_margin_left = 14
			item.add_theme_stylebox_override(state, item_style)
		item.add_theme_color_override("font_color", Color("#e5f4e7"))
		item.add_theme_color_override("font_hover_color", Color("#ffffff"))
		item.add_theme_color_override("font_pressed_color", Color("#ffffff"))
		item.pressed.connect(_select_rear_hardware_module.bind(index))
		rear_hardware_selection_items.add_child(item)
	rear_hardware_selection_button.disabled = modules.is_empty()
	if selected_index >= 0 and selected_index < modules.size():
		var selected: Dictionary = modules[selected_index]
		rear_hardware_selection_button.text = "%s  %02d  ▼" % [kind_name, int(selected["id"])]
	else:
		rear_hardware_selection_button.text = "ADD A %s TO SELECT  ▼" % kind_name
	if modules.is_empty():
		rear_hardware_selection_popup.visible = false
	elif rear_hardware_selection_popup.visible:
		call_deferred("_position_rear_hardware_selection_popup")


func _select_rear_hardware_module(index: int) -> void:
	var modules := _get_rear_hardware_modules()
	if index < 0 or index >= modules.size():
		return
	_set_rear_hardware_selected_index(index)
	_close_rear_hardware_selection_popup()
	_refresh_rear_hardware_panel()


func _refresh_rear_hardware_panel() -> void:
	if not is_instance_valid(rear_hardware_selection_button):
		return
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	var kind_name := "FLASH" if rear_hardware_mode == "FLASH" else "CAMERA"
	var has_selection := selected_index >= 0 and selected_index < modules.size()
	if has_selection:
		var selected: Dictionary = modules[selected_index]
		rear_hardware_size_slider.set_value_no_signal(float(selected["size"]))
		rear_hardware_size_label.text = "SIZE  %.3f" % float(selected["size"])
	else:
		rear_hardware_size_slider.set_value_no_signal(_get_rear_hardware_default_size())
		rear_hardware_size_label.text = "ADD A %s TO BEGIN" % kind_name
	rear_hardware_size_slider.disabled = not has_selection
	rear_hardware_remove_button.disabled = not has_selection
	_rebuild_rear_hardware_selection_popup()
	var camera_limit_reached := rear_hardware_mode == "CAMERA" and rear_camera_modules.size() >= MAX_REAR_CAMERAS
	var flash_limit_reached := rear_hardware_mode == "FLASH" and rear_flash_modules.size() >= MAX_REAR_FLASHES
	rear_hardware_add_button.text = "MAX 5 CAMERAS" if camera_limit_reached else ("MAX 5 FLASHES" if flash_limit_reached else ("+ ADD CAMERA" if rear_hardware_mode == "CAMERA" else "+ ADD FLASH"))
	rear_hardware_add_button.disabled = camera_limit_reached or flash_limit_reached
	rear_hardware_remove_button.text = "− REMOVE CAMERA" if rear_hardware_mode == "CAMERA" else "− REMOVE FLASH"


func _rear_hardware_back_design_index(module_position: Vector2) -> int:
	# Match the hardware support rule exactly: a module belongs to a raised
	# back-design panel when its centre is inside that panel's live rectangle.
	for index in range(back_design_boxes.size()):
		var box: Dictionary = back_design_boxes[index]
		var box_position: Vector2 = box["position"]
		var half: Vector2 = box["size"] * 0.5
		if absf(module_position.x - box_position.x) <= half.x and absf(module_position.y - box_position.y) <= half.y:
			return index
	return -1


func _back_design_box_has_rear_hardware(box_index: int) -> bool:
	if box_index < 0 or box_index >= back_design_boxes.size():
		return false
	for module in rear_camera_modules:
		var module_position: Vector2 = module["position"]
		if _rear_hardware_back_design_index(module_position) == box_index:
			return true
	for module in rear_flash_modules:
		var module_position: Vector2 = module["position"]
		if _rear_hardware_back_design_index(module_position) == box_index:
			return true
	return false


func _rear_hardware_support_surface_z(module_position: Vector2, _module_size: float) -> float:
	var phone_depth := _phone_depth_for_thickness_level()
	var surface_z := -phone_depth * 0.5
	if _rear_hardware_back_design_index(module_position) >= 0:
		# Raised Back Design mesh extrudes toward the outside of the rear face.
		return surface_z - (0.035 / 1.10 / 1.5)
	return surface_z

func _refresh_rear_hardware_visuals() -> void:
	if not is_instance_valid(phone_body):
		return
	_restore_foldable_accessories_from_group("RearCameraFlashHardware")
	var previous := phone_body.get_node_or_null("RearCameraFlashHardware")
	if is_instance_valid(previous):
		previous.free()
	if rear_camera_modules.is_empty() and rear_flash_modules.is_empty():
		_queue_phone_case_sync()
		_route_foldable_accessories()
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
		flash_rim_material.albedo_color = Color("#65d783") if flash_is_selected else Color("#aab4bd")
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


	_queue_phone_case_sync()
	_route_foldable_accessories()

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

	var description := _make_label("Adjust the curvature of the phone's outer corners", 12, Color("#c7eacb"))
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
	meter.custom_minimum_size = Vector2(76, 320)
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.value_changed.connect(_on_border_radius_level_changed)
	_style_custom_slider(meter)
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

	var description := _make_label("Make the phone body slimmer or thicker", 12, Color("#c7eacb"))
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
	meter.name = "PhoneThicknessLevelMeter"
	meter.min_value = 0
	meter.max_value = 12
	meter.step = 1
	meter.value = phone_thickness_level
	meter.tick_count = 13
	meter.custom_minimum_size = Vector2(64, 320)
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.value_changed.connect(_on_phone_thickness_level_changed)
	_style_custom_slider(meter)
	meter_row.add_child(meter)

	phone_thickness_value_label = _make_label("LEVEL %d / 12" % phone_thickness_level, 16, Color("#a9e3ff"))
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

	# Compact button cards share the left side; one vertical length slider
	# sits alongside them and continues to control both physical buttons.
	var controls_row := HBoxContainer.new()
	controls_row.name = "PowerVolumeControlsRow"
	controls_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_row.add_theme_constant_override("separation", 10)
	active_feature_panel.add_child(controls_row)

	var cards_column := VBoxContainer.new()
	cards_column.name = "ButtonCardsColumn"
	cards_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_column.size_flags_stretch_ratio = 3.2
	cards_column.add_theme_constant_override("separation", 10)
	controls_row.add_child(cards_column)
	_add_side_button_controls("POWER BUTTON", "right", power_button_enabled, power_button_y, cards_column)
	_add_side_button_controls("VOLUME ROCKER", "left", volume_button_enabled, volume_button_y, cards_column)

	var length_column := VBoxContainer.new()
	length_column.name = "ButtonLengthColumn"
	length_column.custom_minimum_size = Vector2(72, 0)
	length_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	length_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	length_column.alignment = BoxContainer.ALIGNMENT_CENTER
	length_column.add_theme_constant_override("separation", 8)
	controls_row.add_child(length_column)

	var length_title := _make_label("LENGTH", 15, Color("#d8f1ff"))
	length_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	length_column.add_child(length_title)

	var length_slider := VSlider.new()
	length_slider.name = "BothSideButtonLengthSlider"
	length_slider.min_value = 0.55
	length_slider.max_value = 1.35
	length_slider.step = 0.05
	length_slider.value = side_button_length_scale
	length_slider.custom_minimum_size = Vector2(64, 300)
	length_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	length_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	length_slider.value_changed.connect(_on_side_button_length_changed)
	_style_custom_slider(length_slider)
	length_column.add_child(length_slider)

	side_button_length_label = _make_label("%d%%" % roundi(side_button_length_scale * 100.0), 15, Color("#a9e3ff"))
	side_button_length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	length_column.add_child(side_button_length_label)


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

	var title := _make_label("HOME BUTTON", 19, Color("#c7eacb"))
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
		toggle_style.bg_color = Color("#174b28") if state != "hover" else Color("#205d37")
		if state == "pressed" or state == "focus":
			toggle_style.bg_color = Color("#168343")
		toggle_style.border_color = Color("#8fd8a1")
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
	var center_y := -_active_phone_size().y * 0.5 + 0.11
	var current_depth := _phone_depth_for_thickness_level()
	var body_front_z := current_depth * 0.5
	var button_surface_z := body_front_z + 0.0008

	# When the screen reaches this fixed device position, rest the marking on
	# the actual glass surface. Otherwise it sits directly on the exposed body.
	if is_instance_valid(phone_screen):
		var screen_width := _active_phone_size().x if screen_shape_mode == "Curve screen" and side_curve_enabled else maxf(0.30, _active_phone_size().x - bezel_width * 2.0)
		var screen_height := _active_phone_size().y if screen_shape_mode == "Curve screen" and vertical_curve_enabled else maxf(0.60, _active_phone_size().y - bezel_height * 2.0)
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
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect x="2.5" y="2.5" width="31" height="31" rx="7" fill="#72d987" fill-opacity="0.30" stroke="#9bd6a7" stroke-width="2.5"/><path d="M9 18.5l6 6L27.5 12" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/></svg>"""
	else:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect x="2.5" y="2.5" width="31" height="31" rx="7" fill="#9bd6a7" fill-opacity="0.10" stroke="#9bd6a7" stroke-width="2.5"/></svg>"""
	var error := image.load_svg_from_string(svg)
	if error != OK:
		push_warning("Could not create side-button checkbox icon")
		return null
	return ImageTexture.create_from_image(image)


func _add_side_button_controls(caption: String, side: String, enabled: bool, position_y: float, parent: Control) -> void:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Keep the complete control stack inside the panel on compact screens.
	# The panel's own margins are additional to the VBox content height.
	section.custom_minimum_size = Vector2(0.0, 184.0)
	var section_style := StyleBoxFlat.new()
	section_style.bg_color = Color(0.035, 0.12, 0.065, 0.88)
	section_style.border_color = Color(0.28, 0.62, 0.38, 0.58)
	section_style.set_border_width_all(1)
	section_style.set_corner_radius_all(12)
	section_style.content_margin_left = 12
	section_style.content_margin_right = 12
	section_style.content_margin_top = 9
	section_style.content_margin_bottom = 9
	section.add_theme_stylebox_override("panel", section_style)
	parent.add_child(section)

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
	var position_title := _make_label("VERTICAL POSITION", 14, Color("#c7eacb"))
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
	_style_power_volume_position_button(down)
	down.pressed.connect(_on_side_button_position_step.bind(side, -1))
	position_row.add_child(down)
	var position_label := _make_label("%d%%" % roundi(position_y / 1.20 * 100.0), 17, Color("#b8e8c2"))
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position_row.add_child(position_label)
	var up := Button.new()
	up.text = "+"
	up.custom_minimum_size = Vector2(64, 54)
	_apply_research_typography(up, 27)
	_style_power_volume_position_button(up)
	up.pressed.connect(_on_side_button_position_step.bind(side, 1))
	position_row.add_child(up)
	if side == "right":
		power_button_position_label = position_label
	else:
		volume_button_position_label = position_label


func _style_power_volume_position_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.16, 0.075, 0.88)
		style.border_color = Color(0.30, 0.68, 0.40, 0.72)
		if state == "hover":
			style.bg_color = Color(0.07, 0.27, 0.12, 0.96)
		elif state == "pressed":
			style.bg_color = Color(0.08, 0.38, 0.16, 1.0)
		elif state == "disabled":
			style.bg_color = Color(0.035, 0.12, 0.065, 0.45)
			style.border_color = Color(0.20, 0.38, 0.25, 0.42)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.12, 0.04, 0.28)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#e8f6eb"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#91b69a"))


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

	var title := _make_label("SIDE BUTTONS", 21, Color("#c7eacb"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(title)
	var description := _make_label("Add tactile controls and a SIM tray to the phone frame.", 12, Color("#c7eacb"))
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
	style.bg_color = Color(0.035, 0.12, 0.065, 0.88)
	style.border_color = Color(0.28, 0.62, 0.38, 0.58)
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
		var position_caption := _make_label("POSITION ON PHONE SIDE", 12, Color("#c7eacb"))
		content.add_child(position_caption)
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		controls.add_theme_constant_override("separation", 10)
		content.add_child(controls)
		var down := Button.new()
		down.text = "−"
		down.custom_minimum_size = Vector2(58, 44)
		_apply_research_typography(down, 24)
		_style_screen_type_option(down, 0, false)
		down.pressed.connect(_on_optional_side_feature_position_step.bind(feature, -1))
		controls.add_child(down)
		var value_label := _make_label("%d%%" % roundi(position_y / 1.20 * 100.0), 15, Color("#9bd6a7"))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(value_label)
		var up := Button.new()
		up.text = "+"
		up.custom_minimum_size = Vector2(58, 44)
		_apply_research_typography(up, 24)
		_style_screen_type_option(up, 0, false)
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
	_style_custom_slider(meter)


func _restore_foldable_accessories_from_group(group_name: String) -> void:
	if selected_phone_type == "Standard" or not is_instance_valid(phone_body):
		return
	var moving_half := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableMovingHalf") as Node3D
	if not is_instance_valid(moving_half):
		return

	# Old accessories may already have been reparented out of their feature
	# group. Return only the matching group's parts to neutral phone space
	# before that group is freed, otherwise they survive as ghost geometry.
	moving_half.rotation = Vector3.ZERO
	moving_half.position = Vector3.ZERO
	moving_half.scale = Vector3.ONE
	var original_group := phone_body.get_node_or_null(group_name)
	for routed_item in moving_half.get_children():
		if not routed_item.has_meta("foldable_routed_accessory"):
			continue
		if str(routed_item.get_meta("foldable_original_group", "")) != group_name:
			continue
		if is_instance_valid(original_group):
			routed_item.reparent(original_group, true)
		else:
			routed_item.queue_free()
		routed_item.remove_meta("foldable_routed_accessory")
		routed_item.remove_meta("foldable_original_group")
	_apply_phone_fold_angle()


func _refresh_phone_side_buttons() -> void:
	if not is_instance_valid(phone_body):
		return
	_restore_foldable_accessories_from_group("PhoneSideButtons")
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

	var current_depth := _phone_depth_for_thickness_level()
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
	_queue_phone_case_sync()
	_route_foldable_accessories()


func _get_style_pen_marker_layout() -> Dictionary:
	# Keep the marker and the pouch opening on the exact same calculated point.
	var corner_radius := 0.32 * float(border_radius_level) / 6.0
	var bottom_y := -_active_phone_size().y * 0.5
	var left_edge := -_active_phone_size().x * 0.5
	var circle_radius := 0.025
	var edge_inset := 0.004
	var speaker_radius := 0.012
	var speaker_clearance := 0.008
	var marker_position := Vector2(left_edge + corner_radius + circle_radius + 0.012, bottom_y + edge_inset)
	var marker_rotation := 0.0
	var found_position := false
	var left_count := int(ceil(float(speaker_count) * 0.5))
	var reserved_port_half_width := 0.115
	var edge_margin := 0.035
	var hole_spacing := 0.045
	var left_speaker_positions: Array[float] = []
	for index in range(left_count):
		left_speaker_positions.append(-(reserved_port_half_width + edge_margin + float(left_count - 1 - index) * hole_spacing))
	var required_clearance := circle_radius + speaker_radius + speaker_clearance
	if corner_radius > 0.08:
		var arc_center := Vector2(left_edge + corner_radius, bottom_y + corner_radius)
		var arc_path_radius := corner_radius - edge_inset
		for step in range(1, 91):
			var angle := -PI * 0.5 - deg_to_rad(float(step))
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
	if not found_position:
		var straight_start_x := left_edge + corner_radius + circle_radius + 0.012
		for step in range(81):
			var candidate_x := lerpf(straight_start_x, 0.0, float(step) / 80.0)
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
	return {"position": marker_position, "rotation": marker_rotation, "valid": found_position}


func _add_phone_style_pen(parent: Node3D, _current_depth: float, _key_material: Material) -> void:
	var layout := _get_style_pen_marker_layout()
	if not bool(layout["valid"]):
		return
	var marker_position: Vector2 = layout["position"]
	var marker_rotation: float = layout["rotation"]
	var circle_radius := 0.025
	var circle_material := StandardMaterial3D.new()
	circle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	circle_material.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	circle_material.metallic = 0.0
	circle_material.roughness = 1.0
	circle_material.disable_receive_shadows = true
	circle_material.disable_fog = true
	circle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var end_marker := MeshInstance3D.new()
	end_marker.name = "StylePenBlackCircleEnd"
	var circle_mesh := CylinderMesh.new()
	circle_mesh.top_radius = circle_radius
	circle_mesh.bottom_radius = circle_radius
	circle_mesh.height = 0.014
	circle_mesh.radial_segments = 40
	end_marker.mesh = circle_mesh
	end_marker.position = Vector3(marker_position.x, marker_position.y, 0.0)
	end_marker.rotation_degrees.z = marker_rotation
	end_marker.material_override = circle_material
	end_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(end_marker)

func _add_phone_sim_tray(parent: Node3D, side_sign: float, position_y: float, frame_material: Material, key_material: Material) -> void:
	var edge := _active_phone_size().x * 0.5
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
	var unit_per_mm := _active_phone_size().y / 150.0
	var button_depth := (1.2 * unit_per_mm) / 0.95
	var button_width := maxf(radius * 1.35, 0.024)
	var side_edge := _active_phone_size().x * 0.5

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

	var description := _make_label("Choose how many speaker openings appear along the bottom edge", 12, Color("#c7eacb"))
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
	meter.custom_minimum_size = Vector2(76, 320)
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	meter.value_changed.connect(_on_speaker_count_changed)
	_style_custom_slider(meter)
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

	_restore_foldable_accessories_from_group("PhoneSpeakerOpenings")
	var previous_set := phone_body.get_node_or_null("PhoneSpeakerOpenings")
	if is_instance_valid(previous_set):
		previous_set.free()
	if speaker_count <= 0:
		_queue_phone_case_sync()
		_route_foldable_accessories()
		return

	var speaker_set := Node3D.new()
	speaker_set.name = "PhoneSpeakerOpenings"
	phone_body.add_child(speaker_set)

	# Fixed center clearance for every supported connector. Speaker placement
	# never reads charge_port_type or port dimensions, so port edits cannot
	# move, resize, or reshape these circles.
	var bottom_y := -_active_phone_size().y * 0.5
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


	_queue_phone_case_sync()
	_route_foldable_accessories()

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

	var description := _make_label("Five established phone connector types", 12, Color("#c7eacb"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(description)

	var selected_label := _make_label("SELECTED: " + charge_port_type.to_upper(), 13, Color("#a8dcb0"))
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
	options.columns = 2
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
	for port_index in range(port_types.size()):
		var port_type: String = port_types[port_index]
		var option_button := Button.new()
		option_button.name = "ChargePort_" + port_type.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
		option_button.text = port_type
		option_button.tooltip_text = port_type
		option_button.custom_minimum_size = Vector2(0, 50)
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_research_typography(option_button, 13)
		_style_screen_type_option(option_button, port_index, port_type == charge_port_type)
		option_button.pressed.connect(_on_charge_port_selected.bind(port_type))
		options.add_child(option_button)


func _on_charge_port_selected(port_type: String) -> void:
	charge_port_type = port_type
	if charge_port_type == "None":
		charger_cable_enabled = false
	# Keep the selected adapter-side plug (USB-A or USB-C), but always replace
	# the phone-side connector with the exact selected phone port standard.
	var adapter_connector := _charger_output_connector()
	var phone_connector := _charger_device_connector()
	if not phone_connector.is_empty():
		charger_cable_type = adapter_connector + " to " + phone_connector
	if is_instance_valid(charge_port_value_label):
		charge_port_value_label.text = "SELECTED: " + charge_port_type.to_upper()
		charge_port_value_label.add_theme_color_override("font_color", Color("#a8dcb0"))
	# Rebuild both the receptacle and whichever chassis architecture is active.
	_refresh_phone_mesh()



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
	var unit_per_mm := _active_phone_size().y / 150.0
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
	var current_phone_depth := _phone_depth_for_thickness_level()
	var half_phone_depth := current_phone_depth * 0.5
	var current_corner_radius := 0.32 * float(border_radius_level) / 6.0
	var port_frame_half_width := _active_phone_size().x * 0.5
	var port_local_offset := Vector2.ZERO
	var flat_bottom_half_width := maxf(0.02, port_frame_half_width - current_corner_radius)
	if selected_phone_type == "Fold":
		var port_fit_layout := _get_foldable_segment_layout()
		var fold_segment_size: Vector3 = port_fit_layout["segment_size"]
		port_frame_half_width = fold_segment_size.x * 0.5
		# The fixed Fold leaf rounds its OUTER left corners, leaving a
		# straight bottom rail from (-half_width + radius) to (+half_width).
		# Centre the connector on that asymmetric straight rail.
		var actual_fold_radius := minf(
			current_corner_radius,
			minf(port_frame_half_width, _active_phone_size().y * 0.5) - 0.001
		)
		var rail_left := -port_frame_half_width + actual_fold_radius
		var rail_right := port_frame_half_width
		port_local_offset.x = (rail_left + rail_right) * 0.5
		flat_bottom_half_width = maxf(0.002, minf(port_local_offset.x - rail_left, rail_right - port_local_offset.x))
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
	charge_port_opening_points = PackedVector2Array()
	for point in inner_points:
		charge_port_opening_points.append(point + port_local_offset)

	var port_root := Node3D.new()
	port_root.name = "PhoneChargingPort"
	if selected_phone_type == "Fold":
		# Keep connector internals centred while positioning the assembly
		# over the real straight rail on the fixed leaf.
		var port_root_layout := _get_foldable_segment_layout()
		var fixed_offset: Vector3 = port_root_layout["fixed_offset"]
		port_root.position = fixed_offset + Vector3(port_local_offset.x, 0.0, 0.0)
	phone_body.add_child(port_root)
	var bottom_y := -_active_phone_size().y * 0.5
	var mouth_y := bottom_y + 0.0001
	var recess_depth := minf(6.2 * unit_per_mm, _active_phone_size().y * 0.08)
	var back_y := bottom_y + recess_depth
	var contact_face_y := bottom_y + recess_depth * 0.54

	var bezel_material := StandardMaterial3D.new()
	bezel_material.albedo_color = Color("#000000")
	bezel_material.metallic = 0.0
	bezel_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	bezel_material.roughness = 1.0
	bezel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gasket_material := StandardMaterial3D.new()
	gasket_material.albedo_color = Color("#000000")
	gasket_material.metallic = 0.0
	gasket_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	gasket_material.roughness = 1.0
	gasket_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cavity_material := StandardMaterial3D.new()
	cavity_material.albedo_color = Color("#000000")
	cavity_material.metallic = 0.0
	cavity_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	cavity_material.roughness = 1.0
	cavity_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cavity_wall_material := StandardMaterial3D.new()
	cavity_wall_material.albedo_color = Color("#000000")
	cavity_wall_material.metallic = 0.0
	cavity_wall_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	cavity_wall_material.roughness = 1.0
	cavity_wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if circular:
		cavity_wall_material.albedo_color = Color("#000000")
		cavity_wall_material.metallic = 0.0
		cavity_wall_material.roughness = 1.0
	var tongue_material := StandardMaterial3D.new()
	# Connector tongues and contact beds are insulating polymer, not bare metal.
	tongue_material.albedo_color = Color("#000000")
	tongue_material.metallic = 0.0
	tongue_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	tongue_material.roughness = 1.0
	tongue_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var contact_material := StandardMaterial3D.new()
	contact_material.albedo_color = Color("#000000")
	contact_material.metallic = 0.0
	contact_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	contact_material.roughness = 1.0
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


func _phone_depth_for_thickness_level(level: int = -1) -> float:
	# Preserve the complete original 0-10 thickness curve at levels 2-12.
	# The former level 10 (thickest) is now level 12 without changing its
	# physical depth. Levels 1 and 0 add two thinner settings below the
	# former minimum depth.
	var resolved_level := phone_thickness_level if level < 0 else clampi(level, 0, 12)
	if resolved_level <= 2:
		return lerpf(0.04, 0.08, float(resolved_level) / 2.0)
	return lerpf(0.08, _active_phone_size().z, float(resolved_level - 2) / 10.0)


func _on_phone_thickness_level_changed(value: float) -> void:
	phone_thickness_level = clampi(roundi(value), 0, 12)
	if is_instance_valid(phone_thickness_value_label):
		phone_thickness_value_label.text = "LEVEL %d / 12" % phone_thickness_level
	_refresh_phone_mesh()


func _refresh_phone_mesh() -> void:
	if not is_instance_valid(phone_body):
		return
	# Refresh the fitted aperture first: thickness upgrades can change how much
	# room a connector has inside the bottom rail.
	_refresh_phone_charge_port()
	_refresh_foldable_hardware()
	_refresh_back_design_boxes()
	_refresh_phone_side_buttons()
	_refresh_phone_home_button()
	_refresh_phone_screen()
	_refresh_phone_speakers()
	_refresh_back_design_boxes()
	_refresh_rear_hardware_visuals()
	_route_foldable_accessories()
	_apply_phone_fold_angle()
	_queue_phone_case_sync()


func _on_border_radius_level_changed(value: float) -> void:
	border_radius_level = clampi(roundi(value), 0, 6)
	if is_instance_valid(border_radius_value_label):
		border_radius_value_label.text = "LEVEL %d / 6" % border_radius_level
	_refresh_phone_mesh()


func _refresh_foldable_frame_materials() -> void:
	if not is_instance_valid(phone_body) or selected_phone_type == "Standard":
		return
	var fixed_frame := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableFixedHalf/PhoneFoldableFixedFrame") as MeshInstance3D
	var moving_frame := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableMovingHalf/PhoneFoldableMovingFrame") as MeshInstance3D
	if is_instance_valid(fixed_frame):
		fixed_frame.material_override = _create_device_body_material(Vector2(fixed_frame.position.x, fixed_frame.position.y), fixed_frame.mesh.get_aabb().size if is_instance_valid(fixed_frame.mesh) else Vector3.ZERO)
	if is_instance_valid(moving_frame):
		moving_frame.material_override = _create_device_body_material(Vector2(moving_frame.position.x, moving_frame.position.y))
	var hinge_root := phone_body.get_node_or_null("PhoneFoldableHinge")
	var hinge_spine := hinge_root.get_node_or_null("SeamlessHingeCover") as MeshInstance3D if is_instance_valid(hinge_root) else null
	if is_instance_valid(hinge_spine):
		var hinge_material := StandardMaterial3D.new()
		hinge_material.albedo_color = device_body_color.lightened(0.10)
		hinge_material.metallic = 0.72
		hinge_material.roughness = 0.27
		hinge_material.metallic_specular = 0.82
		hinge_spine.material_override = hinge_material
	var hinge_edge := hinge_root.get_node_or_null("HingeEdgeHighlight") as MeshInstance3D if is_instance_valid(hinge_root) else null
	if is_instance_valid(hinge_edge):
		var edge_material := StandardMaterial3D.new()
		edge_material.albedo_color = device_body_color.lightened(0.36)
		edge_material.metallic = 0.78
		edge_material.roughness = 0.22
		hinge_edge.material_override = edge_material


func _get_foldable_segment_layout() -> Dictionary:
	# Shared saved chassis structure for frame, port, cover display and case.
	var phone_size := _active_phone_size()
	var segment_size := Vector3.ZERO
	var fixed_offset := Vector3.ZERO
	var moving_offset := Vector3.ZERO
	if selected_phone_type == "Fold":
		var half_width := (phone_size.x - 0.014) * 0.5
		segment_size = Vector3(half_width, phone_size.y, phone_size.z)
		fixed_offset = Vector3(-half_width * 0.5 - 0.007, 0.0, 0.0)
		moving_offset = Vector3(half_width * 0.5 + 0.007, 0.0, 0.0)
	else:
		var half_height := (phone_size.y - 0.014) * 0.5
		segment_size = Vector3(phone_size.x, half_height, phone_size.z)
		fixed_offset = Vector3(0.0, -half_height * 0.5 - 0.007, 0.0)
		moving_offset = Vector3(0.0, half_height * 0.5 + 0.007, 0.0)
	return {
		"segment_size": segment_size,
		"fixed_offset": fixed_offset,
		"moving_offset": moving_offset
	}


func _foldable_half_corner_mask(is_moving_half: bool) -> int:
	# Corner order matches both mesh builders: top-right, top-left,
	# bottom-left, bottom-right. Only the outside corners of the complete
	# foldable handset receive the Standard phone's border radius.
	if selected_phone_type == "Fold":
		return 9 if is_moving_half else 6
	if selected_phone_type == "Flip":
		return 3 if is_moving_half else 12
	return 15


func _refresh_foldable_hardware() -> void:
	if not is_instance_valid(phone_body):
		return
	var previous_panels := phone_body.get_node_or_null("PhoneFoldablePanels")
	if is_instance_valid(previous_panels):
		var previous_moving := previous_panels.get_node_or_null("PhoneFoldableMovingHalf") as Node3D
		if is_instance_valid(previous_moving):
			# Rebuilds can be triggered while the phone is closed. First return
			# the moving parent to its neutral pose so routed parts are restored
			# to their original phone-body coordinates without leaving a ghost.
			previous_moving.rotation = Vector3.ZERO
			previous_moving.position = Vector3.ZERO
			previous_moving.scale = Vector3.ONE
			for routed_item in previous_moving.get_children():
				if routed_item.has_meta("foldable_routed_accessory"):
					var original_group_name := str(routed_item.get_meta("foldable_original_group", ""))
					var original_group := phone_body.get_node_or_null(original_group_name) if not original_group_name.is_empty() else null
					if is_instance_valid(original_group):
						routed_item.reparent(original_group, true)
					else:
						routed_item.reparent(phone_body, true)
					routed_item.remove_meta("foldable_routed_accessory")
					routed_item.remove_meta("foldable_original_group")
		previous_panels.free()
	var previous_hinge := phone_body.get_node_or_null("PhoneFoldableHinge")
	if is_instance_valid(previous_hinge):
		previous_hinge.free()
	if selected_phone_type == "Standard":
		phone_body.mesh = _create_rounded_phone_mesh(0.32 * float(border_radius_level) / 6.0, charge_port_opening_points)
		fold_angle_degrees = 0.0
		fold_target_angle_degrees = 0.0
		return

	phone_body.mesh = null
	var radius := 0.32 * float(border_radius_level) / 6.0
	var current_depth := _phone_depth_for_thickness_level()
	var panels := Node3D.new()
	panels.name = "PhoneFoldablePanels"
	phone_body.add_child(panels)
	var fixed_half := Node3D.new()
	fixed_half.name = "PhoneFoldableFixedHalf"
	panels.add_child(fixed_half)
	var moving_half := Node3D.new()
	moving_half.name = "PhoneFoldableMovingHalf"
	panels.add_child(moving_half)

	var chassis_layout := _get_foldable_segment_layout()
	var segment_size: Vector3 = chassis_layout["segment_size"]
	var fixed_offset: Vector3 = chassis_layout["fixed_offset"]
	var moving_offset: Vector3 = chassis_layout["moving_offset"]

	var fixed_corner_mask := _foldable_half_corner_mask(false)
	var moving_corner_mask := _foldable_half_corner_mask(true)
	var fixed_frame := MeshInstance3D.new()
	fixed_frame.name = "PhoneFoldableFixedFrame"
	fixed_frame.mesh = _create_rounded_phone_mesh(radius, charge_port_opening_points, segment_size, fixed_corner_mask)
	fixed_frame.material_override = _create_device_body_material(Vector2(fixed_offset.x, fixed_offset.y), segment_size)
	fixed_frame.position = fixed_offset
	fixed_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fixed_half.add_child(fixed_frame)
	var moving_frame := MeshInstance3D.new()
	moving_frame.name = "PhoneFoldableMovingFrame"
	moving_frame.mesh = _create_rounded_phone_mesh(radius, PackedVector2Array(), segment_size, moving_corner_mask)
	moving_frame.material_override = _create_device_body_material(Vector2(moving_offset.x, moving_offset.y))
	moving_frame.position = moving_offset
	moving_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moving_half.add_child(moving_frame)

	# Do not add a synthetic dark outline around the folded chassis.

	var hinge_root := Node3D.new()
	hinge_root.name = "PhoneFoldableHinge"
	phone_body.add_child(hinge_root)
	# A narrow, flush hinge spine follows the center seam. Its shallow,
	# rounded plate reads as an integrated Armor Aluminum cover, not a barrel.
	var hinge_material := StandardMaterial3D.new()
	hinge_material.albedo_color = device_body_color.lightened(0.08)
	hinge_material.metallic = 0.68
	hinge_material.roughness = 0.30
	hinge_material.metallic_specular = 0.78
	var hinge_length := (_active_phone_size().y if selected_phone_type == "Fold" else _active_phone_size().x) * 0.92
	var hinge_band_width := 0.020
	var spine := MeshInstance3D.new()
	spine.name = "SeamlessHingeCover"
	spine.mesh = _create_rounded_panel_mesh(hinge_band_width, hinge_length, 0.004, 0.009)
	spine.material_override = hinge_material
	if selected_phone_type == "Flip":
		spine.rotation.z = PI * 0.5
	spine.position = Vector3(0.0, 0.0, -current_depth * 0.5 - 0.002)
	spine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hinge_root.add_child(spine)

	# A single hairline finish catches light along the center of the hinge cap.
	var hinge_highlight := MeshInstance3D.new()
	hinge_highlight.name = "HingeEdgeHighlight"
	hinge_highlight.mesh = _create_rounded_panel_mesh(0.0012, hinge_length * 0.86, 0.001, 0.0005)
	var highlight_material := StandardMaterial3D.new()
	highlight_material.albedo_color = device_body_color.lightened(0.30)
	highlight_material.metallic = 0.72
	highlight_material.roughness = 0.24
	hinge_highlight.material_override = highlight_material
	if selected_phone_type == "Flip":
		hinge_highlight.rotation.z = PI * 0.5
	hinge_highlight.position = Vector3(0.0, 0.0, -current_depth * 0.5 - 0.0045)
	hinge_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hinge_root.add_child(hinge_highlight)
	_apply_phone_fold_angle()


func _route_foldable_accessories() -> void:
	if selected_phone_type == "Standard" or not is_instance_valid(phone_body):
		return
	var moving_half := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableMovingHalf") as Node3D
	if not is_instance_valid(moving_half):
		return

	# UI edits can rebuild a side-button/SIM/speaker group while the device is
	# already folded. Route in the neutral phone coordinate space, not through
	# the current rotated parent transform.
	moving_half.rotation = Vector3.ZERO
	moving_half.position = Vector3.ZERO
	moving_half.scale = Vector3.ONE

	var moving_axis := Vector3.RIGHT if selected_phone_type == "Fold" else Vector3.UP
	for group_name in ["PhoneSideButtons", "PhoneSpeakerOpenings", "RearCameraFlashHardware", "BackDesignRaisedSections"]:
		var group := phone_body.get_node_or_null(group_name)
		if not is_instance_valid(group):
			continue
		for item in group.get_children():
			if not item is Node3D or item.has_meta("foldable_routed_accessory"):
				continue
			var axis_position := (item as Node3D).position.dot(moving_axis)
			if axis_position > 0.008:
				item.set_meta("foldable_routed_accessory", true)
				item.set_meta("foldable_original_group", group_name)
				# Keep the original open-pose transform when changing parent.
				item.reparent(moving_half, true)

	# Put the moving frame and all routed hardware back at the live hinge angle.
	_apply_phone_fold_angle()


func _foldable_inward_rotation(angle_radians: float) -> Vector3:
	# The moving Fold leaf starts on +X, so rotate it around Y toward -X.
	# The moving Flip leaf starts on +Y, so rotate it around X toward -Y.
	# These opposite axis signs keep the inner glass aimed at the fixed leaf
	# throughout the hinge travel, including the partially-open positions.
	if selected_phone_type == "Fold":
		return Vector3(0.0, -angle_radians, 0.0)
	if selected_phone_type == "Flip":
		return Vector3(angle_radians, 0.0, 0.0)
	return Vector3.ZERO


func _apply_phone_fold_angle() -> void:
	var angle_radians := deg_to_rad(clampf(fold_angle_degrees, 0.0, MAX_FOLD_ANGLE_DEGREES))
	var inward_rotation := _foldable_inward_rotation(angle_radians)
	# Both leaves originally rotate around the same centre plane. At 180
	# degrees their solid thickness therefore occupies identical space and
	# they visually collapse into one slab. Raise the moving leaf through the
	# closing arc so its inner glass meets the fixed inner glass while the
	# two chassis remain physically layered. Zero offset when fully open;
	# one complete body depth when fully closed.
	var layer_offset := _phone_depth_for_thickness_level() * sin(angle_radians * 0.5)
	var moving_half := phone_body.get_node_or_null("PhoneFoldablePanels/PhoneFoldableMovingHalf") if is_instance_valid(phone_body) else null
	if is_instance_valid(moving_half):
		moving_half.rotation = inward_rotation
		moving_half.position.z = layer_offset
	# The bridge is coplanar with both leaves only in the flat-open posture.
	# Hide it as soon as the hinge bends so no floating glass appears in motion.
	var inner_bridge := phone_body.get_node_or_null("PhoneDisplayPanel/ContinuousInnerDisplayBridge") if is_instance_valid(phone_body) else null
	if is_instance_valid(inner_bridge):
		inner_bridge.visible = fold_angle_degrees <= 2.0
	# Closed-pose separation comes from the two real chassis layers, not a dark overlay.
	var case_moving := phone_case_preview.get_node_or_null("PhoneCaseMovingHalf") if is_instance_valid(phone_case_preview) else null
	if is_instance_valid(case_moving):
		case_moving.rotation = inward_rotation
		case_moving.position.z = layer_offset


func _set_fold_angle_from_pinch(distance: float) -> void:
	if selected_phone_type == "Standard" or not fold_pinch_active:
		return
	var distance_change := distance - fold_pinch_start_distance
	fold_target_angle_degrees = clampf(fold_pinch_start_angle - distance_change * FOLD_PINCH_ANGLE_SENSITIVITY, 0.0, MAX_FOLD_ANGLE_DEGREES)


func _create_phone_chassis_mesh(radius: float, port_opening: PackedVector2Array) -> Mesh:
	# Foldable handsets are assembled as independently transformable halves.
	return _create_rounded_phone_mesh(radius, port_opening)


func _add_phone_bottom_edge_rectangle(surface: SurfaceTool, x_min: float, x_max: float, z_min: float, z_max: float, face_y: float) -> void:
	if x_max - x_min <= 0.00001 or z_max - z_min <= 0.00001:
		return
	var a := Vector3(x_min, face_y, z_min)
	var b := Vector3(x_max, face_y, z_min)
	var c := Vector3(x_max, face_y, z_max)
	var d := Vector3(x_min, face_y, z_max)
	var normal := Vector3(0.0, -1.0, 0.0)
	_add_phone_mesh_triangle(surface, a, b, c, normal)
	_add_phone_mesh_triangle(surface, a, c, d, normal)


func _add_foldable_bottom_edge_with_port(surface: SurfaceTool, phone_size: Vector3, port_opening: PackedVector2Array, flat_bottom_left: float, flat_bottom_right: float) -> void:
	if port_opening.size() < 3:
		return
	var half_size := phone_size * 0.5
	var face_y := -half_size.y
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in port_opening:
		low.x = minf(low.x, point.x)
		low.y = minf(low.y, point.y)
		high.x = maxf(high.x, point.x)
		high.y = maxf(high.y, point.y)
	var centre := (low + high) * 0.5
	var centred_opening := PackedVector2Array()
	for point in port_opening:
		centred_opening.append(point - centre)

	# Keep the triangulation local to the actual connector. The small border
	# is enough for the opening's transition ring; the far rail is filled with
	# rectangular strips that stay exactly inside the saved half-frame bounds.
	# Limit the port transition to the closest REAL straight-edge endpoint.
	# Fold's outer bottom-left corner is rounded, while its hinge-side corner is square.
	var left_clearance := maxf(0.002, centre.x - flat_bottom_left - 0.002)
	var right_clearance := maxf(0.002, flat_bottom_right - centre.x - 0.002)
	var box_half_x := minf((high.x - low.x) * 0.5 + 0.004, minf(left_clearance, right_clearance))
	var box_half_z := minf((high.y - low.y) * 0.5 + 0.004, maxf(0.002, half_size.z - 0.002))
	var angles: Array[float] = []
	const PORT_RING_SAMPLES := 64
	for sample in range(PORT_RING_SAMPLES):
		angles.append(TAU * float(sample) / float(PORT_RING_SAMPLES))
	var corner_angle := atan2(box_half_z, box_half_x)
	angles.append(corner_angle)
	angles.append(PI - corner_angle)
	angles.append(PI + corner_angle)
	angles.append(TAU - corner_angle)
	angles.sort()

	var inner_points := PackedVector3Array()
	var outer_points := PackedVector3Array()
	var previous_angle := -1.0
	for angle in angles:
		if absf(angle - previous_angle) < 0.00001:
			continue
		previous_angle = angle
		var direction := Vector2(cos(angle), sin(angle))
		var inner_local := _port_polygon_ray_intersection(centred_opening, direction)
		if inner_local == Vector2.ZERO:
			continue
		var scale_x := box_half_x / maxf(absf(direction.x), 0.000001)
		var scale_z := box_half_z / maxf(absf(direction.y), 0.000001)
		var outer_local := direction * minf(scale_x, scale_z)
		var inner := centre + inner_local
		var outer := centre + outer_local
		inner_points.append(Vector3(inner.x, face_y, inner.y))
		outer_points.append(Vector3(outer.x, face_y, outer.y))

	var normal := Vector3(0.0, -1.0, 0.0)
	for index in range(mini(inner_points.size(), outer_points.size())):
		var next_index := (index + 1) % inner_points.size()
		_add_phone_mesh_triangle(surface, outer_points[index], outer_points[next_index], inner_points[next_index], normal)
		_add_phone_mesh_triangle(surface, outer_points[index], inner_points[next_index], inner_points[index], normal)

	var box_left := centre.x - box_half_x
	var box_right := centre.x + box_half_x
	var box_bottom := centre.y - box_half_z
	var box_top := centre.y + box_half_z
	_add_phone_bottom_edge_rectangle(surface, flat_bottom_left, box_left, -half_size.z, half_size.z, face_y)
	_add_phone_bottom_edge_rectangle(surface, box_right, flat_bottom_right, -half_size.z, half_size.z, face_y)
	_add_phone_bottom_edge_rectangle(surface, box_left, box_right, box_top, half_size.z, face_y)
	_add_phone_bottom_edge_rectangle(surface, box_left, box_right, -half_size.z, box_bottom, face_y)


func _add_phone_bottom_edge_with_port(surface: SurfaceTool, phone_size: Vector3, port_opening: PackedVector2Array, flat_bottom_half_width: float, flat_bottom_left: float, flat_bottom_right: float) -> void:
	if selected_phone_type == "Fold":
		# Fold's port belongs to the asymmetrically rounded fixed leaf.
		# Fill only the straight rail between its actual edge endpoints.
		_add_foldable_bottom_edge_with_port(surface, phone_size, port_opening, flat_bottom_left, flat_bottom_right)
		return
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
		# Standard and Flip retain their established port-edge treatment.
		# Fold uses a split half-frame, so the old full-thickness bridge spans
		# beyond that segment and creates the unwanted flat bottom extension.
		if selected_phone_type != "Fold":
			var inner_next := Vector3(opening[next_index].x, mouth_y, opening[next_index].y)
			var inner_current := Vector3(opening[index].x, mouth_y, opening[index].y)
			var wall_normal := Vector3((inner_current.x + inner_next.x) * 0.5, 0.0, (inner_current.z + inner_next.z) * 0.5).normalized()
			var front_a := Vector3(inner_current.x, inner_current.y, half_size.z)
			var front_b := Vector3(inner_next.x, inner_next.y, half_size.z)
			var back_a := Vector3(inner_current.x, inner_current.y, -half_size.z)
			var back_b := Vector3(inner_next.x, inner_next.y, -half_size.z)
			_add_phone_mesh_triangle(surface, front_a, back_a, back_b, wall_normal)
			_add_phone_mesh_triangle(surface, front_a, back_b, front_b, wall_normal)


func _create_rounded_phone_mesh(radius: float, port_opening: PackedVector2Array, size_override: Vector3 = Vector3.ZERO, corner_mask: int = 15) -> Mesh:
	var phone_size := _active_phone_size()
	if size_override.x > 0.0 and size_override.y > 0.0:
		phone_size.x = size_override.x
		phone_size.y = size_override.y
	# The former minimum 0.08-unit body is preserved at new level 2.
	phone_size.z = _phone_depth_for_thickness_level()
	var half_size := phone_size * 0.5
	var outline := PackedVector2Array()
	var rounded_outline_points: Array[bool] = []

	var corner_points := [
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y)
	]
	if radius <= 0.0001:
		for corner_point in corner_points:
			outline.append(corner_point)
			rounded_outline_points.append(false)
	else:
		# Round only selected outer corners. The two corners beside a fold
		# hinge remain square so both leaves form one continuous perimeter.
		var corner_radius := clampf(radius, 0.0, minf(half_size.x, half_size.y) - 0.001)
		var corner_segments := 48
		for corner_index in range(4):
			var corner_point: Vector2 = corner_points[corner_index]
			var should_round := (corner_mask & (1 << corner_index)) != 0 and corner_radius > 0.0001
			if should_round:
				var center := Vector2(
					signf(corner_point.x) * (half_size.x - corner_radius),
					signf(corner_point.y) * (half_size.y - corner_radius)
				)
				var start_angle := float(corner_index) * PI * 0.5
				for segment in range(corner_segments + 1):
					var angle := start_angle + float(segment) / float(corner_segments) * PI * 0.5
					outline.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)
					rounded_outline_points.append(true)
			else:
				outline.append(corner_point)
				rounded_outline_points.append(false)

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

	# Build the perimeter with crisp hinge-side corners and smooth outside arcs.
	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[next_index]
		var is_bottom_edge := absf(a.y + half_size.y) < 0.0001 and absf(b.y + half_size.y) < 0.0001
		if is_bottom_edge and port_opening.size() >= 3:
			var flat_bottom_half_width := maxf(absf(a.x), absf(b.x))
			var flat_bottom_left := minf(a.x, b.x)
			var flat_bottom_right := maxf(a.x, b.x)
			_add_phone_bottom_edge_with_port(surface, phone_size, port_opening, flat_bottom_half_width, flat_bottom_left, flat_bottom_right)
		else:
			var edge := b - a
			var side_normal := Vector3(edge.y, -edge.x, 0.0).normalized()
			var normal_a := side_normal
			var normal_b := side_normal
			if rounded_outline_points[index]:
				var previous_a: Vector2 = outline[(index - 1 + outline.size()) % outline.size()]
				var previous_edge_a := a - previous_a
				var previous_normal_a := Vector3(previous_edge_a.y, -previous_edge_a.x, 0.0).normalized()
				normal_a = (previous_normal_a + side_normal).normalized()
			if rounded_outline_points[next_index]:
				var next_b: Vector2 = outline[(next_index + 1) % outline.size()]
				var next_edge_b := next_b - b
				var next_normal_b := Vector3(next_edge_b.y, -next_edge_b.x, 0.0).normalized()
				normal_b = (side_normal + next_normal_b).normalized()
			var front_a := Vector3(a.x, a.y, front_z)
			var front_b := Vector3(b.x, b.y, front_z)
			var back_a := Vector3(a.x, a.y, back_z)
			var back_b := Vector3(b.x, b.y, back_z)
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
	software_summary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	software_summary_panel.clip_contents = true
	software_summary_panel.visible = false
	preview_stack.add_child(software_summary_panel)

	# The middle preview card becomes a real vertical specification view.
	var scroll := ScrollContainer.new()
	scroll.name = "SoftwareSpecificationsVerticalScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keep vertical scrolling active while hiding its visual scrollbar.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	software_summary_panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "SoftwareSpecificationContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Guarantee overflow in the middle panel so touch/mouse scrolling always
	# has a real vertical range, even on tall displays.
	content.custom_minimum_size.y = 900.0
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var heading := _make_label("SOFTWARE SPECIFICATIONS", 21, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_research_typography(heading, 21)
	content.add_child(heading)
	var subtitle := _make_label("DEVICE CONFIGURATION", 14, Color("#a9c9dc"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_research_typography(subtitle, 14)
	content.add_child(subtitle)
	content.add_child(HSeparator.new())

	software_value_labels.clear()
	var specifications := [
		["RAM", selected_ram_capacity],
		["ROM", selected_rom_capacity],
		["BATTERY", selected_battery_capacity],
		["PHONE TYPE", selected_phone_type],
		["REFRESH RATE", selected_refresh_rate],
		["MEMORY CLOCK", selected_memory_clock],
		["COOLING SYSTEM", selected_cooling_system],
		["CHARGING SPEED", str(selected_charging_speed) + "W"],
		["WIRELESS CHARGING", (str(selected_wireless_charging_speed) + "W" if selected_wireless_charge_enabled else "Disabled")],
		["BLUETOOTH", selected_bluetooth_version],
		["WI-FI", selected_wifi_standard],
		["MOBILE NETWORK", selected_mobile_network],
		["FRONT CAMERAS", _get_front_camera_mp_summary()],
		["REAR CAMERAS", _get_rear_camera_mp_summary()],
		["CHIPSET", "Not set"],
		["OPERATING SYSTEM", "Not set"],
		["RAM TECHNOLOGY", selected_ram_technology],
		["STORAGE TYPE", "Not set"],
		["CONNECTIVITY", "Not set"],
		["SENSORS", _get_enabled_sensor_summary()]
	]
	for specification in specifications:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)
		var name_label := _make_label(str(specification[0]) + ":", 15, Color("#d8f1ff"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(name_label, 15)
		row.add_child(name_label)
		var value_label := _make_label(str(specification[1]), 15, Color.WHITE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(value_label, 15)
		row.add_child(value_label)
		software_value_labels[str(specification[0])] = value_label
	var hint := _make_label("Choose a software feature from the left panel to configure this device.", 13, Color("#a9c9dc"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_research_typography(hint, 13)
	content.add_child(hint)
	_update_camera_software_summary()


func _get_front_camera_mp_summary() -> String:
	if not front_camera_enabled:
		return "0 cameras"
	if front_camera_style == "Dual Punch-Hole":
		return "2 cameras — %d MP / %d MP" % [front_camera_megapixels, front_camera_secondary_megapixels]
	return "1 camera — %d MP" % front_camera_megapixels


func _get_rear_camera_mp_summary() -> String:
	if rear_camera_modules.is_empty():
		return "0 cameras"
	var megapixel_values: Array[String] = []
	for camera_index in range(rear_camera_modules.size()):
		var camera_data: Dictionary = rear_camera_modules[camera_index]
		megapixel_values.append("%d MP" % int(camera_data.get("mp", 12)))
	return "%d cameras — %s" % [rear_camera_modules.size(), " / ".join(megapixel_values)]


func _get_enabled_sensor_summary() -> String:
	var enabled_sensors: Array[String] = []
	for sensor_name in selected_phone_sensors.keys():
		if bool(selected_phone_sensors[sensor_name]):
			enabled_sensors.append(str(sensor_name))
	if enabled_sensors.is_empty():
		return "None enabled"
	return "%d enabled — %s" % [enabled_sensors.size(), ", ".join(enabled_sensors)]


func _update_sensor_software_summary() -> void:
	if software_value_labels.has("SENSORS") and is_instance_valid(software_value_labels["SENSORS"]):
		var sensor_label: Label = software_value_labels["SENSORS"]
		sensor_label.text = _get_enabled_sensor_summary()




func _update_memory_clock_software_summary() -> void:
	if software_value_labels.has("MEMORY CLOCK") and is_instance_valid(software_value_labels["MEMORY CLOCK"]):
		var clock_label: Label = software_value_labels["MEMORY CLOCK"]
		clock_label.text = selected_memory_clock


func _update_cooling_software_summary() -> void:
	if software_value_labels.has("COOLING SYSTEM") and is_instance_valid(software_value_labels["COOLING SYSTEM"]):
		var cooling_label: Label = software_value_labels["COOLING SYSTEM"]
		cooling_label.text = selected_cooling_system


func _update_camera_software_summary() -> void:
	if software_value_labels.has("FRONT CAMERAS") and is_instance_valid(software_value_labels["FRONT CAMERAS"]):
		var front_label: Label = software_value_labels["FRONT CAMERAS"]
		front_label.text = _get_front_camera_mp_summary()
	if software_value_labels.has("REAR CAMERAS") and is_instance_valid(software_value_labels["REAR CAMERAS"]):
		var rear_label: Label = software_value_labels["REAR CAMERAS"]
		rear_label.text = _get_rear_camera_mp_summary()


func _show_memory_clock_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "MemoryClockSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 12)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("MEMORY CLOCK", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	memory_clock_value_label = _make_label("CURRENT: " + selected_memory_clock.to_upper(), 16, Color("#d8f1ff"))
	memory_clock_value_label.name = "CurrentMemoryClockLabel"
	memory_clock_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(memory_clock_value_label)

	var range_heading := _make_label("4267 MHz", 13, Color("#a9e3ff"))
	range_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(range_heading)

	var slider_center := CenterContainer.new()
	slider_center.name = "MemoryClockSliderCenter"
	slider_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(slider_center)

	memory_clock_slider = VSlider.new()
	memory_clock_slider.name = "MemoryClockSlider"
	memory_clock_slider.min_value = 0
	memory_clock_slider.max_value = MEMORY_CLOCK_STEPS.size() - 1
	memory_clock_slider.step = 1
	memory_clock_slider.tick_count = MEMORY_CLOCK_STEPS.size()
	memory_clock_slider.custom_minimum_size = Vector2(76, 330)
	memory_clock_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	memory_clock_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	memory_clock_slider.value = maxf(0.0, float(_get_memory_clock_index()))
	memory_clock_slider.value_changed.connect(_on_memory_clock_slider_changed)
	_style_custom_slider(memory_clock_slider)
	slider_center.add_child(memory_clock_slider)

	var minimum_label := _make_label("400 MHz", 13, Color("#a9e3ff"))
	minimum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(minimum_label)

	var instruction := _make_label("DRAG THE SLIDER TO SET THE MEMORY CLOCK", 12, Color("#91b8ce"))
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(instruction)


func _get_memory_clock_index() -> int:
	for index in range(MEMORY_CLOCK_STEPS.size()):
		if selected_memory_clock == "%d MHz" % MEMORY_CLOCK_STEPS[index]:
			return index
	return -1


func _on_memory_clock_slider_changed(value: float) -> void:
	var index := clampi(int(round(value)), 0, MEMORY_CLOCK_STEPS.size() - 1)
	selected_memory_clock = "%d MHz" % MEMORY_CLOCK_STEPS[index]
	if is_instance_valid(memory_clock_value_label):
		memory_clock_value_label.text = "CURRENT: " + selected_memory_clock
	if software_value_labels.has("MEMORY CLOCK") and is_instance_valid(software_value_labels["MEMORY CLOCK"]):
		var clock_label: Label = software_value_labels["MEMORY CLOCK"]
		clock_label.text = selected_memory_clock


func _show_cooling_system_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "CoolingSystemSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("COOLING SYSTEM", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var current := _make_label("CURRENT: " + selected_cooling_system.to_upper(), 14, Color("#d8f1ff"))
	current.name = "CurrentCoolingSystemLabel"
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(current)

	var scroll := ScrollContainer.new()
	scroll.name = "CoolingSystemOptionsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	active_feature_panel.add_child(scroll)
	var options := VBoxContainer.new()
	options.name = "CoolingSystemOptions"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	scroll.add_child(options)

	var cooling_options := [
		"No Dedicated Cooling",
		"Graphite Sheet",
		"Graphite + Copper Foil",
		"Graphene Composite",
		"Heat Pipe",
		"Vapor Chamber",
		"Dual Vapor Chamber",
		"Vapor Chamber + Graphite Stack"
	]
	for cooling_type in cooling_options:
		var option := Button.new()
		option.name = "CoolingSystemOption_" + cooling_type.replace(" ", "").replace("+", "Plus")
		option.text = cooling_type + ("   ✓ SELECTED" if selected_cooling_system == cooling_type else "")
		option.custom_minimum_size.y = 46
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_research_typography(option, 14)
		_style_staff_button(option, selected_cooling_system == cooling_type)
		option.pressed.connect(_on_cooling_system_selected.bind(cooling_type))
		options.add_child(option)


func _on_cooling_system_selected(cooling_type: String) -> void:
	if not ["No Dedicated Cooling", "Graphite Sheet", "Graphite + Copper Foil", "Graphene Composite", "Heat Pipe", "Vapor Chamber", "Dual Vapor Chamber", "Vapor Chamber + Graphite Stack"].has(cooling_type):
		return
	selected_cooling_system = cooling_type
	if software_value_labels.has("COOLING SYSTEM") and is_instance_valid(software_value_labels["COOLING SYSTEM"]):
		var cooling_label: Label = software_value_labels["COOLING SYSTEM"]
		cooling_label.text = selected_cooling_system
	_show_cooling_system_controls()


func _show_refresh_rate_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "RefreshRateSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("DISPLAY REFRESH RATE", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	var current := _make_label("CURRENT: " + (selected_refresh_rate.to_upper() if selected_refresh_rate != "Not set" else "NOT SET"), 14, Color("#d8f1ff"))
	current.name = "CurrentRefreshRateLabel"
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(current)

	var scroll := ScrollContainer.new()
	scroll.name = "RefreshRateOptionsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	active_feature_panel.add_child(scroll)

	var options := VBoxContainer.new()
	options.name = "RefreshRateOptions"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	scroll.add_child(options)

	for rate in [60, 90, 120, 144, 165, 240]:
		var rate_text := "%d Hz" % rate
		var option := Button.new()
		option.name = "RefreshRateOption_%dHz" % rate
		option.text = rate_text + ("   ✓ SELECTED" if selected_refresh_rate == rate_text else "")
		option.custom_minimum_size.y = 43
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 14)
		_style_staff_button(option, selected_refresh_rate == rate_text)
		option.pressed.connect(_on_refresh_rate_selected.bind(rate_text))
		options.add_child(option)


func _on_refresh_rate_selected(rate_text: String) -> void:
	if not ["60 Hz", "90 Hz", "120 Hz", "144 Hz", "165 Hz", "240 Hz"].has(rate_text):
		return
	selected_refresh_rate = rate_text
	if software_value_labels.has("REFRESH RATE") and is_instance_valid(software_value_labels["REFRESH RATE"]):
		var refresh_label: Label = software_value_labels["REFRESH RATE"]
		refresh_label.text = selected_refresh_rate
	_show_refresh_rate_controls()


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

	var heading := _make_label("SELECT RAM", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
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
	for capacity in _get_supported_ram_capacities(selected_ram_technology):
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
	if not _get_supported_ram_capacities(selected_ram_technology).has(capacity):
		return
	selected_ram_capacity = capacity
	if software_value_labels.has("RAM") and is_instance_valid(software_value_labels["RAM"]):
		var ram_label: Label = software_value_labels["RAM"]
		ram_label.text = capacity
	_show_ram_controls()


func _get_supported_ram_capacities(technology: String) -> Array:
	var all_capacities := ["1 GB", "2 GB", "3 GB", "4 GB", "6 GB", "8 GB", "12 GB", "16 GB", "18 GB", "24 GB", "32 GB"]
	match technology:
		"LPDDR3":
			return ["1 GB", "2 GB", "3 GB", "4 GB"]
		"LPDDR4":
			return ["1 GB", "2 GB", "3 GB", "4 GB", "6 GB", "8 GB"]
		"LPDDR4X":
			return ["2 GB", "3 GB", "4 GB", "6 GB", "8 GB", "12 GB"]
		"LPDDR5":
			return ["4 GB", "6 GB", "8 GB", "12 GB", "16 GB"]
		"LPDDR5X":
			return ["8 GB", "12 GB", "16 GB", "18 GB", "24 GB", "32 GB"]
		"LPDDR5T":
			return ["12 GB", "16 GB", "18 GB", "24 GB", "32 GB"]
		_:
			return all_capacities


func _show_ram_technology_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "RAMTechnologySelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT RAM TECHNOLOGY", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var current := _make_label("CURRENT: " + selected_ram_technology.to_upper(), 13, Color.WHITE)
	current.name = "CurrentRAMTechnologyLabel"
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(current)

	var scroll := ScrollContainer.new()
	scroll.name = "RAMTechnologyOptionsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	active_feature_panel.add_child(scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	scroll.add_child(options)
	for technology in ["LPDDR3", "LPDDR4", "LPDDR4X", "LPDDR5", "LPDDR5X", "LPDDR5T"]:
		var option := Button.new()
		option.name = "RAMTechnologyOption_" + technology
		option.text = technology + ("   ✓ SELECTED" if selected_ram_technology == technology else "")
		option.custom_minimum_size.y = 43
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 14)
		_style_staff_button(option, selected_ram_technology == technology)
		option.pressed.connect(_on_ram_technology_selected.bind(technology))
		options.add_child(option)


func _on_ram_technology_selected(technology: String) -> void:
	if not ["LPDDR3", "LPDDR4", "LPDDR4X", "LPDDR5", "LPDDR5X", "LPDDR5T"].has(technology):
		return
	selected_ram_technology = technology
	var compatible_capacities := _get_supported_ram_capacities(technology)
	if selected_ram_capacity != "Not set" and not compatible_capacities.has(selected_ram_capacity):
		var previous_amount := int(selected_ram_capacity.replace(" GB", ""))
		var closest_capacity: String = str(compatible_capacities[0])
		var closest_distance := 2147483647
		for capacity_value in compatible_capacities:
			var candidate := str(capacity_value)
			var candidate_amount := int(candidate.replace(" GB", ""))
			var distance := absi(candidate_amount - previous_amount)
			if distance < closest_distance:
				closest_distance = distance
				closest_capacity = candidate
		selected_ram_capacity = closest_capacity
		if software_value_labels.has("RAM") and is_instance_valid(software_value_labels["RAM"]):
			var ram_label: Label = software_value_labels["RAM"]
			ram_label.text = selected_ram_capacity
	if software_value_labels.has("RAM TECHNOLOGY") and is_instance_valid(software_value_labels["RAM TECHNOLOGY"]):
		var technology_label: Label = software_value_labels["RAM TECHNOLOGY"]
		technology_label.text = selected_ram_technology
	_show_ram_technology_controls()


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

	var heading := _make_label("SELECT ROM", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
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
	for capacity in ["4 GB", "8 GB", "16 GB", "32 GB", "64 GB", "128 GB", "256 GB", "512 GB", "1 TB", "2 TB"]:
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
	if not ["4 GB", "8 GB", "16 GB", "32 GB", "64 GB", "128 GB", "256 GB", "512 GB", "1 TB", "2 TB"].has(capacity):
		return
	selected_rom_capacity = capacity
	if software_value_labels.has("ROM") and is_instance_valid(software_value_labels["ROM"]):
		var rom_label: Label = software_value_labels["ROM"]
		rom_label.text = capacity
	_show_rom_controls()


func _show_battery_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BatterySelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT BATTERY CAPACITY", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	# A fixed two-column grid presents all 24 capacities in twelve rows.
	# No ScrollContainer is used, so the battery panel itself never scrolls.
	var options := GridContainer.new()
	options.name = "BatteryCapacityGrid"
	options.columns = 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	options.add_theme_constant_override("h_separation", 7)
	options.add_theme_constant_override("v_separation", 7)
	active_feature_panel.add_child(options)

	for capacity in ["1,000 mAh", "1,250 mAh", "1,500 mAh", "1,750 mAh", "2,000 mAh", "2,250 mAh", "2,500 mAh", "2,750 mAh", "3,000 mAh", "3,250 mAh", "3,500 mAh", "3,750 mAh", "4,000 mAh", "4,250 mAh", "4,500 mAh", "4,750 mAh", "5,000 mAh", "5,250 mAh", "5,500 mAh", "6,000 mAh", "6,500 mAh", "7,000 mAh", "7,500 mAh", "8,000 mAh"]:
		var option := Button.new()
		option.name = "BatteryOption_" + capacity.replace(",", "").replace(" ", "")
		option.text = capacity + ("  ✓" if selected_battery_capacity == capacity else "")
		option.custom_minimum_size = Vector2(0, 39)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 15)
		var battery_option_font := FontVariation.new()
		battery_option_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		battery_option_font.variation_embolden = 1.5
		option.add_theme_font_override("font", battery_option_font)
		_style_staff_button(option, selected_battery_capacity == capacity)
		option.pressed.connect(_on_battery_capacity_selected.bind(capacity))
		options.add_child(option)


func _on_battery_capacity_selected(capacity: String) -> void:
	if not ["1,000 mAh", "1,250 mAh", "1,500 mAh", "1,750 mAh", "2,000 mAh", "2,250 mAh", "2,500 mAh", "2,750 mAh", "3,000 mAh", "3,250 mAh", "3,500 mAh", "3,750 mAh", "4,000 mAh", "4,250 mAh", "4,500 mAh", "4,750 mAh", "5,000 mAh", "5,250 mAh", "5,500 mAh", "6,000 mAh", "6,500 mAh", "7,000 mAh", "7,500 mAh", "8,000 mAh"].has(capacity):
		return
	selected_battery_capacity = capacity
	if software_value_labels.has("BATTERY") and is_instance_valid(software_value_labels["BATTERY"]):
		var battery_label: Label = software_value_labels["BATTERY"]
		battery_label.text = capacity
	_show_battery_controls()


func _show_charging_speed_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "ChargingSpeedControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("WIRED CHARGING SPEED", 17, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	charging_speed_value_label = _make_label(str(selected_charging_speed) + "W", 31, Color.WHITE)
	charging_speed_value_label.name = "ChargingSpeedValue"
	charging_speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(charging_speed_value_label)

	var range_hint := _make_label("2W  —  200W", 12, Color("#a9c9dc"))
	range_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(range_hint)

	var slider_row := HBoxContainer.new()
	slider_row.name = "ChargingSpeedSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 12)
	active_feature_panel.add_child(slider_row)

	var minimum_label := _make_label("2W", 11, Color("#a9c9dc"))
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)

	charging_speed_slider = VSlider.new()
	charging_speed_slider.name = "ChargingSpeedVerticalSlider"
	charging_speed_slider.min_value = 2
	charging_speed_slider.max_value = 200
	charging_speed_slider.step = 1
	charging_speed_slider.value = selected_charging_speed
	charging_speed_slider.custom_minimum_size = Vector2(52, 245)
	charging_speed_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	charging_speed_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	charging_speed_slider.focus_mode = Control.FOCUS_NONE
	charging_speed_slider.tick_count = 0
	charging_speed_slider.value_changed.connect(_on_charging_speed_changed)
	_style_custom_slider(charging_speed_slider)
	slider_row.add_child(charging_speed_slider)

	var maximum_label := _make_label("200W", 11, Color("#a9c9dc"))
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)

	var adjustment_row := HBoxContainer.new()
	adjustment_row.name = "ChargingSpeedFineAdjustment"
	adjustment_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adjustment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	adjustment_row.add_theme_constant_override("separation", 12)
	active_feature_panel.add_child(adjustment_row)

	charging_speed_decrease_button = Button.new()
	charging_speed_decrease_button.name = "DecreaseChargingSpeed"
	charging_speed_decrease_button.text = "−  1W"
	charging_speed_decrease_button.custom_minimum_size = Vector2(76, 42)
	charging_speed_decrease_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(charging_speed_decrease_button, 14)
	_style_staff_button(charging_speed_decrease_button, false)
	charging_speed_decrease_button.pressed.connect(_adjust_charging_speed.bind(-1))
	adjustment_row.add_child(charging_speed_decrease_button)

	charging_speed_increase_button = Button.new()
	charging_speed_increase_button.name = "IncreaseChargingSpeed"
	charging_speed_increase_button.text = "+  1W"
	charging_speed_increase_button.custom_minimum_size = Vector2(76, 42)
	charging_speed_increase_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(charging_speed_increase_button, 14)
	_style_staff_button(charging_speed_increase_button, false)
	charging_speed_increase_button.pressed.connect(_adjust_charging_speed.bind(1))
	adjustment_row.add_child(charging_speed_increase_button)

	_update_charging_speed_controls()


func _on_charging_speed_changed(value: float) -> void:
	# Phone charging capability is independent from the adapter's maximum output.
	selected_charging_speed = clampi(roundi(value), 2, 200)
	_update_charging_speed_controls()


func _adjust_charging_speed(amount: int) -> void:
	selected_charging_speed = clampi(selected_charging_speed + amount, 2, 200)
	if is_instance_valid(charging_speed_slider):
		charging_speed_slider.set_value_no_signal(selected_charging_speed)
	_update_charging_speed_controls()


func _update_charging_speed_controls() -> void:
	if is_instance_valid(charging_speed_value_label):
		charging_speed_value_label.text = str(selected_charging_speed) + "W"
	if is_instance_valid(charging_speed_slider) and not is_equal_approx(charging_speed_slider.value, float(selected_charging_speed)):
		charging_speed_slider.set_value_no_signal(selected_charging_speed)
	if is_instance_valid(charging_speed_decrease_button):
		charging_speed_decrease_button.disabled = selected_charging_speed <= 2
	if is_instance_valid(charging_speed_increase_button):
		charging_speed_increase_button.disabled = selected_charging_speed >= 200
	if software_value_labels.has("CHARGING SPEED") and is_instance_valid(software_value_labels["CHARGING SPEED"]):
		var speed_label: Label = software_value_labels["CHARGING SPEED"]
		speed_label.text = str(selected_charging_speed) + "W"


func _show_wireless_charge_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "WirelessChargeControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("WIRELESS CHARGING", 17, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	wireless_charge_enable_checkbox = Button.new()
	wireless_charge_enable_checkbox.name = "CustomWirelessChargeCheckbox"
	wireless_charge_enable_checkbox.toggle_mode = true
	wireless_charge_enable_checkbox.button_pressed = selected_wireless_charge_enabled
	wireless_charge_enable_checkbox.text = ("☑  ENABLE WIRELESS CHARGING" if selected_wireless_charge_enabled else "□  ENABLE WIRELESS CHARGING")
	wireless_charge_enable_checkbox.custom_minimum_size = Vector2(0, 48)
	wireless_charge_enable_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wireless_charge_enable_checkbox.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(wireless_charge_enable_checkbox, 15)
	_style_staff_button(wireless_charge_enable_checkbox, selected_wireless_charge_enabled)
	wireless_charge_enable_checkbox.toggled.connect(_on_wireless_charge_enabled_changed)
	active_feature_panel.add_child(wireless_charge_enable_checkbox)

	wireless_charging_speed_value_label = _make_label(str(selected_wireless_charging_speed) + "W", 29, Color.WHITE)
	wireless_charging_speed_value_label.name = "WirelessChargingSpeedValue"
	wireless_charging_speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(wireless_charging_speed_value_label)

	var range_hint := _make_label("5W  —  80W", 12, Color("#a9c9dc"))
	range_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(range_hint)

	var slider_row := HBoxContainer.new()
	slider_row.name = "WirelessChargingSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	active_feature_panel.add_child(slider_row)

	var minimum_label := _make_label("5W", 11, Color("#a9c9dc"))
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)

	wireless_charging_speed_slider = VSlider.new()
	wireless_charging_speed_slider.name = "WirelessChargingVerticalSlider"
	wireless_charging_speed_slider.min_value = 5
	wireless_charging_speed_slider.max_value = 80
	wireless_charging_speed_slider.step = 1
	wireless_charging_speed_slider.value = selected_wireless_charging_speed
	wireless_charging_speed_slider.custom_minimum_size = Vector2(52, 245)
	wireless_charging_speed_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wireless_charging_speed_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wireless_charging_speed_slider.focus_mode = Control.FOCUS_NONE
	wireless_charging_speed_slider.value_changed.connect(_on_wireless_charging_speed_changed)
	_style_custom_slider(wireless_charging_speed_slider)
	slider_row.add_child(wireless_charging_speed_slider)

	var maximum_label := _make_label("80W", 11, Color("#a9c9dc"))
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)

	_update_wireless_charge_controls()


func _on_wireless_charge_enabled_changed(enabled: bool) -> void:
	selected_wireless_charge_enabled = enabled
	_update_wireless_charge_controls()
	if is_instance_valid(active_feature_panel) and active_feature_panel.name == "ChargingSpeedControls":
		_show_charging_speed_controls()


func _on_wireless_charging_speed_changed(value: float) -> void:
	selected_wireless_charging_speed = clampi(roundi(value), 5, 80)
	_update_wireless_charge_controls()


func _update_wireless_charge_controls() -> void:
	if is_instance_valid(wireless_charge_enable_checkbox):
		wireless_charge_enable_checkbox.button_pressed = selected_wireless_charge_enabled
		wireless_charge_enable_checkbox.text = ("☑  ENABLE WIRELESS CHARGING" if selected_wireless_charge_enabled else "□  ENABLE WIRELESS CHARGING")
		_style_staff_button(wireless_charge_enable_checkbox, selected_wireless_charge_enabled)
	if is_instance_valid(wireless_charging_speed_slider):
		wireless_charging_speed_slider.editable = selected_wireless_charge_enabled
		if not is_equal_approx(wireless_charging_speed_slider.value, float(selected_wireless_charging_speed)):
			wireless_charging_speed_slider.set_value_no_signal(selected_wireless_charging_speed)
	if is_instance_valid(wireless_charging_speed_value_label):
		wireless_charging_speed_value_label.text = (str(selected_wireless_charging_speed) + "W" if selected_wireless_charge_enabled else "Disabled")
	if software_value_labels.has("WIRELESS CHARGING") and is_instance_valid(software_value_labels["WIRELESS CHARGING"]):
		var wireless_label: Label = software_value_labels["WIRELESS CHARGING"]
		wireless_label.text = (str(selected_wireless_charging_speed) + "W" if selected_wireless_charge_enabled else "Disabled")


func _show_bluetooth_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BluetoothSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT BLUETOOTH VERSION", 17, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	# Non-scrollable two-column grid. Short BT labels keep every option readable.
	var options := GridContainer.new()
	options.name = "BluetoothVersionOptions"
	options.columns = 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	options.add_theme_constant_override("h_separation", 6)
	options.add_theme_constant_override("v_separation", 6)
	active_feature_panel.add_child(options)

	for version in ["Bluetooth 2.0 + EDR", "Bluetooth 2.1 + EDR", "Bluetooth 3.0 + HS", "Bluetooth 4.0", "Bluetooth 4.1", "Bluetooth 4.2", "Bluetooth 5.0", "Bluetooth 5.1", "Bluetooth 5.2", "Bluetooth 5.3", "Bluetooth 5.4", "Bluetooth 6.0", "Bluetooth 6.1", "Bluetooth 6.2"]:
		var option := Button.new()
		option.name = "BluetoothOption_" + version.replace(" ", "").replace("+", "").replace(".", "_")
		var button_label: String = version.replace("Bluetooth ", "BT ").replace(" + EDR", " EDR").replace(" + HS", " HS")
		option.text = button_label + ("  ✓" if selected_bluetooth_version == version else "")
		option.tooltip_text = version
		option.custom_minimum_size = Vector2(0, 42)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 15)
		var option_font := FontVariation.new()
		option_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		option_font.variation_embolden = 1.5
		option.add_theme_font_override("font", option_font)
		_style_staff_button(option, selected_bluetooth_version == version)
		option.pressed.connect(_on_bluetooth_version_selected.bind(version))
		options.add_child(option)


func _on_bluetooth_version_selected(version: String) -> void:
	if not ["Bluetooth 2.0 + EDR", "Bluetooth 2.1 + EDR", "Bluetooth 3.0 + HS", "Bluetooth 4.0", "Bluetooth 4.1", "Bluetooth 4.2", "Bluetooth 5.0", "Bluetooth 5.1", "Bluetooth 5.2", "Bluetooth 5.3", "Bluetooth 5.4", "Bluetooth 6.0", "Bluetooth 6.1", "Bluetooth 6.2"].has(version):
		return
	selected_bluetooth_version = version
	if software_value_labels.has("BLUETOOTH") and is_instance_valid(software_value_labels["BLUETOOTH"]):
		var bluetooth_label: Label = software_value_labels["BLUETOOTH"]
		bluetooth_label.text = version
	_show_bluetooth_controls()


func _show_wifi_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "WiFiSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT WI-FI STANDARD", 17, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	# Non-scrollable two-column grid for all Wi-Fi standards.
	var options := GridContainer.new()
	options.name = "WiFiStandardOptions"
	options.columns = 1
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	options.add_theme_constant_override("h_separation", 6)
	options.add_theme_constant_override("v_separation", 6)
	active_feature_panel.add_child(options)

	for standard in ["Wi-Fi 1 (802.11b)", "Wi-Fi 2 (802.11a)", "Wi-Fi 3 (802.11g)", "Wi-Fi 4 (802.11n)", "Wi-Fi 5 (802.11ac)", "Wi-Fi 6 (802.11ax)", "Wi-Fi 6E (802.11ax, 6 GHz)", "Wi-Fi 7 (802.11be)"]:
		var option := Button.new()
		option.name = "WiFiOption_" + standard.replace(" ", "").replace("(", "").replace(")", "").replace(".", "_").replace(",", "")
		var button_label: String = "Wi-Fi " + standard.get_slice(" ", 1).split(" ")[0]
		option.text = button_label + ("  ✓" if selected_wifi_standard == standard else "")
		option.tooltip_text = standard
		option.custom_minimum_size = Vector2(0, 42)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 15)
		var option_font := FontVariation.new()
		option_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		option_font.variation_embolden = 1.5
		option.add_theme_font_override("font", option_font)
		_style_staff_button(option, selected_wifi_standard == standard)
		option.pressed.connect(_on_wifi_standard_selected.bind(standard))
		options.add_child(option)


func _on_wifi_standard_selected(standard: String) -> void:
	if not ["Wi-Fi 1 (802.11b)", "Wi-Fi 2 (802.11a)", "Wi-Fi 3 (802.11g)", "Wi-Fi 4 (802.11n)", "Wi-Fi 5 (802.11ac)", "Wi-Fi 6 (802.11ax)", "Wi-Fi 6E (802.11ax, 6 GHz)", "Wi-Fi 7 (802.11be)"].has(standard):
		return
	selected_wifi_standard = standard
	if software_value_labels.has("WI-FI") and is_instance_valid(software_value_labels["WI-FI"]):
		var wifi_label: Label = software_value_labels["WI-FI"]
		wifi_label.text = standard
	_show_wifi_controls()


func _show_sensor_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()

	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "PhoneSensorSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 8)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("PHONE SENSORS", 21, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var count_label := _make_label("", 15, Color("#d8f1ff"))
	count_label.name = "EnabledSensorCount"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(count_label)

	var scroll := ScrollContainer.new()
	scroll.name = "PhoneSensorOptionsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	active_feature_panel.add_child(scroll)

	var options := VBoxContainer.new()
	options.name = "PhoneSensorOptions"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	scroll.add_child(options)

	for sensor_name in selected_phone_sensors.keys():
		var row := HBoxContainer.new()
		row.name = "SensorRow_" + str(sensor_name).replace(" ", "_").replace("/", "_")
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		options.add_child(row)

		var sensor_label := _make_label(str(sensor_name), 16, Color("#e7f6ff"))
		sensor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sensor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sensor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(sensor_label)

		var toggle := TextureButton.new()
		toggle.name = "SensorEnabledToggle"
		toggle.custom_minimum_size = Vector2(42, 42)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.ignore_texture_size = true
		toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		toggle.texture_normal = _make_side_button_checkbox_icon(bool(selected_phone_sensors[sensor_name]))
		toggle.texture_hover = _make_side_button_checkbox_icon(bool(selected_phone_sensors[sensor_name]))
		toggle.texture_pressed = _make_side_button_checkbox_icon(true)
		toggle.texture_disabled = _make_side_button_checkbox_icon(false)
		toggle.toggle_mode = true
		toggle.button_pressed = bool(selected_phone_sensors[sensor_name])
		toggle.tooltip_text = "Enable or disable " + str(sensor_name)
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		toggle.toggled.connect(_on_phone_sensor_toggled.bind(str(sensor_name), count_label, toggle))
		row.add_child(toggle)

	_update_sensor_count_label(count_label)


func _update_sensor_count_label(count_label: Label) -> void:
	if not is_instance_valid(count_label):
		return
	var enabled_count := 0
	for sensor_name in selected_phone_sensors.keys():
		if bool(selected_phone_sensors[sensor_name]):
			enabled_count += 1
	count_label.text = "%d OF %d SENSORS ENABLED" % [enabled_count, selected_phone_sensors.size()]


func _on_phone_sensor_toggled(enabled: bool, sensor_name: String, count_label: Label, toggle: TextureButton) -> void:
	if not selected_phone_sensors.has(sensor_name):
		return
	selected_phone_sensors[sensor_name] = enabled
	if is_instance_valid(toggle):
		var icon := _make_side_button_checkbox_icon(enabled)
		toggle.texture_normal = icon
		toggle.texture_hover = icon
		toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	_update_sensor_count_label(count_label)
	_update_sensor_software_summary()


func _show_mobile_network_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "MobileNetworkSelectionControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation", 9)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("SELECT MOBILE NETWORK", 17, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)

	var options := GridContainer.new()
	options.name = "MobileNetworkOptions"
	options.columns = 1
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	options.add_theme_constant_override("h_separation", 6)
	options.add_theme_constant_override("v_separation", 6)
	active_feature_panel.add_child(options)

	var networks := [
		"2G (GSM / EDGE)",
		"3G (UMTS / HSPA)",
		"4G (LTE)",
		"4G+ (LTE-Advanced)",
		"5G NSA",
		"5G SA",
		"5G-Advanced"
	]
	for network in networks:
		var option := Button.new()
		option.name = "MobileNetworkOption_" + network.replace(" ", "").replace("/", "_").replace("(", "").replace(")", "").replace("+", "Plus")
		var display_name: String = network
		match network:
			"2G (GSM / EDGE)":
				display_name = "2G"
			"3G (UMTS / HSPA)":
				display_name = "3G"
			"4G (LTE)":
				display_name = "4G LTE"
			"4G+ (LTE-Advanced)":
				display_name = "4G+"
			"5G-Advanced":
				display_name = "5G-A"
		option.text = display_name + ("  ✓" if selected_mobile_network == network else "")
		option.tooltip_text = network
		option.custom_minimum_size = Vector2(0, 42)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_research_typography(option, 15)
		var option_font := FontVariation.new()
		option_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
		option_font.variation_embolden = 1.5
		option.add_theme_font_override("font", option_font)
		_style_staff_button(option, selected_mobile_network == network)
		option.pressed.connect(_on_mobile_network_selected.bind(network))
		options.add_child(option)


func _on_mobile_network_selected(network: String) -> void:
	if not ["2G (GSM / EDGE)", "3G (UMTS / HSPA)", "4G (LTE)", "4G+ (LTE-Advanced)", "5G NSA", "5G SA", "5G-Advanced"].has(network):
		return
	selected_mobile_network = network
	if software_value_labels.has("MOBILE NETWORK") and is_instance_valid(software_value_labels["MOBILE NETWORK"]):
		var network_label: Label = software_value_labels["MOBILE NETWORK"]
		network_label.text = network
	_show_mobile_network_controls()


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
	if left_tools_page != 2 and box_package_preview_mode:
		_set_box_package_preview_mode(false)
	_update_phone_case_preview_mode()
	if is_instance_valid(preview_container):
		preview_container.visible = left_tools_page != 1
	if is_instance_valid(software_summary_panel):
		software_summary_panel.visible = left_tools_page == 1
		if left_tools_page == 1:
			_update_camera_software_summary()
			_update_sensor_software_summary()
			_update_memory_clock_software_summary()
			_update_cooling_software_summary()
	var tools_content := get_node_or_null("PhoneEditorInterface/PhoneEditorRoot/PhoneEditorPageMargin/PhoneEditorMainLayout/PhoneEditorLeftToolsCard/PhoneEditorLeftToolsCardScroll/PhoneEditorLeftToolsCardPages")
	if not is_instance_valid(tools_content):
		return
	for page_index in range(3):
		var page_grid := tools_content.get_node_or_null("PhoneEditorLeftToolsCardButtonPage" + str(page_index + 1))
		if is_instance_valid(page_grid):
			page_grid.visible = page_index == left_tools_page


func _build_phone_case_preview(parent: Node3D) -> void:
	phone_case_preview = Node3D.new()
	phone_case_preview.name = "PhoneCasePreview"
	phone_case_preview.visible = false
	parent.add_child(phone_case_preview)


func _build_box_package_preview(parent: Node3D) -> void:
	box_package_preview = Node3D.new()
	box_package_preview.name = "BoxPackagePreview"
	box_package_preview.visible = false
	parent.add_child(box_package_preview)


func _case_outline(expansion: float) -> PackedVector2Array:
	var phone_size := _active_phone_size()
	return _case_outline_for_size(Vector2(phone_size.x, phone_size.y), expansion, 15)


func _case_rounded_cutout(width: float, height: float, radius: float) -> PackedVector2Array:
	var x := width * 0.5
	var y := height * 0.5
	var r := clampf(radius,0.002,minf(x,y)-0.001)
	var centers := [Vector2(x-r,y-r),Vector2(-x+r,y-r),Vector2(-x+r,-y+r),Vector2(x-r,-y+r)]
	var points := PackedVector2Array()
	for corner in range(4):
		var first_step := 0 if corner == 0 else 1
		var last_step := 4 if corner < 3 else 3
		for step in range(first_step,last_step+1):
			var angle := float(corner)*PI*0.5+float(step)/4.0*PI*0.5
			points.append(centers[corner]+Vector2(cos(angle),sin(angle))*r)
	return points


func _case_circle_outline(radius: float, segments: int = 56) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segment_count := maxi(segments, 12)
	for index in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _create_case_camera_trim_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#c6a04b")
	material.metallic = 0.88
	material.roughness = 0.22
	material.clearcoat_enabled = true
	material.clearcoat = 0.28
	material.clearcoat_roughness = 0.20
	return material


func _add_phone_case_camera_trim(parent: Node3D, centre: Vector2, inner_outline: PackedVector2Array, outer_outline: PackedVector2Array, surface_z: float, node_name: String, trim_material: Material) -> void:
	if inner_outline.size() < 12 or inner_outline.size() != outer_outline.size():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rear_normal := Vector3(0.0, 0.0, -1.0)
	for index in range(inner_outline.size()):
		var next := (index + 1) % inner_outline.size()
		var inner_a: Vector2 = inner_outline[index]
		var inner_b: Vector2 = inner_outline[next]
		var outer_a: Vector2 = outer_outline[index]
		var outer_b: Vector2 = outer_outline[next]
		_add_phone_mesh_triangle(surface, Vector3(inner_a.x, inner_a.y, 0.0), Vector3(outer_a.x, outer_a.y, 0.0), Vector3(outer_b.x, outer_b.y, 0.0), rear_normal)
		_add_phone_mesh_triangle(surface, Vector3(inner_a.x, inner_a.y, 0.0), Vector3(outer_b.x, outer_b.y, 0.0), Vector3(inner_b.x, inner_b.y, 0.0), rear_normal)
	var trim := MeshInstance3D.new()
	trim.name = node_name
	trim.mesh = surface.commit()
	trim.material_override = trim_material
	trim.position = Vector3(centre.x, centre.y, surface_z)
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(trim)


func _add_phone_case_camera_aperture(combiner: CSGCombiner3D, centre: Vector2, module_size: float, depth: float, wall: float, opening_name: String, trim_material: Material) -> void:
	# The widest camera/flash housing tier uses radius module_size * 1.22.
	# Add a small clearance so the pouch never touches the raised housing.
	var housing_radius := module_size * 1.22
	var aperture_radius := housing_radius + 0.010
	var opening := CSGPolygon3D.new()
	opening.name = opening_name
	opening.polygon = _case_circle_outline(aperture_radius)
	opening.depth = wall * 3.0 + 0.02
	opening.position = Vector3(centre.x, centre.y, -depth * 0.5 + wall * 1.5)
	opening.smooth_faces = true
	_case_subtract(combiner, opening)

	# A fine metallic lip follows the circular cut, with a small air gap left
	# between the gold edge and the camera/flash body.
	var inner_outline := _case_circle_outline(aperture_radius - 0.001)
	var outer_outline := _case_circle_outline(aperture_radius + 0.007)
	var rear_case_surface_z := -depth * 0.5 - wall - 0.001
	_add_phone_case_camera_trim(phone_case_preview, centre, inner_outline, outer_outline, rear_case_surface_z, opening_name + "GoldTrim", trim_material)


func _create_phone_case_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 solid_color : source_color = vec4(0.16, 0.22, 0.28, 1.0);
uniform vec4 gradient_color : source_color = vec4(0.24, 0.46, 0.66, 1.0);
uniform bool gradient_enabled = false;
uniform int gradient_direction : hint_range(0, 3) = 0;
uniform int design_style : hint_range(0, 4) = 0;
varying vec3 case_pos;
varying vec3 case_normal;
void vertex() {
	case_pos = VERTEX;
	case_normal = NORMAL;
}
void fragment() {
	vec2 p = case_pos.xy / vec2(0.95, 1.9) + vec2(0.5);
	float t = p.y;
	if (gradient_direction == 1) { t = p.x; }
	else if (gradient_direction == 2) { t = clamp((p.x+p.y)*0.5,0.0,1.0); }
	else if (gradient_direction == 3) { t = clamp(length((p-vec2(0.5))*vec2(1.0,1.8))*1.4142,0.0,1.0); }
	vec3 base_color = gradient_enabled ? mix(solid_color.rgb,gradient_color.rgb,clamp(t,0.0,1.0)) : solid_color.rgb;
	vec3 case_color = base_color;

	// Procedural finishes are applied only to the rear-facing case surface.
	if (case_normal.z < -0.5 && design_style > 0) {
		float luminance = dot(base_color, vec3(0.299, 0.587, 0.114));
		vec3 detail_color = mix(base_color * 0.38, min(base_color + vec3(0.30), vec3(1.0)), step(0.45, luminance));
		float detail = 0.0;
		if (design_style == 1) {
			// Alternating diagonal fibers create a carbon-weave finish.
			vec2 tile = fract(p * vec2(34.0, 58.0));
			float diagonal_a = 1.0 - smoothstep(0.12, 0.42, abs(tile.x - tile.y));
			float diagonal_b = 1.0 - smoothstep(0.12, 0.42, abs(tile.x + tile.y - 1.0));
			detail = mix(diagonal_a, diagonal_b, step(0.5, mod(floor(p.x * 34.0) + floor(p.y * 58.0), 2.0)));
		} else if (design_style == 2) {
			// Fine hexagonal outlines give the back a technical panel texture.
			vec2 hex_uv = p * vec2(20.0, 34.0);
			vec2 cell = abs(fract(hex_uv) - vec2(0.5));
			float edge = abs(max(cell.x * 0.8660254 + cell.y * 0.5, cell.y) - 0.36);
			detail = 1.0 - smoothstep(0.018, 0.055, edge);
		} else if (design_style == 3) {
			// Two slim diagonal racing lines run the length of the rear panel.
			float stripe_a = 1.0 - smoothstep(0.018, 0.045, abs(p.x - (0.27 + (p.y - 0.5) * 0.10)));
			float stripe_b = 1.0 - smoothstep(0.018, 0.045, abs(p.x - (0.36 + (p.y - 0.5) * 0.10)));
			detail = max(stripe_a, stripe_b);
		} else if (design_style == 4) {
			// Closely spaced ridges add a subtle grippy rear texture.
			detail = 1.0 - smoothstep(0.08, 0.19, abs(fract(p.x * 24.0) - 0.5));
		}
		case_color = mix(base_color, detail_color, clamp(detail * 0.58, 0.0, 0.58));
	}
	ALBEDO = case_color;
	METALLIC = 0.04;
	ROUGHNESS = (case_normal.z < -0.5 && design_style == 4) ? 0.62 : 0.46;
	SPECULAR = 0.78;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("solid_color",phone_case_color)
	material.set_shader_parameter("gradient_color",phone_case_gradient_color)
	material.set_shader_parameter("gradient_enabled",phone_case_gradient_enabled)
	material.set_shader_parameter("gradient_direction",phone_case_gradient_direction)
	material.set_shader_parameter("design_style",phone_case_design_style)
	return material


func _refresh_phone_case_material() -> void:
	if is_instance_valid(phone_case_preview):
		var case_material := _create_phone_case_material()
		var case_shells := phone_case_preview.find_children("ProtectiveOuterShell", "CSGPolygon3D", true, false)
		var case_back_plates := phone_case_preview.find_children("ProtectiveBackPlate", "CSGPolygon3D", true, false)
		case_shells.append_array(case_back_plates)
		for shell_node in case_shells:
			var shell := shell_node as CSGPolygon3D
			if is_instance_valid(shell):
				shell.material = case_material
		var hinge_bridge := phone_case_preview.get_node_or_null("FlexibleCaseHingeBridge") as MeshInstance3D
		if is_instance_valid(hinge_bridge):
			var bridge_material := StandardMaterial3D.new()
			bridge_material.albedo_color = phone_case_color.darkened(0.32)
			bridge_material.roughness = 0.86
			bridge_material.metallic = 0.01
			hinge_bridge.material_override = bridge_material
	elif is_instance_valid(phone_case_shell):
		phone_case_shell.material = _create_phone_case_material()


func _case_subtract(combiner: CSGCombiner3D, cutter: CSGShape3D) -> void:
	cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
	cutter.use_collision = false
	combiner.add_child(cutter)


func _case_side_opening(combiner: CSGCombiner3D, side: float, y: float, length: float, depth: float, wall: float, opening_name: String) -> void:
	var opening := CSGBox3D.new()
	opening.name = opening_name
	# Cut only a button-width band through the side wall. The former fixed
	# 72 mm depth spanned the complete phone thickness and could open the back.
	# Leave a case-material margin on both the front and rear faces.
	var side_cut_depth := minf(0.056, maxf(0.026, depth * 0.50))
	opening.size = Vector3(wall * 2.0 + 0.055, maxf(length + 0.008, 0.045), side_cut_depth)
	opening.position = Vector3(side * _active_phone_size().x * 0.5, y, 0.0)
	_case_subtract(combiner, opening)


func _case_outline_for_size(size: Vector2, expansion: float, corner_mask: int = 15) -> PackedVector2Array:
	# Use the same corner order and 48-segment arcs as the saved chassis mesh.
	# Fold/Flip case lips remain square at hinge-side corners.
	var half_w := size.x * 0.5 + expansion
	var half_h := size.y * 0.5 + expansion
	var radius := clampf(0.32 * float(border_radius_level) / 6.0 + expansion, 0.001, minf(half_w, half_h) - 0.001)
	var corner_points := [
		Vector2(half_w, half_h), Vector2(-half_w, half_h),
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h)
	]
	var points := PackedVector2Array()
	const CASE_CORNER_SEGMENTS := 48
	for corner in range(4):
		var corner_point: Vector2 = corner_points[corner]
		var should_round := (corner_mask & (1 << corner)) != 0 and radius > 0.0001
		if not should_round:
			points.append(corner_point)
			continue
		var centre := Vector2(
			signf(corner_point.x) * (half_w - radius),
			signf(corner_point.y) * (half_h - radius)
		)
		var start_angle := float(corner) * PI * 0.5
		for step in range(CASE_CORNER_SEGMENTS + 1):
			var angle := start_angle + float(step) / float(CASE_CORNER_SEGMENTS) * PI * 0.5
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _add_phone_case_back_plate(combiner: CSGCombiner3D, size: Vector2, centre: Vector2, depth: float, wall: float, corner_mask: int) -> void:
	# Build the rear skin as an explicit union, not as a fragile remnant of
	# the shell-hollowing boolean.
	var back_plate := CSGPolygon3D.new()
	back_plate.name = "ProtectiveBackPlate"
	back_plate.operation = CSGShape3D.OPERATION_UNION
	back_plate.polygon = _case_outline_for_size(size, wall, corner_mask)
	back_plate.depth = wall
	back_plate.position = Vector3(centre.x, centre.y, -depth * 0.5)
	back_plate.material = _create_phone_case_material()
	back_plate.smooth_faces = true
	combiner.add_child(back_plate)


func _add_foldable_case_segment(parent: Node3D, segment_size: Vector2, centre: Vector2, depth: float, wall: float, segment_name: String, include_port: bool, corner_mask: int) -> void:
	var combiner := CSGCombiner3D.new()
	combiner.name = segment_name
	combiner.use_collision = false
	parent.add_child(combiner)
	var shell := CSGPolygon3D.new()
	shell.name = "ProtectiveOuterShell"
	shell.polygon = _case_outline_for_size(segment_size, wall, corner_mask)
	# CSGPolygon3D extrudes from its local XY plane toward negative Z.
	# Start at the outside/front lip, then extrude through the phone depth
	# and finish at the rear outside face. This wraps the actual chassis.
	shell.depth = depth + wall * 2.0
	shell.position = Vector3(centre.x, centre.y, depth * 0.5 + wall)
	shell.material = _create_phone_case_material()
	shell.smooth_faces = true
	combiner.add_child(shell)
	if segment_name == "PhoneCaseFixedHalf":
		phone_case_shell = shell

	var cavity := CSGPolygon3D.new()
	cavity.name = "DeviceClearanceCavity"
	# Match the actual phone leaf dimensions, then add 4 mm clearance on
	# every side. The previous -0.008 size adjustment cancelled the outline
	# expansion entirely, leaving the cavity no wider than the handset and
	# causing the case lip to intersect/mis-seat around the device.
	cavity.polygon = _case_outline_for_size(segment_size, 0.003, corner_mask)
	# Hollow the side shell fully through its rear, then union a separate
	# backing plate. This guarantees a real back skin instead of relying on
	# the remaining sliver from a deep CSG subtraction.
	cavity.depth = depth + wall * 2.0 + 0.080
	cavity.position = Vector3(centre.x, centre.y, depth * 0.5 + wall + 0.040)
	_case_subtract(combiner, cavity)
	_add_phone_case_back_plate(combiner, segment_size, centre, depth, wall, corner_mask)

	# Fold and Flip cover displays live on the outside/back face. Leave a
	# precision window in the matching case half so the case never covers
	# the actual outer glass, bezel or selected front-camera assembly.
	var has_outer_display := (
		(selected_phone_type == "Fold" and segment_name == "PhoneCaseFixedHalf")
		or (selected_phone_type == "Flip" and segment_name == "PhoneCaseMovingHalfShell")
	)
	if screen_enabled and has_outer_display:
		var outer_panel_width: float
		var outer_panel_height: float
		if selected_phone_type == "Fold":
			outer_panel_width = (_active_phone_size().x - 0.014) * 0.5 - 0.12
			outer_panel_height = _active_phone_size().y - 0.20
		else:
			outer_panel_width = _active_phone_size().x - 0.18
			outer_panel_height = (_active_phone_size().y - 0.014) * 0.5 - 0.12
		var outer_window := CSGPolygon3D.new()
		outer_window.name = "OuterDisplayClearanceWindow"
		# The window follows the outer bezel footprint plus a small fitting gap.
		outer_window.polygon = _case_outline_for_size(
			Vector2(outer_panel_width + 0.07, outer_panel_height + 0.07),
			0.035,
			_foldable_half_corner_mask(true)
		)
		outer_window.depth = wall + 0.050
		outer_window.position = Vector3(centre.x, centre.y, -depth * 0.5 + 0.025)
		_case_subtract(combiner, outer_window)

	# Rear camera apertures are allocated to the half that actually contains each module.
	for camera_index in range(rear_camera_modules.size()):
		var camera_data: Dictionary = rear_camera_modules[camera_index]
		var camera_position: Vector2 = camera_data["position"]
		if absf(camera_position.x - centre.x) > segment_size.x * 0.5 or absf(camera_position.y - centre.y) > segment_size.y * 0.5:
			continue
		if _rear_hardware_back_design_index(camera_position) >= 0:
			continue
		var camera_cut := CSGPolygon3D.new()
		camera_cut.name = "RearCameraOpening_%02d" % (camera_index + 1)
		camera_cut.polygon = _case_circle_outline(float(camera_data["size"]) * 1.22 + 0.010)
		camera_cut.depth = wall * 3.0 + 0.02
		camera_cut.position = Vector3(camera_position.x, camera_position.y, -depth * 0.5 + wall * 1.5)
		camera_cut.smooth_faces = true
		_case_subtract(combiner, camera_cut)
	for flash_index in range(rear_flash_modules.size()):
		var flash_data: Dictionary = rear_flash_modules[flash_index]
		var flash_position: Vector2 = flash_data["position"]
		if absf(flash_position.x - centre.x) > segment_size.x * 0.5 or absf(flash_position.y - centre.y) > segment_size.y * 0.5:
			continue
		if _rear_hardware_back_design_index(flash_position) >= 0:
			continue
		var flash_cut := CSGPolygon3D.new()
		flash_cut.name = "RearFlashOpening_%02d" % (flash_index + 1)
		flash_cut.polygon = _case_circle_outline(float(flash_data["size"]) * 1.22 + 0.010)
		flash_cut.depth = wall * 3.0 + 0.02
		flash_cut.position = Vector3(flash_position.x, flash_position.y, -depth * 0.5 + wall * 1.5)
		flash_cut.smooth_faces = true
		_case_subtract(combiner, flash_cut)

	# Raised back-design panels must pass through the pouch without pressing
	# against the phone's own geometry. Keep each clearance on its actual half.
	var camera_trim_material := _create_case_camera_trim_material()
	for box_index in range(back_design_boxes.size()):
		var box_data: Dictionary = back_design_boxes[box_index]
		var box_position: Vector2 = box_data["position"]
		if absf(box_position.x - centre.x) > segment_size.x * 0.5 or absf(box_position.y - centre.y) > segment_size.y * 0.5:
			continue
		var box_size: Vector2 = box_data["size"]
		var cut_width := box_size.x + 0.045
		var cut_height := box_size.y + 0.045
		var cut_radius := minf(box_size.x, box_size.y) * float(box_data.get("border", 0.0)) + 0.018
		var design_cut := CSGPolygon3D.new()
		design_cut.name = "BackDesignClearance_%02d" % (box_index + 1)
		design_cut.polygon = _case_rounded_cutout(cut_width, cut_height, cut_radius)
		design_cut.depth = wall * 3.0 + 0.02
		design_cut.position = Vector3(box_position.x, box_position.y, -depth * 0.5 + wall * 1.5)
		_case_subtract(combiner, design_cut)
		if _back_design_box_has_rear_hardware(box_index):
			var trim_inner := _case_rounded_cutout(cut_width - 0.002, cut_height - 0.002, maxf(0.002, cut_radius - 0.001))
			var trim_outer := _case_rounded_cutout(cut_width + 0.014, cut_height + 0.014, cut_radius + 0.007)
			var rear_case_surface_z := -depth * 0.5 - wall - 0.001
			_add_phone_case_camera_trim(phone_case_preview, box_position, trim_inner, trim_outer, rear_case_surface_z, "BackDesignCameraGoldTrim_%02d" % (box_index + 1), camera_trim_material)

	if include_port and charge_port_type != "None" and charge_port_opening_points.size() >= 3:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point in charge_port_opening_points:
			low.x = minf(low.x, point.x)
			low.y = minf(low.y, point.y)
			high.x = maxf(high.x, point.x)
			high.y = maxf(high.y, point.y)
		var port_cut := CSGBox3D.new()
		port_cut.name = "ChargingPortOpening"
		port_cut.size = Vector3(high.x - low.x + 0.026, wall * 2.0 + 0.035, high.y - low.y + 0.026)
		port_cut.position = Vector3(centre.x + (low.x + high.x) * 0.5, centre.y - segment_size.y * 0.5, (low.y + high.y) * 0.5)
		_case_subtract(combiner, port_cut)

	# S-Pen access follows the phone's live collision-aware marker position.
	if style_pen_enabled:
		var pen_layout := _get_style_pen_marker_layout()
		if bool(pen_layout["valid"]):
			var pen_position: Vector2 = pen_layout["position"]
			if absf(pen_position.x - centre.x) <= segment_size.x * 0.5 and absf(pen_position.y - centre.y) <= segment_size.y * 0.5:
				var pen_cut := CSGCylinder3D.new()
				pen_cut.name = "StylePenSlotOpening"
				pen_cut.radius = 0.029
				pen_cut.height = wall * 2.0 + 0.045
				pen_cut.sides = 40
				pen_cut.position = Vector3(pen_position.x, centre.y - segment_size.y * 0.5, 0.0)
				_case_subtract(combiner, pen_cut)

	var key_length := 0.30 * side_button_length_scale * 0.46
	if power_button_enabled:
		_case_side_opening(combiner, 1.0, power_button_y, key_length + 0.06, depth, wall, "PowerButtonOpening")
	if volume_button_enabled:
		var volume_key_length := key_length * 0.46
		_case_side_opening(combiner, -1.0, volume_button_y + volume_key_length * 0.52 + 0.018, volume_key_length, depth, wall, "VolumeUpOpening")
		_case_side_opening(combiner, -1.0, volume_button_y - volume_key_length * 0.52 - 0.018, volume_key_length, depth, wall, "VolumeDownOpening")
	if camera_side_button_enabled:
		_case_side_opening(combiner, 1.0, camera_side_button_y, 0.25, depth, wall, "CameraSideButtonOpening")
	if sound_button_enabled:
		var case_phone_depth := _phone_depth_for_thickness_level()
		var case_key_radius := clampf(case_phone_depth * 0.27, 0.018, 0.036) * 0.78
		var sound_key_width := maxf(case_key_radius * 1.35, 0.024)
		var sound_key_length := maxf(0.0, (0.105 + sound_key_width) / 1.2 - sound_key_width)
		var sound_key_total_height := maxf(sound_key_length + sound_key_width, sound_key_width * 2.0)
		_case_side_opening(combiner, -1.0, volume_button_y + key_length + 0.15, sound_key_total_height + 0.012, depth, wall, "SoundButtonOpening")
	if sim_tray_enabled:
		_case_side_opening(combiner, -1.0, sim_tray_y, 0.25, depth, wall, "SIMTrayOpening")

	if speaker_count > 0 and (selected_phone_type == "Fold" or include_port):
		var left_count := int(ceil(float(speaker_count) * 0.5))
		var right_count := speaker_count - left_count
		var speaker_xs: Array[float] = []
		for index in range(left_count):
			speaker_xs.append(-(0.115 + 0.035 + float(left_count - 1 - index) * 0.045))
		for index in range(right_count):
			speaker_xs.append(0.115 + 0.035 + float(index) * 0.045)
		for index in range(speaker_xs.size()):
			var speaker_x := speaker_xs[index]
			if absf(speaker_x - centre.x) > segment_size.x * 0.5:
				continue
			var speaker_cut := CSGCylinder3D.new()
			speaker_cut.name = "SpeakerOpening_%02d" % (index + 1)
			speaker_cut.radius = 0.016
			speaker_cut.height = 0.16
			speaker_cut.sides = 32
			speaker_cut.position = Vector3(speaker_x, centre.y - segment_size.y * 0.5, 0.0)
			_case_subtract(combiner, speaker_cut)

	# A pop-up camera gets an edge slot only on the leaf that contains the top edge.
	if front_camera_enabled and front_camera_style == "Pop-Up Camera":
		var popup_y := _active_phone_size().y * 0.5 + 0.045
		if absf(centre.x) <= segment_size.x * 0.5 and absf(popup_y - centre.y) <= segment_size.y * 0.5 + 0.08:
			var popup_cut := CSGBox3D.new()
			popup_cut.name = "PopUpCameraOpening"
			popup_cut.size = Vector3(0.22, 0.16, depth + wall * 2.0 + 0.08)
			popup_cut.position = Vector3(0.0, popup_y, 0.0)
			_case_subtract(combiner, popup_cut)


func _rebuild_foldable_phone_case_geometry() -> void:
	if not is_instance_valid(phone_case_preview):
		return
	for child in phone_case_preview.get_children():
		child.free()
	phone_case_shell = null
	var depth := _phone_depth_for_thickness_level()
	var wall := clampf(depth * 0.08, 0.008, 0.014)
	var moving_case := Node3D.new()
	moving_case.name = "PhoneCaseMovingHalf"
	phone_case_preview.add_child(moving_case)
	var chassis_layout := _get_foldable_segment_layout()
	var chassis_segment: Vector3 = chassis_layout["segment_size"]
	var fixed_offset: Vector3 = chassis_layout["fixed_offset"]
	var moving_offset: Vector3 = chassis_layout["moving_offset"]
	var segment_size := Vector2(chassis_segment.x, chassis_segment.y)
	var fixed_centre := Vector2(fixed_offset.x, fixed_offset.y)
	var moving_centre := Vector2(moving_offset.x, moving_offset.y)

	_add_foldable_case_segment(
		phone_case_preview, segment_size, fixed_centre, depth, wall,
		"PhoneCaseFixedHalf", true, _foldable_half_corner_mask(false)
	)
	_add_foldable_case_segment(
		moving_case, segment_size, moving_centre, depth, wall,
		"PhoneCaseMovingHalfShell", false, _foldable_half_corner_mask(true)
	)

	var hinge_bridge := MeshInstance3D.new()
	hinge_bridge.name = "FlexibleCaseHingeBridge"
	var bridge_length := (_active_phone_size().y if selected_phone_type == "Fold" else _active_phone_size().x) * 0.90
	hinge_bridge.mesh = _create_rounded_panel_mesh(0.024, bridge_length, 0.005, 0.010)
	if selected_phone_type == "Flip":
		hinge_bridge.rotation.z = PI * 0.5
	var bridge_material := StandardMaterial3D.new()
	bridge_material.albedo_color = phone_case_color.darkened(0.20)
	bridge_material.roughness = 0.78
	bridge_material.metallic = 0.02
	hinge_bridge.material_override = bridge_material
	hinge_bridge.position = Vector3(0.0, 0.0, -depth * 0.5 - wall - 0.0025)
	hinge_bridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	phone_case_preview.add_child(hinge_bridge)
	_apply_phone_fold_angle()
	phone_case_preview.visible = left_tools_page != 1 and phone_case_custom_enabled and phone_case_built and not phone_case_building and not charger_preview_mode


func _rebuild_phone_case_geometry() -> void:
	if not is_instance_valid(phone_case_preview) or not phone_case_custom_enabled:
		return
	if selected_phone_type != "Standard":
		_rebuild_foldable_phone_case_geometry()
		return
	for child in phone_case_preview.get_children():
		child.free()
	phone_case_shell = null
	var depth := _phone_depth_for_thickness_level()
	var wall := clampf(depth*0.08,0.008,0.014)
	var combiner := CSGCombiner3D.new()
	combiner.name = "LiveFittedPhoneCase"
	combiner.use_collision = false
	phone_case_preview.add_child(combiner)

	var shell := CSGPolygon3D.new()
	shell.name = "ProtectiveOuterShell"
	shell.polygon = _case_outline(wall)
	# CSGPolygon3D extrudes toward negative Z from its local XY plane.
	# Begin beyond the phone's screen-side face so the shell surrounds the
	# complete chassis depth instead of sitting behind the handset.
	shell.depth = depth+wall*2.0
	shell.position.z = depth*0.5+wall
	shell.material = _create_phone_case_material()
	shell.smooth_faces = true
	combiner.add_child(shell)
	phone_case_shell = shell

	# Hollow the front and inner volume while retaining the case's rear skin and rim.
	var cavity := CSGPolygon3D.new()
	cavity.name = "DeviceClearanceCavity"
	cavity.polygon = _case_outline(0.003)
	# Hollow the shell fully through its rear, then add a separate backing
	# plate so the case always has a continuous physical back.
	cavity.depth = depth+wall*2.0+0.080
	cavity.position.z = depth*0.5+wall+0.040
	_case_subtract(combiner,cavity)
	var case_back_size := _active_phone_size()
	_add_phone_case_back_plate(
		combiner, Vector2(case_back_size.x, case_back_size.y), Vector2.ZERO,
		depth, wall, 15
	)

	# Flat-back camera and flash units get individual circular apertures.
	# Hardware mounted on a raised Back Design panel is handled by that panel's
	# own rounded opening below, leaving the case filled across the flat back.
	var camera_trim_material := _create_case_camera_trim_material()
	for camera_index in range(rear_camera_modules.size()):
		var camera_module: Dictionary = rear_camera_modules[camera_index]
		var camera_position: Vector2 = camera_module["position"]
		if _rear_hardware_back_design_index(camera_position) < 0:
			_add_phone_case_camera_aperture(combiner, camera_position, float(camera_module["size"]), depth, wall, "RearCameraOpening_%02d" % int(camera_module.get("id", camera_index + 1)), camera_trim_material)
	for flash_index in range(rear_flash_modules.size()):
		var flash_module: Dictionary = rear_flash_modules[flash_index]
		var flash_position: Vector2 = flash_module["position"]
		if _rear_hardware_back_design_index(flash_position) < 0:
			_add_phone_case_camera_aperture(combiner, flash_position, float(flash_module["size"]), depth, wall, "RearFlashOpening_%02d" % int(flash_module.get("id", flash_index + 1)), camera_trim_material)

	# A raised back-design panel keeps its existing shaped opening. Add gold
	# trim only when camera or flash hardware is actually mounted on that panel.
	for i in range(back_design_boxes.size()):
		var item: Dictionary = back_design_boxes[i]
		var size: Vector2 = item["size"]
		var p: Vector2 = item["position"]
		var cut_width := size.x + 0.045
		var cut_height := size.y + 0.045
		var cut_radius := minf(size.x, size.y) * float(item.get("border", 0.0)) + 0.018
		var cut := CSGPolygon3D.new()
		cut.name = "BackDesignClearance_%02d" % (i + 1)
		cut.polygon = _case_rounded_cutout(cut_width, cut_height, cut_radius)
		cut.depth = wall * 3.0 + 0.02
		cut.position = Vector3(p.x, p.y, -depth * 0.5 + wall * 1.5)
		_case_subtract(combiner, cut)
		if _back_design_box_has_rear_hardware(i):
			var trim_inner := _case_rounded_cutout(cut_width - 0.002, cut_height - 0.002, maxf(0.002, cut_radius - 0.001))
			var trim_outer := _case_rounded_cutout(cut_width + 0.014, cut_height + 0.014, cut_radius + 0.007)
			var rear_case_surface_z := -depth * 0.5 - wall - 0.001
			_add_phone_case_camera_trim(phone_case_preview, p, trim_inner, trim_outer, rear_case_surface_z, "BackDesignCameraGoldTrim_%02d" % (i + 1), camera_trim_material)

	# Charging-port aperture follows the active connector profile stored by the phone.
	if charge_port_type!="None" and charge_port_opening_points.size()>=3:
		var low_port := Vector2(INF,INF)
		var high_port := Vector2(-INF,-INF)
		for point in charge_port_opening_points:
			low_port.x = minf(low_port.x,point.x)
			low_port.y = minf(low_port.y,point.y)
			high_port.x = maxf(high_port.x,point.x)
			high_port.y = maxf(high_port.y,point.y)
		var port_cut := CSGBox3D.new()
		port_cut.name = "ChargingPortOpening"
		# Cut through the bottom rim only. The old 0.16 Y span reached too far
		# inward and removed part of the rear skin behind the connector.
		var port_wall_span := wall*2.0+0.035
		port_cut.size = Vector3(high_port.x-low_port.x+0.026,port_wall_span,high_port.y-low_port.y+0.026)
		port_cut.position = Vector3((low_port.x+high_port.x)*0.5,-_active_phone_size().y*0.5,(low_port.y+high_port.y)*0.5)
		_case_subtract(combiner,port_cut)

	# S-Pen access follows the exact same collision-aware position as the
	# handset's black end marker, so the case slot stays aligned as the layout changes.
	if style_pen_enabled:
		var pen_layout := _get_style_pen_marker_layout()
		if bool(pen_layout["valid"]):
			var pen_position: Vector2 = pen_layout["position"]
			var pen_cut := CSGCylinder3D.new()
			pen_cut.name = "StylePenSlotOpening"
			pen_cut.radius = 0.029
			pen_cut.height = wall*2.0+0.045
			pen_cut.sides = 40
			pen_cut.position = Vector3(pen_position.x, -_active_phone_size().y*0.5, 0.0)
			_case_subtract(combiner,pen_cut)

	# Bottom speaker openings are placed from the same formula as the live phone.
	if speaker_count>0:
		var reserved := 0.115
		var margin := 0.035
		var spacing := 0.045
		var left_count := int(ceil(float(speaker_count)*0.5))
		var right_count := speaker_count-left_count
		var xs: Array[float] = []
		for i in range(left_count):
			xs.append(-(reserved+margin+float(left_count-1-i)*spacing))
		for i in range(right_count):
			xs.append(reserved+margin+float(i)*spacing)
		for i in range(xs.size()):
			var speaker_cut := CSGCylinder3D.new()
			speaker_cut.name = "SpeakerOpening_%02d" % (i+1)
			speaker_cut.radius = 0.016
			speaker_cut.height = 0.16
			speaker_cut.sides = 32
			speaker_cut.position = Vector3(xs[i],-_active_phone_size().y*0.5,0.0)
			_case_subtract(combiner,speaker_cut)

	# Side button, SIM tray and optional side controls track their live positions.
	var key_length := 0.30*side_button_length_scale*0.46
	if power_button_enabled:
		_case_side_opening(combiner,1.0,power_button_y,key_length+0.06,depth,wall,"PowerButtonOpening")
	if volume_button_enabled:
		var gap := 0.018
		# Keep the two volume-key apertures separate, with a visible bridge of
		# case material between them so each key has its own defined outline.
		var volume_key_length := key_length*0.46
		_case_side_opening(combiner,-1.0,volume_button_y+volume_key_length*0.52+gap,volume_key_length,depth,wall,"VolumeUpOpening")
		_case_side_opening(combiner,-1.0,volume_button_y-volume_key_length*0.52-gap,volume_key_length,depth,wall,"VolumeDownOpening")
	if camera_side_button_enabled:
		_case_side_opening(combiner,1.0,camera_side_button_y,0.25,depth,wall,"CameraSideButtonOpening")
	if sound_button_enabled:
		# Match the actual smaller sound-action key, not a long generic slot.
		# This leaves a clear case-material border around it above Volume Up.
		var case_phone_depth := _phone_depth_for_thickness_level()
		var case_key_radius := clampf(case_phone_depth*0.27,0.018,0.036)*0.78
		var sound_key_width := maxf(case_key_radius*1.35,0.024)
		var sound_key_length := maxf(0.0,(0.105+sound_key_width)/1.2-sound_key_width)
		var sound_key_total_height := maxf(sound_key_length+sound_key_width,sound_key_width*2.0)
		_case_side_opening(combiner,-1.0,volume_button_y+key_length+0.15,sound_key_total_height+0.012,depth,wall,"SoundButtonOpening")
	if sim_tray_enabled:
		_case_side_opening(combiner,-1.0,sim_tray_y,0.25,depth,wall,"SIMTrayOpening")

	# Pop-up selfie mechanism needs a matching top-edge clearance.
	if front_camera_enabled and front_camera_style=="Pop-Up Camera":
		var popup_cut := CSGBox3D.new()
		popup_cut.name = "PopUpCameraOpening"
		popup_cut.size = Vector3(0.22,0.16,depth+wall*2.0+0.08)
		popup_cut.position = Vector3(0.0,_active_phone_size().y*0.5+0.045,0.0)
		_case_subtract(combiner,popup_cut)
	phone_case_preview.visible = left_tools_page!=1 and phone_case_custom_enabled and phone_case_built and not phone_case_building and not charger_preview_mode


func _queue_phone_case_sync() -> void:
	if not phone_case_custom_enabled or not phone_case_built or phone_case_building or phone_case_sync_queued:
		return
	if not is_instance_valid(phone_case_preview):
		return
	phone_case_sync_queued=true
	call_deferred("_sync_phone_case_geometry")


func _sync_phone_case_geometry() -> void:
	phone_case_sync_queued=false
	if phone_case_custom_enabled and phone_case_built and not phone_case_building:
		_rebuild_phone_case_geometry()


func _update_phone_case_preview_mode() -> void:
	if charger_preview_mode:
		_set_charger_preview_mode(true)
		return
	if is_instance_valid(phone_body):
		phone_body.visible=true
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible=left_tools_page!=1 and phone_case_custom_enabled and phone_case_built and not phone_case_building
	if left_tools_page==2:
		_show_phone_case_controls()
	else:
		preview_mouse_dragging=false


func _show_box_package_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	box_package_color_mode = false
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel = VBoxContainer.new()
	active_feature_panel.name = "BoxPackageControls"
	active_feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_feature_panel.add_theme_constant_override("separation", 7)
	right_tools_content.add_child(active_feature_panel)

	var compact := get_viewport().get_visible_rect().size.x < 900.0
	var heading := _make_label("BOX PACKAGE", 18, Color("#c7eacb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Design the retail box for this phone. Drag the centre preview to inspect the packaging from every angle.", 12, Color("#d5e9f5"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	_add_box_package_toggle(active_feature_panel, "ShowBoxPackage", "SHOW BOX PACKAGE", box_package_enabled, Callable(self, "_on_box_package_enabled_toggled"))
	_add_box_package_toggle(active_feature_panel, "OpenBoxPackage", "OPEN BOX LID", box_package_open, Callable(self, "_on_box_package_open_toggled"))

	var color_button := Button.new()
	color_button.name = "EditBoxPackageColor"
	color_button.text = "CHANGE BOX COLOUR"
	color_button.custom_minimum_size.y = 42 if compact else 46
	color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_button.focus_mode = Control.FOCUS_NONE
	_apply_research_typography(color_button, 13)
	_style_staff_button(color_button, true)
	color_button.pressed.connect(_show_device_color_controls.bind(false, false, false, false, false, false, true))
	active_feature_panel.add_child(color_button)

	var branding_heading := _make_label("COMPANY BRANDING", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(branding_heading)
	_add_box_package_toggle(active_feature_panel, "ShowCompanyLogo", "SHOW COMPANY LOGO", box_package_logo_visible, Callable(self, "_on_box_package_logo_visibility_toggled"))
	_add_box_package_toggle(active_feature_panel, "ShowCompanyName", "SHOW COMPANY NAME", box_package_name_visible, Callable(self, "_on_box_package_name_visibility_toggled"))

	var position_heading := _make_label("BRANDING POSITION", 13, Color("#a9e3ff"))
	active_feature_panel.add_child(position_heading)
	var target_row := HBoxContainer.new()
	target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(target_row)
	for target in ["LOGO", "NAME"]:
		var target_button := Button.new()
		target_button.text = target
		target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_button.custom_minimum_size.y = 40 if compact else 44
		_apply_research_typography(target_button, 12)
		_style_staff_button(target_button, box_package_position_target == target)
		target_button.pressed.connect(_set_box_package_position_target.bind(target))
		target_row.add_child(target_button)
	var position_pad := GridContainer.new()
	position_pad.name = "BoxPackagePositionPad"
	position_pad.columns = 3
	position_pad.add_theme_constant_override("h_separation", 6)
	position_pad.add_theme_constant_override("v_separation", 5)
	position_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(position_pad)
	_add_box_package_position_pad_spacer(position_pad)
	_add_box_package_position_button(position_pad, "↑", Vector2i(0, 1), compact)
	_add_box_package_position_pad_spacer(position_pad)
	_add_box_package_position_button(position_pad, "←", Vector2i(-1, 0), compact)
	var position_center := Button.new()
	position_center.text = "RESET"
	position_center.custom_minimum_size = Vector2(54, 42)
	_apply_research_typography(position_center, 10)
	_style_staff_button(position_center, true)
	position_center.pressed.connect(_reset_box_package_position)
	position_pad.add_child(position_center)
	_add_box_package_position_button(position_pad, "→", Vector2i(1, 0), compact)
	_add_box_package_position_pad_spacer(position_pad)
	_add_box_package_position_button(position_pad, "↓", Vector2i(0, -1), compact)
	_add_box_package_position_pad_spacer(position_pad)
	var step_row := HBoxContainer.new()
	step_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_row.add_theme_constant_override("separation", 6)
	active_feature_panel.add_child(step_row)
	var step_label := _make_label("MOVEMENT", 10, Color("#d7eaf5"))
	step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step_row.add_child(step_label)
	for step in [0.03, 0.08, 0.16]:
		var step_button := Button.new()
		step_button.text = "SMALL" if is_equal_approx(step, 0.03) else ("MED" if is_equal_approx(step, 0.08) else "LARGE")
		step_button.custom_minimum_size = Vector2(54, 36)
		_apply_research_typography(step_button, 10)
		_style_staff_button(step_button, is_equal_approx(box_package_position_step, step))
		step_button.pressed.connect(_set_box_package_position_step.bind(step))
		step_row.add_child(step_button)


func _add_box_package_toggle(parent: Control, control_name: String, caption: String, enabled: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = control_name + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := _make_label(caption, 12, Color("#e6f5ff"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var toggle := TextureButton.new()
	toggle.name = control_name
	toggle.custom_minimum_size = Vector2(38, 38)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal = _make_side_button_checkbox_icon(false)
	toggle.texture_hover = _make_side_button_checkbox_icon(false)
	toggle.texture_pressed = _make_side_button_checkbox_icon(true)
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(callback)
	row.add_child(toggle)


func _add_box_package_position_pad_spacer(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 40)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _add_box_package_position_button(parent: GridContainer, caption: String, direction: Vector2i, compact: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(48, 40) if compact else Vector2(54, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_research_typography(button, 20)
	_style_staff_button(button, true)
	button.pressed.connect(_move_box_package_branding.bind(direction))
	parent.add_child(button)


func _set_box_package_position_target(target: String) -> void:
	box_package_position_target = target
	_show_box_package_controls()


func _set_box_package_position_step(step: float) -> void:
	box_package_position_step = step
	_show_box_package_controls()


func _move_box_package_branding(direction: Vector2i) -> void:
	var offset := Vector2(direction) * box_package_position_step
	if box_package_position_target == "LOGO":
		box_package_logo_position.x = clampf(box_package_logo_position.x + offset.x, -0.55, 0.55)
		box_package_logo_position.y = clampf(box_package_logo_position.y + offset.y, -1.20, 1.20)
	else:
		box_package_name_position.x = clampf(box_package_name_position.x + offset.x, -0.55, 0.55)
		box_package_name_position.y = clampf(box_package_name_position.y + offset.y, -1.20, 1.20)
	_refresh_box_package_branding()


func _reset_box_package_position() -> void:
	if box_package_position_target == "LOGO":
		box_package_logo_position = Vector2(0.0, 0.66)
	else:
		box_package_name_position = Vector2(0.0, -0.62)
	_refresh_box_package_branding()


func _on_box_package_enabled_toggled(enabled: bool) -> void:
	box_package_enabled = enabled
	if is_instance_valid(box_package_preview):
		box_package_preview.visible = box_package_preview_mode and box_package_enabled
	if is_instance_valid(phone_body):
		phone_body.visible = not box_package_preview_mode or not box_package_enabled
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible = not box_package_preview_mode and phone_case_custom_enabled and phone_case_built and not phone_case_building and left_tools_page != 1


func _on_box_package_open_toggled(enabled: bool) -> void:
	box_package_open = enabled
	_refresh_box_package_lid_transform()


func _on_box_package_logo_visibility_toggled(enabled: bool) -> void:
	box_package_logo_visible = enabled
	_refresh_box_package_branding()


func _on_box_package_name_visibility_toggled(enabled: bool) -> void:
	box_package_name_visible = enabled
	_refresh_box_package_branding()


func _set_box_package_preview_mode(enabled: bool) -> void:
	var entering := enabled and not box_package_preview_mode
	box_package_preview_mode = enabled
	if entering and is_instance_valid(box_package_preview):
		box_package_preview.rotation_degrees = Vector3(-7.0, -16.0, 0.0)
	if is_instance_valid(phone_body):
		phone_body.visible = not enabled or not box_package_enabled
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible = not enabled and phone_case_custom_enabled and phone_case_built and not phone_case_building and left_tools_page != 1
	if is_instance_valid(charger_preview):
		charger_preview.visible = false
	if is_instance_valid(smartwatch_preview):
		smartwatch_preview.visible = false
	if is_instance_valid(power_bank_preview):
		power_bank_preview.visible = false
	if is_instance_valid(wireless_earbuds_preview):
		wireless_earbuds_preview.visible = false
	wireless_earbuds_preview_mode = false
	smartwatch_preview_mode = false
	power_bank_preview_mode = false
	charger_preview_mode = false
	if is_instance_valid(box_package_preview):
		box_package_preview.visible = enabled and box_package_enabled
	if is_instance_valid(preview_camera):
		preview_camera.position = Vector3(0.0, 0.0, 5.55 if enabled else 5.2)
		preview_camera.fov = 38.0
		preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _make_box_package_material(color: Color, roughness: float = 0.82) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.metallic_specular = 0.0
	return material


func _add_box_package_part(parent: Node3D, node_name: String, dimensions: Vector3, part_position: Vector3, color: Color, roughness: float = 0.82) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = part_position
	part.material_override = _make_box_package_material(color, roughness)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)
	return part


func _rebuild_box_package_preview() -> void:
	if not is_instance_valid(box_package_preview):
		return
	for child in box_package_preview.get_children():
		child.free()

	# A real two-piece rigid phone carton: the base tray has a bottom and four
	# upright walls. The lid is a separate shallow cap with its own four skirts.
	# The cap lifts away as one piece, exposing the open tray instead of a solid block.
	var half_width := 0.91
	var half_height := 1.66
	var wall := 0.075
	var base_z := -0.23
	_add_box_package_part(box_package_preview, "TrayBottom", Vector3(1.78, 3.22, wall), Vector3(0.0, 0.0, base_z), box_package_color.darkened(0.16))
	_add_box_package_part(box_package_preview, "TrayLeftWall", Vector3(wall, 3.20, 0.43), Vector3(-half_width + wall * 0.5, 0.0, base_z + 0.22), box_package_color.darkened(0.10))
	_add_box_package_part(box_package_preview, "TrayRightWall", Vector3(wall, 3.20, 0.43), Vector3(half_width - wall * 0.5, 0.0, base_z + 0.22), box_package_color.darkened(0.10))
	_add_box_package_part(box_package_preview, "TrayTopWall", Vector3(1.78, wall, 0.43), Vector3(0.0, half_height - wall * 0.5, base_z + 0.22), box_package_color.darkened(0.10))
	_add_box_package_part(box_package_preview, "TrayBottomWall", Vector3(1.78, wall, 0.43), Vector3(0.0, -half_height + wall * 0.5, base_z + 0.22), box_package_color.darkened(0.10))
	# A fitted inner board and dark phone-shaped recess make the open carton read as retail packaging.
	_add_box_package_part(box_package_preview, "InnerCardboardInsert", Vector3(1.62, 3.02, 0.045), Vector3(0.0, 0.0, 0.015), box_package_color.lightened(0.06))
	_add_box_package_part(box_package_preview, "PhoneRecess", Vector3(1.38, 2.78, 0.025), Vector3(0.0, 0.0, 0.052), Color("#26313b"), 0.94)

	box_package_lid = Node3D.new()
	box_package_lid.name = "RemovableBoxLid"
	box_package_preview.add_child(box_package_lid)
	_add_box_package_part(box_package_lid, "LidTopPanel", Vector3(1.86, 3.36, wall), Vector3(0.0, 0.0, 0.245), box_package_color)
	_add_box_package_part(box_package_lid, "LidLeftSkirt", Vector3(wall, 3.36, 0.30), Vector3(-0.93 + wall * 0.5, 0.0, 0.075), box_package_color.darkened(0.07))
	_add_box_package_part(box_package_lid, "LidRightSkirt", Vector3(wall, 3.36, 0.30), Vector3(0.93 - wall * 0.5, 0.0, 0.075), box_package_color.darkened(0.07))
	_add_box_package_part(box_package_lid, "LidTopSkirt", Vector3(1.86, wall, 0.30), Vector3(0.0, 1.68 - wall * 0.5, 0.075), box_package_color.darkened(0.07))
	_add_box_package_part(box_package_lid, "LidBottomSkirt", Vector3(1.86, wall, 0.30), Vector3(0.0, -1.68 + wall * 0.5, 0.075), box_package_color.darkened(0.07))

	box_package_logo_sprite = Sprite3D.new()
	box_package_logo_sprite.name = "CompanyLogoPrint"
	box_package_logo_sprite.pixel_size = 0.003
	box_package_logo_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box_package_lid.add_child(box_package_logo_sprite)

	box_package_name_label = Label3D.new()
	box_package_name_label.name = "CompanyNamePrint"
	box_package_name_label.font = load("res://assets/fonts/STIXTwoText[wght].ttf") as Font
	box_package_name_label.font_size = 46
	box_package_name_label.pixel_size = 0.00135
	box_package_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_package_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box_package_name_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box_package_lid.add_child(box_package_name_label)

	_refresh_box_package_material()
	_refresh_box_package_branding()
	_refresh_box_package_lid_transform()
	box_package_preview.visible = box_package_preview_mode and box_package_enabled


func _refresh_box_package_material() -> void:
	if not is_instance_valid(box_package_preview):
		return
	for part in _collect_box_package_meshes(box_package_preview):
		var shade := box_package_color
		if part.name.contains("Wall") or part.name.contains("Skirt"):
			shade = box_package_color.darkened(0.09)
		elif part.name == "TrayBottom":
			shade = box_package_color.darkened(0.15)
		part.material_override = _make_box_package_material(shade)
	_refresh_box_package_branding()


func _collect_box_package_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			found.append(child as MeshInstance3D)
		elif child is Node:
			found.append_array(_collect_box_package_meshes(child))
	return found


func _refresh_box_package_lid_transform() -> void:
	if not is_instance_valid(box_package_lid):
		return
	box_package_lid.position = Vector3(0.0, 2.10 if box_package_open else 0.0, 0.10 if box_package_open else 0.0)
	box_package_lid.rotation_degrees = Vector3(-8.0 if box_package_open else 0.0, 0.0, 0.0)


func _refresh_box_package_branding() -> void:
	if not is_instance_valid(box_package_preview):
		return
	var ink_color := Color("#202a34") if box_package_color.get_luminance() > 0.52 else Color("#f4f7fa")
	var logo_atlas := load("res://assets/company_logos.svg") as Texture2D
	if is_instance_valid(box_package_logo_sprite):
		if is_instance_valid(logo_atlas):
			var logo_texture := AtlasTexture.new()
			logo_texture.atlas = logo_atlas
			var logo_index := clampi(box_company_logo_id, 1, 50) - 1
			logo_texture.region = Rect2(Vector2(float(logo_index % 10) * 100.0, floorf(float(logo_index) / 10.0) * 100.0), Vector2(100.0, 100.0))
			box_package_logo_sprite.texture = logo_texture
		box_package_logo_sprite.modulate = ink_color
		box_package_logo_sprite.position = Vector3(box_package_logo_position.x, box_package_logo_position.y, 0.292)
		box_package_logo_sprite.visible = box_package_logo_visible
	if is_instance_valid(box_package_name_label):
		box_package_name_label.text = box_company_name.to_upper()
		box_package_name_label.font_size = 46 if box_company_name.length() <= 14 else (38 if box_company_name.length() <= 22 else 30)
		box_package_name_label.modulate = ink_color
		box_package_name_label.position = Vector3(box_package_name_position.x, box_package_name_position.y, 0.292)
		box_package_name_label.visible = box_package_name_visible


func _show_phone_case_controls() -> void:
	if not is_instance_valid(right_tools_content):
		return
	phone_case_color_mode=false
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel=VBoxContainer.new()
	active_feature_panel.name="PhoneCaseControls"
	active_feature_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation",10)
	right_tools_content.add_child(active_feature_panel)

	var heading := _make_label("PHONE CASE",18,Color("#c7eacb"))
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	active_feature_panel.add_child(heading)
	var description := _make_label("Build a protective shell fitted to this phone's current geometry and hardware.",13,Color("#d5e9f5"))
	description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(description)

	var row := HBoxContainer.new()
	row.name="EnableCustomCaseRow"
	row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	active_feature_panel.add_child(row)
	var label := _make_label("ENABLE CUSTOM CASE",14,Color("#e6f5ff"))
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var toggle := TextureButton.new()
	toggle.name="EnableCustomPhoneCaseCheckbox"
	toggle.custom_minimum_size=Vector2(40,40)
	toggle.ignore_texture_size=true
	toggle.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle.texture_normal=_make_side_button_checkbox_icon(false)
	toggle.texture_hover=_make_side_button_checkbox_icon(false)
	toggle.texture_pressed=_make_side_button_checkbox_icon(true)
	toggle.toggle_mode=true
	toggle.button_pressed=phone_case_custom_enabled
	toggle.focus_mode=Control.FOCUS_NONE
	toggle.mouse_filter=Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(_on_phone_case_custom_toggled)
	row.add_child(toggle)

	if phone_case_building:
		var panel := PanelContainer.new()
		panel.name="PhoneCaseBuildLoading"
		var style := StyleBoxFlat.new()
		style.bg_color=Color("#0c2a16")
		style.border_color=Color("#2d7540")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left=12
		style.content_margin_right=12
		style.content_margin_top=12
		style.content_margin_bottom=12
		panel.add_theme_stylebox_override("panel",style)
		active_feature_panel.add_child(panel)
		var loading:=VBoxContainer.new()
		loading.add_theme_constant_override("separation",9)
		panel.add_child(loading)
		var text_label:=_make_label("Building case",16,Color("#eaf8ff"))
		text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		loading.add_child(text_label)
		var shimmer:=ColorRect.new()
		shimmer.name="CaseBuildShimmer"
		shimmer.custom_minimum_size=Vector2(0,12)
		shimmer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var shader:=Shader.new()
		shader.code="""
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.10,0.30,0.44,1.0);
uniform vec4 shine_color : source_color = vec4(0.48,0.82,1.0,1.0);
void fragment(){
	float sweep=fract(UV.x*1.25-TIME*0.72);
	float shine=smoothstep(0.02,0.18,sweep)*(1.0-smoothstep(0.22,0.42,sweep));
	COLOR=mix(base_color,shine_color,shine*0.9);
}
"""
		var shimmer_material:=ShaderMaterial.new()
		shimmer_material.shader=shader
		shimmer.material=shimmer_material
		loading.add_child(shimmer)
		var building_note:=_make_label("Matching the cameras, speaker openings, port and buttons…",11,Color("#a9d9ad"))
		building_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		building_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		loading.add_child(building_note)
	elif phone_case_custom_enabled and phone_case_built:
		var case_ready_label:=_make_label("CUSTOM CASE FITTED TO CURRENT DEVICE",12,Color("#8bd696"))
		case_ready_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		active_feature_panel.add_child(case_ready_label)
		var color_button:=Button.new()
		color_button.name="EditPhoneCaseColor"
		color_button.text="CHANGE CASE COLOR"
		color_button.custom_minimum_size.y=44
		color_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		color_button.focus_mode=Control.FOCUS_NONE
		_apply_research_typography(color_button,13)
		_style_staff_button(color_button,true)
		color_button.pressed.connect(_show_device_color_controls.bind(false,true))
		active_feature_panel.add_child(color_button)

		var design_button:=Button.new()
		design_button.name="EditPhoneCaseDesign"
		design_button.text="CHANGE CASE DESIGN"
		design_button.custom_minimum_size.y=44
		design_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		design_button.focus_mode=Control.FOCUS_NONE
		_apply_research_typography(design_button,13)
		_style_staff_button(design_button,false)
		design_button.pressed.connect(_show_phone_case_design_controls)
		active_feature_panel.add_child(design_button)
	else:
		var disabled_note:=_make_label("Enable the custom case to generate the fitted 3D shell.",12,Color("#a9c9dc"))
		disabled_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		disabled_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		active_feature_panel.add_child(disabled_note)


func _show_phone_case_design_controls() -> void:
	if not is_instance_valid(right_tools_content) or not phone_case_custom_enabled or not phone_case_built:
		return
	phone_case_color_mode=false
	for child in right_tools_content.get_children():
		child.queue_free()
	active_feature_panel=VBoxContainer.new()
	active_feature_panel.name="PhoneCaseDesignControls"
	active_feature_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	active_feature_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	active_feature_panel.add_theme_constant_override("separation",9)
	right_tools_content.add_child(active_feature_panel)

	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",7)
	active_feature_panel.add_child(header)
	var back_button:=Button.new()
	back_button.name="BackToPhoneCaseControls"
	back_button.text="‹"
	back_button.custom_minimum_size=Vector2(36,36)
	back_button.focus_mode=Control.FOCUS_NONE
	_apply_research_typography(back_button,24)
	_style_staff_button(back_button,false)
	back_button.pressed.connect(_show_phone_case_controls)
	header.add_child(back_button)
	var title:=_make_label("CASE BACK DESIGN",16,Color("#c7eacb"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var note:=_make_label("Choose a finish for the pouch back. Your selected color and gradient stay unchanged.",12,Color("#b9d8e9"))
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	active_feature_panel.add_child(note)

	for index in range(PHONE_CASE_DESIGN_NAMES.size()):
		var option:=Button.new()
		option.name="PhoneCaseDesignOption_%02d" % index
		option.text=PHONE_CASE_DESIGN_NAMES[index].to_upper() + ("   ✓ ACTIVE" if index==phone_case_design_style else "")
		option.custom_minimum_size=Vector2(0,48)
		option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		option.focus_mode=Control.FOCUS_NONE
		_apply_research_typography(option,13)
		_style_staff_button(option,index==phone_case_design_style)
		option.pressed.connect(_on_phone_case_design_selected.bind(index))
		active_feature_panel.add_child(option)


func _on_phone_case_design_selected(index: int) -> void:
	phone_case_design_style=clampi(index,0,PHONE_CASE_DESIGN_NAMES.size()-1)
	_refresh_phone_case_material()
	_show_phone_case_design_controls()


func _on_phone_case_custom_toggled(enabled: bool) -> void:
	phone_case_custom_enabled=enabled
	phone_case_build_token+=1
	phone_case_sync_queued=false
	if enabled:
		phone_case_building=true
		phone_case_built=false
		if is_instance_valid(phone_case_preview):
			phone_case_preview.visible=false
		_show_phone_case_controls()
		var token:=phone_case_build_token
		get_tree().create_timer(1.15).timeout.connect(_complete_phone_case_build.bind(token))
	else:
		phone_case_building=false
		phone_case_built=false
		if is_instance_valid(phone_case_preview):
			for child in phone_case_preview.get_children():
				child.free()
			phone_case_preview.visible=false
		phone_case_shell=null
		_show_phone_case_controls()


func _complete_phone_case_build(token: int) -> void:
	if token!=phone_case_build_token or not phone_case_custom_enabled:
		return
	phone_case_building=false
	_rebuild_phone_case_geometry()
	phone_case_built=true
	if is_instance_valid(phone_case_preview):
		phone_case_preview.visible=left_tools_page!=1 and not charger_preview_mode
	_show_phone_case_controls()


func _make_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	_apply_research_typography(label, font_size + 2)
	label.add_theme_color_override("font_color", color)
	return label


func _input(event: InputEvent) -> void:
	if research_mode or left_tools_page == 1 or not is_instance_valid(preview_container) or not preview_container.is_visible_in_tree():
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
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and preview_rect.has_point(touch.position):
			preview_touch_points[touch.index] = touch.position
			if preview_touch_points.size() >= 2 and selected_phone_type != "Standard" and not box_package_preview_mode:
				_begin_fold_pinch()
		else:
			preview_touch_points.erase(touch.index)
			if preview_touch_points.size() < 2:
				fold_pinch_active = false
	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		if preview_touch_points.has(screen_drag.index):
			preview_touch_points[screen_drag.index] = screen_drag.position
		if preview_touch_points.size() >= 2 and selected_phone_type != "Standard" and not box_package_preview_mode:
			if not fold_pinch_active:
				_begin_fold_pinch()
			_update_fold_pinch()
		elif preview_rect.has_point(screen_drag.position):
			_rotate_phone_from_drag(screen_drag.relative)
	elif event is InputEventMagnifyGesture and selected_phone_type != "Standard" and not box_package_preview_mode and preview_rect.has_point(event.position):
		fold_target_angle_degrees = clampf(fold_target_angle_degrees - (event.factor - 1.0) * 105.0, 0.0, MAX_FOLD_ANGLE_DEGREES)


func _begin_fold_pinch() -> void:
	var touch_ids := preview_touch_points.keys()
	if touch_ids.size() < 2:
		return
	var first: Vector2 = preview_touch_points[touch_ids[0]]
	var second: Vector2 = preview_touch_points[touch_ids[1]]
	fold_pinch_start_distance = first.distance_to(second)
	fold_target_angle_degrees = fold_angle_degrees
	fold_pinch_start_angle = fold_angle_degrees
	fold_pinch_active = true


func _update_fold_pinch() -> void:
	if not fold_pinch_active:
		return
	var touch_ids := preview_touch_points.keys()
	if touch_ids.size() < 2:
		fold_pinch_active = false
		return
	var first: Vector2 = preview_touch_points[touch_ids[0]]
	var second: Vector2 = preview_touch_points[touch_ids[1]]
	_set_fold_angle_from_pinch(first.distance_to(second))


func _rotate_phone_from_drag(delta: Vector2) -> void:
	# Each accessory owns an independent preview pivot.
	var rotation_target: Node3D = box_package_preview if box_package_preview_mode else (wireless_earbuds_preview if wireless_earbuds_preview_mode else (power_bank_preview if power_bank_preview_mode else (smartwatch_preview if smartwatch_preview_mode else (charger_preview if charger_preview_mode else phone_body))))
	if not is_instance_valid(rotation_target):
		return
	# Lock each movement to one of four directions: left/right OR up/down.
	# Horizontal drag turns around Y; vertical drag tilts around X.
	if absf(delta.x) >= absf(delta.y):
		rotation_target.rotation.y += delta.x * DRAG_SENSITIVITY
	else:
		rotation_target.rotation.x += delta.y * DRAG_SENSITIVITY
	# PhoneCasePreview inherits PhoneBody rotation as a child; no second rotation is needed.


func _rotate_axis(axis: Vector3, direction: float) -> void:
	var rotation_target: Node3D = box_package_preview if box_package_preview_mode else phone_body
	if not is_instance_valid(rotation_target):
		return
	if axis == Vector3.RIGHT:
		rotation_target.rotation.x += ROTATION_STEP * direction
	elif axis == Vector3.UP:
		rotation_target.rotation.y += ROTATION_STEP * direction
	# PhoneCasePreview inherits PhoneBody rotation as a child; no second rotation is needed.


func _rotate_axis_fine(axis: Vector3, direction: float) -> void:
	var rotation_target: Node3D = box_package_preview if box_package_preview_mode else phone_body
	if not is_instance_valid(rotation_target):
		return
	var fine_step := deg_to_rad(5.0)
	if axis == Vector3.RIGHT:
		rotation_target.rotation.x += fine_step * direction
	elif axis == Vector3.UP:
		rotation_target.rotation.y += fine_step * direction
	# PhoneCasePreview inherits PhoneBody rotation as a child; no second rotation is needed.


func _reset_phone_rotation() -> void:
	if is_instance_valid(phone_body):
		phone_body.rotation = Vector3.ZERO
	if is_instance_valid(phone_case_preview):
		phone_case_preview.rotation = Vector3.ZERO
	if is_instance_valid(box_package_preview):
		box_package_preview.rotation = Vector3.ZERO


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
