extends SceneTree

var _frame := 0
var _v1: Villager
var _v2: Villager
var _v3: Villager
var _house: BaseBuilding

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		print("--- Setting up 3 villagers and 1 house foundation ---")
		var v_scene: PackedScene = load("res://scenes/entities/villager.tscn")
		var h_scene: PackedScene = load("res://scenes/entities/house.tscn")

		_v1 = v_scene.instantiate()
		_v2 = v_scene.instantiate()
		_v3 = v_scene.instantiate()
		_v1.name = "Villager_1"
		_v2.name = "Villager_2"
		_v3.name = "Villager_3"

		root.add_child(_v1)
		root.add_child(_v2)
		root.add_child(_v3)

		# 3 villagers dung gan nhau tai vi tri (0, 0, 0), (0.8, 0, 0), (0, 0, 0.8)
		_v1.global_position = Vector3(0, 0, 0)
		_v2.global_position = Vector3(0.8, 0, 0)
		_v3.global_position = Vector3(0, 0, 0.8)

		_house = h_scene.instantiate()
		_house.name = "HouseFoundation"
		_house.current_hp = 1
		_house.is_constructed = false
		root.add_child(_house)
		# Nha dat tai (10, 0, 0)
		_house.global_position = Vector3(10, 0, 0)
		return false

	if _frame == 3:
		print("Ordering all 3 villagers to construct house...")
		_v1.construct_building(_house)
		_v2.construct_building(_house)
		_v3.construct_building(_house)

	if _frame > 3 and _frame <= 650:
		if _frame % 60 == 0:
			print("Frame ", _frame, ":")
			print("  V1: pos=", _v1.global_position, " state=", _v1.state, " vel=", _v1.velocity)
			print("  V2: pos=", _v2.global_position, " state=", _v2.state, " vel=", _v2.velocity)
			print("  V3: pos=", _v3.global_position, " state=", _v3.state, " vel=", _v3.velocity)
			print("  House HP: ", _house.current_hp, "/", _house.max_hp, " is_constructed=", _house.is_constructed)

		# Neu nha da xay xong
		if _house.is_constructed:
			print("House completed at frame ", _frame)
			print("V1: ", _v1.global_position, " state=", _v1.state)
			print("V2: ", _v2.global_position, " state=", _v2.state)
			print("V3: ", _v3.global_position, " state=", _v3.state)
			assert(_v1.global_position.distance_to(_house.global_position) <= 5.0, "V1 phai o gan nha xay xong!")
			assert(_v2.global_position.distance_to(_house.global_position) <= 5.0, "V2 phai o gan nha xay xong!")
			assert(_v3.global_position.distance_to(_house.global_position) <= 5.0, "V3 phai o gan nha xay xong!")
			print("ALL 3 VILLAGERS CONSTRUCTED TOGETHER SUCCESSFULLY!")
			_cleanup()
			quit(0)
			return true

	if _frame > 650:
		print("TIMEOUT frame 650!")
		print("V1: ", _v1.global_position, " state=", _v1.state)
		print("V2: ", _v2.global_position, " state=", _v2.state)
		print("V3: ", _v3.global_position, " state=", _v3.state)
		_cleanup()
		quit(1)
		return true

	return false

func target_pos_or_null(unit: Villager) -> Vector3:
	return unit.target_position

func _cleanup() -> void:
	if is_instance_valid(_v1): _v1.free()
	if is_instance_valid(_v2): _v2.free()
	if is_instance_valid(_v3): _v3.free()
	if is_instance_valid(_house): _house.free()
