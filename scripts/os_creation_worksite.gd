extends Node3D

signal back_requested
signal os_selected(configuration: Dictionary)
signal boot_completed

const ProceduralOSEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const OSPreviewSimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")
const MAX_SELECTABLE_GENERATION := 4
const CUSTOMIZATION_COMPONENTS := ["lock_screen", "home_screen", "app_drawer", "control_center", "notifications", "wallpapers"]
const WIZARD_STEP_COUNT := 8

var generated_os_configuration: Dictionary = {}
var selected_os_component_id := "home_screen"
var current_wizard_step := 1
var home_screen_layout_level := 0
var home_screen_corner_radius := 0
var home_screen_layout_decrease_button: Button
var home_screen_layout_increase_button: Button
var home_screen_layout_value_label: Label
var home_screen_layout_family_label: Label
var android_ui_family_selector: OptionButton
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
var home_generation := 2
var generation_decrease_button: Button
var generation_increase_button: Button
var generation_value_label: Label
var generation_description_label: Label
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
		custom_minimum_size = Vector2(40, 40)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		var box_side := maxf(8.0, minf(size.x, size.y) - 6.0)
		var box_position := (size - Vector2.ONE * box_side) * 0.5
		var box_rect := Rect2(box_position, Vector2.ONE * box_side)
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

	progress_number = _label("STEP 1 / %d" % WIZARD_STEP_COUNT, 11, Color("#E5E0D6"))
	progress_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

	progress_bar = ProgressBar.new()
	progress_bar.name = "OSWizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = WIZARD_STEP_COUNT
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
	left_power_region.visible = false

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
	_build_os_selection_controls()

	# Bottom navigation uses the same direct-root approach as the top controls.
	# Each arrow owns only its own hit rectangle; there is no full-width overlay.
	wizard_back_button = GlassArrowButton.new()
	wizard_back_button.name = "OSWizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.anchor_left = 0.0
	wizard_back_button.anchor_right = 0.0
	wizard_back_button.anchor_top = 1.0
	wizard_back_button.anchor_bottom = 1.0
	wizard_back_button.offset_left = 20.0
	wizard_back_button.offset_top = -74.0
	wizard_back_button.offset_right = 74.0
	wizard_back_button.offset_bottom = -20.0
	wizard_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	root.add_child(wizard_back_button)

	next_button = GlassArrowButton.new()
	next_button.name = "OSNextStepIconButton"
	next_button.points_right = true
	next_button.anchor_left = 1.0
	next_button.anchor_right = 1.0
	next_button.anchor_top = 1.0
	next_button.anchor_bottom = 1.0
	next_button.offset_left = -74.0
	next_button.offset_top = -74.0
	next_button.offset_right = -20.0
	next_button.offset_bottom = -20.0
	next_button.mouse_filter = Control.MOUSE_FILTER_STOP
	next_button.pressed.connect(_on_next_pressed)
	root.add_child(next_button)

	_apply_responsive_layout()
	_keep_step_navigation_active()


func _build_home_screen_preview(screen: PanelContainer) -> void:
	os_preview_simulator = OSPreviewSimulatorScript.new() as Control
	os_preview_simulator.name = "GeneratedOSPreviewSimulator"
	os_preview_simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	os_preview_simulator.configure_os(generated_os_configuration, selected_os_component_id)
	os_preview_simulator.visible = false
	screen.add_child(os_preview_simulator)

