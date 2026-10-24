extends Node

## Autoload: SteamManager
## Quản lý tích hợp Steam API, Lobby P2P, mã Invite Code và Steam Overlay.

signal lobby_created(connect_result: int, lobby_id: int)
signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
signal player_joined(steam_id: int, player_name: String)
signal player_left(steam_id: int)
signal steam_initialized(success: bool)

enum LobbyType {
	PRIVATE = 0,
	FRIENDS_ONLY = 1,
	PUBLIC = 2,
	INVISIBLE = 3,
}

const CHAT_MEMBER_STATE_ENTERED: int = 1
const CHAT_MEMBER_STATE_LEFT: int = 2
const CHAT_MEMBER_STATE_DISCONNECTED: int = 4
const CHAT_MEMBER_STATE_KICKED: int = 8
const CHAT_MEMBER_STATE_BANNED: int = 16

var is_steam_active: bool = false
var steam_id: int = 0
var steam_username: String = ""
var current_lobby_id: int = 0
var is_host: bool = false
var lobby_members: Array[Dictionary] = []


func _ready() -> void:
	_initialize_steam()


func _process(_delta: float) -> void:
	if is_steam_active and ClassDB.class_exists("Steam"):
		Steam.run_callbacks()


func _initialize_steam() -> void:
	if not ClassDB.class_exists("Steam"):
		push_warning("SteamManager: Steam class khong ton tai. Steam API bi tat.")
		steam_initialized.emit(false)
		return

	if Steam.loggedOn() or Steam.getSteamID() > 0:
		is_steam_active = true
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
		_connect_steam_signals()
		print_rich("[color=green]SteamManager: Steam da san sang. User: %s (ID: %d)[/color]" % [steam_username, steam_id])
		steam_initialized.emit(true)
		return

	var init_response: Variant = Steam.steamInit(false)
	var is_ok: bool = false
	if init_response is bool:
		is_ok = init_response
	elif init_response is Dictionary:
		is_ok = (int(init_response.get("status", 1)) == 0)

	# is_ok hoac Steam.isSteamRunning() xac nhan Steam API khoi tao thanh cong
	if is_ok or Steam.isSteamRunning():
		is_steam_active = true
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
		_connect_steam_signals()
		print_rich("[color=green]SteamManager: Khoi tao Steam thanh cong. User: %s (ID: %d)[/color]" % [steam_username, steam_id])
		steam_initialized.emit(true)
	else:
		is_steam_active = false
		push_warning("SteamManager: Khong the khoi tao Steam.")
		steam_initialized.emit(false)


func _connect_steam_signals() -> void:
	if not is_steam_active:
		return

	if not Steam.lobby_created.is_connected(_on_steam_lobby_created):
		Steam.lobby_created.connect(_on_steam_lobby_created)
	if not Steam.lobby_joined.is_connected(_on_steam_lobby_joined):
		Steam.lobby_joined.connect(_on_steam_lobby_joined)
	if not Steam.lobby_chat_update.is_connected(_on_steam_lobby_chat_update):
		Steam.lobby_chat_update.connect(_on_steam_lobby_chat_update)
	if not Steam.join_requested.is_connected(_on_steam_join_requested):
		Steam.join_requested.connect(_on_steam_join_requested)


func create_lobby(type: int = LobbyType.PUBLIC, max_players: int = 8) -> void:
	if not is_steam_active:
		push_error("SteamManager: Khong the tao lobby vi Steam chua kich hoat.")
		lobby_created.emit(0, 0)
		return

	Steam.createLobby(type, max_players)


func join_lobby(lobby_id: int) -> void:
	if not is_steam_active:
		push_error("SteamManager: Khong the join lobby vi Steam chua kich hoat.")
		lobby_joined.emit(lobby_id, 0, false, 0)
		return

	Steam.joinLobby(lobby_id)


func leave_lobby() -> void:
	if not is_steam_active or current_lobby_id == 0:
		return

	Steam.leaveLobby(current_lobby_id)
	current_lobby_id = 0
	is_host = false
	lobby_members.clear()


func get_invite_code(target_lobby_id: int = 0) -> String:
	var id_to_use: int = target_lobby_id if target_lobby_id != 0 else current_lobby_id
	if id_to_use == 0:
		return ""
	return String.num_int64(id_to_use, 16).to_upper()


func parse_invite_code(code: String) -> int:
	var cleaned: String = code.strip_edges()
	if cleaned.is_empty():
		return 0

	# Neu chuoi la so thap phan thuan tuy (raw Steam 64-bit ID)
	if cleaned.is_valid_int():
		return cleaned.to_int()

	# Neu chuoi la ma Hex
	if cleaned.is_valid_hex_number(false):
		return cleaned.hex_to_int()

	return 0


func open_invite_dialog() -> void:
	if not is_steam_active:
		push_warning("SteamManager: Steam chua kich hoat, khong the mo Invite Dialog.")
		return

	if current_lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(current_lobby_id)
	else:
		Steam.activateGameOverlay("friends")


func refresh_lobby_members() -> void:
	lobby_members.clear()
	if not is_steam_active or current_lobby_id == 0:
		return

	var member_count: int = Steam.getNumLobbyMembers(current_lobby_id)
	for i: int in range(member_count):
		var member_id: int = Steam.getLobbyMemberByIndex(current_lobby_id, i)
		var member_name: String = Steam.getFriendPersonaName(member_id)
		lobby_members.append({
			"id": member_id,
			"name": member_name,
			"is_owner": member_id == Steam.getLobbyOwner(current_lobby_id)
		})


func _on_steam_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result == 1:
		current_lobby_id = lobby_id
		is_host = true
		Steam.setLobbyJoinable(lobby_id, true)
		Steam.setLobbyData(lobby_id, "name", "%s's RTS Match" % steam_username)
		Steam.setLobbyData(lobby_id, "code", get_invite_code(lobby_id))
		refresh_lobby_members()
	else:
		current_lobby_id = 0
		is_host = false

	lobby_created.emit(connect_result, lobby_id)


func _on_steam_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	if response == 1:
		current_lobby_id = lobby_id
		var owner_id: int = Steam.getLobbyOwner(lobby_id)
		is_host = (owner_id == steam_id)
		refresh_lobby_members()
	else:
		current_lobby_id = 0
		is_host = false

	lobby_joined.emit(lobby_id, permissions, locked, response)


func _on_steam_lobby_chat_update(_lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	refresh_lobby_members()
	if chat_state == CHAT_MEMBER_STATE_ENTERED:
		var player_name: String = Steam.getFriendPersonaName(changed_id)
		player_joined.emit(changed_id, player_name)
	elif (chat_state & (CHAT_MEMBER_STATE_LEFT | CHAT_MEMBER_STATE_DISCONNECTED | CHAT_MEMBER_STATE_KICKED | CHAT_MEMBER_STATE_BANNED)) != 0:
		player_left.emit(changed_id)


func _on_steam_join_requested(lobby_id: int, _friend_id: int) -> void:
	join_lobby(lobby_id)
