extends Control

signal app_opened(app_name: String)

const OSEngine = preload("res://scripts/os/procedural_os_engine.gd")

class OSWallpaperLayer extends Control:
	var palette: Dictionary = {}
	var wallpaper_id := "aurora"
	var treatment := "natural"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var background := Color(str(palette.get("background", "#0B1017")))
		var accent := Color(str(palette.get("accent", "#76C8D4")))
		var surface := Color(str(palette.get("surface_alt", "#263544")))
		draw_rect(Rect2(Vector2.ZERO, size), background)

		var rng := RandomNumberGenerator.new()
		rng.seed = abs(hash(wallpaper_id))
		for star_index in range(34):
			var star_position := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y))
			var star_radius := rng.randf_range(0.45, 1.15)
			draw_circle(star_position, star_radius, Color(0.92, 0.96, 1.0, rng.randf_range(0.10, 0.34)))

		var shortest_side := minf(size.x, size.y)
		match wallpaper_id:
			"orbital":
				var planet_center := Vector2(size.x * 0.68, size.y * 0.43)
				var planet_radius := shortest_side * 0.31
				draw_arc(planet_center, planet_radius * 1.40, -0.45, 2.8, 96, Color(accent.r, accent.g, accent.b, 0.28), maxf(1.2, shortest_side * 0.010), true)
				draw_circle(planet_center, planet_radius, Color(surface.r * 0.55, surface.g * 0.55, surface.b * 0.55, 0.98))
				draw_circle(planet_center + Vector2(-planet_radius * 0.24, -planet_radius * 0.26), planet_radius * 0.76, Color(accent.r * 0.56, accent.g * 0.60, accent.b * 0.68, 0.72))
				draw_circle(planet_center + Vector2(-planet_radius * 0.43, -planet_radius * 0.43), planet_radius * 0.24, Color(1, 1, 1, 0.08))
				draw_arc(planet_center, planet_radius * 1.40, 2.95, 5.8, 96, Color(surface.r, surface.g, surface.b, 0.74), maxf(1.5, shortest_side * 0.018), true)
				draw_arc(planet_center, planet_radius * 0.91, -2.7, 0.4, 64, Color(accent.r, accent.g, accent.b, 0.34), maxf(1.0, shortest_side * 0.008), true)
			"dune":
				var far_dune := PackedVector2Array([
					Vector2(0, size.y * 0.58), Vector2(size.x * 0.18, size.y * 0.47),
					Vector2(size.x * 0.43, size.y * 0.55), Vector2(size.x * 0.72, size.y * 0.40),
					Vector2(size.x, size.y * 0.52), Vector2(size.x, size.y), Vector2(0, size.y)
				])
				var middle_dune := PackedVector2Array([
					Vector2(0, size.y * 0.73), Vector2(size.x * 0.22, size.y * 0.62),
					Vector2(size.x * 0.51, size.y * 0.70), Vector2(size.x * 0.79, size.y * 0.56),
					Vector2(size.x, size.y * 0.66), Vector2(size.x, size.y), Vector2(0, size.y)
				])
				var near_dune := PackedVector2Array([
					Vector2(0, size.y * 0.86), Vector2(size.x * 0.30, size.y * 0.75),
					Vector2(size.x * 0.61, size.y * 0.87), Vector2(size.x, size.y * 0.76),
					Vector2(size.x, size.y), Vector2(0, size.y)
				])
				draw_colored_polygon(far_dune, Color(surface.r, surface.g, surface.b, 0.52))
				draw_colored_polygon(middle_dune, Color(accent.r, accent.g, accent.b, 0.20))
				draw_colored_polygon(near_dune, Color(surface.r * 1.18, surface.g * 1.10, surface.b * 0.92, 0.86))
				draw_arc(Vector2(size.x * 0.32, size.y * 0.84), size.x * 0.46, -2.95, -0.35, 72, Color(1, 1, 1, 0.12), maxf(1.0, shortest_side * 0.006), true)
			"prism":
				var facet_one := PackedVector2Array([Vector2(size.x * 0.48, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.54), Vector2(size.x * 0.68, size.y * 0.42)])
				var facet_two := PackedVector2Array([Vector2(0, size.y * 0.22), Vector2(size.x * 0.48, 0), Vector2(size.x * 0.68, size.y * 0.42), Vector2(size.x * 0.28, size.y * 0.68)])
				var facet_three := PackedVector2Array([Vector2(size.x * 0.28, size.y * 0.68), Vector2(size.x * 0.68, size.y * 0.42), Vector2(size.x, size.y * 0.54), Vector2(size.x, size.y), Vector2(size.x * 0.48, size.y)])
				draw_colored_polygon(facet_one, Color(accent.r, accent.g, accent.b, 0.19))
				draw_colored_polygon(facet_two, Color(surface.r, surface.g, surface.b, 0.62))
				draw_colored_polygon(facet_three, Color(accent.r * 0.72, accent.g * 0.76, accent.b * 0.82, 0.20))
				draw_polyline(PackedVector2Array([Vector2(size.x * 0.48, 0), Vector2(size.x * 0.68, size.y * 0.42), Vector2(size.x * 0.28, size.y * 0.68), Vector2(size.x * 0.48, size.y)]), Color(1, 1, 1, 0.18), 1.2, true)
			"midnight_flow":
				for band in range(7):
					var points := PackedVector2Array()
					for step in range(41):
						var progress := float(step) / 40.0
						var wave := sin(progress * TAU * 1.15 + float(band) * 0.42) * 0.075
						var drift := cos(progress * PI * 1.3 + float(band) * 0.24) * 0.035
						var y_position := size.y * (0.28 + float(band) * 0.105 + wave + drift)
						points.append(Vector2(size.x * progress, y_position))
					draw_polyline(points, Color(surface.r, surface.g, surface.b, 0.24), maxf(3.0, shortest_side * 0.075), true)
					draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.12), maxf(1.0, shortest_side * 0.007), true)
			_:
				for band in range(6):
					var points := PackedVector2Array()
					for step in range(41):
						var progress := float(step) / 40.0
						var wave := sin(progress * TAU * 0.85 + float(band) * 0.56) * 0.070
						var crest := cos(progress * PI * 2.0 + float(band) * 0.30) * 0.025
						var y_position := size.y * (0.24 + float(band) * 0.105 + wave + crest)
						points.append(Vector2(size.x * progress, y_position))
					draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.045), maxf(3.0, shortest_side * 0.105), true)
					draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.13), maxf(1.0, shortest_side * 0.006), true)
				draw_circle(Vector2(size.x * 0.82, size.y * 0.24), shortest_side * 0.20, Color(accent.r, accent.g, accent.b, 0.035))

		if treatment == "deep_contrast":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.12))
		elif treatment == "soft_glow":
			draw_circle(Vector2(size.x * 0.74, size.y * 0.30), shortest_side * 0.42, Color(accent.r, accent.g, accent.b, 0.055))