func _build_os_selection_controls() -> void:
	_clear_selection_controls()
	var content := VBoxContainer.new()
	content.name = "OSSelectionControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 12)
	selection_panel.add_child(content)

	var heading := _label("SELECT LAYOUT & GENERATION", 20, Color("#D3AA6B"))
	heading.name = "OSSelectionHeroTitle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var description := _label("Choose the operating-system family and the generation you want to build.", 12, Color("#D0CBC2"))
	description.name = "OSSelectionHeroDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)

	var layout_gap := Control.new()
	layout_gap.custom_minimum_size.y = 24
	content.add_child(layout_gap)

	home_screen_layout_decrease_button = Button.new()
	home_screen_layout_decrease_button.name = "DecreaseHomeScreenLayoutButton"
	home_screen_layout_decrease_button.text = "−"
	home_screen_layout_decrease_button.custom_minimum_size = Vector2(56, 48)
	home_screen_layout_decrease_button.focus_mode = Control.FOCUS_NONE
	_style_button(home_screen_layout_decrease_button)
	home_screen_layout_decrease_button.pressed.connect(_on_home_screen_layout_decrease_pressed)

	home_screen_layout_value_label = _label("LAYOUT 1", 19, Color.WHITE)
	home_screen_layout_value_label.name = "HomeScreenLayoutValueLabel"
	home_screen_layout_value_label.custom_minimum_size.x = 170
	home_screen_layout_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	home_screen_layout_increase_button = Button.new()
	home_screen_layout_increase_button.name = "IncreaseHomeScreenLayoutButton"
	home_screen_layout_increase_button.text = "+"
	home_screen_layout_increase_button.custom_minimum_size = Vector2(56, 48)
	home_screen_layout_increase_button.focus_mode = Control.FOCUS_NONE
	_style_button(home_screen_layout_increase_button)
	home_screen_layout_increase_button.pressed.connect(_on_home_screen_layout_increase_pressed)

	var layout_selector := HBoxContainer.new()
	layout_selector.name = "HomeScreenLayoutSelector"
	layout_selector.alignment = BoxContainer.ALIGNMENT_CENTER
	layout_selector.add_theme_constant_override("separation", 14)
	layout_selector.add_child(home_screen_layout_decrease_button)
	layout_selector.add_child(home_screen_layout_value_label)
	layout_selector.add_child(home_screen_layout_increase_button)
	content.add_child(layout_selector)

	home_screen_layout_family_label = _label("ANDROID", 10, Color("#D3AA6B"))
	home_screen_layout_family_label.name = "HomeScreenLayoutFamilyLabel"
	home_screen_layout_family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(home_screen_layout_family_label)

	var ui_family_heading := _label("ANDROID UI FAMILY", 10, Color("#D3AA6B"))
	ui_family_heading.name = "AndroidUIFamilyHeading"
	ui_family_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(ui_family_heading)
	android_ui_family_selector = OptionButton.new()
	android_ui_family_selector.name = "AndroidUIFamilySelector"
	android_ui_family_selector.custom_minimum_size = Vector2(260, 42)
	android_ui_family_selector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	android_ui_family_selector.item_selected.connect(_on_android_ui_family_selected)
	content.add_child(android_ui_family_selector)

	var generation_gap := Control.new()
	generation_gap.custom_minimum_size.y = 18
	content.add_child(generation_gap)

	generation_decrease_button = Button.new()
	generation_decrease_button.name = "DecreaseOSGenerationButton"
	generation_decrease_button.text = "−"
	generation_decrease_button.custom_minimum_size = Vector2(56, 48)
	generation_decrease_button.focus_mode = Control.FOCUS_NONE
	_style_button(generation_decrease_button)
	generation_decrease_button.pressed.connect(_on_generation_decrease_pressed)

	generation_value_label = _label("GENERATION 02", 17, Color.WHITE)
	generation_value_label.name = "OSGenerationValueLabel"
	generation_value_label.custom_minimum_size.x = 190
	generation_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	generation_increase_button = Button.new()
	generation_increase_button.name = "IncreaseOSGenerationButton"
	generation_increase_button.text = "+"
	generation_increase_button.custom_minimum_size = Vector2(56, 48)
	generation_increase_button.focus_mode = Control.FOCUS_NONE
	_style_button(generation_increase_button)
	generation_increase_button.pressed.connect(_on_generation_increase_pressed)

	var generation_selector := HBoxContainer.new()
	generation_selector.name = "OSGenerationSelector"
	generation_selector.alignment = BoxContainer.ALIGNMENT_CENTER
	generation_selector.add_theme_constant_override("separation", 14)
	generation_selector.add_child(generation_decrease_button)
	generation_selector.add_child(generation_value_label)
	generation_selector.add_child(generation_increase_button)
	content.add_child(generation_selector)

	generation_description_label = _label("ANDROID 7.0 NOUGAT", 11, Color("#D3AA6B"))
	generation_description_label.name = "OSGenerationDescription"
	generation_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(generation_description_label)

	var note := _label("Gen 1 · Android 4.x    Gen 2 · Android 7 Nougat    Gen 3 · Android 9 Pie    Gen 4 · Android 10 One UI 2.0", 10, Color("#A6A096"))
	note.name = "OSSelectionGenerationNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	_refresh_home_screen_layout_selector()


func _clear_selection_controls() -> void:
	if not is_instance_valid(selection_panel):
		return
	for child in selection_panel.get_children():
		selection_panel.remove_child(child)
		child.queue_free()


func _build_bootloader_controls_only() -> void:
	_clear_selection_controls()
	var content := VBoxContainer.new()
	content.name = "BootLoaderOnlyControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 14)
	selection_panel.add_child(content)
	_build_bootloader_controls(content)


