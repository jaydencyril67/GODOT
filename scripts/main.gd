extends Node3D

# First-person mobile exploration for the DigitalWorld HQ.
var player: CharacterBody3D
var view_camera: Camera3D
var look_touch_id := -1
var move_touch_id := -1
var look_last := Vector2.ZERO
var move_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var touch_look_sensitivity := 0.00125
var look_pending_delta := Vector2.ZERO
var joystick_home_position := Vector2.ZERO
var joystick_is_floating := false
var joystick_base: Panel
var joystick_knob: Panel
var interact_button: Button
var current_interaction := ""
var is_sitting := false
var saved_stand_position := Vector3.ZERO
var saved_camera_height := 0.53
var elevator_left: MeshInstance3D
var elevator_right: MeshInstance3D
var elevator_left_collision: StaticBody3D
var elevator_right_collision: StaticBody3D
var elevator_open := false
var elevator_left_closed := Vector3(3.30, 1.20, 8.34)
var elevator_right_closed := Vector3(4.20, 1.20, 8.34)

# Lightweight procedural HQ. All geometry is generated in code.
const CONCRETE := Color(0.76, 0.78, 0.78)
const FLOOR := Color(0.52, 0.54, 0.54)
const GLASS := Color(0.48, 0.68, 0.76, 0.20)
const DARK := Color(0.08, 0.13, 0.17)
const WOOD := Color(0.34, 0.19, 0.10)
const GREEN := Color(0.12, 0.34, 0.20)

func _ready() -> void:
	build_world()
	create_player()
	create_mobile_hint()

