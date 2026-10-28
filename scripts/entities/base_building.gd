class_name BaseBuilding
extends StaticBody3D

signal building_completed(building: BaseBuilding)
signal building_destroyed(building: BaseBuilding)

enum BuildingType {
	TOWN_CENTER = 0,
	HOUSE = 1,
	BARRACKS = 2,
	STORAGE_PIT = 3, # Thay cho MINING_CAMP
	GRANARY = 4,
	WATCH_TOWER = 5,
	SMALL_WALL = 6,
}

@export var building_type: BuildingType = BuildingType.TOWN_CENTER
@export var owner_peer_id: int = 1
@export var max_hp: int = 600
@export var current_hp: int = 1
@export var build_time: float = 20.0
@export var pop_bonus: int = 5

var is_constructed: bool = false
var rally_point: Vector3 = Vector3.ZERO
var production_queue: Array[Dictionary] = []
var production_timer: float = 0.0
var is_selected: bool = false
var selection_box_mesh: MeshInstance3D = null
var _pulse_light: OmniLight3D = null

func _ready() -> void:
	add_to_group("buildings")
	if building_type == BuildingType.TOWN_CENTER:
		is_constructed = true
		current_hp = max_hp
	elif current_hp >= max_hp:
		is_constructed = true
	else:
		is_constructed = false
		_apply_scaffold_visuals()

	if is_constructed and (building_type in [BuildingType.TOWN_CENTER, BuildingType.STORAGE_PIT, BuildingType.GRANARY]):
		add_to_group("dropoffs")
	rally_point = global_position + Vector3(0.0, 0.0, 5.0)
	_create_selection_box()
	_create_building_hp_bar()

var building_hp_bar_pivot: Node3D = null
var building_hp_bar_fill: MeshInstance3D = null

func _create_building_hp_bar() -> void:
	building_hp_bar_pivot = Node3D.new()
	building_hp_bar_pivot.name = "BuildingHPBar"
	var hp_height := 3.2
	match building_type:
		BuildingType.TOWN_CENTER:
			hp_height = 3.2
		BuildingType.BARRACKS:
			hp_height = 2.8
		BuildingType.HOUSE:
			hp_height = 2.4
	building_hp_bar_pivot.position = Vector3(0.0, hp_height, 0.0)

	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(2.5, 0.22)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.12, 0.12, 0.12, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	building_hp_bar_pivot.add_child(bg)

	building_hp_bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(2.4, 0.18)
	building_hp_bar_fill.mesh = fill_mesh
	building_hp_bar_fill.position.z = 0.01
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 1.0, 0.2, 1.0) if owner_peer_id == 1 else Color(1.0, 0.2, 0.2, 1.0)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	building_hp_bar_fill.material_override = fill_mat
	building_hp_bar_pivot.add_child(building_hp_bar_fill)

	building_hp_bar_pivot.visible = false
	add_child(building_hp_bar_pivot)

func _update_building_hp_bar() -> void:
	if building_hp_bar_fill and max_hp > 0:
		var ratio := float(current_hp) / float(max_hp)
		building_hp_bar_fill.scale.x = ratio
	if building_hp_bar_pivot:
		building_hp_bar_pivot.visible = is_selected or (current_hp < max_hp)

func _apply_scaffold_visuals() -> void:
	var model = get_node_or_null("Model")
	if model:
		model.scale = Vector3(0.95, 0.4, 0.95)
	for child in find_children("", "MeshInstance3D"):
		if child != selection_box_mesh and (not building_hp_bar_pivot or child.get_parent() != building_hp_bar_pivot):
			child.transparency = 0.5

func _restore_completed_visuals() -> void:
	var model = get_node_or_null("Model")
	if model:
		model.scale = Vector3.ONE
	for child in find_children("", "MeshInstance3D"):
		if child != selection_box_mesh and (not building_hp_bar_pivot or child.get_parent() != building_hp_bar_pivot):
			child.transparency = 0.0

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_box_mesh:
		selection_box_mesh.visible = selected
	_update_building_hp_bar()

func flash_highlight() -> void:
	if not selection_box_mesh:
		_create_selection_box()
	if selection_box_mesh:
		selection_box_mesh.visible = true
		var t := create_tween()
		t.tween_property(selection_box_mesh, "scale", Vector3(1.15, 1.0, 1.15), 0.15)
		t.tween_property(selection_box_mesh, "scale", Vector3.ONE, 0.15)
		t.chain().tween_callback(func():
			if is_instance_valid(selection_box_mesh):
				selection_box_mesh.visible = is_selected
		)
	_show_build_pulse()

