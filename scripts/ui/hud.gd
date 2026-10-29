# Fact 1: UI HUD for RTS game, imported by scenes/ui/hud.tscn
# Fact 2: Verified buildings and tech IDs in scripts/autoload/tech_manager.gd
# Fact 3: Handles top bar resources, age display, action panel, production queue, and build buttons
# Fact 4: User request: "bạn thiết kế lại UI UX cho tôi bạn phải làm sao để giống game gốc [Image #1] nó rất đơn giản nhưng lại có mọi thứ và phải lên đời/ research thì mới hiện các côgn trình chứ hiện tại bạn cứ để bừa trên màn hình là không được"

class_name RTSHUD
extends Control

signal build_requested(building_type: String)

# Top Bar Nodes
@onready var wood_label: Label = $TopBar/Margin/HBox/ResWood/WoodLabel
@onready var food_label: Label = $TopBar/Margin/HBox/ResFood/FoodLabel
@onready var gold_label: Label = $TopBar/Margin/HBox/ResGold/GoldLabel
@onready var stone_label: Label = $TopBar/Margin/HBox/ResStone/StoneLabel
@onready var pop_label: Label = $TopBar/Margin/HBox/ResPop/PopLabel
@onready var age_label: Label = $TopBar/Margin/HBox/AgeLabel
@onready var year_label: Label = $TopBar/Margin/HBox/YearLabel

# Contextual Tooltip Banner
@onready var tooltip_banner: PanelContainer = $TooltipBanner
@onready var tooltip_label: Label = $TooltipBanner/Margin/TooltipLabel

# Left Info Box Nodes
@onready var entity_title: Label = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/EntityTitle
@onready var details_hbox: HBoxContainer = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox
@onready var thumbnail_rect: TextureRect = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox/Thumbnail
@onready var hp_bar: ProgressBar = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox/StatsVBox/HPBar
@onready var hp_label: Label = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox/StatsVBox/HPLabel
@onready var combat_hbox: HBoxContainer = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox/StatsVBox/CombatHBox
@onready var atk_label: Label = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox/StatsVBox/CombatHBox/AtkLabel
@onready var arm_label: Label = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/DetailsHBox/StatsVBox/CombatHBox/ArmLabel
@onready var status_or_queue_label: Label = $BottomConsole/Margin/HBox/LeftInfoBox/Margin/VBox/StatusOrQueueLabel

# Center Action Box Nodes
@onready var pharaoh_relief: TextureRect = $BottomConsole/Margin/HBox/CenterActionBox/Margin/PharaohRelief
@onready var villager_action_menu: HBoxContainer = $BottomConsole/Margin/HBox/CenterActionBox/Margin/VillagerActionMenu
@onready var btn_econ: Button = $BottomConsole/Margin/HBox/CenterActionBox/Margin/VillagerActionMenu/BtnEcon
@onready var btn_mil: Button = $BottomConsole/Margin/HBox/CenterActionBox/Margin/VillagerActionMenu/BtnMil
@onready var btn_repair: Button = $BottomConsole/Margin/HBox/CenterActionBox/Margin/VillagerActionMenu/BtnRepair

@onready var sub_building_grid: VBoxContainer = $BottomConsole/Margin/HBox/CenterActionBox/Margin/SubBuildingGrid
@onready var sub_menu_title: Label = $BottomConsole/Margin/HBox/CenterActionBox/Margin/SubBuildingGrid/SubHeaderHBox/SubMenuTitle
@onready var btn_back_from_sub: Button = $BottomConsole/Margin/HBox/CenterActionBox/Margin/SubBuildingGrid/SubHeaderHBox/BtnBackFromSub
@onready var building_buttons_hbox: HBoxContainer = $BottomConsole/Margin/HBox/CenterActionBox/Margin/SubBuildingGrid/ScrollContainer/BuildingButtonsHBox

@onready var building_production_menu: VBoxContainer = $BottomConsole/Margin/HBox/CenterActionBox/Margin/BuildingProductionMenu
@onready var building_prod_title: Label = $BottomConsole/Margin/HBox/CenterActionBox/Margin/BuildingProductionMenu/ProdHeaderHBox/BuildingProdTitle
@onready var btn_cancel_prod: Button = $BottomConsole/Margin/HBox/CenterActionBox/Margin/BuildingProductionMenu/ProdHeaderHBox/BtnCancelProd
@onready var prod_buttons_hbox: HBoxContainer = $BottomConsole/Margin/HBox/CenterActionBox/Margin/BuildingProductionMenu/ProdButtonsScroll/ProdButtonsHBox

