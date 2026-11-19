extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

const CLOCK_CONTAINER_SIZE := Vector2(0.90, 0.50)
const DEFAULT_CLOCK_POSITION := Vector2(0.05, 0.14)
const DEFAULT_CLOCK_RECT := Rect2(DEFAULT_CLOCK_POSITION, CLOCK_CONTAINER_SIZE)

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


func _ready() -> void:
	set_process(true)


func configure(design: Dictionary, palette: Dictionary) -> void:
	var saved_position: Variant = design.get("clock_position", DEFAULT_CLOCK_POSITION)
	_clock_position = saved_position if saved_position is Vector2 else DEFAULT_CLOCK_POSITION
	_clock_position.x = clampf(_clock_position.x, 0.0, 1.0 - CLOCK_CONTAINER_SIZE.x)
	_clock_position.y = clampf(_clock_position.y, 0.0, 1.0 - CLOCK_CONTAINER_SIZE.y)
	_position_mode = str(design.get("clock_position_mode", "fixed")).to_lower()
	if _position_mode not in ["flex", "fixed"]:
		_position_mode = "fixed"
	_apply_clock_position()

	# Preserve the generated analog-artwork and date geometry inside the shared
	# draggable frame. Digital faces fill that same frame, so both clock types
	# move and lock as one object.
	var screen_clock_rect: Rect2 = design.get("clock_rect", Rect2(0.35, 0.2, 0.30, 0.15))
	_set_normalized_rect(analog_container, _to_frame_rect(screen_clock_rect))
	_set_normalized_rect(digital_artwork, Rect2(0.0, 0.0, 1.0, 1.0))
	var date_rect := _find_component_rect(design, "date")
	if date_rect.size.x > 0.0 and date_rect.size.y > 0.0:
		_set_normalized_rect(date_label, _to_frame_rect(date_rect))

	var clock_type := str(design.get("clock_type", "analog")).to_lower()
	analog_container.visible = clock_type == "analog"
	digital_artwork.visible = clock_type == "digital"
	date_label.visible = clock_type == "analog" and bool(design.get("show_details", true))

	date_label.add_theme_color_override("font_color", palette.get("muted", Color("#C7CDD5")))
	date_label.add_theme_font_size_override("font_size", int(design.get("date_font_size", 15)))
	date_label.horizontal_alignment = _alignment_from_name(str(design.get("date_align", "center")))
	date_label.add_theme_constant_override("letter_spacing", int(design.get("date_letter_spacing", 1)))

	var style_index := int(design.get("clock_style_index", design.get("analog_clock_asset_index", 1)))
	var asset_index := int(design.get("analog_clock_asset_index", style_index))
	analog_artwork.texture = load(AssetLibrary.get_analog_clock_path(asset_index)) as Texture2D
	analog_artwork.visible = clock_type == "analog" and analog_artwork.texture != null
	digital_artwork.call("configure", int(design.get("digital_clock_style_index", style_index)), palette, design)
	_refresh_date()


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


func get_drag_hit_rect() -> Rect2:
	if not is_instance_valid(position_container):
		return Rect2()
	if digital_artwork.visible:
		var frame_rect := digital_artwork.get_global_rect()
		return Rect2(
			frame_rect.position + frame_rect.size * Vector2(0.05, 0.30),
			frame_rect.size * Vector2(0.90, 0.40)
		).grow(12.0)
	var hit_rect := analog_container.get_global_rect()
	if date_label.visible:
		hit_rect = hit_rect.merge(date_label.get_global_rect())
	return hit_rect.grow(12.0)


func begin_clock_drag(screen_position: Vector2) -> bool:
	if _position_mode != "flex" or not visible or not get_drag_hit_rect().has_point(screen_position):
		return false
	_drag_active = true
	var viewport_size := _get_lock_screen_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_drag_active = false
		return false
	_drag_offset = screen_position / viewport_size - _clock_position
	return true


func drag_clock_to(screen_position: Vector2) -> bool:
	if not _drag_active:
		return false
	var viewport_size := _get_lock_screen_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var next_position := screen_position / viewport_size - _drag_offset
	_clock_position.x = clampf(next_position.x, 0.0, 1.0 - CLOCK_CONTAINER_SIZE.x)
	_clock_position.y = clampf(next_position.y, 0.0, 1.0 - CLOCK_CONTAINER_SIZE.y)
	_apply_clock_position()
	return true


func end_clock_drag() -> void:
	_drag_active = false


func _get_lock_screen_size() -> Vector2:
	var parent_control := get_parent_control()
	return parent_control.size if parent_control != null else size


func _apply_clock_position() -> void:
	_set_normalized_rect(position_container, Rect2(_clock_position, CLOCK_CONTAINER_SIZE))


func _to_frame_rect(screen_rect: Rect2) -> Rect2:
	return Rect2(
		(screen_rect.position - DEFAULT_CLOCK_RECT.position) / DEFAULT_CLOCK_RECT.size,
		screen_rect.size / DEFAULT_CLOCK_RECT.size
	)


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
