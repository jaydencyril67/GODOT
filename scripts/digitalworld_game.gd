extends Node3D

const CityMapScript = preload("res://scripts/world/digitalworld_city.gd")
const HeadquartersPreviewScript = preload("res://scripts/world/digitalworld_headquarters.gd")
const SAVE_PATH := "user://digitalworld_save.cfg"

const LOGO_NAMES := [
	"Orchard", "Skybird", "Crown", "Apex", "Volt", "Prism", "Quantum", "Helix", "Titan", "Zenith",
	"Vertex", "Catalyst", "Photon", "Fusion", "Eclipse", "Infinity", "Shield", "Spark", "Wave", "Matrix",
	"Nova", "Orbit", "Falcon", "Monolith", "Comet", "Aurora", "Pinnacle", "Circuit", "Lattice", "Monarch",
	"Flare", "Keystone", "Bluepeak", "Atlas", "Crescent", "Vortex", "Beacon", "Stratos", "Ironclad", "Mosaic",
	"Northstar", "Vector", "Aether", "Pulse", "Forge", "Meridian", "Lumen", "Cobalt", "Terra", "Frontier"
]

const NAVY := Color("#ffffff")
const BLUE := Color("#248cc4")
const PANEL := Color(0.075, 0.12, 0.13, 0.94)
const PALE := Color("#e8eee8")
const MUTED := Color("#a6b5b1")
const ACCENT := Color("#d8e6bd")

var ui_layer: CanvasLayer
var ui_root: Control
var world_root: Node3D
var career: Dictionary = {}
var upgrade_level := 1
var selected_upgrade := 1
var current_screen := "menu"
var full_name_input: LineEdit
var company_name_input: LineEdit
var logo_option: Button
var selected_logo_id := 1
var insignia_preview: TextureRect
var logo_picker_layer: Control
var logo_picker_panel: PanelContainer
var logo_picker_grid: GridContainer
var logo_picker_scroll: ScrollContainer
var logo_picker_scroll_tween: Tween
var logo_picker_touch_index := -1
var logo_picker_touch_start := Vector2.ZERO
var logo_picker_touch_dragging := false
var logo_picker_touch_velocity_y := 0.0
var logo_picker_touch_logo_id := 0
var logo_picker_mouse_logo_id := 0
var profile_status: Label
var graphics_quality := "High"
var sound_enabled := true

func _ready() -> void:
	# Start in Android immersive fullscreen after the display window is initialized.
	if OS.has_feature("android"):
		call_deferred("_apply_android_fullscreen")
	_load_career()
	_show_menu()


func _notification(what: int) -> void:
	# Android can restore system bars after app switching; re-enter immersive mode
	# when the game resumes instead of allowing a reduced-height window to persist.
	if what == NOTIFICATION_APPLICATION_RESUMED and OS.has_feature("android"):
		call_deferred("_apply_android_fullscreen")


func _apply_android_fullscreen() -> void:
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _load_career() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		career = {}
		upgrade_level = 1
		return false
	career = {
		"full_name": str(config.get_value("career", "full_name", "")),
		"company_name": str(config.get_value("career", "company_name", "")),
		"logo_id": int(config.get_value("career", "logo_id", 1)),
		"created_at": str(config.get_value("career", "created_at", "")),
		"last_opened_at": str(config.get_value("career", "last_opened_at", ""))
	}
	upgrade_level = clampi(int(config.get_value("career", "upgrade_level", 1)), 1, 10)
	return not str(career.get("company_name", "")).is_empty()

func _save_career() -> bool:
	var config := ConfigFile.new()
	config.set_value("career", "full_name", str(career.get("full_name", "")))
	config.set_value("career", "company_name", str(career.get("company_name", "")))
	config.set_value("career", "logo_id", int(career.get("logo_id", 1)))
	config.set_value("career", "created_at", str(career.get("created_at", "")))
	config.set_value("career", "last_opened_at", Time.get_datetime_string_from_system(true))
	config.set_value("career", "upgrade_level", upgrade_level)
	var error := config.save(SAVE_PATH)
	return error == OK

