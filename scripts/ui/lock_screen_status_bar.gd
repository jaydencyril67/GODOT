extends Control

const AssetLibrary = preload("res://scripts/status_bar_asset_library.gd")
const SVG_ROOT := "res://assets/lock-screen/aosp/SVG"

@onready var row: HBoxContainer = $Row
@onready var leading: HBoxContainer = $Row/Leading
@onready var trailing: HBoxContainer = $Row/Trailing


func configure(design: Dictionary, palette: Dictionary) -> void:
	var style := AssetLibrary.get_style(str(design.get("status_style_id", "pixel_compact")))
	row.add_theme_constant_override("separation", int(style.get("gap", 3)))
	_set_normalized_rect(self, Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035)))
	var time_label := Label.new()
	time_label.name = "StatusBarClock"
	var time := Time.get_time_dict_from_system()
	time_label.text = "%02d:%02d" % [int(time["hour"]), int(time["minute"])]
	time_label.add_theme_font_size_override("font_size", int(style.get("time_size", 12)))
	time_label.add_theme_color_override("font_color", palette.get("muted", Color.WHITE))
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var time_side := str(style.get("time_side", "left"))
	var icon_group := trailing if time_side == "left" else leading
	var time_group := leading if time_side == "left" else trailing
	time_group.add_child(time_label)
	if bool(style.get("show_lock", false)):
		var lock_icon := TextureRect.new()
		lock_icon.name = "StatusBarLockIcon"
		lock_icon.texture = load(SVG_ROOT.path_join("ic_lock_locked.svg")) as Texture2D
		lock_icon.modulate = palette.get("muted", Color.WHITE)
		lock_icon.custom_minimum_size = Vector2(10, 13)
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_group.add_child(lock_icon)
	for icon_type in style.get("order", []):
		var icon_id := str(icon_type)
		if icon_id == "bluetooth" and not bool(style.get("show_bluetooth", false)):
			continue
		var texture_id := "bluetooth_connected" if icon_id == "bluetooth" else "%s_%d" % [icon_id, int(style.get(icon_id + "_level", 4))]
		var texture := AssetLibrary.get_icon_texture(texture_id)
		if texture == null:
			continue
		var icon := TextureRect.new()
		icon.name = "StatusBar" + icon_id.capitalize() + "Icon"
		icon.texture = texture
		icon.modulate = palette.get("muted", Color.WHITE)
		var icon_size := float(style.get("icon_size", 16))
		icon.custom_minimum_size = Vector2(icon_size * 0.75 if icon_id == "signal" else icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_group.add_child(icon)


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
