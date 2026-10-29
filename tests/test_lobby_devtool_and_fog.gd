# Fact 1: Standalone CLI test suite executed via Godot console: Godot_v4.7.2-stable_win64_console.exe --headless -s tests/test_lobby_devtool_and_fog.gd
# Fact 2: Verified no existing test_lobby_devtool_and_fog.gd via Glob in tests/
# Fact 3: SceneTree script validating GameManager match settings, FogOfWar void border coverage, DevTool cheat functions, and LobbyUI AoE 1 options
# Fact 4: User verbatim instruction: "[Image #2] hiện tại map vẫn chưa đen toàn bộ cũng như bạn làm cho tôi công cụ devtool để tôi có thể spawn mọi thứ ra dễ dàng và tôi chưa hề thấy chọn maptype hay có cho phép đen bản đồ hay là sáng toàn bản đồ hoặc chọn loại map medium, large, gigantic bạn xem để chọn các loại map bạn bảo thì chọn ở đâu tôi muốn ở bên ngoài lobby là phải có rồi đồng thời design lại lobby để giống game đế chế gốc [Image #4]"

extends SceneTree

const GameManagerScript = preload("res://scripts/autoload/game_manager.gd")
const DevToolScript = preload("res://scripts/ui/dev_tool.gd")
const DevToolScene = preload("res://scenes/ui/dev_tool.tscn")
const LobbyUIScript = preload("res://scripts/ui/lobby_ui.gd")
const LobbyScene = preload("res://scenes/ui/lobby.tscn")
const FogOfWarScript = preload("res://scripts/systems/fog_of_war.gd")

func _init() -> void:
	print("=== Running AoE 1 Lobby, DevTool & Fog of War Test Suite ===")
	_ensure_autoloads()
	test_game_manager_settings_and_presets()
	test_fog_of_war_void_borders_and_modes()
	test_dev_tool_spawning_and_cheats()
	test_lobby_ui_options_and_navigation()
	print("=== All Lobby, DevTool & Fog of War Tests PASSED! ===")
	quit(0)

func _ensure_autoloads() -> void:
	if not root.has_node("GameManager"):
		var gm = GameManagerScript.new()
		gm.name = "GameManager"
		root.add_child(gm)
		gm._ready()
	if not root.has_node("FogOfWar"):
		var fow = FogOfWarScript.new()
		fow.name = "FogOfWar"
		root.add_child(fow)
		fow._ready()

func test_game_manager_settings_and_presets() -> void:
	var gm := root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager autoload must exist")

	# Kiểm tra các giá trị thiết lập trận đấu
	gm.selected_map_type = 6 # Mediterranean
	gm.selected_map_size = 4 # Gigantic / Huge
	gm.selected_map_visibility = 2 # ALL_VISIBLE
	gm.selected_starting_resources_preset = 3 # Deathmatch
	gm.selected_starting_age = 2 # Bronze Age

	assert(gm.selected_map_type == 6, "Map type must be Mediterranean (6)")
	assert(gm.selected_map_size == 4, "Map size must be Gigantic (4)")
	assert(gm.selected_map_visibility == 2, "Visibility must be ALL_VISIBLE (2)")

	# Áp dụng tài nguyên Deathmatch
	gm.reset_match_resources()
	assert(gm.get_resource(1, ResourceSource.ResourceType.FOOD) == 20000, "Deathmatch Food must be 20000")
	assert(gm.get_resource(1, ResourceSource.ResourceType.WOOD) == 20000, "Deathmatch Wood must be 20000")
	assert(gm.get_resource(1, ResourceSource.ResourceType.GOLD) == 10000, "Deathmatch Gold must be 10000")
	assert(gm.get_resource(1, ResourceSource.ResourceType.STONE) == 5000, "Deathmatch Stone must be 5000")

	# Khôi phục preset mặc định
	gm.selected_starting_resources_preset = 0
	gm.reset_match_resources()
	assert(gm.get_resource(1, ResourceSource.ResourceType.FOOD) == 200, "Default Food must be 200")
	assert(gm.get_resource(1, ResourceSource.ResourceType.WOOD) == 200, "Default Wood must be 200")
	assert(gm.get_resource(1, ResourceSource.ResourceType.GOLD) == 100, "Default Gold must be 100")
	assert(gm.get_resource(1, ResourceSource.ResourceType.STONE) == 0, "Default Stone must be 0")

	print("✓ GameManager match settings & resource presets validated")

