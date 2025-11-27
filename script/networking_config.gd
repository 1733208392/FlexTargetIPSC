extends Control

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

# Networking configuration UI for setting channel and target name
# Features remote control navigation and onscreen keyboard for input

@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var channel_label = $CenterContainer/VBoxContainer/ChannelLabel
@onready var workmode_label = $CenterContainer/VBoxContainer/WorkMode
@onready var name_label = $CenterContainer/VBoxContainer/NameLabel
@onready var channel_dropdown = $CenterContainer/VBoxContainer/ChannelDropdown
@onready var workmode_dropdown = $CenterContainer/VBoxContainer/WorkModeDropdown
@onready var name_line_edit = $CenterContainer/VBoxContainer/NameLineEdit
@onready var keyboard = $BottomContainer/OnscreenKeyboard
@onready var confirm_button = $CenterContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var dismiss_button = $CenterContainer/VBoxContainer/HBoxContainer/DismissButton

var focused_control = 0  # 0 = channel dropdown, 1 = workmode dropdown, 2 = name line edit
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
	# Initialize controls array
	controls = [channel_dropdown, workmode_dropdown, name_line_edit, confirm_button]
	
	# Update UI texts with translations
	update_ui_texts()
	
	# Setup timers
	setup_timers()
	
	# Populate channel dropdown with values 1-10
	for i in range(1, 11):
		channel_dropdown.add_item(str(i), i)
	
	# Populate workmode dropdown with master/slave
	workmode_dropdown.add_item("Master", 0)
	workmode_dropdown.add_item("Slave", 1)
	
	# Load current settings
	load_current_settings()
	
	# Set initial focus
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
		status_label.text = tr("netlink_config")
	if channel_label:
		channel_label.text = tr("net_config_channel")
	if workmode_label:
		workmode_label.text = tr("net_config_workmode")
	if name_label:
		name_label.text = tr("net_config_target_name")
	if confirm_button:
		confirm_button.text = tr("net_config_done")
	if dismiss_button:
		dismiss_button.text = tr("dismiss")

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
		# Load channel setting (default to 1)
		var channel = int(global_data.settings_dict.get("channel", 1))
		if channel >= 1 and channel <= 10:
			channel_dropdown.select(channel - 1)  # OptionButton is 0-indexed
		
		# Load workmode setting (default to "master")
		var workmode_str = global_data.settings_dict.get("workmode", "master")
		var workmode_index = 0  # Default to Master
		if workmode_str == "slave":
			workmode_index = 1
		workmode_dropdown.select(workmode_index)
		
		# Load target name setting (default to empty)
		var target_name = global_data.settings_dict.get("target_name", "")
		name_line_edit.text = target_name
		
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Loaded settings - Channel: ", channel, ", Workmode: ", workmode_str, ", Name: ", target_name)
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] No settings loaded, using defaults")

func set_focused_control(index: int):
	if index >= 0 and index < controls.size():
		focused_control = index
		
		# Use deferred call for focus to ensure it happens after UI updates
		controls[index].grab_focus()
		
		# Handle dropdown visibility
		if focused_control == 0 or focused_control == 1:  # Channel or Workmode dropdown
			if dropdown_open:
				if focused_control == 0:
					var rect = channel_dropdown.get_global_rect()
					channel_dropdown.get_popup().popup(rect)
				else:  # focused_control == 1
					var rect = workmode_dropdown.get_global_rect()
					workmode_dropdown.get_popup().popup(rect)
			else:
				channel_dropdown.get_popup().hide()
				workmode_dropdown.get_popup().hide()
		else:
			channel_dropdown.get_popup().hide()
			workmode_dropdown.get_popup().hide()
			dropdown_open = false
		
		# Show keyboard if name field is focused
		if focused_control == 2:  # Name line edit
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
			if not keyboard.visible:
				set_focused_control((focused_control - 1 + controls.size()) % controls.size())
				return
			if dropdown_open:
				if focused_control == 0:  # Channel dropdown
					var current_selected = channel_dropdown.selected
					if current_selected > 0:
						channel_dropdown.select(current_selected - 1)
				elif focused_control == 1:  # Workmode dropdown
					var current_selected = workmode_dropdown.selected
					if current_selected > 0:
						workmode_dropdown.select(current_selected - 1)
			else:
				# Don't switch focus if keyboard is visible (let keyboard handle navigation)
				if not keyboard.visible:
					set_focused_control((focused_control - 1 + controls.size()) % controls.size())
		"down":
			if not keyboard.visible:
				set_focused_control((focused_control + 1) % controls.size())
				return
			if dropdown_open:
				if focused_control == 0:  # Channel dropdown
					var current_selected = channel_dropdown.selected
					if current_selected < channel_dropdown.item_count - 1:
						channel_dropdown.select(current_selected + 1)
				elif focused_control == 1:  # Workmode dropdown
					var current_selected = workmode_dropdown.selected
					if current_selected < workmode_dropdown.item_count - 1:
						workmode_dropdown.select(current_selected + 1)
			else:
				# Don't switch focus if keyboard is visible (let keyboard handle navigation)
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
					if focused_control == 0:  # Channel dropdown
						var current_selected = channel_dropdown.selected
						if direction == "left" and current_selected > 0:
							channel_dropdown.select(current_selected - 1)
						elif direction == "right" and current_selected < channel_dropdown.item_count - 1:
							channel_dropdown.select(current_selected + 1)
					elif focused_control == 1:  # Workmode dropdown
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
	if focused_control == 0:  # Channel dropdown
		if not dropdown_open:
			var rect = channel_dropdown.get_global_rect()
			channel_dropdown.get_popup().popup(rect)
			dropdown_open = true
		else:
			channel_dropdown.get_popup().hide()
			dropdown_open = false
			set_focused_control(1)  # Move to workmode
	elif focused_control == 1:  # Workmode dropdown
		if not dropdown_open:
			var rect = workmode_dropdown.get_global_rect()
			workmode_dropdown.get_popup().popup(rect)
			dropdown_open = true
		else:
			workmode_dropdown.get_popup().hide()
			dropdown_open = false
			set_focused_control(2)  # Move to name field
	else:  # focused_control == 2 (Name line edit) or 3 (Confirm button)
		if focused_control == 2:
			show_keyboard_for_name_input()
		else:
			configure_network()

