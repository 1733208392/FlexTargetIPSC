extends Control

@onready var start_button = $VBoxContainer/ipsc
@onready var network_button = $VBoxContainer/network
@onready var bootcamp_button = $VBoxContainer/boot_camp
@onready var leaderboard_button = $VBoxContainer/learder_board
@onready var option_button = $VBoxContainer/option
@onready var copyright_label = $Label

var focused_index
var buttons = []

func load_language_setting():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[Menu] Loaded language from GlobalData: ", language)
		call_deferred("update_ui_texts")
	else:
		print("[Menu] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
		call_deferred("update_ui_texts")

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh_CN"
		"Traditional Chinese":
			locale = "zh_TW"
		"Japanese":
			locale = "ja"
		_:
			locale = "en"  # Default to English
	TranslationServer.set_locale(locale)
	print("[Menu] Set locale to: ", locale)

func update_ui_texts():
	# Update button texts with current language
	start_button.text = tr("ipsc")
	network_button.text = tr("network")
	bootcamp_button.text = tr("boot_camp")
	leaderboard_button.text = tr("leaderboard")
	option_button.text = tr("options")
	copyright_label.text = tr("copyright")
	
	print("[Menu] UI texts updated")

func _ready():
	# Load and apply current language setting
	load_language_setting()
	
	# Initially hide the network button until network is started
	network_button.visible = false
	
	# Connect button signals
	focused_index = 0
	buttons = [
		start_button,
		network_button,
		bootcamp_button,
		leaderboard_button,
		option_button]
		
	buttons[focused_index].grab_focus()

	# Use get_node instead of Engine.has_singleton
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		# Connect BLE ready command signal to jump to network scene
		if ws_listener.has_signal("ble_ready_command"):
			ws_listener.ble_ready_command.connect(_on_ble_ready_command)
			print("[Menu] Connected to WebSocketListener.ble_ready_command signal")
		else:
			print("[Menu] WebSocketListener has no ble_ready_command signal")
		print("[Menu] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Menu] WebSocketListener singleton not found!")

	# Connect to GlobalData netlink_status_loaded signal
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.netlink_status_loaded.connect(_on_netlink_status_loaded)
		print("[Menu] Connected to GlobalData.netlink_status_loaded signal")
		# Check if network is already started
		_check_network_button_visibility()
	else:
		print("[Menu] GlobalData not found!")

	start_button.pressed.connect(on_start_pressed)
	network_button.pressed.connect(_on_network_pressed)
	bootcamp_button.pressed.connect(_on_bootcamp_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	option_button.pressed.connect(_on_option_pressed)

func _on_menu_control(directive: String):
	print("[Menu] Received menu_control signal with directive: ", directive)
	match directive:
		"up":
			print("[Menu] Moving focus up")
			focused_index = (focused_index - 1) % buttons.size()
			buttons[focused_index].grab_focus()
		"down":
			print("[Menu] Moving focus down")
			focused_index = (focused_index + 1) % buttons.size()
			buttons[focused_index].grab_focus()
		"enter":
			print("[Menu] Simulating button press")
			buttons[focused_index].pressed.emit()
		"power":
			print("[Menu] Power off")
			power_off()
		_:
			print("[Menu] Unknown directive: ", directive)

func on_start_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_start_response)
	else:
		print("[Menu] HttpService singleton not found!")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/intro.tscn")
		else:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_start_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Menu] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		print("[Menu] Start game success, changing scene.")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/intro.tscn")
		else:
			print("[Menu] Warning: Node not in tree, cannot change scene")
	else:
		print("[Menu] Start game failed or invalid response.")

func _on_network_pressed():
	# Load the network scene
	print("[Menu] _on_network_pressed called, is_inside_tree: ", is_inside_tree())
	if is_inside_tree():
		print("[Menu] Attempting to change scene to: res://scene/drills_network/drills_network.tscn")
		var result = get_tree().change_scene_to_file("res://scene/drills_network/drills_network.tscn")
		print("[Menu] change_scene_to_file result: ", result)
	else:
		print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_bootcamp_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_bootcamp_response)
	else:
		print("[Menu] HttpService singleton not found!")
	print("Boot Camp button pressed - Load training mode")

func _on_bootcamp_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Menu] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		print("[Menu] Bootcamp Start game success, changing scene.")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/bootcamp.tscn")
		else:
			print("[Menu] Warning: Node not in tree, cannot change scene")
	else:
		print("[Menu] Start bootcamp failed or invalid response.")

func _on_leaderboard_pressed():
	# Load the history scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/history.tscn")
	else:
		print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_option_pressed():
	# Load the options scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/option/option.tscn")
	else:
		print("[Menu] Warning: Node not in tree, cannot change scene")

func power_off():
	# Call the HTTP service to power off the system
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Menu] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		print("[Menu] HttpService singleton not found!")

func _on_ble_ready_command(content: Dictionary) -> void:
	print("[Menu] Received ble_ready_command with content: ", content)
	# Optionally inspect content to decide target scene or additional behavior
	# Store content on GlobalData.settings_dict so the drills_network scene can read it on startup
	var gd = get_node_or_null("/root/GlobalData")
	if gd:
		var settings = gd.get("settings_dict")
		if settings != null and typeof(settings) == TYPE_DICTIONARY:
			settings["ble_ready_content"] = content
			print("[Menu] Stored ble_ready_content in GlobalData.settings_dict")
		else:
			# fallback: attach directly on GlobalData
			gd.set("ble_ready_content", content)
			print("[Menu] Stored ble_ready_content directly on GlobalData")
	else:
		print("[Menu] GlobalData not available; cannot persist ble content")

	# Send ACK back to mobile app before changing scene
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var ack_data = {"ack": "ready"}
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				print("[Menu] ACK for ready command sent successfully")
			else:
				print("[Menu] Failed to send ACK for ready command")
		, ack_data)
	else:
		print("[Menu] HttpService not available; cannot send ACK")

	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/drills_network/drills_network.tscn")
	else:
		print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_network_started() -> void:
	print("[Menu] Network started, making network button visible")
	network_button.visible = true

func _on_netlink_status_loaded() -> void:
	print("[Menu] Netlink status loaded, checking network button visibility")
	_check_network_button_visibility()

func _check_network_button_visibility() -> void:
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.netlink_status.has("started"):
		if global_data.netlink_status["started"] == true:
			print("[Menu] Network is started, making network button visible")
			network_button.visible = true
		else:
			print("[Menu] Network is not started, keeping network button hidden")
			network_button.visible = false
	else:
		print("[Menu] Netlink status not available or missing 'started' key")

func _on_shutdown_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Menu] Shutdown HTTP response:", result, response_code, body_str)
