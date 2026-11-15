extends RefCounted
class_name ProceduralOSEngine

const SCHEMA_VERSION := 9

const COMPONENTS := [
	{"id": "home_screen", "title": "Home Screen"},
	{"id": "app_drawer", "title": "App Drawer"},
	{"id": "control_center", "title": "Control Center"},
	{"id": "notifications", "title": "Notification Panel"},
	{"id": "lock_screen", "title": "Lock Screen"},
	{"id": "wallpapers", "title": "Wallpapers"}
]

const PALETTES := [
	{"name": "Obsidian", "background": "#0B1017", "surface": "#19232E", "surface_alt": "#263544", "accent": "#76C8D4", "text": "#F4F7F8", "muted": "#A7B4BD"},
	{"name": "Midnight", "background": "#10101B", "surface": "#201F31", "surface_alt": "#302E46", "accent": "#A69AF2", "text": "#F6F4FF", "muted": "#B9B5CD"},
	{"name": "Graphite", "background": "#151719", "surface": "#24292D", "surface_alt": "#343B40", "accent": "#D6A56A", "text": "#F4F1EA", "muted": "#B8B3A9"},
	{"name": "Arctic", "background": "#102027", "surface": "#1C333D", "surface_alt": "#294751", "accent": "#83D8CF", "text": "#F0FBFA", "muted": "#B5CFCE"},
	{"name": "Plum", "background": "#1D1422", "surface": "#302238", "surface_alt": "#46314D", "accent": "#D99BCD", "text": "#FFF5FC", "muted": "#C9B7C7"},
	{"name": "Sandstone", "background": "#211D19", "surface": "#342D25", "surface_alt": "#4A4034", "accent": "#E0B27B", "text": "#FFF8EC", "muted": "#C9BDAA"}
]

const WALLPAPER_STYLES := ["lollipop", "aurora", "orbital", "dune", "prism", "midnight_flow"]
const ANDROID_PIE_PALETTE := {
	"name": "Pixel Pie",
	"background": "#15243A",
	"surface": "#F8F9FA",
	"surface_alt": "#E8EAED",
	"accent": "#4285F4",
	"text": "#202124",
	"muted": "#5F6368"
}

const HOME_LAYOUT_STYLES := ["android_pixel", "ios_home", "windows_tiles"]
const HOME_LAYOUT_FAMILY_LABELS := ["ANDROID", "iPHONE", "WINDOWS PHONE"]

const APP_DEFINITIONS := [
	{"name": "Phone", "glyph": "☎", "color": "#4B9B78"},
	{"name": "Messages", "glyph": "✉", "color": "#4C91C7"},
	{"name": "Camera", "glyph": "◉", "color": "#687987"},
	{"name": "Gallery", "glyph": "▧", "color": "#A77BC4"},
	{"name": "Browser", "glyph": "◎", "color": "#3E9E9B"},
	{"name": "Music", "glyph": "♫", "color": "#C36E83"},
	{"name": "Calendar", "glyph": "▦", "color": "#CE765D"},
	{"name": "Settings", "glyph": "⚙", "color": "#778590"},
	{"name": "Files", "glyph": "▤", "color": "#A58B5A"},
	{"name": "Clock", "glyph": "◷", "color": "#6688B7"},
	{"name": "Maps", "glyph": "⌖", "color": "#4F9D82"},
	{"name": "Notes", "glyph": "▤", "color": "#B18E56"},
	{"name": "Contacts", "glyph": "♙", "color": "#568FA8"},
	{"name": "Email", "glyph": "✉", "color": "#B87962"},
	{"name": "Calculator", "glyph": "＋", "color": "#728C9E"},
	{"name": "Weather", "glyph": "☀", "color": "#C18C55"},
	{"name": "Downloads", "glyph": "↓", "color": "#8B7CB5"},
	{"name": "Recorder", "glyph": "◉", "color": "#B66C76"},
	{"name": "Video", "glyph": "▶", "color": "#A36F9D"},
	{"name": "Store", "glyph": "▣", "color": "#5D9B83"},
	{"name": "Security", "glyph": "◇", "color": "#6488A8"},
	{"name": "Device Care", "glyph": "✚", "color": "#6E9D82"},
	{"name": "Drive", "glyph": "△", "color": "#B99A58"},
	{"name": "Photos", "glyph": "✿", "color": "#B77A9B"},
	{"name": "Podcasts", "glyph": "◖", "color": "#9277B5"},
	{"name": "Tasks", "glyph": "☑", "color": "#638D9D"},
	{"name": "Wallet", "glyph": "▱", "color": "#A88762"},
	{"name": "Compass", "glyph": "⊕", "color": "#648A9E"},
	{"name": "Assistant", "glyph": "✧", "color": "#8D83BC"},
	{"name": "Meet", "glyph": "◉", "color": "#5E9A8B"}
]

