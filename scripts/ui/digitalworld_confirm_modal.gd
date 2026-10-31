extends CanvasLayer

var _pending_action: Callable
var _shade: ColorRect
var _panel: PanelContainer
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
	show()
	_shade.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_shade, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_modal() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.005, 0.025, 0.05, 0.82)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 22)
	center.add_theme_constant_override("margin_right", 22)
	center.add_theme_constant_override("margin_top", 22)
	center.add_theme_constant_override("margin_bottom", 22)
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(minf(390.0, maxf(280.0, get_viewport().get_visible_rect().size.x - 44.0)), 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.scale = Vector2.ONE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.13, 0.22, 0.97)
	panel_style.border_color = Color(0.36, 0.78, 1.0, 0.92)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(24)
	panel_style.shadow_color = Color(0.0, 0.55, 0.95, 0.24)
	panel_style.shadow_size = 24
	panel_style.shadow_offset = Vector2(0, 8)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	_panel.add_child(stack)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 3)
	accent.color = Color(0.35, 0.82, 1.0, 0.95)
	stack.add_child(accent)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", Color("#f2faff"))
	_title.add_theme_constant_override("outline_size", 1)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.55, 0.85, 0.4))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_title)

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 15)
	_message.add_theme_color_override("font_color", Color("#c5deed"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(0, 54)
	stack.add_child(_message)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator_color", Color(0.48, 0.76, 0.94, 0.32))
	stack.add_child(separator)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)

	_cancel_button = Button.new()
	_cancel_button.text = "CANCEL"
	_cancel_button.custom_minimum_size = Vector2(112, 44)
	_cancel_button.add_theme_font_size_override("font_size", 14)
	_style_button(_cancel_button, Color(0.12, 0.25, 0.35, 0.94), Color(0.42, 0.68, 0.82, 0.8))
	_cancel_button.pressed.connect(_cancel)
	actions.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRM"
	_confirm_button.custom_minimum_size = Vector2(132, 44)
	_confirm_button.add_theme_font_size_override("font_size", 14)
	_style_button(_confirm_button, Color(0.08, 0.43, 0.66, 0.98), Color(0.48, 0.86, 1.0, 0.95))
	_confirm_button.pressed.connect(_confirm)
	actions.add_child(_confirm_button)


func _style_button(button: Button, fill: Color, edge: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.12) if state == "hover" else fill
		style.border_color = edge
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f5fbff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _confirm() -> void:
	var action := _pending_action
	_pending_action = Callable()
	hide()
	if action.is_valid():
		action.call()


func _cancel() -> void:
	_pending_action = Callable()
	hide()
