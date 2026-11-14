extends Node3D

signal back_requested
signal os_selected(configuration: Dictionary)
signal boot_completed

const ProceduralOSEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const OSPreviewSimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")

var generated_os_configuration: Dictionary = {}
var selected_os_component_id := "home_screen"
var current_wizard_step := 1
var os_preview_simulator: Control
var os_component_selector: OptionButton
var os_generation_selector: OptionButton
var os_generation_busy := false

var progress_number: Label
var progress_bar: ProgressBar
var wizard_back_button: Button
var next_button: Button
var navigation_layer: CanvasLayer
var navigation_bar: HBoxContainer
var worksite_body: BoxContainer
var preview_region: Control
var screen_center: CenterContainer
var selection_panel: Control
var configuration_region: Control
var selection_scroll: ScrollContainer
var screen_frame: PanelContainer
var home_preview_screen: PanelContainer
var home_generation := 1
var home_generation_status: Label
var left_power_region: Control
var power_button: Button
var boot_overlay: Control
var boot_stage_container: VBoxContainer
var boot_logo: TextureRect
var boot_message: Label
var boot_model_message: Label
var boot_enabled_inputs: Dictionary = {}
var lock_screen_enabled_inputs: Dictionary = {}
var fingerprint_sensor_available := false
var boot_busy := false
var device_powered_on := false
var boot_identity := {
	"company_name": "YOUR COMPANY",
	"company_logo_id": 1,
	"phone_name": "DigitalWorld Phone",
	"phone_model": "DW-01"
}
var bootloader_settings := {
	"duration_seconds": 10.0,
	"items": {
		"company_logo": {"enabled": true},
		"phone_details": {"enabled": true}
	}
}
class GlassArrowButton extends Button:
	var points_right := true

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		var fill := Color(0.28, 0.20, 0.11, 0.96) if is_hovered() else Color(0.10, 0.11, 0.12, 0.92)
		if is_pressed():
			fill = Color(0.16, 0.11, 0.06, 0.98)
		draw_circle(centre + Vector2(0, 2), radius + 1.0, Color(0, 0, 0, 0.42))
		draw_circle(centre, radius, fill)
		draw_arc(centre, radius - 1.0, PI * 1.08, PI * 1.92, 48, Color(0.94, 0.91, 0.84, 0.78), 1.5, true)
		draw_arc(centre, radius - 1.5, -PI * 0.08, PI * 0.88, 48, Color(0.79, 0.61, 0.35, 0.36), 1.0, true)
		var direction := 1.0 if points_right else -1.0
		var tip := centre + Vector2(direction * 7.0, 0)
		var upper := centre + Vector2(-direction * 4.5, -7.0)
		var lower := centre + Vector2(-direction * 4.5, 7.0)
		draw_line(upper, tip, Color("#F2EDE4"), 2.8, true)
		draw_line(tip, lower, Color("#F2EDE4"), 2.8, true)
		draw_line(centre + Vector2(-direction * 5.0, 0), centre + Vector2(direction * 6.0, 0), Color("#F2EDE4"), 2.8, true)


class GlassCheckbox extends Button:
	func _init() -> void:
		toggle_mode = true
		flat = true
		text = ""
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var empty_style := StyleBoxEmpty.new()
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state_name, empty_style)
		add_theme_color_override("font_color", Color(0, 0, 0, 0))

	func _ready() -> void:
		toggled.connect(_on_toggled)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
		queue_redraw()

	func _on_toggled(_pressed: bool) -> void:
		queue_redraw()

	func _draw() -> void:
		if size.x < 8.0 or size.y < 8.0:
			return
		var box_rect := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
		var box_style := StyleBoxFlat.new()
		box_style.bg_color = Color("#654A2A") if button_pressed else (Color("#25282A") if is_hovered() else Color("#151719"))
		box_style.border_color = Color("#D0A66C") if button_pressed or is_hovered() else Color("#827052")
		box_style.set_border_width_all(1)
		box_style.set_corner_radius_all(6)
		draw_style_box(box_style, box_rect)
		if button_pressed:
			var mark_color := Color("#FFF5E8")
			var mark_start := box_rect.position + Vector2(box_rect.size.x * 0.20, box_rect.size.y * 0.52)
			var mark_corner := box_rect.position + Vector2(box_rect.size.x * 0.43, box_rect.size.y * 0.72)
			var mark_end := box_rect.position + Vector2(box_rect.size.x * 0.80, box_rect.size.y * 0.28)
			draw_line(mark_start, mark_corner, mark_color, 2.4, true)
			draw_line(mark_corner, mark_end, mark_color, 2.4, true)


