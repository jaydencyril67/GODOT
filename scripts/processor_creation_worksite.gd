extends Node3D

const ProcessorDesignLibrary = preload("res://scripts/processor_design_library.gd")

signal back_requested
signal design_saved(design: Dictionary)

const ACCENT := Color("#C58A3A")
const TEXT := Color("#EEEAE2")
const MUTED := Color("#A9A49A")

const DEFAULT_VIEW_ROTATION := Vector3(-0.24, -0.42, 0.0)
const WIZARD_STEP_COUNT := 4

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


var preview_viewport: SubViewport
var processor_preview_world: Node3D
var processor_root: Node3D
var preview_camera: Camera3D
var name_input: LineEdit
var package_size: OptionButton
var package_finish: OptionButton
var die_finish: OptionButton
var status_label: Label
var worksite_body: BoxContainer
var preview_region: Control
var preview_holder: SubViewportContainer
var selection_scroll: ScrollContainer
var selection_region: MarginContainer
var selection_stack: VBoxContainer
var step_pages: Array[Control] = []
var progress_number: Label
var progress_bar: ProgressBar
var wizard_back_button: Button
var next_button: Button
var current_wizard_step := 1
var package_layers: Array[MeshInstance3D] = []
var die_surface: MeshInstance3D
var die_surfaces: Array[MeshInstance3D] = []
var processor_designs: Array[Dictionary] = []
var processor_models_data: Array[Dictionary] = []
var selected_design_index := 0
var design_decrease_button: Button
var design_increase_button: Button
var design_value_label: Label
var design_position_label: Label
var design_note_label: Label
var drag_active := false
var is_flipped := false
var processor_design := {
	"name": "DW SILICON 01",
	"design_id": "dw_silicon_01",
	"design_name": "DW SILICON 01",
	"package_size": "12 × 12 mm",
	"package_finish": "Matte graphite",
	"die_finish": "Dark silicon"
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
	if is_instance_valid(name_input):
		name_input.text = str(processor_design.get("name", ProcessorDesignLibrary.DESIGNS[restored_index].get("name", "DW SILICON 01")))
	if is_instance_valid(package_size):
		_select_option(package_size, str(processor_design.get("package_size", "12 × 12 mm")))
	if is_instance_valid(package_finish):
		_select_option(package_finish, str(processor_design.get("package_finish", "Matte graphite")))
	if is_instance_valid(die_finish):
		_select_option(die_finish, str(processor_design.get("die_finish", "Dark silicon")))
	_apply_design()
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

	var view_actions := HBoxContainer.new()
	view_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	view_actions.add_theme_constant_override("separation", 10)
	preview_column.add_child(view_actions)

	var flip_button := Button.new()
	flip_button.text = "FLIP CHIP"
	flip_button.custom_minimum_size = Vector2(120, 36)
	_style_button(flip_button, false)
	flip_button.pressed.connect(_flip_chip)
	view_actions.add_child(flip_button)

	var reset_button := Button.new()
	reset_button.text = "RESET VIEW"
	reset_button.custom_minimum_size = Vector2(120, 36)
	_style_button(reset_button, false)
	reset_button.pressed.connect(_reset_view)
	view_actions.add_child(reset_button)

	var hint := _label("DRAG TO ROTATE  ·  VIEW TOP AND CONTACT SIDE", 9, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(hint)

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
	worksite_body.add_child(selection_scroll)

	selection_region = MarginContainer.new()
	selection_region.name = "ProcessorSelectionRegion"
	selection_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_region.add_theme_constant_override("margin_left", 24)
	selection_region.add_theme_constant_override("margin_right", 24)
	selection_region.add_theme_constant_override("margin_top", 20)
	selection_region.add_theme_constant_override("margin_bottom", 20)
	selection_scroll.add_child(selection_region)

	selection_stack = VBoxContainer.new()
	selection_stack.name = "ProcessorSelectionControls"
	selection_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_stack.add_theme_constant_override("separation", 16)
	selection_region.add_child(selection_stack)

	var name_page := _create_step_page(
		"SELECT PROCESSOR DESIGN",
		"Explore 15 distinct, physically grounded mobile processor package designs."
	)
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

	design_position_label = _label("DESIGN 01 / 15", 10, ACCENT)
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

	design_note_label = _label("", 11, Color("#D0CBC2"))
	design_note_label.name = "ProcessorDesignNoteLabel"
	design_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	design_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	design_note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_column.add_child(design_note_label)

	var name_label := _label("PROCESSOR NAME", 11, ACCENT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_page.add_child(name_label)
	name_input = LineEdit.new()
	name_input.name = "ProcessorNameInput"
	name_input.text = str(processor_design.get("name", "DW Silicon 01"))
	name_input.placeholder_text = "Enter processor name"
	name_input.custom_minimum_size = Vector2(0, 46)
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(name_input)
	name_input.text_changed.connect(_on_design_changed)
	name_page.add_child(name_input)

	var dimensions_page := _create_step_page(
		"PACKAGE DIMENSIONS",
		"Choose the physical footprint of the processor package."
	)
	var dimensions_label := _label("PACKAGE SIZE", 11, ACCENT)
	dimensions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dimensions_page.add_child(dimensions_label)
	package_size = OptionButton.new()
	package_size.name = "ProcessorPackageSize"
	package_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["10 × 10 mm", "12 × 12 mm", "14 × 14 mm", "16 × 16 mm"]:
		package_size.add_item(option)
	_select_option(package_size, str(processor_design.get("package_size", "12 × 12 mm")))
	_style_option(package_size)
	package_size.item_selected.connect(_on_design_changed)
	dimensions_page.add_child(package_size)

	var package_page := _create_step_page(
		"PACKAGE FINISH",
		"Select the finish and substrate appearance for the processor package."
	)
	var package_label := _label("PACKAGE MATERIAL FINISH", 11, ACCENT)
	package_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	package_page.add_child(package_label)
	package_finish = OptionButton.new()
	package_finish.name = "ProcessorPackageFinish"
	package_finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["Matte graphite", "Deep green substrate", "Ceramic black"]:
		package_finish.add_item(option)
	_select_option(package_finish, str(processor_design.get("package_finish", "Matte graphite")))
	_style_option(package_finish)
	package_finish.item_selected.connect(_on_design_changed)
	package_page.add_child(package_finish)

	var die_page := _create_step_page(
		"SILICON DIE FINISH",
		"Choose the visible finish of the silicon die and heat-spreader surface."
	)
	var die_label := _label("DIE SURFACE", 11, ACCENT)
	die_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	die_page.add_child(die_label)
	die_finish = OptionButton.new()
	die_finish.name = "ProcessorDieFinish"
	die_finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["Dark silicon", "Polished silicon", "Metallic silicon cap"]:
		die_finish.add_item(option)
	_select_option(die_finish, str(processor_design.get("die_finish", "Dark silicon")))
	_style_option(die_finish)
	die_finish.item_selected.connect(_on_design_changed)
	die_page.add_child(die_finish)

	status_label = _label("DESIGN NOT YET SAVED", 10, MUTED)
	status_label.name = "ProcessorDesignStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	die_page.add_child(status_label)

	var save_button := Button.new()
	save_button.name = "SaveProcessorDesignButton"
	save_button.text = "SAVE PROCESSOR DESIGN"
	save_button.custom_minimum_size = Vector2(0, 46)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_button, true)
	save_button.pressed.connect(_save_design)
	die_page.add_child(save_button)

	var research_note := _label("The seven research systems will be added after the base processor design is established.", 9, MUTED)
	research_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	research_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	die_page.add_child(research_note)

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


func _create_step_page(title_text: String, description_text: String) -> VBoxContainer:
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

	var description := _label(description_text, 12, Color("#D0CBC2"))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	page.add_child(description)
	return page


func _apply_responsive_layout() -> void:
	if not is_instance_valid(worksite_body) or not is_instance_valid(preview_region) or not is_instance_valid(selection_scroll):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var is_wide := viewport_size.x >= viewport_size.y and viewport_size.x >= 700.0
	worksite_body.vertical = not is_wide
	if is_wide:
		preview_region.size_flags_stretch_ratio = 1.12
		selection_scroll.size_flags_stretch_ratio = 0.88
		preview_region.custom_minimum_size = Vector2(0, 0)
		preview_holder.custom_minimum_size = Vector2(0, 245)
		selection_scroll.custom_minimum_size = Vector2(280, 0)
		selection_region.add_theme_constant_override("margin_left", 24)
		selection_region.add_theme_constant_override("margin_right", 24)
		selection_region.add_theme_constant_override("margin_top", 20)
		selection_region.add_theme_constant_override("margin_bottom", 20)
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		selection_scroll.size_flags_stretch_ratio = 1.18
		preview_region.custom_minimum_size = Vector2(0, maxf(160.0, viewport_size.y * 0.25))
		preview_holder.custom_minimum_size = Vector2(0, 100)
		selection_scroll.custom_minimum_size = Vector2(0, maxf(300.0, viewport_size.y * 0.50))
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

	# Construct and retain all fifteen models under the world root during
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
	selected_design_index = clampi(index, 0, mini(processor_models_data.size(), processor_designs.size()) - 1)
	for model_index in range(processor_models_data.size()):
		var model_root := processor_models_data[model_index].get("root") as Node3D
		if is_instance_valid(model_root):
			model_root.visible = model_index == selected_design_index
			if model_index == selected_design_index:
				model_root.rotation = DEFAULT_VIEW_ROTATION
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
	is_flipped = false

	if reset_to_preset:
		if is_instance_valid(name_input):
			name_input.text = str(selected_profile.get("name", "DW PROCESSOR"))
		if is_instance_valid(package_size):
			_select_option(package_size, str(selected_profile.get("package_size", "12 × 12 mm")))
		if is_instance_valid(package_finish):
			_select_option(package_finish, str(selected_profile.get("package_finish", "Matte graphite")))
		if is_instance_valid(die_finish):
			_select_option(die_finish, str(selected_profile.get("die_finish", "Dark silicon")))
	# All finish materials and geometry were prepared during initialization.
	# Switching designs is now a visibility change only.
	_refresh_processor_design_controls()


func _refresh_processor_design_controls() -> void:
	if selected_design_index < 0 or selected_design_index >= processor_designs.size():
		return
	var profile: Dictionary = processor_designs[selected_design_index]
	if is_instance_valid(design_value_label):
		design_value_label.text = str(profile.get("name", "DW PROCESSOR"))
	if is_instance_valid(design_position_label):
		design_position_label.text = "DESIGN %02d / %02d" % [selected_design_index + 1, processor_designs.size()]
	if is_instance_valid(design_note_label):
		design_note_label.text = str(profile.get("description", ""))
	if is_instance_valid(design_decrease_button):
		design_decrease_button.disabled = selected_design_index <= 0
	if is_instance_valid(design_increase_button):
		design_increase_button.disabled = selected_design_index >= processor_designs.size() - 1

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
	processor_root.rotation.y += relative.x * 0.008
	processor_root.rotation.x = clampf(processor_root.rotation.x + relative.y * 0.006, -0.65, 3.80)

func _flip_chip() -> void:
	if not is_instance_valid(processor_root):
		return
	is_flipped = not is_flipped
	processor_root.rotation.x = PI - 0.24 if is_flipped else DEFAULT_VIEW_ROTATION.x

func _reset_view() -> void:
	if not is_instance_valid(processor_root):
		return
	is_flipped = false
	processor_root.rotation = DEFAULT_VIEW_ROTATION

func _on_design_changed(_value: Variant = null) -> void:
	_apply_design()
	if is_instance_valid(status_label):
		status_label.text = "UNSAVED DESIGN CHANGES"

func _apply_design() -> void:
	if not is_instance_valid(processor_root) or not is_instance_valid(package_size):
		return
	var package_colors := {
		"Matte graphite": Color("#222C31"),
		"Deep green substrate": Color("#183B32"),
		"Ceramic black": Color("#15191E")
	}
	var die_colors := {
		"Dark silicon": Color("#171D22"),
		"Polished silicon": Color("#454F57"),
		"Metallic silicon cap": Color("#91999D")
	}
	var selected_package := package_finish.get_item_text(package_finish.selected)
	var selected_die := die_finish.get_item_text(die_finish.selected)
	var package_color: Color = package_colors.get(selected_package, Color("#222C31"))
	for layer in package_layers:
		if is_instance_valid(layer):
			var layer_material := _material(package_color, 0.42, 0.34)
			layer_material.albedo_color = package_color.darkened(0.12) if layer.name == "PackageLowerEdge" else package_color
			layer.material_override = layer_material
	for surface in die_surfaces:
		if is_instance_valid(surface):
			surface.material_override = _material(die_colors.get(selected_die, Color("#171D22")), 0.32, 0.25)
	var package_size_values := {
		"10 × 10 mm": 10.0,
		"12 × 12 mm": 12.0,
		"14 × 14 mm": 14.0,
		"16 × 16 mm": 16.0
	}
	var selected_size_label := package_size.get_item_text(package_size.selected)
	var target_package_size := float(package_size_values.get(selected_size_label, 12.0))
	var base_package_size := 12.0
	if selected_design_index >= 0 and selected_design_index < processor_designs.size():
		var selected_profile: Dictionary = processor_designs[selected_design_index]
		base_package_size = float(package_size_values.get(str(selected_profile.get("package_size", "12 × 12 mm")), 12.0))
	var scale_factor := target_package_size / maxf(base_package_size, 1.0)
	processor_root.scale = Vector3.ONE * scale_factor

func _save_design() -> void:
	var selected_profile: Dictionary = processor_designs[selected_design_index]
	processor_design = {
		"name": name_input.text.strip_edges() if not name_input.text.strip_edges().is_empty() else str(selected_profile.get("name", "DW SILICON 01")),
		"design_id": str(selected_profile.get("id", "dw_silicon_01")),
		"design_name": str(selected_profile.get("name", "DW SILICON 01")),
		"package_size": package_size.get_item_text(package_size.selected),
		"package_finish": package_finish.get_item_text(package_finish.selected),
		"die_finish": die_finish.get_item_text(die_finish.selected)
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
