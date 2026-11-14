extends Control

signal app_opened(app_name: String)

const OSEngine = preload("res://scripts/os/procedural_os_engine.gd")

class OSWallpaperLayer extends Control:
	var palette: Dictionary = {}
	var wallpaper_id := "aurora"
	var treatment := "natural"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var background := Color(str(palette.get("background", "#0B1017")))
		var accent := Color(str(palette.get("accent", "#76C8D4")))
		var surface := Color(str(palette.get("surface_alt", "#263544")))
		draw_rect(Rect2(Vector2.ZERO, size), background)

		var rng := RandomNumberGenerator.new()
		rng.seed = abs(hash(wallpaper_id))
		for star_index in range(34):
			var star_position := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
			var star_radius := rng.randf_range(0.45, 1.15)
			draw_circle(star_position, star_radius, Color(0.92, 0.96, 1.0, rng.randf_range(0.10, 0.34)))

		var shortest_side := minf(size.x, size.y)
		match wallpaper_id:
			"orbital":
				var planet_center := Vector2(size.x * 0.68, size.y * 0.43)
				var planet_radius := shortest_side * 0.31
				draw_arc(planet_center, planet_radius * 1.40, -0.45, 2.8, 96, Color(accent.r, accent.g, accent.b, 0.28), maxf(1.2, shortest_side * 0.010), true)
				draw_circle(planet_center, planet_radius, Color(surface.r * 0.55, surface.g * 0.55, surface.b * 0.55, 0.98))
				draw_circle(planet_center + Vector2(-planet_radius * 0.24, -planet_radius * 0.26), planet_radius * 0.76, Color(accent.r * 0.56, accent.g * 0.60, accent.b * 0.68, 0.72))
				draw_circle(planet_center + Vector2(-planet_radius * 0.43, -planet_radius * 0.43), planet_radius * 0.24, Color(1, 1, 1, 0.08))
				draw_arc(planet_center, planet_radius * 1.40, 2.95, 5.8, 96, Color(surface.r, surface.g, surface.b, 0.74), maxf(1.5, shortest_side * 0.018), true)
				draw_arc(planet_center, planet_radius * 0.91, -2.7, 0.4, 64, Color(accent.r, accent.g, accent.b, 0.34), maxf(1.0, shortest_side * 0.008), true)
			"dune":
				var far_dune := PackedVector2Array([
					Vector2(0, size.y * 0.58), Vector2(size.x * 0.18, size.y * 0.47),
					Vector2(size.x * 0.43, size.y * 0.55), Vector2(size.x * 0.72, size.y * 0.40),
					Vector2(size.x, size.y * 0.52), Vector2(size.x, size.y), Vector2(0, size.y)
				])
				var middle_dune := PackedVector2Array([
					Vector2(0, size.y * 0.73), Vector2(size.x * 0.22, size.y * 0.62),
					Vector2(size.x * 0.51, size.y * 0.70), Vector2(size.x * 0.79, size.y * 0.56),
					Vector2(size.x, size.y * 0.66), Vector2(size.x, size.y), Vector2(0, size.y)
				])
				var near_dune := PackedVector2Array([
					Vector2(0, size.y * 0.86), Vector2(size.x * 0.30, size.y * 0.75),
					Vector2(size.x * 0.61, size.y * 0.87), Vector2(size.x, size.y * 0.76),
					Vector2(size.x, size.y), Vector2(0, size.y)
				])
				draw_colored_polygon(far_dune, Color(surface.r, surface.g, surface.b, 0.52))
				draw_colored_polygon(middle_dune, Color(accent.r, accent.g, accent.b, 0.20))
				draw_colored_polygon(near_dune, Color(surface.r * 1.18, surface.g * 1.10, surface.b * 0.92, 0.86))
				draw_arc(Vector2(size.x * 0.32, size.y * 0.84), size.x * 0.46, -2.95, -0.35, 72, Color(1, 1, 1, 0.12), maxf(1.0, shortest_side * 0.006), true)
			"prism":
				var facet_one := PackedVector2Array([Vector2(size.x * 0.48, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.54), Vector2(size.x * 0.68, size.y * 0.42)])
				var facet_two := PackedVector2Array([Vector2(0, size.y * 0.22), Vector2(size.x * 0.48, 0), Vector2(size.x * 0.68, size.y * 0.42), Vector2(size.x * 0.28, size.y * 0.68)])
				var facet_three := PackedVector2Array([Vector2(size.x * 0.28, size.y * 0.68), Vector2(size.x * 0.68, size.y * 0.42), Vector2(size.x, size.y * 0.54), Vector2(size.x, size.y), Vector2(size.x * 0.48, size.y)])
				draw_colored_polygon(facet_one, Color(accent.r, accent.g, accent.b, 0.19))
				draw_colored_polygon(facet_two, Color(surface.r, surface.g, surface.b, 0.62))
				draw_colored_polygon(facet_three, Color(accent.r * 0.72, accent.g * 0.76, accent.b * 0.82, 0.20))
				draw_polyline(PackedVector2Array([Vector2(size.x * 0.48, 0), Vector2(size.x * 0.68, size.y * 0.42), Vector2(size.x * 0.28, size.y * 0.68), Vector2(size.x * 0.48, size.y)]), Color(1, 1, 1, 0.18), 1.2, true)
			"midnight_flow":
				for band in range(7):
					var points := PackedVector2Array()
					for step in range(41):
						var progress := float(step) / 40.0
						var wave := sin(progress * TAU * 1.15 + float(band) * 0.42) * 0.075
						var drift := cos(progress * PI * 1.3 + float(band) * 0.24) * 0.035
						var y_position := size.y * (0.28 + float(band) * 0.105 + wave + drift)
						points.append(Vector2(size.x * progress, y_position))
					draw_polyline(points, Color(surface.r, surface.g, surface.b, 0.24), maxf(3.0, shortest_side * 0.075), true)
					draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.12), maxf(1.0, shortest_side * 0.007), true)
			_:
				for band in range(6):
					var points := PackedVector2Array()
					for step in range(41):
						var progress := float(step) / 40.0
						var wave := sin(progress * TAU * 0.85 + float(band) * 0.56) * 0.070
						var crest := cos(progress * PI * 2.0 + float(band) * 0.30) * 0.025
						var y_position := size.y * (0.24 + float(band) * 0.105 + wave + crest)
						points.append(Vector2(size.x * progress, y_position))
					draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.045), maxf(3.0, shortest_side * 0.105), true)
					draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.13), maxf(1.0, shortest_side * 0.006), true)
				draw_circle(Vector2(size.x * 0.82, size.y * 0.24), shortest_side * 0.20, Color(accent.r, accent.g, accent.b, 0.035))

		if treatment == "deep_contrast":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.12))
		elif treatment == "soft_glow":
			draw_circle(Vector2(size.x * 0.74, size.y * 0.30), shortest_side * 0.42, Color(accent.r, accent.g, accent.b, 0.055))


class OSStatusIndicators extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(54, 14)
		queue_redraw()

	func _draw() -> void:
		var ink := Color("#F4F2ED")
		for i in range(4):
			var bar_height := 3.0 + float(i) * 2.1
			draw_rect(Rect2(Vector2(float(i) * 3.4, 12.0 - bar_height), Vector2(2.1, bar_height)), ink)
		var wifi_center := Vector2(22.0, 10.0)
		draw_arc(wifi_center, 6.0, PI * 1.18, PI * 1.82, 16, ink, 1.1, true)
		draw_arc(wifi_center, 3.7, PI * 1.20, PI * 1.80, 12, ink, 1.1, true)
		draw_circle(wifi_center + Vector2(0, -0.2), 1.0, ink)
		var battery := Rect2(Vector2(34.0, 3.0), Vector2(15.0, 9.0))
		draw_rect(battery, ink, false, 1.0)
		draw_rect(Rect2(Vector2(49.5, 5.7), Vector2(1.8, 3.6)), ink)
		draw_rect(Rect2(Vector2(35.6, 4.5), Vector2(11.5, 6.0)), ink)


class LockScreenFingerprintButton extends Button:
	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(52, 52)
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var ink := Color("#F3EDE3")
		var accent := Color("#D7B47A")
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(centre, radius, Color(0.04, 0.05, 0.06, 0.20))
		draw_arc(centre, radius - 1.0, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.78), 1.15, true)
		draw_arc(centre, radius - 4.0, 0.0, TAU, 48, Color(ink.r, ink.g, ink.b, 0.16), 0.8, true)
		draw_arc(centre + Vector2(0, 2), 12.0, PI * 1.12, PI * 1.88, 28, ink, 1.25, true)
		draw_arc(centre + Vector2(0, 3), 8.7, PI * 1.08, PI * 1.92, 24, ink, 1.15, true)
		draw_arc(centre + Vector2(0, 3), 5.4, PI * 1.03, PI * 1.97, 20, ink, 1.1, true)
		draw_arc(centre + Vector2(0, 5), 2.2, PI * 1.02, PI * 1.98, 16, ink, 1.0, true)
		draw_line(centre + Vector2(-9, 1), centre + Vector2(-7, 9), ink, 1.0, true)
		draw_line(centre + Vector2(9, 1), centre + Vector2(7, 9), ink, 1.0, true)
		if is_pressed():
			draw_circle(centre, radius - 1.0, Color(accent.r, accent.g, accent.b, 0.12))


var configuration: Dictionary = {}
var active_component := "home_screen"
var page_container: VBoxContainer
var status_label: Label
var _palette: Dictionary = {}
var _style: Dictionary = {}
var _building := false
var _last_layout_size := Vector2.ZERO
var _resize_rebuild_pending := false
var _gesture_start := Vector2.ZERO
var _gesture_start_time := 0
var _gesture_active := false
var _gesture_overlay: Control
var _recent_app_names: Array[String] = []
var _last_opened_app := ""
var _clock_update_elapsed := 0.0

