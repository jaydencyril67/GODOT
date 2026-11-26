extends Node3D

signal back_requested
signal worksite_launch_requested(worksite_id: String)
signal research_launch_requested(research_id: String)
signal staff_launch_requested(staff_screen_id: String)

const JoystickScript = preload("res://scripts/world/campus_joystick.gd")
const OSPhoneModelScript = preload("res://scripts/os_worksite_phone_model.gd")

const CAMPUS_WIDTH := 800.0
const CAMPUS_DEPTH := 600.0
const HALF_WIDTH := CAMPUS_WIDTH * 0.5
const HALF_DEPTH := CAMPUS_DEPTH * 0.5
const WALK_SPEED := 1.5
const GRAVITY := 9.8
const FIRST_PERSON_EYE_HEIGHT := 1.62
const CAMERA_SENSITIVITY := 0.0055
const PHONE_BUTTON_SIZE := Vector2(54.0, 54.0)
const PHONE_BODY_ASPECT_RATIO := 1.45 / 2.92
const PHONE_BODY_HEIGHT_RATIO := 0.98
const PHONE_BODY_EDGE_MARGIN := 4.0
const PHONE_BODY_BUTTON_GAP := 26.0
const PHONE_BUTTON_STACK_GAP := 10.0
const PHONE_BODY_LEFT_CLEARANCE := 230.0
const GRASS_INSTANCE_COUNT := 7600
const MAINTAINED_GRASS_RATIO := 0.72
const NEAR_PLAYER_GRASS_COUNT := 900
const NEAR_PLAYER_GRASS_RADIUS := 6.5
const NEAR_PLAYER_GRASS_UPDATE_DISTANCE := 1.25

const CAMPUS_SECTION_NAMES := [
	"Main Entrance, Security & Reception",
	"Administration & Corporate Offices",
	"Staff Facilities, Cafeteria & Recreation",
	"Parking, Roads & Transport",
	"Research & Technology",
	"Production & Operations",
	"Logistics, Warehouses & Loading",
	"Landscaping, Green Spaces & Utilities"
]
const CAMPUS_SECTION_SHORT_NAMES := [
	"Main Entrance & Reception",
	"Corporate Offices",
	"Staff & Recreation",
	"Parking & Transport",
	"Research & Technology",
	"Production & Operations",
	"Logistics & Warehouses",
	"Green Spaces & Utilities"
]
const CAMPUS_SECTION_SIGN_TEXT := [
	"MAIN ENTRANCE\n& RECEPTION",
	"ADMINISTRATION\n& CORPORATE OFFICES",
	"STAFF QUARTERS\n& FACILITIES",
	"PARKING\n& TRANSPORT",
	"RESEARCH\n& TECHNOLOGY",
	"PRODUCTION\n& OPERATIONS",
	"LOGISTICS\n& WAREHOUSES",
	"LANDSCAPING\n& UTILITIES"
]
const SECTION_COLUMN_CENTERS := [-300.0, -100.0, 100.0, 300.0]
const SECTION_ROW_CENTERS := [150.0, -150.0]
const SECTION_HALF_WIDTH := 94.0
const SECTION_HALF_DEPTH := 144.0
const SECTION_GATE_WIDTH := 8.0

var player: CharacterBody3D
var player_camera: Camera3D
var movement_joystick: Control
var overlay_root: Control
var phone_button: Button
var phone_control_buttons: Array[Button] = []
var phone_device: SubViewportContainer
var phone_viewport: SubViewport
var phone_model: Node3D
var phone_screen_ui: Panel
var phone_home_view: Control
var explore_app_view: Control
var explore_status_label: Label
var explore_section_buttons: Array[Button] = []
var phone_app_views: Dictionary = {}
var worksite_app_buttons: Array[Button] = []
var research_app_buttons: Array[Button] = []
var staffs_app_buttons: Array[Button] = []
var near_player_grass: MultiMeshInstance3D
var near_player_grass_center := Vector3.INF

var camera_yaw := PI * 0.25
var camera_pitch := 0.0
var camera_touch_index := -1
var mouse_look_active := false


func _ready() -> void:
	set_meta("map_dimensions", Vector2(CAMPUS_WIDTH, CAMPUS_DEPTH))
	set_meta("map_area_square_metres", CAMPUS_WIDTH * CAMPUS_DEPTH)
	set_meta("walk_speed_metres_per_second", WALK_SPEED)
	set_meta("movement_response", "direct_analog_slide_no_acceleration_ramp")
	set_meta("camera_perspective", "first_person_eye_only")
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

	var horizontal_velocity := _calculate_horizontal_velocity(movement)
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.z
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = -0.2

	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -HALF_WIDTH + 1.0, HALF_WIDTH - 1.0)
	player.global_position.z = clampf(player.global_position.z, -HALF_DEPTH + 1.0, HALF_DEPTH - 1.0)
	_update_near_player_grass()

	player.rotation.y = -camera_yaw


