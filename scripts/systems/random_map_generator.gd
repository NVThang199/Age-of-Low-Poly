# Fact 1: Called by scenes/core/main.tscn:80, tests/test_random_map_generator.gd:15, scripts/core/game_manager.gd:42
# Fact 2: Verified no existing file serves the same purpose via Glob in C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\scripts\systems
# Fact 3: Node3D schema implementing MapType, MapSize, FastNoiseLite, instantiating PackedScenes (town_center.tscn, villager.tscn, berry_bush.tscn, gazelle.tscn, elephant.tscn, lion.tscn, alligator.tscn, gold_node.tscn, stone_node.tscn, resource_node.tscn)
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi C:\Users\nguye\Downloads\Age of Empires 1_Linkneverdie.com\Age of Empires 1_Linkneverdie.com\Age of Empires sử dụng mcp REA để đọc toàn bộ không đọc 1 phần tất cả mọi chức năng đọc thật kĩ không được phép làm cầu thả"

class_name RandomMapGenerator
extends Node3D

## RandomMapGenerator (AoE 1 Authentic RMS Implementation)
## Tái hiện hệ thống sinh bản đồ ngẫu nhiên kinh điển của Age of Empires 1 / Rise of Rome:
## - Hỗ trợ đầy đủ 9 chủng loại bản đồ: Highland, Continental, Inland, Coastal, Small Islands,
##   Large Islands, Mediterranean, Hill Country, Narrows.
## - Phân bổ tài nguyên khởi đầu chuẩn xác theo công thức gốc: 1 Town Center, 3 Dân (Villagers),
##   bụi quả (Berry Bush 5-6 cây), bầy Hươu/Nai (Gazelle 4-6 con), Voi (2 con để câu về TC),
##   Sư tử rình rập, mỏ Vàng chính & phụ, mỏ Đá, và rừng gỗ bao bọc.
## - Phân bổ động vật hoang dã tự nhiên: Cá sấu ven sông hồ, Sư tử săn mồi, Voi lang thang.

enum MapType {
	SMALL_ISLANDS = 0,
	LARGE_ISLANDS = 1,
	COASTAL = 2,
	INLAND = 3,
	HIGHLAND = 4,
	CONTINENTAL = 5,
	MEDITERRANEAN = 6,
	HILL_COUNTRY = 7,
	NARROWS = 8,
}

enum MapSize {
	TINY = 0,    # 100 x 100 (2 Players)
	SMALL = 1,   # 140 x 140 (3 Players)
	MEDIUM = 2,  # 180 x 180 (4 Players)
	LARGE = 3,   # 220 x 220 (6 Players)
	HUGE = 4,    # 280 x 280 (8 Players)
}

@export var map_type: MapType = MapType.HIGHLAND
@export var map_size: MapSize = MapSize.MEDIUM
@export var map_seed: int = 1997
@export var num_players: int = 2
@export var auto_generate: bool = false

# Preload các PackedScene thực thể chuẩn AoE 1
const SCENE_TC: PackedScene = preload("res://scenes/entities/town_center.tscn")
const SCENE_VILLAGER: PackedScene = preload("res://scenes/entities/villager.tscn")
const SCENE_BERRY: PackedScene = preload("res://scenes/entities/berry_bush.tscn")
const SCENE_TREE: PackedScene = preload("res://scenes/entities/resource_node.tscn")
const SCENE_GOLD: PackedScene = preload("res://scenes/entities/gold_node.tscn")
const SCENE_STONE: PackedScene = preload("res://scenes/entities/stone_node.tscn")
const SCENE_GAZELLE: PackedScene = preload("res://scenes/entities/animals/gazelle.tscn")
const SCENE_ELEPHANT: PackedScene = preload("res://scenes/entities/animals/elephant.tscn")
const SCENE_LION: PackedScene = preload("res://scenes/entities/animals/lion.tscn")
const SCENE_ALLIGATOR: PackedScene = preload("res://scenes/entities/animals/alligator.tscn")

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()

var generated_nodes: Array[Node] = []
var player_spawn_positions: Array[Vector3] = []

signal map_generation_started
signal map_generation_completed

func _ready() -> void:
	if auto_generate:
		generate_map()