var configuration: Dictionary = {}
var active_component := "home_screen"
var page_container: VBoxContainer
var status_label: Label
var _palette: Dictionary = {}
var _style: Dictionary = {}
var _building := false
var _last_layout_size := Vector2.ZERO
var _resize_rebuild_pending := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_simulator_resized)
	if configuration.is_empty():
		configuration = OSEngine.generate_os()
	_build_shell()
	_last_layout_size = size

func _on_simulator_resized() -> void:
	if not is_inside_tree() or size.x < 48.0 or size.y < 48.0:
		return
	if _last_layout_size == Vector2.ZERO:
		_last_layout_size = size
		return
	if size.distance_to(_last_layout_size) < 4.0:
		return
	_last_layout_size = size
	if _resize_rebuild_pending:
		return
	_resize_rebuild_pending = true
	call_deferred("_rebuild_after_resize")

func _rebuild_after_resize() -> void:
	_resize_rebuild_pending = false
	if is_inside_tree():
		_build_shell()

func configure_os(os_configuration: Dictionary, component_id: String = "home_screen") -> void:
	configuration = OSEngine.normalize_os(os_configuration)
	active_component = _safe_component_id(component_id)
	if is_inside_tree():
		_build_shell()

func set_component_view(component_id: String) -> void:
	active_component = _safe_component_id(component_id)
	if is_inside_tree():
		_build_shell()

func update_configuration(os_configuration: Dictionary) -> void:
	configuration = OSEngine.normalize_os(os_configuration)
	if is_inside_tree():
		_build_shell()

func _safe_component_id(component_id: String) -> String:
	for component in OSEngine.COMPONENTS:
		if str(component["id"]) == component_id:
			return component_id
	return "home_screen"

func _build_shell() -> void:
	if _building:
		return
	_building = true
	for child in get_children():
		remove_child(child)
		child.free()

	_style = configuration.get("style", {})
	_palette = _style.get("palette", {"background":"#0B1017","surface":"#19232E","surface_alt":"#263544","accent":"#76C8D4","text":"#F4F7F8","muted":"#A7B4BD"})
	var wallpaper := OSWallpaperLayer.new()
	wallpaper.name = "OSProceduralWallpaper"
	wallpaper.palette = _palette.duplicate(true)
	wallpaper.wallpaper_id = str(_style.get("wallpaper", "aurora"))
	wallpaper.treatment = str(configuration.get("components", {}).get("wallpapers", {}).get("treatment", "natural"))
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wallpaper)

	var safe_area := MarginContainer.new()
	safe_area.name = "OSSimulatorSafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 12)
	safe_area.add_theme_constant_override("margin_right", 12)
	safe_area.add_theme_constant_override("margin_top", 7)
	safe_area.add_theme_constant_override("margin_bottom", 7)
	add_child(safe_area)

	var shell := VBoxContainer.new()
	shell.name = "OSSimulatorLayout"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 6)
	safe_area.add_child(shell)

	_build_status_bar(shell)

	var scroll := ScrollContainer.new()
	scroll.name = "OSComponentViewport"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	shell.add_child(scroll)

	page_container = VBoxContainer.new()
	page_container.name = "OSComponentContent"
	page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_theme_constant_override("separation", int(_style.get("spacing", 10)))
	scroll.add_child(page_container)
	_build_component(active_component)

	var footer := VBoxContainer.new()
	footer.name = "OSNavigationFooter"
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 4)
	if active_component == "home_screen":
		var home_layout := str(configuration.get("components", {}).get("home_screen", {}).get("layout_style", "ios_grid"))
		if home_layout != "windows_tiles":
			_build_home_dock(footer)
	var indicator_alignment := CenterContainer.new()
	indicator_alignment.name = "OSNavigationIndicatorArea"
	indicator_alignment.custom_minimum_size = Vector2(0, 9)
	var indicator := ColorRect.new()
	indicator.name = "OSNavigationIndicator"
	indicator.custom_minimum_size = Vector2(34, 4)
	indicator.color = _text_color()
	indicator_alignment.add_child(indicator)
	footer.add_child(indicator_alignment)
	shell.add_child(footer)
	_building = false

