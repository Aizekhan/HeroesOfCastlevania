extends Node
## CardManager - Управління колодами карт
## Singleton для всіх колод (Монстри, Руїни, Пригоди)

# Signals
signal card_drawn(deck_type: String, card_data: Dictionary)
signal deck_shuffled(deck_type: String)

# Deck types
enum DeckType {
	MONSTERS,
	RUINS,
	ADVENTURES,
	COMPANIONS
}

# Decks (array of dictionaries representing cards)
var monsters_deck: Array = []
var ruins_deck: Array = []
var adventures_deck: Array = []
var companions_deck: Array = []

# Discard piles
var monsters_discard: Array = []
var ruins_discard: Array = []
var adventures_discard: Array = []


func _ready() -> void:
	randomize()


## Initialize all decks
func initialize_decks() -> void:
	if not NetworkManager.is_host:
		return  # Only host initializes decks

	_create_monsters_deck()
	_create_ruins_deck()
	_create_adventures_deck()
	_create_companions_deck()

	print("All decks initialized")


## Create monsters deck (10 types × 5 levels = 50 cards)
func _create_monsters_deck() -> void:
	monsters_deck.clear()

	var monster_types = [
		"Вампір", "Вовкулак", "Зомбі", "Привид", "Скелет",
		"Упир", "Відьма", "Горгона", "Мумія", "Демон"
	]

	for monster_name in monster_types:
		for level in range(1, 6):  # Levels 1-5
			var monster = {
				"name": monster_name,
				"level": level,
				"rewards": _generate_artifact_rewards(level)
			}
			monsters_deck.append(monster)

	shuffle_deck(DeckType.MONSTERS)


## Create ruins deck (90 cards: 60 artifacts + 30 losses)
func _create_ruins_deck() -> void:
	ruins_deck.clear()

	var artifact_types = ["Fire", "Water", "Air", "Nature", "Lightning", "Dragon"]

	# Artifacts distribution
	var level_counts = {1: 5, 2: 4, 3: 3, 4: 2, 5: 1}

	for artifact_type in artifact_types:
		for level in level_counts.keys():
			var count = level_counts[level]
			for i in range(count):
				var artifact = {
					"type": "artifact",
					"artifact_type": artifact_type,
					"level": level
				}
				ruins_deck.append(artifact)

	# Loss cards (30 total)
	for i in range(10):
		ruins_deck.append({"type": "loss", "loss_type": "gold", "amount": "2d6"})

	for i in range(10):
		ruins_deck.append({"type": "loss", "loss_type": "artifact_1"})

	for i in range(10):
		ruins_deck.append({"type": "loss", "loss_type": "artifact_2"})

	shuffle_deck(DeckType.RUINS)


## Create adventures deck (101 cards)
func _create_adventures_deck() -> void:
	adventures_deck.clear()

	# Card distributions from Rules
	_add_adventure_cards("Чудовий день", 16, "movement", "+1D6 movement", true)
	_add_adventure_cards("Засідка", 8, "physical", "Move to nearest Monster", true)
	_add_adventure_cards("Торговець", 8, "encounter", "Teleport to City", true)
	_add_adventure_cards("Кузнець", 8, "encounter", "Upgrade artifact", true)
	_add_adventure_cards("Пастка", 24, "physical", "Place trap token", false)
	_add_adventure_cards("Крадіжка", 6, "physical", "Steal item", true)
	_add_adventure_cards("Бар'єр", 6, "magic", "Block action", true)
	_add_adventure_cards("Вуду", 3, "magic", "Trade 2HP for item", true)
	_add_adventure_cards("Хіл", 4, "magic", "Restore 1HP", true)
	_add_adventure_cards("Абра-кадабра", 4, "magic", "Steal companion", true)
	_add_adventure_cards("Підкуп", 6, "physical", "Buy companion for 2 gold", true)
	_add_adventure_cards("Халепа", 8, "trouble", "Lose 1D6 gold", false)

	shuffle_deck(DeckType.ADVENTURES)


## Helper to add multiple identical adventure cards
func _add_adventure_cards(name: String, count: int, category: String, effect: String, can_hold: bool) -> void:
	for i in range(count):
		adventures_deck.append({
			"name": name,
			"category": category,
			"effect": effect,
			"can_hold": can_hold
		})


