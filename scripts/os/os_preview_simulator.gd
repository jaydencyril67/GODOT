extends Control

signal app_opened(app_name: String)

const OSEngine = preload("res://scripts/os/procedural_os_engine.gd")
const PHONE_UNLOCK_PIN := "1234"
# Load imported assets after the simulator enters the scene tree. Preloading these
# font/SVG resources during a clean-checkout script scan fails before Godot imports them.
var LOCKSCREEN_FONT: FontFile
var LOCKSCREEN_CAMERA_TEXTURE: Texture2D
var LOCKSCREEN_FLASHLIGHT_TEXTURE: Texture2D
const LOCKSCREEN_SHORTCUT_ICON_SCALE := 0.81
var STATUS_CELLULAR_TEXTURE: Texture2D
var STATUS_WIFI_TEXTURE: Texture2D
var STATUS_BATTERY_TEXTURE: Texture2D

class PINLockIndicator extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(28, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var center_x := size.x * 0.5
		draw_arc(Vector2(center_x, 8.0), 4.0, PI, TAU, 20, Color("#F4F6FA"), 1.5, true)
		draw_rect(Rect2(Vector2(center_x - 5.0, 7.0), Vector2(10.0, 9.0)), Color("#F4F6FA"))
		draw_circle(Vector2(center_x, 11.0), 1.0, Color("#263244"))


class OreoLockShortcutButton extends Button:
	var shortcut_id := "assistant"

	func _ready() -> void:
		text = ""
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(42, 42)
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var icon_color := Color("#FFFFFF")
		if is_pressed():
			draw_circle(centre, 15.0, Color(1, 1, 1, 0.12))
		match shortcut_id:
			"assistant":
				draw_rect(Rect2(centre + Vector2(-3.2, -9.0), Vector2(6.4, 13.0)), icon_color, false, 1.8, true)
				draw_arc(centre + Vector2(0, 0.0), 7.0, 0.0, PI, 32, icon_color, 1.8, true)
				draw_line(centre + Vector2(0, 7.0), centre + Vector2(0, 10.0), icon_color, 1.8, true)
				draw_line(centre + Vector2(-5.0, 10.0), centre + Vector2(5.0, 10.0), icon_color, 1.8, true)
			"camera":
				draw_rect(Rect2(centre + Vector2(-10.0, -5.0), Vector2(20.0, 14.0)), icon_color, false, 1.8, true)
				draw_rect(Rect2(centre + Vector2(-4.5, -8.0), Vector2(9.0, 3.0)), icon_color, false, 1.6, true)
				draw_circle(centre + Vector2(0, 2.0), 4.2, icon_color, false, 1.8, true)
				draw_circle(centre + Vector2(0, 2.0), 1.4, icon_color)


class OreoLockCenterGlyph extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(32, 38)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var icon_color := Color("#FFFFFF")
		draw_arc(centre + Vector2(0, -3.0), 7.0, PI, TAU, 28, icon_color, 1.8, true)
		draw_rect(Rect2(centre + Vector2(-8.0, -2.0), Vector2(16.0, 13.0)), icon_color, false, 1.8, true)
		draw_circle(centre + Vector2(0, 3.0), 1.3, icon_color)
		draw_line(centre + Vector2(0, 4.0), centre + Vector2(0, 7.0), icon_color, 1.4, true)


class AndroidNavigationButton extends Button:
	var action_name := "Back"
	var icon_color := Color.WHITE

	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(30, 44)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var color := icon_color
		if is_pressed():
			draw_circle(centre, 13.0, Color(color.r, color.g, color.b, 0.12))
		match action_name:
			"Back":
				draw_colored_polygon(PackedVector2Array([
					centre + Vector2(-9, 0),
					centre + Vector2(4, -9),
					centre + Vector2(4, 9)
				]), color)
			"Home":
				draw_arc(centre, 8.0, 0.0, TAU, 40, color, 2.0, true)
			"Overview":
				draw_rect(Rect2(centre - Vector2(7, 7), Vector2(14, 14)), color, false, 2.0, true)


class OSScreenCornerMask extends Control:
	var corner_radius := 22.0
	var mask_color := Color.BLACK
	var mask_bottom_corners := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var radius := minf(corner_radius, minf(size.x, size.y) * 0.5)
		var segments := 8
		var centers := [
			Vector2(radius, radius),
			Vector2(size.x - radius, radius),
			Vector2(size.x - radius, size.y - radius),
			Vector2(radius, size.y - radius)
		]
		# Each polygon starts at the physical screen corner, then follows
		# the start of its quarter-circle arc. Keeping this order consistent
		# prevents the top-left and bottom-right masks from folding inward.
		var outer_points := [
			[Vector2.ZERO, Vector2(0.0, radius)],
			[Vector2(size.x, 0.0), Vector2(size.x - radius, 0.0)],
			[Vector2(size.x, size.y), Vector2(size.x, size.y - radius)],
			[Vector2(0.0, size.y), Vector2(radius, size.y)]
		]
		var angle_ranges := [[-PI, -PI * 0.5], [-PI * 0.5, 0.0], [0.0, PI * 0.5], [PI * 0.5, PI]]
		for index in range(4):
			if not mask_bottom_corners and index >= 2:
				continue
			var polygon := PackedVector2Array()
			polygon.append(outer_points[index][0])
			polygon.append(outer_points[index][1])
			for step in range(segments + 1):
				var angle := lerpf(angle_ranges[index][0], angle_ranges[index][1], float(step) / float(segments))
				polygon.append(centers[index] + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(polygon, mask_color)


class LollipopAppDrawerButton extends Button:
	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(34, 34)
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		queue_redraw()

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var centre := size * 0.5
		draw_circle(centre, side * 0.45, Color("#FFFFFF"))
		for row_index in range(3):
			for column_index in range(2):
				var point := centre + Vector2((float(column_index) - 0.5) * side * 0.19, (float(row_index) - 1.0) * side * 0.19)
				draw_circle(point, maxf(1.0, side * 0.035), Color("#737373"))


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
			"lollipop":
				# Android 5.0's signature blue/teal geometric Nexus wallpaper.
				draw_rect(Rect2(Vector2.ZERO, size), Color("#234D73"))
				var facet_a := PackedVector2Array([
					Vector2(0, size.y * 0.08), Vector2(size.x * 0.54, 0),
					Vector2(size.x * 0.72, size.y * 0.34), Vector2(size.x * 0.22, size.y * 0.53)
				])
				var facet_b := PackedVector2Array([
					Vector2(size.x * 0.54, 0), Vector2(size.x, 0),
					Vector2(size.x, size.y * 0.48), Vector2(size.x * 0.72, size.y * 0.34)
				])
				var facet_c := PackedVector2Array([
					Vector2(0, size.y * 0.08), Vector2(size.x * 0.22, size.y * 0.53),
					Vector2(size.x * 0.10, size.y), Vector2(0, size.y)
				])
				var facet_d := PackedVector2Array([
					Vector2(size.x * 0.22, size.y * 0.53), Vector2(size.x * 0.72, size.y * 0.34),
					Vector2(size.x, size.y * 0.48), Vector2(size.x, size.y),
					Vector2(size.x * 0.10, size.y)
				])
				draw_colored_polygon(facet_a, Color("#176A8A"))
				draw_colored_polygon(facet_b, Color("#1687A2"))
				draw_colored_polygon(facet_c, Color("#1A3D62"))
				draw_colored_polygon(facet_d, Color("#17607E"))
				draw_colored_polygon(PackedVector2Array([
					Vector2(size.x * 0.72, size.y * 0.34), Vector2(size.x, size.y * 0.48),
					Vector2(size.x * 0.63, size.y), Vector2(size.x * 0.10, size.y),
					Vector2(size.x * 0.22, size.y * 0.53)
				]), Color("#267E91"))
				draw_line(Vector2(size.x * 0.22, size.y * 0.53), Vector2(size.x * 0.72, size.y * 0.34), Color(1, 1, 1, 0.10), 1.0, true)
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
var _screen_history: Array[String] = []
var _last_opened_app := ""
var _entered_unlock_pin := ""
var _pin_error_message := ""
var _quick_setting_states := {
	"Wi-Fi": true, "Bluetooth": true, "Airplane mode": false,
	"Auto-rotate": true, "Flashlight": false, "Location": true,
	"Cast screen": false, "Hotspot": false, "Battery saver": false
}
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
		var pie_date := find_child("PieHomeDate", true, false) as Label
		if is_instance_valid(pie_date):
			pie_date.text = _current_lock_date("minimal")



func _current_lock_time(family: String = "") -> String:
	var now := Time.get_datetime_dict_from_system()
	var hour := int(now.get("hour", 9))
	var minute := int(now.get("minute", 41))
	if family == "pixel":
		var twelve_hour := hour % 12
		if twelve_hour == 0:
			twelve_hour = 12
		return "%d:%02d" % [twelve_hour, minute]
	if family == "typographic":
		return "%02d\n%02d" % [hour, minute]
	return "%02d:%02d" % [hour, minute]


func _current_lock_date(treatment: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	var weekdays := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var weekday_index := clampi(int(now.get("weekday", 1)), 0, 6)
	var month_index := clampi(int(now.get("month", 1)) - 1, 0, 11)
	var weekday := str(weekdays[weekday_index])
	var month := str(months[month_index])
	var day := int(now.get("day", 1))
	match treatment:
		"pixel":
			return "%s, %s %d" % [weekday, month, day]
		"minimal":
			return "%s  ·  %02d %s" % [weekday.to_upper().substr(0, 3), day, month.to_upper().substr(0, 3)]
		"editorial":
			return "%s, %02d %s %04d" % [weekday.to_upper(), day, month.to_upper(), int(now.get("year", 2026))]
		"inline":
			return "%s %02d %s  ·  %04d" % [weekday.to_upper().substr(0, 3), day, month.to_upper().substr(0, 3), int(now.get("year", 2026))]
	return "%s  ·  %s %02d" % [weekday.to_upper(), month.to_upper(), day]


func _refresh_lock_screen_clock() -> void:
	var is_oreo_android := _is_android_os() and int(configuration.get("generation", 1)) == 2
	var clock := find_child("LockScreenClock", true, false) as Label
	if is_instance_valid(clock):
		clock.text = _current_lock_time("pixel" if is_oreo_android else "")
	var date := find_child("LockScreenDate", true, false) as Label
	if is_instance_valid(date):
		date.text = _current_lock_date("pixel" if is_oreo_android else "uppercase")
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
		if _gesture_overlay.name == "OSGestureOverlay_notifications" and delta.y >= vertical_threshold:
			_show_gesture_overlay("control_center")
		elif _gesture_overlay.name == "OSGestureOverlay_recent_apps" and int(configuration.get("generation", 2)) == 3:
			if delta.y <= -vertical_threshold:
				_dismiss_pie_overview_top_card()
			elif absf(delta.y) < vertical_threshold and absf(delta.x) < horizontal_threshold:
				_close_gesture_overlay()
		elif _gesture_overlay.name == "OSGestureOverlay_recent_apps":
			if delta.y <= -vertical_threshold:
				_advance_overview_deck(false)
			elif delta.y >= vertical_threshold:
				_advance_overview_deck(true)
			elif absf(delta.x) >= horizontal_threshold:
				_dismiss_overview_top_card()
			else:
				_close_gesture_overlay()
		elif delta.y <= -vertical_threshold or absf(delta.x) >= horizontal_threshold:
			_close_gesture_overlay()
		return

	if start.y <= edge_size and delta.y >= vertical_threshold and absf(delta.y) > absf(delta.x) * 1.2:
		_show_gesture_overlay("notifications")
		return

	if active_component == "lock_screen" and delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
		set_component_view("pin_input")
		return

	# Android 9 Pixel Launcher still opens its app drawer with a short upward
	# swipe from the bottom of the home screen; a longer swipe opens Overview.
	if _is_android_os() and int(configuration.get("generation", 2)) == 3 and active_component == "home_screen":
		if start.y >= size.y - edge_size and delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
			if elapsed_ms >= 420:
				_show_gesture_overlay("recent_apps")
			else:
				set_component_view("app_drawer")
			return

	# Earlier Android generations keep the physical-style three-button navigation.
	if _is_android_os():
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
	_screen_history.clear()
	set_component_view("home_screen", false)


func _navigate_back() -> void:
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		_close_gesture_overlay()
		return
	if active_component == "pin_input":
		set_component_view("lock_screen", false)
		return
	if not _screen_history.is_empty():
		var previous_screen := str(_screen_history.pop_back())
		set_component_view(previous_screen, false)
	else:
		_navigate_home()


func _show_gesture_overlay(mode: String) -> void:
	if _is_android_os() and int(configuration.get("generation", 2)) == 3:
		match mode:
			"notifications":
				_build_android_pie_notification_shade()
				return
			"control_center":
				_build_android_pie_quick_settings_shade()
				return
			"recent_apps":
				_build_android_pie_overview()
				return
	if mode == "recent_apps" and _is_android_os():
		_build_lollipop_overview()
		return
	if _is_android_os() and int(configuration.get("generation", 2)) == 1:
		match mode:
			"notifications":
				_build_lollipop_notification_shade()
				return
			"control_center":
				_build_lollipop_quick_settings_shade()
				return
			"recent_apps":
				_build_lollipop_overview()
				return

	_close_gesture_overlay()
	_gesture_overlay = Control.new()
	_gesture_overlay.name = "OSGestureOverlay_" + mode
	_gesture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gesture_overlay.offset_bottom = -54.0
	_gesture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_gesture_overlay)

	var shade := ColorRect.new()
	shade.name = "GestureOverlayShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	var title_text := "RECENT APPS" if mode == "recent_apps" else mode.to_upper().replace("_", " ")
	var title := _label(title_text, 12, _text_color())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(title)

	match mode:
		"control_center":
			_build_gesture_control_center(content)
		"notifications":
			_build_gesture_notifications(content)
		"recent_apps":
			_build_gesture_recent_apps(content)


func _create_lollipop_shade_overlay(mode: String, background_color: Color) -> Control:
	_close_gesture_overlay()
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_" + mode
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -46.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_gesture_overlay = overlay

	var background := ColorRect.new()
	background.name = "LollipopShadeBackground"
	background.color = background_color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	return overlay


func _create_lollipop_shade_body(overlay: Control) -> VBoxContainer:
	var margins := MarginContainer.new()
	margins.name = "LollipopShadeMargins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 12)
	margins.add_theme_constant_override("margin_right", 12)
	margins.add_theme_constant_override("margin_top", 10)
	margins.add_theme_constant_override("margin_bottom", 8)
	overlay.add_child(margins)

	var scroll := ScrollContainer.new()
	scroll.name = "LollipopShadeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	margins.add_child(scroll)

	var body := VBoxContainer.new()
	body.name = "LollipopShadeContent"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)
	return body


func _create_android_pie_shade(mode: String) -> Control:
	_close_gesture_overlay()
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_" + mode
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -46.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_gesture_overlay = overlay
	var background := ColorRect.new()
	background.name = "PieShadeBackground"
	background.color = Color("#E8ECF3")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	var margins := MarginContainer.new()
	margins.name = "PieShadeMargins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 12)
	margins.add_theme_constant_override("margin_right", 12)
	margins.add_theme_constant_override("margin_top", 9)
	margins.add_theme_constant_override("margin_bottom", 8)
	overlay.add_child(margins)
	var scroll := ScrollContainer.new()
	scroll.name = "PieShadeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	margins.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "PieShadeContent"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	scroll.add_child(body)
	return overlay


func _add_pie_shade_header(parent: Control) -> void:
	var header := HBoxContainer.new()
	header.name = "PieShadeHeader"
	header.add_theme_constant_override("separation", 8)
	var time_stack := VBoxContainer.new()
	time_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clock := _label(_current_lock_time("pixel"), 25, Color("#202124"))
	clock.name = "PieShadeClock"
	clock.custom_minimum_size.y = 30
	clock.add_theme_font_override("font", LOCKSCREEN_FONT)
	time_stack.add_child(clock)
	time_stack.add_child(_label(_current_lock_date("pixel"), 9, Color("#5F6368")))
	header.add_child(time_stack)
	var battery := _label("100%  ▰", 9, Color("#5F6368"))
	battery.name = "PieShadeBattery"
	battery.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(battery)
	parent.add_child(header)


func _pie_quick_tile_style(enabled: bool) -> StyleBoxFlat:
	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = Color("#4285F4") if enabled else Color("#DADCE0")
	tile_style.set_corner_radius_all(999)
	tile_style.set_border_width_all(0)
	tile_style.content_margin_left = 0
	tile_style.content_margin_right = 0
	tile_style.content_margin_top = 0
	tile_style.content_margin_bottom = 0
	return tile_style


func _add_android_pie_quick_tile(parent: GridContainer, definition: Dictionary) -> void:
	var setting_id := str(definition.get("id", ""))
	var safe_id := setting_id.replace(" ", "")
	var enabled := bool(_quick_setting_states.get(setting_id, definition.get("enabled", false)))
	var item := VBoxContainer.new()
	item.name = "PieQuickTileItem_" + safe_id
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 2)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tile := Button.new()
	tile.name = "PieQuickTile_" + safe_id
	tile.toggle_mode = true
	tile.button_pressed = enabled
	tile.custom_minimum_size = Vector2(43, 43)
	tile.focus_mode = Control.FOCUS_NONE
	tile.add_theme_stylebox_override("normal", _pie_quick_tile_style(enabled))
	tile.add_theme_stylebox_override("hover", _pie_quick_tile_style(enabled))
	tile.add_theme_stylebox_override("pressed", _pie_quick_tile_style(not enabled))
	tile.add_theme_stylebox_override("focus", _pie_quick_tile_style(enabled))
	tile.add_theme_color_override("font_color", Color.WHITE if enabled else Color("#5F6368"))
	tile.add_theme_font_size_override("font_size", 19)
	tile.text = str(definition.get("glyph", "•"))
	tile.tooltip_text = setting_id
	holder.add_child(tile)
	item.add_child(holder)
	var label := _label(setting_id, 8, Color("#3C4043"))
	label.name = "PieQuickTileLabel_" + safe_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.y = 17
	item.add_child(label)
	tile.toggled.connect(_on_pie_quick_tile_toggled.bind(setting_id, tile, label))
	parent.add_child(item)


