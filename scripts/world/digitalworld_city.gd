extends Node3D
class_name DigitalWorldCity

const GRID_COLUMNS := 5
const GRID_ROWS := 6
const PLOT_SPACING := 12.5
const ROAD_WIDTH := 3.2
const CITY_HALF_WIDTH := 34.0
const CITY_HALF_DEPTH := 40.0

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
		(person["left_leg"] as Node3D).rotation.z = sin(phase) * 0.22
		(person["right_leg"] as Node3D).rotation.z = -sin(phase) * 0.22
		(person["left_arm"] as Node3D).rotation.z = -sin(phase) * 0.16
		(person["right_arm"] as Node3D).rotation.z = sin(phase) * 0.16

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
	var asphalt := _mat(Color("#30383d"), 0.96)
	var sidewalk := _mat(Color("#b4b6b0"), 0.92)
	var curb := _mat(Color("#d0d0c7"), 0.88)
	var lane_paint := _mat(Color("#e4d9ad"), 0.82)
	var white_paint := _mat(Color("#dce0dc"), 0.8)
	var grassless_soil := _mat(Color("#77766c"), 1.0)
	var trunk := _mat(Color("#655044"), 0.98)
	var foliage_a := _mat(Color("#426b55"), 0.92)
	var foliage_b := _mat(Color("#64815c"), 0.94)
	var pole_material := _mat(Color("#3d484b"), 0.52, 0.62)
	var lamp_material := _mat(Color("#fff0c5"), 0.28)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("#ffe3a0")
	lamp_material.emission_energy_multiplier = 1.4

	_box(self, "City_Base_Slab", Vector3(78.0, 0.7, 90.0), Vector3(0.0, -0.48, 0.0), concrete)
	_box(self, "City_Paved_Surface", Vector3(76.0, 0.08, 88.0), Vector3(0.0, -0.08, 0.0), grassless_soil)

	# Continuous asphalt streets between every block, with raised paved sidewalks.
	for row_edge in range(GRID_ROWS + 1):
		var z := (float(row_edge) - 3.0) * PLOT_SPACING
		_box(self, "East_West_Asphalt_Road", Vector3(76.0, 0.10, ROAD_WIDTH), Vector3(0.0, 0.0, z), asphalt)
		_box(self, "North_Sidewalk", Vector3(76.0, 0.16, 1.15), Vector3(0.0, 0.06, z - ROAD_WIDTH * 0.5 - 0.62), sidewalk)
		_box(self, "South_Sidewalk", Vector3(76.0, 0.16, 1.15), Vector3(0.0, 0.06, z + ROAD_WIDTH * 0.5 + 0.62), sidewalk)
		for dash in range(9):
			var dx := -31.0 + float(dash) * 7.75
			_box(self, "Broken_Centre_Lane_Marking", Vector3(1.75, 0.018, 0.09), Vector3(dx, 0.065, z), lane_paint)
	for col_edge in range(GRID_COLUMNS + 1):
		var x := (float(col_edge) - 2.5) * PLOT_SPACING
		_box(self, "North_South_Asphalt_Road", Vector3(ROAD_WIDTH, 0.11, 88.0), Vector3(x, 0.012, 0.0), asphalt)
		_box(self, "West_Sidewalk", Vector3(1.1, 0.16, 88.0), Vector3(x - ROAD_WIDTH * 0.5 - 0.58, 0.07, 0.0), sidewalk)
		_box(self, "East_Sidewalk", Vector3(1.1, 0.16, 88.0), Vector3(x + ROAD_WIDTH * 0.5 + 0.58, 0.07, 0.0), sidewalk)
		for dash in range(11):
			var dz := -38.0 + float(dash) * 7.6
			_box(self, "Broken_Centre_Lane_Marking", Vector3(0.09, 0.018, 1.75), Vector3(x, 0.075, dz), lane_paint)

	# Thirty individually modelled city blocks: offices, apartments, hotels and towers.
	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var plot_position := Vector3((float(col) - 2.0) * PLOT_SPACING, 0.0, (float(row) - 2.5) * PLOT_SPACING)
			_build_city_building(row * GRID_COLUMNS + col, plot_position)

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
		car.rotation.y = 0.0 if direction > 0.0 else PI
		add_child(car)
		traffic.append({"node": car, "speed": 3.0 + float(index % 3) * 0.65, "direction": direction})

	# Small pedestrians walk along the paved sidewalks, not through the traffic lanes.
	var pedestrian_lanes: Array[float] = [-27.5, -2.5, 22.5]
	for index in range(14):
		var person := _make_pedestrian(index)
		person["node"].position = Vector3(-32.0 + float(index) * 4.7, 0.0, pedestrian_lanes[index % 3])
		add_child(person["node"])
		walkers.append(person)

