extends SceneTree

const UIEvolutionEngineScript = preload("res://scripts/ui_evolution_engine.gd")
const GeneratedPhoneUIScript = preload("res://scripts/generated_phone_ui.gd")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")
const PhoneCreationWorksiteScript = preload("res://scripts/phone_creation_worksite.gd")

const TEST_SAVE_PATH := "user://ui_evolution_smoke_test.json"


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	if not _check_generated_designs():
		quit(1)
		return
	if not _check_research_unlock():
		quit(1)
		return
	if not await _check_phone_screen_integration():
		quit(1)
		return
	print("UI_EVOLUTION_SMOKE_TEST: PASS")
	quit()


func _check_generated_designs() -> bool:
	var signatures: Dictionary = {}
	var latest_design: Dictionary = {}
	for seed_value in range(1, 81):
		var device_specs := {
			"phone_type": "Standard",
			"mobile_network": "3G",
			"refresh_rate": "120 Hz",
			"display_technology": "AMOLED"
		}
		var design: Dictionary = UIEvolutionEngineScript.generate_ui(seed_value, device_specs)
		var issues: PackedStringArray = UIEvolutionEngineScript.validate_ui(design)
		if not issues.is_empty():
			_fail("Generated design %d failed validation: %s" % [seed_value, "; ".join(issues)])
			return false

		var home: Dictionary = design.get("home", {})
		var apps: Array = home.get("apps", [])
		var dock: Array = home.get("dock", [])
		var widgets: Array = home.get("widgets", [])
		if apps.size() < 6 or apps.size() > 12 or dock.size() != 4 or widgets.is_empty():
			_fail("Generated design %d contains an invalid app, dock or widget arrangement." % seed_value)
			return false
		for app_value in apps:
			if not app_value is Dictionary:
				_fail("Generated app entry is not a structured application record.")
				return false
			if dock.has(str(app_value.get("name", ""))):
				_fail("A home-screen app was duplicated in the dock.")
				return false
		if str(design.get("system", {}).get("network_label", "")) != "3G":
			_fail("The generated status bar ignored the phone's researched mobile network.")
			return false

		var style: Dictionary = design.get("style", {})
		var widget_signature := ""
		for widget_value in widgets:
			widget_signature += str(widget_value.get("type", "")) + ","
		var signature := "%s|%s|%s|%s|%s|%s|%s" % [
			str(style.get("layout_archetype", "")),
			str(style.get("palette", {}).get("name", "")),
			str(style.get("wallpaper_style", "")),
			str(style.get("icon_shape", "")),
			str(style.get("grid_columns", "")),
			widget_signature,
			str(design.get("name", ""))
		]
		signatures[signature] = true
		latest_design = design

	if signatures.size() < 30:
		_fail("The generator produced too few distinct compositions across 80 independent seeds.")
		return false

	if not UIEvolutionEngineScript.save_ui(latest_design, TEST_SAVE_PATH):
		_fail("The generated UI blueprint could not be saved.")
		return false
	var restored := UIEvolutionEngineScript.load_ui(TEST_SAVE_PATH)
	if restored.is_empty() or int(restored.get("seed", -1)) != int(latest_design.get("seed", -2)):
		_fail("The saved UI blueprint did not restore with its original generation seed.")
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	var renderer := GeneratedPhoneUIScript.new() as Control
	if not is_instance_valid(renderer):
		_fail("The generated phone UI renderer could not be instantiated.")
		return false
	root.add_child(renderer)
	renderer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	renderer.call("set_blueprint", latest_design)
	await process_frame
	var rendered_blueprint: Dictionary = renderer.get("blueprint")
	var renderer_ready := not rendered_blueprint.is_empty() and str(rendered_blueprint.get("name", "")) == str(latest_design.get("name", ""))
	renderer.queue_free()
	if not renderer_ready:
		_fail("The phone screen renderer did not receive the validated UI blueprint.")
		return false
	return true


