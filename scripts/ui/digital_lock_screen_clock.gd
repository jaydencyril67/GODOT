extends Control

const FaceAssetLibrary = preload("res://scripts/ui/xmorph_clock_face_asset_library.gd")

var _library := FaceAssetLibrary.new()
var _style_index := 1
var _face: Dictionary = {}
var _palette: Dictionary = {}
var _show_date := true
var _last_minute := -1
var _device_mode := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_render_face)
	set_process(true)
	_load_selected_face()


func configure(index: int, palette: Dictionary = {}, design: Dictionary = {}) -> void:
	_style_index = clampi(index, 1, maxi(1, _library.get_face_count()))
	_palette = palette.duplicate(true)
	_show_date = bool(design.get("show_details", true))
	_device_mode = bool(design.get("device_clock", _device_mode))
	_load_selected_face()


func get_style_index() -> int:
	return _style_index


func get_style_count() -> int:
	return _library.get_face_count()


func get_style_name() -> String:
	return str(_face.get("name", "Digital Clock"))


func get_style_source() -> String:
	return str(_face.get("category", "digital")).to_upper()


func get_style_layout() -> String:
	var large: Dictionary = _face.get("large", {})
	for key in ["row", "column", "stack"]:
		if large.has(key):
			return key
	return "custom"


func _process(_delta: float) -> void:
	var now := Time.get_time_dict_from_system()
	if int(now.get("minute", -1)) != _last_minute:
		_render_face()


func _load_selected_face() -> void:
	_face = _library.get_face(_style_index)
	_last_minute = -1
	_render_face()


func _render_face() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if size.x <= 0.0 or size.y <= 0.0:
		return

	if _device_mode:
		_render_device_face()
		return

	if _face.is_empty():
		return

	var large: Dictionary = _face.get("large", {})
	var layout_key := ""
	for key in ["row", "column", "stack"]:
		if large.has(key):
			layout_key = key
			break
	if layout_key.is_empty():
		return

	var layout_data: Dictionary = large[layout_key]
	var root_width := clampf(float(layout_data.get("width", large.get("width", 0.90))), 0.30, 1.0)
	var root_height := clampf(float(layout_data.get("height", large.get("height", 0.48))), 0.16, 0.90)
	var root_x := float(large.get("x", 0.5))
	var root_y := float(large.get("y", 0.32))
	var horizontal_anchor := str(large.get("anchor", "CENTER"))
	var left := root_x
	if horizontal_anchor == "CENTER":
		left -= root_width * 0.5
	elif horizontal_anchor == "END":
		left -= root_width
	left = clampf(left, 0.0, 1.0 - root_width)
	var top := clampf(root_y - root_height * 0.5, 0.06, 1.0 - root_height)

	var frame := Control.new()
	frame.name = "XMorphClockFace"
	_set_normalized_rect(frame, Rect2(left, top, root_width, root_height))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var root_node := _build_layout_node(large, Vector2(size.x * root_width, size.y * root_height))
	if root_node == null:
		return
	root_node.name = "XMorphClockLayout"
	root_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(root_node)
	_last_minute = int(Time.get_time_dict_from_system().get("minute", -1))


func _build_layout_node(spec: Dictionary, available_size: Vector2) -> Control:
	if spec.has("layer"):
		return _make_layer_label(spec, available_size)

	var layout_key := ""
	for key in ["row", "column", "stack"]:
		if spec.has(key):
			layout_key = key
			break
	if layout_key.is_empty():
		return null

	var data: Dictionary = spec[layout_key]
	if layout_key == "stack":
		var stack := Control.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stack_width := float(data.get("width", 1.0))
		var stack_height := float(data.get("height", 1.0))
		stack.custom_minimum_size = Vector2(available_size.x * stack_width, available_size.y * stack_height)
		for child_value in data.get("children", []):
			var child_spec: Dictionary = child_value
			var child := _build_layout_node(child_spec, available_size)
			if child == null:
				continue
			stack.add_child(child)
			_place_stack_child(child, child_spec, available_size)
		return stack

	var container: BoxContainer
	if layout_key == "row":
		container = HBoxContainer.new()
	else:
		container = VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.alignment = _box_alignment(str(data.get("align", "CENTER")))
	var gap := float(data.get("gap", 0.0))
	container.add_theme_constant_override("separation", roundi(minf(available_size.x, available_size.y) * gap))
	for child_value in data.get("children", []):
		var child_spec: Dictionary = child_value
		var child_available := available_size
		var child := _build_layout_node(child_spec, child_available)
		if child == null:
			continue
		if child is Label:
			if layout_key == "column":
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else:
				child.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.add_child(child)
	return container


