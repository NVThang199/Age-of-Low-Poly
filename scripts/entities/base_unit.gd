class_name BaseUnit
extends CharacterBody3D

signal died(unit: BaseUnit)
signal health_changed(current: int, max: int)

enum UnitType {
	VILLAGER = 0,
	INFANTRY = 1,
	ARCHER = 2,
	CAVALRY = 3,
	PRIEST = 4,
	SIEGE = 5,
}

enum UnitState {
	IDLE = 0,
	MOVING = 1,
	ATTACKING = 2,
	GATHERING = 3,
	BUILDING = 4,
	DEAD = 5,
	HEALING = 6,
	CONVERTING = 7,
}

enum ActionSubState {
	NONE = 0,
	DONE = 1,
	WAIT = 2,
	SEARCH = 3,
	GOTO = 4,
	WORK = 6,
	RETURN = 8,
	MOVE = 11,
	ATTACK = 12,
	FAILED = 13,
	MOVE_NO_SEARCH = 15,
}

enum UnitStance {
	AGGRESSIVE = 0,
	DEFENSIVE = 1,
	STAND_GROUND = 2,
	NO_ATTACK = 3,
}

@export var unit_type: UnitType = UnitType.INFANTRY
@export var stance: UnitStance = UnitStance.AGGRESSIVE
var sub_state: ActionSubState = ActionSubState.NONE
var home_position: Vector3 = Vector3.ZERO
var command_queue: Array[Dictionary] = []
var _search_cooldown: float = 0.0
@export var owner_peer_id: int = 1:
	set(val):
		owner_peer_id = val
		_update_authority()
@export var move_speed: float = 6.0
@export var max_hp: int = 50
@export var current_hp: int = 50

const NET_SYNC_INTERVAL: float = 0.05
var _net_sync_timer: float = 0.0

@export var melee_attack: int = 5
@export var pierce_attack: int = 0
@export var melee_armor: int = 0
@export var pierce_armor: int = 1
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.2

var base_melee_attack: int = 5
var base_pierce_attack: int = 0
var base_melee_armor: int = 0
var base_pierce_armor: int = 1
var _stats_initialized: bool = false

@export_group("Equipment Sockets")
@export var right_hand_offset: Vector3 = Vector3.ZERO
@export var right_hand_rotation: Vector3 = Vector3.ZERO
@export var left_hand_offset: Vector3 = Vector3.ZERO
@export var left_hand_rotation: Vector3 = Vector3.ZERO
@export var right_tool_offset: Vector3 = Vector3.ZERO
@export var right_tool_rotation: Vector3 = Vector3.ZERO
@export var left_tool_offset: Vector3 = Vector3.ZERO
@export var left_tool_rotation: Vector3 = Vector3.ZERO

var state: UnitState = UnitState.IDLE
var target_position: Vector3 = Vector3.ZERO
var target_entity: Node = null
var attack_timer: float = 0.0
var stuck_timer: float = 0.0
var last_collision_normal: Vector3 = Vector3.ZERO
var avoidance_side: float = 0.0
var avoidance_timer: float = 0.0
var unmoving_timer: float = 0.0

var is_selected: bool = false
@onready var selection_ring: MeshInstance3D = null
var anim_player: AnimationPlayer = null

var _hand_r_attach: BoneAttachment3D = null
var _hand_l_attach: BoneAttachment3D = null
var _equipped_right_weapon: Node3D = null
var _equipped_left_weapon: Node3D = null

static var _tool_mat: StandardMaterial3D = null
static var _weapon_mat: StandardMaterial3D = null

static func _get_tool_material() -> StandardMaterial3D:
	if not _tool_mat:
		_tool_mat = StandardMaterial3D.new()
		var tex := load("res://assets/tools/tools_bits_texture.png") as Texture2D
		if tex:
			_tool_mat.albedo_texture = tex
		_tool_mat.roughness = 0.8
		_tool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _tool_mat

static func _get_weapon_material() -> StandardMaterial3D:
	if not _weapon_mat:
		_weapon_mat = StandardMaterial3D.new()
		var tex := load("res://assets/weapons/weapons_bits_texture.png") as Texture2D
		if tex:
			_weapon_mat.albedo_texture = tex
		_weapon_mat.roughness = 0.8
		_weapon_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _weapon_mat

static func _apply_equipment_material(item: Node3D, scene_path: String) -> void:
	if not item:
		return
	var mat: StandardMaterial3D = null
	if "tools" in scene_path:
		mat = _get_tool_material()
	elif "weapons" in scene_path:
		mat = _get_weapon_material()
	if not mat:
		return
	if item is MeshInstance3D:
		(item as MeshInstance3D).material_override = mat
	for child in item.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = mat