func _build_city_building(index: int, plot_position: Vector3) -> void:
	var palette := [
		Color("#aebbc0"), Color("#c2b7a4"), Color("#899da8"), Color("#c6c9c4"),
		Color("#9babb0"), Color("#b7a99a"), Color("#7f929b"), Color("#d0c8b8")
	]
	var glass_palette := [
		Color("#31566a"), Color("#426879"), Color("#536d78"), Color("#294957")
	]
	var base_color: Color = palette[index % palette.size()]
	var glass_color: Color = glass_palette[index % glass_palette.size()]
	var height := 8.0 + float((index * 7) % 8) * 2.25
	if index % 7 == 0:
		height += 8.0
	var width := 5.7 + float(index % 3) * 0.55
	var depth := 5.6 + float((index + 1) % 3) * 0.5
	var building := Node3D.new()
	building.name = "City_Building_%02d" % (index + 1)
	building.position = plot_position
	add_child(building)

	var base := _mat(base_color, 0.78, 0.12)
	var glass := _mat(glass_color, 0.24, 0.32)
	var trim := _mat(Color("#3d484c"), 0.48, 0.55)
	var roof := _mat(base_color.darkened(0.24), 0.88, 0.08)
	_box(building, "Building_Podium", Vector3(7.8, 0.8, 7.8), Vector3(0.0, 0.42, 0.0), roof)
	_box(building, "Main_Architectural_Mass", Vector3(width, height, depth), Vector3(0.0, 0.8 + height * 0.5, 0.0), base)
	_box(building, "Roof_Crown", Vector3(width + 0.24, 0.28, depth + 0.24), Vector3(0.0, 0.94 + height, 0.0), trim)

	# Recessed-looking horizontal glazing bands and vertical facade fins.
	var floors := clampi(floori(height / 4.0), 3, 4)
	for floor_index in range(floors):
		var y := 1.25 + float(floor_index) * (height / float(floors))
		_box(building, "Front_Glass_Band", Vector3(width - 0.32, 0.72, 0.045), Vector3(0.0, y, depth * 0.5 + 0.025), glass)
	for fin in [-1.0, 1.0]:
		_box(building, "Facade_Vertical_Fin", Vector3(0.13, height - 0.5, 0.16), Vector3(fin * (width * 0.5 - 0.12), 0.8 + height * 0.5, depth * 0.5 + 0.08), trim)

	if index % 4 == 0:
		_box(building, "Roof_Mechanical_Penthouse", Vector3(width * 0.42, 1.3, depth * 0.48), Vector3(0.0, 1.72 + height, 0.0), roof)
	if index % 5 == 0:
		_box(building, "Side_Annex", Vector3(1.35, height * 0.58, depth * 0.72), Vector3(width * 0.5 + 0.7, 0.8 + height * 0.29, 0.0), base)

