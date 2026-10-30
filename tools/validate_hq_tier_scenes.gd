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
		if instance == null or instance.get_child_count() == 0:
			push_error("HQ tier scene is empty or has an invalid root: " + scene_path)
			if is_instance_valid(instance):
				instance.free()
			quit(1)
			return
		print("Validated prebuilt HQ tier ", level, " with ", instance.get_child_count(), " top-level parts.")
		instance.free()

	print("All ten prebuilt HQ tier scenes loaded successfully.")
	quit(0)
