extends SceneTree

const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")

const GENERATION_COUNT := 60


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var designer: Control = LockScreenDesignerScript.new()
	designer.name = "LockScreenDesignerSmokeTest"
	designer.size = Vector2(680.0, 1360.0)
	root.add_child(designer)
	await process_frame

	var signatures: Dictionary = {}
	var clock_styles: Dictionary = {}
	for generation_index in range(GENERATION_COUNT):
		var design: Dictionary = designer.call("generate_new_design")
		if design.is_empty():
			_fail("The autonomous designer failed to produce a valid composition.")
			return

		var issues: Array[String] = designer.call("validate_layout", design)
		if not issues.is_empty():
			_fail("Generated design %02d violated a layout rule: %s" % [generation_index + 1, "; ".join(issues)])
			return

		var signature := str(design.get("signature", ""))
		if signatures.has(signature):
			_fail("The designer repeated a recent lock-screen composition.")
			return
		signatures[signature] = true

		var style := str(design.get("clock_style", ""))
		clock_styles[style] = true

		var shortcuts: Array = design.get("shortcuts", [])
		var found_flashlight := false
		var found_camera := false
		for shortcut in shortcuts:
			var kind := str(shortcut.get("kind", ""))
			var rect: Rect2 = shortcut.get("rect", Rect2())
			if rect.position.y < 0.885:
				_fail("A bottom shortcut was placed outside the bottom zone.")
				return
			if kind == "flashlight":
				found_flashlight = true
			elif kind == "camera":
				found_camera = true
		if not found_flashlight or not found_camera:
			_fail("The lock screen is missing its separate flashlight or camera shortcut.")
			return

	if clock_styles.size() < 2:
		_fail("The designer did not vary its clock treatments across repeated generations.")
		return
	if int(designer.call("get_generation_count")) != GENERATION_COUNT:
		_fail("The designer generation counter is inconsistent.")
		return
	if designer.find_child("GeneratedWallpaper", true, false) == null:
		_fail("The generated lock screen is missing its wallpaper renderer.")
		return
	if designer.find_child("BottomFlashlightShortcut", true, false) == null:
		_fail("The generated lock screen is missing the flashlight shortcut preview.")
		return
	if designer.find_child("BottomCameraShortcut", true, false) == null:
		_fail("The generated lock screen is missing the camera shortcut preview.")
		return

	designer.free()
	print("AUTONOMOUS_LOCK_SCREEN_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("AUTONOMOUS_LOCK_SCREEN_SMOKE_TEST: FAIL: " + message)
	quit(1)