static func generate_os(seed_value: int = -1, generation: int = 2) -> Dictionary:
	var actual_seed := seed_value
	if actual_seed < 0:
		actual_seed = int(Time.get_unix_time_from_system()) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed
	var generation_number := clampi(generation, 1, 3)
	var palette: Dictionary = ANDROID_PIE_PALETTE.duplicate(true) if generation_number == 3 else PALETTES[rng.randi_range(0, PALETTES.size() - 1)].duplicate(true)
	var icon_shapes := ["square", "soft_square", "squircle"]
	var columns: int = [4, 4, 5][generation_number - 1]
	var wallpaper_id: String = "lollipop" if generation_number == 1 else "prism" if generation_number == 3 else WALLPAPER_STYLES[rng.randi_range(1, WALLPAPER_STYLES.size() - 1)]
	var config := {
		"schema_version": SCHEMA_VERSION,
		"seed": actual_seed,
		"generation": generation_number,
		"name": "System %06d" % (abs(actual_seed) % 1000000),
		"created_at": int(Time.get_unix_time_from_system()),
		"revision": 1,
		"style": {
			"identity": ["Classic", "Oreo", "Pie"][generation_number - 1],
			"generation": generation_number,
			"palette": palette,
			"icon_shape": icon_shapes[generation_number - 1],
			"icon_size": [48, 52, 56][generation_number - 1],
			"grid_columns": columns,
			"corner_radius": [0, 6, 18][generation_number - 1],
			"widget_count": [0, 2, 4][generation_number - 1],
			"spacing": [8, 10, 12][generation_number - 1],
			"wallpaper": wallpaper_id,
			"animation_speed": [0.20, 0.24, 0.28][generation_number - 1],
			"font_scale": [0.96, 1.0, 1.04][generation_number - 1]
		},
		"components": {}
	}
	for component in COMPONENTS:
		var component_id := str(component["id"])
		config["components"][component_id] = _generate_component(component_id, rng, config["style"])
	if generation_number == 3:
		config["components"]["app_drawer"] = {
			"layout": "alphabetical",
			"columns": 5,
			"search_position": "top",
			"scroll_direction": "vertical"
		}
		config["components"]["control_center"] = {
			"tile_shape": "circle",
			"tile_layout": "expanded",
			"brightness_style": "slider"
		}
		config["components"]["notifications"] = {
			"card_style": "rounded",
			"corner_radius": 16,
			"show_app_icon": true,
			"translucent": false
		}
		config["components"]["lock_screen"]["show_weather"] = true
		config["components"]["lock_screen"]["show_battery"] = true
	_sync_shared_settings(config)
	return config