class GlassButtonReflection extends Control:
	var accent := Color("#C58A3A")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 4.0 or size.y <= 4.0:
			return
		for i in range(48):
			var x0 := size.x * float(i) / 48.0
			var x1 := size.x * float(i + 1) / 48.0
			var mid := (float(i) + 0.5) / 48.0
			var highlight := exp(-pow((mid - 0.34) / 0.29, 2.0))
			draw_line(Vector2(x0, 1.2), Vector2(x1, 1.2), Color(0.97, 1.0, 0.98, 0.09 + 0.30 * highlight), 1.2, true)
		var edge := Color(accent.r, accent.g, accent.b, 0.24)
		draw_line(Vector2(1.2, 9.0), Vector2(1.2, maxf(9.0, size.y - 9.0)), edge, 1.0, true)
		draw_line(Vector2(size.x - 1.2, 9.0), Vector2(size.x - 1.2, maxf(9.0, size.y - 9.0)), edge, 1.0, true)
		draw_line(Vector2(12.0, size.y - 2.0), Vector2(size.x - 12.0, size.y - 2.0), Color(0.82, 0.72, 0.55, 0.10), 1.0, true)


func _ready() -> void:
	generated_os_configuration = ProceduralOSEngineScript.generate_os(-1, home_generation)
	var initial_components: Dictionary = generated_os_configuration.get("components", {})
	var initial_lock_data: Dictionary = initial_components.get("lock_screen", {})
	initial_lock_data["fingerprint_sensor_available"] = fingerprint_sensor_available
	initial_lock_data["show_fingerprint"] = fingerprint_sensor_available
	initial_components["lock_screen"] = initial_lock_data
	generated_os_configuration["components"] = initial_components
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	_build_interface()
	_apply_bootloader_settings_to_configuration()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OSCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	var root := Control.new()
	root.name = "OSWorksiteRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)
	root.resized.connect(_apply_responsive_layout)

	var backdrop := ColorRect.new()
	backdrop.name = "OSWorksiteBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#292B2D")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	# Main content fills the scene directly; controls are independent overlays.
	worksite_body = BoxContainer.new()
	worksite_body.name = "OSWorksiteMainContent"
	worksite_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worksite_body.offset_left = 20.0
	worksite_body.offset_right = -20.0
	worksite_body.offset_top = 4.0
	worksite_body.offset_bottom = -12.0
	worksite_body.add_theme_constant_override("separation", 0)
	root.add_child(worksite_body)

	# Back button is positioned directly on the scene, not inside a top bar.
	var back_button := Button.new()
	back_button.name = "OSWorksiteBackButton"
	back_button.text = "BACK"
	back_button.anchor_left = 0.0
	back_button.anchor_right = 0.0
	back_button.anchor_top = 0.0
	back_button.anchor_bottom = 0.0
	back_button.offset_left = 20.0
	back_button.offset_top = 12.0
	back_button.offset_right = 102.0
	back_button.offset_bottom = 60.0
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button)
	back_button.pressed.connect(func(): back_requested.emit())
	root.add_child(back_button)

	# Progress indicator is independently anchored to the top-center of the scene.
	var progress := VBoxContainer.new()
	progress.name = "OSWorksiteProgress"
	progress.anchor_left = 1.0
	progress.anchor_right = 1.0
	progress.anchor_top = 0.0
	progress.anchor_bottom = 0.0
	progress.offset_left = -170.0
	progress.offset_top = 12.0
	progress.offset_right = -20.0
	progress.offset_bottom = 50.0
	progress.add_theme_constant_override("separation", 4)
	root.add_child(progress)

	progress_number = _label("STEP 1 / 2", 11, Color("#E5E0D6"))
	progress_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

	progress_bar = ProgressBar.new()
	progress_bar.name = "OSWizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = 2
	progress_bar.value = 1
	progress_bar.show_percentage = false
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("#C58A3A")
	progress_fill.set_corner_radius_all(4)
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color("#292D2F")
	progress_track.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_bar.add_theme_stylebox_override("background", progress_track)
	progress.add_child(progress_bar)

	left_power_region = CenterContainer.new()
	left_power_region.name = "OSPowerButtonRegion"
	left_power_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_power_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_power_region.size_flags_stretch_ratio = 0.30
	worksite_body.add_child(left_power_region)
	_build_power_button()

	preview_region = Control.new()
	preview_region.name = "OSScreenPreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.12
	worksite_body.add_child(preview_region)

	screen_center = CenterContainer.new()
	screen_center.name = "OSScreenCenter"
	screen_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_region.add_child(screen_center)

	screen_frame = PanelContainer.new()
	screen_frame.name = "OSPortraitScreenFrame"
	screen_frame.custom_minimum_size = Vector2(148.2, 327.6)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#090A0C")
	frame_style.border_color = Color("#77736D")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(22)
	frame_style.content_margin_left = 7
	frame_style.content_margin_right = 7
	frame_style.content_margin_top = 7
	frame_style.content_margin_bottom = 7
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame_style.shadow_size = 16
	frame_style.shadow_offset = Vector2(0, 5)
	screen_frame.add_theme_stylebox_override("panel", frame_style)
	screen_center.add_child(screen_frame)

	var screen_glass := PanelContainer.new()
	screen_glass.name = "OSPortraitScreen"
	var glass_style := StyleBoxFlat.new()
	glass_style.bg_color = Color("#030405")
	glass_style.set_corner_radius_all(16)
	screen_glass.add_theme_stylebox_override("panel", glass_style)
	screen_glass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_glass.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_frame.add_child(screen_glass)

	home_preview_screen = screen_glass
	_build_home_screen_preview(screen_glass)
	_build_boot_overlay(screen_glass)

	selection_scroll = ScrollContainer.new()
	selection_scroll.name = "OSConfigurationScroll"
	selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var selection_scroll_bar := selection_scroll.get_v_scroll_bar()
	selection_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	selection_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	configuration_region = selection_scroll
	worksite_body.add_child(selection_scroll)

	var right_region := MarginContainer.new()
	right_region.name = "OSConfigurationRegion"
	right_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_region.add_theme_constant_override("margin_left", 24)
	right_region.add_theme_constant_override("margin_right", 24)
	right_region.add_theme_constant_override("margin_top", 20)
	right_region.add_theme_constant_override("margin_bottom", 20)
	selection_scroll.add_child(right_region)

	# Keep the controls directly on the worksite; no surrounding card or panel.
	selection_panel = right_region
	_build_bootloader_controls_only()

	navigation_layer = CanvasLayer.new()
	navigation_layer.name = "OSWorksiteNavigationOverlay"
	navigation_layer.layer = 127
	add_child(navigation_layer)

	var navigation_root := Control.new()
	navigation_root.name = "OSWorksiteNavigationRoot"
	navigation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigation_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_layer.add_child(navigation_root)

	navigation_bar = HBoxContainer.new()
	navigation_bar.name = "OSWorksiteBottomBar"
	navigation_bar.anchor_left = 0.0
	navigation_bar.anchor_right = 1.0
	navigation_bar.anchor_top = 1.0
	navigation_bar.anchor_bottom = 1.0
	navigation_bar.offset_left = 20.0
	navigation_bar.offset_right = -20.0
	navigation_bar.offset_top = -74.0
	navigation_bar.offset_bottom = -12.0
	navigation_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	navigation_bar.z_index = 1000
	navigation_bar.z_as_relative = false
	navigation_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation_bar.add_theme_constant_override("separation", 18)
	navigation_root.add_child(navigation_bar)

	wizard_back_button = GlassArrowButton.new()
	wizard_back_button.name = "OSWizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	navigation_bar.add_child(wizard_back_button)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_bar.add_child(bottom_spacer)

	next_button = GlassArrowButton.new()
	next_button.name = "OSNextStepIconButton"
	next_button.points_right = true
	next_button.pressed.connect(_on_next_pressed)
	navigation_bar.add_child(next_button)

	_apply_responsive_layout()
	_keep_step_navigation_active()


