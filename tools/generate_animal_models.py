# Fact 1: Tools script to generate 3D low-poly models for AoE 1 wildlife animals via Blender
# Fact 2: Output to C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\models
# Fact 3: Models generated: gazelle.glb, elephant.glb, lion.glb, alligator.glb
# Fact 4: User verbatim request: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi C:\Users\nguye\Downloads\Age of Empires 1_Linkneverdie.com\Age of Empires 1_Linkneverdie.com\Age of Empires"

import bpy
import os
import math

OUT_DIR = "C:/Users/nguye/Godot_v4.7.2-stable_win64.exe/git/Age-of-Low-Poly/assets/models"
os.makedirs(OUT_DIR, exist_ok=True)

def reset_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for mesh in bpy.data.meshes:
        bpy.data.meshes.remove(mesh)
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat)

def make_mat(name, color_rgba, roughness=0.85):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs['Base Color'].default_value = color_rgba
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

def export_glb(filename):
    filepath = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("SUCCESS: Exported", filename)

# ==============================================================================
# 1. GAZELLE.GLB (Nai / Linh dương chạy trốn)
# ==============================================================================
reset_scene()
mat_tan = make_mat("GazelleTan", (0.76, 0.52, 0.30, 1.0))
mat_belly = make_mat("GazelleWhite", (0.92, 0.88, 0.80, 1.0))
mat_horn = make_mat("GazelleHorn", (0.18, 0.16, 0.14, 1.0))
mat_hoof = make_mat("GazelleHoof", (0.12, 0.10, 0.08, 1.0))

# Body (torso)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.95))
body = bpy.context.active_object
body.scale = (0.35, 0.8, 0.4)
body.data.materials.append(mat_tan)

# White underbelly
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.05, 0.78))
belly = bpy.context.active_object
belly.scale = (0.32, 0.65, 0.12)
belly.data.materials.append(mat_belly)

# Neck
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.42, 1.25))
neck = bpy.context.active_object
neck.scale = (0.2, 0.28, 0.45)
neck.rotation_euler = (math.radians(-30), 0, 0)
neck.data.materials.append(mat_tan)

# Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.58, 1.48))
head = bpy.context.active_object
head.scale = (0.22, 0.38, 0.22)
head.rotation_euler = (math.radians(10), 0, 0)
head.data.materials.append(mat_tan)

# Snout
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.74, 1.42))
snout = bpy.context.active_object
snout.scale = (0.16, 0.18, 0.14)
snout.data.materials.append(mat_horn)

# Horns (left and right curved)
for hx in [-0.07, 0.07]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.03, depth=0.45, location=(hx, -0.48, 1.72))
    horn = bpy.context.active_object
    horn.rotation_euler = (math.radians(35), math.radians(10 if hx > 0 else -10), 0)
    horn.data.materials.append(mat_horn)

# Ears
for ex in [-0.14, 0.14]:
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.05, depth=0.2, location=(ex, -0.45, 1.58))
    ear = bpy.context.active_object
    ear.rotation_euler = (math.radians(-40), math.radians(45 if ex > 0 else -45), 0)
    ear.data.materials.append(mat_tan)

# Legs (4 slender legs + hooves)
for lx in [-0.14, 0.14]:
    for ly in [-0.3, 0.3]:
        # Upper leg
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.045, depth=0.75, location=(lx, ly, 0.42))
        leg = bpy.context.active_object
        leg.data.materials.append(mat_tan)
        # Hoof
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.048, depth=0.1, location=(lx, ly, 0.05))
        hoof = bpy.context.active_object
        hoof.data.materials.append(mat_hoof)

# Tail
bpy.ops.mesh.primitive_cylinder_add(vertices=4, radius=0.03, depth=0.25, location=(0, 0.44, 0.88))
tail = bpy.context.active_object
tail.rotation_euler = (math.radians(40), 0, 0)
tail.data.materials.append(mat_horn)

export_glb("gazelle.glb")

# ==============================================================================
# 2. ELEPHANT.GLB (Voi chiến / Voi rừng săn thịt)
# ==============================================================================
reset_scene()
mat_ele_skin = make_mat("ElephantSkin", (0.42, 0.43, 0.45, 1.0), roughness=0.95)
mat_tusk = make_mat("IvoryTusk", (0.95, 0.94, 0.86, 1.0), roughness=0.3)
mat_dark = make_mat("ElephantDark", (0.22, 0.22, 0.24, 1.0))

# Massive Body
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.7))
body = bpy.context.active_object
body.scale = (1.5, 2.2, 1.4)
body.data.materials.append(mat_ele_skin)

# Back hump
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.2, 2.3))
hump = bpy.context.active_object
hump.scale = (1.2, 1.4, 0.4)
hump.data.materials.append(mat_ele_skin)

# Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.35, 1.95))
head = bpy.context.active_object
head.scale = (1.1, 1.1, 1.1)
head.data.materials.append(mat_ele_skin)

# Trunk (curved forward)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.22, depth=1.0, location=(0, -1.95, 1.5))
t1 = bpy.context.active_object
t1.rotation_euler = (math.radians(-30), 0, 0)
t1.data.materials.append(mat_ele_skin)

bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.18, depth=0.8, location=(0, -2.25, 0.9))
t2 = bpy.context.active_object
t2.rotation_euler = (math.radians(15), 0, 0)
t2.data.materials.append(mat_ele_skin)

bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.14, depth=0.5, location=(0, -2.15, 0.45))
t3 = bpy.context.active_object
t3.rotation_euler = (math.radians(65), 0, 0)
t3.data.materials.append(mat_ele_skin)

