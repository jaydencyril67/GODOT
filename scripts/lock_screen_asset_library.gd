extends RefCounted

const ICON_ATLAS_PATH := "res://assets/system-ui/godot/notifications/notification_icon_atlas.svg"
const SOURCE_ICON_ATLAS_PATH := "res://assets/system-ui/godot/notifications/notification_source_icon_atlas.svg"
const NOTIFICATION_SURFACE_PATH := "res://assets/system-ui/godot/notifications/notification_card_surface.svg"
const MEDIA_SURFACE_PATH := "res://assets/system-ui/godot/notifications/media_player_surface.svg"
const SHORTCUT_SURFACE_PATH := "res://assets/system-ui/godot/notifications/shortcut_surface.svg"

const SOURCE_ICON_REGIONS := {
	"category_chat": Rect2(0, 0, 24, 24),
	"category_email": Rect2(32, 0, 24, 24),
	"category_calendar": Rect2(64, 0, 24, 24),
	"category_security": Rect2(96, 0, 24, 24),
	"category_school": Rect2(128, 0, 24, 24),
	"category_work": Rect2(160, 0, 24, 24),
	"category_shopping": Rect2(192, 0, 24, 24),
	"category_news": Rect2(224, 0, 24, 24),
	"action_more": Rect2(0, 32, 24, 24),
	"action_expand": Rect2(32, 32, 24, 24),
	"action_collapse": Rect2(64, 32, 24, 24),
	"action_close": Rect2(96, 32, 24, 24),
	"action_refresh": Rect2(128, 32, 24, 24)
}

const MEDIA_ICON_REGIONS := {
	"media_previous": Rect2(0, 64, 24, 24),
	"media_pause": Rect2(32, 64, 24, 24),
	"media_play": Rect2(64, 64, 24, 24),
	"media_next": Rect2(96, 64, 24, 24),
	"camera": Rect2(128, 64, 24, 24),
	"lock": Rect2(160, 64, 24, 24)
}

static func get_icon_texture(icon_id: String) -> Texture2D:
	if SOURCE_ICON_REGIONS.has(icon_id):
		return _get_atlas_region(SOURCE_ICON_ATLAS_PATH, SOURCE_ICON_REGIONS[icon_id])
	if MEDIA_ICON_REGIONS.has(icon_id):
		return _get_atlas_region(ICON_ATLAS_PATH, MEDIA_ICON_REGIONS[icon_id])
	return null

static func _get_atlas_region(path: String, region: Rect2) -> Texture2D:
	var atlas := load(path) as Texture2D
	if atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture

static func get_surface_texture(surface_id: String) -> Texture2D:
	var path := ""
	match surface_id:
		"notification":
			path = NOTIFICATION_SURFACE_PATH
		"media":
			path = MEDIA_SURFACE_PATH
		"shortcut":
			path = SHORTCUT_SURFACE_PATH
	if path.is_empty():
		return null
	return load(path) as Texture2D

static func get_notification_category(app_name: String) -> String:
	var normalized := app_name.to_lower()
	if "gmail" in normalized or "email" in normalized:
		return "category_email"
	if "task" in normalized or "keep" in normalized:
		return "category_calendar"
	if "classroom" in normalized or "school" in normalized:
		return "category_school"
	if "security" in normalized or "auth" in normalized:
		return "category_security"
	if "work" in normalized:
		return "category_work"
	if "shop" in normalized:
		return "category_shopping"
	if "news" in normalized:
		return "category_news"
	return "category_chat"

static func get_analog_clock_path(asset_index: int) -> String:
	return "res://assets/lock-screen/clocks/analog/analog-%02d.png" % clampi(asset_index, 1, get_analog_clock_count())

static func get_analog_clock_count() -> int:
	return 41
