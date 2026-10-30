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
var profile_status: Label
var graphics_quality := "High"
var sound_enabled := true

func _ready() -> void:
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

	# Full-screen purple-to-black atmosphere. No panel or card behind the menu.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([
		Color("#c9a7ff"),
		Color("#4b187f"),
		Color("#050309")
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 1.0)
	gradient_texture.width = 1024
	gradient_texture.height = 512

	var background := TextureRect.new()
	background.name = "DigitalWorld_Purple_Gradient_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture = gradient_texture
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	# A subtle dark wash keeps the white typography readable.
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.015, 0.005, 0.025, 0.16)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(696, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(content)

	var eyebrow := _label("THE WORLD OF BUSINESS, BUILT BY YOU", 12, Color("#eadcff"), HORIZONTAL_ALIGNMENT_CENTER)
	eyebrow.add_theme_color_override("font_color", Color("#eadcff"))
	content.add_child(eyebrow)
	_add_spacer(content, 8)

	var hero := Label.new()
	hero.name = "DigitalWorld_3D_Hero"
	hero.text = "DIGITALWORLD"
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero.autowrap_mode = TextServer.AUTOWRAP_OFF
	hero.clip_text = false
	hero.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.custom_minimum_size = Vector2(0, 92)
	hero.add_theme_font_size_override("font_size", 65)
	hero.add_theme_color_override("font_color", Color("#ffffff"))
	hero.add_theme_color_override("font_outline_color", Color("#321052"))
	hero.add_theme_constant_override("outline_size", 3)
	hero.add_theme_color_override("font_shadow_color", Color(0.015, 0.0, 0.04, 0.95))
	hero.add_theme_constant_override("shadow_offset_x", 5)
	hero.add_theme_constant_override("shadow_offset_y", 7)
	var hero_font := FontVariation.new()
	_hero_font_base(hero_font)
	hero.add_theme_font_override("font", hero_font)
	content.add_child(hero)

	_add_spacer(content, 4)
	var subtitle := _label("TECHNOLOGY  /  INDUSTRY  /  ENTERPRISE", 12, Color("#e6d3ff"), HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(subtitle)
	_add_spacer(content, 16)

	var description := _label("Build your company. Shape your headquarters. Lead your industry.", 16, Color("#f0e8fa"), HORIZONTAL_ALIGNMENT_CENTER)
	description.autowrap_mode = TextServer.AUTOWRAP_OFF
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	_add_spacer(content, 34)

	# Simple, transparent glass controls in one clean horizontal row.
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)

	var start_button := _add_action_button(actions, "START GAME  ›", true, _start_new_game)
	var load_button := _add_action_button(actions, "LOAD GAME", false, _load_game_pressed)
	var settings_button := _add_action_button(actions, "SETTINGS", false, _show_settings)
	var exit_button := _add_action_button(actions, "EXIT", false, _confirm_exit)
	for button in [start_button, load_button, settings_button, exit_button]:
		button.custom_minimum_size = Vector2(0, 58)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_glass_menu_button(button, button == start_button)

	_add_spacer(content, 22)
	var status := "SAVED COMPANY FOUND ON THIS DEVICE" if not career.is_empty() else "READY TO ESTABLISH A NEW COMPANY"
	var status_label := _label("●  " + status, 11, Color("#dfc9f5"), HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(status_label)

	var footer := _label("KINGSHALL-ORG", 10, Color("#d4bce9"))
	footer.anchor_left = 0.04
	footer.anchor_right = 0.46
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -30
	footer.offset_bottom = -10
	root.add_child(footer)
	var footer_right := _label("DIGITALWORLD", 10, Color("#d4bce9"), HORIZONTAL_ALIGNMENT_RIGHT)
	footer_right.anchor_left = 0.54
	footer_right.anchor_right = 0.96
	footer_right.anchor_top = 1.0
	footer_right.anchor_bottom = 1.0
	footer_right.offset_top = -25
	footer_right.offset_bottom = -8
	root.add_child(footer_right)


func _start_new_game() -> void:
	_show_profile()


func _show_profile() -> void:
	current_screen = "profile"
	_clear_world()
	var root := _new_screen()
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = load("res://assets/digitalworld-landing.png")
	root.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.075, 0.12, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 28)
	outer.add_theme_constant_override("margin_right", 28)
	outer.add_theme_constant_override("margin_top", 16)
	outer.add_theme_constant_override("margin_bottom", 16)
	root.add_child(outer)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	outer.add_child(page)
	page.add_child(_label("DIGITALWORLD  /  FOUNDER SETUP", 9, Color("#8ccff1")))
	page.add_child(_label("CREATE YOUR COMPANY", 30, Color("#f5fbff")))
	page.add_child(_label("Establish your identity and define your company brand.", 11, Color("#c5deed")))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var identity := _panel(Color(0.08, 0.22, 0.31, 0.72), Color(0.78, 0.91, 1.0, 0.28), 14)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(identity)
	var identity_margin := _margin(identity, 20, 20, 18, 18)
	var identity_stack := VBoxContainer.new()
	identity_stack.add_theme_constant_override("separation", 9)
	identity_margin.add_child(identity_stack)
	identity_stack.add_child(_label("01  FOUNDER IDENTITY", 11, Color("#9ad9f8")))
	identity_stack.add_child(_label("Founder name", 10, Color("#b6d9ed")))
	full_name_input = LineEdit.new()
	full_name_input.placeholder_text = "Enter your full name"
	full_name_input.text = str(career.get("full_name", ""))
	full_name_input.custom_minimum_size = Vector2(0, 42)
	_style_line_edit(full_name_input)
	identity_stack.add_child(full_name_input)
	identity_stack.add_child(_label("Company name", 10, Color("#b6d9ed")))
	company_name_input = LineEdit.new()
	company_name_input.placeholder_text = "Enter your company name"
	company_name_input.text = str(career.get("company_name", ""))
	company_name_input.custom_minimum_size = Vector2(0, 42)
	_style_line_edit(company_name_input)
	identity_stack.add_child(company_name_input)
	var identity_note := _label("Your founder profile and company identity are stored locally on this device.", 9, Color("#a8c5d8"))
	identity_note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity_stack.add_child(identity_note)

	var brand := _panel(Color(0.08, 0.22, 0.31, 0.72), Color(0.78, 0.91, 1.0, 0.28), 14)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(brand)
	var brand_margin := _margin(brand, 20, 20, 18, 18)
	var brand_stack := VBoxContainer.new()
	brand_stack.add_theme_constant_override("separation", 9)
	brand_margin.add_child(brand_stack)
	brand_stack.add_child(_label("02  COMPANY BRAND", 11, Color("#9ad9f8")))
	brand_stack.add_child(_label("Choose your company insignia", 15, Color("#f5fbff")))
	brand_stack.add_child(_label("Select one of the 50 original DigitalWorld insignia identities.", 10, Color("#c5deed")))
	selected_logo_id = clampi(int(career.get("logo_id", 1)), 1, 50)
	logo_option = Button.new()
	logo_option.custom_minimum_size = Vector2(0, 48)
	logo_option.text = "%02d  —  %s     CHANGE" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1]]
	_style_glass_menu_button(logo_option, false)
	logo_option.pressed.connect(_open_logo_picker)
	brand_stack.add_child(logo_option)
	var insignia_preview_panel := _panel(Color(0.45, 0.76, 0.88, 0.12), Color(0.85, 0.96, 1.0, 0.22), 10)
	insignia_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brand_stack.add_child(insignia_preview_panel)
	var preview_margin := _margin(insignia_preview_panel, 12, 12, 12, 12)
	var preview_stack := VBoxContainer.new()
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_stack.add_theme_constant_override("separation", 6)
	insignia_preview = TextureRect.new()
	insignia_preview.custom_minimum_size = Vector2(112, 112)
	insignia_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insignia_preview.texture = _company_logo_texture(selected_logo_id)
	insignia_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_stack.add_child(insignia_preview)
	preview_stack.add_child(_label("SELECTED INSIGNIA", 9, Color("#a8d7ef"), HORIZONTAL_ALIGNMENT_CENTER))
	preview_stack.add_child(_label("%02d  /  50   •   %s" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1].to_upper()], 11, Color("#e8f6ff"), HORIZONTAL_ALIGNMENT_CENTER))
	preview_margin.add_child(preview_stack)

	profile_status = _label("", 10, Color("#ffd0b8"))
	page.add_child(profile_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_add_action_button(actions, "BACK", false, _show_menu)
	_add_action_button(actions, "ESTABLISH COMPANY  ›", true, _create_company)
	page.add_child(actions)


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
	logo_picker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(logo_picker_layer)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.015, 0.005, 0.025, 0.88)
	logo_picker_layer.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo_picker_layer.add_child(center)
	var panel := _panel(Color(0.10, 0.055, 0.16, 0.98), Color(0.82, 0.68, 1.0, 0.62), 14)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(panel)
	var margin := _margin(panel, 16, 16, 12, 12)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_label("COMPANY BRANDING", 10, Color("#d8baff")))
	title_stack.add_child(_label("CHOOSE YOUR INSIGNIA", 19, Color("#ffffff")))
	title_stack.add_child(_label("Select one of the 50 original DigitalWorld vector designs.", 10, Color("#d8cbe8")))
	heading.add_child(title_stack)
	var close := _add_action_button(heading, "CLOSE", false, _close_logo_picker)
	close.custom_minimum_size = Vector2(76, 42)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for index in range(50):
		var logo_id := index + 1
		var option := Button.new()
		option.custom_minimum_size = Vector2(104, 82)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.toggle_mode = true
		option.button_pressed = logo_id == selected_logo_id
		option.add_theme_stylebox_override("normal", _logo_option_style(logo_id == selected_logo_id))
		option.add_theme_stylebox_override("hover", _logo_option_style(true))
		option.add_theme_stylebox_override("pressed", _logo_option_style(true))
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 3)
		var mark := TextureRect.new()
		mark.custom_minimum_size = Vector2(42, 42)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.texture = _company_logo_texture(logo_id)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(mark)
		cell.add_child(_label(LOGO_NAMES[index].to_upper(), 9, Color("#ffffff"), HORIZONTAL_ALIGNMENT_CENTER))
		option.add_child(cell)
		option.pressed.connect(_select_company_logo.bind(logo_id))
		grid.add_child(option)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	footer.add_child(_label("%02d / 50 SELECTED" % selected_logo_id, 10, Color("#d8baff")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_add_action_button(footer, "DONE", true, _close_logo_picker)


func _logo_option_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.48, 0.27, 0.68, 0.52) if selected else Color(0.9, 0.84, 1.0, 0.07)
	style.border_color = Color(0.86, 0.70, 1.0, 0.78) if selected else Color(0.9, 0.84, 1.0, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _select_company_logo(logo_id: int) -> void:
	selected_logo_id = clampi(logo_id, 1, 50)
	logo_option.text = "%02d  —  %s     CHANGE" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1]]
	insignia_preview.texture = _company_logo_texture(selected_logo_id)
	var preview_copy := insignia_preview.get_parent().get_child(2) as Label
	preview_copy.text = "%02d  /  50   •   %s" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1].to_upper()]
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
		style.bg_color = Color(0.55, 0.30, 0.82, 0.28) if primary else Color(0.92, 0.84, 1.0, 0.075)
		if state == "hover":
			style.bg_color = Color(0.72, 0.48, 0.96, 0.34) if primary else Color(0.92, 0.84, 1.0, 0.16)
		elif state == "pressed":
			style.bg_color = Color(0.35, 0.14, 0.58, 0.42)
		style.border_color = Color(0.96, 0.90, 1.0, 0.48)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	button.add_theme_font_size_override("font_size", 13)


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
	field.add_theme_color_override("font_color", Color("#173c4b"))
	field.add_theme_color_override("font_placeholder_color", Color("#80918f"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ffffff")
	style.border_color = Color("#bdcbc5")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	field.add_theme_stylebox_override("normal", style)
	field.add_theme_stylebox_override("focus", style)

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