func _calculate_horizontal_velocity(movement: Vector2) -> Vector3:
	var input_strength := minf(movement.length(), 1.0)
	if input_strength <= 0.001:
		return Vector3.ZERO

	var forward := Vector3(sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, sin(camera_yaw))
	var move_direction := right * movement.x + forward * movement.y
	if move_direction.length_squared() <= 0.000001:
		return Vector3.ZERO

	# Normalize direction first, then apply analog strength once. This keeps
	# partial joystick input linear instead of squaring its magnitude.
	return move_direction.normalized() * WALK_SPEED * input_strength


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
	sky_material.sky_top_color = Color("#3e82bd")
	sky_material.sky_horizon_color = Color("#b9d7ed")
	sky_material.ground_bottom_color = Color("#34483b")
	sky_material.ground_horizon_color = Color("#a9b9aa")
	sky_material.sky_curve = 0.16
	sky_material.sky_energy_multiplier = 1.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Soft_Daylight"
	sun.rotation_degrees = Vector3(-43.0, -32.0, 0.0)
	sun.light_color = Color("#fff1dc")
	sun.light_energy = 1.24
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)

	_build_cloud_layer()


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
	grass_material.uv1_scale = Vector3(42.0, 32.0, 1.0)
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
	_build_campus_sections()



func _build_cloud_layer() -> void:
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color.WHITE
	cloud_material.vertex_color_use_as_albedo = true
	cloud_material.roughness = 1.0
	cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 12
	cloud_mesh.rings = 6
	cloud_mesh.material = cloud_material

	var cloud_multi := MultiMesh.new()
	cloud_multi.transform_format = MultiMesh.TRANSFORM_3D
	cloud_multi.use_colors = true
	cloud_multi.mesh = cloud_mesh
	var cloud_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	const CLOUD_CLUSTER_COUNT := 22

	for cloud_index in range(CLOUD_CLUSTER_COUNT):
		var center := Vector3(
			rng.randf_range(-455.0, 455.0),
			rng.randf_range(94.0, 132.0),
			rng.randf_range(-390.0, 390.0)
		)
		var puff_count := rng.randi_range(6, 8)
		var cloud_yaw := rng.randf_range(0.0, TAU)
		var along_axis := Vector3(cos(cloud_yaw), 0.0, sin(cloud_yaw))
		var across_axis := Vector3(-along_axis.z, 0.0, along_axis.x)
		var cloud_span := rng.randf_range(24.0, 38.0)

		for puff_index in range(puff_count):
			var centered_index := float(puff_index) - float(puff_count - 1) * 0.5
			var along := centered_index * cloud_span / float(puff_count - 1)
			var puff_position := center
			puff_position += along_axis * along
			puff_position += across_axis * rng.randf_range(-5.5, 5.5)
			puff_position.y += rng.randf_range(-2.2, 2.2)

			var puff_scale := Vector3(
				rng.randf_range(8.0, 13.5),
				rng.randf_range(3.5, 5.8),
				rng.randf_range(6.5, 10.5)
			)
			var cloud_basis := Basis.IDENTITY.scaled(puff_scale)
			cloud_transforms.append(Transform3D(cloud_basis, puff_position))

	cloud_multi.instance_count = cloud_transforms.size()
	for index in range(cloud_transforms.size()):
		cloud_multi.set_instance_transform(index, cloud_transforms[index])
		var brightness := rng.randf_range(0.91, 1.0)
		cloud_multi.set_instance_color(index, Color(brightness, brightness, minf(1.0, brightness + 0.015), 1.0))

	var clouds := MultiMeshInstance3D.new()
	clouds.name = "Campus_Clouds"
	clouds.multimesh = cloud_multi
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clouds.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	clouds.set_meta("cloud_cluster_count", CLOUD_CLUSTER_COUNT)
	clouds.set_meta("cloud_puff_count", cloud_transforms.size())
	clouds.set_meta("cloud_layer_height_range", Vector2(94.0, 132.0))
	add_child(clouds)