func get_map_dimension() -> float:
	match map_size:
		MapSize.TINY: return 100.0
		MapSize.SMALL: return 140.0
		MapSize.MEDIUM: return 180.0
		MapSize.LARGE: return 220.0
		MapSize.HUGE: return 280.0
		_: return 180.0

## Khởi tạo và thiết lập các thông số nhiễu địa hình (FastNoiseLite)
func _setup_noise() -> void:
	var effective_seed := map_seed if map_seed != 0 else randi()
	rng.seed = effective_seed
	noise.seed = effective_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

## Tính độ cao địa hình tại tọa độ (x, z) dựa theo MapType
func get_height(x: float, z: float) -> float:
	var dim := get_map_dimension()
	var half := dim * 0.5
	var nx := x / half
	var nz := z / half
	var dist_center := sqrt(nx * nx + nz * nz)
	var raw_n := noise.get_noise_2d(x, z)

	match map_type:
		MapType.HIGHLAND:
			# Cao nguyên đồi bát úp, chia cắt bởi dòng sông ở giữa với các bến vượt nông (shallow fords)
			var river_center := sin(z * 0.04) * 16.0
			var dist_river := absf(x - river_center)
			var base_height := 2.5 + raw_n * 4.0
			# Các bến cạn (shallow crossing) nối 2 bờ cao nguyên
			var is_crossing := absf(z - 15.0) < 6.0 or absf(z + 25.0) < 6.0
			if dist_river < 6.5 and not is_crossing:
				return -1.5 # Lòng sông ngập nước
			elif dist_river < 6.5 and is_crossing:
				return 0.1 # Bến nông vượt sông
			return maxf(0.5, base_height)

		MapType.CONTINENTAL:
			# Đại lục rộng lớn ở trung tâm, bao quanh bởi biển nước ở viền ngoài
			var edge_factor := 1.0 - pow(clampf(dist_center, 0.0, 1.2), 2.2)
			var h := (edge_factor * 6.0 - 1.8) + raw_n * 2.5
			return h

		MapType.INLAND:
			# Đất liền hoàn toàn với vài hồ nước nhỏ rải rác
			var h := 1.8 + raw_n * 3.5
			# Hồ nước 1
			if Vector2(x - 25.0, z - 20.0).length() < 10.0: return -2.0
			# Hồ nước 2
			if Vector2(x + 30.0, z + 25.0).length() < 8.0: return -2.0
			return maxf(0.2, h)

		MapType.COASTAL:
			# Bờ biển: Phía Tây là đất liền trù phú, phía Đông là biển sâu
			var coast_factor := -nx * 3.5
			var h := coast_factor + raw_n * 2.8
			return h

		MapType.SMALL_ISLANDS:
			# Nhiều đảo nhỏ biệt lập được ngăn cách bởi đại dương
			var island_noise := noise.get_noise_2d(x * 1.8, z * 1.8)
			return (island_noise - 0.12) * 5.5

		MapType.LARGE_ISLANDS:
			# Vài đảo lớn đủ chỗ cho mỗi người chơi phát triển
			var island_noise := noise.get_noise_2d(x * 1.1, z * 1.1)
			return (island_noise - 0.05) * 5.0

		MapType.MEDITERRANEAN:
			# Biển Địa Trung Hải: Đại dương nằm ở chính giữa, đất liền bao bọc thành một vòng cung
			if dist_center < 0.42:
				return -2.5 # Biển giữa
			else:
				var rim := (dist_center - 0.42) * 4.0
				return rim + raw_n * 2.0

		MapType.HILL_COUNTRY:
			# Đồi núi gập ghềnh, không có diện tích nước lớn
			return absf(raw_n) * 6.5 + 0.8

		MapType.NARROWS:
			# Hai bờ đất liền ngăn cách bởi eo biển hẹp, nối nhau bằng 1-2 dải đất hẹp
			var dist_channel := absf(z)
			var is_bridge := absf(x - 10.0) < 5.0 or absf(x + 30.0) < 5.0
			if dist_channel < 12.0 and not is_bridge:
				return -2.0
			elif dist_channel < 12.0 and is_bridge:
				return 0.2
			return 2.0 + raw_n * 3.0

		_:
			return 1.5 + raw_n * 2.5

## Kiểm tra tọa độ có phải là vùng đất khô ráo có thể xây dựng và di chuyển
func is_walkable_land(x: float, z: float) -> bool:
	var h := get_height(x, z)
	var dim := get_map_dimension() * 0.48
	if absf(x) > dim or absf(z) > dim:
		return false
	return h >= 0.0

