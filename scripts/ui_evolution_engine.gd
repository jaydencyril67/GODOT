extends RefCounted
class_name UIEvolutionEngine

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://digitalworld_ui_evolution.json"

const PALETTES := [
	{"name": "Glacier", "background": "#101D2A", "surface": "#203344", "surface_alt": "#30495B", "accent": "#79D7D0", "accent_secondary": "#B5A8FF", "text": "#F4FAFC", "muted": "#A9BDC8"},
	{"name": "Solaris", "background": "#211A28", "surface": "#38283B", "surface_alt": "#51364A", "accent": "#FFB77A", "accent_secondary": "#F27F9B", "text": "#FFF7F0", "muted": "#D0B7B2"},
	{"name": "Verdant", "background": "#111F1C", "surface": "#20352E", "surface_alt": "#304B3F", "accent": "#92D6A1", "accent_secondary": "#D6C77D", "text": "#F3FAF3", "muted": "#AEC4B4"},
	{"name": "Ultraviolet", "background": "#17152B", "surface": "#282544", "surface_alt": "#39345C", "accent": "#B5A3FF", "accent_secondary": "#71D7F2", "text": "#F7F5FF", "muted": "#BDB8D7"},
	{"name": "Ember", "background": "#241916", "surface": "#3D2A25", "surface_alt": "#563A31", "accent": "#F2A36B", "accent_secondary": "#E8D18A", "text": "#FFF7F0", "muted": "#D0B7A8"},
	{"name": "Monochrome", "background": "#15191D", "surface": "#272D33", "surface_alt": "#394149", "accent": "#E3E8EB", "accent_secondary": "#9EC5D6", "text": "#F6F8F9", "muted": "#B4BEC4"},
	{"name": "Rose Quartz", "background": "#241923", "surface": "#3A2938", "surface_alt": "#53384D", "accent": "#F0A7CB", "accent_secondary": "#A9C8F4", "text": "#FFF6FB", "muted": "#D3B8C8"},
	{"name": "Cobalt", "background": "#101D32", "surface": "#1E3451", "surface_alt": "#2B496D", "accent": "#78B8FF", "accent_secondary": "#8CE0D0", "text": "#F4F8FF", "muted": "#AEC1D8"}
]

const WALLPAPER_STYLES := ["aurora", "orbital", "contour", "ribbon", "prism", "soft_gradient"]
const LAYOUT_ARCHETYPES := ["clock_focus", "dashboard", "editorial", "asymmetric", "minimal", "stacked"]
const WIDGET_TYPES := ["clock", "weather", "calendar", "music", "device", "focus", "battery"]

const APP_LIBRARY := [
	{"name": "Phone", "glyph": "P", "color": "#369B79"},
	{"name": "Messages", "glyph": "M", "color": "#398FCB"},
	{"name": "Camera", "glyph": "C", "color": "#687987"},
	{"name": "Gallery", "glyph": "G", "color": "#A77BC4"},
	{"name": "Browser", "glyph": "B", "color": "#319B9A"},
	{"name": "Music", "glyph": "♪", "color": "#C36E83"},
	{"name": "Calendar", "glyph": "18", "color": "#D4775D"},
	{"name": "Settings", "glyph": "S", "color": "#778590"},
	{"name": "Files", "glyph": "F", "color": "#A58B5A"},
	{"name": "Clock", "glyph": "◷", "color": "#6688B7"},
	{"name": "Maps", "glyph": "↗", "color": "#4F9D82"},
	{"name": "Notes", "glyph": "N", "color": "#B18E56"},
	{"name": "Contacts", "glyph": "U", "color": "#568FA8"},
	{"name": "Email", "glyph": "E", "color": "#B87962"},
	{"name": "Calculator", "glyph": "÷", "color": "#728C9E"},
	{"name": "Weather", "glyph": "☼", "color": "#C18C55"},
	{"name": "Store", "glyph": "◆", "color": "#5D9B83"},
	{"name": "Security", "glyph": "◇", "color": "#6488A8"},
	{"name": "Photos", "glyph": "✦", "color": "#B77A9B"},
	{"name": "Wallet", "glyph": "$", "color": "#A88762"},
	{"name": "Assistant", "glyph": "✧", "color": "#8D83BC"},
	{"name": "Tasks", "glyph": "✓", "color": "#638D9D"}
]