func _on_back_pressed():
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.return_to_network_button = true
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
	# Populate channel if present and within 1-10
	if status.has("channel"):
		var ch = int(status["channel"])
		if ch >= 1 and ch <= 10:
			channel_dropdown.select(ch - 1)
	# Populate work_mode if present
	if status.has("work_mode"):
		var wm = str(status["work_mode"]).to_lower()
		if wm == "slave":
			workmode_dropdown.select(1)
		else:
			workmode_dropdown.select(0)
	# Populate device name
	if status.has("device_name"):
		name_line_edit.text = str(status["device_name"])
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Populated netlink info from GlobalData: ", status)

func save_settings():
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] GlobalData not found, cannot save settings")
		return
	
	# Get values from UI
	var channel = channel_dropdown.get_selected_id()
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
		
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] HttpService not found, cannot configure network")
		return
	
	# Check if netlink is currently started
	var global_data = get_node_or_null("/root/GlobalData")
	var netlink_started = false
	if global_data and global_data.netlink_status.has("started"):
		netlink_started = global_data.netlink_status["started"]
	
	if netlink_started:
		# Need to stop netlink first
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink is started, stopping first...")
		is_stopping = true
		start_progress_animation("stopping_netlink")
		start_guard_timer()
		http_service.netlink_stop(_on_netlink_stop_callback)
	else:
		# Proceed directly to configuration
		do_netlink_config()

func do_netlink_config():
	# Start configuration process
	is_configuring = true
	start_progress_animation("netlink_config_progress")
	start_guard_timer()
	
	# Get values from UI
	var channel = channel_dropdown.get_selected_id()
	var workmode_index = workmode_dropdown.get_selected_id()
	var workmode = "master" if workmode_index == 0 else "slave"
	var target_name = name_line_edit.text.strip_edges()
	
	if not DEBUG_DISABLED:
		print("[NetworkingConfig] Configuring network with channel: ", channel, ", workmode: ", workmode, ", target_name: ", target_name)
	
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.netlink_config(_on_netlink_config_callback, channel, target_name, workmode)

func _on_netlink_stop_callback(result, response_code, _headers, _body):
	stop_timers()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink stop successful, proceeding to config...")
		
		# Update GlobalData to mark netlink as stopped
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.netlink_status["started"] = false
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] Updated GlobalData.netlink_status.started to false")
		
		is_stopping = false
		# Now proceed to configuration
		do_netlink_config()
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink stop failed - Result: ", result, ", Code: ", response_code)
		set_status_stop_failed()
		is_stopping = false

func _on_netlink_config_callback(result, response_code, _headers, _body):
	stop_timers()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink config successful, updating GlobalData and starting netlink...")
		
		# Update GlobalData.netlink_status with the new configuration
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			var channel = channel_dropdown.get_selected_id()
			var workmode_index = workmode_dropdown.get_selected_id()
			var workmode = "master" if workmode_index == 0 else "slave"
			var target_name = name_line_edit.text.strip_edges()
			
			# Update netlink_status with new configuration
			global_data.netlink_status["channel"] = channel
			global_data.netlink_status["work_mode"] = workmode
			global_data.netlink_status["device_name"] = target_name
			global_data.netlink_status["bluetooth_name"] = target_name
			global_data.netlink_status["started"] = false  # Will be updated when start succeeds
			
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] Updated GlobalData.netlink_status: ", global_data.netlink_status)
		
		var http_service = get_node_or_null("/root/HttpService")
		if http_service:
			http_service.netlink_start(_on_netlink_start_callback)
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink config failed - Result: ", result, ", Code: ", response_code)
		set_status_failed()
		is_configuring = false

func _on_netlink_start_callback(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink start successful")
		
		# Update GlobalData to mark netlink as started
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.netlink_status["started"] = true
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] Updated GlobalData.netlink_status.started to true")
			# Emit the signal to notify other components
			global_data.netlink_status_loaded.emit()
		
		is_configuring = false
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] Emitting network_started via SignalBus")
			signal_bus.emit_network_started()
		else:
			if not DEBUG_DISABLED:
				print("[NetworkingConfig] SignalBus not found, cannot emit wifi_connected signal")
		get_tree().change_scene_to_file("res://scene/option/option.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[NetworkingConfig] Netlink start failed - Result: ", result, ", Code: ", response_code)
		set_status_failed()
		is_configuring = false

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

func set_status_stop_failed():
	stop_timers()
	status_label.text = tr("stopping_netlink_failed")
