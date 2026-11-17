extends Control

const SVG_ROOT := "res://assets/lock-screen/aosp/SVG"
const WALLPAPER_ROOT := "res://assets/wallpapers"
const LayoutLibrary = preload("res://scripts/lock_screen_layout_library.gd")

const NOTIFICATION_PRESETS := [
	{"app": "MESSAGES", "icon": "res://assets/app_icons/appstract/google/google_chat.png", "title": "You have a new message", "body": "A new conversation is waiting for you."},
	{"app": "GMAIL", "icon": "res://assets/app_icons/appstract/google/gmail.png", "title": "A new email arrived", "body": "Your inbox has a fresh update."},
	{"app": "GOOGLE KEEP", "icon": "res://assets/app_icons/appstract/google/google_keep.png", "title": "Reminder", "body": "A saved note is ready for review."},
	{"app": "GOOGLE TASKS", "icon": "res://assets/app_icons/appstract/google/google_tasks.png", "title": "Task due today", "body": "One item is still on your list."},
	{"app": "CLASSROOM", "icon": "res://assets/app_icons/appstract/google/google_classroom.png", "title": "New class update", "body": "Your learning feed has changed."},
	{"app": "SECURITY", "icon": "res://assets/app_icons/appstract/google/google_authenticator.png", "title": "Security check complete", "body": "Your account protection is up to date."}
]

const MEDIA_PRESETS := [
	{"service": "SPOTIFY", "icon": "res://assets/app_icons/appstract/music/spotify.png", "title": "Midnight City", "artist": "M83"},
	{"service": "APPLE MUSIC", "icon": "res://assets/app_icons/appstract/music/apple_music.png", "title": "Sunset Lover", "artist": "Petit Biscuit"},
	{"service": "AMAZON MUSIC", "icon": "res://assets/app_icons/appstract/music/amazon_music.png", "title": "The Less I Know the Better", "artist": "Tame Impala"},
	{"service": "SOUNDCLOUD", "icon": "res://assets/app_icons/appstract/music/soundcloud.png", "title": "A Walk", "artist": "Tycho"},
	{"service": "POWERAMP", "icon": "res://assets/app_icons/appstract/music/poweramp.png", "title": "Night Drive", "artist": "Digital World Radio"}
]

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