func test_fog_of_war_void_borders_and_modes() -> void:
	var fow := root.get_node_or_null("FogOfWar")
	assert(fow != null, "FogOfWar autoload must exist")

	# Cấu hình kích thước bản đồ lớn 220x220 với chế độ đen bản đồ tiêu chuẩn
	fow.setup_fog_map(220.0, 0) # NORMAL_FOG
	assert(fow.map_size == 220.0, "Map size must update to 220.0")
	assert(fow.half_size == 110.0, "Half size must update to 110.0")
	assert(fow.visibility_mode == 0, "Visibility mode must be NORMAL_FOG")
	assert(fow._void_skirt_nodes.size() == 4, "Must generate 4 black void borders around map edges")

	# Kiểm tra tọa độ ngoài biên phải luôn luôn chưa nhìn thấy (UNEXPLORED / not visible)
	assert(not fow.is_pos_visible(Vector3(150.0, 0.0, 150.0)), "Positions beyond map edges must NOT be visible")

	# Kiểm tra chế độ Sáng toàn bản đồ (Marco Polo)
	fow.toggle_all_visible()
	assert(fow.visibility_mode == 2, "Visibility mode must be ALL_VISIBLE (2)")
	assert(fow.is_pos_visible(Vector3(0.0, 0.0, 0.0)), "Center must be visible under Marco Polo")
	assert(fow.is_pos_explored(Vector3(50.0, 0.0, 50.0)), "All points must be explored under Marco Polo")

	# Kiểm tra chế độ Mở toàn bộ địa hình (EXPLORED)
	fow.set_all_explored()
	assert(fow.visibility_mode == 1, "Visibility mode must be EXPLORED (1)")
	assert(fow.is_pos_explored(Vector3(-50.0, 0.0, -50.0)), "Points must be explored")

	# Khôi phục chế độ Đen toàn bộ (Reset Fog)
	fow.reset_to_black()
	assert(fow.visibility_mode == 0, "Visibility mode must reset to NORMAL_FOG (0)")

	print("✓ FogOfWar dynamic sizing, void borders, and visibility modes validated")

func test_dev_tool_spawning_and_cheats() -> void:
	var dev_tool: DevTool = DevToolScene.instantiate() as DevTool
	assert(dev_tool != null, "DevTool scene must instantiate")
	root.add_child(dev_tool)
	dev_tool._ready()

	# Kiểm tra danh mục thực thể có đầy đủ Units, Animals, Buildings, Resources
	assert(dev_tool.SCENES.has("Villager"), "DevTool must have Villager")
	assert(dev_tool.SCENES.has("Swordsman"), "DevTool must have Swordsman")
	assert(dev_tool.SCENES.has("Elephant"), "DevTool must have Elephant")
	assert(dev_tool.SCENES.has("Gazelle"), "DevTool must have Gazelle")
	assert(dev_tool.SCENES.has("Lion"), "DevTool must have Lion")
	assert(dev_tool.SCENES.has("Alligator"), "DevTool must have Alligator")
	assert(dev_tool.SCENES.has("Town Center"), "DevTool must have Town Center")
	assert(dev_tool.SCENES.has("Barracks"), "DevTool must have Barracks")
	assert(dev_tool.SCENES.has("Gold Mine"), "DevTool must have Gold Mine")
	assert(dev_tool.SCENES.has("Berry Bush"), "DevTool must have Berry Bush")

	# Kiểm tra cheat tài nguyên
	var gm := root.get_node_or_null("GameManager")
	var initial_wood: int = gm.get_resource(1, ResourceSource.ResourceType.WOOD)
	dev_tool.cheat_add_resources(1000, 1000, 1000, 1000)
	assert(gm.get_resource(1, ResourceSource.ResourceType.WOOD) == initial_wood + 1000, "Cheat must add 1000 Wood")

	# Kiểm tra toggle DevTool
	assert(not dev_tool.is_open, "Initially closed")
	dev_tool.toggle_dev_tool()
	assert(dev_tool.is_open, "Toggled open")
	assert(dev_tool.visible, "Visible when open")
	dev_tool.toggle_dev_tool()
	assert(not dev_tool.is_open, "Toggled closed")

	# Kiểm tra Spawn tức thì qua DevTool
	var spawned_elephant = dev_tool._spawn_entity_at("Elephant", Vector3(10.0, 0.0, 10.0))
	assert(spawned_elephant != null, "Must successfully spawn Elephant")
	assert(spawned_elephant is BaseAnimal, "Spawned node must be BaseAnimal")
	assert((spawned_elephant as BaseAnimal).animal_name == "Elephant", "Spawned animal must be Elephant")
	spawned_elephant.queue_free()

	dev_tool.queue_free()
	print("✓ DevTool spawning dictionary, cheat resources, and toggle validated")

