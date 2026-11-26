extends Node3D

signal back_requested

const JoystickScript = preload("res://scripts/world/campus_joystick.gd")

const CAMPUS_WIDTH := 800.0
const CAMPUS_DEPTH := 600.0
const HALF_WIDTH := CAMPUS_WIDTH * 0.5
const HALF_DEPTH := CAMPUS_DEPTH * 0.5
const WALK_SPEED := 1.5
const GRAVITY := 9.8
const FIRST_PERSON_EYE_HEIGHT := 1.62
const CAMERA_SENSITIVITY := 0.0055
const GRASS_INSTANCE_COUNT := 7600
const MAINTAINED_GRASS_RATIO := 0.72
const NEAR_PLAYER_GRASS_COUNT := 900
const NEAR_PLAYER_GRASS_RADIUS := 6.5
const NEAR_PLAYER_GRASS_UPDATE_DISTANCE := 1.25

var player: CharacterBody3D
var player_camera: Camera3D
var movement_joystick: Control
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var body_visual: Node3D
var head_visual: Node3D
var near_player_grass: MultiMeshInstance3D
var near_player_grass_center := Vector3.INF

var camera_yaw := PI * 0.25
var camera_pitch := 0.0
var camera_touch_index := -1
var mouse_look_active := false
var walking_phase := 0.0


func _ready() -> void:
	set_meta("map_dimensions", Vector2(CAMPUS_WIDTH, CAMPUS_DEPTH))
	set_meta("map_area_square_metres", CAMPUS_WIDTH * CAMPUS_DEPTH)
	set_meta("walk_speed_metres_per_second", WALK_SPEED)
	set_meta("camera_perspective", "first_person_hybrid")
	_build_environment()
	_build_terrain()
	_build_player()
	_build_camera()
	_build_overlay()
	_update_camera()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var movement := Vector2.ZERO
	if is_instance_valid(movement_joystick):
		var joystick_value: Variant = movement_joystick.call("get_value")
		if joystick_value is Vector2:
			movement = joystick_value

	if movement.length() < 0.05:
		movement = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	var forward := Vector3(sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, sin(camera_yaw))
	var move_direction := right * movement.x + forward * movement.y
	var input_strength := minf(movement.length(), 1.0)
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	player.velocity.x = move_direction.x * WALK_SPEED * input_strength
	player.velocity.z = move_direction.z * WALK_SPEED * input_strength
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = -0.2

	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -HALF_WIDTH + 1.0, HALF_WIDTH - 1.0)
	player.global_position.z = clampf(player.global_position.z, -HALF_DEPTH + 1.0, HALF_DEPTH - 1.0)
	_update_near_player_grass()

	player.rotation.y = -camera_yaw
	var is_walking := input_strength > 0.08 and move_direction.length_squared() > 0.01
	if is_walking:
		walking_phase += delta * 7.0 * input_strength
	else:
		walking_phase = lerpf(walking_phase, 0.0, minf(1.0, delta * 4.0))
	_update_character_animation(is_walking, input_strength)


func _process(_delta: float) -> void:
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var camera_start_x := maxf(220.0, viewport_width * 0.52)

	if event is InputEventScreenTouch:
		if event.pressed and event.position.x >= camera_start_x:
			camera_touch_index = event.index
		elif not event.pressed and event.index == camera_touch_index:
			camera_touch_index = -1
	elif event is InputEventScreenDrag and event.index == camera_touch_index:
		_rotate_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_look_active = event.pressed and event.position.x >= camera_start_x
	elif event is InputEventMouseMotion and mouse_look_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_rotate_camera(event.relative)


func _rotate_camera(delta_position: Vector2) -> void:
	camera_yaw += delta_position.x * CAMERA_SENSITIVITY
	camera_pitch = clampf(camera_pitch + delta_position.y * CAMERA_SENSITIVITY * 0.72, -0.45, 1.25)


