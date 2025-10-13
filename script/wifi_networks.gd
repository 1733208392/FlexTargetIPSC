extends Control

# Simple WiFi networks UI for testing remote navigation + onscreen keyboard
# The scene shows a list of fake networks. Remote navigation should move
# focus between network buttons. Pressing Enter on a network opens an
# overlay where user can input a password using the onscreen keyboard.

const WIFI_ICON = preload("res://asset/wifi.fill.idle.png")
const WIFI_CONNECTED_ICON = preload("res://asset/wifi.fill.connect.png")

@onready var list_vbox = $CenterContainer/NetworksVBox
@onready var overlay = $Overlay
@onready var password_line = $Overlay/PanelContainer/VBoxContainer/PasswordLine
@onready var title_label = $Overlay/PanelContainer/VBoxContainer/Label
@onready var keyboard = $Overlay/PanelContainer/VBoxContainer/OnscreenKeyboard
@onready var scanning_container = $ScanningContainer
@onready var scanning_label = $ScanningContainer/ScanningLabel
@onready var retry_button = $ScanningContainer/RetryButton

var networks = []
var selected_network = ""
var focused_index = 0
var network_buttons = []
var connected_network = ""
var scan_timer: Timer
var timeout_timer: Timer
var dot_count = 0

func _ready():
	print("[WiFi Networks] _ready called, list_vbox: ", list_vbox)
	overlay.visible = false
	scanning_container.visible = false
	_scan_networks()
	
	# Connect to MenuController signals
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller:
		menu_controller.navigate.connect(_on_navigate)
		menu_controller.enter_pressed.connect(_on_enter_pressed)
		menu_controller.back_pressed.connect(_on_back_pressed)
		menu_controller.volume_up_requested.connect(_on_volume_up)
		menu_controller.volume_down_requested.connect(_on_volume_down)
		menu_controller.power_off_requested.connect(_on_power_off)
		print("[WiFi Networks] Connected to MenuController signals")
	else:
		print("[WiFi Networks] MenuController singleton not found!")

	# Connect retry button signal
	retry_button.pressed.connect(_on_retry_button_pressed)

func _scan_networks():
	print("[WiFi Networks] Starting network scan")
	scanning_container.visible = true
	retry_button.visible = false
	print("[WiFi Networks] Scanning container visible: ", scanning_container.visible)
	dot_count = 0
	scanning_label.text = tr("scanning_networks")
	
	# Create and start timer for dot animation (every 0.5 seconds)
	scan_timer = Timer.new()
	scan_timer.wait_time = 0.5
	scan_timer.one_shot = false
	scan_timer.connect("timeout", Callable(self, "_on_scan_timer_timeout"))
	add_child(scan_timer)
	scan_timer.start()
	
	# Create timeout timer (20 seconds)
	timeout_timer = Timer.new()
	timeout_timer.wait_time = 20.0
	timeout_timer.one_shot = true
	timeout_timer.connect("timeout", Callable(self, "_on_scan_timeout"))
	add_child(timeout_timer)
	timeout_timer.start()
	
	HttpService.wifi_scan(Callable(self, "_on_wifi_scan_completed"))

func _on_scan_timeout():
	print("[WiFi Networks] Scan timeout occurred")
	
	# Stop both timers
	if scan_timer:
		scan_timer.stop()
		scan_timer.queue_free()
		scan_timer = null
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null
	
	# Update UI for timeout - static text, no animation
	scanning_label.text = tr("wifi_scan_timeout")
	retry_button.visible = true
	retry_button.grab_focus()
	print("[WiFi Networks] Timeout UI updated")

func _on_scan_timer_timeout():
	dot_count = (dot_count + 1) % 4  # Cycle through 0, 1, 2, 3
	var dots = ""
	for i in range(dot_count):
		dots += "."
	scanning_label.text = tr("scanning_networks") + dots
	print("[WiFi Networks] Scanning animation: ", scanning_label.text)

func _on_retry_button_pressed():
	print("[WiFi Networks] Retry button pressed")
	_scan_networks()

func _on_wifi_scan_completed(result, response_code, _headers, body):
	print("[WiFi Networks] Scan completed: result=", result, " code=", response_code)
	
	# Stop and cleanup timers
	if scan_timer:
		scan_timer.stop()
		scan_timer.queue_free()
		scan_timer = null
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		print("[WiFi Networks] Response body: ", body_str)
		var json = JSON.parse_string(body_str)
		if json and json.has("data") and json["data"].has("ssid_list"):
			networks = json["data"]["ssid_list"]
			print("[WiFi Networks] Networks found: ", networks)
			# Hide scanning indicator on success
			scanning_container.visible = false
			_build_list()
		else:
			print("Invalid response format")
			# Show failure state
			scanning_label.text = tr("wifi_scan_failed")
			retry_button.visible = true
			retry_button.grab_focus()
	else:
		print("WiFi scan failed: ", result, " code: ", response_code)
		# Show failure state for HTTP errors
		scanning_label.text = tr("wifi_scan_failed")
		retry_button.visible = true
		retry_button.grab_focus()

