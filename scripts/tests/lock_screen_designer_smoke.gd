extends SceneTree

const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")
const LayoutLibrary = preload("res://scripts/lock_screen_layout_library.gd")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")
const StatusBarAssetLibrary = preload("res://scripts/status_bar_asset_library.gd")

const GENERATION_COUNT := 60


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for status_style_definition in StatusBarAssetLibrary.get_styles():
		if not StatusBarAssetLibrary.has_style(str(status_style_definition.get("id", ""))):
			_fail("A status-bar style is missing from the style library.")
			return
		for icon_type in status_style_definition.get("order", []):
			var icon_id := "bluetooth_connected" if str(icon_type) == "bluetooth" else "%s_%d" % [str(icon_type), int(status_style_definition.get(str(icon_type) + "_level", 4))]
			if StatusBarAssetLibrary.get_icon_texture(icon_id) == null:
				_fail("A status-bar preset references a missing Android vector asset: " + icon_id)
				return

	for icon_id in ["category_chat", "category_email", "category_calendar", "category_security", "category_school", "category_work", "category_shopping", "category_news", "action_more", "action_expand", "action_collapse", "action_close", "action_refresh", "media_previous", "media_pause", "media_play", "media_next", "camera"]:
		if LockScreenAssetLibrary.get_icon_texture(icon_id) == null:
			_fail("A lock-screen notification or media icon could not be loaded: " + icon_id)
			return
	for surface_id in ["notification", "media", "shortcut"]:
		if LockScreenAssetLibrary.get_surface_texture(surface_id) == null:
			_fail("A lock-screen surface asset could not be loaded: " + surface_id)
			return
	for face_index in range(1, LockScreenAssetLibrary.get_analog_face_count() + 1):
		if not FileAccess.file_exists(LockScreenAssetLibrary.get_analog_face_path(face_index)):
			_fail("An analog clock face asset is missing.")
			return
		for hand_name in ["hr", "min", "sec"]:
			if not FileAccess.file_exists(LockScreenAssetLibrary.get_analog_hand_path(face_index, hand_name)):
				_fail("An analog clock hand asset is missing.")
				return

	var designer: Control = LockScreenDesignerScript.new()
	designer.name = "LockScreenDesignerSmokeTest"
	designer.size = Vector2(680.0, 1360.0)
	root.add_child(designer)
	await process_frame

	var signatures: Dictionary = {}
	var layout_ids: Dictionary = {}
	var wallpaper_paths: Dictionary = {}
	var clock_styles: Dictionary = {}
	var analog_face_renderer_found := false
	var media_count := 0
	var notification_count := 0

	for generation_index in range(GENERATION_COUNT):
		var design: Dictionary = designer.call("generate_new_design")
		if design.is_empty():
			_fail("The hybrid designer failed to produce a valid composition.")
			return

		var issues: Array[String] = designer.call("validate_layout", design)
		if not issues.is_empty():
			_fail("Generated design %02d violated a layout rule: %s" % [generation_index + 1, "; ".join(issues)])
			return

		var signature := str(design.get("signature", ""))
		if signatures.has(signature):
			_fail("The designer repeated a lock-screen composition within the test window.")
			return
		signatures[signature] = true

		var layout_id := str(design.get("layout_id", ""))
		if layout_id.is_empty():
			_fail("A generated design is missing its curated layout ID.")
			return
		layout_ids[layout_id] = true

		var wallpaper_path := str(design.get("wallpaper_path", ""))
		if not wallpaper_path.begins_with("res://assets/wallpapers/") or not FileAccess.file_exists(wallpaper_path):
			_fail("A generated design selected a missing or unsupported wallpaper asset.")
			return
		wallpaper_paths[wallpaper_path] = true

		var style := str(design.get("clock_style", ""))
		clock_styles[style] = true
		if style == "analog":
			var analog_face := designer.find_child("GeneratedAnalogClockFace", true, false) as TextureRect
			if analog_face == null or analog_face.texture == null:
				_fail("The analog lock-screen renderer did not load its real clock-face asset.")
				return
			analog_face_renderer_found = true

		var notifications: Array = design.get("notifications", [])
		notification_count += notifications.size()
		for notification_entry in notifications:
			var icon_path := str(notification_entry.get("icon", ""))
			if icon_path.is_empty() or not FileAccess.file_exists(icon_path):
				_fail("A generated notification is missing its bundled app icon.")
				return

		var media: Dictionary = design.get("media", {})
		if not media.is_empty():
			media_count += 1
			var media_icon := str(media.get("icon", ""))
			if media_icon.is_empty() or not FileAccess.file_exists(media_icon):
				_fail("The generated media player is missing its bundled service icon.")
				return

		var shortcuts: Array = design.get("shortcuts", [])
		var found_flashlight := false
		var found_camera := false
		for shortcut in shortcuts:
			var kind := str(shortcut.get("kind", ""))
			var rect: Rect2 = shortcut.get("rect", Rect2())
			if rect.position.y < 0.885:
				_fail("A bottom shortcut was placed outside the bottom zone.")
				return
			if kind == "flashlight":
				found_flashlight = true
			elif kind == "camera":
				found_camera = true
		if not found_flashlight or not found_camera:
			_fail("The lock screen is missing its separate flashlight or camera shortcut.")

	var expected_blueprints: Array = LayoutLibrary.get_blueprints()
	if layout_ids.size() != expected_blueprints.size():
		_fail("The designer did not exercise every curated layout foundation.")
		return
	if wallpaper_paths.size() < 50:
		_fail("The designer did not rotate through enough distinct bundled wallpapers.")
		return
	if media_count < 5:
		_fail("The designer did not generate enough media-player compositions.")
		return
	if notification_count < 25:
		_fail("The designer did not generate enough app-branded notifications.")
		return
	if clock_styles.size() < 3:
		_fail("The designer did not vary its digital, stacked and analog clock treatments.")
		return
	if not analog_face_renderer_found:
		_fail("The analog clock face asset renderer was not exercised.")
		return
	if int(designer.call("get_generation_count")) != GENERATION_COUNT:
		_fail("The designer generation counter is inconsistent.")
		return
	if int(designer.call("get_available_wallpaper_count")) < 50:
		_fail("The lock-screen wallpaper library is unexpectedly small.")
		return

	var wallpaper_node := designer.find_child("GeneratedWallpaper", true, false) as TextureRect
	if wallpaper_node == null or wallpaper_node.texture == null:
		_fail("The generated lock screen is not rendering a real bundled wallpaper texture.")
		return
	if designer.find_child("BottomFlashlightShortcut", true, false) == null:
		_fail("The generated lock screen is missing the flashlight shortcut preview.")
		return
	if designer.find_child("BottomCameraShortcut", true, false) == null:
		_fail("The generated lock screen is missing the camera shortcut preview.")
		return

	# Force the preview through a media-capable composition and a notification
	# composition so their actual scene renderers are tested as well as metadata.
	var media_renderer_found := false
	var notification_renderer_found := false
	for _probe in range(30):
		var latest: Dictionary = designer.call("get_last_design")
		if not latest.get("media", {}).is_empty():
			var media_surface := designer.find_child("GeneratedMediaPlayerSurface", true, false) as TextureRect
			var media_controls := designer.find_child("GeneratedMediaControls", true, false) as HBoxContainer
			media_renderer_found = designer.find_child("GeneratedLockScreenMediaPlayer", true, false) != null and media_surface != null and media_surface.texture != null and media_controls != null
		if not latest.get("notifications", []).is_empty():
			var notification_surface := designer.find_child("GeneratedNotificationSurface", true, false) as TextureRect
			var category_icon := designer.find_child("NotificationCategoryIcon", true, false) as TextureRect
			notification_renderer_found = designer.find_child("GeneratedNotification", true, false) != null and notification_surface != null and notification_surface.texture != null and category_icon != null and category_icon.texture != null
		if media_renderer_found and notification_renderer_found:
			break
		designer.call("generate_new_design")

	if not media_renderer_found:
		_fail("The lock-screen media-player scene renderer was not exercised.")
		return
	if not notification_renderer_found:
		_fail("The lock-screen notification scene renderer was not exercised.")
		return
	if designer.find_child("GeneratedCameraGlyph", true, false) == null:
		_fail("The camera shortcut is missing its composed camera glyph.")
		return

	for selectable_style in StatusBarAssetLibrary.get_styles():
		var style_id := str(selectable_style.get("id", ""))
		if not bool(designer.call("set_status_bar_style", style_id)):
			_fail("The lock-screen renderer rejected a status-bar style: " + style_id)
			return
		if str(designer.call("get_status_bar_style_id")) != style_id:
			_fail("The selected status-bar style was not stored in the active design.")
			return
		if designer.find_child("StatusBarClock", true, false) == null:
			_fail("A status-bar preset failed to render its live clock.")
			return
		for icon_type in selectable_style.get("order", []):
			var icon_id := str(icon_type)
			if icon_id == "bluetooth" and not bool(selectable_style.get("show_bluetooth", false)):
				continue
			var node_name := "StatusBar" + icon_id.capitalize() + "Icon"
			var status_icon := designer.find_child(node_name, true, false) as TextureRect
			if status_icon == null or status_icon.texture == null:
				_fail("A status-bar preset failed to render an icon asset: " + node_name)
				return

	designer.free()
	print("HYBRID_LOCK_SCREEN_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("HYBRID_LOCK_SCREEN_SMOKE_TEST: FAIL: " + message)
	quit(1)
