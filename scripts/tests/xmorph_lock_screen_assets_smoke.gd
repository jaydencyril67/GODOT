extends SceneTree

const FaceAssetLibrary = preload("res://scripts/ui/xmorph_clock_face_asset_library.gd")
const WidgetAssetLibrary = preload("res://scripts/ui/xmorph_widget_asset_library.gd")
const DigitalClockScript = preload("res://scripts/ui/digital_lock_screen_clock.gd")
const DATE_TIME_GAP_MIN := 5.0
const DATE_TIME_GAP_MAX := 12.0
const MediaPlayerScene = preload("res://scenes/system_ui/lock_screen_media_player_card.tscn")
const NotificationScene = preload("res://scenes/system_ui/lock_screen_notification_card.tscn")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var faces := FaceAssetLibrary.new()
	if faces.get_face_count() != 41:
		_fail("The curated XMorph digital clock library must expose exactly 41 faces.")
		return

	var required_time_types := ["HOURS", "MINUTES", "COLON", "TIME", "HOUR_TENS", "HOUR_ONES", "MINUTE_TENS", "MINUTE_ONES"]
	for index in range(1, 42):
		var face: Dictionary = faces.get_face(index)
		if face.is_empty():
			_fail("An XMorph clock face could not be loaded at index %02d." % index)
			return
		if not FileAccess.file_exists(str(face.get("_asset_path", ""))):
			_fail("A selected XMorph clock JSON file is missing: " + str(face.get("_asset_file", "")))
			return
		var has_time := false
		for layer_value in face.get("layers", []):
			var layer: Dictionary = layer_value
			var layer_type := str(layer.get("type", ""))
			if layer_type in ["HAND_HOUR", "HAND_MINUTE"]:
				_fail("An analog hand layer entered the digital clock set: " + str(face.get("name", "")))
				return
			if layer_type in required_time_types:
				has_time = true
			var font_reference := str(layer.get("font", ""))
			if not font_reference.is_empty() and faces.get_font(font_reference) == null:
				_fail("An XMorph clock font reference could not be resolved: " + font_reference)
				return
		if not has_time:
			_fail("An XMorph style has no digital time layers: " + str(face.get("name", "")))
			return

	var digital_clock: Control = DigitalClockScript.new()
	digital_clock.name = "DigitalClockAssetSmokeTest"
	digital_clock.size = Vector2(680.0, 1360.0)
	root.add_child(digital_clock)
	var test_palette := {
		"accent": Color("#A9C9FF"),
		"text": Color.WHITE,
		"muted": Color("#C3CFE3")
	}
	# Match production initial loading: configure the selected face, then batch-build every style before asserting the cache.
	digital_clock.call("configure", 41, test_palette, {"show_details": true})
	if not bool(await digital_clock.call("prepare_all_styles", 3)):
		_fail("The XMorph renderer could not prepare all 41 digital clock styles.")
		return
	await process_frame
	var prebuilt_face_canvases := digital_clock.find_children("XMorphClockFace_*", "Control", true, false)
	var prebuilt_layout_trees := digital_clock.find_children("XMorphClockLayout_*", "Control", true, false)
	if prebuilt_face_canvases.size() != 41:
		_fail("The XMorph digital clock renderer must preload all 41 named face canvases.")
		return
	if prebuilt_layout_trees.size() != 41:
		_fail("The XMorph digital clock renderer must preload all 41 named JSON layout trees.")
		return
	if str(digital_clock.call("get_style_name")) != faces.get_face_name(41):
		_fail("The digital clock selector did not bind the 41st imported style.")
		return
	if digital_clock.find_child("DeviceClockTime", true, false) != null:
		_fail("Digital clock styles must never fall back to the shared Roboto device clock.")
		return

	var unique_names: Dictionary = {}
	var unique_design_signatures: Dictionary = {}
	var unique_time_fonts: Dictionary = {}
	var expected_time_font_size := -1
	for face_index in range(1, faces.get_face_count() + 1):
		digital_clock.call("configure", face_index, test_palette, {"show_details": true})
		await process_frame
		await process_frame
		var layout_ready: bool = await _wait_for_digital_clock_layout(digital_clock, face_index)
		if not layout_ready:
			return
		var face_canvas := digital_clock.find_child("XMorphClockFace_%02d" % face_index, true, false) as Control
		if face_canvas == null:
			_fail("Digital face %02d did not render on the default production path." % face_index)
			return
		if not is_equal_approx(face_canvas.anchor_left, 0.05) or not is_equal_approx(face_canvas.anchor_top, 0.30) or not is_equal_approx(face_canvas.anchor_right, 0.95) or not is_equal_approx(face_canvas.anchor_bottom, 0.70):
			_fail("Digital face %02d does not use the shared centered clock canvas." % face_index)
			return
		var time_bounds: Rect2 = digital_clock.call("get_time_visual_rect")
		if time_bounds.size == Vector2.ZERO or time_bounds.get_center().distance_to(face_canvas.get_global_rect().get_center()) > 2.5:
			_fail("Digital face %02d moves the visible time away from the shared position." % face_index)
			return
		var date_bounds: Rect2 = digital_clock.call("get_date_visual_rect")
		if date_bounds.size != Vector2.ZERO:
			var date_gap := float(digital_clock.call("get_date_time_gap_pixels"))
			if date_gap < DATE_TIME_GAP_MIN - 1.0 or date_gap > DATE_TIME_GAP_MAX + 1.0:
				_fail("Digital face %02d leaves too much space between the date and time." % face_index)
				return
		var face: Dictionary = faces.get_face(face_index)
		var face_name := str(face.get("name", ""))
		if face_name.is_empty() or unique_names.has(face_name):
			_fail("Digital face %02d does not have a unique design name." % face_index)
			return
		unique_names[face_name] = true
		var design_signature := JSON.stringify(face.get("large", {})) + "|" + JSON.stringify(face.get("layers", []))
		unique_design_signatures[design_signature] = true
		var time_layer_ids: Dictionary = {}
		for layer_value in face.get("layers", []):
			var layer: Dictionary = layer_value
			if str(layer.get("type", "")) in ["HOURS", "MINUTES", "COLON", "TIME", "HOUR_TENS", "HOUR_ONES", "MINUTE_TENS", "MINUTE_ONES"]:
				time_layer_ids[str(layer.get("id", ""))] = true
		for layer_value in face.get("layers", []):
			var layer: Dictionary = layer_value
			if not time_layer_ids.has(str(layer.get("id", ""))):
				continue
			var font_reference := str(layer.get("font", "roboto_flex")).trim_prefix("res:").get_slice("?", 0)
			unique_time_fonts[font_reference] = true
		for label_value in digital_clock.find_children("*", "Label", true, false):
			var clock_label := label_value as Label
			var rendered_layer_id := ""
			match clock_label.name:
				"DigitalClockHours":
					rendered_layer_id = "hours"
				"DigitalClockMinutes":
					rendered_layer_id = "minutes"
				"DigitalClockTime":
					rendered_layer_id = "time"
				"DigitalClockDate":
					continue
				_:
					if clock_label.name.begins_with("ClockLayer_"):
						rendered_layer_id = clock_label.name.trim_prefix("ClockLayer_")
			if not time_layer_ids.has(rendered_layer_id):
				continue
			if expected_time_font_size < 0:
				expected_time_font_size = clock_label.get_theme_font_size("font_size")
			elif clock_label.get_theme_font_size("font_size") != expected_time_font_size:
				_fail("Digital faces must keep the same time font size across every style.")
				return

	if unique_names.size() != faces.get_face_count() or unique_design_signatures.size() != faces.get_face_count() or unique_time_fonts.size() < 10:
		_fail("The digital clock set must retain unique designs and a broad range of imported time fonts.")
		return

	# Production initially keeps the digital renderer hidden while Analog is selected.
	# Its cached labels must still be measurable, rather than waiting for the 12-frame invalid-bounds fallback.
	var hidden_host := Control.new()
	hidden_host.name = "HiddenAnalogClockHost"
	hidden_host.size = Vector2(680.0, 1360.0)
	hidden_host.visible = false
	root.add_child(hidden_host)
	var hidden_clock: Control = DigitalClockScript.new()
	hidden_clock.name = "HiddenDigitalClockAssetSmokeTest"
	hidden_clock.size = Vector2(680.0, 1360.0)
	hidden_host.add_child(hidden_clock)
	hidden_clock.call("configure", 41, test_palette, {"show_details": true})
	var hidden_progress_values: Array[float] = []
	var hidden_progress_callback := func(_message: String, progress: float) -> void:
		hidden_progress_values.append(progress)
	var hidden_start_frame := Engine.get_process_frames()
	if not bool(await hidden_clock.call("prepare_all_styles", 3, hidden_progress_callback)):
		_fail("The hidden digital renderer could not prepare its 41 cached clock styles.")
		return
	var hidden_elapsed_frames := Engine.get_process_frames() - hidden_start_frame
	if hidden_elapsed_frames > 100 or not bool(hidden_clock.call("is_time_layout_normalized")):
		_fail("Hidden digital clock layouts took too long to normalize (%d frames)." % hidden_elapsed_frames)
		return
	var previous_hidden_progress := -1.0
	var hidden_normalization_updates := 0
	for progress_value in hidden_progress_values:
		if progress_value + 0.001 < previous_hidden_progress:
			_fail("Hidden digital clock preparation progress moved backwards.")
			return
		if progress_value > 75.0 and progress_value < 100.0:
			hidden_normalization_updates += 1
		previous_hidden_progress = progress_value
	if hidden_normalization_updates < 3 or not is_equal_approx(previous_hidden_progress, 100.0):
		_fail("Hidden digital clock normalization must report incremental progress through completion.")
		return
	hidden_clock.free()
	hidden_host.free()

	var widgets := WidgetAssetLibrary.new()
	var notification_widget := widgets.get_widget("40_notifications")
	for required_layer in ["bg", "nicon", "count"]:
		if widgets.get_layer(notification_widget, required_layer).is_empty():
			_fail("The XMorph notification definition is missing layer: " + required_layer)
			return

	var media_card: Control = MediaPlayerScene.instantiate()
	media_card.name = "XMorphMediaPlayerSmokeTest"
	media_card.size = Vector2(680.0, 240.0)
	root.add_child(media_card)
	media_card.call("configure", {
		"artwork": "res://assets/music_player/musicplayer01.png"
	})
	await process_frame
	var media_artwork := media_card.find_child("GeneratedMediaPlayerArtwork", true, false) as TextureRect
	if media_artwork == null or media_artwork.texture == null:
		_fail("The lock-screen music-player artwork did not load as a complete card.")
		return
	if media_artwork.texture.resource_path != "res://assets/music_player/musicplayer01.png":
		_fail("The lock-screen renderer loaded a different music-player asset.")
		return
	if media_artwork.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		_fail("The complete music-player artwork must preserve its original aspect ratio.")
		return
	if media_card.find_child("GeneratedMediaPlayerSurface", true, false) != null or media_card.find_child("GeneratedMediaControls", true, false) != null:
		_fail("The old generated player overlays must not be drawn over the complete artwork.")
		return

	var notification_card: Control = NotificationScene.instantiate()
	notification_card.name = "XMorphNotificationSmokeTest"
	notification_card.size = Vector2(680.0, 120.0)
	root.add_child(notification_card)
	notification_card.call("configure", {
		"app": "WHATSAPP",
		"icon": "res://assets/app_icons/papirus/social/apps_whatsapp.svg",
		"title": "You have a new message",
		"body": "A new conversation is waiting for you.",
		"timestamp": "NOW",
		"notification_count": 1
	}, {"accent": Color("#A9C9FF"), "text": Color.WHITE, "muted": Color("#C3CFE3")})
	await process_frame
	var notification_surface := notification_card.find_child("GeneratedNotificationSurface", true, false) as TextureRect
	var notification_icon := notification_card.find_child("NotificationCategoryIcon", true, false) as TextureRect
	var notification_badge := notification_card.find_child("NotificationCountBadge", true, false) as Panel
	if notification_surface == null or notification_surface.texture == null or notification_icon == null or notification_icon.texture == null or notification_badge == null:
		_fail("The imported XMorph notification widget did not render its card, category icon, and count badge.")
		return

	if LockScreenAssetLibrary.get_analog_clock_count() != 41:
		_fail("The existing analog clock collection changed during the digital refactor.")
		return

	digital_clock.free()
	media_card.free()
	notification_card.free()
	print("XMORPH_LOCK_SCREEN_ASSETS_SMOKE_TEST: PASS")
	quit()


func _wait_for_digital_clock_layout(digital_clock: Control, face_index: int) -> bool:
	# Each imported face can use a different nested layout. Wait until the
	# renderer has detached its date layer, allowed containers to reflow, and
	# centered the final time bounds before testing its shared position.
	for _frame_index in range(12):
		if not is_instance_valid(digital_clock):
			_fail("Digital face %02d renderer was replaced before normalization." % face_index)
			return false
		if bool(digital_clock.call("is_time_layout_normalized")):
			return true
		await process_frame
	if is_instance_valid(digital_clock) and bool(digital_clock.call("is_time_layout_normalized")):
		return true
	_fail("Digital face %02d did not finish layout normalization within 12 frames." % face_index)
	return false


func _fail(message: String) -> void:
	push_error(message)
	print("XMORPH_LOCK_SCREEN_ASSETS_SMOKE_TEST: FAIL: " + message)
	quit(1)
