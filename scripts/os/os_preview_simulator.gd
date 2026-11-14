extends Control

signal app_opened(app_name: String)

const OSEngine = preload("res://scripts/os/procedural_os_engine.gd")
const PHONE_UNLOCK_PIN := "1234"
const LOCKSCREEN_FONT: FontFile = preload("res://assets/fonts/STIXTwoText[wght].ttf")
const FINGERPRINT_SENSOR_TEXTURE: Texture2D = preload("res://assets/os/lockscreen/fingerprint_sensor.svg")
const LOCKSCREEN_CAMERA_TEXTURE: Texture2D = preload("res://assets/os/lockscreen/camera.svg")
const LOCKSCREEN_FLASHLIGHT_TEXTURE: Texture2D = preload("res://assets/os/lockscreen/flashlight.svg")
const LOCKSCREEN_SHORTCUT_ICON_SCALE := 0.81
const STATUS_CELLULAR_TEXTURE: Texture2D = preload("res://assets/os/lockscreen/status_cellular.svg")
const STATUS_WIFI_TEXTURE: Texture2D = preload("res://assets/os/lockscreen/status_wifi.svg")
const STATUS_BATTERY_TEXTURE: Texture2D = preload("res://assets/os/lockscreen/status_battery.svg")

class PINLockIndicator extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(14, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var center_x := size.x * 0.5
		draw_arc(Vector2(center_x, 8.0), 4.0, PI, TAU, 20, Color("#F4F6FA"), 1.5, true)
		draw_rect(Rect2(Vector2(center_x - 5.0, 7.0), Vector2(10.0, 9.0)), Color("#F4F6FA"))
		draw_circle(Vector2(center_x, 11.0), 1.0, Color("#263244"))


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


class LockScreenFingerprintButton extends Button:
	var sensor_texture: Texture2D
	var artwork_scale := 0.81

	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(52, 52)
		sensor_texture = FINGERPRINT_SENSOR_TEXTURE
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		queue_redraw()

	func _draw() -> void:
		if sensor_texture == null:
			return
		var side := minf(size.x, size.y)
		var artwork_side := side * clampf(artwork_scale, 0.0, 1.0)
		var rect := Rect2((size - Vector2.ONE * artwork_side) * 0.5, Vector2.ONE * artwork_side)
		if is_pressed():
			draw_circle(size * 0.5, side * 0.48, Color("#DCEEFF", 0.18))
		draw_texture_rect(sensor_texture, rect, false)


var configuration: Dictionary = {}
var active_component := "home_screen"
var _home_screen_corner_radius := 0
var _home_screen_radius_styleboxes: Array[StyleBoxFlat] = []
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
var _entered_unlock_pin := ""
var _pin_error_message := ""
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
	elif active_component == "home_screen":
		var home_clock := find_child("HomeHeroClock", true, false) as Label
		if is_instance_valid(home_clock):
			home_clock.text = _current_lock_time()
		var home_date := find_child("HomeHeroDate", true, false) as Label
		if is_instance_valid(home_date):
			home_date.text = _current_lock_date("minimal")


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
		set_component_view("pin_input")
		return

	if start.y >= size.y - edge_size and delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
		if elapsed_ms >= 420:
			_show_gesture_overlay("recent_apps")
		elif active_component == "home_screen":
			set_component_view("app_drawer")
		elif active_component == "pin_input":
			set_component_view("lock_screen")
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
	elif active_component == "pin_input":
		set_component_view("lock_screen")
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
	if active_component == "pin_input":
		_entered_unlock_pin = ""
		_pin_error_message = ""
	if is_inside_tree():
		_build_shell()

func update_configuration(os_configuration: Dictionary) -> void:
	configuration = OSEngine.normalize_os(os_configuration)
	if is_inside_tree():
		_build_shell()


func set_home_screen_corner_radius(value: float) -> void:
	var next_radius := clampi(roundi(value), 0, 24)
	if next_radius == _home_screen_corner_radius:
		return
	_home_screen_corner_radius = next_radius
	# Reuse cached styles while dragging instead of searching the tree and
	# allocating new StyleBoxes on every slider event.
	for style in _home_screen_radius_styleboxes:
		if is_instance_valid(style):
			style.set_corner_radius_all(_home_screen_corner_radius)


func _register_home_screen_radius_style(style: StyleBoxFlat) -> void:
	if style != null and not _home_screen_radius_styleboxes.has(style):
		_home_screen_radius_styleboxes.append(style)

func _apply_home_screen_icon_styles() -> void:
	if active_component != "home_screen":
		return
	for grid_name in ["HomeAppGrid", "ColorOSWorkFolderGrid", "ColorOSMediaFolderGrid"]:
		var app_grid := find_child(grid_name, true, false) as GridContainer
		if app_grid == null:
			continue
		for app_tile in app_grid.get_children():
			var app_button := app_tile.get_node_or_null("CenterContainer/Button") as Button
			if app_button != null:
				_style_home_app_icon(app_button)
	var dock := find_child("HomeAppDock", true, false) as Control
	if dock != null:
		for button_node in dock.find_children("*", "Button", true, false):
			var dock_button := button_node as Button
			if dock_button != null:
				_style_home_app_icon(dock_button)


func _safe_component_id(component_id: String) -> String:
	if component_id == "pin_input":
		return component_id
	for component in OSEngine.COMPONENTS:
		if str(component["id"]) == component_id:
			return component_id
	return "home_screen"

func _build_shell() -> void:
	if _building:
		return
	_building = true
	_home_screen_radius_styleboxes.clear()
	for child in get_children():
		remove_child(child)
		# A component switch may originate inside a descendant Button signal.
		# Detach immediately, but defer destruction until signal emission ends.
		child.queue_free()

	_style = configuration.get("style", {})
	_palette = _style.get("palette", {"background":"#0B1017","surface":"#19232E","surface_alt":"#263544","accent":"#76C8D4","text":"#F4F7F8","muted":"#A7B4BD"})
	var wallpaper := OSWallpaperLayer.new()
	wallpaper.name = "OSProceduralWallpaper"
	wallpaper.palette = _palette.duplicate(true)
	wallpaper.wallpaper_id = str(_style.get("wallpaper", "aurora"))
	wallpaper.treatment = str(configuration.get("components", {}).get("wallpapers", {}).get("treatment", "natural"))
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wallpaper)

	if active_component == "pin_input":
		var pin_screen_tint := ColorRect.new()
		pin_screen_tint.name = "PINScreenBackdropTint"
		pin_screen_tint.color = Color(0.015, 0.025, 0.055, 0.22)
		pin_screen_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pin_screen_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pin_screen_tint)

	var safe_area := MarginContainer.new()
	safe_area.name = "OSSimulatorSafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 12)
	safe_area.add_theme_constant_override("margin_right", 12)
	safe_area.add_theme_constant_override("margin_top", 7)
	safe_area.add_theme_constant_override("margin_bottom", 7)
	add_child(safe_area)

	if active_component in ["lock_screen", "pin_input"]:
		var lock_shell := VBoxContainer.new()
		lock_shell.name = "OSLockScreenShell" if active_component == "lock_screen" else "OSPinInputShell"
		lock_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lock_shell.add_theme_constant_override("separation", 3)
		safe_area.add_child(lock_shell)

		# The lock screen keeps its compact system status bar. Samsung-style
		# PIN entry instead uses a clean lock indicator at the top of the screen.
		_build_status_bar(lock_shell)
		if active_component == "pin_input":
			var pin_status_bar := lock_shell.get_node_or_null("OSStatusBar") as Control
			if pin_status_bar != null:
				pin_status_bar.visible = false

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

	page_container = VBoxContainer.new()
	page_container.name = "OSComponentContent"
	page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_theme_constant_override("separation", int(_style.get("spacing", 10)))
	if active_component == "home_screen":
		# The home screen is a fixed-height composition, not a scrolling list.
		page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shell.add_child(page_container)
	else:
		var scroll := ScrollContainer.new()
		scroll.name = "OSComponentViewport"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		shell.add_child(scroll)
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
	if active_component == "home_screen":
		# Resolve and style app buttons only after their full inherited theme
		# hierarchy and the dock have entered the live scene tree.
		_apply_home_screen_icon_styles()
	_building = false

