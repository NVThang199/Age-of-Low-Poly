# Fact 1: Called via CLI standalone runner: Godot_v4.7.2-stable_win64_console.exe --headless -s tests/test_wildlife_ai.gd
# Fact 2: Verified no existing test_wildlife_ai.gd via Glob in C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\tests
# Fact 3: SceneTree script testing BaseAnimal, Gazelle, Elephant, Lion, Alligator stats, fleeing, pursuing, and meat harvesting
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi C:\Users\nguye\Downloads\Age of Empires 1_Linkneverdie.com\Age of Empires 1_Linkneverdie.com\Age of Empires sử dụng mcp REA để đọc toàn bộ không đọc 1 phần tất cả mọi chức năng đọc thật kĩ không được phép làm cầu thả"

extends SceneTree

func _init() -> void:
	print("=== Running AoE 1 Wildlife AI & Meat Ecosystem Test Suite ===")
	test_gazelle_prey_mechanics()
	test_elephant_kiting_and_stats()
	test_lion_predator_behavior()
	test_alligator_predator_stats()
	test_animal_death_and_carcass_harvesting()
	print("=== All Wildlife AI Tests PASSED! ===")
	quit(0)

func test_gazelle_prey_mechanics() -> void:
	var scene: PackedScene = load("res://scenes/entities/animals/gazelle.tscn")
	assert(scene != null, "Gazelle scene must load")
	var g: BaseAnimal = scene.instantiate() as BaseAnimal
	assert(g != null, "Gazelle must instantiate")
	root.add_child(g)

	assert(g.animal_name == "Gazelle", "Name must be Gazelle")
	assert(g.behavior == BaseAnimal.Behavior.PREY, "Gazelle must be PREY")
	assert(g.max_hp == 15, "Gazelle max HP must be 15")
	assert(g.current_hp == 15, "Gazelle starting HP must be 15")
	assert(g.meat_amount == 150, "Gazelle drops 150 meat")
	assert(g.attack_damage == 0, "Prey has 0 attack damage")

	# Bị tấn công phải chuyển sang trạng thái FLEEING
	var dummy_attacker := Node3D.new()
	root.add_child(dummy_attacker)
	dummy_attacker.position = Vector3(5, 0, 0)
	g.position = Vector3(0, 0, 0)

	g.take_damage(5, dummy_attacker)
	assert(g.current_hp == 10, "HP must drop to 10")
	assert(g.state == BaseAnimal.AnimalState.FLEEING, "Gazelle must enter FLEEING state")

	dummy_attacker.queue_free()
	g.queue_free()
	print("✓ Gazelle prey & flee mechanics validated")

func test_elephant_kiting_and_stats() -> void:
	var scene: PackedScene = load("res://scenes/entities/animals/elephant.tscn")
	assert(scene != null, "Elephant scene must load")
	var e: BaseAnimal = scene.instantiate() as BaseAnimal
	assert(e != null, "Elephant must instantiate")
	root.add_child(e)

	assert(e.animal_name == "Elephant", "Name must be Elephant")
	assert(e.behavior == BaseAnimal.Behavior.NEUTRAL_DEFENDER, "Elephant is neutral defender")
	assert(e.max_hp == 600, "Elephant has 600 HP (massive tank)")
	assert(e.attack_damage == 15, "Elephant deals 15 damage")
	assert(e.meat_amount == 300, "Elephant yields 300 meat")
	assert(e.leash_range >= 30.0, "Elephant leash range must allow TC kiting")

	# Cơ chế Kiting kinh điển: Ban đầu IDLE, nhận sát thương -> PURSUING người đánh
	assert(e.state == BaseAnimal.AnimalState.IDLE, "Initially idle")
	var villager := Node3D.new()
	root.add_child(villager)
	villager.position = Vector3(4, 0, 0)

	e.take_damage(10, villager)
	assert(e.current_hp == 590, "Elephant took 10 damage")
	assert(e.state == BaseAnimal.AnimalState.PURSUING, "Elephant must PURSUE attacker (TC kiting)")
	assert(e.target_entity == villager, "Elephant must target the villager")

	villager.queue_free()
	e.queue_free()
	print("✓ Elephant AoE 1 TC kiting & retaliate mechanics validated")

func test_lion_predator_behavior() -> void:
	var scene: PackedScene = load("res://scenes/entities/animals/lion.tscn")
	assert(scene != null, "Lion scene must load")
	var l: BaseAnimal = scene.instantiate() as BaseAnimal
	assert(l != null, "Lion must instantiate")
	root.add_child(l)

	assert(l.animal_name == "Lion", "Name must be Lion")
	assert(l.behavior == BaseAnimal.Behavior.PREDATOR, "Lion is PREDATOR")
	assert(l.max_hp == 100, "Lion has 100 HP")
	assert(l.attack_damage == 6, "Lion deals 6 damage")
	assert(l.meat_amount == 100, "Lion yields 100 meat")

	l.queue_free()
	print("✓ Lion predator stats validated")

func test_alligator_predator_stats() -> void:
	var scene: PackedScene = load("res://scenes/entities/animals/alligator.tscn")
	assert(scene != null, "Alligator scene must load")
	var a: BaseAnimal = scene.instantiate() as BaseAnimal
	assert(a != null, "Alligator must instantiate")
	root.add_child(a)

	assert(a.animal_name == "Alligator", "Name must be Alligator")
	assert(a.behavior == BaseAnimal.Behavior.PREDATOR, "Alligator is PREDATOR")
	assert(a.max_hp == 80, "Alligator has 80 HP")
	assert(a.attack_damage == 5, "Alligator deals 5 damage")
	assert(a.meat_amount == 100, "Alligator yields 100 meat")

	a.queue_free()
	print("✓ Alligator predator stats validated")

func test_animal_death_and_carcass_harvesting() -> void:
	var scene: PackedScene = load("res://scenes/entities/animals/gazelle.tscn")
	var g: BaseAnimal = scene.instantiate() as BaseAnimal
	root.add_child(g)

	# Giết thú để chuyển sang Carcass (Xác thịt thu hoạch)
	var dead_emitted := [false]
	g.animal_died.connect(func(_a): dead_emitted[0] = true)

	g.take_damage(20, null)
	assert(g.current_hp == 0, "HP must be 0")
	assert(g.state == BaseAnimal.AnimalState.DEAD, "State must be DEAD (carcass)")
	assert(dead_emitted[0], "animal_died signal must fire")
	assert(g.current_amount == 150, "Carcass holds 150 meat")
	assert(g.is_meat == true, "Must be tagged as is_meat")

	# Dân làng thu hoạch thịt (gather)
	var gathered_info := [-1, 0]
	g.resource_gathered.connect(func(t, a):
		gathered_info[0] = t
		gathered_info[1] = a
	)

	var harvested := g.gather(50)
	assert(harvested == 50, "Harvested 50 food")
	assert(g.current_amount == 100, "100 meat remaining")
	assert(gathered_info[0] == 0, "Resource type is FOOD (0)")
	assert(gathered_info[1] == 50, "Emitted 50 gathered")

	# Thu hoạch nốt phần còn lại -> Xác cạn kiệt biến mất
	var depleted := [false]
	g.resource_depleted.connect(func(_src): depleted[0] = true)
	var final_harvest := g.gather(100)
	assert(final_harvest == 100, "Gathered remaining 100")
	assert(depleted[0], "Resource depleted emitted when meat exhausted")

	g.queue_free()
	print("✓ Carcass & meat harvesting ecosystem validated")
