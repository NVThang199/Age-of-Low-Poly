extends Node3D
## Handles building placement with ghost preview

enum BuildingType {
	HOUSE,
	BARRACKS,
	MINE,
}

const BUILDING_COSTS = {
	"house": {"wood": 30},
	"barracks": {"wood": 175},
	"mine": {"wood": 100},
}

const BUILDING_SCENES = {
	"house": "res://scenes/entities/house.tscn",
	"barracks": "res://scenes/entities/barracks.tscn",
	"mine": "res://scenes/entities/mine.tscn",
}

var is_placing: bool = false
var current_building_type: String = ""
var ghost_building: Node3D = null
var can_place: bool = false
var camera: Camera3D = null
var last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	camera = get_viewport().get_camera_3d()
	if not camera:
		camera = get_node_or_null("../CameraController/Camera3D")
	var hud = get_tree().root.get_node_or_null("Main/CanvasLayer/HUD")
	if hud and hud.has_signal("build_requested"):
		hud.build_requested.connect(_on_build_requested)
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and not net_mgr.command_received.is_connected(_on_network_command_received):
		net_mgr.command_received.connect(_on_network_command_received)

func _exit_tree() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.command_received.is_connected(_on_network_command_received):
		net_mgr.command_received.disconnect(_on_network_command_received)

func _on_network_command_received(command: Dictionary) -> void:
	var c_type: String = command.get("type", "")
	if c_type == "place_building":
		var payload: Dictionary = command.get("payload", {})
		var sender_peer: int = command.get("sender_peer", 1)
		_execute_spawn_building(payload, sender_peer)

func _process(_delta: float) -> void:
	if not is_placing or not ghost_building:
		return

	_update_ghost_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		last_mouse_pos = event.position

	if not is_placing:
		return

	# Tránh bắt click chuột nếu con trỏ đang tương tác với UI Control (nút Cancel, build menu)
	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control and hovered_control.is_visible_in_tree() and hovered_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if can_place:
				_place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()
			get_viewport().set_input_as_handled()

func _on_build_requested(building_type: String) -> void:
	if building_type == "cancel":
		_cancel_placement()
		return

	# Check if player can afford
	var cost = BUILDING_COSTS.get(building_type, {})
	var game_mgr = get_node_or_null("/root/GameManager")
	if not game_mgr:
		return

	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for res_name in cost:
		var res_type = _get_resource_type(res_name)
		if game_mgr.get_resource(my_id, res_type) < cost[res_name]:
			print("Not enough ", res_name)
			return

	_start_placement(building_type)

func _start_placement(building_type: String) -> void:
	_cancel_placement()  # Clear any existing placement

	current_building_type = building_type
	is_placing = true

	# Create ghost building
	var scene_path = BUILDING_SCENES.get(building_type)
	if not scene_path or not ResourceLoader.exists(scene_path):
		# For now, use a placeholder box
		ghost_building = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(4, 3, 4)
		ghost_building.mesh = box_mesh

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.3, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_building.material_override = mat
	else:
		ghost_building = load(scene_path).instantiate()
		_apply_ghost_material(ghost_building)

	get_parent().add_child(ghost_building)

