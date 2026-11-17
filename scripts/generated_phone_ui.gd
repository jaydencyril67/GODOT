extends Control
class_name GeneratedPhoneUI

var blueprint: Dictionary = {}
var _font: Font
var _typography_scale := 1.0
var _icon_texture_cache: Dictionary = {}
var _wallpaper_texture_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/STIXTwoText[wght].ttf") as Font
	queue_redraw()


func set_blueprint(config: Dictionary) -> void:
	blueprint = config.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	if blueprint.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Color("#101820"))
		return

	var style: Dictionary = blueprint.get("style", {})
	var palette: Dictionary = style.get("palette", {})
	var home: Dictionary = blueprint.get("home", {})
	var system: Dictionary = blueprint.get("system", {})
		var surface := _palette_color(palette, "surface", "#203344")
	var accent := _palette_color(palette, "accent", "#79D7D0")
	var text_color := _palette_color(palette, "text", "#F4FAFC")
	var muted := _palette_color(palette, "muted", "#A9BDC8")
	var secondary := _palette_color(palette, "accent_secondary", "#B5A8FF")
	match str(style.get("accent_treatment", "vivid")):
		"subtle":
			accent = accent.darkened(0.14)
		"tonal":
			accent = secondary
		"vivid":
			accent = accent.lightened(0.08)
	var radius := int(style.get("corner_radius", 22))
	_typography_scale = clampf(float(style.get("typography_scale", 1.0)), 0.85, 1.2)
	var margin := size.x * 0.065

	_draw_wallpaper(str(style.get("wallpaper_path", "")))
	_draw_status_bar(text_color, muted, system, style)

	var composition: Dictionary = home.get("composition", {})
	var placements: Array = composition.get("widget_placements", [])
	var apps_top := size.y * clampf(float(composition.get("apps_top", 0.57)), 0.46, 0.675)
	var density := str(style.get("composition_density", "balanced"))
	var widget_scale := 0.94 if density == "airy" else (1.04 if density == "compact" else 1.0)
	var header_text := str(home.get("header_text", "YOUR SPACE"))
	_draw_text(header_text, Vector2(margin, size.y * 0.143), 13, text_color, HORIZONTAL_ALIGNMENT_LEFT, size.x - margin * 2.0)

	for placement_value in placements:
		if not placement_value is Dictionary:
			continue
		var placement: Dictionary = placement_value
		var rect_values: Array = placement.get("rect", [])
		if rect_values.size() != 4:
			continue
		var widget_rect := Rect2(
				Vector2(float(rect_values[0]) * size.x, float(rect_values[1]) * size.y),
				Vector2(float(rect_values[2]) * size.x, float(rect_values[3]) * size.y)
			)
		var widget_type := str(placement.get("type", "clock"))
		var local_scale := clampf(widget_rect.size.y / maxf(1.0, size.y * 0.22), 0.62, 1.12) * widget_scale
		_draw_widget(widget_rect, widget_type, palette, radius, text_color, muted, accent, local_scale)

	if bool(home.get("show_search", true)):
		var search_y := apps_top - size.y * 0.105
		if str(home.get("search_position", "above_apps")) == "below_widgets":
			var region_bounds: Array = composition.get("region_bounds", [])
			if region_bounds.size() == 4:
				search_y = (float(region_bounds[1]) + float(region_bounds[3]) + 0.012) * size.y
		_draw_search_bar(Rect2(margin, search_y, size.x - margin * 2.0, size.y * 0.052), surface, muted, radius)

	_draw_apps(home.get("apps", []), apps_top, style, palette, text_color, muted, size)
	_draw_dock(home.get("dock", []), style, palette, text_color, muted, size, radius)
	_draw_navigation(style, muted, text_color)


