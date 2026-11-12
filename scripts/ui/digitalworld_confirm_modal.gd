extends CanvasLayer

var _pending_action: Callable
var _root: Control
var _shade: ColorRect
var _content: VBoxContainer
var _title: Label
var _message: Label
var _confirm_button: Button
var _cancel_button: Button
var _actions: BoxContainer
var _custom_content: Control
var _picker_overlay: Control


func _ready() -> void:
	layer = 100
	_build_modal()
	hide()


func show_confirmation(title_text: String, message_text: String, action_text: String, action: Callable) -> void:
	_clear_custom_content()
	_pending_action = action
	_title.text = title_text.to_upper()
	_message.text = message_text
	_confirm_button.text = action_text.to_upper()
	_cancel_button.text = "CANCEL"
	_cancel_button.show()
	_open_overlay()


func show_action_prompt(title_text: String, message_text: String, action_text: String, action: Callable) -> void:
	_clear_custom_content()
	_pending_action = action
	_title.text = title_text.to_upper()
	_message.text = message_text
	_confirm_button.text = action_text.to_upper()
	_cancel_button.text = "CLOSE"
	if not (_actions is HBoxContainer):
		var previous_actions := _actions
		var horizontal_actions := HBoxContainer.new()
		horizontal_actions.alignment = BoxContainer.ALIGNMENT_CENTER
		horizontal_actions.add_theme_constant_override("separation", 12)
		var parent := previous_actions.get_parent()
		var previous_index := previous_actions.get_index()
		parent.remove_child(previous_actions)
		parent.add_child(horizontal_actions)
		parent.move_child(horizontal_actions, previous_index)
		previous_actions.remove_child(_cancel_button)
		horizontal_actions.add_child(_cancel_button)
		previous_actions.remove_child(_confirm_button)
		horizontal_actions.add_child(_confirm_button)
		previous_actions.queue_free()
		_actions = horizontal_actions
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.custom_minimum_size.x = 0
	_confirm_button.custom_minimum_size.x = 0
	_cancel_button.show()
	_open_overlay()


func show_notice(title_text: String, message_text: String) -> void:
	_clear_custom_content()
	_pending_action = Callable()
	_title.text = title_text.to_upper()
	_message.text = message_text
	_confirm_button.text = "GOT IT"
	_cancel_button.hide()
	_open_overlay()


func show_custom_prompt(title_text: String, message_text: String, custom_content: Control, action_text: String, action: Callable) -> void:
	_clear_custom_content()
	_pending_action = action
	_title.text = title_text.to_upper()
	_message.text = message_text
	_confirm_button.text = action_text.to_upper()
	_cancel_button.text = "CLOSE"
	_cancel_button.show()
	_custom_content = custom_content
	if is_instance_valid(_custom_content):
		_content.add_child(_custom_content)
		_content.move_child(_custom_content, _actions.get_index())
	_open_overlay()


