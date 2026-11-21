extends Node3D

const ProcessorDesignLibrary = preload("res://scripts/processor_design_library.gd")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")

signal back_requested
signal research_requested
signal design_saved(design: Dictionary)

const ACCENT := Color("#C58A3A")
const TEXT := Color("#EEEAE2")
const MUTED := Color("#A9A49A")
const LEGACY_PROCESSOR_COLORS := {
	"Obsidian Black": Color("#101214"),
	"Graphite": Color("#34383D"),
	"Gunmetal": Color("#4B5055"),
	"Silver": Color("#A5AAAE"),
	"Gold": Color("#94703A"),
	"Midnight Blue": Color("#223B5A"),
	"Crimson": Color("#682F35")
}

const DEFAULT_VIEW_ROTATION := Vector3(-0.24, -0.42, 0.0)
const DRAG_SENSITIVITY := 0.0024
const WIZARD_STEP_COUNT := 8

const PROCESSOR_TECHNOLOGIES := [
	"Control Unit",
	"Instruction Decoder",
	"Instruction Fetch Unit",
	"Branch Prediction Unit",
	"Memory Management Unit",
	"Translation Lookaside Buffer",
	"Internal Bus",
	"Ring Bus / Interconnect Fabric",
	"System Agent",
	"I/O Controller",
	"Clock Distribution Network",
	"Voltage Regulator Interface",
	"Thermal Sensor",
	"Debug and Test Unit",
	"Security Processing Unit"
]

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


class DeviceColorSpectrum extends Control:
	signal color_changed(color: Color)
	var hue := 0.0
	var saturation := 1.0
	var brightness := 1.0
	var spectrum_texture: ImageTexture
	var dragging := false

	func _ready() -> void:
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
		draw_rect(rect, Color("#C58A3A"), false, 1.0)
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


var preview_viewport: SubViewport
var processor_preview_world: Node3D
var processor_root: Node3D
var preview_camera: Camera3D
var package_size: OptionButton
var processor_color := Color("#101214")
var processor_gradient_color := Color("#536DFE")
var processor_gradient_enabled := false
var processor_gradient_direction := 0
var processor_gradient_color_edit_mode := false
var processor_color_material: Material
var processor_solid_material: StandardMaterial3D
var processor_gradient_material: ShaderMaterial
var status_label: Label
var worksite_body: BoxContainer
var preview_region: Control
var preview_holder: SubViewportContainer
var right_panel_column: VBoxContainer
var selection_scroll: ScrollContainer
var selection_region: MarginContainer
var selection_stack: VBoxContainer
var processor_color_step_host: VBoxContainer
var processor_color_content: VBoxContainer
var gradient_direction_button: Button
var worksite_color_gradient_toggle: TextureButton
var step_pages: Array[Control] = []
var progress_number: Label
var progress_bar: ProgressBar
var wizard_back_button: Button
var next_button: Button
var current_wizard_step := 1
var processor_technology_step_content: VBoxContainer
var processor_technology_enable_label: Label
var processor_technology_enabled_toggle: TextureButton
var processor_technology_name_label: Label
var processor_technology_previous_button: Button
var processor_technology_next_button: Button
var processor_technology_selected_index := 0
var processor_technology_enabled_states: Dictionary = {}
var processor_technology_research_levels: Dictionary = {}
var processor_technology_level_value_label: Label
var processor_technology_checked_texture: Texture2D
var processor_technology_unchecked_texture: Texture2D
var processor_cpu_core_step_content: VBoxContainer
var processor_cpu_core_slider: HSlider
var processor_cpu_core_value_label: Label
var processor_cpu_core_range_label: Label
var processor_cpu_core_research_level := 0
var processor_cpu_core_count := 1
var processor_instruction_scheduler_step_content: VBoxContainer
var processor_instruction_scheduler_slider: HSlider
var processor_instruction_scheduler_value_label: Label
var processor_instruction_scheduler_range_label: Label
var processor_instruction_scheduler_research_level := 0
var processor_instruction_scheduler_selected_level := 0
var processor_l1_cache_step_content: VBoxContainer
var processor_l1_cache_slider: HSlider
var processor_l1_cache_value_label: Label
var processor_l1_cache_range_label: Label
var processor_l1_cache_research_level := 0
var processor_l1_cache_selected_level := 0
var processor_l2_cache_step_content: VBoxContainer
var processor_l2_cache_slider: HSlider
var processor_l2_cache_value_label: Label
var processor_l2_cache_range_label: Label
var processor_l2_cache_research_level := 0
var processor_l2_cache_selected_level := 0
var processor_l3_cache_step_content: VBoxContainer
var processor_l3_cache_slider: HSlider
var processor_l3_cache_value_label: Label
var processor_l3_cache_range_label: Label
var processor_l3_cache_research_level := 0
var processor_l3_cache_selected_level := 0
var package_layers: Array[MeshInstance3D] = []
var die_surface: MeshInstance3D
var die_surfaces: Array[MeshInstance3D] = []
var processor_designs: Array[Dictionary] = []
var processor_models_data: Array[Dictionary] = []
var selected_design_index := 0
var processor_design_research_level := 0
var design_decrease_button: Button
var design_increase_button: Button
var design_value_label: Label
var design_position_label: Label
var drag_active := false
var processor_design := {
	"name": "DW SILICON 01",
	"design_id": "dw_silicon_01",
	"design_name": "DW SILICON 01",
	"package_size": "12 × 12 mm",
	"processor_color": "#101214",
	"processor_gradient_color": "#536DFE",
	"processor_gradient_enabled": false,
	"processor_gradient_direction": 0,
	"cpu_core_count": 1,
	"instruction_scheduler_entries": 8,
	"l1_cache_kb": 2,
	"l2_cache_kb": 128,
	"l3_cache_kb": 1024
}

func _ready() -> void:
	_build_interface()
	_build_processor_preview()
	_apply_design()

func configure_design(design: Dictionary) -> void:
	if design.is_empty():
		return
	processor_design = design.duplicate(true)
	var saved_design_id := str(processor_design.get("design_id", "dw_silicon_01"))
	var restored_index := 0
	for index in range(ProcessorDesignLibrary.DESIGNS.size()):
		if str(ProcessorDesignLibrary.DESIGNS[index].get("id", "")) == saved_design_id:
			restored_index = index
			break
	_select_processor_design(restored_index, false)
	if is_instance_valid(package_size):
		_select_option(package_size, str(processor_design.get("package_size", "12 × 12 mm")))
	processor_color = _parse_saved_processor_color(str(processor_design.get("processor_color", "#101214")), Color("#101214"))
	processor_gradient_color = _parse_saved_processor_color(str(processor_design.get("processor_gradient_color", "#536DFE")), Color("#536DFE"))
	processor_gradient_enabled = bool(processor_design.get("processor_gradient_enabled", false))
	processor_gradient_direction = clampi(int(processor_design.get("processor_gradient_direction", 0)), 0, 3)
	processor_cpu_core_count = clampi(int(processor_design.get("cpu_core_count", 1)), 1, 30)
	var saved_scheduler_entries := int(processor_design.get("instruction_scheduler_entries", 8))
	var saved_scheduler_level := ResearchManagerScript.INSTRUCTION_SCHEDULER_ENTRY_LEVELS.find(saved_scheduler_entries)
	processor_instruction_scheduler_selected_level = maxi(0, saved_scheduler_level)
	var saved_l1_cache_kb := clampi(int(processor_design.get("l1_cache_kb", 2)), 2, ResearchManagerScript.L1_CACHE_MAX_CAPACITY_KB)
	processor_l1_cache_selected_level = clampi(floori(float(saved_l1_cache_kb - ResearchManagerScript.L1_CACHE_BASE_CAPACITY_KB) / float(ResearchManagerScript.L1_CACHE_RESEARCH_INCREMENT_KB)), 0, ResearchManagerScript.L1_CACHE_MAX_RESEARCH_LEVEL)
	var saved_l2_cache_kb := clampi(int(processor_design.get("l2_cache_kb", ResearchManagerScript.L2_CACHE_BASE_CAPACITY_KB)), ResearchManagerScript.L2_CACHE_BASE_CAPACITY_KB, ResearchManagerScript.L2_CACHE_MAX_CAPACITY_KB)
	processor_l2_cache_selected_level = clampi(floori(float(saved_l2_cache_kb - ResearchManagerScript.L2_CACHE_BASE_CAPACITY_KB) / float(ResearchManagerScript.L2_CACHE_RESEARCH_INCREMENT_KB)), 0, ResearchManagerScript.L2_CACHE_MAX_RESEARCH_LEVEL)
	var saved_l3_cache_kb := clampi(int(processor_design.get("l3_cache_kb", ResearchManagerScript.L3_CACHE_BASE_CAPACITY_KB)), ResearchManagerScript.L3_CACHE_BASE_CAPACITY_KB, ResearchManagerScript.L3_CACHE_MAX_CAPACITY_KB)
	processor_l3_cache_selected_level = clampi(floori(float(saved_l3_cache_kb - ResearchManagerScript.L3_CACHE_BASE_CAPACITY_KB) / float(ResearchManagerScript.L3_CACHE_RESEARCH_INCREMENT_KB)), 0, ResearchManagerScript.L3_CACHE_MAX_RESEARCH_LEVEL)
	var saved_technology_states: Variant = processor_design.get("processor_technology_enabled_states", {})
	if saved_technology_states is Dictionary:
		processor_technology_enabled_states = saved_technology_states.duplicate(true)
	processor_gradient_color_edit_mode = false
	_apply_design()
	_refresh_processor_color_controls()
	if is_instance_valid(status_label):
		status_label.text = "SAVED PROCESSOR DESIGN LOADED"

