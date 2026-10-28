import bpy
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh, do_unlink=True)

def create_mat(name, color_rgb, metallic=0.0, roughness=0.85):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color_rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat

def build_granary(output_path):
    clear_scene()
    print("Building Granary model...")

    mat_dark_wood = create_mat("DarkWood", (0.32, 0.20, 0.10))
    mat_plank_wood = create_mat("PlankWood", (0.58, 0.38, 0.22))
    mat_thatch = create_mat("ThatchRoof", (0.84, 0.70, 0.28))
    mat_silo_wicker = create_mat("SiloWicker", (0.68, 0.52, 0.32))
    mat_sack = create_mat("GrainSack", (0.86, 0.82, 0.72))
    mat_frame = create_mat("WoodFrame", (0.42, 0.28, 0.15))

    # 1. 4 cọc gỗ nâng sàn (Stilts)
    stilts = [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]
    for i, (sx, sz) in enumerate(stilts):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.6, vertices=6, location=(sx, sz, 0.3))
        o = bpy.context.active_object
        o.name = f"Stilt_{i}"
        o.data.materials.append(mat_dark_wood)

    # 2. Sàn gỗ nâng (Elevated Floor)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.65))
    floor = bpy.context.active_object
    floor.name = "Floor"
    floor.scale = (2.6, 2.6, 0.15)
    floor.data.materials.append(mat_plank_wood)

    # 3. Nhà chính (Main Cabin)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.25, -0.1, 1.45))
    cabin = bpy.context.active_object
    cabin.name = "Cabin"
    cabin.scale = (1.8, 1.8, 1.4)
    cabin.data.materials.append(mat_plank_wood)

    # Khung dầm gỗ quanh nóc cabin
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.25, -0.1, 2.15))
    beam = bpy.context.active_object
    beam.name = "RoofBeam"
    beam.scale = (1.95, 1.95, 0.12)
    beam.data.materials.append(mat_frame)

    # 4. Mái rơm chóp vát (Thatch Roof)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.75, radius2=0.0, depth=1.2, location=(-0.25, -0.1, 2.7))
    roof = bpy.context.active_object
    roof.name = "Roof"
    roof.rotation_euler.z = math.radians(45)
    roof.data.materials.append(mat_thatch)

    # 5. Silo thóc tròn nan tre bên cạnh (Grain Silo)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=1.2, vertices=8, location=(1.05, 0.5, 0.6))
    silo = bpy.context.active_object
    silo.name = "GrainSilo"
    silo.data.materials.append(mat_silo_wicker)

    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.62, radius2=0.0, depth=0.45, location=(1.05, 0.5, 1.42))
    silo_lid = bpy.context.active_object
    silo_lid.name = "SiloLid"
    silo_lid.data.materials.append(mat_thatch)

    # 6. Các bao tải thóc (Grain Sacks)
    sacks = [
        (0.95, -0.55, 0.15, (0.35, 0.28, 0.22), math.radians(15)),
        (0.65, -0.80, 0.15, (0.32, 0.30, 0.22), math.radians(-25)),
        (0.85, -0.68, 0.35, (0.30, 0.26, 0.20), math.radians(35))
    ]
    for i, (gx, gz, gy, sc, rot_z) in enumerate(sacks):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gx, gz, gy))
        sack = bpy.context.active_object
        sack.name = f"Sack_{i}"
        sack.scale = sc
        sack.rotation_euler.z = rot_z
        sack.data.materials.append(mat_sack)

    # 7. Bậc thang gỗ lên sàn (Wooden Steps)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.25, -1.35, 0.3))
    ramp = bpy.context.active_object
    ramp.name = "Ramp"
    ramp.scale = (0.75, 0.45, 0.3)
    ramp.rotation_euler.x = math.radians(-18)
    ramp.data.materials.append(mat_dark_wood)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
    print("Exported Granary successfully to:", output_path)

