extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

const DEFAULT_CLOCK_POSITION := Vector2.ZERO

@onready var position_container: Control = $ClockPositionContainer
@onready var date_label: Label = $ClockPositionContainer/GeneratedLockScreenDate
@onready var analog_container: Control = $ClockPositionContainer/AnalogClock
@onready var analog_artwork: TextureRect = $ClockPositionContainer/AnalogClock/GeneratedAnalogClockArtwork
@onready var digital_artwork: Control = $ClockPositionContainer/DigitalClock

var _last_minute := -1
var _position_mode := "fixed"
var _clock_position := DEFAULT_CLOCK_POSITION
var _drag_active := false
var _drag_offset := Vector2.ZERO
var _analog_textures: Dictionary = {}
var _clock_style_index := 1
var _clock_type := "analog"


func _ready() -> void:
	set_process(true)


func configure(design: Dictionary, palette: Dictionary) -> void:
	var saved_position: Variant = design.get("clock_position", DEFAULT_CLOCK_POSITION)
	_clock_position = saved_position if saved_position is Vector2 else DEFAULT_CLOCK_POSITION
	_clock_position.x = clampf(_clock_position.x, -2.0, 2.0)
	_clock_position.y = clampf(_clock_position.y, -2.0, 2.0)
	_position_mode = str(design.get("clock_position_mode", "fixed")).to_lower()
	if _position_mode not in ["flex", "fixed"]:
		_position_mode = "fixed"
	_apply_clock_position()

	var screen_clock_rect: Rect2 = design.get("clock_rect", Rect2(0.35, 0.2, 0.30, 0.15))
	_set_normalized_rect(analog_container, screen_clock_rect)
	_set_normalized_rect(digital_artwork, Rect2(0.0, 0.0, 1.0, 1.0))
	var date_rect := _find_component_rect(design, "date")
	if date_rect.size.x > 0.0 and date_rect.size.y > 0.0:
		_set_normalized_rect(date_label, date_rect)
	date_label.visible = false
	date_label.add_theme_color_override("font_color", palette.get("muted", Color("#C7CDD5")))
	date_label.add_theme_font_size_override("font_size", int(design.get("date_font_size", 15)))
	date_label.horizontal_alignment = _alignment_from_name(str(design.get("date_align", "center")))
	date_label.add_theme_constant_override("letter_spacing", int(design.get("date_letter_spacing", 1)))

	_clock_style_index = int(design.get("clock_style_index", design.get("analog_clock_asset_index", 1)))
	digital_artwork.call("configure", int(design.get("digital_clock_style_index", _clock_style_index)), palette, design)
	set_clock_style_index(_clock_style_index)
	set_clock_type(str(design.get("clock_type", "analog")))
	_refresh_date()


func prepare_all_styles(batch_size: int = 5, progress_callback: Callable = Callable()) -> bool:
	var total := AssetLibrary.get_analog_clock_count()
	var safe_batch_size := maxi(1, batch_size)
	for asset_index in range(1, total + 1):
		if not _analog_textures.has(asset_index):
			var asset_path := AssetLibrary.get_analog_clock_path(asset_index)
			_analog_textures[asset_index] = load(asset_path) as Texture2D
		if asset_index % safe_batch_size == 0 or asset_index == total:
			if progress_callback.is_valid():
				var analog_progress := 25.0 * float(asset_index) / maxf(float(total), 1.0)
				progress_callback.call("Preparing lock-screen clock styles", analog_progress)
			await get_tree().process_frame
	if not _restore_selected_analog_artwork():
		return false
	return bool(await digital_artwork.call("prepare_all_styles", 3, progress_callback))


func set_clock_style_index(style_index: int) -> bool:
	var digital_style_count := int(digital_artwork.call("get_style_count"))
	if style_index < 1 or style_index > digital_style_count:
		return false
	_clock_style_index = style_index
	# Digital faces retain their full 41-style library. Analog artwork is a
	# separate 15-image collection, so higher shared style indices use the
	# final available analog artwork rather than requesting a missing file.
	_restore_selected_analog_artwork()
	var digital_style_updated := bool(digital_artwork.call("set_style_index", style_index))
	_apply_clock_renderer_visibility()
	return digital_style_updated


func get_clock_style_index() -> int:
	return _clock_style_index


