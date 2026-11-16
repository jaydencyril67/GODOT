extends SceneTree

const ProceduralEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const SimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")

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
		var image_node := simulator.find_child("SamsungGen1ScreenImage_" + str(component_id), true, false) as TextureRect
		var expected_path := "res://assets/os/gen1/samsung/" + str(samsung_assets[component_id])
		if image_node == null or image_node.texture == null or image_node.texture.resource_path != expected_path:
			_fail("Gen 1 Samsung " + str(component_id) + " reference image failed to load: " + expected_path)
			return

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
		simulator.configure_os(pixel_config, str(component_id))
		await process_frame
		var image_node := simulator.find_child("PixelGen1ScreenImage_" + str(component_id), true, false) as TextureRect
		var expected_path := "res://assets/os/gen1/pixel/" + str(pixel_assets[component_id])
		if image_node == null or image_node.texture == null or image_node.texture.resource_path != expected_path:
			_fail("Gen 1 Google Stock Android 4 " + str(component_id) + " reference image failed to load: " + expected_path)
			return

	var xiaomi_config := ProceduralEngineScript.generate_os(8103, 1)
	xiaomi_config["style"]["ui_family"] = "xiaomi_miui"
	xiaomi_config = ProceduralEngineScript.normalize_os(xiaomi_config)
	if int(xiaomi_config.get("generation", 0)) != 1 or str(xiaomi_config.get("style", {}).get("identity", "")) != "Xiaomi MIUI (Android 4.0 era)":
		_fail("Xiaomi MIUI must remain an independent Gen 1 UI family.")
		return
	simulator.configure_os(xiaomi_config, "home_screen")
	await process_frame
	if simulator.find_child("XiaomiGen1ReferencePending_home_screen", true, false) == null:
		_fail("Gen 1 Xiaomi MIUI family configuration was not loaded.")
		return

	root.remove_child(simulator_host)
	simulator_host.free()
	await process_frame
	print("GEN1_OS_GENERATOR_SMOKE_TEST: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("GEN1_OS_GENERATOR_SMOKE_TEST: " + message)
	quit(1)