# State Tracking
var current_selected_building: BaseBuilding = null
var current_selected_unit: BaseUnit = null
var is_in_sub_menu: bool = false
var sub_menu_mode: String = "" # "econ" or "mil"

const BUILDING_DATA: Dictionary = {
	# Economic (B)
	"house": {
		"name": "House",
		"cost": "30 Wood",
		"icon": "res://assets/ui/icon_house.png",
		"category": "econ",
		"age": 0,
		"desc": "Provides +4 Population capacity."
	},
	"granary": {
		"name": "Granary",
		"cost": "120 Wood",
		"icon": "res://assets/ui/icon_granary.png",
		"category": "econ",
		"age": 0,
		"desc": "Drop-off site for Foraged Berries & Farm Food. Unlocks Walls and Towers."
	},
	"storage_pit": {
		"name": "Storage Pit",
		"cost": "120 Wood",
		"icon": "res://assets/ui/icon_storage.png",
		"category": "econ",
		"age": 0,
		"desc": "Drop-off site for Wood, Gold, Stone, and Hunted Meat. Provides armor upgrades."
	},
	"farm": {
		"name": "Farm",
		"cost": "75 Wood",
		"icon": "res://assets/ui/icon_farm.png",
		"category": "econ",
		"age": 1,
		"desc": "Renewable Food source. Requires Tool Age and Market."
	},
	"market": {
		"name": "Market",
		"cost": "150 Wood",
		"icon": "res://assets/ui/icon_market.png",
		"category": "econ",
		"age": 1,
		"desc": "Economic hub. Provides Woodworking, Mining, and Farm upgrades."
	},
	# Military (V)
	"barracks": {
		"name": "Barracks",
		"cost": "175 Wood",
		"icon": "res://assets/ui/icon_barracks.png",
		"category": "mil",
		"age": 0,
		"desc": "Trains infantry (Clubman, Axeman, Swordsman)."
	},
	"archery_range": {
		"name": "Archery Range",
		"cost": "150 Wood",
		"icon": "res://assets/ui/icon_archery.png",
		"category": "mil",
		"age": 1,
		"desc": "Trains ranged units (Bowman, Improved Bowman, Composite Bowman)."
	},
	"stable": {
		"name": "Stable",
		"cost": "150 Wood",
		"icon": "res://assets/ui/icon_stable.png",
		"category": "mil",
		"age": 1,
		"desc": "Trains cavalry units (Scout, Cavalry, Heavy Cavalry)."
	},
	"small_wall": {
		"name": "Small Wall",
		"cost": "5 Stone",
		"icon": "res://assets/ui/icon_wall.png",
		"category": "mil",
		"age": 1,
		"desc": "Defensive perimeter fortification. Requires Small Wall research at Granary."
	},
	"watch_tower": {
		"name": "Watch Tower",
		"cost": "150 Stone",
		"icon": "res://assets/ui/icon_tower.png",
		"category": "mil",
		"age": 1,
		"desc": "Defensive tower that attacks nearby enemy units automatically."
	},
	"temple": {
		"name": "Temple",
		"cost": "200 Wood",
		"icon": "res://assets/ui/icon_temple.png",
		"category": "mil",
		"age": 2,
		"desc": "Religious shrine. Trains Priests that heal and convert enemies."
	},
	"siege_workshop": {
		"name": "Siege Workshop",
		"cost": "200 Wood",
		"icon": "res://assets/ui/icon_siege.png",
		"category": "mil",
		"age": 2,
		"desc": "Constructs artillery catapults and ballistas."
	}
}

func _get_my_id() -> int:
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func _get_tech_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("TechManager")
	return null

func _get_game_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("GameManager")
	return null

