# Fact 1: Called by scripts/systems/command_manager.gd:80, scripts/systems/selection_system.gd:64, scripts/ui/hud.gd:220
# Fact 2: Verified no existing animal scripts via Glob in scripts/entities/
# Fact 3: CharacterBody3D node hierarchy with Godot 4 text scene schema, exports meat_amount, current_hp, emits animal_died, resource_gathered
# Fact 4: User verbatim instruction: "cũng như bạn chưa hề làm voi, sư tử, nai, cũng như chưa có cơ chế random map hoặc xây theo loại map highland hay một loạt các loại map ở game gốc, tôi cần bạn clone i nguyên sang cho tôi C:\Users\nguye\Downloads\Age of Empires 1_Linkneverdie.com\Age of Empires 1_Linkneverdie.com\Age of Empires"

class_name BaseAnimal
extends CharacterBody3D

enum Behavior {
	PREY = 0,             # Nai (Gazelle): Bỏ chạy khi có đơn vị lại gần
	PREDATOR = 1,         # Sư tử (Lion), Cá sấu: Chủ động tấn công đơn vị trong tầm nhìn
	NEUTRAL_DEFENDER = 2  # Voi (Elephant): Hiền lành cho đến khi bị tấn công, sau đó truy đuổi người đánh (kiting)
}

enum AnimalState {
	IDLE = 0,
	ROAMING = 1,
	FLEEING = 2,
	PURSUING = 3,
	ATTACKING = 4,
	DEAD = 5
}

@export var animal_name: String = "Animal"
@export var behavior: Behavior = Behavior.PREY
@export var max_hp: int = 25
@export var current_hp: int = 25
@export var meat_amount: int = 150
@export var move_speed: float = 3.5
@export var run_speed: float = 5.5
@export var attack_damage: int = 0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.4
@export var alert_range: float = 9.0
@export var leash_range: float = 26.0

# Resource properties for carcass harvesting
var resource_type: int = 0 # ResourceSource.ResourceType.FOOD
var is_meat: bool = true
var current_amount: int = 150
var max_amount: int = 150

var state: AnimalState = AnimalState.IDLE
var target_entity: Node = null
var target_position: Vector3 = Vector3.ZERO
var home_position: Vector3 = Vector3.ZERO

var attack_timer: float = 0.0
var roam_timer: float = 2.0
var scan_timer: float = 0.3

var selection_ring: MeshInstance3D = null
var is_selected: bool = false
var mesh_node: Node3D = null
var hp_bar_pivot: Node3D = null

signal animal_died(animal: BaseAnimal)
signal health_changed(curr: int, max_v: int)
signal resource_gathered(type: int, amount: int)
signal resource_depleted(source: Node)

func _ready() -> void:
	add_to_group("animals")
	add_to_group("selectable")
	current_hp = max_hp
	current_amount = meat_amount
	max_amount = meat_amount
	home_position = global_position
	target_position = global_position

	_setup_mesh_and_collision()
	_create_selection_ring()
	_setup_hp_bar()

func _setup_mesh_and_collision() -> void:
	mesh_node = get_node_or_null("Model")
	if not mesh_node:
		for child in get_children():
			if child is MeshInstance3D or (child is Node3D and child.name != "SelectionRing" and child.name != "HealthBarPivot"):
				mesh_node = child
				break

