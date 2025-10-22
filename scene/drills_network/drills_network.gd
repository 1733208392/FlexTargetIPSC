extends Control

const DEBUG_DISABLED = false

# Single target for network drills
@export var target_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")

# Target type to scene mapping
var target_type_to_scene = {
	"ipsc": "res://scene/ipsc_mini.tscn",
	"special_1": "res://scene/ipsc_mini_black_1.tscn",
	"special_2": "res://scene/ipsc_mini_black_2.tscn",
	"hostage": "res://scene/hostage.tscn",
	"rotation": "res://scene/ipsc_mini_rotate.tscn",
	"paddle": "res://scene/3paddles.tscn",
	"popper": "res://scene/2poppers_simple.tscn"
}

# Node references
@onready var center_container = $CenterContainer
@onready var drill_timer = $DrillUI/DrillTimer
@onready var network_complete_overlay = $DrillNetworkCompleteOverlay
@onready var device_name_label = $DeviceNameLabel

# Global data reference
var global_data: Node = null

# Target instance
var target_instance: Node = null
var total_score: int = 0
var drill_completed: bool = false
var shot_timer_visible: bool = false
var current_target_type: String = "ipsc_mini"  # Default fallback

# Elapsed time tracking
var elapsed_seconds: float = 0.0
var drill_start_time: float = 0.0

# Timeout functionality
var timeout_timer: Timer = null
var timeout_seconds: float = 40.0
var drill_timed_out: bool = false

# Master/Slave mode
var is_first: bool = false

# Saved parameters from BLE 'ready' until a 'start' is received
var saved_ble_ready_content: Dictionary = {}

# Current repeat tracking
var current_repeat: int = 0

# Performance tracking
signal drills_finished
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float, repeat: int)

# UI update signals
signal ui_timer_update(elapsed_seconds: float)
signal ui_timer_stopped(final_time: float)
signal ui_target_title_update(target_index: int, total_targets: int)
signal ui_target_name_update(target_name: String)
signal ui_show_shot_timer()
signal ui_hide_shot_timer()
signal ui_mode_update(is_first: bool)
signal ui_theme_change(theme_name: String)

@onready var performance_tracker = preload("res://script/performance_tracker_network.gd").new()

func _ready():
	"""Initialize the network drill with a single target"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Starting network drill")
	
	# Get global data reference
	global_data = get_node_or_null("/root/GlobalData")
	
	# Add performance tracker to scene tree first
	add_child(performance_tracker)
	
	# Connect performance tracker
	target_hit.connect(performance_tracker._on_target_hit)
	
	# Connect to WebSocketListener for menu control (deferred to ensure it's ready)
	call_deferred("_connect_to_websocket")
	
	# Connect to GlobalData netlink_status_loaded signal
	if global_data:
		global_data.netlink_status_loaded.connect(_on_netlink_status_loaded)
	
	# Connect to shot timer ready signal
	var shot_timer = get_node("DrillUI/ShotTimerOverlay")
	if shot_timer and shot_timer.has_signal("timer_ready"):
		shot_timer.timer_ready.connect(_on_shot_timer_ready)
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Connected to shot timer ready signal")
	
	# Set theme
	emit_signal("ui_theme_change", "golden")
	
	# Initialize progress (1 target)
	# Note: progress UI updates are not emitted for network drills
	emit_signal("ui_target_title_update", 1, 1)

	# Hide only the HeaderContainer inside TopContainer for network drills
	var drill_ui_node = get_node_or_null("DrillUI")
	if drill_ui_node and drill_ui_node.has_node("TopContainer/TopLayout/HeaderContainer"):
		var header = drill_ui_node.get_node("TopContainer/TopLayout/HeaderContainer")
		if header:
			header.visible = false
	
	# Set device name
	if global_data and global_data.netlink_status.has("device_name"):
		device_name_label.text = global_data.netlink_status["device_name"]
	else:
		device_name_label.text = tr("unknown_device")
	
	# Check if there's a saved ready state from main_menu and process it
	call_deferred("_check_and_process_saved_ready_state")

func _connect_to_websocket():
	"""Connect to WebSocketListener signals (called deferred to ensure WebSocketListener is ready)"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Attempting deferred connection to WebSocketListener")
	
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Found WebSocketListener at /root/WebSocketListener")
		
		# Check if signals exist before connecting
		if ws_listener.has_signal("menu_control"):
			ws_listener.menu_control.connect(_on_menu_control)
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] Connected to menu_control signal")
		else:
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have menu_control signal")
		
		if ws_listener.has_signal("ble_ready_command"):
			ws_listener.ble_ready_command.connect(_on_ble_ready_command)
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] Connected to ble_ready_command signal")
		else:
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have ble_ready_command signal")
		
		# Connect to ble_start_command so the drill only starts when an explicit 'start' is received
		if ws_listener.has_signal("ble_start_command"):
			ws_listener.ble_start_command.connect(_on_ble_start_command)
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] Connected to ble_start_command signal")
		else:
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have ble_start_command signal")
	else:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] ERROR: WebSocketListener not found at /root/WebSocketListener")
		# Try again after a short delay
		await get_tree().create_timer(0.1).timeout
		_connect_to_websocket()

