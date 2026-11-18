extends Control

const APP_MANIFEST_PATH := "res://assets/app_icons/papirus/manifest.json"
const StatusBarAssetLibrary = preload("res://scripts/status_bar_asset_library.gd")
const LOCK_ICON_PATH := "res://assets/lock-screen/aosp/SVG/ic_lock_locked.svg"

const HOME_PAGE_APP_IDS := [
	[
		"instagram", "facebook", "telegram", "tiktok",
		"google_keep", "google_docs", "google_earth", "netflix",
		"discord", "snapchat", "twitter", "shazam",
		"spotify_client", "google_chrome", "google_drive", "google_photos"
	],
	[
		"google_sheets", "google_slides", "google_classroom", "google_translate",
		"amazon_store", "ebay", "paypal", "uber_driver",
		"airbnb", "duolingo", "minecraft", "roblox",
		"pubg", "brawl_stars", "cash_app", "notion"
	]
]
const DOCK_APP_IDS := ["whatsapp", "gmail", "spotify_client", "youtube"]

var _design: Dictionary = {}
var _status_bar_style_id := "one_ui_balanced"
var _app_manifest: Array[Dictionary] = []
var _apps_by_id: Dictionary = {}
var _home_page_index := 0
var _clock_elapsed := 0.0

var _home_content: Control
var _app_drawer: Control
var _drawer_grid: GridContainer
var _drawer_search: LineEdit
var _status_bar: Control
var _clock_label: Label
var _date_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_load_app_manifest()
	set_process(true)


func _process(delta: float) -> void:
	_clock_elapsed += delta
	if _clock_elapsed >= 1.0:
		_clock_elapsed = 0.0
		_refresh_clock_labels()


func configure(design: Dictionary, status_bar_style_id: String = "one_ui_balanced") -> bool:
	if design.is_empty():
		return false
	if _app_manifest.is_empty():
		_load_app_manifest()
	_design = design.duplicate(true)
	_status_bar_style_id = status_bar_style_id if StatusBarAssetLibrary.has_style(status_bar_style_id) else "one_ui_balanced"
	_home_page_index = 0
	_build_screen()
	return _clock_label != null and _date_label != null and _status_bar != null


func set_status_bar_style(style_id: String) -> bool:
	if not StatusBarAssetLibrary.has_style(style_id):
		return false
	_status_bar_style_id = style_id
	if is_instance_valid(_status_bar):
		_status_bar.queue_free()
		_status_bar = null
	_add_status_bar()
	return true


func get_status_bar_style_id() -> String:
	return _status_bar_style_id


func get_home_page_count() -> int:
	return HOME_PAGE_APP_IDS.size()


func get_home_page_index() -> int:
	return _home_page_index


func get_loaded_app_count() -> int:
	return _app_manifest.size()


func get_home_icon_count() -> int:
	var total := DOCK_APP_IDS.size()
	for page in HOME_PAGE_APP_IDS:
		total += page.size()
	return total


func get_status_bar_icon_count() -> int:
	if not is_instance_valid(_status_bar):
		return 0
	var icon_count := 0
	for node in _status_bar.find_children("*", "TextureRect", true, false):
		var node_name := str(node.name)
		if node_name.begins_with("HomeStatusBar") and node_name.ends_with("Icon"):
			icon_count += 1
	return icon_count


func move_page(direction: int) -> bool:
	if is_app_drawer_visible() or direction == 0:
		return false
	var next_page := clampi(_home_page_index + signi(direction), 0, HOME_PAGE_APP_IDS.size() - 1)
	if next_page == _home_page_index:
		return false
	_home_page_index = next_page
	_rebuild_home_app_grid()
	_refresh_page_indicators()
	return true


func open_app_drawer() -> void:
	if is_instance_valid(_app_drawer):
		_app_drawer.visible = true
		if is_instance_valid(_drawer_search):
			_drawer_search.text = ""
		_rebuild_app_drawer_grid("")


func close_app_drawer() -> void:
	if is_instance_valid(_app_drawer):
		_app_drawer.visible = false
	if is_instance_valid(_drawer_search):
		_drawer_search.text = ""


