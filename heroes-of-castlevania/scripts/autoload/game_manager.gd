extends Node
## GameManager - Управління станом гри
## Singleton для відстеження глобального стану

# Signals
signal game_started
signal game_ended(winner_id: int)
signal player_state_changed(player_id: int)

# Enums
enum GameState {
	MENU,
	LOBBY,
	HERO_SELECTION,
	PLAYING,
	GAME_OVER
}

# Game state
var current_state: GameState = GameState.MENU

# Player data structure
class PlayerData:
	var peer_id: int
	var hero_name: String = ""
	var position: int = 0  # Position on board (0-69)
	var gold: int = 0
	var health: int = 3
	var armor: int = 0
	var artifacts: Array = []  # Array of artifact resources
	var companions: Array = []  # Array of companion resources
	var weapons: Dictionary = {}  # {weapon_name: count}
	var elixirs: int = 0
	var scrolls: int = 0
	var adventure_cards: Array = []  # Max 3 cards
	var traps: int = 5

	func _init(id: int) -> void:
		peer_id = id


# Players in game
var players: Dictionary = {}  # {peer_id: PlayerData}

# Board state
var board_locations: Array = []  # 70 locations

# Decks state (managed by CardManager, but tracked here)
var monsters_deck_size: int = 0
var ruins_deck_size: int = 0
var adventures_deck_size: int = 0

# Black market
var black_market_artifacts: Array = []


func _ready() -> void:
	pass


## Initialize new game
func start_new_game() -> void:
	# Clear old data
	players.clear()
	black_market_artifacts.clear()

	# Create player data for all connected peers
	for peer_id in NetworkManager.players.keys():
		var player_data = PlayerData.new(peer_id)
		players[peer_id] = player_data

	current_state = GameState.HERO_SELECTION
	game_started.emit()

	print("Game started with %d players" % players.size())


## End game
func end_game(winner_id: int) -> void:
	current_state = GameState.GAME_OVER
	game_ended.emit(winner_id)

	print("Game ended! Winner: Player %d" % winner_id)


## Get player data
func get_player_data(peer_id: int) -> PlayerData:
	if players.has(peer_id):
		return players[peer_id]
	return null


## Get local player data
func get_local_player() -> PlayerData:
	var my_id = multiplayer.get_unique_id()
	return get_player_data(my_id)


## Update player position
@rpc("any_peer", "call_local", "reliable")
func update_player_position(peer_id: int, new_position: int) -> void:
	if players.has(peer_id):
		players[peer_id].position = new_position
		player_state_changed.emit(peer_id)


## Update player gold
@rpc("any_peer", "call_local", "reliable")
func update_player_gold(peer_id: int, amount: int) -> void:
	if players.has(peer_id):
		players[peer_id].gold += amount
		player_state_changed.emit(peer_id)


## Update player health
@rpc("any_peer", "call_local", "reliable")
func update_player_health(peer_id: int, amount: int) -> void:
	if players.has(peer_id):
		players[peer_id].health += amount
		players[peer_id].health = clampi(players[peer_id].health, 0, 3)
		player_state_changed.emit(peer_id)


## Add artifact to player
@rpc("any_peer", "call_local", "reliable")
func add_artifact_to_player(peer_id: int, artifact_data: Dictionary) -> void:
	if players.has(peer_id):
		players[peer_id].artifacts.append(artifact_data)
		player_state_changed.emit(peer_id)


## Remove artifact from player
@rpc("any_peer", "call_local", "reliable")
func remove_artifact_from_player(peer_id: int, artifact_index: int) -> void:
	if players.has(peer_id):
		if artifact_index >= 0 and artifact_index < players[peer_id].artifacts.size():
			players[peer_id].artifacts.remove_at(artifact_index)
			player_state_changed.emit(peer_id)


## Check if player has winning artifact set
func check_winning_condition(peer_id: int) -> bool:
	var player = get_player_data(peer_id)
	if not player:
		return false

	# Need artifacts of one type, levels 1-5
	var artifact_types = {}

	for artifact in player.artifacts:
		var type = artifact.get("type", "")
		var level = artifact.get("level", 0)

		if not artifact_types.has(type):
			artifact_types[type] = []

		artifact_types[type].append(level)

	# Check each type
	for type in artifact_types.keys():
		var levels = artifact_types[type]
		levels.sort()

		# Check if has 1, 2, 3, 4, 5
		if levels.size() >= 5:
			if 1 in levels and 2 in levels and 3 in levels and 4 in levels and 5 in levels:
				return true

	return false


## Add to black market
@rpc("any_peer", "call_local", "reliable")
func add_to_black_market(artifact_data: Dictionary) -> void:
	black_market_artifacts.append(artifact_data)


## Buy from black market
@rpc("any_peer", "call_local", "reliable")
func buy_from_black_market(peer_id: int, artifact_index: int) -> void:
	if artifact_index >= 0 and artifact_index < black_market_artifacts.size():
		var artifact = black_market_artifacts[artifact_index]
		add_artifact_to_player(peer_id, artifact)
		black_market_artifacts.remove_at(artifact_index)
