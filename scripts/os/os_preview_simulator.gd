extends Control

signal app_opened(app_name: String)

const OSEngine = preload("res://scripts/os/procedural_os_engine.gd")
const PHONE_UNLOCK_PIN := "1234"
const SAMSUNG_GEN1_SCREEN_ASSETS := {
	"lock_screen": "lockscreen.jpg",
	"home_screen": "home_screen.jpg",
	"app_drawer": "app_drawer.jpg",
	"control_center": "notification.jpg",
	"notifications": "notification.jpg",
	"recent_apps": "recent_apps.jpg"
}
const PIXEL_GEN1_SCREEN_ASSETS := {
	"lock_screen": "lockscreen.jpg",
	"home_screen": "homescreen.jpg",
	"app_drawer": "appsdrawer.jpg",
	"control_center": "controlcenter.jpg",
	"notifications": "notification.jpg",
	"recent_apps": "recentapps.jpg"
}
const XIAOMI_GEN1_SCREEN_ASSETS := {
	"lock_screen": "lockscreen.jpg",
	"home_screen": "homescreen.jpg",
	"app_drawer": "appdrawer.jpg",
	"notifications": "notification.jpg",
	"recent_apps": "recentapps.jpg"
}
const SAMSUNG_GEN2_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg",
	"home_screen": "home.jpg",
	"app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg",
	"notifications": "notifications.jpg",
	"recent_apps": "recent.jpg"
}
const PIXEL_GEN2_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg",
	"home_screen": "home.jpg",
	"app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg",
	"notifications": "notification.jpg",
	"recent_apps": "recent.jpg"
}
const XIAOMI_GEN2_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg",
	"home_screen": "home.jpg",
	"app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg",
	"notifications": "notification.jpg",
	"recent_apps": "recent.jpg"
}
const SAMSUNG_GEN3_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg", "home_screen": "home.jpg", "app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg", "notifications": "notification.jpg", "recent_apps": "recent.jpg"
}
const PIXEL_GEN3_SCREEN_ASSETS := {
	"lock_screen": "lockscreen.jpg", "home_screen": "home.jpg", "app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg", "notifications": "notification.jpg", "recent_apps": "recent.jpg"
}
const XIAOMI_GEN3_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg", "home_screen": "home.jpg", "app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg", "notifications": "notification.jpg", "recent_apps": "recents.jpg"
}

const SAMSUNG_GEN4_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg", "home_screen": "home.jpg", "app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg", "notifications": "notification.jpg", "recent_apps": "recents.jpg"
}
const PIXEL_GEN4_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg", "home_screen": "home.jpg", "app_drawer": "appsdrawer.jpg",
	"control_center": "controlcenter.jpg", "notifications": "notification.jpg", "recent_apps": "recent.jpg"
}
const XIAOMI_GEN4_SCREEN_ASSETS := {
	"lock_screen": "lock.jpg", "home_screen": "home.jpg", "app_drawer": "appdrawer.jpg",
	"control_center": "controlcenter.jpg", "notifications": "notification.jpg", "recent_apps": "recent.jpg"
}

# Load imported assets after the simulator enters the scene tree. Preloading these
# font/SVG resources during a clean-checkout script scan fails before Godot imports them.
var LOCKSCREEN_FONT: FontFile
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
	var border_color := Color("#34404B")
	var border_width := 1.5

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
		var screen_border := StyleBoxFlat.new()
		screen_border.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		screen_border.border_color = border_color
		screen_border.set_border_width_all(roundi(border_width))
		screen_border.set_corner_radius_all(roundi(radius))
		screen_border.content_margin_left = 0
		screen_border.content_margin_right = 0
		screen_border.content_margin_top = 0
		screen_border.content_margin_bottom = 0
		draw_style_box(screen_border, Rect2(Vector2.ZERO, size))

class OSWallpaperLayer extends Control:
	var palette: Dictionary = {}
	var wallpaper_id := "touchwiz_nature"
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
		var focal := Vector2(size.x * 0.72, size.y * 0.32)
		var radius := minf(size.x, size.y) * 0.42
		draw_circle(focal, radius, Color(accent.r, accent.g, accent.b, 0.14))
		draw_arc(focal, radius * 0.74, -1.15, 2.2, 96, Color(1, 1, 1, 0.15), maxf(1.0, radius * 0.018), true)
		draw_arc(Vector2(size.x * 0.22, size.y * 0.82), radius * 1.1, -2.7, -0.25, 96, Color(surface.r, surface.g, surface.b, 0.30), maxf(2.0, radius * 0.055), true)
		draw_arc(Vector2(size.x * 0.82, size.y * 0.92), radius * 0.86, -2.8, -0.35, 96, Color(accent.r, accent.g, accent.b, 0.20), maxf(1.0, radius * 0.025), true)
		if treatment == "deep_contrast":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.12))
		elif treatment == "soft_glow":
			draw_circle(focal, radius, Color(accent.r, accent.g, accent.b, 0.055))
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
	"Sound": true, "Mute": false,
	"Cast screen": false, "Hotspot": false, "Battery saver": false
}
var _clock_update_elapsed := 0.0
var _brightness_level := 80

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
func _current_lock_time() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%02d:%02d" % [int(now.get("hour", 9)), int(now.get("minute", 41))]
func _current_lock_date(_treatment: String = "minimal") -> String:
	var now := Time.get_datetime_dict_from_system()
	var weekdays := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var weekday_index := clampi(int(now.get("weekday", 1)), 0, 6)
	var month_index := clampi(int(now.get("month", 1)) - 1, 0, 11)
	return "%s  ·  %02d %s" % [str(weekdays[weekday_index]).to_upper().substr(0, 3), int(now.get("day", 1)), str(months[month_index]).to_upper().substr(0, 3)]
