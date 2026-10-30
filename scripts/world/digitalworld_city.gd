extends Node3D
class_name DigitalWorldCity

const GRID_COLUMNS := 5
const GRID_ROWS := 6
const PLOT_SPACING := 12.5
const ROAD_WIDTH := 3.2
const CITY_HALF_WIDTH := 34.0
const CITY_HALF_DEPTH := 40.0
const CITY_BUILDING_MODELS := [
	"res://assets/city_glb/building-a.glb",
	"res://assets/city_glb/building-b.glb",
	"res://assets/city_glb/building-c.glb",
	"res://assets/city_glb/building-d.glb",
	"res://assets/city_glb/building-e.glb",
	"res://assets/city_glb/building-f.glb",
	"res://assets/city_glb/building-g.glb",
	"res://assets/city_glb/building-h.glb",
	"res://assets/city_glb/building-i.glb",
	"res://assets/city_glb/building-j.glb",
	"res://assets/city_glb/building-k.glb",
	"res://assets/city_glb/building-l.glb",
	"res://assets/city_glb/building-m.glb",
	"res://assets/city_glb/building-n.glb"
]
const CITY_TOWER_MODELS := [
	"res://assets/city_glb/building-skyscraper-a.glb",
	"res://assets/city_glb/building-skyscraper-b.glb",
	"res://assets/city_glb/building-skyscraper-c.glb",
	"res://assets/city_glb/building-skyscraper-d.glb",
	"res://assets/city_glb/building-skyscraper-e.glb"
]
const CITY_CAR_MODELS := [
	"res://assets/city_glb/sedan.glb",
	"res://assets/city_glb/suv.glb",
	"res://assets/city_glb/taxi.glb"
]
const CITY_PEDESTRIAN_MODELS := [
	"res://assets/city_glb/character-female-a.glb",
	"res://assets/city_glb/character-male-a.glb"
]
const CITY_TREE_MODELS := [
	"res://assets/city_glb/tree-default.glb",
	"res://assets/city_glb/tree-oak.glb"
]

var traffic: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var animation_clock := 0.0
var city_camera: Camera3D
var camera_target := Vector3(0.0, 5.2, 15.0)
var camera_yaw := 0.0
var camera_pitch := -0.09
var camera_distance := 26.0
var mouse_orbiting := false
var mouse_panning := false
var touch_points: Dictionary = {}
var pinch_distance := 0.0
var last_touch_midpoint := Vector2.ZERO

func _ready() -> void:
	_build_city()
	_add_camera_hud()

func _process(delta: float) -> void:
	animation_clock += delta
	for vehicle in traffic:
		var node: Node3D = vehicle["node"]
		var direction: float = vehicle["direction"]
		node.position.x += float(vehicle["speed"]) * direction * delta
		if node.position.x > CITY_HALF_WIDTH + 4.0:
			node.position.x = -CITY_HALF_WIDTH - 4.0
		elif node.position.x < -CITY_HALF_WIDTH - 4.0:
			node.position.x = CITY_HALF_WIDTH + 4.0
	for person in walkers:
		var node: Node3D = person["node"]
		node.position.x += float(person["speed"]) * delta
		if node.position.x > CITY_HALF_WIDTH:
			node.position.x = -CITY_HALF_WIDTH
		var phase := animation_clock * 7.0 + float(person["phase"])
		if person.has("left_leg"):
			(person["left_leg"] as Node3D).rotation.z = sin(phase) * 0.22
			(person["right_leg"] as Node3D).rotation.z = -sin(phase) * 0.22
			(person["left_arm"] as Node3D).rotation.z = -sin(phase) * 0.16
			(person["right_arm"] as Node3D).rotation.z = sin(phase) * 0.16
		else:
			node.position.y = 0.025 + abs(sin(phase)) * 0.035

