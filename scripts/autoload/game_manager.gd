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

func _ready() -> void:
	# Khởi tạo mặc định cho singleplayer / test chạy thẳng scene
	init_player(1)
	await get_tree().process_frame
	recalculate_max_pop(1)

func init_player(peer_id: int) -> void:
	if player_resources.has(peer_id):
		return
	player_resources[peer_id] = {
		ResourceSource.ResourceType.FOOD: 200,
		ResourceSource.ResourceType.WOOD: 200,
		ResourceSource.ResourceType.GOLD: 100,
		ResourceSource.ResourceType.STONE: 0,
	}
	player_population[peer_id] = {
		"current": 3,
		"max": 10,
	}

func add_resource(peer_id: int, res_type: int, amount: int) -> void:
	if not player_resources.has(peer_id):
		init_player(peer_id)
	player_resources[peer_id][res_type] += amount
	print("[GameManager] Resource added: peer_id=", peer_id, " type=", res_type, " amount=", amount, " new_total=", player_resources[peer_id][res_type])
	resource_updated.emit(peer_id, res_type, player_resources[peer_id][res_type])

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
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
		var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		if my_id != 1 and (peer_id == 1 or peer_id == my_id):
			var other_id := my_id if peer_id == 1 else 1
			if not player_resources.has(other_id):
				init_player(other_id)
			player_resources[other_id][res_type] = player_resources[peer_id][res_type]
			resource_updated.emit(other_id, res_type, player_resources[other_id][res_type])
		return true
	return false

func get_resource(peer_id: int, res_type: int) -> int:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
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
