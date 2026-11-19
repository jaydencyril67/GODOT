extends Node3D

const CameraLessPhoneModelScript = preload("res://scripts/camera_worksite_phone_model.gd")

const DRAG_SENSITIVITY := 0.0024
const MIN_PREVIEW_DISTANCE := 3.2
const MAX_PREVIEW_DISTANCE := 7.2
const DEFAULT_PREVIEW_DISTANCE := 4.6

const WIZARD_STEPS := [
	{"title": "CAMERA SYSTEM"},
	{"title": "CAMERA HARDWARE"},
	{"title": "CAMERA POSITIONING"}
]


signal back_requested

var worksite_root: Control
var worksite_body: BoxContainer
var preview_region: Control
var preview_container: SubViewportContainer
var preview_viewport: SubViewport
var preview_world: Node3D
var preview_camera: Camera3D
var phone_model: Node3D

var right_panel_column: VBoxContainer
var selection_scroll: ScrollContainer
var selection_stack: VBoxContainer
var progress_number: Label
var progress_bar: ProgressBar
var step_title_label: Label
var wizard_back_button: Button
var next_button: Button

var current_wizard_step := 1
var preview_mouse_dragging := false
var preview_touch_points: Dictionary = {}


class GlassArrowButton extends Button:
	var points_right := true

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var centre := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		var fill := Color("#292D2F") if disabled else (Color("#6F4B20") if is_hovered() else Color("#15191C"))
		if is_pressed():
			fill = Color("#523817") if not disabled else Color("#24282A")
		draw_circle(centre + Vector2(0, 2), radius + 1.0, Color(0, 0, 0, 0.42))
		draw_circle(centre, radius, fill)
		draw_arc(centre, radius - 1.0, PI * 1.08, PI * 1.92, 48, Color(0.94, 0.91, 0.84, 0.78 if not disabled else 0.24), 1.5, true)
		draw_arc(centre, radius - 1.5, -PI * 0.08, PI * 0.88, 48, Color(0.79, 0.61, 0.35, 0.36 if not disabled else 0.10), 1.0, true)
		var direction := 1.0 if points_right else -1.0
		var arrow_color := Color("#F2EDE4") if not disabled else Color("#8C8983")
		var tip := centre + Vector2(direction * 7.0, 0)
		var upper := centre + Vector2(-direction * 4.5, -7.0)
		var lower := centre + Vector2(-direction * 4.5, 7.0)
		draw_line(upper, tip, arrow_color, 2.8, true)
		draw_line(tip, lower, arrow_color, 2.8, true)
		draw_line(centre + Vector2(-direction * 5.0, 0), centre + Vector2(direction * 6.0, 0), arrow_color, 2.8, true)


func _ready() -> void:
	_build_preview_world()
	_build_interface()
	_set_wizard_step(1)
	_initialize_rear_view()


func _build_preview_world() -> void:
	preview_container = SubViewportContainer.new()
	preview_container.name = "CameraPreviewViewportContainer"
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP

	preview_viewport = SubViewport.new()
	preview_viewport.name = "CameraPreviewViewport"
	preview_viewport.size = Vector2i(640, 640)
	preview_viewport.msaa_3d = Viewport.MSAA_DISABLED
	preview_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	preview_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	preview_viewport.scaling_3d_scale = 1.0
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_container.add_child(preview_viewport)

	preview_world = Node3D.new()
	preview_world.name = "CameraStudioPreviewWorld"
	preview_viewport.add_child(preview_world)

	_build_preview_environment()
	_build_preview_lighting()

	phone_model = CameraLessPhoneModelScript.new() as Node3D
	phone_model.name = "CameraLessPhoneModel"
	phone_model.call("build_camera_less", _create_inactive_screen_texture())
	preview_world.add_child(phone_model)

	preview_camera = Camera3D.new()
	preview_camera.name = "CameraStudioPreviewCamera"
	preview_camera.position = Vector3(0.0, 0.0, -DEFAULT_PREVIEW_DISTANCE)
	preview_camera.fov = 38.0
	preview_camera.near = 0.05
	preview_camera.far = 100.0
	preview_world.add_child(preview_camera)
	preview_camera.current = true