func _on_pie_quick_tile_toggled(enabled: bool, setting_id: String, tile: Button, label: Label) -> void:
	_quick_setting_states[setting_id] = enabled
	var style := _pie_quick_tile_style(enabled)
	if is_instance_valid(tile):
		for state_name in ["normal", "hover", "pressed", "focus"]:
			tile.add_theme_stylebox_override(state_name, style)
		tile.add_theme_color_override("font_color", Color.WHITE if enabled else Color("#5F6368"))
	if is_instance_valid(label):
		label.add_theme_color_override("font_color", Color("#3C4043") if enabled else Color("#5F6368"))


func _pie_quick_tile_definitions() -> Array:
	return [
		{"id": "Wi-Fi", "glyph": "◉", "enabled": true},
		{"id": "Bluetooth", "glyph": "ᛒ", "enabled": true},
		{"id": "Do not disturb", "glyph": "⊖", "enabled": false},
		{"id": "Airplane mode", "glyph": "✈", "enabled": false},
		{"id": "Auto-rotate", "glyph": "⟳", "enabled": true},
		{"id": "Battery saver", "glyph": "▰", "enabled": false},
		{"id": "Flashlight", "glyph": "☼", "enabled": false},
		{"id": "Location", "glyph": "⌖", "enabled": true},
		{"id": "Hotspot", "glyph": "⌁", "enabled": false}
	]


func _add_pie_brightness_slider(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "PieBrightnessPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#DADCE0")
	panel_style.set_corner_radius_all(18)
	panel_style.set_border_width_all(0)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", panel_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.add_child(_label("☼", 17, Color("#5F6368")))
	var slider := HSlider.new()
	slider.name = "PieBrightnessSlider"
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 72
	slider.custom_minimum_size.y = 20
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	row.add_child(_label("☀", 13, Color("#5F6368")))
	panel.add_child(row)
	parent.add_child(panel)


func _add_pie_notification_card(parent: Control, app_name: String, message_text: String, time_text: String, icon_text: String, icon_color: Color) -> void:
	var card := PanelContainer.new()
	card.name = "PieNotification_" + app_name.replace(" ", "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#F8F9FA")
	card_style.set_corner_radius_all(14)
	card_style.set_border_width_all(0)
	card_style.content_margin_left = 10
	card_style.content_margin_right = 10
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(27, 27)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = icon_color
	icon_style.set_corner_radius_all(14)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	var icon := _label(icon_text, 8, Color.WHITE)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_panel.add_child(icon)
	row.add_child(icon_panel)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	var title_row := HBoxContainer.new()
	var title := _label(app_name, 8, Color("#202124"))
	title.name = "PieNotificationTitle_" + app_name.replace(" ", "")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(_label(time_text, 7, Color("#5F6368")))
	copy.add_child(title_row)
	var message := _label(message_text, 9, Color("#3C4043"))
	message.name = "PieNotificationMessage_" + app_name.replace(" ", "")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(message)
	row.add_child(copy)
	parent.add_child(card)


