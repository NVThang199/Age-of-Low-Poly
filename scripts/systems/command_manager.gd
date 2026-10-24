class_name CommandManager
extends Node

## CommandManager
## Điều phối lệnh chuột phải (Contextual Right-Click) gửi lệnh qua NetworkManager.
## Hỗ trợ Server Authority: Đóng gói lệnh gửi lên Server (hoặc thực thi ngay ở Singleplayer/Offline),
## lắng nghe `NetworkManager.command_received` để thực thi đồng bộ trên Server và các Client.

@onready var selection_system: SelectionSystem = $"../SelectionSystem"
@onready var camera: Camera3D = $"../CameraController/Camera3D"

func _ready() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and not net_mgr.command_received.is_connected(_on_command_received):
		net_mgr.command_received.connect(_on_command_received)

func _exit_tree() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.command_received.is_connected(_on_command_received):
		net_mgr.command_received.disconnect(_on_command_received)

func _unhandled_input(event: InputEvent) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered and hovered.is_visible_in_tree() and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return

	if not selection_system or selection_system.selected_units.is_empty():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.is_pressed():
			_handle_right_click(mb.position)

func _handle_right_click(screen_pos: Vector2) -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var unit_names: Array[String] = []
	for u in selection_system.selected_units:
		if is_instance_valid(u) and u.is_in_group("units"):
			var u_peer: int = u.owner_peer_id if "owner_peer_id" in u else 1
			if multiplayer.has_multiplayer_peer() and u_peer != my_id:
				continue
			unit_names.append(String(u.name))

	if unit_names.is_empty():
		return

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end := ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	var space_state := (get_parent() as Node3D).get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := space_state.intersect_ray(query)

	if not hit.has("position"):
		return

	var target_pos: Vector3 = hit["position"]
	var collider: Node = hit.get("collider", null)

	var action_type := "move"
	var target_node: Node = null

	if is_instance_valid(collider) and collider.is_in_group("resources"):
		action_type = "gather"
		target_node = collider
	elif is_instance_valid(collider) and collider.is_in_group("dropoffs"):
		var d_peer: int = collider.owner_peer_id if "owner_peer_id" in collider else 1
		var is_friendly: bool = (d_peer == my_id) or not multiplayer.has_multiplayer_peer()
		if is_friendly:
			action_type = "deposit"
			target_node = collider
		else:
			action_type = "attack"
			target_node = collider
	elif is_instance_valid(collider) and collider.is_in_group("buildings") and collider is BaseBuilding and not (collider as BaseBuilding).is_constructed:
		action_type = "build"
		target_node = collider
	elif is_instance_valid(collider) and collider.is_in_group("buildings"):
		var b_peer: int = collider.owner_peer_id if "owner_peer_id" in collider else 1
		if multiplayer.has_multiplayer_peer() and b_peer != my_id:
			action_type = "attack"
			target_node = collider
		else:
			action_type = "move"
	elif is_instance_valid(collider) and collider.is_in_group("units"):
		var u_peer: int = collider.owner_peer_id if "owner_peer_id" in collider else 1
		if multiplayer.has_multiplayer_peer() and u_peer != my_id:
			action_type = "attack"
			target_node = collider
		else:
			action_type = "move"
	else:
		var nearby_res := _find_nearby_resource(target_pos, 2.5)
		if nearby_res:
			action_type = "gather"
			target_node = nearby_res
		else:
			action_type = "move"

	# Phản hồi thị giác tức thì cho client ra lệnh
	_spawn_feedback_marker(action_type, target_pos, target_node)

	# Đóng gói payload gửi Server
	var target_path: NodePath = target_node.get_path() if is_instance_valid(target_node) else NodePath("")
	var payload: Dictionary = {
		"unit_names": unit_names,
		"target_pos": target_pos,
		"target_path": target_path
	}

	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.send_command(action_type, payload)
	else:
		_execute_command(action_type, payload, my_id)

func _spawn_feedback_marker(action_type: String, target_pos: Vector3, target_node: Node) -> void:
	match action_type:
		"gather":
			if is_instance_valid(target_node) and target_node is Node3D:
				var radius := 1.7 if ("resource_type" in target_node and (target_node.resource_type == 2 or target_node.resource_type == 3)) else 0.95
				_spawn_click_marker((target_node as Node3D).global_position, Color(1.0, 0.85, 0.2, 0.9), radius)
			if is_instance_valid(target_node) and target_node.has_method("flash_highlight"):
				target_node.flash_highlight()
		"deposit":
			if is_instance_valid(target_node) and target_node is Node3D:
				_spawn_click_marker((target_node as Node3D).global_position, Color(0.2, 0.9, 1.0, 0.8), 2.2)
		"build":
			if is_instance_valid(target_node) and target_node is Node3D:
				_spawn_click_marker((target_node as Node3D).global_position, Color(0.2, 0.8, 1.0, 0.8), 2.0)
			if is_instance_valid(target_node) and target_node.has_method("flash_highlight"):
				target_node.flash_highlight()
		"attack":
			if is_instance_valid(target_node) and target_node is Node3D:
				_spawn_click_marker((target_node as Node3D).global_position, Color(1.0, 0.2, 0.2, 0.8), 0.9)
		"move":
			_spawn_click_marker(target_pos, Color(0.2, 1.0, 0.3, 0.8))

