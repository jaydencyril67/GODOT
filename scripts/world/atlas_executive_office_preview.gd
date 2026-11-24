extends Node3D

signal back_requested

const OFFICE_ASSET: PackedScene = preload("res://assets/3d/atlas_executive_office.glb")

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
const TARGET_INTERIOR_HEIGHT := 3.40
const EXTERIOR_NAME_HINTS := [
	"skyline", "tower", "maple", "hedge", "bush", "plant",
	"tree", "landscape", "exterior", "background"
]

var office_instance: Node3D
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
var office_bounds := AABB()
var walkable_floor_found := false
var fallback_floor_created := false


func _ready() -> void:
	_build_environment()
	if not _load_office_asset():
		return
	_build_office_collision()
	# Let the physics server register the imported room collision before
	# selecting a floor point for the player spawn.
	await get_tree().physics_frame
	_build_first_person_player()
	_build_touch_controls()
	set_process_input(true)
	set_physics_process(true)


func _load_office_asset() -> bool:
	office_instance = OFFICE_ASSET.instantiate() as Node3D
	if office_instance == null:
		push_error("The Atlas executive office GLB could not be instantiated.")
		return false

	office_instance.name = "AtlasExecutiveOffice"
	add_child(office_instance)

	var mesh_nodes := office_instance.find_children("*", "MeshInstance3D", true, false)
	var raw_bounds := AABB()
	var has_bounds := false
	for candidate in mesh_nodes:
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or _is_exterior_mesh(mesh_instance):
			continue
		var mesh_bounds: AABB = mesh_instance.get_aabb() * mesh_instance.global_transform
		if not has_bounds:
			raw_bounds = mesh_bounds
			has_bounds = true
		else:
			raw_bounds = raw_bounds.merge(mesh_bounds)

	if not has_bounds or raw_bounds.size.y <= 0.05:
		push_error("The Atlas office did not contain measurable interior mesh geometry.")
		return false

	var scale_factor := clampf(TARGET_INTERIOR_HEIGHT / raw_bounds.size.y, 0.05, 12.0)
	var raw_center := raw_bounds.get_center()
	office_instance.scale = Vector3.ONE * scale_factor
	office_instance.position = Vector3(
		-raw_center.x * scale_factor,
		-raw_bounds.position.y * scale_factor,
		-raw_center.z * scale_factor
	)
	office_instance.force_update_transform()
	office_bounds = AABB(
		Vector3(-raw_bounds.size.x * scale_factor * 0.5, 0.0, -raw_bounds.size.z * scale_factor * 0.5),
		raw_bounds.size * scale_factor
	)
	return true


func _is_exterior_mesh(mesh_instance: MeshInstance3D) -> bool:
	var current: Node = mesh_instance
	while current != null and current != office_instance:
		var node_name := str(current.name).to_lower()
		for hint in EXTERIOR_NAME_HINTS:
			if node_name.contains(hint):
				return true
		current = current.get_parent()
	return false