const DESIGN_PREFIXES := ["Aether", "Lumen", "Nova", "Sora", "Vanta", "Mira", "Orbit", "Solace", "Kairo", "Nexa", "Aural", "Cinder"]
const DESIGN_SUFFIXES := ["Flow", "One", "Arc", "Pulse", "Vista", "OS", "Motion", "Bloom", "Sense", "Wave", "Layer", "Space"]

static func generate_ui(seed_value: int = -1, device_specs: Dictionary = {}) -> Dictionary:
	var actual_seed := seed_value
	if actual_seed < 0:
		actual_seed = int(Time.get_ticks_usec()) ^ int(randi())
		if actual_seed < 0:
			actual_seed = -actual_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, actual_seed)

	var palette: Dictionary = PALETTES[rng.randi_range(0, PALETTES.size() - 1)].duplicate(true)
	var apps: Array = APP_LIBRARY.duplicate(true)
	_shuffle_array(apps, rng)

	var layout_style: String = LAYOUT_ARCHETYPES[rng.randi_range(0, LAYOUT_ARCHETYPES.size() - 1)]
	var widget_pool: Array = WIDGET_TYPES.duplicate()
	_shuffle_array(widget_pool, rng)
	var widget_count := rng.randi_range(1, 3)
	if layout_style == "minimal":
		widget_count = 1
	var widgets: Array[Dictionary] = []
	for index in range(widget_count):
		widgets.append({
			"type": str(widget_pool[index]),
			"emphasis": "hero" if index == 0 else ("compact" if index == 1 else "micro"),
			"variant": rng.randi_range(0, 2)
		})

	var dock := ["Phone", "Messages", "Browser", "Camera"]
	var home_apps: Array[Dictionary] = []
	var target_app_count := rng.randi_range(9, 12)
	for app_value in apps:
		var app: Dictionary = app_value
		if dock.has(str(app.get("name", ""))):
			continue
		home_apps.append(app.duplicate(true))
		if home_apps.size() >= target_app_count:
			break

	var style := {
		"palette": palette,
		"wallpaper_style": WALLPAPER_STYLES[rng.randi_range(0, WALLPAPER_STYLES.size() - 1)],
		"layout_archetype": layout_style,
		"grid_columns": [3, 4, 4, 5][rng.randi_range(0, 3)],
		"icon_shape": ["squircle", "rounded_square", "circle", "soft_square"][rng.randi_range(0, 3)],
		"icon_size": rng.randi_range(46, 58),
		"corner_radius": [14, 20, 26, 32][rng.randi_range(0, 3)],
		"spacing": rng.randi_range(10, 20),
		"surface_style": ["glass", "layered", "soft_solid"][rng.randi_range(0, 2)],
		"typography_scale": rng.randf_range(0.94, 1.08),
		"status_bar_style": ["quiet", "balanced", "detailed"][rng.randi_range(0, 2)],
		"navigation_style": ["gesture", "three_button"][rng.randi_range(0, 1)],
		"accent_treatment": ["subtle", "vivid", "tonal"][rng.randi_range(0, 2)]
	}

	var config := {
		"schema_version": SCHEMA_VERSION,
		"seed": actual_seed,
		"revision": 1,
		"name": "%s %s" % [DESIGN_PREFIXES[rng.randi_range(0, DESIGN_PREFIXES.size() - 1)], DESIGN_SUFFIXES[rng.randi_range(0, DESIGN_SUFFIXES.size() - 1)]],
		"created_at": int(Time.get_unix_time_from_system()),
		"style": style,
		"home": {
			"widgets": widgets,
			"apps": home_apps,
			"dock": dock,
			"show_search": rng.randf() > 0.32,
			"search_position": ["above_apps", "below_widgets"][rng.randi_range(0, 1)],
			"greeting_style": ["time_based", "short_greeting", "date_first"][rng.randi_range(0, 2)]
		},
		"system": {
			"time_format": ["24h", "12h"][rng.randi_range(0, 1)],
			"battery_percent": rng.randi_range(72, 100),
			"network_label": _network_label(device_specs),
			"show_battery_percent": rng.randf() > 0.55
		},
		"device": device_specs.duplicate(true)
	}
	return normalize_ui(config)


