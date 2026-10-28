class_name RTSHUD
extends Control

@onready var food_label: Label = $TopBar/HBox/FoodLabel
@onready var wood_label: Label = $TopBar/HBox/WoodLabel
@onready var gold_label: Label = $TopBar/HBox/GoldLabel
@onready var stone_label: Label = $TopBar/HBox/StoneLabel
@onready var pop_label: Label = $TopBar/HBox/PopLabel

@onready var build_house_btn: Button = get_node_or_null("BuildMenu/HBox/BuildHouseBtn")
@onready var build_granary_btn: Button = get_node_or_null("BuildMenu/HBox/BuildGranaryBtn")
@onready var build_storage_pit_btn: Button = get_node_or_null("BuildMenu/HBox/BuildStoragePitBtn")
@onready var build_barracks_btn: Button = get_node_or_null("BuildMenu/HBox/BuildBarracksBtn")
@onready var build_mine_btn: Button = get_node_or_null("BuildMenu/HBox/BuildMineBtn")
@onready var cancel_build_btn: Button = get_node_or_null("BuildMenu/HBox/CancelBuildBtn")

signal build_requested(building_type: String)

@onready var action_panel: PanelContainer = get_node_or_null("ActionPanel")
@onready var action_title: Label = get_node_or_null("ActionPanel/VBox/TitleLabel")
@onready var action_queue: Label = get_node_or_null("ActionPanel/VBox/QueueLabel")
@onready var buttons_hbox: HBoxContainer = get_node_or_null("ActionPanel/VBox/ButtonsHBox")
@onready var train_btn: Button = get_node_or_null("ActionPanel/VBox/ButtonsHBox/TrainBtn")
@onready var train_archer_btn: Button = get_node_or_null("ActionPanel/VBox/ButtonsHBox/TrainArcherBtn")

var current_selected_building: BaseBuilding = null
var current_selected_unit: BaseUnit = null
var _dynamic_tech_buttons: Array[Button] = []

func _ready() -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var game_mgr := get_node_or_null("/root/GameManager")
	if game_mgr:
		if not game_mgr.player_resources.has(my_id):
			game_mgr.init_player(my_id)
		game_mgr.resource_updated.connect(_on_resource_updated)
		game_mgr.population_updated.connect(_on_population_updated)
		_update_display()

	if action_panel:
		action_panel.visible = false

	# Connect build buttons
	if build_house_btn:
		build_house_btn.pressed.connect(func():
			build_requested.emit("house")
		)
	if build_granary_btn:
		build_granary_btn.pressed.connect(func():
			build_requested.emit("granary")
		)
	if build_storage_pit_btn:
		build_storage_pit_btn.pressed.connect(func():
			build_requested.emit("storage_pit")
		)
	if build_barracks_btn:
		build_barracks_btn.pressed.connect(func():
			build_requested.emit("barracks")
		)
	if build_mine_btn:
		build_mine_btn.pressed.connect(func():
			build_requested.emit("storage_pit")
		)
	if cancel_build_btn:
		cancel_build_btn.pressed.connect(func():
			build_requested.emit("cancel")
		)

	var tech_mgr = get_node_or_null("/root/TechManager")
	if tech_mgr:
		tech_mgr.tech_completed.connect(_on_tech_completed)

	if train_btn:
		train_btn.pressed.connect(func():
			_on_train_btn_pressed()
		)
	if train_archer_btn:
		train_archer_btn.pressed.connect(func():
			_on_train_archer_btn_pressed()
		)

	await get_tree().process_frame
	var sel_system := get_tree().root.get_node_or_null("Main/SelectionSystem")
	if sel_system:
		sel_system.selection_changed.connect(_on_selection_changed)

