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
	for asset_index in range(1, LockScreenAssetLibrary.get_analog_clock_count() + 1):
		var asset_path := LockScreenAssetLibrary.get_analog_clock_path(asset_index)
		if not FileAccess.file_exists(asset_path):
			_fail("An uploaded analog clock artwork asset is missing: " + asset_path)
			return

	var designer: Control = LockScreenDesignerScript.new()
	designer.name = "LockScreenDesignerSmokeTest"
	designer.size = Vector2(680.0, 1360.0)
	root.add_child(designer)
	await process_frame

	for option in ["notifications", "music_player", "flashlight", "camera", "fingerprint"]:
		if bool(designer.call("get_display_option", option)):
			_fail("Optional lock-screen element was enabled by default: " + option)
			return

	var signatures: Dictionary = {}
	var layout_ids: Dictionary = {}

	var wallpaper_paths: Dictionary = {}
	var original_wallpaper_path := ""
	var analog_asset_indices: Dictionary = {}
	var analog_artwork_renderer_found := false
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

		var wallpaper_shade := designer.find_child("LockScreenWallpaperLegibilityShade", true, false) as ColorRect
		if wallpaper_shade == null or wallpaper_shade.color.a < 0.55:
			_fail("A generated lock-screen wallpaper is not darkened enough.")
			return

		var wallpaper_path := str(design.get("wallpaper_path", ""))
		if not wallpaper_path.begins_with("res://assets/wallpapers/") or not FileAccess.file_exists(wallpaper_path):
			_fail("A generated design selected a missing or unsupported wallpaper asset.")
			return
		if generation_index == 0:
			original_wallpaper_path = wallpaper_path
		elif wallpaper_path != original_wallpaper_path:
			_fail("Regenerating the lock-screen layout unexpectedly changed the selected wallpaper.")
			return
		wallpaper_paths[wallpaper_path] = true

		var asset_index := int(design.get("analog_clock_asset_index", 0))
		if asset_index < 1 or asset_index > LockScreenAssetLibrary.get_analog_clock_count():
			_fail("A generated design selected an invalid analog clock artwork index.")
			return
		analog_asset_indices[asset_index] = true
		if designer.find_child("GeneratedAnalogClockArtwork", true, false) == null or designer.find_child("GeneratedLockScreenDate", true, false) == null:
			_fail("The image-based analog clock/date scene component was not rendered.")
			return
		for legacy_node_name in ["GeneratedLockScreenClock", "GeneratedAnalogClockFace", "AnalogHourHand", "AnalogMinuteHand", "AnalogSecondHand"]:
			if designer.find_child(legacy_node_name, true, false) != null:
				_fail("A legacy generated clock or separate clock-hand node is still present: " + legacy_node_name)
				return
		if designer.find_child("LockScreenStatusBar", true, false) == null:
			_fail("The asset-backed status-bar scene component was not rendered.")
			return
		if bool(design.get("show_fingerprint", false)) and designer.find_child("GeneratedLockScreenFingerprint", true, false) == null:
			_fail("The asset-backed fingerprint prompt component was not rendered.")
			return
		var analog_artwork := designer.find_child("GeneratedAnalogClockArtwork", true, false) as TextureRect
		if analog_artwork == null or analog_artwork.texture == null:
			_fail("The analog lock-screen renderer did not load a complete clock artwork asset.")
			return
		var expected_clock_path := LockScreenAssetLibrary.get_analog_clock_path(asset_index)
		if analog_artwork.texture.resource_path != expected_clock_path:
			_fail("The selected analog clock artwork does not match its generated asset index.")
			return
		analog_artwork_renderer_found = true

		var notifications: Array = design.get("notifications", [])
		if notifications.is_empty():
			_fail("A generated lock-screen composition has no notification available for the optional notification renderer.")
			return
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

	if str(designer.call("get_clock_position_mode")) != "fixed":
		_fail("Lock-screen clock positioning must default to Fixed mode.")
		return
	var clock_component := designer.find_child("GeneratedLockScreenClockComponent", true, false) as Control
	if clock_component == null:
		_fail("The generated lock-screen clock component is missing.")
		return
	var initial_clock_position: Vector2 = designer.call("get_clock_position")
	if bool(designer.call("begin_clock_drag", clock_component.call("get_drag_hit_rect").get_center())):
		_fail("A fixed clock must reject drag attempts.")
		return
	if not bool(designer.call("set_clock_position_mode", "flex")):
		_fail("The clock could not be switched into Flex mode.")
		return
	var drag_hit_rect: Rect2 = clock_component.call("get_drag_hit_rect")
	if not bool(designer.call("begin_clock_drag", drag_hit_rect.get_center())):
		_fail("A flexible clock did not start dragging when touched.")
		return
	if not bool(designer.call("drag_clock_to", Vector2(520.0, 1080.0))):
		_fail("A flexible clock did not follow the pointer.")
		return
	designer.call("end_clock_drag")
	var moved_clock_position: Vector2 = designer.call("get_clock_position")
	if moved_clock_position.distance_to(initial_clock_position) < 0.05:
		_fail("Dragging in Flex mode did not persist a new clock position.")
		return
	if not bool(designer.call("set_clock_position_mode", "fixed")):
		_fail("The clock could not be switched into Fixed mode.")
		return
	if bool(designer.call("begin_clock_drag", clock_component.call("get_drag_hit_rect").get_center())):
		_fail("A fixed clock remained draggable.")
		return
	if not bool(designer.call("set_clock_type", "digital")) or designer.call("get_clock_position") != moved_clock_position:
		_fail("Switching to Digital did not preserve the selected clock position.")
		return
	if not bool(designer.call("set_clock_type", "analog")) or designer.call("get_clock_position") != moved_clock_position:
		_fail("Switching back to Analog did not preserve the selected clock position.")
		return
	if not bool(designer.call("set_clock_position_mode", "flex")):
		_fail("The clock could not restore Flex mode after switching clock types.")
		return
	var expected_blueprints: Array = LayoutLibrary.get_blueprints()
	if layout_ids.size() != expected_blueprints.size():
		var missing_layouts: Array[String] = []
		for blueprint in expected_blueprints:
			var expected_id := str(blueprint.get("id", ""))
			if not layout_ids.has(expected_id):
				missing_layouts.append(expected_id)
		_fail("The designer did not exercise every curated layout foundation. Missing: %s. Seen: %s" % [", ".join(missing_layouts), ", ".join(layout_ids.keys())])
		return
	if wallpaper_paths.size() != 1:
		_fail("Layout generation should retain one selected wallpaper until the Wallpapers step changes it.")
		return
	if media_count < 5:
		_fail("The designer did not generate enough media-player compositions.")
		return
	if notification_count < 25:
		_fail("The designer did not generate enough app-branded notifications.")
		return
	if analog_asset_indices.is_empty():
		_fail("The designer did not select any analog clock artwork.")
		return
	if not analog_artwork_renderer_found:
		_fail("The complete analog clock artwork renderer was not exercised.")
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
	if designer.find_child("BottomFlashlightShortcut", true, false) != null or designer.find_child("BottomCameraShortcut", true, false) != null:
		_fail("Flashlight and camera shortcuts must both be hidden by default.")
		return

	# Enable each optional element independently and exercise its real renderer.
	for option in ["notifications", "music_player", "flashlight", "camera", "fingerprint"]:
		if not bool(designer.call("set_display_option", option, true)):
			_fail("The lock-screen rejected an optional display setting: " + option)
			return

	var media_surface := designer.find_child("GeneratedMediaPlayerSurface", true, false) as TextureRect
	var media_controls := designer.find_child("GeneratedMediaControls", true, false) as HBoxContainer
	var notification_surface := designer.find_child("GeneratedNotificationSurface", true, false) as TextureRect
	var category_icon := designer.find_child("NotificationCategoryIcon", true, false) as TextureRect
	if designer.find_child("GeneratedLockScreenMediaPlayer", true, false) == null or media_surface == null or media_surface.texture == null or media_controls == null:
		_fail("The media-player scene renderer did not appear when enabled.")
		return
	if designer.find_child("GeneratedNotification", true, false) == null or notification_surface == null or notification_surface.texture == null or category_icon == null or category_icon.texture == null:
		_fail("The notification scene renderer did not appear when enabled.")
		return
	if designer.find_child("GeneratedLockScreenFingerprint", true, false) == null:
		_fail("The fingerprint component did not appear when enabled.")
		return
	if designer.find_child("BottomFlashlightShortcut", true, false) == null or designer.find_child("BottomCameraShortcut", true, false) == null:
		_fail("Both bottom shortcuts should appear after their independent settings are enabled.")
		return
	if designer.find_child("GeneratedCameraGlyph", true, false) == null:
		_fail("The camera shortcut is missing its composed camera glyph.")
		return

	if not bool(designer.call("set_display_option", "notifications", false)):
		_fail("The notification setting could not be switched off.")
		return
	if designer.find_child("GeneratedNotification", true, false) != null or designer.find_child("GeneratedLockScreenMediaPlayer", true, false) == null:
		_fail("Disabling notifications must not disable the independent media player.")
		return
	if not bool(designer.call("set_display_option", "notifications", true)):
		_fail("The notification setting could not be switched on again.")
		return
	if not bool(designer.call("set_display_option", "flashlight", false)):
		_fail("The flashlight shortcut could not be switched off.")
		return
	if designer.find_child("BottomFlashlightShortcut", true, false) != null or designer.find_child("BottomCameraShortcut", true, false) == null:
		_fail("Disabling flashlight must leave the camera shortcut enabled.")
		return
	if not bool(designer.call("set_display_option", "flashlight", true)):
		_fail("The flashlight shortcut could not be switched on again.")
		return

	var wallpapers: Array = designer.call("get_wallpaper_paths")
	var chosen_wallpaper := original_wallpaper_path
	if wallpapers.size() > 1:
		for path_value in wallpapers:
			if str(path_value) != original_wallpaper_path:
				chosen_wallpaper = str(path_value)
				break
	if not bool(designer.call("set_wallpaper", chosen_wallpaper)):
		_fail("The independent wallpaper selector rejected a bundled wallpaper.")
		return
	var generated_again: Dictionary = designer.call("generate_new_design")
	if str(generated_again.get("wallpaper_path", "")) != chosen_wallpaper:
		_fail("Layout regeneration replaced the wallpaper selected independently.")
		return
	for option in ["notifications", "music_player", "flashlight", "camera", "fingerprint"]:
		if not bool(designer.call("get_display_option", option)):
			_fail("Regeneration discarded the user's lock-screen element preference: " + option)
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
