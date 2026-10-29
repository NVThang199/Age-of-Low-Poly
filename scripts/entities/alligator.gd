# Fact 1: Called by scenes/entities/animals/alligator.tscn:6 and scripts/systems/random_map_generator.gd
# Fact 2: Verified no existing alligator script via Glob in scripts/entities/
# Fact 3: Extends BaseAnimal, initializes water predator stats (80 HP, 100 meat, 5 attack)
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi"

class_name Alligator
extends BaseAnimal

func _init() -> void:
	animal_name = "Alligator"
	behavior = Behavior.PREDATOR
	max_hp = 80
	current_hp = 80
	meat_amount = 100
	current_amount = 100
	max_amount = 100
	move_speed = 3.0
	run_speed = 4.6
	attack_damage = 5
	attack_range = 1.6
	attack_cooldown = 1.4
	alert_range = 7.0
	leash_range = 20.0