## Create companions deck (24 unique)
func _create_companions_deck() -> void:
	companions_deck.clear()

	var companions = [
		{"name": "Єдиноріг", "ability": "Swap dice digits"},
		{"name": "Пегас", "ability": "Skip elixir dice roll"},
		{"name": "Грифон", "ability": "Teleport to Monster location"},
		{"name": "Дракон", "ability": "+artifact chance from boss"},
		{"name": "Вовк", "ability": "+1 gold on monster victory"},
		{"name": "Ведмідь", "ability": "+2 armor in battle"},
		{"name": "Пес", "ability": "Tie = victory"},
		{"name": "Змія", "ability": "Ignore Ruins losses"},
		{"name": "Ластівка", "ability": "Peek top card (1 gold)"},
		{"name": "Лев", "ability": "+1 battle roll (2 gold)"},
		{"name": "Папуга", "ability": "+5 gold in City"},
		{"name": "Ворон", "ability": "Borrow 1 gold"},
		{"name": "Кабан", "ability": "Sacrifice for your life"},
		{"name": "Тхір", "ability": "+2 gold on Find"},
		{"name": "Кінь", "ability": "+2 movement"},
		{"name": "Щур", "ability": "+1 gold in Ruins"},
		{"name": "Кіт", "ability": "Immune to magic"},
		{"name": "Мавпа", "ability": "+1 gold per monster"},
		{"name": "Оси", "ability": "Block action (2 gold)"},
		{"name": "Лисиця", "ability": "Choose 1 of 5 artifacts"},
		{"name": "Павук", "ability": "Immune to physical"},
		{"name": "Черепаха", "ability": "Immune to traps"},
		{"name": "Віслюк", "ability": "Hold 6 cards"},
		{"name": "Білка", "ability": "+1 gold per elixir/scroll use"}
	]

	for companion in companions:
		companions_deck.append(companion)

	shuffle_deck(DeckType.COMPANIONS)


## Generate random artifact rewards for monster
func _generate_artifact_rewards(level: int) -> Array:
	var artifact_types = ["Fire", "Water", "Air", "Nature", "Lightning", "Dragon"]
	var rewards = []

	for i in range(3):
		var random_type = artifact_types[randi() % artifact_types.size()]
		rewards.append({
			"artifact_type": random_type,
			"level": level
		})

	return rewards


## Shuffle deck
@rpc("authority", "call_local", "reliable")
func shuffle_deck(deck_type: DeckType) -> void:
	var deck = _get_deck(deck_type)
	deck.shuffle()

	deck_shuffled.emit(_deck_type_to_string(deck_type))
	print("Deck shuffled: %s" % _deck_type_to_string(deck_type))


## Draw card from deck
@rpc("any_peer", "call_local", "reliable")
func draw_card(deck_type: DeckType) -> Dictionary:
	var deck = _get_deck(deck_type)

	if deck.is_empty():
		# Reshuffle discard pile
		_reshuffle_from_discard(deck_type)

	if deck.is_empty():
		push_error("Deck is empty: %s" % _deck_type_to_string(deck_type))
		return {}

	var card = deck.pop_front()
	card_drawn.emit(_deck_type_to_string(deck_type), card)

	return card


## Discard card
@rpc("any_peer", "call_local", "reliable")
func discard_card(deck_type: DeckType, card: Dictionary) -> void:
	var discard = _get_discard_pile(deck_type)
	discard.append(card)


## Get deck reference
func _get_deck(deck_type: DeckType) -> Array:
	match deck_type:
		DeckType.MONSTERS: return monsters_deck
		DeckType.RUINS: return ruins_deck
		DeckType.ADVENTURES: return adventures_deck
		DeckType.COMPANIONS: return companions_deck
	return []


## Get discard pile reference
func _get_discard_pile(deck_type: DeckType) -> Array:
	match deck_type:
		DeckType.MONSTERS: return monsters_discard
		DeckType.RUINS: return ruins_discard
		DeckType.ADVENTURES: return adventures_discard
	return []


## Reshuffle discard pile back into deck
func _reshuffle_from_discard(deck_type: DeckType) -> void:
	var deck = _get_deck(deck_type)
	var discard = _get_discard_pile(deck_type)

	deck.append_array(discard)
	discard.clear()

	shuffle_deck(deck_type)
	print("Reshuffled discard pile: %s" % _deck_type_to_string(deck_type))


## Helper: deck type to string
func _deck_type_to_string(deck_type: DeckType) -> String:
	match deck_type:
		DeckType.MONSTERS: return "Monsters"
		DeckType.RUINS: return "Ruins"
		DeckType.ADVENTURES: return "Adventures"
		DeckType.COMPANIONS: return "Companions"
	return "Unknown"
