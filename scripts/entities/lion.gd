# Fact 1: Called by scenes/entities/animals/lion.tscn:6 and scripts/systems/random_map_generator.gd
# Fact 2: Verified no existing lion script via Glob in scripts/entities/
# Fact 3: Extends BaseAnimal, initializes predator stats (100 HP, 100 meat, 6 attack, aggressive scanning)
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi"

class_name Lion
extends BaseAnimal

func _init() -> void:
	animal_name = "Lion"
	behavior = Behavior.PREDATOR
	max_hp = 100
	current_hp = 100
	meat_amount = 100
	current_amount = 100
	max_amount = 100
	move_speed = 3.8
	run_speed = 5.8
	attack_damage = 6
	attack_range = 1.8
	attack_cooldown = 1.2
	alert_range = 8.5
	leash_range = 24.0
