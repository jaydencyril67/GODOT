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

		var geometry_count := _count_geometry_nodes(instance)
		if instance.get_child_count() == 0 or geometry_count == 0:
			push_error("HQ tier scene contains no saved building geometry: " + scene_path)
			instance.free()
			quit(1)
			return
		print("Validated prebuilt HQ tier ", level, " with ", geometry_count, " geometry nodes.")
		instance.free()

	print("All ten prebuilt HQ tier scenes loaded successfully.")
	quit(0)


func _count_geometry_nodes(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			count += 1
		count += _count_geometry_nodes(child)
	return count
