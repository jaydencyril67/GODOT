extends Node3D

# The OS worksite uses the same physical handset proportions as the Phone
# Creation Worksite. Its boot UI is supplied as a viewport texture; this node
# owns only the handset model and its studio preview.

const HANDSET_SIZE := Vector3(1.45, 2.92, 0.13)
const OUTER_CORNER_RADIUS := 0.34
# Keep a constant 0.020 inset on every straight edge and rounded corner.
const BEZEL_WIDTH := 0.020
const BEZEL_HEIGHT := BEZEL_WIDTH
const SCREEN_WIDTH := HANDSET_SIZE.x - BEZEL_WIDTH * 2.0
const SCREEN_HEIGHT := HANDSET_SIZE.y - BEZEL_HEIGHT * 2.0
const SCREEN_CORNER_RADIUS := OUTER_CORNER_RADIUS - BEZEL_WIDTH
const DISPLAY_INSET_MARGIN := 0.002
const BODY_COLOR := Color("#A5ADB6")
const POWER_KEY_CENTER_Y := 0.55
const VOLUME_KEY_VERTICAL_OFFSET := 0.12

var chassis: MeshInstance3D
var screen_surface: MeshInstance3D
var preview_camera: Camera3D


func build(screen_texture: Texture2D) -> void:
	for child in get_children():
		child.free()

	_build_environment()
	_build_lighting()
	_build_camera()
	_build_chassis()
	_build_display(screen_texture)
	_build_front_hardware()
	_build_side_controls()
	_build_bottom_hardware()

func build_for_loading(screen_texture: Texture2D, progress_callback: Callable) -> void:
	for child in get_children():
		child.free()

	await _run_loading_build_stage("Building handset studio environment", progress_callback, Callable(self, "_build_environment"))
	await _run_loading_build_stage("Setting up handset studio lighting", progress_callback, Callable(self, "_build_lighting"))
	await _run_loading_build_stage("Preparing handset preview camera", progress_callback, Callable(self, "_build_camera"))
	await _run_loading_build_stage("Constructing handset chassis", progress_callback, Callable(self, "_build_chassis"))
	await _run_loading_build_stage("Building handset glass display", progress_callback, Callable(self, "_build_display").bind(screen_texture))
	await _run_loading_build_stage("Building handset front hardware", progress_callback, Callable(self, "_build_front_hardware"))
	await _run_loading_build_stage("Building handset side controls", progress_callback, Callable(self, "_build_side_controls"))
	await _run_loading_build_stage("Building handset bottom hardware", progress_callback, Callable(self, "_build_bottom_hardware"))


func _run_loading_build_stage(message: String, progress_callback: Callable, build_action: Callable) -> void:
	if progress_callback.is_valid():
		progress_callback.call(message, 0.0)
	await get_tree().process_frame
	build_action.call()
	if progress_callback.is_valid():
		progress_callback.call(message, 100.0)
	await get_tree().create_timer(0.18).timeout



func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "PhonePreviewEnvironment"

	var environment := Environment.new()
	var studio_sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#35383A")
	sky_material.sky_horizon_color = Color("#D5CFC3")
	sky_material.ground_horizon_color = Color("#77736C")
	sky_material.ground_bottom_color = Color("#17191B")
	sky_material.sky_energy_multiplier = 0.85
	sky_material.ground_energy_multiplier = 0.65
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.08
	studio_sky.sky_material = sky_material
	studio_sky.radiance_size = Sky.RADIANCE_SIZE_128

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.sky = studio_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment_node.environment = environment
	add_child(environment_node)


func _build_lighting() -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "PhoneStudioKeyLight"
	key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key_light.light_color = Color("#EEE9DF")
	key_light.light_energy = 0.82
	key_light.shadow_enabled = false
	add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "PhoneStudioRimLight"
	rim_light.rotation_degrees = Vector3(18.0, 142.0, -8.0)
	rim_light.light_color = Color("#C7BBA6")
	rim_light.light_energy = 0.28
	rim_light.shadow_enabled = false
	add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "PhoneStudioFillLight"
	fill_light.position = Vector3(-2.2, 1.4, 2.8)
	fill_light.light_color = Color("#C7BBA6")
	fill_light.light_energy = 0.16
	fill_light.omni_range = 8.0
	add_child(fill_light)


func _build_camera() -> void:
	preview_camera = Camera3D.new()
	preview_camera.name = "PhonePreviewCamera"
	preview_camera.position = Vector3(0.0, 0.0, 4.6)
	preview_camera.fov = 38.0
	preview_camera.near = 0.05
	preview_camera.far = 100.0
	# A camera's default forward axis is -Z, so the fixed straight-on
	# preview needs no look_at call or scene-tree-dependent transform update.
	preview_camera.basis = Basis.IDENTITY
	add_child(preview_camera)
	preview_camera.current = true


