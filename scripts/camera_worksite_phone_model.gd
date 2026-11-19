extends "res://scripts/os_worksite_phone_model.gd"

# Camera Creation starts from the same finished handset geometry used by the
# OS worksite, but deliberately leaves both faces free of camera hardware.
func build_camera_less(screen_texture: Texture2D) -> void:
	for child in get_children():
		child.free()

	_build_chassis()
	_build_display(screen_texture)
	_build_side_controls()
	_build_bottom_hardware()
