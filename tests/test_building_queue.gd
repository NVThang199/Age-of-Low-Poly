extends SceneTree

# Test runner kiểm tra dual-queue và logic tech của BaseBuilding
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("--- Running Test Building Queue ---")
		test_dual_queue_and_tech()
		test_accepts_resource()
		print("--- All Building Queue Tests PASSED ---")
		quit(0)
	return true

func test_dual_queue_and_tech() -> void:
	var tm = root.get_node_or_null("TechManager")
	assert(tm != null, "TechManager autoload must exist")

	var building_script := load("res://scripts/entities/base_building.gd")
	var b = building_script.new()
	b.building_type = 3 # STORAGE_PIT
	b.current_hp = b.max_hp
	b.is_constructed = true
	b.owner_peer_id = 1
	root.add_child(b)

	# Kiểm tra queue_tech
	assert(b.production_queue.is_empty(), "Initial queue must be empty")
	var queued = b.queue_tech("toolworking", 1.0)
	assert(queued == true, "queue_tech must return true")
	assert(b.production_queue.size() == 1, "Queue must contain 1 item")
	assert(b.production_queue[0]["type"] == "tech", "Item type must be tech")
	assert(b.production_queue[0]["tech_id"] == "toolworking", "Item tech_id must be toolworking")

	# Xử lý production trong 1.1s để hoàn thành
	b._process_production(1.1)
	assert(b.production_queue.is_empty(), "Queue must be empty after completion")
	assert(tm.is_tech_researched(1, "toolworking") == true, "TechManager must record toolworking as researched")

	b.free()

func test_accepts_resource() -> void:
	var building_script := load("res://scripts/entities/base_building.gd")
	var tc = building_script.new()
	tc.building_type = 0 # TOWN_CENTER
	tc.current_hp = tc.max_hp
	tc.is_constructed = true
	root.add_child(tc)
	assert(tc.accepts_resource(ResourceSource.ResourceType.FOOD, false) == true, "TC accepts food berries")
	assert(tc.accepts_resource(ResourceSource.ResourceType.WOOD, false) == true, "TC accepts wood")

	var granary = building_script.new()
	granary.building_type = 4 # GRANARY
	granary.current_hp = granary.max_hp
	granary.is_constructed = true
	root.add_child(granary)
	assert(granary.accepts_resource(ResourceSource.ResourceType.FOOD, false) == true, "Granary accepts non-meat food")
	assert(granary.accepts_resource(ResourceSource.ResourceType.FOOD, true) == false, "Granary rejects hunt meat")
	assert(granary.accepts_resource(ResourceSource.ResourceType.WOOD, false) == false, "Granary rejects wood")

	var pit = building_script.new()
	pit.building_type = 3 # STORAGE_PIT
	pit.current_hp = pit.max_hp
	pit.is_constructed = true
	root.add_child(pit)
	assert(pit.accepts_resource(ResourceSource.ResourceType.WOOD, false) == true, "Storage pit accepts wood")
	assert(pit.accepts_resource(ResourceSource.ResourceType.FOOD, true) == true, "Storage pit accepts hunt meat")
	assert(pit.accepts_resource(ResourceSource.ResourceType.FOOD, false) == false, "Storage pit rejects berry food")

	tc.free()
	granary.free()
	pit.free()
