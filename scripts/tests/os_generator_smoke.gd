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

	var legacy_media_config := generated.duplicate(true)
	legacy_media_config["schema_version"] = 5
	legacy_media_config["components"]["lock_screen"]["show_audio_player"] = false
	var migrated_media := ProceduralEngineScript.normalize_os(legacy_media_config)
	if not bool(migrated_media["components"]["lock_screen"].get("show_audio_player", false)):
		_fail("Legacy lock-screen configuration did not migrate to the visible media player.")
		return

	if ProceduralEngineScript.LOCK_SCREEN_LAYOUT_TEMPLATES.size() != 20:
		_fail("Lock-screen system must expose exactly 20 structural layout templates.")
		return
	var simulator_host := Control.new()
	simulator_host.name = "OSSimulatorResponsiveTestHost"
	simulator_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	simulator_host.size = Vector2(145.0, 360.0)
	root.add_child(simulator_host)

	var template_preview := SimulatorScript.new()
	template_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simulator_host.add_child(template_preview)
	var observed_templates := {}
	for template_index in range(ProceduralEngineScript.LOCK_SCREEN_LAYOUT_TEMPLATES.size()):
		var template_name := str(ProceduralEngineScript.LOCK_SCREEN_LAYOUT_TEMPLATES[template_index])
		var template_config := generated.duplicate(true)
		template_config["components"]["lock_screen"]["layout_template"] = template_name
		template_preview.configure_os(template_config, "lock_screen")
		await process_frame
		await process_frame
		var layout_root := template_preview.find_child("LockScreenLayout_" + template_name, true, false)
		if layout_root == null:
			_fail("A lock-screen template did not render its own layout root: " + template_name)
			return
		var status_bar := template_preview.find_child("OSStatusBar", true, false) as Control
		var status_clock := template_preview.find_child("StatusBarClock", true, false) as Label
		var status_indicators := template_preview.find_child("StatusBarSystemIndicators", true, false) as Control
		var clock_stage := template_preview.find_child("LockScreenProtectedClockStage", true, false) as Control
		var lock_clock := template_preview.find_child("LockScreenClock", true, false) as Label
		var lock_date := template_preview.find_child("LockScreenDate", true, false) as Label
		if status_bar == null or not status_bar.visible or status_bar.size.y < 15.0:
			_fail("Lock-screen status bar is missing or has no visible height: " + template_name)
			return
		if status_clock == null or status_clock.text.strip_edges().is_empty() or status_clock.size.x <= 0.0:
			_fail("Lock-screen status-bar time is missing or invisible: " + template_name)
			return
		if status_indicators == null or status_indicators.size.x < 45.0:
			_fail("Samsung-style cellular, Wi-Fi and battery indicators are missing: " + template_name)
			return
		if clock_stage == null or lock_clock == null or not clock_stage.is_ancestor_of(lock_clock):
			_fail("Lock-screen clock escaped its protected clock stage: " + template_name)
			return
		if lock_clock.size.x <= 0.0 or lock_clock.position.x < -1.0 or lock_clock.position.x + lock_clock.size.x > clock_stage.size.x + 1.0:
			_fail("Lock-screen clock is clipped horizontally: " + template_name)
			return
		if lock_clock == null or lock_clock.text.strip_edges().is_empty() or lock_clock.size.y < 20.0:
			_fail("Lock-screen main clock is missing or has no visible height: " + template_name)
			return
		if lock_date == null or lock_date.text.strip_edges().is_empty():
			_fail("Lock-screen date is missing: " + template_name)
			return
		var structure_signature := ""
		for layout_child in layout_root.get_children():
			structure_signature += "%s:%s|" % [layout_child.name, layout_child.get_class()]
		if observed_templates.has(structure_signature):
			_fail("Two lock-screen templates share the same structural composition: " + template_name)
			return
		observed_templates[structure_signature] = true
	if observed_templates.size() != 20:
		_fail("The 20 lock-screen templates did not produce 20 distinct layout roots.")
		return
	simulator_host.remove_child(template_preview)
	template_preview.free()
	await process_frame

	var lock_screen_before: Dictionary = components["lock_screen"].duplicate(true)
	var wallpaper_regenerated := ProceduralEngineScript.regenerate_component(generated, "wallpapers", 246802)
	var wallpaper_components: Dictionary = wallpaper_regenerated["components"]
	var lock_screen_after: Dictionary = wallpaper_components["lock_screen"]
	var selected_wallpaper := str(wallpaper_regenerated["style"]["wallpaper"])
	if not ProceduralEngineScript.WALLPAPER_STYLES.has(selected_wallpaper):
		_fail("Wallpaper regeneration selected an unsupported wallpaper style.")
		return
	if lock_screen_after["design_family"] != lock_screen_before["design_family"] or lock_screen_after["clock_treatment"] != lock_screen_before["clock_treatment"] or lock_screen_after["show_notifications"] != lock_screen_before["show_notifications"]:
		_fail("Wallpaper regeneration unexpectedly changed lock screen design settings.")
		return
	if selected_wallpaper != wallpaper_components["home_screen"]["wallpaper"] or selected_wallpaper != lock_screen_after["wallpaper"] or selected_wallpaper != wallpaper_components["wallpapers"]["style"]:
		_fail("Wallpaper regeneration did not keep the OS wallpaper synchronized.")
		return

	var lock_candidate := generated.duplicate(true)
	var lock_candidate_data: Dictionary = lock_candidate["components"]["lock_screen"]
	lock_candidate_data["show_audio_player"] = true
	lock_candidate_data["show_camera_shortcut"] = false
	lock_candidate_data["fingerprint_sensor_available"] = true
	lock_candidate_data["show_fingerprint"] = true
	var lock_design_before := str(lock_candidate_data.get("design_family", ""))
	var lock_wallpaper_before := str(lock_candidate["style"]["wallpaper"])
	var lock_redesigned := ProceduralEngineScript.regenerate_component(lock_candidate, "lock_screen", 246803)
	var lock_design_after: Dictionary = lock_redesigned["components"]["lock_screen"]
	if str(lock_design_after.get("design_family", "")) == lock_design_before:
		_fail("Lock-screen generator repeated the previous design family.")
		return
	if str(lock_design_after.get("layout_template", "")) == str(lock_candidate_data.get("layout_template", "")):
		_fail("Lock-screen generator repeated the previous structural template.")
		return
	if str(lock_redesigned["style"]["wallpaper"]) != lock_wallpaper_before or str(lock_design_after.get("wallpaper", "")) != lock_wallpaper_before:
		_fail("Lock-screen generation changed the independently managed wallpaper.")
		return
	if not bool(lock_design_after.get("show_audio_player", false)) or bool(lock_design_after.get("show_camera_shortcut", true)) or not bool(lock_design_after.get("show_fingerprint", false)):
		_fail("Lock-screen generation did not preserve the player's selected features.")
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

	generated["components"]["home_screen"]["layout_style"] = "ios_grid"
	var simulator := SimulatorScript.new()
	simulator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	simulator.configure_os(generated, "home_screen")
	simulator_host.add_child(simulator)
	await process_frame

	var lock_preview_config := generated.duplicate(true)
	var lock_preview_data: Dictionary = lock_preview_config["components"]["lock_screen"]
	lock_preview_data["show_notifications"] = true
	lock_preview_data["show_audio_player"] = true
	lock_preview_data["show_camera_shortcut"] = true
	lock_preview_data["show_flashlight_shortcut"] = true
	lock_preview_data["fingerprint_sensor_available"] = true
	lock_preview_data["show_fingerprint"] = true
	lock_preview_data["show_unlock_hint"] = true
	simulator.configure_os(lock_preview_config, "lock_screen")
	await process_frame
	for lock_control_name in ["LockScreenClock", "LockScreenDate", "LockScreenNotification_Messages", "LockScreenAudioPlayer", "LockScreenShortcut_Camera", "LockScreenShortcut_Flashlight", "LockScreenFingerprintSensor", "UnlockOSButton"]:
		if simulator.find_child(lock_control_name, true, false) == null:
			_fail("Lock screen did not render enabled feature: " + lock_control_name)
			return
	for lock_content_name in ["LockScreenNotificationApp_Messages", "LockScreenNotificationMessage_Messages", "LockScreenAudioTrackTitle", "LockScreenAudioArtist", "StatusBarClock"]:
		if simulator.find_child(lock_content_name, true, false) == null:
			_fail("Lock screen rendered an empty content surface; missing: " + lock_content_name)
			return
	var rendered_track_title := simulator.find_child("LockScreenAudioTrackTitle", true, false) as Label
	var rendered_message := simulator.find_child("LockScreenNotificationMessage_Messages", true, false) as Label
	var rendered_status_clock := simulator.find_child("StatusBarClock", true, false) as Label
	var rendered_lock_clock := simulator.find_child("LockScreenClock", true, false) as Label
	if rendered_track_title == null or rendered_track_title.text.strip_edges().is_empty() or rendered_message == null or rendered_message.text.strip_edges().is_empty():
		_fail("Lock-screen media or notification content is blank.")
		return
	if rendered_status_clock == null or rendered_status_clock.text.strip_edges().is_empty() or rendered_lock_clock == null or rendered_lock_clock.text.strip_edges().is_empty():
		_fail("Lock-screen status time or main lock-screen clock is blank.")
		return
	if rendered_track_title.size.x <= 0.0 or rendered_message.size.x <= 0.0:
		_fail("Lock-screen notification/media text has no visible horizontal space.")
		return
	var lock_gesture_position := Vector2(72, 180)
	simulator.call("_handle_system_gesture", lock_gesture_position, Vector2(72, 105), 180)
	await process_frame
	if simulator.get("active_component") != "home_screen":
		_fail("Upward swipe did not unlock the lock screen.")
		return
	simulator.set_component_view("home_screen")
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
	var initial_step_label := worksite.find_child("OSWorksiteProgress", true, false).get_child(0) as Label
	if initial_step_label == null or initial_step_label.text != "STEP 1 / 2":
		_fail("Boot Loader must be explicitly identified as Step 1 of 2.")
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
	await worksite.boot_completed
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
	if completed_step_label == null or completed_step_label.text != "STEP 2 / 2":
		_fail("Lock Screen Studio must appear as Step 2 after boot completes.")
		return
	worksite.call("_on_wizard_back_pressed")
	await process_frame
	if worksite.find_child("BootLoaderOnlyControls", true, false) == null or worksite.find_child("LockScreenStudioControls", true, false) != null:
		_fail("Wizard Back did not return exclusively to Boot Loader Step 1.")
		return
	worksite.call("_on_next_pressed")
	await process_frame
	if worksite.find_child("LockScreenStudioControls", true, false) == null:
		_fail("Wizard Next did not return to Lock Screen Studio Step 2.")
		return

	worksite.call("set_fingerprint_sensor_available", true)
	worksite.call("_on_lock_screen_feature_toggled", true, "show_audio_player")
	worksite.call("_on_lock_screen_feature_toggled", true, "show_fingerprint")
	await process_frame
	if worksite_preview.find_child("LockScreenAudioPlayer", true, false) == null or worksite_preview.find_child("LockScreenFingerprintSensor", true, false) == null:
		_fail("Enabling audio or available fingerprint hardware did not update the lock-screen preview.")
		return
	var fingerprint_sensor := worksite_preview.find_child("LockScreenFingerprintSensor", true, false) as Button
	var fingerprint_stage := worksite_preview.find_child("LockScreenFingerprintStage", true, false) as CenterContainer
	if fingerprint_sensor == null or fingerprint_sensor.size != Vector2(52, 52) or fingerprint_stage == null or not fingerprint_stage.is_ancestor_of(fingerprint_sensor):
		_fail("Under-display fingerprint indicator is missing its centred Samsung-style sensor target.")
		return
	var generator_button := worksite.find_child("GenerateLockScreenDesignButton", true, false) as Button
	if generator_button == null:
		_fail("Lock-screen design generator button is missing.")
		return
	var wallpaper_before_generation := str(worksite.get("generated_os_configuration")["style"]["wallpaper"])
	var family_before_generation := str(worksite.get("generated_os_configuration")["components"]["lock_screen"]["design_family"])
	generator_button.pressed.emit()
	await process_frame
	var worksite_configuration: Dictionary = worksite.get("generated_os_configuration")
	var generated_lock_data: Dictionary = worksite_configuration["components"]["lock_screen"]
	if str(generated_lock_data.get("design_family", "")) == family_before_generation:
		_fail("Generate button did not create a new lock-screen design family.")
		return
	if str(worksite_configuration["style"]["wallpaper"]) != wallpaper_before_generation or str(generated_lock_data.get("wallpaper", "")) != wallpaper_before_generation:
		_fail("Lock-screen generator changed the wallpaper.")
		return
	if not bool(generated_lock_data.get("show_audio_player", false)) or not bool(generated_lock_data.get("show_fingerprint", false)):
		_fail("Lock-screen generator did not preserve enabled functionality.")
		return
	if worksite_configuration.get("components", {}).size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("Generate OS action did not produce all 6 core components.")
		return
	if worksite_preview.get("configuration").get("components", {}).size() != ProceduralEngineScript.COMPONENTS.size():
		_fail("Generate OS action did not refresh the visible simulator.")
		return
	root.remove_child(worksite)
	worksite.free()
	await process_frame
	await process_frame
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