func _process(_delta: float) -> void:
	if current_selected_building and is_instance_valid(current_selected_building) and action_queue:
		var q_count := current_selected_building.production_queue.size()
		if q_count > 0:
			var curr: Dictionary = current_selected_building.production_queue[0]
			var progress := int((current_selected_building.production_timer / curr["time"]) * 100.0)
			if curr.get("type", "") == "tech":
				var tm = get_node_or_null("/root/TechManager")
				var t_name: String = curr.get("tech_id", "")
				if tm and tm.TECH_DATABASE.has(t_name):
					t_name = tm.TECH_DATABASE[t_name].get("name", t_name)
				action_queue.text = "Research: %s (%d%%)" % [t_name, progress]
			else:
				action_queue.text = "Queue: %d (%d%%)" % [q_count, progress]
		else:
			action_queue.text = "Queue: 0"
	elif current_selected_unit and is_instance_valid(current_selected_unit) and action_title:
		action_title.text = "%s [HP: %d/%d]" % [_get_unit_display_name(current_selected_unit), current_selected_unit.current_hp, current_selected_unit.max_hp]
		if action_queue and current_selected_unit is Villager:
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
			action_queue.text = "Carrying: %d/%d %s [%s]" % [v.carried_amount, v.carry_capacity, type_str, state_str]

func _get_unit_display_name(u: BaseUnit) -> String:
	match u.unit_type:
		BaseUnit.UnitType.VILLAGER: return "Villager"
		BaseUnit.UnitType.INFANTRY: return "Swordsman"
		BaseUnit.UnitType.ARCHER: return "Archer"
		BaseUnit.UnitType.CAVALRY: return "Cavalry"
	return "Unit"

func _on_selection_changed(selected_entities: Array) -> void:
	current_selected_building = null
	current_selected_unit = null
	_clear_tech_buttons()
	if not action_panel:
		return

	if selected_entities.size() == 1 and selected_entities[0] is BaseBuilding:
		var b: BaseBuilding = selected_entities[0]
		current_selected_building = b
		action_panel.visible = true
		if b.building_type == BaseBuilding.BuildingType.TOWN_CENTER:
			action_title.text = "Town Center (HQ)"
			train_btn.text = "Train Villager (50F)"
			train_btn.visible = true
			if train_archer_btn:
				train_archer_btn.visible = false
		elif b.building_type == BaseBuilding.BuildingType.BARRACKS:
			action_title.text = "Barracks (Military)"
			train_btn.text = "Train Swordsman (60F, 20G)"
			train_btn.visible = true
			if train_archer_btn:
				train_archer_btn.text = "Train Archer (40W, 30G)"
				train_archer_btn.visible = true
		elif b.building_type == BaseBuilding.BuildingType.STORAGE_PIT:
			action_title.text = "Storage Pit (Resources & Armory)"
			train_btn.visible = false
			if train_archer_btn:
				train_archer_btn.visible = false
			_populate_tech_buttons("storage_pit")
		elif b.building_type == BaseBuilding.BuildingType.GRANARY:
			action_title.text = "Granary (Food & Defense)"
			train_btn.visible = false
			if train_archer_btn:
				train_archer_btn.visible = false
			_populate_tech_buttons("granary")
		else:
			action_title.text = "Building"
			train_btn.visible = false
			if train_archer_btn:
				train_archer_btn.visible = false
	elif selected_entities.size() > 0 and selected_entities[0] is BaseUnit:
		# Hiển thị thông tin đơn vị đang chọn
		var u: BaseUnit = selected_entities[0]
		current_selected_unit = u
		action_panel.visible = true
		var u_name := "Unit"
		match u.unit_type:
			BaseUnit.UnitType.VILLAGER: u_name = "Villager (Worker)"
			BaseUnit.UnitType.INFANTRY: u_name = "Swordsman (Infantry)"
			BaseUnit.UnitType.ARCHER: u_name = "Archer (Ranged)"
			BaseUnit.UnitType.CAVALRY: u_name = "Cavalry (Scout)"

		if selected_entities.size() == 1:
			action_title.text = "%s [HP: %d/%d]" % [u_name, u.current_hp, u.max_hp]
		else:
			action_title.text = "%s + %d units" % [u_name, selected_entities.size() - 1]

		if action_queue:
			action_queue.text = "ATK: %d | ARM: %d/%d | SPD: %.1f" % [
				u.melee_attack + u.pierce_attack,
				u.melee_armor,
				u.pierce_armor,
				u.move_speed
			]
		train_btn.visible = false
		if train_archer_btn:
			train_archer_btn.visible = false
	else:
		action_panel.visible = false

