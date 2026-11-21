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
	var right_panel_column := worksite.find_child("ProcessorCreationRightPanel", true, false) as VBoxContainer
	var selection_scroll := worksite.find_child("ProcessorSelectionScroll", true, false) as ScrollContainer
	var selection_controls := worksite.find_child("ProcessorSelectionControls", true, false) as VBoxContainer
	var progress_bar := worksite.find_child("WizardProgressBar", true, false) as ProgressBar
	var back_step_button := worksite.find_child("WizardBackIconButton", true, false) as Button
	var next_step_button := worksite.find_child("NextStepIconButton", true, false) as Button
	if worksite_root == null or worksite_body == null or preview_region == null or preview_column == null or preview_container == null or viewport == null or preview_world == null or preview_environment == null or model == null or design_models.size() != 30 or design_selector_previous == null or design_selector_next == null or design_selector_value == null or design_selector_position == null or right_panel_column == null or selection_scroll == null or selection_controls == null or progress_bar == null or back_step_button == null or next_step_button == null:
		_fail("Processor worksite is missing part of the shared Phone/OS full-screen worksite structure.")
		worksite.free()
		return
	var backdrop := worksite.find_child("WorksiteBackdrop", true, false) as ColorRect
	if right_panel_column.get_parent() != worksite_body or selection_scroll.get_parent() != right_panel_column:
		_fail("Processor right-side controls do not follow the Phone Creation right-panel hierarchy.")
		worksite.free()
		return
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
	if progress_bar.max_value != 8 or progress_bar.value != 1 or int(worksite.get("current_wizard_step")) != 1:
		_fail("Processor worksite does not initialize its eight-step progress navigation.")
		worksite.free()
		return
	if worksite.find_child("ProcessorPackageSize", true, false) != null or worksite.find_child("SaveProcessorDesignButton", true, false) == null:
		_fail("Removed package-dimensions UI remains, or the save action was not retained on the colour step.")
		worksite.free()
		return

	var technology_name_label := worksite.find_child("SelectedProcessorTechnology", true, false) as Label
	var technology_toggle := worksite.find_child("ProcessorTechnologyEnabledToggle", true, false) as TextureButton
	var technology_previous := worksite.find_child("PreviousProcessorTechnologyButton", true, false) as Button
	var technology_next := worksite.find_child("NextProcessorTechnologyButton", true, false) as Button
	var technology_states: Dictionary = worksite.get("processor_technology_enabled_states")
	var processor_research_button := worksite.find_child("ProcessorResearchButton", true, false) as Button
	var technology_level_panel := worksite.find_child("ProcessorTechnologyLevelPanel", true, false) as PanelContainer
	var technology_level_value := worksite.find_child("ProcessorTechnologyLevelValue", true, false) as Label
	if technology_name_label == null or technology_toggle == null or technology_previous == null or technology_next == null or technology_states.size() != 15 or processor_research_button == null or technology_level_panel == null or technology_level_value == null:
		_fail("Processor Technologies step is missing its selector, enable control, or all 15 entries.")
		worksite.free()
		return
	if technology_name_label.text != "Control Unit" or not technology_previous.disabled or technology_next.disabled or not technology_toggle.disabled or technology_level_value.text != "0.00 TP":
		_fail("Processor Technologies does not initialize locked with the correct first-entry, toggle, and TP states.")
		worksite.free()
		return
	if worksite.find_child("ProcessorTechnologyCameraSwitcher", true, false) != null:
		_fail("Processor Technologies contains an unwanted camera-style top switcher.")
		worksite.free()
		return
	var research_request_events: Array[String] = []
	worksite.research_requested.connect(func(): research_request_events.append("requested"))
	processor_research_button.pressed.emit()
	if research_request_events.size() != 1:
		_fail("Processor Research button did not emit its navigation request.")
		worksite.free()
		return
	if not back_step_button.disabled or next_step_button.disabled:
		_fail("Processor worksite step arrows have incorrect initial enabled states.")
		worksite.free()
		return

	if design_selector_position.text != "DESIGN 01 / 30" or design_selector_value.text != "DW SILICON 01" or not design_selector_previous.disabled or not design_selector_next.disabled:
		_fail("The first processor design selector does not match the Phone Worksite's initial minus/current/plus state.")
		worksite.free()
		return

	var design_profiles: Array = worksite.get("processor_designs")
	if design_profiles.size() != 30:
		_fail("The processor library does not expose exactly 30 design profiles.")
		worksite.free()
		return
	worksite.call("set_processor_design_research_level", 1)
	if design_selector_next.disabled:
		_fail("Approving Processor Design research did not unlock the next design selector step.")
		worksite.free()
		return
	design_selector_next.pressed.emit()
	if int(worksite.get("selected_design_index")) != 1 or design_selector_value.text != "DW CORE 02" or design_selector_position.text != "DESIGN 02 / 30" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 21.0) or technology_level_value.text != "21.00 TP":
		_fail("Processor Design research did not make Design 02 selectable.")
		worksite.free()
		return
	worksite.call("set_processor_design_research_level", 0)
	if int(worksite.get("selected_design_index")) != 0 or design_selector_value.text != "DW SILICON 01" or not design_selector_next.disabled or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 0.0) or technology_level_value.text != "0.00 TP":
		_fail("Reducing the unlocked Processor Design level did not clamp selection back to the available baseline.")
		worksite.free()
		return
	var unique_design_ids := {}
	var unique_design_layouts := {}
	for profile_value in design_profiles:
		var profile: Dictionary = profile_value
		var design_id := str(profile.get("id", ""))
		var design_layout := str(profile.get("layout", ""))
		if design_id.is_empty() or design_layout.is_empty() or unique_design_ids.has(design_id) or unique_design_layouts.has(design_layout):
			_fail("Processor presets must have unique design IDs and unique physical layouts.")
			worksite.free()
			return
		unique_design_ids[design_id] = true
		unique_design_layouts[design_layout] = true

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
	# Every design's editable package/die body surfaces start black.
	# Accent meshes and contact arrays are intentionally not forced to black.
	for model_data_value in design_models:
		var model_data: Dictionary = model_data_value
		var body_surface_count := 0
		for body_surface_value in model_data.get("package_layers", []) + model_data.get("die_surfaces", []):
			var body_surface := body_surface_value as MeshInstance3D
			var body_material := body_surface.material_override as StandardMaterial3D if body_surface != null else null
			if body_material == null or body_material.albedo_color.r > 0.1 or body_material.albedo_color.g > 0.1 or body_material.albedo_color.b > 0.1:
				_fail("A processor package or die body surface does not start black.")
				worksite.free()
				return
			body_surface_count += 1
		if body_surface_count == 0:
			_fail("A processor design has no colour-editable package or die surfaces.")
			worksite.free()
			return
	var initial_viewport_child_count := viewport.get_child_count()
	var first_package_surface := model.find_child("PackageSubstrate", true, false) as MeshInstance3D
	var first_package_material := first_package_surface.material_override as StandardMaterial3D if first_package_surface != null else null
	if first_package_surface == null or first_package_material == null or first_package_material.albedo_color != Color("#101214"):
		_fail("The original processor package does not start in the required black finish.")
		worksite.free()
		return
	# Design 01 must retain its original gold and light-grey realism accents.
	var gold_trace := model.find_child("TopEdgeTrace", true, false) as MeshInstance3D
	var light_gray_passive := model.find_child("SurfaceMountPassive", true, false) as MeshInstance3D
	var gold_contact_array := model.find_child("UndersideBGAContactArray", true, false) as MultiMeshInstance3D
	var gold_trace_material := gold_trace.material_override as StandardMaterial3D if gold_trace != null else null
	var light_gray_material := light_gray_passive.material_override as StandardMaterial3D if light_gray_passive != null else null
	var contact_material := gold_contact_array.material_override as StandardMaterial3D if gold_contact_array != null else null
	if gold_trace_material == null or gold_trace_material.albedo_color != Color("#B58B4C") or light_gray_material == null or light_gray_material.albedo_color != Color("#B6B4A8") or contact_material == null or contact_material.albedo_color != Color("#D3A957"):
		_fail("Processor gold traces, light-grey ceramic components, or gold contacts lost their original materials.")
		worksite.free()
		return
	var first_package_material_id := first_package_surface.material_override.get_instance_id()
	# The earlier checks deliberately reset research to level 0. Unlock all 30
	# designs before verifying that each prebuilt model can be selected.
	worksite.call("set_processor_design_research_level", 29)
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
	if int(worksite.get("selected_design_index")) != 28:
		_fail("The processor design minus button did not move back from Design 30 to Design 29.")
		worksite.free()
		return
	worksite.call("_select_processor_design", 0, true)

	var processor_color_content := worksite.find_child("ProcessorColorControls", true, false) as VBoxContainer
	var color_picker_columns := worksite.find_child("ProcessorColorPickerColumns", true, false) as HBoxContainer
	var normal_picker := worksite.find_child("ProcessorNormalColorPicker", true, false) as VBoxContainer
	var gradient_picker := worksite.find_child("ProcessorGradientColorPicker", true, false) as VBoxContainer
	var gradient_toggle := worksite.find_child("EnableProcessorGradient", true, false) as TextureButton
	var gradient_direction := worksite.find_child("ProcessorGradientDirection", true, false) as Button
	var normal_spectrum := normal_picker.get_node_or_null("ProcessorColorSpectrum") as Control if normal_picker != null else null
	var normal_hue := normal_picker.get_node_or_null("ProcessorColorHue") as Control if normal_picker != null else null
	var normal_hex := normal_picker.get_node_or_null("ProcessorCustomHexEntry/ProcessorColorHexInput") as LineEdit if normal_picker != null else null
	var gradient_hex := gradient_picker.get_node_or_null("ProcessorCustomHexEntry/ProcessorColorHexInput") as LineEdit if gradient_picker != null else null
	if processor_color_content == null or color_picker_columns == null or normal_picker == null or gradient_picker == null or gradient_toggle == null or gradient_direction == null or normal_spectrum == null or normal_hue == null or normal_hex == null or gradient_hex == null:
		_fail("Processor colour step is missing part of the Phone Creation spectrum, hue, hex, or gradient editor.")
		worksite.free()
		return
	if worksite.find_child("ProcessorColor", true, false) != null:
		_fail("Processor colour step still uses the old preset dropdown instead of the Phone Creation editor.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2:
		_fail("Processor Next navigation did not advance to the dedicated colour step.")
		worksite.free()
		return
	worksite.call("_on_processor_color_picker_changed", Color("#A5AAAE"), false)
	var recolored_surface := model.find_child("PackageSubstrate", true, false) as MeshInstance3D
	var recolored_material := recolored_surface.material_override as StandardMaterial3D if recolored_surface != null else null
	if recolored_surface == null or recolored_material == null or recolored_material.albedo_color != Color("#A5AAAE"):
		_fail("Processor normal colour selection did not apply to the model body.")
		worksite.free()
		return
	gold_trace_material = gold_trace.material_override as StandardMaterial3D if gold_trace != null else null
	light_gray_material = light_gray_passive.material_override as StandardMaterial3D if light_gray_passive != null else null
	contact_material = gold_contact_array.material_override as StandardMaterial3D if gold_contact_array != null else null
	if gold_trace_material == null or gold_trace_material.albedo_color != Color("#B58B4C") or light_gray_material == null or light_gray_material.albedo_color != Color("#B6B4A8") or contact_material == null or contact_material.albedo_color != Color("#D3A957"):
		_fail("Applying processor body colour also changed gold or light-grey realism details.")
		worksite.free()
		return
	gradient_toggle.button_pressed = true
	worksite.call("_on_processor_gradient_toggle_pressed", gradient_toggle)
	worksite.call("_on_processor_color_picker_changed", Color("#C65B8E"), true)
	worksite.call("_select_processor_gradient_direction", 2)
	var gradient_material := recolored_surface.material_override as ShaderMaterial if recolored_surface != null else null
	if gradient_material == null:
		_fail("Enabling the processor gradient did not apply a gradient shader to the model.")
		worksite.free()
		return
	if gradient_material.get_shader_parameter("solid_color") != Color("#A5AAAE") or gradient_material.get_shader_parameter("gradient_color") != Color("#C65B8E") or int(gradient_material.get_shader_parameter("gradient_direction")) != 2:
		_fail("Processor gradient shader did not receive the selected normal colour, gradient colour, and diagonal direction.")
		worksite.free()
		return
	gold_trace_material = gold_trace.material_override as StandardMaterial3D if gold_trace != null else null
	light_gray_material = light_gray_passive.material_override as StandardMaterial3D if light_gray_passive != null else null
	contact_material = gold_contact_array.material_override as StandardMaterial3D if gold_contact_array != null else null
	if gold_trace_material == null or light_gray_material == null or contact_material == null or gold_trace_material.albedo_color != Color("#B58B4C") or light_gray_material.albedo_color != Color("#B6B4A8") or contact_material.albedo_color != Color("#D3A957"):
		_fail("Applying the processor gradient also changed the gold or light-grey realism details.")
		worksite.free()
		return
	var gradient_options := processor_color_content.get_node_or_null("ProcessorGradientOptions") as Control
	if gradient_options == null or not gradient_options.visible or gradient_picker.modulate.a < 0.99 or not gradient_direction.text.contains("DIAGONAL"):
		_fail("Processor gradient controls did not follow the Phone Creation enabled-gradient state.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3 or next_step_button.disabled:
		_fail("Processor Next navigation did not advance from colour to the Technologies step before CPU Cores.")
		worksite.free()
		return
	worksite.call("set_processor_technology_research_levels", {"Control Unit": 1, "Security Processing Unit": 1})
	if technology_toggle.disabled:
		_fail("An approved Processor Technology did not enable its worksite toggle.")
		worksite.free()
		return
	worksite.call("_on_processor_technology_toggled", true)
	technology_states = worksite.get("processor_technology_enabled_states")
	if not technology_toggle.button_pressed or not bool(technology_states.get("Control Unit", false)) or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 1.20):
		_fail("Processor Technologies enable toggle did not update the selected technology state.")
		worksite.free()
		return
	for technology_index in range(14):
		worksite.call("_on_processor_technology_next_pressed")
	if technology_name_label.text != "Security Processing Unit" or int(worksite.get("processor_technology_selected_index")) != 14 or not technology_next.disabled or technology_previous.disabled or technology_toggle.disabled:
		_fail("Processor Technologies plus navigation did not reach the unlocked fifteenth and final entry.")
		worksite.free()
		return
	worksite.call("_on_processor_technology_toggled", true)
	if not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 4.00) or technology_level_value.text != "4.00 TP":
		_fail("Processor Technologies did not add the approved unlocks to the shared TP total.")
		worksite.free()
		return
	worksite.call("_on_processor_technology_previous_pressed")
	if technology_name_label.text != "Debug and Test Unit":
		_fail("Processor Technologies minus navigation did not move to the previous entry.")
		worksite.free()
		return
	for technology_index in range(14):
		worksite.call("_on_processor_technology_previous_pressed")
	if technology_name_label.text != "Control Unit" or not technology_previous.disabled:
		_fail("Processor Technologies did not return to its first entry or disable the minus control.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	var cpu_core_slider := worksite.find_child("ProcessorCpuCoreSlider", true, false) as HSlider
	var cpu_core_value := worksite.find_child("ProcessorCpuCoreCountValue", true, false) as Label
	var cpu_core_range := worksite.find_child("ProcessorCpuCoreRangeLabel", true, false) as Label
	if int(worksite.get("current_wizard_step")) != 4 or progress_bar.value != 4 or next_step_button.disabled or cpu_core_slider == null or cpu_core_value == null or cpu_core_range == null:
		_fail("Processor CPU Cores is not available as the fourth worksite step with its slider and labels.")
		worksite.free()
		return
	if cpu_core_slider.min_value != 1.0 or cpu_core_slider.max_value != 1.0 or cpu_core_slider.step != 1.0 or cpu_core_value.text != "1 CORE" or cpu_core_range.text != "AVAILABLE RANGE: 1–1 CORES":
		_fail("Processor CPU Cores did not initialize at the one-core baseline.")
		worksite.free()
		return
	worksite.call("set_cpu_core_research_level", 2)
	if cpu_core_slider.max_value != 3.0 or cpu_core_range.text != "AVAILABLE RANGE: 1–3 CORES":
		_fail("CPU Core research approval did not progressively expand the selectable core-count range.")
		worksite.free()
		return
	cpu_core_slider.value = 3.0
	if int(worksite.get("processor_cpu_core_count")) != 3 or cpu_core_value.text != "3 CORES" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 19.00) or technology_level_value.text != "19.00 TP":
		_fail("CPU Core selection did not update the selected count and shared Processor Technology Points total.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	var scheduler_slider := worksite.find_child("ProcessorInstructionSchedulerSlider", true, false) as HSlider
	var scheduler_value := worksite.find_child("ProcessorInstructionSchedulerEntryValue", true, false) as Label
	var scheduler_range := worksite.find_child("ProcessorInstructionSchedulerRangeLabel", true, false) as Label
	if int(worksite.get("current_wizard_step")) != 5 or progress_bar.value != 5 or next_step_button.disabled or scheduler_slider == null or scheduler_value == null or scheduler_range == null:
		_fail("Instruction Scheduler is not available as the fifth worksite step with its slider and labels.")
		worksite.free()
		return
	if scheduler_slider.min_value != 0.0 or scheduler_slider.max_value != 0.0 or scheduler_slider.step != 1.0 or scheduler_value.text != "8 ENTRIES" or scheduler_range.text != "AVAILABLE RANGE: 8–8 ENTRIES":
		_fail("Instruction Scheduler did not initialize at the 8-entry baseline.")
		worksite.free()
		return
	worksite.call("set_instruction_scheduler_research_level", 4)
	if scheduler_slider.max_value != 4.0 or scheduler_range.text != "AVAILABLE RANGE: 8–48 ENTRIES":
		_fail("Instruction Scheduler approvals did not progressively expand its selectable capacity.")
		worksite.free()
		return
	scheduler_slider.value = 4.0
	if int(worksite.get("processor_instruction_scheduler_selected_level")) != 4 or scheduler_value.text != "48 ENTRIES" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 29.80) or technology_level_value.text != "29.80 TP":
		_fail("Instruction Scheduler selection did not update the entry capacity and shared Technology Points total.")
		worksite.free()
		return
	worksite.call("set_instruction_scheduler_research_level", 2)
	if scheduler_slider.max_value != 2.0 or int(worksite.get("processor_instruction_scheduler_selected_level")) != 2 or scheduler_value.text != "24 ENTRIES" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 24.40):
		_fail("Instruction Scheduler selection did not clamp to the approved research ceiling.")
		worksite.free()
		return
	worksite.call("set_instruction_scheduler_research_level", 13)
	if scheduler_slider.max_value != 13.0 or scheduler_range.text != "AVAILABLE RANGE: 8–500 ENTRIES":
		_fail("Instruction Scheduler did not expose the complete 500-entry research ceiling.")
		worksite.free()
		return
	scheduler_slider.value = 13.0
	if scheduler_value.text != "500 ENTRIES" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 54.10):
		_fail("Maximum Instruction Scheduler capacity did not contribute its full shared TP value.")
		worksite.free()
		return
	worksite.call("_on_next_pressed")
	var l1_cache_slider := worksite.find_child("ProcessorL1CacheSlider", true, false) as HSlider
	var l1_cache_value := worksite.find_child("ProcessorL1CacheCapacityValue", true, false) as Label
	var l1_cache_range := worksite.find_child("ProcessorL1CacheRangeLabel", true, false) as Label
	if int(worksite.get("current_wizard_step")) != 6 or progress_bar.value != 6 or next_step_button.disabled or l1_cache_slider == null or l1_cache_value == null or l1_cache_range == null:
		_fail("L1 Cache is not available as the sixth worksite step with its slider and labels.")
		worksite.free()
		return
	if l1_cache_slider.min_value != 0.0 or l1_cache_slider.max_value != 0.0 or l1_cache_slider.step != 1.0 or l1_cache_value.text != "2 KB" or l1_cache_range.text != "AVAILABLE RANGE: 2–2 KB":
		_fail("L1 Cache did not initialize at its 2 KB baseline.")
		worksite.free()
		return
	worksite.call("set_l1_cache_research_level", 4)
	if l1_cache_slider.max_value != 4.0 or l1_cache_range.text != "AVAILABLE RANGE: 2–10 KB":
		_fail("L1 Cache research did not expand the selectable capacity in 2 KB increments.")
		worksite.free()
		return
	l1_cache_slider.value = 4.0
	if int(worksite.get("processor_l1_cache_selected_level")) != 4 or l1_cache_value.text != "10 KB" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 54.50) or technology_level_value.text != "54.50 TP":
		_fail("L1 Cache selection did not update capacity and the shared Technology Points total.")
		worksite.free()
		return
	worksite.call("set_l1_cache_research_level", 149)
	if l1_cache_slider.max_value != 149.0 or l1_cache_range.text != "AVAILABLE RANGE: 2–300 KB":
		_fail("L1 Cache did not expose the full 300 KB research ceiling.")
		worksite.free()
		return
	l1_cache_slider.value = 149.0
	if l1_cache_value.text != "300 KB" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 69.00):
		_fail("Maximum L1 Cache capacity did not contribute its full shared TP value.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	var l2_cache_slider := worksite.find_child("ProcessorL2CacheSlider", true, false) as HSlider
	var l2_cache_value := worksite.find_child("ProcessorL2CacheCapacityValue", true, false) as Label
	var l2_cache_range := worksite.find_child("ProcessorL2CacheRangeLabel", true, false) as Label
	if int(worksite.get("current_wizard_step")) != 7 or progress_bar.value != 7 or next_step_button.disabled or l2_cache_slider == null or l2_cache_value == null or l2_cache_range == null:
		_fail("L2 Cache is not available as the seventh worksite step with its slider and labels.")
		worksite.free()
		return
	if l2_cache_slider.min_value != 0.0 or l2_cache_slider.max_value != 0.0 or l2_cache_slider.step != 1.0 or l2_cache_value.text != "128 KB" or l2_cache_range.text != "AVAILABLE RANGE: 128–128 KB":
		_fail("L2 Cache did not initialize at its 128 KB baseline.")
		worksite.free()
		return
	worksite.call("set_l2_cache_research_level", 4)
	if l2_cache_slider.max_value != 4.0 or l2_cache_range.text != "AVAILABLE RANGE: 128–640 KB":
		_fail("L2 Cache research did not expand the selectable capacity in 128 KB increments.")
		worksite.free()
		return
	l2_cache_slider.value = 4.0
	if int(worksite.get("processor_l2_cache_selected_level")) != 4 or l2_cache_value.text != "640 KB" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 69.40) or technology_level_value.text != "69.40 TP":
		_fail("L2 Cache selection did not update capacity and the shared Technology Points total.")
		worksite.free()
		return
	worksite.call("set_l2_cache_research_level", 149)
	if l2_cache_slider.max_value != 149.0 or l2_cache_range.text != "AVAILABLE RANGE: 128–19200 KB":
		_fail("L2 Cache did not expose the full 19200 KB research ceiling.")
		worksite.free()
		return
	l2_cache_slider.value = 149.0
	if l2_cache_value.text != "19200 KB" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 83.90):
		_fail("Maximum L2 Cache capacity did not contribute its full shared TP value.")
		worksite.free()
		return

	worksite.call("_on_next_pressed")
	var l3_cache_slider := worksite.find_child("ProcessorL3CacheSlider", true, false) as HSlider
	var l3_cache_value := worksite.find_child("ProcessorL3CacheCapacityValue", true, false) as Label
	var l3_cache_range := worksite.find_child("ProcessorL3CacheRangeLabel", true, false) as Label
	if int(worksite.get("current_wizard_step")) != 8 or progress_bar.value != 8 or not next_step_button.disabled or l3_cache_slider == null or l3_cache_value == null or l3_cache_range == null:
		_fail("L3 Cache is not available as the eighth and final worksite step with its slider and labels.")
		worksite.free()
		return
	if l3_cache_slider.min_value != 0.0 or l3_cache_slider.max_value != 0.0 or l3_cache_slider.step != 1.0 or l3_cache_value.text != "1024 KB" or l3_cache_range.text != "AVAILABLE RANGE: 1024–1024 KB":
		_fail("L3 Cache did not initialize at its 1024 KB baseline.")
		worksite.free()
		return
	worksite.call("set_l3_cache_research_level", 4)
	if l3_cache_slider.max_value != 4.0 or l3_cache_range.text != "AVAILABLE RANGE: 1024–5120 KB":
		_fail("L3 Cache research did not expand the selectable capacity in 1024 KB increments.")
		worksite.free()
		return
	l3_cache_slider.value = 4.0
	if int(worksite.get("processor_l3_cache_selected_level")) != 4 or l3_cache_value.text != "5120 KB" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 84.30) or technology_level_value.text != "84.30 TP":
		_fail("L3 Cache selection did not update capacity and the shared Technology Points total.")
		worksite.free()
		return
	worksite.call("set_l3_cache_research_level", 149)
	if l3_cache_slider.max_value != 149.0 or l3_cache_range.text != "AVAILABLE RANGE: 1024–153600 KB":
		_fail("L3 Cache did not expose the full 153600 KB research ceiling.")
		worksite.free()
		return
	l3_cache_slider.value = 149.0
	if l3_cache_value.text != "153600 KB" or not is_equal_approx(float(worksite.call("_calculate_processor_technology_points")), 98.80):
		_fail("Maximum L3 Cache capacity did not contribute its full shared TP value.")
		worksite.free()
		return

	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 7 or progress_bar.value != 7 or next_step_button.disabled:
		_fail("Processor Back navigation did not return from L3 Cache to L2 Cache.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 6 or progress_bar.value != 6 or next_step_button.disabled:
		_fail("Processor Back navigation did not return from L2 Cache to L1 Cache.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 5 or progress_bar.value != 5 or next_step_button.disabled:
		_fail("Processor Back navigation did not return from L1 Cache to Instruction Scheduler.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 4 or progress_bar.value != 4 or next_step_button.disabled:
		_fail("Processor Back navigation did not return from Instruction Scheduler to CPU Cores.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 3 or progress_bar.value != 3 or next_step_button.disabled:
		_fail("Processor Back navigation did not return from CPU Cores to Technologies.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 2 or progress_bar.value != 2 or next_step_button.disabled:
		_fail("Processor Back navigation did not return from Technologies to colour.")
		worksite.free()
		return
	worksite.call("_on_wizard_back_pressed")
	if int(worksite.get("current_wizard_step")) != 1 or progress_bar.value != 1:
		_fail("Processor Back navigation did not return from colour to design selection.")
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
	if name_control != null or worksite.get("processor_color") != Color("#A5AAAE"):
		_fail("Processor worksite still shows a name field or failed to restore a legacy named processor colour.")
		worksite.free()
		return
	worksite.configure_design({
		"design_id": "dw_silicon_01",
		"package_size": "14 × 14 mm",
		"processor_color": "#A5AAAE",
		"processor_gradient_color": "#C65B8E",
		"processor_gradient_enabled": true,
		"processor_gradient_direction": 2,
		"cpu_core_count": 3,
		"instruction_scheduler_entries": 500,
		"l1_cache_kb": 300,
		"l2_cache_kb": 1024,
		"l3_cache_kb": 1024,
		"processor_technology_enabled_states": {
			"Control Unit": true,
			"Security Processing Unit": true
		}
	})
	var restored_toggle := worksite.find_child("EnableProcessorGradient", true, false) as TextureButton
	var restored_shader := recolored_surface.material_override as ShaderMaterial
	if restored_toggle == null or not restored_toggle.button_pressed or not bool(worksite.get("processor_gradient_enabled")) or int(worksite.get("processor_gradient_direction")) != 2 or restored_shader == null:
		_fail("Processor worksite did not restore the saved gradient editor state.")
		worksite.free()
		return

	var emitted_design: Array = []
	worksite.design_saved.connect(func(design: Dictionary): emitted_design.append(design))
	var l2_save_slider := worksite.find_child("ProcessorL2CacheSlider", true, false) as HSlider
	var l3_save_slider := worksite.find_child("ProcessorL3CacheSlider", true, false) as HSlider
	if l2_save_slider == null or l3_save_slider == null:
		_fail("Processor design save is missing one or both cache capacity controls.")
		worksite.free()
		return
	l2_save_slider.value = 7.0
	l3_save_slider.value = 9.0
	worksite.call("_save_design")
	if emitted_design.size() != 1 or str(emitted_design[0].get("name", "")) != "DW SILICON 01" or int(emitted_design[0].get("cpu_core_count", 0)) != 3 or int(emitted_design[0].get("instruction_scheduler_entries", 0)) != 500:
		_fail("Save Processor Design did not use the selected design's preset name.")
		worksite.free()
		return
	if int(emitted_design[0].get("l1_cache_kb", 0)) != 300 or int(emitted_design[0].get("l2_cache_kb", 0)) != 1024 or int(emitted_design[0].get("l3_cache_kb", 0)) != 1024:
		_fail("Save Processor Design did not persist all three selected cache capacities.")
		worksite.free()
		return
	worksite.call("configure_design", emitted_design[0])
	if int(worksite.get("processor_l2_cache_selected_level")) != 7 or int(worksite.get("processor_l3_cache_selected_level")) != 9:
		_fail("Processor Worksite did not restore the saved L2 and L3 cache selections.")
		worksite.free()
		return
	worksite.call("set_l2_cache_research_level", 149)
	worksite.call("set_l3_cache_research_level", 149)
	technology_states = worksite.get("processor_technology_enabled_states")
	if not bool(technology_states.get("Control Unit", false)) or not bool(technology_states.get("Security Processing Unit", false)):
		_fail("Processor Technology enable states did not restore with the saved processor design.")
		worksite.free()
		return
	if str(emitted_design[0].get("design_id", "")) != "dw_silicon_01":
		_fail("Saving the processor did not preserve the selected physical design identity.")
		worksite.free()
		return
	if str(emitted_design[0].get("package_size", "")) != "14 × 14 mm" or str(emitted_design[0].get("processor_color", "")) != "#A5AAAE":
		_fail("Save Processor Design did not preserve the configured package size and normal processor colour.")
		worksite.free()
		return
	if str(emitted_design[0].get("processor_gradient_color", "")) != "#C65B8E" or not bool(emitted_design[0].get("processor_gradient_enabled", false)) or int(emitted_design[0].get("processor_gradient_direction", -1)) != 2:
		_fail("Save Processor Design did not preserve gradient colour, enabled state, and direction.")
		worksite.free()
		return
	var saved_technology_states: Dictionary = emitted_design[0].get("processor_technology_enabled_states", {})
	if not bool(saved_technology_states.get("Control Unit", false)) or not bool(saved_technology_states.get("Security Processing Unit", false)):
		_fail("Save Processor Design did not preserve enabled Processor Technologies.")
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
