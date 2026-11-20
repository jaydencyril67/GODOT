extends SceneTree

const WorksiteScene = preload("res://scenes/camera_creation_worksite.tscn")


func _initialize() -> void:
	call_deferred("_run_camera_worksite_test")


func _run_camera_worksite_test() -> void:
	var worksite := WorksiteScene.instantiate() as Node3D
	if worksite == null:
		_fail("Camera Creation Worksite scene failed to instantiate.")
		return

	root.add_child(worksite)
	await process_frame
	await process_frame
	worksite.call("_apply_responsive_layout")

	var worksite_root := worksite.find_child("WorksiteRoot", true, false) as Control
	var backdrop := worksite.find_child("WorksiteBackdrop", true, false) as ColorRect
	var worksite_body := worksite.find_child("WorksiteMainContent", true, false) as BoxContainer
	var preview_region := worksite.find_child("CameraPreviewRegion", true, false) as Control
	var preview_container := worksite.find_child("CameraPreviewViewportContainer", true, false) as SubViewportContainer
	var viewport := worksite.find_child("CameraPreviewViewport", true, false) as SubViewport
	var preview_world := worksite.find_child("CameraStudioPreviewWorld", true, false) as Node3D
	var phone_model := worksite.find_child("CameraLessPhoneModel", true, false) as Node3D
	var chassis := worksite.find_child("PhoneChassis", true, false) as MeshInstance3D
	var screen := worksite.find_child("PhoneScreenSurface", true, false) as MeshInstance3D
	var side_controls := worksite.find_child("SideControls", true, false) as Node3D
	var power_button := worksite.find_child("PowerButton", true, false) as MeshInstance3D
	var charging_port := worksite.find_child("ChargingPortFrame", true, false) as MeshInstance3D
	var bottom_speaker := worksite.find_child("BottomSpeaker_L_01", true, false) as MeshInstance3D
	var selection_scroll := worksite.find_child("CameraSelectionScroll", true, false) as ScrollContainer
	var selection_controls := worksite.find_child("CameraSelectionControls", true, false) as VBoxContainer
	var progress_bar := worksite.find_child("WizardProgressBar", true, false) as ProgressBar
	var back_step_button := worksite.find_child("WizardBackIconButton", true, false) as Button
	var next_step_button := worksite.find_child("NextStepIconButton", true, false) as Button
	var camera := worksite.find_child("CameraStudioPreviewCamera", true, false) as Camera3D

	if worksite_root == null or backdrop == null or worksite_body == null or preview_region == null or preview_container == null or viewport == null or preview_world == null or phone_model == null or chassis == null or screen == null or selection_scroll == null or selection_controls == null or progress_bar == null or back_step_button == null or next_step_button == null or camera == null:
		_fail("Camera Worksite is missing part of the shared Phone Creation Worksite layout or 3D handset preview.")
		worksite.free()
		return

	if worksite_root.mouse_filter != Control.MOUSE_FILTER_STOP or backdrop.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Camera Worksite does not block touch input from reaching the previous Create page.")
		worksite.free()
		return

	if viewport.size.x <= 0 or viewport.size.y <= 0 or viewport.msaa_3d != Viewport.MSAA_DISABLED or viewport.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED or viewport.render_target_update_mode != SubViewport.UPDATE_WHEN_VISIBLE:
		_fail("Camera handset preview is not using the expected low-end-device rendering settings.")
		worksite.free()
		return

	if not preview_container.visible or preview_container.get_child(0) != viewport:
		_fail("Camera handset preview viewport is not mounted directly in the worksite preview area.")
		worksite.free()
		return

	if progress_bar.max_value != 4 or progress_bar.value != 1 or int(worksite.get("current_wizard_step")) != 1:
		_fail("Camera Worksite does not initialize its four-stage creation workflow.")
		worksite.free()
		return

	if not back_step_button.disabled or next_step_button.disabled:
		_fail("Camera Worksite wizard arrows have incorrect initial enabled states.")
		worksite.free()
		return

	if chassis.mesh == null or screen.mesh == null or side_controls == null or power_button == null or charging_port == null or bottom_speaker == null:
		_fail("Camera-less handset is missing its chassis, glass display, side controls or bottom hardware.")
		worksite.free()
		return

	var handset_bounds := chassis.mesh.get_aabb()
	if not is_equal_approx(handset_bounds.size.x, 1.45) or not is_equal_approx(handset_bounds.size.y, 2.92) or not is_equal_approx(handset_bounds.size.z, 0.13):
		_fail("Camera-less handset is too thick or no longer matches realistic shared handset proportions.")
		worksite.free()
		return

	if phone_model.find_child("UnderDisplayCameraOpticalWindow", true, false) != null or phone_model.find_child("FrontCameraLens", true, false) != null or phone_model.find_child("RearCameraModule", true, false) != null or phone_model.find_child("RearFlashModule", true, false) != null:
		_fail("The Camera Worksite base handset contains camera hardware before camera design begins.")
		worksite.free()
		return

	if camera.current != true or camera.position.z >= -4.0:
		_fail("Camera Worksite must open on the blank rear of the camera-less handset.")
		worksite.free()
		return

	if worksite.find_child("CameraFrontViewButton", true, false) != null or worksite.find_child("CameraRearViewButton", true, false) != null or worksite.find_child("CameraStudioResetButton", true, false) != null:
		_fail("Camera Worksite still exposes manual view-side or reset controls.")
		worksite.free()
		return

	var start_rotation := phone_model.rotation.y
	var start_pitch := phone_model.rotation.x
	worksite.call("_rotate_phone_from_drag", Vector2(36.0, 12.0))
	if not is_equal_approx(phone_model.rotation.y - start_rotation, 36.0 * 0.0024) or not is_equal_approx(phone_model.rotation.x, start_pitch) or camera.position.z >= 0.0:
		_fail("Camera drag no longer uses the stable single-axis sensitivity while preserving its initial rear view.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 4 or progress_bar.value != 4 or not next_step_button.disabled:
		_fail("Camera Worksite Next navigation did not reach the fourth and final workflow stage.")
		worksite.free()
		return

	var rare_camera_panel := worksite.find_child("RareCameraStepControls", true, false) as VBoxContainer
	var camera_mode_button := worksite.find_child("RearHardwareModeCamera", true, false) as Button
	var flash_mode_button := worksite.find_child("RearHardwareModeFlash", true, false) as Button
	var add_button := worksite.find_child("RearHardwareAddButton", true, false) as Button
	var remove_button := worksite.find_child("RearHardwareRemoveButton", true, false) as Button
	var size_slider := worksite.find_child("RearHardwareHorizontalSizeSlider", true, false) as HSlider
	var direction_pad := worksite.find_child("RearHardwareDirectionPad", true, false) as GridContainer
	if rare_camera_panel == null or not rare_camera_panel.visible or camera_mode_button == null or flash_mode_button == null or add_button == null or remove_button == null or size_slider == null or direction_pad == null:
		_fail("Rare Camera step is missing its camera/flash, add/remove, resize or movement controls.")
		worksite.free()
		return

	worksite.call("_add_rear_hardware_module")
	var camera_modules: Array = worksite.get("rear_camera_modules")
	if camera_modules.size() != 1 or remove_button.disabled:
		_fail("Rare Camera step could not add and select a rear camera module.")
		worksite.free()
		return

	var initial_camera_position: Vector2 = camera_modules[0]["position"]
	worksite.call("_on_rear_hardware_size_changed", 0.10)
	camera_modules = worksite.get("rear_camera_modules")
	if not is_equal_approx(float(camera_modules[0]["size"]), 0.10):
		_fail("Rare Camera size control did not resize the selected camera.")
		worksite.free()
		return

	worksite.call("_on_rear_hardware_pad_pressed", Vector2i(1, 0))
	camera_modules = worksite.get("rear_camera_modules")
	if camera_modules[0]["position"] == initial_camera_position:
		_fail("Rare Camera direction pad did not move the selected camera.")
		worksite.free()
		return

	worksite.call("_set_rear_hardware_mode", "FLASH")
	worksite.call("_add_rear_hardware_module")
	var flash_modules: Array = worksite.get("rear_flash_modules")
	if flash_modules.size() != 1 or worksite.find_child("RearCameraFlashHardware", true, false) == null:
		_fail("Rare Camera step could not add a flash or render the rear hardware preview.")
		worksite.free()
		return

	worksite.call("_remove_rear_hardware_module")
	flash_modules = worksite.get("rear_flash_modules")
	if not flash_modules.is_empty():
		_fail("Rare Camera remove control did not remove the selected flash.")
		worksite.free()
		return

	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3 or rare_camera_panel.visible:
		_fail("Camera Worksite Back navigation did not leave the fourth step cleanly.")
		worksite.free()
		return

	worksite.free()
	print("CAMERA_CREATION_WORKSITE_SMOKE_TEST: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("CAMERA_CREATION_WORKSITE_SMOKE_TEST: FAIL — " + message)
	quit(1)
