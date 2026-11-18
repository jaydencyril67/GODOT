extends SceneTree

const WorksiteScript = preload("res://scripts/os_creation_worksite.gd")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var worksite: Node = WorksiteScript.new()
	worksite.name = "OSCreationBootLockScreenSmokeTest"
	root.add_child(worksite)
	for _frame_index in range(1200):
		if bool(worksite.get("setup_complete")):
			break
		await process_frame
	if not bool(worksite.get("setup_complete")):
		_fail("The OS Worksite did not finish its staged startup preparation.")
		return

	var home_screen := worksite.find_child("OneUIHomeScreenPreview", true, false)
	if home_screen == null or int(home_screen.call("get_loaded_app_count")) != 200:
		_fail("The OS Worksite did not preload all 200 Papirus apps.")
		return
	var app_drawer_grid := home_screen.find_child("AppDrawerIconGrid", true, false) as GridContainer
	if app_drawer_grid == null or app_drawer_grid.get_child_count() != 200:
		_fail("The 200-app drawer was not fully built before startup preparation completed.")
		return
	if int(home_screen.call("get_app_drawer_loaded_icon_count")) != 200:
		_fail("Some of the 200 prebuilt app drawer SVG textures did not load.")

	if not is_equal_approx(float(worksite.call("get_boot_sequence_duration_seconds")), 10.0):
		_fail("The configured boot sequence must last exactly ten seconds.")
		return

	var plan: Array = worksite.call("_get_boot_presentation_plan")
	var total := 0.0
	for stage in plan:
		total += float(stage.get("duration", 0.0))
	if not is_equal_approx(total, 10.0):
		_fail("The selected boot branding options do not fill the full ten-second boot window.")
		return
	if plan.size() != 3:
		_fail("All three enabled boot items must appear as independent sequence stages.")
		return
	var expected_order := ["logo", "phone_name", "phone_model"]
	for stage_index in range(expected_order.size()):
		if str(plan[stage_index].get("kind", "")) != expected_order[stage_index]:
			_fail("The boot presentation plan did not preserve the configured drag-and-drop order.")
			return
		if not is_equal_approx(float(plan[stage_index].get("duration", 0.0)), 10.0 / 3.0):
			_fail("The ten-second boot window must be divided evenly between enabled items.")
			return

	worksite.call("_on_boot_order_drop", 2, 0)
	plan = worksite.call("_get_boot_presentation_plan")
	if str(plan[0].get("kind", "")) != "phone_model":
		_fail("Dragging a boot item to the first position did not update the presentation order.")
		return

	# Accelerate only the test execution; production boot timing remains ten seconds.
	worksite.set("screen_powered", true)
	worksite.set("boot_sequence_complete", false)
	worksite.call("_show_phone_boot_sequence", int(worksite.get("boot_sequence_id")), 0.01)
	await create_timer(1.0).timeout
	if not bool(worksite.get("boot_sequence_complete")):
		_fail("The boot sequence did not report completion.")
		return
	var lock_screen := worksite.find_child("AutonomousLockScreenDesignerPreview", true, false) as Control
	if lock_screen == null or not lock_screen.visible:
		_fail("The lock screen did not appear automatically after boot.")
		return
	if lock_screen.call("get_generation_count") == 0:
		_fail("The OS worksite did not prepare a default lock-screen before boot completed.")
		return

	worksite.call("_show_step", 1)
	var heading := worksite.get("heading_label") as Label
	if heading == null or heading.text != "LOCKSCREEN CLOCK":
		_fail("The dedicated Lockscreen Clock screen must be the second OS Worksite step.")
		return
	var clock_controls := worksite.get("content_column") as VBoxContainer
	var type_add_button := clock_controls.find_child("ClockTypeAddButton", true, false) as Button
	var style_button := clock_controls.find_child("ClockStyleNextButton", true, false) as Button
	if type_add_button == null or type_add_button.text != "Analog  +":
		_fail("Step 2 must start with the Analog + clock type selector.")
		return
	if style_button == null or style_button.text != "Style 1  +":
		_fail("Step 2 must start at Clock Style 1.")
		return
	worksite.call("_on_clock_type_expand_pressed")
	var digital_type_button := clock_controls.find_child("ClockTypeAlternateButton", true, false) as Button
	if digital_type_button == null or digital_type_button.text != "Digital  +":
		_fail("Adding a clock type must reveal Digital + beside the selected Analog type.")
		return
	for _style_step in range(40):
		worksite.call("_on_clock_style_next_pressed")
	if int(lock_screen.call("get_clock_style_index")) != 41 or style_button.text != "Style 41  +":
		_fail("The Clock Style selector must expose all 41 styles and retain the selected style.")
		return
	worksite.call("_select_lock_screen_clock_type", "digital")
	if str(lock_screen.call("get_clock_type")) != "digital":
		_fail("Selecting Digital did not update the active lock-screen clock type.")
		return
	var digital_clock := lock_screen.find_child("DigitalClock", true, false) as Control
	if digital_clock == null or not digital_clock.visible or int(digital_clock.call("get_style_index")) != 41:
		_fail("Digital Style 41 did not render on the live lock screen.")
		return
	worksite.call("_select_lock_screen_clock_type", "analog")
	var analog_artwork := lock_screen.find_child("GeneratedAnalogClockArtwork", true, false) as TextureRect
	if analog_artwork == null or analog_artwork.texture == null or analog_artwork.texture.resource_path != LockScreenAssetLibrary.get_analog_clock_path(41):
		_fail("Analog Style 41 did not render the matching uploaded artwork.")
		return

	worksite.call("_show_step", 2)
	if heading.text != "LOCK-SCREEN":
		_fail("The original lock-screen options must move to the third OS Worksite step.")
		return
	var lock_controls := worksite.get("content_column") as VBoxContainer
	var option_defaults := {
		"clock": true,
		"notification": false,
		"shortcut": false,
		"details": true,
		"widget": false,
		"unlock": false
	}
	for option_name in option_defaults:
		var option_toggle := lock_controls.find_child("LockScreenOption_" + str(option_name), true, false) as CheckBox
		if option_toggle == null or option_toggle.button_pressed != bool(option_defaults[option_name]):
			_fail("A Step 3 lock-screen checkbox is missing or has the wrong default: " + str(option_name))
			return

	var wallpapers: Array = lock_screen.call("get_wallpaper_paths")
	if wallpapers.is_empty():
		_fail("The separate Wallpapers step has no available lock-screen wallpaper assets.")
		return
	worksite.call("_show_step", 5)
	if heading.text != "WALLPAPERS":
		_fail("The independent Wallpapers step is not in position six.")
		return
	worksite.call("_select_asset", str(wallpapers[0]))
	if str(lock_screen.call("get_selected_wallpaper_path")) != str(wallpapers[0]):
		_fail("Selecting a wallpaper in the Wallpapers step did not update the lock-screen preview.")
		return

	# The status-bar worksite step exposes all ten presets and applies selections
	# to the lock-screen currently displayed on the phone.
	worksite.call("_show_step", 6)
	var controls_column := worksite.get("content_column") as VBoxContainer
	if controls_column == null:
		_fail("The OS worksite status-bar controls column could not be found.")
		return
	var style_button_count := 0
	for child in controls_column.get_children():
		if child is Button and child.has_meta("status_style_id"):
			style_button_count += 1
	if style_button_count != 10:
		_fail("The Status Bar step must expose all ten selectable styles.")
		return
	worksite.call("_on_status_bar_style_selected", "quiet_minimal")
	if str(lock_screen.call("get_status_bar_style_id")) != "quiet_minimal":
		_fail("Selecting a status-bar preset did not update the phone lock screen.")
		return

	# A logo-only or device-text-only boot must still occupy the same ten seconds.
	worksite.set("show_phone_name_on_boot", false)
	worksite.set("show_phone_model_on_boot", false)
	plan = worksite.call("_get_boot_presentation_plan")
	if plan.size() != 1 or not is_equal_approx(float(plan[0].get("duration", 0.0)), 10.0):
		_fail("A logo-only boot must still last ten seconds.")
		return
	worksite.set("show_company_logo_on_boot", false)
	worksite.set("show_phone_name_on_boot", true)
	plan = worksite.call("_get_boot_presentation_plan")
	if plan.size() != 1 or not is_equal_approx(float(plan[0].get("duration", 0.0)), 10.0):
		_fail("A device-text-only boot must still last ten seconds.")
		return

	worksite.queue_free()
	await process_frame
	print("OS_BOOT_LOCK_SCREEN_SMOKE_TEST: PASS")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	print("OS_BOOT_LOCK_SCREEN_SMOKE_TEST: FAIL: " + message)
	quit(1)
