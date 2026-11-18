extends Control

signal pin_unlocked

const SVG_ROOT := "res://assets/lock-screen/aosp/SVG"
const WALLPAPER_ROOT := "res://assets/wallpapers"
const LayoutLibrary = preload("res://scripts/lock_screen_layout_library.gd")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")
const StatusBarAssetLibrary = preload("res://scripts/status_bar_asset_library.gd")
const NotificationCardScene = preload("res://scenes/system_ui/lock_screen_notification_card.tscn")
const MediaPlayerCardScene = preload("res://scenes/system_ui/lock_screen_media_player_card.tscn")
const LockScreenClockScene = preload("res://scenes/system_ui/lock_screen_clock.tscn")
const LockScreenStatusBarScene = preload("res://scenes/system_ui/lock_screen_status_bar.tscn")
const FingerprintPromptScene = preload("res://scenes/system_ui/lock_screen_fingerprint_prompt.tscn")
const LockScreenShortcutScene = preload("res://scenes/system_ui/lock_screen_shortcut.tscn")
const PIN_BACKSPACE_ICON_PATH := "res://assets/system-ui/godot/pin-entry/pin_backspace.svg"
const PIN_LENGTH := 6

const NOTIFICATION_PRESETS := [
	{"app": "WHATSAPP", "icon": "res://assets/app_icons/papirus/social/apps_whatsapp.svg", "title": "You have a new message", "body": "A new conversation is waiting for you."},
	{"app": "GMAIL", "icon": "res://assets/app_icons/papirus/google_essential/google_gmail.svg", "title": "A new email arrived", "body": "Your inbox has a fresh update."},
	{"app": "GOOGLE KEEP", "icon": "res://assets/app_icons/papirus/google_essential/google_keep.svg", "title": "Reminder", "body": "A saved note is ready for review."},
	{"app": "TODOIST", "icon": "res://assets/app_icons/papirus/productivity_education/apps_todoist.svg", "title": "Task due today", "body": "One item is still on your list."},
	{"app": "CLASSROOM", "icon": "res://assets/app_icons/papirus/productivity_education/google_classroom.svg", "title": "New class update", "body": "Your learning feed has changed."},
	{"app": "SECURITY", "icon": "res://assets/app_icons/papirus/google_essential/google_auth.svg", "title": "Security check complete", "body": "Your account protection is up to date."}
]

