# Fact 1: Called by scenes/entities/animals/gazelle.tscn:6 and scripts/systems/random_map_generator.gd
# Fact 2: Verified no existing gazelle script via Glob in scripts/entities/
# Fact 3: Extends BaseAnimal, initializes prey stats (15 HP, 150 food meat, fast fleeing)
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi"

class_name Gazelle
extends BaseAnimal

func _init() -> void:
	animal_name = "Gazelle"
	behavior = Behavior.PREY
	max_hp = 15
	current_hp = 15
	meat_amount = 150
	current_amount = 150
	max_amount = 150
	move_speed = 4.0
	run_speed = 6.8
	attack_damage = 0
	alert_range = 9.5