func _build_chassis() -> void:
	chassis = MeshInstance3D.new()
	chassis.name = "PhoneChassis"
	chassis.mesh = _build_rounded_extrusion(
		HANDSET_SIZE.x,
		HANDSET_SIZE.y,
		HANDSET_SIZE.z,
		OUTER_CORNER_RADIUS,
		48
	)

	var material := StandardMaterial3D.new()
	material.albedo_color = BODY_COLOR
	material.metallic = 0.78
	material.roughness = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	chassis.material_override = material
	chassis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chassis)


func _build_display(screen_texture: Texture2D) -> void:
	var front_z := HANDSET_SIZE.z * 0.5

	# A dark, slightly wider inset creates a continuous visible frame around
	# the active glass instead of placing the texture over the whole chassis.
	var inset := MeshInstance3D.new()
	inset.name = "DisplayInsetFrame"
	inset.mesh = _build_rounded_extrusion(
		SCREEN_WIDTH + DISPLAY_INSET_MARGIN * 2.0,
		SCREEN_HEIGHT + DISPLAY_INSET_MARGIN * 2.0,
		0.004,
		SCREEN_CORNER_RADIUS + DISPLAY_INSET_MARGIN,
		32
	)
	var inset_material := StandardMaterial3D.new()
	inset_material.albedo_color = Color("#28323C")
	inset_material.metallic = 0.48
	inset_material.roughness = 0.30
	inset_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	inset.material_override = inset_material
	inset.position = Vector3(0.0, 0.0, front_z + 0.001)
	inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inset)

	screen_surface = MeshInstance3D.new()
	screen_surface.name = "PhoneScreenSurface"
	screen_surface.mesh = _build_rounded_panel_with_uv(
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		0.006,
		SCREEN_CORNER_RADIUS,
		32
	)

	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	screen_material.albedo_color = Color.WHITE
	screen_material.albedo_texture = screen_texture
	screen_material.roughness = 0.18
	screen_material.metallic = 0.0
	screen_surface.material_override = screen_material
	# This is the same front-face offset used by the working Phone Creation
	# Worksite. The back of the glass sits just above the chassis face.
	screen_surface.position = Vector3(0.0, 0.0, front_z + 0.0035)
	screen_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen_surface)


func _build_front_hardware() -> void:
	# Match Phone Creation Worksite's Under-Display Camera treatment: one
	# restrained optical window beneath the display glass, with no cutout,
	# metallic ring, notch, or earpiece.
	var optical_window := MeshInstance3D.new()
	optical_window.name = "UnderDisplayCameraOpticalWindow"
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.026
	lens_mesh.bottom_radius = 0.026
	lens_mesh.height = 0.0015
	lens_mesh.radial_segments = 40
	optical_window.mesh = lens_mesh
	optical_window.rotation_degrees.x = 90.0
	var front_z := HANDSET_SIZE.z * 0.5
	optical_window.position = Vector3(0.0, SCREEN_HEIGHT * 0.5 - 0.075, front_z + 0.007)
	var optical_material := StandardMaterial3D.new()
	optical_material.albedo_color = Color(0.025, 0.055, 0.085, 0.22)
	optical_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	optical_material.roughness = 0.28
	optical_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	optical_window.material_override = optical_material
	optical_window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(optical_window)


func _build_side_controls() -> void:
	var frame_material := _make_metal_material(BODY_COLOR.darkened(0.24), 0.62, 0.30)
	var key_material := _make_metal_material(BODY_COLOR.lightened(0.08), 0.72, 0.24)

	var controls := Node3D.new()
	controls.name = "SideControls"
	add_child(controls)

	# Power key on the right; the two separate volume keys are on the left.
	# Each key is aligned to the side plane and slightly overlaps it so it
	# looks physically fitted, not like a decal placed on the front glass.
	_add_side_key(controls, "PowerButton", 1.0, POWER_KEY_CENTER_Y, 0.19, frame_material, key_material)
	# Keep the volume pair on the opposite edge, centered as a group directly
	# across from the power key, like a conventional modern phone layout.
	_add_side_key(controls, "VolumeUpButton", -1.0, POWER_KEY_CENTER_Y + VOLUME_KEY_VERTICAL_OFFSET, 0.15, frame_material, key_material)
	_add_side_key(controls, "VolumeDownButton", -1.0, POWER_KEY_CENTER_Y - VOLUME_KEY_VERTICAL_OFFSET, 0.15, frame_material, key_material)


