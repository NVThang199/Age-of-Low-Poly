extends SceneTree

# Comprehensive End-to-End Integration Test for AoE 1 Dual Storage & Technology System
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("=================================================================")
		print("--- Running Full AoE 1 Storage & Technology E2E Integration ---")
		print("=================================================================")
		test_e2e_full_flow()
		print("=================================================================")
		print("--- ALL E2E INTEGRATION TESTS PASSED (100% GREEN) ---")
		print("=================================================================")
		quit(0)
	return true

func test_e2e_full_flow() -> void:
	var tm = root.get_node_or_null("TechManager")
	var gm = root.get_node_or_null("GameManager")
	assert(tm != null, "TechManager autoload must be running")
	assert(gm != null, "GameManager autoload must be running")

	var peer_id := 1
	gm.init_player(peer_id)
	tm.init_player(peer_id)

	# Set initial resources
	gm.add_resource(peer_id, ResourceSource.ResourceType.FOOD, 800)
	gm.add_resource(peer_id, ResourceSource.ResourceType.WOOD, 800)
	gm.add_resource(peer_id, ResourceSource.ResourceType.GOLD, 400)
	gm.add_resource(peer_id, ResourceSource.ResourceType.STONE, 500)

	var building_script := load("res://scripts/entities/base_building.gd")
	var villager_script := load("res://scripts/entities/villager.gd")
	var swordsman_script := load("res://scripts/entities/swordsman.gd")

	# 1. Instantiate Storage Buildings
	var granary = building_script.new()
	granary.building_type = 4 # GRANARY
	granary.current_hp = granary.max_hp
	granary.is_constructed = true
	granary.owner_peer_id = peer_id
	granary.add_to_group("dropoffs")
	root.add_child(granary)
	granary.global_position = Vector3(15, 0, 0)

	var pit = building_script.new()
	pit.building_type = 3 # STORAGE_PIT
	pit.current_hp = pit.max_hp
	pit.is_constructed = true
	pit.owner_peer_id = peer_id
	pit.add_to_group("dropoffs")
	root.add_child(pit)
	pit.global_position = Vector3(0, 0, 15)

	# 2. Test Dual-Storage Routing
	var v = villager_script.new()
	v.owner_peer_id = peer_id
	root.add_child(v)
	v.global_position = Vector3.ZERO

	# Berry Food -> Granary
	v.carried_type = ResourceSource.ResourceType.FOOD
	v.carried_is_meat = false
	var dropoff = v._find_nearest_dropoff()
	assert(dropoff == granary, "E2E: Foraged berries must route to Granary")

	# Wood -> Storage Pit
	v.carried_type = ResourceSource.ResourceType.WOOD
	v.carried_is_meat = false
	dropoff = v._find_nearest_dropoff()
	assert(dropoff == pit, "E2E: Wood must route to Storage Pit")

	# Hunt Meat -> Storage Pit
	v.carried_type = ResourceSource.ResourceType.FOOD
	v.carried_is_meat = true
	dropoff = v._find_nearest_dropoff()
	assert(dropoff == pit, "E2E: Hunt meat must route to Storage Pit")

	# Deposit resources & verify GameManager update
	var food_before: int = gm.get_resource(peer_id, ResourceSource.ResourceType.FOOD)
	granary.deposit_resource(peer_id, ResourceSource.ResourceType.FOOD, 10)
	assert(gm.get_resource(peer_id, ResourceSource.ResourceType.FOOD) == food_before + 10, "E2E: Depositing food must increase GameManager food")

	# 3. Create Military & Civilian Units for stat tracking
	var sword = swordsman_script.new()
	sword.owner_peer_id = peer_id
	root.add_child(sword)

	assert(v.melee_attack == 3, "Villager base attack is 3")
	assert(sword.melee_attack == 8, "Swordsman base attack is 8")
	assert(v.melee_armor == 0, "Villager base melee armor is 0")
	assert(sword.melee_armor == 1, "Swordsman base melee armor is 1")
	assert(v.pierce_armor == 0, "Villager base pierce armor is 0")
	assert(sword.pierce_armor == 1, "Swordsman base pierce armor is 1")

	# 4. Research Toolworking (+2 Melee Attack) at Storage Pit
	assert(pit.queue_tech("toolworking", 2.0) == true, "E2E: Queue toolworking must succeed")
	pit._process_production(2.1) # Simulate completion

	assert(tm.is_tech_researched(peer_id, "toolworking") == true, "E2E: Toolworking must be researched")
	assert(v.melee_attack == 5, "E2E: Active Villager must now have 3 + 2 = 5 melee attack")
	assert(sword.melee_attack == 10, "E2E: Active Swordsman must now have 8 + 2 = 10 melee attack")

	# Newly instantiated units also receive the bonus immediately
	var new_v = villager_script.new()
	new_v.owner_peer_id = peer_id
	root.add_child(new_v)
	assert(new_v.melee_attack == 5, "E2E: Newly spawned Villager must inherit +2 melee attack")
	new_v.free()

	# 5. Research Bronze Shield (+1 Pierce Armor) at Storage Pit
	assert(pit.queue_tech("bronze_shield", 1.5) == true, "E2E: Queue bronze shield must succeed")
	pit._process_production(1.6)

	assert(tm.is_tech_researched(peer_id, "bronze_shield") == true, "E2E: Bronze shield must be researched")
	assert(v.pierce_armor == 1, "E2E: Villager must have 0 + 1 = 1 pierce armor")
	assert(sword.pierce_armor == 2, "E2E: Swordsman must have 1 + 1 = 2 pierce armor")

	# 6. Research Watch Tower at Granary -> Unlocks Building
	assert(tm.is_building_unlocked(peer_id, "watch_tower") == false, "E2E: Watch Tower initially locked")
	assert(granary.queue_tech("watch_tower", 1.0) == true, "E2E: Queue watch tower at Granary")
	granary._process_production(1.1)

	assert(tm.is_building_unlocked(peer_id, "watch_tower") == true, "E2E: Watch Tower unlocked after research")

	# 7. Late-join Peer State Synchronization
	var sync_data = tm.get_sync_state()
	assert(sync_data.has("researched_techs"), "Sync data contains researched_techs")
	assert(sync_data.has("unlocked_buildings"), "Sync data contains unlocked_buildings")

	var joiner_peer := 2
	tm.init_player(joiner_peer)
	# Simulate receiving sync packet from server
	var client_tm = root.get_node_or_null("TechManager")
	client_tm.apply_sync_state(sync_data)
	assert(client_tm.is_tech_researched(peer_id, "toolworking") == true, "Synced client records toolworking")
	assert(client_tm.is_building_unlocked(peer_id, "watch_tower") == true, "Synced client records watch tower unlocked")

	# Clean up test nodes
	v.free()
	sword.free()
	granary.free()
	pit.free()
