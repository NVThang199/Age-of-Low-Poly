# Fact 1: Called by scripts/entities/base_unit.gd:370, project.godot autoload
# Fact 2: Verified tech manager structure via Grep in scripts/autoload/tech_manager.gd
# Fact 3: In-memory only; manages tech tree and age progression
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

class_name TechManagerNode
extends Node

## Autoload: TechManager
## Quản lý catalog công nghệ AoE 1, trạng thái nghiên cứu theo peer_id,
## cache stat modifiers và đồng bộ RPC Host-Authoritative.

signal tech_completed(peer_id: int, tech_id: String)
signal building_unlocked(peer_id: int, building_type: String)
signal age_advanced(peer_id: int, new_age: int)

enum Age {
	STONE_AGE = 0,
	TOOL_AGE = 1,
	BRONZE_AGE = 2,
	IRON_AGE = 3,
}

const TECH_DATABASE: Dictionary = {
	# Town Center (Lên Đời - 4 Kỷ Nguyên)
	"tool_age": {
		"name": "Tool Age",
		"building": "town_center",
		"cost": { ResourceSource.ResourceType.FOOD: 500 },
		"research_time": 40.0,
		"description": "Advance to Tool Age (Đời 2)",
		"effects": [
			{ "target": "advance_age", "age": Age.TOOL_AGE },
			{ "target": "unlock_building", "building_type": "archery_range" },
			{ "target": "unlock_building", "building_type": "stable" },
			{ "target": "unlock_building", "building_type": "market" },
			{ "target": "unlock_building", "building_type": "farm" }
		]
	},
	"bronze_age": {
		"name": "Bronze Age",
		"building": "town_center",
		"cost": { ResourceSource.ResourceType.FOOD: 800 },
		"research_time": 50.0,
		"description": "Advance to Bronze Age (Đời 3)",
		"effects": [
			{ "target": "advance_age", "age": Age.BRONZE_AGE },
			{ "target": "unlock_building", "building_type": "temple" },
			{ "target": "unlock_building", "building_type": "siege_workshop" },
			{ "target": "unlock_building", "building_type": "academy" },
			{ "target": "unlock_building", "building_type": "government_center" }
		]
	},
	"iron_age": {
		"name": "Iron Age",
		"building": "town_center",
		"cost": { ResourceSource.ResourceType.FOOD: 1000, ResourceSource.ResourceType.GOLD: 800 },
		"research_time": 60.0,
		"description": "Advance to Iron Age (Đời 4)",
		"effects": [
			{ "target": "advance_age", "age": Age.IRON_AGE }
		]
	},
	# Nâng cấp quân sự & kinh tế
	"axeman": {
		"name": "Axeman Upgrade",
		"building": "barracks",
		"cost": { ResourceSource.ResourceType.FOOD: 100 },
		"research_time": 25.0,
		"description": "+5 HP & +2 Melee Attack for Infantry",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.INFANTRY], "stat": "melee_attack", "value": 2 },
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.INFANTRY], "stat": "max_hp", "value": 5 }
		]
	},
	"woodworking": {
		"name": "Woodworking",
		"building": "market",
		"cost": { ResourceSource.ResourceType.FOOD: 120, ResourceSource.ResourceType.WOOD: 75 },
		"research_time": 30.0,
		"description": "+2 Villager carry capacity, +1 Archer range",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.ARCHER], "stat": "attack_range", "value": 1 }
		]
	},
	"astrology": {
		"name": "Astrology",
		"building": "temple",
		"cost": { ResourceSource.ResourceType.FOOD: 100, ResourceSource.ResourceType.GOLD: 150 },
		"research_time": 35.0,
		"description": "+30% Priest conversion speed",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.PRIEST], "stat": "conversion_rate", "value": 30 }
		]
	},
	"engineering": {
		"name": "Engineering",
		"building": "siege_workshop",
		"cost": { ResourceSource.ResourceType.WOOD: 200, ResourceSource.ResourceType.GOLD: 100 },
		"research_time": 40.0,
		"description": "+2 Siege Catapult attack range",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.SIEGE], "stat": "attack_range", "value": 2 }
		]
	},
	# Storage Pit (BM)
	"toolworking": {
		"name": "Toolworking",
		"building": "storage_pit",
		"cost": { ResourceSource.ResourceType.FOOD: 100 },
		"research_time": 30.0,
		"description": "+2 Melee Attack for Infantry & Villagers",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.INFANTRY, BaseUnit.UnitType.VILLAGER], "stat": "melee_attack", "value": 2 }
		]
	},
	"leather_armor_infantry": {
		"name": "Leather Armor (Infantry)",
		"building": "storage_pit",
		"cost": { ResourceSource.ResourceType.FOOD: 75 },
		"research_time": 25.0,
		"description": "+2 Melee Armor for Infantry",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.INFANTRY], "stat": "melee_armor", "value": 2 }
		]
	},
	"bronze_shield": {
		"name": "Bronze Shield",
		"building": "storage_pit",
		"cost": { ResourceSource.ResourceType.FOOD: 150 },
		"research_time": 30.0,
		"description": "+1 Pierce Armor for Infantry & Villagers",
		"effects": [
			{ "target": "unit_stat", "unit_types": [BaseUnit.UnitType.INFANTRY, BaseUnit.UnitType.VILLAGER], "stat": "pierce_armor", "value": 1 }
		]
	},
	# Granary (BS)
	"small_wall": {
		"name": "Small Wall",
		"building": "granary",
		"cost": { ResourceSource.ResourceType.FOOD: 50 },
		"research_time": 20.0,
		"description": "Unlocks Wall construction",
		"effects": [
			{ "target": "unlock_building", "building_type": "small_wall" }
		]
	},
	"watch_tower": {
		"name": "Watch Tower",
		"building": "granary",
		"cost": { ResourceSource.ResourceType.FOOD: 50, ResourceSource.ResourceType.WOOD: 100 },
		"research_time": 30.0,
		"description": "Unlocks Watch Tower construction",
		"effects": [
			{ "target": "unlock_building", "building_type": "watch_tower" }
		]
	}
}

