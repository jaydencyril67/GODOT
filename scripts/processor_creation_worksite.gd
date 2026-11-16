extends Node3D

signal back_requested
signal design_saved(design: Dictionary)

const ACCENT := Color("#C58A3A")
const DARK := Color("#101316")
const PANEL := Color("#191D20")
const TEXT := Color("#EEEAE2")
const MUTED := Color("#A9A49A")

const DEFAULT_VIEW_ROTATION := Vector3(-0.24, -0.42, 0.0)
const CHIP_BASE_SIZE := 2.30

var preview_viewport: SubViewport
var processor_root: Node3D
var preview_camera: Camera3D
var name_input: LineEdit
var package_size: OptionButton
var package_finish: OptionButton
var die_finish: OptionButton
var status_label: Label
var package_layers: Array[MeshInstance3D] = []
var die_surface: MeshInstance3D
var drag_active := false
var is_flipped := false
var processor_design := {
	"name": "DW Silicon 01",
	"package_size": "12 × 12 mm",
	"package_finish": "Matte graphite",
	"die_finish": "Dark silicon"
}

func _ready() -> void:
	_build_interface()
	_build_processor_preview()
	_apply_design()

func configure_design(design: Dictionary) -> void:
	if design.is_empty():
		return
	processor_design = design.duplicate(true)
	if is_instance_valid(name_input):
		name_input.text = str(processor_design.get("name", "DW Silicon 01"))
	if is_instance_valid(package_size):
		_select_option(package_size, str(processor_design.get("package_size", "12 × 12 mm")))
	if is_instance_valid(package_finish):
		_select_option(package_finish, str(processor_design.get("package_finish", "Matte graphite")))
	if is_instance_valid(die_finish):
		_select_option(die_finish, str(processor_design.get("die_finish", "Dark silicon")))
	_apply_design()
	if is_instance_valid(status_label):
		status_label.text = "SAVED PROCESSOR DESIGN LOADED"

