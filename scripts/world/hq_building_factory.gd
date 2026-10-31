extends RefCounted
class_name HQBuildingFactory

const BUILDING_NAMES := [
	"Starter Headquarters",
	"Compact Office",
	"Urban Office",
	"Mid-rise Headquarters",
	"Corporate House",
	"Corporate Tower",
	"High-rise Headquarters",
	"Glass Skyscraper",
	"Landmark Tower",
	"Mega Skyscraper"
]
const FLOOR_COUNTS := [1, 2, 3, 5, 7, 9, 12, 15, 19, 23]
const WIDTHS := [11.8, 11.8, 12.2, 12.8, 13.2, 13.8, 14.2, 14.6, 15.2, 15.8]
const DEPTHS := [9.2, 9.4, 9.6, 9.8, 10.1, 10.4, 10.7, 10.9, 11.2, 11.4]
const FLOOR_HEIGHT := 2.65

static func create_building(level: int, company_name: String = "YOUR COMPANY") -> Node3D:
	var tier := clampi(level, 1, 10)
	if tier == 1:
		return _create_starter_building(company_name)
	var root := Node3D.new()
	root.name = "Headquarters_Level_%02d" % tier

	var width: float = WIDTHS[tier - 1]
	var depth: float = DEPTHS[tier - 1]
	var floor_count: int = FLOOR_COUNTS[tier - 1]
	var height := float(floor_count) * FLOOR_HEIGHT
	var body_width := width * (0.86 if tier >= 8 else 1.0)
	var body_depth := depth * (0.86 if tier >= 8 else 1.0)

	var concrete := _material(Color("#c9c5b7") if tier < 4 else Color("#aeb8b6"), 0.88, 0.04)
	var light_concrete := _material(Color("#ded9ca"), 0.82, 0.05)
	var dark_concrete := _material(Color("#515e5a"), 0.70, 0.22)
	var metal := _material(Color("#344441"), 0.34, 0.78)
	var glass := _material(Color("#6c9a9e") if tier < 5 else Color("#477b88"), 0.16, 0.20, 0.72)
	var lit_glass := _material(Color("#b7d2ce"), 0.25, 0.12)
	var foundation := _material(Color("#737a74"), 0.94)

	_box(root, Vector3(width + 1.2, 0.62, depth + 1.2), Vector3(0, 0.31, 0), foundation, "Foundation")
	_box(root, Vector3(width + 0.45, 0.24, depth + 0.45), Vector3(0, 0.72, 0), metal, "Entrance_Platform")

	var podium_height := 2.8 if tier >= 5 else 1.35
	if tier >= 5:
		_box(root, Vector3(width + 1.4, podium_height, depth + 1.1), Vector3(0, 0.84 + podium_height * 0.5, 0), light_concrete, "Corporate_Podium")
		for x_index in range(9):
			var x := -width * 0.5 + float(x_index) * (width / 8.0)
			_box(root, Vector3(0.045, podium_height * 0.7, 0.06), Vector3(x, 0.84 + podium_height * 0.5, depth * 0.5 + 0.57), dark_concrete, "Podium_Fin")

	var start_y := 0.84 + podium_height if tier >= 5 else 0.84
	var body_height := maxf(FLOOR_HEIGHT, height - (podium_height if tier >= 5 else 0.0))
	var body_floors := maxi(1, roundi(body_height / FLOOR_HEIGHT))
	var floor_step := body_height / float(body_floors)
	var bays := 7 if tier >= 8 else (6 if tier >= 5 else 5)

	for floor_index in range(body_floors):
		var y := start_y + float(floor_index) * floor_step + floor_step * 0.5
		_box(root, Vector3(body_width + 0.16, 0.12, body_depth + 0.16), Vector3(0, y - floor_step * 0.5 + 0.08, 0), light_concrete, "Floor_Slab")
		_box(root, Vector3(body_width, floor_step * 0.82, 0.09), Vector3(0, y, body_depth * 0.5 + 0.015), dark_concrete, "Front_Spandrel")
		_box(root, Vector3(body_width, floor_step * 0.82, 0.09), Vector3(0, y, -body_depth * 0.5 - 0.015), dark_concrete, "Rear_Spandrel")
		_box(root, Vector3(0.09, floor_step * 0.82, body_depth), Vector3(body_width * 0.5 + 0.015, y, 0), dark_concrete, "Right_Spandrel")
		_box(root, Vector3(0.09, floor_step * 0.82, body_depth), Vector3(-body_width * 0.5 - 0.015, y, 0), dark_concrete, "Left_Spandrel")

		var pane_height := maxf(0.5, floor_step * 0.58)
		var pane_material: Material = lit_glass if floor_index % 4 == 1 else glass
		_box(root, Vector3(body_width - 0.26, pane_height, 0.055), Vector3(0, y - 0.02, body_depth * 0.5 + 0.075), pane_material, "Front_Glazing")
		_box(root, Vector3(body_width - 0.26, pane_height, 0.055), Vector3(0, y - 0.02, -body_depth * 0.5 - 0.075), pane_material, "Rear_Glazing")
		_box(root, Vector3(0.055, pane_height, body_depth - 0.28), Vector3(body_width * 0.5 + 0.075, y - 0.02, 0), pane_material, "Right_Glazing")
		_box(root, Vector3(0.055, pane_height, body_depth - 0.28), Vector3(-body_width * 0.5 - 0.075, y - 0.02, 0), pane_material, "Left_Glazing")

		for bay in range(bays + 1):
			var x := -body_width * 0.5 + body_width * float(bay) / float(bays)
			_box(root, Vector3(0.055, floor_step * 0.78, 0.11), Vector3(x, y, body_depth * 0.5 + 0.12), metal, "Front_Mullion")
			_box(root, Vector3(0.055, floor_step * 0.78, 0.11), Vector3(x, y, -body_depth * 0.5 - 0.12), metal, "Rear_Mullion")
		for side in [-1.0, 1.0]:
			_box(root, Vector3(0.13, floor_step * 0.9, body_depth + 0.18), Vector3(side * body_width * 0.5, y, 0), light_concrete, "Corner_Pier")

		if tier >= 6 and floor_index % 5 == 0:
			for x in [-body_width * 0.5 + 0.55, body_width * 0.5 - 0.55]:
				_box(root, Vector3(0.18, floor_step * 0.9, body_depth + 0.35), Vector3(x, y, 0), metal, "Tower_Fin")
		if tier >= 4 and tier <= 7 and floor_index % 2 == 0:
			_box(root, Vector3(body_width + 0.35, 0.09, body_depth + 0.32), Vector3(0, y + floor_step * 0.43, 0), light_concrete, "Facade_Band")

	# Ground-level entrance, glazed lobby, canopy and metal supports.
	_box(root, Vector3(minf(4.2, width * 0.34), 2.25, 0.18), Vector3(0, 1.9, depth * 0.5 + 0.16), metal, "Lobby_Frame")
	_box(root, Vector3(minf(3.6, width * 0.29), 1.95, 0.045), Vector3(0, 1.88, depth * 0.5 + 0.27), glass, "Lobby_Glass")
	_box(root, Vector3(minf(5.8, width * 0.52), 0.22, 1.7), Vector3(0, 3.12, depth * 0.5 + 0.78), dark_concrete, "Entrance_Canopy")
	for x in [-2.5, 2.5]:
		_box(root, Vector3(0.18, 2.85, 0.18), Vector3(x, 1.52, depth * 0.5 + 0.55), metal, "Canopy_Support")

	# Ten distinct roof treatments preserve the upgrade progression.
	if tier == 1:
		_box(root, Vector3(width + 0.4, 0.22, depth + 0.4), Vector3(0, height + 0.72, 0), dark_concrete, "Starter_Roof_Edge")
		var roof_left := _box(root, Vector3(width * 0.55, 0.42, depth + 0.2), Vector3(-width * 0.22, height + 1.0, 0), light_concrete, "Pitched_Roof_Left")
		roof_left.rotation.z = 0.2
		var roof_right := _box(root, Vector3(width * 0.55, 0.42, depth + 0.2), Vector3(width * 0.22, height + 1.0, 0), light_concrete, "Pitched_Roof_Right")
		roof_right.rotation.z = -0.2
	elif tier <= 3:
		_box(root, Vector3(body_width + 0.7, 0.38, body_depth + 0.7), Vector3(0, height + 0.5, 0), light_concrete, "Roof_Cap")
		for x in [-body_width * 0.32, body_width * 0.32]:
			_box(root, Vector3(0.75, 0.5, 0.75), Vector3(x, height + 0.92, -1.2), dark_concrete, "Roof_Plant")
	elif tier <= 6:
		_box(root, Vector3(body_width + 0.5, 0.45, body_depth + 0.5), Vector3(0, height + 0.42, 0), metal, "Mechanical_Roof")
		_box(root, Vector3(body_width * 0.42, 1.5, body_depth * 0.5), Vector3(0, height + 1.2, -body_depth * 0.08), light_concrete, "Roof_Penthouse")
		for index in range(10):
			var x := -body_width * 0.35 + float(index) * (body_width * 0.7 / 9.0)
			_box(root, Vector3(0.055, 1.15, 0.07), Vector3(x, height + 1.1, body_depth * 0.5), metal, "Roof_Fin")
	else:
		var crown_height := 7.5 if tier == 10 else (5.2 if tier == 9 else 3.4)
		var crown_width := body_width * 0.5 if tier == 10 else (body_width * 0.65 if tier == 9 else body_width * 0.78)
		_box(root, Vector3(body_width + 0.55, 0.48, body_depth + 0.55), Vector3(0, height + 0.4, 0), metal, "Crown_Base")
		_box(root, Vector3(crown_width, crown_height, body_depth * 0.72), Vector3(0, height + crown_height * 0.5 + 0.6, -body_depth * 0.06), glass, "Glass_Crown")
		for side in [-1.0, 1.0]:
			_box(root, Vector3(0.18, height + crown_height, 0.2), Vector3(side * body_width * 0.47, (height + crown_height) * 0.5 + 0.4, 0), metal, "Crown_Column")
		if tier >= 9:
			var spire := MeshInstance3D.new()
			var spire_mesh := CylinderMesh.new()
			spire_mesh.top_radius = 0.08
			spire_mesh.bottom_radius = 0.42
			spire_mesh.height = 10.0 if tier == 10 else 6.0
			spire.mesh = spire_mesh
			spire.position = Vector3(0, height + crown_height + (5.0 if tier == 10 else 3.0), 0)
			spire.material_override = metal
			root.add_child(spire)

	# Discreet facade details and a plaque carrying the founder's company name.
	for index in range(8):
		var x := -width * 0.5 + float(index) * (width / 7.0)
		_box(root, Vector3(0.055, 0.32, 0.07), Vector3(x, 0.95, depth * 0.5 + 0.18), metal, "Lobby_Mullion")
	var plaque := MeshInstance3D.new()
	var plaque_mesh := BoxMesh.new()
	plaque_mesh.size = Vector3(4.4, 0.76, 0.12)
	plaque.mesh = plaque_mesh
	plaque.position = Vector3(0, 3.05, depth * 0.5 + 0.34)
	plaque.material_override = dark_concrete
	root.add_child(plaque)
	var sign := Label3D.new()
	sign.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	sign.text = company_name.to_upper().substr(0, 24) if not company_name.is_empty() else "YOUR COMPANY"
	sign.font_size = 44
	sign.pixel_size = 0.008
	sign.modulate = Color("#f0f3e8")
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.position = Vector3(0, 3.05, depth * 0.5 + 0.42)
	sign.rotation.y = PI
	root.add_child(sign)
	return root

