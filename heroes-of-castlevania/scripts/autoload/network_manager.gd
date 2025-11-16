extends Node
## NetworkManager - Управління мережевим з'єднанням
## Singleton для онлайн мультиплеєра

# Signals
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_created
signal joined_server
signal connection_failed
signal player_list_updated

# Constants
const DEFAULT_PORT = 7777
const MAX_PLAYERS = 6

# Variables
var players: Dictionary = {}  # {peer_id: {name: String, ready: bool}}
var is_host: bool = false
var server_ip: String = "127.0.0.1"
var server_port: int = DEFAULT_PORT


func _ready() -> void:
	# Connect to multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Create server (Host)
func create_server(port: int = DEFAULT_PORT) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)

	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		server_port = port

		# Add host to players list
		var host_id = multiplayer.get_unique_id()
		players[host_id] = {
			"name": "Host",
			"ready": false
		}

		server_created.emit()
		print("Server created on port %d" % port)
	else:
		push_error("Failed to create server: %d" % error)


## Join server (Client)
func join_server(ip: String, port: int = DEFAULT_PORT) -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, port)

	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		server_ip = ip
		server_port = port
		print("Connecting to server %s:%d..." % [ip, port])
	else:
		connection_failed.emit()
		push_error("Failed to join server: %d" % error)


## Disconnect from network
func disconnect_from_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	players.clear()
	is_host = false


## Get player count
func get_player_count() -> int:
	return players.size()


## Check if we can start game
func can_start_game() -> bool:
	if not is_host:
		return false

	if players.size() < 2:
		return false

	# Check if all players are ready
	for player_data in players.values():
		if not player_data.ready:
			return false

	return true


## Set player ready status
@rpc("any_peer", "call_local", "reliable")
func set_player_ready(peer_id: int, ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id].ready = ready
		player_list_updated.emit()


## Set player name
@rpc("any_peer", "call_local", "reliable")
func set_player_name(peer_id: int, player_name: String) -> void:
	if players.has(peer_id):
		players[peer_id].name = player_name
		player_list_updated.emit()


## Sync players list (host only)
@rpc("authority", "call_local", "reliable")
func sync_players(players_data: Dictionary) -> void:
	players = players_data
	player_list_updated.emit()


# ========================================
# Signal callbacks
# ========================================

func _on_peer_connected(id: int) -> void:
	print("Peer connected: %d" % id)

	if is_host:
		# Add new player to list
		players[id] = {
			"name": "Player %d" % id,
			"ready": false
		}

		# Sync players list to all clients
		sync_players.rpc(players)

	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: %d" % id)

	if players.has(id):
		players.erase(id)

	if is_host:
		# Sync players list to all clients
		sync_players.rpc(players)

	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	print("Connected to server!")

	# Add self to players list
	var my_id = multiplayer.get_unique_id()
	players[my_id] = {
		"name": "Player %d" % my_id,
		"ready": false
	}

	joined_server.emit()


func _on_connection_failed() -> void:
	print("Connection failed!")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("Server disconnected!")
	disconnect_from_network()
