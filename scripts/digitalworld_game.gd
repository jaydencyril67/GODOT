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
var logo_picker_panel: Control
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
	# Landing menu controls remain visually still during hover, click and focus.
	# Input continues to work; only the interaction highlight is removed.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var base_fill := Color(0.16, 0.43, 0.23, 0.82) if primary else Color(0.11, 0.24, 0.15, 0.64)
	var base_edge := Color(0.76, 0.94, 0.79, 0.82) if primary else Color(0.55, 0.76, 0.59, 0.54)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = base_fill
		style.border_color = base_edge
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
	button.add_theme_color_override("font_hover_color", Color("#f4fbf4"))
	button.add_theme_color_override("font_pressed_color", Color("#f4fbf4"))
	button.add_theme_color_override("font_focus_color", Color("#f4fbf4"))
	button.add_theme_color_override("font_disabled_color", Color("#f4fbf4"))
	_apply_shared_page_typography(button, 16)
	button.add_theme_color_override("font_outline_color", Color("#07170b"))
	button.add_theme_constant_override("outline_size", 1)

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
	_apply_shared_page_typography(button, 22)
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.20, 0.30, 0.72))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 0)

func _start_new_game() -> void:
	# Never overwrite an existing career without the player's explicit approval.
	if FileAccess.file_exists(SAVE_PATH):
		_show_confirmation(
			"START A NEW GAME?",
			"Starting a new game will permanently erase your saved company, money, office, employees, research and all other game progress. This cannot be undone.\n\nDo you want to reset your saved data and start again?",
			"START NEW GAME",
			Callable(self, "_reset_saved_game_and_start")
		)
		return
	_begin_fresh_game()


func _reset_saved_game_and_start() -> void:
	# Delete the persistent save only after the reusable confirmation modal confirms.
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if remove_error != OK:
			_show_notice("SAVE RESET FAILED", "Your existing game data could not be erased. Your saved company has been kept safe.")
			return
	_begin_fresh_game()


func _begin_fresh_game() -> void:
	# Clear every in-memory value that belongs to the previous career as well.
	career = {}
	upgrade_level = 0
	selected_upgrade = 1
	selected_logo_id = 1
	game_date_unix = 1262304000.0
	game_clock_paused = false
	last_saved_game_day = -1
	_dispose_phone_editor()
	_clear_world()
	_show_profile()