# { peer_id: Array[String] }
var researched_techs: Dictionary = {}

# { peer_id: { unit_type: { stat_name: int } } }
var unit_modifiers: Dictionary = {}

# { peer_id: { building_type: bool } }
var unlocked_buildings: Dictionary = {}

# { peer_id: Age }
var player_ages: Dictionary = {}

func _ready() -> void:
	init_player(1)

func init_player(peer_id: int) -> void:
	if not researched_techs.has(peer_id):
		researched_techs[peer_id] = []
	if not unit_modifiers.has(peer_id):
		unit_modifiers[peer_id] = {}
	if not unlocked_buildings.has(peer_id):
		unlocked_buildings[peer_id] = {}
	if not player_ages.has(peer_id):
		player_ages[peer_id] = Age.STONE_AGE

func get_player_age(peer_id: int) -> int:
	return player_ages.get(peer_id, Age.STONE_AGE)

func is_tech_researched(peer_id: int, tech_id: String) -> bool:
	if not researched_techs.has(peer_id):
		return false
	return tech_id in researched_techs[peer_id]

func is_building_unlocked(peer_id: int, b_type: String) -> bool:
	if b_type in ["house", "barracks", "granary", "storage_pit", "town_center"]:
		return true
	if not unlocked_buildings.has(peer_id):
		return false
	return unlocked_buildings[peer_id].get(b_type, false)

func get_unit_modifiers(peer_id: int, u_type: int) -> Dictionary:
	if not unit_modifiers.has(peer_id):
		return {}
	return unit_modifiers[peer_id].get(u_type, {})

func can_research(peer_id: int, tech_id: String) -> bool:
	if not TECH_DATABASE.has(tech_id):
		return false
	if is_tech_researched(peer_id, tech_id):
		return false
	var curr_age := get_player_age(peer_id)
	if tech_id == "tool_age" and curr_age != Age.STONE_AGE:
		return false
	if tech_id == "bronze_age" and curr_age != Age.TOOL_AGE:
		return false
	if tech_id == "iron_age" and curr_age != Age.BRONZE_AGE:
		return false
	return true

func server_complete_tech(peer_id: int, tech_id: String) -> void:
	if not TECH_DATABASE.has(tech_id):
		return
	_apply_tech_effects(peer_id, tech_id)

	# Gửi RPC đồng bộ đích danh tới các clients
	if multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and "connected_peers" in net_mgr:
			for pid in net_mgr.connected_peers:
				if pid != 1:
					sync_tech_completed.rpc_id(pid, peer_id, tech_id)

@rpc("authority", "call_local", "reliable")
func sync_tech_completed(peer_id: int, tech_id: String) -> void:
	# 4 lớp bảo vệ RPC an toàn
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	var local_id := multiplayer.get_unique_id()
	if local_id == 0:
		return
	_apply_tech_effects(peer_id, tech_id)

func _apply_tech_effects(peer_id: int, tech_id: String) -> void:
	init_player(peer_id)
	if tech_id not in researched_techs[peer_id]:
		researched_techs[peer_id].append(tech_id)

	var t_data: Dictionary = TECH_DATABASE[tech_id]
	for effect in t_data.get("effects", []):
		var target: String = effect.get("target", "")
		if target == "unit_stat":
			var u_types: Array = effect.get("unit_types", [])
			var stat_name: String = effect.get("stat", "")
			var val: int = effect.get("value", 0)
			for ut in u_types:
				var ut_int: int = int(ut)
				if not unit_modifiers[peer_id].has(ut_int):
					unit_modifiers[peer_id][ut_int] = {}
				var curr: int = unit_modifiers[peer_id][ut_int].get(stat_name, 0)
				unit_modifiers[peer_id][ut_int][stat_name] = curr + val
		elif target == "unlock_building":
			var b_type: String = effect.get("building_type", "")
			unlocked_buildings[peer_id][b_type] = true
			building_unlocked.emit(peer_id, b_type)
		elif target == "advance_age":
			var new_age: int = effect.get("age", 0)
			player_ages[peer_id] = new_age
			age_advanced.emit(peer_id, new_age)

	tech_completed.emit(peer_id, tech_id)

func get_sync_state() -> Dictionary:
	return {
		"researched_techs": researched_techs,
		"unlocked_buildings": unlocked_buildings,
		"player_ages": player_ages,
	}

func apply_sync_state(state: Dictionary) -> void:
	var r_techs: Dictionary = state.get("researched_techs", {})
	for pid_str in r_techs:
		var pid := int(pid_str)
		init_player(pid)
		for tech_id in r_techs[pid_str]:
			_apply_tech_effects(pid, tech_id)
	var ages: Dictionary = state.get("player_ages", {})
	for pid_str in ages:
		player_ages[int(pid_str)] = ages[pid_str]
