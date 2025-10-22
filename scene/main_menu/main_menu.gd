extends Control

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

@onready var start_button = $VBoxContainer/ipsc
@onready var network_button = $VBoxContainer/network
@onready var bootcamp_button = $VBoxContainer/boot_camp
@onready var leaderboard_button = $VBoxContainer/learder_board
@onready var option_button = $VBoxContainer/option
@onready var copyright_label = $Label
@onready var background_music = $BackgroundMusic

var focused_index
var buttons = []

func load_language_setting():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[Menu] Loaded language from GlobalData: ", language)
		call_deferred("update_ui_texts")
	else:
		if not DEBUG_DISABLED:
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
	if not DEBUG_DISABLED:
		print("[Menu] Set locale to: ", locale)

func update_ui_texts():
	# Update button texts with current language
	start_button.text = tr("ipsc")
	network_button.text = tr("network")
	bootcamp_button.text = tr("boot_camp")
	leaderboard_button.text = tr("leaderboard")
	option_button.text = tr("options")
	copyright_label.text = tr("copyright")
	
	if not DEBUG_DISABLED:
		print("[Menu] UI texts updated")

func _ready():
	# Show status bar when entering main menu
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		if not DEBUG_DISABLED:
			print("[Menu] Showed status bar: ", status_bar.name)
	
	# Load and apply current language setting
	load_language_setting()
	
	# Load SFX volume from GlobalData and apply it
	var global_data_for_sfx = get_node_or_null("/root/GlobalData")
	if global_data_for_sfx and global_data_for_sfx.settings_dict.has("sfx_volume"):
		var sfx_volume = global_data_for_sfx.settings_dict.get("sfx_volume", 5)
		_apply_sfx_volume(sfx_volume)
		if not DEBUG_DISABLED:
			print("[Menu] Loaded SFX volume from GlobalData: ", sfx_volume)
	else:
		# Default to volume level 5 if not set
		_apply_sfx_volume(5)
		if not DEBUG_DISABLED:
			print("[Menu] Using default SFX volume: 5")
	
	# Play background music
	if background_music:
		background_music.play()
		if not DEBUG_DISABLED:
			print("[Menu] Playing background music")
	
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
			if not DEBUG_DISABLED:
				print("[Menu] Connected to WebSocketListener.ble_ready_command signal")
		else:
			if not DEBUG_DISABLED:
				print("[Menu] WebSocketListener has no ble_ready_command signal")
		if not DEBUG_DISABLED:
			print("[Menu] Connecting to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] WebSocketListener singleton not found!")

	# Connect to GlobalData netlink_status_loaded signal
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.netlink_status_loaded.connect(_on_netlink_status_loaded)
		if not DEBUG_DISABLED:
			print("[Menu] Connected to GlobalData.netlink_status_loaded signal")
		# Check if network is already started
		_check_network_button_visibility()
	else:
		if not DEBUG_DISABLED:
			print("[Menu] GlobalData not found!")

	start_button.pressed.connect(on_start_pressed)
	network_button.pressed.connect(_on_network_pressed)
	bootcamp_button.pressed.connect(_on_bootcamp_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	option_button.pressed.connect(_on_option_pressed)

func on_start_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_start_response)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] HttpService singleton not found!")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/intro.tscn")
		else:
			if not DEBUG_DISABLED:
				print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_start_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Menu] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[Menu] Start game success, changing scene.")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/intro/intro.tscn")
		else:
			if not DEBUG_DISABLED:
				print("[Menu] Warning: Node not in tree, cannot change scene")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Start game failed or invalid response.")

func _on_network_pressed():
	# Load the network scene
	if not DEBUG_DISABLED:
		print("[Menu] _on_network_pressed called, is_inside_tree: ", is_inside_tree())
	if is_inside_tree():
		if not DEBUG_DISABLED:
			print("[Menu] Attempting to change scene to: res://scene/drills_network/drills_network.tscn")
		var result = get_tree().change_scene_to_file("res://scene/drills_network/drills_network.tscn")
		if not DEBUG_DISABLED:
			print("[Menu] change_scene_to_file result: ", result)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_bootcamp_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_bootcamp_response)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] HttpService singleton not found!")
	if not DEBUG_DISABLED:
		print("Boot Camp button pressed - Load training mode")

func _on_bootcamp_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Menu] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[Menu] Bootcamp Start game success, changing scene.")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/bootcamp.tscn")
		else:
			if not DEBUG_DISABLED:
				print("[Menu] Warning: Node not in tree, cannot change scene")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Start bootcamp failed or invalid response.")