func _show_profile() -> void:
	current_screen = "profile"
	_clear_world()
	landing_environment = _build_landing_showroom()
	add_child(landing_environment)
	var root := _new_screen()
	root.modulate.a = 0.0

	# Reuse the landing page's soft vignette and architectural emerald showroom.
	var vignette := ColorRect.new()
	vignette.name = "CompanySetupVignette"
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

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 820.0 or viewport_size.y < 560.0
	var frame := MarginContainer.new()
	frame.name = "CompanySetupFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 18 if compact else 48)
	frame.add_theme_constant_override("margin_right", 18 if compact else 48)
	frame.add_theme_constant_override("margin_top", 18 if compact else 28)
	frame.add_theme_constant_override("margin_bottom", 18 if compact else 28)
	root.add_child(frame)

	var layout: BoxContainer
	if compact:
		var scroll := ScrollContainer.new()
		scroll.name = "CompanySetupScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.follow_focus = true
		frame.add_child(scroll)
		var stacked := VBoxContainer.new()
		stacked.name = "CompanySetupContent"
		stacked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stacked.add_theme_constant_override("separation", 22)
		scroll.add_child(stacked)
		layout = stacked
	else:
		var split := HBoxContainer.new()
		split.name = "CompanySetupLayout"
		split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_theme_constant_override("separation", 24)
		frame.add_child(split)
		layout = split

	# Left side mirrors the landing page's brand and welcome hierarchy.
	var showcase := VBoxContainer.new()
	showcase.name = "CompanySetupShowcase"
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase.size_flags_stretch_ratio = 1.35
	showcase.add_theme_constant_override("separation", 7)
	layout.add_child(showcase)

	var brand := VBoxContainer.new()
	brand.name = "CompanySetupBrand"
	brand.add_theme_constant_override("separation", 4)
	showcase.add_child(brand)
	var brand_name := _label("DIGITAL WORLD", 27 if compact else 29, Color("#f3faf3"))
	_apply_menu_3d_label(brand_name, 1)
	brand.add_child(brand_name)
	brand.add_child(_label("M O B I L E S     /     POWERED BY KINGSHALL", 9 if compact else 10, Color("#9cc9a7")))

	if not compact:
		var showcase_spacer := Control.new()
		showcase_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		showcase.add_child(showcase_spacer)

	var welcome := VBoxContainer.new()
	welcome.name = "CompanySetupWelcome"
	welcome.add_theme_constant_override("separation", 9)
	showcase.add_child(welcome)
	welcome.add_child(_label("YOUR COMPANY. YOUR LEGACY.", 10 if compact else 11, Color("#8fbd9a")))
	var welcome_title := _label("BUILD THE\nNEXT GENERATION.", 27 if compact else 36, Color("#f4f8f3"))
	welcome_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_menu_3d_label(welcome_title, 1)
	welcome.add_child(welcome_title)
	var welcome_caption := _label(
		"Put your name behind the technology.\nChoose an identity and establish your company.",
		13 if compact else 15,
		Color("#b5c7b9")
	)
	welcome_caption.add_theme_constant_override("line_separation", 4)
	welcome.add_child(welcome_caption)

	if compact:
		var lower_spacer := Control.new()
		lower_spacer.custom_minimum_size.y = 4
		showcase.add_child(lower_spacer)

	# Right side follows the landing menu's single glass command panel.
	var command_area := CenterContainer.new()
	command_area.name = "CompanySetupCommandArea"
	command_area.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if compact:
		command_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		command_area.size_flags_horizontal = Control.SIZE_SHRINK_END
		command_area.custom_minimum_size.x = 0.0 if compact else 440.0
	layout.add_child(command_area)

	var command_panel := PanelContainer.new()
	command_panel.name = "CompanySetupCommandPanel"
	command_panel.custom_minimum_size = Vector2(0.0 if compact else 420.0, 0.0)
	command_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.065, 0.039, 0.82)
	panel_style.border_color = Color(0.58, 0.82, 0.63, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.025, 0.008, 0.62)
	panel_style.shadow_size = 28
	panel_style.shadow_offset = Vector2(0, 10)
	panel_style.anti_aliasing = true
	panel_style.content_margin_left = 23 if compact else 26
	panel_style.content_margin_right = 23 if compact else 26
	panel_style.content_margin_top = 22 if compact else 24
	panel_style.content_margin_bottom = 22 if compact else 24
	command_panel.add_theme_stylebox_override("panel", panel_style)
	command_area.add_child(command_panel)

	var menu := VBoxContainer.new()
	menu.name = "CompanySetupForm"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation", 9)
	command_panel.add_child(menu)
	menu.add_child(_label("CREATE YOUR COMPANY", 21 if compact else 23, Color("#f1f7f0"), HORIZONTAL_ALIGNMENT_CENTER))
	var menu_rule := ColorRect.new()
	menu_rule.custom_minimum_size = Vector2(0, 1)
	menu_rule.color = Color(0.58, 0.82, 0.63, 0.48)
	menu.add_child(menu_rule)

	menu.add_child(_label("FOUNDER NAME", 11, Color("#c9e5cd")))
	full_name_input = LineEdit.new()
	full_name_input.name = "FounderNameInput"
	full_name_input.placeholder_text = "Enter your full name"
	full_name_input.text = str(career.get("full_name", ""))
	full_name_input.custom_minimum_size = Vector2(0, 52)
	full_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shared_page_typography(full_name_input, 17)
	_style_company_setup_input(full_name_input)
	menu.add_child(full_name_input)

	menu.add_child(_label("COMPANY NAME", 11, Color("#c9e5cd")))
	company_name_input = LineEdit.new()
	company_name_input.name = "CompanyNameInput"
	company_name_input.placeholder_text = "Enter your company name"
	company_name_input.text = str(career.get("company_name", ""))
	company_name_input.custom_minimum_size = Vector2(0, 52)
	company_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shared_page_typography(company_name_input, 17)
	_style_company_setup_input(company_name_input)
	menu.add_child(company_name_input)

	menu.add_child(_label("COMPANY INSIGNIA", 11, Color("#c9e5cd")))
	selected_logo_id = clampi(int(career.get("logo_id", 1)), 1, 50)
	var preview_panel := PanelContainer.new()
	preview_panel.name = "CompanyInsigniaPreview"
	preview_panel.custom_minimum_size = Vector2(0, 86 if compact else 92)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.30, 0.62, 0.36, 0.12)
	preview_style.border_color = Color(0.72, 0.91, 0.75, 0.32)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(13)
	preview_style.content_margin_left = 10
	preview_style.content_margin_right = 10
	preview_style.content_margin_top = 8
	preview_style.content_margin_bottom = 8
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	menu.add_child(preview_panel)

	var preview_row := HBoxContainer.new()
	preview_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 13)
	preview_panel.add_child(preview_row)
	insignia_preview = TextureRect.new()
	insignia_preview.name = "SelectedInsigniaTexture"
	insignia_preview.custom_minimum_size = Vector2(68, 68)
	insignia_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insignia_preview.texture = _company_logo_texture(selected_logo_id)
	preview_row.add_child(insignia_preview)
	var preview_copy := VBoxContainer.new()
	preview_copy.name = "PreviewCopy"
	preview_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_copy.add_theme_constant_override("separation", 4)
	preview_copy.add_child(_label("YOUR SELECTED MARK", 9, Color("#a8d5b0")))
	var selected_name := _label("%02d / 50  ·  %s" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1].to_upper()], 12, Color("#f3faf3"))
	selected_name.name = "SelectedInsigniaName"
	preview_copy.add_child(selected_name)
	preview_row.add_child(preview_copy)

	logo_option = Button.new()
	logo_option.name = "ChangeCompanyInsignia"
	logo_option.text = "CHANGE INSIGNIA  ›"
	logo_option.custom_minimum_size = Vector2(0, 46)
	logo_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shared_page_typography(logo_option, 14)
	_style_company_glass_button(logo_option)
	logo_option.pressed.connect(_open_logo_picker)
	menu.add_child(logo_option)

	profile_status = _label("", 12, Color("#ffd0a8"))
	profile_status.name = "CompanySetupStatus"
	profile_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(profile_status)

	var establish_button := _add_action_button(menu, "ESTABLISH COMPANY  ›", true, _create_company)
	establish_button.custom_minimum_size = Vector2(0, 54)
	establish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_landing_command_button(establish_button, true)
	var back_button := _add_action_button(menu, "BACK TO MENU", false, _show_menu)
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_landing_command_button(back_button, false)

	var entrance := create_tween()
	entrance.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(root, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _style_company_setup_input(field: LineEdit) -> void:
	field.add_theme_color_override("font_color", Color("#f3faf3"))
	field.add_theme_color_override("font_placeholder_color", Color("#8eaa94"))
	field.add_theme_color_override("caret_color", Color("#b3e7bb"))
	field.add_theme_color_override("selection_color", Color(0.24, 0.62, 0.34, 0.38))
	for state in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.008, 0.035, 0.018, 0.82)
		style.border_color = Color(0.60, 0.82, 0.63, 0.58)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 13
		style.content_margin_right = 13
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		field.add_theme_stylebox_override(state, style)


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
	logo_picker_layer.name = "CompanyInsigniaSelection"
	logo_picker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(logo_picker_layer)

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 760.0 or viewport_size.y < 560.0
	var side_margin := 18.0 if compact else 34.0
	var top_margin := 12.0 if compact else 22.0
	var bottom_margin := 12.0 if compact else 22.0
	var grid_gap := 4 if compact else 7
	var available_width := maxf(1.0, viewport_size.x - side_margin * 2.0)
	var header_space := 78.0 if compact else 108.0
	var footer_space := 46.0 if compact else 58.0
	var grid_area_height := maxf(64.0, viewport_size.y - top_margin - bottom_margin - header_space - footer_space - 24.0)

	# Pick the column count that gives all 50 marks the largest possible square footprint.
	# This makes the complete selection fit on screen without a scroll container.
	var columns := 2
	var tile_size := 1
	for candidate_columns in range(2, 15):
		var candidate_rows := int(ceil(50.0 / float(candidate_columns)))
		var width_fit := int(floor((available_width - grid_gap * (candidate_columns - 1)) / candidate_columns))
		var height_fit := int(floor((grid_area_height - grid_gap * (candidate_rows - 1)) / candidate_rows))
		var candidate_size := mini(104, mini(maxi(1, width_fit), maxi(1, height_fit)))
		if candidate_size > tile_size:
			columns = candidate_columns
			tile_size = candidate_size

	var rows := int(ceil(50.0 / float(columns)))
	var grid_width := float(columns * tile_size + (columns - 1) * grid_gap)
	var grid_height := float(rows * tile_size + (rows - 1) * grid_gap)

	# Match Settings and Exit: a dedicated deep-emerald screen with centred content.
	var scrim := ColorRect.new()
	scrim.name = "InsigniaDarkScreen"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.002, 0.018, 0.009, 0.96)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	logo_picker_layer.add_child(scrim)

	var center := CenterContainer.new()
	center.name = "InsigniaDirectContent"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = side_margin
	center.offset_right = -side_margin
	center.offset_top = top_margin
	center.offset_bottom = -bottom_margin
	logo_picker_layer.add_child(center)

	var stack := VBoxContainer.new()
	stack.name = "InsigniaScreenLayout"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.custom_minimum_size.x = minf(1240.0, available_width)
	stack.add_theme_constant_override("separation", 8 if compact else 12)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stack)

	var accent := ColorRect.new()
	accent.name = "InsigniaAccent"
	accent.custom_minimum_size = Vector2(76 if compact else 96, 3)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color("#a9d9ad")
	stack.add_child(accent)

	var eyebrow := _label("DIGITAL WORLD MOBILES", 10 if compact else 13, Color("#a9d9ad"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(eyebrow)
	var heading := _label("CHOOSE YOUR INSIGNIA", 22 if compact else 30, Color("#f4fff3"), HORIZONTAL_ALIGNMENT_CENTER)
	_apply_menu_3d_label(heading, 2)
	stack.add_child(heading)
	var description := _label("50 distinctive marks  ·  Select one to represent your company", 11 if compact else 14, Color("#c4d9c7"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(description)

	# This fixed-height viewport is intentionally non-scrollable; every logo is visible.
	var grid_viewport := ScrollContainer.new()
	grid_viewport.name = "InsigniaGridViewport"
	grid_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_viewport.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid_viewport.custom_minimum_size = Vector2(0.0, grid_height)
	grid_viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_viewport.follow_focus = false
	grid_viewport.clip_contents = true
	logo_picker_scroll = grid_viewport
	logo_picker_panel = logo_picker_layer
	stack.add_child(grid_viewport)

	var grid_alignment := CenterContainer.new()
	grid_alignment.name = "InsigniaGridAlignment"
	grid_alignment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_alignment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_viewport.add_child(grid_alignment)

	var grid := GridContainer.new()
	grid.name = "InsigniaGrid"
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.custom_minimum_size = Vector2(grid_width, grid_height)
	grid.add_theme_constant_override("h_separation", grid_gap)
	grid.add_theme_constant_override("v_separation", grid_gap)
	logo_picker_grid = grid
	grid_alignment.add_child(grid)

	for index in range(50):
		var logo_id := index + 1
		var option := Button.new()
		option.name = "InsigniaOption_%02d" % logo_id
		option.custom_minimum_size = Vector2(tile_size, tile_size)
		option.toggle_mode = false
		option.focus_mode = Control.FOCUS_NONE
		option.mouse_filter = Control.MOUSE_FILTER_IGNORE
		option.mouse_default_cursor_shape = Control.CURSOR_ARROW
		option.clip_contents = true
		option.flat = true
		var no_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			option.add_theme_stylebox_override(state, no_style)

		var logo_center := CenterContainer.new()
		logo_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		logo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := TextureRect.new()
		var mark_size := mini(84, maxi(1, int(tile_size * 0.84)))
		mark.custom_minimum_size = Vector2(mark_size, mark_size)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.texture = _company_logo_texture(logo_id)
		logo_center.add_child(mark)
		option.add_child(logo_center)
		grid.add_child(option)

	var footer := Button.new()
	footer.name = "InsigniaCancelButton"
	footer.text = "CANCEL"
	footer.custom_minimum_size = Vector2(0.0, 38 if compact else 46)
	footer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer.focus_mode = Control.FOCUS_NONE
	footer.mouse_default_cursor_shape = Control.CURSOR_ARROW
	footer.pressed.connect(_close_logo_picker)
	_style_landing_command_button(footer, false)
	_apply_shared_page_typography(footer, 13 if compact else 16)
	stack.add_child(footer)


func _style_company_glass_button(button: Button, _selected: bool = false) -> void:
	# Emerald frosted glass with a clean highlight; interactions never flash.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.46, 0.24, 0.34)
	style.border_color = Color(0.72, 0.91, 0.75, 0.54)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.025, 0.008, 0.24)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = true
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f3faf3"))
	button.add_theme_color_override("font_hover_color", Color("#f3faf3"))
	button.add_theme_color_override("font_pressed_color", Color("#f3faf3"))
	button.add_theme_color_override("font_focus_color", Color("#f3faf3"))
	button.add_theme_color_override("font_disabled_color", Color("#f3faf3"))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.03, 0.0))
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


func _logo_picker_logo_at(local_position: Vector2) -> int:
	if not is_instance_valid(logo_picker_grid):
		return 0
	for index in range(logo_picker_grid.get_child_count()):
		var tile := logo_picker_grid.get_child(index) as Control
		if is_instance_valid(tile) and tile.get_global_rect().has_point(local_position):
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
	style.bg_color = Color(0.20, 0.52, 0.27, 0.38) if selected else Color(0.18, 0.46, 0.24, 0.24)
	style.border_color = Color(0.76, 0.94, 0.79, 0.70) if selected else Color(0.72, 0.91, 0.75, 0.36)
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
	logo_option.text = "CHANGE INSIGNIA  ›"
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
	if not career.has("balance"):
		career["balance"] = 10000000.0
	if not career.has("research_points"):
		career["research_points"] = 0
	if not career.has("research_points_progress"):
		career["research_points_progress"] = 0.0
	if not career.has("game_date_unix"):
		game_date_unix = 1262304000.0
		career["game_date_unix"] = game_date_unix
	if not career.has("game_clock_paused"):
		game_clock_paused = false
		career["game_clock_paused"] = false
	if not career.has("last_rent_billed_month"):
		career["last_rent_billed_month"] = _get_game_month_key(game_date_unix)
	if not career.has("last_payroll_billed_month"):
		career["last_payroll_billed_month"] = _get_game_month_key(game_date_unix)
	_ensure_staff_data()
	if str(career.get("created_at", "")).is_empty():
		career["created_at"] = Time.get_datetime_string_from_system(true)
	upgrade_level = 0
	career["upgrade_level"] = upgrade_level
	if not _save_career():
		profile_status.text = "The company could not be saved. Check device storage."
		return
	_show_city()

func _load_game_pressed() -> void:
	if _load_career():
		_show_city()
	else:
		_show_notice("NO SAVED COMPANY", "No saved Digital World Mobiles company was found on this device. Choose NEW GAME to establish one.")

func _show_city() -> void:
	# Every new or returning company lands on Home at its currently owned building.
	upgrade_level = clampi(upgrade_level, 0, 10)
	selected_upgrade = maxi(upgrade_level, 1)
	_process_pending_monthly_expenses()
	_show_home_scene()


func _show_home_scene() -> void:
	current_screen = "home"
	_clear_world()
	_show_headquarters_loading_screen()
	# Let the HQ preparation screen render before refreshing the market and generating buildings.
	await get_tree().process_frame
	_refresh_staff_market_on_startup()

	var headquarters = HeadquartersPreviewScript.new()
	headquarters.name = "DigitalWorld_Home_Scene"
	headquarters.home_mode = true
	headquarters.preview_level = clampi(upgrade_level, 1, 10)
	headquarters.owned_level = clampi(upgrade_level, 0, 10)
	headquarters.company_name = str(career.get("company_name", "YOUR COMPANY"))
	headquarters.company_balance = float(career.get("balance", 10000000.0))
	headquarters.preview_level_changed.connect(_on_headquarters_preview_level_changed)
	headquarters.back_requested.connect(_return_home_from_headquarters)
	headquarters.upgrade_requested.connect(_upgrade_headquarters)
	headquarters.downgrade_requested.connect(_downgrade_headquarters)
	headquarters.staff_market_requested.connect(func(): _open_staff_screen("market"))
	headquarters.staff_management_requested.connect(func(): _open_staff_screen("management"))
	headquarters.setup_progress.connect(_update_headquarters_loading)
	headquarters.setup_completed.connect(_finish_headquarters_loading)
	world_root = headquarters
	add_child(world_root)


func _show_headquarters_preview() -> void:
	_close_staff_overlay()
	current_screen = "headquarters"
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	ui_layer = null
	ui_root = null
	if is_instance_valid(world_root) and world_root.has_method("set_home_mode"):
		world_root.set_preview_active(true)
		world_root.set_home_mode(false)


func _return_home_from_headquarters() -> void:
	current_screen = "home"
	if is_instance_valid(world_root) and world_root.has_method("set_home_mode"):
		world_root.set_home_mode(true)
		world_root.set_preview_active(true)
	_show_home_navigation()


func _upgrade_headquarters(level: int) -> void:
	var requested_level := clampi(level, 1, 10)
	if requested_level <= upgrade_level:
		return
	var is_first_purchase := upgrade_level <= 0 and requested_level == 1
	var upgrade_cost := float(HeadquartersPreviewScript.get_upgrade_cost(requested_level))
	var previous_balance := float(career.get("balance", 10000000.0))
	if previous_balance < upgrade_cost:
		_show_notice("INSUFFICIENT BALANCE", "You need %s to purchase Headquarters Level %d. Your available balance is %s." % [_format_balance(upgrade_cost), requested_level, _format_balance(previous_balance)])
		return
	var confirmation_title := "PURCHASE HEADQUARTERS" if is_first_purchase else "UPGRADE HEADQUARTERS"
	var confirmation_message := "Purchase your first headquarters (Level %d)?\n\nPurchase price: %s\nAvailable balance: %s" % [requested_level, _format_balance(upgrade_cost), _format_balance(previous_balance)] if is_first_purchase else "Upgrade your headquarters to Level %d?\n\nCost: %s\nAvailable balance: %s" % [requested_level, _format_balance(upgrade_cost), _format_balance(previous_balance)]
	var confirmation_action := "PURCHASE" if is_first_purchase else "UPGRADE"
	_show_confirmation(confirmation_title, confirmation_message, confirmation_action, Callable(self, "_apply_headquarters_upgrade").bind(requested_level))


func _apply_headquarters_upgrade(requested_level: int) -> void:
	if requested_level <= upgrade_level:
		return
	var upgrade_cost := float(HeadquartersPreviewScript.get_upgrade_cost(requested_level))
	var previous_balance := float(career.get("balance", 10000000.0))
	if previous_balance < upgrade_cost:
		_show_notice("INSUFFICIENT BALANCE", "You need %s to relocate to Headquarters Level %d. Your available balance is %s." % [_format_balance(upgrade_cost), requested_level, _format_balance(previous_balance)])
		return
	var previous_level := upgrade_level
	upgrade_level = requested_level
	career["upgrade_level"] = upgrade_level
	career["balance"] = previous_balance - upgrade_cost
	if not _save_career():
		upgrade_level = previous_level
		career["upgrade_level"] = previous_level
		career["balance"] = previous_balance
		_show_notice("UPGRADE NOT SAVED", "Your headquarters upgrade and payment could not be saved. No money was deducted. Please try again.")
		return
	if is_instance_valid(world_root):
		if world_root.has_method("set_owned_level"):
			world_root.set_owned_level(upgrade_level)
		if world_root.has_method("set_company_balance"):
			world_root.set_company_balance(float(career["balance"]))
	# The staff pages are prebuilt before purchase. Refresh both cached screens
	# now so their hire buttons receive the newly purchased office capacity.
	_refresh_staff_screen_data()
	_update_home_status_bar()
	_show_finance_toast(-upgrade_cost, "HEADQUARTERS UPGRADE")

func _downgrade_headquarters(level: int, refund_percent: int) -> void:
	var requested_level := clampi(level, 1, 10)
	if requested_level >= upgrade_level:
		return
	var previous_level := upgrade_level
	var safe_refund_percent := clampi(refund_percent, 50, 60)
	var amount_paid := float(HeadquartersPreviewScript.get_upgrade_cost(previous_level))
	var refund_amount := amount_paid * float(safe_refund_percent) / 100.0
	_show_confirmation("DOWNGRADE HEADQUARTERS", "Downgrade your headquarters to Level %d?\n\nEstimated refund: %s (%d%%)." % [requested_level, _format_balance(refund_amount), safe_refund_percent], "DOWNGRADE", Callable(self, "_apply_headquarters_downgrade").bind(requested_level, safe_refund_percent))


func _apply_headquarters_downgrade(requested_level: int, refund_percent: int) -> void:
	if requested_level >= upgrade_level:
		return
	var previous_level := upgrade_level
	var previous_balance := float(career.get("balance", 10000000.0))
	var safe_refund_percent := clampi(refund_percent, 50, 60)
	var amount_paid := float(HeadquartersPreviewScript.get_upgrade_cost(previous_level))
	var refund_amount := amount_paid * float(safe_refund_percent) / 100.0
	upgrade_level = requested_level
	career["upgrade_level"] = upgrade_level
	career["balance"] = previous_balance + refund_amount
	if not _save_career():
		upgrade_level = previous_level
		career["upgrade_level"] = previous_level
		career["balance"] = previous_balance
		_show_notice("DOWNGRADE NOT SAVED", "Your headquarters downgrade and refund could not be saved. Your building and balance have not changed.")
		return
	if is_instance_valid(world_root):
		if world_root.has_method("set_owned_level"):
			world_root.set_owned_level(upgrade_level)
		if world_root.has_method("set_company_balance"):
			world_root.set_company_balance(float(career["balance"]))
	_update_home_status_bar()
	_show_finance_toast(refund_amount, "HEADQUARTERS REFUND")

func _apply_home_button_typography(button: Control, font_size: int) -> void:
	# Use the project STIX variable font explicitly and strengthen its weight
	# without changing any button dimensions, layout, or visual styling.
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 0.7
	button.add_theme_font_override("font", stix_font)
	button.add_theme_font_size_override("font_size", font_size)


func _show_home_navigation() -> void:
	# Let _new_screen() retire the previous screen before creating Home UI.
	# Clearing ui_layer here would orphan the previous CanvasLayer on screen.
	var root := _new_screen()
	ui_layer.layer = 30
	home_navigation_layer = ui_layer

	_build_home_status_bar(root)

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "Home_Bottom_Navigation"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 8.0
	bottom_panel.offset_top = -78.0
	bottom_panel.offset_right = -8.0
	bottom_panel.offset_bottom = -8.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#102638")
	panel_style.border_color = Color("#397da5")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 7.0
	panel_style.content_margin_right = 7.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 6.0
	bottom_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(bottom_panel)

	var row := HBoxContainer.new()
	row.name = "Home_Navigation_Buttons_Row"
	row.add_theme_constant_override("separation", 5)
	bottom_panel.add_child(row)
	for button_name in ["Create", "Products", "Research", "Marketing", "Media", "Office", "Statistics"]:
		var button := Button.new()
		button.name = button_name + "_Button"
		button.text = button_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 54.0)
		_apply_home_button_typography(button, 14)
		_style_button(button, false)
		if button_name == "Create":
			button.pressed.connect(_show_create_scene)
		elif button_name == "Research":
			button.pressed.connect(_show_research_scene)
		elif button_name == "Office":
			button.pressed.connect(_show_office_hub)
		row.add_child(button)


