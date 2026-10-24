extends Node

## Autoload: NetworkManager
## Kiến trúc Host-Authoritative: quản lý MultiplayerPeer (SteamMultiplayerPeer / ENet fallback),
## đồng bộ hóa lệnh qua RPC (send_command -> submit_command -> broadcast_command),
## và state sync heartbeat định kỳ 1 giây.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal peer_synced(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
signal command_received(command: Dictionary)
signal state_synchronized(state: Dictionary)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8
const HEARTBEAT_INTERVAL: float = 1.0

var is_host: bool = false
var command_queue: Array[Dictionary] = []
var connected_peers: Array[int] = []
var synced_peers: Dictionary = {1: true}
var current_tick: int = 0
var command_sequence: int = 0
var heartbeat_timer: float = 0.0

var _state_provider: Callable = Callable()


func _ready() -> void:
	_connect_multiplayer_signals()


func _process(delta: float) -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	if multiplayer.is_server():
		current_tick += 1
		heartbeat_timer += delta
		if heartbeat_timer >= HEARTBEAT_INTERVAL:
			heartbeat_timer = 0.0
			_send_heartbeat()


func _connect_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(steam_lobby_id: int = 0, fallback_port: int = DEFAULT_PORT) -> Error:
	disconnect_game()

	var err: Error = FAILED
	if ClassDB.class_exists("SteamMultiplayerPeer") and steam_lobby_id != 0:
		var steam_peer: Variant = ClassDB.instantiate("SteamMultiplayerPeer")
		if steam_peer != null:
			err = steam_peer.create_host(0)
			if err == OK:
				multiplayer.multiplayer_peer = steam_peer
				is_host = true
				connected_peers = [1]
				synced_peers = {1: true}
				print_rich("[color=green]NetworkManager: Host game qua SteamMultiplayerPeer thanh cong.[/color]")
				return OK
			push_warning("NetworkManager: SteamMultiplayerPeer create_host that bai (loi %d), chuyen sang ENet." % err)

	var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	err = enet_peer.create_server(fallback_port, MAX_PLAYERS)
	if err == OK:
		multiplayer.multiplayer_peer = enet_peer
		is_host = true
		connected_peers = [1]
		synced_peers = {1: true}
		print_rich("[color=green]NetworkManager: Host game qua ENet port %d thanh cong.[/color]" % fallback_port)
	else:
		push_error("NetworkManager: Khong the khoi tao server ENet (loi %d)." % err)
	return err