const MEDIA_PRESETS := [
	{"service": "SPOTIFY", "icon": "res://assets/app_icons/papirus/entertainment_music/apps_spotify_client.svg", "title": "Midnight City", "artist": "M83"},
	{"service": "YOUTUBE MUSIC", "icon": "res://assets/app_icons/papirus/google_essential/google_youtube_music.svg", "title": "Sunset Lover", "artist": "Petit Biscuit"},
	{"service": "DEEZER", "icon": "res://assets/app_icons/papirus/entertainment_music/apps_deezer.svg", "title": "The Less I Know the Better", "artist": "Tame Impala"},
	{"service": "SOUNDCLOUD", "icon": "res://assets/app_icons/papirus/entertainment_music/apps_soundcloud.svg", "title": "A Walk", "artist": "Tycho"},
	{"service": "SAMSUNG MUSIC", "icon": "res://assets/app_icons/papirus/entertainment_music/apps_samsung_music.svg", "title": "Night Drive", "artist": "Digital World Radio"}
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
var _selected_wallpaper_path := ""
var _show_notifications := false
var _show_media_player := false
var _show_fingerprint := false
var _show_flashlight_shortcut := false
var _show_camera_shortcut := false
var _wallpaper_bag: Array[String] = []
var _recent_wallpaper_paths: Array[String] = []
var _pin_entry_layer: Control
var _pin_dot_nodes: Array[Panel] = []
var _pin_title_label: Label
var _pin_subtitle_label: Label
var _pin_lock_icon: TextureRect
var _pin_digits := ""
var _pin_unlocked := false


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


func get_wallpaper_paths() -> Array[String]:
	return _wallpaper_paths.duplicate()


func get_selected_wallpaper_path() -> String:
	return _selected_wallpaper_path


func set_wallpaper(path: String) -> bool:
	if not _wallpaper_paths.has(path) or not FileAccess.file_exists(path):
		return false
	_selected_wallpaper_path = path
	if _last_design.is_empty():
		return true
	_last_design["wallpaper_path"] = path
	_last_design["wallpaper_index"] = _wallpaper_number(path)
	_last_design["signature"] = _make_signature(_last_design)
	_render_design(_last_design)
	return true


func get_display_option(option: String) -> bool:
	match option:
		"notifications":
			return _show_notifications
		"music_player":
			return _show_media_player
		"flashlight":
			return _show_flashlight_shortcut
		"camera":
			return _show_camera_shortcut
		"fingerprint":
			return _show_fingerprint
	return false


func set_display_option(option: String, enabled: bool) -> bool:
	if _last_design.is_empty():
		return false
	var design_key := ""
	match option:
		"notifications":
			_show_notifications = enabled
			design_key = "show_notifications"
		"music_player":
			_show_media_player = enabled
			design_key = "show_media_player"
		"flashlight":
			_show_flashlight_shortcut = enabled
			design_key = "show_flashlight_shortcut"
		"camera":
			_show_camera_shortcut = enabled
			design_key = "show_camera_shortcut"
		"fingerprint":
			_show_fingerprint = enabled
			design_key = "show_fingerprint"
		_:
			return false
	_last_design[design_key] = enabled
	_render_design(_last_design)
	return true


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
	if _selected_wallpaper_path.is_empty():
		_selected_wallpaper_path = _next_wallpaper_path()
	var wallpaper_path := _selected_wallpaper_path
	if wallpaper_path.is_empty():
		return {}

	var status_rect := Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035))
	_add_component(components, occupied, "status", status_rect)

	# The complete transparent artwork is square; vary its horizontal placement
	# with the date alignment instead of composing a face and rotating hands.
	var date_alignments: Array = blueprint["date_alignments"]
	var date_align := str(date_alignments[_rng.randi_range(0, date_alignments.size() - 1)])
	var clock_date_shift := Vector2(_rng.randf_range(-0.012, 0.012), _rng.randf_range(-0.008, 0.008))
	var clock_rect: Rect2 = blueprint["clock_rect"]
	var date_rect: Rect2 = blueprint["date_rect"]
	match date_align:
		"left":
			clock_rect.position.x = 0.075
		"right":
			clock_rect.position.x = 0.625
		_:
			clock_rect.position.x = 0.35
	clock_rect.position += clock_date_shift
	date_rect.position += clock_date_shift
	clock_rect.position.x = clampf(clock_rect.position.x, 0.055, 0.945 - clock_rect.size.x)
	date_rect.position.x = clampf(date_rect.position.x, 0.055, 0.945 - date_rect.size.x)
	_add_component(components, occupied, "clock", clock_rect)
	_add_component(components, occupied, "date", date_rect)

	var notifications: Array[Dictionary] = []
	var media: Dictionary = {}
	var content_shift := _rng.randf_range(-0.004, 0.004)
	for slot in blueprint["content_slots"]:
		var slot_rect: Rect2 = slot["rect"]
		slot_rect.position.y += content_shift
		slot_rect.position.x += _rng.randf_range(-0.003, 0.003)
		# Give notification and media surfaces a little more room without
		# changing their visual center or the surrounding lock-screen layout.
		var original_slot_height := slot_rect.size.y
		slot_rect.size.y *= 1.08
		slot_rect.position.y -= (slot_rect.size.y - original_slot_height) * 0.5
		slot_rect.size.x = clampf(slot_rect.size.x + _rng.randf_range(-0.012, 0.012), 0.78, 0.88)
		slot_rect.position.x = clampf(slot_rect.position.x, 0.055, 0.945 - slot_rect.size.x)
		if not _can_place(slot_rect, occupied):
			continue

		if str(slot["type"]) == "notification":
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

	var fingerprint_rect := Rect2(
		Vector2(_rng.randf_range(0.33, 0.39), _rng.randf_range(0.785, 0.795)),
		Vector2(_rng.randf_range(0.22, 0.31), 0.07)
	)
	# Fingerprint occupies its own safe zone, but remains disabled until selected.
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

	var status_styles: Array = StatusBarAssetLibrary.get_styles()
	var selected_status_style: Dictionary = status_styles[_rng.randi_range(0, status_styles.size() - 1)]
	var analog_clock_asset_index := _rng.randi_range(1, LockScreenAssetLibrary.get_analog_clock_count())

	var design := {
		"layout_id": str(blueprint["id"]),
		"layout_name": str(blueprint["name"]),
		"status_style_id": str(selected_status_style.get("id", "pixel_compact")),
		"analog_clock_asset_index": analog_clock_asset_index,
		"palette": palette,
		"wallpaper_path": wallpaper_path,
		"wallpaper_index": _wallpaper_number(wallpaper_path),
		"components": components,
		"clock_rect": clock_rect,
		"date_align": date_align,
		"date_font_size": _rng.randi_range(13, 18),
		"date_letter_spacing": _rng.randi_range(1, 3),
		"notifications": notifications,
		"media": media,
		"show_notifications": _show_notifications,
		"show_media_player": _show_media_player,
		"show_fingerprint": _show_fingerprint,
		"show_flashlight_shortcut": _show_flashlight_shortcut,
		"show_camera_shortcut": _show_camera_shortcut,
		"shortcuts": [
			{"kind": "flashlight", "rect": flashlight_rect},
			{"kind": "camera", "rect": camera_rect}
		],
		"glows": glows
	}
	design["signature"] = _make_signature(design)
	return design


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
		str(design.get("date_align", "")),
		str(design.get("status_style_id", "")),
		str(design.get("analog_clock_asset_index", 0)),
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
	hide_pin_entry()
	for child in get_children():
		remove_child(child)
		child.free()

	var palette: Dictionary = design["palette"]
	_add_wallpaper(design)
	for glow in design["glows"]:
		_add_glow(glow, palette["glow"])
	_add_status_bar(design, palette)
	_add_clock(design, palette)
	if bool(design.get("show_notifications", false)):
		for index in range(design["notifications"].size()):
			_add_notification(design["notifications"][index], palette)
	if bool(design.get("show_media_player", false)) and not design["media"].is_empty():
		_add_media_player(design["media"], palette)
	if bool(design.get("show_fingerprint", false)):
		_add_fingerprint(design, palette)
	_add_shortcuts(design, palette)


