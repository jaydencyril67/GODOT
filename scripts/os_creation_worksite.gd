extends Node3D

const OSPhoneModelScript = preload("res://scripts/os_worksite_phone_model.gd")
const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")
const HomeScreenDesignerScript = preload("res://scripts/home_screen_designer.gd")
const StatusBarAssetLibrary = preload("res://scripts/status_bar_asset_library.gd")

signal back_requested
signal setup_progress(message: String, progress: float)
signal setup_completed
signal setup_failed(message: String)

const STEP_NAMES := [
	"OS SETUP",
	"LOCKSCREEN CLOCK",
	"LOCK-SCREEN",
	"APP ICONS",
	"WIDGETS",
	"WALLPAPERS",
	"STATUS BAR",
	"QUICK SETTINGS",
	"NOTIFICATIONS",
	"NAVIGATION",
	"RECENT APPS"
]

const STEP_ASSET_PATHS := {
	3: "res://assets/app_icons",
	4: "res://assets/system-ui/Widgets",
	5: "res://assets/wallpapers",
	6: "res://assets/system-ui/android-systemui/Status-Bar",
	7: "res://assets/system-ui/Quick-Settings",
	8: "res://assets/system-ui/Notifications",
	9: "res://assets/system-ui/android-systemui/Navigation",
	10: "res://assets/system-ui/Recent-Apps"
}

const BACKGROUND := Color("#292B2D")
const PANEL := Color("#202325")
const ACCENT := Color("#C58A3A")
const TEXT := Color("#EEE9DF")
const MUTED := Color("#A6A096")

class BootOrderDragHandle extends Control:
	signal reorder_requested(source_index: int, target_index: int)
	var item_index := -1

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := PanelContainer.new()
		preview.custom_minimum_size = Vector2(190, 42)
		var preview_label := Label.new()
		preview_label.text = "MOVING BOOT ITEM"
		preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview.add_child(preview_label)
		set_drag_preview(preview)
		return {"source_index": item_index}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("source_index") and int(data["source_index"]) != item_index

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if _can_drop_data(_at_position, data):
			reorder_requested.emit(int(data["source_index"]), item_index)


var boot_display_order: Array[String] = ["logo", "phone_name", "phone_model"]
var current_step := 0
var root_control: Control
var worksite_body: HBoxContainer
var preview_region: Control
var controls_scroll: ScrollContainer
var controls_stack: VBoxContainer
var heading_label: Label
var clock_enabled_toggle: Button
var clock_type_row: HBoxContainer
var clock_type_value_label: Label
var clock_type_decrease_button: Button
var clock_type_increase_button: Button
var clock_style_row: HBoxContainer
var clock_style_value_label: Label
var clock_style_decrease_button: Button
var clock_style_increase_button: Button
var clock_position_flex_button: Button
var clock_position_fixed_button: Button
var clock_position_description: Label
var progress_label: Label
var progress_bar: ProgressBar
var content_column: VBoxContainer
var _step_content_host: VBoxContainer
var _step_content_panels: Dictionary = {}
var _step_content_panels_built := false
var selection_status_label: Label
var phone_frame: SubViewportContainer
var phone_screen_interface_viewport: SubViewport
var phone_screen: ColorRect
var power_button: Button
var previous_button: Button
var next_button: Button
var boot_logo_toggle: Button
var boot_phone_name_toggle: Button
var boot_phone_model_toggle: Button
var show_company_logo_on_boot := true
var show_phone_name_on_boot := true
var show_phone_model_on_boot := true
var selected_asset_path := ""
var screen_powered := false
var company_logo_preview: TextureRect
var company_logo_texture: Texture2D
var phone_name_label: Label
var phone_model_label: Label
var lock_screen_designer: Control
var home_screen_designer: Control
var _home_screen_unlocked := false
var selected_status_bar_style_id := "one_ui_balanced"
var boot_sequence_complete := false
var boot_sequence_id := 0
var _phone_pointer_active := false
var _phone_pointer_start := Vector2.ZERO
var _phone_pointer_pin_mode := false
var _phone_pointer_home_mode := false
var _phone_pointer_clock_mode := false
var setup_complete := false
var preparing_for_first_load := false
var phone_model: Node3D
var phone_screen_texture: Texture2D
var _asset_file_cache: Dictionary = {}

func set_preparing_for_first_load(value: bool) -> void:
	preparing_for_first_load = value


func _ready() -> void:
	await _initialize_worksite()


func _initialize_worksite() -> void:
	setup_complete = false
	_asset_file_cache.clear()
	await _build_interface()
	if not is_instance_valid(phone_model) or not is_instance_valid(phone_screen_texture):
		setup_failed.emit("The handset preview could not be initialized.")
		return
	await phone_model.call(
		"build_for_loading",
		phone_screen_texture,
		Callable(self, "_emit_setup_progress")
	)
	for step_index_value in STEP_ASSET_PATHS.keys():
		var step_index := int(step_index_value)
		var category_name: String = str(STEP_NAMES[step_index])
		_emit_setup_progress("Indexing %s assets" % category_name.to_lower(), 0.0)
		await get_tree().process_frame
		var files: Array[String] = []
		_collect_files(str(STEP_ASSET_PATHS[step_index]), files)
		files.sort()
		_asset_file_cache[step_index] = files
		_emit_setup_progress("Indexing %s assets" % category_name.to_lower(), 100.0)
		await get_tree().create_timer(0.18).timeout

	_emit_setup_progress("Generating the default lock screen", 0.0)
	await get_tree().process_frame
	var initial_design: Dictionary = lock_screen_designer.call("generate_new_design")
	if initial_design.is_empty():
		setup_failed.emit("The default lock-screen design could not be generated.")
		return
	_update_lock_screen_status(initial_design)
	_emit_setup_progress("Generating the default lock screen", 100.0)
	await get_tree().create_timer(0.18).timeout

	var home_ready: bool = await home_screen_designer.call(
		"configure_for_loading",
		initial_design,
		str(lock_screen_designer.call("get_status_bar_style_id")),
		Callable(self, "_emit_setup_progress")
	)
	if not home_ready:
		setup_failed.emit("The homepage or 200-app drawer could not be built.")
		return

	_build_all_step_content_panels()
	_show_step(0)
	_update_phone_preview_mode()
	setup_complete = true
	setup_completed.emit()

func _emit_setup_progress(message: String, progress: float) -> void:
	setup_progress.emit(message, clampf(progress, 0.0, 100.0))

