extends Control

# Debug flag
const DEBUG_DISABLED = true

# References to networking buttons
@onready var wifi_button = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/WifiButton"
@onready var network_button = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/NetworkButton"
@onready var networking_buttons = []

# References to networking info labels
@onready var content1_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row1/Content1"
@onready var content2_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row2/Content2"
@onready var content3_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row3/Content3"
@onready var content4_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row4/Content4"
@onready var content5_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row5/Content5"

# References to networking title labels
@onready var title1_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row1/Title1"
@onready var title2_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row2/Title2"
@onready var title3_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row3/Title3"
@onready var title4_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row4/Title4"
@onready var title5_label = $"../VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row5/Title5"

func _ready():
	"""Initialize networking tab"""
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
	
	# Initialize networking buttons array (wifi, network)
	networking_buttons = []
	if wifi_button:
		networking_buttons.append(wifi_button)
	if network_button:
		networking_buttons.append(network_button)

	if not DEBUG_DISABLED:
		print("[NetworkingTab] Networking buttons initialization:")
		for i in range(networking_buttons.size()):
			if networking_buttons[i]:
				print("[NetworkingTab]   Net Button ", i, ": ", networking_buttons[i].name, " - OK")
			else:
				print("[NetworkingTab]   Net Button ", i, ": NULL - MISSING!")

	# Connect wifi button pressed to open overlay
	if wifi_button:
		wifi_button.pressed.connect(_on_wifi_pressed)
	
	# Request initial netlink status
	_request_netlink_status()

func _populate_networking_fields(data: Dictionary):
	"""Populate networking UI labels with data from netlink_status"""
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
		var work_mode = str(data.get("work_mode", "")).to_lower()
		if work_mode == "master":
			content5_label.text = tr("work_mode_master")
		elif work_mode == "slave":
			content5_label.text = tr("work_mode_slave")
		else:
			content5_label.text = work_mode

func _request_netlink_status():
	"""Request netlink status from HTTP service"""
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[NetworkingTab] About to call http_service.netlink_status")
		http_service.netlink_status(Callable(self, "_on_netlink_status_response"))
		if not DEBUG_DISABLED:
			print("[NetworkingTab] Called http_service.netlink_status successfully")
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingTab] HttpService singleton not found; cannot request netlink status")

func _on_netlink_status_response(result, response_code, _headers, body):
	"""Handle netlink_status HTTP response"""
	if not DEBUG_DISABLED:
		print("[NetworkingTab] Received netlink_status HTTP response - Code:", response_code)
	if response_code == 200 and result == HTTPRequest.RESULT_SUCCESS:
		var body_str = body.get_string_from_utf8()
		if not DEBUG_DISABLED:
			print("[NetworkingTab] netlink_status body: ", body_str)
		
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
				if not DEBUG_DISABLED:
					print("[NetworkingTab] Parsed data from 'data' field")
			else:
				# Direct format: {...}
				parsed_data = json
				if not DEBUG_DISABLED:
					print("[NetworkingTab] Parsed data directly from response")
			
			if parsed_data and typeof(parsed_data) == TYPE_DICTIONARY:
				if not DEBUG_DISABLED:
					print("[NetworkingTab] Parsed netlink_status data: ", parsed_data)
				# Populate UI directly with parsed data
				_populate_networking_fields(parsed_data)
			else:
				if not DEBUG_DISABLED:
					print("[NetworkingTab] Failed to parse netlink_status data - parsed_data: ", parsed_data, " type: ", typeof(parsed_data))
		else:
			if not DEBUG_DISABLED:
				print("[NetworkingTab] Failed to parse JSON response: ", body_str)
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingTab] netlink_status request failed with code:", response_code)

func get_networking_buttons() -> Array:
	"""Get array of networking buttons for navigation"""
	return networking_buttons

func navigate_network_buttons(direction: String):
	"""Navigate between networking buttons"""
	if networking_buttons.is_empty():
		if not DEBUG_DISABLED:
			print("[NetworkingTab] No networking buttons available")
		return

	var current_index = -1
	for i in range(networking_buttons.size()):
		if networking_buttons[i] and networking_buttons[i].has_focus():
			current_index = i
			break

	if current_index == -1:
		networking_buttons[0].grab_focus()
		if not DEBUG_DISABLED:
			print("[NetworkingTab] Focus set to first networking button")
		return

	var target_index = current_index
	if direction == "up":
		target_index = (target_index - 1 + networking_buttons.size()) % networking_buttons.size()
	else:
		target_index = (target_index + 1) % networking_buttons.size()

	if networking_buttons[target_index]:
		networking_buttons[target_index].grab_focus()
		if not DEBUG_DISABLED:
			print("[NetworkingTab] Networking focus moved to ", networking_buttons[target_index].name)

func press_focused_button():
	"""Handle button press for currently focused networking button"""
	for button in networking_buttons:
		if button and button.has_focus():
			if button == wifi_button:
				_on_wifi_pressed()
			elif button == network_button:
				_on_network_pressed()
			return

func set_focus_to_first_button():
	"""Set focus to first networking button"""
	if not networking_buttons.is_empty() and networking_buttons[0]:
		networking_buttons[0].grab_focus()
		if not DEBUG_DISABLED:
			print("[NetworkingTab] Focus set to first networking button")

func _on_wifi_pressed():
	"""Handle WiFi button pressed"""
	_show_wifi_networks()

func _show_wifi_networks():
	"""Navigate to WiFi networks scene"""
	if not is_inside_tree():
		print("[NetworkingTab] Cannot change scene, node not inside tree")
		return
	print("[NetworkingTab] Switching to WiFi networks scene")
	get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")

func _on_network_pressed():
	"""Handle Network button pressed"""
	get_tree().change_scene_to_file("res://scene/networking_config.tscn")

func update_ui_texts():
	"""Update networking tab UI text labels with translated strings"""
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
