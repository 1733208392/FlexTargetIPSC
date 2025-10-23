extends Control

# =============================================================================
# WiFi Networks UI Controller
# =============================================================================
# Manages WiFi network scanning, selection, and connection with onscreen keyboard
# Features remote navigation, password input, and connection status feedback

# =============================================================================
# CONSTANTS
# =============================================================================

const WIFI_ICON = preload("res://asset/wifi.fill.idle.png")
const WIFI_CONNECTED_ICON = preload("res://asset/wifi.fill.connect.png")
const WIFI_ICON_NETWORK = preload("res://asset/wifi.blue.icon.png")
const WIFI_BUTTON_THEME = preload("res://theme/wifi_button_theme.tres")

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var status_container = $Frame/StatusContainer
@onready var status_label = $Frame/StatusContainer/StatusLabel
@onready var retry_button = $Frame/StatusContainer/RetryButton

@onready var scroll_container = $Frame/ScrollContainer
@onready var list_vbox = $Frame/ScrollContainer/NetworksVBox

@onready var overlay = $Overlay
@onready var title_label = $Overlay/PanelContainer/VBoxContainer/Label
@onready var password_line = $Overlay/PanelContainer/VBoxContainer/PasswordLine
@onready var keyboard = $Overlay/PanelContainer/VBoxContainer/OnscreenKeyboard


# =============================================================================
# VARIABLES
# =============================================================================

var networks = []           # List of available WiFi networks
var selected_network = ""   # Currently selected network for connection
var focused_index = 0       # Index of currently focused network button
var network_buttons = []    # Array of network buttons in the list
var connected_network = ""  # Name of currently connected network

# Animation and timing variables
var scan_timer: Timer       # Timer for scanning dots animation
var timeout_timer: Timer    # Timer for scan timeout
var connecting_timer: Timer # Timer for connecting dots animation
var dot_count = 0           # Current dot count for animations (0-3)

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready():
	"""
	Initialize the WiFi networks interface
	"""
	print("[WiFi Networks] _ready called, list_vbox: ", list_vbox)

	# Hide all overlays initially
	overlay.visible = false
	status_container.visible = false

	# Start network scanning
	_scan_networks()

	# Connect to MenuController for remote control
	_connect_menu_controller_signals()

	# Connect retry button
	retry_button.pressed.connect(_on_retry_button_pressed)

func _connect_menu_controller_signals():
	"""
	Connect to MenuController signals for remote navigation and input
	"""
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

# =============================================================================
# NETWORK SCANNING
# =============================================================================

func _scan_networks():
	"""
	Start WiFi network scanning process
	"""
	print("[WiFi Networks] Starting network scan")

	# Show scanning UI
	status_container.visible = true
	retry_button.visible = false
	dot_count = 0
	status_label.text = tr("scanning_networks")

	# Create and start animation timer
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

	# Request network scan from server
	HttpService.wifi_scan(Callable(self, "_on_wifi_scan_completed"))

func _on_scan_timeout():
	"""
	Handle network scan timeout
	"""
	print("[WiFi Networks] Scan timeout occurred")

	# Cleanup timers
	_cleanup_scan_timers()

	# Show timeout UI
	status_label.text = tr("wifi_scan_timeout")
	retry_button.visible = true
	retry_button.grab_focus()
	print("[WiFi Networks] Timeout UI updated")

func _on_scan_timer_timeout():
	"""
	Update scanning animation dots
	"""
	dot_count = (dot_count + 1) % 4  # Cycle through 0, 1, 2, 3
	var dots = ""
	for i in range(dot_count):
		dots += "."
	status_label.text = tr("scanning_networks") + dots
	print("[WiFi Networks] Scanning animation: ", status_label.text)

func _on_retry_button_pressed():
	"""
	Handle retry button press - restart network scan
	"""
	print("[WiFi Networks] Retry button pressed")
	_scan_networks()

