extends Control

# Global variable for current language
static var current_language = "English"

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/SimplifiedChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/EnglishButton"
@onready var traditional_chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/TraditionalChineseButton"

# References to labels that need translation
@onready var tab_container = $"VBoxContainer/MarginContainer/tab_container"
@onready var description_label = $"VBoxContainer/MarginContainer/tab_container/About/Left/DescriptionLabel"
@onready var copyright_label = $"VBoxContainer/MarginContainer/tab_container/About/Left/CopyrightLabel"

@onready var language_buttons = []

func _ready():
	# Load saved settings
	load_settings()
	
	# Connect signals for language buttons
	if chinese_button:
		chinese_button.pressed.connect(_on_language_changed.bind("Chinese"))
	if japanese_button:
		japanese_button.pressed.connect(_on_language_changed.bind("Japanese"))
	if english_button:
		english_button.pressed.connect(_on_language_changed.bind("English"))
	if traditional_chinese_button:
		traditional_chinese_button.pressed.connect(_on_language_changed.bind("Traditional Chinese"))
	
	# Note: set_language_button_pressed() and update_ui_texts() will be called 
	# from the load_settings callback when the actual language is loaded
	
	# Initialize language buttons array
	language_buttons = [english_button, chinese_button, japanese_button, traditional_chinese_button]
	
	# Set tab_container focusable
	if tab_container:
		tab_container.focus_mode = Control.FOCUS_ALL
	
	# Set default focus to English button (will be updated when settings load)
	if english_button:
		english_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Option] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Option] WebSocketListener singleton not found!")

func _on_language_changed(language: String):
	current_language = language
	set_locale_from_language(language)
	save_settings()
	update_ui_texts()
	print("Language changed to: ", language)

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
		tab_container.set_tab_title(1, tr("about"))
	if description_label:
		description_label.text = tr("description")
	if copyright_label:
		copyright_label.text = tr("copyright")

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
	
	if response_code == 200:
		# Parse existing settings
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(body_str)
		if error == OK:
			var data = json.data
			var settings = data.get("content", "{}")
			var settings_json = JSON.new()
			var settings_error = settings_json.parse(settings)
			if settings_error == OK:
				settings_data = settings_json.data
				print("Loaded existing settings: ", settings_data)
			else:
				print("Failed to parse existing settings JSON, using empty dict")
		else:
			print("Failed to parse response JSON, using empty dict")
	else:
		print("Failed to load existing settings (", response_code, "), creating new settings")
	
	# Update only the language field
	settings_data["language"] = current_language
	print("Updated settings with language: ", settings_data)
	
	# Save the merged settings
	var content = JSON.stringify(settings_data)
	http_service.save_game(_on_save_settings_callback, "settings", content)

func _on_save_settings_callback(_result, response_code, _headers, _body):
	if response_code == 200:
		print("Settings saved successfully")
	else:
		print("Failed to save settings: ", response_code)

func load_settings():
	var http_service = get_node("/root/HttpService")
	if http_service:
		http_service.load_game(_on_load_settings_callback, "settings")
	else:
		print("HttpService not found, using default")
		set_locale_from_language(current_language)
		set_language_button_pressed()
		update_ui_texts()
		set_focus_to_current_language()

func _on_load_settings_callback(_result, response_code, _headers, body):
	if response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var error = json.parse(body_str)
		if error == OK:
			var data = json.data
			var settings = data.get("content", "{}")
			var settings_json = JSON.new()
			var settings_error = settings_json.parse(settings)
			if settings_error == OK:
				var settings_data = settings_json.data
				current_language = settings_data.get("language", "English")
				set_locale_from_language(current_language)
				print("Loaded language: ", current_language)
				# Update button states and UI to reflect the loaded language
				set_language_button_pressed()
				update_ui_texts()
				# Set focus to the correct language button
				set_focus_to_current_language()
			else:
				print("Failed to parse settings JSON")
				set_locale_from_language(current_language)
				set_language_button_pressed()
				update_ui_texts()
				set_focus_to_current_language()
		else:
			print("Failed to parse response JSON")
			set_locale_from_language(current_language)
			set_language_button_pressed()
			update_ui_texts()
			set_focus_to_current_language()
	else:
		print("Failed to load settings: ", response_code)
		set_locale_from_language(current_language)
		set_language_button_pressed()
		update_ui_texts()
		set_focus_to_current_language()

# Function to get current language (can be called from other scripts)
static func get_current_language() -> String:
	return current_language

func _on_menu_control(directive: String):
	print("[Option] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down":
			if tab_container and tab_container.current_tab == 0:
				print("[Option] Navigation: ", directive)
				navigate_buttons(directive)
		"left", "right":
			print("[Option] Tab switch: ", directive)
			switch_tab(directive)
		"enter":
			print("[Option] Enter pressed")
			press_focused_button()
		"back", "homepage":
			print("[Option] ", directive, " - navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
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
		return
	if direction == "up":
		current_index = (current_index - 1 + language_buttons.size()) % language_buttons.size()
	else:  # down
		current_index = (current_index + 1) % language_buttons.size()
	if language_buttons[current_index]:
		language_buttons[current_index].grab_focus()
		print("[Option] Focus moved to ", language_buttons[current_index].name)

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
	else:  # About
		tab_container.grab_focus()
	print("[Option] Switched to tab: ", tab_container.get_tab_title(current))
