extends Control

signal back_requested
signal fence_upgrade_requested(level: int, cost: int)

const TEXT_MAIN := Color("#EEE9DF")
const TEXT_MUTED := Color("#AAA49A")
const ACCENT := Color("#C58A3A")
const ACCENT_SOFT := Color("#D2A15C")
const CARD_BACKGROUND := Color("#142019")
const CARD_BORDER := Color("#80663F")

const FENCE_DESIGNS := [
	{
		"id": "wooden",
		"level": "LEVEL 01",
		"name": "Wooden Fence",
		"descriptor": "TREATED TIMBER",
		"description": "Treated timber posts and closely spaced vertical boards form the basic perimeter boundary."
	},
	{
		"id": "concrete_block",
		"level": "LEVEL 02",
		"name": "Concrete Block Wall",
		"descriptor": "SOLID MASONRY",
		"upgrade_cost": 2000000,
		"description": "Layered concrete masonry with reinforced piers, a solid base and a protective top cap."
	},
	{
		"id": "modern_steel",
		"level": "LEVEL 03",
		"name": "Modern Steel Security Fence",
		"descriptor": "POWDER-COATED STEEL",
		"upgrade_cost": 3500000,
		"description": "Heavy steel posts, horizontal rails and evenly spaced vertical security bars."
	},
	{
		"id": "premium_architectural",
		"level": "LEVEL 04",
		"name": "Premium Architectural Security Fence",
		"descriptor": "ARCHITECTURAL SECURITY",
		"upgrade_cost": 5000000,
		"description": "A premium perimeter design combining architectural piers, glazed panels and precision-finished metal details."
	}
]

var frame_container: MarginContainer
var page_root: VBoxContainer
var page_title: Label
var page_kicker: Label
var content_body: VBoxContainer
var back_button: Button
var catalogue_grid: GridContainer
var current_page := "projects"
var current_fence_level := 1
var pending_fence_upgrade: Dictionary = {}
var available_balance := 0.0


func configure_fence_upgrade_state(installed_level: int, pending_upgrade: Dictionary, balance: float) -> void:
	current_fence_level = clampi(installed_level, 1, 4)
	pending_fence_upgrade = pending_upgrade.duplicate(true)
	available_balance = maxf(balance, 0.0)
	set_meta("current_fence_level", current_fence_level)
	set_meta("pending_fence_upgrade", pending_fence_upgrade.duplicate(true))
	set_meta("available_balance", available_balance)
	if current_page == "fencing" and is_instance_valid(content_body):
		_show_fencing_catalogue()