func _build_campus_sections() -> void:
	var section_root := Node3D.new()
	section_root.name = "Campus_Sections"
	section_root.set_meta("section_count", CAMPUS_SECTION_NAMES.size())
	section_root.set_meta("layout", "four_columns_two_rows")
	add_child(section_root)

	var fence_root := Node3D.new()
	fence_root.name = "Campus_Wooden_Fences"
	fence_root.set_meta("wooden_fence", true)
	fence_root.set_meta("gate_opening_width_metres", SECTION_GATE_WIDTH)
	add_child(fence_root)

	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color("#67452e")
	post_material.roughness = 0.94
	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = Color("#8a5b38")
	rail_material.roughness = 0.92
	var sign_board_material := StandardMaterial3D.new()
	sign_board_material.albedo_color = Color("#503522")
	sign_board_material.roughness = 0.92
	var sign_support_material := StandardMaterial3D.new()
	sign_support_material.albedo_color = Color("#69452d")
	sign_support_material.roughness = 0.94

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3.ONE
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3.ONE
	var picket_mesh := BoxMesh.new()
	picket_mesh.size = Vector3(0.16, 1.18, 0.10)
	var post_transforms: Array[Transform3D] = []
	var rail_transforms: Array[Transform3D] = []
	var picket_transforms: Array[Transform3D] = []

	var fence_collisions := StaticBody3D.new()
	fence_collisions.name = "Fence_Collisions"
	fence_collisions.collision_layer = 1
	fence_collisions.collision_mask = 1
	fence_collisions.set_meta("blocks_player", true)
	fence_collisions.set_meta("collision_layer", 1)
	fence_root.add_child(fence_collisions)

	for section_index in range(CAMPUS_SECTION_NAMES.size()):
		var row_index := floori(float(section_index) / 4.0)
		var column_index := section_index % 4
		var center := Vector3(
			SECTION_COLUMN_CENTERS[column_index],
			0.0,
			SECTION_ROW_CENTERS[row_index]
		)

		var section := Node3D.new()
		section.name = "Section_%02d" % (section_index + 1)
		section.position = center
		section.set_meta("section_number", section_index + 1)
		section.set_meta("section_name", CAMPUS_SECTION_NAMES[section_index])
		section.set_meta("section_bounds_local", Vector4(-SECTION_HALF_WIDTH, -SECTION_HALF_DEPTH, SECTION_HALF_WIDTH, SECTION_HALF_DEPTH))
		section_root.add_child(section)

		var west_start := center + Vector3(-SECTION_HALF_WIDTH, 0.0, -SECTION_HALF_DEPTH)
		var east_start := center + Vector3(SECTION_HALF_WIDTH, 0.0, -SECTION_HALF_DEPTH)
		var north_start := center + Vector3(-SECTION_HALF_WIDTH, 0.0, -SECTION_HALF_DEPTH)
		var south_start := center + Vector3(-SECTION_HALF_WIDTH, 0.0, SECTION_HALF_DEPTH)
		_append_fence_side(post_transforms, rail_transforms, picket_transforms, fence_collisions, west_start, Vector3(0.0, 0.0, 1.0), SECTION_HALF_DEPTH * 2.0)
		_append_fence_side(post_transforms, rail_transforms, picket_transforms, fence_collisions, east_start, Vector3(0.0, 0.0, 1.0), SECTION_HALF_DEPTH * 2.0)
		_append_fence_side(post_transforms, rail_transforms, picket_transforms, fence_collisions, north_start, Vector3.RIGHT, SECTION_HALF_WIDTH * 2.0)
		_append_fence_side(post_transforms, rail_transforms, picket_transforms, fence_collisions, south_start, Vector3.RIGHT, SECTION_HALF_WIDTH * 2.0)
		_build_section_sign(section, CAMPUS_SECTION_SIGN_TEXT[section_index], sign_board_material, sign_support_material)
	var picket_material := StandardMaterial3D.new()
	picket_material.albedo_color = Color("#a87549")
	picket_material.roughness = 0.93
	var posts := _add_fence_multimesh(fence_root, "Fence_Posts", post_mesh, post_material, post_transforms)
	var rails := _add_fence_multimesh(fence_root, "Fence_Rails", rail_mesh, rail_material, rail_transforms)
	var pickets := _add_fence_multimesh(fence_root, "Fence_Vertical_Pickets", picket_mesh, picket_material, picket_transforms)
	posts.set_meta("fence_component", "structural_posts")
	rails.set_meta("fence_component", "horizontal_rails")
	pickets.set_meta("fence_component", "vertical_pickets")
	fence_root.set_meta("fence_style", "hybrid_post_rail_vertical_picket")
	fence_root.set_meta("post_count", post_transforms.size())
	fence_root.set_meta("rail_segment_count", rail_transforms.size())
	fence_root.set_meta("picket_count", picket_transforms.size())
	fence_root.set_meta("collision_segment_count", fence_collisions.get_child_count())


func _append_fence_side(
	post_transforms: Array[Transform3D],
	rail_transforms: Array[Transform3D],
	picket_transforms: Array[Transform3D],
	fence_collisions: StaticBody3D,
	start: Vector3,
	direction: Vector3,
	length: float
) -> void:
	var normalized_direction := direction.normalized()
	var gate_start := (length - SECTION_GATE_WIDTH) * 0.5
	var gate_end := gate_start + SECTION_GATE_WIDTH
	var segments := [
		Vector2(0.0, gate_start),
		Vector2(gate_end, length)
	]
	var yaw := 0.0 if absf(normalized_direction.x) > 0.5 else PI * 0.5

	for segment in segments:
		var segment_start: float = segment.x
		var segment_end: float = segment.y
		var segment_length := segment_end - segment_start
		if segment_length <= 0.5:
			continue

		var segment_center := start + normalized_direction * ((segment_start + segment_end) * 0.5)
		for rail_height in [0.38, 1.08]:
			var rail_basis := Basis(Vector3.UP, yaw).scaled(Vector3(segment_length, 0.16, 0.18))
			rail_transforms.append(Transform3D(rail_basis, segment_center + Vector3.UP * rail_height))

		var picket_spacing := 0.34
		var picket_count := maxi(1, ceili(segment_length / picket_spacing))
		for picket_index in range(picket_count):
			var picket_distance := minf(segment_length - 0.10, (float(picket_index) + 0.5) * segment_length / float(picket_count))
			var picket_position := start + normalized_direction * (segment_start + picket_distance) + Vector3.UP * 0.76
			var picket_basis := Basis(Vector3.UP, yaw)
			picket_transforms.append(Transform3D(picket_basis, picket_position))

		var post_steps := maxi(1, ceili(segment_length / 3.4))
		for post_index in range(post_steps + 1):
			var post_distance := lerpf(segment_start, segment_end, float(post_index) / float(post_steps))
			var post_position := start + normalized_direction * post_distance + Vector3.UP * 0.72
			var post_basis := Basis(Vector3.UP, yaw).scaled(Vector3(0.20, 1.44, 0.20))
			post_transforms.append(Transform3D(post_basis, post_position))

		var fence_shape := CollisionShape3D.new()
		fence_shape.name = "Fence_Wall_Collision"
		var fence_box := BoxShape3D.new()
		fence_box.size = Vector3(segment_length, 1.52, 0.30)
		fence_shape.shape = fence_box
		fence_shape.position = segment_center + Vector3.UP * 0.76
		fence_shape.rotation.y = yaw
		fence_collisions.add_child(fence_shape)


