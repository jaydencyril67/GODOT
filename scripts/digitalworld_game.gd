extends Node3D

const HeadquartersPreviewScript = preload("res://scripts/world/digitalworld_headquarters.gd")
const PhoneCreationWorksiteScene: PackedScene = preload("res://scenes/phone_creation_worksite.tscn")
const ResearchAllocationDashboardScene: PackedScene = preload("res://scenes/research_allocation_dashboard.tscn")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")
const StaffMarketScene: PackedScene = preload("res://scenes/staff_market.tscn")
const LandingCampusScene: PackedScene = preload("res://scenes/landing_campus.tscn")
const ConfirmModalScript = preload("res://scripts/ui/digitalworld_confirm_modal.gd")
const SAVE_PATH := "user://digitalworld_save.cfg"

const LOGO_NAMES := [
	"Orchard", "Skybird", "Crown", "Apex", "Volt", "Prism", "Quantum", "Helix", "Titan", "Zenith",
	"Vertex", "Catalyst", "Photon", "Fusion", "Eclipse", "Infinity", "Shield", "Spark", "Wave", "Matrix",
	"Nova", "Orbit", "Falcon", "Monolith", "Comet", "Aurora", "Pinnacle", "Circuit", "Lattice", "Monarch",
	"Flare", "Keystone", "Bluepeak", "Atlas", "Crescent", "Vortex", "Beacon", "Stratos", "Ironclad", "Mosaic",
	"Northstar", "Vector", "Aether", "Pulse", "Forge", "Meridian", "Lumen", "Cobalt", "Terra", "Frontier"
]

const NAVY := Color("#17191B")
const BLUE := Color("#C58A3A")
const PANEL := Color(0.045, 0.065, 0.10, 0.94)
const PALE := Color("#E5E3DD")
const MUTED := Color("#A9A297")
const ACCENT := Color("#C58A3A")

var ui_layer: CanvasLayer
var ui_root: Control
var create_ui_layer: CanvasLayer
var create_ui_root: Control
var world_root: DigitalWorldHeadquarters
var landing_world: Node3D
var research_allocation_dashboard: Control
var phone_creation_worksite: Node3D
var research_dashboard_return_to_worksite := false
var worksite_research_overlay_layer: CanvasLayer
var home_navigation_layer: CanvasLayer
var home_company_label: Label
var home_date_label: Label
var home_balance_label: Label
var home_finance_toast: Label
var home_finance_toast_tween: Tween
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
var loading_percent_label: Label
var loading_progress_tween: Tween
var loading_accent_tween: Tween
var headquarters_loading_finish_started := false
var graphics_quality := "High"
var sound_enabled := true

func _ready() -> void:
	print("[DigitalWorld] Main scene _ready reached")
	# Start in Android immersive fullscreen after the display window is initialized.
	set_process(true)
	if OS.has_feature("android"):
		call_deferred("_apply_android_fullscreen")
	confirm_modal = ConfirmModalScript.new()
	confirm_modal.name = "DigitalWorld_Confirm_Modal"
	add_child(confirm_modal)
	_load_career()
	_show_menu()
	print("[DigitalWorld] Initial menu construction completed")


func _process(delta: float) -> void:
	if career.is_empty() or str(career.get("company_name", "")).is_empty() or game_clock_paused:
		return
	# Keep the in-game clock and monthly staff refresh running on all company screens,
	# including while the player is browsing products, research, or other HQ features.
	if current_screen not in ["home", "headquarters", "create", "research", "research_allocation", "office", "staff_market", "staff_management", "phone_creation_worksite"]:
		return
	var previous_day := floori(game_date_unix / 86400.0)
	var previous_month := _get_game_month_key(game_date_unix)
	# One complete in-game day passes every three real-world seconds.
	var game_time_delta := delta * 28800.0
	game_date_unix += game_time_delta
	var completed_rd_projects: Array = ResearchManagerScript.advance_projects(career, game_time_delta, game_date_unix)
	if not completed_rd_projects.is_empty():
		_save_career()
		for completed_id in completed_rd_projects:
			for project_value in career.get("research_projects", []):
				if not (project_value is Dictionary) or str(project_value.get("id", "")) != completed_id:
					continue
				var completed_project: Dictionary = project_value
				var component_name := str(completed_project.get("component", "Research"))
				if str(completed_project.get("status", "")) == ResearchManagerScript.STATUS_AWAITING_VALIDATION:
					_show_notice("RESEARCH READY FOR VALIDATION", "%s completed its R&D work and is ready for technical validation." % component_name)
				else:
					_show_notice("RESEARCH UNSUCCESSFUL", "%s research did not produce a successful result." % component_name)
				break
		if is_instance_valid(phone_creation_worksite):
			phone_creation_worksite.call("set_screen_width_research_level", int(career.get("research_component_levels", {}).get("Screen Width", 0)))
			phone_creation_worksite.call("set_screen_height_research_level", int(career.get("research_component_levels", {}).get("Screen Height", 0)))
			phone_creation_worksite.call("set_curved_screen_horizontal_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Horizontal", 0)))
			phone_creation_worksite.call("set_curved_screen_vertical_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Vertical", 0)))
			phone_creation_worksite.call("set_curved_screen_both_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Both", 0)))
			phone_creation_worksite.call("set_refresh_rate_research_level", int(career.get("research_component_levels", {}).get("Refresh Rate", 0)))
			phone_creation_worksite.call("set_memory_clock_research_level", int(career.get("research_component_levels", {}).get("Memory Clock", 0)))
			phone_creation_worksite.call("set_screen_technology_research_level", int(career.get("research_component_levels", {}).get("Screen Technology", 0)))
			phone_creation_worksite.call("set_front_camera_research_level", int(career.get("research_component_levels", {}).get("Front Camera", 0)))
			phone_creation_worksite.call("set_front_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Front Camera MP", 0)))
			phone_creation_worksite.call("set_ram_technology_research_level", int(career.get("research_component_levels", {}).get("RAM Technology", 0)))
			phone_creation_worksite.call("set_ram_capacity_research_level", int(career.get("research_component_levels", {}).get("RAM", 0)))
			phone_creation_worksite.call("set_internal_storage_research_level", int(career.get("research_component_levels", {}).get("Internal Storage", 0)))
		phone_creation_worksite.call("set_phone_sensor_research_levels", career.get("research_component_levels", {}))
		phone_creation_worksite.call("set_side_button_research_levels", career.get("research_component_levels", {}))
		if is_instance_valid(research_allocation_dashboard):
			research_allocation_dashboard.call("configure", _get_research_dashboard_data())
	var current_day := floori(game_date_unix / 86400.0)
	var current_month := _get_game_month_key(game_date_unix)
	if current_month != previous_month:
		_process_pending_monthly_expenses()
		_process_staff_market_refresh(current_month)
	if current_day != previous_day:
		_save_career()
		last_saved_game_day = current_day
		if is_instance_valid(research_allocation_dashboard):
			research_allocation_dashboard.call("update_live_progress", career.get("research_projects", []), float(career.get("balance", 0.0)), career.get("staff_employees", []))
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
		"game_date_unix": float(config.get_value("career", "game_date_unix", 1262304000.0)),
		"game_clock_paused": bool(config.get_value("career", "game_clock_paused", false)),
		"last_rent_billed_month": str(config.get_value("career", "last_rent_billed_month", _get_game_month_key(float(config.get_value("career", "game_date_unix", 1262304000.0))))),
		"last_payroll_billed_month": str(config.get_value("career", "last_payroll_billed_month", _get_game_month_key(float(config.get_value("career", "game_date_unix", 1262304000.0))))),
		"staff_candidates": config.get_value("career", "staff_candidates", []),
		"staff_employees": config.get_value("career", "staff_employees", []),
		"next_staff_candidate_id": int(config.get_value("career", "next_staff_candidate_id", 1)),
		"last_candidate_refresh_month": str(config.get_value("career", "last_candidate_refresh_month", _get_game_month_key(float(config.get_value("career", "game_date_unix", 1262304000.0))))),
		"staff_market_initialized": bool(config.get_value("career", "staff_market_initialized", false)),
		"research_history": config.get_value("career", "research_history", []),
		"research_projects": config.get_value("career", "research_projects", []),
		"research_technologies": config.get_value("career", "research_technologies", {}),
		"research_component_levels": config.get_value("career", "research_component_levels", {}),
		"next_research_project_id": int(config.get_value("career", "next_research_project_id", 1))
	}
	ResearchManagerScript.ensure_state(career)
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
	config.set_value("career", "game_date_unix", game_date_unix)
	config.set_value("career", "game_clock_paused", game_clock_paused)
	config.set_value("career", "last_rent_billed_month", str(career.get("last_rent_billed_month", _get_game_month_key(game_date_unix))))
	config.set_value("career", "last_payroll_billed_month", str(career.get("last_payroll_billed_month", _get_game_month_key(game_date_unix))))
	config.set_value("career", "staff_candidates", career.get("staff_candidates", []))
	config.set_value("career", "staff_employees", career.get("staff_employees", []))
	config.set_value("career", "next_staff_candidate_id", int(career.get("next_staff_candidate_id", 1)))
	config.set_value("career", "last_candidate_refresh_month", str(career.get("last_candidate_refresh_month", _get_game_month_key(game_date_unix))))
	config.set_value("career", "staff_market_initialized", bool(career.get("staff_market_initialized", false)))
	config.set_value("career", "research_history", career.get("research_history", []))
	config.set_value("career", "research_projects", career.get("research_projects", []))
	config.set_value("career", "research_technologies", career.get("research_technologies", {}))
	config.set_value("career", "research_component_levels", career.get("research_component_levels", {}))
	config.set_value("career", "next_research_project_id", int(career.get("next_research_project_id", 1)))
	var error := config.save(SAVE_PATH)
	return error == OK

func _clear_world() -> void:
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = null
	if is_instance_valid(landing_world):
		landing_world.queue_free()
	landing_world = null
	if is_instance_valid(staff_ui_layer):
		staff_ui_layer.queue_free()
	staff_ui_layer = null
	staff_screen = null
	staff_market_screen = null
	staff_management_screen = null