func _add_streetlight(position: Vector3, metal: Material, lamp: Material) -> void:
	var light_root := Node3D.new()
	light_root.position = position
	add_child(light_root)
	_cylinder(light_root, "Streetlight_Pole", 0.055, 0.075, 4.2, Vector3(0.0, 2.1, 0.0), metal)
	_box(light_root, "Streetlight_Arm", Vector3(0.9, 0.07, 0.07), Vector3(0.36, 4.12, 0.0), metal)
	_box(light_root, "Streetlight_Lamp", Vector3(0.42, 0.12, 0.28), Vector3(0.72, 4.02, 0.0), lamp)

func _add_tree(position: Vector3, trunk_material: Material, leaf_a: Material, leaf_b: Material) -> void:
	var tree := Node3D.new()
	tree.position = position
	add_child(tree)
	_cylinder(tree, "Tree_Trunk", 0.13, 0.18, 1.55, Vector3(0.0, 0.78, 0.0), trunk_material)
	_sphere(tree, "Tree_Canopy_Lower", 0.88, Vector3(0.0, 1.85, 0.0), leaf_a)
	_sphere(tree, "Tree_Canopy_Upper", 0.62, Vector3(0.0, 2.55, 0.0), leaf_b)

func _make_car(index: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Traffic_Car_%02d" % (index + 1)
	var body_colors := [Color("#b84e3d"), Color("#d6d8d5"), Color("#315d79"), Color("#c5a65c"), Color("#3f494d")]
	var body := _mat(body_colors[index % body_colors.size()], 0.34, 0.28)
	var glass := _mat(Color("#253f4c"), 0.2, 0.18)
	var rubber := _mat(Color("#202528"), 0.92)
	_box(car, "Car_Body", Vector3(1.65, 0.48, 0.82), Vector3(0.0, 0.48, 0.0), body)
	_box(car, "Car_Cabin", Vector3(0.88, 0.43, 0.68), Vector3(-0.08, 0.91, 0.0), glass)
	for side in [-1.0, 1.0]:
		for axle in [-0.52, 0.52]:
			var wheel := _cylinder(car, "Car_Wheel", 0.22, 0.22, 0.14, Vector3(axle, 0.24, side * 0.42), rubber)
			wheel.rotation.x = PI * 0.5
	return car

func _make_pedestrian(index: int) -> Dictionary:
	var person := Node3D.new()
	person.name = "Pedestrian_%02d" % (index + 1)
	var clothes_colors := [Color("#355b72"), Color("#7b5947"), Color("#526b4d"), Color("#8a6c85")]
	var clothes := _mat(clothes_colors[index % clothes_colors.size()], 0.88)
	var skin := _mat(Color("#986b50"), 0.9)
	var trousers := _mat(Color("#343b42"), 0.94)
	_sphere(person, "Pedestrian_Head", 0.16, Vector3(0.0, 1.45, 0.0), skin)
	_capsule(person, "Pedestrian_Torso", 0.19, 0.62, Vector3(0.0, 0.98, 0.0), clothes)
	var left_leg := _capsule(person, "Pedestrian_Left_Leg", 0.07, 0.42, Vector3(-0.09, 0.48, 0.0), trousers)
	var right_leg := _capsule(person, "Pedestrian_Right_Leg", 0.07, 0.42, Vector3(0.09, 0.48, 0.0), trousers)
	var left_arm := _capsule(person, "Pedestrian_Left_Arm", 0.055, 0.4, Vector3(-0.23, 1.0, 0.0), clothes)
	var right_arm := _capsule(person, "Pedestrian_Right_Arm", 0.055, 0.4, Vector3(0.23, 1.0, 0.0), clothes)
	return {"node": person, "left_leg": left_leg, "right_leg": right_leg, "left_arm": left_arm, "right_arm": right_arm, "speed": 0.65 + float(index % 4) * 0.12, "phase": float(index) * 0.7}

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
				pinch_distance = (points[0] as Vector2).distance_to(points[1] as Vector2)
				last_touch_midpoint = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
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
