extends Control

# Networking configuration UI for setting channel and target name
# Features remote control navigation and onscreen keyboard for input

@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var channel_dropdown = $CenterContainer/VBoxContainer/ChannelDropdown
@onready var workmode_dropdown = $CenterContainer/VBoxContainer/WorkModeDropdown
@onready var name_line_edit = $CenterContainer/VBoxContainer/NameLineEdit
@onready var keyboard = $OnscreenKeyboard
@onready var done_button = $CenterContainer/VBoxContainer/DoneButton

var focused_control = 0  # 0 = channel dropdown, 1 = workmode dropdown, 2 = name line edit, 3 = done button
var controls = []
var dropdown_open = false

# Status handling variables
var guard_timer: Timer
var animation_timer: Timer
var animation_dots = 0
var is_configuring = false

func _ready():
	# Initialize controls array
	controls = [channel_dropdown, workmode_dropdown, name_line_edit, done_button]
	
	# Initialize status label
	status_label.text = "Netlink Config"
	
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
		print("[NetworkingConfig] Connected to MenuController signals")
	else:
		print("[NetworkingConfig] MenuController singleton not found!")

	# Connect to GlobalData netlink status signal to populate fields when available
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		if global_data.has_signal("netlink_status_loaded"):
			global_data.netlink_status_loaded.connect(_on_netlink_status_loaded)
			print("[NetworkingConfig] Connected to GlobalData.netlink_status_loaded signal")
		# If netlink_status is already present, populate immediately
		if global_data.netlink_status and global_data.netlink_status.size() > 0:
			_on_netlink_status_loaded()
	else:
		print("[NetworkingConfig] GlobalData singleton not found; will not auto-populate netlink info")

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
		var channel = global_data.settings_dict.get("channel", 1)
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
		
		print("[NetworkingConfig] Loaded settings - Channel: ", channel, ", Workmode: ", workmode_str, ", Name: ", target_name)
	else:
		print("[NetworkingConfig] No settings loaded, using defaults")

func set_focused_control(index: int):
	if index >= 0 and index < controls.size():
		focused_control = index
		controls[focused_control].grab_focus()
		
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
			show_keyboard_for_name_input()
		else:
			hide_keyboard()

func show_keyboard_for_name_input():
	if keyboard:
		keyboard.visible = true
		name_line_edit.grab_focus()
		
		# Connect to keyboard signals if not already connected
		if keyboard.has_signal("released") and not keyboard.released.is_connected(_on_keyboard_key_released):
			keyboard.released.connect(_on_keyboard_key_released)
		
		# Show keyboard
		if keyboard.has_method("_show_keyboard"):
			keyboard._show_keyboard()
		
		print("[NetworkingConfig] Keyboard shown for name input")

func hide_keyboard():
	if keyboard:
		keyboard.visible = false

func _on_keyboard_key_released(key_data):
	if key_data and key_data.has("output"):
		var key_value = key_data.get("output")
		if key_value and name_line_edit.has_focus():
			# Insert the character into the name field
			var current_text = name_line_edit.text
			var caret_pos = name_line_edit.caret_position
			name_line_edit.text = current_text.insert(caret_pos, key_value)
			name_line_edit.caret_position = caret_pos + key_value.length()
			print("[NetworkingConfig] Inserted key '", key_value, "' into name field")

func _on_navigate(direction: String):
	print("[NetworkingConfig] Navigation: ", direction)
	match direction:
		"up":
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
	elif focused_control == 2:  # Name line edit
		save_settings()
	else:  # focused_control == 3 (Done button)
		configure_network()

func _on_back_pressed():
	print("[NetworkingConfig] Back pressed - navigating to main menu")
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_netlink_status_loaded():
	print("[NetworkingConfig] Received netlink_status_loaded signal, populating UI")
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
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
	print("[NetworkingConfig] Populated netlink info from GlobalData: ", status)

func save_settings():
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
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
		print("[NetworkingConfig] Saving settings: ", settings_data)
		http_service.save_game(_on_save_settings_callback, "settings", content)
	else:
		print("[NetworkingConfig] HttpService not found, settings saved locally only")

func _on_save_settings_callback(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[NetworkingConfig] Settings saved successfully")
	else:
		print("[NetworkingConfig] Failed to save settings - Result: ", result, ", Code: ", response_code)

func configure_network():
	if is_configuring:
		print("[NetworkingConfig] Configuration already in progress, ignoring request")
		return
		
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		print("[NetworkingConfig] HttpService not found, cannot configure network")
		return
	
	# Start configuration process
	is_configuring = true
	start_progress_animation()
	start_guard_timer()
	
	# Get values from UI
	var channel = channel_dropdown.get_selected_id()
	var workmode_index = workmode_dropdown.get_selected_id()
	var workmode = "master" if workmode_index == 0 else "slave"
	var target_name = name_line_edit.text.strip_edges()
	
	print("[NetworkingConfig] Configuring network with channel: ", channel, ", workmode: ", workmode, ", target_name: ", target_name)
	http_service.netlink_config(_on_netlink_config_callback, channel, target_name, workmode)

func _on_netlink_config_callback(result, response_code, _headers, _body):
	stop_timers()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
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
			
			print("[NetworkingConfig] Updated GlobalData.netlink_status: ", global_data.netlink_status)
		
		var http_service = get_node_or_null("/root/HttpService")
		if http_service:
			http_service.netlink_start(_on_netlink_start_callback)
	else:
		print("[NetworkingConfig] Netlink config failed - Result: ", result, ", Code: ", response_code)
		set_status_failed()
		is_configuring = false

func _on_netlink_start_callback(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[NetworkingConfig] Netlink start successful")
		
		# Update GlobalData to mark netlink as started
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.netlink_status["started"] = true
			print("[NetworkingConfig] Updated GlobalData.netlink_status.started to true")
			# Emit the signal to notify other components
			global_data.netlink_status_loaded.emit()
		
		is_configuring = false
		var signal_bus = get_node_or_null("/root/SignalBus")
		if signal_bus:
			print("[NetworkingConfig] Emitting network_started via SignalBus")
			signal_bus.emit_network_started()
		else:
			print("[NetworkingConfig] SignalBus not found, cannot emit wifi_connected signal")
		get_tree().change_scene_to_file("res://scene/option.tscn")
	else:
		print("[NetworkingConfig] Netlink start failed - Result: ", result, ", Code: ", response_code)
		set_status_failed()
		is_configuring = false

# Timer and animation functions
func start_progress_animation():
	status_label.text = "Netlink Config In Progress"
	animation_dots = 0
	animation_timer.start()

func start_guard_timer():
	guard_timer.start()

func stop_timers():
	if guard_timer:
		guard_timer.stop()
	if animation_timer:
		animation_timer.stop()

func _on_guard_timer_timeout():
	print("[NetworkingConfig] Guard timer timed out (15s)")
	stop_timers()
	set_status_timeout()
	is_configuring = false

func _on_animation_timer_timeout():
	animation_dots = (animation_dots + 1) % 4
	var dots = ".".repeat(animation_dots)
	status_label.text = "Netlink Config In Progress" + dots

func set_status_failed():
	stop_timers()
	status_label.text = "Netlink Config Failed"

func set_status_timeout():
	status_label.text = "Netlink Config Timeout"

# Allow closing with ESC
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_back_pressed()
