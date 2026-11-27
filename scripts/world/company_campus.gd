extends Node3D

signal back_requested
signal setup_progress(message: String, progress: float)
signal setup_completed
signal game_clock_toggle_requested
signal worksite_launch_requested(worksite_id: String)
signal research_launch_requested(research_id: String)
signal project_launch_requested
signal staff_launch_requested(staff_screen_id: String)

const JoystickScript = preload("res://scripts/world/campus_joystick.gd")
const OSPhoneModelScript = preload("res://scripts/os_worksite_phone_model.gd")

const CAMPUS_WIDTH := 800.0
const CAMPUS_DEPTH := 600.0
const HALF_WIDTH := CAMPUS_WIDTH * 0.5
const HALF_DEPTH := CAMPUS_DEPTH * 0.5
const MOVE_SPEED := 2.0
const GRAVITY := 9.8
const FIRST_PERSON_EYE_HEIGHT := 1.62
const CAMERA_SENSITIVITY := 0.0055
const PHONE_BUTTON_SIZE := Vector2(54.0, 54.0)
const PHONE_BODY_ASPECT_RATIO := 1.45 / 2.92
const PHONE_BODY_HEIGHT_RATIO := 1.0
const PHONE_BODY_EDGE_MARGIN := 2.0
const PHONE_BODY_BUTTON_GAP := 26.0
const PHONE_BUTTON_STACK_GAP := 10.0
const PHONE_BODY_LEFT_CLEARANCE := 230.0
const GRASS_INSTANCE_COUNT := 7600
const GRASS_BLADE_COUNT := 6
const MAINTAINED_GRASS_RATIO := 0.72

const CAMPUS_SECTION_NAMES := [
	"Main Entrance, Security & Reception",
	"Administration & Corporate Offices",
	"Staff Facilities, Cafeteria & Recreation",
	"Parking, Roads & Transport",
	"Research & Technology",
	"Production & Operations",
	"Logistics, Warehouses & Loading",
	"Landscaping, Green Spaces & Utilities",
	"Expansion Zone A",
	"Expansion Zone B",
	"Innovation Hub",
	"Future Projects",
	"R&D Extension",
	"Manufacturing Expansion",
	"Global Business Hub",
	"Special Projects"
]
const CAMPUS_SECTION_SHORT_NAMES := [
	"Main Entrance & Reception",
	"Corporate Offices",
	"Staff & Recreation",
	"Parking & Transport",
	"Research & Technology",
	"Production & Operations",
	"Logistics & Warehouses",
	"Green Spaces & Utilities",
	"Expansion Zone A",
	"Expansion Zone B",
	"Innovation Hub",
	"Future Projects",
	"R&D Extension",
	"Manufacturing Expansion",
	"Global Business Hub",
	"Special Projects"
]
const CAMPUS_SECTION_SIGN_TEXT := [
	"PLOT 01\nMAIN ENTRANCE & RECEPTION",
	"PLOT 02\nCORPORATE OFFICES",
	"PLOT 03\nSTAFF & RECREATION",
	"PLOT 04\nPARKING & TRANSPORT",
	"PLOT 05\nRESEARCH & TECHNOLOGY",
	"PLOT 06\nPRODUCTION & OPERATIONS",
	"PLOT 07\nLOGISTICS & WAREHOUSES",
	"PLOT 08\nGREEN SPACES & UTILITIES",
	"PLOT 09\nEXPANSION ZONE A",
	"PLOT 10\nEXPANSION ZONE B",
	"PLOT 11\nINNOVATION HUB",
	"PLOT 12\nFUTURE PROJECTS",
	"PLOT 13\nR&D EXTENSION",
	"PLOT 14\nMANUFACTURING EXPANSION",
	"PLOT 15\nGLOBAL BUSINESS HUB",
	"PLOT 16\nSPECIAL PROJECTS"
]
const SECTION_COLUMN_CENTERS := [-300.0, -100.0, 100.0, 300.0]
const SECTION_ROW_CENTERS := [225.0, 75.0, -75.0, -225.0]
const SECTION_HALF_WIDTH := 94.0
const SECTION_HALF_DEPTH := 69.0
const SECTION_GATE_WIDTH := 8.0
const INTERNAL_ROAD_WIDTH := 12.0
const CENTRAL_DIVIDING_AISLE_WIDTH := INTERNAL_ROAD_WIDTH
const ROAD_VERTICAL_CENTERS := [-200.0, 0.0, 200.0]
const ROAD_HORIZONTAL_CENTERS := [-150.0, 0.0, 150.0]
const STARTER_LAND_PARCEL_ID := "LAND-01"
const LAND_PARCEL_COUNT := 16

var land_parcels: Array[Dictionary] = []
var active_land_parcel_id := STARTER_LAND_PARCEL_ID
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
var career_company_name := "YOUR COMPANY"
var career_insignia_texture: Texture2D
var career_balance_text := "$10,000,000"
var career_date_text := "1st Jan 2020"
var career_clock_paused := false
var career_overlay_requested_visible := false
var career_company_label: Label
var career_identity_card: PanelContainer
var career_balance_label: Label
var career_date_label: Label
var career_clock_button: Button
var _property_gate_mesh: Mesh
var _property_gate_material: StandardMaterial3D

var camera_yaw := PI * 0.5
var camera_pitch := 0.0
var camera_touch_index := -1
var mouse_look_active := false


func configure_career_hud(
	company_name: String,
	insignia_texture: Texture2D,
	balance_text: String,
	date_text: String,
	clock_paused: bool
) -> void:
	career_company_name = company_name
	career_insignia_texture = insignia_texture
	career_balance_text = balance_text
	career_date_text = date_text
	career_clock_paused = clock_paused


func update_career_hud(
	company_name: String,
	balance_text: String,
	date_text: String,
	clock_paused: bool
) -> void:
	if career_company_name != company_name:
		career_company_name = company_name
		if is_instance_valid(career_company_label):
			career_company_label.text = career_company_name
			career_company_label.tooltip_text = career_company_name
			_update_career_identity_card_width()
	if career_balance_text != balance_text:
		career_balance_text = balance_text
		if is_instance_valid(career_balance_label):
			career_balance_label.text = career_balance_text
	if career_date_text != date_text:
		career_date_text = date_text
		if is_instance_valid(career_date_label):
			career_date_label.text = career_date_text
	if career_clock_paused != clock_paused:
		career_clock_paused = clock_paused
		if is_instance_valid(career_clock_button):
			career_clock_button.text = "▶  PLAY" if career_clock_paused else "Ⅱ  PAUSE"


func configure_land_parcels(parcel_values: Array, selected_parcel_id: String) -> void:
	land_parcels.clear()
	for parcel_value in parcel_values:
		if parcel_value is Dictionary:
			land_parcels.append(parcel_value.duplicate(true))
	_ensure_default_land_parcels()
	active_land_parcel_id = selected_parcel_id if _is_land_parcel_accessible(selected_parcel_id) else STARTER_LAND_PARCEL_ID
	_refresh_explore_section_buttons()


func _ensure_default_land_parcels() -> void:
	var existing_by_id: Dictionary = {}
	for existing_value in land_parcels:
		if existing_value is Dictionary:
			var existing_parcel: Dictionary = existing_value.duplicate(true)
			var existing_id := str(existing_parcel.get("id", ""))
			if existing_id.begins_with("LAND-"):
				existing_by_id[existing_id] = existing_parcel

	land_parcels.clear()
	for section_index in range(LAND_PARCEL_COUNT):
		var parcel_id := "LAND-%02d" % (section_index + 1)
		var is_starter := section_index == 0
		var parcel: Dictionary = existing_by_id.get(parcel_id, {})
		var access_granted := bool(parcel.get("access_granted", is_starter))
		var tenure_status := str(parcel.get("tenure_status", "starter_access" if is_starter else "not_acquired"))
		if not existing_by_id.has(parcel_id):
			access_granted = is_starter
			tenure_status = "starter_access" if is_starter else "not_acquired"
		if tenure_status in ["starter_access", "owned", "rented"]:
			access_granted = true
		parcel["id"] = parcel_id
		parcel["section_index"] = section_index
		parcel["access_granted"] = access_granted
		parcel["access_status"] = "accessible" if access_granted else "locked"
		parcel["tenure_status"] = tenure_status if access_granted else "not_acquired"
		land_parcels.append(parcel)


