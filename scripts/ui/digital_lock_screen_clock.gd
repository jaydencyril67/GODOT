extends Control

const STYLE_PROFILES := [
	{"family":"segment","case":"#15191E","screen":"#05090D","frame":"#5A3430","lit":"#FF493F","dim":"#54201F","accent":"#E47A64","label":"LED"},
	{"family":"segment","case":"#191715","screen":"#090807","frame":"#81532C","lit":"#FFAA45","dim":"#58361C","accent":"#FFD18B","label":"AMBER"},
	{"family":"segment","case":"#101820","screen":"#030A12","frame":"#275B83","lit":"#54C8FF","dim":"#183B52","accent":"#A5E5FF","label":"BLUE"},
	{"family":"lcd","case":"#29352C","screen":"#AAB99A","frame":"#536A4B","lit":"#243E2D","dim":"#71836A","accent":"#E4F0CB","label":"LCD"},
	{"family":"lcd","case":"#D9D9D1","screen":"#F4F4E9","frame":"#8C9487","lit":"#202C30","dim":"#B8C0B5","accent":"#FFFFFF","label":"PAPER"},
	{"family":"lcd","case":"#242A2D","screen":"#667D7B","frame":"#9BAAA4","lit":"#122B2B","dim":"#48605E","accent":"#C1E7DD","label":"GLASS"},
	{"family":"flip","case":"#171717","screen":"#090A0B","frame":"#B1A58E","lit":"#F3E9D4","dim":"#716B61","accent":"#E6CDA1","label":"FLIP"},
	{"family":"dot","case":"#19191B","screen":"#060608","frame":"#7E3734","lit":"#FF554B","dim":"#4B2221","accent":"#FFB2A8","label":"DOT MATRIX"},
	{"family":"dot","case":"#102020","screen":"#030D0D","frame":"#327D76","lit":"#55E6D0","dim":"#1C5B54","accent":"#A1FFF0","label":"MATRIX"},
	{"family":"dot","case":"#191B20","screen":"#070A11","frame":"#485DAD","lit":"#88A7FF","dim":"#303C70","accent":"#D0DBFF","label":"PIXEL"},
	{"family":"tube","case":"#17120F","screen":"#080604","frame":"#8A4B24","lit":"#FF9B48","dim":"#5D321C","accent":"#FFD2A0","label":"NIXIE"},
	{"family":"tube","case":"#15201D","screen":"#050B09","frame":"#477B68","lit":"#8FFFD2","dim":"#315B4C","accent":"#D3FFEC","label":"VFD"},
	{"family":"text","case":"#111318","screen":"#080A10","frame":"#404754","lit":"#F2F4FA","dim":"#686F7D","accent":"#FFFFFF","label":"ULTRA"},
	{"family":"text","case":"#18202B","screen":"#0A101B","frame":"#54728D","lit":"#C6E8FF","dim":"#536C84","accent":"#F0FAFF","label":"GLASS"},
	{"family":"segment","case":"#10171C","screen":"#050B10","frame":"#4A9BB1","lit":"#91F1FF","dim":"#275562","accent":"#D9FCFF","label":"EDGE"},
	{"family":"text","case":"#060708","screen":"#020303","frame":"#353A40","lit":"#F5F7FA","dim":"#555B62","accent":"#FFFFFF","label":"OLED"},
	{"family":"segment","case":"#A8A9A7","screen":"#1B2024","frame":"#D4D5D2","lit":"#F4F7F8","dim":"#52606A","accent":"#FFFFFF","label":"CHROME"},
	{"family":"segment","case":"#54585A","screen":"#111619","frame":"#B9C0C1","lit":"#B8F2E5","dim":"#44615C","accent":"#ECFFFB","label":"STEEL"},
	{"family":"flip","case":"#28231C","screen":"#100D09","frame":"#A9824C","lit":"#F2C77B","dim":"#624B2C","accent":"#FFE0A9","label":"DESK"},
	{"family":"segment","case":"#26313A","screen":"#0A1118","frame":"#596C7B","lit":"#E4F0FF","dim":"#596A7A","accent":"#FFFFFF","label":"SPORT"},
	{"family":"segment","case":"#0D131A","screen":"#050A10","frame":"#3D91B4","lit":"#6CD8FF","dim":"#24546C","accent":"#C5F1FF","label":"CHRONO"},
	{"family":"segment","case":"#353638","screen":"#101214","frame":"#8D9295","lit":"#F6B86D","dim":"#69523B","accent":"#FFE0B4","label":"INSTRUMENT"},
	{"family":"dot","case":"#17131E","screen":"#08050D","frame":"#7A4DA1","lit":"#D69AFF","dim":"#593B70","accent":"#F1D7FF","label":"ARCADE"},
	{"family":"lcd","case":"#30343A","screen":"#C6CCB7","frame":"#767F75","lit":"#26312A","dim":"#929A88","accent":"#F5F8E9","label":"CALCULATOR"},
	{"family":"text","case":"#17211A","screen":"#050B07","frame":"#376C4B","lit":"#8DFFAE","dim":"#3F7651","accent":"#D7FFE1","label":"TERMINAL"},
	{"family":"dot","case":"#101A13","screen":"#030A05","frame":"#315C39","lit":"#70F08A","dim":"#244E30","accent":"#D5FFD9","label":"MATRIX"},
	{"family":"segment","case":"#201326","screen":"#08050C","frame":"#874BA1","lit":"#F08BFF","dim":"#63366F","accent":"#FFD4FF","label":"VIOLET"},
	{"family":"text","case":"#101B25","screen":"#050C13","frame":"#377C96","lit":"#8CEBFF","dim":"#326779","accent":"#D2F8FF","label":"HOLOGRAM"},
	{"family":"lcd","case":"#D8D5C9","screen":"#F1EEE3","frame":"#A7A18F","lit":"#333C38","dim":"#B8B6A9","accent":"#FFFFFF","label":"E-INK"},
	{"family":"flip","case":"#11151A","screen":"#07090C","frame":"#4D677B","lit":"#E6F2FF","dim":"#516373","accent":"#C8E6FF","label":"SPLIT"},
	{"family":"flip","case":"#25221E","screen":"#090807","frame":"#A77E4B","lit":"#F7D6A2","dim":"#65523D","accent":"#FFF0D5","label":"AIRPORT"},
	{"family":"text","case":"#28333D","screen":"#101A22","frame":"#7C9AA9","lit":"#F1FAFF","dim":"#8198A4","accent":"#FFFFFF","label":"CLEAR"},
	{"family":"segment","case":"#30251D","screen":"#0D0A07","frame":"#9A7045","lit":"#FFD08B","dim":"#62472C","accent":"#FFF0CF","label":"WOOD"},
	{"family":"tube","case":"#211B12","screen":"#090704","frame":"#B38A4E","lit":"#FFC66B","dim":"#70532C","accent":"#FFF0BC","label":"BRASS"},
	{"family":"segment","case":"#15191D","screen":"#05090D","frame":"#737F88","lit":"#D4E7F2","dim":"#58636D","accent":"#F5FCFF","label":"DASH"},
	{"family":"lcd","case":"#242B2C","screen":"#82958B","frame":"#52665E","lit":"#1C2C26","dim":"#5E7669","accent":"#D9F2E3","label":"FIELD"},
	{"family":"segment","case":"#2A211A","screen":"#0B0805","frame":"#B06B32","lit":"#FFB25E","dim":"#6D421F","accent":"#FFE1B8","label":"AVIATION"},
	{"family":"segment","case":"#10202A","screen":"#030A10","frame":"#2B769D","lit":"#69CFFF","dim":"#24546D","accent":"#C5F1FF","label":"DEEP"},
	{"family":"text","case":"#080A0C","screen":"#020304","frame":"#555D65","lit":"#F8FAFC","dim":"#7A858E","accent":"#FFFFFF","label":"CERAMIC"},
	{"family":"segment","case":"#1A1722","screen":"#06050A","frame":"#6B5A9A","lit":"#C1A8FF","dim":"#50456E","accent":"#E9DFFF","label":"PRISM"},
	{"family":"text","case":"#15191E","screen":"#06090D","frame":"#9A875D","lit":"#F5E8C9","dim":"#796F5B","accent":"#FFF8E9","label":"SIGNATURE"}
]