func _get_right_offset() -> Vector3:
	return right_tool_offset if right_tool_offset != Vector3.ZERO else right_hand_offset

func _get_right_rotation() -> Vector3:
	return right_tool_rotation if right_tool_rotation != Vector3.ZERO else right_hand_rotation

func _get_left_offset() -> Vector3:
	return left_tool_offset if left_tool_offset != Vector3.ZERO else left_hand_offset

func _get_left_rotation() -> Vector3:
	return left_tool_rotation if left_tool_rotation != Vector3.ZERO else left_hand_rotation

func get_skeleton() -> Skeleton3D:
	var skels := find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		return skels[0] as Skeleton3D
	return null

func get_hand_r() -> BoneAttachment3D:
	if _hand_r_attach and is_instance_valid(_hand_r_attach):
		return _hand_r_attach
	var skel := get_skeleton()
	if not skel:
		return null
	var bone_idx := _find_bone(skel, ["hand_r", "hand.r", "hand_right", "right_hand", "wrist_r"])
	if bone_idx == -1:
		return null
	var b_name := skel.get_bone_name(bone_idx)
	for child in skel.get_children():
		if child is BoneAttachment3D and (child as BoneAttachment3D).bone_name == b_name:
			_hand_r_attach = child as BoneAttachment3D
			return _hand_r_attach
	var existing_attach := find_child("BoneAttachment_HandR", true, false) as BoneAttachment3D
	if existing_attach:
		_hand_r_attach = existing_attach
		return _hand_r_attach
	_hand_r_attach = BoneAttachment3D.new()
	_hand_r_attach.name = "BoneAttachment_HandR"
	_hand_r_attach.bone_name = b_name
	skel.add_child(_hand_r_attach)
	return _hand_r_attach

func get_hand_l() -> BoneAttachment3D:
	if _hand_l_attach and is_instance_valid(_hand_l_attach):
		return _hand_l_attach
	var skel := get_skeleton()
	if not skel:
		return null
	var bone_idx := _find_bone(skel, ["hand_l", "hand.l", "hand_left", "left_hand", "wrist_l"])
	if bone_idx == -1:
		return null
	var b_name := skel.get_bone_name(bone_idx)
	for child in skel.get_children():
		if child is BoneAttachment3D and (child as BoneAttachment3D).bone_name == b_name:
			_hand_l_attach = child as BoneAttachment3D
			return _hand_l_attach
	var existing_attach := find_child("BoneAttachment_HandL", true, false) as BoneAttachment3D
	if existing_attach:
		_hand_l_attach = existing_attach
		return _hand_l_attach
	_hand_l_attach = BoneAttachment3D.new()
	_hand_l_attach.name = "BoneAttachment_HandL"
	_hand_l_attach.bone_name = b_name
	skel.add_child(_hand_l_attach)
	return _hand_l_attach

func get_right_socket() -> Node3D:
	var hand := get_hand_r()
	if hand:
		var sock := hand.get_node_or_null("RightHandSocket") as Node3D
		if sock:
			return sock
		sock = hand.find_child("RightHandSocket", true, false) as Node3D
		if sock:
			return sock
	var scene_sock := find_child("RightHandSocket", true, false) as Node3D
	if scene_sock:
		if hand and scene_sock.get_parent() != hand and not (scene_sock.get_parent() is BoneAttachment3D):
			var cur_transform := scene_sock.transform
			scene_sock.reparent(hand)
			scene_sock.transform = cur_transform
		return scene_sock
	return null

func get_left_socket() -> Node3D:
	var hand := get_hand_l()
	if hand:
		var sock := hand.get_node_or_null("LeftHandSocket") as Node3D
		if sock:
			return sock
		sock = hand.find_child("LeftHandSocket", true, false) as Node3D
		if sock:
			return sock
	var scene_sock := find_child("LeftHandSocket", true, false) as Node3D
	if scene_sock:
		if hand and scene_sock.get_parent() != hand and not (scene_sock.get_parent() is BoneAttachment3D):
			var cur_transform := scene_sock.transform
			scene_sock.reparent(hand)
			scene_sock.transform = cur_transform
		return scene_sock
	return null

func _find_bone(skel: Skeleton3D, candidates: Array) -> int:
	for cand in candidates:
		var idx := skel.find_bone(cand)
		if idx != -1:
			return idx
	for i in range(skel.get_bone_count()):
		var b_name := skel.get_bone_name(i).to_lower()
		for cand in candidates:
			if cand.to_lower() in b_name:
				return i
	return -1