func _build_home_dock(parent: VBoxContainer) -> void:
	var dock := PanelContainer.new()
	dock.name = "HomeAppDock"
	dock.custom_minimum_size.y = 48
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(dock, true)
	var dock_row := HBoxContainer.new()
	dock_row.name = "HomeAppDockIcons"
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_row.add_theme_constant_override("separation", 6)
	dock.add_child(dock_row)
	var dock_apps := ["Phone", "Messages", "Browser", "Camera"]
	var dock_icon_size := _responsive_icon_size(35, dock_apps.size(), 6)
	for app_name in dock_apps:
		var app := _find_app(app_name)
		if not app.is_empty():
			dock_row.add_child(_create_app_icon(app, dock_icon_size, false))
	parent.add_child(dock)


func _build_status_bar(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "OSStatusBar"
	row.custom_minimum_size.y = 16
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var clock_alignment := str(configuration.get("components", {}).get("system_ui", {}).get("clock_alignment", "left"))
	var clock := _label("9:41", 9, _text_color())
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if clock_alignment == "right":
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(clock)
	status_label = _label("●  ▮▮▮  " + ("100%" if configuration.get("components", {}).get("system_ui", {}).get("battery_style") == "percentage" else "▰"), 8, _text_color())
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status_label)

func _build_component(component_id: String) -> void:
	var components: Dictionary = configuration.get("components", {})
	var component_data: Dictionary = components.get(component_id, {})
	match component_id:
		"home_screen":
			_build_home_screen(component_data)
		"lock_screen":
			_build_lock_screen(component_data)
		"app_icons":
			_build_icon_gallery(component_data)
		"themes_appearance":
			_build_theme_preview(component_data)
		"wallpapers":
			_build_wallpaper_preview(component_data)
		"animations_transitions":
			_build_animation_preview(component_data)
		"control_center":
			_build_control_center(component_data)
		"notifications":
			_build_notifications(component_data)
		"navigation_gestures":
			_build_navigation_preview(component_data)
		"app_drawer":
			_build_app_drawer(component_data)
		"recent_apps":
			_build_recent_apps(component_data)
		"system_ui":
			_build_system_ui(component_data)

func _build_home_screen(data: Dictionary) -> void:
	var layout_style := str(data.get("layout_style", "ios_grid"))
	var widget_count := clampi(int(_style.get("widget_count", data.get("widget_count", 0))), 0, 4)

	match layout_style:
		"android_pixel":
			_build_home_header("At a glance", "Your day, at a glance")
			_build_home_widgets(widget_count)
			page_container.add_child(_search_field("Search apps"))
			_add_section_label("FAVOURITES")
			_build_home_grid(data)
		"samsung_one_ui":
			_build_home_header("Good evening", "Your phone, arranged for easy reach")
			_build_home_widgets(widget_count)
			_add_section_label("APPS")
			_build_home_grid(data)
		"windows_tiles":
			_build_home_header("Start", "Pinned apps and live information")
			_build_home_widgets(widget_count)
			_add_section_label("PINNED")
			_build_windows_tiles()
		"compact_list":
			_build_home_header("Applications", "A focused, space-efficient home")
			_build_home_widgets(widget_count)
			page_container.add_child(_search_field("Find an app"))
			_build_home_list()
		"category_sections":
			_build_home_header("Your apps", "Organised by what you do")
			_build_home_widgets(widget_count)
			_build_home_categories(data)
		_:
			_build_home_widgets(widget_count)
			if bool(data.get("show_search", true)):
				page_container.add_child(_search_field("Search apps and more"))
			_add_section_label("YOUR APPS")
			_build_home_grid(data)


func _build_home_header(title_text: String, subtitle_text: String) -> void:
	var header := VBoxContainer.new()
	header.name = "HomeLayoutHeader"
	header.add_theme_constant_override("separation", 1)
	var title := _label(title_text, 18, _text_color())
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	var subtitle := _label(subtitle_text, 7, _muted_color())
	header.add_child(subtitle)
	page_container.add_child(header)