func _build_list():
	print("[WiFi Networks] Building list with ", networks.size(), " networks")
	# clear existing children
	for c in list_vbox.get_children():
		c.queue_free()
	network_buttons.clear()
	for net_name in networks:
		var b = Button.new()
		b.text = net_name
		b.icon = WIFI_CONNECTED_ICON if net_name == connected_network else WIFI_ICON
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.connect("pressed", Callable(self, "_on_network_selected").bind(net_name))
		list_vbox.add_child(b)
		network_buttons.append(b)
	
	# Set initial focus
	if network_buttons.size() > 0:
		focused_index = 0
		network_buttons[focused_index].grab_focus()

func _set_connected_network(ssid: String):
	connected_network = ssid
	for button in network_buttons:
		if not button:
			continue
		if button.text == connected_network:
			button.icon = WIFI_CONNECTED_ICON
		else:
			button.icon = WIFI_ICON

func _on_network_selected(network_name):
	selected_network = network_name
	# Show overlay and focus password field
	overlay.visible = true
	if title_label:
		title_label.text = tr("enter_password").replace("{wifi_name}", selected_network)
	password_line.text = ""
	password_line.grab_focus()
	if keyboard:
		keyboard.visible = true
		# Ensure password field stays focused for keyboard input
		call_deferred("_ensure_password_focus")
		# Then show keyboard to detect input focus
		call_deferred("_show_keyboard_for_input")
		print("[WiFi Networks] Keyboard shown, password LineEdit focused")

func _show_keyboard_for_input():
	if keyboard:
		# First, ensure the keyboard detects the input focus
		if keyboard.has_method("_show_keyboard"):
			keyboard._show_keyboard()
			print("[WiFi Networks] Keyboard _show_keyboard called")
		
		# Manually set last_input_focus as backup
		if "last_input_focus" in keyboard:
			keyboard.last_input_focus = password_line
			print("[WiFi Networks] Manually set keyboard last_input_focus to password LineEdit")
		
		# Then connect to keyboard's key release signal as additional backup
		# Attach handlers to individual keyboard buttons so we can detect Enter
		# presses (the keyboard internal signal flow doesn't expose a global
		# "key pressed" signal externally).
		_attach_keyboard_handlers()
		print("[WiFi Networks] Attached keyboard button handlers")

func _attach_keyboard_handlers(node = null):
	if not keyboard:
		return
	if node == null:
		node = keyboard
	# recursively traverse children and connect 'released' signals
	for child in node.get_children():
		# If child has a 'released' signal (KeyboardButton), connect to it
		if child.has_signal("released"):
			var cb = Callable(self, "_on_keyboard_button_released")
			if not child.is_connected("released", cb):
				child.connect("released", cb)
		# Recurse into containers
		_attach_keyboard_handlers(child)

func _on_keyboard_button_released(key_data):
	# key_data is a dictionary describing the key (may contain 'output')
	if key_data and typeof(key_data) == TYPE_DICTIONARY:
		var out = ""
		if key_data.has("output") and key_data["output"] != null:
			out = str(key_data["output"]).strip_edges()
		var display_text = ""
		if key_data.has("display") and key_data["display"] != null:
			display_text = str(key_data["display"]).strip_edges()
		var display_icon = ""
		if key_data.has("display-icon") and key_data["display-icon"] != null:
			display_icon = str(key_data["display-icon"]).strip_edges()
		var key_type = ""
		if key_data.has("type") and key_data["type"] != null:
			key_type = str(key_data["type"]).strip_edges()
		var is_enter = false
		if out.to_lower() == "enter" or out.to_lower() == "return":
			is_enter = true
		elif display_text.to_lower() == "enter":
			is_enter = true
		elif display_icon == "PREDEFINED:ENTER":
			is_enter = true
		elif key_type == "special-hide-keyboard" and display_text.to_lower() == "enter":
			is_enter = true
		if is_enter:
			print("[WiFi Networks] Onscreen keyboard Enter pressed")
			_commit_password()
			return

func _on_keyboard_key_released(key_data):
	if overlay.visible and password_line and key_data and key_data.has("output"):
		# Handle the key press directly for the password field
		var key_value = key_data.get("output")
		if key_value:
			# Insert the character into the password field
			var current_text = password_line.text
			var caret_pos = password_line.caret_position
			password_line.text = current_text.insert(caret_pos, key_value)
			password_line.caret_position = caret_pos + key_value.length()
			print("[WiFi Networks] Inserted key '", key_value, "' into password field")

