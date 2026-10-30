extends Node3D

const HQWorldScript = preload("res://scripts/world/hq_world.gd")
const HQCutawayScript = preload("res://scripts/world/hq_cutaway.gd")
const BuildingFactory = preload("res://scripts/world/hq_building_factory.gd")
const SAVE_PATH := "user://digitalworld_save.cfg"

const LOGO_NAMES := [
	"Orchard", "Skybird", "Crown", "Apex", "Volt", "Prism", "Quantum", "Helix", "Titan", "Zenith",
	"Vertex", "Catalyst", "Photon", "Fusion", "Eclipse", "Infinity", "Shield", "Spark", "Wave", "Matrix",
	"Nova", "Orbit", "Falcon", "Monolith", "Comet", "Aurora", "Pinnacle", "Circuit", "Lattice", "Monarch",
	"Flare", "Keystone", "Bluepeak", "Atlas", "Crescent", "Vortex", "Beacon", "Stratos", "Ironclad", "Mosaic",
	"Northstar", "Vector", "Aether", "Pulse", "Forge", "Meridian", "Lumen", "Cobalt", "Terra", "Frontier"
]
const UPGRADE_FLOORS := [1, 2, 3, 5, 7, 9, 12, 15, 19, 23]

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
var profile_status: Label
var graphics_quality := "High"
var sound_enabled := true