func _build_home_widgets(widget_count: int) -> void:
	for widget_index in range(widget_count):
		_build_home_widget(widget_index)


func _build_home_grid(data: Dictionary) -> void:
	var preferred_columns := clampi(int(data.get("columns", _style.get("grid_columns", 4))), 2, 6)
	var columns := _responsive_columns(preferred_columns)
	var apps_grid := GridContainer.new()
	apps_grid.name = "HomeAppGrid"
	apps_grid.columns = columns
	apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_grid.add_theme_constant_override("h_separation", 7)
	apps_grid.add_theme_constant_override("v_separation", 9)
	page_container.add_child(apps_grid)
	_populate_app_grid(apps_grid, "", int(configuration.get("style", {}).get("icon_size", 52)), true)


func _build_windows_tiles() -> void:
	var tiles := GridContainer.new()
	tiles.name = "WindowsLiveTileGrid"
	tiles.columns = _responsive_columns(3)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("h_separation", 5)
	tiles.add_theme_constant_override("v_separation", 5)
	page_container.add_child(tiles)
	for app in OSEngine.APP_DEFINITIONS:
		var tile := Button.new()
		tile.name = "LiveTile_" + str(app.get("name", "App")).replace(" ", "")
		tile.custom_minimum_size = Vector2(48, 54)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.text = str(app.get("glyph", "•")) + "\n" + str(app.get("name", "App"))
		tile.add_theme_font_size_override("font_size", 9)
		_style_icon_button(tile, Color(str(app.get("color", "#687987"))), "square")
		tile.pressed.connect(_on_app_pressed.bind(str(app.get("name", "App"))))
		tiles.add_child(tile)


func _build_home_list() -> void:
	var app_list := VBoxContainer.new()
	app_list.name = "HomeAppList"
	app_list.add_theme_constant_override("separation", 4)
	app_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_child(app_list)
	for app in OSEngine.APP_DEFINITIONS:
		var app_name := str(app.get("name", "App"))
		var row := HBoxContainer.new()
		row.name = "HomeListRow_" + app_name.replace(" ", "")
		row.custom_minimum_size.y = 35
		row.add_theme_constant_override("separation", 9)
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.text = str(app.get("glyph", "•"))
		_style_icon_button(icon, Color(str(app.get("color", "#687987"))), "square")
		icon.pressed.connect(_on_app_pressed.bind(app_name))
		row.add_child(icon)
		var label := _label(app_name, 9, _text_color())
		row.add_child(label)
		var open_button := Button.new()
		open_button.text = "›"
		open_button.custom_minimum_size = Vector2(24, 28)
		_style_action_button(open_button)
		open_button.pressed.connect(_on_app_pressed.bind(app_name))
		row.add_child(open_button)
		app_list.add_child(row)


func _build_home_categories(data: Dictionary) -> void:
	var groups := {
		"COMMUNICATION": ["Phone", "Messages"],
		"MEDIA": ["Camera", "Gallery", "Music"],
		"PRODUCTIVITY": ["Calendar", "Files", "Notes", "Clock"],
		"DISCOVER": ["Browser", "Maps", "Settings"]
	}
	for group_name in groups:
		_add_section_label(group_name)
		var group_grid := GridContainer.new()
		group_grid.name = "HomeCategory_" + group_name.replace(" ", "") + "Grid"
		group_grid.columns = _responsive_columns(int(data.get("columns", _style.get("grid_columns", 4))))
		group_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group_grid.add_theme_constant_override("h_separation", 7)
		group_grid.add_theme_constant_override("v_separation", 8)
		page_container.add_child(group_grid)
		for app_name in groups[group_name]:
			var app := _find_app(app_name)
			if not app.is_empty():
				group_grid.add_child(_create_app_icon(app, _responsive_icon_size(int(_style.get("icon_size", 52)), group_grid.columns), true))


func _build_home_widget(widget_index: int) -> void:
	var widget_names := ["Clock", "Weather", "Calendar", "Music"]
	var widget_titles := ["09:41", "WEATHER  ·  LOCAL CONDITIONS", "UP NEXT  ·  CALENDAR", "NOW PLAYING"]
	var widget_details := ["MONDAY  ·  YOUR DAY AT A GLANCE", "28°  ·  PARTLY CLOUDY", "Team meeting  ·  10:30 AM", "No track currently playing"]
	var widget := PanelContainer.new()
	widget.name = "HomeWidget_" + widget_names[widget_index]
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(widget, true)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	widget.add_child(content)
	var heading := _label(widget_titles[widget_index], 20 if widget_index == 0 else 9, _text_color())
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if widget_index == 0 else HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(heading)
	var detail := _label(widget_details[widget_index], 7, _muted_color())
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if widget_index == 0 else HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(detail)
	page_container.add_child(widget)

