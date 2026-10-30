extends Node3D

signal back_requested

const PHONE_SIZE := Vector3(1.28, 2.58, 0.18)
const ROTATION_STEP := deg_to_rad(15.0)
const DRAG_SENSITIVITY := 0.009

var phone_body: MeshInstance3D
var preview_camera: Camera3D
var preview_container: SubViewportContainer


func _ready() -> void:
	_build_preview_world()
	_build_editor_ui()


func _build_preview_world() -> void:
	var viewport := SubViewport.new()
	viewport.name = "PhonePreviewViewport"
	viewport.size = Vector2i(1200, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0a2942")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c7e8ff")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var preview_world := Node3D.new()
	preview_world.name = "PhonePreviewWorld"
	viewport.add_child(preview_world)

	phone_body = MeshInstance3D.new()
	phone_body.name = "Plain_Phone_Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = PHONE_SIZE
	phone_body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#a9c8dc")
	body_material.metallic = 0.28
	body_material.roughness = 0.32
	phone_body.material_override = body_material
	preview_world.add_child(phone_body)

	var key_light := DirectionalLight3D.new()
	key_light.name = "Soft_Key_Light"
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	preview_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "Soft_Fill_Light"
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#83cfff")
	fill_light.light_energy = 0.7
	fill_light.omni_range = 8.0
	preview_world.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.name = "PhonePreviewCamera"
	preview_camera.position = Vector3(0.0, 0.0, 5.2)
	preview_camera.current = true
	preview_camera.fov = 38.0
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	preview_world.add_child(preview_camera)


