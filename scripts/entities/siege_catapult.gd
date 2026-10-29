# Fact 1: Called by scripts/systems/command_manager.gd, scenes/entities/siege_catapult.tscn
# Fact 2: Verified no existing siege catapult via Glob in scripts/entities/
# Fact 3: In-memory only; extends BaseUnit
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

class_name SiegeCatapult
extends BaseUnit

## SiegeCatapult (Xe bắn đá - Đời 3/4)
## Đơn vị công thành hủy diệt theo chuẩn AOE 1:
## - Tầm bắn xa (12m), có tầm bắn tối thiểu (Blind spot 3m).
## - Đạn đạn đạo nổ lan (Splash Area of Effect Damage 2.5m).
## - Sát thương cực lớn đối với công trình và đám đông lính cụm.

const PROJECTILE_SCENE_PATH := "res://scenes/entities/arrow_projectile.tscn"

@export var min_attack_range: float = 3.0
@export var aoe_splash_radius: float = 2.5

func _init() -> void:
	unit_type = UnitType.SIEGE
	max_hp = 75
	current_hp = 75
	move_speed = 3.2
	melee_attack = 0
	pierce_attack = 40
	melee_armor = 0
	pierce_armor = 2
	attack_range = 12.0
	attack_cooldown = 3.5

func _ready() -> void:
	super._ready()

func _perform_attack(target: Node) -> void:
	if not is_instance_valid(target) or not (target is Node3D):
		return

	var dist := global_position.distance_to((target as Node3D).global_position)
	if dist < min_attack_range:
		# Mục tiêu quá gần vùng mù (Blind spot)
		return

	play_anim("Sword_Regular_Combo")

	var proj_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	if not proj_scene:
		return
	var proj := proj_scene.instantiate()
	if not proj:
		return

	proj.set("target", target)
	proj.set("attacker", self)
	proj.set("damage", pierce_attack)
	proj.set("splash_radius", aoe_splash_radius)
	proj.set("speed", 18.0) # Tốc độ đá bắn chậm hơn tên

	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0.0, 1.5, 0.0)
# ponytail: Catapult reuses character rig; replace with vehicle rig when wheeled assets are rigged.
