# Fact 1: Called by scenes/core/main.tscn, scenes/ui/hud.tscn, and triggered via F10 or ~ key
# Fact 2: Verified no existing dev_tool.gd via Glob in scripts/ui/
# Fact 3: Control schema implementing UI tabs, spawn raycasting, cheat resource signals, age advance, and fog toggles
# Fact 4: User verbatim instruction: "làm cho tôi công cụ devtool để tôi có thể spawn mọi thứ ra dễ dàng và tôi chưa hề thấy chọn maptype hay có cho phép đen bản đồ hay là sáng toàn bản đồ hoặc chọn loại map medium, large, gigantic bạn xem để chọn các loại map bạn bảo thì chọn ở đâu tôi muốn ở bên ngoài lobby là phải có rồi"

class_name DevTool
extends Control

## DevTool (AoE 1 Low Poly Developer & Cheat Console)
## Cung cấp công cụ toàn diện hỗ trợ test nhanh:
## - Spawn tức thì mọi Unit, Building, Động vật hoang dã (Voi, Nai, Sư tử, Cá sấu) và Mỏ tài nguyên.
## - Bơm tài nguyên cheat kinh điển (Woodstock, Pepperoni Pizza, Coinage, Quarry).
## - Ép lên đời (Stone -> Tool -> Bronze -> Iron).
## - Điều khiển sương mù: Toggle sáng toàn bản đồ (Marco Polo), mở toàn bộ địa hình, đen lại bản đồ.
## - Tùy chỉnh tốc độ trận đấu (1x, 2x, 5x) và tiêu diệt mục tiêu.

const SCENES: Dictionary = {
	# Units
	"Villager": preload("res://scenes/entities/villager.tscn"),
	"Swordsman": preload("res://scenes/entities/swordsman.tscn"),
	"Archer": preload("res://scenes/entities/archer.tscn"),
	"Cavalry": preload("res://scenes/entities/cavalry.tscn"),
	"Priest": preload("res://scenes/entities/priest.tscn"),
	"Catapult": preload("res://scenes/entities/siege_catapult.tscn"),
	# Animals / Wildlife
	"Gazelle": preload("res://scenes/entities/animals/gazelle.tscn"),
	"Elephant": preload("res://scenes/entities/animals/elephant.tscn"),
	"Lion": preload("res://scenes/entities/animals/lion.tscn"),
	"Alligator": preload("res://scenes/entities/animals/alligator.tscn"),
	# Resources
	"Berry Bush": preload("res://scenes/entities/berry_bush.tscn"),
	"Tree": preload("res://scenes/entities/resource_node.tscn"),
	"Gold Mine": preload("res://scenes/entities/gold_node.tscn"),
	"Stone Mine": preload("res://scenes/entities/stone_node.tscn"),
	# Buildings
	"Town Center": preload("res://scenes/entities/town_center.tscn"),
	"Barracks": preload("res://scenes/entities/barracks.tscn"),
	"House": preload("res://scenes/entities/house.tscn"),
	"Granary": preload("res://scenes/entities/granary.tscn"),
	"Storage Pit": preload("res://scenes/entities/storage_pit.tscn"),
	"Farm": preload("res://scenes/entities/farm.tscn"),
	"Archery Range": preload("res://scenes/entities/archery_range.tscn"),
	"Stable": preload("res://scenes/entities/stable.tscn"),
	"Market": preload("res://scenes/entities/market.tscn"),
	"Temple": preload("res://scenes/entities/temple.tscn"),
	"Watch Tower": preload("res://scenes/entities/watch_tower.tscn"),
}

var is_open: bool = false
var pending_spawn_key: String = ""
var camera: Camera3D = null

var panel: PanelContainer = null
var status_lbl: Label = null
var spawn_status_bar: Label = null

func _ready() -> void:
	visible = false
	is_open = false
	_build_ui_layout()

