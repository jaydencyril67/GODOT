extends RefCounted

const ICON_ATLAS_PATH := "res://assets/system-ui/godot/notifications/notification_icon_atlas.svg"
const NOTIFICATION_SURFACE_PATH := "res://assets/system-ui/godot/notifications/notification_card_surface.svg"
const MEDIA_SURFACE_PATH := "res://assets/system-ui/godot/notifications/media_player_surface.svg"
const SHORTCUT_SURFACE_PATH := "res://assets/system-ui/godot/notifications/shortcut_surface.svg"

const ICON_REGIONS := {
	"category_chat": Rect2(0, 0, 24, 24),
	"category_email": Rect2(32, 0, 24, 24),
	"category_calendar": Rect2(64, 0, 24, 24),
	"category_security": Rect2(96, 0, 24, 24),
	"category_school": Rect2(128, 0, 24, 24),
	"category_work": Rect2(160, 0, 24, 24),
	"category_shopping": Rect2(192, 0, 24, 24),
	"category_news": Rect2(224, 0, 24, 24),
	"action_expand": Rect2(0, 32, 24, 24),
	"action_close": Rect2(32, 32, 24, 24),
	"action_more": Rect2(64, 32, 24, 24),
	"action_collapse": Rect2(96, 32, 24, 24),
	"action_refresh": Rect2(128, 32, 24, 24),
	"media_previous": Rect2(0, 64, 24, 24),
	"media_pause": Rect2(32, 64, 24, 24),
	"media_play": Rect2(64, 64, 24, 24),
	"media_next": Rect2(96, 64, 24, 24),
	"camera": Rect2(128, 64, 24, 24),
	"lock": Rect2(160, 64, 24, 24)
}

static func get_icon_texture(icon_id: String) -> Texture2D:
	var region: Rect2 = ICON_REGIONS.get(icon_id, Rect2())
	if region.size == Vector2.ZERO:
		return null
	var texture_atlas := load(ICON_ATLAS_PATH) as Texture2D
	if texture_atlas == null:
		return null
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture_atlas
	atlas_texture.region = region
	return atlas_texture

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

static func get_analog_face_path(style_index: int) -> String:
	var index := clampi(style_index, 1, 8)
	return "res://assets/widgets/clock/faces/512/face_%d_512.png" % index

static func get_analog_hand_path(style_index: int, hand_name: String) -> String:
	var index := clampi(style_index, 1, 8)
	if hand_name not in ["hr", "min", "sec"]:
		return ""
	return "res://assets/widgets/clock/hands/%d/%s.png" % [index, hand_name]
