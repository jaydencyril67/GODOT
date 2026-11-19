extends Control

const FaceAssetLibrary = preload("res://scripts/ui/xmorph_clock_face_asset_library.gd")
const FACE_FRAME_RECT := Rect2(0.05, 0.30, 0.90, 0.40)
const TIME_FONT_FRACTION := 0.58
const DATE_FONT_FRACTION := 0.045
const DATE_TIME_GAP_RATIO := 0.012
const DATE_TIME_GAP_MIN := 5.0
const DATE_TIME_GAP_MAX := 12.0
const TIME_LAYER_TYPES := ["HOURS", "MINUTES", "COLON", "TIME", "HOUR_TENS", "HOUR_ONES", "MINUTE_TENS", "MINUTE_ONES"]

var _library := FaceAssetLibrary.new()
var _style_index := 1
var _face: Dictionary = {}
var _palette: Dictionary = {}
var _show_date := true
var _last_minute := -1
var _pending_normalization_frame: Control
var _pending_normalization_root: Control
var _pending_normalization_last_bounds := Rect2()
var _pending_normalization_stable_frames := 0
var _pending_date_label: Label
var _pending_date_was_above := false
var _pending_date_width := 0.0
var _pending_date_height := 0.0
var _pending_date_detached := false
var _time_layout_normalized := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_render_face)
	set_process(true)
	_load_selected_face()


func configure(index: int, palette: Dictionary = {}, _design: Dictionary = {}) -> void:
	_style_index = clampi(index, 1, maxi(1, _library.get_face_count()))
	_palette = palette.duplicate(true)
	_show_date = false
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


func is_time_layout_normalized() -> bool:
	return _time_layout_normalized


func _process(_delta: float) -> void:
	# Wait for the newly-created containers to finish layout before measuring
	# their labels. This stays on the live renderer instance (no async resume
	# after a style rebuild frees it).
	if is_instance_valid(_pending_normalization_frame) and is_instance_valid(_pending_normalization_root):
		var frame := _pending_normalization_frame
		var root_node := _pending_normalization_root
		if frame.is_inside_tree() and root_node.is_inside_tree() and frame.size.x > 0.0 and frame.size.y > 0.0:
			var time_bounds := _get_time_layer_bounds(root_node)
			if time_bounds.size.x > 0.0 and time_bounds.size.y > 0.0:
				var stable := _rects_match(time_bounds, _pending_normalization_last_bounds, 0.1)
				_pending_normalization_stable_frames = _pending_normalization_stable_frames + 1 if stable else 0
				_pending_normalization_last_bounds = time_bounds
				# Godot may need multiple layout passes after imported face
				# controls are attached. Normalize only after the measured time
				# bounds stop changing, avoiding style-dependent first-frame data.
				if _pending_normalization_stable_frames >= 2:
					if not _pending_date_detached:
						_detach_date_from_layout(frame, root_node)
						_pending_date_detached = true
						# Removing the date can reflow a BoxContainer and move the
						# time labels. Measure again after that second layout settles.
						_pending_normalization_last_bounds = Rect2()
						_pending_normalization_stable_frames = 0
					else:
						_normalize_time_and_date(frame, root_node)
						_time_layout_normalized = true
						_pending_normalization_frame = null
						_pending_normalization_root = null
						_pending_normalization_last_bounds = Rect2()
						_pending_normalization_stable_frames = 0
	var now := Time.get_time_dict_from_system()
	if int(now.get("minute", -1)) != _last_minute:
		_render_face()


func _load_selected_face() -> void:
	_face = _library.get_face(_style_index)
	_last_minute = -1
	_render_face()


