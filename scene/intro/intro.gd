extends Control

@onready var start_button = $StartButton
@onready var main_text = $CenterContainer/ContentVBox/MainText
@onready var prev_button = $CenterContainer/ContentVBox/NavigationContainer/PrevButton
@onready var next_button = $CenterContainer/ContentVBox/NavigationContainer/NextButton
@onready var page_indicator = $CenterContainer/ContentVBox/NavigationContainer/PageIndicator
@onready var title_label = $TitleLabel
@onready var history_button = get_node_or_null("TopBar/HistoryButton")

var current_page = 0
var pages = []

func load_language_setting():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[Intro] Loaded language from GlobalData: ", language)
		call_deferred("initialize_pages_and_ui")
	else:
		print("[Intro] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
		call_deferred("initialize_pages_and_ui")

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
	print("[Intro] Set locale to: ", locale)

func initialize_pages_and_ui():
	# Initialize pages with translated content
	pages = []
	
	# Get translated content for each page
	var translation_keys = ["score_rule", "panelty_rule", "timer_system", "drill_rule", "hit_factor_rule"]
	
	for key in translation_keys:
		var translated_content = tr(key)
		print("[Intro] Raw translation for ", key, ": ", translated_content)
		
		# Try to parse as JSON first
		var parsed_json = JSON.parse_string(translated_content)
		if parsed_json != null and typeof(parsed_json) == TYPE_DICTIONARY and parsed_json.has("content"):
			# Successfully parsed JSON - use only the content
			pages.append({
				"title": parsed_json.get("title", key.to_upper().replace("_", " ")),
				"content": parsed_json.content
			})
			print("[Intro] Successfully parsed JSON for ", key)
		else:
			# JSON parsing failed, try to extract content manually
			print("[Intro] JSON parsing failed for ", key, ", trying manual extraction")
			
			# Try to extract content from the string manually
			var content = extract_content_from_string(translated_content)
			pages.append({
				"title": key.to_upper().replace("_", " "),
				"content": content
			})
	
	# Update UI texts
	update_ui_texts()
	
	# Initialize pagination
	update_page_display()

func extract_content_from_string(text: String) -> String:
	# Try to extract content from JSON-like string manually
	var content_start = text.find('"content"')
	if content_start == -1:
		content_start = text.find("\"content\"")
	if content_start == -1:
		return text  # Return original if no content field found
	
	# Find the start of the content value
	var colon_pos = text.find(":", content_start)
	if colon_pos == -1:
		return text
	
	# Find the opening quote of the content value
	var quote_start = text.find('"', colon_pos)
	if quote_start == -1:
		return text
	
	# Find the closing quote (look for last quote before closing brace)
	var brace_pos = text.rfind("}")
	if brace_pos == -1:
		brace_pos = text.length()
	
	var quote_end = text.rfind('"', brace_pos)
	if quote_end == -1 or quote_end <= quote_start:
		return text
	
	# Extract the content between quotes
	var content = text.substr(quote_start + 1, quote_end - quote_start - 1)
	
	# Clean up escaped quotes
	content = content.replace('""', '"')
	
	return content

func update_ui_texts():
	# Update button texts and title
	if title_label:
		title_label.text = tr("rules")
	if prev_button:
		prev_button.text = tr("prev")
	if next_button:
		next_button.text = tr("next")
	if start_button:
		start_button.text = tr("start")
	if history_button:
		history_button.text = tr("leaderboard")

func _ready():
	# Load and apply current language setting first
	load_language_setting()
	
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
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
	# Safety check: ensure pages exist and current_page is valid
	if pages.is_empty() or current_page < 0 or current_page >= pages.size():
		print("[Intro] Invalid page state: pages.size()=", pages.size(), " current_page=", current_page)
		return
	
	# Update main text content
	var current_page_data = pages[current_page]
	if current_page_data != null and typeof(current_page_data) == TYPE_DICTIONARY:
		if current_page_data.has("content"):
			main_text.text = current_page_data.content
		else:
			main_text.text = tr("content_not_available")
			print("[Intro] Page ", current_page, " missing content field")
	else:
		main_text.text = tr("page_data_invalid")
		print("[Intro] Page ", current_page, " has invalid data: ", current_page_data)
	
	# Update page indicator
	if page_indicator:
		page_indicator.text = str(current_page + 1) + " / " + str(pages.size())
	
	# Update button states
	if prev_button:
		prev_button.disabled = (current_page == 0)
	if next_button:
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

func _on_start_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Start game HTTP response:", _result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		print("[Intro] Start game success, changing scene.")
		get_tree().change_scene_to_file("res://scene/drills.tscn")
	else:
		print("[Intro] Start game failed or invalid response.")

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
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
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
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

func _on_volume_up_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Volume up HTTP response:", _result, response_code, body_str)

func volume_down():
	# Call the HTTP service to decrease the volume
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Intro] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		print("[Intro] HttpService singleton not found!")

func _on_volume_down_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Intro] Volume down HTTP response:", _result, response_code, body_str)

func power_off():
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.set_alert_text(tr("power_off_alert"))
	add_child(dialog)

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

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