func show_pin_entry() -> bool:
	if _last_design.is_empty():
		return false
	if is_pin_entry_visible():
		return true
	_pin_digits = ""
	_pin_unlocked = false
	_build_pin_entry_screen()
	return is_pin_entry_visible()


func hide_pin_entry() -> void:
	if is_instance_valid(_pin_entry_layer):
		_pin_entry_layer.visible = false
		if _pin_entry_layer.get_parent() == self:
			remove_child(_pin_entry_layer)
		_pin_entry_layer.free()
	_pin_entry_layer = null
	_pin_dot_nodes.clear()
	_pin_title_label = null
	_pin_subtitle_label = null
	_pin_lock_icon = null
	_pin_digits = ""
	_pin_unlocked = false


func is_pin_entry_visible() -> bool:
	return is_instance_valid(_pin_entry_layer) and _pin_entry_layer.visible


func get_pin_digit_count() -> int:
	return _pin_digits.length()


func is_pin_unlocked() -> bool:
	return _pin_unlocked


func press_pin_digit(digit: int) -> void:
	if not is_pin_entry_visible() or _pin_unlocked:
		return
	if digit < 0 or digit > 9 or _pin_digits.length() >= PIN_LENGTH:
		return
	_pin_digits += str(digit)
	_refresh_pin_entry()
	if _pin_digits.length() >= PIN_LENGTH:
		_complete_pin_preview()