func _build_editor_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PhoneEditorInterface"
	add_child(layer)

	var root := Control.new()
	root.name = "PhoneEditorRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#071c30")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var preview_backdrop := ColorRect.new()
	preview_backdrop.anchor_right = 0.64
	preview_backdrop.anchor_bottom = 1.0
	preview_backdrop.offset_top = 78.0
	preview_backdrop.color = Color("#0a2942")
	preview_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview_backdrop)

	preview_container = SubViewportContainer.new()
	preview_container.name = "RotatablePhonePreview"
	preview_container.anchor_right = 0.64
	preview_container.anchor_bottom = 1.0
	preview_container.offset_left = 12.0
	preview_container.offset_top = 78.0
	preview_container.offset_right = -8.0
	preview_container.offset_bottom = -12.0
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_container.gui_input.connect(_on_preview_gui_input)
	var viewport := _get_preview_viewport()
	preview_container.add_child(viewport)
	root.add_child(preview_container)

	var header := HBoxContainer.new()
	header.name = "PhoneEditorHeader"
	header.anchor_right = 1.0
	header.offset_left = 22.0
	header.offset_top = 12.0
	header.offset_right = -20.0
	header.offset_bottom = 66.0
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 1)
	header.add_child(title_stack)
	title_stack.add_child(_make_label("DIGITALWORLD  /  PRODUCT STUDIO", 10, Color("#9edfff")))
	title_stack.add_child(_make_label("PHONE EDITOR", 23, Color.WHITE))

	var back_button := _make_button("BACK", 112.0, 42.0)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var tools_panel := PanelContainer.new()
	tools_panel.name = "PhoneEditorToolsPanel"
	tools_panel.anchor_left = 0.65
	tools_panel.anchor_top = 0.105
	tools_panel.anchor_right = 1.0
	tools_panel.anchor_bottom = 1.0
	tools_panel.offset_right = -14.0
	tools_panel.offset_bottom = -14.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.36, 0.54, 0.42)
	panel_style.border_color = Color(0.73, 0.91, 1.0, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	tools_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(tools_panel)

	var tools_content := VBoxContainer.new()
	tools_content.add_theme_constant_override("separation", 10)
	tools_panel.add_child(tools_content)
	tools_content.add_child(_make_label("EDITOR CONTROLS", 14, Color.WHITE))
	var instruction := _make_label("Drag the plain 3D body to turn it freely. Use the blocks below for precise rotation.", 11, Color("#c5e6f7"))
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_content.add_child(instruction)

	var grid := GridContainer.new()
	grid.name = "PhoneEditorButtonGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 8)
	tools_content.add_child(grid)

	_add_tool_button(grid, "X -", _rotate_axis.bind(Vector3.RIGHT, -1.0))
	_add_tool_button(grid, "X +", _rotate_axis.bind(Vector3.RIGHT, 1.0))
	_add_tool_button(grid, "Y -", _rotate_axis.bind(Vector3.UP, -1.0))
	_add_tool_button(grid, "Y +", _rotate_axis.bind(Vector3.UP, 1.0))
	_add_tool_button(grid, "Z -", _rotate_axis.bind(Vector3.FORWARD, -1.0))
	_add_tool_button(grid, "Z +", _rotate_axis.bind(Vector3.FORWARD, 1.0))
	_add_tool_button(grid, "RESET", _reset_phone_rotation)
	_add_tool_button(grid, "ZOOM +", _zoom_camera.bind(-0.4))
	_add_tool_button(grid, "ZOOM -", _zoom_camera.bind(0.4))

	var hint := _make_label("The model is intentionally a single solid block: no display, camera, buttons, logo or ports.", 10, Color("#b8d9ed"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_content.add_child(hint)


func _get_preview_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PhonePreviewViewport"
	viewport.size = Vector2i(1200, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0a2942")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c7e8ff")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var preview_world := Node3D.new()
	preview_world.name = "PhonePreviewWorld"
	viewport.add_child(preview_world)

	phone_body = MeshInstance3D.new()
	phone_body.name = "Plain_Phone_Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = PHONE_SIZE
	phone_body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#a9c8dc")
	body_material.metallic = 0.28
	body_material.roughness = 0.32
	phone_body.material_override = body_material
	preview_world.add_child(phone_body)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	preview_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#83cfff")
	fill_light.light_energy = 0.7
	fill_light.omni_range = 8.0
	preview_world.add_child(fill_light)

	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0.0, 0.0, 5.2)
	preview_camera.current = true
	preview_camera.fov = 38.0
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	preview_world.add_child(preview_camera)
	return viewport


func _add_tool_button(parent: GridContainer, caption: String, callback: Callable) -> void:
	var button := _make_button(caption, 0.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.x = 0.0
	button.pressed.connect(callback)
	parent.add_child(button)


func _make_button(caption: String, min_width: float, min_height: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(min_width, min_height)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.26, 0.62, 0.82, 0.42)
		if state == "hover":
			style.bg_color = Color(0.38, 0.76, 0.96, 0.62)
		elif state == "pressed":
			style.bg_color = Color(0.10, 0.39, 0.65, 0.78)
		style.border_color = Color(0.82, 0.95, 1.0, 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 5.0
		style.content_margin_right = 5.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		button.add_theme_stylebox_override(state, style)
	return button


func _make_label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_rotate_phone_from_drag(motion.relative)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_rotate_phone_from_drag(drag.relative)


func _rotate_phone_from_drag(delta: Vector2) -> void:
	if not is_instance_valid(phone_body):
		return
	phone_body.rotate_x(-delta.y * DRAG_SENSITIVITY)
	phone_body.rotate_y(-delta.x * DRAG_SENSITIVITY)


func _rotate_axis(axis: Vector3, direction: float) -> void:
	if is_instance_valid(phone_body):
		phone_body.rotate_object_local(axis, ROTATION_STEP * direction)


func _reset_phone_rotation() -> void:
	if is_instance_valid(phone_body):
		phone_body.rotation = Vector3.ZERO


func _zoom_camera(distance_change: float) -> void:
	if not is_instance_valid(preview_camera):
		return
	preview_camera.position.z = clampf(preview_camera.position.z + distance_change, 3.0, 7.5)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _on_back_pressed() -> void:
	back_requested.emit()