func _create_inactive_screen_texture() -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("#070A0E"))
	return ImageTexture.create_from_image(image)


func _build_preview_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "CameraStudioWorldEnvironment"

	var environment := Environment.new()
	var studio_sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#35383A")
	sky_material.sky_horizon_color = Color("#D5CFC3")
	sky_material.ground_horizon_color = Color("#77736C")
	sky_material.ground_bottom_color = Color("#17191B")
	sky_material.sky_energy_multiplier = 0.85
	sky_material.ground_energy_multiplier = 0.65
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.08
	studio_sky.sky_material = sky_material
	studio_sky.radiance_size = Sky.RADIANCE_SIZE_128

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.sky = studio_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment_node.environment = environment
	preview_world.add_child(environment_node)


func _build_preview_lighting() -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "CameraStudioKeyLight"
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_color = Color("#EEE9DF")
	key_light.light_energy = 0.82
	key_light.shadow_enabled = false
	preview_world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "CameraStudioRimLight"
	rim_light.rotation_degrees = Vector3(18.0, 142.0, -8.0)
	rim_light.light_color = Color("#C7BBA6")
	rim_light.light_energy = 0.34
	rim_light.shadow_enabled = false
	preview_world.add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "CameraStudioFillLight"
	fill_light.position = Vector3(-2.2, 1.4, -2.8)
	fill_light.light_color = Color("#C7BBA6")
	fill_light.light_energy = 0.18
	fill_light.omni_range = 8.0
	preview_world.add_child(fill_light)


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CameraCreationWorksiteInterface"
	layer.layer = 40
	add_child(layer)

	worksite_root = Control.new()
	worksite_root.name = "WorksiteRoot"
	worksite_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worksite_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(worksite_root)

	var backdrop := ColorRect.new()
	backdrop.name = "WorksiteBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#292B2D")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	worksite_root.add_child(backdrop)

	worksite_root.resized.connect(_apply_responsive_layout)

	worksite_body = BoxContainer.new()
	worksite_body.name = "WorksiteMainContent"
	worksite_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worksite_body.offset_left = 20.0
	worksite_body.offset_right = -20.0
	worksite_body.offset_top = 4.0
	worksite_body.offset_bottom = -12.0
	worksite_body.add_theme_constant_override("separation", 0)
	worksite_root.add_child(worksite_body)

	preview_region = Control.new()
	preview_region.name = "CameraPreviewRegion"
	preview_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_region.size_flags_stretch_ratio = 1.12
	preview_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	worksite_body.add_child(preview_region)

	preview_region.add_child(preview_container)
	preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	# SubViewportContainer switches attached viewports to UPDATE_ALWAYS while
	# mounting. Restore visibility-based rendering after the viewport is mounted
	# so the studio does not waste frames when the worksite is hidden.
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

	right_panel_column = VBoxContainer.new()
	right_panel_column.name = "CameraCreationRightPanel"
	right_panel_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel_column.size_flags_stretch_ratio = 0.88
	right_panel_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel_column.add_theme_constant_override("separation", 8)
	worksite_body.add_child(right_panel_column)

	selection_scroll = ScrollContainer.new()
	selection_scroll.name = "CameraSelectionScroll"
	selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_bar := selection_scroll.get_v_scroll_bar()
	scroll_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_panel_column.add_child(selection_scroll)

	var selection_region := MarginContainer.new()
	selection_region.name = "CameraSelectionRegion"
	selection_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_region.add_theme_constant_override("margin_left", 22)
	selection_region.add_theme_constant_override("margin_right", 18)
	selection_region.add_theme_constant_override("margin_top", 20)
	selection_region.add_theme_constant_override("margin_bottom", 20)
	selection_scroll.add_child(selection_region)

	selection_stack = VBoxContainer.new()
	selection_stack.name = "CameraSelectionControls"
	selection_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	selection_stack.add_theme_constant_override("separation", 14)
	selection_region.add_child(selection_stack)


	step_title_label = _label("", 24, Color("#F2EDE4"))
	step_title_label.name = "CameraStepTitle"
	selection_stack.add_child(step_title_label)

	var divider := ColorRect.new()
	divider.name = "CameraStepDivider"
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.color = Color(0.58, 0.46, 0.29, 0.42)
	selection_stack.add_child(divider)



	var progress := VBoxContainer.new()
	progress.name = "WorksiteProgress"
	progress.anchor_left = 1.0
	progress.anchor_right = 1.0
	progress.anchor_top = 0.0
	progress.anchor_bottom = 0.0
	progress.offset_left = -170.0
	progress.offset_top = 12.0
	progress.offset_right = -20.0
	progress.offset_bottom = 50.0
	progress.add_theme_constant_override("separation", 4)
	worksite_root.add_child(progress)

	progress_number = _label("STEP 1 / 3", 11, Color("#E5E0D6"), HORIZONTAL_ALIGNMENT_CENTER)
	progress_number.name = "WorksiteProgressNumber"
	progress_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(progress_number)

	progress_bar = ProgressBar.new()
	progress_bar.name = "WizardProgressBar"
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.min_value = 0
	progress_bar.max_value = WIZARD_STEPS.size()
	progress_bar.value = 1
	progress_bar.show_percentage = false
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color("#C58A3A")
	progress_fill.set_corner_radius_all(4)
	var progress_track := StyleBoxFlat.new()
	progress_track.bg_color = Color("#292D2F")
	progress_track.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_bar.add_theme_stylebox_override("background", progress_track)
	progress.add_child(progress_bar)

	var back_button := Button.new()
	back_button.name = "WorksiteBackButton"
	back_button.text = "BACK"
	back_button.anchor_left = 0.0
	back_button.anchor_right = 0.0
	back_button.anchor_top = 0.0
	back_button.anchor_bottom = 0.0
	back_button.offset_left = 20.0
	back_button.offset_top = 12.0
	back_button.offset_right = 102.0
	back_button.offset_bottom = 60.0
	back_button.focus_mode = Control.FOCUS_NONE
	_style_button(back_button, false)
	back_button.pressed.connect(_on_back_pressed)
	worksite_root.add_child(back_button)


	wizard_back_button = GlassArrowButton.new()
	wizard_back_button.name = "WizardBackIconButton"
	wizard_back_button.points_right = false
	wizard_back_button.anchor_left = 0.0
	wizard_back_button.anchor_right = 0.0
	wizard_back_button.anchor_top = 1.0
	wizard_back_button.anchor_bottom = 1.0
	wizard_back_button.offset_left = 20.0
	wizard_back_button.offset_top = -74.0
	wizard_back_button.offset_right = 74.0
	wizard_back_button.offset_bottom = -20.0
	wizard_back_button.pressed.connect(_on_wizard_back_pressed)
	worksite_root.add_child(wizard_back_button)

	next_button = GlassArrowButton.new()
	next_button.name = "NextStepIconButton"
	next_button.points_right = true
	next_button.anchor_left = 1.0
	next_button.anchor_right = 1.0
	next_button.anchor_top = 1.0
	next_button.anchor_bottom = 1.0
	next_button.offset_left = -74.0
	next_button.offset_top = -74.0
	next_button.offset_right = -20.0
	next_button.offset_bottom = -20.0
	next_button.pressed.connect(_on_next_pressed)
	worksite_root.add_child(next_button)

	_apply_responsive_layout()


