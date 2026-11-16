extends SceneTree

const ProceduralEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const SimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")

var _opened_apps: Array[String] = []

func _initialize() -> void:
	call_deferred("_run_gen1_smoke_test")

func _run_gen1_smoke_test() -> void:
	var simulator_host := Control.new()
	simulator_host.name = "Gen1SmokeTestHost"
	simulator_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	simulator_host.size = Vector2(145.0, 360.0)
	root.add_child(simulator_host)
	await process_frame

	var simulator := SimulatorScript.new()
	simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simulator_host.add_child(simulator)
	await process_frame
	simulator.app_opened.connect(_capture_app_opened)

	# Samsung TouchWiz: retain the existing screenshot routing and tap behaviour.
	var samsung_config := ProceduralEngineScript.generate_os(8101, 1)
	if str(samsung_config.get("style", {}).get("identity", "")) != "Samsung TouchWiz Nature UX":
		_fail("Gen 1 Samsung family identity is incorrect.")
		return
	if int(samsung_config.get("generation", 0)) != 1:
		_fail("Samsung TouchWiz configuration must remain in Gen 1.")
		return
	if not ProceduralEngineScript.validate_os(samsung_config).is_empty():
		_fail("Gen 1 Samsung configuration failed validation.")
		return

	var samsung_assets := {
		"lock_screen": "lockscreen.jpg",
		"home_screen": "home_screen.jpg",
		"app_drawer": "app_drawer.jpg",
		"notifications": "notification.jpg",
		"control_center": "notification.jpg",
		"recent_apps": "recent_apps.jpg"
	}
	for component_id in samsung_assets:
		simulator.configure_os(samsung_config, str(component_id))
		await process_frame
		var samsung_image_node := simulator.find_child("SamsungGen1ScreenImage_" + str(component_id), true, false) as TextureRect
		var expected_path := "res://assets/os/gen1/samsung/" + str(samsung_assets[component_id])
		if samsung_image_node == null or samsung_image_node.texture == null or samsung_image_node.texture.resource_path != expected_path:
			_fail("Gen 1 Samsung " + str(component_id) + " reference image failed to load: " + expected_path)
			return

	simulator.configure_os(samsung_config, "home_screen")
	await process_frame
	_opened_apps.clear()
	_simulate_screenshot_tap(simulator, "SamsungGen1ScreenImage_home_screen", Vector2(0.14, 0.52))
	if _opened_apps.is_empty() or _opened_apps.back() != "Email":
		_fail("Samsung TouchWiz home-screen icon taps stopped opening their mapped app.")
		return

	# Google Stock Android 4.0: verify real tap, app drawer, navigation, panels and unlock.
	var pixel_config := ProceduralEngineScript.generate_os(8102, 1)
	pixel_config["style"]["ui_family"] = "google_stock"
	pixel_config = ProceduralEngineScript.normalize_os(pixel_config)
	if int(pixel_config.get("generation", 0)) != 1 or str(pixel_config.get("style", {}).get("identity", "")) != "Google Stock Android 4.0 Ice Cream Sandwich":
		_fail("Google Stock Android 4.0 must remain an independent Gen 1 UI family.")
		return
	var pixel_assets := {
		"lock_screen": "lockscreen.jpg",
		"home_screen": "homescreen.jpg",
		"app_drawer": "appsdrawer.jpg",
		"control_center": "controlcenter.jpg",
		"notifications": "notification.jpg",
		"recent_apps": "recentapps.jpg"
	}
	for component_id in pixel_assets:
		var expected_path := "res://assets/os/gen1/pixel/" + str(pixel_assets[component_id])
		simulator.configure_os(pixel_config, str(component_id))
		await process_frame
		if component_id == "recent_apps":
			if (load(expected_path) as Texture2D) == null:
				_fail("Google Stock Android 4 recent-apps reference asset failed to import: " + expected_path)
				return
			if simulator.find_child("PixelGen1ScreenImage_recent_apps", true, false) != null:
				_fail("Google Stock Android 4 recent apps should use the live task interface, not a fixed screenshot.")
				return
			if simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
				_fail("Google Stock Android 4 live recent-apps interface was not built.")
				return
			continue
		var pixel_image_node := simulator.find_child("PixelGen1ScreenImage_" + str(component_id), true, false) as TextureRect
		if pixel_image_node == null or pixel_image_node.texture == null or pixel_image_node.texture.resource_path != expected_path:
			_fail("Gen 1 Google Stock Android 4 " + str(component_id) + " reference image failed to load: " + expected_path)
			return

	simulator.configure_os(pixel_config, "home_screen")
	await process_frame
	if simulator.find_child("PixelGen1NavigationBack", true, false) == null or simulator.find_child("PixelGen1NavigationHome", true, false) == null or simulator.find_child("PixelGen1NavigationOverview", true, false) == null:
		_fail("Google Stock Android 4 must expose working Back, Home and Overview navigation controls.")
		return
	_opened_apps.clear()
	_simulate_screenshot_tap(simulator, "PixelGen1ScreenImage_home_screen", Vector2(0.14, 0.50))
	if _opened_apps.is_empty() or _opened_apps.back() != "Calendar":
		_fail("Google Stock Android 4 home-screen icon taps are not connected to apps.")
		return
	_simulate_screenshot_tap(simulator, "PixelGen1ScreenImage_home_screen", Vector2(0.50, 0.95))
	if simulator.active_component != "app_drawer":
		_fail("Google Stock Android 4 Apps shortcut did not open the app drawer.")
		return
	await process_frame
	_simulate_screenshot_tap(simulator, "PixelGen1ScreenImage_app_drawer", Vector2(0.13, 0.245))
	if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
		_fail("Google Stock Android 4 app-drawer icons are not interactive.")
		return

	simulator.configure_os(pixel_config, "lock_screen")
	await process_frame
	if simulator.find_child("AndroidNavigationBar", true, false) == null:
		_fail("Google Stock Android 4 lock screen is missing its system navigation bar.")
		return
	simulator._dispatch_android_navigation("Home")
	simulator._dispatch_android_navigation("Back")
	if simulator.active_component != "lock_screen":
		_fail("Google Stock Android 4 navigation buttons must not bypass the locked screen.")
		return
	simulator._handle_system_gesture(Vector2(simulator.size.x * 0.30, simulator.size.y * 0.50), Vector2(simulator.size.x * 0.80, simulator.size.y * 0.50), 150)
	if simulator.active_component != "home_screen":
		_fail("Google Stock Android 4 slide-to-unlock gesture did not enter the home screen.")
		return
	await process_frame

	simulator._handle_system_gesture(Vector2(72.0, 7.0), Vector2(72.0, 100.0), 150)
	await process_frame
	if simulator.find_child("OSGestureOverlay_notifications", true, false) == null or simulator.find_child("PixelGen1ScreenImage_notifications", true, false) == null:
		_fail("Google Stock Android 4 top-edge swipe did not open its notification shade.")
		return
	_opened_apps.clear()
	_simulate_overlay_tap(simulator, "PixelGen1ScreenImage_notifications", "notifications", Vector2(0.50, 0.46))
	if _opened_apps.is_empty() or _opened_apps.back() != "Email":
		_fail("Google Stock Android 4 notification entries are not interactive.")
		return

	simulator.configure_os(pixel_config, "control_center")
	await process_frame
	var pixel_wifi_before := bool(simulator._quick_setting_states.get("Wi-Fi", false))
	_simulate_screenshot_tap(simulator, "PixelGen1ScreenImage_control_center", Vector2(0.25, 0.38))
	if bool(simulator._quick_setting_states.get("Wi-Fi", false)) == pixel_wifi_before:
		_fail("Google Stock Android 4 Quick Settings tiles do not update their state.")
		return
	var pixel_brightness_before := int(simulator._brightness_level)
	_simulate_screenshot_tap(simulator, "PixelGen1ScreenImage_control_center", Vector2(0.50, 0.24))
	if int(simulator._brightness_level) == pixel_brightness_before:
		_fail("Google Stock Android 4 brightness slider does not change display brightness.")
		return
	_opened_apps.clear()
	simulator._dispatch_android_navigation("Overview")
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
		_fail("Google Stock Android 4 Overview navigation did not open the live recent-apps interface.")
		return
	simulator._navigate_back()

	# Xiaomi MIUI V4: family-specific launcher, notification controls, nav and unlock.
	var xiaomi_config := ProceduralEngineScript.generate_os(8103, 1)
	xiaomi_config["style"]["ui_family"] = "xiaomi_miui"
	xiaomi_config = ProceduralEngineScript.normalize_os(xiaomi_config)
	if int(xiaomi_config.get("generation", 0)) != 1 or str(xiaomi_config.get("style", {}).get("identity", "")) != "Xiaomi MIUI (Android 4.0 era)":
		_fail("Xiaomi MIUI must remain an independent Gen 1 UI family.")
		return
	var xiaomi_assets := {
		"lock_screen": "lockscreen.jpg",
		"home_screen": "homescreen.jpg",
		"app_drawer": "appdrawer.jpg",
		"notifications": "notification.jpg",
		"recent_apps": "recentapps.jpg"
	}
	for component_id in xiaomi_assets:
		var expected_xiaomi_path := "res://assets/os/gen1/miui/" + str(xiaomi_assets[component_id])
		simulator.configure_os(xiaomi_config, str(component_id))
		await process_frame
		if component_id == "recent_apps":
			if (load(expected_xiaomi_path) as Texture2D) == null:
				_fail("Xiaomi MIUI recent-apps reference asset failed to import: " + expected_xiaomi_path)
				return
			if simulator.find_child("XiaomiGen1ScreenImage_recent_apps", true, false) != null or simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
				_fail("Xiaomi MIUI recent apps should use its live task interface instead of a fixed screenshot.")
				return
			continue
		var xiaomi_image_node := simulator.find_child("XiaomiGen1ScreenImage_" + str(component_id), true, false) as TextureRect
		if xiaomi_image_node == null or xiaomi_image_node.texture == null or xiaomi_image_node.texture.resource_path != expected_xiaomi_path:
			_fail("Gen 1 Xiaomi MIUI V4 " + str(component_id) + " reference image failed to load: " + expected_xiaomi_path)
			return

	simulator.configure_os(xiaomi_config, "control_center")
	await process_frame
	if simulator.find_child("XiaomiGen1ScreenImage_control_center", true, false) != null or simulator.find_child("XiaomiGen1ReferencePending_control_center", true, false) == null:
		_fail("Gen 1 Xiaomi Control Center must not reuse the notification screenshot when its own reference image is missing.")
		return

	simulator.configure_os(xiaomi_config, "home_screen")
	await process_frame
	if simulator.find_child("XiaomiGen1NavigationBack", true, false) == null or simulator.find_child("XiaomiGen1NavigationHome", true, false) == null or simulator.find_child("XiaomiGen1NavigationOverview", true, false) == null:
		_fail("Xiaomi MIUI V4 must expose Back, Home and Overview navigation controls.")
		return
	_opened_apps.clear()
	_simulate_screenshot_tap(simulator, "XiaomiGen1ScreenImage_home_screen", Vector2(0.16, 0.32))
	if _opened_apps.is_empty() or _opened_apps.back() != "Calendar":
		_fail("Xiaomi MIUI V4 launcher icons are not interactive.")
		return

	simulator.configure_os(xiaomi_config, "notifications")
	await process_frame
	var xiaomi_wifi_before := bool(simulator._quick_setting_states.get("Wi-Fi", false))
	_simulate_screenshot_tap(simulator, "XiaomiGen1ScreenImage_notifications", Vector2(0.14, 0.18))
	if bool(simulator._quick_setting_states.get("Wi-Fi", false)) == xiaomi_wifi_before:
		_fail("Xiaomi MIUI V4 notification-panel Quick Settings do not update their state.")
		return
	var xiaomi_brightness_before := int(simulator._brightness_level)
	_simulate_screenshot_tap(simulator, "XiaomiGen1ScreenImage_notifications", Vector2(0.75, 0.29))
	if int(simulator._brightness_level) == xiaomi_brightness_before:
		_fail("Xiaomi MIUI V4 brightness slider does not change display brightness.")
		return

	simulator.configure_os(xiaomi_config, "lock_screen")
	await process_frame
	if simulator.find_child("AndroidNavigationBar", true, false) == null:
		_fail("Xiaomi MIUI V4 lock screen is missing its system navigation bar.")
		return
	simulator._dispatch_android_navigation("Home")
	simulator._dispatch_android_navigation("Back")
	if simulator.active_component != "lock_screen":
		_fail("Xiaomi MIUI V4 navigation buttons must not bypass the locked screen.")
		return
	simulator._handle_system_gesture(Vector2(simulator.size.x * 0.30, simulator.size.y * 0.86), Vector2(simulator.size.x * 0.80, simulator.size.y * 0.86), 150)
	if simulator.active_component != "home_screen":
		_fail("Xiaomi MIUI V4 slide-to-unlock gesture did not enter the home screen.")
		return
	await process_frame

	simulator._dispatch_android_navigation("Overview")
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
		_fail("Xiaomi MIUI V4 Overview navigation did not open the live recent-apps interface.")
		return
	simulator._navigate_back()

	# Gen 2 Android 7 Nougat: each manufacturer family has its own six reference
	# images, while navigation, gestures, app launching, quick settings and recents
	# reuse the interaction model proven by Gen 1.
	var gen2_families: Array[Dictionary] = [
		{
			"id": "samsung_experience",
			"prefix": "Samsung",
			"folder": "samsung",
			"identity": "Samsung Experience 8.0 · Android 7 Nougat",
			"notifications_file": "notifications.jpg",
			"home_tap": Vector2(0.13, 0.34)
		},
		{
			"id": "google_pixel",
			"prefix": "Pixel",
			"folder": "pixel",
			"identity": "Google Pixel Launcher · Android 7.1 Nougat",
			"notifications_file": "notification.jpg",
			"home_tap": Vector2(0.13, 0.57)
		},
		{
			"id": "xiaomi_miui8",
			"prefix": "Xiaomi",
			"folder": "miui",
			"identity": "Xiaomi MIUI 8 · Android 7 Nougat",
			"notifications_file": "notification.jpg",
			"home_tap": Vector2(0.13, 0.34)
		}
	]
	for family_index in range(gen2_families.size()):
		var family: Dictionary = gen2_families[family_index]
		var gen2_config := ProceduralEngineScript.generate_os(8201 + family_index, 2)
		var gen2_style: Dictionary = gen2_config.get("style", {}).duplicate(true)
		gen2_style["ui_family"] = str(family["id"])
		gen2_config["style"] = gen2_style
		gen2_config = ProceduralEngineScript.normalize_os(gen2_config)
		if int(gen2_config.get("generation", 0)) != 2:
			_fail("Gen 2 family configuration did not remain in Generation 2.")
			return
		if str(gen2_config.get("style", {}).get("identity", "")) != str(family["identity"]):
			_fail("Gen 2 " + str(family["id"]) + " family identity is incorrect.")
			return
		if not ProceduralEngineScript.validate_os(gen2_config).is_empty():
			_fail("Gen 2 " + str(family["id"]) + " configuration failed validation.")
			return

		var gen2_assets := {
			"lock_screen": "lock.jpg",
			"home_screen": "home.jpg",
			"app_drawer": "appdrawer.jpg",
			"control_center": "controlcenter.jpg",
			"notifications": str(family["notifications_file"]),
			"recent_apps": "recent.jpg"
		}
		for component_id in gen2_assets:
			var expected_gen2_path := "res://assets/os/gen2/" + str(family["folder"]) + "/" + str(gen2_assets[component_id])
			simulator.configure_os(gen2_config, str(component_id))
			await process_frame
			var gen2_node_name := str(family["prefix"]) + "Gen2ScreenImage_" + str(component_id)
			var gen2_image_node := simulator.find_child(gen2_node_name, true, false) as TextureRect
			if gen2_image_node == null or gen2_image_node.texture == null or gen2_image_node.texture.resource_path != expected_gen2_path:
				_fail("Gen 2 " + str(family["id"]) + " " + str(component_id) + " reference image failed to load: " + expected_gen2_path)
				return

		simulator.configure_os(gen2_config, "home_screen")
		await process_frame
		if simulator.find_child(str(family["prefix"]) + "Gen2NavigationHome", true, false) == null:
			_fail("Gen 2 " + str(family["id"]) + " is missing its Home navigation control.")
			return
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_home_screen", family["home_tap"])
		if _opened_apps.is_empty() or _opened_apps.back() != "Calendar":
			_fail("Gen 2 " + str(family["id"]) + " home-screen app icons are not interactive.")
			return

		simulator.configure_os(gen2_config, "app_drawer")
		await process_frame
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_app_drawer", Vector2(0.13, 0.22))
		if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
			_fail("Gen 2 " + str(family["id"]) + " app-drawer icons are not interactive.")
			return

		simulator.configure_os(gen2_config, "notifications")
		await process_frame
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_notifications", Vector2(0.20, 0.34))
		if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
			_fail("Gen 2 " + str(family["id"]) + " notification entries are not interactive.")
			return

		simulator.configure_os(gen2_config, "control_center")
		await process_frame
		var gen2_wifi_before := bool(simulator._quick_setting_states.get("Wi-Fi", false))
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_control_center", Vector2(0.25, 0.35))
		if bool(simulator._quick_setting_states.get("Wi-Fi", false)) == gen2_wifi_before:
			_fail("Gen 2 " + str(family["id"]) + " Quick Settings tiles do not update their state.")
			return
		var gen2_brightness_before := int(simulator._brightness_level)
		var gen2_brightness_test_x := 0.85 if gen2_brightness_before < 85 else 0.25
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_control_center", Vector2(gen2_brightness_test_x, 0.20))
		if int(simulator._brightness_level) == gen2_brightness_before:
			_fail("Gen 2 " + str(family["id"]) + " brightness control does not change display brightness.")
			return

		simulator.configure_os(gen2_config, "recent_apps")
		await process_frame
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_recent_apps", Vector2(0.20, 0.20))
		if _opened_apps.is_empty() or _opened_apps.back() != "Settings":
			_fail("Gen 2 " + str(family["id"]) + " recent-app reference cards are not interactive.")
			return

		simulator.configure_os(gen2_config, "lock_screen")
		await process_frame
		for action in ["Back", "Home", "Overview"]:
			if simulator.find_child(str(family["prefix"]) + "Gen2Navigation" + action, true, false) == null:
				_fail("Gen 2 " + str(family["id"]) + " is missing the " + action + " navigation control.")
				return
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_lock_screen", Vector2(0.15, 0.92))
		if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
			_fail("Gen 2 " + str(family["id"]) + " lower-left lock shortcut did not launch Phone.")
			return
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_lock_screen", Vector2(0.85, 0.92))
		if _opened_apps.is_empty() or _opened_apps.back() != "Camera":
			_fail("Gen 2 " + str(family["id"]) + " lower-right lock shortcut did not launch Camera.")
			return
		simulator._dispatch_android_navigation("Home")
		if simulator.active_component != "lock_screen":
			_fail("Gen 2 " + str(family["id"]) + " navigation must not bypass the locked screen.")
			return
		simulator._handle_system_gesture(Vector2(simulator.size.x * 0.50, simulator.size.y * 0.82), Vector2(simulator.size.x * 0.50, simulator.size.y * 0.20), 150)
		if simulator.active_component != "home_screen":
			_fail("Gen 2 " + str(family["id"]) + " swipe-up unlock gesture did not open the home screen.")
			return

		# Top-edge swipe opens Notifications; a second downward swipe opens
		# the independently supplied Control Center reference.
		simulator._handle_system_gesture(Vector2(simulator.size.x * 0.50, 4.0), Vector2(simulator.size.x * 0.50, simulator.size.y * 0.42), 150)
		await process_frame
		if simulator.find_child("OSGestureOverlay_notifications", true, false) == null or simulator.find_child(str(family["prefix"]) + "Gen2ScreenImage_notifications", true, false) == null:
			_fail("Gen 2 " + str(family["id"]) + " top-edge swipe did not open its Notifications shade.")
			return
		simulator._handle_system_gesture(Vector2(simulator.size.x * 0.50, simulator.size.y * 0.20), Vector2(simulator.size.x * 0.50, simulator.size.y * 0.72), 150)
		await process_frame
		if simulator.find_child("OSGestureOverlay_control_center", true, false) == null or simulator.find_child(str(family["prefix"]) + "Gen2ScreenImage_control_center", true, false) == null:
			_fail("Gen 2 " + str(family["id"]) + " second shade swipe did not open its Control Center.")
			return
		var gen2_overlay_wifi_before := bool(simulator._quick_setting_states.get("Wi-Fi", false))
		_simulate_overlay_tap(simulator, str(family["prefix"]) + "Gen2ScreenImage_control_center", "control_center", Vector2(0.25, 0.35))
		if bool(simulator._quick_setting_states.get("Wi-Fi", false)) == gen2_overlay_wifi_before:
			_fail("Gen 2 " + str(family["id"]) + " shade Quick Settings are not interactive.")
			return
		simulator._close_gesture_overlay()

		simulator.configure_os(gen2_config, "home_screen")
		await process_frame
		simulator._dispatch_android_navigation("Overview")
		await process_frame
		if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
			_fail("Gen 2 " + str(family["id"]) + " Overview did not open the live recent-apps task interface.")
			return
		var gen2_clear_all := simulator.find_child("Gen1FamilyClearAllRecentApps", true, false) as Button
		if gen2_clear_all == null:
			_fail("Gen 2 " + str(family["id"]) + " Overview is missing Clear all.")
			return
		gen2_clear_all.pressed.emit()
		await process_frame
		if not simulator._recent_app_names.is_empty():
			_fail("Gen 2 " + str(family["id"]) + " Clear all did not remove recent tasks.")
			return
		simulator._dispatch_android_navigation("Back")
		await process_frame


	# Gen 3 Android 8 Oreo: each manufacturer family has its own six reference
	# images, while navigation, gestures, app launching, quick settings and recents
	# reuse the interaction model proven by Gen 1.
	var gen3_families: Array[Dictionary] = [
		{
			"id": "samsung_experience9",
			"prefix": "Samsung",
			"folder": "samsung",
			"identity": "Samsung Experience 9.0 · Android 8 Oreo",
			"home_tap": Vector2(0.13, 0.34)
		},
		{
			"id": "google_pixel8",
			"prefix": "Pixel",
			"folder": "pixel",
			"identity": "Google Pixel Launcher · Android 8 Oreo",
			"home_tap": Vector2(0.13, 0.57)
		},
		{
			"id": "xiaomi_miui9",
			"prefix": "Xiaomi",
			"folder": "miui",
			"identity": "Xiaomi MIUI 9.5 · Android 8.1 Oreo",
			"home_tap": Vector2(0.13, 0.34)
		}
	]
	for family_index in range(gen3_families.size()):
		var family: Dictionary = gen3_families[family_index]
		var gen3_config := ProceduralEngineScript.generate_os(8301 + family_index, 3)
		var gen3_style: Dictionary = gen3_config.get("style", {}).duplicate(true)
		gen3_style["ui_family"] = str(family["id"])
		gen3_config["style"] = gen3_style
		gen3_config = ProceduralEngineScript.normalize_os(gen3_config)
		if int(gen3_config.get("generation", 0)) != 2:
			_fail("Gen 3 family configuration did not remain in Generation 3.")
			return
		if str(gen3_config.get("style", {}).get("identity", "")) != str(family["identity"]):
			_fail("Gen 3 " + str(family["id"]) + " family identity is incorrect.")
			return
		if not ProceduralEngineScript.validate_os(gen3_config).is_empty():
			_fail("Gen 3 " + str(family["id"]) + " configuration failed validation.")
			return

		var gen3_assets := {
			"lock_screen": "lock.jpg",
			"home_screen": "home.jpg",
			"app_drawer": "appdrawer.jpg",
			"control_center": "controlcenter.jpg",
			"notifications": "notification.jpg",
			"recent_apps": "recent.jpg"
		}
		if str(family["id"]) == "google_pixel8":
			gen3_assets["lock_screen"] = "lockscreen.jpg"
		elif str(family["id"]) == "xiaomi_miui9":
			gen3_assets["recent_apps"] = "recents.jpg"
		for component_id in gen3_assets:
			var expected_gen3_path := "res://assets/os/gen3/" + str(family["folder"]) + "/" + str(gen3_assets[component_id])
			simulator.configure_os(gen3_config, str(component_id))
			await process_frame
			var gen3_node_name := str(family["prefix"]) + "Gen3ScreenImage_" + str(component_id)
			var gen3_image_node := simulator.find_child(gen3_node_name, true, false) as TextureRect
			if gen3_image_node == null or gen3_image_node.texture == null or gen3_image_node.texture.resource_path != expected_gen3_path:
				_fail("Gen 3 " + str(family["id"]) + " " + str(component_id) + " reference image failed to load: " + expected_gen3_path)
				return

		simulator.configure_os(gen3_config, "home_screen")
		await process_frame
		if simulator.find_child(str(family["prefix"]) + "Gen3NavigationHome", true, false) == null:
			_fail("Gen 3 " + str(family["id"]) + " is missing its Home navigation control.")
			return
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_home_screen", family["home_tap"])
		if _opened_apps.is_empty() or _opened_apps.back() != "Calendar":
			_fail("Gen 3 " + str(family["id"]) + " home-screen app icons are not interactive.")
			return

		simulator.configure_os(gen3_config, "app_drawer")
		await process_frame
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_app_drawer", Vector2(0.13, 0.22))
		if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
			_fail("Gen 3 " + str(family["id"]) + " app-drawer icons are not interactive.")
			return

		simulator.configure_os(gen3_config, "notifications")
		await process_frame
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_notifications", Vector2(0.20, 0.34))
		if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
			_fail("Gen 3 " + str(family["id"]) + " notification entries are not interactive.")
			return

		simulator.configure_os(gen3_config, "control_center")
		await process_frame
		var gen3_wifi_before := bool(simulator._quick_setting_states.get("Wi-Fi", false))
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_control_center", Vector2(0.25, 0.35))
		if bool(simulator._quick_setting_states.get("Wi-Fi", false)) == gen3_wifi_before:
			_fail("Gen 3 " + str(family["id"]) + " Quick Settings tiles do not update their state.")
			return
		var gen3_brightness_before := int(simulator._brightness_level)
		var gen3_brightness_test_x := 0.85 if gen3_brightness_before < 85 else 0.25
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_control_center", Vector2(gen3_brightness_test_x, 0.20))
		if int(simulator._brightness_level) == gen3_brightness_before:
			_fail("Gen 3 " + str(family["id"]) + " brightness control does not change display brightness.")
			return

		simulator.configure_os(gen3_config, "recent_apps")
		await process_frame
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_recent_apps", Vector2(0.20, 0.20))
		if _opened_apps.is_empty() or _opened_apps.back() != "Settings":
			_fail("Gen 3 " + str(family["id"]) + " recent-app reference cards are not interactive.")
			return

		simulator.configure_os(gen3_config, "lock_screen")
		await process_frame
		for action in ["Back", "Home", "Overview"]:
			if simulator.find_child(str(family["prefix"]) + "Gen3Navigation" + action, true, false) == null:
				_fail("Gen 3 " + str(family["id"]) + " is missing the " + action + " navigation control.")
				return
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_lock_screen", Vector2(0.15, 0.92))
		if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
			_fail("Gen 3 " + str(family["id"]) + " lower-left lock shortcut did not launch Phone.")
			return
		_opened_apps.clear()
		_simulate_screenshot_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_lock_screen", Vector2(0.85, 0.92))
		if _opened_apps.is_empty() or _opened_apps.back() != "Camera":
			_fail("Gen 3 " + str(family["id"]) + " lower-right lock shortcut did not launch Camera.")
			return
		simulator._dispatch_android_navigation("Home")
		if simulator.active_component != "lock_screen":
			_fail("Gen 3 " + str(family["id"]) + " navigation must not bypass the locked screen.")
			return
		simulator._handle_system_gesture(Vector2(simulator.size.x * 0.50, simulator.size.y * 0.82), Vector2(simulator.size.x * 0.50, simulator.size.y * 0.20), 150)
		if simulator.active_component != "home_screen":
			_fail("Gen 3 " + str(family["id"]) + " swipe-up unlock gesture did not open the home screen.")
			return

		# Top-edge swipe opens Notifications; a second downward swipe opens
		# the independently supplied Control Center reference.
		simulator._handle_system_gesture(Vector2(simulator.size.x * 0.50, 4.0), Vector2(simulator.size.x * 0.50, simulator.size.y * 0.42), 150)
		await process_frame
		if simulator.find_child("OSGestureOverlay_notifications", true, false) == null or simulator.find_child(str(family["prefix"]) + "Gen3ScreenImage_notifications", true, false) == null:
			_fail("Gen 3 " + str(family["id"]) + " top-edge swipe did not open its Notifications shade.")
			return
		simulator._handle_system_gesture(Vector2(simulator.size.x * 0.50, simulator.size.y * 0.20), Vector2(simulator.size.x * 0.50, simulator.size.y * 0.72), 150)
		await process_frame
		if simulator.find_child("OSGestureOverlay_control_center", true, false) == null or simulator.find_child(str(family["prefix"]) + "Gen3ScreenImage_control_center", true, false) == null:
			_fail("Gen 3 " + str(family["id"]) + " second shade swipe did not open its Control Center.")
			return
		var gen3_overlay_wifi_before := bool(simulator._quick_setting_states.get("Wi-Fi", false))
		_simulate_overlay_tap(simulator, str(family["prefix"]) + "Gen3ScreenImage_control_center", "control_center", Vector2(0.25, 0.35))
		if bool(simulator._quick_setting_states.get("Wi-Fi", false)) == gen3_overlay_wifi_before:
			_fail("Gen 3 " + str(family["id"]) + " shade Quick Settings are not interactive.")
			return
		simulator._close_gesture_overlay()

		simulator.configure_os(gen3_config, "home_screen")
		await process_frame
		simulator._dispatch_android_navigation("Overview")
		await process_frame
		if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
			_fail("Gen 3 " + str(family["id"]) + " Overview did not open the live recent-apps task interface.")
			return
		var gen3_clear_all := simulator.find_child("Gen1FamilyClearAllRecentApps", true, false) as Button
		if gen3_clear_all == null:
			_fail("Gen 3 " + str(family["id"]) + " Overview is missing Clear all.")
			return
		gen3_clear_all.pressed.emit()
		await process_frame
		if not simulator._recent_app_names.is_empty():
			_fail("Gen 3 " + str(family["id"]) + " Clear all did not remove recent tasks.")
			return
		simulator._dispatch_android_navigation("Back")
		await process_frame

	root.remove_child(simulator_host)
	simulator_host.free()
	await process_frame
	print("OS_GENERATOR_SMOKE_TEST: PASS")
	quit(0)

