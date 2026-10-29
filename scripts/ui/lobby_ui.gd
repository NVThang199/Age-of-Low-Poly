# Fact 1: Attached to scenes/ui/lobby.tscn root node (LobbyUI)
# Fact 2: Verified existing lobby_ui.gd via Glob in scripts/ui/
# Fact 3: Control schema managing AoE 1 authentic main menu buttons, singleplayer random map settings, and multiplayer lobby
# Fact 4: User verbatim instruction: "tôi chưa hề thấy chọn maptype hay có cho phép đen bản đồ hay là sáng toàn bản đồ hoặc chọn loại map medium, large, gigantic bạn xem để chọn các loại map bạn bảo thì chọn ở đâu tôi muốn ở bên ngoài lobby là phải có rồi đồng thời design lại lobby để giống game đế chế gốc [Image #4]"

class_name LobbyUI
extends Control

## LobbyUI (AoE 1 Authentic Main Menu & Match Setup)
## Thiết kế theo đúng phong cách nguyên bản của Age of Empires 1 (Rise of Rome):
## - Menu chính với các nút kinh điển: Single Player, Multiplayer, Help, Scenario Builder, Exit.
## - Bảng thiết lập Random Map Game: Chọn 9 loại Map (Highland, Continental, Mediterranean...),
##   5 kích cỡ bản đồ (Tiny, Small, Medium, Large, Gigantic), chế độ sương mù (Đen bản đồ / Sáng toàn bộ),
##   Thời kỳ khởi đầu (Stone, Tool, Bronze, Iron) và Gói tài nguyên khởi đầu.

# Main Buttons
@onready var single_player_btn: Button = $MainMenu/VBox/SinglePlayerBtn
@onready var multiplayer_btn: Button = $MainMenu/VBox/MultiplayerBtn
@onready var help_btn: Button = $MainMenu/VBox/HelpBtn
@onready var scenario_btn: Button = $MainMenu/VBox/ScenarioBtn
@onready var exit_btn: Button = $MainMenu/VBox/ExitBtn

# Dialogs
@onready var main_menu_container: Control = $MainMenu
@onready var setup_dialog: PanelContainer = $SetupDialog
@onready var multiplayer_dialog: PanelContainer = $MultiplayerDialog
@onready var help_dialog: PanelContainer = $HelpDialog

# Setup Controls
@onready var opt_map_type: OptionButton = $SetupDialog/VBox/Grid/OptMapType
@onready var opt_map_size: OptionButton = $SetupDialog/VBox/Grid/OptMapSize
@onready var opt_map_vis: OptionButton = $SetupDialog/VBox/Grid/OptMapVis
@onready var opt_start_age: OptionButton = $SetupDialog/VBox/Grid/OptStartAge
@onready var opt_resources: OptionButton = $SetupDialog/VBox/Grid/OptResources
@onready var opt_players: OptionButton = $SetupDialog/VBox/Grid/OptPlayers
@onready var start_match_btn: Button = $SetupDialog/VBox/Actions/StartMatchBtn
@onready var cancel_setup_btn: Button = $SetupDialog/VBox/Actions/CancelSetupBtn

# Multiplayer Controls
@onready var mp_host_btn: Button = $MultiplayerDialog/VBox/Actions/HostBtn
@onready var mp_join_btn: Button = $MultiplayerDialog/VBox/Actions/JoinBtn
@onready var mp_invite_btn: Button = $MultiplayerDialog/VBox/Actions/InviteBtn
@onready var mp_code_input: LineEdit = $MultiplayerDialog/VBox/CodeHBox/CodeInput
@onready var mp_status_lbl: Label = $MultiplayerDialog/VBox/StatusLabel
@onready var mp_start_btn: Button = $MultiplayerDialog/VBox/StartGameBtn
@onready var mp_back_btn: Button = $MultiplayerDialog/VBox/BackBtn

var _signals_connected: bool = false

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

func _ready() -> void:
	_setup_dialog_options()
	_connect_signals()

	setup_dialog.visible = false
	multiplayer_dialog.visible = false
	help_dialog.visible = false
	main_menu_container.visible = true

	var steam_mgr := _get_autoload_node("SteamManager")
	if steam_mgr and not steam_mgr.lobby_created.is_connected(_on_lobby_created):
		steam_mgr.lobby_created.connect(_on_lobby_created)
		steam_mgr.lobby_joined.connect(_on_lobby_joined)