func _set_wizard_step(step: int) -> void:
	current_wizard_step = clampi(step, 1, WIZARD_STEPS.size())
	var data: Dictionary = WIZARD_STEPS[current_wizard_step - 1]
	step_title_label.text = str(data.get("title", ""))
	progress_number.text = "STEP %d / %d" % [current_wizard_step, WIZARD_STEPS.size()]
	progress_bar.value = current_wizard_step
	wizard_back_button.disabled = current_wizard_step <= 1
	next_button.disabled = current_wizard_step >= WIZARD_STEPS.size()
	wizard_back_button.queue_redraw()
	next_button.queue_redraw()


func _on_next_pressed() -> void:
	if current_wizard_step < WIZARD_STEPS.size():
		_set_wizard_step(current_wizard_step + 1)


func _on_wizard_back_pressed() -> void:
	if current_wizard_step > 1:
		_set_wizard_step(current_wizard_step - 1)


func _on_back_pressed() -> void:
	back_requested.emit()


func _initialize_rear_view() -> void:
	if not is_instance_valid(preview_camera):
		return
	preview_camera.position = Vector3(0.0, 0.0, -DEFAULT_PREVIEW_DISTANCE)
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)
	if is_instance_valid(phone_model):
		phone_model.rotation = Vector3.ZERO


