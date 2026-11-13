extends SceneTree

const ProceduralEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const SimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")
const WorksiteScene = preload("res://scenes/os_creation_worksite.tscn")

func _initialize() -> void:
	call_deferred("_run_os_generator_test")

func _run_os_generator_test() -> void:
	var generated := ProceduralEngineScript.generate_os(1357911, 1)
	var components: Dictionary = generated.get("components", {})
	if components.size() != 12:
		_fail("Generator did not produce all 12 OS components.")
		return
	for component in ProceduralEngineScript.COMPONENTS:
		if not components.has(component["id"]):
			_fail("Missing generated component: " + str(component["id"]))
			return

	var lock_screen_before: Dictionary = components["lock_screen"].duplicate(true)
	var wallpaper_regenerated := ProceduralEngineScript.regenerate_component(generated, "wallpapers", 246802)
	var lock_screen_after: Dictionary = wallpaper_regenerated["components"]["lock_screen"]
	if lock_screen_after["clock_style"] != lock_screen_before["clock_style"] or lock_screen_after["show_notifications"] != lock_screen_before["show_notifications"]:
		_fail("Wallpaper regeneration unexpectedly changed lock screen layout settings.")
		return
	if wallpaper_regenerated["style"]["wallpaper"] != wallpaper_regenerated["components"]["home_screen"]["wallpaper"] or wallpaper_regenerated["style"]["wallpaper"] != lock_screen_after["wallpaper"]:
		_fail("Wallpaper regeneration did not keep home and lock screen wallpapers synchronized.")
		return

	var themed := ProceduralEngineScript.regenerate_component(generated, "themes_appearance", 97531)
	if themed["style"]["palette"] != themed["components"]["themes_appearance"]["palette"]:
		_fail("Theme regeneration did not update the shared OS palette.")
		return
	var icons := ProceduralEngineScript.regenerate_component(generated, "app_icons", 86420)
	if icons["style"]["icon_shape"] != icons["components"]["app_icons"]["shape"]:
		_fail("Icon regeneration did not update the shared OS icon shape.")
		return

	var test_save_path := "user://os_generator_smoke_test.json"
	if not ProceduralEngineScript.save_os(wallpaper_regenerated, test_save_path):
		_fail("Generated OS configuration could not be saved.")
		return
	var loaded := ProceduralEngineScript.load_os(test_save_path)
	if loaded.get("seed", -1) != wallpaper_regenerated.get("seed", -2):
		_fail("Saved OS configuration could not be loaded correctly.")
		return

	var simulator := SimulatorScript.new()
	simulator.configure_os(generated, "home_screen")
	root.add_child(simulator)
	await process_frame
	for component in ProceduralEngineScript.COMPONENTS:
		simulator.set_component_view(str(component["id"]))
		await process_frame
		if simulator.find_child("OSComponentContent", true, false) == null:
			_fail("Simulator failed to render component: " + str(component["id"]))
			return
	simulator.queue_free()

	var worksite := WorksiteScene.instantiate()
	root.add_child(worksite)
	await process_frame
	var worksite_preview := worksite.find_child("GeneratedOSPreviewSimulator", true, false)
	if worksite_preview == null:
		_fail("OS creation worksite did not mount the generated simulator screen.")
		return
	worksite.call("_generate_complete_os")
	await process_frame
	var worksite_configuration: Dictionary = worksite.get("generated_os_configuration")
	if worksite_configuration.get("components", {}).size() != 12:
		_fail("Generate OS action did not produce all 12 components.")
		return
	if worksite_preview.get("configuration").get("components", {}).size() != 12:
		_fail("Generate OS action did not refresh the visible simulator.")
		return
	worksite.queue_free()
	print("OS_GENERATOR_SMOKE_TEST: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("OS_GENERATOR_SMOKE_TEST: " + message)
	quit(1)