def build_storage_pit(output_path):
    clear_scene()
    print("Building Storage Pit model...")

    mat_ground = create_mat("GroundBase", (0.38, 0.30, 0.22), roughness=0.95)
    mat_log_bark = create_mat("LogBark", (0.34, 0.22, 0.12), roughness=0.9)
    mat_log_cut = create_mat("LogCut", (0.75, 0.58, 0.35), roughness=0.8)
    mat_gold_ore = create_mat("GoldOre", (0.95, 0.78, 0.15), metallic=0.75, roughness=0.35)
    mat_stone_ore = create_mat("StoneOre", (0.52, 0.55, 0.58), roughness=0.85)
    mat_iron_anvil = create_mat("IronAnvil", (0.20, 0.22, 0.25), metallic=0.9, roughness=0.4)
    mat_canopy_cloth = create_mat("CanopyCloth", (0.78, 0.68, 0.52), roughness=0.9)
    mat_post = create_mat("PostWood", (0.45, 0.30, 0.18), roughness=0.9)

    # 1. Nền kho đất nện / bãi tập kết (Packed Earth Yard)
    bpy.ops.mesh.primitive_cylinder_add(radius=2.0, depth=0.15, vertices=10, location=(0, 0, 0.075))
    ground = bpy.context.active_object
    ground.name = "Ground"
    ground.data.materials.append(mat_ground)

    # 2. Bãi gỗ súc (Log Pile)
    log_configs = [
        (-0.9, 0.4, 0.2, math.radians(90)),
        (-0.9, 0.8, 0.2, math.radians(90)),
        (-0.9, 1.2, 0.2, math.radians(90)),
        (-0.9, 0.6, 0.5, math.radians(90)),
        (-0.9, 1.0, 0.5, math.radians(90)),
    ]
    for i, (lx, lz, ly, rot_y) in enumerate(log_configs):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=1.6, vertices=8, location=(lx, lz, ly))
        log_obj = bpy.context.active_object
        log_obj.name = f"Log_{i}"
        log_obj.rotation_euler.x = math.radians(90)
        log_obj.data.materials.append(mat_log_bark)

    # 3. Đống quặng đá tảng (Stone Ore Pile)
    stone_configs = [
        (0.8, 0.9, 0.35, (0.5, 0.45, 0.4)),
        (1.2, 0.6, 0.28, (0.42, 0.4, 0.35)),
        (0.9, 0.4, 0.22, (0.35, 0.35, 0.3)),
    ]
    for i, (sx, sz, sy, sc) in enumerate(stone_configs):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(sx, sz, sy))
        stone = bpy.context.active_object
        stone.name = f"StoneOre_{i}"
        stone.scale = sc
        stone.data.materials.append(mat_stone_ore)

    # 4. Đống quặng vàng lấp lánh (Gold Ore Pile)
    gold_configs = [
        (1.0, -0.4, 0.32, (0.45, 0.45, 0.38)),
        (0.6, -0.7, 0.25, (0.38, 0.38, 0.32)),
        (1.1, -0.8, 0.20, (0.32, 0.32, 0.25)),
    ]
    for i, (gx, gz, gy, sc) in enumerate(gold_configs):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.55, location=(gx, gz, gy))
        gold = bpy.context.active_object
        gold.name = f"GoldOre_{i}"
        gold.scale = sc
        gold.data.materials.append(mat_gold_ore)

    # 5. Khu nâng cấp vũ khí/giáp: Đe rèn trên gốc cây (Blacksmith Anvil & Stump)
    # Gốc cây
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.6, vertices=8, location=(-0.3, -0.7, 0.3))
    stump = bpy.context.active_object
    stump.name = "AnvilStump"
    stump.data.materials.append(mat_log_cut)

    # Đe rèn sắt
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.3, -0.7, 0.72))
    anvil = bpy.context.active_object
    anvil.name = "Anvil"
    anvil.scale = (0.55, 0.25, 0.22)
    anvil.data.materials.append(mat_iron_anvil)

    # Mũi nhọn đe rèn
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.2, radius2=0.0, depth=0.3, location=(-0.62, -0.7, 0.72))
    horn = bpy.context.active_object
    horn.name = "AnvilHorn"
    horn.rotation_euler.y = math.radians(90)
    horn.data.materials.append(mat_iron_anvil)

    # 6. Mái che hở (Lean-to Shelter) trên 4 cột gỗ
    posts = [(-1.2, -1.2), (0.2, -1.2), (-1.2, 0.0), (0.2, 0.0)]
    for i, (px, pz) in enumerate(posts):
        h = 1.9 if pz < -0.5 else 1.6
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=h, vertices=6, location=(px, pz, h / 2.0))
        post = bpy.context.active_object
        post.name = f"ShelterPost_{i}"
        post.data.materials.append(mat_post)

    # Mái che bạt dốc
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.5, -0.6, 1.85))
    canopy = bpy.context.active_object
    canopy.name = "Canopy"
    canopy.scale = (1.7, 1.5, 0.08)
    canopy.rotation_euler.x = math.radians(12)
    canopy.data.materials.append(mat_canopy_cloth)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
    print("Exported Storage Pit successfully to:", output_path)

if __name__ == "__main__":
    base_dir = "C:/Users/nguye/Godot_v4.7.2-stable_win64.exe/git/Age-of-Low-Poly/assets/models"
    build_granary(os.path.join(base_dir, "granary.glb"))
    build_storage_pit(os.path.join(base_dir, "storage_pit.glb"))