func _refresh_lock_screen_clock() -> void:
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
	elif event is InputEventScreenDrag and _gesture_active:
		_try_finish_drag_gesture(_screen_to_local((event as InputEventScreenDrag).position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_begin_gesture(_screen_to_local(mouse.position))
		else:
			_finish_gesture(_screen_to_local(mouse.position))
	elif event is InputEventMouseMotion and _gesture_active:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_try_finish_drag_gesture(_screen_to_local(motion.position))

func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position

func _begin_gesture(touch_position: Vector2) -> void:
	_gesture_start = touch_position
	_gesture_start_time = Time.get_ticks_msec()
	_gesture_active = true


func _try_finish_drag_gesture(touch_position: Vector2) -> void:
	if not _is_gen1_phone_ui() and not _is_gen2_phone_ui() and not _is_gen3_phone_ui() and not _is_gen4_phone_ui():
		return
	var delta := touch_position - _gesture_start
	var vertical_threshold := maxf(20.0, size.y * 0.06)
	var horizontal_threshold := maxf(24.0, size.x * 0.10)
	var vertical_swipe := absf(delta.y) >= vertical_threshold and absf(delta.y) > absf(delta.x) * 1.10
	var horizontal_swipe := absf(delta.x) >= horizontal_threshold and absf(delta.x) > absf(delta.y) * 1.20
	if not vertical_swipe and not horizontal_swipe:
		return
	var elapsed_ms := Time.get_ticks_msec() - _gesture_start_time
	_gesture_active = false
	call_deferred("_handle_system_gesture", _gesture_start, touch_position, elapsed_ms)
func _finish_gesture(touch_position: Vector2) -> void:
	if not _gesture_active:
		return
	_gesture_active = false
	var elapsed_ms := Time.get_ticks_msec() - _gesture_start_time
	_handle_system_gesture(_gesture_start, touch_position, elapsed_ms)


func _handle_system_gesture(start: Vector2, finish: Vector2, _elapsed_ms: int) -> void:
	var delta := finish - start
	var vertical_threshold := maxf(24.0, size.y * 0.07)
	var horizontal_threshold := maxf(26.0, size.x * 0.12)
	var edge_size := clampf(minf(size.x, size.y) * 0.08, 16.0, 30.0)
	var tap_threshold := maxf(12.0, minf(size.x, size.y) * 0.035)

	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		if _gesture_overlay.name == "OSGestureOverlay_notifications":
			if delta.length() <= tap_threshold:
				_handle_gen1_overlay_tap("notifications", start)
			elif (_is_gen1_pixel_ui() or _is_gen2_phone_ui() or _is_gen3_phone_ui() or _is_gen4_phone_ui()) and delta.y >= vertical_threshold:
				_show_gesture_overlay("control_center")
			elif delta.y <= -vertical_threshold or absf(delta.x) >= horizontal_threshold:
				_close_gesture_overlay()
			return
		if _gesture_overlay.name == "OSGestureOverlay_control_center":
			if delta.length() <= tap_threshold:
				_handle_gen1_overlay_tap("control_center", start)
			elif delta.y <= -vertical_threshold or absf(delta.x) >= horizontal_threshold:
				_close_gesture_overlay()
			return
		if _gesture_overlay.name == "OSGestureOverlay_recent_apps":
			if delta.length() <= tap_threshold:
				_handle_gen1_overlay_tap("recent_apps", start)
			else:
				_close_gesture_overlay()
			return
		_close_gesture_overlay()
		return

	if start.y <= edge_size and delta.y >= vertical_threshold and absf(delta.y) > absf(delta.x) * 1.2:
		_show_gesture_overlay("notifications")
		return

	if _is_gen2_phone_ui() or _is_gen3_phone_ui() or _is_gen4_phone_ui():
		if active_component == "lock_screen":
			var unlock_up := delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.10
			var unlock_right := delta.x >= horizontal_threshold and absf(delta.x) > absf(delta.y) * 1.10
			if unlock_up or unlock_right:
				set_component_view("home_screen")
				return
		if active_component == "home_screen" and delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
			set_component_view("app_drawer")
			return
		if delta.length() <= tap_threshold:
			_handle_gen1_screen_tap(start)
		return

	if not _is_gen1_phone_ui():
		return

	if active_component == "lock_screen" and delta.x >= horizontal_threshold and absf(delta.x) > absf(delta.y) * 1.10:
		var valid_unlock_start := true
		if _is_gen1_pixel_ui():
			valid_unlock_start = start.y >= size.y * 0.30 and start.y <= size.y * 0.78
		elif _is_gen1_xiaomi_ui():
			valid_unlock_start = start.y >= size.y * 0.76
		if valid_unlock_start:
			set_component_view("home_screen")
		return

	if active_component == "home_screen" and (_is_gen1_pixel_ui() or _is_gen1_xiaomi_ui()):
		if delta.y <= -vertical_threshold and absf(delta.y) > absf(delta.x) * 1.15:
			set_component_view("app_drawer")
			return

	if delta.length() <= tap_threshold:
		_handle_gen1_screen_tap(start)
func _is_gen1_phone_ui() -> bool:
	return _is_gen1_samsung_ui() or _is_gen1_pixel_ui() or _is_gen1_xiaomi_ui()

func _is_gen2_phone_ui() -> bool:
	return _is_gen2_samsung_ui() or _is_gen2_pixel_ui() or _is_gen2_xiaomi_ui()

func _is_gen3_phone_ui() -> bool:
	return _is_gen3_samsung_ui() or _is_gen3_pixel_ui() or _is_gen3_xiaomi_ui()

func _is_gen4_phone_ui() -> bool:
	return _is_gen4_samsung_ui() or _is_gen4_pixel_ui() or _is_gen4_xiaomi_ui()

func _gen1_screenshot_prefix() -> String:
	if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui():
		return "Pixel"
	if _is_gen1_xiaomi_ui() or _is_gen2_xiaomi_ui() or _is_gen3_xiaomi_ui() or _is_gen4_xiaomi_ui():
		return "Xiaomi"
	return "Samsung"

func _gen1_screenshot_position(component_id: String, touch_position: Vector2) -> Vector2:
	var generation_prefix := "Gen4" if _is_gen4_phone_ui() else "Gen3" if _is_gen3_phone_ui() else "Gen2" if _is_gen2_phone_ui() else "Gen1"
	var screenshot_name := _gen1_screenshot_prefix() + generation_prefix + "ScreenImage_" + component_id
	var screenshot := find_child(screenshot_name, true, false) as TextureRect
	if screenshot == null or not is_instance_valid(screenshot):
		return Vector2(-1.0, -1.0)
	var screenshot_rect := screenshot.get_global_rect()
	if screenshot_rect.size.x <= 0.0 or screenshot_rect.size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var canvas_position := get_global_transform_with_canvas() * touch_position
	if not screenshot_rect.has_point(canvas_position):
		return Vector2(-1.0, -1.0)
	return Vector2(
		(canvas_position.x - screenshot_rect.position.x) / screenshot_rect.size.x,
		(canvas_position.y - screenshot_rect.position.y) / screenshot_rect.size.y
	)

func _handle_gen1_screen_tap(touch_position: Vector2) -> void:
	if _is_gen2_phone_ui() or _is_gen3_phone_ui() or _is_gen4_phone_ui():
		_handle_gen2_screen_tap(touch_position)
		return
	if _is_gen1_samsung_ui():
		_handle_samsung_gen1_tap(touch_position)
	elif _is_gen1_pixel_ui():
		_handle_pixel_gen1_tap(touch_position)
	elif _is_gen1_xiaomi_ui():
		_handle_xiaomi_gen1_tap(touch_position)

func _handle_pixel_gen1_tap(touch_position: Vector2) -> void:
	var normalized_position := _gen1_screenshot_position(active_component, touch_position)
	if normalized_position.x < 0.0 or normalized_position.y < 0.0:
		return
	var columns := [0.14, 0.38, 0.62, 0.86]
	match active_component:
		"lock_screen":
			if normalized_position.y >= 0.94:
				_show_gen1_panel_feedback("Emergency calling is unavailable in this preview.")
		"home_screen":
			if normalized_position.y >= 0.90 and normalized_position.x >= 0.36 and normalized_position.x <= 0.64:
				set_component_view("app_drawer")
				return
			if normalized_position.y >= 0.77 and normalized_position.y <= 0.90:
				var dock_column := clampi(roundi((normalized_position.x - 0.14) / 0.35), 0, 2)
				_on_app_pressed(["Phone", "Messages", "Browser"][dock_column])
				return
			var home_rows := [
				["Calendar", "Email", "Camera", "Gallery"],
				["Maps", "Store", "Messages", "Video"]
			]
			var row_centres := [0.50, 0.68]
			for row_index in range(home_rows.size()):
				if absf(normalized_position.y - row_centres[row_index]) > 0.075:
					continue
				for column_index in range(columns.size()):
					if absf(normalized_position.x - float(columns[column_index])) <= 0.10:
						_on_app_pressed(str(home_rows[row_index][column_index]))
						return
			if normalized_position.y >= 0.08 and normalized_position.y <= 0.20:
				_on_app_pressed("Browser")
		"app_drawer":
			if normalized_position.y < 0.20 and normalized_position.x >= 0.50:
				set_component_view("home_screen")
				return
			var drawer_rows := [
				["Phone", "Contacts", "Messages", "Browser"],
				["Email", "Camera", "Gallery", "Music"],
				["Calendar", "Maps", "Video", "Store"],
				["Settings", "Clock", "Calculator", "Email"],
				["Drive", "Downloads", "Messages", "Assistant"]
			]
			var drawer_columns := [0.13, 0.38, 0.62, 0.87]
			var drawer_centres := [0.245, 0.405, 0.565, 0.725, 0.885]
			for row_index in range(drawer_rows.size()):
				if absf(normalized_position.y - drawer_centres[row_index]) > 0.075:
					continue
				for column_index in range(drawer_columns.size()):
					if absf(normalized_position.x - drawer_columns[column_index]) <= 0.10:
						_on_app_pressed(str(drawer_rows[row_index][column_index]))
						return
		"notifications":
			if normalized_position.y < 0.25 and normalized_position.x > 0.72:
				_show_gen1_panel_feedback("Notifications cleared")
				return
			var notification_rows := [
				{"y":0.34,"app":"Phone"},
				{"y":0.51,"app":"Email"},
				{"y":0.68,"app":"Downloads"},
				{"y":0.84,"app":"Settings"}
			]
			for item in notification_rows:
				if absf(normalized_position.y - float(item["y"])) <= 0.08:
					_on_app_pressed(str(item["app"]))
					return
		"control_center":
			_handle_pixel_quick_settings(normalized_position)

func _handle_pixel_quick_settings(normalized_position: Vector2) -> void:
	if normalized_position.y >= 0.18 and normalized_position.y <= 0.29:
		_set_gen1_brightness_from_position(normalized_position.x)
		return
	if normalized_position.y >= 0.31 and normalized_position.y <= 0.86:
		var row := clampi(floori((normalized_position.y - 0.31) / 0.18), 0, 2)
		var column := 0 if normalized_position.x < 0.5 else 1
		var tiles := [
			["Wi-Fi", "Bluetooth"],
			["Mobile data", "Airplane mode"],
			["Auto-rotate", "Location"]
		]
		_toggle_gen1_quick_setting(str(tiles[row][column]))
		return
	if normalized_position.y >= 0.90:
		if normalized_position.x >= 0.70:
			_close_gesture_overlay()
		else:
			_toggle_gen1_quick_setting("Sound")

func _handle_xiaomi_gen1_tap(touch_position: Vector2) -> void:
	var normalized_position := _gen1_screenshot_position(active_component, touch_position)
	if normalized_position.x < 0.0 or normalized_position.y < 0.0:
		return
	var columns := [0.16, 0.40, 0.64, 0.88]
	match active_component:
		"lock_screen":
			if normalized_position.y >= 0.92 and normalized_position.x <= 0.16:
				_on_app_pressed("Camera")
		"home_screen":
			if normalized_position.y >= 0.86:
				var dock_column := clampi(roundi((normalized_position.x - 0.16) / 0.24), 0, 3)
				_on_app_pressed(["Phone", "Messages", "Browser", "Camera"][dock_column])
				return
			var home_rows := [
				["Calendar", "Clock", "Notes", "Themes"],
				["Contacts", "Messages", "Browser", "Camera"],
				["Gallery", "Music", "Downloads", "Settings"],
				["Security", "Store", "Files", "Phone"]
			]
			var row_centres := [0.32, 0.47, 0.62, 0.77]
			for row_index in range(home_rows.size()):
				if absf(normalized_position.y - float(row_centres[row_index])) > 0.065:
					continue
				for column_index in range(columns.size()):
					if absf(normalized_position.x - float(columns[column_index])) <= 0.10:
						var app_name := str(home_rows[row_index][column_index])
						_on_app_pressed("Store" if app_name == "Market" else app_name)
						return
		"app_drawer":
			var drawer_rows := [
				["Phone", "Contacts", "Messages", "Browser"],
				["Gallery", "Music", "Settings", "Camera"],
				["Themes", "Security", "Downloads", "Files"],
				["Notes", "Clock", "Calculator", "Calendar"],
				["Video", "Weather", "Messages", "Email"]
			]
			var drawer_centres := [0.31, 0.46, 0.62, 0.77, 0.92]
			for row_index in range(drawer_rows.size()):
				if absf(normalized_position.y - drawer_centres[row_index]) > 0.065:
					continue
				for column_index in range(columns.size()):
					if absf(normalized_position.x - float(columns[column_index])) <= 0.10:
						_on_app_pressed(str(drawer_rows[row_index][column_index]))
						return
		"notifications":
			_handle_xiaomi_notification_panel(normalized_position)

func _handle_xiaomi_notification_panel(normalized_position: Vector2) -> void:
	if normalized_position.y >= 0.12 and normalized_position.y <= 0.24:
		var quick_tiles := ["Wi-Fi", "Location", "Sound", "Auto-rotate"]
		var tile_index := clampi(floori(normalized_position.x * 4.0), 0, 3)
		_toggle_gen1_quick_setting(quick_tiles[tile_index])
		return
	if normalized_position.y >= 0.25 and normalized_position.y <= 0.34:
		_set_gen1_brightness_from_position(normalized_position.x)
		return
	var notification_rows := [
		{"y":0.44,"app":"Store"},
		{"y":0.58,"app":"Email"},
		{"y":0.70,"app":"Messages"},
		{"y":0.82,"app":"Store"},
		{"y":0.94,"app":"Messages"}
	]
	for item in notification_rows:
		if absf(normalized_position.y - float(item["y"])) <= 0.07:
			_on_app_pressed(str(item["app"]))
			return

func _handle_gen2_screen_tap(touch_position: Vector2) -> void:
	var normalized_position := _gen1_screenshot_position(active_component, touch_position)
	if normalized_position.x < 0.0 or normalized_position.y < 0.0:
		return
	match active_component:
		"lock_screen":
			if normalized_position.y >= 0.88:
				_on_app_pressed("Phone" if normalized_position.x < 0.5 else "Camera")
		"home_screen":
			_handle_gen2_home_screen_tap(normalized_position)
		"app_drawer":
			_handle_gen2_app_drawer_tap(normalized_position)
		"notifications":
			_handle_gen2_notifications_tap(normalized_position)
		"control_center":
			_handle_gen2_control_center_tap(normalized_position)
		"recent_apps":
			_handle_gen2_recent_apps_tap(normalized_position)

func _handle_gen2_home_screen_tap(normalized_position: Vector2) -> void:
	var columns := [0.13, 0.38, 0.62, 0.87]
	if _is_gen2_samsung_ui() or _is_gen3_samsung_ui() or _is_gen4_samsung_ui():
		if normalized_position.y >= 0.84:
			var dock_index := clampi(floori(normalized_position.x * 4.0), 0, 3)
			var dock_apps := ["Phone", "Messages", "Browser", "APP_DRAWER"]
			var dock_app := str(dock_apps[dock_index])
			if dock_app == "APP_DRAWER":
				set_component_view("app_drawer")
			else:
				_on_app_pressed(dock_app)
			return
		var rows := [
			["Calendar", "Email", "Camera", "Gallery"],
			["Clock", "Maps", "Play Store", "Settings"],
			["Contacts", "Downloads", "Music", "Video"]
		]
		for row_index in range(rows.size()):
			if absf(normalized_position.y - (0.34 + float(row_index) * 0.18)) <= 0.075:
				for column_index in range(columns.size()):
					if absf(normalized_position.x - columns[column_index]) <= 0.10:
						_on_app_pressed(str(rows[row_index][column_index]))
						return
	elif _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui():
		if normalized_position.y >= 0.82:
			var dock_index := clampi(floori(normalized_position.x * 4.0), 0, 3)
			_on_app_pressed(["Phone", "Messages", "Chrome", "Camera"][dock_index])
			return
		var rows := [
			["Calendar", "Photos", "Gmail", "Maps"],
			["YouTube", "Drive", "Play Store", "Settings"]
		]
		for row_index in range(rows.size()):
			if absf(normalized_position.y - (0.57 + float(row_index) * 0.16)) <= 0.075:
				for column_index in range(columns.size()):
					if absf(normalized_position.x - columns[column_index]) <= 0.10:
						_on_app_pressed(str(rows[row_index][column_index]))
						return
	elif _is_gen2_xiaomi_ui() or _is_gen3_xiaomi_ui() or _is_gen4_xiaomi_ui():
		if normalized_position.y >= 0.84:
			var dock_index := clampi(floori(normalized_position.x * 4.0), 0, 3)
			_on_app_pressed(["Phone", "Messages", "Browser", "Camera"][dock_index])
			return
		var rows := [
			["Calendar", "Clock", "Themes", "Security"],
			["Gallery", "Music", "Settings", "Tools"],
			["Contacts", "Downloads", "Browser", "Camera"]
		]
		for row_index in range(rows.size()):
			if absf(normalized_position.y - (0.34 + float(row_index) * 0.17)) <= 0.075:
				for column_index in range(columns.size()):
					if absf(normalized_position.x - columns[column_index]) <= 0.10:
						_on_app_pressed(str(rows[row_index][column_index]))
						return

func _handle_gen2_app_drawer_tap(normalized_position: Vector2) -> void:
	if normalized_position.y < 0.14 and normalized_position.x >= 0.78:
		set_component_view("home_screen")
		return
	var columns := [0.13, 0.38, 0.62, 0.87]
	var rows := [
		["Phone", "Contacts", "Messages", "Browser"],
		["Camera", "Gallery", "Photos", "Music"],
		["Calendar", "Clock", "Calculator", "Settings"],
		["Maps", "YouTube", "Drive", "Play Store"],
		["Files", "Downloads", "Email", "Weather"]
	]
	for row_index in range(rows.size()):
		if absf(normalized_position.y - (0.22 + float(row_index) * 0.15)) > 0.065:
			continue
		for column_index in range(columns.size()):
			if absf(normalized_position.x - columns[column_index]) <= 0.10:
				_on_app_pressed(str(rows[row_index][column_index]))
				return

func _handle_gen2_notifications_tap(normalized_position: Vector2) -> void:
	if normalized_position.y <= 0.20 and normalized_position.x >= 0.78:
		_show_gen1_panel_feedback("Notifications cleared")
		return
	var rows := [
		{"y":0.34,"app":"Phone"},
		{"y":0.49,"app":"Messages"},
		{"y":0.64,"app":"Email"},
		{"y":0.79,"app":"Downloads"},
		{"y":0.91,"app":"Calendar"}
	]
	for item in rows:
		if absf(normalized_position.y - float(item["y"])) <= 0.07:
			_on_app_pressed(str(item["app"]))
			return

func _handle_gen2_control_center_tap(normalized_position: Vector2) -> void:
	if normalized_position.y >= 0.14 and normalized_position.y <= 0.29:
		_set_gen1_brightness_from_position(normalized_position.x)
		return
	if normalized_position.y >= 0.30 and normalized_position.y <= 0.88:
		var row := clampi(floori((normalized_position.y - 0.30) / 0.19), 0, 2)
		var column := 0 if normalized_position.x < 0.5 else 1
		var tiles := [
			["Wi-Fi", "Bluetooth"],
			["Mobile data", "Airplane mode"],
			["Auto-rotate", "Location"]
		]
		_toggle_gen1_quick_setting(str(tiles[row][column]))
		return
	if normalized_position.y > 0.90 and normalized_position.x > 0.78:
		_close_gesture_overlay()

func _handle_gen2_recent_apps_tap(normalized_position: Vector2) -> void:
	var app_names := ["Settings", "Browser", "Messages", "Camera"]
	var row_index := clampi(floori((normalized_position.y - 0.12) / 0.22), 0, app_names.size() - 1)
	if normalized_position.x >= 0.10 and normalized_position.x <= 0.92 and normalized_position.y >= 0.10 and normalized_position.y <= 0.92:
		_on_app_pressed(app_names[row_index])

func _handle_gen2_overlay_tap(component_id: String, touch_position: Vector2) -> void:
	if component_id == "recent_apps":
		return
	var normalized_position := _gen1_screenshot_position(component_id, touch_position)
	if normalized_position.x < 0.0 or normalized_position.y < 0.0:
		return
	if component_id == "control_center":
		_handle_gen2_control_center_tap(normalized_position)
	elif component_id == "notifications":
		_handle_gen2_notifications_tap(normalized_position)

func _handle_gen1_overlay_tap(component_id: String, touch_position: Vector2) -> void:
	if _is_gen2_phone_ui() or _is_gen3_phone_ui() or _is_gen4_phone_ui():
		_handle_gen2_overlay_tap(component_id, touch_position)
		return
	if _is_gen1_samsung_ui():
		_handle_samsung_gen1_overlay_tap(component_id, touch_position)
		return
	if component_id == "recent_apps":
		return
	var normalized_position := _gen1_screenshot_position(component_id, touch_position)
	if normalized_position.x < 0.0 or normalized_position.y < 0.0:
		return
	if _is_gen1_pixel_ui():
		if component_id == "control_center":
			_handle_pixel_quick_settings(normalized_position)
		elif component_id == "notifications":
			_handle_pixel_gen1_panel_tap(normalized_position)
	elif _is_gen1_xiaomi_ui() and component_id in ["notifications", "control_center"]:
		_handle_xiaomi_notification_panel(normalized_position)

func _handle_pixel_gen1_panel_tap(normalized_position: Vector2) -> void:
	if normalized_position.y < 0.25 and normalized_position.x > 0.72:
		_show_gen1_panel_feedback("Notifications cleared")
		return
	var notification_rows := [
		{"y":0.30,"app":"Phone"},
		{"y":0.46,"app":"Email"},
		{"y":0.64,"app":"Downloads"},
		{"y":0.82,"app":"Settings"}
	]
	for item in notification_rows:
		if absf(normalized_position.y - float(item["y"])) <= 0.08:
			_on_app_pressed(str(item["app"]))
			return

func _build_gen2_family_gesture_overlay(mode: String) -> void:
	_close_gesture_overlay()
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_" + mode
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	overlay.z_as_relative = false
	add_child(overlay)
	_gesture_overlay = overlay
	_add_gen2_family_screenshot(overlay, mode)
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "Gen2FamilyShadeScreenCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_bottom_corners = false
	corner_mask.mask_color = Color.BLACK
	corner_mask.z_index = 130
	corner_mask.z_as_relative = false
	overlay.add_child(corner_mask)


func _build_gen3_family_gesture_overlay(mode: String) -> void:
	_close_gesture_overlay()
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_" + mode
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	overlay.z_as_relative = false
	add_child(overlay)
	_gesture_overlay = overlay
	_add_gen3_family_screenshot(overlay, mode)
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "Gen3FamilyShadeScreenCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_bottom_corners = false
	corner_mask.mask_color = Color.BLACK
	corner_mask.z_index = 130
	corner_mask.z_as_relative = false
	overlay.add_child(corner_mask)


func _build_gen4_family_gesture_overlay(mode: String) -> void:
	_close_gesture_overlay()
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_" + mode
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	overlay.z_as_relative = false
	add_child(overlay)
	_gesture_overlay = overlay
	_add_gen4_family_screenshot(overlay, mode)
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "Gen4FamilyShadeScreenCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_bottom_corners = false
	corner_mask.mask_color = Color.BLACK
	corner_mask.z_index = 130
	corner_mask.z_as_relative = false
	overlay.add_child(corner_mask)


func _build_gen1_family_gesture_overlay(mode: String) -> void:
	_close_gesture_overlay()
	var screenshot_component := mode
	if _is_gen1_xiaomi_ui() and mode == "control_center":
		screenshot_component = "notifications"
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_" + mode
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	overlay.z_as_relative = false
	add_child(overlay)
	_gesture_overlay = overlay
	_add_gen1_family_screenshot(overlay, screenshot_component)
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "Gen1FamilyShadeScreenCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_bottom_corners = false
	corner_mask.mask_color = Color.BLACK
	corner_mask.z_index = 130
	corner_mask.z_as_relative = false
	overlay.add_child(corner_mask)

func _build_gen1_family_overview() -> void:
	_close_gesture_overlay()
	_set_samsung_gen1_overview_underlay_visible(false)
	var overlay := Control.new()
	overlay.name = "OSGestureOverlay_recent_apps"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_bottom = -54.0
	overlay.clip_contents = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 120
	overlay.z_as_relative = false
	add_child(overlay)
	_gesture_overlay = overlay
	var background := ColorRect.new()
	background.name = "Gen1FamilyOverviewBackground"
	background.color = Color("#101720") if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui() else Color("#071A31")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	_build_gen1_family_recent_apps(overlay)
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "Gen1FamilyOverviewCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_bottom_corners = false
	corner_mask.mask_color = Color.BLACK
	corner_mask.z_index = 130
	overlay.add_child(corner_mask)

func _build_gen1_family_recent_apps(parent: Control) -> void:
	var content := VBoxContainer.new()
	content.name = "Gen1FamilyRecentApps"
	content.add_theme_constant_override("separation", 8)
	if parent is Container:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12.0
		content.offset_top = 16.0
		content.offset_right = -12.0
		content.offset_bottom = -12.0
	parent.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var title := _label("Recent apps", 16 if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui() else 15, Color("#C8D8F0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var clear_button := Button.new()
	clear_button.name = "Gen1FamilyClearAllRecentApps"
	clear_button.text = "Clear all"
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.add_theme_font_size_override("font_size", 9)
	clear_button.pressed.connect(_clear_gen1_family_recent_apps)
	header.add_child(clear_button)
	content.add_child(header)

	if _recent_app_names.is_empty():
		var empty_label := _label("No recent apps yet. Open an app to see it here.", 10, Color("#AAB8C8"))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(empty_label)
		return

	for app_name in _recent_app_names:
		var app := _find_app(app_name)
		var card := Button.new()
		card.name = "Gen1FamilyRecentApp_" + app_name.replace(" ", "")
		card.text = ""
		card.custom_minimum_size.y = 58.0
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_NONE
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#202A36") if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui() else Color("#142B49")
		card_style.border_color = Color("#477CB8") if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui() else Color("#477DCA")
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card_style.content_margin_left = 8
		card_style.content_margin_right = 8
		card_style.content_margin_top = 4
		card_style.content_margin_bottom = 4
		for state_name in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(state_name, card_style.duplicate())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph := _label(str(app.get("glyph", "•")), 22, Color(str(app.get("color", "#7FADE0"))))
		glyph.custom_minimum_size.x = 30
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(glyph)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(_label(app_name, 11, Color("#F4F7FA")))
		details.add_child(_label("Tap to return to this app", 8, Color("#9DB0C4")))
		row.add_child(details)
		card.add_child(row)
		card.pressed.connect(_open_gen1_recent_app.bind(app_name))
		content.add_child(card)

func _clear_gen1_family_recent_apps() -> void:
	_recent_app_names.clear()
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay) and _gesture_overlay.name == "OSGestureOverlay_recent_apps":
		_build_gen1_family_overview()
	elif active_component == "recent_apps":
		_build_shell()

func _open_gen1_recent_app(app_name: String) -> void:
	_close_gesture_overlay()
	_on_app_pressed(app_name)


func _handle_samsung_gen1_tap(touch_position: Vector2) -> void:
	var screenshot := find_child("SamsungGen1ScreenImage_" + active_component, true, false) as TextureRect
	if screenshot == null or not is_instance_valid(screenshot):
		return
	var screenshot_rect := screenshot.get_global_rect()
	var touch_canvas_position := get_global_transform_with_canvas() * touch_position
	if screenshot_rect.size.x <= 0.0 or screenshot_rect.size.y <= 0.0 or not screenshot_rect.has_point(touch_canvas_position):
		return
	var normalized_x := (touch_canvas_position.x - screenshot_rect.position.x) / screenshot_rect.size.x
	var normalized_y := (touch_canvas_position.y - screenshot_rect.position.y) / screenshot_rect.size.y
	if active_component == "recent_apps":
		var recent_apps := ["Email", "Camera", "Gallery", "Browser"]
		var recent_card_regions := [
			Rect2(0.20, 0.10, 0.60, 0.22),
			Rect2(0.20, 0.32, 0.60, 0.20),
			Rect2(0.20, 0.53, 0.60, 0.21),
			Rect2(0.20, 0.75, 0.60, 0.20)
		]
		for card_index in range(recent_card_regions.size()):
			if recent_card_regions[card_index].has_point(Vector2(normalized_x, normalized_y)):
				_close_gesture_overlay()
				_on_app_pressed(str(recent_apps[card_index]))
				return
		_close_gesture_overlay()
		return
	if active_component == "lock_screen":
		if normalized_y >= 0.90:
			if normalized_x <= 0.25:
				_on_app_pressed("Phone")
			elif normalized_x >= 0.75:
				_on_app_pressed("Camera")
		return
	var column_centres := [0.14, 0.38, 0.62, 0.86]
	if active_component == "home_screen":
		var home_rows := [
			["Email", "Camera", "Gallery", "Music"],
			["Browser", "Maps", "Video", "Store"],
			["Phone", "Contacts", "Messages", "APP_DRAWER"]
		]
		var home_row_centres := [0.52, 0.73, 0.90]
		for row_index in range(home_rows.size()):
			if absf(normalized_y - float(home_row_centres[row_index])) > 0.085:
				continue
			for column_index in range(column_centres.size()):
				if absf(normalized_x - float(column_centres[column_index])) > 0.11:
					continue
				var app_name := str(home_rows[row_index][column_index])
				if app_name == "APP_DRAWER":
					set_component_view("app_drawer")
				else:
					_on_app_pressed(app_name)
				return
	elif active_component == "notifications" or active_component == "control_center":
		var quick_tiles := ["Wi-Fi", "Location", "Sound", "Mute", "Auto-rotate", "Bluetooth", "Bluetooth"]
		if normalized_y >= 0.08 and normalized_y <= 0.30:
			var tile_index := clampi(int(floor(normalized_x * float(quick_tiles.size()))), 0, quick_tiles.size() - 1)
			var tile_name := str(quick_tiles[tile_index])
			_quick_setting_states[tile_name] = not bool(_quick_setting_states.get(tile_name, false))
		return
	elif active_component == "app_drawer":
		var drawer_rows := [
			["Email", "Camera", "Gallery", "Music"],
			["Browser", "Maps", "Video", "Store"],
			["Settings", "Notes", "Messages", "Downloads"],
			["Clock", "Calendar", "Calculator", "Recorder"],
			["Contacts", "Messages", "Files", "Calendar"]
		]
		var drawer_row_centres := [0.22, 0.37, 0.53, 0.69, 0.85]
		for row_index in range(drawer_rows.size()):
			if absf(normalized_y - float(drawer_row_centres[row_index])) > 0.07:
				continue
			for column_index in range(column_centres.size()):
				if absf(normalized_x - float(column_centres[column_index])) > 0.11:
					continue
				_on_app_pressed(str(drawer_rows[row_index][column_index]))
				return

func _handle_samsung_gen1_overlay_tap(component_id: String, touch_position: Vector2) -> void:
	var screenshot := find_child("SamsungGen1ScreenImage_" + component_id, true, false) as TextureRect
	if screenshot == null or not is_instance_valid(screenshot):
		return
	var screenshot_rect := screenshot.get_global_rect()
	var texture_size := screenshot.texture.get_size()
	if screenshot_rect.size.x <= 0.0 or screenshot_rect.size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	# TextureRect uses KEEP_ASPECT_CENTERED, so taps must be mapped against
	# the visible image area rather than any letterboxed part of its control.
	var image_scale := minf(screenshot_rect.size.x / texture_size.x, screenshot_rect.size.y / texture_size.y)
	var displayed_size := texture_size * image_scale
	var displayed_rect := Rect2(screenshot_rect.position + (screenshot_rect.size - displayed_size) * 0.5, displayed_size)
	var touch_canvas_position := get_global_transform_with_canvas() * touch_position
	if not displayed_rect.has_point(touch_canvas_position):
		return
	var normalized_position := Vector2(
		(touch_canvas_position.x - displayed_rect.position.x) / displayed_rect.size.x,
		(touch_canvas_position.y - displayed_rect.position.y) / displayed_rect.size.y
	)
	if component_id == "recent_apps":
		var recent_apps := ["Email", "Camera", "Gallery", "Browser"]
		var recent_card_regions := [
			Rect2(0.20, 0.10, 0.60, 0.22),
			Rect2(0.20, 0.32, 0.60, 0.20),
			Rect2(0.20, 0.53, 0.60, 0.21),
			Rect2(0.20, 0.75, 0.60, 0.20)
		]
		for card_index in range(recent_card_regions.size()):
			if recent_card_regions[card_index].has_point(normalized_position):
				_close_gesture_overlay()
				_on_app_pressed(str(recent_apps[card_index]))
				return
		_close_gesture_overlay()
		return
	if normalized_position.y < 0.08 or normalized_position.y > 0.30:
		return
	var quick_tiles := ["Wi-Fi", "Location", "Sound", "Mute", "Auto-rotate", "Bluetooth", "Bluetooth"]
	var tile_index := clampi(int(floor(normalized_position.x * float(quick_tiles.size()))), 0, quick_tiles.size() - 1)
	var tile_name := str(quick_tiles[tile_index])
	var enabled := not bool(_quick_setting_states.get(tile_name, false))
	_quick_setting_states[tile_name] = enabled
	_show_gen1_panel_feedback("%s · %s" % [tile_name, "ON" if enabled else "OFF"])


func _show_gen1_panel_feedback(message: String) -> void:
	var feedback_parent: Control = self
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		feedback_parent = _gesture_overlay
	var previous_feedback := feedback_parent.get_node_or_null("Gen1QuickSettingFeedback")
	if previous_feedback != null:
		previous_feedback.queue_free()
	var feedback := PanelContainer.new()
	feedback.name = "Gen1QuickSettingFeedback"
	feedback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	feedback.offset_left = 18.0
	feedback.offset_top = -54.0
	feedback.offset_right = -18.0
	feedback.offset_bottom = -8.0
	feedback.z_index = 140
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feedback_style := StyleBoxFlat.new()
	feedback_style.bg_color = Color(0.06, 0.07, 0.08, 0.94)
	feedback_style.border_color = Color(0.45, 0.50, 0.56, 0.62)
	feedback_style.set_border_width_all(1)
	feedback_style.set_corner_radius_all(8)
	feedback.add_theme_stylebox_override("panel", feedback_style)
	var feedback_label := Label.new()
	feedback_label.text = message
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 11)
	feedback_label.add_theme_color_override("font_color", Color.WHITE)
	feedback.add_child(feedback_label)
	feedback_parent.add_child(feedback)

func _toggle_gen1_quick_setting(tile_name: String) -> void:
	var enabled := not bool(_quick_setting_states.get(tile_name, false))
	_quick_setting_states[tile_name] = enabled
	_show_gen1_panel_feedback("%s · %s" % [tile_name, "ON" if enabled else "OFF"])


func _set_gen1_brightness_from_position(normalized_x: float) -> void:
	_brightness_level = clampi(roundi(normalized_x * 100.0), 0, 100)
	_apply_gen1_brightness_to_screenshots()
	_show_gen1_panel_feedback("Brightness · %d%%" % _brightness_level)

func _apply_gen1_brightness_to_screenshots() -> void:
	var brightness_scale := lerpf(0.12, 1.0, float(_brightness_level) / 100.0)
	var brightness_modulate := Color(brightness_scale, brightness_scale, brightness_scale, 1.0)
	for node in find_children("*", "TextureRect", true, false):
		var screenshot := node as TextureRect
		if screenshot.name.begins_with("SamsungGen1ScreenImage_") or screenshot.name.begins_with("PixelGen1ScreenImage_") or screenshot.name.begins_with("XiaomiGen1ScreenImage_") or screenshot.name.begins_with("SamsungGen2ScreenImage_") or screenshot.name.begins_with("PixelGen2ScreenImage_") or screenshot.name.begins_with("XiaomiGen2ScreenImage_") or screenshot.name.begins_with("SamsungGen3ScreenImage_") or screenshot.name.begins_with("PixelGen3ScreenImage_") or screenshot.name.begins_with("XiaomiGen3ScreenImage_") or screenshot.name.begins_with("SamsungGen4ScreenImage_") or screenshot.name.begins_with("PixelGen4ScreenImage_") or screenshot.name.begins_with("XiaomiGen4ScreenImage_"):
			screenshot.modulate = brightness_modulate
func _build_samsung_gen1_gesture_overlay(mode: String) -> void:
	_close_gesture_overlay()
	var screenshot_component := "recent_apps" if mode == "recent_apps" else "notifications"
	var overlay_name := "OSGestureOverlay_recent_apps" if mode == "recent_apps" else "OSGestureOverlay_notifications"
	_gesture_overlay = Control.new()
	_gesture_overlay.name = overlay_name
	_gesture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gesture_overlay.offset_bottom = -54.0
	_gesture_overlay.clip_contents = true
	_gesture_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_gesture_overlay.z_index = 120
	_gesture_overlay.z_as_relative = false
	add_child(_gesture_overlay)
	_add_gen1_family_screenshot(_gesture_overlay, screenshot_component)
	var corner_mask := OSScreenCornerMask.new()
	corner_mask.name = "SamsungGen1ShadeScreenCornerMask"
	corner_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner_mask.corner_radius = 22.0
	corner_mask.mask_bottom_corners = false
	corner_mask.mask_color = Color.BLACK
	corner_mask.z_index = 130
	corner_mask.z_as_relative = false
	_gesture_overlay.add_child(corner_mask)


func _navigate_home() -> void:
	if active_component == "lock_screen":
		return
	_close_gesture_overlay()
	_screen_history.clear()
	set_component_view("home_screen", false)

func _navigate_back() -> void:
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		_close_gesture_overlay()
		return
	if active_component == "lock_screen":
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
	if not _is_gen1_phone_ui() and not _is_gen2_phone_ui() and not _is_gen3_phone_ui() and not _is_gen4_phone_ui():
		return
	if mode not in ["notifications", "control_center", "recent_apps"]:
		return
	if _is_gen4_phone_ui():
		if mode == "recent_apps":
			_build_gen1_family_overview()
		else:
			_build_gen4_family_gesture_overlay(mode)
	elif _is_gen3_phone_ui():
		if mode == "recent_apps":
			_build_gen1_family_overview()
		else:
			_build_gen3_family_gesture_overlay(mode)
	elif _is_gen2_phone_ui():
		if mode == "recent_apps":
			_build_gen1_family_overview()
		else:
			_build_gen2_family_gesture_overlay(mode)
	elif _is_gen1_samsung_ui():
		_build_samsung_gen1_gesture_overlay(mode)
	elif mode == "recent_apps":
		_build_gen1_family_overview()
	else:
		_build_gen1_family_gesture_overlay(mode)
func _apply_gen1_screen_corner_mask(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.clip_contents = true
	var mask := OSScreenCornerMask.new()
	mask.name = "SamsungGen1ScreenCornerMask"
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.corner_radius = 22.0
	mask.mask_color = Color.BLACK
	mask.mask_bottom_corners = false
	mask.z_index = 100
	overlay.add_child(mask)

func _build_samsung_gen1_overview() -> void:
	# Rebuild the task deck without running the normal close path. The close
	# path restores the launcher and navigation bar, which causes a brief
	# teardown/re-entry during repeated card dismissals and can leave only the
	# navigation controls visible on the next swipe.
	var replacing_overview := _gesture_overlay != null and is_instance_valid(_gesture_overlay) and _gesture_overlay.name == "OSGestureOverlay_recent_apps"
	if replacing_overview:
		_gesture_overlay.queue_free()
		_gesture_overlay = null
		var previous_footer := find_child("SamsungGen1OverviewNavigationFooter", true, false) as Control
		if is_instance_valid(previous_footer):
			previous_footer.queue_free()
	else:
		_close_gesture_overlay()
		_set_samsung_gen1_overview_underlay_visible(false)

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
	overview_navigation_footer.name = "SamsungGen1OverviewNavigationFooter"
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
	_build_android_navigation(overview_navigation_footer)

	# Samsung Gen 1 Overview sits over the launcher wallpaper, not a solid panel.
	var background := ColorRect.new()
	background.name = "SamsungGen1OverviewBackground"
	background.color = Color(0.0, 0.0, 0.0, 0.035)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)

	var search_bar := PanelContainer.new()
	search_bar.name = "SamsungGen1OverviewSearchBar"
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
	google_wordmark.name = "SamsungGen1OverviewGoogleWordmark"
	google_wordmark.text = "Google"
	google_wordmark.add_theme_font_size_override("font_size", 17)
	google_wordmark.add_theme_color_override("font_color", Color("#757575"))
	google_wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	google_wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(google_wordmark)
	var voice_mark := Label.new()
	voice_mark.name = "SamsungGen1OverviewVoiceSearch"
	voice_mark.text = "●"
	voice_mark.add_theme_font_size_override("font_size", 11)
	voice_mark.add_theme_color_override("font_color", Color("#777777"))
	voice_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	voice_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	voice_mark.custom_minimum_size = Vector2(22, 22)
	search_row.add_child(voice_mark)

	if _recent_app_names.is_empty():
		var empty_label := Label.new()
		empty_label.name = "SamsungGen1OverviewEmptyState"
		empty_label.text = "No recent apps"
		empty_label.position = Vector2(18.0, 88.0)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		overlay.add_child(empty_label)
		_apply_gen1_screen_corner_mask(overlay)
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
		card.name = "SamsungGen1OverviewTask_" + app_name.replace(" ", "")
		card.position = Vector2(base_x, base_y + float(depth) * stack_step)
		card.size = Vector2(card_width, card_height)
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.z_index = visible_count - index
		card.clip_contents = true
		card.text = ""
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_theme_stylebox_override("normal", _samsung_gen1_overview_card_style(Color("#FFFFFF")))
		card.add_theme_stylebox_override("hover", _samsung_gen1_overview_card_style(Color("#FFFFFF")))
		card.add_theme_stylebox_override("pressed", _samsung_gen1_overview_card_style(Color("#F5F5F5")))
		card.add_theme_stylebox_override("focus", _samsung_gen1_overview_card_style(Color("#FFFFFF")))
		card.pressed.connect(func() -> void:
			_close_gesture_overlay()
			_on_app_pressed(app_name)
		)
		overlay.add_child(card)

		var preview_background := ColorRect.new()
		preview_background.name = "SamsungGen1OverviewPreview_" + app_name.replace(" ", "")
		preview_background.position = Vector2(0.0, 42.0)
		preview_background.size = Vector2(card_width, card_height - 42.0)
		preview_background.color = Color("#FAFAFA")
		preview_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview_background)

		var header := ColorRect.new()
		header.name = "SamsungGen1OverviewCardHeader_" + app_name.replace(" ", "")
		header.color = _samsung_gen1_overview_app_color(app_name)
		header.position = Vector2.ZERO
		header.size = Vector2(card_width, 42.0)
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header)

		var header_row := HBoxContainer.new()
		header_row.name = "SamsungGen1OverviewHeaderContent_" + app_name.replace(" ", "")
		header_row.position = Vector2(10.0, 0.0)
		header_row.size = Vector2(card_width - 16.0, 42.0)
		header_row.add_theme_constant_override("separation", 9)
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(header_row)

		var app := _find_app(app_name)
		var app_icon := Label.new()
		app_icon.name = "SamsungGen1OverviewAppIcon_" + app_name.replace(" ", "")
		app_icon.text = str(app.get("glyph", "•"))
		app_icon.custom_minimum_size = Vector2(24.0, 30.0)
		app_icon.add_theme_font_size_override("font_size", 19)
		app_icon.add_theme_color_override("font_color", Color("#FFFFFF"))
		app_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		app_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_row.add_child(app_icon)

		var app_title := Label.new()
		app_title.name = "SamsungGen1OverviewAppTitle_" + app_name.replace(" ", "")
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
		preview_content.name = "SamsungGen1OverviewPreviewContent_" + app_name.replace(" ", "")
		preview_content.position = Vector2(13.0, 52.0)
		preview_content.size = Vector2(card_width - 26.0, card_height - 62.0)
		preview_content.add_theme_constant_override("separation", 8)
		preview_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(preview_content)
		_build_samsung_gen1_overview_preview(preview_content, app_name)

	_apply_gen1_screen_corner_mask(overlay)