func erase_pin_digit() -> void:
	if not is_pin_entry_visible() or _pin_digits.is_empty():
		return
	if _pin_unlocked:
		_pin_unlocked = false
		if is_instance_valid(_pin_title_label):
			_pin_title_label.text = "ENTER PIN"
		if is_instance_valid(_pin_subtitle_label):
			_pin_subtitle_label.text = "Enter your 6-digit PIN to unlock"
		if is_instance_valid(_pin_lock_icon):
			var palette: Dictionary = _last_design.get("palette", {})
			_pin_lock_icon.texture = _load_tinted_asset(
				SVG_ROOT.path_join("ic_lock_locked.svg"),
				palette.get("accent", Color.WHITE)
			)
	_pin_digits = _pin_digits.left(_pin_digits.length() - 1)
	_refresh_pin_entry()


func _complete_pin_preview() -> void:
	if not is_pin_entry_visible():
		return
	_pin_unlocked = true
	if is_instance_valid(_pin_title_label):
		_pin_title_label.text = "DEVICE UNLOCKED"
	if is_instance_valid(_pin_subtitle_label):
		_pin_subtitle_label.text = "PIN PREVIEW COMPLETE"
	if is_instance_valid(_pin_lock_icon):
		_pin_lock_icon.texture = _load_tinted_asset(
			SVG_ROOT.path_join("ic_unlocked.svg"),
			Color("#9BE2B5")
		)
	_refresh_pin_entry()
	pin_unlocked.emit()


func _build_pin_entry_screen() -> void:
	var palette: Dictionary = _last_design.get("palette", {})
	var text_color: Color = palette.get("text", Color("#F4F6FA"))
	var muted_color: Color = palette.get("muted", Color("#B8C2D1"))
	var accent_color: Color = palette.get("accent", Color("#A9C9FF"))
	var glass_color: Color = palette.get("glass", Color("#17243B"))

	_pin_entry_layer = Control.new()
	_pin_entry_layer.name = "PinEntryOverlay"
	_pin_entry_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_pin_entry_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pin_entry_layer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_pin_entry_layer)

	var shade := ColorRect.new()
	shade.name = "PinEntryWallpaperShade"
	shade.color = Color(0.008, 0.014, 0.025, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(shade)
	_pin_entry_layer.add_child(shade)

	_pin_lock_icon = TextureRect.new()
	_pin_lock_icon.name = "PinLockStateIcon"
	_pin_lock_icon.texture = _load_tinted_asset(SVG_ROOT.path_join("ic_lock_locked.svg"), accent_color)
	_pin_lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pin_lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pin_lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(_pin_lock_icon, Rect2(Vector2(0.455, 0.135), Vector2(0.09, 0.052)))
	_pin_entry_layer.add_child(_pin_lock_icon)

	_pin_title_label = _make_pin_text_label("ENTER PIN", 24, text_color)
	_pin_title_label.name = "PinEntryTitle"
	_set_normalized_rect(_pin_title_label, Rect2(Vector2(0.12, 0.218), Vector2(0.76, 0.045)))
	_pin_entry_layer.add_child(_pin_title_label)

	_pin_subtitle_label = _make_pin_text_label("Enter your 6-digit PIN to unlock", 12, muted_color)
	_pin_subtitle_label.name = "PinEntrySubtitle"
	_set_normalized_rect(_pin_subtitle_label, Rect2(Vector2(0.12, 0.268), Vector2(0.76, 0.035)))
	_pin_entry_layer.add_child(_pin_subtitle_label)

	var dots_row := HBoxContainer.new()
	dots_row.name = "PinEntryDots"
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 24)
	dots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(dots_row, Rect2(Vector2(0.18, 0.335), Vector2(0.64, 0.035)))
	_pin_entry_layer.add_child(dots_row)

	_pin_dot_nodes.clear()
	for index in range(PIN_LENGTH):
		var dot := Panel.new()
		dot.name = "PinDigitIndicator_%02d" % (index + 1)
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots_row.add_child(dot)
		_pin_dot_nodes.append(dot)

	var keypad_center := CenterContainer.new()
	keypad_center.name = "PinKeypadCenter"
	keypad_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_normalized_rect(keypad_center, Rect2(Vector2(0.12, 0.405), Vector2(0.76, 0.405)))
	_pin_entry_layer.add_child(keypad_center)

	var keypad := GridContainer.new()
	keypad.name = "PinNumericKeypad"
	keypad.columns = 3
	keypad.add_theme_constant_override("h_separation", 18)
	keypad.add_theme_constant_override("v_separation", 12)
	keypad.mouse_filter = Control.MOUSE_FILTER_PASS
	keypad_center.add_child(keypad)

	for digit in range(1, 10):
		keypad.add_child(_make_pin_digit_button(digit, text_color, glass_color))

	var empty_slot := Control.new()
	empty_slot.name = "PinKeypadEmptySlot"
	empty_slot.custom_minimum_size = Vector2(104, 88)
	empty_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keypad.add_child(empty_slot)
	keypad.add_child(_make_pin_digit_button(0, text_color, glass_color))
	keypad.add_child(_make_pin_backspace_button(muted_color, glass_color))

	if bool(_last_design.get("show_fingerprint", false)):
		var fingerprint_prompt: Control = FingerprintPromptScene.instantiate() as Control
		fingerprint_prompt.name = "PinFingerprintOption"
		_set_normalized_rect(fingerprint_prompt, Rect2(Vector2(0.22, 0.835), Vector2(0.56, 0.055)))
		_pin_entry_layer.add_child(fingerprint_prompt)
		fingerprint_prompt.call("configure", _last_design.get("palette", {}), "USE FINGERPRINT", Vector2(19, 27), true)
		fingerprint_prompt.activated.connect(_complete_pin_preview)

	var return_hint := _make_pin_text_label("SWIPE DOWN TO RETURN", 9, Color(muted_color.r, muted_color.g, muted_color.b, 0.82))
	return_hint.name = "PinEntryReturnHint"
	_set_normalized_rect(return_hint, Rect2(Vector2(0.18, 0.935), Vector2(0.64, 0.027)))
	_pin_entry_layer.add_child(return_hint)

	_refresh_pin_entry()
	var fade := create_tween()
	fade.tween_property(_pin_entry_layer, "modulate", Color.WHITE, 0.18)


