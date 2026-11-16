extends SceneTree

const ProceduralEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const SimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")
const WorksiteScene = preload("res://scenes/os_creation_worksite.tscn")
const DigitalWorldGameScript = preload("res://scripts/digitalworld_game.gd")

func _initialize() -> void:
	call_deferred("_run_os_generator_test")

func _run_os_generator_test() -> void:
	var identity_owner := DigitalWorldGameScript.new()
	identity_owner.set("career", {"phone_name": "   ", "phone_model": null})
	identity_owner.call("_normalize_phone_identity")
	var normalized_identity: Dictionary = identity_owner.get("career")
	if normalized_identity.get("phone_name", "") != "DigitalWorld Phone" or normalized_identity.get("phone_model", "") != "DW-01":
		_fail("Career phone identity fallback did not replace blank and null values.")
		identity_owner.free()
		return
	identity_owner.set("career", {})
	identity_owner.call("_normalize_phone_identity")
	normalized_identity = identity_owner.get("career")
	identity_owner.free()
	if normalized_identity.get("phone_name", "") != "DigitalWorld Phone" or normalized_identity.get("phone_model", "") != "DW-01":
		_fail("Career phone identity fallback did not handle missing save fields.")
		return

	var generated := ProceduralEngineScript.generate_os(1357911, 2)
	var components: Dictionary = generated.get("components", {})
	if generated.get("schema_version", 0) != ProceduralEngineScript.SCHEMA_VERSION:
		_fail("Generated OS did not use the current configuration schema.")
		return
	if components.size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("Generator did not produce all 6 core OS components.")
		return
	if str(components.get("home_screen", {}).get("layout_style", "")) != "android_pixel":
		_fail("New OS generation must select the approved Android home-screen structure.")
		return
	if ProceduralEngineScript.APP_DEFINITIONS.size() != 30:
		_fail("OS app catalog must contain exactly 30 installed apps.")
		return
	var generated_icon_size := int(generated.get("style", {}).get("icon_size", 0))
	if generated_icon_size < 48 or generated_icon_size > 56:
		_fail("Generated app icon size is outside the upgraded 48–56 px range.")
		return
	if not ProceduralEngineScript.validate_os(generated).is_empty():
		_fail("Generated OS failed configuration validation.")
		return
	for component in ProceduralEngineScript.COMPONENTS:
		if not components.has(component["id"]):
			_fail("Missing generated component: " + str(component["id"]))
			return

	var expected_radii := [0, 6, 18]
	var expected_widgets := [0, 2, 1]
	for generation_number in range(1, 4):
		var generation_config := ProceduralEngineScript.generate_os(7000 + generation_number, generation_number)
		var generation_style: Dictionary = generation_config.get("style", {})
		if int(generation_style.get("corner_radius", -1)) != expected_radii[generation_number - 1]:
			_fail("Generation-specific corner radius is incorrect for generation %d." % generation_number)
			return
		if int(generation_style.get("widget_count", -1)) != expected_widgets[generation_number - 1]:
			_fail("Generation-specific widget count is incorrect for generation %d." % generation_number)
			return
		var tampered_config := generation_config.duplicate(true)
		tampered_config["style"]["corner_radius"] = 27
		tampered_config["style"]["widget_count"] = 99
		var enforced_config := ProceduralEngineScript.normalize_os(tampered_config)
		if int(enforced_config["style"]["corner_radius"]) != expected_radii[generation_number - 1] or int(enforced_config["style"]["widget_count"]) != expected_widgets[generation_number - 1]:
			_fail("Users can override generation-locked visual rules for generation %d." % generation_number)
			return

	var missing_icon_shape_config := generated.duplicate(true)
	missing_icon_shape_config["style"].erase("icon_shape")
	var normalized_missing_icon_shape := ProceduralEngineScript.normalize_os(missing_icon_shape_config)
	if str(normalized_missing_icon_shape["style"].get("icon_shape", "")) != "rounded":
		_fail("OS normalization did not default a missing icon shape.")
		return

	var legacy_config := generated.duplicate(true)
	legacy_config["schema_version"] = 1
	legacy_config["style"]["wallpaper"] = "res://legacy/old_wallpaper.png"
	var migrated := ProceduralEngineScript.normalize_os(legacy_config)
	if migrated.get("schema_version", 0) != ProceduralEngineScript.SCHEMA_VERSION:
		_fail("Legacy OS configuration was not migrated to the current schema.")
		return
	if not ProceduralEngineScript.WALLPAPER_STYLES.has(str(migrated["style"].get("wallpaper", ""))):
		_fail("Legacy wallpaper reference was not converted to a procedural wallpaper style.")
		return
	if not ProceduralEngineScript.validate_os(migrated).is_empty():
		_fail("Migrated OS configuration failed validation.")
		return


	var legacy_lock_config := generated.duplicate(true)
	legacy_lock_config["schema_version"] = 5
	legacy_lock_config["generation"] = 1
	legacy_lock_config["components"]["lock_screen"]["show_audio_player"] = true
	legacy_lock_config["components"]["lock_screen"]["design_family"] = "glass"
	legacy_lock_config["components"]["lock_screen"]["show_camera_shortcut"] = false
	var migrated_lock := ProceduralEngineScript.normalize_os(legacy_lock_config)
	var migrated_lock_data: Dictionary = migrated_lock["components"]["lock_screen"]
	if migrated_lock_data.has("design_family") or migrated_lock_data.has("show_audio_player") or bool(migrated_lock_data.get("show_camera_shortcut", true)):
		_fail("Legacy lock-screen design settings were not cleaned up while preserving shortcut enablement.")
		return
	for required_setting in ["show_time", "show_date", "show_camera_shortcut", "show_flashlight_shortcut"]:
		if not migrated_lock_data.has(required_setting):
			_fail("Generation 1 lock-screen setting was not migrated: " + required_setting)
			return
	var simulator_host := Control.new()
	simulator_host.name = "OSSimulatorResponsiveTestHost"
	simulator_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	simulator_host.size = Vector2(145.0, 640.0)
	root.add_child(simulator_host)


	await process_frame
	# Keep the gesture-routing simulator at its original compact viewport;
	# the taller host above is reserved for lock-screen vertical-layout checks.
	simulator_host.size = Vector2(145.0, 360.0)
	await process_frame


	var lock_screen_before: Dictionary = components["lock_screen"].duplicate(true)
	var wallpaper_regenerated := ProceduralEngineScript.regenerate_component(generated, "wallpapers", 246802)
	var wallpaper_components: Dictionary = wallpaper_regenerated["components"]
	var lock_screen_after: Dictionary = wallpaper_components["lock_screen"]
	var selected_wallpaper := str(wallpaper_regenerated["style"]["wallpaper"])
	if not ProceduralEngineScript.WALLPAPER_STYLES.has(selected_wallpaper):
		_fail("Wallpaper regeneration selected an unsupported wallpaper style.")
		return
	for lock_key in ["show_time", "show_date", "show_camera_shortcut", "show_assistant_shortcut", "show_notifications"]:
		if bool(lock_screen_after.get(lock_key, false)) != bool(lock_screen_before.get(lock_key, false)):
			_fail("Wallpaper regeneration unexpectedly changed Android Oreo lock-screen setting: " + lock_key)
			return
	if selected_wallpaper != wallpaper_components["home_screen"]["wallpaper"] or selected_wallpaper != wallpaper_components["lock_screen"].get("wallpaper", selected_wallpaper) or selected_wallpaper != wallpaper_components["wallpapers"]["style"]:
		_fail("Wallpaper regeneration did not keep the OS wallpaper synchronized.")
		return
	var legacy_style_config := generated.duplicate(true)
	legacy_style_config["schema_version"] = 2
	legacy_style_config["components"]["app_icons"] = {"shape": "squircle", "size": 60}
	legacy_style_config["components"]["themes_appearance"] = {"palette": ProceduralEngineScript.PALETTES[1].duplicate(true)}
	var migrated_style := ProceduralEngineScript.normalize_os(legacy_style_config)
	if migrated_style["style"]["icon_shape"] != "squircle" or migrated_style["style"]["icon_size"] != 60:
		_fail("Legacy icon styling was not migrated into shared OS settings.")
		return
	if migrated_style["style"]["palette"] != ProceduralEngineScript.PALETTES[1]:
		_fail("Legacy theme palette was not migrated into shared OS settings.")
		return
	for obsolete_id in ["app_icons", "themes_appearance", "animations_transitions", "navigation_gestures", "recent_apps", "system_ui"]:
		if migrated_style["components"].has(obsolete_id):
			_fail("Obsolete standalone component survived migration: " + obsolete_id)
			return

	var test_save_path := "user://os_generator_smoke_test.json"
	if not ProceduralEngineScript.save_os(wallpaper_regenerated, test_save_path):
		_fail("Generated OS configuration could not be saved.")
		return
	var loaded := ProceduralEngineScript.load_os(test_save_path)
	if loaded.get("seed", -1) != wallpaper_regenerated.get("seed", -2):
		_fail("Saved OS configuration could not be loaded correctly.")
		return
	if not ProceduralEngineScript.validate_os(loaded).is_empty():
		_fail("Loaded OS configuration failed validation.")
		return

	generated["components"]["home_screen"]["layout_style"] = "ios_home"
	var simulator := SimulatorScript.new()
	simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simulator.configure_os(generated, "home_screen")
	simulator_host.add_child(simulator)
	await process_frame


	var lock_preview_config := generated.duplicate(true)
	lock_preview_config["generation"] = 1
	lock_preview_config["components"]["home_screen"]["layout_style"] = "android_pixel"
	lock_preview_config = ProceduralEngineScript.normalize_os(lock_preview_config)
	var lock_preview_data: Dictionary = lock_preview_config["components"]["lock_screen"]
	lock_preview_data["show_time"] = true
	lock_preview_data["show_date"] = true
	lock_preview_data["show_camera_shortcut"] = true
	lock_preview_data["show_flashlight_shortcut"] = true
	simulator.configure_os(lock_preview_config, "lock_screen")
	await process_frame
	for lock_control_name in ["LollipopLockScreen", "LockScreenClock", "LockScreenDate", "LockScreenShortcut_Camera", "LockScreenShortcut_Flashlight"]:
		if simulator.find_child(lock_control_name, true, false) == null:
			_fail("Lollipop lock screen is missing expected element: " + lock_control_name)
			return
	if simulator.find_child("LockScreenAudioPlayer", true, false) != null or simulator.find_child("LockScreenFingerprintSensor", true, false) != null:
		_fail("Legacy media or fingerprint lock-screen widgets are still being rendered.")
		return
	var lollipop_clock := simulator.find_child("LockScreenClock", true, false) as Label
	var lollipop_date := simulator.find_child("LockScreenDate", true, false) as Label
	var lock_status_clock := simulator.find_child("StatusBarClock", true, false) as Label
	if lollipop_clock == null or lollipop_clock.text.strip_edges().is_empty() or lollipop_date == null or lollipop_date.text.strip_edges().is_empty():
		_fail("Lollipop lock-screen time or date is blank.")
		return
	if lock_status_clock == null or not lock_status_clock.visible or lock_status_clock.text.strip_edges().is_empty():
		_fail("Lollipop lock screen must keep the small status-bar time visible above the large lock-screen clock.")
		return
	var camera_shortcut := simulator.find_child("LockScreenShortcut_Camera", true, false) as Button
	var flashlight_shortcut := simulator.find_child("LockScreenShortcut_Flashlight", true, false) as Button
	if camera_shortcut == null or flashlight_shortcut == null or camera_shortcut.get_index() >= flashlight_shortcut.get_index():
		_fail("Lollipop camera and flashlight shortcuts are missing or incorrectly ordered.")
		return
	var hidden_lock_config := lock_preview_config.duplicate(true)
	hidden_lock_config["components"]["lock_screen"]["show_time"] = false
	hidden_lock_config["components"]["lock_screen"]["show_date"] = false
	hidden_lock_config["components"]["lock_screen"]["show_camera_shortcut"] = false
	hidden_lock_config["components"]["lock_screen"]["show_flashlight_shortcut"] = false
	simulator.configure_os(hidden_lock_config, "lock_screen")
	await process_frame
	for hidden_name in ["LockScreenClock", "LockScreenDate", "LockScreenShortcut_Camera", "LockScreenShortcut_Flashlight"]:
		var hidden_control := simulator.find_child(hidden_name, true, false)
		if hidden_control != null:
			_fail("Disabled Lollipop lock-screen element remained visible: " + hidden_name)
			return
	simulator.configure_os(lock_preview_config, "lock_screen")
	await process_frame
	var lock_gesture_position := Vector2(72, 180)
	simulator.call("_handle_system_gesture", lock_gesture_position, Vector2(72, 105), 180)
	await process_frame
	if simulator.get("active_component") != "pin_input":
		_fail("Upward swipe did not open PIN entry from the lock screen.")
		return
	for digit in ["1", "2", "3", "4"]:
		var unlock_key := simulator.find_child("PINKey_" + digit, true, false) as Button
		if unlock_key == null:
			_fail("PIN keypad is missing digit " + digit + ".")
			return
		unlock_key.pressed.emit()
		await process_frame
	if simulator.get("active_component") != "home_screen":
		_fail("Correct PIN 1234 did not unlock the phone after a lock-screen swipe.")
		return
	simulator.set_component_view("home_screen")
	await process_frame

	if ProceduralEngineScript.HOME_LAYOUT_STYLES != ["android_pixel", "ios_home", "windows_tiles"]:
		_fail("Home Screen Studio must contain only Android, iOS and Windows layouts, in that order.")
		return
	for generation_number in range(1, 4):
		var generation_preview := ProceduralEngineScript.generate_os(8100 + generation_number, generation_number)
		simulator.configure_os(generation_preview, "home_screen")
		await process_frame
		if str(generation_preview.get("components", {}).get("home_screen", {}).get("layout_style", "")) != "android_pixel":
			_fail("OS generation did not use the approved Android home-screen layout.")
			return
		if generation_number == 1:
			if simulator.find_child("LollipopGoogleSearchBar", true, false) == null or simulator.find_child("LollipopHomeAppGrid", true, false) == null:
				_fail("Android Generation 1 must render the Lollipop Google search bar and home app grid.")
				return
			if simulator.find_child("LollipopAppDrawerButton", true, false) == null:
				_fail("Android Generation 1 must include its app drawer launcher.")
				return
		elif generation_number == 2:
			if simulator.find_child("AndroidWeatherWidget", true, false) == null or simulator.find_child("AndroidAssistantWidget", true, false) == null:
				_fail("Android 8 Oreo must retain its two side-by-side Pixel widgets.")
				return
			if simulator.find_child("HomeAppGrid", true, false) == null or simulator.find_child("HomeSearchBar", true, false) == null or simulator.find_child("HomeAppDock", true, false) == null:
				_fail("Android 8 Oreo is missing its home grid, search field or dock.")
				return
		else:
			if simulator.find_child("PieHomeAtAGlance", true, false) == null or simulator.find_child("PieHomeWeather", true, false) == null:
				_fail("Android 9 Pie must render the Pixel Launcher At a Glance date and weather.")
				return
			var pie_home_grid := simulator.find_child("PieHomeAppGrid", true, false) as GridContainer
			var pie_dock := simulator.find_child("PieHomeDockIcons", true, false) as HBoxContainer
			if pie_home_grid == null or pie_home_grid.columns != 5 or pie_home_grid.get_child_count() < 8:
				_fail("Android 9 Pie home screen must render its five-column Pixel app grid.")
				return
			if simulator.find_child("PieHomeGoogleSearchBar", true, false) == null or pie_dock == null or pie_dock.get_child_count() != 5:
				_fail("Android 9 Pie must have the five-icon dock and Google search pill.")
				return
			if simulator.find_child("AndroidWeatherWidget", true, false) != null or simulator.find_child("AndroidAssistantWidget", true, false) != null:
				_fail("Android 9 Pie must not reuse the Oreo side-by-side widgets.")
		var expected_android_nav := "LollipopThreeButtonNavigation" if generation_number == 1 else "PieThreeButtonNavigation" if generation_number == 3 else "AndroidThreeButtonNavigation"
		var generation_navigation := simulator.find_child(expected_android_nav, true, false) as HBoxContainer
		if generation_navigation == null or generation_navigation.get_child_count() != 3:
			_fail("Every Android generation must display Recent, Home and Back navigation buttons.")
			return
		var expected_navigation_order := ["Overview", "Home", "Back"]
		for navigation_index in range(3):
			var navigation_button := generation_navigation.get_child(navigation_index) as Button
			if navigation_button == null or str(navigation_button.get("action_name")) != expected_navigation_order[navigation_index]:
				_fail("Android navigation buttons must follow the selected Pixel generation's button order.")
				return
		var expected_navigation_bar := "PieNavigationBar" if generation_number == 3 else "AndroidNavigationBar"
		var generation_navigation_bar := simulator.find_child(expected_navigation_bar, true, false) as PanelContainer
		var generation_navigation_style := generation_navigation_bar.get_theme_stylebox("panel") as StyleBoxFlat if generation_navigation_bar != null else null
		if generation_navigation_style == null or generation_navigation_style.bg_color.a > 0.01:
			_fail("Android navigation bar background must be transparent for every generation.")
			return
		if generation_number >= 2:
			var asset_app_name := "Photos" if generation_number == 2 else "Calendar"
			var asset_family := "oreo" if generation_number == 2 else "pie"
			var asset_tile := simulator.find_child("App_" + asset_app_name, true, false) as VBoxContainer
			var asset_button := asset_tile.find_child("Button", true, false) as Button if asset_tile != null else null
			var atlas_icon := asset_button.icon as AtlasTexture if asset_button != null else null
			if atlas_icon == null or atlas_icon.atlas == null or atlas_icon.atlas.resource_path != "res://assets/os/" + asset_family + "/icons.svg" or atlas_icon.region.size != Vector2(96.0, 96.0):
				_fail("Android generation %d did not load its own bundled app icon assets." % generation_number)
				return
			var expected_app_names := [
				"Phone", "Messages", "Camera", "Gallery", "Browser", "Music", "Calendar", "Settings",
				"Files", "Clock", "Maps", "Notes", "Contacts", "Email", "Calculator", "Weather",
				"Downloads", "Recorder", "Video", "Store", "Security", "Device Care", "Drive", "Photos",
				"Podcasts", "Tasks", "Wallet", "Compass", "Assistant", "Meet"
			]
			var generation_icon_regions := {}
			for expected_app_name in expected_app_names:
				var imported_app_icon := simulator.call("_load_android_generation_icon", expected_app_name) as AtlasTexture
				if imported_app_icon == null or imported_app_icon.atlas == null or imported_app_icon.atlas.resource_path != "res://assets/os/" + asset_family + "/icons.svg":
					_fail("Android generation %d is missing imported artwork for installed app: %s" % [generation_number, expected_app_name])
					return
				generation_icon_regions[str(imported_app_icon.region.position)] = true
			if generation_icon_regions.size() != expected_app_names.size():
				_fail("Android generation %d must provide 30 distinct imported app icon regions." % generation_number)
				return
		simulator.configure_os(generation_preview, "lock_screen")
		await process_frame
		if simulator.find_child(expected_android_nav, true, false) != null:
			_fail("Android lock screen must hide the three-button navigation bar.")
			return
		if generation_number == 2:
			for oreo_control_name in ["OreoLockScreen", "OreoLockScreenClockBlock", "LockScreenClock", "LockScreenDate", "OreoLockScreenNotifications", "OreoLockNotification_Messages", "OreoLockNotification_Calendar", "OreoAssistantShortcut", "OreoLockStatusGlyph", "OreoCameraShortcut", "OreoSwipeToUnlockHint"]:
				if simulator.find_child(oreo_control_name, true, false) == null:
					_fail("Android 8 Oreo Pixel lock screen is missing: " + oreo_control_name)
					return
			if simulator.find_child("LollipopLockScreen", true, false) != null or simulator.find_child("LockScreenShortcut_Flashlight", true, false) != null:
				_fail("Android 8 lock screen must not reuse Lollipop or add a flashlight shortcut.")
				return
			var oreo_clock := simulator.find_child("LockScreenClock", true, false) as Label
			var oreo_date := simulator.find_child("LockScreenDate", true, false) as Label
			var oreo_status_clock := simulator.find_child("StatusBarClock", true, false) as Label
			var oreo_assistant := simulator.find_child("OreoAssistantShortcut", true, false) as Button
			var oreo_camera := simulator.find_child("OreoCameraShortcut", true, false) as Button
			if oreo_clock == null or not oreo_clock.text.contains(":") or oreo_date == null or not oreo_date.text.contains(","):
				_fail("Oreo lock screen must show its 12-hour clock and Pixel-style date.")
				return
			if oreo_status_clock == null or oreo_status_clock.visible:
				_fail("Oreo lock screen must not duplicate the large clock with an extra status-bar time.")
				return
			if oreo_assistant == null or oreo_camera == null or not oreo_assistant.visible or oreo_assistant.custom_minimum_size.x < 44.0 or oreo_assistant.get_parent().get_index() >= oreo_camera.get_parent().get_index():
				_fail("Oreo lock shortcuts must show a full-size Assistant button left of Camera.")
				return
			var oreo_assistant_art := oreo_assistant.find_child("ImportedLockShortcutArtwork", true, false) as TextureRect
			var oreo_camera_art := oreo_camera.find_child("ImportedLockShortcutArtwork", true, false) as TextureRect
			var oreo_lock_art := simulator.find_child("ImportedLockStatusArtwork", true, false) as TextureRect
			var oreo_notification_art := simulator.find_child("OreoLockNotificationIcon_Messages", true, false) as TextureRect
			var oreo_assistant_atlas := oreo_assistant_art.texture as AtlasTexture if oreo_assistant_art != null else null
			if oreo_assistant_atlas == null or oreo_assistant_atlas.atlas.resource_path != "res://assets/os/oreo/icons.svg":
				_fail("Oreo Assistant shortcut must use its imported generation-specific app icon.")
				return
			if oreo_camera_art == null or oreo_camera_art.texture == null or oreo_camera_art.texture.resource_path != "res://assets/os/lockscreen/camera.svg":
				_fail("Oreo Camera shortcut must use the imported camera artwork.")
				return
			if oreo_lock_art == null or oreo_lock_art.texture == null or oreo_lock_art.texture.resource_path != "res://assets/os/lockscreen/lock.svg":
				_fail("Oreo lock indicator must use the imported lock artwork.")
				return
			var oreo_notification_atlas := oreo_notification_art.texture as AtlasTexture if oreo_notification_art != null else null
			if oreo_notification_atlas == null or oreo_notification_atlas.atlas.resource_path != "res://assets/os/oreo/icons.svg":
				_fail("Oreo notifications must use imported app icon artwork.")
				return
			var normalized_oreo_config: Dictionary = simulator.get("configuration")
			var oreo_lock_data: Dictionary = normalized_oreo_config["components"]["lock_screen"]
			for required_oreo_setting in ["show_time", "show_date", "show_notifications", "show_assistant_shortcut", "show_camera_shortcut"]:
				if not oreo_lock_data.has(required_oreo_setting):
					_fail("Android 8 lock configuration is missing: " + required_oreo_setting)
					return
			if oreo_lock_data.has("show_flashlight_shortcut"):
				_fail("Android 8 Pixel lock configuration must not inherit the Lollipop flashlight setting.")
				return
		elif generation_number == 3:
			for pie_control_name in ["PieLockScreen", "PieLockScreenClock", "PieLockScreenDate", "PieLockWeather", "PieLockBatteryInfo", "PieLockScreenNotifications", "PieLockNotification_Messages", "PieLockNotification_Calendar", "PieAssistantShortcut", "PieLockScreenShortcutCenterSpacer", "PieCameraShortcut", "PieSwipeToUnlockHint"]:
				if simulator.find_child(pie_control_name, true, false) == null:
					_fail("Android 9 Pie Pixel lock screen is missing: " + pie_control_name)
					return
			if simulator.find_child("OreoLockScreen", true, false) != null or simulator.find_child("LockScreenShortcut_Flashlight", true, false) != null:
				_fail("Android 9 Pie must use its own lock screen and must not reuse Oreo/Lollipop layouts.")
				return
			var pie_clock := simulator.find_child("PieLockScreenClock", true, false) as Label
			var pie_date := simulator.find_child("PieLockScreenDate", true, false) as Label
			var pie_status_clock := simulator.find_child("StatusBarClock", true, false) as Label
			if pie_clock == null or not pie_clock.text.contains(":") or pie_date == null or not pie_date.text.contains(","):
				_fail("Android 9 Pie lock screen must display a 12-hour clock and date.")
				return
			if pie_status_clock == null or pie_status_clock.visible:
				_fail("Android 9 Pie lock screen must not duplicate its large clock in the status bar.")
				return
			var pie_assistant := simulator.find_child("PieAssistantShortcut", true, false) as Button
			var pie_camera := simulator.find_child("PieCameraShortcut", true, false) as Button
			var pie_assistant_art := pie_assistant.find_child("ImportedLockShortcutArtwork", true, false) as TextureRect if pie_assistant != null else null
			var pie_camera_art := pie_camera.find_child("ImportedLockShortcutArtwork", true, false) as TextureRect if pie_camera != null else null
			var pie_notification_art := simulator.find_child("PieLockNotificationIcon_Messages", true, false) as TextureRect
			var pie_assistant_atlas := pie_assistant_art.texture as AtlasTexture if pie_assistant_art != null else null
			var pie_notification_atlas := pie_notification_art.texture as AtlasTexture if pie_notification_art != null else null
			if pie_assistant_atlas == null or pie_assistant_atlas.atlas.resource_path != "res://assets/os/pie/icons.svg":
				_fail("Pie Assistant shortcut must use its imported generation-specific app icon.")
				return
			if pie_camera_art == null or pie_camera_art.texture == null or pie_camera_art.texture.resource_path != "res://assets/os/lockscreen/camera.svg":
				_fail("Pie Camera shortcut must use the imported camera artwork.")
				return
			if not pie_assistant.visible or pie_assistant.custom_minimum_size.x < 44.0:
				_fail("Pie lock screen must display a full-size Assistant shortcut.")
				return
			if simulator.find_child("ImportedLockStatusArtwork", true, false) != null:
				_fail("Android 9 Pie must not display a fingerprint sensor or central lock glyph.")
			if pie_notification_atlas == null or pie_notification_atlas.atlas.resource_path != "res://assets/os/pie/icons.svg":
				_fail("Pie notifications must use imported app icon artwork.")
				return
			var normalized_pie_config: Dictionary = simulator.get("configuration")
			var pie_lock_data: Dictionary = normalized_pie_config["components"]["lock_screen"]
			for required_pie_setting in ["show_time", "show_date", "show_notifications", "show_assistant_shortcut", "show_camera_shortcut", "show_weather", "show_battery"]:
				if not pie_lock_data.has(required_pie_setting):
					_fail("Android 9 Pie lock configuration is missing: " + required_pie_setting)
					return
		simulator.set_component_view("pin_input")
		await process_frame
		var pin_navigation := simulator.find_child(expected_android_nav, true, false) as HBoxContainer
		if pin_navigation == null or pin_navigation.get_child_count() != 3:
			_fail("Android PIN entry must reserve the same three navigation positions while displaying only Back.")
			return
		var pin_back_button := pin_navigation.get_child(2) as Button
		if pin_back_button == null or pin_back_button.get_index() != 2 or str(pin_back_button.get("action_name")) != "Back":
			_fail("Android PIN entry Back button must occupy the bottom-right, rightmost three-button navigation position.")
			return
		if pin_navigation.get_child(0) is Button or pin_navigation.get_child(1) is Button:
			_fail("Android PIN entry must keep Home and Overview hidden while reserving their navigation positions.")
			return
		var pin_navigation_footer := pin_navigation.get_parent().get_parent() as VBoxContainer
		var pin_shell := pin_navigation_footer.get_parent() as VBoxContainer if pin_navigation_footer != null else null
		if pin_navigation_footer == null or pin_shell == null or pin_shell.get_child(pin_shell.get_child_count() - 1) != pin_navigation_footer:
			_fail("PIN navigation footer must remain attached to the bottom of the PIN screen.")
			return
		pin_back_button.pressed.emit()
		await process_frame
		if simulator.get("active_component") != "lock_screen":
			_fail("The bottom-right PIN Back button did not return to the lock screen.")
			return
		simulator.configure_os(generation_preview, "home_screen")
		await process_frame
		if simulator.find_child(expected_android_nav, true, false) == null:
			_fail("Android navigation bar did not return after leaving the lock/PIN screens.")
			return
		if generation_number in [2, 3]:
			var drawer_touch := InputEventScreenTouch.new()
			drawer_touch.index = 0
			drawer_touch.position = Vector2(72, 300)
			drawer_touch.pressed = true
			simulator.call("_input", drawer_touch)
			var drawer_drag := InputEventScreenDrag.new()
			drawer_drag.index = 0
			drawer_drag.position = Vector2(72, 225)
			drawer_drag.relative = Vector2(0, -75)
			simulator.call("_input", drawer_drag)
			await process_frame
			if simulator.get("active_component") != "app_drawer":
				_fail("Android generation %d upward home swipe did not open the app drawer." % generation_number)
				return
			simulator.configure_os(generation_preview, "home_screen")
			await process_frame
		if generation_number == 1:
			simulator.configure_os(generation_preview, "home_screen")
			await process_frame
			_simulate_touch_swipe(simulator, Vector2(60, 2), Vector2(60, 75), 110)
			await process_frame
			if simulator.find_child("OSGestureOverlay_notifications", true, false) == null or simulator.find_child("LollipopNotificationHeader", true, false) == null:
				_fail("Android 5 notification shade did not render its Lollipop header.")
				return
			if simulator.find_child("LollipopNotification_Messages", true, false) == null or simulator.find_child("CloseGestureOverlayButton", true, false) != null:
				_fail("Android 5 notification cards are missing or an unwanted close button was added.")
				return
			var notification_overlay := simulator.find_child("OSGestureOverlay_notifications", true, false) as Control
			var notification_mask := simulator.find_child("LollipopShadeScreenCornerMask", true, false) as Control
			if notification_overlay == null or not notification_overlay.clip_contents or notification_mask == null:
				_fail("Lollipop notification shade must be clipped to the rounded phone screen.")
				return
			if not bool(notification_mask.get("mask_bottom_corners")) == false or notification_mask.z_index < 100:
				_fail("Lollipop shade corner mask must preserve the top screen radius without rounding the navigation edge.")
				return
			var notification_app_label := simulator.find_child("LollipopNotificationApp_Messages", true, false) as Label
			var notification_message_label := simulator.find_child("LollipopNotificationMessage_Messages", true, false) as Label
			var notification_icon_label := simulator.find_child("LollipopNotificationIcon_Messages", true, false) as Label
			if notification_app_label == null or notification_app_label.text != "Messages" or notification_app_label.custom_minimum_size.y < 14:
				_fail("Lollipop notification card must show a properly sized app title.")
				return
			if notification_message_label == null or notification_message_label.text.is_empty() or notification_message_label.custom_minimum_size.y < 16:
				_fail("Lollipop notification card must show its message text.")
				return
			if notification_icon_label == null or notification_icon_label.text != "M":
				_fail("Lollipop notification card must show its app icon glyph.")
				return
			simulator.call("_handle_system_gesture", Vector2(72, 180), Vector2(72, 240), 110)
			await process_frame
			if simulator.find_child("LollipopQuickSettingsHeader", true, false) == null or simulator.find_child("LollipopQuickSettingsGrid", true, false) == null or simulator.find_child("LollipopBrightnessSlider", true, false) == null:
				_fail("Expanded Android 5 Quick Settings is missing its header, brightness slider or icon tiles.")
				return
			var quick_settings_overlay := simulator.find_child("OSGestureOverlay_control_center", true, false) as Control
			var quick_settings_mask := simulator.find_child("LollipopShadeScreenCornerMask", true, false) as Control
			if quick_settings_overlay == null or not quick_settings_overlay.clip_contents or quick_settings_mask == null:
				_fail("Lollipop Quick Settings must remain inside the rounded phone screen boundary.")
				return
			if simulator.find_child("CloseGestureOverlayButton", true, false) != null:
				_fail("Android 5 Quick Settings must dismiss by system gestures/navigation, not an X button.")
				return
			var wifi_tile := simulator.find_child("LollipopQuickTile_Wi-Fi", true, false) as Button
			if wifi_tile == null:
				_fail("Android 5 Quick Settings Wi-Fi tile is missing.")
				return
			var wifi_icon_label := simulator.find_child("LollipopQuickTileIcon_Wi-Fi", true, false) as Label
			var wifi_title_label := simulator.find_child("LollipopQuickTileLabel_Wi-Fi", true, false) as Label
			var wifi_tile_style := wifi_tile.get_theme_stylebox("normal") as StyleBoxFlat if wifi_tile != null else null
			if wifi_icon_label == null or wifi_icon_label.text.is_empty() or wifi_title_label == null or wifi_title_label.text != "Wi-Fi":
				_fail("Lollipop Quick Settings tile must visibly contain its icon and label.")
				return
			if wifi_tile.custom_minimum_size.y < 68 or wifi_tile_style == null or wifi_tile_style.bg_color.a < 0.9:
				_fail("Lollipop Quick Settings tiles must have visible tile surfaces and a reliable height.")
				return
			var wifi_before := bool(simulator.get("_quick_setting_states").get("Wi-Fi", false))
			wifi_tile.button_pressed = not wifi_before
			wifi_tile.toggled.emit(not wifi_before)
			if bool(simulator.get("_quick_setting_states").get("Wi-Fi", wifi_before)) == wifi_before:
				_fail("Quick Settings tile did not retain its toggled state.")
				return
			var lollipop_back := simulator.find_child("LollipopNavigationBack", true, false) as Button
			var lollipop_home := simulator.find_child("LollipopNavigationHome", true, false) as Button
			var lollipop_overview := simulator.find_child("LollipopNavigationOverview", true, false) as Button
			if lollipop_back == null or lollipop_home == null or lollipop_overview == null:
				_fail("The Lollipop navigation row is missing one or more working controls.")
				return
			lollipop_back.pressed.emit()
			await process_frame
			if simulator.find_child("OSGestureOverlay_control_center", true, false) != null:
				_fail("Android Back button did not dismiss the expanded Lollipop Quick Settings panel.")
				return
			_simulate_touch_swipe(simulator, Vector2(60, 2), Vector2(60, 75), 110)
			await process_frame
			lollipop_home = simulator.find_child("LollipopNavigationHome", true, false) as Button
			lollipop_home.pressed.emit()
			await process_frame
			if simulator.get("active_component") != "home_screen" or simulator.find_child("OSGestureOverlay_notifications", true, false) != null:
				_fail("Android Home button did not close the notification shade and jump directly home.")
				return
			lollipop_overview = simulator.find_child("LollipopNavigationOverview", true, false) as Button
			lollipop_overview.pressed.emit()
			await process_frame
			if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null:
				_fail("Android Overview button did not open the Lollipop task overview.")
				return
			lollipop_back = simulator.find_child("LollipopNavigationBack", true, false) as Button
			lollipop_back.pressed.emit()
			await process_frame
			if simulator.find_child("OSGestureOverlay_recent_apps", true, false) != null:
				_fail("Android Back button did not close the Lollipop Overview panel.")
				return
	var lollipop_panel_test_config := ProceduralEngineScript.generate_os(8201, 1)
	simulator.configure_os(lollipop_panel_test_config, "notifications")
	await process_frame
	var notification_preview := simulator.find_child("LollipopNotificationPreview", true, false)
	var preview_message_label := simulator.find_child("LollipopNotificationMessage_Messages", true, false) as Label
	if notification_preview == null or preview_message_label == null or preview_message_label.text != "A new message is waiting":
		_fail("Android 5 Notification Panel preview is missing visible notification content.")
		return
	simulator.configure_os(lollipop_panel_test_config, "control_center")
	await process_frame
	var control_center_preview := simulator.find_child("LollipopControlCenterPreview", true, false)
	var preview_wifi_tile := simulator.find_child("LollipopQuickTile_Wi-Fi", true, false) as Button
	var preview_wifi_label := simulator.find_child("LollipopQuickTileLabel_Wi-Fi", true, false) as Label
	if control_center_preview == null or preview_wifi_tile == null or preview_wifi_label == null or preview_wifi_label.text != "Wi-Fi":
		_fail("Android 5 Control Center preview is missing its visible Quick Settings tiles.")
		return

	# Restore the shared test configuration to Android after the iOS component checks.
	generated["components"]["home_screen"]["layout_style"] = "android_pixel"
	generated = ProceduralEngineScript.normalize_os(generated)
	simulator.configure_os(generated, "home_screen")
	await process_frame

	# Android keeps three-button navigation; bottom-edge swipes must not replace it.
	_simulate_touch_swipe(simulator, Vector2(60, 2), Vector2(60, 70), 100)
	await process_frame
	if simulator.find_child("OSGestureOverlay_notifications", true, false) == null:
		_fail("Top-edge swipe did not open the Android notification shade.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 180), Vector2(72, 235), 100)
	await process_frame
	var android_expanded_grid := simulator.find_child("OreoExpandedQuickSettingsGrid", true, false) as GridContainer
	if android_expanded_grid == null or android_expanded_grid.get_child_count() != 9 or simulator.find_child("OreoBrightnessSlider", true, false) == null:
		_fail("Second downward pull did not expand the full Android 8 Quick Settings panel.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 235), Vector2(72, 150), 100)
	await process_frame
	if simulator.find_child("OSGestureOverlay_control_center", true, false) != null:
		_fail("Swipe-up gesture did not collapse the expanded Quick Settings shade.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 358), Vector2(72, 280), 120)
	await process_frame
	if simulator.get("active_component") != "home_screen":
		_fail("Android bottom swipe must not replace the three-button navigation system.")
		return
	var android_overview := simulator.find_child("AndroidNavigationOverview", true, false) as Button
	var android_home := simulator.find_child("AndroidNavigationHome", true, false) as Button
	var android_back_button := simulator.find_child("AndroidNavigationBack", true, false) as Button
	if android_overview == null or android_home == null or android_back_button == null:
		_fail("Android Back, Home and Overview navigation buttons must all exist.")
		return
	for navigation_button in [android_back_button, android_home, android_overview]:
		if navigation_button.mouse_filter != Control.MOUSE_FILTER_STOP or navigation_button.custom_minimum_size.x < 30.0 or navigation_button.custom_minimum_size.y < 40.0:
			_fail("Android navigation buttons must have active mouse input and a reliable touch target.")
			return
	simulator.call("_on_app_pressed", "Settings")
	simulator.call("_on_app_pressed", "Messages")
	android_overview.pressed.emit()
	await process_frame
	var overview_overlay := simulator.find_child("OSGestureOverlay_recent_apps", true, false) as Control
	var overview_background := simulator.find_child("LollipopOverviewBackground", true, false) as ColorRect
	var overview_search := simulator.find_child("LollipopOverviewSearchBar", true, false) as PanelContainer
	var messages_card := simulator.find_child("LollipopOverviewTask_Messages", true, false) as Button
	var settings_card := simulator.find_child("LollipopOverviewTask_Settings", true, false) as Button
	if simulator.get("active_component") != "home_screen" or overview_overlay == null:
		_fail("Android Overview button did not open the Recent Apps overview.")
		return
	if overview_background == null or overview_search == null or messages_card == null or settings_card == null:
		_fail("Android 5 Overview must show the Google search bar and overlapping app task cards.")
		return
	if overview_overlay == null or not overview_overlay.clip_contents or overview_background.color.a > 0.10:
		_fail("Android 5 Overview must preserve the wallpaper behind a screen-clipped task stack.")
		return
	if simulator.find_child("LollipopOverviewTitle", true, false) != null or simulator.find_child("LollipopOverviewClearAll", true, false) != null:
		_fail("Stock Android 5 Overview must not show a generic heading or a Clear All control.")
		return
	if messages_card.position.y <= settings_card.position.y or messages_card.z_index <= settings_card.z_index:
		_fail("The newest Android 5 task must sit in front of older cards in the bottom of the stack.")
		return
	if messages_card.size.x < float(simulator.size.x) * 0.90 or messages_card.size.y < float(simulator.size.y) * 0.60:
		_fail("Android 5 Overview task cards must be large, near-full-width app snapshots.")
		return
	var messages_header := simulator.find_child("LollipopOverviewCardHeader_Messages", true, false) as ColorRect
	var messages_icon := simulator.find_child("LollipopOverviewAppIcon_Messages", true, false) as Label
	var messages_close := simulator.find_child("DismissOverviewTask_Messages", true, false) as Button
	var overview_content := simulator.find_child("OSComponentContent", true, false) as Control
	if messages_header == null or messages_header.color != Color("#009688") or messages_icon == null or messages_icon.text.is_empty() or messages_close == null:
		_fail("Android 5 task cards must include the app-coloured title strip, app icon and individual close control.")
		return
	if overview_content == null or overview_content.visible:
		_fail("The launcher app grid must be hidden behind the Android 5 Overview task stack.")
		return
	var overview_navigation_footer := simulator.find_child("LollipopOverviewNavigationFooter", true, false) as Control
	var overview_navigation_bar := simulator.find_child("AndroidNavigationBar", true, false) as Control
	var overview_recent := simulator.find_child("LollipopNavigationOverview", true, false) as Button
	var overview_home := simulator.find_child("LollipopNavigationHome", true, false) as Button
	var overview_back := simulator.find_child("LollipopNavigationBack", true, false) as Button
	if overview_navigation_footer == null or overview_navigation_bar == null or overview_navigation_bar.visible:
		_fail("Android 5 Overview must display its dedicated navigation footer above the task stack.")
		return
	if overview_recent == null or overview_home == null or overview_back == null or not overview_recent.visible or not overview_home.visible or not overview_back.visible:
		_fail("All three Android navigation buttons must remain visible in Recent Apps.")
		return
	# Repeated card dismissals must rebuild only the task deck, not restore
	# the launcher beneath it or strand the navigation footer.
	simulator.call("_dismiss_overview_task", "Messages")
	await process_frame
	var remaining_overview := simulator.find_child("OSGestureOverlay_recent_apps", true, false) as Control
	var remaining_settings_card := simulator.find_child("LollipopOverviewTask_Settings", true, false) as Button
	if remaining_overview == null:
		_fail("Dismissing the first recent app removed the Overview overlay.")
		return
	if remaining_settings_card == null:
		_fail("Dismissing Messages failed to rebuild the remaining Settings task card.")
		return
	simulator.call("_dismiss_overview_task", "Settings")
	await process_frame
	overview_content = simulator.find_child("OSComponentContent", true, false) as Control
	overview_navigation_footer = simulator.find_child("LollipopOverviewNavigationFooter", true, false) as Control
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or overview_content == null or overview_content.visible:
		_fail("Dismissing a second recent app must not remove the Overview screen or reveal the launcher.")
		return
	if overview_navigation_footer == null or simulator.find_child("LollipopNavigationOverview", true, false) == null or simulator.find_child("LollipopNavigationHome", true, false) == null or simulator.find_child("LollipopNavigationBack", true, false) == null:
		_fail("All three navigation buttons must remain available after repeated recent-app dismissals.")
		return
	var android_back := overview_back
	android_back.pressed.emit()
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) != null:
		_fail("Android Back button did not close the Recent Apps overview.")
		return
	overview_content = simulator.find_child("OSComponentContent", true, false) as Control
	if overview_content == null or not overview_content.visible:
		_fail("Closing Android 5 Overview must restore the launcher content.")
		return
	var rounded_mask := simulator.find_child("OSScreenRoundedCornerMask", true, false) as Control
	if rounded_mask == null or not is_equal_approx(float(rounded_mask.get("corner_radius")), 22.0):
		_fail("All four display corners must use the same rounded screen mask.")
		return

	# Android 9 Pie owns independent screens and interactions; Oreo and Lollipop stay unchanged.
	var pie_test_config := ProceduralEngineScript.generate_os(8303, 3)
	simulator.configure_os(pie_test_config, "lock_screen")
	await process_frame
	for pie_lock_name in ["PieLockScreen", "PieLockScreenClock", "PieLockScreenDate", "PieLockWeather", "PieLockBatteryInfo", "PieLockNotification_Messages", "PieLockNotification_Calendar", "PieAssistantShortcut", "PieCameraShortcut"]:
		if simulator.find_child(pie_lock_name, true, false) == null:
			_fail("Android 9 Pie lock screen is missing: " + pie_lock_name)
			return
	var pie_lock_status_clock := simulator.find_child("StatusBarClock", true, false) as Label
	if pie_lock_status_clock == null or pie_lock_status_clock.visible:
		_fail("Android 9 Pie lock screen should show only its large lock-screen clock.")
		return

	# Unlock swipe opens Pie's PIN keypad, then a valid PIN returns to the home screen.
	simulator.call("_handle_system_gesture", Vector2(72, 180), Vector2(72, 105), 140)
	await process_frame
	if simulator.find_child("PiePINInputScreen", true, false) == null:
		_fail("Android 9 Pie lock screen swipe did not open its dedicated PIN input screen.")
		return
	for pie_digit in ["1", "2", "3", "4"]:
		var pie_key := simulator.find_child("PINKey_" + pie_digit, true, false) as Button
		if pie_key == null:
			_fail("Android 9 Pie PIN keypad is missing digit " + pie_digit + ".")
			return
		pie_key.pressed.emit()
		await process_frame
	if simulator.get("active_component") != "home_screen":
		_fail("Android 9 Pie PIN 1234 did not unlock to its Pixel home screen.")
		return

	# Pie app drawer uses a search field, suggested apps and a vertical all-apps list.
	simulator.configure_os(pie_test_config, "app_drawer")
	await process_frame
	var pie_drawer_search := simulator.find_child("PieAppDrawerSearchField", true, false) as LineEdit
	var pie_drawer_grid := simulator.find_child("PieAppDrawerGrid", true, false) as GridContainer
	if pie_drawer_search == null or pie_drawer_grid == null or pie_drawer_grid.columns != 5:
		_fail("Android 9 Pie app drawer must render its search field and five-column apps grid.")
		return
	if simulator.find_child("PieSuggestedAppsRow", true, false) == null or simulator.find_child("PieAppDrawerAllAppsHeading", true, false) == null:
		_fail("Android 9 Pie app drawer is missing suggested apps or the All apps heading.")
		return
	var pie_drawer_initial_count := pie_drawer_grid.get_child_count()
	pie_drawer_search.text_changed.emit("Calendar")
	await process_frame
	if pie_drawer_grid.get_child_count() == 0 or pie_drawer_grid.get_child_count() >= pie_drawer_initial_count:
		_fail("Android 9 Pie app drawer search did not filter the installed apps.")
		return
	pie_drawer_search.text_changed.emit("")
	await process_frame

	# Dedicated notification and expanded Quick Settings previews.
	simulator.configure_os(pie_test_config, "notifications")
	await process_frame
	if simulator.find_child("PieNotificationPreview", true, false) == null or simulator.find_child("PieNotification_Messages", true, false) == null or simulator.find_child("PieNotificationQuickSettingsGrid", true, false) == null:
		_fail("Android 9 Pie Notification Panel preview is incomplete.")
		return
	simulator.configure_os(pie_test_config, "control_center")
	await process_frame
	var pie_control_grid := simulator.find_child("PieExpandedQuickSettingsGrid", true, false) as GridContainer
	if simulator.find_child("PieControlCenterPreview", true, false) == null or pie_control_grid == null or pie_control_grid.get_child_count() != 9 or simulator.find_child("PieBrightnessSlider", true, false) == null:
		_fail("Android 9 Pie expanded Quick Settings preview must show nine circular tiles and brightness.")
		return
	var pie_preview_wifi := simulator.find_child("PieQuickTile_Wi-Fi", true, false) as Button
	if pie_preview_wifi == null:
		_fail("Android 9 Pie Quick Settings is missing its Wi-Fi toggle.")
		return

	# Exercise the real two-stage pull-down: notification shade first, full Quick Settings second.
	simulator.configure_os(pie_test_config, "home_screen")
	await process_frame
	simulator.call("_handle_system_gesture", Vector2(72, 2), Vector2(72, 75), 120)
	await process_frame
	var pie_notification_overlay := simulator.find_child("OSGestureOverlay_notifications", true, false) as Control
	var pie_notification_grid := simulator.find_child("PieNotificationQuickSettingsGrid", true, false) as GridContainer
	if pie_notification_overlay == null or pie_notification_grid == null or pie_notification_grid.get_child_count() != 6 or simulator.find_child("PieNotification_Messages", true, false) == null:
		_fail("Android 9 Pie first pull must show six Quick Settings shortcuts and notification cards.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 180), Vector2(72, 235), 120)
	await process_frame
	var pie_expanded_overlay := simulator.find_child("OSGestureOverlay_control_center", true, false) as Control
	var pie_expanded_grid := simulator.find_child("PieExpandedQuickSettingsGrid", true, false) as GridContainer
	if pie_expanded_overlay == null or pie_expanded_grid == null or pie_expanded_grid.get_child_count() != 9 or simulator.find_child("PieBrightnessSlider", true, false) == null:
		_fail("Second Android 9 Pie pull must expand to all nine Quick Settings tiles and brightness.")
		return
	var pie_wifi_toggle := simulator.find_child("PieQuickTile_Wi-Fi", true, false) as Button
	var pie_wifi_before := bool(simulator.get("_quick_setting_states").get("Wi-Fi", false))
	if pie_wifi_toggle == null:
		_fail("Android 9 Pie expanded panel Wi-Fi tile is missing.")
		return
	pie_wifi_toggle.button_pressed = not pie_wifi_before
	pie_wifi_toggle.toggled.emit(not pie_wifi_before)
	if bool(simulator.get("_quick_setting_states").get("Wi-Fi", pie_wifi_before)) == pie_wifi_before:
		_fail("Android 9 Pie Quick Settings tile did not retain its toggled state.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 235), Vector2(72, 150), 120)
	await process_frame
	if simulator.find_child("OSGestureOverlay_control_center", true, false) != null:
		_fail("Swipe-up did not collapse Android 9 Pie Quick Settings.")
		return

	# Pixel Pie Overview is a horizontal task carousel, and swiping up dismisses cards.
	simulator.set("_recent_app_names", [])
	simulator.call("_on_app_pressed", "Settings")
	simulator.call("_on_app_pressed", "Messages")
	var pie_overview_button := simulator.find_child("PieNavigationOverview", true, false) as Button
	if pie_overview_button == null:
		_fail("Android 9 Pie is missing its Overview navigation button.")
		return
	pie_overview_button.pressed.emit()
	await process_frame
	var pie_overview := simulator.find_child("OSGestureOverlay_recent_apps", true, false) as Control
	var pie_carousel := simulator.find_child("PieRecentAppsCarousel", true, false) as ScrollContainer
	var pie_messages_card := simulator.find_child("PieRecentAppsCard_Messages", true, false) as Button
	var pie_settings_card := simulator.find_child("PieRecentAppsCard_Settings", true, false) as Button
	if pie_overview == null or pie_carousel == null or pie_messages_card == null or pie_settings_card == null:
		_fail("Android 9 Pie Overview must show horizontally scrollable app snapshot cards.")
		return
	if pie_carousel.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO or pie_carousel.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("Android 9 Pie Recent Apps must use a horizontal, not vertical, task carousel.")
		return
	if simulator.find_child("PieOverviewNavigationFooter", true, false) == null or simulator.find_child("PieOverviewNavigationBack", true, false) == null or simulator.find_child("PieOverviewNavigationHome", true, false) == null or simulator.find_child("PieOverviewNavigationOverview", true, false) == null:
		_fail("Android 9 Pie Recent Apps must keep all three navigation buttons visible.")
		return
	var pie_original_navigation := simulator.find_child("PieNavigationBar", true, false) as Control
	var pie_home_content := simulator.find_child("OSComponentContent", true, false) as Control
	if pie_original_navigation == null or pie_original_navigation.visible or pie_home_content == null or pie_home_content.visible:
		_fail("Pie Overview must place the navigation footer above cards and hide the launcher underneath.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 250), Vector2(72, 180), 130)
	await process_frame
	if simulator.find_child("PieRecentAppsCard_Messages", true, false) != null or simulator.find_child("PieRecentAppsCard_Settings", true, false) == null:
		_fail("Swiping a Pie recent-app card upward must dismiss only that task.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 250), Vector2(72, 180), 130)
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or simulator.find_child("PieRecentAppsEmptyState", true, false) == null:
		_fail("Dismissing the final Pie recent app must leave the Overview surface, not exit it.")
		return
	var pie_back_button := simulator.find_child("PieOverviewNavigationBack", true, false) as Button
	if pie_back_button == null:
		_fail("Pie Overview lost its Back navigation button after dismissing tasks.")
		return
	pie_back_button.pressed.emit()
	await process_frame
	pie_original_navigation = simulator.find_child("PieNavigationBar", true, false) as Control
	pie_home_content = simulator.find_child("OSComponentContent", true, false) as Control
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) != null or pie_original_navigation == null or not pie_original_navigation.visible or pie_home_content == null or not pie_home_content.visible:
		_fail("Closing Pie Overview must restore the original Pixel home screen and navigation bar.")
		return

	simulator.configure_os(generated, "home_screen")
	await process_frame
	await process_frame
	if simulator.find_child("OSProceduralWallpaper", true, false) == null:
		_fail("Simulator did not render its procedural OS wallpaper.")
		return
	var compact_grid := simulator.find_child("HomeAppGrid", true, false) as GridContainer
	if compact_grid == null or compact_grid.columns != 4:
		_fail("Approved Android home-screen app row must retain its four-column arrangement.")
		return
	var home_dock := simulator.find_child("HomeAppDock", true, false)
	var home_content := simulator.find_child("OSComponentContent", true, false)
	if home_dock == null or home_dock.get_parent().name != "OSNavigationFooter":
		_fail("Home dock is not anchored in the fixed navigation footer.")
		return
	if simulator.find_child("OSComponentViewport", true, false) != null or (home_content != null and home_content.is_ancestor_of(home_dock)):
		_fail("Home screen content must remain fixed-height with its dock outside the content area.")
		return
	var dock_icons := simulator.find_child("HomeAppDockIcons", true, false) as HBoxContainer
	if dock_icons == null or dock_icons.get_child_count() != 4:
		_fail("Home dock did not render all four pinned app icons.")
		return
	var horizontal_app_label := simulator.find_child("AppLabel_Photos", true, false) as Label
	if horizontal_app_label == null or horizontal_app_label.autowrap_mode != TextServer.AUTOWRAP_OFF or absf(horizontal_app_label.rotation) > 0.001:
		_fail("App labels are not kept horizontal on narrow phone previews.")
		return
	simulator_host.size = Vector2(190.0, 360.0)
	await process_frame
	await process_frame
	var wide_grid := simulator.find_child("HomeAppGrid", true, false) as GridContainer
	if wide_grid == null or wide_grid.columns != 4 or wide_grid.get_child_count() != 4:
		_fail("Layout 1 must keep its approved four-app row at wider phone widths.")
		return
	simulator_host.size = Vector2(145.0, 360.0)
	await process_frame
	await process_frame
	for component in ProceduralEngineScript.COMPONENTS:
		var component_id := str(component["id"])
		simulator.set_component_view(component_id)
		await process_frame
		var content_node := simulator.find_child("OSComponentContent", true, false)
		if content_node == null:
			_fail("Simulator failed to render component: " + component_id)
			return
		if content_node.get_child_count() == 0:
			_fail("Simulator rendered an empty component: " + component_id)
			return
		if component_id == "control_center":
			var active_generation := int(simulator.get("configuration").get("generation", 1))
			if active_generation == 2:
				var quick_grid := simulator.find_child("OreoExpandedQuickSettingsGrid", true, false) as GridContainer
				if quick_grid == null or quick_grid.get_child_count() != 9 or simulator.find_child("OreoBrightnessSlider", true, false) == null or simulator.find_child("OreoControlCenterPreview", true, false) == null:
					_fail("Android 8 Control Center must render its nine Oreo Quick Settings tiles and brightness slider.")
					return
			elif active_generation == 3:
				var quick_grid := simulator.find_child("PieExpandedQuickSettingsGrid", true, false) as GridContainer
				if quick_grid == null or quick_grid.get_child_count() != 9 or simulator.find_child("PieBrightnessSlider", true, false) == null or simulator.find_child("PieControlCenterPreview", true, false) == null:
					_fail("Android 9 Control Center must render its nine Pie Quick Settings tiles and brightness slider.")
					return
			else:
				var quick_grid := simulator.find_child("QuickSettingsGrid", true, false) as GridContainer
				if quick_grid == null or quick_grid.get_child_count() < 12:
					_fail("Control Center did not render its expanded quick-settings tile set.")
					return
				if simulator.find_child("ControlCenterMediaCard", true, false) == null or simulator.find_child("ControlSlider_Brightness", true, false) == null:
					_fail("Control Center is missing its media card or styled brightness control.")
					return
		if component_id == "app_drawer":
			var drawer_data: Dictionary = simulator.get("configuration").get("components", {}).get("app_drawer", {})
			drawer_data["layout"] = "alphabetical"
			drawer_data["scroll_direction"] = "vertical"
			var drawer_config: Dictionary = simulator.get("configuration").duplicate(true)
			drawer_config["components"]["app_drawer"] = drawer_data
			simulator.update_configuration(drawer_config)
			await process_frame
			var search_field := simulator.find_child("AppDrawerSearchField", true, false) as LineEdit
			var legacy_drawer_grid := simulator.find_child("AppDrawerGrid", true, false) as GridContainer
			if search_field == null or legacy_drawer_grid == null:
				_fail("App Drawer search field or icon grid was not attached to the visible UI tree.")
				return
			if legacy_drawer_grid.get_child_count() != 30:
				_fail("App Drawer did not render all 30 installed applications.")
				return
			search_field.text_changed.emit("Settings")
			await process_frame
			if legacy_drawer_grid.get_child_count() != 1:
				_fail("App Drawer search did not filter the installed applications.")
				return
			search_field.text_changed.emit("")
			await process_frame
			drawer_config["components"]["app_drawer"]["scroll_direction"] = "horizontal"
			simulator.update_configuration(drawer_config)
			await process_frame
			var horizontal_viewport := simulator.find_child("AppDrawerViewport", true, false) as ScrollContainer
			var horizontal_grid := simulator.find_child("AppDrawerGrid", true, false) as GridContainer
			if horizontal_viewport == null or horizontal_grid == null or horizontal_viewport.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO or horizontal_grid.columns != 30:
				_fail("Generated horizontal App Drawer scrolling was not applied.")
				return
		if component_id == "wallpapers":
			var wallpaper_preview := simulator.find_child("WallpaperStylePreview", true, false) as Control
			if wallpaper_preview == null or wallpaper_preview.custom_minimum_size.y < 150.0:
				_fail("Wallpaper preview did not render at the upgraded preview size.")
				return
	root.remove_child(simulator_host)
	simulator_host.free()
	await process_frame

	var worksite := WorksiteScene.instantiate()
	root.add_child(worksite)
	await process_frame
	var worksite_preview := worksite.find_child("GeneratedOSPreviewSimulator", true, false)
	if worksite_preview == null:
		_fail("OS creation worksite did not mount the generated simulator screen.")
		return
	var worksite_root := worksite.find_child("OSWorksiteRoot", true, false) as Control
	var worksite_back_button := worksite.find_child("OSWizardBackIconButton", true, false) as Button
	var worksite_next_button := worksite.find_child("OSNextStepIconButton", true, false) as Button
	if worksite_root == null or worksite_back_button == null or worksite_next_button == null:
		_fail("Worksite must create its independent bottom navigation buttons on the main root.")
		return
	if worksite_back_button.get_parent() != worksite_root or worksite_next_button.get_parent() != worksite_root:
		_fail("Worksite bottom arrows must be direct root children, like the independent top controls.")
		return
	if worksite.find_child("OSWorksiteNavigationRoot", true, false) != null or worksite.find_child("OSWorksiteBottomBar", true, false) != null:
		_fail("Worksite must not create a full-width bottom navigation overlay or bar.")
		return
	if worksite_back_button.mouse_filter != Control.MOUSE_FILTER_STOP or worksite_next_button.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Worksite Back and Next arrow buttons must remain individually clickable.")
		return
	if worksite_back_button.anchor_top != 1.0 or worksite_next_button.anchor_top != 1.0 or worksite_back_button.anchor_right != 0.0 or worksite_next_button.anchor_left != 1.0:
		_fail("Worksite bottom arrows must be independently anchored to the bottom-left and bottom-right corners.")
		return
	if worksite_preview.find_child("OSProceduralWallpaper", true, false) == null:
		_fail("OS creation worksite preview did not use the procedural OS wallpaper.")
		return
	var power_button := worksite.find_child("OSPowerButton", true, false) as Button
	var screen_frame := worksite.find_child("OSPortraitScreenFrame", true, false) as Control
	var boot_overlay := worksite.find_child("OSBootLoaderOverlay", true, false) as Control
	if power_button == null or screen_frame == null or power_button.is_ancestor_of(screen_frame) or screen_frame.is_ancestor_of(power_button):
		_fail("Boot power button must be positioned outside the phone screen, beside it.")
		return
	if boot_overlay == null or boot_overlay.visible:
		_fail("Phone screen should remain off until the separate power button is pressed.")
		return
	var selection_controls := worksite.find_child("OSSelectionControls", true, false) as VBoxContainer
	if selection_controls == null or worksite.find_child("BootLoaderOnlyControls", true, false) != null:
		_fail("Step 1 must begin with Layout and Generation selection, not Boot Loader.")
		return
	var initial_step_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if initial_step_label == null or initial_step_label.text != "STEP 1 / 8":
		_fail("OS selection must be explicitly identified as Step 1 of 8.")
		return
	if left_power_region_is_visible(worksite):
		_fail("The power control must stay hidden until the Boot step.")
		return
	var layout_selector := worksite.find_child("HomeScreenLayoutSelector", true, false) as HBoxContainer
	var layout_label := worksite.find_child("HomeScreenLayoutValueLabel", true, false) as Label
	var layout_minus := worksite.find_child("DecreaseHomeScreenLayoutButton", true, false) as Button
	var layout_plus := worksite.find_child("IncreaseHomeScreenLayoutButton", true, false) as Button
	var generation_selector := worksite.find_child("OSGenerationSelector", true, false) as HBoxContainer
	var generation_label := worksite.find_child("OSGenerationValueLabel", true, false) as Label
	var generation_minus := worksite.find_child("DecreaseOSGenerationButton", true, false) as Button
	var generation_plus := worksite.find_child("IncreaseOSGenerationButton", true, false) as Button
	var generation_description := worksite.find_child("OSGenerationDescription", true, false) as Label
	if layout_selector == null or layout_label == null or layout_label.text != "LAYOUT 1" or layout_minus == null or layout_plus == null:
		_fail("Step 1 must expose the three OS layouts with Android selected as Layout 1.")
		return
	if generation_selector == null or generation_label == null or generation_label.text != "GENERATION 02" or generation_minus == null or generation_plus == null or generation_description == null or generation_description.text != "ANDROID 8.0 OREO":
		_fail("Step 1 must default Android Layout 1 to Generation 2 (Android 8.0 Oreo).")
		return
	if not layout_minus.disabled or layout_plus.disabled or generation_minus.disabled or generation_plus.disabled:
		_fail("Layout and generation arrows must enforce the available selector bounds at Layout 1 / Generation 2.")
		return
	for target_layout in range(1, 3):
		layout_plus.pressed.emit()
		await process_frame
		if layout_label.text != "LAYOUT " + str(target_layout + 1):
			_fail("Step 1 did not advance to layout " + str(target_layout + 1) + ".")
			return
	for _return_layout in range(2):
		layout_minus.pressed.emit()
		await process_frame
	if layout_label.text != "LAYOUT 1" or str(worksite.get("generated_os_configuration")["components"]["home_screen"]["layout_style"]) != "android_pixel":
		_fail("Returning to Layout 1 did not restore Android before boot.")
		return
	generation_minus.pressed.emit()
	await process_frame
	if generation_label.text != "GENERATION 01" or generation_description.text != "ANDROID 5.0 LOLLIPOP":
		_fail("Generation selector did not expose Android 5.0 as Generation 1.")
		return
	generation_plus.pressed.emit()
	await process_frame
	if generation_label.text != "GENERATION 02" or generation_description.text != "ANDROID 8.0 OREO":
		_fail("Generation selector did not restore Android 8.0 Oreo as Generation 2.")
		return
	if int(worksite.get("generated_os_configuration").get("generation", 0)) != 2:
		_fail("Changing the generation did not regenerate the selected OS configuration.")
		return
	generation_plus.pressed.emit()
	await process_frame
	var selected_pie_config: Dictionary = worksite.get("generated_os_configuration")
	var pie_components: Dictionary = selected_pie_config.get("components", {})
	var pie_home_data: Dictionary = pie_components.get("home_screen", {})
	var selected_pie_lock_data: Dictionary = pie_components.get("lock_screen", {})
	if generation_label.text != "GENERATION 03" or generation_description.text != "ANDROID 9.0 PIE" or int(selected_pie_config.get("generation", 0)) != 3:
		_fail("Layout 1 must expose Generation 3 as Android 9.0 Pie.")
		return
	if int(pie_home_data.get("columns", 0)) != 5 or int(pie_home_data.get("widget_count", 0)) != 1:
		_fail("Android 9 Pie worksite selection must use its five-column Pixel grid and one At a Glance widget.")
		return
	if not bool(selected_pie_lock_data.get("show_weather", false)) or not bool(selected_pie_lock_data.get("show_battery", false)) or selected_pie_lock_data.has("show_flashlight_shortcut"):
		_fail("Android 9 Pie lock-screen options must include weather and battery but not the Lollipop flashlight.")
		return
	generation_minus.pressed.emit()
	await process_frame
	if generation_label.text != "GENERATION 02" or generation_description.text != "ANDROID 8.0 OREO" or int(worksite.get("generated_os_configuration").get("generation", 0)) != 2:
		_fail("Returning from Android 9 Pie must preserve the existing Android 8 Oreo generation.")
		return
	worksite.call("_on_next_pressed")
	await process_frame
	var boot_controls := worksite.find_child("BootLoaderOnlyControls", true, false) as VBoxContainer
	if boot_controls == null or is_instance_valid(selection_controls):
		_fail("Step 2 must switch from OS selection to Boot Loader controls.")
		return
	if boot_controls.alignment != BoxContainer.ALIGNMENT_BEGIN:
		_fail("Step 2 right-panel content must begin beneath its hero heading, not be vertically centred.")
		return
	var boot_hero := boot_controls.find_child("BootLoaderHeroTitle", true, false) as Label
	var boot_gap := boot_controls.find_child("BootLoaderHeroGap", true, false) as Control
	if boot_hero == null or boot_gap == null or boot_gap.custom_minimum_size.y < 52.0 or boot_hero.get_index() >= boot_gap.get_index():
		_fail("Step 2 must place its hero heading at the top with a clear vertical gap before the settings.")
		return
	var boot_step_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if boot_step_label == null or boot_step_label.text != "STEP 2 / 8" or not left_power_region_is_visible(worksite):
		_fail("Boot Loader must be Step 2 of 8 and reveal the independent Power control.")
		return
	for obsolete_control in ["OSGeneratorControlsViewport", "ProceduralOSGeneratorControls", "OSComponentSelector", "GenerateCompleteOSButton", "RegenerateOSComponentButton", "SelectGeneratedOSButton"]:
		if worksite.find_child(obsolete_control, true, false) != null:
			_fail("Old OS generator UI is still visible in Step 2: " + obsolete_control)
			return
	if worksite.find_child("BootCompletedStatus", true, false) != null:
		_fail("Boot loader must not create a device-turned-on status label.")
		return
	for item_id in ["company_logo", "phone_details"]:
		var row := worksite.find_child("BootSettingRow_" + item_id, true, false) as HBoxContainer
		if row == null or row.get_child_count() != 2:
			_fail("Boot loader setting must contain only its label and checkbox: " + item_id)
			return
		var row_label := row.get_child(0) as Label
		var toggle := row.get_child(1) as Button
		if row_label == null or row_label.autowrap_mode != TextServer.AUTOWRAP_OFF or absf(row_label.rotation) > 0.001:
			_fail("Boot loader setting label is not displayed horizontally: " + item_id)
			return
		if toggle == null or toggle is CheckBox or not toggle.text.is_empty():
			_fail("Boot loader enable control must use the custom checkbox, not Godot's native CheckBox: " + item_id)
			return
		if row.custom_minimum_size.y < 58.0 or toggle.custom_minimum_size.x < 40.0 or toggle.custom_minimum_size.y < 40.0 or toggle.size_flags_horizontal != Control.SIZE_SHRINK_CENTER or toggle.size_flags_vertical != Control.SIZE_SHRINK_CENTER or row_label.get_theme_font_size("font_size") < 18:
			_fail("Boot loader setting rows and touch targets must use the larger Phone Creation Worksite sizing.")
			return
		if absf(toggle.size.x - toggle.size.y) > 1.0:
			_fail("Boot loader checkbox must render as a square, not a vertical rectangle: " + item_id)
			return
		if worksite.find_child("BootOrder_" + item_id, true, false) != null:
			_fail("Boot loader must not contain startup order number boxes.")
			return
	var boot_settings: Dictionary = worksite.get("bootloader_settings")
	if boot_settings["items"]["company_logo"].has("order") or boot_settings["items"]["phone_details"].has("order"):
		_fail("Boot loader still stores manual startup order values.")
		return
	var logo_toggle := worksite.find_child("BootEnabled_company_logo", true, false) as Button
	var details_toggle := worksite.find_child("BootEnabled_phone_details", true, false) as Button
	logo_toggle.set_pressed_no_signal(true)
	details_toggle.set_pressed_no_signal(true)
	worksite.call("_on_boot_item_toggled", true, "company_logo")
	worksite.call("_on_boot_item_toggled", true, "phone_details")
	worksite.call("set_boot_identity", "KingsHall", 3, "", "")
	var fallback_boot_identity: Dictionary = worksite.get("boot_identity")
	if fallback_boot_identity.get("phone_name", "") != "DigitalWorld Phone" or fallback_boot_identity.get("phone_model", "") != "DW-01":
		_fail("Boot screen did not replace empty phone name and model with their defaults.")
		return
	worksite.call("set_boot_identity", "KingsHall", 3, "   ", "  \t  ")
	fallback_boot_identity = worksite.get("boot_identity")
	if fallback_boot_identity.get("phone_name", "") != "DigitalWorld Phone" or fallback_boot_identity.get("phone_model", "") != "DW-01":
		_fail("Boot screen did not replace whitespace-only phone identity with its defaults.")
		return
	worksite.call("set_boot_identity", "KingsHall", 3, "DigitalWorld Phone Professional Edition", "DW-01")
	worksite.call("_generate_complete_os")
	await process_frame
	var saved_boot_config: Dictionary = worksite.get("generated_os_configuration").get("bootloader", {})
	if float(saved_boot_config.get("duration_seconds", 0.0)) != 10.0:
		_fail("Generated OS did not retain the fixed ten-second boot duration.")
		return
	if worksite_preview.visible:
		_fail("Generating an OS incorrectly powered on the display before boot.")
		return
	var boot_started_at := Time.get_ticks_msec()
	var boot_completion_state := {"done": false}
	worksite.boot_completed.connect(func() -> void:
		boot_completion_state["done"] = true
	, CONNECT_ONE_SHOT)
	worksite.call("_on_power_button_pressed")
	if not boot_overlay.visible:
		_fail("Power button did not switch the display into its boot sequence.")
		return
	if worksite.find_child("BootDebugPanel", true, false) != null or worksite.find_child("BootDebugCopyButton", true, false) != null:
		_fail("Temporary boot diagnostics panel was not removed.")
		return
	await create_timer(0.1).timeout
	var boot_identity_label := worksite.find_child("BootIdentityText", true, false) as Label
	var boot_model_label := worksite.find_child("BootModelText", true, false) as Label
	var boot_logo := worksite.find_child("BootCompanyLogo", true, false) as TextureRect
	if boot_identity_label == null or boot_model_label == null or boot_logo == null:
		_fail("Boot logo, phone-name label or phone-model label was not created.")
		return
	if not boot_logo.visible or boot_identity_label.visible or boot_model_label.visible:
		_fail("Company logo must be the first visible boot stage before phone details.")
		return
	await create_timer(5.0).timeout
	var boot_stage := worksite.find_child("BootLoaderStage", true, false) as VBoxContainer
	if boot_identity_label.text != "DigitalWorld Phone Professional Edition" or not boot_identity_label.visible or boot_logo.visible:
		_fail("Phone name must visibly replace the company logo in the second boot stage.")
		return
	if boot_model_label == null or boot_model_label.text != "DW-01" or not boot_model_label.visible:
		_fail("Phone model must be shown as part of the second boot stage.")
		return
	if boot_stage == null or boot_stage.size.x <= 0.0 or boot_identity_label.size.x <= 0.0 or boot_identity_label.size.x > boot_stage.size.x + 1.0:
		_fail("Boot identity text is not constrained to the available phone-screen width.")
		return
	if boot_identity_label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		_fail("Phone identity text must support wrapping inside the phone screen.")
		return
	if boot_identity_label.position.y + boot_identity_label.size.y > boot_model_label.position.y + 0.5:
		_fail("Phone model overlaps the phone name: name end %.1f, model start %.1f." % [boot_identity_label.position.y + boot_identity_label.size.y, boot_model_label.position.y])
		return
	var boot_identity_font := boot_identity_label.get_theme_font("font") as FontVariation
	if boot_identity_label.get_theme_font_size("font_size") != 18 or boot_identity_font == null or not is_equal_approx(boot_identity_font.variation_embolden, 1.5):
		_fail("Phone name must use the bold, screen-fitted boot identity typography.")
		return
	if boot_model_label.get_theme_font_size("font_size") != 15 or boot_model_label.custom_minimum_size.y < 26.0:
		_fail("Phone model must use the explicitly sized secondary boot identity typography.")
		return
	if boot_identity_label.custom_minimum_size.y < 54.0:
		_fail("Phone name must reserve enough vertical space for controlled multi-line wrapping.")
		return
	var boot_model_font := boot_model_label.get_theme_font("font") as FontVariation
	if boot_model_font == null or not is_equal_approx(boot_model_font.variation_embolden, 1.0):
		_fail("Phone model must use the defined medium-weight boot typography.")
		return
	while not bool(boot_completion_state["done"]) and Time.get_ticks_msec() - boot_started_at < 12000:
		await process_frame
	if not bool(boot_completion_state["done"]):
		_fail("Boot sequence did not emit its completion signal within twelve seconds.")
		return
	var boot_elapsed := Time.get_ticks_msec() - boot_started_at
	if boot_elapsed < 9900 or boot_elapsed > 10500:
		_fail("Boot sequence did not complete in ten real-world seconds (%d ms)." % boot_elapsed)
		return
	if boot_overlay.visible or not worksite_preview.visible:
		_fail("Completed boot did not reveal the generated OS lock screen.")
		return
	if worksite_preview.get("active_component") != "lock_screen":
		_fail("Completed boot did not land on the lock screen.")
		return
	if worksite.find_child("LockScreenStudioControls", true, false) == null:
		_fail("Lock-screen functionality controls were not shown in the right panel.")
		return
	var completed_step_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if completed_step_label == null or completed_step_label.text != "STEP 3 / 8":
		_fail("Lock Screen Studio must appear as Step 3 after boot completes.")
		return
	worksite.call("_on_wizard_back_pressed")
	await process_frame
	if worksite.find_child("BootLoaderOnlyControls", true, false) == null or worksite.find_child("LockScreenStudioControls", true, false) != null:
		_fail("Wizard Back did not return exclusively to Boot Loader Step 2.")
		return
	worksite.call("_on_next_pressed")
	await process_frame
	var lock_controls := worksite.find_child("LockScreenStudioControls", true, false) as VBoxContainer
	if lock_controls == null:
		_fail("Wizard Next did not return to Lock Screen Studio Step 3.")
		return
	if worksite.find_child("LockScreenSettingRow_show_unlock_hint", true, false) != null or worksite.find_child("LockScreenEnabled_show_unlock_hint", true, false) != null:
		_fail("Lock Screen Studio must not expose an unlock-prompt checkbox or its enablement text.")
		return
	var lock_hero := lock_controls.find_child("LockScreenHeroTitle", true, false) as Label
	var lock_gap := lock_controls.find_child("LockScreenHeroGap", true, false) as Control
	if lock_hero == null or lock_gap == null or lock_gap.custom_minimum_size.y < 20.0 or lock_hero.get_index() >= lock_gap.get_index():
		_fail("Step 2 must place its hero heading at the top with a clear vertical gap before the settings.")
		return

	for setting_id in ["show_time", "show_date", "show_notifications", "show_assistant_shortcut", "show_camera_shortcut"]:
		var setting_row := lock_controls.find_child("LockScreenSettingRow_" + setting_id, true, false) as HBoxContainer
		var setting_toggle := lock_controls.find_child("LockScreenEnabled_" + setting_id, true, false) as Button
		if setting_row == null or setting_toggle == null or setting_row.custom_minimum_size.y < 54.0 or setting_toggle.custom_minimum_size.x < 40.0 or setting_toggle.custom_minimum_size.y < 40.0:
			_fail("Oreo Lock Screen Studio is missing a properly sized checkbox row: " + setting_id)
			return
		if absf(setting_toggle.size.x - setting_toggle.size.y) > 1.0:
			_fail("Oreo lock-screen checkbox must remain square: " + setting_id)
			return
	if lock_hero.text != "ANDROID 8.0 OREO LOCK SCREEN":
		_fail("Layout 1 Generation 2 must identify the Pixel 2 Android 8.0 lock screen.")
		return

	worksite.call("_on_next_pressed")
	await process_frame
	var home_controls := worksite.find_child("HomeScreenStudioControls", true, false) as VBoxContainer
	var home_step_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if home_controls == null or home_step_label == null or home_step_label.text != "STEP 4 / 8":
		_fail("Step 4 Home Screen Studio did not open with the eight-step progress indicator.")
		return
	if worksite.find_child("HomeScreenLayoutSelector", true, false) != null or worksite.find_child("HomeScreenCornerRadiusSlider", true, false) == null:
		_fail("Layout selection must stay in Step 1; Home Screen Studio should contain only its own customization controls.")
		return
	if worksite_preview.get("active_component") != "home_screen" or worksite_preview.find_child("HomeAppGrid", true, false) == null or worksite_preview.find_child("HomeSearchBar", true, false) == null:
		_fail("Entering Step 4 did not show the selected Android 8 home screen.")
		return
	worksite.call("_on_wizard_back_pressed")
	await process_frame
	if worksite.find_child("LockScreenStudioControls", true, false) == null or worksite_preview.get("active_component") != "lock_screen":
		_fail("Wizard Back from Step 4 did not return to the Android 8 Lock Screen Studio.")
		return


	for setting_id in ["show_time", "show_date", "show_notifications", "show_assistant_shortcut", "show_camera_shortcut"]:
		var setting_toggle := worksite.find_child("LockScreenEnabled_" + setting_id, true, false) as Button
		if setting_toggle == null:
			_fail("Oreo Lock Screen Studio is missing its checkbox: " + setting_id)
			return
		setting_toggle.button_pressed = false
		setting_toggle.toggled.emit(false)
		await process_frame
		if bool(worksite.get("generated_os_configuration")["components"]["lock_screen"].get(setting_id, true)):
			_fail("Oreo Lock Screen Studio checkbox did not save its disabled state: " + setting_id)
			return
		if setting_id == "show_date" and worksite_preview.find_child("LockScreenDate", true, false) != null:
			_fail("Disabling Display Date must remove the date from the live lock-screen preview.")
			return
		setting_toggle.button_pressed = true
		setting_toggle.toggled.emit(true)
		await process_frame
		if setting_id == "show_date":
			var preview_date := worksite_preview.find_child("LockScreenDate", true, false) as Label
			if preview_date == null or not preview_date.visible or preview_date.text.strip_edges().is_empty() or preview_date.custom_minimum_size.y < 16.0:
				_fail("Enabling Display Date must render a visible, non-empty, properly sized date label in the live lock-screen preview.")
				return
	worksite_preview.call("_handle_system_gesture", Vector2(72, 300), Vector2(72, 220), 120)
	await process_frame
	if worksite_preview.get("active_component") != "pin_input":
		_fail("Swipe-up on the lock screen did not open PIN entry.")
		return
	var pin_info := worksite_preview.find_child("PINPreviewUnlockInfo", true, false) as PanelContainer
	var pin_info_label := pin_info.get_child(0) as Label if pin_info != null else null
	var pin_error := worksite_preview.find_child("PINEntryError", true, false) as Label
	var pin_lock_indicator := worksite_preview.find_child("PINLockIndicator", true, false) as Control
	var pin_keypad := worksite_preview.find_child("PINKeypad", true, false) as GridContainer
	var pin_key_two := worksite_preview.find_child("PINKey_2", true, false) as Button
	var emergency_call := worksite_preview.find_child("PINEmergencyCallButton", true, false) as Button
	if pin_info == null or pin_info_label == null or pin_error == null or not pin_info_label.text.contains("1234"):
		_fail("PIN screen did not clearly display the preview unlock PIN 1234.")
		return
	if pin_lock_indicator == null or pin_keypad == null or pin_keypad.columns != 3 or pin_keypad.get_child_count() != 12 or emergency_call == null:
		_fail("PIN screen is missing its lock indicator, responsive 3×4 keypad or emergency-call control.")
		return
	var pin_key_spacer := pin_keypad.get_child(9) as Control
	var pin_key_zero := pin_keypad.get_child(10) as Button
	var pin_key_delete := pin_keypad.get_child(11) as Button
	if pin_key_spacer == null or pin_key_spacer is Button or pin_key_spacer.name != "PINKey_Spacer" or pin_key_zero == null or pin_key_zero.name != "PINKey_0" or pin_key_delete == null or pin_key_delete.name != "PINKey_Delete":
		_fail("PIN keypad bottom row must place an empty slot, zero and Delete from left to right.")
		return
	if worksite_preview.find_child("PINKey_OK", true, false) != null:
		_fail("PIN keypad must not show a redundant OK key when the fourth digit submits automatically.")
		return
	if pin_key_two == null or pin_key_two.size.x < 24.0 or pin_key_two.text != "2":
		_fail("PIN digit buttons must display their number on a usable circular touch target.")
		return
	if pin_key_two.custom_minimum_size.x < 34.0 or pin_keypad.get_theme_constant("h_separation") < 8 or pin_keypad.get_theme_constant("v_separation") < 8:
		_fail("PIN keypad buttons and row/column spacing must be comfortably sized rather than tightly compressed.")
		return
	if pin_lock_indicator.custom_minimum_size.y < 20.0 or pin_error.custom_minimum_size.y < 14.0 or emergency_call.custom_minimum_size.y < 28.0:
		_fail("PIN header, reserved error row and emergency-call footer must have enough vertical breathing room.")
		return
	for digit_text in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]:
		var visible_digit := worksite_preview.find_child("PINKey_" + digit_text, true, false) as Button
		if visible_digit == null or visible_digit.text != digit_text:
			_fail("PIN keypad digit is missing from its actual Button text: " + digit_text)
			return
	var pin_key_style := pin_key_two.get_theme_stylebox("normal") as StyleBoxFlat
	if pin_key_style == null or pin_key_style.corner_radius_top_left < 15:
		_fail("PIN number keys are not styled as circular One UI-style buttons.")
		return
	var pin_key_font_color := pin_key_two.get_theme_color("font_color")
	if pin_key_font_color.a < 0.95 or pin_key_font_color.get_luminance() < 0.80:
		_fail("PIN digits do not have a clearly visible white font color.")
		return
	if pin_key_style.bg_color.a <= 0.0 or pin_key_style.bg_color.a > 0.20 or pin_key_style.get_border_width(SIDE_LEFT) != 0 or pin_key_style.get_border_width(SIDE_RIGHT) != 0 or pin_key_style.get_border_width(SIDE_TOP) != 0 or pin_key_style.get_border_width(SIDE_BOTTOM) != 0 or pin_key_style.shadow_size != 0:
		_fail("PIN keypad keys must use clean transparent glass without connector outlines or shadows.")
		return
	var pin_key_three := worksite_preview.find_child("PINKey_3", true, false) as Button
	var pin_key_three_style := pin_key_three.get_theme_stylebox("normal") as StyleBoxFlat if pin_key_three != null else null
	if pin_key_three_style == null or pin_key_three_style.bg_color != pin_key_style.bg_color:
		_fail("All PIN keys must share the same neutral glass color.")
		return
	for digit in ["0", "0", "0", "0"]:
		var wrong_key := worksite_preview.find_child("PINKey_" + digit, true, false) as Button
		wrong_key.pressed.emit()
		await process_frame
	if worksite_preview.get("active_component") != "pin_input" or not pin_error.text.contains("Incorrect PIN"):
		_fail("Incorrect PIN did not show an error while keeping the phone locked.")
		return
	var delete_test_key := worksite_preview.find_child("PINKey_1", true, false) as Button
	delete_test_key.pressed.emit()
	await process_frame
	pin_key_delete.pressed.emit()
	await process_frame
	if str(worksite_preview.get("_entered_unlock_pin")) != "":
		_fail("PIN Delete did not clear the last entered digit.")
		return
	if not pin_error.visible or not pin_error.text.is_empty():
		_fail("The empty PIN error row must stay reserved so the keypad does not shift while typing.")
		return
	for digit in ["1", "2", "3", "4"]:
		var correct_key := worksite_preview.find_child("PINKey_" + digit, true, false) as Button
		correct_key.pressed.emit()
		await process_frame
	if worksite_preview.get("active_component") != "home_screen":
		_fail("Entering the correct preview PIN 1234 did not unlock to Home.")
		return
	var oreo_home_grid := worksite_preview.find_child("HomeAppGrid", true, false) as GridContainer
	var oreo_home_search := worksite_preview.find_child("HomeSearchBar", true, false) as LineEdit
	var oreo_home_weather := worksite_preview.find_child("AndroidWeatherWidget", true, false) as Control
	var oreo_home_assistant := worksite_preview.find_child("AndroidAssistantWidget", true, false) as Control
	var oreo_navigation := worksite_preview.find_child("AndroidThreeButtonNavigation", true, false) as HBoxContainer
	if oreo_home_grid == null or oreo_home_grid.columns != 4 or oreo_home_grid.get_child_count() != 4 or oreo_home_search == null:
		_fail("Android 8 home screen is missing its app grid or search field.")
		return
	if oreo_home_weather == null or oreo_home_assistant == null or oreo_navigation == null or oreo_navigation.get_child_count() != 3:
		_fail("Android 8 home screen is missing its widgets or three-button navigation.")
		return
	var oreo_configuration: Dictionary = worksite_preview.get("configuration")
	if int(oreo_configuration.get("generation", 0)) != 2 or str(oreo_configuration.get("components", {}).get("home_screen", {}).get("layout_style", "")) != "android_pixel":
		_fail("The selected worksite OS did not retain Android Layout 1 Generation 2.")
		return
	if str(oreo_configuration.get("style", {}).get("wallpaper", "")) == "lollipop":
		_fail("Android 8 Generation 2 must not use the Lollipop-only default wallpaper.")
		return

	worksite_preview.set_component_view("app_drawer")
	await process_frame
	var oreo_drawer_viewport := worksite_preview.find_child("AppDrawerViewport", true, false) as ScrollContainer
	var oreo_drawer_grid := worksite_preview.find_child("AppDrawerGrid", true, false) as GridContainer
	var oreo_drawer_search := worksite_preview.find_child("AppDrawerSearchField", true, false) as LineEdit
	var oreo_drawer_data: Dictionary = oreo_configuration.get("components", {}).get("app_drawer", {})
	var rendered_oreo_app_count := 0
	if str(oreo_drawer_data.get("layout", "alphabetical")) == "categories":
		var oreo_category_grids := worksite_preview.find_children("AppDrawerCategory_*", "GridContainer", true, false)
		for category_grid in oreo_category_grids:
			rendered_oreo_app_count += (category_grid as GridContainer).get_child_count()
	else:
		if oreo_drawer_grid != null:
			rendered_oreo_app_count = oreo_drawer_grid.get_child_count()
	if oreo_drawer_search == null or rendered_oreo_app_count != ProceduralEngineScript.APP_DEFINITIONS.size():
		_fail("Android 8 app drawer did not render all installed apps and its search field.")
		return
	if str(oreo_drawer_data.get("layout", "alphabetical")) != "categories" and oreo_drawer_viewport == null:
		_fail("Android 8 scrolling app drawer is missing its viewport.")
		return
	var drawer_back := worksite_preview.find_child("AndroidNavigationBack", true, false) as Button
	if drawer_back == null:
		_fail("Android 8 app drawer is missing its Back navigation key.")
		return
	drawer_back.pressed.emit()
	await process_frame
	if worksite_preview.get("active_component") != "home_screen":
		_fail("Android Back navigation did not return from the app drawer to Home.")
		return
	worksite_preview.set_component_view("app_drawer")
	await process_frame
	worksite_preview.set_component_view("lock_screen")
	await process_frame
	worksite_preview.call("_navigate_back")
	await process_frame
	if worksite_preview.get("active_component") != "app_drawer":
		_fail("Android Back navigation did not restore the previous screen from navigation history.")
		return
	worksite_preview.call("_navigate_home")
	await process_frame
	if worksite_preview.get("active_component") != "home_screen":
		_fail("Android Home navigation did not bypass navigation history and return directly Home.")
		return

	worksite.call("_on_next_pressed")
	await process_frame
	var home_studio_controls := worksite.find_child("HomeScreenStudioControls", true, false) as VBoxContainer
	var home_corner_slider := worksite.find_child("HomeScreenCornerRadiusSlider", true, false) as HSlider
	var step_four_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if home_studio_controls == null or home_corner_slider == null or step_four_label.text != "STEP 4 / 8":
		_fail("Wizard Next did not enter Home Screen Studio as Step 4.")
		return
	if home_corner_slider.min_value != 0.0 or home_corner_slider.max_value != 24.0 or home_corner_slider.value != 0.0 or home_corner_slider.step > 0.25:
		_fail("Home Screen Studio lost its corner-radius setting.")
		return
	home_corner_slider.value = 12.0
	await process_frame
	home_corner_slider.value = 0.0
	await process_frame

	var expected_component_steps := [
		["app_drawer", "APP DRAWER", "STEP 5 / 8"],
		["control_center", "CONTROL CENTER", "STEP 6 / 8"],
		["notifications", "NOTIFICATION PANEL", "STEP 7 / 8"],
		["wallpapers", "WALLPAPERS", "STEP 8 / 8"]
	]
	for expected_step in expected_component_steps:
		worksite.call("_on_next_pressed")
		await process_frame
		var step_text := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
		var component_controls := worksite.find_child("ComponentStudioControls", true, false) as VBoxContainer
		var component_heading := component_controls.find_child("ComponentStudioHeroTitle", true, false) as Label if component_controls != null else null
		if step_text == null or step_text.text != str(expected_step[2]) or component_controls == null or component_heading == null or component_heading.text != str(expected_step[1]):
			_fail("Worksite customization sequence did not show " + str(expected_step[1]) + " at " + str(expected_step[2]) + ".")
			return
		if str(worksite_preview.get("active_component")) != str(expected_step[0]):
			_fail("Phone preview did not switch to " + str(expected_step[0]) + " at its wizard step.")
			return
	if not worksite_next_button.disabled:
		_fail("The final Wallpapers step must disable the wizard Next arrow.")
		return
	worksite.call("_on_wizard_back_pressed")
	await process_frame
	var final_step_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if final_step_label == null or final_step_label.text != "STEP 7 / 8" or worksite_preview.get("active_component") != "notifications":
		_fail("Wizard Back from Wallpapers did not return to Notification Panel Step 7.")
		return
	worksite_preview.set_component_view("lock_screen")
	await process_frame
	for obsolete_lock_control in ["LockScreenFingerprintSensor", "LockScreenAudioPlayer", "GenerateLockScreenDesignButton"]:
		if worksite.find_child(obsolete_lock_control, true, false) != null or worksite_preview.find_child(obsolete_lock_control, true, false) != null:
			_fail("Obsolete lock-screen system control remains: " + obsolete_lock_control)
			return
	var final_worksite_configuration: Dictionary = worksite.get("generated_os_configuration")
	if final_worksite_configuration.get("components", {}).size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("The OS worksite no longer contains all 6 core components after the lock-screen cleanup.")
		return
	if worksite_preview.get("configuration").get("components", {}).size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("The visible simulator did not retain all 6 core components.")
		return
	root.remove_child(worksite)
	worksite.free()
	await process_frame
	await process_frame
	await process_frame
	print("OS_GENERATOR_SMOKE_TEST: PASS")
	quit(0)



func left_power_region_is_visible(worksite: Node) -> bool:
	var power_region := worksite.find_child("OSPowerButtonRegion", true, false) as Control
	return power_region != null and power_region.visible

func _simulate_touch_swipe(simulator: Control, start: Vector2, finish: Vector2, duration_ms: int) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = start
	press.pressed = true
	simulator.call("_input", press)
	simulator.set("_gesture_start_time", Time.get_ticks_msec() - duration_ms)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = finish
	release.pressed = false
	simulator.call("_input", release)


func _fail(message: String) -> void:
	push_error("OS_GENERATOR_SMOKE_TEST: " + message)
	quit(1)
