extends Node3D

signal back_requested

const EmptyRoomAsset: PackedScene = preload("res://assets/3d/empty_room.gltf")

const WALK_SPEED := 2.65
const LOOK_SENSITIVITY := 0.0036
const CAMERA_EYE_HEIGHT := 1.60
const PLAYER_CAPSULE_RADIUS := 0.28
const PLAYER_CAPSULE_HEIGHT := 1.72
const JOYSTICK_RADIUS := 62.0 * 1.8
const JOYSTICK_DEADZONE := 0.12
const JOYSTICK_BASE_SIZE := Vector2(259.2, 259.2)
const JOYSTICK_THUMB_SIZE := Vector2(90.0, 90.0)
const LOOK_PAD_SIZE := Vector2(118.0, 118.0)

const LARGE_ROOM_WIDTH := 9.73
const LARGE_ROOM_DEPTH := 8.16
const LARGE_ROOM_HEIGHT := 3.20
const LARGE_ROOM_FRONT_Z := -2.66
const LARGE_ROOM_CENTER_Z := LARGE_ROOM_FRONT_Z - LARGE_ROOM_DEPTH * 0.5
const LARGE_ROOM_BACK_Z := LARGE_ROOM_FRONT_Z - LARGE_ROOM_DEPTH

var player: CharacterBody3D
var player_camera: Camera3D
var ui_root: Control
var move_pad_base: Panel
var move_pad_thumb: Panel
var look_pad_base: Panel
var joystick_vector := Vector2.ZERO
var move_pad_center := Vector2.ZERO
var look_pad_center := Vector2.ZERO
var camera_pitch := 0.0
var touch_roles: Dictionary = {}
var move_touch_index := -1
var mouse_move_active := false
var mouse_look_active := false
var room_wall_material: StandardMaterial3D
var door_pivot: Node3D
var door_collision_shape: CollisionShape3D
var door_open_button: Button
var door_is_open := false
var large_room_root: Node3D


func _ready() -> void:
	_build_room()
	_apply_room_finish()
	_build_glass_exit_door()
	_build_room_collisions()
	_build_large_empty_room()
	_build_environment()
	_build_first_person_player()
	_build_touch_controls()
	_build_door_interaction_ui()
	set_process_input(true)
	set_physics_process(true)


func _build_room() -> void:
	var room := EmptyRoomAsset.instantiate()
	room.name = "EmptyRoomAsset"
	add_child(room)


func _build_room_collisions() -> void:
	# The far wall has a framed glass exit door. The glass itself remains closed
	# and collidable, while the wall geometry is split around its opening.
	_add_room_collision_box("RoomFloorCollision", Vector3(0.0, -0.10, 0.0), Vector3(6.32, 0.20, 5.32))
	_add_room_collision_box("LeftWallCollision", Vector3(-3.08, 1.50, 0.0), Vector3(0.16, 3.0, 5.16))
	_add_room_collision_box("RightWallCollision", Vector3(3.08, 1.50, 0.0), Vector3(0.16, 3.0, 5.16))
	_add_room_collision_box("BackWallLeftCollision", Vector3(-1.90, 1.50, -2.58), Vector3(2.36, 3.0, 0.16))
	_add_room_collision_box("BackWallRightCollision", Vector3(1.90, 1.50, -2.58), Vector3(2.36, 3.0, 0.16))
	_add_room_collision_box("BackWallTopCollision", Vector3(0.0, 2.64, -2.58), Vector3(1.44, 0.88, 0.16))
	_add_room_collision_box("FrontWallCollision", Vector3(0.0, 1.50, 2.58), Vector3(6.16, 3.0, 0.16))
	_add_room_collision_box("CeilingCollision", Vector3(0.0, 3.08, 0.0), Vector3(6.16, 0.16, 5.16))


func _add_room_collision_box(node_name: String, center: Vector3, dimensions: Vector3) -> void:
	_add_collision_box_to(self, node_name, center, dimensions)


