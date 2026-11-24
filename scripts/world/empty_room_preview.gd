extends Node3D

signal back_requested

const EmptyRoomAsset: PackedScene = preload("res://assets/3d/empty_room.gltf")

const WALK_SPEED := 2.65
const LOOK_SENSITIVITY := 0.0036
const CAMERA_EYE_HEIGHT := 1.60
const PLAYER_CAPSULE_RADIUS := 0.28
const PLAYER_CAPSULE_HEIGHT := 1.72
const JOYSTICK_RADIUS := 62.0
const JOYSTICK_DEADZONE := 0.12
const JOYSTICK_BASE_SIZE := Vector2(144.0, 144.0)
const JOYSTICK_THUMB_SIZE := Vector2(50.0, 50.0)
const LOOK_PAD_SIZE := Vector2(118.0, 118.0)

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


func _ready() -> void:
	_build_room()
	_build_room_collisions()
	_build_environment()
	_build_first_person_player()
	_build_touch_controls()
	set_process_input(true)


func _build_room() -> void:
	var room := EmptyRoomAsset.instantiate()
	room.name = "EmptyRoomAsset"
	add_child(room)


func _build_room_collisions() -> void:
	# The imported GLTF is visual geometry. These simple colliders make the
	# floor, four walls and ceiling solid without adding visible objects.
	_add_room_collision_box("RoomFloorCollision", Vector3(0.0, -0.10, 0.0), Vector3(6.32, 0.20, 5.32))
	_add_room_collision_box("LeftWallCollision", Vector3(-3.08, 1.50, 0.0), Vector3(0.16, 3.0, 5.16))
	_add_room_collision_box("RightWallCollision", Vector3(3.08, 1.50, 0.0), Vector3(0.16, 3.0, 5.16))
	_add_room_collision_box("BackWallCollision", Vector3(0.0, 1.50, -2.58), Vector3(6.16, 3.0, 0.16))
	_add_room_collision_box("FrontWallCollision", Vector3(0.0, 1.50, 2.58), Vector3(6.16, 3.0, 0.16))
	_add_room_collision_box("CeilingCollision", Vector3(0.0, 3.08, 0.0), Vector3(6.16, 0.16, 5.16))


func _add_room_collision_box(node_name: String, center: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


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

	var mode_label := Label.new()
	mode_label.name = "FirstPersonModeLabel"
	mode_label.text = "FIRST-PERSON WALK"
	mode_label.position = Vector2(0.0, 24.0)
	mode_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.add_theme_color_override("font_color", Color(0.91, 0.88, 0.82, 0.68))
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(mode_label)

	move_pad_base = _make_round_panel("MovementJoystickBase", JOYSTICK_BASE_SIZE, Color(0.08, 0.10, 0.12, 0.48), Color(0.83, 0.78, 0.69, 0.48))
	ui_root.add_child(move_pad_base)
	move_pad_thumb = _make_round_panel("MovementJoystickThumb", JOYSTICK_THUMB_SIZE, Color(0.78, 0.72, 0.62, 0.82), Color(0.96, 0.91, 0.82, 0.78))
	ui_root.add_child(move_pad_thumb)

	look_pad_base = _make_round_panel("LookPad", LOOK_PAD_SIZE, Color(0.08, 0.10, 0.12, 0.30), Color(0.83, 0.78, 0.69, 0.38))
	ui_root.add_child(look_pad_base)
	var look_label := Label.new()
	look_label.name = "LookHintLabel"
	look_label.text = "LOOK"
	look_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	look_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	look_label.add_theme_font_size_override("font_size", 14)
	look_label.add_theme_color_override("font_color", Color(0.94, 0.91, 0.85, 0.84))
	look_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	look_pad_base.add_child(look_label)

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
	var screen_size := get_viewport_rect().size
	move_pad_center = Vector2(maxf(78.0, screen_size.x * 0.17), screen_size.y - 112.0)
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


func _begin_touch(index: int, position: Vector2) -> void:
	var screen_size := get_viewport_rect().size
	if _is_move_zone(position) and move_touch_index == -1:
		touch_roles[index] = "move"
		move_touch_index = index
		_set_move_joystick(position)
	elif position.x >= screen_size.x * 0.5:
		touch_roles[index] = "look"


func _end_touch(index: int) -> void:
	if not touch_roles.has(index):
		return
	var role: String = touch_roles[index]
	touch_roles.erase(index)
	if role == "move":
		move_touch_index = -1
		_reset_move_joystick()


func _is_move_zone(position: Vector2) -> bool:
	var screen_size := get_viewport_rect().size
	return position.x < screen_size.x * 0.5 and position.y > screen_size.y * 0.52


func _set_move_joystick(position: Vector2) -> void:
	var offset := position - move_pad_center
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
