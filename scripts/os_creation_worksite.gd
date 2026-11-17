extends Node3D

signal back_requested

const STEP_NAMES := [
	"OS SETUP",
	"BOOTLOADER",
	"APP ICONS",
	"WIDGETS",
	"WALLPAPERS",
	"LOCK-SCREEN",
	"STATUS BAR",
	"QUICK SETTINGS",
	"NOTIFICATIONS",
	"NAVIGATION",
	"RECENT APPS"
]

const STEP_DESCRIPTIONS := [
	"Define the identity of the operating system.",
	"Set the startup presentation for this operating system.",
	"Choose the icon assets that will be available to this OS.",
	"Choose widget designs for the operating system.",
	"Choose wallpaper assets for the operating system.",
	"Choose lock-screen components and visual assets.",
	"Choose the status bar design assets.",
	"Choose quick settings and control-centre assets.",
	"Choose notification appearance assets.",
	"Choose navigation assets and interaction styles.",
	"Choose recent-apps presentation assets."
]

const STEP_ASSET_PATHS := {
	2: "res://assets/app_icons",
	3: "res://assets/system-ui/Widgets",
	4: "res://assets/system-ui/Wallpapers",
	5: "res://assets/system-ui/Lock-Screen",
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

var current_step := 0
var root_control: Control
var worksite_body: HBoxContainer
var preview_region: Control
var controls_scroll: ScrollContainer
var controls_stack: VBoxContainer
var heading_label: Label
var description_label: Label
var progress_label: Label
var progress_bar: ProgressBar
var content_column: VBoxContainer
var selection_status_label: Label
var phone_frame: PanelContainer
var phone_screen: ColorRect
var power_button: Button
var previous_button: Button
var next_button: Button
var os_name_input: LineEdit
var manufacturer_input: LineEdit
var boot_logo_toggle: CheckButton
var boot_device_toggle: CheckButton
var selected_asset_path := ""
var screen_powered := false
var company_logo_preview: TextureRect
var company_logo_texture: Texture2D
var phone_name_label: Label
var phone_model_label: Label

func _ready() -> void:
	_build_interface()
	_show_step(0)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OSCreationWorksiteInterface"
	layer.layer = 40
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
	preview_region.size_flags_stretch_ratio = 1.0
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worksite_body.add_child(preview_region)

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
	power_button.add_theme_font_size_override("font_size", 30)
	power_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#343638"), Color("#8A8175"), 1, 30))
	power_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#40382D"), ACCENT, 1, 30))
	power_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#17191B"), ACCENT, 1, 30))
	power_button.add_theme_color_override("font_color", TEXT)
	power_button.pressed.connect(_on_power_pressed)
	power_button_center.add_child(power_button)

	phone_frame = PanelContainer.new()
	phone_frame.name = "OSPhoneFrame"
	phone_frame.custom_minimum_size = Vector2(228, 440)
	phone_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	phone_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	phone_frame.add_theme_stylebox_override("panel", _make_panel_style(Color("#08090A"), Color("#77736D"), 2, 28))
	phone_row.add_child(phone_frame)

	var screen_margin := MarginContainer.new()
	screen_margin.add_theme_constant_override("margin_left", 9)
	screen_margin.add_theme_constant_override("margin_right", 9)
	screen_margin.add_theme_constant_override("margin_top", 9)
	screen_margin.add_theme_constant_override("margin_bottom", 9)
	phone_frame.add_child(screen_margin)

	phone_screen = ColorRect.new()
	phone_screen.name = "PhoneDisplay"
	phone_screen.color = Color("#000000")
	phone_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_margin.add_child(phone_screen)

	var boot_content := VBoxContainer.new()
	boot_content.name = "BootScreenContent"
	boot_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot_content.alignment = BoxContainer.ALIGNMENT_CENTER
	boot_content.add_theme_constant_override("separation", 18)
	boot_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_screen.add_child(boot_content)

	company_logo_preview = TextureRect.new()
	company_logo_preview.name = "CompanyLogoBootImage"
	company_logo_preview.custom_minimum_size = Vector2(104, 104)
	company_logo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	company_logo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	company_logo_preview.texture = company_logo_texture
	company_logo_preview.visible = false
	company_logo_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot_content.add_child(company_logo_preview)

	phone_name_label = _make_label("Digital World", 19, TEXT)
	phone_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_name_label.visible = false
	boot_content.add_child(phone_name_label)
	_apply_boot_font_weight(phone_name_label, 800)

	phone_model_label = _make_label("Test Mobile", 15, Color("#D0CBC2"))
	phone_model_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_model_label.visible = false
	boot_content.add_child(phone_model_label)
	_apply_boot_font_weight(phone_model_label, 700)

	controls_scroll = ScrollContainer.new()
	controls_scroll.name = "OSControlsScroll"
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_stretch_ratio = 1.0
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
	controls_margin.add_theme_constant_override("margin_top", 68)
	controls_margin.add_theme_constant_override("margin_bottom", 68)
	controls_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls_margin)

	controls_stack = VBoxContainer.new()
	controls_stack.name = "OSControlsStack"
	controls_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_stack.add_theme_constant_override("separation", 18)
	controls_margin.add_child(controls_stack)

	heading_label = _make_label("OS SETUP", 24, Color("#D3AA6B"))
	controls_stack.add_child(heading_label)

	description_label = _make_label("", 12, Color("#D0CBC2"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_stack.add_child(description_label)

	var content_gap := Control.new()
	content_gap.custom_minimum_size.y = 8
	controls_stack.add_child(content_gap)

	content_column = VBoxContainer.new()
	content_column.name = "OSStepControls"
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.add_theme_constant_override("separation", 16)
	controls_stack.add_child(content_column)

	selection_status_label = _make_label("NO ASSET SELECTED", 10, MUTED)
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
	call_deferred("_apply_responsive_layout")

func _apply_responsive_layout() -> void:
	if not is_instance_valid(phone_frame) or not is_instance_valid(preview_region):
		return
	var available := preview_region.size
	# Fill almost the entire preview height while preserving a realistic handset ratio.
	var target_height := maxf(available.y - 18.0, 220.0)
	var aspect := 228.0 / 440.0
	var target_width := target_height * aspect
	var max_width := maxf(available.x - 112.0, 120.0)
	if target_width > max_width:
		target_width = max_width
		target_height = target_width / aspect
	phone_frame.custom_minimum_size = Vector2(target_width, target_height)

func _show_step(step_index: int) -> void:
	current_step = clampi(step_index, 0, STEP_NAMES.size() - 1)
	heading_label.text = STEP_NAMES[current_step]
	description_label.text = STEP_DESCRIPTIONS[current_step]
	progress_label.text = "STEP %02d / %02d" % [current_step + 1, STEP_NAMES.size()]
	progress_bar.value = current_step + 1
	previous_button.disabled = current_step == 0
	next_button.text = "✓" if current_step == STEP_NAMES.size() - 1 else "›"
	selection_status_label.text = "NO ASSET SELECTED" if selected_asset_path.is_empty() else selected_asset_path.replace("res://", "")

	for child in content_column.get_children():
		content_column.remove_child(child)
		child.queue_free()

	match current_step:
		0:
			_add_field("OPERATING SYSTEM NAME", "Enter OS name", true)
			_add_field("MANUFACTURER / DEVELOPER", "Enter developer name", false)
		1:
			boot_logo_toggle = CheckButton.new()
			boot_logo_toggle.text = "Show company logo during startup"
			boot_logo_toggle.button_pressed = true
			content_column.add_child(boot_logo_toggle)
			boot_device_toggle = CheckButton.new()
			boot_device_toggle.text = "Show device name and model"
			boot_device_toggle.button_pressed = true
			content_column.add_child(boot_device_toggle)
		_:
			_show_asset_browser(current_step)

func _add_field(caption: String, placeholder: String, is_os_name: bool) -> void:
	var label := _make_label(caption, 11, Color("#D3AA6B"))
	content_column.add_child(label)
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = 48
	field.add_theme_color_override("font_color", TEXT)
	field.add_theme_color_override("font_placeholder_color", Color("#8F8A80"))
	field.add_theme_stylebox_override("normal", _make_panel_style(PANEL, Color("#6E5B42"), 1, 9))
	field.add_theme_stylebox_override("focus", _make_panel_style(Color("#29251F"), ACCENT, 1, 9))
	content_column.add_child(field)
	if is_os_name:
		os_name_input = field
	else:
		manufacturer_input = field

func _show_asset_browser(step_index: int) -> void:
	var path := str(STEP_ASSET_PATHS.get(step_index, ""))
	var path_label := _make_label(path.replace("res://", ""), 10, Color("#D3AA6B"))
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_column.add_child(path_label)

	var files: Array[String] = []
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
	selection_status_label.text = path.replace("res://", "")

func set_company_logo_texture(texture: Texture2D) -> void:
	company_logo_texture = texture
	if is_instance_valid(company_logo_preview):
		company_logo_preview.texture = texture

func _on_power_pressed() -> void:
	if screen_powered:
		screen_powered = false
		company_logo_preview.visible = false
		phone_name_label.visible = false
		phone_model_label.visible = false
		phone_screen.color = Color("#000000")
		return

	screen_powered = true
	phone_screen.color = Color("#050607")
	company_logo_preview.visible = true
	phone_name_label.visible = false
	phone_model_label.visible = false
	_show_phone_boot_sequence()

func _show_phone_boot_sequence() -> void:
	# First five real-time seconds: company logo.
	await get_tree().create_timer(5.0, true, false, true).timeout
	if not screen_powered or not is_instance_valid(phone_model_label):
		return

	# Next five real-time seconds: phone name and model.
	company_logo_preview.visible = false
	phone_name_label.visible = true
	phone_model_label.visible = true
	await get_tree().create_timer(5.0, true, false, true).timeout
	if not screen_powered:
		return
	# Boot is complete; keep the phone name/model on screen.

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
