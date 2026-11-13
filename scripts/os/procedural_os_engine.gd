extends RefCounted
class_name ProceduralOSEngine

const COMPONENTS := [
	{"id": "home_screen", "title": "Home Screen"},
	{"id": "lock_screen", "title": "Lock Screen"},
	{"id": "app_icons", "title": "App Icons"},
	{"id": "themes_appearance", "title": "Themes & Appearance"},
	{"id": "wallpapers", "title": "Wallpapers"},
	{"id": "animations_transitions", "title": "Animations & Transitions"},
	{"id": "control_center", "title": "Control Center"},
	{"id": "notifications", "title": "Notification Appearance"},
	{"id": "navigation_gestures", "title": "Navigation & Gestures"},
	{"id": "app_drawer", "title": "App Drawer"},
	{"id": "recent_apps", "title": "Recent Apps"},
	{"id": "system_ui", "title": "System UI Elements"}
]

const PALETTES := [
	{"name": "Obsidian", "background": "#101318", "surface": "#202833", "accent": "#72B7C8", "text": "#F2F4F5", "muted": "#A6B0B9"},
	{"name": "Midnight", "background": "#10101A", "surface": "#25243A", "accent": "#9A8BEA", "text": "#F5F2FF", "muted": "#B8B3CD"},
	{"name": "Graphite", "background": "#17191B", "surface": "#303438", "accent": "#D0A36C", "text": "#F2EEE8", "muted": "#B8B0A5"},
	{"name": "Arctic", "background": "#17232A", "surface": "#2B3E49", "accent": "#82D4D0", "text": "#F1FAFA", "muted": "#B4C9CC"},
	{"name": "Plum", "background": "#211722", "surface": "#3A293C", "accent": "#D49BCB", "text": "#FFF3FC", "muted": "#C7B4C5"}
]

const WALLPAPERS := [
	"res://assets/textures/os/android_1_0_default_wallpaper.jpg"
]

const APP_DEFINITIONS := [
	{"name": "Phone", "glyph": "☎"},
	{"name": "Messages", "glyph": "✉"},
	{"name": "Camera", "glyph": "◉"},
	{"name": "Gallery", "glyph": "▧"},
	{"name": "Browser", "glyph": "◎"},
	{"name": "Music", "glyph": "♫"},
	{"name": "Calendar", "glyph": "▦"},
	{"name": "Settings", "glyph": "⚙"},
	{"name": "Files", "glyph": "▤"},
	{"name": "Clock", "glyph": "◷"},
	{"name": "Maps", "glyph": "⌖"},
	{"name": "Notes", "glyph": "▧"}
]

static func generate_os(seed_value: int = -1, generation: int = 1) -> Dictionary:
	var actual_seed := seed_value
	if actual_seed < 0:
		actual_seed = int(Time.get_unix_time_from_system()) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed
	var generation_number := clampi(generation, 1, 3)
	var palette: Dictionary = PALETTES[rng.randi_range(0, PALETTES.size() - 1)].duplicate(true)
	var icon_shape := "square" if generation_number == 1 else ("soft_square" if generation_number == 2 else "rounded")
	var columns := 3 if generation_number == 1 else rng.randi_range(4, 5)
	var wallpaper_index := rng.randi_range(0, WALLPAPERS.size() - 1)
	var config := {
		"schema_version": 1,
		"seed": actual_seed,
		"generation": generation_number,
		"name": "System %06d" % (abs(actual_seed) % 1000000),
		"created_at": int(Time.get_unix_time_from_system()),
		"style": {
			"identity": ["Classic", "Modern", "Advanced"][generation_number - 1],
			"generation": generation_number,
			"palette": palette,
			"icon_shape": icon_shape,
			"grid_columns": columns,
			"corner_radius": [0, 7, 13][generation_number - 1],
			"spacing": [7, 9, 11][generation_number - 1],
			"wallpaper": WALLPAPERS[wallpaper_index],
			"animation_speed": [0.18, 0.24, 0.30][generation_number - 1]
		},
		"components": {}
	}
	for component in COMPONENTS:
		config["components"][component["id"]] = _generate_component(component["id"], rng, config["style"])
	config["components"]["wallpapers"]["path"] = config["style"]["wallpaper"]
	config["style"]["icon_shape"] = config["components"]["app_icons"]["shape"]
	return config