func is_app_drawer_visible() -> bool:
	return is_instance_valid(_app_drawer) and _app_drawer.visible


func set_app_search_query(query: String) -> void:
	if not is_instance_valid(_drawer_search):
		return
	_drawer_search.text = query
	_rebuild_app_drawer_grid(query)


func get_app_drawer_result_count() -> int:
	if not is_instance_valid(_drawer_grid):
		return 0
	return _drawer_grid.get_child_count()


func _load_app_manifest() -> void:
	_app_manifest.clear()
	_apps_by_id.clear()
	if not FileAccess.file_exists(APP_MANIFEST_PATH):
		push_warning("Home screen app manifest is missing: " + APP_MANIFEST_PATH)
		return
	var file := FileAccess.open(APP_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Home screen app manifest could not be opened.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Home screen app manifest is not a valid JSON object.")
		return
	var raw_apps: Array = (parsed as Dictionary).get("apps", [])
	for raw_app in raw_apps:
		if not raw_app is Dictionary:
			continue
		var app: Dictionary = raw_app.duplicate(true)
		var app_id := str(app.get("id", ""))
		var icon_path := str(app.get("path", ""))
		if app_id.is_empty() or icon_path.is_empty() or not FileAccess.file_exists(icon_path):
			continue
		_app_manifest.append(app)
		_apps_by_id[app_id] = app


func _build_screen() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	_clock_label = null
	_date_label = null
	_status_bar = null
	_app_drawer = null
	_drawer_grid = null
	_drawer_search = null

	var wallpaper := TextureRect.new()
	wallpaper.name = "HomeScreenWallpaper"
	var wallpaper_path := str(_design.get("wallpaper_path", ""))
	if not wallpaper_path.is_empty() and ResourceLoader.exists(wallpaper_path):
		wallpaper.texture = load(wallpaper_path) as Texture2D
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(wallpaper)
	add_child(wallpaper)

	var shade := ColorRect.new()
	shade.name = "HomeScreenWallpaperLegibilityShade"
	shade.color = Color(0.004, 0.008, 0.014, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(shade)
	add_child(shade)

	_home_content = Control.new()
	_home_content.name = "HomeScreenMainPage"
	_home_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_full_rect(_home_content)
	add_child(_home_content)

	_add_clock_widget()
	_add_search_widget()
	_add_home_app_grid()
	_add_dock()
	_add_page_indicators()
	_add_navigation_gesture()
	_build_app_drawer()
	_add_status_bar()
	_refresh_clock_labels()


func _add_clock_widget() -> void:
	var palette: Dictionary = _design.get("palette", {})
	var primary: Color = palette.get("text", Color.WHITE)
	var secondary: Color = palette.get("muted", Color("#E0E5EE"))

	_clock_label = Label.new()
	_clock_label.name = "HomeScreenClock"
	_clock_label.add_theme_font_size_override("font_size", 88)
	_clock_label.add_theme_color_override("font_color", primary)
	_clock_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.28))
	_clock_label.add_theme_constant_override("shadow_offset_x", 1)
	_clock_label.add_theme_constant_override("shadow_offset_y", 2)
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(_clock_label, Rect2(Vector2(0.075, 0.082), Vector2(0.82, 0.092)))
	_home_content.add_child(_clock_label)

	_date_label = Label.new()
	_date_label.name = "HomeScreenDate"
	_date_label.add_theme_font_size_override("font_size", 25)
	_date_label.add_theme_color_override("font_color", secondary)
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(_date_label, Rect2(Vector2(0.082, 0.177), Vector2(0.82, 0.038)))
	_home_content.add_child(_date_label)


