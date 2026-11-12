extends Node3D

signal back_requested

var progress_number: Label
var progress_bar: ProgressBar
var wizard_back_button: Button
var next_button: Button
var navigation_layer: CanvasLayer
var navigation_bar: HBoxContainer
var worksite_body: BoxContainer
var preview_region: Control
var selection_panel: PanelContainer
var configuration_region: Control
var screen_frame: PanelContainer

class GlassArrowButton extends Button:
	var points_right := true

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		var fill := Color(0.28, 0.20, 0.11, 0.96) if is_hovered() else Color(0.10, 0.11, 0.12, 0.92)
		if is_pressed():
			fill = Color(0.16, 0.11, 0.06, 0.98)
		draw_circle(centre + Vector2(0, 2), radius + 1.0, Color(0, 0, 0, 0.42))
		draw_circle(centre, radius, fill)
		draw_arc(centre, radius - 1.0, PI * 1.08, PI * 1.92, 48, Color(0.94, 0.91, 0.84, 0.78), 1.5, true)
		draw_arc(centre, radius - 1.5, -PI * 0.08, PI * 0.88, 48, Color(0.79, 0.61, 0.35, 0.36), 1.0, true)
		var direction := 1.0 if points_right else -1.0
		var tip := centre + Vector2(direction * 7.0, 0)
		var upper := centre + Vector2(-direction * 4.5, -7.0)
		var lower := centre + Vector2(-direction * 4.5, 7.0)
		draw_line(upper, tip, Color("#F2EDE4"), 2.8, true)
		draw_line(tip, lower, Color("#F2EDE4"), 2.8, true)
		draw_line(centre + Vector2(-direction * 5.0, 0), centre + Vector2(direction * 6.0, 0), Color("#F2EDE4"), 2.8, true)


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OSCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	var root := Control.new()
	root.name = "OSWorksiteRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)
	root.resized.connect(_apply_responsive_layout)

	var backdrop := ColorRect.new()
	backdrop.name = "OSWorksiteBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#292B2D")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.name = "OSWorksiteLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 20
	layout.offset_right = -20
	layout.offset_top = 12
	layout.offset_bottom = -12
	layout.add_theme_constant_override("separation", 10)
	root.add_child(layout)

	var top_bar := HBoxContainer.new()
	top_bar.name = "OSWorksiteTopBar"
	top_bar.custom_minimum_size.y = 48.0
	top_bar.add_theme_constant_override("separation", 12)
	layout.add_child(top_bar)

	var back_button := Button.new()
	back_button.name = "OSWorksiteBackButton"
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(82, 48)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button)
	back_button.pressed.connect(func(): back_requested.emit())
	top_bar.add_child(back_button)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var progress := VBoxContainer.new()
	progress.name = "OSWorksiteProgress"
	progress.custom_minimum_size = Vector2(150, 38)
	progress.add_theme_constant_override("separation", 4)
	top_bar.add_child(progress)

	progress_number = _label("STEP 1 / 1", 11, Color("#E5E0D6"))
	progress_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

	progress_bar = ProgressBar.new()
	progress_bar.name = "OSWizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = 1
	progress_bar.value = 1
	progress_bar.show_percentage = false
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("#C58A3A")
	progress_fill.set_corner_radius_all(4)
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color("#292D2F")
	progress_track.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_bar.add_theme_stylebox_override("background", progress_track)
	progress.add_child(progress_bar)

	worksite_body = BoxContainer.new()
	worksite_body.name = "OSWorksiteMainContent"
	worksite_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worksite_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worksite_body.add_theme_constant_override("separation", 0)
	layout.add_child(worksite_body)

	preview_region = Control.new()
	preview_region.name = "OSScreenPreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.12
	worksite_body.add_child(preview_region)

	var screen_center := CenterContainer.new()
	screen_center.name = "OSScreenCenter"
	screen_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_region.add_child(screen_center)

	screen_frame = PanelContainer.new()
	screen_frame.name = "OSPortraitScreenFrame"
	screen_frame.custom_minimum_size = Vector2(132, 264)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#090A0C")
	frame_style.border_color = Color("#77736D")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(22)
	frame_style.content_margin_left = 7
	frame_style.content_margin_right = 7
	frame_style.content_margin_top = 7
	frame_style.content_margin_bottom = 7
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame_style.shadow_size = 16
	frame_style.shadow_offset = Vector2(0, 5)
	screen_frame.add_theme_stylebox_override("panel", frame_style)
	screen_center.add_child(screen_frame)

	var screen_glass := PanelContainer.new()
	screen_glass.name = "OSPortraitScreen"
	var glass_style := StyleBoxFlat.new()
	glass_style.bg_color = Color("#030405")
	glass_style.set_corner_radius_all(16)
	screen_glass.add_theme_stylebox_override("panel", glass_style)
	screen_glass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_glass.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_frame.add_child(screen_glass)

	_build_home_screen_preview(screen_glass)

	var right_region := MarginContainer.new()
	configuration_region = right_region
	right_region.name = "OSConfigurationRegion"
	right_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_region.size_flags_stretch_ratio = 0.88
	right_region.add_theme_constant_override("margin_left", 22)
	right_region.add_theme_constant_override("margin_right", 18)
	right_region.add_theme_constant_override("margin_top", 20)
	right_region.add_theme_constant_override("margin_bottom", 20)
	worksite_body.add_child(right_region)

	selection_panel = PanelContainer.new()
	selection_panel.name = "OSConfigurationPanel"
	selection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var blank_panel_style := StyleBoxFlat.new()
	blank_panel_style.bg_color = Color(0.035, 0.039, 0.043, 0.20)
	blank_panel_style.border_color = Color(0.70, 0.62, 0.48, 0.12)
	blank_panel_style.set_border_width_all(1)
	blank_panel_style.set_corner_radius_all(14)
	selection_panel.add_theme_stylebox_override("panel", blank_panel_style)
	right_region.add_child(selection_panel)

	var bottom_bar_space := Control.new()
	bottom_bar_space.name = "OSWorksiteBottomBarSpace"
	bottom_bar_space.custom_minimum_size = Vector2(0, 62.0)
	layout.add_child(bottom_bar_space)

	navigation_layer = CanvasLayer.new()
	navigation_layer.name = "OSWorksiteNavigationOverlay"
	navigation_layer.layer = 127
	add_child(navigation_layer)

	var navigation_root := Control.new()
	navigation_root.name = "OSWorksiteNavigationRoot"
	navigation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigation_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_layer.add_child(navigation_root)

	navigation_bar = HBoxContainer.new()
	navigation_bar.name = "OSWorksiteBottomBar"
	navigation_bar.anchor_left = 0.0
	navigation_bar.anchor_right = 1.0
	navigation_bar.anchor_top = 1.0
	navigation_bar.anchor_bottom = 1.0
	navigation_bar.offset_left = 20.0
	navigation_bar.offset_right = -20.0
	navigation_bar.offset_top = -74.0
	navigation_bar.offset_bottom = -12.0
	navigation_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	navigation_bar.z_index = 1000
	navigation_bar.z_as_relative = false
	navigation_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation_bar.add_theme_constant_override("separation", 18)
	navigation_root.add_child(navigation_bar)

	wizard_back_button = GlassArrowButton.new()
	wizard_back_button.name = "OSWizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	navigation_bar.add_child(wizard_back_button)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_bar.add_child(bottom_spacer)

	next_button = GlassArrowButton.new()
	next_button.name = "OSNextStepIconButton"
	next_button.points_right = true
	next_button.pressed.connect(_on_next_pressed)
	navigation_bar.add_child(next_button)

	_apply_responsive_layout()
	_keep_step_navigation_active()