func _build_home_dock(parent: VBoxContainer) -> void:
	var home_layout := str(configuration.get("components", {}).get("home_screen", {}).get("layout_style", "android_pixel"))
	var is_huawei_layout := home_layout == "huawei_pura"
	var is_transparent_dock := home_layout in ["huawei_pura", "nothing_os"]
	var dock_apps := ["Phone", "Messages", "Camera", "Email"] if is_huawei_layout else ["Phone", "Messages", "Browser", "Camera"]
	var dock_row := HBoxContainer.new()
	dock_row.name = "HomeAppDockIcons"
	dock_row.custom_minimum_size.y = 40 if is_huawei_layout else 48
	dock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 8 if is_huawei_layout else 6)
	var dock_icon_size := _responsive_icon_size(32 if is_huawei_layout else 35, dock_apps.size(), 6)
	for app_name in dock_apps:
		var app := _find_app(app_name)
		if not app.is_empty():
			dock_row.add_child(_create_app_icon(app, dock_icon_size, false))
	if is_transparent_dock:
		dock_row.name = "HomeAppDock"
		parent.add_child(dock_row)
	else:
		var dock := PanelContainer.new()
		dock.name = "HomeAppDock"
		dock.custom_minimum_size.y = 48
		dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_home_surface(dock, 18)
		dock.add_child(dock_row)
		parent.add_child(dock)