static func regenerate_component(config: Dictionary, component_id: String, seed_value: int = -1) -> Dictionary:
	if component_id == "lock_screen":
		return regenerate_lock_screen_design(config, seed_value)
	var updated := normalize_os(config)
	if not updated.get("components", {}).has(component_id):
		return updated
	var actual_seed := seed_value
	if actual_seed < 0:
		actual_seed = int(Time.get_unix_time_from_system()) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed
	updated["components"][component_id] = _generate_component(component_id, rng, updated.get("style", {}))
	match component_id:
		"wallpapers":
			var wallpaper_id: String = WALLPAPER_STYLES[rng.randi_range(0, WALLPAPER_STYLES.size() - 1)]
			updated["style"]["wallpaper"] = wallpaper_id
		"themes_appearance":
			var new_palette: Dictionary = PALETTES[rng.randi_range(0, PALETTES.size() - 1)].duplicate(true)
			updated["components"]["themes_appearance"]["palette"] = new_palette
			updated["style"]["palette"] = new_palette.duplicate(true)
		"app_icons":
			var generation_number := int(updated.get("generation", 2))
			var shape_options := ["soft_square", "rounded"] if generation_number == 1 else ["rounded", "squircle", "soft_square"]
			var new_shape: String = shape_options[rng.randi_range(0, shape_options.size() - 1)]
			updated["components"]["app_icons"]["shape"] = new_shape
			updated["style"]["icon_shape"] = new_shape
	updated["last_component_seed"] = actual_seed
	updated["revision"] = int(updated.get("revision", 0)) + 1
	_sync_shared_settings(updated)
	return updated