func _add_collision_box_to(parent: Node, node_name: String, center: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _apply_room_finish() -> void:
	var room := get_node_or_null("EmptyRoomAsset")
	if room == null:
		return
	var mesh_nodes := room.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		push_warning("Empty room model has no mesh to receive its surface finish.")
		return
	var room_mesh := mesh_nodes[0] as MeshInstance3D
	if room_mesh.mesh == null or room_mesh.mesh.get_surface_count() < 6:
		push_warning("Empty room model does not contain the expected six surfaces.")
		return

	room_wall_material = _make_room_material("Soft textured warm wall plaster", Color("#D2D0C8"), 0.94, 0.018, 41, false)
	var wall_material := room_wall_material
	var floor_material := _make_room_material("Subtle tiled mineral floor", Color("#858A8B"), 0.88, 0.025, 73, true)
	var ceiling_material := _make_room_material("Light matte ceiling", Color("#E5E2DB"), 0.97, 0.008, 19, false)
	room_mesh.set_surface_override_material(0, floor_material)
	room_mesh.set_surface_override_material(1, wall_material)
	room_mesh.set_surface_override_material(2, wall_material)
	room_mesh.set_surface_override_material(4, wall_material)
	room_mesh.set_surface_override_material(5, ceiling_material)

	# The original solid back wall surface is replaced by three wall sections,
	# leaving a real visual opening for the glass door.
	var hidden_wall := StandardMaterial3D.new()
	hidden_wall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hidden_wall.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	hidden_wall.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	room_mesh.set_surface_override_material(3, hidden_wall)


func _make_room_material(material_name: String, base_color: Color, roughness_value: float, noise_amount: float, seed_value: int, add_tile_lines: bool) -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = seed_value
	noise.frequency = 0.055
	for y in range(128):
		for x in range(128):
			var variation := noise.get_noise_2d(float(x), float(y)) * noise_amount
			var pixel := Color(
				clampf(base_color.r + variation, 0.0, 1.0),
				clampf(base_color.g + variation, 0.0, 1.0),
				clampf(base_color.b + variation, 0.0, 1.0),
				1.0
			)
			if add_tile_lines and (x % 32 <= 1 or y % 32 <= 1):
				pixel = pixel.darkened(0.045)
			image.set_pixel(x, y, pixel)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = roughness_value
	material.metallic = 0.0
	material.uv1_scale = Vector3(2.0, 2.0, 1.0)
	return material


func _build_glass_exit_door() -> void:
	var wall_material: Material = room_wall_material
	if wall_material == null:
		var fallback_wall := StandardMaterial3D.new()
		fallback_wall.albedo_color = Color("#D2D0C8")
		fallback_wall.roughness = 0.94
		wall_material = fallback_wall

	# Rebuild the far wall around a 1.44 m wide, 2.20 m high doorway.
	_add_visual_box("ExitDoorWallLeft", Vector3(-1.90, 1.50, -2.58), Vector3(2.36, 3.16, 0.16), wall_material)
	_add_visual_box("ExitDoorWallRight", Vector3(1.90, 1.50, -2.58), Vector3(2.36, 3.16, 0.16), wall_material)
	_add_visual_box("ExitDoorWallLintel", Vector3(0.0, 2.64, -2.58), Vector3(1.44, 0.88, 0.16), wall_material)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color("#343B3E")
	frame_material.metallic = 0.48
	frame_material.roughness = 0.38
	_add_visual_box("GlassExitDoorFrameLeft", Vector3(-0.68, 1.10, -2.49), Vector3(0.08, 2.20, 0.16), frame_material)
	_add_visual_box("GlassExitDoorFrameRight", Vector3(0.68, 1.10, -2.49), Vector3(0.08, 2.20, 0.16), frame_material)
	_add_visual_box("GlassExitDoorFrameTop", Vector3(0.0, 2.20, -2.49), Vector3(1.44, 0.10, 0.16), frame_material)
	_add_visual_box("GlassExitDoorThreshold", Vector3(0.0, 0.045, -2.49), Vector3(1.44, 0.09, 0.20), frame_material)

	# The glass leaf and its collision share a hinge, so the door really swings
	# into the larger room rather than disappearing when the player taps OPEN.
	door_pivot = Node3D.new()
	door_pivot.name = "GlassExitDoorPivot"
	door_pivot.position = Vector3(-0.60, 0.0, -2.475)
	add_child(door_pivot)

	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.44, 0.66, 0.69, 0.38)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.22
	glass_material.roughness = 0.16
	glass_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_visual_box_to(door_pivot, "GlassExitDoorPane", Vector3(0.60, 1.10, 0.0), Vector3(1.20, 2.08, 0.035), glass_material)

	var handle_mount_material := StandardMaterial3D.new()
	handle_mount_material.albedo_color = Color("#24292B")
	handle_mount_material.metallic = 0.62
	handle_mount_material.roughness = 0.30
	_add_visual_box_to(door_pivot, "ExitDoorHandleMount", Vector3(1.08, 1.08, 0.045), Vector3(0.075, 0.22, 0.035), handle_mount_material)

	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color("#C6C9C7")
	handle_material.metallic = 0.82
	handle_material.roughness = 0.22
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.018
	handle_mesh.bottom_radius = 0.018
	handle_mesh.height = 0.34
	handle_mesh.radial_segments = 12
	var handle := MeshInstance3D.new()
	handle.name = "ExitDoorPullHandle"
	handle.mesh = handle_mesh
	handle.position = Vector3(1.08, 1.08, 0.075)
	handle.material_override = handle_material
	door_pivot.add_child(handle)

	var door_body := AnimatableBody3D.new()
	door_body.name = "GlassExitDoorCollision"
	door_body.sync_to_physics = true
	var door_shape := CollisionShape3D.new()
	door_shape.name = "GlassExitDoorCollisionShape"
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(1.20, 2.12, 0.08)
	door_shape.shape = door_box
	door_shape.position = Vector3(0.60, 1.10, 0.0)
	door_body.add_child(door_shape)
	door_pivot.add_child(door_body)
	door_collision_shape = door_shape

	var sign_material := StandardMaterial3D.new()
	sign_material.albedo_color = Color("#1E4938")
	sign_material.roughness = 0.72
	_add_visual_box("ExitSignPanel", Vector3(0.0, 2.37, -2.48), Vector3(0.62, 0.18, 0.055), sign_material)

	var exit_label := Label3D.new()
	exit_label.name = "ExitSignText"
	exit_label.text = "EXIT"
	exit_label.font_size = 42
	exit_label.pixel_size = 0.0017
	exit_label.modulate = Color("#E6F6EB")
	exit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exit_label.position = Vector3(0.0, 2.345, -2.44)
	add_child(exit_label)


