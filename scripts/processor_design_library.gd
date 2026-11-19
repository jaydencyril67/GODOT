extends RefCounted

# Fifteen physical smartphone-SoC package designs. Each entry describes a real
# packaging approach or die arrangement rather than a cosmetic colour preset.
const DESIGNS := [
	{
		"id": "dw_silicon_01",
		"name": "DW SILICON 01",
		"description": "Monolithic mobile SoC: one exposed logic die on a laminated organic substrate with perimeter passives and a 15 × 15 BGA contact field.",
		"layout": "reference",
		"board_size": 2.30,
		"grid": 15,
		"contacts": "BGA",
		"package_size": "12 × 12 mm",
		"package_finish": "Matte graphite",
		"die_finish": "Dark silicon"
	},
	{
		"id": "dw_core_02",
		"name": "DW CORE 02",
		"description": "Compact monolithic package with a smaller central silicon die and tightly spaced board-level passives.",
		"layout": "compact_logic",
		"board_size": 2.08,
		"grid": 13,
		"contacts": "BGA",
		"package_size": "10 × 10 mm",
		"package_finish": "Ceramic black",
		"die_finish": "Dark silicon"
	},
	{
		"id": "dw_nova_03",
		"name": "DW NOVA 03",
		"description": "Main application die paired with a dedicated power-management companion die on the same substrate.",
		"layout": "logic_companion",
		"board_size": 2.30,
		"grid": 15,
		"contacts": "BGA",
		"package_size": "12 × 12 mm",
		"package_finish": "Deep green substrate",
		"die_finish": "Polished silicon"
	},
	{
		"id": "dw_atlas_04",
		"name": "DW ATLAS 04",
		"description": "Dual-compute package with separate CPU and graphics silicon tiles arranged side by side.",
		"layout": "dual_compute",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Matte graphite",
		"die_finish": "Dark silicon"
	},
	{
		"id": "dw_helix_05",
		"name": "DW HELIX 05",
		"description": "Three-chiplet arrangement with distinct compute, graphics and I/O dies placed around a shared package routing area.",
		"layout": "triple_chiplet",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Deep green substrate",
		"die_finish": "Polished silicon"
	},
	{
		"id": "dw_matrix_06",
		"name": "DW MATRIX 06",
		"description": "Two-tier logic stack using vertically bonded silicon dies to increase integration without expanding the package footprint.",
		"layout": "stacked_logic",
		"board_size": 2.30,
		"grid": 15,
		"contacts": "BGA",
		"package_size": "12 × 12 mm",
		"package_finish": "Ceramic black",
		"die_finish": "Metallic silicon cap"
	},
	{
		"id": "dw_quantum_07",
		"name": "DW QUANTUM 07",
		"description": "Package-on-package design with the application processor below and a separate stacked-memory package above it.",
		"layout": "pop_memory",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Matte graphite",
		"die_finish": "Dark silicon"
	},
	{
		"id": "dw_fusion_08",
		"name": "DW FUSION 08",
		"description": "Four-die compute package with independent silicon tiles arranged symmetrically around a central routing region.",
		"layout": "quad_chiplet",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Deep green substrate",
		"die_finish": "Polished silicon"
	},
	{
		"id": "dw_vertex_09",
		"name": "DW VERTEX 09",
		"description": "Sealed processor package with a low-profile nickel-alloy heat spreader covering the silicon die.",
		"layout": "metal_lid",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Ceramic black",
		"die_finish": "Metallic silicon cap"
	},
	{
		"id": "dw_titan_10",
		"name": "DW TITAN 10",
		"description": "Exposed-die package reinforced by a raised perimeter stiffener frame to protect the silicon and substrate.",
		"layout": "stiffened_die",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Matte graphite",
		"die_finish": "Polished silicon"
	},
	{
		"id": "dw_prism_11",
		"name": "DW PRISM 11",
		"description": "Elongated substrate carrying two long silicon tiles with separate electrical and thermal zones.",
		"layout": "elongated_dual",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "16 × 16 mm",
		"package_finish": "Deep green substrate",
		"die_finish": "Dark silicon"
	},
	{
		"id": "dw_pulse_12",
		"name": "DW PULSE 12",
		"description": "Fan-out wafer-level style package with a moulded body, exposed central die and visible redistribution routing.",
		"layout": "fanout",
		"board_size": 2.24,
		"grid": 15,
		"contacts": "BGA",
		"package_size": "12 × 12 mm",
		"package_finish": "Ceramic black",
		"die_finish": "Dark silicon"
	},
	{
		"id": "dw_cobalt_13",
		"name": "DW COBALT 13",
		"description": "Land-grid package using flat underside contact pads instead of solder balls, with a single exposed logic die.",
		"layout": "lga",
		"board_size": 2.30,
		"grid": 13,
		"contacts": "LGA",
		"package_size": "12 × 12 mm",
		"package_finish": "Matte graphite",
		"die_finish": "Polished silicon"
	},
	{
		"id": "dw_apex_14",
		"name": "DW APEX 14",
		"description": "Silicon-interposer assembly with a central I/O tile and four surrounding compute chiplets.",
		"layout": "interposer",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "14 × 14 mm",
		"package_finish": "Deep green substrate",
		"die_finish": "Metallic silicon cap"
	},
	{
		"id": "dw_crown_15",
		"name": "DW CROWN 15",
		"description": "Advanced 3D package combining a central application die with two vertically stacked memory/compute tiles.",
		"layout": "triple_stack",
		"board_size": 2.48,
		"grid": 17,
		"contacts": "BGA",
		"package_size": "16 × 16 mm",
		"package_finish": "Ceramic black",
		"die_finish": "Polished silicon"
	}
]


