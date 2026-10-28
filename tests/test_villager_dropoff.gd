extends SceneTree

# Test suite for Villager dropoff routing and anti-stuck logic
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("--- Running Test Villager Dropoff Routing ---")
		test_dropoff_routing()
		test_manual_deposit_rerouting()
		print("--- All Villager Dropoff Tests PASSED ---")
		quit(0)
	return true

func test_dropoff_routing() -> void:
	var building_script := load("res://scripts/entities/base_building.gd")
	var villager_script := load("res://scripts/entities/villager.gd")

	# Create buildings
	var granary = building_script.new()
	granary.building_type = 4 # GRANARY
	granary.current_hp = granary.max_hp
	granary.is_constructed = true
	granary.owner_peer_id = 1
	granary.add_to_group("dropoffs")
	root.add_child(granary)
	granary.global_position = Vector3(10, 0, 0)

	var pit = building_script.new()
	pit.building_type = 3 # STORAGE_PIT
	pit.current_hp = pit.max_hp
	pit.is_constructed = true
	pit.owner_peer_id = 1
	pit.add_to_group("dropoffs")
	root.add_child(pit)
	pit.global_position = Vector3(0, 0, 10)

	var v = villager_script.new()
	v.owner_peer_id = 1
	root.add_child(v)
	v.global_position = Vector3.ZERO

	# 1. Wood -> must route to Storage Pit
	v.carried_type = ResourceSource.ResourceType.WOOD
	v.carried_is_meat = false
	var target = v._find_nearest_dropoff()
	assert(target == pit, "Wood must route to Storage Pit, not Granary")

	# 2. Food (berries, is_meat = false) -> must route to Granary
	v.carried_type = ResourceSource.ResourceType.FOOD
	v.carried_is_meat = false
	target = v._find_nearest_dropoff()
	assert(target == granary, "Berries must route to Granary, not Storage Pit")

	# 3. Food (meat, is_meat = true) -> must route to Storage Pit
	v.carried_type = ResourceSource.ResourceType.FOOD
	v.carried_is_meat = true
	target = v._find_nearest_dropoff()
	assert(target == pit, "Hunt meat must route to Storage Pit, not Granary")

	v.free()
	granary.free()
	pit.free()

func test_manual_deposit_rerouting() -> void:
	var building_script := load("res://scripts/entities/base_building.gd")
	var villager_script := load("res://scripts/entities/villager.gd")

	var granary = building_script.new()
	granary.building_type = 4 # GRANARY
	granary.current_hp = granary.max_hp
	granary.is_constructed = true
	granary.owner_peer_id = 1
	granary.add_to_group("dropoffs")
	root.add_child(granary)

	var pit = building_script.new()
	pit.building_type = 3 # STORAGE_PIT
	pit.current_hp = pit.max_hp
	pit.is_constructed = true
	pit.owner_peer_id = 1
	pit.add_to_group("dropoffs")
	root.add_child(pit)

	var v = villager_script.new()
	v.owner_peer_id = 1
	v.carried_type = ResourceSource.ResourceType.WOOD
	v.carried_amount = 10
	v.carried_is_meat = false
	root.add_child(v)

	# User commands villager carrying wood to granary -> must reroute to pit
	v.return_resources_to(granary)
	assert(v.target_dropoff == pit, "Manual return to Granary with Wood must reroute to Storage Pit")
	assert(v.is_delivering == true, "Must be delivering")

	v.free()
	granary.free()
	pit.free()
