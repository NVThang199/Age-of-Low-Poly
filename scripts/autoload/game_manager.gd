extends Node

## Autoload: GameManager
## Quản lý tài nguyên người chơi, giới hạn dân số và điều kiện thắng thua.

signal resource_updated(peer_id: int, res_type: int, new_total: int)
signal population_updated(peer_id: int, current_pop: int, max_pop: int)
@warning_ignore("unused_signal")
signal game_ended(winner_peer_id: int)

# Lưu trữ tài nguyên của từng Peer ID
# { peer_id: { FOOD: int, WOOD: int, GOLD: int, STONE: int } }
var player_resources: Dictionary = {}
var player_population: Dictionary = {}

# Cấu hình trận đấu được chọn từ Lobby theo yêu cầu AoE 1
enum MapVisibility {
	NORMAL_FOG = 0,   # Đen toàn bộ (Fog of War tiêu chuẩn AoE 1)
	EXPLORED = 1,     # Đã mở toàn bộ địa hình và mỏ, ẩn quân địch
	ALL_VISIBLE = 2   # Sáng toàn bản đồ (Marco Polo / All Visible)
}

var selected_map_type: int = 4 # HIGHLAND
var selected_map_size: int = 2 # MEDIUM (180x180)
var selected_map_visibility: int = MapVisibility.NORMAL_FOG
var selected_map_seed: int = 0
var selected_player_count: int = 2
var selected_starting_age: int = 0 # 0=Stone, 1=Tool, 2=Bronze, 3=Iron
var selected_starting_resources_preset: int = 0 # 0=Default, 1=Medium, 2=High, 3=Deathmatch

func _ready() -> void:
	# Khởi tạo mặc định cho singleplayer / test chạy thẳng scene
	init_player(1)
	if is_inside_tree() and get_tree():
		await get_tree().process_frame
		recalculate_max_pop(1)

func _get_local_peer_id() -> int:
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func init_player(peer_id: int) -> void:
	var f := 200
	var w := 200
	var g := 100
	var s := 0

	match selected_starting_resources_preset:
		1: # Medium
			f = 500; w = 500; g = 300; s = 150
		2: # High
			f = 1000; w = 1000; g = 1000; s = 1000
		3: # Deathmatch
			f = 20000; w = 20000; g = 10000; s = 5000
		_: # Default AoE 1
			f = 200; w = 200; g = 100; s = 0

	player_resources[peer_id] = {
		ResourceSource.ResourceType.FOOD: f,
		ResourceSource.ResourceType.WOOD: w,
		ResourceSource.ResourceType.GOLD: g,
		ResourceSource.ResourceType.STONE: s,
	}
	player_population[peer_id] = {
		"current": 3,
		"max": 10,
	}

func reset_match_resources() -> void:
	for pid in player_resources.keys():
		init_player(pid)
		for res_type in player_resources[pid].keys():
			resource_updated.emit(pid, res_type, player_resources[pid][res_type])

func add_resource(peer_id: int, res_type: int, amount: int) -> void:
	if not player_resources.has(peer_id):
		init_player(peer_id)
	player_resources[peer_id][res_type] += amount
	print("[GameManager] Resource added: peer_id=", peer_id, " type=", res_type, " amount=", amount, " new_total=", player_resources[peer_id][res_type])
	resource_updated.emit(peer_id, res_type, player_resources[peer_id][res_type])

	var my_id := _get_local_peer_id()
	if my_id != 1 and (peer_id == 1 or peer_id == my_id):
		var other_id := my_id if peer_id == 1 else 1
		if not player_resources.has(other_id):
			init_player(other_id)
		player_resources[other_id][res_type] = player_resources[peer_id][res_type]
		resource_updated.emit(other_id, res_type, player_resources[other_id][res_type])

func spend_resource(peer_id: int, res_type: int, amount: int) -> bool:
	if not player_resources.has(peer_id):
		init_player(peer_id)
	if player_resources[peer_id][res_type] >= amount:
		player_resources[peer_id][res_type] -= amount
		resource_updated.emit(peer_id, res_type, player_resources[peer_id][res_type])
		var my_id := _get_local_peer_id()
		if my_id != 1 and (peer_id == 1 or peer_id == my_id):
			var other_id := my_id if peer_id == 1 else 1
			if not player_resources.has(other_id):
				init_player(other_id)
			player_resources[other_id][res_type] = player_resources[peer_id][res_type]
			resource_updated.emit(other_id, res_type, player_resources[other_id][res_type])
		return true
	return false

func get_resource(peer_id: int, res_type: int) -> int:
	var my_id := _get_local_peer_id()
	var target_id := peer_id
	if not player_resources.has(target_id):
		if target_id == 1 and player_resources.has(my_id):
			target_id = my_id
		elif target_id == my_id and player_resources.has(1):
			target_id = 1
		else:
			init_player(target_id)
	return player_resources[target_id].get(res_type, 0)

func recalculate_max_pop(peer_id: int) -> void:
	var total_max: int = 5 # Cơ bản từ Town Center
	var buildings := get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if "owner_peer_id" in b and b.owner_peer_id == peer_id and "is_constructed" in b and b.is_constructed:
			if "pop_bonus" in b:
				total_max += b.pop_bonus
	total_max = mini(50, total_max) # Hard cap 50 cho MVP
	if not player_population.has(peer_id):
		init_player(peer_id)
	player_population[peer_id]["max"] = total_max
	population_updated.emit(peer_id, player_population[peer_id]["current"], total_max)
