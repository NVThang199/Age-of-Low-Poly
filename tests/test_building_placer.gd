extends SceneTree

# Test suite for BuildingPlacer & Tech Unlock Integration
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("--- Running Test Building Placer ---")
		test_building_placer_definitions()
		test_tech_gating()
		print("--- All Building Placer Tests PASSED ---")
		quit(0)
	return true

func test_building_placer_definitions() -> void:
	var placer_script := load("res://scripts/systems/building_placer.gd")
	assert(placer_script != null, "BuildingPlacer script must load")

	var costs: Dictionary = placer_script.BUILDING_COSTS
	assert(costs.has("granary"), "Must have granary cost")
	assert(costs["granary"]["wood"] == 120, "Granary cost must be 120 wood")
	assert(costs.has("storage_pit"), "Must have storage_pit cost")
	assert(costs["storage_pit"]["wood"] == 120, "Storage Pit cost must be 120 wood")

	var scenes: Dictionary = placer_script.BUILDING_SCENES
	assert(scenes.has("granary"), "Must have granary scene")
	assert(scenes["granary"] == "res://scenes/entities/granary.tscn", "Granary scene path must match")
	assert(scenes.has("storage_pit"), "Must have storage_pit scene")
	assert(scenes["storage_pit"] == "res://scenes/entities/storage_pit.tscn", "Storage Pit scene path must match")

func test_tech_gating() -> void:
	var tm = root.get_node_or_null("TechManager")
	assert(tm != null, "TechManager autoload must exist")

	# Basic buildings unlocked
	assert(tm.is_building_unlocked(1, "house") == true, "House unlocked by default")
	assert(tm.is_building_unlocked(1, "granary") == true, "Granary unlocked by default")
	assert(tm.is_building_unlocked(1, "storage_pit") == true, "Storage Pit unlocked by default")

	# Advanced buildings locked until researched
	assert(tm.is_building_unlocked(1, "watch_tower") == false, "Watch Tower locked by default")
	assert(tm.is_building_unlocked(1, "small_wall") == false, "Small Wall locked by default")

	# Research watch_tower
	tm.server_complete_tech(1, "watch_tower")
	assert(tm.is_building_unlocked(1, "watch_tower") == true, "Watch Tower unlocked after research")