func _clear_world() -> void:
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = null

func _new_screen() -> Control:
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "Native_Godot_Interface"
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.name = "ScreenRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_layer.add_child(ui_root)
	return ui_root


func _show_menu() -> void:
	current_screen = "menu"
	_clear_world()
	var root := _new_screen()
	# Match the founder setup page's exact background image and overlay.
	var background := TextureRect.new()
	background.name = "DigitalWorld_Shared_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load("res://assets/digitalworld-landing.png")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.075, 0.12, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(center)

	var menu := VBoxContainer.new()
	menu.name = "Minimal_3D_Command_Menu"
	menu.custom_minimum_size = Vector2(440, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 18)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(menu)

	var new_game := _add_action_button(menu, "NEW GAME", true, _start_new_game)
	var continue_game := _add_action_button(menu, "CONTINUE", false, _load_game_pressed)
	var settings := _add_action_button(menu, "SETTINGS", false, _show_settings)
	var exit_game := _add_action_button(menu, "EXIT", false, _confirm_exit)

	for button in [new_game, continue_game, settings, exit_game]:
		button.custom_minimum_size = Vector2(0, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_command_menu_button(button, button == new_game)


func _style_command_menu_button(button: Button, primary: bool) -> void:
	# Frosted-glass appearance: translucent white surfaces and crisp borders,
	# with no neon glow or coloured drop shadow.
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		if state == "pressed":
			style.bg_color = Color(0.78, 0.91, 0.98, 0.38)
		elif state == "hover":
			style.bg_color = Color(0.98, 1.0, 1.0, 0.40)
		else:
			style.bg_color = Color(0.94, 0.98, 1.0, 0.28) if primary else Color(0.94, 0.98, 1.0, 0.22)
		style.border_color = Color(1.0, 1.0, 1.0, 0.92)
		style.set_border_width_all(2)
		style.border_width_top = 3
		style.set_corner_radius_all(16)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.10)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 1)
		style.anti_aliasing = true
		style.content_margin_left = 26
		style.content_margin_right = 26
		style.content_margin_top = 13
		style.content_margin_bottom = 13
		button.add_theme_stylebox_override(state, style)

	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#f0faff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.20, 0.30, 0.72))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)

func _start_new_game() -> void:
	_show_profile()


