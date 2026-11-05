extends Node3D

var charging_speed_step_visited := false
var wireless_charge_step_visited := false
var sensors_step_visited := false
var front_camera_mp_step_visited := false
var rear_camera_mp_step_visited := false
var memory_clock_step_visited := false
var refresh_rate_step_visited := false
var cooling_system_step_visited := false

signal back_requested

const PHONE_TYPES := ["Standard", "Flip", "Fold"]
const PhoneEditorScene = preload("res://scenes/product_phone_editor.tscn")


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
		var fill := Color(0.15, 0.24, 0.17, 0.96) if is_hovered() else Color(0.09, 0.14, 0.10, 0.92)
		if is_pressed():
			fill = Color(0.06, 0.11, 0.07, 0.98)
		draw_circle(centre + Vector2(0, 2), radius + 1.0, Color(0, 0, 0, 0.42))
		draw_circle(centre, radius, fill)
		draw_arc(centre, radius - 1.0, PI * 1.08, PI * 1.92, 48, Color(0.94, 1.0, 0.95, 0.78), 1.5, true)
		draw_arc(centre, radius - 1.5, -PI * 0.08, PI * 0.88, 48, Color(0.61, 0.83, 0.66, 0.36), 1.0, true)
		var direction := 1.0 if points_right else -1.0
		var tip := centre + Vector2(direction * 7.0, 0)
		var upper := centre + Vector2(-direction * 4.5, -7.0)
		var lower := centre + Vector2(-direction * 4.5, 7.0)
		draw_line(upper, tip, Color("#effff1"), 2.8, true)
		draw_line(tip, lower, Color("#effff1"), 2.8, true)
		draw_line(centre + Vector2(-direction * 5.0, 0), centre + Vector2(direction * 6.0, 0), Color("#effff1"), 2.8, true)


class GlassButtonReflection extends Control:
	var accent := Color("#9bd6a7")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 4.0 or size.y <= 4.0:
			return
		# Fine silver-green specular streak across the upper glass edge.
		var segments := 48
		for i in range(segments):
			var start_x := size.x * float(i) / float(segments)
			var end_x := size.x * float(i + 1) / float(segments)
			var midpoint := (float(i) + 0.5) / float(segments)
			var highlight := exp(-pow((midpoint - 0.34) / 0.29, 2.0))
			var alpha := 0.09 + 0.30 * highlight
			draw_line(Vector2(start_x, 1.2), Vector2(end_x, 1.2), Color(0.97, 1.0, 0.98, alpha), 1.2, true)
		# Restrained edge reflections make the surface feel polished, not neon.
		var side_color := Color(accent.r, accent.g, accent.b, 0.24)
		draw_line(Vector2(1.2, 9.0), Vector2(1.2, maxf(9.0, size.y - 9.0)), side_color, 1.0, true)
		draw_line(Vector2(size.x - 1.2, 9.0), Vector2(size.x - 1.2, maxf(9.0, size.y - 9.0)), side_color, 1.0, true)
		draw_line(Vector2(12.0, size.y - 2.0), Vector2(size.x - 12.0, size.y - 2.0), Color(0.72, 0.88, 0.76, 0.10), 1.0, true)


var selected_phone_type := ""
var type_buttons: Dictionary = {}
var next_button: Button
var wizard_back_button: Button
var progress_bar: ProgressBar
var progress_number: Label
var type_step_content: VBoxContainer
var wizard_step := 0
var thickness_panel: Control
var border_radius_panel: Control
var screen_tech_panel: Control
var screen_size_panel: Control
var screen_type_panel: Control
var power_volume_panel: Control
var speaker_panel: Control
var charge_port_panel: Control
var side_button_panel: Control
var home_button_panel: Control
var device_color_panel: Control
var front_camera_panel: Control
var back_design_panel: Control
var rear_camera_panel: Control
var phone_editor: Node
var worksite_body: BoxContainer
var preview_region: Control
var specification_readout_scroll: ScrollContainer
var specification_readout: HBoxContainer
var specification_readout_left: VBoxContainer
var specification_readout_right: VBoxContainer
var specification_readout_entry_count: int = 0
var selection_scroll: ScrollContainer
var selection_region: MarginContainer
var selection_stack: VBoxContainer
var navigation_layer: CanvasLayer
var navigation_bar: HBoxContainer
var step_panels: Dictionary = {}


func _ready() -> void:
	_build_preview_world()
	_build_interface()


func _build_preview_world() -> void:
	# Instantiate the real editor so its existing chassis generator, phone-type
	# state, materials, display construction and foldable hierarchy are reused.
	# Its full-screen editor UI is hidden; only its original preview viewport is
	# moved into this worksite's left-hand preview region.
	phone_editor = PhoneEditorScene.instantiate()
	phone_editor.name = "ReusedPhoneEditorEngine"
	phone_editor.worksite_creation_mode = true
	phone_editor.worksite_owner = self
	add_child(phone_editor)
	if phone_editor.has_signal("worksite_nested_color_view_opened"):
		phone_editor.connect("worksite_nested_color_view_opened", _on_nested_color_view_opened)

	var editor_interface := phone_editor.get_node_or_null("PhoneEditorInterface") as CanvasLayer
	if is_instance_valid(editor_interface):
		editor_interface.hide()