func _on_train_btn_pressed() -> void:
	if not current_selected_building or not is_instance_valid(current_selected_building):
		return

	var game_mgr := get_node_or_null("/root/GameManager")
	if not game_mgr:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Kiểm tra giới hạn dân số
	if game_mgr.player_population.has(my_id):
		var pop_data: Dictionary = game_mgr.player_population[my_id]
		var total_in_queue := current_selected_building.production_queue.size()
		if pop_data["current"] + total_in_queue >= pop_data["max"]:
			print("Population limit reached! Build more Houses.")
			return

	if current_selected_building.building_type == BaseBuilding.BuildingType.TOWN_CENTER:
		# Villager: 50 Food, 10s
		if game_mgr.get_resource(my_id, ResourceSource.ResourceType.FOOD) >= 50:
			game_mgr.spend_resource(my_id, ResourceSource.ResourceType.FOOD, 50)
			current_selected_building.queue_unit("res://scenes/entities/villager.tscn", 8.0)
		else:
			print("Not enough food for Villager!")
	elif current_selected_building.building_type == BaseBuilding.BuildingType.BARRACKS:
		# Swordsman: 60 Food, 20 Gold, 12s
		if game_mgr.get_resource(my_id, ResourceSource.ResourceType.FOOD) >= 60 and game_mgr.get_resource(my_id, ResourceSource.ResourceType.GOLD) >= 20:
			game_mgr.spend_resource(my_id, ResourceSource.ResourceType.FOOD, 60)
			game_mgr.spend_resource(my_id, ResourceSource.ResourceType.GOLD, 20)
			current_selected_building.queue_unit("res://scenes/entities/swordsman.tscn", 10.0)
		else:
			print("Not enough resources for Swordsman!")

func _on_train_archer_btn_pressed() -> void:
	if not current_selected_building or not is_instance_valid(current_selected_building):
		return

	var game_mgr := get_node_or_null("/root/GameManager")
	if not game_mgr:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	if game_mgr.player_population.has(my_id):
		var pop_data: Dictionary = game_mgr.player_population[my_id]
		var total_in_queue := current_selected_building.production_queue.size()
		if pop_data["current"] + total_in_queue >= pop_data["max"]:
			print("Population limit reached! Build more Houses.")
			return

	if current_selected_building.building_type == BaseBuilding.BuildingType.BARRACKS:
		# Archer: 40 Wood, 30 Gold, 10s
		if game_mgr.get_resource(my_id, ResourceSource.ResourceType.WOOD) >= 40 and game_mgr.get_resource(my_id, ResourceSource.ResourceType.GOLD) >= 30:
			game_mgr.spend_resource(my_id, ResourceSource.ResourceType.WOOD, 40)
			game_mgr.spend_resource(my_id, ResourceSource.ResourceType.GOLD, 30)
			current_selected_building.queue_unit("res://scenes/entities/archer.tscn", 10.0)
		else:
			print("Not enough resources for Archer!")

func _update_display() -> void:
	var game_mgr := get_node_or_null("/root/GameManager")
	if not game_mgr:
		return
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if food_label:
		food_label.text = "Food: %d" % game_mgr.get_resource(my_id, ResourceSource.ResourceType.FOOD)
	if wood_label:
		wood_label.text = "Wood: %d" % game_mgr.get_resource(my_id, ResourceSource.ResourceType.WOOD)
	if gold_label:
		gold_label.text = "Gold: %d" % game_mgr.get_resource(my_id, ResourceSource.ResourceType.GOLD)
	if stone_label:
		stone_label.text = "Stone: %d" % game_mgr.get_resource(my_id, ResourceSource.ResourceType.STONE)
	if pop_label and game_mgr.player_population.has(my_id):
		var pop_data: Dictionary = game_mgr.player_population[my_id]
		pop_label.text = "Pop: %d/%d" % [pop_data["current"], pop_data["max"]]

func _on_resource_updated(peer_id: int, _res_type: int, _amount: int) -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id == my_id or peer_id == 1 or not multiplayer.has_multiplayer_peer():
		_update_display()
		_flash_resource_label(_res_type)

