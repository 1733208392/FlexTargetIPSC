extends Control

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production
const QR_CODE_GENERATOR = preload("res://script/qrcode.gd")

# Networking configuration UI for setting channel and target name
# Features remote control navigation and onscreen keyboard for input

@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var workmode_label = $CenterContainer/VBoxContainer/WorkMode
@onready var name_label = $CenterContainer/VBoxContainer/NameLabel
@onready var workmode_dropdown = $CenterContainer/VBoxContainer/WorkModeDropdown
@onready var name_line_edit = $CenterContainer/VBoxContainer/NameLineEdit
@onready var qr_texture = $CenterContainer/VBoxContainer/QRCodeTexture
@onready var keyboard = $BottomContainer/OnscreenKeyboard
@onready var confirm_button = $CenterContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var dismiss_button = $CenterContainer/VBoxContainer/HBoxContainer/DismissButton

var focused_control = 0  # 0 = name_line_edit, 1 = workmode dropdown, 2 = confirm_button
var controls = []
var dropdown_open = false

# Status handling variables
var guard_timer: Timer
var animation_timer: Timer
var animation_dots = 0
var is_configuring = false
var is_stopping = false
var progress_text_key = ""

func _ready():
	# Initialize controls array - order: name_line_edit (0), workmode_dropdown (1), confirm_button (2)
	controls = [name_line_edit, workmode_dropdown, confirm_button]
	
	# Update UI texts with translations
	update_ui_texts()
	
	# Setup timers
	setup_timers()
	
	# Populate workmode dropdown with master/slave
	workmode_dropdown.add_item(tr("workmode_master"), 0)
	workmode_dropdown.add_item(tr("workmode_slave"), 1)
	
	# Load current settings
	load_current_settings()
	
	# Set initial focus to name_line_edit (index 0)
	set_focused_control(0)
	
	# Connect to MenuController signals for remote control
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller:
		menu_controller.navigate.connect(_on_navigate)
		menu_controller.enter_pressed.connect(_on_enter_pressed)
		menu_controller.back_pressed.connect(_on_back_pressed)
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Connected to MenuController signals")
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] MenuController singleton not found!")

	# Connect button signals to track focused_control when clicked
	if confirm_button:
		confirm_button.pressed.connect(Callable(self, "_on_confirm_button_pressed"))
		confirm_button.focus_entered.connect(Callable(self, "_on_confirm_button_focused"))
	if dismiss_button:
		dismiss_button.pressed.connect(Callable(self, "_on_dismiss_button_pressed"))
		dismiss_button.focus_entered.connect(Callable(self, "_on_dismiss_button_focused"))
	if name_line_edit:
		name_line_edit.focus_entered.connect(Callable(self, "_on_name_line_edit_focused"))
	if workmode_dropdown:
		workmode_dropdown.focus_entered.connect(Callable(self, "_on_workmode_dropdown_focused"))

	# Connect to GlobalData netlink status signal to populate fields when available
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		if global_data.has_signal("netlink_status_loaded"):
			global_data.netlink_status_loaded.connect(_on_netlink_status_loaded)
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] Connected to GlobalData.netlink_status_loaded signal")
		# If netlink_status is already present, populate immediately
		if global_data.netlink_status and global_data.netlink_status.size() > 0:
			_on_netlink_status_loaded()
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] GlobalData singleton not found; will not auto-populate netlink info")

func update_ui_texts():
	if status_label:
		update_status_label()
	if workmode_label:
		workmode_label.text = tr("net_config_workmode")
	if name_label:
		name_label.text = tr("net_config_target_name")
	if confirm_button:
		confirm_button.text = tr("net_config_done")
	if dismiss_button:
		dismiss_button.text = tr("dismiss")

func update_qr_code():
	if not qr_texture:
		return
		
	var text = ""
	var is_started = false
	var work_mode = ""
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.netlink_status:
		if global_data.netlink_status.has("bluetooth_name"):
			text = str(global_data.netlink_status["bluetooth_name"])
		if global_data.netlink_status.has("started"):
			is_started = global_data.netlink_status["started"]
		if global_data.netlink_status.has("work_mode"):
			work_mode = str(global_data.netlink_status["work_mode"]).to_lower()
	
	# Hide QR code if not started, no bluetooth_name, or work_mode is slave
	if not is_started or text.is_empty() or work_mode == "slave":
		qr_texture.texture = null
		qr_texture.visible = false
		return
		
	qr_texture.visible = true
	var qr = QR_CODE_GENERATOR.new()
	var image = qr.generate_image(text, 4)
	if image:
		qr_texture.texture = ImageTexture.create_from_image(image)