func _build_home_status_bar(root: Control) -> void:
	var cards_row := HBoxContainer.new()
	cards_row.name = "Home_Individual_Glass_Cards"
	cards_row.anchor_left = 0.0
	cards_row.anchor_top = 0.0
	cards_row.anchor_right = 1.0
	cards_row.anchor_bottom = 0.0
	cards_row.offset_left = 12.0
	cards_row.offset_top = 10.0
	cards_row.offset_right = -12.0
	cards_row.offset_bottom = 78.0
	cards_row.add_theme_constant_override("separation", 10)
	cards_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(cards_row)

	# Each status item is an independent glass card with its own spacing,
	# border and highlight. There is deliberately no shared parent panel.
	var company_card := _make_home_status_glass_card("Company_Name_Card")
	company_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	company_card.custom_minimum_size = Vector2(0.0, 62.0)
	cards_row.add_child(company_card)
	home_company_label = Label.new()
	home_company_label.name = "Company_Name"
	home_company_label.text = str(career.get("company_name", "YOUR COMPANY"))
	home_company_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_company_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home_company_label.clip_text = false
	home_company_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	home_company_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	home_company_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_company_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_shared_page_typography(home_company_label, 19)
	home_company_label.add_theme_color_override("font_color", Color("#ffffff"))
	company_card.add_child(home_company_label)

	# Push the financial, date and clock cards together to the far right.
	var status_spacer := Control.new()
	status_spacer.name = "Home_Status_Flexible_Spacer"
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_child(status_spacer)

	var balance_card := _make_home_status_glass_card("Company_Balance_Card")
	balance_card.custom_minimum_size = Vector2(150.0, 62.0)
	cards_row.add_child(balance_card)
	home_balance_label = Label.new()
	home_balance_label.name = "Company_Balance"
	home_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_shared_page_typography(home_balance_label, 18)
	home_balance_label.add_theme_color_override("font_color", Color("#b8f6df"))
	balance_card.add_child(home_balance_label)

	var research_points_card := _make_home_status_glass_card("Research_Points_Card")
	research_points_card.custom_minimum_size = Vector2(150.0, 62.0)
	cards_row.add_child(research_points_card)
	home_research_points_label = Label.new()
	home_research_points_label.name = "Research_Points"
	home_research_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_research_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_shared_page_typography(home_research_points_label, 14)
	home_research_points_label.add_theme_color_override("font_color", Color("#d8e6ff"))
	research_points_card.add_child(home_research_points_label)

	var date_card := _make_home_status_glass_card("Game_Date_Card")
	date_card.custom_minimum_size = Vector2(154.0, 62.0)
	cards_row.add_child(date_card)
	home_date_label = Label.new()
	home_date_label.name = "Game_Date"
	home_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_shared_page_typography(home_date_label, 17)
	home_date_label.add_theme_color_override("font_color", Color("#c8edff"))
	date_card.add_child(home_date_label)

	var clock_card := _make_home_status_glass_card("Game_Clock_Card")
	clock_card.custom_minimum_size = Vector2(118.0, 62.0)
	cards_row.add_child(clock_card)
	home_time_button = Button.new()
	home_time_button.name = "Game_Time_Control"
	home_time_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_time_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_home_button_typography(home_time_button, 15)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(0.10, 0.48, 0.70, 0.24)
		if state == "hover":
			button_style.bg_color = Color(0.20, 0.68, 0.88, 0.38)
		elif state == "pressed":
			button_style.bg_color = Color(0.04, 0.32, 0.52, 0.42)
		elif state == "disabled":
			button_style.bg_color = Color(0.10, 0.20, 0.27, 0.18)
		button_style.set_corner_radius_all(11)
		button_style.border_color = Color(0.60, 0.88, 1.0, 0.46)
		button_style.set_border_width_all(1)
		home_time_button.add_theme_stylebox_override(state, button_style)
	home_time_button.add_theme_color_override("font_color", Color("#ffffff"))
	home_time_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	home_time_button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	home_time_button.pressed.connect(_toggle_game_clock)
	clock_card.add_child(home_time_button)

	_update_home_status_bar()