func _is_land_parcel_accessible(parcel_id: String) -> bool:
	for parcel in land_parcels:
		if str(parcel.get("id", "")) == parcel_id:
			return bool(parcel.get("access_granted", false))
	return false


func _is_section_accessible(section_index: int) -> bool:
	if section_index < 0 or section_index >= LAND_PARCEL_COUNT:
		return false
	return _is_land_parcel_accessible("LAND-%02d" % (section_index + 1))


func _get_internal_plot_sides(row_index: int, column_index: int) -> Array[String]:
	var sides: Array[String] = []
	if column_index > 0:
		sides.append("west")
	if column_index < 3:
		sides.append("east")
	if row_index > 0:
		sides.append("north")
	if row_index < 3:
		sides.append("south")
	return sides


func set_land_parcel_access(parcel_id: String, access_granted: bool, tenure_status: String = "owned") -> bool:
	var section_index := -1
	for index in range(land_parcels.size()):
		if str(land_parcels[index].get("id", "")) == parcel_id:
			section_index = int(land_parcels[index].get("section_index", index))
			break
	if section_index < 0 or (not access_granted and parcel_id == active_land_parcel_id):
		return false

	for index in range(land_parcels.size()):
		if str(land_parcels[index].get("id", "")) == parcel_id:
			var updated_parcel: Dictionary = land_parcels[index].duplicate(true)
			updated_parcel["access_granted"] = access_granted
			updated_parcel["access_status"] = "accessible" if access_granted else "locked"
			updated_parcel["tenure_status"] = tenure_status if access_granted else "not_acquired"
			land_parcels[index] = updated_parcel
			break

	var section_root := get_node_or_null("Campus_Sections") as Node3D
	var section := section_root.get_node_or_null("Section_%02d" % (section_index + 1)) as Node3D if is_instance_valid(section_root) else null
	if is_instance_valid(section):
		section.set_meta("access_granted", access_granted)
		section.set_meta("access_status", "accessible" if access_granted else "locked")
		section.set_meta("tenure_status", tenure_status if access_granted else "not_acquired")

	var gates_root := get_node_or_null("Campus_Wooden_Fences/Property_Gates") as Node3D
	if is_instance_valid(gates_root):
		var matching_gate_count := 0
		for gate_value in gates_root.get_children():
			var gate := gate_value as StaticBody3D
			if not is_instance_valid(gate) or str(gate.get_meta("property_id", "")) != parcel_id:
				continue
			matching_gate_count += 1
			gate.visible = not access_granted
			gate.set_meta("gate_locked", not access_granted)
			var gate_collision := gate.get_node_or_null("GateCollision") as CollisionShape3D
			if is_instance_valid(gate_collision):
				gate_collision.disabled = access_granted

		if matching_gate_count == 0:
			var row_index := floori(float(section_index) / 4.0)
			var column_index := section_index % 4
			var section_center := Vector3(SECTION_COLUMN_CENTERS[column_index], 0.0, SECTION_ROW_CENTERS[row_index])
			_create_property_gates_for_parcel(gates_root, section_center, section_index, access_granted)
		_refresh_property_gate_counts(gates_root)

	_refresh_explore_section_buttons()
	return true


func _refresh_explore_section_buttons() -> void:
	for section_index in range(explore_section_buttons.size()):
		var button := explore_section_buttons[section_index]
		var accessible := _is_section_accessible(section_index)
		var parcel_id := "LAND-%02d" % (section_index + 1)
		button.set_meta("property_access", "accessible" if accessible else "locked")
		button.set_meta("property_id", parcel_id)
		button.text = "%02d   %s   %s" % [section_index + 1, CAMPUS_SECTION_SHORT_NAMES[section_index], "OPEN" if accessible else "LOCKED"]
		button.tooltip_text = "%s - %s" % [parcel_id, "Access available" if accessible else "Locked: acquire or rent this land"]


func _ready() -> void:
	_ensure_default_land_parcels()
	set_meta("career_home_scene", true)
	set_meta("map_dimensions", Vector2(CAMPUS_WIDTH, CAMPUS_DEPTH))
	set_meta("map_area_square_metres", CAMPUS_WIDTH * CAMPUS_DEPTH)
	set_meta("land_parcel_count", LAND_PARCEL_COUNT)
	set_meta("initially_accessible_land_parcel_count", 1)
	set_meta("active_land_parcel_id", active_land_parcel_id)
	set_meta("move_speed_metres_per_second", MOVE_SPEED)
	set_meta("movement_model", "continuous_velocity")
	set_meta("movement_response", "direct_analog_velocity_no_deadzone_no_temporal_acceleration")
	set_meta("mobile_render_profile", "performance_first_no_realtime_shadows")
	set_meta("movement_grass_follow_enabled", false)
	set_meta("camera_perspective", "first_person_eye_only")
	set_meta("player_spawn_zone", "central_dividing_aisle")
	set_meta("player_spawn_position", Vector3(-366.0, 0.0, 0.0))
	set_meta("player_spawn_heading", "east_along_central_aisle")
	set_meta("central_dividing_aisle_width_metres", CENTRAL_DIVIDING_AISLE_WIDTH)

	setup_progress.emit("Preparing campus environment", 0.0)
	await get_tree().process_frame
	await _build_environment_batched()

	await get_tree().process_frame
	setup_progress.emit("Generating campus grounds and landscaping", 0.0)
	await _build_terrain_batched()

	await get_tree().process_frame
	setup_progress.emit("Setting up first-person campus controls", 0.0)
	_build_player()
	_build_camera()
	_update_camera()
	setup_progress.emit("Setting up first-person campus controls", 35.0)
	await get_tree().process_frame
	await _build_overlay_batched()
	setup_progress.emit("Setting up first-person campus controls", 100.0)
	set_meta("campus_generation_complete", true)
	setup_completed.emit()


func set_career_home_overlay_visible(should_show: bool) -> void:
	career_overlay_requested_visible = should_show
	var layer := get_node_or_null("Campus_Controls_Layer") as CanvasLayer
	if is_instance_valid(layer):
		layer.visible = should_show


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var move_input := _get_move_input()
	var move_velocity := _calculate_move_velocity(move_input)

	# Translation is driven only by continuous world-space velocity. No gait,
	# step timer, animation cycle, or movement cadence controls player position.
	player.velocity.x = move_velocity.x
	player.velocity.z = move_velocity.z
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = -0.2

	player.move_and_slide()
	player.global_position.x = clampf(player.global_position.x, -HALF_WIDTH + 1.0, HALF_WIDTH - 1.0)
	player.global_position.z = clampf(player.global_position.z, -HALF_DEPTH + 1.0, HALF_DEPTH - 1.0)

	player.rotation.y = -camera_yaw


func _get_move_input() -> Vector2:
	if is_instance_valid(movement_joystick):
		var joystick_value: Variant = movement_joystick.call("get_value")
		if joystick_value is Vector2 and joystick_value != Vector2.ZERO:
			return joystick_value

	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")


func _calculate_move_velocity(move_input: Vector2) -> Vector3:
	var input_strength := clampf(move_input.length(), 0.0, 1.0)
	if input_strength <= 0.0:
		return Vector3.ZERO

	var forward := Vector3(sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, sin(camera_yaw))
	var move_direction := right * move_input.x + forward * move_input.y
	if move_direction.length_squared() <= 0.000001:
		return Vector3.ZERO

	# Direction is normalized once; input magnitude remains analog. Godot's
	# CharacterBody3D integrates this velocity through move_and_slide() each
	# physics tick, keeping travel continuous and collision-resolved.
	return move_direction.normalized() * MOVE_SPEED * input_strength


func _process(_delta: float) -> void:
	# CanvasLayers do not inherit Node3D visibility. Keep the touch HUD alive
	# whenever this campus is the active visible world, even if another screen
	# accidentally hides the layer during a transition.
	if career_overlay_requested_visible and visible:
		var controls_layer := get_node_or_null("Campus_Controls_Layer") as CanvasLayer
		if is_instance_valid(controls_layer) and not controls_layer.visible:
			controls_layer.visible = true
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
	# Follow the transform that Godot will actually render, not the latest
	# discrete physics transform. Keep look input responsive every rendered frame.
	var rendered_player_transform := player.get_global_transform_interpolated()
	player_camera.global_position = rendered_player_transform.origin + Vector3.UP * FIRST_PERSON_EYE_HEIGHT
	var look_direction := Vector3(
		sin(camera_yaw) * cos(camera_pitch),
		-sin(camera_pitch),
		-cos(camera_yaw) * cos(camera_pitch)
	)
	player_camera.look_at(player_camera.global_position + look_direction, Vector3.UP)


