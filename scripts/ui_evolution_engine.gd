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
const WALLPAPER_ASSETS := [
	"res://assets/wallpapers/wallpaper-01.jpg",
	"res://assets/wallpapers/wallpaper-02.jpg",
	"res://assets/wallpapers/wallpaper-03.jpg",
	"res://assets/wallpapers/wallpaper-04.jpg",
	"res://assets/wallpapers/wallpaper-05.jpg",
	"res://assets/wallpapers/wallpaper-06.jpg",
	"res://assets/wallpapers/wallpaper-07.jpg",
	"res://assets/wallpapers/wallpaper-08.jpg",
	"res://assets/wallpapers/wallpaper-09.jpg",
	"res://assets/wallpapers/wallpaper-10.jpg",
	"res://assets/wallpapers/wallpaper-11.jpg",
	"res://assets/wallpapers/wallpaper-12.jpg",
	"res://assets/wallpapers/wallpaper-13.jpg",
	"res://assets/wallpapers/wallpaper-14.jpg",
	"res://assets/wallpapers/wallpaper-15.jpg",
	"res://assets/wallpapers/wallpaper-16.jpg",
	"res://assets/wallpapers/wallpaper-17.jpg",
	"res://assets/wallpapers/wallpaper-18.jpg",
	"res://assets/wallpapers/wallpaper-19.jpg",
	"res://assets/wallpapers/wallpaper-20.jpg",
	"res://assets/wallpapers/wallpaper-21.jpg",
	"res://assets/wallpapers/wallpaper-22.jpg",
	"res://assets/wallpapers/wallpaper-23.jpg",
	"res://assets/wallpapers/wallpaper-24.jpg",
	"res://assets/wallpapers/wallpaper-25.jpg",
	"res://assets/wallpapers/wallpaper-26.jpg",
	"res://assets/wallpapers/wallpaper-27.jpg",
	"res://assets/wallpapers/wallpaper-28.jpg",
	"res://assets/wallpapers/wallpaper-29.jpg",
	"res://assets/wallpapers/wallpaper-30.jpg",
	"res://assets/wallpapers/wallpaper-31.jpg",
	"res://assets/wallpapers/wallpaper-32.jpg",
	"res://assets/wallpapers/wallpaper-33.jpg",
	"res://assets/wallpapers/wallpaper-34.jpg",
	"res://assets/wallpapers/wallpaper-35.jpg",
	"res://assets/wallpapers/wallpaper-36.jpg",
	"res://assets/wallpapers/wallpaper-37.jpg",
	"res://assets/wallpapers/wallpaper-38.jpg",
	"res://assets/wallpapers/wallpaper-39.jpg",
	"res://assets/wallpapers/wallpaper-40.jpg",
	"res://assets/wallpapers/wallpaper-41.jpg",
	"res://assets/wallpapers/wallpaper-42.jpg",
	"res://assets/wallpapers/wallpaper-43.jpg",
	"res://assets/wallpapers/wallpaper-44.jpg",
	"res://assets/wallpapers/wallpaper-45.jpg",
	"res://assets/wallpapers/wallpaper-46.jpg",
	"res://assets/wallpapers/wallpaper-47.jpg",
	"res://assets/wallpapers/wallpaper-48.jpg",
	"res://assets/wallpapers/wallpaper-49.jpg",
	"res://assets/wallpapers/wallpaper-50.jpg",
	"res://assets/wallpapers/wallpaper-51.jpg",
	"res://assets/wallpapers/wallpaper-52.jpg",
	"res://assets/wallpapers/wallpaper-53.jpg",
	"res://assets/wallpapers/wallpaper-54.jpg",
	"res://assets/wallpapers/wallpaper-55.jpg",
	"res://assets/wallpapers/wallpaper-56.jpg",
	"res://assets/wallpapers/wallpaper-57.jpg",
	"res://assets/wallpapers/wallpaper-58.jpg",
	"res://assets/wallpapers/wallpaper-59.jpg",
	"res://assets/wallpapers/wallpaper-60.jpg"
]
const WIDGET_TYPES := ["clock", "weather", "calendar", "music", "device", "focus", "battery"]

