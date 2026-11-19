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
	var front_view_button := worksite.find_child("CameraFrontViewButton", true, false) as Button
	var rear_view_button := worksite.find_child("CameraRearViewButton", true, false) as Button
	var camera := worksite.find_child("CameraStudioPreviewCamera", true, false) as Camera3D

	if worksite_root == null or backdrop == null or worksite_body == null or preview_region == null or preview_container == null or viewport == null or preview_world == null or phone_model == null or chassis == null or screen == null or selection_scroll == null or selection_controls == null or progress_bar == null or back_step_button == null or next_step_button == null or front_view_button == null or rear_view_button == null or camera == null:
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

	if progress_bar.max_value != 3 or progress_bar.value != 1 or int(worksite.get("current_wizard_step")) != 1:
		_fail("Camera Worksite does not initialize its three-stage creation workflow.")
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

	var start_rotation := phone_model.rotation.y
	worksite.call("_rotate_phone_from_drag", Vector2(36.0, 0.0))
	if is_equal_approx(phone_model.rotation.y, start_rotation):
		_fail("Dragging the 3D handset did not rotate its preview.")
		worksite.free()
		return

	worksite.call("_set_view_side", "FRONT")
	if camera.position.z <= 0.0 or str(worksite.get("current_view_side")) != "FRONT":
		_fail("Front View did not move the studio camera to the display side.")
		worksite.free()
		return

	worksite.call("_set_view_side", "REAR")
	if camera.position.z >= 0.0 or str(worksite.get("current_view_side")) != "REAR":
		_fail("Rear View did not return the studio camera to the blank camera-design surface.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3 or not next_step_button.disabled:
		_fail("Camera Worksite Next navigation did not reach the final workflow stage.")
		worksite.free()
		return

	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2:
		_fail("Camera Worksite Back navigation did not return to the previous workflow stage.")
		worksite.free()
		return

	worksite.free()
	print("CAMERA_CREATION_WORKSITE_SMOKE_TEST: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("CAMERA_CREATION_WORKSITE_SMOKE_TEST: FAIL — " + message)
	quit(1)