func _build_lock_screen(data: Dictionary) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	page_container.add_child(spacer)
	var clock := _label("09:41", 38 if data.get("clock_style") == "bold" else 31, _text_color())
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_container.add_child(clock)
	var date := _label("MONDAY  ·  NOVEMBER 13", 8, _muted_color())
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_container.add_child(date)
	var breathing_space := Control.new()
	breathing_space.custom_minimum_size.y = 22
	page_container.add_child(breathing_space)
	if bool(data.get("show_notifications", true)):
		_add_notification_surface("Messages", "A new message is waiting", "NOW")
		_add_notification_surface("Calendar", "Your next event is coming up", "IN 10 MIN")
	var bottom_space := Control.new()
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_space.custom_minimum_size.y = 12
	page_container.add_child(bottom_space)
	var shortcut_row := HBoxContainer.new()
	shortcut_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcut_row.add_theme_constant_override("separation", 26)
	shortcut_row.add_child(_round_shortcut("◉"))
	shortcut_row.add_child(_round_shortcut("▣"))
	page_container.add_child(shortcut_row)
	var unlock := Button.new()
	unlock.name = "UnlockOSButton"
	unlock.text = "SWIPE TO UNLOCK"
	unlock.custom_minimum_size.y = 36
	_style_action_button(unlock, true)
	unlock.pressed.connect(func(): set_component_view("home_screen"))
	page_container.add_child(unlock)

func _build_icon_gallery(data: Dictionary) -> void:
	_add_section_label("APP ICON SYSTEM")
	var columns := 3
	var grid := GridContainer.new()
	grid.name = "AppIconGallery"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 10)
	page_container.add_child(grid)
	_populate_app_grid(grid, "", int(data.get("size", 48)), bool(data.get("label_visibility", true)))

func _build_theme_preview(data: Dictionary) -> void:
	_add_section_label(str(data.get("palette", {}).get("name", "Theme")) + " · APPEARANCE")
	var sample := PanelContainer.new()
	sample.name = "ThemeSampleSurface"
	sample.custom_minimum_size.y = 72
	_style_surface(sample, true)
	var sample_content := VBoxContainer.new()
	sample_content.add_theme_constant_override("separation", 3)
	sample.add_child(sample_content)
	sample_content.add_child(_label("A consistent visual language", 11, _text_color()))
	sample_content.add_child(_label("Surface, typography and actions share one palette.", 8, _muted_color()))
	var action := Button.new()
	action.text = "PRIMARY ACTION"
	action.custom_minimum_size.y = 30
	_style_action_button(action, true)
	sample_content.add_child(action)
	page_container.add_child(sample)
	for key in ["background", "surface", "surface_alt", "accent", "text", "muted"]:
		var swatch := HBoxContainer.new()
		swatch.add_theme_constant_override("separation", 9)
		var color_box := PanelContainer.new()
		color_box.custom_minimum_size = Vector2(34, 26)
		var swatch_style := StyleBoxFlat.new()
		swatch_style.bg_color = Color(str(_palette.get(key, "#FFFFFF")))
		swatch_style.set_corner_radius_all(int(_style.get("corner_radius", 0)))
		color_box.add_theme_stylebox_override("panel", swatch_style)
		swatch.add_child(color_box)
		var swatch_label := _label(key.replace("_", " ").capitalize(), 9, _text_color())
		swatch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.add_child(swatch_label)
		swatch.add_child(_label(str(_palette.get(key, "")), 8, _muted_color()))
		page_container.add_child(swatch)

func _build_wallpaper_preview(data: Dictionary) -> void:
	_add_section_label("WALLPAPER COLLECTION")
	var art := OSWallpaperLayer.new()
	art.name = "WallpaperStylePreview"
	art.palette = _palette.duplicate(true)
	art.wallpaper_id = str(data.get("style", data.get("id", "aurora")))
	art.treatment = str(data.get("treatment", "natural"))
	art.custom_minimum_size = Vector2(0, 164)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_child(art)
	var wallpaper_name := _label(art.wallpaper_id.replace("_", " ").capitalize(), 11, _text_color())
	page_container.add_child(wallpaper_name)
	var treatment_name := str(data.get("treatment", "natural")).replace("_", " ").capitalize()
	page_container.add_child(_label("Shared home and lock screen wallpaper  ·  " + treatment_name, 8, _muted_color()))