func _dismiss_overview_task(app_name: String) -> void:
	_recent_app_names.erase(app_name)
	var task_card_name := "SamsungGen1OverviewTask_" + app_name.replace(" ", "")
	var task_card := find_child(task_card_name, true, false) as Control
	if is_instance_valid(task_card):
		task_card.queue_free()
	var overlay := find_child("OSGestureOverlay_recent_apps", true, false) as Control
	if not is_instance_valid(overlay):
		_build_samsung_gen1_overview()
		return
	if _recent_app_names.is_empty():
		var empty_label := Label.new()
		empty_label.name = "SamsungGen1OverviewEmptyState"
		empty_label.text = "No recent apps"
		empty_label.position = Vector2(18.0, 88.0)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color("#FFFFFF"))
		overlay.add_child(empty_label)


func _samsung_gen1_overview_card_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	style.set_border_width_all(0)
	return style

func _samsung_gen1_overview_app_color(app_name: String) -> Color:
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

func _build_samsung_gen1_overview_preview(parent: VBoxContainer, app_name: String) -> void:
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
			_add_samsung_gen1_overview_preview_row(parent, "Alex Morgan", "Are we still meeting today?", Color("#4C91C7"))
			_add_samsung_gen1_overview_preview_row(parent, "Family", "Thanks, see you soon.", Color("#4B9B78"))
			_add_samsung_gen1_overview_preview_row(parent, "Work", "The document is ready.", Color("#CE765D"))
		"Settings":
			_add_samsung_gen1_overview_preview_row(parent, "Wireless & networks", "Wi-Fi, Bluetooth, data usage", Color("#4C91C7"))
			_add_samsung_gen1_overview_preview_row(parent, "Device", "Display, sound, storage", Color("#4B9B78"))
			_add_samsung_gen1_overview_preview_row(parent, "Personal", "Location, security, accounts", Color("#CE765D"))
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
			parent.add_child(_label(_samsung_gen1_overview_preview_text(app_name), 11, Color("#455A64")))
			for line_index in range(3):
				var preview_line := ColorRect.new()
				preview_line.color = Color("#CFD8DC")
				preview_line.custom_minimum_size = Vector2(0.0, 4.0)
				parent.add_child(preview_line)

