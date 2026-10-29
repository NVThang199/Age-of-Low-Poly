# Fact 1: Called by scenes/entities/watch_tower.tscn:10, scripts/systems/building_placer.gd:52
# Fact 2: Verified no existing watch_tower.gd via Glob in scripts/entities/
# Fact 3: Extends BaseBuilding; instances scenes/entities/arrow_projectile.tscn
# Fact 4: User request: "tôi bảo bạn làm full game cho tôi hãy dùng cả blender mcp để làm mà đừng làm một vài chức năng làm full tất cả mọi thứ cho tôi làm sao để game giống game gốc"

class_name WatchTower
extends BaseBuilding

## Watch Tower (Chòi canh AoE 1)
## Công trình phòng thủ tự động:
## - Tự động quét và bắn tên vào kẻ thù trong phạm vi 9.5m khi đã xây xong.
## - Tốc độ bắn 1.4s/phát, sát thương 5 pierce, bắn từ đỉnh tháp.

const ARROW_SCENE_PATH := "res://scenes/entities/arrow_projectile.tscn"

@export var attack_range: float = 9.5
@export var attack_damage: int = 5
@export var attack_cooldown: float = 1.4

var _attack_timer: float = 0.0

func _init() -> void:
	building_type = BuildingType.WATCH_TOWER
	max_hp = 500
	current_hp = 500
	build_time = 30.0

func _process(delta: float) -> void:
	super._process(delta)
	if not is_constructed:
		return
	if multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _attack_timer <= 0.0:
		var target := _find_nearest_enemy()
		if target:
			_attack_timer = attack_cooldown
			_fire_arrow(target)

func _find_nearest_enemy() -> Node3D:
	var units := get_tree().get_nodes_in_group("units")
	var nearest: Node3D = null
	var min_dist := attack_range
	for u in units:
		if not is_instance_valid(u) or not (u is Node3D):
			continue
		var u_peer: int = u.owner_peer_id if "owner_peer_id" in u else 1
		if u_peer == owner_peer_id:
			continue
		if "state" in u and u.state == BaseUnit.UnitState.DEAD:
			continue
		var dist := global_position.distance_to(u.global_position)
		if dist <= min_dist:
			min_dist = dist
			nearest = u
	return nearest

func _fire_arrow(target: Node3D) -> void:
	var arrow_scene := load(ARROW_SCENE_PATH) as PackedScene
	if not arrow_scene:
		return
	var arrow := arrow_scene.instantiate()
	if not arrow:
		return
	arrow.set("target", target)
	arrow.set("attacker", self)
	arrow.set("damage", attack_damage)
	get_parent().add_child(arrow)
	# Bắn từ đỉnh chòi canh (cao 6.5m)
	arrow.global_position = global_position + Vector3(0.0, 6.5, 0.0)
	var sm := get_node_or_null("/root/SoundManager")
	if sm: sm.play_sound("arrow")