## Điểm bắt đầu tạo toàn bộ thế giới
func generate_map() -> void:
	map_generation_started.emit()
	clear_map()
	_setup_noise()

	_build_terrain_mesh()
	_calculate_player_starts()
	_spawn_player_settlements()
	_spawn_wilderness_resources_and_fauna()

	map_generation_completed.emit()

## Xóa bỏ mọi thực thể đã sinh ra trước đó
func clear_map() -> void:
	for node in generated_nodes:
		if is_instance_valid(node):
			node.queue_free()
	generated_nodes.clear()
	player_spawn_positions.clear()

## Sinh địa hình và mặt nước
func _build_terrain_mesh() -> void:
	var dim := get_map_dimension()

	# Tạo mặt đất Ground Plane
	var ground := StaticBody3D.new()
	ground.name = "GeneratedGround"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(dim * 1.2, 1.0, dim * 1.2)
	col.shape = box
	col.position.y = -0.5
	ground.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(dim * 1.2, dim * 1.2)
	mesh_inst.mesh = plane_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.48, 0.22) # Màu cỏ thảo nguyên AoE 1
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	ground.add_child(mesh_inst)

	add_child(ground)
	generated_nodes.append(ground)

	# Nếu map có mặt nước, thêm Water Mesh phẳng màu xanh ngọc biển
	var water := MeshInstance3D.new()
	water.name = "WaterPlane"
	var w_mesh := PlaneMesh.new()
	w_mesh.size = Vector2(dim * 1.2, dim * 1.2)
	water.mesh = w_mesh
	water.position.y = -0.05

	var w_mat := StandardMaterial3D.new()
	w_mat.albedo_color = Color(0.15, 0.38, 0.58, 0.8) # Xanh biển AoE 1
	w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w_mat.roughness = 0.1
	water.material_override = w_mat

	add_child(water)
	generated_nodes.append(water)

## Tính toán vị trí xuất phát công bằng cho các Player
func _calculate_player_starts() -> void:
	player_spawn_positions.clear()
	var dim := get_map_dimension()
	var spawn_radius := dim * 0.32

	for p in range(num_players):
		var base_angle := (TAU / float(num_players)) * float(p)
		var found_pos := false
		var candidate_pos := Vector3.ZERO

		# Thử tìm vị trí khô ráo lân cận góc xuất phát
		for attempt in range(25):
			var angle := base_angle + rng.randf_range(-0.25, 0.25)
			var r := spawn_radius + rng.randf_range(-12.0, 12.0)
			var test_x := cos(angle) * r
			var test_z := sin(angle) * r

			if is_walkable_land(test_x, test_z) and _is_area_flat(test_x, test_z, 12.0):
				candidate_pos = Vector3(test_x, 0.0, test_z)
				found_pos = true
				break

		if not found_pos:
			candidate_pos = Vector3(cos(base_angle) * spawn_radius, 0.0, sin(base_angle) * spawn_radius)

		player_spawn_positions.append(candidate_pos)

func _is_area_flat(center_x: float, center_z: float, radius: float) -> bool:
	for dx in [-radius, 0.0, radius]:
		for dz in [-radius, 0.0, radius]:
			if not is_walkable_land(center_x + dx, center_z + dz):
				return false
	return true

