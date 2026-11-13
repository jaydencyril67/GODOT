extends Control

signal app_opened(app_name: String)

var configuration: Dictionary = {}
var active_component := "home_screen"
var page_container: VBoxContainer
var status_label: Label
var _palette: Dictionary = {}
var _style: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if configuration.is_empty():
		configuration = ProceduralOSEngine.generate_os()
	_build_shell()

func configure_os(os_configuration: Dictionary, component_id: String = "home_screen") -> void:
	configuration = os_configuration.duplicate(true)
	active_component = component_id
	if is_inside_tree():
		_build_shell()

func set_component_view(component_id: String) -> void:
	active_component = component_id
	if is_inside_tree():
		_build_shell()

func update_configuration(os_configuration: Dictionary) -> void:
	configuration = os_configuration.duplicate(true)
	if is_inside_tree():
		_build_shell()

func _build_shell() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_style = configuration.get("style", {})
	_palette = _style.get("palette", {"background":"#101318","surface":"#202833","accent":"#72B7C8","text":"#F2F4F5","muted":"#A6B0B9"})
	var background := ColorRect.new()
	background.name = "OSWallpaperBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(str(_palette.get("background", "#101318")))
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var wallpaper_path := str(_style.get("wallpaper", ""))
	if ResourceLoader.exists(wallpaper_path):
		var wallpaper := TextureRect.new()
		wallpaper.name = "OSWallpaper"
		wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wallpaper.texture = load(wallpaper_path) as Texture2D
		wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		wallpaper.modulate = Color(0.68, 0.72, 0.78, 0.82)
		wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wallpaper)
	var tint := ColorRect.new()
	tint.name = "OSWallpaperTint"
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(Color(str(_palette.get("background", "#101318"))), 0.30)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	var shell := VBoxContainer.new()
	shell.name = "OSSimulatorLayout"
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 3)
	shell.add_theme_constant_override("margin_left", 7)
	shell.add_theme_constant_override("margin_right", 7)
	shell.add_theme_constant_override("margin_top", 5)
	shell.add_theme_constant_override("margin_bottom", 5)
	add_child(shell)
	var status := HBoxContainer.new()
	status.name = "OSStatusBar"
	status.custom_minimum_size.y = 12
	shell.add_child(status)
	var clock := _label("9:41", 8, _text_color())
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(clock)
	status_label = _label("◆  ▮▮  ▰", 7, _text_color())
	status.add_child(status_label)
	var title := _label(_component_title(active_component), 8, _text_color())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 13
	shell.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "OSComponentViewport"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	page_container = VBoxContainer.new()
	page_container.name = "OSComponentContent"
	page_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_container.add_theme_constant_override("separation", 5)
	scroll.add_child(page_container)
	_build_component(active_component)
	var footer := CenterContainer.new()
	footer.custom_minimum_size.y = 9
	shell.add_child(footer)
	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(28, 3)
	indicator.color = _text_color()
	footer.add_child(indicator)

func _build_component(component_id: String) -> void:
	var component_data: Dictionary = configuration.get("components", {}).get(component_id, {})
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
		_:
			page_container.add_child(_label("OS component", 10, _text_color()))

func _build_home_screen(data: Dictionary) -> void:
	if bool(data.get("show_clock_widget", true)):
		var clock := _label("09:41", 25, _text_color())
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_container.add_child(clock)
		var date := _label("FRIDAY  ·  NOVEMBER 13", 7, _muted_color())
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_container.add_child(date)
	if bool(data.get("show_search", true)):
		page_container.add_child(_surface_label("⌕   Search", 8))
	_add_app_grid(int(data.get("columns", 4)), 12, true)
	page_container.add_child(_surface_label("☎       ✉       ◎       ◉", 12))

func _build_lock_screen(data: Dictionary) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 25
	page_container.add_child(spacer)
	var clock := _label("09:41", 34 if data.get("clock_style") == "bold" else 27, _text_color())
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_container.add_child(clock)
	var date := _label("FRIDAY, NOVEMBER 13", 8, _muted_color())
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_container.add_child(date)
	var middle := Control.new()
	middle.custom_minimum_size.y = 20
	page_container.add_child(middle)
	if bool(data.get("show_notifications", true)):
		page_container.add_child(_surface_label("MESSAGES     New message", 8))
		page_container.add_child(_surface_label("CALENDAR      Upcoming event", 8))
	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_container.add_child(bottom)
	page_container.add_child(_surface_label("◉                                  ▣", 12))

