extends Node3D

# Two-screen DigitalWorld launcher:
# 1) KingsHall DigitalWorld-inspired landing page
# 2) Static, open-front architectural cutaway of a modern office building
# No player controller, interior navigation, furniture, or interaction systems.

var menu_layer: CanvasLayer
var building_root: Node3D
var status_label: Label

const NAVY := Color("#103a5a")
const BLUE := Color("#248cc4")
const GLASS := Color(0.82, 0.96, 1.0, 0.30)
const CONCRETE := Color("#d2d0c5")
const DARK_METAL := Color("#263c3d")
const GLASS_BLUE := Color(0.31, 0.56, 0.64, 0.34)

func _ready() -> void:
	show_landing_page()

func show_landing_page() -> void:
	if is_instance_valid(building_root):
		building_root.queue_free()
		building_root = null
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()

	menu_layer = CanvasLayer.new()
	menu_layer.name = "LandingPage"
	add_child(menu_layer)

	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(screen)

	var backdrop := TextureRect.new()
	backdrop.name = "LandingBackground"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture = load("res://assets/digitalworld-landing.png")
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	screen.add_child(backdrop)

	var menu := VBoxContainer.new()
	menu.name = "MainMenu"
	menu.anchor_left = 0.5
	menu.anchor_top = 0.5
	menu.anchor_right = 0.5
	menu.anchor_bottom = 0.5
	menu.offset_left = -104.0
	menu.offset_top = -100.0
	menu.offset_right = 104.0
	menu.offset_bottom = 100.0
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 9)
	screen.add_child(menu)

	_add_menu_button(menu, "START GAME", true, _on_start_game)
	_add_menu_button(menu, "LOAD GAME", false, _on_load_game)
	_add_menu_button(menu, "SETTINGS", false, _on_settings)
	_add_menu_button(menu, "EXIT GAME", false, _on_exit_game)

	status_label = Label.new()
	status_label.text = "DIGITALWORLD  /  READY"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color("#426982"))
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.anchor_top = 0.5
	status_label.anchor_bottom = 0.5
	status_label.offset_left = -150
	status_label.offset_right = 150
	status_label.offset_top = 118
	status_label.offset_bottom = 140
	screen.add_child(status_label)

	var footer := Label.new()
	footer.text = "KINGSHALL-ORG                                      DIGITALWORLD"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 22
	footer.offset_right = -22
	footer.offset_top = -28
	footer.offset_bottom = -10
	footer.add_theme_font_size_override("font_size", 8)
	footer.add_theme_color_override("font_color", Color("#3f789a"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(footer)

func _add_menu_button(parent: VBoxContainer, caption: String, primary: bool, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption + "     ›"
	button.custom_minimum_size = Vector2(208, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _menu_button_style(primary, false))
	button.add_theme_stylebox_override("hover", _menu_button_style(primary, true))
	button.add_theme_stylebox_override("pressed", _menu_button_style(primary, true))
	button.add_theme_stylebox_override("focus", _menu_button_style(primary, true))
	button.pressed.connect(callback)
	parent.add_child(button)

func _menu_button_style(primary: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.75, 0.95, 0.78) if primary else (Color(0.90, 0.98, 1.0, 0.48) if hovered else GLASS)
	style.border_color = Color(1, 1, 1, 0.96)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0.0, 0.35, 0.58, 0.18)
	style.shadow_size = 5
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _on_start_game() -> void:
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = null
	_build_halfcut_office()

func _on_load_game() -> void:
	if is_instance_valid(status_label):
		status_label.text = "NO SAVED GAME FOUND"

func _on_settings() -> void:
	if is_instance_valid(status_label):
		status_label.text = "SETTINGS WILL BE ADDED IN A LATER PHASE"

func _on_exit_game() -> void:
	get_tree().quit()

func _build_halfcut_office() -> void:
	building_root = Node3D.new()
	building_root.name = "HalfCutOfficeBuilding"
	add_child(building_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#a9c8d8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce9ed")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	building_root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	building_root.add_child(sun)

	var camera := Camera3D.new()
	camera.name = "CutawayCamera"
	camera.position = Vector3(17.0, 15.0, 21.0)
	camera.fov = 38.0
	camera.look_at(Vector3(0.0, 3.25, 0.0), Vector3.UP)
	building_root.add_child(camera)
	camera.current = true

	var concrete := _material(CONCRETE, 0.88)
	var pale_concrete := _material(Color("#e7e5dc"), 0.82)
	var metal := _material(DARK_METAL, 0.48, 0.62)
	var glass := _material(GLASS_BLUE, 0.20, 0.18, true)
	var floor_mat := _material(Color("#a7aaa6"), 0.92)
	var ground_mat := _material(Color("#858d8d"), 0.98)

	_add_box("Ground", Vector3(34, 0.35, 28), Vector3(0, -0.35, 0), ground_mat)
	_add_box("Foundation", Vector3(15.0, 0.62, 11.0), Vector3(0, 0.12, 0), concrete)
	_add_box("LowerFloorPlate", Vector3(14.4, 0.28, 10.4), Vector3(0, 0.58, 0), floor_mat)
	_add_box("UpperFloorPlate", Vector3(14.4, 0.30, 10.4), Vector3(0, 3.72, 0), pale_concrete)

	# Rear elevation: glazed curtain wall with visible mullions.
	_add_box("RearConcreteBeam", Vector3(14.5, 0.42, 0.38), Vector3(0, 7.05, -5.2), concrete)
	_add_box("RearLowerSill", Vector3(14.2, 0.24, 0.28), Vector3(0, 0.92, -5.15), concrete)
	_add_box("RearUpperSill", Vector3(14.2, 0.24, 0.28), Vector3(0, 4.02, -5.15), concrete)
	for x in [-6.8, -4.55, -2.3, 0.0, 2.3, 4.55, 6.8]:
		_add_box("RearCurtainWallMullion", Vector3(0.12, 6.0, 0.18), Vector3(x, 3.95, -5.18), metal)
	for y in [2.35, 5.45]:
		_add_box("RearCurtainWallTransom", Vector3(14.0, 0.10, 0.16), Vector3(0, y, -5.20), metal)
	for x in [-5.65, -3.4, -1.15, 1.15, 3.4, 5.65]:
		for y in [2.35, 5.45]:
			_add_box("RearGlazingPanel", Vector3(2.08, 2.82, 0.045), Vector3(x, y, -5.28), glass)

	# Left structural wall and the exposed cut edges. The front and right
	# elevations stay open so the building reads clearly as an architectural section.
	_add_box("LeftShearWall", Vector3(0.34, 6.65, 10.2), Vector3(-7.0, 3.85, 0), concrete)
	_add_box("LeftCutEdgeColumn", Vector3(0.42, 6.5, 0.42), Vector3(-6.55, 3.85, 4.7), metal)
	_add_box("RearRightColumn", Vector3(0.42, 6.5, 0.42), Vector3(6.55, 3.85, -4.7), metal)

	# Open structural frame: the front and right sides are removed for a clear view inside.
	for x in [-5.8, -2.0, 2.0, 5.8]:
		_add_box("FrontStructuralColumn", Vector3(0.34, 6.3, 0.34), Vector3(x, 3.85, 4.75), pale_concrete)
		_add_box("MidStructuralColumn", Vector3(0.30, 6.3, 0.30), Vector3(x, 3.85, 0.0), metal)
	_add_box("FrontLowerBeam", Vector3(14.0, 0.34, 0.36), Vector3(0, 3.18, 4.75), concrete)
	_add_box("FrontUpperBeam", Vector3(14.0, 0.34, 0.36), Vector3(0, 6.32, 4.75), concrete)

	# Fully roofless top-down cutaway: both floor plates and all office rooms stay visible.
	# Ground floor: reception, open-plan desks, meeting room and private offices.
	_add_box("ReceptionDeskBase", Vector3(2.8, 0.78, 0.78), Vector3(-3.9, 1.12, 2.55), metal)
	_add_box("ReceptionDeskTop", Vector3(3.0, 0.12, 0.92), Vector3(-3.9, 1.56, 2.55), pale_concrete)
	_add_box("ReceptionFeatureWall", Vector3(3.8, 2.2, 0.18), Vector3(-3.9, 2.0, -0.45), pale_concrete)
	_add_box("ReceptionLogoPanel", Vector3(1.3, 0.68, 0.06), Vector3(-3.9, 2.05, -0.32), glass)
	_add_box("GroundMeetingTable", Vector3(3.4, 0.14, 1.55), Vector3(2.8, 1.22, -2.25), pale_concrete)
	for x in [1.25, 2.8, 4.35]:
		_add_box("MeetingChairSeat", Vector3(0.58, 0.16, 0.58), Vector3(x, 0.88, -3.45), metal)
		_add_box("MeetingChairBack", Vector3(0.58, 0.62, 0.12), Vector3(x, 1.18, -3.72), metal)
		_add_box("MeetingChairSeat", Vector3(0.58, 0.16, 0.58), Vector3(x, 0.88, -1.05), metal)
		_add_box("MeetingChairBack", Vector3(0.58, 0.62, 0.12), Vector3(x, 1.18, -0.78), metal)
	# Open-plan workstation islands.
	for x in [-5.0, -2.2, 1.0]:
		for z in [-1.2, 1.0]:
			_add_box("OfficeDeskTop", Vector3(1.65, 0.12, 0.78), Vector3(x, 1.42, z), pale_concrete)
			_add_box("OfficeDeskPedestal", Vector3(0.34, 0.72, 0.58), Vector3(x - 0.55, 1.02, z), metal)
			_add_box("OfficeMonitor", Vector3(0.62, 0.48, 0.08), Vector3(x, 1.72, z - 0.18), DARK_METAL)
			_add_box("OfficeChairSeat", Vector3(0.62, 0.16, 0.62), Vector3(x, 0.92, z + 0.78), metal)
			_add_box("OfficeChairBack", Vector3(0.62, 0.64, 0.14), Vector3(x, 1.24, z + 1.05), metal)
	# Glass partitions define enclosed offices without blocking the roofless view.
	_add_box("GroundOfficePartitionA", Vector3(0.12, 2.35, 4.2), Vector3(5.1, 1.75, 1.9), glass)
	_add_box("GroundOfficePartitionB", Vector3(3.2, 2.35, 0.12), Vector3(5.0, 1.75, -0.2), glass)
	_add_box("GroundOfficeDesk", Vector3(1.8, 0.12, 0.85), Vector3(5.65, 1.45, 2.2), pale_concrete)
	# Upper floor: executive offices and a second collaboration area.
	_add_box("UpperMeetingTable", Vector3(3.2, 0.14, 1.45), Vector3(-3.8, 4.42, -2.15), pale_concrete)
	for x in [-5.0, -3.8, -2.6]:
		_add_box("UpperMeetingChairSeat", Vector3(0.54, 0.16, 0.54), Vector3(x, 4.08, -3.35), metal)
		_add_box("UpperMeetingChairBack", Vector3(0.54, 0.58, 0.12), Vector3(x, 4.36, -3.60), metal)
		_add_box("UpperMeetingChairSeat", Vector3(0.54, 0.16, 0.54), Vector3(x, 4.08, -0.95), metal)
		_add_box("UpperMeetingChairBack", Vector3(0.54, 0.58, 0.12), Vector3(x, 4.36, -0.70), metal)
	for x in [0.0, 3.0]:
		_add_box("ExecutiveDeskTop", Vector3(2.0, 0.12, 0.88), Vector3(x, 4.62, 1.6), pale_concrete)
		_add_box("ExecutiveDeskBase", Vector3(0.38, 0.78, 0.68), Vector3(x - 0.65, 4.22, 1.6), metal)
		_add_box("ExecutiveMonitor", Vector3(0.68, 0.5, 0.08), Vector3(x, 4.92, 1.35), DARK_METAL)
	_add_box("UpperGlassPartitionA", Vector3(0.12, 2.35, 4.3), Vector3(4.8, 4.9, 1.8), glass)
	_add_box("UpperGlassPartitionB", Vector3(3.0, 2.35, 0.12), Vector3(4.7, 4.9, -0.3), glass)
	_add_box("UpperOfficeDesk", Vector3(1.8, 0.12, 0.85), Vector3(5.55, 4.62, 2.0), pale_concrete)
	# Low planters add scale and make the open floors read as furnished offices.
	for z in [-3.9, 3.65]:
		_add_box("GroundPlanter", Vector3(1.1, 0.48, 0.72), Vector3(-6.0, 1.0, z), _material(Color("#526f58"), 0.92))
		_add_box("UpperPlanter", Vector3(1.1, 0.48, 0.72), Vector3(-6.0, 4.15, z), _material(Color("#526f58"), 0.92))

	# A restrained front plinth and entrance threshold anchor the section.
	_add_box("EntranceThreshold", Vector3(4.2, 0.16, 0.9), Vector3(0, 0.84, 5.45), pale_concrete)
	_add_box("FacadeNameBand", Vector3(4.6, 0.46, 0.14), Vector3(0, 6.65, 4.92), metal)

	var back_button := Button.new()
	back_button.text = "‹  BACK TO MENU"
	back_button.position = Vector2(22, 22)
	back_button.custom_minimum_size = Vector2(148, 42)
	back_button.add_theme_font_size_override("font_size", 10)
	back_button.add_theme_color_override("font_color", Color.WHITE)
	back_button.add_theme_stylebox_override("normal", _menu_button_style(false, false))
	back_button.add_theme_stylebox_override("hover", _menu_button_style(false, true))
	back_button.pressed.connect(show_landing_page)
	var hud := CanvasLayer.new()
	hud.name = "CutawayNavigation"
	building_root.add_child(hud)
	hud.add_child(back_button)

func _material(color: Color, roughness: float, metallic: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _add_box(label: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	building_root.add_child(mesh_instance)
	return mesh_instance