func _build_home_screen_preview(screen: PanelContainer) -> void:
	var screen_content := VBoxContainer.new()
	screen_content.name = "OSHomeScreenContent"
	screen_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_content.add_theme_constant_override("separation", 5)
	screen.add_child(screen_content)

	var status_row := HBoxContainer.new()
	status_row.name = "HomeStatusBar"
	status_row.custom_minimum_size.y = 13
	screen_content.add_child(status_row)
	var time_label := _label("9:41", 8, Color("#F4F5F7"))
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(time_label)
	var status_icons := _label("▮  Wi-Fi  ▰", 7, Color("#E9EDF2"))
	status_icons.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(status_icons)

	var top_widget := PanelContainer.new()
	top_widget.name = "HomeScreenFeaturedWidget"
	top_widget.custom_minimum_size.y = 48
	var widget_style := StyleBoxFlat.new()
	widget_style.bg_color = Color(0.10, 0.16, 0.25, 0.88)
	widget_style.set_corner_radius_all(10)
	widget_style.content_margin_left = 8
	widget_style.content_margin_right = 8
	widget_style.content_margin_top = 5
	widget_style.content_margin_bottom = 5
	top_widget.add_theme_stylebox_override("panel", widget_style)
	screen_content.add_child(top_widget)
	var widget_content := VBoxContainer.new()
	widget_content.add_theme_constant_override("separation", 0)
	top_widget.add_child(widget_content)
	var greeting := _label("MONDAY, 12 NOVEMBER", 6, Color("#B8C7D9"))
	widget_content.add_child(greeting)
	var widget_main := HBoxContainer.new()
	widget_content.add_child(widget_main)
	var clock := _label("09:41", 21, Color("#FFFFFF"))
	clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget_main.add_child(clock)
	var weather := _label("☀  27°\nLAGOS", 7, Color("#E8D9B8"))
	weather.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weather.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	widget_main.add_child(weather)

	var search := PanelContainer.new()
	search.name = "HomeSearchBar"
	search.custom_minimum_size.y = 19
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color(0.91, 0.94, 0.98, 0.14)
	search_style.set_corner_radius_all(10)
	search_style.content_margin_left = 8
	search_style.content_margin_right = 8
	search_style.content_margin_top = 2
	search_style.content_margin_bottom = 2
	search.add_theme_stylebox_override("panel", search_style)
	screen_content.add_child(search)
	var search_label := _label("⌕   Search apps", 7, Color("#D6DEE8"))
	search.add_child(search_label)

	var app_grid := GridContainer.new()
	app_grid.name = "HomeAppGrid"
	app_grid.columns = 4
	app_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_grid.add_theme_constant_override("h_separation", 2)
	app_grid.add_theme_constant_override("v_separation", 3)
	screen_content.add_child(app_grid)
	var apps := [
		["Phone", "☎", "#3C9B82"],
		["Messages", "✉", "#438DCE"],
		["Camera", "◉", "#68778D"],
		["Gallery", "▧", "#C57D57"],
		["Music", "♫", "#9B6FC0"],
		["Browser", "◎", "#4D9AA0"],
		["Calendar", "▦", "#B66D6D"],
		["Tools", "▤", "#71879A"]
	]
	for app in apps:
		app_grid.add_child(_make_home_app_icon(str(app[0]), str(app[1]), Color(str(app[2]))))
	app_grid.add_child(_make_home_app_icon("Social", "▣", Color("#527D9B")))
	app_grid.add_child(_make_home_app_icon("Games", "▦", Color("#9A7954"), true))
	app_grid.add_child(_make_home_app_icon("Work", "▣", Color("#617F70"), true))
	app_grid.add_child(_make_home_app_icon("Travel", "◇", Color("#7A719B")))

	var page_row := HBoxContainer.new()
	page_row.name = "HomePageIndicator"
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page_row.custom_minimum_size.y = 7
	screen_content.add_child(page_row)
	var page_dots := _label("•  ●  •", 8, Color("#E7EAF0"))
	page_row.add_child(page_dots)

	var dock := PanelContainer.new()
	dock.name = "HomeAppDock"
	dock.custom_minimum_size.y = 35
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = Color(0.86, 0.91, 0.98, 0.16)
	dock_style.set_corner_radius_all(12)
	dock_style.content_margin_left = 5
	dock_style.content_margin_right = 5
	dock_style.content_margin_top = 3
	dock_style.content_margin_bottom = 3
	dock.add_theme_stylebox_override("panel", dock_style)
	screen_content.add_child(dock)
	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 8)
	dock.add_child(dock_row)
	for item in [["☎", "#3C9B82"], ["✉", "#438DCE"], ["◎", "#4D9AA0"], ["◉", "#68778D"]]:
		var dock_icon := Label.new()
		dock_icon.text = str(item[0])
		dock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dock_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dock_icon.custom_minimum_size = Vector2(22, 24)
		dock_icon.add_theme_font_size_override("font_size", 13)
		dock_icon.add_theme_color_override("font_color", Color("#FFFFFF"))
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(str(item[1]))
		icon_style.set_corner_radius_all(7)
		dock_icon.add_theme_stylebox_override("normal", icon_style)
		dock_row.add_child(dock_icon)


