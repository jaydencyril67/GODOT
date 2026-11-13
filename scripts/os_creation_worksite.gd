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
var home_preview_screen: PanelContainer
var home_generation := 1
var home_generation_status: Label

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


class Android10WorkspaceArt extends Control:
	var ui_font: Font

	func _ready() -> void:
		ui_font = ThemeDB.fallback_font
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(320.0, 420.0))

		# A blue, distant shoreline/water wallpaper treatment matching the G1 reference.
		for y in range(0, 420, 3):
			var band: Color
			if y < 126:
				band = Color("#65B7E7").lerp(Color("#B8E3F2"), float(y) / 126.0)
			elif y < 158:
				band = Color("#B8E3F2").lerp(Color("#DCEBF0"), float(y - 126) / 32.0)
			elif y < 188:
				band = Color("#B7D6E4").lerp(Color("#3D9CD2"), float(y - 158) / 30.0)
			else:
				band = Color("#1687CC").lerp(Color("#064A9F"), float(y - 188) / 232.0)
			draw_rect(Rect2(0, y, 320, 3), band)

		# Distant pale shoreline and the soft blue land forms visible behind the icons.
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 145), Vector2(28, 140), Vector2(54, 143), Vector2(84, 136),
			Vector2(108, 141), Vector2(139, 135), Vector2(166, 142), Vector2(194, 137),
			Vector2(221, 143), Vector2(248, 137), Vector2(280, 141), Vector2(320, 136),
			Vector2(320, 170), Vector2(0, 170)
		]), Color("#D5E7EC"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 154), Vector2(48, 150), Vector2(82, 155), Vector2(118, 149),
			Vector2(151, 155), Vector2(188, 151), Vector2(224, 157), Vector2(260, 151),
			Vector2(290, 156), Vector2(320, 150), Vector2(320, 178), Vector2(0, 178)
		]), Color("#8ABDD5"))
		draw_line(Vector2(0, 179), Vector2(320, 179), Color(0.80, 0.91, 0.96, 0.58), 1.0)

		# Subtle water highlights; the original wallpaper stays blue and low-contrast.
		for i in range(13):
			var y := 194.0 + float(i) * 15.0
			var left := float((i * 37) % 74)
			var line_width := 42.0 + float((i * 19) % 66)
			draw_line(Vector2(left, y), Vector2(minf(318.0, left + line_width), y), Color(0.72, 0.89, 0.98, 0.17), 1.0, true)
			draw_line(Vector2(190.0 + float((i * 23) % 74), y + 5.0), Vector2(270.0 + float((i * 11) % 45), y + 5.0), Color(0.02, 0.30, 0.62, 0.12), 1.0, true)

		# Six original-era shortcuts, with individual illustrated artwork rather than modern icon tiles.
		_draw_shortcut(Vector2(35, 202), "Messaging", 0)
		_draw_shortcut(Vector2(285, 202), "Market", 1)
		_draw_shortcut(Vector2(37, 300), "Dialer", 2)
		_draw_shortcut(Vector2(119, 300), "Contacts", 3)
		_draw_shortcut(Vector2(201, 300), "Browser", 4)
		_draw_shortcut(Vector2(283, 300), "Google Maps", 5)

		# The visible pull-tab for All Apps is the defining bottom control, not a dock.
		var tab := Rect2(119, 383, 82, 30)
		draw_rect(Rect2(tab.position + Vector2(0, 2), tab.size), Color(0.02, 0.10, 0.24, 0.34))
		draw_rect(tab, Color("#8ABBDD"))
		draw_rect(Rect2(120, 384, 80, 28), Color("#B7D9EE"))
		draw_line(Vector2(121, 385), Vector2(199, 385), Color("#E0F1FA"), 1.0)
		draw_line(Vector2(121, 410), Vector2(199, 410), Color("#477CA8"), 1.0)
		draw_circle(Vector2(160, 398), 10.0, Color("#6FA6CC"))
		draw_arc(Vector2(160, 398), 9.0, 0.0, TAU, 32, Color("#E4F3FA"), 1.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(160, 392), Vector2(154, 400), Vector2(158, 400),
			Vector2(158, 404), Vector2(162, 404), Vector2(162, 400),
			Vector2(166, 400)
		]), Color("#F7FCFF"))

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_shortcut(center: Vector2, title: String, kind: int) -> void:
		var icon_rect := Rect2(center - Vector2(17, 18), Vector2(34, 34))
		draw_rect(Rect2(icon_rect.position + Vector2(1, 2), icon_rect.size), Color(0.02, 0.08, 0.18, 0.34))
		var base_colors := [
			Color("#C5E2EF"), Color("#D6E8D8"), Color("#2C78B5"),
			Color("#D5E1EA"), Color("#B8D9DE"), Color("#F1E5C2")
		]
		draw_rect(icon_rect, base_colors[kind])
		draw_rect(icon_rect, Color(0.92, 0.97, 1.0, 0.80), false, 1.0)
		draw_line(icon_rect.position + Vector2(1, 1), icon_rect.position + Vector2(32, 1), Color(1, 1, 1, 0.62), 1.0)

		match kind:
			0:
				# Messaging: an old-style blue message envelope.
				draw_rect(Rect2(center + Vector2(-12, -9), Vector2(24, 17)), Color("#4E91BE"))
				draw_rect(Rect2(center + Vector2(-10, -7), Vector2(20, 13)), Color("#EDF5F8"))
				draw_line(center + Vector2(-10, -7), center + Vector2(0, 1), Color("#4D8FB9"), 2.0, true)
				draw_line(center + Vector2(10, -7), center + Vector2(0, 1), Color("#4D8FB9"), 2.0, true)
				draw_line(center + Vector2(-10, 6), center + Vector2(-1, -1), Color("#77AAC7"), 1.0, true)
				draw_line(center + Vector2(10, 6), center + Vector2(1, -1), Color("#77AAC7"), 1.0, true)
			1:
				# Market: a pale green shopping bag with a small Android-era mascot.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-11, -7), center + Vector2(11, -7),
					center + Vector2(9, 11), center + Vector2(-9, 11)
				]), Color("#6CA77B"))
				draw_arc(center + Vector2(0, -7), 6.0, PI, TAU, 16, Color("#39784C"), 2.0, true)
				draw_circle(center, 4.2, Color("#D9F0D9"))
				draw_circle(center + Vector2(-1.5, -1), 0.8, Color("#48885B"))
				draw_circle(center + Vector2(1.5, -1), 0.8, Color("#48885B"))
				draw_line(center + Vector2(-2, 3), center + Vector2(2, 3), Color("#48885B"), 1.0)
			2:
				# Dialer: a light handset on a dark blue square.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-11, -9), center + Vector2(-7, -12),
					center + Vector2(-3, -7), center + Vector2(-6, -3),
					center + Vector2(4, 7), center + Vector2(8, 4),
					center + Vector2(12, 9), center + Vector2(8, 13),
					center + Vector2(2, 12), center + Vector2(-8, 2)
				]), Color("#EDF5FB"))
				draw_line(center + Vector2(-8, -9), center + Vector2(8, 9), Color("#9CC7DF"), 1.0, true)
			3:
				# Contacts: a small two-page address book and a profile silhouette.
				draw_rect(Rect2(center + Vector2(-12, -12), Vector2(24, 24)), Color("#9BAFBD"))
				draw_rect(Rect2(center + Vector2(-9, -10), Vector2(18, 20)), Color("#F5F7F8"))
				draw_rect(Rect2(center + Vector2(-9, -10), Vector2(4, 20)), Color("#557C9B"))
				draw_circle(center + Vector2(4, -3), 4.0, Color("#82A6BD"))
				draw_arc(center + Vector2(4, 7), 7.0, PI, TAU, 20, Color("#82A6BD"), 3.0, true)
			4:
				# Browser: a glossy blue-green globe.
				draw_circle(center, 12.0, Color("#347F9C"))
				draw_circle(center, 10.0, Color("#83C4C0"))
				draw_arc(center, 9.0, 0.0, TAU, 28, Color("#E1F3E9"), 1.2, true)
				draw_arc(center, 5.0, 0.0, TAU, 24, Color("#E1F3E9"), 1.0, true)
				draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color("#E1F3E9"), 1.0)
				draw_line(center + Vector2(-8, -5), center + Vector2(8, -5), Color("#E1F3E9"), 1.0)
				draw_line(center + Vector2(-8, 5), center + Vector2(8, 5), Color("#E1F3E9"), 1.0)
			5:
				# Maps: folded map panels with a location marker.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-12, -9), center + Vector2(-3, -12),
					center + Vector2(4, -8), center + Vector2(12, -11),
					center + Vector2(12, 10), center + Vector2(4, 12),
					center + Vector2(-3, 8), center + Vector2(-12, 11)
				]), Color("#F6F1DC"))
				draw_line(center + Vector2(-3, -11), center + Vector2(-3, 8), Color("#80AF91"), 2.0)
				draw_line(center + Vector2(4, -8), center + Vector2(4, 11), Color("#83A6C0"), 2.0)
				draw_circle(center + Vector2(2, -1), 5.0, Color("#D45B4E"))
				draw_circle(center + Vector2(2, -1), 1.8, Color("#FFF6E8"))

		var label_width := maxf(30.0, float(title.length()) * 5.3 + 8.0)
		var label_rect := Rect2(Vector2(center.x - label_width * 0.5, center.y + 18.0), Vector2(label_width, 14.0))
		draw_rect(label_rect, Color(0.02, 0.07, 0.16, 0.72))
		if is_instance_valid(ui_font):
			draw_string(ui_font, Vector2(label_rect.position.x, label_rect.position.y + 10.5), title, HORIZONTAL_ALIGNMENT_CENTER, label_width, 8, Color("#FFFFFF"))


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
	screen_frame.custom_minimum_size = Vector2(156, 312)
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

	home_preview_screen = screen_glass
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
	_build_home_generation_controls()

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
	if home_generation < 5:
		_build_legacy_home_screen_preview(screen, home_generation)
		return
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

	var app_grid := VBoxContainer.new()
	app_grid.name = "HomeAppGrid"
	app_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_grid.add_theme_constant_override("separation", 0)
	screen_content.add_child(app_grid)
	var apps := [
		["Phone", "☎", "#3C9B82"], ["Messages", "✉", "#438DCE"],
		["Camera", "◉", "#68778D"], ["Gallery", "▧", "#C57D57"],
		["Music", "♫", "#9B6FC0"], ["Browser", "◎", "#4D9AA0"],
		["Calendar", "▦", "#B66D6D"], ["Tools", "▤", "#71879A"],
		["Social", "▣", "#527D9B"], ["Games", "▦", "#9A7954"],
		["Work", "▣", "#617F70"], ["Travel", "◇", "#7A719B"]
	]
	var app_items: Array[Control] = []
	for app in apps:
		app_items.append(_make_home_app_icon(str(app[0]), str(app[1]), Color(str(app[2])), str(app[0]) in ["Games", "Work"]))
	for row_index in range(3):
		var app_row := HBoxContainer.new()
		app_row.name = "HomeAppRow_%d" % (row_index + 1)
		app_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		app_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_row.alignment = BoxContainer.ALIGNMENT_CENTER
		app_grid.add_child(app_row)
		for column_index in range(4):
			var app_slot := CenterContainer.new()
			app_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			app_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			app_row.add_child(app_slot)
			var app_item := app_items[row_index * 4 + column_index]
			app_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			app_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			app_slot.add_child(app_item)

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


