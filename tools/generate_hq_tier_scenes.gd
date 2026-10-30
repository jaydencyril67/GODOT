extends SceneTree

const HeadquartersScript = preload("res://scripts/world/digitalworld_headquarters.gd")
const OUTPUT_DIRECTORY := "res://scenes/world/headquarters_tiers"

func _initialize() -> void:
	call_deferred("_generate_tier_scenes")

func _generate_tier_scenes() -> void:
	# Remove the old external NoiseTexture2D resources. The new tier scenes
	# carry baked ImageTexture data inside each PackedScene.
	for legacy_path in [
		"res://scenes/world/headquarters_tiers/shared/facade_noise.tres",
		"res://scenes/world/headquarters_tiers/shared/facade_normal.tres"
	]:
		var absolute_path := ProjectSettings.globalize_path(legacy_path)
		if FileAccess.file_exists(legacy_path):
			var remove_error := DirAccess.remove_absolute(absolute_path)
			if remove_error != OK:
				push_error("Could not remove legacy HQ texture resource: " + legacy_path)
				quit(1)
				return

	var builder = HeadquartersScript.new()
	builder._create_material_library()
	builder._create_procedural_surface_textures()
	if builder.facade_noise == null or builder.facade_normal == null:
		push_error("HQ facade image textures could not be generated.")
		builder.free()
		quit(1)
		return

	# ImageTexture pixel data is embedded by PackedScene.pack() with the
	# materials that reference it. Tier scenes have no shared texture files.

	for level in range(1, 11):
		builder._build_procedural_building(level, true)
		var building: Node3D = builder.building_root
		if not is_instance_valid(building):
			push_error("HQ tier %02d did not produce a building root." % level)
			builder.free()
			quit(1)
			return

		builder.remove_child(building)
		_set_scene_owners(building, building)
		var packed_scene := PackedScene.new()
		var pack_error := packed_scene.pack(building)
		if pack_error != OK:
			push_error("Could not pack HQ tier %02d: %s" % [level, error_string(pack_error)])
			building.free()
			builder.free()
			quit(1)
			return

		var scene_path := "%s/level_%02d.tscn" % [OUTPUT_DIRECTORY, level]
		var save_error := ResourceSaver.save(packed_scene, scene_path)
		if save_error != OK:
			push_error("Could not save HQ tier %02d: %s" % [level, error_string(save_error)])
			building.free()
			builder.free()
			quit(1)
			return

		print("Generated prebuilt headquarters tier: ", scene_path)
		building.free()
		builder.building_root = null

	builder.free()
	print("Successfully generated all 10 prebuilt headquarters tier scenes.")
	quit(0)


func _set_scene_owners(node: Node, scene_root: Node) -> void:
	# PackedScene.pack() serializes only descendants owned by the packed root.
	# add_child() does not assign ownership, so explicitly own every generated part.
	for child in node.get_children():
		child.owner = scene_root
		_set_scene_owners(child, scene_root)