func _draw_wallpaper(base: Color, accent: Color, wallpaper_style: String, sefunc _draw_wallpaper(wallpaper_path: String) -> void:
	if wallpaper_path.is_empty():
		push_error("Phone UI has no selected wallpaper asset.")
		return
	var texture: Texture2D = _wallpaper_texture_cache.get(wallpaper_path) as Texture2D
	if texture == null:
		if not ResourceLoader.exists(wallpaper_path):
			push_error("Phone UI wallpaper asset does not exist: " + wallpaper_path)
			return
		texture = ResourceLoader.load(wallpaper_path) as Texture2D
		if texture == null:
			push_error("Phone UI wallpaper asset could not be loaded: " + wallpaper_path)
			return
		_wallpaper_texture_cache[wallpaper_path] = texture
	var source_size := texture.get_size()
	var target_ratio := size.x / maxf(1.0, size.y)
	var source_ratio := source_size.x / maxf(1.0, source_size.y)
	var source_rect := Rect2(Vector2.ZERO, source_size)
	if source_ratio > target_ratio:
		var cropped_width := source_size.y * target_ratio
		source_rect.position.x = (source_size.x - cropped_width) * 0.5
		source_rect.size.x = cropped_width
	else:
		var cropped_height := source_size.x / target_ratio
		source_rect.position.y = (source_size.y - cropped_height) * 0.5
		source_rect.size.y = cropped_height
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), source_rect), style: Dictionary) -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour := int(now.get("hour", 9))
	var minute := int(now.get("minute", 41))
	var time_text := "%02d:%02d" % [hour, minute]
	if str(system.get("time_format", "24h")) == "12h":
		var period := "PM" if hour >= 12 else "AM"
		var twelve_hour := hour % 12
		time_text = "%d:%02d %s" % [12 if twelve_hour == 0 else twelve_hour, minute, period]
	_draw_text(time_text, Vector2(size.x * 0.065, size.y * 0.047), 13, text_color)
	var right := size.x * 0.94
	var status_style := str(style.get("status_bar_style", "balanced"))
	if status_style != "quiet":
		_draw_text(str(system.get("network_label", "5G")), Vector2(right - 72.0, size.y * 0.047), 10, text_color, HORIZONTAL_ALIGNMENT_RIGHT, 42.0)
	draw_arc(Vector2(right - 25.0, size.y * 0.039), 7.0, PI * 1.15, PI * 1.85, 20, text_color, 1.5, true)
	draw_arc(Vector2(right - 25.0, size.y * 0.039), 4.0, PI * 1.15, PI * 1.85, 20, text_color, 1.3, true)
	draw_circle(Vector2(right - 25.0, size.y * 0.048), 1.4, text_color)
	var battery_rect := Rect2(Vector2(right - 17.0, size.y * 0.026), Vector2(15.0, 8.0))
	draw_rect(battery_rect, text_color, false, 1.2)
	draw_rect(Rect2(battery_rect.position + Vector2(1.5, 1.5), Vector2(12.0 * float(system.get("battery_percent", 88)) / 100.0, 5.0)), text_color)
	draw_rect(Rect2(Vector2(right - 1.0, size.y * 0.029), Vector2(2.0, 4.0)), text_color)
	if bool(system.get("show_battery_percent", false)) and status_style == "detailed":
		_draw_text("%d%%" % int(system.get("battery_percent", 88)), Vector2(right - 23.0, size.y * 0.047), 8, text_color, HORIZONTAL_ALIGNMENT_RIGHT, 20.0)