func _ready() -> void:
	set_meta("project_dashboard_version", "stage_one_fencing_catalogue")
	set_meta("fence_catalogue_count", FENCE_DESIGNS.size())
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	_show_category_page()
	resized.connect(_on_dashboard_resized)


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "ProjectDevelopmentBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#111315")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.name = "ProjectDevelopmentAtmosphere"
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.075, 0.065, 0.052, 0.22)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	frame_container = MarginContainer.new()
	frame_container.name = "ProjectDevelopmentFrame"
	frame_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame_container)

	page_root = VBoxContainer.new()
	page_root.name = "ProjectDevelopmentPage"
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", 12)
	frame_container.add_child(page_root)

	var top_bar := HBoxContainer.new()
	top_bar.name = "ProjectDevelopmentTopBar"
	top_bar.custom_minimum_size.y = 48.0
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_theme_constant_override("separation", 14)
	page_root.add_child(top_bar)

	back_button = _make_button("‹  BACK", false)
	back_button.name = "ProjectBackButton"
	back_button.custom_minimum_size = Vector2(112.0, 42.0)
	back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(back_button)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 1)
	top_bar.add_child(title_stack)

	page_kicker = _label("CAMPUS DEVELOPMENT", 9, ACCENT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	page_kicker.name = "ProjectPageKicker"
	title_stack.add_child(page_kicker)

	page_title = _label("PROJECTS", 20, TEXT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	page_title.name = "ProjectPageTitle"
	page_title.add_theme_font_size_override("font_size", 20)
	title_stack.add_child(page_title)

	var status_stack := VBoxContainer.new()
	status_stack.custom_minimum_size.x = 150.0
	status_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	status_stack.add_theme_constant_override("separation", 2)
	top_bar.add_child(status_stack)
	status_stack.add_child(_label("PROJECT OFFICE", 9, TEXT_MAIN, HORIZONTAL_ALIGNMENT_RIGHT))
	status_stack.add_child(_label("CAMPUS INFRASTRUCTURE", 7, TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT))

	var divider := ColorRect.new()
	divider.name = "ProjectHeaderDivider"
	divider.custom_minimum_size.y = 1.0
	divider.color = Color(0.58, 0.46, 0.29, 0.48)
	page_root.add_child(divider)

	content_body = VBoxContainer.new()
	content_body.name = "ProjectContentBody"
	content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_body.add_theme_constant_override("separation", 10)
	page_root.add_child(content_body)

	_apply_shell_layout()


func _on_dashboard_resized() -> void:
	_apply_shell_layout()


func _apply_shell_layout() -> void:
	if not is_instance_valid(frame_container):
		return
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 820.0 or viewport_size.y < 560.0
	var horizontal_margin := 14 if compact else 34
	var vertical_margin := 10 if compact else 22
	frame_container.add_theme_constant_override("margin_left", horizontal_margin)
	frame_container.add_theme_constant_override("margin_right", horizontal_margin)
	frame_container.add_theme_constant_override("margin_top", vertical_margin)
	frame_container.add_theme_constant_override("margin_bottom", vertical_margin)
	if is_instance_valid(catalogue_grid):
		# The four approved fence options always share one landscape row.
		catalogue_grid.columns = FENCE_DESIGNS.size()


func _show_category_page() -> void:
	current_page = "projects"
	set_meta("active_page", current_page)
	page_kicker.text = "CAMPUS DEVELOPMENT"
	page_title.text = "PROJECTS"
	_clear_content()

	var intro := VBoxContainer.new()
	intro.add_theme_constant_override("separation", 3)
	content_body.add_child(intro)
	intro.add_child(_label("AVAILABLE PROJECTS", 11, ACCENT_SOFT))
	var intro_description := _label("Choose an area of the campus to develop.", 12, TEXT_MUTED)
	intro_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(intro_description)

	var category_card := PanelContainer.new()
	category_card.name = "ProjectCategory_Fencing"
	category_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_card.add_theme_stylebox_override("panel", _make_panel_style())
	content_body.add_child(category_card)

	var card_layout: BoxContainer
	if _is_portrait():
		card_layout = VBoxContainer.new()
	else:
		card_layout = HBoxContainer.new()
	card_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_layout.add_theme_constant_override("separation", 18)
	category_card.add_child(card_layout)

	var category_preview := _create_fence_preview("wooden")
	category_preview.name = "FencingCategory3DPreview"
	category_preview.custom_minimum_size = Vector2(320.0, 210.0)
	category_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_layout.add_child(category_preview)

	var category_info := VBoxContainer.new()
	category_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_info.alignment = BoxContainer.ALIGNMENT_CENTER
	category_info.add_theme_constant_override("separation", 8)
	card_layout.add_child(category_info)

	category_info.add_child(_label("01  /  CAMPUS PERIMETER", 9, ACCENT_SOFT))
	var category_title := _label("FENCING", 26, TEXT_MAIN)
	category_title.add_theme_font_size_override("font_size", 26)
	category_info.add_child(category_title)
	category_info.add_child(_label("BOUNDARY SYSTEMS", 10, ACCENT_SOFT))
	var category_description := _label(
		"Explore the available fence designs for your company campus. Each of the eight campus sections will be managed independently when construction becomes available.",
		13,
		TEXT_MUTED
	)
	category_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	category_info.add_child(category_description)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_info.add_child(spacer)

	category_info.add_child(_label("04 FENCE DESIGNS AVAILABLE", 10, TEXT_MAIN))

	var open_button := _make_button("VIEW FENCE DESIGNS  ›", true)
	open_button.name = "OpenFencingCatalogueButton"
	open_button.custom_minimum_size = Vector2(0.0, 46.0)
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.pressed.connect(_show_fencing_catalogue)
	category_info.add_child(open_button)

	var footer := _label("01 PROJECT CATEGORY AVAILABLE", 8, TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	content_body.add_child(footer)


func _show_fencing_catalogue() -> void:
	current_page = "fencing"
	set_meta("active_page", current_page)
	page_kicker.text = "PERIMETER INFRASTRUCTURE  /  04 DESIGNS"
	page_title.text = "FENCING SYSTEMS"
	_clear_content()

	var intro := HBoxContainer.new()
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_theme_constant_override("separation", 10)
	content_body.add_child(intro)
	var intro_stack := VBoxContainer.new()
	intro_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_stack.add_theme_constant_override("separation", 2)
	intro.add_child(intro_stack)
	intro_stack.add_child(_label("FENCE DESIGN CATALOGUE", 11, ACCENT_SOFT))
	var subtitle := _label("Inspect the designs, then select the next fence level to commission its construction.", 11, TEXT_MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_stack.add_child(subtitle)
	var balance_label := _label("AVAILABLE BALANCE  " + _format_upgrade_cost(int(available_balance)), 10, TEXT_MAIN)
	balance_label.name = "FenceUpgradeAvailableBalance"
	intro_stack.add_child(balance_label)
	var design_count := _label("04 OPTIONS", 10, TEXT_MAIN, HORIZONTAL_ALIGNMENT_RIGHT)
	design_count.custom_minimum_size.x = 90.0
	intro.add_child(design_count)

	# Four compact cards sit directly in one horizontal row. There is no
	# ScrollContainer: the catalogue must remain fully visible on the phone.
	catalogue_grid = GridContainer.new()
	catalogue_grid.name = "FenceCatalogueGrid"
	catalogue_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalogue_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalogue_grid.columns = FENCE_DESIGNS.size()
	catalogue_grid.add_theme_constant_override("h_separation", 10)
	catalogue_grid.add_theme_constant_override("v_separation", 0)
	catalogue_grid.set_meta("single_horizontal_row", true)
	content_body.add_child(catalogue_grid)

	for design_value in FENCE_DESIGNS:
		var design: Dictionary = design_value
		_add_fence_design_card(design)


func _add_fence_design_card(design: Dictionary) -> void:
	var design_id := str(design.get("id", ""))
	var viewport_size := get_viewport_rect().size
	var compact_catalogue := viewport_size.x < 1100.0 or viewport_size.y < 600.0
	var preview_height := clampf(viewport_size.y * 0.27, 88.0, 118.0)
	var card := PanelContainer.new()
	card.name = "FenceCard_" + design_id
	# No fixed 300 px width: GridContainer divides the available landscape
	# width evenly between all four cards.
	card.custom_minimum_size = Vector2.ZERO
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card_style := _make_panel_style()
	card_style.content_margin_left = 9.0
	card_style.content_margin_right = 9.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", card_style)
	catalogue_grid.add_child(card)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)

	var top_line := HBoxContainer.new()
	top_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(top_line)
	var level_label := _label(str(design.get("level", "")), 8, ACCENT_SOFT)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_line.add_child(level_label)
	top_line.add_child(_label("3D", 7, TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT))

	var preview := _create_fence_preview(design_id)
	preview.name = "Fence3DPreview_" + design_id
	preview.custom_minimum_size = Vector2(0.0, preview_height)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(preview)

	var title_font_size := 12 if compact_catalogue else 14
	var title := _label(str(design.get("name", "")), title_font_size, TEXT_MAIN)
	title.add_theme_font_size_override("font_size", title_font_size)
	title.name = "FenceTitle_" + design_id
	content.add_child(title)
	content.add_child(_label(str(design.get("descriptor", "")), 8, ACCENT_SOFT))

	var description_font_size := 8 if compact_catalogue else 9
	var description := _label(str(design.get("description", "")), description_font_size, TEXT_MUTED)
	description.name = "FenceDescription_" + design_id
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	var level_number := int(str(design.get("level", "LEVEL 01")).get_slice(" ", 1))
	var upgrade_cost := int(design.get("upgrade_cost", 0))
	var cost_text := "CURRENTLY INSTALLED" if level_number == current_fence_level else "FULL UPGRADE COST  " + _format_upgrade_cost(upgrade_cost)
	if not pending_fence_upgrade.is_empty() and int(pending_fence_upgrade.get("level", 0)) == level_number:
		cost_text = "PAYMENT RECORDED  " + _format_upgrade_cost(upgrade_cost)
	var cost_label := _label(cost_text, 8, ACCENT_SOFT)
	cost_label.name = "FenceUpgradeCost_" + design_id
	content.add_child(cost_label)

	var button_text := "CURRENT FENCE"
	var button_enabled := false
	if level_number < current_fence_level:
		button_text = "PREVIOUS TIER"
	elif level_number > current_fence_level and not pending_fence_upgrade.is_empty():
		button_text = "UPGRADE PENDING"
		if int(pending_fence_upgrade.get("level", 0)) == level_number:
			button_text = "PAID · AWAITING BUILD"
	elif level_number == current_fence_level + 1:
		button_text = "SELECT UPGRADE"
		button_enabled = true
	else:
		button_text = "LOCKED · UPGRADE PREVIOUS TIER"

	var upgrade_button := _make_button(button_text, button_enabled)
	upgrade_button.name = "SelectFenceUpgradeButton_%02d" % level_number
	upgrade_button.custom_minimum_size = Vector2(0.0, 34.0)
	upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_button.disabled = not button_enabled
	upgrade_button.add_theme_font_size_override("font_size", 10)
	if button_enabled:
		upgrade_button.pressed.connect(_emit_fence_upgrade_request.bind(level_number, upgrade_cost))
	content.add_child(upgrade_button)

	card.set_meta("fence_design_id", design_id)
	card.set_meta("preview_is_3d", true)
	card.set_meta("single_row_card", true)
	card.set_meta("upgrade_level", level_number)
	card.set_meta("upgrade_cost", upgrade_cost)
	card.set_meta("upgrade_selectable", button_enabled)


func _create_fence_preview(design_id: String) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_meta("fence_design_id", design_id)
	container.set_meta("actual_3d_preview", true)

	var viewport := SubViewport.new()
	viewport.name = "FencePreviewViewport_" + design_id
	viewport.size = Vector2i(480, 220)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1B2823")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#D8D0BE")
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.name = "FencePreviewKeyLight"
	key_light.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	key_light.light_color = Color("#FFF0D9")
	key_light.light_energy = 1.15
	key_light.shadow_enabled = false
	viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "FencePreviewFillLight"
	fill_light.position = Vector3(-2.8, 2.1, 3.0)
	fill_light.light_color = Color("#B8D4D5")
	fill_light.light_energy = 0.42
	fill_light.omni_range = 8.0
	fill_light.shadow_enabled = false
	viewport.add_child(fill_light)

	var model_root := Node3D.new()
	model_root.name = "FencePreviewModel_" + design_id
	model_root.set_meta("fence_design_id", design_id)
	viewport.add_child(model_root)

	_add_preview_ground(model_root)
	match design_id:
		"wooden":
			_build_wooden_fence_preview(model_root)
		"concrete_block":
			_build_concrete_block_fence_preview(model_root)
		"modern_steel":
			_build_modern_steel_fence_preview(model_root)
		"premium_architectural":
			_build_premium_fence_preview(model_root)
		_:
			_build_wooden_fence_preview(model_root)

	var camera := Camera3D.new()
	camera.name = "FencePreviewCamera"
	camera.position = Vector3(4.4, 2.7, 6.0)
	camera.fov = 40.0
	camera.near = 0.05
	camera.far = 80.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.82, 0.0), Vector3.UP)
	camera.current = true
	viewport.add_child(camera)

	viewport.set_meta("fence_design_id", design_id)
	return container


