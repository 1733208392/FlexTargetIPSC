extends Control

# Global variable for current language
static var current_language = "English"

# Global variable for current drill sequence
static var current_drill_sequence = "Fixed"

# Global variables for auto restart settings
static var auto_restart_enabled = false
static var auto_restart_pause_time = 5  # Changed to store the selected time (5 or 10)

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/SimplifiedChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/EnglishButton"
@onready var traditional_chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/TraditionalChineseButton"

# References to labels that need translation
@onready var tab_container = $"VBoxContainer/MarginContainer/tab_container"
@onready var description_label = $"VBoxContainer/MarginContainer/tab_container/About/Left/MarginContainer/DescriptionLabel"
@onready var copyright_label = $"CopyrightLabel"

# References to drill button (single CheckButton)
@onready var random_sequence_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/RandomSequenceButton"

# References to auto restart controls
@onready var auto_restart_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartButton"
@onready var pause_5s_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartPauseContainer/Pause5sButton"
@onready var pause_10s_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartPauseContainer/Pause10sButton"
@onready var auto_restart_pause_container = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartPauseContainer"

@onready var language_buttons = []
@onready var wifi_button = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/WifiButton"
@onready var network_button = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/NetworkButton"
@onready var networking_buttons = []
@onready var content1_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row1/Content1"
@onready var content2_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row2/Content2"
@onready var content3_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row3/Content3"
@onready var content4_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row4/Content4"
@onready var content5_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row5/Content5"

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
	
	# Connect signals for drill sequence CheckButton
	if random_sequence_check:
		random_sequence_check.toggled.connect(_on_drill_sequence_toggled)
	
	# Connect signals for auto restart controls
	if auto_restart_check:
		auto_restart_check.toggled.connect(_on_auto_restart_toggled)
	if pause_5s_check:
		pause_5s_check.toggled.connect(_on_pause_time_changed.bind(5))
	if pause_10s_check:
		pause_10s_check.toggled.connect(_on_pause_time_changed.bind(10))
	
	# Initialize language buttons array
	# Order: Traditional Chinese (0), Chinese (1), Japanese (2), English (3)
	language_buttons = [traditional_chinese_button, chinese_button, japanese_button, english_button]
	
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

	# Initialize networking buttons array (wifi, network)
	networking_buttons = []
	if wifi_button:
		networking_buttons.append(wifi_button)
	if network_button:
		networking_buttons.append(network_button)

	print("[Option] Networking buttons initialization:")
	for i in range(networking_buttons.size()):
		if networking_buttons[i]:
			print("[Option]   Net Button ", i, ": ", networking_buttons[i].name, " - OK")
		else:
			print("[Option]   Net Button ", i, ": NULL - MISSING!")

	# Connect wifi button pressed to open overlay (also handled by press_focused_button)
	if wifi_button:
		wifi_button.pressed.connect(_on_wifi_pressed)
	
	# Focus will be set by load_settings_from_global_data() based on current language
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Option] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Option] WebSocketListener singleton not found!")

	# Listen for netlink status updates from GlobalData
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		var cb = Callable(self, "_on_netlink_status_loaded")
		if not global_data.is_connected("netlink_status_loaded", cb):
			global_data.connect("netlink_status_loaded", cb)
			print("[Option] Connected to GlobalData.netlink_status_loaded signal")
		else:
			print("[Option] Already connected to GlobalData.netlink_status_loaded signal")

		# Immediate-populate fallback: if GlobalData already has netlink_status populated, update UI now
		if global_data.netlink_status and typeof(global_data.netlink_status) == TYPE_DICTIONARY and global_data.netlink_status.size() > 0:
			print("[Option] GlobalData.netlink_status already present at _ready, populating UI immediately")
			_on_netlink_status_loaded()
	else:
		print("[Option] GlobalData singleton not found; cannot listen for netlink status")

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

func _on_drill_sequence_toggled(button_pressed: bool):
	var sequence = "Random" if button_pressed else "Fixed"
	print("[Option] Drill sequence toggled to: ", sequence)
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

func _on_auto_restart_toggled(button_pressed: bool):
	print("[Option] Auto restart toggled to: ", button_pressed)
	auto_restart_enabled = button_pressed
	
	# Show/hide pause time container based on auto restart state
	if auto_restart_pause_container:
		auto_restart_pause_container.visible = button_pressed
	
	# Enable/disable pause time buttons based on auto restart state
	if pause_5s_check:
		pause_5s_check.disabled = !button_pressed
	if pause_10s_check:
		pause_10s_check.disabled = !button_pressed
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["auto_restart"] = auto_restart_enabled
		print("[Option] Immediately updated GlobalData.settings_dict[auto_restart] to: ", auto_restart_enabled)
	else:
		print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