func _build_environment_batched() -> void:
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
	# Real-time directional shadows are expensive on lower-end Android GPUs.
	# Keep direct lighting, but avoid the extra shadow-map rendering pass.
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)
	setup_progress.emit("Preparing campus environment", 15.0)
	await get_tree().process_frame
	await _build_cloud_layer_batched()


func _build_terrain_batched() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.set_meta("grass_layout", "hybrid_maintained_core_natural_perimeter")
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(CAMPUS_WIDTH, CAMPUS_DEPTH)
	# This ground is flat and texture-driven; dense subdivisions add vertices
	# without providing visible surface detail.
	terrain_mesh.subdivide_width = 1
	terrain_mesh.subdivide_depth = 1
	terrain.mesh = terrain_mesh

	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_texture = await _create_grass_texture_batched(0.0, 18.0)
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
	setup_progress.emit("Generating campus grounds and landscaping", 18.0)
	await get_tree().process_frame
	await _add_grass_instances_batched(18.0, 65.0)
	await _build_campus_trees_batched(65.0, 72.0)
	await _build_campus_sections_batched(72.0, 100.0)



func _build_cloud_layer_batched() -> void:
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
		if (cloud_index + 1) % 2 == 0 or cloud_index + 1 == CLOUD_CLUSTER_COUNT:
			setup_progress.emit("Preparing campus environment", 15.0 + 55.0 * float(cloud_index + 1) / float(CLOUD_CLUSTER_COUNT))
			await get_tree().process_frame

	cloud_multi.instance_count = cloud_transforms.size()
	for index in range(cloud_transforms.size()):
		cloud_multi.set_instance_transform(index, cloud_transforms[index])
		var brightness := rng.randf_range(0.91, 1.0)
		cloud_multi.set_instance_color(index, Color(brightness, brightness, minf(1.0, brightness + 0.015), 1.0))
		if (index + 1) % 64 == 0 or index + 1 == cloud_transforms.size():
			setup_progress.emit("Preparing campus environment", 70.0 + 29.0 * float(index + 1) / maxf(float(cloud_transforms.size()), 1.0))
			await get_tree().process_frame

	var clouds := MultiMeshInstance3D.new()
	clouds.name = "Campus_Clouds"
	clouds.multimesh = cloud_multi
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clouds.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	clouds.set_meta("cloud_cluster_count", CLOUD_CLUSTER_COUNT)
	clouds.set_meta("cloud_puff_count", cloud_transforms.size())
	clouds.set_meta("cloud_layer_height_range", Vector2(94.0, 132.0))
	add_child(clouds)


func _build_campus_sections_batched(progress_start: float, progress_end: float) -> void:
	var section_root := Node3D.new()
	section_root.name = "Campus_Sections"
	section_root.set_meta("section_count", CAMPUS_SECTION_NAMES.size())
	section_root.set_meta("layout", "four_columns_four_rows")
	section_root.set_meta("grid_columns", 4)
	section_root.set_meta("grid_rows", 4)
	section_root.set_meta("property_model", "sixteen_independent_land_parcels")
	section_root.set_meta("plot_size_metres", Vector2(SECTION_HALF_WIDTH * 2.0, SECTION_HALF_DEPTH * 2.0))
	add_child(section_root)

	_build_asphalt_road_network()

	var fence_root := Node3D.new()
	fence_root.name = "Campus_Wooden_Fences"
	fence_root.set_meta("wooden_fence", true)
	fence_root.set_meta("gate_opening_width_metres", SECTION_GATE_WIDTH)
	fence_root.set_meta("plot_count", LAND_PARCEL_COUNT)
	add_child(fence_root)

	var gates_root := Node3D.new()
	gates_root.name = "Property_Gates"
	gates_root.set_meta("gate_system", "individual_plot_internal_perimeter_entrances")
	fence_root.add_child(gates_root)
	_ensure_property_gate_resources()

	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color("#67452e")
	post_material.roughness = 0.94
		var sign_board_material := StandardMaterial3D.new()
	sign_board_material.albedo_color = Color("#503522")
	sign_board_material.roughness = 0.92
	var sign_support_material := StandardMaterial3D.new()
	sign_support_material.albedo_color = Color("#69452d")
	sign_support_material.roughness = 0.94

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3.ONE
		var picket_mesh := BoxMesh.new()
	picket_mesh.size = Vector3(0.16, 1.18, 0.10)
	var post_transforms: Array[Transform3D] = []
	var picket_transforms: Array[Transform3D] = []

	var fence_collisions := StaticBody3D.new()
	fence_collisions.name = "Fence_Collisions"
	fence_collisions.collision_layer = 1
	fence_collisions.collision_mask = 1
	fence_collisions.set_meta("blocks_player", true)
	fence_collisions.set_meta("collision_layer", 1)
	fence_root.add_child(fence_collisions)

	var locked_gate_count := 0
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
		var parcel_id := "LAND-%02d" % (section_index + 1)
		var parcel_accessible := _is_section_accessible(section_index)
		var parcel_tenure := "starter_access" if section_index == 0 else "not_acquired"
		for parcel in land_parcels:
			if str(parcel.get("id", "")) == parcel_id:
				parcel_tenure = str(parcel.get("tenure_status", parcel_tenure))
				break

		var internal_sides := _get_internal_plot_sides(row_index, column_index)
		section.set_meta("section_number", section_index + 1)
		section.set_meta("section_name", CAMPUS_SECTION_NAMES[section_index])
		section.set_meta("property_id", parcel_id)
		section.set_meta("is_individual_land_parcel", true)
		section.set_meta("property_area_square_metres", SECTION_HALF_WIDTH * 2.0 * SECTION_HALF_DEPTH * 2.0)
		section.set_meta("plot_size_metres", Vector2(SECTION_HALF_WIDTH * 2.0, SECTION_HALF_DEPTH * 2.0))
		section.set_meta("grid_row", row_index)
		section.set_meta("grid_column", column_index)
		section.set_meta("entrance_sides", internal_sides.duplicate())
		section.set_meta("access_granted", parcel_accessible)
		section.set_meta("access_status", "accessible" if parcel_accessible else "locked")
		section.set_meta("tenure_status", parcel_tenure)
		section.set_meta("section_bounds_local", Vector4(-SECTION_HALF_WIDTH, -SECTION_HALF_DEPTH, SECTION_HALF_WIDTH, SECTION_HALF_DEPTH))
		section_root.add_child(section)

		var west_start := center + Vector3(-SECTION_HALF_WIDTH, 0.0, -SECTION_HALF_DEPTH)
		var east_start := center + Vector3(SECTION_HALF_WIDTH, 0.0, -SECTION_HALF_DEPTH)
		var north_start := center + Vector3(-SECTION_HALF_WIDTH, 0.0, SECTION_HALF_DEPTH)
		var south_start := center + Vector3(-SECTION_HALF_WIDTH, 0.0, -SECTION_HALF_DEPTH)
		var side_progress_span := (progress_end - progress_start) * 0.55 / float(CAMPUS_SECTION_NAMES.size() * 4)
		var side_progress_base := progress_start + float(section_index * 4) * side_progress_span

		await _append_fence_side_batched(post_transforms, picket_transforms, fence_collisions, west_start, Vector3(0.0, 0.0, 1.0), SECTION_HALF_DEPTH * 2.0, side_progress_base, side_progress_base + side_progress_span, internal_sides.has("west"))
		await _append_fence_side_batched(post_transforms, picket_transforms, fence_collisions, east_start, Vector3(0.0, 0.0, 1.0), SECTION_HALF_DEPTH * 2.0, side_progress_base + side_progress_span, side_progress_base + side_progress_span * 2.0, internal_sides.has("east"))
		await _append_fence_side_batched(post_transforms, picket_transforms, fence_collisions, north_start, Vector3.RIGHT, SECTION_HALF_WIDTH * 2.0, side_progress_base + side_progress_span * 2.0, side_progress_base + side_progress_span * 3.0, internal_sides.has("north"))
		await _append_fence_side_batched(post_transforms, picket_transforms, fence_collisions, south_start, Vector3.RIGHT, SECTION_HALF_WIDTH * 2.0, side_progress_base + side_progress_span * 3.0, side_progress_base + side_progress_span * 4.0, internal_sides.has("south"))

		for side in internal_sides:
			_build_locked_property_gate(gates_root, center, section_index, side, parcel_accessible)
		if not parcel_accessible:
			locked_gate_count += internal_sides.size()

		_build_section_sign(section, CAMPUS_SECTION_SIGN_TEXT[section_index], sign_board_material, sign_support_material)
		await get_tree().process_frame

	var picket_material := StandardMaterial3D.new()
	picket_material.albedo_color = Color("#a87549")
	picket_material.roughness = 0.93
	var posts: MultiMeshInstance3D = await _add_fence_multimesh_batched(fence_root, "Fence_Posts", post_mesh, post_material, post_transforms, progress_start + (progress_end - progress_start) * 0.55, progress_start + (progress_end - progress_start) * 0.68)
	var pickets: MultiMeshInstance3D = await _add_fence_multimesh_batched(fence_root, "Fence_Vertical_Pickets", picket_mesh, picket_material, picket_transforms, progress_start + (progress_end - progress_start) * 0.80, progress_start + (progress_end - progress_start) * 0.99)
	posts.set_meta("fence_component", "structural_posts")
	pickets.set_meta("fence_component", "vertical_pickets")
	fence_root.set_meta("fence_style", "vertical_post_picket_only")
	fence_root.set_meta("post_count", post_transforms.size())
	fence_root.set_meta("horizontal_rail_count", 0)
	fence_root.set_meta("horizontal_rails_removed", true)
	fence_root.set_meta("picket_count", picket_transforms.size())
	fence_root.set_meta("collision_segment_count", fence_collisions.get_child_count())
	fence_root.set_meta("locked_gate_count", locked_gate_count)
	_refresh_property_gate_counts(gates_root)