func _add_preview_ground(parent: Node3D) -> void:
	var ground := MeshInstance3D.new()
	ground.name = "PreviewGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6.0, 3.8)
	ground.mesh = mesh
	ground.position = Vector3(0.0, -0.055, 0.0)
	ground.material_override = _preview_material(Color("#304237"), 0.96)
	parent.add_child(ground)

	var concrete_strip := MeshInstance3D.new()
	concrete_strip.name = "FenceDisplayFoundation"
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(4.55, 0.10, 0.48)
	concrete_strip.mesh = strip_mesh
	concrete_strip.position = Vector3(0.0, 0.0, 0.0)
	concrete_strip.material_override = _preview_material(Color("#77766D"), 0.88)
	parent.add_child(concrete_strip)


func _build_wooden_fence_preview(parent: Node3D) -> void:
	var post_material := _preview_material(Color("#69472F"), 0.92)
	var rail_material := _preview_material(Color("#96683F"), 0.9)
	var board_material := _preview_material(Color("#B4814E"), 0.88)
	var dark_board_material := _preview_material(Color("#986A40"), 0.9)

	for post_index in range(3):
		var x := -2.0 + float(post_index) * 2.0
		_add_preview_box(parent, "WoodPost_%02d" % post_index, Vector3(0.17, 1.62, 0.17), Vector3(x, 0.82, 0.0), post_material)

	for rail_index in range(3):
		var y := 0.38 + float(rail_index) * 0.48
		_add_preview_box(parent, "WoodRail_%02d" % rail_index, Vector3(4.05, 0.11, 0.13), Vector3(0.0, y, 0.0), rail_material)

	for board_index in range(21):
		var x := -1.92 + float(board_index) * 0.192
		var board_surface := board_material if board_index % 3 != 1 else dark_board_material
		_add_preview_box(parent, "WoodBoard_%02d" % board_index, Vector3(0.105, 1.16, 0.075), Vector3(x, 0.86, 0.105), board_surface)