func _ready() -> void:
	var my_id := _get_my_id()
	var game_mgr := _get_game_manager()
	if game_mgr:
		if not game_mgr.player_resources.has(my_id):
			game_mgr.init_player(my_id)
		game_mgr.resource_updated.connect(_on_resource_updated)
		game_mgr.population_updated.connect(_on_population_updated)
		_update_display()

	var tech_mgr := _get_tech_manager()
	if tech_mgr:
		tech_mgr.tech_completed.connect(_on_tech_completed)
		tech_mgr.age_advanced.connect(_on_age_advanced)
		tech_mgr.building_unlocked.connect(func(_p, _b):
			if is_in_sub_menu:
				_populate_sub_building_menu(sub_menu_mode)
		)

	# Connect buttons
	if btn_econ and not btn_econ.pressed.is_connected(_on_btn_econ_pressed):
		btn_econ.pressed.connect(_on_btn_econ_pressed)
	if btn_mil and not btn_mil.pressed.is_connected(_on_btn_mil_pressed):
		btn_mil.pressed.connect(_on_btn_mil_pressed)
	if btn_repair and not btn_repair.pressed.is_connected(_on_repair_pressed):
		btn_repair.pressed.connect(_on_repair_pressed)
	if btn_back_from_sub and not btn_back_from_sub.pressed.is_connected(_close_sub_building_menu):
		btn_back_from_sub.pressed.connect(_close_sub_building_menu)
	if btn_cancel_prod and not btn_cancel_prod.pressed.is_connected(_on_cancel_prod_pressed):
		btn_cancel_prod.pressed.connect(_on_cancel_prod_pressed)

	_update_age_label()
	_show_idle_relief()

	if is_inside_tree() and get_tree():
		await get_tree().process_frame
		if get_tree() and get_tree().root:
			var sel_system := get_tree().root.get_node_or_null("Main/SelectionSystem")
			if sel_system:
				sel_system.selection_changed.connect(_on_selection_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	# Phím tắt chuẩn AoE 1: B (Economic), V (Military), X/Escape (Cancel/Back)
	if current_selected_unit and current_selected_unit is Villager:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_X):
			if is_in_sub_menu:
				_close_sub_building_menu()
				get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_B:
				_open_sub_building_menu("econ")
				get_viewport().set_input_as_handled()
			elif key_event.keycode == KEY_V:
				_open_sub_building_menu("mil")
				get_viewport().set_input_as_handled()
			elif key_event.keycode == KEY_R:
				_on_repair_pressed()
				get_viewport().set_input_as_handled()

func _update_age_label() -> void:
	var tm := _get_tech_manager()
	var my_id := _get_my_id()
	var age_num: int = tm.get_player_age(my_id) if tm else 0
	if age_label:
		age_label.text = _get_age_name(age_num)

func _get_age_name(a: int) -> String:
	match a:
		0: return "Stone Age"
		1: return "Tool Age"
		2: return "Bronze Age"
		3: return "Iron Age"
	return "Stone Age"

func _on_age_advanced(peer_id: int, new_age: int) -> void:
	var my_id := _get_my_id()
	if peer_id == my_id or peer_id == 1:
		if age_label:
			age_label.text = _get_age_name(new_age)
			var tween := create_tween()
			age_label.modulate = Color.WHITE
			tween.tween_property(age_label, "modulate", Color(0.95, 0.80, 0.20, 1.0), 1.2)
		set_tooltip("Advanced to %s!" % _get_age_name(new_age))
		if is_in_sub_menu:
			_populate_sub_building_menu(sub_menu_mode)
		elif current_selected_building and is_instance_valid(current_selected_building):
			_populate_production_menu(current_selected_building)

func _on_tech_completed(peer_id: int, tech_id: String) -> void:
	var my_id := _get_my_id()
	if peer_id == my_id or peer_id == 1:
		var tm := _get_tech_manager()
		var t_name := tech_id
		if tm and tm.TECH_DATABASE.has(tech_id):
			t_name = tm.TECH_DATABASE[tech_id].get("name", tech_id)
		set_tooltip("Research completed: %s!" % t_name)
		if is_in_sub_menu:
			_populate_sub_building_menu(sub_menu_mode)
		elif current_selected_building and is_instance_valid(current_selected_building):
			_populate_production_menu(current_selected_building)

func set_tooltip(msg: String) -> void:
	if tooltip_label:
		tooltip_label.text = msg

# --- Selection & Action Area Flow ---

func _show_idle_relief() -> void:
	is_in_sub_menu = false
	if pharaoh_relief: pharaoh_relief.visible = true
	if villager_action_menu: villager_action_menu.visible = false
	if sub_building_grid: sub_building_grid.visible = false
	if building_production_menu: building_production_menu.visible = false
	if entity_title: entity_title.text = "No Selection"
	if details_hbox: details_hbox.visible = false
	if status_or_queue_label: status_or_queue_label.text = ""

