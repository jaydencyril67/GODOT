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
var selection_panel: Control
var configuration_region: Control
var screen_frame: PanelContainer
var home_preview_screen: PanelContainer
var home_generation := 1
var home_image_index := 0
var home_generation_status: Label
var home_screen_number_label: Label
var home_screen_decrease_button: Button
var home_screen_increase_button: Button
var home_image_paths := [
	"res://OSHSG1/IMG-20261113-WA0227.jpg",
	"res://OSHSG1/IMG-20261113-WA1726.jpg",
	"res://OSHSG1/IMG-20261113-WA3003.jpg",
	"res://OSHSG1/IMG-20261113-WA3402.jpg",
	"res://OSHSG1/IMG-20261113-WA4851.jpg",
	"res://OSHSG1/IMG-20261113-WA6095.jpg",
	"res://OSHSG1/IMG-20261113-WA7589.jpg",
	"res://OSHSG1/IMG-20261113-WA8214.jpg",
	"res://OSHSG1/IMG-20261113-WA9815.jpg",
	"res://OSHSG1/IMG-20261113-WA9894.jpg"
]

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
		draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(320.0, 456.0))

		# Period-accurate analog clock widget: brushed-metal bezel, pale face,
		# twelve numerals and the simple hands visible in the 2008 stock capture.
		var clock_center := Vector2(160, 101)
		draw_circle(clock_center + Vector2(0, 3), 69, Color(0.02, 0.05, 0.08, 0.34))
		draw_circle(clock_center, 68, Color("#3B4145"))
		draw_circle(clock_center, 66, Color("#92999C"))
		draw_circle(clock_center, 63, Color("#D4D7D6"))
		draw_circle(clock_center, 60, Color("#687176"))
		draw_circle(clock_center, 57, Color("#E9E8E1"))
		draw_circle(clock_center, 54, Color("#F7F5EC"))
		draw_arc(clock_center, 65, PI * 1.05, PI * 1.95, 72, Color(1, 1, 1, 0.82), 1.8, true)
		draw_arc(clock_center, 61, -PI * 0.02, PI * 0.95, 72, Color(0.18, 0.22, 0.24, 0.55), 1.0, true)

		for tick in range(60):
			var angle := -PI * 0.5 + TAU * float(tick) / 60.0
			var outer := clock_center + Vector2(cos(angle), sin(angle)) * 51.0
			var inner_radius := 44.0 if tick % 5 == 0 else 48.0
			var inner := clock_center + Vector2(cos(angle), sin(angle)) * inner_radius
			draw_line(inner, outer, Color("#5D6264"), 1.35 if tick % 5 == 0 else 0.65, true)

		var numerals := ["12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]
		for i in range(12):
			var angle := -PI * 0.5 + TAU * float(i) / 12.0
			var numeral_center := clock_center + Vector2(cos(angle), sin(angle)) * 40.5
			if is_instance_valid(ui_font):
				draw_string(ui_font, numeral_center + Vector2(-7.0, 4.0), numerals[i], HORIZONTAL_ALIGNMENT_CENTER, 14.0, 11, Color("#44494B"))

		# The small clock-face signature sits just above the hand pivot.
		if is_instance_valid(ui_font):
			draw_string(ui_font, clock_center + Vector2(-17, 21), "MALMO", HORIZONTAL_ALIGNMENT_CENTER, 34.0, 4, Color("#777A77"))

		# The stock capture shows the clock at approximately 7:36.
		var minute_angle := -PI * 0.5 + TAU * 36.0 / 60.0
		var hour_angle := -PI * 0.5 + TAU * (7.0 + 36.0 / 60.0) / 12.0
		var minute_tip := clock_center + Vector2(cos(minute_angle), sin(minute_angle)) * 43.0
		var hour_tip := clock_center + Vector2(cos(hour_angle), sin(hour_angle)) * 31.0
		draw_line(clock_center + Vector2(1, 1), minute_tip + Vector2(1, 1), Color(0.05, 0.07, 0.08, 0.26), 4.0, true)
		draw_line(clock_center + Vector2(1, 1), hour_tip + Vector2(1, 1), Color(0.05, 0.07, 0.08, 0.26), 5.0, true)
		draw_line(clock_center, minute_tip, Color("#202629"), 2.4, true)
		draw_line(clock_center, hour_tip, Color("#202629"), 4.0, true)
		draw_circle(clock_center, 4.0, Color("#30373A"))
		draw_circle(clock_center, 1.7, Color("#BCC2C2"))

		# Four shortcuts occupy the lower row, with the original black capsule labels.
		_draw_shortcut(Vector2(40, 342), "Dialer", 0)
		_draw_shortcut(Vector2(120, 342), "Contacts", 1)
		_draw_shortcut(Vector2(200, 342), "Browser", 2)
		_draw_shortcut(Vector2(280, 342), "Maps", 3)

		# Original metallic All Apps handle with side grip grooves and a raised arrow.
		var drawer := Rect2(110, 413, 100, 43)
		draw_rect(Rect2(drawer.position + Vector2(0, 2), drawer.size), Color(0.01, 0.02, 0.03, 0.36))
		draw_rect(drawer, Color("#858B8E"))
		draw_rect(Rect2(112, 414, 96, 41), Color("#BFC2C1"))
		draw_line(Vector2(113, 415), Vector2(207, 415), Color("#E6E7E4"), 1.0)
		draw_line(Vector2(113, 454), Vector2(207, 454), Color("#666D70"), 1.0)
		for groove in range(3):
			var gy := 422.0 + float(groove) * 8.0
			draw_line(Vector2(116, gy), Vector2(127, gy), Color("#737A7E"), 1.4)
			draw_line(Vector2(193, gy), Vector2(204, gy), Color("#737A7E"), 1.4)
		draw_circle(Vector2(160, 435), 13.0, Color("#727A7D"))
		draw_circle(Vector2(160, 434), 11.0, Color("#AEB6B6"))
		draw_arc(Vector2(160, 434), 10.0, PI * 1.05, PI * 1.95, 32, Color("#E5E8E6"), 1.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(160, 426), Vector2(152, 435), Vector2(157, 435),
			Vector2(157, 441), Vector2(163, 441), Vector2(163, 435),
			Vector2(168, 435)
		]), Color("#535C60"))

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_shortcut(center: Vector2, title: String, kind: int) -> void:
		# Each icon uses a softly bevelled, glossy 2008-style illustration.
		draw_rect(Rect2(center + Vector2(-20, -18), Vector2(40, 39)), Color(0.02, 0.05, 0.08, 0.20))
		match kind:
			0:
				# Dialer: silver keypad body with a blue handset.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-18, -11), center + Vector2(-8, -17),
					center + Vector2(13, -11), center + Vector2(18, 9),
					center + Vector2(7, 16), center + Vector2(-15, 10)
				]), Color("#C7D3D9"))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-12, -8), center + Vector2(6, -13),
					center + Vector2(12, 4), center + Vector2(-6, 11)
				]), Color("#E8EDF0"))
				for row in range(3):
					for col in range(3):
						draw_circle(center + Vector2(-5 + col * 6, -4 + row * 5), 1.3, Color("#7D929D"))
				draw_arc(center + Vector2(0, -1), 10, PI * 0.12, PI * 0.82, 18, Color("#197FC0"), 4.3, true)
				draw_arc(center + Vector2(0, -1), 10, PI * 1.12, PI * 1.82, 18, Color("#197FC0"), 4.3, true)
			1:
				# Contacts: layered paper cards and a small profile portrait.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-16, -11), center + Vector2(-3, -15),
					center + Vector2(12, -9), center + Vector2(13, 13),
					center + Vector2(-15, 10)
				]), Color("#AEBBC2"))
				draw_rect(Rect2(center + Vector2(-8, -13), Vector2(24, 26)), Color("#E4E8E9"))
				draw_rect(Rect2(center + Vector2(-5, -10), Vector2(18, 20)), Color("#F7F7F2"))
				draw_circle(center + Vector2(3, -4), 5.0, Color("#D5A36D"))
				draw_arc(center + Vector2(3, 9), 8.0, PI, TAU, 18, Color("#779AB0"), 5.0, true)
				draw_line(center + Vector2(-4, -10), center + Vector2(-4, 10), Color("#8096A3"), 1.0)
			2:
				# Browser: a compact silver browser window with a globe.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-17, -12), center + Vector2(15, -10),
					center + Vector2(16, 12), center + Vector2(-14, 10)
				]), Color("#B8C8CD"))
				draw_rect(Rect2(center + Vector2(-13, -8), Vector2(25, 17)), Color("#E7F0F0"))
				draw_line(center + Vector2(-12, -5), center + Vector2(11, -5), Color("#6A9CB3"), 1.5)
				draw_circle(center + Vector2(0, 3), 8.0, Color("#2A9D83"))
				draw_circle(center + Vector2(0, 3), 6.0, Color("#75C5C1"))
				draw_arc(center + Vector2(0, 3), 6.0, 0.0, TAU, 20, Color("#E7F5EA"), 1.0, true)
				draw_line(center + Vector2(-6, 3), center + Vector2(6, 3), Color("#E7F5EA"), 1.0)
			3:
				# Maps: folded map with the familiar red location pin.
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-18, -7), center + Vector2(-5, -13),
					center + Vector2(5, -9), center + Vector2(18, -14),
					center + Vector2(16, 12), center + Vector2(5, 16),
					center + Vector2(-6, 11), center + Vector2(-17, 15)
				]), Color("#E8E4D2"))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-16, -5), center + Vector2(-6, -10),
					center + Vector2(-6, 10), center + Vector2(-16, 13)
				]), Color("#76A8A0"))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-4, -8), center + Vector2(4, -5),
					center + Vector2(4, 13), center + Vector2(-4, 10)
				]), Color("#9BC6A6"))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(7, -9), center + Vector2(15, -12),
					center + Vector2(14, 9), center + Vector2(7, 12)
				]), Color("#E8CD83"))
				draw_circle(center + Vector2(5, -8), 7.0, Color("#D74C42"))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-1, -4), center + Vector2(11, -4),
					center + Vector2(5, 10)
				]), Color("#D74C42"))
				draw_circle(center + Vector2(5, -8), 2.3, Color("#FFF5E8"))

		var label_width := float(title.length()) * 7.0 + 12.0
		var label_rect := Rect2(Vector2(center.x - label_width * 0.5, center.y + 20.0), Vector2(label_width, 18.0))
		draw_rect(label_rect, Color("#101B24"))
		draw_circle(Vector2(label_rect.position.x, label_rect.position.y + 9), 9.0, Color("#101B24"))
		draw_circle(Vector2(label_rect.end.x, label_rect.position.y + 9), 9.0, Color("#101B24"))
		if is_instance_valid(ui_font):
			draw_string(ui_font, Vector2(label_rect.position.x, label_rect.position.y + 13.5), title, HORIZONTAL_ALIGNMENT_CENTER, label_width, 10, Color("#F7F7F7"))


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

	# Main content fills the scene directly; controls are independent overlays.
	worksite_body = BoxContainer.new()
	worksite_body.name = "OSWorksiteMainContent"
	worksite_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worksite_body.offset_left = 20.0
	worksite_body.offset_right = -20.0
	worksite_body.offset_top = 4.0
	worksite_body.offset_bottom = -12.0
	worksite_body.add_theme_constant_override("separation", 0)
	root.add_child(worksite_body)

	# Back button is positioned directly on the scene, not inside a top bar.
	var back_button := Button.new()
	back_button.name = "OSWorksiteBackButton"
	back_button.text = "BACK"
	back_button.anchor_left = 0.0
	back_button.anchor_right = 0.0
	back_button.anchor_top = 0.0
	back_button.anchor_bottom = 0.0
	back_button.offset_left = 20.0
	back_button.offset_top = 12.0
	back_button.offset_right = 102.0
	back_button.offset_bottom = 60.0
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button)
	back_button.pressed.connect(func(): back_requested.emit())
	root.add_child(back_button)

	# Progress indicator is independently anchored to the top-center of the scene.
	var progress := VBoxContainer.new()
	progress.name = "OSWorksiteProgress"
	progress.anchor_left = 1.0
	progress.anchor_right = 1.0
	progress.anchor_top = 0.0
	progress.anchor_bottom = 0.0
	progress.offset_left = -170.0
	progress.offset_top = 12.0
	progress.offset_right = -20.0
	progress.offset_bottom = 50.0
	progress.add_theme_constant_override("separation", 4)
	root.add_child(progress)

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

	# Keep the controls directly on the worksite; no surrounding card or panel.
	selection_panel = right_region
	_build_home_generation_controls()

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
	_build_selected_home_image(screen)