func _apply_android_pie_shade_screen_mask(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.clip_contents = true
	var mask := OSScreenCornerMask.new()
	mask.name = "PieShadeScreenCornerMask"
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.corner_radius = 22.0
	mask.mask_color = Color.BLACK
	mask.mask_bottom_corners = false
	mask.z_index = 100
	overlay.add_child(mask)


func _build_android_pie_notification_shade() -> void:
	var overlay := _create_android_pie_shade("notifications")
	var body := overlay.find_child("PieShadeContent", true, false) as VBoxContainer
	if body == null:
		return
	_add_pie_shade_header(body)
	var quick_grid := GridContainer.new()
	quick_grid.name = "PieNotificationQuickSettingsGrid"
	quick_grid.columns = 3
	quick_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_grid.add_theme_constant_override("h_separation", 2)
	quick_grid.add_theme_constant_override("v_separation", 3)
	for definition in _pie_quick_tile_definitions().slice(0, 6):
		_add_android_pie_quick_tile(quick_grid, definition)
	body.add_child(quick_grid)
	var notification_heading := _label("Notifications", 10, Color("#5F6368"))
	notification_heading.name = "PieNotificationHeading"
	body.add_child(notification_heading)
	_add_pie_notification_card(body, "Messages", "Alex Morgan  ·  Are we still meeting today?", "NOW", "M", Color("#4285F4"))
	_add_pie_notification_card(body, "Calendar", "Your event starts in 10 minutes", "10 MIN", "31", Color("#4285F4"))
	_add_pie_notification_card(body, "Android System", "Device is up to date", "EARLIER", "A", Color("#5F6368"))
	body.add_child(_label("Swipe down again for all Quick Settings", 8, Color("#5F6368")))
	_apply_android_pie_shade_screen_mask(overlay)


func _build_android_pie_quick_settings_shade() -> void:
	var overlay := _create_android_pie_shade("control_center")
	var body := overlay.find_child("PieShadeContent", true, false) as VBoxContainer
	if body == null:
		return
	_add_pie_shade_header(body)
	_add_pie_brightness_slider(body)
	var grid := GridContainer.new()
	grid.name = "PieExpandedQuickSettingsGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 5)
	for definition in _pie_quick_tile_definitions():
		_add_android_pie_quick_tile(grid, definition)
	body.add_child(grid)
	var page_row := CenterContainer.new()
	page_row.name = "PieQuickSettingsPageIndicator"
	page_row.add_child(_label("●  ○", 8, Color("#5F6368")))
	body.add_child(page_row)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	var settings_button := Button.new()
	settings_button.name = "PieQuickSettingsSettingsButton"
	settings_button.text = "⚙  Settings"
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.pressed.connect(func() -> void:
		_close_gesture_overlay()
		_on_app_pressed("Settings")
	)
	footer.add_child(settings_button)
	body.add_child(footer)
	_apply_android_pie_shade_screen_mask(overlay)


func _build_android_pie_notifications_preview() -> void:
	var panel := PanelContainer.new()
	panel.name = "PieNotificationPreview"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#E8ECF3")
	style.set_corner_radius_all(16)
	style.set_border_width_all(0)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	page_container.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	panel.add_child(body)
	_add_pie_shade_header(body)
	var compact_grid := GridContainer.new()
	compact_grid.name = "PieNotificationQuickSettingsGrid"
	compact_grid.columns = 3
	for definition in _pie_quick_tile_definitions().slice(0, 6):
		_add_android_pie_quick_tile(compact_grid, definition)
	body.add_child(compact_grid)
	body.add_child(_label("Notifications", 9, Color("#5F6368")))
	_add_pie_notification_card(body, "Messages", "Alex Morgan  ·  Are we still meeting today?", "NOW", "M", Color("#4285F4"))
	_add_pie_notification_card(body, "Calendar", "Your event starts in 10 minutes", "10 MIN", "31", Color("#4285F4"))


func _build_android_pie_control_center_preview() -> void:
	var panel := PanelContainer.new()
	panel.name = "PieControlCenterPreview"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#E8ECF3")
	style.set_corner_radius_all(16)
	style.set_border_width_all(0)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	page_container.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	panel.add_child(body)
	_add_pie_shade_header(body)
	_add_pie_brightness_slider(body)
	var grid := GridContainer.new()
	grid.name = "PieExpandedQuickSettingsGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 4)
	for definition in _pie_quick_tile_definitions():
		_add_android_pie_quick_tile(grid, definition)
	body.add_child(grid)
	body.add_child(_label("●  ○    ·    Settings", 8, Color("#5F6368")))


func _build_lollipop_notification_shade() -> void:
	var overlay := _create_lollipop_shade_overlay("notifications", Color(0.025, 0.045, 0.060, 0.76))
	var body := _create_lollipop_shade_body(overlay)
	_build_lollipop_notification_content(body)
	var hint := _label("Swipe down again for Quick Settings", 9, Color("#CFD8DC"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.y = 25
	body.add_child(hint)
	_apply_lollipop_shade_screen_mask(overlay)


func _build_lollipop_notification_content(parent: Control) -> void:
	var header := HBoxContainer.new()
	header.name = "LollipopNotificationHeader"
	header.add_theme_constant_override("separation", 8)
	var time_stack := VBoxContainer.new()
	time_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clock_label := _label(_current_lock_time(), 27, Color("#FFFFFF"))
	clock_label.custom_minimum_size.y = 34
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_stack.add_child(clock_label)
	var date_label := _label(_current_lock_date("editorial"), 10, Color("#CFD8DC"))
	date_label.custom_minimum_size.y = 16
	date_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_stack.add_child(date_label)
	header.add_child(time_stack)

	var header_status := VBoxContainer.new()
	header_status.alignment = BoxContainer.ALIGNMENT_CENTER
	header_status.add_child(_label("100%  ▰", 10, Color("#FFFFFF")))
	header_status.add_child(_label("Wi-Fi  ·  LTE", 8, Color("#CFD8DC")))
	header.add_child(header_status)
	parent.add_child(header)

	var divider := ColorRect.new()
	divider.name = "LollipopNotificationHeaderDivider"
	divider.custom_minimum_size.y = 1
	divider.color = Color(1, 1, 1, 0.22)
	parent.add_child(divider)

	parent.add_child(_label("NOTIFICATIONS", 10, Color("#ECEFF1")))
	_add_lollipop_notification_card(parent, "Messages", "A new message is waiting", "NOW", Color("#4285F4"), "M")
	_add_lollipop_notification_card(parent, "Calendar", "Your next event is coming up", "10 MIN", Color("#0F9D58"), "31")
	_add_lollipop_notification_card(parent, "Android System", "Your device is up to date", "EARLIER", Color("#78909C"), "A")


func _add_lollipop_notification_card(parent: Control, app_name: String, message: String, time_label: String, icon_color: Color, icon_text: String) -> void:
	var card := PanelContainer.new()
	var safe_app_id := app_name.replace(" ", "")
	card.name = "LollipopNotification_" + safe_app_id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 76)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#FAFAFA")
	card_style.set_border_width_all(0)
	card_style.set_corner_radius_all(2)
	card_style.shadow_color = Color(0, 0, 0, 0.20)
	card_style.shadow_size = 5
	card_style.shadow_offset = Vector2(0, 2)
	card_style.content_margin_left = 10
	card_style.content_margin_right = 10
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 54)
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(36, 40)
	var icon_circle := PanelContainer.new()
	icon_circle.custom_minimum_size = Vector2(30, 30)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = icon_color
	icon_style.set_corner_radius_all(18)
	icon_circle.add_theme_stylebox_override("panel", icon_style)
	var icon := _label(icon_text, 12, Color("#FFFFFF"))
	icon.name = "LollipopNotificationIcon_" + safe_app_id
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	icon.add_theme_font_override("font", LOCKSCREEN_FONT)
	icon_circle.add_child(icon)
	icon_holder.add_child(icon_circle)
	row.add_child(icon_holder)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_stack.custom_minimum_size = Vector2(100, 40)
	text_stack.add_theme_constant_override("separation", 1)
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.custom_minimum_size.y = 16
	var app_label := _label(app_name, 10, Color("#455A64"))
	app_label.name = "LollipopNotificationApp_" + safe_app_id
	app_label.custom_minimum_size.y = 16
	app_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	app_label.clip_text = true
	title_row.add_child(app_label)
	var time := _label(time_label, 8, Color("#78909C"))
	time.name = "LollipopNotificationTime_" + safe_app_id
	time.custom_minimum_size.y = 16
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(time)
	text_stack.add_child(title_row)
	var message_label := _label(message, 11, Color("#263238"))
	message_label.name = "LollipopNotificationMessage_" + safe_app_id
	message_label.custom_minimum_size.y = 19
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.clip_text = false
	text_stack.add_child(message_label)
	row.add_child(text_stack)
	parent.add_child(card)

func _build_lollipop_quick_settings_shade() -> void:
	var overlay := _create_lollipop_shade_overlay("control_center", Color("#263238"))
	var body := _create_lollipop_shade_body(overlay)
	_build_lollipop_quick_settings_content(body, true)
	_apply_lollipop_shade_screen_mask(overlay)


func _apply_lollipop_shade_screen_mask(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.clip_contents = true
	var mask := OSScreenCornerMask.new()
	mask.name = "LollipopShadeScreenCornerMask"
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.corner_radius = 22.0
	mask.mask_color = Color.BLACK
	mask.mask_bottom_corners = false
	mask.z_index = 100
	overlay.add_child(mask)


func _build_lollipop_quick_settings_content(parent: Control, include_notifications: bool) -> void:
	var header := PanelContainer.new()
	header.name = "LollipopQuickSettingsHeader"
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color("#37474F")
	header_style.set_border_width_all(0)
	header_style.set_corner_radius_all(2)
	header_style.content_margin_left = 10
	header_style.content_margin_right = 8
	header_style.content_margin_top = 8
	header_style.content_margin_bottom = 8
	header.add_theme_stylebox_override("panel", header_style)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	var time_stack := VBoxContainer.new()
	time_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clock_label := _label(_current_lock_time(), 26, Color("#FFFFFF"))
	clock_label.custom_minimum_size.y = 32
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_stack.add_child(clock_label)
	var date_label := _label(_current_lock_date("editorial"), 10, Color("#CFD8DC"))
	date_label.custom_minimum_size.y = 16
	date_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	time_stack.add_child(date_label)
	header_row.add_child(time_stack)

	var header_actions := VBoxContainer.new()
	header_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var battery_label := _label("100%  ▰", 10, Color("#FFFFFF"))
	battery_label.custom_minimum_size.y = 16
	battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_actions.add_child(battery_label)
	var settings_button := Button.new()
	settings_button.name = "LollipopQuickSettingsOpenSettings"
	settings_button.text = "⚙"
	settings_button.tooltip_text = "Settings"
	settings_button.custom_minimum_size = Vector2(36, 32)
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.add_theme_font_size_override("font_size", 17)
	var settings_style := StyleBoxFlat.new()
	settings_style.bg_color = Color(1, 1, 1, 0.08)
	settings_style.set_corner_radius_all(2)
	settings_button.add_theme_stylebox_override("normal", settings_style)
	settings_button.add_theme_stylebox_override("hover", settings_style)
	settings_button.add_theme_stylebox_override("pressed", settings_style)
	settings_button.add_theme_color_override("font_color", Color("#FFFFFF"))
	settings_button.pressed.connect(func() -> void:
		_close_gesture_overlay()
		_on_app_pressed("Settings")
	)
	header_actions.add_child(settings_button)
	header_row.add_child(header_actions)
	header.add_child(header_row)
	parent.add_child(header)

	var brightness_panel := PanelContainer.new()
	brightness_panel.name = "LollipopBrightnessPanel"
	var brightness_style := StyleBoxFlat.new()
	brightness_style.bg_color = Color("#37474F")
	brightness_style.set_border_width_all(0)
	brightness_style.set_corner_radius_all(2)
	brightness_style.content_margin_left = 10
	brightness_style.content_margin_right = 10
	brightness_style.content_margin_top = 7
	brightness_style.content_margin_bottom = 7
	brightness_panel.add_theme_stylebox_override("panel", brightness_style)
	var brightness_row := HBoxContainer.new()
	brightness_row.add_theme_constant_override("separation", 8)
	var brightness_low := _label("☼", 20, Color("#FFFFFF"))
	brightness_low.custom_minimum_size = Vector2(24, 28)
	brightness_low.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brightness_low.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brightness_row.add_child(brightness_low)
	var brightness_slider := HSlider.new()
	brightness_slider.name = "LollipopBrightnessSlider"
	brightness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brightness_slider.min_value = 0
	brightness_slider.max_value = 100
	brightness_slider.value = 72
	brightness_slider.custom_minimum_size.y = 24
	brightness_slider.focus_mode = Control.FOCUS_NONE
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color("#607D8B")
	slider_track.set_corner_radius_all(4)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	brightness_slider.add_theme_stylebox_override("slider", slider_track)
	var slider_active := StyleBoxFlat.new()
	slider_active.bg_color = Color("#B0BEC5")
	slider_active.set_corner_radius_all(4)
	brightness_slider.add_theme_stylebox_override("grabber_area", slider_active)
	brightness_slider.add_theme_stylebox_override("grabber_area_highlight", slider_active)
	brightness_row.add_child(brightness_slider)
	var brightness_high := _label("☀", 15, Color("#FFFFFF"))
	brightness_high.custom_minimum_size = Vector2(24, 28)
	brightness_high.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brightness_high.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brightness_row.add_child(brightness_high)
	brightness_panel.add_child(brightness_row)
	parent.add_child(brightness_panel)

	var grid := GridContainer.new()
	grid.name = "LollipopQuickSettingsGrid" if _gesture_overlay != null else "QuickSettingsGrid"
	grid.columns = 3 if size.x >= 250.0 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	var tile_definitions := [
		{"id": "Wi-Fi", "glyph": "◉", "enabled": true},
		{"id": "Bluetooth", "glyph": "ᛒ", "enabled": true},
		{"id": "Airplane mode", "glyph": "✈", "enabled": false},
		{"id": "Auto-rotate", "glyph": "⟳", "enabled": true},
		{"id": "Flashlight", "glyph": "☼", "enabled": false},
		{"id": "Location", "glyph": "⌖", "enabled": true},
		{"id": "Cast screen", "glyph": "▣", "enabled": false},
		{"id": "Hotspot", "glyph": "⌁", "enabled": false},
		{"id": "Battery saver", "glyph": "▰", "enabled": false}
	]
	for definition in tile_definitions:
		_add_lollipop_quick_setting_tile(grid, definition)

	if include_notifications:
		var notification_heading := _label("NOTIFICATIONS", 10, Color("#CFD8DC"))
		notification_heading.custom_minimum_size.y = 22
		parent.add_child(notification_heading)
		_add_lollipop_notification_card(parent, "Messages", "A new message is waiting", "NOW", Color("#4285F4"), "M")
		_add_lollipop_notification_card(parent, "Calendar", "Your next event is coming up", "10 MIN", Color("#0F9D58"), "31")


func _add_lollipop_quick_setting_tile(parent: GridContainer, definition: Dictionary) -> void:
	var setting_id := str(definition.get("id", ""))
	var safe_setting_id := setting_id.replace(" ", "")
	var tile := Button.new()
	tile.name = "LollipopQuickTile_" + safe_setting_id
	tile.toggle_mode = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.custom_minimum_size = Vector2(0, 72)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.text = ""

	var enabled := bool(_quick_setting_states.get(setting_id, definition.get("enabled", false)))
	var enabled_style := StyleBoxFlat.new()
	enabled_style.bg_color = Color("#455A64")
	enabled_style.border_color = Color("#78909C")
	enabled_style.set_border_width_all(1)
	enabled_style.set_corner_radius_all(2)
	enabled_style.content_margin_left = 3
	enabled_style.content_margin_right = 3
	enabled_style.content_margin_top = 4
	enabled_style.content_margin_bottom = 4
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color("#37474F")
	disabled_style.border_color = Color("#546E7A")
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(2)
	disabled_style.content_margin_left = 3
	disabled_style.content_margin_right = 3
	disabled_style.content_margin_top = 4
	disabled_style.content_margin_bottom = 4
	tile.add_theme_stylebox_override("normal", enabled_style if enabled else disabled_style)
	tile.add_theme_stylebox_override("hover", enabled_style if enabled else disabled_style)
	tile.add_theme_stylebox_override("pressed", enabled_style if enabled else disabled_style)
	tile.add_theme_stylebox_override("focus", enabled_style if enabled else disabled_style)

	var tile_stack := VBoxContainer.new()
	tile_stack.name = "LollipopQuickTileContent_" + safe_setting_id
	tile_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile_stack.add_theme_constant_override("separation", 1)
	tile_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	tile_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_label := _label(str(definition.get("glyph", "•")), 22, Color("#FFFFFF") if enabled else Color("#B0BEC5"))
	icon_label.name = "LollipopQuickTileIcon_" + safe_setting_id
	icon_label.custom_minimum_size = Vector2(0, 30)
	icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tile_stack.add_child(icon_label)
	var title_label := _label(setting_id, 9, Color("#FFFFFF") if enabled else Color("#B0BEC5"))
	title_label.name = "LollipopQuickTileLabel_" + safe_setting_id
	title_label.custom_minimum_size = Vector2(0, 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = false
	tile_stack.add_child(title_label)
	tile.add_child(tile_stack)
	tile.button_pressed = enabled
	tile.toggled.connect(_on_lollipop_quick_setting_toggled.bind(setting_id, icon_label, title_label, tile, enabled_style, disabled_style))
	parent.add_child(tile)


func _on_lollipop_quick_setting_toggled(enabled: bool, setting_id: String, icon_label: Label, title_label: Label, tile: Button, enabled_style: StyleBoxFlat, disabled_style: StyleBoxFlat) -> void:
	_quick_setting_states[setting_id] = enabled
	var selected_style: StyleBoxFlat = enabled_style if enabled else disabled_style
	if is_instance_valid(tile):
		tile.add_theme_stylebox_override("normal", selected_style)
		tile.add_theme_stylebox_override("hover", selected_style)
		tile.add_theme_stylebox_override("pressed", selected_style)
		tile.add_theme_stylebox_override("focus", selected_style)
	if is_instance_valid(icon_label):
		icon_label.add_theme_color_override("font_color", Color("#FFFFFF") if enabled else Color("#B0BEC5"))
	if is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", Color("#FFFFFF") if enabled else Color("#B0BEC5"))

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
		var tile_style := StyleBoxFlat.new()
		tile_style.bg_color = Color("#D8EDF5") if tile.button_pressed else Color("#ECEFF1")
		tile_style.set_corner_radius_all(3)
		for state_name in ["normal", "hover", "pressed", "focus"]:
			tile.add_theme_stylebox_override(state_name, tile_style)
		tile.add_theme_color_override("font_color", Color("#263238"))
		tile.toggled.connect(func(enabled: bool) -> void:
			tile_style.bg_color = Color("#D8EDF5") if enabled else Color("#ECEFF1")
		)
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
	var clock := _label(_current_lock_time(), 26, Color("#263238"))
	parent.add_child(clock)
	parent.add_child(_label(_current_lock_date("minimal"), 9, Color("#607D8B")))
	var quick_hint := _label("Swipe down again for Quick Settings", 8, Color("#78909C"))
	parent.add_child(quick_hint)
	for item in [
		{"app": "Messages", "message": "A new message is waiting", "time": "NOW"},
		{"app": "Calendar", "message": "Your next event is coming up", "time": "10 MIN"},
		{"app": "System", "message": "Your device is up to date", "time": "EARLIER"}
	]:
		var notification_panel := PanelContainer.new()
		notification_panel.name = "GestureNotification_" + str(item["app"])
		var notification_style := StyleBoxFlat.new()
		notification_style.bg_color = Color("#FFFFFF")
		notification_style.set_corner_radius_all(2)
		notification_style.shadow_color = Color(0, 0, 0, 0.10)
		notification_style.shadow_size = 2
		notification_panel.add_theme_stylebox_override("panel", notification_style)
		var body := VBoxContainer.new()
		body.add_child(_label(str(item["app"]) + "  ·  " + str(item["time"]), 8, Color("#607D8B")))
		body.add_child(_label(str(item["message"]), 10, Color("#263238")))
		notification_panel.add_child(body)
		parent.add_child(notification_panel)


func _build_gesture_recent_apps(parent: VBoxContainer) -> void:
	for app_name in _recent_app_names:
		var open_button := Button.new()
		open_button.name = "GestureRecentApp_" + app_name.replace(" ", "")
		open_button.text = app_name
		open_button.pressed.connect(func() -> void:
			_close_gesture_overlay()
			_on_app_pressed(app_name)
		)
		parent.add_child(open_button)


func _build_android_pie_overview() -> void:
	# Android 9 recents uses a horizontal carousel of large app snapshots.
	# Rebuild the carousel in place after dismissals to avoid flashing the launcher.
	var replacing_overview := _gesture_overlay != null and is_instance_valid(_gesture_overlay) and _gesture_overlay.name == "OSGestureOverlay_recent_apps"
	if replacing_overview:
		_gesture_overlay.queue_free()
		_gesture_overlay = null
		var old_footer := find_child("PieOverviewNavigationFooter", true, false) as Control
		if is_instance_valid(old_footer):
			old_footer.queue_free()
	else:
		_close_gesture_overlay()
		_set_lollipop_overview_underlay_visible(false)

	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_recent_apps"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_gesture_overlay = overlay

	var original_navigation := find_child("PieNavigationBar", true, false) as Control
	if is_instance_valid(original_navigation):
		original_navigation.visible = false
	var navigation_footer := VBoxContainer.new()
	navigation_footer.name = "PieOverviewNavigationFooter"
	navigation_footer.anchor_left = 0.0
	navigation_footer.anchor_right = 1.0
	navigation_footer.anchor_top = 1.0
	navigation_footer.anchor_bottom = 1.0
	navigation_footer.offset_left = 0.0
	navigation_footer.offset_right = 0.0
	navigation_footer.offset_top = -46.0
	navigation_footer.offset_bottom = 0.0
	navigation_footer.z_as_relative = false
	navigation_footer.z_index = 100
	add_child(navigation_footer)
	_build_android_navigation(navigation_footer, false, false, true, true)

	var backdrop := ColorRect.new()
	backdrop.name = "PieOverviewBackdrop"
	backdrop.color = Color(0.035, 0.055, 0.09, 0.24)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(backdrop)

	var content := VBoxContainer.new()
	content.name = "PieOverviewContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 7)
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_bottom", 4)
	overlay.add_child(content)

	var carousel := ScrollContainer.new()
	carousel.name = "PieRecentAppsCarousel"
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	carousel.scroll_deadzone = 8
	content.add_child(carousel)
	var row := HBoxContainer.new()
	row.name = "PieRecentAppsRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	carousel.add_child(row)

	if _recent_app_names.is_empty():
		var empty_state := CenterContainer.new()
		empty_state.name = "PieRecentAppsEmptyState"
		empty_state.custom_minimum_size = Vector2(maxf(120.0, size.x - 24.0), size.y * 0.48)
		empty_state.add_child(_label("No recent apps", 12, Color("#FFFFFF")))
		row.add_child(empty_state)
	else:
		for app_name in _recent_app_names:
			var app := _find_app(app_name)
			if app.is_empty():
				continue
			var card := Button.new()
			card.name = "PieRecentAppsCard_" + app_name.replace(" ", "")
			card.text = ""
			card.custom_minimum_size = Vector2(clampf(size.x * 0.72, 190.0, 290.0), maxf(210.0, size.y * 0.62))
			card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			card.focus_mode = Control.FOCUS_NONE
			card.clip_contents = true
			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color("#FFFFFF")
			card_style.set_corner_radius_all(15)
			card_style.set_border_width_all(0)
			card_style.shadow_color = Color(0, 0, 0, 0.25)
			card_style.shadow_size = 8
			card_style.shadow_offset = Vector2(0, 3)
			for state_name in ["normal", "hover", "pressed", "focus"]:
				card.add_theme_stylebox_override(state_name, card_style)
			card.pressed.connect(func() -> void:
				_close_gesture_overlay()
				_on_app_pressed(app_name)
			)
			row.add_child(card)

			var card_content := VBoxContainer.new()
			card_content.name = "PieRecentAppsCardContent_" + app_name.replace(" ", "")
			card_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_content.add_theme_constant_override("separation", 0)
			card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(card_content)

			var card_header := HBoxContainer.new()
			card_header.name = "PieRecentAppsCardHeader_" + app_name.replace(" ", "")
			card_header.custom_minimum_size.y = 39
			card_header.add_theme_constant_override("separation", 8)
			var app_icon := _label(str(app.get("glyph", "•")), 18, Color(str(app.get("color", "#4285F4"))))
			app_icon.custom_minimum_size.x = 24
			app_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card_header.add_child(app_icon)
			var app_title := _label(app_name, 11, Color("#202124"))
			app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			app_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card_header.add_child(app_title)
			card_content.add_child(card_header)

			var preview_background := ColorRect.new()
			preview_background.name = "PieRecentAppsSnapshot_" + app_name.replace(" ", "")
			preview_background.color = Color("#FFFFFF")
			preview_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
			preview_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_content.add_child(preview_background)
			var preview := VBoxContainer.new()
			preview.position = Vector2(10, 7)
			preview.size = Vector2(card.custom_minimum_size.x - 20, card.custom_minimum_size.y - 55)
			preview.add_theme_constant_override("separation", 6)
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_background.add_child(preview)
			_build_lollipop_overview_preview(preview, app_name)

	var clear_all := Button.new()
	clear_all.name = "PieRecentAppsClearAll"
	clear_all.text = "Clear all"
	clear_all.custom_minimum_size = Vector2(75, 42)
	clear_all.focus_mode = Control.FOCUS_NONE
	clear_all.add_theme_color_override("font_color", Color("#FFFFFF"))
	clear_all.add_theme_font_size_override("font_size", 10)
	clear_all.pressed.connect(_clear_pie_overview_tasks)
	row.add_child(clear_all)

	var search := PanelContainer.new()
	search.name = "PieOverviewSearchBar"
	search.custom_minimum_size.y = 37
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color("#F1F3F4")
	search_style.set_corner_radius_all(20)
	search_style.set_border_width_all(0)
	search_style.content_margin_left = 12
	search_style.content_margin_right = 12
	search_style.content_margin_top = 3
	search_style.content_margin_bottom = 3
	search.add_theme_stylebox_override("panel", search_style)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 7)
	search_row.add_child(_label("G", 18, Color("#4285F4")))
	var search_text := _label("Search", 9, Color("#5F6368"))
	search_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(search_text)
	search_row.add_child(_label("●", 9, Color("#4285F4")))
	search.add_child(search_row)
	content.add_child(search)


func _dismiss_pie_overview_top_card() -> void:
	if not _recent_app_names.is_empty():
		_dismiss_pie_overview_task(_recent_app_names[0])


func _dismiss_pie_overview_task(app_name: String) -> void:
	if not _recent_app_names.has(app_name):
		return
	_recent_app_names.erase(app_name)
	var card := find_child("PieRecentAppsCard_" + app_name.replace(" ", ""), true, false) as Control
	if is_instance_valid(card):
		card.queue_free()
	if _recent_app_names.is_empty():
		_set_pie_overview_empty_state()


func _clear_pie_overview_tasks() -> void:
	_recent_app_names.clear()
	var row := find_child("PieRecentAppsRow", true, false) as HBoxContainer
	if not is_instance_valid(row):
		return
	for child in row.get_children():
		if child.name.begins_with("PieRecentAppsCard_") or child.name == "PieRecentAppsClearAll":
			child.queue_free()
	_set_pie_overview_empty_state()


func _set_pie_overview_empty_state() -> void:
	# Scope lookups to the active Overview so stale or unrelated preview nodes
	# cannot prevent the empty state from appearing after the final task is dismissed.
	var overlay := _gesture_overlay as Control
	if not is_instance_valid(overlay) or overlay.name != "OSGestureOverlay_recent_apps":
		overlay = find_child("OSGestureOverlay_recent_apps", true, false) as Control
	if not is_instance_valid(overlay):
		return
	var row := overlay.find_child("PieRecentAppsRow", true, false) as HBoxContainer
	if not is_instance_valid(row) or is_instance_valid(row.find_child("PieRecentAppsEmptyState", false, false)):
		return
	var clear_all := row.find_child("PieRecentAppsClearAll", false, false) as Control
	if is_instance_valid(clear_all):
		clear_all.queue_free()
	var empty_state := CenterContainer.new()
	empty_state.name = "PieRecentAppsEmptyState"
	empty_state.custom_minimum_size = Vector2(maxf(120.0, size.x - 24.0), size.y * 0.48)
	empty_state.add_child(_label("No recent apps", 12, Color("#FFFFFF")))
	row.add_child(empty_state)


func _build_android_pie_recent_apps_preview() -> void:
	var note := _label("ANDROID 9 RECENT APPS", 9, Color("#5F6368"))
	note.name = "PieRecentAppsPreviewHeading"
	page_container.add_child(note)
	var preview := HBoxContainer.new()
	preview.name = "PieRecentAppsPreviewCards"
	preview.add_theme_constant_override("separation", 6)
	for app_name in ["Settings", "Messages", "Camera"]:
		var card := PanelContainer.new()
		card.name = "PieRecentAppsPreview_" + app_name
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#FFFFFF")
		style.set_corner_radius_all(12)
		style.set_border_width_all(0)
		card.add_theme_stylebox_override("panel", style)
		var body := VBoxContainer.new()
		body.add_child(_label(app_name, 8, Color("#202124")))
		body.add_child(_label("App snapshot", 7, Color("#5F6368")))
		card.add_child(body)
		preview.add_child(card)
	page_container.add_child(preview)
	page_container.add_child(_label("Swipe a card up to dismiss it", 8, Color("#5F6368")))


func _build_lollipop_overview() -> void:
	# Rebuild the task deck without running the normal close path. The close
	# path restores the launcher and navigation bar, which causes a brief
	# teardown/re-entry during repeated card dismissals and can leave only the
	# navigation controls visible on the next swipe.
	var replacing_overview := _gesture_overlay != null and is_instance_valid(_gesture_overlay) and _gesture_overlay.name == "OSGestureOverlay_recent_apps"
	if replacing_overview:
		_gesture_overlay.queue_free()
		_gesture_overlay = null
		var previous_footer := find_child("LollipopOverviewNavigationFooter", true, false) as Control
		if is_instance_valid(previous_footer):
			previous_footer.queue_free()
	else:
		_close_gesture_overlay()
		_set_lollipop_overview_underlay_visible(false)

	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_recent_apps"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0 # Leave the classic three-button navigation visible.
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_gesture_overlay = overlay

	# Keep the three-button system navigation above the Overview task layer.
	# The original footer can be covered by the full-screen task overlay on
	# some simulator sizes, so temporarily replace it with a top-level footer.
	var original_navigation_bar := find_child("AndroidNavigationBar", true, false) as Control
	if is_instance_valid(original_navigation_bar):
		original_navigation_bar.visible = false
	var overview_navigation_footer := VBoxContainer.new()
	overview_navigation_footer.name = "LollipopOverviewNavigationFooter"
	overview_navigation_footer.anchor_left = 0.0
	overview_navigation_footer.anchor_right = 1.0
	overview_navigation_footer.anchor_top = 1.0
	overview_navigation_footer.anchor_bottom = 1.0
	overview_navigation_footer.offset_left = 0.0
	overview_navigation_footer.offset_right = 0.0
	overview_navigation_footer.offset_top = -46.0
	overview_navigation_footer.offset_bottom = 0.0
	overview_navigation_footer.z_as_relative = false
	overview_navigation_footer.z_index = 100
	add_child(overview_navigation_footer)
	_build_android_navigation(overview_navigation_footer, true)

	# Lollipop Overview sits over the launcher wallpaper, not a solid panel.
	var background := ColorRect.new()
	background.name = "LollipopOverviewBackground"
	background.color = Color(0.0, 0.0, 0.0, 0.035)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)

	var search_bar := PanelContainer.new()
	search_bar.name = "LollipopOverviewSearchBar"
	search_bar.position = Vector2(10.0, 29.0)
	search_bar.size = Vector2(maxf(120.0, size.x - 20.0), 39.0)
	search_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color("#FFFFFF")
	search_style.set_corner_radius_all(2)
	search_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	search_style.shadow_size = 4
	search_style.shadow_offset = Vector2(0, 2)
	search_style.content_margin_left = 13
	search_style.content_margin_right = 10
	search_style.content_margin_top = 3
	search_style.content_margin_bottom = 3
	search_bar.add_theme_stylebox_override("panel", search_style)
	overlay.add_child(search_bar)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 5)
	search_bar.add_child(search_row)
	var google_wordmark := Label.new()
	google_wordmark.name = "LollipopOverviewGoogleWordmark"
	google_wordmark.text = "Google"
	google_wordmark.add_theme_font_size_override("font_size", 17)
	google_wordmark.add_theme_color_override("font_color", Color("#757575"))
	google_wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	google_wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(google_wordmark)
	var voice_mark := Label.new()
	voice_mark.name = "LollipopOverviewVoiceSearch"
	voice_mark.text = "●"
	voice_mark.add_theme_font_size_override("font_size", 11)
	voice_mark.add_theme_color_override("font_color", Color("#777777"))
	voice_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	voice_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	voice_mark.custom_minimum_size = Vector2(22, 22)
	search_row.add_child(voice_mark)

	if _recent_app_names.is_empty():
		var empty_label := Label.new()
		empty_label.name = "LollipopOverviewEmptyState"
		empty_label.text = "No recent apps"
		empty_label.position = Vector2(18.0, 88.0)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		overlay.add_child(empty_label)
		_apply_lollipop_shade_screen_mask(overlay)
		return

	# The newest task is the foreground card at the bottom of the deck.
	# Older tasks recede upwards, as they do in Android 5.0 Overview.
	var visible_count := mini(_recent_app_names.size(), 6)
	var card_width := maxf(140.0, size.x - 22.0)
	var card_height := maxf(190.0, size.y * 0.72)
	var base_x := (size.x - card_width) * 0.5
	var base_y := 82.0
	var stack_step := 29.0
	for index in range(visible_count):
		var app_name := _recent_app_names[index]
		if _find_app(app_name).is_empty():
			continue
		var depth := visible_count - 1 - index
		var card := Button.new()
		card.name = "LollipopOverviewTask_" + app_name.replace(" ", "")
		card.position = Vector2(base_x, base_y + float(depth) * stack_step)
		card.size = Vector2(card_width, card_height)
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.z_index = visible_count - index
		card.clip_contents = true
		card.text = ""
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_theme_stylebox_override("normal", _lollipop_overview_card_style(Color("#FFFFFF")))
		card.add_theme_stylebox_override("hover", _lollipop_overview_card_style(Color("#FFFFFF")))
		card.add_theme_stylebox_override("pressed", _lollipop_overview_card_style(Color("#F5F5F5")))
		card.add_theme_stylebox_override("focus", _lollipop_overview_card_style(Color("#FFFFFF")))
		card.pressed.connect(func() -> void:
			_close_gesture_overlay()
			_on_app_pressed(app_name)
		)
		overlay.add_child(card)

		var preview_background := ColorRect.new()
		preview_background.name = "LollipopOverviewPreview_" + app_name.replace(" ", "")
		preview_background.position = Vector2(0.0, 42.0)
		preview_background.size = Vector2(card_width, card_height - 42.0)
		preview_background.color = Color("#FAFAFA")
		preview_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview_background)

		var header := ColorRect.new()
		header.name = "LollipopOverviewCardHeader_" + app_name.replace(" ", "")
		header.color = _lollipop_overview_app_color(app_name)
		header.position = Vector2.ZERO
		header.size = Vector2(card_width, 42.0)
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header)

		var header_row := HBoxContainer.new()
		header_row.name = "LollipopOverviewHeaderContent_" + app_name.replace(" ", "")
		header_row.position = Vector2(10.0, 0.0)
		header_row.size = Vector2(card_width - 16.0, 42.0)
		header_row.add_theme_constant_override("separation", 9)
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header_row)

		var app := _find_app(app_name)
		var app_icon := Label.new()
		app_icon.name = "LollipopOverviewAppIcon_" + app_name.replace(" ", "")
		app_icon.text = str(app.get("glyph", "•"))
		app_icon.custom_minimum_size = Vector2(24.0, 30.0)
		app_icon.add_theme_font_size_override("font_size", 19)
		app_icon.add_theme_color_override("font_color", Color("#FFFFFF"))
		app_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		app_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_row.add_child(app_icon)

		var app_title := Label.new()
		app_title.name = "LollipopOverviewAppTitle_" + app_name.replace(" ", "")
		app_title.text = app_name
		app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		app_title.add_theme_font_size_override("font_size", 15)
		app_title.add_theme_color_override("font_color", Color("#FFFFFF"))
		app_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_row.add_child(app_title)

		var close_task := Button.new()
		close_task.name = "DismissOverviewTask_" + app_name.replace(" ", "")
		close_task.text = "×"
		close_task.custom_minimum_size = Vector2(30.0, 34.0)
		close_task.add_theme_font_size_override("font_size", 24)
		close_task.add_theme_color_override("font_color", Color("#FFFFFF"))
		close_task.focus_mode = Control.FOCUS_NONE
		for state_name in ["normal", "hover", "pressed", "focus"]:
			close_task.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		close_task.pressed.connect(_dismiss_overview_task.bind(app_name))
		header_row.add_child(close_task)

		var preview_content := VBoxContainer.new()
		preview_content.name = "LollipopOverviewPreviewContent_" + app_name.replace(" ", "")
		preview_content.position = Vector2(13.0, 52.0)
		preview_content.size = Vector2(card_width - 26.0, card_height - 62.0)
		preview_content.add_theme_constant_override("separation", 8)
		preview_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview_content)
		_build_lollipop_overview_preview(preview_content, app_name)

	_apply_lollipop_shade_screen_mask(overlay)