func _build_interface() -> void:
	_emit_setup_progress("Building OS worksite screen layout", 0.0)
	var layer := CanvasLayer.new()
	layer.name = "OSCreationWorksiteInterface"
	layer.layer = 40
	layer.visible = not preparing_for_first_load
	add_child(layer)

	root_control = Control.new()
	root_control.name = "WorksiteRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root_control)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKGROUND
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(backdrop)

	# The two work areas occupy exactly half of the available width each.
	worksite_body = HBoxContainer.new()
	worksite_body.name = "WorksiteMainContent"
	worksite_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worksite_body.offset_left = 20.0
	worksite_body.offset_right = -20.0
	worksite_body.offset_top = 4.0
	worksite_body.offset_bottom = -12.0
	worksite_body.add_theme_constant_override("separation", 0)
	root_control.add_child(worksite_body)

	preview_region = Control.new()
	preview_region.name = "OSPhonePreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.08
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worksite_body.add_child(preview_region)
	_emit_setup_progress("Building OS worksite screen layout", 100.0)
	await get_tree().create_timer(0.18).timeout
	_emit_setup_progress("Preparing handset screen and boot interface", 0.0)

	var phone_center := CenterContainer.new()
	phone_center.name = "PhoneDisplayCenter"
	phone_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phone_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_region.add_child(phone_center)

	# The round power control is a separate object beside the handset.
	var phone_row := HBoxContainer.new()
	phone_row.name = "PhoneAndSeparatePowerButton"
	phone_row.alignment = BoxContainer.ALIGNMENT_CENTER
	phone_row.add_theme_constant_override("separation", 22)
	phone_center.add_child(phone_row)

	var power_button_center := CenterContainer.new()
	power_button_center.name = "PowerButtonCenter"
	power_button_center.custom_minimum_size = Vector2(58, 58)
	power_button_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	power_button_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	phone_row.add_child(power_button_center)

	power_button = Button.new()
	power_button.name = "SeparateRoundPowerButton"
	power_button.text = "⏻"
	power_button.custom_minimum_size = Vector2(58, 58)
	power_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	power_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_button.tooltip_text = "Power on / off"
	power_button.focus_mode = Control.FOCUS_NONE
	power_button.mouse_filter = Control.MOUSE_FILTER_STOP
	power_button.disabled = false
	power_button.z_index = 20
	power_button.add_theme_font_size_override("font_size", 30)
	power_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#343638"), Color("#8A8175"), 1, 30))
	power_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#40382D"), ACCENT, 1, 30))
	power_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#17191B"), ACCENT, 1, 30))
	power_button.add_theme_color_override("font_color", TEXT)
	power_button.pressed.connect(_on_power_pressed)
	power_button_center.add_child(power_button)

	# Render a fixed 3D handset in its own viewport. The camera is deliberately
	# static: the player can power the device, but cannot rotate or drag it.
	phone_frame = SubViewportContainer.new()
	phone_frame.name = "OSPhone3DPreview"
	phone_frame.custom_minimum_size = Vector2(250, 500)
	phone_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	phone_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	phone_frame.stretch = true
	phone_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_frame.gui_input.connect(_on_phone_preview_gui_input)
	phone_row.add_child(phone_frame)

	var phone_viewport := SubViewport.new()
	phone_viewport.name = "FixedPhone3DViewport"
	phone_viewport.size = Vector2i(700, 1400)
	phone_viewport.msaa_3d = Viewport.MSAA_DISABLED
	phone_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	phone_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	phone_viewport.scaling_3d_scale = 1.25
	phone_viewport.own_world_3d = true
	phone_viewport.transparent_bg = true
	phone_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	phone_frame.add_child(phone_viewport)

	var phone_world := Node3D.new()
	phone_world.name = "FixedPhonePreviewWorld"
	phone_viewport.add_child(phone_world)

	# A dedicated UI viewport supplies the boot image to the 3D glass surface.
	# The handset model itself is built by the same geometry rules as the
	# working Phone Creation Worksite, not by a second improvised phone mesh.
	var screen_viewport := SubViewport.new()
	phone_screen_interface_viewport = screen_viewport
	screen_viewport.name = "PhoneScreenInterfaceViewport"
	screen_viewport.size = Vector2i(680, 1360)
	screen_viewport.transparent_bg = false
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	phone_viewport.add_child(screen_viewport)

	var screen_root := Control.new()
	screen_root.name = "PhoneScreenInterface"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_viewport.add_child(screen_root)

	phone_screen = ColorRect.new()
	phone_screen.name = "PhoneDisplay"
	phone_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phone_screen.color = Color("#000000")
	phone_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(phone_screen)

	var boot_content := VBoxContainer.new()
	boot_content.name = "BootScreenContent"
	boot_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot_content.alignment = BoxContainer.ALIGNMENT_CENTER
	boot_content.add_theme_constant_override("separation", 28)
	boot_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_screen.add_child(boot_content)

	company_logo_preview = TextureRect.new()
	company_logo_preview.name = "CompanyLogoBootImage"
	company_logo_preview.custom_minimum_size = Vector2(190, 190)
	company_logo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	company_logo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	company_logo_preview.texture = company_logo_texture
	company_logo_preview.visible = false
	company_logo_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot_content.add_child(company_logo_preview)

	phone_name_label = _make_label("Digital World", 60, TEXT)
	phone_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_name_label.visible = false
	boot_content.add_child(phone_name_label)
	_apply_boot_font_weight(phone_name_label, 900)

	phone_model_label = _make_label("Test Mobile", 55, Color("#D0CBC2"))
	phone_model_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_model_label.visible = false
	boot_content.add_child(phone_model_label)
	_apply_boot_font_weight(phone_model_label, 900)

	lock_screen_designer = LockScreenDesignerScript.new()
	lock_screen_designer.name = "AutonomousLockScreenDesignerPreview"
	lock_screen_designer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_screen_designer.offset_left = 0.0
	lock_screen_designer.offset_top = 0.0
	lock_screen_designer.offset_right = 0.0
	lock_screen_designer.offset_bottom = 0.0
	lock_screen_designer.visible = false
	phone_screen.add_child(lock_screen_designer)
	lock_screen_designer.pin_unlocked.connect(_on_pin_unlocked)

	home_screen_designer = HomeScreenDesignerScript.new()
	home_screen_designer.name = "OneUIHomeScreenPreview"
	home_screen_designer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_screen_designer.offset_left = 0.0
	home_screen_designer.offset_top = 0.0
	home_screen_designer.offset_right = 0.0
	home_screen_designer.offset_bottom = 0.0
	home_screen_designer.visible = false
	phone_screen.add_child(home_screen_designer)
	_emit_setup_progress("Preparing handset screen and boot interface", 100.0)
	await get_tree().create_timer(0.18).timeout
	_emit_setup_progress("Preparing handset scene connection", 0.0)

	phone_model = OSPhoneModelScript.new()
	phone_model.name = "OSWorksiteHandsetModel"
	phone_world.add_child(phone_model)
	phone_screen_texture = screen_viewport.get_texture()
	_emit_setup_progress("Preparing handset scene connection", 100.0)
	await get_tree().create_timer(0.18).timeout
	_emit_setup_progress("Building OS worksite controls and navigation", 0.0)

	controls_scroll = ScrollContainer.new()
	controls_scroll.name = "OSControlsScroll"
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_stretch_ratio = 0.92
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_bar := controls_scroll.get_v_scroll_bar()
	scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worksite_body.add_child(controls_scroll)

	var controls_margin := MarginContainer.new()
	controls_margin.name = "OSControlsMargin"
	controls_margin.add_theme_constant_override("margin_left", 28)
	controls_margin.add_theme_constant_override("margin_right", 24)
	controls_margin.add_theme_constant_override("margin_top", 66)
	controls_margin.add_theme_constant_override("margin_bottom", 20)
	controls_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls_margin)

	controls_stack = VBoxContainer.new()
	controls_stack.name = "OSControlsStack"
	controls_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_stack.add_theme_constant_override("separation", 18)
	controls_margin.add_child(controls_stack)

	var heading_row := HBoxContainer.new()
	heading_row.name = "WorksiteStepHeroRow"
	heading_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_theme_constant_override("separation", 10)
	controls_stack.add_child(heading_row)

	heading_label = _make_label("OS SETUP", 22, Color("#D3AA6B"))
	heading_label.name = "WorksiteStepHero"
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_row.add_child(heading_label)

	clock_enabled_toggle = Button.new()
	clock_enabled_toggle.name = "LockScreenClockEnabled"
	clock_enabled_toggle.toggle_mode = true
	clock_enabled_toggle.text = "✓  ENABLE" if bool(lock_screen_designer.call("get_display_option", "clock")) else "□  ENABLE"
	clock_enabled_toggle.custom_minimum_size = Vector2(112, 38)
	clock_enabled_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	clock_enabled_toggle.focus_mode = Control.FOCUS_NONE
	clock_enabled_toggle.button_pressed = bool(lock_screen_designer.call("get_display_option", "clock"))
	_style_clock_enable_toggle(clock_enabled_toggle, clock_enabled_toggle.button_pressed)
	clock_enabled_toggle.toggled.connect(_on_clock_enabled_toggled)
	heading_row.add_child(clock_enabled_toggle)

	content_column = VBoxContainer.new()
	content_column.name = "OSStepControls"
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_column.alignment = BoxContainer.ALIGNMENT_CENTER
	content_column.add_theme_constant_override("separation", 28)
	controls_stack.add_child(content_column)
	_step_content_host = content_column

	selection_status_label = _make_label("NO ASSET SELECTED", 10, MUTED)
	selection_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_stack.add_child(selection_status_label)

	# Navigation and progress are independent overlays, not header/footer bars.
	var back_button := _make_button("BACK")
	back_button.name = "WorksiteBackButton"
	back_button.anchor_left = 0.0
	back_button.anchor_top = 0.0
	back_button.anchor_right = 0.0
	back_button.anchor_bottom = 0.0
	back_button.offset_left = 20
	back_button.offset_top = 12
	back_button.offset_right = 104
	back_button.offset_bottom = 58
	back_button.pressed.connect(func(): back_requested.emit())
	root_control.add_child(back_button)

	var progress_box := VBoxContainer.new()
	progress_box.name = "WorksiteProgress"
	progress_box.anchor_left = 1.0
	progress_box.anchor_right = 1.0
	progress_box.anchor_top = 0.0
	progress_box.anchor_bottom = 0.0
	progress_box.offset_left = -180
	progress_box.offset_top = 12
	progress_box.offset_right = -20
	progress_box.offset_bottom = 52
	progress_box.add_theme_constant_override("separation", 4)
	root_control.add_child(progress_box)

	progress_label = _make_label("STEP 01 / 11", 11, TEXT)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_box.add_child(progress_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = STEP_NAMES.size()
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("fill", _make_panel_style(ACCENT, ACCENT, 0, 4))
	progress_bar.add_theme_stylebox_override("background", _make_panel_style(Color("#17191B"), Color("#17191B"), 0, 4))
	progress_box.add_child(progress_bar)

	previous_button = _make_arrow_button("‹")
	previous_button.name = "WorksitePreviousArrow"
	previous_button.anchor_left = 0.0
	previous_button.anchor_right = 0.0
	previous_button.anchor_top = 1.0
	previous_button.anchor_bottom = 1.0
	previous_button.offset_left = 20
	previous_button.offset_top = -70
	previous_button.offset_right = 76
	previous_button.offset_bottom = -14
	previous_button.pressed.connect(_previous_step)
	root_control.add_child(previous_button)

	next_button = _make_arrow_button("›")
	next_button.name = "WorksiteNextArrow"
	next_button.anchor_left = 1.0
	next_button.anchor_right = 1.0
	next_button.anchor_top = 1.0
	next_button.anchor_bottom = 1.0
	next_button.offset_left = -76
	next_button.offset_top = -70
	next_button.offset_right = -20
	next_button.offset_bottom = -14
	next_button.pressed.connect(_next_step)
	root_control.add_child(next_button)

	root_control.resized.connect(_apply_responsive_layout)
	preview_region.resized.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	_emit_setup_progress("Building OS worksite controls and navigation", 100.0)
	await get_tree().create_timer(0.18).timeout

func _apply_responsive_layout() -> void:
	if not is_instance_valid(phone_frame) or not is_instance_valid(preview_region):
		return
	var available := preview_region.size
	# Keep the rendered 3D handset tall while preserving its real-world silhouette.
	var target_height := maxf(available.y + 6.0, 220.0)
	var aspect := 250.0 / 500.0
	var target_width := target_height * aspect
	var max_width := maxf(available.x - 84.0, 125.0)
	if target_width > max_width:
		target_width = max_width
		target_height = target_width / aspect
	phone_frame.custom_minimum_size = Vector2(target_width, target_height)




func _get_phone_screen_input_rect() -> Rect2:
	if not is_instance_valid(phone_frame):
		return Rect2()
	# Bounds account for the handset's 1.41 x 2.88 display projected
	# through the fixed 38-degree preview camera into its 700 x 1400 viewport.
	return Rect2(
		Vector2(phone_frame.size.x * 0.043, phone_frame.size.y * 0.0335),
		Vector2(phone_frame.size.x * 0.914, phone_frame.size.y * 0.933)
	)


func _get_phone_preview_event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return Vector2(-1.0, -1.0)


func _is_phone_preview_press_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		return button_event.button_index == MOUSE_BUTTON_LEFT and button_event.pressed
	return false


func _is_phone_preview_release_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		return button_event.button_index == MOUSE_BUTTON_LEFT and not button_event.pressed
	return false


func _map_phone_preview_position_to_screen(frame_position: Vector2) -> Vector2:
	var display_rect := _get_phone_screen_input_rect()
	if display_rect.size.x <= 0.0 or display_rect.size.y <= 0.0:
		return Vector2.ZERO
	var target_size := Vector2(680.0, 1360.0)
	if is_instance_valid(phone_screen_interface_viewport):
		target_size = Vector2(phone_screen_interface_viewport.size)
	return (frame_position - display_rect.position) / display_rect.size * target_size


func _forward_phone_screen_input(event: InputEvent, frame_position: Vector2) -> void:
	if not is_instance_valid(phone_screen_interface_viewport):
		return
	var display_rect := _get_phone_screen_input_rect()
	if display_rect.size.x <= 0.0 or display_rect.size.y <= 0.0:
		return
	var target_size := Vector2(phone_screen_interface_viewport.size)
	var input_scale := Vector2(target_size.x / display_rect.size.x, target_size.y / display_rect.size.y)
	var mapped_position := (frame_position - display_rect.position) * input_scale
	var mapped_event := event.duplicate() as InputEvent
	if mapped_event is InputEventScreenTouch:
		(mapped_event as InputEventScreenTouch).position = mapped_position
	elif mapped_event is InputEventScreenDrag:
		var drag_event := mapped_event as InputEventScreenDrag
		var source_drag := event as InputEventScreenDrag
		drag_event.position = mapped_position
		drag_event.relative = source_drag.relative * input_scale
	elif mapped_event is InputEventMouseButton:
		(mapped_event as InputEventMouseButton).position = mapped_position
	elif mapped_event is InputEventMouseMotion:
		var motion_event := mapped_event as InputEventMouseMotion
		var source_motion := event as InputEventMouseMotion
		motion_event.position = mapped_position
		motion_event.relative = source_motion.relative * input_scale
	phone_screen_interface_viewport.push_input(mapped_event, true)


func _on_phone_preview_gui_input(event: InputEvent) -> void:
	if not screen_powered or not boot_sequence_complete or not is_instance_valid(lock_screen_designer):
		return
	var pointer_position := _get_phone_preview_event_position(event)
	if pointer_position.x < 0.0:
		return

	if _is_phone_preview_press_event(event):
		if not _get_phone_screen_input_rect().has_point(pointer_position):
			return
		_phone_pointer_active = true
		_phone_pointer_start = pointer_position
		_phone_pointer_pin_mode = bool(lock_screen_designer.call("is_pin_entry_visible"))
		_phone_pointer_home_mode = is_instance_valid(home_screen_designer) and home_screen_designer.visible
		_phone_pointer_clock_mode = false
		if current_step == 1 and not _phone_pointer_pin_mode and not _phone_pointer_home_mode:
			var clock_screen_position := _map_phone_preview_position_to_screen(pointer_position)
			_phone_pointer_clock_mode = bool(lock_screen_designer.call("begin_clock_drag", clock_screen_position))
		if _phone_pointer_pin_mode or _phone_pointer_home_mode:
			_forward_phone_screen_input(event, pointer_position)
		return

	if not _phone_pointer_active:
		return

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _phone_pointer_clock_mode:
			lock_screen_designer.call("drag_clock_to", _map_phone_preview_position_to_screen(pointer_position))
		elif _phone_pointer_pin_mode or _phone_pointer_home_mode:
			_forward_phone_screen_input(event, pointer_position)
		return

	if _is_phone_preview_release_event(event):
		if _phone_pointer_clock_mode:
			lock_screen_designer.call("end_clock_drag")
			_phone_pointer_active = false
			_phone_pointer_clock_mode = false
			_phone_pointer_pin_mode = false
			_phone_pointer_home_mode = false
			return
		var delta := pointer_position - _phone_pointer_start
		var swipe_threshold := maxf(32.0, phone_frame.size.y * 0.075)
		var is_vertical_swipe := absf(delta.y) >= swipe_threshold and absf(delta.y) >= absf(delta.x) * 1.15
		var is_horizontal_swipe := absf(delta.x) >= swipe_threshold and absf(delta.x) >= absf(delta.y) * 1.15
		if _phone_pointer_pin_mode:
			_forward_phone_screen_input(event, pointer_position)
			if is_vertical_swipe and delta.y > 0.0:
				lock_screen_designer.call("hide_pin_entry")
		elif _phone_pointer_home_mode:
			_forward_phone_screen_input(event, pointer_position)
			if is_instance_valid(home_screen_designer):
				if not bool(home_screen_designer.call("is_app_drawer_visible")):
					if is_vertical_swipe and delta.y < 0.0:
						home_screen_designer.call("open_app_drawer")
					elif is_horizontal_swipe:
						home_screen_designer.call("move_page", -1 if delta.x > 0.0 else 1)
				elif is_vertical_swipe and delta.y > 0.0 and _phone_pointer_start.y < phone_frame.size.y * 0.32:
					home_screen_designer.call("close_app_drawer")
		elif is_vertical_swipe and delta.y < 0.0:
			lock_screen_designer.call("show_pin_entry")
		_phone_pointer_active = false
		_phone_pointer_pin_mode = false
		_phone_pointer_home_mode = false
		_phone_pointer_clock_mode = false


func _build_all_step_content_panels() -> void:
	if _step_content_panels_built or not is_instance_valid(_step_content_host):
		return
	for step_index in range(STEP_NAMES.size()):
		var panel := VBoxContainer.new()
		panel.name = "OSStepControls_%02d" % step_index
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_theme_constant_override("separation", 28)
		panel.visible = false
		_step_content_host.add_child(panel)
		_step_content_panels[step_index] = panel
	for step_index in range(STEP_NAMES.size()):
		content_column = _step_content_panels[step_index] as VBoxContainer
		match step_index:
			0:
				_show_boot_display_controls()
			1:
				_show_lock_screen_clock_controls()
			2:
				_show_lock_screen_designer_controls()
			6:
				_show_status_bar_style_controls()
			_:
				_show_asset_browser(step_index)
	_step_content_panels_built = true
	content_column = _step_content_panels.get(current_step, _step_content_panels[0]) as VBoxContainer


func _refresh_boot_order_rows() -> void:
	if not _step_content_panels.has(0):
		return
	var panel := _step_content_panels[0] as VBoxContainer
	for index in range(boot_display_order.size()):
		var option := boot_display_order[index]
		var row := panel.get_node_or_null("BootOrderRow_" + option) as HBoxContainer
		if row == null:
			continue
		panel.move_child(row, 2 + index)
		if row.get_child_count() > 0 and row.get_child(0) is Label:
			(row.get_child(0) as Label).text = "%02d" % (index + 1)
		var drag_handle := row.get_node_or_null("BootOrderDragHandle_" + option)
		if drag_handle != null:
			drag_handle.set("item_index", index)


func _show_step(step_index: int) -> void:
	current_step = clampi(step_index, 0, STEP_NAMES.size() - 1)
	heading_label.text = STEP_NAMES[current_step]
	selection_status_label.visible = current_step not in [1, 2]
	clock_enabled_toggle.visible = current_step == 1
	progress_label.text = "STEP %02d / %02d" % [current_step + 1, STEP_NAMES.size()]
	progress_bar.value = current_step + 1
	previous_button.disabled = current_step == 0
	next_button.text = "✓" if current_step == STEP_NAMES.size() - 1 else "›"
	selection_status_label.text = "NO ASSET SELECTED" if selected_asset_path.is_empty() else selected_asset_path.replace("res://", "")
	if _step_content_panels_built:
		for panel_value in _step_content_panels.values():
			var panel := panel_value as Control
			if is_instance_valid(panel):
				panel.visible = false
		content_column = _step_content_panels[current_step] as VBoxContainer
		content_column.visible = true
	_update_phone_preview_mode()

func _show_status_bar_style_controls() -> void:
	_add_note("TEN STATUS BAR STYLES")
	_add_note("Select a status-bar system. The live phone preview updates immediately using the Android vector assets.")
	selected_status_bar_style_id = str(lock_screen_designer.call("get_status_bar_style_id"))
	for style in StatusBarAssetLibrary.get_styles():
		var style_id := str(style.get("id", ""))
		var style_button := _make_button("")
		style_button.name = "StatusBarStyle_" + style_id
		style_button.custom_minimum_size.y = 48
		style_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		style_button.set_meta("status_style_id", style_id)
		style_button.pressed.connect(_on_status_bar_style_selected.bind(style_id))
		content_column.add_child(style_button)
		_update_status_bar_style_button(style_button)

func _on_status_bar_style_selected(style_id: String) -> void:
	if not lock_screen_designer.call("set_status_bar_style", style_id):
		return
	if is_instance_valid(home_screen_designer):
		home_screen_designer.call("set_status_bar_style", style_id)
	selected_status_bar_style_id = style_id
	for child in content_column.get_children():
		if child is Button and child.has_meta("status_style_id"):
			_update_status_bar_style_button(child)
	selection_status_label.text = "STATUS BAR  ·  " + str(StatusBarAssetLibrary.get_style(style_id).get("name", style_id))

func _update_status_bar_style_button(style_button: Button) -> void:
	var style_id := str(style_button.get_meta("status_style_id", ""))
	var style_name := str(StatusBarAssetLibrary.get_style(style_id).get("name", style_id))
	var selected := style_id == selected_status_bar_style_id
	style_button.text = style_name + ("     SELECTED" if selected else "")
	style_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#30291F") if selected else PANEL, ACCENT if selected else Color("#6E5B42"), 1, 9))
	style_button.add_theme_color_override("font_color", TEXT if selected else MUTED)

func _show_boot_display_controls() -> void:
	_add_note("BOOT DISPLAY ORDER")
	_add_note("Drag the grip handle to change the sequence. Switch each item ON or OFF independently.")
	var labels := {
		"logo": "Show Company Logo",
		"phone_name": "Show Phone Name",
		"phone_model": "Show Phone Model"
	}
	for index in range(boot_display_order.size()):
		var option := boot_display_order[index]
		var row := HBoxContainer.new()
		row.name = "BootOrderRow_" + option
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_column.add_child(row)

		var position_label := _make_label("%02d" % (index + 1), 12, MUTED)
		position_label.custom_minimum_size = Vector2(24, 0)
		position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(position_label)

		var drag_handle := BootOrderDragHandle.new()
		drag_handle.name = "BootOrderDragHandle_" + option
		drag_handle.item_index = index
		drag_handle.custom_minimum_size = Vector2(38, 54)
		drag_handle.tooltip_text = "Drag to change boot order"
		drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
		drag_handle.reorder_requested.connect(_on_boot_order_drop)
		var grip_label := _make_label("☰", 22, Color("#D3AA6B"))
		grip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drag_handle.add_child(grip_label)
		row.add_child(drag_handle)

		var enabled := _is_boot_display_enabled(option)
		var toggle := _add_boot_display_toggle(str(labels[option]), option, enabled, row)
		match option:
			"logo":
				boot_logo_toggle = toggle
			"phone_name":
				boot_phone_name_toggle = toggle
			"phone_model":
				boot_phone_model_toggle = toggle

func _is_boot_display_enabled(option: String) -> bool:
	match option:
		"logo":
			return show_company_logo_on_boot
		"phone_name":
			return show_phone_name_on_boot
		"phone_model":
			return show_phone_model_on_boot
	return false

func _on_boot_order_drop(source_index: int, target_index: int) -> void:
	if source_index < 0 or source_index >= boot_display_order.size():
		return
	if target_index < 0 or target_index >= boot_display_order.size() or source_index == target_index:
		return
	var moved_option: String = boot_display_order.pop_at(source_index)
	boot_display_order.insert(target_index, moved_option)
	_refresh_boot_order_rows()

func _add_boot_display_toggle(label: String, option: String, initially_enabled: bool, parent: Container = null) -> Button:
	var toggle := _make_button("")
	toggle.toggle_mode = true
	toggle.button_pressed = initially_enabled
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size.y = 54
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.toggled.connect(_on_boot_display_toggled.bind(option, toggle, label))
	if parent == null:
		content_column.add_child(toggle)
	else:
		parent.add_child(toggle)
	_style_boot_display_toggle(toggle, initially_enabled, label)
	return toggle

func _on_boot_display_toggled(enabled: bool, option: String, toggle: Button, label: String) -> void:
	_set_boot_display_option(option, enabled)
	if not enabled and not _has_enabled_boot_display():
		toggle.set_pressed_no_signal(true)
		enabled = true
		_set_boot_display_option(option, true)
	_style_boot_display_toggle(toggle, enabled, label)
	_update_phone_preview_mode()

func _set_boot_display_option(option: String, enabled: bool) -> void:
	match option:
		"logo":
			show_company_logo_on_boot = enabled
		"phone_name":
			show_phone_name_on_boot = enabled
		"phone_model":
			show_phone_model_on_boot = enabled

func _has_enabled_boot_display() -> bool:
	return show_company_logo_on_boot or show_phone_name_on_boot or show_phone_model_on_boot

func _style_boot_display_toggle(toggle: Button, enabled: bool, label: String) -> void:
	toggle.text = "%s     %s" % [label, "ON" if enabled else "OFF"]
	var fill := Color("#30291F") if enabled else PANEL
	var border := ACCENT if enabled else Color("#6E5B42")
	toggle.add_theme_stylebox_override("normal", _make_panel_style(fill, border, 1, 9))
	toggle.add_theme_stylebox_override("hover", _make_panel_style(Color("#40382D") if enabled else Color("#292B2D"), ACCENT, 1, 9))
	toggle.add_theme_stylebox_override("pressed", _make_panel_style(Color("#30291F"), ACCENT, 1, 9))
	toggle.add_theme_color_override("font_color", TEXT if enabled else MUTED)

func _style_clock_enable_toggle(toggle: Button, enabled: bool) -> void:
	toggle.text = "✓  ENABLE" if enabled else "□  ENABLE"
	var fill := Color("#30291F") if enabled else Color("#17191B")
	var border := ACCENT if enabled else Color("#62513D")
	toggle.add_theme_stylebox_override("normal", _make_panel_style(fill, border, 1, 8))
	toggle.add_theme_stylebox_override("hover", _make_panel_style(Color("#40382D"), ACCENT, 1, 8))
	toggle.add_theme_stylebox_override("pressed", _make_panel_style(Color("#30291F"), ACCENT, 1, 8))
	toggle.add_theme_color_override("font_color", TEXT if enabled else MUTED)
	toggle.add_theme_font_size_override("font_size", 12)

func _on_clock_enabled_toggled(enabled: bool) -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	_style_clock_enable_toggle(clock_enabled_toggle, enabled)
	if not bool(lock_screen_designer.call("set_display_option", "clock", enabled)):
		clock_enabled_toggle.set_pressed_no_signal(not enabled)
		_style_clock_enable_toggle(clock_enabled_toggle, not enabled)


func _show_lock_screen_clock_controls() -> void:
	clock_type_row = null
	clock_type_value_label = null
	clock_type_decrease_button = null
	clock_type_increase_button = null
	clock_style_row = null
	clock_style_value_label = null
	clock_style_decrease_button = null
	clock_style_increase_button = null
	clock_position_flex_button = null
	clock_position_fixed_button = null
	clock_position_description = null

	# Keep each sub-hero heading immediately above its selector. Descriptions
	# remain available below the selector instead of separating the two.
	var feature_panel := VBoxContainer.new()
	feature_panel.name = "LockScreenClockFeaturePanel"
	feature_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feature_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	feature_panel.add_theme_constant_override("separation", 28)
	content_column.add_child(feature_panel)

	var type_section := VBoxContainer.new()
	type_section.name = "ClockTypeFeatureSection"
	type_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_section.add_theme_constant_override("separation", 4)
	feature_panel.add_child(type_section)

	var type_title := _make_label("CLOCK TYPE", 19, Color("#D3AA6B"))
	type_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_section.add_child(type_title)

	var type_controls_center := CenterContainer.new()
	type_controls_center.name = "ClockTypeControlsCenter"
	type_controls_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_controls_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	type_section.add_child(type_controls_center)

	clock_type_row = HBoxContainer.new()
	clock_type_row.name = "ClockTypeSelector"
	clock_type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_type_row.add_theme_constant_override("separation", 14)
	type_controls_center.add_child(clock_type_row)

	clock_type_decrease_button = _make_button("−")
	clock_type_decrease_button.name = "ClockTypeDecreaseButton"
	clock_type_decrease_button.custom_minimum_size = Vector2(56, 48)
	clock_type_decrease_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clock_type_decrease_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_type_decrease_button.add_theme_font_size_override("font_size", 22)
	clock_type_decrease_button.pressed.connect(_select_lock_screen_clock_type.bind("analog"))
	clock_type_row.add_child(clock_type_decrease_button)

	clock_type_value_label = _make_label("", 19, Color("#F2EEE7"))
	clock_type_value_label.name = "ClockTypeValueLabel"
	clock_type_value_label.custom_minimum_size.x = 190
	clock_type_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_type_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_type_row.add_child(clock_type_value_label)

	clock_type_increase_button = _make_button("+")
	clock_type_increase_button.name = "ClockTypeIncreaseButton"
	clock_type_increase_button.custom_minimum_size = Vector2(56, 48)
	clock_type_increase_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clock_type_increase_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_type_increase_button.add_theme_font_size_override("font_size", 22)
	clock_type_increase_button.pressed.connect(_select_lock_screen_clock_type.bind("digital"))
	clock_type_row.add_child(clock_type_increase_button)

	var type_description := _make_label("Choose between analog and digital clock designs for the phone lock screen.", 12, Color("#E5E0D6"))
	type_description.name = "ClockTypeDescription"
	type_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	type_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_section.add_child(type_description)

	var style_section := VBoxContainer.new()
	style_section.name = "ClockStyleFeatureSection"
	style_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_section.add_theme_constant_override("separation", 4)
	feature_panel.add_child(style_section)

	var style_title := _make_label("CLOCK STYLE", 19, Color("#D3AA6B"))
	style_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_section.add_child(style_title)

	var style_controls_center := CenterContainer.new()
	style_controls_center.name = "ClockStyleControlsCenter"
	style_controls_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_controls_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	style_section.add_child(style_controls_center)

	clock_style_row = HBoxContainer.new()
	clock_style_row.name = "ClockStyleSelector"
	clock_style_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_style_row.add_theme_constant_override("separation", 14)
	style_controls_center.add_child(clock_style_row)

	clock_style_decrease_button = _make_button("−")
	clock_style_decrease_button.name = "ClockStyleDecreaseButton"
	clock_style_decrease_button.custom_minimum_size = Vector2(56, 48)
	clock_style_decrease_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clock_style_decrease_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_style_decrease_button.add_theme_font_size_override("font_size", 22)
	clock_style_decrease_button.pressed.connect(_on_clock_style_decrease_pressed)
	clock_style_row.add_child(clock_style_decrease_button)

	clock_style_value_label = _make_label("", 19, Color("#F2EEE7"))
	clock_style_value_label.name = "ClockStyleValueLabel"
	clock_style_value_label.custom_minimum_size.x = 190
	clock_style_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_style_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_style_row.add_child(clock_style_value_label)

	clock_style_increase_button = _make_button("+")
	clock_style_increase_button.name = "ClockStyleIncreaseButton"
	clock_style_increase_button.custom_minimum_size = Vector2(56, 48)
	clock_style_increase_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clock_style_increase_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_style_increase_button.add_theme_font_size_override("font_size", 22)
	clock_style_increase_button.pressed.connect(_on_clock_style_increase_pressed)
	clock_style_row.add_child(clock_style_increase_button)

	var style_description := _make_label("Choose one of the 41 available clock designs for the live phone preview.", 12, Color("#E5E0D6"))
	style_description.name = "ClockStyleDescription"
	style_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	style_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_section.add_child(style_description)

	var position_section := VBoxContainer.new()
	position_section.name = "ClockPositionFeatureSection"
	position_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_section.add_theme_constant_override("separation", 6)
	feature_panel.add_child(position_section)

	var position_title := _make_label("CLOCK POSITION", 19, Color("#D3AA6B"))
	position_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_section.add_child(position_title)

	var position_controls_center := CenterContainer.new()
	position_controls_center.name = "ClockPositionControlsCenter"
	position_controls_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_section.add_child(position_controls_center)

	var position_row := HBoxContainer.new()
	position_row.name = "ClockPositionSelector"
	position_row.alignment = BoxContainer.ALIGNMENT_CENTER
	position_row.add_theme_constant_override("separation", 10)
	position_controls_center.add_child(position_row)

	clock_position_flex_button = _make_button("FLEX")
	clock_position_flex_button.name = "ClockPositionFlexButton"
	clock_position_flex_button.custom_minimum_size = Vector2(132, 48)
	clock_position_flex_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_position_flex_button.pressed.connect(_on_clock_position_mode_selected.bind("flex"))
	position_row.add_child(clock_position_flex_button)

	clock_position_fixed_button = _make_button("FIXED")
	clock_position_fixed_button.name = "ClockPositionFixedButton"
	clock_position_fixed_button.custom_minimum_size = Vector2(132, 48)
	clock_position_fixed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_position_fixed_button.pressed.connect(_on_clock_position_mode_selected.bind("fixed"))
	position_row.add_child(clock_position_fixed_button)

	clock_position_description = _make_label("", 12, Color("#E5E0D6"))
	clock_position_description.name = "ClockPositionDescription"
	clock_position_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_position_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	clock_position_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position_section.add_child(clock_position_description)

	_refresh_clock_type_selector()
	_refresh_clock_style_selector()
	_refresh_clock_position_controls()


func _on_clock_position_mode_selected(mode: String) -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	if not bool(lock_screen_designer.call("set_clock_position_mode", mode)):
		return
	_refresh_clock_position_controls()


func _refresh_clock_position_controls() -> void:
	if not is_instance_valid(clock_position_flex_button) or not is_instance_valid(clock_position_fixed_button) or not is_instance_valid(lock_screen_designer):
		return
	var selected_mode := str(lock_screen_designer.call("get_clock_position_mode"))
	var is_flex := selected_mode == "flex"
	clock_position_flex_button.disabled = is_flex
	clock_position_fixed_button.disabled = not is_flex
	clock_position_flex_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#30291F") if is_flex else PANEL, ACCENT if is_flex else Color("#6E5B42"), 1, 9))
	clock_position_fixed_button.add_theme_stylebox_override("normal", _make_panel_style(PANEL if is_flex else Color("#30291F"), Color("#6E5B42") if is_flex else ACCENT, 1, 9))
	clock_position_description.text = "Drag the clock anywhere on the phone preview, then choose FIXED to lock its position." if is_flex else "The clock is fixed in place. Choose FLEX to reposition it on the phone preview."

func _refresh_clock_type_selector() -> void:
	if not is_instance_valid(clock_type_row) or not is_instance_valid(lock_screen_designer):
		return
	var selected_type := str(lock_screen_designer.call("get_clock_type"))
	if is_instance_valid(clock_type_value_label):
		clock_type_value_label.text = selected_type.to_upper()
	if is_instance_valid(clock_type_decrease_button):
		clock_type_decrease_button.disabled = selected_type == "analog"
	if is_instance_valid(clock_type_increase_button):
		clock_type_increase_button.disabled = selected_type == "digital"


func _select_lock_screen_clock_type(clock_type: String) -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	if not bool(lock_screen_designer.call("set_clock_type", clock_type)):
		return
	_refresh_clock_type_selector()


func _on_clock_style_decrease_pressed() -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	var previous_style := int(lock_screen_designer.call("get_clock_style_index")) - 1
	if previous_style < 1:
		return
	if bool(lock_screen_designer.call("set_clock_style_index", previous_style)):
		_refresh_clock_style_selector()


func _on_clock_style_increase_pressed() -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	var next_style := int(lock_screen_designer.call("get_clock_style_index")) + 1
	if next_style > int(lock_screen_designer.call("get_clock_style_count")):
		return
	if bool(lock_screen_designer.call("set_clock_style_index", next_style)):
		_refresh_clock_style_selector()


func _refresh_clock_style_selector() -> void:
	if not is_instance_valid(clock_style_row) or not is_instance_valid(lock_screen_designer):
		return
	var selected_style := int(lock_screen_designer.call("get_clock_style_index"))
	var style_count := int(lock_screen_designer.call("get_clock_style_count"))
	if is_instance_valid(clock_style_value_label):
		clock_style_value_label.text = "STYLE %02d" % selected_style
		var active_clock_type := str(lock_screen_designer.call("get_clock_type"))
		if active_clock_type == "digital":
			var style_name := str(lock_screen_designer.call("get_clock_style_name"))
			clock_style_value_label.tooltip_text = "XMorph digital face: " + style_name
		else:
			clock_style_value_label.tooltip_text = "Analog clock artwork %02d" % selected_style
	if is_instance_valid(clock_style_decrease_button):
		clock_style_decrease_button.disabled = selected_style <= 1
	if is_instance_valid(clock_style_increase_button):
		clock_style_increase_button.disabled = selected_style >= style_count


func _show_lock_screen_designer_controls() -> void:
	if int(lock_screen_designer.call("get_generation_count")) == 0:
		_generate_lock_screen_design()
	else:
		_update_lock_screen_status(lock_screen_designer.call("get_last_design"))

	var generate_button := _make_button("GENERATE NEW LAYOUT")
	generate_button.name = "GenerateNewLockScreenDesign"
	generate_button.custom_minimum_size.y = 54
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_button.pressed.connect(_generate_lock_screen_design)
	content_column.add_child(generate_button)

	var display_options := [
		{"option": "notification", "label": "Notification"},
		{"option": "shortcut", "label": "Shortcut"},
		{"option": "details", "label": "Details"},
		{"option": "widget", "label": "Widget"},
		{"option": "unlock", "label": "Unlock"}
	]
	for option_data in display_options:
		_add_lock_screen_display_toggle(str(option_data["label"]), str(option_data["option"]))


func _add_lock_screen_display_toggle(label: String, option: String) -> void:
	var enabled := bool(lock_screen_designer.call("get_display_option", option))
	var row := HBoxContainer.new()
	row.name = "LockScreenOptionRow_" + option
	row.custom_minimum_size = Vector2(0, 54)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	content_column.add_child(row)

	var toggle := CheckBox.new()
	toggle.name = "LockScreenOption_" + option
	toggle.button_pressed = enabled
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(_on_lock_screen_display_toggled.bind(option, toggle))
	row.add_child(toggle)

	var label_control := _make_label(label, 18, TEXT)
	label_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label_control)