func _add_visual_box(node_name: String, center: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	return _add_visual_box_to(self, node_name, center, dimensions, material)


func _add_visual_box_to(parent: Node, node_name: String, center: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.position = center
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_large_empty_room() -> void:
	large_room_root = Node3D.new()
	large_room_root.name = "LargeEmptyRoom"
	add_child(large_room_root)

	var half_width := LARGE_ROOM_WIDTH * 0.5
	var front_z := LARGE_ROOM_FRONT_Z
	var back_z := LARGE_ROOM_BACK_Z
	var center_z := LARGE_ROOM_CENTER_Z
	var wall_material := _make_room_material("Large room plaster walls", Color("#D2D0C8"), 0.94, 0.014, 97, false)
	var floor_material := _make_room_material("Large room mineral floor", Color("#929897"), 0.88, 0.020, 101, true)
	var ceiling_material := _make_room_material("Large room matte ceiling", Color("#E5E2DB"), 0.97, 0.008, 109, false)

	var metal_material := StandardMaterial3D.new()
	metal_material.albedo_color = Color("#42494B")
	metal_material.metallic = 0.46
	metal_material.roughness = 0.38

	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color("#70533D")
	wood_material.roughness = 0.76

	var wood_trim_material := StandardMaterial3D.new()
	wood_trim_material.albedo_color = Color("#352C25")
	wood_trim_material.roughness = 0.66

	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.52, 0.72, 0.78, 0.34)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.12
	glass_material.roughness = 0.18
	glass_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var window_backdrop_material := StandardMaterial3D.new()
	window_backdrop_material.albedo_color = Color("#8FA7B2")
	window_backdrop_material.roughness = 1.0
	window_backdrop_material.emission_enabled = true
	window_backdrop_material.emission = Color("#425762")
	window_backdrop_material.emission_energy_multiplier = 0.42

	var stair_material := StandardMaterial3D.new()
	stair_material.albedo_color = Color("#777C7B")
	stair_material.roughness = 0.84

	# This room has 2.5 times the floor area of the first room (about 79.4 m²).
	_add_large_room_box("LargeRoomFloor", Vector3(0.0, -0.09, center_z), Vector3(LARGE_ROOM_WIDTH, 0.18, LARGE_ROOM_DEPTH), floor_material)
	_add_large_room_box("LargeRoomCeiling", Vector3(0.0, LARGE_ROOM_HEIGHT + 0.08, center_z), Vector3(LARGE_ROOM_WIDTH, 0.16, LARGE_ROOM_DEPTH), ceiling_material)

	# The front wall has a matching opening so the glass door connects directly
	# into this room with no step or narrow corridor between the spaces.
	var entry_half_width := 0.72
	var side_wall_width := half_width - entry_half_width
	var side_wall_center := (half_width + entry_half_width) * 0.5
	_add_large_room_box("LargeRoomFrontWallLeft", Vector3(-side_wall_center, LARGE_ROOM_HEIGHT * 0.5, front_z + 0.08), Vector3(side_wall_width, LARGE_ROOM_HEIGHT, 0.16), wall_material)
	_add_large_room_box("LargeRoomFrontWallRight", Vector3(side_wall_center, LARGE_ROOM_HEIGHT * 0.5, front_z + 0.08), Vector3(side_wall_width, LARGE_ROOM_HEIGHT, 0.16), wall_material)
	_add_large_room_box("LargeRoomFrontWallLintel", Vector3(0.0, 2.70, front_z + 0.08), Vector3(1.44, 1.0, 0.16), wall_material)

	# Side walls each contain a wide daylight window and one closed interior door.
	var window_center_z := -5.90
	var window_half_width := 1.0
	var window_front_edge := window_center_z + window_half_width
	var window_back_edge := window_center_z - window_half_width
	var side_door_z := -9.55
	var side_door_half_width := 0.55
	var side_door_front_edge := side_door_z + side_door_half_width
	var side_door_back_edge := side_door_z - side_door_half_width

	for side in [-1.0, 1.0]:
		var wall_x := side * (half_width - 0.08)
		var front_segment_length := window_front_edge - front_z
		var middle_segment_length := side_door_front_edge - window_back_edge
		var rear_segment_length := back_z - side_door_back_edge
		_add_large_room_box("LargeRoomSideFrontWall%d" % int(side), Vector3(wall_x, 1.60, (front_z + window_front_edge) * 0.5), Vector3(0.16, LARGE_ROOM_HEIGHT, front_segment_length), wall_material)
		_add_large_room_box("LargeRoomSideMiddleWall%d" % int(side), Vector3(wall_x, 1.60, (window_back_edge + side_door_front_edge) * 0.5), Vector3(0.16, LARGE_ROOM_HEIGHT, middle_segment_length), wall_material)
		_add_large_room_box("LargeRoomSideRearWall%d" % int(side), Vector3(wall_x, 1.60, (side_door_back_edge + back_z) * 0.5), Vector3(0.16, LARGE_ROOM_HEIGHT, rear_segment_length), wall_material)
		_add_large_room_box("LargeRoomSideWindowSill%d" % int(side), Vector3(wall_x, 0.55, window_center_z), Vector3(0.16, 1.10, 2.0), wall_material)
		_add_large_room_box("LargeRoomSideWindowHeader%d" % int(side), Vector3(wall_x, 2.85, window_center_z), Vector3(0.16, 0.70, 2.0), wall_material)

		var outer_x := side * (half_width + 0.20)
		_add_visual_box_to(large_room_root, "LargeRoomWindowBackdrop%d" % int(side), Vector3(outer_x, 1.80, window_center_z), Vector3(0.025, 1.30, 1.88), window_backdrop_material)
		_add_visual_box_to(large_room_root, "LargeRoomWindowGlass%d" % int(side), Vector3(side * (half_width - 0.045), 1.80, window_center_z), Vector3(0.035, 1.36, 1.96), glass_material)
		_add_visual_box_to(large_room_root, "LargeRoomWindowFrameTop%d" % int(side), Vector3(wall_x, 2.50, window_center_z), Vector3(0.11, 0.09, 2.14), metal_material)
		_add_visual_box_to(large_room_root, "LargeRoomWindowFrameBottom%d" % int(side), Vector3(wall_x, 1.10, window_center_z), Vector3(0.11, 0.09, 2.14), metal_material)
		for edge in [-1.0, 1.0]:
			_add_visual_box_to(large_room_root, "LargeRoomWindowFrameSide%d_%d" % [int(side), int(edge)], Vector3(wall_x, 1.80, window_center_z + edge * 1.04), Vector3(0.11, 1.48, 0.09), metal_material)

		_add_large_room_box("LargeRoomInteriorDoor%d" % (1 if side < 0.0 else 2), Vector3(side * (half_width - 0.045), 1.08, side_door_z), Vector3(0.05, 2.12, 1.0), wood_material)
		for edge in [-1.0, 1.0]:
			_add_visual_box_to(large_room_root, "LargeRoomSideDoorJamb%d_%d" % [int(side), int(edge)], Vector3(wall_x, 1.10, side_door_z + edge * 0.56), Vector3(0.10, 2.20, 0.10), wood_trim_material)
		_add_visual_box_to(large_room_root, "LargeRoomSideDoorHeader%d" % int(side), Vector3(wall_x, 2.22, side_door_z), Vector3(0.10, 0.10, 1.18), wood_trim_material)
		_add_visual_box_to(large_room_root, "LargeRoomSideDoorHandle%d" % int(side), Vector3(side * (half_width - 0.15), 1.08, side_door_z + 0.30), Vector3(0.06, 0.12, 0.08), metal_material)

	# The far wall contains two additional doors, bringing the room to four.
	var rear_door_centers := [-2.20, 2.20]
	var rear_door_half_width := 0.55
	var rear_left_edge := rear_door_centers[0] - rear_door_half_width
	var rear_left_inner := rear_door_centers[0] + rear_door_half_width
	var rear_right_inner := rear_door_centers[1] - rear_door_half_width
	var rear_right_edge := rear_door_centers[1] + rear_door_half_width
	_add_large_room_box("LargeRoomRearWallLeft", Vector3((-half_width + rear_left_edge) * 0.5, 1.60, back_z + 0.08), Vector3(rear_left_edge + half_width, LARGE_ROOM_HEIGHT, 0.16), wall_material)
	_add_large_room_box("LargeRoomRearWallCenter", Vector3((rear_left_inner + rear_right_inner) * 0.5, 1.60, back_z + 0.08), Vector3(rear_right_inner - rear_left_inner, LARGE_ROOM_HEIGHT, 0.16), wall_material)
	_add_large_room_box("LargeRoomRearWallRight", Vector3((rear_right_edge + half_width) * 0.5, 1.60, back_z + 0.08), Vector3(half_width - rear_right_edge, LARGE_ROOM_HEIGHT, 0.16), wall_material)
	for door_index in range(rear_door_centers.size()):
		var door_x: float = rear_door_centers[door_index]
		_add_large_room_box("LargeRoomInteriorDoor%d" % (door_index + 3), Vector3(door_x, 1.08, back_z + 0.045), Vector3(1.0, 2.12, 0.05), wood_material)
		for edge in [-1.0, 1.0]:
			_add_visual_box_to(large_room_root, "LargeRoomRearDoorJamb%d_%d" % [door_index, int(edge)], Vector3(door_x + edge * 0.56, 1.10, back_z + 0.045), Vector3(0.10, 2.20, 0.10), wood_trim_material)
		_add_visual_box_to(large_room_root, "LargeRoomRearDoorHeader%d" % door_index, Vector3(door_x, 2.22, back_z + 0.045), Vector3(1.18, 0.10, 0.10), wood_trim_material)
		_add_visual_box_to(large_room_root, "LargeRoomRearDoorHandle%d" % door_index, Vector3(door_x + 0.30, 1.08, back_z + 0.12), Vector3(0.08, 0.12, 0.06), metal_material)

	# A compact in-house staircase rises to a small upper landing.
	var stair_angle := atan2(1.80, 3.80)
	var stair_rotation := Vector3(-stair_angle, PI, 0.0)
	_add_large_room_rotated_box("LargeRoomStairRamp", Vector3(2.85, 0.90, -6.30), Vector3(1.55, 0.14, 3.80), stair_material, stair_rotation, true)
	for step_index in range(9):
		var step_height := float(step_index + 1) * 0.20
		var step_z := -4.50 - float(step_index) * 0.40
		_add_large_room_box("LargeRoomStairStep%02d" % step_index, Vector3(2.85, step_height * 0.5, step_z), Vector3(1.45, 0.20, 0.46), stair_material)
	for side in [-1.0, 1.0]:
		_add_large_room_rotated_box("LargeRoomStairHandrail%d" % int(side), Vector3(2.85 + side * 0.82, 1.00, -6.30), Vector3(0.075, 0.075, 4.0), wood_trim_material, stair_rotation, false)
	_add_large_room_box("LargeRoomStairLanding", Vector3(2.85, 1.85, -8.45), Vector3(1.90, 0.16, 1.15), stair_material)

	var room_light := OmniLight3D.new()
	room_light.name = "LargeRoomCeilingLight"
	room_light.position = Vector3(0.0, 2.72, center_z)
	room_light.light_color = Color("#FFF5E8")
	room_light.light_energy = 1.50
	room_light.omni_range = 13.5
	room_light.shadow_enabled = false
	large_room_root.add_child(room_light)

	var stair_fill := OmniLight3D.new()
	stair_fill.name = "LargeRoomStairLight"
	stair_fill.position = Vector3(2.8, 2.45, -7.0)
	stair_fill.light_color = Color("#F3EEE4")
	stair_fill.light_energy = 0.82
	stair_fill.omni_range = 6.0
	stair_fill.shadow_enabled = false
	large_room_root.add_child(stair_fill)


func _add_large_room_box(node_name: String, center: Vector3, dimensions: Vector3, material: Material, collision_enabled: bool = true) -> MeshInstance3D:
	var mesh_instance := _add_visual_box_to(large_room_root, node_name, center, dimensions, material)
	if collision_enabled:
		_add_collision_box_to(large_room_root, node_name + "Collision", center, dimensions)
	return mesh_instance


func _add_large_room_rotated_box(node_name: String, center: Vector3, dimensions: Vector3, material: Material, rotation_value: Vector3, collision_enabled: bool) -> MeshInstance3D:
	var mesh_instance := _add_visual_box_to(large_room_root, node_name, center, dimensions, material)
	mesh_instance.rotation = rotation_value
	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = node_name + "Collision"
		body.position = center
		body.rotation = rotation_value
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = dimensions
		shape.shape = box
		body.add_child(shape)
		large_room_root.add_child(body)
	return mesh_instance


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "EmptyRoomEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111416")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#D4D0C5")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var ceiling_fill := OmniLight3D.new()
	ceiling_fill.name = "HiddenCeilingFill"
	ceiling_fill.position = Vector3(0.0, 2.72, 0.0)
	ceiling_fill.light_color = Color("#FFF5E7")
	ceiling_fill.light_energy = 1.75
	ceiling_fill.omni_range = 8.0
	ceiling_fill.shadow_enabled = false
	add_child(ceiling_fill)

	var soft_key := DirectionalLight3D.new()
	soft_key.name = "SoftInteriorKey"
	soft_key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	soft_key.light_color = Color("#F4F0E8")
	soft_key.light_energy = 0.34
	soft_key.shadow_enabled = false
	add_child(soft_key)


