class_name ArrowProjectile
extends Node3D

var target: Node = null
var speed: float = 24.0
var damage: int = 5
var attacker: Node = null
var splash_radius: float = 0.0 # Bán kính nổ lan cho Siege / Catapult

var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 9.8
var _lifetime: float = 3.5
var _initialized: bool = false

func _ready() -> void:
	call_deferred("_setup_trajectory")

func _setup_trajectory() -> void:
	if not is_instance_valid(target) or not (target is Node3D):
		return

	var target_3d := target as Node3D
	var target_vel := Vector3.ZERO
	if "velocity" in target_3d:
		target_vel = target_3d.velocity

	var target_pos := target_3d.global_position + Vector3(0.0, 0.8, 0.0)
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var t_flight := maxf(0.1, dist / speed)

	# Thuật toán đón đầu mục tiêu (Ballistics Leading)
	var predicted_pos := target_pos + target_vel * t_flight * 0.85
	var flight_vector := predicted_pos - global_position

	# Vận tốc ngang và dọc bù trọng lực
	_velocity = Vector3(flight_vector.x / t_flight, (flight_vector.y / t_flight) + (0.5 * _gravity * t_flight), flight_vector.z / t_flight)
	_initialized = true

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if not _initialized:
		_setup_trajectory()
		if not _initialized:
			queue_free()
			return

	_velocity.y -= _gravity * delta
	global_position += _velocity * delta

	if _velocity.length_squared() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)

	# Kiểm tra va chạm với mục tiêu hoặc mặt đất
	if global_position.y <= 0.05:
		_hit_ground()
		return

	if is_instance_valid(target) and target is Node3D:
		var t_pos: Vector3 = (target as Node3D).global_position + Vector3(0.0, 0.8, 0.0)
		if global_position.distance_to(t_pos) < 0.65:
			_hit_target()

func _hit_target() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		var elev_mod: float = 1.0
		if is_instance_valid(attacker) and attacker is Node3D:
			var diff_y: float = (attacker as Node3D).global_position.y - (target as Node3D).global_position.y
			if diff_y >= 0.8:
				elev_mod = 1.33 # Bắn từ trên cao xuống
			elif diff_y <= -0.8:
				elev_mod = 0.67 # Bắn từ dưới lên
		var p_armor: int = target.pierce_armor if "pierce_armor" in target else 0
		var final_dmg: int = maxi(1, int(round(float(damage - p_armor) * elev_mod)))
		target.take_damage(final_dmg, attacker)

	if splash_radius > 0.0:
		_apply_splash_damage()

	queue_free()

func _hit_ground() -> void:
	if splash_radius > 0.0:
		_apply_splash_damage()
	queue_free()

func _apply_splash_damage() -> void:
	var hits: Array[Node3D] = []
	var sg = get_node_or_null("/root/SpatialGrid")
	if sg:
		hits = sg.search_radius(global_position, splash_radius)
	else:
		for u in get_tree().get_nodes_in_group("units"):
			if u is Node3D and (u as Node3D).global_position.distance_to(global_position) <= splash_radius:
				hits.append(u as Node3D)

	for h in hits:
		if is_instance_valid(h) and h.has_method("take_damage") and h != target:
			var p_armor: int = h.pierce_armor if "pierce_armor" in h else 0
			var splash_dmg: int = maxi(1, int((damage - p_armor) * 0.5))
			h.take_damage(splash_dmg, attacker)
# ponytail: Simple parabolic arc; upgrade to RK4 integrator if wind resistance is added.