func _build_city() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9fb8c7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce8ed")
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	# Street-level cinematic entry. The orbit target stays inside the city,
	# while distance and pitch remain user-controlled on touch and desktop.
	city_camera = Camera3D.new()
	city_camera.name = "Metropolis_Free_Explore_Camera"
	city_camera.fov = 66.0
	city_camera.near = 0.08
	city_camera.far = 650.0
	add_child(city_camera)
	_update_camera_transform()
	city_camera.current = true

	var concrete := _mat(Color("#777f82"), 0.94)
	var asphalt := _mat(Color("#252b30"), 0.94)
	var sidewalk := _mat(Color("#b4b6b0"), 0.92)
	var curb := _mat(Color("#d0d0c7"), 0.88)
	var lane_paint := _mat(Color("#e9d8a2"), 0.78)
	var white_paint := _mat(Color("#e8ece9"), 0.76)
	var grassless_soil := _mat(Color("#77766c"), 1.0)
	var concrete_texture := load("res://assets/textures/concrete-color.svg") as Texture2D
	if concrete_texture != null:
		concrete.albedo_texture = concrete_texture
		asphalt.albedo_texture = concrete_texture
		sidewalk.albedo_texture = concrete_texture
		grassless_soil.albedo_texture = concrete_texture
		concrete.uv1_scale = Vector3(5.0, 5.0, 1.0)
		asphalt.uv1_scale = Vector3(7.0, 7.0, 1.0)
		sidewalk.uv1_scale = Vector3(3.0, 3.0, 1.0)
		grassless_soil.uv1_scale = Vector3(6.0, 6.0, 1.0)
		asphalt.albedo_color = Color("#686b6c")
		sidewalk.albedo_color = Color("#c3c0b5")
		grassless_soil.albedo_color = Color("#96948a")
	var trunk := _mat(Color("#655044"), 0.98)
	var foliage_a := _mat(Color("#426b55"), 0.92)
	var foliage_b := _mat(Color("#64815c"), 0.94)
	var pole_material := _mat(Color("#3d484b"), 0.52, 0.62)
	var lamp_material := _mat(Color("#fff0c5"), 0.24)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("#ffe3a0")
	lamp_material.emission_energy_multiplier = 2.2
	var glass_material := _mat(Color("#78b9d0"), 0.12, 0.62)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.47, 0.72, 0.82, 0.78)
	glass_material.metallic = 0.48
	glass_material.emission_enabled = true
	glass_material.emission = Color("#183d50")
	glass_material.emission_energy_multiplier = 0.18
	var window_frame_material := _mat(Color("#26343b"), 0.42, 0.72)
	var roof_detail_material := _mat(Color("#59656a"), 0.76, 0.35)

	_box(self, "City_Base_Slab", Vector3(78.0, 0.7, 90.0), Vector3(0.0, -0.48, 0.0), concrete)
	_box(self, "City_Paved_Surface", Vector3(76.0, 0.08, 88.0), Vector3(0.0, -0.08, 0.0), grassless_soil)

	# Curved road corridors and offset paved sidewalks break the rigid grid silhouette.
	for row_edge in range(GRID_ROWS + 1):
		var z := (float(row_edge) - 3.0) * PLOT_SPACING
		var road_points := PackedVector3Array()
		for sample in range(13):
			var t := float(sample) / 12.0
			var x := lerpf(-38.0, 38.0, t)
			var bend := sin(t * PI * 2.0 + float(row_edge) * 0.43) * 0.58
			road_points.append(Vector3(x, 0.0, z + bend))
		_add_road_ribbon("Curved_East_West_Asphalt", road_points, ROAD_WIDTH, 0.015, asphalt)
		_add_road_ribbon("Curved_North_Sidewalk", _offset_road_path(road_points, Vector3(0.0, 0.0, -2.12)), 1.15, 0.075, sidewalk)
		_add_road_ribbon("Curved_South_Sidewalk", _offset_road_path(road_points, Vector3(0.0, 0.0, 2.12)), 1.15, 0.075, sidewalk)
		for dash in range(1, 12, 2):
			var p: Vector3 = road_points[dash]
			var next_p: Vector3 = road_points[dash + 1]
			var mark := _box(self, "Curved_Centre_Lane_Marking", Vector3(2.1, 0.018, 0.075), Vector3((p.x + next_p.x) * 0.5, 0.085, (p.z + next_p.z) * 0.5), lane_paint)
			mark.rotation.y = atan2(next_p.z - p.z, next_p.x - p.x)
	for col_edge in range(GRID_COLUMNS + 1):
		var x := (float(col_edge) - 2.5) * PLOT_SPACING
		var road_points := PackedVector3Array()
		for sample in range(13):
			var t := float(sample) / 12.0
			var z := lerpf(-44.0, 44.0, t)
			var bend := sin(t * PI * 2.0 + float(col_edge) * 0.51) * 0.52
			road_points.append(Vector3(x + bend, 0.0, z))
		_add_road_ribbon("Curved_North_South_Asphalt", road_points, ROAD_WIDTH, 0.02, asphalt)
		_add_road_ribbon("Curved_West_Sidewalk", _offset_road_path(road_points, Vector3(-2.08, 0.0, 0.0)), 1.1, 0.08, sidewalk)
		_add_road_ribbon("Curved_East_Sidewalk", _offset_road_path(road_points, Vector3(2.08, 0.0, 0.0)), 1.1, 0.08, sidewalk)
		for dash in range(1, 12, 2):
			var p: Vector3 = road_points[dash]
			var next_p: Vector3 = road_points[dash + 1]
			var mark := _box(self, "Curved_Centre_Lane_Marking", Vector3(0.075, 0.018, 2.1), Vector3((p.x + next_p.x) * 0.5, 0.09, (p.z + next_p.z) * 0.5), lane_paint)
			mark.rotation.y = atan2(next_p.x - p.x, next_p.z - p.z)

	# Marked pedestrian crossings at the central signalized junctions.
	_add_crosswalk(Vector3(-6.25, 0.0, 0.0), true, white_paint)
	_add_crosswalk(Vector3(6.25, 0.0, 0.0), true, white_paint)
	_add_crosswalk(Vector3(0.0, 0.0, -6.25), false, white_paint)
	_add_crosswalk(Vector3(0.0, 0.0, 6.25), false, white_paint)

	# Thirty individually modelled city blocks: offices, apartments, hotels and towers.
	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var plot_position := Vector3(
				(float(col) - 2.0) * PLOT_SPACING + sin(float(row) * 0.72) * 0.52,
				0.0,
				(float(row) - 2.5) * PLOT_SPACING + sin(float(col) * 0.63) * 0.48
			)
			_build_city_building(row * GRID_COLUMNS + col, plot_position, window_frame_material, glass_material, roof_detail_material)

	# Street furniture and greenery soften the concrete city grid.
	for row_edge in range(GRID_ROWS + 1):
		var z := (float(row_edge) - 3.0) * PLOT_SPACING + PLOT_SPACING * 0.5
		for x in [-24.0, 0.0, 24.0]:
			if row_edge % 2 == 1:
				_add_streetlight(Vector3(x, 0.0, z - 2.65), pole_material, lamp_material)
	for col_edge in range(GRID_COLUMNS + 1):
		var x := (float(col_edge) - 2.5) * PLOT_SPACING
		for z in [-25.0, 0.0, 25.0]:
			if col_edge % 2 == 0:
				_add_streetlight(Vector3(x + 2.65, 0.0, z), pole_material, lamp_material)

	# Signalized junctions give the main avenues recognizable city infrastructure.
	for signal_position in [Vector3(-7.0, 0.0, -1.9), Vector3(7.0, 0.0, 1.9), Vector3(-19.5, 0.0, 23.1), Vector3(19.5, 0.0, -23.1)]:
		var signal_root := Node3D.new()
		signal_root.position = signal_position
		add_child(signal_root)
		var signal_model := _add_glb_model(signal_root, "res://assets/city_glb/traffic-light.glb", Vector3.ONE * 2.1)
		if signal_model != null:
			signal_model.rotation.y = PI * 0.5

	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var p := Vector3((float(col) - 2.0) * PLOT_SPACING, 0.0, (float(row) - 2.5) * PLOT_SPACING)
			if (row + col) % 3 == 0:
				_add_tree(Vector3(p.x - 4.35, 0.0, p.z - 4.45), trunk, foliage_a, foliage_b)

	# Cars circulate along the east-west avenues in both directions.
	var traffic_lanes: Array[float] = [-25.0, 0.0, 25.0]
	for index in range(10):
		var row_lane: float = traffic_lanes[index % 3]
		var direction := 1.0 if index % 2 == 0 else -1.0
		var start_x := -31.0 + float(index) * 6.8
		var car := _make_car(index)
		car.position = Vector3(start_x, 0.12, row_lane + (0.58 if direction > 0.0 else -0.58))
		car.rotation.y = -PI * 0.5 if direction > 0.0 else PI * 0.5
		add_child(car)
		traffic.append({"node": car, "speed": 3.0 + float(index % 3) * 0.65, "direction": direction})

	# Small pedestrians walk along the paved sidewalks, not through the traffic lanes.
	var pedestrian_lanes: Array[float] = [-27.5, -2.5, 22.5]
	for index in range(14):
		var person := _make_pedestrian(index)
		person["node"].position = Vector3(-32.0 + float(index) * 4.7, 0.0, pedestrian_lanes[index % 3])
		add_child(person["node"])
		walkers.append(person)

