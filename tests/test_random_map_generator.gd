# Fact 1: Called via CLI standalone runner: Godot_v4.7.2-stable_win64_console.exe --headless -s tests/test_random_map_generator.gd
# Fact 2: Verified no existing test_random_map_generator.gd via Glob in C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\tests
# Fact 3: SceneTree script testing RandomMapGenerator map types, dimensions, seed determinism, and procedural starting resources
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi C:\Users\nguye\Downloads\Age of Empires 1_Linkneverdie.com\Age of Empires 1_Linkneverdie.com\Age of Empires sử dụng mcp REA để đọc toàn bộ không đọc 1 phần tất cả mọi chức năng đọc thật kĩ không được phép làm cầu thả"

extends SceneTree

const RandomMapGeneratorScript = preload("res://scripts/systems/random_map_generator.gd")

func _init() -> void:
	print("=== Running AoE 1 Random Map Generator (RMS) Test Suite ===")
	test_map_dimensions_and_types()
	test_seed_determinism()
	test_map_generation_and_player_starting_settlement()
	print("=== All Random Map Generator Tests PASSED! ===")
	quit(0)

func test_map_dimensions_and_types() -> void:
	var gen = RandomMapGeneratorScript.new()
	root.add_child(gen)

	# Kiểm tra kích thước Map
	gen.map_size = RandomMapGeneratorScript.MapSize.TINY
	assert(gen.get_map_dimension() == 100.0, "TINY map size must be 100")
	gen.map_size = RandomMapGeneratorScript.MapSize.SMALL
	assert(gen.get_map_dimension() == 140.0, "SMALL map size must be 140")
	gen.map_size = RandomMapGeneratorScript.MapSize.MEDIUM
	assert(gen.get_map_dimension() == 180.0, "MEDIUM map size must be 180")
	gen.map_size = RandomMapGeneratorScript.MapSize.LARGE
	assert(gen.get_map_dimension() == 220.0, "LARGE map size must be 220")
	gen.map_size = RandomMapGeneratorScript.MapSize.HUGE
	assert(gen.get_map_dimension() == 280.0, "HUGE map size must be 280")

	# Kiểm tra logic độ cao Highland: Lòng sông phải âm, bến cạn phải cạn
	gen.map_type = RandomMapGeneratorScript.MapType.HIGHLAND
	gen._setup_noise()
	var river_bed_h: float = gen.get_height(0.0, 0.0)
	assert(river_bed_h < 0.0, "Highland river bed must be underwater (< 0.0)")
	var river_crossing_h: float = gen.get_height(0.0, 15.0)
	assert(river_crossing_h >= 0.0, "Highland crossing must be walkable (>= 0.0)")

	# Kiểm tra Mediterranean: Trung tâm là biển (< 0.0), vành đai là đất (> 0.0)
	gen.map_type = RandomMapGeneratorScript.MapType.MEDITERRANEAN
	gen._setup_noise()
	var med_center_h: float = gen.get_height(0.0, 0.0)
	assert(med_center_h < 0.0, "Mediterranean center must be deep sea")
	var med_outer_h: float = gen.get_height(55.0, 55.0)
	assert(med_outer_h > 0.0, "Mediterranean outer rim must be dry land")

	gen.queue_free()
	print("✓ Map dimensions and terrain types validated")

func test_seed_determinism() -> void:
	var gen1 = RandomMapGeneratorScript.new()
	var gen2 = RandomMapGeneratorScript.new()
	root.add_child(gen1)
	root.add_child(gen2)

	gen1.map_seed = 12345
	gen2.map_seed = 12345
	gen1._setup_noise()
	gen2._setup_noise()

	for x in [-30.0, 0.0, 30.0]:
		for z in [-30.0, 0.0, 30.0]:
			var h1: float = gen1.get_height(x, z)
			var h2: float = gen2.get_height(x, z)
			assert(is_equal_approx(h1, h2), "Identical seed must produce identical heightmap")

	# Khác seed phải sinh địa hình khác nhau
	gen2.map_seed = 99999
	gen2._setup_noise()
	var diff_count := 0
	for x in [-40.0, 10.0, 40.0]:
		for z in [-40.0, 10.0, 40.0]:
			if not is_equal_approx(gen1.get_height(x, z), gen2.get_height(x, z)):
				diff_count += 1
	assert(diff_count > 0, "Different seeds must produce different heightmaps")

	gen1.queue_free()
	gen2.queue_free()
	print("✓ Map seed determinism validated")

