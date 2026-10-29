extends Node3D

# Lightweight procedural cutaway HQ. All geometry is generated in code.
const CONCRETE := Color(0.70, 0.73, 0.74)
const FLOOR := Color(0.36, 0.38, 0.39)
const GLASS := Color(0.28, 0.48, 0.56, 0.24)
const DARK := Color(0.08, 0.13, 0.17)
const WOOD := Color(0.40, 0.23, 0.13)
const GREEN := Color(0.12, 0.34, 0.20)

func _ready() -> void:
	build_world()

func mat(color: Color, metallic: float = 0.0, roughness: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func label3d(text_value: String, pos: Vector3, size: float = 0.32) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = pos
	label.font_size = 48
	label.pixel_size = size / 48.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.08, 0.15, 0.20)
	add_child(label)

func build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.57, 0.63)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.80, 0.81)
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Daylight"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# Base slab and open-front floor plan.
	box(self, "Foundation", Vector3(12.8, 0.32, 9.0), Vector3(0, -0.18, 0), mat(Color(0.18, 0.22, 0.25)))
	box(self, "InteriorFloor", Vector3(12.2, 0.08, 8.4), Vector3(0, 0.02, 0), mat(FLOOR, 0.05, 0.3))

	# Rear facade: concrete frame and large glass panels.
	box(self, "RearConcreteHeader", Vector3(12.2, 0.32, 0.30), Vector3(0, 3.25, -4.05), mat(CONCRETE))
	box(self, "RearConcreteBase", Vector3(12.2, 0.42, 0.30), Vector3(0, 0.28, -4.05), mat(CONCRETE))
	for x in [-5.9, -3.0, 0.0, 3.0, 5.9]:
		box(self, "AluminiumFrame", Vector3(0.12, 3.0, 0.22), Vector3(x, 1.82, -4.05), mat(Color(0.48, 0.55, 0.59), 0.7, 0.28))
	for x in [-4.45, -1.5, 1.5, 4.45]:
		box(self, "GlassFacade", Vector3(2.78, 2.85, 0.08), Vector3(x, 1.83, -4.12), mat(GLASS, 0.15, 0.18))

	# Short side returns keep the building readable as a cutaway.
	box(self, "LeftSideWall", Vector3(0.28, 3.2, 8.2), Vector3(-6.05, 1.58, 0), mat(CONCRETE))
	box(self, "RightSidePier", Vector3(0.28, 3.2, 2.3), Vector3(6.05, 1.58, -2.9), mat(CONCRETE))
	box(self, "RoofEdge", Vector3(12.5, 0.18, 0.42), Vector3(0, 3.42, -4.0), mat(Color(0.60, 0.65, 0.68), 0.35, 0.35))

	# Reception zone on the left.
	box(self, "ReceptionDeskBase", Vector3(2.35, 0.82, 0.72), Vector3(-3.65, 0.48, -0.75), mat(Color(0.77, 0.79, 0.78), 0.05, 0.32))
	box(self, "ReceptionDeskTop", Vector3(2.5, 0.12, 0.82), Vector3(-3.65, 0.95, -0.75), mat(WOOD, 0.0, 0.28))
	box(self, "DeskFrontAccent", Vector3(1.8, 0.10, 0.04), Vector3(-3.65, 0.52, -0.375), mat(Color(0.18, 0.48, 0.61), 0.2, 0.25))
	box(self, "WaitingSofaSeat", Vector3(2.0, 0.28, 0.72), Vector3(-3.8, 0.35, 1.55), mat(Color(0.17, 0.25, 0.30)))
	box(self, "WaitingSofaBack", Vector3(2.0, 0.72, 0.20), Vector3(-3.8, 0.78, 1.82), mat(Color(0.17, 0.25, 0.30)))
	box(self, "SofaArmLeft", Vector3(0.20, 0.48, 0.72), Vector3(-4.7, 0.56, 1.55), mat(Color(0.22, 0.31, 0.36)))
	box(self, "SofaArmRight", Vector3(0.20, 0.48, 0.72), Vector3(-2.9, 0.56, 1.55), mat(Color(0.22, 0.31, 0.36)))
	box(self, "CoffeeTable", Vector3(1.25, 0.12, 0.72), Vector3(-3.8, 0.48, 0.25), mat(Color(0.63, 0.67, 0.67), 0.35, 0.25))
	label3d("RECEPTION", Vector3(-4.4, 2.25, -0.8), 0.28)

	# Boardroom zone on the right.
	box(self, "BoardroomTableTop", Vector3(3.35, 0.16, 1.45), Vector3(2.45, 0.98, -0.35), mat(WOOD, 0.0, 0.28))
	box(self, "BoardroomTableLeg", Vector3(0.24, 0.88, 0.24), Vector3(2.45, 0.49, -0.35), mat(DARK, 0.4, 0.3))
	for x in [1.15, 2.45, 3.75]:
		for z in [-1.55, 0.85]:
			box(self, "BoardroomChairSeat", Vector3(0.72, 0.16, 0.65), Vector3(x, 0.55, z), mat(Color(0.15, 0.22, 0.27)))
			box(self, "BoardroomChairBack", Vector3(0.72, 0.62, 0.14), Vector3(x, 0.87, z + (0.30 if z > 0 else -0.30)), mat(Color(0.15, 0.22, 0.27)))
	label3d("BOARDROOM", Vector3(1.5, 2.4, -2.1), 0.28)
	label3d("DIGITALWORLD HQ", Vector3(-1.5, 3.75, -4.15), 0.25)

	# Simple plants add scale and life without heavy assets.
	for p in [Vector3(-5.1, 0.0, 2.7), Vector3(5.0, 0.0, -2.0), Vector3(0.0, 0.0, 2.9)]:
		box(self, "PlantPot", Vector3(0.48, 0.46, 0.48), p + Vector3(0, 0.23, 0), mat(Color(0.34, 0.24, 0.17)))
		box(self, "PlantFoliage", Vector3(0.62, 0.92, 0.62), p + Vector3(0, 0.88, 0), mat(GREEN))

	var camera := Camera3D.new()
	camera.name = "OverviewCamera"
	camera.position = Vector3(10.0, 7.4, 11.5)
	camera.fov = 42.0
	add_child(camera)
	camera.look_at(Vector3(0, 1.15, -0.35), Vector3.UP)
	camera.current = true
