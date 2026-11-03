extends Node3D

const HeadquartersPreviewScript = preload("res://scripts/world/digitalworld_headquarters.gd")
const PhoneEditorScene: PackedScene = preload("res://scenes/product_phone_editor.tscn")
const StaffMarketScene: PackedScene = preload("res://scenes/staff_market.tscn")
const ConfirmModalScript = preload("res://scripts/ui/digitalworld_confirm_modal.gd")
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

var landing_environment: Node3D
var ui_layer: CanvasLayer
var ui_root: Control
var create_ui_layer: CanvasLayer
var create_ui_root: Control
var world_root: Node3D
var phone_editor: Node3D
var home_navigation_layer: CanvasLayer
var home_company_label: Label
var home_date_label: Label
var home_balance_label: Label
var home_finance_toast: Label
var home_finance_toast_tween: Tween
var home_research_points_label: Label
var home_time_button: Button
var staff_ui_layer: CanvasLayer
var staff_screen
var staff_market_screen
var staff_management_screen
var confirm_modal: CanvasLayer
var game_date_unix := 1262304000.0
var game_clock_paused := false
var last_saved_game_day := -1
var career: Dictionary = {}
var upgrade_level := 0
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
var loading_status_label: Label
var loading_progress_bar: ProgressBar
var graphics_quality := "High"
var sound_enabled := true

func _ready() -> void:
	# Start in Android immersive fullscreen after the display window is initialized.
	set_process(true)
	if OS.has_feature("android"):
		call_deferred("_apply_android_fullscreen")
	confirm_modal = ConfirmModalScript.new()
	confirm_modal.name = "DigitalWorld_Confirm_Modal"
	add_child(confirm_modal)
	_load_career()
	_show_menu()


func _process(delta: float) -> void:
	if career.is_empty() or str(career.get("company_name", "")).is_empty() or game_clock_paused:
		return
	# Keep the in-game clock and monthly staff refresh running on all company screens,
	# including while the player is browsing products, research, or other HQ features.
	if current_screen not in ["home", "headquarters", "create", "research", "research_phone", "office", "staff_market", "staff_management", "phone_editor"]:
		return
	var previous_day := floori(game_date_unix / 86400.0)
	var previous_month := _get_game_month_key(game_date_unix)
	# One complete in-game day passes every three real-world seconds.
	var game_time_delta := delta * 28800.0
	game_date_unix += game_time_delta
	_accrue_research_points(game_time_delta)
	var current_day := floori(game_date_unix / 86400.0)
	var current_month := _get_game_month_key(game_date_unix)
	if current_month != previous_month:
		_process_pending_monthly_expenses()
		_process_staff_market_refresh(current_month)
	if current_day != previous_day:
		_save_career()
		last_saved_game_day = current_day
	_update_home_status_bar()


