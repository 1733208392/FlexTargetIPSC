extends Control

# Global variable for current language
static var current_language = "English"

# Global variable for current drill sequence
static var current_drill_sequence = "Fixed"

# Global variables for auto restart settings
static var auto_restart_enabled = false
static var auto_restart_pause_time = 5  # Changed to store the selected time (5 or 10)

# Sensor threshold tracking
var initial_threshold = 0
var current_threshold = 0
var threshold_changed = false

# Debug flag for controlling print statements
const DEBUG_ENABLED = false

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/SimplifiedChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/EnglishButton"
@onready var traditional_chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/TraditionalChineseButton"

# References to labels that need translation
@onready var tab_container = $"VBoxContainer/MarginContainer/tab_container"
@onready var description_label = $"VBoxContainer/MarginContainer/tab_container/About/HBoxContainer/Left/MarginContainer/DescriptionLabel"
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

# References to networking title labels
@onready var title1_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row1/Title1"
@onready var title2_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row2/Title2"
@onready var title3_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row3/Title3"
@onready var title4_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row4/Title4"
@onready var title5_label = $"VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row5/Title5"

# References to drill note label
@onready var drill_note_label = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/Label"

# References to sensitivity controls
@onready var sensitivity_slider = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/SensitivityHSlider"
@onready var sensitivity_label = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/SensitivityLabel"

# Reference to upgrade button
@onready var upgrade_button = $"VBoxContainer/MarginContainer/tab_container/About/MarginContainer/Button"

func _ready():
	# Show status bar when entering options
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		print("[Option] Showed status bar: ", status_bar.name)
	
	# Load saved settings from GlobalData
	load_settings_from_global_data()
	
	# Set title labels to left alignment
	if title1_label:
		title1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title2_label:
		title2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title3_label:
		title3_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title4_label:
		title4_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title5_label:
		title5_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
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
	if DEBUG_ENABLED:
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

	if DEBUG_ENABLED:
		print("[Option] Networking buttons initialization:")
		for i in range(networking_buttons.size()):
			if networking_buttons[i]:
				print("[Option]   Net Button ", i, ": ", networking_buttons[i].name, " - OK")
			else:
				print("[Option]   Net Button ", i, ": NULL - MISSING!")

	# Connect wifi button pressed to open overlay (also handled by press_focused_button)
	if wifi_button:
		wifi_button.pressed.connect(_on_wifi_pressed)
	
	# Connect upgrade button pressed
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)

	# Connect sensitivity slider value_changed signal
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_value_changed)
		# Update label with initial value
		_update_sensitivity_label()
	else:
		if DEBUG_ENABLED:
			print("[Option] Sensitivity slider not found!")

	# Load embedded system status to get current threshold
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.embedded_status(Callable(self, "_on_embedded_status_response"))
		if DEBUG_ENABLED:
			print("[Option] Requesting embedded system status")
	else:
		if DEBUG_ENABLED:
			print("[Option] HttpService singleton not found!")

	# Focus will be set by load_settings_from_global_data() based on current language
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_ENABLED:
			print("[Option] Connecting to WebSocketListener.menu_control signal")
	else:
		if DEBUG_ENABLED:
			print("[Option] WebSocketListener singleton not found!")

	# Always request fresh netlink status from server
	var http_service_netlink = get_node_or_null("/root/HttpService")
	if http_service_netlink:
		if DEBUG_ENABLED:
			print("[Option] About to call http_service.netlink_status")
		http_service.netlink_status(Callable(self, "_on_netlink_status_response"))
		if DEBUG_ENABLED:
			print("[Option] Called http_service.netlink_status successfully")
	else:
		if DEBUG_ENABLED:
			print("[Option] HttpService singleton not found; cannot request netlink status")

func _on_language_changed(language: String):
	current_language = language
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["language"] = current_language
		if DEBUG_ENABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[language] to: ", current_language)
	else:
		if DEBUG_ENABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	set_locale_from_language(language)
	save_settings()
	update_ui_texts()
	if DEBUG_ENABLED:
		print("Language changed to: ", language)