func _make_pin_digit_button(digit: int, text_color: Color, glass_color: Color) -> Button:
	var button := Button.new()
	button.name = "PinDigit%d" % digit
	button.text = str(digit)
	button.custom_minimum_size = Vector2(104, 88)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 29)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_stylebox_override("normal", _make_pin_key_style(Color(glass_color.r, glass_color.g, glass_color.b, 0.28), Color(1.0, 1.0, 1.0, 0.13)))
	button.add_theme_stylebox_override("hover", _make_pin_key_style(Color(glass_color.r, glass_color.g, glass_color.b, 0.48), Color(1.0, 1.0, 1.0, 0.30)))
	button.add_theme_stylebox_override("pressed", _make_pin_key_style(Color(glass_color.r, glass_color.g, glass_color.b, 0.62), Color(1.0, 1.0, 1.0, 0.38)))
	button.pressed.connect(press_pin_digit.bind(digit))
	return button


func _make_pin_backspace_button(muted_color: Color, glass_color: Color) -> Button:
	var button := Button.new()
	button.name = "PinBackspace"
	button.custom_minimum_size = Vector2(104, 88)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_stylebox_override("normal", _make_pin_key_style(Color(glass_color.r, glass_color.g, glass_color.b, 0.18), Color(1.0, 1.0, 1.0, 0.12)))
	button.add_theme_stylebox_override("hover", _make_pin_key_style(Color(glass_color.r, glass_color.g, glass_color.b, 0.38), Color(1.0, 1.0, 1.0, 0.28)))
	button.add_theme_stylebox_override("pressed", _make_pin_key_style(Color(glass_color.r, glass_color.g, glass_color.b, 0.52), Color(1.0, 1.0, 1.0, 0.34)))
	button.pressed.connect(erase_pin_digit)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(center)
	button.add_child(center)

	var icon := TextureRect.new()
	icon.name = "PinBackspaceIcon"
	icon.texture = _load_tinted_asset(PIN_BACKSPACE_ICON_PATH, muted_color)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	return button