func set_clock_type(clock_type: String) -> bool:
	var normalized := clock_type.to_lower()
	if normalized not in ["analog", "digital"]:
		return false
	_clock_type = normalized
	if normalized == "analog":
		if not _restore_selected_analog_artwork():
			_apply_clock_renderer_visibility()
			return false
	else:
		# Re-select the cached digital face before exposing its renderer. This
		# keeps the selected style synchronized after returning from Analog.
		digital_artwork.call("set_style_index", _clock_style_index)
	_apply_clock_renderer_visibility()
	return true


func _restore_selected_analog_artwork() -> bool:
	var selected_texture := _analog_textures.get(_clock_style_index) as Texture2D
	if selected_texture == null:
		selected_texture = load(AssetLibrary.get_analog_clock_path(_clock_style_index)) as Texture2D
	if selected_texture == null:
		return false
	_analog_textures[_clock_style_index] = selected_texture
	analog_artwork.texture = selected_texture
	return true


func _apply_clock_renderer_visibility() -> void:
	var showing_analog := _clock_type == "analog"
	analog_container.visible = showing_analog
	digital_artwork.visible = not showing_analog
	analog_artwork.visible = showing_analog and analog_artwork.texture != null
	analog_container.queue_redraw()
	analog_artwork.queue_redraw()
	digital_artwork.queue_redraw()


func get_clock_type() -> String:
	return _clock_type

func set_position_mode(mode: String) -> bool:
	var normalized := mode.to_lower()
	if normalized not in ["flex", "fixed"]:
		return false
	_position_mode = normalized
	if _position_mode == "fixed":
		_drag_active = false
	return true


func get_position_mode() -> String:
	return _position_mode


func get_clock_position() -> Vector2:
	return _clock_position


func get_clock_visual_rect() -> Rect2:
	if not is_instance_valid(position_container):
		return Rect2()
	var has_bounds := false
	var bounds := Rect2()
	if digital_artwork.visible:
		for label_value in digital_artwork.find_children("*", "Label", true, false):
			var clock_label := label_value as Label
			if not clock_label.is_visible_in_tree() or clock_label.text.is_empty():
				continue
			var label_rect := clock_label.get_global_rect()
			if label_rect.size.x <= 0.0 or label_rect.size.y <= 0.0:
				continue
			bounds = label_rect if not has_bounds else bounds.merge(label_rect)
			has_bounds = true
	else:
		var artwork_rect := analog_artwork.get_global_rect()
		if artwork_rect.size.x > 0.0 and artwork_rect.size.y > 0.0:
			bounds = artwork_rect
			has_bounds = true
		if date_label.visible:
			var date_rect := date_label.get_global_rect()
			if date_rect.size.x > 0.0 and date_rect.size.y > 0.0:
				bounds = date_rect if not has_bounds else bounds.merge(date_rect)
				has_bounds = true
	return bounds if has_bounds else Rect2()


func get_drag_hit_rect() -> Rect2:
	# The larger touch target is only for starting a drag. Screen-edge limits
	# use the true visible clock bounds with no artificial inner margin.
	var bounds := get_clock_visual_rect()
	return bounds.grow(24.0) if bounds.size != Vector2.ZERO else Rect2()

func begin_clock_drag(screen_position: Vector2) -> bool:
	if _position_mode != "flex" or not visible or not get_drag_hit_rect().has_point(screen_position):
		return false
	_drag_active = true
	var screen_rect := _get_lock_screen_rect()
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		_drag_active = false
		return false
	_drag_offset = (screen_position - screen_rect.position) / screen_rect.size - _clock_position
	return true


func drag_clock_to(screen_position: Vector2) -> bool:
	if not _drag_active:
		return false
	var screen_rect := _get_lock_screen_rect()
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		return false
	var next_position := (screen_position - screen_rect.position) / screen_rect.size - _drag_offset
	var current_bounds := get_clock_visual_rect()
	if current_bounds.size.x > 0.0 and current_bounds.size.y > 0.0:
		var current_translation := _clock_position * screen_rect.size
		var unshifted_position := current_bounds.position - screen_rect.position - current_translation
		var unshifted_end := current_bounds.end - screen_rect.position - current_translation
		var minimum_offset := -unshifted_position
		var maximum_offset := screen_rect.size - unshifted_end
		if minimum_offset.x <= maximum_offset.x:
			next_position.x = clampf(next_position.x, minimum_offset.x / screen_rect.size.x, maximum_offset.x / screen_rect.size.x)
		else:
			next_position.x = (screen_rect.size.x * 0.5 - unshifted_position.x - current_bounds.size.x * 0.5) / screen_rect.size.x
		if minimum_offset.y <= maximum_offset.y:
			next_position.y = clampf(next_position.y, minimum_offset.y / screen_rect.size.y, maximum_offset.y / screen_rect.size.y)
		else:
			next_position.y = (screen_rect.size.y * 0.5 - unshifted_position.y - current_bounds.size.y * 0.5) / screen_rect.size.y
	_clock_position = next_position
	_apply_clock_position()
	return true