func _on_selection_changed(selected_entities: Array) -> void:
	current_selected_building = null
	current_selected_unit = null
	is_in_sub_menu = false

	if selected_entities.is_empty():
		_show_idle_relief()
		set_tooltip("Click to select units or buildings.")
		return

	var first = selected_entities[0]
	if not is_instance_valid(first):
		_show_idle_relief()
		return

	if selected_entities.size() == 1 and first is BaseBuilding:
		var b: BaseBuilding = first
		current_selected_building = b
		_display_building_info(b)
		_populate_production_menu(b)
	elif selected_entities.size() > 0 and first is BaseUnit:
		var u: BaseUnit = first
		current_selected_unit = u
		_display_unit_info(u, selected_entities.size())
		if u is Villager:
			_show_villager_menu()
		else:
			_show_idle_relief()
			# Chỉ giữ hiển thị thông tin bên LeftInfoBox
			_display_unit_info(u, selected_entities.size())
	elif first is BaseAnimal or first.is_in_group("animals"):
		_show_idle_relief()
		_display_animal_info(first)
	elif first is ResourceSource or first.is_in_group("resources"):
		_show_idle_relief()
		_display_resource_info(first)
	else:
		_show_idle_relief()

func _display_animal_info(a: Node) -> void:
	if pharaoh_relief: pharaoh_relief.visible = true
	if details_hbox: details_hbox.visible = true
	if thumbnail_rect:
		thumbnail_rect.visible = true
		thumbnail_rect.texture = preload("res://assets/ui/icon_sword.png")

	var is_dead: bool = ("state" in a and a.state == 5) or ("current_hp" in a and a.current_hp <= 0)
	var a_name: String = a.animal_name if "animal_name" in a else "Animal"

	if is_dead:
		if entity_title: entity_title.text = "Dead " + a_name
		var curr_meat: int = a.current_amount if "current_amount" in a else 0
		var max_meat: int = a.max_amount if "max_amount" in a else 150
		_update_hp_display(curr_meat, max_meat)
		if hp_label: hp_label.text = "Meat: %d / %d" % [curr_meat, max_meat]
		if combat_hbox: combat_hbox.visible = false
		if status_or_queue_label: status_or_queue_label.text = "Harvestable Meat"
		set_tooltip("Dead %s - %d Food remaining for gatherers." % [a_name, curr_meat])
	else:
		if entity_title: entity_title.text = a_name
		var curr_hp: int = a.current_hp if "current_hp" in a else 25
		var max_hp: int = a.max_hp if "max_hp" in a else 25
		_update_hp_display(curr_hp, max_hp)
		var dmg: int = a.attack_damage if "attack_damage" in a else 0
		if combat_hbox: combat_hbox.visible = (dmg > 0)
		if atk_label: atk_label.text = str(dmg)
		if arm_label: arm_label.text = "0 / 0"
		var meat: int = a.meat_amount if "meat_amount" in a else 150
		if status_or_queue_label: status_or_queue_label.text = "Meat: %d" % meat
		set_tooltip("Wild %s - HP: %d/%d, Food: %d" % [a_name, curr_hp, max_hp, meat])

func _display_resource_info(res: Node) -> void:
	if pharaoh_relief: pharaoh_relief.visible = true
	if details_hbox: details_hbox.visible = true
	if combat_hbox: combat_hbox.visible = false
	if thumbnail_rect: thumbnail_rect.visible = false

	var res_type: int = res.resource_type if "resource_type" in res else 1
	var type_name := "Wood"
	match res_type:
		0: type_name = "Berry Bush" if not ("is_meat" in res and res.is_meat) else "Meat Carcass"
		1: type_name = "Tree (Wood)"
		2: type_name = "Gold Mine"
		3: type_name = "Stone Mine"

	if entity_title: entity_title.text = type_name
	var curr: int = res.current_amount if "current_amount" in res else 300
	var max_amt: int = res.max_amount if "max_amount" in res else 300
	_update_hp_display(curr, max_amt)
	if hp_label: hp_label.text = "Left: %d / %d" % [curr, max_amt]
	if status_or_queue_label: status_or_queue_label.text = "Resource Source"
	set_tooltip("%s - %d remaining." % [type_name, curr])

