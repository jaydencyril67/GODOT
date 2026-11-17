extends Control

const SVG_ROOT := "res://assets/lock-screen/aosp/SVG"

const PALETTES := [
	{
		"name": "MIDNIGHT BLUE",
		"top": Color("#111D35"),
		"bottom": Color("#080D1C"),
		"glow": Color("#4F85D8"),
		"accent": Color("#A9C9FF"),
		"text": Color("#F3F6FF"),
		"muted": Color("#C3CFE3"),
		"glass": Color("#17243B")
	},
	{
		"name": "OBSIDIAN",
		"top": Color("#292725"),
		"bottom": Color("#090A0B"),
		"glow": Color("#A98A69"),
		"accent": Color("#E3C39B"),
		"text": Color("#FFF8EE"),
		"muted": Color("#D3C6B5"),
		"glass": Color("#302B25")
	},
	{
		"name": "FOREST",
		"top": Color("#12352F"),
		"bottom": Color("#071714"),
		"glow": Color("#4BA58C"),
		"accent": Color("#9DE4C8"),
		"text": Color("#F0FFF8"),
		"muted": Color("#BEDBD0"),
		"glass": Color("#163A31")
	},
	{
		"name": "VIOLET DUSK",
		"top": Color("#34254B"),
		"bottom": Color("#100B1C"),
		"glow": Color("#9C72D1"),
		"accent": Color("#D8B9FF"),
		"text": Color("#FBF6FF"),
		"muted": Color("#D7C9E9"),
		"glass": Color("#342545")
	},
	{
		"name": "EMBER",
		"top": Color("#48271F"),
		"bottom": Color("#170C0A"),
		"glow": Color("#D47A51"),
		"accent": Color("#FFC09A"),
		"text": Color("#FFF7F2"),
		"muted": Color("#E7C9BC"),
		"glass": Color("#492A21")
	},
	{
		"name": "ARCTIC",
		"top": Color("#25404C"),
		"bottom": Color("#0A151C"),
		"glow": Color("#77B6C8"),
		"accent": Color("#B9F0F8"),
		"text": Color("#F2FDFF"),
		"muted": Color("#C5E0E5"),
		"glass": Color("#24424D")
	},
	{
		"name": "BURGUNDY",
		"top": Color("#482333"),
		"bottom": Color("#160912"),
		"glow": Color("#C36D8D"),
		"accent": Color("#F1B0C5"),
		"text": Color("#FFF5F8"),
		"muted": Color("#E5C4CF"),
		"glass": Color("#482334")
	},
	{
		"name": "GRAPHITE",
		"top": Color("#343B42"),
		"bottom": Color("#0B0E12"),
		"glow": Color("#8C9AA8"),
		"accent": Color("#E2E9F0"),
		"text": Color("#F8FAFC"),
		"muted": Color("#CCD4DD"),
		"glass": Color("#313A43")
	}
]