func _show_build_pulse() -> void:
	if not _pulse_light:
		_pulse_light = OmniLight3D.new()
		_pulse_light.light_color = Color(0.2, 0.85, 1.0, 1.0) # Màu xanh cyan nổi bật
		_pulse_light.light_energy = 4.5
		_pulse_light.omni_range = 8.0
		_pulse_light.position = Vector3(0.0, 2.0, 0.0)
		add_child(_pulse_light)

	_pulse_light.visible = true
	_pulse_light.light_energy = 4.5
	var tween := create_tween()
	tween.tween_property(_pulse_light, "light_energy", 0.0, 0.3)
	tween.chain().tween_callback(func():
		if is_instance_valid(_pulse_light):
			_pulse_light.visible = false
	)

func _create_selection_box() -> void:
	selection_box_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	match building_type:
		BuildingType.HOUSE:
			box.size = Vector3(3.2, 0.1, 3.2)
		BuildingType.TOWN_CENTER, BuildingType.BARRACKS, BuildingType.GRANARY, BuildingType.STORAGE_PIT:
			box.size = Vector3(4.2, 0.1, 4.2)
		BuildingType.WATCH_TOWER:
			box.size = Vector3(2.5, 0.1, 2.5)
		BuildingType.SMALL_WALL:
			box.size = Vector3(1.5, 0.1, 1.5)
		_:
			box.size = Vector3(3.5, 0.1, 3.5)
	selection_box_mesh.mesh = box
	selection_box_mesh.position.y = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_box_mesh.material_override = mat
	selection_box_mesh.visible = false
	add_child(selection_box_mesh)

func _physics_process(delta: float) -> void:
	if building_hp_bar_pivot and building_hp_bar_pivot.visible:
		var cam := get_viewport().get_camera_3d()
		if cam:
			building_hp_bar_pivot.look_at(cam.global_position, Vector3.UP)
	_process_production(delta)

func queue_unit(unit_scene_path: String, train_time: float) -> bool:
	if not is_constructed:
		return false
	production_queue.append({
		"type": "unit",
		"scene": unit_scene_path,
		"time": train_time
	})
	_sync_queue_to_clients()
	return true

func queue_tech(tech_id: String, research_time: float) -> bool:
	if not is_constructed:
		return false
	production_queue.append({
		"type": "tech",
		"tech_id": tech_id,
		"time": research_time
	})
	_sync_queue_to_clients()
	return true

@rpc("any_peer", "call_local", "reliable")
func request_research(tech_id: String) -> void:
	if multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var sender_id := 1
	if multiplayer and multiplayer.has_multiplayer_peer():
		sender_id = multiplayer.get_remote_sender_id()
		if sender_id == 0:
			sender_id = multiplayer.get_unique_id()

	if sender_id != owner_peer_id or not is_constructed:
		return

	var tm = get_node_or_null("/root/TechManager")
	if not tm or not tm.can_research(owner_peer_id, tech_id):
		return

	for item in production_queue:
		if item.get("type") == "tech" and item.get("tech_id") == tech_id:
			return

	var t_data: Dictionary = tm.TECH_DATABASE.get(tech_id, {})
	var costs: Dictionary = t_data.get("cost", {})
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		for res_type in costs:
			if game_mgr.get_resource(owner_peer_id, res_type) < costs[res_type]:
				return
		for res_type in costs:
			game_mgr.spend_resource(owner_peer_id, res_type, costs[res_type])

	queue_tech(tech_id, t_data.get("research_time", 30.0))

func _sync_queue_to_clients() -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and "connected_peers" in net_mgr:
		for pid in net_mgr.connected_peers:
			if pid != 1:
				sync_production_queue.rpc_id(pid, production_queue)

@rpc("authority", "call_remote", "reliable")
func sync_production_queue(queue_data: Array) -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	var local_id := multiplayer.get_unique_id()
	if local_id == 0:
		return
	production_queue.clear()
	for item in queue_data:
		production_queue.append(item)

func _process_production(delta: float) -> void:
	if production_queue.is_empty():
		production_timer = 0.0
		return

	if multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var current_item: Dictionary = production_queue[0]
	production_timer += delta
	var target_time: float = float(current_item.get("time", 1.0))
	if production_timer >= target_time:
		production_timer = 0.0
		var item_type: String = current_item.get("type", "unit")
		if item_type == "tech":
			var tech_id: String = current_item.get("tech_id", "")
			var tm = get_node_or_null("/root/TechManager")
			if tm:
				tm.server_complete_tech(owner_peer_id, tech_id)
		elif item_type == "unit":
			var scene_path: String = current_item.get("scene", "")
			_spawn_unit(scene_path)
		production_queue.pop_front()
		_sync_queue_to_clients()