func _on_drill_sequence_toggled(button_pressed: bool):
	var sequence = "Random" if button_pressed else "Fixed"
	if DEBUG_ENABLED:
		print("[Option] Drill sequence toggled to: ", sequence)
		print("[Option] Current drill_sequence before change: ", current_drill_sequence)
	current_drill_sequence = sequence
	if DEBUG_ENABLED:
		print("[Option] Current drill_sequence after change: ", current_drill_sequence)
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["drill_sequence"] = current_drill_sequence
		if DEBUG_ENABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[drill_sequence] to: ", current_drill_sequence)
	else:
		if DEBUG_ENABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

func _on_auto_restart_toggled(button_pressed: bool):
	if DEBUG_ENABLED:
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
		if DEBUG_ENABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[auto_restart] to: ", auto_restart_enabled)
	else:
		if DEBUG_ENABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

func _on_pause_time_changed(selected_time: int):
	if DEBUG_ENABLED:
		print("[Option] Pause time changed to: ", selected_time)
	auto_restart_pause_time = selected_time
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["auto_restart_pause_time"] = auto_restart_pause_time
		if DEBUG_ENABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[auto_restart_pause_time] to: ", auto_restart_pause_time)
	else:
		if DEBUG_ENABLED:
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
		description_label.text = tr("about_description_intro") + "\n" + tr("about_description_features")
	if copyright_label:
		copyright_label.text = tr("copyright")
	if random_sequence_check:
		random_sequence_check.text = tr("random_sequence")
	
	# Networking tab labels
	if title1_label:
		title1_label.text = tr("bluetooth_name")
	if title2_label:
		title2_label.text = tr("device_name")
	if title3_label:
		title3_label.text = tr("network_channel")
	if title4_label:
		title4_label.text = tr("ip_address")
	if title5_label:
		title5_label.text = tr("working_mode")
	if wifi_button:
		wifi_button.text = tr("wifi_configure")
	if network_button:
		network_button.text = tr("network_configure")
	
	# Drills tab labels
	if auto_restart_check:
		auto_restart_check.text = tr("auto_restart")
	if pause_5s_check:
		pause_5s_check.text = tr("pause_5s")
	if pause_10s_check:
		pause_10s_check.text = tr("pause_10s")
	if drill_note_label:
		drill_note_label.text = tr("auto_restart_note")

func save_settings():
	# Save settings directly using current GlobalData
	var http_service = get_node("/root/HttpService")
	if not http_service:
		if DEBUG_ENABLED:
			print("HttpService not found!")
		return
	
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data or global_data.settings_dict.size() == 0:
		if DEBUG_ENABLED:
			print("GlobalData not available, cannot save settings")
		return
	
	var settings_data = global_data.settings_dict.duplicate()
	var content = JSON.stringify(settings_data)
	if DEBUG_ENABLED:
		print("[Option] Saving settings directly: ", settings_data)
	
	http_service.save_game(_on_save_settings_callback, "settings", content)

func _on_save_settings_callback(_result, response_code, _headers, _body):
	if DEBUG_ENABLED:
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
		if DEBUG_ENABLED:
			print("[Option] Loaded language from GlobalData: ", current_language)
	else:
		if DEBUG_ENABLED:
			print("[Option] GlobalData not found or no language setting, using default English")
		current_language = "English"
		set_locale_from_language(current_language)
	
	# Load drill sequence setting
	if global_data and global_data.settings_dict.has("drill_sequence"):
		current_drill_sequence = global_data.settings_dict.get("drill_sequence", "Fixed")
		if current_drill_sequence == "":
			current_drill_sequence = "Fixed"
		if DEBUG_ENABLED:
			print("[Option] Loaded drill_sequence from GlobalData: ", current_drill_sequence)
	else:
		if DEBUG_ENABLED:
			print("[Option] No drill_sequence setting, using default Fixed")
		current_drill_sequence = "Fixed"
	
	# Load auto restart settings
	if global_data and global_data.settings_dict.has("auto_restart"):
		auto_restart_enabled = global_data.settings_dict.get("auto_restart", false)
		if DEBUG_ENABLED:
			print("[Option] Loaded auto_restart from GlobalData: ", auto_restart_enabled)
	else:
		if DEBUG_ENABLED:
			print("[Option] No auto_restart setting, using default false")
		auto_restart_enabled = false
	
	if global_data and global_data.settings_dict.has("auto_restart_pause_time"):
		auto_restart_pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		if DEBUG_ENABLED:
			print("[Option] Loaded auto_restart_pause_time from GlobalData: ", auto_restart_pause_time)
	else:
		if DEBUG_ENABLED:
			print("[Option] No auto_restart_pause_time setting, using default 5")
		auto_restart_pause_time = 5
	
	# Update UI to reflect the loaded settings
	set_language_button_pressed()
	set_drill_button_pressed()
	set_auto_restart_button_pressed()
	update_ui_texts()
	
	# Use call_deferred to ensure focus is set after all UI updates are complete
	call_deferred("set_focus_to_current_language")

