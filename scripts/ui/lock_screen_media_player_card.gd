extends Control


func configure(media: Dictionary, _palette: Dictionary = {}) -> void:
	_clear_children()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	var artwork_path := str(media.get("artwork", ""))
	if artwork_path.is_empty() or not ResourceLoader.exists(artwork_path):
		push_warning("Lock-screen music-player artwork is missing: " + artwork_path)
		return

	var artwork_texture := load(artwork_path) as Texture2D
	if artwork_texture == null:
		push_warning("Lock-screen music-player artwork could not be loaded: " + artwork_path)
		return

	var artwork := TextureRect.new()
	artwork.name = "GeneratedMediaPlayerArtwork"
	artwork.texture = artwork_texture
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(artwork)


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
