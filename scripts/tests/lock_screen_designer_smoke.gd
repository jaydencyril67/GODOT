extends SceneTree

const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")
const LayoutLibrary = preload("res://scripts/lock_screen_layout_library.gd")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")
const StatusBarAssetLibrary = preload("res://scripts/status_bar_asset_library.gd")

const GENERATION_COUNT := 60
const MEDIA_PLAYER_ASSET_ROOT := "res://assets/music_player"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for asset_index in range(1, 11):
		var asset_path := "%s/musicplayer%02d.png" % [MEDIA_PLAYER_ASSET_ROOT, asset_index]
		var asset_texture := load(asset_path) as Texture2D
		if asset_texture == null or asset_texture.get_width() <= 0 or asset_texture.get_height() <= 0:
			_fail("A complete lock-screen music-player asset is missing or invalid: " + asset_path)
			return

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
		if designer.find_child("GeneratedAnalogClockArtwork", true, false) == null:
			_fail("The image-based analog clock scene component was not rendered.")
			return
		var lock_screen_date := designer.find_child("GeneratedLockScreenDate", true, false) as Label
		if lock_screen_date == null or lock_screen_date.visible:
			_fail("The lock-screen date must be completely hidden.")
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
			var artwork_path := str(media.get("artwork", ""))
			if not artwork_path.begins_with(MEDIA_PLAYER_ASSET_ROOT + "/") or not FileAccess.file_exists(artwork_path):
				_fail("The generated media player is missing a complete bundled music-player image.")
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

	# Both analog and digital clocks can travel to the visible screen edges.
	var screen_rect := designer.get_global_rect()
	for edge_position in [
		screen_rect.position + Vector2(0.0, 0.0),
		screen_rect.position + Vector2(screen_rect.size.x, screen_rect.size.y)
	]:
		var visible_bounds: Rect2 = clock_component.call("get_clock_visual_rect")
		if not bool(designer.call("begin_clock_drag", visible_bounds.get_center())):
			_fail("The flexible clock could not be grabbed for a screen-edge drag.")
			return
		if not bool(designer.call("drag_clock_to", edge_position)):
			_fail("The flexible clock could not move toward a phone-screen edge.")
			return
		designer.call("end_clock_drag")
		visible_bounds = clock_component.call("get_clock_visual_rect")
		if visible_bounds.position.x < screen_rect.position.x - 1.0 or visible_bounds.position.y < screen_rect.position.y - 1.0 or visible_bounds.end.x > screen_rect.end.x + 1.0 or visible_bounds.end.y > screen_rect.end.y + 1.0:
			_fail("Clock movement must be limited by the outer phone-screen edges, not an inner safe area.")
			return
	moved_clock_position = designer.call("get_clock_position")
	if not bool(designer.call("set_clock_position_mode", "fixed")):
		_fail("The clock could not be switched into Fixed mode.")
		return
	if bool(designer.call("begin_clock_drag", clock_component.call("get_drag_hit_rect").get_center())):
		_fail("A fixed clock remained draggable.")
		return
	if not bool(designer.call("set_clock_type", "digital")) or designer.call("get_clock_position") != moved_clock_position:
		_fail("Switching to Digital did not preserve the selected clock position.")
		return
	# Mirror the real initial-loading path: prepare every analog and digital clock style before asserting the cached face trees.
	if not bool(await designer.call("prepare_clock_styles_for_loading")):
		_fail("The lock-screen designer could not prepare all clock styles during initial setup.")
		return
	await process_frame
	await process_frame
	var digital_component := designer.find_child("GeneratedLockScreenClockComponent", true, false) as Control
	var digital_component_id := digital_component.get_instance_id()
	var digital_artwork := digital_component.find_child("DigitalClock", true, false) as Control
	var digital_artwork_id := digital_artwork.get_instance_id()
	var prebuilt_faces := digital_artwork.find_children("XMorphClockFace_*", "Control", true, false)
	if prebuilt_faces.size() != 41:
		_fail("All 41 digital clock face trees must be built during initial clock setup; found %d." % prebuilt_faces.size())
		return
	var initial_layout_ready: bool = await _wait_for_digital_clock_layout(digital_artwork, int(designer.call("get_clock_style_index")))
	if not initial_layout_ready:
		return
	var initial_digital_time_rect: Rect2 = digital_artwork.call("get_time_visual_rect")
	var initial_drag_bounds: Rect2 = digital_component.call("get_clock_visual_rect")
	if initial_digital_time_rect.position.distance_to(initial_drag_bounds.position) > 1.0 or initial_digital_time_rect.size.distance_to(initial_drag_bounds.size) > 1.0:
		_fail("Digital drag bounds must include only the active prebuilt face, not the 40 hidden faces.")
		return
	var maximum_time_font_size := 0
	for label_value in digital_artwork.find_children("*", "Label", true, false):
		var time_label := label_value as Label
		if time_label.is_visible_in_tree() and time_label.text.length() > 0:
			maximum_time_font_size = maxi(maximum_time_font_size, time_label.get_theme_font_size("font_size"))
	if maximum_time_font_size > 112:
		_fail("Digital clock text exceeds the compact 112px maximum (actual %dpx)." % maximum_time_font_size)
		return
	var expected_time_center: Vector2 = initial_digital_time_rect.get_center()
	var digital_date := digital_artwork.find_child("DigitalClockDate", true, false) as Label
	if digital_date != null and digital_date.visible:
		_fail("Digital clock faces must not display a date.")
		return
	for style_index in [1, 5, 12, 20, 29, 37, 41]:
		if not bool(designer.call("set_clock_style_index", style_index, false)):
			_fail("A digital style could not be selected while checking clock position stability.")
			return
		await process_frame
		await process_frame
		if designer.call("get_clock_position") != moved_clock_position:
			_fail("Changing digital clock styles must not change the saved clock position.")
			return
		digital_component = designer.find_child("GeneratedLockScreenClockComponent", true, false) as Control
		digital_artwork = digital_component.find_child("DigitalClock", true, false) as Control
		if digital_component.get_instance_id() != digital_component_id or digital_artwork.get_instance_id() != digital_artwork_id:
			_fail("Switching digital clock styles must reuse the same clock component and renderer.")
			return
		if int(digital_artwork.call("get_style_index")) != style_index:
			_fail("The cached digital renderer did not activate the requested prebuilt face.")
			return
		var visible_face_count := 0
		for face_value in prebuilt_faces:
			if (face_value as Control).visible:
				visible_face_count += 1
		if visible_face_count != 1:
			_fail("Exactly one of the 41 prebuilt digital clock faces must be visible after selection.")
			return
		var style_layout_ready: bool = await _wait_for_digital_clock_layout(digital_artwork, style_index)
		if not style_layout_ready:
			return
		var current_time_center: Vector2 = digital_artwork.call("get_time_visual_rect").get_center()
		var center_delta := current_time_center.distance_to(expected_time_center)
		if center_delta > 2.5:
			_fail("Changing digital clock styles must keep the visible time at the same screen position (style %d; expected %s, got %s; delta %.2f px)." % [style_index, expected_time_center, current_time_center, center_delta])
			return

	if not bool(designer.call("set_clock_position_mode", "flex")):
		_fail("The digital clock could not enter Flex mode for movement testing.")
		return
	var digital_screen_rect := designer.get_global_rect()
	var digital_edge_targets := [
		digital_screen_rect.position,
		Vector2(digital_screen_rect.end.x, digital_screen_rect.position.y),
		Vector2(digital_screen_rect.position.x, digital_screen_rect.end.y),
		digital_screen_rect.end
	]
	for edge_target in digital_edge_targets:
		var before_edge_rect: Rect2 = digital_component.call("get_clock_visual_rect")
		var before_edge_distance := before_edge_rect.get_center().distance_to(edge_target)
		if not bool(designer.call("begin_clock_drag", before_edge_rect.get_center())):
			_fail("The active digital face could not be grabbed for screen-edge movement.")
			return
		if not bool(designer.call("drag_clock_to", edge_target)):
			_fail("The digital clock could not move toward a requested screen section.")
			return
		designer.call("end_clock_drag")
		var after_edge_rect: Rect2 = digital_component.call("get_clock_visual_rect")
		if after_edge_rect.position.x < digital_screen_rect.position.x - 1.0 or after_edge_rect.position.y < digital_screen_rect.position.y - 1.0 or after_edge_rect.end.x > digital_screen_rect.end.x + 1.0 or after_edge_rect.end.y > digital_screen_rect.end.y + 1.0:
			_fail("The digital clock must remain inside the full phone screen while moving to its edges.")
			return
		if after_edge_rect.get_center().distance_to(edge_target) >= before_edge_distance:
			_fail("The digital clock did not move closer to the requested screen section.")
			return
	moved_clock_position = designer.call("get_clock_position")
	if not bool(designer.call("set_clock_position_mode", "fixed")):
		_fail("The digital clock could not return to Fixed mode after movement testing.")
		return
	if not bool(designer.call("set_clock_type", "analog")) or designer.call("get_clock_position") != moved_clock_position:
		_fail("Switching back to Analog did not preserve the selected clock position.")
		return
	await process_frame
	var analog_component := designer.find_child("GeneratedLockScreenClockComponent", true, false) as Control
	var analog_date := analog_component.find_child("GeneratedLockScreenDate", true, false) as Label
	if analog_date == null or analog_date.visible:
		_fail("The analog lock-screen date must remain hidden.")
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
	await process_frame

	var media_player := designer.find_child("GeneratedLockScreenMediaPlayer", true, false) as Control
	var media_artwork := designer.find_child("GeneratedMediaPlayerArtwork", true, false) as TextureRect
	var notification_surface := designer.find_child("GeneratedNotificationSurface", true, false) as TextureRect
	var category_icon := designer.find_child("NotificationCategoryIcon", true, false) as TextureRect
	if media_player == null or media_artwork == null or media_artwork.texture == null:
		_fail("The complete music-player image did not appear when the lockscreen option was enabled.")
		return
	var latest_design: Dictionary = designer.call("get_last_design")
	var expected_artwork_path := str(latest_design.get("media", {}).get("artwork", ""))
	if media_artwork.texture.resource_path != expected_artwork_path:
		_fail("The lockscreen did not render the exact music-player asset selected by its layout.")
		return
	if media_artwork.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		_fail("The lockscreen music-player image is not preserving its original proportions.")
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
	var retained_notification := designer.find_child("GeneratedNotification", true, false) as Control
	var retained_media := designer.find_child("GeneratedLockScreenMediaPlayer", true, false) as Control
	if retained_notification == null or retained_notification.visible or retained_media == null or not retained_media.visible:
		_fail("Disabling notifications must hide the existing notification without affecting the media player.")
		return
	if not bool(designer.call("set_display_option", "notifications", true)):
		_fail("The notification setting could not be switched on again.")
		return
	if not bool(designer.call("set_display_option", "flashlight", false)):
		_fail("The flashlight shortcut could not be switched off.")
		return
	var retained_flashlight := designer.find_child("BottomFlashlightShortcut", true, false) as Control
	var retained_camera := designer.find_child("BottomCameraShortcut", true, false) as Control
	if retained_flashlight == null or retained_flashlight.visible or retained_camera == null or not retained_camera.visible:
		_fail("Disabling flashlight must hide its existing shortcut and leave the camera shortcut enabled.")
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

	var status_bar_component := designer.find_child("LockScreenStatusBar", true, false) as Control
	var status_bar_component_id := status_bar_component.get_instance_id()
	if int(status_bar_component.call("get_style_variant_count")) != 10:
		_fail("All ten lock-screen status-bar styles must be prebuilt during initial preview setup.")
		return
	for selectable_style in StatusBarAssetLibrary.get_styles():
		var style_id := str(selectable_style.get("id", ""))
		if not bool(designer.call("set_status_bar_style", style_id)):
			_fail("The lock-screen renderer rejected a status-bar style: " + style_id)
			return
		if str(designer.call("get_status_bar_style_id")) != style_id:
			_fail("The selected status-bar style was not stored in the active design.")
			return
		if designer.find_child("LockScreenStatusBar", true, false).get_instance_id() != status_bar_component_id:
			_fail("Status-bar style changes must reuse the same prebuilt status-bar component.")
			return
		var visible_status_variants := 0
		for variant_value in status_bar_component.get_children():
			var variant := variant_value as Control
			if variant.name.begins_with("StatusBarVariant_") and variant.visible:
				visible_status_variants += 1
		if visible_status_variants != 1:
			_fail("Exactly one prebuilt lock-screen status-bar variant must be visible.")
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


func _wait_for_digital_clock_layout(digital_artwork: Control, style_index: int) -> bool:
	# Face layouts use BoxContainers whose measured label bounds are only valid
	# after the renderer has completed its normalization pass. Wait on that
	# explicit state instead of assuming a fixed number of frames is enough.
	for _frame_index in range(12):
		if not is_instance_valid(digital_artwork):
			_fail("Digital clock renderer was replaced while waiting for style %d to normalize." % style_index)
			return false
		if bool(digital_artwork.call("is_time_layout_normalized")):
			return true
		await process_frame
	if is_instance_valid(digital_artwork) and bool(digital_artwork.call("is_time_layout_normalized")):
		return true
	_fail("Digital clock style %d did not finish layout normalization within 12 frames." % style_index)
	return false


func _fail(message: String) -> void:
	push_error(message)
	print("HYBRID_LOCK_SCREEN_SMOKE_TEST: FAIL: " + message)
	quit(1)
