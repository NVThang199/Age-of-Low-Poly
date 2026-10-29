# Fact 1: Called via CLI standalone execution: godot --headless -s tests/test_aoe_full_features.gd
# Fact 2: Extends coverage beyond tests/test_tech_manager.gd to 4 ages and full building scenes
# Fact 3: Asserts TechManager, BuildingPlacer, and BaseBuilding logic
# Fact 4: User request: "tôi bảo bạn làm full game cho tôi hãy dùng cả blender mcp để làm mà đừng làm một vài chức năng làm full tất cả mọi thứ cho tôi làm sao để game giống game gốc"

extends SceneTree

func _init() -> void:
	print("=== Running AoE Full Features Suite ===")
	test_four_ages_progression()
	test_age_prerequisites()
	test_building_unlocks_by_age()
	test_building_costs_and_scenes()
	print("=== All AoE Full Features Tests PASSED ===")
	quit(0)

func test_four_ages_progression() -> void:
	var tm_script := load("res://scripts/autoload/tech_manager.gd")
	assert(tm_script != null, "TechManager script must load")
	var tm = tm_script.new()
	var pid := 1

	# Ban đầu ở Stone Age (Đời 1)
	assert(tm.get_player_age(pid) == tm_script.Age.STONE_AGE, "Player must start in Stone Age")

	# Lên Đời 2: Tool Age
	tm.server_complete_tech(pid, "tool_age")
	assert(tm.get_player_age(pid) == tm_script.Age.TOOL_AGE, "Player must be in Tool Age")

	# Lên Đời 3: Bronze Age
	tm.server_complete_tech(pid, "bronze_age")
	assert(tm.get_player_age(pid) == tm_script.Age.BRONZE_AGE, "Player must be in Bronze Age")

	# Lên Đời 4: Iron Age
	tm.server_complete_tech(pid, "iron_age")
	assert(tm.get_player_age(pid) == tm_script.Age.IRON_AGE, "Player must be in Iron Age")

	tm.free()
	print("✓ 4 Ages progression validated")

func test_age_prerequisites() -> void:
	var tm_script := load("res://scripts/autoload/tech_manager.gd")
	var tm = tm_script.new()
	var pid := 1

	# Trong Stone Age: chỉ có thể lên Tool Age, không thể nhảy cóc lên Bronze Age hay Iron Age
	assert(tm.can_research(pid, "tool_age") == true, "Can research Tool Age in Stone Age")
	assert(tm.can_research(pid, "bronze_age") == false, "Cannot skip to Bronze Age in Stone Age")
	assert(tm.can_research(pid, "iron_age") == false, "Cannot skip to Iron Age in Stone Age")

	# Sau khi lên Tool Age
	tm.server_complete_tech(pid, "tool_age")
	assert(tm.can_research(pid, "tool_age") == false, "Already researched Tool Age")
	assert(tm.can_research(pid, "bronze_age") == true, "Can research Bronze Age in Tool Age")
	assert(tm.can_research(pid, "iron_age") == false, "Cannot skip to Iron Age in Tool Age")

	tm.free()
	print("✓ Age prerequisites validated")

func test_building_unlocks_by_age() -> void:
	var tm_script := load("res://scripts/autoload/tech_manager.gd")
	var tm = tm_script.new()
	var pid := 1

	# Đời 1: nhà cơ bản mở, nhà quân sự cấp cao khóa
	assert(tm.is_building_unlocked(pid, "house") == true, "House unlocked by default")
	assert(tm.is_building_unlocked(pid, "barracks") == true, "Barracks unlocked by default")
	assert(tm.is_building_unlocked(pid, "archery_range") == false, "Archery Range locked in Stone Age")
	assert(tm.is_building_unlocked(pid, "stable") == false, "Stable locked in Stone Age")
	assert(tm.is_building_unlocked(pid, "market") == false, "Market locked in Stone Age")
	assert(tm.is_building_unlocked(pid, "temple") == false, "Temple locked in Stone Age")

	# Lên Đời 2: Mở Archery Range, Stable, Market, Farm
	tm.server_complete_tech(pid, "tool_age")
	assert(tm.is_building_unlocked(pid, "archery_range") == true, "Archery Range unlocked in Tool Age")
	assert(tm.is_building_unlocked(pid, "stable") == true, "Stable unlocked in Tool Age")
	assert(tm.is_building_unlocked(pid, "market") == true, "Market unlocked in Tool Age")
	assert(tm.is_building_unlocked(pid, "farm") == true, "Farm unlocked in Tool Age")
	assert(tm.is_building_unlocked(pid, "temple") == false, "Temple still locked in Tool Age")

	# Lên Đời 3: Mở Temple, Siege Workshop
	tm.server_complete_tech(pid, "bronze_age")
	assert(tm.is_building_unlocked(pid, "temple") == true, "Temple unlocked in Bronze Age")
	assert(tm.is_building_unlocked(pid, "siege_workshop") == true, "Siege Workshop unlocked in Bronze Age")

	tm.free()
	print("✓ Building unlocks by age validated")

func test_building_costs_and_scenes() -> void:
	var bp_script := load("res://scripts/systems/building_placer.gd")
	assert(bp_script != null, "BuildingPlacer script must load")

	var costs: Dictionary = bp_script.BUILDING_COSTS
	var scenes: Dictionary = bp_script.BUILDING_SCENES

	var required_buildings := [
		"house", "barracks", "granary", "storage_pit",
		"farm", "archery_range", "stable", "market",
		"temple", "siege_workshop", "watch_tower", "small_wall"
	]

	for b_id in required_buildings:
		assert(costs.has(b_id), "Building cost must exist for: " + b_id)
		assert(scenes.has(b_id), "Building scene path must exist for: " + b_id)
		var sc_path: String = scenes[b_id]
		assert(ResourceLoader.exists(sc_path), "Scene file must exist on disk: " + sc_path)

	print("✓ Building costs and 100% scenes existence validated")