func _make_home_status_glass_card(card_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.28, 0.40, 0.38)
	style.border_color = Color(0.58, 0.84, 0.98, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0.0, 0.04, 0.12, 0.34)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	card.add_theme_stylebox_override("panel", style)
	return card

func _format_game_date(timestamp: float) -> String:
	var date := Time.get_datetime_dict_from_unix_time(floori(timestamp))
	var day := int(date["day"])
	var suffix := "th"
	if day % 100 < 11 or day % 100 > 13:
		match day % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	var month_names := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d%s %s %04d" % [day, suffix, month_names[int(date["month"]) - 1], int(date["year"])]


func _get_research_department_stats() -> Dictionary:
	var research_staff_count := 0
	var total_efficiency := 0.0
	for employee_value in career.get("staff_employees", []):
		if not (employee_value is Dictionary):
			continue
		var employee: Dictionary = employee_value
		if str(employee.get("department", "")) != "Research":
			continue
		research_staff_count += 1
		total_efficiency += float(clampi(int(employee.get("efficiency", 0)), 0, 100))

	var average_efficiency := total_efficiency / float(research_staff_count) if research_staff_count > 0 else 0.0
	# One researcher at 100% efficiency produces one point per in-game day.
	# Summing individual efficiency is equivalent to staff count multiplied by average efficiency.
	var daily_output := total_efficiency / 100.0
	return {
		"staff_count": research_staff_count,
		"average_efficiency": average_efficiency,
		"daily_output": daily_output
	}


func _accrue_research_points(game_time_delta: float) -> void:
	if game_time_delta <= 0.0:
		return
	var research_stats := _get_research_department_stats()
	var daily_output := float(research_stats.get("daily_output", 0.0))
	if daily_output <= 0.0:
		return

	var accumulated_progress := maxf(0.0, float(career.get("research_points_progress", 0.0)))
	accumulated_progress += daily_output * game_time_delta / 86400.0
	var whole_points := floori(accumulated_progress)
	if whole_points > 0:
		career["research_points"] = maxi(0, int(career.get("research_points", 0))) + whole_points
		accumulated_progress -= float(whole_points)
	career["research_points_progress"] = clampf(accumulated_progress, 0.0, 0.9999999)


func _format_count(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return formatted


func _format_balance(amount: float) -> String:
	var digits := str(roundi(amount))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted


func _update_home_status_bar() -> void:
	if is_instance_valid(home_date_label):
		home_date_label.text = _format_game_date(game_date_unix)
	if is_instance_valid(home_balance_label):
		home_balance_label.text = _format_balance(float(career.get("balance", 10000000.0)))
	if is_instance_valid(home_research_points_label):
		home_research_points_label.text = "%s RESEARCH PTS" % _format_count(int(career.get("research_points", 0)))
	if is_instance_valid(home_company_label):
		home_company_label.text = str(career.get("company_name", "YOUR COMPANY"))
		var company_card := home_company_label.get_parent() as PanelContainer
		var cards_row := company_card.get_parent() as HBoxContainer if is_instance_valid(company_card) else null
		if is_instance_valid(company_card):
			var company_font := home_company_label.get_theme_font("font")
			var text_width := company_font.get_string_size(home_company_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			# Reserve room for the four fixed status cards, their gaps and the row margins.
			# The company card uses the remaining width, growing naturally for longer names.
			var viewport_width := get_viewport().get_visible_rect().size.x
			var maximum_company_width := maxf(110.0, viewport_width - 636.0)
			var company_width := minf(text_width + 24.0, maximum_company_width)
			var usable_text_width := maxf(1.0, company_width - 24.0)
			var estimated_lines := maxi(1, ceili(text_width / usable_text_width))
			var company_height := maxf(62.0, float(estimated_lines) * 23.0 + 20.0)
			company_card.custom_minimum_size = Vector2(company_width, company_height)
			home_company_label.custom_minimum_size.y = maxf(42.0, float(estimated_lines) * 23.0)
			if is_instance_valid(cards_row):
				cards_row.offset_bottom = 10.0 + company_height
	if is_instance_valid(home_time_button):
		home_time_button.text = "▶ PLAY" if game_clock_paused else "Ⅱ PAUSE"


func _show_finance_toast(amount: float, activity: String) -> void:
	# Attach the floating text to whichever balance display is currently visible:
	# the Home status card or the headquarters finance panel.
	var toast_parent: Control
	var toast_y := 68.0
	if is_instance_valid(home_balance_label) and home_balance_label.is_visible_in_tree():
		toast_parent = home_balance_label.get_parent() as Control
	elif is_instance_valid(world_root):
		var hq_balance_label := world_root.get("available_balance_label") as Control
		if is_instance_valid(hq_balance_label) and hq_balance_label.is_visible_in_tree():
			toast_parent = hq_balance_label
			toast_y = 22.0
	if not is_instance_valid(toast_parent):
		return
	if is_instance_valid(home_finance_toast_tween):
		home_finance_toast_tween.kill()
	if is_instance_valid(home_finance_toast):
		home_finance_toast.queue_free()

	var received := amount >= 0.0
	var toast := Label.new()
	toast.name = "Home_Financial_Activity_Toast"
	toast.z_index = 100
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.custom_minimum_size = Vector2(230.0, 38.0)
	toast.size = Vector2(230.0, 38.0)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-115.0, toast_y)
	toast.modulate.a = 0.0
	toast.text = ("+" if received else "−") + _format_balance(absf(amount)) + "  ·  " + activity
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 13)
	toast.add_theme_color_override("font_color", Color("#baffdf") if received else Color("#ffd0ca"))
	toast.clip_text = true
	toast.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toast_parent.add_child(toast)
	home_finance_toast = toast

	home_finance_toast_tween = create_tween()
	home_finance_toast_tween.set_trans(Tween.TRANS_CUBIC)
	home_finance_toast_tween.set_ease(Tween.EASE_OUT)
	home_finance_toast_tween.tween_property(toast, "position:y", toast_y + 6.0, 0.16)
	home_finance_toast_tween.parallel().tween_property(toast, "modulate:a", 1.0, 0.16)
	home_finance_toast_tween.tween_interval(1.8)
	home_finance_toast_tween.set_ease(Tween.EASE_IN)
	home_finance_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.22)
	home_finance_toast_tween.tween_callback(func():
		if is_instance_valid(toast):
			toast.queue_free()
		if home_finance_toast == toast:
			home_finance_toast = null
	)


func _toggle_game_clock() -> void:
	game_clock_paused = not game_clock_paused
	career["game_clock_paused"] = game_clock_paused
	_save_career()
	_update_home_status_bar()