static func build_all(parent: Node3D) -> Array[Dictionary]:
	var built_models: Array[Dictionary] = []
	for index in range(DESIGNS.size()):
		var profile: Dictionary = DESIGNS[index]
		var model_root := Node3D.new()
		model_root.name = "ProcessorSoCModel" if index == 0 else "ProcessorSoCModel_%02d" % (index + 1)
		model_root.position = Vector3(0.0, 0.02, 0.0)
		model_root.rotation = Vector3(-0.24, -0.42, 0.0)
		parent.add_child(model_root)

		var model_data: Dictionary
		if index == 0:
			model_data = _build_reference_design(model_root)
		else:
			model_data = _build_variant_design(model_root, profile)
		_apply_profile_finishes(model_data, profile)
		model_data["root"] = model_root
		model_data["profile"] = profile.duplicate(true)
		model_root.visible = index == 0
		built_models.append(model_data)
	return built_models



static func _apply_profile_finishes(model_data: Dictionary, profile: Dictionary) -> void:
	var package_colors := {
		"Matte graphite": Color("#222C31"),
		"Deep green substrate": Color("#183B32"),
		"Ceramic black": Color("#15191E")
	}
	var die_colors := {
		"Dark silicon": Color("#171D22"),
		"Polished silicon": Color("#454F57"),
		"Metallic silicon cap": Color("#91999D")
	}
	var package_color: Color = package_colors.get(str(profile.get("package_finish", "Matte graphite")), Color("#222C31"))
	var die_color: Color = die_colors.get(str(profile.get("die_finish", "Dark silicon")), Color("#171D22"))
	for layer_value in model_data.get("package_layers", []):
		var layer := layer_value as MeshInstance3D
		if is_instance_valid(layer):
			var layer_material := _material(package_color, 0.42, 0.34)
			layer_material.albedo_color = package_color.darkened(0.12) if layer.name == "PackageLowerEdge" else package_color
			layer.material_override = layer_material
	for surface_value in model_data.get("die_surfaces", []):
		var surface := surface_value as MeshInstance3D
		if is_instance_valid(surface):
			surface.material_override = _material(die_color, 0.32, 0.25)

