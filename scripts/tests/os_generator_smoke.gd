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
	_simulate_screenshot_tap(simulator, "PixelGen1ScreenImage_app_drawer", Vector2(0.13, 0.245))
	if _opened_apps.is_empty() or _opened_apps.back() != "Phone":
		_fail("Google Stock Android 4 app-drawer icons are not interactive.")
		return

	simulator.configure_os(pixel_config, "lock_screen")
	await process_frame
	if simulator.find_child("AndroidNavigationBar", true, false) == null:
		_fail("Google Stock Android 4 lock screen is missing its system navigation bar.")
		return
	simulator._handle_system_gesture(Vector2(0.30, 180.0), Vector2(0.80, 180.0), 150)
	if simulator.active_component != "home_screen":
		_fail("Google Stock Android 4 slide-to-unlock gesture did not enter the home screen.")
		return

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

	simulator.configure_os(xiaomi_config, "lock_screen")
	await process_frame
	if simulator.find_child("AndroidNavigationBar", true, false) == null:
		_fail("Xiaomi MIUI V4 lock screen is missing its system navigation bar.")
		return
	simulator._handle_system_gesture(Vector2(0.30, 310.0), Vector2(0.80, 310.0), 150)
	if simulator.active_component != "home_screen":
		_fail("Xiaomi MIUI V4 slide-to-unlock gesture did not enter the home screen.")
		return

	simulator._dispatch_android_navigation("Overview")
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null or simulator.find_child("Gen1FamilyRecentApps", true, false) == null:
		_fail("Xiaomi MIUI V4 Overview navigation did not open the live recent-apps interface.")
		return
	simulator._navigate_back()

	root.remove_child(simulator_host)
	simulator_host.free()
	await process_frame
	print("GEN1_OS_GENERATOR_SMOKE_TEST: PASS")
	quit(0)

func _simulate_screenshot_tap(simulator, node_name: String, normalized_position: Vector2) -> void:
	var screenshot := simulator.find_child(node_name, true, false) as TextureRect
	if screenshot == null:
		_fail("Cannot simulate tap; screenshot node is missing: " + node_name)
		return
	var rectangle := screenshot.get_global_rect()
	var canvas_position := rectangle.position + rectangle.size * normalized_position
	var local_position := simulator.get_global_transform_with_canvas().affine_inverse() * canvas_position
	simulator._handle_gen1_screen_tap(local_position)

func _simulate_overlay_tap(simulator, node_name: String, component_id: String, normalized_position: Vector2) -> void:
	var screenshot := simulator.find_child(node_name, true, false) as TextureRect
	if screenshot == null:
		_fail("Cannot simulate overlay tap; screenshot node is missing: " + node_name)
		return
	var rectangle := screenshot.get_global_rect()
	var canvas_position := rectangle.position + rectangle.size * normalized_position
	var local_position := simulator.get_global_transform_with_canvas().affine_inverse() * canvas_position
	simulator._handle_gen1_overlay_tap(component_id, local_position)

func _capture_app_opened(app_name: String) -> void:
	_opened_apps.append(app_name)

func _fail(message: String) -> void:
	push_error("GEN1_OS_GENERATOR_SMOKE_TEST: " + message)
	quit(1)
