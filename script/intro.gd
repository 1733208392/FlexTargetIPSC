extends Control

@onready var start_button = $BottomContainer/StartButton
@onready var drill_history_button = $TopBar/DrillHistoryButton
@onready var game_rule_image = $CenterContainer/GameRuleContainer/GameRuleImage

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	drill_history_button.pressed.connect(_on_drill_history_pressed)
	
	# Set start button as default focus
	start_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Intro] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Intro] WebSocketListener singleton not found!")
	
	# Add some visual polish
	setup_ui_styles()

func setup_ui_styles():
	# Style the start button
	if start_button:
		start_button.add_theme_color_override("font_color", Color.WHITE)
		start_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
		start_button.add_theme_color_override("font_hover_color", Color.CYAN)
	
	# Style the drill history button
	if drill_history_button:
		drill_history_button.add_theme_color_override("font_color", Color.WHITE)
		drill_history_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
		drill_history_button.add_theme_color_override("font_hover_color", Color.CYAN)

func _on_start_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Intro] Sending start game HTTP request...")
		http_service.start_game(_on_start_response)
	else:
		print("[Intro] HttpService singleton not found!")
		get_tree().change_scene_to_file("res://scene/drills.tscn")

func _on_start_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		print("[Intro] Start game success, changing scene.")
		get_tree().change_scene_to_file("res://scene/drills.tscn")
	else:
		print("[Intro] Start game failed or invalid response.")

func _on_drill_history_pressed():
	# Call the HTTP service to start the game (assuming drill history needs game start)
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Intro] Sending start game HTTP request for drill history...")
		http_service.start_game(_on_drill_history_response)
	else:
		print("[Intro] HttpService singleton not found!")
		get_tree().change_scene_to_file("res://scene/history.tscn")

func _on_drill_history_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Drill history start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		print("[Intro] Drill history start game success, changing scene.")
		get_tree().change_scene_to_file("res://scene/history.tscn")
	else:
		print("[Intro] Drill history start game failed or invalid response.")

func _on_menu_control(directive: String):
	print("[Intro] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down", "left", "right":
			print("[Intro] Navigation: ", directive)
			navigate_buttons()
		"enter":
			print("[Intro] Enter pressed")
			press_focused_button()
		"back", "homepage":
			print("[Intro] ", directive, " - navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		"volume_up":
			print("[Intro] Volume up")
			volume_up()
		"volume_down":
			print("[Intro] Volume down")
			volume_down()
		"power":
			print("[Intro] Power off")
			power_off()
		_:
			print("[Intro] Unknown directive: ", directive)

func volume_up():
	# Call the HTTP service to increase the volume
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Intro] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		print("[Intro] HttpService singleton not found!")

func _on_volume_up_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Volume up HTTP response:", result, response_code, body_str)

func volume_down():
	# Call the HTTP service to decrease the volume
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Intro] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		print("[Intro] HttpService singleton not found!")

func _on_volume_down_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Volume down HTTP response:", result, response_code, body_str)

func power_off():
	# Call the HTTP service to power off the system
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Intro] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		print("[Intro] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Shutdown HTTP response:", result, response_code, body_str)

func navigate_buttons():
	# Toggle focus between start button and drill history button
	if start_button.has_focus():
		drill_history_button.grab_focus()
		print("[Intro] Focus moved to drill history button")
	else:
		start_button.grab_focus()
		print("[Intro] Focus moved to start button")

func press_focused_button():
	# Simulate pressing the currently focused button
	if start_button.has_focus():
		print("[Intro] Simulating start button press")
		_on_start_pressed()
	elif drill_history_button.has_focus():
		print("[Intro] Simulating drill history button press")
		_on_drill_history_pressed()
	else:
		print("[Intro] No button has focus")