func _check_and_process_saved_ready_state():
	"""Check if there's a saved ready state from main_menu and process it"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Checking for saved ready state from main_menu")
	
	if not global_data:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] GlobalData not available, cannot check for saved ready state")
		return
	
	# Check if ready content was saved by main_menu in GlobalData.ble_ready_content
	var saved_ready_content = global_data.ble_ready_content
	
	if saved_ready_content != null and saved_ready_content.size() > 0:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Found saved ready state, processing it: ", saved_ready_content)
		
		# Process it as if we received the ready command
		_on_ble_ready_command(saved_ready_content)
		
		# Start auto-start fallback timer (drill will start if no 'start' command arrives)
		_start_auto_start_fallback()
	else:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] No saved ready state found in GlobalData")

func _start_auto_start_fallback():
	"""Start a fallback timer that will auto-start the drill in master mode if no 'start' command arrives"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Starting auto-start fallback timer (2 seconds)")
	
	await get_tree().create_timer(2.0).timeout
	
	# If drill has not been started yet (no BLE start command received), start it now
	if not drill_completed and target_instance == null:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Auto-start fallback triggered - no BLE start command received, starting drill")
		
		# Use is_first from saved ready content, default to true (master mode) if not present
		is_first = saved_ble_ready_content.get("isFirst", true)
		emit_signal("ui_mode_update", is_first)
		
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Operating in ", "master" if is_first else "slave", " mode (based on saved isFirst: ", is_first, ")")
		
		# Use saved timeout or default
		if saved_ble_ready_content.has("timeout"):
			timeout_seconds = float(saved_ble_ready_content["timeout"])
		else:
			timeout_seconds = 40.0
		
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Auto-starting drill with timeout: ", timeout_seconds)
		
		start_drill()
		if is_first:
			shot_timer_visible = true
	else:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Auto-start fallback cancelled - drill already started or will be started by BLE command")
			
func _on_netlink_status_loaded():
	"""Update device name when netlink status is loaded"""
	if global_data and global_data.netlink_status.has("device_name"):
		device_name_label.text = global_data.netlink_status["device_name"]
	else:
		device_name_label.text = tr("unknown_device")
			
func spawn_target():
	"""Spawn the single target"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Spawning target")
	
	# Clear any existing target
	if target_instance:
		target_instance.queue_free()
		target_instance = null
	
	# Instance the target
	target_instance = target_scene.instantiate()
	center_container.add_child(target_instance)
	
	# Set drill active flag to false initially
	if target_instance.has_method("set"):
		target_instance.set("drill_active", false)
	
	# Connect to target hit signal if it exists
	if target_instance.has_signal("target_hit"):
		target_instance.target_hit.connect(_on_target_hit)
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Connected to target_hit signal")
	else:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] WARNING: Target does not have target_hit signal")
	
	# Connect performance tracker to our target_hit signal
	target_hit.connect(performance_tracker._on_target_hit)
	
	# Start drill timer
	start_drill_timer()
	
	# Show shot timer only in master mode
	if is_first:
		show_shot_timer()

func start_drill():
	"""Start the drill after delay"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Starting drill after delay")
	spawn_target()

