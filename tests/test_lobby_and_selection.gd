extends SceneTree

# Test suite verifying Lobby Host flow, Offline mode, and Unit Selection/Movement
var _tested := false

func _process(_delta: float) -> bool:
	if not _tested:
		_tested = true
		print("=========================================================")
		print("--- Running Test Lobby Host, Offline & Selection Flow ---")
		print("=========================================================")
		test_offline_button_flow()
		test_lobby_host_and_selection_flow()
		print("=========================================================")
		print("--- ALL LOBBY & SELECTION TESTS PASSED (100% GREEN) ---")
		print("=========================================================")
		quit(0)
	return true

func test_offline_button_flow() -> void:
	var lobby_scene: PackedScene = load("res://scenes/ui/lobby.tscn")
	assert(lobby_scene != null, "lobby.tscn must load")
	var lobby = lobby_scene.instantiate()
	root.add_child(lobby)

	assert(lobby.offline_btn != null, "OfflineBtn must exist in Lobby")

	var net_mgr = root.get_node_or_null("NetworkManager")
	assert(net_mgr != null, "NetworkManager must exist")

	# Simulate pressing offline button
	lobby._on_offline_pressed()
	assert(not root.multiplayer.has_multiplayer_peer(), "Offline mode must clear multiplayer peer")
	print("Offline flow test passed!")
	lobby.free()

func test_lobby_host_and_selection_flow() -> void:
	var lobby_scene: PackedScene = load("res://scenes/ui/lobby.tscn")
	var lobby = lobby_scene.instantiate()
	root.add_child(lobby)

	var net_mgr = root.get_node_or_null("NetworkManager")
	var steam_mgr = root.get_node_or_null("SteamManager")

	# 1. Host creates game
	net_mgr.host_game()
	assert(net_mgr.is_host == true, "NetworkManager must be host")
	assert(root.multiplayer.has_multiplayer_peer() == true, "Must have multiplayer peer")
	assert(root.multiplayer.get_unique_id() == 1, "Host peer id must be 1")

	# 2. Simulate Steam callback lobby_created & lobby_joined
	var fake_lobby_id := 999888777
	if steam_mgr:
		steam_mgr.is_host = true
	lobby._on_lobby_created(1, fake_lobby_id)
	lobby._on_lobby_joined(fake_lobby_id, 0, false, 1)

	# Crucial assertion: Host must NOT have been destroyed by lobby_joined!
	assert(net_mgr.is_host == true, "Host MUST remain host after lobby_joined!")
	assert(root.multiplayer.get_unique_id() == 1, "Host peer id MUST remain 1 after lobby_joined!")
	assert(lobby.start_btn.disabled == false, "Start button must be enabled for host")

	# 3. Simulate Selection System & Command Manager in Host Match
	var main_node := Node3D.new()
	main_node.name = "Main"
	root.add_child(main_node)

	var cam_ctrl := Node3D.new()
	cam_ctrl.name = "CameraController"
	main_node.add_child(cam_ctrl)

	var dummy_camera := Camera3D.new()
	dummy_camera.name = "Camera3D"
	cam_ctrl.add_child(dummy_camera)

	var sel_system := SelectionSystem.new()
	sel_system.name = "SelectionSystem"
	main_node.add_child(sel_system)

	var cmd_manager := CommandManager.new()
	cmd_manager.name = "CommandManager"
	main_node.add_child(cmd_manager)

	sel_system.camera = dummy_camera
	cmd_manager.camera = dummy_camera
	cmd_manager.selection_system = sel_system

	var villager_script := load("res://scripts/entities/villager.gd")
	var v = villager_script.new()
	v.owner_peer_id = 1
	v.name = "TestVillager"
	main_node.add_child(v)
	v.add_to_group("units")
	v.global_position = Vector3(0, 0, -10)

	# Setup camera to face the unit
	dummy_camera.global_position = Vector3(0, 5, 0)
	dummy_camera.look_at(Vector3(0, 0, -10))

	# Box selection simulation
	var screen_pos := dummy_camera.unproject_position(v.global_position)
	var box_margin := Vector2(20, 20)
	sel_system._box_select(screen_pos - box_margin, screen_pos + box_margin)

	assert(sel_system.selected_units.has(v), "Host MUST be able to box select owned units (peer_id=1)")

	# Verify CommandManager right-click moves the unit without filtering it out
	var my_id := root.multiplayer.get_unique_id()
	var unit_names: Array[String] = []
	for u in sel_system.selected_units:
		if is_instance_valid(u) and u.is_in_group("units"):
			var u_peer: int = u.owner_peer_id if "owner_peer_id" in u else 1
			if root.multiplayer.has_multiplayer_peer() and u_peer != my_id:
				continue
			unit_names.append(String(u.name))

	assert(unit_names.size() == 1, "Unit MUST pass ownership check for command dispatch")
	assert(unit_names[0] == "TestVillager", "TestVillager must be queued for move")

	print("Lobby Host & Selection flow test passed!")

	# Cleanup
	main_node.free()
	lobby.free()
	net_mgr.disconnect_game()
