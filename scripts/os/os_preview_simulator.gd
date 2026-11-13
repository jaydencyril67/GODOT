extends Control

signal app_opened(app_name: String)

const OSEngine = preload("res://scripts/os/procedural_os_engine.gd")

class OSWallpaperLayer extends Control:
	var palette: Dictionary = {}
	var wallpaper_id := "aurora"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var background := Color(str(palette.get("background", "#0B1017")))
		var accent := Color(str(palette.get("accent", "#76C8D4")))
		var surface := Color(str(palette.get("surface_alt", "#263544")))
		draw_rect(Rect2(Vector2.ZERO, size), background)
		var scale_factor := maxf(size.x, size.y)
		var first_center := Vector2(size.x * 0.76, size.y * 0.29)
		var second_center := Vector2(size.x * 0.12, size.y * 0.79)
		var radius := scale_factor * 0.74
		for ring in range(20):
			var progress := float(ring) / 20.0
			var alpha := 0.012 + (1.0 - progress) * 0.008
			var ring_color := Color(accent.r, accent.g, accent.b, alpha)
			draw_circle(first_center, radius * (1.0 - progress * 0.88), ring_color)
		for ring in range(16):
			var progress := float(ring) / 16.0
			var alpha := 0.009 + (1.0 - progress) * 0.008
			draw_circle(second_center, radius * 0.65 * (1.0 - progress * 0.88), Color(surface.r, surface.g, surface.b, alpha))
		match wallpaper_id:
			"orbital":
				draw_arc(Vector2(size.x * 0.52, size.y * 0.46), scale_factor * 0.43, -0.8, 3.6, 96, Color(accent.r, accent.g, accent.b, 0.22), maxf(1.0, scale_factor * 0.004), true)
				draw_arc(Vector2(size.x * 0.52, size.y * 0.46), scale_factor * 0.34, 2.3, 5.9, 96, Color(surface.r, surface.g, surface.b, 0.30), maxf(1.0, scale_factor * 0.006), true)
			"dune":
				draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.67), Vector2(size.x * 0.34, size.y * 0.53), Vector2(size.x, size.y * 0.72), Vector2(size.x, size.y), Vector2(0, size.y)]), Color(accent.r, accent.g, accent.b, 0.10))
				draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.82), Vector2(size.x * 0.48, size.y * 0.68), Vector2(size.x, size.y * 0.85), Vector2(size.x, size.y), Vector2(0, size.y)]), Color(surface.r, surface.g, surface.b, 0.22))
			"prism":
				draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.54, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.68), Vector2(size.x * 0.79, size.y * 0.58)]), Color(accent.r, accent.g, accent.b, 0.12))
				draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.55), Vector2(size.x * 0.24, size.y * 0.38), Vector2(size.x * 0.62, size.y), Vector2(0, size.y)]), Color(surface.r, surface.g, surface.b, 0.18))
			"midnight_flow":
				draw_arc(Vector2(size.x * 0.18, size.y * 0.60), scale_factor * 0.58, -1.15, 1.22, 96, Color(accent.r, accent.g, accent.b, 0.17), maxf(2.0, scale_factor * 0.025), true)
				draw_arc(Vector2(size.x * 0.24, size.y * 0.66), scale_factor * 0.48, -1.08, 1.20, 96, Color(surface.r, surface.g, surface.b, 0.23), maxf(2.0, scale_factor * 0.018), true)
			_:
				draw_arc(first_center, scale_factor * 0.32, -2.7, 0.65, 96, Color(accent.r, accent.g, accent.b, 0.19), maxf(1.0, scale_factor * 0.005), true)

var configuration: Dictionary = {}
var active_component := "home_screen"
var page_container: VBoxContainer
var status_label: Label
var _palette: Dictionary = {}
var _style: Dictionary = {}
var _building := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if configuration.is_empty():
		configuration = OSEngine.generate_os()
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
		child.queue_free()

	_style = configuration.get("style", {})
	_palette = _style.get("palette", {"background":"#0B1017","surface":"#19232E","surface_alt":"#263544","accent":"#76C8D4","text":"#F4F7F8","muted":"#A7B4BD"})
	var wallpaper := OSWallpaperLayer.new()
	wallpaper.name = "OSProceduralWallpaper"
	wallpaper.palette = _palette.duplicate(true)
	wallpaper.wallpaper_id = str(_style.get("wallpaper", "aurora"))
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
	shell.add_theme_constant_override("separation", 7)
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

	var footer := CenterContainer.new()
	footer.name = "OSNavigationFooter"
	footer.custom_minimum_size.y = 10
	shell.add_child(footer)
	var indicator := ColorRect.new()
	indicator.name = "OSNavigationIndicator"
	indicator.custom_minimum_size = Vector2(34, 4)
	indicator.color = _text_color()
	footer.add_child(indicator)
	_building = false

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
	if bool(data.get("show_clock_widget", true)):
		var clock_widget := PanelContainer.new()
		clock_widget.name = "HomeClockWidget"
		clock_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_surface(clock_widget, true)
		var clock_content := VBoxContainer.new()
		clock_content.add_theme_constant_override("separation", 1)
		clock_widget.add_child(clock_content)
		var clock := _label("09:41", 30, _text_color())
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock_content.add_child(clock)
		var date := _label("MONDAY  ·  YOUR DAY AT A GLANCE", 7, _muted_color())
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock_content.add_child(date)
		page_container.add_child(clock_widget)

	if bool(data.get("show_search", true)):
		page_container.add_child(_search_field("Search apps and more"))

	_add_section_label("YOUR APPS")
	var columns := clampi(int(data.get("columns", _style.get("grid_columns", 4))), 3, 6)
	var apps_grid := GridContainer.new()
	apps_grid.name = "HomeAppGrid"
	apps_grid.columns = columns
	apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apps_grid.add_theme_constant_override("h_separation", 6)
	apps_grid.add_theme_constant_override("v_separation", 10)
	page_container.add_child(apps_grid)
	_populate_app_grid(apps_grid, "", int(configuration.get("components", {}).get("app_icons", {}).get("size", 46)), true)

	var dock := PanelContainer.new()
	dock.name = "HomeAppDock"
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_surface(dock, true)
	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 9)
	dock.add_child(dock_row)
	var dock_apps := ["Phone", "Messages", "Browser", "Camera"]
	for app_name in dock_apps:
		var app := _find_app(app_name)
		if not app.is_empty():
			dock_row.add_child(_create_app_icon(app, 34, false))
	page_container.add_child(dock)

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
		swatch_style.set_corner_radius_all(6)
		color_box.add_theme_stylebox_override("panel", swatch_style)
		swatch.add_child(color_box)
		var swatch_label := _label(key.replace("_", " ").capitalize(), 9, _text_color())
		swatch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.add_child(swatch_label)
		swatch.add_child(_label(str(_palette.get(key, "")), 8, _muted_color()))
		page_container.add_child(swatch)

