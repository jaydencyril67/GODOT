extends RefCounted

const DEFINITION_ROOT := "res://research/XMorphClock/Clock-Faces/Definitions"
const FONT_ROOT := "res://research/XMorphClock/Fonts/Files"
const FACE_FILES: Array[String] = [
	"01_swash.json", "02_bubble.json", "03_sticker.json", "04_puff.json", "05_flourish.json",
	"11_doodle.json", "12_marker.json", "13_graffiti.json", "14_hello.json", "15_journal.json",
	"20_space.json", "21_garden.json", "22_kitty.json", "23_party.json", "24_daydream.json",
	"37_gilded.json", "38_vogue.json", "39_lumiere.json", "40_editorial.json", "41_bodoni.json",
	"45_stacked.json", "46_inline.json", "47_crystal.json", "48_ember.json", "49_thread.json", "55_quad.json",
	"61_staircase.json", "62_layer_cake.json", "63_tilt_duo.json", "64_column.json", "65_outline_mix.json", "67_retro.json",
	"70_terminal.json", "71_matrix.json", "72_dots.json", "73_mono.json", "74_readout.json",
	"75_hud.json", "76_lcd.json", "77_pixel.json", "78_tall.json"
]

var _faces: Array[Dictionary] = []
var _fonts: Dictionary = {}
var _loaded := false


func get_faces() -> Array[Dictionary]:
	_load_faces()
	return _faces.duplicate(true)


func get_face_count() -> int:
	_load_faces()
	return _faces.size()


func get_face(index: int) -> Dictionary:
	_load_faces()
	if _faces.is_empty():
		return {}
	return _faces[clampi(index - 1, 0, _faces.size() - 1)].duplicate(true)


func get_face_name(index: int) -> String:
	return str(get_face(index).get("name", "Digital Clock"))


func get_face_category(index: int) -> String:
	return str(get_face(index).get("category", "digital"))


func get_font(font_reference: String) -> Font:
	var alias := font_reference.strip_edges().trim_prefix("res:").get_slice("?", 0).to_lower()
	if alias.is_empty():
		return null
	if _fonts.has(alias):
		return _fonts[alias] as Font
	var filename := "morph_roboto_flex.ttf" if alias == "roboto_flex" else "font_%s.ttf" % alias
	var path := FONT_ROOT.path_join(filename)
	if not FileAccess.file_exists(path):
		return null
	var font := load(path) as Font
	if font != null:
		_fonts[alias] = font
	return font


func _load_faces() -> void:
	if _loaded:
		return
	_loaded = true
	for filename in FACE_FILES:
		var path := DEFINITION_ROOT.path_join(filename)
		if not FileAccess.file_exists(path):
			push_warning("XMorph clock face is missing: " + path)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("XMorph clock face JSON is invalid: " + path)
			continue
		var face: Dictionary = parsed
		var has_digital_time := false
		for layer_value in face.get("layers", []):
			var layer: Dictionary = layer_value
			if str(layer.get("type", "")) in [
				"HOURS", "MINUTES", "COLON", "TIME",
				"HOUR_TENS", "HOUR_ONES", "MINUTE_TENS", "MINUTE_ONES"
			]:
				has_digital_time = true
				break
		if not has_digital_time:
			push_warning("XMorph face has no digital time layer: " + path)
			continue
		face["_asset_path"] = path
		face["_asset_file"] = filename
		_faces.append(face)
	if _faces.size() != 41:
		push_warning("Expected 41 curated XMorph digital faces, loaded %d." % _faces.size())