static func normalize_ui(config: Dictionary) -> Dictionary:
	var normalized := config.duplicate(true)
	var style: Dictionary = normalized.get("style", {}).duplicate(true)
	var palette: Dictionary = style.get("palette", PALETTES[0]).duplicate(true)
	for key in ["background", "surface", "surface_alt", "accent", "accent_secondary", "text", "muted"]:
		if not palette.has(key):
			palette[key] = PALETTES[0][key]
	style["palette"] = palette

	var layout_style := str(style.get("layout_archetype", "clock_focus"))
	if not LAYOUT_ARCHETYPES.has(layout_style):
		layout_style = "clock_focus"
	style["layout_archetype"] = layout_style
	var wallpaper_style := str(style.get("wallpaper_style", "aurora"))
	if not WALLPAPER_STYLES.has(wallpaper_style):
		wallpaper_style = "aurora"
	style["wallpaper_style"] = wallpaper_style
	style["grid_columns"] = clampi(int(style.get("grid_columns", 4)), 3, 5)
	style["icon_size"] = clampi(int(style.get("icon_size", 52)), 40, 64)
	style["corner_radius"] = clampi(int(style.get("corner_radius", 22)), 10, 36)
	style["spacing"] = clampi(int(style.get("spacing", 14)), 8, 24)
	style["typography_scale"] = clampf(float(style.get("typography_scale", 1.0)), 0.85, 1.2)
	normalized["style"] = style

	var home: Dictionary = normalized.get("home", {}).duplicate(true)
	var widgets: Array = home.get("widgets", [])
	if widgets.is_empty():
		widgets = [{"type": "clock", "emphasis": "hero", "variant": 0}]
	home["widgets"] = widgets
	var apps: Array = home.get("apps", [])
	if apps.size() < 6:
		apps = APP_LIBRARY.slice(4, 16)
	home["apps"] = apps
	var dock: Array = home.get("dock", ["Phone", "Messages", "Browser", "Camera"])
	if dock.size() != 4:
		dock = ["Phone", "Messages", "Browser", "Camera"]
	home["dock"] = dock
	normalized["home"] = home
	var system: Dictionary = normalized.get("system", {}).duplicate(true)
	system["battery_percent"] = clampi(int(system.get("battery_percent", 88)), 1, 100)
	normalized["system"] = system
	normalized["schema_version"] = SCHEMA_VERSION
	return normalized


static func validate_ui(config: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	if config.is_empty():
		issues.append("Generated UI blueprint is empty.")
		return issues
	if int(config.get("schema_version", 0)) != SCHEMA_VERSION:
		issues.append("Generated UI blueprint has an unsupported schema version.")
	var style: Dictionary = config.get("style", {})
	var palette: Dictionary = style.get("palette", {})
	for key in ["background", "surface", "surface_alt", "accent", "accent_secondary", "text", "muted"]:
		if not palette.has(key):
			issues.append("Generated palette is missing: " + key)
	var home: Dictionary = config.get("home", {})
	var widgets: Array = home.get("widgets", [])
	var apps: Array = home.get("apps", [])
	var dock: Array = home.get("dock", [])
	if widgets.is_empty():
		issues.append("At least one home-screen widget is required.")
	if apps.size() < 6:
		issues.append("The home screen needs at least six app icons.")
	if dock.size() != 4:
		issues.append("The dock must contain exactly four applications.")
	if not LAYOUT_ARCHETYPES.has(str(style.get("layout_archetype", ""))):
		issues.append("The home-screen composition is not recognized.")
	if not WALLPAPER_STYLES.has(str(style.get("wallpaper_style", ""))):
		issues.append("The wallpaper composition is not recognized.")
	return issues


static func save_ui(config: Dictionary, path: String = SAVE_PATH) -> bool:
	var normalized := normalize_ui(config)
	if not validate_ui(normalized).is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return true


static func load_ui(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var normalized := normalize_ui(parsed)
	if not validate_ui(normalized).is_empty():
		return {}
	return normalized


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


static func _network_label(device_specs: Dictionary) -> String:
	var network := str(device_specs.get("mobile_network", ""))
	for generation in ["6G", "5G", "4G", "3G", "2G", "1G"]:
		if network.contains(generation):
			return generation
	if network.contains("LTE"):
		return "LTE"
	if network.contains("Wi-Fi"):
		return "Wi-Fi"
	return "Offline"
