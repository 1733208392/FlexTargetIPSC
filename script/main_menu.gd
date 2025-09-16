extends Control

@onready var start_button = $VBoxContainer/ipsc
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
	print("[Menu] Updating UI texts with locale: ", TranslationServer.get_locale())
	print("[Menu] Translation for 'start': ", tr("start"))
	print("[Menu] Translation for 'boot_camp': ", tr("boot_camp"))
	print("[Menu] Translation for 'leaderboard': ", tr("leaderboard"))
	print("[Menu] Translation for 'options': ", tr("options"))
	print("[Menu] Translation for 'copyright': ", tr("copyright"))
	
	start_button.text = tr("start")
	bootcamp_button.text = tr("boot_camp")
	leaderboard_button.text = tr("leaderboard")
	option_button.text = tr("options")
	copyright_label.text = tr("copyright")
	
	print("[Menu] UI texts updated")

func _ready():
	# Load and apply current language setting
	load_language_setting()
	
	# Connect button signals
	focused_index = 0
	buttons = [
		start_button,
		bootcamp_button,
		leaderboard_button,
		option_button]
		
	buttons[focused_index].grab_focus()

	# Use get_node instead of Engine.has_singleton
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Menu] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Menu] WebSocketListener singleton not found!")

	start_button.pressed.connect(on_start_pressed)
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

func _on_start_response(result, response_code, headers, body):
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

func _on_bootcamp_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_bootcamp_response)
	else:
		print("[Menu] HttpService singleton not found!")
	print("Boot Camp button pressed - Load training mode")

func _on_bootcamp_response(result, response_code, headers, body):
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
		get_tree().change_scene_to_file("res://scene/option.tscn")
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

func _on_shutdown_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Menu] Shutdown HTTP response:", result, response_code, body_str)
