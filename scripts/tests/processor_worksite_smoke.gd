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

	var preview_panel := worksite.find_child("Processor3DPreviewPanel", true, false) as PanelContainer
	var preview_column := worksite.find_child("ProcessorPreviewColumn", true, false) as VBoxContainer
	var preview_container := worksite.find_child("ProcessorPreviewViewport", true, false) as SubViewportContainer
	var viewport := worksite.find_child("Processor3DSubViewport", true, false) as SubViewport
	var model := worksite.find_child("ProcessorSoCModel", true, false) as Node3D
	var controls_panel := worksite.find_child("ProcessorDesignControlsPanel", true, false) as PanelContainer
	if preview_panel == null or preview_column == null or preview_container == null or viewport == null or model == null or controls_panel == null:
		_fail("Processor worksite is missing its left 3D preview or right design controls.")
		worksite.free()
		return
	if not preview_container.visible or preview_container.custom_minimum_size.y < 240.0 or (preview_container.size_flags_vertical & Control.SIZE_EXPAND_FILL) == 0:
		_fail("Processor preview does not reserve an expanding visible area above the bottom screen edge.")
		worksite.free()
		return
	if preview_column.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		_fail("Processor preview column is not configured to fill the left worksite panel.")
		worksite.free()
		return

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
	var name_control := worksite.find_child("ProcessorDesignControlsPanel", true, false).find_child("LineEdit", true, false) as LineEdit
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
