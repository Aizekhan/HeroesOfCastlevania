extends Control
## Lobby Scene
## Лобі гри де гравці чекають перед початком

# UI References
@onready var players_label: Label = $MarginContainer/VBoxContainer/MainContent/LeftPanel/PlayersLabel
@onready var players_container: VBoxContainer = $MarginContainer/VBoxContainer/MainContent/LeftPanel/PlayersList/ScrollContainer/PlayersContainer
@onready var ready_button: Button = $MarginContainer/VBoxContainer/MainContent/LeftPanel/ReadyButton
@onready var start_button: Button = $MarginContainer/VBoxContainer/BottomPanel/StartButton
@onready var room_info: Label = $MarginContainer/VBoxContainer/Header/RoomInfo
@onready var chat_log: RichTextLabel = $MarginContainer/VBoxContainer/MainContent/RightPanel/ChatContainer/ChatScroll/ChatLog
@onready var chat_input: LineEdit = $MarginContainer/VBoxContainer/MainContent/RightPanel/ChatContainer/ChatInputContainer/ChatInput

# State
var is_ready: bool = false


func _ready() -> void:
	# Update room info
	if NetworkManager.is_host:
		room_info.text = "Кімната: %s:%d (HOST)" % [NetworkManager.server_ip, NetworkManager.server_port]
		start_button.disabled = false
	else:
		room_info.text = "Кімната: %s:%d" % [NetworkManager.server_ip, NetworkManager.server_port]
		start_button.visible = false  # Only host can start

	# Connect NetworkManager signals
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.player_list_updated.connect(_update_player_list)

	# Initial update
	_update_player_list()
	_add_chat_message("Система", "Ласкаво просимо до лобі!", Color.YELLOW)


# ========================================
# Player List Management
# ========================================

func _update_player_list() -> void:
	# Clear current list
	for child in players_container.get_children():
		child.queue_free()

	var player_count = NetworkManager.get_player_count()
	players_label.text = "👥 Гравці (%d/6)" % player_count

	# Add players
	for peer_id in NetworkManager.players.keys():
		var player_data = NetworkManager.players[peer_id]
		_add_player_to_list(peer_id, player_data)

	# Update start button
	if NetworkManager.is_host:
		start_button.disabled = not NetworkManager.can_start_game()


func _add_player_to_list(peer_id: int, player_data: Dictionary) -> void:
	var player_panel = PanelContainer.new()
	player_panel.custom_minimum_size = Vector2(0, 50)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	player_panel.add_child(hbox)

	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	hbox.add_child(margin)

	var content = HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	# Player name
	var name_label = Label.new()
	name_label.text = player_data.get("name", "Player %d" % peer_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 20)

	# Is this us?
	if peer_id == multiplayer.get_unique_id():
		name_label.text += " (Ви)"
		name_label.modulate = Color.YELLOW

	# Is this host?
	if NetworkManager.is_host and peer_id == 1:
		name_label.text += " [HOST]"
		name_label.modulate = Color.ORANGE

	content.add_child(name_label)

	# Ready status
	var ready_label = Label.new()
	if player_data.get("ready", false):
		ready_label.text = "✓ Готовий"
		ready_label.modulate = Color.GREEN
	else:
		ready_label.text = "⏳ Не готовий"
		ready_label.modulate = Color.GRAY

	ready_label.add_theme_font_size_override("font_size", 18)
	content.add_child(ready_label)

	players_container.add_child(player_panel)


# ========================================
# Chat System
# ========================================

func _add_chat_message(sender: String, message: String, color: Color = Color.WHITE) -> void:
	var timestamp = Time.get_time_string_from_system()
	var formatted_msg = "[color=#%s][%s] %s: %s[/color]\n" % [
		color.to_html(),
		timestamp,
		sender,
		message
	]

	chat_log.append_text(formatted_msg)


@rpc("any_peer", "call_local", "reliable")
func send_chat_message(sender_id: int, message: String) -> void:
	var sender_name = "Player %d" % sender_id

	if NetworkManager.players.has(sender_id):
		sender_name = NetworkManager.players[sender_id].get("name", sender_name)

	_add_chat_message(sender_name, message)


# ========================================
# Button Callbacks
# ========================================

func _on_ready_button_pressed() -> void:
	is_ready = not is_ready

	# Update button
	if is_ready:
		ready_button.text = "✓ Готовий"
		ready_button.modulate = Color.GREEN
	else:
		ready_button.text = "⏳ Не готовий"
		ready_button.modulate = Color.WHITE

	# Notify NetworkManager
	var my_id = multiplayer.get_unique_id()
	NetworkManager.set_player_ready.rpc(my_id, is_ready)


func _on_start_button_pressed() -> void:
	if not NetworkManager.is_host:
		return

	if not NetworkManager.can_start_game():
		_add_chat_message("Система", "Не всі гравці готові!", Color.RED)
		return

	print("Starting game...")
	_add_chat_message("Система", "Гра починається!", Color.GREEN)

	# TODO: Start game
	# For now, just notify
	await get_tree().create_timer(1.0).timeout
	_add_chat_message("Система", "Перехід до гри ще не реалізовано", Color.ORANGE)


func _on_back_button_pressed() -> void:
	# Disconnect from network
	NetworkManager.disconnect_from_network()

	# Go back to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_send_button_pressed() -> void:
	_send_chat_message()


func _on_chat_input_text_submitted(_new_text: String) -> void:
	_send_chat_message()


func _send_chat_message() -> void:
	var message = chat_input.text.strip_edges()

	if message.is_empty():
		return

	var my_id = multiplayer.get_unique_id()
	send_chat_message.rpc(my_id, message)

	chat_input.text = ""
	chat_input.grab_focus()


# ========================================
# NetworkManager Signal Handlers
# ========================================

func _on_peer_connected(id: int) -> void:
	_add_chat_message("Система", "Гравець %d приєднався" % id, Color.CYAN)
	_update_player_list()


func _on_peer_disconnected(id: int) -> void:
	_add_chat_message("Система", "Гравець %d вийшов" % id, Color.ORANGE)
	_update_player_list()