func _show_profile() -> void:
	current_screen = "profile"
	_clear_world()
	var root := _new_screen()

	# Keep the shared application background and overlay exactly as they are.
	var background := TextureRect.new()
	background.name = "DigitalWorld_Shared_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load("res://assets/digitalworld-landing.png")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.075, 0.12, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	# A single vertical scroll surface handles short screens without clipping.
	var scroll := ScrollContainer.new()
	scroll.name = "CompanySetupScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	root.add_child(scroll)

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 820.0
	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 18 if compact else 42)
	page_margin.add_theme_constant_override("margin_right", 18 if compact else 42)
	page_margin.add_theme_constant_override("margin_top", 22 if compact else 30)
	page_margin.add_theme_constant_override("margin_bottom", 24 if compact else 30)
	scroll.add_child(page_margin)

	var page := VBoxContainer.new()
	page.name = "CompanySetupContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	page_margin.add_child(page)

	# Header: clear hierarchy, readable on narrow phone widths.
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	page.add_child(header)
	var eyebrow := _label("DIGITALWORLD  /  FOUNDER SETUP", 11 if compact else 13, Color("#a9e3ff"))
	header.add_child(eyebrow)
	var title := _label("CREATE YOUR COMPANY", 27 if compact else 36, Color("#ffffff"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	var subtitle := _label("Build your identity. Choose the insignia that represents your company.", 13 if compact else 15, Color("#d8efff"))
	header.add_child(subtitle)

	# The two main sections flow vertically on phones and side-by-side on wide screens.
	var sections: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	sections.name = "CompanySetupSections"
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 14 if compact else 18)
	sections.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(sections)

	# Keep both cards centered and reduce each card's previous horizontal
	# allocation by a factor of 1.05 on phones and wide landscape displays.
	var horizontal_page_width := maxf(0.0, viewport_size.x - (36.0 if compact else 84.0))
	var original_card_width := horizontal_page_width if compact else (horizontal_page_width - 18.0) * 0.5
	var reduced_card_width := maxf(1.0, original_card_width / 1.05)

	# Founder identity card.
	var identity := _panel(Color(0.035, 0.14, 0.23, 0.84), Color(0.76, 0.92, 1.0, 0.76), 18)
	identity.name = "FounderIdentityCard"
	identity.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	identity.size_flags_stretch_ratio = 1.0
	identity.custom_minimum_size = Vector2(reduced_card_width, 0)
	sections.add_child(identity)
	var identity_style := identity.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	identity_style.set_border_width_all(1)
	identity_style.shadow_color = Color(0.0, 0.20, 0.36, 0.24)
	identity_style.shadow_size = 12
	identity.add_theme_stylebox_override("panel", identity_style)
	var identity_margin := _margin(identity, 18 if compact else 24, 18 if compact else 24, 18 if compact else 22, 18 if compact else 22)
	var identity_stack := VBoxContainer.new()
	identity_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_stack.add_theme_constant_override("separation", 10)
	identity_margin.add_child(identity_stack)
	identity_stack.add_child(_label("01  /  FOUNDER IDENTITY", 12, Color("#a9e3ff")))
	identity_stack.add_child(_label("Your details", 20 if compact else 22, Color("#ffffff")))
	identity_stack.add_child(_label("These details identify you and your business in DigitalWorld.", 12, Color("#c7e2f3")))

	identity_stack.add_child(_label("FOUNDER NAME", 11, Color("#d9efff")))
	full_name_input = LineEdit.new()
	full_name_input.placeholder_text = "Enter your full name"
	full_name_input.text = str(career.get("full_name", ""))
	full_name_input.custom_minimum_size = Vector2(0, 54)
	full_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_name_input.add_theme_font_size_override("font_size", 16)
	_style_line_edit(full_name_input)
	identity_stack.add_child(full_name_input)

	identity_stack.add_child(_label("COMPANY NAME", 11, Color("#d9efff")))
	company_name_input = LineEdit.new()
	company_name_input.placeholder_text = "Enter your company name"
	company_name_input.text = str(career.get("company_name", ""))
	company_name_input.custom_minimum_size = Vector2(0, 54)
	company_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	company_name_input.add_theme_font_size_override("font_size", 16)
	_style_line_edit(company_name_input)
	identity_stack.add_child(company_name_input)

	var privacy_note := _label("Your founder profile and company identity are saved locally on this device.", 11, Color("#b9d9eb"))
	privacy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_stack.add_child(privacy_note)

	# Brand card.
	var brand := _panel(Color(0.035, 0.14, 0.23, 0.84), Color(0.76, 0.92, 1.0, 0.76), 18)
	brand.name = "CompanyBrandCard"
	brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	brand.size_flags_stretch_ratio = 1.0
	brand.custom_minimum_size = Vector2(reduced_card_width, 0)
	sections.add_child(brand)
	var brand_style := brand.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	brand_style.set_border_width_all(1)
	brand_style.shadow_color = Color(0.0, 0.20, 0.36, 0.24)
	brand_style.shadow_size = 12
	brand.add_theme_stylebox_override("panel", brand_style)
	var brand_margin := _margin(brand, 18 if compact else 24, 18 if compact else 24, 18 if compact else 22, 18 if compact else 22)
	var brand_stack := VBoxContainer.new()
	brand_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_stack.add_theme_constant_override("separation", 10)
	brand_margin.add_child(brand_stack)
	brand_stack.add_child(_label("02  /  COMPANY BRAND", 12, Color("#a9e3ff")))
	brand_stack.add_child(_label("Choose your insignia", 20 if compact else 22, Color("#ffffff")))
	brand_stack.add_child(_label("Select one of 50 original DigitalWorld insignia designs.", 12, Color("#c7e2f3")))

	selected_logo_id = clampi(int(career.get("logo_id", 1)), 1, 50)
	logo_option = Button.new()
	logo_option.text = "%02d   %s     ·     CHANGE" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1]]
	logo_option.custom_minimum_size = Vector2(0, 52)
	logo_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo_option.add_theme_font_size_override("font_size", 14)
	_style_company_glass_button(logo_option)
	logo_option.pressed.connect(_open_logo_picker)
	brand_stack.add_child(logo_option)

	var preview_panel := _panel(Color(0.42, 0.73, 0.91, 0.13), Color(0.78, 0.93, 1.0, 0.40), 14)
	preview_panel.custom_minimum_size = Vector2(0, 126 if compact else 150)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_stack.add_child(preview_panel)
	var preview_margin := _margin(preview_panel, 12, 12, 10, 10)
	var preview_row := HBoxContainer.new()
	preview_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 14)
	preview_margin.add_child(preview_row)
	insignia_preview = TextureRect.new()
	insignia_preview.custom_minimum_size = Vector2(88, 88)
	insignia_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insignia_preview.texture = _company_logo_texture(selected_logo_id)
	preview_row.add_child(insignia_preview)
	var preview_copy := VBoxContainer.new()
	preview_copy.name = "PreviewCopy"
	preview_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_copy.add_theme_constant_override("separation", 5)
	preview_copy.add_child(_label("YOUR SELECTED MARK", 10, Color("#b8e5ff")))
	var selected_name := _label("%02d / 50  ·  %s" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1].to_upper()], 13, Color("#ffffff"))
	selected_name.name = "SelectedInsigniaName"
	preview_copy.add_child(selected_name)
	preview_row.add_child(preview_copy)

	var status_panel := PanelContainer.new()
	status_panel.name = "CompanySetupStatus"
	status_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	page.add_child(status_panel)
	profile_status = _label("", 12, Color("#ffd0b8"))
	profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_panel.add_child(profile_status)

	# Actions use full-width stacked buttons on narrow displays.
	var actions: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	actions.name = "CompanySetupActions"
	# Match the action row to the card widths above: each desktop button
	# occupies exactly one card width, while stacked phone buttons match one card.
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.custom_minimum_size.x = reduced_card_width if compact else (reduced_card_width * 2.0 + 10.0)
	actions.add_theme_constant_override("separation", 10)
	page.add_child(actions)
	var back_button := _add_action_button(actions, "BACK TO MENU", false, _show_menu)
	var establish_button := _add_action_button(actions, "ESTABLISH COMPANY  ›", true, _create_company)
	for action_button in [back_button, establish_button]:
		action_button.custom_minimum_size = Vector2(0, 56)
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_button.add_theme_font_size_override("font_size", 14 if compact else 15)
		_style_company_glass_button(action_button, action_button == establish_button)