func _build_animation_preview(data: Dictionary) -> void:
	_add_section_label("MOTION & TRANSITIONS")
	var demo := PanelContainer.new()
	demo.name = "AnimationDemoSurface"
	demo.custom_minimum_size = Vector2(0, 92)
	_style_surface(demo, true)
	var demo_content := CenterContainer.new()
	demo.add_child(demo_content)
	var demo_label := _label("OS WINDOW", 12, _text_color())
	demo_content.add_child(demo_label)
	page_container.add_child(demo)
	var description := _label(str(data.get("style", "fade")).capitalize() + " · " + str(snappedf(float(data.get("duration", 0.24)), 0.01)) + "s", 9, _muted_color())
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_container.add_child(description)
	var play := Button.new()
	play.text = "PREVIEW TRANSITION"
	play.custom_minimum_size.y = 34
	_style_action_button(play, true)
	play.pressed.connect(func():
		var tween := create_tween()
		demo.scale = Vector2(0.92, 0.92)
		demo.modulate.a = 0.45
		tween.set_parallel(true)
		var duration := float(data.get("duration", 0.24))
		tween.tween_property(demo, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(demo, "modulate:a", 1.0, duration)
	)
	page_container.add_child(play)

func _build_control_center(_data: Dictionary) -> void:
	_add_section_label("QUICK SETTINGS")
	var grid := GridContainer.new()
	grid.name = "QuickSettingsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	page_container.add_child(grid)
	for item in ["Wi-Fi", "Bluetooth", "Airplane mode", "Flashlight", "Focus", "Battery saver"]:
		var toggle := Button.new()
		toggle.text = item
		toggle.toggle_mode = true
		toggle.button_pressed = item in ["Wi-Fi", "Bluetooth"]
		toggle.custom_minimum_size.y = 42
		_style_action_button(toggle, toggle.button_pressed)
		toggle.toggled.connect(func(enabled: bool): _style_action_button(toggle, enabled))
		grid.add_child(toggle)
	_add_slider_row("Brightness", 72)
	_add_slider_row("Volume", 58)

func _build_notifications(data: Dictionary) -> void:
	_add_section_label("NOTIFICATION PANEL")
	_add_notification_surface("Messages", "A new message is waiting", "NOW")
	_add_notification_surface("Calendar", "Your next event is coming up", "10 MIN")
	_add_notification_surface("System", "Your device is up to date", "EARLIER")
	page_container.add_child(_label("Card style · " + str(data.get("card_style", "grouped")).replace("_", " ").capitalize(), 8, _muted_color()))

func _build_navigation_preview(data: Dictionary) -> void:
	_add_section_label("SYSTEM NAVIGATION")
	page_container.add_child(_surface_label("Navigation mode  ·  " + str(data.get("mode", "gesture")).replace("_", " ").capitalize(), 10))
	if data.get("mode", "gesture") == "three_button":
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 10)
		for caption in ["BACK", "HOME", "RECENTS"]:
			var button := Button.new()
			button.text = caption
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 36
			_style_action_button(button)
			buttons.add_child(button)
		page_container.add_child(buttons)
	else:
		var gesture_area := PanelContainer.new()
		gesture_area.custom_minimum_size.y = 90
		_style_surface(gesture_area, true)
		var gesture_label := _label("Swipe up to go home\nSwipe from an edge to go back", 9, _text_color())
		gesture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gesture_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gesture_area.add_child(gesture_label)
		page_container.add_child(gesture_area)
	var indicator := CenterContainer.new()
	indicator.custom_minimum_size.y = 20
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(42 if data.get("indicator_style") == "pill" else 28, 4)
	line.color = _text_color()
	indicator.add_child(line)
	page_container.add_child(indicator)

func _build_app_drawer(data: Dictionary) -> void:
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 6)
	var heading := _label("ALL APPS", 9, _accent_color())
	heading_row.add_child(heading)
	var count_label := _label("%02d INSTALLED" % OSEngine.APP_DEFINITIONS.size(), 7, _muted_color())
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(count_label)
	page_container.add_child(heading_row)

	var search := _search_field("Search installed apps")
	search.name = "AppDrawerSearchField"
	page_container.add_child(search)

	var grid := GridContainer.new()
	grid.name = "AppDrawerGrid"
	var preferred_columns := clampi(int(data.get("columns", _style.get("grid_columns", 4))), 2, 6)
	grid.columns = _responsive_columns(preferred_columns)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 10)
	page_container.add_child(grid)
	_populate_app_grid(grid, "", int(configuration.get("style", {}).get("icon_size", 52)), true)
	search.text_changed.connect(_on_app_search_changed.bind(grid))