func _build_first_person_player() -> void:
	player = CharacterBody3D.new()
	player.name = "FirstPersonPlayer"
	player.position = Vector3(0.0, 0.02, 1.35)
	player.floor_snap_length = 0.22
	player.safe_margin = 0.002
	add_child(player)

	var player_collision := CollisionShape3D.new()
	player_collision.name = "PlayerCapsule"
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS
	capsule.height = PLAYER_CAPSULE_HEIGHT
	player_collision.shape = capsule
	player_collision.position.y = PLAYER_CAPSULE_HEIGHT * 0.5
	player.add_child(player_collision)

	player_camera = Camera3D.new()
	player_camera.name = "EmptyRoomCamera"
	player_camera.position = Vector3(0.0, CAMERA_EYE_HEIGHT, 0.0)
	player_camera.fov = 78.0
	player_camera.near = 0.05
	player_camera.far = 40.0
	player.add_child(player_camera)
	player_camera.current = true


func _build_touch_controls() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "EmptyRoomFirstPersonUI"
	ui_layer.layer = 20
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.name = "EmptyRoomFirstPersonUIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)

	var back_button := Button.new()
	back_button.name = "EmptyRoomBackButton"
	back_button.text = "‹  BACK"
	back_button.position = Vector2(18.0, 18.0)
	back_button.size = Vector2(126.0, 48.0)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.add_theme_color_override("font_color", Color("#F2EDE4"))
	back_button.add_theme_color_override("font_hover_color", Color.WHITE)
	back_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#25282A")
		if state == "hover":
			style.bg_color = Color("#34383A")
		elif state == "pressed":
			style.bg_color = Color("#191C1E")
		style.border_color = Color("#A47A43")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		back_button.add_theme_stylebox_override(state, style)
	back_button.pressed.connect(_request_back)
	ui_root.add_child(back_button)

	move_pad_base = _make_round_panel("MovementJoystickBase", JOYSTICK_BASE_SIZE, Color(0.08, 0.10, 0.12, 0.48), Color(0.83, 0.78, 0.69, 0.48))
	ui_root.add_child(move_pad_base)
	move_pad_thumb = _make_round_panel("MovementJoystickThumb", JOYSTICK_THUMB_SIZE, Color(0.78, 0.72, 0.62, 0.82), Color(0.96, 0.91, 0.82, 0.78))
	ui_root.add_child(move_pad_thumb)

	look_pad_base = _make_round_panel("LookPad", LOOK_PAD_SIZE, Color(0.08, 0.10, 0.12, 0.30), Color(0.83, 0.78, 0.69, 0.38))
	ui_root.add_child(look_pad_base)
	_layout_touch_controls()