func _build_city_building(index: int, plot_position: Vector3, window_frame_material: Material, glass_material: Material, roof_detail_material: Material) -> void:
	var building := Node3D.new()
	building.name = "City_Building_%02d" % (index + 1)
	building.position = plot_position
	add_child(building)

	var podium_material := _mat(Color("#777f82"), 0.88, 0.08)
	_box(building, "Architectural_Podium", Vector3(9.2, 0.42, 9.2), Vector3(0.0, 0.21, 0.0), podium_material)

	var model_path: String
	var model_scale := 7.1 + float(index % 3) * 0.38
	if index % 6 == 0 or index == 17 or index == 28:
		model_path = CITY_TOWER_MODELS[floori(float(index) / 6.0) % CITY_TOWER_MODELS.size()]
		model_scale += 0.75
	else:
		model_path = CITY_BUILDING_MODELS[index % CITY_BUILDING_MODELS.size()]

	var model := _add_glb_model(building, model_path, Vector3.ONE * model_scale)
	if model != null:
		model.rotation.y = float((index * 3) % 4) * PI * 0.5
		_add_building_glazing(building, index, window_frame_material, glass_material, roof_detail_material)
	else:
		# Keep a safe fallback if an imported asset fails to load on a clean editor import.
		var fallback_height := 9.0 + float((index * 7) % 8) * 2.0
		var fallback := _mat(Color("#9babb0"), 0.72, 0.12)
		_box(building, "Fallback_Building_Mass", Vector3(6.0, fallback_height, 6.0), Vector3(0.0, 0.42 + fallback_height * 0.5, 0.0), fallback)