static func _build_reference_design(root: Node3D) -> Dictionary:
	# Design 01 preserves the existing processor model and its original detail.
	var package_layers: Array[MeshInstance3D] = []
	var lower_edge := _add_box(root, Vector3(2.30, 0.035, 2.30), Vector3(0.0, -0.075, 0.0), _material(Color("#11191B"), 0.36, 0.34), "PackageLowerEdge")
	var core := _add_box(root, Vector3(2.26, 0.135, 2.26), Vector3(0.0, 0.005, 0.0), _material(Color("#1D302D"), 0.42, 0.38), "PackageSubstrate")
	var top_mask := _add_box(root, Vector3(2.22, 0.022, 2.22), Vector3(0.0, 0.082, 0.0), _material(Color("#203B34"), 0.32, 0.34), "TopSolderMask")
	package_layers.append_array([lower_edge, core, top_mask])

	var copper := _material(Color("#B58B4C"), 0.82, 0.25)
	for side in [-1.0, 1.0]:
		for index in range(6):
			var along := -0.72 + float(index) * 0.288
			_add_box(root, Vector3(0.10, 0.008, 0.014), Vector3(along, 0.096, side * 1.075), copper, "TopEdgeTrace")
			_add_box(root, Vector3(0.014, 0.008, 0.10), Vector3(side * 1.075, 0.096, along), copper, "SideEdgeTrace")

	var frame_material := _material(Color("#6C604B"), 0.72, 0.28)
	_add_box(root, Vector3(1.49, 0.025, 1.49), Vector3(0.0, 0.111, 0.0), frame_material, "DieBondFrame")
	_add_box(root, Vector3(1.39, 0.045, 1.39), Vector3(0.0, 0.145, 0.0), _material(Color("#20272C"), 0.38, 0.30), "SiliconDie")
	var die_surface := _add_box(root, Vector3(1.32, 0.012, 1.32), Vector3(0.0, 0.173, 0.0), _material(Color("#171D22"), 0.32, 0.24), "SiliconDieSurface")
	var die_surfaces: Array[MeshInstance3D] = [die_surface]

	var frame_gold := _material(Color("#C69A55"), 0.86, 0.22)
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(1.44, 0.007, 0.012), Vector3(0.0, 0.126, side * 0.728), frame_gold, "DieFrameEdge")
		_add_box(root, Vector3(0.012, 0.007, 1.44), Vector3(side * 0.728, 0.126, 0.0), frame_gold, "DieFrameEdge")

	var ceramic := _material(Color("#B6B4A8"), 0.18, 0.30)
	var terminal := _material(Color("#B58C51"), 0.78, 0.23)
	for index in range(4):
		var along := -0.78 + float(index) * 0.52
		_add_smd(root, Vector3(along, 0.118, 0.91), ceramic, terminal)
		_add_smd(root, Vector3(along, 0.118, -0.91), ceramic, terminal)
		_add_smd(root, Vector3(0.91, 0.118, along), ceramic, terminal)
		_add_smd(root, Vector3(-0.91, 0.118, along), ceramic, terminal)

	_add_marking(root, "DW", 46, Vector3(0.0, 0.181, -0.12), Color("#C7C9C5"), 0.0042, "LaserEtchedMarking_Logo")
	_add_marking(root, "SILICON 01", 19, Vector3(0.0, 0.181, 0.20), Color("#AAB1B4"), 0.0032, "LaserEtchedMarking_Product")
	_add_marking(root, "MOBILE COMPUTE  ·  REV A", 9, Vector3(0.0, 0.181, 0.36), Color("#78858A"), 0.0023, "LaserEtchedMarking_Revision")
	_build_contacts(root, 15, 2.0, "BGA", "UndersideBGAContactArray")
	return {
		"package_layers": package_layers,
		"die_surfaces": die_surfaces,
		"contact_count": 225
	}