static func normalize_os(config: Dictionary) -> Dictionary:
	var normalized := config.duplicate(true)
	var is_legacy_schema := int(normalized.get("schema_version", 1)) < SCHEMA_VERSION
	var generation_number := clampi(int(normalized.get("generation", 2)), 1, 3)
	var style: Dictionary = normalized.get("style", {}).duplicate(true)
	var legacy_components: Dictionary = normalized.get("components", {})
	var legacy_icons: Dictionary = legacy_components.get("app_icons", {})
	var legacy_theme: Dictionary = legacy_components.get("themes_appearance", {})
	if is_legacy_schema and legacy_icons.has("shape"):
		style["icon_shape"] = legacy_icons["shape"]
	if is_legacy_schema and legacy_icons.has("size"):
		style["icon_size"] = legacy_icons["size"]
	if is_legacy_schema and legacy_theme.has("palette"):
		style["palette"] = legacy_theme["palette"].duplicate(true)
	var palette: Dictionary = style.get("palette", PALETTES[0]).duplicate(true)
	if palette.is_empty():
		palette = PALETTES[0].duplicate(true)
	var wallpaper_id := str(style.get("wallpaper", "aurora"))
	if not WALLPAPER_STYLES.has(wallpaper_id):
		wallpaper_id = "aurora"
	style["generation"] = generation_number
	style["identity"] = ["Classic", "Oreo", "Pie"][generation_number - 1]
	style["palette"] = palette
	style["wallpaper"] = wallpaper_id
	style["grid_columns"] = clampi(int(style.get("grid_columns", 4)), 3, 6)
	style["icon_size"] = clampi(int(style.get("icon_size", 52)), 40, 64)
	var icon_shape := str(style.get("icon_shape", "rounded"))
	if not ["square", "soft_square", "rounded", "squircle"].has(icon_shape):
		icon_shape = "rounded"
	style["icon_shape"] = icon_shape
	style["corner_radius"] = [0, 6, 18][generation_number - 1]
	style["widget_count"] = [0, 2, 4][generation_number - 1]
	style["spacing"] = clampi(int(style.get("spacing", 10)), 4, 20)
	style["animation_speed"] = clampf(float(style.get("animation_speed", 0.24)), 0.08, 0.6)
	style["font_scale"] = clampf(float(style.get("font_scale", 1.0)), 0.85, 1.2)
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["generation"] = generation_number
	normalized["style"] = style
	var components: Dictionary = normalized.get("components", {}).duplicate(true)
	for obsolete_id in ["app_icons", "themes_appearance", "animations_transitions", "navigation_gestures", "recent_apps", "system_ui"]:
		components.erase(obsolete_id)
	var fallback_rng := RandomNumberGenerator.new()
	fallback_rng.seed = int(normalized.get("seed", 1))
	for component in COMPONENTS:
		var component_id := str(component["id"])
		if not components.has(component_id) or not components[component_id] is Dictionary:
			components[component_id] = _generate_component(component_id, fallback_rng, style)

	var lock_defaults := _generate_lock_screen_component(fallback_rng, {})
	var lock_data: Dictionary = components.get("lock_screen", {}).duplicate(true)
	for lock_key in lock_defaults:
		if not lock_data.has(lock_key):
			lock_data[lock_key] = lock_defaults[lock_key]
	var configured_home_data: Dictionary = components.get("home_screen", {})
	var is_oreo_android := generation_number == 2 and str(configured_home_data.get("layout_style", "android_pixel")) == "android_pixel"
	var is_pie_android := generation_number == 3 and str(configured_home_data.get("layout_style", "android_pixel")) == "android_pixel"
	# Keep the two generations historically distinct. Lollipop retains its
	# approved four switches; Oreo uses the Pixel 2 Assistant/notification set.
	var obsolete_lock_keys := [
		"show_audio_player", "show_fingerprint", "fingerprint_sensor_available",
		"show_now_playing", "design_family", "layout_template", "clock_alignment", "clock_size",
		"clock_weight", "clock_treatment", "date_treatment",
		"notification_treatment", "audio_treatment", "shortcut_treatment",
		"fingerprint_treatment", "show_unlock_hint", "unlock_treatment", "wallpaper"
	]
	for obsolete_key in obsolete_lock_keys:
		lock_data.erase(obsolete_key)
	if is_oreo_android or is_pie_android:
		lock_data.erase("show_flashlight_shortcut")
	else:
		for oreo_key in ["show_assistant_shortcut", "show_notifications", "show_weather", "show_battery"]:
			lock_data.erase(oreo_key)
	if is_pie_android:
		lock_data["show_weather"] = bool(lock_data.get("show_weather", true))
		lock_data["show_battery"] = bool(lock_data.get("show_battery", true))
	else:
		lock_data.erase("show_weather")
		lock_data.erase("show_battery")
	components["lock_screen"] = lock_data

	var home_data: Dictionary = components.get("home_screen", {})
	var home_layout := str(home_data.get("layout_style", ""))
	if not HOME_LAYOUT_STYLES.has(home_layout):
		home_layout = "android_pixel"
	home_data["layout_style"] = home_layout
	home_data["columns"] = int(style.get("grid_columns", 4))
	home_data["widget_count"] = int(style.get("widget_count", 0))
	if is_pie_android:
		var drawer_data: Dictionary = components.get("app_drawer", {})
		drawer_data["layout"] = str(drawer_data.get("layout", "alphabetical"))
		drawer_data["columns"] = int(drawer_data.get("columns", 5))
		drawer_data["search_position"] = str(drawer_data.get("search_position", "top"))
		drawer_data["scroll_direction"] = str(drawer_data.get("scroll_direction", "vertical"))
		components["app_drawer"] = drawer_data
		var control_data: Dictionary = components.get("control_center", {})
		control_data["tile_shape"] = str(control_data.get("tile_shape", "circle"))
		control_data["tile_layout"] = str(control_data.get("tile_layout", "expanded"))
		control_data["brightness_style"] = str(control_data.get("brightness_style", "slider"))
		components["control_center"] = control_data
		var notification_data: Dictionary = components.get("notifications", {})
		notification_data["card_style"] = str(notification_data.get("card_style", "rounded"))
		notification_data["corner_radius"] = int(notification_data.get("corner_radius", 16))
		notification_data["show_app_icon"] = bool(notification_data.get("show_app_icon", true))
		notification_data["translucent"] = bool(notification_data.get("translucent", false))
		components["notifications"] = notification_data
	components["home_screen"] = home_data
	normalized["components"] = components
	_sync_shared_settings(normalized)
	return normalized

