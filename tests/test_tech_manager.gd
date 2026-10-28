extends SceneTree

# Test runner độc lập cho logic TechManager
func _init() -> void:
	print("--- Running Test TechManager ---")
	test_tech_catalog()
	test_tech_modifiers()
	test_unlock_buildings()
	print("--- All TechManager Tests PASSED ---")
	quit(0)

func test_tech_catalog() -> void:
	var tm_script := load("res://scripts/autoload/tech_manager.gd")
	assert(tm_script != null, "TechManager script must load")
	var tm = tm_script.new()
	assert(tm.TECH_DATABASE.has("toolworking"), "Must have toolworking")
	assert(tm.TECH_DATABASE.has("leather_armor_infantry"), "Must have leather armor")
	assert(tm.TECH_DATABASE.has("bronze_shield"), "Must have bronze shield")
	assert(tm.TECH_DATABASE.has("small_wall"), "Must have small wall")
	assert(tm.TECH_DATABASE.has("watch_tower"), "Must have watch tower")
	tm.free()

func test_tech_modifiers() -> void:
	var tm_script := load("res://scripts/autoload/tech_manager.gd")
	var tm = tm_script.new()
	var peer_id := 1

	# Chưa nghiên cứu gì
	var mods_before: Dictionary = tm.get_unit_modifiers(peer_id, 1) # INFANTRY = 1
	assert(mods_before.get("melee_attack", 0) == 0, "Initial attack bonus must be 0")
	assert(mods_before.get("melee_armor", 0) == 0, "Initial melee armor bonus must be 0")

	# Hoàn thành Toolworking
	tm.server_complete_tech(peer_id, "toolworking")
	assert(tm.is_tech_researched(peer_id, "toolworking") == true, "Toolworking must be marked researched")
	var mods_after: Dictionary = tm.get_unit_modifiers(peer_id, 1) # INFANTRY
	assert(mods_after.get("melee_attack", 0) == 2, "Infantry melee_attack must gain +2 from Toolworking")

	# Hoàn thành Leather Armor
	tm.server_complete_tech(peer_id, "leather_armor_infantry")
	mods_after = tm.get_unit_modifiers(peer_id, 1)
	assert(mods_after.get("melee_armor", 0) == 2, "Infantry melee_armor must gain +2 from Leather Armor")

	# Hoàn thành Bronze Shield
	tm.server_complete_tech(peer_id, "bronze_shield")
	mods_after = tm.get_unit_modifiers(peer_id, 1)
	assert(mods_after.get("pierce_armor", 0) == 1, "Infantry pierce_armor must gain +1 from Bronze Shield")

	tm.free()

func test_unlock_buildings() -> void:
	var tm_script := load("res://scripts/autoload/tech_manager.gd")
	var tm = tm_script.new()
	var peer_id := 1

	assert(tm.is_building_unlocked(peer_id, "small_wall") == false, "Wall locked by default")
	assert(tm.is_building_unlocked(peer_id, "watch_tower") == false, "Tower locked by default")

	tm.server_complete_tech(peer_id, "small_wall")
	assert(tm.is_building_unlocked(peer_id, "small_wall") == true, "Wall unlocked after research")

	tm.server_complete_tech(peer_id, "watch_tower")
	assert(tm.is_building_unlocked(peer_id, "watch_tower") == true, "Tower unlocked after research")

	tm.free()
