class_name LobbyUI
extends Control

@onready var host_btn: Button = $VBox/HostBtn
@onready var invite_btn: Button = $VBox/InviteBtn
@onready var code_input: LineEdit = $VBox/HBox/CodeInput
@onready var join_btn: Button = $VBox/HBox/JoinBtn
@onready var start_btn: Button = $VBox/StartBtn
@onready var status_lbl: Label = $VBox/StatusLbl

func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	invite_btn.pressed.connect(_on_invite_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)

	invite_btn.disabled = true
	start_btn.disabled = true

	var steam_mgr := get_node_or_null("/root/SteamManager")
	if steam_mgr:
		steam_mgr.lobby_created.connect(_on_lobby_created)
		steam_mgr.lobby_joined.connect(_on_lobby_joined)

func _on_host_pressed() -> void:
	var steam_mgr := get_node_or_null("/root/SteamManager")
	var net_mgr := get_node_or_null("/root/NetworkManager")
	status_lbl.text = "Dang tao phong..."

	if steam_mgr and steam_mgr.is_steam_active:
		steam_mgr.create_lobby()
	elif net_mgr:
		net_mgr.host_game()
		status_lbl.text = "Da Host qua Local ENet (Port 7777)"
		start_btn.disabled = false

func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result == 1:
		var steam_mgr := get_node_or_null("/root/SteamManager")
		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.host_game(lobby_id)
		var code: String = steam_mgr.get_invite_code(lobby_id) if steam_mgr else str(lobby_id)
		status_lbl.text = "Lobby ID: %d | Invite Code: %s" % [lobby_id, code]
		invite_btn.disabled = false
		start_btn.disabled = false
	else:
		status_lbl.text = "Tao lobby that bai!"

func _on_invite_pressed() -> void:
	var steam_mgr := get_node_or_null("/root/SteamManager")
	if steam_mgr:
		steam_mgr.open_invite_dialog()

func _on_join_pressed() -> void:
	var raw_code := code_input.text.strip_edges()
	if raw_code.is_empty():
		return

	var steam_mgr := get_node_or_null("/root/SteamManager")
	if steam_mgr and steam_mgr.is_steam_active:
		var lobby_id: int = steam_mgr.parse_invite_code(raw_code)
		status_lbl.text = "Dang vao phong: %d..." % lobby_id
		steam_mgr.join_lobby(lobby_id)
	else:
		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr:
			net_mgr.join_game(0, raw_code)
			status_lbl.text = "Da ket noi toi %s" % raw_code
			start_btn.disabled = false

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == 1:
		status_lbl.text = "Vao phong thanh cong! Lobby: %d" % lobby_id
		var net_mgr := get_node_or_null("/root/NetworkManager")
		if net_mgr:
			var host_id: int = Steam.getLobbyOwner(lobby_id) if ClassDB.class_exists("Steam") else 0
			net_mgr.join_game(host_id)
		start_btn.disabled = false
	else:
		status_lbl.text = "Vao phong that bai!"

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")
