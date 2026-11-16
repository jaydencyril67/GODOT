extends Node3D

signal back_requested
signal design_saved(design: Dictionary)

const ACCENT := Color("#C58A3A")
const DARK := Color("#101316")
const PANEL := Color("#191D20")
const TEXT := Color("#EEEAE2")
const MUTED := Color("#A9A49A")

var preview_viewport: SubViewport
var processor_root: Node3D
var preview_camera: Camera3D
var name_input: LineEdit
var package_size: OptionButton
var package_finish: OptionButton
var die_finish: OptionButton
var status_label: Label
var drag_active := false
var last_drag_position := Vector2.ZERO
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
	body.offset_top = 72
	body.offset_right = -18
	body.offset_bottom = -18
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	var left := PanelContainer.new()
	left.name = "Processor3DPreviewPanel"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	_style_panel(left)
	body.add_child(left)

	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 8)
	left.add_child(preview_column)

	var preview_heading := _label("SILICON PREVIEW", 12, ACCENT)
	preview_column.add_child(preview_heading)

	var preview_holder := SubViewportContainer.new()
	preview_holder.name = "ProcessorPreviewViewport"
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.stretch = true
	preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_holder.gui_input.connect(_on_preview_input)
	preview_column.add_child(preview_holder)

	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(900, 700)
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_holder.add_child(preview_viewport)

	var hint := _label("DRAG TO ROTATE  ·  3D CHIP MODEL", 10, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(hint)

	var right := PanelContainer.new()
	right.name = "ProcessorDesignControlsPanel"
	right.custom_minimum_size.x = 310
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.82
	_style_panel(right)
	body.add_child(right)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	right.add_child(controls)

	controls.add_child(_label("PROCESSOR CONFIGURATION", 15, TEXT))
	controls.add_child(_label("Define the physical package before developing its silicon.", 10, MUTED))

	controls.add_child(_label("PROCESSOR NAME", 10, ACCENT))
	name_input = LineEdit.new()
	name_input.text = str(processor_design.name)
	name_input.placeholder_text = "Enter processor name"
	name_input.custom_minimum_size.y = 42
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
	package_finish.item_selected.connect(_on_design_changed)
	controls.add_child(package_finish)

	controls.add_child(_label("SILICON DIE FINISH", 10, ACCENT))
	die_finish = OptionButton.new()
	for option in ["Dark silicon", "Polished silicon", "Metallic heat spreader"]:
		die_finish.add_item(option)
	_style_option(die_finish)
	die_finish.item_selected.connect(_on_design_changed)
	controls.add_child(die_finish)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	status_label = _label("DESIGN NOT YET SAVED", 10, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.add_child(status_label)

	var save := Button.new()
	save.text = "SAVE PROCESSOR DESIGN"
	save.custom_minimum_size.y = 46
	_style_button(save, true)
	save.pressed.connect(_save_design)
	controls.add_child(save)

	var research_note := _label("Research systems will be developed after the processor's base design is established.", 9, MUTED)
	research_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.add_child(research_note)

func _build_processor_preview() -> void:
	var world := World3D.new()
	preview_viewport.world_3d = world
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0B1015")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8D9AA6")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	preview_viewport.add_child(environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.2, 4.8)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.fov = 38
	preview_viewport.add_child(camera)
	preview_camera = camera

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42, -28, 0)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true
	preview_viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.0, 1.6)
	fill_light.light_energy = 1.0
	fill_light.omni_range = 8.0
	preview_viewport.add_child(fill_light)

	processor_root = Node3D.new()
	processor_root.name = "ProcessorSoCModel"
	preview_viewport.add_child(processor_root)
	_add_box(processor_root, Vector3(2.5, 0.22, 2.5), Vector3.ZERO, Color("#27343A"), 0.72, 0.28)
	_add_box(processor_root, Vector3(2.34, 0.07, 2.34), Vector3(0, 0.14, 0), Color("#344A45"), 0.58, 0.3)
	_add_box(processor_root, Vector3(1.22, 0.10, 1.22), Vector3(0, 0.225, 0), Color("#171D22"), 0.35, 0.22)
	_add_box(processor_root, Vector3(0.92, 0.018, 0.92), Vector3(0, 0.285, 0), Color("#303A40"), 0.25, 0.18)
	_add_contact_grid()
	_add_die_markings()

func _add_contact_grid() -> void:
	var gold := Color("#C7A56A")
	for i in range(14):
		var offset := -1.08 + float(i) * 0.166
		for side in [-1.0, 1.0]:
			_add_box(processor_root, Vector3(0.075, 0.025, 0.075), Vector3(offset, 0.115, side * 1.17), gold, 0.25, 0.72)
			_add_box(processor_root, Vector3(0.075, 0.025, 0.075), Vector3(side * 1.17, 0.115, offset), gold, 0.25, 0.72)

func _add_die_markings() -> void:
	for i in range(5):
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.66, 0.008, 0.012)
		line.mesh = mesh
		line.position = Vector3(0, 0.299, -0.28 + float(i) * 0.14)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#78858A")
		mat.metallic = 0.55
		mat.roughness = 0.35
		line.material_override = mat
		processor_root.add_child(line)

func _add_box(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color, metallic: float, roughness: float) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	part.material_override = material
	parent.add_child(part)

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		drag_active = event.pressed
		last_drag_position = event.position
	elif event is InputEventScreenDrag and drag_active:
		_rotate_preview(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_active = event.pressed
		last_drag_position = event.position
	elif event is InputEventMouseMotion and drag_active:
		_rotate_preview(event.relative)

func _rotate_preview(relative: Vector2) -> void:
	if not is_instance_valid(processor_root):
		return
	processor_root.rotation.y += relative.x * 0.009
	processor_root.rotation.x = clampf(processor_root.rotation.x + relative.y * 0.006, -0.55, 0.55)

func _on_design_changed(_value: Variant = null) -> void:
	_apply_design()
	status_label.text = "UNSAVED DESIGN CHANGES"

func _apply_design() -> void:
	if not is_instance_valid(processor_root):
		return
	var package_colors := {
		"Matte graphite": Color("#27343A"),
		"Deep green substrate": Color("#244B40"),
		"Ceramic black": Color("#17191D")
	}
	var die_colors := {
		"Dark silicon": Color("#171D22"),
		"Polished silicon": Color("#56616A"),
		"Metallic heat spreader": Color("#A2A8A8")
	}
	var package_material := StandardMaterial3D.new()
	package_material.albedo_color = package_colors.get(package_finish.get_item_text(package_finish.selected), Color("#27343A"))
	package_material.metallic = 0.72
	package_material.roughness = 0.28
	var die_material := StandardMaterial3D.new()
	die_material.albedo_color = die_colors.get(die_finish.get_item_text(die_finish.selected), Color("#171D22"))
	die_material.metallic = 0.45
	die_material.roughness = 0.22
	var package_base := processor_root.get_child(0) as MeshInstance3D
	var substrate := processor_root.get_child(1) as MeshInstance3D
	var die := processor_root.get_child(2) as MeshInstance3D
	var spreader := processor_root.get_child(3) as MeshInstance3D
	package_base.material_override = package_material
	substrate.material_override = package_material
	die.material_override = die_material
	spreader.material_override = die_material
	var dimension := package_size.get_item_text(package_size.selected)
	var scale_factor := 1.0
	match dimension:
		"10 × 10 mm": scale_factor = 0.84
		"14 × 14 mm": scale_factor = 1.14
		"16 × 16 mm": scale_factor = 1.28
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
