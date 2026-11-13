extends Node

# Modern animated backdrop for the landing page. It draws the shader behind the
# 3D hero, then adds light rings to the podium and a cool fill light.
const BACKDROP_SHADER: Shader = preload("res://shaders/landing_backdrop.gdshader")
const AMBER_ACCENT := Color("#C58A3A")
const CYAN_ACCENT := Color("#3FD0E0")

var ring_materials: Array[StandardMaterial3D] = []
var active_tweens: Array[Tween] = []


func _ready() -> void:
	_build_backdrop_layer()
	# The landing hero builds its environment in its own _ready, which runs after this child.
	var hero := get_parent() as Node3D
	if hero == null:
		return
	if not hero.is_node_ready():
		await hero.ready
	if not is_instance_valid(hero):
		return
	_render_backdrop_behind_world(hero)
	_add_stage_accents(hero)
	_animate_rings()


func _exit_tree() -> void:
	for tween in active_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	active_tweens.clear()


func _build_backdrop_layer() -> void:
	# Canvas layers at or below background_canvas_max_layer render behind the 3D scene.
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.name = "Landing_Modern_Backdrop"
	backdrop_layer.layer = -10
	add_child(backdrop_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "Landing_Backdrop_Shader"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BACKDROP_SHADER
	backdrop.material = shader_material
	backdrop_layer.add_child(backdrop)


func _render_backdrop_behind_world(hero: Node3D) -> void:
	for child in hero.get_children():
		var world_environment := child as WorldEnvironment
		if world_environment != null and world_environment.environment != null:
			world_environment.environment.background_mode = Environment.BG_CANVAS
			world_environment.environment.background_canvas_max_layer = -1


func _add_stage_accents(hero: Node3D) -> void:
	# Cool cyan fill ties the hero device into the backdrop lighting.
	var cyan_fill := OmniLight3D.new()
	cyan_fill.name = "Cyan_Fill_Light"
	cyan_fill.position = Vector3(9.0, 3.5, 7.0)
	cyan_fill.light_color = CYAN_ACCENT
	cyan_fill.light_energy = 0.55
	cyan_fill.omni_range = 20.0
	hero.add_child(cyan_fill)

	# Thin light rings trace the podium edges so the stage glows against the backdrop.
	_add_ring(hero, 8.26, 8.14, 0.03, _ring_material(CYAN_ACCENT, Color("#2AA9BA"), 0.5), "Podium_Edge_Light_Ring")
	_add_ring(hero, 5.96, 5.88, 0.125, _ring_material(AMBER_ACCENT, Color("#805621"), 0.48), "Upper_Disc_Light_Ring")


func _ring_material(color: Color, glow: Color, strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3
	material.metallic = 0.62
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = strength
	ring_materials.append(material)
	return material


func _add_ring(hero: Node3D, outer_radius: float, inner_radius: float, height: float, material: Material, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.outer_radius = outer_radius
	mesh.inner_radius = inner_radius
	mesh.rings = 96
	mesh.ring_segments = 10
	instance.mesh = mesh
	instance.position = Vector3(0.0, height, 0.0)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hero.add_child(instance)


func _animate_rings() -> void:
	for material in ring_materials:
		var pulse := create_tween().set_loops()
		active_tweens.append(pulse)
		pulse.tween_property(material, "emission_energy_multiplier", 0.62, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(material, "emission_energy_multiplier", 0.38, 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
