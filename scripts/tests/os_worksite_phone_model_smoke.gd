extends SceneTree

const OSPhoneModelScript = preload("res://scripts/os_worksite_phone_model.gd")
const MIN_DISPLAY_BACK_Z := 0.109


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
	var front_camera := phone.find_child("FrontCameraLens", true, false) as MeshInstance3D
	var earpiece := phone.find_child("TopEarpiece", true, false) as MeshInstance3D

	if not is_instance_valid(chassis) or not is_instance_valid(inset) or not is_instance_valid(display):
		_fail("The OS handset is missing its chassis, inset bezel, or glass display.")
		return
	if not is_instance_valid(power_key) or not is_instance_valid(volume_up) or not is_instance_valid(volume_down):
		_fail("The power and volume keys are not present as separate side-mounted hardware.")
		return
	if not is_instance_valid(front_camera) or not is_instance_valid(earpiece):
		_fail("The front camera or earpiece is missing from the top bezel.")
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

	var display_width_ratio := display.mesh.get_aabb().size.x / body_bounds.size.x
	var display_height_ratio := display.mesh.get_aabb().size.y / body_bounds.size.y
	if display_width_ratio < 0.95 or display_height_ratio < 0.96:
		_fail("The OS handset display must cover nearly the full front face with minimal bezels.")
		return
	var display_top := display.mesh.get_aabb().position.y + display.mesh.get_aabb().size.y
	if front_camera.position.y < display_top - 0.18 or earpiece.position.y < display_top - 0.18:
		_fail("The front camera and earpiece must remain inside the narrow top edge of the active display.")
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