func _select_option(option: OptionButton, value: String) -> void:
	for index in range(option.item_count):
		if option.get_item_text(index) == value:
			option.select(index)
			return

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProcessorWorksiteLayer"
	layer.layer = 45
	add_child(layer)

	var root := Control.new()
	root.name = "ProcessorWorksiteRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = DARK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 22
	top.offset_top = 12
	top.offset_right = -22
	top.offset_bottom = 58
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "‹  BACK"
	back.custom_minimum_size = Vector2(112, 42)
	_style_button(back, false)
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)

	var heading := Label.new()
	heading.text = "PROCESSOR DESIGN WORKSITE"
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", TEXT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(heading)

	var phase := Label.new()
	phase.text = "DESIGN PHASE 01"
	phase.add_theme_font_size_override("font_size", 11)
	phase.add_theme_color_override("font_color", ACCENT)
	phase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(phase)

	var body := HBoxContainer.new()
	body.anchor_left = 0.0
	body.anchor_top = 0.0
	body.anchor_right = 1.0
	body.anchor_bottom = 1.0
	body.offset_left = 18
	body.offset_top = 70
	body.offset_right = -18
	body.offset_bottom = -14
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var left := PanelContainer.new()
	left.name = "Processor3DPreviewPanel"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	_style_panel(left)
	body.add_child(left)

	var preview_column := VBoxContainer.new()
	preview_column.name = "ProcessorPreviewColumn"
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_theme_constant_override("separation", 7)
	left.add_child(preview_column)

	var preview_heading := _label("SILICON PREVIEW", 12, ACCENT)
	preview_column.add_child(preview_heading)

	var preview_holder := SubViewportContainer.new()
	preview_holder.name = "ProcessorPreviewViewport"
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.custom_minimum_size = Vector2(0, 245)
	preview_holder.stretch = true
	preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_holder.gui_input.connect(_on_preview_input)
	preview_column.add_child(preview_holder)

	preview_viewport = SubViewport.new()
	preview_viewport.name = "Processor3DSubViewport"
	preview_viewport.size = Vector2i(1000, 760)
	preview_viewport.own_world_3d = true
	preview_viewport.msaa_3d = Viewport.MSAA_4X
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_holder.add_child(preview_viewport)

	var view_actions := HBoxContainer.new()
	view_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	view_actions.add_theme_constant_override("separation", 10)
	preview_column.add_child(view_actions)

	var flip_button := Button.new()
	flip_button.text = "FLIP CHIP"
	flip_button.custom_minimum_size = Vector2(120, 36)
	_style_button(flip_button, false)
	flip_button.pressed.connect(_flip_chip)
	view_actions.add_child(flip_button)

	var reset_button := Button.new()
	reset_button.text = "RESET VIEW"
	reset_button.custom_minimum_size = Vector2(120, 36)
	_style_button(reset_button, false)
	reset_button.pressed.connect(_reset_view)
	view_actions.add_child(reset_button)

	var hint := _label("DRAG TO ROTATE  ·  VIEW TOP AND CONTACT SIDE", 9, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(hint)

	var right := PanelContainer.new()
	right.name = "ProcessorDesignControlsPanel"
	right.custom_minimum_size.x = 300
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.82
	_style_panel(right)
	body.add_child(right)

	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 10)
	right.add_child(controls)

	controls.add_child(_label("PROCESSOR CONFIGURATION", 15, TEXT))
	controls.add_child(_label("Establish the physical package and silicon identity.", 10, MUTED))

	controls.add_child(_label("PROCESSOR NAME", 10, ACCENT))
	name_input = LineEdit.new()
	name_input.text = str(processor_design.name)
	name_input.placeholder_text = "Enter processor name"
	name_input.custom_minimum_size.y = 40
	_style_input(name_input)
	name_input.text_changed.connect(_on_design_changed)
	controls.add_child(name_input)

	controls.add_child(_label("PACKAGE DIMENSIONS", 10, ACCENT))
	package_size = OptionButton.new()
	for option in ["10 × 10 mm", "12 × 12 mm", "14 × 14 mm", "16 × 16 mm"]:
		package_size.add_item(option)
	package_size.select(1)
	_style_option(package_size)
	package_size.item_selected.connect(_on_design_changed)
	controls.add_child(package_size)

	controls.add_child(_label("PACKAGE FINISH", 10, ACCENT))
	package_finish = OptionButton.new()
	for option in ["Matte graphite", "Deep green substrate", "Ceramic black"]:
		package_finish.add_item(option)
	_style_option(package_finish)
	controls.add_child(package_finish)
	package_finish.item_selected.connect(_on_design_changed)

	controls.add_child(_label("DIE FINISH", 10, ACCENT))
	die_finish = OptionButton.new()
	for option in ["Dark silicon", "Polished silicon", "Metallic silicon cap"]:
		die_finish.add_item(option)
	_style_option(die_finish)
	controls.add_child(die_finish)
	die_finish.item_selected.connect(_on_design_changed)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	status_label = _label("DESIGN NOT YET SAVED", 10, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.add_child(status_label)

	var save := Button.new()
	save.text = "SAVE PROCESSOR DESIGN"
	save.custom_minimum_size.y = 44
	_style_button(save, true)
	save.pressed.connect(_save_design)
	controls.add_child(save)

	var research_note := _label("The seven research systems will be added after the base processor design is established.", 9, MUTED)
	research_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.add_child(research_note)

func _build_processor_preview() -> void:
		var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0B1117")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9DABB7")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	preview_viewport.add_child(environment_node)

	var camera := Camera3D.new()
	camera.name = "ProcessorStudioCamera"
	camera.position = Vector3(0.0, 2.45, 6.0)
	camera.fov = 36.0
	camera.near = 0.05
	camera.far = 100.0
	preview_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.015, 0.0), Vector3.UP)
	preview_camera = camera

	var key_light := DirectionalLight3D.new()
	key_light.name = "LargeSoftKeyLight"
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key_light.light_color = Color("#FFF1D8")
	key_light.light_energy = 2.2
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 18.0
	preview_viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "CoolFillLight"
	fill_light.position = Vector3(-2.7, 2.0, 2.1)
	fill_light.light_color = Color("#A8C9E8")
	fill_light.light_energy = 1.45
	fill_light.omni_range = 9.0
	preview_viewport.add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.name = "WarmRimLight"
	rim_light.position = Vector3(2.4, 1.3, -2.3)
	rim_light.light_color = Color("#E5B875")
	rim_light.light_energy = 1.7
	rim_light.omni_range = 8.0
	preview_viewport.add_child(rim_light)

	var studio_floor := MeshInstance3D.new()
	studio_floor.name = "StudioFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 40.0)
	studio_floor.mesh = floor_mesh
	studio_floor.position = Vector3(0.0, -0.68, 0.0)
	studio_floor.material_override = _material(Color("#111A20"), 0.24, 0.34)
	preview_viewport.add_child(studio_floor)

	processor_root = Node3D.new()
	processor_root.name = "ProcessorSoCModel"
	processor_root.position = Vector3(0.0, 0.02, 0.0)
	processor_root.rotation = DEFAULT_VIEW_ROTATION
	preview_viewport.add_child(processor_root)

	_build_package_body()
	_build_top_die_and_passives()
	_build_bottom_contacts()