func _process(delta: float) -> void:
	_clock_update_elapsed += delta
	if _clock_update_elapsed < 1.0:
		return
	_clock_update_elapsed = 0.0
	var status_clock := find_child("StatusBarClock", true, false) as Label
	if is_instance_valid(status_clock):
		status_clock.text = _current_lock_time()
	if active_component == "lock_screen":
		_refresh_lock_screen_clock()


func _current_lock_time(family: String = "") -> String:
	var now := Time.get_datetime_dict_from_system()
	var hour_minute := "%02d:%02d" % [int(now.get("hour", 9)), int(now.get("minute", 41))]
	if family == "typographic":
		return "%02d\n%02d" % [int(now.get("hour", 9)), int(now.get("minute", 41))]
	return hour_minute


func _current_lock_date(treatment: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	var weekdays := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
	var months := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
	var weekday := str(weekdays[clampi(int(now.get("weekday", 1)), 0, 6)])
	var month := str(months[clampi(int(now.get("month", 1)) - 1, 0, 11)])
	var day := int(now.get("day", 1))
	match treatment:
		"minimal":
			return "%s  ·  %02d %s" % [weekday.substr(0, 3), day, month.substr(0, 3)]
		"editorial":
			return "%s, %02d %s %04d" % [weekday, day, month, int(now.get("year", 2026))]
		"inline":
			return "%s %02d %s  ·  %04d" % [weekday.substr(0, 3), day, month.substr(0, 3), int(now.get("year", 2026))]
	return "%s  ·  %s %02d" % [weekday, month, day]


func _refresh_lock_screen_clock() -> void:
	var family := str(configuration.get("components", {}).get("lock_screen", {}).get("design_family", "minimal"))
	var data: Dictionary = configuration.get("components", {}).get("lock_screen", {})
	var clock := find_child("LockScreenClock", true, false) as Label
	if is_instance_valid(clock):
		clock.text = _current_lock_time(family)
	var date := find_child("LockScreenDate", true, false) as Label
	if is_instance_valid(date):
		date.text = _current_lock_date(str(data.get("date_treatment", "uppercase")))
	var status_clock := find_child("StatusBarClock", true, false) as Label
	if is_instance_valid(status_clock):
		status_clock.text = _current_lock_time()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_gesture(_screen_to_local(touch.position))
		else:
			_finish_gesture(_screen_to_local(touch.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_begin_gesture(_screen_to_local(mouse.position))
		else:
			_finish_gesture(_screen_to_local(mouse.position))


func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func _begin_gesture(touch_position: Vector2) -> void:
	_gesture_start = touch_position
	_gesture_start_time = Time.get_ticks_msec()
	_gesture_active = true


func _finish_gesture(touch_position: Vector2) -> void:
	if not _gesture_active:
		return
	_gesture_active = false
	var elapsed_ms := Time.get_ticks_msec() - _gesture_start_time
	_handle_system_gesture(_gesture_start, touch_position, elapsed_ms)


func _handle_system_gesture(start: Vector2, finish: Vector2, elapsed_ms: int) -> void:
	var delta := finish - start
	var vertical_threshold := maxf(34.0, size.y * 0.10)
	var horizontal_threshold := maxf(32.0, size.x * 0.18)
	var edge_size := clampf(minf(size.x, size.y) * 0.09, 18.0, 34.0)

	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		if delta.y <= -vertical_threshold or absf(delta.x) >= horizontal_threshold:
			_close_gesture_overlay()
		return

	if start.y <= edge_size and delta.y >= vertical_threshold and absf(delta.y) > absf(delta.x) * 1.2:
		if start.x >= size.x * 0.56:
			_show_gesture_overlay("control_center")
		else:
			_show_gesture_overlay("notifications")
		return

	if active_component == "lock_screen" and delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
		set_component_view("home_screen")
		return

	if start.y >= size.y - edge_size and delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
		if elapsed_ms >= 420:
			_show_gesture_overlay("recent_apps")
		elif active_component == "home_screen":
			set_component_view("app_drawer")
		else:
			_navigate_home()
		return

	if absf(delta.x) >= horizontal_threshold and absf(delta.x) > absf(delta.y) * 1.2:
		if start.x <= edge_size and delta.x > 0.0:
			_navigate_back()
		elif start.x >= size.x - edge_size and delta.x < 0.0:
			_navigate_back()


func _navigate_home() -> void:
	_close_gesture_overlay()
	set_component_view("home_screen")


func _navigate_back() -> void:
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		_close_gesture_overlay()
	elif active_component == "app_drawer":
		_navigate_home()
	else:
		_navigate_home()


func _show_gesture_overlay(mode: String) -> void:
	_close_gesture_overlay()
	_gesture_overlay = Control.new()
	_gesture_overlay.name = "OSGestureOverlay_" + mode
	_gesture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gesture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_gesture_overlay)

	var shade := ColorRect.new()
	shade.name = "GestureOverlayShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_gesture_overlay.add_child(shade)

	var margins := MarginContainer.new()
	margins.name = "GestureOverlayMargins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 8)
	margins.add_theme_constant_override("margin_right", 8)
	margins.add_theme_constant_override("margin_top", 8)
	margins.add_theme_constant_override("margin_bottom", 8)
	_gesture_overlay.add_child(margins)

	var panel := PanelContainer.new()
	panel.name = "GestureOverlayPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_surface(panel, true)
	margins.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "GestureOverlayContent"
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var header := HBoxContainer.new()
	var title_text := "QUICK SETTINGS" if mode == "control_center" else ("NOTIFICATIONS" if mode == "notifications" else "RECENT APPS")
	var title := _label(title_text, 12, _text_color())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseGestureOverlayButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(28, 28)
	_style_action_button(close_button)
	close_button.pressed.connect(_close_gesture_overlay)
	header.add_child(close_button)
	content.add_child(header)

	match mode:
		"control_center":
			_build_gesture_control_center(content)
		"notifications":
			_build_gesture_notifications(content)
		"recent_apps":
			_build_gesture_recent_apps(content)


func _build_gesture_control_center(parent: VBoxContainer) -> void:
	var subtitle := _label("Manage connections and device controls", 8, _muted_color())
	parent.add_child(subtitle)
	var grid := GridContainer.new()
	grid.name = "GestureQuickSettingsGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var items := [
		["Wi-Fi", "◉", true], ["Bluetooth", "ᛒ", true],
		["Mobile data", "▥", true], ["Airplane mode", "✈", false],
		["Flashlight", "☼", false], ["Location", "⌖", true],
		["Do not disturb", "◐", false], ["Battery saver", "▰", false],
		["Auto-rotate", "⟳", true], ["Hotspot", "⌁", false],
		["NFC", "◈", false], ["Nearby Share", "↗", false]
	]
	for item in items:
		var tile := Button.new()
		tile.name = "GestureQuickTile_" + str(item[0]).replace(" ", "")
		tile.text = str(item[1]) + "  " + str(item[0])
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tile.toggle_mode = true
		tile.button_pressed = bool(item[2])
		tile.custom_minimum_size.y = 40
		_style_action_button(tile, tile.button_pressed)
		tile.toggled.connect(func(enabled: bool) -> void: _style_action_button(tile, enabled))
		grid.add_child(tile)
	var media := PanelContainer.new()
	media.name = "GestureMediaCard"
	_style_surface(media, true)
	var media_row := HBoxContainer.new()
	media.add_child(media_row)
	var media_text := VBoxContainer.new()
	media_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media_text.add_child(_label("NOW PLAYING", 7, _accent_color()))
	media_text.add_child(_label("No media playing", 8, _text_color()))
	media_row.add_child(media_text)
	media_row.add_child(_label("◀   ▶   ▷", 10, _text_color()))
	parent.add_child(media)
	_add_gesture_slider(parent, "Brightness", 72)
	_add_gesture_slider(parent, "Volume", 58)

func _add_gesture_slider(parent: VBoxContainer, caption: String, initial_value: float) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.add_child(_label(caption, 8, _muted_color()))
	var slider := HSlider.new()
	slider.name = "Gesture" + caption.replace(" ", "") + "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_value
	slider.custom_minimum_size.y = 18
	row.add_child(slider)
	parent.add_child(row)


func _build_gesture_notifications(parent: VBoxContainer) -> void:
	for item in [
		{"app": "Messages", "message": "A new message is waiting", "time": "NOW"},
		{"app": "Calendar", "message": "Your next event is coming up", "time": "10 MIN"},
		{"app": "System", "message": "Your device is up to date", "time": "EARLIER"}
	]:
		var notification_panel := PanelContainer.new()
		notification_panel.name = "GestureNotification_" + str(item["app"])
		_style_surface(notification_panel)
		var body := VBoxContainer.new()
		body.add_child(_label(str(item["app"]) + "  ·  " + str(item["time"]), 8, _accent_color()))
		body.add_child(_label(str(item["message"]), 9, _text_color()))
		notification_panel.add_child(body)
		parent.add_child(notification_panel)


func _build_gesture_recent_apps(parent: VBoxContainer) -> void:
	if _recent_app_names.is_empty() and not _last_opened_app.is_empty():
		_recent_app_names.append(_last_opened_app)
	if _recent_app_names.is_empty():
		parent.add_child(_label("No recently opened apps", 9, _muted_color()))
		return
	for app_name in _recent_app_names:
		var app := _find_app(app_name)
		if app.is_empty():
			continue
		var card := PanelContainer.new()
		card.name = "GestureRecentApp_" + app_name.replace(" ", "")
		_style_surface(card)
		var row := HBoxContainer.new()
		row.add_child(_create_app_icon(app, 28, false))
		var name_label := _label(app_name, 9, _text_color())
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var open_button := Button.new()
		open_button.text = "OPEN"
		_style_action_button(open_button)
		open_button.pressed.connect(func() -> void:
			_close_gesture_overlay()
			_on_app_pressed(app_name)
		)
		row.add_child(open_button)
		card.add_child(row)
		parent.add_child(card)
	var clear_button := Button.new()
	clear_button.name = "ClearGestureRecentAppsButton"
	clear_button.text = "CLEAR ALL"
	_style_action_button(clear_button)
	clear_button.pressed.connect(func() -> void:
		_recent_app_names.clear()
		_show_gesture_overlay("recent_apps")
	)
	parent.add_child(clear_button)


func _close_gesture_overlay() -> void:
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		_gesture_overlay.queue_free()
	_gesture_overlay = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_simulator_resized)
	if configuration.is_empty():
		configuration = OSEngine.generate_os()
	_build_shell()
	_last_layout_size = size