func _build_home_generation_controls() -> void:
	var content := VBoxContainer.new()
	content.name = "HomeGenerationControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	selection_panel.add_child(content)

	var heading := _label("HOME SCREEN EVOLUTION", 17, Color("#F0E9DD"))
	content.add_child(heading)
	var description := _label("Choose a generation to preview how the operating system evolves.", 12, Color("#B8B1A6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	var stages := [
		["01  CLASSIC", "Early Android workspace, Google search, clock and simple shortcuts."],
		["02  CUSTOM", "A cleaner grid, fixed dock and basic folders."],
		["03  MODERN", "Rounded icons, a clock widget and richer layouts."],
		["04  INTELLIGENT", "Adaptive icons, search and flexible widgets."],
		["05  PREMIUM", "The full featured Home Screen preview already designed."]
	]
	for i in range(stages.size()):
		var stage_button := Button.new()
		stage_button.name = "HomeGeneration_%d" % (i + 1)
		stage_button.text = str(stages[i][0]) + "\n" + str(stages[i][1])
		stage_button.custom_minimum_size = Vector2(0, 72)
		stage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stage_button.focus_mode = Control.FOCUS_NONE
		stage_button.pressed.connect(_select_home_generation.bind(i + 1))
		_style_button(stage_button)
		content.add_child(stage_button)

	home_generation_status = _label("PREVIEWING GENERATION 01", 11, Color("#C58A3A"))
	content.add_child(home_generation_status)
	_update_home_generation_controls()


func _select_home_generation(generation: int) -> void:
	home_generation = clampi(generation, 1, 5)
	if is_instance_valid(home_preview_screen):
		for child in home_preview_screen.get_children():
			home_preview_screen.remove_child(child)
			child.free()
		_build_home_screen_preview(home_preview_screen)
	_update_home_generation_controls()


func _update_home_generation_controls() -> void:
	if is_instance_valid(home_generation_status):
		home_generation_status.text = "PREVIEWING GENERATION %02d" % home_generation
	var content := selection_panel.get_node_or_null("HomeGenerationControls") as VBoxContainer
	if not is_instance_valid(content):
		return
	for i in range(5):
		var stage_button := content.get_node_or_null("HomeGeneration_%d" % (i + 1)) as Button
		if is_instance_valid(stage_button):
			stage_button.modulate = Color("#E6B96F") if home_generation == i + 1 else Color("#FFFFFF")


func _build_legacy_home_screen_preview(screen: PanelContainer, generation: int) -> void:
	if generation == 1:
		_build_android_10_home_screen_preview(screen)
		return
	var content := VBoxContainer.new()
	content.name = "OSHomeScreenContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	screen.add_child(content)

	var status := HBoxContainer.new()
	status.custom_minimum_size.y = 12
	content.add_child(status)
	var time := _label("9:41", 8, Color("#FFFFFF"))
	time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(time)
	var indicators := _label("▮  ▰", 7, Color("#D8D8D8"))
	indicators.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(indicators)

	if generation >= 3:
		var widget := PanelContainer.new()
		widget.custom_minimum_size.y = 42 if generation == 3 else 52
		var widget_style := StyleBoxFlat.new()
		widget_style.bg_color = Color("#283746") if generation == 3 else Color("#1E2B38")
		widget_style.set_corner_radius_all(8 if generation == 3 else 12)
		widget.add_theme_stylebox_override("panel", widget_style)
		content.add_child(widget)
		var widget_label := _label("09:41\nMON  ·  12 NOV" if generation == 3 else "GOOD MORNING\n09:41       27°  ·  LAGOS", 10, Color("#FFFFFF"))
		widget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		widget_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		widget.add_child(widget_label)

	if generation >= 4:
		var search := PanelContainer.new()
		search.custom_minimum_size.y = 19
		var search_style := StyleBoxFlat.new()
		search_style.bg_color = Color("#303943")
		search_style.set_corner_radius_all(10)
		search.add_theme_stylebox_override("panel", search_style)
		content.add_child(search)
		var search_label := _label("⌕   Search apps", 8, Color("#DCE3EA"))
		search_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		search.add_child(search_label)

	var grid := VBoxContainer.new()
	grid.name = "HomeAppGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 0)
	content.add_child(grid)
	var apps := [
		["Phone", "☎", "#638B72"], ["Messages", "✉", "#597FAD"],
		["Camera", "◉", "#777D85"], ["Music", "♫", "#9470A7"],
		["Browser", "◎", "#4F8990"], ["Calendar", "▦", "#A56D6D"],
		["Gallery", "▧", "#A77D59"], ["Settings", "⚙", "#777D83"],
		["Files", "▤", "#8B865C"], ["Clock", "◷", "#657C99"],
		["Maps", "⌖", "#628B83"], ["Notes", "▧", "#9A8A62"]
	]
	var app_items: Array[Control] = []
	for app in apps:
		var tile := VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.add_theme_constant_override("separation", 2)
		var icon := PanelContainer.new()
		icon.custom_minimum_size = Vector2(34, 34) if generation == 1 else Vector2(36, 36)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(str(app[2]))
		icon_style.set_corner_radius_all(0 if generation == 1 else (5 if generation < 4 else 9))
		icon.add_theme_stylebox_override("panel", icon_style)
		tile.add_child(icon)
		var glyph := _label(str(app[1]), 13, Color("#FFFFFF"))
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_child(glyph)
		var app_name := _label(str(app[0]), 8, Color("#EAECEF"))
		app_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(app_name)
		app_items.append(tile)
	var columns := 3 if generation == 1 else 4
	var row_count := int(ceil(float(app_items.size()) / float(columns)))
	for row_index in range(row_count):
		var app_row := HBoxContainer.new()
		app_row.name = "HomeAppRow_%d" % (row_index + 1)
		app_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		app_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_row.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_child(app_row)
		for column_index in range(columns):
			var app_index := row_index * columns + column_index
			if app_index >= app_items.size():
				break
			var app_slot := CenterContainer.new()
			app_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			app_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			app_row.add_child(app_slot)
			app_slot.add_child(app_items[app_index])

	if generation >= 2:
		var dock := PanelContainer.new()
		dock.name = "HomeAppDock"
		dock.custom_minimum_size.y = 38
		var dock_style := StyleBoxFlat.new()
		dock_style.bg_color = Color(0.22, 0.25, 0.29, 0.94)
		dock_style.border_color = Color(0.75, 0.78, 0.82, 0.12)
		dock_style.set_border_width_all(1)
		dock_style.set_corner_radius_all(5 if generation == 2 else 12)
		dock_style.content_margin_left = 5
		dock_style.content_margin_right = 5
		dock_style.content_margin_top = 3
		dock_style.content_margin_bottom = 3
		dock.add_theme_stylebox_override("panel", dock_style)
		content.add_child(dock)
		var dock_row := HBoxContainer.new()
		dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
		dock_row.add_theme_constant_override("separation", 10)
		dock.add_child(dock_row)
		for dock_app in [["☎", "#638B72"], ["✉", "#597FAD"], ["◎", "#4F8990"], ["◉", "#777D85"]]:
			var dock_icon := PanelContainer.new()
			dock_icon.custom_minimum_size = Vector2(25, 27)
			var dock_icon_style := StyleBoxFlat.new()
			dock_icon_style.bg_color = Color(str(dock_app[1]))
			dock_icon_style.set_corner_radius_all(0 if generation == 2 else 8)
			dock_icon.add_theme_stylebox_override("panel", dock_icon_style)
			dock_row.add_child(dock_icon)
			var dock_glyph := _label(str(dock_app[0]), 14, Color("#FFFFFF"))
			dock_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dock_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dock_icon.add_child(dock_glyph)

	var navigation_area := CenterContainer.new()
	navigation_area.name = "HomeNavigationArea"
	navigation_area.custom_minimum_size.y = 8
	content.add_child(navigation_area)
	var home_indicator := ColorRect.new()
	home_indicator.name = "HomeGestureIndicator"
	home_indicator.custom_minimum_size = Vector2(28, 3)
	home_indicator.color = Color(0.92, 0.93, 0.95, 0.78)
	navigation_area.add_child(home_indicator)


func _build_android_10_home_screen_preview(screen: PanelContainer) -> void:
	var content := VBoxContainer.new()
	content.name = "Android10HomeScreen"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	screen.add_child(content)

	# Android 1.0's blue notification/status strip from the HTC Dream.
	var status_bar := PanelContainer.new()
	status_bar.name = "Android10StatusBar"
	status_bar.custom_minimum_size.y = 16
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color("#173B82")
	status_style.border_color = Color("#4775B8")
	status_style.border_width_bottom = 1
	status_style.content_margin_left = 4
	status_style.content_margin_right = 4
	status_style.content_margin_top = 0
	status_style.content_margin_bottom = 0
	status_bar.add_theme_stylebox_override("panel", status_style)
	content.add_child(status_bar)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 3)
	status_bar.add_child(status_row)
	var notifications := _android_era_label("▣  ▪", 8, Color("#F1F6FF"))
	status_row.add_child(notifications)
	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_spacer)
	var connection := _android_era_label("▂▃▅  ▰", 7, Color("#F1F6FF"))
	status_row.add_child(connection)
	var time := _android_era_label("11:56 PM", 8, Color("#FFFFFF"))
	status_row.add_child(time)

	# Original Android used Google's narrow, rectangular search widget here.
	var search_bar := PanelContainer.new()
	search_bar.name = "Android10GoogleSearch"
	search_bar.custom_minimum_size.y = 27
	var search_style := StyleBoxFlat.new()
	search_style.bg_color = Color("#D9EDF7")
	search_style.border_color = Color("#8BAEC3")
	search_style.set_border_width_all(1)
	search_style.content_margin_left = 6
	search_style.content_margin_right = 5
	search_style.content_margin_top = 1
	search_style.content_margin_bottom = 1
	search_bar.add_theme_stylebox_override("panel", search_style)
	content.add_child(search_bar)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 5)
	search_bar.add_child(search_row)
	var google_wordmark := _android_era_label("Google", 12, Color("#4276A8"))
	google_wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	google_wordmark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(google_wordmark)
	var search_icon := _android_era_label("⌕", 17, Color("#467EA8"))
	search_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(search_icon)
	var search_divider := ColorRect.new()
	search_divider.custom_minimum_size = Vector2(1, 17)
	search_divider.color = Color("#A5C1D1")
	search_row.add_child(search_divider)
	var voice_icon := _android_era_label("♩", 12, Color("#4D86AA"))
	voice_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_row.add_child(voice_icon)

	# The central page is intentionally sparse: two upper shortcuts and four lower shortcuts.
	var workspace := Android10WorkspaceArt.new()
	workspace.name = "Android10ClassicWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(workspace)


func _android_era_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label

func _make_home_app_icon(app_name: String, glyph: String, tint: Color, is_folder: bool = false) -> Control:
	var item := VBoxContainer.new()
	item.name = "HomeApp_" + app_name.replace(" ", "")
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 1)
	var icon_tile := PanelContainer.new()
	icon_tile.name = "IconTile"
	icon_tile.custom_minimum_size = Vector2(29, 29)
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
	var name_label := _label(app_name, 7, Color("#F0F2F5"))
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
		screen_height = clampf(viewport_size.y - 104.0, 250.0, 620.0)
		screen_frame.custom_minimum_size = Vector2(screen_height * 0.667, screen_height)
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		configuration_region.size_flags_stretch_ratio = 1.18
		preview_region.custom_minimum_size = Vector2(0, maxf(140.0, viewport_size.y * 0.24))
		screen_height = clampf(viewport_size.y * 0.42, 190.0, 340.0)
		screen_frame.custom_minimum_size = Vector2(screen_height * 0.50, screen_height)


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
