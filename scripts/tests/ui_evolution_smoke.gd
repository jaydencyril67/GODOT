extends SceneTree

const UIEvolutionEngineScript = preload("res://scripts/ui_evolution_engine.gd")
const GeneratedPhoneUIScript = preload("res://scripts/generated_phone_ui.gd")
const PhoneCreationWorksiteScript = preload("res://scripts/phone_creation_worksite.gd")
const ScreenTechnologySystemScript = preload("res://scripts/screen_technology_system.gd")

const TEST_SAVE_PATH := "user://ui_evolution_smoke_test.json"


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	if not await _check_generated_designs():
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
		var composition: Dictionary = home.get("composition", {})
		var widget_signature := ""
		for widget_value in widgets:
			widget_signature += str(widget_value.get("type", "")) + ","
		var placement_signature := ""
		for placement_value in composition.get("widget_placements", []):
			var placement: Dictionary = placement_value
			var rect_values: Array = placement.get("rect", [])
			for rect_value in rect_values:
				placement_signature += "%.2f," % float(rect_value)
			placement_signature += ";"
		var signature := "%s|%s|%s|%s|%s|%s|%s" % [
			str(style.get("palette", {}).get("name", "")),
			str(style.get("wallpaper_style", "")),
			str(style.get("icon_shape", "")),
			str(style.get("grid_columns", "")),
			widget_signature,
			placement_signature,
			str(home.get("search_position", ""))
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
	if not await _check_generated_ui_pixels():
		return false
	return true


func _check_generated_ui_pixels() -> bool:
	var viewport := SubViewport.new()
	viewport.name = "GeneratedPhoneUIPixelSmokeViewport"
	viewport.size = Vector2i(480, 960)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var renderer := GeneratedPhoneUIScript.new() as Control
	renderer.name = "GeneratedPhoneUIPixelSmokeRenderer"
	renderer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(renderer)
	renderer.set_blueprint({
		"style": {
			"palette": {
				"background": "#050814",
				"surface": "#E82018",
				"surface_alt": "#9C1515",
				"accent": "#5577AA",
				"accent_secondary": "#6688BB",
				"text": "#FFFFFF",
				"muted": "#DDE4EE"
			},
			"wallpaper_style": "soft_gradient",
			"composition_density": "balanced",
			"grid_columns": 4,
			"icon_shape": "rounded_square",
			"icon_size": 52,
			"corner_radius": 20,
			"spacing": 14,
			"surface_style": "soft_solid",
			"typography_scale": 1.0,
			"status_bar_style": "quiet",
			"navigation_style": "gesture",
			"accent_treatment": "subtle"
		},
		"home": {
			"widgets": [{"type": "clock", "emphasis": "hero", "variant": 0}],
			"composition": {
				"widget_placements": [{"type": "clock", "rect": [0.10, 0.20, 0.80, 0.20]}],
				"apps_top": 0.66,
				"region_bounds": [0.10, 0.20, 0.80, 0.20]
			},
			"apps": [
				{"name": "Test One", "glyph": "1", "color": "#00FF33"},
				{"name": "Test Two", "glyph": "2", "color": "#00FF33"},
				{"name": "Test Three", "glyph": "3", "color": "#00FF33"},
				{"name": "Test Four", "glyph": "4", "color": "#00FF33"},
				{"name": "Test Five", "glyph": "5", "color": "#00FF33"},
				{"name": "Test Six", "glyph": "6", "color": "#00FF33"},
				{"name": "Test Seven", "glyph": "7", "color": "#00FF33"},
				{"name": "Test Eight", "glyph": "8", "color": "#00FF33"}
			],
			"dock": ["Phone", "Messages", "Browser", "Camera"],
			"show_search": false
		},
		"system": {
			"time_format": "24h",
			"battery_percent": 88,
			"network_label": "5G",
			"show_battery_percent": false
		}
	})

	await process_frame
	await process_frame
	await process_frame
	var rendered_image := viewport.get_texture().get_image()
	if rendered_image == null or rendered_image.get_width() != 480 or rendered_image.get_height() != 960:
		viewport.free()
		_fail("The generated UI renderer did not produce a readable 480x960 screen image.")
		return false

	# The widget surface and app icon use unique colors which cannot come from
	# the wallpaper. Their pixels prove those UI layers were actually drawn.
	var widget_pixel := rendered_image.get_pixel(400, 280)
	var icon_pixel := rendered_image.get_pixel(61, 620)
	var widget_visible := widget_pixel.r > 0.45 and widget_pixel.g < 0.30
	var app_visible := icon_pixel.g > 0.45 and icon_pixel.r < 0.30
	viewport.free()
	if not widget_visible or not app_visible:
		_fail("The generated screen image contains wallpaper but is missing visible widget or app-icon pixels.")
		return false
	return true


func _check_phone_screen_integration() -> bool:
	var worksite := PhoneCreationWorksiteScript.new()
	worksite.name = "UIEvolutionPhoneScreenSmokeWorksite"
	root.add_child(worksite)
	await process_frame
	worksite.call("_show_ui_evolution_step")
	await process_frame
	await process_frame

	var screen := worksite.get("phone_screen") as MeshInstance3D
	var ui_viewport := worksite.get("phone_ui_viewport") as SubViewport
	var ui_renderer := worksite.get("phone_ui_renderer") as Control
	if screen == null or ui_viewport == null or ui_renderer == null:
		worksite.queue_free()
		_fail("The standalone UI Evolution feature did not create its phone screen viewport and renderer.")
		return false
	if not bool(worksite.get("screen_enabled")) or screen.mesh == null:
		worksite.queue_free()
		_fail("The generated interface did not enable the physical 3D phone display.")
		return false

	if not _has_generated_screen_texture(screen):
		worksite.queue_free()
		_fail("The Standard phone display is missing its generated viewport texture or UV mapping.")
		return false

	# The interface must render into an opaque, higher-density target. Screen
	# research must affect glass optics without tinting away readable UI pixels.
	if ui_viewport.size != Vector2i(480, 960) or ui_viewport.transparent_bg:
		worksite.queue_free()
		_fail("The generated UI viewport is not using the expected opaque high-density display target.")
		return false
	var screen_material := screen.material_override as ShaderMaterial
	var screen_quality: Dictionary = worksite.get("screen_quality_state")
	var screen_profile: Dictionary = ScreenTechnologySystemScript.get_visual_profile(screen_quality)
	if screen_material == null or screen_material.shader == null:
		worksite.queue_free()
		_fail("The generated screen is missing its clarity and glass-response shader.")
		return false
	var shader_source := screen_material.shader.code
	if shader_source.contains("ALPHA =") or not shader_source.contains("screen_reflection_strength") or not shader_source.contains("ALBEDO = display_rgb"):
		worksite.queue_free()
		_fail("The generated screen shader does not preserve opacity or screen-technology optical controls.")
		return false
	var expected_reflection := float(screen_profile.get("specular", 0.55))
	var actual_reflection := float(screen_material.get_shader_parameter("screen_reflection_strength"))
	if not is_equal_approx(actual_reflection, expected_reflection):
		worksite.queue_free()
		_fail("Screen reflection reduction is not connected to the generated display glass.")
		return false

	# Verify the same live interface maps onto both foldable inner displays.
	worksite.call("set_phone_type_research_level", 2)
	worksite.call("_on_phone_type_increase_pressed")
	await process_frame
	var flip_screen := worksite.get("phone_screen") as MeshInstance3D
	if str(worksite.get("selected_phone_type")) != "Flip" or not _has_generated_screen_texture(flip_screen):
		worksite.queue_free()
		_fail("The generated interface did not map correctly onto the Flip's inner display.")
		return false
	worksite.call("_on_phone_type_increase_pressed")
	await process_frame
	var fold_screen := worksite.get("phone_screen") as MeshInstance3D
	if str(worksite.get("selected_phone_type")) != "Fold" or not _has_generated_screen_texture(fold_screen):
		worksite.queue_free()
		_fail("The generated interface did not map correctly onto the Fold's inner display.")
		return false

	# Confirm the new UI research step sits immediately after Cooling System Design.
	worksite.call("_show_cooling_system_step")
	worksite.call("_on_next_pressed")
	if int(worksite.get("wizard_step")) != 30:
		worksite.queue_free()
		_fail("The phone-interface design step is not positioned after Cooling System Design.")
		return false
	var progress_label := worksite.get("progress_number") as Label
	if progress_label == null or progress_label.text != "STEP 31 / 38":
		worksite.queue_free()
		_fail("The phone-interface design step did not update the 38-step progress counter.")
		return false
	worksite.call("_on_next_pressed")
	if int(worksite.get("wizard_step")) != 31:
		worksite.queue_free()
		_fail("Box Package did not follow the phone-interface design step.")
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


func _has_generated_screen_texture(screen: MeshInstance3D) -> bool:
	if not is_instance_valid(screen) or screen.mesh == null:
		return false
	var material := screen.material_override as ShaderMaterial
	if material == null:
		return false
	var texture := material.get_shader_parameter("screen_texture") as Texture2D
	if texture == null or screen.mesh.get_surface_count() <= 0:
		return false
	var mesh_arrays: Array = screen.mesh.surface_get_arrays(0)
	var uv_values: PackedVector2Array = mesh_arrays[Mesh.ARRAY_TEX_UV]
	return not uv_values.is_empty()


func _fail(message: String) -> void:
	push_error(message)
	print("UI_EVOLUTION_SMOKE_TEST: FAIL — " + message)
