extends SceneTree

const WorksiteScene = preload("res://scenes/camera_creation_worksite.tscn")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")


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
	var technology_level_panel := worksite.find_child("CameraTechnologyLevelPanel", true, false) as PanelContainer
	var technology_level_value := worksite.find_child("CameraTechnologyLevelValue", true, false) as Label
	var selection_controls := worksite.find_child("CameraSelectionControls", true, false) as VBoxContainer
	var progress_bar := worksite.find_child("WizardProgressBar", true, false) as ProgressBar
	var back_step_button := worksite.find_child("WizardBackIconButton", true, false) as Button
	var next_step_button := worksite.find_child("NextStepIconButton", true, false) as Button
	var camera := worksite.find_child("CameraStudioPreviewCamera", true, false) as Camera3D

	if worksite_root == null or backdrop == null or worksite_body == null or preview_region == null or preview_container == null or viewport == null or preview_world == null or phone_model == null or chassis == null or screen == null or selection_scroll == null or technology_level_panel == null or technology_level_value == null or selection_controls == null or progress_bar == null or back_step_button == null or next_step_button == null or camera == null:
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

	if technology_level_panel.get_parent().name != "CameraTechnologyLevelSafeArea" or technology_level_value.text != "0.00 TP":
		_fail("Camera Worksite is missing its pinned Technology Level footer or its zero baseline score.")
		worksite.free()
		return

	if not preview_container.visible or preview_container.get_child(0) != viewport:
		_fail("Camera handset preview viewport is not mounted directly in the worksite preview area.")
		worksite.free()
		return

	if progress_bar.max_value != 5 or progress_bar.value != 1 or int(worksite.get("current_wizard_step")) != 1:
		_fail("Camera Worksite does not initialize its five-stage camera workflow.")
		worksite.free()
		return

	if not back_step_button.disabled or next_step_button.disabled:
		_fail("Camera Worksite wizard arrows have incorrect initial enabled states.")
		worksite.free()
		return

	var initial_rear_panel := worksite.find_child("RareCameraStepControls", true, false) as VBoxContainer
	var initial_mp_panel := worksite.find_child("RearCameraMegapixelStepControls", true, false) as VBoxContainer
	var initial_front_panel := worksite.find_child("FrontCameraStepControls", true, false) as VBoxContainer
	var initial_front_mp_panel := worksite.find_child("FrontCameraMegapixelStepControls", true, false) as VBoxContainer
	var initial_sensor_panel := worksite.find_child("CameraSensorStepControls", true, false) as VBoxContainer
	if initial_rear_panel == null or not initial_rear_panel.visible or initial_mp_panel == null or initial_mp_panel.visible or initial_front_panel == null or initial_front_panel.visible or initial_front_mp_panel == null or initial_front_mp_panel.visible or initial_sensor_panel == null or initial_sensor_panel.visible:
		_fail("Only the Rare Camera editor should be visible at the start of the five-step workflow.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	var no_camera_hint := worksite.find_child("RearCameraMegapixelStepControls", true, false) as VBoxContainer
	var empty_mp_message := no_camera_hint.get_child(1) as Label if no_camera_hint != null and no_camera_hint.get_child_count() > 1 else null
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2 or initial_rear_panel.visible or no_camera_hint == null or no_camera_hint.find_child("RearCameraMegapixelOptions", true, false) != null or empty_mp_message == null or empty_mp_message.text != "Add rear cameras in Step 1 first":
		_fail("Step 2 should show the empty rear-camera MP prompt when no cameras exist.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 1 or progress_bar.value != 1 or not initial_rear_panel.visible or initial_mp_panel.visible:
		_fail("Camera Worksite Back navigation did not restore Step 1.")
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

	var rare_camera_panel := worksite.find_child("RareCameraStepControls", true, false) as VBoxContainer
	var camera_mode_button := worksite.find_child("RearHardwareModeCamera", true, false) as Button
	var flash_mode_button := worksite.find_child("RearHardwareModeFlash", true, false) as Button
	var design_mode_button := worksite.find_child("RearHardwareModeDesign", true, false) as Button
	var mode_switchers := worksite.find_child("RearHardwareModeSwitchers", true, false) as HBoxContainer
	var add_button := worksite.find_child("RearHardwareAddButton", true, false) as Button
	var remove_button := worksite.find_child("RearHardwareRemoveButton", true, false) as Button
	var size_slider := worksite.find_child("RearHardwareHorizontalSizeSlider", true, false) as HSlider
	var direction_pad := worksite.find_child("RearHardwareDirectionPad", true, false) as GridContainer
	if rare_camera_panel == null or not rare_camera_panel.visible or camera_mode_button == null or flash_mode_button == null or design_mode_button == null or mode_switchers == null or mode_switchers.get_child_count() != 3 or add_button == null or remove_button == null or size_slider == null or direction_pad == null:
		_fail("Rare Camera step is missing its three mode tabs or existing camera/flash controls.")
		worksite.free()
		return

	worksite.call("set_back_raised_design_research_level", 2)
	design_mode_button.emit_signal("pressed")
	var design_panel := worksite.find_child("CameraBackDesignControls", true, false) as VBoxContainer
	var design_selector := worksite.find_child("CameraBackDesignBoxSelector", true, false) as Button
	var design_add_button := worksite.find_child("CameraBackDesignAddButton", true, false) as Button
	var design_remove_button := worksite.find_child("CameraBackDesignRemoveButton", true, false) as Button
	var design_rounding_slider := worksite.find_child("CameraBackDesignHorizontalRoundingSlider", true, false) as HSlider
	var design_direction_pad := worksite.find_child("CameraBackDesignDirectionPad", true, false) as GridContainer
	if design_panel == null or not design_panel.visible or design_selector == null or design_add_button == null or design_remove_button == null or design_rounding_slider == null or design_direction_pad == null:
		_fail("DESIGN mode did not reproduce the Back Raised Design editor structure.")
		worksite.free()
		return

	design_add_button.emit_signal("pressed")
	var design_boxes: Array = worksite.get("camera_back_design_boxes")
	if design_boxes.size() != 1 or worksite.find_child("CameraBackDesignRaisedSections", true, false) == null:
		_fail("DESIGN mode could not add and render a raised back-design box.")
		worksite.free()
		return

	var initial_design_position: Vector2 = design_boxes[0]["position"]
	worksite.call("_on_camera_back_design_pad_pressed", Vector2i(1, 0))
	design_boxes = worksite.get("camera_back_design_boxes")
	if design_boxes[0]["position"] == initial_design_position:
		_fail("Back-design movement controller did not move the selected raised box.")
		worksite.free()
		return

	worksite.call("_set_camera_back_design_mode", "SIZE")
	var initial_design_size: Vector2 = design_boxes[0]["size"]
	worksite.call("_on_camera_back_design_pad_pressed", Vector2i(1, 0))
	design_boxes = worksite.get("camera_back_design_boxes")
	if design_boxes[0]["size"] == initial_design_size:
		_fail("Back-design SIZE mode did not resize the selected raised box.")
		worksite.free()
		return

	worksite.call("_on_camera_back_design_rounding_changed", 0.18)
	design_boxes = worksite.get("camera_back_design_boxes")
	if not is_equal_approx(float(design_boxes[0]["border"]), 0.18):
		_fail("Back-design rounding slider did not update the selected raised box.")
		worksite.free()
		return

	var active_design_panel := worksite.get("camera_back_design_view") as VBoxContainer
	var design_color_button := active_design_panel.find_child("CameraBackDesignColorButton", true, false) as Button if active_design_panel != null else null
	if design_color_button == null or design_color_button.disabled:
		_fail("Back-design COLOR action is unavailable for the selected box.")
		worksite.free()
		return
	design_color_button.emit_signal("pressed")
	var normal_color_picker := worksite.find_child("CameraBackDesignNormalColorPicker", true, false) as ColorPickerButton
	var gradient_color_picker := worksite.find_child("CameraBackDesignGradientColorPicker", true, false) as ColorPickerButton
	var gradient_toggle := worksite.find_child("CameraBackDesignGradientToggle", true, false) as Button
	var gradient_direction_button := worksite.find_child("CameraBackDesignGradientDirectionButton", true, false) as Button
	if normal_color_picker == null or gradient_color_picker == null or gradient_toggle == null or gradient_direction_button == null:
		_fail("Back-design COLOR action did not expose its normal/gradient color controls.")
		worksite.free()
		return
	var device_color_toggle := worksite.find_child("CameraBackDesignUseDeviceColor", true, false) as Button
	var design_chassis := worksite.find_child("PhoneChassis", true, false) as MeshInstance3D
	var design_chassis_material := design_chassis.material_override as StandardMaterial3D if design_chassis != null else null
	if device_color_toggle == null or design_chassis_material == null:
		_fail("Back-design colour editor is missing device-colour inheritance.")
		worksite.free()
		return
	worksite.call("_on_camera_back_design_use_device_color_toggled", true)
	var inherited_material_node := worksite.find_child("CameraRaisedBackBox_1", true, false) as MeshInstance3D
	var inherited_material := inherited_material_node.material_override as ShaderMaterial if inherited_material_node != null else null
	if inherited_material == null or inherited_material.get_shader_parameter("solid_color") != design_chassis_material.albedo_color.lightened(0.045) or bool(inherited_material.get_shader_parameter("gradient_enabled")):
		_fail("Back-design device-colour inheritance did not use the handset finish.")
		worksite.free()
		return
	worksite.call("_on_camera_back_design_use_device_color_toggled", false)

	var selected_design_color := Color("#7b9fbc")
	worksite.call("_on_camera_back_design_color_changed", selected_design_color, false)
	design_boxes = worksite.get("camera_back_design_boxes")
	if design_boxes[0]["custom_color"] != selected_design_color:
		_fail("Back-design normal colour picker did not update the raised box material.")
		worksite.free()
		return

	worksite.call("_on_camera_back_design_gradient_toggled", true)
	var selected_gradient_color := Color("#b58be0")
	worksite.call("_on_camera_back_design_color_changed", selected_gradient_color, true)
	worksite.call("_show_camera_back_design_gradient_direction_controls")
	var gradient_direction_panel := worksite.find_child("CameraBackDesignGradientDirectionControls", true, false) as VBoxContainer
	var radial_direction := worksite.find_child("CameraBackDesignGradientDirectionOption3", true, false) as Button
	if gradient_direction_panel == null or radial_direction == null:
		_fail("Back-design gradient direction selector is missing its four direction options.")
		worksite.free()
		return
	radial_direction.emit_signal("pressed")
	design_boxes = worksite.get("camera_back_design_boxes")
	if not bool(design_boxes[0]["gradient_enabled"]) or design_boxes[0]["gradient_color"] != selected_gradient_color or int(design_boxes[0]["gradient_direction"]) != 3:
		_fail("Back-design gradient colour or direction was not applied to the selected raised box.")
		worksite.free()
		return
	var raised_box := worksite.find_child("CameraRaisedBackBox_1", true, false) as MeshInstance3D
	var raised_material := raised_box.material_override as ShaderMaterial if raised_box != null else null
	if raised_material == null or not bool(raised_material.get_shader_parameter("gradient_enabled")):
		_fail("Raised back-design preview did not receive the gradient material.")
		worksite.free()
		return

	camera_mode_button.emit_signal("pressed")
	var active_camera_controls := worksite.get("rear_hardware_controls_view") as VBoxContainer
	var active_design_panel_after_switch := worksite.get("camera_back_design_view") as VBoxContainer
	if active_camera_controls == null or not active_camera_controls.visible or active_design_panel_after_switch == null or active_design_panel_after_switch.visible:
		_fail("Switching from DESIGN back to CAMERA did not restore the original camera controls.")
		worksite.free()
		return

	worksite.call("_add_rear_hardware_module")
	var camera_modules: Array = worksite.get("rear_camera_modules")
	if camera_modules.size() != 1 or remove_button.disabled or not add_button.disabled:
		_fail("The first rear camera should be available by default and use up the initial one-camera capacity.")
		worksite.free()
		return
	worksite.call("_add_rear_hardware_module")
	camera_modules = worksite.get("rear_camera_modules")
	if camera_modules.size() != 1:
		_fail("Camera Worksite added a second rear camera before count research approval.")
		worksite.free()
		return

	var component_selector := worksite.find_child("RearHardwareItemSelector", true, false) as Button
	if component_selector == null:
		_fail("Camera/Flash component selector disappeared after adding a camera.")
		worksite.free()
		return
	component_selector.emit_signal("pressed")
	var component_selection := worksite.find_child("RearHardwareSelection", true, false) as VBoxContainer
	if component_selection == null:
		_fail("Camera component selection view did not open.")
		worksite.free()
		return
	design_mode_button.emit_signal("pressed")
	var restored_design_panel := worksite.get("camera_back_design_view") as VBoxContainer
	if not component_selection.is_queued_for_deletion() or restored_design_panel == null or not restored_design_panel.visible:
		_fail("Switching from Camera component selection to DESIGN left overlapping panels.")
		worksite.free()
		return
	camera_mode_button.emit_signal("pressed")
	if restored_design_panel.visible:
		_fail("Switching back to CAMERA did not hide the Back Design panel.")
		worksite.free()
		return

	var initial_camera_position: Vector2 = camera_modules[0]["position"]
	worksite.call("_on_rear_hardware_size_changed", 0.06)
	camera_modules = worksite.get("rear_camera_modules")
	if not is_equal_approx(float(camera_modules[0]["size"]), 0.06):
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
	if flash_modules.size() != 1 or worksite.find_child("RearCameraFlashHardware", true, false) == null or not add_button.disabled:
		_fail("Rare Camera step should add one default rear flash and then enforce its initial capacity.")
		worksite.free()
		return
	worksite.call("_add_rear_hardware_module")
	flash_modules = worksite.get("rear_flash_modules")
	if flash_modules.size() != 1:
		_fail("Camera Worksite added a second rear flash before count research approval.")
		worksite.free()
		return

	worksite.call("set_rear_flash_count_research_level", 1)
	if add_button.disabled or int(worksite.call("_get_rear_hardware_addition_limit")) != 2:
		_fail("Approving Rear Flash Count level 1 did not unlock the second flash slot.")
		worksite.free()
		return
	var flash_points_before_second := float(worksite.call("_calculate_camera_technology_points"))
	worksite.call("_add_rear_hardware_module")
	flash_modules = worksite.get("rear_flash_modules")
	var flash_points_after_second := float(worksite.call("_calculate_camera_technology_points"))
	var expected_flash_points := ResearchManagerScript.get_technology_points_for_progress("Rear Flash Count", 1.0)
	if flash_modules.size() != 2 or not add_button.disabled or not is_equal_approx(flash_points_after_second - flash_points_before_second, expected_flash_points):
		_fail("The approved second flash slot or its Technology Points contribution was not applied.")
		worksite.free()
		return
	worksite.call("set_rear_flash_count_research_level", 4)
	if int(worksite.call("_get_rear_hardware_addition_limit")) != 5:
		_fail("Rear Flash Count level 4 did not unlock the five-flash maximum.")
		worksite.free()
		return
	worksite.call("set_rear_flash_count_research_level", 1)
	worksite.call("_remove_rear_hardware_module")
	worksite.call("_remove_rear_hardware_module")
	flash_modules = worksite.get("rear_flash_modules")
	if not flash_modules.is_empty():
		_fail("Rare Camera remove control did not remove both test flashes.")
		worksite.free()
		return
	worksite.call("set_rear_flash_count_research_level", 0)

	worksite.call("_set_rear_hardware_mode", "CAMERA")
	worksite.call("set_rear_camera_count_research_level", 1)
	if add_button.disabled or int(worksite.call("_get_rear_hardware_addition_limit")) != 2:
		_fail("Approving Rear Camera Count level 1 did not unlock the second camera slot.")
		worksite.free()
		return
	var camera_points_before_second := float(worksite.call("_calculate_camera_technology_points"))
	worksite.call("_add_rear_hardware_module")
	camera_modules = worksite.get("rear_camera_modules")
	var camera_points_after_second := float(worksite.call("_calculate_camera_technology_points"))
	var expected_camera_points := ResearchManagerScript.get_technology_points_for_progress("Rear Camera Count", 1.0)
	if camera_modules.size() != 2 or int(camera_modules[1].get("mp", -1)) != 1 or not add_button.disabled or not is_equal_approx(camera_points_after_second - camera_points_before_second, expected_camera_points):
		_fail("The approved second rear camera slot, independent 1MP starting resolution, or Technology Points contribution was not applied.")
		worksite.free()
		return
	worksite.call("set_rear_camera_count_research_level", 4)
	if int(worksite.call("_get_rear_hardware_addition_limit")) != 5:
		_fail("Rear Camera Count level 4 did not unlock the five-camera maximum.")
		worksite.free()
		return
	worksite.call("set_rear_camera_count_research_level", 1)
	camera_modules = worksite.get("rear_camera_modules")
	if camera_modules.size() != 2 or int(camera_modules[1].get("mp", -1)) != 1:
		_fail("New rear cameras must receive an independent 1MP starting resolution.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	var mp_panel := worksite.find_child("RearCameraMegapixelStepControls", true, false) as VBoxContainer
	var mp_row := worksite.find_child("RearCameraMegapixelOptions", true, false) as HBoxContainer
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2 or next_step_button.disabled or rare_camera_panel.visible or mp_panel == null or not mp_panel.visible or mp_row == null or mp_row.get_child_count() != 2:
		_fail("Step 2 did not show one independent megapixel slider for each rear camera.")
		worksite.free()
		return

	worksite.call("set_rear_camera_mp_research_level", 2)
	mp_panel = worksite.find_child("RearCameraMegapixelStepControls", true, false) as VBoxContainer
	mp_row = worksite.find_child("RearCameraMegapixelOptions", true, false) as HBoxContainer
	var first_camera_card := mp_row.get_child(0) as VBoxContainer if mp_row != null and mp_row.get_child_count() > 0 else null
	var second_camera_card := mp_row.get_child(1) as VBoxContainer if mp_row != null and mp_row.get_child_count() > 1 else null
	var first_mp_slider := first_camera_card.find_child("CameraMPValueSlider", true, false) as VSlider if first_camera_card != null else null
	var second_mp_slider := second_camera_card.find_child("CameraMPValueSlider", true, false) as VSlider if second_camera_card != null else null
	var first_mp_value := first_camera_card.find_child("CameraMPValueLabel", true, false) as Label if first_camera_card != null else null
	var first_mp_max := first_camera_card.find_child("CameraMPMaximumLabel", true, false) as Label if first_camera_card != null else null
	if first_mp_slider == null or second_mp_slider == null or first_mp_value == null or first_mp_max == null or first_mp_slider.min_value != 1.0 or first_mp_slider.max_value != 11.0 or second_mp_slider.max_value != 11.0 or first_mp_max.text != "11":
		_fail("Rear Camera MP sliders did not copy the 1MP baseline and research-based 11MP ceiling.")
		worksite.free()
		return

	first_mp_slider.value = 11.0
	camera_modules = worksite.get("rear_camera_modules")
	if int(camera_modules[0]["mp"]) != 11 or int(camera_modules[1]["mp"]) != 1 or first_mp_value.text != "11 MP":
		_fail("The first rear-camera MP slider changed another camera or failed to save its selected resolution.")
		worksite.free()
		return

	second_mp_slider.value = 7.0
	camera_modules = worksite.get("rear_camera_modules")
	if int(camera_modules[0]["mp"]) != 11 or int(camera_modules[1]["mp"]) != 7:
		_fail("Each rear camera must retain its own independent megapixel selection.")
		worksite.free()
		return

	worksite.call("set_rear_camera_mp_research_level", 0)
	camera_modules = worksite.get("rear_camera_modules")
	if int(camera_modules[0]["mp"]) != 1 or int(camera_modules[1]["mp"]) != 1:
		_fail("Reducing the Rear Camera MP research ceiling did not clamp existing camera values.")
		worksite.free()
		return

	worksite.call("set_rear_camera_mp_research_level", 2)
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 1 or progress_bar.value != 1 or not rare_camera_panel.visible or mp_panel.visible:
		_fail("Camera Worksite Back navigation did not return from MP settings to Step 1.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	var front_camera_panel := worksite.find_child("FrontCameraStepControls", true, false) as VBoxContainer
	var front_mp_panel := worksite.find_child("FrontCameraMegapixelStepControls", true, false) as VBoxContainer
	var front_enable_button := worksite.find_child("FrontCameraEnablement", true, false) as Button
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3 or not front_camera_panel.visible or initial_rear_panel.visible or initial_mp_panel.visible or front_mp_panel.visible or front_enable_button == null or not is_equal_approx(float(phone_model.rotation.y), PI):
		_fail("Step 3 did not open the front camera editor and turn the handset to its front face.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	var empty_front_mp_message := front_mp_panel.get_child(1) as Label if front_mp_panel != null and front_mp_panel.get_child_count() > 1 else null
	if int(worksite.get("current_wizard_step")) != 4 or progress_bar.value != 4 or not front_mp_panel.visible or front_camera_panel.visible or empty_front_mp_message == null or empty_front_mp_message.text != "Enable the front camera in Step 3 first":
		_fail("Step 4 should prompt the user to enable the front camera before setting its megapixels.")
		worksite.free()
		return

	worksite.call("_on_wizard_back_pressed")
	front_enable_button.emit_signal("toggled", true)
	if not bool(worksite.get("front_camera_enabled")) or worksite.find_child("FrontCameraHardware", true, false) == null:
		_fail("Enabling the front camera did not add its design to the handset preview.")
		worksite.free()
		return

	worksite.call("set_front_camera_research_level", 4)
	worksite.call("_change_front_camera_style", 4)
	if str(worksite.get("front_camera_style")) != "Dual Punch-Hole" or worksite.find_child("FrontCameraLens01", true, false) == null or worksite.find_child("FrontCameraLens02", true, false) == null:
		_fail("Front Camera research did not unlock and preview the dual punch-hole design.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	var front_mp_row := worksite.find_child("FrontCameraMegapixelOptions", true, false) as HBoxContainer
	if int(worksite.get("current_wizard_step")) != 4 or front_mp_row == null or front_mp_row.get_child_count() != 2:
		_fail("Dual Punch-Hole should provide two independent front-camera MP controls.")
		worksite.free()
		return

	worksite.call("set_front_camera_mp_research_level", 2)
	front_mp_row = worksite.find_child("FrontCameraMegapixelOptions", true, false) as HBoxContainer
	var front_first_card := front_mp_row.get_child(0) as VBoxContainer if front_mp_row != null and front_mp_row.get_child_count() > 0 else null
	var front_second_card := front_mp_row.get_child(1) as VBoxContainer if front_mp_row != null and front_mp_row.get_child_count() > 1 else null
	var front_first_slider := front_first_card.find_child("FrontCameraMPValueSlider", true, false) as VSlider if front_first_card != null else null
	var front_second_slider := front_second_card.find_child("FrontCameraMPValueSlider", true, false) as VSlider if front_second_card != null else null
	var front_first_max := front_first_card.find_child("FrontCameraMPMaximumLabel", true, false) as Label if front_first_card != null else null
	if front_first_slider == null or front_second_slider == null or front_first_max == null or front_first_slider.min_value != 1.0 or front_first_slider.max_value != 11.0 or front_second_slider.max_value != 11.0 or front_first_max.text != "11":
		_fail("Front Camera MP sliders did not inherit the 1MP baseline and research-based 11MP ceiling.")
		worksite.free()
		return

	front_first_slider.value = 11.0
	front_second_slider.value = 6.0
	if int(worksite.get("front_camera_megapixels")) != 11 or int(worksite.get("front_camera_secondary_megapixels")) != 6:
		_fail("The two front-camera MP sliders did not preserve their independent resolutions.")
		worksite.free()
		return

	worksite.call("set_front_camera_mp_research_level", 0)
	if int(worksite.get("front_camera_megapixels")) != 1 or int(worksite.get("front_camera_secondary_megapixels")) != 1:
		_fail("Reducing Front Camera MP research did not clamp both front-camera resolutions.")
		worksite.free()
		return

	worksite.call("set_front_camera_research_level", 0)
	front_mp_row = worksite.find_child("FrontCameraMegapixelOptions", true, false) as HBoxContainer
	if str(worksite.get("front_camera_style")) != "Bezel Camera" or front_mp_row == null or front_mp_row.get_child_count() != 1:
		_fail("Reducing Front Camera research did not restore the baseline design and single-camera MP layout.")
		worksite.free()
		return

	worksite.call("_on_wizard_back_pressed")
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 2 or not is_equal_approx(float(phone_model.rotation.y), 0.0):
		_fail("Returning to the rear-camera steps did not restore the handset rear view.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	var camera_sensor_panel := worksite.find_child("CameraSensorStepControls", true, false) as VBoxContainer
	var camera_sensor_heading := camera_sensor_panel.get_child(0) as Label if camera_sensor_panel != null and camera_sensor_panel.get_child_count() > 0 else null
	var camera_sensor_toggle := worksite.find_child("CameraSensorEnabledToggle", true, false) as TextureButton
	var camera_sensor_label := worksite.find_child("SelectedCameraSensor", true, false) as Label
	var camera_sensor_enable_label := worksite.get("camera_sensor_enable_label") as Label
	var camera_sensor_previous := worksite.find_child("PreviousCameraSensorButton", true, false) as Button
	var camera_sensor_next := worksite.find_child("NextCameraSensorButton", true, false) as Button
	var rear_camera_selector := worksite.find_child("CameraSensorRearCameraButton", true, false) as Button
	var front_camera_selector := worksite.find_child("CameraSensorFrontCameraButton", true, false) as Button
	var camera_sensor_states: Dictionary = worksite.get("camera_sensor_enabled_states")
	var rear_sensor_states: Dictionary = camera_sensor_states.get("REAR", {})
	var front_sensor_states: Dictionary = camera_sensor_states.get("FRONT", {})
	if int(worksite.get("current_wizard_step")) != 5 or progress_bar.max_value != 5 or progress_bar.value != 5 or camera_sensor_panel == null or not camera_sensor_panel.visible or camera_sensor_heading == null or camera_sensor_heading.text != "CAMERA SENSORS" or camera_sensor_toggle == null or camera_sensor_label == null or camera_sensor_label.text != "Portrait Mode" or camera_sensor_previous == null or not camera_sensor_previous.disabled or camera_sensor_next == null or camera_sensor_next.disabled or rear_camera_selector == null or front_camera_selector == null or str(worksite.get("camera_sensor_selected_camera")) != "REAR" or not rear_camera_selector.button_pressed or front_camera_selector.button_pressed or rear_sensor_states.size() != 11 or front_sensor_states.size() != 11:
		_fail("Stage 5 did not expose the shared 11-capability selector with separate Rear and Front camera controls.")
		worksite.free()
		return

	if camera_sensor_enable_label.text != "LOCKED" or not camera_sensor_toggle.disabled:
		_fail("Camera features must remain locked until their one-time research is approved.")
		worksite.free()
		return

	worksite.call("set_camera_sensor_research_levels", {
		"Portrait Mode": 1,
		"Macro Photography": 1
	})
	if camera_sensor_toggle.disabled or camera_sensor_enable_label.text != "ENABLE":
		_fail("Approved camera research did not unlock the feature controls.")
		worksite.free()
		return

	camera_sensor_next.emit_signal("pressed")
	camera_sensor_next.emit_signal("pressed")
	if camera_sensor_label.text != "Ultra-Wide Photography" or not camera_sensor_toggle.disabled or camera_sensor_enable_label.text != "LOCKED":
		_fail("An unresearched camera feature was not kept locked.")
		worksite.free()
		return
	camera_sensor_toggle.emit_signal("toggled", true)
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	rear_sensor_states = camera_sensor_states.get("REAR", {})
	if bool(rear_sensor_states.get("Ultra-Wide Photography", false)):
		_fail("A locked camera feature accepted an enable action.")
		worksite.free()
		return
	camera_sensor_previous.emit_signal("pressed")
	camera_sensor_previous.emit_signal("pressed")

	var points_before_rear_portrait := float(worksite.call("_calculate_camera_technology_points"))
	camera_sensor_toggle.emit_signal("toggled", true)
	worksite.call("_refresh_camera_technology_level_display")
	var points_after_rear_portrait := float(worksite.call("_calculate_camera_technology_points"))
	if not is_equal_approx(points_after_rear_portrait - points_before_rear_portrait, 2.60) or technology_level_value.text != "%.2f TP" % points_after_rear_portrait:
		_fail("Enabling Rear Portrait Mode did not add its 2.60 TP unlock value to the Camera Technology Level.")
		worksite.free()
		return
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	rear_sensor_states = camera_sensor_states.get("REAR", {})
	front_sensor_states = camera_sensor_states.get("FRONT", {})
	if not bool(rear_sensor_states.get("Portrait Mode", false)) or bool(front_sensor_states.get("Portrait Mode", true)):
		_fail("Enabling a Rear Camera capability changed the Front Camera state or failed to save the Rear Camera state.")
		worksite.free()
		return

	camera_sensor_next.emit_signal("pressed")
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	rear_sensor_states = camera_sensor_states.get("REAR", {})
	if camera_sensor_label.text != "Macro Photography" or camera_sensor_toggle.button_pressed or bool(rear_sensor_states.get("Macro Photography", true)) or not bool(rear_sensor_states.get("Portrait Mode", false)):
		_fail("Camera sensor navigation did not preserve each selected capability's independent Rear Camera state.")
		worksite.free()
		return

	front_camera_selector.emit_signal("pressed")
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	front_sensor_states = camera_sensor_states.get("FRONT", {})
	if str(worksite.get("camera_sensor_selected_camera")) != "FRONT" or rear_camera_selector.button_pressed or not front_camera_selector.button_pressed or camera_sensor_toggle.button_pressed or bool(front_sensor_states.get("Macro Photography", true)):
		_fail("Switching to Front Camera did not load its own capability states.")
		worksite.free()
		return

	var points_before_front_macro := float(worksite.call("_calculate_camera_technology_points"))
	camera_sensor_toggle.emit_signal("toggled", true)
	worksite.call("_refresh_camera_technology_level_display")
	var points_after_front_macro := float(worksite.call("_calculate_camera_technology_points"))
	if not is_equal_approx(points_after_front_macro - points_before_front_macro, 2.50):
		_fail("Enabling Front Macro Photography did not add its 2.50 TP unlock value.")
		worksite.free()
		return
	camera_sensor_previous.emit_signal("pressed")
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	rear_sensor_states = camera_sensor_states.get("REAR", {})
	front_sensor_states = camera_sensor_states.get("FRONT", {})
	if camera_sensor_label.text != "Portrait Mode" or camera_sensor_toggle.button_pressed or not bool(front_sensor_states.get("Macro Photography", false)) or bool(front_sensor_states.get("Portrait Mode", true)) or not bool(rear_sensor_states.get("Portrait Mode", false)):
		_fail("Front Camera enablement was not saved independently from Rear Camera enablement.")
		worksite.free()
		return

	var points_before_front_portrait := float(worksite.call("_calculate_camera_technology_points"))
	camera_sensor_toggle.emit_signal("toggled", true)
	worksite.call("_refresh_camera_technology_level_display")
	var points_after_front_portrait := float(worksite.call("_calculate_camera_technology_points"))
	if not is_equal_approx(points_after_front_portrait - points_before_front_portrait, 2.60):
		_fail("Enabling Front Portrait Mode did not add a separate 2.60 TP camera contribution.")
		worksite.free()
		return
	rear_camera_selector.emit_signal("pressed")
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	rear_sensor_states = camera_sensor_states.get("REAR", {})
	front_sensor_states = camera_sensor_states.get("FRONT", {})
	if str(worksite.get("camera_sensor_selected_camera")) != "REAR" or not camera_sensor_toggle.button_pressed or not bool(rear_sensor_states.get("Portrait Mode", false)) or not bool(front_sensor_states.get("Portrait Mode", false)):
		_fail("Returning to Rear Camera did not restore its saved Portrait Mode state.")
		worksite.free()
		return

	camera_sensor_next.emit_signal("pressed")
	camera_sensor_states = worksite.get("camera_sensor_enabled_states")
	rear_sensor_states = camera_sensor_states.get("REAR", {})
	front_sensor_states = camera_sensor_states.get("FRONT", {})
	if camera_sensor_toggle.button_pressed or bool(rear_sensor_states.get("Macro Photography", true)) or not bool(front_sensor_states.get("Macro Photography", false)):
		_fail("Rear and Front Camera Macro Photography states were not kept independent.")
		worksite.free()
		return

	front_camera_selector.emit_signal("pressed")
	if not camera_sensor_toggle.button_pressed or str(worksite.get("camera_sensor_selected_camera")) != "FRONT":
		_fail("Switching back to Front Camera did not restore its saved Macro Photography state.")
		worksite.free()
		return

	worksite.free()
	print("CAMERA_CREATION_WORKSITE_SMOKE_TEST: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("CAMERA_CREATION_WORKSITE_SMOKE_TEST: FAIL — " + message)
	quit(1)
