extends Control

const WidgetAssetLibrary = preload("res://scripts/ui/xmorph_widget_asset_library.gd")
const LockScreenAssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

var _widgets := WidgetAssetLibrary.new()


func configure(media: Dictionary, palette: Dictionary = {}) -> void:
	_clear_children()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var widget := _widgets.get_widget("44_media_player")
	if widget.is_empty():
		return
	var background_layer := _widgets.get_layer(widget, "bg")
	var artwork_layer := _widgets.get_layer(widget, "art")
	var title_layer := _widgets.get_layer(widget, "title")
	var artist_layer := _widgets.get_layer(widget, "artist")
	var previous_layer := _widgets.get_layer(widget, "prev")
	var play_layer := _widgets.get_layer(widget, "play")
	var play_background_layer := _widgets.get_layer(widget, "pbg")
	var next_layer := _widgets.get_layer(widget, "next")
	var screen_size := get_viewport_rect().size
	var accent: Color = palette.get("accent", Color("#A9C9FF"))
	var text_color: Color = palette.get("text", Color.WHITE)
	var muted_color: Color = palette.get("muted", Color("#C3CFE3"))

	var surface := TextureRect.new()
	surface.name = "GeneratedMediaPlayerSurface"
	surface.texture = LockScreenAssetLibrary.get_surface_texture("media")
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode = TextureRect.STRETCH_SCALE
	surface.modulate = Color(1.0, 1.0, 1.0, 0.72)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)

	var panel := Panel.new()
	panel.name = "XMorphMediaPlayerCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = _widgets.get_asset_color(str(background_layer.get("color", "#E61C1C1E")), Color(0.11, 0.11, 0.12, 0.90))
	panel_style.set_corner_radius_all(clampi(roundi(minf(size.y, 80.0) * float(background_layer.get("radius", 0.3))), 14, 26))
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "XMorphMediaPlayerContent"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var art := TextureRect.new()
	art.name = "MediaAlbumArtwork"
	var album_path := str(media.get("album_art", ""))
	if album_path.is_empty() or not ResourceLoader.exists(album_path):
		album_path = str(media.get("icon", ""))
	var album_texture: Texture2D = null
	if not album_path.is_empty():
		album_texture = load(album_path) as Texture2D
	art.texture = album_texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(
		clampf(screen_size.x * float(artwork_layer.get("aspect", 1.0)) * float(_find_layout_size(widget, "art", 0.1188)), 52.0, 110.0),
		clampf(screen_size.x * float(_find_layout_size(widget, "art", 0.1188)), 52.0, 110.0)
	)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	var info := VBoxContainer.new()
	info.name = "MediaPlayerInformation"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var service_row := HBoxContainer.new()
	service_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	service_row.add_theme_constant_override("separation", 6)
	service_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(service_row)

	var service_icon_path := str(media.get("icon", ""))
	if not service_icon_path.is_empty():
		var service_icon := TextureRect.new()
		service_icon.name = "MediaServiceIcon"
		service_icon.texture = load(service_icon_path) as Texture2D
		service_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		service_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		service_icon.custom_minimum_size = Vector2(16, 16)
		service_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		service_row.add_child(service_icon)

	var service_label := Label.new()
	service_label.name = "MediaPlayerService"
	service_label.text = str(media.get("service", "MUSIC")) + "  ·  NOW PLAYING"
	service_label.add_theme_font_size_override("font_size", 10)
	service_label.add_theme_color_override("font_color", accent)
	service_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	service_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	service_row.add_child(service_label)

	var title := Label.new()
	title.name = "MediaPlayerTitle"
	title.text = str(media.get("title", "Unknown track"))
	title.add_theme_font_size_override("font_size", clampi(roundi(screen_size.x * float(_find_layout_size(widget, "title", 0.0288))), 14, 25))
	title.add_theme_color_override("font_color", text_color)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_font := _widgets.get_font(str(title_layer.get("font", "")))
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	info.add_child(title)

	var artist := Label.new()
	artist.name = "MediaPlayerArtist"
	artist.text = str(media.get("artist", ""))
	artist.add_theme_font_size_override("font_size", clampi(roundi(screen_size.x * float(_find_layout_size(widget, "artist", 0.0216))), 11, 19))
	artist.add_theme_color_override("font_color", muted_color)
	artist.clip_text = true
	artist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	artist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var artist_font := _widgets.get_font(str(artist_layer.get("font", "")))
	if artist_font != null:
		artist.add_theme_font_override("font", artist_font)
	info.add_child(artist)

	var controls := HBoxContainer.new()
	controls.name = "GeneratedMediaControls"
	controls.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls.add_theme_constant_override("separation", 18)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(controls)
	controls.add_child(_make_control_icon("Previous", "media_previous", previous_layer, screen_size, muted_color))
	var is_playing := bool(media.get("playing", true))
	var play_surface := Control.new()
	play_surface.name = "MediaPlaySurface"
	play_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var play_surface_size := clampf(screen_size.x * float(_find_layout_size(widget, "pbg", 0.0648)), 38.0, 56.0)
	play_surface.custom_minimum_size = Vector2(play_surface_size, play_surface_size)
	var play_panel := Panel.new()
	play_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var play_style := StyleBoxFlat.new()
	var play_color := _widgets.get_asset_color(str(play_background_layer.get("color", "#33FFFFFF")), Color(1, 1, 1, 0.20))
	play_style.bg_color = Color(accent.r, accent.g, accent.b, play_color.a)
	play_style.set_corner_radius_all(100)
	play_panel.add_theme_stylebox_override("panel", play_style)
	play_surface.add_child(play_panel)
	var play_icon := _make_control_icon("PlayPause", "media_pause" if is_playing else "media_play", play_layer, screen_size, text_color, accent)
	var play_icon_size := clampf(screen_size.x * float(play_layer.get("size", 0.0324)), 20.0, 36.0)
	play_icon.anchor_left = 0.5
	play_icon.anchor_right = 0.5
	play_icon.anchor_top = 0.5
	play_icon.anchor_bottom = 0.5
	play_icon.offset_left = -play_icon_size * 0.5
	play_icon.offset_right = play_icon_size * 0.5
	play_icon.offset_top = -play_icon_size * 0.5
	play_icon.offset_bottom = play_icon_size * 0.5
	play_surface.add_child(play_icon)
	controls.add_child(play_surface)
	controls.add_child(_make_control_icon("Next", "media_next", next_layer, screen_size, muted_color))


func _make_control_icon(node_name: String, icon_name: String, layer: Dictionary, screen_size: Vector2, tint: Color, accent: Color = Color.TRANSPARENT) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = LockScreenAssetLibrary.get_icon_texture(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_scale := float(layer.get("size", 0.04))
	var icon_size := clampf(screen_size.x * icon_scale, 22.0, 42.0)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.modulate = accent if node_name == "PlayPause" and accent.a > 0.0 else tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _find_layout_size(widget: Dictionary, layer_id: String, fallback: float) -> float:
	var large: Dictionary = widget.get("large", {})
	for key in ["row", "column", "stack"]:
		if large.has(key):
			var found := _find_layer_size(large[key], layer_id)
			if found > 0.0:
				return found
	return fallback


func _find_layer_size(node: Dictionary, layer_id: String) -> float:
	if str(node.get("layer", "")) == layer_id:
		return float(node.get("size", 0.0))
	for key in ["row", "column", "stack"]:
		if node.has(key):
			for child_value in node[key].get("children", []):
				var value := _find_layer_size(child_value, layer_id)
				if value > 0.0:
					return value
	return 0.0


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