func _lollipop_overview_card_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	style.set_border_width_all(0)
	return style


func _lollipop_overview_app_color(app_name: String) -> Color:
	match app_name:
		"Camera":
			return Color("#263238")
		"Notes":
			return Color("#F4B400")
		"Drive", "Sheets":
			return Color("#0F9D58")
		"Email":
			return Color("#D14836")
		"Maps":
			return Color("#4285F4")
		"Messages":
			return Color("#009688")
		"Browser":
			return Color("#4285F4")
		"Settings":
			return Color("#607D8B")
		"Gallery", "Photos":
			return Color("#AB47BC")
		"Calendar":
			return Color("#4285F4")
		_:
			var app := _find_app(app_name)
			return Color(str(app.get("color", "#607D8B")))


func _build_lollipop_overview_preview(parent: VBoxContainer, app_name: String) -> void:
	var status_line := _label("9:41  ·  " + app_name.to_upper(), 8, Color("#78909C"))
	status_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(status_line)

	match app_name:
		"Camera":
			var camera_preview := ColorRect.new()
			camera_preview.name = "OverviewCameraSnapshot"
			camera_preview.color = Color("#263238")
			camera_preview.custom_minimum_size.y = 118
			parent.add_child(camera_preview)
			var capture_hint := _label("PHOTO  ·  VIDEO", 8, Color("#607D8B"))
			parent.add_child(capture_hint)
		"Messages", "Email":
			_add_lollipop_overview_preview_row(parent, "Alex Morgan", "Are we still meeting today?", Color("#4C91C7"))
			_add_lollipop_overview_preview_row(parent, "Family", "Thanks, see you soon.", Color("#4B9B78"))
			_add_lollipop_overview_preview_row(parent, "Work", "The document is ready.", Color("#CE765D"))
		"Settings":
			_add_lollipop_overview_preview_row(parent, "Wireless & networks", "Wi-Fi, Bluetooth, data usage", Color("#4C91C7"))
			_add_lollipop_overview_preview_row(parent, "Device", "Display, sound, storage", Color("#4B9B78"))
			_add_lollipop_overview_preview_row(parent, "Personal", "Location, security, accounts", Color("#CE765D"))
		"Browser":
			var address := PanelContainer.new()
			address.custom_minimum_size.y = 28
			var address_style := StyleBoxFlat.new()
			address_style.bg_color = Color("#ECEFF1")
			address_style.set_corner_radius_all(2)
			address.add_theme_stylebox_override("panel", address_style)
			address.add_child(_label("Search or enter address", 8, Color("#607D8B")))
			parent.add_child(address)
			parent.add_child(_label("Recently viewed page", 11, Color("#37474F")))
			var article_line := ColorRect.new()
			article_line.color = Color("#CFD8DC")
			article_line.custom_minimum_size.y = 58
			parent.add_child(article_line)
		"Photos", "Gallery":
			var photo_grid := GridContainer.new()
			photo_grid.columns = 3
			photo_grid.add_theme_constant_override("h_separation", 5)
			photo_grid.add_theme_constant_override("v_separation", 5)
			for tile_color in [Color("#90A4AE"), Color("#B0BEC5"), Color("#78909C"), Color("#CFD8DC"), Color("#A1887F"), Color("#80CBC4")]:
				var photo_tile := ColorRect.new()
				photo_tile.color = tile_color
				photo_tile.custom_minimum_size = Vector2(54.0, 48.0)
				photo_grid.add_child(photo_tile)
			parent.add_child(photo_grid)
		"Maps":
			var map_preview := ColorRect.new()
			map_preview.color = Color("#E8E4D8")
			map_preview.custom_minimum_size.y = 116
			parent.add_child(map_preview)
			parent.add_child(_label("Nearby places", 10, Color("#455A64")))
		_:
			parent.add_child(_label(_lollipop_overview_preview_text(app_name), 11, Color("#455A64")))
			for line_index in range(3):
				var preview_line := ColorRect.new()
				preview_line.color = Color("#CFD8DC")
				preview_line.custom_minimum_size = Vector2(0.0, 4.0)
				parent.add_child(preview_line)