func _flash_resource_label(res_type: int) -> void:
	var target_lbl: Label = null
	match res_type:
		ResourceSource.ResourceType.FOOD: target_lbl = food_label
		ResourceSource.ResourceType.WOOD: target_lbl = wood_label
		ResourceSource.ResourceType.GOLD: target_lbl = gold_label
		ResourceSource.ResourceType.STONE: target_lbl = stone_label
	if target_lbl:
		var tween := create_tween()
		target_lbl.modulate = Color(1.0, 1.0, 0.2, 1.0)
		tween.tween_property(target_lbl, "modulate", Color.WHITE, 0.4)

func _on_population_updated(peer_id: int, _curr: int, _max_p: int) -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id == my_id or not multiplayer.has_multiplayer_peer():
		_update_display()

func _clear_tech_buttons() -> void:
	for btn in _dynamic_tech_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_dynamic_tech_buttons.clear()

func _populate_tech_buttons(building_filter: String) -> void:
	if not buttons_hbox:
		return
	var tm = get_node_or_null("/root/TechManager")
	if not tm:
		return
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var game_mgr = get_node_or_null("/root/GameManager")

	for tech_id in tm.TECH_DATABASE:
		var t_data: Dictionary = tm.TECH_DATABASE[tech_id]
		if t_data.get("building", "") != building_filter:
			continue

		var btn := Button.new()
		var t_name: String = t_data.get("name", tech_id)
		var is_researched: bool = tm.is_tech_researched(my_id, tech_id)

		var cost_strs: Array[String] = []
		var can_afford := true
		var cost: Dictionary = t_data.get("cost", {})
		for r_type in cost:
			var req: int = cost[r_type]
			var r_name := "F"
			match r_type:
				ResourceSource.ResourceType.FOOD: r_name = "F"
				ResourceSource.ResourceType.WOOD: r_name = "W"
				ResourceSource.ResourceType.GOLD: r_name = "G"
				ResourceSource.ResourceType.STONE: r_name = "S"
			cost_strs.append("%d%s" % [req, r_name])
			if game_mgr and game_mgr.get_resource(my_id, r_type) < req:
				can_afford = false
		var cost_label := ", ".join(cost_strs)

		var is_queued := false
		if current_selected_building:
			for item in current_selected_building.production_queue:
				if item.get("type", "") == "tech" and item.get("tech_id", "") == tech_id:
					is_queued = true
					break

		if is_researched:
			btn.text = "[Done] %s" % t_name
			btn.disabled = true
		elif is_queued:
			btn.text = "[Queued] %s" % t_name
			btn.disabled = true
		else:
			btn.text = "%s (%s)" % [t_name, cost_label]
			btn.disabled = not can_afford
			btn.pressed.connect(func():
				_on_research_tech_pressed(tech_id)
			)

		buttons_hbox.add_child(btn)
		_dynamic_tech_buttons.append(btn)

func _on_research_tech_pressed(tech_id: String) -> void:
	if not current_selected_building or not is_instance_valid(current_selected_building):
		return
	var tm = get_node_or_null("/root/TechManager")
	var game_mgr = get_node_or_null("/root/GameManager")
	if not tm or not game_mgr:
		return
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var t_data: Dictionary = tm.TECH_DATABASE.get(tech_id, {})
	var cost: Dictionary = t_data.get("cost", {})

	for r_type in cost:
		if game_mgr.get_resource(my_id, r_type) < cost[r_type]:
			print("Cannot afford tech: ", tech_id)
			return
	for r_type in cost:
		game_mgr.spend_resource(my_id, r_type, cost[r_type])

	current_selected_building.request_research(tech_id)
	var b_filter := "storage_pit" if current_selected_building.building_type == BaseBuilding.BuildingType.STORAGE_PIT else "granary"
	_clear_tech_buttons()
	_populate_tech_buttons(b_filter)

func _on_tech_completed(_peer_id: int, _tech_id: String) -> void:
	if current_selected_building and is_instance_valid(current_selected_building):
		var b_filter := ""
		if current_selected_building.building_type == BaseBuilding.BuildingType.STORAGE_PIT:
			b_filter = "storage_pit"
		elif current_selected_building.building_type == BaseBuilding.BuildingType.GRANARY:
			b_filter = "granary"
		if b_filter != "":
			_clear_tech_buttons()
			_populate_tech_buttons(b_filter)
