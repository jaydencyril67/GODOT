extends Control

const AssetLibrary = preload("res://scripts/lock_screen_asset_library.gd")

@onready var surface: TextureRect = $GeneratedNotificationSurface
@onready var app_icon: TextureRect = $Margin/Row/AppIcon
@onready var app_label: Label = $Margin/Row/Content/Header/AppLabel
@onready var category_icon: TextureRect = $Margin/Row/Content/Header/NotificationCategoryIcon
@onready var more_icon: TextureRect = $Margin/Row/Content/Header/MoreIcon
@onready var title_label: Label = $Margin/Row/Content/Title
@onready var body_label: Label = $Margin/Row/Content/Body


func configure(notification_data: Dictionary, palette: Dictionary) -> void:
	surface.texture = AssetLibrary.get_surface_texture("notification")
	var glass: Color = palette.get("glass", Color("#20242B"))
	surface.modulate = Color(glass.r, glass.g, glass.b, 0.82)

	var icon_path := str(notification_data.get("icon", ""))
	app_icon.texture = load(icon_path) as Texture2D if not icon_path.is_empty() else null

	var app_name := str(notification_data.get("app", "APP"))
	app_label.text = app_name + "  ·  " + str(notification_data.get("timestamp", "NOW"))
	title_label.text = str(notification_data.get("title", "Notification"))
	body_label.text = str(notification_data.get("body", ""))

	var accent: Color = palette.get("accent", Color.WHITE)
	var primary: Color = palette.get("text", Color.WHITE)
	var muted: Color = palette.get("muted", Color("#C7CDD5"))
	app_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_color_override("font_color", primary)
	body_label.add_theme_color_override("font_color", muted)

	category_icon.texture = AssetLibrary.get_icon_texture(AssetLibrary.get_notification_category(app_name))
	category_icon.modulate = muted
	more_icon.texture = AssetLibrary.get_icon_texture("action_more")
	more_icon.modulate = muted