func _on_lock_screen_display_toggled(enabled: bool, option: String, toggle: CheckBox) -> void:
	if not bool(lock_screen_designer.call("set_display_option", option, enabled)):
		toggle.set_pressed_no_signal(not enabled)


func _generate_lock_screen_design() -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	var generated: Dictionary = lock_screen_designer.call("generate_new_design")
	if generated.is_empty():
		selection_status_label.text = "DESIGN VALIDATION FAILED — GENERATE AGAIN"
		return
	_update_lock_screen_status(generated)
	_configure_home_screen()
	_update_phone_preview_mode()


func _update_lock_screen_status(generated: Dictionary) -> void:
	var generation := int(lock_screen_designer.call("get_generation_count"))
	var layout_name := str(generated.get("layout_name", "AUTONOMOUS"))
	var wallpaper_number := int(generated.get("wallpaper_index", 0))
	var wallpaper_total := int(lock_screen_designer.call("get_available_wallpaper_count"))
	selection_status_label.text = "DESIGN %03d  •  %s\nWALLPAPER %02d / %02d" % [
		generation,
		layout_name,
		wallpaper_number,
		wallpaper_total
	]

func _configure_home_screen() -> void:
	if not is_instance_valid(home_screen_designer) or not is_instance_valid(lock_screen_designer):
		return
	var design: Dictionary = lock_screen_designer.call("get_last_design")
	if design.is_empty():
		return
	home_screen_designer.call("configure", design, str(lock_screen_designer.call("get_status_bar_style_id")))


