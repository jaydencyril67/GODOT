extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

@onready var digital_clock: Label = $GeneratedLockScreenClock
@onready var date_label: Label = $GeneratedLockScreenDate
@onready var analog_clock: Control = $AnalogClock
@onready var analog_face: TextureRect = $AnalogClock/GeneratedAnalogClockFace
@onready var hour_hand: TextureRect = $AnalogClock/AnalogHourHand
@onready var minute_hand: TextureRect = $AnalogClock/AnalogMinuteHand
@onready var second_hand: TextureRect = $AnalogClock/AnalogSecondHand

var _clock_style := "digital"
var _clock_format := "single"
var _last_minute := -1
var _last_second := -1


func _ready() -> void:
	set_process(true)


func configure(design: Dictionary, palette: Dictionary) -> void:
	_clock_style = str(design.get("clock_style", "digital"))
	_clock_format = str(design.get("clock_format", "single"))
	var clock_rect: Rect2 = design.get("clock_rect", Rect2(0.08, 0.2, 0.84, 0.15))
	_set_normalized_rect(digital_clock, clock_rect)
	_set_normalized_rect(analog_clock, clock_rect)
	digital_clock.add_theme_color_override("font_color", palette.get("text", Color.WHITE))
	digital_clock.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.30))
	digital_clock.add_theme_constant_override("shadow_offset_x", 1)
	digital_clock.add_theme_constant_override("shadow_offset_y", 3)
	digital_clock.add_theme_font_size_override("font_size", int(design.get("clock_font_size", 80)))
	digital_clock.horizontal_alignment = _alignment_from_name(str(design.get("clock_align", "center")))
	date_label.add_theme_color_override("font_color", palette.get("muted", Color("#C7CDD5")))
	date_label.add_theme_font_size_override("font_size", int(design.get("date_font_size", 15)))
	date_label.horizontal_alignment = _alignment_from_name(str(design.get("clock_align", "center")))
	date_label.add_theme_constant_override("letter_spacing", int(design.get("date_letter_spacing", 1)))
	_set_normalized_rect(date_label, _find_component_rect(design, "date"))
	analog_clock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	digital_clock.visible = _clock_style != "analog"
	analog_clock.visible = _clock_style == "analog"
	if _clock_style == "analog":
		_configure_analog_clock(design, palette)
	_refresh_time()


func _process(_delta: float) -> void:
	var time := Time.get_time_dict_from_system()
	if int(time["minute"]) != _last_minute or int(time["second"]) != _last_second:
		_refresh_time()


func _refresh_time() -> void:
	var time := Time.get_time_dict_from_system()
	_last_minute = int(time["minute"])
	_last_second = int(time["second"])
	var hour := int(time["hour"])
	var minute := int(time["minute"])
	var second := int(time["second"])
	var hour_text := "%02d" % hour
	var minute_text := "%02d" % minute
	match _clock_format:
		"split":
			digital_clock.text = hour_text + "\n" + minute_text
		"spaced":
			digital_clock.text = hour_text + "   " + minute_text
		_:
			digital_clock.text = hour_text + ":" + minute_text
	date_label.text = _current_date_text()
	if _clock_style == "analog":
		hour_hand.rotation = (float(hour % 12) + float(minute) / 60.0) * TAU / 12.0
		minute_hand.rotation = (float(minute) + float(second) / 60.0) * TAU / 60.0
		second_hand.rotation = float(second) * TAU / 60.0


func _configure_analog_clock(design: Dictionary, palette: Dictionary) -> void:
	var style_index := int(design.get("analog_clock_style_index", 1))
	analog_face.texture = load(AssetLibrary.get_analog_face_path(style_index)) as Texture2D
	hour_hand.texture = load(AssetLibrary.get_analog_hand_path(style_index, "hr")) as Texture2D
	minute_hand.texture = load(AssetLibrary.get_analog_hand_path(style_index, "min")) as Texture2D
	second_hand.texture = load(AssetLibrary.get_analog_hand_path(style_index, "sec")) as Texture2D
	hour_hand.modulate = palette.get("accent", Color.WHITE)
	minute_hand.modulate = palette.get("text", Color.WHITE)
	second_hand.modulate = palette.get("muted", Color.WHITE)
	for hand in [hour_hand, minute_hand, second_hand]:
		hand.resized.connect(func(): hand.pivot_offset = hand.size * 0.5)
		hand.pivot_offset = hand.size * 0.5


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