const WEEKDAYS := ["", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
const MONTHS := ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

var _rng := RandomNumberGenerator.new()
var _recent_signatures: Array[String] = []
var _last_design: Dictionary = {}
var _generation_count := 0
var _layout_queue: Array = []
var _wallpaper_paths: Array[String] = []
var _wallpaper_bag: Array[String] = []
var _recent_wallpaper_paths: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()
	_wallpaper_paths = _discover_wallpapers()

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


func get_available_wallpaper_count() -> int:
	return _wallpaper_paths.size()


func get_blueprint_count() -> int:
	return LayoutLibrary.get_blueprints().size()


func validate_layout(design: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var components: Array = design.get("components", [])
	if components.size() < 5:
		issues.append("The composition is missing required lock-screen components.")
		return issues

	if str(design.get("layout_id", "")).is_empty():
		issues.append("The composition has no curated layout foundation.")
	var wallpaper_path := str(design.get("wallpaper_path", ""))
	if wallpaper_path.is_empty() or not FileAccess.file_exists(wallpaper_path):
		issues.append("The composition does not reference a bundled lock-screen wallpaper.")

	var occupied: Array[Rect2] = []
	var notification_components := 0
	var media_components := 0
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
		if role == "notification":
			notification_components += 1
		if role == "media":
			media_components += 1
		for existing in occupied:
			if rect.grow(0.006).intersects(existing.grow(0.006)):
				issues.append("%s collides with another independent component." % role)
				break
		occupied.append(rect)

	if notification_components != design.get("notifications", []).size():
		issues.append("Notification metadata and placed notification components do not match.")
	if media_components > 1 or (media_components == 1) != (not design.get("media", {}).is_empty()):
		issues.append("The media-player metadata and placed media component do not match.")

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
	var blueprint := _next_layout_blueprint()
	if blueprint.is_empty():
		return {}

	var palette: Dictionary = PALETTES[_rng.randi_range(0, PALETTES.size() - 1)]
	var components: Array[Dictionary] = []
	var occupied: Array[Rect2] = []
	var wallpaper_path := _next_wallpaper_path()
	if wallpaper_path.is_empty():
		return {}

	var status_rect := Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035))
	_add_component(components, occupied, "status", status_rect)

	# A shared shift keeps the clock/date relationship designed while allowing
	# the autonomous engine to move the whole visual group between generations.
	var clock_date_shift := Vector2(_rng.randf_range(-0.012, 0.012), _rng.randf_range(-0.008, 0.008))
	var clock_rect: Rect2 = blueprint["clock_rect"]
	var date_rect: Rect2 = blueprint["date_rect"]
	clock_rect.position += clock_date_shift
	date_rect.position += clock_date_shift
	clock_rect.position.x = clampf(clock_rect.position.x, 0.055, 0.945 - clock_rect.size.x)
	date_rect.position.x = clampf(date_rect.position.x, 0.055, 0.945 - date_rect.size.x)
	_add_component(components, occupied, "clock", clock_rect)
	_add_component(components, occupied, "date", date_rect)

	var clock_styles: Array = blueprint["clock_styles"]
	var clock_style := str(clock_styles[_rng.randi_range(0, clock_styles.size() - 1)])
	var alignments: Array = blueprint["alignments"]
	var clock_align := str(alignments[_rng.randi_range(0, alignments.size() - 1)])
	var clock_formats: Array = blueprint["clock_formats"]
	var clock_format := str(clock_formats[_rng.randi_range(0, clock_formats.size() - 1)])
	if clock_style == "analog":
		clock_format = "single"

	var notifications: Array[Dictionary] = []
	var media: Dictionary = {}
	var content_shift := _rng.randf_range(-0.004, 0.004)
	for slot in blueprint["content_slots"]:
		var slot_rect: Rect2 = slot["rect"]
		slot_rect.position.y += content_shift
		slot_rect.position.x += _rng.randf_range(-0.003, 0.003)
		slot_rect.size.x = clampf(slot_rect.size.x + _rng.randf_range(-0.012, 0.012), 0.78, 0.88)
		slot_rect.position.x = clampf(slot_rect.position.x, 0.055, 0.945 - slot_rect.size.x)
		if not _can_place(slot_rect, occupied):
			continue

		if str(slot["type"]) == "notification":
			if _rng.randf() < 0.12:
				continue
			var notification_data: Dictionary = NOTIFICATION_PRESETS[_rng.randi_range(0, NOTIFICATION_PRESETS.size() - 1)].duplicate(true)
			notification_data["rect"] = slot_rect
			notification_data["timestamp"] = ["NOW", "1 MIN AGO", "2 MIN AGO", "5 MIN AGO"][_rng.randi_range(0, 3)]
			notifications.append(notification_data)
			_add_component(components, occupied, "notification", slot_rect)
		elif str(slot["type"]) == "media" and media.is_empty():
			media = MEDIA_PRESETS[_rng.randi_range(0, MEDIA_PRESETS.size() - 1)].duplicate(true)
			media["rect"] = slot_rect
			media["progress"] = _rng.randi_range(28, 84)
			media["playing"] = _rng.randf() > 0.18
			_add_component(components, occupied, "media", slot_rect)

	var show_fingerprint := bool(blueprint.get("fingerprint", false)) and _rng.randf() > 0.18
	if show_fingerprint:
		var fingerprint_rect := Rect2(
			Vector2(_rng.randf_range(0.33, 0.39), _rng.randf_range(0.792, 0.812)),
			Vector2(_rng.randf_range(0.22, 0.31), 0.045)
		)
		# Fingerprint prompts occupy their own lower safe zone, below all content slots.
		_add_component(components, occupied, "fingerprint", fingerprint_rect)

	var shortcut_y := _rng.randf_range(0.90, 0.91)
	var shortcut_size := Vector2(_rng.randf_range(0.12, 0.135), _rng.randf_range(0.060, 0.068))
	var flashlight_rect := Rect2(Vector2(_rng.randf_range(0.115, 0.14), shortcut_y), shortcut_size)
	var camera_rect := Rect2(Vector2(_rng.randf_range(0.75, 0.785), shortcut_y), shortcut_size)
	_add_component(components, occupied, "bottom_shortcut", flashlight_rect)
	_add_component(components, occupied, "bottom_shortcut", camera_rect)

	var glow_count := _rng.randi_range(1, 2)
	var glows: Array[Dictionary] = []
	for _glow_index in range(glow_count):
		glows.append({
			"rect": Rect2(
				Vector2(_rng.randf_range(-0.10, 0.68), _rng.randf_range(0.08, 0.68)),
				Vector2(_rng.randf_range(0.30, 0.58), _rng.randf_range(0.14, 0.26))
			),
			"alpha": _rng.randf_range(0.025, 0.065)
		})

	var design := {
		"layout_id": str(blueprint["id"]),
		"layout_name": str(blueprint["name"]),
		"palette": palette,
		"wallpaper_path": wallpaper_path,
		"wallpaper_index": _wallpaper_number(wallpaper_path),
		"components": components,
		"clock_rect": clock_rect,
		"clock_style": clock_style,
		"clock_format": clock_format,
		"clock_align": clock_align,
		"clock_font_size": _rng.randi_range(88, 116) if clock_style == "digital" else (_rng.randi_range(76, 96) if clock_style == "stacked" else 0),
		"date_font_size": _rng.randi_range(13, 18),
		"date_letter_spacing": _rng.randi_range(1, 3),
		"notifications": notifications,
		"media": media,
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
		if rect.grow(0.004).intersects(existing.grow(0.004)):
			return false
	return true


func _make_signature(design: Dictionary) -> String:
	var parts: Array[String] = [
		str(design.get("layout_id", "")),
		str(design.get("wallpaper_path", "").get_file()),
		str(design.get("clock_style", "")),
		str(design.get("clock_format", "")),
		str(design.get("clock_align", "")),
		str(design.get("palette", {}).get("name", "")),
		str(design.get("notifications", []).size()),
		"media" if not design.get("media", {}).is_empty() else "no-media"
	]
	for component in design.get("components", []):
		var rect: Rect2 = component.get("rect", Rect2())
		parts.append("%s:%d:%d:%d:%d" % [
			str(component.get("role", "")),
			roundi(rect.position.x * 1000.0),
			roundi(rect.position.y * 1000.0),
			roundi(rect.size.x * 1000.0),
			roundi(rect.size.y * 1000.0)
		])
	return "|".join(parts)

func _render_design(design: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var palette: Dictionary = design["palette"]
	_add_wallpaper(design)
	for glow in design["glows"]:
		_add_glow(glow, palette["glow"])
	_add_status_bar(palette)
	_add_clock(design, palette)
	_add_date(design, palette)
	for index in range(design["notifications"].size()):
		_add_notification(design["notifications"][index], palette)
	if not design["media"].is_empty():
		_add_media_player(design["media"], palette)
	if bool(design["show_fingerprint"]):
		_add_fingerprint(design, palette)
	_add_shortcuts(design, palette)

func _add_wallpaper(design: Dictionary) -> void:
	var wallpaper := TextureRect.new()
	wallpaper.name = "GeneratedWallpaper"
	var wallpaper_path := str(design.get("wallpaper_path", ""))
	var wallpaper_texture: Texture2D = null
	if not wallpaper_path.is_empty():
		wallpaper_texture = load(wallpaper_path) as Texture2D
	if wallpaper_texture != null:
		wallpaper.texture = wallpaper_texture
	else:
		var palette: Dictionary = design["palette"]
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([palette["top"], palette["bottom"]])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		var fallback_texture := GradientTexture2D.new()
		fallback_texture.gradient = gradient
		fallback_texture.width = 256
		fallback_texture.height = 512
		fallback_texture.fill_from = Vector2(0.12, 0.0)
		fallback_texture.fill_to = Vector2(0.88, 1.0)
		wallpaper.texture = fallback_texture
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(wallpaper)
	add_child(wallpaper)

	var shade := ColorRect.new()
	shade.name = "LockScreenWallpaperLegibilityShade"
	shade.color = Color(0.015, 0.02, 0.03, 0.30)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(shade)
	add_child(shade)

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
	var row := HBoxContainer.new()
	row.name = "LockScreenStatusBar"
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(row, Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035)))
	add_child(row)

	var lock_icon := TextureRect.new()
	lock_icon.texture = _load_tinted_asset(SVG_ROOT.path_join("ic_lock_locked.svg"), palette["muted"])
	lock_icon.custom_minimum_size = Vector2(12, 15)
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lock_icon)

	var time_label := Label.new()
	time_label.text = _current_time_text()
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", palette["muted"])
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(time_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var system_icons := Label.new()
	system_icons.text = "⌁  ◈  ▰"
	system_icons.add_theme_font_size_override("font_size", 13)
	system_icons.add_theme_color_override("font_color", palette["muted"])
	system_icons.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	system_icons.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	system_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(system_icons)

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


func _add_notification(notification_data: Dictionary, palette: Dictionary) -> void:
	var rect: Rect2 = notification_data["rect"]
	var card := PanelContainer.new()
	card.name = "GeneratedNotification"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(palette["glass"].r, palette["glass"].g, palette["glass"].b, 0.82)
	style.border_color = Color(palette["muted"].r, palette["muted"].g, palette["muted"].b, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(17)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", style)
	_set_normalized_rect(card, rect)
	add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var app_icon := TextureRect.new()
	var icon_path := str(notification_data.get("icon", ""))
	if not icon_path.is_empty():
		app_icon.texture = load(icon_path) as Texture2D
	app_icon.custom_minimum_size = Vector2(25, 25)
	app_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	app_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(app_icon)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)

	var app_label := Label.new()
	app_label.text = str(notification_data["app"]) + "  ·  " + str(notification_data.get("timestamp", "NOW"))
	app_label.add_theme_font_size_override("font_size", 9)
	app_label.add_theme_color_override("font_color", palette["accent"])
	app_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(app_label)

	var title := Label.new()
	title.text = str(notification_data["title"])
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", palette["text"])
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var body := Label.new()
	body.text = str(notification_data["body"])
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", palette["muted"])
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
		style.bg_color = Color(palette["glass"].r, palette["glass"].g, palette["glass"].b, 0.58)
		style.border_color = Color(palette["muted"].r, palette["muted"].g, palette["muted"].b, 0.36)
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
			flashlight.custom_minimum_size = Vector2(27, 32)
			flashlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flashlight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flashlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(flashlight)
		else:
			_add_camera_symbol(center, palette)


func _add_camera_symbol(parent: Control, palette: Dictionary) -> void:
	var camera := Control.new()
	camera.name = "GeneratedCameraGlyph"
	camera.custom_minimum_size = Vector2(34, 30)
	camera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(camera)

	var body := Panel.new()
	body.position = Vector2(1, 5)
	body.size = Vector2(32, 22)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0.0, 0.0, 0.0, 0.04)
	body_style.border_color = palette["text"]
	body_style.set_border_width_all(2)
	body_style.set_corner_radius_all(5)
	body.add_theme_stylebox_override("panel", body_style)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera.add_child(body)

	var bump := Panel.new()
	bump.position = Vector2(8, 1)
	bump.size = Vector2(11, 6)
	var bump_style := StyleBoxFlat.new()
	bump_style.bg_color = palette["text"]
	bump_style.set_corner_radius_all(2)
	bump.add_theme_stylebox_override("panel", bump_style)
	bump.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera.add_child(bump)

	var lens := Panel.new()
	lens.position = Vector2(11, 10)
	lens.size = Vector2(12, 12)
	var lens_style := StyleBoxFlat.new()
	lens_style.bg_color = palette["accent"]
	lens_style.set_corner_radius_all(8)
	lens.add_theme_stylebox_override("panel", lens_style)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(lens)