static func _build_variant_design(root: Node3D, profile: Dictionary) -> Dictionary:
	var board_size := float(profile.get("board_size", 2.30))
	var substrate_color := Color("#1D302D")
	var lower := _add_box(root, Vector3(board_size, 0.035, board_size), Vector3(0.0, -0.075, 0.0), _material(Color("#11191B"), 0.42, 0.34), "PackageLowerEdge")
	var substrate := _add_box(root, Vector3(board_size - 0.04, 0.135, board_size - 0.04), Vector3(0.0, 0.005, 0.0), _material(substrate_color, 0.42, 0.36), "PackageSubstrate")
	var top_mask := _add_box(root, Vector3(board_size - 0.08, 0.022, board_size - 0.08), Vector3(0.0, 0.082, 0.0), _material(Color("#203B34"), 0.30, 0.38), "TopSolderMask")
	var package_layers: Array[MeshInstance3D] = [lower, substrate, top_mask]

	var edge_copper := _material(Color("#B58B4C"), 0.82, 0.25)
	for side in [-1.0, 1.0]:
		for index in range(6):
			var along := -board_size * 0.32 + float(index) * board_size * 0.128
			_add_box(root, Vector3(board_size * 0.045, 0.008, 0.014), Vector3(along, 0.096, side * (board_size * 0.468)), edge_copper, "SubstrateEdgeTrace")
			_add_box(root, Vector3(0.014, 0.008, board_size * 0.045), Vector3(side * (board_size * 0.468), 0.096, along), edge_copper, "SubstrateEdgeTrace")

	var die_surfaces: Array[MeshInstance3D] = []
	var layout := str(profile.get("layout", "compact_logic"))
	match layout:
		"compact_logic":
			_add_die(root, Vector2.ZERO, Vector2(1.10, 1.10), 0.145, Color("#171D22"), die_surfaces, "MainLogicDie")
		"logic_companion":
			_add_die(root, Vector2(-0.25, 0.02), Vector2(1.18, 1.18), 0.145, Color("#202A32"), die_surfaces, "ApplicationProcessorDie")
			_add_die(root, Vector2(0.67, -0.42), Vector2(0.40, 0.48), 0.145, Color("#353C42"), die_surfaces, "PowerManagementDie")
		"dual_compute":
			_add_die(root, Vector2(-0.48, 0.0), Vector2(0.78, 1.22), 0.145, Color("#171D22"), die_surfaces, "CPUComputeDie")
			_add_die(root, Vector2(0.48, 0.0), Vector2(0.78, 1.22), 0.145, Color("#343C44"), die_surfaces, "GraphicsComputeDie")
		"triple_chiplet":
			_add_die(root, Vector2(-0.48, -0.32), Vector2(0.74, 0.82), 0.145, Color("#172027"), die_surfaces, "CPUChiplet")
			_add_die(root, Vector2(0.48, -0.32), Vector2(0.74, 0.82), 0.145, Color("#303B45"), die_surfaces, "GPUChiplet")
			_add_die(root, Vector2(0.0, 0.54), Vector2(0.72, 0.48), 0.145, Color("#42484A"), die_surfaces, "IOChiplet")
		"stacked_logic":
			_add_die(root, Vector2.ZERO, Vector2(1.16, 1.16), 0.145, Color("#252D34"), die_surfaces, "BaseLogicDie")
			_add_die(root, Vector2.ZERO, Vector2(0.86, 0.86), 0.226, Color("#48525A"), die_surfaces, "StackedLogicDie")
			_add_box(root, Vector3(0.94, 0.012, 0.94), Vector3(0.0, 0.188, 0.0), _material(Color("#B39A73"), 0.72, 0.28), "DieToDieBondLayer")
		"pop_memory":
			_add_die(root, Vector2.ZERO, Vector2(0.92, 0.92), 0.145, Color("#1E272E"), die_surfaces, "ApplicationProcessorDie")
			_add_box(root, Vector3(1.42, 0.055, 0.86), Vector3(0.0, 0.235, 0.0), _material(Color("#222B30"), 0.46, 0.30), "PoPMemoryPackageSubstrate")
			_add_box(root, Vector3(1.34, 0.018, 0.78), Vector3(0.0, 0.274, 0.0), _material(Color("#394249"), 0.30, 0.34), "PoPMemoryMouldCap")
			_add_die(root, Vector2(-0.32, 0.0), Vector2(0.42, 0.50), 0.292, Color("#59636A"), die_surfaces, "StackedMemoryDieLeft")
			_add_die(root, Vector2(0.32, 0.0), Vector2(0.42, 0.50), 0.292, Color("#59636A"), die_surfaces, "StackedMemoryDieRight")
		"quad_chiplet":
			for x_side in [-1.0, 1.0]:
				for z_side in [-1.0, 1.0]:
					var tile_color := Color("#1C252D") if x_side == z_side else Color("#39444D")
					_add_die(root, Vector2(x_side * 0.43, z_side * 0.43), Vector2(0.60, 0.60), 0.145, tile_color, die_surfaces, "ComputeChiplet")
		"metal_lid":
			_add_die(root, Vector2.ZERO, Vector2(1.08, 1.08), 0.145, Color("#20282E"), die_surfaces, "CoveredApplicationDie")
			_add_box(root, Vector3(1.62, 0.035, 1.62), Vector3(0.0, 0.155, 0.0), _material(Color("#777F83"), 0.86, 0.24), "HeatSpreaderRetentionFrame")
			var heat_spreader := _add_box(root, Vector3(1.48, 0.055, 1.48), Vector3(0.0, 0.199, 0.0), _material(Color("#9DA5A6"), 0.88, 0.22), "NickelAlloyHeatSpreaderLid")
			die_surfaces.append(heat_spreader)
			_add_marking(root, "DW", 28, Vector3(0.0, 0.228, -0.15), Color("#E4E7E4"), 0.0034, "HeatSpreaderLogo")
			_add_marking(root, "VERTEX 09", 12, Vector3(0.0, 0.228, 0.18), Color("#D2D7D7"), 0.0028, "HeatSpreaderProduct")
		"stiffened_die":
			_add_box(root, Vector3(1.76, 0.025, 1.76), Vector3(0.0, 0.108, 0.0), _material(Color("#777F82"), 0.82, 0.30), "DieStiffenerFrame")
			_add_die(root, Vector2.ZERO, Vector2(1.24, 1.24), 0.145, Color("#3F484D"), die_surfaces, "ReinforcedApplicationDie")
		"elongated_dual":
			_add_die(root, Vector2(-0.43, 0.0), Vector2(0.72, 1.22), 0.145, Color("#1C252D"), die_surfaces, "PrimaryComputeDie")
			_add_die(root, Vector2(0.43, 0.0), Vector2(0.72, 1.22), 0.145, Color("#3A444B"), die_surfaces, "SecondaryComputeDie")
		"fanout":
			_add_die(root, Vector2.ZERO, Vector2(1.12, 1.12), 0.145, Color("#20292F"), die_surfaces, "FanOutLogicDie")
			var routing := _material(Color("#B58B4C"), 0.82, 0.28)
			for index in range(7):
				var offset := -0.78 + float(index) * 0.26
				_add_box(root, Vector3(0.012, 0.006, 0.54), Vector3(offset, 0.103, 0.0), routing, "FanOutRedistributionTrace")
				_add_box(root, Vector3(0.54, 0.006, 0.012), Vector3(0.0, 0.103, offset), routing, "FanOutRedistributionTrace")
		"lga":
			_add_die(root, Vector2.ZERO, Vector2(1.18, 1.18), 0.145, Color("#313B42"), die_surfaces, "LGAApplicationDie")
		"interposer":
			_add_box(root, Vector3(1.92, 0.018, 1.92), Vector3(0.0, 0.104, 0.0), _material(Color("#414A4E"), 0.56, 0.34), "SiliconInterposer")
			_add_die(root, Vector2.ZERO, Vector2(0.62, 0.62), 0.145, Color("#222A31"), die_surfaces, "CentralIOChiplet")
			for x_side in [-1.0, 1.0]:
				for z_side in [-1.0, 1.0]:
					_add_die(root, Vector2(x_side * 0.55, z_side * 0.55), Vector2(0.48, 0.48), 0.145, Color("#3A444B"), die_surfaces, "InterposerComputeChiplet")
		"triple_stack":
			_add_die(root, Vector2.ZERO, Vector2(0.82, 0.82), 0.145, Color("#202A31"), die_surfaces, "CentralApplicationDie")
			_add_die(root, Vector2(-0.52, 0.0), Vector2(0.48, 0.66), 0.145, Color("#39454C"), die_surfaces, "LeftMemoryBaseDie")
			_add_die(root, Vector2(-0.52, 0.0), Vector2(0.38, 0.54), 0.218, Color("#59636A"), die_surfaces, "LeftStackedMemoryDie")
			_add_die(root, Vector2(0.52, 0.0), Vector2(0.48, 0.66), 0.145, Color("#39454C"), die_surfaces, "RightMemoryBaseDie")
			_add_die(root, Vector2(0.52, 0.0), Vector2(0.38, 0.54), 0.218, Color("#59636A"), die_surfaces, "RightStackedMemoryDie")

	var ceramic := _material(Color("#B6B4A8"), 0.18, 0.30)
	var terminal := _material(Color("#B58C51"), 0.78, 0.23)
	_add_perimeter_passives(root, board_size, ceramic, terminal)
	_add_marking(root, "DW", 24, Vector3(0.0, 0.112, board_size * 0.405), Color("#D2D5D0"), 0.0030, "ProcessorBrandMarking")
	_add_marking(root, str(profile.get("name", "DW PROCESSOR")), 10, Vector3(0.0, 0.112, board_size * 0.34), Color("#AAB1B4"), 0.0018, "ProcessorProductMarking")

	var grid := int(profile.get("grid", 15))
	var contacts := str(profile.get("contacts", "BGA"))
	_build_contacts(root, grid, board_size * 0.86, contacts, "Underside%sContactArray" % contacts)
	return {
		"package_layers": package_layers,
		"die_surfaces": die_surfaces,
		"contact_count": grid * grid
	}