func _simulate_screenshot_tap(simulator, node_name: String, normalized_position: Vector2) -> void:
	var screenshot := simulator.find_child(node_name, true, false) as TextureRect
	if screenshot == null:
		_fail("Cannot simulate tap; screenshot node is missing: " + node_name)
		return
	var rectangle := screenshot.get_global_rect()
	var canvas_position := rectangle.position + rectangle.size * normalized_position
	var local_position: Vector2 = simulator.get_global_transform_with_canvas().affine_inverse() * canvas_position
	simulator._handle_gen1_screen_tap(local_position)

func _simulate_overlay_tap(simulator, node_name: String, component_id: String, normalized_position: Vector2) -> void:
	var screenshot := simulator.find_child(node_name, true, false) as TextureRect
	if screenshot == null:
		_fail("Cannot simulate overlay tap; screenshot node is missing: " + node_name)
		return
	var rectangle := screenshot.get_global_rect()
	var canvas_position := rectangle.position + rectangle.size * normalized_position
	var local_position: Vector2 = simulator.get_global_transform_with_canvas().affine_inverse() * canvas_position
	simulator._handle_gen1_overlay_tap(component_id, local_position)

func _capture_app_opened(app_name: String) -> void:
	_opened_apps.append(app_name)

func _fail(message: String) -> void:
	push_error("OS_GENERATOR_SMOKE_TEST: " + message)
	quit(1)