func _build_office_collision() -> void:
	var faces := PackedVector3Array()
	var mesh_nodes := office_instance.find_children("*", "MeshInstance3D", true, false)
	var preview_from_world := global_transform.affine_inverse()

	for candidate in mesh_nodes:
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or _is_exterior_mesh(mesh_instance):
			continue
		if not mesh_instance.visible:
			continue

		var mesh_to_preview := preview_from_world * mesh_instance.global_transform
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var surface_arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			if surface_arrays.is_empty():
				continue
			var vertices_value: Variant = surface_arrays[Mesh.ARRAY_VERTEX]
			if not (vertices_value is PackedVector3Array):
				continue
			var vertices: PackedVector3Array = vertices_value
			if vertices.size() < 3:
				continue

			var indices := PackedInt32Array()
			var indices_value: Variant = surface_arrays[Mesh.ARRAY_INDEX]
			if indices_value is PackedInt32Array:
				indices = indices_value

			if indices.is_empty():
				for index in range(0, vertices.size() - 2, 3):
					faces.push_back(mesh_to_preview * vertices[index])
					faces.push_back(mesh_to_preview * vertices[index + 1])
					faces.push_back(mesh_to_preview * vertices[index + 2])
			else:
				for index in range(0, indices.size() - 2, 3):
					var a := int(indices[index])
					var b := int(indices[index + 1])
					var c := int(indices[index + 2])
					if a < vertices.size() and b < vertices.size() and c < vertices.size():
						faces.push_back(mesh_to_preview * vertices[a])
						faces.push_back(mesh_to_preview * vertices[b])
						faces.push_back(mesh_to_preview * vertices[c])

	if faces.size() < 3:
		push_warning("No office triangle geometry was available for collision.")
		return

	var collision_body := StaticBody3D.new()
	collision_body.name = "AtlasOfficeCollision"
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "AtlasOfficeCollisionShape"
	var concave_shape := ConcavePolygonShape3D.new()
	concave_shape.backface_collision = true
	concave_shape.set_faces(faces)
	collision_shape.shape = concave_shape
	collision_body.add_child(collision_shape)
	add_child(collision_body)


func _find_spawn_transform() -> Dictionary:
	var preferred_position := Vector3(0.0, 0.035, office_bounds.size.z * 0.28)
	var preferred_forward := Vector3(0.0, 0.0, -1.0)
	var has_entrance := false

	for candidate in office_instance.find_children("*", "Node3D", true, false):
		var node_3d := candidate as Node3D
		if node_3d == null:
			continue
		var node_name := str(node_3d.name).to_lower()
		if not node_name.contains("entrance") or not node_name.contains("door"):
			continue
		var entrance_position := to_local(node_3d.global_position)
		var inward := Vector3(-entrance_position.x, 0.0, -entrance_position.z)
		if inward.length_squared() <= 0.1:
			continue
		preferred_forward = inward.normalized()
		preferred_position = entrance_position + preferred_forward * 1.35
		has_entrance = true
		break

	var candidate_points: Array[Vector2] = [
		Vector2(preferred_position.x, preferred_position.z),
		Vector2.ZERO
	]
	var margin := minf(0.45, minf(office_bounds.size.x * 0.15, office_bounds.size.z * 0.15))
	var min_x := office_bounds.position.x + margin
	var max_x := office_bounds.position.x + office_bounds.size.x - margin
	var min_z := office_bounds.position.z + margin
	var max_z := office_bounds.position.z + office_bounds.size.z - margin
	for x_index in range(7):
		for z_index in range(7):
			var point := Vector2(
				lerpf(min_x, max_x, float(x_index) / 6.0),
				lerpf(min_z, max_z, float(z_index) / 6.0)
			)
			if not candidate_points.has(point):
				candidate_points.append(point)

	var space_state := get_world_3d().direct_space_state
	for point in candidate_points:
		var floor_hit := _query_walkable_floor(space_state, point)
		if floor_hit.is_empty():
			continue
		var floor_position: Vector3 = floor_hit["position"]
		if not _has_player_clearance(space_state, point, floor_position.y):
			continue
		walkable_floor_found = true
		return {
			"position": Vector3(point.x, floor_position.y + 0.05, point.y),
			"forward": preferred_forward
		}

	# Some exported rooms have incomplete floor triangles. Keep the player
	# inside the room bounds instead of letting the character fall forever.
	_build_fallback_floor_collision()
	fallback_floor_created = true
	var safe_margin_x := minf(0.5, office_bounds.size.x * 0.25)
	var safe_margin_z := minf(0.5, office_bounds.size.z * 0.25)
	var safe_x := clampf(
		preferred_position.x,
		office_bounds.position.x + safe_margin_x,
		office_bounds.position.x + office_bounds.size.x - safe_margin_x
	)
	var safe_z := clampf(
		preferred_position.z,
		office_bounds.position.z + safe_margin_z,
		office_bounds.position.z + office_bounds.size.z - safe_margin_z
	)
	return {
		"position": Vector3(safe_x, 0.05, safe_z),
		"forward": preferred_forward if has_entrance else Vector3(0.0, 0.0, -1.0)
	}