func join_game(host_steam_id: int = 0, fallback_address: String = "127.0.0.1", fallback_port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	synced_peers.clear()

	var err: Error = FAILED
	if ClassDB.class_exists("SteamMultiplayerPeer") and host_steam_id != 0:
		var steam_peer: Variant = ClassDB.instantiate("SteamMultiplayerPeer")
		if steam_peer != null:
			err = steam_peer.create_client(host_steam_id, 0)
			if err == OK:
				multiplayer.multiplayer_peer = steam_peer
				is_host = false
				print_rich("[color=green]NetworkManager: Ket noi client toi Steam Host %d thanh cong.[/color]" % host_steam_id)
				return OK
			push_warning("NetworkManager: SteamMultiplayerPeer create_client that bai (loi %d), chuyen sang ENet." % err)

	var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	err = enet_peer.create_client(fallback_address, fallback_port)
	if err == OK:
		multiplayer.multiplayer_peer = enet_peer
		is_host = false
		print_rich("[color=green]NetworkManager: Ket noi client toi ENet %s:%d thanh cong.[/color]" % [fallback_address, fallback_port])
	else:
		push_error("NetworkManager: Khong the ket noi client ENet toi %s:%d (loi %d)." % [fallback_address, fallback_port, err])
	return err


func disconnect_game() -> void:
	if multiplayer.has_multiplayer_peer():
		var peer: MultiplayerPeer = multiplayer.multiplayer_peer
		if peer != null:
			peer.close()
		multiplayer.multiplayer_peer = null

	is_host = false
	connected_peers.clear()
	synced_peers = {1: true}
	command_queue.clear()
	current_tick = 0
	command_sequence = 0
	heartbeat_timer = 0.0


func set_state_provider(provider: Callable) -> void:
	_state_provider = provider


func send_command(action_type: String, payload: Dictionary = {}) -> void:
	var cmd: Dictionary = {
		"sender_peer": multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1,
		"type": action_type,
		"payload": payload,
		"client_time": Time.get_ticks_msec(),
	}

	if not multiplayer.has_multiplayer_peer():
		# Che do Offline / Singleplayer: xu ly truc tiep
		cmd["tick"] = current_tick
		cmd["sequence"] = _next_command_sequence()
		command_queue.append(cmd)
		command_received.emit(cmd)
		return

	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	# Gửi lên Host để xác thực và đóng dấu tick
	submit_command.rpc_id(1, cmd)


func request_game_sync() -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	request_sync.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_sync() -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var local_id: int = multiplayer.get_unique_id()
	if local_id == 0:
		return
	if not multiplayer.is_server():
		return

	var caller_id: int = multiplayer.get_remote_sender_id()
	if caller_id == 0:
		caller_id = 1

	synced_peers[caller_id] = true
	peer_synced.emit(caller_id)

	var payload: Dictionary = _build_sync_payload()
	sync_state.rpc_id(caller_id, payload)


@rpc("any_peer", "call_local", "reliable")
func submit_command(command: Dictionary) -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var local_id: int = multiplayer.get_unique_id()
	if local_id == 0:
		return
	if not multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0:
		command["sender_peer"] = sender

	command["tick"] = current_tick
	command["sequence"] = _next_command_sequence()

	# Host Authoritative: targeted RPC toi synced peers thay vi broadcast toan mang
	for target_id: int in synced_peers.keys():
		broadcast_command.rpc_id(target_id, command)


@rpc("authority", "call_local", "reliable")
func broadcast_command(command: Dictionary) -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var local_id: int = multiplayer.get_unique_id()
	if local_id == 0:
		return

	command_queue.append(command)
	command_received.emit(command)


func pop_command() -> Dictionary:
	if command_queue.is_empty():
		return {}
	return command_queue.pop_front()


func pop_all_commands() -> Array[Dictionary]:
	var commands: Array[Dictionary] = command_queue.duplicate()
	command_queue.clear()
	return commands


func get_command_count() -> int:
	return command_queue.size()


func clear_command_queue() -> void:
	command_queue.clear()


func _build_sync_payload() -> Dictionary:
	var payload: Dictionary = {}
	if _state_provider.is_valid():
		var custom_state: Variant = _state_provider.call()
		if custom_state is Dictionary:
			payload = custom_state

	payload["tick"] = current_tick
	payload["server_time"] = Time.get_ticks_msec()
	payload["peer_count"] = connected_peers.size()
	return payload


func _send_heartbeat() -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var payload: Dictionary = _build_sync_payload()

	for target_id: int in synced_peers.keys():
		sync_state.rpc_id(target_id, payload)


@rpc("authority", "call_local", "unreliable_ordered")
func sync_state(state_data: Dictionary) -> void:
	if not is_inside_tree():
		return
	if not multiplayer or not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var local_id: int = multiplayer.get_unique_id()
	if local_id == 0:
		return

	state_synchronized.emit(state_data)


func _next_command_sequence() -> int:
	command_sequence += 1
	return command_sequence


func _on_peer_connected(id: int) -> void:
	if not connected_peers.has(id):
		connected_peers.append(id)
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	synced_peers.erase(id)
	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	connection_succeeded.emit()
	request_game_sync()


func _on_connection_failed() -> void:
	disconnect_game()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	disconnect_game()
	server_disconnected.emit()