func _display_unit_info(u: BaseUnit, group_count: int) -> void:
	if pharaoh_relief: pharaoh_relief.visible = (u is not Villager)
	if details_hbox: details_hbox.visible = true
	if combat_hbox: combat_hbox.visible = true

	var u_name := _get_unit_display_name(u)
	if entity_title:
		entity_title.text = u_name if group_count == 1 else "%s (%d units)" % [u_name, group_count]

	if thumbnail_rect:
		thumbnail_rect.visible = true
		if u is Villager:
			thumbnail_rect.texture = preload("res://assets/ui/portrait_villager.png")
		else:
			thumbnail_rect.texture = preload("res://assets/ui/icon_sword.png")

	_update_hp_display(u.current_hp, u.max_hp)

	if atk_label:
		atk_label.text = str(u.melee_attack + u.pierce_attack)
	if arm_label:
		arm_label.text = "%d / %d" % [u.melee_armor, u.pierce_armor]

	set_tooltip("Selected %s." % u_name)

func _display_building_info(b: BaseBuilding) -> void:
	if details_hbox: details_hbox.visible = true
	if combat_hbox: combat_hbox.visible = false
	if thumbnail_rect: thumbnail_rect.visible = false

	var b_name := _get_building_display_name(b)
	if entity_title:
		entity_title.text = b_name

	_update_hp_display(b.current_hp, b.max_hp)
	set_tooltip("Selected %s." % b_name)

func _update_hp_display(curr: int, maximum: int) -> void:
	if hp_bar:
		hp_bar.max_value = float(maximum)
		hp_bar.value = float(curr)
	if hp_label:
		hp_label.text = "HP: %d / %d" % [curr, maximum]

func _show_villager_menu() -> void:
	if pharaoh_relief: pharaoh_relief.visible = false
	if villager_action_menu: villager_action_menu.visible = true
	if sub_building_grid: sub_building_grid.visible = false
	if building_production_menu: building_production_menu.visible = false
	set_tooltip("Villager ready. Press (B) for Economic buildings, (V) for Military.")

func _on_btn_econ_pressed() -> void:
	_open_sub_building_menu("econ")

func _on_btn_mil_pressed() -> void:
	_open_sub_building_menu("mil")

func _open_sub_building_menu(mode: String) -> void:
	is_in_sub_menu = true
	sub_menu_mode = mode
	if villager_action_menu: villager_action_menu.visible = false
	if sub_building_grid: sub_building_grid.visible = true
	if sub_menu_title:
		sub_menu_title.text = "Economic Buildings (B)" if mode == "econ" else "Military Buildings (V)"
	_populate_sub_building_menu(mode)

func _close_sub_building_menu() -> void:
	is_in_sub_menu = false
	build_requested.emit("cancel")
	if current_selected_unit and current_selected_unit is Villager:
		_show_villager_menu()
	else:
		_show_idle_relief()

func _on_repair_pressed() -> void:
	set_tooltip("Click an injured building to repair it.")

func _populate_sub_building_menu(mode: String) -> void:
	if not building_buttons_hbox:
		return

	for c in building_buttons_hbox.get_children():
		c.queue_free()

	var tm := _get_tech_manager()
	var my_id := _get_my_id()
	var current_age: int = tm.get_player_age(my_id) if tm else 0

	for b_id in BUILDING_DATA:
		var data: Dictionary = BUILDING_DATA[b_id]
		if data.get("category", "") != mode:
			continue

		var is_unlocked: bool = tm.is_building_unlocked(my_id, b_id) if tm else true
		var age_req: int = data.get("age", 0)

		# CHỈ HIỂN THỊ CÁC CÔNG TRÌNH ĐÃ MỞ KHÓA HOẶC CÔNG TRÌNH CỦA ĐỜI NÀY
		# Nếu công trình thuộc kỷ nguyên tương lai chưa tới, ẩn hoàn toàn (Zero Clutter!)
		if current_age < age_req:
			continue

		var btn := Button.new()
		btn.text = "%s\n(%s)" % [data["name"], data["cost"]]
		if ResourceLoader.exists(data["icon"]):
			btn.icon = load(data["icon"])
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(90, 80)

		btn.disabled = not is_unlocked
		if not is_unlocked:
			btn.modulate = Color(0.6, 0.6, 0.6, 0.45)
			btn.tooltip_text = "%s - Requires research / prerequisites." % data["name"]
		else:
			btn.modulate = Color.WHITE
			btn.tooltip_text = "%s: %s\nCost: %s" % [data["name"], data["desc"], data["cost"]]

		var bound_id: String = b_id
		btn.mouse_entered.connect(func():
			set_tooltip("%s (%s): %s" % [data["name"], data["cost"], data["desc"]])
		)
		btn.pressed.connect(func():
			build_requested.emit(bound_id)
			set_tooltip("Placing %s. Left-click to place, Right-click to cancel." % data["name"])
		)

		building_buttons_hbox.add_child(btn)

