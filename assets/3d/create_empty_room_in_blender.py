"""Create the empty 6 m x 5 m x 3 m room in Blender and export it for Godot.

Run from Blender's Scripting workspace or with:
    blender --background --python create_empty_room_in_blender.py

The saved .blend keeps the procedural plaster materials, glass exit door and preview lighting.
The exported .glb contains the room shell and matching glass exit door.
"""

import bpy
import math
import os
from mathutils import Vector

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else bpy.path.abspath("//")
BLEND_PATH = os.path.join(OUTPUT_DIR, "empty_room.blend")
GLB_PATH = os.path.join(OUTPUT_DIR, "empty_room.glb")

# Start with a clean Blender scene.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.name != "Collection":
        try:
            bpy.data.collections.remove(collection)
        except Exception:
            pass
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.render.resolution_x = 1440
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"


def make_plaster_material(name, color, roughness, noise_scale, bump_distance):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness

    texcoord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 2.0
    noise.inputs["Roughness"].default_value = 0.68
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.12
    bump.inputs["Distance"].default_value = bump_distance
    links.new(texcoord.outputs["Generated"], noise.inputs["Vector"])
    color_ramp = nodes.new("ShaderNodeValToRGB")
    color_ramp.color_ramp.elements[0].position = 0.0
    color_ramp.color_ramp.elements[0].color = (*(component * 0.965 for component in color), 1.0)
    color_ramp.color_ramp.elements[1].position = 1.0
    color_ramp.color_ramp.elements[1].color = (*(component * 1.025 for component in color), 1.0)
    links.new(noise.outputs["Fac"], color_ramp.inputs["Fac"])
    links.new(color_ramp.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return material


wall_material = make_plaster_material("Warm neutral matte wall plaster", (0.76, 0.75, 0.71), 0.94, 145.0, 0.010)
floor_material = make_plaster_material("Soft grey mineral floor", (0.39, 0.41, 0.42), 0.88, 105.0, 0.006)
ceiling_material = make_plaster_material("Warm white ceiling plaster", (0.86, 0.85, 0.81), 0.97, 155.0, 0.008)

# The clear interior dimensions are exactly 6.0 m wide, 5.0 m deep and 3.0 m high.
room_parts = [
    ("Room_Floor", (0.0, -0.08, 0.0), (6.16, 0.16, 5.16), floor_material),
    ("Room_Left_Wall", (-3.08, 1.50, 0.0), (0.16, 3.16, 5.16), wall_material),
    ("Room_Right_Wall", (3.08, 1.50, 0.0), (0.16, 3.16, 5.16), wall_material),
    # Leave a 1.44 m x 2.20 m opening in the far wall for the glass exit door.
    ("Room_Back_Wall_Left", (-1.90, 1.50, -2.58), (2.36, 3.16, 0.16), wall_material),
    ("Room_Back_Wall_Right", (1.90, 1.50, -2.58), (2.36, 3.16, 0.16), wall_material),
    ("Room_Back_Wall_Lintel", (0.0, 2.64, -2.58), (1.44, 0.88, 0.16), wall_material),
    ("Room_Front_Wall", (0.0, 1.50, 2.58), (6.16, 3.16, 0.16), wall_material),
    ("Room_Ceiling", (0.0, 3.08, 0.0), (6.16, 0.16, 5.16), ceiling_material),
]
room_objects = []
for name, location, dimensions, material in room_parts:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    room_objects.append(obj)


# Simple glazed exit door, sized to fit the opening in the far wall.
door_frame_material = bpy.data.materials.new("Graphite metal door frame")
door_frame_material.diffuse_color = (0.20, 0.23, 0.24, 1.0)
door_frame_material.use_nodes = True
frame_bsdf = door_frame_material.node_tree.nodes.get("Principled BSDF")
frame_bsdf.inputs["Base Color"].default_value = (0.20, 0.23, 0.24, 1.0)
frame_bsdf.inputs["Metallic"].default_value = 0.48
frame_bsdf.inputs["Roughness"].default_value = 0.38

glass_material = bpy.data.materials.new("Soft blue green safety glass")
glass_material.diffuse_color = (0.44, 0.66, 0.69, 0.38)
glass_material.use_nodes = True
glass_bsdf = glass_material.node_tree.nodes.get("Principled BSDF")
glass_bsdf.inputs["Base Color"].default_value = (0.44, 0.66, 0.69, 0.38)
glass_bsdf.inputs["Alpha"].default_value = 0.38
glass_bsdf.inputs["Metallic"].default_value = 0.22
glass_bsdf.inputs["Roughness"].default_value = 0.16
transmission_socket = glass_bsdf.inputs.get("Transmission Weight") or glass_bsdf.inputs.get("Transmission")
if transmission_socket is not None:
    transmission_socket.default_value = 0.18
try:
    glass_material.surface_render_method = "BLENDED"
except Exception:
    try:
        glass_material.blend_method = "BLEND"
    except Exception:
        pass

sign_material = bpy.data.materials.new("Exit sign deep green")
sign_material.diffuse_color = (0.06, 0.19, 0.13, 1.0)
sign_material.use_nodes = True
sign_bsdf = sign_material.node_tree.nodes.get("Principled BSDF")
sign_bsdf.inputs["Base Color"].default_value = (0.06, 0.19, 0.13, 1.0)
sign_bsdf.inputs["Roughness"].default_value = 0.72

handle_material = bpy.data.materials.new("Brushed stainless steel handle")
handle_material.diffuse_color = (0.72, 0.75, 0.74, 1.0)
handle_material.use_nodes = True
handle_bsdf = handle_material.node_tree.nodes.get("Principled BSDF")
handle_bsdf.inputs["Base Color"].default_value = (0.72, 0.75, 0.74, 1.0)
handle_bsdf.inputs["Metallic"].default_value = 0.82
handle_bsdf.inputs["Roughness"].default_value = 0.22

door_objects = []


def add_door_box(name, location, dimensions, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    door_objects.append(obj)
    return obj


add_door_box("Glass_Exit_Door_Pane", (0.0, 1.10, -2.475), (1.20, 2.08, 0.035), glass_material)
add_door_box("Glass_Exit_Door_Frame_Left", (-0.68, 1.10, -2.49), (0.08, 2.20, 0.16), door_frame_material)
add_door_box("Glass_Exit_Door_Frame_Right", (0.68, 1.10, -2.49), (0.08, 2.20, 0.16), door_frame_material)
add_door_box("Glass_Exit_Door_Frame_Top", (0.0, 2.20, -2.49), (1.44, 0.10, 0.16), door_frame_material)
add_door_box("Glass_Exit_Door_Threshold", (0.0, 0.045, -2.49), (1.44, 0.09, 0.20), door_frame_material)
add_door_box("Exit_Door_Handle_Mount", (0.48, 1.08, -2.445), (0.075, 0.22, 0.035), door_frame_material)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.48, 1.08, -2.415))
handle = bpy.context.object
handle.name = "Exit_Door_Pull_Handle"
handle.dimensions = (0.036, 0.34, 0.036)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
handle.data.materials.append(handle_material)
door_objects.append(handle)