func update_status_label():
	if not status_label:
		return
		
	if is_configuring or is_stopping:
		return
		
	var text = tr("netlink_config")
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.netlink_status:
		if global_data.netlink_status.get("started", false):
			text += " (" + tr("started") + ")"
		else:
			text += " (" + tr("stopped") + ")"
	
	status_label.text = text

func setup_timers():
	# Setup guard timer (15 seconds)
	guard_timer = Timer.new()
	guard_timer.wait_time = 15.0
	guard_timer.one_shot = true
	guard_timer.timeout.connect(_on_guard_timer_timeout)
	add_child(guard_timer)
	
	# Setup animation timer (for dots animation)
	animation_timer = Timer.new()
	animation_timer.wait_time = 0.5
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	add_child(animation_timer)

func load_current_settings():
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.size() > 0:
		# Load workmode setting (default to "slave")
		var workmode_str = global_data.settings_dict.get("workmode", "slave")
		var workmode_index = 1  # Default to Slave
		if workmode_str == "master":
			workmode_index = 0
		workmode_dropdown.select(workmode_index)
		
		# Load target name setting (default to empty)
		var target_name = global_data.settings_dict.get("target_name", "")
		name_line_edit.text = target_name
		# Note: We don't update QR code here because it should only reflect the actual netlink status
		
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Loaded settings - Channel: 17, Workmode: ", workmode_str, ", Name: ", target_name)
	else:
		# Default to Slave if no settings
		workmode_dropdown.select(1)
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] No settings loaded, using defaults (Slave)")

func set_focused_control(index: int):
	if index >= 0 and index < controls.size():
		focused_control = index
		
		# Use deferred call for focus to ensure it happens after UI updates
		controls[index].grab_focus()
		
	# Handle dropdown visibility and keyboard
	if focused_control == 1:  # Workmode dropdown
		if dropdown_open:
			var rect = workmode_dropdown.get_global_rect()
			workmode_dropdown.get_popup().popup(rect)
		else:
			workmode_dropdown.get_popup().hide()
	else:
		workmode_dropdown.get_popup().hide()
		dropdown_open = false
	
	# Show keyboard if name field is focused
	if focused_control == 0:  # Name line edit
		# Do not show keyboard by default
		pass
	else:
		hide_keyboard()

func show_keyboard_for_name_input():
	if keyboard:
		keyboard.visible = true
		
		# Show keyboard
		if keyboard.has_method("_show_keyboard"):
			keyboard._show_keyboard()
		
		# Focus the 'q' key on the keyboard
		call_deferred("_focus_q_key")
		
		# Connect keyboard button handlers
		_attach_keyboard_handlers()
		
		# Connect text_submitted to hide keyboard
		if not name_line_edit.text_submitted.is_connected(_on_name_text_submitted):
			name_line_edit.text_submitted.connect(_on_name_text_submitted)
		
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Keyboard shown for name input")

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
			# Check if this is the hide keyboard button and disable it
			var is_hide_button = false
			if child.name.to_lower().contains("hide") or (child.has_method("get_text") and child.get_text().to_lower().contains("hide")):
				is_hide_button = true
			elif child.has_meta("key_type") and str(child.get_meta("key_type")).to_lower().contains("hide"):
				is_hide_button = true
			
			if is_hide_button:
				child.disabled = true
				if not DEBUG_DISABLED:
					print("[NetworkingConfig] Disabled hide keyboard button: ", child.name)
			else:
				var callback = Callable(self, "_on_keyboard_key_released")
				if not child.is_connected("released", callback):
					child.connect("released", callback)
		# Recurse into containers
		_attach_keyboard_handlers(child)

