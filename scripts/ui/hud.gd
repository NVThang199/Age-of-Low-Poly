class_name RTSHUD
extends Control

@onready var food_label: Label = $TopBar/HBox/FoodLabel
@onready var wood_label: Label = $TopBar/HBox/WoodLabel
@onready var gold_label: Label = $TopBar/HBox/GoldLabel
@onready var stone_label: Label = $TopBar/HBox/StoneLabel
@onready var pop_label: Label = $TopBar/HBox/PopLabel

@onready var build_house_btn: Button = $BuildMenu/HBox/BuildHouseBtn
@onready var build_barracks_btn: Button = $BuildMenu/HBox/BuildBarracksBtn
@onready var build_mine_btn: Button = $BuildMenu/HBox/BuildMineBtn
@onready var cancel_build_btn: Button = $BuildMenu/HBox/CancelBuildBtn

signal build_requested(building_type: String)

@onready var action_panel: PanelContainer = get_node_or_null("ActionPanel")
@onready var action_title: Label = get_node_or_null("ActionPanel/VBox/TitleLabel")
@onready var action_queue: Label = get_node_or_null("ActionPanel/VBox/QueueLabel")
@onready var train_btn: Button = get_node_or_null("ActionPanel/VBox/ButtonsHBox/TrainBtn")
@onready var train_archer_btn: Button = get_node_or_null("ActionPanel/VBox/ButtonsHBox/TrainArcherBtn")

var current_selected_building: BaseBuilding = null

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
	if build_barracks_btn:
		build_barracks_btn.pressed.connect(func():
			build_requested.emit("barracks")
		)
	if build_mine_btn:
		build_mine_btn.pressed.connect(func():
			build_requested.emit("mine")
		)
	if cancel_build_btn:
		cancel_build_btn.pressed.connect(func():
			build_requested.emit("cancel")
		)

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

var current_selected_unit: BaseUnit = null

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