func _show_headquarters_loading_screen() -> void:
	var root := _new_screen()
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "Headquarters_Preparation_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#071b2c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var accent := ColorRect.new()
	accent.name = "Preparation_Accent"
	accent.anchor_left = 0.0
	accent.anchor_top = 0.0
	accent.anchor_right = 1.0
	accent.anchor_bottom = 0.0
	accent.offset_bottom = 5.0
	accent.color = Color("#249bd3")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(accent)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var content := VBoxContainer.new()
	content.name = "Headquarters_Preparation_Content"
	content.custom_minimum_size = Vector2(420.0, 0.0)
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 18)
	center.add_child(content)

	var brand := Label.new()
	brand.text = "DIGITAL WORLD MOBILES"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_home_button_typography(brand, 18)
	brand.add_theme_color_override("font_color", Color("#72cfff"))
	content.add_child(brand)

	var title := Label.new()
	title.text = "Preparing your headquarters"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_home_button_typography(title, 32)
	title.add_theme_color_override("font_color", Color("#ffffff"))
	content.add_child(title)

	var company_label := Label.new()
	company_label.text = str(career.get("company_name", "YOUR COMPANY"))
	company_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_home_button_typography(company_label, 19)
	company_label.add_theme_color_override("font_color", Color("#b9dff3"))
	content.add_child(company_label)

	loading_status_label = Label.new()
	loading_status_label.name = "Preparation_Status"
	loading_status_label.text = "Initializing game..."
	loading_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_home_button_typography(loading_status_label, 18)
	loading_status_label.add_theme_color_override("font_color", Color("#e3f4ff"))
	content.add_child(loading_status_label)

	loading_progress_bar = ProgressBar.new()
	loading_progress_bar.name = "Preparation_Progress"
	loading_progress_bar.custom_minimum_size = Vector2(0.0, 9.0)
	loading_progress_bar.min_value = 0.0
	loading_progress_bar.max_value = 100.0
	loading_progress_bar.value = 5.0
	loading_progress_bar.show_percentage = false
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color("#1c3b50")
	progress_style.set_corner_radius_all(6)
	loading_progress_bar.add_theme_stylebox_override("background", progress_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#35b7ee")
	fill_style.set_corner_radius_all(6)
	loading_progress_bar.add_theme_stylebox_override("fill", fill_style)
	content.add_child(loading_progress_bar)


func _update_headquarters_loading(message: String, progress: float) -> void:
	if is_instance_valid(loading_status_label):
		loading_status_label.text = message
	if is_instance_valid(loading_progress_bar):
		loading_progress_bar.value = clampf(progress, 0.0, 100.0)


func _finish_headquarters_loading() -> void:
	# Prepare both staff pages while the HQ loading screen is still active.
	# HQ buttons will only reveal these already-built controls.
	_prepare_staff_scenes()
	var preparation_layer := ui_layer
	ui_layer = null
	ui_root = null
	loading_status_label = null
	loading_progress_bar = null

	_show_home_navigation()
	if is_instance_valid(preparation_layer):
		preparation_layer.queue_free()


func _show_create_scene() -> void:
	current_screen = "create"
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	if is_instance_valid(world_root) and world_root.has_method("set_preview_active"):
		world_root.set_preview_active(false)

	# Keep the product interface alive after its first construction. Opening it
	# again only reveals the existing controls instead of rebuilding the page.
	if is_instance_valid(create_ui_layer) and is_instance_valid(create_ui_root):
		if is_instance_valid(ui_layer) and ui_layer != create_ui_layer:
			ui_layer.queue_free()
		ui_layer = create_ui_layer
		ui_root = create_ui_root
		ui_layer.show()
		return

	var root := _new_screen()
	create_ui_layer = ui_layer
	create_ui_root = ui_root

	# Use the same background, overlay, scroll, margins, typography and glass-card
	# construction as the founder setup page.
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
	shade.color = Color(0.008, 0.035, 0.065, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.name = "CreateSceneScroll"
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
	page.name = "CreateSceneContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	page_margin.add_child(page)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	page.add_child(header)
	header.add_child(_label("DIGITAL WORLD MOBILES  /  PRODUCT STUDIO", 11 if compact else 13, Color("#a9e3ff")))

	# Keep the hero title and Back control together on one horizontal header row.
	var hero_row := HBoxContainer.new()
	hero_row.name = "CreateHeroRow"
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_theme_constant_override("separation", 12)
	header.add_child(hero_row)
	var title := _label("CREATE A NEW PRODUCT", 27 if compact else 36, Color("#ffffff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_row.add_child(title)
	var back_button := _add_action_button(hero_row, "BACK", false, _return_to_home)
	back_button.custom_minimum_size = Vector2(104 if compact else 120, 46 if compact else 50)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_shared_page_typography(back_button, 15 if compact else 16)
	_style_create_glass_button(back_button, false)

	header.add_child(_label("Choose a product category to begin designing your next device.", 13 if compact else 15, Color("#d8efff")))

	var section := VBoxContainer.new()
	section.name = "ProductCategoriesSection"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)
	page.add_child(section)
	section.add_child(_label("01  /  PRODUCT CATEGORIES", 12, Color("#a9e3ff")))

	var grid := GridContainer.new()
	grid.name = "Create_Category_Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	section.add_child(grid)

	var horizontal_page_width := maxf(0.0, viewport_size.x - (36.0 if compact else 84.0))
	var card_width := maxf(1.0, (horizontal_page_width - 14.0) * 0.5)
	var card_height := maxf(132.0, minf(220.0, card_width * 0.82))
	var categories := [
		{"name": "PHONE", "number": "01", "description": "Design the complete smartphone, from its exterior to its user experience."},
		{"name": "PROCESSOR", "number": "02", "description": "Develop mobile chipsets and next-generation processing technology."},
		{"name": "OPERATING SYSTEM", "number": "03", "description": "Create the software platform that powers the phone and its features."},
		{"name": "CAMERA", "number": "04", "description": "Develop smartphone camera systems, sensors and imaging technology."}
	]
	for category in categories:
		var card := _panel(Color(0.34, 0.68, 0.88, 0.24), Color(0.86, 0.97, 1.0, 0.92), 18)
		card.name = str(category["name"]).replace(" ", "_") + "_Category_Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(card_width, card_height)
		var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		card_style.bg_color = Color(0.32, 0.66, 0.88, 0.27)
		card_style.border_color = Color(0.86, 0.97, 1.0, 0.92)
		card_style.set_border_width_all(1)
		card_style.shadow_color = Color(0.0, 0.16, 0.34, 0.42)
		card_style.shadow_size = 18
		card_style.shadow_offset = Vector2(0, 5)
		card_style.anti_aliasing = true
		card.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card)

		# Soft vertical reflection across the upper glass surface.
		var glass_gradient := Gradient.new()
		glass_gradient.set_color(0, Color(0.92, 0.98, 1.0, 0.34))
		glass_gradient.set_color(1, Color(0.76, 0.91, 1.0, 0.0))
		var glass_texture := GradientTexture2D.new()
		glass_texture.gradient = glass_gradient
		glass_texture.fill_from = Vector2(0.0, 0.0)
		glass_texture.fill_to = Vector2(0.0, 1.0)
		var reflection := TextureRect.new()
		reflection.name = "Glass_Reflection"
		reflection.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		reflection.offset_bottom = 78.0
		reflection.texture = glass_texture
		reflection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reflection.stretch_mode = TextureRect.STRETCH_SCALE
		reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(reflection)

		var card_margin := _margin(card, 16 if compact else 22, 16 if compact else 22, 14 if compact else 18, 14 if compact else 18)
		var card_content := VBoxContainer.new()
		card_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_content.add_theme_constant_override("separation", 7)
		card_margin.add_child(card_content)
		card_content.add_child(_label(str(category["number"]) + "  /  PRODUCT TYPE", 11, Color("#a9e3ff")))
		var category_title := _label(str(category["name"]), 20 if compact else 24, Color("#ffffff"))
		_apply_shared_page_typography(category_title, 22 if compact else 26)
		card_content.add_child(category_title)
		var description := _label(str(category["description"]), 12 if compact else 13, Color("#c7e2f3"))
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_content.add_child(description)
		var choose := _add_action_button(card_content, "SELECT CATEGORY  ›", true, _on_create_category_pressed.bind(str(category["name"])))
		choose.custom_minimum_size = Vector2(0, 46)
		_apply_shared_page_typography(choose, 14)
		_style_create_glass_button(choose, true)

func _show_research_scene() -> void:
	current_screen = "research"
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	if is_instance_valid(world_root) and world_root.has_method("set_preview_active"):
		world_root.set_preview_active(false)

	var root := _new_screen()
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
	shade.color = Color(0.008, 0.035, 0.065, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.name = "ResearchSceneScroll"
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
	page_margin.add_theme_constant_override("margin_bottom", 104 if compact else 112)
	scroll.add_child(page_margin)

	var page := VBoxContainer.new()
	page.name = "ResearchSceneContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	page_margin.add_child(page)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	page.add_child(header)
	header.add_child(_label("DIGITAL WORLD MOBILES  /  RESEARCH", 11 if compact else 13, Color("#a9e3ff")))

	var hero_row := HBoxContainer.new()
	hero_row.name = "ResearchHeroRow"
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_theme_constant_override("separation", 12)
	header.add_child(hero_row)
	var title := _label("RESEARCH & DEVELOPMENT", 27 if compact else 36, Color("#ffffff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_row.add_child(title)
	var back_button := _add_action_button(hero_row, "BACK", false, _return_home_from_research)
	back_button.custom_minimum_size = Vector2(104 if compact else 120, 46 if compact else 50)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_shared_page_typography(back_button, 15 if compact else 16)
	_style_create_glass_button(back_button, false)
	header.add_child(_label("Explore research areas for the products your company develops.", 13 if compact else 15, Color("#d8efff")))

	var section := VBoxContainer.new()
	section.name = "ResearchProductCategories"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)
	page.add_child(section)
	section.add_child(_label("01  /  PRODUCT RESEARCH", 12, Color("#a9e3ff")))

	var grid := GridContainer.new()
	grid.name = "Research_Product_Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	section.add_child(grid)

	var horizontal_page_width := maxf(0.0, viewport_size.x - (36.0 if compact else 84.0))
	var card_width := maxf(1.0, (horizontal_page_width - 14.0) * 0.5)
	var card_height := maxf(132.0, minf(220.0, card_width * 0.82))
	var categories := [
		{"name": "PHONE", "number": "01", "description": "Design the complete smartphone, from its exterior to its user experience."},
		{"name": "PROCESSOR", "number": "02", "description": "Develop mobile chipsets and next-generation processing technology."},
		{"name": "OPERATING SYSTEM", "number": "03", "description": "Create the software platform that powers the phone and its features."},
		{"name": "CAMERA", "number": "04", "description": "Develop smartphone camera systems, sensors and imaging technology."}
	]
	for category in categories:
		var card := _panel(Color(0.34, 0.68, 0.88, 0.24), Color(0.86, 0.97, 1.0, 0.92), 18)
		card.name = str(category["name"]).replace(" ", "_") + "_Research_Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(card_width, card_height)
		var card_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		card_style.bg_color = Color(0.32, 0.66, 0.88, 0.27)
		card_style.border_color = Color(0.86, 0.97, 1.0, 0.92)
		card_style.set_border_width_all(1)
		card_style.shadow_color = Color(0.0, 0.16, 0.34, 0.42)
		card_style.shadow_size = 18
		card_style.shadow_offset = Vector2(0, 5)
		card_style.anti_aliasing = true
		card.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card)

		var glass_gradient := Gradient.new()
		glass_gradient.set_color(0, Color(0.92, 0.98, 1.0, 0.34))
		glass_gradient.set_color(1, Color(0.76, 0.91, 1.0, 0.0))
		var glass_texture := GradientTexture2D.new()
		glass_texture.gradient = glass_gradient
		glass_texture.fill_from = Vector2(0.0, 0.0)
		glass_texture.fill_to = Vector2(0.0, 1.0)
		var reflection := TextureRect.new()
		reflection.name = "Glass_Reflection"
		reflection.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		reflection.offset_bottom = 78.0
		reflection.texture = glass_texture
		reflection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reflection.stretch_mode = TextureRect.STRETCH_SCALE
		reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(reflection)

		var card_margin := _margin(card, 16 if compact else 22, 16 if compact else 22, 14 if compact else 18, 14 if compact else 18)
		var card_content := VBoxContainer.new()
		card_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_content.add_theme_constant_override("separation", 7)
		card_margin.add_child(card_content)
		card_content.add_child(_label(str(category["number"]) + "  /  RESEARCH AREA", 11, Color("#a9e3ff")))
		var category_title := _label(str(category["name"]), 20 if compact else 24, Color("#ffffff"))
		_apply_shared_page_typography(category_title, 22 if compact else 26)
		card_content.add_child(category_title)
		var description := _label(str(category["description"]), 12 if compact else 13, Color("#c7e2f3"))
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_content.add_child(description)
		var explore := _add_action_button(card_content, "OPEN RESEARCH  ›", true, _on_research_category_pressed.bind(str(category["name"])))
		explore.custom_minimum_size = Vector2(0, 46)
		_apply_shared_page_typography(explore, 14)
		_style_create_glass_button(explore, true)


func _on_research_category_pressed(category: String) -> void:
	if category.to_upper() == "PHONE":
		_show_research_phone()
		return
	_show_notice("RESEARCH", category.capitalize() + " research will be added here.")


func _return_home_from_research() -> void:
	current_screen = "home"
	if is_instance_valid(world_root) and world_root.has_method("set_home_mode"):
		world_root.set_home_mode(true)
		world_root.set_preview_active(true)
	_show_home_navigation()


func _show_research_phone() -> void:
	_dispose_phone_editor()
	phone_editor = PhoneEditorScene.instantiate() as Node3D
	phone_editor.name = "Phone_Research_Screen"
	phone_editor.set("research_mode", true)
	phone_editor.connect("back_requested", Callable(self, "_return_from_research_phone"))
	phone_editor.connect("research_upgrade_requested", Callable(self, "_on_phone_design_research_upgrade"))
	phone_editor.call("set_research_data", career.get("phone_design_research", {}), float(career.get("balance", 10000000.0)))
	if is_instance_valid(ui_layer):
		ui_layer.hide()
	add_child(phone_editor)
	current_screen = "research_phone"


func _return_from_research_phone() -> void:
	_dispose_phone_editor()
	current_screen = "research"
	if is_instance_valid(ui_layer):
		ui_layer.show()


func _on_phone_design_research_upgrade(research_id: String) -> void:
	var research_names := {
		"screen_size": "Screen size",
		"phone_thickness": "Phone thickness",
		"bezel_width": "Bezel width",
		"frame_material": "Frame material",
		"body_finish": "Body finish",
		"camera_module": "Camera-module design"
	}
	if not research_names.has(research_id):
		return
	var research_levels: Dictionary = career.get("phone_design_research", {})
	var current_level := clampi(int(research_levels.get(research_id, 1)), 1, 20)
	if current_level >= 20:
		_show_notice("MAXIMUM RESEARCH LEVEL", str(research_names[research_id]) + " has already reached level 20.")
		return
	var upgrade_cost := 250000.0 * float(current_level)
	var previous_balance := float(career.get("balance", 10000000.0))
	if previous_balance < upgrade_cost:
		_show_notice("INSUFFICIENT BALANCE", "Upgrading %s to level %d requires %s. Your available balance is %s." % [research_names[research_id], current_level + 1, _format_balance(upgrade_cost), _format_balance(previous_balance)])
		return
	_show_confirmation("CONFIRM RESEARCH UPGRADE", "Upgrade %s from Level %d to Level %d?\n\nCost: %s" % [research_names[research_id], current_level, current_level + 1, _format_balance(upgrade_cost)], "UPGRADE", Callable(self, "_apply_phone_design_research_upgrade").bind(research_id))


func _apply_phone_design_research_upgrade(research_id: String) -> void:
	var research_names := {
		"screen_size": "Screen size",
		"phone_thickness": "Phone thickness",
		"bezel_width": "Bezel width",
		"frame_material": "Frame material",
		"body_finish": "Body finish",
		"camera_module": "Camera-module design"
	}
	if not research_names.has(research_id):
		return
	var research_levels: Dictionary = career.get("phone_design_research", {}).duplicate(true)
	var current_level := clampi(int(research_levels.get(research_id, 1)), 1, 20)
	if current_level >= 20:
		_show_notice("MAXIMUM RESEARCH LEVEL", str(research_names[research_id]) + " has already reached level 20.")
		return
	var upgrade_cost := 250000.0 * float(current_level)
	var previous_balance := float(career.get("balance", 10000000.0))
	if previous_balance < upgrade_cost:
		_show_notice("INSUFFICIENT BALANCE", "Upgrading %s to level %d requires %s. Your available balance is %s." % [research_names[research_id], current_level + 1, _format_balance(upgrade_cost), _format_balance(previous_balance)])
		return
	var previous_levels := research_levels.duplicate(true)
	research_levels[research_id] = current_level + 1
	career["phone_design_research"] = research_levels
	career["balance"] = previous_balance - upgrade_cost
	if not _save_career():
		career["phone_design_research"] = previous_levels
		career["balance"] = previous_balance
		_show_notice("RESEARCH NOT SAVED", "The research upgrade could not be saved. Your research level and balance have not changed.")
		return
	_update_home_status_bar()
	_update_staff_office_balance()
	_show_finance_toast(-upgrade_cost, "RESEARCH UPGRADE")
	if is_instance_valid(world_root) and world_root.has_method("set_company_balance"):
		world_root.set_company_balance(float(career["balance"]))
	if is_instance_valid(phone_editor):
		phone_editor.call("set_research_data", career.get("phone_design_research", {}), float(career["balance"]))
func _return_to_home() -> void:
	current_screen = "home"
	if is_instance_valid(create_ui_layer):
		create_ui_layer.hide()
	ui_layer = null
	ui_root = null
	if is_instance_valid(world_root) and world_root.has_method("set_home_mode"):
		world_root.set_home_mode(true)
		world_root.set_preview_active(true)
	_show_home_navigation()


func _style_create_glass_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.60, 0.84, 0.96, 0.25) if primary else Color(0.72, 0.89, 0.98, 0.14)
		if state == "hover":
			style.bg_color = Color(0.76, 0.92, 1.0, 0.36)
		elif state == "pressed":
			style.bg_color = Color(0.35, 0.68, 0.88, 0.42)
		style.border_color = Color(0.91, 0.98, 1.0, 0.96)
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.12, 0.28, 0.32)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))


