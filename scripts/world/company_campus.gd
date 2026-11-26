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
const GRASS_INSTANCE_COUNT := 5600

var player: CharacterBody3D
var player_camera: Camera3D
var movement_joystick: Control
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var body_visual: Node3D
var head_visual: Node3D

var camera_yaw := PI * 0.25
var camera_pitch := 0.16
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
	camera_pitch = clampf(camera_pitch + delta_position.y * CAMERA_SENSITIVITY * 0.72, -0.12, 0.52)


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
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(CAMPUS_WIDTH, CAMPUS_DEPTH)
	terrain_mesh.subdivide_width = 64
	terrain_mesh.subdivide_depth = 48
	terrain.mesh = terrain_mesh

	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_texture = _create_grass_texture()
	grass_material.roughness = 1.0
	grass_material.uv1_scale = Vector3(38.0, 1.0, 30.0)
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


func _create_grass_texture() -> Texture2D:
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 4817
	broad_noise.frequency = 0.022
	broad_noise.fractal_octaves = 3
	var fine_noise := FastNoiseLite.new()
	fine_noise.seed = 9127
	fine_noise.frequency = 0.16
	for y in range(256):
		for x in range(256):
			var broad := broad_noise.get_noise_2d(float(x), float(y))
			var fine := fine_noise.get_noise_2d(float(x), float(y))
			var tone := clampf(0.52 + broad * 0.22 + fine * 0.10, 0.0, 1.0)
			var grain := 0.96 if ((x * 13 + y * 7) % 29) < 3 else 1.0
			var color := Color(
				(0.105 + tone * 0.105) * grain,
				(0.185 + tone * 0.175) * grain,
				(0.060 + tone * 0.075) * grain
			)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _add_grass_instances() -> void:
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color.WHITE
	blade_material.vertex_color_use_as_albedo = true
	blade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(blade_material)
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var half_width := 0.035
		var height := 0.13
		var a := -direction * half_width
		var b := direction * half_width
		var c := b + Vector3.UP * height
		var d := a + Vector3.UP * height
		surface.add_vertex(a)
		surface.add_vertex(b)
		surface.add_vertex(c)
		surface.add_vertex(a)
		surface.add_vertex(c)
		surface.add_vertex(d)
	surface.generate_normals()
	var blade_mesh := surface.commit()

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = blade_mesh
	multi.instance_count = GRASS_INSTANCE_COUNT

	var rng := RandomNumberGenerator.new()
	rng.seed = 260911
	for index in range(GRASS_INSTANCE_COUNT):
		var x := rng.randf_range(-HALF_WIDTH + 1.0, HALF_WIDTH - 1.0)
		var z := rng.randf_range(-HALF_DEPTH + 1.0, HALF_DEPTH - 1.0)
		var scale_value := rng.randf_range(0.76, 1.28)
		var grass_transform_basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		multi.set_instance_transform(index, Transform3D(grass_transform_basis, Vector3(x, 0.012, z)))
		var shade := rng.randf_range(0.78, 1.0)
		multi.set_instance_color(index, Color(0.72 * shade, 0.92 * shade, 0.62 * shade, 1.0))

	var grass := MultiMeshInstance3D.new()
	grass.name = "Instanced_Grass_Clumps"
	grass.multimesh = multi
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(grass)


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
