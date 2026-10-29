# Fact 1: Called by scripts/entities/base_unit.gd in _scan_for_enemies() and _process_attack()
# Fact 2: Verified no existing target evaluator via Glob("scripts/systems/*evaluator*")
# Fact 3: In-memory only; no external data files read or written
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

class_name TargetEvaluator
extends RefCounted

## TargetEvaluator
## Port thuật toán đánh giá mục tiêu Combat Desirability từ Rules.Rps & Strategic Numbers của AOE 1.
## Tự động tính điểm ưu tiên diệt chủng dựa trên khắc hệ, khoảng cách và lượng máu còn lại.

# Ma trận điểm khắc hệ Rules.Rps (0 - 100)
# BaseUnit.UnitType: { TargetType: Score }
const COMBAT_RATING: Dictionary = {
	BaseUnit.UnitType.INFANTRY: {
		BaseUnit.UnitType.ARCHER: 75.0,
		BaseUnit.UnitType.INFANTRY: 50.0,
		BaseUnit.UnitType.CAVALRY: 30.0,
		BaseUnit.UnitType.VILLAGER: 80.0
	},
	BaseUnit.UnitType.ARCHER: {
		BaseUnit.UnitType.INFANTRY: 80.0,
		BaseUnit.UnitType.CAVALRY: 25.0,
		BaseUnit.UnitType.ARCHER: 50.0,
		BaseUnit.UnitType.VILLAGER: 75.0
	},
	BaseUnit.UnitType.CAVALRY: {
		BaseUnit.UnitType.ARCHER: 90.0,
		BaseUnit.UnitType.INFANTRY: 65.0,
		BaseUnit.UnitType.CAVALRY: 50.0,
		BaseUnit.UnitType.VILLAGER: 85.0
	},
	BaseUnit.UnitType.VILLAGER: {
		BaseUnit.UnitType.VILLAGER: 50.0,
		BaseUnit.UnitType.INFANTRY: 20.0,
		BaseUnit.UnitType.ARCHER: 20.0,
		BaseUnit.UnitType.CAVALRY: 10.0
	}
}

const SCORE_BUILDING: float = 20.0
const SCORE_PRIEST: float = 95.0 # Mối đe dọa cao nhất, ưu tiên triệt hạ

static func evaluate(attacker: BaseUnit, target: Node3D) -> float:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return -INF

	var base_score: float = 50.0

	if target is BaseUnit:
		var target_unit := target as BaseUnit
		if target_unit.state == BaseUnit.UnitState.DEAD:
			return -INF

		# 1. Kiểm tra đơn vị linh mục / phù thủy
		if "is_priest" in target_unit and target_unit.is_priest:
			base_score = SCORE_PRIEST
		else:
			var attacker_matrix: Dictionary = COMBAT_RATING.get(attacker.unit_type, {})
			base_score = float(attacker_matrix.get(target_unit.unit_type, 50.0))

		# 2. Ưu tiên mục tiêu yếu máu (SNTargetEvaluationHitpoints)
		if target_unit.max_hp > 0:
			var hp_ratio := float(target_unit.current_hp) / float(target_unit.max_hp)
			base_score += (1.0 - hp_ratio) * 25.0

		# 3. Ưu tiên mục tiêu đang tấn công mình
		if target_unit.target_entity == attacker:
			base_score += 15.0

	elif target is BaseBuilding:
		var b := target as BaseBuilding
		base_score = SCORE_BUILDING
		# Ưu tiên tháp canh hoặc nhà quân sự hơn nhà dân
		if b.building_type in [BaseBuilding.BuildingType.WATCH_TOWER, BaseBuilding.BuildingType.BARRACKS]:
			base_score += 10.0
	else:
		return -INF

	# 4. Trừ điểm theo khoảng cách (SNTargetEvaluationDistance)
	var dist := attacker.global_position.distance_to(target.global_position)
	var final_score := base_score - (dist * 3.5)

	return final_score
# ponytail: Static scoring; add player stance modifiers when stances implemented.