func _apply_worksite_preview_studio_lighting(preview_viewport: SubViewport) -> void:
	if not is_instance_valid(preview_viewport):
		return
	var preview_world := preview_viewport.get_node_or_null("PhonePreviewWorld") as Node3D
	if not is_instance_valid(preview_world):
		return

	# Neutral studio illumination keeps dark chassis colours readable without
	# changing their materials or tinting the selected device colour.
	var directional_lights: Array[DirectionalLight3D] = []
	for child in preview_world.get_children():
		if child is DirectionalLight3D:
			directional_lights.append(child as DirectionalLight3D)
		elif child is OmniLight3D:
			var fill_light := child as OmniLight3D
			fill_light.light_color = Color("#dce5df")
			fill_light.light_energy = 0.38
			fill_light.omni_range = 8.0

	if directional_lights.size() > 0:
		var key_light := directional_lights[0]
		key_light.light_color = Color("#fffdf8")
		key_light.light_energy = 1.20
		key_light.shadow_enabled = false
	if directional_lights.size() > 1:
		var rim_light := directional_lights[1]
		rim_light.light_color = Color("#d5e2d9")
		rim_light.light_energy = 0.78
		rim_light.shadow_enabled = false

	var environment_node := preview_viewport.get_node_or_null("PhonePreviewWorld/WorldEnvironment") as WorldEnvironment
	if is_instance_valid(environment_node) and is_instance_valid(environment_node.environment):
		var environment := environment_node.environment
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("#aeb8b1")
		environment.ambient_light_energy = 0.66
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		if is_instance_valid(environment.sky) and environment.sky.sky_material is ProceduralSkyMaterial:
			var studio_sky_material := environment.sky.sky_material as ProceduralSkyMaterial
			studio_sky_material.sky_top_color = Color("#77817b")
			studio_sky_material.sky_horizon_color = Color("#d4d9d5")
			studio_sky_material.ground_horizon_color = Color("#727b75")
			studio_sky_material.ground_bottom_color = Color("#343b37")
			studio_sky_material.sky_energy_multiplier = 0.9
			studio_sky_material.ground_energy_multiplier = 0.72

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PhoneCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	var root := Control.new()
	root.name = "WorksiteRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.name = "WorksiteBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#292d2b")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	root.resized.connect(_apply_responsive_layout)

	var layout := VBoxContainer.new()
	layout.name = "WorksiteLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Keep the entire worksite safely inset from the physical screen edges.
	layout.offset_left = 20
	layout.offset_right = -20
	layout.offset_top = 12
	layout.offset_bottom = -12
	layout.add_theme_constant_override("separation", 10)
	root.add_child(layout)

	var top_bar := HBoxContainer.new()
	top_bar.name = "WorksiteTopBar"
	top_bar.custom_minimum_size.y = 48.0
	top_bar.add_theme_constant_override("separation", 12)
	layout.add_child(top_bar)

	var back_button := Button.new()
	back_button.name = "WorksiteBackButton"
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(82, 48)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_arrow_button(back_button)
	back_button.pressed.connect(func(): back_requested.emit())
	top_bar.add_child(back_button)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var progress := VBoxContainer.new()
	progress.name = "WorksiteProgress"
	progress.custom_minimum_size = Vector2(150, 38)
	progress.add_theme_constant_override("separation", 4)
	top_bar.add_child(progress)
	progress_number = _label("STEP 1 / 37", 11, Color("#dce9df"), HORIZONTAL_ALIGNMENT_CENTER)
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)
	progress_bar = ProgressBar.new()
	progress_bar.name = "WizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = 37
	progress_bar.value = 1
	progress_bar.show_percentage = false
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("#4f9a60")
	progress_fill.set_corner_radius_all(4)
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color("#26332a")
	progress_track.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_bar.add_theme_stylebox_override("background", progress_track)
	progress.add_child(progress_bar)

	# BoxContainer supports switching between horizontal and vertical
	# layouts at runtime; HBoxContainer has a fixed horizontal orientation.
	var body := BoxContainer.new()
	body.name = "WorksiteMainContent"
	worksite_body = body
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	layout.add_child(body)

	preview_region = Control.new()
	preview_region.name = "PhonePreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.0
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview_region)

	var viewport_container := phone_editor.get("preview_container") as SubViewportContainer
	if is_instance_valid(viewport_container):
		# Move the original editor's live SubViewportContainer, not a recreated
		# preview. The original editor remains alive and continues handling
		# rotation, fold gestures and mesh rebuilds for this exact viewport.
		var original_parent := viewport_container.get_parent()
		if is_instance_valid(original_parent):
			original_parent.remove_child(viewport_container)
		preview_region.add_child(viewport_container)
		viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
		viewport_container.offset_left = 0
		viewport_container.offset_right = 0
		viewport_container.offset_top = 0
		viewport_container.offset_bottom = 0
		# Let the live 3D preview sit directly on the worksite's single shared
		# dark background. Keep the original sky available for PBR lighting.
		var preview_viewport := viewport_container.get_child(0) as SubViewport
		if is_instance_valid(preview_viewport):
			preview_viewport.transparent_bg = true
			var preview_environment := preview_viewport.get_node_or_null("PhonePreviewWorld/WorldEnvironment") as WorldEnvironment
			if is_instance_valid(preview_environment) and is_instance_valid(preview_environment.environment):
				preview_environment.environment.background_mode = Environment.BG_COLOR
				preview_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
			_apply_worksite_preview_studio_lighting(preview_viewport)

	# Software specifications replace the 3D preview during the final software
	# steps. One shared, invisible vertical scroll area moves both columns
	# together; it is hidden and disabled whenever the 3D phone is displayed.
	specification_readout_scroll = ScrollContainer.new()
	specification_readout_scroll.name = "SpecificationReadoutScroll"
	specification_readout_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	specification_readout_scroll.offset_left = 12.0
	specification_readout_scroll.offset_right = -12.0
	specification_readout_scroll.offset_top = 12.0
	specification_readout_scroll.offset_bottom = -12.0
	specification_readout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	specification_readout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var specification_scroll_bar := specification_readout_scroll.get_v_scroll_bar()
	specification_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	specification_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specification_readout_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	specification_readout_scroll.visible = false
	preview_region.add_child(specification_readout_scroll)
	specification_readout_scroll.resized.connect(_update_specification_readout_alignment)

	# The two columns remain inside one horizontal row, preserving their
	# independent vertical stacks while the parent scrolls as a single unit.
	specification_readout = HBoxContainer.new()
	specification_readout.name = "ProgressiveSpecificationReadout"
	specification_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specification_readout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	specification_readout.add_theme_constant_override("separation", 16)
	specification_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specification_readout.visible = false

	specification_readout_left = VBoxContainer.new()
	specification_readout_left.name = "SpecificationReadoutLeftColumn"
	specification_readout_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specification_readout_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	specification_readout_left.alignment = BoxContainer.ALIGNMENT_CENTER
	specification_readout_left.add_theme_constant_override("separation", 8)
	specification_readout_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specification_readout.add_child(specification_readout_left)

	specification_readout_right = VBoxContainer.new()
	specification_readout_right.name = "SpecificationReadoutRightColumn"
	specification_readout_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specification_readout_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	specification_readout_right.alignment = BoxContainer.ALIGNMENT_CENTER
	specification_readout_right.add_theme_constant_override("separation", 8)
	specification_readout_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specification_readout.add_child(specification_readout_right)

	specification_readout_scroll.add_child(specification_readout)

	selection_scroll = ScrollContainer.new()
	selection_scroll.name = "PhoneTypeSelectionScroll"
	selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Let taller control cards remain fully reachable on compact landscape
	# screens while keeping the scrollbar invisible to preserve the clean UI.
	selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var selection_scroll_bar := selection_scroll.get_v_scroll_bar()
	selection_scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	selection_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(selection_scroll)

	selection_region = MarginContainer.new()
	selection_region.name = "PhoneTypeSelectionRegion"
	selection_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_region.add_theme_constant_override("margin_left", 22)
	selection_region.add_theme_constant_override("margin_right", 18)
	selection_region.add_theme_constant_override("margin_top", 20)
	selection_region.add_theme_constant_override("margin_bottom", 20)
	selection_scroll.add_child(selection_region)

	selection_stack = VBoxContainer.new()
	selection_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_stack.add_theme_constant_override("separation", 16)
	selection_region.add_child(selection_stack)

	type_step_content = VBoxContainer.new()
	type_step_content.name = "PhoneTypeStepContent"
	type_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_stack.add_child(type_step_content)
	var section_title := _label("PHONE TYPE", 22, Color("#f1f5f1"))
	type_step_content.add_child(section_title)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 9)
	type_step_content.add_child(options)
	for phone_type in PHONE_TYPES:
		var option := Button.new()
		option.name = phone_type.replace(" ", "") + "PhoneTypeOption"
		option.text = phone_type
		option.custom_minimum_size = Vector2(0, 56)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.toggle_mode = true
		option.focus_mode = Control.FOCUS_NONE
		_style_button(option, false)
		option.pressed.connect(_on_phone_type_selected.bind(phone_type))
		options.add_child(option)
		type_buttons[phone_type] = option

	# Reserve the same space in the worksite VBox, but render the actual
	# navigation controls on their own high-priority CanvasLayer. This prevents
	# nested editor/color overlays from covering the arrows or stealing taps.
	var bottom_bar_space := Control.new()
	bottom_bar_space.name = "WorksiteBottomBarSpace"
	bottom_bar_space.custom_minimum_size = Vector2(0, 62.0)
	layout.add_child(bottom_bar_space)

	navigation_layer = CanvasLayer.new()
	navigation_layer.name = "WorksiteNavigationOverlay"
	navigation_layer.layer = 127
	add_child(navigation_layer)

	var navigation_root := Control.new()
	navigation_root.name = "WorksiteNavigationRoot"
	navigation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigation_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_layer.add_child(navigation_root)

	navigation_bar = HBoxContainer.new()
	navigation_bar.name = "WorksiteBottomBar"
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
	wizard_back_button.name = "WizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	navigation_bar.add_child(wizard_back_button)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_bar.add_child(bottom_spacer)
	next_button = GlassArrowButton.new()
	next_button.name = "NextStepIconButton"
	next_button.points_right = true
	next_button.pressed.connect(_on_next_pressed)
	navigation_bar.add_child(next_button)
	_keep_step_navigation_active()
	_apply_responsive_layout()
	# Start with Standard selected in both the worksite controls and the
	# original editor engine, so the preview and Next state are immediately ready.
	_on_phone_type_selected("Standard")


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
		selection_scroll.custom_minimum_size = Vector2(280, 0)
		selection_region.add_theme_constant_override("margin_left", 24)
		selection_region.add_theme_constant_override("margin_right", 24)
		selection_region.add_theme_constant_override("margin_top", 20)
		selection_region.add_theme_constant_override("margin_bottom", 20)
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		selection_scroll.size_flags_stretch_ratio = 1.18
		# Give the controls enough vertical room in portrait so the two-column
		# Screen Tech choices remain visible without needing a scroll gesture.
		preview_region.custom_minimum_size = Vector2(0, maxf(140.0, viewport_size.y * 0.24))
		selection_scroll.custom_minimum_size = Vector2(0, maxf(300.0, viewport_size.y * 0.52))
		selection_region.add_theme_constant_override("margin_left", 20)
		selection_region.add_theme_constant_override("margin_right", 20)
		selection_region.add_theme_constant_override("margin_top", 14)
		selection_region.add_theme_constant_override("margin_bottom", 14)


func _on_phone_type_selected(phone_type: String) -> void:
	selected_phone_type = phone_type
	for option_name in type_buttons:
		var option: Button = type_buttons[option_name]
		option.button_pressed = option_name == phone_type
		_style_button(option, option_name == phone_type)
	_keep_step_navigation_active()
	_update_preview_for_phone_type(phone_type)


func _update_preview_for_phone_type(phone_type: String) -> void:
	if not is_instance_valid(phone_editor):
		return
	# Delegate to the original editor's own type-selection callback. This runs
	# its complete mesh rebuild path for Standard, Flip and Fold.
	phone_editor.call("_on_phone_type_selected", phone_type)


func _on_next_pressed() -> void:
	_keep_step_navigation_active()
	if selected_phone_type.is_empty():
		return
	if wizard_step == 0:
		_show_thickness_step()
	elif wizard_step == 1:
		_show_border_radius_step()
	elif wizard_step == 2:
		_show_screen_tech_step()
	elif wizard_step == 3:
		_show_screen_size_step()
	elif wizard_step == 4:
		_show_screen_type_step()
	elif wizard_step == 5:
		_show_power_volume_step()
	elif wizard_step == 6:
		_show_speakers_step()
	elif wizard_step == 7:
		_show_charge_port_step()
	elif wizard_step == 8:
		_show_side_button_step()
	elif wizard_step == 9:
		_show_home_button_step()
	elif wizard_step == 10:
		_show_device_color_step()
	elif wizard_step == 11:
		_show_front_camera_step()
	elif wizard_step == 12:
		_show_back_design_step()
	elif wizard_step == 13:
		_show_rear_camera_step()
	elif wizard_step == 14:
		_show_ram_technology_step()
	elif wizard_step == 15:
		_show_ram_step()
	elif wizard_step == 16:
		_show_internal_storage_step()
	elif wizard_step == 17:
		_show_internet_selection_step()
	elif wizard_step == 18:
		_show_wifi_step()
	elif wizard_step == 19:
		_show_bluetooth_step()
	elif wizard_step == 20:
		_show_battery_step()
	elif wizard_step == 21:
		_show_charging_speed_step()
	elif wizard_step == 22:
		_show_wireless_charge_step()
	elif wizard_step == 23:
		_show_sensors_step()
	elif wizard_step == 24:
		_show_front_camera_mp_step()
	elif wizard_step == 25:
		_show_rear_camera_mp_step()
	elif wizard_step == 26:
		_show_memory_clock_step()
	elif wizard_step == 27:
		_show_refresh_rate_step()
	elif wizard_step == 28:
		_show_cooling_system_step()
	elif wizard_step == 29:
		_show_box_package_step()
	elif wizard_step == 30:
		_show_phone_case_step()
	elif wizard_step == 31:
		_show_charger_step()
	elif wizard_step == 32:
		_show_protection_glass_step()
	elif wizard_step == 33:
		_show_wireless_earbuds_step()
	elif wizard_step == 34:
		_show_smartwatch_step()


func _cache_current_step_panel() -> void:
	if wizard_step <= 0 or not is_instance_valid(phone_editor):
		return

	# Nested raised-box color editing is a temporary view of the Back Design
	# step. Close its floating overlays and restore the parent controls before
	# caching the step, so returning later restores the correct main view.
	if wizard_step == 13:
		if bool(phone_editor.get("back_design_color_mode")):
			if phone_editor.has_method("_close_worksite_back_design_color_view"):
				phone_editor.call("_close_worksite_back_design_color_view")
			phone_editor.call("_show_back_design_controls")
		elif phone_editor.has_method("_close_back_design_selection_popup"):
			phone_editor.call("_close_back_design_selection_popup")
	elif wizard_step == 14 and phone_editor.has_method("_close_rear_hardware_selection_popup"):
		phone_editor.call("_close_rear_hardware_selection_popup")
	elif wizard_step == 30 and bool(phone_editor.get("box_package_color_mode")):
		_show_worksite_box_package_controls()
	elif wizard_step == 31 and bool(phone_editor.get("phone_case_color_mode")):
		_show_worksite_phone_case_controls()
	elif wizard_step == 32 and bool(phone_editor.get("charger_color_mode")):
		_show_worksite_charger_controls("HOME")
	elif wizard_step == 34 and bool(phone_editor.get("wireless_earbuds_color_mode")):
		_show_worksite_earbuds_controls()
	elif wizard_step == 35 and bool(phone_editor.get("smartwatch_color_mode")):
		_show_worksite_smartwatch_controls()

	var current_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(current_panel):
		step_panels[wizard_step] = current_panel
		current_panel.hide()