func test_lobby_ui_options_and_navigation() -> void:
	var lobby: LobbyUI = LobbyScene.instantiate() as LobbyUI
	assert(lobby != null, "Lobby scene must instantiate")
	root.add_child(lobby)
	lobby._ready()

	# Kiểm tra các nút Menu chính AoE 1
	assert(lobby.single_player_btn != null, "Single Player button must exist")
	assert(lobby.multiplayer_btn != null, "Multiplayer button must exist")
	assert(lobby.help_btn != null, "Help button must exist")
	assert(lobby.scenario_btn != null, "Scenario Builder button must exist")
	assert(lobby.exit_btn != null, "Exit button must exist")

	# Kiểm tra đầy đủ 9 chủng loại bản đồ trong Dropdown
	assert(lobby.opt_map_type.item_count == 9, "Must contain all 9 authentic AoE 1 map types")
	# Kiểm tra 5 kích thước bản đồ
	assert(lobby.opt_map_size.item_count == 5, "Must contain 5 map sizes (Tiny to Huge/Gigantic)")
	# Kiểm tra chế độ sương mù
	assert(lobby.opt_map_vis.item_count == 3, "Must contain 3 visibility modes (Normal, Explored, All Visible)")
	# Kiểm tra 4 thời kỳ xuất phát
	assert(lobby.opt_start_age.item_count == 4, "Must contain 4 ages (Stone, Tool, Bronze, Iron)")
	# Kiểm tra 4 gói tài nguyên
	assert(lobby.opt_resources.item_count == 4, "Must contain 4 resource presets")

	# Mở Dialog Single Player Setup
	lobby._on_single_player_pressed()
	assert(lobby.setup_dialog.visible, "Setup Dialog must become visible")
	assert(not lobby.main_menu_container.visible, "Main menu hides when dialog opens")

	# Chọn các tùy chọn và lưu cài đặt
	lobby.opt_map_type.select(6) # Mediterranean
	lobby.opt_map_size.select(4) # Gigantic
	lobby.opt_map_vis.select(2)  # All Visible
	lobby._save_settings_to_game_manager()

	var gm := root.get_node_or_null("GameManager")
	assert(gm.selected_map_type == 6, "GameManager must receive selected map type 6")
	assert(gm.selected_map_size == 4, "GameManager must receive selected map size 4")
	assert(gm.selected_map_visibility == 2, "GameManager must receive selected map visibility 2")

	# Đóng Dialog
	lobby._close_all_dialogs()
	assert(not lobby.setup_dialog.visible, "Setup Dialog must close")
	assert(lobby.main_menu_container.visible, "Main menu returns to visible")

	lobby.queue_free()
	print("✓ Lobby UI authentic AoE 1 menu buttons, dialogs, and setup options validated")