# Tusks (Left & Right curved)
for tx in [-0.45, 0.45]:
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.12, depth=1.2, location=(tx, -1.9, 1.25))
    tusk = bpy.context.active_object
    tusk.rotation_euler = (math.radians(-45), math.radians(15 if tx > 0 else -15), 0)
    tusk.data.materials.append(mat_tusk)

# Large Ears
for ex in [-0.85, 0.85]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ex, -1.2, 1.95))
    ear = bpy.context.active_object
    ear.scale = (0.1, 0.8, 0.9)
    ear.rotation_euler = (0, math.radians(20 if ex > 0 else -20), math.radians(15 if ex > 0 else -15))
    ear.data.materials.append(mat_ele_skin)

# Stout Pillar Legs (4 legs)
for lx in [-0.55, 0.55]:
    for ly in [-0.8, 0.8]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.32, depth=1.2, location=(lx, ly, 0.6))
        leg = bpy.context.active_object
        leg.data.materials.append(mat_ele_skin)
        # Feet pads
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.34, depth=0.15, location=(lx, ly, 0.08))
        foot = bpy.context.active_object
        foot.data.materials.append(mat_dark)

# Tail
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.06, depth=0.9, location=(0, 1.15, 1.25))
tail = bpy.context.active_object
tail.rotation_euler = (math.radians(20), 0, 0)
tail.data.materials.append(mat_dark)

export_glb("elephant.glb")

# ==============================================================================
# 3. LION.GLB (Sư tử săn mồi hung dữ)
# ==============================================================================
reset_scene()
mat_lion_body = make_mat("LionBody", (0.80, 0.60, 0.28, 1.0))
mat_mane = make_mat("LionMane", (0.42, 0.24, 0.12, 1.0))
mat_nose = make_mat("LionNose", (0.22, 0.14, 0.10, 1.0))
mat_eye = make_mat("LionEye", (0.95, 0.85, 0.20, 1.0))

# Muscular Body
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.75))
body = bpy.context.active_object
body.scale = (0.55, 1.2, 0.55)
body.data.materials.append(mat_lion_body)

# Majestic Dark Mane (Chest + Neck)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.65, 0.95))
mane = bpy.context.active_object
mane.scale = (0.85, 0.75, 0.85)
mane.data.materials.append(mat_mane)

# Head
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.0, 1.05))
head = bpy.context.active_object
head.scale = (0.45, 0.45, 0.45)
head.data.materials.append(mat_lion_body)

# Snout / Jaws
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.25, 0.96))
snout = bpy.context.active_object
snout.scale = (0.28, 0.32, 0.25)
snout.data.materials.append(mat_lion_body)

# Nose tip
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.42, 1.02))
nose = bpy.context.active_object
nose.scale = (0.12, 0.08, 0.08)
nose.data.materials.append(mat_nose)

# Ears
for ex in [-0.22, 0.22]:
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, depth=0.16, location=(ex, -0.92, 1.32))
    ear = bpy.context.active_object
    ear.rotation_euler = (math.radians(-20), math.radians(20 if ex > 0 else -20), 0)
    ear.data.materials.append(mat_mane)

# 4 Powerful Legs
for lx in [-0.24, 0.24]:
    for ly in [-0.45, 0.45]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.09, depth=0.6, location=(lx, ly, 0.32))
        leg = bpy.context.active_object
        leg.data.materials.append(mat_lion_body)
        # Paws
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly - 0.04, 0.06))
        paw = bpy.context.active_object
        paw.scale = (0.18, 0.22, 0.12)
        paw.data.materials.append(mat_lion_body)

# Long Tail with tuft
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.04, depth=0.8, location=(0, 0.75, 0.65))
tail = bpy.context.active_object
tail.rotation_euler = (math.radians(35), 0, 0)
tail.data.materials.append(mat_lion_body)

bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=0.08, location=(0, 1.05, 0.35))
tuft = bpy.context.active_object
tuft.data.materials.append(mat_mane)

export_glb("lion.glb")

# ==============================================================================
# 4. ALLIGATOR.GLB (Cá sấu đầm lầy / bờ sông)
# ==============================================================================
reset_scene()
mat_gator_back = make_mat("GatorBack", (0.24, 0.35, 0.20, 1.0), roughness=0.9)
mat_gator_belly = make_mat("GatorBelly", (0.55, 0.60, 0.35, 1.0), roughness=0.8)
mat_teeth = make_mat("GatorTeeth", (0.95, 0.95, 0.90, 1.0), roughness=0.3)

# Flat elongated body
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.24))
body = bpy.context.active_object
body.scale = (0.6, 1.6, 0.26)
body.data.materials.append(mat_gator_back)

# Long Snout
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.2, 0.20))
snout = bpy.context.active_object
snout.scale = (0.42, 1.1, 0.16)
snout.data.materials.append(mat_gator_back)

# Ridges along the back
for rz in range(-5, 6):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.06, depth=0.15, location=(0, rz * 0.2, 0.42))
    ridge = bpy.context.active_object
    ridge.data.materials.append(mat_gator_belly)

# 4 sprawling reptilian legs
for lx in [-0.45, 0.45]:
    for ly in [-0.5, 0.5]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, ly, 0.16))
        leg = bpy.context.active_object
        leg.scale = (0.35, 0.18, 0.14)
        leg.rotation_euler = (0, 0, math.radians(25 if lx > 0 else -25))
        leg.data.materials.append(mat_gator_back)

# Heavy long tail
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.25, depth=1.6, location=(0, 1.45, 0.20))
tail = bpy.context.active_object
tail.rotation_euler = (math.radians(90), 0, 0)
tail.data.materials.append(mat_gator_back)

export_glb("alligator.glb")
print("=== All Wildlife 3D Models Successfully Generated ===")
