extends Node3D

signal back_requested
signal os_selected(configuration: Dictionary)

const ProceduralOSEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const OSPreviewSimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")

var generated_os_configuration: Dictionary = {}
var selected_os_component_id := "home_screen"
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
var selection_panel: Control
var configuration_region: Control
var screen_frame: PanelContainer
var home_preview_screen: PanelContainer
var home_generation := 1
var home_generation_status: Label
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
	_build_interface()


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

	progress_number = _label("STEP 1 / 1", 11, Color("#E5E0D6"))
	progress_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

	progress_bar = ProgressBar.new()
	progress_bar.name = "OSWizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = 1
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

	preview_region = Control.new()
	preview_region.name = "OSScreenPreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.12
	worksite_body.add_child(preview_region)

	var screen_center := CenterContainer.new()
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

	var right_region := MarginContainer.new()
	configuration_region = right_region
	right_region.name = "OSConfigurationRegion"
	right_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_region.size_flags_stretch_ratio = 0.88
	right_region.add_theme_constant_override("margin_left", 22)
	right_region.add_theme_constant_override("margin_right", 18)
	right_region.add_theme_constant_override("margin_top", 20)
	right_region.add_theme_constant_override("margin_bottom", 20)
	worksite_body.add_child(right_region)

	# Keep the controls directly on the worksite; no surrounding card or panel.
	selection_panel = right_region
	_build_home_generation_controls()

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
	screen.add_child(os_preview_simulator)

func _build_home_generation_controls() -> void:
	var controls_scroll := ScrollContainer.new()
	controls_scroll.name = "OSGeneratorControlsViewport"
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	selection_panel.add_child(controls_scroll)

	var content := VBoxContainer.new()
	content.name = "ProceduralOSGeneratorControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 10)
	controls_scroll.add_child(content)

	var heading := _label("OPERATING SYSTEM GENERATOR", 16, Color("#F0E9DD"))
	content.add_child(heading)
	var description := _label("Generate a complete OS, then refine any component independently.", 11, Color("#B8B1A6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	content.add_child(_label("DESIGN GENERATION", 10, Color("#C58A3A")))
	os_generation_selector = OptionButton.new()
	os_generation_selector.name = "OSGenerationSelector"
	os_generation_selector.add_item("Generation 1 · Classic")
	os_generation_selector.add_item("Generation 2 · Modern")
	os_generation_selector.add_item("Generation 3 · Advanced")
	os_generation_selector.selected = clampi(home_generation - 1, 0, 2)
	os_generation_selector.custom_minimum_size.y = 40
	os_generation_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(os_generation_selector)
	os_generation_selector.item_selected.connect(_on_os_generation_selected)
	content.add_child(os_generation_selector)

	content.add_child(_label("COMPONENT PREVIEW", 10, Color("#C58A3A")))
	os_component_selector = OptionButton.new()
	os_component_selector.name = "OSComponentSelector"
	os_component_selector.custom_minimum_size.y = 40
	os_component_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for component in ProceduralOSEngineScript.COMPONENTS:
		os_component_selector.add_item(str(component["title"]))
	os_component_selector.select(0)
	_style_button(os_component_selector)
	os_component_selector.item_selected.connect(_on_os_component_selected)
	content.add_child(os_component_selector)

	var generate_button := Button.new()
	generate_button.name = "GenerateCompleteOSButton"
	generate_button.text = "GENERATE COMPLETE OS"
	generate_button.custom_minimum_size.y = 46
	_style_button(generate_button)
	generate_button.pressed.connect(_generate_complete_os)
	content.add_child(generate_button)

	var regenerate_button := Button.new()
	regenerate_button.name = "RegenerateOSComponentButton"
	regenerate_button.text = "REGENERATE THIS COMPONENT"
	regenerate_button.custom_minimum_size.y = 42
	_style_button(regenerate_button)
	regenerate_button.pressed.connect(_regenerate_selected_component)
	content.add_child(regenerate_button)

	var select_button := Button.new()
	select_button.name = "SelectGeneratedOSButton"
	select_button.text = "SELECT & USE THIS OS"
	select_button.custom_minimum_size.y = 46
	_style_button(select_button)
	select_button.pressed.connect(_select_generated_os)
	content.add_child(select_button)

	home_generation_status = _label("READY · 12 COMPONENTS", 10, Color("#C58A3A"))
	home_generation_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(home_generation_status)

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
		os_preview_simulator.visible = true
		os_preview_simulator.configure_os(generated_os_configuration, selected_os_component_id)
		os_preview_simulator.set_component_view(selected_os_component_id)
	else:
		push_error("Generated OS preview simulator is not mounted in the phone screen.")
		_set_os_generation_status("PREVIEW FAILED · REOPEN OS WORKSITE")
		os_generation_busy = false
		return
	if is_instance_valid(progress_bar):
		progress_bar.value = 1.0
	_set_os_generation_status("GENERATED · %s · 12 COMPONENTS READY" % str(generated_os_configuration.get("name", "NEW OS")))
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
		preview_region.size_flags_stretch_ratio = 1.12
		configuration_region.size_flags_stretch_ratio = 0.88
		preview_region.custom_minimum_size = Vector2(0, 0)
		screen_height = clampf(viewport_size.y - 28.0, 250.0, 760.0)
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		configuration_region.size_flags_stretch_ratio = 1.18
		preview_region.custom_minimum_size = Vector2(0, maxf(140.0, viewport_size.y * 0.24))
		screen_height = clampf(viewport_size.y * 0.34, 210.0, 420.0)
	# The preview always represents a portrait handset, regardless of worksite orientation.
	screen_frame.custom_minimum_size = Vector2(screen_height * 0.49, screen_height)


func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	var font := load("res://assets/fonts/STIXTwoText[wght].ttf") as Font
	if is_instance_valid(font):
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
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


func _keep_step_navigation_active() -> void:
	if is_instance_valid(navigation_layer):
		navigation_layer.layer = 127
	if is_instance_valid(navigation_bar):
		navigation_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		navigation_bar.z_index = 1000
		navigation_bar.z_as_relative = false
	for button in [wizard_back_button, next_button]:
		if is_instance_valid(button):
			button.disabled = false
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.modulate.a = 1.0


func _on_wizard_back_pressed() -> void:
	_keep_step_navigation_active()
	if not is_instance_valid(os_component_selector):
		return
	var previous_index := maxi(os_component_selector.selected - 1, 0)
	os_component_selector.select(previous_index)
	_on_os_component_selected(previous_index)


func _on_next_pressed() -> void:
	_keep_step_navigation_active()
	if not is_instance_valid(os_component_selector):
		return
	var next_index := (os_component_selector.selected + 1) % ProceduralOSEngineScript.COMPONENTS.size()
	os_component_selector.select(next_index)
	_on_os_component_selected(next_index)