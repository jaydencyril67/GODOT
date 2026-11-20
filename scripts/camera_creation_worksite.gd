extends Node3D

const CameraLessPhoneModelScript = preload("res://scripts/camera_worksite_phone_model.gd")
const ResearchManagerScript = preload("res://scripts/digitalworld_research_manager.gd")

const MAX_REAR_CAMERAS := 5
const MAX_REAR_FLASHES := 5
const MAX_CAMERA_BACK_DESIGN_BOXES := 20
const REAR_HARDWARE_GRID_STEP := 0.04
const REAR_HARDWARE_SPAWN_GRID_INTERVALS := 3
const REAR_HARDWARE_SIZE_MIN := 0.05
const REAR_HARDWARE_SIZE_MAX := 0.20
const CAMERA_WORKSITE_PHONE_DEPTH := 0.13
const CAMERA_BACK_DESIGN_BOX_DEPTH := 0.035 / 1.10 / 1.5
const CAMERA_BACK_DESIGN_GRID_STEP := 0.08

const DRAG_SENSITIVITY := 0.0024
const MIN_PREVIEW_DISTANCE := 3.2
const MAX_PREVIEW_DISTANCE := 7.2
const DEFAULT_PREVIEW_DISTANCE := 4.6

const FRONT_CAMERA_STYLES := [
	"Bezel Camera",
	"Waterdrop Notch",
	"Punch-Hole",
	"Side Punch-Hole",
	"Dual Punch-Hole",
	"Pop-Up Camera",
	"Dynamic Island",
	"Under-Display Camera"
]
const FRONT_CAMERA_PREVIEW_SCREEN_WIDTH := 1.41
const FRONT_CAMERA_PREVIEW_SCREEN_HEIGHT := 2.88
const FRONT_CAMERA_PREVIEW_FACE_Z := 0.075

const WIZARD_STEPS := [
	{"title": "RARE CAMERA"},
	{"title": "REAR CAMERA MP"},
	{"title": "FRONT CAMERA"},
	{"title": "FRONT CAMERA MP"}
]


signal back_requested
signal research_requested

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

var rear_camera_modules: Array[Dictionary] = []
var rear_flash_modules: Array[Dictionary] = []
var rear_camera_mp_research_level := 0
var rear_camera_mp_sliders: Array[VSlider] = []
var rear_camera_mp_value_labels: Array[Label] = []
var rear_camera_mp_max_labels: Array[Label] = []
var rear_camera_mp_slider_camera_ids: Array[int] = []
var rear_camera_mp_step_content: VBoxContainer

var front_camera_enabled := false
var front_camera_style := "Bezel Camera"
var front_camera_research_level := 0
var front_camera_mp_research_level := 0
var front_camera_megapixels := 1
var front_camera_secondary_megapixels := 1
var front_camera_step_content: VBoxContainer
var front_camera_mp_step_content: VBoxContainer
var front_camera_enable_button: Button
var front_camera_style_label: Label
var front_camera_research_label: Label
var front_camera_style_previous_button: Button
var front_camera_style_next_button: Button
var front_camera_mp_sliders: Array[VSlider] = []
var front_camera_mp_value_labels: Array[Label] = []
var front_camera_mp_max_labels: Array[Label] = []
var rear_hardware_mode := "CAMERA"
var rear_camera_selected_index := -1
var rear_flash_selected_index := -1
var next_rear_camera_id := 1
var next_rear_flash_id := 1

var rear_hardware_step_content: VBoxContainer
var rear_hardware_controls_view: VBoxContainer
var rear_hardware_selection_view: VBoxContainer
var rear_hardware_mode_switchers: HBoxContainer
var rear_hardware_camera_mode_button: Button
var rear_hardware_flash_mode_button: Button
var rear_hardware_design_mode_button: Button
var rear_hardware_selection_button: Button
var rear_hardware_size_label: Label
var rear_hardware_size_slider: HSlider
var rear_hardware_add_button: Button
var rear_hardware_remove_button: Button
var rear_hardware_move_buttons: Array[Button] = []
var right_panel_mode := "CAMERA"

var camera_back_design_boxes: Array[Dictionary] = []
var camera_back_design_research_level := 0
var camera_back_design_selected_index := -1
var next_camera_back_design_id := 1
var camera_back_design_mode := "MOVE"
var camera_back_design_size_action := "EXPAND"
var camera_back_design_color := Color("#a5adb6")
var camera_back_design_view: VBoxContainer
var camera_back_design_selection_view: VBoxContainer
var camera_back_design_selection_button: Button
var camera_back_design_capacity_label: Label
var camera_back_design_size_label: Label
var camera_back_design_rounding_label: Label
var camera_back_design_rounding_slider: HSlider
var camera_back_design_move_buttons: Array[Button] = []


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
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#B6B0A5")
	environment.ambient_light_energy = 0.66
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	sky_material.sky_top_color = Color("#77736C")
	sky_material.sky_horizon_color = Color("#D5CFC3")
	sky_material.ground_horizon_color = Color("#716C63")
	sky_material.ground_bottom_color = Color("#34312D")
	sky_material.sky_energy_multiplier = 0.9
	sky_material.ground_energy_multiplier = 0.72
	environment_node.environment = environment
	preview_world.add_child(environment_node)


func _build_preview_lighting() -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "CameraStudioKeyLight"
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_color = Color("#EEE9DF")
	key_light.light_color = Color("#fffdf8")
	key_light.light_energy = 1.20
	key_light.shadow_enabled = false
	preview_world.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "CameraStudioRimLight"
	rim_light.rotation_degrees = Vector3(18.0, 142.0, -8.0)
	rim_light.light_color = Color("#C7BBA6")
	rim_light.light_energy = 0.78
	rim_light.shadow_enabled = false
	preview_world.add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "CameraStudioFillLight"
	fill_light.position = Vector3(-2.2, 1.4, -2.8)
	fill_light.light_color = Color("#D8D1C5")
	fill_light.light_energy = 0.38
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

	_build_rear_hardware_step_controls()
	_build_rear_camera_mp_step_controls()
	_build_front_camera_step_controls()
	_build_front_camera_mp_step_controls()


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

	progress_number = _label("STEP 1 / 4", 11, Color("#E5E0D6"), HORIZONTAL_ALIGNMENT_CENTER)
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
	var previous_step := current_wizard_step
	current_wizard_step = clampi(step, 1, WIZARD_STEPS.size())
	var data: Dictionary = WIZARD_STEPS[current_wizard_step - 1]
	step_title_label.text = str(data.get("title", ""))
	progress_number.text = "STEP %d / %d" % [current_wizard_step, WIZARD_STEPS.size()]
	progress_bar.value = current_wizard_step
	if is_instance_valid(rear_hardware_step_content):
		rear_hardware_step_content.visible = current_wizard_step == 1
		if current_wizard_step == 1 and previous_step != 1:
			_show_rear_camera_controls()
	if is_instance_valid(rear_camera_mp_step_content):
		rear_camera_mp_step_content.visible = current_wizard_step == 2
		if current_wizard_step == 2:
			_refresh_rear_camera_mp_controls()
	if is_instance_valid(front_camera_step_content):
		front_camera_step_content.visible = current_wizard_step == 3
		if current_wizard_step == 3:
			_refresh_front_camera_step_controls()
	if is_instance_valid(front_camera_mp_step_content):
		front_camera_mp_step_content.visible = current_wizard_step == 4
		if current_wizard_step == 4:
			_refresh_front_camera_mp_controls()
	if is_instance_valid(phone_model):
		phone_model.rotation = Vector3(0.0, PI, 0.0) if current_wizard_step >= 3 else Vector3.ZERO
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



