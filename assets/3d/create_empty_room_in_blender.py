"""Create the empty 6 m x 5 m x 3 m room in Blender and export it for Godot.

Run from Blender's Scripting workspace or with:
    blender --background --python create_empty_room_in_blender.py

The saved .blend keeps the procedural plaster materials and preview lighting.
The exported .glb contains only the six architectural room surfaces.
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
    ("Room_Back_Wall", (0.0, 1.50, -2.58), (6.16, 3.16, 0.16), wall_material),
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

# Export only the six architectural surfaces to keep the Godot asset completely empty.
bpy.ops.object.select_all(action="DESELECT")
for obj in room_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = room_objects[0]
bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", use_selection=True, export_apply=True)

# Save the editable Blender project with the preview camera, lights and procedural materials.
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = camera
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
print("EMPTY_ROOM_BLENDER_BUILD: created", BLEND_PATH, "and", GLB_PATH)