func _select_option(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if option.get_item_text(index) == value:
			option.select(index)
			return

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProcessorCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	var root := Control.new()
	root.name = "WorksiteRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	root.resized.connect(_apply_responsive_layout)

	var backdrop := ColorRect.new()
	backdrop.name = "WorksiteBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#292B2D")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	worksite_body = BoxContainer.new()
	worksite_body.name = "WorksiteMainContent"
	worksite_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worksite_body.offset_left = 20.0
	worksite_body.offset_right = -20.0
	worksite_body.offset_top = 4.0
	worksite_body.offset_bottom = -12.0
	worksite_body.add_theme_constant_override("separation", 0)
	root.add_child(worksite_body)

	var back_button := Button.new()
	back_button.name = "WorksiteBackButton"
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
	_style_button(back_button, false)
	back_button.pressed.connect(func(): back_requested.emit())
	root.add_child(back_button)

	var research_button := Button.new()
	research_button.name = "ProcessorResearchButton"
	research_button.text = "RESEARCH"
	research_button.anchor_left = 0.0
	research_button.anchor_right = 0.0
	research_button.anchor_top = 0.0
	research_button.anchor_bottom = 0.0
	research_button.offset_left = 112.0
	research_button.offset_top = 12.0
	research_button.offset_right = 226.0
	research_button.offset_bottom = 60.0
	research_button.focus_mode = Control.FOCUS_NONE
	_style_button(research_button, false)
	research_button.pressed.connect(func(): research_requested.emit())
	root.add_child(research_button)

	var progress := VBoxContainer.new()
	progress.name = "WorksiteProgress"
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
	progress_bar.name = "WizardProgressBar"
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

	preview_region = Control.new()
	preview_region.name = "ProcessorPreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.12
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worksite_body.add_child(preview_region)

	var preview_column := VBoxContainer.new()
	preview_column.name = "ProcessorPreviewColumn"
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_column.add_theme_constant_override("separation", 7)
	preview_region.add_child(preview_column)

	preview_holder = SubViewportContainer.new()
	preview_holder.name = "ProcessorPreviewViewport"
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.custom_minimum_size = Vector2(0, 140)
	preview_holder.stretch = true
	preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_holder.gui_input.connect(_on_preview_input)
	preview_column.add_child(preview_holder)

	preview_viewport = SubViewport.new()
	preview_viewport.name = "Processor3DSubViewport"
	preview_viewport.size = Vector2i(640, 480)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.msaa_3d = Viewport.MSAA_DISABLED
	preview_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	preview_viewport.scaling_3d_scale = 1.25
	preview_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview_holder.add_child(preview_viewport)


	selection_scroll = ScrollContainer.new()
	selection_scroll.name = "ProcessorSelectionScroll"
	selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_scroll.size_flags_stretch_ratio = 0.88
	selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var selection_scroll_bar := selection_scroll.get_v_scroll_bar()
	selection_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	selection_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel_column = VBoxContainer.new()
	right_panel_column.name = "ProcessorCreationRightPanel"
	right_panel_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel_column.add_theme_constant_override("separation", 8)
	worksite_body.add_child(right_panel_column)
	right_panel_column.add_child(selection_scroll)
	_build_processor_technology_level_footer()

	selection_region = MarginContainer.new()
	selection_region.name = "ProcessorSelectionRegion"
	selection_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_region.add_theme_constant_override("margin_left", 22)
	selection_region.add_theme_constant_override("margin_right", 18)
	selection_region.add_theme_constant_override("margin_top", 20)
	selection_region.add_theme_constant_override("margin_bottom", 20)
	selection_scroll.add_child(selection_region)

	selection_stack = VBoxContainer.new()
	selection_stack.name = "ProcessorSelectionControls"
	selection_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_stack.add_theme_constant_override("separation", 16)
	selection_region.add_child(selection_stack)

	var name_page := _create_step_page("SELECT PROCESSOR DESIGN")
	var design_selector_zone := CenterContainer.new()
	design_selector_zone.name = "ProcessorDesignSelectorZone"
	design_selector_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	design_selector_zone.custom_minimum_size = Vector2(0, 168)
	name_page.add_child(design_selector_zone)

	var selector_column := VBoxContainer.new()
	selector_column.name = "ProcessorDesignSelector"
	selector_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_column.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_column.add_theme_constant_override("separation", 9)
	design_selector_zone.add_child(selector_column)

	design_position_label = _label("DESIGN 01 / 30", 10, ACCENT)
	design_position_label.name = "ProcessorDesignPositionLabel"
	design_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selector_column.add_child(design_position_label)

	var selector_row := HBoxContainer.new()
	selector_row.name = "ProcessorDesignSelectorControls"
	selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_theme_constant_override("separation", 14)
	selector_column.add_child(selector_row)

	design_decrease_button = Button.new()
	design_decrease_button.name = "DecreaseProcessorDesignButton"
	design_decrease_button.text = "−"
	_style_design_selector_button(design_decrease_button)
	design_decrease_button.pressed.connect(_on_processor_design_decrease_pressed)
	selector_row.add_child(design_decrease_button)

	design_value_label = _label("DW SILICON 01", 19, Color.WHITE)
	design_value_label.name = "ProcessorDesignValueLabel"
	design_value_label.custom_minimum_size.x = 210
	design_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	design_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	design_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	selector_row.add_child(design_value_label)

	design_increase_button = Button.new()
	design_increase_button.name = "IncreaseProcessorDesignButton"
	design_increase_button.text = "+"
	_style_design_selector_button(design_increase_button)
	design_increase_button.pressed.connect(_on_processor_design_increase_pressed)
	selector_row.add_child(design_increase_button)



	var color_page := _create_step_page("PROCESSOR COLOR")
	color_page.alignment = BoxContainer.ALIGNMENT_BEGIN
	color_page.add_theme_constant_override("separation", 8)
	processor_color_step_host = VBoxContainer.new()
	processor_color_step_host.name = "ProcessorColorStepHost"
	processor_color_step_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_color_step_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_color_step_host.add_theme_constant_override("separation", 6)
	color_page.add_child(processor_color_step_host)
	_build_processor_color_controls()

	status_label = _label("DESIGN NOT YET SAVED", 10, MUTED)
	status_label.name = "ProcessorDesignStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_page.add_child(status_label)

	var save_button := Button.new()
	save_button.name = "SaveProcessorDesignButton"
	save_button.text = "SAVE PROCESSOR DESIGN"
	save_button.custom_minimum_size = Vector2(0, 46)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_button, true)
	save_button.pressed.connect(_save_design)
	color_page.add_child(save_button)

	var technologies_page := _create_step_page("TECHNOLOGIES")
	_build_processor_technology_controls(technologies_page)
	var save_technology_settings_button := Button.new()
	save_technology_settings_button.name = "SaveProcessorTechnologySettingsButton"
	save_technology_settings_button.text = "SAVE PROCESSOR DESIGN"
	save_technology_settings_button.custom_minimum_size = Vector2(0, 46)
	save_technology_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_technology_settings_button, true)
	save_technology_settings_button.pressed.connect(_save_design)
	technologies_page.add_child(save_technology_settings_button)

	var cpu_cores_page := _create_step_page("CPU CORES")
	_build_processor_cpu_core_controls(cpu_cores_page)
	var save_cpu_core_settings_button := Button.new()
	save_cpu_core_settings_button.name = "SaveProcessorCpuCoreSettingsButton"
	save_cpu_core_settings_button.text = "SAVE PROCESSOR DESIGN"
	save_cpu_core_settings_button.custom_minimum_size = Vector2(0, 46)
	save_cpu_core_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_cpu_core_settings_button, true)
	save_cpu_core_settings_button.pressed.connect(_save_design)
	cpu_cores_page.add_child(save_cpu_core_settings_button)

	var instruction_scheduler_page := _create_step_page("INSTRUCTION SCHEDULER")
	_build_processor_instruction_scheduler_controls(instruction_scheduler_page)
	var save_instruction_scheduler_settings_button := Button.new()
	save_instruction_scheduler_settings_button.name = "SaveProcessorInstructionSchedulerSettingsButton"
	save_instruction_scheduler_settings_button.text = "SAVE PROCESSOR DESIGN"
	save_instruction_scheduler_settings_button.custom_minimum_size = Vector2(0, 46)
	save_instruction_scheduler_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_instruction_scheduler_settings_button, true)
	save_instruction_scheduler_settings_button.pressed.connect(_save_design)
	instruction_scheduler_page.add_child(save_instruction_scheduler_settings_button)

	var l1_cache_page := _create_step_page("L1 CACHE")
	_build_processor_l1_cache_controls(l1_cache_page)
	var save_l1_cache_settings_button := Button.new()
	save_l1_cache_settings_button.name = "SaveProcessorL1CacheSettingsButton"
	save_l1_cache_settings_button.text = "SAVE PROCESSOR DESIGN"
	save_l1_cache_settings_button.custom_minimum_size = Vector2(0, 46)
	save_l1_cache_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_l1_cache_settings_button, true)
	save_l1_cache_settings_button.pressed.connect(_save_design)
	l1_cache_page.add_child(save_l1_cache_settings_button)

	var l2_cache_page := _create_step_page("L2 CACHE")
	_build_processor_l2_cache_controls(l2_cache_page)
	var save_l2_cache_settings_button := Button.new()
	save_l2_cache_settings_button.name = "SaveProcessorL2CacheSettingsButton"
	save_l2_cache_settings_button.text = "SAVE PROCESSOR DESIGN"
	save_l2_cache_settings_button.custom_minimum_size = Vector2(0, 46)
	save_l2_cache_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_l2_cache_settings_button, true)
	save_l2_cache_settings_button.pressed.connect(_save_design)
	l2_cache_page.add_child(save_l2_cache_settings_button)

	var l3_cache_page := _create_step_page("L3 CACHE")
	_build_processor_l3_cache_controls(l3_cache_page)
	var save_l3_cache_settings_button := Button.new()
	save_l3_cache_settings_button.name = "SaveProcessorL3CacheSettingsButton"
	save_l3_cache_settings_button.text = "SAVE PROCESSOR DESIGN"
	save_l3_cache_settings_button.custom_minimum_size = Vector2(0, 46)
	save_l3_cache_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_l3_cache_settings_button, true)
	save_l3_cache_settings_button.pressed.connect(_save_design)
	l3_cache_page.add_child(save_l3_cache_settings_button)

	wizard_back_button = GlassArrowButton.new()
	wizard_back_button.name = "WizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.anchor_left = 0.0
	wizard_back_button.anchor_right = 0.0
	wizard_back_button.anchor_top = 1.0
	wizard_back_button.anchor_bottom = 1.0
	wizard_back_button.offset_left = 20.0
	wizard_back_button.offset_top = -74.0
	wizard_back_button.offset_right = 74.0
	wizard_back_button.offset_bottom = -20.0
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	root.add_child(wizard_back_button)

	next_button = GlassArrowButton.new()
	next_button.name = "NextStepIconButton"
	next_button.points_right = true
	next_button.anchor_left = 1.0
	next_button.anchor_right = 1.0
	next_button.anchor_top = 1.0
	next_button.anchor_bottom = 1.0
	next_button.offset_left = -74.0
	next_button.offset_top = -74.0
	next_button.offset_right = -20.0
	next_button.offset_bottom = -20.0
	next_button.pressed.connect(_on_next_pressed)
	root.add_child(next_button)

	_apply_responsive_layout()
	_set_wizard_step(1)