func _apply_ghost_material(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is CollisionShape3D:
		node.disabled = true
	if node is BaseBuilding:
		node.set_physics_process(false)
		node.set_process(false)
		node.remove_from_group("buildings")
		node.remove_from_group("dropoffs")
	if node.name.begins_with("BuildingHPBar") or node.name.begins_with("SelectionBox"):
		node.visible = false

	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.3, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat

	for child in node.get_children():
		_apply_ghost_material(child)

func _update_ghost_position() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera or not ghost_building:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	if last_mouse_pos != Vector2.ZERO:
		mouse_pos = last_mouse_pos
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	# Chiếu trực tiếp lên mặt phẳng đất y = 0 để tránh va chạm vào chính preview làm rung lắc / phóng to thu nhỏ
	var ground_plane := Plane(Vector3.UP, 0.0)
	var hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return

	var target_pos: Vector3 = hit
	target_pos.y = 0.0
	target_pos.x = round(target_pos.x / 2.0) * 2.0
	target_pos.z = round(target_pos.z / 2.0) * 2.0

	ghost_building.global_position = target_pos

	var valid := _check_placement_valid(target_pos)
	if valid != can_place:
		can_place = valid
		var color := Color(0.2, 1.0, 0.3, 0.5) if can_place else Color(1.0, 0.2, 0.2, 0.5)
		_update_ghost_color(ghost_building, color)

func _check_placement_valid(pos: Vector3) -> bool:
	# Check if position is within map bounds
	if abs(pos.x) > 95 or abs(pos.z) > 95:
		return false

	# Không đặt đè lên các tòa nhà đã có
	var buildings := get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if b is Node3D and is_instance_valid(b) and b != ghost_building:
			if pos.distance_to((b as Node3D).global_position) < 4.2:
				return false

	# Không đặt đè lên tài nguyên (cây, mỏ đá, mỏ vàng)
	var resources := get_tree().get_nodes_in_group("resources")
	for r in resources:
		if r is Node3D and is_instance_valid(r):
			if pos.distance_to((r as Node3D).global_position) < 3.2:
				return false

	return true

func _update_ghost_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.material_override:
		node.material_override.albedo_color = color

	for child in node.get_children():
		_update_ghost_color(child, color)

func _place_building() -> void:
	if not can_place or not ghost_building:
		return

	var pos: Vector3 = ghost_building.global_position
	var b_type := current_building_type
	_cancel_placement()

	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var payload := {
		"building_type": b_type,
		"position": pos,
		"builder_peer": my_id
	}

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and multiplayer.has_multiplayer_peer():
		net_mgr.send_command("place_building", payload)
	else:
		_execute_spawn_building(payload, my_id)

func _execute_spawn_building(payload: Dictionary, sender_peer: int) -> void:
	var b_type: String = payload.get("building_type", "")
	var pos: Vector3 = payload.get("position", Vector3.ZERO)

	# Trừ tài nguyên
	var cost = BUILDING_COSTS.get(b_type, {})
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		for res_name in cost:
			var res_type = _get_resource_type(res_name)
			game_mgr.add_resource(sender_peer, res_type, -cost[res_name])

	# Spawn actual building (đặt móng với 1 HP để dân làng ra xây)
	var scene_path = BUILDING_SCENES.get(b_type)
	if scene_path and ResourceLoader.exists(scene_path):
		var building = load(scene_path).instantiate()
		if building is BaseBuilding:
			building.current_hp = 1
			building.is_constructed = false
			building.owner_peer_id = sender_peer
		get_parent().add_child(building)
		building.global_position = pos
		if building.has_method("flash_highlight"):
			building.flash_highlight()

		# Điều phối dân làng đang chọn hoặc dân làng gần nhất của sender ra xây
		var ordered := false
		var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		if sender_peer == my_id:
			var sel_sys := get_node_or_null("../SelectionSystem")
			if sel_sys and "selected_units" in sel_sys:
				for u in sel_sys.selected_units:
					if is_instance_valid(u) and u is Villager:
						u.construct_building(building)
						ordered = true
		if not ordered:
			var units := get_tree().get_nodes_in_group("units")
			var nearest_villager: Villager = null
			var min_d := 40.0
			for u in units:
				if u is Villager and is_instance_valid(u) and u.owner_peer_id == sender_peer:
					var d := pos.distance_to(u.global_position)
					if d < min_d:
						min_d = d
						nearest_villager = u
			if nearest_villager:
				nearest_villager.construct_building(building)
	else:
		print("Building scene not found: ", scene_path)

func _cancel_placement() -> void:
	if ghost_building:
		ghost_building.queue_free()
		ghost_building = null
	is_placing = false
	can_place = false
	current_building_type = ""

func _get_resource_type(res_name: String) -> int:
	match res_name:
		"food": return 0  # ResourceSource.ResourceType.FOOD
		"wood": return 1  # ResourceSource.ResourceType.WOOD
		"gold": return 2  # ResourceSource.ResourceType.GOLD
	return 0
