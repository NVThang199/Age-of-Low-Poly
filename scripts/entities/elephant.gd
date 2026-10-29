# Fact 1: Called by scenes/entities/animals/elephant.tscn:6 and scripts/systems/random_map_generator.gd
# Fact 2: Verified no existing elephant script via Glob in scripts/entities/
# Fact 3: Extends BaseAnimal, initializes elephant stats (600 HP, 300 meat, 15 attack, kiting mechanics)
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi"

class_name Elephant
extends BaseAnimal

func _init() -> void:
	animal_name = "Elephant"
	behavior = Behavior.NEUTRAL_DEFENDER
	max_hp = 600
	current_hp = 600
	meat_amount = 300
	current_amount = 300
	max_amount = 300
	move_speed = 3.2
	run_speed = 4.8
	attack_damage = 15
	attack_range = 2.4
	attack_cooldown = 1.35
	alert_range = 0.0 # Peaceful until attacked
	leash_range = 36.0 # Allows kiting to Town Center
