extends CanvasLayer

var _pending_action: Callable
var _shade: ColorRect
var _content: VBoxContainer
var _title: Label
var _message: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	layer = 100
	_build_modal()
	hide()


func show_confirmation(title_text: String, message_text: String, action_text: String, action: Callable) -> void:
	_pending_action = action
	_title.text = title_text.to_upper()
	_message.text = message_text
	_confirm_button.text = action_text.to_upper()
	_cancel_button.show()
	_open_overlay()


func show_notice(title_text: String, message_text: String) -> void:
	_pending_action = Callable()
	_title.text = title_text.to_upper()
	_message.text = message_text
	_confirm_button.text = "GOT IT"
	_cancel_button.hide()
	_open_overlay()


func _open_overlay() -> void:
	show()
	_shade.modulate.a = 0.0
	_content.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_shade, "modulate:a", 1.0, 0.2)
	tween.tween_property(_content, "modulate:a", 1.0, 0.24)


func _build_modal() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.002, 0.018, 0.009, 0.84)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 26)
	center.add_theme_constant_override("margin_right", 26)
	center.add_theme_constant_override("margin_top", 24)
	center.add_theme_constant_override("margin_bottom", 24)
	root.add_child(center)

	_content = VBoxContainer.new()
	_content.name = "DimPage_AlertContent"
	_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.custom_minimum_size.x = minf(720.0, maxf(220.0, get_viewport().get_visible_rect().size.x - 52.0))
	_content.add_theme_constant_override("separation", 22)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_content)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(92, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color("#a9d9ad")
	_content.add_child(accent)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_color", Color("#f4fff3"))
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.12, 0.035, 0.9))
	_title.add_theme_constant_override("outline_size", 2)
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_content.add_child(_title)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color("#dcebdd"))
	_message.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.025, 0.8))
	_message.add_theme_constant_override("outline_size", 1)
	_message.custom_minimum_size.y = 54
	_content.add_child(_message)

	var compact := get_viewport().get_visible_rect().size.x < 600.0
	var actions: BoxContainer
	if compact:
		actions = VBoxContainer.new()
	else:
		actions = HBoxContainer.new()
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


func _refresh_responsive_type() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var compact := width < 760.0
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	font.variation_embolden = 0.85
	for label in [_title, _message]:
		label.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 28 if compact else 38)
	_message.add_theme_font_size_override("font_size", 21 if compact else 25)
	for button in [_cancel_button, _confirm_button]:
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 19 if compact else 21)
		button.custom_minimum_size.y = 56 if compact else 64
		button.custom_minimum_size.x = 0 if compact else 170


func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("#f5fff4"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("#12351c"))
	button.add_theme_constant_override("outline_size", 1)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.56, 0.30, 0.56) if primary else Color(0.72, 0.88, 0.73, 0.20)
		if state == "hover":
			style.bg_color = Color(0.34, 0.72, 0.42, 0.72) if primary else Color(0.82, 0.96, 0.84, 0.34)
		elif state == "pressed":
			style.bg_color = Color(0.08, 0.31, 0.15, 0.78)
		style.border_color = Color(0.86, 1.0, 0.87, 0.92)
		style.set_border_width_all(1)
		style.border_width_top = 3
		style.set_corner_radius_all(16)
		style.shadow_color = Color(0.0, 0.12, 0.025, 0.62)
		style.shadow_size = 16
		style.shadow_offset = Vector2(0, 5)
		style.anti_aliasing = true
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		button.add_theme_stylebox_override(state, style)


func _confirm() -> void:
	var action := _pending_action
	_pending_action = Callable()
	hide()
	if action.is_valid():
		action.call()


func _cancel() -> void:
	_pending_action = Callable()
	hide()