func _build_icon_gallery(data: Dictionary) -> void:
	var shape := str(data.get("shape", "rounded"))
	var columns := 3
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 7)
	page_container.add_child(grid)
	for app in ProceduralOSEngine.APP_DEFINITIONS:
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 2)
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.text = str(app["glyph"])
		icon.add_theme_font_size_override("font_size", 15)
		_style_icon_button(icon, _app_color(str(app["name"])), shape)
		grid.add_child(tile)
		tile.add_child(icon)
		var label := _label(str(app["name"]), 6, _text_color())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if bool(data.get("label_visibility", true)):
			tile.add_child(label)

func _build_theme_preview(data: Dictionary) -> void:
	page_container.add_child(_label(str(data.get("palette", {}).get("name", "Theme")) + " identity", 14, _text_color()))
	page_container.add_child(_surface_label("Primary surface · sample card", 8))
	for key in ["background", "surface", "accent", "text"]:
		var swatch := HBoxContainer.new()
		var color_box := ColorRect.new()
		color_box.custom_minimum_size = Vector2(28, 18)
		color_box.color = Color(str(_palette.get(key, "#FFFFFF")))
		swatch.add_child(color_box)
		swatch.add_child(_label(key.capitalize(), 8, _text_color()))
		page_container.add_child(swatch)
	var action := Button.new()
	action.text = "Sample action"
	action.custom_minimum_size.y = 25
	_style_action_button(action)
	page_container.add_child(action)

func _build_wallpaper_preview(data: Dictionary) -> void:
	page_container.add_child(_label("Wallpaper selection", 11, _text_color()))
	page_container.add_child(_surface_label(str(data.get("treatment", "natural")).replace("_", " ").capitalize(), 8))
	page_container.add_child(_label("The selected wallpaper is applied consistently to the home and lock screens.", 7, _muted_color()))

func _build_animation_preview(data: Dictionary) -> void:
	page_container.add_child(_label(str(data.get("style", "fade")).capitalize() + " transition", 11, _text_color()))
	var demo := PanelContainer.new()
	demo.name = "AnimationDemoSurface"
	demo.custom_minimum_size = Vector2(0, 55)
	_style_surface(demo)
	demo.add_child(_label("OS WINDOW", 9, _text_color()))
	page_container.add_child(demo)
	var play := Button.new()
	play.text = "PLAY ANIMATION"
	play.custom_minimum_size.y = 26
	_style_action_button(play)
	play.pressed.connect(func():
		var tween := create_tween()
		demo.scale = Vector2(0.88, 0.88)
		demo.modulate.a = 0.45
		tween.set_parallel(true)
		tween.tween_property(demo, "scale", Vector2.ONE, float(data.get("duration", 0.22))).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(demo, "modulate:a", 1.0, float(data.get("duration", 0.22)))
	)
	page_container.add_child(play)