func equip_item_right(scene_path: String) -> Node3D:
	var hand := get_hand_r()
	if not hand:
		return null

	var socket := get_right_socket()
	var parent_node: Node3D = socket if socket else hand

	if is_instance_valid(_equipped_right_weapon):
		_equipped_right_weapon.queue_free()
		_equipped_right_weapon = null

	for child in hand.get_children():
		if child != socket and child.name != "RightHandSocket":
			child.queue_free()
	if socket:
		for child in socket.get_children():
			child.queue_free()

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null

	var packed := load(scene_path) as PackedScene
	if not packed:
		return null
	_equipped_right_weapon = packed.instantiate() as Node3D
	_apply_equipment_material(_equipped_right_weapon, scene_path)
	parent_node.add_child(_equipped_right_weapon)

	if socket:
		_equipped_right_weapon.position = right_tool_offset
		_equipped_right_weapon.rotation_degrees = right_tool_rotation
	else:
		_equipped_right_weapon.position = _get_right_offset()
		_equipped_right_weapon.rotation_degrees = _get_right_rotation()

	return _equipped_right_weapon

func equip_item_left(scene_path: String) -> Node3D:
	var hand := get_hand_l()
	if not hand:
		return null

	var socket := get_left_socket()
	var parent_node: Node3D = socket if socket else hand

	if is_instance_valid(_equipped_left_weapon):
		_equipped_left_weapon.queue_free()
		_equipped_left_weapon = null

	for child in hand.get_children():
		if child != socket and child.name != "LeftHandSocket":
			child.queue_free()
	if socket:
		for child in socket.get_children():
			child.queue_free()

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null

	var packed := load(scene_path) as PackedScene
	if not packed:
		return null
	_equipped_left_weapon = packed.instantiate() as Node3D
	_apply_equipment_material(_equipped_left_weapon, scene_path)
	parent_node.add_child(_equipped_left_weapon)

	if socket:
		_equipped_left_weapon.position = left_tool_offset
		_equipped_left_weapon.rotation_degrees = left_tool_rotation
	else:
		_equipped_left_weapon.position = _get_left_offset()
		_equipped_left_weapon.rotation_degrees = _get_left_rotation()

	return _equipped_left_weapon

func _ready() -> void:
	add_to_group("units")
	current_hp = max_hp
	if not _stats_initialized:
		base_melee_attack = melee_attack
		base_pierce_attack = pierce_attack
		base_melee_armor = melee_armor
		base_pierce_armor = pierce_armor
		_stats_initialized = true
	apply_tech_modifiers()
	var tm = get_node_or_null("/root/TechManager")
	if tm and not tm.tech_completed.is_connected(_on_tech_completed):
		tm.tech_completed.connect(_on_tech_completed)
	_update_authority()
	_create_selection_ring()
	_create_hp_bar()
	home_position = global_position
	_search_cooldown = randf_range(0.0, 0.25)
	var sg = get_node_or_null("/root/SpatialGrid")
	if sg:
		sg.register_entity(self)
	call_deferred("_init_animations")

func _exit_tree() -> void:
	var sg = get_node_or_null("/root/SpatialGrid")
	if sg:
		sg.unregister_entity(self)
	var tm = get_node_or_null("/root/TechManager")
	if tm and tm.tech_completed.is_connected(_on_tech_completed):
		tm.tech_completed.disconnect(_on_tech_completed)

func _on_tech_completed(peer_id: int, _tech_id: String) -> void:
	if peer_id == owner_peer_id:
		apply_tech_modifiers()

func apply_tech_modifiers() -> void:
	var tm = get_node_or_null("/root/TechManager")
	if not tm:
		return
	var mods: Dictionary = tm.get_unit_modifiers(owner_peer_id, int(unit_type))
	melee_attack = base_melee_attack + mods.get("melee_attack", 0)
	pierce_attack = base_pierce_attack + mods.get("pierce_attack", 0)
	melee_armor = base_melee_armor + mods.get("melee_armor", 0)
	pierce_armor = base_pierce_armor + mods.get("pierce_armor", 0)

func _update_authority() -> void:
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(owner_peer_id)

@rpc("any_peer", "unreliable")
func sync_unit_state(pos: Vector3, rot_y: float, anim: String) -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_multiplayer_authority():
		return
	global_position = pos
	rotation.y = rot_y
	if anim != "":
		play_anim(anim)

static var _ual1_lib: AnimationLibrary = null

static func _get_ual1_lib() -> AnimationLibrary:
	if _ual1_lib == null:
		var s1: PackedScene = load("res://assets/animations/UAL1_Standard.glb")
		if s1:
			var n1 = s1.instantiate()
			var ap1: AnimationPlayer = n1.find_child("AnimationPlayer", true, false)
			if ap1 and ap1.has_animation_library(""):
				_ual1_lib = ap1.get_animation_library("").duplicate(true)
			n1.free()
	return _ual1_lib

