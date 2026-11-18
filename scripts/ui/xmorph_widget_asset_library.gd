extends RefCounted

const WIDGET_ROOT := "res://research/XMorphClock/Widgets/Definitions"
const FONT_ROOT := "res://research/XMorphClock/Fonts/Files"

var _widgets: Dictionary = {}
var _fonts: Dictionary = {}


func get_widget(name: String) -> Dictionary:
	var normalized := name.trim_suffix(".json")
	if _widgets.has(normalized):
		return (_widgets[normalized] as Dictionary).duplicate(true)
	var path := WIDGET_ROOT.path_join(normalized + ".json")
	if not FileAccess.file_exists(path):
		push_warning("XMorph widget definition is missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("XMorph widget JSON is invalid: " + path)
		return {}
	var widget: Dictionary = parsed
	_widgets[normalized] = widget
	return widget.duplicate(true)


func get_layer(widget: Dictionary, layer_id: String) -> Dictionary:
	for layer_value in widget.get("layers", []):
		var layer: Dictionary = layer_value
		if str(layer.get("id", "")) == layer_id:
			return layer.duplicate(true)
	return {}


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


func get_asset_color(value: String, fallback: Color = Color.WHITE) -> Color:
	var raw := value.strip_edges()
	if not raw.begins_with("#"):
		return fallback
	var hex := raw.trim_prefix("#")
	if hex.length() == 8:
		var alpha := float(hex.substr(0, 2).hex_to_int()) / 255.0
		var red := float(hex.substr(2, 2).hex_to_int()) / 255.0
		var green := float(hex.substr(4, 2).hex_to_int()) / 255.0
		var blue := float(hex.substr(6, 2).hex_to_int()) / 255.0
		return Color(red, green, blue, alpha)
	if hex.length() == 6:
		return Color(
			float(hex.substr(0, 2).hex_to_int()) / 255.0,
			float(hex.substr(2, 2).hex_to_int()) / 255.0,
			float(hex.substr(4, 2).hex_to_int()) / 255.0,
			1.0
		)
	return fallback