func _query_walkable_floor(space_state: PhysicsDirectSpaceState3D, point: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, 0.55, point.y),
		Vector3(point.x, -0.25, point.y)
	)
	query.collision_mask = 1
	query.hit_back_faces = true
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var hit_position: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]
	if absf(hit_normal.y) < 0.65 or hit_position.y < -0.15 or hit_position.y > 0.22:
		return {}
	return hit


func _has_player_clearance(space_state: PhysicsDirectSpaceState3D, point: Vector2, floor_height: float) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS * 0.9
	capsule.height = PLAYER_CAPSULE_HEIGHT * 0.92
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(
		Basis(),
		Vector3(point.x, floor_height + 0.12 + capsule.height * 0.5, point.y)
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 0.02
	return space_state.intersect_shape(query, 8).is_empty()


func _build_fallback_floor_collision() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "AtlasOfficeFallbackFloor"
	var floor_shape_node := CollisionShape3D.new()
	floor_shape_node.name = "AtlasOfficeFallbackFloorShape"
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(
		maxf(office_bounds.size.x, 2.0),
		0.2,
		maxf(office_bounds.size.z, 2.0)
	)
	floor_shape_node.shape = floor_shape
	floor_shape_node.position = Vector3(0.0, -0.1, 0.0)
	floor_body.add_child(floor_shape_node)
	add_child(floor_body)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "AtlasOfficeEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111416")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#D8D3C9")
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "OfficeSoftKeyLight"
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color("#F4EBDD")
	key_light.light_energy = 0.82
	key_light.shadow_enabled = false
	add_child(key_light)

	var ceiling_fill := OmniLight3D.new()
	ceiling_fill.name = "OfficeCeilingFill"
	ceiling_fill.position = Vector3(0.0, 2.85, 0.0)
	ceiling_fill.light_color = Color("#FFF2DF")
	ceiling_fill.light_energy = 1.25
	ceiling_fill.omni_range = 9.0
	ceiling_fill.shadow_enabled = false
	add_child(ceiling_fill)


func _build_first_person_player() -> void:
	player = CharacterBody3D.new()
	player.name = "FirstPersonPlayer"
	var spawn: Dictionary = _find_spawn_transform()
	var spawn_position: Vector3 = spawn.get("position", Vector3(0.0, 0.035, 1.0))
	var spawn_forward: Vector3 = spawn.get("forward", Vector3(0.0, 0.0, -1.0))
	player.position = spawn_position
	player.rotation.y = atan2(-spawn_forward.x, -spawn_forward.z)
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
	player_camera.name = "OfficeFirstPersonCamera"
	player_camera.position = Vector3(0.0, CAMERA_EYE_HEIGHT, 0.0)
	player_camera.fov = 78.0
	player_camera.near = 0.05
	player_camera.far = maxf(office_bounds.size.length(), 40.0)
	player.add_child(player_camera)
	player_camera.current = true


func _build_touch_controls() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "AtlasOfficeTouchUI"
	ui_layer.layer = 20
	add_child(ui_layer)

	ui_root = Control.new()
	ui_root.name = "AtlasOfficeTouchRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)

	var back_button := Button.new()
	back_button.name = "OfficeBackButton"
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
	if _is_move_zone(touch_position) and move_touch_index == -1:
		touch_roles[index] = "move"
		move_touch_index = index
		_set_move_joystick(touch_position)
	elif touch_position.x >= get_viewport().get_visible_rect().size.x * 0.5:
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


func _request_back() -> void:
	back_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_instance_valid(ui_root):
		_layout_touch_controls()
