class_name Villager
extends BaseUnit

@export var carry_capacity: int = 10
@export var gather_rate: float = 1.0

var carried_type: ResourceSource.ResourceType = ResourceSource.ResourceType.WOOD
var carried_amount: int = 0

var target_resource: ResourceSource = null
var target_dropoff: Node3D = null
var target_building: BaseBuilding = null
var gather_timer: float = 0.0
var is_delivering: bool = false
var current_equipped_tool: String = ""

func _init() -> void:
	unit_type = UnitType.VILLAGER
	max_hp = 25
	current_hp = 25
	move_speed = 5.0
	melee_attack = 3
	melee_armor = 0
	pierce_armor = 0
	right_hand_rotation = Vector3(0.0, 90.0, 0.0)

func _ready() -> void:
	super._ready()
	call_deferred("_update_tool")

func _update_tool() -> void:
	var needed_tool := ""
	if state == UnitState.GATHERING and is_instance_valid(target_resource):
		match target_resource.resource_type:
			ResourceSource.ResourceType.WOOD:
				needed_tool = "res://assets/tools/axe.fbx"
			ResourceSource.ResourceType.STONE, ResourceSource.ResourceType.GOLD:
				needed_tool = "res://assets/tools/pickaxe.fbx"
			ResourceSource.ResourceType.FOOD:
				needed_tool = "res://assets/tools/knife.fbx"
	elif state == UnitState.BUILDING:
		needed_tool = "res://assets/tools/hammer.fbx"
	else:
		needed_tool = ""

	if current_equipped_tool != needed_tool:
		current_equipped_tool = needed_tool
		equip_item_right(needed_tool)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == UnitState.GATHERING:
		_process_gathering(delta)
	elif state == UnitState.BUILDING:
		_process_building(delta)

func construct_building(building: BaseBuilding) -> void:
	target_building = building
	target_entity = building
	state = UnitState.BUILDING
	_update_tool()

func _process_building(delta: float) -> void:
	if not is_instance_valid(target_building):
		state = UnitState.IDLE
		_update_tool()
		return

	if target_building.is_constructed:
		state = UnitState.IDLE
		target_building = null
		_update_tool()
		return

	var dist := global_position.distance_to(target_building.global_position)
	var build_dist: float = 4.2
	var can_build := (dist <= build_dist) or (dist <= build_dist + 1.5 and stuck_timer > 0.08)
	if not can_build:
		var base_dir := global_position - target_building.global_position
		base_dir.y = 0.0
		var angle: float = atan2(base_dir.x, base_dir.z) if base_dir.length_squared() > 0.05 else float(get_instance_id() % 8) * (PI / 4.0)
		var slot_offset := float(get_instance_id() % 6) * (PI / 3.0) * 0.35
		angle += slot_offset
		var dir := Vector3(sin(angle), 0.0, cos(angle)).normalized()
		target_position = target_building.global_position + dir * 2.8
		_process_movement(delta)
		return

	velocity = Vector3.ZERO
	stuck_timer = 0.0
	var b_pos := target_building.global_position
	var diff := b_pos - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.05:
		look_at(Vector3(b_pos.x, global_position.y, b_pos.z), Vector3.UP)

	play_anim("Sword_Regular_Combo")
	target_building.construct(delta, 1.0)

func move_to(target_pos: Vector3) -> void:
	super.move_to(target_pos)
	is_delivering = false
	_update_tool()

func gather_from(source: ResourceSource) -> void:
	target_resource = source
	target_entity = source
	is_delivering = false
	state = UnitState.GATHERING
	_update_tool()

func return_resources_to(dropoff: Node3D) -> void:
	target_dropoff = dropoff
	if carried_amount > 0:
		is_delivering = true
		state = UnitState.GATHERING
	elif is_instance_valid(target_resource):
		is_delivering = false
		state = UnitState.GATHERING
	else:
		is_delivering = false
		state = UnitState.MOVING
		target_position = dropoff.global_position
	_update_tool()