func _build_wallpaper_preview(data: Dictionary) -> void:
	_add_section_label("WALLPAPER")
	var art := OSWallpaperLayer.new()
	art.name = "WallpaperStylePreview"
	art.palette = _palette.duplicate(true)
	art.wallpaper_id = str(data.get("style", data.get("id", "aurora")))
	art.custom_minimum_size = Vector2(0, 130)
	page_container.add_child(art)
	page_container.add_child(_label(str(art.wallpaper_id).replace("_", " ").capitalize() + " procedural wallpaper", 11, _text_color()))
	page_container.add_child(_label("One wallpaper identity is shared by the home screen and lock screen.", 8, _muted_color()))

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

func _build_control_center(data: Dictionary) -> void:
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
	_add_section_label("NOTIFICATION APPEARANCE")
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
	_add_section_label("ALL APPLICATIONS")
	var search := _search_field("Find an app")
	var grid := GridContainer.new()
	grid.name = "AppDrawerGrid"
	grid.columns = clampi(int(data.get("columns", _style.get("grid_columns", 4))), 3, 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	page_container.add_child(grid)
	_populate_app_grid(grid, "", int(configuration.get("components", {}).get("app_icons", {}).get("size", 46)), true)
	search.text_changed.connect(_on_app_search_changed.bind(grid))

func _build_recent_apps(data: Dictionary) -> void:
	_add_section_label("RECENT APPLICATIONS")
	var recent_list := VBoxContainer.new()
	recent_list.name = "RecentAppsList"
	recent_list.add_theme_constant_override("separation", 8)
	for app_name in ["Settings", "Camera", "Messages"]:
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 56
		_style_surface(card, true)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var app := _find_app(app_name)
		if not app.is_empty():
			row.add_child(_create_app_icon(app, 30, false))
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(_label(app_name, 9, _text_color()))
		details.add_child(_label("Recently opened", 7, _muted_color()))
		row.add_child(details)
		recent_list.add_child(card)
	page_container.add_child(recent_list)
	if bool(data.get("show_clear_all", true)):
		var clear := Button.new()
		clear.name = "ClearRecentAppsButton"
		clear.text = "CLEAR ALL"
		clear.custom_minimum_size.y = 34
		_style_action_button(clear)
		clear.pressed.connect(func():
			for child in recent_list.get_children():
				child.queue_free()
		)
		page_container.add_child(clear)

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
	tile.name = "App_" + str(app.get("name", "Application")).replace(" ", "")
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 3)
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := Button.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.text = str(app.get("glyph", "•"))
	icon.add_theme_font_size_override("font_size", maxi(14, int(icon_size * 0.42)))
	_style_icon_button(icon, Color(str(app.get("color", "#687987"))), str(configuration.get("components", {}).get("app_icons", {}).get("shape", "rounded")))
	icon.pressed.connect(_on_app_pressed.bind(str(app.get("name", "Application"))))
	holder.add_child(icon)
	tile.add_child(holder)
	if show_label:
		var caption := _label(str(app.get("name", "Application")), 7, _text_color())
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		tile.add_child(caption)
	return tile

func _populate_app_grid(grid: GridContainer, query: String, icon_size: int, show_labels: bool) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var normalized_query := query.strip_edges().to_lower()
	for app in OSEngine.APP_DEFINITIONS:
		if not normalized_query.is_empty() and not str(app.get("name", "")).to_lower().contains(normalized_query):
			continue
		grid.add_child(_create_app_icon(app, icon_size, show_labels))
	if grid.get_child_count() == 0:
		grid.add_child(_label("No matching applications", 8, _muted_color()))

func _on_app_search_changed(query: String, grid: GridContainer) -> void:
	if is_instance_valid(grid):
		_populate_app_grid(grid, query, int(configuration.get("components", {}).get("app_icons", {}).get("size", 46)), true)

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
	_style_icon_button(button, _surface_color(), "rounded")
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	return label

func _style_surface(panel: PanelContainer, prominent: bool = false) -> void:
	var style := StyleBoxFlat.new()
	var surface_color := Color(str(_palette.get("surface", "#19232E")))
	style.bg_color = Color(surface_color.r, surface_color.g, surface_color.b, 0.88 if prominent else 0.78)
	style.border_color = Color(_text_color().r, _text_color().g, _text_color().b, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 16)))
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

func _style_icon_button(button: Button, tint: Color, shape: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	var radius := 2 if shape == "square" else (7 if shape == "soft_square" else (12 if shape == "rounded" else 16))
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
