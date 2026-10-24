class_name Archer
extends BaseUnit

const ARROW_SCENE_PATH := "res://scenes/entities/arrow_projectile.tscn"

@export_group("Weapons")
@export var bow_scene_path: String = "res://assets/weapons/bow_A_withString.fbx"

func _init() -> void:
	unit_type = UnitType.ARCHER
	max_hp = 35
	current_hp = 35
	move_speed = 5.5
	pierce_attack = 4
	melee_attack = 0
	melee_armor = 0
	pierce_armor = 0
	attack_range = 8.0
	attack_cooldown = 1.6
	left_hand_rotation = Vector3(0.0, 180.0, 0.0)

func _ready() -> void:
	super._ready()
	call_deferred("_equip_bow")

func _equip_bow() -> void:
	equip_item_left(bow_scene_path)

func _perform_attack(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var arrow_scene := load(ARROW_SCENE_PATH) as PackedScene
	if not arrow_scene:
		return
	var arrow := arrow_scene.instantiate()
	if not arrow:
		return
	arrow.set("target", target)
	arrow.set("attacker", self)
	arrow.set("damage", pierce_attack)
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	SoundManager.play_sound("arrow")