func _build_concrete_block_fence_preview(parent: Node3D) -> void:
	var block_material := _preview_material(Color("#A5A49B"), 0.94)
	var alternate_block_material := _preview_material(Color("#8D8F8A"), 0.96)
	var pier_material := _preview_material(Color("#777A75"), 0.9)
	var cap_material := _preview_material(Color("#B8B7AE"), 0.82)

	_add_preview_box(parent, "MasonryWallBase", Vector3(4.28, 0.18, 0.38), Vector3(0.0, 0.13, 0.0), pier_material)
	for course in range(6):
		var block_width := 0.55
		var gap := 0.025
		var total_width := 7.0 * block_width + 6.0 * gap
		for block_index in range(7):
			var offset := 0.0
			if course % 2 == 1:
				offset = 0.27
			var x := -total_width * 0.5 + block_width * 0.5 + float(block_index) * (block_width + gap) + offset
			if x > 1.92:
				continue
			var block_surface := block_material if (block_index + course) % 2 == 0 else alternate_block_material
			_add_preview_box(
				parent,
				"MasonryBlock_%02d_%02d" % [course, block_index],
				Vector3(block_width, 0.245, 0.32),
				Vector3(x, 0.34 + float(course) * 0.25, 0.0),
				block_surface
			)

	for pier_index in range(3):
		var x := -2.0 + float(pier_index) * 2.0
		_add_preview_box(parent, "MasonryPier_%02d" % pier_index, Vector3(0.29, 1.62, 0.40), Vector3(x, 0.92, 0.0), pier_material)

	_add_preview_box(parent, "MasonryTopCap", Vector3(4.35, 0.12, 0.44), Vector3(0.0, 1.77, 0.0), cap_material)


