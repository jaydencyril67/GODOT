extends Node3D

signal back_requested

const EmptyRoomAsset: PackedScene = preload("res://assets/3d/empty_room.gltf")
const CAMERA_START_DISTANCE := 2.18
const CAMERA_MIN_DISTANCE := 1.55
const CAMERA_MAX_DISTANCE := 2.28
const DRAG_SENSITIVITY := 0.0042
const PINCH_SENSITIVITY := 0.0032

var orbit_pivot: Node3D
var preview_camera: Camera3D
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var mouse_dragging := false


func _ready() -> void:
	_build_room()
	_build_environment()
	_build_preview_camera()
	_build_back_button()
	set_process_input(true)


func _build_room() -> void:
	var room := EmptyRoomAsset.instantiate()
	room.name = "EmptyRoomAsset"
	add_child(room)


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

	# Soft interior fill; the lights are hidden, leaving only the empty room shell visible.
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


func _build_preview_camera() -> void:
	orbit_pivot = Node3D.new()
	orbit_pivot.name = "RoomOrbitPivot"
	orbit_pivot.position = Vector3(0.0, 1.5, 0.0)
	add_child(orbit_pivot)

	preview_camera = Camera3D.new()
	preview_camera.name = "EmptyRoomCamera"
	preview_camera.position = Vector3(0.0, 0.42, CAMERA_START_DISTANCE)
	preview_camera.rotation.x = -atan2(0.42, CAMERA_START_DISTANCE)
	preview_camera.fov = 78.0
	preview_camera.near = 0.05
	preview_camera.far = 30.0
	orbit_pivot.add_child(preview_camera)
	preview_camera.current = true


func _build_back_button() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "EmptyRoomPreviewUI"
	ui_layer.layer = 20
	add_child(ui_layer)

	var ui_root := Control.new()
	ui_root.name = "EmptyRoomPreviewUIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


func _request_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(preview_camera.position.z - 0.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(preview_camera.position.z + 0.12)
	elif event is InputEventMouseMotion and mouse_dragging:
		_rotate_room(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			last_pinch_distance = _get_pinch_distance()
		else:
			touch_points.erase(event.index)
			last_pinch_distance = _get_pinch_distance()
	elif event is InputEventScreenDrag:
		if touch_points.has(event.index):
			touch_points[event.index] = event.position
			if touch_points.size() >= 2:
				var next_distance := _get_pinch_distance()
				if last_pinch_distance > 0.0 and next_distance > 0.0:
					_set_zoom(preview_camera.position.z + (last_pinch_distance - next_distance) * PINCH_SENSITIVITY)
				last_pinch_distance = next_distance
			else:
				_rotate_room(event.relative)
	elif event is InputEventMagnifyGesture:
		_set_zoom(preview_camera.position.z / maxf(float(event.factor), 0.1))


func _get_pinch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
	var touch_ids := touch_points.keys()
	var first_point: Vector2 = touch_points[touch_ids[0]]
	var second_point: Vector2 = touch_points[touch_ids[1]]
	return first_point.distance_to(second_point)


func _rotate_room(relative: Vector2) -> void:
	orbit_pivot.rotation.y -= relative.x * DRAG_SENSITIVITY
	orbit_pivot.rotation.x = clampf(orbit_pivot.rotation.x - relative.y * DRAG_SENSITIVITY, -0.22, 0.22)


func _set_zoom(distance: float) -> void:
	preview_camera.position.z = clampf(distance, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