func _setup_dialog_options() -> void:
	# 1. 9 Chủng loại bản đồ AoE 1
	opt_map_type.clear()
	opt_map_type.add_item("Highland (Cao nguyên - Sông & Bến cạn)", 4)
	opt_map_type.add_item("Continental (Đại lục - Biển bao quanh)", 5)
	opt_map_type.add_item("Inland (Nội địa - Hồ nước nhỏ)", 3)
	opt_map_type.add_item("Coastal (Bờ biển)", 2)
	opt_map_type.add_item("Small Islands (Quần đảo nhỏ)", 0)
	opt_map_type.add_item("Large Islands (Đảo lớn)", 1)
	opt_map_type.add_item("Mediterranean (Địa Trung Hải - Biển giữa)", 6)
	opt_map_type.add_item("Hill Country (Đồi núi gập ghềnh)", 7)
	opt_map_type.add_item("Narrows (Eo biển & Cầu đất)", 8)
	opt_map_type.select(0) # Mặc định Highland

	# 2. 5 Kích thước bản đồ
	opt_map_size.clear()
	opt_map_size.add_item("Tiny (2 Players - 100x100)", 0)
	opt_map_size.add_item("Small (3 Players - 140x140)", 1)
	opt_map_size.add_item("Medium (4 Players - 180x180)", 2)
	opt_map_size.add_item("Large (6 Players - 220x220)", 3)
	opt_map_size.add_item("Gigantic / Huge (8 Players - 280x280)", 4)
	opt_map_size.select(2) # Mặc định Medium

	# 3. Chế độ hiển thị sương mù (Đen toàn bộ hoặc Sáng toàn bản đồ)
	opt_map_vis.clear()
	opt_map_vis.add_item("Normal Fog of War (Đen bản đồ - Chuẩn AoE 1)", 0)
	opt_map_vis.add_item("Explored (Đã mở toàn bộ địa hình & mỏ)", 1)
	opt_map_vis.add_item("All Visible (Sáng toàn bản đồ - Marco Polo)", 2)
	opt_map_vis.select(0) # Mặc định Normal Fog

	# 4. Thời kỳ xuất phát
	opt_start_age.clear()
	opt_start_age.add_item("Stone Age (Thời kỳ Đồ đá)", 0)
	opt_start_age.add_item("Tool Age (Thời kỳ Công cụ)", 1)
	opt_start_age.add_item("Bronze Age (Thời kỳ Đồ đồng)", 2)
	opt_start_age.add_item("Iron Age (Thời kỳ Đồ sắt)", 3)
	opt_start_age.select(0)

	# 5. Gói tài nguyên xuất phát
	opt_resources.clear()
	opt_resources.add_item("Default (200W, 200F, 100G, 0S)", 0)
	opt_resources.add_item("Medium (500W, 500F, 300G, 150S)", 1)
	opt_resources.add_item("High (1000W, 1000F, 1000G, 1000S)", 2)
	opt_resources.add_item("Deathmatch (20000W, 20000F, 10000G, 5000S)", 3)
	opt_resources.select(0)

	# 6. Số lượng người chơi
	opt_players.clear()
	opt_players.add_item("2 Players", 2)
	opt_players.add_item("4 Players", 4)
	opt_players.add_item("8 Players", 8)
	opt_players.select(0)

func _connect_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true

	single_player_btn.pressed.connect(_on_single_player_pressed)
	multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	scenario_btn.pressed.connect(_on_scenario_pressed)
	exit_btn.pressed.connect(func(): if get_tree(): get_tree().quit())

	start_match_btn.pressed.connect(_on_start_match_pressed)
	cancel_setup_btn.pressed.connect(_close_all_dialogs)

	mp_host_btn.pressed.connect(_on_mp_host_pressed)
	mp_join_btn.pressed.connect(_on_mp_join_pressed)
	mp_invite_btn.pressed.connect(_on_mp_invite_pressed)
	mp_start_btn.pressed.connect(_on_mp_start_game_pressed)
	mp_back_btn.pressed.connect(_close_all_dialogs)

	if has_node("HelpDialog/VBox/CloseHelpBtn"):
		$HelpDialog/VBox/CloseHelpBtn.pressed.connect(_close_all_dialogs)

func _close_all_dialogs() -> void:
	setup_dialog.visible = false
	multiplayer_dialog.visible = false
	help_dialog.visible = false
	main_menu_container.visible = true

func _on_single_player_pressed() -> void:
	main_menu_container.visible = false
	setup_dialog.visible = true

func _on_multiplayer_pressed() -> void:
	main_menu_container.visible = false
	multiplayer_dialog.visible = true

func _on_help_pressed() -> void:
	main_menu_container.visible = false
	help_dialog.visible = true