func _build_asphalt_road_network() -> void:
	var asphalt_material := StandardMaterial3D.new()
	# Deep charcoal-black, matte asphalt that stays visually distinct from the green plots.
	asphalt_material.albedo_color = Color("#17191b")
	asphalt_material.roughness = 1.0
	asphalt_material.metallic = 0.0

	var road_surface := SurfaceTool.new()
	road_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	road_surface.set_material(asphalt_material)

	var campus_min_x := -HALF_WIDTH + 6.0
	var campus_max_x := HALF_WIDTH - 6.0
	var campus_min_z := -HALF_DEPTH + 6.0
	var campus_max_z := HALF_DEPTH - 6.0

	for horizontal_z in ROAD_HORIZONTAL_CENTERS:
		_append_road_quad(road_surface, campus_min_x, campus_max_x, horizontal_z - INTERNAL_ROAD_WIDTH * 0.5, horizontal_z + INTERNAL_ROAD_WIDTH * 0.5)

	for vertical_x in ROAD_VERTICAL_CENTERS:
		var z_start := campus_min_z
		for horizontal_z in ROAD_HORIZONTAL_CENTERS:
			var intersection_min_z: float = float(horizontal_z) - INTERNAL_ROAD_WIDTH * 0.5
			var intersection_max_z: float = float(horizontal_z) + INTERNAL_ROAD_WIDTH * 0.5
			if intersection_min_z > z_start:
				_append_road_quad(road_surface, vertical_x - INTERNAL_ROAD_WIDTH * 0.5, vertical_x + INTERNAL_ROAD_WIDTH * 0.5, z_start, intersection_min_z)
			z_start = intersection_max_z
		if z_start < campus_max_z:
			_append_road_quad(road_surface, vertical_x - INTERNAL_ROAD_WIDTH * 0.5, vertical_x + INTERNAL_ROAD_WIDTH * 0.5, z_start, campus_max_z)

	road_surface.generate_normals()
	var road_instance := MeshInstance3D.new()
	road_instance.name = "Campus_Asphalt_Roads"
	road_instance.mesh = road_surface.commit()
	road_instance.material_override = asphalt_material
	road_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	road_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	road_instance.set_meta("road_corridor_count", 6)
	road_instance.set_meta("asphalt_surface_quad_count", 15)
	road_instance.set_meta("road_width_metres", INTERNAL_ROAD_WIDTH)
	add_child(road_instance)

	var marking_material := StandardMaterial3D.new()
	marking_material.albedo_color = Color("#d5d8d9")
	marking_material.roughness = 0.96
	marking_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3.ONE
	var dash_transforms: Array[Transform3D] = []

	for horizontal_z in ROAD_HORIZONTAL_CENTERS:
		var x_position := campus_min_x + 10.0
		while x_position <= campus_max_x - 10.0:
			var near_intersection := false
			for vertical_x in ROAD_VERTICAL_CENTERS:
				if absf(x_position - vertical_x) < INTERNAL_ROAD_WIDTH:
					near_intersection = true
					break
			if not near_intersection:
				var dash_basis := Basis.IDENTITY.scaled(Vector3(2.6, 0.012, 0.16))
				dash_transforms.append(Transform3D(dash_basis, Vector3(x_position, 0.041, horizontal_z)))
			x_position += 14.0

	for vertical_x in ROAD_VERTICAL_CENTERS:
		var z_position := campus_min_z + 10.0
		while z_position <= campus_max_z - 10.0:
			var near_intersection := false
			for horizontal_z in ROAD_HORIZONTAL_CENTERS:
				if absf(z_position - horizontal_z) < INTERNAL_ROAD_WIDTH:
					near_intersection = true
					break
			if not near_intersection:
				var dash_basis := Basis.IDENTITY.scaled(Vector3(0.16, 0.012, 2.6))
				dash_transforms.append(Transform3D(dash_basis, Vector3(vertical_x, 0.041, z_position)))
			z_position += 14.0

	var dash_multi := MultiMesh.new()
	dash_multi.transform_format = MultiMesh.TRANSFORM_3D
	dash_multi.mesh = dash_mesh
	dash_multi.instance_count = dash_transforms.size()
	for dash_index in range(dash_transforms.size()):
		dash_multi.set_instance_transform(dash_index, dash_transforms[dash_index])
	var markings := MultiMeshInstance3D.new()
	markings.name = "Campus_Road_Markings"
	markings.multimesh = dash_multi
	markings.material_override = marking_material
	markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	markings.set_meta("marking_style", "sparse_dashed_center_lines")
	markings.set_meta("dash_count", dash_transforms.size())
	add_child(markings)


func _append_road_quad(surface: SurfaceTool, min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	var a := Vector3(min_x, 0.035, min_z)
	var b := Vector3(min_x, 0.035, max_z)
	var c := Vector3(max_x, 0.035, max_z)
	var d := Vector3(max_x, 0.035, min_z)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)


func _is_on_asphalt_road(x: float, z: float) -> bool:
	var road_clearance := INTERNAL_ROAD_WIDTH * 0.5 + 0.25
	for road_x in ROAD_VERTICAL_CENTERS:
		if absf(x - road_x) < road_clearance:
			return true
	for road_z in ROAD_HORIZONTAL_CENTERS:
		if absf(z - road_z) < road_clearance:
			return true
	return false


func _append_fence_side(
	post_transforms: Array[Transform3D],
	picket_transforms: Array[Transform3D],
	fence_collisions: StaticBody3D,
	start: Vector3,
	direction: Vector3,
	length: float,
	has_entrance: bool = false
) -> void:
	var normalized_direction := direction.normalized()
	var gate_start := (length - SECTION_GATE_WIDTH) * 0.5
	var gate_end := gate_start + SECTION_GATE_WIDTH
	var segments: Array[Vector2] = [Vector2(0.0, length)]
	if has_entrance:
		segments = [Vector2(0.0, gate_start), Vector2(gate_end, length)]
	var yaw := 0.0 if absf(normalized_direction.x) > 0.5 else PI * 0.5

	for segment in segments:
		var segment_start: float = segment.x
		var segment_end: float = segment.y
		var segment_length := segment_end - segment_start
		if segment_length <= 0.5:
			continue

		var segment_center := start + normalized_direction * ((segment_start + segment_end) * 0.5)

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


