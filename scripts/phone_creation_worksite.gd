extends Node3D

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
var phone_editor: Node
var worksite_body: BoxContainer
var preview_region: Control
var selection_scroll: ScrollContainer
var selection_region: MarginContainer
var selection_stack: VBoxContainer


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
	add_child(phone_editor)

	var editor_interface := phone_editor.get_node_or_null("PhoneEditorInterface") as CanvasLayer
	if is_instance_valid(editor_interface):
		editor_interface.hide()


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
	backdrop.color = Color("#080b09")
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
	progress_number = _label("STEP 1 / 4", 11, Color("#dce9df"), HORIZONTAL_ALIGNMENT_CENTER)
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)
	progress_bar = ProgressBar.new()
	progress_bar.name = "WizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = 4
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

	var body := HBoxContainer.new()
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

	selection_scroll = ScrollContainer.new()
	selection_scroll.name = "PhoneTypeSelectionScroll"
	selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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

	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "WorksiteBottomBar"
	bottom_bar.custom_minimum_size.y = 62.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 18)
	layout.add_child(bottom_bar)
	wizard_back_button = GlassArrowButton.new()
	wizard_back_button.name = "WizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.disabled = true
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	bottom_bar.add_child(wizard_back_button)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer)
	next_button = GlassArrowButton.new()
	next_button.name = "NextStepIconButton"
	next_button.points_right = true
	next_button.disabled = true
	next_button.pressed.connect(_on_next_pressed)
	bottom_bar.add_child(next_button)
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
		preview_region.custom_minimum_size = Vector2(0, maxf(150.0, viewport_size.y * 0.34))
		selection_scroll.custom_minimum_size = Vector2(0, maxf(190.0, viewport_size.y * 0.42))
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
	next_button.disabled = false
	_update_preview_for_phone_type(phone_type)


func _update_preview_for_phone_type(phone_type: String) -> void:
	if not is_instance_valid(phone_editor):
		return
	# Delegate to the original editor's own type-selection callback. This runs
	# its complete mesh rebuild path for Standard, Flip and Fold.
	phone_editor.call("_on_phone_type_selected", phone_type)


func _on_next_pressed() -> void:
	if selected_phone_type.is_empty():
		return
	if wizard_step == 0:
		_show_thickness_step()
	elif wizard_step == 1:
		_show_border_radius_step()
	elif wizard_step == 2:
		_show_screen_tech_step()


func _discard_panel(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var parent := panel.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(panel)
	panel.queue_free()


func _mount_original_panel(method_name: String) -> Control:
	phone_editor.call(method_name)
	var panel := phone_editor.get("active_feature_panel") as Control
	if not is_instance_valid(panel):
		return null
	var parent := panel.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	selection_stack.add_child(panel)
	return panel


func _show_thickness_step() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	wizard_step = 1
	type_step_content.hide()
	thickness_panel = _mount_original_panel("_show_thickness_controls")
	progress_number.text = "STEP 2 / 4"
	progress_bar.value = 2
	wizard_back_button.disabled = false
	next_button.disabled = false
	selection_scroll.scroll_vertical = 0


func _show_border_radius_step() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	_discard_panel(thickness_panel)
	thickness_panel = null
	wizard_step = 2
	border_radius_panel = _mount_original_panel("_show_border_radius_controls")
	progress_number.text = "STEP 3 / 4"
	progress_bar.value = 3
	wizard_back_button.disabled = false
	next_button.disabled = false
	selection_scroll.scroll_vertical = 0


func _show_screen_tech_step() -> void:
	if not is_instance_valid(phone_editor) or not is_instance_valid(selection_stack):
		return
	_discard_panel(border_radius_panel)
	border_radius_panel = null
	wizard_step = 3
	screen_tech_panel = _mount_original_panel("_show_screen_tech_controls")
	progress_number.text = "STEP 4 / 4"
	progress_bar.value = 4
	wizard_back_button.disabled = false
	# No following wizard stage has been designed or approved yet.
	next_button.disabled = true
	selection_scroll.scroll_vertical = 0


func _on_wizard_back_pressed() -> void:
	if wizard_step == 3:
		_discard_panel(screen_tech_panel)
		screen_tech_panel = null
		wizard_step = 2
		border_radius_panel = _mount_original_panel("_show_border_radius_controls")
		progress_number.text = "STEP 3 / 4"
		progress_bar.value = 3
		wizard_back_button.disabled = false
		next_button.disabled = false
	elif wizard_step == 2:
		_discard_panel(border_radius_panel)
		border_radius_panel = null
		wizard_step = 1
		thickness_panel = _mount_original_panel("_show_thickness_controls")
		progress_number.text = "STEP 2 / 4"
		progress_bar.value = 2
		wizard_back_button.disabled = false
		next_button.disabled = false
	elif wizard_step == 1:
		_discard_panel(thickness_panel)
		thickness_panel = null
		wizard_step = 0
		type_step_content.show()
		progress_number.text = "STEP 1 / 4"
		progress_bar.value = 1
		wizard_back_button.disabled = true
		next_button.disabled = selected_phone_type.is_empty()
	selection_scroll.scroll_vertical = 0


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