func _on_target_hit(arg1, arg2, arg3, arg4 = null):
	"""Handle target hit - supports different target signal signatures"""
	# Ignore any shots after the drill has completed
	if drill_completed:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Ignoring target hit because drill is completed")
		return

	# Ignore shots that arrive before the timeout timer actually starts (e.g. master mode before shot timer ready)
	if timeout_timer and timeout_timer.is_stopped():
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Ignoring target hit because timeout timer has not started yet")
		return
	var zone: String
	var points: int
	var hit_position: Vector2
	
	# Handle different target signal signatures
	if arg4 == null:
		# ipsc_mini style: (zone, points, hit_position)
		zone = arg1
		points = arg2
		hit_position = arg3
	else:
		# 2poppers style: (popper_id, zone, points, hit_position)
		zone = arg2
		points = arg3
		hit_position = arg4
	
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Target hit: zone=", zone, " points=", points, " pos=", hit_position)
	
	# Hide shot timer on first shot
	if shot_timer_visible:
		hide_shot_timer()
		shot_timer_visible = false
	
	total_score += points
	
	# Emit for performance tracking
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Emitting target_hit signal to performance tracker")
	emit_signal("target_hit", current_target_type, hit_position, zone, 0.0, current_repeat)
	
	# Update fastest time
	# Note: fastest time UI update removed per request
	
	# Drill continues until timeout

func start_drill_timer():
	"""Start the drill timer"""
	# Reset performance tracker for new drill
	performance_tracker.reset_shot_timer()
	
	# Create timeout timer (will be started when shot timer is ready in master mode, immediately in slave mode)
	if timeout_timer:
		timeout_timer.queue_free()
	timeout_timer = Timer.new()
	timeout_timer.wait_time = timeout_seconds
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)
	
	if not is_first:
		# In slave mode, start timer immediately since no shot timer
		timeout_timer.start()
		drill_start_time = Time.get_ticks_msec() / 1000.0
		elapsed_seconds = 0.0
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Slave mode: Drill timer started immediately")
		# Activate drill for target
		if target_instance and target_instance.has_method("set"):
			target_instance.set("drill_active", true)
	else:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Master mode: Drill timer created (waiting for shot timer ready)")

func _process(_delta):
	"""Update timer"""
	if drill_start_time > 0 and not drill_completed:
		elapsed_seconds = (Time.get_ticks_msec() / 1000.0) - drill_start_time
		emit_signal("ui_timer_update", elapsed_seconds)

func _on_timeout():
	"""Handle drill timeout"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Drill timed out")
	drill_timed_out = true
	complete_drill()

func complete_drill():
	"""Complete the drill"""
	if drill_completed:
		return
	
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Drill completed! Score:", total_score)
	drill_completed = true
	
	# Deactivate the target
	if target_instance and target_instance.has_method("set"):
		target_instance.set("drill_active", false)
	
	# Emit timer stopped signal with final elapsed time BEFORE stopping
	emit_signal("ui_timer_stopped", elapsed_seconds)
	
	# Stop timers
	if timeout_timer:
		timeout_timer.stop()
	
	# Hide shot timer
	hide_shot_timer()
	
	# Show completion
	network_complete_overlay.show_completion(current_repeat)
	
	emit_signal("drills_finished")

func reset_drill_state():
	"""Reset the drill state to fresh start"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Resetting drill state to fresh start")
	
	drill_completed = false
	total_score = 0
	drill_timed_out = false
	elapsed_seconds = 0.0
	drill_start_time = 0.0
	shot_timer_visible = false
	
	# Stop and clean up timeout timer
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null
	
	# Remove existing target instance
	if target_instance:
		target_instance.queue_free()
		target_instance = null
	
	# Hide completion overlay
	network_complete_overlay.hide_completion()
	
	# Reset performance tracker
	performance_tracker.reset_shot_timer()
	
	# Reset UI timer
	emit_signal("ui_timer_update", 0.0)

func show_shot_timer():
	"""Show the shot timer"""
	emit_signal("ui_show_shot_timer")

func hide_shot_timer():
	"""Hide the shot timer"""
	emit_signal("ui_hide_shot_timer")