func _on_wifi_scan_completed(result, response_code, _headers, body):
	"""
	Handle completion of WiFi network scan
	"""
	# Check if node still exists (scene might have changed)
	if not is_instance_valid(self) or not is_inside_tree():
		print("[WiFi Networks] Node no longer valid, ignoring wifi_scan callback")
		return

	print("[WiFi Networks] Scan completed: result=", result, " code=", response_code)

	# Cleanup timers
	_cleanup_scan_timers()

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Parse successful response
		var body_str = body.get_string_from_utf8()
		print("[WiFi Networks] Response body: ", body_str)
		var json = JSON.parse_string(body_str)

		# Check for error in response message
		if json and json.has("msg") and "error" in json["msg"].to_lower():
			print("WiFi scan error: ", json.get("msg", "Unknown error"))
			_show_scan_error()
		elif json and json.has("data") and json["data"].has("ssid_list"):
			networks = json["data"]["ssid_list"]
			print("[WiFi Networks] Networks found: ", networks)

			# Hide scanning and build network list
			_build_list()
			status_container.visible = false

		else:
			print("Invalid response format")
			_show_scan_error()
	else:
		print("WiFi scan failed: ", result, " code: ", response_code)
		_show_scan_error()

func _cleanup_scan_timers():
	"""
	Cleanup scanning-related timers
	"""
	if scan_timer:
		scan_timer.stop()
		scan_timer.queue_free()
		scan_timer = null
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null

func _show_scan_error():
	"""
	Show scanning error UI
	"""
	status_label.text = tr("wifi_scan_failed")
	retry_button.visible = true
	retry_button.grab_focus()

# =============================================================================
# NETWORK LIST MANAGEMENT
# =============================================================================

func _build_list():
	"""
	Build the list of available WiFi networks
	"""
	print("[WiFi Networks] Building list with ", networks.size(), " networks")

	# Clear existing network buttons
	for child in list_vbox.get_children():
		child.queue_free()
	network_buttons.clear()

	# Reset scroll position to top
	if scroll_container:
		scroll_container.scroll_vertical = 0

	# Create button for each network
	for net_name in networks:
		var button = Button.new()
		button.text = net_name
		button.icon = WIFI_ICON_NETWORK
		# button.icon = WIFI_CONNECTED_ICON if net_name == connected_network else WIFI_ICON
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme = WIFI_BUTTON_THEME
		button.connect("pressed", Callable(self, "_on_network_selected").bind(net_name))
		list_vbox.add_child(button)
		network_buttons.append(button)

	# Set initial focus
	if network_buttons.size() > 0:
		focused_index = 0
		network_buttons[focused_index].grab_focus()

func _set_connected_network(ssid: String):
	"""
	Update UI to show connected network
	"""
	connected_network = ssid
	for button in network_buttons:
		if button and button.text == connected_network:
			button.icon = WIFI_CONNECTED_ICON
		else:
			button.icon = WIFI_ICON

# =============================================================================
# PASSWORD INPUT AND KEYBOARD HANDLING
# =============================================================================

func _on_network_selected(network_name):
	"""
	Handle network selection - show password input overlay
	"""
	selected_network = network_name

	# Hide the list
	list_vbox.visible = false

	# Show password overlay
	overlay.visible = true
	title_label.text = tr("enter_password").replace("{wifi_name}", selected_network)
	password_line.text = ""
	password_line.grab_focus()

	# Show and setup keyboard
	if keyboard:
		keyboard.visible = true
		call_deferred("_ensure_password_focus")
		call_deferred("_show_keyboard_for_input")
		print("[WiFi Networks] Keyboard shown, password LineEdit focused")

func _show_keyboard_for_input():
	"""
	Initialize and show the onscreen keyboard
	"""
	if not keyboard:
		return

	# Ensure keyboard detects input focus
	if keyboard.has_method("_show_keyboard"):
		keyboard._show_keyboard()
		print("[WiFi Networks] Keyboard _show_keyboard called")

	# Set last_input_focus as backup
	if "last_input_focus" in keyboard:
		keyboard.last_input_focus = password_line
		print("[WiFi Networks] Manually set keyboard last_input_focus to password LineEdit")

	# Connect keyboard button handlers
	_attach_keyboard_handlers()
	print("[WiFi Networks] Attached keyboard button handlers")

func _attach_keyboard_handlers(node = null):
	"""
	Recursively attach handlers to keyboard buttons
	"""
	if not keyboard:
		return

	if node == null:
		node = keyboard

	# Connect released signals for keyboard buttons
	for child in node.get_children():
		if child.has_signal("released"):
			var callback = Callable(self, "_on_keyboard_button_released")
			if not child.is_connected("released", callback):
				child.connect("released", callback)
		# Recurse into containers
		_attach_keyboard_handlers(child)