func _company_logo_texture(logo_id: int) -> AtlasTexture:
	var atlas := load("res://assets/company_logos.svg") as Texture2D
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	var index := clampi(logo_id, 1, 50) - 1
	texture.region = Rect2(Vector2((index % 10) * 100, floori(float(index) / 10.0) * 100), Vector2(100, 100))
	return texture


func _open_logo_picker() -> void:
	if is_instance_valid(logo_picker_layer):
		logo_picker_layer.queue_free()

	logo_picker_layer = Control.new()
	logo_picker_layer.name = "CompanyInsigniaModal"
	logo_picker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(logo_picker_layer)

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 700.0
	var side_margin := 8.0 if compact else 28.0
	var vertical_margin := 8.0 if compact else 24.0
	var dialog_width := maxf(1.0, minf(viewport_size.x - side_margin * 2.0, 760.0))
	var dialog_height := maxf(1.0, minf(viewport_size.y - vertical_margin * 2.0, 680.0))
	var columns := 2 if viewport_size.x < 420.0 else (3 if viewport_size.x < 640.0 else (4 if viewport_size.x < 900.0 else 5))

	var scrim := ColorRect.new()
	scrim.name = "ModalScrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.005, 0.025, 0.045, 0.84)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	logo_picker_layer.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_theme_constant_override("margin_left", int(side_margin))
	center.add_theme_constant_override("margin_right", int(side_margin))
	center.add_theme_constant_override("margin_top", int(vertical_margin))
	center.add_theme_constant_override("margin_bottom", int(vertical_margin))
	logo_picker_layer.add_child(center)

	# The dialog has a screen-bounded size; the grid scrolls inside it.
	var panel := _panel(Color(0.025, 0.105, 0.17, 0.97), Color(0.72, 0.88, 0.96, 0.34), 18)
	panel.name = "InsigniaDialog"
	panel.custom_minimum_size = Vector2(dialog_width, dialog_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo_picker_panel = panel
	center.add_child(panel)

	var panel_style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.bg_color = Color(0.025, 0.105, 0.17, 0.97)
	panel_style.border_color = Color(0.48, 0.82, 1.0, 0.92)
	panel_style.set_border_width_all(3)
	panel_style.shadow_size = 0
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)

	var inset := 10 if compact else 18
	var margin := _margin(panel, inset, inset, inset, inset)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Scrolling stays enabled, but Godot's scrollbar is explicitly hidden.
	var scroll := ScrollContainer.new()
	scroll.name = "InsigniaGridScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = false
	scroll.scroll_deadzone = 8
	scroll.clip_contents = true
	logo_picker_scroll = scroll
	margin.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "InsigniaGrid"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid_gap := 7 if compact else 10
	grid.add_theme_constant_override("h_separation", grid_gap)
	grid.add_theme_constant_override("v_separation", grid_gap)
	# Keep the grid taller than the viewport on every device size so the
	# ScrollContainer always has a real vertical range to move through.
	var tile_height := 94 if compact else 112
	var grid_rows := int(ceil(50.0 / float(columns)))
	grid.custom_minimum_size.y = float(grid_rows * tile_height + (grid_rows - 1) * grid_gap)
	logo_picker_grid = grid
	scroll.add_child(grid)

	for index in range(50):
		var logo_id := index + 1
		var option := Button.new()
		option.name = "InsigniaOption_%02d" % logo_id
		option.custom_minimum_size = Vector2(0, 94 if compact else 112)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.toggle_mode = false
		option.focus_mode = Control.FOCUS_NONE
		option.mouse_filter = Control.MOUSE_FILTER_IGNORE
		option.mouse_default_cursor_shape = Control.CURSOR_ARROW
		option.clip_contents = true
		_style_company_glass_button(option)

		var logo_center := CenterContainer.new()
		logo_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		logo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := TextureRect.new()
		mark.custom_minimum_size = Vector2(56, 56) if compact else Vector2(72, 72)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.texture = _company_logo_texture(logo_id)
		logo_center.add_child(mark)
		option.add_child(logo_center)
		grid.add_child(option)