func _build_home_screen_preview(screen: PanelContainer) -> void:
	os_preview_simulator = OSPreviewSimulatorScript.new() as Control
	os_preview_simulator.name = "GeneratedOSPreviewSimulator"
	os_preview_simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	os_preview_simulator.configure_os(generated_os_configuration, selected_os_component_id)
	os_preview_simulator.visible = false
	screen.add_child(os_preview_simulator)

func _build_bootloader_controls_only() -> void:
	for child in selection_panel.get_children():
		selection_panel.remove_child(child)
		child.queue_free()
	var content := VBoxContainer.new()
	content.name = "BootLoaderOnlyControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	selection_panel.add_child(content)
	_build_bootloader_controls(content)


func _show_lock_screen_studio_controls() -> void:
	if not is_instance_valid(selection_panel):
		return
	selected_os_component_id = "lock_screen"
	lock_screen_enabled_inputs.clear()
	for child in selection_panel.get_children():
		selection_panel.remove_child(child)
		child.queue_free()

	var content := VBoxContainer.new()
	content.name = "LockScreenStudioControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	selection_panel.add_child(content)

	var heading := _label("LOCK SCREEN", 21, Color("#D3AA6B"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(heading)
	var description := _label("Choose what appears on the lock screen. Generate changes its visual design without replacing your wallpaper.", 10, Color("#D0CBC2"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(description)

	var clock_note := _label("CLOCK  ·  ALWAYS INCLUDED", 9, Color("#D3AA6B"))
	content.add_child(clock_note)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = Color("#62513A")
	content.add_child(divider)

	_add_lock_screen_toggle_row(content, "show_notifications", "Notifications", "Messages and alerts")
	_add_lock_screen_toggle_row(content, "show_audio_player", "Audio Player", "Playback controls on the lock screen")
	_add_lock_screen_toggle_row(content, "show_camera_shortcut", "Camera Shortcut", "Bottom-left quick button")
	_add_lock_screen_toggle_row(content, "show_flashlight_shortcut", "Flashlight Shortcut", "Bottom-right quick button")
	_add_lock_screen_toggle_row(content, "show_fingerprint", "Fingerprint Sensor", "Available only when the phone has this sensor", not fingerprint_sensor_available)
	_add_lock_screen_toggle_row(content, "show_unlock_hint", "Unlock Prompt", "Show or hide the swipe-to-unlock hint")

	var generator := Button.new()
	generator.name = "GenerateLockScreenDesignButton"
	generator.text = "GENERATE NEW DESIGN"
	generator.custom_minimum_size.y = 40
	generator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator.focus_mode = Control.FOCUS_NONE
	_style_button(generator)
	generator.pressed.connect(_regenerate_selected_component)
	content.add_child(generator)

	var note := _label("Your wallpaper stays exactly the same.", 8, Color("#A6A096"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)


func _add_lock_screen_toggle_row(parent: VBoxContainer, feature_id: String, title_text: String, detail_text: String, unavailable: bool = false) -> void:
	var row := HBoxContainer.new()
	row.name = "LockScreenSettingRow_" + feature_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 1)
	var title := _label(title_text, 11, Color("#E5E0D6"))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	labels.add_child(title)
	var detail := _label(detail_text if not unavailable else "No fingerprint sensor detected on this phone", 7, Color("#A6A096"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	labels.add_child(detail)
	row.add_child(labels)

	var lock_data: Dictionary = generated_os_configuration.get("components", {}).get("lock_screen", {})
	var enabled := GlassCheckbox.new()
	enabled.name = "LockScreenEnabled_" + feature_id
	enabled.button_pressed = bool(lock_data.get(feature_id, false))
	enabled.disabled = unavailable
	enabled.toggled.connect(_on_lock_screen_feature_toggled.bind(feature_id))
	row.add_child(enabled)
	lock_screen_enabled_inputs[feature_id] = enabled


func _on_lock_screen_feature_toggled(enabled: bool, feature_id: String) -> void:
	if feature_id == "show_fingerprint" and not fingerprint_sensor_available:
		if lock_screen_enabled_inputs.has(feature_id):
			(lock_screen_enabled_inputs[feature_id] as Button).set_pressed_no_signal(false)
		return
	var components: Dictionary = generated_os_configuration.get("components", {})
	var lock_data: Dictionary = components.get("lock_screen", {})
	lock_data[feature_id] = enabled
	lock_data["fingerprint_sensor_available"] = fingerprint_sensor_available
	components["lock_screen"] = lock_data
	generated_os_configuration["components"] = components
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.update_configuration(generated_os_configuration)
		os_preview_simulator.set_component_view("lock_screen")


func set_fingerprint_sensor_available(available: bool) -> void:
	fingerprint_sensor_available = available
	var components: Dictionary = generated_os_configuration.get("components", {})
	var lock_data: Dictionary = components.get("lock_screen", {})
	lock_data["fingerprint_sensor_available"] = available
	if not available:
		lock_data["show_fingerprint"] = false
	components["lock_screen"] = lock_data
	generated_os_configuration["components"] = components
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	if device_powered_on:
		_show_lock_screen_studio_controls()
		if is_instance_valid(os_preview_simulator):
			os_preview_simulator.update_configuration(generated_os_configuration)
			os_preview_simulator.set_component_view("lock_screen")


func _build_power_button() -> void:
	var column := VBoxContainer.new()
	column.name = "PowerButtonColumn"
	column.add_theme_constant_override("separation", 8)
	left_power_region.add_child(column)
	var caption := _label("POWER", 9, Color("#C58A3A"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	power_button = Button.new()
	power_button.name = "OSPowerButton"
	power_button.text = "⏻"
	power_button.custom_minimum_size = Vector2(66, 66)
	power_button.focus_mode = Control.FOCUS_NONE
	power_button.add_theme_font_size_override("font_size", 34)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#111416")
	normal.border_color = Color("#9C7847")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(34)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2B241A")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#49351D")
	power_button.add_theme_stylebox_override("normal", normal)
	power_button.add_theme_stylebox_override("hover", hover)
	power_button.add_theme_stylebox_override("pressed", pressed)
	power_button.add_theme_color_override("font_color", Color("#E8D2AD"))
	power_button.pressed.connect(_on_power_button_pressed)
	column.add_child(power_button)
	var hint := _label("PRESS TO START", 7, Color("#8F8B84"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_boot_overlay(screen: PanelContainer) -> void:
	boot_overlay = Control.new()
	boot_overlay.name = "OSBootLoaderOverlay"
	boot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot_overlay.visible = false
	boot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(boot_overlay)
	var background := ColorRect.new()
	background.name = "BootLoaderBlackout"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#030405")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot_overlay.add_child(background)
	var stage_margin := MarginContainer.new()
	stage_margin.name = "BootStageMargin"
	stage_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_margin.add_theme_constant_override("margin_left", 10)
	stage_margin.add_theme_constant_override("margin_right", 10)
	stage_margin.add_theme_constant_override("margin_top", 10)
	stage_margin.add_theme_constant_override("margin_bottom", 10)
	stage_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot_overlay.add_child(stage_margin)
	boot_stage_container = VBoxContainer.new()
	boot_stage_container.name = "BootLoaderStage"
	boot_stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boot_stage_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	boot_stage_container.alignment = BoxContainer.ALIGNMENT_CENTER
	boot_stage_container.add_theme_constant_override("separation", 8)
	boot_stage_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_margin.add_child(boot_stage_container)
	boot_logo = TextureRect.new()
	boot_logo.name = "BootCompanyLogo"
	boot_logo.custom_minimum_size = Vector2(64, 64)
	boot_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	boot_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boot_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boot_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boot_stage_container.add_child(boot_logo)
	boot_message = _label("", 18, Color("#FFFFFF"))
	boot_message.name = "BootIdentityText"
	var boot_identity_font := FontVariation.new()
	boot_identity_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	boot_identity_font.variation_embolden = 1.5
	boot_message.add_theme_font_override("font", boot_identity_font)
	boot_message.add_theme_font_size_override("font_size", 18)
	boot_message.add_theme_color_override("font_color", Color("#FFFFFF"))
	boot_message.custom_minimum_size = Vector2(0, 54)
	boot_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boot_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boot_message.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boot_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boot_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	boot_stage_container.add_child(boot_message)
	boot_model_message = _label("", 15, Color("#D8D2C8"))
	boot_model_message.name = "BootModelText"
	boot_model_message.custom_minimum_size = Vector2(0, 26)
	var boot_model_font := FontVariation.new()
	boot_model_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	boot_model_font.variation_embolden = 1.0
	boot_model_message.add_theme_font_override("font", boot_model_font)
	boot_model_message.add_theme_font_size_override("font_size", 15)
	boot_model_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_model_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boot_model_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boot_model_message.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boot_model_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boot_model_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	boot_stage_container.add_child(boot_model_message)
	boot_message.visible = false
	boot_model_message.visible = false
	boot_stage_container.modulate.a = 0.0
	boot_logo.texture = _get_boot_company_logo_texture()


func _build_bootloader_controls(parent: VBoxContainer) -> void:
	parent.add_theme_constant_override("separation", 16)
	var heading := _label("BOOT LOADER", 22, Color("#D3AA6B"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)
	var description := _label("Choose which startup details appear when your phone powers on.", 14, Color("#E5E0D6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(description)
	var rows := [
		["company_logo", "Company Logo"],
		["phone_details", "Phone Details"]
	]
	for row_data in rows:
		var item_id := str(row_data[0])
		var row := HBoxContainer.new()
		row.name = "BootSettingRow_" + item_id
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)
		var item_label := _label(str(row_data[1]), 16, Color("#E5E0D6"))
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(item_label)
		var enabled := GlassCheckbox.new()
		enabled.name = "BootEnabled_" + item_id
		enabled.button_pressed = bool(bootloader_settings["items"][item_id]["enabled"])
		enabled.toggled.connect(_on_boot_item_toggled.bind(item_id))
		row.add_child(enabled)
		boot_enabled_inputs[item_id] = enabled
	var divider := ColorRect.new()
	divider.name = "BootLoaderControlsDivider"
	divider.custom_minimum_size.y = 1
	divider.color = Color("#62513A")
	parent.add_child(divider)


func _on_boot_item_toggled(enabled: bool, item_id: String) -> void:
	var items: Dictionary = bootloader_settings["items"]
	if not enabled:
		var enabled_count := 0
		for other_id in items:
			if other_id != item_id and bool(items[other_id]["enabled"]):
				enabled_count += 1
		if enabled_count == 0:
			(boot_enabled_inputs[item_id] as Button).set_pressed_no_signal(true)
			return
	items[item_id]["enabled"] = enabled
	_apply_bootloader_settings_to_configuration()


func _apply_bootloader_settings_to_configuration() -> void:
	bootloader_settings["duration_seconds"] = 10.0
	generated_os_configuration["bootloader"] = bootloader_settings.duplicate(true)
	generated_os_configuration["boot_identity"] = boot_identity.duplicate(true)


func set_boot_identity(company_name: String, logo_id: int, phone_name: String = "DigitalWorld Phone", phone_model: String = "DW-01") -> void:
	boot_identity["company_name"] = company_name.strip_edges() if not company_name.strip_edges().is_empty() else "YOUR COMPANY"
	boot_identity["company_logo_id"] = clampi(logo_id, 1, 50)
	boot_identity["phone_name"] = phone_name.strip_edges() if not phone_name.strip_edges().is_empty() else "DigitalWorld Phone"
	boot_identity["phone_model"] = phone_model.strip_edges() if not phone_model.strip_edges().is_empty() else "DW-01"
	if is_instance_valid(boot_logo):
		boot_logo.texture = _get_boot_company_logo_texture()
	if is_instance_valid(boot_message):
		boot_message.text = str(boot_identity["phone_name"])
	if is_instance_valid(boot_model_message):
		boot_model_message.text = str(boot_identity["phone_model"])
	_apply_bootloader_settings_to_configuration()


func _get_boot_company_logo_texture() -> Texture2D:
	var atlas := load("res://assets/company_logos.svg") as Texture2D
	if not is_instance_valid(atlas):
		return null
	var logo_index := clampi(int(boot_identity["company_logo_id"]), 1, 50) - 1
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(float(logo_index % 10) * 100.0, floorf(float(logo_index) / 10.0) * 100.0), Vector2(100.0, 100.0))
	return texture


func _on_power_button_pressed() -> void:
	if boot_busy:
		return
	_run_boot_sequence()


func _run_boot_sequence() -> void:
	if boot_busy or not is_instance_valid(boot_overlay):
		return
	boot_busy = true
	var started_at := Time.get_ticks_msec()
	device_powered_on = false
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.visible = false
	boot_overlay.visible = true
	boot_overlay.modulate.a = 1.0
	boot_message.visible = false
	boot_model_message.visible = false
	boot_stage_container.modulate.a = 1.0
	var ordered_items: Array[String] = []
	var item_settings: Dictionary = bootloader_settings["items"]
	# Startup order is fixed: company logo always precedes phone details.
	for item_id in ["company_logo", "phone_details"]:
		if bool(item_settings.get(item_id, {}).get("enabled", false)):
			ordered_items.append(item_id)
	var stage_duration := 10.0 / float(maxi(1, ordered_items.size()))
	for item_id in ordered_items:
		boot_stage_container.modulate.a = 1.0
		boot_logo.visible = item_id == "company_logo"
		boot_message.visible = item_id == "phone_details"
		boot_model_message.visible = item_id == "phone_details"
		if item_id == "company_logo":
			boot_logo.texture = _get_boot_company_logo_texture()
			boot_logo.modulate.a = 1.0
			boot_message.text = ""
			boot_model_message.text = ""
		elif item_id == "phone_details":
			boot_message.text = str(boot_identity["phone_name"])
			boot_model_message.text = str(boot_identity["phone_model"])
			boot_message.modulate.a = 1.0
			boot_model_message.modulate.a = 1.0
		await get_tree().create_timer(stage_duration).timeout
	var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
	if elapsed < 10.0:
		await get_tree().create_timer(10.0 - elapsed).timeout
	boot_overlay.visible = false
	boot_message.visible = true
	boot_busy = false
	device_powered_on = true
	selected_os_component_id = "lock_screen"
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.visible = true
		os_preview_simulator.set_component_view("lock_screen")
	_set_wizard_step(2)
	boot_completed.emit()

func _on_os_generation_selected(index: int) -> void:
	home_generation = clampi(index + 1, 1, 3)
	_set_os_generation_status("GENERATION %02d SELECTED" % home_generation)

func _on_os_component_selected(index: int) -> void:
	if index < 0 or index >= ProceduralOSEngineScript.COMPONENTS.size():
		return
	selected_os_component_id = str(ProceduralOSEngineScript.COMPONENTS[index]["id"])
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.set_component_view(selected_os_component_id)

func _generate_complete_os() -> void:
	if os_generation_busy:
		return
	os_generation_busy = true
	_set_os_generation_status("GENERATING OPERATING SYSTEM...")
	generated_os_configuration = ProceduralOSEngineScript.generate_os(-1, home_generation)
	var generated_components: Dictionary = generated_os_configuration.get("components", {})
	var generated_lock_data: Dictionary = generated_components.get("lock_screen", {})
	generated_lock_data["fingerprint_sensor_available"] = fingerprint_sensor_available
	generated_lock_data["show_fingerprint"] = fingerprint_sensor_available
	generated_components["lock_screen"] = generated_lock_data
	generated_os_configuration["components"] = generated_components
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	_apply_bootloader_settings_to_configuration()
	var components: Dictionary = generated_os_configuration.get("components", {})
	if components.size() != ProceduralOSEngineScript.COMPONENTS.size():
		push_error("OS generator returned an incomplete configuration.")
		_set_os_generation_status("GENERATION FAILED · TRY AGAIN")
		os_generation_busy = false
		return
	if not is_instance_valid(os_preview_simulator):
		if is_instance_valid(home_preview_screen):
			_build_home_screen_preview(home_preview_screen)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.visible = device_powered_on
		os_preview_simulator.configure_os(generated_os_configuration, selected_os_component_id)
		os_preview_simulator.set_component_view(selected_os_component_id)
		if device_powered_on and selected_os_component_id == "lock_screen":
			_show_lock_screen_studio_controls()
	else:
		push_error("Generated OS preview simulator is not mounted in the phone screen.")
		_set_os_generation_status("PREVIEW FAILED · REOPEN OS WORKSITE")
		os_generation_busy = false
		return
	if is_instance_valid(progress_bar):
		progress_bar.value = 1.0
	_set_os_generation_status("GENERATED · %s · 6 CORE COMPONENTS READY" % str(generated_os_configuration.get("name", "NEW OS")))
	os_generation_busy = false

func _regenerate_selected_component() -> void:
	if generated_os_configuration.is_empty():
		return
	generated_os_configuration = ProceduralOSEngineScript.regenerate_component(generated_os_configuration, selected_os_component_id)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.update_configuration(generated_os_configuration)
		os_preview_simulator.set_component_view(selected_os_component_id)
	_set_os_generation_status("%s REGENERATED" % selected_os_component_id.replace("_", " ").to_upper())
func _select_generated_os() -> void:
	_apply_bootloader_settings_to_configuration()
	if generated_os_configuration.is_empty():
		_set_os_generation_status("GENERATE AN OS BEFORE SELECTING")
		return
	if not ProceduralOSEngineScript.save_os(generated_os_configuration, "user://digitalworld_selected_os.json"):
		_set_os_generation_status("COULD NOT SAVE OS CONFIGURATION")
		return
	os_selected.emit(generated_os_configuration.duplicate(true))
	_set_os_generation_status("OS SELECTED AND SAVED")

func _set_os_generation_status(message: String) -> void:
	if is_instance_valid(home_generation_status):
		home_generation_status.text = message

func _apply_responsive_layout() -> void:
	if not is_instance_valid(worksite_body) or not is_instance_valid(preview_region) or not is_instance_valid(selection_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var is_wide := viewport_size.x >= viewport_size.y and viewport_size.x >= 560.0
	worksite_body.vertical = not is_wide
	var screen_height: float
	if is_wide:
		left_power_region.size_flags_stretch_ratio = 0.30
		preview_region.size_flags_stretch_ratio = 1.12
		screen_center.offset_left = -190.0
		screen_center.offset_right = 10.0
		selection_scroll.size_flags_stretch_ratio = 0.88
		selection_scroll.custom_minimum_size = Vector2(280, 0)
		_set_right_region_margins(24, 24, 20, 20)
		preview_region.custom_minimum_size = Vector2(0, 0)
		screen_height = clampf(viewport_size.y - 28.0, 250.0, 760.0)
	else:
		left_power_region.size_flags_stretch_ratio = 0.18
		preview_region.size_flags_stretch_ratio = 0.82
		screen_center.offset_left = -104.0
		screen_center.offset_right = 16.0
		selection_scroll.size_flags_stretch_ratio = 1.18
		selection_scroll.custom_minimum_size = Vector2(0, maxf(300.0, viewport_size.y * 0.52))
		_set_right_region_margins(20, 20, 14, 14)
		preview_region.custom_minimum_size = Vector2(0, maxf(140.0, viewport_size.y * 0.24))
		screen_height = clampf(viewport_size.y * 0.34, 210.0, 420.0)
	# The preview always represents a portrait handset, regardless of worksite orientation.
	screen_frame.custom_minimum_size = Vector2(screen_height * 0.49, screen_height)


func _set_right_region_margins(left: int, right: int, top: int, bottom: int) -> void:
	var region := selection_scroll.get_child(0) as MarginContainer
	if not is_instance_valid(region):
		return
	region.add_theme_constant_override("margin_left", left)
	region.add_theme_constant_override("margin_right", right)
	region.add_theme_constant_override("margin_top", top)
	region.add_theme_constant_override("margin_bottom", bottom)


func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	font.variation_embolden = 0.7
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#17191B")
	normal.border_color = Color("#8D7048")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#30271D")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#211B14")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_font_size_override("font_size", 13)


func _set_wizard_step(step: int) -> void:
	current_wizard_step = clampi(step, 1, 2)
	if current_wizard_step == 1:
		_build_bootloader_controls_only()
	else:
		if not device_powered_on:
			current_wizard_step = 1
			_build_bootloader_controls_only()
		else:
			selected_os_component_id = "lock_screen"
			if is_instance_valid(os_preview_simulator):
				os_preview_simulator.visible = true
				os_preview_simulator.set_component_view("lock_screen")
			_show_lock_screen_studio_controls()
	if is_instance_valid(progress_number):
		progress_number.text = "STEP %d / 2" % current_wizard_step
	if is_instance_valid(progress_bar):
		progress_bar.max_value = 2
		progress_bar.value = current_wizard_step
	_keep_step_navigation_active()


func _keep_step_navigation_active() -> void:
	if is_instance_valid(navigation_layer):
		navigation_layer.layer = 127
	if is_instance_valid(navigation_bar):
		navigation_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		navigation_bar.z_index = 1000
		navigation_bar.z_as_relative = false
	if is_instance_valid(wizard_back_button):
		wizard_back_button.disabled = current_wizard_step <= 1
		wizard_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
		wizard_back_button.modulate.a = 0.42 if wizard_back_button.disabled else 1.0
	if is_instance_valid(next_button):
		next_button.disabled = current_wizard_step >= 2 or not device_powered_on
		next_button.mouse_filter = Control.MOUSE_FILTER_STOP
		next_button.modulate.a = 0.42 if next_button.disabled else 1.0


func _on_wizard_back_pressed() -> void:
	_set_wizard_step(1)


func _on_next_pressed() -> void:
	if current_wizard_step == 1 and device_powered_on:
		_set_wizard_step(2)