func _add_samsung_gen1_overview_preview_row(parent: VBoxContainer, primary_text: String, secondary_text: String, avatar_color: Color) -> void:
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

func _set_samsung_gen1_overview_underlay_visible(should_show: bool) -> void:
	var component_content := find_child("OSComponentContent", true, false) as Control
	if is_instance_valid(component_content):
		component_content.visible = should_show
func _samsung_gen1_overview_preview_text(app_name: String) -> String:
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

func _close_gesture_overlay() -> void:
	var was_recent_apps := _gesture_overlay != null and is_instance_valid(_gesture_overlay) and _gesture_overlay.name == "OSGestureOverlay_recent_apps"
	if _gesture_overlay != null and is_instance_valid(_gesture_overlay):
		_gesture_overlay.queue_free()
		_gesture_overlay = null
	if was_recent_apps:
		var overview_navigation_footer := find_child("SamsungGen1OverviewNavigationFooter", true, false) as Control
		if is_instance_valid(overview_navigation_footer):
			overview_navigation_footer.queue_free()
		var original_navigation_bar := find_child("AndroidNavigationBar", true, false) as Control
		if is_instance_valid(original_navigation_bar):
			original_navigation_bar.visible = true
		_set_samsung_gen1_overview_underlay_visible(true)
func _ready() -> void:
	LOCKSCREEN_FONT = load("res://assets/fonts/STIXTwoText[wght].ttf") as FontFile
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
	if component_id in ["pin_input", "recent_apps"]:
		return component_id
	for component in OSEngine.COMPONENTS:
		if str(component["id"]) == component_id:
			return component_id
	return "home_screen"