func _add_side_key(
	parent: Node3D,
	node_name: String,
	side_sign: float,
	position_y: float,
	length: float,
	frame_material: Material,
	key_material: Material
) -> void:
	var half_width := HANDSET_SIZE.x * 0.5
	var key_width := 0.036
	var edge_depth := 0.026
	var key_radius := key_width * 0.5

	var recess := MeshInstance3D.new()
	recess.name = node_name + "Recess"
	var recess_mesh := BoxMesh.new()
	recess_mesh.size = Vector3(0.012, length + 0.026, 0.052)
	recess.mesh = recess_mesh
	recess.material_override = frame_material
	recess.position = Vector3(side_sign * (half_width - 0.004), position_y, 0.0)
	recess.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(recess)

	var key := MeshInstance3D.new()
	key.name = node_name
	var key_mesh := CapsuleMesh.new()
	key_mesh.radius = key_radius
	key_mesh.height = maxf(length + key_width, key_width * 2.0)
	key_mesh.radial_segments = 24
	key_mesh.rings = 8
	key.mesh = key_mesh
	key.scale = Vector3(edge_depth / key_width, 1.0, 0.92)
	key.position = Vector3(side_sign * (half_width + edge_depth * 0.20), position_y, 0.0)
	key.material_override = key_material
	key.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(key)


func _build_bottom_hardware() -> void:
	var bottom_y := -HANDSET_SIZE.y * 0.5
	var port_frame := MeshInstance3D.new()
	port_frame.name = "ChargingPortFrame"
	var port_mesh := BoxMesh.new()
	port_mesh.size = Vector3(0.22, 0.018, 0.058)
	port_frame.mesh = port_mesh
	port_frame.position = Vector3(0.0, bottom_y, 0.0)
	port_frame.material_override = _make_metal_material(Color("#252B32"), 0.38, 0.42)
	port_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(port_frame)

	var port_inner := MeshInstance3D.new()
	port_inner.name = "ChargingPortOpening"
	var opening_mesh := BoxMesh.new()
	opening_mesh.size = Vector3(0.15, 0.008, 0.035)
	port_inner.mesh = opening_mesh
	port_inner.position = Vector3(0.0, bottom_y - 0.006, 0.0)
	port_inner.material_override = _make_metal_material(Color("#050607"), 0.0, 1.0)
	port_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(port_inner)

	var speaker_material := StandardMaterial3D.new()
	speaker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	speaker_material.albedo_color = Color("#050607")
	speaker_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		for index in range(4):
			var speaker := MeshInstance3D.new()
			speaker.name = "BottomSpeaker_%s_%02d" % ["L" if side < 0.0 else "R", index + 1]
			var hole := CylinderMesh.new()
			hole.top_radius = 0.011
			hole.bottom_radius = 0.011
			hole.height = 0.010
			hole.radial_segments = 20
			speaker.mesh = hole
			speaker.position = Vector3(side * (0.27 + float(index) * 0.045), bottom_y - 0.001, 0.0)
			speaker.material_override = speaker_material
			speaker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(speaker)


func _make_metal_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_rounded_extrusion(
	width: float,
	height: float,
	depth: float,
	corner_radius: float,
	corner_segments: int
) -> Mesh:
	var outline := _rounded_outline(width, height, corner_radius, corner_segments)
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		var fallback := BoxMesh.new()
		fallback.size = Vector3(width, height, depth)
		return fallback

	var half_depth := depth * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for index in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var c: Vector2 = outline[indices[index + 2]]
		_append_triangle(
			surface,
			Vector3(a.x, a.y, half_depth),
			Vector3(b.x, b.y, half_depth),
			Vector3(c.x, c.y, half_depth),
			Vector3.FORWARD
		)
		_append_triangle(
			surface,
			Vector3(a.x, a.y, -half_depth),
			Vector3(c.x, c.y, -half_depth),
			Vector3(b.x, b.y, -half_depth),
			Vector3.BACK
		)

	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		var a := outline[index]
		var b := outline[next_index]
		var edge := b - a
		var side_normal := Vector3(edge.y, -edge.x, 0.0).normalized()
		var normal_a := side_normal
		var normal_b := side_normal

		if _is_rounded_outline_point(a, width, height, corner_radius):
			var previous_a := outline[(index - 1 + outline.size()) % outline.size()]
			var previous_edge := a - previous_a
			var previous_normal := Vector3(previous_edge.y, -previous_edge.x, 0.0).normalized()
			normal_a = (previous_normal + side_normal).normalized()
		if _is_rounded_outline_point(b, width, height, corner_radius):
			var next_b := outline[(next_index + 1) % outline.size()]
			var next_edge := next_b - b
			var next_normal := Vector3(next_edge.y, -next_edge.x, 0.0).normalized()
			normal_b = (side_normal + next_normal).normalized()

		var front_a := Vector3(a.x, a.y, half_depth)
		var front_b := Vector3(b.x, b.y, half_depth)
		var back_a := Vector3(a.x, a.y, -half_depth)
		var back_b := Vector3(b.x, b.y, -half_depth)
		_append_triangle_with_normals(surface, front_a, back_a, back_b, normal_a, normal_a, normal_b)
		_append_triangle_with_normals(surface, front_a, back_b, front_b, normal_a, normal_b, normal_b)

	return surface.commit()


