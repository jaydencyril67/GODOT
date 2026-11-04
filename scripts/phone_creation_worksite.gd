extends Node3D

signal back_requested

const PHONE_TYPES := ["Standard", "Flip", "Fold"]

var selected_phone_type := ""
var type_buttons: Dictionary = {}
var next_button: Button
var selection_status: Label
var preview_body: MeshInstance3D
var preview_screen: MeshInstance3D


func _ready() -> void:
	_build_preview_world()
	_build_interface()


func _build_preview_world() -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "PhonePreviewViewportContainer"
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.stretch = true

	var viewport := SubViewport.new()
	viewport.name = "PhonePreviewViewport"
	viewport.size = Vector2i(720, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)
	add_child(viewport_container)

	var preview_world := Node3D.new()
	preview_world.name = "PhonePreviewWorld"
	viewport.add_child(preview_world)

	var camera := Camera3D.new()
	camera.name = "PhonePreviewCamera"
	camera.position = Vector3(0.0, 0.0, 5.2)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.3
	preview_world.add_child(camera)
	camera.current = true

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	preview_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 1.0, 2.0)
	fill_light.light_energy = 0.65
	fill_light.omni_range = 8.0
	preview_world.add_child(fill_light)

	var stage := MeshInstance3D.new()
	stage.name = "PreviewStage"
	var stage_mesh := CylinderMesh.new()
	stage_mesh.top_radius = 1.65
	stage_mesh.bottom_radius = 1.65
	stage_mesh.height = 0.10
	stage.mesh = stage_mesh
	stage.position = Vector3(0.0, -1.55, -0.35)
	var stage_material := StandardMaterial3D.new()
	stage_material.albedo_color = Color("#101b15")
	stage_material.metallic = 0.42
	stage_material.roughness = 0.34
	stage.material_override = stage_material
	preview_world.add_child(stage)

	var phone_root := Node3D.new()
	phone_root.name = "PhoneBlockPreview"
	phone_root.rotation_degrees = Vector3(5.0, -18.0, -3.0)
	preview_world.add_child(phone_root)

	preview_body = MeshInstance3D.new()
	preview_body.name = "PhoneBodyBlock"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.18, 2.42, 0.16)
	preview_body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#343d3a")
	body_material.metallic = 0.72
	body_material.roughness = 0.24
	preview_body.material_override = body_material
	phone_root.add_child(preview_body)

	preview_screen = MeshInstance3D.new()
	preview_screen.name = "PhoneDisplayBlock"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(1.08, 2.30, 0.018)
	preview_screen.mesh = screen_mesh
	preview_screen.position = Vector3(0.0, 0.0, 0.091)
	var screen_material := StandardMaterial3D.new()
	screen_material.albedo_color = Color("#07110d")
	screen_material.metallic = 0.18
	screen_material.roughness = 0.16
	preview_screen.material_override = screen_material
	phone_root.add_child(preview_screen)

	var camera_lens := MeshInstance3D.new()
	camera_lens.name = "PreviewFrontCamera"
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.035
	lens_mesh.bottom_radius = 0.035
	lens_mesh.height = 0.012
	camera_lens.mesh = lens_mesh
	camera_lens.rotation_degrees.x = 90.0
	camera_lens.position = Vector3(0.0, 1.06, 0.105)
	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color("#172a22")
	lens_material.metallic = 0.5
	lens_material.roughness = 0.12
	camera_lens.material_override = lens_material
	phone_root.add_child(camera_lens)


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PhoneCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	var root := Control.new()
	root.name = "WorksiteRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.name = "WorksiteBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#07100b")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.name = "WorksiteLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	root.add_child(layout)

	var top_bar := HBoxContainer.new()
	top_bar.name = "WorksiteTopBar"
	top_bar.custom_minimum_size.y = 54.0
	top_bar.add_theme_constant_override("separation", 12)
	layout.add_child(top_bar)

	var back_button := Button.new()
	back_button.name = "WorksiteBackButton"
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(48, 44)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button, false)
	back_button.pressed.connect(func(): back_requested.emit())
	top_bar.add_child(back_button)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	top_bar.add_child(title_stack)

	var brand := _label("DIGITAL WORLD MOBILES", 10, Color("#a9d9ad"))
	title_stack.add_child(brand)
	var heading := _label("PHONE CREATION", 17, Color("#f2fff3"))
	title_stack.add_child(heading)

	var progress := PanelContainer.new()
	progress.name = "ProgressStepOne"
	progress.custom_minimum_size = Vector2(46, 38)
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color("#1b3d28")
	progress_style.border_color = Color("#70bd83")
	progress_style.set_border_width_all(1)
	progress_style.set_corner_radius_all(10)
	progress.add_theme_stylebox_override("panel", progress_style)
	top_bar.add_child(progress)

	var progress_number := _label("1", 15, Color("#effff0"), HORIZONTAL_ALIGNMENT_CENTER)
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

	var body := HBoxContainer.new()
	body.name = "WorksiteMainContent"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	layout.add_child(body)

	var preview_region := Control.new()
	preview_region.name = "PhonePreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.0
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview_region)

	var viewport_container := get_node("PhonePreviewViewportContainer") as SubViewportContainer
	# Reparent before applying Control anchors so they resolve against the left preview region.
	remove_child(viewport_container)
	preview_region.add_child(viewport_container)
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.offset_left = 0
	viewport_container.offset_right = 0
	viewport_container.offset_top = 0
	viewport_container.offset_bottom = 0

	var preview_caption := _label("LIVE DEVICE PREVIEW", 9, Color("#88b997"), HORIZONTAL_ALIGNMENT_CENTER)
	preview_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	preview_caption.offset_top = -30
	preview_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_region.add_child(preview_caption)

	var selection_region := MarginContainer.new()
	selection_region.name = "PhoneTypeSelectionRegion"
	selection_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_region.size_flags_stretch_ratio = 1.0
	selection_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_region.add_theme_constant_override("margin_left", 22)
	selection_region.add_theme_constant_override("margin_right", 18)
	selection_region.add_theme_constant_override("margin_top", 20)
	selection_region.add_theme_constant_override("margin_bottom", 20)
	body.add_child(selection_region)

	var selection_stack := VBoxContainer.new()
	selection_stack.add_theme_constant_override("separation", 13)
	selection_region.add_child(selection_stack)

	var step_label := _label("STEP 01", 10, Color("#8fc79b"))
	selection_stack.add_child(step_label)
	var section_title := _label("PHONE TYPE", 25, Color("#f2fff3"))
	selection_stack.add_child(section_title)
	var description := _label("Choose the form factor for your new device.", 12, Color("#aebfb1"))
	selection_stack.add_child(description)

	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 9)
	selection_stack.add_child(options)
	for phone_type in PHONE_TYPES:
		var option := Button.new()
		option.name = phone_type.replace(" ", "") + "PhoneTypeOption"
		option.text = phone_type
		option.custom_minimum_size = Vector2(0, 56)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.toggle_mode = true
		option.focus_mode = Control.FOCUS_NONE
		_style_button(option, false)
		option.pressed.connect(_on_phone_type_selected.bind(phone_type))
		options.add_child(option)
		type_buttons[phone_type] = option

	selection_status = _label("Select a phone type to continue.", 10, Color("#829889"))
	selection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_stack.add_child(selection_status)

	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "WorksiteBottomBar"
	bottom_bar.custom_minimum_size.y = 58.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(bottom_bar)

	next_button = Button.new()
	next_button.name = "NextStepIconButton"
	next_button.text = "→"
	next_button.custom_minimum_size = Vector2(54, 50)
	next_button.disabled = true
	next_button.focus_mode = Control.FOCUS_NONE
	_style_button(next_button, true)
	next_button.pressed.connect(_on_next_pressed)
	bottom_bar.add_child(next_button)