func _add_fence_multimesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.set_meta("instance_count", transforms.size())
	parent.add_child(instance)
	return instance


func _build_section_sign(
	section: Node3D,
	sign_text: String,
	board_material: Material,
	support_material: Material
) -> void:
	var sign_root := Node3D.new()
	sign_root.name = "SectionSign"
	section.add_child(sign_root)

	var sign_z := SECTION_HALF_DEPTH + 0.06
	_add_box(sign_root, "Sign_Support_Left", Vector3(0.20, 2.85, 0.22), Vector3(-3.72, 1.425, sign_z), support_material)
	_add_box(sign_root, "Sign_Support_Right", Vector3(0.20, 2.85, 0.22), Vector3(3.72, 1.425, sign_z), support_material)
	_add_box(sign_root, "Wooden_Sign_Board", Vector3(7.55, 1.08, 0.22), Vector3(0.0, 2.43, sign_z), board_material)

	var label := Label3D.new()
	label.name = "SectionName"
	label.text = sign_text
	label.font_size = 46
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color("#fff0d5")
	label.outline_modulate = Color("#2d2118")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.rotation.y = PI
	label.position = Vector3(0.0, 2.43, sign_z + 0.13)
	sign_root.add_child(label)


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
		var grass_instance_basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		multi.set_instance_transform(index, Transform3D(grass_instance_basis, Vector3(x, 0.008, z)))
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
		var tree_instance_basis := Basis(Vector3.UP, yaw).scaled(Vector3(size_x, size_y, size_z))
		var tree_instance_transform := Transform3D(tree_instance_basis, positions[index])
		trunk_multi.set_instance_transform(index, tree_instance_transform)
		canopy_multi.set_instance_transform(index, tree_instance_transform)
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
	player.collision_layer = 1
	player.collision_mask = 1
	player.floor_snap_length = 0.28
	player.safe_margin = 0.06

	var collision := CollisionShape3D.new()
	collision.name = "Humanoid_Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 1.84
	collision.shape = capsule
	collision.position.y = 0.92
	player.add_child(collision)
	add_child(player)


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
	overlay_root = root
	root.resized.connect(_layout_phone_controls)

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

	movement_joystick = JoystickScript.new() as Control
	movement_joystick.name = "MovementJoystick"
	movement_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	movement_joystick.offset_left = 22.0
	movement_joystick.offset_top = -218.0
	movement_joystick.offset_right = 218.0
	movement_joystick.offset_bottom = -22.0
	movement_joystick.custom_minimum_size = Vector2(196.0, 196.0)
	root.add_child(movement_joystick)

	_build_phone_controls(root)
	_layout_phone_controls()
	call_deferred("_layout_phone_controls")


func _build_phone_controls(root: Control) -> void:
	phone_control_buttons.clear()

	var first_action_button := _create_phone_control_button(root, "PhoneActionButton1", "···")
	var second_action_button := _create_phone_control_button(root, "PhoneActionButton2", "···")
	phone_button = _create_phone_control_button(root, "PhoneButton", "")
	var fourth_action_button := _create_phone_control_button(root, "PhoneActionButton4", "···")

	first_action_button.set_meta("functionless", true)
	second_action_button.set_meta("functionless", true)
	fourth_action_button.set_meta("functionless", true)
	phone_button.tooltip_text = "Open phone"
	phone_button.set_meta("phone_toggle", true)
	_build_phone_button_icon(phone_button)
	phone_button.pressed.connect(_toggle_phone)

	phone_control_buttons.append(first_action_button)
	phone_control_buttons.append(second_action_button)
	phone_control_buttons.append(phone_button)
	phone_control_buttons.append(fourth_action_button)

	# Use the actual OS Worksite handset model, not a hand-drawn UI substitute.
	# The worksite model supplies its own fixed front-facing camera, metal chassis,
	# true rounded extrusion, inset bezel, dark glass, side keys and bottom hardware.
	phone_device = SubViewportContainer.new()
	phone_device.name = "PhoneDevice"
	phone_device.visible = false
	phone_device.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_device.focus_mode = Control.FOCUS_NONE
	phone_device.stretch = true
	phone_device.set_meta("phone_design", "shared_os_worksite_physical_handset")
	phone_device.set_meta("screen_powered", true)
	phone_device.set_meta("phone_fixed", true)
	phone_device.z_index = 5
	root.add_child(phone_device)

	phone_viewport = SubViewport.new()
	phone_viewport.name = "CampusPhoneModelViewport"
	phone_viewport.size = Vector2i(700, 1400)
	phone_viewport.msaa_3d = Viewport.MSAA_DISABLED
	phone_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	phone_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	phone_viewport.scaling_3d_scale = 1.0
	phone_viewport.own_world_3d = true
	phone_viewport.transparent_bg = true
	phone_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	phone_device.add_child(phone_viewport)

	phone_model = OSPhoneModelScript.new() as Node3D
	phone_model.name = "CampusOSWorksiteHandsetModel"
	phone_model.set_meta("handset_source", "res://scripts/os_worksite_phone_model.gd")
	phone_model.set_meta("rotation_locked", true)
	phone_viewport.add_child(phone_model)
	phone_model.call("build", _create_phone_screen_texture())
	phone_model.rotation = Vector3.ZERO
	_build_phone_screen_ui(root)