static func regenerate_component(config: Dictionary, component_id: String, seed_value: int = -1) -> Dictionary:
	var updated := config.duplicate(true)
	if not updated.has("components") or not updated["components"].has(component_id):
		return updated
	var actual_seed := seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system()) ^ randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed
	updated["components"][component_id] = _generate_component(component_id, rng, updated.get("style", {}))
	match component_id:
		"wallpapers":
			var wallpaper_path: String = WALLPAPERS[rng.randi_range(0, WALLPAPERS.size() - 1)]
			updated["components"]["wallpapers"]["path"] = wallpaper_path
			updated["style"]["wallpaper"] = wallpaper_path
			updated["components"]["home_screen"]["wallpaper"] = wallpaper_path
			updated["components"]["lock_screen"]["wallpaper"] = wallpaper_path
		"themes_appearance":
			var new_palette: Dictionary = PALETTES[rng.randi_range(0, PALETTES.size() - 1)].duplicate(true)
			updated["components"]["themes_appearance"]["palette"] = new_palette
			updated["style"]["palette"] = new_palette
		"app_icons":
			var generation_number := int(updated.get("generation", 1))
			var shape_options := ["square"] if generation_number == 1 else (["soft_square", "rounded"] if generation_number == 2 else ["rounded", "soft_square"])
			var new_shape: String = shape_options[rng.randi_range(0, shape_options.size() - 1)]
			updated["components"]["app_icons"]["shape"] = new_shape
			updated["style"]["icon_shape"] = new_shape
	updated["last_component_seed"] = actual_seed
	updated["revision"] = int(updated.get("revision", 0)) + 1
	return updated

static func _generate_component(component_id: String, rng: RandomNumberGenerator, style: Dictionary) -> Dictionary:
	var palette: Dictionary = style.get("palette", PALETTES[0])
	match component_id:
		"home_screen":
			return {"layout": ["classic_grid", "widget_grid", "minimal_grid"][rng.randi_range(0, 2)], "columns": int(style.get("grid_columns", 4)), "dock_count": rng.randi_range(3, 5), "show_search": rng.randf() > 0.45, "show_clock_widget": rng.randf() > 0.35, "wallpaper": style.get("wallpaper", WALLPAPERS[0])}
		"lock_screen":
			return {"clock_style": ["bold", "compact", "stacked"][rng.randi_range(0, 2)], "show_notifications": rng.randf() > 0.25, "shortcut_style": ["circular", "minimal"][rng.randi_range(0, 1)], "wallpaper": style.get("wallpaper", WALLPAPERS[0])}
		"app_icons":
			var generation_number := int(style.get("generation", 1))
			var shape_options := ["square"] if generation_number == 1 else (["soft_square", "rounded"] if generation_number == 2 else ["rounded", "soft_square"])
			return {"shape": shape_options[rng.randi_range(0, shape_options.size() - 1)], "size": rng.randi_range(34, 46), "label_visibility": rng.randf() > 0.2, "tint_variation": rng.randi_range(0, 3)}
		"themes_appearance":
			return {"palette": palette.duplicate(true), "surface_style": ["solid", "translucent", "layered"][rng.randi_range(0, 2)], "contrast": ["balanced", "high"][rng.randi_range(0, 1)]}
		"wallpapers":
			return {"path": WALLPAPERS[rng.randi_range(0, WALLPAPERS.size() - 1)], "treatment": ["natural", "dimmed", "gradient_overlay"][rng.randi_range(0, 2)], "blur": rng.randf_range(0.0, 0.18)}
		"animations_transitions":
			return {"style": ["fade", "slide", "scale", "spring"][rng.randi_range(0, 3)], "duration": rng.randf_range(0.16, 0.34), "reduced_motion": false}
		"control_center":
			return {"tile_shape": ["square", "rounded", "pill"][rng.randi_range(0, 2)], "tile_layout": ["compact", "expanded"][rng.randi_range(0, 1)], "brightness_style": ["bar", "slider"][rng.randi_range(0, 1)]}
		"notifications":
			return {"card_style": ["compact", "grouped", "expanded"][rng.randi_range(0, 2)], "corner_radius": rng.randi_range(6, 16), "show_app_icon": true, "translucent": rng.randf() > 0.5}
		"navigation_gestures":
			return {"mode": ["gesture", "three_button"][rng.randi_range(0, 1)], "indicator_style": ["line", "pill"][rng.randi_range(0, 1)], "edge_back": true}
		"app_drawer":
			return {"layout": ["alphabetical", "categories", "frequent_first"][rng.randi_range(0, 2)], "columns": int(style.get("grid_columns", 4)), "search_position": ["top", "bottom"][rng.randi_range(0, 1)]}
		"recent_apps":
			return {"layout": ["stack", "carousel", "grid"][rng.randi_range(0, 2)], "show_clear_all": true, "card_radius": rng.randi_range(8, 18)}
		"system_ui":
			return {"status_style": ["minimal", "detailed"][rng.randi_range(0, 1)], "battery_style": ["icon", "percentage", "pill"][rng.randi_range(0, 2)], "clock_alignment": ["left", "right"][rng.randi_range(0, 1)]}
	return {}

static func save_os(config: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(config, "\t"))
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
	return parsed if parsed is Dictionary else {}