func _style_company_glass_button(button: Button, selected: bool = false) -> void:
	# Keep every visual state identical: no hover, pressed, focus, or selection flash.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.48, 0.78, 0.92, 0.10)
	style.border_color = Color(0.78, 0.92, 1.0, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_size = 0
	style.anti_aliasing = true
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f2faff"))
	button.add_theme_color_override("font_hover_color", Color("#f2faff"))
	button.add_theme_color_override("font_pressed_color", Color("#f2faff"))
	button.add_theme_color_override("font_focus_color", Color("#f2faff"))
	button.add_theme_color_override("font_disabled_color", Color("#f2faff"))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.14, 0.0))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(logo_picker_layer) or not is_instance_valid(logo_picker_panel):
		return

	var panel_rect := logo_picker_panel.get_global_rect()
	var viewport := get_viewport()

	# Desktop mouse input is handled here, not by the logo tile Controls.
	if event is InputEventMouseButton and not OS.has_feature("android"):
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.pressed and is_instance_valid(logo_picker_scroll) and logo_picker_scroll.get_global_rect().has_point(event.position):
				var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
				var target := clampi(logo_picker_scroll.scroll_vertical + direction * 132, 0, _logo_picker_max_scroll())
				_animate_logo_picker_scroll(target, 0.22)
				viewport.set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not panel_rect.has_point(event.position):
					_close_logo_picker()
					viewport.set_input_as_handled()
					return
				logo_picker_mouse_logo_id = _logo_picker_logo_at(event.position)
				if logo_picker_mouse_logo_id > 0:
					viewport.set_input_as_handled()
			else:
				if logo_picker_mouse_logo_id > 0:
					var released_logo_id := _logo_picker_logo_at(event.position)
					if released_logo_id == logo_picker_mouse_logo_id:
						_select_company_logo(released_logo_id)
					viewport.set_input_as_handled()
				logo_picker_mouse_logo_id = 0
		return

	# Android touch input is tracked before GUI dispatch. A drag moves the grid;
	# a short tap selects a logo only when it starts and ends on that same tile.
	if event is InputEventScreenTouch:
		if event.pressed:
			if not panel_rect.has_point(event.position):
				_close_logo_picker()
				viewport.set_input_as_handled()
				return
			if is_instance_valid(logo_picker_scroll) and logo_picker_scroll.get_global_rect().has_point(event.position):
				logo_picker_touch_index = event.index
				logo_picker_touch_start = event.position
				logo_picker_touch_dragging = false
				logo_picker_touch_velocity_y = 0.0
				logo_picker_touch_logo_id = _logo_picker_logo_at(event.position)
				viewport.set_input_as_handled()
		else:
			if event.index == logo_picker_touch_index:
				if logo_picker_touch_dragging:
					var fling_distance := clampf(logo_picker_touch_velocity_y * 0.10, -420.0, 420.0)
					var target := clampi(roundi(float(logo_picker_scroll.scroll_vertical) - fling_distance), 0, _logo_picker_max_scroll())
					_animate_logo_picker_scroll(target, 0.24)
				else:
					var released_logo_id := _logo_picker_logo_at(event.position)
					if logo_picker_touch_logo_id > 0 and released_logo_id == logo_picker_touch_logo_id:
						_select_company_logo(released_logo_id)
				viewport.set_input_as_handled()
				logo_picker_touch_index = -1
				logo_picker_touch_dragging = false
				logo_picker_touch_velocity_y = 0.0
				logo_picker_touch_logo_id = 0

	elif event is InputEventScreenDrag and event.index == logo_picker_touch_index:
		if not logo_picker_touch_dragging and logo_picker_touch_start.distance_to(event.position) >= 9.0:
			logo_picker_touch_dragging = true
		if logo_picker_touch_dragging and is_instance_valid(logo_picker_scroll):
			logo_picker_scroll.scroll_vertical = clampi(logo_picker_scroll.scroll_vertical - roundi(event.relative.y), 0, _logo_picker_max_scroll())
			logo_picker_touch_velocity_y = event.velocity.y
			viewport.set_input_as_handled()


