# Fact 1: Called by scripts/systems/command_manager.gd, scenes/entities/priest.tscn
# Fact 2: Verified no existing priest script via Glob in scripts/entities/
# Fact 3: In-memory only; extends BaseUnit
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

class_name Priest
extends BaseUnit

## Priest (Phù thủy - Đời 3 Bronze Age)
## Tái hiện cơ chế Phù thủy kinh điển trong AOE 1:
## 1. Hồi máu (Heal) cho quân ta bị thương.
## 2. Hú chuyển hóa (Convert / Wololo!) lính và nhà của quân địch sang phe mình.
## 3. Hệ thống Mana/Niềm tin (Faith) hồi phục theo thời gian.

@export_group("Weapons")
@export var staff_scene_path: String = "res://assets/weapons/spear_A.fbx"

@export_group("Priest Stats")
@export var heal_range: float = 8.0
@export var convert_range: float = 9.5
@export var convert_duration: float = 6.0 # Thời gian hú để thu phục

var is_priest: bool = true
var target_heal_unit: BaseUnit = null
var target_convert_node: Node3D = null

var faith: float = 100.0
var max_faith: float = 100.0
var faith_regen_rate: float = 6.5 # Hồi phục sau ~15 giây
var _convert_progress: float = 0.0

func _init() -> void:
	unit_type = UnitType.PRIEST
	max_hp = 25
	current_hp = 25
	move_speed = 4.2
	melee_attack = 0
	pierce_attack = 0
	melee_armor = 0
	pierce_armor = 0
	attack_range = convert_range
	attack_cooldown = 1.0
	right_hand_rotation = Vector3(0.0, 90.0, 0.0)

func _ready() -> void:
	super._ready()
	call_deferred("_equip_staff")

func _equip_staff() -> void:
	equip_item_right(staff_scene_path)

func heal_unit(target: BaseUnit) -> void:
	target_heal_unit = target
	target_convert_node = null
	target_entity = target
	state = UnitState.ATTACKING

func convert_target(target: Node3D) -> void:
	target_convert_node = target
	target_heal_unit = null
	target_entity = target
	state = UnitState.ATTACKING

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Hồi phục niềm tin (Faith)
	if faith < max_faith:
		faith = minf(max_faith, faith + faith_regen_rate * delta)

	if is_instance_valid(target_heal_unit):
		_process_healing(delta)
	elif is_instance_valid(target_convert_node):
		_process_conversion(delta)

func _process_healing(delta: float) -> void:
	if not is_instance_valid(target_heal_unit) or target_heal_unit.state == UnitState.DEAD or target_heal_unit.current_hp >= target_heal_unit.max_hp:
		target_heal_unit = null
		state = UnitState.IDLE
		play_anim("Idle")
		return

	var dist := global_position.distance_to(target_heal_unit.global_position)
	if dist > heal_range:
		target_position = target_heal_unit.global_position
		_process_movement(delta)
		return

	# Dừng lại và làm phép hồi máu
	velocity = Vector3.ZERO
	_face_target(target_heal_unit.global_position, delta)
	play_anim("Pistol_Aim_Neutral")

	# Hồi 4 HP mỗi giây
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		target_heal_unit.current_hp = mini(target_heal_unit.max_hp, target_heal_unit.current_hp + int(ceilf(4.0 * delta)))
		target_heal_unit.health_changed.emit(target_heal_unit.current_hp, target_heal_unit.max_hp)

func _process_conversion(delta: float) -> void:
	if not is_instance_valid(target_convert_node) or faith < 100.0:
		target_convert_node = null
		_convert_progress = 0.0
		state = UnitState.IDLE
		play_anim("Idle")
		return

	if "state" in target_convert_node and target_convert_node.state == UnitState.DEAD:
		target_convert_node = null
		_convert_progress = 0.0
		state = UnitState.IDLE
		play_anim("Idle")
		return

	var dist := global_position.distance_to(target_convert_node.global_position)
	if dist > convert_range:
		target_position = target_convert_node.global_position
		_process_movement(delta)
		return

	# Dừng lại và niệm thần chú Wololo!
	velocity = Vector3.ZERO
	_face_target(target_convert_node.global_position, delta)
	play_anim("Sword_Regular_Combo")

	# Tốc độ thu phục được tăng cường bởi công nghệ Astrology (TechManager)
	var tm = get_node_or_null("/root/TechManager")
	var rate_bonus: float = 1.0
	if tm:
		var mods: Dictionary = tm.get_unit_modifiers(owner_peer_id, int(unit_type))
		rate_bonus += float(mods.get("conversion_rate", 0)) / 100.0

	_convert_progress += delta * rate_bonus

	if _convert_progress >= convert_duration:
		_convert_progress = 0.0
		faith = 0.0 # Xả sạch mana sau khi thu phục thành công
		_execute_conversion(target_convert_node)
		target_convert_node = null
		state = UnitState.IDLE
		play_anim("Idle")

func _face_target(t_pos: Vector3, delta: float) -> void:
	var diff := t_pos - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.05:
		var target_rot_y := atan2(-diff.x, -diff.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 12.0 * delta)

func _execute_conversion(target: Node3D) -> void:
	if not (multiplayer.is_server() or not multiplayer.has_multiplayer_peer()):
		return

	if "owner_peer_id" in target:
		target.owner_peer_id = owner_peer_id
		if target.has_method("set_multiplayer_authority"):
			target.set_multiplayer_authority(owner_peer_id)
		# Đồng bộ đổi phe trên toàn bộ peers
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and "connected_peers" in net_mgr:
			for pid in net_mgr.connected_peers:
				if pid != 1:
					sync_unit_converted.rpc_id(pid, target.get_path(), owner_peer_id)

@rpc("authority", "call_local", "reliable")
func sync_unit_converted(target_path: NodePath, new_owner: int) -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	var node := get_node_or_null(target_path)
	if is_instance_valid(node) and "owner_peer_id" in node:
		node.owner_peer_id = new_owner
		if node.has_method("set_multiplayer_authority"):
			node.set_multiplayer_authority(new_owner)
# ponytail: Single convert target; add AOE group chant when faith tech is researched.