func _append_fence_side_batched(
	post_transforms: Array[Transform3D],
	picket_transforms: Array[Transform3D],
	fence_collisions: StaticBody3D,
	start: Vector3,
	direction: Vector3,
	length: float,
	progress_start: float,
	progress_end: float,
	has_entrance: bool = false
) -> void:
	var normalized_direction := direction.normalized()
	var gate_start := (length - SECTION_GATE_WIDTH) * 0.5
	var gate_end := gate_start + SECTION_GATE_WIDTH
	var segments: Array[Vector2] = [Vector2(0.0, length)]
	if has_entrance:
		segments = [Vector2(0.0, gate_start), Vector2(gate_end, length)]
	var yaw := 0.0 if absf(normalized_direction.x) > 0.5 else PI * 0.5
	var total_pickets := 0
	for segment_value in segments:
		var segment_value_length := float(segment_value.y - segment_value.x)
		if segment_value_length > 0.5:
			total_pickets += maxi(1, ceili(segment_value_length / 0.34))
	var processed_pickets := 0
	for segment in segments:
		var segment_start: float = segment.x
		var segment_end: float = segment.y
		var segment_length := segment_end - segment_start
		if segment_length <= 0.5:
			continue
		var segment_center := start + normalized_direction * ((segment_start + segment_end) * 0.5)
		var picket_spacing := 0.34
		var picket_count := maxi(1, ceili(segment_length / picket_spacing))
		for picket_index in range(picket_count):
			var picket_distance := minf(segment_length - 0.10, (float(picket_index) + 0.5) * segment_length / float(picket_count))
			var picket_position := start + normalized_direction * (segment_start + picket_distance) + Vector3.UP * 0.76
			picket_transforms.append(Transform3D(Basis(Vector3.UP, yaw), picket_position))
			processed_pickets += 1
			if processed_pickets % 128 == 0 or processed_pickets == total_pickets:
				var batch_ratio := float(processed_pickets) / maxf(float(total_pickets), 1.0)
				setup_progress.emit("Generating campus grounds and landscaping", lerpf(progress_start, progress_end, batch_ratio))
				await get_tree().process_frame
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
	setup_progress.emit("Generating campus grounds and landscaping", progress_end)


func _add_fence_multimesh_batched(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D],
	progress_start: float,
	progress_end: float
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
		if (index + 1) % 256 == 0 or index + 1 == transforms.size():
			var ratio := float(index + 1) / maxf(float(transforms.size()), 1.0)
			setup_progress.emit("Generating campus grounds and landscaping", lerpf(progress_start, progress_end, ratio))
			await get_tree().process_frame
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.set_meta("instance_count", transforms.size())
	parent.add_child(instance)
	return instance


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


func _ensure_property_gate_resources() -> void:
	if _property_gate_mesh != null and _property_gate_material != null:
		return

	_property_gate_material = StandardMaterial3D.new()
	_property_gate_material.vertex_color_use_as_albedo = true
	_property_gate_material.roughness = 0.94
	_property_gate_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_property_gate_material)
	var timber_color := Color("#563922")
	var slat_color := Color("#8A5B38")
	var sign_color := Color("#2D2118")

	_append_gate_box(surface, Vector3(0.22, 1.92, 0.24), Vector3(-3.86, 0.96, 0.0), timber_color)
	_append_gate_box(surface, Vector3(0.22, 1.92, 0.24), Vector3(3.86, 0.96, 0.0), timber_color)
	_append_gate_box(surface, Vector3(7.72, 0.20, 0.24), Vector3(0.0, 1.78, 0.0), timber_color)
	_append_gate_box(surface, Vector3(7.72, 0.20, 0.24), Vector3(0.0, 0.22, 0.0), timber_color)
	for slat_index in range(11):
		var slat_x := lerpf(-3.35, 3.35, float(slat_index) / 10.0)
		_append_gate_box(surface, Vector3(0.15, 1.42, 0.14), Vector3(slat_x, 1.0, 0.0), slat_color)
	_append_gate_box(surface, Vector3(5.8, 0.62, 0.18), Vector3(0.0, 2.36, 0.0), sign_color)

	surface.generate_normals()
	_property_gate_mesh = surface.commit()


func _append_gate_box(surface: SurfaceTool, size: Vector3, center: Vector3, color: Color) -> void:
	var half := size * 0.5
	var p000 := center + Vector3(-half.x, -half.y, -half.z)
	var p001 := center + Vector3(-half.x, -half.y, half.z)
	var p010 := center + Vector3(-half.x, half.y, -half.z)
	var p011 := center + Vector3(-half.x, half.y, half.z)
	var p100 := center + Vector3(half.x, -half.y, -half.z)
	var p101 := center + Vector3(half.x, -half.y, half.z)
	var p110 := center + Vector3(half.x, half.y, -half.z)
	var p111 := center + Vector3(half.x, half.y, half.z)

	_append_gate_face(surface, p001, p101, p111, p011, color)
	_append_gate_face(surface, p100, p000, p010, p110, color)
	_append_gate_face(surface, p101, p100, p110, p111, color)
	_append_gate_face(surface, p000, p001, p011, p010, color)
	_append_gate_face(surface, p011, p111, p110, p010, color)
	_append_gate_face(surface, p000, p100, p101, p001, color)


func _append_gate_face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(b)
	surface.set_color(color)
	surface.add_vertex(c)
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(c)
	surface.set_color(color)
	surface.add_vertex(d)


func _create_property_gates_for_parcel(gates_root: Node3D, section_center: Vector3, section_index: int, parcel_accessible: bool) -> int:
	var row_index := floori(float(section_index) / 4.0)
	var column_index := section_index % 4
	var sides := _get_internal_plot_sides(row_index, column_index)
	for side in sides:
		_build_locked_property_gate(gates_root, section_center, section_index, side, parcel_accessible)
	return sides.size()


func _refresh_property_gate_counts(gates_root: Node3D) -> void:
	var total_gate_count := 0
	var locked_gate_count := 0
	for gate_value in gates_root.get_children():
		var gate := gate_value as StaticBody3D
		if not is_instance_valid(gate):
			continue
		total_gate_count += 1
		if bool(gate.get_meta("gate_locked", false)):
			locked_gate_count += 1
	gates_root.set_meta("gate_count", total_gate_count)
	gates_root.set_meta("locked_gate_count", locked_gate_count)
	var fence_root := gates_root.get_parent() as Node3D
	if is_instance_valid(fence_root):
		fence_root.set_meta("locked_gate_count", locked_gate_count)


func _build_locked_property_gate(gates_root: Node3D, section_center: Vector3, section_index: int, side: String, parcel_accessible: bool) -> StaticBody3D:
	_ensure_property_gate_resources()
	var parcel_id := "LAND-%02d" % (section_index + 1)
	var gate := StaticBody3D.new()
	gate.name = "PropertyGate_%02d_%s" % [section_index + 1, side.capitalize()]
	gate.collision_layer = 1
	gate.collision_mask = 1
	gate.visible = not parcel_accessible
	gate.set_meta("property_id", parcel_id)
	gate.set_meta("entrance_side", side)
	gate.set_meta("faces_campus_interior", true)
	gate.set_meta("gate_front_faces_internal_road", true)
	gate.set_meta("gate_locked", not parcel_accessible)
	gate.set_meta("blocks_player", true)
	gate.add_to_group("locked_land_gates")

	var gate_offset := Vector3.ZERO
	match side:
		"north":
			gate_offset = Vector3(0.0, 0.0, SECTION_HALF_DEPTH)
			gate.rotation.y = 0.0
		"south":
			gate_offset = Vector3(0.0, 0.0, -SECTION_HALF_DEPTH)
			gate.rotation.y = PI
		"east":
			gate_offset = Vector3(SECTION_HALF_WIDTH, 0.0, 0.0)
			gate.rotation.y = PI * 0.5
		"west":
			gate_offset = Vector3(-SECTION_HALF_WIDTH, 0.0, 0.0)
			gate.rotation.y = -PI * 0.5
		_:
			push_error("Unknown internal plot gate side: " + side)
			return gate
	gate.position = section_center + gate_offset

	var gate_mesh_instance := MeshInstance3D.new()
	gate_mesh_instance.name = "GateMesh"
	gate_mesh_instance.mesh = _property_gate_mesh
	gate_mesh_instance.material_override = _property_gate_material
	gate_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	gate.add_child(gate_mesh_instance)

	var gate_collision := CollisionShape3D.new()
	gate_collision.name = "GateCollision"
	var gate_shape := BoxShape3D.new()
	gate_shape.size = Vector3(SECTION_GATE_WIDTH, 1.95, 0.40)
	gate_collision.shape = gate_shape
	gate_collision.position = Vector3(0.0, 0.98, 0.0)
	gate_collision.disabled = parcel_accessible
	gate.add_child(gate_collision)

	var label := Label3D.new()
	label.name = "Gate_Locked_Label"
	label.text = "PLOT %02d  -  LOCKED" % (section_index + 1)
	label.font_size = 25
	label.pixel_size = 0.008
	label.outline_size = 5
	label.modulate = Color("#FFF0D5")
	label.outline_modulate = Color("#2D2118")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 2.36, 0.125)
	gate.add_child(label)

	gates_root.add_child(gate)
	return gate