func _add_lollipop_overview_preview_row(parent: VBoxContainer, primary_text: String, secondary_text: String, avatar_color: Color) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 38.0
	row.add_theme_constant_override("separation", 9)
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(27.0, 27.0)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = avatar_color
	avatar_style.set_corner_radius_all(14)
	avatar.add_theme_stylebox_override("panel", avatar_style)
	row.add_child(avatar)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(_label(primary_text, 9, Color("#37474F")))
	copy.add_child(_label(secondary_text, 8, Color("#78909C")))
	row.add_child(copy)
	parent.add_child(row)


func _set_lollipop_overview_underlay_visible(should_show: bool) -> void:
	var component_content := find_child("OSComponentContent", true, false) as Control
	if is_instance_valid(component_content):
		component_content.visible = should_show
	for dock_name in ["HomeAppDockIcons", "PieHomeDockIcons", "PieHomeGoogleSearchBar"]:
		var home_dock := find_child(dock_name, true, false) as Control
		if is_instance_valid(home_dock):
			home_dock.visible = should_show


func _lollipop_overview_preview_text(app_name: String) -> String:
	match app_name:
		"Messages":
			return "Recent conversations\n\nNo new messages"
		"Browser":
			return "Recently viewed page\n\nSearch or enter address"
		"Settings":
			return "Wireless & networks\nDevice\nPersonal"
		"Photos", "Gallery":
			return "Your recent pictures and albums"
		"Calendar":
			return "Today\nUpcoming events"
		_:
			return app_name + " application preview"


func _advance_overview_deck(move_to_back: bool) -> void:
	if _recent_app_names.size() < 2:
		return
	if move_to_back:
		_recent_app_names.push_back(_recent_app_names.pop_front())
	else:
		_recent_app_names.push_front(_recent_app_names.pop_back())
	_build_lollipop_overview()


func _dismiss_overview_top_card() -> void:
	if not _recent_app_names.is_empty():
		_dismiss_overview_task(_recent_app_names[0])


func _dismiss_overview_task(app_name: String) -> void:
	_recent_app_names.erase(app_name)
	# Keep the active Overview overlay and navigation footer alive. Removing
	# only the dismissed task avoids destroying the close button's own parent
	# while its pressed signal is being dispatched.
	var task_card_name := "LollipopOverviewTask_" + app_name.replace(" ", "")
	var task_card := find_child(task_card_name, true, false) as Control
	if is_instance_valid(task_card):
		task_card.queue_free()
	var overlay := find_child("OSGestureOverlay_recent_apps", true, false) as Control
	if not is_instance_valid(overlay):
		_build_lollipop_overview()
		return
	if _recent_app_names.is_empty():
		var empty_label := Label.new()
		empty_label.name = "LollipopOverviewEmptyState"
		empty_label.text = "No recent apps"
		empty_label.position = Vector2(18.0, 88.0)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		overlay.add_child(empty_label)
		return
	var visible_count := mini(_recent_app_names.size(), 6)
	var card_width := maxf(140.0, size.x - 22.0)
	var base_x := (size.x - card_width) * 0.5
	var base_y := 82.0
	var stack_step := 29.0
	for index in range(visible_count):
		var remaining_name := _recent_app_names[index]
		var remaining_card := find_child("LollipopOverviewTask_" + remaining_name.replace(" ", ""), true, false) as Control
		if not is_instance_valid(remaining_card):
			continue
		var depth := visible_count - 1 - index
		remaining_card.position = Vector2(base_x, base_y + float(depth) * stack_step)
		remaining_card.z_index = visible_count - index


func _close_gesture_overlay() -> void:
	var was_recent_apps := _gesture_overlay != null and is_instance_valid(_gesture_overlay) and _gesture_overlay.name == "OSGestureOverlay_recent_apps"
	var was_pie_overview := was_recent_apps and int(configuration.get("generation", 2)) == 3
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		_gesture_overlay.queue_free()
	_gesture_overlay = null
	if was_recent_apps:
		var footer_name := "PieOverviewNavigationFooter" if was_pie_overview else "LollipopOverviewNavigationFooter"
		var overview_navigation_footer := find_child(footer_name, true, false) as Control
		if is_instance_valid(overview_navigation_footer):
			overview_navigation_footer.queue_free()
		var nav_name := "PieNavigationBar" if was_pie_overview else "AndroidNavigationBar"
		var original_navigation_bar := find_child(nav_name, true, false) as Control
		if is_instance_valid(original_navigation_bar):
			original_navigation_bar.visible = true
		_set_lollipop_overview_underlay_visible(true)


func _ready() -> void:
	LOCKSCREEN_FONT = load("res://assets/fonts/STIXTwoText[wght].ttf") as FontFile
	LOCKSCREEN_CAMERA_TEXTURE = load("res://assets/os/lockscreen/camera.svg") as Texture2D
	LOCKSCREEN_FLASHLIGHT_TEXTURE = load("res://assets/os/lockscreen/flashlight.svg") as Texture2D
	STATUS_CELLULAR_TEXTURE = load("res://assets/os/lockscreen/status_cellular.svg") as Texture2D
	STATUS_WIFI_TEXTURE = load("res://assets/os/lockscreen/status_wifi.svg") as Texture2D
	STATUS_BATTERY_TEXTURE = load("res://assets/os/lockscreen/status_battery.svg") as Texture2D
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

func set_component_view(component_id: String, remember_previous: bool = true) -> void:
	var next_component := _safe_component_id(component_id)
	if remember_previous and next_component != active_component and active_component != "lock_screen":
		_screen_history.append(active_component)
		while _screen_history.size() > 12:
			_screen_history.pop_front()
	active_component = next_component
	if active_component == "home_screen":
		_screen_history.clear()
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
	for grid_name in ["HomeAppGrid"]:
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


func _is_android_os() -> bool:
	var layout_style := str(configuration.get("components", {}).get("home_screen", {}).get("layout_style", "android_pixel"))
	return layout_style == "android_pixel"


func _build_android_navigation(parent: VBoxContainer, use_lollipop_style: bool = false, back_only: bool = false, use_pie_style: bool = false, use_pie_overview: bool = false) -> void:
	parent.add_theme_constant_override("separation", 0)
	var is_light_surface := active_component == "app_drawer" and (use_lollipop_style or use_pie_style)
	var navigation_bar := PanelContainer.new()
	navigation_bar.name = "PieOverviewNavigationBar" if use_pie_overview else "PieNavigationBar" if use_pie_style else "AndroidNavigationBar"
	navigation_bar.custom_minimum_size = Vector2(0, 46)
	navigation_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style := StyleBoxFlat.new()
	# Android 5 Lollipop draws its navigation glyphs directly over the
	# screen surface; it does not use a separate opaque navigation strip.
	bar_style.bg_color = Color(0.0, 0.0, 0.0, 0.0) if use_lollipop_style or (use_pie_style and not is_light_surface) else (Color("#F8F9FA") if use_pie_style else Color("#FAFAFA")) if is_light_surface else Color(0.025, 0.035, 0.045, 0.88)
	bar_style.set_border_width_all(0)
	bar_style.set_corner_radius_all(0)
	bar_style.content_margin_left = 0
	bar_style.content_margin_right = 0
	bar_style.content_margin_top = 0
	bar_style.content_margin_bottom = 0
	navigation_bar.add_theme_stylebox_override("panel", bar_style)

	var navigation_keys := HBoxContainer.new()
	navigation_keys.name = "PieOverviewThreeButtonNavigation" if use_pie_overview else "PieThreeButtonNavigation" if use_pie_style else "LollipopThreeButtonNavigation" if use_lollipop_style else "AndroidThreeButtonNavigation"
	navigation_keys.custom_minimum_size.y = 46
	navigation_keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation_keys.mouse_filter = Control.MOUSE_FILTER_PASS
	navigation_keys.add_theme_constant_override("separation", 2)

	var navigation_color := Color("#616161") if is_light_surface else Color("#F5F7F8")
	if back_only:
		# Keep Back in the same rightmost third it occupies when all three
		# Android navigation buttons are present.
		for spacer_index in range(2):
			var spacer := Control.new()
			spacer.name = "AndroidNavigationReservedSlot" + str(spacer_index + 1)
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			navigation_keys.add_child(spacer)
	var navigation_actions := ["Back"] if back_only else ["Back", "Home", "Overview"] if use_pie_style else ["Overview", "Home", "Back"]
	for action in navigation_actions:
		var key := AndroidNavigationButton.new()
		key.name = ("PieOverviewNavigation" if use_pie_overview else "PieNavigation" if use_pie_style else "LollipopNavigation" if use_lollipop_style else "AndroidNavigation") + action
		key.action_name = action
		key.icon_color = navigation_color
		key.tooltip_text = action
		key.custom_minimum_size = Vector2(30, 44)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.pressed.connect(_queue_android_navigation.bind(action))
		navigation_keys.add_child(key)

	navigation_bar.add_child(navigation_keys)
	parent.add_child(navigation_bar)


func _queue_android_navigation(action: String) -> void:
	call_deferred("_dispatch_android_navigation", action)


func _dispatch_android_navigation(action: String) -> void:
	match action:
		"Back":
			_navigate_back()
		"Home":
			_navigate_home()
		"Overview":
			_show_gesture_overlay("recent_apps")


func _on_android_navigation_pressed(action: String) -> void:
	_queue_android_navigation(action)