func _on_simulator_resized() -> void:
	if not is_inside_tree() or size.x < 48.0 or size.y < 48.0:
		return
	if _last_layout_size == Vector2.ZERO:
		_last_layout_size = size
		return
	if size.distance_to(_last_layout_size) < 4.0:
		return
	_last_layout_size = size
	if _resize_rebuild_pending:
		return
	_resize_rebuild_pending = true
	call_deferred("_rebuild_after_resize")

func _rebuild_after_resize() -> void:
	_resize_rebuild_pending = false
	if is_inside_tree():
		_build_shell()

func configure_os(os_configuration: Dictionary, component_id: String = "home_screen") -> void:
	configuration = OSEngine.normalize_os(os_configuration)
	active_component = _safe_component_id(component_id)
	if is_inside_tree():
		_build_shell()

func set_component_view(component_id: String) -> void:
	active_component = _safe_component_id(component_id)
	if is_inside_tree():
		_build_shell()

func update_configuration(os_configuration: Dictionary) -> void:
	configuration = OSEngine.normalize_os(os_configuration)
	if is_inside_tree():
		_build_shell()

func _safe_component_id(component_id: String) -> String:
	for component in OSEngine.COMPONENTS:
		if str(component["id"]) == component_id:
			return component_id
	return "home_screen"

func _build_shell() -> void:
	if _building:
		return
	_building = true
	for child in get_children():
		remove_child(child)
		child.free()

	_style = configuration.get("style", {})
	_palette = _style.get("palette", {"background":"#0B1017","surface":"#19232E","surface_alt":"#263544","accent":"#76C8D4","text":"#F4F7F8","muted":"#A7B4BD"})
	var wallpaper := OSWallpaperLayer.new()
	wallpaper.name = "OSProceduralWallpaper"
	wallpaper.palette = _palette.duplicate(true)
	wallpaper.wallpaper_id = str(_style.get("wallpaper", "aurora"))
	wallpaper.treatment = str(configuration.get("components", {}).get("wallpapers", {}).get("treatment", "natural"))
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wallpaper)

	var safe_area := MarginContainer.new()
	safe_area.name = "OSSimulatorSafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 12)
	safe_area.add_theme_constant_override("margin_right", 12)
	safe_area.add_theme_constant_override("margin_top", 7)
	safe_area.add_theme_constant_override("margin_bottom", 7)
	add_child(safe_area)

	if active_component == "lock_screen":
		var lock_shell := VBoxContainer.new()
		lock_shell.name = "OSLockScreenShell"
		lock_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lock_shell.add_theme_constant_override("separation", 3)
		safe_area.add_child(lock_shell)

		# The system status bar is part of the lock screen, not only Home.
		_build_status_bar(lock_shell)

		page_container = VBoxContainer.new()
		page_container.name = "OSComponentContent"
		page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page_container.add_theme_constant_override("separation", 4)
		lock_shell.add_child(page_container)
		_build_component(active_component)
		_building = false
		return

	var shell := VBoxContainer.new()
	shell.name = "OSSimulatorLayout"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 6)
	safe_area.add_child(shell)

	_build_status_bar(shell)

	var scroll := ScrollContainer.new()
	scroll.name = "OSComponentViewport"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	shell.add_child(scroll)

	page_container = VBoxContainer.new()
	page_container.name = "OSComponentContent"
	page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_theme_constant_override("separation", int(_style.get("spacing", 10)))
	scroll.add_child(page_container)
	_build_component(active_component)

	var footer := VBoxContainer.new()
	footer.name = "OSNavigationFooter"
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 4)
	if active_component == "home_screen":
		var home_layout := str(configuration.get("components", {}).get("home_screen", {}).get("layout_style", "ios_grid"))
		if home_layout != "windows_tiles":
			_build_home_dock(footer)
	var indicator_alignment := CenterContainer.new()
	indicator_alignment.name = "OSNavigationIndicatorArea"
	indicator_alignment.custom_minimum_size = Vector2(0, 9)
	var indicator := ColorRect.new()
	indicator.name = "OSNavigationIndicator"
	indicator.custom_minimum_size = Vector2(34, 4)
	indicator.color = _text_color()
	indicator_alignment.add_child(indicator)
	footer.add_child(indicator_alignment)
	shell.add_child(footer)
	_building = false

func _build_home_dock(parent: VBoxContainer) -> void:
	var dock := PanelContainer.new()
	dock.name = "HomeAppDock"
	dock.custom_minimum_size.y = 48
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(dock, true)
	var dock_row := HBoxContainer.new()
	dock_row.name = "HomeAppDockIcons"
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_row.add_theme_constant_override("separation", 6)
	dock.add_child(dock_row)
	var dock_apps := ["Phone", "Messages", "Browser", "Camera"]
	var dock_icon_size := _responsive_icon_size(35, dock_apps.size(), 6)
	for app_name in dock_apps:
		var app := _find_app(app_name)
		if not app.is_empty():
			dock_row.add_child(_create_app_icon(app, dock_icon_size, false))
	parent.add_child(dock)


