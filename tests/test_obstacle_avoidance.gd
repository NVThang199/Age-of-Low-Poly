extends SceneTree

var _frame := 0
var _unit: BaseUnit
var _obs: StaticBody3D

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		print("--- Running Test Obstacle Avoidance & Steering ---")
		var villager_scene: PackedScene = load("res://scenes/entities/villager.tscn")
		_unit = villager_scene.instantiate()
		_unit.name = "TestVillager"
		root.add_child(_unit)
		_unit.global_position = Vector3(0, 0, 0)

		# Tao vat the chan duong giua (0, 0, 0) va (0, 0, 8)
		# Hop kich thuoc 4m x 2m x 4m dat tai (0, 0, 3)
		_obs = StaticBody3D.new()
		_obs.name = "ObstacleBox"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4, 2, 4)
		shape.shape = box
		_obs.add_child(shape)
		root.add_child(_obs)
		_obs.global_position = Vector3(0, 0, 3)
		return false

	if _frame == 3:
		# Ra lenh di chuyen xuyen qua phia sau vat the
		_unit.move_to(Vector3(0, 0, 8))
		return false

	if _phase == 1 and _frame > 3 and _frame <= 350:
		# Sau 30 frame (khoang 0.5s), unit tiep xuc voi vat the tai Z=1. Tuyet doi KHONG duoc Idle!
		if _frame == 40:
			assert(_unit.state == BaseUnit.UnitState.MOVING, "NPC khong duoc ve IDLE sau 0.5s khi cham vat the neu van con duong!")
			assert(_unit.avoidance_side != 0.0 or _unit.velocity.length() > 0.1, "NPC phai bat dau danh lai de ne vat the!")

		# Kiem tra neu da den dich
		if _unit.state == BaseUnit.UnitState.IDLE:
			var final_dist := _unit.global_position.distance_to(Vector3(0, 0, 8))
			assert(final_dist < 0.35, "Unit phai ve IDLE tai dung dich den (0, 0, 8), dist: " + str(final_dist))
			print("SUCCESS Phase 1: Unit da vuot qua vat the va den dich (0, 0, 8) tai frame ", _frame, " vi tri: ", _unit.global_position)
			_unit.free()
			_obs.free()
			# Chuyen sang Phase 2: Kiem tra khi dich bi chan hoan toan (khong co duong)
			_start_phase_2()
			return false

	if _frame > 350 and _phase == 1:
		print("FAILED Phase 1: Timeout! Unit bi ket tai vi tri: ", _unit.global_position, " state: ", _unit.state)
		_unit.free()
		_obs.free()
		quit(1)
		return true

	if _phase == 2:
		return _process_phase_2()

	return false

var _phase := 1
var _phase2_frame := 0
var _trapped_walls: Array[StaticBody3D] = []

func _start_phase_2() -> void:
	print("--- Starting Phase 2: Trapped / Walled In (No Path Available) ---")
	_phase = 2
	_phase2_frame = 0
	var villager_scene: PackedScene = load("res://scenes/entities/villager.tscn")
	_unit = villager_scene.instantiate()
	_unit.name = "TrappedVillager"
	root.add_child(_unit)
	_unit.global_position = Vector3(0, 0, 0)

	# Tao 4 buc tuong bao quanh unit tai Z=+1, Z=-1, X=+1, X=-1
	var wall_offsets := [
		Vector3(0, 0, 1.2),
		Vector3(0, 0, -1.2),
		Vector3(1.2, 0, 0),
		Vector3(-1.2, 0, 0)
	]
	var wall_sizes := [
		Vector3(3.0, 2.0, 0.4),
		Vector3(3.0, 2.0, 0.4),
		Vector3(0.4, 2.0, 3.0),
		Vector3(0.4, 2.0, 3.0)
	]

	for i in range(4):
		var w := StaticBody3D.new()
		w.name = "Wall_" + str(i)
		var s := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = wall_sizes[i]
		s.shape = b
		w.add_child(s)
		root.add_child(w)
		w.global_position = wall_offsets[i]
		_trapped_walls.append(w)

func _process_phase_2() -> bool:
	_phase2_frame += 1
	if _phase2_frame == 3:
		# Ra lenh di ra ben ngoai hop
		_unit.move_to(Vector3(0, 0, 10))
		return false

	if _phase2_frame > 3:
		# Trong 0.5 giay dau tien (frame 40), unit van phai o trang thai MOVING de thu tim duong
		if _phase2_frame == 35:
			assert(_unit.state == BaseUnit.UnitState.MOVING, "NPC khong duoc bo cuoc ngay sau 0.5s")

		# Sau 2 giay (frame > 140), unit phat hien khet hoan toan (khong co duong nao mo) va chuyen ve IDLE
		if _unit.state == BaseUnit.UnitState.IDLE:
			print("SUCCESS Phase 2: NPC chuyen ve IDLE sau khi khong con duong di nao tai frame ", _phase2_frame)
			_unit.free()
			for w in _trapped_walls:
				w.free()
			print("--- ALL Obstacle Avoidance & No-Path Tests PASSED ---")
			quit(0)
			return true

		if _phase2_frame > 220:
			print("FAILED Phase 2: NPC khong ve IDLE sau 3 giay bi nhot!")
			_unit.free()
			for w in _trapped_walls:
				w.free()
			quit(1)
			return true

	return false
