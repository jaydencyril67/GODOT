extends SceneTree

const FaceAssetLibrary = preload("res://scripts/ui/xmorph_clock_face_asset_library.gd")
const WidgetAssetLibrary = preload("res://scripts/ui/xmorph_widget_asset_library.gd")
const DigitalClockScript = preload("res://scripts/ui/digital_lock_screen_clock.gd")
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
	digital_clock.call("configure", 41, {
		"accent": Color("#A9C9FF"),
		"text": Color.WHITE,
		"muted": Color("#C3CFE3")
	}, {"show_details": true, "device_clock": false})
	await process_frame
	if digital_clock.find_child("XMorphClockFace", true, false) == null:
		_fail("The XMorph digital clock renderer did not create its face canvas.")
		return
	if digital_clock.find_child("XMorphClockLayout", true, false) == null:
		_fail("The XMorph digital clock renderer did not create its JSON layout tree.")
		return
	if str(digital_clock.call("get_style_name")) != faces.get_face_name(41):
		_fail("The digital clock selector did not bind the 41st imported style.")
		return

	var widgets := WidgetAssetLibrary.new()
	var media_widget := widgets.get_widget("44_media_player")
	var notification_widget := widgets.get_widget("40_notifications")
	for required_layer in ["bg", "art", "title", "artist", "prev", "play", "next"]:
		if widgets.get_layer(media_widget, required_layer).is_empty():
			_fail("The XMorph media-player definition is missing layer: " + required_layer)
			return
	for required_layer in ["bg", "nicon", "count"]:
		if widgets.get_layer(notification_widget, required_layer).is_empty():
			_fail("The XMorph notification definition is missing layer: " + required_layer)
			return

	var media_card: Control = MediaPlayerScene.instantiate()
	media_card.name = "XMorphMediaPlayerSmokeTest"
	media_card.size = Vector2(680.0, 240.0)
	root.add_child(media_card)
	media_card.call("configure", {
		"service": "SPOTIFY",
		"icon": "res://assets/app_icons/papirus/entertainment_music/apps_spotify_client.svg",
		"album_art": "res://assets/lock-screen/music-player/1b9e7b387846cf3c10ff5c98ffaf2a4b.jpg",
		"title": "Midnight City",
		"artist": "M83",
		"playing": true
	}, {"accent": Color("#A9C9FF"), "text": Color.WHITE, "muted": Color("#C3CFE3")})
	await process_frame
	var media_surface := media_card.find_child("GeneratedMediaPlayerSurface", true, false) as TextureRect
	var media_art := media_card.find_child("MediaAlbumArtwork", true, false) as TextureRect
	var media_controls := media_card.find_child("GeneratedMediaControls", true, false) as HBoxContainer
	if media_surface == null or media_surface.texture == null or media_art == null or media_art.texture == null or media_controls == null:
		_fail("The imported XMorph media layout did not render its surface, artwork, and playback controls.")
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


func _fail(message: String) -> void:
	push_error(message)
	print("XMORPH_LOCK_SCREEN_ASSETS_SMOKE_TEST: FAIL: " + message)
	quit(1)