func _new_screen() -> Control:
	# Screens are transparent over the active 3D world. Non-3D pages naturally
	# fall back to the obsidian clear colour configured in project.godot.
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

	# The curtains, camera, buildings and atmospheric motion are all real 3D.
	landing_world = LandingCampusScene.instantiate() as Node3D
	landing_world.name = "Landing_Corporate_World"
	add_child(landing_world)

	var root := _new_screen()
	var veil := ColorRect.new()
	veil.name = "Landing_Obsidian_Veil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.006, 0.008, 0.012, 0.22)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)

	var layout := HBoxContainer.new()
	layout.name = "Landing_Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 900.0 or viewport_size.y < 520.0
	var showcase := Control.new()
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.size_flags_stretch_ratio = 1.25
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(showcase)

	var welcome := VBoxContainer.new()
	welcome.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	welcome.position = Vector2(34.0 if compact else 58.0, 26.0 if compact else 30.0)
	welcome.custom_minimum_size = Vector2(300.0 if compact else 430.0, 160.0)
	welcome.add_theme_constant_override("separation", 10)
	welcome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(welcome)

	var eyebrow := _label("DIGITAL WORLD MOBILES", 9 if compact else 11, Color("#D2A15C"))
	eyebrow.name = "Landing_Eyebrow"
	welcome.add_child(eyebrow)

	# The headline is split into two independently revealed lines.
	var title_line_one := _label("BUILD YOUR", 25 if compact else 37, Color("#f4f6fa"))
	title_line_one.name = "Landing_Hero_Line_One"
	title_line_one.autowrap_mode = TextServer.AUTOWRAP_OFF
	_apply_menu_3d_label(title_line_one, 1)
	welcome.add_child(title_line_one)
	var title_line_two := _label("TECHNOLOGY EMPIRE.", 25 if compact else 37, Color("#f4f6fa"))
	title_line_two.name = "Landing_Hero_Line_Two"
	title_line_two.autowrap_mode = TextServer.AUTOWRAP_OFF
	_apply_menu_3d_label(title_line_two, 1)
	welcome.add_child(title_line_two)

	var caption_line_one := _label("Design the devices. Build your company.", 12 if compact else 15, Color("#D6D0C5"))
	caption_line_one.name = "Landing_Caption_Line_One"
	welcome.add_child(caption_line_one)
	var caption_line_two := _label("Lead the next generation of mobile technology.", 12 if compact else 15, Color("#D6D0C5"))
	caption_line_two.name = "Landing_Caption_Line_Two"
	welcome.add_child(caption_line_two)

	var command_area := CenterContainer.new()
	command_area.name = "Landing_Command_Area"
	command_area.modulate.a = 0.0
	command_area.size_flags_horizontal = Control.SIZE_SHRINK_END
	command_area.custom_minimum_size.x = 292.0 if compact else 370.0
	command_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(command_area)

	var command_panel := PanelContainer.new()
	command_panel.name = "Landing_Glass_Command_Panel"
	command_panel.custom_minimum_size = Vector2(270.0 if compact else 330.0, 0.0)
	command_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.038, 0.040, 0.94)
	panel_style.border_color = Color("#C58A3A")
	panel_style.border_color.a = 0.84
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.76)
	panel_style.shadow_size = 28
	panel_style.shadow_offset = Vector2(0, 9)
	panel_style.anti_aliasing = true
	panel_style.content_margin_left = 20 if compact else 25
	panel_style.content_margin_right = 20 if compact else 25
	panel_style.content_margin_top = 21 if compact else 27
	panel_style.content_margin_bottom = 20 if compact else 25
	command_panel.add_theme_stylebox_override("panel", panel_style)
	command_area.add_child(command_panel)
	command_panel.scale = Vector2(0.90, 0.90)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 11 if compact else 14)
	command_panel.add_child(menu)
	var menu_heading := _label("DIGITAL WORLD MOBILES", 9 if compact else 10, Color("#D2A15C"), HORIZONTAL_ALIGNMENT_CENTER)
	menu.add_child(menu_heading)
	var menu_title := _label("YOUR COMPANY STARTS HERE", 16 if compact else 19, Color("#f4f6fa"), HORIZONTAL_ALIGNMENT_CENTER)
	menu.add_child(menu_title)
	var menu_rule := ColorRect.new()
	menu_rule.custom_minimum_size = Vector2(0, 1)
	menu_rule.color = Color(0.72, 0.49, 0.20, 0.82)
	menu.add_child(menu_rule)

	var new_game := _add_action_button(menu, "NEW GAME", true, _start_new_game)
	var continue_game := _add_action_button(menu, "CONTINUE", false, _load_game_pressed)
	var settings := _add_action_button(menu, "SETTINGS", false, _show_settings)
	var exit_game := _add_action_button(menu, "EXIT", false, _confirm_exit)
	var landing_buttons: Array[Button] = [new_game, continue_game, settings, exit_game]
	for button in landing_buttons:
		button.custom_minimum_size = Vector2(0, 48 if compact else 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = true
		_style_landing_command_button(button, button == new_game)

	var footer_rule := ColorRect.new()
	footer_rule.custom_minimum_size = Vector2(0, 1)
	footer_rule.color = Color(0.72, 0.49, 0.20, 0.38)
	menu.add_child(footer_rule)
	var footer := _label("POWERED BY KINGSHALL", 8 if compact else 9, Color("#A19A8F"), HORIZONTAL_ALIGNMENT_CENTER)
	menu.add_child(footer)

	landing_world.connect("cinematic_reveal_finished", _animate_landing_menu.bind(root, welcome, command_area, command_panel, landing_buttons))


func _animate_landing_menu(root: Control, welcome: Control, command_area: Control, command_panel: Control, buttons: Array[Button]) -> void:
	if not is_instance_valid(root) or not is_instance_valid(welcome) or not is_instance_valid(command_panel):
		return

	# Copy uses a dedicated writing/reveal sequence; the right-hand command
	# panel keeps its existing scale entrance and button timing unchanged.
	_animate_landing_text_label(welcome.get_node_or_null("Landing_Eyebrow") as Label, 0.62, 0.0, 0.12)
	_animate_landing_text_label(welcome.get_node_or_null("Landing_Hero_Line_One") as Label, 0.78, 0.42, 0.04)
	_animate_landing_text_label(welcome.get_node_or_null("Landing_Hero_Line_Two") as Label, 1.05, 1.08, 0.035)
	_animate_landing_text_label(welcome.get_node_or_null("Landing_Caption_Line_One") as Label, 0.88, 2.18, 0.018)
	_animate_landing_text_label(welcome.get_node_or_null("Landing_Caption_Line_Two") as Label, 1.12, 2.82, 0.016)
	_run_landing_copy_cycle(welcome)

	command_panel.pivot_offset = command_panel.size * 0.5
	var intro := create_tween().set_parallel(true)
	intro.tween_property(command_area, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(command_panel, "scale", Vector2.ONE, 0.95).set_delay(0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.set_parallel(false)
	intro.tween_callback(func() -> void:
		for button in buttons:
			if is_instance_valid(button):
				button.disabled = false
	)


func _animate_landing_text_label(label: Label, duration: float, delay: float, character_interval: float) -> void:
	if not is_instance_valid(label):
		return
	label.visible_characters = 0
	label.modulate.a = 0.0
	var reveal_duration := maxf(duration, float(label.text.length()) * character_interval)
	var reveal := create_tween()
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_interval(delay)
	reveal.set_parallel(true)
	reveal.tween_property(label, "visible_characters", label.text.length(), reveal_duration).set_trans(Tween.TRANS_LINEAR)
	reveal.tween_property(label, "modulate:a", 1.0, minf(0.28, duration * 0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _run_landing_copy_cycle(welcome: Control) -> void:
	var hero_one := welcome.get_node_or_null("Landing_Hero_Line_One") as Label
	var hero_two := welcome.get_node_or_null("Landing_Hero_Line_Two") as Label
	var caption_one := welcome.get_node_or_null("Landing_Caption_Line_One") as Label
	var caption_two := welcome.get_node_or_null("Landing_Caption_Line_Two") as Label
	if not is_instance_valid(hero_one) or not is_instance_valid(hero_two) or not is_instance_valid(caption_one) or not is_instance_valid(caption_two):
		return

	var slides: Array[Dictionary] = [
		{"headline_one": "BUILD YOUR", "headline_two": "TECHNOLOGY EMPIRE.", "caption_one": "Design the devices. Build your company.", "caption_two": "Lead the next generation of mobile technology."},
		{"headline_one": "DREAM BIGGER.", "headline_two": "BUILD WHAT'S NEXT.", "caption_one": "Turn bold ideas into remarkable devices.", "caption_two": "Shape the future of mobile technology."},
		{"headline_one": "FROM WORKSHOP", "headline_two": "TO WORLDWIDE.", "caption_one": "Grow a company from its very first product.", "caption_two": "Create. Innovate. Expand your reach."},
		{"headline_one": "ENGINEER THE", "headline_two": "EXTRAORDINARY.", "caption_one": "Explore hardware, software and design.", "caption_two": "Make every generation of devices your own."},
		{"headline_one": "YOUR VISION.", "headline_two": "YOUR EMPIRE.", "caption_one": "Build teams. Develop products. Lead markets.", "caption_two": "Every great technology company starts somewhere."}
	]
	var slide_index := 1
	while is_instance_valid(welcome) and current_screen == "menu":
		await get_tree().create_timer(5.0).timeout
		if not is_instance_valid(welcome) or current_screen != "menu":
			return
		var fade := create_tween().set_parallel(true)
		for label in [hero_one, hero_two, caption_one, caption_two]:
			if is_instance_valid(label):
				fade.tween_property(label, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await fade.finished
		if not is_instance_valid(welcome) or current_screen != "menu":
			return
		var slide: Dictionary = slides[slide_index]
		hero_one.text = str(slide["headline_one"])
		hero_two.text = str(slide["headline_two"])
		caption_one.text = str(slide["caption_one"])
		caption_two.text = str(slide["caption_two"])
		for label in [hero_one, hero_two, caption_one, caption_two]:
			label.visible_characters = 0
			label.modulate.a = 1.0
		_animate_landing_text_label(hero_one, 0.78, 0.0, 0.035)
		_animate_landing_text_label(hero_two, 0.92, 0.34, 0.032)
		_animate_landing_text_label(caption_one, 0.82, 1.02, 0.018)
		_animate_landing_text_label(caption_two, 0.92, 1.42, 0.016)
		slide_index = (slide_index + 1) % slides.size()


func _style_landing_command_button(button: Button, primary: bool) -> void:
	# Restrained amber action on graphite; secondary controls stay neutral steel.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var base_fill := Color("#805821") if primary else Color("#202326")
	var base_edge := Color("#C99347") if primary else Color("#45484A")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = base_fill
		if state == "hover":
			style.bg_color = Color("#956A2E") if primary else Color("#2A2E30")
		elif state == "pressed":
			style.bg_color = Color("#61431C") if primary else Color("#181A1C")
		elif state == "disabled":
			style.bg_color = Color("#34302A")
		style.border_color = base_edge
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
		style.shadow_size = 8 if primary else 4
		style.shadow_offset = Vector2(0, 3)
		style.anti_aliasing = true
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	var text_color := Color("#F2EDE4")
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color("#A19A8F"))
	_apply_shared_page_typography(button, 15)
	button.add_theme_color_override("font_outline_color", Color("#090A0B"))
	button.add_theme_constant_override("outline_size", 1)

func _style_command_menu_button(button: Button, primary: bool) -> void:
	# Frosted-glass appearance: translucent white surfaces and crisp borders,
	# with no neon glow or coloured drop shadow.
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		if state == "pressed":
			style.bg_color = Color(0.42, 0.32, 0.19, 0.38)
		elif state == "hover":
			style.bg_color = Color(0.96, 0.92, 0.84, 0.28)
		else:
			style.bg_color = Color(0.92, 0.87, 0.76, 0.20) if primary else Color(0.92, 0.87, 0.76, 0.14)
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
	button.add_theme_color_override("font_pressed_color", Color("#EEE9DF"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	_apply_shared_page_typography(button, 22)
	button.add_theme_color_override("font_outline_color", Color(0.16, 0.13, 0.08, 0.72))
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
	_clear_world()
	_show_profile()


func _show_profile() -> void:
	current_screen = "profile"
	_clear_world()
	var root := _new_screen()
	root.modulate.a = 0.0

	# Keep the photographic background readable with a soft vignette.
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

	if not compact:
		var showcase_spacer := Control.new()
		showcase_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		showcase.add_child(showcase_spacer)

	var welcome := VBoxContainer.new()
	welcome.name = "CompanySetupWelcome"
	welcome.add_theme_constant_override("separation", 9)
	showcase.add_child(welcome)
	welcome.add_child(_label("YOUR COMPANY. YOUR LEGACY.", 10 if compact else 11, Color("#BFA579")))
	var welcome_title := _label("BUILD THE\nNEXT GENERATION.", 27 if compact else 36, Color("#f4f6fa"))
	welcome_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_menu_3d_label(welcome_title, 1)
	welcome.add_child(welcome_title)
	var welcome_caption := _label(
		"Put your name behind the technology.\nChoose an identity and establish your company.",
		13 if compact else 15,
		Color("#CFC7BA")
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
	panel_style.bg_color = Color(0.035, 0.038, 0.040, 0.92)
	panel_style.border_color = Color(0.58, 0.46, 0.29, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.set_corner_radius_all(20)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
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
	menu.add_child(_label("CREATE YOUR COMPANY", 21 if compact else 23, Color("#f4f6fa"), HORIZONTAL_ALIGNMENT_CENTER))
	var menu_rule := ColorRect.new()
	menu_rule.custom_minimum_size = Vector2(0, 1)
	menu_rule.color = Color(0.68, 0.50, 0.28, 0.52)
	menu.add_child(menu_rule)

	menu.add_child(_label("FOUNDER NAME", 11, Color("#C8BCA9")))
	full_name_input = LineEdit.new()
	full_name_input.name = "FounderNameInput"
	full_name_input.placeholder_text = "Enter your full name"
	full_name_input.text = str(career.get("full_name", ""))
	full_name_input.custom_minimum_size = Vector2(0, 52)
	full_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shared_page_typography(full_name_input, 17)
	_style_company_setup_input(full_name_input)
	menu.add_child(full_name_input)

	menu.add_child(_label("COMPANY NAME", 11, Color("#C8BCA9")))
	company_name_input = LineEdit.new()
	company_name_input.name = "CompanyNameInput"
	company_name_input.placeholder_text = "Enter your company name"
	company_name_input.text = str(career.get("company_name", ""))
	company_name_input.custom_minimum_size = Vector2(0, 52)
	company_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_shared_page_typography(company_name_input, 17)
	_style_company_setup_input(company_name_input)
	menu.add_child(company_name_input)

	menu.add_child(_label("COMPANY INSIGNIA", 11, Color("#C8BCA9")))
	selected_logo_id = clampi(int(career.get("logo_id", 1)), 1, 50)
	var preview_panel := PanelContainer.new()
	preview_panel.name = "CompanyInsigniaPreview"
	preview_panel.custom_minimum_size = Vector2(0, 86 if compact else 92)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.42, 0.28, 0.11, 0.16)
	preview_style.border_color = Color(0.72, 0.58, 0.36, 0.34)
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
	preview_copy.add_child(_label("YOUR SELECTED MARK", 9, Color("#D2A15C")))
	var selected_name := _label("%02d / 50  ·  %s" % [selected_logo_id, LOGO_NAMES[selected_logo_id - 1].to_upper()], 12, Color("#f4f6fa"))
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
	field.add_theme_color_override("font_color", Color("#EEE9DF"))
	field.add_theme_color_override("font_placeholder_color", Color("#A9A297"))
	field.add_theme_color_override("caret_color", Color("#C58A3A"))
	field.add_theme_color_override("selection_color", Color(0.58, 0.39, 0.16, 0.42))
	for state in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1B1E20")
		style.border_color = Color("#4A4740") if state != "focus" else Color("#C58A3A")
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

	# Match Settings and Exit: a dedicated graphite screen with centred content.
	var scrim := ColorRect.new()
	scrim.name = "InsigniaDarkScreen"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.004, 0.004, 0.004, 0.90)
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
	accent.color = Color("#D2A15C")
	stack.add_child(accent)

	var eyebrow := _label("DIGITAL WORLD MOBILES", 10 if compact else 13, Color("#D2A15C"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(eyebrow)
	var heading := _label("CHOOSE YOUR INSIGNIA", 22 if compact else 30, Color("#f4f6fa"), HORIZONTAL_ALIGNMENT_CENTER)
	_apply_menu_3d_label(heading, 2)
	stack.add_child(heading)
	var description := _label("50 distinctive marks  ·  Select one to represent your company", 11 if compact else 14, Color("#CEC5B7"), HORIZONTAL_ALIGNMENT_CENTER)
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
	# Satin graphite surface with a narrow warm-metal edge.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#25292B")
	style.border_color = Color("#6B5637")
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = true
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_color_override("font_hover_color", Color("#F2EDE4"))
	button.add_theme_color_override("font_pressed_color", Color("#F2EDE4"))
	button.add_theme_color_override("font_focus_color", Color("#F2EDE4"))
	button.add_theme_color_override("font_disabled_color", Color("#A19A8F"))
	button.add_theme_color_override("font_outline_color", Color("#090A0B"))
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))


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
	style.bg_color = Color(0.44, 0.28, 0.11, 0.42) if selected else Color(0.12, 0.13, 0.14, 0.22)
	style.border_color = Color(0.80, 0.64, 0.40, 0.74) if selected else Color(0.44, 0.44, 0.41, 0.40)
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
	ResearchManagerScript.ensure_state(career)
	if str(career.get("created_at", "")).is_empty():
		career["created_at"] = Time.get_datetime_string_from_system(true)
	upgrade_level = 0
	career["upgrade_level"] = upgrade_level
	if not _save_career():
		profile_status.text = "The company could not be saved. Check device storage."
		return
	_show_city()

func _load_game_pressed() -> void:
	# _ready() already loaded the save before presenting the landing page.
	# Re-reading and migrating the same file on button press only blocks the
	# first visible frame of the transition, so use the prepared in-memory career.
	if career.is_empty() or str(career.get("company_name", "")).is_empty():
		_show_notice("NO SAVED COMPANY", "No saved Digital World Mobiles company was found on this device. Choose NEW GAME to establish one.")
		return
	_show_city()

func _show_city() -> void:
	# Put the loading UI on screen before billing, saving, or constructing the HQ.
	# _show_home_scene() keeps this same layer alive while the 3D scene is prepared.
	upgrade_level = clampi(upgrade_level, 0, 10)
	selected_upgrade = maxi(upgrade_level, 1)
	headquarters_loading_finish_started = false
	_show_headquarters_loading_screen()
	_process_pending_monthly_expenses()
	_show_home_scene()


func _show_home_scene() -> void:
	# A live headquarters is created only by the loading-screen entry path.
	# If a caller reaches this function while it already exists, restore that
	# same scene instead of constructing the compound again.
	if is_instance_valid(world_root):
		push_warning("Headquarters already exists; restoring the existing company scene.")
		_restore_home_after_standalone_screen()
		return

	current_screen = "home"
	_clear_world()
	# The loading layer was shown by _show_city() before any synchronous work.
	# Keep it visible and give it a rendered frame before refreshing/generating HQ.
	# Let the HQ preparation screen render before refreshing the market and generating buildings.
	await get_tree().process_frame
	_refresh_staff_market_on_startup()
	var headquarters: DigitalWorldHeadquarters = HeadquartersPreviewScript.new()
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
	# Build the 3D scene off-screen. It must not render behind the preparation UI.
	headquarters.visible = false
	world_root = headquarters
	# Initialize the Worksite in the same loading phase, immediately before HQ construction.
	_prepare_phone_creation_worksite()
	add_child(world_root)


func _show_headquarters_preview() -> void:
	# Office always reuses the headquarters created by the company loading screen.
	# A missing scene is a lifecycle error, never a reason to rebuild during navigation.
	if not is_instance_valid(world_root):
		push_error("Office cannot open because the loading-screen headquarters scene is missing.")
		return

	_close_staff_overlay()
	current_screen = "headquarters"
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	ui_layer = null
	ui_root = null

	# Change the HQ mode before making the world visible, so the new camera and
	# interface are ready together rather than exposing a partially rebuilt frame.
	world_root.set_home_mode(false)
	world_root.set_preview_active(true)


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

func _apply_home_bold_typography(control: Control, font_size: int) -> void:
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 1.1
	control.add_theme_font_override("font", stix_font)
	control.add_theme_font_size_override("font_size", font_size)


func _apply_home_button_typography(button: Control, font_size: int) -> void:
	# Use the project STIX variable font explicitly and strengthen its weight
	# without changing any button dimensions, layout, or visual styling.
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 0.7
	button.add_theme_font_override("font", stix_font)
	button.add_theme_font_size_override("font_size", font_size)


func _show_home_navigation() -> void:
	# Home navigation must always sit over the same scene created at game entry.
	# Missing world state is reported instead of silently starting another build.
	if not is_instance_valid(world_root):
		push_error("Cannot show Home navigation: the loading-screen headquarters scene is missing.")
		return

	# Home UI is a transparent overlay: it frames the live headquarters without
	# placing a tint, backdrop, or panel over the 3D building.
	var root := _new_screen()
	ui_layer.layer = 30
	home_navigation_layer = ui_layer

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 1180.0 or viewport_size.y < 640.0

	_build_home_status_bar(root, compact, viewport_size.x < 640.0 or viewport_size.x < viewport_size.y * 1.1)

	# A floating command dock uses the graphite-and-amber interface styling
	# while leaving the building visible through the centre of the screen.
	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "Home_Bottom_Navigation"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 18.0 if not compact else 10.0
	bottom_panel.offset_top = -88.0 if not compact else -78.0
	bottom_panel.offset_right = -18.0 if not compact else -10.0
	bottom_panel.offset_bottom = -12.0 if not compact else -10.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.028, 0.030, 0.86)
	panel_style.border_color = Color(0.58, 0.46, 0.29, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.border_width_top = 2
	panel_style.set_corner_radius_all(17)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	panel_style.shadow_size = 16
	panel_style.shadow_offset = Vector2(0.0, 5.0)
	panel_style.anti_aliasing = true
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 6.0
	panel_style.content_margin_bottom = 6.0
	bottom_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(bottom_panel)

	var row := HBoxContainer.new()
	row.name = "Home_Navigation_Buttons_Row"
	row.add_theme_constant_override("separation", 6)
	bottom_panel.add_child(row)

	var nav_items := [
		{"name": "Create", "index": "01"},
		{"name": "Products", "index": "02"},
		{"name": "Research", "index": "03"},
		{"name": "Marketing", "index": "04"},
		{"name": "Media", "index": "05"},
		{"name": "Office", "index": "06"},
		{"name": "Statistics", "index": "07"}
	]
	for item in nav_items:
		var button_name := str(item["name"])
		var button := Button.new()
		button.name = button_name + "_Button"
		button.text = "%s   %s" % [str(item["index"]), button_name.to_upper()]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 48.0 if compact else 54.0)
		button.focus_mode = Control.FOCUS_NONE
		_style_landing_command_button(button, false)
		_apply_home_bold_typography(button, 12 if compact else 15)
		row.add_child(button)

		if button_name == "Create":
			button.pressed.connect(_show_create_scene)
		elif button_name == "Research":
			button.pressed.connect(_show_research_scene)
		elif button_name == "Office":
			button.pressed.connect(_show_office_hub)

	# Home is shown fully formed immediately after the loading layer is removed.


func _build_home_status_bar(root: Control, compact: bool = false, stacked: bool = false) -> void:
	var header: Control
	if stacked:
		var stacked_header := VBoxContainer.new()
		header = stacked_header
		stacked_header.add_theme_constant_override("separation", 8)
		stacked_header.offset_left = 14.0
		stacked_header.offset_top = 12.0
		stacked_header.offset_right = -14.0
		stacked_header.offset_bottom = 146.0
	else:
		var aligned_header := HBoxContainer.new()
		header = aligned_header
		aligned_header.add_theme_constant_override("separation", 14 if compact else 18)
		aligned_header.offset_left = 14.0 if compact else 26.0
		aligned_header.offset_top = 12.0 if compact else 18.0
		aligned_header.offset_right = -14.0 if compact else -26.0
		aligned_header.offset_bottom = 88.0 if compact else 100.0

	header.name = "Home_Premium_Header"
	header.anchor_left = 0.0
	header.anchor_top = 0.0
	header.anchor_right = 1.0
	header.anchor_bottom = 0.0
	root.add_child(header)

	var identity := _make_home_identity_card(compact, stacked)
	header.add_child(identity)

	if not compact and not stacked:
		var spacer := Control.new()
		spacer.name = "Home_Header_Flexible_Spacer"
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)

	var metrics := HBoxContainer.new()
	metrics.name = "Home_Status_Metrics"
	metrics.add_theme_constant_override("separation", 8)
	metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	header.add_child(metrics)

	home_balance_label = _make_home_metric_card(
		metrics, "Company_Balance_Card", "AVAILABLE BALANCE", 166.0, 18, Color("#f0c36a"), compact
	)
	home_date_label = _make_home_metric_card(
		metrics, "Game_Date_Card", "IN-GAME DATE", 148.0, 16, Color("#f4f6fa"), compact
	)

	var clock_card := _make_home_status_glass_card("Game_Clock_Card")
	clock_card.custom_minimum_size = Vector2(0.0 if compact else 126.0, 60.0 if compact else 76.0)
	clock_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	metrics.add_child(clock_card)

	var clock_content := VBoxContainer.new()
	clock_content.add_theme_constant_override("separation", 2)
	clock_content.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_card.add_child(clock_content)
	clock_content.add_child(_label("GAME CLOCK", 9, Color("#C8BCA9"), HORIZONTAL_ALIGNMENT_CENTER))

	home_time_button = Button.new()
	home_time_button.name = "Game_Time_Control"
	home_time_button.custom_minimum_size = Vector2(0.0, 32.0)
	home_time_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_time_button.focus_mode = Control.FOCUS_NONE
	home_time_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_apply_home_bold_typography(home_time_button, 15)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var clock_style := StyleBoxFlat.new()
		clock_style.bg_color = Color(0.34, 0.22, 0.09, 0.92)
		clock_style.border_color = Color(0.66, 0.52, 0.31, 0.78)
		clock_style.set_border_width_all(1)
		clock_style.set_corner_radius_all(9)
		clock_style.content_margin_left = 7
		clock_style.content_margin_right = 7
		clock_style.content_margin_top = 4
		clock_style.content_margin_bottom = 4
		clock_style.anti_aliasing = true
		home_time_button.add_theme_stylebox_override(state, clock_style)
	home_time_button.add_theme_color_override("font_color", Color("#f5f8fc"))
	home_time_button.add_theme_color_override("font_hover_color", Color("#f5f8fc"))
	home_time_button.add_theme_color_override("font_pressed_color", Color("#f5f8fc"))
	home_time_button.add_theme_color_override("font_focus_color", Color("#f5f8fc"))
	home_time_button.add_theme_color_override("font_disabled_color", Color("#f5f8fc"))
	home_time_button.pressed.connect(_toggle_game_clock)
	clock_content.add_child(home_time_button)

	_update_home_status_bar()


func _make_home_identity_card(compact: bool, stacked: bool) -> Control:
	# Keep the company name in its own guaranteed-width label beside the mark.
	# No nested panel container can consume the label's horizontal space.
	var identity := HBoxContainer.new()
	identity.name = "Company_Identity_Block"
	identity.custom_minimum_size = Vector2(0.0 if compact else 340.0, 64.0 if compact else 76.0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_SHRINK_BEGIN
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_theme_constant_override("separation", 12)

	var insignia_frame := PanelContainer.new()
	insignia_frame.name = "Home_Insignia_Frame"
	insignia_frame.custom_minimum_size = Vector2(54.0, 54.0)
	insignia_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	insignia_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var insignia_style := StyleBoxFlat.new()
	insignia_style.bg_color = Color(0.18, 0.16, 0.13, 0.66)
	insignia_style.border_color = Color(0.68, 0.53, 0.31, 0.72)
	insignia_style.set_border_width_all(1)
	insignia_style.set_corner_radius_all(14)
	insignia_style.content_margin_left = 5
	insignia_style.content_margin_right = 5
	insignia_style.content_margin_top = 5
	insignia_style.content_margin_bottom = 5
	insignia_frame.add_theme_stylebox_override("panel", insignia_style)
	identity.add_child(insignia_frame)

	var insignia := TextureRect.new()
	insignia.name = "Home_Company_Insignia"
	insignia.texture = _company_logo_texture(clampi(int(career.get("logo_id", 1)), 1, 50))
	insignia.custom_minimum_size = Vector2(42.0, 42.0)
	insignia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insignia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insignia_frame.add_child(insignia)

	var accent := ColorRect.new()
	accent.name = "Identity_Amber_Accent"
	accent.custom_minimum_size = Vector2(3.0, 48.0)
	accent.color = Color("#C58A3A")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(accent)

	var copy := VBoxContainer.new()
	copy.name = "Company_Identity_Copy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(copy)

	var brand_line := _label("DIGITAL WORLD MOBILES  /  POWERED BY KINGSHALL", 9, Color("#D2A15C"))
	brand_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	brand_line.clip_text = true
	_apply_shared_page_typography(brand_line, 10)
	copy.add_child(brand_line)

	home_company_label = Label.new()
	home_company_label.name = "Company_Name"
	home_company_label.text = str(career.get("company_name", "YOUR COMPANY"))
	home_company_label.custom_minimum_size = Vector2(180.0, 30.0)
	home_company_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_company_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	home_company_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_company_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	home_company_label.clip_text = true
	home_company_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	home_company_label.tooltip_text = home_company_label.text
	_apply_home_bold_typography(home_company_label, 25 if not compact else 22)
	home_company_label.add_theme_color_override("font_color", Color("#ffffff"))
	home_company_label.add_theme_color_override("font_outline_color", Color("#080A0A"))
	home_company_label.add_theme_constant_override("outline_size", 2)
	copy.add_child(home_company_label)

	var founder_name := str(career.get("full_name", "FOUNDER")).strip_edges()
	if founder_name.is_empty():
		founder_name = "FOUNDER"
	var office_detail := "NO HEADQUARTERS OWNED" if upgrade_level <= 0 else "HEADQUARTERS  /  LEVEL %02d" % upgrade_level
	var detail := _label("%s   •   FOUNDER: %s" % [office_detail, founder_name], 8, Color("#C8BFB1"))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.clip_text = true
	copy.add_child(detail)

	return identity


func _make_home_metric_card(
	parent: Control,
	card_name: String,
	caption: String,
	width: float,
	value_font_size: int,
	value_color: Color,
	compact: bool
) -> Label:
	var card := _make_home_status_glass_card(card_name)
	card.custom_minimum_size = Vector2(0.0 if compact else width, 60.0 if compact else 76.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	parent.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(content)

	var caption_label := _label(caption, 8, Color("#C8BCA9"), HORIZONTAL_ALIGNMENT_CENTER)
	caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption_label.clip_text = true
	content.add_child(caption_label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size = Vector2(0.0, 26.0)
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_home_bold_typography(value_label, value_font_size if not compact else mini(value_font_size, 14))
	value_label.add_theme_color_override("font_color", value_color)
	value_label.add_theme_color_override("font_outline_color", Color("#080A0A"))
	value_label.add_theme_constant_override("outline_size", 1)
	content.add_child(value_label)
	return value_label


func _make_home_status_glass_card(card_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.039, 0.041, 0.90)
	style.border_color = Color(0.58, 0.46, 0.29, 0.68)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.025, 0.008, 0.40)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	style.anti_aliasing = true
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
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
	if is_instance_valid(home_company_label):
		home_company_label.text = str(career.get("company_name", "YOUR COMPANY"))
		home_company_label.tooltip_text = home_company_label.text
	if is_instance_valid(home_time_button):
		home_time_button.text = "▶  PLAY" if game_clock_paused else "Ⅱ  PAUSE"


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
	root.modulate.a = 0.0

	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y < 540.0 or viewport_size.x < 920.0
	var content_width := minf(620.0, maxf(270.0, viewport_size.x - (56.0 if compact else 88.0)))

	# The preparation page uses the graphite atmosphere and subtle warm-metal
	# accent shared by the landing and company setup screens.
	var background := ColorRect.new()
	background.name = "Headquarters_Preparation_Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_shader := Shader.new()
	background_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5);
	vec2 stretched = p * vec2(1.0, 1.25);
	float glow = exp(-dot(stretched, stretched) * 5.0);
	float edge = smoothstep(0.12, 0.82, length(p));
	vec3 graphite = vec3(0.075, 0.078, 0.080);
	vec3 deep = vec3(0.012, 0.014, 0.015);
	vec3 base = mix(graphite, deep, edge * 0.88);
	base += vec3(0.035, 0.022, 0.008) * glow;
	COLOR = vec4(base, 1.0);
}
"""
	var background_material := ShaderMaterial.new()
	background_material.shader = background_shader
	background.material = background_material
	root.add_child(background)

	var center := CenterContainer.new()
	center.name = "Headquarters_Preparation_Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var content := VBoxContainer.new()
	content.name = "Headquarters_Preparation_Content"
	content.custom_minimum_size = Vector2(content_width, 0.0)
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10 if compact else 15)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.modulate.a = 0.0
	content.pivot_offset = Vector2(content_width * 0.5, 132.0 if compact else 154.0)
	center.add_child(content)

	var accent := ColorRect.new()
	accent.name = "Preparation_Accent"
	accent.custom_minimum_size = Vector2(96.0, 4.0)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accent.color = Color("#D2A15C")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(accent)

	var brand := Label.new()
	brand.text = "DIGITAL WORLD MOBILES"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_home_button_typography(brand, 16 if compact else 18)
	brand.add_theme_color_override("font_color", Color("#C8BCA9"))
	brand.add_theme_color_override("font_outline_color", Color("#080A0A"))
	brand.add_theme_constant_override("outline_size", 1)
	content.add_child(brand)

	var title := Label.new()
	title.name = "Preparation_Title"
	title.text = "PREPARING YOUR HEADQUARTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(0.0, 58.0 if compact else 70.0)
	_apply_home_button_typography(title, 29 if compact else 36)
	title.add_theme_color_override("font_color", Color("#f5f8fc"))
	title.add_theme_color_override("font_outline_color", Color("#080A0A"))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.025, 0.008, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title)

	var company_label := Label.new()
	company_label.name = "Preparation_Company"
	company_label.text = str(career.get("company_name", "YOUR COMPANY"))
	company_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	company_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	company_label.custom_minimum_size = Vector2(0.0, 34.0)
	_apply_home_button_typography(company_label, 20 if compact else 23)
	company_label.add_theme_color_override("font_color", Color("#E5DFD4"))
	company_label.add_theme_color_override("font_outline_color", Color("#080A0A"))
	company_label.add_theme_constant_override("outline_size", 1)
	content.add_child(company_label)

	var loading_status_label_new := Label.new()
	loading_status_label = loading_status_label_new
	loading_status_label.name = "Preparation_Status"
	loading_status_label.text = "Initializing game..."
	loading_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_apply_home_button_typography(loading_status_label, 17 if compact else 19)
	loading_status_label.add_theme_color_override("font_color", Color("#F2EDE4"))
	loading_status_label.add_theme_color_override("font_outline_color", Color("#080A0A"))
	loading_status_label.add_theme_constant_override("outline_size", 1)
	content.add_child(loading_status_label)

	var progress_heading := HBoxContainer.new()
	progress_heading.name = "Preparation_Progress_Heading"
	progress_heading.add_theme_constant_override("separation", 8)
	content.add_child(progress_heading)

	var progress_caption := Label.new()
	progress_caption.text = "SETUP PROGRESS"
	progress_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_home_button_typography(progress_caption, 12 if compact else 14)
	progress_caption.add_theme_color_override("font_color", Color("#D2A15C"))
	progress_heading.add_child(progress_caption)

	loading_percent_label = Label.new()
	loading_percent_label.name = "Preparation_Percentage"
	loading_percent_label.text = "5%"
	loading_percent_label.custom_minimum_size = Vector2(58.0, 0.0)
	loading_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_home_button_typography(loading_percent_label, 14 if compact else 16)
	loading_percent_label.add_theme_color_override("font_color", Color("#f4f6fa"))
	progress_heading.add_child(loading_percent_label)

	loading_progress_bar = ProgressBar.new()
	loading_progress_bar.name = "Preparation_Progress"
	loading_progress_bar.custom_minimum_size = Vector2(0.0, 12.0 if compact else 14.0)
	loading_progress_bar.min_value = 0.0
	loading_progress_bar.max_value = 100.0
	loading_progress_bar.value = 5.0
	loading_progress_bar.show_percentage = false
	loading_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color(0.055, 0.060, 0.062, 0.96)
	progress_track.border_color = Color(0.58, 0.46, 0.29, 0.72)
	progress_track.set_border_width_all(1)
	progress_track.set_corner_radius_all(8)
	loading_progress_bar.add_theme_stylebox_override("background", progress_track)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("#C58A3A")
	progress_fill.border_color = Color("#E2C58E")
	progress_fill.set_border_width_all(1)
	progress_fill.set_corner_radius_all(8)
	loading_progress_bar.add_theme_stylebox_override("fill", progress_fill)
	content.add_child(loading_progress_bar)

	var footer := Label.new()
	footer.text = "POWERED BY KINGSHALL"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_home_button_typography(footer, 11 if compact else 12)
	footer.add_theme_color_override("font_color", Color("#A19A8F"))
	content.add_child(footer)

	# A restrained entrance and breathing accent keep the screen polished
	# without distracting from the live preparation status.
	var entrance := create_tween()
	entrance.set_parallel(true)
	entrance.tween_property(root, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(content, "modulate:a", 1.0, 0.52).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(content, "scale", Vector2.ONE, 0.5).from(Vector2(0.985, 0.985)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if loading_accent_tween != null and loading_accent_tween.is_running():
		loading_accent_tween.kill()
	loading_accent_tween = create_tween()
	loading_accent_tween.set_loops()
	loading_accent_tween.tween_property(accent, "modulate:a", 0.58, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loading_accent_tween.tween_property(accent, "modulate:a", 1.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_headquarters_loading(message: String, progress: float) -> void:
	var safe_progress := clampf(progress, 0.0, 100.0)
	if is_instance_valid(loading_status_label) and loading_status_label.text != message:
		var status_fade := create_tween()
		status_fade.tween_property(loading_status_label, "modulate:a", 0.35, 0.07)
		status_fade.tween_callback(func():
			if is_instance_valid(loading_status_label):
				loading_status_label.text = message
		)
		status_fade.tween_property(loading_status_label, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(loading_percent_label):
		loading_percent_label.text = "%d%%" % roundi(safe_progress)
	if is_instance_valid(loading_progress_bar):
		if loading_progress_tween != null and loading_progress_tween.is_running():
			loading_progress_tween.kill()
		loading_progress_tween = create_tween()
		loading_progress_tween.tween_property(loading_progress_bar, "value", safe_progress, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _finish_headquarters_loading() -> void:
	# A single guarded completion path prevents duplicate reveal sequences.
	if headquarters_loading_finish_started:
		return
	headquarters_loading_finish_started = true

	# This callback is connected to the headquarters' setup_completed signal.
	# That signal is emitted by the actual builder only after construction,
	# camera setup, and the final setup frame are complete. The progress bar
	# is visual feedback only and must never delay or trigger this handoff.
	if not is_instance_valid(world_root):
		headquarters_loading_finish_started = false
		return

	if loading_progress_tween != null and loading_progress_tween.is_running():
		loading_progress_tween.kill()
	loading_progress_tween = null
	if loading_accent_tween != null and loading_accent_tween.is_running():
		loading_accent_tween.kill()
	loading_accent_tween = null

	# Queue the loading layer for removal, then construct Home in this same
	# frame. Godot removes the queued loading layer at frame end, revealing
	# the already-created Home and headquarters together—no empty green frame,
	# progress-bar wait, timer, crossfade, or extra process-frame pause.
	var preparation_layer := ui_layer
	ui_layer = null
	ui_root = null
	loading_status_label = null
	loading_percent_label = null
	loading_progress_bar = null
	if is_instance_valid(preparation_layer):
		preparation_layer.queue_free()

	world_root.visible = true
	_show_home_navigation()

	# Prepare staff pages after Home is already on screen so their setup cannot
	# create a blank gap between the loading screen and the Home page.
	call_deferred("_prepare_staff_scenes")


func _show_create_scene() -> void:
	current_screen = "create"
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	if is_instance_valid(world_root) and world_root.has_method("set_preview_active"):
		world_root.set_preview_active(false)

	# Reuse the product page when returning from a product editor.
	if is_instance_valid(create_ui_layer) and is_instance_valid(create_ui_root):
		if is_instance_valid(ui_layer) and ui_layer != create_ui_layer:
			ui_layer.queue_free()
		ui_layer = create_ui_layer
		ui_root = create_ui_root
		ui_layer.show()
		return

	# Keep the already-built headquarters resident but inactive behind this page.
	# It is restored directly when the player returns to Home.
	var root := _new_screen()
	root.name = "CreateProductScreen"
	root.modulate.a = 0.0
	create_ui_layer = ui_layer
	create_ui_root = ui_root

	# Use the shared photographic background as the page backdrop.
	var vignette := ColorRect.new()
	vignette.name = "CreateProductVignette"
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
	var margin_x := 14 if compact else 48
	var margin_y := 12 if compact else 24
	var frame := MarginContainer.new()
	frame.name = "CreateProductFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", margin_x)
	frame.add_theme_constant_override("margin_right", margin_x)
	frame.add_theme_constant_override("margin_top", margin_y)
	frame.add_theme_constant_override("margin_bottom", margin_y)
	root.add_child(frame)

	# No ScrollContainer: the back control and all four cards stay on one screen.
	var page := VBoxContainer.new()
	page.name = "CreateProductContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10 if compact else 16)
	frame.add_child(page)

	var top_bar := HBoxContainer.new()
	top_bar.name = "CreateProductTopBar"
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(top_bar)

	var back_button := _add_action_button(top_bar, "BACK  ‹", false, _return_to_home)
	back_button.custom_minimum_size = Vector2(94 if compact else 124, 40 if compact else 48)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_landing_command_button(back_button, false)
	_apply_shared_page_typography(back_button, 13 if compact else 15)

	var grid := GridContainer.new()
	grid.name = "Create_Category_Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10 if compact else 18)
	grid.add_theme_constant_override("v_separation", 10 if compact else 18)
	page.add_child(grid)

	var horizontal_page_width := maxf(0.0, viewport_size.x - float(margin_x * 2))
	var card_width := maxf(1.0, (horizontal_page_width - (10.0 if compact else 18.0)) * 0.5)
	var available_grid_height := viewport_size.y - float(margin_y * 2) - (40.0 if compact else 48.0) - (10.0 if compact else 16.0) - (10.0 if compact else 18.0)
	var card_height := maxf(108.0 if compact else 170.0, available_grid_height * 0.5)
	var categories := [
		{"name": "PHONE", "number": "01", "descriptor": "THE FLAGSHIP", "description": "Shape every detail of your smartphone, from its physical design to the experience inside."},
		{"name": "PROCESSOR", "number": "02", "descriptor": "THE PERFORMANCE", "description": "Create the silicon that drives speed, efficiency and the next generation of mobile power."},
		{"name": "OPERATING SYSTEM", "number": "03", "descriptor": "THE EXPERIENCE", "description": "Build the software platform, interface and intelligent features behind your devices."},
		{"name": "CAMERA", "number": "04", "descriptor": "THE IMAGING", "description": "Develop camera systems and imaging technology that capture every detail."}
	]

	for category in categories:
		var card := PanelContainer.new()
		card.name = str(category["name"]).replace(" ", "_") + "_Category_Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(card_width, card_height)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.018, 0.065, 0.039, 0.84)
		card_style.border_color = Color(0.58, 0.46, 0.29, 0.62)
		card_style.set_border_width_all(1)
		card_style.border_width_top = 2
		card_style.set_corner_radius_all(18)
		card_style.shadow_color = Color(0.0, 0.025, 0.008, 0.48)
		card_style.shadow_size = 14
		card_style.shadow_offset = Vector2(0.0, 5.0)
		card_style.anti_aliasing = true
		card_style.content_margin_left = 12 if compact else 22
		card_style.content_margin_right = 12 if compact else 22
		card_style.content_margin_top = 10 if compact else 20
		card_style.content_margin_bottom = 10 if compact else 20
		card.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card)

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 4 if compact else 7)
		card.add_child(content)

		var top_line := HBoxContainer.new()
		top_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(top_line)
		var index := _label(str(category["number"]) + "  /  PRODUCT TYPE", 8 if compact else 10, Color("#D2A15C"))
		index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_line.add_child(index)
		top_line.add_child(_label("✦", 12, Color("#D2A15C")))

		var category_title := _label(str(category["name"]), 15 if compact else 22, Color("#f4f6fa"))
		category_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_menu_3d_label(category_title, 1)
		content.add_child(category_title)
		content.add_child(_label(str(category["descriptor"]), 8 if compact else 10, Color("#BFA579")))

		var divider := ColorRect.new()
		divider.custom_minimum_size = Vector2(0, 1)
		divider.color = Color(0.58, 0.46, 0.29, 0.30)
		content.add_child(divider)

		var description := _label(str(category["description"]), 9 if compact else 13, Color("#CFC7BA"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(description)

		var choose := _add_action_button(content, "EXPLORE CATEGORY  ›", true, _on_create_category_pressed.bind(str(category["name"])))
		choose.custom_minimum_size = Vector2(0, 34 if compact else 48)
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_landing_command_button(choose, true)
		_apply_shared_page_typography(choose, 10 if compact else 13)

	var entrance := create_tween()
	entrance.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(root, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _show_research_scene() -> void:
	current_screen = "research"
	if is_instance_valid(home_navigation_layer):
		home_navigation_layer.hide()
		home_navigation_layer.queue_free()
	home_navigation_layer = null
	if is_instance_valid(world_root) and world_root.has_method("set_preview_active"):
		world_root.set_preview_active(false)

	# Keep the already-built headquarters resident but inactive behind this page.
	# It is restored directly when the player returns to Home.
	var root := _new_screen()
	root.name = "ResearchDevelopmentScreen"
	root.modulate.a = 0.0

	# Match the Create Product page: keep the photo visible and avoid a
	# scrolling page or extra headings outside the research cards.
	var vignette := ColorRect.new()
	vignette.name = "ResearchDevelopmentVignette"
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
	var margin_x := 14 if compact else 48
	var margin_y := 12 if compact else 24
	var frame := MarginContainer.new()
	frame.name = "ResearchDevelopmentFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", margin_x)
	frame.add_theme_constant_override("margin_right", margin_x)
	frame.add_theme_constant_override("margin_top", margin_y)
	frame.add_theme_constant_override("margin_bottom", margin_y)
	root.add_child(frame)

	var page := VBoxContainer.new()
	page.name = "ResearchDevelopmentContent"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10 if compact else 16)
	frame.add_child(page)

	var top_bar := HBoxContainer.new()
	top_bar.name = "ResearchDevelopmentTopBar"
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(top_bar)

	var back_button := _add_action_button(top_bar, "BACK  ‹", false, _return_home_from_research)
	back_button.custom_minimum_size = Vector2(94 if compact else 124, 40 if compact else 48)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_landing_command_button(back_button, false)
	_apply_shared_page_typography(back_button, 13 if compact else 15)

	var grid := GridContainer.new()
	grid.name = "Research_Product_Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10 if compact else 18)
	grid.add_theme_constant_override("v_separation", 10 if compact else 18)
	page.add_child(grid)

	var horizontal_page_width := maxf(0.0, viewport_size.x - float(margin_x * 2))
	var card_width := maxf(1.0, (horizontal_page_width - (10.0 if compact else 18.0)) * 0.5)
	var available_grid_height := viewport_size.y - float(margin_y * 2) - (40.0 if compact else 48.0) - (10.0 if compact else 16.0) - (10.0 if compact else 18.0)
	var card_height := maxf(108.0 if compact else 170.0, available_grid_height * 0.5)
	var categories := [
		{"name": "PHONE", "number": "01", "descriptor": "DEVICE ENGINEERING", "description": "Research the materials, dimensions and technology behind your next smartphone."},
		{"name": "PROCESSOR", "number": "02", "descriptor": "CHIPSET INNOVATION", "description": "Advance processing power, graphics performance and energy efficiency."},
		{"name": "OPERATING SYSTEM", "number": "03", "descriptor": "SOFTWARE DEVELOPMENT", "description": "Improve the platform, interface and core software experience."},
		{"name": "CAMERA", "number": "04", "descriptor": "IMAGING TECHNOLOGY", "description": "Explore camera modules, sensors and next-generation image processing."}
	]

	for category in categories:
		var card := PanelContainer.new()
		card.name = str(category["name"]).replace(" ", "_") + "_Research_Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(card_width, card_height)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.018, 0.065, 0.039, 0.84)
		card_style.border_color = Color(0.58, 0.46, 0.29, 0.62)
		card_style.set_border_width_all(1)
		card_style.border_width_top = 2
		card_style.set_corner_radius_all(18)
		card_style.shadow_color = Color(0.0, 0.025, 0.008, 0.48)
		card_style.shadow_size = 14
		card_style.shadow_offset = Vector2(0.0, 5.0)
		card_style.anti_aliasing = true
		card_style.content_margin_left = 12 if compact else 22
		card_style.content_margin_right = 12 if compact else 22
		card_style.content_margin_top = 10 if compact else 20
		card_style.content_margin_bottom = 10 if compact else 20
		card.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card)

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 4 if compact else 7)
		card.add_child(content)

		var top_line := HBoxContainer.new()
		top_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(top_line)
		var index := _label(str(category["number"]) + "  /  RESEARCH", 8 if compact else 10, Color("#D2A15C"))
		index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_line.add_child(index)
		top_line.add_child(_label("✦", 12, Color("#D2A15C")))

		var category_title := _label(str(category["name"]), 15 if compact else 22, Color("#f4f6fa"))
		category_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_menu_3d_label(category_title, 1)
		content.add_child(category_title)
		content.add_child(_label(str(category["descriptor"]), 8 if compact else 10, Color("#BFA579")))

		var divider := ColorRect.new()
		divider.custom_minimum_size = Vector2(0, 1)
		divider.color = Color(0.58, 0.46, 0.29, 0.30)
		content.add_child(divider)

		var description := _label(str(category["description"]), 9 if compact else 13, Color("#CFC7BA"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(description)

		var explore := _add_action_button(content, "OPEN RESEARCH  ›", true, _on_research_category_pressed.bind(str(category["name"])))
		explore.custom_minimum_size = Vector2(0, 34 if compact else 48)
		explore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_landing_command_button(explore, true)
		_apply_shared_page_typography(explore, 10 if compact else 13)

	var entrance := create_tween()
	entrance.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrance.tween_property(root, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_research_category_pressed(category: String) -> void:
	if category.to_upper() == "PHONE":
		_show_research_allocation_dashboard()
		return
	_show_notice("RESEARCH", category.capitalize() + " research will be added here.")


func _return_home_from_research() -> void:
	_restore_home_after_standalone_screen()


func _restore_home_after_standalone_screen() -> void:
	# Create and Research only hide the persistent world. Returning to Home
	# restores its visibility and navigation without replaying the loading screen.
	if not is_instance_valid(world_root):
		push_error("Cannot return Home: the original loading-screen headquarters scene is missing.")
		return

	if is_instance_valid(create_ui_layer):
		create_ui_layer.hide()
	if is_instance_valid(ui_layer) and ui_layer != create_ui_layer:
		ui_layer.hide()
		ui_layer.queue_free()
	ui_layer = null
	ui_root = null

	current_screen = "home"
	if not world_root.home_mode:
		world_root.set_home_mode(true)
	world_root.set_preview_active(true)
	_show_home_navigation()


func _open_research_from_phone_creation_worksite() -> void:
	if not is_instance_valid(phone_creation_worksite):
		return
	if research_dashboard_return_to_worksite:
		return
	# The worksite runs without the normal screen UI root, so open research in
	# a dedicated top-layer CanvasLayer and restore the same worksite on return.
	phone_creation_worksite.process_mode = Node.PROCESS_MODE_DISABLED
	phone_creation_worksite.hide()
	for child in phone_creation_worksite.get_children():
		if child is CanvasLayer:
			child.hide()
	worksite_research_overlay_layer = CanvasLayer.new()
	worksite_research_overlay_layer.name = "WorksiteResearchOverlay"
	worksite_research_overlay_layer.layer = 100
	add_child(worksite_research_overlay_layer)
	var overlay_root := Control.new()
	overlay_root.name = "WorksiteResearchRoot"
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	worksite_research_overlay_layer.add_child(overlay_root)
	ui_layer = worksite_research_overlay_layer
	ui_root = overlay_root
	research_dashboard_return_to_worksite = true
	_show_research_allocation_dashboard()


func _show_research_allocation_dashboard() -> void:
	# Phone now opens the company-level research dashboard, not the legacy
	# component-by-component upgrade catalogue.
	if not is_instance_valid(ui_root):
		push_error("Cannot open Research Allocation: the Research screen root is missing.")
		return
	if is_instance_valid(research_allocation_dashboard):
		research_allocation_dashboard.queue_free()
	research_allocation_dashboard = ResearchAllocationDashboardScene.instantiate() as Control
	if not is_instance_valid(research_allocation_dashboard):
		push_error("Could not instantiate the Company Research Allocation Dashboard.")
		return
	research_allocation_dashboard.name = "CompanyResearchAllocationDashboard"
	research_allocation_dashboard.call("configure", _get_research_dashboard_data())
	research_allocation_dashboard.connect("back_requested", Callable(self, "_return_from_research_allocation_dashboard"))
	research_allocation_dashboard.connect("project_commission_requested", Callable(self, "_on_rd_project_commission_requested"))
	research_allocation_dashboard.connect("project_approve_requested", Callable(self, "_on_rd_project_approve_requested"))
	research_allocation_dashboard.connect("project_reject_requested", Callable(self, "_on_rd_project_reject_requested"))
	ui_root.add_child(research_allocation_dashboard)
	current_screen = "research_allocation"


func _get_research_dashboard_data() -> Dictionary:
	return {
		"company_name": str(career.get("company_name", "Your Company")),
		"balance": float(career.get("balance", 0.0)),
		"staff_employees": career.get("staff_employees", []),
		"research_projects": career.get("research_projects", []),
		"research_technologies": career.get("research_technologies", {}),
		"research_component_levels": career.get("research_component_levels", {}),
		"research_history": career.get("research_history", []),
		"game_date_unix": game_date_unix
	}


func _refresh_research_dashboard() -> void:
	if is_instance_valid(research_allocation_dashboard):
		research_allocation_dashboard.call("configure", _get_research_dashboard_data())


func _on_rd_project_commission_requested(request: Dictionary) -> void:
	var result := commission_research_project(request)
	if not bool(result.get("ok", false)):
		_show_notice("PROJECT NOT COMMISSIONED", str(result.get("error", "The project could not be commissioned.")))
		return
	if is_instance_valid(research_allocation_dashboard):
		research_allocation_dashboard.call("complete_creation_flow")
	_refresh_research_dashboard()
	_show_notice("PROJECT COMMISSIONED", "Research project %s has been created and assigned to its research team." % str(result.get("project", {}).get("id", "")))


func _on_rd_project_approve_requested(project_id: String, results: Array) -> void:
	var result := approve_research_project(project_id, results)
	if not bool(result.get("ok", false)):
		_show_notice("APPROVAL FAILED", str(result.get("error", "The research findings could not be approved.")))
		return
	_refresh_research_dashboard()
	if is_instance_valid(phone_creation_worksite):
		phone_creation_worksite.call("set_screen_width_research_level", int(career.get("research_component_levels", {}).get("Screen Width", 0)))
		phone_creation_worksite.call("set_screen_height_research_level", int(career.get("research_component_levels", {}).get("Screen Height", 0)))
		phone_creation_worksite.call("set_curved_screen_horizontal_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Horizontal", 0)))
		phone_creation_worksite.call("set_curved_screen_vertical_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Vertical", 0)))
		phone_creation_worksite.call("set_curved_screen_both_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Both", 0)))
		phone_creation_worksite.call("set_ram_technology_research_level", int(career.get("research_component_levels", {}).get("RAM Technology", 0)))
		phone_creation_worksite.call("set_ram_capacity_research_level", int(career.get("research_component_levels", {}).get("RAM", 0)))
		phone_creation_worksite.call("set_internal_storage_research_level", int(career.get("research_component_levels", {}).get("Internal Storage", 0)))
		phone_creation_worksite.call("set_mobile_network_research_level", int(career.get("research_component_levels", {}).get("Mobile Network", 0)))
		phone_creation_worksite.call("set_wifi_research_level", int(career.get("research_component_levels", {}).get("Wi-Fi", 0)))
		phone_creation_worksite.call("set_bluetooth_research_level", int(career.get("research_component_levels", {}).get("Bluetooth", 0)))
		phone_creation_worksite.call("set_phone_sensor_research_levels", career.get("research_component_levels", {}))
		phone_creation_worksite.call("set_side_button_research_levels", career.get("research_component_levels", {}))
		phone_creation_worksite.call("set_rear_camera_count_research_level", int(career.get("research_component_levels", {}).get("Rear Camera Count", 0)))
		phone_creation_worksite.call("set_rear_flash_count_research_level", int(career.get("research_component_levels", {}).get("Rear Flash Count", 0)))
	phone_creation_worksite.call("set_back_raised_design_research_level", int(career.get("research_component_levels", {}).get("Back Raised Design", 0)))
	phone_creation_worksite.call("set_device_color_research_level", int(career.get("research_component_levels", {}).get("Device Color", 0)))
	var approved_component := str(result.get("project", {}).get("component", ""))
	var next_mobile_project: Dictionary = result.get("auto_next_project", {}) if approved_component == "Mobile Network" else {}
	var next_wifi_project: Dictionary = result.get("auto_next_project", {}) if approved_component == "Wi-Fi" else {}
	var next_bluetooth_project: Dictionary = result.get("auto_next_project", {}) if approved_component == "Bluetooth" else {}
	if not next_mobile_project.is_empty():
		_show_notice("RESEARCH APPROVED", "The findings were validated. Research has automatically started on %s (%s) with the same team." % [
			str(next_mobile_project.get("research_target", "")),
			str(next_mobile_project.get("research_generation", ""))
		])
	elif not next_wifi_project.is_empty():
		_show_notice("RESEARCH APPROVED", "The findings were validated. Research has automatically started on Wi-Fi %s (%s) with the same team." % [
			str(next_wifi_project.get("research_generation", "")).trim_prefix("Wi-Fi "),
			str(next_wifi_project.get("research_target", ""))
		])
	elif not next_bluetooth_project.is_empty():
		_show_notice("RESEARCH APPROVED", "The findings were validated. Research has automatically started on %s with the same team." % [
			str(next_bluetooth_project.get("research_target", ""))
		])
	elif not str(result.get("auto_next_project_error", "")).is_empty():
		_show_notice("RESEARCH APPROVED", "The findings were validated, but the next %s project could not start automatically: %s" % [
			approved_component,
			str(result.get("auto_next_project_error", ""))
		])
	else:
		_show_notice("RESEARCH APPROVED", "The validated findings have been recorded in the company's technology development history.")


func _on_rd_project_reject_requested(project_id: String, review_note: String) -> void:
	var result := reject_research_project(project_id, review_note)
	if not bool(result.get("ok", false)):
		_show_notice("REVIEW FAILED", str(result.get("error", "The research findings could not be rejected.")))
		return
	_refresh_research_dashboard()
	_show_notice("FINDINGS REJECTED", "The project review decision has been recorded.")


func get_research_workforce_summary() -> Dictionary:
	return ResearchManagerScript.get_workforce_summary(career)


func commission_research_project(request: Dictionary) -> Dictionary:
	var previous_career := career.duplicate(true)
	var result: Dictionary = ResearchManagerScript.commission_project(career, request, game_date_unix)
	if not bool(result.get("ok", false)):
		return result
	if not _save_career():
		career = previous_career
		return {"ok": false, "error": "The project could not be saved. No funds were deducted."}
	_update_home_status_bar()
	return result


func approve_research_project(project_id: String, results: Array) -> Dictionary:
	var previous_career := career.duplicate(true)
	var result: Dictionary = ResearchManagerScript.approve_project(career, project_id, results, game_date_unix)
	if not bool(result.get("ok", false)):
		return result

	var approved_project: Dictionary = result.get("project", {})
	if str(approved_project.get("component", "")) in ["Mobile Network", "Wi-Fi", "Bluetooth"]:
		var sequence_component := str(approved_project.get("component", ""))
		var previous_team: Array = approved_project.get("staff_ids", []).duplicate()
		var next_target: Dictionary = {}
		var component_levels: Dictionary = career.get("research_component_levels", {})
		match sequence_component:
			"Mobile Network":
				next_target = ResearchManagerScript.get_mobile_network_research_target(component_levels)
			"Wi-Fi":
				next_target = ResearchManagerScript.get_wifi_research_target(component_levels)
			"Bluetooth":
				next_target = ResearchManagerScript.get_bluetooth_research_target(component_levels)
		if not previous_team.is_empty() and not next_target.is_empty():
			var next_project_result: Dictionary = ResearchManagerScript.commission_project(career, {
				"component": sequence_component,
				"staff_ids": previous_team
			}, game_date_unix)
			if bool(next_project_result.get("ok", false)):
				result["auto_next_project"] = next_project_result.get("project", {})
			else:
				result["auto_next_project_error"] = str(next_project_result.get("error", "The next technology could not be started automatically."))

	if not _save_career():
		career = previous_career
		return {"ok": false, "error": "The approval could not be saved. The project remains awaiting validation."}
	if is_instance_valid(phone_creation_worksite):
		phone_creation_worksite.call("set_refresh_rate_research_level", int(career.get("research_component_levels", {}).get("Refresh Rate", 0)))
		phone_creation_worksite.call("set_memory_clock_research_level", int(career.get("research_component_levels", {}).get("Memory Clock", 0)))
		phone_creation_worksite.call("set_cooling_system_research_level", int(career.get("research_component_levels", {}).get("Cooling System Design", 0)))
		phone_creation_worksite.call("set_phone_type_research_level", int(career.get("research_component_levels", {}).get("Phone Type", 0)))
		phone_creation_worksite.call("set_charging_speed_research_level", int(career.get("research_component_levels", {}).get("Charging Speed", 0)))
		phone_creation_worksite.call("set_wireless_charging_research_level", int(career.get("research_component_levels", {}).get("Wireless Charging", 0)))
		phone_creation_worksite.call("set_front_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Front Camera MP", 0)))
		phone_creation_worksite.call("set_rear_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Rear Camera MP", 0)))
		phone_creation_worksite.call("set_rear_camera_count_research_level", int(career.get("research_component_levels", {}).get("Rear Camera Count", 0)))
		phone_creation_worksite.call("set_rear_flash_count_research_level", int(career.get("research_component_levels", {}).get("Rear Flash Count", 0)))
	phone_creation_worksite.call("set_back_raised_design_research_level", int(career.get("research_component_levels", {}).get("Back Raised Design", 0)))
	phone_creation_worksite.call("set_device_color_research_level", int(career.get("research_component_levels", {}).get("Device Color", 0)))
	return result


func reject_research_project(project_id: String, review_note: String) -> Dictionary:
	var previous_career := career.duplicate(true)
	var result: Dictionary = ResearchManagerScript.reject_project(career, project_id, review_note)
	if not bool(result.get("ok", false)):
		return result
	if not _save_career():
		career = previous_career
		return {"ok": false, "error": "The review could not be saved. The project remains awaiting validation."}
	return result


func _return_from_research_allocation_dashboard() -> void:
	if is_instance_valid(research_allocation_dashboard):
		research_allocation_dashboard.queue_free()
	research_allocation_dashboard = null
	if research_dashboard_return_to_worksite:
		research_dashboard_return_to_worksite = false
		if is_instance_valid(worksite_research_overlay_layer):
			worksite_research_overlay_layer.queue_free()
		worksite_research_overlay_layer = null
		ui_layer = null
		ui_root = null
		if is_instance_valid(phone_creation_worksite):
			phone_creation_worksite.process_mode = Node.PROCESS_MODE_INHERIT
			phone_creation_worksite.show()
			for child in phone_creation_worksite.get_children():
				if child is CanvasLayer:
					child.show()
		current_screen = "phone_creation_worksite"
		return
	current_screen = "research"


func _return_to_home() -> void:
	_restore_home_after_standalone_screen()


func _style_create_glass_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#805821") if primary else Color("#292D2F")
		if state == "hover":
			style.bg_color = Color("#956A2E") if primary else Color("#373B3D")
		elif state == "pressed":
			style.bg_color = Color("#61431C") if primary else Color("#202325")
		style.border_color = Color("#A17A42") if primary else Color("#55524A")
		style.set_border_width_all(1)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_color_override("font_hover_color", Color("#F2EDE4"))
	button.add_theme_color_override("font_pressed_color", Color("#F2EDE4"))
	button.add_theme_color_override("font_focus_color", Color("#F2EDE4"))

func _on_create_category_pressed(category: String) -> void:
	if category.to_upper() == "PHONE":
		_show_phone_creation_worksite()
		return
	if category.to_upper() == "OPERATING SYSTEM":
		_show_notice("OPERATING SYSTEM", "Operating System creation is temporarily dormant and will return in a future update.")
		return
	_show_notice("PRODUCT STUDIO", category.capitalize() + " creation will be available here.")


func _dispose_phone_creation_worksite() -> void:
	if not is_instance_valid(phone_creation_worksite):
		phone_creation_worksite = null
		return
	for child in phone_creation_worksite.get_children():
		if child is CanvasLayer:
			child.hide()
	phone_creation_worksite.queue_free()
	phone_creation_worksite = null


func _prepare_phone_creation_worksite() -> void:
	if is_instance_valid(phone_creation_worksite):
		return
	phone_creation_worksite = PhoneCreationWorksiteScene.instantiate() as Node3D
	if not is_instance_valid(phone_creation_worksite):
		push_error("Phone Creation Worksite scene could not be initialized during company startup.")
		return
	phone_creation_worksite.name = "Phone_Creation_Worksite"
	phone_creation_worksite.process_mode = Node.PROCESS_MODE_DISABLED
	phone_creation_worksite.connect("back_requested", Callable(self, "_return_from_phone_creation_worksite"))
	phone_creation_worksite.connect("research_requested", Callable(self, "_open_research_from_phone_creation_worksite"))
	add_child(phone_creation_worksite)
	phone_creation_worksite.hide()
	for child in phone_creation_worksite.get_children():
		if child is CanvasLayer:
			child.hide()
	phone_creation_worksite.call("set_screen_technology_research_level", int(career.get("research_component_levels", {}).get("Screen Technology", 0)))
	phone_creation_worksite.call("set_screen_width_research_level", int(career.get("research_component_levels", {}).get("Screen Width", 0)))
	phone_creation_worksite.call("set_screen_height_research_level", int(career.get("research_component_levels", {}).get("Screen Height", 0)))
	phone_creation_worksite.call("set_curved_screen_horizontal_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Horizontal", 0)))
	phone_creation_worksite.call("set_curved_screen_vertical_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Vertical", 0)))
	phone_creation_worksite.call("set_curved_screen_both_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Both", 0)))
	phone_creation_worksite.call("set_ram_technology_research_level", int(career.get("research_component_levels", {}).get("RAM Technology", 0)))
	phone_creation_worksite.call("set_memory_clock_research_level", int(career.get("research_component_levels", {}).get("Memory Clock", 0)))
	phone_creation_worksite.call("set_ram_capacity_research_level", int(career.get("research_component_levels", {}).get("RAM", 0)))
	phone_creation_worksite.call("set_internal_storage_research_level", int(career.get("research_component_levels", {}).get("Internal Storage", 0)))
	phone_creation_worksite.call("set_cooling_system_research_level", int(career.get("research_component_levels", {}).get("Cooling System Design", 0)))
	phone_creation_worksite.call("set_charge_port_research_level", int(career.get("research_component_levels", {}).get("Charge Port", 0)))
	phone_creation_worksite.call("set_home_button_research_level", int(career.get("research_component_levels", {}).get("Home Button", 0)))
	phone_creation_worksite.call("set_front_camera_research_level", int(career.get("research_component_levels", {}).get("Front Camera", 0)))
	phone_creation_worksite.call("set_front_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Front Camera MP", 0)))
	phone_creation_worksite.call("set_rear_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Rear Camera MP", 0)))
	phone_creation_worksite.call("set_rear_camera_count_research_level", int(career.get("research_component_levels", {}).get("Rear Camera Count", 0)))
	phone_creation_worksite.call("set_rear_flash_count_research_level", int(career.get("research_component_levels", {}).get("Rear Flash Count", 0)))
	phone_creation_worksite.call("set_back_raised_design_research_level", int(career.get("research_component_levels", {}).get("Back Raised Design", 0)))
	phone_creation_worksite.call("set_device_color_research_level", int(career.get("research_component_levels", {}).get("Device Color", 0)))
	phone_creation_worksite.call("set_speaker_research_level", int(career.get("research_component_levels", {}).get("Speakers", 0)))
	phone_creation_worksite.call("set_battery_capacity_research_level", int(career.get("research_component_levels", {}).get("Battery Capacity", 0)))
	phone_creation_worksite.call("set_charging_speed_research_level", int(career.get("research_component_levels", {}).get("Charging Speed", 0)))
	phone_creation_worksite.call("set_wireless_charging_research_level", int(career.get("research_component_levels", {}).get("Wireless Charging", 0)))
	phone_creation_worksite.call("set_front_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Front Camera MP", 0)))
	phone_creation_worksite.call("set_phone_thickness_research_level", int(career.get("research_component_levels", {}).get("Phone Thickness", 0)))
	phone_creation_worksite.call("set_border_radius_research_level", int(career.get("research_component_levels", {}).get("Border Radius", 0)))
	phone_creation_worksite.call("set_wifi_research_level", int(career.get("research_component_levels", {}).get("Wi-Fi", 0)))
	phone_creation_worksite.call("set_bluetooth_research_level", int(career.get("research_component_levels", {}).get("Bluetooth", 0)))
	phone_creation_worksite.call("set_mobile_network_research_level", int(career.get("research_component_levels", {}).get("Mobile Network", 0)))
	phone_creation_worksite.call("set_phone_type_research_level", int(career.get("research_component_levels", {}).get("Phone Type", 0)))
	phone_creation_worksite.call("set_phone_sensor_research_levels", career.get("research_component_levels", {}))
	phone_creation_worksite.call("set_side_button_research_levels", career.get("research_component_levels", {}))
	phone_creation_worksite.call("set_company_branding", str(career.get("company_name", "")), int(career.get("logo_id", 1)))


func _show_phone_creation_worksite() -> void:
	if current_screen == "phone_creation_worksite" and is_instance_valid(phone_creation_worksite):
		return

	if not is_instance_valid(phone_creation_worksite):
		_prepare_phone_creation_worksite()
	if not is_instance_valid(phone_creation_worksite):
		return
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
	current_screen = "phone_creation_worksite"
	phone_creation_worksite.process_mode = Node.PROCESS_MODE_INHERIT
	phone_creation_worksite.show()
	for child in phone_creation_worksite.get_children():
		if child is CanvasLayer:
			child.show()
	phone_creation_worksite.call("set_screen_technology_research_level", int(career.get("research_component_levels", {}).get("Screen Technology", 0)))
	phone_creation_worksite.call("set_screen_width_research_level", int(career.get("research_component_levels", {}).get("Screen Width", 0)))
	phone_creation_worksite.call("set_screen_height_research_level", int(career.get("research_component_levels", {}).get("Screen Height", 0)))
	phone_creation_worksite.call("set_curved_screen_horizontal_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Horizontal", 0)))
	phone_creation_worksite.call("set_curved_screen_vertical_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Vertical", 0)))
	phone_creation_worksite.call("set_curved_screen_both_research_level", int(career.get("research_component_levels", {}).get("Curved Screen Both", 0)))
	phone_creation_worksite.call("set_ram_technology_research_level", int(career.get("research_component_levels", {}).get("RAM Technology", 0)))
	phone_creation_worksite.call("set_memory_clock_research_level", int(career.get("research_component_levels", {}).get("Memory Clock", 0)))
	phone_creation_worksite.call("set_ram_capacity_research_level", int(career.get("research_component_levels", {}).get("RAM", 0)))
	phone_creation_worksite.call("set_internal_storage_research_level", int(career.get("research_component_levels", {}).get("Internal Storage", 0)))
	phone_creation_worksite.call("set_cooling_system_research_level", int(career.get("research_component_levels", {}).get("Cooling System Design", 0)))
	phone_creation_worksite.call("set_charge_port_research_level", int(career.get("research_component_levels", {}).get("Charge Port", 0)))
	phone_creation_worksite.call("set_home_button_research_level", int(career.get("research_component_levels", {}).get("Home Button", 0)))
	phone_creation_worksite.call("set_front_camera_research_level", int(career.get("research_component_levels", {}).get("Front Camera", 0)))
	phone_creation_worksite.call("set_front_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Front Camera MP", 0)))
	phone_creation_worksite.call("set_rear_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Rear Camera MP", 0)))
	phone_creation_worksite.call("set_rear_camera_count_research_level", int(career.get("research_component_levels", {}).get("Rear Camera Count", 0)))
	phone_creation_worksite.call("set_rear_flash_count_research_level", int(career.get("research_component_levels", {}).get("Rear Flash Count", 0)))
	phone_creation_worksite.call("set_back_raised_design_research_level", int(career.get("research_component_levels", {}).get("Back Raised Design", 0)))
	phone_creation_worksite.call("set_device_color_research_level", int(career.get("research_component_levels", {}).get("Device Color", 0)))
	phone_creation_worksite.call("set_speaker_research_level", int(career.get("research_component_levels", {}).get("Speakers", 0)))
	phone_creation_worksite.call("set_battery_capacity_research_level", int(career.get("research_component_levels", {}).get("Battery Capacity", 0)))
	phone_creation_worksite.call("set_charging_speed_research_level", int(career.get("research_component_levels", {}).get("Charging Speed", 0)))
	phone_creation_worksite.call("set_wireless_charging_research_level", int(career.get("research_component_levels", {}).get("Wireless Charging", 0)))
	phone_creation_worksite.call("set_front_camera_mp_research_level", int(career.get("research_component_levels", {}).get("Front Camera MP", 0)))
	phone_creation_worksite.call("set_phone_thickness_research_level", int(career.get("research_component_levels", {}).get("Phone Thickness", 0)))
	phone_creation_worksite.call("set_border_radius_research_level", int(career.get("research_component_levels", {}).get("Border Radius", 0)))
	phone_creation_worksite.call("set_wifi_research_level", int(career.get("research_component_levels", {}).get("Wi-Fi", 0)))
	phone_creation_worksite.call("set_bluetooth_research_level", int(career.get("research_component_levels", {}).get("Bluetooth", 0)))
	phone_creation_worksite.call("set_mobile_network_research_level", int(career.get("research_component_levels", {}).get("Mobile Network", 0)))
	phone_creation_worksite.call("set_phone_type_research_level", int(career.get("research_component_levels", {}).get("Phone Type", 0)))
	phone_creation_worksite.call("set_phone_sensor_research_levels", career.get("research_component_levels", {}))
	phone_creation_worksite.call("set_side_button_research_levels", career.get("research_component_levels", {}))
	phone_creation_worksite.call("set_company_branding", str(career.get("company_name", "")), int(career.get("logo_id", 1)))


func _return_from_phone_creation_worksite() -> void:
	current_screen = "create"
	if is_instance_valid(phone_creation_worksite):
		phone_creation_worksite.process_mode = Node.PROCESS_MODE_DISABLED
		phone_creation_worksite.hide()
		for child in phone_creation_worksite.get_children():
			if child is CanvasLayer:
				child.hide()
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
	shade.color = Color(0.002, 0.008, 0.025, 0.88)
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
	accent.color = Color("#D2A15C")
	stack.add_child(accent)
	var eyebrow := _label("DIGITAL WORLD MOBILES", 13 if compact else 16, Color("#D2A15C"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(eyebrow)
	var heading := _label("SETTINGS", 28 if compact else 34, Color("#f4f6fa"), HORIZONTAL_ALIGNMENT_CENTER)
	_apply_menu_3d_label(heading, 2)
	stack.add_child(heading)
	var description := _label("Personalise the presentation and sound of your game.", 16 if compact else 20, Color("#D6D0C5"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(description)

	var quality_label := _label("GRAPHICS QUALITY", 16 if compact else 19, Color("#F2EDE4"))
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
	sound.add_theme_color_override("font_color", Color("#F2EDE4"))
	stack.add_child(sound)

	var done_button := _add_action_button(stack, "DONE", true, Callable())
	done_button.custom_minimum_size = Vector2(0, 52 if compact else 62)
	_style_landing_command_button(done_button, true)
	_apply_shared_page_typography(done_button, 18 if compact else 21)
	done_button.pressed.connect(_close_settings_overlay.bind(shade, center))

func _style_settings_dropdown(selector: OptionButton) -> void:
	selector.focus_mode = Control.FOCUS_NONE
	var field := StyleBoxFlat.new()
	field.bg_color = Color("#202326")
	field.border_color = Color("#806239")
	field.set_border_width_all(1)
	field.set_corner_radius_all(14)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 12
	field.content_margin_bottom = 12
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		selector.add_theme_stylebox_override(state, field)
	selector.add_theme_color_override("font_color", Color("#EEE9DF"))
	selector.add_theme_color_override("font_hover_color", Color("#F2EDE4"))
	selector.add_theme_color_override("font_pressed_color", Color("#F2EDE4"))
	selector.add_theme_color_override("font_focus_color", Color("#F2EDE4"))
	var popup := selector.get_popup()
	popup.min_size = Vector2i(maxi(roundi(selector.custom_minimum_size.x), 280), 0)
	popup.add_theme_font_size_override("font_size", 19)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#1B1E20")
	panel.border_color = Color("#C58A3A")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", panel)
	var item_idle := StyleBoxFlat.new()
	item_idle.bg_color = Color("#1B1E20")
	item_idle.set_corner_radius_all(7)
	item_idle.content_margin_left = 14
	item_idle.content_margin_right = 14
	item_idle.content_margin_top = 12
	item_idle.content_margin_bottom = 12
	popup.add_theme_stylebox_override("hover", item_idle)
	popup.add_theme_stylebox_override("pressed", item_idle)
	popup.add_theme_stylebox_override("focus", item_idle)
	popup.add_theme_color_override("font_color", Color("#EEE9DF"))
	popup.add_theme_color_override("font_hover_color", Color("#F2EDE4"))
	popup.add_theme_color_override("font_pressed_color", Color("#F2EDE4"))
	popup.add_theme_color_override("font_focus_color", Color("#F2EDE4"))
	popup.add_theme_constant_override("v_separation", 10)
	popup.add_theme_constant_override("outline_size", 1)
	popup.add_theme_color_override("font_outline_color", Color("#101214"))

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
	button.add_theme_color_override("font_color", Color("#ffffff") if primary else Color("#E5E0D6"))
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
		style.bg_color = Color("#6F4B20") if primary else Color("#24282A")
		if state == "hover":
			style.bg_color = Color("#8B622A") if primary else Color("#303437")
		elif state == "pressed":
			style.bg_color = Color("#523817") if primary else Color("#191C1E")
		style.border_color = Color("#79613D") if primary else Color("#515355")
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.border_width_left = 1
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
		style.shadow_size = 10 if primary else 7
		style.shadow_offset = Vector2(0, 4)
		style.anti_aliasing = true
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#F2EDE4"))
	button.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_focus_color", Color("#FFFFFF"))
	_apply_shared_page_typography(button, 20)
	button.add_theme_color_override("font_outline_color", Color("#211A11"))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 2)

func _apply_menu_3d_label(label: Label, depth: int = 3) -> void:
	# Layered outline and offset shadow give every menu caption a consistent
	# raised, extruded finish while keeping the interface crisp on mobile.
	label.add_theme_color_override("font_outline_color", Color("#2D261C"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.025, 0.012, 0.92))
	label.add_theme_constant_override("shadow_offset_x", depth)
	label.add_theme_constant_override("shadow_offset_y", depth + 2)


func _style_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#93652C") if primary else Color("#292D2F")
		if state == "hover":
			style.bg_color = Color("#AA7837") if primary else Color("#373B3D")
		elif state == "pressed":
			style.bg_color = Color("#6D4A20") if primary else Color("#202325")
		style.border_color = Color("#85683F") if primary else Color("#515456")
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)

func _style_line_edit(field: LineEdit) -> void:
	field.add_theme_color_override("font_color", Color("#EEE9DF"))
	field.add_theme_color_override("font_placeholder_color", Color("#A9A297"))
	field.add_theme_color_override("caret_color", Color("#C58A3A"))
	field.add_theme_color_override("selection_color", Color(0.58, 0.39, 0.16, 0.42))
	for state in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1B1E20")
		style.border_color = Color("#4A4740") if state != "focus" else Color("#C58A3A")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
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