func _ready() -> void:
	# Re-apply Android immersive fullscreen at runtime as well as in the export preset.
	# Android may briefly reveal system bars for its edge-swipe navigation gesture.
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_load_career()
	_show_menu()

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
	page.add_child(sections)

	# Founder identity card.
	var identity := _panel(Color(0.035, 0.14, 0.23, 0.84), Color(0.76, 0.92, 1.0, 0.76), 18)
	identity.name = "FounderIdentityCard"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_stretch_ratio = 1.0
	identity.custom_minimum_size = Vector2(0, 0)
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
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.size_flags_stretch_ratio = 1.0
	brand.custom_minimum_size = Vector2(0, 0)
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
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8 if compact else 11)
	margin.add_child(stack)

	# Fixed header: it never moves with the logo grid.
	var heading := HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 8)
	stack.add_child(heading)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 3)
	heading.add_child(title_stack)
	title_stack.add_child(_label("COMPANY BRANDING  /  STEP 02", 9 if compact else 11, Color("#a9dff5")))
	var title := _label("Choose your insignia", 17 if compact else 23, Color("#ffffff"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(title)
	var subtitle := _label("Select one of 50 original DigitalWorld designs.", 10 if compact else 12, Color("#c4dbe8"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_stack.add_child(subtitle)

	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(38, 38) if compact else Vector2(42, 42)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(_close_logo_picker)
	_style_company_glass_button(close)
	heading.add_child(close)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.72, 0.88, 0.96, 0.18)
	stack.add_child(divider)

	# Only this middle region scrolls; header and footer remain stationary.
	var scroll := ScrollContainer.new()
	scroll.name = "InsigniaGridScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	stack.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "InsigniaGrid"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7 if compact else 10)
	grid.add_theme_constant_override("v_separation", 7 if compact else 10)
	scroll.add_child(grid)

	for index in range(50):
		var logo_id := index + 1
		var option := Button.new()
		option.name = "InsigniaOption_%02d" % logo_id
		option.custom_minimum_size = Vector2(0, 94 if compact else 112)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.toggle_mode = true
		option.button_pressed = logo_id == selected_logo_id
		option.clip_text = true
		_style_company_glass_button(option, logo_id == selected_logo_id)
		option.add_theme_constant_override("h_separation", 6)
		option.add_theme_constant_override("icon_max_width", 56 if compact else 64)

		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 3)
		var mark := TextureRect.new()
		mark.custom_minimum_size = Vector2(36, 36) if compact else Vector2(48, 48)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.texture = _company_logo_texture(logo_id)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(mark)

		var logo_name := _label(LOGO_NAMES[index].to_upper(), 8 if compact else 9, Color("#eaf6fc"), HORIZONTAL_ALIGNMENT_CENTER)
		logo_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		logo_name.max_lines_visible = 2
		cell.add_child(logo_name)
		option.add_child(cell)
		option.pressed.connect(_select_company_logo.bind(logo_id))
		grid.add_child(option)

	var footer_line := ColorRect.new()
	footer_line.custom_minimum_size = Vector2(0, 1)
	footer_line.color = Color(0.72, 0.88, 0.96, 0.18)
	stack.add_child(footer_line)

	# Fixed footer keeps the selection status and DONE action reachable.
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 8)
	stack.add_child(footer)

	var count_label := _label("%02d / 50 SELECTED" % selected_logo_id, 9 if compact else 10, Color("#b8e5ff"))
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(count_label)

	var footer_hint := _label("TAP A DESIGN TO SELECT", 9 if compact else 10, Color("#91bfd5"))
	footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(footer_hint)



func _style_company_glass_button(button: Button, selected: bool = false) -> void:
	# Quiet frosted-glass treatment: transparent fill, fine edge, no glow or shadow.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.20, 0.58, 0.78, 0.25) if selected else Color(0.48, 0.78, 0.92, 0.10)
		if state == "hover":
			style.bg_color = Color(0.34, 0.70, 0.86, 0.30) if selected else Color(0.55, 0.82, 0.94, 0.19)
		elif state == "pressed":
			style.bg_color = Color(0.15, 0.48, 0.68, 0.36)
		elif state == "disabled":
			style.bg_color = Color(0.45, 0.62, 0.70, 0.07)
		style.border_color = Color(0.78, 0.92, 1.0, 0.56) if selected else Color(0.78, 0.92, 1.0, 0.26)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.shadow_size = 0
		style.anti_aliasing = true
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f2faff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#8daab9"))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.14, 0.0))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)


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
	if is_instance_valid(logo_picker_layer):
		logo_picker_layer.queue_free()
	logo_picker_layer = null

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
	_show_map()

func _load_game_pressed() -> void:
	if _load_career():
		_show_map()
	else:
		_show_notice("NO SAVED COMPANY", "No saved DigitalWorld company was found on this device. Choose START GAME to establish one.")

func _show_map() -> void:
	current_screen = "map"
	_clear_world()
	var map := HQWorldScript.new()
	map.configure(str(career.get("company_name", "YOUR COMPANY")), upgrade_level)
	map.building_selected.connect(_open_headquarters)
	map.upgrade_requested.connect(_show_upgrades)
	map.tool_selected.connect(_map_tool_selected)
	world_root = map
	add_child(world_root)

	var root := _new_screen()
	_add_top_bar(root, "DIGITALWORLD  /  COMPANY TERRITORY", str(career.get("company_name", "YOUR COMPANY")), _show_menu)
	var sidebar := _anchored_panel(root, 14, 12, 248, -12, 0, 0.2, 0, 0.78)
	var side_stack := VBoxContainer.new()
	side_stack.add_theme_constant_override("separation", 8)
	sidebar.add_child(side_stack)
	side_stack.add_child(_label("HEADQUARTERS TOOLS", 10, ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_add_action_button(side_stack, "BUILD", false, func(): _map_action("BUILD"))
	_add_action_button(side_stack, "UPGRADE", true, _show_upgrades)
	_add_action_button(side_stack, "DOWNGRADE", false, func(): _map_action("DOWNGRADE"))
	_add_action_button(side_stack, "DEMOLISH", false, func(): _map_action("DEMOLISH"))
	_add_bottom_bar(root, "10 PLOTS  /  SELECT YOUR HEADQUARTERS TO OPEN ITS OPERATIONS")
	
func _open_headquarters() -> void:
	_show_interior()

func _show_interior() -> void:
	current_screen = "interior"
	_clear_world()
	var interior := HQCutawayScript.new()
	world_root = interior
	add_child(world_root)

	var root := _new_screen()
	_add_top_bar(root, "DIGITALWORLD  /  COMPANY INTERIOR", str(career.get("company_name", "YOUR COMPANY")), _show_map, "EXTERIOR")
	var sidebar := _anchored_panel(root, 14, 12, 248, -12, 0, 0.16, 0, 0.86)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	sidebar.add_child(stack)
	stack.add_child(_label("OPERATIONS", 10, ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	for action in ["CREATE", "RESEARCH", "INVENTORY", "HISTORY", "STAFFS"]:
		_add_action_button(stack, action, false, func(): _interior_action(action))
	_add_bottom_bar(root, "PROGRAMMING STUDIO     /     MANUFACTURING     /     PACKAGING & STACKING")

func _map_action(action: String) -> void:
	if action == "UPGRADE":
		_show_upgrades()
	else:
		_show_notice(action, "This headquarters management tool is present in the DigitalWorld design. Its construction/economy system has not yet been connected.")

func _map_tool_selected(tool_name: String) -> void:
	_map_action(tool_name)

func _interior_action(action: String) -> void:
	_show_notice(action, "The %s department panel is not connected to a simulation system yet. The original DigitalWorld version shows this as a tool entry without a gameplay handler." % action.to_lower())

func _show_upgrades() -> void:
	current_screen = "upgrade"
	_clear_world()
	selected_upgrade = mini(10, upgrade_level + 1)
	var stage := Node3D.new()
	stage.name = "Native_Godot_Upgrade_Showroom"
	world_root = stage
	add_child(stage)
	_build_upgrade_showroom(stage)

	var root := _new_screen()
	_add_top_bar(root, "DIGITALWORLD  /  HEADQUARTERS DEVELOPMENT", "CURRENT LEVEL  %02d / 10" % upgrade_level, _show_map, "EXTERIOR")
	var bottom := _anchored_panel(root, 12, 0, -12, -10, 0, 0.53, 1, 1)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	bottom.add_child(content)
	content.add_child(_label("SELECT A HEADQUARTERS TIER", 10, ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for index in range(10):
		var tier := index + 1
		var button := Button.new()
		button.text = "%02d  %s\n%d FLOORS" % [tier, BuildingFactory.BUILDING_NAMES[index], UPGRADE_FLOORS[index]]
		button.custom_minimum_size = Vector2(125, 48)
		button.toggle_mode = true
		button.button_pressed = tier == selected_upgrade
		_style_button(button, tier == selected_upgrade)
		button.pressed.connect(_select_upgrade.bind(tier))
		grid.add_child(button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var selected_name: String = str(BuildingFactory.BUILDING_NAMES[selected_upgrade - 1])
	actions.add_child(_label("SELECTED: %s" % selected_name.to_upper(), 10, PALE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_add_action_button(actions, "BACK", false, _show_map)
	_add_action_button(actions, "UPGRADE BUILDING", true, _confirm_upgrade)

func _select_upgrade(level: int) -> void:
	selected_upgrade = clampi(level, 1, 10)
	_show_upgrades()

func _confirm_upgrade() -> void:
	if selected_upgrade <= upgrade_level:
		_show_notice("HEADQUARTERS LEVEL", "That tier is already owned. Select a higher development tier.")
		return
	upgrade_level = selected_upgrade
	_save_career()
	_show_map()

func _build_upgrade_showroom(parent: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8b9697")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#eaf1ef")
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	parent.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	parent.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 42, 86)
	camera.fov = 42
	camera.look_at(Vector3(0, 8, 0), Vector3.UP)
	parent.add_child(camera)
	camera.current = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 86)
	ground.mesh = plane
	ground.position.y = -0.1
	ground.material_override = _material(Color("#777d7a"), 0.96)
	parent.add_child(ground)
	for index in range(10):
		var tier := index + 1
		var column := index % 5
		var row := floori(float(index) / 5.0)
		var x := float(column - 2) * 15.5
		var z := 10.0 if row == 0 else -10.0
		var pad := MeshInstance3D.new()
		var pad_mesh := BoxMesh.new()
		pad_mesh.size = Vector3(12.5, 0.22, 12.5)
		pad.mesh = pad_mesh
		pad.position = Vector3(x, 0.08, z)
		pad.material_override = _material(Color("#d7e5c2") if tier == selected_upgrade else Color("#b3b8b3"), 0.85, 0.12)
		parent.add_child(pad)
		var building: Node3D = BuildingFactory.create_preview_building(tier)
		building.scale = Vector3.ONE * 0.42
		building.position = Vector3(x, 0.22, z)
		building.rotation.y = -0.12
		parent.add_child(building)

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

func _add_top_bar(root: Control, kicker: String, company: String, back_action: Callable, back_text: String = "MAIN MENU") -> void:
	var panel := _anchored_panel(root, 12, 12, -12, 76, 0, 0, 1, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_theme_constant_override("alignment", BoxContainer.ALIGNMENT_CENTER)
	panel.add_child(row)
	var brand := _label("DW", 17, Color("#183e4b"), HORIZONTAL_ALIGNMENT_CENTER)
	brand.custom_minimum_size = Vector2(42, 42)
	row.add_child(brand)
	var copy := VBoxContainer.new()
	copy.add_child(_label(kicker, 9, Color("#456777")))
	copy.add_child(_label(company, 15, Color("#163e4d")))
	row.add_child(copy)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_add_action_button(row, "SETTINGS", false, _show_settings)
	_add_action_button(row, back_text, true, back_action)

func _add_bottom_bar(root: Control, text_value: String) -> void:
	var panel := _anchored_panel(root, 12, -52, -12, -10, 0, 1, 1, 1)
	var label := _label(text_value, 10, PALE, HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)

func _anchored_panel(parent: Control, offset_left: float, offset_top: float, offset_right: float, offset_bottom: float, anchor_left: float, anchor_top: float, anchor_right: float, anchor_bottom: float) -> PanelContainer:
	var panel := _panel(PANEL, Color(0.78, 0.88, 0.82, 0.5), 10)
	panel.anchor_left = anchor_left
	panel.anchor_top = anchor_top
	panel.anchor_right = anchor_right
	panel.anchor_bottom = anchor_bottom
	panel.offset_left = offset_left
	panel.offset_top = offset_top
	panel.offset_right = offset_right
	panel.offset_bottom = offset_bottom
	parent.add_child(panel)
	return panel

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

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