func _update_camera() -> void:
	if not is_instance_valid(player_camera) or not is_instance_valid(player):
		return
	player_camera.global_position = player.global_position + Vector3.UP * FIRST_PERSON_EYE_HEIGHT
	var look_direction := Vector3(
		sin(camera_yaw) * cos(camera_pitch),
		-sin(camera_pitch),
		-cos(camera_yaw) * cos(camera_pitch)
	)
	player_camera.look_at(player_camera.global_position + look_direction, Vector3.UP)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "Campus_World_Environment"
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#58758d")
	sky_material.sky_horizon_color = Color("#c5d0d0")
	sky_material.ground_bottom_color = Color("#39493a")
	sky_material.ground_horizon_color = Color("#aab7a8")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d5ddce")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Soft_Daylight"
	sun.rotation_degrees = Vector3(-43.0, -32.0, 0.0)
	sun.light_color = Color("#fff0d9")
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 82.0
	add_child(sun)


func _build_terrain() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.set_meta("grass_layout", "hybrid_maintained_core_natural_perimeter")
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(CAMPUS_WIDTH, CAMPUS_DEPTH)
	terrain_mesh.subdivide_width = 64
	terrain_mesh.subdivide_depth = 48
	terrain.mesh = terrain_mesh

	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_texture = _create_grass_texture()
	grass_material.roughness = 1.0
	grass_material.uv1_scale = Vector3(42.0, 1.0, 32.0)
	grass_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	terrain.material_override = grass_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(terrain)

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollider"
	ground_body.position.y = -0.5
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(CAMPUS_WIDTH, 1.0, CAMPUS_DEPTH)
	ground_shape.shape = ground_box
	ground_body.add_child(ground_shape)
	add_child(ground_body)

	_add_grass_instances()
	_build_campus_trees()