func _add_media_player(media: Dictionary, palette: Dictionary) -> void:
	var rect: Rect2 = media["rect"]
	var card := PanelContainer.new()
	card.name = "GeneratedLockScreenMediaPlayer"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(palette["glass"].r, palette["glass"].g, palette["glass"].b, 0.86)
	style.border_color = Color(palette["muted"].r, palette["muted"].g, palette["muted"].b, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(19)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)
	_set_normalized_rect(card, rect)
	add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(top_row)

	var service_icon := TextureRect.new()
	var icon_path := str(media.get("icon", ""))
	if not icon_path.is_empty():
		service_icon.texture = load(icon_path) as Texture2D
	service_icon.custom_minimum_size = Vector2(43, 43)
	service_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	service_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	service_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(service_icon)

	var track_info := VBoxContainer.new()
	track_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_info.add_theme_constant_override("separation", 0)
	track_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(track_info)

	var service_label := Label.new()
	service_label.text = str(media.get("service", "MUSIC")) + "  ·  NOW PLAYING"
	service_label.add_theme_font_size_override("font_size", 8)
	service_label.add_theme_color_override("font_color", palette["accent"])
	service_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_info.add_child(service_label)

	var title := Label.new()
	title.text = str(media.get("title", "Now Playing"))
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", palette["text"])
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_info.add_child(title)

	var artist := Label.new()
	artist.text = str(media.get("artist", "Digital World Radio"))
	artist.add_theme_font_size_override("font_size", 10)
	artist.add_theme_color_override("font_color", palette["muted"])
	artist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_info.add_child(artist)

	var play_state := Label.new()
	play_state.text = "Ⅱ" if bool(media.get("playing", true)) else "▶"
	play_state.add_theme_font_size_override("font_size", 19)
	play_state.add_theme_color_override("font_color", palette["text"])
	play_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	play_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(play_state)

	var progress := ProgressBar.new()
	progress.name = "MediaPlaybackProgress"
	progress.min_value = 0
	progress.max_value = 100
	progress.value = float(media.get("progress", 55))
	progress.show_percentage = false
	progress.custom_minimum_size.y = 3
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = palette["accent"]
	progress_fill.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", progress_fill)
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color(palette["muted"].r, palette["muted"].g, palette["muted"].b, 0.20)
	progress_track.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", progress_track)
	content.add_child(progress)

	var controls := Label.new()
	controls.text = "‹          " + ("Ⅱ" if bool(media.get("playing", true)) else "▶") + "          ›"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", palette["text"])
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(controls)

