extends SceneTree

const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")
const LayoutLibrary = preload("res://scripts/lock_screen_layout_library.gd")

const GENERATION_COUNT := 60


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var designer: Control = LockScreenDesignerScript.new()
	designer.name = "LockScreenDesignerSmokeTest"
	designer.size = Vector2(680.0, 1360.0)
	root.add_child(designer)
	await process_frame

	var signatures: Dictionary = {}
	var layout_ids: Dictionary = {}
	var wallpaper_paths: Dictionary = {}
	var clock_styles: Dictionary = {}
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

		var notifications: Array = design.get("notifications", [])
		notification_count += notifications.size()
		for notification in notifications:
			var icon_path := str(notification.get("icon", ""))
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
			media_renderer_found = designer.find_child("GeneratedLockScreenMediaPlayer", true, false) != null
		if not latest.get("notifications", []).is_empty():
			notification_renderer_found = designer.find_child("GeneratedNotification", true, false) != null
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

	designer.free()
	print("HYBRID_LOCK_SCREEN_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("HYBRID_LOCK_SCREEN_SMOKE_TEST: FAIL: " + message)
	quit(1)