func _create_grass_texture() -> Texture2D:
	var image := Image.create(512, 512, false, Image.FORMAT_RGB8)
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 4817
	broad_noise.frequency = 0.012
	broad_noise.fractal_octaves = 4
	var mid_noise := FastNoiseLite.new()
	mid_noise.seed = 9127
	mid_noise.frequency = 0.075
	mid_noise.fractal_octaves = 3
	var fine_noise := FastNoiseLite.new()
	fine_noise.seed = 7319
	fine_noise.frequency = 0.34
	for y in range(512):
		for x in range(512):
			var broad := broad_noise.get_noise_2d(float(x), float(y))
			var mid := mid_noise.get_noise_2d(float(x), float(y))
			var fine := fine_noise.get_noise_2d(float(x), float(y))
			var patch := clampf(0.54 + broad * 0.23 + mid * 0.14, 0.0, 1.0)
			var dry_tone := maxf(0.0, mid - 0.18) * 0.08
			var micro := fine * 0.025
			var color := Color(
				0.075 + patch * 0.050 + dry_tone * 0.55 + micro * 0.42,
				0.175 + patch * 0.115 - dry_tone * 0.16 + micro,
				0.038 + patch * 0.040 + dry_tone * 0.16 + micro * 0.25
			)
			image.set_pixel(x, y, color)

	var rng := RandomNumberGenerator.new()
	rng.seed = 490217
	for blade_index in range(9000):
		var start_x := rng.randi_range(0, 511)
		var start_y := rng.randi_range(0, 511)
		var blade_length := rng.randi_range(3, 11)
		var drift := rng.randf_range(-1.5, 1.5)
		var blade_tone := rng.randf_range(0.78, 1.22)
		var light_blade := rng.randf() > 0.44
		for step in range(blade_length):
			var px := wrapi(start_x + roundi(drift * float(step) / float(blade_length)), 0, 512)
			var py := wrapi(start_y + step, 0, 512)
			var old_color := image.get_pixel(px, py)
			var blade_color := Color(0.25, 0.38, 0.13) if light_blade else Color(0.08, 0.19, 0.035)
			image.set_pixel(px, py, old_color.lerp(blade_color * blade_tone, 0.42))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _add_grass_instances() -> void:
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color.WHITE
	blade_material.vertex_color_use_as_albedo = true
	blade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var blade_mesh := _create_grass_clump_mesh(blade_material, 0.19, 8)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = blade_mesh
	multi.instance_count = GRASS_INSTANCE_COUNT

	var rng := RandomNumberGenerator.new()
	rng.seed = 260911
	var maintained_count := int(float(GRASS_INSTANCE_COUNT) * MAINTAINED_GRASS_RATIO)
	for index in range(GRASS_INSTANCE_COUNT):
		var is_maintained := index < maintained_count
		var x: float
		var z: float
		if is_maintained:
			x = rng.randf_range(-HALF_WIDTH * 0.38, HALF_WIDTH * 0.38)
			z = rng.randf_range(-HALF_DEPTH * 0.38, HALF_DEPTH * 0.38)
		else:
			var edge := rng.randi_range(0, 3)
			if edge == 0:
				x = rng.randf_range(-HALF_WIDTH + 2.0, HALF_WIDTH - 2.0)
				z = rng.randf_range(-HALF_DEPTH + 2.0, -HALF_DEPTH * 0.34)
			elif edge == 1:
				x = rng.randf_range(-HALF_WIDTH + 2.0, HALF_WIDTH - 2.0)
				z = rng.randf_range(HALF_DEPTH * 0.34, HALF_DEPTH - 2.0)
			elif edge == 2:
				x = rng.randf_range(-HALF_WIDTH + 2.0, -HALF_WIDTH * 0.38)
				z = rng.randf_range(-HALF_DEPTH * 0.34, HALF_DEPTH * 0.34)
			else:
				x = rng.randf_range(HALF_WIDTH * 0.38, HALF_WIDTH - 2.0)
				z = rng.randf_range(-HALF_DEPTH * 0.34, HALF_DEPTH * 0.34)

		var scale_value := rng.randf_range(0.72, 0.98) if is_maintained else rng.randf_range(1.25, 2.05)
		var grass_transform_basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		multi.set_instance_transform(index, Transform3D(grass_transform_basis, Vector3(x, 0.012, z)))
		var shade := rng.randf_range(0.90, 1.08) if is_maintained else rng.randf_range(0.72, 1.12)
		var tint := Color(0.78, 0.94, 0.68, 1.0) if is_maintained else Color(0.74, 0.91, 0.61, 1.0)
		multi.set_instance_color(index, Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0))

	var grass := MultiMeshInstance3D.new()
	grass.name = "Hybrid_Grass_Clumps"
	grass.multimesh = multi
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	grass.set_meta("instance_count", GRASS_INSTANCE_COUNT)
	grass.set_meta("maintained_core_instance_count", maintained_count)
	grass.set_meta("natural_edge_instance_count", GRASS_INSTANCE_COUNT - maintained_count)
	add_child(grass)

	near_player_grass = MultiMeshInstance3D.new()
	near_player_grass.name = "NearPlayer_Grass"
	var near_multi := MultiMesh.new()
	near_multi.transform_format = MultiMesh.TRANSFORM_3D
	near_multi.use_colors = true
	near_multi.mesh = _create_near_grass_mesh(blade_material)
	near_multi.instance_count = NEAR_PLAYER_GRASS_COUNT
	near_player_grass.multimesh = near_multi
	near_player_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	near_player_grass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	near_player_grass.set_meta("follows_player", true)
	add_child(near_player_grass)
	_update_near_player_grass(true)

func _create_near_grass_mesh(material: Material) -> ArrayMesh:
	return _create_grass_clump_mesh(material, 0.30, 9)


func _create_grass_clump_mesh(material: Material, max_height: float, blade_count: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var rng := RandomNumberGenerator.new()
	rng.seed = blade_count * 731 + roundi(max_height * 1000.0)
	for blade_index in range(blade_count):
		var angle := TAU * float(blade_index) / float(blade_count) + rng.randf_range(-0.24, 0.24)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-direction.z, 0.0, direction.x)
		var base := direction * rng.randf_range(0.0, 0.022)
		var height := rng.randf_range(max_height * 0.62, max_height)
		var bend := direction * rng.randf_range(0.025, 0.085) + side * rng.randf_range(-0.025, 0.025)
		var width := rng.randf_range(0.010, 0.018)
		var base_left := base - side * width
		var base_right := base + side * width
		var middle := base + bend * 0.42 + Vector3.UP * height * 0.56
		var middle_width := width * 0.58
		var middle_left := middle - side * middle_width
		var middle_right := middle + side * middle_width
		var tip := base + bend + Vector3.UP * height
		var tip_left := tip - side * 0.0015
		var tip_right := tip + side * 0.0015
		var brightness := rng.randf_range(0.82, 1.16)
		var root_color := Color(0.12, 0.25, 0.07, 1.0) * brightness
		var middle_color := Color(0.31, 0.53, 0.15, 1.0) * brightness
		var tip_color := Color(0.56, 0.68, 0.28, 1.0) * brightness
		_add_grass_quad(surface, base_left, base_right, middle_right, middle_left, root_color, middle_color)
		_add_grass_quad(surface, middle_left, middle_right, tip_right, tip_left, middle_color, tip_color)
	surface.generate_normals()
	return surface.commit()


