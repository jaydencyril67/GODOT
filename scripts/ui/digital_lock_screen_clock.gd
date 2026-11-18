extends Control

# These 41 presets are grouped around the real phone lock-screen references:
# Galaxy S21 / One UI, Galaxy S26 / One UI, iPhone 16 Pro Max, iPhone 17 Pro
# Max, and Pixel / Android 16. Each preset describes a phone-screen layout,
# never a decorative clock device or a hardware bezel.
const STYLE_GROUPS := [
	{
		"source": "SAMSUNG GALAXY S21 · ONE UI",
		"layout": "single",
		"time_rect": Rect2(0.075, 0.215, 0.85, 0.145),
		"hours_rect": Rect2(),
		"minutes_rect": Rect2(),
		"date_rect": Rect2(0.075, 0.178, 0.85, 0.026),
		"font_names": ["Roboto"],
		"font_families": ["sans-serif", "sans-serif-light", "sans-serif-medium", "sans-serif-black", "sans-serif-condensed", "sans-serif", "sans-serif", "sans-serif"],
		"date_format": "samsung",
		"color_mode": "text",
		"names": ["One UI Classic", "One UI Light", "One UI Medium", "One UI Bold", "One UI Compact", "One UI Wide", "One UI Left", "One UI Right"],
		"font_scales": [0.108, 0.104, 0.11, 0.112, 0.103, 0.109, 0.108, 0.108],
		"font_weights": [400, 300, 600, 900, 500, 800, 600, 700],
		"font_italics": [false, false, false, false, false, false, true, false],
		"time_letter_spacings": [0, 0, 0, 0, 0, 1, 0, -1],
		"font_stretches": [100, 96, 100, 100, 92, 112, 100, 100],
		"alignments": ["center", "center", "center", "center", "center", "center", "left", "right"],
		"font_alphas": [1.0, 0.96, 1.0, 1.0, 0.96, 1.0, 1.0, 1.0],
		"date_scales": [0.021, 0.021, 0.021, 0.021, 0.02, 0.021, 0.021, 0.021]
	},
	{
		"source": "SAMSUNG GALAXY S26 · ONE UI",
		"layout": "stacked",
		"time_rect": Rect2(),
		"hours_rect": Rect2(0.08, 0.115, 0.84, 0.115),
		"minutes_rect": Rect2(0.08, 0.23, 0.84, 0.115),
		"date_rect": Rect2(0.08, 0.35, 0.84, 0.028),
		"font_names": ["Roboto"],
		"date_format": "samsung",
		"color_mode": "text",
		"names": ["One UI Stack", "One UI Stack Light", "One UI Stack Medium", "One UI Stack Bold", "One UI Stack Narrow", "One UI Stack Wide", "One UI Stretch", "One UI Stack Large"],
		"font_scales": [0.11, 0.106, 0.11, 0.112, 0.106, 0.11, 0.112, 0.114],
		"font_weights": [400, 300, 600, 900, 500, 700, 600, 700],
		"font_italics": [false, false, false, false, false, false, true, false],
		"time_letter_spacings": [0, 0, 0, 0, 0, 1, 0, -1],
		"font_stretches": [100, 100, 100, 100, 88, 112, 112, 100],
		"alignments": ["center", "center", "center", "center", "center", "center", "center", "center"],
		"font_alphas": [1.0, 0.96, 1.0, 1.0, 1.0, 1.0, 0.98, 1.0],
		"date_scales": [0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.022]
	},
	{
		"source": "APPLE IPHONE 16 PRO MAX · IOS",
		"layout": "single",
		"time_rect": Rect2(0.055, 0.225, 0.89, 0.17),
		"hours_rect": Rect2(),
		"minutes_rect": Rect2(),
		"date_rect": Rect2(0.055, 0.19, 0.89, 0.026),
		"font_names": ["Roboto"],
		"font_families": ["sans-serif", "sans-serif-light", "sans-serif", "sans-serif-medium", "sans-serif-medium", "sans-serif-black", "sans-serif-condensed", "sans-serif"],
		"date_format": "apple",
		"color_mode": "white",
		"names": ["iOS Classic", "iOS Ultralight", "iOS Light", "iOS Regular", "iOS Medium", "iOS Semibold", "iOS Wide", "iOS Tall"],
		"font_scales": [0.12, 0.116, 0.118, 0.12, 0.122, 0.124, 0.12, 0.126],
		"font_weights": [400, 200, 300, 500, 600, 800, 500, 600],
		"font_italics": [false, false, false, false, false, false, false, true],
		"time_letter_spacings": [0, 0, 0, 0, 0, 0, 1, 0],
		"font_stretches": [100, 100, 100, 100, 100, 100, 112, 100],
		"alignments": ["center", "center", "center", "center", "center", "center", "center", "center"],
		"font_alphas": [1.0, 0.94, 0.96, 1.0, 1.0, 1.0, 1.0, 1.0],
		"date_scales": [0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021]
	},
	{
		"source": "APPLE IPHONE 17 PRO MAX · IOS",
		"layout": "single",
		"time_rect": Rect2(0.045, 0.212, 0.91, 0.18),
		"hours_rect": Rect2(),
		"minutes_rect": Rect2(),
		"date_rect": Rect2(0.055, 0.178, 0.89, 0.026),
		"font_names": ["Roboto"],
		"font_families": ["sans-serif", "sans-serif-light", "sans-serif", "sans-serif-medium", "sans-serif-medium", "sans-serif-black", "sans-serif-condensed", "sans-serif"],
		"date_format": "apple",
		"color_mode": "white",
		"names": ["iOS 26 Clear", "iOS 26 Soft", "iOS 26 Translucent", "iOS 26 Light", "iOS 26 Medium", "iOS 26 Bold", "iOS 26 Tall", "iOS 26 Extended"],
		"font_scales": [0.124, 0.12, 0.116, 0.118, 0.122, 0.126, 0.128, 0.124],
		"font_weights": [400, 350, 300, 400, 600, 900, 500, 600],
		"font_italics": [false, false, false, false, false, false, false, true],
		"time_letter_spacings": [0, 0, 0, 0, 0, 0, 1, 0],
		"font_stretches": [100, 100, 100, 96, 100, 100, 108, 118],
		"alignments": ["center", "center", "center", "center", "center", "center", "center", "center"],
		"font_alphas": [1.0, 0.9, 0.76, 0.94, 1.0, 1.0, 0.92, 0.96],
		"date_scales": [0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021]
	},
	{
		"source": "GOOGLE PIXEL · ANDROID 16",
		"layout": "stacked",
		"layouts": ["stacked", "stacked", "stacked", "stacked", "stacked", "stacked", "single", "single", "single"],
		"time_rect": Rect2(0.08, 0.205, 0.84, 0.14),
		"hours_rect": Rect2(0.09, 0.145, 0.82, 0.108),
		"minutes_rect": Rect2(0.09, 0.253, 0.82, 0.108),
		"date_rect": Rect2(0.09, 0.365, 0.82, 0.026),
		"font_names": ["Roboto"],
		"font_families": ["sans-serif", "sans-serif-light", "sans-serif-medium", "sans-serif-black", "sans-serif-condensed", "sans-serif", "sans-serif", "sans-serif-condensed", "sans-serif-condensed"],
		"date_format": "pixel",
		"color_mode": "accent",
		"names": ["Material Stack", "Material Stack Light", "Material Stack Medium", "Material Stack Bold", "Material Stack Narrow", "Material Stack Wide", "Material Single", "Material Single Wide", "Material Single Compact"],
		"font_scales": [0.11, 0.106, 0.112, 0.114, 0.106, 0.11, 0.108, 0.11, 0.102],
		"font_weights": [400, 300, 600, 900, 500, 700, 500, 600, 400],
		"font_italics": [false, false, false, false, false, false, false, true, false],
		"time_letter_spacings": [0, 0, 0, 0, 0, 1, 0, 1, -1],
		"font_stretches": [100, 100, 100, 100, 88, 112, 100, 115, 90],
		"alignments": ["center", "center", "center", "center", "center", "center", "center", "center", "center"],
		"font_alphas": [1.0, 0.96, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		"date_scales": [0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.021, 0.02]
	}
]

var _style_profiles: Array[Dictionary] = []
var _font_cache: Dictionary = {}
var style_index := 1
var _current_time := "00:00"
var _last_minute := -1
var _palette: Dictionary = {}
var _show_date := true

var _single_time_label: Label
var _hours_label: Label
var _minutes_label: Label
var _date_label: Label


func _init() -> void:
	_style_profiles = _build_style_profiles()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_single_time_label = _create_clock_label("DigitalClockTime")
	_hours_label = _create_clock_label("DigitalClockHours")
	_minutes_label = _create_clock_label("DigitalClockMinutes")
	_date_label = _create_clock_label("DigitalClockDate")
	add_child(_single_time_label)
	add_child(_hours_label)
	add_child(_minutes_label)
	add_child(_date_label)
	resized.connect(_apply_profile_layout)
	set_process(true)
	_refresh_time()
	_apply_profile_layout()


func configure(index: int, palette: Dictionary = {}, design: Dictionary = {}) -> void:
	style_index = clampi(index, 1, _style_profiles.size())
	_palette = palette.duplicate(true)
	_show_date = bool(design.get("show_details", true))
	_refresh_time()
	_apply_profile_layout()


func get_style_index() -> int:
	return style_index


func get_style_count() -> int:
	return _style_profiles.size()


func get_style_name() -> String:
	return str(_current_profile().get("name", "Digital Lock Screen"))


func get_style_source() -> String:
	return str(_current_profile().get("source", "PHONE LOCK SCREEN"))


func get_style_layout() -> String:
	return str(_current_profile().get("layout", "single"))


func _build_style_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for group_value in STYLE_GROUPS:
		var group: Dictionary = group_value
		var names: Array = group.get("names", [])
		for variant_index in range(names.size()):
			var profile: Dictionary = group.duplicate(true)
			profile.erase("names")
			var layouts: Array = profile.get("layouts", [])
			if not layouts.is_empty():
				profile["layout"] = str(layouts[variant_index % layouts.size()])
			profile.erase("layouts")
			profile["name"] = str(names[variant_index])
			profile["font_scale"] = _variant_value(group.get("font_scales", []), variant_index, 0.12)
			profile["font_names"] = [str(_variant_value(group.get("font_families", []), variant_index, "sans-serif")), "Roboto"]
			profile["font_italic"] = bool(_variant_value(group.get("font_italics", []), variant_index, false))
			profile["time_letter_spacing"] = int(_variant_value(group.get("time_letter_spacings", []), variant_index, 0))
			profile["font_weight"] = _variant_value(group.get("font_weights", []), variant_index, 400)
			profile["font_stretch"] = _variant_value(group.get("font_stretches", []), variant_index, 100)
			profile["alignment"] = str(_variant_value(group.get("alignments", []), variant_index, "center"))
			profile["font_alpha"] = _variant_value(group.get("font_alphas", []), variant_index, 1.0)
			profile["date_font_scale"] = _variant_value(group.get("date_scales", []), variant_index, 0.026)
			profiles.append(profile)
	return profiles


func _variant_value(values: Array, index: int, fallback: Variant) -> Variant:
	if values.is_empty():
		return fallback
	return values[index % values.size()]


func _current_profile() -> Dictionary:
	if _style_profiles.is_empty():
		return {}
	return _style_profiles[clampi(style_index - 1, 0, _style_profiles.size() - 1)]


func _create_clock_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	return label


func _process(_delta: float) -> void:
	var time := Time.get_time_dict_from_system()
	var minute := int(time.get("minute", -1))
	if minute != _last_minute:
		_refresh_time()
		_apply_profile_layout()


func _refresh_time() -> void:
	var time := Time.get_time_dict_from_system()
	_current_time = "%02d:%02d" % [int(time.get("hour", 0)), int(time.get("minute", 0))]
	_last_minute = int(time.get("minute", -1))
	if is_instance_valid(_single_time_label):
		_single_time_label.text = _current_time
	if is_instance_valid(_hours_label):
		_hours_label.text = _current_time.substr(0, 2)
	if is_instance_valid(_minutes_label):
		_minutes_label.text = _current_time.substr(3, 2)
	if is_instance_valid(_date_label):
		_date_label.text = _format_date(str(_current_profile().get("date_format", "samsung")))


func _format_date(format_id: String) -> String:
	var date := Time.get_date_dict_from_system()
	var weekday := clampi(int(date.get("weekday", 1)), 1, 7)
	var month := clampi(int(date.get("month", 1)), 1, 12)
	var day := int(date.get("day", 1))
	var weekdays_short := ["", "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
	var weekdays_long := ["", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
	var months_short := ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var months_long := ["", "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
	match format_id:
		"apple":
			return "%s, %s %d" % [weekdays_long[weekday], months_long[month], day]
		"pixel":
			return "%s, %s %d" % [weekdays_short[weekday], months_short[month], day]
		_:
			return "%s, %d %s" % [weekdays_short[weekday], day, months_short[month]]


func _apply_profile_layout() -> void:
	if not is_instance_valid(_single_time_label) or not is_instance_valid(_date_label):
		return
	var profile := _current_profile()
	if profile.is_empty():
		return

	var layout := str(profile.get("layout", "single"))
	var single_rect: Rect2 = profile.get("time_rect", Rect2(0.08, 0.21, 0.84, 0.15))
	var hours_rect: Rect2 = profile.get("hours_rect", Rect2(0.08, 0.14, 0.84, 0.11))
	var minutes_rect: Rect2 = profile.get("minutes_rect", Rect2(0.08, 0.25, 0.84, 0.11))
	var date_rect: Rect2 = profile.get("date_rect", Rect2(0.08, 0.36, 0.84, 0.03))
	var alignment := _alignment_from_name(str(profile.get("alignment", "center")))
	_single_time_label.visible = layout == "single"
	_hours_label.visible = layout == "stacked"
	_minutes_label.visible = layout == "stacked"
	_date_label.visible = _show_date

	if layout == "stacked":
		_set_normalized_rect(_hours_label, hours_rect)
		_set_normalized_rect(_minutes_label, minutes_rect)
	else:
		_set_normalized_rect(_single_time_label, single_rect)
	_set_normalized_rect(_date_label, date_rect)

	var font := _get_profile_font(profile)
	var time_color := _get_time_color(profile)
	var date_color: Color = _palette.get("muted", Color(time_color.r, time_color.g, time_color.b, 0.88))
	var alpha := float(profile.get("font_alpha", 1.0))
	time_color.a *= alpha
	var single_font_size := _fit_font_size(font, _current_time, single_rect, float(profile.get("font_scale", 0.14)))
	var stacked_font_size := _fit_font_size(font, "88", hours_rect, float(profile.get("font_scale", 0.14)))
	var date_font_size := maxi(11, roundi(minf(size.y * float(profile.get("date_font_scale", 0.026)), size.y * date_rect.size.y * 0.9)))
	_apply_label_style(_single_time_label, font, single_font_size, time_color, alignment, int(profile.get("time_letter_spacing", 0)))
	_apply_label_style(_hours_label, font, stacked_font_size, time_color, alignment, int(profile.get("time_letter_spacing", 0)))
	_apply_label_style(_minutes_label, font, stacked_font_size, time_color, alignment, int(profile.get("time_letter_spacing", 0)))
	_apply_label_style(_date_label, font, date_font_size, date_color, alignment, int(profile.get("date_letter_spacing", 0)))
	_date_label.visible = _show_date


func _fit_font_size(font: Font, text_value: String, rect: Rect2, relative_scale: float) -> int:
	var available_height := maxf(18.0, size.y * rect.size.y * 0.9)
	var font_size := maxi(18, roundi(minf(size.y * relative_scale, available_height)))
	var available_width := maxf(48.0, size.x * rect.size.x * 0.96)
	while font_size > 18 and font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > available_width:
		font_size -= 2
	return font_size


func _get_profile_font(profile: Dictionary) -> Font:
	var names := PackedStringArray()
	for value in profile.get("font_names", ["Roboto"]):
		names.append(str(value))
	var weight := int(profile.get("font_weight", 400))
	var stretch := int(profile.get("font_stretch", 100))
	var italic := bool(profile.get("font_italic", false))
	var key := "%s|%d|%d|%s" % [",".join(names), weight, stretch, str(italic)]
	if _font_cache.has(key):
		return _font_cache[key] as Font
	var font := SystemFont.new()
	font.font_names = names
	font.font_weight = weight
	font.font_stretch = stretch
	font.font_italic = italic
	_font_cache[key] = font
	return font


func _get_time_color(profile: Dictionary) -> Color:
	match str(profile.get("color_mode", "text")):
		"white":
			return Color(1.0, 1.0, 1.0, 1.0)
		"accent":
			return _palette.get("accent", Color.WHITE)
		_:
			return _palette.get("text", Color.WHITE)


func _apply_label_style(label: Label, font: Font, font_size: int, color: Color, alignment: HorizontalAlignment, letter_spacing: int) -> void:
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("letter_spacing", letter_spacing)


func _alignment_from_name(value: String) -> HorizontalAlignment:
	match value:
		"left":
			return HORIZONTAL_ALIGNMENT_LEFT
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		_:
			return HORIZONTAL_ALIGNMENT_CENTER


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