func _ensure_name_focus():
	"""
	Ensure name_line_edit maintains focus after keyboard is shown
	"""
	if name_line_edit:
		name_line_edit.grab_focus()
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Name LineEdit focus ensured")
		
		# Set last_input_focus as backup if keyboard supports it
		if keyboard and "last_input_focus" in keyboard:
			keyboard.last_input_focus = name_line_edit
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] Manually set keyboard last_input_focus to name LineEdit")

func _focus_q_key():
	"""
	Find and focus the 'q' key on the keyboard
	"""
	if not keyboard:
		return
	
	var q_key = _find_key_by_text(keyboard, "q")
	if q_key:
		q_key.grab_focus()
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Focused 'q' key on keyboard")
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] 'q' key not found on keyboard")

func _find_key_by_text(node, text: String):
	"""
	Recursively search for a keyboard key with the specified text
	"""
	for child in node.get_children():
		if child is Button and child.has_method("get_text"):
			if child.get_text().to_lower() == text.to_lower():
				return child
		# Recurse into containers
		var found = _find_key_by_text(child, text)
		if found:
			return found
	return null

func hide_keyboard():
	if keyboard:
		keyboard.visible = false

func _on_keyboard_key_released(key_data):
	if not key_data or typeof(key_data) != TYPE_DICTIONARY:
		return

	# Extract key data
	var out = key_data.get("output", "").strip_edges()
	var display_text = key_data.get("display", "").strip_edges()
	var _display_icon = key_data.get("display-icon", "").strip_edges()
	var key_type = key_data.get("type", "").strip_edges()

	# Check for Enter key
	var is_enter = (out.to_lower() in ["enter", "return"] or
				   display_text.to_lower() == "enter" or
				   _display_icon == "PREDEFINED:ENTER" or
				   (key_type == "special-hide-keyboard" and display_text.to_lower() == "enter"))

	# Handle special keys that need custom behavior
	if is_enter:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Keyboard enter pressed, hiding keyboard")
		hide_keyboard()
		name_line_edit.call_deferred("grab_focus")
		return
	
	# For all other keys (including backspace), let the keyboard addon handle input automatically
	# The addon sends InputEventKey to the focused LineEdit, so no manual text manipulation needed

func _on_navigate(direction: String):
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Navigation: ", direction)
	match direction:
		"up":
			if dropdown_open:
				if focused_control == 1:  # Workmode dropdown
					var current_selected = workmode_dropdown.selected
					if current_selected > 0:
						workmode_dropdown.select(current_selected - 1)
			else:
				if not keyboard.visible:
					set_focused_control((focused_control - 1 + controls.size()) % controls.size())
		"down":
			if dropdown_open:
				if focused_control == 1:  # Workmode dropdown
					var current_selected = workmode_dropdown.selected
					if current_selected < workmode_dropdown.item_count - 1:
						workmode_dropdown.select(current_selected + 1)
			else:
				if not keyboard.visible:
					set_focused_control((focused_control + 1) % controls.size())
		"left", "right":
			var current = get_viewport().gui_get_focus_owner()
			if current == confirm_button:
				dismiss_button.grab_focus()
			elif current == dismiss_button:
				confirm_button.grab_focus()
			else:
				if dropdown_open:
					if focused_control == 1:  # Workmode dropdown
						var current_selected = workmode_dropdown.selected
						if direction == "left" and current_selected > 0:
							workmode_dropdown.select(current_selected - 1)
						elif direction == "right" and current_selected < workmode_dropdown.item_count - 1:
							workmode_dropdown.select(current_selected + 1)

func _on_enter_pressed():
	if keyboard.visible:
		return
	var current = get_viewport().gui_get_focus_owner()
	if current == dismiss_button:
		_on_back_pressed()
		return
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Enter pressed")
	if focused_control == 1:  # Workmode dropdown
		if not dropdown_open:
			var rect = workmode_dropdown.get_global_rect()
			workmode_dropdown.get_popup().popup(rect)
			dropdown_open = true
		else:
			workmode_dropdown.get_popup().hide()
			dropdown_open = false
			set_focused_control(2)  # Move to confirm button
	else:  # focused_control == 0 (Name line edit) or 2 (Confirm button)
		if focused_control == 0:
			show_keyboard_for_name_input()
		else:
			configure_network()

