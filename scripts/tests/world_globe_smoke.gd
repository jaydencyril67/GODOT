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
	if not _has_godot_clockwise_front_faces(earth.mesh):
		_fail("Earth surface triangles are wound backwards and will be culled from outside.")
		return
	if clouds == null or clouds.mesh == null:
		_fail("The separate cloud shell is missing.")
		return
	if atmosphere == null or atmosphere.mesh == null:
		_fail("The atmospheric rim is missing.")
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
	var detected_country: Dictionary = globe.call("_find_country_at_front")
	if detected_country.is_empty() or str(detected_country.get("properties", {}).get("ADM0_A3", "")) != "TST":
		_fail("The globe did not resolve the country at the center of its current view.")
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
	globe.call("_set_zoom", 2.2)
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