func _add_glb_model(parent: Node3D, model_path: String, model_scale: Vector3) -> Node3D:
	if not ResourceLoader.exists(model_path):
		return null
	var packed_scene := ResourceLoader.load(model_path) as PackedScene
	if packed_scene == null:
		return null
	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.scale = model_scale
	parent.add_child(instance)
	return instance


func _offset_road_path(points: PackedVector3Array, offset: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in points:
		result.append(point + offset)
	return result


func _add_road_ribbon(node_name: String, points: PackedVector3Array, width: float, height: float, material: Material) -> void:
	if points.size() < 2:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var following := points[mini(index + 1, points.size() - 1)]
		var tangent := (following - previous).normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x).normalized() * width * 0.5
		var center := points[index]
		surface.set_uv(Vector2(float(index) * 0.42, 0.0))
		surface.add_vertex(center - side + Vector3.UP * height)
		surface.set_uv(Vector2(float(index) * 0.42, 1.0))
		surface.add_vertex(center + side + Vector3.UP * height)
	surface.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mesh_instance)

func _add_building_glazing(parent: Node3D, index: int, frame_material: Material, glass_material: Material, roof_material: Material) -> void:
	# Use two MultiMesh batches per building instead of hundreds of individual window nodes.
	var tower := index % 6 == 0 or index == 17 or index == 28
	var floor_count := 8 if tower else 4
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.42, 1.12, 0.13)
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(1.20, 0.90, 0.09)
	var sill_mesh := BoxMesh.new()
	sill_mesh.size = Vector3(1.38, 0.10, 0.18)
	var frame_batch := MultiMesh.new()
	frame_batch.transform_format = MultiMesh.TRANSFORM_3D
	frame_batch.mesh = frame_mesh
	var glass_batch := MultiMesh.new()
	glass_batch.transform_format = MultiMesh.TRANSFORM_3D
	glass_batch.mesh = glass_mesh
	var sill_batch := MultiMesh.new()
	sill_batch.transform_format = MultiMesh.TRANSFORM_3D
	sill_batch.mesh = sill_mesh
	var window_transforms: Array[Transform3D] = []
	var sill_transforms: Array[Transform3D] = []
	for floor_index in range(floor_count):
		var window_y := 1.55 + float(floor_index) * 1.62
		for side_index in range(4):
			var side_angle := float(side_index) * PI * 0.5
			for bay in range(2):
				var bay_offset := -1.35 if bay == 0 else 1.35
				var local_position := Vector3(bay_offset, window_y, 4.13)
				var rotated_position := Basis(Vector3.UP, side_angle) * local_position
				var window_basis := Basis(Vector3.UP, side_angle)
				window_transforms.append(Transform3D(window_basis, rotated_position))
				var sill_position := Vector3(bay_offset, window_y - 0.53, 4.16)
				sill_transforms.append(Transform3D(window_basis, window_basis * sill_position))
	frame_batch.instance_count = window_transforms.size()
	glass_batch.instance_count = window_transforms.size()
	sill_batch.instance_count = sill_transforms.size()
	for window_index in range(window_transforms.size()):
		frame_batch.set_instance_transform(window_index, window_transforms[window_index])
		glass_batch.set_instance_transform(window_index, window_transforms[window_index])
		sill_batch.set_instance_transform(window_index, sill_transforms[window_index])
	var frames := MultiMeshInstance3D.new()
	frames.name = "Architectural_Window_Frames"
	frames.multimesh = frame_batch
	frames.material_override = frame_material
	frames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(frames)
	var glazing := MultiMeshInstance3D.new()
	glazing.name = "Blue_Tinted_Glass_Panels"
	glazing.multimesh = glass_batch
	glazing.material_override = glass_material
	glazing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glazing)
	var sills := MultiMeshInstance3D.new()
	sills.name = "Architectural_Window_Sills"
	sills.multimesh = sill_batch
	sills.material_override = frame_material
	sills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sills)
	# A restrained rooftop service unit adds a constructed, functional silhouette.
	var roof_unit := _box(parent, "Rooftop_HVAC_Unit", Vector3(1.45, 0.48, 0.95), Vector3(-2.55, 8.0 if tower else 7.0, -2.45), roof_material)
	roof_unit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_crosswalk(center: Vector3, across_horizontal_road: bool, material: Material) -> void:
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.22, 0.025, 2.75) if across_horizontal_road else Vector3(2.75, 0.025, 0.22)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = stripe_mesh
	batch.instance_count = 7
	for stripe_index in range(7):
		var offset := float(stripe_index - 3) * 0.42
		var stripe_position := center + (Vector3(offset, 0.105, 0.0) if across_horizontal_road else Vector3(0.0, 0.105, offset))
		batch.set_instance_transform(stripe_index, Transform3D(Basis.IDENTITY, stripe_position))
	var crossing := MultiMeshInstance3D.new()
	crossing.name = "Pedestrian_Zebra_Crossing"
	crossing.multimesh = batch
	crossing.material_override = material
	crossing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crossing)


