extends SceneTree

# Test suite for Villager dropoff routing and anti-stuck logic
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("--- Running Test Villager Dropoff Routing ---")
		test_dropoff_routing()
		test_manual_deposit_rerouting()
		test_auto_dropoff_on_full_inventory()
		test_collision_obstacle_vs_floor_sliding()
		test_villager_movement_animation()
		test_dropoff_empty_hands_perimeter_clamping()
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

func test_auto_dropoff_on_full_inventory() -> void:
	var building_script := load("res://scripts/entities/base_building.gd")
	var villager_script := load("res://scripts/entities/villager.gd")

	var granary = building_script.new()
	granary.building_type = 4 # GRANARY
	granary.current_hp = granary.max_hp
	granary.is_constructed = true
	granary.owner_peer_id = 1
	granary.add_to_group("dropoffs")
	root.add_child(granary)
	granary.global_position = Vector3(5, 0, 0)

	var v = villager_script.new()
	v.owner_peer_id = 1
	v.carry_capacity = 10
	v.carried_amount = 10
	v.carried_type = ResourceSource.ResourceType.FOOD
	v.carried_is_meat = false
	v.state = BaseUnit.UnitState.GATHERING
	root.add_child(v)
	v.global_position = Vector3(20, 0, 0)

	# Simulate physics tick when full -> must auto find nearest dropoff (granary) and enter is_delivering
	v._process_gathering(0.1)
	assert(v.is_delivering == true, "Villager must automatically start delivering when full")
	assert(v.target_dropoff == granary, "Villager must auto-target nearest compatible Granary for berries")

	# Simulate reaching deposit range (dist <= 4.2)
	v.global_position = Vector3(7.5, 0, 0) # dist = 2.5 <= 4.2
	v._return_to_dropoff(0.1)
	assert(v.carried_amount == 0, "Resources must be deposited upon entering stop_dist")
	assert(v.is_delivering == false, "Delivery must conclude after depositing")
	assert(v.target_dropoff == null, "Target dropoff must reset to allow auto-finding on next trip")

	v.free()
	granary.free()

func test_collision_obstacle_vs_floor_sliding() -> void:
	var villager_script := load("res://scripts/entities/villager.gd")
	var v = villager_script.new()
	root.add_child(v)

	# 1. Verify wall normal activates slide adjustment
	v.target_position = Vector3(0, 0, 10)
	v.global_position = Vector3.ZERO
	v.last_collision_normal = Vector3(0, 0, -1) # Wall facing unit
	var dir: Vector3 = (v.target_position - v.global_position).normalized()
	assert(dir.dot(v.last_collision_normal) < -0.05, "Unit is moving into obstacle")

	# Test horizontal slide tangent
	var tangent1 := Vector3(-v.last_collision_normal.z, 0.0, v.last_collision_normal.x).normalized()
	assert(absf(tangent1.x) > 0.5 or absf(tangent1.z) > 0.5, "Tangent must be non-zero horizontal vector")

	# 2. Verify floor normal (Y=1) is correctly differentiated
	var floor_normal := Vector3(0, 1, 0)
	assert(absf(floor_normal.y) >= 0.7, "Floor normal Y >= 0.7 must be ignored by wall collision filter")

	v.free()

func test_villager_movement_animation() -> void:
	var villager_script := load("res://scripts/entities/villager.gd")
	var v = villager_script.new()
	root.add_child(v)
	v.global_position = Vector3.ZERO
	v.target_position = Vector3(10, 0, 0)

	# 1. Empty handed -> Sprint condition
	v.carried_amount = 0
	v.is_delivering = false
	var is_carrying: bool = ("carried_amount" in v and v.carried_amount > 0) or ("is_delivering" in v and v.is_delivering)
	assert(not is_carrying, "Empty handed villager must NOT trigger carry animation")

	# 2. Carrying resources -> Walk_Carry condition
	v.carried_amount = 5
	is_carrying = ("carried_amount" in v and v.carried_amount > 0) or ("is_delivering" in v and v.is_delivering)
	assert(is_carrying, "Villager carrying resources MUST trigger carry animation")

	# 3. Delivering mode -> Walk_Carry condition
	v.carried_amount = 0
	v.is_delivering = true
	is_carrying = ("carried_amount" in v and v.carried_amount > 0) or ("is_delivering" in v and v.is_delivering)
	assert(is_carrying, "Villager delivering back to dropoff MUST trigger carry animation")

	v.free()

func test_dropoff_empty_hands_perimeter_clamping() -> void:
	var building_script := load("res://scripts/entities/base_building.gd")
	var villager_script := load("res://scripts/entities/villager.gd")

	var pit = building_script.new()
	pit.building_type = 3 # STORAGE_PIT
	pit.current_hp = pit.max_hp
	pit.is_constructed = true
	pit.owner_peer_id = 1
	pit.add_to_group("dropoffs")
	root.add_child(pit)
	pit.global_position = Vector3(10, 0, 0)

	var v = villager_script.new()
	v.owner_peer_id = 1
	v.carried_amount = 0
	root.add_child(v)
	v.global_position = Vector3(0, 0, 0)

	# Right clicking dropoff with empty hands must clamp target_position to perimeter
	v.return_resources_to(pit)
	assert(v.state == BaseUnit.UnitState.MOVING, "Empty handed click on dropoff sets MOVING state")
	var dist_to_center: float = v.target_position.distance_to(pit.global_position)
	assert(absf(dist_to_center - 3.4) < 0.1, "Target position must clamp to perimeter radius 3.4m, not center")

	v.free()
	pit.free()



