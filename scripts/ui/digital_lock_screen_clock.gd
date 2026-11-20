extends Control

const FaceAssetLibrary = preload("res://scripts/ui/xmorph_clock_face_asset_library.gd")
const FACE_FRAME_RECT := Rect2(0.05, 0.30, 0.90, 0.40)
const TIME_FONT_FRACTION := 0.32
const CLOCK_ROW_GAP_SCALE := 0.20
const CLOCK_COLUMN_GAP_SCALE := 0.30
const TIME_LABEL_SIDE_PADDING := 0.02

var _face_variants: Dictionary = {}
var _face_normalization_queue: Array[int] = []
var _faces_initialized := false
var _initial_build_pending := false
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
var _pending_date_label: Label
var _pending_date_was_above := false
var _pending_date_width := 0.0
var _pending_date_height := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func configure(index: int, palette: Dictionary = {}, _design: Dictionary = {}) -> void:
	_style_index = clampi(index, 1, maxi(1, _library.get_face_count()))
	_palette = palette.duplicate(true)
	_show_date = false
	if size.x > 0.0 and size.y > 0.0:
		if not _face_variants.has(_style_index):
			_build_face_variant(_style_index)
		_faces_initialized = not _face_variants.is_empty()
		if _faces_initialized:
			_select_cached_face(_style_index)
			_refresh_all_cached_time_labels()
	else:
		_initial_build_pending = true

func prepare_all_styles(batch_size: int = 3) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var selected_index := _style_index
	var total := get_style_count()
	var safe_batch_size := maxi(1, batch_size)
	for face_index in range(1, total + 1):
		_build_face_variant(face_index)
		if face_index % safe_batch_size == 0 or face_index == total:
			await get_tree().process_frame
	_faces_initialized = not _face_variants.is_empty()
	if not _faces_initialized:
		return
	refresh_cached_face_layouts()
	while not _face_normalization_queue.is_empty():
		await get_tree().process_frame
	_select_cached_face(selected_index)
	_refresh_all_cached_time_labels()


func set_style_index(index: int) -> bool:
	if index < 1 or index > get_style_count():
		return false
	if size.x <= 0.0 or size.y <= 0.0:
		_style_index = index
		_initial_build_pending = true
		return false
	if not _face_variants.has(index) and not _build_face_variant(index):
		return false
	_faces_initialized = not _face_variants.is_empty()
	_select_cached_face(index)
	_refresh_all_cached_time_labels()
	return true


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
	if not _face_variants.has(_style_index):
		return false
	return bool(_face_variants[_style_index].get("normalized", false))

func _process(_delta: float) -> void:
	if _initial_build_pending and size.x > 0.0 and size.y > 0.0:
		_initial_build_pending = false
		_initialize_face_variants()
	if not _faces_initialized:
		return
	_process_face_normalization_queue()
	var now := Time.get_time_dict_from_system()
	var current_minute := int(now.get("minute", -1))
	if current_minute != _last_minute:
		_refresh_all_cached_time_labels()
		_last_minute = current_minute

func _load_selected_face() -> void:
	if not _face_variants.has(_style_index):
		if not _build_face_variant(_style_index):
			return
	_faces_initialized = not _face_variants.is_empty()
	_select_cached_face(_style_index)
	_refresh_all_cached_time_labels()

func _render_face() -> void:
	# Only the selected face is built; other styles are created when requested.
	if not _face_variants.has(_style_index):
		if not _build_face_variant(_style_index):
			return
	_faces_initialized = not _face_variants.is_empty()
	_select_cached_face(_style_index)
	_refresh_all_cached_time_labels()

func get_time_visual_rect() -> Rect2:
	if not _face_variants.has(_style_index):
		return Rect2()
	var root_node: Control = _face_variants[_style_index].get("root") as Control
	return _get_time_layer_bounds(root_node, _face) if is_instance_valid(root_node) else Rect2()

func get_date_visual_rect() -> Rect2:
	return Rect2()

func get_date_time_gap_pixels() -> float:
	return -1.0


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


func _get_time_layer_bounds(search_root: Node, face_override: Dictionary = {}) -> Rect2:
	var has_bounds := false
	var bounds := Rect2()
	for label_value in search_root.find_children("*", "Label", true, false):
		var clock_label := label_value as Label
		if not clock_label.is_visible_in_tree() or clock_label.text.is_empty():
			continue
		var layer := _get_layer(_layer_id_for_label(clock_label), face_override)
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


func _build_layout_node(spec: Dictionary, available_size: Vector2, face_override: Dictionary = {}) -> Control:
	if spec.has("layer"):
		return _make_layer_label(spec, available_size, face_override)
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
		stack.custom_minimum_size = Vector2(
			available_size.x * float(data.get("width", 1.0)),
			available_size.y * float(data.get("height", 1.0))
		)
		for child_value in data.get("children", []):
			var child_spec: Dictionary = child_value
			var child := _build_layout_node(child_spec, available_size, face_override)
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
	var gap_scale := CLOCK_ROW_GAP_SCALE if layout_key == "row" else CLOCK_COLUMN_GAP_SCALE
	container.add_theme_constant_override(
		"separation",
		roundi(minf(available_size.x, available_size.y) * float(data.get("gap", 0.0)) * gap_scale)
	)
	for child_value in data.get("children", []):
		var child_spec: Dictionary = child_value
		var child := _build_layout_node(child_spec, available_size, face_override)
		if child == null:
			continue
		if child is Label:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL if layout_key == "column" else Control.SIZE_SHRINK_CENTER
		container.add_child(child)
	return container