func _logo_picker_logo_at(position: Vector2) -> int:
	if not is_instance_valid(logo_picker_grid):
		return 0
	for index in range(logo_picker_grid.get_child_count()):
		var tile := logo_picker_grid.get_child(index) as Control
		if is_instance_valid(tile) and tile.get_global_rect().has_point(position):
			return index + 1
	return 0

func _logo_picker_max_scroll() -> int:
	if not is_instance_valid(logo_picker_scroll):
		return 0
	var bar := logo_picker_scroll.get_v_scroll_bar()
	return maxi(0, roundi(bar.max_value - bar.page))


func _animate_logo_picker_scroll(target: int, duration: float) -> void:
	if not is_instance_valid(logo_picker_scroll):
		return
	if is_instance_valid(logo_picker_scroll_tween) and logo_picker_scroll_tween.is_running():
		logo_picker_scroll_tween.kill()
	logo_picker_scroll_tween = logo_picker_scroll.create_tween()
	logo_picker_scroll_tween.set_trans(Tween.TRANS_QUAD)
	logo_picker_scroll_tween.set_ease(Tween.EASE_OUT)
	logo_picker_scroll_tween.tween_property(logo_picker_scroll, "scroll_vertical", target, duration)

func _logo_option_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.58, 0.78, 0.25) if selected else Color(0.48, 0.78, 0.92, 0.10)
	style.border_color = Color(0.78, 0.92, 1.0, 0.56) if selected else Color(0.78, 0.92, 1.0, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_size = 0
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _select_company_logo(logo_id: int) -> void:
	selected_logo_id = clampi(logo_id, 1, 50)
	logo_option.text = "%02d   %s     ·     CHANGE" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1]]
	insignia_preview.texture = _company_logo_texture(selected_logo_id)
	var preview_row := insignia_preview.get_parent()
	var preview_copy := preview_row.get_node_or_null("PreviewCopy/SelectedInsigniaName") as Label
	if is_instance_valid(preview_copy):
		preview_copy.text = "%02d / 50  ·  %s" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1].to_upper()]
	_close_logo_picker()