func _unhandled_input(event: InputEvent) -> void:
	# Phím F10 hoặc dấu ~ (KEY_QUOTELEFT) mở/đóng DevTool
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_F10 or event.keycode == KEY_QUOTELEFT:
			toggle_dev_tool()
			get_viewport().set_input_as_handled()
			return

	# Nếu đang ở chế độ chờ click để Spawn thực thể xuống đất 3D
	if not pending_spawn_key.is_empty():
		if event is InputEventMouseButton and event.is_pressed():
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var hovered := get_viewport().gui_get_hovered_control()
				if hovered and hovered.is_visible_in_tree() and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					return
				_handle_spawn_click(mb.position)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				cancel_spawn_mode()
				get_viewport().set_input_as_handled()

func _get_local_peer_id() -> int:
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func _get_autoload_node(node_name: String) -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null(node_name)
	if get_parent():
		if get_parent().name == node_name:
			return get_parent()
		var sibling := get_parent().get_node_or_null(node_name)
		if sibling:
			return sibling
	return null

func toggle_dev_tool() -> void:
	is_open = not is_open
	visible = is_open
	if is_open and status_lbl:
		status_lbl.text = "DevTool Active. Click any button or select an entity to spawn."
	else:
		cancel_spawn_mode()

func cancel_spawn_mode() -> void:
	pending_spawn_key = ""
	if spawn_status_bar:
		spawn_status_bar.visible = false

func start_spawn_mode(entity_key: String) -> void:
	if not SCENES.has(entity_key):
		return
	pending_spawn_key = entity_key
	if spawn_status_bar:
		spawn_status_bar.visible = true
		spawn_status_bar.text = "Click ground to spawn [%s] (Right-Click to Cancel)" % entity_key

func _handle_spawn_click(screen_pos: Vector2) -> void:
	if pending_spawn_key.is_empty() or not SCENES.has(pending_spawn_key):
		cancel_spawn_mode()
		return

	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end := ray_origin + camera.project_ray_normal(screen_pos) * 1000.0
	var space_state := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := space_state.intersect_ray(query)

	var spawn_pos: Vector3 = Vector3.ZERO
	if hit.has("position"):
		spawn_pos = hit["position"]
	else:
		# Fallback nếu raycast không trúng collider
		var plane := Plane(Vector3.UP, 0.0)
		var p_hit = plane.intersects_ray(ray_origin, camera.project_ray_normal(screen_pos))
		if p_hit:
			spawn_pos = p_hit

	_spawn_entity_at(pending_spawn_key, spawn_pos)

	# Giữ chế độ spawn nếu giữ phím Shift, ngược lại thoát chế độ spawn
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_spawn_mode()

func _spawn_entity_at(entity_key: String, pos: Vector3) -> Node:
	var scene: PackedScene = SCENES.get(entity_key, null)
	if not scene:
		return null

	var instance: Node = scene.instantiate()
	var main_scene: Node = null
	if is_inside_tree() and get_tree():
		main_scene = get_tree().current_scene
	if not main_scene:
		main_scene = get_parent()
	if not main_scene:
		main_scene = self

	# Tuân thủ CLAUDE.md: add_child trước khi gán vị trí
	main_scene.add_child(instance)
	if instance is Node3D:
		instance.position = pos

	var my_id := _get_local_peer_id()

	if instance is BaseUnit:
		instance.owner_peer_id = my_id
		if instance.has_method("set_team"):
			instance.set_team(my_id)
	elif instance is BaseBuilding:
		instance.owner_peer_id = my_id
		instance.is_constructed = true
		if instance.has_method("set_team"):
			instance.set_team(my_id)

	if status_lbl:
		status_lbl.text = "Spawned [%s] at (%.1f, %.1f, %.1f)" % [entity_key, pos.x, pos.y, pos.z]
	return instance

## Cheat Tài Nguyên
func cheat_add_resources(wood: int, food: int, gold: int, stone: int) -> void:
	var my_id := _get_local_peer_id()
	var gm := _get_autoload_node("GameManager")
	if gm:
		if wood > 0: gm.add_resource(my_id, ResourceSource.ResourceType.WOOD, wood)
		if food > 0: gm.add_resource(my_id, ResourceSource.ResourceType.FOOD, food)
		if gold > 0: gm.add_resource(my_id, ResourceSource.ResourceType.GOLD, gold)
		if stone > 0: gm.add_resource(my_id, ResourceSource.ResourceType.STONE, stone)
		if status_lbl:
			status_lbl.text = "Cheat added: +%d Food, +%d Wood, +%d Gold, +%d Stone" % [food, wood, gold, stone]