func _create_step_page(title_text: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 14)
	page.visible = false
	selection_stack.add_child(page)
	step_pages.append(page)

	var heading := _label(title_text, 20, Color("#D3AA6B"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(heading)

	return page




func _build_processor_technology_level_footer() -> void:
	var panel := PanelContainer.new()
	panel.name = "ProcessorTechnologyLevelPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#141719")
	panel_style.border_color = Color("#625039")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 13.0
	panel_style.content_margin_right = 13.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var row := HBoxContainer.new()
	row.name = "ProcessorTechnologyLevelRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var title := _label("TECHNOLOGY LEVEL", 12, Color("#D3AA6B"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	processor_technology_level_value_label = _label("0.00 TP", 20, Color("#F2EEE7"))
	processor_technology_level_value_label.name = "ProcessorTechnologyLevelValue"
	processor_technology_level_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	processor_technology_level_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	processor_technology_level_value_label.custom_minimum_size = Vector2(88, 0)
	row.add_child(processor_technology_level_value_label)
	right_panel_column.add_child(panel)
	_refresh_processor_technology_level_display()


func set_processor_technology_research_levels(levels: Dictionary) -> void:
	processor_technology_research_levels = levels.duplicate(true)
	for technology_value in PROCESSOR_TECHNOLOGIES:
		var technology_name := str(technology_value)
		if int(processor_technology_research_levels.get(technology_name, 0)) < 1:
			processor_technology_enabled_states[technology_name] = false
	_refresh_processor_technology_controls()
	_refresh_processor_technology_level_display()


func set_cpu_core_research_level(level: int) -> void:
	processor_cpu_core_research_level = clampi(level, 0, ResearchManagerScript.CPU_CORE_MAX_RESEARCH_LEVEL)
	_refresh_processor_cpu_core_controls()


func _get_maximum_cpu_core_count() -> int:
	return ResearchManagerScript.get_cpu_cores_max_for_level(processor_cpu_core_research_level)


func set_instruction_scheduler_research_level(level: int) -> void:
	processor_instruction_scheduler_research_level = clampi(level, 0, ResearchManagerScript.INSTRUCTION_SCHEDULER_MAX_RESEARCH_LEVEL)
	_refresh_processor_instruction_scheduler_controls()



func set_l1_cache_research_level(level: int) -> void:
	processor_l1_cache_research_level = clampi(level, 0, ResearchManagerScript.L1_CACHE_MAX_RESEARCH_LEVEL)
	_refresh_processor_l1_cache_controls()


func set_l2_cache_research_level(level: int) -> void:
	processor_l2_cache_research_level = clampi(level, 0, ResearchManagerScript.L2_CACHE_MAX_RESEARCH_LEVEL)
	_refresh_processor_l2_cache_controls()


func set_l3_cache_research_level(level: int) -> void:
	processor_l3_cache_research_level = clampi(level, 0, ResearchManagerScript.L3_CACHE_MAX_RESEARCH_LEVEL)
	_refresh_processor_l3_cache_controls()


func set_processor_design_research_level(level: int) -> void:
	processor_design_research_level = clampi(level, 0, ResearchManagerScript.PROCESSOR_DESIGN_MAX_RESEARCH_LEVEL)
	var last_unlocked_index := _get_maximum_processor_design_count() - 1
	if selected_design_index > last_unlocked_index:
		_select_processor_design(last_unlocked_index, false)
	else:
		_refresh_processor_design_controls()


func _get_maximum_processor_design_count() -> int:
	return ResearchManagerScript.get_processor_design_max_for_level(processor_design_research_level)


func _build_processor_cpu_core_controls(parent: VBoxContainer) -> void:
	processor_cpu_core_step_content = VBoxContainer.new()
	processor_cpu_core_step_content.name = "ProcessorCpuCoreStepContent"
	processor_cpu_core_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_cpu_core_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_cpu_core_step_content.alignment = BoxContainer.ALIGNMENT_CENTER
	processor_cpu_core_step_content.add_theme_constant_override("separation", 18)
	parent.add_child(processor_cpu_core_step_content)

	var description := _label("SELECT THE NUMBER OF CPU CORES", 12, MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_cpu_core_step_content.add_child(description)

	processor_cpu_core_value_label = _label("1 CORE", 30, Color("#F2EEE7"))
	processor_cpu_core_value_label.name = "ProcessorCpuCoreCountValue"
	processor_cpu_core_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_cpu_core_step_content.add_child(processor_cpu_core_value_label)

	var slider_row := HBoxContainer.new()
	slider_row.name = "ProcessorCpuCoreSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_theme_constant_override("separation", 12)
	processor_cpu_core_step_content.add_child(slider_row)

	var minimum_label := _label("1", 12, MUTED)
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)

	processor_cpu_core_slider = HSlider.new()
	processor_cpu_core_slider.name = "ProcessorCpuCoreSlider"
	processor_cpu_core_slider.min_value = 1
	processor_cpu_core_slider.max_value = _get_maximum_cpu_core_count()
	processor_cpu_core_slider.step = 1
	processor_cpu_core_slider.value = processor_cpu_core_count
	processor_cpu_core_slider.custom_minimum_size = Vector2(0, 46)
	processor_cpu_core_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_cpu_core_slider.focus_mode = Control.FOCUS_NONE
	processor_cpu_core_slider.tick_count = 0
	_style_processor_cpu_core_slider(processor_cpu_core_slider)
	processor_cpu_core_slider.value_changed.connect(_on_processor_cpu_core_slider_changed)
	slider_row.add_child(processor_cpu_core_slider)

	var maximum_label := _label("30", 12, MUTED)
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)

	processor_cpu_core_range_label = _label("AVAILABLE RANGE: 1–1 CORES", 11, ACCENT)
	processor_cpu_core_range_label.name = "ProcessorCpuCoreRangeLabel"
	processor_cpu_core_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_cpu_core_step_content.add_child(processor_cpu_core_range_label)
	_refresh_processor_cpu_core_controls()


func _style_processor_cpu_core_slider(slider: Slider) -> void:
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
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#FFFFFF"))
	gradient.set_color(1, Color("#C58A3A"))
	var grabber := GradientTexture2D.new()
	grabber.gradient = gradient
	grabber.width = 32
	grabber.height = 32
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.editable = true


func _on_processor_cpu_core_slider_changed(value: float) -> void:
	processor_cpu_core_count = clampi(roundi(value), 1, _get_maximum_cpu_core_count())
	_refresh_processor_cpu_core_controls()


func _refresh_processor_cpu_core_controls() -> void:
	var maximum_count := _get_maximum_cpu_core_count()
	processor_cpu_core_count = clampi(processor_cpu_core_count, 1, maximum_count)
	if is_instance_valid(processor_cpu_core_slider):
		processor_cpu_core_slider.min_value = 1
		processor_cpu_core_slider.max_value = maximum_count
		if not is_equal_approx(processor_cpu_core_slider.value, float(processor_cpu_core_count)):
			processor_cpu_core_slider.set_value_no_signal(processor_cpu_core_count)
	if is_instance_valid(processor_cpu_core_value_label):
		processor_cpu_core_value_label.text = "%d CORE%s" % [processor_cpu_core_count, "" if processor_cpu_core_count == 1 else "S"]
	if is_instance_valid(processor_cpu_core_range_label):
		processor_cpu_core_range_label.text = "AVAILABLE RANGE: 1–%d CORES" % maximum_count
	_refresh_processor_technology_level_display()


func _build_processor_instruction_scheduler_controls(parent: VBoxContainer) -> void:
	processor_instruction_scheduler_step_content = VBoxContainer.new()
	processor_instruction_scheduler_step_content.name = "ProcessorInstructionSchedulerStepContent"
	processor_instruction_scheduler_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_instruction_scheduler_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_instruction_scheduler_step_content.alignment = BoxContainer.ALIGNMENT_CENTER
	processor_instruction_scheduler_step_content.add_theme_constant_override("separation", 18)
	parent.add_child(processor_instruction_scheduler_step_content)

	var description := _label("SELECT INSTRUCTION SCHEDULER CAPACITY", 12, MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_instruction_scheduler_step_content.add_child(description)

	processor_instruction_scheduler_value_label = _label("8 ENTRIES", 30, Color("#F2EEE7"))
	processor_instruction_scheduler_value_label.name = "ProcessorInstructionSchedulerEntryValue"
	processor_instruction_scheduler_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_instruction_scheduler_step_content.add_child(processor_instruction_scheduler_value_label)

	var slider_row := HBoxContainer.new()
	slider_row.name = "ProcessorInstructionSchedulerSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_theme_constant_override("separation", 12)
	processor_instruction_scheduler_step_content.add_child(slider_row)

	var minimum_label := _label("8", 12, MUTED)
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)

	processor_instruction_scheduler_slider = HSlider.new()
	processor_instruction_scheduler_slider.name = "ProcessorInstructionSchedulerSlider"
	processor_instruction_scheduler_slider.min_value = 0
	processor_instruction_scheduler_slider.max_value = processor_instruction_scheduler_research_level
	processor_instruction_scheduler_slider.step = 1
	processor_instruction_scheduler_slider.value = processor_instruction_scheduler_selected_level
	processor_instruction_scheduler_slider.custom_minimum_size = Vector2(0, 46)
	processor_instruction_scheduler_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_instruction_scheduler_slider.focus_mode = Control.FOCUS_NONE
	processor_instruction_scheduler_slider.tick_count = 0
	_style_processor_cpu_core_slider(processor_instruction_scheduler_slider)
	processor_instruction_scheduler_slider.value_changed.connect(_on_processor_instruction_scheduler_slider_changed)
	slider_row.add_child(processor_instruction_scheduler_slider)

	var maximum_label := _label("500", 12, MUTED)
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)

	processor_instruction_scheduler_range_label = _label("AVAILABLE RANGE: 8–8 ENTRIES", 11, ACCENT)
	processor_instruction_scheduler_range_label.name = "ProcessorInstructionSchedulerRangeLabel"
	processor_instruction_scheduler_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_instruction_scheduler_step_content.add_child(processor_instruction_scheduler_range_label)
	_refresh_processor_instruction_scheduler_controls()


func _on_processor_instruction_scheduler_slider_changed(value: float) -> void:
	processor_instruction_scheduler_selected_level = clampi(roundi(value), 0, processor_instruction_scheduler_research_level)
	_refresh_processor_instruction_scheduler_controls()


func _refresh_processor_instruction_scheduler_controls() -> void:
	var maximum_level := processor_instruction_scheduler_research_level
	processor_instruction_scheduler_selected_level = clampi(processor_instruction_scheduler_selected_level, 0, maximum_level)
	var selected_entries := ResearchManagerScript.get_instruction_scheduler_entries_for_level(processor_instruction_scheduler_selected_level)
	var maximum_entries := ResearchManagerScript.get_instruction_scheduler_entries_for_level(maximum_level)
	if is_instance_valid(processor_instruction_scheduler_slider):
		processor_instruction_scheduler_slider.min_value = 0
		processor_instruction_scheduler_slider.max_value = maximum_level
		if not is_equal_approx(processor_instruction_scheduler_slider.value, float(processor_instruction_scheduler_selected_level)):
			processor_instruction_scheduler_slider.set_value_no_signal(processor_instruction_scheduler_selected_level)
	if is_instance_valid(processor_instruction_scheduler_value_label):
		processor_instruction_scheduler_value_label.text = "%d ENTRIES" % selected_entries
	if is_instance_valid(processor_instruction_scheduler_range_label):
		processor_instruction_scheduler_range_label.text = "AVAILABLE RANGE: 8–%d ENTRIES" % maximum_entries
	_refresh_processor_technology_level_display()