func _is_android_os() -> bool:
	return str(configuration.get("components", {}).get("home_screen", {}).get("layout_style", "android_pixel")) == "android_pixel"

func _is_gen1_samsung_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 1 and str(configuration.get("style", {}).get("ui_family", "samsung_touchwiz")) == "samsung_touchwiz"

func _is_gen1_pixel_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 1 and str(configuration.get("style", {}).get("ui_family", "samsung_touchwiz")) == "google_stock"

func _is_gen1_xiaomi_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 1 and str(configuration.get("style", {}).get("ui_family", "samsung_touchwiz")) == "xiaomi_miui"

func _is_gen2_samsung_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 2 and str(configuration.get("style", {}).get("ui_family", "samsung_experience")) == "samsung_experience"

func _is_gen2_pixel_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 2 and str(configuration.get("style", {}).get("ui_family", "samsung_experience")) == "google_pixel"

func _is_gen2_xiaomi_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 2 and str(configuration.get("style", {}).get("ui_family", "samsung_experience")) == "xiaomi_miui8"

func _is_gen3_samsung_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 3 and str(configuration.get("style", {}).get("ui_family", "samsung_experience9")) == "samsung_experience9"

func _is_gen3_pixel_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 3 and str(configuration.get("style", {}).get("ui_family", "samsung_experience9")) == "google_pixel8"