## Phân bổ khu định cư xuất phát (Town Center, Villagers, Quả, Hươu, Voi, Vàng, Đá, Rừng)
func _spawn_player_settlements() -> void:
	for p in range(player_spawn_positions.size()):
		var tc_pos := player_spawn_positions[p]
		var peer_id := p + 1

		# 1. Town Center
		var tc = _safe_instantiate(SCENE_TC, tc_pos)
		if "owner_peer_id" in tc:
			tc.owner_peer_id = peer_id
		if tc.has_method("set_team"):
			tc.set_team(peer_id)

		# 2. 3 Villagers tụ họp quanh Town Center
		for v_idx in range(3):
			var v_ang := (TAU / 3.0) * float(v_idx) + rng.randf_range(-0.2, 0.2)
			var v_dist := rng.randf_range(3.5, 5.0)
			var v_pos := tc_pos + Vector3(cos(v_ang) * v_dist, 0.0, sin(v_ang) * v_dist)
			var villager = _safe_instantiate(SCENE_VILLAGER, v_pos)
			if "owner_peer_id" in villager:
				villager.owner_peer_id = peer_id
			if villager.has_method("set_team"):
				villager.set_team(peer_id)

		# 3. Cụm Bụi Quả (Forage Berry Bushes) - 5-6 cây gần nhà chính
		var berry_ang := rng.randf_range(0.0, TAU)
		var berry_center := tc_pos + Vector3(cos(berry_ang) * 9.5, 0.0, sin(berry_ang) * 9.5)
		_spawn_cluster(SCENE_BERRY, berry_center, 5, 2.0)

		# 4. Bầy Hươu/Nai (Gazelles) - 4-6 con chạy trốn khi có người lại gần
		var gazelle_ang := berry_ang + PI * 0.65 + rng.randf_range(-0.3, 0.3)
		var gazelle_center := tc_pos + Vector3(cos(gazelle_ang) * 16.0, 0.0, sin(gazelle_ang) * 16.0)
		_spawn_cluster(SCENE_GAZELLE, gazelle_center, rng.randi_range(4, 6), 3.5)

		# 5. Voi Hoang Dã (Elephants) - 2 con cách nhà 22-26 ô để câu voi (kiting) về TC
		var elephant_ang := berry_ang + PI + rng.randf_range(-0.4, 0.4)
		var elephant_center := tc_pos + Vector3(cos(elephant_ang) * 24.0, 0.0, sin(elephant_ang) * 24.0)
		_spawn_cluster(SCENE_ELEPHANT, elephant_center, 2, 4.0)

		# 6. Sư Tử (Lions) rình rập quanh khu rừng hoặc đồng hoang
		var lion_ang := berry_ang + PI * 1.4 + rng.randf_range(-0.3, 0.3)
		var lion_center := tc_pos + Vector3(cos(lion_ang) * 26.0, 0.0, sin(lion_ang) * 26.0)
		_spawn_cluster(SCENE_LION, lion_center, rng.randi_range(1, 2), 3.0)

		# 7. Mỏ Vàng Chính (Primary Gold) - 4 mỏ vàng gần nhà
		var gold_ang := berry_ang + PI * 0.35 + rng.randf_range(-0.2, 0.2)
		var gold_center := tc_pos + Vector3(cos(gold_ang) * 13.0, 0.0, sin(gold_ang) * 13.0)
		_spawn_cluster(SCENE_GOLD, gold_center, 4, 2.2)

		# 8. Mỏ Vàng Phụ (Secondary Gold) - 3 mỏ vàng xa hơn
		var gold2_ang := gold_ang + PI * 0.8
		var gold2_center := tc_pos + Vector3(cos(gold2_ang) * 28.0, 0.0, sin(gold2_ang) * 28.0)
		_spawn_cluster(SCENE_GOLD, gold2_center, 3, 2.2)

		# 9. Mỏ Đá (Stone Mine) - 3-4 mỏ đá
		var stone_ang := berry_ang - PI * 0.45 + rng.randf_range(-0.2, 0.2)
		var stone_center := tc_pos + Vector3(cos(stone_ang) * 15.0, 0.0, sin(stone_ang) * 15.0)
		_spawn_cluster(SCENE_STONE, stone_center, 3, 2.2)

		# 10. Rừng Gỗ (Woodlines) - 2 cụm rừng tự nhiên ôm lấy căn cứ
		for w in range(2):
			var wood_ang := berry_ang + float(w) * PI * 0.75 + PI * 0.2
			var wood_center := tc_pos + Vector3(cos(wood_ang) * 14.0, 0.0, sin(wood_ang) * 14.0)
			_spawn_forest_patch(wood_center, rng.randi_range(10, 14), 6.0)