func _physics_process(delta: float) -> void:
	if player == null:
		return

	apply_smoothed_look(delta)
	update_nearby_interaction()
	if is_sitting:
		player.velocity = Vector3.ZERO
		return

	# Use one input source at a time. Mixing a keyboard vector with a stale
	# touch-stick vector can produce unwanted diagonal or reversing movement.
	var input_dir := move_vector if move_touch_id != -1 else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_dir = input_dir.limit_length(1.0)

	var direction := player.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()

	var target_velocity := direction * 2.8
	var smoothing := 1.0 - exp(-delta * (16.0 if input_dir.length() > 0.05 else 22.0))
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z).lerp(Vector2(target_velocity.x, target_velocity.z), smoothing)
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.y

	# Preserve vertical physics. Resetting Y velocity every frame can fight
	# floor snapping and collision resolution, making the view jitter.
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	elif player.velocity.y < 0.0:
		player.velocity.y = 0.0

	# Stop at the walkable bounds by cancelling outward velocity, not by
	# teleporting the body after collision resolution (which caused shaking).
	var next_x := player.position.x + player.velocity.x * delta
	var next_z := player.position.z + player.velocity.z * delta
	if (next_x < -5.55 and player.velocity.x < 0.0) or (next_x > 5.55 and player.velocity.x > 0.0):
		player.velocity.x = 0.0
	if (next_z < -3.55 and player.velocity.z < 0.0) or (next_z > 7.75 and player.velocity.z > 0.0):
		player.velocity.z = 0.0

	player.floor_snap_length = 0.28
	player.move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var screen_size := get_viewport().get_visible_rect().size
			if event.position.x < screen_size.x * 0.45 and move_touch_id == -1:
				move_touch_id = event.index
				var home_rect := Rect2(joystick_home_position, joystick_base.size)
				if home_rect.has_point(event.position):
					# Fixed stick: finger position is measured from the visible base.
					joystick_is_floating = false
					move_origin = joystick_center()
					move_vector = ((event.position - move_origin) / 58.0).limit_length(1.0)
				else:
					# Floating stick: anchor it under the initial touch so a finger
					# landing elsewhere on the left side does not cause a sudden turn.
					joystick_is_floating = true
					var max_x := maxf(0.0, screen_size.x * 0.45 - joystick_base.size.x)
					var max_y := maxf(0.0, screen_size.y - joystick_base.size.y)
					joystick_base.position = Vector2(
						clampf(event.position.x - joystick_base.size.x * 0.5, 0.0, max_x),
						clampf(event.position.y - joystick_base.size.y * 0.5, 0.0, max_y)
					)
					move_origin = joystick_center()
					move_vector = Vector2.ZERO
				update_joystick_knob(event.position)
			elif look_touch_id == -1:
				look_touch_id = event.index
				look_last = event.position
		else:
			if event.index == move_touch_id:
				move_touch_id = -1
				move_vector = Vector2.ZERO
				if joystick_is_floating:
					joystick_base.position = joystick_home_position
					joystick_is_floating = false
				reset_joystick_knob()
			if event.index == look_touch_id:
				look_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch_id:
			var offset: Vector2 = event.position - move_origin
			move_vector = (offset / 58.0).limit_length(1.0)
			update_joystick_knob(event.position)
		elif event.index == look_touch_id:
			rotate_view(event.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		rotate_view(event.relative)

func rotate_view(delta: Vector2) -> void:
	if player == null or view_camera == null:
		return
	# Queue mouse/touch deltas and apply them gradually in physics frames.
	look_pending_delta += delta * touch_look_sensitivity

func apply_smoothed_look(delta: float) -> void:
	if player == null or view_camera == null or look_pending_delta.length_squared() < 0.0000001:
		return
	var blend := 1.0 - exp(-delta * 24.0)
	var applied := look_pending_delta * blend
	look_pending_delta -= applied
	player.rotation.y -= applied.x
	view_camera.rotation.x = clampf(
		view_camera.rotation.x - applied.y,
		deg_to_rad(-75.0),
		deg_to_rad(75.0)
	)

func create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "FirstPersonPlayer"
	player.position = Vector3(0.0, 0.98, 3.15)
	add_child(player)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "BodyCollision"
	collision.shape = capsule
	player.add_child(collision)

	view_camera = Camera3D.new()
	view_camera.name = "FirstPersonCamera"
	view_camera.position = Vector3(0.0, 0.53, 0.0)
	view_camera.fov = 82.0
	player.add_child(view_camera)
	view_camera.current = true

func create_mobile_hint() -> void:
	var hud := CanvasLayer.new()
	hud.name = "MobileControls"
	add_child(hud)

	# Fixed translucent joystick base and thumb pad, GTA-style.
	joystick_base = Panel.new()
	joystick_base.name = "MovementJoystickBase"
	joystick_base.position = Vector2(28.0, get_viewport().get_visible_rect().size.y - 300.0)
	joystick_base.size = Vector2(264.0, 264.0)
	joystick_home_position = joystick_base.position
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.04, 0.09, 0.13, 0.42)
	base_style.corner_radius_top_left = 132
	base_style.corner_radius_top_right = 132
	base_style.corner_radius_bottom_left = 132
	base_style.corner_radius_bottom_right = 132
	base_style.border_width_left = 2
	base_style.border_width_top = 2
	base_style.border_width_right = 2
	base_style.border_width_bottom = 2
	base_style.border_color = Color(0.75, 0.91, 1.0, 0.65)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	hud.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "MovementJoystickKnob"
	joystick_knob.size = Vector2(108.0, 108.0)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.72, 0.88, 0.96, 0.78)
	knob_style.corner_radius_top_left = 54
	knob_style.corner_radius_top_right = 54
	knob_style.corner_radius_bottom_left = 54
	knob_style.corner_radius_bottom_right = 54
	knob_style.border_width_left = 2
	knob_style.border_width_top = 2
	knob_style.border_width_right = 2
	knob_style.border_width_bottom = 2
	knob_style.border_color = Color(1.0, 1.0, 1.0, 0.85)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	hud.add_child(joystick_knob)
	reset_joystick_knob()

	var hint := Label.new()
	hint.text = "MOVE"
	hint.position = Vector2(110.0, get_viewport().get_visible_rect().size.y - 28.0)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	hud.add_child(hint)

	interact_button = Button.new()
	interact_button.name = "ContextInteractionButton"
	interact_button.text = "USE"
	interact_button.position = Vector2(get_viewport().get_visible_rect().size.x - 132.0, get_viewport().get_visible_rect().size.y - 164.0)
	interact_button.size = Vector2(104.0, 104.0)
	interact_button.add_theme_font_size_override("font_size", 17)
	interact_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.04, 0.12, 0.17, 0.48)
	button_style.corner_radius_top_left = 52
	button_style.corner_radius_top_right = 52
	button_style.corner_radius_bottom_left = 52
	button_style.corner_radius_bottom_right = 52
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.75, 0.91, 1.0, 0.72)
	interact_button.add_theme_stylebox_override("normal", button_style)
	interact_button.add_theme_stylebox_override("hover", button_style)
	interact_button.add_theme_stylebox_override("pressed", button_style)
	interact_button.visible = false
	interact_button.pressed.connect(perform_context_interaction)
	hud.add_child(interact_button)

func joystick_center() -> Vector2:
	return joystick_base.position + joystick_base.size * 0.5 if joystick_base != null else Vector2(94.0, 0.0)

func update_joystick_knob(touch_position: Vector2) -> void:
	if joystick_base == null or joystick_knob == null:
		return
	var center := joystick_center()
	var offset := (touch_position - center).limit_length(88.0)
	joystick_knob.position = center + offset - joystick_knob.size * 0.5