static func _create_starter_building(company_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Starter_Headquarters"
	var stone := _material(Color("#96988e"), 0.96)
	var wall := _material(Color("#d2cbb8"), 0.90)
	var side_wall := _material(Color("#8d9990"), 0.94)
	var roof := _material(Color("#405653"), 0.82, 0.04)
	var trim := _material(Color("#b8b5a5"), 0.86)
	var dark_metal := _material(Color("#283433"), 0.42, 0.62)
	var brushed_metal := _material(Color("#8c9893"), 0.32, 0.78)
	var glass := _material(Color("#36535a"), 0.13, 0.28, 0.90)
	var window_glass := _material(Color("#83b8bd"), 0.22, 0.25)
	window_glass.emission_enabled = true
	window_glass.emission = Color("#1e4344")
	window_glass.emission_energy_multiplier = 0.24
	var warm_light := _material(Color("#fff0c8"), 0.35)
	warm_light.emission_enabled = true
	warm_light.emission = Color("#ffd78a")
	warm_light.emission_energy_multiplier = 1.35
	_apply_pbr(wall, "concrete", Vector2(2.8, 1.6), 0.24)
	_apply_pbr(side_wall, "concrete", Vector2(2.2, 1.6), 0.22)
	_apply_pbr(stone, "stone", Vector2(3.2, 2.4), 0.28)
	_apply_pbr(roof, "roof", Vector2(3.2, 2.4), 0.28)
	_apply_pbr(trim, "stone", Vector2(1.1, 2.0), 0.22)

	# Original DigitalWorld starter headquarters: a seven-metre concrete envelope with a split metal roof.
	_box(root, Vector3(15, 0.75, 11), Vector3(0, 0.2, 0), stone, "Stone_Foundation")
	_box(root, Vector3(13, 7, 0.45), Vector3(0, 4, 4.8), wall, "Front_Concrete_Elevation")
	_box(root, Vector3(0.45, 7, 9.2), Vector3(-6.3, 4, 0), wall, "Left_Concrete_Elevation")
	_box(root, Vector3(0.45, 7, 9.2), Vector3(6.3, 4, 0), side_wall, "Right_Concrete_Elevation")
	_box(root, Vector3(13, 7, 0.45), Vector3(0, 4, -4.8), side_wall, "Rear_Concrete_Elevation")

	var roof_left := _box(root, Vector3(7.7, 0.55, 12), Vector3(-2.2, 8, 0), roof, "Split_Roof_Left")
	roof_left.rotation.z = 0.45
	var roof_right := _box(root, Vector3(7.7, 0.55, 12), Vector3(2.2, 8, 0), roof, "Split_Roof_Right")
	roof_right.rotation.z = -0.45
	var roof_seam := _material(Color("#293f3b"), 0.76, 0.12)
	for roof_piece in [roof_left, roof_right]:
		for seam_index in range(11):
			var rib := _box(roof_piece, Vector3(0.075, 0.1, 11.8), Vector3(float(seam_index - 5) * 0.62, 0.32, 0), roof_seam, "Raised_Roof_Seam")

	# Corner piers, plinth, entry step, eaves and rainwater details.
	for x in [-6.18, 6.18]:
		_box(root, Vector3(0.62, 7.05, 0.62), Vector3(x, 4, 5.02), trim, "Front_Corner_Pier")
	_box(root, Vector3(13.8, 0.42, 0.7), Vector3(0, 0.83, 5.05), stone, "Front_Plith")
	_box(root, Vector3(3.3, 0.24, 1.2), Vector3(0, 0.76, 5.75), trim, "Entry_Step")
	_box(root, Vector3(13.9, 0.16, 0.72), Vector3(0, 7.42, 4.92), trim, "Front_Eaves")
	_box(root, Vector3(0.34, 0.34, 12.15), Vector3(0, 9.02, 0), dark_metal, "Roof_Ridge_Cap")
	for x in [-4.4, 4.4]:
		_box(root, Vector3(1.05, 0.18, 0.9), Vector3(x, 7.02, -2.5), dark_metal, "Roof_Vent_Base")
		_box(root, Vector3(0.78, 0.48, 0.62), Vector3(x, 7.28, -2.5), dark_metal, "Roof_Vent")

	# Facade joints and layered window assemblies.
	for y in [1.15, 2.5, 3.85, 5.2, 6.55]:
		_box(root, Vector3(12.82, 0.035, 0.055), Vector3(0, y, 5.035), dark_metal, "Horizontal_Facade_Joint")
	for x in [-5.45, -3.2, -1.1, 1.1, 3.2, 5.45]:
		_box(root, Vector3(0.045, 5.65, 0.05), Vector3(x, 4.05, 5.04), dark_metal, "Vertical_Facade_Reveal")
	var door_frame := _box(root, Vector3(1.85, 3.5, 0.2), Vector3(0, 2.05, 5.16), trim, "Main_Entrance_Frame")
	_box(root, Vector3(1.5, 3.2, 0.12), Vector3(0, 2.1, 5.12), _material(Color("#604a35"), 0.86), "Main_Entrance_Door")
	_box(root, Vector3(1.22, 2.78, 0.045), Vector3(0, 2.13, 5.205), glass, "Main_Entrance_Glazing")
	for x in [-0.69, 0.69]:
		_box(root, Vector3(0.055, 2.95, 0.07), Vector3(x, 2.12, 5.25), brushed_metal, "Door_Side_Rail")
	_box(root, Vector3(1.43, 0.06, 0.07), Vector3(0, 3.61, 5.25), brushed_metal, "Door_Top_Rail")
	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.045
	handle_mesh.bottom_radius = 0.045
	handle_mesh.height = 0.62
	handle.mesh = handle_mesh
	handle.position = Vector3(0.43, 2.22, 5.31)
	handle.material_override = brushed_metal
	root.add_child(handle)

	for x in [-4.3, 0.0, 4.3]:
		_box(root, Vector3(1.9, 2.2, 0.18), Vector3(x, 4.8, 5.08), trim, "Front_Window_Frame")
		_box(root, Vector3(1.55, 1.82, 0.1), Vector3(x, 4.82, 5.19), window_glass, "Front_Window_Glass")
		_box(root, Vector3(0.07, 1.8, 0.07), Vector3(x, 4.82, 5.26), trim, "Window_Mullion")
		_box(root, Vector3(1.82, 0.12, 0.28), Vector3(x, 3.68, 5.22), trim, "Window_Sill")
		_box(root, Vector3(2.02, 0.12, 0.25), Vector3(x, 5.98, 5.19), trim, "Window_Lintel")

	# Recessed entrance canopy with metal fascia, soffit and warm downlights.
	_box(root, Vector3(5.2, 0.22, 2.05), Vector3(0, 4.05, 6.05), dark_metal, "Entrance_Canopy")
	_box(root, Vector3(4.92, 0.08, 1.78), Vector3(0, 3.91, 6.05), trim, "Canopy_Soffit")
	for x in [-1.65, 0.0, 1.65]:
		var lamp := MeshInstance3D.new()
		var lamp_mesh := CylinderMesh.new()
		lamp_mesh.top_radius = 0.105
		lamp_mesh.bottom_radius = 0.105
		lamp_mesh.height = 0.035
		lamp.mesh = lamp_mesh
		lamp.rotation.x = PI * 0.5
		lamp.position = Vector3(x, 3.86, 6.55)
		lamp.material_override = warm_light
		root.add_child(lamp)

	for side in [-1.0, 1.0]:
		for z in [-2.8, 0.0, 2.8]:
			_box(root, Vector3(0.065, 1.55, 1.72), Vector3(side * 6.54, 4.55, z), glass, "Side_Window_Glass")
			_box(root, Vector3(0.12, 1.78, 1.95), Vector3(side * 6.56, 4.55, z), dark_metal, "Side_Window_Frame")
			_box(root, Vector3(0.075, 1.53, 1.7), Vector3(side * 6.635, 4.55, z), glass, "Side_Window_Inset")
			_box(root, Vector3(0.22, 0.1, 2.02), Vector3(side * 6.65, 3.62, z), brushed_metal, "Side_Window_Sill")

	# Eaves drainage, downpipes and service panels.
	for x in [-6.55, 6.55]:
		var pipe := MeshInstance3D.new()
		var pipe_mesh := CylinderMesh.new()
		pipe_mesh.top_radius = 0.075
		pipe_mesh.bottom_radius = 0.075
		pipe_mesh.height = 6.2
		pipe.mesh = pipe_mesh
		pipe.position = Vector3(x, 4.05, 4.92)
		pipe.material_override = dark_metal
		root.add_child(pipe)
	for x in [-5.4, 5.4]:
		_box(root, Vector3(0.32, 0.58, 0.22), Vector3(x, 5.85, 5.12), dark_metal, "Wall_Light_Fixture")
		_box(root, Vector3(0.2, 0.36, 0.035), Vector3(x, 5.85, 5.245), warm_light, "Wall_Light_Diffuser")
	for x in [-4.9, 4.9]:
		_box(root, Vector3(0.62, 0.82, 0.09), Vector3(x, 2.1, 5.13), dark_metal, "Service_Panel")
		_box(root, Vector3(0.44, 0.08, 0.025), Vector3(x, 2.3, 5.19), brushed_metal, "Service_Panel_Label")

	# Company name fascia on the main entrance.
	_box(root, Vector3(5.3, 0.85, 0.18), Vector3(0, 7.0, 5.12), dark_metal, "Company_Sign_Plaque")
	var company_sign := Label3D.new()
	company_sign.font = load("res://assets/fonts/STIXTwoText[wght].ttf")
	company_sign.text = company_name.to_upper().substr(0, 24) if not company_name.is_empty() else "YOUR COMPANY"
	company_sign.font_size = 40
	company_sign.pixel_size = 0.008
	company_sign.modulate = Color("#eaf0dc")
	company_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	company_sign.position = Vector3(0, 7.0, 5.23)
	company_sign.rotation.y = PI
	root.add_child(company_sign)
	return root

static func _apply_pbr(material: StandardMaterial3D, family: String, repeat_uv: Vector2, normal_strength: float) -> void:
	var prefix := "res://assets/textures/%s-" % family
	var color_texture := load(prefix + "color.svg") as Texture2D
	var normal_texture := load(prefix + "normal.svg") as Texture2D
	var roughness_texture := load(prefix + "roughness.svg") as Texture2D
	if color_texture != null:
		material.albedo_texture = color_texture
		material.uv1_scale = Vector3(repeat_uv.x, repeat_uv.y, 1.0)
	if normal_texture != null:
		material.normal_enabled = true
		material.normal_texture = normal_texture
		material.normal_scale = normal_strength
	if roughness_texture != null:
		material.roughness_texture = roughness_texture
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

static func create_preview_building(level: int) -> Node3D:
	var tier := clampi(level, 1, 10)
	var root := Node3D.new()
	root.name = "Upgrade_Preview_%02d" % tier
	var width: float = WIDTHS[tier - 1]
	var depth: float = DEPTHS[tier - 1]
	var floors: int = FLOOR_COUNTS[tier - 1]
	var height := float(floors) * FLOOR_HEIGHT
	var body_width := width * (0.86 if tier >= 8 else 1.0)
	var body_depth := depth * (0.86 if tier >= 8 else 1.0)
	var concrete := _material(Color("#c9c5b7") if tier < 4 else Color("#aeb8b6"), 0.88, 0.04)
	var light := _material(Color("#ded9ca"), 0.82, 0.05)
	var dark := _material(Color("#515e5a"), 0.70, 0.22)
	var metal := _material(Color("#344441"), 0.34, 0.78)
	var glass := _material(Color("#477b88"), 0.16, 0.20, 0.72)
	_box(root, Vector3(width + 1.0, 0.55, depth + 1.0), Vector3(0, 0.27, 0), concrete, "Showroom_Foundation")
	var podium := 2.8 if tier >= 5 else 1.2
	if tier >= 5:
		_box(root, Vector3(width + 1.2, podium, depth + 1.0), Vector3(0, 0.55 + podium * 0.5, 0), light, "Showroom_Podium")
	_box(root, Vector3(body_width, height, body_depth), Vector3(0, 0.55 + height * 0.5, 0), dark, "Tower_Core")
	var floor_count := mini(floors, 23)
	for floor_index in range(floor_count + 1):
		var y := 0.55 + float(floor_index) * FLOOR_HEIGHT
		_box(root, Vector3(body_width + 0.14, 0.11, body_depth + 0.14), Vector3(0, y, 0), light, "Floor_Band")
	for floor_index in range(floor_count):
		var y := 0.55 + (float(floor_index) + 0.5) * FLOOR_HEIGHT
		_box(root, Vector3(body_width - 0.35, FLOOR_HEIGHT * 0.54, 0.06), Vector3(0, y, body_depth * 0.5 + 0.04), glass, "Front_Window_Band")
		_box(root, Vector3(body_width - 0.35, FLOOR_HEIGHT * 0.54, 0.06), Vector3(0, y, -body_depth * 0.5 - 0.04), glass, "Rear_Window_Band")
	if tier <= 3:
		_box(root, Vector3(body_width + 0.6, 0.32, body_depth + 0.6), Vector3(0, height + 0.72, 0), light, "Low_Roof_Cap")
	elif tier <= 6:
		_box(root, Vector3(body_width + 0.55, 0.42, body_depth + 0.55), Vector3(0, height + 0.74, 0), metal, "Mechanical_Crown")
		_box(root, Vector3(body_width * 0.42, 1.2, body_depth * 0.5), Vector3(0, height + 1.55, 0), light, "Roof_Penthouse")
	else:
		var crown_height := 7.5 if tier == 10 else (5.2 if tier == 9 else 3.4)
		var crown_width := body_width * (0.5 if tier == 10 else (0.65 if tier == 9 else 0.78))
		_box(root, Vector3(body_width + 0.5, 0.42, body_depth + 0.5), Vector3(0, height + 0.75, 0), metal, "Crown_Base")
		_box(root, Vector3(crown_width, crown_height, body_depth * 0.72), Vector3(0, height + crown_height * 0.5 + 0.95, 0), glass, "Glass_Crown")
		if tier >= 9:
			var spire := MeshInstance3D.new()
			var spire_mesh := CylinderMesh.new()
			spire_mesh.top_radius = 0.08
			spire_mesh.bottom_radius = 0.42
			spire_mesh.height = 10.0 if tier == 10 else 6.0
			spire.mesh = spire_mesh
			spire.position = Vector3(0, height + crown_height + (6.0 if tier == 10 else 4.0), 0)
			spire.material_override = metal
			root.add_child(spire)
	return root

static func _material(color: Color, roughness: float, metallic: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = roughness
	material.metallic = metallic
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

static func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material, node_name: String = "Building_Part") -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mesh_instance)
	return mesh_instance