func _build_rounded_panel_with_uv(
	width: float,
	height: float,
	depth: float,
	corner_radius: float,
	corner_segments: int
) -> ArrayMesh:
	var outline := _rounded_outline(width, height, corner_radius, corner_segments)
	var indices := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_depth := depth * 0.5

	for index in range(0, indices.size(), 3):
		var a: Vector2 = outline[indices[index]]
		var b: Vector2 = outline[indices[index + 1]]
		var c: Vector2 = outline[indices[index + 2]]
		_append_uv_triangle(
			surface,
			Vector3(a.x, a.y, half_depth),
			Vector3(b.x, b.y, half_depth),
			Vector3(c.x, c.y, half_depth),
			Vector3.FORWARD,
			width,
			height
		)
		_append_triangle(
			surface,
			Vector3(a.x, a.y, -half_depth),
			Vector3(c.x, c.y, -half_depth),
			Vector3(b.x, b.y, -half_depth),
			Vector3.BACK
		)

	for index in range(outline.size()):
		var next_index := (index + 1) % outline.size()
		var a := outline[index]
		var b := outline[next_index]
		var edge := b - a
		var side_normal := Vector3(edge.y, -edge.x, 0.0).normalized()
		var half_depth_position := half_depth
		var front_a := Vector3(a.x, a.y, half_depth_position)
		var front_b := Vector3(b.x, b.y, half_depth_position)
		var back_a := Vector3(a.x, a.y, -half_depth_position)
		var back_b := Vector3(b.x, b.y, -half_depth_position)
		_append_triangle_with_normals(surface, front_a, back_a, back_b, side_normal, side_normal, side_normal)
		_append_triangle_with_normals(surface, front_a, back_b, front_b, side_normal, side_normal, side_normal)

	return surface.commit()


func _rounded_outline(
	width: float,
	height: float,
	radius: float,
	corner_segments: int
) -> PackedVector2Array:
	var half_width := width * 0.5
	var half_height := height * 0.5
	var resolved_radius := clampf(radius, 0.001, minf(half_width, half_height))
	var points := PackedVector2Array()
	var corners: Array[Dictionary] = [
		{"center": Vector2(half_width - resolved_radius, half_height - resolved_radius), "start": 0.0},
		{"center": Vector2(-half_width + resolved_radius, half_height - resolved_radius), "start": 90.0},
		{"center": Vector2(-half_width + resolved_radius, -half_height + resolved_radius), "start": 180.0},
		{"center": Vector2(half_width - resolved_radius, -half_height + resolved_radius), "start": 270.0}
	]
	for corner in corners:
		var center: Vector2 = corner["center"]
		var start_angle := float(corner["start"])
		for segment in range(corner_segments + 1):
			var angle := deg_to_rad(start_angle + 90.0 * float(segment) / float(corner_segments))
			points.append(center + Vector2(cos(angle), sin(angle)) * resolved_radius)
	return points


func _is_rounded_outline_point(point: Vector2, width: float, height: float, radius: float) -> bool:
	var half_width := width * 0.5
	var half_height := height * 0.5
	var corner_x := half_width - radius
	var corner_y := half_height - radius
	return absf(point.x) >= corner_x - 0.0001 and absf(point.y) >= corner_y - 0.0001


func _append_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.set_normal(normal)
	surface.add_vertex(b)
	surface.set_normal(normal)
	surface.add_vertex(c)


func _append_triangle_with_normals(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal_a: Vector3,
	normal_b: Vector3,
	normal_c: Vector3
) -> void:
	surface.set_normal(normal_a.normalized())
	surface.add_vertex(a)
	surface.set_normal(normal_b.normalized())
	surface.add_vertex(b)
	surface.set_normal(normal_c.normalized())
	surface.add_vertex(c)


func _append_uv_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	width: float,
	height: float
) -> void:
	for point in [a, b, c]:
		var uv := Vector2(
			point.x / maxf(width, 0.001) + 0.5,
			0.5 - point.y / maxf(height, 0.001)
		)
		surface.set_normal(normal)
		surface.set_uv(uv)
		surface.add_vertex(point)