func _on_create_category_pressed(category: String) -> void:
	if category.to_upper() == "PHONE":
		_show_phone_editor()
		return
	_show_notice("PRODUCT STUDIO", category.capitalize() + " creation will be available here.")


func _show_phone_editor() -> void:
	# Ignore duplicate activation while the Phone Editor is already open.
	# Re-instantiating a CanvasLayer every time the button receives input can
	# briefly leave overlapping UI layers on mobile.
	if current_screen == "phone_editor" and is_instance_valid(phone_editor):
		phone_editor.show()
		var existing_interface := phone_editor.get_node_or_null("PhoneEditorInterface") as CanvasLayer
		if is_instance_valid(existing_interface):
			existing_interface.show()
		return

	_dispose_phone_editor()

	# Make the Phone Editor an exclusive screen. Hide every persistent screen
	# layer that can outlive a page transition, not only the Create page.
	if is_instance_valid(ui_layer):
		ui_layer.hide()
	if is_instance_valid(create_ui_layer):
		create_ui_layer.hide()
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
	if is_instance_valid(staff_ui_layer):
		staff_ui_layer.hide()
	if is_instance_valid(world_root) and world_root.has_method("set_preview_active"):
		world_root.set_preview_active(false)

	ui_layer = null
	ui_root = null
	current_screen = "phone_editor"

	phone_editor = PhoneEditorScene.instantiate() as Node3D
	if not is_instance_valid(phone_editor):
		current_screen = "create"
		if is_instance_valid(create_ui_layer):
			create_ui_layer.show()
			ui_layer = create_ui_layer
			ui_root = create_ui_root
		push_error("Phone Editor scene could not be instantiated.")
		return

	phone_editor.name = "Phone_Product_Editor"
	phone_editor.call("set_company_branding", str(career.get("company_name", "YOUR COMPANY")), int(career.get("logo_id", 1)))
	phone_editor.connect("back_requested", Callable(self, "_return_from_phone_editor"))
	add_child(phone_editor)


func _return_from_phone_editor() -> void:
	# Switch the state before removing the editor so no frame treats the
	# outgoing screen as active while the Create page is being restored.
	current_screen = "create"
	_dispose_phone_editor()
	if is_instance_valid(create_ui_layer):
		create_ui_layer.show()
		ui_layer = create_ui_layer
		ui_root = create_ui_root


func _on_headquarters_preview_level_changed(level: int) -> void:
	# Preview selection is temporary; owned progress is saved independently.
	selected_upgrade = clampi(level, 1, 10)


func _process_monthly_staff_payroll(month_key: String) -> void:
	if month_key == str(career.get("last_payroll_billed_month", "")):
		return
	var payroll := 0.0
	for employee in career.get("staff_employees", []):
		payroll += float(employee.get("monthly_salary", 0.0))
	var previous_balance := float(career.get("balance", 10000000.0))
	career["last_payroll_billed_month"] = month_key
	if payroll <= 0.0:
		_save_career()
		return
	if previous_balance < payroll:
		_save_career()
		_show_notice("PAYROLL UNPAID", "Your company needs %s for monthly staff salaries, but only has %s available. No money was deducted." % [_format_balance(payroll), _format_balance(previous_balance)])
		return
	career["balance"] = previous_balance - payroll
	if not _save_career():
		career["balance"] = previous_balance
		career["last_payroll_billed_month"] = _get_game_month_key(game_date_unix - 86400.0)
		_show_notice("PAYROLL NOT SAVED", "Monthly staff payroll could not be saved. Your balance has not changed.")
		return
	if is_instance_valid(world_root) and world_root.has_method("set_company_balance"):
		world_root.set_company_balance(float(career["balance"]))
	_update_home_status_bar()
	_update_staff_office_balance()
	_show_finance_toast(-payroll, "MONTHLY PAYROLL")


func _ensure_staff_data() -> void:
	if not career.has("research_points"):
		career["research_points"] = 0
	if not career.has("research_points_progress"):
		career["research_points_progress"] = 0.0
	else:
		career["research_points_progress"] = fposmod(float(career["research_points_progress"]), 1.0)
	if not career.has("staff_candidates") or not (career.get("staff_candidates") is Array):
		career["staff_candidates"] = []
	if not career.has("staff_employees") or not (career.get("staff_employees") is Array):
		career["staff_employees"] = []
	if not bool(career.get("staff_market_initialized", false)):
		var initial_candidates: Array = []
		for index in range(50):
			initial_candidates.append(_generate_staff_candidate())
		career["staff_candidates"] = initial_candidates
		career["staff_market_initialized"] = true
	# Remove retired staff attributes from existing saves during migration.
	for candidate_value in career["staff_candidates"]:
		if candidate_value is Dictionary:
			var candidate_data: Dictionary = candidate_value
			candidate_data.erase("ability")
			candidate_data.erase("potential")
			candidate_data.erase("reliability")
			candidate_data.erase("communication")
			candidate_data.erase("personality")
			candidate_data.erase("rarity")
	for employee_value in career["staff_employees"]:
		if employee_value is Dictionary:
			var employee_data: Dictionary = employee_value
			employee_data.erase("ability")
			employee_data.erase("potential")
			employee_data.erase("reliability")
			employee_data.erase("communication")
			employee_data.erase("personality")
			employee_data.erase("rarity")
			# Migrate employees from retired departments into the new three-team structure.
			if str(employee_data.get("department", "")) not in ["Development", "Marketing", "Research"]:
				var legacy_position := str(employee_data.get("position", "")).to_lower()
				if "research" in legacy_position or "analyst" in legacy_position or "scientist" in legacy_position:
					employee_data["department"] = "Research"
				elif "marketing" in legacy_position or "brand" in legacy_position or "social" in legacy_position or "recruit" in legacy_position:
					employee_data["department"] = "Marketing"
				else:
					employee_data["department"] = "Development"
	if not career.has("next_staff_candidate_id"):
		career["next_staff_candidate_id"] = 1
	# Older saves migrate to the current in-game month without triggering an instant refresh.
	if not career.has("last_candidate_refresh_month"):
		career["last_candidate_refresh_month"] = _get_game_month_key(game_date_unix)
	if not career.has("last_payroll_billed_month"):
		career["last_payroll_billed_month"] = _get_game_month_key(game_date_unix)