func _render_face() -> void:
	_pending_normalization_frame = null
	_pending_normalization_root = null
	_pending_normalization_last_bounds = Rect2()
	_pending_normalization_stable_frames = 0
	_pending_date_label = null
	_pending_date_was_above = false
	_pending_date_width = 0.0
	_pending_date_height = 0.0
	_pending_date_detached = false
	_time_layout_normalized = false
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if size.x <= 0.0 or size.y <= 0.0:
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

	# Every imported face shares one fixed, centered canvas. The JSON controls
	# typography and composition inside it, never the clock's screen position.
	var frame := Control.new()
	frame.name = "XMorphClockFace"
	_set_normalized_rect(frame, FACE_FRAME_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var frame_size := Vector2(size.x * FACE_FRAME_RECT.size.x, size.y * FACE_FRAME_RECT.size.y)
	var root_node := _build_layout_node(large, frame_size)
	if root_node == null:
		return
	root_node.name = "XMorphClockLayout"
	root_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(root_node)
	_pending_normalization_frame = frame
	_pending_normalization_root = root_node
	_pending_normalization_last_bounds = Rect2()
	_pending_normalization_stable_frames = 0
	_last_minute = int(Time.get_time_dict_from_system().get("minute", -1))


func get_time_visual_rect() -> Rect2:
	return _get_time_layer_bounds(self)


func get_date_visual_rect() -> Rect2:
	var date_label := _pending_date_label if is_instance_valid(_pending_date_label) else _find_date_layer(self)
	return date_label.get_global_rect() if date_label != null and date_label.visible else Rect2()


func get_date_time_gap_pixels() -> float:
	var time_rect := get_time_visual_rect()
	var date_rect := get_date_visual_rect()
	if time_rect.size == Vector2.ZERO or date_rect.size == Vector2.ZERO:
		return -1.0
	if date_rect.end.y <= time_rect.position.y:
		return time_rect.position.y - date_rect.end.y
	if date_rect.position.y >= time_rect.end.y:
		return date_rect.position.y - time_rect.end.y
	return 0.0


func _detach_date_from_layout(frame: Control, root_node: Control) -> void:
	_pending_date_label = null
	_pending_date_was_above = false
	_pending_date_width = 0.0
	_pending_date_height = 0.0
	var date_label := _find_date_layer(root_node)
	if date_label == null or not date_label.visible:
		return
	_pending_date_label = date_label
	var original_date_rect := date_label.get_global_rect()
	var initial_time_rect := _get_time_layer_bounds(root_node)
	if initial_time_rect.size != Vector2.ZERO:
		_pending_date_was_above = original_date_rect.get_center().y < initial_time_rect.get_center().y
	var date_font := date_label.get_theme_font("font")
	var date_font_size := date_label.get_theme_font_size("font_size")
	_pending_date_width = date_label.custom_minimum_size.x
	if date_font != null:
		_pending_date_width = maxf(_pending_date_width, date_font.get_string_size(
			date_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, date_font_size
		).x + 8.0)
	_pending_date_height = maxf(date_label.custom_minimum_size.y, maxf(float(date_font_size) * 1.35, 16.0))
	# Detach the date before the final time measurement. BoxContainers need
	# another layout pass after this removal, otherwise their time children
	# shift after centering has already been applied.
	date_label.reparent(frame, false)
	date_label.anchor_left = 0.0
	date_label.anchor_top = 0.0
	date_label.anchor_right = 0.0
	date_label.anchor_bottom = 0.0
	date_label.offset_left = 0.0
	date_label.offset_top = 0.0
	date_label.offset_right = 0.0
	date_label.offset_bottom = 0.0
	date_label.custom_minimum_size = Vector2.ZERO
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _normalize_time_and_date(frame: Control, root_node: Control) -> void:
	var date_label := _pending_date_label
	var date_visible := is_instance_valid(date_label) and date_label.visible
	var date_was_above := _pending_date_was_above
	var date_width := _pending_date_width
	var date_height := _pending_date_height
	var time_rect := _get_time_layer_bounds(root_node)
	if time_rect.size == Vector2.ZERO:
		return

	# Imported faces keep their own type, font, tracking and time composition,
	# but the visible time group always shares the same visual center.
	var frame_rect := frame.get_global_rect()
	var time_local := Rect2(time_rect.position - frame_rect.position, time_rect.size)
	# The visual time center is the invariant across face styles. Do not clamp
	# this translation to the internal face-frame edges: doing so leaves some
	# layouts visibly off-center when their artwork extends beyond that frame.
	var shift := frame.size * 0.5 - time_local.get_center()
	if not is_zero_approx(shift.x) or not is_zero_approx(shift.y):
		root_node.offset_left += shift.x
		root_node.offset_right += shift.x
		root_node.offset_top += shift.y
		root_node.offset_bottom += shift.y

	time_rect = _get_time_layer_bounds(root_node)
	if time_rect.size == Vector2.ZERO or not date_visible or date_label == null:
		return
	var current_frame_rect := frame.get_global_rect()
	var time_in_frame := Rect2(time_rect.position - current_frame_rect.position, time_rect.size)
	date_width = clampf(date_width, 24.0, frame.size.x)
	date_height = minf(maxf(date_height, 16.0), frame.size.y)
	var gap := clampf(frame.size.y * DATE_TIME_GAP_RATIO, DATE_TIME_GAP_MIN, DATE_TIME_GAP_MAX)
	date_label.size = Vector2(date_width, date_height)
	var date_x := clampf(time_in_frame.get_center().x - date_width * 0.5, 0.0, frame.size.x - date_width)
	var above_y := time_in_frame.position.y - gap - date_height
	var below_y := time_in_frame.end.y + gap
	var date_y := above_y if date_was_above else below_y
	if date_y < 0.0 or date_y + date_height > frame.size.y:
		date_y = below_y if date_was_above else above_y
	date_y = clampf(date_y, 0.0, frame.size.y - date_height)
	date_label.position = Vector2(date_x, date_y)


func _rects_match(first: Rect2, second: Rect2, tolerance: float) -> bool:
	return first.position.distance_to(second.position) <= tolerance and first.size.distance_to(second.size) <= tolerance


func _get_time_layer_bounds(search_root: Node) -> Rect2:
	var has_bounds := false
	var bounds := Rect2()
	for label_value in search_root.find_children("*", "Label", true, false):
		var clock_label := label_value as Label
		if not clock_label.visible or clock_label.text.is_empty():
			continue
		var layer := _get_layer(_layer_id_for_label(clock_label))
		if str(layer.get("type", "")) not in TIME_LAYER_TYPES:
			continue
		var label_rect := clock_label.get_global_rect()
		if label_rect.size.x <= 0.0 or label_rect.size.y <= 0.0:
			continue
		bounds = label_rect if not has_bounds else bounds.merge(label_rect)
		has_bounds = true
	return bounds if has_bounds else Rect2()


func _find_date_layer(search_root: Node) -> Label:
	var fallback_date: Label = null
	for label_value in search_root.find_children("*", "Label", true, false):
		var clock_label := label_value as Label
		var layer_id := _layer_id_for_label(clock_label)
		if str(_get_layer(layer_id).get("type", "")) != "DATE":
			continue
		# Some faces have secondary date labels (for example, weekday plus
		# calendar date). Keep the primary `date` layer as the shared nearby
		# date anchor even after it is reparented outside the layout tree.
		if layer_id == "date":
			return clock_label
		if fallback_date == null:
			fallback_date = clock_label
	return fallback_date


func _layer_id_for_label(clock_label: Label) -> String:
	match clock_label.name:
		"DigitalClockHours":
			return "hours"
		"DigitalClockMinutes":
			return "minutes"
		"DigitalClockDate":
			return "date"
		"DigitalClockTime":
			return "time"
		_:
			return clock_label.name.trim_prefix("ClockLayer_") if clock_label.name.begins_with("ClockLayer_") else ""


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
	var layer_type := str(layer.get("type", "TEXT"))
	var requested_size := DATE_FONT_FRACTION
	if layer_type in ["HOURS", "MINUTES", "COLON", "TIME", "HOUR_TENS", "HOUR_ONES", "MINUTE_TENS", "MINUTE_ONES"]:
		requested_size = TIME_FONT_FRACTION
	var short_side := minf(available_size.x, available_size.y)
	var max_font_size := mini(180, maxi(12, roundi(available_size.y * 0.42)))
	var font_size := clampi(roundi(short_side * requested_size * 0.62), 11, max_font_size)
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