func _build_home_generation_controls() -> void:
	var content := VBoxContainer.new()
	content.name = "HomeGenerationControls"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 12)
	selection_panel.add_child(content)

	var heading := _label("GENERATION 01", 17, Color("#F0E9DD"))
	content.add_child(heading)
	var description := _label("Choose a home-screen design.", 12, Color("#B8B1A6"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	var selector := HBoxContainer.new()
	selector.name = "HomeScreenDesignSelector"
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	selector.add_theme_constant_override("separation", 18)
	content.add_child(selector)

	home_screen_decrease_button = Button.new()
	home_screen_decrease_button.name = "PreviousHomeScreenButton"
	home_screen_decrease_button.text = "−"
	_style_level_selector_button(home_screen_decrease_button)
	home_screen_decrease_button.pressed.connect(_step_home_image.bind(-1))
	selector.add_child(home_screen_decrease_button)

	home_screen_number_label = _label("SCREEN 01 / %02d" % home_image_paths.size(), 16, Color("#EEE9DF"))
	home_screen_number_label.name = "SelectedHomeScreenNumber"
	home_screen_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_screen_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_screen_number_label.custom_minimum_size = Vector2(150, 48)
	selector.add_child(home_screen_number_label)

	home_screen_increase_button = Button.new()
	home_screen_increase_button.name = "NextHomeScreenButton"
	home_screen_increase_button.text = "+"
	_style_level_selector_button(home_screen_increase_button)
	home_screen_increase_button.pressed.connect(_step_home_image.bind(1))
	selector.add_child(home_screen_increase_button)

	home_generation_status = _label("GENERATION 01  •  10 DESIGNS", 11, Color("#C58A3A"))
	content.add_child(home_generation_status)
	_update_home_generation_controls()


func _style_level_selector_button(button: Button) -> void:
	# Match the compact +/- selector controls used in the phone creation worksite.
	_style_button(button)
	button.custom_minimum_size = Vector2(56, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE


func _step_home_image(direction: int) -> void:
	_select_home_image(home_image_index + direction)


func _select_home_image(image_index: int) -> void:
	home_image_index = clampi(image_index, 0, home_image_paths.size() - 1)
	if is_instance_valid(home_preview_screen):
		for child in home_preview_screen.get_children():
			home_preview_screen.remove_child(child)
			child.free()
		_build_home_screen_preview(home_preview_screen)
	_update_home_generation_controls()


func _update_home_generation_controls() -> void:
	if is_instance_valid(home_generation_status):
		home_generation_status.text = "GENERATION 01  •  10 DESIGNS"
	if is_instance_valid(home_screen_number_label):
		home_screen_number_label.text = "SCREEN %02d / %02d" % [home_image_index + 1, home_image_paths.size()]
	if is_instance_valid(home_screen_decrease_button):
		home_screen_decrease_button.disabled = home_image_index <= 0
	if is_instance_valid(home_screen_increase_button):
		home_screen_increase_button.disabled = home_image_index >= home_image_paths.size() - 1


func _build_selected_home_image(screen: PanelContainer) -> void:
	screen.clip_contents = true
	var image := TextureRect.new()
	image.name = "SelectedHomeScreenImage"
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.texture = load(home_image_paths[home_image_index]) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Fill the complete phone display bounds: no crop and no letterboxing.
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Match the rounded inner display corners so square image corners never
	# paint beyond the visible OS screen shape.
	var rounded_clip_shader := Shader.new()
	rounded_clip_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	vec2 q = p - vec2(0.88);
	float outside_distance = length(max(q, vec2(0.0)));
	float inside_distance = min(max(q.x, q.y), 0.0);
	float rounded_distance = outside_distance + inside_distance - 0.12;
	if (rounded_distance > 0.0) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * COLOR;
}
"""
	var rounded_clip_material := ShaderMaterial.new()
	rounded_clip_material.shader = rounded_clip_shader
	image.material = rounded_clip_material
	screen.clip_contents = true
	screen.add_child(image)


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

	# Android 1.0 / HTC Dream stock status strip.
	var status_bar := PanelContainer.new()
	status_bar.name = "Android10StatusBar"
	status_bar.custom_minimum_size.y = 24
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color("#25282B")
	status_style.border_color = Color("#101315")
	status_style.border_width_bottom = 1
	status_style.content_margin_left = 5
	status_style.content_margin_right = 5
	status_style.content_margin_top = 0
	status_style.content_margin_bottom = 0
	status_bar.add_theme_stylebox_override("panel", status_style)
	content.add_child(status_bar)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 4)
	status_bar.add_child(status_row)
	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_spacer)
	for indicator in ["ᛒ", "3G", "▮▮▮", "▰"]:
		var status_icon := _android_era_label(indicator, 9, Color("#E6E8E9"))
		status_row.add_child(status_icon)
	var time := _android_era_label("7:36 AM", 11, Color("#FFFFFF"))
	status_row.add_child(time)

	# The original 640x480 Mono Lake Blue AOSP wallpaper is center-cropped to the
	# HTC Dream's 320x480 portrait display, as Android's wallpaper service did.
	var workspace := Control.new()
	workspace.name = "Android10StockWorkspace"
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.clip_contents = true
	content.add_child(workspace)

	var wallpaper := TextureRect.new()
	wallpaper.name = "Android10MonoLakeWallpaper"
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wallpaper.texture = load("res://assets/textures/os/android_1_0_default_wallpaper.jpg") as Texture2D
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace.add_child(wallpaper)

	var artwork := Android10WorkspaceArt.new()
	artwork.name = "Android10StockClockIconsAndDrawer"
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace.add_child(artwork)


func _android_era_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	return label

func _make_home_app_icon(app_name: String, glyph: String, tint: Color, _is_folder: bool = false) -> Control:
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
		# Extend the landscape phone close to the bottom edge; navigation remains an overlay.
		screen_height = clampf(viewport_size.y - 28.0, 280.0, 760.0)
		screen_frame.custom_minimum_size = Vector2(screen_height * 0.667, screen_height * 0.95)
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
