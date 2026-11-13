extends RefCounted
class_name ProceduralOSEngine

const SCHEMA_VERSION := 3

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

const WALLPAPER_STYLES := ["aurora", "orbital", "dune", "prism", "midnight_flow"]

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
	{"name": "Notes", "glyph": "▤", "color": "#B18E56"}
]

static func generate_os(seed_value: int = -1, generation: int = 2) -> Dictionary:
	var actual_seed := seed_value
	if actual_seed < 0:
		actual_seed = int(Time.get_unix_time_from_system()) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed
	var generation_number := clampi(generation, 1, 3)
	var palette: Dictionary = PALETTES[rng.randi_range(0, PALETTES.size() - 1)].duplicate(true)
	var icon_shapes := ["soft_square", "rounded", "squircle"]
	var columns: int = [4, 4, 5][generation_number - 1]
	var wallpaper_id: String = WALLPAPER_STYLES[rng.randi_range(0, WALLPAPER_STYLES.size() - 1)]
	var config := {
		"schema_version": SCHEMA_VERSION,
		"seed": actual_seed,
		"generation": generation_number,
		"name": "System %06d" % (abs(actual_seed) % 1000000),
		"created_at": int(Time.get_unix_time_from_system()),
		"revision": 1,
		"style": {
			"identity": ["Foundation", "Modern", "Flagship"][generation_number - 1],
			"generation": generation_number,
			"palette": palette,
			"icon_shape": icon_shapes[generation_number - 1],
			"icon_size": [48, 52, 56][generation_number - 1],
			"grid_columns": columns,
			"corner_radius": [10, 16, 21][generation_number - 1],
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
	_sync_shared_settings(config)
	return config

static func regenerate_component(config: Dictionary, component_id: String, seed_value: int = -1) -> Dictionary:
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
	style["palette"] = palette
	style["wallpaper"] = wallpaper_id
	style["grid_columns"] = clampi(int(style.get("grid_columns", 4)), 3, 6)
	style["icon_shape"] = str(style.get("icon_shape", "rounded"))
	style["icon_size"] = clampi(int(style.get("icon_size", 52)), 40, 64)
	if not ["square", "soft_square", "rounded", "squircle"].has(style["icon_shape"]):
		style["icon_shape"] = "rounded"
	style["corner_radius"] = clampi(int(style.get("corner_radius", 16)), 0, 28)
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
	var columns := int(style.get("grid_columns", 0))
	if columns < 3 or columns > 6:
		issues.append("Home screen grid columns are outside the supported range.")
	return issues

static func _sync_shared_settings(config: Dictionary) -> void:
	var style: Dictionary = config.get("style", {})
	var components: Dictionary = config.get("components", {})
	var wallpaper_id := str(style.get("wallpaper", "aurora"))
	if components.has("wallpapers"):
		components["wallpapers"]["style"] = wallpaper_id
		components["wallpapers"]["id"] = wallpaper_id
	if components.has("home_screen"):
		components["home_screen"]["wallpaper"] = wallpaper_id
	if components.has("lock_screen"):
		components["lock_screen"]["wallpaper"] = wallpaper_id
	
	config["components"] = components

static func _generate_component(component_id: String, rng: RandomNumberGenerator, style: Dictionary) -> Dictionary:
	match component_id:
		"home_screen":
			return {
				"layout": ["balanced_grid", "widget_grid", "minimal_grid"][rng.randi_range(0, 2)],
				"columns": int(style.get("grid_columns", 4)),
				"dock_count": 4,
				"show_search": rng.randf() > 0.35,
				"show_clock_widget": true,
				"wallpaper": style.get("wallpaper", "aurora")
			}
		"lock_screen":
			return {
				"clock_style": ["bold", "compact", "stacked"][rng.randi_range(0, 2)],
				"show_notifications": true,
				"shortcut_style": ["circular", "minimal"][rng.randi_range(0, 1)],
				"wallpaper": style.get("wallpaper", "aurora")
			}
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
				"search_position": ["top", "bottom"][rng.randi_range(0, 1)]
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