func _build_modern_steel_fence_preview(parent: Node3D) -> void:
	var steel_material := _preview_material(Color("#3E484C"), 0.34, 0.78)
	var rail_material := _preview_material(Color("#68767A"), 0.28, 0.72)
	var concrete_material := _preview_material(Color("#777970"), 0.92)

	for post_index in range(3):
		var x := -2.0 + float(post_index) * 2.0
		_add_preview_box(parent, "SteelPostFooting_%02d" % post_index, Vector3(0.34, 0.18, 0.34), Vector3(x, 0.12, 0.0), concrete_material)
		_add_preview_box(parent, "SteelPost_%02d" % post_index, Vector3(0.13, 1.65, 0.13), Vector3(x, 0.94, 0.0), steel_material)

	_add_preview_box(parent, "SteelTopRail", Vector3(4.15, 0.11, 0.14), Vector3(0.0, 1.67, 0.0), rail_material)
	_add_preview_box(parent, "SteelBottomRail", Vector3(4.15, 0.10, 0.14), Vector3(0.0, 0.34, 0.0), rail_material)

	for bar_index in range(25):
		var x := -1.91 + float(bar_index) * 0.159
		_add_preview_box(parent, "SteelSecurityBar_%02d" % bar_index, Vector3(0.052, 1.27, 0.075), Vector3(x, 1.0, 0.0), steel_material)