func _make_pin_key_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(46)
	return style


func _make_pin_text_label(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_pin_entry() -> void:
	if not is_instance_valid(_pin_entry_layer):
		return
	var palette: Dictionary = _last_design.get("palette", {})
	var text_color: Color = palette.get("text", Color.WHITE)
	var accent_color: Color = Color("#9BE2B5") if _pin_unlocked else palette.get("accent", Color("#A9C9FF"))
	for index in range(_pin_dot_nodes.size()):
		var filled := _pin_unlocked or index < _pin_digits.length()
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = accent_color if filled else Color(1.0, 1.0, 1.0, 0.035)
		dot_style.border_color = accent_color if filled else Color(text_color.r, text_color.g, text_color.b, 0.66)
		dot_style.set_border_width_all(1)
		dot_style.set_corner_radius_all(7)
		_pin_dot_nodes[index].add_theme_stylebox_override("panel", dot_style)


func _add_wallpaper(design: Dictionary) -> void:
	var wallpaper := TextureRect.new()
	wallpaper.name = "GeneratedWallpaper"
	var wallpaper_path := str(design.get("wallpaper_path", ""))
	var wallpaper_texture: Texture2D = null
	if not wallpaper_path.is_empty():
		wallpaper_texture = ResourceLoader.load(wallpaper_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
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
	shade.color = Color(0.008, 0.012, 0.02, 0.58)
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


func _add_status_bar(design: Dictionary, palette: Dictionary) -> void:
	var status_bar: Control = LockScreenStatusBarScene.instantiate() as Control
	status_bar.name = "LockScreenStatusBar"
	add_child(status_bar)
	status_bar.call("configure", design, palette)

func get_status_bar_style_id() -> String:
	return str(_last_design.get("status_style_id", "pixel_compact"))

func set_status_bar_style(style_id: String) -> bool:
	if not StatusBarAssetLibrary.has_style(style_id) or _last_design.is_empty():
		return false
	_last_design["status_style_id"] = style_id
	_render_design(_last_design)
	return true

func _add_clock(design: Dictionary, palette: Dictionary) -> void:
	var clock: Control = LockScreenClockScene.instantiate() as Control
	clock.name = "GeneratedLockScreenClockComponent"
	add_child(clock)
	clock.call("configure", design, palette)

func _add_notification(notification_data: Dictionary, palette: Dictionary) -> void:
	var card: Control = NotificationCardScene.instantiate() as Control
	card.name = "GeneratedNotification"
	_set_normalized_rect(card, notification_data["rect"])
	add_child(card)
	card.call("configure", notification_data, palette)


func _add_media_player(media: Dictionary, palette: Dictionary) -> void:
	var card: Control = MediaPlayerCardScene.instantiate() as Control
	card.name = "GeneratedLockScreenMediaPlayer"
	_set_normalized_rect(card, media["rect"])
	add_child(card)
	card.call("configure", media, palette)

func _add_shortcuts(design: Dictionary, palette: Dictionary) -> void:
	for shortcut in design["shortcuts"]:
		var kind := str(shortcut["kind"])
		if kind == "flashlight" and not bool(design.get("show_flashlight_shortcut", false)):
			continue
		if kind == "camera" and not bool(design.get("show_camera_shortcut", false)):
			continue
		var button: Control = LockScreenShortcutScene.instantiate() as Control
		button.name = "Bottom" + kind.capitalize() + "Shortcut"
		_set_normalized_rect(button, shortcut["rect"])
		add_child(button)
		button.call("configure", kind, palette)


func _add_fingerprint(design: Dictionary, palette: Dictionary) -> void:
	var fingerprint: Control = FingerprintPromptScene.instantiate() as Control
	fingerprint.name = "GeneratedLockScreenFingerprint"
	_set_normalized_rect(fingerprint, _find_component_rect(design, "fingerprint"))
	add_child(fingerprint)
	fingerprint.call("configure", palette, "TOUCH SENSOR TO UNLOCK", Vector2(25, 32), false)

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
	var selected: String = _wallpaper_bag.pop_back()
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