static func _add_die(parent: Node3D, centre: Vector2, dimensions: Vector2, base_height: float, die_color: Color, die_surfaces: Array[MeshInstance3D], node_prefix: String) -> MeshInstance3D:
	var frame_size := dimensions + Vector2(0.075, 0.075)
	_add_box(parent, Vector3(frame_size.x, 0.024, frame_size.y), Vector3(centre.x, base_height - 0.034, centre.y), _material(Color("#78684E"), 0.72, 0.30), node_prefix + "BondFrame")
	_add_box(parent, Vector3(dimensions.x + 0.018, 0.044, dimensions.y + 0.018), Vector3(centre.x, base_height, centre.y), _material(Color("#20272C"), 0.38, 0.30), node_prefix + "SiliconCore")
	var surface := _add_box(parent, Vector3(dimensions.x, 0.012, dimensions.y), Vector3(centre.x, base_height + 0.028, centre.y), _material(die_color, 0.34, 0.25), node_prefix + "DieSurface")
	die_surfaces.append(surface)
	return surface


static func _add_perimeter_passives(parent: Node3D, board_size: float, ceramic: StandardMaterial3D, terminal: StandardMaterial3D) -> void:
	var offset := board_size * 0.40
	for index in range(4):
		var along := -board_size * 0.27 + float(index) * board_size * 0.18
		_add_smd(parent, Vector3(along, 0.118, offset), ceramic, terminal)
		_add_smd(parent, Vector3(along, 0.118, -offset), ceramic, terminal)
		_add_smd(parent, Vector3(offset, 0.118, along), ceramic, terminal)
		_add_smd(parent, Vector3(-offset, 0.118, along), ceramic, terminal)