func _build_premium_fence_preview(parent: Node3D) -> void:
	var plinth_material := _preview_material(Color("#555C5A"), 0.7, 0.24)
	var frame_material := _preview_material(Color("#A7A99F"), 0.24, 0.82)
	var glass_material := _preview_material(Color(0.25, 0.46, 0.48, 0.48), 0.16, 0.45)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var slat_material := _preview_material(Color("#303A3C"), 0.3, 0.8)
	var accent_material := _preview_material(Color("#D2A15C"), 0.24, 0.68)

	_add_preview_box(parent, "ArchitecturalStonePlinth", Vector3(4.42, 0.48, 0.44), Vector3(0.0, 0.28, 0.0), plinth_material)
	for pier_index in range(4):
		var x := -2.1 + float(pier_index) * 1.4
		_add_preview_box(parent, "ArchitecturalPier_%02d" % pier_index, Vector3(0.14, 1.52, 0.20), Vector3(x, 1.24, 0.0), frame_material)

	for panel_index in range(3):
		var x := -1.4 + float(panel_index) * 1.4
		_add_preview_box(parent, "ArchitecturalGlassPanel_%02d" % panel_index, Vector3(1.22, 1.04, 0.055), Vector3(x, 1.20, 0.0), glass_material)
		for slat_index in range(5):
			var slat_x := x - 0.48 + float(slat_index) * 0.24
			_add_preview_box(parent, "ArchitecturalMetalSlat_%02d_%02d" % [panel_index, slat_index], Vector3(0.035, 1.02, 0.11), Vector3(slat_x, 1.20, 0.085), slat_material)

	_add_preview_box(parent, "ArchitecturalTopBeam", Vector3(4.38, 0.12, 0.22), Vector3(0.0, 2.02, 0.0), frame_material)
	_add_preview_box(parent, "ArchitecturalAccentLine", Vector3(4.24, 0.025, 0.235), Vector3(0.0, 1.94, 0.0), accent_material)


func _add_preview_box(
	parent: Node3D,
	node_name: String,
	box_size: Vector3,
	box_position: Vector3,
	surface_material: StandardMaterial3D
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = box_position
	instance.material_override = surface_material
	parent.add_child(instance)
	return instance


func _preview_material(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var new_material := StandardMaterial3D.new()
	new_material.albedo_color = color
	new_material.roughness = roughness
	new_material.metallic = metallic
	return new_material


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACKGROUND
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.0, 0.018, 0.012, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	style.anti_aliasing = true
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _emit_fence_upgrade_request(level: int, cost: int) -> void:
	fence_upgrade_requested.emit(level, cost)


func _format_upgrade_cost(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits.substr(index, 1)
	return "$" + formatted


func _make_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#805821") if primary else Color("#202326")
	normal.border_color = ACCENT
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#956A2E") if primary else Color("#2A2E30")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _label(value: String, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment as HorizontalAlignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _clear_content() -> void:
	catalogue_grid = null
	for child in content_body.get_children():
		content_body.remove_child(child)
		child.queue_free()


func _is_portrait() -> bool:
	var viewport_size := get_viewport_rect().size
	return viewport_size.x < viewport_size.y * 1.25


func _on_back_pressed() -> void:
	if current_page == "fencing":
		_show_category_page()
	else:
		back_requested.emit()