const APP_NAMES := ["MESSAGES", "CALENDAR", "SYSTEM", "REMINDERS", "WEATHER"]
const NOTIFICATION_TITLES := [
	"One new message",
	"Your next event is coming up",
	"System update is ready",
	"Daily reminder",
	"Rain expected this evening"
]
const NOTIFICATION_BODIES := [
	"You have something new waiting for you.",
	"Your schedule has been updated.",
	"Everything is ready when you are.",
	"Take a moment to review your latest update.",
	"Tap to see the full details."
]
const WEEKDAYS := ["", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
const MONTHS := ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

var _rng := RandomNumberGenerator.new()
var _recent_signatures: Array[String] = []
var _last_design: Dictionary = {}
var _generation_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()


func generate_new_design() -> Dictionary:
	var candidate: Dictionary = {}
	var signature := ""
	for _attempt in range(48):
		candidate = _compose_design()
		var issues := validate_layout(candidate)
		signature = str(candidate.get("signature", ""))
		if issues.is_empty() and not _recent_signatures.has(signature):
			break

	if candidate.is_empty() or not validate_layout(candidate).is_empty():
		return {}

	_generation_count += 1
	candidate["generation"] = _generation_count
	_last_design = candidate
	_recent_signatures.append(signature)
	if _recent_signatures.size() > 30:
		_recent_signatures.pop_front()
	_render_design(_last_design)
	return _last_design.duplicate(true)


func get_last_design() -> Dictionary:
	return _last_design.duplicate(true)


func get_generation_count() -> int:
	return _generation_count


func validate_layout(design: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var components: Array = design.get("components", [])
	if components.size() < 5:
		issues.append("The composition is missing required lock-screen components.")
		return issues

	var occupied: Array[Rect2] = []
	for component in components:
		var rect: Rect2 = component.get("rect", Rect2())
		var role := str(component.get("role", ""))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			issues.append("%s has an empty component rectangle." % role)
			continue
		if rect.position.x < 0.025 or rect.position.y < 0.015 or rect.end.x > 0.975 or rect.end.y > 0.985:
			issues.append("%s extends outside the screen safe area." % role)
		if role == "status" and rect.end.y > 0.085:
			issues.append("The status area has left its top zone.")
		if role == "bottom_shortcut" and rect.position.y < 0.885:
			issues.append("A bottom shortcut has left the designated bottom zone.")
		if role == "fingerprint" and (rect.position.y < 0.775 or rect.end.y > 0.88):
			issues.append("The fingerprint component has left its lower-screen zone.")
		for existing in occupied:
			if rect.grow(0.006).intersects(existing.grow(0.006)):
				issues.append("%s collides with another independent component." % role)
				break
		occupied.append(rect)

	var shortcuts: Array = design.get("shortcuts", [])
	if shortcuts.size() != 2:
		issues.append("The lock screen must have separate flashlight and camera shortcuts.")
	else:
		for shortcut in shortcuts:
			if str(shortcut.get("kind", "")) not in ["flashlight", "camera"]:
				issues.append("An unsupported bottom shortcut was generated.")
			var shortcut_rect: Rect2 = shortcut.get("rect", Rect2())
			if shortcut_rect.position.y < 0.885:
				issues.append("A shortcut was incorrectly positioned outside the bottom zone.")

	return issues


func _compose_design() -> Dictionary:
	var palette: Dictionary = PALETTES[_rng.randi_range(0, PALETTES.size() - 1)]
	var components: Array[Dictionary] = []
	var occupied: Array[Rect2] = []

	var status_rect := Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035))
	_add_component(components, occupied, "status", status_rect)

	var clock_style := "digital"
	var style_roll := _rng.randi_range(0, 99)
	if style_roll >= 88:
		clock_style = "analog"
	elif style_roll >= 63:
		clock_style = "stacked"

	var clock_rect := _make_clock_rect(clock_style)
	_add_component(components, occupied, "clock", clock_rect)

	var date_width := _rng.randf_range(0.36, 0.78)
	var date_height := _rng.randf_range(0.028, 0.043)
	var date_x := clampf(clock_rect.position.x + _rng.randf_range(0.0, maxf(clock_rect.size.x - date_width, 0.0)), 0.055, 0.945 - date_width)
	var date_above := _rng.randf() >= 0.5
	var date_y := clock_rect.position.y - date_height - 0.018 if date_above else clock_rect.end.y + 0.018
	var date_rect := Rect2(Vector2(date_x, date_y), Vector2(date_width, date_height))
	if not _can_place(date_rect, occupied):
		date_y = clock_rect.end.y + 0.026 if date_above else clock_rect.position.y - date_height - 0.026
		date_rect.position.y = date_y
	if not _can_place(date_rect, occupied):
		date_rect.position.x = 0.5 - date_width * 0.5
		date_rect.position.y = 0.715
	if _can_place(date_rect, occupied):
		_add_component(components, occupied, "date", date_rect)
	else:
		return {}

	var notification_count := _rng.randi_range(1, 2)
	var notifications: Array[Dictionary] = []
	for notification_index in range(notification_count):
		var notification_rect := _find_notification_rect(occupied, notification_index)
		if notification_rect.size == Vector2.ZERO:
			continue
		var notification := {
			"rect": notification_rect,
			"app": APP_NAMES[_rng.randi_range(0, APP_NAMES.size() - 1)],
			"title": NOTIFICATION_TITLES[_rng.randi_range(0, NOTIFICATION_TITLES.size() - 1)],
			"body": NOTIFICATION_BODIES[_rng.randi_range(0, NOTIFICATION_BODIES.size() - 1)]
		}
		notifications.append(notification)
		_add_component(components, occupied, "notification", notification_rect)

	var show_fingerprint := _rng.randf() >= 0.16
	if show_fingerprint:
		var fingerprint_rect := Rect2(
			Vector2(_rng.randf_range(0.33, 0.42), _rng.randf_range(0.795, 0.825)),
			Vector2(_rng.randf_range(0.16, 0.34), 0.045)
		)
		if _can_place(fingerprint_rect, occupied):
			_add_component(components, occupied, "fingerprint", fingerprint_rect)
		else:
			show_fingerprint = false

	var shortcut_y := _rng.randf_range(0.90, 0.91)
	var shortcut_size := Vector2(_rng.randf_range(0.115, 0.145), _rng.randf_range(0.060, 0.070))
	var flashlight_rect := Rect2(Vector2(_rng.randf_range(0.105, 0.145), shortcut_y), shortcut_size)
	var camera_rect := Rect2(Vector2(_rng.randf_range(0.755, 0.795), shortcut_y), shortcut_size)
	_add_component(components, occupied, "bottom_shortcut", flashlight_rect)
	_add_component(components, occupied, "bottom_shortcut", camera_rect)

	var glow_count := _rng.randi_range(2, 4)
	var glows: Array[Dictionary] = []
	for _glow_index in range(glow_count):
		glows.append({
			"rect": Rect2(
				Vector2(_rng.randf_range(-0.12, 0.70), _rng.randf_range(0.08, 0.70)),
				Vector2(_rng.randf_range(0.28, 0.62), _rng.randf_range(0.12, 0.28))
			),
			"alpha": _rng.randf_range(0.055, 0.13)
		})

	var clock_align := ["left", "center", "right"][_rng.randi_range(0, 2)]
	var clock_format := "single"
	if clock_style == "stacked":
		clock_format = "split"
	elif clock_style == "digital" and _rng.randf() > 0.72:
		clock_format = "spaced"

	var design := {
		"palette": palette,
		"components": components,
		"clock_rect": clock_rect,
		"clock_style": clock_style,
		"clock_format": clock_format,
		"clock_align": clock_align,
		"clock_font_size": _rng.randi_range(94, 148) if clock_style != "analog" else 0,
		"date_font_size": _rng.randi_range(17, 25),
		"date_letter_spacing": _rng.randi_range(1, 4),
		"notifications": notifications,
		"show_fingerprint": show_fingerprint,
		"shortcuts": [
			{"kind": "flashlight", "rect": flashlight_rect},
			{"kind": "camera", "rect": camera_rect}
		],
		"glows": glows
	}
	design["signature"] = _make_signature(design)
	return design