const DIGIT_SEGMENTS := [126, 48, 109, 121, 51, 91, 95, 112, 127, 123]

var style_index := 1
var _current_time := "00:00"
var _last_minute := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_refresh_time()


func configure(index: int) -> void:
	style_index = clampi(index, 1, STYLE_PROFILES.size())
	_refresh_time()
	queue_redraw()


func get_style_index() -> int:
	return style_index


func get_style_count() -> int:
	return STYLE_PROFILES.size()


func _process(_delta: float) -> void:
	var time := Time.get_time_dict_from_system()
	var minute := int(time.get("minute", -1))
	if minute != _last_minute:
		_refresh_time()
		queue_redraw()


func _refresh_time() -> void:
	var time := Time.get_time_dict_from_system()
	_current_time = "%02d:%02d" % [int(time.get("hour", 0)), int(time.get("minute", 0))]
	_last_minute = int(time.get("minute", -1))


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var profile: Dictionary = STYLE_PROFILES[clampi(style_index - 1, 0, STYLE_PROFILES.size() - 1)]
	var base_size := minf(size.x, size.y)
	var outer_padding := base_size * 0.045
	var outer := Rect2(Vector2(outer_padding, outer_padding), size - Vector2(outer_padding * 2.0, outer_padding * 2.0))
	var frame_color := Color(str(profile.get("frame", "#56616D")))
	var case_color := Color(str(profile.get("case", "#15191E")))
	var screen_color := Color(str(profile.get("screen", "#05090D")))
	var accent_color := Color(str(profile.get("accent", "#FFFFFF")))

	draw_rect(Rect2(outer.position + Vector2(1.5, base_size * 0.014), outer.size), Color(0.0, 0.0, 0.0, 0.62), true)
	draw_rect(outer, case_color, true)
	draw_rect(outer, frame_color, false, maxf(1.0, base_size * 0.012))
	var inner_padding := base_size * 0.105
	var screen := Rect2(outer.position + Vector2(inner_padding, inner_padding * 0.72), outer.size - Vector2(inner_padding * 2.0, inner_padding * 1.44))
	draw_rect(screen, screen_color, true)
	draw_rect(screen, Color(frame_color.r, frame_color.g, frame_color.b, 0.72), false, maxf(1.0, base_size * 0.006))
	draw_line(screen.position + Vector2(4.0, 2.0), screen.position + Vector2(screen.size.x * 0.63, 2.0), Color(1.0, 1.0, 1.0, 0.18), maxf(1.0, base_size * 0.006), true)
	draw_line(Vector2(screen.position.x + 4.0, screen.end.y - 2.0), Vector2(screen.end.x - 4.0, screen.end.y - 2.0), Color(accent_color.r, accent_color.g, accent_color.b, 0.11), 1.0, true)

	var family := str(profile.get("family", "segment"))
	if family == "flip":
		_draw_flip_digits(screen, profile)
	elif family == "tube":
		_draw_tube_digits(screen, profile)
	elif family == "text":
		_draw_type_digits(screen, profile)
	else:
		_draw_segment_digits(screen, profile, family == "dot")

	_draw_case_details(outer, profile, style_index)


