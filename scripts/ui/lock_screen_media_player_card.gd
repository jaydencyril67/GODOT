extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

@onready var surface: TextureRect = $Surface
@onready var service_icon: TextureRect = $Margin/Content/TopRow/ServiceIcon
@onready var service_label: Label = $Margin/Content/TopRow/TrackInfo/ServiceLabel
@onready var title_label: Label = $Margin/Content/TopRow/TrackInfo/Title
@onready var artist_label: Label = $Margin/Content/TopRow/TrackInfo/Artist
@onready var progress: ProgressBar = $Margin/Content/Progress
@onready var previous_icon: TextureRect = $Margin/Content/Controls/Previous
@onready var play_pause_icon: TextureRect = $Margin/Content/Controls/PlayPause
@onready var next_icon: TextureRect = $Margin/Content/Controls/Next


func configure(media: Dictionary, palette: Dictionary) -> void:
	surface.texture = AssetLibrary.get_surface_texture("media")
	var glass: Color = palette.get("glass", Color("#20242B"))
	surface.modulate = Color(glass.r, glass.g, glass.b, 0.86)

	var icon_path := str(media.get("icon", ""))
	service_icon.texture = load(icon_path) as Texture2D if not icon_path.is_empty() else null
	service_label.text = str(media.get("service", "MUSIC")) + "  ·  NOW PLAYING"
	title_label.text = str(media.get("title", "Now Playing"))
	artist_label.text = str(media.get("artist", "Digital World Radio"))

	var accent: Color = palette.get("accent", Color.WHITE)
	var primary: Color = palette.get("text", Color.WHITE)
	var muted: Color = palette.get("muted", Color("#C7CDD5"))
	service_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_color_override("font_color", primary)
	artist_label.add_theme_color_override("font_color", muted)

	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = float(media.get("progress", 55))
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(muted.r, muted.g, muted.b, 0.20)
	track.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", track)

	previous_icon.texture = AssetLibrary.get_icon_texture("media_previous")
	play_pause_icon.texture = AssetLibrary.get_icon_texture("media_pause" if bool(media.get("playing", true)) else "media_play")
	next_icon.texture = AssetLibrary.get_icon_texture("media_next")
	previous_icon.modulate = muted
	play_pause_icon.modulate = primary
	next_icon.modulate = muted