func _close_logo_picker() -> void:
	if is_instance_valid(logo_picker_scroll_tween) and logo_picker_scroll_tween.is_running():
		logo_picker_scroll_tween.kill()
	if is_instance_valid(logo_picker_layer):
		logo_picker_layer.queue_free()
	logo_picker_layer = null
	logo_picker_panel = null
	logo_picker_grid = null
	logo_picker_scroll = null
	logo_picker_touch_index = -1
	logo_picker_touch_dragging = false
	logo_picker_touch_velocity_y = 0.0
	logo_picker_touch_logo_id = 0
	logo_picker_mouse_logo_id = 0

func _create_company() -> void:
	var founder := full_name_input.text.strip_edges()
	var company := company_name_input.text.strip_edges()
	if founder.is_empty() or company.is_empty():
		profile_status.text = "Enter both your full name and company name."
		return
	career["full_name"] = founder
	career["company_name"] = company
	career["logo_id"] = selected_logo_id
	if str(career.get("created_at", "")).is_empty():
		career["created_at"] = Time.get_datetime_string_from_system(true)
	upgrade_level = clampi(upgrade_level, 1, 10)
	if not _save_career():
		profile_status.text = "The company could not be saved. Check device storage."
		return
	_show_city()

func _load_game_pressed() -> void:
	if _load_career():
		_show_city()
	else:
		_show_notice("NO SAVED COMPANY", "No saved DigitalWorld company was found on this device. Choose NEW GAME to establish one.")

func _show_city() -> void:
	# New and loaded companies open at their currently owned headquarters level.
	selected_upgrade = clampi(upgrade_level, 1, 10)
	_show_headquarters_preview()

func _show_headquarters_preview() -> void:
	current_screen = "headquarters"
	_clear_world()
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = null
	ui_root = null

	var headquarters = HeadquartersPreviewScript.new()
	headquarters.name = "DigitalWorld_Headquarters_Preview"
	headquarters.preview_level = clampi(selected_upgrade, 1, 10)
	headquarters.owned_level = clampi(upgrade_level, 1, 10)
	headquarters.company_name = str(career.get("company_name", "YOUR COMPANY"))
	headquarters.map_requested.connect(_show_expansion_map)
	headquarters.preview_level_changed.connect(_on_headquarters_preview_level_changed)
	world_root = headquarters
	add_child(world_root)

func _show_expansion_map() -> void:
	current_screen = "map"
	_clear_world()
	if is_instance_valid(ui_layer):
		ui_layer.queue_free()
	ui_layer = null
	ui_root = null

	var expansion_map = CityMapScript.new()
	expansion_map.name = "DigitalWorld_Expansion_Map"
	expansion_map.headquarters_requested.connect(_show_headquarters_preview)
	world_root = expansion_map
	add_child(world_root)

func _on_headquarters_preview_level_changed(level: int) -> void:
	# Preview selection is temporary; owned progress is saved independently.
	selected_upgrade = clampi(level, 1, 10)