func _draw_widget(rect: Rect2, widget_type: String, palette: Dictionary, corner_radius: int, text_color: Color, muted: Color, accent: Color, widget_text_scale: float) -> void:
	var surface := _palette_color(palette, "surface", "#203344")
	var surface_alt := _palette_color(palette, "surface_alt", "#30495B")
	var fill := Color(surface.r, surface.g, surface.b, 0.94)
	if str(blueprint.get("style", {}).get("surface_style", "glass")) == "glass":
		fill.a = 0.88
	_draw_round_rect(rect, fill, float(corner_radius))
	_draw_round_rect_outline(rect, Color(1.0, 1.0, 1.0, 0.13), float(corner_radius), 1.0)
	var inset := rect.size.x * 0.075
	match widget_type:
		"clock":
			_draw_text("LOCAL TIME", rect.position + Vector2(inset, rect.size.y * 0.27), 9, muted)
			_draw_clock(rect.position + Vector2(inset, rect.size.y * 0.70), int(rect.size.y * 0.40 * widget_text_scale), text_color)
			_draw_text("A good moment to begin.", rect.position + Vector2(inset, rect.size.y * 0.88), 9, muted)
		"weather":
			_draw_text("WEATHER", rect.position + Vector2(inset, rect.size.y * 0.24), 9, muted)
			_draw_text("28°", rect.position + Vector2(inset, rect.size.y * 0.70), int(rect.size.y * 0.42 * widget_text_scale), text_color)
			_draw_text("Partly cloudy  ·  Feels like 30°", rect.position + Vector2(inset, rect.size.y * 0.88), 9, muted)
			draw_circle(rect.position + Vector2(rect.size.x * 0.79, rect.size.y * 0.48), rect.size.y * 0.14, Color(accent.r, accent.g, accent.b, 0.88))
			draw_arc(rect.position + Vector2(rect.size.x * 0.79, rect.size.y * 0.48), rect.size.y * 0.21, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.34), 1.2, true)
		"calendar":
			_draw_text("UP NEXT", rect.position + Vector2(inset, rect.size.y * 0.24), 9, muted)
			_draw_text("18", rect.position + Vector2(inset, rect.size.y * 0.72), int(rect.size.y * 0.48 * widget_text_scale), text_color)
			_draw_text("DESIGN REVIEW", rect.position + Vector2(rect.size.x * 0.36, rect.size.y * 0.53), 10, accent)
			_draw_text("10:30  ·  Today", rect.position + Vector2(rect.size.x * 0.36, rect.size.y * 0.75), 9, muted)
		"music":
			_draw_text("NOW PLAYING", rect.position + Vector2(inset, rect.size.y * 0.25), 9, muted)
			_draw_text("A quieter kind of focus", rect.position + Vector2(inset, rect.size.y * 0.56), 14, text_color)
			_draw_text("Daily Mix  ·  32 min left", rect.position + Vector2(inset, rect.size.y * 0.78), 9, muted)
			draw_circle(rect.position + Vector2(rect.size.x * 0.84, rect.size.y * 0.54), rect.size.y * 0.20, accent)
			draw_colored_polygon(PackedVector2Array([
				rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.43),
				rect.position + Vector2(rect.size.x * 0.82, rect.size.y * 0.65),
				rect.position + Vector2(rect.size.x * 0.96, rect.size.y * 0.54)
			]), surface_alt)
		"device", "battery":
			_draw_text("DEVICE STATUS", rect.position + Vector2(inset, rect.size.y * 0.25), 9, muted)
			_draw_text("%d%%" % int(blueprint.get("system", {}).get("battery_percent", 88)), rect.position + Vector2(inset, rect.size.y * 0.72), int(rect.size.y * 0.38 * widget_text_scale), text_color)
			_draw_text("Battery health  ·  Normal", rect.position + Vector2(rect.size.x * 0.39, rect.size.y * 0.67), 9, muted)
			_draw_round_rect(Rect2(rect.position + Vector2(rect.size.x * 0.39, rect.size.y * 0.76), Vector2(rect.size.x * 0.48, 5.0)), Color(accent.r, accent.g, accent.b, 0.25), 3.0)
			_draw_round_rect(Rect2(rect.position + Vector2(rect.size.x * 0.39, rect.size.y * 0.76), Vector2(rect.size.x * 0.48 * 0.88, 5.0)), accent, 3.0)
		"focus":
			_draw_text("FOCUS MODE", rect.position + Vector2(inset, rect.size.y * 0.26), 9, muted)
			_draw_text("Stay in flow.", rect.position + Vector2(inset, rect.size.y * 0.60), 17, text_color)
			_draw_text("Next session  ·  25 minutes", rect.position + Vector2(inset, rect.size.y * 0.82), 9, muted)
		_:
			_draw_clock(rect.position + Vector2(inset, rect.size.y * 0.72), int(rect.size.y * 0.42), text_color)