func _build_status_bar(parent: VBoxContainer) -> void:
	var bar := PanelContainer.new()
	bar.name = "OSStatusBar"
	bar.custom_minimum_size.y = 22
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.56)
	bar_style.border_color = Color(_text_color().r, _text_color().g, _text_color().b, 0.10)
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(8)
	bar_style.content_margin_left = 7
	bar_style.content_margin_right = 7
	bar_style.content_margin_top = 2
	bar_style.content_margin_bottom = 2
	bar.add_theme_stylebox_override("panel", bar_style)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	var clock := _label(_current_lock_time(), 8, _text_color())
	clock.name = "StatusBarClock"
	clock.custom_minimum_size = Vector2(32, 13)
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(clock)
	var notification_dot := _label("●", 5, _text_color())
	notification_dot.name = "StatusBarNotificationIndicator"
	notification_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(notification_dot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var indicators := OSStatusIndicators.new()
	indicators.name = "StatusBarSystemIndicators"
	row.add_child(indicators)
	status_label = _label("", 1, _text_color())
	status_label.name = "StatusBarBattery"
	status_label.visible = false
	parent.add_child(bar)

func _build_component(component_id: String) -> void:
	var components: Dictionary = configuration.get("components", {})
	var component_data: Dictionary = components.get(component_id, {})
	match component_id:
		"home_screen":
			_build_home_screen(component_data)
		"lock_screen":
			_build_lock_screen(component_data)
		"app_icons":
			_build_icon_gallery(component_data)
		"themes_appearance":
			_build_theme_preview(component_data)
		"wallpapers":
			_build_wallpaper_preview(component_data)
		"animations_transitions":
			_build_animation_preview(component_data)
		"control_center":
			_build_control_center(component_data)
		"notifications":
			_build_notifications(component_data)
		"navigation_gestures":
			_build_navigation_preview(component_data)
		"app_drawer":
			_build_app_drawer(component_data)
		"recent_apps":
			_build_recent_apps(component_data)
		"system_ui":
			_build_system_ui(component_data)

func _build_home_screen(data: Dictionary) -> void:
	var layout_style := str(data.get("layout_style", "ios_grid"))
	var widget_count := clampi(int(_style.get("widget_count", data.get("widget_count", 0))), 0, 4)
	match layout_style:
		"android_pixel":
			_build_android_home(data, widget_count)
		"samsung_one_ui":
			_build_home_header("Good evening", "Your phone, arranged for easy reach")
			_build_home_widgets(widget_count)
			_add_section_label("APPS")
			_build_home_grid(data)
		"windows_tiles":
			_build_home_header("Start", "Pinned apps and live information")
			_build_home_widgets(widget_count)
			_add_section_label("PINNED")
			_build_windows_tiles()
		"compact_list":
			_build_home_header("Applications", "A focused, space-efficient home")
			_build_home_widgets(widget_count)
			page_container.add_child(_search_field("Find an app"))
			_build_home_list()
		"category_sections":
			_build_home_header("Your apps", "Organised by what you do")
			_build_home_widgets(widget_count)
			_build_home_categories(data)
		_:
			_build_home_widgets(widget_count)
			if bool(data.get("show_search", true)):
				page_container.add_child(_search_field("Search apps and more"))
			_add_section_label("YOUR APPS")
			_build_home_grid(data)


func _build_android_home(data: Dictionary, widget_count: int) -> void:
	var hero := PanelContainer.new()
	hero.name = "AndroidAtAGlanceWidget"
	hero.custom_minimum_size.y = 86
	_style_surface(hero, true)
	var hero_content := VBoxContainer.new()
	hero_content.add_theme_constant_override("separation", 1)
	hero.add_child(hero_content)
	hero_content.add_child(_label("MONDAY, NOVEMBER 14", 7, _muted_color()))
	var clock := _label("09:41", 29, _text_color())
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_content.add_child(clock)
	var date := _label("28°  ·  Partly cloudy  ·  Yenagoa", 8, _muted_color())
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_content.add_child(date)
	page_container.add_child(hero)
	for widget_index in range(widget_count):
		_build_home_widget(widget_index)
	var search := _search_field("Search your phone")
	search.name = "AndroidHomeSearch"
	page_container.add_child(search)
	var apps_header := HBoxContainer.new()
	apps_header.add_child(_label("FAVOURITES", 8, _accent_color()))
	var manage := _label("APP DRAWER  ›", 7, _muted_color())
	manage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	apps_header.add_child(manage)
	page_container.add_child(apps_header)
	var breathing_space := Control.new()
	breathing_space.name = "AndroidHomeFlexibleSpace"
	breathing_space.custom_minimum_size.y = 14
	breathing_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(breathing_space)
	_build_android_favourites(data)

func _build_home_header(title_text: String, subtitle_text: String) -> void:
	var header := VBoxContainer.new()
	header.name = "HomeLayoutHeader"
	header.add_theme_constant_override("separation", 1)
	var title := _label(title_text, 18, _text_color())
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var subtitle := _label(subtitle_text, 7, _muted_color())
	header.add_child(subtitle)
	page_container.add_child(header)


func _build_home_widgets(widget_count: int) -> void:
	for widget_index in range(widget_count):
		_build_home_widget(widget_index)


func _build_home_grid(data: Dictionary) -> void:
	var preferred_columns := clampi(int(data.get("columns", _style.get("grid_columns", 4))), 2, 6)
	var columns := _responsive_columns(preferred_columns)
	var apps_grid := GridContainer.new()
	apps_grid.name = "HomeAppGrid"
	apps_grid.columns = columns
	apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_grid.add_theme_constant_override("h_separation", 7)
	apps_grid.add_theme_constant_override("v_separation", 9)
	page_container.add_child(apps_grid)
	_populate_app_grid(apps_grid, "", int(configuration.get("style", {}).get("icon_size", 52)), true)


func _build_android_favourites(data: Dictionary) -> void:
	var columns := _responsive_columns(clampi(int(data.get("columns", _style.get("grid_columns", 4))), 3, 5))
	var grid := GridContainer.new()
	grid.name = "HomeAppGrid"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	page_container.add_child(grid)
	var icon_size := _responsive_icon_size(int(_style.get("icon_size", 52)), columns, 8)
	for app_index in range(mini(16, OSEngine.APP_DEFINITIONS.size())):
		grid.add_child(_create_app_icon(OSEngine.APP_DEFINITIONS[app_index], icon_size, true))


func _build_windows_tiles() -> void:
	var tiles := GridContainer.new()
	tiles.name = "WindowsLiveTileGrid"
	tiles.columns = _responsive_columns(3)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("h_separation", 5)
	tiles.add_theme_constant_override("v_separation", 5)
	page_container.add_child(tiles)
	for app in OSEngine.APP_DEFINITIONS:
		var tile := Button.new()
		tile.name = "LiveTile_" + str(app.get("name", "App")).replace(" ", "")
		tile.custom_minimum_size = Vector2(48, 54)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.text = str(app.get("glyph", "•")) + "\n" + str(app.get("name", "App"))
		tile.add_theme_font_size_override("font_size", 9)
		_style_icon_button(tile, Color(str(app.get("color", "#687987"))), "square")
		tile.pressed.connect(_on_app_pressed.bind(str(app.get("name", "App"))))
		tiles.add_child(tile)


func _build_home_list() -> void:
	var app_list := VBoxContainer.new()
	app_list.name = "HomeAppList"
	app_list.add_theme_constant_override("separation", 4)
	app_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_child(app_list)
	for app in OSEngine.APP_DEFINITIONS:
		var app_name := str(app.get("name", "App"))
		var row := HBoxContainer.new()
		row.name = "HomeListRow_" + app_name.replace(" ", "")
		row.custom_minimum_size.y = 35
		row.add_theme_constant_override("separation", 9)
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.text = str(app.get("glyph", "•"))
		_style_icon_button(icon, Color(str(app.get("color", "#687987"))), "square")
		icon.pressed.connect(_on_app_pressed.bind(app_name))
		row.add_child(icon)
		var label := _label(app_name, 9, _text_color())
		row.add_child(label)
		var open_button := Button.new()
		open_button.text = "›"
		open_button.custom_minimum_size = Vector2(24, 28)
		_style_action_button(open_button)
		open_button.pressed.connect(_on_app_pressed.bind(app_name))
		row.add_child(open_button)
		app_list.add_child(row)


func _build_home_categories(data: Dictionary) -> void:
	var groups := {
		"COMMUNICATION": ["Phone", "Messages"],
		"MEDIA": ["Camera", "Gallery", "Music"],
		"PRODUCTIVITY": ["Calendar", "Files", "Notes", "Clock"],
		"DISCOVER": ["Browser", "Maps", "Settings"]
	}
	for group_name in groups:
		_add_section_label(group_name)
		var group_grid := GridContainer.new()
		group_grid.name = "HomeCategory_" + group_name.replace(" ", "") + "Grid"
		group_grid.columns = _responsive_columns(int(data.get("columns", _style.get("grid_columns", 4))))
		group_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_grid.add_theme_constant_override("h_separation", 7)
		group_grid.add_theme_constant_override("v_separation", 8)
		page_container.add_child(group_grid)
		for app_name in groups[group_name]:
			var app := _find_app(app_name)
			if not app.is_empty():
				group_grid.add_child(_create_app_icon(app, _responsive_icon_size(int(_style.get("icon_size", 52)), group_grid.columns), true))


func _build_home_widget(widget_index: int) -> void:
	var widget_names := ["Clock", "Weather", "Calendar", "Music"]
	var widget := PanelContainer.new()
	widget.name = "HomeWidget_" + widget_names[widget_index]
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget.custom_minimum_size.y = 66 if widget_index != 0 else 72
	_style_surface(widget, true)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	widget.add_child(content)
	match widget_index:
		0:
			content.add_child(_label("CLOCK  ·  WORLD TIME", 7, _accent_color()))
			var time := _label("09:41", 25, _text_color())
			time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(time)
			var day := _label("MON  ·  NOVEMBER 14", 7, _muted_color())
			day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(day)
		1:
			content.add_child(_label("WEATHER", 7, _accent_color()))
			var weather_row := HBoxContainer.new()
			weather_row.add_child(_label("☀", 23, _text_color()))
			var weather_text := VBoxContainer.new()
			weather_text.add_child(_label("28°  Partly cloudy", 12, _text_color()))
			weather_text.add_child(_label("Feels like 31°  ·  H:30° L:24°", 7, _muted_color()))
			weather_row.add_child(weather_text)
			content.add_child(weather_row)
		2:
			content.add_child(_label("UP NEXT  ·  CALENDAR", 7, _accent_color()))
			content.add_child(_label("14  MONDAY", 18, _text_color()))
			content.add_child(_label("Team meeting  ·  10:30 AM", 8, _muted_color()))
		3:
			content.add_child(_label("NOW PLAYING", 7, _accent_color()))
			var music_row := HBoxContainer.new()
			music_row.add_child(_label("♫", 23, _text_color()))
			var music_text := VBoxContainer.new()
			music_text.add_child(_label("Your soundtrack", 10, _text_color()))
			music_text.add_child(_label("No track currently playing", 7, _muted_color()))
			music_row.add_child(music_text)
			content.add_child(music_row)
	page_container.add_child(widget)

func _build_lock_screen(data: Dictionary) -> void:
	var template := str(data.get("layout_template", "classic_clock"))
	if not OSEngine.LOCK_SCREEN_LAYOUT_TEMPLATES.has(template):
		template = "classic_clock"
	var family := str(data.get("design_family", "minimal"))
	var original_container := page_container
	var bank := VBoxContainer.new()
	bank.name = "LockScreenComponentBank"
	page_container = bank
	if bool(data.get("show_notifications", true)):
		_add_lock_notification("Messages", "A new message is waiting", "NOW", str(data.get("notification_treatment", "glass")), 0)
		_add_lock_notification("Calendar", "Your next event is coming up", "IN 10 MIN", str(data.get("notification_treatment", "glass")), 1)
	if bool(data.get("show_audio_player", true)):
		_add_lock_audio_player(str(data.get("audio_treatment", "album_card")))
	page_container = original_container

	var root_layout := VBoxContainer.new()
	root_layout.name = "LockScreenLayout_" + template
	root_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_theme_constant_override("separation", maxi(3, int(float(_style.get("spacing", 10)) * 0.5)))
	page_container.add_child(root_layout)

	var clock_stack := VBoxContainer.new()
	clock_stack.name = "LockScreenClockStack"
	clock_stack.add_theme_constant_override("separation", 1)
	var alignment := HORIZONTAL_ALIGNMENT_CENTER
	match str(data.get("clock_alignment", "center")):
		"left":
			alignment = HORIZONTAL_ALIGNMENT_LEFT
		"right":
			alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var configured_clock_size := clampi(int(data.get("clock_size", 46)), 30, 58)
	if size.x <= 180.0:
		configured_clock_size = mini(configured_clock_size, 36)
	if template == "pixel_large_clock" or str(data.get("clock_treatment", "")) == "oversized":
		configured_clock_size = mini(58, configured_clock_size + 6)
	var clock := _label(_current_lock_time(family), configured_clock_size, _text_color())
	clock.name = "LockScreenClock"
	clock.horizontal_alignment = alignment
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock.clip_contents = false
	clock.custom_minimum_size = Vector2(0, configured_clock_size + 5)
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	clock_stack.custom_minimum_size.y = configured_clock_size + 19
	clock_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_stack.clip_contents = false
	var clock_font := FontVariation.new()
	clock_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	clock_font.variation_embolden = 1.1 if template in ["coloros_typography", "neo_brutalist"] else 0.55
	clock.add_theme_font_override("font", clock_font)
	clock_stack.add_child(clock)
	var date := _label(_current_lock_date(str(data.get("date_treatment", "uppercase"))), 8, _muted_color())
	date.name = "LockScreenDate"
	date.horizontal_alignment = alignment
	date.custom_minimum_size.y = 12
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock_stack.add_child(date)
	var clock_stage := CenterContainer.new()
	clock_stage.name = "LockScreenProtectedClockStage"
	clock_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_stage.custom_minimum_size.y = configured_clock_size + 34
	clock_stage.clip_contents = false
	clock_stage.add_child(clock_stack)
	root_layout.add_child(clock_stage)

	var notifications := VBoxContainer.new()
	notifications.name = "LockScreenNotificationZone"
	notifications.add_theme_constant_override("separation", 5)
	for notification_name in ["LockScreenNotification_Messages", "LockScreenNotification_Calendar"]:
		_lock_screen_move(bank, notification_name, notifications)
	var media := bank.get_node_or_null("LockScreenAudioPlayer") as Control
	if is_instance_valid(media):
		bank.remove_child(media)
	var shortcuts := HBoxContainer.new()
	shortcuts.name = "LockScreenQuickShortcuts"
	shortcuts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.add_theme_constant_override("separation", 8)
	if bool(data.get("show_camera_shortcut", true)):
		shortcuts.add_child(_make_lock_shortcut("◉", "CAMERA", str(data.get("shortcut_treatment", "floating")), "Camera"))
	var shortcut_spacer := Control.new()
	shortcut_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.add_child(shortcut_spacer)
	if bool(data.get("show_flashlight_shortcut", true)):
		shortcuts.add_child(_make_lock_shortcut("ϟ", "FLASH", str(data.get("shortcut_treatment", "floating")), "Flashlight"))

	var fingerprint: Control
	if bool(data.get("show_fingerprint", false)) and bool(data.get("fingerprint_sensor_available", false)):
		var sensor := LockScreenFingerprintButton.new()
		sensor.name = "LockScreenFingerprintSensor"
		sensor.tooltip_text = "Touch to unlock"
		sensor.pressed.connect(func(): set_component_view("home_screen"))
		fingerprint = sensor
	var unlock_control: Button
	if bool(data.get("show_unlock_hint", true)):
		unlock_control = Button.new()
		unlock_control.name = "UnlockOSButton"
		unlock_control.text = "SWIPE UP TO UNLOCK" if str(data.get("unlock_treatment", "pill")) != "text_link" else "SWIPE UP  →"
		unlock_control.custom_minimum_size.y = 22
		_style_lock_button(unlock_control, str(data.get("unlock_treatment", "pill")))
		unlock_control.pressed.connect(func(): set_component_view("home_screen"))

	var top_space := Control.new()
	top_space.name = "LockScreenTopFlexibleSpace"
	top_space.custom_minimum_size.y = 4
	# A top spacer must never consume the clock's visible area on compact previews.
	var lower_space := Control.new()
	lower_space.name = "LockScreenBottomFlexibleSpace"
	lower_space.custom_minimum_size.y = 4

	var feature_row := VBoxContainer.new()
	feature_row.name = "LockScreenMediaAndNotifications"
	feature_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature_row.add_theme_constant_override("separation", 5)
	var notification_column := VBoxContainer.new()
	notification_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notification_column.add_theme_constant_override("separation", 4)
	var media_column := VBoxContainer.new()
	media_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feature_row.add_child(notification_column)
	feature_row.add_child(media_column)
	# Clock is rendered in a dedicated protected stage above every template.

	match template:
		"classic_clock":
			root_layout.add_child(top_space)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"rhombus_clock":
			root_layout.add_child(top_space)
			root_layout.add_child(_label("TODAY  ·  DIGITALWORLD", 7, _accent_color()))
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"magazine_cover":
			root_layout.add_child(top_space)
			root_layout.add_child(_label("THE DAILY EDITION  /  DIGITALWORLD", 7, _accent_color()))
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
		"depth_layer":
			root_layout.add_child(top_space)
			root_layout.add_child(lower_space)
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
		"widget_dashboard":
			if notifications.get_child_count() > 0:
				notification_column.add_child(notifications)
			if is_instance_valid(media):
				media_column.add_child(media)
			root_layout.add_child(feature_row)
		"live_activity":
			root_layout.add_child(top_space)
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
		"one_ui_personal":
			var personal_zones := VBoxContainer.new()
			personal_zones.name = "OneUIPersonalContentZones"
			var personal_left := VBoxContainer.new()
			personal_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			personal_left.add_child(notifications)
			var personal_right := VBoxContainer.new()
			personal_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if is_instance_valid(media): personal_right.add_child(media)
			personal_zones.add_child(personal_left)
			personal_zones.add_child(personal_right)
			root_layout.add_child(top_space)
			root_layout.add_child(personal_zones)
		"now_bar":
			var now_bar := VBoxContainer.new()
			now_bar.name = "LockScreenNowBar"
			if is_instance_valid(media): now_bar.add_child(media)
			if notifications.get_child_count() > 0: now_bar.add_child(notifications)
			root_layout.add_child(now_bar)
		"notification_stack":
			root_layout.add_child(lower_space)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"pixel_at_a_glance":
			root_layout.add_child(_label("AT A GLANCE  ·  YOUR DAY", 7, _accent_color()))
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"pixel_large_clock":
			var large_clock_stage := CenterContainer.new()
			large_clock_stage.name = "PixelLargeClockStage"
			large_clock_stage.custom_minimum_size.y = configured_clock_size + 22
			large_clock_stage.add_child(clock_stack)
			root_layout.add_child(top_space)
			root_layout.add_child(large_clock_stage)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"pixel_ambient":
			root_layout.add_child(top_space)
			root_layout.add_child(lower_space)
			root_layout.add_child(_label("MON  ·  DIGITALWORLD", 7, _muted_color()))
		"huawei_magazine":
			root_layout.add_child(top_space)
			root_layout.add_child(_label("MONDAY  /  YOUR PERSONAL EDITION", 7, _accent_color()))
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"huawei_dynamic":
			var dynamic_row := VBoxContainer.new()
			dynamic_row.name = "HuaweiDynamicActivity"
			if is_instance_valid(media): dynamic_row.add_child(media)
			root_layout.add_child(top_space)
			root_layout.add_child(dynamic_row)
			root_layout.add_child(notifications)
		"nothing_widget_grid":
			var widget_grid := GridContainer.new()
			widget_grid.name = "LockScreenNothingWidgetGrid"
			widget_grid.columns = 1 if size.x <= 180.0 else 2
			widget_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			widget_grid.add_child(_label("MON  /  DATE", 8, _muted_color()))
			if notifications.get_child_count() > 0: widget_grid.add_child(notifications)
			if is_instance_valid(media): widget_grid.add_child(media)
			root_layout.add_child(top_space)
			root_layout.add_child(widget_grid)
		"origin_player":
			root_layout.add_child(top_space)
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
		"coloros_typography":
			root_layout.add_child(top_space)
			var typography_rule := ColorRect.new()
			typography_rule.custom_minimum_size.y = 3
			typography_rule.color = _accent_color()
			root_layout.add_child(typography_rule)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"coloros_flux":
			var flux_column := VBoxContainer.new()
			flux_column.add_child(clock_stack)
			if is_instance_valid(media): flux_column.add_child(media)
			root_layout.add_child(top_space)
			root_layout.add_child(flux_column)
			root_layout.add_child(notifications)
		"clean_android":
			if notifications.get_child_count() > 0: root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(lower_space)
		"focus_lock_screen":
			root_layout.add_child(_label("FOCUS  /  PERSONAL", 7, _accent_color()))
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
			root_layout.add_child(lower_space)

	# Some intentionally minimal templates omit widgets from their composition.
	# Keep enabled notifications and media visible rather than silently dropping them.
	if notifications.get_child_count() > 0 and notifications.get_parent() == null:
		root_layout.add_child(notifications)
	if is_instance_valid(media) and media.get_parent() == null:
		root_layout.add_child(media)
	if lower_space.get_parent() == null:
		root_layout.add_child(lower_space)
	if is_instance_valid(fingerprint):
		var fingerprint_stage := CenterContainer.new()
		fingerprint_stage.name = "LockScreenFingerprintStage"
		fingerprint_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fingerprint_stage.custom_minimum_size.y = 56
		fingerprint_stage.add_child(fingerprint)
		root_layout.add_child(fingerprint_stage)
	root_layout.add_child(shortcuts)
	if is_instance_valid(unlock_control):
		root_layout.add_child(unlock_control)
	page_container = original_container


func _lock_screen_move(source: Control, node_name: String, destination: Control) -> void:
	var item := source.get_node_or_null(node_name) as Control
	if is_instance_valid(item):
		source.remove_child(item)
		destination.add_child(item)


func _add_lock_notification(app_name: String, message: String, time_label: String, treatment: String, _index: int) -> void:
	var card := PanelContainer.new()
	card.name = "LockScreenNotification_" + app_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	match treatment:
		"glass":
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.44)
			style.border_color = Color(1, 1, 1, 0.20)
			style.set_corner_radius_all(15)
			style.set_border_width_all(1)
		"solid":
			style.bg_color = _surface_color().darkened(0.18)
			style.border_color = _accent_color()
			style.set_corner_radius_all(4)
			style.set_border_width_all(1)
		"outline":
			style.bg_color = Color(0, 0, 0, 0.12)
			style.border_color = _accent_color()
			style.set_corner_radius_all(12)
			style.set_border_width_all(1)
		"minimal":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(1, 1, 1, 0.16)
			style.set_corner_radius_all(0)
			style.set_border_width_all(0)
			style.border_width_bottom = 1
		_:
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.76)
			style.border_color = Color(1, 1, 1, 0.12)
			style.set_corner_radius_all(7)
			style.set_border_width_all(1)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.y = 44
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 34
	row.add_theme_constant_override("separation", 7)
	var app_icon := PanelContainer.new()
	app_icon.custom_minimum_size = Vector2(30, 30)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = _accent_color().darkened(0.42)
	icon_style.set_corner_radius_all(9)
	app_icon.add_theme_stylebox_override("panel", icon_style)
	var icon_label := _label("✉" if app_name == "Messages" else "▦", 16, _text_color())
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(28, 28)
	app_icon.add_child(icon_label)
	row.add_child(app_icon)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 29)
	body.add_theme_constant_override("separation", 1)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var app_label := _label(app_name, 10, _text_color())
	app_label.name = "LockScreenNotificationApp_" + app_name
	app_label.custom_minimum_size.y = 12
	app_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(app_label)
	var time_label_control := _label(time_label, 7, _muted_color())
	time_label_control.custom_minimum_size.y = 12
	header.add_child(time_label_control)
	body.add_child(header)
	var message_label := _label(message, 9, _text_color())
	message_label.name = "LockScreenNotificationMessage_" + app_name
	message_label.custom_minimum_size.y = 12
	body.add_child(message_label)
	row.add_child(body)
	card.add_child(row)
	page_container.add_child(card)