func _show_settings() -> void:
	if not is_instance_valid(ui_root):
		_new_screen()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.04, 0.055, 0.72)
	ui_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var card := _panel(Color("#e9eeea"), Color("#ffffff"), 16)
	card.custom_minimum_size = Vector2(330, 290)
	center.add_child(card)
	var margin := _margin(card, 22, 22, 18, 18)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	stack.add_child(_label("GAME CONFIGURATION", 10, Color("#426777"), HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label("SETTINGS", 24, Color("#173c4b"), HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label("GRAPHICS QUALITY", 10, Color("#345c68")))
	var quality := OptionButton.new()
	for option in ["High", "Balanced", "Performance"]:
		quality.add_item(option)
	quality.select(0 if graphics_quality == "High" else (1 if graphics_quality == "Balanced" else 2))
	quality.item_selected.connect(func(index: int): graphics_quality = quality.get_item_text(index))
	stack.add_child(quality)
	var sound := CheckButton.new()
	sound.text = "Sound enabled"
	sound.button_pressed = sound_enabled
	sound.toggled.connect(func(enabled: bool): sound_enabled = enabled)
	stack.add_child(sound)
	var done_button := _add_action_button(stack, "DONE", true, Callable())
	done_button.pressed.connect(_close_settings_overlay.bind(shade, center))

func _close_settings_overlay(shade: Control, center: Control) -> void:
	if is_instance_valid(shade):
		shade.queue_free()
	if is_instance_valid(center):
		center.queue_free()

func _confirm_exit() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "EXIT DIGITALWORLD"
	dialog.dialog_text = "Are you sure you want to leave DigitalWorld? Your saved company data will remain on this device."
	dialog.confirmed.connect(func(): get_tree().quit())
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 190))

func _show_notice(title_text: String, message_text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = message_text
	add_child(dialog)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(440, 190))

func _add_plain_background(root: Control, color: Color) -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = color
	root.add_child(backdrop)

func _panel(background: Color, border: Color, radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _margin(parent: Control, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin

func _label(text_value: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _add_action_button(parent: Node, caption: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#ffffff") if primary else Color("#e8eee8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_style_button(button, primary)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _hero_font_base(font_variation: FontVariation) -> void:
	font_variation.base_font = ThemeDB.fallback_font
	font_variation.variation_embolden = 0.7


func _style_glass_menu_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.62, 0.91, 0.38) if primary else Color(0.58, 0.84, 1.0, 0.20)
		if state == "hover":
			style.bg_color = Color(0.28, 0.78, 1.0, 0.52) if primary else Color(0.74, 0.93, 1.0, 0.34)
		elif state == "pressed":
			style.bg_color = Color(0.035, 0.24, 0.58, 0.62)
		style.border_color = Color(0.90, 0.98, 1.0, 0.94)
		style.set_border_width_all(1)
		style.border_width_top = 3
		style.border_width_left = 2
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.16, 0.48, 0.62)
		style.shadow_size = 15 if primary else 11
		style.shadow_offset = Vector2(0, 5)
		style.anti_aliasing = true
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_outline_color", Color("#06345f"))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.025, 0.12, 0.95))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 3)


func _apply_menu_3d_label(label: Label, depth: int = 3) -> void:
	# Layered outline and offset shadow give every menu caption a consistent
	# raised, extruded finish while keeping the interface crisp on mobile.
	label.add_theme_color_override("font_outline_color", Color("#052b59"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.025, 0.12, 0.92))
	label.add_theme_constant_override("shadow_offset_x", depth)
	label.add_theme_constant_override("shadow_offset_y", depth + 2)


func _style_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1679a4") if primary else Color(0.82, 0.93, 0.92, 0.32)
		if state == "hover":
			style.bg_color = Color("#2396bd") if primary else Color(0.9, 0.97, 0.94, 0.5)
		style.border_color = Color(1, 1, 1, 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)

func _style_line_edit(field: LineEdit) -> void:
	field.add_theme_color_override("font_color", Color("#123d58"))
	field.add_theme_color_override("font_placeholder_color", Color("#66879a"))
	field.add_theme_color_override("caret_color", Color("#1679b5"))
	field.add_theme_color_override("selection_color", Color(0.20, 0.58, 0.84, 0.34))
	for state in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.94, 0.98, 1.0, 0.97)
		style.border_color = Color("#bceaff") if state != "focus" else Color("#4fc5ff")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0.02, 0.20, 0.34, 0.16)
		style.shadow_size = 5
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		field.add_theme_stylebox_override(state, style)

func _add_spacer(parent: VBoxContainer, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)
