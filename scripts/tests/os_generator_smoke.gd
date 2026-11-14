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
	var expected_widgets := [0, 2, 4]
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

	generated["components"]["home_screen"]["layout_style"] = "ios_grid"
	var simulator := SimulatorScript.new()
	simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simulator.configure_os(generated, "home_screen")
	simulator_host.add_child(simulator)
	await process_frame

	for generation_number in range(1, 4):
		var generation_preview := ProceduralEngineScript.generate_os(8100 + generation_number, generation_number)
		simulator.configure_os(generation_preview, "home_screen")
		await process_frame
		var rendered_widget_count := 0
		for widget_name in ["HomeWidget_Clock", "HomeWidget_Weather", "HomeWidget_Calendar", "HomeWidget_Music"]:
			if simulator.find_child(widget_name, true, false) != null:
				rendered_widget_count += 1
		if rendered_widget_count != expected_widgets[generation_number - 1]:
			_fail("Simulator rendered the wrong number of widgets for generation %d." % generation_number)
			return
	for layout_style in ProceduralEngineScript.HOME_LAYOUT_STYLES:
		var layout_config := generated.duplicate(true)
		layout_config["components"]["home_screen"]["layout_style"] = layout_style
		simulator.configure_os(layout_config, "home_screen")
		await process_frame
		match layout_style:
			"windows_tiles":
				if simulator.find_child("WindowsLiveTileGrid", true, false) == null:
					_fail("Windows tile layout did not render its live-tile grid.")
					return
				if simulator.find_child("HomeAppDock", true, false) != null:
					_fail("Windows tile layout incorrectly rendered the standard app dock.")
					return
			"compact_list":
				if simulator.find_child("HomeAppList", true, false) == null:
					_fail("Compact list layout did not render its app list.")
					return
			"category_sections":
				if simulator.find_child("HomeCategory_COMMUNICATIONGrid", true, false) == null:
					_fail("Category layout did not render grouped app sections.")
					return
			_:
				if simulator.find_child("HomeAppGrid", true, false) == null:
					_fail("Grid layout did not render its app grid: " + layout_style)
					return
	simulator.configure_os(generated, "home_screen")
	await process_frame

	# Exercise the same gesture router used by touch and mouse input.
	_simulate_touch_swipe(simulator, Vector2(60, 2), Vector2(60, 70), 100)
	await process_frame
	if simulator.find_child("OSGestureOverlay_notifications", true, false) == null:
		_fail("Top-left swipe did not open the notification panel.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 180), Vector2(72, 90), 100)
	await process_frame
	if simulator.find_child("OSGestureOverlay_notifications", true, false) != null:
		_fail("Swipe-up gesture did not dismiss the notification panel.")
		return
	simulator.call("_handle_system_gesture", Vector2(140, 2), Vector2(140, 70), 100)
	await process_frame
	if simulator.find_child("GestureQuickSettingsGrid", true, false) == null:
		_fail("Top-right swipe did not open Control Center quick settings.")
		return
	simulator.call("_close_gesture_overlay")
	simulator.call("_handle_system_gesture", Vector2(72, 358), Vector2(72, 280), 120)
	await process_frame
	if simulator.get("active_component") != "app_drawer":
		_fail("Bottom swipe up from Home did not open the App Drawer.")
		return
	simulator.call("_handle_system_gesture", Vector2(2, 170), Vector2(70, 170), 100)
	await process_frame
	if simulator.get("active_component") != "home_screen":
		_fail("Edge swipe back did not return from App Drawer to Home.")
		return
	simulator.call("_handle_system_gesture", Vector2(72, 358), Vector2(72, 280), 600)
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) == null:
		_fail("Long bottom swipe did not open Recent Apps.")
		return
	simulator.call("_close_gesture_overlay")
	await process_frame
	if simulator.find_child("OSGestureOverlay_recent_apps", true, false) != null:
		_fail("Recent Apps overlay did not close cleanly.")
		return
	simulator.set_component_view("home_screen")
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
		if component_id == "control_center":
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
			var drawer_grid := simulator.find_child("AppDrawerGrid", true, false) as GridContainer
			if search_field == null or drawer_grid == null:
				_fail("App Drawer search field or icon grid was not attached to the visible UI tree.")
				return
			if drawer_grid.get_child_count() != 30:
				_fail("App Drawer did not render all 30 installed applications.")
				return
			search_field.text_changed.emit("Settings")
			await process_frame
			if drawer_grid.get_child_count() != 1:
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
	if worksite.find_child("BootLoaderOnlyControls", true, false) == null:
		_fail("Step 1 right panel must contain the Boot Loader controls.")
		return
	for obsolete_control in ["OSGeneratorControlsViewport", "ProceduralOSGeneratorControls", "OSGenerationSelector", "OSComponentSelector", "GenerateCompleteOSButton", "RegenerateOSComponentButton", "SelectGeneratedOSButton"]:
		if worksite.find_child(obsolete_control, true, false) != null:
			_fail("Old OS generator UI is still visible in Step 1: " + obsolete_control)
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
	worksite.call("_on_power_button_pressed")
	if not boot_overlay.visible:
		_fail("Power button did not switch the display into its boot sequence.")
		return
	var boot_debug_panel := worksite.find_child("BootDebugPanel", true, false) as PanelContainer
	var boot_debug_label := worksite.find_child("BootDebugText", true, false) as Label
	if boot_debug_panel == null or boot_debug_label == null or not boot_debug_panel.visible:
		_fail("Boot diagnostics panel was not visible while the phone was booting.")
		return
	if not boot_debug_label.text.contains("RAW SAVED INPUT") or not boot_debug_label.text.contains("RESOLVED IDENTITY"):
		_fail("Boot diagnostics did not report the incoming and resolved phone identity.")
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
	if boot_model_label.get_theme_font_size("font_size") != 14:
		_fail("Phone model must use the smaller secondary boot identity typography.")
		return
	await worksite.boot_completed
	var boot_elapsed := Time.get_ticks_msec() - boot_started_at
	if boot_elapsed < 9900 or boot_elapsed > 10500:
		_fail("Boot sequence did not complete in ten real-world seconds (%d ms)." % boot_elapsed)
		return
	if boot_overlay.visible or not worksite_preview.visible:
		_fail("Completed boot did not reveal the generated OS home screen.")
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
