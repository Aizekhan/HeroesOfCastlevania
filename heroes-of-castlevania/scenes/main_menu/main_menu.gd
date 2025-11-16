extends Control
## Main Menu Scene
## Головне меню гри з кнопками Host/Join/Settings/Exit

# UI References
@onready var join_dialog: Window = $JoinDialog
@onready var ip_input: LineEdit = $JoinDialog/VBoxContainer/IPInput
@onready var port_input: LineEdit = $JoinDialog/VBoxContainer/PortInput


func _ready() -> void:
	# Set default values
	ip_input.text = "127.0.0.1"
	port_input.text = str(NetworkManager.DEFAULT_PORT)

	# Connect to NetworkManager signals
	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)


# ========================================
# Button Callbacks
# ========================================

func _on_host_button_pressed() -> void:
	print("Creating server...")

	# Create server
	NetworkManager.create_server()

	# Server will be created, signal will trigger _on_server_created


func _on_join_button_pressed() -> void:
	# Show join dialog
	join_dialog.show()


func _on_settings_button_pressed() -> void:
	# TODO: Open settings menu
	print("Settings not implemented yet")

	# Show temporary notification
	var notif = Label.new()
	notif.text = "Налаштування в розробці..."
	notif.position = Vector2(850, 500)
	notif.modulate = Color.YELLOW
	add_child(notif)

	await get_tree().create_timer(2.0).timeout
	notif.queue_free()


func _on_exit_button_pressed() -> void:
	print("Exiting game...")
	get_tree().quit()


# ========================================
# Join Dialog Callbacks
# ========================================

func _on_connect_button_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	var port_text = port_input.text.strip_edges()

	# Validate input
	if ip.is_empty():
		ip = "127.0.0.1"

	var port = int(port_text) if port_text.is_valid_int() else NetworkManager.DEFAULT_PORT

	print("Connecting to %s:%d..." % [ip, port])

	# Hide dialog
	join_dialog.hide()

	# Join server
	NetworkManager.join_server(ip, port)


func _on_cancel_button_pressed() -> void:
	join_dialog.hide()


# ========================================
# NetworkManager Signal Handlers
# ========================================

func _on_server_created() -> void:
	print("Server created successfully! Going to lobby...")

	# Go to lobby scene
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_joined_server() -> void:
	print("Joined server successfully! Going to lobby...")

	# Go to lobby scene
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_connection_failed() -> void:
	print("Failed to connect to server!")

	# Show error message
	var error_label = Label.new()
	error_label.text = "❌ Не вдалося підключитися до сервера!"
	error_label.position = Vector2(700, 500)
	error_label.modulate = Color.RED
	error_label.add_theme_font_size_override("font_size", 24)
	add_child(error_label)

	await get_tree().create_timer(3.0).timeout
	error_label.queue_free()