func _on_back_pressed():
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Back pressed - navigating to main menu")
	get_tree().change_scene_to_file("res://scene/option/option.tscn")

func _on_netlink_status_loaded():
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Received netlink_status_loaded signal, populating UI")
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] GlobalData not found in _on_netlink_status_loaded")
		return
	var status = global_data.netlink_status
	
	# Check if configured
	var wm_val = status.get("work_mode")
	var dev_val = status.get("device_name")
	
	if wm_val == null and dev_val == null:
		# Case 1: Not configured before -> Default to Slave
		workmode_dropdown.select(1)
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink not configured, defaulting to Slave")
	else:
		# Case 2 & 3: Configured -> Use values
		if wm_val:
			var wm = str(wm_val).to_lower()
			if wm == "slave":
				workmode_dropdown.select(1)
			else:
				workmode_dropdown.select(0)
		
		if dev_val:
			name_line_edit.text = str(dev_val)
	
	update_qr_code()
	update_status_label()
	
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Populated netlink info from GlobalData: ", status)

func save_settings():
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] GlobalData not found, cannot save settings")
		return
	
	# Get values from UI
	var channel = 17
	var workmode_index = workmode_dropdown.get_selected_id()
	var workmode = "master" if workmode_index == 0 else "slave"
	var target_name = name_line_edit.text.strip_edges()
	
	# Update settings_dict
	global_data.settings_dict["channel"] = channel
	global_data.settings_dict["workmode"] = workmode
	global_data.settings_dict["target_name"] = target_name
	
	# Save to HTTP service
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var settings_data = global_data.settings_dict.duplicate()
		var content = JSON.stringify(settings_data)
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Saving settings: ", settings_data)
		http_service.save_game(_on_save_settings_callback, "settings", content)
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] HttpService not found, settings saved locally only")

func _on_save_settings_callback(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Settings saved successfully")
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Failed to save settings - Result: ", result, ", Code: ", response_code)

func configure_network():
	if is_configuring or is_stopping:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Configuration or stopping already in progress, ignoring request")
		return
	
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] GlobalData not found, cannot check for changes")
		return
	
	# Get current values from UI
	var workmode_index = workmode_dropdown.get_selected_id()
	var ui_workmode = "master" if workmode_index == 0 else "slave"
	var ui_target_name = name_line_edit.text.strip_edges()
	
	# Get current values from netlink_status
	var current_workmode = global_data.netlink_status.get("work_mode", "slave")
	var current_target_name = global_data.netlink_status.get("device_name", "")
	
	# Check if there are any changes
	if ui_workmode == current_workmode and ui_target_name == current_target_name:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] No changes detected (workmode: ", ui_workmode, ", name: ", ui_target_name, "), skipping configuration")
		return
	
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Changes detected!")
		print("[NetworkingConfig]   Workmode: ", current_workmode, " -> ", ui_workmode)
		print("[NetworkingConfig]   Target name: ", current_target_name, " -> ", ui_target_name)
	
	# Start the configuration sequence
	is_configuring = true
	start_progress_animation("netlink_config_progress")
	start_guard_timer()
	
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] HttpService not found, cannot configure network")
		is_configuring = false
		return
	
	# Check if netlink is currently started
	var netlink_started = global_data.netlink_status.has("started") and global_data.netlink_status["started"]
	
	if netlink_started:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink is started, will stop first in sequence...")
		# Call netlink_stop without callback - will proceed to config in do_netlink_config_sequence
		http_service.netlink_stop(func(_result, _response_code, _headers, _body): pass)
		# Give the stop call a moment, then proceed to config
		await get_tree().create_timer(0.5).timeout
		do_netlink_config_sequence()
	else:
		# Proceed directly to configuration
		do_netlink_config_sequence()

func do_netlink_config():
	# This method is kept for backward compatibility but not used in the new flow
	# The new flow uses do_netlink_config_sequence() instead
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] do_netlink_config called - this is legacy, use do_netlink_config_sequence instead")