func _on_pause_time_changed(selected_time: int):
	print("[Option] Pause time changed to: ", selected_time)
	auto_restart_pause_time = selected_time
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["auto_restart_pause_time"] = auto_restart_pause_time
		print("[Option] Immediately updated GlobalData.settings_dict[auto_restart_pause_time] to: ", auto_restart_pause_time)
	else:
		print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

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
	# Set CheckButton state: checked = Random, unchecked = Fixed
	if random_sequence_check:
		random_sequence_check.button_pressed = (current_drill_sequence == "Random")

func set_auto_restart_button_pressed():
	# Set CheckButton state for auto restart
	if auto_restart_check:
		auto_restart_check.button_pressed = auto_restart_enabled
		# Show/hide pause time container based on auto restart state
		if auto_restart_pause_container:
			auto_restart_pause_container.visible = auto_restart_enabled
		# Set pause time button states based on auto restart state and selected time
		if pause_5s_check:
			pause_5s_check.disabled = !auto_restart_enabled
			pause_5s_check.button_pressed = (auto_restart_enabled and auto_restart_pause_time == 5)
		if pause_10s_check:
			pause_10s_check.disabled = !auto_restart_enabled
			pause_10s_check.button_pressed = (auto_restart_enabled and auto_restart_pause_time == 10)

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
		# New tab order: 0 Networking, 1 Languages, 2 Drills, 3 About
		tab_container.set_tab_title(0, tr("networking"))
		tab_container.set_tab_title(1, tr("languages"))
		tab_container.set_tab_title(2, tr("drill"))
		tab_container.set_tab_title(3, tr("about"))
	if description_label:
		description_label.text = tr("description")
	if copyright_label:
		copyright_label.text = tr("copyright")
	if random_sequence_check:
		random_sequence_check.text = tr("random_sequence")

func save_settings():
	# Save settings directly using current GlobalData
	var http_service = get_node("/root/HttpService")
	if not http_service:
		print("HttpService not found!")
		return
	
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data or global_data.settings_dict.size() == 0:
		print("GlobalData not available, cannot save settings")
		return
	
	var settings_data = global_data.settings_dict.duplicate()
	var content = JSON.stringify(settings_data)
	print("[Option] Saving settings directly: ", settings_data)
	
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
	
	# Load auto restart settings
	if global_data and global_data.settings_dict.has("auto_restart"):
		auto_restart_enabled = global_data.settings_dict.get("auto_restart", false)
		print("[Option] Loaded auto_restart from GlobalData: ", auto_restart_enabled)
	else:
		print("[Option] No auto_restart setting, using default false")
		auto_restart_enabled = false
	
	if global_data and global_data.settings_dict.has("auto_restart_pause_time"):
		auto_restart_pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		print("[Option] Loaded auto_restart_pause_time from GlobalData: ", auto_restart_pause_time)
	else:
		print("[Option] No auto_restart_pause_time setting, using default 5")
		auto_restart_pause_time = 5
	
	# Update UI to reflect the loaded settings
	set_language_button_pressed()
	set_drill_button_pressed()
	set_auto_restart_button_pressed()
	update_ui_texts()
	
	# Use call_deferred to ensure focus is set after all UI updates are complete
	call_deferred("set_focus_to_current_language")

func _on_netlink_status_loaded():
	print("[Option] Received GlobalData.netlink_status_loaded signal")
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		print("[Option] GlobalData not found in _on_netlink_status_loaded")
		return

	var s = global_data.netlink_status
	if s == null or typeof(s) != TYPE_DICTIONARY:
		print("[Option] GlobalData.netlink_status is empty or invalid: ", s)
		return

	# Map expected fields from netlink_status -> UI labels
	# Content1: bluetooth_name, Content2: device_name, Content3: channel, Content4: wifi_ip, Content5: work_mode
	if content1_label:
		content1_label.text = str(s.get("bluetooth_name", ""))
	if content2_label:
		content2_label.text = str(s.get("device_name", ""))
	if content3_label:
		content3_label.text = str(s.get("channel", ""))
	if content4_label:
		content4_label.text = str(s.get("wifi_ip", ""))
	if content5_label:
		content5_label.text = str(s.get("work_mode", ""))

	print("[Option] Populated networking fields from GlobalData.netlink_status: ", s)

# Function to get current language (can be called from other scripts)
static func get_current_language() -> String:
	return current_language

# Function to get current drill sequence (can be called from other scripts)
static func get_current_drill_sequence() -> String:
	return current_drill_sequence

# Functions to get current auto restart settings (can be called from other scripts)
static func get_auto_restart_enabled() -> bool:
	return auto_restart_enabled

static func get_auto_restart_pause_time() -> int:
	return auto_restart_pause_time

