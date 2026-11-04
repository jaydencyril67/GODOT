extends Node3D

signal back_requested

const PHONE_TYPES := ["Standard", "Flip", "Fold"]
const PhoneEditorScene = preload("res://scenes/product_phone_editor.tscn")

var selected_phone_type := ""
var type_buttons: Dictionary = {}
var next_button: Button
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
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(48, 44)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button, false)
	back_button.pressed.connect(func(): back_requested.emit())
	top_bar.add_child(back_button)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var progress := PanelContainer.new()
	progress.name = "ProgressStepOne"
	progress.custom_minimum_size = Vector2(46, 38)
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color("#2f7543")
	progress_style.border_color = Color("#4b9b5e")
	progress_style.set_border_width_all(1)
	progress_style.set_corner_radius_all(10)
	progress.add_theme_stylebox_override("panel", progress_style)
	top_bar.add_child(progress)

	var progress_number := _label("1", 15, Color("#f7fff7"), HORIZONTAL_ALIGNMENT_CENTER)
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

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
		# light background. Keep the original sky available for PBR lighting.
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
	selection_region.size_flags_stretch_ratio = 1.0
	selection_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_region.add_theme_constant_override("margin_left", 22)
	selection_region.add_theme_constant_override("margin_right", 18)
	selection_region.add_theme_constant_override("margin_top", 20)
	selection_region.add_theme_constant_override("margin_bottom", 20)
	selection_scroll.add_child(selection_region)

	selection_stack = VBoxContainer.new()
	selection_stack.add_theme_constant_override("separation", 16)
	selection_region.add_child(selection_stack)

	var section_title := _label("PHONE TYPE", 22, Color("#f1f5f1"))
	selection_stack.add_child(section_title)

	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 9)
	selection_stack.add_child(options)
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
	bottom_bar.custom_minimum_size.y = 52.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(bottom_bar)

	next_button = Button.new()
	next_button.name = "NextStepIconButton"
	next_button.text = "→"
	next_button.custom_minimum_size = Vector2(54, 50)
	next_button.disabled = true
	next_button.focus_mode = Control.FOCUS_NONE
	_style_button(next_button, true)
	next_button.pressed.connect(_on_next_pressed)
	bottom_bar.add_child(next_button)
	_apply_responsive_layout()


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
	# The following wizard stage is intentionally not created until its
	# controls and data flow are implemented as a separate approved step.


func _style_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#2f7543") if primary else Color("#e1ebe1")
		if state == "hover":
			style.bg_color = Color("#3c8951") if primary else Color("#cbdccb")
		elif state == "pressed":
			style.bg_color = Color("#245f35")
		elif state == "disabled":
			style.bg_color = Color("#d4dfd4")
		style.border_color = Color("#438c54") if primary else Color("#78a780")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f7fff7") if primary else Color("#24432b"))
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else Color("#18351f"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#8a978c"))
	button.add_theme_font_size_override("font_size", 16)


func _label(value: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