static func _add_smd(parent: Node3D, at: Vector3, body_material: StandardMaterial3D, terminal_material: StandardMaterial3D) -> void:
	_add_box(parent, Vector3(0.14, 0.035, 0.075), at, body_material, "SurfaceMountPassive")
	for side in [-1.0, 1.0]:
		_add_box(parent, Vector3(0.018, 0.039, 0.078), at + Vector3(side * 0.068, 0.0, 0.0), terminal_material, "PassiveMetalEnd")


static func _add_marking(parent: Node3D, value: String, font_size_value: int, at: Vector3, color: Color, pixel_size_value: float, node_name: String) -> void:
	var marking := Label3D.new()
	marking.name = node_name
	marking.text = value
	marking.font_size = font_size_value
	marking.pixel_size = pixel_size_value
	marking.modulate = color
	marking.shaded = true
	marking.no_depth_test = false
	marking.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marking.position = at
	parent.add_child(marking)


static func _build_contacts(parent: Node3D, grid_count: int, field_size: float, contact_type: String, node_name: String) -> void:
	var contacts := MultiMesh.new()
	contacts.transform_format = MultiMesh.TRANSFORM_3D
	if contact_type == "LGA":
		var pad_mesh := BoxMesh.new()
		pad_mesh.size = Vector3(0.078, 0.012, 0.078)
		contacts.mesh = pad_mesh
	else:
		var ball_mesh := SphereMesh.new()
		ball_mesh.radius = 0.034
		ball_mesh.height = 0.068
		ball_mesh.radial_segments = 10
		ball_mesh.rings = 6
		contacts.mesh = ball_mesh
	contacts.instance_count = grid_count * grid_count
	var step := field_size / float(maxi(1, grid_count - 1))
	var start := -field_size * 0.5
	for row in range(grid_count):
		for column in range(grid_count):
			var x := start + float(column) * step
			var z := start + float(row) * step
			var y := -0.126 if contact_type == "BGA" else -0.105
			contacts.set_instance_transform(row * grid_count + column, Transform3D(Basis.IDENTITY, Vector3(x, y, z)))
	var contact_array := MultiMeshInstance3D.new()
	contact_array.name = node_name
	contact_array.multimesh = contacts
	contact_array.material_override = _material(Color("#D3A957"), 0.91, 0.20)
	parent.add_child(contact_array)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _add_box(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part
