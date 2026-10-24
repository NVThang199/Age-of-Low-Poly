class_name Swordsman
extends BaseUnit

@export_group("Weapons")
@export var sword_scene_path: String = "res://assets/weapons/sword_B.fbx"
@export var shield_scene_path: String = "res://assets/weapons/shield_C.fbx"

func _init() -> void:
	unit_type = UnitType.INFANTRY
	max_hp = 60
	current_hp = 60
	move_speed = 5.5
	melee_attack = 8
	melee_armor = 1
	pierce_armor = 1
	attack_range = 1.8
	attack_cooldown = 1.0
	left_hand_rotation = Vector3(0.0, 180.0, 0.0)

func _ready() -> void:
	super._ready()
	call_deferred("_equip_weapons")

func _equip_weapons() -> void:
	equip_item_right(sword_scene_path)
	equip_item_left(shield_scene_path)

