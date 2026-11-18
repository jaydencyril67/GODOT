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
	var clock_toggle := worksite.find_child("LockScreenClockEnabled", true, false) as CheckBox
	if clock_toggle == null or not clock_toggle.visible or not clock_toggle.button_pressed:
		_fail("Step 2 must show an enabled clock checkbox beside the LOCKSCREEN CLOCK hero.")
		return
	clock_toggle.set_pressed_no_signal(false)
	worksite.call("_on_clock_enabled_toggled", false)
	if lock_screen.find_child("GeneratedAnalogClockArtwork", true, false) != null or lock_screen.find_child("DigitalClock", true, false) != null:
		_fail("Disabling the Step 2 clock checkbox must remove the clock from the live preview.")
		return
	clock_toggle.set_pressed_no_signal(true)
	worksite.call("_on_clock_enabled_toggled", true)
	if lock_screen.find_child("GeneratedAnalogClockArtwork", true, false) == null:
		_fail("Enabling the Step 2 clock checkbox must restore the live clock.")
		return
	var clock_feature_panel := clock_controls.find_child("LockScreenClockFeaturePanel", true, false) as VBoxContainer
	var type_section := clock_controls.find_child("ClockTypeFeatureSection", true, false) as VBoxContainer
	var type_description := clock_controls.find_child("ClockTypeDescription", true, false) as Label
	var type_center := clock_controls.find_child("ClockTypeControlsCenter", true, false) as CenterContainer
	var type_row := clock_controls.find_child("ClockTypeSelector", true, false) as HBoxContainer
	var type_decrease_button := clock_controls.find_child("ClockTypeDecreaseButton", true, false) as Button
	var type_value_label := clock_controls.find_child("ClockTypeValueLabel", true, false) as Label
	var type_increase_button := clock_controls.find_child("ClockTypeIncreaseButton", true, false) as Button
	var style_section := clock_controls.find_child("ClockStyleFeatureSection", true, false) as VBoxContainer
	var style_description := clock_controls.find_child("ClockStyleDescription", true, false) as Label
	var style_center := clock_controls.find_child("ClockStyleControlsCenter", true, false) as CenterContainer
	var style_row := clock_controls.find_child("ClockStyleSelector", true, false) as HBoxContainer
	var style_decrease_button := clock_controls.find_child("ClockStyleDecreaseButton", true, false) as Button
	var style_value_label := clock_controls.find_child("ClockStyleValueLabel", true, false) as Label
	var style_increase_button := clock_controls.find_child("ClockStyleIncreaseButton", true, false) as Button
	if clock_feature_panel == null or type_section == null or type_description == null or type_center == null or type_row == null:
		_fail("The Lock Screen Clock panel must use the Phone Type feature-section hierarchy.")
		return
	var type_heading := type_section.get_child(0) as Label
	if type_heading == null or type_heading.text != "CLOCK TYPE":
		_fail("Clock Type must begin with a dedicated feature heading.")
		return
	if type_row.get_parent() != type_center or type_center.get_parent() != type_section or type_section.get_parent() != clock_feature_panel:
		_fail("Clock Type controls must sit inside their centred feature-section hierarchy.")
		return
	if type_row.get_child_count() != 3 or type_decrease_button == null or type_value_label == null or type_increase_button == null:
		_fail("Clock Type must use the three-part minus, selected value, plus selector structure.")
		return
	if type_value_label.text != "ANALOG" or not type_decrease_button.disabled or type_increase_button.disabled:
		_fail("The Clock Type selector must initially show Analog with only the forward selector enabled.")
		return
	if style_section == null or style_description == null or style_center == null or style_row == null:
		_fail("Clock Style must have its own heading, description and centred control area.")
		return
	var style_heading := style_section.get_child(0) as Label
	if style_heading == null or style_heading.text != "CLOCK STYLE":
		_fail("Clock Style must begin with a dedicated feature heading.")
		return
	if style_row.get_parent() != style_center or style_center.get_parent() != style_section:
		_fail("Clock Style controls must sit inside their own centred feature section.")
		return
	if style_row.get_child_count() != 3 or style_decrease_button == null or style_value_label == null or style_increase_button == null:
		_fail("Clock Style must use the same minus, selected value, plus selector as Phone Type.")
		return
	if style_value_label.text != "STYLE 01" or not style_decrease_button.disabled or style_increase_button.disabled:
		_fail("Clock Style must start at Style 01 with only the plus control enabled.")
		return
	type_increase_button.pressed.emit()
	if type_value_label.text != "DIGITAL" or type_decrease_button.disabled or not type_increase_button.disabled:
		_fail("The plus control must select Digital and update the available direction controls.")
		return
	type_decrease_button.pressed.emit()
	if type_value_label.text != "ANALOG" or not type_decrease_button.disabled or type_increase_button.disabled:
		_fail("The minus control must restore Analog and update the available direction controls.")
		return
	for _style_step in range(40):
		style_increase_button.pressed.emit()
	if int(lock_screen.call("get_clock_style_index")) != 41 or style_value_label.text != "STYLE 41":
		_fail("The Clock Style plus control must reach Style 41 and retain the selected style.")
		return
	if not style_increase_button.disabled or style_decrease_button.disabled:
		_fail("The Clock Style plus control must disable at Style 41.")
		return
	style_decrease_button.pressed.emit()
	if int(lock_screen.call("get_clock_style_index")) != 40 or style_value_label.text != "STYLE 40":
		_fail("The Clock Style minus control must move back to Style 40.")
		return
	for _style_step in range(39):
		style_decrease_button.pressed.emit()
	if int(lock_screen.call("get_clock_style_index")) != 1 or style_value_label.text != "STYLE 01":
		_fail("The Clock Style minus control must reach Style 01.")
		return
	if not style_decrease_button.disabled or style_increase_button.disabled:
		_fail("The Clock Style minus control must disable at Style 01.")
		return
	for _style_step in range(40):
		style_increase_button.pressed.emit()
	if int(lock_screen.call("get_clock_style_index")) != 41 or style_value_label.text != "STYLE 41":
		_fail("Clock Style must return to Style 41 for the live preview checks.")
		return
	worksite.call("_select_lock_screen_clock_type", "digital")
	if str(lock_screen.call("get_clock_type")) != "digital":
		_fail("Selecting Digital did not update the active lock-screen clock type.")
		return
	var digital_clock := lock_screen.find_child("DigitalClock", true, false) as Control
	if digital_clock == null or not digital_clock.visible or int(digital_clock.call("get_style_index")) != 41:
		_fail("Digital Style 41 did not render on the live lock screen.")
		return
	if int(digital_clock.call("get_style_count")) != 41:
		_fail("Digital lock-screen styles must retain all 41 selectable presets.")
		return
	var digital_time_label := digital_clock.find_child("DigitalClockTime", true, false) as Label
	var digital_date_label := digital_clock.find_child("DigitalClockDate", true, false) as Label
	var digital_hours_label := digital_clock.find_child("DigitalClockHours", true, false) as Label
	var digital_minutes_label := digital_clock.find_child("DigitalClockMinutes", true, false) as Label
	if digital_time_label == null or digital_date_label == null or digital_hours_label == null or digital_minutes_label == null:
		_fail("The digital clock must use real lock-screen time and date labels, not a drawn alarm-clock casing.")
		return
	if digital_clock.anchor_left != 0.0 or digital_clock.anchor_top != 0.0 or digital_clock.anchor_right != 1.0 or digital_clock.anchor_bottom != 1.0:
		_fail("Digital lock-screen styles must own a full-screen layout instead of inheriting the analog clock's small rectangle.")
		return
	var reference_styles := [
		{"index": 1, "source": "SAMSUNG GALAXY S21", "layout": "single"},
		{"index": 9, "source": "SAMSUNG GALAXY S26", "layout": "stacked"},
		{"index": 17, "source": "APPLE IPHONE 16 PRO MAX", "layout": "single"},
		{"index": 25, "source": "APPLE IPHONE 17 PRO MAX", "layout": "single"},
		{"index": 33, "source": "GOOGLE PIXEL", "layout": "stacked"}
	]
	for reference_style in reference_styles:
		var reference_index := int(reference_style["index"])
		if not bool(lock_screen.call("set_clock_style_index", reference_index)):
			_fail("A named real-device digital clock reference could not be selected.")
			return
		var active_digital := lock_screen.find_child("DigitalClock", true, false) as Control
		if active_digital == null or str(active_digital.call("get_style_source")).find(str(reference_style["source"])) < 0:
			_fail("Digital Style %02d is not mapped to its named real-device reference." % reference_index)
			return
		if str(active_digital.call("get_style_layout")) != str(reference_style["layout"]):
			_fail("Digital Style %02d does not use the expected phone clock structure." % reference_index)
			return
		var active_time := active_digital.find_child("DigitalClockTime", true, false) as Label
		var active_hours := active_digital.find_child("DigitalClockHours", true, false) as Label
		var active_minutes := active_digital.find_child("DigitalClockMinutes", true, false) as Label
		if str(reference_style["layout"]) == "stacked":
			if active_time == null or active_time.visible or active_hours == null or not active_hours.visible or active_minutes == null or not active_minutes.visible:
				_fail("Stacked phone clock references must render separate hour and minute rows.")
				return
		else:
			if active_time == null or not active_time.visible or active_hours == null or active_hours.visible or active_minutes == null or active_minutes.visible:
				_fail("Single-line phone clock references must render one horizontal time row.")
				return
	if not bool(lock_screen.call("set_clock_style_index", 41)):
		_fail("Digital Style 41 could not be restored after reference validation.")
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
		"notification": false,
		"shortcut": false,
		"details": true,
		"widget": false,
		"unlock": false
	}
	if lock_controls.find_child("LockScreenOption_clock", true, false) != null:
		_fail("The Clock checkbox must not appear in Step 3; it belongs to Step 2.")
		return
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