## Cheat Lên Đời
func cheat_advance_age(target_age: int) -> void:
	var my_id := _get_local_peer_id()
	var tm := _get_autoload_node("TechManager")
	if tm:
		tm.advance_age_instant(my_id, target_age)
		var age_name := "Stone"
		match target_age:
			1: age_name = "Tool"
			2: age_name = "Bronze"
			3: age_name = "Iron"
		if status_lbl:
			status_lbl.text = "Cheat advanced to %s Age!" % age_name

## Cheat Sương Mù
func cheat_toggle_fog() -> void:
	var fow := _get_autoload_node("FogOfWar")
	if fow:
		fow.toggle_all_visible()
		if status_lbl:
			status_lbl.text = "Toggled Map Fog: %s" % ("ALL VISIBLE (Marco Polo)" if fow.visibility_mode == 2 else "NORMAL FOG")

func cheat_explore_map() -> void:
	var fow := _get_autoload_node("FogOfWar")
	if fow:
		fow.set_all_explored()
		if status_lbl:
			status_lbl.text = "Entire Map Explored!"

func cheat_reset_fog() -> void:
	var fow := _get_autoload_node("FogOfWar")
	if fow:
		fow.reset_to_black()
		if status_lbl:
			status_lbl.text = "Fog of War Reset to Black!"

## Tiêu diệt mục tiêu đang chọn hoặc dọn sạch
func cheat_kill_selected() -> void:
	var sel_system := get_tree().current_scene.get_node_or_null("SelectionSystem") as SelectionSystem
	if sel_system and not sel_system.selected_units.is_empty():
		var count := sel_system.selected_units.size()
		for u in sel_system.selected_units:
			if is_instance_valid(u):
				if u.has_method("take_damage"):
					u.take_damage(9999, null)
				else:
					u.queue_free()
		sel_system.clear_selection()
		status_lbl.text = "Killed %d selected entities" % count
	else:
		status_lbl.text = "No entity selected to kill"

## Tốc độ game
func set_game_speed(scale_val: float) -> void:
	Engine.time_scale = scale_val
	status_lbl.text = "Game speed set to %.1fx" % scale_val