func _notification_component_rect(design: Dictionary, notification_index: int) -> Rect2:
	var notification_data: Dictionary = design["notifications"][notification_index]
	return notification_data["rect"]


func _find_component_rect(design: Dictionary, role: String) -> Rect2:
	for component in design["components"]:
		if str(component["role"]) == role:
			return component["rect"]
	return Rect2()


func _discover_wallpapers() -> Array[String]:
	var discovered: Array[String] = []
	var directory := DirAccess.open(WALLPAPER_ROOT)
	if directory == null:
		return discovered
	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()
		if extension in ["jpg", "jpeg", "png", "webp"]:
			discovered.append(WALLPAPER_ROOT.path_join(file_name))
	discovered.sort()
	return discovered


func _next_wallpaper_path() -> String:
	if _wallpaper_bag.is_empty():
		_wallpaper_bag = _wallpaper_paths.duplicate()
		_wallpaper_bag.shuffle()
		if _wallpaper_bag.size() > 1 and not _recent_wallpaper_paths.is_empty() and _wallpaper_bag.back() == _recent_wallpaper_paths.back():
			var swap_index := _rng.randi_range(0, _wallpaper_bag.size() - 2)
			var swap_value := _wallpaper_bag[swap_index]
			_wallpaper_bag[swap_index] = _wallpaper_bag.back()
			_wallpaper_bag[_wallpaper_bag.size() - 1] = swap_value
	if _wallpaper_bag.is_empty():
		return ""
	var selected := _wallpaper_bag.pop_back()
	_recent_wallpaper_paths.append(selected)
	if _recent_wallpaper_paths.size() > 12:
		_recent_wallpaper_paths.pop_front()
	return selected


func _next_layout_blueprint() -> Dictionary:
	if _layout_queue.is_empty():
		_layout_queue = LayoutLibrary.get_blueprints()
		_layout_queue.shuffle()
	if _layout_queue.is_empty():
		return {}
	return _layout_queue.pop_back()


func _wallpaper_number(path: String) -> int:
	var digits := path.get_file().get_basename().trim_prefix("wallpaper-")
	return int(digits)

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