func _populate_networking_fields(data: Dictionary):
	# Map expected fields from netlink_status -> UI labels
	# Content1: bluetooth_name, Content2: device_name, Content3: channel, Content4: wifi_ip, Content5: work_mode
	if content1_label:
		content1_label.text = str(data.get("bluetooth_name", ""))
	if content2_label:
		content2_label.text = str(data.get("device_name", ""))
	if content3_label:
		content3_label.text = str(int(data.get("channel", 0)))
	if content4_label:
		content4_label.text = str(data.get("wifi_ip", ""))
	if content5_label:
		content5_label.text = str(data.get("work_mode", ""))

func _on_netlink_status_response(result, response_code, _headers, body):
	if DEBUG_ENABLED:
		print("[Option] Received netlink_status HTTP response - Code:", response_code)
	if response_code == 200 and result == HTTPRequest.RESULT_SUCCESS:
		var body_str = body.get_string_from_utf8()
		if DEBUG_ENABLED:
			print("[Option] netlink_status body: ", body_str)
		
		# Parse the response
		var json = JSON.parse_string(body_str)
		if json:
			var parsed_data = null
			
			# Try different response formats
			if json.has("data"):
				# Format: {"data": "..."} or {"data": {...}}
				var data_field = json["data"]
				if typeof(data_field) == TYPE_STRING:
					parsed_data = JSON.parse_string(data_field)
				else:
					parsed_data = data_field
				if DEBUG_ENABLED:
					print("[Option] Parsed data from 'data' field")
			else:
				# Direct format: {...}
				parsed_data = json
				if DEBUG_ENABLED:
					print("[Option] Parsed data directly from response")
			
			if parsed_data and typeof(parsed_data) == TYPE_DICTIONARY:
				if DEBUG_ENABLED:
					print("[Option] Parsed netlink_status data: ", parsed_data)
				# Populate UI directly with parsed data
				_populate_networking_fields(parsed_data)
			else:
				if DEBUG_ENABLED:
					print("[Option] Failed to parse netlink_status data - parsed_data: ", parsed_data, " type: ", typeof(parsed_data))
		else:
			if DEBUG_ENABLED:
				print("[Option] Failed to parse JSON response: ", body_str)
	else:
		if DEBUG_ENABLED:
			print("[Option] netlink_status request failed with code:", response_code)