func _is_gen3_xiaomi_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 3 and str(configuration.get("style", {}).get("ui_family", "samsung_experience9")) == "xiaomi_miui9"

func _is_gen4_samsung_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 4 and str(configuration.get("style", {}).get("ui_family", "samsung_oneui2")) == "samsung_oneui2"

func _is_gen4_pixel_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 4 and str(configuration.get("style", {}).get("ui_family", "samsung_oneui2")) == "google_pixel10"

func _is_gen4_xiaomi_ui() -> bool:
	return _is_android_os() and int(configuration.get("generation", 0)) == 4 and str(configuration.get("style", {}).get("ui_family", "samsung_oneui2")) == "xiaomi_miui11"


func _uses_gen1_reference_screenshot(component_id: String = "") -> bool:
	var target_component := active_component if component_id.is_empty() else component_id
	if _is_gen1_samsung_ui() and SAMSUNG_GEN1_SCREEN_ASSETS.has(target_component):
		return true
	if _is_gen1_pixel_ui() and PIXEL_GEN1_SCREEN_ASSETS.has(target_component):
		return target_component != "recent_apps"
	if _is_gen1_xiaomi_ui() and XIAOMI_GEN1_SCREEN_ASSETS.has(target_component):
		if target_component == "recent_apps":
			return false
		var xiaomi_path := "res://assets/os/gen1/miui/" + str(XIAOMI_GEN1_SCREEN_ASSETS[target_component])
		return ResourceLoader.exists(xiaomi_path)
	return false

func _uses_gen2_reference_screenshot(component_id: String = "") -> bool:
	var target_component := active_component if component_id.is_empty() else component_id
	if _is_gen2_samsung_ui():
		return SAMSUNG_GEN2_SCREEN_ASSETS.has(target_component)
	if _is_gen2_pixel_ui():
		return PIXEL_GEN2_SCREEN_ASSETS.has(target_component)
	if _is_gen2_xiaomi_ui():
		return XIAOMI_GEN2_SCREEN_ASSETS.has(target_component)
	return false