func accepts_resource(res_type: int, is_meat: bool = false) -> bool:
	if not is_constructed:
		return false
	match building_type:
		BuildingType.TOWN_CENTER:
			return true
		BuildingType.GRANARY:
			return res_type == ResourceSource.ResourceType.FOOD and not is_meat
		BuildingType.STORAGE_PIT:
			if res_type in [ResourceSource.ResourceType.WOOD, ResourceSource.ResourceType.GOLD, ResourceSource.ResourceType.STONE]:
				return true
			if res_type == ResourceSource.ResourceType.FOOD and is_meat:
				return true
			return false
		_:
			return false

func _spawn_unit(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		return
	var unit_scene := load(scene_path) as PackedScene
	if not unit_scene:
		return
	var unit := unit_scene.instantiate() as BaseUnit
	if not unit:
		return
	unit.owner_peer_id = owner_peer_id
	var spawn_pos := global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(2.5, 3.5))
	get_parent().add_child(unit)
	unit.global_position = spawn_pos

	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.player_population.has(owner_peer_id):
		game_mgr.player_population[owner_peer_id]["current"] += 1
		game_mgr.population_updated.emit(
			owner_peer_id,
			game_mgr.player_population[owner_peer_id]["current"],
			game_mgr.player_population[owner_peer_id]["max"]
		)

	if unit.has_method("move_to"):
		unit.move_to(rally_point)

func construct(delta: float, builder_speed: float = 1.0) -> void:
	if is_constructed:
		return

	var hp_gain := (float(max_hp) / build_time) * delta * builder_speed
	current_hp = mini(max_hp, current_hp + int(ceilf(hp_gain)))
	_update_building_hp_bar()

	if current_hp >= max_hp:
		current_hp = max_hp
		is_constructed = true
		_restore_completed_visuals()
		if building_type in [BuildingType.TOWN_CENTER, BuildingType.STORAGE_PIT, BuildingType.GRANARY]:
			add_to_group("dropoffs")
		building_completed.emit(self)
		var game_mgr := get_node_or_null("/root/GameManager")
		if game_mgr and game_mgr.has_method("recalculate_max_pop"):
			game_mgr.recalculate_max_pop(owner_peer_id)

func deposit_resource(peer_id: int, res_type: ResourceSource.ResourceType, amount: int) -> void:
	if not is_constructed:
		return
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var target_peer := my_id if (peer_id == 1 and my_id != 1) else (peer_id if peer_id > 0 else my_id)
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("add_resource"):
		game_mgr.add_resource(target_peer, res_type, amount)
		_spawn_deposit_popup(res_type, amount)

func _spawn_deposit_popup(res_type: ResourceSource.ResourceType, amount: int) -> void:
	var type_name := "Wood"
	var color := Color(0.4, 1.0, 0.4, 1.0)
	match res_type:
		ResourceSource.ResourceType.FOOD:
			type_name = "Food"
			color = Color(1.0, 0.85, 0.3, 1.0)
		ResourceSource.ResourceType.WOOD:
			type_name = "Wood"
			color = Color(0.4, 1.0, 0.4, 1.0)
		ResourceSource.ResourceType.GOLD:
			type_name = "Gold"
			color = Color(1.0, 0.85, 0.1, 1.0)
		ResourceSource.ResourceType.STONE:
			type_name = "Stone"
			color = Color(0.85, 0.9, 0.95, 1.0)

	var label := Label3D.new()
	label.text = "+%d %s" % [amount, type_name]
	label.modulate = color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.outline_size = 4
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(randf_range(-0.5, 0.5), 3.5, randf_range(-0.5, 0.5))
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.8, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)

func take_damage(amount: int, _attacker: Node = null) -> void:
	current_hp = maxi(0, current_hp - amount)
	_update_building_hp_bar()
	if current_hp <= 0:
		building_destroyed.emit(self)
		remove_from_group("buildings")
		remove_from_group("dropoffs")
		var game_mgr := get_node_or_null("/root/GameManager")
		if game_mgr and game_mgr.has_method("recalculate_max_pop"):
			game_mgr.recalculate_max_pop(owner_peer_id)
		queue_free()
