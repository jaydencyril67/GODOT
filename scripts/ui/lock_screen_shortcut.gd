extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")
const SVG_ROOT := "res://assets/lock-screen/aosp/SVG"

@onready var surface: TextureRect = $ShortcutSurface
@onready var camera_glyph: TextureRect = $ShortcutCenter/GeneratedCameraGlyph
@onready var flashlight_glyph: TextureRect = $ShortcutCenter/FlashlightGlyph


func configure(kind: String, palette: Dictionary) -> void:
	surface.texture = AssetLibrary.get_surface_texture("shortcut")
	var glass: Color = palette.get("glass", Color("#20242B"))
	surface.modulate = Color(glass.r, glass.g, glass.b, 0.58)
	var tint: Color = palette.get("text", Color.WHITE)
	camera_glyph.visible = kind == "camera"
	flashlight_glyph.visible = kind == "flashlight"
	if kind == "camera":
		camera_glyph.texture = AssetLibrary.get_icon_texture("camera")
		camera_glyph.modulate = tint
	else:
		flashlight_glyph.texture = load(SVG_ROOT.path_join("ic_flashlight_off.svg")) as Texture2D
		flashlight_glyph.modulate = tint