func _init_animations() -> void:
	anim_player = find_child("AnimationPlayer", true, false)
	if anim_player:
		var ual1 := _get_ual1_lib()
		if ual1 and anim_player.has_animation_library(""):
			var default_lib := anim_player.get_animation_library("")
			for a_name in ual1.get_animation_list():
				if not default_lib.has_animation(a_name):
					default_lib.add_animation(a_name, ual1.get_animation(a_name))

		for anim_name in anim_player.get_animation_list():
			var anim := anim_player.get_animation(anim_name)
			if anim:
				var n := anim_name.to_lower()
				if "loop" in n or "chop" in n or "walk" in n or "idle" in n or "carry" in n or "mine" in n or "farm" in n or "harvest" in n or "plant" in n or "sprint" in n or "run" in n or "jog" in n:
					anim.loop_mode = Animation.LOOP_LINEAR
		var all_anims := anim_player.get_animation_list()
		if not all_anims.is_empty():
			for candidate in ["Idle", "Idle_FoldArms", "Idle_Loop"]:
				for a in all_anims:
					if a == candidate or a.ends_with("/" + candidate) or a.to_lower() == candidate.to_lower():
						anim_player.play(a)
						return
			anim_player.play(all_anims[0])

func play_anim(anim_name: String) -> void:
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false)
	if not anim_player:
		return

	var all_anims := anim_player.get_animation_list()
	var target_a := ""

	for a in all_anims:
		if a == anim_name or a.ends_with("/" + anim_name) or a.to_lower() == anim_name.to_lower():
			target_a = a
			break

	if target_a.is_empty():
		var lower := anim_name.to_lower()
		if "chop" in lower or "wood" in lower or "tree" in lower or "mine" in lower or "stone" in lower or "gold" in lower:
			for a in all_anims:
				if "treechopping" in a.to_lower() or "melee_hook" in a.to_lower():
					target_a = a
					break
		elif "harvest" in lower or "food" in lower or "berry" in lower or "farm" in lower:
			for a in all_anims:
				if "farm_harvest" in a.to_lower() or "consume" in a.to_lower():
					target_a = a
					break
		elif "carry" in lower:
			for a in all_anims:
				if "walk_carry" in a.to_lower():
					target_a = a
					break
		elif "sprint" in lower or "walk" in lower or "run" in lower or "jog" in lower:
			for a in all_anims:
				if "sprint" in a.to_lower() or "walk" in a.to_lower() or "jog" in a.to_lower():
					target_a = a
					break
		elif "idle" in lower:
			for candidate in ["Idle", "Idle_FoldArms", "Idle_Loop"]:
				for a in all_anims:
					if a == candidate or a.ends_with("/" + candidate) or a.to_lower() == candidate.to_lower():
						target_a = a
						break
				if not target_a.is_empty():
					break
		elif "aim" in lower or "bow" in lower or "shoot" in lower:
			for a in all_anims:
				if "pistol_aim_neutral" in a.to_lower() or "pistol_idle" in a.to_lower() or "aim" in a.to_lower():
					target_a = a
					break
		elif "sword" in lower or "attack" in lower or "punch" in lower or "slash" in lower:
			for a in all_anims:
				if "sword_regular" in a.to_lower() or "punch" in a.to_lower():
					target_a = a
					break

	if not target_a.is_empty():
		var anim := anim_player.get_animation(target_a)
		if anim and anim.loop_mode == Animation.LOOP_NONE:
			var n := target_a.to_lower()
			if "chop" in n or "walk" in n or "idle" in n or "carry" in n or "harvest" in n:
				anim.loop_mode = Animation.LOOP_LINEAR
		if anim_player.current_animation != target_a or not anim_player.is_playing():
			anim_player.play(target_a)

func _physics_process(delta: float) -> void:
	if state == UnitState.DEAD:
		return

	if hp_bar_pivot and hp_bar_pivot.visible:
		var cam := get_viewport().get_camera_3d()
		if cam:
			hp_bar_pivot.look_at(cam.global_position, Vector3.UP)

	if multiplayer and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	_search_cooldown = maxf(0.0, _search_cooldown - delta)

	match state:
		UnitState.IDLE:
			play_anim("Idle")
			_scan_for_enemies()
		UnitState.MOVING:
			_process_movement(delta)
			if sub_state != ActionSubState.MOVE_NO_SEARCH:
				_scan_for_enemies()
		UnitState.ATTACKING:
			_process_attack(delta)
		UnitState.BUILDING:
			pass

	if multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and is_multiplayer_authority():
		_net_sync_timer += delta
		if _net_sync_timer >= NET_SYNC_INTERVAL:
			_net_sync_timer = 0.0
			var current_anim: String = ""
			if anim_player and is_instance_valid(anim_player) and anim_player.is_playing():
				current_anim = anim_player.current_animation
			var my_id := multiplayer.get_unique_id()
			var net_mgr = get_node_or_null("/root/NetworkManager")
			if net_mgr and "connected_peers" in net_mgr:
				for target_id: int in net_mgr.connected_peers:
					if target_id != my_id:
						sync_unit_state.rpc_id(target_id, global_position, rotation.y, current_anim)
				if not multiplayer.is_server() and not net_mgr.connected_peers.has(1):
					sync_unit_state.rpc_id(1, global_position, rotation.y, current_anim)