func _on_pin_unlocked() -> void:
	if not screen_powered or not boot_sequence_complete:
		return
	_home_screen_unlocked = true
	lock_screen_designer.visible = false
	lock_screen_designer.call("hide_pin_entry")
	home_screen_designer.visible = true
	_update_phone_preview_mode()


func _update_phone_preview_mode() -> void:
	if not is_instance_valid(lock_screen_designer):
		return
	if not screen_powered:
		lock_screen_designer.call("hide_pin_entry")
		lock_screen_designer.visible = false
		if is_instance_valid(home_screen_designer):
			home_screen_designer.visible = false
		return
	if not boot_sequence_complete:
		lock_screen_designer.call("hide_pin_entry")
		lock_screen_designer.visible = false
		if is_instance_valid(home_screen_designer):
			home_screen_designer.visible = false
		return
	company_logo_preview.visible = false
	phone_name_label.visible = false
	phone_model_label.visible = false
	var has_lock_screen := int(lock_screen_designer.call("get_generation_count")) > 0
	lock_screen_designer.visible = has_lock_screen and not _home_screen_unlocked
	if is_instance_valid(home_screen_designer):
		if _home_screen_unlocked:
			if not bool(home_screen_designer.call("get_loaded_app_count") > 0):
				_configure_home_screen()
			home_screen_designer.visible = true
		else:
			home_screen_designer.visible = false

