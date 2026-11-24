extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var packed_scene := load("res://scenes/world_globe.tscn") as PackedScene
	if packed_scene == null:
		_fail("The standalone globe scene could not be loaded.")
		return

	var globe := packed_scene.instantiate()
	root.add_child(globe)
	await process_frame

	var camera := globe.find_child("GlobeCamera", true, false) as Camera3D
	var earth := globe.find_child("EarthSurface", true, false) as MeshInstance3D
	var clouds := globe.find_child("ProceduralCloudDeck", true, false) as MeshInstance3D
	var atmosphere := globe.find_child("BlueAtmosphericRim", true, false) as MeshInstance3D

	if camera == null or not camera.current:
		_fail("The globe scene did not activate its dedicated camera.")
		return
	if earth == null or earth.mesh == null or earth.mesh.get_surface_count() == 0:
		_fail("The globe is missing its rendered Earth sphere.")
		return
	if not earth.material_override is StandardMaterial3D:
		_fail("The Earth surface must use a lit StandardMaterial3D for reliable 3D shading.")
		return
	var earth_material := earth.material_override as StandardMaterial3D
	if earth_material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		_fail("Earth imagery must retain mipmapped filtering for clear zoom transitions.")
		return
	if not _has_godot_clockwise_front_faces(earth.mesh):
		_fail("Earth surface triangles are wound backwards and will be culled from outside.")
		return
	if clouds == null or clouds.mesh == null:
		_fail("The separate cloud shell is missing.")
		return
	if atmosphere == null or atmosphere.mesh == null:
		_fail("The atmospheric rim is missing.")
		return
	if globe.find_child("GlobeDiagnosticsPanel", true, false) == null:
		_fail("The live diagnostics panel is missing.")
		return
	var copy_button := globe.get("debug_copy_button") as Button
	if copy_button == null or copy_button.text != "COPY":
		_fail("The live diagnostics panel is missing its COPY button.")
		return
	var admin_panel := globe.find_child("ZoomOnlyAdministrativeData", true, false)
	if admin_panel != null:
		_fail("The globe must not show a manual country or province selector panel.")
		return

	var sample_geojson := {
		"type": "FeatureCollection",
		"features": [{
			"type": "Feature",
			"properties": {"ADMIN": "Testland", "NAME": "Testland", "ADM0_A3": "TST", "ISO_A3_EH": "TST", "LABEL_X": 0.0, "LABEL_Y": 0.0, "LABELRANK": 1},
			"bbox": [-10.0, -10.0, 10.0, 10.0],
			"geometry": {
				"type": "Polygon",
				"coordinates": [[[-10.0, -10.0], [10.0, -10.0], [10.0, 10.0], [-10.0, 10.0], [-10.0, -10.0]]]
			}
		}]
	}
	if not globe.call("_apply_country_boundaries", sample_geojson):
		_fail("The automatic world country-boundary layer could not be created.")
		return
	if globe.get("country_label_nodes").is_empty():
		_fail("Country name labels were not generated from the country dataset.")
		return
	var country_boundary := globe.get("country_boundary_node") as MeshInstance3D
	if country_boundary == null or country_boundary.visible:
		_fail("Country borders must be hidden at the default far-out globe view.")
		return
	var country_labels: Array = globe.get("country_label_nodes")
	for country_label in country_labels:
		if country_label.visible:
			_fail("Country names must remain hidden at the default far-out globe view.")
			return
		if country_label.font_size > 18:
			_fail("Country labels should use compact text.")
			return
	var detected_country: Dictionary = globe.call("_find_country_at_front")
	if detected_country.is_empty() or str(detected_country.get("properties", {}).get("ADM0_A3", "")) != "TST":
		_fail("The globe did not resolve the country at the center of its current view.")
		return

	var planet_root := globe.get("planet_root") as Node3D
	planet_root.rotation = Vector3.ZERO
	globe.call("_process", 1.0)
	if not planet_root.rotation.is_equal_approx(Vector3.ZERO):
		_fail("The globe must remain stationary when it is not being dragged.")
		return
	globe.call("_set_zoom", 3.65)
	globe.call("_drag_planet", Vector2(100.0, 0.0))
	var rotation_at_overview := planet_root.rotation.y
	planet_root.rotation = Vector3.ZERO
	globe.call("_set_zoom", 1.08)
	globe.call("_drag_planet", Vector2(100.0, 0.0))
	var rotation_at_close_zoom := planet_root.rotation.y
	if not is_equal_approx(rotation_at_overview, rotation_at_close_zoom):
		_fail("Drag rotation sensitivity must remain identical at every zoom level.")
		return
	planet_root.rotation = Vector3.ZERO
	globe.call("_set_zoom", 3.2)
	if not country_boundary.visible:
		_fail("Country borders did not appear after zooming closer.")
		return
	var country_label_visible := false
	for country_label in country_labels:
		country_label_visible = country_label_visible or country_label.visible
	if not country_label_visible:
		_fail("Country names did not appear at the country zoom level.")
		return

	globe.call("_set_zoom", 2.8)
	if globe.call("_is_province_zoom_active"):
		_fail("State/province boundaries should remain hidden at the country overview zoom.")
		return
	if absf(float(globe.get("target_distance")) - 2.8) > 0.001:
		_fail("The zoom-out view should remain within the configured overview range.")
		return
	globe.call("_set_zoom", 100.0)
	if absf(float(globe.get("target_distance")) - 3.65) > 0.001:
		_fail("Zooming out should stop at the initial globe view.")
		return
	globe.call("_set_zoom", -10.0)
	if absf(float(globe.get("target_distance")) - 1.08) > 0.001:
		_fail("The globe cannot zoom close enough to the regional layer.")
		return
	globe.call("_set_zoom", 1.7)
	if not globe.call("_is_province_zoom_active"):
		_fail("State/province boundaries did not activate at the closer map zoom.")
		return

	globe.set("focused_country_name", "Testland")
	var sample_adm1 := {
		"type": "FeatureCollection",
		"features": [{
			"type": "Feature",
			"properties": {"shapeName": "Test Province", "label_x": 0.0, "label_y": 0.0},
			"geometry": {
				"type": "Polygon",
				"coordinates": [[[-5.0, -5.0], [5.0, -5.0], [5.0, 5.0], [-5.0, 5.0], [-5.0, -5.0]]]
			}
		}]
	}
	if not globe.call("_apply_province_boundaries", sample_adm1):
		_fail("The automatic state/province boundary layer could not be created.")
		return
	var province_layer := globe.find_child("AutomaticStateProvinceBoundaries", true, false) as MeshInstance3D
	if province_layer == null or not province_layer.visible:
		_fail("State/province outlines did not appear at the closer map zoom.")
		return
	if globe.get("province_label_nodes").is_empty():
		_fail("State/province name labels were not generated from the ADM1 dataset.")
		return
	var province_labels: Array = globe.get("province_label_nodes")
	for province_label in province_labels:
		if province_label.font_size > 11 or province_label.pixel_size > 0.00055:
			_fail("State/province labels must remain compact and unobtrusive.")
			return

	globe.queue_free()
	await process_frame
	print("WORLD_GLOBE_SMOKE_TEST: PASS")
	quit()


func _has_godot_clockwise_front_faces(mesh: ArrayMesh) -> bool:
	if mesh.get_surface_count() == 0:
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or indices.size() < 3 or indices.size() % 3 != 0:
		return false
	var clockwise_faces := 0
	var counterclockwise_faces := 0
	for offset in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[offset]]
		var b: Vector3 = vertices[indices[offset + 1]]
		var c: Vector3 = vertices[indices[offset + 2]]
		var face_direction := (b - a).cross(c - a).dot((a + b + c) / 3.0)
		if face_direction < -0.0000001:
			clockwise_faces += 1
		elif face_direction > 0.0000001:
			counterclockwise_faces += 1
	return clockwise_faces > 0 and counterclockwise_faces == 0


func _fail(message: String) -> void:
	push_error(message)
	print("WORLD_GLOBE_SMOKE_TEST: FAIL: " + message)
	quit(1)