func _create_phone_control_button(root: Control, button_name: String, button_text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = button_text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = PHONE_BUTTON_SIZE
	button.size = PHONE_BUTTON_SIZE
	button.tooltip_text = "Reserved control" if button_name != "PhoneButton" else "Open phone"
	_style_phone_button(button)
	if not button_text.is_empty():
		button.add_theme_font_size_override("font_size", 17)
	root.add_child(button)
	return button


func _create_phone_screen_texture() -> Texture2D:
	var image := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		var shade := lerpf(0.055, 0.105, float(y) / float(maxi(image.get_height() - 1, 1)))
		for x in range(image.get_width()):
			image.set_pixel(x, y, Color(shade * 0.78, shade, shade * 1.22, 1.0))
	return ImageTexture.create_from_image(image)


func _build_phone_screen_ui(root: Control) -> void:
	phone_screen_ui = Panel.new()
	phone_screen_ui.name = "PhoneScreenUI"
	phone_screen_ui.visible = false
	phone_screen_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_screen_ui.focus_mode = Control.FOCUS_NONE
	phone_screen_ui.clip_contents = true
	phone_screen_ui.z_index = 8
	phone_screen_ui.set_meta("screen_powered", true)
	phone_screen_ui.set_meta("home_app_count", 4)
	phone_screen_ui.set_meta("active_app", "home")
	phone_screen_ui.add_theme_stylebox_override(
		"panel",
		_make_phone_style(Color("#101923"), Color("#273847"), 1, 34)
	)
	root.add_child(phone_screen_ui)

	phone_home_view = VBoxContainer.new()
	phone_home_view.name = "PhoneHomeScreen"
	phone_home_view.mouse_filter = Control.MOUSE_FILTER_PASS
	phone_home_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phone_home_view.offset_left = 9.0
	phone_home_view.offset_top = 8.0
	phone_home_view.offset_right = -9.0
	phone_home_view.offset_bottom = -8.0
	phone_home_view.add_theme_constant_override("separation", 7)
	phone_screen_ui.add_child(phone_home_view)
	phone_home_view.add_child(_make_phone_status_bar("PhoneHomeStatusBar"))

	var home_heading := Label.new()
	home_heading.name = "PhoneHomeHeading"
	home_heading.text = "Campus"
	home_heading.add_theme_font_size_override("font_size", 21)
	home_heading.add_theme_color_override("font_color", Color("#F4F7FA"))
	phone_home_view.add_child(home_heading)

	var home_subtitle := Label.new()
	home_subtitle.name = "PhoneHomeSubtitle"
	home_subtitle.text = "Your campus, one tap away"
	home_subtitle.add_theme_font_size_override("font_size", 10)
	home_subtitle.add_theme_color_override("font_color", Color("#A9BAC8"))
	phone_home_view.add_child(home_subtitle)

	var app_grid := GridContainer.new()
	app_grid.name = "PhoneHomeAppGrid"
	app_grid.columns = 2
	app_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_grid.add_theme_constant_override("h_separation", 7)
	app_grid.add_theme_constant_override("v_separation", 5)
	app_grid.add_theme_constant_override("margin_left", 2)
	app_grid.add_theme_constant_override("margin_right", 2)
	phone_home_view.add_child(app_grid)

	_add_phone_home_app(app_grid, "Explore", "ExploreAppIcon", "⌖", Callable(self, "_launch_explore_app"))
	_add_phone_home_app(app_grid, "Worksite", "WorksiteAppIcon", "▦", Callable(self, "_launch_worksite_app"))
	_add_phone_home_app(app_grid, "Research", "ResearchAppIcon", "◈", Callable(self, "_launch_research_app"))
	_add_phone_home_app(app_grid, "Staffs", "StaffsAppIcon", "♙", Callable(self, "_launch_staffs_app"))

	var home_footer := Label.new()
	home_footer.name = "PhoneHomeFooter"
	home_footer.text = "DIGITALWORLD CAMPUS"
	home_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_footer.add_theme_font_size_override("font_size", 8)
	home_footer.add_theme_color_override("font_color", Color("#778B9B"))
	phone_home_view.add_child(home_footer)

	var explore_page := _create_phone_app_page(
		"ExploreAppScreen",
		"Explore",
		"Choose a campus section to travel there",
		"ExploreBackToHomeButton"
	)
	explore_app_view = explore_page["page"]
	phone_screen_ui.add_child(explore_app_view)
	phone_app_views["explore"] = explore_app_view
	var explore_list: VBoxContainer = explore_page["list"]
	explore_section_buttons.clear()
	for section_index in range(CAMPUS_SECTION_NAMES.size()):
		var section_button := _create_phone_destination_button(
			explore_list,
			"ExploreSectionButton_%02d" % (section_index + 1),
			"%02d   %s" % [section_index + 1, CAMPUS_SECTION_SHORT_NAMES[section_index]],
			"",
			Callable(self, "_transport_to_campus_section").bind(section_index)
		)
		section_button.tooltip_text = CAMPUS_SECTION_NAMES[section_index]
		section_button.custom_minimum_size.y = 34.0
		section_button.set_meta("campus_section_index", section_index)
		explore_section_buttons.append(section_button)

	explore_status_label = Label.new()
	explore_status_label.name = "ExploreStatusLabel"
	explore_status_label.text = "Select a section to travel there"
	explore_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explore_status_label.custom_minimum_size.y = 24.0
	explore_status_label.add_theme_font_size_override("font_size", 8)
	explore_status_label.add_theme_color_override("font_color", Color("#8FD7D1"))
	explore_app_view.add_child(explore_status_label)

	var worksite_page := _create_phone_app_page(
		"WorksiteAppScreen",
		"Worksite",
		"Choose a workspace to open",
		"WorksiteBackToHomeButton"
	)
	phone_app_views["worksite"] = worksite_page["page"]
	var worksite_list: VBoxContainer = worksite_page["list"]
	worksite_app_buttons.clear()
	var worksite_options := [
		{"id": "phone", "name": "Phone Creation Worksite", "detail": "Design and build phones"},
		{"id": "camera", "name": "Camera Worksite", "detail": "Create camera systems"},
		{"id": "os", "name": "OS Worksite", "detail": "Design the operating system"},
		{"id": "processor", "name": "Processor Worksite", "detail": "Build processor designs"}
	]
	for option in worksite_options:
		var option_id := str(option["id"])
		var worksite_button := _create_phone_destination_button(
			worksite_list,
			"WorksiteOption_" + option_id.capitalize(),
			str(option["name"]),
			str(option["detail"]),
			Callable(self, "_request_worksite_launch").bind(option_id)
		)
		worksite_app_buttons.append(worksite_button)

	var research_page := _create_phone_app_page(
		"ResearchAppScreen",
		"Research",
		"Open a research workspace",
		"ResearchBackToHomeButton"
	)
	phone_app_views["research"] = research_page["page"]
	var research_list: VBoxContainer = research_page["list"]
	research_app_buttons.clear()
	var research_options := [
		{"id": "hub", "name": "Research Hub", "detail": "Browse all research areas"},
		{"id": "phone", "name": "Phone Research", "detail": "Phone technology and components"},
		{"id": "camera", "name": "Camera Research", "detail": "Imaging and camera technology"},
		{"id": "processor", "name": "Processor Research", "detail": "Chip and processor technology"}
	]
	for option in research_options:
		var option_id := str(option["id"])
		var research_button := _create_phone_destination_button(
			research_list,
			"ResearchOption_" + option_id.capitalize(),
			str(option["name"]),
			str(option["detail"]),
			Callable(self, "_request_research_launch").bind(option_id)
		)
		research_app_buttons.append(research_button)

	var staffs_page := _create_phone_app_page(
		"StaffsAppScreen",
		"Staffs",
		"Choose a staff area to open",
		"StaffsBackToHomeButton"
	)
	phone_app_views["staffs"] = staffs_page["page"]
	var staffs_list: VBoxContainer = staffs_page["list"]
	staffs_app_buttons.clear()
	var staff_options := [
		{"id": "market", "name": "Staff Market", "detail": "Find and recruit employees"},
		{"id": "management", "name": "Staff Management", "detail": "Manage your employees"}
	]
	for option in staff_options:
		var option_id := str(option["id"])
		var staff_button := _create_phone_destination_button(
			staffs_list,
			"StaffsOption_" + option_id.capitalize(),
			str(option["name"]),
			str(option["detail"]),
			Callable(self, "_request_staff_launch").bind(option_id)
		)
		staffs_app_buttons.append(staff_button)


func _add_phone_home_app(parent: GridContainer, app_title: String, button_name: String, glyph: String, action: Callable) -> void:
	var tile := VBoxContainer.new()
	tile.name = app_title.replace(" ", "") + "Tile"
	tile.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_theme_constant_override("separation", 3)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(tile)

	var app_icon := Button.new()
	app_icon.name = button_name
	app_icon.text = glyph
	app_icon.custom_minimum_size = Vector2(48.0, 48.0)
	app_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	app_icon.focus_mode = Control.FOCUS_NONE
	app_icon.tooltip_text = "Open " + app_title
	_style_phone_app_icon(app_icon)
	app_icon.add_theme_font_size_override("font_size", 24)
	app_icon.pressed.connect(action)
	tile.add_child(app_icon)

	var caption := Label.new()
	caption.name = button_name.replace("Icon", "Label")
	caption.text = app_title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", Color("#F0F4F7"))
	tile.add_child(caption)


func _create_phone_app_page(page_name: String, title_text: String, description_text: String, back_button_name: String) -> Dictionary:
	var page := VBoxContainer.new()
	page.name = page_name
	page.visible = false
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 7.0
	page.offset_top = 7.0
	page.offset_right = -7.0
	page.offset_bottom = -7.0
	page.add_theme_constant_override("separation", 5)
	page.add_child(_make_phone_status_bar(page_name + "StatusBar"))

	var header := HBoxContainer.new()
	header.name = page_name + "Header"
	header.add_theme_constant_override("separation", 5)
	page.add_child(header)

	var back_button := Button.new()
	back_button.name = back_button_name
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(27.0, 28.0)
	back_button.focus_mode = Control.FOCUS_NONE
	_style_phone_small_button(back_button)
	back_button.add_theme_font_size_override("font_size", 21)
	back_button.pressed.connect(_return_to_phone_home)
	header.add_child(back_button)

	var title := Label.new()
	title.name = page_name + "Title"
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#F4F7FA"))
	header.add_child(title)

	var description := Label.new()
	description.name = page_name + "Description"
	description.text = description_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 9)
	description.add_theme_color_override("font_color", Color("#A9BAC8"))
	page.add_child(description)

	var scroll := ScrollContainer.new()
	scroll.name = page_name + "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(scroll)

	var options_list := VBoxContainer.new()
	options_list.name = page_name + "Options"
	options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_list.add_theme_constant_override("separation", 4)
	scroll.add_child(options_list)
	return {"page": page, "list": options_list}