func _add_lock_audio_player(treatment: String) -> void:
	var player := PanelContainer.new()
	player.name = "LockScreenAudioPlayer"
	player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	match treatment:
		"glass_bar":
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.40)
			style.border_color = Color(1, 1, 1, 0.24)
			style.set_corner_radius_all(22)
			style.set_border_width_all(1)
		"compact_row":
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.84)
			style.border_color = _accent_color()
			style.set_corner_radius_all(5)
			style.set_border_width_all(1)
		"editorial":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.55)
			style.set_corner_radius_all(0)
			style.set_border_width_all(0)
			style.border_width_bottom = 1
		_:
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.78)
			style.border_color = Color(1, 1, 1, 0.16)
			style.set_corner_radius_all(13)
			style.set_border_width_all(1)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	player.add_theme_stylebox_override("panel", style)

	player.custom_minimum_size.y = 62
	var player_content := VBoxContainer.new()
	player_content.custom_minimum_size.y = 62
	player_content.add_theme_constant_override("separation", 3)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var artwork := PanelContainer.new()
	artwork.name = "LockScreenAudioArtwork"
	artwork.custom_minimum_size = Vector2(32, 32)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = _accent_color().darkened(0.35)
	art_style.set_corner_radius_all(7 if treatment == "compact_row" else 12)
	artwork.add_theme_stylebox_override("panel", art_style)
	var art_label := _label("♫", 21, _text_color())
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.custom_minimum_size = Vector2(34, 34)
	artwork.add_child(art_label)
	row.add_child(artwork)
	var track := VBoxContainer.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size.x = 0
	track.add_theme_constant_override("separation", 0)
	var now_playing := _label("NOW PLAYING", 7, _accent_color())
	now_playing.name = "LockScreenAudioEyebrow"
	now_playing.custom_minimum_size.y = 10
	track.add_child(now_playing)
	var track_title := _label("Midnight Drive", 10, _text_color())
	track_title.name = "LockScreenAudioTrackTitle"
	track_title.custom_minimum_size.y = 13
	track.add_child(track_title)
	var artist_name := _label("DigitalWorld Audio", 8, _muted_color())
	artist_name.name = "LockScreenAudioArtist"
	artist_name.custom_minimum_size.y = 12
	track.add_child(artist_name)
	row.add_child(track)
	var play := Button.new()
	play.name = "LockScreenAudioPlayButton"
	play.text = "Ⅱ"
	play.custom_minimum_size = Vector2(28, 28)
	_style_lock_button(play, "minimal")
	play.pressed.connect(func(): play.text = "▶" if play.text == "Ⅱ" else "Ⅱ")
	row.add_child(play)
	player_content.add_child(row)
	var progress := HBoxContainer.new()
	progress.add_child(_label("1:24", 7, _muted_color()))
	var progress_line := ColorRect.new()
	progress_line.custom_minimum_size = Vector2(0, 3)
	progress_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_line.color = _accent_color()
	progress.add_child(progress_line)
	progress.add_child(_label("3:48", 7, _muted_color()))
	player_content.add_child(progress)
	player.add_child(player_content)
	page_container.add_child(player)