func _status_bar_icon(asset_texture: Texture2D, icon_size: Vector2, node_name: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = asset_texture
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE
	return icon


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
	var indicators := HBoxContainer.new()
	indicators.name = "StatusBarSystemIndicators"
	indicators.alignment = BoxContainer.ALIGNMENT_END
	indicators.add_theme_constant_override("separation", 3)
	indicators.custom_minimum_size = Vector2(57, 16)
	indicators.add_child(_status_bar_icon(STATUS_CELLULAR_TEXTURE, Vector2(16, 13), "StatusBarCellularIcon"))
	indicators.add_child(_status_bar_icon(STATUS_WIFI_TEXTURE, Vector2(15, 13), "StatusBarWifiIcon"))
	indicators.add_child(_status_bar_icon(STATUS_BATTERY_TEXTURE, Vector2(20, 13), "StatusBarBatteryIcon"))
	row.add_child(indicators)
	status_label = _label("", 1, _text_color())
	status_label.name = "StatusBarBattery"
	status_label.visible = false
	# Keep the hidden status target inside the live tree so each shell rebuild
	# releases it with the rest of the status bar instead of orphaning a Label.
	bar.add_child(status_label)
	parent.add_child(bar)

func _build_component(component_id: String) -> void:
	var components: Dictionary = configuration.get("components", {})
	var component_data: Dictionary = components.get(component_id, {})
	match component_id:
		"home_screen":
			_build_home_screen(component_data)
		"lock_screen":
			_build_lock_screen(component_data)
		"pin_input":
			_build_pin_input()
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
	var layout_style := str(data.get("layout_style", "android_pixel"))
	match layout_style:
		"coloros_home":
			_build_coloros_home(data)
		"ios_home":
			_build_apple_ios_home()
		"samsung_one_ui":
			_build_samsung_one_ui_home()
		"huawei_pura":
			_build_huawei_pura_home(data)
		"hyperos_home":
			_build_redmi_hyperos_home()
		"hios_home":
			_build_tecno_hios_home()
		"xos_home":
			_build_infinix_xos_home()
		"itel_home":
			_build_itel_home()
		"windows_tiles":
			_build_windows_phone_home()
		"nothing_os":
			_build_nothing_os_home()
		"motorola_hello":
			_build_motorola_hello_home()
		"sony_xperia":
			_build_sony_xperia_home()
		"asus_zen":
			_build_asus_zen_home()
		"vivo_origin":
			_build_vivo_origin_home()
		_:
			_build_android_home(data, 2)


func _build_android_home(_data: Dictionary, _widget_count: int) -> void:
	var date_label := _label(_current_lock_date("minimal").to_upper(), 10, _text_color())
	date_label.name = "AndroidHomeDate"
	page_container.add_child(date_label)
	var greeting := _label("26°  ·  Partly cloudy", 8, _muted_color())
	greeting.name = "AndroidHomeWeatherSummary"
	page_container.add_child(greeting)

	var top_spacing := Control.new()
	top_spacing.name = "AndroidHomeTopFlexibleSpace"
	top_spacing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(top_spacing)

	var widgets_row := HBoxContainer.new()
	widgets_row.name = "AndroidHomeWidgetRow"
	widgets_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widgets_row.add_theme_constant_override("separation", 7)
	page_container.add_child(widgets_row)

	var weather_widget := PanelContainer.new()
	weather_widget.name = "AndroidWeatherWidget"
	weather_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_widget.custom_minimum_size.y = 72
	_style_home_surface(weather_widget, 15)
	var weather_content := VBoxContainer.new()
	weather_content.add_theme_constant_override("separation", 2)
	weather_widget.add_child(weather_content)
	weather_content.add_child(_label("WEATHER", 7, _muted_color()))
	weather_content.add_child(_label("26°", 22, _text_color()))
	weather_content.add_child(_label("Partly cloudy", 7, _muted_color()))
	widgets_row.add_child(weather_widget)

	var assistant_widget := PanelContainer.new()
	assistant_widget.name = "AndroidAssistantWidget"
	assistant_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assistant_widget.custom_minimum_size.y = 72
	_style_home_surface(assistant_widget, 15)
	var assistant_content := VBoxContainer.new()
	assistant_content.add_theme_constant_override("separation", 3)
	assistant_widget.add_child(assistant_content)
	assistant_content.add_child(_label("ASSISTANT", 7, _muted_color()))
	assistant_content.add_child(_label("Ask anything", 11, _text_color()))
	assistant_content.add_child(_label("Tap to get help", 7, _muted_color()))
	widgets_row.add_child(assistant_widget)

	var middle_spacing := Control.new()
	middle_spacing.name = "AndroidHomeMiddleFlexibleSpace"
	middle_spacing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(middle_spacing)

	var apps_grid := GridContainer.new()
	apps_grid.name = "HomeAppGrid"
	apps_grid.columns = 4
	apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_grid.add_theme_constant_override("h_separation", 5)
	apps_grid.add_theme_constant_override("v_separation", 5)
	for app_name in ["Photos", "Store", "Email", "Maps"]:
		var app := _find_app(app_name)
		if not app.is_empty():
			apps_grid.add_child(_create_app_icon(app, _responsive_icon_size(34, 4, 5), true))
	page_container.add_child(apps_grid)

	var search_spacing := Control.new()
	search_spacing.name = "AndroidHomeSearchFlexibleSpace"
	search_spacing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(search_spacing)

	_add_home_search_field("Search your phone", "HomeSearchBar")



func _build_coloros_home(_data: Dictionary) -> void:
	var top_space := Control.new()
	top_space.name = "ColorOSHomeTopSpace"
	top_space.custom_minimum_size.y = 7
	page_container.add_child(top_space)

	var hero := VBoxContainer.new()
	hero.name = "ColorOSHomeClock"
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", 2)
	var clock := _label(_current_lock_time(), 31, _text_color())
	clock.name = "HomeHeroClock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(clock)
	var date := _label(_current_lock_date("minimal"), 8, _muted_color())
	date.name = "HomeHeroDate"
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(date)
	page_container.add_child(hero)

	var information := PanelContainer.new()
	information.name = "ColorOSSmartInformationWidget"
	information.custom_minimum_size.y = 66
	information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_home_surface(information, 0)
	var information_row := HBoxContainer.new()
	information_row.add_theme_constant_override("separation", 8)
	information.add_child(information_row)
	var information_text := VBoxContainer.new()
	information_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	information_text.add_theme_constant_override("separation", 2)
	information_text.add_child(_label("TODAY'S OVERVIEW", 7, _muted_color()))
	information_text.add_child(_label("Good evening", 15, _text_color()))
	information_text.add_child(_label("Your day at a glance", 7, _muted_color()))
	information_row.add_child(information_text)
	var calendar_icon := _label("▦", 24, _accent_color())
	calendar_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	calendar_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calendar_icon.custom_minimum_size.x = 34
	information_row.add_child(calendar_icon)
	page_container.add_child(information)

	var folder_row := HBoxContainer.new()
	folder_row.name = "ColorOSFolderRow"
	folder_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_row.add_theme_constant_override("separation", 7)
	page_container.add_child(folder_row)
	_build_coloros_app_folder(folder_row, "Work", "ColorOSWorkFolder", ["Email", "Calendar", "Files", "Notes"])
	_build_coloros_app_folder(folder_row, "Media", "ColorOSMediaFolder", ["Gallery", "Music", "Video", "Photos"])

	var apps_grid := GridContainer.new()
	apps_grid.name = "HomeAppGrid"
	apps_grid.columns = 4
	apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_grid.add_theme_constant_override("h_separation", 5)
	apps_grid.add_theme_constant_override("v_separation", 3)
	for app_name in ["Settings", "Maps", "Store", "Downloads"]:
		var app := _find_app(app_name)
		if not app.is_empty():
			apps_grid.add_child(_create_app_icon(app, _responsive_icon_size(30, 4, 5), true))
	page_container.add_child(apps_grid)

	var flexible_space := Control.new()
	flexible_space.name = "ColorOSHomeFlexibleSpace"
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(flexible_space)


func _build_coloros_app_folder(parent: HBoxContainer, title_text: String, folder_name: String, app_names: Array) -> void:
	var folder := PanelContainer.new()
	folder.name = folder_name
	folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder.custom_minimum_size.y = 104
	_style_home_surface(folder, 0)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	folder.add_child(content)
	content.add_child(_label(title_text, 10, _text_color()))
	var grid := GridContainer.new()
	grid.name = folder_name + "Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for app_name in app_names:
		var app := _find_app(str(app_name))
		if not app.is_empty():
			grid.add_child(_create_app_icon(app, _responsive_icon_size(24, 2, 3), false))
	content.add_child(grid)
	parent.add_child(folder)

func _style_home_surface(panel: PanelContainer, _radius: int) -> void:
	var style := StyleBoxFlat.new()
	var surface_color := _surface_color()
	style.bg_color = Color(surface_color.r, surface_color.g, surface_color.b, 0.90)
	style.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(_home_screen_corner_radius)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	_register_home_screen_radius_style(style)


func _style_home_app_icon(button: Button) -> void:
	# Preserve each app's own tinted icon style, while the Home Screen Studio
	# slider controls its geometry independently of the general OS icon style.
	for state_name in ["normal", "hover", "pressed"]:
		var source_style := button.get_theme_stylebox(state_name) as StyleBoxFlat
		var style := StyleBoxFlat.new()
		if source_style != null:
			style = source_style.duplicate() as StyleBoxFlat
		style.set_corner_radius_all(_home_screen_corner_radius)
		style.border_color = Color(_text_color().r, _text_color().g, _text_color().b, 0.42)
		style.set_border_width_all(1)
		button.add_theme_stylebox_override(state_name, style)
		_register_home_screen_radius_style(style)


func _build_huawei_pura_home(_data: Dictionary) -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.8)
	page_container.add_child(_build_home_clock_block(28))
	page_container.add_child(_make_home_widget_row("HomeServiceWidgetRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "DAILY ACTIVITY", "6,270 steps", "1,730 steps to your daily goal", "✣", 62),
		_make_home_widget_panel("HuaweiWeatherWidget", "WEATHER", "26°  Mostly sunny", "Feels like 29°  ·  H:30° L:24°", "☀", 62)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.7)
	page_container.add_child(_make_home_app_grid(["Gallery", "Music", "Video", "Calendar", "Wallet", "Files", "Settings", "Store"], 4, 30, true))
	_add_home_flexible_space("HomeLayoutBottomFlexibleSpace", 0.5)



func _add_home_flexible_space(node_name: String, stretch_ratio: float = 1.0) -> Control:
	var spacer := Control.new()
	spacer.name = node_name
	spacer.custom_minimum_size = Vector2(0, 2)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = maxf(0.1, stretch_ratio)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_container.add_child(spacer)
	return spacer


func _build_home_clock_block(font_size: int = 30, alignment: int = HORIZONTAL_ALIGNMENT_CENTER) -> VBoxContainer:
	var hero := VBoxContainer.new()
	hero.name = "HomeHeroClockStack"
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 1)
	var clock_text := _current_lock_time()
	var fitted_size := maxi(20, font_size)
	var clock_font := FontVariation.new()
	clock_font.base_font = LOCKSCREEN_FONT
	clock_font.variation_embolden = 0.65
	var available_width := maxf(1.0, (size.x if size.x > 0.0 else 220.0) - 34.0)
	var measured_width := clock_font.get_string_size(clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x
	if measured_width > available_width and measured_width > 0.0:
		fitted_size = maxi(20, floori(float(fitted_size) * available_width / measured_width))
	var clock := _label(clock_text, fitted_size, _text_color())
	clock.name = "HomeHeroClock"
	clock.horizontal_alignment = alignment as HorizontalAlignment
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.custom_minimum_size = Vector2(0, fitted_size + 5)
	clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock.clip_text = false
	clock.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	clock.add_theme_font_override("font", clock_font)
	hero.add_child(clock)
	var date := _label(_current_lock_date("minimal"), 8, _muted_color())
	date.name = "HomeHeroDate"
	date.horizontal_alignment = alignment as HorizontalAlignment
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.custom_minimum_size.y = 12
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	date.clip_text = false
	hero.add_child(date)
	return hero


func _make_home_widget_panel(panel_name: String, heading_text: String, value_text: String, detail_text: String, glyph: String = "", minimum_height: float = 60.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, minimum_height)
	_style_home_surface(panel, _home_screen_corner_radius)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	var heading := _label(heading_text, 7, _muted_color())
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	copy.add_child(heading)
	var value := _label(value_text, 13, _text_color())
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.clip_text = false
	copy.add_child(value)
	var detail := _label(detail_text, 7, _muted_color())
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.clip_text = false
	copy.add_child(detail)
	row.add_child(copy)
	if not glyph.is_empty():
		var icon := _label(glyph, 23, _accent_color())
		icon.custom_minimum_size.x = 30
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(icon)
	panel.add_child(row)
	return panel


func _make_home_app_grid(app_names: Array, columns: int = 4, icon_size: int = 30, show_labels: bool = true, grid_name: String = "HomeAppGrid") -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = _responsive_columns(clampi(columns, 2, 6))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var fitted_size := _responsive_icon_size(icon_size, grid.columns, 5)
	for app_name_variant in app_names:
		var app := _find_app(str(app_name_variant))
		if not app.is_empty():
			grid.add_child(_create_app_icon(app, fitted_size, show_labels))
	return grid


func _make_home_widget_row(row_name: String, widgets: Array, gap: int = 6) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", gap)
	for widget_variant in widgets:
		var widget := widget_variant as Control
		if is_instance_valid(widget):
			row.add_child(widget)
	return row


func _add_home_search_field(placeholder_text: String, field_name: String = "HomeSearchBar") -> LineEdit:
	var search := _search_field(placeholder_text)
	search.name = field_name
	_style_home_search_field(search)
	page_container.add_child(search)
	return search


func _style_home_search_field(search: LineEdit) -> void:
	for state_name in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		var surface := _surface_color()
		style.bg_color = Color(surface.r, surface.g, surface.b, 0.88)
		style.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.68 if state_name == "focus" else 0.52)
		style.set_border_width_all(1)
		style.set_corner_radius_all(_home_screen_corner_radius)
		style.content_margin_left = 11
		style.content_margin_right = 11
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		search.add_theme_stylebox_override(state_name, style)
		_register_home_screen_radius_style(style)


