extends Node3D
class_name HQWorld

signal building_selected
signal upgrade_requested
signal tool_selected(tool_name: String)

const BuildingFactory = preload("res://scripts/world/hq_building_factory.gd")

var company_name := "YOUR COMPANY"
var upgrade_level := 1

func configure(name: String, level: int) -> void:
	company_name = name
	upgrade_level = clampi(level, 1, 10)

func _ready() -> void:
	_build_world()

func _build_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#85898b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e5e8e9")
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 138, 0)
	fill.light_color = Color("#d6e0e8")
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	add_child(fill)

	var camera := Camera3D.new()
	camera.name = "Territory_Camera"
	camera.position = Vector3(0, 44, 160)
	camera.fov = 34.0
	camera.look_at(Vector3(0, 0, 15), Vector3.UP)
	add_child(camera)
	camera.current = true

	_box("Territory_Ground", Vector3(190, 0.45, 85), Vector3(0, -0.24, 15), _mat(Color("#777b7d"), 0.96))
	var slot_x_positions := [-60.0, -30.0, 0.0, 30.0, 60.0]
	var slot_z_positions := [0.0, 30.0]
	var plot_number := 1
	for z in slot_z_positions:
		for x in slot_x_positions:
			_create_plot(plot_number, Vector3(x, 0, z))
			plot_number += 1

	var hq := BuildingFactory.create_building(upgrade_level, company_name)
	hq.name = "Player_Headquarters"
	hq.position = Vector3(0, 0.6, 0)
	hq.scale = Vector3.ONE * 1.5
	add_child(hq)

	var selection_ring := MeshInstance3D.new()
	selection_ring.name = "Headquarters_Selection_Ring"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 8.2
	ring_mesh.outer_radius = 8.42
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 12
	selection_ring.mesh = ring_mesh
	selection_ring.position = Vector3(0, 0.24, 0)
	selection_ring.rotation.x = PI * 0.5
	selection_ring.material_override = _mat(Color("#d9f2a9"), 0.45, 0.1)
	add_child(selection_ring)

	# A dedicated pick body opens the interior when the headquarters is tapped.
	var pick_body := StaticBody3D.new()
	pick_body.name = "Headquarters_Tap_Target"
	pick_body.position = Vector3(0, 5.2, 0)
	pick_body.input_ray_pickable = true
	var hit_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(21.0, 11.0, 16.0)
	hit_shape.shape = box_shape
	pick_body.add_child(hit_shape)
	pick_body.input_event.connect(_on_headquarters_input)
	add_child(pick_body)

	var hint := Label3D.new()
	hint.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	hint.text = "TAP HEADQUARTERS TO OPEN"
	hint.font_size = 24
	hint.pixel_size = 0.014
	hint.modulate = Color("#f1f2e8")
	hint.outline_size = 6
	hint.position = Vector3(0, 0.3, 11.0)
	add_child(hint)

func _create_plot(number: int, center: Vector3) -> void:
	var surface := _mat(Color("#9b9fa1"), 0.96)
	var edge := _mat(Color("#b8bbbd"), 0.9)
	var line := _mat(Color("#e4e3dc"), 0.88)
	_box("Plot_%02d_Surface" % number, Vector3(28, 0.12, 28), center + Vector3(0, 0.045, 0), surface)
	_box("Plot_%02d_North_Border" % number, Vector3(28, 0.2, 0.38), center + Vector3(0, 0.15, -14), edge)
	_box("Plot_%02d_South_Border" % number, Vector3(28, 0.2, 0.38), center + Vector3(0, 0.15, 14), edge)
	_box("Plot_%02d_West_Border" % number, Vector3(0.38, 0.2, 28), center + Vector3(-14, 0.15, 0), edge)
	_box("Plot_%02d_East_Border" % number, Vector3(0.38, 0.2, 28), center + Vector3(14, 0.15, 0), edge)
	for offset in [-12.65, 12.65]:
		_box("Plot_%02d_Marking" % number, Vector3(25.3, 0.035, 0.11), center + Vector3(0, 0.22, offset), line)
		_box("Plot_%02d_Marking" % number, Vector3(0.11, 0.035, 25.3), center + Vector3(offset, 0.22, 0), line)
	var number_label := Label3D.new()
	number_label.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	number_label.text = "PLOT %02d" % number
	number_label.font_size = 22
	number_label.pixel_size = 0.018
	number_label.modulate = Color("#dce0dc")
	number_label.position = center + Vector3(-10.5, 0.3, -10.5)
	add_child(number_label)

func _on_headquarters_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		building_selected.emit()
	elif event is InputEventScreenTouch and event.pressed:
		building_selected.emit()

func _box(node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mesh_instance)
	return mesh_instance

func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
