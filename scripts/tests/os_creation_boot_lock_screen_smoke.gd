extends SceneTree

const WorksiteScript = preload("res://scripts/os_creation_worksite.gd")

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var worksite: Node = WorksiteScript.new()
	worksite.name = "OSCreationBootLockScreenSmokeTest"
	root.add_child(worksite)
	await process_frame

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
	if plan.size() != 2 or float(plan[0].get("duration", 0.0)) != 5.0 or float(plan[1].get("duration", 0.0)) != 5.0:
		_fail("Logo and device branding must receive five seconds each when both are enabled.")
		return

	# Accelerate only the test execution; production boot timing remains ten seconds.
	worksite.set("screen_powered", true)
	worksite.set("boot_sequence_complete", false)
	worksite.call("_show_phone_boot_sequence", int(worksite.get("boot_sequence_id")), 0.01)
	await create_timer(0.15).timeout
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

	# The status-bar worksite step exposes all ten presets and applies selections
	# to the lock-screen currently displayed on the phone.
	worksite.call("_show_step", 5)
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