func _build_apple_ios_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.8)
	page_container.add_child(_build_home_clock_block(27))
	page_container.add_child(_make_home_widget_row("AppleWidgetRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°  Mostly sunny", "Feels like 29°  ·  H:30° L:24°", "☀", 60),
		_make_home_widget_panel("AppleCalendarWidget", "FRIDAY  ·  CALENDAR", "14", "No events scheduled today", "▦", 60)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 1.0)
	page_container.add_child(_make_home_app_grid(["Photos", "Calendar", "Clock", "Email", "Notes", "Tasks", "Store", "Maps"], 4, 29, true))
	_add_home_flexible_space("HomeLayoutBottomFlexibleSpace", 0.55)
	_add_home_search_field("Search iPhone", "HomeSearchBar")


func _build_samsung_one_ui_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.75)
	page_container.add_child(_build_home_clock_block(31))
	page_container.add_child(_make_home_widget_row("SamsungWidgetRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°  Partly cloudy", "Port Harcourt  ·  H:30° L:24°", "☁", 62),
		_make_home_widget_panel("SamsungCalendarWidget", "UP NEXT", "10:30 AM", "Team meeting  ·  Today", "▦", 62)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.8)
	page_container.add_child(_make_home_app_grid(["Calendar", "Gallery", "Music", "Files", "Settings", "Store", "Maps", "Wallet"], 4, 29, true))
	_add_home_search_field("Search Galaxy", "HomeSearchBar")


func _build_redmi_hyperos_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.8)
	page_container.add_child(_build_home_clock_block(32))
	page_container.add_child(_make_home_widget_row("HyperOSWidgetRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°", "Mostly sunny  ·  Feels like 29°", "☀", 64),
		_make_home_widget_panel("RedmiDailyWidget", "SCREEN TIME", "2h 14m", "Down 18% from yesterday", "◷", 64)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.9)
	page_container.add_child(_make_home_app_grid(["Clock", "Calendar", "Gallery", "Video", "Music", "Security", "Store", "Files"], 4, 29, true))
	_add_home_search_field("Search apps and content", "HomeSearchBar")


func _build_tecno_hios_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.7)
	page_container.add_child(_build_home_clock_block(29))
	var dashboard := GridContainer.new()
	dashboard.name = "TecnoHiOSWidgetGrid"
	dashboard.columns = 2
	dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard.add_theme_constant_override("h_separation", 5)
	dashboard.add_theme_constant_override("v_separation", 5)
	dashboard.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°  Sunny", "Feels like 29°", "☀", 48))
	dashboard.add_child(_make_home_widget_panel("TecnoCalendarWidget", "CALENDAR", "14 NOV", "No upcoming events", "▦", 48))
	dashboard.add_child(_make_home_widget_panel("TecnoDeviceCareWidget", "DEVICE CARE", "All clear", "Battery health is good", "✚", 48))
	dashboard.add_child(_make_home_widget_panel("TecnoMusicWidget", "NOW PLAYING", "Your soundtrack", "Nothing playing", "♫", 48))
	page_container.add_child(dashboard)
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.8)
	page_container.add_child(_make_home_app_grid(["Gallery", "Video", "Music", "Calendar", "Files", "Settings", "Store", "Weather"], 4, 27, true))
	_add_home_search_field("Search HiOS", "HomeSearchBar")


