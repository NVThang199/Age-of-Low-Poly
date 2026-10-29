class_name EnemyAI
extends Node

## EnemyAI
## Quản lý chiến thuật máy: tự động phát động các đợt tấn công (raid waves)
## từ căn cứ địch nhắm vào căn cứ người chơi (AoE style).

@export var enemy_peer_id: int = 2
@export var wave_interval: float = 35.0
@export var first_wave_delay: float = 15.0

var _wave_timer: float = 15.0
var _wave_index: int = 1

const SWORDSMAN_SCENE_PATH := "res://scenes/entities/swordsman.tscn"
const ARCHER_SCENE_PATH := "res://scenes/entities/archer.tscn"

func _ready() -> void:
	_wave_timer = first_wave_delay
	print("EnemyAI initialized. First raid wave in %s seconds." % _wave_timer)

func _process(delta: float) -> void:
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = wave_interval
		_trigger_raid_wave()

func _trigger_raid_wave() -> void:
	print("EnemyAI: Launching Raid Wave #%d!" % _wave_index)
	var sm := get_node_or_null("/root/SoundManager")
	if sm: sm.play_sound("horn")
	var swordsman_scene := load(SWORDSMAN_SCENE_PATH) as PackedScene
	var archer_scene := load(ARCHER_SCENE_PATH) as PackedScene

	var base_target_pos := Vector3.ZERO
	var tc := get_tree().get_first_node_in_group("buildings")
	if tc is Node3D and is_instance_valid(tc):
		base_target_pos = (tc as Node3D).global_position

	var num_swordsmen := 1 + _wave_index
	var num_archers := mini(4, _wave_index)

	var spawn_origin := Vector3(-28.0, 0.0, -28.0)

	for i in range(num_swordsmen):
		if swordsman_scene:
			var sm := swordsman_scene.instantiate() as BaseUnit
			sm.owner_peer_id = enemy_peer_id
			sm.position = spawn_origin + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
			get_parent().add_child(sm)
			sm.move_to(base_target_pos + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0)))

	for j in range(num_archers):
		if archer_scene:
			var arc := archer_scene.instantiate() as BaseUnit
			arc.owner_peer_id = enemy_peer_id
			arc.position = spawn_origin + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			get_parent().add_child(arc)
			arc.move_to(base_target_pos + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0)))

	_wave_index += 1