func _populate_production_menu(b: BaseBuilding) -> void:
	if pharaoh_relief: pharaoh_relief.visible = false
	if villager_action_menu: villager_action_menu.visible = false
	if sub_building_grid: sub_building_grid.visible = false
	if not building_production_menu: return
	building_production_menu.visible = true

	if building_prod_title:
		building_prod_title.text = "%s - Commands & Research" % _get_building_display_name(b)

	for c in prod_buttons_hbox.get_children():
		c.queue_free()

	var tm := _get_tech_manager()
	var my_id := _get_my_id()

	# 1. Đơn vị có thể huấn luyện theo từng loại nhà
	match b.building_type:
		BaseBuilding.BuildingType.TOWN_CENTER:
			_add_train_button("Train Villager", "50 Food", "res://assets/ui/portrait_villager.png", func():
				_train_unit_from_tc()
			)
		BaseBuilding.BuildingType.BARRACKS:
			_add_train_button("Train Swordsman", "60 Food, 20 Gold", "res://assets/ui/icon_sword.png", func():
				_train_military_unit("swordsman", 60, 0, 20)
			)
		BaseBuilding.BuildingType.ARCHERY_RANGE:
			_add_train_button("Train Archer", "40 Wood, 30 Gold", "res://assets/ui/icon_sword.png", func():
				_train_military_unit("archer", 0, 40, 30)
			)
		BaseBuilding.BuildingType.STABLE:
			_add_train_button("Train Cavalry", "70 Food", "res://assets/ui/icon_sword.png", func():
				_train_military_unit("cavalry", 70, 0, 0)
			)
		BaseBuilding.BuildingType.TEMPLE:
			_add_train_button("Train Priest", "125 Gold", "res://assets/ui/icon_sword.png", func():
				_train_military_unit("priest", 0, 0, 125)
			)
		BaseBuilding.BuildingType.SIEGE_WORKSHOP:
			_add_train_button("Build Catapult", "180 Wood, 80 Gold", "res://assets/ui/icon_sword.png", func():
				_train_military_unit("siege_catapult", 0, 180, 80)
			)

	# 2. Công nghệ và Kỷ nguyên tiếp theo (Chỉ hiện nút Lên Đời duy nhất khả thi!)
	if tm:
		var filter := _get_building_filter(b)
		for tech_id in tm.TECH_DATABASE:
			var t_data: Dictionary = tm.TECH_DATABASE[tech_id]
			if t_data.get("building", "") != filter:
				continue
			if tm.is_researched(my_id, tech_id):
				continue
			if not tm.can_research(my_id, tech_id):
				continue

			var t_name: String = t_data.get("name", tech_id)
			var c_dict: Dictionary = t_data.get("cost", {})
			var cost_str := ""
			for r_type in c_dict:
				var r_name := "Food"
				match r_type:
					ResourceSource.ResourceType.WOOD: r_name = "Wood"
					ResourceSource.ResourceType.FOOD: r_name = "Food"
					ResourceSource.ResourceType.GOLD: r_name = "Gold"
					ResourceSource.ResourceType.STONE: r_name = "Stone"
				cost_str += "%d %s " % [c_dict[r_type], r_name]

			var btn := Button.new()
			btn.text = "Research %s\n(%s)" % [t_name, cost_str.strip_edges()]
			btn.modulate = Color(1.0, 0.90, 0.35, 1.0)
			btn.custom_minimum_size = Vector2(120, 60)
			var bound_t_id: String = tech_id
			btn.mouse_entered.connect(func():
				set_tooltip("%s: %s" % [t_name, t_data.get("description", "")])
			)
			btn.pressed.connect(func():
				_research_tech(bound_t_id)
			)
			prod_buttons_hbox.add_child(btn)

func _add_train_button(name_str: String, cost_str: String, icon_path: String, on_click: Callable) -> void:
	var btn := Button.new()
	btn.text = "%s\n(%s)" % [name_str, cost_str]
	if ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.expand_icon = true
	btn.custom_minimum_size = Vector2(110, 60)
	btn.mouse_entered.connect(func():
		set_tooltip("%s (%s)" % [name_str, cost_str])
	)
	btn.pressed.connect(on_click)
	prod_buttons_hbox.add_child(btn)