func _draw_clock(text_position: Vector2, font_size: int, color: Color) -> void:
	var now := Time.get_datetime_dict_from_system()
	var hour := int(now.get("hour", 9))
	var minute := int(now.get("minute", 41))
	_draw_text("%02d:%02d" % [hour, minute], text_position, font_size, color)


func _draw_search_bar(rect: Rect2, surface: Color, muted: Color, radius: int) -> void:
	_draw_round_rect(rect, Color(surface.r, surface.g, surface.b, 0.94), float(radius) * 0.85)
	draw_circle(rect.position + Vector2(rect.size.y * 0.38, rect.size.y * 0.5), rect.size.y * 0.13, muted)
	_draw_text("Search anything", rect.position + Vector2(rect.size.y * 0.75, rect.size.y * 0.64), 10, muted)
	draw_circle(rect.position + Vector2(rect.size.x - rect.size.y * 0.48, rect.size.y * 0.5), rect.size.y * 0.15, Color(muted.r, muted.g, muted.b, 0.7))


func _draw_apps(apps_value: Variant, apps_top: float, style: Dictionary, _palette: Dictionary, text_color: Color, _muted: Color, viewport_size: Vector2) -> void:
	if not apps_value is Array:
		return
	var apps: Array = apps_value
	var columns := clampi(int(style.get("grid_columns", 4)), 3, 5)
	var margin := viewport_size.x * 0.045
	var cell_width := (viewport_size.x - margin * 2.0) / float(columns)
	var icon_size := clampf(float(style.get("icon_size", 52)) * 0.88, 36.0, 54.0)
	var row_count := maxi(1, ceili(float(apps.size()) / float(columns)))
	var dock_top := viewport_size.y - viewport_size.y * 0.083 - 38.0
	var available_height := maxf(48.0, dock_top - apps_top - 18.0)
	var label_gap := clampf(float(style.get("spacing", 14)) * 1.25, 13.0, 22.0)
	var row_height := minf(icon_size + label_gap, available_height / float(row_count))
	icon_size = minf(icon_size, maxf(26.0, row_height - label_gap))
	for index in range(apps.size()):
		var app_value: Variant = apps[index]
		if not app_value is Dictionary:
			continue
		var app: Dictionary = app_value
		var column := index % columns
		var row := floori(float(index) / float(columns))
		var centre := Vector2(margin + cell_width * (float(column) + 0.5), apps_top + float(row) * row_height)
		var icon_rect := Rect2(centre - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		_draw_app_icon(app, icon_rect)
		var label := str(app.get("name", "App"))
		_draw_text(label, centre + Vector2(-cell_width * 0.48, icon_size * 0.5 + label_gap - 8.0), 8, text_color, HORIZONTAL_ALIGNMENT_CENTER, cell_width * 0.96)


func _draw_app_icon(app: Dictionary, icon_rect: Rect2) -> void:
	var icon_path := str(app.get("icon_path", ""))
	if icon_path.is_empty():
		return
	var texture: Texture2D = _icon_texture_cache.get(icon_path) as Texture2D
	if texture == null:
		if not ResourceLoader.exists(icon_path):
			push_warning("Phone UI app icon asset is missing: " + icon_path)
			return
		texture = ResourceLoader.load(icon_path) as Texture2D
		if texture == null:
			push_warning("Phone UI app icon could not be loaded: " + icon_path)
			return
		_icon_texture_cache[icon_path] = texture
	draw_texture_rect(texture, icon_rect, false)


func _draw_dock(dock_value: Variant, _style: Dictionary, palette: Dictionary, _text_color: Color, _muted: Color, viewport_size: Vector2, radius: int) -> void:
	var dock: Array = dock_value if dock_value is Array else ["WhatsApp", "Gmail", "Spotify", "YouTube"]
	var dock_height := viewport_size.y * 0.083
	var dock_rect := Rect2(Vector2(viewport_size.x * 0.055, viewport_size.y - dock_height - 38.0), Vector2(viewport_size.x * 0.89, dock_height))
	var surface := _palette_color(palette, "surface", "#203344")
	_draw_round_rect(dock_rect, Color(surface.r, surface.g, surface.b, 0.92), float(radius))
	_draw_round_rect_outline(dock_rect, Color(1.0, 1.0, 1.0, 0.10), float(radius), 1.0)
	var cell_width := dock_rect.size.x / 4.0
	for index in range(mini(4, dock.size())):
		var app_name := str(dock[index])
		var app := _find_app(app_name)
		var icon_size := dock_rect.size.y * 0.60
		var centre := Vector2(dock_rect.position.x + cell_width * (float(index) + 0.5), dock_rect.position.y + dock_rect.size.y * 0.49)
		var icon_rect := Rect2(centre - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
		_draw_app_icon(app, icon_rect)


func _draw_navigation(style: Dictionary, muted: Color, text_color: Color) -> void:
	var y := size.y - 12.0
	if str(style.get("navigation_style", "gesture")) == "three_button":
		var centre_x := size.x * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(centre_x - 42.0, y - 3.0), Vector2(centre_x - 32.0, y - 9.0), Vector2(centre_x - 32.0, y + 3.0)]), muted)
		draw_circle(Vector2(centre_x, y - 3.0), 5.5, muted)
		draw_rect(Rect2(Vector2(centre_x + 28.0, y - 8.0), Vector2(12.0, 10.0)), muted, false, 1.5)
	else:
		_draw_round_rect(Rect2(Vector2(size.x * 0.5 - 34.0, y - 4.0), Vector2(68.0, 4.0)), Color(text_color.r, text_color.g, text_color.b, 0.84), 2.0)