func _build_infinix_xos_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.65)
	_add_home_search_field("Search with Google", "HomeSearchBar")
	page_container.add_child(_build_home_clock_block(34, HORIZONTAL_ALIGNMENT_LEFT))
	page_container.add_child(_make_home_widget_row("InfinixXOSWidgetRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "SMART FOLDER", "4 essentials", "Assistant  ·  Files  ·  Video  ·  Music", "▦", 62),
		_make_home_widget_panel("InfinixWeatherWidget", "WEATHER", "26°  Cloudy", "Feels like 29°", "☁", 62)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.75)
	page_container.add_child(_make_home_app_grid(["Assistant", "Files", "Video", "Gallery", "Calendar", "Music", "Weather", "Settings"], 4, 28, true))


func _build_itel_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.7)
	page_container.add_child(_build_home_clock_block(27))
	page_container.add_child(_make_home_widget_row("ItelWidgetRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°", "Sunny today", "☀", 57),
		_make_home_widget_panel("ItelCalendarWidget", "CALENDAR", "14 NOV", "No events today", "▦", 57)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.9)
	page_container.add_child(_make_home_app_grid(["Gallery", "Music", "Calendar", "Files", "Settings", "Store", "Calculator", "Notes"], 4, 29, true))
	_add_home_flexible_space("HomeLayoutBottomFlexibleSpace", 0.45)
	_add_home_search_field("Search your phone", "HomeSearchBar")


func _build_windows_phone_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.7)
	page_container.add_child(_build_home_clock_block(27, HORIZONTAL_ALIGNMENT_LEFT))
	page_container.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "LIVE UPDATES", "26°  ·  14 NOV", "Weather, calendar and activity at a glance", "▦", 52))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.5)
	_build_windows_tiles()
	_add_home_flexible_space("HomeLayoutBottomFlexibleSpace", 0.35)


func _build_nothing_os_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.8)
	page_container.add_child(_build_home_clock_block(35))
	page_container.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "DOT MATRIX  ·  DEVICE STATUS", "87% battery  ·  5G", "26° outside  ·  3 tasks today", "◉", 62))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.9)
	page_container.add_child(_make_home_app_grid(["Gallery", "Music", "Calendar", "Files", "Settings", "Store", "Maps", "Recorder"], 4, 29, true))
	_add_home_flexible_space("HomeLayoutBottomFlexibleSpace", 0.45)
	_add_home_search_field("Search essentials", "HomeSearchBar")


func _build_motorola_hello_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.7)
	page_container.add_child(_build_home_clock_block(31))
	page_container.add_child(_make_home_widget_row("MotorolaAtAGlanceRow", [
		_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°  Mostly sunny", "Port Harcourt  ·  H:30° L:24°", "☀", 61),
		_make_home_widget_panel("MotorolaAtAGlanceWidget", "AT A GLANCE", "2 reminders", "Next event  ·  10:30 AM", "◷", 61)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.9)
	page_container.add_child(_make_home_app_grid(["Gallery", "Calendar", "Photos", "Music", "Settings", "Maps", "Files", "Weather"], 4, 28, true))
	_add_home_search_field("Search apps", "HomeSearchBar")


func _build_sony_xperia_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.7)
	page_container.add_child(_build_home_clock_block(28, HORIZONTAL_ALIGNMENT_LEFT))
	page_container.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "MUSIC  ·  NOW PLAYING", "Your soundtrack", "No track playing  ·  Tap to open Music", "♫", 68))
	page_container.add_child(_make_home_widget_row("SonyXperiaSecondaryWidgets", [
		_make_home_widget_panel("SonyCalendarWidget", "TODAY", "14 NOV", "No events scheduled", "▦", 54),
		_make_home_widget_panel("SonyWeatherWidget", "WEATHER", "26°  Sunny", "Feels like 29°", "☀", 54)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.75)
	page_container.add_child(_make_home_app_grid(["Gallery", "Music", "Video", "Calendar", "Store", "Maps", "Settings", "Files"], 4, 27, true))
	_add_home_search_field("Search Xperia", "HomeSearchBar")


func _build_asus_zen_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.65)
	page_container.add_child(_build_home_clock_block(27))
	var widget_grid := GridContainer.new()
	widget_grid.name = "AsusZenWidgetGrid"
	widget_grid.columns = 2
	widget_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget_grid.add_theme_constant_override("h_separation", 5)
	widget_grid.add_theme_constant_override("v_separation", 5)
	widget_grid.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "WEATHER", "26°  Mostly sunny", "Feels like 29°", "☀", 48))
	widget_grid.add_child(_make_home_widget_panel("AsusCalendarWidget", "CALENDAR", "14 NOV", "No events today", "▦", 48))
	widget_grid.add_child(_make_home_widget_panel("AsusQuickToolsWidget", "QUICK TOOLS", "Calculator  ·  Notes", "Your everyday tools", "＋", 48))
	widget_grid.add_child(_make_home_widget_panel("AsusDeviceWidget", "DEVICE STATUS", "87% battery", "All systems normal", "◇", 48))
	page_container.add_child(widget_grid)
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.75)
	page_container.add_child(_make_home_app_grid(["Gallery", "Music", "Files", "Settings", "Calculator", "Store", "Maps", "Calendar"], 4, 26, true))
	_add_home_search_field("Search ZenUI", "HomeSearchBar")


func _build_vivo_origin_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.75)
	page_container.add_child(_build_home_clock_block(30))
	page_container.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "ORIGIN SMART SPACE", "26°  ·  Air quality good", "3 tasks today  ·  Next event 10:30 AM", "✧", 68))
	page_container.add_child(_make_home_widget_row("VivoOriginSecondaryRow", [
		_make_home_widget_panel("VivoCalendarWidget", "CALENDAR", "14 NOV", "A clear day ahead", "▦", 52),
		_make_home_widget_panel("VivoHealthWidget", "DAILY ACTIVITY", "6,270 steps", "Goal progress 63%", "✣", 52)
	]))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.75)
	page_container.add_child(_make_home_app_grid(["Gallery", "Music", "Calendar", "Files", "Settings", "Store", "Wallet", "Notes"], 4, 27, true))
	_add_home_search_field("Search OriginOS", "HomeSearchBar")