static func validate_os(config: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	if config.is_empty():
		issues.append("Configuration is empty.")
		return issues
	var style: Dictionary = config.get("style", {})
	var palette: Dictionary = style.get("palette", {})
	if palette.is_empty():
		issues.append("Shared palette is missing.")
	for key in ["background", "surface", "accent", "text", "muted"]:
		if not palette.has(key):
			issues.append("Palette colour is missing: " + key)
	var components: Dictionary = config.get("components", {})
	for component in COMPONENTS:
		var component_id := str(component["id"])
		if not components.has(component_id):
			issues.append("Missing component: " + component_id)
	if not WALLPAPER_STYLES.has(str(style.get("wallpaper", ""))):
		issues.append("Wallpaper style is invalid.")
	var lock_screen: Dictionary = config.get("components", {}).get("lock_screen", {})
	var home_data: Dictionary = components.get("home_screen", {})
	var is_oreo_android := int(config.get("generation", 1)) == 2 and str(home_data.get("layout_style", "android_pixel")) == "android_pixel"
	var is_pie_android := int(config.get("generation", 1)) == 3 and str(home_data.get("layout_style", "android_pixel")) == "android_pixel"
	var required_lock_keys := ["show_time", "show_date", "show_camera_shortcut", "show_assistant_shortcut", "show_notifications", "show_weather", "show_battery"] if is_pie_android else ["show_time", "show_date", "show_camera_shortcut", "show_assistant_shortcut", "show_notifications"] if is_oreo_android else ["show_time", "show_date", "show_camera_shortcut", "show_flashlight_shortcut"]
	for lock_key in required_lock_keys:
		if not lock_screen.has(lock_key):
			issues.append("Lock-screen setting is missing: " + lock_key)
	var columns := int(style.get("grid_columns", 0))
	if columns < 3 or columns > 6:
		issues.append("Home screen grid columns are outside the supported range.")
	return issues

static func _sync_shared_settings(config: Dictionary) -> void:
	var style: Dictionary = config.get("style", {})
	var components: Dictionary = config.get("components", {})
	var wallpaper_id := str(style.get("wallpaper", "aurora"))
	if components.has("home_screen"):
		components["home_screen"]["widget_count"] = int(style.get("widget_count", 0))
		components["home_screen"]["show_clock_widget"] = int(style.get("widget_count", 0)) > 0
		components["home_screen"]["columns"] = int(style.get("grid_columns", 4))
		var home_layout := str(components["home_screen"].get("layout_style", "ios_grid"))
		if not HOME_LAYOUT_STYLES.has(home_layout):
			home_layout = "android_pixel"
		components["home_screen"]["layout_style"] = home_layout
	if components.has("wallpapers"):
		components["wallpapers"]["style"] = wallpaper_id
		components["wallpapers"]["id"] = wallpaper_id
	if components.has("home_screen"):
		components["home_screen"]["wallpaper"] = wallpaper_id
	if components.has("lock_screen"):
		components["lock_screen"]["wallpaper"] = wallpaper_id
	
	config["components"] = components


static func regenerate_lock_screen_design(config: Dictionary, _seed_value: int = -1) -> Dictionary:
	# Kept as a compatibility entry point for older callers; Lollipop has no
	# procedural lock-screen design generator.
	return normalize_os(config)


static func _generate_lock_screen_component(_rng: RandomNumberGenerator, previous: Dictionary) -> Dictionary:
	return {
		"show_time": bool(previous.get("show_time", true)),
		"show_date": bool(previous.get("show_date", true)),
		"show_camera_shortcut": bool(previous.get("show_camera_shortcut", true)),
		"show_flashlight_shortcut": bool(previous.get("show_flashlight_shortcut", true)),
		"show_assistant_shortcut": bool(previous.get("show_assistant_shortcut", true)),
		"show_notifications": bool(previous.get("show_notifications", true))
	}


static func _generate_component(component_id: String, rng: RandomNumberGenerator, style: Dictionary) -> Dictionary:
	match component_id:
		"home_screen":
			return {
				"layout_style": "android_pixel",
				"columns": int(style.get("grid_columns", 4)),
				"dock_count": 4,
				"show_search": true,
				"widget_count": int(style.get("widget_count", 2)),
				"show_clock_widget": int(style.get("widget_count", 2)) > 0,
				"wallpaper": style.get("wallpaper", "aurora")
			}
		"lock_screen":
			var lock_screen_data := _generate_lock_screen_component(rng, {})
			lock_screen_data["wallpaper"] = style.get("wallpaper", "aurora")
			return lock_screen_data
		"app_icons":
			return {
				"shape": str(style.get("icon_shape", "rounded")),
				"size": rng.randi_range(48, 56),
				"label_visibility": true,
				"tint_variation": rng.randi_range(0, 3)
			}
		"themes_appearance":
			return {
				"palette": style.get("palette", PALETTES[0]).duplicate(true),
				"surface_style": ["solid", "translucent", "layered"][rng.randi_range(0, 2)],
				"contrast": ["balanced", "high"][rng.randi_range(0, 1)]
			}
		"wallpapers":
			return {
				"id": style.get("wallpaper", "aurora"),
				"style": style.get("wallpaper", "aurora"),
				"treatment": ["natural", "soft_glow", "deep_contrast"][rng.randi_range(0, 2)],
				"blur": rng.randf_range(0.0, 0.12)
			}
		"animations_transitions":
			return {
				"style": ["fade", "slide", "scale", "spring"][rng.randi_range(0, 3)],
				"duration": rng.randf_range(0.18, 0.32),
				"reduced_motion": false
			}
		"control_center":
			return {
				"tile_shape": ["rounded", "pill"][rng.randi_range(0, 1)],
				"tile_layout": ["compact", "expanded"][rng.randi_range(0, 1)],
				"brightness_style": ["bar", "slider"][rng.randi_range(0, 1)]
			}
		"notifications":
			return {
				"card_style": ["compact", "grouped", "expanded"][rng.randi_range(0, 2)],
				"corner_radius": int(style.get("corner_radius", 16)),
				"show_app_icon": true,
				"translucent": rng.randf() > 0.25
			}
		"navigation_gestures":
			return {
				"mode": ["gesture", "three_button"][rng.randi_range(0, 1)],
				"indicator_style": ["line", "pill"][rng.randi_range(0, 1)],
				"edge_back": true
			}
		"app_drawer":
			return {
				"layout": ["alphabetical", "categories", "frequent_first"][rng.randi_range(0, 2)],
				"columns": int(style.get("grid_columns", 4)),
				"search_position": ["top", "bottom"][rng.randi_range(0, 1)],
				"scroll_direction": ["vertical", "horizontal"][rng.randi_range(0, 1)]
			}
		"recent_apps":
			return {
				"layout": ["stack", "carousel", "grid"][rng.randi_range(0, 2)],
				"show_clear_all": true,
				"card_radius": clampi(int(style.get("corner_radius", 16)), 8, 24)
			}
		"system_ui":
			return {
				"status_style": ["minimal", "detailed"][rng.randi_range(0, 1)],
				"battery_style": ["icon", "percentage", "pill"][rng.randi_range(0, 2)],
				"clock_alignment": ["left", "right"][rng.randi_range(0, 1)]
			}
	return {}

static func save_os(config: Dictionary, path: String) -> bool:
	var normalized := normalize_os(config)
	if not validate_os(normalized).is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return true

static func load_os(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	return normalize_os(parsed)