func _scan_for_enemies() -> void:
	if unit_type == UnitType.VILLAGER:
		return # Dân làng không tự động săn lùng kẻ thù
	if sub_state == ActionSubState.MOVE_NO_SEARCH:
		return # Lệnh ép di chuyển bỏ qua quét mục tiêu
	if stance == UnitStance.NO_ATTACK:
		return

	if _search_cooldown > 0.0:
		return
	_search_cooldown = 0.25 # Staggered 4Hz scan

	var candidates: Array[Node3D] = []
	var sg = get_node_or_null("/root/SpatialGrid")
	if sg:
		candidates = sg.search_radius(global_position, 12.0)
	else:
		for u in get_tree().get_nodes_in_group("units"):
			if u is Node3D: candidates.append(u as Node3D)
		for b in get_tree().get_nodes_in_group("buildings"):
			if b is Node3D: candidates.append(b as Node3D)

	var best_target: Node3D = null
	var best_score: float = -INF

	for cand in candidates:
		if not is_instance_valid(cand):
			continue
		var cand_peer: int = cand.owner_peer_id if "owner_peer_id" in cand else 1
		if cand_peer == owner_peer_id:
			continue
		if "state" in cand and cand.state == UnitState.DEAD:
			continue

		var dist := global_position.distance_to(cand.global_position)
		if stance == UnitStance.STAND_GROUND and dist > attack_range:
			continue
		if stance == UnitStance.DEFENSIVE and home_position != Vector3.ZERO:
			if home_position.distance_to(cand.global_position) > 8.0:
				continue

		var score := TargetEvaluator.evaluate(self, cand)
		if score > best_score:
			best_score = score
			best_target = cand

	if best_target and best_score > -100.0:
		attack_target(best_target)