func _add_search_widget() -> void:
	var search_surface := PanelContainer.new()
	search_surface.name = "HomeScreenSearchWidget"
	_set_normalized_rect(search_surface, Rect2(Vector2(0.045, 0.265), Vector2(0.91, 0.058)))
	search_surface.add_theme_stylebox_override(
		"panel",
		_make_surface_style(Color(0.96, 0.97, 0.99, 0.90), Color(1.0, 1.0, 1.0, 0.34), 30, 18)
	)
	_home_content.add_child(search_surface)

	var row := HBoxContainer.new()
	row.name = "HomeSearchWidgetContents"
	row.add_theme_constant_override("separation", 13)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	search_surface.add_child(row)

	var google_mark := Label.new()
	google_mark.text = "G"
	google_mark.add_theme_font_size_override("font_size", 33)
	google_mark.add_theme_color_override("font_color", Color("#4285F4"))
	google_mark.custom_minimum_size.x = 34
	google_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	google_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	google_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(google_mark)

	var placeholder := Label.new()
	placeholder.text = "Search"
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.add_theme_font_size_override("font_size", 25)
	placeholder.add_theme_color_override("font_color", Color("#666B73"))
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(placeholder)

	var search_glyph := Label.new()
	search_glyph.text = "⌕"
	search_glyph.add_theme_font_size_override("font_size", 38)
	search_glyph.add_theme_color_override("font_color", Color("#555B65"))
	search_glyph.custom_minimum_size.x = 42
	search_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	search_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(search_glyph)


func _add_home_app_grid() -> void:
	var grid := GridContainer.new()
	grid.name = "HomeScreenAppGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(grid, Rect2(Vector2(0.035, 0.35), Vector2(0.93, 0.47)))
	_home_content.add_child(grid)
	_rebuild_home_app_grid()


func _rebuild_home_app_grid() -> void:
	if not is_instance_valid(_home_content):
		return
	var grid := _home_content.find_child("HomeScreenAppGrid", true, false) as GridContainer
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.free()

	if _home_page_index < 0 or _home_page_index >= HOME_PAGE_APP_IDS.size():
		return
	for app_id in HOME_PAGE_APP_IDS[_home_page_index]:
		var app: Dictionary = _apps_by_id.get(str(app_id), {})
		if app.is_empty():
			continue
		grid.add_child(_make_app_tile(app, 98, 24, 142, false))


func _add_dock() -> void:
	var palette: Dictionary = _design.get("palette", {})
	var dock_fill := Color(0.035, 0.045, 0.065, 0.45)
	var dock_border := Color(1.0, 1.0, 1.0, 0.18)
	if palette.has("glass"):
		var glass: Color = palette["glass"]
		dock_fill = Color(glass.r, glass.g, glass.b, 0.52)

	var dock := PanelContainer.new()
	dock.name = "HomeScreenDock"
	_set_normalized_rect(dock, Rect2(Vector2(0.035, 0.825), Vector2(0.93, 0.105)))
	dock.add_theme_stylebox_override("panel", _make_surface_style(dock_fill, dock_border, 30, 12))
	_home_content.add_child(dock)

	var row := HBoxContainer.new()
	row.name = "HomeScreenDockApps"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	dock.add_child(row)

	for app_id in DOCK_APP_IDS:
		var app: Dictionary = _apps_by_id.get(str(app_id), {})
		if app.is_empty():
			continue
		row.add_child(_make_app_tile(app, 78, 21, 118, true))


func _add_page_indicators() -> void:
	var holder := HBoxContainer.new()
	holder.name = "HomeScreenPageIndicators"
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 9)
	_set_normalized_rect(holder, Rect2(Vector2(0.38, 0.94), Vector2(0.24, 0.025)))
	_home_content.add_child(holder)
	_refresh_page_indicators()


func _refresh_page_indicators() -> void:
	if not is_instance_valid(_home_content):
		return
	var holder := _home_content.find_child("HomeScreenPageIndicators", true, false) as HBoxContainer
	if holder == null:
		return
	for child in holder.get_children():
		holder.remove_child(child)
		child.free()
	for index in range(HOME_PAGE_APP_IDS.size()):
		var dot := Panel.new()
		dot.name = "HomeScreenPageIndicator%d" % index
		dot.custom_minimum_size = Vector2(18, 7) if index == _home_page_index else Vector2(7, 7)
		var fill := Color(1.0, 1.0, 1.0, 0.94) if index == _home_page_index else Color(1.0, 1.0, 1.0, 0.48)
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(4)
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(dot)