func _build_control_center(_data: Dictionary) -> void:
	page_container.add_child(_label("Quick controls", 11, _text_color()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	page_container.add_child(grid)
	for item in ["Wi-Fi", "Bluetooth", "Airplane", "Flashlight", "Focus", "Battery"]:
		var toggle := Button.new()
		toggle.text = item
		toggle.toggle_mode = true
		toggle.button_pressed = item in ["Wi-Fi", "Bluetooth"]
		toggle.custom_minimum_size = Vector2(0, 29)
		_style_action_button(toggle)
		grid.add_child(toggle)
	page_container.add_child(_label("Brightness", 8, _muted_color()))
	var brightness := HSlider.new()
	brightness.min_value = 0
	brightness.max_value = 100
	brightness.value = 72
	page_container.add_child(brightness)
	page_container.add_child(_label("Volume", 8, _muted_color()))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.value = 58
	page_container.add_child(volume)

func _build_notifications(data: Dictionary) -> void:
	page_container.add_child(_label("Notifications", 13, _text_color()))
	for item in ["Messages  ·  Just now", "Calendar  ·  10 minutes ago", "System update  ·  Earlier"]:
		var card := PanelContainer.new()
		_style_surface(card)
		var text := _label(item + "\nYou have an update waiting.", 7, _text_color())
		card.add_child(text)
		page_container.add_child(card)
	if bool(data.get("translucent", true)):
		page_container.add_child(_label("Translucent notification surfaces", 7, _muted_color()))

func _build_navigation_preview(data: Dictionary) -> void:
	page_container.add_child(_label("Navigation mode", 11, _text_color()))
	page_container.add_child(_surface_label(str(data.get("mode", "gesture")).replace("_", " ").capitalize(), 9))
	var back := Button.new()
	back.text = "‹       BACK"
	back.custom_minimum_size.y = 30
	_style_action_button(back)
	back.pressed.connect(func(): status_label.text = "Back gesture preview" if is_instance_valid(status_label) else "")
	page_container.add_child(back)
	page_container.add_child(_surface_label("━━━━", 9))

func _build_app_drawer(_data: Dictionary) -> void:
	page_container.add_child(_surface_label("⌕   Search applications", 8))
	_add_app_grid(3, 12, true)

func _build_recent_apps(data: Dictionary) -> void:
	page_container.add_child(_label("Recent applications", 11, _text_color()))
	for app in ["Settings", "Camera", "Messages"]:
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 42
		_style_surface(card)
		card.add_child(_label(app + "  ·  App preview", 8, _text_color()))
		page_container.add_child(card)
	if bool(data.get("show_clear_all", true)):
		var clear := Button.new()
		clear.text = "CLEAR ALL"
		clear.custom_minimum_size.y = 25
		_style_action_button(clear)
		clear.pressed.connect(func():
			for child in page_container.get_children():
				if child is PanelContainer:
					child.queue_free()
		)
		page_container.add_child(clear)

func _build_system_ui(data: Dictionary) -> void:
	page_container.add_child(_label("System indicators", 11, _text_color()))
	page_container.add_child(_surface_label("9:41     ◈  ▮▮▮  " + ("100%" if data.get("battery_style") == "percentage" else "▰"), 9))
	page_container.add_child(_surface_label("Status bar · " + str(data.get("status_style", "minimal")), 8))
	page_container.add_child(_surface_label("Battery · " + str(data.get("battery_style", "icon")), 8))
	page_container.add_child(_surface_label("Signal · Wi-Fi · Bluetooth", 8))

func _add_app_grid(columns: int, app_count: int, show_labels: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = clampi(columns, 3, 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 3)
	page_container.add_child(grid)
	for index in range(mini(app_count, ProceduralOSEngine.APP_DEFINITIONS.size())):
		var app: Dictionary = ProceduralOSEngine.APP_DEFINITIONS[index]
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 1)
		var button := Button.new()
		button.text = str(app["glyph"])
		button.custom_minimum_size = Vector2(24, 25)
		button.add_theme_font_size_override("font_size", 12)
		_style_icon_button(button, _app_color(str(app["name"])), str(configuration.get("components", {}).get("app_icons", {}).get("shape", _style.get("icon_shape", "rounded"))))
		button.pressed.connect(_on_app_pressed.bind(str(app["name"])))
		tile.add_child(button)
		if show_labels:
			var label := _label(str(app["name"]), 5, _text_color())
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.add_child(label)
		grid.add_child(tile)

func _on_app_pressed(app_name: String) -> void:
	app_opened.emit(app_name)
	if is_instance_valid(status_label):
		status_label.text = app_name + " preview"

func _component_title(component_id: String) -> String:
	for component in ProceduralOSEngine.COMPONENTS:
		if component["id"] == component_id:
			return str(component["title"]).to_upper()
	return "OPERATING SYSTEM"

func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _surface_label(caption: String, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 23
	_style_surface(panel)
	var label := _label(caption, font_size, _text_color())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func _style_surface(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(str(_palette.get("surface", "#202833")), 0.88)
	style.border_color = Color(_text_color(), 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 10)))
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

func _style_action_button(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(str(_palette.get("surface", "#202833")))
	style.border_color = Color(str(_palette.get("accent", "#72B7C8")), 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(_style.get("corner_radius", 10)))
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_color_override("font_color", _text_color())
	button.add_theme_font_size_override("font_size", 7)

func _style_icon_button(button: Button, tint: Color, shape: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	var radius := 0 if shape == "square" else (5 if shape == "soft_square" else 10)
	style.set_corner_radius_all(radius)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE

func _app_color(app_name: String) -> Color:
	var colors := ["#638B72", "#597FAD", "#777D85", "#9470A7", "#4F8990", "#A56D6D", "#A77D59", "#777D83"]
	var index: int = abs(app_name.hash()) % colors.size()
	return Color(colors[index])

func _text_color() -> Color:
	return Color(str(_palette.get("text", "#F2F4F5")))

func _muted_color() -> Color:
	return Color(str(_palette.get("muted", "#A6B0B9")))