const AppIconLibrary = preload("res://scripts/app_icon_library.gd")

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
	var apps: Array = AppIconLibrary.get_apps()
	_shuffle_array(apps, rng)

	var widget_pool: Array = WIDGET_TYPES.duplicate()
	_shuffle_array(widget_pool, rng)
	var widget_count := rng.randi_range(1, 3)
	var widgets: Array[Dictionary] = []
	for index in range(widget_count):
		widgets.append({
			"type": str(widget_pool[index]),
			"emphasis": "hero" if index == 0 else ("compact" if index == 1 else "micro"),
			"variant": rng.randi_range(0, 2)
		})

	var widget_layout := _create_widget_layout(widgets, rng)
	var dock := ["WhatsApp", "Gmail", "Spotify", "YouTube"]
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
		"wallpaper_path": WALLPAPER_ASSETS[rng.randi_range(0, WALLPAPER_ASSETS.size() - 1)],
		"composition_density": ["airy", "balanced", "compact"][rng.randi_range(0, 2)],
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
			"composition": widget_layout,
			"header_text": ["YOUR SPACE", "A GOOD DAY TO BEGIN", "TODAY", "AT A GLANCE", "WELCOME BACK"][rng.randi_range(0, 4)],
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

	var composition_density := str(style.get("composition_density", "balanced"))
	if not ["airy", "balanced", "compact"].has(composition_density):
		composition_density = "balanced"
	style["composition_density"] = composition_density
	var wallpaper_style := str(style.get("wallpaper_style", "aurora"))
	if not WALLPAPER_STYLES.has(wallpaper_style):
		wallpaper_style = "aurora"
	style["wallpaper_style"] = wallpaper_style
	var wallpaper_path := str(style.get("wallpaper_path", WALLPAPER_ASSETS[0]))
	if not WALLPAPER_ASSETS.has(wallpaper_path):
		wallpaper_path = WALLPAPER_ASSETS[0]
	style["wallpaper_path"] = wallpaper_path
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
	var composition: Dictionary = home.get("composition", {}).duplicate(true)
	var placements: Array = composition.get("widget_placements", [])
	if placements.size() != widgets.size():
		var layout_rng := RandomNumberGenerator.new()
		layout_rng.seed = maxi(1, int(normalized.get("seed", 1)))
		composition = _create_widget_layout(widgets, layout_rng)
	home["composition"] = composition
	var apps: Array = home.get("apps", [])
	if apps.size() < 6:
		apps = AppIconLibrary.get_apps().slice(4, 16)
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
	var composition: Dictionary = home.get("composition", {})
	var placements: Array = composition.get("widget_placements", [])
	if placements.size() != widgets.size():
		issues.append("The generated composition does not place every widget.")
	for index in range(placements.size()):
		var placement_value: Variant = placements[index]
		if not placement_value is Dictionary:
			issues.append("The generated widget placement is not a structured region.")
			continue
		var placement: Dictionary = placement_value
		var rect_values: Array = placement.get("rect", [])
		if rect_values.size() != 4:
			issues.append("A generated widget region has invalid geometry.")
			continue
		var rect := Rect2(float(rect_values[0]), float(rect_values[1]), float(rect_values[2]), float(rect_values[3]))
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.end.x > 1.0 or rect.end.y > 0.78:
			issues.append("A generated widget region exceeds the phone's safe screen area.")
		for previous_index in range(index):
			var previous: Dictionary = placements[previous_index]
			var previous_rect_values: Array = previous.get("rect", [])
			if previous_rect_values.size() == 4:
				var previous_rect := Rect2(float(previous_rect_values[0]), float(previous_rect_values[1]), float(previous_rect_values[2]), float(previous_rect_values[3]))
				if rect.intersects(previous_rect):
					issues.append("Generated widget regions overlap.")
	if not WALLPAPER_STYLES.has(str(style.get("wallpaper_style", ""))):
		issues.append("The wallpaper composition is not recognized.")
	if not WALLPAPER_ASSETS.has(str(style.get("wallpaper_path", ""))):
		issues.append("The selected wallpaper asset is not recognized.")
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


static func _create_widget_layout(widgets: Array, rng: RandomNumberGenerator) -> Dictionary:
	var density := rng.randf_range(0.215, 0.285) if widgets.size() <= 2 else rng.randf_range(0.285, 0.36)
	if widgets.size() == 1:
		density = rng.randf_range(0.145, 0.205)
	var top := rng.randf_range(0.168, 0.198)
	var region := Rect2(0.055, top, rng.randf_range(0.86, 0.90), density)
	var placements: Array[Dictionary] = []
	_split_widget_layout(region, widgets, 0, widgets.size(), placements, rng)
	var apps_top := clampf(region.end.y + rng.randf_range(0.10, 0.14), 0.50, 0.72)
	return {
		"widget_placements": placements,
		"apps_top": apps_top,
		"region_bounds": [region.position.x, region.position.y, region.size.x, region.size.y]
	}


static func _split_widget_layout(rect: Rect2, widgets: Array, start_index: int, count: int, placements: Array[Dictionary], rng: RandomNumberGenerator, previous_axis: int = -1) -> void:
	if count <= 1:
		var widget: Dictionary = widgets[start_index]
		placements.append({
			"type": str(widget.get("type", "clock")),
			"variant": int(widget.get("variant", 0)),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		})
		return

	var divide_width := (rng.randf() > 0.48) if previous_axis < 0 else previous_axis == 1
	var current_axis := 0 if divide_width else 1
	var first_count := rng.randi_range(1, count - 1)
	var ratio := rng.randf_range(0.36, 0.64)
	var gap := rng.randf_range(0.012, 0.022)
	var first_rect := rect
	var second_rect := rect
	if divide_width:
		var first_width := (rect.size.x - gap) * ratio
		first_rect.size.x = first_width
		second_rect.position.x = rect.position.x + first_width + gap
		second_rect.size.x = rect.size.x - first_width - gap
	else:
		var first_height := (rect.size.y - gap) * ratio
		first_rect.size.y = first_height
		second_rect.position.y = rect.position.y + first_height + gap
		second_rect.size.y = rect.size.y - first_height - gap
	_split_widget_layout(first_rect, widgets, start_index, first_count, placements, rng, current_axis)
	_split_widget_layout(second_rect, widgets, start_index + first_count, count - first_count, placements, rng, current_axis)


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