func _ensure_password_focus():
	if overlay.visible and password_line:
		password_line.grab_focus()
		print("[WiFi Networks] Password LineEdit focus ensured")


func _commit_password():
	var password = password_line.text
	print("[WiFi Networks] Submit pressed with password: '", password, "' (length: ", password.length(), ")")
	HttpService.wifi_connect(Callable(self, "_on_wifi_connect_completed"), selected_network, password)
	_cancel_password(false)

func _on_wifi_connect_completed(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		var success = false
		var error_msg = "Unknown error"
		if typeof(json) == TYPE_DICTIONARY:
			if json.has("data") and typeof(json["data"]) == TYPE_DICTIONARY:
				var data_section = json["data"]
				if data_section.has("code") and int(data_section["code"]) == 0:
					success = true
					print("Successfully connected to WiFi: ", selected_network)
				else:
					error_msg = data_section.get("msg", error_msg)
			elif json.has("code") and int(json["code"]) == 0:
				success = true
				print("Successfully connected to WiFi: ", selected_network)
			else:
				error_msg = json.get("msg", error_msg)
		else:
			print("Failed to parse WiFi connect response: ", body_str)
		
		if not success:
			print("Failed to connect to WiFi: ", error_msg)
		else:
			_set_connected_network(selected_network)
			var signal_bus = get_node_or_null("/root/SignalBus")
			if signal_bus:
				print("WiFi Networks: Emitting wifi_connected signal for SSID: ", selected_network)
				signal_bus.emit_wifi_connected(selected_network)
				get_tree().change_scene_to_file("res://scene/option.tscn")
			else:
				print("WiFi Networks: SignalBus not found, cannot emit signal")
			# Ensure overlay and keyboard are dismissed after successful connect
			_cancel_password()
	else:
		print("WiFi connect request failed: ", result, " code: ", response_code)

func _on_navigate(direction: String):
	print("[WiFi Networks] Navigation: ", direction)
	if overlay.visible:
		# Keyboard navigation is handled by the onscreen keyboard itself via menu_control signal
		pass
	else:
		# Check if retry button is visible (scanning failed/timed out)
		if retry_button.visible:
			# If retry button is visible, give it focus
			retry_button.grab_focus()
		else:
			# Navigate network list
			match direction:
				"up":
					navigate_buttons(-1)
				"down", "left", "right":
					navigate_buttons(1)

func _on_enter_pressed():
	print("[WiFi Networks] Enter pressed")
	if overlay.visible:
		# If the onscreen keyboard is visible, route Enter to it so the
		# currently-focused key is activated (inserts a char or performs special key).
		if keyboard and keyboard.visible:
			if keyboard.has_method("_simulate_enter"):
				keyboard._simulate_enter()
				return
			# fallback: ensure keyboard is shown
			if keyboard and keyboard.has_method("_show_keyboard"):
				keyboard._show_keyboard()
				return
		# If keyboard not present, fallback to commit
		_commit_password()
	else:
		# Check if retry button is visible and focused
		if retry_button.visible and retry_button.has_focus():
			_on_retry_button_pressed()
		else:
			press_focused_button()

func _on_back_pressed():
	if overlay.visible:
		print("[WiFi Networks] Back pressed - cancelling password entry")
		_cancel_password()
	else:
		print("[WiFi Networks] Back pressed - navigating to main menu")
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_volume_up():
	print("[WiFi Networks] Volume up requested")

func _on_volume_down():
	print("[WiFi Networks] Volume down requested")

func _on_power_off():
	print("[WiFi Networks] Power off requested")

func _cancel_password(clear_text: bool = true):
	overlay.visible = false
	if clear_text and password_line:
		password_line.text = ""
	if keyboard:
		keyboard.visible = false
	if network_buttons.size() > 0:
		network_buttons[focused_index].grab_focus()

func navigate_buttons(direction: int):
	# Navigate network buttons
	if network_buttons.size() > 0:
		if overlay.visible:
			# Could navigate overlay elements
			pass
		else:
			# Navigate network list
			focused_index = (focused_index + direction + network_buttons.size()) % network_buttons.size()
			network_buttons[focused_index].grab_focus()
			print("[WiFi Networks] Focus moved to button ", focused_index)

func press_focused_button():
	# Simulate pressing the currently focused button
	if overlay.visible:
		# If keyboard visible, simulate enter on the keyboard (activate focused key)
		if keyboard and keyboard.visible and keyboard.has_method("_simulate_enter"):
			keyboard._simulate_enter()
		else:
			# No keyboard: submit the password
			_commit_password()
	else:
		if network_buttons.size() > 0:
			print("[WiFi Networks] Simulating network button press")
			var focused_button = network_buttons[focused_index]
			focused_button.pressed.emit()

# Allow closing overlay with ESC
func _input(event):
	if overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_password()
		get_viewport().gui_focus(null)