func _build_processor_l1_cache_controls(parent: VBoxContainer) -> void:
	processor_l1_cache_step_content = VBoxContainer.new()
	processor_l1_cache_step_content.name = "ProcessorL1CacheStepContent"
	processor_l1_cache_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_l1_cache_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_l1_cache_step_content.alignment = BoxContainer.ALIGNMENT_CENTER
	processor_l1_cache_step_content.add_theme_constant_override("separation", 18)
	parent.add_child(processor_l1_cache_step_content)
	var description := _label("SELECT L1 CACHE CAPACITY", 12, MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l1_cache_step_content.add_child(description)
	processor_l1_cache_value_label = _label("2 KB", 30, Color("#F2EEE7"))
	processor_l1_cache_value_label.name = "ProcessorL1CacheCapacityValue"
	processor_l1_cache_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l1_cache_step_content.add_child(processor_l1_cache_value_label)
	var slider_row := HBoxContainer.new()
	slider_row.name = "ProcessorL1CacheSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_theme_constant_override("separation", 12)
	processor_l1_cache_step_content.add_child(slider_row)
	var minimum_label := _label("2 KB", 12, MUTED)
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)
	processor_l1_cache_slider = HSlider.new()
	processor_l1_cache_slider.name = "ProcessorL1CacheSlider"
	processor_l1_cache_slider.min_value = 0
	processor_l1_cache_slider.max_value = processor_l1_cache_research_level
	processor_l1_cache_slider.step = 1
	processor_l1_cache_slider.value = processor_l1_cache_selected_level
	processor_l1_cache_slider.custom_minimum_size = Vector2(0, 46)
	processor_l1_cache_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_l1_cache_slider.focus_mode = Control.FOCUS_NONE
	processor_l1_cache_slider.tick_count = 0
	_style_processor_cpu_core_slider(processor_l1_cache_slider)
	processor_l1_cache_slider.value_changed.connect(_on_processor_l1_cache_slider_changed)
	slider_row.add_child(processor_l1_cache_slider)
	var maximum_label := _label("300 KB", 12, MUTED)
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)
	processor_l1_cache_range_label = _label("AVAILABLE RANGE: 2–2 KB", 11, ACCENT)
	processor_l1_cache_range_label.name = "ProcessorL1CacheRangeLabel"
	processor_l1_cache_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l1_cache_step_content.add_child(processor_l1_cache_range_label)
	_refresh_processor_l1_cache_controls()


func _on_processor_l1_cache_slider_changed(value: float) -> void:
	processor_l1_cache_selected_level = clampi(roundi(value), 0, processor_l1_cache_research_level)
	_refresh_processor_l1_cache_controls()


func _refresh_processor_l1_cache_controls() -> void:
	processor_l1_cache_selected_level = clampi(processor_l1_cache_selected_level, 0, processor_l1_cache_research_level)
	var selected_capacity := 2 + processor_l1_cache_selected_level * 2
	var maximum_capacity := 2 + processor_l1_cache_research_level * 2
	if is_instance_valid(processor_l1_cache_slider):
		processor_l1_cache_slider.min_value = 0
		processor_l1_cache_slider.max_value = processor_l1_cache_research_level
		if not is_equal_approx(processor_l1_cache_slider.value, float(processor_l1_cache_selected_level)):
			processor_l1_cache_slider.set_value_no_signal(processor_l1_cache_selected_level)
	if is_instance_valid(processor_l1_cache_value_label):
		processor_l1_cache_value_label.text = "%d KB" % selected_capacity
	if is_instance_valid(processor_l1_cache_range_label):
		processor_l1_cache_range_label.text = "AVAILABLE RANGE: 2–%d KB" % maximum_capacity
	_refresh_processor_technology_level_display()


func _build_processor_l2_cache_controls(parent: VBoxContainer) -> void:
	processor_l2_cache_step_content = VBoxContainer.new()
	processor_l2_cache_step_content.name = "ProcessorL2CacheStepContent"
	processor_l2_cache_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_l2_cache_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_l2_cache_step_content.alignment = BoxContainer.ALIGNMENT_CENTER
	processor_l2_cache_step_content.add_theme_constant_override("separation", 18)
	parent.add_child(processor_l2_cache_step_content)
	var description := _label("SELECT L2 CACHE CAPACITY", 12, MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l2_cache_step_content.add_child(description)
	processor_l2_cache_value_label = _label("128 KB", 30, Color("#F2EEE7"))
	processor_l2_cache_value_label.name = "ProcessorL2CacheCapacityValue"
	processor_l2_cache_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l2_cache_step_content.add_child(processor_l2_cache_value_label)
	var slider_row := HBoxContainer.new()
	slider_row.name = "ProcessorL2CacheSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_theme_constant_override("separation", 12)
	processor_l2_cache_step_content.add_child(slider_row)
	var minimum_label := _label("128 KB", 12, MUTED)
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)
	processor_l2_cache_slider = HSlider.new()
	processor_l2_cache_slider.name = "ProcessorL2CacheSlider"
	processor_l2_cache_slider.min_value = 0
	processor_l2_cache_slider.max_value = processor_l2_cache_research_level
	processor_l2_cache_slider.step = 1
	processor_l2_cache_slider.value = processor_l2_cache_selected_level
	processor_l2_cache_slider.custom_minimum_size = Vector2(0, 46)
	processor_l2_cache_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_l2_cache_slider.focus_mode = Control.FOCUS_NONE
	processor_l2_cache_slider.tick_count = 0
	_style_processor_cpu_core_slider(processor_l2_cache_slider)
	processor_l2_cache_slider.value_changed.connect(_on_processor_l2_cache_slider_changed)
	slider_row.add_child(processor_l2_cache_slider)
	var maximum_label := _label("19,200 KB", 12, MUTED)
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)
	processor_l2_cache_range_label = _label("AVAILABLE RANGE: 128–128 KB", 11, ACCENT)
	processor_l2_cache_range_label.name = "ProcessorL2CacheRangeLabel"
	processor_l2_cache_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l2_cache_step_content.add_child(processor_l2_cache_range_label)
	_refresh_processor_l2_cache_controls()


func _on_processor_l2_cache_slider_changed(value: float) -> void:
	processor_l2_cache_selected_level = clampi(roundi(value), 0, processor_l2_cache_research_level)
	_refresh_processor_l2_cache_controls()


func _refresh_processor_l2_cache_controls() -> void:
	processor_l2_cache_selected_level = clampi(processor_l2_cache_selected_level, 0, processor_l2_cache_research_level)
	var selected_capacity := ResearchManagerScript.L2_CACHE_BASE_CAPACITY_KB + processor_l2_cache_selected_level * ResearchManagerScript.L2_CACHE_RESEARCH_INCREMENT_KB
	var maximum_capacity := ResearchManagerScript.L2_CACHE_BASE_CAPACITY_KB + processor_l2_cache_research_level * ResearchManagerScript.L2_CACHE_RESEARCH_INCREMENT_KB
	if is_instance_valid(processor_l2_cache_slider):
		processor_l2_cache_slider.min_value = 0
		processor_l2_cache_slider.max_value = processor_l2_cache_research_level
		if not is_equal_approx(processor_l2_cache_slider.value, float(processor_l2_cache_selected_level)):
			processor_l2_cache_slider.set_value_no_signal(processor_l2_cache_selected_level)
	if is_instance_valid(processor_l2_cache_value_label):
		processor_l2_cache_value_label.text = "%d KB" % selected_capacity
	if is_instance_valid(processor_l2_cache_range_label):
		processor_l2_cache_range_label.text = "AVAILABLE RANGE: 128–%d KB" % maximum_capacity
	_refresh_processor_technology_level_display()


func _build_processor_l3_cache_controls(parent: VBoxContainer) -> void:
	processor_l3_cache_step_content = VBoxContainer.new()
	processor_l3_cache_step_content.name = "ProcessorL3CacheStepContent"
	processor_l3_cache_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_l3_cache_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_l3_cache_step_content.alignment = BoxContainer.ALIGNMENT_CENTER
	processor_l3_cache_step_content.add_theme_constant_override("separation", 18)
	parent.add_child(processor_l3_cache_step_content)
	var description := _label("SELECT L3 CACHE CAPACITY", 12, MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l3_cache_step_content.add_child(description)
	processor_l3_cache_value_label = _label("1,024 KB", 30, Color("#F2EEE7"))
	processor_l3_cache_value_label.name = "ProcessorL3CacheCapacityValue"
	processor_l3_cache_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l3_cache_step_content.add_child(processor_l3_cache_value_label)
	var slider_row := HBoxContainer.new()
	slider_row.name = "ProcessorL3CacheSliderRow"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.add_theme_constant_override("separation", 12)
	processor_l3_cache_step_content.add_child(slider_row)
	var minimum_label := _label("1,024 KB", 12, MUTED)
	minimum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(minimum_label)
	processor_l3_cache_slider = HSlider.new()
	processor_l3_cache_slider.name = "ProcessorL3CacheSlider"
	processor_l3_cache_slider.min_value = 0
	processor_l3_cache_slider.max_value = processor_l3_cache_research_level
	processor_l3_cache_slider.step = 1
	processor_l3_cache_slider.value = processor_l3_cache_selected_level
	processor_l3_cache_slider.custom_minimum_size = Vector2(0, 46)
	processor_l3_cache_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_l3_cache_slider.focus_mode = Control.FOCUS_NONE
	processor_l3_cache_slider.tick_count = 0
	_style_processor_cpu_core_slider(processor_l3_cache_slider)
	processor_l3_cache_slider.value_changed.connect(_on_processor_l3_cache_slider_changed)
	slider_row.add_child(processor_l3_cache_slider)
	var maximum_label := _label("153,600 KB", 12, MUTED)
	maximum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider_row.add_child(maximum_label)
	processor_l3_cache_range_label = _label("AVAILABLE RANGE: 1,024–1,024 KB", 11, ACCENT)
	processor_l3_cache_range_label.name = "ProcessorL3CacheRangeLabel"
	processor_l3_cache_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_l3_cache_step_content.add_child(processor_l3_cache_range_label)
	_refresh_processor_l3_cache_controls()


func _on_processor_l3_cache_slider_changed(value: float) -> void:
	processor_l3_cache_selected_level = clampi(roundi(value), 0, processor_l3_cache_research_level)
	_refresh_processor_l3_cache_controls()


func _refresh_processor_l3_cache_controls() -> void:
	processor_l3_cache_selected_level = clampi(processor_l3_cache_selected_level, 0, processor_l3_cache_research_level)
	var selected_capacity := ResearchManagerScript.L3_CACHE_BASE_CAPACITY_KB + processor_l3_cache_selected_level * ResearchManagerScript.L3_CACHE_RESEARCH_INCREMENT_KB
	var maximum_capacity := ResearchManagerScript.L3_CACHE_BASE_CAPACITY_KB + processor_l3_cache_research_level * ResearchManagerScript.L3_CACHE_RESEARCH_INCREMENT_KB
	if is_instance_valid(processor_l3_cache_slider):
		processor_l3_cache_slider.min_value = 0
		processor_l3_cache_slider.max_value = processor_l3_cache_research_level
		if not is_equal_approx(processor_l3_cache_slider.value, float(processor_l3_cache_selected_level)):
			processor_l3_cache_slider.set_value_no_signal(processor_l3_cache_selected_level)
	if is_instance_valid(processor_l3_cache_value_label):
		processor_l3_cache_value_label.text = "%d KB" % selected_capacity
	if is_instance_valid(processor_l3_cache_range_label):
		processor_l3_cache_range_label.text = "AVAILABLE RANGE: 1,024–%d KB" % maximum_capacity
	_refresh_processor_technology_level_display()


func _refresh_processor_technology_level_display() -> void:
	if is_instance_valid(processor_technology_level_value_label):
		processor_technology_level_value_label.text = "%.2f TP" % _calculate_processor_technology_points()


func _calculate_processor_technology_points() -> float:
	var total := 0.0
	for technology_value in PROCESSOR_TECHNOLOGIES:
		var technology_name := str(technology_value)
		if int(processor_technology_research_levels.get(technology_name, 0)) >= 1 and bool(processor_technology_enabled_states.get(technology_name, false)):
			total += ResearchManagerScript.get_technology_points_for_progress(technology_name, 1.0)
	total += ResearchManagerScript.get_technology_points_for_progress("CPU Cores", float(maxi(0, processor_cpu_core_count - 1)))
	total += ResearchManagerScript.get_technology_points_for_progress("Instruction Scheduler", float(processor_instruction_scheduler_selected_level))
	total += ResearchManagerScript.get_technology_points_for_progress("L1 Cache", float(processor_l1_cache_selected_level))
	total += ResearchManagerScript.get_technology_points_for_progress("L2 Cache", float(processor_l2_cache_selected_level))
	total += ResearchManagerScript.get_technology_points_for_progress("L3 Cache", float(processor_l3_cache_selected_level))
	total += ResearchManagerScript.get_technology_points_for_progress("Processor Design", float(maxi(0, selected_design_index)))
	return maxf(0.0, total)


func _build_processor_technology_controls(parent: VBoxContainer) -> void:
	processor_technology_step_content = VBoxContainer.new()
	processor_technology_step_content.name = "ProcessorTechnologyStepContent"
	processor_technology_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_technology_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_technology_step_content.custom_minimum_size = Vector2(0, 300)
	processor_technology_step_content.add_theme_constant_override("separation", 14)
	parent.add_child(processor_technology_step_content)

	var enable_row := HBoxContainer.new()
	enable_row.name = "ProcessorTechnologyEnableRow"
	enable_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.custom_minimum_size = Vector2(124, 42)
	enable_row.add_theme_constant_override("separation", 8)
	processor_technology_step_content.add_child(enable_row)

	processor_technology_enable_label = _label("ENABLE", 14, TEXT)
	processor_technology_enable_label.name = "ProcessorTechnologyEnableLabel"
	processor_technology_enable_label.custom_minimum_size = Vector2(72, 0)
	processor_technology_enable_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	processor_technology_enable_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	processor_technology_enable_label.clip_text = true
	enable_row.add_child(processor_technology_enable_label)

	processor_technology_checked_texture = _processor_checkbox_icon(true)
	processor_technology_unchecked_texture = _processor_checkbox_icon(false)
	processor_technology_enabled_toggle = TextureButton.new()
	processor_technology_enabled_toggle.name = "ProcessorTechnologyEnabledToggle"
	processor_technology_enabled_toggle.custom_minimum_size = Vector2(42, 42)
	processor_technology_enabled_toggle.ignore_texture_size = true
	processor_technology_enabled_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	processor_technology_enabled_toggle.toggle_mode = true
	processor_technology_enabled_toggle.focus_mode = Control.FOCUS_NONE
	processor_technology_enabled_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	processor_technology_enabled_toggle.texture_normal = processor_technology_unchecked_texture
	processor_technology_enabled_toggle.texture_hover = processor_technology_unchecked_texture
	processor_technology_enabled_toggle.texture_pressed = processor_technology_checked_texture
	processor_technology_enabled_toggle.texture_disabled = processor_technology_unchecked_texture
	processor_technology_enabled_toggle.toggled.connect(_on_processor_technology_toggled)
	enable_row.add_child(processor_technology_enabled_toggle)

	var navigation_center := CenterContainer.new()
	navigation_center.name = "ProcessorTechnologyNavigationCenter"
	navigation_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_technology_step_content.add_child(navigation_center)

	var navigation := HBoxContainer.new()
	navigation.name = "ProcessorTechnologyNavigation"
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 30)
	navigation_center.add_child(navigation)

	processor_technology_previous_button = Button.new()
	processor_technology_previous_button.name = "PreviousProcessorTechnologyButton"
	processor_technology_previous_button.text = "−"
	processor_technology_previous_button.custom_minimum_size = Vector2(56, 48)
	processor_technology_previous_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(processor_technology_previous_button, false)
	processor_technology_previous_button.pressed.connect(_on_processor_technology_previous_pressed)
	navigation.add_child(processor_technology_previous_button)

	processor_technology_name_label = _label(PROCESSOR_TECHNOLOGIES[0], 19, TEXT)
	processor_technology_name_label.name = "SelectedProcessorTechnology"
	processor_technology_name_label.custom_minimum_size = Vector2(150, 56)
	processor_technology_name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	processor_technology_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	processor_technology_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	processor_technology_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	processor_technology_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	navigation.add_child(processor_technology_name_label)

	processor_technology_next_button = Button.new()
	processor_technology_next_button.name = "NextProcessorTechnologyButton"
	processor_technology_next_button.text = "+"
	processor_technology_next_button.custom_minimum_size = Vector2(56, 48)
	processor_technology_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(processor_technology_next_button, false)
	processor_technology_next_button.pressed.connect(_on_processor_technology_next_pressed)
	navigation.add_child(processor_technology_next_button)

	for technology_value in PROCESSOR_TECHNOLOGIES:
		processor_technology_enabled_states[str(technology_value)] = false
	_refresh_processor_technology_controls()