func _add_streetlight(position: Vector3, metal: Material, lamp: Material) -> void:
	var light_root := Node3D.new()
	light_root.position = position
	add_child(light_root)
	_cylinder(light_root, "Streetlight_Pole", 0.055, 0.075, 4.2, Vector3(0.0, 2.1, 0.0), metal)
	_box(light_root, "Streetlight_Arm", Vector3(0.9, 0.07, 0.07), Vector3(0.36, 4.12, 0.0), metal)
	_box(light_root, "Streetlight_Lamp", Vector3(0.42, 0.12, 0.28), Vector3(0.72, 4.02, 0.0), lamp)
	var practical_light := OmniLight3D.new()
	practical_light.name = "Streetlight_Illumination"
	practical_light.position = Vector3(0.72, 3.94, 0.0)
	practical_light.light_color = Color("#ffe2ad")
	practical_light.light_energy = 0.42
	practical_light.omni_range = 8.5
	practical_light.shadow_enabled = false
	# Keep the number of real-time lights low for mobile GPUs.
	if int(abs(position.x * 3.0 + position.z)) % 3 == 0:
		light_root.add_child(practical_light)

func _add_tree(position: Vector3, trunk_material: Material, leaf_a: Material, leaf_b: Material) -> void:
	var tree := Node3D.new()
	tree.name = "Urban_Tree"
	tree.position = position
	add_child(tree)
	var tree_path: String = CITY_TREE_MODELS[int(abs(position.x * 3.0 + position.z)) % CITY_TREE_MODELS.size()]
	var model := _add_glb_model(tree, tree_path, Vector3.ONE * 2.15)
	if model == null:
		_cylinder(tree, "Tree_Trunk", 0.13, 0.18, 1.55, Vector3(0.0, 0.78, 0.0), trunk_material)
		_sphere(tree, "Tree_Canopy_Lower", 0.88, Vector3(0.0, 1.85, 0.0), leaf_a)
		_sphere(tree, "Tree_Canopy_Upper", 0.62, Vector3(0.0, 2.55, 0.0), leaf_b)