func show_custom_picker(options: Array, title_text: String, selected_value: String, on_selected: Callable) -> void:
	_close_custom_picker()
	if not is_instance_valid(_root):
		return

	# A second alert layer: keep the original alert visible underneath it.
	_picker_overlay = Control.new()
	_picker_overlay.name = "ResearchNestedAlert"
	_picker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker_overlay.z_index = 20
	_root.add_child(_picker_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.004, 0.004, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 22)
	center.add_theme_constant_override("margin_right", 22)
	center.add_theme_constant_override("margin_top", 14)
	center.add_theme_constant_override("margin_bottom", 14)
	_picker_overlay.add_child(center)

	# Match the existing dark alert presentation; no card or scroll container.
	var alert_content := VBoxContainer.new()
	alert_content.name = "NestedAlertContent"
	alert_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	alert_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alert_content.custom_minimum_size.x = minf(650.0, maxf(220.0, get_viewport().get_visible_rect().size.x - 44.0))
	alert_content.add_theme_constant_override("separation", 12)
	alert_content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(alert_content)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(76, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color("#D2A15C")
	alert_content.add_child(accent)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	alert_content.add_child(header)

	var heading := _make_label(title_text.to_upper(), 19, Color("#EEE9DF"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)

	var close_button := Button.new()
	close_button.text = "CLOSE  ×"
	close_button.custom_minimum_size = Vector2(94, 42)
	_style_button(close_button, false)
	close_button.pressed.connect(_close_custom_picker)
	header.add_child(close_button)

	var hint := _make_label("CHOOSE ONE OPTION", 11, Color("#AAA49A"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_content.add_child(hint)

	var options_grid := GridContainer.new()
	options_grid.name = "ResearchAlertOptions"
	options_grid.columns = 2
	options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_grid.add_theme_constant_override("h_separation", 10)
	options_grid.add_theme_constant_override("v_separation", 8)
	alert_content.add_child(options_grid)

	if options.is_empty():
		var empty := _make_label("No available options.", 15, Color("#AAA49A"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alert_content.add_child(empty)
	else:
		for option_value in options:
			var option_text := str(option_value)
			var option_button := Button.new()
			option_button.text = option_text.to_upper()
			option_button.custom_minimum_size = Vector2(0, 44)
			option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_button(option_button, option_text == selected_value)
			option_button.pressed.connect(_choose_custom_picker_option.bind(option_text, on_selected))
			options_grid.add_child(option_button)

	var footer_note := _make_label("SELECTING AN OPTION RETURNS TO THE PREVIOUS ALERT", 9, Color("#938D83"))
	footer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_content.add_child(footer_note)

func _choose_custom_picker_option(option_text: String, on_selected: Callable) -> void:
	_close_custom_picker()
	if on_selected.is_valid():
		on_selected.call(option_text)


func _close_custom_picker() -> void:
	if is_instance_valid(_picker_overlay):
		_picker_overlay.queue_free()
	_picker_overlay = null


func _clear_custom_content() -> void:
	_close_custom_picker()
	if is_instance_valid(_custom_content):
		# Remove findings content synchronously before another prompt can be
		# opened in the same frame after an approval or retry action.
		var content_parent := _custom_content.get_parent()
		if is_instance_valid(content_parent):
			content_parent.remove_child(_custom_content)
		_custom_content.free()
	_custom_content = null


func _open_overlay() -> void:
	show()
	_shade.modulate.a = 0.0
	_content.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_shade, "modulate:a", 1.0, 0.2)
	tween.tween_property(_content, "modulate:a", 1.0, 0.24)


func _build_modal() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.004, 0.004, 0.004, 0.88)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 26)
	center.add_theme_constant_override("margin_right", 26)
	center.add_theme_constant_override("margin_top", 24)
	center.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(center)

	_content = VBoxContainer.new()
	_content.name = "DimPage_AlertContent"
	_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.custom_minimum_size.x = minf(720.0, maxf(220.0, get_viewport().get_visible_rect().size.x - 52.0))
	_content.add_theme_constant_override("separation", 16)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_content)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(92, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color("#D2A15C")
	_content.add_child(accent)

	_title = _make_label("", 28, Color("#EEE9DF"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.10, 0.075, 0.04, 0.9))
	_title.add_theme_constant_override("outline_size", 2)
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_content.add_child(_title)

	_message = _make_label("", 19, Color("#D6D0C5"))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size.y = 28
	_content.add_child(_message)

	var compact := get_viewport().get_visible_rect().size.x < 600.0
	var actions: BoxContainer
	if compact:
		actions = VBoxContainer.new()
	else:
		actions = HBoxContainer.new()
	_actions = actions
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12 if compact else 14)
	_content.add_child(actions)

	_cancel_button = Button.new()
	_cancel_button.text = "CANCEL"
	_cancel_button.custom_minimum_size = Vector2(0, 56 if compact else 58)
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_cancel_button, false)
	_cancel_button.pressed.connect(_cancel)
	actions.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRM"
	_confirm_button.custom_minimum_size = Vector2(0, 56 if compact else 58)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_confirm_button, true)
	_confirm_button.pressed.connect(_confirm)
	actions.add_child(_confirm_button)

	_refresh_responsive_type()


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _refresh_responsive_type() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var compact := width < 760.0
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	font.variation_embolden = 0.85
	for label in [_title, _message]:
		label.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 25 if compact else 34)
	_message.add_theme_font_size_override("font_size", 17 if compact else 21)
	for button in [_cancel_button, _confirm_button]:
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 17 if compact else 19)
		button.custom_minimum_size.y = 52 if compact else 60


func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#211A11"))
	button.add_theme_constant_override("outline_size", 1)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#805821") if primary else Color("#292D2F")
		if state == "hover":
			style.bg_color = Color("#956A2E") if primary else Color("#373B3D")
		elif state == "pressed":
			style.bg_color = Color("#61431C") if primary else Color("#202325")
		elif state == "disabled":
			style.bg_color = Color("#34302A")
		style.border_color = Color("#A17A42") if primary else Color("#515456")
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.set_corner_radius_all(14)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		style.shadow_size = 11 if primary else 7
		style.shadow_offset = Vector2(0, 4)
		style.anti_aliasing = true
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)

func _confirm() -> void:
	var action := _pending_action
	_pending_action = Callable()
	_clear_custom_content()
	hide()
	if action.is_valid():
		action.call()


func _cancel() -> void:
	_pending_action = Callable()
	_clear_custom_content()
	hide()