func _show_asset_browser(step_index: int) -> void:
	var path := str(STEP_ASSET_PATHS.get(step_index, ""))

	var path_label := _make_label(path.replace("res://", ""), 10, Color("#D3AA6B"))
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_column.add_child(path_label)

	var files: Array[String] = []
	if step_index == 5 and is_instance_valid(lock_screen_designer):
		var wallpaper_paths: Array = lock_screen_designer.call("get_wallpaper_paths")
		for wallpaper_path in wallpaper_paths:
			files.append(str(wallpaper_path))
	else:
		var cached_files: Variant = _asset_file_cache.get(step_index, null)
		if cached_files is Array:
			for cached_path in cached_files:
				files.append(str(cached_path))
		else:
			_collect_files(path, files)
			files.sort()
	if files.is_empty():
		_add_note("No collected files are present in this category yet. This category is ready for its assets.")
		return

	for file_path in files:
		var item := _make_button(file_path.trim_prefix(path + "/"))
		item.custom_minimum_size.y = 48
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.pressed.connect(_select_asset.bind(file_path))
		content_column.add_child(item)

func _collect_files(folder_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var full_path := folder_path.path_join(entry)
			if directory.current_is_dir():
				_collect_files(full_path, output)
			else:
				output.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _select_asset(path: String) -> void:
	selected_asset_path = path
	if current_step == 5 and is_instance_valid(lock_screen_designer):
		if not bool(lock_screen_designer.call("set_wallpaper", path)):
			selection_status_label.text = "WALLPAPER COULD NOT BE LOADED"
			return
		selection_status_label.text = "WALLPAPER SELECTED  •  " + path.get_file()
		return
	selection_status_label.text = path.replace("res://", "")

func set_company_logo_texture(texture: Texture2D) -> void:
	company_logo_texture = texture
	if is_instance_valid(company_logo_preview):
		company_logo_preview.texture = texture

func _on_power_pressed() -> void:
	boot_sequence_id += 1
	if screen_powered:
		if is_instance_valid(lock_screen_designer):
			lock_screen_designer.call("hide_pin_entry")
		_phone_pointer_active = false
		_phone_pointer_pin_mode = false
		_phone_pointer_home_mode = false
		_home_screen_unlocked = false
		if is_instance_valid(home_screen_designer):
			home_screen_designer.visible = false
		screen_powered = false
		boot_sequence_complete = false
		lock_screen_designer.visible = false
		company_logo_preview.visible = false
		phone_name_label.visible = false
		phone_model_label.visible = false
		phone_screen.color = Color("#000000")
		return

	_home_screen_unlocked = false
	if is_instance_valid(home_screen_designer):
		home_screen_designer.visible = false
	screen_powered = true
	boot_sequence_complete = false
	lock_screen_designer.visible = false
	phone_screen.color = Color("#050607")
	company_logo_preview.visible = false
	phone_name_label.visible = false
	phone_model_label.visible = false
	_show_phone_boot_sequence(boot_sequence_id)

func get_boot_sequence_duration_seconds() -> float:
	return 10.0

func _get_boot_presentation_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var enabled_options: Array[String] = []
	for option in boot_display_order:
		if _is_boot_display_enabled(option):
			enabled_options.append(option)
	if enabled_options.is_empty():
		return plan

	var stage_duration := get_boot_sequence_duration_seconds() / float(enabled_options.size())
	for option in enabled_options:
		plan.append({"kind": option, "duration": stage_duration})
	return plan

func _show_phone_boot_sequence(sequence_id: int, duration_scale: float = 1.0) -> void:
	for stage in _get_boot_presentation_plan():
		if not _is_boot_sequence_active(sequence_id):
			return
		var stage_kind := str(stage.get("kind", "logo"))
		company_logo_preview.visible = stage_kind == "logo"
		phone_name_label.visible = stage_kind == "phone_name"
		phone_model_label.visible = stage_kind == "phone_model"
		await get_tree().create_timer(float(stage.get("duration", 10.0)) * duration_scale, true, false, true).timeout
		if not _is_boot_sequence_active(sequence_id):
			return

	company_logo_preview.visible = false
	phone_name_label.visible = false
	phone_model_label.visible = false
	boot_sequence_complete = true
	_update_phone_preview_mode()

func _is_boot_sequence_active(sequence_id: int) -> bool:
	return screen_powered and sequence_id == boot_sequence_id

func _add_note(message: String) -> void:
	var note := _make_label(message, 11, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_column.add_child(note)

func _previous_step() -> void:
	if current_step > 0:
		_show_step(current_step - 1)

func _next_step() -> void:
	if current_step < STEP_NAMES.size() - 1:
		_show_step(current_step + 1)
	else:
		back_requested.emit()

func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _apply_boot_font_weight(label: Label, weight: int) -> void:
	var base_font := label.get_theme_font("font")
	if base_font == null:
		return
	var weighted_font := FontVariation.new()
	weighted_font.base_font = base_font
	weighted_font.variation_opentype = {"wght": weight}
	label.add_theme_font_override("font", weighted_font)

func _make_panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _make_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _make_panel_style(PANEL, Color("#6E5B42"), 1, 9))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color("#30291F"), ACCENT, 1, 9))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#211B14"), ACCENT, 1, 9))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color("#F2EDE4"))
	return button

func _make_arrow_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(56, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color("#17191B"), Color("#6E5B42"), 1, 28))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color("#30291F"), ACCENT, 1, 28))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#211B14"), ACCENT, 1, 28))
	button.add_theme_color_override("font_color", TEXT)
	return button