func _add_grass_quad(surface: SurfaceTool, left_base: Vector3, right_base: Vector3, right_top: Vector3, left_top: Vector3, base_color: Color, top_color: Color) -> void:
	surface.set_color(base_color)
	surface.add_vertex(left_base)
	surface.set_color(base_color)
	surface.add_vertex(right_base)
	surface.set_color(top_color)
	surface.add_vertex(right_top)
	surface.set_color(base_color)
	surface.add_vertex(left_base)
	surface.set_color(top_color)
	surface.add_vertex(right_top)
	surface.set_color(top_color)
	surface.add_vertex(left_top)

func _update_near_player_grass(force: bool = false) -> void:
	if not is_instance_valid(player) or not is_instance_valid(near_player_grass):
		return
	var player_position := player.global_position
	var flat_position := Vector3(player_position.x, 0.0, player_position.z)
	if not force and near_player_grass_center != Vector3.INF and near_player_grass_center.distance_to(flat_position) < NEAR_PLAYER_GRASS_UPDATE_DISTANCE:
		return
	near_player_grass_center = flat_position
	var multi := near_player_grass.multimesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 871203
	for index in range(NEAR_PLAYER_GRASS_COUNT):
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf_range(0.45 * 0.45, NEAR_PLAYER_GRASS_RADIUS * NEAR_PLAYER_GRASS_RADIUS))
		var x := flat_position.x + cos(angle) * radius
		var z := flat_position.z + sin(angle) * radius
		var scale_value := rng.randf_range(0.78, 1.28)
		var basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		multi.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.008, z)))
		var shade := rng.randf_range(0.82, 1.08)
		multi.set_instance_color(index, Color(0.72 * shade, 0.91 * shade, 0.60 * shade, 1.0))


func _build_campus_trees() -> void:
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("#60432e")
	trunk_material.roughness = 0.96
	trunk_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf_material := StandardMaterial3D.new()
	leaf_material.vertex_color_use_as_albedo = true
	leaf_material.roughness = 0.92
	leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var trunk_mesh := _create_tree_trunk_mesh(trunk_material)
	var canopy_mesh := _create_tree_canopy_mesh(leaf_material)
	var positions: Array[Vector3] = []
	for index in range(11):
		var z := lerpf(-238.0, 238.0, float(index) / 10.0)
		positions.append(Vector3(-354.0, 0.0, z))
		positions.append(Vector3(354.0, 0.0, z))
	for index in range(11):
		var x := lerpf(-316.0, 316.0, float(index) / 10.0)
		positions.append(Vector3(x, 0.0, -254.0))
		positions.append(Vector3(x, 0.0, 254.0))

	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = positions.size()
	var canopy_multi := MultiMesh.new()
	canopy_multi.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multi.mesh = canopy_mesh
	canopy_multi.instance_count = positions.size()

	var rng := RandomNumberGenerator.new()
	rng.seed = 72519
	for index in range(positions.size()):
		var size_x := rng.randf_range(0.82, 1.18)
		var size_y := rng.randf_range(0.88, 1.24)
		var size_z := rng.randf_range(0.82, 1.18)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size_x, size_y, size_z))
		var transform := Transform3D(basis, positions[index])
		trunk_multi.set_instance_transform(index, transform)
		canopy_multi.set_instance_transform(index, transform)

	var trunks := MultiMeshInstance3D.new()
	trunks.name = "Campus_Tree_Trunks"
	trunks.multimesh = trunk_multi
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	trunks.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	trunks.set_meta("tree_count", positions.size())
	add_child(trunks)

	var canopies := MultiMeshInstance3D.new()
	canopies.name = "Campus_Tree_Canopies"
	canopies.multimesh = canopy_multi
	canopies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	canopies.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	canopies.set_meta("tree_count", positions.size())
	add_child(canopies)