func _draw_segment_digits(screen: Rect2, profile: Dictionary, dotted: bool) -> void:
	var digit_width := screen.size.x * 0.155
	var digit_height := screen.size.y * 0.53
	var gap := screen.size.x * 0.022
	var colon_width := screen.size.x * 0.052
	var total_width := digit_width * 4.0 + gap * 3.0 + colon_width
	var start_x := screen.position.x + (screen.size.x - total_width) * 0.5
	var start_y := screen.position.y + (screen.size.y - digit_height) * 0.5
	var chars := _current_time.replace(":", "")
	var lit := Color(str(profile.get("lit", "#FFFFFF")))
	var dim := Color(str(profile.get("dim", "#33404B")))
	for index in range(4):
		var digit := int(chars.substr(index, 1))
		_draw_segment_digit(Vector2(start_x + float(index) * (digit_width + gap) + (colon_width if index >= 2 else 0.0), start_y), Vector2(digit_width, digit_height), digit, lit, dim, dotted)
	var colon_x := start_x + digit_width * 2.0 + gap * 1.5 + colon_width * 0.5
	var dot_radius := maxf(1.7, minf(digit_width, digit_height) * 0.035)
	var dot_color := lit
	draw_circle(Vector2(colon_x, start_y + digit_height * 0.34), dot_radius, dot_color)
	draw_circle(Vector2(colon_x, start_y + digit_height * 0.68), dot_radius, dot_color)


