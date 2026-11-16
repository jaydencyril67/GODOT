extends SceneTree

const WorksiteScene = preload("res://scenes/processor_creation_worksite.tscn")

func _initialize() -> void:
	call_deferred("_run_processor_worksite_test")


func _run_processor_worksite_test() -> void:
	var worksite := WorksiteScene.instantiate() as Node3D
	if worksite == null:
		_fail("Processor Creation Worksite scene failed to instantiate.")
		return
	root.add_child(worksite)
	await process_frame
	await process_frame
	worksite.call("_apply_responsive_layout")

	var worksite_root := worksite.find_child("WorksiteRoot", true, false) as Control
	var worksite_body := worksite.find_child("WorksiteMainContent", true, false) as BoxContainer
	var preview_region := worksite.find_child("ProcessorPreviewRegion", true, false) as Control
	var preview_column := worksite.find_child("ProcessorPreviewColumn", true, false) as VBoxContainer
	var preview_container := worksite.find_child("ProcessorPreviewViewport", true, false) as SubViewportContainer
	var viewport := worksite.find_child("Processor3DSubViewport", true, false) as SubViewport
	var model := worksite.find_child("ProcessorSoCModel", true, false) as Node3D
	var selection_scroll := worksite.find_child("ProcessorSelectionScroll", true, false) as ScrollContainer
	var selection_controls := worksite.find_child("ProcessorSelectionControls", true, false) as VBoxContainer
	var progress_bar := worksite.find_child("WizardProgressBar", true, false) as ProgressBar
	var back_step_button := worksite.find_child("WizardBackIconButton", true, false) as Button
	var next_step_button := worksite.find_child("NextStepIconButton", true, false) as Button
	if worksite_root == null or worksite_body == null or preview_region == null or preview_column == null or preview_container == null or viewport == null or model == null or selection_scroll == null or selection_controls == null or progress_bar == null or back_step_button == null or next_step_button == null:
		_fail("Processor worksite is missing part of the shared Phone/OS full-screen worksite structure.")
		worksite.free()
		return
	var backdrop := worksite.find_child("WorksiteBackdrop", true, false) as ColorRect
	if worksite_root.mouse_filter != Control.MOUSE_FILTER_STOP or backdrop == null or backdrop.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Processor worksite does not block touch input from reaching the previous Creation page.")
		worksite.free()
		return
	if viewport.size.x <= 0 or viewport.size.y <= 0 or viewport.msaa_3d != Viewport.MSAA_2X or viewport.render_target_update_mode != SubViewport.UPDATE_WHEN_VISIBLE:
		_fail("Processor preview is not using the low-end-device rendering budget.")
		worksite.free()
		return

	if worksite.find_child("Processor3DPreviewPanel", true, false) != null or worksite.find_child("ProcessorDesignControlsPanel", true, false) != null:
		_fail("Processor worksite still contains the old independent preview/configuration cards.")
		worksite.free()
		return
	if not preview_container.visible or preview_container.custom_minimum_size.y < 240.0 or (preview_container.size_flags_vertical & Control.SIZE_EXPAND_FILL) == 0:
		_fail("Processor preview does not reserve an expanding visible area above the bottom screen edge.")
		worksite.free()
		return
	if preview_column.size_flags_vertical != Control.SIZE_EXPAND_FILL or (preview_region.size_flags_vertical & Control.SIZE_EXPAND_FILL) == 0:
		_fail("Processor preview region is not configured to fill the shared worksite body.")
		worksite.free()
		return
	if progress_bar.max_value != 4 or progress_bar.value != 1 or int(worksite.get("current_wizard_step")) != 1:
		_fail("Processor worksite does not initialize its four-step progress navigation.")
		worksite.free()
		return
	if not back_step_button.disabled or next_step_button.disabled:
		_fail("Processor worksite step arrows have incorrect initial enabled states.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3:
		_fail("Processor Next navigation did not advance the wizard and progress indicator.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2:
		_fail("Processor Back navigation did not return to the previous design step.")
		worksite.free()
		return
	worksite.call("_set_wizard_step", 1)

	var camera := viewport.get_camera_3d()
	if camera == null or camera.position.y < 1.5 or camera.position.z < 4.0:
		_fail("Processor studio camera framing is too tight or is not aimed from above.")
		worksite.free()
		return

	var contacts := model.find_child("UndersideBGAContactArray", true, false) as MultiMeshInstance3D
	if contacts == null or contacts.multimesh == null or contacts.multimesh.instance_count != 225:
		_fail("Processor model is missing its 15 × 15 underside ball-grid contact array.")
		worksite.free()
		return
	if model.find_child("SiliconDieSurface", true, false) == null:
		_fail("Processor model is missing its visible top silicon die.")
		worksite.free()
		return
	if model.find_child("LaserEtchedMarking_Logo", true, false) == null or model.find_child("LaserEtchedMarking_Product", true, false) == null or model.find_child("LaserEtchedMarking_Revision", true, false) == null:
		_fail("Processor top face is missing its etched product markings.")
		worksite.free()
		return

	worksite.configure_design({
		"name": "Smoke Test SoC",
		"package_size": "14 × 14 mm",
		"package_finish": "Deep green substrate",
		"die_finish": "Polished silicon"
	})
	var name_control := worksite.get("name_input") as LineEdit
	if name_control == null or name_control.text != "Smoke Test SoC":
		_fail("Saved processor design values are not restored into the controls.")
		worksite.free()
		return

	var emitted_design: Array = []
	worksite.design_saved.connect(func(design: Dictionary): emitted_design.append(design))
	worksite.call("_save_design")
	if emitted_design.size() != 1 or str(emitted_design[0].get("name", "")) != "Smoke Test SoC":
		_fail("Save Processor Design did not emit the configured processor design.")
		worksite.free()
		return
	if str(emitted_design[0].get("package_size", "")) != "14 × 14 mm" or str(emitted_design[0].get("package_finish", "")) != "Deep green substrate" or str(emitted_design[0].get("die_finish", "")) != "Polished silicon":
		_fail("Save Processor Design did not preserve all configured package and die values.")
		worksite.free()
		return

	var starting_rotation := model.rotation.x
	worksite.call("_flip_chip")
	if is_equal_approx(model.rotation.x, starting_rotation):
		_fail("Flip Chip did not reveal the underside contact array.")
		worksite.free()
		return
	worksite.call("_reset_view")
	if not is_equal_approx(model.rotation.x, -0.24):
		_fail("Reset View did not return the processor to its correctly framed top view.")
		worksite.free()
		return

	worksite.free()
	print("PROCESSOR_WORKSITE_SMOKE_TEST: PASS")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	print("PROCESSOR_WORKSITE_SMOKE_TEST: FAIL — " + message)
	quit(1)