func _on_phone_type_selected(phone_type: String) -> void:
	selected_phone_type = phone_type
	for option_name in type_buttons:
		var option: Button = type_buttons[option_name]
		option.button_pressed = option_name == phone_type
		_style_button(option, option_name == phone_type)
	next_button.disabled = false
	selection_status.text = phone_type + " selected."
	_update_preview_for_phone_type(phone_type)


func _update_preview_for_phone_type(phone_type: String) -> void:
	if not is_instance_valid(preview_body) or not is_instance_valid(preview_screen):
		return
	var body_mesh := preview_body.mesh as BoxMesh
	var screen_mesh := preview_screen.mesh as BoxMesh
	match phone_type:
		"Flip":
			body_mesh.size = Vector3(1.12, 2.30, 0.18)
			screen_mesh.size = Vector3(1.02, 2.18, 0.018)
		"Fold":
			body_mesh.size = Vector3(1.38, 2.42, 0.18)
			screen_mesh.size = Vector3(1.28, 2.30, 0.018)
		_:
			body_mesh.size = Vector3(1.18, 2.42, 0.16)
			screen_mesh.size = Vector3(1.08, 2.30, 0.018)


func _on_next_pressed() -> void:
	if selected_phone_type.is_empty():
		return
	selection_status.text = selected_phone_type + " selected. The next stage will be added in the next build step."


func _style_button(button: Button, primary: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#285c39") if primary else Color("#14241a")
		if state == "hover":
			style.bg_color = Color("#367b4b") if primary else Color("#20382a")
		elif state == "pressed":
			style.bg_color = Color("#19472a")
		elif state == "disabled":
			style.bg_color = Color("#172019")
		style.border_color = Color("#79c58a") if primary else Color("#476b50")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#effff0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#718075"))
	button.add_theme_font_size_override("font_size", 16)


func _label(value: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