func _make_clock_rect(style: String) -> Rect2:
	if style == "analog":
		var size_x := 0.30
		return Rect2(
			Vector2(_rng.randf_range(0.14, 0.56), _rng.randf_range(0.19, 0.40)),
			Vector2(size_x, size_x * 0.5)
		)
	if style == "stacked":
		var width := _rng.randf_range(0.40, 0.62)
		return Rect2(
			Vector2(_rng.randf_range(0.08, maxf(0.08, 0.945 - width)), _rng.randf_range(0.18, 0.37)),
			Vector2(width, _rng.randf_range(0.15, 0.205))
		)
	var digital_width := _rng.randf_range(0.66, 0.88)
	return Rect2(
		Vector2(_rng.randf_range(0.07, maxf(0.07, 0.945 - digital_width)), _rng.randf_range(0.19, 0.39)),
		Vector2(digital_width, _rng.randf_range(0.105, 0.17))
	)


func _find_notification_rect(occupied: Array[Rect2], index: int) -> Rect2:
	var height := _rng.randf_range(0.060, 0.078)
	for _attempt in range(36):
		var width := _rng.randf_range(0.76, 0.88)
		var x := _rng.randf_range(0.06, 0.94 - width)
		var y := _rng.randf_range(0.535, 0.735)
		if index > 0:
			y = _rng.randf_range(0.62, 0.735)
		var candidate := Rect2(Vector2(x, y), Vector2(width, height))
		if _can_place(candidate, occupied):
			return candidate
	return Rect2()


func _add_component(components: Array[Dictionary], occupied: Array[Rect2], role: String, rect: Rect2) -> void:
	components.append({"role": role, "rect": rect})
	occupied.append(rect)


func _can_place(rect: Rect2, occupied: Array[Rect2]) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	if rect.position.x < 0.045 or rect.position.y < 0.105 or rect.end.x > 0.955 or rect.end.y > 0.775:
		return false
	for existing in occupied:
		if rect.grow(0.008).intersects(existing.grow(0.008)):
			return false
	return true


func _make_signature(design: Dictionary) -> String:
	var parts: Array[String] = [
		str(design.get("clock_style", "")),
		str(design.get("clock_format", "")),
		str(design.get("clock_align", "")),
		str(design.get("palette", {}).get("name", ""))
	]
	for component in design.get("components", []):
		var rect: Rect2 = component.get("rect", Rect2())
		parts.append("%s:%d:%d:%d:%d" % [
			str(component.get("role", "")),
			roundi(rect.position.x * 100.0),
			roundi(rect.position.y * 100.0),
			roundi(rect.size.x * 100.0),
			roundi(rect.size.y * 100.0)
		])
	return "|".join(parts)