func _generate_staff_candidate() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Keep given names and surnames paired within nine international name pools.
	var international_names := {
		"China": {"first": ["Wei", "Yun", "Jia", "Ming", "Mei", "Hao", "Xinyi", "Lei", "Lina", "Jun", "Yating", "Chen"], "last": ["Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Wu", "Zhou"]},
		"USA": {"first": ["James", "Olivia", "Ethan", "Ava", "Noah", "Madison", "Liam", "Grace", "Mason", "Chloe", "Logan", "Harper"], "last": ["Smith", "Johnson", "Williams", "Brown", "Miller", "Davis", "Wilson", "Taylor", "Anderson", "Thomas"]},
		"UK": {"first": ["Oliver", "Amelia", "George", "Isla", "Harry", "Charlotte", "Arthur", "Freya", "Oscar", "Florence", "Jack", "Emily"], "last": ["Smith", "Jones", "Taylor", "Brown", "Wilson", "Davies", "Evans", "Thomas", "Roberts", "Walker"]},
		"Belgium": {"first": ["Lucas", "Emma", "Arthur", "Louise", "Louis", "Alice", "Jules", "Marie", "Victor", "Elise", "Noah", "Lena"], "last": ["Peeters", "Janssens", "Maes", "Jacobs", "Mertens", "Willems", "Claes", "Goossens", "Dubois", "Lambert"]},
		"Netherlands": {"first": ["Daan", "Emma", "Sem", "Julia", "Milan", "Sophie", "Lars", "Tess", "Finn", "Lotte", "Bram", "Eva"], "last": ["de Jong", "Jansen", "de Vries", "van den Berg", "Bakker", "Visser", "Smit", "Meijer", "de Boer", "Mulder"]},
		"Poland": {"first": ["Jakub", "Zofia", "Antoni", "Julia", "Jan", "Maja", "Szymon", "Hanna", "Aleksander", "Alicja", "Filip", "Oliwia"], "last": ["Nowak", "Kowalski", "Wiśniewski", "Wójcik", "Kamiński", "Lewandowski", "Zieliński", "Szymański", "Woźniak", "Dąbrowski"]},
		"Nigeria": {"first": ["Chinedu", "Amara", "Tobi", "Adaora", "Ifeanyi", "Zainab", "Oluwaseun", "Nneka", "Emeka", "Amina", "Kelechi", "Temiloluwa"], "last": ["Okafor", "Adeyemi", "Balogun", "Eze", "Nwosu", "Adebayo", "Onyeka", "Ibrahim", "Ogunleye", "Mohammed"]},
		"Russia": {"first": ["Alexander", "Anastasia", "Dmitri", "Sofia", "Nikolai", "Ekaterina", "Mikhail", "Alina", "Ivan", "Daria", "Artem", "Natalia"], "last": ["Ivanov", "Smirnov", "Kuznetsov", "Popov", "Sokolov", "Lebedev", "Kozlov", "Novikov", "Morozov", "Volkov"]},
		"Spain": {"first": ["Hugo", "Lucia", "Mateo", "Sofia", "Martin", "Martina", "Leo", "Valeria", "Daniel", "Carmen", "Pablo", "Alba"], "last": ["Garcia", "Rodriguez", "Gonzalez", "Fernandez", "Lopez", "Martinez", "Sanchez", "Perez", "Gomez", "Martin"]}
	}
	var countries: Array = international_names.keys()
	var country: String = str(countries[rng.randi_range(0, countries.size() - 1)])
	var name_pool: Dictionary = international_names[country]
	var first_names: Array = name_pool["first"]
	var surnames: Array = name_pool["last"]
	var roles := {
		"Development": ["Software Developer", "Senior Developer", "Game Developer", "UI/UX Designer", "Systems Engineer"],
		"Research": ["Research Analyst", "Data Analyst", "Research Scientist", "Product Researcher", "Innovation Specialist"],
		"Marketing": ["Marketing Manager", "Marketing Specialist", "Brand Strategist", "Social Media Manager", "Advertising Specialist"]
	}
	var departments := ["Development", "Marketing", "Research"]
	var department: String = departments[rng.randi_range(0, departments.size() - 1)]
	var role_list: Array = roles[department]
	var efficiency := rng.randi_range(48, 99)
	var experience := rng.randi_range(0, 22)
	var base_salary := 145000.0
	match department:
		"Development": base_salary = 190000.0
		"Research": base_salary = 175000.0
		"Marketing": base_salary = 145000.0
	var salary := roundf(base_salary * (0.65 + float(efficiency) / 100.0) * (1.0 + float(experience) * 0.035) / 1000.0) * 1000.0
	var candidate_id := "candidate_%05d" % int(career.get("next_staff_candidate_id", 1))
	career["next_staff_candidate_id"] = int(career.get("next_staff_candidate_id", 1)) + 1
	return {
		"id": candidate_id,
		"full_name": str(first_names[rng.randi_range(0, first_names.size() - 1)]) + " " + str(surnames[rng.randi_range(0, surnames.size() - 1)]),
		"country": country,
		"age": rng.randi_range(21, 58),
		"gender": "Female" if rng.randi_range(0, 1) == 0 else "Male",
		"department": department,
		"position": role_list[rng.randi_range(0, role_list.size() - 1)],
		"efficiency": efficiency,
		"experience": experience,
		"education": ["Diploma", "Bachelor's Degree", "Master's Degree", "Doctorate"][rng.randi_range(0, 3)],
		"monthly_salary": salary
	}


func _refresh_staff_market_on_startup() -> void:
	# Refresh candidates on every launch while the HQ preparation screen is shown.
	# Employees already hired remain untouched.
	_ensure_staff_data()
	var refreshed_market: Array = []
	for index in range(50):
		refreshed_market.append(_generate_staff_candidate())
	career["staff_candidates"] = refreshed_market
	career["staff_market_initialized"] = true
	career["last_candidate_refresh_month"] = _get_game_month_key(game_date_unix)
	_save_career()


func _process_staff_market_refresh(current_month: String) -> void:
	var last_refresh_month := str(career.get("last_candidate_refresh_month", current_month))
	var current_parts := current_month.split("-")
	var previous_parts := last_refresh_month.split("-")
	if current_parts.size() != 2 or previous_parts.size() != 2:
		career["last_candidate_refresh_month"] = current_month
		_save_career()
		return
	var current_month_index := int(current_parts[0]) * 12 + int(current_parts[1])
	var previous_month_index := int(previous_parts[0]) * 12 + int(previous_parts[1])
	if current_month_index <= previous_month_index:
		return
	# Replace all 50 candidates once per in-game month, even off the staff screens.
	var refreshed_market: Array = []
	for index in range(50):
		refreshed_market.append(_generate_staff_candidate())
	career["staff_candidates"] = refreshed_market
	career["staff_market_initialized"] = true
	career["last_candidate_refresh_month"] = current_month
	_save_career()
	_refresh_staff_screen_data()


func _refresh_staff_screen_data() -> void:
	# Rebuild cached page contents only when staff data changes, never on page opening.
	var candidates: Array = career.get("staff_candidates", [])
	var employees: Array = career.get("staff_employees", [])
	var capacity := HeadquartersPreviewScript.get_staff_capacity(upgrade_level)
	var business_name := str(career.get("company_name", "YOUR COMPANY"))
	var balance := float(career.get("balance", 0.0))
	if is_instance_valid(staff_market_screen):
		staff_market_screen.open("market", candidates, employees, capacity, business_name, balance)
	if is_instance_valid(staff_management_screen):
		staff_management_screen.open("management", candidates, employees, capacity, business_name, balance)


func _update_staff_office_balance() -> void:
	if is_instance_valid(staff_screen):
		staff_screen.update_balance(float(career.get("balance", 0.0)))


func _show_office_hub() -> void:
	_show_headquarters_preview()


func _prepare_staff_scenes() -> void:
	if is_instance_valid(staff_market_screen) and is_instance_valid(staff_management_screen):
		return
	staff_ui_layer = CanvasLayer.new()
	staff_ui_layer.name = "DigitalWorld_Prepared_Staff_Layer"
	staff_ui_layer.layer = 60
	add_child(staff_ui_layer)

	staff_market_screen = StaffMarketScene.instantiate()
	staff_market_screen.name = "Prepared_Staff_Market"
	staff_ui_layer.add_child(staff_market_screen)
	_connect_staff_screen_signals(staff_market_screen)
	staff_market_screen.open("market", career.get("staff_candidates", []), career.get("staff_employees", []), HeadquartersPreviewScript.get_staff_capacity(upgrade_level), str(career.get("company_name", "YOUR COMPANY")), float(career.get("balance", 0.0)))
	staff_market_screen.hide()

	staff_management_screen = StaffMarketScene.instantiate()
	staff_management_screen.name = "Prepared_Staff_Management"
	staff_ui_layer.add_child(staff_management_screen)
	_connect_staff_screen_signals(staff_management_screen)
	staff_management_screen.open("management", career.get("staff_candidates", []), career.get("staff_employees", []), HeadquartersPreviewScript.get_staff_capacity(upgrade_level), str(career.get("company_name", "YOUR COMPANY")), float(career.get("balance", 0.0)))
	staff_management_screen.hide()


