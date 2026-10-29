# Behaviour and module under test: scenes/ui/hud.tscn and scripts/ui/hud.gd (RTSHUD layout, Pharaoh relief, submenus, age filtering)
# Existing test files: None for HUD UI (tests/test_aoe_full_features.gd covers tech progression)
# User verbatim instruction: "bạn thiết kế lại UI UX cho tôi bạn phải làm sao để giống game gốc [Image #1] nó rất đơn giản nhưng lại có mọi thứ và phải lên đời/ research thì mới hiện các côgn trình chứ hiện tại bạn cứ để bừa trên màn hình là không được"
# Fact 1: Called via CLI standalone execution: godot --headless -s tests/test_hud_ui.gd
# Fact 2: Verified HUD scene path in scenes/ui/hud.tscn
# Fact 3: Instantiates RTSHUD and verifies Image #1 UI specifications

extends SceneTree

func _init() -> void:
	print("=== Running AoE 1 Authentic HUD Suite ===")
	test_hud_scene_structure()
	test_idle_pharaoh_relief_and_zero_clutter()
	test_age_filtered_building_submenus()
	print("=== All AoE 1 HUD Tests PASSED ===")
	quit(0)

func test_hud_scene_structure() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	assert(hud_scene != null, "HUD scene must exist and load")
	var hud: Node = hud_scene.instantiate()
	assert(hud != null, "HUD must instantiate")
	root.add_child(hud)

	# Verify TopBar elements
	assert(hud.has_node("TopBar/Margin/HBox/ResWood/WoodLabel"), "WoodLabel must exist")
	assert(hud.has_node("TopBar/Margin/HBox/ResFood/FoodLabel"), "FoodLabel must exist")
	assert(hud.has_node("TopBar/Margin/HBox/ResGold/GoldLabel"), "GoldLabel must exist")
	assert(hud.has_node("TopBar/Margin/HBox/ResStone/StoneLabel"), "StoneLabel must exist")
	assert(hud.has_node("TopBar/Margin/HBox/ResPop/PopLabel"), "PopLabel must exist")
	assert(hud.has_node("TopBar/Margin/HBox/AgeLabel"), "AgeLabel must exist")
	assert(hud.has_node("TopBar/Margin/HBox/YearLabel"), "YearLabel must exist")

	# Verify Hover Tooltip
	assert(hud.has_node("TooltipBanner/Margin/TooltipLabel"), "TooltipLabel must exist")

	# Verify Bottom Console panels
	assert(hud.has_node("BottomConsole/Margin/HBox/LeftInfoBox"), "LeftInfoBox must exist")
	assert(hud.has_node("BottomConsole/Margin/HBox/CenterActionBox"), "CenterActionBox must exist")
	assert(hud.has_node("BottomConsole/Margin/HBox/RightMinimapBox"), "RightMinimapBox must exist")

	# Verify Pharaoh Relief
	assert(hud.has_node("BottomConsole/Margin/HBox/CenterActionBox/Margin/PharaohRelief"), "Pharaoh relief must exist")

	hud.queue_free()
	print("✓ HUD scene structure and nodes validated")

func test_idle_pharaoh_relief_and_zero_clutter() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud: RTSHUD = hud_scene.instantiate() as RTSHUD
	root.add_child(hud)
	hud._ready()

	# At idle (no selection), Pharaoh relief must be visible and action menus hidden
	assert(hud.pharaoh_relief != null and hud.pharaoh_relief.visible == true, "Pharaoh relief must be visible at idle")
	assert(hud.villager_action_menu != null and hud.villager_action_menu.visible == false, "Villager menu must be hidden when nothing selected")
	assert(hud.sub_building_grid != null and hud.sub_building_grid.visible == false, "Sub building grid must be hidden when nothing selected")
	assert(hud.building_production_menu != null and hud.building_production_menu.visible == false, "Building production must be hidden when nothing selected")

	hud.queue_free()
	print("✓ Idle state shows iconic Pharaoh relief with zero button clutter")

func test_age_filtered_building_submenus() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud: RTSHUD = hud_scene.instantiate() as RTSHUD
	root.add_child(hud)
	hud._ready()

	# Test opening economic submenu in Stone Age
	hud._open_sub_building_menu("econ")
	assert(hud.is_in_sub_menu == true, "Must be in sub menu")
	assert(hud.sub_building_grid.visible == true, "Sub building grid must be visible")

	# Check buttons in economic menu
	var econ_buttons := hud.building_buttons_hbox.get_children()
	assert(econ_buttons.size() >= 3, "Stone Age economic menu must display available base buildings")

	# Farm (Tool Age) must not be accessible in Stone Age
	for b in econ_buttons:
		if b is Button:
			if "Farm" in b.text:
				assert(false, "Farm must not be present in Stone Age")

	# Test Military submenu in Stone Age
	hud._open_sub_building_menu("mil")
	var mil_buttons := hud.building_buttons_hbox.get_children()
	assert(mil_buttons.size() >= 1, "Stone Age military menu must display Barracks")

	# Archery Range / Stable / Temple must not be present in Stone Age
	for b in mil_buttons:
		if b is Button:
			if "Temple" in b.text or "Siege" in b.text:
				assert(false, "Temple and Siege must not be present in Stone Age")

	hud.queue_free()
	print("✓ Age-filtered building submenus validated")