func _build_section_sign(
	section: Node3D,
	sign_text: String,
	board_material: Material,
	support_material: Material
) -> void:
	var sign_root := Node3D.new()
	sign_root.name = "SectionSign"
	section.add_child(sign_root)

	var sign_z := 0.0
	_add_box(sign_root, "Sign_Support_Left", Vector3(0.20, 2.85, 0.22), Vector3(-3.72, 1.425, sign_z), support_material)
	_add_box(sign_root, "Sign_Support_Right", Vector3(0.20, 2.85, 0.22), Vector3(3.72, 1.425, sign_z), support_material)
	_add_box(sign_root, "Wooden_Sign_Board", Vector3(7.55, 1.08, 0.22), Vector3(0.0, 2.43, sign_z), board_material)

	var label := Label3D.new()
	label.name = "SectionName"
	label.text = sign_text
	label.font_size = 38
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color("#fff0d5")
	label.outline_modulate = Color("#2d2118")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 2.43, sign_z + 0.13)
	sign_root.add_child(label)


func _create_grass_texture_batched(progress_start: float, progress_end: float) -> Texture2D:
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
		if (y + 1) % 16 == 0:
			var row_progress := float(y + 1) / 512.0
			setup_progress.emit("Generating campus grounds and landscaping", lerpf(progress_start, progress_start + (progress_end - progress_start) * 0.65, row_progress))
			await get_tree().process_frame

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
		if (blade_index + 1) % 300 == 0 or blade_index + 1 == 9000:
			var blade_progress := float(blade_index + 1) / 9000.0
			setup_progress.emit("Generating campus grounds and landscaping", lerpf(progress_start + (progress_end - progress_start) * 0.65, progress_end, blade_progress))
			await get_tree().process_frame
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _add_grass_instances_batched(progress_start: float, progress_end: float) -> void:
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color.WHITE
	blade_material.vertex_color_use_as_albedo = true
	blade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var blade_mesh := _create_grass_clump_mesh(blade_material, 0.19, GRASS_BLADE_COUNT)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = blade_mesh
	multi.instance_count = GRASS_INSTANCE_COUNT

	var rng := RandomNumberGenerator.new()
	rng.seed = 260911
	var maintained_count := int(float(GRASS_INSTANCE_COUNT) * MAINTAINED_GRASS_RATIO)
	var road_safe_instance_count := 0
	for index in range(GRASS_INSTANCE_COUNT):
		var is_maintained := index < maintained_count
		var edge := -1 if is_maintained else rng.randi_range(0, 3)
		var x: float
		var z: float
		while true:
			if is_maintained:
				x = rng.randf_range(-HALF_WIDTH * 0.38, HALF_WIDTH * 0.38)
				z = rng.randf_range(-HALF_DEPTH * 0.38, HALF_DEPTH * 0.38)
			elif edge == 0:
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
			if not _is_on_asphalt_road(x, z):
				break
		road_safe_instance_count += 1

		var scale_value := rng.randf_range(0.72, 0.98) if is_maintained else rng.randf_range(1.25, 2.05)
		var grass_transform_basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		multi.set_instance_transform(index, Transform3D(grass_transform_basis, Vector3(x, 0.012, z)))
		var shade := rng.randf_range(0.90, 1.08) if is_maintained else rng.randf_range(0.72, 1.12)
		var tint := Color(0.78, 0.94, 0.68, 1.0) if is_maintained else Color(0.74, 0.91, 0.61, 1.0)
		multi.set_instance_color(index, Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0))
		if (index + 1) % 256 == 0 or index + 1 == GRASS_INSTANCE_COUNT:
			setup_progress.emit("Generating campus grounds and landscaping", lerpf(progress_start, progress_start + (progress_end - progress_start) * 0.86, float(index + 1) / float(GRASS_INSTANCE_COUNT)))
			await get_tree().process_frame

	var grass := MultiMeshInstance3D.new()
	grass.name = "Hybrid_Grass_Clumps"
	grass.multimesh = multi
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	grass.set_meta("instance_count", GRASS_INSTANCE_COUNT)
	grass.set_meta("blade_count_per_instance", GRASS_BLADE_COUNT)
	grass.set_meta("maintained_core_instance_count", maintained_count)
	grass.set_meta("natural_edge_instance_count", GRASS_INSTANCE_COUNT - maintained_count)
	grass.set_meta("road_safe_instance_count", road_safe_instance_count)
	grass.set_meta("road_exclusion_enabled", road_safe_instance_count == GRASS_INSTANCE_COUNT)
	add_child(grass)


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

func _build_campus_trees_batched(progress_start: float, progress_end: float) -> void:
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
	# Keep all perimeter tree trunks outside the fenced plot footprints. The
	# six-metre border strip remains green without placing blockers in plots or roads.
	var perimeter_tree_z_positions := [-260.0, -220.0, -185.0, -110.0, -75.0, -35.0, 35.0, 75.0, 110.0, 185.0, 260.0]
	for z in perimeter_tree_z_positions:
		positions.append(Vector3(-398.0, 0.0, z))
		positions.append(Vector3(398.0, 0.0, z))
	var perimeter_tree_x_positions := [-380.0, -340.0, -280.0, -240.0, -120.0, -80.0, 80.0, 120.0, 240.0, 280.0, 340.0]
	for x in perimeter_tree_x_positions:
		positions.append(Vector3(x, 0.0, -298.0))
		positions.append(Vector3(x, 0.0, 298.0))

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
	var tree_collision_body := StaticBody3D.new()
	tree_collision_body.name = "Campus_Tree_Collisions"
	tree_collision_body.collision_layer = 1
	tree_collision_body.collision_mask = 0
	tree_collision_body.set_meta("blocks_player", true)
	tree_collision_body.set_meta("tree_collision_count", positions.size())
	for index in range(positions.size()):
		var size_x := rng.randf_range(0.82, 1.18)
		var size_y := rng.randf_range(0.88, 1.24)
		var size_z := rng.randf_range(0.82, 1.18)
		var yaw := rng.randf_range(0.0, TAU)
		var tree_instance_basis := Basis(Vector3.UP, yaw).scaled(Vector3(size_x, size_y, size_z))
		var tree_instance_transform := Transform3D(tree_instance_basis, positions[index])
		trunk_multi.set_instance_transform(index, tree_instance_transform)
		canopy_multi.set_instance_transform(index, tree_instance_transform)
		var trunk_collision := CollisionShape3D.new()
		trunk_collision.name = "TreeTrunkCollision_%02d" % (index + 1)
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.25 * maxf(size_x, size_z)
		trunk_shape.height = 4.35 * size_y
		trunk_collision.shape = trunk_shape
		trunk_collision.position = positions[index] + Vector3.UP * (trunk_shape.height * 0.5)
		tree_collision_body.add_child(trunk_collision)
		if (index + 1) % 8 == 0 or index + 1 == positions.size():
			setup_progress.emit("Generating campus grounds and landscaping", lerpf(progress_start, progress_end, float(index + 1) / float(positions.size())))
			await get_tree().process_frame
	add_child(tree_collision_body)
	var trunks := MultiMeshInstance3D.new()
	trunks.name = "Campus_Tree_Trunks"
	trunks.multimesh = trunk_multi
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trunks.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	trunks.set_meta("tree_count", positions.size())
	add_child(trunks)

	var canopies := MultiMeshInstance3D.new()
	canopies.name = "Campus_Tree_Canopies"
	canopies.multimesh = canopy_multi
	canopies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	player.position = Vector3(-366.0, 0.0, 0.0)
	player.collision_layer = 1
	player.collision_mask = 1
	player.set_meta("motion_model", "continuous_velocity")
	player.set_meta("motion_animation_drives_translation", false)
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
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
	# Prime interpolation history before the first camera read, then avoid a
	# spawn-time streak from the uninitialized previous transform.
	player.get_global_transform_interpolated()
	player.reset_physics_interpolation()