func _check_research_unlock() -> bool:
	if not ResearchManagerScript.COMPONENT_CATALOGUE.has("UI Evolution"):
		_fail("UI Evolution is missing from the central R&D component catalogue.")
		return false
	if ResearchManagerScript.get_component_research_duration_days("UI Evolution") != 30.0:
		_fail("UI Evolution should use the standard 30-day research duration.")
		return false

	var career: Dictionary = {
		"staff_employees": [{
			"id": "ui_evolution_researcher",
			"department": "Research",
			"efficiency": 100
		}],
		"research_projects": [],
		"research_component_levels": {},
		"research_technologies": {},
		"next_research_project_id": 1
	}
	var commission: Dictionary = ResearchManagerScript.commission_project(career, {
		"component": "UI Evolution",
		"staff_ids": ["ui_evolution_researcher"]
	}, 1000.0)
	if not bool(commission.get("ok", false)):
		_fail("The UI Evolution research project could not be commissioned.")
		return false
	var project: Dictionary = commission.get("project", {})
	if str(project.get("research_target", "")) != "Procedural UI Generator" or int(project.get("research_target_index", -1)) != 1:
		_fail("The UI Evolution project did not store its one-time generator unlock target.")
		return false
	if float(project.get("required_research_days", 0.0)) != 30.0:
		_fail("The UI Evolution research duration was not stored correctly.")

	var duplicate: Dictionary = ResearchManagerScript.commission_project(career, {
		"component": "UI Evolution",
		"staff_ids": ["ui_evolution_researcher"]
	}, 1000.0)
	if bool(duplicate.get("ok", false)):
		_fail("A duplicate UI Evolution research project was allowed.")
		return false

	var projects: Array = career.get("research_projects", [])
	projects[0]["status"] = ResearchManagerScript.STATUS_AWAITING_VALIDATION
	career["research_projects"] = projects
	var invalid: Dictionary = ResearchManagerScript.approve_project(career, str(project.get("id", "")), [{
		"component": "UI Evolution",
		"metric": "Generator validation",
		"value": "Fixed manufacturer template"
	}], 2000.0)
	if bool(invalid.get("ok", false)) or int(career.get("research_component_levels", {}).get("UI Evolution", 0)) != 0:
		_fail("UI Evolution accepted a validation result that did not match its assigned generator target.")
		return false

	var approval: Dictionary = ResearchManagerScript.approve_project(career, str(project.get("id", "")), [{
		"component": "UI Evolution",
		"metric": "Generator validation",
		"value": "Procedural UI Generator"
	}], 2000.0)
	if not bool(approval.get("ok", false)) or int(career.get("research_component_levels", {}).get("UI Evolution", 0)) != 1:
		_fail("Approved UI Evolution research did not unlock the procedural generator.")
		return false
	var second_unlock: Dictionary = ResearchManagerScript.commission_project(career, {
		"component": "UI Evolution",
		"staff_ids": ["ui_evolution_researcher"]
	}, 3000.0)
	if bool(second_unlock.get("ok", false)):
		_fail("UI Evolution incorrectly allowed a second initial generator unlock.")
		return false
	return true


func _check_phone_screen_integration() -> bool:
	var worksite := PhoneCreationWorksiteScript.new()
	worksite.name = "UIEvolutionPhoneScreenSmokeWorksite"
	root.add_child(worksite)
	await process_frame
	worksite.call("set_ui_evolution_research_level", 1)
	await process_frame
	await process_frame

	var screen := worksite.get("phone_screen") as MeshInstance3D
	var ui_viewport := worksite.get("phone_ui_viewport") as SubViewport
	var ui_renderer := worksite.get("phone_ui_renderer") as Control
	if screen == null or ui_viewport == null or ui_renderer == null:
		worksite.queue_free()
		_fail("The first UI Evolution design did not create its phone screen viewport and renderer.")
		return false
	if not bool(worksite.get("screen_enabled")) or screen.mesh == null:
		worksite.queue_free()
		_fail("The generated interface did not enable the physical 3D phone display.")
		return false

	var screen_material := screen.material_override as ShaderMaterial
	if screen_material == null:
		worksite.queue_free()
		_fail("The physical phone display is not using the generated UI screen material.")
		return false
	var texture := screen_material.get_shader_parameter("screen_texture") as Texture2D
	if texture == null:
		worksite.queue_free()
		_fail("The physical phone display shader is missing its generated UI viewport texture.")
		return false
	var mesh_arrays: Array = screen.mesh.surface_get_arrays(0)
	var uv_values: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV]
	if uv_values.is_empty():
		worksite.queue_free()
		_fail("The physical phone display mesh does not contain UV coordinates for the generated interface.")
		return false
	var generated_config: Dictionary = worksite.get("ui_evolution_configuration")
	if generated_config.is_empty() or str(generated_config.get("name", "")).is_empty():
		worksite.queue_free()
		_fail("The generated UI configuration was not applied to the phone.")
		return false

	worksite.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UIEvolutionEngineScript.SAVE_PATH))
	return true


func _fail(message: String) -> void:
	push_error(message)
	print("UI_EVOLUTION_SMOKE_TEST: FAIL — " + message)
