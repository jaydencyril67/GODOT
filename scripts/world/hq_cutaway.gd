extends Node3D
class_name HQCutaway

const LIGHT_GOLD := Color("#d8b64e")

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#aeb8b4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e8e8dc")
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.name = "Fixed_Cutaway_Camera"
	camera.position = Vector3(15.5, 20.5, 25.5)
	camera.fov = 38.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.3, 0), Vector3.UP)
	camera.current = true

	var floor_base := _mat(Color("#a6a79e"), 0.94)
	var floor_left := _mat(Color("#b6bbb3"), 0.94)
	var floor_middle := _mat(Color("#969f98"), 0.92)
	var floor_right := _mat(Color("#c5bda9"), 0.95)
	var wall := _mat(Color("#d5d2c8"), 0.90)
	var partition := _mat(Color("#c5c7bd"), 0.88)
	var dark := _mat(Color("#303a39"), 0.42, 0.48)
	var aluminum := _mat(Color("#9da8a2"), 0.32, 0.72)
	var desk := _mat(Color("#6c6254"), 0.74)
	var light_desk := _mat(Color("#d0c8b8"), 0.68)
	var screen := _mat(Color("#101f2a"), 0.2, 0.12)
	screen.emission_enabled = true
	screen.emission = Color("#1c5b75")
	screen.emission_energy_multiplier = 0.6
	var machine := _mat(Color("#52615e"), 0.48, 0.35)
	var machine_light := _mat(Color("#87948b"), 0.4, 0.42)
	var rubber := _mat(Color("#252c2b"), 0.9)
	var glass := _mat(Color("#a8c6c5", 0.48), 0.12, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var green := _mat(Color("#a6d78b"), 0.35)
	green.emission_enabled = true
	green.emission = Color("#4e9e3a")
	green.emission_energy_multiplier = 0.65
	var amber := _mat(Color("#f0b65c"), 0.35)
	amber.emission_enabled = true
	amber.emission = Color("#b96b18")
	amber.emission_energy_multiplier = 0.45
	var carton := _mat(Color("#b88d58"), 0.96)
	var carton_light := _mat(Color("#d0ad77"), 0.96)
	var steel := _mat(Color("#a8b2ad"), 0.24, 0.88)
	var floor_mark := _mat(LIGHT_GOLD, 0.86)

	# One-storey, open-top operations building: the roof is removed for a clear cutaway.
	_box("Structural_Floor_Slab", Vector3(18.6, 0.38, 14.6), Vector3(0, 0.06, 0), floor_base)
	_box("Finished_Floor_Surface", Vector3(18.2, 0.035, 14.2), Vector3(0, 0.27, 0), floor_base)
	_box("Programming_Studio_Floor", Vector3(5.92, 0.025, 13.75), Vector3(-6.08, 0.3, 0), floor_left)
	_box("Manufacturing_Floor", Vector3(5.92, 0.025, 13.75), Vector3(0, 0.3, 0), floor_middle)
	_box("Packaging_Floor", Vector3(5.92, 0.025, 13.75), Vector3(6.08, 0.3, 0), floor_right)

	# The entry elevation is cut down; the rear and side walls stay low enough to reveal the rooms.
	_box("Left_Cutaway_Wall", Vector3(0.2, 3.55, 14.35), Vector3(-9.15, 2.0, 0), wall)
	_box("Right_Cutaway_Wall", Vector3(0.2, 3.55, 14.35), Vector3(9.15, 2.0, 0), wall)
	_box("Rear_Cutaway_Wall", Vector3(18.3, 3.55, 0.2), Vector3(0, 2.0, -7.15), wall)
	_box("Front_Left_Wall_Remnant", Vector3(7.5, 3.55, 0.2), Vector3(-5.15, 2.0, 7.1), wall)
	_box("Front_Right_Wall_Remnant", Vector3(7.5, 3.55, 0.2), Vector3(5.15, 2.0, 7.1), wall)

	# Skirting, slab joints and the two partition walls define three working departments.
	for x in range(-8, 9, 2):
		_box("Concrete_Construction_Joint", Vector3(0.012, 0.009, 13.8), Vector3(float(x), 0.322, 0), dark)
	for z in range(-6, 7, 2):
		_box("Concrete_Construction_Joint", Vector3(18.0, 0.009, 0.012), Vector3(0, 0.322, float(z)), dark)
	_box("Skirting_Left", Vector3(0.08, 0.16, 13.9), Vector3(-9.02, 0.42, 0), aluminum)
	_box("Skirting_Right", Vector3(0.08, 0.16, 13.9), Vector3(9.02, 0.42, 0), aluminum)
	_box("Skirting_Rear", Vector3(18.1, 0.16, 0.08), Vector3(0, 0.42, -7.02), aluminum)
	for x in [-3.02, 3.02]:
		_box("Department_Glass_Partition", Vector3(0.16, 3.0, 8.35), Vector3(x, 1.72, -2.65), partition)
		_box("Department_Glass_Partition", Vector3(0.16, 3.0, 3.25), Vector3(x, 1.72, 5.45), partition)
		_box("Department_Glass_Partition", Vector3(0.16, 3.0, 1.55), Vector3(x, 1.72, 0.25), partition)

	# Room labels are actual 3D signs on the back wall, not HTML overlays.
	_label("PROGRAMMING STUDIO", Vector3(-6.05, 3.1, -6.99), Color("#7ebfce"))
	_label("MANUFACTURING", Vector3(0, 3.1, -6.99), Color("#a8ce8d"))
	_label("PACKAGING & STACKING", Vector3(6.05, 3.1, -6.99), Color("#ddb77b"))

	# PROGRAMMING: four desks, monitors, keyboards, office chairs and a shared station.
	_add_desk(Vector3(-7.3, 0, -3.1), 0, desk, dark, screen, aluminum, rubber, light_desk)
	_add_desk(Vector3(-4.9, 0, -3.1), 0, desk, dark, screen, aluminum, rubber, light_desk)
	_add_desk(Vector3(-7.3, 0, 1.2), PI, desk, dark, screen, aluminum, rubber, light_desk)
	_add_desk(Vector3(-4.9, 0, 1.2), PI, desk, dark, screen, aluminum, rubber, light_desk)
	_box("Shared_Programming_Bench", Vector3(1.35, 0.08, 0.58), Vector3(-6.05, 0.88, -5.05), desk)
	for x in [-6.55, -5.55]:
		_cylinder("Studio_Plant_Pot", 0.16, 0.19, 0.27, Vector3(x, 0.48, 4.55), _mat(Color("#825f45"), 0.8))
		_cylinder("Studio_Plant_Stem", 0.03, 0.015, 0.5, Vector3(x, 0.84, 4.55), _mat(Color("#427855"), 0.9))

	# MANUFACTURING: roller conveyor, assembly stations and two industrial machines.
	_box("Conveyor_Frame", Vector3(1.18, 0.48, 7.1), Vector3(0, 0.77, -0.05), dark)
	_box("Conveyor_Belt", Vector3(0.94, 0.14, 6.82), Vector3(0, 1.08, -0.05), rubber)
	for index in range(12):
		var roller_z := -3.2 + float(index) * 0.57
		var roller := _cylinder("Conveyor_Roller", 0.095, 0.095, 1.02, Vector3(0, 1.18, roller_z), steel)
		roller.rotation.z = PI * 0.5
		for side in [-1.0, 1.0]:
			var cap := _cylinder("Roller_End_Cap", 0.115, 0.115, 0.045, Vector3(side * 0.52, 1.18, roller_z), dark)
			cap.rotation.z = PI * 0.5
	_box("Conveyor_Side_Rail_Left", Vector3(0.045, 0.11, 6.9), Vector3(-0.57, 1.27, -0.05), aluminum)
	_box("Conveyor_Side_Rail_Right", Vector3(0.045, 0.11, 6.9), Vector3(0.57, 1.27, -0.05), aluminum)
	for z in [-2.4, -0.2, 2.0]:
		_box("Assembly_Station", Vector3(0.72, 0.15, 0.62), Vector3(0, 1.34, z), light_desk)
		_box("Assembly_Control_Console", Vector3(0.18, 0.13, 0.15), Vector3(0, 1.48, z), dark)
		_box("Assembly_Status_Light", Vector3(0.12, 0.08, 0.06), Vector3(0, 1.58, z + 0.05), green if z < 0 else amber)
	_add_machine(Vector3(-1.88, 0.92, -2.5), machine, machine_light, dark, rubber, steel, glass, green, amber)
	_add_machine(Vector3(1.88, 0.92, 2.25), machine, machine_light, dark, rubber, steel, glass, amber, green)
	_box("Machine_Control_Column", Vector3(1.08, 1.88, 0.7), Vector3(-2.25, 1.12, 2.1), machine)
	_box("Machine_Control_Screen", Vector3(0.72, 0.72, 0.055), Vector3(-2.25, 1.35, 2.48), screen)

	# PACKAGING & STACKING: dispatch bench, six cartons, pallet and three-tier storage shelving.
	_box("Dispatch_Bench_Top", Vector3(2.25, 0.14, 1.18), Vector3(5.75, 0.94, 3.65), desk)
	for x in [4.82, 6.68]:
		for z in [3.22, 4.08]:
			_box("Dispatch_Bench_Leg", Vector3(0.1, 0.9, 0.1), Vector3(x, 0.48, z), dark)
	_add_carton(Vector3(4.85, 0.55, -4.65), Vector3(0.92, 0.52, 0.82), carton, dark, carton_light)
	_add_carton(Vector3(5.78, 0.55, -4.65), Vector3(0.92, 0.52, 0.82), carton_light, dark, carton)
	_add_carton(Vector3(4.85, 1.10, -4.65), Vector3(0.92, 0.52, 0.82), carton_light, dark, carton)
	_add_carton(Vector3(5.78, 1.10, -4.65), Vector3(0.92, 0.52, 0.82), carton, dark, carton_light)
	_add_carton(Vector3(4.85, 0.55, -3.72), Vector3(0.92, 0.52, 0.82), carton_light, dark, carton)
	_add_carton(Vector3(7.45, 0.55, -4.7), Vector3(0.86, 0.52, 0.78), carton, dark, carton_light)
	_add_carton(Vector3(7.45, 1.10, -4.7), Vector3(0.86, 0.52, 0.78), carton_light, dark, carton)
	_add_carton(Vector3(7.45, 1.65, -4.7), Vector3(0.86, 0.52, 0.78), carton, dark, carton_light)
	for x in [8.2]:
		for z in [-2.8, 0.0, 2.8]:
			_box("Warehouse_Rack_Upright", Vector3(0.12, 2.65, 0.12), Vector3(x, 1.5, z), dark)
	for y in [0.55, 1.45, 2.35]:
		_box("Warehouse_Rack_Shelf", Vector3(1.2, 0.09, 5.85), Vector3(7.55, y, 0), aluminum)

	# Gold floor guides trace the workflow from workstations through production to dispatch.
	for x in [-2.85, -2.55, 2.55, 2.85]:
		_box("Workflow_Floor_Guide", Vector3(0.06, 0.018, 11.5), Vector3(x, 0.325, 0), floor_mark)
	for z in [-5.3, 5.3]:
		_box("Workflow_Floor_Guide", Vector3(11.6, 0.018, 0.06), Vector3(0, 0.325, z), floor_mark)

	# Ceiling lights remain visible but the roof itself is absent.
	for x in [-6.1, 0.0, 6.1]:
		for z in [-3.5, 2.2]:
			_box("Light_Housing", Vector3(1.35, 0.055, 0.58), Vector3(x, 3.54, z), aluminum)
			_box("Light_Diffuser", Vector3(1.2, 0.028, 0.45), Vector3(x, 3.58, z), _emissive_mat(Color("#fff0cc"), 1.05))
			var fill := OmniLight3D.new()
			fill.light_color = Color("#ffe9c6") if x != 0 else Color("#e1edff")
			fill.light_energy = 1.6
			fill.omni_range = 8.5
			fill.position = Vector3(x, 3.1, z)
			add_child(fill)

	# Wall clock, emergency exit sign and an inactive founder avatar reproduce the original scale cues.
	_cylinder("Wall_Clock", 0.34, 0.34, 0.07, Vector3(-8.98, 2.85, -4.5), wall)
	_box("Clock_Hand_H", Vector3(0.48, 0.06, 0.075), Vector3(-8.98, 2.85, -4.42), dark)
	_box("Clock_Hand_V", Vector3(0.06, 0.32, 0.075), Vector3(-8.98, 2.85, -4.42), dark)
	_label("EXIT", Vector3(0, 3.15, 6.96), Color("#dcf2d4"))
	_add_static_avatar(Vector3(0, 0.2, 4.7))

func _add_desk(position: Vector3, rotation_y: float, desk: Material, dark: Material, screen: Material, aluminum: Material, rubber: Material, light_desk: Material) -> void:
	var group := Node3D.new()
	group.position = position
	group.rotation.y = rotation_y
	add_child(group)
	_box("Workstation_Desk_Top", Vector3(1.95, 0.13, 0.92), Vector3(0, 0.91, 0), desk, group)
	for dx in [-0.82, 0.82]:
		for dz in [-0.32, 0.32]:
			_box("Workstation_Desk_Leg", Vector3(0.09, 0.82, 0.09), Vector3(dx, 0.44, dz), dark, group)
	_box("Monitor_Frame", Vector3(0.74, 0.48, 0.075), Vector3(0, 1.2, -0.27), dark, group)
	_box("Monitor_Display", Vector3(0.65, 0.37, 0.026), Vector3(0, 1.2, -0.224), screen, group)
	_box("Monitor_Stand", Vector3(0.1, 0.16, 0.1), Vector3(0, 0.98, -0.27), aluminum, group)
	_box("Keyboard", Vector3(0.76, 0.035, 0.27), Vector3(0, 0.99, 0.23), rubber, group)
	_box("Desk_Notepad", Vector3(0.32, 0.025, 0.18), Vector3(-0.55, 0.995, 0.23), light_desk, group)
	_box("Office_Chair_Seat", Vector3(0.55, 0.15, 0.55), Vector3(0, 0.52, 0.88), rubber, group)
	_box("Office_Chair_Back", Vector3(0.53, 0.55, 0.13), Vector3(0, 0.86, 1.1), rubber, group)
	_cylinder("Office_Chair_Column", 0.055, 0.055, 0.38, Vector3(0, 0.26, 0.88), aluminum, group)
	_box("Office_Chair_Base", Vector3(0.8, 0.06, 0.06), Vector3(0, 0.09, 0.88), dark, group)

func _add_machine(position: Vector3, machine: Material, light: Material, dark: Material, rubber: Material, steel: Material, glass: Material, status: Material, accent: Material) -> void:
	_box("Industrial_Machine_Cabinet", Vector3(1.42, 1.45, 1.72), position, machine)
	_box("Machine_Enclosure", Vector3(1.18, 0.88, 1.5), position + Vector3(0, 0.13, 0), light)
	_box("Machine_Base_Trim", Vector3(1.04, 0.04, 1.36), position + Vector3(0, 0.6, 0), rubber)
	_box("Machine_Service_Panel", Vector3(0.44, 0.19, 0.08), position + Vector3(0, 0.83, 0.9), dark)
	_box("Machine_Status_Display", Vector3(0.32, 0.1, 0.035), position + Vector3(0, 0.84, 0.95), status)
	_box("Machine_Inspection_Frame", Vector3(0.68, 0.48, 0.065), position + Vector3(0, 0.3, 0.9), dark)
	_box("Machine_Inspection_Glass", Vector3(0.56, 0.34, 0.025), position + Vector3(0, 0.3, 0.95), glass)
	for index in range(7):
		_box("Machine_Vent", Vector3(0.58, 0.025, 0.018), position + Vector3(0, -0.2 + float(index) * 0.085, 0.875), dark)
	for side in [-1.0, 1.0]:
		_cylinder("Machine_Foot", 0.035, 0.035, 0.022, position + Vector3(side * 0.5, -0.7, 0.55), steel)

func _add_carton(position: Vector3, size: Vector3, body: Material, seam: Material, tape: Material) -> void:
	_box("Cardboard_Carton", size, position, body)
	_box("Carton_Top_Seam", Vector3(size.x + 0.012, 0.025, size.z + 0.012), position + Vector3(0, size.y * 0.5 - 0.035, 0), seam)
	_box("Carton_Tape", Vector3(0.045, size.y * 0.6, 0.026), position + Vector3(0, 0.01, size.z * 0.5 + 0.015), tape)

func _add_static_avatar(position: Vector3) -> void:
	var avatar := Node3D.new()
	avatar.name = "Founder_Reference_Avatar"
	avatar.position = position
	add_child(avatar)
	var clothes := _mat(Color("#344f49"), 0.88)
	var pants := _mat(Color("#303b3c"), 0.92)
	var skin := _mat(Color("#b98563"), 0.84)
	var shoes := _mat(Color("#242b2b"), 0.82)
	_capsule(avatar, 0.245, 0.62, Vector3(0, 1.27, 0), clothes)
	_sphere(avatar, 0.22, Vector3(0, 1.98, 0), skin)
	_capsule(avatar, 0.09, 0.5, Vector3(-0.13, 0.48, 0), pants)
	_capsule(avatar, 0.09, 0.5, Vector3(0.13, 0.48, 0), pants)
	_box("Avatar_Shoe_Left", Vector3(0.25, 0.13, 0.38), Vector3(-0.13, 0.12, -0.055), shoes, avatar)
	_box("Avatar_Shoe_Right", Vector3(0.25, 0.13, 0.38), Vector3(0.13, 0.12, -0.055), shoes, avatar)
	_capsule(avatar, 0.07, 0.48, Vector3(-0.32, 1.29, 0), clothes)
	_capsule(avatar, 0.07, 0.48, Vector3(0.32, 1.29, 0), clothes)

func _box(node_name: String, size: Vector3, position: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var target: Node3D = self if parent == null else parent
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	target.add_child(mesh_instance)
	return mesh_instance

func _cylinder(node_name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = 16
	mesh_instance.mesh = cylinder
	mesh_instance.position = position
	mesh_instance.material_override = material
	var target: Node3D = self if parent == null else parent
	target.add_child(mesh_instance)
	return mesh_instance

func _capsule(parent: Node3D, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _sphere(parent: Node3D, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _label(text: String, position: Vector3, accent: Color) -> void:
	var board := _box("Room_Sign", Vector3(4.55, 1.08, 0.08), position - Vector3(0, 0, 0.045), _mat(Color("#273330"), 0.8))
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = 34
	sign.pixel_size = 0.012
	sign.modulate = Color("#e9eee4")
	sign.outline_size = 7
	sign.outline_modulate = Color("#273330")
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.position = position + Vector3(0, 0, 0.01)
	sign.rotation.y = PI
	add_child(sign)
	_box("Room_Sign_Accent", Vector3(0.08, 1.02, 0.025), position + Vector3(-2.2, 0, 0.02), _mat(accent, 0.6))

func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color, 0.32)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
