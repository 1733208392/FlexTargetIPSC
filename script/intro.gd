extends Control

@onready var start_button = $StartButton
@onready var main_text = $CenterContainer/ContentVBox/MainText
@onready var prev_button = $CenterContainer/ContentVBox/NavigationContainer/PrevButton
@onready var next_button = $CenterContainer/ContentVBox/NavigationContainer/NextButton
@onready var page_indicator = $CenterContainer/ContentVBox/NavigationContainer/PageIndicator

var current_page = 0
var pages = [
	{
		"title": "SCORING RULES",
		"content": """[center][color=WHITE][b]SCORING RULES[/b][/color][/center]
[color=WHITE][b]Target Zones:[/b][/color]
• [color=WHITE]Alpha (A): 5 pts[/color]
• [color=WHITE]Charlie (C): 2 pts[/color]
• [color=WHITE]Delta (D): 1 pt[/color]
• [color=WHITE]Miss: 1 pt[/color]

[color=WHITE][b]Special Targets:[/b][/color]
• [color=WHITE]Steel Plates: 5 pts[/color]
• [color=WHITE]Paddles: 5 pts[/color]
• [color=WHITE]No-Shoot: -10 pts[/color]"""
	},
	{
		"title": "PENALTY RULES",
		"content": """[center][color=WHITE][b]PENALTY RULES[/b][/color][/center]

[color=WHITE][b]Time Penalties:[/b][/color]
• [color=WHITE]Miss: +10 sec[/color]
• [color=WHITE]No-Shoot Hit: +10 sec[/color]
• [color=WHITE]Procedural: +10 sec[/color]

[color=WHITE][b]Score Penalties:[/b][/color]
• [color=WHITE]No-Shoot Hit: -10 pts[/color]
• [color=WHITE]Disqualification: 0 pts[/color]

[color=WHITE][b]Safety First:[/b][/color]
• [color=WHITE]Identify targets before shooting[/color]
• [color=WHITE]Avoid hitting hostages[/color]"""
	},
	{
		"title": "TIMER SYSTEM",
		"content": """[center][color=WHITE][b]TIMER SYSTEM[/b][/color][/center]

[color=WHITE][b]Game Start:[/b][/color]
• Game begins with [color=WHITE]BEEP[/color] sound
• [color=WHITE]3-5 second[/color] random delay
• From standby to beep

[color=WHITE][b]Timing:[/b][/color]
• Timer starts on beep
• Timer stops when stage complete
• Total time includes penalties

[color=WHITE][b]Ready Position:[/b][/color]
• Wait for the beep signal
• Stay focused and prepared"""
	},
	{
		"title": "TARGET RULES",
		"content": """[center][color=WHITE][b]TARGET RULES[/b][/color][/center]

[color=WHITE][b]Stage Completion:[/b][/color]
• [color=WHITE]2 shots[/color] on paper targets
• [color=WHITE]Knock down all[/color] steel targets
• Move to next target spot

[color=WHITE][b]Target Types:[/b][/color]
• Paper targets (IPSC zones)
• Steel plates and poppers
• Hostage targets (no-shoot)

[color=WHITE][b]Engagement Rules:[/b][/color]
• Shoot until requirements met
• Proceed to next position"""
	},
	{
		"title": "HIT FACTOR",
		"content": """[center][color=WHITE][b]HIT FACTOR[/b][/color][/center]

[color=WHITE][b]Hit Factor Formula:[/b][/color]

[center][color=WHITE][b]HF = Score ÷ Total Time[/b][/color][/center]

[color=WHITE][b]Leaderboard:[/b][/color]
• [color=WHITE]Highest Hit Factor[/color] wins
• Better position in rankings
• Rewards accuracy + speed

[center][color=WHITE][b]High HF = Champion![/b][/color][/center]

[color=WHITE][b]Strategy:[/b][/color]
• Balance speed and accuracy
• Minimize penalties"""
	}
]

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# Initialize pagination
	update_page_display()
	
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

func update_page_display():
	# Update main text content
	main_text.text = pages[current_page].content
	
	# Update page indicator
	page_indicator.text = str(current_page + 1) + " / " + str(pages.size())
	
	# Update button states
	prev_button.disabled = (current_page == 0)
	next_button.disabled = (current_page == pages.size() - 1)

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_page_display()
		print("[Intro] Previous page: ", current_page + 1)

func _on_next_pressed():
	if current_page < pages.size() - 1:
		current_page += 1
		update_page_display()
		print("[Intro] Next page: ", current_page + 1)
	
	# Add some visual polish
	setup_ui_styles()

func setup_ui_styles():
	# Style the start button
	if start_button:
		start_button.add_theme_color_override("font_color", Color.WHITE)
		start_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
		start_button.add_theme_color_override("font_hover_color", Color.CYAN)

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
	# Enhanced navigation for prev/next and start buttons
	if prev_button.has_focus():
		next_button.grab_focus()
		print("[Intro] Focus moved to next button")
	elif next_button.has_focus():
		start_button.grab_focus()
		print("[Intro] Focus moved to start button")
	elif start_button.has_focus():
		prev_button.grab_focus()
		print("[Intro] Focus moved to prev button")
	else:
		prev_button.grab_focus()
		print("[Intro] Focus moved to prev button")

func press_focused_button():
	# Simulate pressing the currently focused button
	if start_button.has_focus():
		print("[Intro] Simulating start button press")
		_on_start_pressed()
	elif prev_button.has_focus():
		print("[Intro] Simulating prev button press")
		_on_prev_pressed()
	elif next_button.has_focus():
		print("[Intro] Simulating next button press")
		_on_next_pressed()
	else:
		print("[Intro] No button has focus")
