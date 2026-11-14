@tool
extends EditorPlugin

var _android_export_plugin: AndroidOSUIExportPlugin


func _enter_tree() -> void:
	_android_export_plugin = AndroidOSUIExportPlugin.new()
	add_export_plugin(_android_export_plugin)


func _exit_tree() -> void:
	if _android_export_plugin != null:
		remove_export_plugin(_android_export_plugin)
		_android_export_plugin = null


class AndroidOSUIExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["res://addons/digitalworld_os_ui/bin/debug/plugin-debug.aar"])
		return PackedStringArray(["res://addons/digitalworld_os_ui/bin/release/plugin-release.aar"])

	func _get_name() -> String:
		return "DigitalWorldOSUI"
