extends SceneTree

const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")
const WorksiteScript = preload("res://scripts/os_creation_worksite.gd")
const PIN_BACKSPACE_PATH := "res://assets/system-ui/godot/pin-entry/pin_backspace.svg"
const LOCK_TO_UNLOCK_ANIMATION := "res://assets/lock-screen/aosp/Animations/lock_to_unlock.json"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for asset_path in [
		PIN_BACKSPACE_PATH,
		LOCK_TO_UNLOCK_ANIMATION,
		"res://assets/lock-screen/aosp/SVG/ic_lock_locked.svg",
		"res://assets/lock-screen/aosp/SVG/ic_unlocked.svg",
		"res://assets/lock-screen/aosp/SVG/ic_fingerprint.svg"
	]:
		if not FileAccess.file_exists(asset_path):
			_fail("A required AOSP lock-screen asset is missing: " + asset_path)
			return

	var designer: Control = LockScreenDesignerScript.new()
	designer.name = "PinEntryDesignerSmokeTest"
	designer.size = Vector2(680.0, 1360.0)
	root.add_child(designer)
	await process_frame
	if (designer.call("generate_new_design") as Dictionary).is_empty():
		_fail("The lock-screen designer did not create a screen for PIN entry.")
		return
	if not bool(designer.call("show_pin_entry")):
		_fail("The PIN entry screen did not open.")
		return
	if not bool(designer.call("is_pin_entry_visible")):
		_fail("The PIN entry overlay is not visible.")
		return

	var backspace_icon := designer.find_child("PinBackspaceIcon", true, false) as TextureRect
	if backspace_icon == null or backspace_icon.texture == null:
		_fail("The AOSP backspace asset did not load into the PIN keypad.")
		return
	var lock_icon := designer.find_child("PinLockStateIcon", true, false) as TextureRect
	if lock_icon == null or lock_icon.texture == null:
		_fail("The AOSP lock-state asset did not load into the PIN screen.")
		return
	for digit in range(10):
		if designer.find_child("PinDigit%d" % digit, true, false) == null:
			_fail("The numeric keypad is missing digit %d." % digit)
			return

	for digit in [1, 2, 3, 4, 5, 6]:
		designer.call("press_pin_digit", digit)
	if int(designer.call("get_pin_digit_count")) != 6 or not bool(designer.call("is_pin_unlocked")):
		_fail("A complete six-digit PIN did not finish the preview unlock.")
		return
	designer.call("erase_pin_digit")
	if int(designer.call("get_pin_digit_count")) != 5 or bool(designer.call("is_pin_unlocked")):
		_fail("PIN backspace did not clear one digit and return to PIN entry.")
		return
	designer.call("hide_pin_entry")
	if bool(designer.call("is_pin_entry_visible")):
		_fail("The PIN overlay did not close cleanly.")
		return
	designer.free()

	var worksite: Node = WorksiteScript.new()
	worksite.name = "PinEntrySwipeWorksiteSmokeTest"
	root.add_child(worksite)
	await process_frame
	var phone_frame := worksite.get("phone_frame") as SubViewportContainer
	var screen_viewport := worksite.get("phone_screen_interface_viewport") as SubViewport
	var lock_screen := worksite.get("lock_screen_designer") as Control
	if phone_frame == null or screen_viewport == null or lock_screen == null:
		_fail("The OS worksite did not expose its handset screen input bridge.")
		return
	if phone_frame.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("The handset preview is not receiving screen gestures.")
		return
	phone_frame.size = Vector2(250.0, 500.0)
	worksite.set("screen_powered", true)
	worksite.set("boot_sequence_complete", true)
	worksite.call("_update_phone_preview_mode")

	var screen_center: Vector2 = worksite.call("_map_phone_preview_position_to_screen", phone_frame.size * 0.5)
	if screen_center.distance_to(Vector2(340.0, 680.0)) > 1.0:
		_fail("Phone preview touch coordinates are not mapped to the screen viewport: %s" % screen_center)
		return

	var swipe_start := Vector2(phone_frame.size.x * 0.5, phone_frame.size.y * 0.80)
	var swipe_end := Vector2(phone_frame.size.x * 0.5, phone_frame.size.y * 0.28)
	_send_touch(worksite, swipe_start, true)
	_send_touch(worksite, swipe_end, false)
	if not bool(lock_screen.call("is_pin_entry_visible")):
		_fail("Swiping upward on the lock screen did not reveal PIN entry.")
		return

	swipe_start = Vector2(phone_frame.size.x * 0.5, phone_frame.size.y * 0.28)
	swipe_end = Vector2(phone_frame.size.x * 0.5, phone_frame.size.y * 0.80)
	_send_touch(worksite, swipe_start, true)
	_send_touch(worksite, swipe_end, false)
	if bool(lock_screen.call("is_pin_entry_visible")):
		_fail("Swiping down from PIN entry did not return to the lock screen.")
		return

	worksite.queue_free()
	await process_frame
	print("PIN_ENTRY_SWIPE_SMOKE_TEST: PASS")
	quit()


func _send_touch(worksite: Node, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	worksite.call("_on_phone_preview_gui_input", event)


func _fail(message: String) -> void:
	push_error(message)
	print("PIN_ENTRY_SWIPE_SMOKE_TEST: FAIL: " + message)
	quit(1)