func _show_lock_screen_studio_controls() -> void:
	if not is_instance_valid(selection_panel):
		return
	selected_os_component_id = "lock_screen"
	lock_screen_enabled_inputs.clear()
	_clear_selection_controls()

	var content := VBoxContainer.new()
	content.name = "LockScreenStudioControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	selection_panel.add_child(content)

	var selected_ui_family := str(generated_os_configuration.get("style", {}).get("ui_family", "samsung_touchwiz"))
	var is_gen1_samsung_android := home_screen_layout_level == 0 and home_generation == 1 and selected_ui_family == "samsung_touchwiz"
	var is_gen1_pixel_android := home_screen_layout_level == 0 and home_generation == 1 and selected_ui_family == "google_stock"
	var is_gen1_xiaomi_android := home_screen_layout_level == 0 and home_generation == 1 and selected_ui_family == "xiaomi_miui"
	var is_oreo_android := home_screen_layout_level == 0 and home_generation == 2
	var is_pie_android := home_screen_layout_level == 0 and home_generation == 3
	var is_samsung_one_ui_android := home_screen_layout_level == 0 and home_generation == 4
	var heading_text := "SAMSUNG TOUCHWIZ NATURE UX · ANDROID 4.x LOCK SCREEN" if is_gen1_samsung_android else "GOOGLE STOCK ANDROID 4.0 ICE CREAM SANDWICH · LOCK SCREEN" if is_gen1_pixel_android else "XIAOMI MIUI · ANDROID 4.0 ERA LOCK SCREEN" if is_gen1_xiaomi_android else "SAMSUNG ONE UI 2.0 · ANDROID 10 LOCK SCREEN" if is_samsung_one_ui_android else "ANDROID 9.0 PIE LOCK SCREEN" if is_pie_android else "ANDROID 8.0 OREO LOCK SCREEN" if is_oreo_android else "LOCK SCREEN" if home_screen_layout_level == 0 else "LOCK SCREEN"
	var heading := _label(heading_text, 20, Color("#D3AA6B"))
	heading.name = "LockScreenHeroTitle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var description_text := "Galaxy S III TouchWiz Nature UX lock screen. Swipe right to unlock and tap the Phone or Camera shortcut." if is_gen1_samsung_android else "Stock Android 4.0 Ice Cream Sandwich lock-screen reference displayed edge-to-edge." if is_gen1_pixel_android else "Xiaomi MIUI is a separate Gen 1 family; its reference art is pending upload." if is_gen1_xiaomi_android else "Samsung One UI 2.0 lock screen. Configure adaptive time/date, compact notifications and Phone/Camera shortcuts." if is_samsung_one_ui_android else "Android 9 Pixel lock screen. Configure rounded notifications, weather and shortcuts." if is_pie_android else "Pixel 2 lock screen. Configure the clock, notifications and bottom shortcuts." if is_oreo_android else "Preview the selected layout's lock screen."
	var description := _label(description_text, 12, Color("#D0CBC2"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)
	if is_gen1_samsung_android:
		var screenshot_note := _label("TouchWiz screen artwork is fixed to the uploaded Galaxy S III reference. Swipe right anywhere on the lock screen to unlock; tap Phone or Camera at the bottom to launch it.", 11, Color("#A6A096"))
		screenshot_note.name = "SamsungGen1LockScreenInteractionNote"
		screenshot_note.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(screenshot_note)
		return

	if is_gen1_pixel_android:
		var pixel_note := _label("The imported Android 4.0 Ice Cream Sandwich lock-screen reference is displayed edge-to-edge.", 11, Color("#A6A096"))
		pixel_note.name = "PixelGen1LockScreenReferenceNote"
		pixel_note.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(pixel_note)
		return

	var hero_gap := Control.new()
	hero_gap.name = "LockScreenHeroGap"
	hero_gap.custom_minimum_size = Vector2(0, 22)
	content.add_child(hero_gap)

	_add_lock_screen_toggle_row(content, "show_time", "Display Time", "Large clock on the lock screen")
	_add_lock_screen_toggle_row(content, "show_date", "Display Date", "Date below the clock")
	if is_samsung_one_ui_android:
		_add_lock_screen_toggle_row(content, "show_notifications", "Lock-screen Notifications", "Compact notifications below the date")
		_add_lock_screen_toggle_row(content, "show_phone_shortcut", "Phone Shortcut", "Green Phone shortcut at bottom-left")
		_add_lock_screen_toggle_row(content, "show_camera_shortcut", "Camera Shortcut", "Red Camera shortcut at bottom-right")
	elif is_oreo_android or is_pie_android:
		_add_lock_screen_toggle_row(content, "show_notifications", "Lock-screen Notifications", "Notification cards below the clock")
		_add_lock_screen_toggle_row(content, "show_assistant_shortcut", "Assistant Shortcut", "Assistant shortcut at bottom-left")
		_add_lock_screen_toggle_row(content, "show_camera_shortcut", "Camera Shortcut", "Camera shortcut at bottom-right")
		if is_pie_android:
			_add_lock_screen_toggle_row(content, "show_weather", "Ambient Weather", "Weather information on the lock screen")
			_add_lock_screen_toggle_row(content, "show_battery", "Ambient Battery", "Battery percentage on the lock screen")
	elif home_screen_layout_level == 0:
		_add_lock_screen_toggle_row(content, "show_camera_shortcut", "Camera Button", "Bottom-left shortcut")
		_add_lock_screen_toggle_row(content, "show_flashlight_shortcut", "Flashlight Button", "Bottom-right shortcut")
	else:
		var preview_note := _label("This layout's lock-screen controls will be expanded in its generation-specific design pass.", 11, Color("#A6A096"))
		preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(preview_note)


func _show_component_studio_controls(component_id: String) -> void:
	if not is_instance_valid(selection_panel):
		return
	selected_os_component_id = component_id
	_clear_selection_controls()
	var content := VBoxContainer.new()
	content.name = "ComponentStudioControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	selection_panel.add_child(content)
	var titles := {
		"app_drawer": "APP DRAWER",
		"control_center": "CONTROL CENTER",
		"notifications": "NOTIFICATION PANEL",
		"wallpapers": "WALLPAPERS"
	}
	var descriptions := {
		"app_drawer": "Choose how installed apps are organised and searched.",
		"control_center": "Adjust the quick-settings tile layout and brightness control.",
		"notifications": "Choose how notification cards are displayed.",
		"wallpapers": "Choose the system wallpaper and its visual treatment."
	}
	var heading := _label(str(titles.get(component_id, "OS COMPONENT")), 20, Color("#D3AA6B"))
	heading.name = "ComponentStudioHeroTitle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var description := _label(str(descriptions.get(component_id, "Customize this OS component.")), 12, Color("#D0CBC2"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)
	if home_screen_layout_level == 0 and home_generation == 1 and component_id in ["app_drawer", "control_center", "notifications"]:
		var selected_ui_family := str(generated_os_configuration.get("style", {}).get("ui_family", "samsung_touchwiz"))
		var screenshot_note_text := "The TouchWiz app drawer is displayed from the uploaded Galaxy S III screenshot. Tap an app to open it; use Back or Home to return." if component_id == "app_drawer" else "TouchWiz combines Quick Settings and notifications in one pull-down panel. Swipe down from the top edge to open it and swipe up to dismiss it."
		if selected_ui_family == "google_stock":
			screenshot_note_text = "The Android 4.0 Ice Cream Sandwich " + str(titles.get(component_id, "screen")).to_lower() + " is displayed from its imported reference image."
		var screenshot_note := _label(screenshot_note_text, 11, Color("#A6A096"))
		screenshot_note.name = ("PixelGen1" if selected_ui_family == "google_stock" else "SamsungGen1") + component_id.capitalize() + "ScreenshotNote"
		screenshot_note.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(screenshot_note)
		return

	var component_data: Dictionary = generated_os_configuration.get("components", {}).get(component_id, {})
	match component_id:
		"app_drawer":
			_add_component_option_row(content, "AppDrawerLayoutSelector", component_id, "layout", "APP ORGANISATION", ["alphabetical", "categories", "frequent_first"], component_data.get("layout", "alphabetical"))
			_add_component_option_row(content, "AppDrawerSearchPositionSelector", component_id, "search_position", "SEARCH POSITION", ["top", "bottom"], component_data.get("search_position", "top"))
			_add_component_option_row(content, "AppDrawerScrollDirectionSelector", component_id, "scroll_direction", "SCROLL DIRECTION", ["vertical", "horizontal"], component_data.get("scroll_direction", "vertical"))
			_add_component_option_row(content, "AppDrawerColumnsSelector", component_id, "columns", "GRID COLUMNS", [3, 4, 5], component_data.get("columns", 4))
		"control_center":
			_add_component_option_row(content, "ControlCenterTileShapeSelector", component_id, "tile_shape", "TILE SHAPE", ["rounded", "pill"], component_data.get("tile_shape", "rounded"))
			_add_component_option_row(content, "ControlCenterTileLayoutSelector", component_id, "tile_layout", "TILE DENSITY", ["compact", "expanded"], component_data.get("tile_layout", "compact"))
			_add_component_option_row(content, "ControlCenterBrightnessSelector", component_id, "brightness_style", "BRIGHTNESS CONTROL", ["bar", "slider"], component_data.get("brightness_style", "bar"))
		"notifications":
			_add_component_option_row(content, "NotificationCardStyleSelector", component_id, "card_style", "CARD STYLE", ["compact", "grouped", "expanded"], component_data.get("card_style", "compact"))
			_add_component_toggle_row(content, component_id, "show_app_icon", "Show app icons", bool(component_data.get("show_app_icon", true)))
			_add_component_toggle_row(content, component_id, "translucent", "Translucent cards", bool(component_data.get("translucent", false)))
			_add_component_slider_row(content, "NotificationCornerRadiusSlider", component_id, "corner_radius", "CORNER RADIUS", float(component_data.get("corner_radius", 16)), 0.0, 24.0, 1.0)
		"wallpapers":
			_add_component_option_row(content, "WallpaperStyleSelector", component_id, "style", "WALLPAPER", ProceduralOSEngineScript.WALLPAPER_STYLES, component_data.get("style", "aurora"))
			_add_component_option_row(content, "WallpaperTreatmentSelector", component_id, "treatment", "TREATMENT", ["natural", "soft_glow", "deep_contrast"], component_data.get("treatment", "natural"))

	var refresh_button := Button.new()
	refresh_button.name = "RegenerateComponentPreviewButton"
	refresh_button.text = "REGENERATE " + str(titles.get(component_id, "DESIGN"))
	refresh_button.custom_minimum_size.y = 42
	_style_button(refresh_button)
	refresh_button.pressed.connect(_regenerate_selected_component)
	content.add_child(refresh_button)


func _add_component_option_row(parent: VBoxContainer, control_name: String, component_id: String, setting_id: String, title_text: String, options: Array, current_value: Variant) -> void:
	var row := HBoxContainer.new()
	row.name = control_name + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 42
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title := _label(title_text, 9, Color("#D0CBC2"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var selector := OptionButton.new()
	selector.name = control_name
	selector.custom_minimum_size = Vector2(112, 36)
	selector.size_flags_horizontal = Control.SIZE_SHRINK_END
	selector.focus_mode = Control.FOCUS_NONE
	for option_value in options:
		selector.add_item(str(option_value).replace("_", " ").to_upper())
	var selected_index := options.find(current_value)
	selector.select(maxi(0, selected_index))
	_style_button(selector)
	selector.item_selected.connect(_on_component_option_selected.bind(component_id, setting_id, options))
	row.add_child(selector)


func _add_component_toggle_row(parent: VBoxContainer, component_id: String, setting_id: String, title_text: String, initial_value: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "ComponentToggleRow_" + component_id + "_" + setting_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var title := _label(title_text, 11, Color("#D0CBC2"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var toggle := GlassCheckbox.new()
	toggle.name = "ComponentToggle_" + component_id + "_" + setting_id
	toggle.button_pressed = initial_value
	toggle.toggled.connect(_on_component_toggle_changed.bind(component_id, setting_id))
	row.add_child(toggle)


func _add_component_slider_row(parent: VBoxContainer, control_name: String, component_id: String, setting_id: String, title_text: String, initial_value: float, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.name = control_name + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 40
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title := _label(title_text, 9, Color("#D0CBC2"))
	title.custom_minimum_size.x = 88
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var slider := HSlider.new()
	slider.name = control_name
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_custom_slider(slider)
	slider.value_changed.connect(_on_component_slider_changed.bind(component_id, setting_id))
	row.add_child(slider)


func _on_component_option_selected(index: int, component_id: String, setting_id: String, options: Array) -> void:
	if index < 0 or index >= options.size():
		return
	var selected_value: Variant = options[index]
	if component_id == "wallpapers" and setting_id == "style":
		var shared_style: Dictionary = generated_os_configuration.get("style", {})
		shared_style["wallpaper"] = str(selected_value)
		generated_os_configuration["style"] = shared_style
	else:
		var components: Dictionary = generated_os_configuration.get("components", {})
		var component_data: Dictionary = components.get(component_id, {})
		component_data[setting_id] = selected_value
		components[component_id] = component_data
		generated_os_configuration["components"] = components
	_apply_component_configuration()


func _on_component_toggle_changed(enabled: bool, component_id: String, setting_id: String) -> void:
	var components: Dictionary = generated_os_configuration.get("components", {})
	var component_data: Dictionary = components.get(component_id, {})
	component_data[setting_id] = enabled
	components[component_id] = component_data
	generated_os_configuration["components"] = components
	_apply_component_configuration()


func _on_component_slider_changed(value: float, component_id: String, setting_id: String) -> void:
	var components: Dictionary = generated_os_configuration.get("components", {})
	var component_data: Dictionary = components.get(component_id, {})
	component_data[setting_id] = int(round(value))
	components[component_id] = component_data
	generated_os_configuration["components"] = components
	_apply_component_configuration()


func _apply_component_configuration() -> void:
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.update_configuration(generated_os_configuration)
		os_preview_simulator.set_component_view(selected_os_component_id)

func _apply_approved_home_screen_layout() -> void:
	if generated_os_configuration.is_empty():
		return
	generated_os_configuration["generation"] = home_generation
	var components: Dictionary = generated_os_configuration.get("components", {})
	var home_data: Dictionary = components.get("home_screen", {})
	var layout_index := clampi(home_screen_layout_level, 0, ProceduralOSEngineScript.HOME_LAYOUT_STYLES.size() - 1)
	var selected_style := str(ProceduralOSEngineScript.HOME_LAYOUT_STYLES[layout_index])
	home_data["layout_style"] = selected_style
	var generation_style: Dictionary = generated_os_configuration.get("style", {})
	home_data["columns"] = int(generation_style.get("grid_columns", 4))
	home_data["widget_count"] = int(generation_style.get("widget_count", 2))
	home_data["show_search"] = not ["coloros_home", "huawei_pura", "windows_tiles"].has(selected_style)
	home_data["dock_count"] = 5 if home_generation == 3 and home_screen_layout_level == 0 else 4
	components["home_screen"] = home_data
	generated_os_configuration["components"] = components
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.update_configuration(generated_os_configuration)
		os_preview_simulator.set_home_screen_corner_radius(float(home_screen_corner_radius))


func _show_home_screen_studio_controls() -> void:
	if not is_instance_valid(selection_panel):
		return
	selected_os_component_id = "home_screen"
	_clear_selection_controls()

	var content := VBoxContainer.new()
	content.name = "HomeScreenStudioControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_theme_constant_override("separation", 12)
	selection_panel.add_child(content)

	var heading := _label("HOME SCREEN", 22, Color("#D3AA6B"))
	heading.name = "HomeScreenHeroTitle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var description := _label("Customize the selected layout's home-screen presentation.", 12, Color("#D0CBC2"))
	description.name = "HomeScreenHeroDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(description)
	if home_screen_layout_level == 0 and home_generation == 1:
		var selected_ui_family := str(generated_os_configuration.get("style", {}).get("ui_family", "samsung_touchwiz"))
		var screenshot_note := _label("Samsung TouchWiz Nature UX home screen uses the imported Galaxy S III screenshot. App shortcuts and the Apps launcher remain touch-enabled; the original icon artwork is no longer generated by DWM." if selected_ui_family == "samsung_touchwiz" else "Google Stock Android 4.0 Ice Cream Sandwich home screen uses the imported full-screen reference.", 11, Color("#A6A096"))
		screenshot_note.name = "SamsungGen1HomeScreenInteractionNote" if selected_ui_family == "samsung_touchwiz" else "PixelGen1HomeScreenReferenceNote"
		screenshot_note.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(screenshot_note)
		return

	var hero_gap := Control.new()
	hero_gap.custom_minimum_size.y = 32
	content.add_child(hero_gap)

	var radius_row := HBoxContainer.new()
	radius_row.name = "HomeScreenCornerRadiusControl"
	radius_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_row.alignment = BoxContainer.ALIGNMENT_CENTER
	radius_row.add_theme_constant_override("separation", 8)
	content.add_child(radius_row)

	var radius_title := _label("CORNER RADIUS", 11, Color("#D0CBC2"))
	radius_title.custom_minimum_size.x = 92
	radius_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	radius_row.add_child(radius_title)

	var radius_slider := HSlider.new()
	radius_slider.name = "HomeScreenCornerRadiusSlider"
	radius_slider.min_value = 0
	radius_slider.max_value = 24
	radius_slider.step = 0.25
	radius_slider.value = home_screen_corner_radius
	radius_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_slider.custom_minimum_size = Vector2(120, 30)
	radius_slider.focus_mode = Control.FOCUS_NONE
	radius_slider.value_changed.connect(_on_home_screen_corner_radius_changed)
	_style_custom_slider(radius_slider)
	radius_row.add_child(radius_slider)

	var radius_value := _label(str(home_screen_corner_radius), 11, Color("#D3AA6B"))
	radius_value.name = "HomeScreenCornerRadiusValue"
	radius_value.custom_minimum_size.x = 20
	radius_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	radius_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	radius_row.add_child(radius_value)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.set_home_screen_corner_radius(float(home_screen_corner_radius))

func _style_custom_slider(slider: Slider) -> void:
	# Exact premium slider styling shared with Phone Creation.
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#26292B")
	track.border_color = Color("#C58A3A")
	track.set_border_width_all(2)
	track.set_corner_radius_all(12)
	track.content_margin_left = 6
	track.content_margin_right = 6
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	var grabber_gradient := Gradient.new()
	grabber_gradient.set_color(0, Color("#ffffff"))
	grabber_gradient.set_color(1, Color("#C58A3A"))
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

func _on_home_screen_corner_radius_changed(value: float) -> void:
	home_screen_corner_radius = clampi(roundi(value), 0, 24)
	var value_label := find_child("HomeScreenCornerRadiusValue", true, false) as Label
	if value_label != null:
		value_label.text = str(home_screen_corner_radius)
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.set_home_screen_corner_radius(float(home_screen_corner_radius))


func _on_home_screen_layout_decrease_pressed() -> void:
	if home_screen_layout_level <= 0:
		return
	home_screen_layout_level -= 1
	_apply_layout_selection()


func _on_home_screen_layout_increase_pressed() -> void:
	if home_screen_layout_level >= ProceduralOSEngineScript.HOME_LAYOUT_STYLES.size() - 1:
		return
	home_screen_layout_level += 1
	_apply_layout_selection()


func _apply_layout_selection() -> void:
	device_powered_on = false
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.visible = false
	_apply_approved_home_screen_layout()
	_refresh_home_screen_layout_selector()


func _refresh_home_screen_layout_selector() -> void:
	var last_layout_index := ProceduralOSEngineScript.HOME_LAYOUT_STYLES.size() - 1
	home_screen_layout_level = clampi(home_screen_layout_level, 0, last_layout_index)
	if is_instance_valid(home_screen_layout_value_label):
		home_screen_layout_value_label.text = "LAYOUT " + str(home_screen_layout_level + 1)
	if is_instance_valid(home_screen_layout_family_label):
		home_screen_layout_family_label.text = str(ProceduralOSEngineScript.HOME_LAYOUT_FAMILY_LABELS[home_screen_layout_level])
	if is_instance_valid(home_screen_layout_decrease_button):
		home_screen_layout_decrease_button.disabled = home_screen_layout_level == 0
	if is_instance_valid(home_screen_layout_increase_button):
		home_screen_layout_increase_button.disabled = home_screen_layout_level == last_layout_index
	if is_instance_valid(generation_value_label):
		generation_value_label.text = "GENERATION %02d" % home_generation
	if is_instance_valid(generation_description_label):
		var layout_name: String = str(["ANDROID", "iOS", "WINDOWS PHONE"][home_screen_layout_level])
		var selected_gen1_family := str(generated_os_configuration.get("style", {}).get("ui_family", "samsung_touchwiz"))
		var ui_family_name := "GOOGLE STOCK ANDROID 4.0 ICE CREAM SANDWICH" if selected_gen1_family == "google_stock" else "XIAOMI MIUI · ANDROID 4.0 ERA" if selected_gen1_family == "xiaomi_miui" else "SAMSUNG TOUCHWIZ NATURE UX"
		var generation_name := ("ANDROID 4.0 · " + ui_family_name) if home_screen_layout_level == 0 and home_generation == 1 else "ANDROID 8.0 OREO" if home_screen_layout_level == 0 and home_generation == 2 else "ANDROID 9.0 PIE" if home_screen_layout_level == 0 and home_generation == 3 else "ANDROID 10 · SAMSUNG ONE UI 2.0" if home_screen_layout_level == 0 and home_generation == 4 else "%s GENERATION %02d" % [layout_name, home_generation]
		generation_description_label.text = generation_name
	if is_instance_valid(android_ui_family_selector):
		var show_gen1_families := home_screen_layout_level == 0 and home_generation == 1
		android_ui_family_selector.visible = show_gen1_families
		var family_heading := selection_panel.find_child("Gen1AndroidUIFamilyHeading", true, false) as Label
		if family_heading != null:
			family_heading.visible = show_gen1_families
		var family := str(generated_os_configuration.get("style", {}).get("ui_family", "samsung_touchwiz"))
		android_ui_family_selector.select(1 if family == "google_stock" else 2 if family == "xiaomi_miui" else 0)
	if is_instance_valid(generation_decrease_button):
		generation_decrease_button.disabled = home_generation <= 1
	if is_instance_valid(generation_increase_button):
		generation_increase_button.disabled = home_generation >= MAX_SELECTABLE_GENERATION
	_apply_approved_home_screen_layout()


func _add_lock_screen_toggle_row(parent: VBoxContainer, feature_id: String, title_text: String, detail_text: String, unavailable: bool = false) -> void:
	var row := HBoxContainer.new()
	row.name = "LockScreenSettingRow_" + feature_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 54)
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 1)
	var title := _label(title_text, 14, Color("#E5E0D6"))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	labels.add_child(title)
	var detail := _label(detail_text if not unavailable else "No fingerprint sensor detected on this phone", 9, Color("#A6A096"))
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
	var components: Dictionary = generated_os_configuration.get("components", {})
	var lock_data: Dictionary = components.get("lock_screen", {})
	lock_data[feature_id] = enabled
	components["lock_screen"] = lock_data
	generated_os_configuration["components"] = components
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
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
	parent.add_theme_constant_override("separation", 14)
	var heading := _label("BOOT LOADER", 22, Color("#D3AA6B"))
	heading.name = "BootLoaderHeroTitle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)
	var description := _label("Choose which startup details appear when your phone powers on.", 13, Color("#E5E0D6"))
	description.name = "BootLoaderHeroDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(description)

	var hero_gap := Control.new()
	hero_gap.name = "BootLoaderHeroGap"
	hero_gap.custom_minimum_size = Vector2(0, 52)
	parent.add_child(hero_gap)

	var rows := [
		["company_logo", "Company Logo"],
		["phone_details", "Phone Details"]
	]
	for row_data in rows:
		var item_id := str(row_data[0])
		var row := HBoxContainer.new()
		row.name = "BootSettingRow_" + item_id
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 58)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var item_label := _label(str(row_data[1]), 18, Color("#E5E0D6"))
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
	_set_wizard_step(3)
	boot_completed.emit()

func _on_os_generation_selected(index: int) -> void:
	home_generation = clampi(index + 1, 1, MAX_SELECTABLE_GENERATION)
	_apply_generation_selection()


func _on_generation_decrease_pressed() -> void:
	if home_generation <= 1:
		return
	home_generation -= 1
	_apply_generation_selection()


func _on_generation_increase_pressed() -> void:
	if home_generation >= MAX_SELECTABLE_GENERATION:
		return
	home_generation += 1
	_apply_generation_selection()


func _android_ui_family_options() -> Array:
	if home_generation == 1:
		return [
			{"id":"samsung_touchwiz","label":"Samsung TouchWiz Nature UX","status":"SAMSUNG TOUCHWIZ NATURE UX"},
			{"id":"google_stock","label":"Google Stock Android 4.0 ICS","status":"GOOGLE STOCK ANDROID 4.0"},
			{"id":"xiaomi_miui","label":"Xiaomi MIUI · Android 4.0 era","status":"XIAOMI MIUI"}
		]
	if home_generation == 2:
		return [
			{"id":"samsung_experience","label":"Samsung Experience 8.0","status":"SAMSUNG EXPERIENCE 8.0"},
			{"id":"google_pixel","label":"Google Pixel Launcher · Android 7.1","status":"GOOGLE PIXEL LAUNCHER · ANDROID 7.1"},
			{"id":"xiaomi_miui8","label":"Xiaomi MIUI 8","status":"XIAOMI MIUI 8"}
		]
	return []

func _on_android_ui_family_selected(index: int) -> void:
	if home_screen_layout_level != 0:
		return
	var options := _android_ui_family_options()
	if index < 0 or index >= options.size():
		return
	var selected: Dictionary = options[index]
	var style: Dictionary = generated_os_configuration.get("style", {}).duplicate(true)
	style["ui_family"] = str(selected["id"])
	generated_os_configuration["style"] = style
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	_apply_approved_home_screen_layout()
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.update_configuration(generated_os_configuration)
		os_preview_simulator.set_component_view("lock_screen")
	_set_os_generation_status("GEN %d UI FAMILY · %s" % [home_generation, str(selected["status"])])


func _apply_generation_selection() -> void:
	device_powered_on = false
	if is_instance_valid(os_preview_simulator):
		os_preview_simulator.visible = false
	var selected_ui_family := str(generated_os_configuration.get("style", {}).get("ui_family", ""))
	generated_os_configuration = ProceduralOSEngineScript.generate_os(-1, home_generation)
	var generated_style: Dictionary = generated_os_configuration.get("style", {})
	if home_generation in [1, 2]:
		for option in _android_ui_family_options():
			if str(option["id"]) == selected_ui_family:
				generated_style["ui_family"] = selected_ui_family
				break
	generated_os_configuration["style"] = generated_style
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	if home_generation in [1, 2, 4]:
		# Screenshot-backed Android generations enter through their family lock screen.
		selected_os_component_id = "lock_screen"
	_apply_bootloader_settings_to_configuration()
	_apply_approved_home_screen_layout()
	if home_generation in [1, 2, 4] and is_instance_valid(os_preview_simulator):
		os_preview_simulator.set_component_view("lock_screen")
	_refresh_home_screen_layout_selector()
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
	var selected_ui_family := str(generated_os_configuration.get("style", {}).get("ui_family", ""))
	generated_os_configuration = ProceduralOSEngineScript.generate_os(-1, home_generation)
	var generated_style: Dictionary = generated_os_configuration.get("style", {})
	if home_generation in [1, 2]:
		for option in _android_ui_family_options():
			if str(option["id"]) == selected_ui_family:
				generated_style["ui_family"] = selected_ui_family
				break
	generated_os_configuration["style"] = generated_style
	generated_os_configuration = ProceduralOSEngineScript.normalize_os(generated_os_configuration)
	_apply_bootloader_settings_to_configuration()
	_apply_approved_home_screen_layout()
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
		_set_right_region_margins(22, 18, 20, 20)
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
	current_wizard_step = clampi(step, 1, WIZARD_STEP_COUNT)
	if current_wizard_step >= 3 and not device_powered_on:
		current_wizard_step = 2
	if current_wizard_step == 1:
		selected_os_component_id = "home_screen"
		if is_instance_valid(os_preview_simulator):
			os_preview_simulator.visible = false
		_build_os_selection_controls()
	elif current_wizard_step == 2:
		if is_instance_valid(os_preview_simulator):
			os_preview_simulator.visible = device_powered_on
		_build_bootloader_controls_only()
	else:
		var component_index := current_wizard_step - 3
		selected_os_component_id = str(CUSTOMIZATION_COMPONENTS[component_index])
		if is_instance_valid(os_preview_simulator):
			os_preview_simulator.visible = true
			os_preview_simulator.set_component_view(selected_os_component_id)
		match selected_os_component_id:
			"lock_screen":
				_show_lock_screen_studio_controls()
			"home_screen":
				_show_home_screen_studio_controls()
			_:
				_show_component_studio_controls(selected_os_component_id)
	if is_instance_valid(progress_number):
		progress_number.text = "STEP %d / %d" % [current_wizard_step, WIZARD_STEP_COUNT]
	if is_instance_valid(progress_bar):
		progress_bar.max_value = WIZARD_STEP_COUNT
		progress_bar.value = current_wizard_step
	_keep_step_navigation_active()


func _keep_step_navigation_active() -> void:
	if is_instance_valid(navigation_layer):
		navigation_layer.layer = 127
	if is_instance_valid(navigation_bar):
		# Keep the full-width container transparent to input; its child arrows
		# retain MOUSE_FILTER_STOP and continue to receive their own taps.
		navigation_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		navigation_bar.z_index = 1000
		navigation_bar.z_as_relative = false
	if is_instance_valid(left_power_region):
		left_power_region.visible = current_wizard_step == 2
	if is_instance_valid(wizard_back_button):
		wizard_back_button.disabled = current_wizard_step <= 1
		wizard_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
		wizard_back_button.modulate.a = 0.42 if wizard_back_button.disabled else 1.0
	if is_instance_valid(next_button):
		var boot_step_waiting := current_wizard_step == 2 and not device_powered_on
		var customization_waiting := current_wizard_step >= 3 and not device_powered_on
		next_button.disabled = current_wizard_step >= WIZARD_STEP_COUNT or boot_step_waiting or customization_waiting
		next_button.mouse_filter = Control.MOUSE_FILTER_STOP
		next_button.modulate.a = 0.42 if next_button.disabled else 1.0


func _on_wizard_back_pressed() -> void:
	_set_wizard_step(current_wizard_step - 1)


func _on_next_pressed() -> void:
	if current_wizard_step == 1:
		_set_wizard_step(2)
	elif current_wizard_step == 2 and device_powered_on:
		_set_wizard_step(3)
	elif current_wizard_step >= 3 and current_wizard_step < WIZARD_STEP_COUNT and device_powered_on:
		_set_wizard_step(current_wizard_step + 1)
