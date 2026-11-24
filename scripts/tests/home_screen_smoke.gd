extends SceneTree

const LockScreenDesignerScript = preload("res://scripts/lock_screen_designer.gd")
const HomeScreenDesignerScript = preload("res://scripts/home_screen_designer.gd")
const AppIconLibrary = preload("res://scripts/app_icon_library.gd")


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var lock_screen: Control = LockScreenDesignerScript.new()
	lock_screen.name = "HomeScreenSourceLockScreen"
	lock_screen.size = Vector2(680.0, 1360.0)
	root.add_child(lock_screen)
	await process_frame
	var design: Dictionary = lock_screen.call("generate_new_design")
	if design.is_empty():
		_fail("The lock-screen designer could not provide a wallpaper and palette for the home screen.")
		return

	var home_screen: Control = HomeScreenDesignerScript.new()
	home_screen.name = "HomeScreenDesignerSmokeTest"
	home_screen.size = Vector2(680.0, 1360.0)
	root.add_child(home_screen)
	await process_frame
	if not bool(home_screen.call("configure", design, "one_ui_balanced")):
		_fail("The One UI home screen did not configure from the generated lock-screen design.")
		return
	await process_frame

	var wallpaper := home_screen.find_child("HomeScreenWallpaper", true, false) as TextureRect
	if wallpaper == null or wallpaper.texture == null:
		_fail("The home screen did not reuse the selected bundled wallpaper.")
		return
	if home_screen.find_child("HomeScreenClock", true, false) == null or home_screen.find_child("HomeScreenDate", true, false) == null:
		_fail("The home screen is missing its live clock or date widget.")
		return
	if home_screen.find_child("HomeScreenSearchWidget", true, false) == null:
		_fail("The One UI search widget is missing.")
		return

	var home_grid := home_screen.find_child("HomeScreenAppGrid", true, false) as GridContainer
	if home_grid == null or home_grid.get_child_count() != 16:
		_fail("The first home page must display a complete four-by-four app grid.")
		return
	if not _grid_is_horizontally_centered(home_grid):
		_fail("The home-screen app grid is horizontally shifted instead of centered.")
		return
	var page_icons := home_grid.find_children("*", "TextureRect", true, false)
	if page_icons.size() != 16:
		_fail("The visible home page must expose sixteen app icons; found %d." % page_icons.size())
		return
	for icon_node in page_icons:
		var icon := icon_node as TextureRect
		if icon == null or icon.texture == null:
			var icon_name := "unknown"
			if icon != null:
				icon_name = str(icon.name)
			_fail("A home-page app icon failed to load: " + icon_name)
			return

	var dock := home_screen.find_child("HomeScreenDock", true, false) as PanelContainer
	var dock_row: HBoxContainer = null
	if dock != null:
		dock_row = dock.find_child("HomeScreenDockApps", true, false) as HBoxContainer
	if dock_row == null or dock_row.get_child_count() != 4:
		_fail("The home screen dock must expose four apps.")
		return
	for tile in dock_row.get_children():
		var dock_icon: TextureRect = null
		if tile.get_child_count() > 0:
			dock_icon = tile.get_child(0) as TextureRect
		if dock_icon == null or dock_icon.texture == null:
			_fail("A dock app icon failed to load.")
			return

	if int(home_screen.call("get_loaded_app_count")) != AppIconLibrary.EXPECTED_APP_COUNT:
		_fail("The app drawer did not load all 50 entries from the Papirus icon manifest.")
		return
	if int(home_screen.call("get_home_page_count")) != 2 or int(home_screen.call("get_home_icon_count")) != 36:
		_fail("The launcher home pages and dock do not expose the expected curated app selection.")
		return
	if int(home_screen.call("get_status_bar_icon_count")) != 4:
		_fail("The One UI status bar did not render its signal, Wi-Fi, Bluetooth and battery assets.")
		return

	if not bool(home_screen.call("set_status_bar_style", "quiet_minimal")):
		_fail("The home-screen status bar rejected a valid shared status-bar preset.")
		return
	if str(home_screen.call("get_status_bar_style_id")) != "quiet_minimal" or int(home_screen.call("get_status_bar_icon_count")) != 2:
		_fail("Changing the status-bar preset did not update the home screen.")
		return

	if not bool(home_screen.call("move_page", 1)) or int(home_screen.call("get_home_page_index")) != 1:
		_fail("A left swipe could not move to the second home page.")
		return
	if not bool(home_screen.call("move_page", -1)) or int(home_screen.call("get_home_page_index")) != 0:
		_fail("A right swipe could not return to the first home page.")
		return
	home_screen.call("open_app_drawer")
	await process_frame
	if not bool(home_screen.call("is_app_drawer_visible")) or int(home_screen.call("get_app_drawer_result_count")) != AppIconLibrary.EXPECTED_APP_COUNT:
		_fail("The swipe-up app drawer did not expose all 50 Papirus apps.")
		return
	if int(home_screen.call("get_app_drawer_loaded_icon_count")) != 200:
		_fail("The app drawer did not render all 50 Papirus SVG textures.")
		return
	var drawer_grid := home_screen.find_child("AppDrawerIconGrid", true, false) as GridContainer
	if not _grid_is_horizontally_centered(drawer_grid):
		_fail("The app-drawer icon grid is horizontally shifted instead of centered.")
		return
	home_screen.call("set_app_search_query", "spotify")
	if int(home_screen.call("get_app_drawer_result_count")) != 1:
		_fail("The app drawer search did not filter the app manifest correctly.")
		return
	home_screen.call("close_app_drawer")
	if bool(home_screen.call("is_app_drawer_visible")):
		_fail("The app drawer did not close cleanly.")

	home_screen.queue_free()
	lock_screen.queue_free()
	await process_frame
	print("ONE_UI_HOME_SCREEN_SMOKE_TEST: PASS")
	quit()


func _grid_is_horizontally_centered(grid: GridContainer) -> bool:
	if grid == null or grid.get_child_count() < grid.columns or grid.columns < 2:
		return false
	var first_tile := grid.get_child(0) as Control
	var last_tile := grid.get_child(grid.columns - 1) as Control
	if first_tile == null or last_tile == null:
		return false
	var grid_center_x := grid.get_global_rect().get_center().x
	var row_center_x := (first_tile.get_global_rect().get_center().x + last_tile.get_global_rect().get_center().x) * 0.5
	return absf(row_center_x - grid_center_x) <= 2.0


func _fail(message: String) -> void:
	push_error(message)
	print("ONE_UI_HOME_SCREEN_SMOKE_TEST: FAIL: " + message)
	quit(1)