func _build_package_body() -> void:
	# The stepped package layers create the thin laminated edge visible on real SoC packages.
	var lower_edge := _add_box(processor_root, Vector3(2.30, 0.035, 2.30), Vector3(0.0, -0.075, 0.0), _material(Color("#11191B"), 0.36, 0.34), "PackageLowerEdge")
	var core := _add_box(processor_root, Vector3(2.26, 0.135, 2.26), Vector3(0.0, 0.005, 0.0), _material(Color("#1D302D"), 0.42, 0.38), "PackageSubstrate")
	var top_mask := _add_box(processor_root, Vector3(2.22, 0.022, 2.22), Vector3(0.0, 0.082, 0.0), _material(Color("#203B34"), 0.32, 0.34), "TopSolderMask")
	package_layers = [lower_edge, core, top_mask]

	# Very restrained edge strata and corner fiducials add scale without turning the chip into a fantasy prop.
	var copper := _material(Color("#B58B4C"), 0.82, 0.25)
	for side in [-1.0, 1.0]:
		for index in range(6):
			var along := -0.72 + float(index) * 0.288
			_add_box(processor_root, Vector3(0.10, 0.008, 0.014), Vector3(along, 0.096, side * 1.075), copper, "TopEdgeTrace")
			_add_box(processor_root, Vector3(0.014, 0.008, 0.10), Vector3(side * 1.075, 0.096, along), copper, "SideEdgeTrace")

func _build_top_die_and_passives() -> void:
	var frame_material := _material(Color("#6C604B"), 0.72, 0.28)
	_add_box(processor_root, Vector3(1.49, 0.025, 1.49), Vector3(0.0, 0.111, 0.0), frame_material, "DieBondFrame")
	_add_box(processor_root, Vector3(1.39, 0.045, 1.39), Vector3(0.0, 0.145, 0.0), _material(Color("#20272C"), 0.38, 0.30), "SiliconDie")
	die_surface = _add_box(processor_root, Vector3(1.32, 0.012, 1.32), Vector3(0.0, 0.173, 0.0), _material(Color("#171D22"), 0.32, 0.24), "SiliconDieSurface")

	var frame_gold := _material(Color("#C69A55"), 0.86, 0.22)
	for side in [-1.0, 1.0]:
		_add_box(processor_root, Vector3(1.44, 0.007, 0.012), Vector3(0.0, 0.126, side * 0.728), frame_gold, "DieFrameEdge")
		_add_box(processor_root, Vector3(0.012, 0.007, 1.44), Vector3(side * 0.728, 0.126, 0.0), frame_gold, "DieFrameEdge")

	# Fine, low-profile passives on the package rim.
	var ceramic := _material(Color("#B6B4A8"), 0.18, 0.30)
	var terminal := _material(Color("#B58C51"), 0.78, 0.23)
	for index in range(4):
		var along := -0.78 + float(index) * 0.52
		_add_smd_component(Vector3(along, 0.118, 0.91), ceramic, terminal)
		_add_smd_component(Vector3(along, 0.118, -0.91), ceramic, terminal)
		_add_smd_component(Vector3(0.91, 0.118, along), ceramic, terminal)
		_add_smd_component(Vector3(-0.91, 0.118, along), ceramic, terminal)

	_add_top_marking("DW", 46, Vector3(0.0, 0.181, -0.12), Color("#C7C9C5"), 0.0042)
	_add_top_marking("SILICON 01", 19, Vector3(0.0, 0.181, 0.20), Color("#AAB1B4"), 0.0032)
	_add_top_marking("MOBILE COMPUTE  ·  REV A", 9, Vector3(0.0, 0.181, 0.36), Color("#78858A"), 0.0023)

func _add_smd_component(at: Vector3, body_material: StandardMaterial3D, terminal_material: StandardMaterial3D) -> void:
	_add_box(processor_root, Vector3(0.14, 0.035, 0.075), at, body_material, "SurfaceMountPassive")
	for side in [-1.0, 1.0]:
		_add_box(processor_root, Vector3(0.018, 0.039, 0.078), at + Vector3(side * 0.068, 0.0, 0.0), terminal_material, "PassiveMetalEnd")

func _add_top_marking(value: String, font_size_value: int, at: Vector3, color: Color, pixel_size_value: float) -> void:
	var marking := Label3D.new()
	marking.name = "LaserEtchedMarking_Logo" if value == "DW" else ("LaserEtchedMarking_Product" if value == "SILICON 01" else "LaserEtchedMarking_Revision")
	marking.text = value
	marking.font_size = font_size_value
	marking.pixel_size = pixel_size_value
	marking.modulate = color
	marking.shaded = true
	marking.no_depth_test = false
	marking.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marking.position = at
	processor_root.add_child(marking)

