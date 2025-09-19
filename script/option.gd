extends Control

# Global variable for current language
static var current_language = "English"

# Global variable for current drill sequence
static var current_drill_sequence = "Fixed"

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/SimplifiedChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/EnglishButton"
@onready var traditional_chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/TraditionalChineseButton"

# References to labels that need translation
@onready var tab_container = $"VBoxContainer/MarginContainer/tab_container"
@onready var description_label = $"VBoxContainer/MarginContainer/tab_container/About/Left/MarginContainer/DescriptionLabel"
@onready var copyright_label = $"CopyrightLabel"

# References to drill buttons
@onready var random_sequence_button = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/RandomSequenceButton"
@onready var fixed_sequence_button = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/FixedSequenceButton"

@onready var language_buttons = []

@onready var drill_buttons = []

func _ready():
	# Load saved settings from GlobalData
	load_settings_from_global_data()
	
	# Connect signals for language buttons
	if chinese_button:
		chinese_button.pressed.connect(_on_language_changed.bind("Chinese"))
	if japanese_button:
		japanese_button.pressed.connect(_on_language_changed.bind("Japanese"))
	if english_button:
		english_button.pressed.connect(_on_language_changed.bind("English"))
	if traditional_chinese_button:
		traditional_chinese_button.pressed.connect(_on_language_changed.bind("Traditional Chinese"))
	
	# Connect signals for drill sequence buttons
	if random_sequence_button:
		random_sequence_button.pressed.connect(_on_drill_sequence_changed.bind("Random"))
	if fixed_sequence_button:
		fixed_sequence_button.pressed.connect(_on_drill_sequence_changed.bind("Fixed"))
	
	# Initialize language buttons array
	# Order: Traditional Chinese (0), Chinese (1), Japanese (2), English (3)
	language_buttons = [traditional_chinese_button, chinese_button, japanese_button, english_button]
	
	# Initialize drill buttons array
	drill_buttons = [random_sequence_button, fixed_sequence_button]
	
	# Debug: Check which buttons are properly loaded
	print("[Option] Language buttons initialization:")
	for i in range(language_buttons.size()):
		if language_buttons[i]:
			print("[Option]   Button ", i, ": ", language_buttons[i].name, " - OK")
		else:
			print("[Option]   Button ", i, ": NULL - MISSING!")
	
	# Set tab_container focusable
	if tab_container:
		tab_container.focus_mode = Control.FOCUS_ALL
	
	# Focus will be set by load_settings_from_global_data() based on current language
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Option] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Option] WebSocketListener singleton not found!")

func _on_language_changed(language: String):
	current_language = language
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["language"] = current_language
		print("[Option] Immediately updated GlobalData.settings_dict[language] to: ", current_language)
	else:
		print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	set_locale_from_language(language)
	save_settings()
	update_ui_texts()
	print("Language changed to: ", language)

func _on_drill_sequence_changed(sequence: String):
	print("[Option] Drill sequence change requested: ", sequence)
	print("[Option] Current drill_sequence before change: ", current_drill_sequence)
	current_drill_sequence = sequence
	print("[Option] Current drill_sequence after change: ", current_drill_sequence)
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["drill_sequence"] = current_drill_sequence
		print("[Option] Immediately updated GlobalData.settings_dict[drill_sequence] to: ", current_drill_sequence)
	else:
		print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()
	set_drill_button_pressed()
	print("[Option] Drill sequence changed to: ", sequence)

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
	TranslationServer.set_locale(locale)

func set_language_button_pressed():
	# First reset all buttons
	if english_button:
		english_button.button_pressed = false
	if chinese_button:
		chinese_button.button_pressed = false
	if traditional_chinese_button:
		traditional_chinese_button.button_pressed = false
	if japanese_button:
		japanese_button.button_pressed = false
	
	# Then set the current language button as pressed
	match current_language:
		"Chinese":
			if chinese_button:
				chinese_button.button_pressed = true
		"Traditional Chinese":
			if traditional_chinese_button:
				traditional_chinese_button.button_pressed = true
		"Japanese":
			if japanese_button:
				japanese_button.button_pressed = true
		"English":
			if english_button:
				english_button.button_pressed = true