func _add_navigation_gesture() -> void:
	var gesture := Panel.new()
	gesture.name = "HomeScreenNavigationGesture"
	gesture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.90)
	style.set_corner_radius_all(8)
	gesture.add_theme_stylebox_override("panel", style)
	_set_normalized_rect(gesture, Rect2(Vector2(0.405, 0.982), Vector2(0.19, 0.006)))
	_home_content.add_child(gesture)


func _make_app_tile(app: Dictionary, icon_size: int, label_size: int, tile_height: int, compact: bool) -> Control:
	var tile := VBoxContainer.new()
	tile.name = "HomeApp_" + str(app.get("id", "unknown"))
	tile.custom_minimum_size = Vector2(142, tile_height)
	tile.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_theme_constant_override("separation", 3 if compact else 5)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.name = "HomeAppIcon_" + str(app.get("id", "unknown"))
	var icon_path := str(app.get("path", ""))
	if not icon_path.is_empty():
		icon.texture = load(icon_path) as Texture2D
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)

	var label := Label.new()
	label.name = "HomeAppLabel_" + str(app.get("id", "unknown"))
	label.text = str(app.get("name", "App"))
	label.custom_minimum_size.y = 26
	label.add_theme_font_size_override("font_size", label_size)
	label.add_theme_color_override("font_color", Color("#FFFFFF"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(label)
	return tile


func _build_app_drawer() -> void:
	_app_drawer = Control.new()
	_app_drawer.name = "HomeScreenAppDrawer"
	_app_drawer.visible = false
	_app_drawer.mouse_filter = Control.MOUSE_FILTER_PASS
	_set_full_rect(_app_drawer)
	add_child(_app_drawer)

	var shade := ColorRect.new()
	shade.name = "AppDrawerShade"
	shade.color = Color(0.012, 0.016, 0.024, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(shade)
	_app_drawer.add_child(shade)

	var title := Label.new()
	title.name = "AppDrawerTitle"
	title.text = "All apps"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#F4F6FA"))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(title, Rect2(Vector2(0.06, 0.065), Vector2(0.88, 0.048)))
	_app_drawer.add_child(title)

	var search := LineEdit.new()
	search.name = "AppDrawerSearch"
	search.placeholder_text = "Search apps"
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", 25)
	search.add_theme_color_override("font_color", Color("#F3F5F8"))
	search.add_theme_color_override("font_placeholder_color", Color("#ADB5C2"))
	search.add_theme_stylebox_override("normal", _make_surface_style(Color(1.0, 1.0, 1.0, 0.10), Color(1.0, 1.0, 1.0, 0.18), 24, 16))
	search.add_theme_stylebox_override("focus", _make_surface_style(Color(1.0, 1.0, 1.0, 0.13), Color("#A9C9FF"), 24, 16))
	_set_normalized_rect(search, Rect2(Vector2(0.045, 0.125), Vector2(0.91, 0.056)))
	search.text_changed.connect(_on_app_search_changed)
	_app_drawer.add_child(search)
	_drawer_search = search

	var scroll := ScrollContainer.new()
	scroll.name = "AppDrawerScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_set_normalized_rect(scroll, Rect2(Vector2(0.025, 0.205), Vector2(0.95, 0.775)))
	_app_drawer.add_child(scroll)
	var scroll_bar := scroll.get_v_scroll_bar()
	scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_drawer_grid = GridContainer.new()
	_drawer_grid.name = "AppDrawerIconGrid"
	_drawer_grid.columns = 4
	_drawer_grid.add_theme_constant_override("h_separation", 4)
	_drawer_grid.add_theme_constant_override("v_separation", 12)
	_drawer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_drawer_grid)
	_rebuild_app_drawer_grid("")


func _on_app_search_changed(query: String) -> void:
	_rebuild_app_drawer_grid(query)


func _rebuild_app_drawer_grid(query: String) -> void:
	if not is_instance_valid(_drawer_grid):
		return
	for child in _drawer_grid.get_children():
		_drawer_grid.remove_child(child)
		child.free()

	var normalized_query := query.strip_edges().to_lower()
	for app in _app_manifest:
		var app_name := str(app.get("name", ""))
		var app_id := str(app.get("id", ""))
		if not normalized_query.is_empty() and not app_name.to_lower().contains(normalized_query) and not app_id.to_lower().contains(normalized_query):
			continue
		_drawer_grid.add_child(_make_app_tile(app, 84, 22, 132, false))


func _add_status_bar() -> void:
	var style: Dictionary = StatusBarAssetLibrary.get_style(_status_bar_style_id)
	var palette: Dictionary = _design.get("palette", {})
	var tint: Color = palette.get("muted", Color("#F4F6FA"))
	_status_bar = Control.new()
	_status_bar.name = "HomeScreenStatusBar"
	_status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_normalized_rect(_status_bar, Rect2(Vector2(0.055, 0.012), Vector2(0.89, 0.043)))
	add_child(_status_bar)

	var row := HBoxContainer.new()
	row.name = "HomeStatusBarContents"
	row.add_theme_constant_override("separation", int(style.get("gap", 3)) + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(row)
	_status_bar.add_child(row)

	var leading := HBoxContainer.new()
	leading.add_theme_constant_override("separation", int(style.get("gap", 3)) + 2)
	leading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(leading)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", int(style.get("gap", 3)) + 2)
	trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trailing)

	var time_label := Label.new()
	time_label.name = "HomeStatusBarClock"
	time_label.text = _current_time_text()
	time_label.add_theme_font_size_override("font_size", maxi(22, int(style.get("time_size", 12)) + 10))
	time_label.add_theme_color_override("font_color", tint)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_group := trailing if str(style.get("time_side", "left")) == "left" else leading
	var time_group := leading if str(style.get("time_side", "left")) == "left" else trailing
	if str(style.get("time_side", "left")) == "left":
		leading.add_child(time_label)
	else:
		trailing.add_child(time_label)

	if bool(style.get("show_lock", false)):
		var lock_icon := TextureRect.new()
		lock_icon.name = "HomeStatusBarLockIcon"
		lock_icon.texture = _load_tinted_asset(LOCK_ICON_PATH, tint)
		lock_icon.custom_minimum_size = Vector2(16, 20)
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_group.add_child(lock_icon)

	for icon_type in style.get("order", []):
		var icon_id := str(icon_type)
		if icon_id == "bluetooth" and not bool(style.get("show_bluetooth", false)):
			continue
		var texture_name := "bluetooth_connected" if icon_id == "bluetooth" else "%s_%d" % [icon_id, int(style.get(icon_id + "_level", 4))]
		var texture := StatusBarAssetLibrary.get_icon_texture(texture_name)
		if texture == null:
			continue
		var icon := TextureRect.new()
		icon.name = "HomeStatusBar" + icon_id.capitalize() + "Icon"
		icon.texture = texture
		icon.modulate = tint
		var base_size := float(style.get("icon_size", 16)) * 1.50
		var icon_width := base_size * 0.75 if icon_id == "signal" else base_size
		icon.custom_minimum_size = Vector2(icon_width, base_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_group.add_child(icon)


func _refresh_clock_labels() -> void:
	if is_instance_valid(_clock_label):
		_clock_label.text = _current_time_text()
	if is_instance_valid(_date_label):
		_date_label.text = _current_date_text()
	if is_instance_valid(_status_bar):
		var status_clock := _status_bar.find_child("HomeStatusBarClock", true, false) as Label
		if status_clock != null:
			status_clock.text = _current_time_text()


func _current_time_text() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(time["hour"]), int(time["minute"])]


func _current_date_text() -> String:
	var date := Time.get_date_dict_from_system()
	var weekdays := ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	var months := ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var weekday_index := clampi(int(date["weekday"]), 1, 7)
	var month_index := clampi(int(date["month"]), 1, 12)
	return "%s, %d %s" % [weekdays[weekday_index], int(date["day"]), months[month_index]]


func _make_surface_style(fill: Color, border: Color, radius: int, horizontal_margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _load_tinted_asset(path: String, tint: Color) -> Texture2D:
	var source := load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0:
				image.set_pixel(x, y, Color(tint.r, tint.g, tint.b, pixel.a * tint.a))
	return ImageTexture.create_from_image(image)


func _set_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _set_normalized_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.end.x
	control.anchor_bottom = rect.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