func _prepare_step_panels_for_navigation() -> void:
	_cache_current_step_panel()
	for step_key in step_panels.keys():
		var panel := step_panels[step_key] as Control
		if is_instance_valid(panel):
			panel.hide()


func _show_worksite_step(step: int, builder_method: String = "") -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return

	var previous_step := wizard_step
	if step < 15 or step > 29:
		_set_ram_selection_preview(false)
	_prepare_step_panels_for_navigation()
	if previous_step == 30 and step != 30:
		phone_editor.call("_set_box_package_preview_mode", false)
	if previous_step == 32 and step != 32:
		phone_editor.call("_set_charger_preview_mode", false)
	if previous_step == 34 and step != 34:
		phone_editor.call("_set_earbuds_preview_mode", false)
	if previous_step == 35 and step != 35:
		phone_editor.call("_set_smartwatch_preview_mode", false)
	wizard_step = step
	if step == 30:
		phone_editor.call("_set_box_package_preview_mode", true)
	if step == 32:
		phone_editor.call("_set_charger_preview_mode", true)
	if step == 34:
		phone_editor.call("_set_earbuds_preview_mode", true)
	if step == 35:
		phone_editor.call("_set_smartwatch_preview_mode", true)
	if step >= 22:
		charging_speed_step_visited = true
	if step >= 23:
		wireless_charge_step_visited = true
	if step >= 24:
		sensors_step_visited = true
	if step >= 25:
		front_camera_mp_step_visited = true
	if step >= 26:
		rear_camera_mp_step_visited = true
	if step >= 27:
		memory_clock_step_visited = true
	if step >= 28:
		refresh_rate_step_visited = true
	if step >= 29:
		cooling_system_step_visited = true
	type_step_content.hide()
	phone_editor.set("active_feature_panel", null)

	# Camera megapixel panels depend on the camera hardware configured in
	# earlier steps. Rebuild these two panels on each visit so added, removed,
	# or changed camera modules are always represented by the current hardware.
	if step == 25 or step == 26:
		var stale_camera_panel := step_panels.get(step) as Control
		if is_instance_valid(stale_camera_panel):
			var stale_parent := stale_camera_panel.get_parent()
			if is_instance_valid(stale_parent):
				stale_parent.remove_child(stale_camera_panel)
			stale_camera_panel.queue_free()
		step_panels.erase(step)

	var panel := step_panels.get(step) as Control
	if is_instance_valid(panel):
		# Reattach only if an editor subview moved this cached panel elsewhere.
		var parent := panel.get_parent()
		if parent != selection_stack:
			if is_instance_valid(parent):
				parent.remove_child(panel)
			selection_stack.add_child(panel)
		panel.show()
		phone_editor.set("active_feature_panel", panel)
	else:
		if builder_method.is_empty():
			return
		# Each builder runs only the first time its step is visited. Its control
		# tree is then kept alive and reused by every later Previous/Next visit.
		# Builders may belong either to this worksite or to the phone editor.
		# Resolve the owner by method availability instead of hard-coding a
		# single exception, so every migrated step uses the correct script.
		if has_method(builder_method):
			call(builder_method)
		elif phone_editor.has_method(builder_method):
			phone_editor.call(builder_method)
		else:
			push_error("Worksite step builder not found: " + builder_method)
			return
		panel = phone_editor.get("active_feature_panel") as Control
		if is_instance_valid(panel):
			var parent := panel.get_parent()
			if is_instance_valid(parent):
				parent.remove_child(panel)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			selection_stack.add_child(panel)
			panel.show()
			step_panels[step] = panel

	if is_instance_valid(panel):
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if step == 8 else Control.SIZE_SHRINK_BEGIN
		if step >= 15 and step <= 29:
			_style_ram_selector_buttons(panel)

	if step >= 15 and step <= 29:
		_set_ram_selection_preview(true)
		_update_ram_selection_display(
			str(phone_editor.get("selected_ram_technology")),
			str(phone_editor.get("selected_ram_capacity")),
			str(phone_editor.get("selected_rom_capacity")),
			str(phone_editor.get("selected_mobile_network")),
			str(phone_editor.get("selected_wifi_standard")),
			str(phone_editor.get("selected_bluetooth_version")),
			str(phone_editor.get("selected_battery_capacity")),
			str(phone_editor.get("selected_charging_speed")) + "W" if charging_speed_step_visited else "Not set",
			(str(phone_editor.get("selected_wireless_charging_speed")) + "W" if bool(phone_editor.get("selected_wireless_charge_enabled")) else "Disabled") if wireless_charge_step_visited else "Not set",
			phone_editor.call("_get_enabled_sensor_names") if sensors_step_visited else [],
			str(phone_editor.call("_get_front_camera_mp_summary")) if front_camera_mp_step_visited else "Not set",
			str(phone_editor.call("_get_rear_camera_mp_summary")) if rear_camera_mp_step_visited else "Not set",
			str(phone_editor.get("selected_memory_clock")) if memory_clock_step_visited else "Not set",
			str(phone_editor.get("selected_refresh_rate")) if refresh_rate_step_visited else "Not set",
			str(phone_editor.get("selected_cooling_system")) if cooling_system_step_visited else "Not set"
		)
	_update_step_progress(step)
	selection_scroll.scroll_vertical = 0
	_keep_step_navigation_active()


func _refresh_ram_capacity_step() -> void:
	if not is_instance_valid(phone_editor):
		return
	var ram_panel := step_panels.get(16) as Control
	if not is_instance_valid(ram_panel):
		return
	if phone_editor.has_method("_refresh_ram_capacity_selection_ui"):
		phone_editor.call("_refresh_ram_capacity_selection_ui", ram_panel)
	_style_ram_selector_buttons(ram_panel)


func _style_ram_selector_buttons(panel: Control) -> void:
	for child in panel.find_children("*", "Button", true, false):
		var option := child as Button
		if not is_instance_valid(option):
			continue
		var selected := option.text.contains("✓")
		_style_button(option, selected)
		option.custom_minimum_size.y = 48
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _set_ram_selection_preview(enabled: bool) -> void:
	var phone_preview := phone_editor.get("preview_container") as Control if is_instance_valid(phone_editor) else null
	if is_instance_valid(phone_preview):
		phone_preview.visible = not enabled
	# The readout is explicitly hidden during construction, so its visibility
	# must follow the preview mode too. Showing only the parent ScrollContainer
	# leaves every specification invisible even though its entries are updated.
	if is_instance_valid(specification_readout):
		specification_readout.visible = enabled
	if is_instance_valid(specification_readout_scroll):
		specification_readout_scroll.visible = enabled
		specification_readout_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if enabled else ScrollContainer.SCROLL_MODE_DISABLED
		if not enabled:
			specification_readout_scroll.scroll_vertical = 0
		if enabled:
			call_deferred("_update_specification_readout_alignment")


func _update_specification_readout_alignment() -> void:
	if not is_instance_valid(specification_readout_scroll) or not is_instance_valid(specification_readout_left) or not is_instance_valid(specification_readout_right):
		return
	# Keep short readouts visually centered. Once either column exceeds the
	# viewport, align both columns to the top so scrolling never leaves the
	# shorter column awkwardly floating halfway down the content.
	var content_height := maxf(
		specification_readout_left.get_combined_minimum_size().y,
		specification_readout_right.get_combined_minimum_size().y
	)
	var alignment := BoxContainer.ALIGNMENT_CENTER if content_height <= specification_readout_scroll.size.y + 1.0 else BoxContainer.ALIGNMENT_BEGIN
	specification_readout_left.alignment = alignment
	specification_readout_right.alignment = alignment