func set_drill_button_pressed():
	# First reset all drill buttons
	if random_sequence_button:
		random_sequence_button.button_pressed = false
	if fixed_sequence_button:
		fixed_sequence_button.button_pressed = false
	
	# Then set the current drill sequence button as pressed
	match current_drill_sequence:
		"Random":
			if random_sequence_button:
				random_sequence_button.button_pressed = true
		"Fixed":
			if fixed_sequence_button:
				fixed_sequence_button.button_pressed = true
		_:
			# Default to Fixed if invalid
			if fixed_sequence_button:
				fixed_sequence_button.button_pressed = true
			current_drill_sequence = "Fixed"

func set_focus_to_current_language():
	# Set focus to the button corresponding to the current language
	match current_language:
		"English":
			if english_button:
				english_button.grab_focus()
		"Chinese":
			if chinese_button:
				chinese_button.grab_focus()
		"Traditional Chinese":
			if traditional_chinese_button:
				traditional_chinese_button.grab_focus()
		"Japanese":
			if japanese_button:
				japanese_button.grab_focus()
		_:
			# Default to English if unknown language
			if english_button:
				english_button.grab_focus()

func update_ui_texts():
	if tab_container:
		tab_container.set_tab_title(0, tr("languages"))
		tab_container.set_tab_title(1, tr("drill"))
		tab_container.set_tab_title(2, tr("about"))
	if description_label:
		description_label.text = tr("description")
	if copyright_label:
		copyright_label.text = tr("copyright")
	if random_sequence_button:
		random_sequence_button.text = tr("random_sequence")
	if fixed_sequence_button:
		fixed_sequence_button.text = tr("fixed_sequence")

func save_settings():
	# First load current settings to preserve other fields
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("Loading current settings before saving language...")
		http_service.load_game(_on_load_before_save_callback, "settings")
	else:
		print("HttpService not found!")

func _on_load_before_save_callback(_result, response_code, _headers, body):
	var http_service = get_node("/root/HttpService")
	if not http_service:
		print("HttpService not found!")
		return
		
	var settings_data = {}
	
	# Try to get existing settings from HTTP first
	if response_code == 200:
		# Parse existing settings
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(body_str)
		if error == OK:
			var data = json.data
			var settings = data.get("data", "{}")
			var settings_json = JSON.new()
			var settings_error = settings_json.parse(settings)
			if settings_error == OK:
				settings_data = settings_json.data
				print("Loaded existing settings from HTTP: ", settings_data)
			else:
				print("Failed to parse existing settings JSON from HTTP")
		else:
			print("Failed to parse HTTP response JSON")
	else:
		print("Failed to load existing settings from HTTP (", response_code, ")")
	
	# If HTTP failed or parsed empty, fallback to GlobalData.settings_dict
	if settings_data.size() == 0:
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data and global_data.settings_dict.size() > 0:
			settings_data = global_data.settings_dict.duplicate()
			print("Using GlobalData.settings_dict as fallback: ", settings_data)
		else:
			print("GlobalData.settings_dict not available, creating minimal settings")
			# Create minimal settings with essential fields
			settings_data = {
				"language": "English",
				"drill_sequence": "Fixed",
				"http_service_url": "http://127.0.0.1",
				"websocket_url": "ws://127.0.0.1/websocket",
				"max_index": 1,
				"spots": ["ipsc_mini", "hostage", "2poppers", "3paddles", "ipsc_mini_rotation"],
				"target_rule": {
					"AZone": 5.0,
					"CZone": 2.0,
					"DZone": 1.0,
					"WhiteZone": -10.0,
					"miss": 1.0,
					"paddles": 5.0,
					"popper": 5.0
				}
			}
	
	# Update only the language field
	settings_data["language"] = current_language
	settings_data["drill_sequence"] = current_drill_sequence
	print("[Option] Updated settings with language: ", current_language, " and drill_sequence: ", current_drill_sequence)
	print("[Option] Full settings to save: ", settings_data)
	
	# Save the merged settings
	var content = JSON.stringify(settings_data)
	print("[Option] JSON content to save: ", content)
	http_service.save_game(_on_save_settings_callback, "settings", content)