func _refresh_processor_technology_controls() -> void:
	if PROCESSOR_TECHNOLOGIES.is_empty():
		return
	processor_technology_selected_index = clampi(processor_technology_selected_index, 0, PROCESSOR_TECHNOLOGIES.size() - 1)
	var technology_name: String = PROCESSOR_TECHNOLOGIES[processor_technology_selected_index]
	var researched := int(processor_technology_research_levels.get(technology_name, 0)) >= 1
	var enabled := researched and bool(processor_technology_enabled_states.get(technology_name, false))
	if is_instance_valid(processor_technology_name_label):
		processor_technology_name_label.text = technology_name
	if is_instance_valid(processor_technology_enable_label):
		processor_technology_enable_label.text = "ENABLE" if researched else "LOCKED"
	if is_instance_valid(processor_technology_enabled_toggle):
		processor_technology_enabled_toggle.disabled = not researched
		processor_technology_enabled_toggle.modulate.a = 1.0 if researched else 0.42
		processor_technology_enabled_toggle.set_pressed_no_signal(enabled)
		var checkbox_texture := processor_technology_checked_texture if enabled else processor_technology_unchecked_texture
		processor_technology_enabled_toggle.texture_normal = checkbox_texture
		processor_technology_enabled_toggle.texture_hover = checkbox_texture
		processor_technology_enabled_toggle.texture_pressed = processor_technology_checked_texture
		processor_technology_enabled_toggle.texture_disabled = processor_technology_unchecked_texture
		processor_technology_enabled_toggle.tooltip_text = ("Enable or disable " + technology_name) if researched else ("Research " + technology_name + " to unlock it")
	if is_instance_valid(processor_technology_previous_button):
		processor_technology_previous_button.disabled = processor_technology_selected_index <= 0
	if is_instance_valid(processor_technology_next_button):
		processor_technology_next_button.disabled = processor_technology_selected_index >= PROCESSOR_TECHNOLOGIES.size() - 1
	if not researched:
		processor_technology_enabled_states[technology_name] = false
	_refresh_processor_technology_level_display()


func _on_processor_technology_toggled(enabled: bool) -> void:
	if PROCESSOR_TECHNOLOGIES.is_empty():
		return
	var technology_name: String = PROCESSOR_TECHNOLOGIES[clampi(processor_technology_selected_index, 0, PROCESSOR_TECHNOLOGIES.size() - 1)]
	if int(processor_technology_research_levels.get(technology_name, 0)) < 1:
		processor_technology_enabled_states[technology_name] = false
		_refresh_processor_technology_controls()
		return
	processor_technology_enabled_states[technology_name] = enabled
	_refresh_processor_technology_controls()
	_refresh_processor_technology_level_display()


func _on_processor_technology_previous_pressed() -> void:
	processor_technology_selected_index = maxi(0, processor_technology_selected_index - 1)
	_refresh_processor_technology_controls()


func _on_processor_technology_next_pressed() -> void:
	processor_technology_selected_index = mini(PROCESSOR_TECHNOLOGIES.size() - 1, processor_technology_selected_index + 1)
	_refresh_processor_technology_controls()


func _apply_responsive_layout() -> void:
	if not is_instance_valid(worksite_body) or not is_instance_valid(preview_region) or not is_instance_valid(selection_scroll) or not is_instance_valid(right_panel_column):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var is_wide := viewport_size.x >= viewport_size.y and viewport_size.x >= 700.0
	worksite_body.vertical = not is_wide
	if is_wide:
		preview_region.size_flags_stretch_ratio = 1.12
		right_panel_column.size_flags_stretch_ratio = 0.88
		preview_region.custom_minimum_size = Vector2(0, 0)
		preview_holder.custom_minimum_size = Vector2(0, 245)
		right_panel_column.custom_minimum_size = Vector2(280, 0)
		selection_scroll.custom_minimum_size = Vector2(0, 0)
		selection_region.add_theme_constant_override("margin_left", 24)
		selection_region.add_theme_constant_override("margin_right", 24)
		selection_region.add_theme_constant_override("margin_top", 20)
		selection_region.add_theme_constant_override("margin_bottom", 20)
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		right_panel_column.size_flags_stretch_ratio = 1.18
		preview_region.custom_minimum_size = Vector2(0, maxf(140.0, viewport_size.y * 0.24))
		right_panel_column.custom_minimum_size = Vector2(0, maxf(300.0, viewport_size.y * 0.52))
		selection_scroll.custom_minimum_size = Vector2(0, 0)
		selection_region.add_theme_constant_override("margin_left", 20)
		selection_region.add_theme_constant_override("margin_right", 20)
		selection_region.add_theme_constant_override("margin_top", 14)
		selection_region.add_theme_constant_override("margin_bottom", 14)


func _set_wizard_step(step: int) -> void:
	current_wizard_step = clampi(step, 1, WIZARD_STEP_COUNT)
	for index in range(step_pages.size()):
		step_pages[index].visible = index == current_wizard_step - 1
	if is_instance_valid(progress_number):
		progress_number.text = "STEP %d / %d" % [current_wizard_step, WIZARD_STEP_COUNT]
	if is_instance_valid(progress_bar):
		progress_bar.max_value = WIZARD_STEP_COUNT
		progress_bar.value = current_wizard_step
	if is_instance_valid(wizard_back_button):
		wizard_back_button.disabled = current_wizard_step <= 1
		wizard_back_button.modulate.a = 0.42 if wizard_back_button.disabled else 1.0
	if is_instance_valid(next_button):
		next_button.disabled = current_wizard_step >= WIZARD_STEP_COUNT
		next_button.modulate.a = 0.42 if next_button.disabled else 1.0


func _on_wizard_back_pressed() -> void:
	if current_wizard_step > 1:
		_set_wizard_step(current_wizard_step - 1)


func _on_next_pressed() -> void:
	if current_wizard_step < WIZARD_STEP_COUNT:
		_set_wizard_step(current_wizard_step + 1)