func _update_ram_selection_display(
	technology: String,
	capacity: String,
	storage: String = "Not set",
	internet: String = "Not set",
	wifi: String = "Not set",
	bluetooth: String = "Not set",
	battery: String = "Not set",
	charging_speed: String = "Not set",
	wireless_charge: String = "Not set",
	sensors: Array = [],
	front_camera_mp: String = "Not set",
	rear_camera_mp: String = "Not set",
	memory_clock: String = "Not set",
	refresh_rate: String = "Not set",
	cooling_system: String = "Not set"
) -> void:
	if not is_instance_valid(specification_readout):
		return

	# Editor callbacks can refresh the full specification list while the user
	# is still on an earlier step. Do not expose a future step's value until
	# that step has actually been reached.
	if not charging_speed_step_visited:
		charging_speed = "Not set"
	if not wireless_charge_step_visited:
		wireless_charge = "Not set"
	if not sensors_step_visited:
		sensors = []
	elif sensors.is_empty() and is_instance_valid(phone_editor) and phone_editor.has_method("_get_enabled_sensor_names"):
		sensors = phone_editor.call("_get_enabled_sensor_names")
	if not front_camera_mp_step_visited:
		front_camera_mp = "Not set"
	elif front_camera_mp == "Not set" and is_instance_valid(phone_editor) and phone_editor.has_method("_get_front_camera_mp_summary"):
		front_camera_mp = str(phone_editor.call("_get_front_camera_mp_summary"))
	if not rear_camera_mp_step_visited:
		rear_camera_mp = "Not set"
	elif rear_camera_mp == "Not set" and is_instance_valid(phone_editor) and phone_editor.has_method("_get_rear_camera_mp_summary"):
		rear_camera_mp = str(phone_editor.call("_get_rear_camera_mp_summary"))
	if not memory_clock_step_visited:
		memory_clock = "Not set"
	if not refresh_rate_step_visited:
		refresh_rate = "Not set"
	if not cooling_system_step_visited:
		cooling_system = "Not set"

	for column in [specification_readout_left, specification_readout_right]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	specification_readout_entry_count = 0

	# Entries alternate between two independent columns.
	if technology != "Not set":
		_add_specification_readout_entry("RAM TECHNOLOGY", technology)
	if capacity != "Not set":
		_add_specification_readout_entry("RAM", capacity)
	if storage != "Not set":
		_add_specification_readout_entry("INTERNAL STORAGE", storage)
	if internet != "Not set":
		_add_specification_readout_entry("INTERNET SELECTION", internet)
	if wifi != "Not set":
		_add_specification_readout_entry("WI-FI", wifi)
	if bluetooth != "Not set":
		_add_specification_readout_entry("BLUETOOTH", bluetooth)
	if battery != "Not set":
		_add_specification_readout_entry("BATTERY", battery)
	if charging_speed != "Not set":
		_add_specification_readout_entry("CHARGING SPEED", charging_speed)
	if wireless_charge != "Not set":
		_add_specification_readout_entry("WIRELESS CHARGING", wireless_charge)
	if sensors_step_visited and not sensors.is_empty():
		var sensor_summary_parts := PackedStringArray()
		for sensor_name in sensors:
			sensor_summary_parts.append(str(sensor_name))
		var sensor_summary := "\n".join(sensor_summary_parts)
		_add_specification_readout_entry("SENSORS", sensor_summary)
	if front_camera_mp != "Not set":
		_add_specification_readout_entry("FRONT CAMERA MP", front_camera_mp)
	if rear_camera_mp != "Not set":
		_add_specification_readout_entry("REAR CAMERA MP", rear_camera_mp)
	if memory_clock != "Not set":
		_add_specification_readout_entry("MEMORY CLOCK", memory_clock)
	if refresh_rate != "Not set":
		_add_specification_readout_entry("REFRESH RATE", refresh_rate)
	if cooling_system != "Not set":
		_add_specification_readout_entry("COOLING SYSTEM", cooling_system)
	call_deferred("_update_specification_readout_alignment")


func _add_specification_readout_entry(caption_text: String, value_text: String) -> void:
	# Each grid cell stacks its green subject above its larger white value.
	# GridContainer keeps these subject/value pairs arranged left-to-right in
	# two columns, then continues on the next row.
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 3)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var subject := _label(caption_text, 18, Color("#9bd6a7"))
	subject.autowrap_mode = TextServer.AUTOWRAP_OFF
	subject.clip_text = true
	subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subject.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(subject)

	var body := _label(value_text, 24, Color("#ffffff"))
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.clip_text = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.x = 0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(body)

	var target_column := specification_readout_left if specification_readout_entry_count % 2 == 0 else specification_readout_right
	target_column.add_child(entry)
	specification_readout_entry_count += 1

func _update_step_progress(step: int) -> void:
	var progress_value := clampi(step + 1, 1, 37)
	progress_number.text = "STEP %d / 37" % progress_value
	progress_bar.value = progress_value


func _show_thickness_step() -> void:
	_show_worksite_step(1, "_show_thickness_controls")


func _show_border_radius_step() -> void:
	_show_worksite_step(2, "_show_border_radius_controls")


func _show_screen_tech_step() -> void:
	_show_worksite_step(3, "_show_screen_tech_controls")


func _show_screen_size_step() -> void:
	_show_worksite_step(4, "_show_screen_size_controls")


func _show_screen_type_step() -> void:
	_show_worksite_step(5, "_show_screen_type_controls")


func _show_power_volume_step() -> void:
	_show_worksite_step(6, "_show_power_volume_controls")


func _show_speakers_step() -> void:
	_show_worksite_step(7, "_show_speaker_controls")


func _show_charge_port_step() -> void:
	_show_worksite_step(8, "_show_charge_port_controls")
	if is_instance_valid(charge_port_panel):
		charge_port_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _show_side_button_step() -> void:
	_show_worksite_step(9, "_show_side_button_controls")


func _show_home_button_step() -> void:
	_show_worksite_step(10, "_show_home_button_controls")


func _show_device_color_step() -> void:
	_show_worksite_step(11, "_show_device_color_controls")
	# Keep the HUE section clean in the worksite by removing only the selected
	# color readout. The cached HUE bar and HEX input remain interactive.
	var active_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(active_panel):
		var hue_preview_row := active_panel.find_child("SelectedDeviceColor", true, false) as Control
		if is_instance_valid(hue_preview_row):
			var preview_parent := hue_preview_row.get_parent()
			if is_instance_valid(preview_parent):
				preview_parent.remove_child(hue_preview_row)
			hue_preview_row.queue_free()


func _show_front_camera_step() -> void:
	_show_worksite_step(12, "_show_front_camera_controls")


func _show_back_design_step() -> void:
	_show_worksite_step(13, "_show_back_design_controls")


func _show_rear_camera_step() -> void:
	_show_worksite_step(14, "_show_rear_camera_controls")


func _show_ram_technology_step() -> void:
	_show_worksite_step(15, "_show_ram_technology_controls")


func _show_ram_step() -> void:
	_show_worksite_step(16, "_show_ram_controls")


func _show_internal_storage_step() -> void:
	_show_worksite_step(17, "_show_rom_controls")


func _show_internet_selection_step() -> void:
	_show_worksite_step(18, "_show_mobile_network_controls")


func _show_wifi_step() -> void:
	_show_worksite_step(19, "_show_wifi_controls")


func _show_bluetooth_step() -> void:
	_show_worksite_step(20, "_show_bluetooth_controls")


func _show_battery_step() -> void:
	_show_worksite_step(21, "_show_battery_controls")


func _show_charging_speed_step() -> void:
	_show_worksite_step(22, "_show_charging_speed_controls")


func _show_wireless_charge_step() -> void:
	_show_worksite_step(23, "_show_wireless_charge_controls")


func _show_sensors_step() -> void:
	_show_worksite_step(24, "_show_worksite_sensor_controls")



func _show_worksite_box_package_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return

	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()

	phone_editor.set("box_package_color_mode", false)
	var panel := VBoxContainer.new()
	panel.name = "WorksiteBoxPackageControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)

	var heading := _label("BOX PACKAGE", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)

	_add_worksite_box_package_toggle(panel, "SHOW BOX PACKAGE", "box_package_enabled", "_on_box_package_enabled_toggled")
	_add_worksite_box_package_toggle(panel, "OPEN BOX LID", "box_package_open", "_on_box_package_open_toggled")

	var color_button := Button.new()
	color_button.name = "EditBoxPackageColor"
	color_button.text = "CHANGE BOX COLOUR"
	color_button.custom_minimum_size = Vector2(0, 44)
	color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_button.focus_mode = Control.FOCUS_NONE
	_style_button(color_button, true)
	color_button.pressed.connect(_open_worksite_box_package_color_controls)
	panel.add_child(color_button)

	var branding_heading := _label("COMPANY BRANDING", 15, Color("#9bd6a7"))
	panel.add_child(branding_heading)
	_add_worksite_box_package_toggle(panel, "SHOW COMPANY LOGO", "box_package_logo_visible", "_on_box_package_logo_visibility_toggled")
	_add_worksite_box_package_toggle(panel, "SHOW COMPANY NAME", "box_package_name_visible", "_on_box_package_name_visibility_toggled")

	var position_heading := _label("BRANDING POSITION", 15, Color("#9bd6a7"))
	panel.add_child(position_heading)

	var target_row := HBoxContainer.new()
	target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_theme_constant_override("separation", 8)
	panel.add_child(target_row)
	for target in ["LOGO", "NAME"]:
		var target_button := Button.new()
		target_button.name = "BoxPackagePositionTarget_" + target
		target_button.text = target
		target_button.custom_minimum_size = Vector2(0, 42)
		target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_button.focus_mode = Control.FOCUS_NONE
		_style_button(target_button, str(phone_editor.get("box_package_position_target")) == target)
		target_button.pressed.connect(_on_worksite_box_package_position_target_selected.bind(target))
		target_row.add_child(target_button)

	var position_pad := GridContainer.new()
	position_pad.name = "BoxPackagePositionPad"
	position_pad.columns = 3
	position_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	position_pad.add_theme_constant_override("h_separation", 7)
	position_pad.add_theme_constant_override("v_separation", 6)
	panel.add_child(position_pad)
	_add_worksite_box_package_position_spacer(position_pad)
	_add_worksite_box_package_position_button(position_pad, "↑", Vector2i(0, 1))
	_add_worksite_box_package_position_spacer(position_pad)
	_add_worksite_box_package_position_button(position_pad, "←", Vector2i(-1, 0))
	var reset_button := Button.new()
	reset_button.name = "ResetBoxPackageBrandingPosition"
	reset_button.text = "RESET"
	reset_button.custom_minimum_size = Vector2(64, 42)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_size_override("font_size", 11)
	_style_button(reset_button, true)
	reset_button.pressed.connect(Callable(phone_editor, "_reset_box_package_position"))
	position_pad.add_child(reset_button)
	_add_worksite_box_package_position_button(position_pad, "→", Vector2i(1, 0))
	_add_worksite_box_package_position_spacer(position_pad)
	_add_worksite_box_package_position_button(position_pad, "↓", Vector2i(0, -1))
	_add_worksite_box_package_position_spacer(position_pad)

	var movement_row := HBoxContainer.new()
	movement_row.name = "BoxPackageMovementSize"
	movement_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	movement_row.add_theme_constant_override("separation", 6)
	panel.add_child(movement_row)
	var movement_label := _label("MOVEMENT", 12, Color("#dce9df"))
	movement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	movement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	movement_row.add_child(movement_label)
	for movement in [
		{"label": "SMALL", "value": 0.03},
		{"label": "MED", "value": 0.08},
		{"label": "LARGE", "value": 0.16}
	]:
		var movement_button := Button.new()
		movement_button.text = str(movement["label"])
		movement_button.custom_minimum_size = Vector2(58, 38)
		movement_button.focus_mode = Control.FOCUS_NONE
		movement_button.add_theme_font_size_override("font_size", 10)
		_style_button(movement_button, is_equal_approx(float(phone_editor.get("box_package_position_step")), float(movement["value"])))
		movement_button.pressed.connect(_on_worksite_box_package_movement_selected.bind(float(movement["value"])))
		movement_row.add_child(movement_button)

	step_panels[30] = panel