func _style_home_tile_button(button: Button, tint: Color) -> void:
	for state_name in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tint.darkened(0.16)
		style.border_color = Color(1, 1, 1, 0.28)
		style.set_border_width_all(1)
		style.set_corner_radius_all(_home_screen_corner_radius)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		button.add_theme_stylebox_override(state_name, style)
		_register_home_screen_radius_style(style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 8)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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
	var tile_names := ["Phone", "Messages", "Email", "Calendar", "Photos", "Store", "Maps", "Music", "Settings"]
	for app_name in tile_names:
		var app := _find_app(app_name)
		if app.is_empty():
			continue
		var tile := Button.new()
		tile.name = "LiveTile_" + app_name.replace(" ", "")
		tile.custom_minimum_size = Vector2(48, 54)
		tile.text = str(app.get("glyph", "•")) + "\n" + app_name
		if app_name == "Calendar":
			tile.text = "14\nCALENDAR"
		elif app_name == "Photos":
			tile.text = "▧\nPHOTOS"
		elif app_name == "Music":
			tile.text = "♫\nMUSIC"
		_style_home_tile_button(tile, Color(str(app.get("color", "#687987"))))
		tile.pressed.connect(_on_app_pressed.bind(app_name))
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
	# Build reusable lock-screen widgets inside the live scene tree. Creating this
	# staging container detached leaves its generated Controls and theme resources
	# outside normal Node ownership during repeated preview rebuilds.
	original_container.add_child(bank)
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
	root_layout.add_theme_constant_override("separation", 3)
	page_container.add_child(root_layout)

	var top_space := Control.new()
	top_space.name = "LockScreenTopFlexibleSpace"
	top_space.custom_minimum_size.y = 4
	# A top spacer must never consume the clock's visible area on compact previews.
	var lower_space := Control.new()
	lower_space.name = "LockScreenBottomFlexibleSpace"
	lower_space.custom_minimum_size.y = 4

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
	if template == "pixel_large_clock" or str(data.get("clock_treatment", "")) == "oversized":
		configured_clock_size = mini(58, configured_clock_size + 6)
	if family == "typographic":
		configured_clock_size = mini(configured_clock_size, 24)
	var clock_text := _current_lock_time(family)
	var clock_line_count := 2 if family == "typographic" else 1
	var clock_font := FontVariation.new()
	clock_font.base_font = LOCKSCREEN_FONT
	clock_font.variation_embolden = 1.1 if template in ["coloros_typography", "neo_brutalist"] else 0.55
	# Fit the actual rendered string to the available phone width. The old fixed
	# 30 px clamp still allowed wide numerals to be clipped, leaving only the
	# centre time separator visible on narrow worksite previews.
	var available_clock_width := maxf(1.0, size.x - 34.0)
	var measured_clock_width := clock_font.get_string_size(clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, configured_clock_size).x
	if measured_clock_width > available_clock_width and measured_clock_width > 0.0:
		configured_clock_size = maxi(20, floori(float(configured_clock_size) * available_clock_width / measured_clock_width))
	var clock := _label(clock_text, configured_clock_size, _text_color())
	clock.name = "LockScreenClock"
	clock.horizontal_alignment = alignment
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	clock.clip_text = false
	clock.clip_contents = false
	clock.custom_minimum_size = Vector2(0, configured_clock_size * clock_line_count + 8)
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	clock_stack.custom_minimum_size.y = configured_clock_size * clock_line_count + 22
	clock_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_stack.clip_contents = false
	clock.add_theme_font_override("font", clock_font)
	clock.add_theme_color_override("font_color", Color("#FFFFFF"))
	clock.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	clock.add_theme_constant_override("outline_size", 2)
	clock.modulate = Color.WHITE
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
	clock_stage.custom_minimum_size.y = configured_clock_size * clock_line_count + 26
	clock_stage.clip_contents = false
	clock_stage.add_child(clock_stack)

	# Lock-screen content needs deliberate vertical distribution. VBoxContainer
	# otherwise packs every child at the top of the phone, leaving the lower
	# half empty. These two flexible regions position the clock in the upper
	# third and reserve the lower area for the sensor and unlock controls.
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_space.size_flags_stretch_ratio = 0.85
	lower_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_space.size_flags_stretch_ratio = 1.15
	root_layout.add_child(top_space)
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
		shortcuts.add_child(_make_lock_shortcut(LOCKSCREEN_CAMERA_TEXTURE, str(data.get("shortcut_treatment", "floating")), "Camera"))
	var shortcut_spacer := Control.new()
	shortcut_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.add_child(shortcut_spacer)
	if bool(data.get("show_flashlight_shortcut", true)):
		shortcuts.add_child(_make_lock_shortcut(LOCKSCREEN_FLASHLIGHT_TEXTURE, str(data.get("shortcut_treatment", "floating")), "Flashlight"))

	var fingerprint: Control
	if bool(data.get("show_fingerprint", false)) and bool(data.get("fingerprint_sensor_available", false)):
		var sensor := LockScreenFingerprintButton.new()
		sensor.name = "LockScreenFingerprintSensor"
		sensor.tooltip_text = "Touch to unlock"
		sensor.pressed.connect(func(): set_component_view("home_screen"))
		fingerprint = sensor

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
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"rhombus_clock":
			var rhombus_caption := _label("TODAY  ·  DIGITALWORLD", 7, _accent_color())
			rhombus_caption.name = "RhombusClockCaption"
			root_layout.add_child(rhombus_caption)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"magazine_cover":
			root_layout.add_child(_label("THE DAILY EDITION  /  DIGITALWORLD", 7, _accent_color()))
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
		"depth_layer":
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)
		"widget_dashboard":
			if notifications.get_child_count() > 0:
				notification_column.add_child(notifications)
			if is_instance_valid(media):
				media_column.add_child(media)
			root_layout.add_child(feature_row)
		"live_activity":
			var live_activity_caption := _label("LIVE ACTIVITY", 7, _accent_color())
			live_activity_caption.name = "LockScreenLiveActivityCaption"
			root_layout.add_child(live_activity_caption)
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
			root_layout.add_child(personal_zones)
		"now_bar":
			var now_bar := VBoxContainer.new()
			now_bar.name = "LockScreenNowBar"
			if is_instance_valid(media): now_bar.add_child(media)
			if notifications.get_child_count() > 0: now_bar.add_child(notifications)
			root_layout.add_child(now_bar)
		"notification_stack":
			var notification_stack_caption := _label("NOTIFICATIONS", 7, _accent_color())
			notification_stack_caption.name = "LockScreenNotificationStackCaption"
			root_layout.add_child(notification_stack_caption)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"pixel_at_a_glance":
			root_layout.add_child(_label("AT A GLANCE  ·  YOUR DAY", 7, _accent_color()))
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"pixel_large_clock":
			var pixel_caption := _label("PIXEL  ·  AT A GLANCE", 7, _accent_color())
			pixel_caption.name = "PixelLargeClockCaption"
			root_layout.add_child(pixel_caption)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"pixel_ambient":
			root_layout.add_child(_label("MON  ·  DIGITALWORLD", 7, _muted_color()))
		"huawei_magazine":
			var huawei_caption := _label("MONDAY  /  YOUR PERSONAL EDITION", 7, _accent_color())
			huawei_caption.name = "HuaweiMagazineCaption"
			root_layout.add_child(huawei_caption)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"huawei_dynamic":
			var dynamic_row := VBoxContainer.new()
			dynamic_row.name = "HuaweiDynamicActivity"
			if is_instance_valid(media): dynamic_row.add_child(media)
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
			root_layout.add_child(widget_grid)
		"origin_player":
			var origin_player_activity := VBoxContainer.new()
			origin_player_activity.name = "OriginPlayerActivity"
			if is_instance_valid(media): origin_player_activity.add_child(media)
			root_layout.add_child(origin_player_activity)
			root_layout.add_child(notifications)
		"coloros_typography":
			var typography_rule := ColorRect.new()
			typography_rule.custom_minimum_size.y = 3
			typography_rule.color = _accent_color()
			root_layout.add_child(typography_rule)
			root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"coloros_flux":
			var flux_column := VBoxContainer.new()
			if is_instance_valid(media): flux_column.add_child(media)
			root_layout.add_child(flux_column)
			root_layout.add_child(notifications)
		"clean_android":
			var clean_android_caption := _label("MONDAY  ·  YOUR DAY", 7, _muted_color())
			clean_android_caption.name = "LockScreenCleanAndroidDate"
			root_layout.add_child(clean_android_caption)
			if notifications.get_child_count() > 0: root_layout.add_child(notifications)
			if is_instance_valid(media): root_layout.add_child(media)
		"focus_lock_screen":
			root_layout.add_child(_label("FOCUS  /  PERSONAL", 7, _accent_color()))
			if is_instance_valid(media): root_layout.add_child(media)
			root_layout.add_child(notifications)

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
		fingerprint_stage.custom_minimum_size.y = 46
		fingerprint_stage.add_child(fingerprint)
		root_layout.add_child(fingerprint_stage)
	root_layout.add_child(shortcuts)
	page_container = original_container

	# Every widget that is used has now been moved into the rendered layout.
	# Release the empty staging bank and any template-only containers that this
	# particular layout did not adopt.
	if bank.get_parent() == original_container:
		original_container.remove_child(bank)
		bank.free()
	for unused_control in [top_space, notifications, feature_row]:
		if is_instance_valid(unused_control) and unused_control.get_parent() == null:
			unused_control.free()


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
	card.custom_minimum_size.y = 38
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 30
	row.add_theme_constant_override("separation", 7)
	var app_icon := PanelContainer.new()
	app_icon.custom_minimum_size = Vector2(26, 26)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = _accent_color().darkened(0.42)
	icon_style.set_corner_radius_all(9)
	app_icon.add_theme_stylebox_override("panel", icon_style)
	var icon_label := _label("✉" if app_name == "Messages" else "▦", 16, _text_color())
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(24, 24)
	app_icon.add_child(icon_label)
	row.add_child(app_icon)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 25)
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

	player.custom_minimum_size.y = 54
	var player_content := VBoxContainer.new()
	player_content.custom_minimum_size.y = 46
	player_content.add_theme_constant_override("separation", 3)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var artwork := PanelContainer.new()
	artwork.name = "LockScreenAudioArtwork"
	artwork.custom_minimum_size = Vector2(28, 28)
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