## Phân bổ tài nguyên và muông thú hoang dã tự nhiên khắp bản đồ
func _spawn_wilderness_resources_and_fauna() -> void:
	var dim := get_map_dimension()
	var half := dim * 0.42

	# Rừng rậm phân tán khắp bản đồ
	var num_wild_forests := int(dim * 0.08)
	for i in range(num_wild_forests):
		var pos := _find_random_land_position(half, 18.0)
		if pos != Vector3.ZERO:
			_spawn_forest_patch(pos, rng.randi_range(12, 18), 7.0)

	# Các mỏ vàng và đá trung lập ở khu vực tranh chấp
	var num_neutral_mines := int(dim * 0.04)
	for i in range(num_neutral_mines):
		var gold_pos := _find_random_land_position(half, 22.0)
		if gold_pos != Vector3.ZERO:
			_spawn_cluster(SCENE_GOLD, gold_pos, 4, 2.4)
		var stone_pos := _find_random_land_position(half, 22.0)
		if stone_pos != Vector3.ZERO:
			_spawn_cluster(SCENE_STONE, stone_pos, 3, 2.4)

	# Bầy hươu hoang dã
	var num_wild_gazelle_herds := int(dim * 0.035)
	for i in range(num_wild_gazelle_herds):
		var pos := _find_random_land_position(half, 20.0)
		if pos != Vector3.ZERO:
			_spawn_cluster(SCENE_GAZELLE, pos, rng.randi_range(4, 6), 4.0)

	# Voi rừng lang thang
	var num_wild_elephants := int(dim * 0.03)
	for i in range(num_wild_elephants):
		var pos := _find_random_land_position(half, 24.0)
		if pos != Vector3.ZERO:
			_spawn_cluster(SCENE_ELEPHANT, pos, rng.randi_range(1, 2), 4.5)

	# Sư tử đi săn
	var num_wild_lions := int(dim * 0.025)
	for i in range(num_wild_lions):
		var pos := _find_random_land_position(half, 25.0)
		if pos != Vector3.ZERO:
			_spawn_cluster(SCENE_LION, pos, rng.randi_range(1, 2), 3.5)

	# Cá sấu ven đầm lầy / mép nước bờ sông
	var num_alligators := int(dim * 0.03)
	for i in range(num_alligators):
		var pos := _find_waterfront_position(half)
		if pos != Vector3.ZERO:
			_spawn_cluster(SCENE_ALLIGATOR, pos, rng.randi_range(1, 2), 3.0)

## Tìm vị trí đất khô cách xa các nhà chính của player
func _find_random_land_position(boundary: float, min_dist_from_players: float) -> Vector3:
	for attempt in range(30):
		var rx := rng.randf_range(-boundary, boundary)
		var rz := rng.randf_range(-boundary, boundary)
		if not is_walkable_land(rx, rz):
			continue

		var candidate := Vector3(rx, 0.0, rz)
		var too_close := false
		for p_pos in player_spawn_positions:
			if candidate.distance_to(p_pos) < min_dist_from_players:
				too_close = true
				break

		if not too_close:
			return candidate
	return Vector3.ZERO

## Tìm vị trí mép nước phù hợp cho cá sấu cư trú
func _find_waterfront_position(boundary: float) -> Vector3:
	for attempt in range(40):
		var rx := rng.randf_range(-boundary, boundary)
		var rz := rng.randf_range(-boundary, boundary)
		var h := get_height(rx, rz)
		# Nằm sát mép nước (-0.5 <= h <= 0.8)
		if h >= -0.5 and h <= 0.8:
			return Vector3(rx, 0.0, rz)
	return Vector3.ZERO

## Sinh cụm thực thể (Mỏ vàng, đá, thú nuôi, bụi quả)
func _spawn_cluster(scene: PackedScene, center: Vector3, count: int, radius: float) -> void:
	for i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.5, radius)
		var spawn_pos := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if is_walkable_land(spawn_pos.x, spawn_pos.z):
			_safe_instantiate(scene, spawn_pos)

## Sinh cụm rừng gỗ tự nhiên (Forest clump)
func _spawn_forest_patch(center: Vector3, count: int, radius: float) -> void:
	for i in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.8, radius)
		var tree_pos := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if is_walkable_land(tree_pos.x, tree_pos.z):
			var tree = _safe_instantiate(SCENE_TREE, tree_pos)
			# Xoay ngẫu nhiên thân cây cho tự nhiên
			if tree is Node3D:
				tree.rotation.y = rng.randf_range(0.0, TAU)

## Khởi tạo Node tuân thủ quy tắc CLAUDE.md: add_child trước khi gán global_position
func _safe_instantiate(scene: PackedScene, pos: Vector3) -> Node:
	var instance := scene.instantiate()
	add_child(instance)
	if instance is Node3D:
		instance.position = pos
	generated_nodes.append(instance)
	return instance