func _add_worksite_box_package_toggle(parent: Control, caption: String, property_name: String, callback_name: String) -> void:
	var row := HBoxContainer.new()
	row.name = property_name + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var caption_label := _label(caption, 14, Color("#e7f6ff"))
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption_label)

	var enabled := bool(phone_editor.get(property_name))
	var toggle := TextureButton.new()
	toggle.name = property_name + "Toggle"
	toggle.custom_minimum_size = Vector2(38, 38)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var unchecked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", false)
	var checked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", true)
	toggle.texture_normal = unchecked_icon
	toggle.texture_hover = unchecked_icon
	toggle.texture_pressed = checked_icon
	toggle.texture_disabled = unchecked_icon
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(Callable(phone_editor, callback_name))
	row.add_child(toggle)


func _add_worksite_box_package_position_spacer(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 42)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _add_worksite_box_package_position_button(parent: GridContainer, caption: String, direction: Vector2i) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(48, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 21)
	_style_button(button, true)
	button.pressed.connect(Callable(phone_editor, "_move_box_package_branding").bind(direction))
	parent.add_child(button)


func _on_worksite_box_package_position_target_selected(target: String) -> void:
	phone_editor.set("box_package_position_target", target)
	_show_worksite_box_package_controls()


func _on_worksite_box_package_movement_selected(step: float) -> void:
	phone_editor.set("box_package_position_step", step)
	_show_worksite_box_package_controls()


func _open_worksite_box_package_color_controls() -> void:
	phone_editor.call("_show_device_color_controls", false, false, false, false, false, false, true)
	var color_panel := phone_editor.get("active_feature_panel") as Control
	if not is_instance_valid(color_panel) or color_panel.get_child_count() == 0:
		return
	var header := color_panel.get_child(0) as HBoxContainer
	if not is_instance_valid(header) or header.get_child_count() == 0:
		return
	var back_button := header.get_child(0) as Button
	if not is_instance_valid(back_button):
		return
	var legacy_back_callback := Callable(phone_editor, "_show_box_package_controls")
	if back_button.pressed.is_connected(legacy_back_callback):
		back_button.pressed.disconnect(legacy_back_callback)
	back_button.pressed.connect(_show_worksite_box_package_controls)



func _show_worksite_phone_case_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	if wizard_step != 31:
		var stale_case_panel := step_panels.get(31) as Control
		if is_instance_valid(stale_case_panel):
			var stale_parent := stale_case_panel.get_parent()
			if is_instance_valid(stale_parent):
				stale_parent.remove_child(stale_case_panel)
			stale_case_panel.queue_free()
			step_panels.erase(31)
		return

	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()

	phone_editor.set("phone_case_color_mode", false)
	var panel := VBoxContainer.new()
	panel.name = "WorksitePhoneCaseControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)

	var heading := _label("PHONE CASE", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)

	var description := _label("Build a protective shell fitted to this phone's current geometry and hardware.", 13, Color("#dce9df"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)

	_add_worksite_phone_case_toggle(panel)

	if bool(phone_editor.get("phone_case_building")):
		var building_heading := _label("BUILDING CASE", 16, Color("#9bd6a7"), HORIZONTAL_ALIGNMENT_CENTER)
		building_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(building_heading)

		var shimmer := ColorRect.new()
		shimmer.name = "PhoneCaseBuildShimmer"
		shimmer.custom_minimum_size = Vector2(0, 12)
		shimmer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.06,0.14,0.09,1.0);
