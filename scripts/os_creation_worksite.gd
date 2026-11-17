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

var current_step := 0
var root_control: Control
var progress_label: Label
var progress_bar: ProgressBar
var heading_label: Label
var description_label: Label
var content_column: VBoxContainer
var asset_list: VBoxContainer
var preview_title: Label
var preview_detail: Label
var back_step_button: Button
var next_step_button: Button
var os_name_input: LineEdit
var manufacturer_input: LineEdit
var boot_logo_toggle: CheckButton
var boot_device_toggle: CheckButton
var selected_asset_path := ""

func _ready() -> void:
	_build_interface()
	_show_step(0)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OSCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_control)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#292B2D")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(backdrop)

	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 22
	top.offset_top = 16
	top.offset_right = -22
	top.offset_bottom = 62
	top.add_theme_constant_override("separation", 16)
	root_control.add_child(top)

	var back := _make_button("BACK")
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)

	progress_label = _make_label("STEP 01 / 11", 11, Color("#E5E0D6"))
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(progress_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 74
	top.add_child(spacer)

	progress_bar = ProgressBar.new()
	progress_bar.anchor_left = 0.16
	progress_bar.anchor_right = 0.84
	progress_bar.anchor_top = 0.0
	progress_bar.anchor_bottom = 0.0
	progress_bar.offset_top = 72
	progress_bar.offset_bottom = 80
	progress_bar.min_value = 0
	progress_bar.max_value = STEP_NAMES.size()
	progress_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#C58A3A")
	fill.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#17191B")
	track.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", track)
	root_control.add_child(progress_bar)

	var body := HBoxContainer.new()
	body.anchor_left = 0.04
	body.anchor_right = 0.96
	body.anchor_top = 0.0
	body.anchor_bottom = 1.0
	body.offset_top = 100
	body.offset_bottom = -94
	body.add_theme_constant_override("separation", 22)
	root_control.add_child(body)

	var preview_column := VBoxContainer.new()
	preview_column.custom_minimum_size.x = 210
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.size_flags_stretch_ratio = 0.82
	preview_column.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_column.add_theme_constant_override("separation", 12)
	body.add_child(preview_column)

	var phone_frame := PanelContainer.new()
	phone_frame.custom_minimum_size = Vector2(150, 320)
	phone_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	phone_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#090A0C")
	frame_style.border_color = Color("#77736D")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(22)
	frame_style.content_margin_left = 8
	frame_style.content_margin_right = 8
	frame_style.content_margin_top = 8
	frame_style.content_margin_bottom = 8
	frame_style.shadow_color = Color(0, 0, 0, 0.42)
	frame_style.shadow_size = 14
	phone_frame.add_theme_stylebox_override("panel", frame_style)
	preview_column.add_child(phone_frame)

	var screen := PanelContainer.new()
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color("#111820")
	screen_style.set_corner_radius_all(15)
	screen.add_theme_stylebox_override("panel", screen_style)
	phone_frame.add_child(screen)

	var preview_stack := VBoxContainer.new()
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_stack.add_theme_constant_override("separation", 12)
	screen.add_child(preview_stack)
	var mark := _make_label("DW", 34, Color("#D3AA6B"))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_stack.add_child(mark)
	var preview_caption := _make_label("OPERATING SYSTEM", 9, Color("#D0CBC2"))
	preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_stack.add_child(preview_caption)
	preview_title = _make_label("DESIGN PREVIEW", 12, Color.WHITE)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_stack.add_child(preview_title)
	preview_detail = _make_label("Your OS workspace preview\nwill appear here.", 9, Color("#A6A096"))
	preview_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview_stack.add_child(preview_detail)

	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.size_flags_stretch_ratio = 1.18
	workspace.add_theme_constant_override("separation", 10)
	body.add_child(workspace)

	heading_label = _make_label("OS SETUP", 22, Color("#D3AA6B"))
	workspace.add_child(heading_label)
	description_label = _make_label("", 11, Color("#D0CBC2"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.add_child(description_label)

	var separator := HSeparator.new()
	workspace.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.get_v_scroll_bar().modulate.a = 0.0
	workspace.add_child(scroll)

	content_column = VBoxContainer.new()
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.add_theme_constant_override("separation", 12)
	scroll.add_child(content_column)

	var footer := HBoxContainer.new()
	footer.anchor_left = 0.04
	footer.anchor_right = 0.96
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -76
	footer.offset_bottom = -18
	footer.add_theme_constant_override("separation", 12)
	root_control.add_child(footer)

	back_step_button = _make_button("PREVIOUS")
	back_step_button.pressed.connect(_previous_step)
	footer.add_child(back_step_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	next_step_button = _make_button("NEXT")
	next_step_button.pressed.connect(_next_step)
	footer.add_child(next_step_button)

func _show_step(step_index: int) -> void:
	current_step = clampi(step_index, 0, STEP_NAMES.size() - 1)
	progress_label.text = "STEP %02d / %02d" % [current_step + 1, STEP_NAMES.size()]
	progress_bar.value = current_step + 1
	heading_label.text = STEP_NAMES[current_step]
	back_step_button.disabled = current_step == 0
	next_step_button.text = "FINISH" if current_step == STEP_NAMES.size() - 1 else "NEXT"
	for child in content_column.get_children():
		content_column.remove_child(child)
		child.queue_free()
	match current_step:
		0:
			description_label.text = "Define the identity of the operating system you are creating."
			_add_field("OPERATING SYSTEM NAME", "MyOS", true)
			_add_field("MANUFACTURER / DEVELOPER", "Your company", false)
			_add_note("This workspace is independent. It does not install or connect an OS to the Phone Creation Worksite.")
		1:
			description_label.text = "Configure the startup identity and boot sequence presentation."
			boot_logo_toggle = CheckButton.new()
			boot_logo_toggle.text = "Show company logo during startup"
			boot_logo_toggle.button_pressed = true
			content_column.add_child(boot_logo_toggle)
			boot_device_toggle = CheckButton.new()
			boot_device_toggle.text = "Show device name and model"
			boot_device_toggle.button_pressed = true
			content_column.add_child(boot_device_toggle)
			_add_note("Bootloader settings are currently design selections only. No boot process or simulator is connected.")
		_:
			description_label.text = "Browse the collected source assets for this OS component. Android XML and vector sources are shown as source files; they are not treated as Godot textures."
			_show_asset_browser(current_step)

func _add_field(caption: String, placeholder: String, is_os_name: bool) -> void:
	var label := _make_label(caption, 9, Color("#D3AA6B"))
	content_column.add_child(label)
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size.y = 42
	field.add_theme_color_override("font_color", Color("#F4F1EA"))
	field.add_theme_color_override("font_placeholder_color", Color("#8F8A80"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17191B")
	style.border_color = Color("#6E5B42")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	field.add_theme_stylebox_override("normal", style)
	content_column.add_child(field)
	if is_os_name:
		os_name_input = field
	else:
		manufacturer_input = field

func _show_asset_browser(step_index: int) -> void:
	var path := str(STEP_ASSET_PATHS.get(step_index, ""))
	var path_label := _make_label(path.replace("res://", ""), 9, Color("#D3AA6B"))
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_column.add_child(path_label)
	var files: Array[String] = []
	_collect_files(path, files)
	files.sort()
	if files.is_empty():
		_add_note("No collected files are present in this category yet. The worksite is ready for the assets when sourcing is complete.")
		return
	for file_path in files:
		var item := _make_button(file_path.trim_prefix(path + "/"))
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
	preview_title.text = "SELECTED SOURCE"
	preview_detail.text = path.replace("res://", "")
	
func _add_note(message: String) -> void:
	var note := _make_label(message, 10, Color("#A6A096"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_column.add_child(note)

func _previous_step() -> void:
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

func _make_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 42)
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#202325")
	normal.border_color = Color("#6E5B42")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	var hover := normal.duplicate()
	hover.bg_color = Color("#30291F")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_color_override("font_hover_color", Color("#F2EDE4"))
	return button