func _render_device_face() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if size.x <= 0.0 or size.y <= 0.0:
		return

	var frame := Control.new()
	frame.name = "DeviceClockFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var time_label := Label.new()
	time_label.name = "DeviceClockTime"
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_label.clip_text = false
	time_label.anchor_left = 0.0
	time_label.anchor_right = 1.0
	time_label.anchor_top = 0.30
	time_label.anchor_bottom = 0.48
	frame.add_child(time_label)

	var date_label := Label.new()
	date_label.name = "DeviceClockDate"
	date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	date_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	date_label.clip_text = false
	date_label.anchor_left = 0.0
	date_label.anchor_right = 1.0
	date_label.anchor_top = 0.50
	date_label.anchor_bottom = 0.60
	if not _show_date:
		date_label.visible = false
	frame.add_child(date_label)

	var short_side := minf(size.x, size.y)
	var time_font_size := clampi(roundi(short_side * 0.14), 36, 140)
	var date_font_size := clampi(roundi(short_side * 0.04), 12, 24)

	time_label.add_theme_font_size_override("font_size", time_font_size)
	date_label.add_theme_font_size_override("font_size", date_font_size)
	time_label.add_theme_color_override("font_color", _palette.get("text", Color.WHITE))
	date_label.add_theme_color_override("font_color", _palette.get("muted", Color("#D1D5DB")))

	var font: Font = _library.get_font("roboto_flex")
	if font != null:
		time_label.add_theme_font_override("font", font)
		date_label.add_theme_font_override("font", font)

	time_label.add_theme_constant_override("letter_spacing", 0)
	date_label.add_theme_constant_override("letter_spacing", 2)
	date_label.modulate.a = 0.85

	_update_device_labels(time_label, date_label)
	_last_minute = int(Time.get_time_dict_from_system().get("minute", -1))


func _update_device_labels(time_label: Label, date_label: Label) -> void:
	var now := Time.get_time_dict_from_system()
	var hour := int(now.get("hour", 0))
	var minute := int(now.get("minute", 0))
	time_label.text = "%02d:%02d" % [hour, minute]

	if _show_date and date_label != null:
		date_label.text = _format_date("EEEE, d MMMM", false)


func _place_stack_child(child: Control, child_spec: Dictionary, available_size: Vector2) -> void:
	var nested_stack: Dictionary = child_spec.get("stack", {})
	var width_fraction := float(nested_stack.get("width", child_spec.get("width", 0.78)))
	var height_fraction := float(nested_stack.get("height", child_spec.get("height", 0.24)))
	if child is Label:
		var label := child as Label
		width_fraction = maxf(width_fraction, label.custom_minimum_size.x / maxf(available_size.x, 1.0))
		height_fraction = maxf(height_fraction, label.custom_minimum_size.y / maxf(available_size.y, 1.0))
	width_fraction = clampf(width_fraction, 0.06, 1.0)
	height_fraction = clampf(height_fraction, 0.04, 1.0)
	var x := float(child_spec.get("x", 0.5))
	var y := float(child_spec.get("y", 0.5))
	var anchor := str(child_spec.get("anchor", "CENTER"))
	var left := x
	if anchor == "CENTER":
		left -= width_fraction * 0.5
	elif anchor == "END":
		left -= width_fraction
	left = clampf(left, 0.0, 1.0 - width_fraction)
	var top := clampf(y - height_fraction * 0.5, 0.0, 1.0 - height_fraction)
	_set_normalized_rect(child, Rect2(left, top, width_fraction, height_fraction))
	child.rotation_degrees = float(child_spec.get("rotation", 0.0))


func _make_layer_label(node_spec: Dictionary, available_size: Vector2) -> Label:
	var layer_id := str(node_spec.get("layer", ""))
	var layer := _get_layer(layer_id)
	var label := Label.new()
	match layer_id:
		"hours":
			label.name = "DigitalClockHours"
		"minutes":
			label.name = "DigitalClockMinutes"
		"date":
			label.name = "DigitalClockDate"
		"time":
			label.name = "DigitalClockTime"
		_:
			label.name = "ClockLayer_" + layer_id
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.text = _layer_text(layer)
	if not _show_date and str(layer.get("type", "")) == "DATE":
		label.visible = false

	var text_value := label.text
	var requested_size := float(node_spec.get("size", 0.09))
	var short_side := minf(available_size.x, available_size.y)
	var max_font_size := mini(180, maxi(12, roundi(available_size.y * 0.28)))
	var font_size := clampi(roundi(short_side * requested_size * 0.42), 11, max_font_size)
	var font_reference := str(layer.get("font", "roboto_flex")).strip_edges()
	if font_reference.is_empty():
		font_reference = "roboto_flex"
	var font: Font = _library.get_font(font_reference)
	if font == null:
		font = _library.get_font("roboto_flex")
	if font == null:
		push_error("XMorph digital clock font is missing: " + font_reference)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _layer_color(str(layer.get("color", ""))))
	var tracking := float(node_spec.get("tracking", layer.get("tracking", 0.0)))
	label.add_theme_constant_override("letter_spacing", roundi(tracking * 5.0))
	var stroke := str(layer.get("stroke", ""))
	if bool(layer.get("outline", false)) or not stroke.is_empty():
		label.add_theme_constant_override("outline_size", clampi(roundi(font_size * float(layer.get("strokeWidth", 0.06))), 1, 5))
		label.add_theme_color_override("font_outline_color", _layer_color(stroke))
	label.modulate.a = float(layer.get("opacity", 1.0))
	label.rotation_degrees = float(node_spec.get("rotation", 0.0))

	var text_width := font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var min_width := clampf(text_width + font_size * 0.28, font_size * 1.1, available_size.x)
	var min_height := maxf(font_size * 1.22, available_size.y * 0.025)
	label.custom_minimum_size = Vector2(min_width, min_height)
	return label


