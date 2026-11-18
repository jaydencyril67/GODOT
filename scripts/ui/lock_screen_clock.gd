extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

@onready var date_label: Label = $GeneratedLockScreenDate
@onready var analog_container: Control = $AnalogClock
@onready var analog_artwork: TextureRect = $AnalogClock/GeneratedAnalogClockArtwork
@onready var digital_artwork: Control = $DigitalClock

var _last_minute := -1


func _ready() -> void:
	set_process(true)


func configure(design: Dictionary, palette: Dictionary) -> void:
	var clock_rect: Rect2 = design.get("clock_rect", Rect2(0.35, 0.2, 0.30, 0.15))
	_set_normalized_rect(analog_container, clock_rect)
	_set_normalized_rect(digital_artwork, clock_rect)

	date_label.add_theme_color_override("font_color", palette.get("muted", Color("#C7CDD5")))
	date_label.add_theme_font_size_override("font_size", int(design.get("date_font_size", 15)))
	date_label.horizontal_alignment = _alignment_from_name(str(design.get("date_align", "center")))
	date_label.add_theme_constant_override("letter_spacing", int(design.get("date_letter_spacing", 1)))
	_set_normalized_rect(date_label, _find_component_rect(design, "date"))
	date_label.visible = bool(design.get("show_details", true))

	var style_index := int(design.get("clock_style_index", design.get("analog_clock_asset_index", 1)))
	var clock_type := str(design.get("clock_type", "analog")).to_lower()
	analog_container.visible = clock_type == "analog"
	digital_artwork.visible = clock_type == "digital"

	var asset_index := int(design.get("analog_clock_asset_index", style_index))
	analog_artwork.texture = load(AssetLibrary.get_analog_clock_path(asset_index)) as Texture2D
	analog_artwork.visible = clock_type == "analog" and analog_artwork.texture != null
	digital_artwork.call("configure", int(design.get("digital_clock_style_index", style_index)))
	_refresh_date()


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