func _add_screen_corner_mask() -> void:
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "OSScreenRoundedCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_color = Color.BLACK
	add_child(corner_mask)


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

	if _is_android_os() and active_component == "app_drawer" and int(configuration.get("generation", 2)) in [1, 3]:
		var full_drawer_background := ColorRect.new()
		full_drawer_background.name = "PieAppDrawerFullScreenBackground" if int(configuration.get("generation", 2)) == 3 else "LollipopAppDrawerFullScreenBackground"
		full_drawer_background.color = Color("#F8F9FA") if int(configuration.get("generation", 2)) == 3 else Color("#FAFAFA")
		full_drawer_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		full_drawer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(full_drawer_background)

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
		if _is_android_os() and active_component == "pin_input":
			var pin_navigation_footer := VBoxContainer.new()
			pin_navigation_footer.name = "OSNavigationFooter"
			pin_navigation_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_build_android_navigation(pin_navigation_footer, int(configuration.get("generation", 2)) == 1, true, int(configuration.get("generation", 2)) == 3)
			lock_shell.add_child(pin_navigation_footer)
		# Android lock screens intentionally have no three-button navigation.
		_add_screen_corner_mask()
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
		if active_component == "app_drawer" and int(configuration.get("generation", 2)) == 1 and _is_android_os():
			page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.add_child(page_container)
		else:
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
	if _is_android_os():
		_build_android_navigation(footer, int(configuration.get("generation", 2)) == 1, false, int(configuration.get("generation", 2)) == 3)
	else:
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
	_add_screen_corner_mask()
	_building = false

func _build_home_dock(parent: VBoxContainer) -> void:
	var is_lollipop := int(configuration.get("generation", 2)) == 1 and str(configuration.get("components", {}).get("home_screen", {}).get("layout_style", "android_pixel")) == "android_pixel"
	var is_pie := int(configuration.get("generation", 2)) == 3 and _is_android_os()
	if is_pie:
		var pie_dock := HBoxContainer.new()
		pie_dock.name = "PieHomeDockIcons"
		pie_dock.custom_minimum_size.y = 47
		pie_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pie_dock.alignment = BoxContainer.ALIGNMENT_CENTER
		pie_dock.add_theme_constant_override("separation", 3)
		for app_name in ["Phone", "Messages", "Photos", "Browser", "Camera"]:
			var app := _find_app(app_name)
			if not app.is_empty():
				var dock_item := _create_app_icon(app, _responsive_icon_size(36, 5, 3), false)
				dock_item.name = "PieHomeDockApp_" + app_name.replace(" ", "")
				pie_dock.add_child(dock_item)
		parent.add_child(pie_dock)
		var search := PanelContainer.new()
		search.name = "PieHomeGoogleSearchBar"
		search.custom_minimum_size.y = 35
		search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var search_style := StyleBoxFlat.new()
		search_style.bg_color = Color("#F1F3F4")
		search_style.set_corner_radius_all(20)
		search_style.set_border_width_all(0)
		search_style.content_margin_left = 12
		search_style.content_margin_right = 12
		search_style.content_margin_top = 3
		search_style.content_margin_bottom = 3
		search.add_theme_stylebox_override("panel", search_style)
		var search_row := HBoxContainer.new()
		search_row.add_theme_constant_override("separation", 7)
		var google_mark := _label("G", 18, Color("#4285F4"))
		google_mark.name = "PieHomeGoogleMark"
		search_row.add_child(google_mark)
		var search_text := _label("Search", 10, Color("#5F6368"))
		search_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		search_row.add_child(search_text)
		search_row.add_child(_label("●", 10, Color("#4285F4")))
		search.add_child(search_row)
		parent.add_child(search)
		return
	var dock_row := HBoxContainer.new()
	dock_row.name = "HomeAppDockIcons"
	dock_row.custom_minimum_size.y = 46
	dock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 5)
	if is_lollipop:
		var dock_apps := ["Phone", "Messages", "Browser", "Camera"]
		var dock_icon_size := _responsive_icon_size(31, 5, 5)
		for index in range(5):
			if index == 2:
				var drawer_tile := VBoxContainer.new()
				drawer_tile.name = "LollipopAppDrawerDockItem"
				drawer_tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				drawer_tile.add_theme_constant_override("separation", 2)
				var holder := CenterContainer.new()
				var drawer_button := LollipopAppDrawerButton.new()
				drawer_button.name = "LollipopAppDrawerButton"
				drawer_button.custom_minimum_size = Vector2(dock_icon_size, dock_icon_size)
				drawer_button.pressed.connect(func(): set_component_view("app_drawer"))
				holder.add_child(drawer_button)
				drawer_tile.add_child(holder)
				dock_row.add_child(drawer_tile)
			else:
				var app_name: String = str(dock_apps[index if index < 2 else index - 1])
				var app := _find_app(app_name)
				if not app.is_empty():
					dock_row.add_child(_create_lollipop_app_icon(app, dock_icon_size, false, Color("#FFFFFF")))
		var dock_spacer := Control.new()
		dock_spacer.custom_minimum_size.y = 2
		parent.add_child(dock_row)
		parent.add_child(dock_spacer)
		return

	var standard_dock_apps := ["Phone", "Messages", "Browser", "Camera"]
	var standard_icon_size := _responsive_icon_size(35, standard_dock_apps.size(), 6)
	for app_name in standard_dock_apps:
		var app := _find_app(app_name)
		if not app.is_empty():
			dock_row.add_child(_create_app_icon(app, standard_icon_size, false))
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
	var is_lollipop_drawer := _is_android_os() and active_component == "app_drawer" and int(configuration.get("generation", 2)) == 1
	var is_pie_drawer := _is_android_os() and active_component == "app_drawer" and int(configuration.get("generation", 2)) == 3
	var is_oreo_lock_screen := _is_android_os() and active_component == "lock_screen" and int(configuration.get("generation", 1)) == 2
	var is_pie_lock_screen := _is_android_os() and active_component == "lock_screen" and int(configuration.get("generation", 1)) == 3
	var status_foreground := Color("#5F6368") if is_pie_drawer else Color("#424242") if is_lollipop_drawer else Color("#FFFFFF") if is_oreo_lock_screen or is_pie_lock_screen else _text_color()
	var bar := PanelContainer.new()
	bar.name = "OSStatusBar"
	bar.custom_minimum_size.y = 17 if is_oreo_lock_screen or is_pie_lock_screen else 22
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style := StyleBoxFlat.new()
	if is_lollipop_drawer or is_pie_drawer:
		bar_style.bg_color = Color("#F8F9FA") if is_pie_drawer else Color("#FAFAFA")
		bar_style.border_color = Color(0, 0, 0, 0)
		bar_style.set_border_width_all(0)
		bar_style.set_corner_radius_all(0)
	elif is_oreo_lock_screen or is_pie_lock_screen:
		bar_style.bg_color = Color(0, 0, 0, 0)
		bar_style.border_color = Color(0, 0, 0, 0)
		bar_style.set_border_width_all(0)
		bar_style.set_corner_radius_all(0)
	else:
		bar_style.bg_color = Color(_surface_color().r, _surface_color().g, _surface_color().b, 0.56)
		bar_style.border_color = Color(_text_color().r, _text_color().g, _text_color().b, 0.10)
		bar_style.set_border_width_all(1)
		bar_style.set_corner_radius_all(8)
	bar_style.content_margin_left = 7
	bar_style.content_margin_right = 7
	bar_style.content_margin_top = 1 if is_oreo_lock_screen else 2
	bar_style.content_margin_bottom = 1 if is_oreo_lock_screen else 2
	bar.add_theme_stylebox_override("panel", bar_style)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	var clock := _label(_current_lock_time(), 8, status_foreground)
	clock.name = "StatusBarClock"
	clock.custom_minimum_size = Vector2(32, 13)
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clock.visible = not (is_oreo_lock_screen or is_pie_lock_screen)
	row.add_child(clock)
	var notification_dot := _label("●", 5, status_foreground)
	notification_dot.name = "StatusBarNotificationIndicator"
	notification_dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_dot.visible = not (is_oreo_lock_screen or is_pie_lock_screen)
	row.add_child(notification_dot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var indicators := HBoxContainer.new()
	indicators.name = "StatusBarSystemIndicators"
	indicators.alignment = BoxContainer.ALIGNMENT_END
	indicators.add_theme_constant_override("separation", 3)
	indicators.custom_minimum_size = Vector2(57, 16)
	var cellular_icon := _status_bar_icon(STATUS_CELLULAR_TEXTURE, Vector2(16, 13), "StatusBarCellularIcon")
	var wifi_icon := _status_bar_icon(STATUS_WIFI_TEXTURE, Vector2(15, 13), "StatusBarWifiIcon")
	var battery_icon := _status_bar_icon(STATUS_BATTERY_TEXTURE, Vector2(20, 13), "StatusBarBatteryIcon")
	if is_lollipop_drawer or is_pie_drawer:
		cellular_icon.modulate = status_foreground
		wifi_icon.modulate = status_foreground
		battery_icon.modulate = status_foreground
	indicators.add_child(cellular_icon)
	indicators.add_child(wifi_icon)
	indicators.add_child(battery_icon)
	row.add_child(indicators)
	status_label = _label("", 1, _text_color())
	status_label.name = "StatusBarBattery"
	status_label.visible = false
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
		"ios_home":
			_build_apple_ios_home()
		"windows_tiles":
			_build_windows_phone_home()
		_:
			_build_android_home(data, 2)


func _build_android_home(data: Dictionary, widget_count: int) -> void:
	var generation_number := int(configuration.get("generation", 2))
	if generation_number == 1:
		_build_lollipop_android_home()
	elif generation_number == 3:
		_build_android_pie_home()
	else:
		_build_legacy_android_home(data, widget_count)


func _build_legacy_android_home(_data: Dictionary, _widget_count: int) -> void:
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


func _build_android_pie_home() -> void:
	# Pixel Launcher on Android 9: At a Glance, a restrained app grid and open wallpaper space.
	var glance := VBoxContainer.new()
	glance.name = "PieHomeAtAGlance"
	glance.add_theme_constant_override("separation", 2)
	var date_line := _label(_current_lock_date("minimal"), 11, Color("#202124"))
	date_line.name = "PieHomeDate"
	date_line.add_theme_font_override("font", LOCKSCREEN_FONT)
	glance.add_child(date_line)
	var weather_line := _label("26°  ·  Partly cloudy", 9, Color("#5F6368"))
	weather_line.name = "PieHomeWeather"
	glance.add_child(weather_line)
	page_container.add_child(glance)

	var top_space := Control.new()
	top_space.name = "PieHomeTopFlexibleSpace"
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(top_space)

	var app_grid := GridContainer.new()
	app_grid.name = "PieHomeAppGrid"
	app_grid.columns = 5
	app_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_grid.add_theme_constant_override("h_separation", 4)
	app_grid.add_theme_constant_override("v_separation", 8)
	for app_name in ["Calendar", "Photos", "Maps", "Store", "Email", "Camera", "Settings", "Clock", "Files", "Contacts"]:
		var app := _find_app(app_name)
		if not app.is_empty():
			app_grid.add_child(_create_app_icon(app, _responsive_icon_size(38, 5, 4), true))
	page_container.add_child(app_grid)
	var bottom_space := Control.new()
	bottom_space.name = "PieHomeBottomFlexibleSpace"
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(bottom_space)


func _build_lollipop_android_home() -> void:
	# Android 5.0 Lollipop / Google Now Launcher: fixed search bar, app grid,
	# open wallpaper space and a separate five-position launcher dock.
	var search_panel := PanelContainer.new()
	search_panel.name = "LollipopGoogleSearchBar"
	search_panel.custom_minimum_size.y = 31
	search_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color("#FFFFFF")
	search_style.set_corner_radius_all(2)
	search_style.set_border_width_all(0)
	search_style.content_margin_left = 7
	search_style.content_margin_right = 7
	search_style.content_margin_top = 2
	search_style.content_margin_bottom = 2
	search_panel.add_theme_stylebox_override("panel", search_style)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	search_panel.add_child(search_row)
	var google_mark := _label("G", 19, Color("#4285F4"))
	google_mark.custom_minimum_size.x = 20
	google_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(google_mark)
	var search_text := _label("Google", 10, Color("#777777"))
	search_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(search_text)
	var microphone := _label("●", 10, Color("#4285F4"))
	microphone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(microphone)
	page_container.add_child(search_panel)
	_add_home_flexible_space("LollipopSearchToAppsSpace", 1.0)
	var apps_grid := GridContainer.new()
	apps_grid.name = "LollipopHomeAppGrid"
	apps_grid.columns = 4
	apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_grid.add_theme_constant_override("h_separation", 4)
	apps_grid.add_theme_constant_override("v_separation", 7)
	for app_name in ["Email", "Photos", "Maps", "Store", "Calendar", "Contacts", "Music", "Settings"]:
		var app := _find_app(app_name)
		if not app.is_empty():
			apps_grid.add_child(_create_lollipop_app_icon(app, _responsive_icon_size(32, 4, 4), true, Color("#FFFFFF")))
	page_container.add_child(apps_grid)
	_add_home_flexible_space("LollipopAppsToDockSpace", 0.75)


func _lollipop_display_name(app_name: String) -> String:
	match app_name:
		"Email":
			return "Gmail"
		"Store":
			return "Play Store"
		"Browser":
			return "Chrome"
		"Music":
			return "Play Music"
		"Meet":
			return "Hangouts"
	return app_name


func _create_lollipop_app_icon(app: Dictionary, icon_size: int, show_label: bool, label_color: Color) -> Control:
	var tile := VBoxContainer.new()
	var app_name := str(app.get("name", "Application"))
	tile.name = "LollipopApp_" + app_name.replace(" ", "")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 2)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := Button.new()
	icon.name = "LollipopIconButton"
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.focus_mode = Control.FOCUS_NONE
	var icon_files := {
		"Phone": "phone", "Messages": "messages", "Camera": "camera", "Gallery": "gallery",
		"Browser": "browser", "Music": "music", "Calendar": "calendar", "Settings": "settings",
		"Files": "files", "Clock": "clock", "Maps": "maps", "Notes": "notes",
		"Contacts": "contacts", "Email": "email", "Calculator": "calculator", "Weather": "weather",
		"Downloads": "downloads", "Recorder": "recorder", "Video": "video", "Store": "store",
		"Security": "security", "Device Care": "device_care", "Drive": "drive", "Photos": "photos",
		"Wallet": "wallet", "Assistant": "assistant", "Meet": "meet"
	}
	var icon_stem := str(icon_files.get(app_name, ""))
	var icon_path := "res://assets/os/lollipop/icons/" + icon_stem + ".png" if not icon_stem.is_empty() else ""
	var icon_texture: Texture2D
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path) as Texture2D
	if is_instance_valid(icon_texture):
		icon.icon = icon_texture
		icon.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.expand_icon = true
		icon.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		icon.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		icon.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	else:
		icon.text = str(app.get("glyph", "•"))
		icon.add_theme_font_size_override("font_size", maxi(15, int(icon_size * 0.50)))
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(str(app.get("color", "#607D8B")))
		icon_style.set_corner_radius_all(5)
		icon_style.set_border_width_all(0)
		icon_style.shadow_color = Color(0, 0, 0, 0.20)
		icon_style.shadow_size = 2
		icon_style.shadow_offset = Vector2(0, 1)
		icon.add_theme_stylebox_override("normal", icon_style)
		icon.add_theme_stylebox_override("hover", icon_style)
		icon.add_theme_stylebox_override("pressed", icon_style)
		icon.add_theme_color_override("font_color", Color.WHITE)
		icon.add_theme_color_override("font_hover_color", Color.WHITE)
	icon.pressed.connect(_on_app_pressed.bind(app_name))
	holder.add_child(icon)
	tile.add_child(holder)
	if show_label:
		var display_name := _lollipop_display_name(app_name)
		var caption := _label(display_name, 7, label_color)
		caption.name = "LollipopAppLabel_" + app_name.replace(" ", "")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.clip_text = true
		tile.add_child(caption)
	return tile


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