func _build_recent_apps(_data: Dictionary) -> void:
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 6)
	var heading := _label("RECENT APPS", 9, _accent_color())
	heading_row.add_child(heading)
	var clear := Button.new()
	clear.name = "ClearRecentAppsButton"
	clear.text = "CLEAR"
	clear.custom_minimum_size = Vector2(56, 27)
	_style_action_button(clear)
	heading_row.add_child(clear)
	page_container.add_child(heading_row)

	var recent_scroll := ScrollContainer.new()
	recent_scroll.name = "RecentAppsViewport"
	recent_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent_scroll.custom_minimum_size.y = 174
	recent_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	recent_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_container.add_child(recent_scroll)

	var recent_row := HBoxContainer.new()
	recent_row.name = "RecentAppsList"
	recent_row.add_theme_constant_override("separation", 8)
	recent_scroll.add_child(recent_row)

	var empty_state := _label("No recent apps", 8, _muted_color())
	empty_state.name = "NoRecentAppsLabel"
	empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state.custom_minimum_size = Vector2(100, 42)
	var recent_names := ["Settings", "Camera", "Messages"]
	var card_width := clampf(size.x * 0.76, 108.0, 140.0)

	var remove_card := func(card: Control) -> void:
		if is_instance_valid(card) and card.get_parent() == recent_row:
			recent_row.remove_child(card)
			card.queue_free()
		if recent_row.get_child_count() == 0 and empty_state.get_parent() == null:
			recent_row.add_child(empty_state)

	for app_name in recent_names:
		var app := _find_app(app_name)
		if app.is_empty():
			continue
		var card := PanelContainer.new()
		card.name = "RecentAppCard_" + app_name.replace(" ", "")
		card.custom_minimum_size = Vector2(card_width, 158)
		_style_surface(card, true)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 6)
		card.add_child(content)

		var card_header := HBoxContainer.new()
		card_header.add_theme_constant_override("separation", 4)
		card_header.add_child(_create_app_icon(app, 22, false))
		var app_title := _label(app_name, 8, _text_color())
		app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_header.add_child(app_title)
		var close := Button.new()
		close.name = "CloseRecentApp_" + app_name.replace(" ", "")
		close.text = "×"
		close.custom_minimum_size = Vector2(20, 20)
		close.add_theme_font_size_override("font_size", 12)
		_style_action_button(close)
		card_header.add_child(close)
		close.pressed.connect(remove_card.bind(card))
		content.add_child(card_header)

		var preview := PanelContainer.new()
		preview.name = "RecentAppPreview_" + app_name.replace(" ", "")
		preview.custom_minimum_size.y = 102
		_style_surface(preview)
		var preview_content := VBoxContainer.new()
		preview_content.add_theme_constant_override("separation", 5)
		preview.add_child(preview_content)
		var preview_status := _label("9:41  ·  " + app_name.to_upper(), 6, _muted_color())
		preview_content.add_child(preview_status)
		var preview_title := ""
		match app_name:
			"Settings":
				preview_title = "Device settings"
			"Camera":
				preview_title = "Camera ready"
			"Messages":
				preview_title = "Recent conversations"
		preview_content.add_child(_label(preview_title, 8, _text_color()))
		for line_index in range(3):
			var preview_line := ColorRect.new()
			preview_line.custom_minimum_size = Vector2(0, 3)
			preview_line.color = Color(_muted_color().r, _muted_color().g, _muted_color().b, 0.22 + float(line_index) * 0.06)
			preview_content.add_child(preview_line)
		content.add_child(preview)
		content.add_child(_label("Recently opened", 6, _muted_color()))
		recent_row.add_child(card)

	clear.pressed.connect(func() -> void:
		for child in recent_row.get_children():
			if child != empty_state:
				recent_row.remove_child(child)
				child.queue_free()
		if empty_state.get_parent() == null:
			recent_row.add_child(empty_state)
	)
	if recent_row.get_child_count() == 0:
		recent_row.add_child(empty_state)


func _build_system_ui(data: Dictionary) -> void:
	_add_section_label("SYSTEM INTERFACE")
	var status_sample := PanelContainer.new()
	status_sample.custom_minimum_size.y = 48
	_style_surface(status_sample)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	status_sample.add_child(row)
	var clock := _label("9:41", 10, _text_color())
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if data.get("clock_alignment") == "right":
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(clock)
	row.add_child(_label("●  ▮▮▮", 8, _text_color()))
	row.add_child(_label("100%" if data.get("battery_style") == "percentage" else "▰", 8, _text_color()))
	page_container.add_child(status_sample)
	for item in ["Status bar", "Signal strength", "Wi-Fi state", "Battery indicator", "Navigation indicator"]:
		page_container.add_child(_surface_label(item + "  ·  " + str(data.get("status_style", "minimal")).capitalize(), 8))

func _add_slider_row(caption: String, initial_value: float) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 2)
	section.add_child(_label(caption, 8, _muted_color()))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial_value
	slider.custom_minimum_size.y = 22
	section.add_child(slider)
	page_container.add_child(section)

func _add_notification_surface(app_name: String, message: String, time_label: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)
	var header := HBoxContainer.new()
	header.add_child(_label(app_name.to_upper(), 7, _accent_color()))
	var time := _label(time_label, 7, _muted_color())
	time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(time)
	content.add_child(header)
	content.add_child(_label(message, 9, _text_color()))
	page_container.add_child(card)

func _add_section_label(caption: String) -> void:
	var label := _label(caption, 8, _accent_color())
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 1)
	page_container.add_child(label)

func _search_field(placeholder_text: String) -> LineEdit:
	var search := LineEdit.new()
	search.placeholder_text = placeholder_text
	search.custom_minimum_size.y = 36
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.clear_button_enabled = true
	search.add_theme_color_override("font_color", _text_color())
	search.add_theme_color_override("font_placeholder_color", _muted_color())
	_style_field(search)
	return search