uniform vec4 shine_color : source_color = vec4(0.38,0.78,0.46,1.0);
void fragment() {
	float sweep = fract(UV.x * 1.25 - TIME * 0.72);
	float shine = smoothstep(0.02,0.18,sweep) * (1.0-smoothstep(0.22,0.42,sweep));
	COLOR = mix(base_color, shine_color, shine * 0.9);
}
"""
		var shimmer_material := ShaderMaterial.new()
		shimmer_material.shader = shader
		shimmer.material = shimmer_material
		panel.add_child(shimmer)

		var building_note := _label("Matching cameras, speakers, charging port and side buttons…", 12, Color("#b8d8be"))
		building_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(building_note)
	elif bool(phone_editor.get("phone_case_custom_enabled")) and bool(phone_editor.get("phone_case_built")):
		var ready_label := _label("CUSTOM CASE FITTED TO CURRENT DEVICE", 13, Color("#9bd6a7"))
		panel.add_child(ready_label)

		var color_button := Button.new()
		color_button.name = "EditPhoneCaseColor"
		color_button.text = "CHANGE CASE COLOUR"
		color_button.custom_minimum_size = Vector2(0, 44)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_button.focus_mode = Control.FOCUS_NONE
		_style_button(color_button, true)
		color_button.pressed.connect(_open_worksite_phone_case_color_controls)
		panel.add_child(color_button)

		var design_button := Button.new()
		design_button.name = "EditPhoneCaseDesign"
		design_button.text = "CHANGE CASE DESIGN"
		design_button.custom_minimum_size = Vector2(0, 44)
		design_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		design_button.focus_mode = Control.FOCUS_NONE
		_style_button(design_button, false)
		design_button.pressed.connect(_show_worksite_phone_case_design_controls)
		panel.add_child(design_button)
	else:
		var disabled_note := _label("Enable the custom case to generate its fitted 3D shell.", 12, Color("#b8d8be"))
		disabled_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(disabled_note)

	var preview := phone_editor.get("phone_case_preview") as Node3D
	if is_instance_valid(preview):
		preview.visible = (
			bool(phone_editor.get("phone_case_custom_enabled"))
			and bool(phone_editor.get("phone_case_built"))
			and not bool(phone_editor.get("phone_case_building"))
			and not bool(phone_editor.get("charger_preview_mode"))
			and not bool(phone_editor.get("box_package_preview_mode"))
		)


func _add_worksite_phone_case_toggle(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "EnableCustomCaseRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var caption := _label("ENABLE CUSTOM CASE", 14, Color("#e7f6ff"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)

	var enabled := bool(phone_editor.get("phone_case_custom_enabled"))
	var toggle := TextureButton.new()
	toggle.name = "EnableCustomPhoneCaseCheckbox"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var unchecked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", false)
	var checked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", true)
	toggle.texture_normal = unchecked_icon
	toggle.texture_hover = unchecked_icon
	toggle.texture_pressed = checked_icon
	toggle.texture_disabled = unchecked_icon
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(Callable(phone_editor, "_on_phone_case_custom_toggled"))
	row.add_child(toggle)


func _show_worksite_phone_case_design_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	if wizard_step != 31:
		return
	if not bool(phone_editor.get("phone_case_custom_enabled")) or not bool(phone_editor.get("phone_case_built")):
		_show_worksite_phone_case_controls()
		return

	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()

	phone_editor.set("phone_case_color_mode", false)
	var panel := VBoxContainer.new()
	panel.name = "WorksitePhoneCaseDesignControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	panel.add_child(header)
	var back_button := Button.new()
	back_button.name = "BackToPhoneCaseControls"
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(38, 38)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button, false)
	back_button.pressed.connect(_show_worksite_phone_case_controls)
	header.add_child(back_button)

	var title := _label("CASE BACK DESIGN", 17, Color("#c7eacb"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var note := _label("Choose a finish for the back of your case. Your selected colour and gradient stay unchanged.", 12, Color("#dce9df"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(note)

	var design_names := ["Smooth", "Carbon Weave", "Hex Pattern", "Racing Stripes", "Grip Ridges"]
	var selected_style := int(phone_editor.get("phone_case_design_style"))
	for index in range(design_names.size()):
		var option := Button.new()
		option.name = "PhoneCaseDesignOption_%02d" % index
		option.text = design_names[index].to_upper() + ("   ✓ ACTIVE" if index == selected_style else "")
		option.custom_minimum_size = Vector2(0, 48)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_style_button(option, index == selected_style)
		option.pressed.connect(Callable(phone_editor, "_on_phone_case_design_selected").bind(index))
		panel.add_child(option)


func _open_worksite_phone_case_color_controls() -> void:
	phone_editor.call("_show_device_color_controls", false, true)
	var color_panel := phone_editor.get("active_feature_panel") as Control
	if not is_instance_valid(color_panel) or color_panel.get_child_count() == 0:
		return
	var header := color_panel.get_child(0) as HBoxContainer
	if not is_instance_valid(header) or header.get_child_count() == 0:
		return
	var back_button := header.get_child(0) as Button
	if not is_instance_valid(back_button):
		return
	var legacy_back_callback := Callable(phone_editor, "_show_phone_case_controls")
	if back_button.pressed.is_connected(legacy_back_callback):
		back_button.pressed.disconnect(legacy_back_callback)
	back_button.pressed.connect(_show_worksite_phone_case_controls)



func _show_worksite_charger_controls(page: String = "HOME") -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return

	var normalized_page := page.to_upper()
	if normalized_page == "FINISH":
		_open_worksite_charger_color_controls()
		return
	if not ["HOME", "PLUG", "CABLE", "POWER"].has(normalized_page):
		normalized_page = "HOME"

	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()

	phone_editor.set("charger_controls_page", normalized_page)
	phone_editor.set("charger_color_mode", false)

	var panel := VBoxContainer.new()
	panel.name = "WorksiteChargerControls_" + normalized_page
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)

	if normalized_page != "HOME":
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		panel.add_child(header)

		var back_button := Button.new()
		back_button.name = "ChargerSettingsBack"
		back_button.text = "‹"
		back_button.custom_minimum_size = Vector2(42, 40)
		back_button.focus_mode = Control.FOCUS_NONE
		_style_button(back_button, false)
		back_button.add_theme_font_size_override("font_size", 24)
		back_button.pressed.connect(_show_worksite_charger_controls.bind("HOME"))
		header.add_child(back_button)

		var page_title := _label("CHARGER " + normalized_page, 17, Color("#c7eacb"))
		page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(page_title)

		match normalized_page:
			"PLUG":
				var plug_heading := _label("WALL PLUG STANDARD", 14, Color("#9bd6a7"))
				panel.add_child(plug_heading)
				for plug_name in ["UK", "EU", "US", "Universal"]:
					var plug_button := Button.new()
					plug_button.name = "ChargerPlug_" + plug_name
					plug_button.text = plug_name + ("   ✓ SELECTED" if str(phone_editor.get("charger_plug_type")) == plug_name else "")
					plug_button.custom_minimum_size = Vector2(0, 48)
					plug_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					plug_button.focus_mode = Control.FOCUS_NONE
					_style_button(plug_button, str(phone_editor.get("charger_plug_type")) == plug_name)
					plug_button.pressed.connect(Callable(phone_editor, "_on_charger_plug_selected").bind(plug_name))
					panel.add_child(plug_button)
				var plug_note := _label("Changes the physical wall-pin layout on the 3D adapter.", 12, Color("#b8d8be"))
				plug_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				panel.add_child(plug_note)

			"CABLE":
				var cable_heading := _label("PHYSICAL CHARGING CABLE", 14, Color("#9bd6a7"))
				panel.add_child(cable_heading)
				_add_worksite_charger_toggle(
					panel,
					"ENABLE PHYSICAL CABLE",
					"charger_cable_enabled",
					"_on_charger_cable_enabled_toggled",
					"EnableChargingCableModel"
				)
				var compatible_cable_options: Array = phone_editor.call("_charger_cable_options_for_phone")
				for cable_name_value in compatible_cable_options:
					var cable_name := str(cable_name_value)
					var cable_button := Button.new()
					cable_button.name = "ChargerCable_" + cable_name.replace(" ", "").replace("-", "")
					cable_button.text = cable_name + ("   ✓ SELECTED" if str(phone_editor.get("charger_cable_type")) == cable_name else "")
					cable_button.custom_minimum_size = Vector2(0, 48)
					cable_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					cable_button.focus_mode = Control.FOCUS_NONE
					_style_button(cable_button, str(phone_editor.get("charger_cable_type")) == cable_name)
					cable_button.pressed.connect(Callable(phone_editor, "_on_charger_cable_selected").bind(cable_name))
					panel.add_child(cable_button)

				var cable_note_text := "A short U-shaped cable with a phone-side connector that matches the selected charging port."
				if str(phone_editor.get("charge_port_type")) == "None":
					cable_note_text = "Choose a phone charging port first. Compatible cable connectors will appear automatically."
				var cable_note := _label(cable_note_text, 12, Color("#b8d8be"))
				cable_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				panel.add_child(cable_note)

			"POWER":
				var wattage_heading := _label("OUTPUT POWER", 14, Color("#9bd6a7"))
				panel.add_child(wattage_heading)

				var wattage_value := _label("%d W" % int(phone_editor.get("charger_wattage")), 32, Color("#ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
				wattage_value.name = "ChargerOutputWattageValue"
				wattage_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				panel.add_child(wattage_value)
				phone_editor.set("charger_wattage_label", wattage_value)

				var wattage_range := _label("2W — 200W · INDEPENDENT ADAPTER OUTPUT", 11, Color("#b8d8be"), HORIZONTAL_ALIGNMENT_CENTER)
				wattage_range.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				panel.add_child(wattage_range)

				var slider_row := HBoxContainer.new()
				slider_row.name = "ChargerWattageVerticalSliderRow"
				slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
				slider_row.add_theme_constant_override("separation", 12)
				panel.add_child(slider_row)

				var minimum := _label("2W", 12, Color("#b8d8be"))
				minimum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slider_row.add_child(minimum)

				var wattage_slider := VSlider.new()
				wattage_slider.name = "ChargerOutputVerticalSlider"
				wattage_slider.min_value = 2
				wattage_slider.max_value = 200
				wattage_slider.step = 1
				wattage_slider.value = int(phone_editor.get("charger_wattage"))
				wattage_slider.custom_minimum_size = Vector2(52, 245)
				wattage_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
				wattage_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				wattage_slider.focus_mode = Control.FOCUS_NONE
				wattage_slider.tick_count = 0
				wattage_slider.value_changed.connect(Callable(phone_editor, "_on_charger_wattage_changed"))
				phone_editor.call("_style_custom_slider", wattage_slider)
				slider_row.add_child(wattage_slider)
				phone_editor.set("charger_wattage_slider", wattage_slider)

				var maximum := _label("200W", 12, Color("#b8d8be"))
				maximum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slider_row.add_child(maximum)

	else:
		var heading := _label("CHARGER ADAPTER", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(heading)

		var description := _label("Configure the adapter, cable and output power. Drag the centre preview to inspect the product from every angle.", 12, Color("#dce9df"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(description)

		_add_worksite_charger_toggle(
			panel,
			"ENABLE CHARGER MODEL",
			"charger_enabled",
			"_on_charger_enabled_toggled",
			"EnableChargerPreview"
		)
		_add_worksite_charger_toggle(
			panel,
			"ENABLE PHYSICAL CABLE",
			"charger_cable_enabled",
			"_on_charger_cable_enabled_toggled",
			"EnableChargingCableModelHome"
		)

		var plug_option := Button.new()
		plug_option.name = "OpenChargerPlugSettings"
		plug_option.text = "PLUG STANDARD     ›     " + str(phone_editor.get("charger_plug_type"))
		plug_option.custom_minimum_size = Vector2(0, 48)
		plug_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plug_option.focus_mode = Control.FOCUS_NONE
		_style_button(plug_option, false)
		plug_option.pressed.connect(_show_worksite_charger_controls.bind("PLUG"))
		panel.add_child(plug_option)

		var cable_option := Button.new()
		cable_option.name = "OpenChargerCableSettings"
		cable_option.text = "CABLE TYPE     ›     " + str(phone_editor.get("charger_cable_type"))
		cable_option.custom_minimum_size = Vector2(0, 48)
		cable_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cable_option.focus_mode = Control.FOCUS_NONE
		_style_button(cable_option, false)
		cable_option.pressed.connect(_show_worksite_charger_controls.bind("CABLE"))
		panel.add_child(cable_option)

		var power_option := Button.new()
		power_option.name = "OpenChargerPowerSettings"
		power_option.text = "OUTPUT POWER     ›     %d W" % int(phone_editor.get("charger_wattage"))
		power_option.custom_minimum_size = Vector2(0, 48)
		power_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		power_option.focus_mode = Control.FOCUS_NONE
		_style_button(power_option, false)
		power_option.pressed.connect(_show_worksite_charger_controls.bind("POWER"))
		panel.add_child(power_option)

		var color_option := Button.new()
		color_option.name = "OpenChargerFinishSettings"
		color_option.text = "ADAPTER COLOUR     ›     #" + Color(phone_editor.get("charger_body_color")).to_html(false).to_upper()
		color_option.custom_minimum_size = Vector2(0, 48)
		color_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_option.focus_mode = Control.FOCUS_NONE
		_style_button(color_option, true)
		color_option.pressed.connect(_open_worksite_charger_color_controls)
		panel.add_child(color_option)

	step_panels[32] = panel




func _show_worksite_smartwatch_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	if wizard_step != 35:
		return

	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()

	var panel := VBoxContainer.new()
	panel.name = "WorksiteSmartwatchControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)

	var heading := _label("SMART WATCH", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)
	var description := _label("Add a rotatable 3D smartwatch accessory to the product preview. Drag the centre preview to inspect the case, display and strap.", 12, Color("#dce9df"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)

	var enable_row := HBoxContainer.new()
	enable_row.name = "SmartwatchEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 8)
	panel.add_child(enable_row)

	var enable_label := _label("ENABLE SMART WATCH", 14, Color("#e7f6ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)

	var toggle := TextureButton.new()
	toggle.name = "EnableSmartwatchModel"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var unchecked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", false)
	var checked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", true)
	toggle.texture_normal = unchecked_icon
	toggle.texture_hover = unchecked_icon
	toggle.texture_pressed = checked_icon
	toggle.texture_disabled = unchecked_icon
	toggle.toggle_mode = true
	toggle.button_pressed = bool(phone_editor.get("smartwatch_enabled"))
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(Callable(phone_editor, "_on_smartwatch_enabled_toggled"))
	enable_row.add_child(toggle)

	if bool(phone_editor.get("smartwatch_enabled")):
		var color_button := Button.new()
		color_button.name = "OpenSmartwatchDeviceColorEditor"
		color_button.text = "CUSTOMIZE SMART WATCH COLOUR     ›     #" + Color(phone_editor.get("smartwatch_body_color")).to_html(false).to_upper()
		color_button.custom_minimum_size = Vector2(0, 48)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_button.focus_mode = Control.FOCUS_NONE
		_style_button(color_button, true)
		color_button.pressed.connect(_open_worksite_smartwatch_color_controls)
		panel.add_child(color_button)
	else:
		var disabled_note := _label("Enable the watch to show its rotatable 3D preview and unlock its custom colour.", 12, Color("#b8d8be"))
		disabled_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(disabled_note)

	step_panels[35] = panel


func _open_worksite_smartwatch_color_controls() -> void:
	if not is_instance_valid(phone_editor) or wizard_step != 35:
		return
	phone_editor.call("_show_device_color_controls", false, false, false, true, false)
	var color_panel := phone_editor.get("active_feature_panel") as Control
	if not is_instance_valid(color_panel):
		return
	var header := color_panel.get_child(0) as Control if color_panel.get_child_count() > 0 else null
	if is_instance_valid(header) and header.get_child_count() > 0:
		var back_button := header.get_child(0) as Button
		if is_instance_valid(back_button):
			_style_button(back_button, false)


func _show_worksite_earbuds_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	if wizard_step != 34:
		return
	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()

	var panel := VBoxContainer.new()
	panel.name = "WorksiteWirelessEarbudsControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)

	var heading := _label("WIRELESS EARBUDS", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)
	var description := _label("Add a rotatable 3D wireless-earbuds charging case. The lid stays closed and both earbuds remain stored inside.", 12, Color("#dce9df"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)

	var enable_row := HBoxContainer.new()
	enable_row.name = "WirelessEarbudsEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 8)
	panel.add_child(enable_row)
	var enable_label := _label("ENABLE EARBUDS CASE", 14, Color("#e7f6ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)

	var toggle := TextureButton.new()
	toggle.name = "EnableWirelessEarbudsModel"
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var unchecked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", false)
	var checked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", true)
	toggle.texture_normal = unchecked_icon
	toggle.texture_hover = unchecked_icon
	toggle.texture_pressed = checked_icon
	toggle.texture_disabled = unchecked_icon
	toggle.toggle_mode = true
	toggle.button_pressed = bool(phone_editor.get("wireless_earbuds_enabled"))
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(Callable(phone_editor, "_on_earbuds_enabled_toggled"))
	enable_row.add_child(toggle)

	if bool(phone_editor.get("wireless_earbuds_enabled")):
		var color_button := Button.new()
		color_button.name = "OpenWirelessEarbudsDeviceColorEditor"
		color_button.text = "CUSTOMIZE CASE COLOUR     ›     #" + Color(phone_editor.get("wireless_earbuds_body_color")).to_html(false).to_upper()
		color_button.custom_minimum_size = Vector2(0, 48)
		color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_button.focus_mode = Control.FOCUS_NONE
		_style_button(color_button, true)
		color_button.pressed.connect(_open_worksite_earbuds_color_controls)
		panel.add_child(color_button)
	else:
		var disabled_note := _label("Enable the case to show its rotatable 3D preview and unlock its custom colour.", 12, Color("#b8d8be"))
		disabled_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(disabled_note)
	step_panels[34] = panel


func _open_worksite_earbuds_color_controls() -> void:
	if not is_instance_valid(phone_editor) or wizard_step != 34:
		return
	phone_editor.call("_show_device_color_controls", false, false, false, false, false, true)
	var color_panel := phone_editor.get("active_feature_panel") as Control
	if not is_instance_valid(color_panel):
		return
	var header := color_panel.get_child(0) as Control if color_panel.get_child_count() > 0 else null
	if is_instance_valid(header) and header.get_child_count() > 0:
		var back_button := header.get_child(0) as Button
		if is_instance_valid(back_button):
			_style_button(back_button, false)


func _show_worksite_protection_glass_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	if wizard_step != 33:
		return
	var previous_panel := phone_editor.get("active_feature_panel") as Control
	if is_instance_valid(previous_panel):
		var previous_parent := previous_panel.get_parent()
		if is_instance_valid(previous_parent):
			previous_parent.remove_child(previous_panel)
		previous_panel.queue_free()
	var panel := VBoxContainer.new()
	panel.name = "WorksiteProtectionGlassControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)
	selection_stack.add_child(panel)
	var heading := _label("PROTECTION GLASS", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)
	var description := _label("Install precision-cut tempered glass fitted to the active display, curves and front-camera layout.", 12, Color("#dce9df"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)
	var enable_row := HBoxContainer.new()
	enable_row.name = "ProtectionGlassEnableRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.add_theme_constant_override("separation", 8)
	panel.add_child(enable_row)
	var enable_label := _label("INSTALL PROTECTION GLASS", 14, Color("#e7f6ff"))
	enable_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_label)
	var screen_is_enabled := bool(phone_editor.get("screen_enabled"))
	var protector_toggle := TextureButton.new()
	protector_toggle.name = "EnableProtectionGlass"
	protector_toggle.custom_minimum_size = Vector2(40, 40)
	protector_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	protector_toggle.ignore_texture_size = true
	protector_toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var unchecked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", false)
	var checked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", true)
	protector_toggle.texture_normal = unchecked_icon
	protector_toggle.texture_hover = unchecked_icon
	protector_toggle.texture_pressed = checked_icon
	protector_toggle.texture_disabled = unchecked_icon
	protector_toggle.toggle_mode = true
	protector_toggle.button_pressed = bool(phone_editor.get("screen_protector_enabled"))
	protector_toggle.disabled = not screen_is_enabled
	protector_toggle.focus_mode = Control.FOCUS_NONE
	protector_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	protector_toggle.toggled.connect(Callable(phone_editor, "_on_screen_protector_toggled"))
	enable_row.add_child(protector_toggle)
	if not screen_is_enabled:
		var screen_hint := _label("Enable the phone screen first. Protection glass fits the active display surfaces.", 12, Color("#e6c98d"))
		screen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(screen_hint)
		step_panels[33] = panel
		return
	if not bool(phone_editor.get("screen_protector_enabled")):
		var disabled_note := _label("Switch on protection glass to install the fitted 3D layer.", 12, Color("#b8d8be"))
		disabled_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(disabled_note)
		step_panels[33] = panel
		return
	panel.add_child(_label("GLASS FINISH", 14, Color("#9bd6a7")))
	for finish_name in ["Ultra Clear", "Matte", "Anti-Reflective"]:
		var finish_button := Button.new()
		finish_button.name = "ProtectorFinish_" + finish_name.replace("-", "").replace(" ", "")
		finish_button.text = finish_name.to_upper() + ("   ✓" if str(phone_editor.get("screen_protector_finish")) == finish_name else "")
		finish_button.custom_minimum_size = Vector2(0, 44)
		finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		finish_button.focus_mode = Control.FOCUS_NONE
		var is_selected := str(phone_editor.get("screen_protector_finish")) == finish_name
		_style_button(finish_button, is_selected)
		finish_button.pressed.connect(Callable(phone_editor, "_on_screen_protector_finish_selected").bind(finish_name))
		panel.add_child(finish_button)
	panel.add_child(_label("GLASS THICKNESS", 14, Color("#9bd6a7")))
	var thickness_label := _label("", 13, Color("#dce9df"), HORIZONTAL_ALIGNMENT_CENTER)
	thickness_label.name = "ProtectionGlassThicknessValue"
	thickness_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(thickness_label)
	phone_editor.set("screen_protector_thickness_label", thickness_label)
	var thickness_slider := HSlider.new()
	thickness_slider.name = "ProtectionGlassThicknessSlider"
	thickness_slider.min_value = 0.003
	thickness_slider.max_value = 0.009
	thickness_slider.step = 0.0005
	thickness_slider.value = float(phone_editor.get("screen_protector_thickness"))
	thickness_slider.custom_minimum_size = Vector2(0, 38)
	thickness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thickness_slider.focus_mode = Control.FOCUS_NONE
	phone_editor.call("_style_custom_slider", thickness_slider)
	thickness_slider.value_changed.connect(Callable(phone_editor, "_on_screen_protector_thickness_changed"))
	panel.add_child(thickness_slider)
	phone_editor.call("_update_screen_protector_thickness_label")
	if bool(phone_editor.get("screen_protector_building")):
		var build_panel := PanelContainer.new()
		build_panel.name = "ProtectionGlassBuildLoading"
		var build_style := StyleBoxFlat.new()
		build_style.bg_color = Color("#0c2a16")
		build_style.border_color = Color("#3d8b50")
		build_style.set_border_width_all(1)
		build_style.set_corner_radius_all(10)
		build_style.content_margin_left = 12
		build_style.content_margin_right = 12
		build_style.content_margin_top = 12
		build_style.content_margin_bottom = 12
		build_panel.add_theme_stylebox_override("panel", build_style)
		panel.add_child(build_panel)
		var loading := VBoxContainer.new()
		loading.add_theme_constant_override("separation", 9)
		build_panel.add_child(loading)
		var loading_title := _label("Building protection glass", 16, Color("#eaf8ed"), HORIZONTAL_ALIGNMENT_CENTER)
		loading.add_child(loading_title)
		var shimmer := ColorRect.new()
		shimmer.name = "ProtectionGlassBuildShimmer"
		shimmer.custom_minimum_size = Vector2(0, 12)
		shimmer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shimmer_shader := Shader.new()
		shimmer_shader.code = """
shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(0.04,0.16,0.08,1.0);
uniform vec4 shine_color : source_color = vec4(0.38,0.78,0.46,1.0);
void fragment(){
	float sweep=fract(UV.x*1.25-TIME*0.72);
	float shine=smoothstep(0.02,0.18,sweep)*(1.0-smoothstep(0.22,0.42,sweep));
	COLOR=mix(base_color,shine_color,shine*0.9);
}
"""
		var shimmer_material := ShaderMaterial.new()
		shimmer_material.shader = shimmer_shader
		shimmer.material = shimmer_material
		loading.add_child(shimmer)
		var building_note := _label("Matching the display shape, curves and front-camera cutouts…", 11, Color("#b8d8be"), HORIZONTAL_ALIGNMENT_CENTER)
		building_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		loading.add_child(building_note)
	var cutout_note := _label("CAMERA & SENSOR CUTOUTS  ·  AUTO-FITTED", 11, Color("#9bd6a7"), HORIZONTAL_ALIGNMENT_CENTER)
	cutout_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(cutout_note)
	step_panels[33] = panel


func _add_worksite_charger_toggle(
	parent: Control,
	caption: String,
	property_name: String,
	callback_name: String,
	control_name: String
) -> void:
	var row := HBoxContainer.new()
	row.name = control_name + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var caption_label := _label(caption, 14, Color("#e7f6ff"))
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption_label)

	var enabled := bool(phone_editor.get(property_name))
	var toggle := TextureButton.new()
	toggle.name = control_name
	toggle.custom_minimum_size = Vector2(40, 40)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var unchecked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", false)
	var checked_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", true)
	toggle.texture_normal = unchecked_icon
	toggle.texture_hover = unchecked_icon
	toggle.texture_pressed = checked_icon
	toggle.texture_disabled = unchecked_icon
	toggle.toggle_mode = true
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.toggled.connect(Callable(phone_editor, callback_name))
	row.add_child(toggle)


func _open_worksite_charger_color_controls() -> void:
	phone_editor.call("_show_device_color_controls", false, false, true)
	var color_panel := phone_editor.get("active_feature_panel") as Control
	if not is_instance_valid(color_panel) or color_panel.get_child_count() == 0:
		return
	var header := color_panel.get_child(0) as HBoxContainer
	if not is_instance_valid(header) or header.get_child_count() == 0:
		return
	var back_button := header.get_child(0) as Button
	if not is_instance_valid(back_button):
		return
	_style_button(back_button, false)
	var legacy_back_callback := Callable(phone_editor, "_show_charger_controls")
	if back_button.pressed.is_connected(legacy_back_callback):
		back_button.pressed.disconnect(legacy_back_callback)
	back_button.pressed.connect(_show_worksite_charger_controls.bind("HOME"))


func _show_worksite_sensor_controls() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return

	var panel := VBoxContainer.new()
	panel.name = "PhoneSensorSelectionControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 340)
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)

	var heading := _label("PHONE SENSORS", 20, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)

	var count_label := _label("", 14, Color("#d8f1ff"), HORIZONTAL_ALIGNMENT_CENTER)
	count_label.name = "EnabledSensorCount"
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(count_label)

	# All ten sensor choices fit directly in the right panel: five rows,
	# two columns, with no ScrollContainer and no scrolling interaction.
	var options := GridContainer.new()
	options.name = "PhoneSensorOptions"
	options.columns = 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("h_separation", 10)
	options.add_theme_constant_override("v_separation", 8)
	panel.add_child(options)

	var sensors: Dictionary = phone_editor.get("selected_phone_sensors")
	var sensor_names: Array[String] = []
	for sensor_value in sensors.keys():
		sensor_names.append(str(sensor_value))
	sensor_names.sort()

	for sensor_name in sensor_names:
		var row := HBoxContainer.new()
		row.name = "SensorRow_" + sensor_name.replace(" ", "_").replace("/", "_")
		row.custom_minimum_size = Vector2(0, 54)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 5)
		options.add_child(row)

		var sensor_label := _label(sensor_name, 16, Color("#e7f6ff"))
		sensor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sensor_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sensor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sensor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(sensor_label)

		var enabled := bool(sensors.get(sensor_name, false))
		var toggle := TextureButton.new()
		toggle.name = "SensorEnabledToggle"
		toggle.custom_minimum_size = Vector2(38, 38)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.ignore_texture_size = true
		toggle.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var checkbox_icon: Texture2D = phone_editor.call("_make_side_button_checkbox_icon", enabled)
		toggle.texture_normal = checkbox_icon
		toggle.texture_hover = checkbox_icon
		toggle.texture_pressed = phone_editor.call("_make_side_button_checkbox_icon", true)
		toggle.texture_disabled = phone_editor.call("_make_side_button_checkbox_icon", false)
		toggle.toggle_mode = true
		toggle.button_pressed = enabled
		toggle.tooltip_text = "Enable or disable " + sensor_name
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.mouse_filter = Control.MOUSE_FILTER_STOP
		toggle.toggled.connect(Callable(phone_editor, "_on_phone_sensor_toggled").bind(sensor_name, count_label, toggle))
		row.add_child(toggle)

	if sensor_names.is_empty():
		var empty_label := _label("NO SENSOR OPTIONS FOUND", 13, Color("#e7f6ff"), HORIZONTAL_ALIGNMENT_CENTER)
		empty_label.custom_minimum_size = Vector2(0, 54)
		options.add_child(empty_label)

	phone_editor.call("_update_sensor_count_label", count_label)


func _show_worksite_front_camera_mp_controls() -> void:
	if not is_instance_valid(phone_editor):
		return

	var panel := VBoxContainer.new()
	panel.name = "WorksiteFrontCameraMegapixelControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)

	var heading := _label("FRONT CAMERA MP", 19, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)

	if not bool(phone_editor.get("front_camera_enabled")):
		var hint := _label("Front camera not enabled", 11, Color("#91b8a0"), HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(hint)
		return

	var camera_rows: Array = phone_editor.call("_get_front_camera_mp_layout")
	for row_index in range(camera_rows.size()):
		var row_data: Array = camera_rows[row_index]
		var camera_row := HBoxContainer.new()
		camera_row.name = "WorksiteFrontCameraMegapixelRow_%d" % (row_index + 1)
		camera_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		camera_row.alignment = BoxContainer.ALIGNMENT_CENTER
		camera_row.add_theme_constant_override("separation", 12)
		panel.add_child(camera_row)

		for camera_entry_value in row_data:
			var camera_entry: Dictionary = camera_entry_value
			var property_name := str(camera_entry.get("property", "front_camera_megapixels"))
			var camera_label := str(camera_entry.get("label", "01"))
			var megapixels := int(phone_editor.get(StringName(property_name)))
			var callback := Callable(phone_editor, "_set_front_camera_mp_value").bind(property_name)
			var card := phone_editor.call("_make_camera_mp_slider_card", camera_label, megapixels, callback) as Control
			camera_row.add_child(card)


func _show_worksite_rear_camera_mp_controls() -> void:
	if not is_instance_valid(phone_editor):
		return

	var panel := VBoxContainer.new()
	panel.name = "WorksiteRearCameraMegapixelControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_constant_override("separation", 8)
	phone_editor.set("active_feature_panel", panel)

	var heading := _label("REAR CAMERA MP", 19, Color("#c7eacb"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(heading)

	var camera_modules: Array = phone_editor.get("rear_camera_modules")
	if camera_modules.is_empty():
		var hint := _label("No rear cameras added", 11, Color("#91b8a0"), HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(hint)
		return

	# Keep every rear-camera slider on the same horizontal line, including all
	# five supported camera modules.
	var slider_row := HBoxContainer.new()
	slider_row.name = "WorksiteRearCameraMegapixelOptions"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 8)
	panel.add_child(slider_row)

	for camera_index in range(camera_modules.size()):
		var camera_data: Dictionary = camera_modules[camera_index]
		var camera_id := int(camera_data.get("id", camera_index + 1))
		var megapixels := int(camera_data.get("mp", 12))
		var callback := func(next_mp: int) -> void:
			var live_modules: Array = phone_editor.get("rear_camera_modules")
			for module_index in range(live_modules.size()):
				var module_data: Dictionary = live_modules[module_index]
				if int(module_data.get("id", -1)) == camera_id:
					module_data["mp"] = next_mp
					live_modules[module_index] = module_data
					break
			phone_editor.set("rear_camera_modules", live_modules)
			phone_editor.call("_update_camera_software_summary")
		var card := phone_editor.call("_make_camera_mp_slider_card", "%02d" % (camera_index + 1), megapixels, callback) as Control
		slider_row.add_child(card)


func _show_front_camera_mp_step() -> void:
	_show_worksite_step(25, "_show_worksite_front_camera_mp_controls")


func _show_rear_camera_mp_step() -> void:
	_show_worksite_step(26, "_show_worksite_rear_camera_mp_controls")


func _show_memory_clock_step() -> void:
	_show_worksite_step(27, "_show_memory_clock_controls")


func _show_refresh_rate_step() -> void:
	_show_worksite_step(28, "_show_refresh_rate_controls")


func _show_cooling_system_step() -> void:
	_show_worksite_step(29, "_show_cooling_system_controls")


func _show_box_package_step() -> void:
	_show_worksite_step(30, "_show_worksite_box_package_controls")


func _show_phone_case_step() -> void:
	_show_worksite_step(31, "_show_worksite_phone_case_controls")


func _show_charger_step() -> void:
	_show_worksite_step(32, "_show_worksite_charger_controls")


func _show_smartwatch_step() -> void:
	_show_worksite_step(35, "_show_worksite_smartwatch_controls")


func _show_wireless_earbuds_step() -> void:
	_show_worksite_step(34, "_show_worksite_earbuds_controls")


func _show_protection_glass_step() -> void:
	_show_worksite_step(33, "_show_worksite_protection_glass_controls")


func _keep_step_navigation_active() -> void:
	# These are persistent wizard controls, not step-validation indicators.
	# Their handlers safely do nothing at the first/last boundary when needed.
	if is_instance_valid(navigation_layer):
		navigation_layer.layer = 127
	if is_instance_valid(navigation_bar):
		navigation_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		navigation_bar.z_index = 1000
		navigation_bar.z_as_relative = false
	if is_instance_valid(wizard_back_button):
		wizard_back_button.disabled = false
		wizard_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
		wizard_back_button.modulate.a = 1.0
	if is_instance_valid(next_button):
		next_button.disabled = false
		next_button.mouse_filter = Control.MOUSE_FILTER_STOP
		next_button.modulate.a = 1.0


func _on_nested_color_view_opened() -> void:
	_keep_step_navigation_active()
	call_deferred("_keep_step_navigation_active")


func _on_wizard_back_pressed() -> void:
	_keep_step_navigation_active()
	if wizard_step <= 0:
		return
	if wizard_step == 1:
		_prepare_step_panels_for_navigation()
		wizard_step = 0
		type_step_content.show()
		phone_editor.set("active_feature_panel", null)
		_update_step_progress(0)
		selection_scroll.scroll_vertical = 0
		return
	var previous_step := wizard_step - 1
	var previous_builder := ""
	if previous_step == 25:
		previous_builder = "_show_worksite_front_camera_mp_controls"
	elif previous_step == 26:
		previous_builder = "_show_worksite_rear_camera_mp_controls"
	_show_worksite_step(previous_step, previous_builder)


func _style_arrow_button(button: Button) -> void:
	# Clean, bold text navigation. Keep the controls floating directly on the
	# shared black background with no card, fill or border behind the labels.
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("h_separation", 0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("#f1f5f1"))
	button.add_theme_color_override("font_hover_color", Color("#9bd6a7"))
	button.add_theme_color_override("font_pressed_color", Color("#6fbd80"))
	button.add_theme_color_override("font_disabled_color", Color("#657268"))
	button.add_theme_color_override("font_outline_color", Color("#000000"))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_font_size_override("font_size", 18)
	_apply_bold_font(button)


func _style_button(button: Button, selected: bool) -> void:
	# KingsHall-inspired glass: translucent dark body, polished rim, inset
	# reflection and a soft shadow. Selection uses the brand green tint.
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
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		style.shadow_size = 9 if selected else 7
		style.shadow_offset = Vector2(0, 3)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#ffffff") if selected else Color("#e5eee7"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#7c897f"))
	button.add_theme_font_size_override("font_size", 18)
	_apply_bold_font(button)
	_add_glass_reflection(button, selected)


func _add_glass_reflection(button: Button, selected: bool) -> void:
	var reflection := button.get_node_or_null("GlassReflection") as GlassButtonReflection
	if not is_instance_valid(reflection):
		reflection = GlassButtonReflection.new()
		reflection.name = "GlassReflection"
		button.add_child(reflection)
	reflection.accent = Color("#9bd6a7") if selected else Color("#c5d0c8")
	reflection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reflection.queue_redraw()


func _apply_bold_font(control: Control) -> void:
	var font := SystemFont.new()
	font.font_weight = 700
	control.add_theme_font_override("font", font)


func _label(value: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_bold_font(label)
	return label
