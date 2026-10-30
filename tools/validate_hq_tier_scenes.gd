extends SceneTree

func _initialize() -> void:
	call_deferred("_validate_tier_scenes")

func _validate_tier_scenes() -> void:
	for level in range(1, 11):
		var scene_path := "res://scenes/world/headquarters_tiers/level_%02d.tscn" % level
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			push_error("Missing or invalid HQ tier scene: " + scene_path)
			quit(1)
			return

		var instance := packed.instantiate() as Node3D
		if instance == null:
			push_error("HQ tier scene has an invalid Node3D root: " + scene_path)
			quit(1)
			return

		var report := {"geometry": 0, "materials": 0, "baked_textures": 0, "normal_maps": 0}
		_inspect_saved_appearance(instance, report)
		if instance.get_child_count() == 0 or report.geometry == 0:
			push_error("HQ tier scene contains no saved building geometry: " + scene_path)
			instance.free()
			quit(1)
			return
		if report.materials < 3 or report.baked_textures < 2 or report.normal_maps < 1:
			push_error("HQ tier scene is missing embedded facade materials/textures: %s (geometry=%d, materials=%d, baked_textures=%d, normal_maps=%d)" % [
				scene_path, report.geometry, report.materials, report.baked_textures, report.normal_maps
			])
			instance.free()
			quit(1)
			return

		print("Validated HQ tier ", level, ": ", report.geometry, " meshes, ",
			report.materials, " materials, ", report.baked_textures,
			" baked textures, ", report.normal_maps, " normal maps.")
		instance.free()

	print("All ten HQ tier scenes contain geometry and embedded appearance resources.")
	quit(0)


func _inspect_saved_appearance(node: Node, report: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			report.geometry += 1
			var material: Material = mesh_instance.material_override
			if material == null and mesh_instance.mesh.get_surface_count() > 0:
				material = mesh_instance.mesh.surface_get_material(0)
			if material is StandardMaterial3D:
				report.materials += 1
				var standard := material as StandardMaterial3D
				if standard.albedo_texture != null:
					if _has_baked_image(standard.albedo_texture):
						report.baked_textures += 1
				if standard.normal_texture != null:
					if _has_baked_image(standard.normal_texture):
						report.normal_maps += 1

	for child in node.get_children():
		_inspect_saved_appearance(child, report)


func _has_baked_image(texture: Texture2D) -> bool:
	if texture is NoiseTexture2D:
		return false
	var image := texture.get_image()
	return image != null and not image.is_empty()
