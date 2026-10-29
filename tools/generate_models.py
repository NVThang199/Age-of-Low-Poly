# Fact 1: Tools script to generate 3D models for AoE buildings and units via Blender
# Fact 2: Output to C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\models
# Fact 3: Models generated: farm, archery_range, stable, market, temple, siege_workshop, watch_tower, catapult
# Fact 4: User request: "tôi bảo bạn làm full game cho tôi hãy dùng cả blender mcp để làm mà đừng làm một vài chức năng làm full tất cả mọi thứ cho tôi làm sao để game giống game gốc"

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

def make_mat(name, color_rgba, roughness=0.8):
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

# ==========================================
# 1. FARM.GLB (Đất cày luống + Lúa mì vàng)
# ==========================================
reset_scene()
mat_dirt = make_mat("Dirt", (0.28, 0.18, 0.10, 1.0))
mat_crop = make_mat("Wheat", (0.85, 0.72, 0.22, 1.0))
mat_wood = make_mat("Wood", (0.35, 0.22, 0.12, 1.0))

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.08))
base = bpy.context.active_object
base.scale = (3.6, 3.6, 0.16)
base.data.materials.append(mat_dirt)

for i in range(-3, 4):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(i * 0.45, 0, 0.22))
    ridge = bpy.context.active_object
    ridge.scale = (0.28, 3.3, 0.15)
    ridge.data.materials.append(mat_crop)

for cx in [-1.7, 1.7]:
    for cy in [-1.7, 1.7]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.8, location=(cx, cy, 0.35))
        post = bpy.context.active_object
        post.data.materials.append(mat_wood)

export_glb("farm.glb")

# ==========================================
# 2. WATCH_TOWER.GLB (Tháp canh bắn tên)
# ==========================================
reset_scene()
mat_stone = make_mat("Stone", (0.55, 0.55, 0.55, 1.0))
mat_wood = make_mat("Wood", (0.38, 0.24, 0.14, 1.0))
mat_roof = make_mat("Roof", (0.75, 0.25, 0.15, 1.0))

# Base
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
base = bpy.context.active_object
base.scale = (2.2, 2.2, 1.0)
base.data.materials.append(mat_stone)

# Shaft
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 3.0))
shaft = bpy.context.active_object
shaft.scale = (1.6, 1.6, 4.0)
shaft.data.materials.append(mat_wood)

# Platform
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 5.2))
plat = bpy.context.active_object
plat.scale = (2.4, 2.4, 0.4)
plat.data.materials.append(mat_wood)

# Battlements
for bx in [-1.0, 1.0]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0, 5.7))
    b = bpy.context.active_object
    b.scale = (0.2, 2.4, 0.6)
    b.data.materials.append(mat_wood)
for by in [-1.0, 1.0]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, by, 5.7))
    b = bpy.context.active_object
    b.scale = (2.4, 0.2, 0.6)
    b.data.materials.append(mat_wood)

# Roof
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.8, depth=1.6, location=(0, 0, 6.8))
roof = bpy.context.active_object
roof.rotation_euler.z = math.radians(45)
roof.data.materials.append(mat_roof)

export_glb("watch_tower.glb")

# ==========================================
# 3. ARCHERY_RANGE.GLB (Trường bắn cung)
# ==========================================
reset_scene()
mat_wood = make_mat("Wood", (0.42, 0.26, 0.14, 1.0))
mat_thatch = make_mat("Thatch", (0.78, 0.65, 0.35, 1.0))
mat_target_straw = make_mat("Straw", (0.9, 0.8, 0.4, 1.0))
mat_target_red = make_mat("TargetRed", (0.9, 0.15, 0.15, 1.0))

# Shelter base
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.5, 0, 0.1))
base = bpy.context.active_object
base.scale = (3.0, 3.4, 0.2)
base.data.materials.append(mat_wood)

# 4 Pillars
for px in [-1.8, 0.8]:
    for py in [-1.5, 1.5]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=2.4, location=(px, py, 1.3))
        col = bpy.context.active_object
        col.data.materials.append(mat_wood)

# Thatched roof (slanted)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.5, 0, 2.7))
roof = bpy.context.active_object
roof.scale = (3.2, 3.6, 0.3)
roof.rotation_euler.y = math.radians(10)
roof.data.materials.append(mat_thatch)

# 2 Archery Targets
for ty in [-0.8, 0.8]:
    # Target stand
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=1.4, location=(1.5, ty, 0.7))
    stand = bpy.context.active_object
    stand.data.materials.append(mat_wood)
    # Target disc
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=0.12, location=(1.5, ty, 1.2))
    target = bpy.context.active_object
    target.rotation_euler.y = math.radians(90)
    target.data.materials.append(mat_target_straw)
    # Bullseye
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.14, location=(1.48, ty, 1.2))
    bull = bpy.context.active_object
    bull.rotation_euler.y = math.radians(90)
    bull.data.materials.append(mat_target_red)

export_glb("archery_range.glb")