func _on_menu_control(directive: String):
	"""Handle websocket menu control"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Received menu_control directive:", directive)
	
	# Handle navigation commands
	match directive:
		"volume_up":
			volume_up()
		"volume_down":
			volume_down()
		"power":
			power_off()
		"back", "homepage":
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			# Clear BLE ready content before exiting the scene
			if global_data:
				global_data.ble_ready_content.clear()
				if not DEBUG_DISABLED:
					print("[DrillsNetwork] Cleared ble_ready_content before returning to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		_:
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] Unknown directive:", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Sending volume up")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Sending volume down")

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Sending power off")

func _on_ble_ready_command(content: Dictionary):
	"""Handle BLE ready command"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] ===== BLE READY COMMAND FUNCTION CALLED =====")
		print("[DrillsNetwork] Received BLE ready command (saved, not starting): ", content)

	# Save the ready content for later use when a 'start' arrives.
	# We store only relevant keys so they can be merged at start time.
	saved_ble_ready_content.clear()
	for k in content.keys():
		saved_ble_ready_content[k] = content[k]

	# Update current_target_type for informational purposes but do not instantiate or start anything
	if saved_ble_ready_content.has("targetType"):
		current_target_type = saved_ble_ready_content["targetType"]

	if not DEBUG_DISABLED:
		print("[DrillsNetwork] BLE ready parameters saved: ", saved_ble_ready_content)

	# Acknowledge the ready command back to sender by forwarding a netlink message
	# Format: {"type":"netlink","action":"forward","device":"A","content":"ready"}
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var content_dict = {"ack":"ready"}
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if not DEBUG_DISABLED:
					print("[DrillsNetwork] Sent ready ack successfully")
			else:
				if not DEBUG_DISABLED:
					print("[DrillsNetwork] Failed to send ready ack: ", result, response_code)
		, content_dict)
	else:
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] HttpService not available; cannot send ready ack")

	# If drill is completed, reset to fresh start
	if drill_completed:
		reset_drill_state()

func _on_ble_start_command(content: Dictionary) -> void:
	"""Handle BLE start command: merge saved ready params with start payload and begin delay/start sequence."""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Received BLE start command: ", content)

	# Merge saved ready params (lowest priority) with start content (highest priority)
	var merged: Dictionary = {}
	for k in saved_ble_ready_content.keys():
		merged[k] = saved_ble_ready_content[k]
	for k in content.keys():
		merged[k] = content[k]

	# Determine master/slave mode based on isFirst from ready command
	is_first = merged.get("isFirst", false)
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Operating in ", "master" if is_first else "slave", " mode (based on isFirst: ", is_first, ")")
	
	# Set current repeat
	current_repeat = merged.get("repeat", 0)
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Current repeat set to: ", current_repeat)
	
	# Notify UI of mode change
	emit_signal("ui_mode_update", is_first)

	# Apply merged parameters similar to original ready behavior
	if merged.has("targetType"):
		var target_type = merged["targetType"]
		current_target_type = target_type
		if target_type_to_scene.has(target_type):
			target_scene = load(target_type_to_scene[target_type])
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] Set target scene for type '", target_type, "' to: ", target_type_to_scene[target_type])
		else:
			if not DEBUG_DISABLED:
				print("[DrillsNetwork] Unknown targetType: ", target_type, ", using default")

	# Update UI target name if provided
	if merged.has("dest"):
		emit_signal("ui_target_name_update", merged["dest"])
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Updated target name to: ", merged["dest"])

	# Parse timeout from merged content
	if merged.has("timeout"):
		if is_first:
			timeout_seconds = float(merged["timeout"])
		else:
			timeout_seconds = 5.0 + float(merged["timeout"])
		if not DEBUG_DISABLED:
			print("[DrillsNetwork] Set timeout to: ", timeout_seconds)

	# Start the drill immediately
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Starting drill immediately")
	start_drill()
	if is_first:
		shot_timer_visible = true

func _on_shot_timer_ready(delay: float):
	"""Handle shot timer ready - start the drill timeout timer and begin elapsed time tracking"""
	if not DEBUG_DISABLED:
		print("[DrillsNetwork] Shot timer ready - starting drill timeout timer and elapsed time tracking. Delay: ", delay, " seconds")
	
	# Pass the delay to performance tracker
	performance_tracker.set_shot_timer_delay(delay)
	
	if timeout_timer and not drill_completed:
		timeout_timer.start()
		# Start tracking elapsed time
		drill_start_time = Time.get_ticks_msec() / 1000.0
		elapsed_seconds = 0.0
		# Activate drill for target
		if target_instance and target_instance.has_method("set"):
			target_instance.set("drill_active", true)
