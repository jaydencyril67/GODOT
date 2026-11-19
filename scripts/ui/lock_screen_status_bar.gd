extends Control

const AssetLibrary = preload("res://scripts/status_bar_asset_library.gd")
const SVG_ROOT := "res://assets/lock-screen/aosp/SVG"

var _variants: Dictionary = {}
var _selected_style_id := "pixel_compact"
var _palette: Dictionary = {}
var _last_minute := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func configure(design: Dictionary, palette: Dictionary) -> void:
	_palette = palette.duplicate(true)
	_set_normalized_rect(self, Rect2(Vector2(0.055, 0.024), Vector2(0.89, 0.035)))
	var legacy_row := get_node_or_null("Row") as Control
	if legacy_row != null:
		legacy_row.visible = false
	_build_all_style_variants()
	set_style(str(design.get("status_style_id", "pixel_compact")))
	_refresh_time_labels()


func _process(_delta: float) -> void:
	var now := Time.get_time_dict_from_system()
	var minute := int(now.get("minute", -1))
	if minute == _last_minute:
		return
	_last_minute = minute
	_refresh_time_labels()


func _build_all_style_variants() -> void:
	if not _variants.is_empty():
		return
	for style in AssetLibrary.get_styles():
		var style_id := str(style.get("id", ""))
		var variant := Control.new()
		variant.name = "StatusBarVariant_" + style_id
		variant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		variant.visible = false
		_set_normalized_rect(variant, Rect2(0.0, 0.0, 1.0, 1.0))
		add_child(variant)

		var row := HBoxContainer.new()
		row.name = "StatusBarRow_" + style_id
		row.add_theme_constant_override("separation", int(style.get("gap", 3)))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_full_rect(row)
		variant.add_child(row)

		var leading := HBoxContainer.new()
		leading.name = "StatusBarLeading_" + style_id
		leading.add_theme_constant_override("separation", int(style.get("gap", 3)))
		leading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(leading)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)

		var trailing := HBoxContainer.new()
		trailing.name = "StatusBarTrailing_" + style_id
		trailing.add_theme_constant_override("separation", int(style.get("gap", 3)))
		trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(trailing)

		var tint: Color = _palette.get("muted", Color.WHITE)
		var time_side := str(style.get("time_side", "left"))
		var icon_group := trailing if time_side == "left" else leading
		var time_group := leading if time_side == "left" else trailing

		var time_label := Label.new()
		time_label.name = "StatusBarClock"
		time_label.text = _current_time_text()
		time_label.add_theme_font_size_override("font_size", int(style.get("time_size", 12)))
		time_label.add_theme_color_override("font_color", tint)
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_group.add_child(time_label)

		if bool(style.get("show_lock", false)):
			var lock_icon := TextureRect.new()
			lock_icon.name = "StatusBarLockIcon"
			lock_icon.texture = load(SVG_ROOT.path_join("ic_lock_locked.svg")) as Texture2D
			lock_icon.modulate = tint
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
			icon.modulate = tint
			var icon_size := float(style.get("icon_size", 16))
			icon.custom_minimum_size = Vector2(icon_size * 0.75 if icon_id == "signal" else icon_size, icon_size)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_group.add_child(icon)

		_variants[style_id] = variant


func set_style(style_id: String) -> bool:
	if not AssetLibrary.has_style(style_id):
		return false
	if _variants.is_empty():
		return false
	_selected_style_id = style_id
	for variant_id in _variants.keys():
		var variant := _variants[variant_id] as Control
		if is_instance_valid(variant):
			variant.visible = str(variant_id) == style_id
	return true


func get_style_id() -> String:
	return _selected_style_id


func get_style_variant_count() -> int:
	return _variants.size()


func _refresh_time_labels() -> void:
	var text_value := _current_time_text()
	for variant in _variants.values():
		var clock_label := (variant as Control).find_child("StatusBarClock", true, false) as Label
		if clock_label != null:
			clock_label.text = text_value
	_last_minute = int(Time.get_time_dict_from_system().get("minute", -1))


func _current_time_text() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(time.get("hour", 0)), int(time.get("minute", 0))]


func _set_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