func _add_gen2_family_screenshot(parent: Control, component_id: String) -> TextureRect:
	var family_folder := "samsung"
	var family_label := "Samsung Experience 8"
	var family_prefix := "Samsung"
	var assets: Dictionary = SAMSUNG_GEN2_SCREEN_ASSETS
	if _is_gen2_pixel_ui():
		family_folder = "pixel"
		family_label = "Google Pixel Android 7"
		family_prefix = "Pixel"
		assets = PIXEL_GEN2_SCREEN_ASSETS
	elif _is_gen2_xiaomi_ui():
		family_folder = "miui"
		family_label = "Xiaomi MIUI 8"
		family_prefix = "Xiaomi"
		assets = XIAOMI_GEN2_SCREEN_ASSETS
	var filename := str(assets.get(component_id, ""))
	if filename.is_empty():
		push_error("No Gen 2 screenshot is registered for component: " + component_id)
		return null
	var asset_path := "res://assets/os/gen2/" + family_folder + "/" + filename
	if not ResourceLoader.exists(asset_path):
		push_error(family_label + " Gen 2 screenshot asset is missing: " + asset_path)
		return null
	var screenshot := TextureRect.new()
	screenshot.name = family_prefix + "Gen2ScreenImage_" + component_id
	screenshot.texture = load(asset_path) as Texture2D
	if screenshot.texture == null:
		push_error(family_label + " Gen 2 screenshot could not be loaded: " + asset_path)
		return null
	screenshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screenshot.stretch_mode = TextureRect.STRETCH_SCALE
	screenshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_gen1_screenshot_brightness(screenshot)
	screenshot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screenshot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(screenshot)
	if not parent is Container:
		screenshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screenshot

func _uses_gen3_reference_screenshot(component_id: String = "") -> bool:
	var target_component := active_component if component_id.is_empty() else component_id
	if _is_gen3_samsung_ui():
		return SAMSUNG_GEN3_SCREEN_ASSETS.has(target_component)
	if _is_gen3_pixel_ui():
		return PIXEL_GEN3_SCREEN_ASSETS.has(target_component)
	if _is_gen3_xiaomi_ui():
		return XIAOMI_GEN3_SCREEN_ASSETS.has(target_component)
	return false

func _add_gen3_family_screenshot(parent: Control, component_id: String) -> TextureRect:
	var family_folder := "samsung"
	var family_label := "Samsung Experience 9.0"
	var family_prefix := "Samsung"
	var assets: Dictionary = SAMSUNG_GEN3_SCREEN_ASSETS
	if _is_gen3_pixel_ui():
		family_folder = "pixel"
		family_label = "Google Pixel Android 8"
		family_prefix = "Pixel"
		assets = PIXEL_GEN3_SCREEN_ASSETS
	elif _is_gen3_xiaomi_ui():
		family_folder = "miui"
		family_label = "Xiaomi MIUI 9.5"
		family_prefix = "Xiaomi"
		assets = XIAOMI_GEN3_SCREEN_ASSETS
	var filename := str(assets.get(component_id, ""))
	if filename.is_empty():
		push_error("No Gen 3 screenshot is registered for component: " + component_id)
		return null
	var asset_path := "res://assets/os/gen3/" + family_folder + "/" + filename
	if not ResourceLoader.exists(asset_path):
		push_error(family_label + " Gen 3 screenshot asset is missing: " + asset_path)
		return null
	var screenshot := TextureRect.new()
	screenshot.name = family_prefix + "Gen3ScreenImage_" + component_id
	screenshot.texture = load(asset_path) as Texture2D
	if screenshot.texture == null:
		push_error(family_label + " Gen 3 screenshot could not be loaded: " + asset_path)
		return null
	screenshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screenshot.stretch_mode = TextureRect.STRETCH_SCALE
	screenshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_gen1_screenshot_brightness(screenshot)
	screenshot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screenshot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(screenshot)
	if not parent is Container:
		screenshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screenshot

func _uses_gen4_reference_screenshot(component_id: String = "") -> bool:
	var target_component := active_component if component_id.is_empty() else component_id
	if _is_gen4_samsung_ui():
		return SAMSUNG_GEN4_SCREEN_ASSETS.has(target_component)
	if _is_gen4_pixel_ui():
		return PIXEL_GEN4_SCREEN_ASSETS.has(target_component)
	if _is_gen4_xiaomi_ui():
		return XIAOMI_GEN4_SCREEN_ASSETS.has(target_component)
	return false

func _add_gen4_family_screenshot(parent: Control, component_id: String) -> TextureRect:
	var family_folder := "samsung"
	var family_label := "Samsung One UI 2.0"
	var family_prefix := "Samsung"
	var assets: Dictionary = SAMSUNG_GEN4_SCREEN_ASSETS
	if _is_gen4_pixel_ui():
		family_folder = "pixel"
		family_label = "Google Pixel Android 10"
		family_prefix = "Pixel"
		assets = PIXEL_GEN4_SCREEN_ASSETS
	elif _is_gen4_xiaomi_ui():
		family_folder = "miui"
		family_label = "Xiaomi MIUI 11"
		family_prefix = "Xiaomi"
		assets = XIAOMI_GEN4_SCREEN_ASSETS
	var filename := str(assets.get(component_id, ""))
	if filename.is_empty():
		push_error("No Gen 4 screenshot is registered for component: " + component_id)
		return null
	var asset_path := "res://assets/os/gen4/" + family_folder + "/" + filename
	if not ResourceLoader.exists(asset_path):
		push_error(family_label + " Gen 4 screenshot asset is missing: " + asset_path)
		return null
	var screenshot := TextureRect.new()
	screenshot.name = family_prefix + "Gen4ScreenImage_" + component_id
	screenshot.texture = load(asset_path) as Texture2D
	if screenshot.texture == null:
		push_error(family_label + " Gen 4 screenshot could not be loaded: " + asset_path)
		return null
	screenshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screenshot.stretch_mode = TextureRect.STRETCH_SCALE
	screenshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_gen1_screenshot_brightness(screenshot)
	screenshot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screenshot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(screenshot)
	if not parent is Container:
		screenshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screenshot

func _add_gen1_family_screenshot(parent: Control, component_id: String) -> TextureRect:
	var family_folder := "samsung"
	var family_label := "Samsung"
	var family_prefix := "Samsung"
	var assets: Dictionary = SAMSUNG_GEN1_SCREEN_ASSETS
	if _is_gen1_pixel_ui():
		family_folder = "pixel"
		family_label = "Pixel"
		family_prefix = "Pixel"
		assets = PIXEL_GEN1_SCREEN_ASSETS
	elif _is_gen1_xiaomi_ui():
		family_folder = "miui"
		family_label = "Xiaomi MIUI"
		family_prefix = "Xiaomi"
		assets = XIAOMI_GEN1_SCREEN_ASSETS
	var filename := str(assets.get(component_id, ""))
	if filename.is_empty():
		push_error("No Gen 1 screenshot is registered for component: " + component_id)
		return null
	var asset_path := "res://assets/os/gen1/" + family_folder + "/" + filename
	if not ResourceLoader.exists(asset_path):
		push_error(family_label + " Gen 1 screenshot asset is missing: " + asset_path)
		return null
	var screenshot := TextureRect.new()
	screenshot.name = family_prefix + "Gen1ScreenImage_" + component_id
	screenshot.texture = load(asset_path) as Texture2D
	if screenshot.texture == null:
		push_error("Samsung Gen 1 screenshot could not be loaded: " + asset_path)
		return null
	screenshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screenshot.stretch_mode = TextureRect.STRETCH_SCALE
	screenshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_gen1_screenshot_brightness(screenshot)
	screenshot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screenshot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(screenshot)
	if not parent is Container:
		screenshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screenshot


func _set_gen1_screenshot_brightness(screenshot: TextureRect) -> void:
	if screenshot == null:
		return
	var brightness_scale := lerpf(0.12, 1.0, float(_brightness_level) / 100.0)
	screenshot.modulate = Color(brightness_scale, brightness_scale, brightness_scale, 1.0)


