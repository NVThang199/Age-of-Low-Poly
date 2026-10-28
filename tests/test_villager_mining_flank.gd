extends SceneTree

# Behaviour under test: Villager avoidance around stationary NPCs and perimeter slot allocation during gathering.
# Existing tests: tests/test_villager_build_trio.gd, tests/test_villager_dropoff.gd.
# User instruction: "bây giờ lại bị khi 2 villager đang thao tác hoặc thu thập tài nguyên hoặc xây thì villager thứ 3 cứ đâm vào giữa chứ không tìm sang đường khác, phần tìm đường cũng phải áp dụng lên cả npc khi thấy npc thì phải tránh ra chứ"

var _frame := 0
var _done := false
var _v1: Villager
var _v2: Villager
var _v3: Villager
var _rock: ResourceSource

func _process(delta: float) -> bool:
	if _done:
		return true
	_frame += 1
	if _frame == 1:
		print("--- Setting up Mining Flank Test (Image #2 reproduction) ---")
		var v_scene: PackedScene = load("res://scenes/entities/villager.tscn")
		var r_scene: PackedScene = load("res://scenes/entities/gold_node.tscn")

		# Tao mo vang/da tai (0, 0, 0)
		_rock = r_scene.instantiate()
		_rock.name = "GoldRock"
		_rock.resource_type = ResourceSource.ResourceType.GOLD
		root.add_child(_rock)
		_rock.global_position = Vector3(0, 0, 0)

		# V1 va V2 dung o phia ben phai tai (2.2, 0, -0.4) va (2.2, 0, 0.4) dang khai thac
		_v1 = v_scene.instantiate()
		_v2 = v_scene.instantiate()
		_v3 = v_scene.instantiate()
		_v1.name = "Miner_1"
		_v2.name = "Miner_2"
		_v3.name = "Approaching_Miner_3"

		root.add_child(_v1)
		root.add_child(_v2)
		root.add_child(_v3)

		_v1.global_position = Vector3(2.2, 0, -0.4)
		_v2.global_position = Vector3(2.2, 0, 0.4)
		# V3 xuat phat tu phia sau (5.5, 0, 0.0) - dam thang vao giua 2 nguoi neu khong co ne tranh
		_v3.global_position = Vector3(5.5, 0, 0.0)
		return false

	if _frame == 3:
		_v1.gather_from(_rock)
		_v2.gather_from(_rock)
		# V3 ra lenh khai thac da
		_v3.gather_from(_rock)
		print("Ordered V3 to gather from rock while V1 and V2 occupy front side...")
		return false

	if _frame > 3 and _frame <= 300:
		if _frame % 30 == 0:
			print("Frame ", _frame, ":")
			print("  V3 pos=", _v3.global_position, " vel=", _v3.velocity, " state=", _v3.state, " target_pos=", _v3.target_position)

		var d_rock := _v3.global_position.distance_to(_rock.global_position)
		# V3 phai tiep can duoc mo vang de khai thac thuc su (dist <= 2.6m)
		if d_rock <= 2.6:
			_done = true
			print("SUCCESS: V3 da tim duong lach qua 2 dong doi va bat dau khai thac tai frame ", _frame, " vi tri: ", _v3.global_position, " dist: ", d_rock)
			# Dam bao V3 khong dam de len V1 hoac V2 (khoang cach > 0.7m)
			var d_v1 := _v3.global_position.distance_to(_v1.global_position)
			var d_v2 := _v3.global_position.distance_to(_v2.global_position)
			print("  Distance to V1: ", d_v1, " Distance to V2: ", d_v2)
			assert(d_v1 > 0.7, "V3 khong duoc de len V1!")
			assert(d_v2 > 0.7, "V3 khong duoc de len V2!")
			_cleanup()
			quit(0)
			return true

	if _frame > 300:
		_done = true
		print("FAILED: Timeout frame 300! V3 bi ket tai vi tri: ", _v3.global_position, " vel=", _v3.velocity)
		var d_v1 := _v3.global_position.distance_to(_v1.global_position)
		var d_v2 := _v3.global_position.distance_to(_v2.global_position)
		print("  Distance to V1: ", d_v1, " Distance to V2: ", d_v2)
		_cleanup()
		quit(1)
		return true

	return false

func _cleanup() -> void:
	if is_instance_valid(_v1): _v1.free()
	if is_instance_valid(_v2): _v2.free()
	if is_instance_valid(_v3): _v3.free()
	if is_instance_valid(_rock): _rock.free()