func _create_phone_destination_button(
	parent: VBoxContainer,
	button_name: String,
	title_text: String,
	detail_text: String,
	action: Callable
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = title_text if detail_text.is_empty() else title_text + "\n" + detail_text
	button.custom_minimum_size = Vector2(0.0, 43.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_phone_small_button(button)
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _make_phone_status_bar(node_name: String) -> Control:
	var status_bar := HBoxContainer.new()
	status_bar.name = node_name
	status_bar.custom_minimum_size.y = 15.0
	var clock := Label.new()
	clock.name = node_name + "Clock"
	clock.text = "%02d:%02d" % [
		int(Time.get_datetime_dict_from_system().get("hour", 9)),
		int(Time.get_datetime_dict_from_system().get("minute", 41))
	]
	clock.add_theme_font_size_override("font_size", 8)
	clock.add_theme_color_override("font_color", Color("#D5E0E8"))
	status_bar.add_child(clock)

	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_spacer)

	var indicators := Label.new()
	indicators.name = node_name + "Indicators"
	indicators.text = "●  ▮  ▰"
	indicators.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	indicators.add_theme_font_size_override("font_size", 8)
	indicators.add_theme_color_override("font_color", Color("#D5E0E8"))
	status_bar.add_child(indicators)
	return status_bar


func _style_phone_app_icon(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#245E68")
		style.border_color = Color("#71CFCC")
		style.set_border_width_all(1)
		style.set_corner_radius_all(18)
		if state == "hover":
			style.bg_color = Color("#2E7880")
		elif state == "pressed":
			style.bg_color = Color("#174A54")
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#F0FFFF"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _style_phone_small_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1B2A37")
		style.border_color = Color("#34495A")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		if state == "hover":
			style.bg_color = Color("#263C4D")
		elif state == "pressed":
			style.bg_color = Color("#315268")
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#EDF4F8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _open_phone_app(app_id: String) -> void:
	if not is_instance_valid(phone_home_view) or not is_instance_valid(phone_screen_ui):
		return
	phone_home_view.visible = false
	for view_id in phone_app_views.keys():
		var app_view := phone_app_views[view_id] as Control
		if is_instance_valid(app_view):
			app_view.visible = str(view_id) == app_id
	phone_screen_ui.set_meta("active_app", app_id.capitalize())


func _launch_explore_app() -> void:
	_open_phone_app("explore")
	if is_instance_valid(explore_status_label):
		explore_status_label.text = "Select a section to travel there"


func _launch_worksite_app() -> void:
	_open_phone_app("worksite")


func _launch_research_app() -> void:
	_open_phone_app("research")


func _launch_staffs_app() -> void:
	_open_phone_app("staffs")


func _return_to_phone_home() -> void:
	if not is_instance_valid(phone_home_view) or not is_instance_valid(phone_screen_ui):
		return
	for view_id in phone_app_views.keys():
		var app_view := phone_app_views[view_id] as Control
		if is_instance_valid(app_view):
			app_view.visible = false
	phone_home_view.visible = true
	phone_screen_ui.set_meta("active_app", "home")


func _close_phone_for_external_scene() -> void:
	if is_instance_valid(phone_device):
		phone_device.visible = false
		phone_device.set_meta("phone_open", false)
	if is_instance_valid(phone_screen_ui):
		phone_screen_ui.visible = false
	if is_instance_valid(phone_button):
		phone_button.tooltip_text = "Open phone"
		phone_button.set_meta("phone_open", false)


func _request_worksite_launch(worksite_id: String) -> void:
	if not ["phone", "camera", "os", "processor"].has(worksite_id):
		return
	_close_phone_for_external_scene()
	worksite_launch_requested.emit(worksite_id)


func _request_research_launch(research_id: String) -> void:
	if not ["hub", "phone", "camera", "processor"].has(research_id):
		return
	_close_phone_for_external_scene()
	research_launch_requested.emit(research_id)


func _request_staff_launch(staff_screen_id: String) -> void:
	if not ["market", "management"].has(staff_screen_id):
		return
	_close_phone_for_external_scene()
	staff_launch_requested.emit(staff_screen_id)


func _transport_to_campus_section(section_index: int) -> void:
	if not is_instance_valid(player) or section_index < 0 or section_index >= CAMPUS_SECTION_NAMES.size():
		return
	var row_index := floori(float(section_index) / 4.0)
	var column_index := section_index % 4
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(
		SECTION_COLUMN_CENTERS[column_index],
		player.global_position.y,
		SECTION_ROW_CENTERS[row_index]
	)
	player.set_meta("last_explore_section_index", section_index)
	set_meta("last_explore_section", section_index + 1)
	_update_camera()
	if is_instance_valid(explore_status_label):
		explore_status_label.text = "Arrived: " + CAMPUS_SECTION_SHORT_NAMES[section_index]


func _build_phone_button_icon(button: Button) -> void:
	var icon_frame := Panel.new()
	icon_frame.name = "PhoneButtonIcon"
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.position = Vector2(18.0, 11.0)
	icon_frame.size = Vector2(18.0, 32.0)
	icon_frame.add_theme_stylebox_override(
		"panel",
		_make_phone_style(Color("#171a1d"), Color("#e4e8e1"), 1, 4)
	)
	button.add_child(icon_frame)

	var icon_screen := Panel.new()
	icon_screen.name = "PhoneButtonIconScreen"
	icon_screen.position = Vector2(3.0, 4.0)
	icon_screen.size = Vector2(12.0, 23.0)
	icon_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_screen.add_theme_stylebox_override(
		"panel",
		_make_phone_style(Color("#050606"), Color("#050606"), 0, 2)
	)
	icon_frame.add_child(icon_screen)


func _style_phone_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.035, 0.030, 0.84)
		style.border_color = Color(0.86, 0.90, 0.84, 0.64)
		style.set_border_width_all(1)
		style.set_corner_radius_all(14)
		if state == "hover":
			style.bg_color = Color(0.12, 0.16, 0.13, 0.96)
		elif state == "pressed":
			style.bg_color = Color(0.20, 0.24, 0.19, 0.98)
		button.add_theme_stylebox_override(state, style)


func _make_phone_style(
	background_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


func _layout_phone_controls() -> void:
	if not is_instance_valid(overlay_root) or phone_control_buttons.size() != 4 or not is_instance_valid(phone_device):
		return

	var viewport_size := overlay_root.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var phone_height := minf(viewport_size.y * PHONE_BODY_HEIGHT_RATIO, viewport_size.y - 12.0)
	var desired_phone_width := phone_height * PHONE_BODY_ASPECT_RATIO
	var available_phone_width := maxf(
		96.0,
		viewport_size.x - PHONE_BODY_LEFT_CLEARANCE - PHONE_BUTTON_SIZE.x - PHONE_BODY_EDGE_MARGIN * 2.0 - PHONE_BODY_BUTTON_GAP
	)
	var phone_width := minf(desired_phone_width, available_phone_width)
	phone_height = phone_width / PHONE_BODY_ASPECT_RATIO

	var button_column_x := viewport_size.x - PHONE_BUTTON_SIZE.x - PHONE_BODY_EDGE_MARGIN
	var stack_gap := minf(
		PHONE_BUTTON_STACK_GAP,
		maxf(0.0, (viewport_size.y - PHONE_BUTTON_SIZE.y * 4.0 - PHONE_BODY_EDGE_MARGIN * 2.0) / 3.0)
	)
	var stack_height := PHONE_BUTTON_SIZE.y * 4.0 + stack_gap * 3.0
	var stack_top := (viewport_size.y - stack_height) * 0.5
	for button_index in range(phone_control_buttons.size()):
		var control_button := phone_control_buttons[button_index]
		control_button.size = PHONE_BUTTON_SIZE
		control_button.position = Vector2(
			button_column_x,
			stack_top + float(button_index) * (PHONE_BUTTON_SIZE.y + stack_gap)
		)

	phone_device.size = Vector2(phone_width, phone_height)
	phone_device.position = Vector2(
		button_column_x - PHONE_BODY_BUTTON_GAP - phone_width,
		(viewport_size.y - phone_height) * 0.5
	)
	if is_instance_valid(phone_screen_ui):
		phone_screen_ui.position = phone_device.position + Vector2(phone_width * 0.055, phone_height * 0.045)
		phone_screen_ui.size = Vector2(phone_width * 0.89, phone_height * 0.91)
		phone_screen_ui.add_theme_stylebox_override(
			"panel",
			_make_phone_style(Color("#101923"), Color("#273847"), 1, roundi(phone_screen_ui.size.y * 0.085))
		)
	phone_device.set_meta("phone_aspect_ratio", PHONE_BODY_ASPECT_RATIO)
	phone_device.set_meta("screen_height_ratio", phone_height / viewport_size.y)
	phone_device.set_meta("phone_left_of_control_stack", true)
	phone_device.set_meta("control_button_count", phone_control_buttons.size())


func _toggle_phone() -> void:
	if not is_instance_valid(phone_device):
		return
	phone_device.visible = not phone_device.visible
	if is_instance_valid(phone_screen_ui):
		phone_screen_ui.visible = phone_device.visible
	phone_button.tooltip_text = "Close phone" if phone_device.visible else "Open phone"
	phone_button.set_meta("phone_open", phone_device.visible)
	phone_device.set_meta("screen_powered", true)


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