func _get_layer(layer_id: String) -> Dictionary:
	for layer_value in _face.get("layers", []):
		var layer: Dictionary = layer_value
		if str(layer.get("id", "")) == layer_id:
			return layer
	return {}


func _layer_text(layer: Dictionary) -> String:
	var kind := str(layer.get("type", "TEXT"))
	var time := Time.get_time_dict_from_system()
	var hour := int(time.get("hour", 0))
	var minute := int(time.get("minute", 0))
	var hour_text := "%02d" % hour if bool(layer.get("hourZero", true)) else str(hour)
	var minute_text := "%02d" % minute
	match kind:
		"HOURS":
			return hour_text
		"MINUTES":
			return minute_text
		"COLON":
			return ":"
		"TIME":
			return hour_text + ":" + minute_text
		"HOUR_TENS":
			return hour_text.substr(0, 1)
		"HOUR_ONES":
			return hour_text.substr(hour_text.length() - 1, 1)
		"MINUTE_TENS":
			return minute_text.substr(0, 1)
		"MINUTE_ONES":
			return minute_text.substr(1, 1)
		"DATE":
			return _format_date(str(layer.get("format", "EEEE, d MMMM")), bool(layer.get("caps", false)))
		_:
			var text_value := str(layer.get("format", ""))
			text_value = text_value.replace("{time}", "%02d:%02d" % [hour, minute])
			text_value = text_value.replace("{date}", _format_date("EEEE, d MMMM", false))
			return text_value.to_upper() if bool(layer.get("caps", false)) else text_value


func _format_date(format_value: String, caps: bool) -> String:
	var date := Time.get_date_dict_from_system()
	var weekday := clampi(int(date.get("weekday", 1)), 1, 7)
	var month := clampi(int(date.get("month", 1)), 1, 12)
	var weekdays := ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	var weekdays_short := ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var months := ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var months_short := ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var value := format_value
	value = value.replace("EEEE", weekdays[weekday])
	value = value.replace("EEE", weekdays_short[weekday])
	value = value.replace("MMMM", months[month])
	value = value.replace("MMM", months_short[month])
	value = value.replace("yyyy", str(date.get("year", 2026)))
	value = value.replace("dd", "%02d" % int(date.get("day", 1)))
	value = value.replace("d", str(date.get("day", 1)))
	return value.to_upper() if caps else value


func _layer_color(value: String) -> Color:
	var normalized := value.to_lower()
	if normalized.begins_with("#"):
		return _library_color(normalized)
	if normalized.begins_with("accent"):
		var accent: Color = _palette.get("accent", Color.WHITE)
		if "_700" in normalized:
			return accent.darkened(0.48)
		if "_200" in normalized:
			return accent.lightened(0.10)
		return accent
	if normalized.begins_with("neutral"):
		if "_300" in normalized or "_200" in normalized:
			return _palette.get("muted", Color("#D1D5DB"))
		return _palette.get("text", Color.WHITE)
	return _palette.get("text", Color.WHITE)


func _library_color(raw: String) -> Color:
	var hex := raw.trim_prefix("#")
	if hex.length() == 8:
		return Color(
			float(hex.substr(2, 2).hex_to_int()) / 255.0,
			float(hex.substr(4, 2).hex_to_int()) / 255.0,
			float(hex.substr(6, 2).hex_to_int()) / 255.0,
			float(hex.substr(0, 2).hex_to_int()) / 255.0
		)
	if hex.length() == 6:
		return Color(
			float(hex.substr(0, 2).hex_to_int()) / 255.0,
			float(hex.substr(2, 2).hex_to_int()) / 255.0,
			float(hex.substr(4, 2).hex_to_int()) / 255.0,
			1.0
		)
	return Color.WHITE


func _box_alignment(value: String):
	match value:
		"START":
			return BoxContainer.ALIGNMENT_BEGIN
		"END":
			return BoxContainer.ALIGNMENT_END
		_:
			return BoxContainer.ALIGNMENT_CENTER


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