func _make_car(index: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Traffic_Car_%02d" % (index + 1)
	var model_path: String = CITY_CAR_MODELS[index % CITY_CAR_MODELS.size()]
	var model := _add_glb_model(car, model_path, Vector3.ONE * 0.72)
	if model == null:
		var body := _mat(Color("#b84e3d"), 0.34, 0.28)
		_box(car, "Car_Body_Fallback", Vector3(1.65, 0.48, 0.82), Vector3(0.0, 0.48, 0.0), body)
	var headlamp_material := _mat(Color("#fff4d2"), 0.22)
	headlamp_material.emission_enabled = true
	headlamp_material.emission = Color("#fff0c5")
	headlamp_material.emission_energy_multiplier = 1.8
	var tail_lamp_material := _mat(Color("#b52e25"), 0.3)
	tail_lamp_material.emission_enabled = true
	tail_lamp_material.emission = Color("#b52e25")
	tail_lamp_material.emission_energy_multiplier = 1.1
	# Small front/rear lamp details follow the vehicle root orientation.
	for side in [-1.0, 1.0]:
		_box(car, "Vehicle_Headlamp", Vector3(0.12, 0.10, 0.055), Vector3(0.72, 0.48, side * 0.25), headlamp_material)
		_box(car, "Vehicle_Tail_Lamp", Vector3(0.10, 0.10, 0.055), Vector3(-0.72, 0.48, side * 0.25), tail_lamp_material)
	return car

func _make_pedestrian(index: int) -> Dictionary:
	var person := Node3D.new()
	person.name = "Pedestrian_%02d" % (index + 1)
	var model_path: String = CITY_PEDESTRIAN_MODELS[index % CITY_PEDESTRIAN_MODELS.size()]
	var model := _add_glb_model(person, model_path, Vector3.ONE * 0.92)
	person.rotation.y = -PI * 0.5
	if model == null:
		var clothes := _mat(Color("#355b72"), 0.88)
		var skin := _mat(Color("#986b50"), 0.9)
		var trousers := _mat(Color("#343b42"), 0.94)
		_sphere(person, "Pedestrian_Head", 0.16, Vector3(0.0, 1.45, 0.0), skin)
		_capsule(person, "Pedestrian_Torso", 0.19, 0.62, Vector3(0.0, 0.98, 0.0), clothes)
		var left_leg := _capsule(person, "Pedestrian_Left_Leg", 0.07, 0.42, Vector3(-0.09, 0.48, 0.0), trousers)
		var right_leg := _capsule(person, "Pedestrian_Right_Leg", 0.07, 0.42, Vector3(0.09, 0.48, 0.0), trousers)
		var left_arm := _capsule(person, "Pedestrian_Left_Arm", 0.055, 0.4, Vector3(-0.23, 1.0, 0.0), clothes)
		var right_arm := _capsule(person, "Pedestrian_Right_Arm", 0.055, 0.4, Vector3(0.23, 1.0, 0.0), clothes)
		return {"node": person, "left_leg": left_leg, "right_leg": right_leg, "left_arm": left_arm, "right_arm": right_arm, "speed": 0.65 + float(index % 4) * 0.12, "phase": float(index) * 0.7}
	return {"node": person, "speed": 0.65 + float(index % 4) * 0.12, "phase": float(index) * 0.7}

func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance

func _capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, node_name: String, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _input(event: InputEvent) -> void:
	# Desktop orbit, pan and wheel zoom.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_orbiting = event.pressed
			return
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_panning = event.pressed
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-2.4)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(2.4)
			return
	elif event is InputEventMouseMotion:
		if mouse_orbiting:
			_orbit_camera(event.relative)
		elif mouse_panning:
			_pan_camera(event.relative)
		return

	# Android: one finger orbits; two fingers pinch-zoom and pan together.
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() == 2:
				var points: Array = touch_points.values()
				var first_point: Vector2 = points[0]
				var second_point: Vector2 = points[1]
				pinch_distance = first_point.distance_to(second_point)
				last_touch_midpoint = (first_point + second_point) * 0.5
		else:
			touch_points.erase(event.index)
			if touch_points.size() == 1:
				pinch_distance = 0.0
			elif touch_points.is_empty():
				pinch_distance = 0.0
		return

	if event is InputEventScreenDrag and touch_points.has(event.index):
		touch_points[event.index] = event.position
		if touch_points.size() >= 2:
			var points: Array = touch_points.values()
			var first: Vector2 = points[0]
			var second: Vector2 = points[1]
			var next_distance := first.distance_to(second)
			var midpoint := (first + second) * 0.5
			if pinch_distance > 0.0:
				_zoom_camera((pinch_distance - next_distance) * 0.045)
			_pan_camera(midpoint - last_touch_midpoint)
			pinch_distance = next_distance
			last_touch_midpoint = midpoint
		else:
			_orbit_camera(event.relative)
		get_viewport().set_input_as_handled()