func _on_command_received(command: Dictionary) -> void:
	var action_type: String = command.get("type", "")
	var payload: Dictionary = command.get("payload", {})
	var sender_peer: int = command.get("sender_peer", 1)
	_execute_command(action_type, payload, sender_peer)

func _execute_command(action_type: String, payload: Dictionary, sender_peer: int = 1) -> void:
	var raw_names: Array = payload.get("unit_names", [])
	var target_pos: Vector3 = payload.get("target_pos", Vector3.ZERO)
	var target_path: NodePath = payload.get("target_path", NodePath(""))

	var units: Array = []
	for uname in raw_names:
		var u := _resolve_unit(uname)
		if is_instance_valid(u):
			if multiplayer.has_multiplayer_peer() and "owner_peer_id" in u and u.owner_peer_id != sender_peer:
				continue
			units.append(u)

	if units.is_empty():
		return

	var target_node: Node = null
	if target_path != NodePath(""):
		target_node = get_node_or_null(target_path)

	match action_type:
		"move":
			_execute_move(units, target_pos)
		"gather":
			if is_instance_valid(target_node):
				_execute_gather(units, target_node)
			else:
				_execute_move(units, target_pos)
		"deposit":
			if is_instance_valid(target_node):
				_execute_deposit(units, target_node)
			else:
				_execute_move(units, target_pos)
		"build":
			if is_instance_valid(target_node):
				_execute_build(units, target_node)
			else:
				_execute_move(units, target_pos)
		"attack":
			if is_instance_valid(target_node):
				_execute_attack(units, target_node)
			else:
				_execute_move(units, target_pos)

func _resolve_unit(unit_identifier: Variant) -> Node:
	if unit_identifier is Node:
		return unit_identifier if is_instance_valid(unit_identifier) else null
	var id_str := str(unit_identifier)
	if id_str.begins_with("/"):
		var n := get_node_or_null(NodePath(id_str))
		if is_instance_valid(n):
			return n
	if get_parent() and get_parent().has_node(id_str):
		var n := get_parent().get_node(id_str)
		if is_instance_valid(n):
			return n
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and u.name == id_str:
			return u
	return null

func _find_nearby_resource(pos: Vector3, max_dist: float) -> Node:
	var resources := get_tree().get_nodes_in_group("resources")
	var nearest: Node = null
	var min_d := max_dist
	for r in resources:
		if r is Node3D and is_instance_valid(r):
			var d := pos.distance_to((r as Node3D).global_position)
			if d < min_d:
				min_d = d
				nearest = r
	return nearest

func _execute_move(units: Array, pos: Vector3) -> void:
	var count: int = units.size()
	if count <= 1:
		for u in units:
			if is_instance_valid(u) and u.has_method("move_to"):
				u.move_to(pos)
		return

	var cols := int(ceilf(sqrt(float(count))))
	var spacing := 1.8
	var idx := 0
	for u in units:
		if is_instance_valid(u) and u.has_method("move_to"):
			@warning_ignore("integer_division")
			var row := idx / cols
			var col := idx % cols
			var offset_x := (col - float(cols - 1) / 2.0) * spacing
			var offset_z := (row - float(cols - 1) / 2.0) * spacing
			u.move_to(pos + Vector3(offset_x, 0.0, offset_z))
			idx += 1

func _execute_gather(units: Array, res: Node) -> void:
	for u in units:
		if is_instance_valid(u) and u.has_method("gather_from"):
			u.gather_from(res)

func _execute_deposit(units: Array, dropoff: Node) -> void:
	for u in units:
		if is_instance_valid(u) and u.has_method("return_resources_to"):
			u.return_resources_to(dropoff)

func _execute_build(units: Array, building: Node) -> void:
	for u in units:
		if is_instance_valid(u) and u.has_method("construct_building"):
			u.construct_building(building)

func _execute_attack(units: Array, target: Node) -> void:
	for u in units:
		if is_instance_valid(u) and u.has_method("attack_target"):
			u.attack_target(target)

func _spawn_click_marker(pos: Vector3, color: Color, radius: float = 0.65) -> void:
	var marker := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.2, radius - 0.15)
	torus.outer_radius = radius
	marker.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat

	get_parent().add_child(marker)
	marker.global_position = Vector3(pos.x, pos.y + 0.08, pos.z)

	var tween := marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector3(1.3, 1.0, 1.3), 0.35)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(marker.queue_free)
