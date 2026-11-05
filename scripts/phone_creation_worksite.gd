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
var specification_readout: HBoxContainer
var specification_readout_columns: Array[VBoxContainer] = []
var specification_readout_existing_count := 0
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
	progress_number = _label("STEP 1 / 30", 11, Color("#dce9df"), HORIZONTAL_ALIGNMENT_CENTER)
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)
	progress_bar = ProgressBar.new()
	progress_bar.name = "WizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = 30
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
	# steps. The readout changes from one centred column to two balanced columns
	# once the longer charging steps begin.
	specification_readout = HBoxContainer.new()
	specification_readout.name = "ProgressiveSpecificationReadout"
	specification_readout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	specification_readout.offset_left = 12.0
	specification_readout.offset_right = -12.0
	specification_readout.offset_top = 18.0
	specification_readout.offset_bottom = -18.0
	specification_readout.alignment = BoxContainer.ALIGNMENT_CENTER
	specification_readout.add_theme_constant_override("separation", 22)
	specification_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specification_readout.visible = false
	preview_region.add_child(specification_readout)

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

	if step < 15 or step > 29:
		_set_ram_selection_preview(false)
	_prepare_step_panels_for_navigation()
	wizard_step = step
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
		phone_editor.call(builder_method)
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
			str(phone_editor.call("_get_enabled_sensor_summary")) if sensors_step_visited else "Not set",
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
	if is_instance_valid(specification_readout):
		specification_readout.visible = enabled


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
	sensors: String = "Not set",
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
		sensors = "Not set"
	elif sensors == "Not set" and is_instance_valid(phone_editor) and phone_editor.has_method("_get_enabled_sensor_summary"):
		sensors = str(phone_editor.call("_get_enabled_sensor_summary"))
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

	for child in specification_readout.get_children():
		specification_readout.remove_child(child)
		child.queue_free()
	specification_readout_columns.clear()
	specification_readout_existing_count = 0

	var column_count := 2
	for column_index in range(column_count):
		var column := VBoxContainer.new()
		column.name = "SpecificationColumn%d" % (column_index + 1)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 18)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		specification_readout.add_child(column)
		specification_readout_columns.append(column)

	# Keep every completed selection visible while navigating between the
	# RAM technology, RAM capacity and internal storage steps. Visibility is
	# driven by whether a value has been selected, not the current step number.
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
	if sensors != "Not set":
		_add_specification_readout_entry("SENSORS", sensors)
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


func _add_specification_readout_entry(caption_text: String, value_text: String) -> void:
	if specification_readout_columns.is_empty():
		return

	# Fill the two columns in strict left-right order. Each column's
	# vertical centre alignment makes the growing list expand from the middle.
	var column_index := specification_readout_existing_count % 2
	specification_readout_existing_count += 1

	var entry := VBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.alignment = BoxContainer.ALIGNMENT_CENTER
	entry.add_theme_constant_override("separation", 3)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specification_readout_columns[column_index].add_child(entry)

	var caption := _label(caption_text, 13, Color("#c3cec6"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.add_child(caption)
	var value := _label(value_text, 26, Color("#f1f5f1"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.add_child(value)


func _update_step_progress(step: int) -> void:
	var progress_value := clampi(step + 1, 1, 30)
	progress_number.text = "STEP %d / 30" % progress_value
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
	_show_worksite_step(24, "_show_sensor_controls")


func _show_front_camera_mp_step() -> void:
	_show_worksite_step(25, "_show_front_camera_mp_controls")


func _show_rear_camera_mp_step() -> void:
	_show_worksite_step(26, "_show_rear_camera_mp_controls")


func _show_memory_clock_step() -> void:
	_show_worksite_step(27, "_show_memory_clock_controls")


func _show_refresh_rate_step() -> void:
	_show_worksite_step(28, "_show_refresh_rate_controls")


func _show_cooling_system_step() -> void:
	_show_worksite_step(29, "_show_cooling_system_controls")


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
	_show_worksite_step(wizard_step - 1)


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