func _process_movement(delta: float) -> void:
	if unit_type == UnitType.VILLAGER:
		var is_carrying: bool = ("carried_amount" in self and self.carried_amount > 0) or ("is_delivering" in self and self.is_delivering)
		play_anim("Walk_Carry" if is_carrying else "Sprint")
	else:
		play_anim("Walk_Loop")

	var diff := target_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var stop_threshold: float = maxf(0.35, move_speed * delta * 1.5)
	if dist <= stop_threshold:
		global_position = Vector3(target_position.x, global_position.y, target_position.z)
		var sg = get_node_or_null("/root/SpatialGrid")
		if sg:
			sg.update_entity(self)
		if state == UnitState.MOVING:
			state = UnitState.IDLE
			sub_state = ActionSubState.NONE
			pop_next_command()
		velocity = Vector3.ZERO
		stuck_timer = 0.0
		unmoving_timer = 0.0
		avoidance_timer = 0.0
		avoidance_side = 0.0
		last_collision_normal = Vector3.ZERO
		play_anim("Idle")
		return

	var target_dir := diff.normalized()

	# 1. Phát hiện chướng ngại vật cản đường thẳng (Look-ahead test_move)
	# Né vật thể tĩnh (nhà, cây, đá, tường) và né NPC đang đứng yên/thao tác cản đường
	var col := KinematicCollision3D.new()
	var lookahead_dist: float = maxf(0.85, move_speed * delta * 4.0)
	var is_blocked := test_move(global_transform, target_dir * lookahead_dist, col)
	var obstacle_normal := Vector3.ZERO

	if is_blocked and col:
		var collider = col.get_collider()
		var is_unit = collider is BaseUnit or (collider and collider.is_in_group("units"))
		if not is_unit:
			var n := col.get_normal()
			if absf(n.y) < 0.7:
				obstacle_normal = Vector3(n.x, 0.0, n.z).normalized()
		else:
			var other: BaseUnit = collider as BaseUnit
			# Nếu NPC phía trước đang đứng yên/thao tác (khai thác, xây dựng, idle, đánh nhau)
			# hoặc di chuyển rất chậm, coi đó là vật cản cần chủ động đánh lái vòng qua
			var is_stationary := not is_instance_valid(other) or other.velocity.length_squared() < 0.2 or other.state != UnitState.MOVING
			if is_stationary:
				var away := (global_position - other.global_position)
				away.y = 0.0
				if away.length_squared() > 0.001:
					obstacle_normal = away.normalized()
				else:
					var n := col.get_normal()
					obstacle_normal = Vector3(n.x, 0.0, n.z).normalized()
			else:
				is_blocked = false # Đồng đội đang cùng di chuyển xử lý qua separation boid

	var move_vec := target_dir

	# 2. Chủ động điều hướng né vật thể tĩnh (Obstacle Avoidance / Tangent Wall-Following)
	if is_blocked and obstacle_normal != Vector3.ZERO:
		last_collision_normal = obstacle_normal
		var t1 := Vector3(-obstacle_normal.z, 0.0, obstacle_normal.x) # Tiếp tuyến rẽ phải
		var t2 := Vector3(obstacle_normal.z, 0.0, -obstacle_normal.x) # Tiếp tuyến rẽ trái

		if avoidance_side == 0.0:
			var cross_y := target_dir.cross(obstacle_normal).y
			if absf(cross_y) > 0.01:
				avoidance_side = 1.0 if cross_y > 0.0 else -1.0
			else:
				var dot1 := t1.dot(target_dir)
				var dot2 := t2.dot(target_dir)
				if absf(dot1 - dot2) > 0.05:
					avoidance_side = 1.0 if dot1 > dot2 else -1.0
				else:
					avoidance_side = 1.0 if (get_instance_id() % 2 == 0) else -1.0

		var chosen_tangent := t1 if avoidance_side > 0.0 else t2

		# Triệt tiêu thành phần của target_dir đâm thẳng vào tường để lướt mượt mà không bị cản ma sát
		var forward_along_wall := target_dir
		var into_wall := forward_along_wall.dot(obstacle_normal)
		if into_wall < 0.0:
			forward_along_wall -= obstacle_normal * into_wall

		move_vec = (chosen_tangent * 0.85 + forward_along_wall * 0.4).normalized()
		avoidance_timer += delta
	else:
		# Đường thẳng tới đích thông thoáng
		avoidance_side = 0.0
		avoidance_timer = maxf(0.0, avoidance_timer - delta * 2.0)
		last_collision_normal = Vector3.ZERO

	# 3. Lực tách cụm (Separation boid): tránh đồng minh chen lấn, dẫm đè lên nhau
	var sep := Vector3.ZERO
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if u != self and u is BaseUnit and is_instance_valid(u):
			var to_me := global_position - (u as BaseUnit).global_position
			to_me.y = 0.0
			var d_sq := to_me.length_squared()
			if d_sq > 0.0001 and d_sq < 2.25: # Cự ly va chạm đồng đội < 1.5m
				var d := sqrt(d_sq)
				sep += (to_me / d) * ((1.5 - d) / 1.5)

	if sep.length_squared() > 0.01:
		var sep_dir := sep.normalized()
		var opposing := sep_dir.dot(move_vec)
		if opposing < -0.05:
			# Khi bị chặn đối đầu trực diện hoặc kẹp giữa các đồng đội:
			# Tạo lực né sườn (lateral dodge) vuông góc với hướng di chuyển để lách sang mép
			var lateral := Vector3(-move_vec.z, 0.0, move_vec.x)
			var cross_y := sep_dir.cross(move_vec).y
			var lat_sign := 1.0 if cross_y > 0.0 else -1.0
			if absf(cross_y) < 0.05:
				lat_sign = 1.0 if (get_instance_id() % 2 == 0) else -1.0
			sep_dir = (lateral * lat_sign * 0.9 + (sep_dir - move_vec * opposing) * 0.3).normalized()
			move_vec = (move_vec * 0.35 + sep_dir * 0.85).normalized()
		else:
			move_vec = (move_vec + sep_dir * 0.4).normalized()

	velocity = move_vec * move_speed
	if move_vec.length_squared() > 0.05:
		var target_rot_y := atan2(-move_vec.x, -move_vec.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 14.0 * delta)

	var prev_pos := global_position
	move_and_slide()

	# 4. Cập nhật va chạm thực tế từ slide collision
	var hit_obstacle := false
	for i in range(get_slide_collision_count()):
		var col_slide := get_slide_collision(i)
		var c = col_slide.get_collider()
		if c:
			var is_c_unit: bool = (c is BaseUnit) or (c.has_method("is_in_group") and c.is_in_group("units"))
			if not is_c_unit:
				var n := col_slide.get_normal()
				if absf(n.y) < 0.7:
					last_collision_normal = Vector3(n.x, 0.0, n.z).normalized()
					hit_obstacle = true
					break
			else:
				var other_unit: BaseUnit = c as BaseUnit
				if is_instance_valid(other_unit) and (other_unit.velocity.length_squared() < 0.2 or other_unit.state != UnitState.MOVING):
					var away := (global_position - other_unit.global_position)
					away.y = 0.0
					if away.length_squared() > 0.001:
						last_collision_normal = away.normalized()
						hit_obstacle = true
						break

	# 5. Phát hiện kẹt (CHỈ dừng về IDLE khi thật sự không thể di chuyển hoặc đích bị vây kín hoàn toàn)
	var physical_disp := (global_position - prev_pos).length()
	if (hit_obstacle or is_blocked) and physical_disp < (move_speed * delta * 0.25):
		stuck_timer += delta
		unmoving_timer += delta
		if unmoving_timer > 1.2: # Bị kẹt cứng trong góc chết 1.2s không nhích được
			if state == UnitState.MOVING:
				state = UnitState.IDLE
			velocity = Vector3.ZERO
			stuck_timer = 0.0
			unmoving_timer = 0.0
			avoidance_timer = 0.0
			avoidance_side = 0.0
			last_collision_normal = Vector3.ZERO
			play_anim("Idle")
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)
		unmoving_timer = maxf(0.0, unmoving_timer - delta * 2.0)

	# Nếu đã đi vòng né vật thể quá lâu (4.5 giây) mà đích vẫn bị vây kín không có đường vào
	if avoidance_timer > 4.5:
		if state == UnitState.MOVING:
			state = UnitState.IDLE
		velocity = Vector3.ZERO
		stuck_timer = 0.0
		unmoving_timer = 0.0
		avoidance_timer = 0.0
		avoidance_side = 0.0
		last_collision_normal = Vector3.ZERO
		play_anim("Idle")

