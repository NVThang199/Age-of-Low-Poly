class_name BaseUnit
extends CharacterBody3D

signal died(unit: BaseUnit)
signal health_changed(current: int, max: int)

enum UnitType {
	VILLAGER = 0,
	INFANTRY = 1,
	ARCHER = 2,
	CAVALRY = 3,
}

enum UnitState {
	IDLE = 0,
	MOVING = 1,
	ATTACKING = 2,
	GATHERING = 3,
	BUILDING = 4,
	DEAD = 5,
}

@export var unit_type: UnitType = UnitType.INFANTRY
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
	call_deferred("_init_animations")

func _exit_tree() -> void:
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

func _init_animations() -> void:
	anim_player = find_child("AnimationPlayer", true, false)
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			var anim := anim_player.get_animation(anim_name)
			if anim:
				var n := anim_name.to_lower()
				if "loop" in n or "chop" in n or "walk" in n or "idle" in n or "carry" in n or "mine" in n or "farm" in n or "harvest" in n or "plant" in n:
					anim.loop_mode = Animation.LOOP_LINEAR
		var all_anims := anim_player.get_animation_list()
		if not all_anims.is_empty():
			for candidate in ["Idle_FoldArms", "Idle_Loop", "Idle"]:
				for a in all_anims:
					if candidate.to_lower() in a.to_lower():
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
		elif "walk" in lower or "run" in lower or "jog" in lower:
			for a in all_anims:
				if "walk" in a.to_lower() or "jog" in a.to_lower():
					target_a = a
					break
		elif "idle" in lower:
			for a in all_anims:
				if "idle_loop" in a.to_lower() or "idle_foldarms" in a.to_lower() or "idle" in a.to_lower():
					target_a = a
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

	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	attack_timer = maxf(0.0, attack_timer - delta)

	match state:
		UnitState.IDLE:
			play_anim("Idle_Loop")
			_scan_for_enemies()
		UnitState.MOVING:
			_process_movement(delta)
		UnitState.ATTACKING:
			_process_attack(delta)
		UnitState.BUILDING:
			pass

	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
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
	var units := get_tree().get_nodes_in_group("units")
	var nearest_enemy: Node = null
	var min_d := 9.0 # Tầm nhìn tự động cảnh giới (Aggro Range)
	for u in units:
		if u is BaseUnit and is_instance_valid(u) and u.owner_peer_id != owner_peer_id and u.state != UnitState.DEAD:
			var d := global_position.distance_to(u.global_position)
			if d < min_d:
				min_d = d
				nearest_enemy = u

	if not nearest_enemy:
		# Quét công trình đối phương lân cận
		var buildings := get_tree().get_nodes_in_group("buildings")
		for b in buildings:
			if b is BaseBuilding and is_instance_valid(b) and b.owner_peer_id != owner_peer_id:
				var d := global_position.distance_to(b.global_position)
				if d < min_d:
					min_d = d
					nearest_enemy = b

	if nearest_enemy:
		attack_target(nearest_enemy)

func _process_movement(delta: float) -> void:
	play_anim("Walk_Carry" if unit_type == UnitType.VILLAGER else "Walk_Loop")
	var diff := target_position - global_position
	diff.y = 0.0
	if diff.length() < 0.25:
		if state == UnitState.MOVING:
			state = UnitState.IDLE
		velocity = Vector3.ZERO
		stuck_timer = 0.0
		last_collision_normal = Vector3.ZERO
		return

	var dir := diff.normalized()
	var move_vec := dir

	# Lực tách cụm (Separation boid): tránh các đồng minh chen lấn, đâm đè lên nhau
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
		move_vec = (move_vec + sep.normalized() * 0.85).normalized()

	# Trượt mượt xung quanh vật cản (đá, tường, công trình) khi có va chạm
	if stuck_timer > 0.05 and last_collision_normal.length_squared() > 0.5:
		var slide_vec := dir.slide(last_collision_normal)
		slide_vec.y = 0.0
		if slide_vec.length_squared() > 0.05:
			move_vec = slide_vec.normalized()
		else:
			var tangent1 := Vector3(-last_collision_normal.z, 0.0, last_collision_normal.x).normalized()
			var tangent2 := -tangent1
			move_vec = tangent1 if dir.dot(tangent1) >= dir.dot(tangent2) else tangent2

	velocity = move_vec * move_speed
	if move_vec.length_squared() > 0.05:
		look_at(Vector3(global_position.x + move_vec.x, global_position.y, global_position.z + move_vec.z), Vector3.UP)

	var prev_pos := global_position
	move_and_slide()

	if get_slide_collision_count() > 0:
		var col := get_slide_collision(0)
		last_collision_normal = col.get_normal()
		var actual_dist := (global_position - prev_pos).length()
		if actual_dist < (move_speed * delta * 0.2):
			stuck_timer += delta
			if stuck_timer > 3.0:
				if state == UnitState.MOVING:
					state = UnitState.IDLE
				velocity = Vector3.ZERO
				stuck_timer = 0.0
				last_collision_normal = Vector3.ZERO
		else:
			stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 3.0)
		last_collision_normal = Vector3.ZERO

func _process_attack(_delta: float) -> void:
	if not is_instance_valid(target_entity):
		state = UnitState.IDLE
		target_entity = null
		return

	var dist := global_position.distance_to(target_entity.global_position)
	var effective_range := attack_range
	if target_entity is BaseBuilding:
		effective_range = maxf(attack_range, 3.8) # Bán kính chạm biên công trình

	if dist > effective_range:
		target_position = target_entity.global_position
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
		var damage: int = maxi(1, melee_attack - (target.melee_armor if "melee_armor" in target else 0))
		target.take_damage(damage, self)

func take_damage(amount: int, _attacker: Node = null) -> void:
	if state == UnitState.DEAD:
		return

	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		_die()

func _die() -> void:
	state = UnitState.DEAD
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

func move_to(target_pos: Vector3) -> void:
	target_position = target_pos
	target_entity = null
	state = UnitState.MOVING

func attack_target(target: Node) -> void:
	target_entity = target
	state = UnitState.ATTACKING

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