func _build_bottom_contacts() -> void:
	# Real phone SoCs use a ball-grid package: hundreds of tiny contacts on the underside.
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.034
	ball_mesh.height = 0.068
	ball_mesh.radial_segments = 10
	ball_mesh.rings = 6
	var contacts := MultiMesh.new()
	contacts.transform_format = MultiMesh.TRANSFORM_3D
	contacts.mesh = ball_mesh
	const GRID_COUNT := 15
	contacts.instance_count = GRID_COUNT * GRID_COUNT
	var instance_index := 0
	for row in range(GRID_COUNT):
		for column in range(GRID_COUNT):
			var x := (float(column) - float(GRID_COUNT - 1) * 0.5) * 0.142
			var z := (float(row) - float(GRID_COUNT - 1) * 0.5) * 0.142
			contacts.set_instance_transform(instance_index, Transform3D(Basis.IDENTITY, Vector3(x, -0.126, z)))
			instance_index += 1
	var contact_array := MultiMeshInstance3D.new()
	contact_array.name = "UndersideBGAContactArray"
	contact_array.multimesh = contacts
	contact_array.material_override = _material(Color("#D3A957"), 0.91, 0.20)
	processor_root.add_child(contact_array)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		drag_active = event.pressed
	elif event is InputEventScreenDrag and drag_active:
		_rotate_preview(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_active = event.pressed
	elif event is InputEventMouseMotion and drag_active:
		_rotate_preview(event.relative)

func _rotate_preview(relative: Vector2) -> void:
	if not is_instance_valid(processor_root):
		return
	processor_root.rotation.y += relative.x * 0.008
	processor_root.rotation.x = clampf(processor_root.rotation.x + relative.y * 0.006, -0.65, 3.80)

func _flip_chip() -> void:
	if not is_instance_valid(processor_root):
		return
	is_flipped = not is_flipped
	processor_root.rotation.x = PI - 0.24 if is_flipped else DEFAULT_VIEW_ROTATION.x

func _reset_view() -> void:
	if not is_instance_valid(processor_root):
		return
	is_flipped = false
	processor_root.rotation = DEFAULT_VIEW_ROTATION

func _on_design_changed(_value: Variant = null) -> void:
	_apply_design()
	status_label.text = "UNSAVED DESIGN CHANGES"

func _apply_design() -> void:
	if not is_instance_valid(processor_root) or not is_instance_valid(package_size):
		return
	var package_colors := {
		"Matte graphite": Color("#222C31"),
		"Deep green substrate": Color("#183B32"),
		"Ceramic black": Color("#15191E")
	}
	var die_colors := {
		"Dark silicon": Color("#171D22"),
		"Polished silicon": Color("#454F57"),
		"Metallic silicon cap": Color("#91999D")
	}
	var selected_package := package_finish.get_item_text(package_finish.selected)
	var selected_die := die_finish.get_item_text(die_finish.selected)
	var package_color: Color = package_colors.get(selected_package, Color("#222C31"))
	for layer in package_layers:
		if is_instance_valid(layer):
			var layer_material := _material(package_color, 0.42, 0.34)
			layer_material.albedo_color = package_color.darkened(0.12) if layer.name == "PackageLowerEdge" else package_color
			layer.material_override = layer_material
	if is_instance_valid(die_surface):
		die_surface.material_override = _material(die_colors.get(selected_die, Color("#171D22")), 0.32, 0.25)
	var scale_factor := 1.0
	match package_size.get_item_text(package_size.selected):
		"10 × 10 mm":
			scale_factor = 0.84
		"14 × 14 mm":
			scale_factor = 1.14
		"16 × 16 mm":
			scale_factor = 1.28
	processor_root.scale = Vector3.ONE * scale_factor

func _save_design() -> void:
	processor_design = {
		"name": name_input.text.strip_edges() if not name_input.text.strip_edges().is_empty() else "DW Silicon 01",
		"package_size": package_size.get_item_text(package_size.selected),
		"package_finish": package_finish.get_item_text(package_finish.selected),
		"die_finish": die_finish.get_item_text(die_finish.selected)
	}
	design_saved.emit(processor_design.duplicate(true))
	status_label.text = "PROCESSOR DESIGN SAVED"

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color("#343A3D")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#674B2A") if primary else Color("#252B2F")
	style.border_color = ACCENT if primary else Color("#596166")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("#795A34") if primary else Color("#333B40")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", TEXT)

func _style_input(input: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0E1215")
	style.border_color = Color("#41484D")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	input.add_theme_stylebox_override("normal", style)
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", MUTED)

func _style_option(option: OptionButton) -> void:
	option.custom_minimum_size.y = 40
	option.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0E1215")
	style.border_color = Color("#41484D")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	option.add_theme_stylebox_override("normal", style)
	option.add_theme_color_override("font_color", TEXT)
