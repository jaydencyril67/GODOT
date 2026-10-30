extends SceneTree

const HeadquartersScript = preload("res://scripts/world/digitalworld_headquarters.gd")
const OUTPUT_DIRECTORY := "res://scenes/world/headquarters_tiers"
const SHARED_DIRECTORY := "res://scenes/world/headquarters_tiers/shared"

func _initialize() -> void:
	call_deferred("_generate_tier_scenes")

func _generate_tier_scenes() -> void:
	var builder = HeadquartersScript.new()
	builder._create_material_library()
	builder._create_procedural_surface_textures()

	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHARED_DIRECTORY))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("Could not create shared headquarters resource directory: %s" % error_string(directory_error))
		builder.free()
		quit(1)
		return

	# Store the two generated facade textures once as shared external resources.
	# All ten tier scenes will reference these same files instead of embedding
	# ten duplicate copies of the procedural texture data.
	var noise_path := SHARED_DIRECTORY + "/facade_noise.tres"
	var normal_path := SHARED_DIRECTORY + "/facade_normal.tres"
	builder.facade_noise.take_over_path(noise_path)
	builder.facade_normal.take_over_path(normal_path)
	var noise_error := ResourceSaver.save(builder.facade_noise, noise_path)
	var normal_error := ResourceSaver.save(builder.facade_normal, normal_path)
	if noise_error != OK or normal_error != OK:
		push_error("Could not save shared HQ facade textures.")
		builder.free()
		quit(1)
		return

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
