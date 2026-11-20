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
	var preview_world := worksite.find_child("ProcessorPreviewWorld", true, false) as Node3D
	var preview_environment := viewport.get_node_or_null("WorldEnvironment") as WorldEnvironment if viewport != null else null
	var model := worksite.find_child("ProcessorSoCModel", true, false) as Node3D
	var design_models: Array = worksite.get("processor_models_data")
	var design_selector_previous := worksite.find_child("DecreaseProcessorDesignButton", true, false) as Button
	var design_selector_next := worksite.find_child("IncreaseProcessorDesignButton", true, false) as Button
	var design_selector_value := worksite.find_child("ProcessorDesignValueLabel", true, false) as Label
	var design_selector_position := worksite.find_child("ProcessorDesignPositionLabel", true, false) as Label
	var selection_scroll := worksite.find_child("ProcessorSelectionScroll", true, false) as ScrollContainer
	var selection_controls := worksite.find_child("ProcessorSelectionControls", true, false) as VBoxContainer
	var progress_bar := worksite.find_child("WizardProgressBar", true, false) as ProgressBar
	var back_step_button := worksite.find_child("WizardBackIconButton", true, false) as Button
	var next_step_button := worksite.find_child("NextStepIconButton", true, false) as Button
	if worksite_root == null or worksite_body == null or preview_region == null or preview_column == null or preview_container == null or viewport == null or preview_world == null or preview_environment == null or model == null or design_models.size() != 30 or design_selector_previous == null or design_selector_next == null or design_selector_value == null or design_selector_position == null or selection_scroll == null or selection_controls == null or progress_bar == null or back_step_button == null or next_step_button == null:
		_fail("Processor worksite is missing part of the shared Phone/OS full-screen worksite structure.")
		worksite.free()
		return
	var backdrop := worksite.find_child("WorksiteBackdrop", true, false) as ColorRect
	if worksite_root.mouse_filter != Control.MOUSE_FILTER_STOP or backdrop == null or backdrop.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Processor worksite does not block touch input from reaching the previous Creation page.")
		worksite.free()
		return
	if viewport.size.x <= 0 or viewport.size.y <= 0 or viewport.msaa_3d != Viewport.MSAA_DISABLED or viewport.screen_space_aa != Viewport.SCREEN_SPACE_AA_DISABLED or viewport.render_target_update_mode != SubViewport.UPDATE_WHEN_VISIBLE:
		_fail("Processor preview is not using the low-end-device rendering budget.")
		worksite.free()
		return

	if not viewport.transparent_bg or preview_environment.environment == null or preview_environment.environment.background_mode != Environment.BG_COLOR or preview_environment.environment.background_color.a > 0.001:
		_fail("Processor preview must use a transparent viewport over the shared Phone Worksite backdrop.")
		worksite.free()
		return
	if backdrop == null or backdrop.color != Color("#292B2D"):
		_fail("Processor preview is not revealing the same charcoal #292B2D backdrop as Phone Creation.")
		worksite.free()
		return
	if preview_world.get_parent() != viewport or preview_world.get_node_or_null("ProcessorStudioCamera") == null or preview_world.get_node_or_null("PhoneStyleStudioKeyLight") == null or preview_world.get_node_or_null("PhoneStyleStudioRimLight") == null or preview_world.get_node_or_null("PhoneStyleStudioFillLight") == null:
		_fail("Processor preview does not follow the Phone Worksite's dedicated 3D preview-world structure.")
		worksite.free()
		return
	if preview_environment.environment.sky == null or not (preview_environment.environment.sky.sky_material is ProceduralSkyMaterial):
		_fail("Processor preview is missing the Phone Worksite procedural studio sky used for PBR lighting.")
		worksite.free()
		return
	if viewport.find_child("StudioFloor", true, false) != null:
		_fail("Processor preview must not add a separate floor/platform; its background must come from WorksiteBackdrop.")
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

	if design_selector_position.text != "DESIGN 01 / 30" or design_selector_value.text != "DW SILICON 01" or not design_selector_previous.disabled or design_selector_next.disabled:
		_fail("The first processor design selector does not match the Phone Worksite's initial minus/current/plus state.")
		worksite.free()
		return

	var model_roots: Array[Node3D] = []
	for model_data_value in design_models:
		var model_data: Dictionary = model_data_value
		var model_root := model_data.get("root") as Node3D
		if not is_instance_valid(model_root) or model_root.get_child_count() == 0:
			_fail("A processor design was not fully constructed during worksite preparation.")
			worksite.free()
			return
		model_roots.append(model_root)
	if model_roots.size() != 30 or model_roots[0] != model or not model_roots[0].visible:
		_fail("The worksite did not preload all 30 physical designs with Design 01 initially visible.")
		worksite.free()
		return
	var initial_viewport_child_count := viewport.get_child_count()
	var first_package_surface := model.find_child("PackageSubstrate", true, false) as MeshInstance3D
	if first_package_surface == null or first_package_surface.material_override == null or first_package_surface.material_override.albedo_color != Color("#101214"):
		_fail("The original processor package does not start in the required black finish.")
		worksite.free()
		return
	var first_package_material_id := first_package_surface.material_override.get_instance_id()
	for design_index in range(30):
		worksite.call("_select_processor_design", design_index, false)
		var visible_count := 0
		for model_root in model_roots:
			if model_root.visible:
				visible_count += 1
		if visible_count != 1 or not model_roots[design_index].visible:
			_fail("Processor design %d did not switch by revealing exactly one prebuilt model." % (design_index + 1))
			worksite.free()
			return
	if viewport.get_child_count() != initial_viewport_child_count:
		_fail("Switching processor designs created new 3D nodes instead of rendering prebuilt models.")
		worksite.free()
		return
	if first_package_surface.material_override.get_instance_id() != first_package_material_id:
		_fail("Switching processor designs recreated materials instead of reusing the prebuilt design.")
		worksite.free()
		return
	worksite.call("_select_processor_design", 29, false)
	if not design_selector_next.disabled or design_selector_previous.disabled:
		_fail("The processor design selector did not disable the plus button at Design 30.")
		worksite.free()
		return
	worksite.call("_on_processor_design_decrease_pressed")
	if int(worksite.get("selected_design_index")) != 13:
		_fail("The processor design minus button did not move back one design.")
		worksite.free()
		return
	worksite.call("_select_processor_design", 0, true)

	var processor_color_control := worksite.find_child("ProcessorColor", true, false) as OptionButton
	if processor_color_control == null:
		_fail("Processor worksite is missing its dedicated second-step colour selector.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2:
		_fail("Processor Next navigation did not advance to the dedicated colour step.")
		worksite.free()
		return
	var silver_index := -1
	for option_index in range(processor_color_control.item_count):
		if processor_color_control.get_item_text(option_index) == "Silver":
			silver_index = option_index
			break
	if silver_index < 0:
		_fail("Processor colour step is missing the Silver option.")
		worksite.free()
		return
	processor_color_control.select(silver_index)
	worksite.call("_on_processor_color_selected", silver_index)
	var recolored_surface := model.find_child("PackageSubstrate", true, false) as MeshInstance3D
	if recolored_surface == null or recolored_surface.material_override == null or recolored_surface.material_override.albedo_color != Color("#A5AAAE"):
		_fail("Processor colour selection did not apply to the model.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3:
		_fail("Processor Next navigation did not advance from colour to package dimensions.")
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
		"design_id": "dw_silicon_01",
		"package_size": "14 × 14 mm",
		"processor_color": "Silver"
	})
	var name_control := worksite.find_child("ProcessorNameInput", true, false)
	var restored_color := worksite.find_child("ProcessorColor", true, false) as OptionButton
	if name_control != null or restored_color == null or restored_color.get_item_text(restored_color.selected) != "Silver":
		_fail("Processor worksite still shows a name field or failed to restore the saved processor colour.")
		worksite.free()
		return

	var emitted_design: Array = []
	worksite.design_saved.connect(func(design: Dictionary): emitted_design.append(design))
	worksite.call("_save_design")
	if emitted_design.size() != 1 or str(emitted_design[0].get("name", "")) != "DW SILICON 01":
		_fail("Save Processor Design did not use the selected design's preset name.")
		worksite.free()
		return
	if str(emitted_design[0].get("design_id", "")) != "dw_silicon_01":
		_fail("Saving the processor did not preserve the selected physical design identity.")
		worksite.free()
		return
	if str(emitted_design[0].get("package_size", "")) != "14 × 14 mm" or str(emitted_design[0].get("processor_color", "")) != "Silver":
		_fail("Save Processor Design did not preserve the configured package size and processor colour.")
		worksite.free()
		return

	if _has_button_text(worksite, "FLIP CHIP") or _has_button_text(worksite, "RESET VIEW"):
		_fail("Processor Worksite still exposes manual flip or reset view controls.")
		worksite.free()
		return
	if worksite.find_child("ProcessorDesignNoteLabel", true, false) != null:
		_fail("Processor Worksite still exposes the removed explanatory design text.")
		worksite.free()
		return

	var active_model := worksite.get("processor_root") as Node3D
	var initial_rotation := active_model.rotation
	worksite.call("_rotate_preview", Vector2(36.0, 12.0))
	var expected_rotation := initial_rotation
	expected_rotation.y += 36.0 * 0.0024
	if not active_model.rotation.is_equal_approx(expected_rotation):
		_fail("Processor drag does not match Camera Worksite stable single-axis rotation sensitivity.")
		worksite.free()
		return
	var viewing_rotation := active_model.rotation
	worksite.call("_select_processor_design", 1, false)
	var switched_model := worksite.get("processor_root") as Node3D
	if switched_model == null or not switched_model.rotation.is_equal_approx(viewing_rotation):
		_fail("Changing processor design reset the current viewing angle instead of preserving it.")
		worksite.free()
		return

	worksite.free()
	print("PROCESSOR_WORKSITE_SMOKE_TEST: PASS")
	quit(0)


func _has_button_text(node: Node, target_text: String) -> bool:
	if node is Button and (node as Button).text == target_text:
		return true
	for child in node.get_children():
		if _has_button_text(child, target_text):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	print("PROCESSOR_WORKSITE_SMOKE_TEST: FAIL — " + message)
	quit(1)