func _draw_segment_digit(origin: Vector2, digit_size: Vector2, digit: int, lit: Color, dim: Color, dotted: bool) -> void:
	var width := digit_size.x
	var height := digit_size.y
	var thickness := width * 0.17
	var middle_y := origin.y + height * 0.5
	var segment_rects := [
		Rect2(origin.x + thickness, origin.y, width - thickness * 2.0, thickness),
		Rect2(origin.x + width - thickness, origin.y + thickness * 0.85, thickness, height * 0.5 - thickness * 0.85),
		Rect2(origin.x + width - thickness, middle_y + thickness * 0.05, thickness, height * 0.5 - thickness * 0.9),
		Rect2(origin.x + thickness, origin.y + height - thickness, width - thickness * 2.0, thickness),
		Rect2(origin.x, middle_y + thickness * 0.05, thickness, height * 0.5 - thickness * 0.9),
		Rect2(origin.x, origin.y + thickness * 0.85, thickness, height * 0.5 - thickness * 0.85),
		Rect2(origin.x + thickness, middle_y - thickness * 0.5, width - thickness * 2.0, thickness)
	]
	var mask := int(DIGIT_SEGMENTS[clampi(digit, 0, 9)])
	for index in range(segment_rects.size()):
		var segment: Rect2 = segment_rects[index]
		var active := (mask & (1 << (6 - index))) != 0
		var color := lit if active else dim
		if active and not dotted:
			draw_rect(segment.grow(thickness * 0.17), Color(lit.r, lit.g, lit.b, 0.13), true)
		if dotted:
			var horizontal := segment.size.x > segment.size.y
			var length := segment.size.x if horizontal else segment.size.y
			var dot_count := maxi(2, int(length / maxf(3.2, thickness * 0.48)))
			for dot_index in range(dot_count):
				var fraction := (float(dot_index) + 0.5) / float(dot_count)
				var point := segment.position + segment.size * (Vector2(fraction, 0.5) if horizontal else Vector2(0.5, fraction))
				draw_circle(point, maxf(1.0, thickness * 0.13), color)
		else:
			draw_rect(segment, color, true)


func _draw_flip_digits(screen: Rect2, profile: Dictionary) -> void:
	var chars := _current_time.replace(":", "")
	var lit := Color(str(profile.get("lit", "#FFFFFF")))
	var dim := Color(str(profile.get("dim", "#303030")))
	var frame := Color(str(profile.get("frame", "#666666")))
	var card_gap := screen.size.x * 0.025
	var card_width := (screen.size.x * 0.88 - card_gap * 3.0) / 4.0
	var card_height := screen.size.y * 0.58
	var start_x := screen.position.x + (screen.size.x - (card_width * 4.0 + card_gap * 3.0)) * 0.5
	var start_y := screen.position.y + (screen.size.y - card_height) * 0.5
	var font := get_theme_default_font()
	var font_size := maxi(10, int(card_height * 0.68))
	for index in range(4):
		var card := Rect2(start_x + float(index) * (card_width + card_gap), start_y, card_width, card_height)
		draw_rect(card, Color(0.0, 0.0, 0.0, 0.42), true)
		draw_rect(card, dim, true)
		draw_rect(Rect2(card.position, Vector2(card.size.x, card.size.y * 0.49)), Color(lit.r, lit.g, lit.b, 0.06), true)
		draw_line(Vector2(card.position.x, card.position.y + card.size.y * 0.5), Vector2(card.end.x, card.position.y + card.size.y * 0.5), frame, maxf(1.0, card_width * 0.035), true)
		if font != null:
			var text_size := font.get_string_size(chars.substr(index, 1), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, Vector2(card.position.x + (card.size.x - text_size.x) * 0.5, card.position.y + card.size.y * 0.72), chars.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, lit)