func _surface_label(caption: String, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 30
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(panel)
	var label := _label(caption, font_size, _text_color())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func _create_app_icon(app: Dictionary, icon_size: int, show_label: bool) -> Control:
	var tile := VBoxContainer.new()
	var app_name := str(app.get("name", "Application"))
	tile.name = "App_" + app_name.replace(" ", "")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 3)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := Button.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.text = str(app.get("glyph", "•"))
	icon.add_theme_font_size_override("font_size", maxi(16, int(icon_size * 0.50)))
	_style_icon_button(icon, Color(str(app.get("color", "#687987"))), str(configuration.get("style", {}).get("icon_shape", "rounded")))
	icon.pressed.connect(_on_app_pressed.bind(app_name))
	holder.add_child(icon)
	tile.add_child(holder)
	if show_label:
		var caption := _label(app_name, 7, _text_color())
		caption.name = "AppLabel_" + app_name.replace(" ", "")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.clip_text = true
		tile.add_child(caption)
	return tile


func _responsive_columns(preferred_columns: int) -> int:
	var available_width := size.x if size.x > 0.0 else 180.0
	var inner_width := maxf(available_width - 26.0, 88.0)
	var minimum_cell_width := 46.0
	var gap := 7.0
	var fitting_columns := floori((inner_width + gap) / (minimum_cell_width + gap))
	return clampi(mini(preferred_columns, fitting_columns), 2, 6)

func _responsive_icon_size(requested_size: int, columns: int, gap: int = 7) -> int:
	var available_width := size.x if size.x > 0.0 else 180.0
	var inner_width := maxf(available_width - 26.0, 88.0)
	var cell_width := (inner_width - float(maxi(columns - 1, 0) * gap)) / float(maxi(columns, 1))
	return clampi(mini(requested_size, floori(cell_width)), 24, requested_size)


func _populate_app_grid(grid: GridContainer, query: String, icon_size: int, show_labels: bool) -> void:
	var fitted_icon_size := _responsive_icon_size(icon_size, grid.columns, 7)
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var normalized_query := query.strip_edges().to_lower()
	for app in OSEngine.APP_DEFINITIONS:
		if not normalized_query.is_empty() and not str(app.get("name", "")).to_lower().contains(normalized_query):
			continue
		grid.add_child(_create_app_icon(app, fitted_icon_size, show_labels))
	if grid.get_child_count() == 0:
		var empty_label := _label("No matching applications", 8, _muted_color())
		empty_label.name = "NoMatchingAppsLabel"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty_label)


func _on_app_search_changed(query: String, grid: GridContainer) -> void:
	if is_instance_valid(grid):
		_populate_app_grid(grid, query, int(configuration.get("style", {}).get("icon_size", 46)), true)

func _find_app(app_name: String) -> Dictionary:
	for app in OSEngine.APP_DEFINITIONS:
		if str(app.get("name", "")) == app_name:
			return app
	return {}

func _round_shortcut(glyph: String) -> Control:
	var button := Button.new()
	button.text = glyph
	button.custom_minimum_size = Vector2(42, 42)
	button.add_theme_font_size_override("font_size", 16)
	_style_icon_button(button, _surface_color(), str(_style.get("icon_shape", "square")))
	return button

func _on_app_pressed(app_name: String) -> void:
	app_opened.emit(app_name)
	if is_instance_valid(status_label):
		status_label.text = app_name + " preview"

func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	var scale_factor := float(_style.get("font_scale", 1.0))
	label.add_theme_font_size_override("font_size", maxi(7, roundi(float(font_size) * scale_factor)))
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Never split an unbroken word into one-character vertical lines on narrow previews.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _style_surface(panel: PanelContainer, prominent: bool = false) -> void:
	var style := StyleBoxFlat.new()
	var surface_color := Color(str(_palette.get("surface", "#19232E")))
	style.bg_color = Color(surface_color.r, surface_color.g, surface_color.b, 0.88 if prominent else 0.78)
	style.border_color = Color(_text_color().r, _text_color().g, _text_color().b, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 0)))
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)

func _style_action_button(button: Button, active: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _accent_color() if active else _surface_color()
	normal.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.60)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(int(_style.get("corner_radius", 16)))
	normal.content_margin_left = 9
	normal.content_margin_right = 9
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.10)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = pressed.bg_color.darkened(0.10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", _text_color())
	button.add_theme_color_override("font_hover_color", _text_color())
	button.add_theme_font_size_override("font_size", 8)
	button.focus_mode = Control.FOCUS_NONE

func _style_icon_button(button: Button, tint: Color, _shape: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	var radius := int(_style.get("corner_radius", 0))
	style.set_corner_radius_all(radius)
	style.border_color = Color(1, 1, 1, 0.20)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.focus_mode = Control.FOCUS_NONE

func _style_field(field: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _surface_color()
	style.border_color = Color(_accent_color().r, _accent_color().g, _accent_color().b, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 16)))
	style.content_margin_left = 9
	style.content_margin_right = 9
	field.add_theme_stylebox_override("normal", style)

func _surface_color() -> Color:
	return Color(str(_palette.get("surface", "#19232E")))

func _accent_color() -> Color:
	return Color(str(_palette.get("accent", "#76C8D4")))

func _text_color() -> Color:
	return Color(str(_palette.get("text", "#F4F7F8")))

func _muted_color() -> Color:
	return Color(str(_palette.get("muted", "#A7B4BD")))
