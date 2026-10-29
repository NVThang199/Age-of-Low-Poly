# Fact 1: Called by scenes/entities/cavalry.tscn, scripts/systems/command_manager.gd
# Fact 2: Verified UnitType.CAVALRY exists in scripts/entities/base_unit.gd
# Fact 3: Scout Cavalry AoE 1 unit logic
# Fact 4: User request: "tôi bảo bạn làm full game cho tôi hãy dùng cả blender mcp để làm mà đừng làm một vài chức năng làm full tất cả mọi thứ cho tôi làm sao để game giống game gốc"

class_name Cavalry
extends BaseUnit

## Scout Cavalry / Ngựa Trinh Sát AoE 1
## Tốc độ di chuyển cao (7.5m/s), tầm nhìn rộng (8.0m), sát thương cận chiến nhanh.

func _init() -> void:
	unit_type = UnitType.CAVALRY
	max_hp = 60
	current_hp = 60
	move_speed = 7.5
	attack_range = 1.4
	attack_cooldown = 1.2
	melee_attack = 8
	melee_armor = 0
	pierce_armor = 2
	right_hand_rotation = Vector3(0.0, 90.0, 0.0)

func _ready() -> void:
	super._ready()
	equip_item_right("res://assets/weapons/spear_A.fbx")