func _build_processor_preview() -> void:
	# Match the Phone Creation Worksite preview composition:
	# a transparent SubViewport reveals the shared charcoal WorksiteBackdrop,
	# while a procedural studio sky remains available for ambient/reflected light.
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	var studio_sky := Sky.new()
	var studio_sky_material := ProceduralSkyMaterial.new()
	studio_sky_material.sky_top_color = Color("#77736C")
	studio_sky_material.sky_horizon_color = Color("#D5CFC3")
	studio_sky_material.ground_horizon_color = Color("#716C63")
	studio_sky_material.ground_bottom_color = Color("#34312D")
	studio_sky_material.sky_energy_multiplier = 0.9
	studio_sky_material.ground_energy_multiplier = 0.72
	studio_sky_material.sun_angle_max = 0.0
	studio_sky_material.sun_curve = 0.08
	studio_sky.sky_material = studio_sky_material
	studio_sky.radiance_size = Sky.RADIANCE_SIZE_128

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.sky = studio_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#B6B0A5")
	environment.ambient_light_energy = 0.66
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment_node.environment = environment
	preview_viewport.add_child(environment_node)

	# All 3D preview content is grouped under one world root, just like
	# PhonePreviewWorld. There is deliberately no physical floor/platform:
	# the transparent viewport exposes the shared #292B2D worksite backdrop.
	processor_preview_world = Node3D.new()
	processor_preview_world.name = "ProcessorPreviewWorld"
	preview_viewport.add_child(processor_preview_world)

	var camera := Camera3D.new()
	camera.name = "ProcessorStudioCamera"
	# Keep the processor-specific elevated angle so its upper die and package
	# edges remain visible; only the environment/background is shared.
	camera.position = Vector3(0.0, 2.45, 6.0)
	camera.fov = 36.0
	camera.near = 0.05
	camera.far = 100.0
	processor_preview_world.add_child(camera)
	camera.look_at(Vector3(0.0, 0.015, 0.0), Vector3.UP)
	camera.make_current()
	preview_camera = camera

	# Match the Phone Worksite's neutral studio key, soft rim and restrained fill.
	var key_light := DirectionalLight3D.new()
	key_light.name = "PhoneStyleStudioKeyLight"
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_color = Color("#fffdf8")
	key_light.light_energy = 1.20
	key_light.shadow_enabled = false
	processor_preview_world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "PhoneStyleStudioRimLight"
	rim_light.rotation_degrees = Vector3(18.0, 142.0, -8.0)
	rim_light.light_color = Color("#C7BBA6")
	rim_light.light_energy = 0.78
	rim_light.shadow_enabled = false
	processor_preview_world.add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "PhoneStyleStudioFillLight"
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#D8D1C5")
	fill_light.light_energy = 0.38
	fill_light.omni_range = 8.0
	processor_preview_world.add_child(fill_light)

	# Construct and retain all thirty models under the world root during
	# initialization. Selection only toggles visibility after this point.
	processor_designs.clear()
	for design_value in ProcessorDesignLibrary.DESIGNS:
		var design_profile: Dictionary = design_value
		processor_designs.append(design_profile.duplicate(true))
	var prebuilt_designs_root := Node3D.new()
	prebuilt_designs_root.name = "PrebuiltProcessorDesigns"
	processor_preview_world.add_child(prebuilt_designs_root)
	processor_models_data = ProcessorDesignLibrary.build_all(prebuilt_designs_root)
	_select_processor_design(0, true)


