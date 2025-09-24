extends Control

# Simple WiFi networks UI for testing remote navigation + onscreen keyboard
# The scene shows a list of fake networks. Remote navigation should move
# focus between network buttons. Pressing Enter on a network opens an
# overlay where user can input a password using the onscreen keyboard.

@onready var list_vbox = $CenterContainer/NetworksVBox
@onready var overlay = $Overlay
@onready var password_line = $Overlay/PanelContainer/VBoxContainer/PasswordLine
@onready var submit_btn = $Overlay/PanelContainer/VBoxContainer/SubmitButton
@onready var cancel_btn = $Overlay/PanelContainer/VBoxContainer/CancelButton
@onready var keyboard = $Overlay/PanelContainer/VBoxContainer/OnscreenKeyboard

var networks = []
var selected_network = ""
var focused_index = 0
var network_buttons = []

func _ready():
	_scan_networks()
	overlay.visible = false
	# connect overlay buttons
	if submit_btn:
		submit_btn.connect("pressed", Callable(self, "_on_submit_pressed"))
	if cancel_btn:
		cancel_btn.connect("pressed", Callable(self, "_on_cancel_pressed"))
	
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

func _scan_networks():
	HttpService.wifi_scan(Callable(self, "_on_wifi_scan_completed"))

func _on_wifi_scan_completed(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		if json and json.has("data") and json["data"].has("ssid_list"):
			networks = json["data"]["ssid_list"]
			_build_list()
		else:
			print("Invalid response format")
	else:
		print("WiFi scan failed: ", result, " code: ", response_code)

func _build_list():
	# clear existing children
	for c in list_vbox.get_children():
		c.queue_free()
	network_buttons.clear()
	for net_name in networks:
		var b = Button.new()
		b.text = net_name
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.connect("pressed", Callable(self, "_on_network_selected").bind(net_name))
		list_vbox.add_child(b)
		network_buttons.append(b)
	
	# Set initial focus
	if network_buttons.size() > 0:
		focused_index = 0
		network_buttons[focused_index].grab_focus()

func _on_network_selected(name):
	selected_network = name
	# Show overlay and focus password field
	overlay.visible = true
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
		if keyboard.has_signal("released"):
			if not keyboard.released.is_connected(_on_keyboard_key_released):
				keyboard.released.connect(_on_keyboard_key_released)
				print("[WiFi Networks] Connected to keyboard released signal")

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

func _on_submit_pressed():
	var password = password_line.text
	print("[WiFi Networks] Submit pressed with password: '", password, "' (length: ", password.length(), ")")
	HttpService.wifi_connect(Callable(self, "_on_wifi_connect_completed"), selected_network, password)
	overlay.visible = false
	if keyboard:
		keyboard.visible = false

func _on_wifi_connect_completed(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		if json and json.has("code") and json["code"] == 0:
			print("Successfully connected to WiFi: ", selected_network)
		else:
			print("Failed to connect to WiFi: ", json.get("msg", "Unknown error") if json else "Invalid response")
	else:
		print("WiFi connect request failed: ", result, " code: ", response_code)

func _on_navigate(direction: String):
	print("[WiFi Networks] Navigation: ", direction)
	if not overlay.visible:
		# Navigate network list
		match direction:
			"up":
				navigate_buttons(-1)
			"down", "left", "right":
				navigate_buttons(1)
	# Keyboard navigation is handled by the onscreen keyboard itself via menu_control signal

func _on_enter_pressed():
	print("[WiFi Networks] Enter pressed")
	press_focused_button()

func _on_back_pressed():
	print("[WiFi Networks] Back pressed - navigating to main menu")
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_volume_up():
	print("[WiFi Networks] Volume up requested")

func _on_volume_down():
	print("[WiFi Networks] Volume down requested")

func _on_power_off():
	print("[WiFi Networks] Power off requested")

func _on_cancel_pressed():
	overlay.visible = false
	if keyboard:
		keyboard.visible = false

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
		# Could press overlay buttons
		pass
	else:
		if network_buttons.size() > 0:
			print("[WiFi Networks] Simulating network button press")
			var focused_button = network_buttons[focused_index]
			focused_button.pressed.emit()

# Allow closing overlay with ESC
func _input(event):
	if overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		overlay.visible = false
		if keyboard:
			keyboard.visible = false
		get_viewport().gui_focus(null)