func _get_game_month_key(timestamp: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%04d-%02d" % [date.year, date.month]


func _process_pending_monthly_expenses() -> void:
	var month_key := _get_game_month_key(game_date_unix)
	if month_key != str(career.get("last_rent_billed_month", month_key)):
		_process_monthly_headquarters_rent(month_key)
	if month_key != str(career.get("last_payroll_billed_month", month_key)):
		_process_monthly_staff_payroll(month_key)


func _process_monthly_headquarters_rent(month_key: String) -> void:
	if month_key == str(career.get("last_rent_billed_month", "")):
		return
	if upgrade_level <= 0:
		career["last_rent_billed_month"] = month_key
		_save_career()
		return
	var monthly_rent := float(HeadquartersPreviewScript.get_monthly_rent(upgrade_level))
	var current_balance := float(career.get("balance", 10000000.0))
	career["last_rent_billed_month"] = month_key
	if monthly_rent <= 0.0:
		_save_career()
		return
	if current_balance < monthly_rent:
		_save_career()
		_show_notice("MONTHLY RENT DUE", "Your Level %d headquarters requires %s in monthly rent, but your balance is only %s. Rent was not deducted." % [upgrade_level, _format_balance(monthly_rent), _format_balance(current_balance)])
		return
	career["balance"] = current_balance - monthly_rent
	if not _save_career():
		career["balance"] = current_balance
		career["last_rent_billed_month"] = _get_game_month_key(game_date_unix - 86400.0)
		_show_notice("RENT PAYMENT NOT SAVED", "Your monthly headquarters rent could not be saved. Your balance has not changed.")
		return
	if is_instance_valid(world_root) and world_root.has_method("set_company_balance"):
		world_root.set_company_balance(float(career["balance"]))
	_update_home_status_bar()
	_update_staff_office_balance()
	_show_finance_toast(-monthly_rent, "HEADQUARTERS RENT")


func _notification(what: int) -> void:
	# Persist simulation state when the app is backgrounded or closed.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not career.is_empty():
			_save_career()
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
		upgrade_level = 0
		return false
	career = {
		"full_name": str(config.get_value("career", "full_name", "")),
		"company_name": str(config.get_value("career", "company_name", "")),
		"logo_id": int(config.get_value("career", "logo_id", 1)),
		"created_at": str(config.get_value("career", "created_at", "")),
		"last_opened_at": str(config.get_value("career", "last_opened_at", "")),
		"balance": float(config.get_value("career", "balance", 10000000.0)),
		"research_points": maxi(0, int(config.get_value("career", "research_points", 0))),
		"research_points_progress": maxf(0.0, float(config.get_value("career", "research_points_progress", 0.0))),
		"game_date_unix": float(config.get_value("career", "game_date_unix", 1262304000.0)),
		"game_clock_paused": bool(config.get_value("career", "game_clock_paused", false)),
		"last_rent_billed_month": str(config.get_value("career", "last_rent_billed_month", _get_game_month_key(float(config.get_value("career", "game_date_unix", 1262304000.0))))),
		"last_payroll_billed_month": str(config.get_value("career", "last_payroll_billed_month", _get_game_month_key(float(config.get_value("career", "game_date_unix", 1262304000.0))))),
		"staff_candidates": config.get_value("career", "staff_candidates", []),
		"staff_employees": config.get_value("career", "staff_employees", []),
		"next_staff_candidate_id": int(config.get_value("career", "next_staff_candidate_id", 1)),
		"last_candidate_refresh_month": str(config.get_value("career", "last_candidate_refresh_month", _get_game_month_key(float(config.get_value("career", "game_date_unix", 1262304000.0))))),
		"staff_market_initialized": bool(config.get_value("career", "staff_market_initialized", false)),
		"phone_design_research": config.get_value("career", "phone_design_research", {})
	}
	game_date_unix = float(career.get("game_date_unix", 1262304000.0))
	game_clock_paused = bool(career.get("game_clock_paused", false))
	last_saved_game_day = floori(game_date_unix / 86400.0)
	upgrade_level = clampi(int(config.get_value("career", "upgrade_level", 0)), 0, 10)
	if not str(career.get("company_name", "")).is_empty():
		_ensure_staff_data()
	return not str(career.get("company_name", "")).is_empty()

func _save_career() -> bool:
	var config := ConfigFile.new()
	config.set_value("career", "full_name", str(career.get("full_name", "")))
	config.set_value("career", "company_name", str(career.get("company_name", "")))
	config.set_value("career", "logo_id", int(career.get("logo_id", 1)))
	config.set_value("career", "created_at", str(career.get("created_at", "")))
	config.set_value("career", "last_opened_at", Time.get_datetime_string_from_system(true))
	config.set_value("career", "upgrade_level", upgrade_level)
	config.set_value("career", "balance", float(career.get("balance", 10000000.0)))
	config.set_value("career", "research_points", maxi(0, int(career.get("research_points", 0))))
	config.set_value("career", "research_points_progress", maxf(0.0, float(career.get("research_points_progress", 0.0))))
	config.set_value("career", "game_date_unix", game_date_unix)
	config.set_value("career", "game_clock_paused", game_clock_paused)
	config.set_value("career", "last_rent_billed_month", str(career.get("last_rent_billed_month", _get_game_month_key(game_date_unix))))
	config.set_value("career", "last_payroll_billed_month", str(career.get("last_payroll_billed_month", _get_game_month_key(game_date_unix))))
	config.set_value("career", "staff_candidates", career.get("staff_candidates", []))
	config.set_value("career", "staff_employees", career.get("staff_employees", []))
	config.set_value("career", "next_staff_candidate_id", int(career.get("next_staff_candidate_id", 1)))
	config.set_value("career", "last_candidate_refresh_month", str(career.get("last_candidate_refresh_month", _get_game_month_key(game_date_unix))))
	config.set_value("career", "staff_market_initialized", bool(career.get("staff_market_initialized", false)))
	config.set_value("career", "phone_design_research", career.get("phone_design_research", {}))
	var error := config.save(SAVE_PATH)
	return error == OK

func _dispose_phone_editor() -> void:
	if not is_instance_valid(phone_editor):
		phone_editor = null
		return
	# CanvasLayers render independently of their Node3D parent, so hide the
	# editor's interface before deferred deletion to prevent a transition flash.
	for child in phone_editor.get_children():
		if child is CanvasLayer:
			child.hide()
	phone_editor.queue_free()
	phone_editor = null


func _clear_world() -> void:
	if is_instance_valid(landing_environment):
		landing_environment.queue_free()
	landing_environment = null
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = null
	if is_instance_valid(staff_ui_layer):
		staff_ui_layer.queue_free()
	staff_ui_layer = null
	staff_screen = null
	staff_market_screen = null
	staff_management_screen = null

func _new_screen() -> Control:
	# Hide the outgoing screen immediately. queue_free() removes it only at
	# the end of the frame, so leaving it visible can briefly stack two scenes.
	if is_instance_valid(ui_layer):
		ui_layer.hide()
		if ui_layer != create_ui_layer:
			ui_layer.queue_free()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "Native_Godot_Interface"
	ui_layer.layer = 20
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
	landing_environment = _build_landing_showroom()
	add_child(landing_environment)

	var root := _new_screen()
	root.modulate.a = 0.0

	# Soft vignette keeps the interface readable without flattening the showroom.
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.22, 0.88, length(p));
	float top_shade = smoothstep(0.0, 0.75, SCREEN_UV.y) * 0.12;
	COLOR = vec4(vec3(0.0), edge * 0.42 + top_shade);
}
"""
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = vignette_shader
	vignette.material = vignette_material
	root.add_child(vignette)

	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)

	var showcase := Control.new()
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.size_flags_stretch_ratio = 1.45
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(showcase)

	var brand := VBoxContainer.new()
	brand.position = Vector2(58, 42)
	brand.custom_minimum_size = Vector2(440, 86)
	brand.add_theme_constant_override("separation", 5)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(brand)
	var brand_name := _label("DIGITAL WORLD", 29, Color("#f3faf3"))
	_apply_menu_3d_label(brand_name, 1)
	brand.add_child(brand_name)
	var brand_subtitle := _label("M O B I L E S     /     POWERED BY KINGSHALL", 10, Color("#9cc9a7"))
	brand.add_child(brand_subtitle)

	var welcome := VBoxContainer.new()
	welcome.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	welcome.position = Vector2(58, 66)
	welcome.custom_minimum_size = Vector2(430, 160)
	welcome.add_theme_constant_override("separation", 10)
	welcome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(welcome)
	var eyebrow := _label("THE MOBILE INDUSTRY STARTS HERE", 10, Color("#8fbd9a"))
	welcome.add_child(eyebrow)
	var welcome_title := _label("BUILD THE\nNEXT GENERATION.", 34, Color("#f4f8f3"))
	welcome_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_apply_menu_3d_label(welcome_title, 1)
	welcome.add_child(welcome_title)
	var welcome_caption := _label("Create technology. Shape the market.\nBuild a brand that leads the future.", 14, Color("#b5c7b9"))
	welcome_caption.add_theme_constant_override("line_separation", 4)
	welcome.add_child(welcome_caption)

	var command_area := CenterContainer.new()
	command_area.size_flags_horizontal = Control.SIZE_SHRINK_END
	command_area.custom_minimum_size.x = 390
	command_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(command_area)

	var command_panel := PanelContainer.new()
	command_panel.custom_minimum_size = Vector2(342, 0)
	command_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.065, 0.039, 0.76)
	panel_style.border_color = Color(0.58, 0.82, 0.63, 0.58)
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.025, 0.008, 0.62)
	panel_style.shadow_size = 28
	panel_style.shadow_offset = Vector2(0, 10)
	panel_style.anti_aliasing = true
	panel_style.content_margin_left = 25
	panel_style.content_margin_right = 25
	panel_style.content_margin_top = 27
	panel_style.content_margin_bottom = 25
	command_panel.add_theme_stylebox_override("panel", panel_style)
	command_area.add_child(command_panel)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	command_panel.add_child(menu)
	var menu_heading := _label("WELCOME BACK", 10, Color("#a8d5b0"), HORIZONTAL_ALIGNMENT_CENTER)
	menu.add_child(menu_heading)
	var menu_title := _label("MAIN MENU", 20, Color("#f1f7f0"), HORIZONTAL_ALIGNMENT_CENTER)
	menu.add_child(menu_title)
	var menu_rule := ColorRect.new()
	menu_rule.custom_minimum_size = Vector2(0, 1)
	menu_rule.color = Color(0.58, 0.82, 0.63, 0.48)
	menu.add_child(menu_rule)

	var new_game := _add_action_button(menu, "NEW GAME", true, _start_new_game)
	var continue_game := _add_action_button(menu, "CONTINUE", false, _load_game_pressed)
	var settings := _add_action_button(menu, "SETTINGS", false, _show_settings)
	var exit_game := _add_action_button(menu, "EXIT", false, _confirm_exit)
	for button in [new_game, continue_game, settings, exit_game]:
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_landing_command_button(button, button == new_game)

	var footer_rule := ColorRect.new()
	footer_rule.custom_minimum_size = Vector2(0, 1)
	footer_rule.color = Color(0.45, 0.68, 0.50, 0.24)
	menu.add_child(footer_rule)
	var footer := _label("A KINGS HALL SIMULATION", 9, Color("#8aa991"), HORIZONTAL_ALIGNMENT_CENTER)
	menu.add_child(footer)

	var entrance := create_tween()
	entrance.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(root, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)



func _build_landing_showroom() -> Node3D:
	var scene := Node3D.new()
	scene.name = "Landing_Showroom_Environment"

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#030a06")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9abda1")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_strength = 0.72
	environment.glow_bloom = 0.08
	world_environment.environment = environment
	scene.add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.0, 12.5)
	camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	camera.fov = 46.0
	camera.current = true
	scene.add_child(camera)

	# Layered soft lighting gives the empty architectural stage depth and polish.
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color("#e5f5e7")
	key_light.light_energy = 1.55
	key_light.shadow_enabled = true
	scene.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill_light.light_color = Color("#9bd8a8")
	fill_light.light_energy = 0.48
	scene.add_child(fill_light)

	var left_wash := OmniLight3D.new()
	left_wash.position = Vector3(-5.2, 3.2, 1.4)
	left_wash.light_color = Color("#38b968")
	left_wash.light_energy = 3.8
	left_wash.omni_range = 11.0
	scene.add_child(left_wash)

	var right_wash := OmniLight3D.new()
	right_wash.position = Vector3(5.0, 2.8, -0.2)
	right_wash.light_color = Color("#b1e2b5")
	right_wash.light_energy = 2.1
	right_wash.omni_range = 9.0
	scene.add_child(right_wash)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(44.0, 44.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.08, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#07140b")
	floor_material.metallic = 0.58
	floor_material.roughness = 0.2
	floor.material_override = floor_material
	scene.add_child(floor)

	var rear_wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(15.0, 7.0, 0.42)
	rear_wall.mesh = wall_mesh
	rear_wall.position = Vector3(0.0, 2.85, -3.55)
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("#07170d")
	wall_material.metallic = 0.42
	wall_material.roughness = 0.34
	rear_wall.material_override = wall_material
	scene.add_child(rear_wall)

	# Slim architectural fins and inset light blades create a premium backdrop,
	# with no handset, pedestal, or product silhouette competing with the menu.
	for i in range(11):
		var x := -6.0 + float(i) * 1.2
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.12, 5.7, 0.34)
		fin.mesh = fin_mesh
		fin.position = Vector3(x, 2.75, -3.22)
		var fin_material := StandardMaterial3D.new()
		fin_material.albedo_color = Color("#173522")
		fin_material.metallic = 0.72
		fin_material.roughness = 0.24
		fin.material_override = fin_material
		scene.add_child(fin)

		if i % 2 == 0:
			var light_blade := MeshInstance3D.new()
			var blade_mesh := BoxMesh.new()
			blade_mesh.size = Vector3(0.025, 4.8, 0.025)
			light_blade.mesh = blade_mesh
			light_blade.position = Vector3(x + 0.16, 2.75, -2.99)
			var blade_material := StandardMaterial3D.new()
			blade_material.albedo_color = Color("#74d58d")
			blade_material.emission_enabled = true
			blade_material.emission = Color("#267c3c")
			blade_material.emission_energy_multiplier = 0.65
			light_blade.material_override = blade_material
			scene.add_child(light_blade)

	# A wide, low-profile luminous line gives the room a subtle horizon.
	var horizon := MeshInstance3D.new()
	var horizon_mesh := BoxMesh.new()
	horizon_mesh.size = Vector3(13.0, 0.025, 0.035)
	horizon.mesh = horizon_mesh
	horizon.position = Vector3(0.0, 0.22, -2.92)
	var horizon_material := StandardMaterial3D.new()
	horizon_material.albedo_color = Color("#65c77c")
	horizon_material.emission_enabled = true
	horizon_material.emission = Color("#1c6530")
	horizon_material.emission_energy_multiplier = 0.8
	horizon.material_override = horizon_material
	scene.add_child(horizon)

	# Restrained floor inlays add perspective while keeping the centre uncluttered.
	for i in range(7):
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.014, 0.008, 8.0)
		line.mesh = line_mesh
		line.position = Vector3(-5.4 + float(i) * 1.8, -0.035, 1.25)
		var line_material := StandardMaterial3D.new()
		line_material.albedo_color = Color("#1d4a2a")
		line_material.emission_enabled = true
		line_material.emission = Color("#0b2412")
		line_material.roughness = 0.3
		line.material_override = line_material
		scene.add_child(line)

	return scene



func _style_landing_command_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.43, 0.23, 0.82) if primary else Color(0.11, 0.24, 0.15, 0.64)
		if state == "hover":
			style.bg_color = Color(0.22, 0.55, 0.30, 0.94) if primary else Color(0.17, 0.36, 0.22, 0.82)
		elif state == "pressed":
			style.bg_color = Color(0.07, 0.25, 0.12, 0.94)
		elif state == "disabled":
			style.bg_color = Color(0.08, 0.15, 0.10, 0.42)
		style.border_color = Color(0.76, 0.94, 0.79, 0.82) if primary else Color(0.55, 0.76, 0.59, 0.54)
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.border_width_left = 2 if primary else 1
		style.set_corner_radius_all(12)
		style.shadow_color = Color(0.0, 0.035, 0.012, 0.48)
		style.shadow_size = 12 if primary else 8
		style.shadow_offset = Vector2(0, 4)
		style.anti_aliasing = true
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 11
		style.content_margin_bottom = 11
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f4fbf4"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("#d4efd9"))
	button.add_theme_color_override("font_disabled_color", Color("#78917d"))
	_apply_shared_page_typography(button, 16)
	button.add_theme_color_override("font_outline_color", Color("#07170b"))
	button.add_theme_constant_override("outline_size", 1)



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
	_style_settings_dropdown(quality)
	stack.add_child(quality)
	var sound := CheckButton.new()
	sound.text = "Sound enabled"
	sound.button_pressed = sound_enabled
	sound.toggled.connect(func(enabled: bool): sound_enabled = enabled)
	stack.add_child(sound)
	var done_button := _add_action_button(stack, "DONE", true, Callable())
	_apply_shared_page_typography(quality, 15)
	_apply_shared_page_typography(sound, 15)
	done_button.pressed.connect(_close_settings_overlay.bind(shade, center))

func _style_settings_dropdown(selector: OptionButton) -> void:
	selector.focus_mode = Control.FOCUS_NONE
	var field := StyleBoxFlat.new()
	field.bg_color = Color("#102b3b")
	field.border_color = Color("#4db9ed")
	field.set_border_width_all(1)
	field.set_corner_radius_all(9)
	field.content_margin_left = 12
	field.content_margin_right = 12
	field.content_margin_top = 8
	field.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		selector.add_theme_stylebox_override(state, field)
	selector.add_theme_color_override("font_color", Color("#e8f7ff"))
	selector.add_theme_color_override("font_hover_color", Color("#e8f7ff"))
	selector.add_theme_color_override("font_pressed_color", Color("#e8f7ff"))
	selector.add_theme_color_override("font_focus_color", Color("#e8f7ff"))
	var popup := selector.get_popup()
	popup.min_size = Vector2i(maxi(roundi(selector.custom_minimum_size.x), 260), 0)
	popup.add_theme_font_size_override("font_size", 16)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#081c2b")
	panel.border_color = Color("#4db9ed")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(9)
	popup.add_theme_stylebox_override("panel", panel)
	var item_idle := StyleBoxFlat.new()
	item_idle.bg_color = Color("#081c2b")
	item_idle.set_corner_radius_all(5)
	item_idle.content_margin_left = 12
	item_idle.content_margin_right = 12
	item_idle.content_margin_top = 10
	item_idle.content_margin_bottom = 10
	popup.add_theme_stylebox_override("hover", item_idle)
	popup.add_theme_stylebox_override("pressed", item_idle)
	popup.add_theme_stylebox_override("focus", item_idle)
	popup.add_theme_color_override("font_color", Color("#dff4ff"))
	popup.add_theme_color_override("font_hover_color", Color("#dff4ff"))
	popup.add_theme_color_override("font_pressed_color", Color("#dff4ff"))
	popup.add_theme_color_override("font_focus_color", Color("#dff4ff"))
	popup.add_theme_constant_override("v_separation", 10)
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_color_override("font_outline_color", Color("#061522"))


func _close_settings_overlay(shade: Control, center: Control) -> void:
	if is_instance_valid(shade):
		shade.queue_free()
	if is_instance_valid(center):
		center.queue_free()

func _confirm_exit() -> void:
	_show_confirmation("EXIT DIGITAL WORLD MOBILES", "Are you sure you want to leave Digital World Mobiles? Your saved company data will remain on this device.", "EXIT", Callable(self, "_exit_digitalworld"))


func _exit_digitalworld() -> void:
	get_tree().quit()
func _show_confirmation(title_text: String, message_text: String, action_text: String, action: Callable) -> void:
	if is_instance_valid(confirm_modal):
		confirm_modal.show_confirmation(title_text, message_text, action_text, action)


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

func _apply_shared_page_typography(control: Control, font_size: int) -> void:
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 0.7
	control.add_theme_font_override("font", stix_font)
	control.add_theme_font_size_override("font_size", font_size)


func _label(text_value: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	_apply_shared_page_typography(label, size + 2)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _add_action_button(parent: Node, caption: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shared_page_typography(button, 13)
	button.add_theme_color_override("font_color", Color("#ffffff") if primary else Color("#e8eee8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_style_button(button, primary)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _hero_font_base(font_variation: FontVariation) -> void:
	font_variation.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
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
	_apply_shared_page_typography(button, 20)
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