func _initialize_face_variants() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if not _face_variants.has(_style_index):
		_build_face_variant(_style_index)
	_faces_initialized = not _face_variants.is_empty()
	_last_minute = int(Time.get_time_dict_from_system().get("minute", -1))
	if _faces_initialized:
		_select_cached_face(_style_index)
		_refresh_all_cached_time_labels()


func _build_face_variant(face_index: int) -> bool:
	if _face_variants.has(face_index):
		return true
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var face := _library.get_face(face_index)
	if face.is_empty():
		return false
	var large: Dictionary = face.get("large", {})
	var layout_key := ""
	for key in ["row", "column", "stack"]:
		if large.has(key):
			layout_key = key
			break
	if layout_key.is_empty():
		return false
	var frame_size := Vector2(size.x * FACE_FRAME_RECT.size.x, size.y * FACE_FRAME_RECT.size.y)
	_face = face
	var frame := Control.new()
	frame.name = "XMorphClockFace_%02d" % face_index
	_set_normalized_rect(frame, FACE_FRAME_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	add_child(frame)
	var root_node := _build_layout_node(large, frame_size, face)
	if root_node == null:
		remove_child(frame)
		frame.free()
		return false
	root_node.name = "XMorphClockLayout_%02d" % face_index
	root_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(root_node)
	_face_variants[face_index] = {
		"frame": frame,
		"root": root_node,
		"face": face,
		"last_bounds": Rect2(),
		"stable_frames": 0,
		"shift_applied": false,
		"shift_attempts": 0,
		"normalized": false
	}
	return true

func refresh_cached_face_layouts() -> void:
	if not _faces_initialized:
		return
	_face_normalization_queue.clear()
	for face_value in _face_variants.keys():
		var face_index := int(face_value)
		var state: Dictionary = _face_variants[face_index]
		var frame := state.get("frame") as Control
		var root_node := state.get("root") as Control
		if not is_instance_valid(frame) or not is_instance_valid(root_node):
			continue
		root_node.offset_left = 0.0
		root_node.offset_top = 0.0
		root_node.offset_right = 0.0
		root_node.offset_bottom = 0.0
		state["normalized"] = false
		state["last_bounds"] = Rect2()
		state["stable_frames"] = 0
		state["shift_applied"] = false
		state["shift_attempts"] = 0
		frame.visible = true
		frame.modulate.a = 1.0 if face_index == _style_index else 0.0
		_face_normalization_queue.append(face_index)


func _select_cached_face(face_index: int) -> void:
	if not _face_variants.has(face_index):
		return
	_style_index = face_index
	_face = _face_variants[face_index].get("face", {})
	_face_normalization_queue.clear()
	var selected_state: Dictionary = _face_variants[face_index]
	if not bool(selected_state.get("normalized", false)):
		var selected_root := selected_state.get("root") as Control
		if is_instance_valid(selected_root):
			selected_root.offset_left = 0.0
			selected_root.offset_top = 0.0
			selected_root.offset_right = 0.0
			selected_root.offset_bottom = 0.0
			selected_state["last_bounds"] = Rect2()
			selected_state["stable_frames"] = 0
			selected_state["shift_applied"] = false
			selected_state["shift_attempts"] = 0
			_face_normalization_queue.append(face_index)
	for cached_index in _face_variants.keys():
		var frame: Control = _face_variants[cached_index].get("frame") as Control
		if not is_instance_valid(frame):
			continue
		frame.visible = int(cached_index) == face_index
		frame.modulate = Color.WHITE

func _process_face_normalization_queue() -> void:
	if _face_normalization_queue.is_empty():
		return
	var completed_indices: Array[int] = []
	for face_value in _face_normalization_queue:
		var face_index := int(face_value)
		if not _face_variants.has(face_index):
			completed_indices.append(face_index)
			continue
		var state: Dictionary = _face_variants[face_index]
		var frame := state.get("frame") as Control
		var root_node := state.get("root") as Control
		if not is_instance_valid(frame) or not is_instance_valid(root_node) or not frame.is_inside_tree():
			continue
		var face: Dictionary = state.get("face", {})
		var time_bounds := _get_time_layer_bounds(root_node, face)
		if time_bounds.size.x <= 0.0 or time_bounds.size.y <= 0.0:
			continue
		var frame_rect := frame.get_global_rect()
		var time_local := Rect2(time_bounds.position - frame_rect.position, time_bounds.size)
		var target_center := frame.size * 0.5
		if bool(state.get("shift_applied", false)):
			var residual := target_center - time_local.get_center()
			if residual.length() <= 1.0:
				state["normalized"] = true
				completed_indices.append(face_index)
				continue
			var attempts := int(state.get("shift_attempts", 0)) + 1
			if attempts > 3:
				push_warning("XMorph clock face %02d could not reach its centered layout." % face_index)
				completed_indices.append(face_index)
				continue
			root_node.offset_left += residual.x
			root_node.offset_right += residual.x
			root_node.offset_top += residual.y
			root_node.offset_bottom += residual.y
			state["shift_attempts"] = attempts
			state["last_bounds"] = Rect2()
			state["stable_frames"] = 0
			continue
		var previous_bounds: Rect2 = state.get("last_bounds", Rect2())
		var stable_frames := int(state.get("stable_frames", 0))
		stable_frames = stable_frames + 1 if _rects_match(time_bounds, previous_bounds, 0.1) else 0
		state["last_bounds"] = time_bounds
		state["stable_frames"] = stable_frames
		if stable_frames < 2:
			continue
		var shift := target_center - time_local.get_center()
		root_node.offset_left += shift.x
		root_node.offset_right += shift.x
		root_node.offset_top += shift.y
		root_node.offset_bottom += shift.y
		state["shift_applied"] = true
		state["shift_attempts"] = 1
		state["last_bounds"] = Rect2()
		state["stable_frames"] = 0
	for face_index in completed_indices:
		_face_normalization_queue.erase(face_index)
	if _face_normalization_queue.is_empty():
		for cached_index in _face_variants.keys():
			var frame: Control = _face_variants[cached_index].get("frame") as Control
			if is_instance_valid(frame):
				frame.visible = int(cached_index) == _style_index
				frame.modulate = Color.WHITE

func _refresh_all_cached_time_labels() -> void:
	for face_index in _face_variants.keys():
		var state: Dictionary = _face_variants[face_index]
		var root_node := state.get("root") as Control
		var face: Dictionary = state.get("face", {})
		if not is_instance_valid(root_node):
			continue
		var changed := false
		for label_value in root_node.find_children("*", "Label", true, false):
			var clock_label := label_value as Label
			var layer_id := str(clock_label.get_meta("clock_layer_id", ""))
			if layer_id.is_empty():
				continue
			var layer := _get_layer(layer_id, face)
			if layer.is_empty():
				continue
			var next_text := _layer_text(layer)
			if clock_label.text == next_text:
				continue
			clock_label.text = next_text
			var font := clock_label.get_theme_font("font")
			var font_size := clock_label.get_theme_font_size("font_size")
			var available_width := float(clock_label.get_meta("clock_available_width", size.x))
			var side_padding := float(clock_label.get_meta("clock_side_padding", TIME_LABEL_SIDE_PADDING))
			var text_width := font.get_string_size(next_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x if font != null else available_width
			clock_label.custom_minimum_size.x = clampf(text_width + font_size * side_padding, font_size * 1.1, available_width)
			changed = true
		if changed:
			var frame := state.get("frame") as Control
			if is_instance_valid(frame):
				frame.visible = true
				frame.modulate.a = 1.0 if int(face_index) == _style_index else 0.0
			root_node.offset_left = 0.0
			root_node.offset_top = 0.0
			root_node.offset_right = 0.0
			root_node.offset_bottom = 0.0
			state["normalized"] = false
			state["last_bounds"] = Rect2()
			state["stable_frames"] = 0
			state["shift_applied"] = false
			state["shift_attempts"] = 0
			if not _face_normalization_queue.has(int(face_index)):
				_face_normalization_queue.append(int(face_index))

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


func _make_layer_label(node_spec: Dictionary, available_size: Vector2, face_override: Dictionary = {}) -> Label:
	var layer_id := str(node_spec.get("layer", ""))
	var layer := _get_layer(layer_id, face_override)
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
	label.set_meta("clock_layer_id", layer_id)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.text = _layer_text(layer)
	if not _show_date and str(layer.get("type", "")) == "DATE":
		label.visible = false
	var layer_type := str(layer.get("type", "TEXT"))
	var requested_size := TIME_FONT_FRACTION if layer_type in TIME_LAYER_TYPES else DATE_FONT_FRACTION
	var short_side := minf(available_size.x, available_size.y)
	var max_font_size := mini(112, maxi(12, roundi(available_size.y * 0.30)))
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
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var side_padding := TIME_LABEL_SIDE_PADDING if layer_type in TIME_LAYER_TYPES else 0.28
	label.set_meta("clock_side_padding", side_padding)
	label.set_meta("clock_available_width", available_size.x)
	label.custom_minimum_size = Vector2(
		clampf(text_width + font_size * side_padding, font_size * 1.1, available_size.x),
		maxf(font_size * 1.22, available_size.y * 0.025)
	)
	return label

func _get_layer(layer_id: String, face_override: Dictionary = {}) -> Dictionary:
	var source_face := face_override if not face_override.is_empty() else _face
	for layer_value in source_face.get("layers", []):
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