# ==========================================
# 4. STABLE.GLB (Chuồng ngựa)
# ==========================================
reset_scene()
mat_wood = make_mat("DarkWood", (0.32, 0.20, 0.12, 1.0))
mat_hay = make_mat("Hay", (0.88, 0.75, 0.30, 1.0))
mat_shingle = make_mat("Shingle", (0.50, 0.25, 0.15, 1.0))

# Floor
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.1))
base = bpy.context.active_object
base.scale = (3.6, 3.6, 0.2)
base.data.materials.append(mat_wood)

# Main Barn Back & Sides
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.2, 0, 1.4))
back_wall = bpy.context.active_object
back_wall.scale = (0.3, 3.4, 2.4)
back_wall.data.materials.append(mat_wood)

# Stalls
for sy in [-1.0, 1.0]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.2, sy, 0.7))
    stall = bpy.context.active_object
    stall.scale = (2.2, 0.2, 1.2)
    stall.data.materials.append(mat_wood)

# Hay Trough
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 0, 0.5))
trough = bpy.context.active_object
trough.scale = (0.6, 2.8, 0.6)
trough.data.materials.append(mat_hay)

# Pitched Roof
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 2.9))
roof = bpy.context.active_object
roof.scale = (3.8, 3.8, 0.3)
roof.rotation_euler.x = math.radians(12)
roof.data.materials.append(mat_shingle)

export_glb("stable.glb")

# ==========================================
# 5. MARKET.GLB (Chợ thương mại)
# ==========================================
reset_scene()
mat_wood = make_mat("Wood", (0.45, 0.28, 0.16, 1.0))
mat_awning_red = make_mat("AwningRed", (0.85, 0.18, 0.18, 1.0))
mat_awning_white = make_mat("AwningWhite", (0.95, 0.95, 0.90, 1.0))
mat_gold_pots = make_mat("GoodsGold", (0.9, 0.75, 0.15, 1.0))

# Plaza base
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.1))
base = bpy.context.active_object
base.scale = (3.6, 3.6, 0.2)
base.data.materials.append(mat_wood)

# Stalls & Counters
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.7))
counter = bpy.context.active_object
counter.scale = (2.4, 2.4, 1.0)
counter.data.materials.append(mat_wood)

# Pillars for Canopy
for px in [-1.4, 1.4]:
    for py in [-1.4, 1.4]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=2.8, location=(px, py, 1.5))
        p = bpy.context.active_object
        p.data.materials.append(mat_wood)

# Striped Canopy Roof
for i in range(-3, 4):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(i * 0.45, 0, 2.8))
    stripe = bpy.context.active_object
    stripe.scale = (0.44, 3.2, 0.15)
    stripe.data.materials.append(mat_awning_red if (i % 2 == 0) else mat_awning_white)

# Goods on Counter
for gx in [-0.6, 0.6]:
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.4, location=(gx, 0.5, 1.4))
    pot = bpy.context.active_object
    pot.data.materials.append(mat_gold_pots)

export_glb("market.glb")

# ==========================================
# 6. TEMPLE.GLB (Đền thờ AoE 1 - Cột đá cẩm thạch)
# ==========================================
reset_scene()
mat_marble = make_mat("Marble", (0.92, 0.90, 0.88, 1.0), roughness=0.3)
mat_gold = make_mat("GoldTrim", (0.95, 0.80, 0.20, 1.0), roughness=0.2)
mat_fire = make_mat("FireAltar", (1.0, 0.4, 0.05, 1.0))

# Stepped Stone Plinth
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.2))
step1 = bpy.context.active_object
step1.scale = (4.0, 4.0, 0.4)
step1.data.materials.append(mat_marble)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
step2 = bpy.context.active_object
step2.scale = (3.6, 3.6, 0.3)
step2.data.materials.append(mat_marble)

# Classical Columns (8 Pillars)
col_positions = [
    (-1.4, -1.4), (0.0, -1.4), (1.4, -1.4),
    (-1.4,  1.4), (0.0,  1.4), (1.4,  1.4),
    (-1.4,  0.0), (1.4,  0.0)
]
for (cx, cy) in col_positions:
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=2.8, location=(cx, cy, 2.0))
    col = bpy.context.active_object
    col.data.materials.append(mat_marble)

# Entablature / Roof Beam
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 3.5))
beam = bpy.context.active_object
beam.scale = (3.8, 3.8, 0.4)
beam.data.materials.append(mat_gold)

# Triangular Pediment Roof
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=2.6, depth=1.2, location=(0, 0, 4.3))
roof = bpy.context.active_object
roof.rotation_euler.z = math.radians(45)
roof.data.materials.append(mat_marble)

# Center Golden Altar
bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=1.0, location=(0, 0, 1.2))
altar = bpy.context.active_object
altar.data.materials.append(mat_fire)

export_glb("temple.glb")

# ==========================================
# 7. SIEGE_WORKSHOP.GLB (Xưởng vũ khí công thành)
# ==========================================
reset_scene()
mat_dark_wood = make_mat("DarkWood", (0.30, 0.18, 0.10, 1.0))
mat_iron = make_mat("Iron", (0.25, 0.25, 0.28, 1.0))
mat_planks = make_mat("Planks", (0.50, 0.35, 0.20, 1.0))

