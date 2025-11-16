extends Node
## TurnManager - Управління ходами гравців
## Singleton для покрокової системи

# Signals
signal turn_started(player_id: int)
signal turn_ended(player_id: int)
signal turn_order_set(order: Array)
signal dice_rolled(player_id: int, result: int)

# Turn state
var current_player_index: int = 0
var player_order: Array = []  # Array of peer IDs
var is_turn_in_progress: bool = false

# Dice
var last_dice_result: int = 0


func _ready() -> void:
	pass


## Initialize turn order
func setup_turn_order(players: Array) -> void:
	player_order = players.duplicate()
	current_player_index = 0

	turn_order_set.emit(player_order)
	print("Turn order set: %s" % player_order)


## Determine initial turn order (by dice roll)
func determine_turn_order_by_dice() -> void:
	if not NetworkManager.is_host:
		return

	var dice_results: Dictionary = {}

	# Each player rolls dice (simulated for now)
	for peer_id in GameManager.players.keys():
		dice_results[peer_id] = randi_range(1, 6)

	# Sort by dice result (descending)
	var sorted_players = dice_results.keys()
	sorted_players.sort_custom(func(a, b): return dice_results[a] > dice_results[b])

	# Reverse for turn order (last picks hero first)
	player_order = sorted_players
	player_order.reverse()

	# Sync to all clients
	sync_turn_order.rpc(player_order)

	print("Turn order determined by dice: %s" % player_order)


## Sync turn order (host only)
@rpc("authority", "call_local", "reliable")
func sync_turn_order(order: Array) -> void:
	player_order = order
	current_player_index = 0
	turn_order_set.emit(player_order)


## Get current player ID
func get_current_player() -> int:
	if player_order.is_empty():
		return -1
	return player_order[current_player_index]


## Check if it's local player's turn
func is_my_turn() -> bool:
	var my_id = multiplayer.get_unique_id()
	return get_current_player() == my_id


## Start turn
func start_turn() -> void:
	if player_order.is_empty():
		push_error("No player order set!")
		return

	is_turn_in_progress = true
	var current_player = get_current_player()

	turn_started.emit(current_player)
	print("Turn started for player %d" % current_player)


## End turn and move to next player
@rpc("any_peer", "call_local", "reliable")
func end_turn() -> void:
	if not is_turn_in_progress:
		return

	var current_player = get_current_player()
	turn_ended.emit(current_player)

	# Move to next player
	current_player_index = (current_player_index + 1) % player_order.size()
	is_turn_in_progress = false

	print("Turn ended for player %d" % current_player)

	# Auto-start next turn
	await get_tree().create_timer(0.5).timeout
	start_turn()


## Roll dice (D6)
@rpc("any_peer", "call_local", "reliable")
func roll_dice(player_id: int) -> int:
	var result = randi_range(1, 6)
	last_dice_result = result

	dice_rolled.emit(player_id, result)
	print("Player %d rolled: %d" % [player_id, result])

	return result


## Roll dice and return result (local)
func roll_dice_local() -> int:
	var my_id = multiplayer.get_unique_id()
	return roll_dice.rpc_id(1, my_id)  # Ask server to roll


## Roll custom dice (D3, etc.)
@rpc("any_peer", "call_local", "reliable")
func roll_custom_dice(player_id: int, sides: int) -> int:
	var result = randi_range(1, sides)

	print("Player %d rolled D%d: %d" % [player_id, sides, result])
	return result


## Skip turn (for penalties, etc.)
@rpc("any_peer", "call_local", "reliable")
func skip_turn(player_id: int) -> void:
	if get_current_player() == player_id:
		print("Player %d skips their turn" % player_id)
		end_turn.rpc()