func _on_leaderboard_pressed():
	# Load the history scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/history.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_option_pressed():
	# Load the options scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/option/option.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func power_off():
	if not DEBUG_DISABLED:
		print("[Menu] power_off() called")
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	if not DEBUG_DISABLED:
		print("[Menu] Dialog scene preloaded")
	var dialog = dialog_scene.instantiate()
	if not DEBUG_DISABLED:
		print("[Menu] Dialog instantiated")
	dialog.set_alert_text(tr("power_off_alert"))
	if not DEBUG_DISABLED:
		print("[Menu] Alert text set")
	add_child(dialog)
	if not DEBUG_DISABLED:
		print("[Menu] Dialog added to scene tree")
	dialog.show()
	if not DEBUG_DISABLED:
		print("[Menu] Dialog shown")

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[Menu] Received menu_control signal with directive: ", directive)
	match directive:
		"up":
			if not DEBUG_DISABLED:
				print("[Menu] Moving focus up")
			focused_index = (focused_index - 1) % buttons.size()
			# Skip invisible buttons
			while not buttons[focused_index].visible:
				focused_index = (focused_index - 1) % buttons.size()
			if not DEBUG_DISABLED:
				print("[Menu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
				print("[Menu] Button has_focus before grab_focus: ", buttons[focused_index].has_focus())
			buttons[focused_index].grab_focus()
			if not DEBUG_DISABLED:
				print("[Menu] Button has_focus after grab_focus: ", buttons[focused_index].has_focus())
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"down":
			if not DEBUG_DISABLED:
				print("[Menu] Moving focus down")
			focused_index = (focused_index + 1) % buttons.size()
			# Skip invisible buttons
			while not buttons[focused_index].visible:
				focused_index = (focused_index + 1) % buttons.size()
			if not DEBUG_DISABLED:
				print("[Menu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
				print("[Menu] Button has_focus before grab_focus: ", buttons[focused_index].has_focus())
			buttons[focused_index].grab_focus()
			if not DEBUG_DISABLED:
				print("[Menu] Button has_focus after grab_focus: ", buttons[focused_index].has_focus())
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"enter":
			if not DEBUG_DISABLED:
				print("[Menu] Simulating button press")
			buttons[focused_index].pressed.emit()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"power":
			if not DEBUG_DISABLED:
				print("[Menu] Power off")
			power_off()
		_:
			if not DEBUG_DISABLED:
				print("[Menu] Unknown directive: ", directive)

func _on_ble_ready_command(content: Dictionary) -> void:
	if not DEBUG_DISABLED:
		print("[Menu] Received ble_ready_command with content: ", content)
	# Optionally inspect content to decide target scene or additional behavior
	# Store content on GlobalData so the drills_network scene can read it on startup
	var gd = get_node_or_null("/root/GlobalData")
	if gd:
		gd.ble_ready_content = content
		if not DEBUG_DISABLED:
			print("[Menu] Stored ble_ready_content in GlobalData: ", content)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] GlobalData not available; cannot persist ble content")

	# Send ACK back to mobile app before changing scene
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var ack_data = {"ack": "ready"}
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if not DEBUG_DISABLED:
					print("[Menu] ACK for ready command sent successfully")
			else:
				if not DEBUG_DISABLED:
					print("[Menu] Failed to send ACK for ready command")
		, ack_data)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] HttpService not available; cannot send ACK")

	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/drills_network/drills_network.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_network_started() -> void:
	if not DEBUG_DISABLED:
		print("[Menu] Network started, making network button visible")
	network_button.visible = true

func _on_netlink_status_loaded() -> void:
	if not DEBUG_DISABLED:
		print("[Menu] Netlink status loaded, checking network button visibility")
	_check_network_button_visibility()

func _check_network_button_visibility() -> void:
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.netlink_status.has("started"):
		if global_data.netlink_status["started"] == true:
			if not DEBUG_DISABLED:
				print("[Menu] Network is started, making network button visible")
			network_button.visible = true
		else:
			if not DEBUG_DISABLED:
				print("[Menu] Network is not started, keeping network button hidden")
			network_button.visible = false
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Netlink status not available or missing 'started' key")

func _on_sfx_volume_changed(volume: int):
	"""Handle SFX volume changes from Option scene.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	if not DEBUG_DISABLED:
		print("[Menu] SFX volume changed to: ", volume)
	_apply_sfx_volume(volume)

func _apply_sfx_volume(volume: int):
	"""Apply SFX volume level to audio.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	# Convert volume (0-10) to Godot's decibel scale
	# 0 = silence (mute), 10 = full volume (0dB)
	# We use approximately -40dB for silence and 0dB for maximum
	if volume <= 0:
		# Stop all SFX
		if background_music:
			background_music.volume_db = -80  # Effectively mute
		if not DEBUG_DISABLED:
			print("[Menu] Muted audio (volume=", volume, ")")
	else:
		# Map 1-10 to -40dB to 0dB
		# volume 1 = -40dB, volume 10 = 0dB
		var db = -40.0 + ((volume - 1) * (40.0 / 9.0))
		if background_music:
			background_music.volume_db = db
		if not DEBUG_DISABLED:
			print("[Menu] Set audio volume_db to ", db, " (volume level: ", volume, ")")
