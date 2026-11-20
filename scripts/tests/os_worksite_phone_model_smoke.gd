extends SceneTree

const OSPhoneModelScript = preload("res://scripts/os_worksite_phone_model.gd")
# The chassis is 0.13 units deep, centered on Z=0. The display glass must
# extend beyond its front face (0.065), not beyond an unrelated 0.109 offset.
const MIN_DISPLAY_BACK_Z := 0.065
const EXPECTED_BEZEL_WIDTH := 0.020


func _initialize() -> void:
	var image := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var screen_texture := ImageTexture.create_from_image(image)

	var phone: Node3D = OSPhoneModelScript.new()
	root.add_child(phone)
	phone.call("build", screen_texture)

	var chassis := phone.find_child("PhoneChassis", true, false) as MeshInstance3D
	var inset := phone.find_child("DisplayInsetFrame", true, false) as MeshInstance3D
	var display := phone.find_child("PhoneScreenSurface", true, false) as MeshInstance3D
	var power_key := phone.find_child("PowerButton", true, false) as MeshInstance3D
	var volume_up := phone.find_child("VolumeUpButton", true, false) as MeshInstance3D
	var volume_down := phone.find_child("VolumeDownButton", true, false) as MeshInstance3D
	var under_display_camera := phone.find_child("UnderDisplayCameraOpticalWindow", true, false) as MeshInstance3D
	var earpiece := phone.find_child("TopEarpiece", true, false) as MeshInstance3D

	if not is_instance_valid(chassis) or not is_instance_valid(inset) or not is_instance_valid(display):
		_fail("The OS handset is missing its chassis, inset bezel, or glass display.")
		return
	if not is_instance_valid(power_key) or not is_instance_valid(volume_up) or not is_instance_valid(volume_down):
		_fail("The power and volume keys are not present as separate side-mounted hardware.")
		return
	if not is_instance_valid(under_display_camera) or is_instance_valid(earpiece):
		_fail("The OS handset must have only an under-display front camera and no top earpiece.")
		return

	var body_bounds := chassis.mesh.get_aabb()
	if not is_equal_approx(body_bounds.size.x, 1.45) or not is_equal_approx(body_bounds.size.y, 2.92):
		_fail("The OS handset no longer matches the Phone Creation Worksite's physical proportions.")
		return
	if inset.mesh.get_aabb().size.x >= body_bounds.size.x or inset.mesh.get_aabb().size.y >= body_bounds.size.y:
		_fail("The display inset must remain inside the outer chassis border.")
		return
	if display.mesh.get_aabb().size.x >= inset.mesh.get_aabb().size.x or display.mesh.get_aabb().size.y >= inset.mesh.get_aabb().size.y:
		_fail("The active glass must sit inside the separate inset bezel.")
		return
	if display.position.z - 0.003 < MIN_DISPLAY_BACK_Z:
		_fail("The display glass is behind or embedded too deeply into the chassis face.")
		return

	var display_bounds := display.mesh.get_aabb()
	var inset_bounds := inset.mesh.get_aabb()
	var horizontal_bezel := (body_bounds.size.x - display_bounds.size.x) * 0.5
	var vertical_bezel := (body_bounds.size.y - display_bounds.size.y) * 0.5
	var corner_bezel := OSPhoneModelScript.OUTER_CORNER_RADIUS - OSPhoneModelScript.SCREEN_CORNER_RADIUS
	var bezel_positions := [
		{"position": "Top", "thickness": vertical_bezel},
		{"position": "Right/top corner", "thickness": corner_bezel},
		{"position": "Right", "thickness": horizontal_bezel},
		{"position": "Right/bottom corner", "thickness": corner_bezel},
		{"position": "Bottom", "thickness": vertical_bezel},
		{"position": "Bottom/left corner", "thickness": corner_bezel},
		{"position": "Left", "thickness": horizontal_bezel},
		{"position": "Left/top corner", "thickness": corner_bezel}
	]
	for bezel_position in bezel_positions:
		if not is_equal_approx(float(bezel_position["thickness"]), EXPECTED_BEZEL_WIDTH):
			_fail(
				"The %s bezel must be exactly 0.020; got %.6f."
				% [bezel_position["position"], float(bezel_position["thickness"])]
			)
			return

	var inset_margin_x := (inset_bounds.size.x - display_bounds.size.x) * 0.5
	var inset_margin_y := (inset_bounds.size.y - display_bounds.size.y) * 0.5
	if not is_equal_approx(inset_margin_x, OSPhoneModelScript.DISPLAY_INSET_MARGIN):
		_fail("The inset frame must keep a uniform 0.002 margin on the left and right.")
		return
	if not is_equal_approx(inset_margin_y, OSPhoneModelScript.DISPLAY_INSET_MARGIN):
		_fail("The inset frame must keep a uniform 0.002 margin on the top and bottom.")
		return

	var display_width_ratio := display_bounds.size.x / body_bounds.size.x
	var display_height_ratio := display_bounds.size.y / body_bounds.size.y
	if display_width_ratio < 0.95 or display_height_ratio < 0.96:
		_fail("The OS handset display must cover nearly the full front face with minimal bezels.")
		return
	var display_top := display_bounds.position.y + display_bounds.size.y
	if under_display_camera.position.y > display_top or under_display_camera.position.y < display_bounds.position.y:
		_fail("The under-display camera optical window must remain within the active display.")
		return

	var side_keys: Array[MeshInstance3D] = [power_key, volume_up, volume_down]
	for key in side_keys:
		if absf(key.position.x) <= body_bounds.size.x * 0.5 or absf(key.position.x) > body_bounds.size.x * 0.5 + 0.03:
			_fail("A physical side key is not seated on the left or right chassis edge.")
			return

	var display_arrays := display.mesh.surface_get_arrays(0)
	var display_uvs: PackedVector2Array = display_arrays[Mesh.ARRAY_TEX_UV]
	if display_uvs.is_empty():
		_fail("The rounded screen surface has no UV coordinates for the boot viewport texture.")
		return

	var display_material := display.material_override as StandardMaterial3D
	if not is_instance_valid(display_material) or display_material.albedo_texture != screen_texture:
		_fail("The phone glass is not bound to the boot screen viewport texture.")
		return
	if display_material.cull_mode != BaseMaterial3D.CULL_DISABLED:
		_fail("The boot screen surface must remain visible from the preview camera.")
		return

	phone.free()
	print("OS_WORKSITE_PHONE_MODEL_SMOKE_TEST: PASS")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	print("OS_WORKSITE_PHONE_MODEL_SMOKE_TEST: FAIL: " + message)
	quit(1)