func _make_lock_shortcut(glyph: String, caption: String, treatment: String, action_name: String) -> Button:
	var button := Button.new()
	button.name = "LockScreenShortcut_" + action_name
	button.text = glyph + "\n" + caption
	button.custom_minimum_size = Vector2(44, 42)
	button.add_theme_font_size_override("font_size", 8)
	_style_lock_button(button, treatment)
	if action_name == "Flashlight":
		button.toggle_mode = true
		button.toggled.connect(func(enabled: bool):
			button.text = "ϟ\nON" if enabled else "ϟ\nFLASH"
			if is_instance_valid(status_label):
				status_label.text = "Flashlight " + ("on" if enabled else "off")
		)
	else:
		button.pressed.connect(func():
			if is_instance_valid(status_label):
				status_label.text = "Camera shortcut"
			app_opened.emit("Camera")
		)
	return button


func _style_lock_button(button: Button, treatment: String) -> void:
	var style := StyleBoxFlat.new()
	match treatment:
		"floating", "pill":
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.78)
			style.border_color = Color(1, 1, 1, 0.22)
			style.set_corner_radius_all(24)
			style.set_border_width_all(1)
		"outlined", "ring":
			style.bg_color = Color(0, 0, 0, 0.12)
			style.border_color = _accent_color()
			style.set_corner_radius_all(24)
			style.set_border_width_all(1)
		"solid":
			style.bg_color = _accent_color().darkened(0.22)
			style.border_color = _accent_color()
			style.set_corner_radius_all(8)
			style.set_border_width_all(1)
		"glass":
			style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.38)
			style.border_color = Color(1, 1, 1, 0.30)
			style.set_corner_radius_all(18)
			style.set_border_width_all(1)
		"minimal", "text_link":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.30)
			style.set_corner_radius_all(2)
			style.set_border_width_all(0)
			style.border_width_bottom = 1
		_:
			style.bg_color = _surface_color()
			style.border_color = Color(1, 1, 1, 0.16)
			style.set_corner_radius_all(10)
			style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	button.add_theme_color_override("font_color", _text_color())
	button.add_theme_color_override("font_hover_color", _text_color())
	button.add_theme_font_size_override("font_size", 8)
	button.focus_mode = Control.FOCUS_NONE


func _build_icon_gallery(data: Dictionary) -> void:
	_add_section_label("APP ICON SYSTEM")
	var columns := 3
	var grid := GridContainer.new()
	grid.name = "AppIconGallery"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 10)
	page_container.add_child(grid)
	_populate_app_grid(grid, "", int(data.get("size", 48)), bool(data.get("label_visibility", true)))

func _build_theme_preview(data: Dictionary) -> void:
	_add_section_label(str(data.get("palette", {}).get("name", "Theme")) + " · APPEARANCE")
	var sample := PanelContainer.new()
	sample.name = "ThemeSampleSurface"
	sample.custom_minimum_size.y = 72
	_style_surface(sample, true)
	var sample_content := VBoxContainer.new()
	sample_content.add_theme_constant_override("separation", 3)
	sample.add_child(sample_content)
	sample_content.add_child(_label("A consistent visual language", 11, _text_color()))
	sample_content.add_child(_label("Surface, typography and actions share one palette.", 8, _muted_color()))
	var action := Button.new()
	action.text = "PRIMARY ACTION"
	action.custom_minimum_size.y = 30
	_style_action_button(action, true)
	sample_content.add_child(action)
	page_container.add_child(sample)
	for key in ["background", "surface", "surface_alt", "accent", "text", "muted"]:
		var swatch := HBoxContainer.new()
		swatch.add_theme_constant_override("separation", 9)
		var color_box := PanelContainer.new()
		color_box.custom_minimum_size = Vector2(34, 26)
		var swatch_style := StyleBoxFlat.new()
		swatch_style.bg_color = Color(str(_palette.get(key, "#FFFFFF")))
		swatch_style.set_corner_radius_all(int(_style.get("corner_radius", 0)))
		color_box.add_theme_stylebox_override("panel", swatch_style)
		swatch.add_child(color_box)
		var swatch_label := _label(key.replace("_", " ").capitalize(), 9, _text_color())
		swatch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.add_child(swatch_label)
		swatch.add_child(_label(str(_palette.get(key, "")), 8, _muted_color()))
		page_container.add_child(swatch)

func _build_wallpaper_preview(data: Dictionary) -> void:
	_add_section_label("WALLPAPER COLLECTION")
	var art := OSWallpaperLayer.new()
	art.name = "WallpaperStylePreview"
	art.palette = _palette.duplicate(true)
	art.wallpaper_id = str(data.get("style", data.get("id", "aurora")))
	art.treatment = str(data.get("treatment", "natural"))
	art.custom_minimum_size = Vector2(0, 164)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_child(art)
	var wallpaper_name := _label(art.wallpaper_id.replace("_", " ").capitalize(), 11, _text_color())
	page_container.add_child(wallpaper_name)
	var treatment_name := str(data.get("treatment", "natural")).replace("_", " ").capitalize()
	page_container.add_child(_label("Shared home and lock screen wallpaper  ·  " + treatment_name, 8, _muted_color()))


