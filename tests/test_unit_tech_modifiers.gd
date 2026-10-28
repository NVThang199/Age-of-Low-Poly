extends SceneTree

var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("--- Running Test Unit Tech Modifiers in _process ---")
		test_swordsman_modifiers()
		test_villager_modifiers()
		print("--- All Unit Tech Modifiers Tests PASSED ---")
		quit(0)
	return true

func test_swordsman_modifiers() -> void:
	var tm = root.get_node_or_null("TechManager")
	print("Found autoload tm: ", tm, " path: ", tm.get_path() if tm else "")

	var swordsman_script := load("res://scripts/entities/swordsman.gd")
	var s = swordsman_script.new()
	s.owner_peer_id = 1
	root.add_child(s)
	print("Added s: ", s.get_path())
	print("Swordsman unit_type: ", s.unit_type, " base_atk: ", s.base_melee_attack, " atk: ", s.melee_attack)

	# Nâng cấp Toolworking (+2 melee_attack cho Infantry & Villager)
	tm.server_complete_tech(1, "toolworking")
	print("After toolworking: mods=", tm.get_unit_modifiers(1, int(s.unit_type)), " s.atk=", s.melee_attack)
	assert(s.melee_attack == 10, "Swordsman melee_attack must be 10 after Toolworking (+2)")

	# Nâng cấp Leather Armor (+2 melee_armor cho Infantry)
	tm.server_complete_tech(1, "leather_armor_infantry")
	assert(s.melee_armor == 3, "Swordsman melee_armor must be 3 after Leather Armor (+2)")

	# Nâng cấp Bronze Shield (+1 pierce_armor cho Infantry & Villager)
	tm.server_complete_tech(1, "bronze_shield")
	assert(s.pierce_armor == 2, "Swordsman pierce_armor must be 2 after Bronze Shield (+1)")

	s.free()

func test_villager_modifiers() -> void:
	var tm = root.get_node_or_null("TechManager")

	var villager_script := load("res://scripts/entities/villager.gd")
	var v = villager_script.new()
	v.owner_peer_id = 1
	root.add_child(v)

	# Toolworking (+2 melee attack) đã nâng cấp, nên nông dân ban đầu 3 + 2 = 5
	assert(v.melee_attack == 5, "Villager melee_attack must be 5 (base 3 + 2 from Toolworking)")
	# Bronze Shield (+1 pierce armor) đã nâng cấp, nên nông dân ban đầu 0 + 1 = 1
	assert(v.pierce_armor == 1, "Villager pierce_armor must be 1 after Bronze Shield")

	v.free()