func _find_app(app_name: String) -> Dictionary:
	for app_value in UIEvolutionEngine.APP_LIBRARY:
		if str(app_value.get("name", "")) == app_name:
			return app_value
	return {"name": app_name, "glyph": app_name.left(1), "color": "#6688B7"}


func _palette_color(palette: Dictionary, key: String, fallback: String) -> Color:
	return Color(str(palette.get(key, fallback)))


func _draw_text(caption: String, text_position: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if _font == null:
		return
	draw_string(_font, text_position, caption, alignment, width, maxi(8, roundi(float(font_size) * _typography_scale)), color)


func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var safe_radius := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position.x + safe_radius, rect.position.y, rect.size.x - safe_radius * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + safe_radius, rect.size.x, rect.size.y - safe_radius * 2.0), color)
	for corner in [
		rect.position + Vector2(safe_radius, safe_radius),
		rect.position + Vector2(rect.size.x - safe_radius, safe_radius),
		rect.position + Vector2(safe_radius, rect.size.y - safe_radius),
		rect.position + Vector2(rect.size.x - safe_radius, rect.size.y - safe_radius)
	]:
		draw_circle(corner, safe_radius, color)


func _draw_round_rect_outline(rect: Rect2, color: Color, radius: float, line_width: float) -> void:
	var safe_radius := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	draw_line(rect.position + Vector2(safe_radius, 0.0), rect.position + Vector2(rect.size.x - safe_radius, 0.0), color, line_width, true)
	draw_line(rect.position + Vector2(safe_radius, rect.size.y), rect.position + Vector2(rect.size.x - safe_radius, rect.size.y), color, line_width, true)
	draw_line(rect.position + Vector2(0.0, safe_radius), rect.position + Vector2(0.0, rect.size.y - safe_radius), color, line_width, true)
	draw_line(rect.position + Vector2(rect.size.x, safe_radius), rect.position + Vector2(rect.size.x, rect.size.y - safe_radius), color, line_width, true)