func _make_home_app_icon(app_name: String, glyph: String, tint: Color, is_folder: bool = false) -> Control:
	var item := VBoxContainer.new()
	item.name = "HomeApp_" + app_name.replace(" ", "")
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 1)
	var icon_tile := PanelContainer.new()
	icon_tile.name = "IconTile"
	icon_tile.custom_minimum_size = Vector2(23, 23)
	icon_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = tint
	tile_style.set_corner_radius_all(7)
	tile_style.content_margin_left = 2
	tile_style.content_margin_right = 2
	tile_style.content_margin_top = 1
	tile_style.content_margin_bottom = 1
	icon_tile.add_theme_stylebox_override("panel", tile_style)
	item.add_child(icon_tile)
	var glyph_label := _label(glyph, 13, Color("#FFFFFF"))
	glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_tile.add_child(glyph_label)
	var name_label := _label(app_name, 6, Color("#F0F2F5"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	item.add_child(name_label)
	return item


func _apply_responsive_layout() -> void:
	if not is_instance_valid(worksite_body) or not is_instance_valid(preview_region) or not is_instance_valid(selection_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var is_wide := viewport_size.x >= viewport_size.y and viewport_size.x >= 700.0
	worksite_body.vertical = not is_wide
	var screen_height: float
	if is_wide:
		preview_region.size_flags_stretch_ratio = 1.12
		configuration_region.size_flags_stretch_ratio = 0.88
		preview_region.custom_minimum_size = Vector2(0, 0)
		screen_height = clampf(viewport_size.y - 160.0, 180.0, 520.0)
		screen_frame.custom_minimum_size = Vector2(screen_height * 0.48, screen_height)
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		configuration_region.size_flags_stretch_ratio = 1.18
		preview_region.custom_minimum_size = Vector2(0, maxf(140.0, viewport_size.y * 0.24))
		screen_height = clampf(viewport_size.y * 0.30, 150.0, 280.0)
		screen_frame.custom_minimum_size = Vector2(screen_height * 0.48, screen_height)


func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	var font := load("res://assets/fonts/STIXTwoText[wght].ttf") as Font
	if is_instance_valid(font):
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#17191B")
	normal.border_color = Color("#8D7048")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#30271D")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#211B14")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_font_size_override("font_size", 13)


func _keep_step_navigation_active() -> void:
	if is_instance_valid(navigation_layer):
		navigation_layer.layer = 127
	if is_instance_valid(navigation_bar):
		navigation_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		navigation_bar.z_index = 1000
		navigation_bar.z_as_relative = false
	for button in [wizard_back_button, next_button]:
		if is_instance_valid(button):
			button.disabled = false
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.modulate.a = 1.0


func _on_wizard_back_pressed() -> void:
	_keep_step_navigation_active()
	# Step 1 is the first OS wizard page; there is no earlier step yet.


func _on_next_pressed() -> void:
	_keep_step_navigation_active()
	# Additional OS wizard steps will be introduced after the structure is approved.