func _build_windows_phone_home() -> void:
	_add_home_flexible_space("HomeLayoutTopFlexibleSpace", 0.7)
	page_container.add_child(_build_home_clock_block(27, HORIZONTAL_ALIGNMENT_LEFT))
	page_container.add_child(_make_home_widget_panel("HomeScreenPrimaryWidget", "LIVE UPDATES", "26°  ·  14 NOV", "Weather, calendar and activity at a glance", "▦", 52))
	_add_home_flexible_space("HomeLayoutMiddleFlexibleSpace", 0.5)
	_build_windows_tiles()
	_add_home_flexible_space("HomeLayoutBottomFlexibleSpace", 0.35)


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


func _build_lock_screen(data: Dictionary) -> void:
	if _is_android_os() and int(configuration.get("generation", 1)) == 3:
		_build_android_pie_lock_screen(data)
		return
	if _is_android_os() and int(configuration.get("generation", 1)) == 2:
		_build_oreo_lock_screen(data)
		return
	_build_lollipop_lock_screen(data)


func _build_android_pie_lock_screen(data: Dictionary) -> void:
	# Android 9 Pixel lock screen: large clock, date/weather, rounded notification cards and Pixel shortcuts.
	var root := VBoxContainer.new()
	root.name = "PieLockScreen"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	page_container.add_child(root)

	var top_space := Control.new()
	top_space.name = "PieLockScreenTopSpace"
	top_space.custom_minimum_size.y = 8
	root.add_child(top_space)

	var status_row := HBoxContainer.new()
	status_row.name = "PieLockScreenStatusRow"
	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_spacer)
	if bool(data.get("show_battery", true)):
		var battery := _label("100%  ▰", 9, Color("#FFFFFF"))
		battery.name = "PieLockBatteryInfo"
		status_row.add_child(battery)
	root.add_child(status_row)

	var clock_block := VBoxContainer.new()
	clock_block.name = "PieLockScreenClockBlock"
	clock_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_block.add_theme_constant_override("separation", 0)
	clock_block.add_theme_constant_override("separation", 1)
	root.add_child(clock_block)

	if bool(data.get("show_time", true)):
		var clock := _label(_current_lock_time("pixel"), 43, Color("#FFFFFF"))
		clock.name = "PieLockScreenClock"
		clock.custom_minimum_size.y = 50
		clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clock.autowrap_mode = TextServer.AUTOWRAP_OFF
		clock.add_theme_font_override("font", LOCKSCREEN_FONT)
		clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.38))
		clock.add_theme_constant_override("outline_size", 1)
		clock_block.add_child(clock)

	if bool(data.get("show_date", true)):
		var date := _label(_current_lock_date("pixel"), 10, Color("#FFFFFF"))
		date.name = "PieLockScreenDate"
		date.custom_minimum_size.y = 18
		date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		date.autowrap_mode = TextServer.AUTOWRAP_OFF
		date.add_theme_font_override("font", LOCKSCREEN_FONT)
		date.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
		date.add_theme_constant_override("outline_size", 1)
		clock_block.add_child(date)

	if bool(data.get("show_weather", true)):
		var weather := _label("Partly cloudy  ·  26°", 9, Color("#FFFFFF"))
		weather.name = "PieLockWeather"
		weather.custom_minimum_size.y = 22
		weather.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weather.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clock_block.add_child(weather)

	var notification_gap := Control.new()
	notification_gap.custom_minimum_size.y = 12
	root.add_child(notification_gap)

	if bool(data.get("show_notifications", true)):
		var notifications := VBoxContainer.new()
		notifications.name = "PieLockScreenNotifications"
		notifications.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notifications.add_theme_constant_override("separation", 6)
		root.add_child(notifications)
		_add_pie_lock_notification(notifications, "Messages", "Alex Morgan", "Are we still meeting today?", "M", Color("#4285F4"))
		_add_pie_lock_notification(notifications, "Calendar", "Upcoming event", "Your event starts in 10 minutes", "31", Color("#4285F4"))

	var flexible_space := Control.new()
	flexible_space.name = "PieLockScreenFlexibleSpace"
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(flexible_space)

	var shortcuts := HBoxContainer.new()
	shortcuts.name = "PieLockScreenShortcuts"
	shortcuts.custom_minimum_size.y = 44
	shortcuts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(shortcuts)
	var assistant_slot := CenterContainer.new()
	assistant_slot.name = "PieAssistantShortcutSlot"
	assistant_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.add_child(assistant_slot)
	if bool(data.get("show_assistant_shortcut", true)):
		var assistant := OreoLockShortcutButton.new()
		assistant.name = "PieAssistantShortcut"
		assistant.shortcut_id = "assistant"
		assistant.pressed.connect(func(): app_opened.emit("Assistant"))
		assistant_slot.add_child(assistant)
	var lock_slot := CenterContainer.new()
	lock_slot.name = "PieLockStatusSlot"
	lock_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_slot.add_child(OreoLockCenterGlyph.new())
	shortcuts.add_child(lock_slot)
	var camera_slot := CenterContainer.new()
	camera_slot.name = "PieCameraShortcutSlot"
	camera_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.add_child(camera_slot)
	if bool(data.get("show_camera_shortcut", true)):
		var camera := OreoLockShortcutButton.new()
		camera.name = "PieCameraShortcut"
		camera.shortcut_id = "camera"
		camera.pressed.connect(func(): app_opened.emit("Camera"))
		camera_slot.add_child(camera)

	var hint := _label("Swipe up to unlock", 8, Color(1, 1, 1, 0.84))
	hint.name = "PieSwipeToUnlockHint"
	hint.custom_minimum_size.y = 17
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


func _add_pie_lock_notification(parent: VBoxContainer, app_name: String, title_text: String, message_text: String, icon_text: String, icon_color: Color) -> void:
	var card := PanelContainer.new()
	card.name = "PieLockNotification_" + app_name.replace(" ", "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 48
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#F8F9FA")
	card_style.set_corner_radius_all(13)
	card_style.set_border_width_all(0)
	card_style.content_margin_left = 9
	card_style.content_margin_right = 9
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var icon := PanelContainer.new()
	icon.name = "PieLockNotificationIcon_" + app_name.replace(" ", "")
	icon.custom_minimum_size = Vector2(27, 27)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = icon_color
	icon_style.set_corner_radius_all(14)
	icon.add_theme_stylebox_override("panel", icon_style)
	var icon_label := _label(icon_text, 8, Color.WHITE)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(icon_label)
	row.add_child(icon)
	var message_column := VBoxContainer.new()
	message_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_column.add_theme_constant_override("separation", 0)
	var title := _label(title_text, 8, Color("#202124"))
	title.name = "PieLockNotificationTitle_" + app_name.replace(" ", "")
	message_column.add_child(title)
	var message := _label(message_text, 8, Color("#3C4043"))
	message.name = "PieLockNotificationMessage_" + app_name.replace(" ", "")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_column.add_child(message)
	row.add_child(message_column)
	parent.add_child(card)


func _build_oreo_lock_screen(data: Dictionary) -> void:
	var root := VBoxContainer.new()
	root.name = "OreoLockScreen"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	page_container.add_child(root)

	var upper_space := Control.new()
	upper_space.name = "OreoLockScreenTopSpace"
	upper_space.custom_minimum_size.y = 7
	root.add_child(upper_space)

	var clock_block := VBoxContainer.new()
	clock_block.name = "OreoLockScreenClockBlock"
	clock_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_block.add_theme_constant_override("separation", 0)
	root.add_child(clock_block)

	if bool(data.get("show_time", true)):
		var clock := _label(_current_lock_time("pixel"), 42, Color("#FFFFFF"))
		clock.name = "LockScreenClock"
		clock.custom_minimum_size.y = 48
		clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clock.autowrap_mode = TextServer.AUTOWRAP_OFF
		clock.clip_text = false
		clock.add_theme_font_override("font", LOCKSCREEN_FONT)
		clock.add_theme_color_override("font_color", Color("#FFFFFF"))
		clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.34))
		clock.add_theme_constant_override("outline_size", 1)
		clock_block.add_child(clock)

	if bool(data.get("show_date", true)):
		var date := _label(_current_lock_date("pixel"), 10, Color("#FFFFFF"))
		date.name = "LockScreenDate"
		date.custom_minimum_size.y = 18
		date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		date.autowrap_mode = TextServer.AUTOWRAP_OFF
		date.clip_text = false
		date.add_theme_font_override("font", LOCKSCREEN_FONT)
		date.add_theme_color_override("font_color", Color("#FFFFFF"))
		date.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.42))
		date.add_theme_constant_override("outline_size", 1)
		clock_block.add_child(date)

	var clock_notification_gap := Control.new()
	clock_notification_gap.name = "OreoLockScreenClockNotificationGap"
	clock_notification_gap.custom_minimum_size.y = 11
	root.add_child(clock_notification_gap)

	if bool(data.get("show_notifications", true)):
		var notifications := VBoxContainer.new()
		notifications.name = "OreoLockScreenNotifications"
		notifications.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notifications.add_theme_constant_override("separation", 5)
		root.add_child(notifications)
		_add_oreo_lock_notification(notifications, "Messages", "New message", "M", Color("#4285F4"))
		_add_oreo_lock_notification(notifications, "Calendar", "Upcoming event reminder", "31", Color("#4285F4"))

	var flexible_space := Control.new()
	flexible_space.name = "OreoLockScreenFlexibleSpace"
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(flexible_space)

	var shortcut_row := HBoxContainer.new()
	shortcut_row.name = "OreoLockScreenShortcuts"
	shortcut_row.custom_minimum_size.y = 42
	shortcut_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcut_row.add_theme_constant_override("separation", 0)
	root.add_child(shortcut_row)

	var assistant_slot := CenterContainer.new()
	assistant_slot.name = "OreoAssistantShortcutSlot"
	assistant_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_row.add_child(assistant_slot)
	if bool(data.get("show_assistant_shortcut", true)):
		var assistant_button := OreoLockShortcutButton.new()
		assistant_button.name = "OreoAssistantShortcut"
		assistant_button.shortcut_id = "assistant"
		assistant_button.pressed.connect(func(): app_opened.emit("Assistant"))
		assistant_slot.add_child(assistant_button)

	var lock_slot := CenterContainer.new()
	lock_slot.name = "OreoLockStatusSlot"
	lock_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_row.add_child(lock_slot)
	var lock_glyph := OreoLockCenterGlyph.new()
	lock_glyph.name = "OreoLockStatusGlyph"
	lock_slot.add_child(lock_glyph)

	var camera_slot := CenterContainer.new()
	camera_slot.name = "OreoCameraShortcutSlot"
	camera_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_row.add_child(camera_slot)
	if bool(data.get("show_camera_shortcut", true)):
		var camera_button := OreoLockShortcutButton.new()
		camera_button.name = "OreoCameraShortcut"
		camera_button.shortcut_id = "camera"
		camera_button.pressed.connect(func(): app_opened.emit("Camera"))
		camera_slot.add_child(camera_button)

	var unlock_hint := _label("Swipe up to unlock", 8, Color(1, 1, 1, 0.82))
	unlock_hint.name = "OreoSwipeToUnlockHint"
	unlock_hint.custom_minimum_size.y = 15
	unlock_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(unlock_hint)

	var bottom_space := Control.new()
	bottom_space.name = "OreoLockScreenBottomSpace"
	bottom_space.custom_minimum_size.y = 2
	root.add_child(bottom_space)


func _add_oreo_lock_notification(parent: VBoxContainer, app_name: String, message: String, icon_text: String, icon_color: Color) -> void:
	var card := PanelContainer.new()
	card.name = "OreoLockNotification_" + app_name.replace(" ", "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 37
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#F2F3F5")
	card_style.set_corner_radius_all(3)
	card_style.content_margin_left = 6
	card_style.content_margin_right = 6
	card_style.content_margin_top = 4
	card_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)

	var app_icon := PanelContainer.new()
	app_icon.name = "OreoLockNotificationIcon_" + app_name.replace(" ", "")
	app_icon.custom_minimum_size = Vector2(23, 23)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = icon_color
	icon_style.set_corner_radius_all(12)
	app_icon.add_theme_stylebox_override("panel", icon_style)
	var icon_label := _label(icon_text, 8, Color.WHITE)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	app_icon.add_child(icon_label)
	row.add_child(app_icon)

	var message_column := VBoxContainer.new()
	message_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_column.add_theme_constant_override("separation", 0)
	var title := _label(app_name, 8, Color("#202124"))
	title.name = "OreoLockNotificationTitle_" + app_name.replace(" ", "")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_column.add_child(title)
	var body := _label(message, 8, Color("#3C4043"))
	body.name = "OreoLockNotificationMessage_" + app_name.replace(" ", "")
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_column.add_child(body)
	row.add_child(message_column)
	parent.add_child(card)