func _render_design(design: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var palette: Dictionary = design["palette"]
	_add_wallpaper(palette)
	for glow in design["glows"]:
		_add_glow(glow, palette["glow"])
	_add_status_bar(palette)
	_add_clock(design, palette)
	_add_date(design, palette)
	for index in range(design["notifications"].size()):
		_add_notification(design["notifications"][index], _notification_component_rect(design, index), palette)
	if bool(design["show_fingerprint"]):
		_add_fingerprint(design, palette)
	_add_shortcuts(design, palette)


func _add_wallpaper(palette: Dictionary) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([palette["top"], palette["bottom"]])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 512
	texture.fill_from = Vector2(0.12, 0.0)
	texture.fill_to = Vector2(0.88, 1.0)

	var wallpaper := TextureRect.new()
	wallpaper.name = "GeneratedWallpaper"
	wallpaper.texture = texture
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_SCALE
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(wallpaper)
	add_child(wallpaper)


func _add_glow(glow: Dictionary, tint: Color) -> void:
	var panel := Panel.new()
	panel.name = "WallpaperAmbientShape"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(panel, glow["rect"])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, float(glow["alpha"]))
	style.set_corner_radius_all(260)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)


func _add_status_bar(palette: Dictionary) -> void:
	var status := Label.new()
	status.name = "LockScreenStatusBar"
	status.text = _current_time_text() + "                                      ◈  ●  ▰"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", palette["muted"])
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(status, Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035)))
	add_child(status)


func _add_clock(design: Dictionary, palette: Dictionary) -> void:
	var rect: Rect2 = design["clock_rect"]
	if str(design["clock_style"]) == "analog":
		_add_analog_clock(rect, palette)
		return

	var clock := Label.new()
	clock.name = "GeneratedLockScreenClock"
	var time_parts := _current_time_text().split(":")
	if str(design["clock_format"]) == "split":
		clock.text = time_parts[0] + "\n" + time_parts[1]
	elif str(design["clock_format"]) == "spaced":
		clock.text = time_parts[0] + "   " + time_parts[1]
	else:
		clock.text = _current_time_text()
	clock.horizontal_alignment = _alignment_from_name(str(design["clock_align"]))
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock.add_theme_font_size_override("font_size", int(design["clock_font_size"]))
	clock.add_theme_color_override("font_color", palette["text"])
	clock.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.30))
	clock.add_theme_constant_override("shadow_offset_x", 1)
	clock.add_theme_constant_override("shadow_offset_y", 3)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(clock, rect)
	add_child(clock)


func _add_analog_clock(rect: Rect2, palette: Dictionary) -> void:
	var dial := Panel.new()
	dial.name = "GeneratedAnalogClockDial"
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(dial, rect)
	var dial_style := StyleBoxFlat.new()
	dial_style.bg_color = Color(palette["glass"].r, palette["glass"].g, palette["glass"].b, 0.18)
	dial_style.border_color = Color(palette["accent"].r, palette["accent"].g, palette["accent"].b, 0.75)
	dial_style.set_border_width_all(3)
	dial_style.set_corner_radius_all(300)
	dial.add_theme_stylebox_override("panel", dial_style)
	add_child(dial)

	var time := Time.get_time_dict_from_system()
	var minute_angle := float(time["minute"]) * TAU / 60.0
	var hour_angle := (float(time["hour"] % 12) + float(time["minute"]) / 60.0) * TAU / 12.0
	var minute_hand := _add_analog_hand("AOSPAnalogMinuteHand", "analog_minute_hand.svg", rect, palette["text"], minute_angle)
	var hour_hand := _add_analog_hand("AOSPAnalogHourHand", "analog_hour_hand.svg", rect, palette["accent"], hour_angle)
	var center_dot := _add_analog_hand("AOSPAnalogCenter", "analog_frame.svg", rect, palette["text"], 0.0)
	minute_hand.z_index = 2
	hour_hand.z_index = 3
	center_dot.z_index = 4


func _add_analog_hand(node_name: String, file_name: String, rect: Rect2, tint: Color, angle: float) -> TextureRect:
	var hand := TextureRect.new()
	hand.name = node_name
	hand.texture = _load_tinted_asset(SVG_ROOT.path_join(file_name), tint)
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(hand, rect)
	hand.rotation = angle
	hand.resized.connect(func(): hand.pivot_offset = hand.size * 0.5)
	add_child(hand)
	hand.pivot_offset = hand.size * 0.5
	return hand