func _build_rear_hardware_step_controls() -> void:
	rear_hardware_step_content = VBoxContainer.new()
	rear_hardware_step_content.name = "RareCameraStepControls"
	rear_hardware_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rear_hardware_step_content.add_theme_constant_override("separation", 9)
	selection_stack.add_child(rear_hardware_step_content)

	rear_hardware_mode_switchers = HBoxContainer.new()
	rear_hardware_mode_switchers.name = "RearHardwareModeSwitchers"
	rear_hardware_mode_switchers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_mode_switchers.add_theme_constant_override("separation", 6)
	rear_hardware_step_content.add_child(rear_hardware_mode_switchers)

	rear_hardware_camera_mode_button = Button.new()
	rear_hardware_camera_mode_button.name = "RearHardwareModeCamera"
	rear_hardware_camera_mode_button.text = "CAMERA"
	rear_hardware_camera_mode_button.custom_minimum_size = Vector2(0, 36)
	rear_hardware_camera_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_camera_mode_button.pressed.connect(_set_rear_hardware_mode.bind("CAMERA"))
	_style_button(rear_hardware_camera_mode_button, true)
	rear_hardware_mode_switchers.add_child(rear_hardware_camera_mode_button)

	rear_hardware_flash_mode_button = Button.new()
	rear_hardware_flash_mode_button.name = "RearHardwareModeFlash"
	rear_hardware_flash_mode_button.text = "FLASH"
	rear_hardware_flash_mode_button.custom_minimum_size = Vector2(0, 36)
	rear_hardware_flash_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_flash_mode_button.pressed.connect(_set_rear_hardware_mode.bind("FLASH"))
	_style_button(rear_hardware_flash_mode_button, false)
	rear_hardware_mode_switchers.add_child(rear_hardware_flash_mode_button)

	rear_hardware_design_mode_button = Button.new()
	rear_hardware_design_mode_button.name = "RearHardwareModeDesign"
	rear_hardware_design_mode_button.text = "DESIGN"
	rear_hardware_design_mode_button.custom_minimum_size = Vector2(0, 36)
	rear_hardware_design_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_design_mode_button.pressed.connect(_show_camera_back_design_controls)
	_style_button(rear_hardware_design_mode_button, false)
	rear_hardware_mode_switchers.add_child(rear_hardware_design_mode_button)

	rear_hardware_controls_view = VBoxContainer.new()
	rear_hardware_controls_view.name = "RearHardwareControls"
	rear_hardware_controls_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_controls_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rear_hardware_controls_view.add_theme_constant_override("separation", 7)
	rear_hardware_step_content.add_child(rear_hardware_controls_view)

	var heading := _label("REAR CAMERA & FLASH", 16, Color("#E5E0D6"), HORIZONTAL_ALIGNMENT_CENTER)
	rear_hardware_controls_view.add_child(heading)

	var management := HBoxContainer.new()
	management.name = "RearHardwareManagementStrip"
	management.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	management.add_theme_constant_override("separation", 6)
	rear_hardware_controls_view.add_child(management)

	rear_hardware_selection_button = Button.new()
	rear_hardware_selection_button.name = "RearHardwareItemSelector"
	rear_hardware_selection_button.custom_minimum_size = Vector2(0, 42)
	rear_hardware_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_button.pressed.connect(_show_rear_hardware_selection_controls)
	_style_button(rear_hardware_selection_button, true)
	management.add_child(rear_hardware_selection_button)

	var size_section := VBoxContainer.new()
	size_section.name = "RearHardwareSizeSection"
	size_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_section.add_theme_constant_override("separation", 3)
	rear_hardware_controls_view.add_child(size_section)

	var size_header := HBoxContainer.new()
	size_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_header.add_theme_constant_override("separation", 8)
	size_section.add_child(size_header)

	var size_heading := _label("SIZE", 10, Color("#B8AFA2"))
	size_heading.name = "RearHardwareSizeHeading"
	size_heading.custom_minimum_size = Vector2(42, 0)
	size_heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	size_heading.clip_text = true
	size_header.add_child(size_heading)

	rear_hardware_size_label = _label("ADD A COMPONENT TO BEGIN", 11, Color("#E5E0D6"))
	rear_hardware_size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rear_hardware_size_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	size_header.add_child(rear_hardware_size_label)

	rear_hardware_size_slider = HSlider.new()
	rear_hardware_size_slider.name = "RearHardwareHorizontalSizeSlider"
	rear_hardware_size_slider.min_value = REAR_HARDWARE_SIZE_MIN
	rear_hardware_size_slider.max_value = REAR_HARDWARE_SIZE_MAX
	rear_hardware_size_slider.step = 0.005
	rear_hardware_size_slider.custom_minimum_size = Vector2(0, 24)
	rear_hardware_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_size_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_rear_hardware_slider(rear_hardware_size_slider)
	rear_hardware_size_slider.value_changed.connect(_on_rear_hardware_size_changed)
	size_section.add_child(rear_hardware_size_slider)

	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 560.0 or viewport_size.x < 520.0
	var icon_diameter := 56.0 if tight else 64.0
	var pad_control_row := HBoxContainer.new()
	pad_control_row.name = "RearHardwarePadWithManagement"
	pad_control_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_control_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_theme_constant_override("separation", 10 if tight else 14)
	rear_hardware_controls_view.add_child(pad_control_row)

	rear_hardware_add_button = _make_rear_hardware_icon_button(
		pad_control_row, "RearHardwareAddButton", "+", "Add camera or flash",
		Callable(self, "_add_rear_hardware_module"), icon_diameter, true
	)

	var pad_center := CenterContainer.new()
	pad_center.name = "RearHardwareDirectionControllerCenter"
	pad_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_child(pad_center)

	var pad_shell := PanelContainer.new()
	pad_shell.name = "RearHardwareDirectionController"
	pad_shell.custom_minimum_size = Vector2(204, 204) if not tight else Vector2(184, 184)
	var pad_style := StyleBoxFlat.new()
	pad_style.bg_color = Color(0.12, 0.13, 0.14, 0.72)
	pad_style.border_color = Color(0.58, 0.46, 0.29, 0.72)
	pad_style.set_border_width_all(1)
	pad_style.set_corner_radius_all(16)
	pad_style.content_margin_left = 8
	pad_style.content_margin_right = 8
	pad_style.content_margin_top = 8
	pad_style.content_margin_bottom = 8
	pad_shell.add_theme_stylebox_override("panel", pad_style)
	pad_center.add_child(pad_shell)

	var pad := GridContainer.new()
	pad.name = "RearHardwareDirectionPad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 18 if not tight else 16)
	pad.add_theme_constant_override("v_separation", 6)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad_shell.add_child(pad)

	_add_rear_hardware_pad_spacer(pad, tight)
	_add_rear_hardware_pad_button(pad, "↑", Vector2i(0, 1), tight)
	_add_rear_hardware_pad_spacer(pad, tight)
	_add_rear_hardware_pad_button(pad, "←", Vector2i(-1, 0), tight)

	var move_label := Button.new()
	move_label.name = "RearHardwareMoveCenterButton"
	move_label.text = "MOVE"
	move_label.custom_minimum_size = Vector2(64, 38)
	move_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_shared_page_typography(move_label, 11)
	_style_button(move_label, true)
	pad.add_child(move_label)

	_add_rear_hardware_pad_button(pad, "→", Vector2i(1, 0), tight)
	_add_rear_hardware_pad_spacer(pad, tight)
	_add_rear_hardware_pad_button(pad, "↓", Vector2i(0, -1), tight)
	_add_rear_hardware_pad_spacer(pad, tight)

	rear_hardware_remove_button = _make_rear_hardware_icon_button(
		pad_control_row, "RearHardwareRemoveButton", "−", "Remove selected component",
		Callable(self, "_remove_rear_hardware_module"), icon_diameter, false
	)
	rear_hardware_step_content.visible = false
	_refresh_rear_hardware_panel()



func set_back_raised_design_research_level(level: int) -> void:
	var updated_level := clampi(level, 0, MAX_CAMERA_BACK_DESIGN_BOXES)
	if updated_level == camera_back_design_research_level:
		return
	camera_back_design_research_level = updated_level
	if current_wizard_step == 1 and right_panel_mode == "DESIGN":
		_show_camera_back_design_controls()


func _build_rear_camera_mp_step_controls() -> void:
	rear_camera_mp_step_content = VBoxContainer.new()
	rear_camera_mp_step_content.name = "RearCameraMegapixelStepControls"
	rear_camera_mp_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_camera_mp_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rear_camera_mp_step_content.add_theme_constant_override("separation", 8)
	rear_camera_mp_step_content.visible = false
	selection_stack.add_child(rear_camera_mp_step_content)
	_refresh_rear_camera_mp_controls()