func _on_save_settings_callback(_result, response_code, _headers, _body):
	print("[Option] Save settings callback - Response code: ", response_code)
	if response_code == 200:
		print("[Option] Settings saved successfully to HTTP server")
		# GlobalData is already updated immediately when settings change
		print("[Option] Settings save completed successfully")
	else:
		print("[Option] Failed to save settings to HTTP server: ", response_code)
		print("[Option] Response body: ", _body.get_string_from_utf8() if _body else "NO_BODY")
		print("[Option] Note: GlobalData has been updated locally, but HTTP save failed")

func load_settings_from_global_data():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		current_language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(current_language)
		print("[Option] Loaded language from GlobalData: ", current_language)
	else:
		print("[Option] GlobalData not found or no language setting, using default English")
		current_language = "English"
		set_locale_from_language(current_language)
	
	# Load drill sequence setting
	if global_data and global_data.settings_dict.has("drill_sequence"):
		current_drill_sequence = global_data.settings_dict.get("drill_sequence", "Fixed")
		if current_drill_sequence == "":
			current_drill_sequence = "Fixed"
		print("[Option] Loaded drill_sequence from GlobalData: ", current_drill_sequence)
	else:
		print("[Option] No drill_sequence setting, using default Fixed")
		current_drill_sequence = "Fixed"
	
	# Update UI to reflect the loaded settings
	set_language_button_pressed()
	set_drill_button_pressed()
	update_ui_texts()
	
	# Use call_deferred to ensure focus is set after all UI updates are complete
	call_deferred("set_focus_to_current_language")

# Function to get current language (can be called from other scripts)
static func get_current_language() -> String:
	return current_language

# Function to get current drill sequence (can be called from other scripts)
static func get_current_drill_sequence() -> String:
	return current_drill_sequence