func _add_date(design: Dictionary, palette: Dictionary) -> void:
	var date := Label.new()
	date.name = "GeneratedLockScreenDate"
	date.text = _current_date_text()
	date.horizontal_alignment = _alignment_from_name(str(design["clock_align"]))
	date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date.add_theme_font_size_override("font_size", int(design["date_font_size"]))
	date.add_theme_color_override("font_color", palette["muted"])
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var date_component := _find_component_rect(design, "date")
	_set_normalized_rect(date, date_component)
	add_child(date)


func _add_notification(notification: Dictionary, rect: Rect2, palette: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "GeneratedNotification"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(palette["glass"].r, palette["glass"].g, palette["glass"].b, 0.82)
	style.border_color = Color(palette["muted"].r, palette["muted"].g, palette["muted"].b, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(22)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	_set_normalized_rect(card, rect)
	add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var app_label := Label.new()
	app_label.text = str(notification["app"]) + "  ·  NOW"
	app_label.add_theme_font_size_override("font_size", 14)
	app_label.add_theme_color_override("font_color", palette["accent"])
	app_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(app_label)

	var title := Label.new()
	title.text = str(notification["title"])
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", palette["text"])
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var body := Label.new()
	body.text = str(notification["body"])
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", palette["muted"])
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body)


func _add_fingerprint(design: Dictionary, palette: Dictionary) -> void:
	var rect := _find_component_rect(design, "fingerprint")
	var group := HBoxContainer.new()
	group.name = "GeneratedFingerprintPrompt"
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 12)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(group, rect)
	add_child(group)

	var icon := TextureRect.new()
	icon.texture = _load_tinted_asset(SVG_ROOT.path_join("ic_fingerprint.svg"), palette["accent"])
	icon.custom_minimum_size = Vector2(34, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(icon)

	var label := Label.new()
	label.text = "TOUCH TO UNLOCK"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", palette["muted"])
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(label)


func _add_shortcuts(design: Dictionary, palette: Dictionary) -> void:
	for shortcut in design["shortcuts"]:
		var kind := str(shortcut["kind"])
		var rect: Rect2 = shortcut["rect"]
		var button := PanelContainer.new()
		button.name = "Bottom" + kind.capitalize() + "Shortcut"
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(palette["glass"].r, palette["glass"].g, palette["glass"].b, 0.54)
		style.border_color = Color(palette["muted"].r, palette["muted"].g, palette["muted"].b, 0.32)
		style.set_border_width_all(1)
		style.set_corner_radius_all(90)
		button.add_theme_stylebox_override("panel", style)
		_set_normalized_rect(button, rect)
		add_child(button)

		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(center)
		if kind == "flashlight":
			var flashlight := TextureRect.new()
			flashlight.texture = _load_tinted_asset(SVG_ROOT.path_join("ic_flashlight_off.svg"), palette["text"])
			flashlight.custom_minimum_size = Vector2(30, 34)
			flashlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flashlight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flashlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(flashlight)
		else:
			var camera := Label.new()
			camera.text = "◉"
			camera.add_theme_font_size_override("font_size", 38)
			camera.add_theme_color_override("font_color", palette["text"])
			camera.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(camera)


func _notification_component_rect(design: Dictionary, notification_index: int) -> Rect2:
	var notification: Dictionary = design["notifications"][notification_index]
	return notification["rect"]


func _find_component_rect(design: Dictionary, role: String) -> Rect2:
	for component in design["components"]:
		if str(component["role"]) == role:
			return component["rect"]
	return Rect2()


func _load_tinted_asset(path: String, tint: Color) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0:
				image.set_pixel(x, y, Color(tint.r, tint.g, tint.b, pixel.a * tint.a))
	return ImageTexture.create_from_image(image)


func _current_time_text() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(time["hour"]), int(time["minute"])]


func _current_date_text() -> String:
	var date := Time.get_date_dict_from_system()
	var weekday := clampi(int(date["weekday"]), 1, 7)
	var month := clampi(int(date["month"]), 1, 12)
	return "%s, %02d %s" % [WEEKDAYS[weekday], int(date["day"]), MONTHS[month]]


func _alignment_from_name(value: String) -> HorizontalAlignment:
	match value:
		"left":
			return HORIZONTAL_ALIGNMENT_LEFT
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		_:
			return HORIZONTAL_ALIGNMENT_CENTER


func _set_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