func _create_selection_ring() -> void:
	if selection_ring:
		return
	selection_ring = MeshInstance3D.new()
	selection_ring.name = "SelectionRing"
	var torus := TorusMesh.new()
	var r: float = 1.2 if behavior == Behavior.PREY else (2.2 if behavior == Behavior.NEUTRAL_DEFENDER else 1.5)
	torus.inner_radius = r - 0.12
	torus.outer_radius = r
	selection_ring.mesh = torus
	selection_ring.position.y = 0.08

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.2, 0.9) if behavior == Behavior.PREDATOR else Color(0.9, 0.85, 0.2, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_ring.material_override = mat
	selection_ring.visible = false
	add_child(selection_ring)

func _setup_hp_bar() -> void:
	hp_bar_pivot = get_node_or_null("HealthBarPivot")
	if hp_bar_pivot:
		hp_bar_pivot.visible = false

func set_selected(selected: bool) -> void:
	is_selected = selected
	if not selection_ring:
		_create_selection_ring()
	if selection_ring:
		selection_ring.visible = selected
	if hp_bar_pivot and state != AnimalState.DEAD:
		hp_bar_pivot.visible = selected or (current_hp < max_hp)

func flash_highlight() -> void:
	if not selection_ring:
		_create_selection_ring()
	if selection_ring:
		selection_ring.visible = true
		var t := create_tween()
		t.tween_property(selection_ring, "scale", Vector3(1.25, 1.0, 1.25), 0.15)
		t.tween_property(selection_ring, "scale", Vector3.ONE, 0.15)
		t.chain().tween_callback(func():
			if is_instance_valid(selection_ring):
				selection_ring.visible = is_selected
		)

func _physics_process(delta: float) -> void:
	if state == AnimalState.DEAD:
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	scan_timer = maxf(0.0, scan_timer - delta)

	match state:
		AnimalState.IDLE:
			_process_idle(delta)
		AnimalState.ROAMING:
			_process_roaming(delta)
		AnimalState.FLEEING:
			_process_fleeing(delta)
		AnimalState.PURSUING:
			_process_pursuing(delta)
		AnimalState.ATTACKING:
			_process_attacking(delta)

func _process_idle(delta: float) -> void:
	velocity = Vector3.ZERO
	roam_timer -= delta

	if scan_timer <= 0.0:
		scan_timer = 0.4
		_scan_environment()

	if roam_timer <= 0.0:
		roam_timer = randf_range(3.0, 7.0)
		var angle := randf() * TAU
		var dist := randf_range(3.0, 8.0)
		target_position = home_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		state = AnimalState.ROAMING

func _process_roaming(delta: float) -> void:
	if scan_timer <= 0.0:
		scan_timer = 0.4
		_scan_environment()

	var diff := target_position - global_position
	diff.y = 0.0
	if diff.length() <= 0.5:
		velocity = Vector3.ZERO
		state = AnimalState.IDLE
		return

	var dir := diff.normalized()
	velocity = dir * move_speed
	_face_direction(dir, delta)
	move_and_slide()

func _process_fleeing(delta: float) -> void:
	if not is_instance_valid(target_entity):
		state = AnimalState.IDLE
		target_entity = null
		return

	var threat_pos: Vector3 = (target_entity as Node3D).global_position
	var dist_to_threat := global_position.distance_to(threat_pos)

	if dist_to_threat >= alert_range + 5.0:
		state = AnimalState.IDLE
		target_entity = null
		velocity = Vector3.ZERO
		return

	var flee_dir := (global_position - threat_pos)
	flee_dir.y = 0.0
	if flee_dir.length_squared() < 0.01:
		flee_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	flee_dir = flee_dir.normalized()

	velocity = flee_dir * run_speed
	_face_direction(flee_dir, delta)
	move_and_slide()

func _process_pursuing(delta: float) -> void:
	if not is_instance_valid(target_entity) or ("is_dead" in target_entity and target_entity.is_dead):
		state = AnimalState.IDLE
		target_entity = null
		velocity = Vector3.ZERO
		return

	var t_pos: Vector3 = (target_entity as Node3D).global_position
	var dist := global_position.distance_to(t_pos)

	if global_position.distance_to(home_position) > leash_range:
		state = AnimalState.ROAMING
		target_position = home_position
		target_entity = null
		return

	if dist <= attack_range:
		velocity = Vector3.ZERO
		state = AnimalState.ATTACKING
		return

	var dir := (t_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity = dir * run_speed
	_face_direction(dir, delta)
	move_and_slide()

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(target_entity) or ("is_dead" in target_entity and target_entity.is_dead):
		state = AnimalState.IDLE
		target_entity = null
		velocity = Vector3.ZERO
		return

	var t_pos: Vector3 = (target_entity as Node3D).global_position
	var dist := global_position.distance_to(t_pos)
	if dist > attack_range + 0.6:
		state = AnimalState.PURSUING
		return

	velocity = Vector3.ZERO
	var dir := (t_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		_face_direction(dir.normalized(), delta)

	if attack_timer <= 0.0 and attack_damage > 0:
		attack_timer = attack_cooldown
		if target_entity.has_method("take_damage"):
			target_entity.take_damage(attack_damage, self)

func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.01:
		var target_rot_y := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 12.0 * delta)

func _scan_environment() -> void:
	var units := get_tree().get_nodes_in_group("units")
	var nearest_dist := 999.0
	var nearest_unit: Node = null

	for u in units:
		if is_instance_valid(u) and u is Node3D:
			var d := global_position.distance_to((u as Node3D).global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_unit = u

	if not nearest_unit:
		return

	match behavior:
		Behavior.PREY:
			if nearest_dist <= alert_range:
				target_entity = nearest_unit
				state = AnimalState.FLEEING
		Behavior.PREDATOR:
			if nearest_dist <= alert_range and state != AnimalState.PURSUING and state != AnimalState.ATTACKING:
				target_entity = nearest_unit
				state = AnimalState.PURSUING
		Behavior.NEUTRAL_DEFENDER:
			pass

func take_damage(amount: int, attacker: Node = null) -> void:
	if state == AnimalState.DEAD:
		return

	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	if hp_bar_pivot:
		hp_bar_pivot.visible = true

	match behavior:
		Behavior.PREY:
			if attacker and is_instance_valid(attacker):
				target_entity = attacker
				state = AnimalState.FLEEING
		Behavior.NEUTRAL_DEFENDER:
			if attacker and is_instance_valid(attacker):
				target_entity = attacker
				state = AnimalState.PURSUING
		Behavior.PREDATOR:
			if attacker and is_instance_valid(attacker):
				target_entity = attacker
				state = AnimalState.PURSUING

	if current_hp <= 0:
		_die(attacker)

func _die(killer: Node = null) -> void:
	state = AnimalState.DEAD
	velocity = Vector3.ZERO
	remove_from_group("animals")
	add_to_group("resources")

	animal_died.emit(self)

	var t := create_tween()
	t.tween_property(self, "rotation:z", deg_to_rad(85.0), 0.35)
	t.parallel().tween_property(self, "position:y", position.y - 0.2, 0.35)

	if hp_bar_pivot:
		hp_bar_pivot.visible = false
	if selection_ring:
		selection_ring.visible = is_selected

	if killer and is_instance_valid(killer) and killer.has_method("gather_from"):
		killer.call_deferred("gather_from", self)

func gather(requested_amount: int) -> int:
	if current_amount <= 0:
		return 0

	var harvested := mini(requested_amount, current_amount)
	current_amount -= harvested
	resource_gathered.emit(resource_type, harvested)

	if current_amount <= 0:
		resource_depleted.emit(self)
		var t := create_tween()
		t.tween_property(self, "scale", Vector3.ZERO, 0.5)
		t.chain().tween_callback(queue_free)

	return harvested