# Heavy Base Platform
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.15))
base = bpy.context.active_object
base.scale = (4.0, 4.0, 0.3)
base.data.materials.append(mat_dark_wood)

# Main Workshop Frame
for fx in [-1.5, 1.5]:
    for fy in [-1.5, 1.5]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, fy, 1.6))
        col = bpy.context.active_object
        col.scale = (0.35, 0.35, 2.8)
        col.data.materials.append(mat_dark_wood)

# Crane Gantry & Hoist
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 3.1))
crossbeam = bpy.context.active_object
crossbeam.scale = (3.4, 0.4, 0.4)
crossbeam.data.materials.append(mat_dark_wood)

# Pulley & Chain
bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.3, location=(0, 0, 2.8))
pulley = bpy.context.active_object
pulley.rotation_euler.x = math.radians(90)
pulley.data.materials.append(mat_iron)

# Spare Catapult Wheels
for wx in [-1.0, 1.0]:
    bpy.ops.mesh.primitive_cylinder_add(radius=0.6, depth=0.2, location=(wx, 1.4, 0.8))
    wheel = bpy.context.active_object
    wheel.rotation_euler.x = math.radians(90)
    wheel.data.materials.append(mat_iron)

# Workbench
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.0, 0.7))
bench = bpy.context.active_object
bench.scale = (1.8, 0.8, 0.8)
bench.data.materials.append(mat_planks)

export_glb("siege_workshop.glb")

# ==========================================
# 8. CATAPULT.GLB (Xe bắn đá 3D model)
# ==========================================
reset_scene()
mat_wood = make_mat("CatapultWood", (0.40, 0.24, 0.14, 1.0))
mat_iron = make_mat("CatapultIron", (0.22, 0.22, 0.24, 1.0))
mat_rock = make_mat("StoneBoulder", (0.6, 0.6, 0.62, 1.0))

# Chassis Frame
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.5))
chassis = bpy.context.active_object
chassis.scale = (1.6, 2.4, 0.3)
chassis.data.materials.append(mat_wood)

# 4 Wheels
for wx in [-0.95, 0.95]:
    for wy in [-0.8, 0.8]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=0.2, location=(wx, wy, 0.45))
        wheel = bpy.context.active_object
        wheel.rotation_euler.y = math.radians(90)
        wheel.data.materials.append(mat_iron)

# Upright A-Frame
for ax in [-0.65, 0.65]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ax, 0.2, 1.3))
    aframe = bpy.context.active_object
    aframe.scale = (0.18, 0.3, 1.5)
    aframe.data.materials.append(mat_wood)

# Crossbar Axle
bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=1.6, location=(0, 0.2, 1.8))
axle = bpy.context.active_object
axle.rotation_euler.y = math.radians(90)
axle.data.materials.append(mat_iron)

# Throwing Arm (slanted)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.4, 1.8))
arm = bpy.context.active_object
arm.scale = (0.2, 2.8, 0.2)
arm.rotation_euler.x = math.radians(-35)
arm.data.materials.append(mat_wood)

# Counterweight Bucket
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.9, 1.1))
bucket = bpy.context.active_object
bucket.scale = (0.7, 0.7, 0.8)
bucket.data.materials.append(mat_iron)

# Throwing Cup & Rock
bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.2, location=(0, -1.4, 2.4))
cup = bpy.context.active_object
cup.data.materials.append(mat_wood)

bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, -1.4, 2.65))
boulder = bpy.context.active_object
boulder.data.materials.append(mat_rock)

export_glb("catapult.glb")

# ==========================================
# 9. SMALL_WALL.GLB (Tường đá Low-Poly có lỗ châu mai)
# ==========================================
reset_scene()
mat_stone = make_mat("WallStone", (0.55, 0.53, 0.50, 1.0), roughness=0.9)
mat_mortar = make_mat("WallMortar", (0.42, 0.40, 0.38, 1.0), roughness=0.95)

# Main Wall Body
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.8))
wall_body = bpy.context.active_object
wall_body.scale = (2.0, 0.7, 1.6)
wall_body.data.materials.append(mat_stone)

# Wall Base Foundation
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.15))
wall_base = bpy.context.active_object
wall_base.scale = (2.2, 0.9, 0.3)
wall_base.data.materials.append(mat_mortar)

# Battlements (Merlons on top)
for mx in [-0.75, 0.0, 0.75]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(mx, 0, 1.8))
    merlon = bpy.context.active_object
    merlon.scale = (0.35, 0.75, 0.4)
    merlon.data.materials.append(mat_stone)

# Wall Walkway trim
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.6))
trim = bpy.context.active_object
trim.scale = (2.05, 0.75, 0.1)
trim.data.materials.append(mat_mortar)

export_glb("small_wall.glb")

print("\n=== ALL 9 AOE MODELS SUCCESSFULLY GENERATED ===")