func end_clock_drag() -> void:
	_drag_active = false


func _get_lock_screen_rect() -> Rect2:
	var parent_control := get_parent_control()
	return parent_control.get_global_rect() if parent_control != null else get_global_rect()


func _get_lock_screen_size() -> Vector2:
	return _get_lock_screen_rect().size


func _apply_clock_position() -> void:
	# Keep the clock's original full-screen coordinate system and translate
	# the shared visual layer. This preserves every face's scale while allowing
	# the user to move it across the entire display.
	var viewport_size := _get_lock_screen_size()
	var translation := _clock_position * viewport_size
	position_container.offset_left = translation.x
	position_container.offset_top = translation.y
	position_container.offset_right = translation.x
	position_container.offset_bottom = translation.y


func _position_analog_date_near_clock(clock_rect: Rect2, original_date_rect: Rect2) -> void:
	var screen_size := _get_lock_screen_size()
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var date_font := date_label.get_theme_font("font")
	var font_size := date_label.get_theme_font_size("font_size")
	var measured_width := date_label.custom_minimum_size.x
	if date_font != null:
		measured_width = maxf(measured_width, date_font.get_string_size(
			date_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
		).x + 12.0)
	var date_width := clampf(maxf(measured_width, clock_rect.size.x * screen_size.x * 0.9), 48.0, screen_size.x * 0.90)
	var date_height := maxf(float(font_size) * 1.4, 18.0)
	var gap := clampf(screen_size.y * 0.008, 6.0, 12.0)
	var clock_in_pixels := Rect2(clock_rect.position * screen_size, clock_rect.size * screen_size)
	var was_above := original_date_rect.get_center().y < clock_rect.get_center().y
	var above_y := clock_in_pixels.position.y - gap - date_height
	var below_y := clock_in_pixels.end.y + gap
	var date_y := above_y if was_above else below_y
	if date_y < 0.0 or date_y + date_height > screen_size.y:
		date_y = below_y if was_above else above_y
	date_y = clampf(date_y, 0.0, screen_size.y - date_height)
	var date_x := clampf(clock_in_pixels.get_center().x - date_width * 0.5, 0.0, screen_size.x - date_width)
	_set_normalized_rect(date_label, Rect2(date_x / screen_size.x, date_y / screen_size.y, date_width / screen_size.x, date_height / screen_size.y))
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func get_analog_date_gap_pixels() -> float:
	if not date_label.visible:
		return -1.0
	var clock_rect := analog_artwork.get_global_rect()
	var date_rect := date_label.get_global_rect()
	if date_rect.end.y <= clock_rect.position.y:
		return clock_rect.position.y - date_rect.end.y
	if date_rect.position.y >= clock_rect.end.y:
		return date_rect.position.y - clock_rect.end.y
	return 0.0


func _process(_delta: float) -> void:
	var time := Time.get_time_dict_from_system()
	if int(time["minute"]) != _last_minute:
		_refresh_date()


func _refresh_date() -> void:
	var time := Time.get_time_dict_from_system()
	_last_minute = int(time["minute"])
	date_label.text = _current_date_text()


func _current_date_text() -> String:
	var date := Time.get_date_dict_from_system()
	var weekdays := ["", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
	var months := ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	return "%s, %02d %s" % [weekdays[clampi(int(date["weekday"]), 1, 7)], int(date["day"]), months[clampi(int(date["month"]), 1, 12)]]


func _alignment_from_name(value: String) -> HorizontalAlignment:
	match value:
		"left":
			return HORIZONTAL_ALIGNMENT_LEFT
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		_:
			return HORIZONTAL_ALIGNMENT_CENTER


func _find_component_rect(design: Dictionary, role: String) -> Rect2:
	for component in design.get("components", []):
		if str(component.get("role", "")) == role:
			return component.get("rect", Rect2())
	return Rect2()


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