func _on_menu_control(directive: String):
	print("[Option] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down":
			if tab_container:
				match tab_container.current_tab:
					0:
						print("[Option] Navigation: ", directive, " on Networking tab")
						navigate_network_buttons(directive)
					1:
						print("[Option] Navigation: ", directive, " on Languages tab")
						navigate_buttons(directive)
					2:
						print("[Option] Navigation: ", directive, " on Drills tab")
						navigate_drill_buttons(directive)
					_:
						print("[Option] Navigation: ", directive, " ignored - current tab has no navigation")
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
	# With multiple drill buttons, we need to handle navigation between them
	var drill_buttons = []
	if random_sequence_check:
		drill_buttons.append(random_sequence_check)
	if auto_restart_check:
		drill_buttons.append(auto_restart_check)
	if pause_5s_check and auto_restart_enabled:
		drill_buttons.append(pause_5s_check)
	if pause_10s_check and auto_restart_enabled:
		drill_buttons.append(pause_10s_check)
	
	if drill_buttons.is_empty():
		print("[Option] No drill buttons found for navigation")
		return
	
	# Find current focused button
	var current_index = -1
	for i in range(drill_buttons.size()):
		if drill_buttons[i].has_focus():
			current_index = i
			break
	
	if current_index == -1:
		# If no button has focus, focus the first one
		if drill_buttons[0]:
			drill_buttons[0].grab_focus()
			print("[Option] Focus set to first drill button")
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
		if drill_buttons[target_index]:
			drill_buttons[target_index].grab_focus()
			print("[Option] Focus moved to drill button at index: ", target_index)
			return
		
		attempts += 1
	
	print("[Option] No other valid drill buttons found for navigation")

func navigate_network_buttons(direction: String):
	if networking_buttons.is_empty():
		print("[Option] No networking buttons available")
		return

	var current_index = -1
	for i in range(networking_buttons.size()):
		if networking_buttons[i] and networking_buttons[i].has_focus():
			current_index = i
			break

	if current_index == -1:
		networking_buttons[0].grab_focus()
		print("[Option] Focus set to first networking button")
		return

	var target_index = current_index
	if direction == "up":
		target_index = (target_index - 1 + networking_buttons.size()) % networking_buttons.size()
	else:
		target_index = (target_index + 1) % networking_buttons.size()

	if networking_buttons[target_index]:
		networking_buttons[target_index].grab_focus()
		print("[Option] Networking focus moved to ", networking_buttons[target_index].name)

func press_focused_button():
	# Networking tab
	if tab_container and tab_container.current_tab == 0:
		for button in networking_buttons:
			if button and button.has_focus():
				if button == wifi_button:
					_on_wifi_pressed()
				elif button == network_button:
					_on_network_pressed()
				return

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
	
	# Handle drill CheckButton
	if random_sequence_check and random_sequence_check.has_focus():
		# Toggle the CheckButton
		random_sequence_check.button_pressed = !random_sequence_check.button_pressed
		# This will trigger the toggled signal which calls _on_drill_sequence_toggled
		print("[Option] Toggled drill CheckButton to: ", random_sequence_check.button_pressed)
	
	# Handle auto restart CheckButton
	if auto_restart_check and auto_restart_check.has_focus():
		# Toggle the CheckButton
		auto_restart_check.button_pressed = !auto_restart_check.button_pressed
		# This will trigger the toggled signal which calls _on_auto_restart_toggled
		print("[Option] Toggled auto restart CheckButton to: ", auto_restart_check.button_pressed)
	
	# Handle pause time check buttons
	if pause_5s_check and pause_5s_check.has_focus():
		# Toggle the 5s button (this will automatically untoggle the 10s button due to ButtonGroup)
		pause_5s_check.button_pressed = true
		print("[Option] Selected pause time: 5s")
		_on_pause_time_changed(5)
	if pause_10s_check and pause_10s_check.has_focus():
		# Toggle the 10s button (this will automatically untoggle the 5s button due to ButtonGroup)
		pause_10s_check.button_pressed = true
		print("[Option] Selected pause time: 10s")
		_on_pause_time_changed(10)

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
	match current:
		0:
			if wifi_button:
				wifi_button.grab_focus()
			else:
				tab_container.grab_focus()
		1:
			set_focus_to_current_language()
		2:
			if random_sequence_check:
				random_sequence_check.grab_focus()
			else:
				tab_container.grab_focus()
		_:
			tab_container.grab_focus()
	print("[Option] Switched to tab: ", tab_container.get_tab_title(current))

func _on_wifi_pressed():
	_show_wifi_networks()

func _show_wifi_networks():
	if not is_inside_tree():
		print("[Option] Cannot change scene, node not inside tree")
		return
	print("[Option] Switching to WiFi networks scene")
	get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")

func _on_network_pressed():
	get_tree().change_scene_to_file("res://scene/networking_config.tscn")