func _on_scenario_pressed() -> void:
	# Quick launch map test with All Visible
	_save_settings_to_game_manager()
	var gm := _get_autoload_node("GameManager")
	if gm:
		gm.selected_map_visibility = 2 # ALL_VISIBLE
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _save_settings_to_game_manager() -> void:
	var gm := _get_autoload_node("GameManager")
	if not gm:
		return

	gm.selected_map_type = opt_map_type.get_selected_id()
	gm.selected_map_size = opt_map_size.get_selected_id()
	gm.selected_map_visibility = opt_map_vis.get_selected_id()
	gm.selected_starting_age = opt_start_age.get_selected_id()
	gm.selected_starting_resources_preset = opt_resources.get_selected_id()
	gm.selected_player_count = opt_players.get_selected_id()
	gm.reset_match_resources()

	# Cập nhật thời kỳ ban đầu cho TechManager nếu chọn xuất phát đời cao
	var tm := _get_autoload_node("TechManager")
	if tm and gm.selected_starting_age > 0:
		tm.advance_age_instant(1, gm.selected_starting_age)

func _on_start_match_pressed() -> void:
	_save_settings_to_game_manager()

	# Ngắt kết nối mạng cũ nếu có để vào trận Offline/Singleplayer sạch
	var net_mgr := _get_autoload_node("NetworkManager")
	if net_mgr:
		net_mgr.disconnect_game()

	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

# Multiplayer Handlers
func _on_mp_host_pressed() -> void:
	_save_settings_to_game_manager()
	var steam_mgr := _get_autoload_node("SteamManager")
	var net_mgr := _get_autoload_node("NetworkManager")
	mp_status_lbl.text = "Dang tao phong..."

	if steam_mgr and steam_mgr.is_steam_active:
		steam_mgr.create_lobby()
	elif net_mgr:
		net_mgr.host_game()
		mp_status_lbl.text = "Da Host qua Local ENet (Port 7777)"
		mp_start_btn.disabled = false

func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result == 1:
		var steam_mgr := _get_autoload_node("SteamManager")
		var net_mgr := _get_autoload_node("NetworkManager")
		if net_mgr:
			net_mgr.host_game(lobby_id)
		var code: String = steam_mgr.get_invite_code(lobby_id) if steam_mgr else str(lobby_id)
		mp_status_lbl.text = "Lobby ID: %d | Invite Code: %s" % [lobby_id, code]
		mp_invite_btn.disabled = false
		mp_start_btn.disabled = false
	else:
		mp_status_lbl.text = "Tao lobby that bai!"

func _on_mp_invite_pressed() -> void:
	var steam_mgr := _get_autoload_node("SteamManager")
	if steam_mgr:
		steam_mgr.open_invite_dialog()

func _on_mp_join_pressed() -> void:
	var raw_code := mp_code_input.text.strip_edges()
	if raw_code.is_empty():
		return

	var steam_mgr := _get_autoload_node("SteamManager")
	if steam_mgr and steam_mgr.is_steam_active:
		var lobby_id: int = steam_mgr.parse_invite_code(raw_code)
		mp_status_lbl.text = "Dang vao phong: %d..." % lobby_id
		steam_mgr.join_lobby(lobby_id)
	else:
		var net_mgr := _get_autoload_node("NetworkManager")
		if net_mgr:
			net_mgr.join_game(0, raw_code)
			mp_status_lbl.text = "Da ket noi toi %s" % raw_code
			mp_start_btn.disabled = true

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == 1:
		mp_status_lbl.text = "Vao phong thanh cong! Lobby: %d" % lobby_id
		var steam_mgr := _get_autoload_node("SteamManager")
		var net_mgr := _get_autoload_node("NetworkManager")

		if (steam_mgr and steam_mgr.is_host) or (net_mgr and net_mgr.is_host):
			mp_start_btn.disabled = false
			return

		if net_mgr:
			var host_id: int = Steam.getLobbyOwner(lobby_id) if ClassDB.class_exists("Steam") else 0
			net_mgr.join_game(host_id)
		mp_start_btn.disabled = true
	else:
		mp_status_lbl.text = "Vao phong that bai!"

func _on_mp_start_game_pressed() -> void:
	_save_settings_to_game_manager()
	var net_mgr := _get_autoload_node("NetworkManager")
	if net_mgr and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for pid in net_mgr.connected_peers:
			if pid != 1:
				start_game_on_client.rpc_id(pid)
		await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

@rpc("authority", "call_remote", "reliable")
func start_game_on_client() -> void:
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")