## Xây dựng giao diện UI
func _build_ui_layout() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	if not has_node("SpawnStatusBar"):
		var ssb := Label.new()
		ssb.name = "SpawnStatusBar"
		ssb.set_anchors_preset(PRESET_TOP_WIDE)
		ssb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ssb.offset_top = 40.0
		ssb.add_theme_font_size_override("font_size", 18)
		ssb.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
		style.set_content_margin_all(8)
		ssb.add_theme_stylebox_override("normal", style)
		ssb.visible = false
		add_child(ssb)
		spawn_status_bar = ssb

	if has_node("Panel"):
		return

	var p := PanelContainer.new()
	p.name = "Panel"
	p.set_anchors_preset(PRESET_TOP_RIGHT)
	p.offset_left = -440.0
	p.offset_top = 45.0
	p.offset_right = -10.0
	p.offset_bottom = 580.0

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	p_style.border_color = Color(0.85, 0.72, 0.35, 1.0) # Vàng đồng AoE 1
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(6)
	p_style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", p_style)
	add_child(p)
	panel = p

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	p.add_child(vbox)

	# Header Title & Close Button
	var header := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "AOE 1 LOW POLY - DEVTOOL"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(toggle_dev_tool)
	header.add_child(close_btn)
	vbox.add_child(header)

	var stat := Label.new()
	stat.name = "StatusLabel"
	stat.text = "Press F10 or ~ to Toggle. Select entity or click cheats."
	stat.add_theme_font_size_override("font_size", 11)
	stat.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	stat.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(stat)
	status_lbl = stat

	# Tab Container chứa các danh mục Spawn
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(400, 260)
	vbox.add_child(tabs)

	_create_spawn_grid(tabs, "Units", ["Villager", "Swordsman", "Archer", "Cavalry", "Priest", "Catapult"])
	_create_spawn_grid(tabs, "Fauna", ["Gazelle", "Elephant", "Lion", "Alligator"])
	_create_spawn_grid(tabs, "Resources", ["Berry Bush", "Tree", "Gold Mine", "Stone Mine"])
	_create_spawn_grid(tabs, "Buildings", ["Town Center", "Barracks", "House", "Granary", "Storage Pit", "Farm", "Archery Range", "Stable", "Market", "Temple", "Watch Tower"])

	# Cheats Section: Tài nguyên
	var res_box := HBoxContainer.new()
	var btn_all_res := Button.new()
	btn_all_res.text = "+1000 All"
	btn_all_res.pressed.connect(func(): cheat_add_resources(1000, 1000, 1000, 1000))
	res_box.add_child(btn_all_res)

	var btn_food := Button.new()
	btn_food.text = "+1000 F"
	btn_food.pressed.connect(func(): cheat_add_resources(0, 1000, 0, 0))
	res_box.add_child(btn_food)

	var btn_wood := Button.new()
	btn_wood.text = "+1000 W"
	btn_wood.pressed.connect(func(): cheat_add_resources(1000, 0, 0, 0))
	res_box.add_child(btn_wood)

	var btn_gold := Button.new()
	btn_gold.text = "+1000 G"
	btn_gold.pressed.connect(func(): cheat_add_resources(0, 0, 1000, 0))
	res_box.add_child(btn_gold)

	var btn_stone := Button.new()
	btn_stone.text = "+1000 S"
	btn_stone.pressed.connect(func(): cheat_add_resources(0, 0, 0, 1000))
	res_box.add_child(btn_stone)
	vbox.add_child(res_box)

	# Cheats Section: Lên Đời
	var age_box := HBoxContainer.new()
	var age_lbl := Label.new()
	age_lbl.text = "Age:"
	age_box.add_child(age_lbl)

	var age_names: Array[String] = ["Stone", "Tool", "Bronze", "Iron"]
	for age_idx in range(4):
		var aname: String = age_names[age_idx]
		var abtn := Button.new()
		abtn.text = aname
		var idx := age_idx
		abtn.pressed.connect(func(): cheat_advance_age(idx))
		age_box.add_child(abtn)
	vbox.add_child(age_box)

	# Cheats Section: Bản đồ & Sương Mù
	var map_box := HBoxContainer.new()
	var btn_marco := Button.new()
	btn_marco.text = "Marco Polo (Light)"
	btn_marco.pressed.connect(cheat_toggle_fog)
	map_box.add_child(btn_marco)

	var btn_explore := Button.new()
	btn_explore.text = "Explore All"
	btn_explore.pressed.connect(cheat_explore_map)
	map_box.add_child(btn_explore)

	var btn_reset_fow := Button.new()
	btn_reset_fow.text = "Reset Fog"
	btn_reset_fow.pressed.connect(cheat_reset_fog)
	map_box.add_child(btn_reset_fow)
	vbox.add_child(map_box)

	# Controls Section: Tốc độ & Tiêu diệt
	var ctrl_box := HBoxContainer.new()
	var btn_1x := Button.new()
	btn_1x.text = "1x"
	btn_1x.pressed.connect(func(): set_game_speed(1.0))
	ctrl_box.add_child(btn_1x)

	var btn_2x := Button.new()
	btn_2x.text = "2x"
	btn_2x.pressed.connect(func(): set_game_speed(2.0))
	ctrl_box.add_child(btn_2x)

	var btn_5x := Button.new()
	btn_5x.text = "5x"
	btn_5x.pressed.connect(func(): set_game_speed(5.0))
	ctrl_box.add_child(btn_5x)

	var btn_kill := Button.new()
	btn_kill.text = "Kill Selected"
	btn_kill.pressed.connect(cheat_kill_selected)
	ctrl_box.add_child(btn_kill)
	vbox.add_child(ctrl_box)

func _create_spawn_grid(tabs: TabContainer, tab_name: String, entities: Array[String]) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	for key in entities:
		var btn := Button.new()
		btn.text = "Spawn " + key
		btn.custom_minimum_size = Vector2(180, 32)
		var e_key := key
		btn.pressed.connect(func(): start_spawn_mode(e_key))
		grid.add_child(btn)

	tabs.add_child(scroll)
