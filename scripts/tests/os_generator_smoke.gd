extends SceneTree

const ProceduralEngineScript = preload("res://scripts/os/procedural_os_engine.gd")
const SimulatorScript = preload("res://scripts/os/os_preview_simulator.gd")
const WorksiteScene = preload("res://scenes/os_creation_worksite.tscn")

func _initialize() -> void:
	call_deferred("_run_os_generator_test")

func _run_os_generator_test() -> void:
	var generated := ProceduralEngineScript.generate_os(1357911, 2)
	var components: Dictionary = generated.get("components", {})
	if generated.get("schema_version", 0) != ProceduralEngineScript.SCHEMA_VERSION:
		_fail("Generated OS did not use the current configuration schema.")
		return
	if components.size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("Generator did not produce all 6 core OS components.")
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

	var lock_screen_before: Dictionary = components["lock_screen"].duplicate(true)
	var wallpaper_regenerated := ProceduralEngineScript.regenerate_component(generated, "wallpapers", 246802)
	var wallpaper_components: Dictionary = wallpaper_regenerated["components"]
	var lock_screen_after: Dictionary = wallpaper_components["lock_screen"]
	var selected_wallpaper := str(wallpaper_regenerated["style"]["wallpaper"])
	if not ProceduralEngineScript.WALLPAPER_STYLES.has(selected_wallpaper):
		_fail("Wallpaper regeneration selected an unsupported wallpaper style.")
		return
	if lock_screen_after["clock_style"] != lock_screen_before["clock_style"] or lock_screen_after["show_notifications"] != lock_screen_before["show_notifications"]:
		_fail("Wallpaper regeneration unexpectedly changed lock screen layout settings.")
		return
	if selected_wallpaper != wallpaper_components["home_screen"]["wallpaper"] or selected_wallpaper != lock_screen_after["wallpaper"] or selected_wallpaper != wallpaper_components["wallpapers"]["style"]:
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

	var simulator_host := Control.new()
	simulator_host.name = "OSSimulatorResponsiveTestHost"
	simulator_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	simulator_host.size = Vector2(145.0, 360.0)
	root.add_child(simulator_host)

	var simulator := SimulatorScript.new()
	simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simulator.configure_os(generated, "home_screen")
	simulator_host.add_child(simulator)
	await process_frame
	if simulator.find_child("OSProceduralWallpaper", true, false) == null:
		_fail("Simulator did not render its procedural OS wallpaper.")
		return
	var compact_grid := simulator.find_child("HomeAppGrid", true, false) as GridContainer
	if compact_grid == null or compact_grid.columns != 2:
		_fail("Compact phone viewport did not reduce the home grid to two readable columns.")
		return
	var home_dock := simulator.find_child("HomeAppDock", true, false)
	var home_viewport := simulator.find_child("OSComponentViewport", true, false)
	if home_dock == null or home_dock.get_parent().name != "OSNavigationFooter":
		_fail("Home dock is not anchored in the fixed navigation footer.")
		return
	if home_viewport == null or home_viewport.is_ancestor_of(home_dock):
		_fail("Home dock must remain outside the scrolling app content.")
		return
	var dock_icons := simulator.find_child("HomeAppDockIcons", true, false) as HBoxContainer
	if dock_icons == null or dock_icons.get_child_count() != 4:
		_fail("Home dock did not render all four pinned app icons.")
		return
	var horizontal_app_label := simulator.find_child("AppLabel_Messages", true, false) as Label
	if horizontal_app_label == null or horizontal_app_label.autowrap_mode != TextServer.AUTOWRAP_OFF or absf(horizontal_app_label.rotation) > 0.001:
		_fail("App labels are not kept horizontal on narrow phone previews.")
		return
	simulator_host.size = Vector2(190.0, 360.0)
	await process_frame
	await process_frame
	var wide_grid := simulator.find_child("HomeAppGrid", true, false) as GridContainer
	if wide_grid == null or wide_grid.columns != 3:
		_fail("Wider phone viewport did not restore the three-column home grid.")
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
		if component_id == "app_drawer":
			var search_field := simulator.find_child("AppDrawerSearchField", true, false) as LineEdit
			var drawer_grid := simulator.find_child("AppDrawerGrid", true, false) as GridContainer
			if search_field == null or drawer_grid == null:
				_fail("App Drawer search field or icon grid was not attached to the visible UI tree.")
				return
			search_field.text_changed.emit("Settings")
			await process_frame
			if drawer_grid.get_child_count() != 1:
				_fail("App Drawer search did not filter the installed applications.")
				return
			search_field.text_changed.emit("")
			await process_frame
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
	if worksite_preview.find_child("OSProceduralWallpaper", true, false) == null:
		_fail("OS creation worksite preview did not use the procedural OS wallpaper.")
		return
	worksite.call("_generate_complete_os")
	await process_frame
	var worksite_configuration: Dictionary = worksite.get("generated_os_configuration")
	if worksite_configuration.get("components", {}).size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("Generate OS action did not produce all 6 core components.")
		return
	if worksite_preview.get("configuration").get("components", {}).size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("Generate OS action did not refresh the visible simulator.")
		return
	root.remove_child(worksite)
	worksite.free()
	await process_frame
	print("OS_GENERATOR_SMOKE_TEST: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("OS_GENERATOR_SMOKE_TEST: " + message)
	quit(1)