func _refresh_rear_camera_mp_controls() -> void:
	if not is_instance_valid(rear_camera_mp_step_content):
		return
	for child in rear_camera_mp_step_content.get_children():
		rear_camera_mp_step_content.remove_child(child)
		child.free()
	rear_camera_mp_sliders.clear()
	rear_camera_mp_value_labels.clear()
	rear_camera_mp_max_labels.clear()
	rear_camera_mp_slider_camera_ids.clear()

	var heading := _label("REAR CAMERA MP", 19, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_camera_mp_step_content.add_child(heading)

	if rear_camera_modules.is_empty():
		var hint := _label("Add rear cameras in Step 1 first", 11, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		rear_camera_mp_step_content.add_child(hint)
		return

	var slider_row := HBoxContainer.new()
	slider_row.name = "RearCameraMegapixelOptions"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 5)
	rear_camera_mp_step_content.add_child(slider_row)

	for camera_index in range(rear_camera_modules.size()):
		var camera_data: Dictionary = rear_camera_modules[camera_index]
		var camera_id := int(camera_data.get("id", camera_index + 1))
		var megapixels := int(camera_data.get("mp", ResearchManagerScript.REAR_CAMERA_MP_BASE))
		var card := _make_rear_camera_mp_slider_card(camera_index + 1, camera_id, megapixels)
		slider_row.add_child(card)


func _make_rear_camera_mp_slider_card(camera_number: int, camera_id: int, current_mp: int) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "RearCameraMegapixelCard_%d" % camera_number
	card.custom_minimum_size = Vector2(52, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_constant_override("separation", 2)

	var title := _label("%02d" % camera_number, 11, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	title.clip_text = true
	card.add_child(title)

	var available_maximum := _get_rear_camera_mp_maximum()
	var selected_mp := clampi(current_mp, ResearchManagerScript.REAR_CAMERA_MP_BASE, available_maximum)
	var value_label := _label("%d MP" % selected_mp, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	value_label.name = "CameraMPValueLabel"
	card.add_child(value_label)
	rear_camera_mp_value_labels.append(value_label)

	var maximum_label := _label(str(available_maximum), 9, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
	maximum_label.name = "CameraMPMaximumLabel"
	card.add_child(maximum_label)
	rear_camera_mp_max_labels.append(maximum_label)

	var slider := VSlider.new()
	slider.name = "CameraMPValueSlider"
	slider.min_value = ResearchManagerScript.REAR_CAMERA_MP_BASE
	slider.max_value = available_maximum
	slider.step = 1
	slider.value = selected_mp
	slider.custom_minimum_size = Vector2(30, 320)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_rear_hardware_slider(slider)
	slider.value_changed.connect(func(value: float) -> void:
		var megapixels := clampi(roundi(value), ResearchManagerScript.REAR_CAMERA_MP_BASE, _get_rear_camera_mp_maximum())
		value_label.text = "%d MP" % megapixels
		_set_rear_camera_mp_value(megapixels, camera_id)
	)
	card.add_child(slider)
	rear_camera_mp_sliders.append(slider)
	rear_camera_mp_slider_camera_ids.append(camera_id)

	var minimum_label := _label(str(ResearchManagerScript.REAR_CAMERA_MP_BASE), 9, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(minimum_label)
	return card


func set_rear_camera_mp_research_level(level: int) -> void:
	rear_camera_mp_research_level = clampi(level, 0, ResearchManagerScript.REAR_CAMERA_MP_RESEARCH_UPGRADES)
	var available_maximum := _get_rear_camera_mp_maximum()
	for camera_index in range(rear_camera_modules.size()):
		var camera_data: Dictionary = rear_camera_modules[camera_index]
		camera_data["mp"] = clampi(
			int(camera_data.get("mp", ResearchManagerScript.REAR_CAMERA_MP_BASE)),
			ResearchManagerScript.REAR_CAMERA_MP_BASE,
			available_maximum
		)
		rear_camera_modules[camera_index] = camera_data
	_refresh_rear_camera_mp_controls()


func _get_rear_camera_mp_maximum() -> int:
	return ResearchManagerScript.get_rear_camera_mp_max_for_level(rear_camera_mp_research_level)


func _build_front_camera_step_controls() -> void:
	front_camera_step_content = VBoxContainer.new()
	front_camera_step_content.name = "FrontCameraStepControls"
	front_camera_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_camera_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	front_camera_step_content.add_theme_constant_override("separation", 12)
	front_camera_step_content.visible = false
	selection_stack.add_child(front_camera_step_content)

	var heading := _label("FRONT CAMERA", 19, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_camera_step_content.add_child(heading)

	var enable_row := HBoxContainer.new()
	enable_row.name = "FrontCameraEnablementRow"
	enable_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enable_row.add_theme_constant_override("separation", 9)
	front_camera_step_content.add_child(enable_row)

	front_camera_enable_button = Button.new()
	front_camera_enable_button.name = "FrontCameraEnablement"
	front_camera_enable_button.text = "ENABLED" if front_camera_enabled else "DISABLED"
	front_camera_enable_button.toggle_mode = true
	front_camera_enable_button.button_pressed = front_camera_enabled
	front_camera_enable_button.custom_minimum_size = Vector2(112, 38)
	front_camera_enable_button.focus_mode = Control.FOCUS_NONE
	_style_button(front_camera_enable_button, front_camera_enabled)
	front_camera_enable_button.toggled.connect(_on_front_camera_enabled_toggled)
	enable_row.add_child(front_camera_enable_button)

	var enable_description := _label("Front Camera", 13, Color("#E5E0D6"))
	enable_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	enable_row.add_child(enable_description)

	front_camera_style_label = _label("", 15, Color("#F2EDE4"), HORIZONTAL_ALIGNMENT_CENTER)
	front_camera_style_label.name = "FrontCameraStyleValue"
	front_camera_style_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_camera_step_content.add_child(front_camera_style_label)

	var style_controls := HBoxContainer.new()
	style_controls.name = "FrontCameraStyleControls"
	style_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	style_controls.add_theme_constant_override("separation", 18)
	front_camera_step_content.add_child(style_controls)

	front_camera_style_previous_button = Button.new()
	front_camera_style_previous_button.name = "DecreaseFrontCameraButton"
	front_camera_style_previous_button.text = "‹"
	front_camera_style_previous_button.custom_minimum_size = Vector2(52, 44)
	front_camera_style_previous_button.focus_mode = Control.FOCUS_NONE
	_style_button(front_camera_style_previous_button, false)
	front_camera_style_previous_button.pressed.connect(_change_front_camera_style.bind(-1))
	style_controls.add_child(front_camera_style_previous_button)

	front_camera_style_next_button = Button.new()
	front_camera_style_next_button.name = "IncreaseFrontCameraButton"
	front_camera_style_next_button.text = "›"
	front_camera_style_next_button.custom_minimum_size = Vector2(52, 44)
	front_camera_style_next_button.focus_mode = Control.FOCUS_NONE
	_style_button(front_camera_style_next_button, false)
	front_camera_style_next_button.pressed.connect(_change_front_camera_style.bind(1))
	style_controls.add_child(front_camera_style_next_button)

	front_camera_research_label = _label("", 10, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
	front_camera_research_label.name = "FrontCameraResearchProgress"
	front_camera_research_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	front_camera_step_content.add_child(front_camera_research_label)
	_refresh_front_camera_step_controls()


func _refresh_front_camera_step_controls() -> void:
	if not is_instance_valid(front_camera_step_content):
		return
	var style_index := FRONT_CAMERA_STYLES.find(front_camera_style)
	if style_index < 0:
		style_index = 0
		front_camera_style = FRONT_CAMERA_STYLES[0]
	if is_instance_valid(front_camera_enable_button):
		front_camera_enable_button.set_pressed_no_signal(front_camera_enabled)
		front_camera_enable_button.text = "ENABLED" if front_camera_enabled else "DISABLED"
		_style_button(front_camera_enable_button, front_camera_enabled)
	if is_instance_valid(front_camera_style_label):
		front_camera_style_label.text = front_camera_style.to_upper()
	if is_instance_valid(front_camera_style_previous_button):
		front_camera_style_previous_button.disabled = not front_camera_enabled or style_index <= 0
	if is_instance_valid(front_camera_style_next_button):
		front_camera_style_next_button.disabled = not front_camera_enabled or style_index >= front_camera_research_level
	if is_instance_valid(front_camera_research_label):
		front_camera_research_label.text = "DESIGNS UNLOCKED  ·  %d / %d" % [front_camera_research_level + 1, FRONT_CAMERA_STYLES.size()]


func _on_front_camera_enabled_toggled(enabled: bool) -> void:
	front_camera_enabled = enabled
	_refresh_front_camera_step_controls()
	_refresh_front_camera_visuals()
	_refresh_front_camera_mp_controls()


func _change_front_camera_style(direction: int) -> void:
	if not front_camera_enabled:
		return
	var current_index := FRONT_CAMERA_STYLES.find(front_camera_style)
	if current_index < 0:
		current_index = 0
	var next_index := clampi(current_index + direction, 0, front_camera_research_level)
	if next_index == current_index:
		return
	front_camera_style = FRONT_CAMERA_STYLES[next_index]
	_refresh_front_camera_step_controls()
	_refresh_front_camera_visuals()
	_refresh_front_camera_mp_controls()


func set_front_camera_research_level(level: int) -> void:
	front_camera_research_level = clampi(level, 0, FRONT_CAMERA_STYLES.size() - 1)
	var style_index := FRONT_CAMERA_STYLES.find(front_camera_style)
	if style_index < 0 or style_index > front_camera_research_level:
		front_camera_style = FRONT_CAMERA_STYLES[front_camera_research_level]
	_refresh_front_camera_step_controls()
	_refresh_front_camera_visuals()
	_refresh_front_camera_mp_controls()


func _build_front_camera_mp_step_controls() -> void:
	front_camera_mp_step_content = VBoxContainer.new()
	front_camera_mp_step_content.name = "FrontCameraMegapixelStepControls"
	front_camera_mp_step_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_camera_mp_step_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	front_camera_mp_step_content.add_theme_constant_override("separation", 8)
	front_camera_mp_step_content.visible = false
	selection_stack.add_child(front_camera_mp_step_content)
	_refresh_front_camera_mp_controls()


func _refresh_front_camera_mp_controls() -> void:
	if not is_instance_valid(front_camera_mp_step_content):
		return
	for child in front_camera_mp_step_content.get_children():
		front_camera_mp_step_content.remove_child(child)
		child.free()
	front_camera_mp_sliders.clear()
	front_camera_mp_value_labels.clear()
	front_camera_mp_max_labels.clear()

	var heading := _label("FRONT CAMERA MP", 19, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	front_camera_mp_step_content.add_child(heading)

	if not front_camera_enabled:
		var hint := _label("Enable the front camera in Step 3 first", 11, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		front_camera_mp_step_content.add_child(hint)
		return

	var slider_row := HBoxContainer.new()
	slider_row.name = "FrontCameraMegapixelOptions"
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 12)
	front_camera_mp_step_content.add_child(slider_row)
	slider_row.add_child(_make_front_camera_mp_slider_card(1, front_camera_megapixels))
	if front_camera_style == "Dual Punch-Hole":
		slider_row.add_child(_make_front_camera_mp_slider_card(2, front_camera_secondary_megapixels))


func _make_front_camera_mp_slider_card(camera_number: int, current_mp: int) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.name = "FrontCameraMegapixelCard_%d" % camera_number
	card.custom_minimum_size = Vector2(64, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_constant_override("separation", 2)

	var title := _label("%02d" % camera_number, 11, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(title)

	var available_maximum := _get_front_camera_mp_maximum()
	var selected_mp := clampi(current_mp, ResearchManagerScript.FRONT_CAMERA_MP_BASE, available_maximum)
	var value_label := _label("%d MP" % selected_mp, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	value_label.name = "FrontCameraMPValueLabel"
	card.add_child(value_label)
	front_camera_mp_value_labels.append(value_label)

	var maximum_label := _label(str(available_maximum), 9, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
	maximum_label.name = "FrontCameraMPMaximumLabel"
	card.add_child(maximum_label)
	front_camera_mp_max_labels.append(maximum_label)

	var slider := VSlider.new()
	slider.name = "FrontCameraMPValueSlider"
	slider.min_value = ResearchManagerScript.FRONT_CAMERA_MP_BASE
	slider.max_value = available_maximum
	slider.step = 1
	slider.value = selected_mp
	slider.custom_minimum_size = Vector2(30, 320)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_rear_hardware_slider(slider)
	slider.value_changed.connect(_on_front_camera_mp_slider_changed.bind(camera_number - 1))
	card.add_child(slider)
	front_camera_mp_sliders.append(slider)

	var minimum_label := _label(str(ResearchManagerScript.FRONT_CAMERA_MP_BASE), 9, Color("#A9A092"), HORIZONTAL_ALIGNMENT_CENTER)
	card.add_child(minimum_label)
	return card


func _on_front_camera_mp_slider_changed(value: float, camera_index: int) -> void:
	_set_front_camera_mp_value(roundi(value), camera_index)
	if camera_index >= 0 and camera_index < front_camera_mp_value_labels.size():
		front_camera_mp_value_labels[camera_index].text = "%d MP" % roundi(value)


func _set_front_camera_mp_value(megapixels: int, camera_index: int) -> void:
	var selected_mp := clampi(megapixels, ResearchManagerScript.FRONT_CAMERA_MP_BASE, _get_front_camera_mp_maximum())
	if camera_index == 0:
		front_camera_megapixels = selected_mp
	elif camera_index == 1:
		front_camera_secondary_megapixels = selected_mp


func set_front_camera_mp_research_level(level: int) -> void:
	front_camera_mp_research_level = clampi(level, 0, ResearchManagerScript.FRONT_CAMERA_MP_RESEARCH_UPGRADES)
	var available_maximum := _get_front_camera_mp_maximum()
	front_camera_megapixels = clampi(front_camera_megapixels, ResearchManagerScript.FRONT_CAMERA_MP_BASE, available_maximum)
	front_camera_secondary_megapixels = clampi(front_camera_secondary_megapixels, ResearchManagerScript.FRONT_CAMERA_MP_BASE, available_maximum)
	_refresh_front_camera_mp_controls()


func _get_front_camera_mp_maximum() -> int:
	return ResearchManagerScript.get_front_camera_mp_max_for_level(front_camera_mp_research_level)


func _set_rear_camera_mp_value(megapixels: int, camera_id: int) -> void:
	for camera_index in range(rear_camera_modules.size()):
		var camera_data: Dictionary = rear_camera_modules[camera_index]
		if int(camera_data.get("id", -1)) != camera_id:
			continue
		camera_data["mp"] = clampi(
			megapixels,
			ResearchManagerScript.REAR_CAMERA_MP_BASE,
			_get_rear_camera_mp_maximum()
		)
		rear_camera_modules[camera_index] = camera_data
		break


func _show_camera_back_design_controls() -> void:
	if not is_instance_valid(rear_hardware_step_content):
		return
	right_panel_mode = "DESIGN"
	if is_instance_valid(rear_hardware_selection_view):
		rear_hardware_selection_view.queue_free()
		rear_hardware_selection_view = null
	if is_instance_valid(camera_back_design_selection_view):
		camera_back_design_selection_view.queue_free()
		camera_back_design_selection_view = null
	if is_instance_valid(rear_hardware_controls_view):
		rear_hardware_controls_view.visible = false
	if is_instance_valid(camera_back_design_view):
		camera_back_design_view.queue_free()
		camera_back_design_view = null
	camera_back_design_move_buttons.clear()
	camera_back_design_view = _build_camera_back_design_controls()
	rear_hardware_step_content.add_child(camera_back_design_view)
	_refresh_camera_back_design_panel()
	_style_button(rear_hardware_camera_mode_button, false)
	_style_button(rear_hardware_flash_mode_button, false)
	_style_button(rear_hardware_design_mode_button, true)


func _build_camera_back_design_controls() -> VBoxContainer:
	camera_back_design_move_buttons.clear()
	var viewport_size := get_viewport().get_visible_rect().size
	var tight := viewport_size.y < 560.0 or viewport_size.x < 520.0
	var control_height := 40.0 if tight else 44.0
	var panel := VBoxContainer.new()
	panel.name = "CameraBackDesignControls"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 7 if tight else 9)

	if camera_back_design_research_level <= 0:
		var locked_heading := _label("BACK RAISED DESIGN", 16, Color("#E5E0D6"), HORIZONTAL_ALIGNMENT_CENTER)
		panel.add_child(locked_heading)
		var controls_center := CenterContainer.new()
		controls_center.name = "CameraBackRaisedDesignResearchControlsCenter"
		controls_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		controls_center.custom_minimum_size = Vector2(0, 360)
		panel.add_child(controls_center)
		var locked_research_button := Button.new()
		locked_research_button.name = "CameraBackDesignResearchButton"
		locked_research_button.text = "RESEARCH"
		locked_research_button.custom_minimum_size = Vector2(0, 48 if not tight else 44)
		locked_research_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		locked_research_button.focus_mode = Control.FOCUS_NONE
		_style_button(locked_research_button, true)
		locked_research_button.pressed.connect(_request_camera_back_raised_design_research)
		controls_center.add_child(locked_research_button)
		return panel

	var heading := _label("BACK DESIGN", 16, Color("#E5E0D6"), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(heading)

	var top_controls := HBoxContainer.new()
	top_controls.name = "CameraBackDesignTopControls"
	top_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_controls.add_theme_constant_override("separation", 6)
	panel.add_child(top_controls)

	for mode in ["SIZE", "MOVE"]:
		var mode_button := Button.new()
		mode_button.name = "CameraBackDesignMode%s" % mode.capitalize()
		mode_button.text = mode
		mode_button.custom_minimum_size = Vector2(0, 36 if tight else 39)
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.focus_mode = Control.FOCUS_NONE
		_style_button(mode_button, camera_back_design_mode == mode)
		mode_button.pressed.connect(_set_camera_back_design_mode.bind(mode))
		top_controls.add_child(mode_button)

	var color_button := Button.new()
	color_button.name = "CameraBackDesignColorButton"
	color_button.text = "COLOR"
	color_button.custom_minimum_size = Vector2(0, 36 if tight else 39)
	color_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_button.focus_mode = Control.FOCUS_NONE
	color_button.disabled = camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size()
	_style_button(color_button, false)
	color_button.pressed.connect(_show_camera_back_design_color_controls)
	top_controls.add_child(color_button)

	var research_button := Button.new()
	research_button.name = "CameraBackDesignResearchButton"
	research_button.text = "RESEARCH" if camera_back_design_research_level < MAX_CAMERA_BACK_DESIGN_BOXES else "MAX 20"
	research_button.custom_minimum_size = Vector2(0, 36 if tight else 39)
	research_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_button.focus_mode = Control.FOCUS_NONE
	research_button.disabled = camera_back_design_research_level >= MAX_CAMERA_BACK_DESIGN_BOXES
	research_button.tooltip_text = "Research to unlock more raised boxes, up to 20." if not research_button.disabled else "Maximum of 20 raised boxes unlocked."
	_style_button(research_button, false)
	research_button.pressed.connect(_request_camera_back_raised_design_research)
	top_controls.add_child(research_button)

	camera_back_design_selection_button = Button.new()
	camera_back_design_selection_button.name = "CameraBackDesignBoxSelector"
	camera_back_design_selection_button.text = "CHOOSE RAISED BOX  ▼"
	camera_back_design_selection_button.custom_minimum_size = Vector2(0, control_height)
	camera_back_design_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_back_design_selection_button.focus_mode = Control.FOCUS_NONE
	_style_button(camera_back_design_selection_button, true)
	camera_back_design_selection_button.pressed.connect(_show_camera_back_design_selection_controls)
	panel.add_child(camera_back_design_selection_button)

	camera_back_design_capacity_label = _label("RAISED BOXES  0 / %d" % camera_back_design_research_level, 10, Color("#B8AFA2"), HORIZONTAL_ALIGNMENT_CENTER)
	camera_back_design_capacity_label.name = "CameraBackDesignCapacityLabel"
	panel.add_child(camera_back_design_capacity_label)

	var rounding_section := VBoxContainer.new()
	rounding_section.name = "CameraBackDesignRoundingSection"
	rounding_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounding_section.add_theme_constant_override("separation", 3)
	panel.add_child(rounding_section)
	var rounding_header := HBoxContainer.new()
	rounding_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rounding_section.add_child(rounding_header)
	rounding_header.add_child(_label("ROUND", 10, Color("#B8AFA2")))
	camera_back_design_rounding_label = _label("NO BOX SELECTED", 10, Color("#E5E0D6"))
	camera_back_design_rounding_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_back_design_rounding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounding_header.add_child(camera_back_design_rounding_label)

	camera_back_design_rounding_slider = HSlider.new()
	camera_back_design_rounding_slider.name = "CameraBackDesignHorizontalRoundingSlider"
	camera_back_design_rounding_slider.min_value = 0.0
	camera_back_design_rounding_slider.max_value = 0.45
	camera_back_design_rounding_slider.step = 0.01
	camera_back_design_rounding_slider.custom_minimum_size = Vector2(0, 24)
	camera_back_design_rounding_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_back_design_rounding_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_rear_hardware_slider(camera_back_design_rounding_slider)
	camera_back_design_rounding_slider.value_changed.connect(_on_camera_back_design_rounding_changed)
	rounding_section.add_child(camera_back_design_rounding_slider)

	camera_back_design_size_label = _label("ADD A BOX TO BEGIN", 10, Color("#E5E0D6"), HORIZONTAL_ALIGNMENT_CENTER)
	camera_back_design_size_label.name = "CameraBackDesignSizeLabel"
	camera_back_design_size_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(camera_back_design_size_label)

	var pad_control_row := HBoxContainer.new()
	pad_control_row.name = "CameraBackDesignPadWithManagement"
	pad_control_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_control_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_theme_constant_override("separation", 10 if tight else 14)
	panel.add_child(pad_control_row)

	var icon_diameter := 56.0 if tight else 64.0
	_make_rear_hardware_icon_button(
		pad_control_row, "CameraBackDesignAddButton", "+", "Add raised box",
		Callable(self, "_add_camera_back_design_box"), icon_diameter, true
	)

	var pad_center := CenterContainer.new()
	pad_center.name = "CameraBackDesignDirectionControllerCenter"
	pad_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pad_control_row.add_child(pad_center)
	var pad_shell := PanelContainer.new()
	pad_shell.name = "CameraBackDesignDirectionController"
	pad_shell.custom_minimum_size = Vector2(204, 204) if not tight else Vector2(184, 184)
	var pad_style := StyleBoxFlat.new()
	pad_style.bg_color = Color(0.12, 0.13, 0.14, 0.72)
	pad_style.border_color = Color(0.58, 0.46, 0.29, 0.72)
	pad_style.set_border_width_all(1)
	pad_style.set_corner_radius_all(16)
	pad_style.content_margin_left = 8
	pad_style.content_margin_right = 8
	pad_style.content_margin_top = 8
	pad_style.content_margin_bottom = 8
	pad_shell.add_theme_stylebox_override("panel", pad_style)
	pad_center.add_child(pad_shell)

	var pad := GridContainer.new()
	pad.name = "CameraBackDesignDirectionPad"
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 18 if not tight else 16)
	pad.add_theme_constant_override("v_separation", 6)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad_shell.add_child(pad)
	_add_camera_back_design_pad_spacer(pad, tight)
	_add_camera_back_design_pad_button(pad, "↑", Vector2i(0, 1), tight)
	_add_camera_back_design_pad_spacer(pad, tight)
	_add_camera_back_design_pad_button(pad, "←", Vector2i(-1, 0), tight)
	var action_button := Button.new()
	action_button.name = "CameraBackDesignSizeActionButton"
	action_button.text = ("EXPAND" if camera_back_design_size_action == "EXPAND" else "SHRINK") if camera_back_design_mode == "SIZE" else "MOVE"
	action_button.custom_minimum_size = Vector2(76, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_button.focus_mode = Control.FOCUS_NONE
	_style_button(action_button, true)
	action_button.pressed.connect(_toggle_camera_back_design_size_action if camera_back_design_mode == "SIZE" else _set_camera_back_design_mode.bind("MOVE"))
	pad.add_child(action_button)
	_add_camera_back_design_pad_button(pad, "→", Vector2i(1, 0), tight)
	_add_camera_back_design_pad_spacer(pad, tight)
	_add_camera_back_design_pad_button(pad, "↓", Vector2i(0, -1), tight)
	_add_camera_back_design_pad_spacer(pad, tight)

	_make_rear_hardware_icon_button(
		pad_control_row, "CameraBackDesignRemoveButton", "−", "Remove selected box",
		Callable(self, "_remove_selected_camera_back_design_box"), icon_diameter, false
	)
	_refresh_camera_back_design_panel()
	return panel


func _request_camera_back_raised_design_research() -> void:
	if camera_back_design_research_level >= MAX_CAMERA_BACK_DESIGN_BOXES:
		return
	research_requested.emit()


func _set_camera_back_design_mode(mode: String) -> void:
	if mode not in ["SIZE", "MOVE"]:
		return
	camera_back_design_mode = mode
	_show_camera_back_design_controls()


func _toggle_camera_back_design_size_action() -> void:
	camera_back_design_size_action = "SHRINK" if camera_back_design_size_action == "EXPAND" else "EXPAND"
	_show_camera_back_design_controls()


func _get_camera_back_design_addition_limit() -> int:
	return clampi(camera_back_design_research_level, 0, MAX_CAMERA_BACK_DESIGN_BOXES)


func _add_camera_back_design_box() -> void:
	var addition_limit := _get_camera_back_design_addition_limit()
	if addition_limit <= 0 or camera_back_design_boxes.size() >= addition_limit or camera_back_design_boxes.size() >= MAX_CAMERA_BACK_DESIGN_BOXES:
		_refresh_camera_back_design_panel()
		return
	var box_size := Vector2(0.34, 0.34)
	var half := box_size * 0.5
	var body_half := Vector2(1.45, 2.92) * 0.5
	var min_x := -body_half.x + half.x
	var max_x := body_half.x - half.x
	var min_y := -body_half.y + half.y
	var max_y := body_half.y - half.y
	var placed := false
	# Place the first raised section centrally so the directional pad has
	# usable movement space in every direction while viewing the handset rear.
	var preferred_position := Vector2.ZERO
	if _camera_back_design_position_is_free(preferred_position, box_size, -1):
		camera_back_design_boxes.append({
			"id": next_camera_back_design_id,
			"position": preferred_position,
			"size": box_size,
			"border": 0.08,
			"custom_color": camera_back_design_color,
			"gradient_color": Color("#536dfe"),
			"gradient_enabled": false,
			"gradient_direction": 0,
			"use_device_color": false
		})
		camera_back_design_selected_index = camera_back_design_boxes.size() - 1
		next_camera_back_design_id += 1
		placed = true
	var y := max_y
	while y >= min_y and not placed:
		var x := min_x
		while x <= max_x and not placed:
			var candidate := Vector2(x, y)
			if _camera_back_design_position_is_free(candidate, box_size, -1):
				camera_back_design_boxes.append({
					"id": next_camera_back_design_id,
					"position": candidate,
					"size": box_size,
					"border": 0.08,
					"custom_color": camera_back_design_color,
					"gradient_color": Color("#536dfe"),
					"gradient_enabled": false,
					"gradient_direction": 0,
					"use_device_color": false
				})
				camera_back_design_selected_index = camera_back_design_boxes.size() - 1
				next_camera_back_design_id += 1
				placed = true
			x += CAMERA_BACK_DESIGN_GRID_STEP
		y -= CAMERA_BACK_DESIGN_GRID_STEP
	if placed:
		_refresh_camera_back_design_visuals()
		_show_camera_back_design_controls()


func _remove_selected_camera_back_design_box() -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	camera_back_design_boxes.remove_at(camera_back_design_selected_index)
	camera_back_design_selected_index = mini(camera_back_design_selected_index, camera_back_design_boxes.size() - 1)
	_refresh_camera_back_design_visuals()
	_show_camera_back_design_controls()


func _show_camera_back_design_selection_controls() -> void:
	if camera_back_design_boxes.is_empty() or not is_instance_valid(rear_hardware_step_content):
		return
	if is_instance_valid(camera_back_design_view):
		camera_back_design_view.visible = false
	if is_instance_valid(camera_back_design_selection_view):
		camera_back_design_selection_view.queue_free()
		camera_back_design_selection_view = null
	camera_back_design_selection_view = VBoxContainer.new()
	camera_back_design_selection_view.name = "CameraBackDesignBoxSelection"
	camera_back_design_selection_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camera_back_design_selection_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	camera_back_design_selection_view.add_theme_constant_override("separation", 9)
	rear_hardware_step_content.add_child(camera_back_design_selection_view)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	camera_back_design_selection_view.add_child(header)
	var back := Button.new()
	back.name = "CameraBackDesignSelectionBackButton"
	back.text = "‹"
	back.custom_minimum_size = Vector2(36, 34)
	back.focus_mode = Control.FOCUS_NONE
	_style_button(back, false)
	back.pressed.connect(_show_camera_back_design_controls)
	header.add_child(back)
	var title := _label("SELECT RAISED BOX", 15, Color("#E5E0D6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var list := GridContainer.new()
	list.name = "CameraBackDesignBoxOptions"
	list.columns = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("h_separation", 7)
	list.add_theme_constant_override("v_separation", 7)
	camera_back_design_selection_view.add_child(list)
	for index in range(camera_back_design_boxes.size()):
		var box: Dictionary = camera_back_design_boxes[index]
		var option := Button.new()
		option.name = "CameraBackDesignBoxOption%d" % index
		option.text = "RAISED BOX  %02d%s" % [int(box["id"]), "   ✓ SELECTED" if index == camera_back_design_selected_index else ""]
		option.custom_minimum_size.y = 48
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.focus_mode = Control.FOCUS_NONE
		_style_button(option, index == camera_back_design_selected_index)
		option.pressed.connect(_select_camera_back_design_box.bind(index))
		list.add_child(option)


func _select_camera_back_design_box(index: int) -> void:
	if index < 0 or index >= camera_back_design_boxes.size():
		return
	camera_back_design_selected_index = index
	_refresh_camera_back_design_visuals()
	_show_camera_back_design_controls()


func _show_camera_back_design_color_controls() -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	if is_instance_valid(camera_back_design_view):
		camera_back_design_view.visible = false
	if is_instance_valid(camera_back_design_selection_view):
		camera_back_design_selection_view.queue_free()
		camera_back_design_selection_view = null

	var selected: Dictionary = camera_back_design_boxes[camera_back_design_selected_index]
	var gradient_enabled := bool(selected.get("gradient_enabled", false))
	var color_view := VBoxContainer.new()
	color_view.name = "CameraBackDesignColorControls"
	color_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	color_view.add_theme_constant_override("separation", 8)
	camera_back_design_selection_view = color_view
	rear_hardware_step_content.add_child(color_view)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	color_view.add_child(header)
	var back := Button.new()
	back.name = "CameraBackDesignColorBackButton"
	back.text = "‹"
	back.custom_minimum_size = Vector2(36, 34)
	back.focus_mode = Control.FOCUS_NONE
	_style_button(back, false)
	back.pressed.connect(_show_camera_back_design_controls)
	header.add_child(back)
	var title := _label("BACK DESIGN COLOR", 15, Color("#E5E0D6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var use_device_color_row := HBoxContainer.new()
	use_device_color_row.name = "CameraBackDesignUseDeviceColorRow"
	use_device_color_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use_device_color_row.add_theme_constant_override("separation", 6)
	color_view.add_child(use_device_color_row)
	var use_device_color_label := _label("USE DEVICE COLOR", 12, Color("#D3AA6B"))
	use_device_color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use_device_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	use_device_color_row.add_child(use_device_color_label)
	var use_device_color_toggle := Button.new()
	use_device_color_toggle.name = "CameraBackDesignUseDeviceColor"
	use_device_color_toggle.text = "ON" if bool(selected.get("use_device_color", false)) else "OFF"
	use_device_color_toggle.toggle_mode = true
	use_device_color_toggle.button_pressed = bool(selected.get("use_device_color", false))
	use_device_color_toggle.custom_minimum_size = Vector2(64, 36)
	use_device_color_toggle.focus_mode = Control.FOCUS_NONE
	_style_button(use_device_color_toggle, use_device_color_toggle.button_pressed)
	use_device_color_toggle.toggled.connect(_on_camera_back_design_use_device_color_toggled)
	use_device_color_row.add_child(use_device_color_toggle)

	var gradient_toggle_row := HBoxContainer.new()
	gradient_toggle_row.name = "CameraBackDesignGradientToggleRow"
	gradient_toggle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_toggle_row.add_theme_constant_override("separation", 6)
	color_view.add_child(gradient_toggle_row)
	var gradient_toggle_label := _label("ENABLE GRADIENT", 12, Color("#D3AA6B"))
	gradient_toggle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gradient_toggle_row.add_child(gradient_toggle_label)
	var gradient_toggle := Button.new()
	gradient_toggle.name = "CameraBackDesignGradientToggle"
	gradient_toggle.text = "ON" if gradient_enabled else "OFF"
	gradient_toggle.toggle_mode = true
	gradient_toggle.button_pressed = gradient_enabled
	gradient_toggle.custom_minimum_size = Vector2(64, 36)
	gradient_toggle.focus_mode = Control.FOCUS_NONE
	gradient_toggle.disabled = bool(selected.get("use_device_color", false))
	_style_button(gradient_toggle, gradient_enabled)
	gradient_toggle.toggled.connect(_on_camera_back_design_gradient_toggled)
	gradient_toggle_row.add_child(gradient_toggle)

	var direction_button := Button.new()
	direction_button.name = "CameraBackDesignGradientDirectionButton"
	direction_button.text = "GRADIENT DIRECTION  ·  " + _camera_back_design_gradient_direction_name(int(selected.get("gradient_direction", 0)))
	direction_button.custom_minimum_size.y = 40
	direction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direction_button.focus_mode = Control.FOCUS_NONE
	direction_button.visible = gradient_enabled and not bool(selected.get("use_device_color", false))
	_style_button(direction_button, false)
	direction_button.pressed.connect(_show_camera_back_design_gradient_direction_controls)
	color_view.add_child(direction_button)

	var color_columns := HBoxContainer.new()
	color_columns.name = "CameraBackDesignColorPickers"
	color_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_columns.add_theme_constant_override("separation", 10)
	color_view.add_child(color_columns)

	var normal_column := VBoxContainer.new()
	normal_column.name = "CameraBackDesignNormalColorColumn"
	normal_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	normal_column.add_theme_constant_override("separation", 5)
	color_columns.add_child(normal_column)
	var normal_heading := _label("NORMAL", 12, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	normal_column.add_child(normal_heading)
	var normal_picker := ColorPickerButton.new()
	normal_picker.name = "CameraBackDesignNormalColorPicker"
	normal_picker.color = Color(selected.get("custom_color", camera_back_design_color))
	normal_picker.edit_alpha = false
	normal_picker.disabled = bool(selected.get("use_device_color", false))
	normal_picker.custom_minimum_size = Vector2(0, 48)
	normal_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	normal_picker.color_changed.connect(_on_camera_back_design_color_changed.bind(false))
	normal_column.add_child(normal_picker)

	var gradient_column := VBoxContainer.new()
	gradient_column.name = "CameraBackDesignGradientColorColumn"
	gradient_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_column.add_theme_constant_override("separation", 5)
	color_columns.add_child(gradient_column)
	var gradient_heading := _label("GRADIENT", 12, Color("#D3AA6B"), HORIZONTAL_ALIGNMENT_CENTER)
	gradient_column.add_child(gradient_heading)
	var gradient_picker := ColorPickerButton.new()
	gradient_picker.name = "CameraBackDesignGradientColorPicker"
	gradient_picker.color = Color(selected.get("gradient_color", Color("#536dfe")))
	gradient_picker.edit_alpha = false
	gradient_picker.custom_minimum_size = Vector2(0, 48)
	gradient_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient_picker.disabled = not gradient_enabled or bool(selected.get("use_device_color", false))
	gradient_picker.color_changed.connect(_on_camera_back_design_color_changed.bind(true))
	gradient_column.add_child(gradient_picker)


func _on_camera_back_design_use_device_color_toggled(enabled: bool) -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	camera_back_design_boxes[camera_back_design_selected_index]["use_device_color"] = enabled
	_refresh_camera_back_design_visuals()
	_show_camera_back_design_color_controls()


func _on_camera_back_design_gradient_toggled(enabled: bool) -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	if bool(camera_back_design_boxes[camera_back_design_selected_index].get("use_device_color", false)):
		return
	camera_back_design_boxes[camera_back_design_selected_index]["gradient_enabled"] = enabled
	_refresh_camera_back_design_visuals()
	var direction_button := camera_back_design_selection_view.find_child("CameraBackDesignGradientDirectionButton", true, false) as Button if is_instance_valid(camera_back_design_selection_view) else null
	var gradient_picker := camera_back_design_selection_view.find_child("CameraBackDesignGradientColorPicker", true, false) as ColorPickerButton if is_instance_valid(camera_back_design_selection_view) else null
	var toggle := camera_back_design_selection_view.find_child("CameraBackDesignGradientToggle", true, false) as Button if is_instance_valid(camera_back_design_selection_view) else null
	var use_device_color := bool(camera_back_design_boxes[camera_back_design_selected_index].get("use_device_color", false))
	if is_instance_valid(direction_button):
		direction_button.visible = enabled and not use_device_color
	if is_instance_valid(gradient_picker):
		gradient_picker.disabled = not enabled or use_device_color
	if is_instance_valid(toggle):
		toggle.text = "ON" if enabled else "OFF"
		_style_button(toggle, enabled)


func _on_camera_back_design_color_changed(color: Color, use_gradient_color: bool = false) -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	if use_gradient_color:
		camera_back_design_boxes[camera_back_design_selected_index]["gradient_color"] = color
	else:
		camera_back_design_boxes[camera_back_design_selected_index]["custom_color"] = color
		camera_back_design_color = color
	_refresh_camera_back_design_visuals()


func _camera_back_design_gradient_direction_name(index: int) -> String:
	var names := ["VERTICAL", "HORIZONTAL", "DIAGONAL", "RADIAL"]
	return names[clampi(index, 0, names.size() - 1)]


func _show_camera_back_design_gradient_direction_controls() -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	if is_instance_valid(camera_back_design_selection_view):
		camera_back_design_selection_view.queue_free()
		camera_back_design_selection_view = null
	var direction_view := VBoxContainer.new()
	direction_view.name = "CameraBackDesignGradientDirectionControls"
	direction_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direction_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	direction_view.add_theme_constant_override("separation", 10)
	camera_back_design_selection_view = direction_view
	rear_hardware_step_content.add_child(direction_view)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	direction_view.add_child(header)
	var back := Button.new()
	back.name = "CameraBackDesignGradientDirectionBackButton"
	back.text = "‹"
	back.custom_minimum_size = Vector2(36, 34)
	back.focus_mode = Control.FOCUS_NONE
	_style_button(back, false)
	back.pressed.connect(_show_camera_back_design_color_controls)
	header.add_child(back)
	var title := _label("GRADIENT DIRECTION", 15, Color("#E5E0D6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var options := GridContainer.new()
	options.name = "CameraBackDesignGradientDirectionOptions"
	options.columns = 2
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("h_separation", 8)
	options.add_theme_constant_override("v_separation", 8)
	direction_view.add_child(options)
	var selected_direction := int(camera_back_design_boxes[camera_back_design_selected_index].get("gradient_direction", 0))
	for index in range(4):
		var option := Button.new()
		option.name = "CameraBackDesignGradientDirectionOption%d" % index
		option.text = _camera_back_design_gradient_direction_name(index) + ("  ✓" if index == selected_direction else "")
		option.custom_minimum_size = Vector2(0, 54)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.focus_mode = Control.FOCUS_NONE
		_style_button(option, index == selected_direction)
		option.pressed.connect(_select_camera_back_design_gradient_direction.bind(index))
		options.add_child(option)


func _select_camera_back_design_gradient_direction(index: int) -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	camera_back_design_boxes[camera_back_design_selected_index]["gradient_direction"] = clampi(index, 0, 3)
	_refresh_camera_back_design_visuals()
	_show_camera_back_design_color_controls()


func _camera_back_design_position_is_free(candidate_position: Vector2, box_size: Vector2, ignore_index: int) -> bool:
	var half := box_size * 0.5
	var body_half := Vector2(1.45, 2.92) * 0.5
	if absf(candidate_position.x) + half.x > body_half.x:
		return false
	if absf(candidate_position.y) + half.y > body_half.y:
		return false
	for index in range(camera_back_design_boxes.size()):
		if index == ignore_index:
			continue
		var other: Dictionary = camera_back_design_boxes[index]
		var other_half: Vector2 = other["size"] * 0.5
		var other_position: Vector2 = other["position"]
		if absf(candidate_position.x - other_position.x) < half.x + other_half.x and absf(candidate_position.y - other_position.y) < half.y + other_half.y:
			return false
	return true


func _on_camera_back_design_pad_pressed(direction: Vector2i) -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	if not is_instance_valid(phone_model) or not is_instance_valid(preview_camera):
		return
	var box: Dictionary = camera_back_design_boxes[camera_back_design_selected_index]
	var box_position: Vector2 = box["position"]
	var box_size: Vector2 = box["size"]
	var inverse_basis := phone_model.global_transform.basis.inverse()
	var camera_right_local := inverse_basis * preview_camera.global_transform.basis.x
	var camera_up_local := inverse_basis * preview_camera.global_transform.basis.y
	var local_direction_3d := camera_right_local * float(direction.x) + camera_up_local * float(direction.y)
	var local_direction := Vector2(local_direction_3d.x, local_direction_3d.y)
	if local_direction.length_squared() < 0.000001:
		return
	local_direction = local_direction.normalized()
	if camera_back_design_mode == "MOVE":
		local_direction = Vector2(signf(local_direction.x), 0.0) if absf(local_direction.x) >= absf(local_direction.y) else Vector2(0.0, signf(local_direction.y))
		var next_position := box_position + local_direction * 0.04
		if _camera_back_design_position_is_free(next_position, box_size, camera_back_design_selected_index):
			box["position"] = next_position
	else:
		var half := box_size * 0.5
		var next_position := box_position
		var next_half := half
		var step := 0.025 if camera_back_design_size_action == "EXPAND" else -0.025
		local_direction = Vector2(signf(local_direction.x), 0.0) if absf(local_direction.x) >= absf(local_direction.y) else Vector2(0.0, signf(local_direction.y))
		if local_direction.x < 0.0:
			next_position.x -= step * 0.5
			next_half.x += step * 0.5
		elif local_direction.x > 0.0:
			next_position.x += step * 0.5
			next_half.x += step * 0.5
		elif local_direction.y > 0.0:
			next_position.y += step * 0.5
			next_half.y += step * 0.5
		elif local_direction.y < 0.0:
			next_position.y -= step * 0.5
			next_half.y += step * 0.5
		var next_size := next_half * 2.0
		if next_size.x > 0.001 and next_size.y > 0.001 and _camera_back_design_position_is_free(next_position, next_size, camera_back_design_selected_index):
			box["position"] = next_position
			box["size"] = next_size
	camera_back_design_boxes[camera_back_design_selected_index] = box
	_refresh_camera_back_design_visuals()
	_refresh_camera_back_design_panel()


func _on_camera_back_design_rounding_changed(value: float) -> void:
	if camera_back_design_selected_index < 0 or camera_back_design_selected_index >= camera_back_design_boxes.size():
		return
	camera_back_design_boxes[camera_back_design_selected_index]["border"] = value
	_refresh_camera_back_design_visuals()
	if is_instance_valid(camera_back_design_rounding_label):
		camera_back_design_rounding_label.text = "ROUNDING  %.0f%%" % (value / 0.45 * 100.0)


func _refresh_camera_back_design_panel() -> void:
	if not is_instance_valid(camera_back_design_view):
		return
	var add_button := camera_back_design_view.find_child("CameraBackDesignAddButton", true, false) as Button
	var remove_button := camera_back_design_view.find_child("CameraBackDesignRemoveButton", true, false) as Button
	var color_button := camera_back_design_view.find_child("CameraBackDesignColorButton", true, false) as Button
	var research_button := camera_back_design_view.find_child("CameraBackDesignResearchButton", true, false) as Button
	var addition_limit := _get_camera_back_design_addition_limit()
	if is_instance_valid(add_button):
		add_button.disabled = addition_limit <= 0 or camera_back_design_boxes.size() >= addition_limit
	if is_instance_valid(research_button):
		research_button.disabled = addition_limit >= MAX_CAMERA_BACK_DESIGN_BOXES
		research_button.text = "RESEARCH" if not research_button.disabled else "MAX 20"
	if is_instance_valid(camera_back_design_capacity_label):
		camera_back_design_capacity_label.text = "RAISED BOXES  %d / %d" % [camera_back_design_boxes.size(), addition_limit]
	var has_box := camera_back_design_selected_index >= 0 and camera_back_design_selected_index < camera_back_design_boxes.size()
	if is_instance_valid(camera_back_design_selection_button):
		camera_back_design_selection_button.disabled = not has_box and camera_back_design_boxes.is_empty()
		camera_back_design_selection_button.text = "ADD A BOX TO SELECT" if not has_box else "RAISED BOX  %02d  ›" % int(camera_back_design_boxes[camera_back_design_selected_index]["id"])
	if is_instance_valid(remove_button):
		remove_button.disabled = not has_box
	if is_instance_valid(color_button):
		color_button.disabled = not has_box
	if is_instance_valid(camera_back_design_rounding_slider):
		camera_back_design_rounding_slider.editable = has_box
	for move_button in camera_back_design_move_buttons:
		move_button.disabled = not has_box
	if has_box:
		var selected: Dictionary = camera_back_design_boxes[camera_back_design_selected_index]
		var size: Vector2 = selected["size"]
		camera_back_design_size_label.text = "SIZE  %.2f × %.2f" % [size.x, size.y]
		camera_back_design_rounding_slider.set_value_no_signal(float(selected["border"]))
		camera_back_design_rounding_label.text = "ROUNDING  %.0f%%" % (float(selected["border"]) / 0.45 * 100.0)
	else:
		camera_back_design_size_label.text = "ADD A BOX TO BEGIN"
		camera_back_design_rounding_slider.set_value_no_signal(0.0)
		camera_back_design_rounding_label.text = "NO BOX SELECTED"


func _add_camera_back_design_pad_spacer(parent: GridContainer, tight: bool) -> void:
	var diameter := 64.0 if tight else 72.0
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(diameter, diameter)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _add_camera_back_design_pad_button(parent: GridContainer, caption: String, direction: Vector2i, tight: bool) -> void:
	var diameter := 64.0 if tight else 72.0
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	_style_rear_hardware_circle_button(button, true, diameter)
	button.pressed.connect(_on_camera_back_design_pad_pressed.bind(direction))
	parent.add_child(button)
	camera_back_design_move_buttons.append(button)


func _make_camera_back_design_mesh(box_size: Vector2, corner_radius: float, depth: float) -> ArrayMesh:
	var outline := PackedVector2Array()
	var radius := clampf(corner_radius, 0.001, minf(box_size.x, box_size.y) * 0.48)
	var centers := [
		Vector2(box_size.x * 0.5 - radius, box_size.y * 0.5 - radius),
		Vector2(-box_size.x * 0.5 + radius, box_size.y * 0.5 - radius),
		Vector2(-box_size.x * 0.5 + radius, -box_size.y * 0.5 + radius),
		Vector2(box_size.x * 0.5 - radius, -box_size.y * 0.5 + radius)
	]
	for corner in range(4):
		for segment in range(5):
			var angle := float(corner) * PI * 0.5 + float(segment) / 4.0 * PI * 0.5
			outline.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	var indices := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer_z := -depth
	for index in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var c: Vector2 = outline[indices[index + 2]]
		_add_camera_design_mesh_triangle(surface, Vector3(a.x, a.y, outer_z), Vector3(b.x, b.y, outer_z), Vector3(c.x, c.y, outer_z), Vector3(0, 0, -1))
		_add_camera_design_mesh_triangle(surface, Vector3(a.x, a.y, 0), Vector3(c.x, c.y, 0), Vector3(b.x, b.y, 0), Vector3(0, 0, 1))
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[next]
		var normal := Vector3((b - a).y, -(b - a).x, 0).normalized()
		var fa := Vector3(a.x, a.y, outer_z)
		var fb := Vector3(b.x, b.y, outer_z)
		var ba := Vector3(a.x, a.y, 0)
		var bb := Vector3(b.x, b.y, 0)
		_add_camera_design_mesh_triangle(surface, fa, ba, bb, normal)
		_add_camera_design_mesh_triangle(surface, fa, bb, fb, normal)
	return surface.commit()


func _add_camera_design_mesh_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward_normal: Vector3) -> void:
	var normal := outward_normal.normalized()
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.set_normal(normal)
	surface.add_vertex(b)
	surface.set_normal(normal)
	surface.add_vertex(c)


func _create_camera_back_design_material(box: Dictionary, box_size: Vector2, selected: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 solid_color : source_color = vec4(0.65, 0.68, 0.71, 1.0);
uniform vec4 gradient_color : source_color = vec4(0.325, 0.427, 0.996, 1.0);
uniform bool gradient_enabled = false;
uniform int gradient_direction : hint_range(0, 3) = 0;
uniform vec2 box_size = vec2(0.8, 0.8);
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	if (local_normal.z > 0.5 || !gradient_enabled) {
		ALBEDO = solid_color.rgb;
	} else {
		vec2 p = local_position.xy / max(box_size, vec2(0.001)) + vec2(0.5);
		float t = p.y;
		if (gradient_direction == 1) {
			t = p.x;
		} else if (gradient_direction == 2) {
			t = clamp((p.x + p.y) * 0.5, 0.0, 1.0);
		} else if (gradient_direction == 3) {
			t = clamp(length((p - vec2(0.5)) * vec2(1.0, 1.8)) * 1.4142, 0.0, 1.0);
		}
		ALBEDO = mix(solid_color.rgb, gradient_color.rgb, clamp(t, 0.0, 1.0));
	}
	METALLIC = 0.34;
	ROUGHNESS = 0.48;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var uses_device_color := bool(box.get("use_device_color", false))
	var base_color := _get_camera_back_design_device_color() if uses_device_color else Color(box.get("custom_color", camera_back_design_color))
	base_color = base_color.lightened(0.045) if selected else base_color.darkened(0.10)
	material.set_shader_parameter("solid_color", base_color)
	material.set_shader_parameter("gradient_color", Color(box.get("gradient_color", Color("#536dfe"))))
	material.set_shader_parameter("gradient_enabled", bool(box.get("gradient_enabled", false)) and not uses_device_color)
	material.set_shader_parameter("gradient_direction", int(box.get("gradient_direction", 0)))
	material.set_shader_parameter("box_size", box_size)
	return material


func _get_camera_back_design_device_color() -> Color:
	if not is_instance_valid(phone_model):
		return camera_back_design_color
	var chassis := phone_model.get_node_or_null("PhoneChassis") as MeshInstance3D
	if not is_instance_valid(chassis):
		return camera_back_design_color
	var chassis_material := chassis.material_override as StandardMaterial3D
	return chassis_material.albedo_color if is_instance_valid(chassis_material) else camera_back_design_color


func _refresh_camera_back_design_visuals() -> void:
	if not is_instance_valid(phone_model):
		return
	var old_root := phone_model.get_node_or_null("CameraBackDesignRaisedSections")
	if is_instance_valid(old_root):
		old_root.free()
	if not camera_back_design_boxes.is_empty():
		var root := Node3D.new()
		root.name = "CameraBackDesignRaisedSections"
		phone_model.add_child(root)
		var surface_z := -CAMERA_WORKSITE_PHONE_DEPTH * 0.5
		for index in range(camera_back_design_boxes.size()):
			var box: Dictionary = camera_back_design_boxes[index]
			var size: Vector2 = box["size"]
			var raised := MeshInstance3D.new()
			raised.name = "CameraRaisedBackBox_%d" % int(box["id"])
			raised.mesh = _make_camera_back_design_mesh(size, minf(size.x, size.y) * float(box["border"]), CAMERA_BACK_DESIGN_BOX_DEPTH)
			raised.material_override = _create_camera_back_design_material(box, size, index == camera_back_design_selected_index)
			raised.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var box_center: Vector2 = box["position"]
			raised.position = Vector3(box_center.x, box_center.y, surface_z)
			root.add_child(raised)
	_refresh_rear_hardware_visuals()


func _camera_back_design_surface_z(module_position: Vector2) -> float:
	var surface_z := -CAMERA_WORKSITE_PHONE_DEPTH * 0.5
	for box in camera_back_design_boxes:
		var centre: Vector2 = box["position"]
		var half: Vector2 = box["size"] * 0.5
		if absf(module_position.x - centre.x) <= half.x and absf(module_position.y - centre.y) <= half.y:
			return surface_z - CAMERA_BACK_DESIGN_BOX_DEPTH
	return surface_z



func _make_rear_hardware_icon_button(parent: Control, node_name: String, caption: String, tooltip: String, pressed_callback: Callable, diameter: float, active: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	_apply_shared_page_typography(button, 29 if diameter >= 52.0 else 27)
	_style_rear_hardware_circle_button(button, active, diameter)
	button.pressed.connect(pressed_callback)
	parent.add_child(button)
	return button


func _style_rear_hardware_circle_button(button: Button, active: bool, diameter: float) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.27, 0.18, 0.09, 0.90) if active else Color(0.12, 0.13, 0.14, 0.82)
		if state == "hover":
			style.bg_color = Color(0.38, 0.25, 0.12, 0.94) if active else Color(0.21, 0.22, 0.23, 0.88)
		elif state == "pressed":
			style.bg_color = Color(0.17, 0.11, 0.06, 0.98) if active else Color(0.08, 0.09, 0.10, 0.94)
		elif state == "disabled":
			style.bg_color = Color(0.10, 0.11, 0.12, 0.58)
		style.border_color = Color(0.80, 0.60, 0.32, 0.78) if active else Color(0.72, 0.72, 0.68, 0.34)
		style.set_border_width_all(1)
		style.set_corner_radius_all(int(diameter * 0.5))
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 2)
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#A9A092"))


func _style_rear_hardware_slider(slider: Slider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#26292B")
	track.border_color = Color("#C58A3A")
	track.set_border_width_all(2)
	track.set_corner_radius_all(12)
	track.content_margin_left = 6
	track.content_margin_right = 6
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)

	var gradient := Gradient.new()
	gradient.set_color(0, Color("#ffffff"))
	gradient.set_color(1, Color("#C58A3A"))
	var grabber := GradientTexture2D.new()
	grabber.gradient = gradient
	grabber.width = 32
	grabber.height = 32
	grabber.fill_from = Vector2.ZERO
	grabber.fill_to = Vector2.ONE
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_filter = Control.MOUSE_FILTER_STOP


func _add_rear_hardware_pad_spacer(parent: GridContainer, tight: bool) -> void:
	var diameter := 64.0 if tight else 72.0
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(diameter, diameter)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _add_rear_hardware_pad_button(parent: GridContainer, caption: String, direction: Vector2i, tight: bool) -> void:
	var diameter := 64.0 if tight else 72.0
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_shared_page_typography(button, 27 if tight else 29)
	button.focus_mode = Control.FOCUS_NONE
	_style_rear_hardware_circle_button(button, true, diameter)
	button.pressed.connect(_on_rear_hardware_pad_pressed.bind(direction))
	parent.add_child(button)
	rear_hardware_move_buttons.append(button)


func _set_rear_hardware_mode(mode: String) -> void:
	if mode not in ["CAMERA", "FLASH"]:
		return
	rear_hardware_mode = mode
	_show_rear_camera_controls()


func _get_rear_hardware_modules() -> Array[Dictionary]:
	return rear_flash_modules if rear_hardware_mode == "FLASH" else rear_camera_modules


func _get_rear_hardware_selected_index() -> int:
	return rear_flash_selected_index if rear_hardware_mode == "FLASH" else rear_camera_selected_index


func _set_rear_hardware_selected_index(index: int) -> void:
	if rear_hardware_mode == "FLASH":
		rear_flash_selected_index = index
	else:
		rear_camera_selected_index = index


func _get_rear_hardware_addition_limit() -> int:
	return MAX_REAR_FLASHES if rear_hardware_mode == "FLASH" else MAX_REAR_CAMERAS


func _add_rear_hardware_module() -> void:
	var modules := _get_rear_hardware_modules()
	if modules.size() >= _get_rear_hardware_addition_limit():
		_refresh_rear_hardware_panel()
		return
	var module_size := REAR_HARDWARE_SIZE_MIN
	if not modules.is_empty():
		module_size = float(modules[modules.size() - 1].get("size", module_size))
	var spawn_position := _find_rear_hardware_spawn_position(rear_hardware_mode, module_size)
	if spawn_position.x > 900.0:
		return
	if rear_hardware_mode == "FLASH":
		rear_flash_modules.append({"id": next_rear_flash_id, "position": spawn_position, "size": module_size})
		rear_flash_selected_index = rear_flash_modules.size() - 1
		next_rear_flash_id += 1
	else:
		rear_camera_modules.append({
			"id": next_rear_camera_id,
			"position": spawn_position,
			"size": module_size,
			"mp": ResearchManagerScript.REAR_CAMERA_MP_BASE
		})
		rear_camera_selected_index = rear_camera_modules.size() - 1
		next_rear_camera_id += 1
	_refresh_rear_hardware_panel()
	_refresh_rear_camera_mp_controls()


func _remove_rear_hardware_module() -> void:
	var selected_index := _get_rear_hardware_selected_index()
	var modules := _get_rear_hardware_modules()
	if selected_index < 0 or selected_index >= modules.size():
		return
	modules.remove_at(selected_index)
	_set_rear_hardware_selected_index(mini(selected_index, modules.size() - 1))
	if rear_hardware_mode == "FLASH":
		rear_flash_modules = modules
	else:
		rear_camera_modules = modules
	_refresh_rear_hardware_panel()
	_refresh_rear_camera_mp_controls()


func _find_rear_hardware_spawn_position(kind: String, module_size: float) -> Vector2:
	var extent := module_size * 1.22
	var half := Vector2(1.45, 2.92) * 0.5
	var min_x := -half.x + extent + 0.025
	var max_x := half.x - extent - 0.025
	var min_y := -half.y + extent + 0.025
	var max_y := half.y - extent - 0.025
	# Start near the centre so the first module can move in every direction.
	# Edge-first placement made one or more direction-pad controls appear broken.
	var preferred_position := _snap_rear_hardware_position(Vector2.ZERO)
	if _rear_module_position_is_free(preferred_position, module_size, kind, -1):
		return preferred_position
	var min_x_index := ceili(min_x / REAR_HARDWARE_GRID_STEP - 0.00001)
	var max_x_index := floori(max_x / REAR_HARDWARE_GRID_STEP + 0.00001)
	var min_y_index := ceili(min_y / REAR_HARDWARE_GRID_STEP - 0.00001)
	var max_y_index := floori(max_y / REAR_HARDWARE_GRID_STEP + 0.00001)
	var y_index := max_y_index
	while y_index >= min_y_index:
		var x_index := min_x_index
		while x_index <= max_x_index:
			var candidate := Vector2(float(x_index) * REAR_HARDWARE_GRID_STEP, float(y_index) * REAR_HARDWARE_GRID_STEP)
			if _rear_module_position_is_free(candidate, module_size, kind, -1):
				return candidate
			x_index += REAR_HARDWARE_SPAWN_GRID_INTERVALS
		y_index -= REAR_HARDWARE_SPAWN_GRID_INTERVALS
	return Vector2(1000.0, 1000.0)


func _rear_module_position_is_free(candidate_position: Vector2, module_size: float, kind: String, ignore_index: int) -> bool:
	var extent := module_size * 1.22 + 0.015
	var half := Vector2(1.45, 2.92) * 0.5
	if absf(candidate_position.x) + extent > half.x - 0.025:
		return false
	if absf(candidate_position.y) + extent > half.y - 0.025:
		return false
	for index in range(rear_camera_modules.size()):
		if kind == "CAMERA" and index == ignore_index:
			continue
		var other: Dictionary = rear_camera_modules[index]
		if candidate_position.distance_to(other["position"]) < (module_size + float(other["size"])) * 1.18 + 0.025:
			return false
	for index in range(rear_flash_modules.size()):
		if kind == "FLASH" and index == ignore_index:
			continue
		var other: Dictionary = rear_flash_modules[index]
		if candidate_position.distance_to(other["position"]) < (module_size + float(other["size"])) * 1.18 + 0.025:
			return false
	return true


func _snap_rear_hardware_position(local_position: Vector2) -> Vector2:
	return Vector2(
		roundf(local_position.x / REAR_HARDWARE_GRID_STEP) * REAR_HARDWARE_GRID_STEP,
		roundf(local_position.y / REAR_HARDWARE_GRID_STEP) * REAR_HARDWARE_GRID_STEP
	)


func _on_rear_hardware_pad_pressed(direction: Vector2i) -> void:
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	if selected_index < 0 or selected_index >= modules.size():
		return
	if not is_instance_valid(phone_model) or not is_instance_valid(preview_camera):
		return
	var module: Dictionary = modules[selected_index]
	var module_position: Vector2 = module["position"]
	var module_size := float(module["size"])
	var inverse_basis := phone_model.global_transform.basis.inverse()
	var camera_right := inverse_basis * preview_camera.global_transform.basis.x
	var camera_up := inverse_basis * preview_camera.global_transform.basis.y
	var local_direction_3d := camera_right * float(direction.x) + camera_up * float(direction.y)
	var local_direction := Vector2(local_direction_3d.x, local_direction_3d.y)
	if local_direction.length_squared() < 0.000001:
		return
	local_direction = local_direction.normalized()
	if absf(local_direction.x) >= absf(local_direction.y):
		local_direction = Vector2(signf(local_direction.x), 0.0)
	else:
		local_direction = Vector2(0.0, signf(local_direction.y))
	var next_position := _snap_rear_hardware_position(
		module_position + local_direction * REAR_HARDWARE_GRID_STEP
	)
	if not _rear_module_position_is_free(next_position, module_size, rear_hardware_mode, selected_index):
		return
	module["position"] = next_position
	if rear_hardware_mode == "FLASH":
		rear_flash_modules[selected_index] = module
	else:
		rear_camera_modules[selected_index] = module
	_refresh_rear_hardware_panel()


func _on_rear_hardware_size_changed(value: float) -> void:
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	if selected_index < 0 or selected_index >= modules.size():
		return
	var module: Dictionary = modules[selected_index]
	var module_position: Vector2 = module["position"]
	var next_size := clampf(value, REAR_HARDWARE_SIZE_MIN, REAR_HARDWARE_SIZE_MAX)
	if not _rear_module_position_is_free(module_position, next_size, rear_hardware_mode, selected_index):
		_refresh_rear_hardware_panel()
		return
	module["size"] = next_size
	if rear_hardware_mode == "FLASH":
		rear_flash_modules[selected_index] = module
	else:
		rear_camera_modules[selected_index] = module
	_refresh_rear_hardware_panel()


func _select_rear_hardware_module(index: int) -> void:
	var modules := _get_rear_hardware_modules()
	if index < 0 or index >= modules.size():
		return
	_set_rear_hardware_selected_index(index)
	_show_rear_camera_controls()


func _show_rear_hardware_selection_controls() -> void:
	var modules := _get_rear_hardware_modules()
	if modules.is_empty() or not is_instance_valid(rear_hardware_step_content):
		return
	right_panel_mode = "CAMERA" if rear_hardware_mode == "CAMERA" else "FLASH"
	if is_instance_valid(camera_back_design_view):
		camera_back_design_view.visible = false
	if is_instance_valid(camera_back_design_selection_view):
		camera_back_design_selection_view.queue_free()
		camera_back_design_selection_view = null
	_style_button(rear_hardware_camera_mode_button, rear_hardware_mode == "CAMERA")
	_style_button(rear_hardware_flash_mode_button, rear_hardware_mode == "FLASH")
	_style_button(rear_hardware_design_mode_button, false)
	if is_instance_valid(rear_hardware_selection_view):
		rear_hardware_selection_view.queue_free()
		rear_hardware_selection_view = null
	rear_hardware_controls_view.visible = false
	rear_hardware_selection_view = VBoxContainer.new()
	rear_hardware_selection_view.name = "RearHardwareSelection"
	rear_hardware_selection_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rear_hardware_selection_view.add_theme_constant_override("separation", 9)
	rear_hardware_step_content.add_child(rear_hardware_selection_view)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	rear_hardware_selection_view.add_child(header)
	var back := Button.new()
	back.name = "RearHardwareSelectionBackButton"
	back.text = "‹"
	back.custom_minimum_size = Vector2(36, 34)
	back.focus_mode = Control.FOCUS_NONE
	_apply_shared_page_typography(back, 25)
	_style_button(back, false)
	back.pressed.connect(_show_rear_camera_controls)
	header.add_child(back)

	var title := _label("SELECT " + rear_hardware_mode, 15, Color("#E5E0D6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var list := GridContainer.new()
	list.name = "RearHardwareOptions"
	list.columns = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("h_separation", 7)
	list.add_theme_constant_override("v_separation", 7)
	rear_hardware_selection_view.add_child(list)
	var selected_index := _get_rear_hardware_selected_index()
	for index in range(modules.size()):
		var module: Dictionary = modules[index]
		var option := Button.new()
		option.name = "RearHardwareOption%d" % index
		option.text = "%s  %02d%s" % [
			rear_hardware_mode,
			int(module["id"]),
			"   ✓ SELECTED" if index == selected_index else ""
		]
		option.custom_minimum_size.y = 48
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.focus_mode = Control.FOCUS_NONE
		_style_button(option, index == selected_index)
		option.pressed.connect(_select_rear_hardware_module.bind(index))
		list.add_child(option)


func _show_rear_camera_controls() -> void:
	if not is_instance_valid(rear_hardware_controls_view):
		return
	right_panel_mode = "CAMERA" if rear_hardware_mode == "CAMERA" else "FLASH"
	if is_instance_valid(rear_hardware_selection_view):
		rear_hardware_selection_view.queue_free()
		rear_hardware_selection_view = null
	if is_instance_valid(camera_back_design_selection_view):
		camera_back_design_selection_view.queue_free()
		camera_back_design_selection_view = null
	if is_instance_valid(camera_back_design_view):
		camera_back_design_view.visible = false
	rear_hardware_controls_view.visible = true
	_style_button(rear_hardware_camera_mode_button, rear_hardware_mode == "CAMERA")
	_style_button(rear_hardware_flash_mode_button, rear_hardware_mode == "FLASH")
	_style_button(rear_hardware_design_mode_button, false)
	_refresh_rear_hardware_panel()


func _refresh_rear_hardware_panel() -> void:
	if not is_instance_valid(rear_hardware_selection_button):
		return
	var modules := _get_rear_hardware_modules()
	var selected_index := _get_rear_hardware_selected_index()
	var kind := "FLASH" if rear_hardware_mode == "FLASH" else "CAMERA"
	var has_selection := selected_index >= 0 and selected_index < modules.size()
	if has_selection:
		var selected: Dictionary = modules[selected_index]
		rear_hardware_size_slider.set_value_no_signal(float(selected["size"]))
		rear_hardware_size_label.text = "SIZE  %.3f" % float(selected["size"])
	else:
		rear_hardware_size_slider.set_value_no_signal(REAR_HARDWARE_SIZE_MIN)
		rear_hardware_size_label.text = "ADD A %s TO BEGIN" % kind

	rear_hardware_size_slider.editable = has_selection
	rear_hardware_remove_button.disabled = not has_selection
	rear_hardware_selection_button.disabled = modules.is_empty()
	rear_hardware_selection_button.text = (
		"%s  %02d  ›" % [kind, int(modules[selected_index]["id"])]
		if has_selection else "ADD A %s TO SELECT" % kind
	)
	rear_hardware_add_button.disabled = modules.size() >= _get_rear_hardware_addition_limit()
	for move_button in rear_hardware_move_buttons:
		move_button.disabled = not has_selection
	_refresh_rear_hardware_visuals()


func _refresh_rear_hardware_visuals() -> void:
	if not is_instance_valid(phone_model):
		return
	var previous := phone_model.get_node_or_null("RearCameraFlashHardware")
	if is_instance_valid(previous):
		previous.free()
	if rear_camera_modules.is_empty() and rear_flash_modules.is_empty():
		return

	var root := Node3D.new()
	root.name = "RearCameraFlashHardware"
	phone_model.add_child(root)

	for module in rear_camera_modules:
		var module_position: Vector2 = module["position"]
		var module_size := float(module["size"])
		var surface_z := _camera_back_design_surface_z(module_position)
		var housing := StandardMaterial3D.new()
		housing.albedo_color = Color("#05070a")
		housing.metallic = 0.88
		housing.roughness = 0.20
		var ring := StandardMaterial3D.new()
		ring.albedo_color = Color("#171d25")
		ring.metallic = 0.94
		ring.roughness = 0.14
		var lens := StandardMaterial3D.new()
		lens.albedo_color = Color("#03070d")
		lens.metallic = 0.62
		lens.roughness = 0.075
		lens.clearcoat_enabled = true
		lens.clearcoat = 0.9
		lens.clearcoat_roughness = 0.06
		var module_id := int(module["id"])
		var depth_scale := (module_size / 0.08) / 1.5
		var layer := func(depth: float) -> float: return depth * depth_scale
		_add_rear_hardware_disc(root, "RearCamera_%d_Housing" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.010)), module_size * 1.22, layer.call(0.020), housing)
		_add_rear_hardware_disc(root, "RearCamera_%d_Rim" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.021)), module_size * 1.04, layer.call(0.006), ring)
		_add_rear_hardware_disc(root, "RearCamera_%d_Gasket" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.025)), module_size * 0.88, layer.call(0.003), housing)
		_add_rear_hardware_disc(root, "RearCamera_%d_Lens" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.030)), module_size * 0.72, layer.call(0.007), lens)
		var optical_core := StandardMaterial3D.new()
		optical_core.albedo_color = Color("#010308")
		optical_core.metallic = 0.18
		optical_core.roughness = 0.045
		optical_core.clearcoat_enabled = true
		optical_core.clearcoat = 1.0
		optical_core.clearcoat_roughness = 0.035
		_add_rear_hardware_disc(root, "RearCamera_%d_OpticalCore" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.034)), module_size * 0.38, layer.call(0.0025), optical_core)
		var glint := StandardMaterial3D.new()
		glint.albedo_color = Color(0.30, 0.43, 0.58, 0.24)
		glint.metallic = 0.22
		glint.roughness = 0.055
		glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_add_rear_hardware_disc(root, "RearCamera_%d_GlassGlint" % module_id, Vector3(module_position.x - module_size * 0.13, module_position.y + module_size * 0.13, surface_z - layer.call(0.036)), module_size * 0.12, layer.call(0.001), glint)

	for index in range(rear_flash_modules.size()):
		var module: Dictionary = rear_flash_modules[index]
		var module_position: Vector2 = module["position"]
		var module_size := float(module["size"])
		var surface_z := _camera_back_design_surface_z(module_position)
		var selected := rear_hardware_mode == "FLASH" and index == rear_flash_selected_index
		var housing := StandardMaterial3D.new()
		housing.albedo_color = Color("#303943")
		housing.metallic = 0.78
		housing.roughness = 0.24
		var rim := StandardMaterial3D.new()
		rim.albedo_color = Color("#C58A3A") if selected else Color("#aab4bd")
		rim.metallic = 0.76
		rim.roughness = 0.24
		var diffuser := StandardMaterial3D.new()
		diffuser.albedo_color = Color("#fff1cf")
		diffuser.roughness = 0.24
		diffuser.emission_enabled = true
		diffuser.emission = Color("#ffe5ad")
		diffuser.emission_energy_multiplier = 0.18
		var module_id := int(module["id"])
		var depth_scale := (module_size / 0.08) / 1.5
		var layer := func(depth: float) -> float: return depth * depth_scale
		_add_rear_hardware_disc(root, "RearFlash_%d_Housing" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.009)), module_size * 1.22, layer.call(0.018), housing)
		_add_rear_hardware_disc(root, "RearFlash_%d_Rim" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.019)), module_size * 1.04, layer.call(0.006), rim)
		_add_rear_hardware_disc(root, "RearFlash_%d_Gasket" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.022)), module_size * 0.86, layer.call(0.0025), housing)
		_add_rear_hardware_disc(root, "RearFlash_%d_Diffuser" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.027)), module_size * 0.70, layer.call(0.006), diffuser)
		var led := StandardMaterial3D.new()
		led.albedo_color = Color("#fff9e9")
		led.roughness = 0.18
		led.emission_enabled = true
		led.emission = Color("#fff0c8")
		led.emission_energy_multiplier = 0.32
		_add_rear_hardware_disc(root, "RearFlash_%d_LEDCore" % module_id, Vector3(module_position.x, module_position.y, surface_z - layer.call(0.031)), module_size * 0.38, layer.call(0.002), led)


func _add_rear_hardware_disc(parent: Node3D, node_name: String, disc_position: Vector3, radius: float, height: float, material: Material) -> void:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	disc.mesh = mesh
	disc.rotation_degrees.x = -90.0
	disc.position = disc_position
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)


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
		right_panel_column.custom_minimum_size = Vector2(356.0, 0.0)
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
