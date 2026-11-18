extends RefCounted

const MANIFEST_PATH := "res://assets/app_icons/papirus/manifest.json"


static func get_apps() -> Array[Dictionary]:
	var apps: Array[Dictionary] = []
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Papirus app icon manifest is missing: " + MANIFEST_PATH)
		return apps
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("Papirus app icon manifest could not be opened.")
		return apps
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Papirus app icon manifest is invalid.")
		return apps
	for entry in (parsed as Dictionary).get("apps", []):
		if not entry is Dictionary:
			continue
		var app: Dictionary = entry.duplicate(true)
		var path := str(app.get("path", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		app["icon_path"] = path
		apps.append(app)
	return apps