func _make_lock_shortcut(icon_texture: Texture2D, treatment: String, action_name: String) -> Button:
	var button := Button.new()
	button.name = "LockScreenShortcut_" + action_name
	button.text = ""
	button.custom_minimum_size = Vector2(42, 42)
	button.clip_contents = true
	_style_lock_button(button, treatment)

	# Keep imported artwork in a plain TextureRect rather than Button.icon.
	# This avoids theme-dependent icon sizing/tint differences on Android.
	var icon_view := TextureRect.new()
	icon_view.name = "LockScreenShortcutIcon_" + action_name
	icon_view.texture = icon_texture
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var original_artwork_size := button.custom_minimum_size - Vector2.ONE * 16.0
	var scaled_artwork_size := original_artwork_size * LOCKSCREEN_SHORTCUT_ICON_SCALE
	var artwork_inset := (button.custom_minimum_size - scaled_artwork_size) * 0.5
	icon_view.offset_left = artwork_inset.x
	icon_view.offset_top = artwork_inset.y
	icon_view.offset_right = -artwork_inset.x
	icon_view.offset_bottom = -artwork_inset.y
	button.add_child(icon_view)

	if action_name == "Flashlight":
		button.toggle_mode = true
		button.toggled.connect(func(enabled: bool):
			icon_view.modulate = Color("#C8E8FF") if enabled else Color.WHITE
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



func _build_pin_input() -> void:
	var layout := VBoxContainer.new()
	layout.name = "PINInputScreen"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 3)
	page_container.add_child(layout)

	var top_space := Control.new()
	top_space.name = "PINTopFlexibleSpace"
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(top_space)

	var lock_indicator_stage := CenterContainer.new()
	lock_indicator_stage.name = "PINLockIndicatorStage"
	lock_indicator_stage.custom_minimum_size.y = 18
	var lock_indicator := PINLockIndicator.new()
	lock_indicator.name = "PINLockIndicator"
	lock_indicator_stage.add_child(lock_indicator)
	layout.add_child(lock_indicator_stage)

	var title := _label("Enter PIN", 17, _text_color())
	title.name = "PINEntryTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 21
	layout.add_child(title)
	var subtitle := _label("Your PIN contains at least 4 digits.", 8, _muted_color())
	subtitle.name = "PINEntrySubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size.y = 12
	layout.add_child(subtitle)

	var dots := _label("○   ○   ○   ○", 16, _text_color())
	dots.name = "PINEntryDots"
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dots.custom_minimum_size.y = 23
	layout.add_child(dots)

	var error_label := _label(_pin_error_message, 8, Color("#FF9AA8"))
	error_label.name = "PINEntryError"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.custom_minimum_size.y = 12
	layout.add_child(error_label)

	var keypad := GridContainer.new()
	keypad.name = "PINKeypad"
	keypad.columns = 3
	keypad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var keypad_gap := clampf(size.x * 0.045, 5.0, 10.0)
	keypad.add_theme_constant_override("h_separation", roundi(keypad_gap))
	keypad.add_theme_constant_override("v_separation", roundi(keypad_gap))
	var available_keypad_width := maxf(100.0, size.x - 40.0)
	var key_size := clampf((available_keypad_width - keypad_gap * 2.0) / 3.0, 32.0, 60.0)
	var pin_keys := [
		{"id":"1", "number":"1"}, {"id":"2", "number":"2"}, {"id":"3", "number":"3"},
		{"id":"4", "number":"4"}, {"id":"5", "number":"5"}, {"id":"6", "number":"6"},
		{"id":"7", "number":"7"}, {"id":"8", "number":"8"}, {"id":"9", "number":"9"},
		{"id":"Delete", "number":"⌫"}, {"id":"0", "number":"0"}, {"id":"OK", "number":"OK"}
	]
	for key_data in pin_keys:
		var key_id := str(key_data["id"])
		var key := Button.new()
		key.name = "PINKey_" + key_id
		# Put the value directly on the Button. The old empty button text relied
		# on nested labels that could be clipped by the phone preview viewport.
		key.text = str(key_data["number"])
		key.alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.custom_minimum_size = Vector2.ONE * key_size
		key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.clip_contents = false
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.90, 0.95, 1.0, 0.11)
		# Keep each key visually independent: no outlines or drop shadows
		# that can join into connector-like lines between adjacent glass keys.
		normal.border_color = Color(1.0, 1.0, 1.0, 0.0)
		normal.set_border_width_all(0)
		normal.set_corner_radius_all(999)
		normal.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
		normal.shadow_size = 0
		normal.shadow_offset = Vector2.ZERO
		normal.content_margin_left = 0
		normal.content_margin_right = 0
		normal.content_margin_top = 0
		normal.content_margin_bottom = 0
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.94, 0.97, 1.0, 0.18)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.82, 0.90, 1.0, 0.23)
		key.add_theme_stylebox_override("normal", normal)
		key.add_theme_stylebox_override("hover", hover)
		key.add_theme_stylebox_override("pressed", pressed)
		key.add_theme_stylebox_override("focus", normal)
		key.add_theme_color_override("font_color", Color("#F7FAFF"))
		key.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
		key.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))
		key.add_theme_color_override("font_disabled_color", Color("#E5EDF7"))
		key.add_theme_font_override("font", LOCKSCREEN_FONT)
		key.add_theme_font_size_override("font_size", 17 if key_size >= 44.0 else 15)
		key.focus_mode = Control.FOCUS_NONE
		key.mouse_filter = Control.MOUSE_FILTER_STOP

		match key_id:
			"Delete":
				key.pressed.connect(_on_pin_delete_pressed)
			"OK":
				key.pressed.connect(_on_pin_submit_pressed)
			_:
				key.pressed.connect(_on_pin_digit_pressed.bind(key_id))
		keypad.add_child(key)
	layout.add_child(keypad)

	var lock_data: Dictionary = configuration.get("components", {}).get("lock_screen", {})
	if bool(lock_data.get("show_fingerprint", false)) and bool(lock_data.get("fingerprint_sensor_available", false)):
		var fingerprint_stage := CenterContainer.new()
		fingerprint_stage.name = "PINFingerprintStage"
		fingerprint_stage.custom_minimum_size.y = 36
		var fingerprint := LockScreenFingerprintButton.new()
		fingerprint.name = "PINFingerprintSensor"
		fingerprint.custom_minimum_size = Vector2(34, 34)
		fingerprint.tooltip_text = "Unlock with fingerprint"
		fingerprint.pressed.connect(func(): set_component_view("home_screen"))
		fingerprint_stage.add_child(fingerprint)
		fingerprint.custom_minimum_size = Vector2(36, 36)
		layout.add_child(fingerprint_stage)

	var emergency_button := Button.new()
	emergency_button.name = "PINEmergencyCallButton"
	emergency_button.text = "Emergency call"
	emergency_button.custom_minimum_size = Vector2(112, 28)
	emergency_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var emergency_style := StyleBoxFlat.new()
	emergency_style.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	emergency_style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	emergency_style.set_border_width_all(1)
	emergency_style.set_corner_radius_all(18)
	emergency_style.content_margin_left = 12
	emergency_style.content_margin_right = 12
	emergency_style.content_margin_top = 4
	emergency_style.content_margin_bottom = 4
	emergency_button.add_theme_stylebox_override("normal", emergency_style)
	emergency_button.add_theme_stylebox_override("hover", emergency_style.duplicate())
	emergency_button.add_theme_stylebox_override("pressed", emergency_style.duplicate())
	emergency_button.add_theme_color_override("font_color", Color("#F4F6FA"))
	emergency_button.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	emergency_button.add_theme_font_size_override("font_size", 8)
	emergency_button.focus_mode = Control.FOCUS_NONE
	emergency_button.pressed.connect(_on_pin_emergency_pressed)
	layout.add_child(emergency_button)

	var info := PanelContainer.new()
	info.name = "PINPreviewUnlockInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	info_style.set_border_width_all(0)
	info_style.content_margin_left = 0
	info_style.content_margin_right = 0
	info_style.content_margin_top = 0
	info_style.content_margin_bottom = 0
	info.add_theme_stylebox_override("panel", info_style)
	var info_label := _label("Preview PIN  ·  1234", 6, Color(1.0, 1.0, 1.0, 0.62))
	info_label.name = "PINPreviewUnlockInfoLabel"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(info_label)
	layout.add_child(info)

	var bottom_space := Control.new()
	bottom_space.name = "PINBottomFlexibleSpace"
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(bottom_space)