func _orbit_camera(relative: Vector2) -> void:
	camera_yaw -= relative.x * 0.0052
	camera_pitch = clampf(camera_pitch - relative.y * 0.0042, -0.16, 1.12)
	_update_camera_transform()


func _zoom_camera(amount: float) -> void:
	camera_distance = clampf(camera_distance + amount, 6.5, 112.0)
	_update_camera_transform()


func _pan_camera(relative: Vector2) -> void:
	if not is_instance_valid(city_camera):
		return
	var scale_factor := camera_distance * 0.00165
	var camera_right := city_camera.global_transform.basis.x
	var camera_up := city_camera.global_transform.basis.y
	camera_target -= camera_right * relative.x * scale_factor
	camera_target += camera_up * relative.y * scale_factor
	camera_target.x = clampf(camera_target.x, -48.0, 48.0)
	camera_target.y = clampf(camera_target.y, 1.0, 38.0)
	camera_target.z = clampf(camera_target.z, -55.0, 55.0)
	_update_camera_transform()


func _update_camera_transform() -> void:
	if not is_instance_valid(city_camera):
		return
	var horizontal := cos(camera_pitch) * camera_distance
	var offset := Vector3(
		sin(camera_yaw) * horizontal,
		sin(camera_pitch) * camera_distance,
		cos(camera_yaw) * horizontal
	)
	city_camera.position = camera_target + offset
	city_camera.look_at(camera_target, Vector3.UP)


func _reset_camera() -> void:
	camera_target = Vector3(0.0, 5.2, 15.0)
	camera_yaw = 0.0
	camera_pitch = -0.09
	camera_distance = 26.0
	_update_camera_transform()


func _add_camera_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "City_Camera_Controls"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var hint := Label.new()
	hint.text = "DRAG TO ROTATE  •  PINCH TO ZOOM  •  TWO FINGERS TO PAN"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98, 0.86))
	hint.add_theme_color_override("font_shadow_color", Color(0.02, 0.07, 0.10, 0.9))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.anchor_left = 0.0
	hint.anchor_top = 1.0
	hint.anchor_right = 0.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 18.0
	hint.offset_top = -34.0
	hint.offset_right = 360.0
	hint.offset_bottom = -14.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	var reset_button := Button.new()
	reset_button.text = "RESET VIEW"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.custom_minimum_size = Vector2(112.0, 38.0)
	reset_button.anchor_left = 1.0
	reset_button.anchor_top = 1.0
	reset_button.anchor_right = 1.0
	reset_button.anchor_bottom = 1.0
	reset_button.offset_left = -130.0
	reset_button.offset_top = -54.0
	reset_button.offset_right = -18.0
	reset_button.offset_bottom = -16.0
	reset_button.add_theme_font_size_override("font_size", 11)
	reset_button.add_theme_color_override("font_color", Color("#f4fbff"))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.035, 0.13, 0.19, 0.78)
	button_style.border_color = Color(0.65, 0.83, 0.91, 0.7)
	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(9)
	for state in ["normal", "hover", "pressed", "focus"]:
		reset_button.add_theme_stylebox_override(state, button_style)
	reset_button.pressed.connect(_reset_camera)
	root.add_child(reset_button)

func _mat(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