func _draw_tube_digits(screen: Rect2, profile: Dictionary) -> void:
	var chars := _current_time.replace(":", "")
	var lit := Color(str(profile.get("lit", "#FFAA55")))
	var frame := Color(str(profile.get("frame", "#885533")))
	var tube_gap := screen.size.x * 0.035
	var tube_width := (screen.size.x * 0.84 - tube_gap * 3.0) / 4.0
	var tube_height := screen.size.y * 0.66
	var start_x := screen.position.x + (screen.size.x - (tube_width * 4.0 + tube_gap * 3.0)) * 0.5
	var start_y := screen.position.y + (screen.size.y - tube_height) * 0.5
	var font := get_theme_default_font()
	var font_size := maxi(10, int(tube_height * 0.7))
	for index in range(4):
		var tube := Rect2(start_x + float(index) * (tube_width + tube_gap), start_y, tube_width, tube_height)
		draw_rect(tube, Color(0.18, 0.12, 0.08, 0.7), true)
		draw_rect(tube, Color(frame.r, frame.g, frame.b, 0.8), false, maxf(1.0, tube_width * 0.055))
		draw_line(Vector2(tube.position.x + 2.0, tube.position.y + 3.0), Vector2(tube.position.x + tube_width * 0.42, tube.position.y + 3.0), Color(1.0, 1.0, 1.0, 0.26), 1.0, true)
		if font != null:
			var digit := chars.substr(index, 1)
			var text_size := font.get_string_size(digit, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, Vector2(tube.position.x + (tube_width - text_size.x) * 0.5, tube.position.y + tube_height * 0.73), digit, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, lit)


func _draw_type_digits(screen: Rect2, profile: Dictionary) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var lit := Color(str(profile.get("lit", "#FFFFFF")))
	var font_size := maxi(12, int(minf(screen.size.x * 0.18, screen.size.y * 0.34)))
	var text_size := font.get_string_size(_current_time, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := screen.position.y + (screen.size.y + font.get_ascent(font_size)) * 0.5
	draw_string(font, Vector2(screen.position.x + (screen.size.x - text_size.x) * 0.5 + 1.5, baseline + 2.0), _current_time, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72))
	draw_string(font, Vector2(screen.position.x + (screen.size.x - text_size.x) * 0.5, baseline), _current_time, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, lit)


func _draw_case_details(outer: Rect2, profile: Dictionary, index: int) -> void:
	var frame := Color(str(profile.get("frame", "#56616D")))
	var accent := Color(str(profile.get("accent", "#FFFFFF")))
	var corner_radius := minf(outer.size.x, outer.size.y) * 0.035
	if index in [20, 21, 22, 35, 36, 37]:
		var screw_radius := maxf(1.3, corner_radius * 0.22)
		for point in [
			outer.position + Vector2(corner_radius, corner_radius),
			Vector2(outer.end.x - corner_radius, outer.position.y + corner_radius),
			Vector2(outer.position.x + corner_radius, outer.end.y - corner_radius),
			outer.end - Vector2(corner_radius, corner_radius)
		]:
			draw_circle(point, screw_radius, Color(frame.r, frame.g, frame.b, 0.85))
			draw_line(point - Vector2(screw_radius * 0.55, 0.0), point + Vector2(screw_radius * 0.55, 0.0), Color(0.0, 0.0, 0.0, 0.65), 1.0, true)
	if index in [13, 14, 28, 32, 39, 40]:
		draw_line(outer.position + Vector2(corner_radius * 1.3, corner_radius * 1.1), Vector2(outer.end.x - corner_radius * 2.0, outer.position.y + corner_radius * 1.1), Color(accent.r, accent.g, accent.b, 0.22), maxf(1.0, corner_radius * 0.2), true)
	if index in [2, 3, 8, 9, 10, 15, 25, 26, 27, 37]:
		draw_arc(outer.get_center(), minf(outer.size.x, outer.size.y) * 0.43, PI * 1.08, PI * 1.92, 48, Color(accent.r, accent.g, accent.b, 0.18), 1.0, true)