func _on_keyboard_button_released(key_data):
	"""
	Handle keyboard button releases
	"""
	if not key_data or typeof(key_data) != TYPE_DICTIONARY:
		return

	# Extract key data
	var out = key_data.get("output", "").strip_edges()
	var display_text = key_data.get("display", "").strip_edges()
	var display_icon = key_data.get("display-icon", "").strip_edges()
	var key_type = key_data.get("type", "").strip_edges()

	# Check for Enter key
	var is_enter = (out.to_lower() in ["enter", "return"] or
				   display_text.to_lower() == "enter" or
				   display_icon == "PREDEFINED:ENTER" or
				   (key_type == "special-hide-keyboard" and display_text.to_lower() == "enter"))

	if is_enter:
		print("[WiFi Networks] Onscreen keyboard Enter pressed")
		_commit_password()

func _on_keyboard_key_released(key_data):
	"""
	Handle keyboard key input for password field
	"""
	if overlay.visible and password_line and key_data and key_data.has("output"):
		var key_value = key_data.get("output")
		if key_value:
			# Insert character into password field
			var current_text = password_line.text
			var caret_pos = password_line.caret_position
			password_line.text = current_text.insert(caret_pos, key_value)
			password_line.caret_position = caret_pos + key_value.length()
			print("[WiFi Networks] Inserted key '", key_value, "' into password field")

func _ensure_password_focus():
	"""
	Ensure password field maintains focus
	"""
	if overlay.visible and password_line:
		password_line.grab_focus()
		print("[WiFi Networks] Password LineEdit focus ensured")

# =============================================================================
# WIFI CONNECTION
# =============================================================================

func _show_connecting_overlay():
	"""
	Show connecting animation overlay
	"""
	print("[WiFi Networks] Showing connecting overlay")

	# Hide password overlay, show connecting overlay
	overlay.visible = false
	status_container.visible = true
	dot_count = 0
	status_label.text = tr("wifi_connecting")

	# Create and start animation timer
	connecting_timer = Timer.new()
	connecting_timer.wait_time = 0.5
	connecting_timer.one_shot = false
	connecting_timer.connect("timeout", Callable(self, "_on_connecting_timer_timeout"))
	add_child(connecting_timer)
	connecting_timer.start()

func _on_connecting_timer_timeout():
	"""
	Update connecting animation dots
	"""
	dot_count = (dot_count + 1) % 4  # Cycle through 0, 1, 2, 3
	var dots = ""
	for i in range(dot_count):
		dots += "."
	status_label.text = tr("wifi_connecting") + dots
	print("[WiFi Networks] Connecting animation: ", status_label.text)

func _hide_connecting_overlay():
	"""
	Hide connecting overlay and cleanup
	"""
	print("[WiFi Networks] Hiding connecting overlay")
	if connecting_timer:
		connecting_timer.stop()
		connecting_timer.queue_free()
		connecting_timer = null
	status_container.visible = false

func _commit_password():
	"""
	Submit password and attempt WiFi connection
	"""
	var password = password_line.text
	print("[WiFi Networks] Submit pressed with password: '", password, "' (length: ", password.length(), ")")

	# Show connecting overlay and start connection
	_show_connecting_overlay()
	HttpService.wifi_connect(Callable(self, "_on_wifi_connect_completed"), selected_network, password)

func _on_wifi_connect_completed(result, response_code, _headers, body):
	"""
	Handle WiFi connection completion
	"""
	# Check if node still exists (scene might have changed)
	if not is_instance_valid(self) or not is_inside_tree():
		print("[WiFi Networks] Node no longer valid, ignoring wifi_connect callback")
		return

	_hide_connecting_overlay()

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Parse response
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		var success = false
		var error_msg = "Unknown error"

		# Bodystr "{"code":0,"data":{},"msg":"ok"}"

		if typeof(json) == TYPE_DICTIONARY:
			if json.has("code") and int(json["code"]) == 0:
				success = true
			else:
				error_msg = json.get("msg", error_msg)

		if success:
			print("Successfully connected to WiFi: ", selected_network)
			_set_connected_network(selected_network)

			# Emit connection signal
			var signal_bus = get_node_or_null("/root/SignalBus")
			if signal_bus:
				print("WiFi Networks: Emitting wifi_connected signal for SSID: ", selected_network)
				signal_bus.emit_wifi_connected(selected_network)
				get_tree().change_scene_to_file("res://scene/option/option.tscn")
			else:
				print("WiFi Networks: SignalBus not found, cannot emit signal")

			# Cleanup overlays
			_cancel_password()
		else:
			print("Failed to connect to WiFi: ", error_msg)
	else:
		print("WiFi connect request failed: ", result, " code: ", response_code)