add_door_box("Exit_Sign_Panel", (0.0, 2.37, -2.48), (0.62, 0.18, 0.055), sign_material)

exit_text_curve = bpy.data.curves.new("Exit sign lettering", type="FONT")
exit_text_curve.body = "EXIT"
exit_text_curve.align_x = "CENTER"
exit_text_curve.align_y = "CENTER"
exit_text_curve.size = 0.115
exit_text_curve.extrude = 0.001
exit_text = bpy.data.objects.new("Exit_Sign_Text", exit_text_curve)
scene.collection.objects.link(exit_text)
exit_text.location = (0.0, 2.37, -2.44)
exit_text_curve.materials.append(handle_material)
bpy.ops.object.select_all(action="DESELECT")
exit_text.select_set(True)
bpy.context.view_layer.objects.active = exit_text
bpy.ops.object.convert(target="MESH")
door_objects.append(bpy.context.object)


# Soft preview lighting is included in the editable Blender project, not the exported room model.
def add_area_light(name, location, power, size, rotation):
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    return obj


add_area_light("Soft ceiling bounce", (0.0, 2.78, 0.0), 520.0, 3.2, (math.radians(-90.0), 0.0, 0.0))
add_area_light("Gentle front fill", (0.0, 1.75, 1.95), 135.0, 2.4, (0.0, 0.0, 0.0))

world = bpy.data.worlds.new("Empty Room Preview World") if bpy.data.worlds.get("Empty Room Preview World") is None else bpy.data.worlds["Empty Room Preview World"]
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.18, 0.19, 0.20, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45

camera_data = bpy.data.cameras.new("Empty Room Preview Camera")
camera = bpy.data.objects.new("Empty Room Preview Camera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0.0, 1.92, 2.16)
target = Vector((0.0, 1.48, -0.10))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.lens = 27.0
camera_data.clip_start = 0.05
camera_data.clip_end = 40.0
scene.camera = camera

# Export the room shell and the simple glazed exit door; lighting and camera remain Blender-only.
bpy.ops.object.select_all(action="DESELECT")
for obj in room_objects + door_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = room_objects[0]
bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", use_selection=True, export_apply=True)

# Save the editable Blender project with the preview camera, lights and procedural materials.
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = camera
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
print("EMPTY_ROOM_BLENDER_BUILD: created", BLEND_PATH, "and", GLB_PATH)