func _train_unit_from_tc() -> void:
	if not current_selected_building or not is_instance_valid(current_selected_building):
		return
	var gm := _get_game_manager()
	var my_id := _get_my_id()
	if not gm: return

	# 50 Food
	if gm.get_resource(my_id, ResourceSource.ResourceType.FOOD) >= 50:
		gm.spend_resource(my_id, ResourceSource.ResourceType.FOOD, 50)
		current_selected_building.add_to_queue({
			"type": "unit",
			"unit_name": "villager",
			"time": 8.0
		})
		set_tooltip("Training Villager queued.")
	else:
		set_tooltip("Not enough Food! (Needs 50 Food)")

func _train_military_unit(u_name: String, food: int, wood: int, gold: int) -> void:
	if not current_selected_building or not is_instance_valid(current_selected_building):
		return
	var gm := _get_game_manager()
	var my_id := _get_my_id()
	if not gm: return

	if gm.get_resource(my_id, ResourceSource.ResourceType.FOOD) < food:
		set_tooltip("Not enough Food! (Needs %d Food)" % food)
		return
	if gm.get_resource(my_id, ResourceSource.ResourceType.WOOD) < wood:
		set_tooltip("Not enough Wood! (Needs %d Wood)" % wood)
		return
	if gm.get_resource(my_id, ResourceSource.ResourceType.GOLD) < gold:
		set_tooltip("Not enough Gold! (Needs %d Gold)" % gold)
		return

	if food > 0: gm.spend_resource(my_id, ResourceSource.ResourceType.FOOD, food)
	if wood > 0: gm.spend_resource(my_id, ResourceSource.ResourceType.WOOD, wood)
	if gold > 0: gm.spend_resource(my_id, ResourceSource.ResourceType.GOLD, gold)

	current_selected_building.add_to_queue({
		"type": "unit",
		"unit_name": u_name,
		"time": 10.0
	})
	set_tooltip("Training %s queued." % u_name)

func _research_tech(tech_id: String) -> void:
	if not current_selected_building or not is_instance_valid(current_selected_building):
		return
	var tm := _get_tech_manager()
	var gm := _get_game_manager()
	var my_id := _get_my_id()
	if not tm or not gm: return

	var t_data: Dictionary = tm.TECH_DATABASE.get(tech_id, {})
	var c_dict: Dictionary = t_data.get("cost", {})
	for r_type in c_dict:
		if gm.get_resource(my_id, r_type) < c_dict[r_type]:
			set_tooltip("Not enough resources to research %s!" % t_data.get("name", tech_id))
			return

	for r_type in c_dict:
		gm.spend_resource(my_id, r_type, c_dict[r_type])

	current_selected_building.add_to_queue({
		"type": "tech",
		"tech_id": tech_id,
		"time": t_data.get("research_time", 30.0)
	})
	set_tooltip("Researching %s..." % t_data.get("name", tech_id))
	_populate_production_menu(current_selected_building)

func _on_cancel_prod_pressed() -> void:
	if current_selected_building and is_instance_valid(current_selected_building):
		if not current_selected_building.production_queue.is_empty():
			current_selected_building.production_queue.pop_back()
			set_tooltip("Cancelled latest production item.")
			_populate_production_menu(current_selected_building)

func _process(_delta: float) -> void:
	if current_selected_building and is_instance_valid(current_selected_building):
		_update_hp_display(current_selected_building.current_hp, current_selected_building.max_hp)
		var q_count := current_selected_building.production_queue.size()
		if q_count > 0:
			var curr: Dictionary = current_selected_building.production_queue[0]
			var progress := int((current_selected_building.production_timer / curr["time"]) * 100.0)
			if curr.get("type", "") == "tech":
				var tm = get_node_or_null("/root/TechManager")
				var t_name: String = curr.get("tech_id", "")
				if tm and tm.TECH_DATABASE.has(t_name):
					t_name = tm.TECH_DATABASE[t_name].get("name", t_name)
				status_or_queue_label.text = "Research: %s (%d%%)" % [t_name, progress]
			else:
				status_or_queue_label.text = "Queue: %d (%d%%)" % [q_count, progress]
		else:
			status_or_queue_label.text = "Queue: 0"
	elif current_selected_unit and is_instance_valid(current_selected_unit):
		_update_hp_display(current_selected_unit.current_hp, current_selected_unit.max_hp)
		if current_selected_unit is Villager:
			var v := current_selected_unit as Villager
			var type_str := "Wood"
			match v.carried_type:
				ResourceSource.ResourceType.FOOD: type_str = "Food"
				ResourceSource.ResourceType.WOOD: type_str = "Wood"
				ResourceSource.ResourceType.GOLD: type_str = "Gold"
				ResourceSource.ResourceType.STONE: type_str = "Stone"
			var state_str := "Idle"
			match v.state:
				BaseUnit.UnitState.GATHERING:
					state_str = "Returning" if v.carried_amount >= v.carry_capacity else "Gathering"
				BaseUnit.UnitState.MOVING: state_str = "Moving"
				BaseUnit.UnitState.BUILDING: state_str = "Constructing"
			status_or_queue_label.text = "Carrying: %d/%d %s [%s]" % [v.carried_amount, v.carry_capacity, type_str, state_str]