func _build_camera() -> void:
	player_camera = Camera3D.new()
	player_camera.name = "PlayerCamera"
	player_camera.fov = 78.0
	player_camera.near = 0.08
	player_camera.far = 500.0
	# The camera follows the interpolated target manually in _process so touch
	# look stays immediate instead of being delayed by physics interpolation.
	player_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(player_camera)
	player_camera.make_current()


func _career_company_identity_width(company_name: String) -> float:
	var font: Font = ThemeDB.fallback_font
	var name_width := font.get_string_size(company_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	var brand_width := font.get_string_size("DIGITAL WORLD MOBILES", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8).x
	return clampf(maxf(name_width, brand_width) + 16.0, 118.0, 232.0)


func _update_career_identity_card_width() -> void:
	if not is_instance_valid(career_identity_card):
		return
	var card_width := _career_company_identity_width(career_company_name)
	career_identity_card.custom_minimum_size = Vector2(card_width, 48.0)
	if is_instance_valid(career_company_label):
		career_company_label.custom_minimum_size = Vector2(card_width - 12.0, 0.0)


func _build_career_hud(root: Control) -> void:
	# This is only a transparent horizontal layout row. Each item below owns
	# its own card so the campus remains visible between the HUD elements.
	var row := HBoxContainer.new()
	row.name = "CampusCareerStatusBar"
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.anchor_right = 1.0
	row.anchor_bottom = 0.0
	row.offset_left = 14.0
	row.offset_top = 10.0
	row.offset_right = -14.0
	row.offset_bottom = 78.0
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	var insignia_frame := PanelContainer.new()
	insignia_frame.name = "CampusCompanyInsigniaFrame"
	insignia_frame.custom_minimum_size = Vector2(48.0, 48.0)
	_apply_career_hud_card_style(insignia_frame)
	row.add_child(insignia_frame)

	var insignia := TextureRect.new()
	insignia.name = "CampusCompanyInsignia"
	insignia.texture = career_insignia_texture
	insignia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	insignia.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	insignia.custom_minimum_size = Vector2(40.0, 40.0)
	insignia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	insignia_frame.add_child(insignia)

	career_identity_card = PanelContainer.new()
	career_identity_card.name = "CampusCompanyIdentityCard"
	career_identity_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	career_identity_card.custom_minimum_size = Vector2(_career_company_identity_width(career_company_name), 48.0)
	_apply_career_hud_card_style(career_identity_card)
	row.add_child(career_identity_card)

	# Keep company identity at the left and push all financial/time controls
	# together to the far right edge of the landscape HUD.
	var alignment_spacer := Control.new()
	alignment_spacer.name = "CampusCareerHudAlignmentSpacer"
	alignment_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(alignment_spacer)

	var identity := VBoxContainer.new()
	identity.name = "CampusCompanyIdentity"
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 1)
	career_identity_card.add_child(identity)

	var brand := Label.new()
	brand.text = "DIGITAL WORLD MOBILES"
	brand.add_theme_font_size_override("font_size", 8)
	brand.add_theme_color_override("font_color", Color("#D2A15C"))
	identity.add_child(brand)

	career_company_label = Label.new()
	career_company_label.name = "CampusCompanyName"
	career_company_label.text = career_company_name
	career_company_label.tooltip_text = career_company_name
	career_company_label.clip_text = true
	career_company_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	career_company_label.add_theme_font_size_override("font_size", 16)
	career_company_label.add_theme_color_override("font_color", Color("#F4F7FA"))
	career_company_label.custom_minimum_size = Vector2(career_identity_card.custom_minimum_size.x - 12.0, 0.0)
	identity.add_child(career_company_label)

	var balance_card := _make_career_metric_card("CampusBalanceCard", "BALANCE")
	row.add_child(balance_card)
	career_balance_label = balance_card.find_child("Value", true, false) as Label
	career_balance_label.name = "CampusBalanceValue"
	career_balance_label.text = career_balance_text

	var date_card := _make_career_metric_card("CampusDateCard", "DATE")
	row.add_child(date_card)
	career_date_label = date_card.find_child("Value", true, false) as Label
	career_date_label.name = "CampusDateValue"
	career_date_label.text = career_date_text

	var clock_card := PanelContainer.new()
	clock_card.name = "CampusGameClockCard"
	clock_card.custom_minimum_size = Vector2(90.0, 48.0)
	_apply_career_hud_card_style(clock_card)
	row.add_child(clock_card)

	career_clock_button = Button.new()
	career_clock_button.name = "CampusGameClockControl"
	career_clock_button.custom_minimum_size = Vector2(84.0, 42.0)
	career_clock_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	career_clock_button.focus_mode = Control.FOCUS_NONE
	career_clock_button.text = "▶  PLAY" if career_clock_paused else "Ⅱ  PAUSE"
	_style_overlay_button(career_clock_button)
	career_clock_button.add_theme_font_size_override("font_size", 10)
	career_clock_button.pressed.connect(func(): game_clock_toggle_requested.emit())
	clock_card.add_child(career_clock_button)


func _apply_career_hud_card_style(card: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.045, 0.78)
	style.border_color = Color(0.62, 0.49, 0.31, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)


func _make_career_metric_card(card_name: String, caption: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = Vector2(104.0, 46.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.088, 0.92)
	style.border_color = Color(0.35, 0.43, 0.48, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	card.add_child(content)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 7)
	caption_label.add_theme_color_override("font_color", Color("#A9BAC8"))
	content.add_child(caption_label)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color("#F4F7FA"))
	content.add_child(value_label)
	return card


func _build_overlay_batched() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Campus_Controls_Layer"
	layer.layer = 30
	# CanvasLayer visibility is independent of the parent Node3D's visibility.
	# Keep all campus HUD and touch controls hidden throughout startup loading.
	layer.visible = false
	add_child(layer)

	var root := Control.new()
	root.name = "CampusOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	overlay_root = root
	root.resized.connect(_layout_phone_controls)
	_build_career_hud(root)
	setup_progress.emit("Setting up first-person campus controls", 45.0)
	await get_tree().process_frame

	movement_joystick = JoystickScript.new() as Control
	movement_joystick.name = "MovementJoystick"
	movement_joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	movement_joystick.offset_left = 22.0
	movement_joystick.offset_top = -257.2
	movement_joystick.offset_right = 257.2
	movement_joystick.offset_bottom = -22.0
	movement_joystick.custom_minimum_size = Vector2(235.2, 235.2)
	root.add_child(movement_joystick)
	setup_progress.emit("Setting up first-person campus controls", 55.0)
	await get_tree().process_frame

	await _build_phone_controls_batched(root)
	_layout_phone_controls()
	call_deferred("_layout_phone_controls")
	setup_progress.emit("Setting up first-person campus controls", 100.0)
	await get_tree().process_frame


func _build_phone_controls_batched(root: Control) -> void:
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
	setup_progress.emit("Setting up first-person campus controls", 62.0)
	await get_tree().process_frame
	await _build_phone_screen_ui_batched(root)


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