func _style_design_selector_button(button: Button) -> void:
	_style_button(button, false)
	button.custom_minimum_size = Vector2(56, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE


func _on_processor_design_decrease_pressed() -> void:
	_select_processor_design(selected_design_index - 1, true)


func _on_processor_design_increase_pressed() -> void:
	_select_processor_design(selected_design_index + 1, true)


func _select_processor_design(index: int, reset_to_preset: bool = true) -> void:
	if processor_models_data.is_empty() or processor_designs.is_empty():
		return
	var preserved_rotation := processor_root.rotation if is_instance_valid(processor_root) else DEFAULT_VIEW_ROTATION
	var maximum_selectable_design_count := mini(mini(processor_models_data.size(), processor_designs.size()), _get_maximum_processor_design_count())
	selected_design_index = clampi(index, 0, maximum_selectable_design_count - 1)
	for model_index in range(processor_models_data.size()):
		var model_root := processor_models_data[model_index].get("root") as Node3D
		if is_instance_valid(model_root):
			model_root.visible = model_index == selected_design_index
			if model_index == selected_design_index:
				model_root.rotation = preserved_rotation
				model_root.scale = Vector3.ONE

	var selected_model: Dictionary = processor_models_data[selected_design_index]
	var selected_profile: Dictionary = processor_designs[selected_design_index]
	processor_root = selected_model.get("root") as Node3D
	package_layers.clear()
	for layer_value in selected_model.get("package_layers", []):
		if layer_value is MeshInstance3D:
			package_layers.append(layer_value)
	die_surfaces.clear()
	for surface_value in selected_model.get("die_surfaces", []):
		if surface_value is MeshInstance3D:
			die_surfaces.append(surface_value)
	die_surface = die_surfaces[0] if not die_surfaces.is_empty() else null

	if reset_to_preset:
		if is_instance_valid(package_size):
			_select_option(package_size, str(selected_profile.get("package_size", "12 × 12 mm")))

	# Apply the selected design's default package size and current colour.
	_refresh_processor_design_controls()
	_apply_design()
	_refresh_processor_technology_level_display()


func _refresh_processor_design_controls() -> void:
	if selected_design_index < 0 or selected_design_index >= processor_designs.size():
		return
	var profile: Dictionary = processor_designs[selected_design_index]
	if is_instance_valid(design_value_label):
		design_value_label.text = str(profile.get("name", "DW PROCESSOR"))
	if is_instance_valid(design_position_label):
		design_position_label.text = "DESIGN %02d / %02d" % [selected_design_index + 1, processor_designs.size()]
	if is_instance_valid(design_decrease_button):
		design_decrease_button.disabled = selected_design_index <= 0
	if is_instance_valid(design_increase_button):
		design_increase_button.disabled = selected_design_index >= _get_maximum_processor_design_count() - 1

func _build_package_body() -> void:
	# The stepped package layers create the thin laminated edge visible on real SoC packages.
	var lower_edge := _add_box(processor_root, Vector3(2.30, 0.035, 2.30), Vector3(0.0, -0.075, 0.0), _material(Color("#11191B"), 0.36, 0.34), "PackageLowerEdge")
	var core := _add_box(processor_root, Vector3(2.26, 0.135, 2.26), Vector3(0.0, 0.005, 0.0), _material(Color("#1D302D"), 0.42, 0.38), "PackageSubstrate")
	var top_mask := _add_box(processor_root, Vector3(2.22, 0.022, 2.22), Vector3(0.0, 0.082, 0.0), _material(Color("#203B34"), 0.32, 0.34), "TopSolderMask")
	package_layers = [lower_edge, core, top_mask]

	# Very restrained edge strata and corner fiducials add scale without turning the chip into a fantasy prop.
	var copper := _material(Color("#B58B4C"), 0.82, 0.25)
	for side in [-1.0, 1.0]:
		for index in range(6):
			var along := -0.72 + float(index) * 0.288
			_add_box(processor_root, Vector3(0.10, 0.008, 0.014), Vector3(along, 0.096, side * 1.075), copper, "TopEdgeTrace")
			_add_box(processor_root, Vector3(0.014, 0.008, 0.10), Vector3(side * 1.075, 0.096, along), copper, "SideEdgeTrace")

func _build_top_die_and_passives() -> void:
	var frame_material := _material(Color("#6C604B"), 0.72, 0.28)
	_add_box(processor_root, Vector3(1.49, 0.025, 1.49), Vector3(0.0, 0.111, 0.0), frame_material, "DieBondFrame")
	_add_box(processor_root, Vector3(1.39, 0.045, 1.39), Vector3(0.0, 0.145, 0.0), _material(Color("#20272C"), 0.38, 0.30), "SiliconDie")
	die_surface = _add_box(processor_root, Vector3(1.32, 0.012, 1.32), Vector3(0.0, 0.173, 0.0), _material(Color("#171D22"), 0.32, 0.24), "SiliconDieSurface")

	var frame_gold := _material(Color("#C69A55"), 0.86, 0.22)
	for side in [-1.0, 1.0]:
		_add_box(processor_root, Vector3(1.44, 0.007, 0.012), Vector3(0.0, 0.126, side * 0.728), frame_gold, "DieFrameEdge")
		_add_box(processor_root, Vector3(0.012, 0.007, 1.44), Vector3(side * 0.728, 0.126, 0.0), frame_gold, "DieFrameEdge")

	# Fine, low-profile passives on the package rim.
	var ceramic := _material(Color("#B6B4A8"), 0.18, 0.30)
	var terminal := _material(Color("#B58C51"), 0.78, 0.23)
	for index in range(4):
		var along := -0.78 + float(index) * 0.52
		_add_smd_component(Vector3(along, 0.118, 0.91), ceramic, terminal)
		_add_smd_component(Vector3(along, 0.118, -0.91), ceramic, terminal)
		_add_smd_component(Vector3(0.91, 0.118, along), ceramic, terminal)
		_add_smd_component(Vector3(-0.91, 0.118, along), ceramic, terminal)

	_add_top_marking("DW", 46, Vector3(0.0, 0.181, -0.12), Color("#C7C9C5"), 0.0042)
	_add_top_marking("SILICON 01", 19, Vector3(0.0, 0.181, 0.20), Color("#AAB1B4"), 0.0032)
	_add_top_marking("MOBILE COMPUTE  ·  REV A", 9, Vector3(0.0, 0.181, 0.36), Color("#78858A"), 0.0023)

func _add_smd_component(at: Vector3, body_material: StandardMaterial3D, terminal_material: StandardMaterial3D) -> void:
	_add_box(processor_root, Vector3(0.14, 0.035, 0.075), at, body_material, "SurfaceMountPassive")
	for side in [-1.0, 1.0]:
		_add_box(processor_root, Vector3(0.018, 0.039, 0.078), at + Vector3(side * 0.068, 0.0, 0.0), terminal_material, "PassiveMetalEnd")

func _add_top_marking(value: String, font_size_value: int, at: Vector3, color: Color, pixel_size_value: float) -> void:
	var marking := Label3D.new()
	marking.name = "LaserEtchedMarking_Logo" if value == "DW" else ("LaserEtchedMarking_Product" if value == "SILICON 01" else "LaserEtchedMarking_Revision")
	marking.text = value
	marking.font_size = font_size_value
	marking.pixel_size = pixel_size_value
	marking.modulate = color
	marking.shaded = true
	marking.no_depth_test = false
	marking.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marking.position = at
	processor_root.add_child(marking)

func _build_bottom_contacts() -> void:
	# Real phone SoCs use a ball-grid package: hundreds of tiny contacts on the underside.
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.034
	ball_mesh.height = 0.068
	ball_mesh.radial_segments = 10
	ball_mesh.rings = 6
	var contacts := MultiMesh.new()
	contacts.transform_format = MultiMesh.TRANSFORM_3D
	contacts.mesh = ball_mesh
	const GRID_COUNT := 15
	contacts.instance_count = GRID_COUNT * GRID_COUNT
	var instance_index := 0
	for row in range(GRID_COUNT):
		for column in range(GRID_COUNT):
			var x := (float(column) - float(GRID_COUNT - 1) * 0.5) * 0.142
			var z := (float(row) - float(GRID_COUNT - 1) * 0.5) * 0.142
			contacts.set_instance_transform(instance_index, Transform3D(Basis.IDENTITY, Vector3(x, -0.126, z)))
			instance_index += 1
	var contact_array := MultiMeshInstance3D.new()
	contact_array.name = "UndersideBGAContactArray"
	contact_array.multimesh = contacts
	contact_array.material_override = _material(Color("#D3A957"), 0.91, 0.20)
	processor_root.add_child(contact_array)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		drag_active = event.pressed
	elif event is InputEventScreenDrag and drag_active:
		_rotate_preview(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_active = event.pressed
	elif event is InputEventMouseMotion and drag_active:
		_rotate_preview(event.relative)

func _rotate_preview(relative: Vector2) -> void:
	if not is_instance_valid(processor_root):
		return
	if absf(relative.x) >= absf(relative.y):
		processor_root.rotation.y += relative.x * DRAG_SENSITIVITY
	else:
		processor_root.rotation.x += relative.y * DRAG_SENSITIVITY

func _on_design_changed(_value: Variant = null) -> void:
	_apply_design()
	if is_instance_valid(status_label):
		status_label.text = "UNSAVED DESIGN CHANGES"

func _apply_design() -> void:
	if not is_instance_valid(processor_root):
		return
	# Package dimensions are no longer a creation step. Keep the selected
	# preset at its native size while preserving legacy saved package metadata.
	processor_root.scale = Vector3.ONE
	_apply_processor_color()


func _parse_saved_processor_color(value: String, fallback: Color) -> Color:
	var cleaned := value.strip_edges()
	if LEGACY_PROCESSOR_COLORS.has(cleaned):
		return LEGACY_PROCESSOR_COLORS[cleaned]
	var hex_value := cleaned.trim_prefix("#")
	if Color.html_is_valid(hex_value):
		return Color.from_string("#" + hex_value, fallback)
	return fallback


func _processor_gradient_direction_name(index: int) -> String:
	var names := ["VERTICAL", "HORIZONTAL", "DIAGONAL", "RADIAL"]
	return names[clampi(index, 0, names.size() - 1)]


func _processor_checkbox_icon(checked: bool) -> Texture2D:
	var image := Image.new()
	var svg := ""
	if checked:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect x="2.5" y="2.5" width="31" height="31" rx="7" fill="#C58A3A" fill-opacity="0.30" stroke="#C58A3A" stroke-width="2.5"/><path d="M9 18.5l6 6L27.5 12" fill="none" stroke="#ffffff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/></svg>"""
	else:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36"><rect x="2.5" y="2.5" width="31" height="31" rx="7" fill="#C58A3A" fill-opacity="0.10" stroke="#C58A3A" stroke-width="2.5"/></svg>"""
	var error := image.load_svg_from_string(svg)
	if error != OK:
		push_warning("Could not create processor colour checkbox icon")
		return null
	return ImageTexture.create_from_image(image)


func _style_processor_staff_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.27, 0.18, 0.09, 0.90) if primary else Color(0.12, 0.13, 0.14, 0.82)
		if state == "hover":
			style.bg_color = Color(0.38, 0.25, 0.12, 0.94) if primary else Color(0.21, 0.22, 0.23, 0.88)
		elif state == "pressed":
			style.bg_color = Color(0.17, 0.11, 0.06, 0.98) if primary else Color(0.08, 0.09, 0.10, 0.94)
		elif state == "disabled":
			style.bg_color = Color(0.10, 0.11, 0.12, 0.58)
		style.border_color = Color(0.80, 0.60, 0.32, 0.78) if primary else Color(0.72, 0.72, 0.68, 0.34)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#A9A092"))


func _clear_processor_color_step_host() -> void:
	if not is_instance_valid(processor_color_step_host):
		return
	for child in processor_color_step_host.get_children():
		processor_color_step_host.remove_child(child)
		child.queue_free()


func _build_processor_color_controls() -> void:
	_clear_processor_color_step_host()
	processor_color_content = VBoxContainer.new()
	processor_color_content.name = "ProcessorColorControls"
	processor_color_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processor_color_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processor_color_content.add_theme_constant_override("separation", 6)
	processor_color_step_host.add_child(processor_color_content)

	var gradient_toggle_row := HBoxContainer.new()
	gradient_toggle_row.name = "EnableProcessorGradientRow"
	gradient_toggle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_toggle_row.add_theme_constant_override("separation", 6)
	processor_color_content.add_child(gradient_toggle_row)

	var gradient_toggle_label := _label("ENABLE GRADIENT", 13, Color("#D3AA6B"))
	gradient_toggle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gradient_toggle_row.add_child(gradient_toggle_label)

	worksite_color_gradient_toggle = TextureButton.new()
	worksite_color_gradient_toggle.name = "EnableProcessorGradient"
	worksite_color_gradient_toggle.custom_minimum_size = Vector2(36, 36)
	worksite_color_gradient_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	worksite_color_gradient_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	worksite_color_gradient_toggle.ignore_texture_size = true
	worksite_color_gradient_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	worksite_color_gradient_toggle.texture_normal = _processor_checkbox_icon(false)
	worksite_color_gradient_toggle.texture_hover = _processor_checkbox_icon(false)
	worksite_color_gradient_toggle.texture_pressed = _processor_checkbox_icon(true)
	worksite_color_gradient_toggle.toggle_mode = true
	worksite_color_gradient_toggle.button_pressed = processor_gradient_enabled
	worksite_color_gradient_toggle.focus_mode = Control.FOCUS_NONE
	worksite_color_gradient_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	worksite_color_gradient_toggle.pressed.connect(_on_processor_gradient_toggle_pressed.bind(worksite_color_gradient_toggle))
	gradient_toggle_row.add_child(worksite_color_gradient_toggle)

	var gradient_options := VBoxContainer.new()
	gradient_options.name = "ProcessorGradientOptions"
	gradient_options.add_theme_constant_override("separation", 7)
	gradient_options.visible = processor_gradient_enabled
	processor_color_content.add_child(gradient_options)

	gradient_direction_button = Button.new()
	gradient_direction_button.name = "ProcessorGradientDirection"
	gradient_direction_button.text = "GRADIENT DIRECTION  ·  " + _processor_gradient_direction_name(processor_gradient_direction)
	gradient_direction_button.custom_minimum_size.y = 40
	gradient_direction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_direction_button.focus_mode = Control.FOCUS_NONE
	_style_processor_staff_button(gradient_direction_button, false)
	gradient_direction_button.pressed.connect(_show_processor_gradient_direction_controls)
	gradient_options.add_child(gradient_direction_button)

	var picker_columns := HBoxContainer.new()
	picker_columns.name = "ProcessorColorPickerColumns"
	picker_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_columns.add_theme_constant_override("separation", 12)
	processor_color_content.add_child(picker_columns)

	var color_viewport_size := get_viewport().get_visible_rect().size
	picker_columns.add_child(_build_processor_color_picker_panel(false, color_viewport_size))
	picker_columns.add_child(_build_processor_color_picker_panel(true, color_viewport_size))
	var gradient_picker := picker_columns.get_node_or_null("ProcessorGradientColorPicker") as Control
	_set_processor_gradient_picker_enabled(gradient_picker, processor_gradient_enabled)


func _build_processor_color_picker_panel(use_gradient_color: bool, viewport_size: Vector2) -> VBoxContainer:
	var picker := VBoxContainer.new()
	picker.name = "ProcessorGradientColorPicker" if use_gradient_color else "ProcessorNormalColorPicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picker.add_theme_constant_override("separation", 5)
	var heading := _label("GRADIENT" if use_gradient_color else "NORMAL", 14, Color("#D3AA6B"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker.add_child(heading)
	var selected_color := processor_gradient_color if use_gradient_color else processor_color
	picker.add_child(_label("COLOR SPECTRUM", 11, Color("#C58A3A")))

	var spectrum := DeviceColorSpectrum.new()
	spectrum.name = "ProcessorColorSpectrum"
	spectrum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectrum.custom_minimum_size = Vector2(0, clampf(viewport_size.y * 0.22, 125.0, 175.0))
	spectrum.set_color_value(selected_color)
	spectrum.color_changed.connect(_on_processor_color_picker_changed.bind(use_gradient_color))
	picker.add_child(spectrum)

	picker.add_child(_label("HUE", 11, Color("#C58A3A")))
	var hue_bar := DeviceHueBar.new()
	hue_bar.name = "ProcessorColorHue"
	hue_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hue_bar.set_hue(selected_color.h)
	hue_bar.hue_changed.connect(_on_processor_color_picker_hue_changed.bind(use_gradient_color))
	picker.add_child(hue_bar)

	var selected_label := _label("#" + selected_color.to_html(false).to_upper(), 12, Color("#EEE9DF"))
	selected_label.name = "ProcessorSelectedColorHex"
	picker.add_child(selected_label)
	picker.add_child(_label("HEX CODE", 11, Color("#C58A3A")))

	var hex_row := HBoxContainer.new()
	hex_row.name = "ProcessorCustomHexEntry"
	hex_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_row.add_theme_constant_override("separation", 5)
	picker.add_child(hex_row)

	var hex_input := LineEdit.new()
	hex_input.name = "ProcessorColorHexInput"
	hex_input.placeholder_text = "#RRGGBB"
	hex_input.text = selected_color.to_html(false).to_upper()
	hex_input.max_length = 7
	hex_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hex_input.custom_minimum_size = Vector2(0, 36)
	hex_input.add_theme_color_override("font_color", Color("#EEE9DF"))
	hex_input.add_theme_color_override("font_placeholder_color", Color("#928B80"))
	hex_input.add_theme_color_override("caret_color", Color("#C58A3A"))
	var hex_normal := StyleBoxFlat.new()
	hex_normal.bg_color = Color("#202326")
	hex_normal.set_corner_radius_all(7)
	hex_normal.set_border_width_all(1)
	hex_normal.border_color = Color("#514B40")
	hex_normal.content_margin_left = 7.0
	hex_normal.content_margin_right = 7.0
	var hex_focus := hex_normal.duplicate() as StyleBoxFlat
	hex_focus.border_color = Color("#C58A3A")
	hex_focus.set_border_width_all(2)
	hex_input.add_theme_stylebox_override("normal", hex_normal)
	hex_input.add_theme_stylebox_override("focus", hex_focus)
	hex_input.add_theme_stylebox_override("read_only", hex_normal)
	hex_row.add_child(hex_input)

	var apply_button := Button.new()
	apply_button.name = "ApplyProcessorHex"
	apply_button.text = "APPLY"
	apply_button.custom_minimum_size = Vector2(58, 36)
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.add_theme_font_size_override("font_size", 11)
	_style_processor_staff_button(apply_button, true)
	hex_row.add_child(apply_button)
	apply_button.pressed.connect(_on_processor_color_hex_apply.bind(hex_input, use_gradient_color))
	hex_input.text_submitted.connect(_on_processor_color_hex_text_submitted.bind(use_gradient_color))
	return picker


func _set_processor_gradient_picker_enabled(picker: Control, enabled: bool) -> void:
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


func _refresh_processor_color_controls() -> void:
	if not is_instance_valid(processor_color_content):
		return
	for use_gradient_color in [false, true]:
		var picker_name := "ProcessorGradientColorPicker" if use_gradient_color else "ProcessorNormalColorPicker"
		var picker := processor_color_content.get_node_or_null("ProcessorColorPickerColumns/" + picker_name)
		if not is_instance_valid(picker):
			continue
		var selected_color := processor_gradient_color if use_gradient_color else processor_color
		var spectrum := picker.get_node_or_null("ProcessorColorSpectrum") as DeviceColorSpectrum
		if is_instance_valid(spectrum):
			spectrum.set_color_value(selected_color)
		var hue_bar := picker.get_node_or_null("ProcessorColorHue") as DeviceHueBar
		if is_instance_valid(hue_bar):
			hue_bar.set_hue(selected_color.h)
		var hex_label := picker.get_node_or_null("ProcessorSelectedColorHex") as Label
		if is_instance_valid(hex_label):
			hex_label.text = "#" + selected_color.to_html(false).to_upper()
			hex_label.add_theme_color_override("font_color", Color("#EEE9DF"))
		var hex_input := picker.get_node_or_null("ProcessorCustomHexEntry/ProcessorColorHexInput") as LineEdit
		if is_instance_valid(hex_input):
			hex_input.text = selected_color.to_html(false).to_upper()
		if use_gradient_color:
			_set_processor_gradient_picker_enabled(picker, processor_gradient_enabled)
	if is_instance_valid(worksite_color_gradient_toggle):
		worksite_color_gradient_toggle.button_pressed = processor_gradient_enabled
		worksite_color_gradient_toggle.texture_normal = _processor_checkbox_icon(false)
		worksite_color_gradient_toggle.texture_pressed = _processor_checkbox_icon(true)
	var gradient_options := processor_color_content.get_node_or_null("ProcessorGradientOptions") as Control
	if is_instance_valid(gradient_options):
		gradient_options.visible = processor_gradient_enabled
	if is_instance_valid(gradient_direction_button):
		gradient_direction_button.text = "GRADIENT DIRECTION  ·  " + _processor_gradient_direction_name(processor_gradient_direction)


func _on_processor_color_picker_changed(color: Color, use_gradient_color: bool) -> void:
	processor_gradient_color_edit_mode = use_gradient_color
	var selected_color := Color(color.r, color.g, color.b, 1.0)
	if use_gradient_color:
		processor_gradient_color = selected_color
	else:
		processor_color = selected_color
	_apply_processor_color()
	_refresh_processor_color_controls()
	if is_instance_valid(status_label):
		status_label.text = "UNSAVED DESIGN CHANGES"


func _on_processor_color_picker_hue_changed(hue: float, use_gradient_color: bool) -> void:
	var picker_name := "ProcessorGradientColorPicker" if use_gradient_color else "ProcessorNormalColorPicker"
	var spectrum := processor_color_content.get_node_or_null("ProcessorColorPickerColumns/" + picker_name + "/ProcessorColorSpectrum") as DeviceColorSpectrum if is_instance_valid(processor_color_content) else null
	if is_instance_valid(spectrum):
		spectrum.set_hue(hue)
		_on_processor_color_picker_changed(Color.from_hsv(hue, spectrum.saturation, spectrum.brightness), use_gradient_color)


func _on_processor_color_hex_apply(hex_input: LineEdit, use_gradient_color: bool) -> void:
	if is_instance_valid(hex_input):
		_on_processor_color_hex_text_submitted(hex_input.text, use_gradient_color)


func _on_processor_color_hex_text_submitted(value: String, use_gradient_color: bool) -> void:
	var hex_value := value.strip_edges().trim_prefix("#")
	if not Color.html_is_valid(hex_value):
		var picker_name := "ProcessorGradientColorPicker" if use_gradient_color else "ProcessorNormalColorPicker"
		var label := processor_color_content.get_node_or_null("ProcessorColorPickerColumns/" + picker_name + "/ProcessorSelectedColorHex") as Label if is_instance_valid(processor_color_content) else null
		if is_instance_valid(label):
			label.text = "INVALID HEX CODE"
			label.add_theme_color_override("font_color", Color("#ff7373"))
		return
	_on_processor_color_picker_changed(Color.from_string("#" + hex_value, processor_gradient_color if use_gradient_color else processor_color), use_gradient_color)


func _on_processor_gradient_toggle_pressed(toggle: TextureButton) -> void:
	if not is_instance_valid(toggle):
		return
	processor_gradient_enabled = toggle.button_pressed
	if not processor_gradient_enabled:
		processor_gradient_color_edit_mode = false
	_apply_processor_color()
	_refresh_processor_color_controls()
	if is_instance_valid(status_label):
		status_label.text = "UNSAVED DESIGN CHANGES"


func _show_processor_gradient_direction_controls() -> void:
	_clear_processor_color_step_host()
	var panel := VBoxContainer.new()
	panel.name = "ProcessorGradientDirectionControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 10)
	processor_color_step_host.add_child(panel)

	var header := HBoxContainer.new()
	header.name = "ProcessorGradientDirectionHeader"
	header.add_theme_constant_override("separation", 7)
	panel.add_child(header)
	var back_button := Button.new()
	back_button.name = "ProcessorGradientDirectionBackButton"
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(34, 32)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_processor_staff_button(back_button, false)
	back_button.add_theme_font_size_override("font_size", 25)
	back_button.pressed.connect(_return_to_processor_color_controls)
	header.add_child(back_button)
	var title := _label("GRADIENT DIRECTION", 16, Color("#D3AA6B"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var options := GridContainer.new()
	options.name = "ProcessorGradientDirectionOptions"
	options.columns = 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("h_separation", 8)
	options.add_theme_constant_override("v_separation", 8)
	panel.add_child(options)
	for index in range(4):
		var option := Button.new()
		option.name = "ProcessorGradientDirectionOption%d" % index
		option.text = _processor_gradient_direction_name(index) + ("  ✓" if index == processor_gradient_direction else "")
		option.custom_minimum_size = Vector2(0, 54)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_style_processor_staff_button(option, index == processor_gradient_direction)
		option.pressed.connect(_select_processor_gradient_direction.bind(index))
		options.add_child(option)


func _return_to_processor_color_controls() -> void:
	_build_processor_color_controls()


func _select_processor_gradient_direction(index: int) -> void:
	processor_gradient_direction = clampi(index, 0, 3)
	_apply_processor_color()
	var options := processor_color_step_host.get_node_or_null("ProcessorGradientDirectionControls/ProcessorGradientDirectionOptions") as GridContainer if is_instance_valid(processor_color_step_host) else null
	if is_instance_valid(options):
		for child in options.get_children():
			if child is Button:
				var option := child as Button
				var option_index := int(option.name.trim_prefix("ProcessorGradientDirectionOption"))
				option.text = _processor_gradient_direction_name(option_index) + ("  ✓" if option_index == processor_gradient_direction else "")
				_style_processor_staff_button(option, option_index == processor_gradient_direction)
	if is_instance_valid(gradient_direction_button):
		gradient_direction_button.text = "GRADIENT DIRECTION  ·  " + _processor_gradient_direction_name(processor_gradient_direction)
	if is_instance_valid(status_label):
		status_label.text = "UNSAVED DESIGN CHANGES"


func _apply_processor_color() -> void:
	if not is_instance_valid(processor_root):
		return
	if processor_gradient_enabled:
		if not is_instance_valid(processor_gradient_material):
			var shader := Shader.new()
			shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 solid_color : source_color = vec4(0.063, 0.071, 0.078, 1.0);
uniform vec4 gradient_color : source_color = vec4(0.325, 0.427, 0.996, 1.0);
uniform int gradient_direction : hint_range(0, 3) = 0;
varying vec2 processor_uv;
void vertex() {
	processor_uv = UV;
}
void fragment() {
	float t = processor_uv.y;
	if (gradient_direction == 1) {
		t = processor_uv.x;
	} else if (gradient_direction == 2) {
		t = clamp((processor_uv.x + processor_uv.y) * 0.5, 0.0, 1.0);
	} else if (gradient_direction == 3) {
		t = clamp(length((processor_uv - vec2(0.5)) * vec2(1.0, 1.8)) * 1.4142, 0.0, 1.0);
	}
	ALBEDO = mix(solid_color.rgb, gradient_color.rgb, clamp(t, 0.0, 1.0));
	METALLIC = 0.62;
	ROUGHNESS = 0.30;
	SPECULAR = 0.82;
}
"""
			processor_gradient_material = ShaderMaterial.new()
			processor_gradient_material.shader = shader
		processor_gradient_material.set_shader_parameter("solid_color", processor_color)
		processor_gradient_material.set_shader_parameter("gradient_color", processor_gradient_color)
		processor_gradient_material.set_shader_parameter("gradient_direction", processor_gradient_direction)
		processor_color_material = processor_gradient_material
	else:
		if not is_instance_valid(processor_solid_material):
			processor_solid_material = StandardMaterial3D.new()
			processor_solid_material.metallic = 0.62
			processor_solid_material.roughness = 0.30
		processor_solid_material.albedo_color = processor_color
		processor_color_material = processor_solid_material

	# Recolour only the actual processor package and die surfaces.
	# Precision details (gold traces, light ceramic passives, BGA/LGA contacts,
	# bond frames and etched markings) retain their original physical materials.
	for layer in package_layers:
		if is_instance_valid(layer):
			layer.material_override = processor_color_material
	for surface in die_surfaces:
		if is_instance_valid(surface):
			surface.material_override = processor_color_material


func _save_design() -> void:
	var selected_profile: Dictionary = processor_designs[selected_design_index]
	processor_design = {
		"name": str(selected_profile.get("name", "DW SILICON 01")),
		"design_id": str(selected_profile.get("id", "dw_silicon_01")),
		"design_name": str(selected_profile.get("name", "DW SILICON 01")),
		"package_size": str(processor_design.get("package_size", selected_profile.get("package_size", "12 × 12 mm"))),
		"processor_color": "#" + processor_color.to_html(false).to_upper(),
		"processor_gradient_color": "#" + processor_gradient_color.to_html(false).to_upper(),
		"processor_gradient_enabled": processor_gradient_enabled,
		"processor_gradient_direction": processor_gradient_direction,
		"cpu_core_count": processor_cpu_core_count,
		"instruction_scheduler_entries": ResearchManagerScript.get_instruction_scheduler_entries_for_level(processor_instruction_scheduler_selected_level),
		"l1_cache_kb": 2 + processor_l1_cache_selected_level * 2,
		"l2_cache_kb": ResearchManagerScript.L2_CACHE_BASE_CAPACITY_KB + processor_l2_cache_selected_level * ResearchManagerScript.L2_CACHE_RESEARCH_INCREMENT_KB,
		"l3_cache_kb": ResearchManagerScript.L3_CACHE_BASE_CAPACITY_KB + processor_l3_cache_selected_level * ResearchManagerScript.L3_CACHE_RESEARCH_INCREMENT_KB,
		"processor_technology_enabled_states": processor_technology_enabled_states.duplicate(true)
	}
	design_saved.emit(processor_design.duplicate(true))
	status_label.text = "PROCESSOR DESIGN SAVED"

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	font.variation_embolden = 0.7
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label

func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#674B2A") if primary else Color("#17191B")
	normal.border_color = ACCENT if primary else Color("#8D7048")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#795A34") if primary else Color("#30271D")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#4C371F") if primary else Color("#211B14")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_font_size_override("font_size", 13)

func _style_input(input: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0E1215")
	style.border_color = Color("#41484D")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	input.add_theme_stylebox_override("normal", style)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", MUTED)

func _style_option(option: OptionButton) -> void:
	option.custom_minimum_size.y = 40
	option.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0E1215")
	style.border_color = Color("#41484D")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	option.add_theme_stylebox_override("normal", style)
	option.add_theme_color_override("font_color", TEXT)