func _process_attack(_delta: float) -> void:
	if not is_instance_valid(target_entity):
		state = UnitState.IDLE
		sub_state = ActionSubState.NONE
		target_entity = null
		pop_next_command()
		return

	# Kiểm tra Leash distance cho tư thế phòng thủ (Defensive Stance)
	if stance == UnitStance.DEFENSIVE and home_position != Vector3.ZERO:
		if global_position.distance_to(home_position) > 8.0:
			target_entity = null
			move_to(home_position, ActionSubState.GOTO)
			return

	var dist := global_position.distance_to((target_entity as Node3D).global_position)
	var effective_range := attack_range
	if target_entity is BaseBuilding:
		effective_range = maxf(attack_range, 3.8) # Bán kính chạm biên công trình

	# Tư thế giữ vị trí: nếu mục tiêu ngoài tầm, ngừng truy đuổi
	if stance == UnitStance.STAND_GROUND and dist > effective_range:
		target_entity = null
		state = UnitState.IDLE
		sub_state = ActionSubState.NONE
		return

	if dist > effective_range:
		if target_entity is BaseBuilding:
			var b_pos: Vector3 = (target_entity as Node3D).global_position
			var to_me: Vector3 = global_position - b_pos
			to_me.y = 0.0
			var approach_dir: Vector3 = to_me.normalized() if to_me.length_squared() > 0.05 else Vector3.FORWARD
			target_position = b_pos + approach_dir * (effective_range - 0.5)
		else:
			target_position = (target_entity as Node3D).global_position
		_process_movement(_delta)
		return

	velocity = Vector3.ZERO
	# Quay mặt về phía mục tiêu
	if target_entity is Node3D:
		var t_pos: Vector3 = (target_entity as Node3D).global_position
		if global_position.distance_to(t_pos) > 0.1:
			look_at(Vector3(t_pos.x, global_position.y, t_pos.z), Vector3.UP)

	if unit_type == UnitType.ARCHER:
		play_anim("Pistol_Aim_Neutral")
	else:
		play_anim("Sword_Regular_Combo")

	if attack_timer <= 0.0:
		attack_timer = attack_cooldown
		_perform_attack(target_entity)

func _perform_attack(target: Node) -> void:
	if target.has_method("take_damage"):
		var elev_mod: float = 1.0
		if target is Node3D:
			var diff_y: float = global_position.y - (target as Node3D).global_position.y
			if diff_y >= 0.8:
				elev_mod = 1.33 # Đánh từ trên cao xuống +33%
			elif diff_y <= -0.8:
				elev_mod = 0.67 # Đánh từ chân dốc lên -33%
		var raw_dmg: int = melee_attack - (target.melee_armor if "melee_armor" in target else 0)
		var damage: int = maxi(1, int(round(float(raw_dmg) * elev_mod)))
		target.take_damage(damage, self)