func _build_animation_preview(data: Dictionary) -> void:
	_add_section_label("MOTION & TRANSITIONS")
	var demo := PanelContainer.new()
	demo.name = "AnimationDemoSurface"
	demo.custom_minimum_size = Vector2(0, 92)
	_style_surface(demo, true)
	var demo_content := CenterContainer.new()
	demo.add_child(demo_content)
	var demo_label := _label("OS WINDOW", 12, _text_color())
	demo_content.add_child(demo_label)
	page_container.add_child(demo)
	var description := _label(str(data.get("style", "fade")).capitalize() + " · " + str(snappedf(float(data.get("duration", 0.24)), 0.01)) + "s", 9, _muted_color())
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_container.add_child(description)
	var play := Button.new()
	play.text = "PREVIEW TRANSITION"
	play.custom_minimum_size.y = 34
	_style_action_button(play, true)
	play.pressed.connect(func():
		var tween := create_tween()
		demo.scale = Vector2(0.92, 0.92)
		demo.modulate.a = 0.45
		tween.set_parallel(true)
		var duration := float(data.get("duration", 0.24))
		tween.tween_property(demo, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(demo, "modulate:a", 1.0, duration)
	)
	page_container.add_child(play)

func _build_control_center(data: Dictionary) -> void:
	_add_section_label("QUICK SETTINGS")
	var layout := str(data.get("tile_layout", "expanded"))
	var grid := GridContainer.new()
	grid.name = "QuickSettingsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	page_container.add_child(grid)
	var toggles := [
		["Wi-Fi", "◉", true], ["Bluetooth", "ᛒ", true],
		["Mobile data", "▥", true], ["Airplane mode", "✈", false],
		["Flashlight", "☼", false], ["Location", "⌖", true],
		["Do not disturb", "◐", false], ["Battery saver", "▰", false],
		["Auto-rotate", "⟳", true], ["Hotspot", "⌁", false],
		["NFC", "◈", false], ["Nearby Share", "↗", false]
	]
	for item in toggles:
		var tile := Button.new()
		tile.name = "QuickTile_" + str(item[0]).replace(" ", "")
		tile.toggle_mode = true
		tile.button_pressed = bool(item[2])
		tile.custom_minimum_size.y = 48 if layout == "expanded" else 39
		tile.text = str(item[1]) + "   " + str(item[0])
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_action_button(tile, tile.button_pressed)
		tile.toggled.connect(func(enabled: bool) -> void: _style_action_button(tile, enabled))
		grid.add_child(tile)
	var media := PanelContainer.new()
	media.name = "ControlCenterMediaCard"
	media.custom_minimum_size.y = 57
	_style_surface(media, true)
	var media_row := HBoxContainer.new()
	media.add_child(media_row)
	var media_info := VBoxContainer.new()
	media_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media_info.add_child(_label("NOW PLAYING", 7, _accent_color()))
	media_info.add_child(_label("No media playing", 9, _text_color()))
	media_row.add_child(media_info)
	media_row.add_child(_label("◀   ▶   ▷", 11, _text_color()))
	page_container.add_child(media)
	_add_control_slider("Brightness", 72, "☼")
	_add_control_slider("Volume", 58, "♫")
	var footer := HBoxContainer.new()
	footer.add_child(_label("Connected  ·  Wi-Fi and mobile network", 7, _muted_color()))
	page_container.add_child(footer)


func _add_control_slider(caption: String, initial_value: float, glyph: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "ControlSlider_" + caption
	_style_surface(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	row.add_child(_label(glyph, 13, _accent_color()))
	var slider_column := VBoxContainer.new()
	slider_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_column.add_child(_label(caption, 7, _muted_color()))
	var slider := HSlider.new()
	slider.name = caption + "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_value
	slider.custom_minimum_size.y = 20
	slider_column.add_child(slider)
	row.add_child(slider_column)
	page_container.add_child(panel)

func _build_notifications(data: Dictionary) -> void:
	_add_section_label("NOTIFICATION PANEL")
	_add_notification_surface("Messages", "A new message is waiting", "NOW")
	_add_notification_surface("Calendar", "Your next event is coming up", "10 MIN")
	_add_notification_surface("System", "Your device is up to date", "EARLIER")
	page_container.add_child(_label("Card style · " + str(data.get("card_style", "grouped")).replace("_", " ").capitalize(), 8, _muted_color()))

func _build_navigation_preview(data: Dictionary) -> void:
	_add_section_label("SYSTEM NAVIGATION")
	page_container.add_child(_surface_label("Navigation mode  ·  " + str(data.get("mode", "gesture")).replace("_", " ").capitalize(), 10))
	if data.get("mode", "gesture") == "three_button":
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 10)
		for caption in ["BACK", "HOME", "RECENTS"]:
			var button := Button.new()
			button.text = caption
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 36
			_style_action_button(button)
			buttons.add_child(button)
		page_container.add_child(buttons)
	else:
		var gesture_area := PanelContainer.new()
		gesture_area.custom_minimum_size.y = 90
		_style_surface(gesture_area, true)
		var gesture_label := _label("Swipe up to go home\nSwipe from an edge to go back", 9, _text_color())
		gesture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gesture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gesture_area.add_child(gesture_label)
		page_container.add_child(gesture_area)
	var indicator := CenterContainer.new()
	indicator.custom_minimum_size.y = 20
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(42 if data.get("indicator_style") == "pill" else 28, 4)
	line.color = _text_color()
	indicator.add_child(line)
	page_container.add_child(indicator)

func _build_app_drawer(data: Dictionary) -> void:
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 6)
	heading_row.add_child(_label("ALL APPS", 10, _accent_color()))
	var count_label := _label("%02d INSTALLED" % OSEngine.APP_DEFINITIONS.size(), 7, _muted_color())
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(count_label)
	page_container.add_child(heading_row)
	var search := _search_field("Search installed apps")
	search.name = "AppDrawerSearchField"
	if str(data.get("search_position", "top")) == "top":
		page_container.add_child(search)
	var layout := str(data.get("layout", "alphabetical"))
	var category_grids: Array[GridContainer] = []
	if layout == "categories":
		var categories := {
			"COMMUNICATION": ["Phone", "Messages", "Contacts", "Email", "Meet"],
			"MEDIA": ["Camera", "Gallery", "Music", "Video", "Podcasts"],
			"PRODUCTIVITY": ["Calendar", "Files", "Notes", "Clock", "Calculator", "Tasks"],
			"GOOGLE & SERVICES": ["Maps", "Browser", "Store", "Weather", "Drive", "Photos"],
			"SYSTEM": ["Settings", "Security", "Device Care", "Downloads", "Recorder", "Compass", "Wallet", "Assistant"]
		}
		for category_name in categories:
			_add_section_label(category_name)
			var category_grid := GridContainer.new()
			category_grid.name = "AppDrawerCategory_" + category_name.replace(" ", "")
			category_grid.set_meta("app_names", categories[category_name])
			category_grids.append(category_grid)
			category_grid.columns = _responsive_columns(int(data.get("columns", _style.get("grid_columns", 4))))
			category_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			category_grid.add_theme_constant_override("h_separation", 7)
			category_grid.add_theme_constant_override("v_separation", 10)
			page_container.add_child(category_grid)
			for app_name in categories[category_name]:
				var app := _find_app(app_name)
				if not app.is_empty():
					category_grid.add_child(_create_app_icon(app, _responsive_icon_size(int(_style.get("icon_size", 52)), category_grid.columns), true))
		search.text_changed.connect(_on_category_app_search_changed.bind(category_grids))
	else:
		var horizontal := str(data.get("scroll_direction", "vertical")) == "horizontal"
		var viewport := ScrollContainer.new()
		viewport.name = "AppDrawerViewport"
		viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
		viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
		viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if horizontal else ScrollContainer.SCROLL_MODE_AUTO
		page_container.add_child(viewport)
		var grid := GridContainer.new()
		grid.name = "AppDrawerGrid"
		grid.columns = OSEngine.APP_DEFINITIONS.size() if horizontal else _responsive_columns(int(data.get("columns", _style.get("grid_columns", 4))))
		grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if horizontal else Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if horizontal else Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 12)
		viewport.add_child(grid)
		_populate_app_grid(grid, "", int(configuration.get("style", {}).get("icon_size", 52)), true)
	if str(data.get("search_position", "top")) == "bottom":
		page_container.add_child(search)
	if layout != "categories":
		var searchable_grid := page_container.find_child("AppDrawerGrid", true, false) as GridContainer
		if searchable_grid != null:
			search.text_changed.connect(_on_app_search_changed.bind(searchable_grid))

func _build_recent_apps(_data: Dictionary) -> void:
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 6)
	var heading := _label("RECENT APPS", 9, _accent_color())
	heading_row.add_child(heading)
	var clear := Button.new()
	clear.name = "ClearRecentAppsButton"
	clear.text = "CLEAR"
	clear.custom_minimum_size = Vector2(56, 27)
	_style_action_button(clear)
	heading_row.add_child(clear)
	page_container.add_child(heading_row)

	var recent_scroll := ScrollContainer.new()
	recent_scroll.name = "RecentAppsViewport"
	recent_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent_scroll.custom_minimum_size.y = 174
	recent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	recent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_container.add_child(recent_scroll)

	var recent_row := HBoxContainer.new()
	recent_row.name = "RecentAppsList"
	recent_row.add_theme_constant_override("separation", 8)
	recent_scroll.add_child(recent_row)

	var empty_state := _label("No recent apps", 8, _muted_color())
	empty_state.name = "NoRecentAppsLabel"
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.custom_minimum_size = Vector2(100, 42)
	var recent_names := ["Settings", "Camera", "Messages"]
	var card_width := clampf(size.x * 0.76, 108.0, 140.0)

	var remove_card := func(card: Control) -> void:
		if is_instance_valid(card) and card.get_parent() == recent_row:
			recent_row.remove_child(card)
			card.queue_free()
		if recent_row.get_child_count() == 0 and empty_state.get_parent() == null:
			recent_row.add_child(empty_state)

	for app_name in recent_names:
		var app := _find_app(app_name)
		if app.is_empty():
			continue
		var card := PanelContainer.new()
		card.name = "RecentAppCard_" + app_name.replace(" ", "")
		card.custom_minimum_size = Vector2(card_width, 158)
		_style_surface(card, true)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		card.add_child(content)

		var card_header := HBoxContainer.new()
		card_header.add_theme_constant_override("separation", 4)
		card_header.add_child(_create_app_icon(app, 22, false))
		var app_title := _label(app_name, 8, _text_color())
		app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_header.add_child(app_title)
		var close := Button.new()
		close.name = "CloseRecentApp_" + app_name.replace(" ", "")
		close.text = "×"
		close.custom_minimum_size = Vector2(20, 20)
		close.add_theme_font_size_override("font_size", 12)
		_style_action_button(close)
		card_header.add_child(close)
		close.pressed.connect(remove_card.bind(card))
		content.add_child(card_header)

		var preview := PanelContainer.new()
		preview.name = "RecentAppPreview_" + app_name.replace(" ", "")
		preview.custom_minimum_size.y = 102
		_style_surface(preview)
		var preview_content := VBoxContainer.new()
		preview_content.add_theme_constant_override("separation", 5)
		preview.add_child(preview_content)
		var preview_status := _label("9:41  ·  " + app_name.to_upper(), 6, _muted_color())
		preview_content.add_child(preview_status)
		var preview_title := ""
		match app_name:
			"Settings":
				preview_title = "Device settings"
			"Camera":
				preview_title = "Camera ready"
			"Messages":
				preview_title = "Recent conversations"
		preview_content.add_child(_label(preview_title, 8, _text_color()))
		for line_index in range(3):
			var preview_line := ColorRect.new()
			preview_line.custom_minimum_size = Vector2(0, 3)
			preview_line.color = Color(_muted_color().r, _muted_color().g, _muted_color().b, 0.22 + float(line_index) * 0.06)
			preview_content.add_child(preview_line)
		content.add_child(preview)
		content.add_child(_label("Recently opened", 6, _muted_color()))
		recent_row.add_child(card)

	clear.pressed.connect(func() -> void:
		for child in recent_row.get_children():
			if child != empty_state:
				recent_row.remove_child(child)
				child.queue_free()
		if empty_state.get_parent() == null:
			recent_row.add_child(empty_state)
	)
	if recent_row.get_child_count() == 0:
		recent_row.add_child(empty_state)