func _on_pin_submit_pressed() -> void:
	if _entered_unlock_pin.length() != 4:
		_pin_error_message = "Enter your 4-digit PIN."
		_refresh_pin_entry_display()
		return
	if _entered_unlock_pin == PHONE_UNLOCK_PIN:
		_entered_unlock_pin = ""
		call_deferred("set_component_view", "home_screen")
	else:
		_entered_unlock_pin = ""
		_pin_error_message = "Incorrect PIN. Use 1234 for this preview."
		_refresh_pin_entry_display()


func _on_pin_emergency_pressed() -> void:
	_pin_error_message = "Emergency calling is unavailable in this preview."
	_refresh_pin_entry_display()


func _on_pin_digit_pressed(digit: String) -> void:
	if _entered_unlock_pin.length() >= 4:
		return
	_entered_unlock_pin += digit
	_pin_error_message = ""
	_refresh_pin_entry_display()
	if _entered_unlock_pin.length() == 4:
		_on_pin_submit_pressed()


func _on_pin_delete_pressed() -> void:
	if not _entered_unlock_pin.is_empty():
		_entered_unlock_pin = _entered_unlock_pin.left(_entered_unlock_pin.length() - 1)
	_pin_error_message = ""
	_refresh_pin_entry_display()


func _refresh_pin_entry_display() -> void:
	var dots := find_child("PINEntryDots", true, false) as Label
	if is_instance_valid(dots):
		var display := ""
		for index in range(4):
			display += "●" if index < _entered_unlock_pin.length() else "○"
			if index < 3:
				display += "  "
		dots.text = display
	var error_label := find_child("PINEntryError", true, false) as Label
	if is_instance_valid(error_label):
		error_label.text = _pin_error_message
		error_label.visible = not _pin_error_message.is_empty()


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
	holder.name = "CenterContainer"
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := Button.new()
	icon.name = "Button"
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