func _process_gathering(delta: float) -> void:
	if is_delivering or carried_amount >= carry_capacity:
		is_delivering = true
		_return_to_dropoff(delta)
		return

	if not is_instance_valid(target_resource) or target_resource.current_amount <= 0:
		target_resource = _find_nearest_resource_of_type(carried_type)
		if not target_resource:
			state = UnitState.IDLE
			_update_tool()
			return

	var dist := global_position.distance_to(target_resource.global_position)
	var is_stone_or_gold: bool = (target_resource.resource_type == ResourceSource.ResourceType.STONE or target_resource.resource_type == ResourceSource.ResourceType.GOLD)
	var gather_dist: float = 3.8 if is_stone_or_gold else 3.2

	# Nếu đã đủ gần hoặc bị chặn bởi dân làng khác/vật cản khi ở cự ly làm việc
	var can_gather := (dist <= gather_dist) or (dist <= gather_dist + 1.2 and stuck_timer > 0.08)
	if not can_gather:
		# Tiếp cận theo góc vị trí riêng (dựa trên instance_id) để chia đều quanh chu vi tài nguyên, không chụm lại
		var base_dir := (global_position - target_resource.global_position)
		base_dir.y = 0.0
		var angle: float = atan2(base_dir.x, base_dir.z) if base_dir.length_squared() > 0.05 else float(get_instance_id() % 8) * (PI / 4.0)
		# Lệch góc theo ID để mỗi dân làng chiếm 1 khe đứng riêng biệt (slot)
		var slot_offset := float(get_instance_id() % 6) * (PI / 3.0) * 0.35
		angle += slot_offset
		var dir := Vector3(sin(angle), 0.0, cos(angle)).normalized()
		var perimeter_offset := 2.2 if is_stone_or_gold else 1.6
		target_position = target_resource.global_position + dir * perimeter_offset
		_process_movement(delta)
		return

	velocity = Vector3.ZERO
	stuck_timer = 0.0
	var res_pos := target_resource.global_position
	var diff := res_pos - global_position
	diff.y = 0.0
	if diff.length_squared() > 0.05:
		look_at(Vector3(res_pos.x, global_position.y, res_pos.z), Vector3.UP)

	match target_resource.resource_type:
		ResourceSource.ResourceType.WOOD:
			play_anim("TreeChopping_Loop")
		ResourceSource.ResourceType.FOOD:
			play_anim("Farm_Harvest")
		ResourceSource.ResourceType.GOLD, ResourceSource.ResourceType.STONE:
			play_anim("TreeChopping_Loop")
		_:
			play_anim("TreeChopping_Loop")

	gather_timer += delta
	if gather_timer >= gather_rate:
		gather_timer = 0.0
		carried_type = target_resource.resource_type
		var harvested := target_resource.gather(1)
		carried_amount += harvested

func _return_to_dropoff(delta: float) -> void:
	if not is_instance_valid(target_dropoff):
		target_dropoff = _find_nearest_dropoff()

	if not is_instance_valid(target_dropoff):
		state = UnitState.IDLE
		is_delivering = false
		return

	var dist := global_position.distance_to(target_dropoff.global_position)
	var stop_dist := 4.2
	if "building_type" in target_dropoff and (target_dropoff.building_type == BaseBuilding.BuildingType.STORAGE_PIT or target_dropoff.building_type == BaseBuilding.BuildingType.GRANARY):
		stop_dist = 3.2

	# Tiến lại gần dropoff nếu chưa trong phạm vi hoặc bị chặn lại bởi dân khác khi tới sát trạm
	var can_deposit := (dist <= stop_dist) or (dist <= stop_dist + 1.5 and stuck_timer > 0.12)
	if not can_deposit:
		var diff := global_position - target_dropoff.global_position
		diff.y = 0.0
		var dir := diff.normalized() if diff.length_squared() > 0.01 else Vector3.FORWARD
		target_position = target_dropoff.global_position + dir * maxf(1.5, stop_dist - 0.8)
		_process_movement(delta)
		play_anim("Walk_Carry")
		return

	velocity = Vector3.ZERO
	stuck_timer = 0.0
	if target_dropoff.has_method("deposit_resource") and carried_amount > 0:
		target_dropoff.deposit_resource(owner_peer_id, carried_type, carried_amount)
		carried_amount = 0
	is_delivering = false
	_update_tool()

	if is_instance_valid(target_resource) and target_resource.current_amount > 0:
		state = UnitState.GATHERING
	else:
		target_resource = _find_nearest_resource_of_type(carried_type)
		if target_resource:
			state = UnitState.GATHERING
		else:
			state = UnitState.IDLE

func _find_nearest_resource_of_type(type: ResourceSource.ResourceType) -> ResourceSource:
	var resources := get_tree().get_nodes_in_group("resources")
	var nearest: ResourceSource = null
	var min_dist := 25.0
	for r in resources:
		if r is ResourceSource and is_instance_valid(r) and r.resource_type == type and r.current_amount > 0:
			var d := global_position.distance_to(r.global_position)
			if d < min_dist:
				min_dist = d
				nearest = r
	return nearest

func _find_nearest_dropoff() -> Node3D:
	var dropoffs := get_tree().get_nodes_in_group("dropoffs")
	var nearest: Node3D = null
	var min_dist := INF
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for d in dropoffs:
		if not is_instance_valid(d) or not (d is Node3D):
			continue
		var d_peer: int = d.owner_peer_id if "owner_peer_id" in d else 1
		var is_friendly: bool = (d_peer == owner_peer_id) or (d_peer == my_id) or (d_peer == 1) or (owner_peer_id == 1)
		if not is_friendly:
			continue
		if "is_constructed" in d and not d.is_constructed:
			continue
		# Kiểm tra loại tài nguyên được kho chấp nhận
		if d.has_method("accepts_resource"):
			if not d.accepts_resource(carried_type, false):
				continue
		var dist := global_position.distance_to((d as Node3D).global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = d as Node3D
	return nearest