# Functions to get current auto restart settings (can be called from other scripts)

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
	if has_visible_power_off_dialog():
		return
	if DEBUG_ENABLED:
		print("[Option] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down":
			if tab_container:
				match tab_container.current_tab:
					0:
						if DEBUG_ENABLED:
							print("[Option] Navigation: ", directive, " on Networking tab")
						navigate_network_buttons(directive)
					1:
						if DEBUG_ENABLED:
							print("[Option] Navigation: ", directive, " on Languages tab")
						navigate_buttons(directive)
					2:
						if DEBUG_ENABLED:
							print("[Option] Navigation: ", directive, " on Drills tab")
						navigate_drill_buttons(directive)
					_:
						if DEBUG_ENABLED:
							print("[Option] Navigation: ", directive, " ignored - current tab has no navigation")
		"left", "right":
			# Check if sensitivity slider is focused on Drills tab
			if tab_container and tab_container.current_tab == 2 and sensitivity_slider and sensitivity_slider.has_focus():
				if DEBUG_ENABLED:
					print("[Option] Adjusting sensitivity slider: ", directive)
				adjust_sensitivity_slider(directive)
			else:
				if DEBUG_ENABLED:
					print("[Option] Tab switch: ", directive)
				switch_tab(directive)
		"enter":
			if DEBUG_ENABLED:
				print("[Option] Enter pressed")
			press_focused_button()
		"back", "homepage":
			if DEBUG_ENABLED:
				print("[Option] ", directive, " - navigating to main menu")
			# Save threshold before leaving the scene
			_save_threshold_if_changed()
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				if DEBUG_ENABLED:
					print("[Option] Warning: Node not in tree, cannot change scene")
		"compose":
			if DEBUG_ENABLED:
				print("[Option] compose directive received - navigating to onboard_debug")
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/onboard_debug.tscn")
			else:
				if DEBUG_ENABLED:
					print("[Option] Warning: Node not in tree, cannot change scene to onboard_debug")
		"volume_up":
			if DEBUG_ENABLED:
				print("[Option] Volume up")
			volume_up()
		"volume_down":
			if DEBUG_ENABLED:
				print("[Option] Volume down")
			volume_down()
		"power":
			if DEBUG_ENABLED:
				print("[Option] Power off")
			power_off()
		_:
			if DEBUG_ENABLED:
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
				if DEBUG_ENABLED:
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
			if DEBUG_ENABLED:
				print("[Option] Focus moved to ", language_buttons[target_index].name)
			return
		
		attempts += 1
	
	if DEBUG_ENABLED:
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
	if sensitivity_slider:
		drill_buttons.append(sensitivity_slider)
	
	if drill_buttons.is_empty():
		if DEBUG_ENABLED:
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
			if DEBUG_ENABLED:
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
			if DEBUG_ENABLED:
				print("[Option] Focus moved to drill button at index: ", target_index)
			return
		
		attempts += 1
	
	if DEBUG_ENABLED:
		print("[Option] No other valid drill buttons found for navigation")

func navigate_network_buttons(direction: String):
	if networking_buttons.is_empty():
		if DEBUG_ENABLED:
			print("[Option] No networking buttons available")
		return

	var current_index = -1
	for i in range(networking_buttons.size()):
		if networking_buttons[i] and networking_buttons[i].has_focus():
			current_index = i
			break

	if current_index == -1:
		networking_buttons[0].grab_focus()
		if DEBUG_ENABLED:
			print("[Option] Focus set to first networking button")
		return

	var target_index = current_index
	if direction == "up":
		target_index = (target_index - 1 + networking_buttons.size()) % networking_buttons.size()
	else:
		target_index = (target_index + 1) % networking_buttons.size()

	if networking_buttons[target_index]:
		networking_buttons[target_index].grab_focus()
		if DEBUG_ENABLED:
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
		if DEBUG_ENABLED:
			print("[Option] Toggled drill CheckButton to: ", random_sequence_check.button_pressed)
	
	# Handle auto restart CheckButton
	if auto_restart_check and auto_restart_check.has_focus():
		# Toggle the CheckButton
		auto_restart_check.button_pressed = !auto_restart_check.button_pressed
		# This will trigger the toggled signal which calls _on_auto_restart_toggled
		if DEBUG_ENABLED:
			print("[Option] Toggled auto restart CheckButton to: ", auto_restart_check.button_pressed)
	
	# Handle pause time check buttons
	if pause_5s_check and pause_5s_check.has_focus():
		# Toggle the 5s button (this will automatically untoggle the 10s button due to ButtonGroup)
		pause_5s_check.button_pressed = true
		if DEBUG_ENABLED:
			print("[Option] Selected pause time: 5s")
		_on_pause_time_changed(5)
	if pause_10s_check and pause_10s_check.has_focus():
		# Toggle the 10s button (this will automatically untoggle the 5s button due to ButtonGroup)
		pause_10s_check.button_pressed = true
		if DEBUG_ENABLED:
			print("[Option] Selected pause time: 10s")
		_on_pause_time_changed(10)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_ENABLED:
			print("[Option] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		if DEBUG_ENABLED:
			print("[Option] HttpService singleton not found!")

func _on_volume_up_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_ENABLED:
		print("[Option] Volume up HTTP response:", _result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_ENABLED:
			print("[Option] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		if DEBUG_ENABLED:
			print("[Option] HttpService singleton not found!")

func _on_volume_down_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_ENABLED:
		print("[Option] Volume down HTTP response:", _result, response_code, body_str)

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

func _on_upgrade_pressed():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_ENABLED:
			print("[Option] Sending upgrade engine HTTP request...")
		http_service.upgrade_engine(_on_upgrade_response)
	else:
		if DEBUG_ENABLED:
			print("[Option] HttpService not found!")

func _on_upgrade_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_ENABLED:
		print("[Option] Upgrade engine HTTP response:", result, response_code, body_str)

func _on_embedded_status_response(_result, _response_code, _headers, body):
	"""Handle embedded system status response."""
	var body_str = body.get_string_from_utf8()
	if DEBUG_ENABLED:
		print("[Option] Embedded status response:", body_str)
	
	var response = JSON.parse_string(body_str)
	if response and response.has("code") and response.code == 0 and response.has("data"):
		var threshold = response.data.threshold
		initial_threshold = threshold
		current_threshold = threshold
		threshold_changed = false
		
		# Set the slider to the fetched threshold value
		if sensitivity_slider:
			sensitivity_slider.value = threshold
			_update_sensitivity_label()
			if DEBUG_ENABLED:
				print("[Option] Set sensitivity slider to: ", threshold)
	else:
		if DEBUG_ENABLED:
			print("[Option] Invalid embedded status response")

func _on_sensitivity_value_changed(value: float):
	"""Called when the sensitivity slider value changes."""
	current_threshold = int(value)
	threshold_changed = (current_threshold != initial_threshold)
	_update_sensitivity_label()
	if DEBUG_ENABLED:
		print("[Option] Sensitivity value changed to: ", value, ", changed: ", threshold_changed)

func _update_sensitivity_label():
	"""Update the sensitivity label with the current slider value."""
	if sensitivity_slider and sensitivity_label:
		sensitivity_label.text = tr("sensor_sensitivity") + " [ "+ str(int(sensitivity_slider.value)) + " ]"
		if DEBUG_ENABLED:
			print("[Option] Updated sensitivity label to: ", sensitivity_label.text)

func adjust_sensitivity_slider(direction: String):
	"""Adjust the sensitivity slider with left/right directives."""
	if not sensitivity_slider:
		if DEBUG_ENABLED:
			print("[Option] Sensitivity slider not found!")
		return
	
	var current_value = sensitivity_slider.value
	var step = sensitivity_slider.step
	
	if direction == "right":
		sensitivity_slider.value = min(sensitivity_slider.max_value, current_value + step)
		if DEBUG_ENABLED:
			print("[Option] Increased sensitivity to: ", sensitivity_slider.value)
	elif direction == "left":
		sensitivity_slider.value = max(sensitivity_slider.min_value, current_value - step)
		if DEBUG_ENABLED:
			print("[Option] Decreased sensitivity to: ", sensitivity_slider.value)

func _save_threshold_if_changed():
	"""Save threshold to embedded system if it has changed."""
	if threshold_changed and current_threshold != initial_threshold:
		var http_service = get_node_or_null("/root/HttpService")
		if http_service:
			if DEBUG_ENABLED:
				print("[Option] Threshold changed from ", initial_threshold, " to ", current_threshold, ", saving...")
			# Use empty callable since we're exiting anyway
			http_service.embedded_set_threshold(Callable(), current_threshold)
		else:
			if DEBUG_ENABLED:
				print("[Option] HttpService not found, cannot save threshold")
	else:
		if DEBUG_ENABLED:
			print("[Option] Threshold not changed, no need to save")

func _on_threshold_set_response(_result, _response_code, _headers, body):
	"""Handle threshold set response."""
	var body_str = body.get_string_from_utf8()
	if DEBUG_ENABLED:
		print("[Option] Threshold set response: ", body_str)

func _exit_tree():
	"""Called when the node is about to leave the scene tree."""
	_save_threshold_if_changed()
