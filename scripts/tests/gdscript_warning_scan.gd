extends SceneTree

var scanned_script_count: int = 0
var reloaded_script_count: int = 0
var failed_script_count: int = 0


func _initialize() -> void:
	call_deferred("_scan_project")


func _scan_project() -> void:
	print("GDSCRIPT_WARNING_SCAN: START")
	_scan_directory("res://")

	print("GDSCRIPT_WARNING_SCAN: Scanned %d GDScript files." % scanned_script_count)
	print("GDSCRIPT_WARNING_SCAN: Reloaded %d GDScript files." % reloaded_script_count)
	print("GDSCRIPT_WARNING_SCAN: Failed to load or reload %d scripts." % failed_script_count)

	if failed_script_count == 0:
		print("GDSCRIPT_WARNING_SCAN: PASS")
		quit(0)
	else:
		print("GDSCRIPT_WARNING_SCAN: FAIL")
		quit(1)


func _scan_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		push_error("Could not open project directory: %s" % directory_path)
		failed_script_count += 1
		return

	directory.list_dir_begin()
	var entry := directory.get_next()

	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := directory_path.path_join(entry)

			if directory.current_is_dir():
				if entry != ".git" and entry != ".godot":
					_scan_directory(entry_path)
			elif entry.ends_with(".gd"):
				_load_script(entry_path)

		entry = directory.get_next()

	directory.list_dir_end()


func _load_script(script_path: String) -> void:
	scanned_script_count += 1
	var loaded_resource: Resource = ResourceLoader.load(script_path, "GDScript")

	if loaded_resource == null:
		push_error("Failed to load GDScript: %s" % script_path)
		failed_script_count += 1
		return

	if not (loaded_resource is GDScript):
		push_error("Resource is not a GDScript: %s" % script_path)
		failed_script_count += 1
		return

	var loaded_script := loaded_resource as GDScript
	if loaded_script == get_script():
		print("GDSCRIPT_WARNING_SCAN: Skipping active scanner script: %s" % script_path)
		return

	var reload_error: Error = loaded_script.reload()
	if reload_error != OK:
		push_error("Failed to reload GDScript: %s (error %d)" % [script_path, reload_error])
		failed_script_count += 1
		return

	reloaded_script_count += 1