func _make_round_panel(node_name: String, panel_size: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(panel_size.x * 0.5))
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _layout_touch_controls() -> void:
	if not is_instance_valid(ui_root):
		return
	var screen_size := get_viewport().get_visible_rect().size
	move_pad_center = Vector2(maxf(JOYSTICK_RADIUS + 18.0, screen_size.x * 0.19), screen_size.y - JOYSTICK_RADIUS - 24.0)
	look_pad_center = Vector2(screen_size.x - maxf(78.0, screen_size.x * 0.17), screen_size.y - 112.0)
	move_pad_base.position = move_pad_center - JOYSTICK_BASE_SIZE * 0.5
	move_pad_thumb.position = move_pad_center - JOYSTICK_THUMB_SIZE * 0.5
	look_pad_base.position = look_pad_center - LOOK_PAD_SIZE * 0.5
	if is_instance_valid(door_open_button):
		door_open_button.position = Vector2(screen_size.x * 0.78 - 46.0, screen_size.y * 0.64 - 46.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		if not touch_roles.has(event.index):
			return
		var role: String = touch_roles[event.index]
		if role == "move":
			_set_move_joystick(event.position)
		elif role == "look":
			_apply_look(event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _is_move_zone(event.position):
				mouse_move_active = true
				_set_move_joystick(event.position)
			elif not event.pressed and mouse_move_active:
				mouse_move_active = false
				_reset_move_joystick()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_look_active = event.pressed
	elif event is InputEventMouseMotion:
		if mouse_move_active:
			_set_move_joystick(event.position)
		elif mouse_look_active:
			_apply_look(event.relative)


func _begin_touch(index: int, touch_position: Vector2) -> void:
	var screen_size := get_viewport().get_visible_rect().size
	if is_instance_valid(door_open_button) and door_open_button.visible and door_open_button.get_global_rect().has_point(touch_position):
		return
	if _is_move_zone(touch_position) and move_touch_index == -1:
		touch_roles[index] = "move"
		move_touch_index = index
		_set_move_joystick(touch_position)
	elif touch_position.x >= screen_size.x * 0.5:
		touch_roles[index] = "look"


func _end_touch(index: int) -> void:
	if not touch_roles.has(index):
		return
	var role: String = touch_roles[index]
	touch_roles.erase(index)
	if role == "move":
		move_touch_index = -1
		_reset_move_joystick()


func _is_move_zone(touch_position: Vector2) -> bool:
	var screen_size := get_viewport().get_visible_rect().size
	return touch_position.x < screen_size.x * 0.5 and touch_position.y > screen_size.y * 0.52


func _set_move_joystick(touch_position: Vector2) -> void:
	var offset := touch_position - move_pad_center
	var distance := offset.length()
	var clamped_offset := offset
	if distance > JOYSTICK_RADIUS:
		clamped_offset = offset.normalized() * JOYSTICK_RADIUS
	var strength := clampf(distance / JOYSTICK_RADIUS, 0.0, 1.0)
	if strength <= JOYSTICK_DEADZONE:
		joystick_vector = Vector2.ZERO
	else:
		var adjusted_strength := (strength - JOYSTICK_DEADZONE) / (1.0 - JOYSTICK_DEADZONE)
		joystick_vector = offset.normalized() * adjusted_strength
	move_pad_thumb.position = move_pad_center + clamped_offset - JOYSTICK_THUMB_SIZE * 0.5


func _reset_move_joystick() -> void:
	joystick_vector = Vector2.ZERO
	if is_instance_valid(move_pad_thumb):
		move_pad_thumb.position = move_pad_center - JOYSTICK_THUMB_SIZE * 0.5


func _apply_look(relative: Vector2) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player_camera):
		return
	player.rotation.y -= relative.x * LOOK_SENSITIVITY
	camera_pitch = clampf(camera_pitch - relative.y * LOOK_SENSITIVITY, deg_to_rad(-80.0), deg_to_rad(80.0))
	player_camera.rotation.x = camera_pitch


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var movement_direction := player.global_transform.basis * Vector3(joystick_vector.x, 0.0, joystick_vector.y)
	movement_direction.y = 0.0
	if movement_direction.length_squared() > 1.0:
		movement_direction = movement_direction.normalized()
	player.velocity.x = movement_direction.x * WALK_SPEED
	player.velocity.z = movement_direction.z * WALK_SPEED

	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		player.velocity.y -= gravity * delta
	player.move_and_slide()
	_update_door_interaction()


func _build_door_interaction_ui() -> void:
	door_open_button = Button.new()
	door_open_button.name = "DoorOpenCircleButton"
	door_open_button.text = "OPEN"
	door_open_button.size = Vector2(92.0, 92.0)
	door_open_button.focus_mode = Control.FOCUS_NONE
	door_open_button.visible = false
	door_open_button.add_theme_font_size_override("font_size", 14)
	door_open_button.add_theme_color_override("font_color", Color("#FFF4DF"))
	door_open_button.add_theme_color_override("font_hover_color", Color.WHITE)
	door_open_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	door_open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#423521")
		if state == "hover":
			style.bg_color = Color("#604B2B")
		elif state == "pressed":
			style.bg_color = Color("#302515")
		style.border_color = Color("#D0A365")
		style.set_border_width_all(2)
		style.set_corner_radius_all(46)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		style.shadow_size = 8
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		door_open_button.add_theme_stylebox_override(state, style)
	door_open_button.pressed.connect(_open_exit_door)
	ui_root.add_child(door_open_button)
	_layout_touch_controls()


func _update_door_interaction() -> void:
	if not is_instance_valid(door_open_button) or not is_instance_valid(player) or door_is_open:
		if is_instance_valid(door_open_button):
			door_open_button.hide()
		return
	var horizontal_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(0.0, -2.20))
	door_open_button.visible = horizontal_distance <= 1.85


func _open_exit_door() -> void:
	if door_is_open or not is_instance_valid(door_pivot):
		return
	door_is_open = true
	if is_instance_valid(door_open_button):
		door_open_button.hide()
	var opening_tween := create_tween()
	opening_tween.set_trans(Tween.TRANS_CUBIC)
	opening_tween.set_ease(Tween.EASE_OUT)
	opening_tween.tween_property(door_pivot, "rotation", Vector3(0.0, deg_to_rad(95.0), 0.0), 0.62)
	opening_tween.tween_callback(func() -> void:
		if is_instance_valid(door_collision_shape):
			door_collision_shape.set_deferred("disabled", true)
	)


func _request_back() -> void:
	back_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_instance_valid(ui_root):
		_layout_touch_controls()