func _build_lollipop_lock_screen(data: Dictionary) -> void:
	# Android 5.0 Lollipop lock screen: preserve the approved Generation 1 composition.
	var root := VBoxContainer.new()
	root.name = "LollipopLockScreen"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	page_container.add_child(root)

	var top_space := Control.new()
	top_space.name = "LollipopLockScreenTopSpace"
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_space.size_flags_stretch_ratio = 1.0
	root.add_child(top_space)

	if bool(data.get("show_time", true)):
		var clock := _label(_current_lock_time(), 52, Color("#FFFFFF"))
		clock.name = "LockScreenClock"
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clock.autowrap_mode = TextServer.AUTOWRAP_OFF
		clock.clip_text = false
		clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clock.add_theme_font_override("font", LOCKSCREEN_FONT)
		clock.add_theme_color_override("font_color", Color("#FFFFFF"))
		clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
		clock.add_theme_constant_override("outline_size", 1)
		root.add_child(clock)

	if bool(data.get("show_date", true)):
		var date := _label(_current_lock_date("uppercase"), 15, Color("#FFFFFF"))
		date.name = "LockScreenDate"
		date.custom_minimum_size = Vector2(0, 24)
		date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		date.autowrap_mode = TextServer.AUTOWRAP_OFF
		date.clip_text = false
		date.add_theme_font_override("font", LOCKSCREEN_FONT)
		date.add_theme_color_override("font_color", Color("#FFFFFF"))
		date.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.72))
		date.add_theme_constant_override("outline_size", 2)
		root.add_child(date)

	var middle_space := Control.new()
	middle_space.name = "LollipopLockScreenMiddleSpace"
	middle_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle_space.size_flags_stretch_ratio = 1.4
	root.add_child(middle_space)

	var shortcuts := HBoxContainer.new()
	shortcuts.name = "LockScreenQuickShortcuts"
	shortcuts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcuts.add_theme_constant_override("separation", 0)
	if bool(data.get("show_camera_shortcut", true)):
		var camera_button := _make_lock_shortcut(LOCKSCREEN_CAMERA_TEXTURE, "floating", "Camera")
		camera_button.name = "LockScreenShortcut_Camera"
		shortcuts.add_child(camera_button)
	else:
		var empty_camera_slot := Control.new()
		empty_camera_slot.name = "LollipopLockScreenCameraSlot"
		shortcuts.add_child(empty_camera_slot)
	var shortcut_spacer := Control.new()
	shortcut_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcuts.add_child(shortcut_spacer)
	if bool(data.get("show_flashlight_shortcut", true)):
		var flashlight_button := _make_lock_shortcut(LOCKSCREEN_FLASHLIGHT_TEXTURE, "floating", "Flashlight")
		flashlight_button.name = "LockScreenShortcut_Flashlight"
		shortcuts.add_child(flashlight_button)
	else:
		var empty_flashlight_slot := Control.new()
		empty_flashlight_slot.name = "LollipopLockScreenFlashlightSlot"
		shortcuts.add_child(empty_flashlight_slot)
	root.add_child(shortcuts)

	var bottom_space := Control.new()
	bottom_space.name = "LollipopLockScreenBottomSpace"
	bottom_space.custom_minimum_size.y = 12
	root.add_child(bottom_space)

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
	var is_pie_pin := _is_android_os() and int(configuration.get("generation", 2)) == 3
	var layout := VBoxContainer.new()
	layout.name = "PiePINInputScreen" if is_pie_pin else "PINInputScreen"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	page_container.add_child(layout)

	_build_pin_input_header(layout)
	_build_pin_input_keypad(layout)
	_build_pin_input_footer(layout)


func _build_pin_input_header(layout: VBoxContainer) -> void:
	var is_pie_pin := _is_android_os() and int(configuration.get("generation", 2)) == 3
	var entry_text_color := Color("#FFFFFF") if is_pie_pin else _text_color()
	var lock_indicator_stage := CenterContainer.new()
	lock_indicator_stage.name = "PINLockIndicatorStage"
	lock_indicator_stage.custom_minimum_size.y = 28
	var lock_indicator := PINLockIndicator.new()
	lock_indicator.name = "PINLockIndicator"
	lock_indicator.custom_minimum_size = Vector2(28.0, 24.0)
	lock_indicator_stage.add_child(lock_indicator)
	layout.add_child(lock_indicator_stage)

	var title := _label("Enter PIN", 18, entry_text_color)
	title.name = "PINEntryTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 26
	layout.add_child(title)

	var subtitle := _label("Use your PIN to unlock" if is_pie_pin else "Enter your 4-digit screen lock.", 9, Color("#DADCE0") if is_pie_pin else _muted_color())
	subtitle.name = "PINEntrySubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size.y = 16
	layout.add_child(subtitle)

	var dots := _label("○   ○   ○   ○", 14, entry_text_color)
	dots.name = "PINEntryDots"
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dots.custom_minimum_size.y = 28
	layout.add_child(dots)

	var error_label := _label(_pin_error_message, 7, Color("#FF9AA8"))
	error_label.name = "PINEntryError"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.custom_minimum_size.y = 18
	# Keep this slot in the layout even when empty so an error never shifts
	# the keypad or changes the position of the bottom navigation.
	layout.add_child(error_label)


func _build_pin_input_keypad(layout: VBoxContainer) -> void:
	var keypad := GridContainer.new()
	keypad.name = "PINKeypad"
	keypad.columns = 3
	keypad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keypad.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var keypad_gap := clampf(size.x * 0.045, 8.0, 12.0)
	keypad.add_theme_constant_override("h_separation", roundi(keypad_gap))
	keypad.add_theme_constant_override("v_separation", roundi(keypad_gap))

	# Fit the circular keys to both the phone width and the available height.
	# The PIN footer/navigation are reserved separately by the parent shell.
	var available_keypad_width := maxf(120.0, size.x - 40.0)
	# Reserve generous space for the header and footer, then distribute all
	# four keypad rows evenly within the remaining phone screen height.
	var available_content_height := maxf(200.0, size.y - 220.0)
	var horizontal_key_size := (available_keypad_width - keypad_gap * 2.0) / 3.0
	var vertical_key_size := (available_content_height - keypad_gap * 3.0) / 4.0
	var key_size := clampf(minf(horizontal_key_size, vertical_key_size), 34.0, 60.0)

	var pin_keys := [
		{"id":"1", "number":"1"}, {"id":"2", "number":"2"}, {"id":"3", "number":"3"},
		{"id":"4", "number":"4"}, {"id":"5", "number":"5"}, {"id":"6", "number":"6"},
		{"id":"7", "number":"7"}, {"id":"8", "number":"8"}, {"id":"9", "number":"9"},
		{"id":"Spacer", "number":""}, {"id":"0", "number":"0"}, {"id":"Delete", "number":"⌫"}
	]

	for key_data in pin_keys:
		var key_id := str(key_data["id"])
		if key_id == "Spacer":
			var spacer := Control.new()
			spacer.name = "PINKey_Spacer"
			spacer.custom_minimum_size = Vector2.ONE * key_size
			spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			keypad.add_child(spacer)
			continue

		var key := _create_pin_key_button(key_id, str(key_data["number"]), key_size)
		keypad.add_child(key)

	layout.add_child(keypad)


func _create_pin_key_button(key_id: String, caption: String, key_size: float) -> Button:
	var key := Button.new()
	key.name = "PINKey_" + key_id
	key.text = caption
	key.alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.custom_minimum_size = Vector2.ONE * key_size
	key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.clip_contents = false
	key.tooltip_text = "Delete the last digit" if key_id == "Delete" else "Enter digit " + key_id

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.90, 0.95, 1.0, 0.11)
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
	key.add_theme_font_size_override("font_size", 15 if key_size >= 30.0 else 13)
	key.focus_mode = Control.FOCUS_NONE
	key.mouse_filter = Control.MOUSE_FILTER_STOP

	if key_id == "Delete":
		key.pressed.connect(_on_pin_delete_pressed)
	else:
		key.pressed.connect(_on_pin_digit_pressed.bind(key_id))
	return key


func _build_pin_input_footer(layout: VBoxContainer) -> void:
	var emergency_button := Button.new()
	emergency_button.name = "PINEmergencyCallButton"
	emergency_button.text = "Emergency call"
	emergency_button.custom_minimum_size = Vector2(132, 32)
	emergency_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var emergency_style := StyleBoxFlat.new()
	emergency_style.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	emergency_style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	emergency_style.set_border_width_all(1)
	emergency_style.set_corner_radius_all(18)
	emergency_style.content_margin_left = 10
	emergency_style.content_margin_right = 10
	emergency_style.content_margin_top = 3
	emergency_style.content_margin_bottom = 3
	emergency_button.add_theme_stylebox_override("normal", emergency_style)
	emergency_button.add_theme_stylebox_override("hover", emergency_style.duplicate())
	emergency_button.add_theme_stylebox_override("pressed", emergency_style.duplicate())
	emergency_button.add_theme_color_override("font_color", Color("#F4F6FA"))
	emergency_button.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	emergency_button.add_theme_font_size_override("font_size", 9)
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

	var is_pie_pin := _is_android_os() and int(configuration.get("generation", 2)) == 3
	var info_label := _label("Enter device PIN" if is_pie_pin else "Preview PIN  ·  1234", 8, Color(1.0, 1.0, 1.0, 0.62))
	info_label.name = "PiePINUnlockInfoLabel" if is_pie_pin else "PINPreviewUnlockInfoLabel"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.custom_minimum_size.y = 16
	info.add_child(info_label)
	layout.add_child(info)


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
		# Keep the reserved row visible while empty to prevent keypad movement.
		error_label.visible = true


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

func _build_control_center(_data: Dictionary) -> void:
	if _is_android_os() and int(configuration.get("generation", 2)) == 3:
		_build_android_pie_control_center_preview()
		return
	if _is_android_os() and int(configuration.get("generation", 2)) == 1:
		var panel := PanelContainer.new()
		panel.name = "LollipopControlCenterPreview"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("#263238")
		panel_style.set_border_width_all(0)
		panel_style.set_corner_radius_all(2)
		panel_style.content_margin_left = 8
		panel_style.content_margin_right = 8
		panel_style.content_margin_top = 8
		panel_style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", panel_style)
		page_container.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		panel.add_child(body)
		_build_lollipop_quick_settings_content(body, true)
		return

	_add_section_label("QUICK SETTINGS")
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
		["NFC", "◈", false], ["Cast screen", "▣", false]
	]
	for item in toggles:
		var tile := Button.new()
		tile.name = "QuickTile_" + str(item[0]).replace(" ", "")
		tile.toggle_mode = true
		tile.button_pressed = bool(item[2])
		tile.custom_minimum_size.y = 48
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


func _build_notifications(_data: Dictionary) -> void:
	if _is_android_os() and int(configuration.get("generation", 2)) == 3:
		_build_android_pie_notifications_preview()
		return
	if _is_android_os() and int(configuration.get("generation", 2)) == 1:
		var panel := PanelContainer.new()
		panel.name = "LollipopNotificationPreview"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("#263238")
		panel_style.set_border_width_all(0)
		panel_style.set_corner_radius_all(2)
		panel_style.content_margin_left = 9
		panel_style.content_margin_right = 9
		panel_style.content_margin_top = 9
		panel_style.content_margin_bottom = 9
		panel.add_theme_stylebox_override("panel", panel_style)
		page_container.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 9)
		panel.add_child(body)
		_build_lollipop_notification_content(body)
		return

	_add_section_label("NOTIFICATION PANEL")
	_add_notification_surface("Messages", "A new message is waiting", "NOW")
	_add_notification_surface("Calendar", "Your next event is coming up", "10 MIN")
	_add_notification_surface("System", "Your device is up to date", "EARLIER")



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
	var is_android_layout := _is_android_os()
	var generation_number := int(configuration.get("generation", 2))
	var is_lollipop := generation_number == 1 and is_android_layout
	if generation_number == 3 and is_android_layout:
		_build_android_pie_app_drawer()
		return
	if is_lollipop:
		_build_lollipop_app_drawer()
		return

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


func _build_android_pie_app_drawer() -> void:
	# Pixel Launcher app drawer: search, suggested row, then an alphabetized all-apps grid.
	var search := LineEdit.new()
	search.name = "PieAppDrawerSearchField"
	search.placeholder_text = "Search your phone"
	search.custom_minimum_size.y = 36
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.clear_button_enabled = true
	_style_home_search_field(search)
	page_container.add_child(search)

	var suggestions_title := _label("Suggested apps", 9, Color("#5F6368"))
	suggestions_title.name = "PieSuggestedAppsHeading"
	page_container.add_child(suggestions_title)
	var suggestions := GridContainer.new()
	suggestions.name = "PieSuggestedAppsRow"
	suggestions.columns = 5
	suggestions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	suggestions.add_theme_constant_override("h_separation", 4)
	for app_name in ["Phone", "Messages", "Camera", "Browser", "Photos"]:
		var app := _find_app(app_name)
		if not app.is_empty():
			var item := _create_app_icon(app, _responsive_icon_size(38, 5, 4), true)
			item.name = "PieSuggestedApp_" + app_name.replace(" ", "")
			suggestions.add_child(item)
	page_container.add_child(suggestions)

	var all_apps_heading := _label("All apps", 13, Color("#202124"))
	all_apps_heading.name = "PieAppDrawerAllAppsHeading"
	page_container.add_child(all_apps_heading)

	var viewport := ScrollContainer.new()
	viewport.name = "PieAppDrawerViewport"
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page_container.add_child(viewport)
	var grid := GridContainer.new()
	grid.name = "PieAppDrawerGrid"
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 9)
	viewport.add_child(grid)
	_populate_android_pie_app_grid("", grid)
	search.text_changed.connect(_populate_android_pie_app_grid.bind(grid))


func _populate_android_pie_app_grid(query: String, grid: GridContainer) -> void:
	if not is_instance_valid(grid):
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var sorted_apps: Array = OSEngine.APP_DEFINITIONS.duplicate(true)
	sorted_apps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)
	var normalized_query := query.strip_edges().to_lower()
	for app in sorted_apps:
		var app_name := str(app.get("name", ""))
		if not normalized_query.is_empty() and not app_name.to_lower().contains(normalized_query):
			continue
		grid.add_child(_create_app_icon(app, _responsive_icon_size(42, 5, 4), true))


func _build_lollipop_app_drawer() -> void:
	# Android 5.0's app drawer is one continuous, vertically scrolling grid.
	# Every installed app fills the next available cell before the list continues.
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	page_container.add_child(spacer)
	var viewport := ScrollContainer.new()
	viewport.name = "LollipopAppDrawerViewport"
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	viewport.scroll_deadzone = 8
	page_container.add_child(viewport)
	var sorted_apps: Array = OSEngine.APP_DEFINITIONS.duplicate(true)
	sorted_apps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)
	var grid := GridContainer.new()
	grid.name = "LollipopAppDrawerGrid"
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 8)
	viewport.add_child(grid)
	var icon_size := _responsive_icon_size(34, 4, 5)
	for app in sorted_apps:
		grid.add_child(_create_lollipop_app_icon(app, icon_size, true, Color("#424242")))


func _build_recent_apps(_data: Dictionary) -> void:
	if _is_android_os() and int(configuration.get("generation", 2)) == 3:
		_build_android_pie_recent_apps_preview()
		return
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
	while _recent_app_names.size() > 8:
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
