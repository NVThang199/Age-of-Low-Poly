class_name ArrowProjectile
extends Node3D

var target: Node = null
var speed: float = 22.0
var damage: int = 5
var attacker: Node = null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var target_pos := (target as Node3D).global_position + Vector3(0.0, 0.8, 0.0)
	var dir := target_pos - global_position
	var dist := dir.length()
	if dist < 0.5:
		_hit_target()
		return

	look_at(target_pos, Vector3.UP)
	global_position += dir.normalized() * speed * delta

func _hit_target() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		var p_armor: int = target.pierce_armor if "pierce_armor" in target else 0
		var final_dmg: int = maxi(1, damage - p_armor)
		target.take_damage(final_dmg, attacker)
	queue_free()