func _build_system_ui(data: Dictionary) -> void:
	_add_section_label("SYSTEM INTERFACE")
	var status_sample := PanelContainer.new()
	status_sample.custom_minimum_size.y = 48
	_style_surface(status_sample)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	status_sample.add_child(row)
	var clock := _label("9:41", 10, _text_color())
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if data.get("clock_alignment") == "right":
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(clock)
	row.add_child(_label("●  ▮▮▮", 8, _text_color()))
	row.add_child(_label("100%" if data.get("battery_style") == "percentage" else "▰", 8, _text_color()))
	page_container.add_child(status_sample)
	for item in ["Status bar", "Signal strength", "Wi-Fi state", "Battery indicator", "Navigation indicator"]:
		page_container.add_child(_surface_label(item + "  ·  " + str(data.get("status_style", "minimal")).capitalize(), 8))

func _add_slider_row(caption: String, initial_value: float) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	section.add_child(_label(caption, 8, _muted_color()))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_value
	slider.custom_minimum_size.y = 22
	section.add_child(slider)
	page_container.add_child(section)

func _add_notification_surface(app_name: String, message: String, time_label: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)
	var header := HBoxContainer.new()
	header.add_child(_label(app_name.to_upper(), 7, _accent_color()))
	var time := _label(time_label, 7, _muted_color())
	time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(time)
	content.add_child(header)
	content.add_child(_label(message, 9, _text_color()))
	page_container.add_child(card)

func _add_section_label(caption: String) -> void:
	var label := _label(caption, 8, _accent_color())
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 1)
	page_container.add_child(label)

func _search_field(placeholder_text: String) -> LineEdit:
	var search := LineEdit.new()
	search.placeholder_text = placeholder_text
	search.custom_minimum_size.y = 36
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.clear_button_enabled = true
	search.add_theme_color_override("font_color", _text_color())
	search.add_theme_color_override("font_placeholder_color", _muted_color())
	_style_field(search)
	return search

func _surface_label(caption: String, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 30
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(panel)
	var label := _label(caption, font_size, _text_color())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func _create_app_icon(app: Dictionary, icon_size: int, show_label: bool) -> Control:
	var tile := VBoxContainer.new()
	var app_name := str(app.get("name", "Application"))
	tile.name = "App_" + app_name.replace(" ", "")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 3)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := Button.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.text = str(app.get("glyph", "•"))
	icon.add_theme_font_size_override("font_size", maxi(16, int(icon_size * 0.50)))
	_style_icon_button(icon, Color(str(app.get("color", "#687987"))), str(configuration.get("style", {}).get("icon_shape", "rounded")))
	icon.pressed.connect(_on_app_pressed.bind(app_name))
	holder.add_child(icon)
	tile.add_child(holder)
	if show_label:
		var caption := _label(app_name, 7, _text_color())
		caption.name = "AppLabel_" + app_name.replace(" ", "")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.clip_text = true
		tile.add_child(caption)
	return tile


func _responsive_columns(preferred_columns: int) -> int:
	var available_width := size.x if size.x > 0.0 else 180.0
	var inner_width := maxf(available_width - 26.0, 88.0)
	var minimum_cell_width := 46.0
	var gap := 7.0
	var fitting_columns := floori((inner_width + gap) / (minimum_cell_width + gap))
	return clampi(mini(preferred_columns, fitting_columns), 2, 6)

func _responsive_icon_size(requested_size: int, columns: int, gap: int = 7) -> int:
	var available_width := size.x if size.x > 0.0 else 180.0
	var inner_width := maxf(available_width - 26.0, 88.0)
	var cell_width := (inner_width - float(maxi(columns - 1, 0) * gap)) / float(maxi(columns, 1))
	return clampi(mini(requested_size, floori(cell_width)), 24, requested_size)


func _populate_app_grid(grid: GridContainer, query: String, icon_size: int, show_labels: bool) -> void:
	var fitted_icon_size := _responsive_icon_size(icon_size, grid.columns, 7)
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var normalized_query := query.strip_edges().to_lower()
	for app in OSEngine.APP_DEFINITIONS:
		if not normalized_query.is_empty() and not str(app.get("name", "")).to_lower().contains(normalized_query):
			continue
		grid.add_child(_create_app_icon(app, fitted_icon_size, show_labels))
	if grid.get_child_count() == 0:
		var empty_label := _label("No matching applications", 8, _muted_color())
		empty_label.name = "NoMatchingAppsLabel"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty_label)


func _on_category_app_search_changed(query: String, category_grids: Array[GridContainer]) -> void:
	var normalized_query := query.strip_edges().to_lower()
	for grid in category_grids:
		if not is_instance_valid(grid):
			continue
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		var app_names: Array = grid.get_meta("app_names", [])
		for app_name_variant in app_names:
			var app_name := str(app_name_variant)
			if not normalized_query.is_empty() and not app_name.to_lower().contains(normalized_query):
				continue
			var app := _find_app(app_name)
			if not app.is_empty():
				grid.add_child(_create_app_icon(app, _responsive_icon_size(int(_style.get("icon_size", 52)), grid.columns), true))


func _on_app_search_changed(query: String, grid: GridContainer) -> void:
	if is_instance_valid(grid):
		_populate_app_grid(grid, query, int(configuration.get("style", {}).get("icon_size", 46)), true)

func _find_app(app_name: String) -> Dictionary:
	for app in OSEngine.APP_DEFINITIONS:
		if str(app.get("name", "")) == app_name:
			return app
	return {}

func _round_shortcut(glyph: String) -> Control:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(42, 42)
	button.add_theme_font_size_override("font_size", 16)
	_style_icon_button(button, _surface_color(), str(_style.get("icon_shape", "square")))
	return button

func _on_app_pressed(app_name: String) -> void:
	_last_opened_app = app_name
	_recent_app_names.erase(app_name)
	_recent_app_names.push_front(app_name)
	while _recent_app_names.size() > 5:
		_recent_app_names.pop_back()
	_close_gesture_overlay()
	app_opened.emit(app_name)
	if is_instance_valid(status_label):
		status_label.text = app_name + " preview"

func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	var scale_factor := float(_style.get("font_scale", 1.0))
	label.add_theme_font_size_override("font_size", maxi(7, roundi(float(font_size) * scale_factor)))
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Never split an unbroken word into one-character vertical lines on narrow previews.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _style_surface(panel: PanelContainer, prominent: bool = false) -> void:
	var style := StyleBoxFlat.new()
	var surface_color := Color(str(_palette.get("surface", "#19232E")))
	style.bg_color = Color(surface_color.r, surface_color.g, surface_color.b, 0.88 if prominent else 0.78)
	style.border_color = Color(_text_color().r, _text_color().g, _text_color().b, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 0)))
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)

func _style_action_button(button: Button, active: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _accent_color() if active else _surface_color()
	normal.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.60)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(int(_style.get("corner_radius", 16)))
	normal.content_margin_left = 9
	normal.content_margin_right = 9
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.10)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed.bg_color.darkened(0.10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", _text_color())
	button.add_theme_color_override("font_hover_color", _text_color())
	button.add_theme_font_size_override("font_size", 8)
	button.focus_mode = Control.FOCUS_NONE

func _style_icon_button(button: Button, tint: Color, _shape: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	var radius := int(_style.get("corner_radius", 0))
	style.set_corner_radius_all(radius)
	style.border_color = Color(1, 1, 1, 0.20)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE

func _style_field(field: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _surface_color()
	style.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 16)))
	style.content_margin_left = 9
	style.content_margin_right = 9
	field.add_theme_stylebox_override("normal", style)

func _surface_color() -> Color:
	return Color(str(_palette.get("surface", "#19232E")))

func _accent_color() -> Color:
	return Color(str(_palette.get("accent", "#76C8D4")))

func _text_color() -> Color:
	return Color(str(_palette.get("text", "#F4F7F8")))

func _muted_color() -> Color:
	return Color(str(_palette.get("muted", "#A7B4BD")))