func take_damage(amount: int, _attacker: Node = null) -> void:
	if state == UnitState.DEAD:
		return

	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	# Phản công tự vệ nếu đang rảnh và không ở tư thế NO_ATTACK
	if _attacker and is_instance_valid(_attacker) and state == UnitState.IDLE and stance != UnitStance.NO_ATTACK:
		attack_target(_attacker)

	if current_hp <= 0:
		_die()

func _die() -> void:
	state = UnitState.DEAD
	sub_state = ActionSubState.NONE
	command_queue.clear()
	var sg = get_node_or_null("/root/SpatialGrid")
	if sg:
		sg.unregister_entity(self)
	died.emit(self)
	remove_from_group("units")
	set_selected(false)

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.player_population.has(owner_peer_id):
		game_mgr.player_population[owner_peer_id]["current"] = maxi(0, game_mgr.player_population[owner_peer_id]["current"] - 1)
		game_mgr.population_updated.emit(
			owner_peer_id,
			game_mgr.player_population[owner_peer_id]["current"],
			game_mgr.player_population[owner_peer_id]["max"]
		)

	# Chạy animation gục ngã hoặc biến mất
	play_anim("Death01")
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_callback(queue_free)

func move_to(target_pos: Vector3, new_sub_state: ActionSubState = ActionSubState.MOVE_NO_SEARCH) -> void:
	target_position = target_pos
	target_entity = null
	state = UnitState.MOVING
	sub_state = new_sub_state
	stuck_timer = 0.0
	unmoving_timer = 0.0
	avoidance_timer = 0.0
	avoidance_side = 0.0
	last_collision_normal = Vector3.ZERO

func attack_target(target: Node) -> void:
	target_entity = target
	state = UnitState.ATTACKING
	sub_state = ActionSubState.ATTACK

func queue_command(cmd: Dictionary) -> void:
	command_queue.append(cmd)

func pop_next_command() -> void:
	if command_queue.is_empty():
		return
	var next_cmd: Dictionary = command_queue.pop_front()
	var cmd_type: String = next_cmd.get("type", "move")
	var pos: Vector3 = next_cmd.get("target_pos", next_cmd.get("pos", Vector3.ZERO))
	var target_node: Node = next_cmd.get("target_node", next_cmd.get("target", null))
	match cmd_type:
		"move", "move_no_search":
			move_to(pos, ActionSubState.MOVE_NO_SEARCH)
		"attack_move":
			move_to(pos, ActionSubState.GOTO)
		"attack":
			if is_instance_valid(target_node):
				attack_target(target_node)
			else:
				move_to(pos)
		"gather":
			if has_method("gather_from") and is_instance_valid(target_node):
				call("gather_from", target_node)
			else:
				move_to(pos)
		"deposit":
			if has_method("return_resources_to") and is_instance_valid(target_node):
				call("return_resources_to", target_node)
			else:
				move_to(pos)
		"build":
			if has_method("construct_building") and is_instance_valid(target_node):
				call("construct_building", target_node)
			else:
				move_to(pos)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected
	if hp_bar_pivot:
		hp_bar_pivot.visible = selected or (current_hp < max_hp)

var hp_bar_pivot: Node3D = null
var hp_bar_fill: MeshInstance3D = null

func _create_hp_bar() -> void:
	if find_child("HealthBarPivot", true, false):
		return # Đã có sẵn trong scene
	hp_bar_pivot = Node3D.new()
	hp_bar_pivot.name = "AutoHealthBar"
	hp_bar_pivot.position = Vector3(0.0, 2.1, 0.0)

	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(1.0, 0.12)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	hp_bar_pivot.add_child(bg)

	hp_bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.96, 0.09)
	hp_bar_fill.mesh = fill_mesh
	hp_bar_fill.position.z = 0.01
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 1.0, 0.2, 1.0) if owner_peer_id == 1 else Color(1.0, 0.2, 0.2, 1.0)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bar_fill.material_override = fill_mat
	hp_bar_pivot.add_child(hp_bar_fill)

	hp_bar_pivot.visible = false
	add_child(hp_bar_pivot)

	health_changed.connect(func(curr, m_val):
		if hp_bar_fill:
			var ratio: float = float(curr) / float(m_val) if m_val > 0 else 0.0
			hp_bar_fill.scale.x = ratio
			if hp_bar_pivot:
				hp_bar_pivot.visible = is_selected or (curr < m_val)
	)

func _create_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 0.95
	selection_ring.mesh = torus
	selection_ring.position.y = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.2, 0.9) if owner_peer_id == 1 else Color(1.0, 0.2, 0.2, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_ring.material_override = mat
	selection_ring.visible = false
	add_child(selection_ring)