func _build_phone_screen_ui_batched(root: Control) -> void:
	phone_screen_ui = Panel.new()
	phone_screen_ui.name = "PhoneScreenUI"
	phone_screen_ui.visible = false
	phone_screen_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_screen_ui.focus_mode = Control.FOCUS_NONE
	phone_screen_ui.clip_contents = true
	phone_screen_ui.z_index = 8
	phone_screen_ui.set_meta("screen_powered", true)
	phone_screen_ui.set_meta("home_app_count", 10)
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
	phone_home_view.add_theme_constant_override("separation", 5)
	phone_screen_ui.add_child(phone_home_view)
	phone_home_view.add_child(_make_phone_status_bar("PhoneHomeStatusBar"))

	var home_heading := Label.new()
	home_heading.name = "PhoneHomeHeading"
	home_heading.text = "Campus"
	home_heading.add_theme_font_size_override("font_size", 18)
	home_heading.add_theme_color_override("font_color", Color("#F4F7FA"))
	phone_home_view.add_child(home_heading)

	var home_subtitle := Label.new()
	home_subtitle.name = "PhoneHomeSubtitle"
	home_subtitle.text = career_company_name
	home_subtitle.add_theme_font_size_override("font_size", 8)
	home_subtitle.add_theme_color_override("font_color", Color("#A9BAC8"))
	phone_home_view.add_child(home_subtitle)

	var app_grid := GridContainer.new()
	app_grid.name = "PhoneHomeAppGrid"
	app_grid.columns = 3
	app_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_grid.add_theme_constant_override("h_separation", 5)
	app_grid.add_theme_constant_override("v_separation", 3)
	phone_home_view.add_child(app_grid)

	_add_phone_home_app(app_grid, "Explore", "ExploreAppIcon", "⌖", Callable(self, "_launch_explore_app"))
	_add_phone_home_app(app_grid, "Project", "ProjectAppIcon", "▤", Callable(self, "_request_project_launch"))
	_add_phone_home_app(app_grid, "Worksite", "WorksiteAppIcon", "▦", Callable(self, "_launch_worksite_app"))
	_add_phone_home_app(app_grid, "Research", "ResearchAppIcon", "◈", Callable(self, "_launch_research_app"))
	_add_phone_home_app(app_grid, "Staffs", "StaffsAppIcon", "♙", Callable(self, "_launch_staffs_app"))
	_add_phone_home_app(app_grid, "Products", "ProductsAppIcon", "▣", Callable(self, "_launch_phone_feature_app").bind("products"))
	setup_progress.emit("Setting up first-person campus controls", 68.0)
	await get_tree().process_frame
	_add_phone_home_app(app_grid, "Marketing", "MarketingAppIcon", "↗", Callable(self, "_launch_phone_feature_app").bind("marketing"))
	_add_phone_home_app(app_grid, "Media", "MediaAppIcon", "▧", Callable(self, "_launch_phone_feature_app").bind("media"))
	_add_phone_home_app(app_grid, "Office", "OfficeAppIcon", "⌂", Callable(self, "_launch_office_shortcut"))
	_add_phone_home_app(app_grid, "Statistics", "StatisticsAppIcon", "▥", Callable(self, "_launch_phone_feature_app").bind("statistics"))
	setup_progress.emit("Setting up first-person campus controls", 72.0)
	await get_tree().process_frame

	var home_footer := Label.new()
	home_footer.name = "PhoneHomeFooter"
	home_footer.text = "DIGITALWORLD CAMPUS"
	home_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_footer.add_theme_font_size_override("font_size", 7)
	home_footer.add_theme_color_override("font_color", Color("#778B9B"))
	phone_home_view.add_child(home_footer)

	var explore_page := _create_phone_app_page("ExploreAppScreen", "Explore", "Choose a campus section to travel there", "ExploreBackToHomeButton")
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
		section_button.set_meta("property_id", "LAND-%02d" % (section_index + 1))
		explore_section_buttons.append(section_button)
		_refresh_explore_section_buttons()
		if (section_index + 1) % 2 == 0 or section_index + 1 == CAMPUS_SECTION_NAMES.size():
			setup_progress.emit("Setting up first-person campus controls", 72.0 + 4.0 * float(section_index + 1) / float(CAMPUS_SECTION_NAMES.size()))
			await get_tree().process_frame

	explore_status_label = Label.new()
	explore_status_label.name = "ExploreStatusLabel"
	explore_status_label.text = "Select a section to travel there"
	explore_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explore_status_label.custom_minimum_size.y = 24.0
	explore_status_label.add_theme_font_size_override("font_size", 8)
	explore_status_label.add_theme_color_override("font_color", Color("#8FD7D1"))
	explore_app_view.add_child(explore_status_label)

	# Worksite and Research now open their standalone gateway screens directly.
	setup_progress.emit("Setting up first-person campus controls", 80.0)
	await get_tree().process_frame

	# Staffs now opens the standalone Staff gateway instead of an in-phone list.
	setup_progress.emit("Setting up first-person campus controls", 92.0)
	await get_tree().process_frame

	_add_phone_feature_page("ProductsAppScreen", "Products", "Company product catalogue", "ProductsBackToHomeButton", "Your product catalogue will appear here.")
	_add_phone_feature_page("MarketingAppScreen", "Marketing", "Promote your company's products", "MarketingBackToHomeButton", "Marketing tools will appear here.")
	setup_progress.emit("Setting up first-person campus controls", 96.0)
	await get_tree().process_frame
	_add_phone_feature_page("MediaAppScreen", "Media", "Company media and campaigns", "MediaBackToHomeButton", "Media tools will appear here.")
	_add_phone_feature_page("StatisticsAppScreen", "Statistics", "Company performance overview", "StatisticsBackToHomeButton", "Company statistics will appear here.")
	setup_progress.emit("Setting up first-person campus controls", 100.0)
	await get_tree().process_frame


func _add_phone_feature_page(page_name: String, title_text: String, description_text: String, back_button_name: String, message: String) -> void:
	var page_data := _create_phone_app_page(page_name, title_text, description_text, back_button_name)
	phone_screen_ui.add_child(page_data["page"])
	phone_app_views[page_name.trim_suffix("AppScreen").to_lower()] = page_data["page"]
	var status := Label.new()
	status.name = page_name + "Status"
	status.text = message
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", Color("#A9BAC8"))
	page_data["list"].add_child(status)


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
	app_icon.custom_minimum_size = Vector2(40.0, 40.0)
	app_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	app_icon.focus_mode = Control.FOCUS_NONE
	app_icon.tooltip_text = "Open " + app_title
	_style_phone_app_icon(app_icon)
	app_icon.add_theme_font_size_override("font_size", 20)
	app_icon.pressed.connect(action)
	tile.add_child(app_icon)

	var caption := Label.new()
	caption.name = button_name.replace("Icon", "Label")
	caption.text = app_title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 8)
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


func _launch_phone_feature_app(app_id: String) -> void:
	_open_phone_app(app_id)


func _launch_office_shortcut() -> void:
	_open_phone_app("explore")
	_transport_to_campus_section(1)


func _launch_explore_app() -> void:
	_open_phone_app("explore")
	_refresh_explore_section_buttons()
	if is_instance_valid(explore_status_label):
		explore_status_label.text = "LAND-01 is your starter compound. Seven other parcels remain visible and gated."


func _launch_worksite_app() -> void:
	_request_worksite_launch("create")


func _launch_research_app() -> void:
	_request_research_launch("hub")


func _request_project_launch() -> void:
	_close_phone_for_external_scene()
	project_launch_requested.emit()


func _launch_staffs_app() -> void:
	_request_staff_launch("hub")


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
	_return_to_phone_home()
	if is_instance_valid(phone_device):
		phone_device.visible = false
		phone_device.set_meta("phone_open", false)
	if is_instance_valid(phone_screen_ui):
		phone_screen_ui.visible = false
	if is_instance_valid(phone_button):
		phone_button.tooltip_text = "Open phone"
		phone_button.set_meta("phone_open", false)


func _request_worksite_launch(worksite_id: String) -> void:
	if worksite_id != "create":
		return
	_close_phone_for_external_scene()
	worksite_launch_requested.emit(worksite_id)


func _request_research_launch(research_id: String) -> void:
	if not ["hub", "phone", "camera", "processor"].has(research_id):
		return
	_close_phone_for_external_scene()
	research_launch_requested.emit(research_id)


func _request_staff_launch(staff_screen_id: String) -> void:
	if staff_screen_id != "hub":
		return
	_close_phone_for_external_scene()
	staff_launch_requested.emit(staff_screen_id)


func _transport_to_campus_section(section_index: int) -> void:
	if not is_instance_valid(player) or section_index < 0 or section_index >= CAMPUS_SECTION_NAMES.size():
		return
	if not _is_section_accessible(section_index):
		var locked_parcel_id := "LAND-%02d" % (section_index + 1)
		set_meta("last_locked_land_request", locked_parcel_id)
		if is_instance_valid(explore_status_label):
			explore_status_label.text = "ACCESS RESTRICTED: %s is not acquired. Its entrance gate is locked." % locked_parcel_id
		return
	var row_index := floori(float(section_index) / 4.0)
	var column_index := section_index % 4
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(
		SECTION_COLUMN_CENTERS[column_index],
		player.global_position.y,
		SECTION_ROW_CENTERS[row_index]
	)
	player.reset_physics_interpolation()
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

	# Let the handset nearly touch both landscape screen edges while
	# retaining a tiny two-pixel safety margin against clipping.
	var phone_height := minf(viewport_size.y * PHONE_BODY_HEIGHT_RATIO, viewport_size.y - PHONE_BODY_EDGE_MARGIN * 2.0)
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