func _zoom_camera(factor: float) -> void:
	if not is_instance_valid(preview_camera) or factor <= 0.0:
		return
	var direction := signf(preview_camera.position.z)
	if is_zero_approx(direction):
		direction = -1.0
	var distance := clampf(absf(preview_camera.position.z) / factor, MIN_PREVIEW_DISTANCE, MAX_PREVIEW_DISTANCE)
	preview_camera.position.z = direction * distance
	preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _rotate_phone_from_drag(delta: Vector2) -> void:
	if not is_instance_valid(phone_model):
		return
	if absf(delta.x) >= absf(delta.y):
		phone_model.rotation.y += delta.x * DRAG_SENSITIVITY
	else:
		phone_model.rotation.x += delta.y * DRAG_SENSITIVITY


func _input(event: InputEvent) -> void:
	if not is_instance_valid(preview_container) or not preview_container.is_visible_in_tree():
		return
	var preview_rect := preview_container.get_global_rect()

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			preview_mouse_dragging = mouse_button.pressed and preview_rect.has_point(mouse_button.position)
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if preview_mouse_dragging and (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_rotate_phone_from_drag(mouse_motion.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and preview_rect.has_point(touch.position):
			preview_touch_points[touch.index] = touch.position
		else:
			preview_touch_points.erase(touch.index)
	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		if preview_touch_points.has(screen_drag.index):
			preview_touch_points[screen_drag.index] = screen_drag.position
			if preview_touch_points.size() == 1:
				_rotate_phone_from_drag(screen_drag.relative)
				get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture and preview_rect.has_point(event.position):
		_zoom_camera(event.factor)
		get_viewport().set_input_as_handled()


func _apply_responsive_layout() -> void:
	if not is_instance_valid(worksite_body) or not is_instance_valid(preview_region) or not is_instance_valid(selection_scroll) or not is_instance_valid(right_panel_column):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var is_wide := viewport_size.x >= viewport_size.y and viewport_size.x >= 700.0
	worksite_body.vertical = not is_wide
	if is_wide:
		preview_region.size_flags_stretch_ratio = 1.12
		right_panel_column.size_flags_stretch_ratio = 0.88
		preview_region.custom_minimum_size = Vector2.ZERO
		right_panel_column.custom_minimum_size = Vector2(280.0, 0.0)
		selection_scroll.custom_minimum_size = Vector2.ZERO
	else:
		preview_region.size_flags_stretch_ratio = 0.82
		right_panel_column.size_flags_stretch_ratio = 1.18
		preview_region.custom_minimum_size = Vector2(0.0, maxf(140.0, viewport_size.y * 0.24))
		right_panel_column.custom_minimum_size = Vector2(0.0, maxf(270.0, viewport_size.y * 0.52))
		selection_scroll.custom_minimum_size = Vector2.ZERO


func _style_button(button: Button, primary: bool) -> void:
	if not is_instance_valid(button):
		return
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#805821") if primary else Color("#252A2D")
		if state == "hover":
			style.bg_color = Color("#956A2E") if primary else Color("#34393C")
		elif state == "pressed":
			style.bg_color = Color("#61431C") if primary else Color("#1C2022")
		elif state == "disabled":
			style.bg_color = Color("#292D2F")
		style.border_color = Color("#A17A42") if primary else Color("#55524A")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#EEE9DF"))
	button.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_disabled_color", Color("#8A867E"))
	_apply_shared_page_typography(button, 13)


func _add_action_button(parent: Control, caption: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(button, primary)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(text_value: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	_apply_shared_page_typography(label, size + 2)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _apply_shared_page_typography(control: Control, font_size: int) -> void:
	var stix_font := FontVariation.new()
	stix_font.base_font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	stix_font.variation_embolden = 0.7
	control.add_theme_font_override("font", stix_font)
	control.add_theme_font_size_override("font_size", font_size)