func _get_unit_display_name(u: BaseUnit) -> String:
	match u.unit_type:
		BaseUnit.UnitType.VILLAGER: return "Villager"
		BaseUnit.UnitType.INFANTRY: return "Swordsman"
		BaseUnit.UnitType.ARCHER: return "Archer"
		BaseUnit.UnitType.CAVALRY: return "Scout Cavalry"
		BaseUnit.UnitType.PRIEST: return "Priest"
		BaseUnit.UnitType.SIEGE: return "Siege Catapult"
	return "Unit"

func _get_building_display_name(b: BaseBuilding) -> String:
	match b.building_type:
		BaseBuilding.BuildingType.TOWN_CENTER: return "Town Center"
		BaseBuilding.BuildingType.HOUSE: return "House"
		BaseBuilding.BuildingType.BARRACKS: return "Barracks"
		BaseBuilding.BuildingType.STORAGE_PIT: return "Storage Pit"
		BaseBuilding.BuildingType.GRANARY: return "Granary"
		BaseBuilding.BuildingType.WATCH_TOWER: return "Watch Tower"
		BaseBuilding.BuildingType.SMALL_WALL: return "Small Wall"
		BaseBuilding.BuildingType.FARM: return "Farm"
		BaseBuilding.BuildingType.MARKET: return "Market"
		BaseBuilding.BuildingType.ARCHERY_RANGE: return "Archery Range"
		BaseBuilding.BuildingType.STABLE: return "Stable"
		BaseBuilding.BuildingType.TEMPLE: return "Temple"
		BaseBuilding.BuildingType.SIEGE_WORKSHOP: return "Siege Workshop"
	return "Building"

func _get_building_filter(b: BaseBuilding) -> String:
	match b.building_type:
		BaseBuilding.BuildingType.TOWN_CENTER: return "town_center"
		BaseBuilding.BuildingType.BARRACKS: return "barracks"
		BaseBuilding.BuildingType.STORAGE_PIT: return "storage_pit"
		BaseBuilding.BuildingType.GRANARY: return "granary"
		BaseBuilding.BuildingType.MARKET: return "market"
		BaseBuilding.BuildingType.TEMPLE: return "temple"
		BaseBuilding.BuildingType.SIEGE_WORKSHOP: return "siege_workshop"
	return ""

func _on_resource_updated(peer_id: int, type: ResourceSource.ResourceType, amount: int) -> void:
	var my_id := _get_my_id()
	if peer_id == my_id:
		match type:
			ResourceSource.ResourceType.WOOD: if wood_label: wood_label.text = str(amount)
			ResourceSource.ResourceType.FOOD: if food_label: food_label.text = str(amount)
			ResourceSource.ResourceType.GOLD: if gold_label: gold_label.text = str(amount)
			ResourceSource.ResourceType.STONE: if stone_label: stone_label.text = str(amount)

func _on_population_updated(peer_id: int, current_pop: int, max_pop: int) -> void:
	var my_id := _get_my_id()
	if peer_id == my_id and pop_label:
		pop_label.text = "%d/%d" % [current_pop, max_pop]

func _update_display() -> void:
	var my_id := _get_my_id()
	var gm := _get_game_manager()
	if not gm: return
	if wood_label: wood_label.text = str(gm.get_resource(my_id, ResourceSource.ResourceType.WOOD))
	if food_label: food_label.text = str(gm.get_resource(my_id, ResourceSource.ResourceType.FOOD))
	if gold_label: gold_label.text = str(gm.get_resource(my_id, ResourceSource.ResourceType.GOLD))
	if stone_label: stone_label.text = str(gm.get_resource(my_id, ResourceSource.ResourceType.STONE))
	if pop_label and gm.player_population.has(my_id):
		var p: Dictionary = gm.player_population[my_id]
		pop_label.text = "%d/%d" % [p["current"], p["max"]]