func _on_menu_control(directive: String):
	print("[Option] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down":
			if tab_container and tab_container.current_tab == 0:
				print("[Option] Navigation: ", directive, " on Languages tab")
				navigate_buttons(directive)
			elif tab_container and tab_container.current_tab == 1:
				print("[Option] Navigation: ", directive, " on Drills tab")
				navigate_drill_buttons(directive)
			else:
				print("[Option] Navigation: ", directive, " ignored - not on navigable tab (current tab: ", tab_container.current_tab if tab_container else "N/A", ")")
		"left", "right":
			print("[Option] Tab switch: ", directive)
			switch_tab(directive)
		"enter":
			print("[Option] Enter pressed")
			press_focused_button()
		"back", "homepage":
			print("[Option] ", directive, " - navigating to main menu")
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu.tscn")
			else:
				print("[Option] Warning: Node not in tree, cannot change scene")
		"volume_up":
			print("[Option] Volume up")
			volume_up()
		"volume_down":
			print("[Option] Volume down")
			volume_down()
		"power":
			print("[Option] Power off")
			power_off()
		_:
			print("[Option] Unknown directive: ", directive)

func navigate_buttons(direction: String):
	var current_index = -1
	for i in range(language_buttons.size()):
		if language_buttons[i] and language_buttons[i].has_focus():
			current_index = i
			break
	if current_index == -1:
		# If no button has focus, start with the first valid button
		for i in range(language_buttons.size()):
			if language_buttons[i]:
				language_buttons[i].grab_focus()
				print("[Option] Focus set to first valid button: ", language_buttons[i].name)
				return
		return
	
	# Find the next valid button in the specified direction
	var attempts = 0
	var target_index = current_index
	while attempts < language_buttons.size():
		if direction == "up":
			target_index = (target_index - 1 + language_buttons.size()) % language_buttons.size()
		else:  # down
			target_index = (target_index + 1) % language_buttons.size()
		
		# Check if the target button exists and is valid
		if language_buttons[target_index] and language_buttons[target_index] != language_buttons[current_index]:
			language_buttons[target_index].grab_focus()
			print("[Option] Focus moved to ", language_buttons[target_index].name)
			return
		
		attempts += 1
	
	print("[Option] No other valid buttons found for navigation")

func navigate_drill_buttons(direction: String):
	var current_index = -1
	for i in range(drill_buttons.size()):
		if drill_buttons[i] and drill_buttons[i].has_focus():
			current_index = i
			break
	if current_index == -1:
		# If no button has focus, start with the first valid button
		for i in range(drill_buttons.size()):
			if drill_buttons[i]:
				drill_buttons[i].grab_focus()
				print("[Option] Focus set to first valid drill button: ", drill_buttons[i].name)
				return
		return
	
	# Find the next valid button in the specified direction
	var attempts = 0
	var target_index = current_index
	while attempts < drill_buttons.size():
		if direction == "up":
			target_index = (target_index - 1 + drill_buttons.size()) % drill_buttons.size()
		else:  # down
			target_index = (target_index + 1) % drill_buttons.size()
		
		# Check if the target button exists and is valid
		if drill_buttons[target_index] and drill_buttons[target_index] != drill_buttons[current_index]:
			drill_buttons[target_index].grab_focus()
			print("[Option] Focus moved to ", drill_buttons[target_index].name)
			return
		
		attempts += 1
	
	print("[Option] No other valid drill buttons found for navigation")

func press_focused_button():
	for button in language_buttons:
		if button and button.has_focus():
			var language = ""
			if button == english_button:
				language = "English"
			elif button == chinese_button:
				language = "Chinese"
			elif button == traditional_chinese_button:
				language = "Traditional Chinese"
			elif button == japanese_button:
				language = "Japanese"
			_on_language_changed(language)
			set_language_button_pressed()
			break
	
	# Handle drill buttons
	for button in drill_buttons:
		if button and button.has_focus():
			# Check if this is the only pressed button
			var other_button = fixed_sequence_button if button == random_sequence_button else random_sequence_button
			if button.button_pressed and (not other_button or not other_button.button_pressed):
				# Don't unpress if it's the only selected option
				print("[Option] Cannot unpress the only selected drill option")
				break
			else:
				# Toggle the button and determine new sequence
				button.button_pressed = !button.button_pressed
				var new_sequence = ""
				if button == random_sequence_button:
					new_sequence = "Random" if button.button_pressed else "Fixed"
				elif button == fixed_sequence_button:
					new_sequence = "Fixed" if button.button_pressed else "Random"
				
				print("[Option] Toggled drill button: ", button.name, " - New sequence: ", new_sequence)
				
				# Use the proper drill sequence change function to ensure settings are saved
				_on_drill_sequence_changed(new_sequence)
				break

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Option] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		print("[Option] HttpService singleton not found!")

func _on_volume_up_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Option] Volume up HTTP response:", _result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Option] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		print("[Option] HttpService singleton not found!")

func _on_volume_down_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Option] Volume down HTTP response:", _result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Option] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		print("[Option] HttpService singleton not found!")

func _on_shutdown_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Option] Shutdown HTTP response:", _result, response_code, body_str)

func switch_tab(direction: String):
	if not tab_container:
		return
	var current = tab_container.current_tab
	if direction == "right":
		current = (current + 1) % tab_container.get_tab_count()
	else:
		current = (current - 1 + tab_container.get_tab_count()) % tab_container.get_tab_count()
	tab_container.current_tab = current
	if current == 0:  # Languages
		# Grab focus on current language button
		match current_language:
			"English":
				if english_button:
					english_button.grab_focus()
			"Chinese":
				if chinese_button:
					chinese_button.grab_focus()
			"Traditional Chinese":
				if traditional_chinese_button:
					traditional_chinese_button.grab_focus()
			"Japanese":
				if japanese_button:
					japanese_button.grab_focus()
	elif current == 1:  # Drills
		# Grab focus on the pressed drill button or default to fixed
		if fixed_sequence_button and fixed_sequence_button.button_pressed:
			fixed_sequence_button.grab_focus()
		elif random_sequence_button:
			random_sequence_button.grab_focus()
		else:
			tab_container.grab_focus()
	else:  # About
		tab_container.grab_focus()
	print("[Option] Switched to tab: ", tab_container.get_tab_title(current))