func _create_tree_trunk_mesh(material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	_append_tapered_branch(surface, Vector3.ZERO, Vector3(0.0, 4.35, 0.0), 0.22, 0.095, 9)
	for branch_index in range(7):
		var angle := TAU * float(branch_index) / 7.0
		var start_height := 2.05 + float(branch_index % 3) * 0.40
		var end_height := 3.45 + float(branch_index % 2) * 0.55
		var end_position := Vector3(cos(angle) * rngless_branch_length(branch_index), end_height, sin(angle) * rngless_branch_length(branch_index))
		_append_tapered_branch(surface, Vector3(0.0, start_height, 0.0), end_position, 0.095, 0.025, 6)
	surface.generate_normals()
	return surface.commit()


func rngless_branch_length(branch_index: int) -> float:
	return 0.92 + float((branch_index * 37) % 5) * 0.10


func _append_tapered_branch(surface: SurfaceTool, start: Vector3, finish: Vector3, start_radius: float, end_radius: float, side_count: int) -> void:
	var axis := (finish - start).normalized()
	var tangent := axis.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = axis.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := axis.cross(tangent).normalized()
	var start_ring: Array[Vector3] = []
	var end_ring: Array[Vector3] = []
	for side_index in range(side_count):
		var angle := TAU * float(side_index) / float(side_count)
		var radial := tangent * cos(angle) + bitangent * sin(angle)
		start_ring.append(start + radial * start_radius)
		end_ring.append(finish + radial * end_radius)
	for side_index in range(side_count):
		var next_index := (side_index + 1) % side_count
		surface.add_vertex(start_ring[side_index])
		surface.add_vertex(end_ring[side_index])
		surface.add_vertex(end_ring[next_index])
		surface.add_vertex(start_ring[side_index])
		surface.add_vertex(end_ring[next_index])
		surface.add_vertex(start_ring[next_index])


func _create_tree_canopy_mesh(material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var centers := [
		Vector3(0.0, 4.45, 0.0),
		Vector3(0.83, 3.95, 0.22),
		Vector3(-0.82, 4.02, -0.18),
		Vector3(0.18, 4.12, 0.92),
		Vector3(-0.12, 4.08, -0.95),
		Vector3(0.72, 4.55, -0.58),
		Vector3(-0.72, 4.48, 0.56)
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 18731
	for index in range(centers.size()):
		var size := rng.randf_range(0.88, 1.12)
		var radii := Vector3(1.12, 0.82, 1.06) * size
		var green_variation := rng.randf_range(0.84, 1.12)
		var leaf_color := Color(0.16, 0.34, 0.105, 1.0) * green_variation
		_append_leaf_cluster(surface, centers[index], radii, leaf_color)
	surface.generate_normals()
	return surface.commit()


func _append_leaf_cluster(surface: SurfaceTool, center: Vector3, radii: Vector3, base_color: Color) -> void:
	const RINGS := 7
	const SIDES := 12
	var points: Array = []
	for ring in range(RINGS + 1):
		var row: Array[Vector3] = []
		var latitude := PI * float(ring) / float(RINGS)
		for side in range(SIDES):
			var longitude := TAU * float(side) / float(SIDES)
			var unit := Vector3(sin(latitude) * cos(longitude), cos(latitude), sin(latitude) * sin(longitude))
			var wobble := 1.0 + sin(longitude * 3.0 + latitude * 4.0) * 0.035 + cos(longitude * 5.0 - latitude * 2.0) * 0.018
			row.append(center + Vector3(unit.x * radii.x, unit.y * radii.y, unit.z * radii.z) * wobble)
		points.append(row)
	for ring in range(RINGS):
		for side in range(SIDES):
			var next_side := (side + 1) % SIDES
			var brightness := 0.90 + float((ring * 7 + side * 3) % 9) * 0.025
			var color := base_color * brightness
			var a: Vector3 = points[ring][side]
			var b: Vector3 = points[ring + 1][side]
			var c: Vector3 = points[ring + 1][next_side]
			var d: Vector3 = points[ring][next_side]
			_add_colored_triangle(surface, a, b, c, color)
			_add_colored_triangle(surface, a, c, d, color)


func _add_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(b)
	surface.set_color(color)
	surface.add_vertex(c)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerCharacter"
	player.position = Vector3(-366.0, 0.0, 266.0)
	player.floor_snap_length = 0.28
	player.safe_margin = 0.04

	var collision := CollisionShape3D.new()
	collision.name = "Humanoid_Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 1.84
	collision.shape = capsule
	collision.position.y = 0.92
	player.add_child(collision)

	body_visual = Node3D.new()
	body_visual.name = "HumanoidVisual"
	player.add_child(body_visual)
	_build_humanoid_visual()
	add_child(player)


func _build_humanoid_visual() -> void:
	var skin := _material(Color("#76513b"), 0.92)
	var shirt := _material(Color("#d1d2c5"), 0.88)
	var trousers := _material(Color("#252e35"), 0.92)
	var shoes := _material(Color("#171b1d"), 0.86)
	var hair := _material(Color("#211b18"), 0.95)
	var eyes := _material(Color("#171411"), 0.48)

	_add_capsule(body_visual, "Torso", 0.245, 0.68, Vector3(0.0, 1.27, 0.20), shirt, 10)
	_add_box(body_visual, "Waist", Vector3(0.43, 0.27, 0.29), Vector3(0.0, 0.91, 0.16), trousers)
	head_visual = Node3D.new()
	head_visual.name = "HeadVisual_FirstPersonHidden"
	body_visual.add_child(head_visual)
	_add_capsule(head_visual, "Neck", 0.075, 0.18, Vector3(0.0, 1.76, 0.0), skin, 8)
	_add_sphere(head_visual, "Head", 0.17, Vector3(0.0, 1.94, 0.0), skin, 16)
	var hair_mesh := _add_sphere(head_visual, "Hair", 0.176, Vector3(0.0, 2.025, 0.018), hair, 16)
	hair_mesh.scale = Vector3(1.0, 0.55, 1.0)
	_add_sphere(head_visual, "Left_Eye", 0.019, Vector3(-0.056, 1.958, -0.153), eyes, 10)
	_add_sphere(head_visual, "Right_Eye", 0.019, Vector3(0.056, 1.958, -0.153), eyes, 10)
	_add_sphere(head_visual, "Nose", 0.026, Vector3(0.0, 1.91, -0.168), skin, 10)
	head_visual.visible = false

	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "Left_Arm_Pivot"
	left_arm_pivot.position = Vector3(-0.29, 1.50, -0.04)
	body_visual.add_child(left_arm_pivot)
	_add_capsule(left_arm_pivot, "Left_Arm", 0.092, 0.70, Vector3(0.0, -0.34, 0.0), shirt, 8)
	_add_sphere(left_arm_pivot, "Left_Hand", 0.09, Vector3(0.0, -0.70, 0.0), skin, 10)

	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "Right_Arm_Pivot"
	right_arm_pivot.position = Vector3(0.29, 1.50, -0.04)
	body_visual.add_child(right_arm_pivot)
	_add_capsule(right_arm_pivot, "Right_Arm", 0.092, 0.70, Vector3(0.0, -0.34, 0.0), shirt, 8)
	_add_sphere(right_arm_pivot, "Right_Hand", 0.09, Vector3(0.0, -0.70, 0.0), skin, 10)

	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "Left_Leg_Pivot"
	left_leg_pivot.position = Vector3(-0.13, 0.86, 0.0)
	body_visual.add_child(left_leg_pivot)
	_add_capsule(left_leg_pivot, "Left_Leg", 0.12, 0.80, Vector3(0.0, -0.37, 0.0), trousers, 8)
	_add_box(left_leg_pivot, "Left_Shoe", Vector3(0.23, 0.12, 0.38), Vector3(0.0, -0.77, -0.045), shoes)

	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "Right_Leg_Pivot"
	right_leg_pivot.position = Vector3(0.13, 0.86, 0.0)
	body_visual.add_child(right_leg_pivot)
	_add_capsule(right_leg_pivot, "Right_Leg", 0.12, 0.80, Vector3(0.0, -0.37, 0.0), trousers, 8)
	_add_box(right_leg_pivot, "Right_Shoe", Vector3(0.23, 0.12, 0.38), Vector3(0.0, -0.77, -0.045), shoes)


func _update_character_animation(is_walking: bool, input_strength: float) -> void:
	if not is_instance_valid(body_visual):
		return
	var stride := sin(walking_phase) * 0.42 * input_strength if is_walking else 0.0
	if is_instance_valid(left_leg_pivot):
		left_leg_pivot.rotation.x = stride
	if is_instance_valid(right_leg_pivot):
		right_leg_pivot.rotation.x = -stride
	if is_instance_valid(left_arm_pivot):
		left_arm_pivot.rotation.x = -stride * 0.78
	if is_instance_valid(right_arm_pivot):
		right_arm_pivot.rotation.x = stride * 0.78
	body_visual.position.y = absf(sin(walking_phase * 2.0)) * 0.025 * input_strength if is_walking else 0.0


func _build_camera() -> void:
	player_camera = Camera3D.new()
	player_camera.name = "PlayerCamera"
	player_camera.fov = 78.0
	player_camera.near = 0.08
	player_camera.far = 500.0
	add_child(player_camera)
	player_camera.make_current()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Campus_Controls_Layer"
	layer.layer = 30
	add_child(layer)

	var root := Control.new()
	root.name = "CampusOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var back_button := Button.new()
	back_button.name = "BackToMenuButton"
	back_button.text = "‹  MENU"
	back_button.position = Vector2(18.0, 18.0)
	back_button.size = Vector2(128.0, 48.0)
	back_button.custom_minimum_size = Vector2(128.0, 48.0)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_overlay_button(back_button)
	back_button.pressed.connect(_request_back)
	root.add_child(back_button)

	var title := Label.new()
	title.name = "CampusTitle"
	title.text = "COMPANY CAMPUS"
	title.position = Vector2(20.0, 78.0)
	title.size = Vector2(260.0, 28.0)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#f4f2e9"))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "CampusDimensions"
	subtitle.text = "800 × 600 m   •   48 hectares   •   EMPTY LAND PHASE"
	subtitle.position = Vector2(20.0, 106.0)
	subtitle.size = Vector2(330.0, 24.0)
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.91, 0.94, 0.87, 0.88))
	root.add_child(subtitle)

	var look_hint := Label.new()
	look_hint.name = "CameraLookHint"
	look_hint.text = "DRAG RIGHT SIDE TO LOOK"
	look_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	look_hint.offset_left = -230.0
	look_hint.offset_top = 24.0
	look_hint.offset_right = -18.0
	look_hint.offset_bottom = 48.0
	look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	look_hint.add_theme_font_size_override("font_size", 11)
	look_hint.add_theme_color_override("font_color", Color(0.95, 0.95, 0.89, 0.88))
	look_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(look_hint)

	movement_joystick = JoystickScript.new() as Control
	movement_joystick.name = "MovementJoystick"
	movement_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	movement_joystick.offset_left = 22.0
	movement_joystick.offset_top = -218.0
	movement_joystick.offset_right = 218.0
	movement_joystick.offset_bottom = -22.0
	movement_joystick.custom_minimum_size = Vector2(196.0, 196.0)
	root.add_child(movement_joystick)


func _style_overlay_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.055, 0.045, 0.78)
		style.border_color = Color(0.83, 0.87, 0.77, 0.55)
		if state == "hover":
			style.bg_color = Color(0.12, 0.17, 0.12, 0.94)
		elif state == "pressed":
			style.bg_color = Color(0.20, 0.25, 0.17, 0.96)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f4f2e9"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 13)


func _request_back() -> void:
	back_requested.emit()


func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 6
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, radius: float, local_position: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 8
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance


func _add_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