# =============================================================================
# NAVIGATION AND INPUT HANDLING
# =============================================================================

func _on_navigate(direction: String):
	"""
	Handle navigation input from remote control
	"""
	print("[WiFi Networks] Navigation: ", direction)

	if overlay.visible:
		# Keyboard navigation handled by keyboard itself
		pass
	else:
		# Check for retry button focus
		if retry_button.visible:
			retry_button.grab_focus()
		else:
			# Navigate network list
			match direction:
				"up":
					navigate_buttons(-1)
				"down", "left", "right":
					navigate_buttons(1)

func _on_enter_pressed():
	"""
	Handle Enter key press
	"""
	print("[WiFi Networks] Enter pressed")

	if overlay.visible:
		# Route to keyboard if visible
		if keyboard and keyboard.visible:
			if keyboard.has_method("_simulate_enter"):
				keyboard._simulate_enter()
				return
			# Fallback: show keyboard
			if keyboard.has_method("_show_keyboard"):
				keyboard._show_keyboard()
				return
		# No keyboard: commit password
		_commit_password()
	else:
		# Check retry button
		if retry_button.visible and retry_button.has_focus():
			_on_retry_button_pressed()
		else:
			press_focused_button()

func _on_back_pressed():
	"""
	Handle Back button press
	"""
	if overlay.visible:
		_cancel_password()
	else:
		get_tree().change_scene_to_file("res://scene/option/option.tscn")

func _on_volume_up():
	"""
	Handle volume up request
	"""
	print("[WiFi Networks] Volume up requested")

func _on_volume_down():
	"""
	Handle volume down request
	"""
	print("[WiFi Networks] Volume down requested")

func _on_power_off():
	"""
	Handle power off request
	"""
	print("[WiFi Networks] Power off requested")

func _scroll_to_focused_button():
	"""
	Scroll the container to ensure the focused button is visible
	"""
	if not scroll_container or network_buttons.size() == 0 or focused_index >= network_buttons.size():
		return

	var focused_button = network_buttons[focused_index]
	if not focused_button:
		return

	# Get the scroll container's viewport height
	var viewport_height = scroll_container.size.y

	# Get the button's position relative to the scroll container
	var button_global_pos = focused_button.global_position
	var scroll_global_pos = scroll_container.global_position
	var button_relative_y = button_global_pos.y - scroll_global_pos.y + scroll_container.scroll_vertical

	# Calculate the button's height (assume all buttons have similar height)
	var button_height = focused_button.size.y if focused_button.size.y > 0 else 50

	# Check if button is above the visible area
	if button_relative_y < scroll_container.scroll_vertical:
		scroll_container.scroll_vertical = button_relative_y
	# Check if button is below the visible area
	elif button_relative_y + button_height > scroll_container.scroll_vertical + viewport_height:
		scroll_container.scroll_vertical = button_relative_y + button_height - viewport_height

	print("[WiFi Networks] Scrolled to show focused button at position ", button_relative_y)

func _cancel_password(clear_text: bool = true):
	"""
	Cancel password entry and hide overlay
	"""
	overlay.visible = false
	if clear_text and password_line:
		password_line.text = ""
	if keyboard:
		keyboard.visible = false
	if network_buttons.size() > 0:
		network_buttons[focused_index].grab_focus()

func navigate_buttons(direction: int):
	"""
	Navigate through network buttons with scrolling support
	"""
	if network_buttons.size() > 0:
		if overlay.visible:
			# Could navigate overlay elements here
			pass
		else:
			# Navigate network list with wraparound
			focused_index = (focused_index + direction + network_buttons.size()) % network_buttons.size()
			network_buttons[focused_index].grab_focus()

			# Scroll to ensure focused button is visible
			_scroll_to_focused_button()

			print("[WiFi Networks] Focus moved to button ", focused_index)

func press_focused_button():
	"""
	Simulate pressing the currently focused button
	"""
	if overlay.visible:
		# Route to keyboard
		if keyboard and keyboard.visible and keyboard.has_method("_simulate_enter"):
			keyboard._simulate_enter()
		else:
			_commit_password()
	else:
		if network_buttons.size() > 0:
			print("[WiFi Networks] Simulating network button press")
			var focused_button = network_buttons[focused_index]
			focused_button.pressed.emit()
