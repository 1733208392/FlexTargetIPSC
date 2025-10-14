extends Node2D

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

@onready var ipsc = $IPSC
@onready var shot_labels = []
@onready var clear_button = $CanvasLayer/Control/BottomContainer/CustomButton

var shot_times = []
var drill_started = false  # Track if drill has been started
var game_start_requested = false  # Prevent multiple requests

func _ready():
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Initialize but don't start the drill yet
	if DEBUG_LOGGING:
		print("[Bootcamp] Initializing bootcamp, waiting for HTTP start game response...")
	
	# Disable disappearing for bootcamp
	ipsc.max_shots = 1000
	
	# Temporarily disable target interaction until drill starts
	ipsc.input_pickable = false
	if DEBUG_LOGGING:
		print("[Bootcamp] Target disabled until game start response received")
	
	# Connect to ipsc target_hit signal
	ipsc.target_hit.connect(_on_target_hit)
	
	# Connect clear button
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	else:
		if DEBUG_LOGGING:
			print("ERROR: ClearButton not found!")
	
	# Get all shot labels
	for i in range(1, 11):
		var label = get_node("CanvasLayer/Control/ShotIntervalsOverlay/Shot" + str(i))
		if label:
			shot_labels.append(label)
			label.text = ""
		else:
			if DEBUG_LOGGING:
				print("ERROR: Shot" + str(i) + " not found!")
	
	# Update UI texts with translations
	update_ui_texts()
	
	# Set clear button as default focus
	clear_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_LOGGING:
			print("[Bootcamp] Connecting to WebSocketListener.menu_control signal")
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] WebSocketListener singleton not found!")
	
	# Send HTTP request to start the game and wait for response
	start_bootcamp_drill()

func start_bootcamp_drill():
	"""Send HTTP start game request and wait for OK response before starting drill"""
	if game_start_requested:
		if DEBUG_LOGGING:
			print("[Bootcamp] Game start already requested, ignoring duplicate call")
		return
	
	game_start_requested = true
	if DEBUG_LOGGING:
		print("[Bootcamp] Sending start game HTTP request for bootcamp...")
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		# Send start game request with bootcamp mode
		http_service.start_game(_on_start_game_response, "bootcamp")
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] ERROR: HttpService singleton not found! Starting drill anyway...")
		_start_drill_immediately()

func _on_start_game_response(result, response_code, headers, body):
	"""Handle the HTTP start game response"""
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
		print("[Bootcamp] Start game HTTP response:", result, response_code, body_str)
	
	# Parse the JSON response
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if DEBUG_LOGGING:
			print("[Bootcamp] Start game SUCCESS - starting bootcamp drill")
		_start_drill_immediately()
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] Start game FAILED or invalid response - starting drill anyway")
		_start_drill_immediately()

func _start_drill_immediately():
	"""Actually start the bootcamp drill"""
	if drill_started:
		if DEBUG_LOGGING:
			print("[Bootcamp] Drill already started, ignoring duplicate call")
		return
	
	drill_started = true
	if DEBUG_LOGGING:
		print("[Bootcamp] Bootcamp drill officially started!")
	
	# Enable target interactions (they might be disabled initially)
	if ipsc:
		ipsc.input_pickable = true
		if DEBUG_LOGGING:
			print("[Bootcamp] Target enabled for shooting practice")
	
	# Any additional drill initialization can go here
	# For bootcamp, the drill is already "active" since it's free practice

func _on_target_hit(_zone: String, _points: int, _hit_position: Vector2):
	# Only process hits if drill has started
	if not drill_started:
		if DEBUG_LOGGING:
			print("[Bootcamp] Target hit before drill started - ignoring")
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	shot_times.append(current_time)
	
	if shot_times.size() > 1:
		var time_diff = shot_times[-1] - shot_times[-2]
		_update_shot_list("+%.2fs" % time_diff)
	else:
		_update_shot_list("First shot")

func _update_shot_list(new_text: String):
	# Shift the list
	for i in range(shot_labels.size() - 1, 0, -1):
		shot_labels[i].text = shot_labels[i-1].text
	shot_labels[0].text = new_text

func _on_clear_pressed():
	# Clear shot list
	for label in shot_labels:
		label.text = ""
	shot_times.clear()
	
	# Clear bullet holes - get all children and check if they're bullet holes
	var children_to_remove = []
	for child in ipsc.get_children():
		# Check if it's a bullet hole (Sprite2D with bullet hole script)
		if child is Sprite2D and child.has_method("set_hole_position"):
			children_to_remove.append(child)
	
	# Remove all bullet holes
	for bullet_hole in children_to_remove:
		bullet_hole.queue_free()
		if DEBUG_LOGGING:
			print("Removed bullet hole: ", bullet_hole.name)

func _on_menu_control(directive: String):
	if DEBUG_LOGGING:
		print("[Bootcamp] Received menu_control signal with directive: ", directive)
	match directive:
		"enter":
			if DEBUG_LOGGING:
				print("[Bootcamp] Enter pressed")
			_on_clear_pressed()
		"back", "homepage":
			if DEBUG_LOGGING:
				print("[Bootcamp] ", directive, " - navigating to main menu")
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				if DEBUG_LOGGING:
					print("[Bootcamp] Warning: Node not in tree, cannot change scene")
		"volume_up":
			if DEBUG_LOGGING:
				print("[Bootcamp] Volume up")
			volume_up()
		"volume_down":
			if DEBUG_LOGGING:
				print("[Bootcamp] Volume down")
			volume_down()
		"power":
			if DEBUG_LOGGING:
				print("[Bootcamp] Power off")
			power_off()
		_:
			if DEBUG_LOGGING:
				print("[Bootcamp] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
			print("[Bootcamp] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] HttpService singleton not found!")

func _on_volume_up_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
		print("[Bootcamp] Volume up HTTP response:", result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
			print("[Bootcamp] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] HttpService singleton not found!")

func _on_volume_down_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
		print("[Bootcamp] Volume down HTTP response:", result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
			print("[Bootcamp] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
		print("[Bootcamp] Shutdown HTTP response:", result, response_code, body_str)

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if DEBUG_LOGGING:
			print("[Bootcamp] Loaded language from GlobalData: ", language)
	else:
		if DEBUG_LOGGING:
			print("[Bootcamp] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")

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
	if DEBUG_LOGGING:
		print("[Bootcamp] Set locale to: ", locale)

func update_ui_texts():
	# Update static UI elements with translations
	var intervals_label = get_node_or_null("CanvasLayer/Control/ShotIntervalsOverlay/IntervalsLabel")
	
	if intervals_label:
		intervals_label.text = get_localized_shots_text()
	
	if clear_button:
		clear_button.text = tr("clear")

func get_localized_shots_text() -> String:
	# Since there's no specific "shots" translation key, create localized text based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "射击"
		"zh_TW":
			return "射擊"
		"ja":
			return "ショット"
		_:
			return "Shots"