func _build_android_navigation(parent: VBoxContainer, back_only: bool = false) -> void:
	parent.add_theme_constant_override("separation", 0)
	var navigation_bar := PanelContainer.new()
	navigation_bar.name = "AndroidNavigationBar"
	navigation_bar.custom_minimum_size = Vector2(0, 40)
	navigation_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bar_style.set_border_width_all(0)
	bar_style.set_corner_radius_all(0)
	bar_style.content_margin_left = 0
	bar_style.content_margin_right = 0
	bar_style.content_margin_top = 0
	bar_style.content_margin_bottom = 0
	navigation_bar.add_theme_stylebox_override("panel", bar_style)

	var is_samsung_overview := parent.name in ["SamsungGen1OverviewNavigationFooter", "SamsungGen2OverviewNavigationFooter", "SamsungGen3OverviewNavigationFooter", "SamsungGen4OverviewNavigationFooter"]
	var generation_prefix := "Gen4" if _is_gen4_phone_ui() else "Gen3" if _is_gen3_phone_ui() else "Gen2" if _is_gen2_phone_ui() else "Gen1"
	var family_prefix := "Samsung" + generation_prefix if _is_gen1_samsung_ui() or _is_gen2_samsung_ui() or _is_gen3_samsung_ui() or _is_gen4_samsung_ui() else "Pixel" + generation_prefix if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui() else "Xiaomi" + generation_prefix if _is_gen1_xiaomi_ui() or _is_gen2_xiaomi_ui() or _is_gen3_xiaomi_ui() or _is_gen4_xiaomi_ui() else "Android"
	var navigation_keys := HBoxContainer.new()
	navigation_keys.name = family_prefix + ("OverviewThreeButtonNavigation" if is_samsung_overview else "ThreeButtonNavigation")
	navigation_keys.custom_minimum_size.y = 40
	navigation_keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation_keys.mouse_filter = Control.MOUSE_FILTER_PASS
	navigation_keys.add_theme_constant_override("separation", 2)

	if back_only:
		for spacer_index in range(2):
			var spacer := Control.new()
			spacer.name = "AndroidNavigationReservedSlot" + str(spacer_index + 1)
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			navigation_keys.add_child(spacer)

	var navigation_actions := ["Back"] if back_only else ["Overview", "Home", "Back"]
	for action in navigation_actions:
		var key := AndroidNavigationButton.new()
		key.name = family_prefix + "Navigation" + action
		key.action_name = action
		key.icon_color = Color("#F5F7F8") if _is_gen1_samsung_ui() or _is_gen2_samsung_ui() or _is_gen3_samsung_ui() or _is_gen4_samsung_ui() else Color("#DCE7F5") if _is_gen1_pixel_ui() or _is_gen2_pixel_ui() or _is_gen3_pixel_ui() or _is_gen4_pixel_ui() else Color("#D9E8F8") if _is_gen1_xiaomi_ui() or _is_gen2_xiaomi_ui() or _is_gen3_xiaomi_ui() or _is_gen4_xiaomi_ui() else Color("#F5F7F8")
		key.tooltip_text = "Recent" if action == "Overview" else action
		key.custom_minimum_size = Vector2(30, 38)
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
			if _is_gen1_phone_ui() or _is_gen2_phone_ui() or _is_gen3_phone_ui() or _is_gen4_phone_ui():
				_show_gesture_overlay("recent_apps")
			else:
				set_component_view("recent_apps")
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
		child.queue_free()
	_style = configuration.get("style", {})
	_palette = _style.get("palette", {"background":"#0B1017","surface":"#19232E","surface_alt":"#263544","accent":"#76C8D4","text":"#F4F7F8","muted":"#A7B4BD"})
	var screenshot_backed_screen := _uses_gen1_reference_screenshot(active_component) or _uses_gen2_reference_screenshot(active_component) or _uses_gen3_reference_screenshot(active_component) or _uses_gen4_reference_screenshot(active_component)
	if not screenshot_backed_screen:
		var wallpaper := OSWallpaperLayer.new()
		wallpaper.name = "OSProceduralWallpaper"
		wallpaper.palette = _palette.duplicate(true)
		wallpaper.wallpaper_id = str(_style.get("wallpaper", "touchwiz_nature"))
		wallpaper.treatment = str(configuration.get("components", {}).get("wallpapers", {}).get("treatment", "natural"))
		wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(wallpaper)
	var safe_area := MarginContainer.new()
	safe_area.name = "OSSimulatorSafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen_margin := 0 if screenshot_backed_screen else 12
	var vertical_margin := 0 if screenshot_backed_screen else 7
	safe_area.add_theme_constant_override("margin_left", screen_margin)
	safe_area.add_theme_constant_override("margin_right", screen_margin)
	safe_area.add_theme_constant_override("margin_top", vertical_margin)
	safe_area.add_theme_constant_override("margin_bottom", vertical_margin)
	add_child(safe_area)

	if active_component in ["lock_screen", "pin_input"]:
		var lock_shell := VBoxContainer.new()
		lock_shell.name = "OSLockScreenShell" if active_component == "lock_screen" else "OSPinInputShell"
		lock_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lock_shell.add_theme_constant_override("separation", 3)
		safe_area.add_child(lock_shell)
		if not screenshot_backed_screen:
			_build_status_bar(lock_shell)
		if active_component == "pin_input":
			var pin_status_bar := lock_shell.get_node_or_null("OSStatusBar") as Control
			if pin_status_bar != null:
				pin_status_bar.visible = false
		page_container = VBoxContainer.new()
		page_container.name = "OSComponentContent"
		page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page_container.add_theme_constant_override("separation", 0)
		lock_shell.add_child(page_container)
		_build_component(active_component)
		if active_component == "pin_input":
			var pin_navigation_footer := VBoxContainer.new()
			pin_navigation_footer.name = "OSNavigationFooter"
			pin_navigation_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_build_android_navigation(pin_navigation_footer, true)
			lock_shell.add_child(pin_navigation_footer)
		elif _is_gen1_pixel_ui() or _is_gen1_xiaomi_ui() or _is_gen2_phone_ui() or _is_gen3_phone_ui() or _is_gen4_phone_ui():
			var lock_navigation_footer := VBoxContainer.new()
			lock_navigation_footer.name = "OSNavigationFooter"
			lock_navigation_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_build_android_navigation(lock_navigation_footer)
			lock_shell.add_child(lock_navigation_footer)
		_add_screen_corner_mask()
		_building = false
		return

	var shell := VBoxContainer.new()
	shell.name = "OSSimulatorLayout"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 6)
	safe_area.add_child(shell)
	if not screenshot_backed_screen:
		_build_status_bar(shell)
	page_container = VBoxContainer.new()
	page_container.name = "OSComponentContent"
	page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_theme_constant_override("separation", int(_style.get("spacing", 8)))
	if screenshot_backed_screen:
		page_container.add_theme_constant_override("separation", 0)
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
	_build_android_navigation(footer)
	shell.add_child(footer)
	if active_component == "home_screen":
		_apply_home_screen_icon_styles()
	_add_screen_corner_mask()
	_building = false
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
	row.add_child(clock)
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
	bar.add_child(status_label)
	parent.add_child(bar)

func _build_component(component_id: String) -> void:
	if _uses_gen4_reference_screenshot(component_id):
		_add_gen4_family_screenshot(page_container, component_id)
		return
	if _uses_gen3_reference_screenshot(component_id):
		_add_gen3_family_screenshot(page_container, component_id)
		return
	if _uses_gen2_reference_screenshot(component_id):
		_add_gen2_family_screenshot(page_container, component_id)
		return
	if _uses_gen1_reference_screenshot(component_id):
		_add_gen1_family_screenshot(page_container, component_id)
		return
	if _is_gen1_xiaomi_ui() and component_id in ["lock_screen", "home_screen", "app_drawer", "control_center", "notifications"]:
		_build_gen1_xiaomi_reference_placeholder(component_id)
		return
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
func _build_gen1_xiaomi_reference_placeholder(component_id: String) -> void:
	var family_panel := PanelContainer.new()
	family_panel.name = "XiaomiGen1ReferencePending_" + component_id
	family_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#171717")
	panel_style.border_color = Color("#FF6900")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	family_panel.add_theme_stylebox_override("panel", panel_style)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	family_panel.add_child(content)
	var title := _label("XIAOMI MIUI · ANDROID 4.0 ERA", 14, Color("#FF8A35"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var component_title := _label(component_id.replace("_", " ").to_upper(), 11, Color("#F5F5F5"))
	component_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(component_title)
	var note := _label("The MIUI Gen 1 reference screenshot for this component has not been uploaded yet.", 10, Color("#BDBDBD"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	page_container.add_child(family_panel)


func _build_home_screen(_data: Dictionary) -> void:
	_add_gen1_family_screenshot(page_container, "home_screen")
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

func _build_lock_screen(_data: Dictionary) -> void:
	_add_gen1_family_screenshot(page_container, "lock_screen")
func _build_pin_input() -> void:
	var layout := VBoxContainer.new()
	layout.name = "PINInputScreen"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 10)
	page_container.add_child(layout)
	_build_pin_input_header(layout)
	_build_pin_input_keypad(layout)
	_build_pin_input_footer(layout)
func _build_pin_input_header(layout: VBoxContainer) -> void:
	var lock_indicator_stage := CenterContainer.new()
	lock_indicator_stage.name = "PINLockIndicatorStage"
	lock_indicator_stage.custom_minimum_size.y = 28
	var lock_indicator := PINLockIndicator.new()
	lock_indicator.name = "PINLockIndicator"
	lock_indicator.custom_minimum_size = Vector2(28.0, 24.0)
	lock_indicator_stage.add_child(lock_indicator)
	layout.add_child(lock_indicator_stage)
	var title := _label("Enter PIN", 18, _text_color())
	title.name = "PINEntryTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 26
	layout.add_child(title)
	var subtitle := _label("Enter your 4-digit screen lock.", 9, _muted_color())
	subtitle.name = "PINEntrySubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size.y = 16
	layout.add_child(subtitle)
	var dots := _label("○   ○   ○   ○", 14, _text_color())
	dots.name = "PINEntryDots"
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dots.custom_minimum_size.y = 28
	layout.add_child(dots)
	var error_label := _label(_pin_error_message, 7, Color("#FF9AA8"))
	error_label.name = "PINEntryError"
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.custom_minimum_size.y = 18
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
	var info_label := _label("Preview PIN  ·  1234", 8, Color(1.0, 1.0, 1.0, 0.62))
	info_label.name = "PINPreviewUnlockInfoLabel"
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
	art.wallpaper_id = str(data.get("style", data.get("id", "touchwiz_nature")))
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
	_add_gen1_family_screenshot(page_container, "control_center")
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
	_add_gen1_family_screenshot(page_container, "notifications")
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

func _build_app_drawer(_data: Dictionary) -> void:
	_add_gen1_family_screenshot(page_container, "app_drawer")

func _build_recent_apps(_data: Dictionary) -> void:
	if _is_gen1_pixel_ui() or _is_gen1_xiaomi_ui():
		_build_gen1_family_recent_apps(page_container)
		return
	_add_gen1_family_screenshot(page_container, "recent_apps")
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
	icon.focus_mode = Control.FOCUS_NONE
	icon.text = str(app.get("glyph", "•"))
	icon.add_theme_font_size_override("font_size", maxi(16, int(icon_size * 0.50)))
	_style_icon_button(icon, Color(str(app.get("color", "#687987"))), str(configuration.get("style", {}).get("icon_shape", "square")))
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