func _connect_staff_screen_signals(screen: Control) -> void:
	screen.back_requested.connect(_return_home_from_staff)
	screen.hire_requested.connect(_hire_staff_candidate)
	screen.dismiss_requested.connect(_request_staff_dismissal)


func _open_staff_screen(screen_mode: String) -> void:
	current_screen = "staff_market" if screen_mode == "market" else "staff_management"
	# Staff is a standalone page, not a translucent layer over the HQ scene.
	if is_instance_valid(world_root) and world_root.has_method("set_preview_active"):
		world_root.set_preview_active(false)
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	if is_instance_valid(ui_layer) and ui_layer != create_ui_layer:
		ui_layer.hide()
		ui_layer.queue_free()
	ui_layer = null
	if not is_instance_valid(staff_market_screen) or not is_instance_valid(staff_management_screen):
		_prepare_staff_scenes()
	if is_instance_valid(staff_ui_layer):
		staff_ui_layer.show()
	staff_market_screen.hide()
	staff_management_screen.hide()
	staff_screen = staff_market_screen if screen_mode == "market" else staff_management_screen
	# Both pages were fully built during HQ loading. Opening is visibility-only.
	staff_screen.show()


func _close_staff_overlay() -> void:
	if is_instance_valid(staff_market_screen):
		staff_market_screen.hide()
	if is_instance_valid(staff_management_screen):
		staff_management_screen.hide()
	staff_screen = null


func _return_home_from_staff() -> void:
	_close_staff_overlay()
	_show_headquarters_preview()


func _hire_staff_candidate(candidate_id: String) -> void:
	if upgrade_level <= 0:
		_show_notice("OFFICE REQUIRED", "Purchase an office building before hiring employees. Your company must own an office to employ staff.")
		return
	var market: Array = career.get("staff_candidates", [])
	var team: Array = career.get("staff_employees", [])
	if team.size() >= HeadquartersPreviewScript.get_staff_capacity(upgrade_level):
		_show_notice("HEADQUARTERS FULL", "Your current headquarters can hold %d employees. Upgrade your headquarters to expand staff capacity." % HeadquartersPreviewScript.get_staff_capacity(upgrade_level))
		return
	for candidate_value in market:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if str(candidate.get("id", "")) != candidate_id:
			continue
		var candidate_name := str(candidate.get("name", candidate.get("full_name", "this candidate")))
		var salary := float(candidate.get("monthly_salary", 0.0))
		_show_confirmation("HIRE EMPLOYEE", "Hire %s to join your company?\n\nDepartment: %s\nMonthly salary: %s" % [candidate_name, str(candidate.get("department", "Unassigned")), _format_balance(salary)], "HIRE", Callable(self, "_apply_staff_hire_candidate").bind(candidate_id))
		return


func _apply_staff_hire_candidate(candidate_id: String) -> void:
	# Re-check ownership after the confirmation dialog too, so a stale hire
	# confirmation can never bypass the office requirement.
	if upgrade_level <= 0:
		_show_notice("OFFICE REQUIRED", "Purchase an office building before hiring employees. Your company must own an office to employ staff.")
		return
	var market: Array = career.get("staff_candidates", [])
	var team: Array = career.get("staff_employees", [])
	if team.size() >= HeadquartersPreviewScript.get_staff_capacity(upgrade_level):
		_show_notice("HEADQUARTERS FULL", "Your current headquarters can hold %d employees. Upgrade your headquarters to expand staff capacity." % HeadquartersPreviewScript.get_staff_capacity(upgrade_level))
		return
	var candidate_index := -1
	for index in range(market.size()):
		if str(market[index].get("id", "")) == candidate_id:
			candidate_index = index
			break
	if candidate_index < 0:
		return
	var previous_market := market.duplicate(true)
	var previous_team := team.duplicate(true)
	var hired: Dictionary = market[candidate_index].duplicate(true)
	market.remove_at(candidate_index)
	team.append(hired)
	career["staff_candidates"] = market
	career["staff_employees"] = team
	if not _save_career():
		career["staff_candidates"] = previous_market
		career["staff_employees"] = previous_team
		_show_notice("HIRE NOT SAVED", "The employee could not be saved. No candidate was removed from the market.")
		return
	_refresh_staff_screen_data()
	_open_staff_screen("market")
func _request_staff_dismissal(employee_id: String) -> void:
	var employee_name := "this employee"
	for employee_value in career.get("staff_employees", []):
		if employee_value is Dictionary and str(employee_value.get("id", "")) == employee_id:
			employee_name = str(employee_value.get("name", employee_value.get("full_name", employee_name)))
			break
	_show_confirmation("DISMISS EMPLOYEE", "Dismiss %s from your company? This action cannot be undone." % employee_name, "DISMISS", Callable(self, "_dismiss_staff_employee").bind(employee_id))
func _dismiss_staff_employee(employee_id: String) -> void:
	var team: Array = career.get("staff_employees", [])
	var previous_team := team.duplicate(true)
	for index in range(team.size() - 1, -1, -1):
		if str(team[index].get("id", "")) == employee_id:
			team.remove_at(index)
			break
	career["staff_employees"] = team
	if not _save_career():
		career["staff_employees"] = previous_team
		_show_notice("DISMISSAL NOT SAVED", "Your employee roster has not changed.")
		return
	_refresh_staff_screen_data()
	_open_staff_screen("management")


func _assign_staff_department(employee_id: String, department: String) -> void:
	var team: Array = career.get("staff_employees", [])
	var previous_team := team.duplicate(true)
	for employee in team:
		if str(employee.get("id", "")) == employee_id:
			employee["department"] = department
			break
	career["staff_employees"] = team
	if not _save_career():
		career["staff_employees"] = previous_team
		_show_notice("ASSIGNMENT NOT SAVED", "The employee's department has not changed.")
		return
	_refresh_staff_screen_data()
	_open_staff_screen("management")


func _show_settings() -> void:
	if not is_instance_valid(ui_root):
		_new_screen()
	var compact := get_viewport().get_visible_rect().size.y < 520.0
	var shade := ColorRect.new()
	shade.name = "Settings_Dim_Backdrop"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.002, 0.018, 0.009, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(shade)

	var center := CenterContainer.new()
	center.name = "Settings_Direct_Content"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 28)
	center.add_theme_constant_override("margin_right", 28)
	center.add_theme_constant_override("margin_top", 16 if compact else 24)
	center.add_theme_constant_override("margin_bottom", 16 if compact else 24)
	ui_root.add_child(center)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size.x = minf(560.0, maxf(260.0, get_viewport().get_visible_rect().size.x - 56.0))
	stack.add_theme_constant_override("separation", 11 if compact else 18)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stack)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(96, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color("#a9d9ad")
	stack.add_child(accent)
	var eyebrow := _label("DIGITAL WORLD MOBILES", 13 if compact else 16, Color("#a9d9ad"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(eyebrow)
	var heading := _label("SETTINGS", 28 if compact else 34, Color("#f4fff3"), HORIZONTAL_ALIGNMENT_CENTER)
	_apply_menu_3d_label(heading, 2)
	stack.add_child(heading)
	var description := _label("Personalise the presentation and sound of your game.", 16 if compact else 20, Color("#dcebdd"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(description)

	var quality_label := _label("GRAPHICS QUALITY", 16 if compact else 19, Color("#f0fff0"))
	stack.add_child(quality_label)
	var quality := OptionButton.new()
	quality.custom_minimum_size = Vector2(0, 48 if compact else 58)
	quality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in ["High", "Balanced", "Performance"]:
		quality.add_item(option)
	quality.select(0 if graphics_quality == "High" else (1 if graphics_quality == "Balanced" else 2))
	quality.item_selected.connect(func(index: int): graphics_quality = quality.get_item_text(index))
	_style_settings_dropdown(quality)
	_apply_shared_page_typography(quality, 18 if compact else 21)
	stack.add_child(quality)

	var sound := CheckButton.new()
	sound.text = "SOUND ENABLED"
	sound.custom_minimum_size.y = 42 if compact else 52
	sound.button_pressed = sound_enabled
	sound.toggled.connect(func(enabled: bool): sound_enabled = enabled)
	_apply_shared_page_typography(sound, 18 if compact else 20)
	sound.add_theme_color_override("font_color", Color("#f1fff1"))
	stack.add_child(sound)

	var done_button := _add_action_button(stack, "DONE", true, Callable())
	done_button.custom_minimum_size = Vector2(0, 52 if compact else 62)
	_style_landing_command_button(done_button, true)
	_apply_shared_page_typography(done_button, 18 if compact else 21)
	done_button.pressed.connect(_close_settings_overlay.bind(shade, center))

func _style_settings_dropdown(selector: OptionButton) -> void:
	selector.focus_mode = Control.FOCUS_NONE
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.035, 0.16, 0.075, 0.82)
	field.border_color = Color(0.66, 0.91, 0.68, 0.9)
	field.set_border_width_all(2)
	field.set_corner_radius_all(14)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 12
	field.content_margin_bottom = 12
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		selector.add_theme_stylebox_override(state, field)
	selector.add_theme_color_override("font_color", Color("#f2fff1"))
	selector.add_theme_color_override("font_hover_color", Color("#ffffff"))
	selector.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	selector.add_theme_color_override("font_focus_color", Color("#ffffff"))
	var popup := selector.get_popup()
	popup.min_size = Vector2i(maxi(roundi(selector.custom_minimum_size.x), 280), 0)
	popup.add_theme_font_size_override("font_size", 19)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#07190d")
	panel.border_color = Color("#9bd6a0")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", panel)
	var item_idle := StyleBoxFlat.new()
	item_idle.bg_color = Color("#0a2111")
	item_idle.set_corner_radius_all(7)
	item_idle.content_margin_left = 14
	item_idle.content_margin_right = 14
	item_idle.content_margin_top = 12
	item_idle.content_margin_bottom = 12
	popup.add_theme_stylebox_override("hover", item_idle)
	popup.add_theme_stylebox_override("pressed", item_idle)
	popup.add_theme_stylebox_override("focus", item_idle)
	popup.add_theme_color_override("font_color", Color("#eaffea"))
	popup.add_theme_color_override("font_hover_color", Color("#ffffff"))
	popup.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	popup.add_theme_color_override("font_focus_color", Color("#ffffff"))
	popup.add_theme_constant_override("v_separation", 10)
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_color_override("font_outline_color", Color("#061508"))

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
	if is_instance_valid(confirm_modal):
		confirm_modal.show_notice(title_text, message_text)

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