func reset_joystick_knob() -> void:
	if joystick_base == null or joystick_knob == null:
		return
	joystick_knob.position = joystick_center() - joystick_knob.size * 0.5

func update_nearby_interaction() -> void:
	if interact_button == null or player == null:
		return
	if is_sitting:
		current_interaction = "stand"
		interact_button.text = "STAND"
		interact_button.visible = true
		return

	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var elevator_xz := Vector2(3.75, 7.25)
	if player_xz.distance_to(elevator_xz) < 2.1:
		current_interaction = "elevator"
		interact_button.text = "CLOSE" if elevator_open else "OPEN"
		interact_button.visible = true
		return

	var seats := [
		{"label": "SIT", "position": Vector3(-4.15, 0.60, 5.45)},
		{"label": "SIT", "position": Vector3(-4.95, 0.48, 7.45)},
		{"label": "SIT", "position": Vector3(-3.45, 0.48, 7.45)},
		{"label": "SIT", "position": Vector3(-0.25, 0.35, 7.35)},
		{"label": "SIT", "position": Vector3(1.15, 0.55, -1.55)},
		{"label": "SIT", "position": Vector3(2.45, 0.55, -1.55)},
		{"label": "SIT", "position": Vector3(3.75, 0.55, -1.55)}
	]
	var nearest_seat: Vector3 = Vector3.ZERO
	var nearest_distance := 1.55
	for seat in seats:
		var seat_pos: Vector3 = seat["position"]
		var distance := player_xz.distance_to(Vector2(seat_pos.x, seat_pos.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_seat = seat_pos
	if nearest_distance < 1.55:
		current_interaction = "sit"
		interact_button.text = "SIT"
		interact_button.visible = true
	else:
		current_interaction = ""
		interact_button.visible = false

func perform_context_interaction() -> void:
	match current_interaction:
		"elevator":
			toggle_elevator()
		"sit":
			begin_sitting()
		"stand":
			stand_up()

func begin_sitting() -> void:
	if player == null or view_camera == null:
		return
	var seats := [
		Vector3(-4.15, 0.60, 5.45),
		Vector3(-4.95, 0.48, 7.45),
		Vector3(-3.45, 0.48, 7.45),
		Vector3(-0.25, 0.35, 7.35),
		Vector3(1.15, 0.55, -1.55),
		Vector3(2.45, 0.55, -1.55),
		Vector3(3.75, 0.55, -1.55)
	]
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var chosen: Vector3 = seats[0]
	var best_distance := INF
	for seat_pos in seats:
		var distance := player_xz.distance_to(Vector2(seat_pos.x, seat_pos.z))
		if distance < best_distance:
			best_distance = distance
			chosen = seat_pos
	if best_distance > 1.55:
		return
	saved_stand_position = player.global_position
	saved_camera_height = view_camera.position.y
	player.global_position = Vector3(chosen.x, 0.98, chosen.z + 0.45)
	player.rotation.y = 0.0
	view_camera.position.y = 0.12
	is_sitting = true

func stand_up() -> void:
	if player == null or view_camera == null:
		return
	player.global_position = saved_stand_position
	view_camera.position.y = saved_camera_height
	is_sitting = false

func toggle_elevator() -> void:
	if player == null:
		return
	var elevator_center := Vector3(3.75, 0.0, 7.25)
	if Vector2(player.global_position.x - elevator_center.x, player.global_position.z - elevator_center.z).length() > 2.5:
		return
	elevator_open = not elevator_open
	var slide := 0.82 if elevator_open else 0.0
	var tween := create_tween().set_parallel(true)
	if elevator_left != null:
		tween.tween_property(elevator_left, "position", elevator_left_closed + Vector3(-slide, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if elevator_right != null:
		tween.tween_property(elevator_right, "position", elevator_right_closed + Vector3(slide, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if elevator_left_collision != null:
		tween.tween_property(elevator_left_collision, "position", elevator_left_closed + Vector3(-slide, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if elevator_right_collision != null:
		tween.tween_property(elevator_right_collision, "position", elevator_right_closed + Vector3(slide, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

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

func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

	if solid:
		add_box_collision(parent, label + "Collision", size, pos)

	return mesh_instance

func add_box_collision(parent: Node3D, label: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func ellipsoid(parent: Node3D, label: String, pos: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale
	instance.material_override = material
	parent.add_child(instance)
	return instance

func cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 2
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

func rod_between(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var direction := b - a
	var rod := cylinder(parent, label, radius, direction.length(), (a + b) * 0.5, material)
	if direction.length_squared() > 0.0001:
		rod.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return rod

func make_office_chair(label: String, seat_pos: Vector3, back_direction: float = 1.0, upholstery_color: Color = Color(0.10, 0.14, 0.17)) -> void:
	var upholstery := mat(upholstery_color, 0.0, 0.78)
	var edge := mat(Color(0.055, 0.075, 0.09), 0.18, 0.42)
	var steel := mat(Color(0.56, 0.61, 0.64), 0.78, 0.24)
	var rubber := mat(Color(0.035, 0.045, 0.05), 0.02, 0.72)

	# Upholstered seat and gently rounded high back replace sharp cube shapes.
	ellipsoid(self, label + "PaddedSeat", seat_pos, Vector3(0.72, 0.22, 0.66), upholstery)
	ellipsoid(self, label + "SeatSeam", seat_pos + Vector3(0.0, 0.082, 0.0), Vector3(0.64, 0.055, 0.57), upholstery)
	ellipsoid(self, label + "Backrest", seat_pos + Vector3(0.0, 0.34, back_direction * 0.27), Vector3(0.68, 0.72, 0.17), upholstery)
	ellipsoid(self, label + "BackInset", seat_pos + Vector3(0.0, 0.35, back_direction * 0.365), Vector3(0.53, 0.53, 0.035), upholstery)
	cylinder(self, label + "GasLift", 0.065, 0.34, seat_pos + Vector3(0.0, -0.245, 0.0), steel)
	cylinder(self, label + "BaseHub", 0.11, 0.075, Vector3(seat_pos.x, 0.105, seat_pos.z), steel)

	# Five-star swivel base and caster wheels.
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		var wheel_pos := Vector3(seat_pos.x + cos(angle) * 0.29, 0.075, seat_pos.z + sin(angle) * 0.29)
		rod_between(self, label + "BaseSpoke", Vector3(seat_pos.x, 0.12, seat_pos.z), Vector3(wheel_pos.x, 0.09, wheel_pos.z), 0.025, steel)
		ellipsoid(self, label + "CasterWheel", wheel_pos, Vector3(0.095, 0.075, 0.075), rubber)

	# Arm supports and padded arm caps.
	for side in [-1.0, 1.0]:
		cylinder(self, label + "ArmSupport", 0.025, 0.20, seat_pos + Vector3(side * 0.29, -0.015, 0.0), steel)
		ellipsoid(self, label + "ArmPad", seat_pos + Vector3(side * 0.29, 0.105, 0.0), Vector3(0.12, 0.045, 0.20), edge)

	add_box_collision(self, label + "SeatCollision", Vector3(0.66, 0.20, 0.58), seat_pos)
	add_box_collision(self, label + "BackCollision", Vector3(0.62, 0.62, 0.16), seat_pos + Vector3(0.0, 0.31, back_direction * 0.28))

func make_plant(label: String, ground_pos: Vector3, size_scale: float = 1.0) -> void:
	var pot := mat(Color(0.30, 0.22, 0.16), 0.02, 0.58)
	var rim := mat(Color(0.42, 0.31, 0.22), 0.05, 0.42)
	var trunk := mat(Color(0.24, 0.16, 0.10), 0.0, 0.92)
	var greens := [
		mat(Color(0.10, 0.29, 0.16), 0.0, 0.88),
		mat(Color(0.16, 0.38, 0.20), 0.0, 0.82),
		mat(Color(0.22, 0.43, 0.23), 0.0, 0.86)
	]
	cylinder(self, label + "TaperedPot", 0.23 * size_scale, 0.34 * size_scale, ground_pos + Vector3(0.0, 0.17 * size_scale, 0.0), pot)
	cylinder(self, label + "PotRim", 0.245 * size_scale, 0.045 * size_scale, ground_pos + Vector3(0.0, 0.335 * size_scale, 0.0), rim)
	cylinder(self, label + "Stem", 0.035 * size_scale, 0.72 * size_scale, ground_pos + Vector3(0.0, 0.72 * size_scale, 0.0), trunk)
	for i in range(9):
		var angle := TAU * float(i) / 9.0
		var ring := 0.18 if i % 2 == 0 else 0.12
		var leaf_pos := ground_pos + Vector3(cos(angle) * ring * size_scale, (0.72 + 0.12 * sin(float(i) * 1.7)) * size_scale, sin(angle) * ring * size_scale)
		ellipsoid(self, label + "Leaf", leaf_pos, Vector3(0.22, 0.30, 0.20) * size_scale, greens[i % greens.size()])
	ellipsoid(self, label + "TopLeaves", ground_pos + Vector3(0.0, 1.02 * size_scale, 0.0), Vector3(0.25, 0.27, 0.23) * size_scale, greens[1])
	add_box_collision(self, label + "PotCollision", Vector3(0.42, 0.34, 0.42) * size_scale, ground_pos + Vector3(0.0, 0.17 * size_scale, 0.0))

func make_office_table(label: String, size: Vector3, top_pos: Vector3, top_material: Material, metal_material: Material) -> void:
	# Rectangular tops are retained, but thin edges, drawers and round metal legs
	# make these read as actual desks instead of unadorned blocks.
	box(self, label + "Top", Vector3(size.x, 0.12, size.z), top_pos, top_material, false)
	box(self, label + "FrontEdge", Vector3(size.x - 0.04, 0.035, 0.035), top_pos + Vector3(0.0, -0.025, size.z * 0.5 - 0.018), metal_material, false)
	box(self, label + "SideEdgeL", Vector3(0.035, 0.035, size.z - 0.04), top_pos + Vector3(-size.x * 0.5 + 0.018, -0.025, 0.0), metal_material, false)
	box(self, label + "SideEdgeR", Vector3(0.035, 0.035, size.z - 0.04), top_pos + Vector3(size.x * 0.5 - 0.018, -0.025, 0.0), metal_material, false)

	var leg_height := maxf(0.30, top_pos.y - 0.15)
	var leg_y := 0.06 + leg_height * 0.5
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			var leg_pos := top_pos + Vector3(side_x * (size.x * 0.5 - 0.10), leg_y - top_pos.y, side_z * (size.z * 0.5 - 0.10))
			cylinder(self, label + "RoundLeg", 0.045, leg_height, leg_pos, metal_material)
	add_box_collision(self, label + "TopCollision", Vector3(size.x, 0.12, size.z), top_pos)

func make_sofa(label: String, center: Vector3, width: float, depth: float, upholstery_color: Color) -> void:
	var upholstery := mat(upholstery_color, 0.0, 0.84)
	var piping := mat(Color(0.10, 0.15, 0.18), 0.0, 0.72)
	# Rounded seat, separate cushions, raised back and soft arms.
	ellipsoid(self, label + "SeatBase", center + Vector3(0.0, 0.28, 0.0), Vector3(width * 0.50, 0.18, depth * 0.50), piping)
	ellipsoid(self, label + "SeatCushion", center + Vector3(0.0, 0.39, -depth * 0.03), Vector3(width * 0.46, 0.15, depth * 0.43), upholstery)
	for i in range(2):
		var x := (float(i) - 0.5) * width * 0.45
		ellipsoid(self, label + "SeatPad", center + Vector3(x, 0.43, -depth * 0.03), Vector3(width * 0.21, 0.13, depth * 0.36), upholstery)
	ellipsoid(self, label + "BackCushion", center + Vector3(0.0, 0.67, depth * 0.35), Vector3(width * 0.48, 0.34, 0.14), upholstery)
	for side in [-1.0, 1.0]:
		ellipsoid(self, label + "Armrest", center + Vector3(side * (width * 0.46), 0.48, 0.0), Vector3(width * 0.09, 0.23, depth * 0.50), upholstery)
	add_box_collision(self, label + "SofaCollision", Vector3(width * 0.94, 0.70, depth * 0.90), center + Vector3(0.0, 0.35, 0.0))

func label3d(text_value: String, pos: Vector3, size: float = 0.32) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = pos
	label.font_size = 48
	label.pixel_size = size / 48.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.08, 0.15, 0.20)
	add_child(label)


func add_photoreal_details() -> void:
	# Soft warm ceiling illumination balances the natural daylight.
	for light_pos in [Vector3(-4.0, 2.95, -1.0), Vector3(0.0, 2.95, -1.0), Vector3(4.0, 2.95, -1.0), Vector3(-4.0, 2.95, 2.0), Vector3(3.5, 2.95, 2.0)]:
		var ceiling_light := OmniLight3D.new()
		ceiling_light.name = "WarmInteriorLighting"
		ceiling_light.position = light_pos
		ceiling_light.light_color = Color(1.0, 0.88, 0.72)
		ceiling_light.light_energy = 0.45
		ceiling_light.omni_range = 5.0
		ceiling_light.shadow_enabled = false
		add_child(ceiling_light)

	# Slim ceiling light housings, brushed metal trim and subtle floor inlays.
	var metal := mat(Color(0.63, 0.68, 0.70), 0.78, 0.24)
	var light_panel := mat(Color(0.96, 0.95, 0.87), 0.0, 0.22)
	var inlay := mat(Color(0.68, 0.72, 0.72), 0.28, 0.32)
	for light_pos in [Vector3(-4.0, 3.02, -1.0), Vector3(0.0, 3.02, -1.0), Vector3(4.0, 3.02, -1.0), Vector3(-4.0, 3.02, 2.0), Vector3(3.5, 3.02, 2.0)]:
		box(self, "CeilingLightTrim", Vector3(1.35, 0.06, 0.42), light_pos, metal, false)
		box(self, "DiffusedLightPanel", Vector3(1.20, 0.025, 0.30), light_pos + Vector3(0.0, -0.035, 0.0), light_panel, false)
	for x in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		box(self, "FloorInlay", Vector3(0.025, 0.008, 7.5), Vector3(x, 0.066, 0.0), inlay, false)

	# Reception workstation details.
	var screen_frame := mat(Color(0.035, 0.055, 0.065), 0.25, 0.22)
	var screen_glow := mat(Color(0.12, 0.45, 0.62), 0.12, 0.18)
	box(self, "ReceptionMonitorFrame", Vector3(0.78, 0.48, 0.055), Vector3(-3.65, 1.28, -0.86), screen_frame, false)
	box(self, "ReceptionMonitorScreen", Vector3(0.70, 0.39, 0.018), Vector3(-3.65, 1.29, -0.895), screen_glow, false)
	box(self, "ReceptionMonitorStand", Vector3(0.10, 0.18, 0.10), Vector3(-3.65, 1.12, -0.84), metal, false)
	box(self, "ReceptionDeskDrawer", Vector3(0.70, 0.20, 0.40), Vector3(-4.20, 0.35, -0.72), mat(Color(0.68, 0.70, 0.69), 0.08, 0.38), false)

	# Fine brushed-metal table trim; chairs now have their own swivel bases.
	box(self, "BoardroomTableMetalEdge", Vector3(3.42, 0.045, 1.50), Vector3(2.45, 0.875, -0.35), metal, false)

	# Thin metallic window mullions make the glass facade read as framed glazing.
	for x in [-4.45, -1.5, 1.5, 4.45]:
		box(self, "WindowSill", Vector3(2.78, 0.045, 0.12), Vector3(x, 0.48, -3.98), metal, false)

func build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.57, 0.63)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.92)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Daylight"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.35
	sun.directional_shadow_max_distance = 22.0
	sun.shadow_bias = 0.055
	sun.shadow_normal_bias = 1.4
	# DirectionalLight3D has no shadow_blur property in Godot 4; avoid a runtime script error.
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

	# Interior glass partitions create separate reception and boardroom areas.
	# Door-sized gaps are intentionally left open so the player can walk between rooms.
	var partition_glass := mat(Color(0.45, 0.62, 0.68, 0.32), 0.12, 0.24)
	var partition_frame := mat(Color(0.43, 0.51, 0.55), 0.65, 0.28)
	box(self, "ReceptionPartitionA", Vector3(0.12, 2.75, 2.2), Vector3(-1.20, 1.39, -1.90), partition_glass)
	box(self, "ReceptionPartitionB", Vector3(0.12, 2.75, 2.0), Vector3(-1.20, 1.39, 2.00), partition_glass)
	box(self, "ReceptionPartitionTopA", Vector3(0.16, 0.10, 2.25), Vector3(-1.20, 2.79, -1.90), partition_frame)
	box(self, "ReceptionPartitionTopB", Vector3(0.16, 0.10, 2.05), Vector3(-1.20, 2.79, 2.00), partition_frame)

	box(self, "BoardroomPartitionA", Vector3(0.12, 2.75, 1.7), Vector3(0.55, 1.39, -1.85), partition_glass)
	box(self, "BoardroomPartitionB", Vector3(0.12, 2.75, 2.0), Vector3(0.55, 1.39, 1.65), partition_glass)
	box(self, "BoardroomPartitionTopA", Vector3(0.16, 0.10, 1.75), Vector3(0.55, 2.79, -1.85), partition_frame)
	box(self, "BoardroomPartitionTopB", Vector3(0.16, 0.10, 2.05), Vector3(0.55, 2.79, 1.65), partition_frame)

	# Reception zone on the left.
	box(self, "ReceptionDeskBase", Vector3(2.35, 0.82, 0.72), Vector3(-3.65, 0.48, -0.75), mat(Color(0.77, 0.79, 0.78), 0.05, 0.32))
	box(self, "ReceptionDeskTop", Vector3(2.5, 0.12, 0.82), Vector3(-3.65, 0.95, -0.75), mat(WOOD, 0.0, 0.28))
	box(self, "DeskFrontAccent", Vector3(1.8, 0.10, 0.04), Vector3(-3.65, 0.52, -0.375), mat(Color(0.18, 0.48, 0.61), 0.2, 0.25))
	make_sofa("WaitingSofa", Vector3(-3.8, 0.0, 1.55), 2.0, 0.72, Color(0.17, 0.25, 0.30))
	make_office_table("CoffeeTable", Vector3(1.25, 0.12, 0.72), Vector3(-3.8, 0.48, 0.25), mat(Color(0.63, 0.67, 0.67), 0.35, 0.25), mat(Color(0.53, 0.60, 0.63), 0.78, 0.24))
	label3d("RECEPTION", Vector3(-4.4, 2.25, -0.8), 0.28)

	# Boardroom zone on the right.
	make_office_table("BoardroomTable", Vector3(3.35, 0.16, 1.45), Vector3(2.45, 0.98, -0.35), mat(WOOD, 0.0, 0.28), mat(Color(0.53, 0.60, 0.63), 0.78, 0.24))
	for x in [1.15, 2.45, 3.75]:
		for z in [-1.55, 0.85]:
			make_office_chair("BoardroomChair", Vector3(x, 0.55, z), 1.0 if z > 0.0 else -1.0, Color(0.12, 0.17, 0.21))
	label3d("BOARDROOM", Vector3(1.5, 2.4, -2.1), 0.28)
	label3d("DIGITALWORLD HQ", Vector3(-1.5, 3.75, -4.15), 0.25)

	# Layered leaves, stems and rounded ceramic planters replace the green cubes.
	make_plant("ReceptionPlantLeft", Vector3(-5.1, 0.0, 2.7), 1.0)
	make_plant("BoardroomPlant", Vector3(5.0, 0.0, -2.0), 0.95)
	make_plant("ReceptionPlantCenter", Vector3(0.0, 0.0, 2.9), 0.9)
	add_photoreal_details()
	build_phase_two()

func build_phase_two() -> void:
	# New forward wing extends the walkable floor beyond the original reception.
	var floor_mat := mat(Color(0.56, 0.58, 0.58), 0.08, 0.26)
	var wall_mat := mat(Color(0.78, 0.80, 0.80), 0.05, 0.48)
	var trim_mat := mat(Color(0.50, 0.57, 0.60), 0.72, 0.24)
	var office_glass := mat(Color(0.48, 0.68, 0.76, 0.22), 0.12, 0.20)
	var exec_wood := mat(Color(0.30, 0.17, 0.10), 0.05, 0.28)
	var carpet := mat(Color(0.20, 0.25, 0.28), 0.0, 0.92)

	box(self, "ExpansionFoundation", Vector3(12.8, 0.32, 4.8), Vector3(0, -0.18, 6.25), mat(Color(0.18, 0.22, 0.25)))
	box(self, "ExpansionFloor", Vector3(12.2, 0.08, 4.8), Vector3(0, 0.02, 6.25), floor_mat)
	box(self, "ExpansionSideLeft", Vector3(0.28, 3.2, 4.6), Vector3(-6.05, 1.58, 6.15), wall_mat)
	box(self, "ExpansionSideRight", Vector3(0.28, 3.2, 4.6), Vector3(6.05, 1.58, 6.15), wall_mat)

	# Rear wall has broad openings so each room remains reachable through its own doorway.
	for x in [-4.45, -0.45]:
		box(self, "ExpansionRearWall", Vector3(2.9, 3.0, 0.24), Vector3(x, 1.50, 8.48), wall_mat)
	# Keep a real opening behind the elevator doors so they can slide apart.
	for x in [2.05, 5.40]:
		box(self, "ElevatorRearWallSide", Vector3(1.10, 3.0, 0.24), Vector3(x, 1.50, 8.48), wall_mat)
	for x in [-2.8, 1.8]:
		box(self, "ExpansionRearPier", Vector3(0.24, 3.0, 0.24), Vector3(x, 1.50, 8.48), trim_mat)

	# Glass dividers separate two executive suites from the elevator lobby.
	# Their front ends stop short of the corridor, leaving clear entrances.
	for x in [-2.35, 1.75]:
		box(self, "ExecutiveGlassDivider", Vector3(0.10, 2.75, 3.0), Vector3(x, 1.39, 6.55), office_glass)
		box(self, "ExecutiveDividerTopRail", Vector3(0.14, 0.10, 3.0), Vector3(x, 2.82, 6.55), trim_mat)
		box(self, "ExecutiveDividerFloorRail", Vector3(0.14, 0.06, 3.0), Vector3(x, 0.10, 6.55), trim_mat)

	# Executive office one: desk, executive chair, guest seats and monitor.
	box(self, "ExecutiveOneCarpet", Vector3(3.55, 0.018, 2.85), Vector3(-4.20, 0.075, 6.55), carpet, false)
	make_office_table("ExecutiveOneDesk", Vector3(1.85, 0.14, 0.88), Vector3(-4.15, 0.92, 6.45), exec_wood, trim_mat)
	box(self, "ExecutiveOneMonitor", Vector3(0.68, 0.42, 0.06), Vector3(-4.15, 1.22, 6.18), mat(Color(0.08, 0.16, 0.19), 0.1, 0.2), false)
	make_office_chair("ExecutiveOneChair", Vector3(-4.15, 0.60, 5.45), 1.0, Color(0.08, 0.12, 0.15))
	for x in [-4.95, -3.45]:
		make_office_chair("ExecutiveGuestChair", Vector3(x, 0.48, 7.45), 1.0, Color(0.19, 0.24, 0.27))
	box(self, "ExecutiveOneCredenza", Vector3(2.30, 0.70, 0.38), Vector3(-4.25, 0.42, 7.95), exec_wood)
	label3d("EXECUTIVE OFFICE", Vector3(-4.95, 2.35, 5.35), 0.22)

	# Executive office two: a second desk and lounge seating.
	box(self, "ExecutiveTwoCarpet", Vector3(3.45, 0.018, 2.85), Vector3(-0.25, 0.075, 6.55), carpet, false)
	make_office_table("ExecutiveTwoDesk", Vector3(1.75, 0.14, 0.82), Vector3(-0.25, 0.92, 6.45), exec_wood, trim_mat)
	box(self, "ExecutiveTwoMonitor", Vector3(0.68, 0.42, 0.06), Vector3(-0.25, 1.22, 6.18), mat(Color(0.08, 0.16, 0.19), 0.1, 0.2), false)
	make_sofa("ExecutiveTwoLoungeSofa", Vector3(-0.25, 0.0, 7.35), 1.45, 0.62, Color(0.17, 0.25, 0.30))
	label3d("EXECUTIVE SUITE", Vector3(-1.15, 2.35, 5.35), 0.22)

	# Elevator lobby: paired stainless doors, header and a visible call panel.
	box(self, "ElevatorCarpet", Vector3(3.75, 0.018, 2.85), Vector3(3.80, 0.075, 6.55), carpet, false)
	box(self, "ElevatorFrameLeft", Vector3(0.12, 2.55, 0.18), Vector3(2.85, 1.28, 8.28), trim_mat)
	box(self, "ElevatorFrameRight", Vector3(0.12, 2.55, 0.18), Vector3(4.65, 1.28, 8.28), trim_mat)
	box(self, "ElevatorHeader", Vector3(1.92, 0.14, 0.18), Vector3(3.75, 2.55, 8.28), trim_mat)
	elevator_left = box(self, "ElevatorDoorLeft", Vector3(0.86, 2.32, 0.08), elevator_left_closed, mat(Color(0.68, 0.72, 0.74), 0.78, 0.22))
	elevator_right = box(self, "ElevatorDoorRight", Vector3(0.86, 2.32, 0.08), elevator_right_closed, mat(Color(0.68, 0.72, 0.74), 0.78, 0.22))
	elevator_left_collision = get_node_or_null("ElevatorDoorLeftCollision") as StaticBody3D
	elevator_right_collision = get_node_or_null("ElevatorDoorRightCollision") as StaticBody3D
	box(self, "ElevatorCallPanel", Vector3(0.18, 0.42, 0.05), Vector3(4.92, 1.48, 8.18), mat(Color(0.08, 0.13, 0.16), 0.25, 0.22), false)
	box(self, "ElevatorFloorDisplay", Vector3(0.08, 0.10, 0.02), Vector3(4.92, 1.62, 8.14), mat(Color(0.18, 0.80, 0.66), 0.1, 0.2), false)
	label3d("ELEVATORS", Vector3(3.05, 2.90, 8.18), 0.20)

	# Soft light in the new wing.
	for light_pos in [Vector3(-4.0, 2.90, 5.8), Vector3(0.0, 2.90, 5.8), Vector3(4.0, 2.90, 5.8)]:
		var wing_light := OmniLight3D.new()
		wing_light.name = "ExpansionWarmLight"
		wing_light.position = light_pos
		wing_light.light_color = Color(1.0, 0.88, 0.74)
		wing_light.light_energy = 0.55
		wing_light.omni_range = 4.5
		add_child(wing_light)