func do_netlink_config_sequence():
	# Call netlink_config without processing its callback
	var channel = 17
	var workmode_index = workmode_dropdown.get_selected_id()
	var workmode = "master" if workmode_index == 0 else "slave"
	var target_name = name_line_edit.text.strip_edges()
	
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Calling netlink_config in sequence (channel: ", channel, ", workmode: ", workmode, ", name: ", target_name, ")")
	
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		# Call netlink_config with a dummy callback (no processing)
		http_service.netlink_config(func(_result, _response_code, _headers, _body): pass, channel, target_name, workmode)
		# Give the config call a moment to execute, then call netlink_start
		await get_tree().create_timer(0.5).timeout
		do_netlink_start()
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] HttpService not found in do_netlink_config_sequence")
		_finish_configuration()

func do_netlink_start():
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Calling netlink_start in sequence")
	
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.netlink_start(_on_netlink_start_callback)
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] HttpService not found in do_netlink_start")
		_finish_configuration()

func _on_netlink_start_callback(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink start successful, waiting 3s for network configuration to complete...")
		
		# Wait 3 seconds for the network configuration to complete
		await get_tree().create_timer(3.0).timeout
		
		# Request status to get the actual bluetooth_name
		var http_service = get_node_or_null("/root/HttpService")
		if http_service:
			http_service.netlink_status(_on_netlink_status_response)
		else:
			_finish_configuration()
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink start failed - Result: ", result, ", Code: ", response_code)
		set_status_failed()
		is_configuring = false

func _on_netlink_status_response(result, response_code, _headers, body):
	stop_timers()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var status = json.get_data()["data"]
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.netlink_status = status
				global_data.netlink_status_loaded.emit()
				if not DEBUG_DISABLED:
					print("[NetworkingConfig] Updated GlobalData.netlink_status from response: ", status)
	
	_finish_configuration()

func _finish_configuration():
	is_configuring = false
	var global_data = get_node_or_null("/root/GlobalData")
	var netlink_started = false
	if global_data and global_data.netlink_status.has("started"):
		netlink_started = global_data.netlink_status["started"]
	
	# GlobalData will emit netlink_status_loaded signal which listeners can use
	# No need to emit network_started here since GlobalData already tracks state
	if not netlink_started:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink not started, configuration complete")
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink started successfully, configuration complete")
	
	# Update status label to show final status
	update_status_label()

# Timer and animation functions
func start_progress_animation(text_key: String):
	status_label.text = tr(text_key)
	animation_dots = 0
	progress_text_key = text_key
	animation_timer.start()

func start_guard_timer():
	guard_timer.start()

func stop_timers():
	if guard_timer:
		guard_timer.stop()
	if animation_timer:
		animation_timer.stop()

func _on_guard_timer_timeout():
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Guard timer timed out (15s)")
	stop_timers()
	if is_stopping:
		set_status_stop_failed()
		is_stopping = false
	else:
		set_status_timeout()
		is_configuring = false

func _on_animation_timer_timeout():
	animation_dots = (animation_dots + 1) % 4
	var dots = ".".repeat(animation_dots)
	status_label.text = tr(progress_text_key) + dots

func set_status_failed():
	stop_timers()
	status_label.text = tr("netlink_config_failed")

func set_status_timeout():
	status_label.text = tr("netlink_config_timeout")

func _on_name_text_submitted(_new_text: String):
	hide_keyboard()
	name_line_edit.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_enter_pressed()

# Focus and button press handlers to sync focused_control with UI interaction
func _on_name_line_edit_focused() -> void:
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Name LineEdit focused via mouse click")
	set_focused_control(0)

func _on_workmode_dropdown_focused() -> void:
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] WorkMode dropdown focused via mouse click")
	set_focused_control(1)

func _on_confirm_button_focused() -> void:
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Confirm button focused via mouse click")
	set_focused_control(2)

func _on_confirm_button_pressed() -> void:
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Confirm button pressed via mouse click")
	focused_control = 2
	configure_network()

func _on_dismiss_button_focused() -> void:
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Dismiss button focused via mouse click")
	# For dismiss button, we just set focus without changing focused_control tracking
	# since it has its own back behavior

func _on_dismiss_button_pressed() -> void:
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Dismiss button pressed via mouse click")
	_on_back_pressed()

func set_status_stop_failed():
	stop_timers()
	status_label.text = tr("stopping_netlink_failed")