func test_map_generation_and_player_starting_settlement() -> void:
	var gen = RandomMapGeneratorScript.new()
	root.add_child(gen)

	gen.map_type = RandomMapGeneratorScript.MapType.HIGHLAND
	gen.map_size = RandomMapGeneratorScript.MapSize.MEDIUM
	gen.map_seed = 77777
	gen.num_players = 2

	var completed := [false]
	gen.map_generation_completed.connect(func(): completed[0] = true)

	gen.generate_map()
	assert(completed[0], "map_generation_completed signal must fire")
	assert(gen.generated_nodes.size() > 0, "Map generator must instantiate world nodes")
	assert(gen.player_spawn_positions.size() == 2, "Must calculate 2 player spawn points")

	# Đếm các thực thể sinh ra trên bản đồ
	var tc_count := 0
	var villager_count := 0
	var berry_count := 0
	var gazelle_count := 0
	var elephant_count := 0
	var lion_count := 0
	var gold_count := 0
	var stone_count := 0
	var tree_count := 0

	for node in gen.generated_nodes:
		if is_instance_valid(node):
			if node is BaseBuilding and node.building_type == BaseBuilding.BuildingType.TOWN_CENTER:
				tc_count += 1
			elif node is Villager:
				villager_count += 1
			elif node is BaseAnimal:
				match node.animal_name:
					"Gazelle": gazelle_count += 1
					"Elephant": elephant_count += 1
					"Lion": lion_count += 1
			elif node is ResourceSource:
				match node.resource_type:
					ResourceSource.ResourceType.FOOD: berry_count += 1
					ResourceSource.ResourceType.WOOD: tree_count += 1
					ResourceSource.ResourceType.GOLD: gold_count += 1
					ResourceSource.ResourceType.STONE: stone_count += 1

	print("  Generated entities summary:")
	print("  - Town Centers: %d" % tc_count)
	print("  - Villagers: %d" % villager_count)
	print("  - Berry Bushes: %d" % berry_count)
	print("  - Gazelles: %d" % gazelle_count)
	print("  - Elephants: %d" % elephant_count)
	print("  - Lions: %d" % lion_count)
	print("  - Gold Mines: %d" % gold_count)
	print("  - Stone Mines: %d" % stone_count)
	print("  - Trees: %d" % tree_count)

	# Kiểm định chuẩn xác quy tắc khởi đầu AoE 1
	assert(tc_count == 2, "Must spawn 1 Town Center per player (total 2)")
	assert(villager_count == 6, "Must spawn 3 Villagers per player (total 6)")
	assert(berry_count >= 10, "Must spawn starting forage berry patches for both players")
	assert(gazelle_count >= 8, "Must spawn gazelle herds for both players")
	assert(elephant_count >= 4, "Must spawn elephants near players for classic kiting")
	assert(lion_count >= 2, "Must spawn predatory lions")
	assert(gold_count >= 14, "Must spawn primary and secondary gold mines")
	assert(stone_count >= 6, "Must spawn stone mines")
	assert(tree_count >= 20, "Must spawn protective woodlines and forests")

	# Kiểm định dọn dẹp an toàn clear_map()
	gen.clear_map()
	assert(gen.generated_nodes.is_empty(), "clear_map() must empty generated_nodes array")
	assert(gen.player_spawn_positions.is_empty(), "clear_map() must clear spawn positions")

	gen.queue_free()
	print("✓ Complete AoE 1 procedural map generation & player start settlement validated")
