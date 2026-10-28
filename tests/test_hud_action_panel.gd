extends SceneTree

# Test suite for HUD & ActionPanel TechGrid Integration
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("--- Running Test HUD Action Panel ---")
		test_hud_build_menu()
		test_action_panel_storage_pit()
		test_action_panel_granary()
		print("--- All HUD Action Panel Tests PASSED ---")
		quit(0)
	return true

func test_hud_build_menu() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	assert(hud_scene != null, "hud.tscn must load")
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	assert(hud.build_granary_btn != null, "BuildGranaryBtn must exist in HUD")
	assert(hud.build_storage_pit_btn != null, "BuildStoragePitBtn must exist in HUD")

	var emitted_box: Array = [""]
	hud.build_requested.connect(func(b_type: String):
		emitted_box[0] = b_type
	)

	hud.build_granary_btn.pressed.emit()
	assert(emitted_box[0] == "granary", "Clicking Granary button must emit 'granary'")

	hud.build_storage_pit_btn.pressed.emit()
	assert(emitted_box[0] == "storage_pit", "Clicking Storage Pit button must emit 'storage_pit'")

	hud.free()

func test_action_panel_storage_pit() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	var building_script := load("res://scripts/entities/base_building.gd")
	var pit = building_script.new()
	pit.building_type = 3 # STORAGE_PIT
	pit.current_hp = pit.max_hp
	pit.is_constructed = true
	pit.owner_peer_id = 1
	root.add_child(pit)

	# Simulate selection
	hud._on_selection_changed([pit])
	assert(hud.action_panel.visible == true, "ActionPanel must be visible")
	assert(hud.action_title.text == "Storage Pit (Resources & Armory)", "Action title must match Storage Pit")
	assert(hud._dynamic_tech_buttons.size() == 3, "Storage Pit must offer 3 tech buttons (toolworking, leather, bronze)")

	# Give player resources and click toolworking
	var game_mgr = root.get_node_or_null("GameManager")
	if game_mgr:
		game_mgr.add_resource(1, ResourceSource.ResourceType.FOOD, 500)

	var toolworking_btn = hud._dynamic_tech_buttons[0]
	toolworking_btn.pressed.emit()
	assert(pit.production_queue.size() == 1, "Pit must have queued 1 tech")
	assert(pit.production_queue[0]["tech_id"] == "toolworking", "Queued tech must be toolworking")

	pit.free()
	hud.free()

func test_action_panel_granary() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)

	var building_script := load("res://scripts/entities/base_building.gd")
	var granary = building_script.new()
	granary.building_type = 4 # GRANARY
	granary.current_hp = granary.max_hp
	granary.is_constructed = true
	granary.owner_peer_id = 1
	root.add_child(granary)

	# Simulate selection
	hud._on_selection_changed([granary])
	assert(hud.action_panel.visible == true, "ActionPanel must be visible")
	assert(hud.action_title.text == "Granary (Food & Defense)", "Action title must match Granary")
	assert(hud._dynamic_tech_buttons.size() == 2, "Granary must offer 2 tech buttons (small_wall, watch_tower)")

	granary.free()
	hud.free()
