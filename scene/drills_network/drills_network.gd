extends Control

const DEBUG_ENABLED = true  # Set to false for production release
const QR_CODE_GENERATOR = preload("res://script/qrcode.gd")

# Single target for network drills
@export var target_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")

# Target type to scene mapping
var target_type_to_scene = {
	"ipsc": "res://scene/ipsc_mini.tscn",
	"special_1": "res://scene/ipsc_mini_black_1.tscn",
	"special_2": "res://scene/ipsc_mini_black_2.tscn",
	"hostage": "res://scene/targets/hostage.tscn",
	"rotation": "res://scene/ipsc_mini_rotate.tscn",
	"paddle": "res://scene/targets/3paddles.tscn",
	"popper": "res://scene/targets/2poppers_simple.tscn",
	"final": "res://scene/targets/final.tscn"
}

# Node references
@onready var center_container = $CenterContainer
@onready var drill_timer = $DrillUI/DrillTimer
@onready var network_complete_overlay = $DrillNetworkCompleteOverlay
@onready var device_name_label = $DeviceNameLabel
@onready var qr_texture_rect = $QRCodeTextureRect

# Global data reference
var global_data: Node = null

# Target instance
var target_instance: Node = null
var total_score: int = 0
var drill_completed: bool = false
var current_target_type: String = "ipsc_mini"  # Default fallback

# Elapsed time tracking
var elapsed_seconds: float = 0.0
var drill_start_time: float = 0.0

# Timeout functionality
var timeout_timer: Timer = null
var timeout_seconds: float = 40.0
var drill_timed_out: bool = false


var is_first: bool = false # First target in the sequence
var is_last: bool = false  # Last target shows the final target

# Saved parameters from BLE 'ready' until a 'start' is received
var saved_ble_ready_content: Dictionary = {}

# Current repeat tracking
var current_repeat: int = 0

# Shot tracking for last target
var shots_on_last_target: int = 0
var final_target_spawned: bool = false
var final_target_instance: Node = null

# Performance tracking
signal drills_finished
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float, repeat: int, target_position: Vector2, t: int)

# UI update signals
signal ui_timer_update(elapsed_seconds: float)
signal ui_timer_stopped(final_time: float)
signal ui_target_name_update(target_name: String)
signal ui_mode_update(is_first: bool)

@onready var performance_tracker = preload("res://script/performance_tracker_network.gd").new()

func _ready():
	"""Initialize the network drill with a single target"""
	if DEBUG_ENABLED:
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
	
	# Enable bullet spawning for network drills scene
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Enabled bullet spawning for network drills scene")

	# Hide only the HeaderContainer inside TopContainer for network drills
	var drill_ui_node = get_node_or_null("DrillUI")
	if drill_ui_node and drill_ui_node.has_node("TopContainer/TopLayout/HeaderContainer"):
		var header = drill_ui_node.get_node("TopContainer/TopLayout/HeaderContainer")
		if header:
			header.visible = false
	
	# Hide the drill timer display as mobile app now counts the elapsed time
	# Stop the DrillTimer node and hide the timer display
	if drill_ui_node:
		# Stop the DrillTimer if it exists
		var drill_timer_node = drill_ui_node.get_node_or_null("DrillTimer")
		if drill_timer_node and drill_timer_node is Timer:
			drill_timer_node.stop()
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Stopped DrillTimer node")
		
		# Hide the timer display
		if drill_ui_node.has_node("TopContainer/TopLayout/TimerContainer"):
			var timer_container = drill_ui_node.get_node("TopContainer/TopLayout/TimerContainer")
			if timer_container:
				timer_container.visible = false
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Hidden TimerContainer display")
	
	# Set device name
	update_device_name_label()
	
	# Check if there's a saved ready state from main_menu and process it
	call_deferred("_check_and_process_saved_ready_state")

func _connect_to_websocket():
	"""Connect to WebSocketListener signals (called deferred to ensure WebSocketListener is ready)"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Attempting deferred connection to WebSocketListener")
	
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Found WebSocketListener at /root/WebSocketListener")
		
		# Check if signals exist before connecting
		if ws_listener.has_signal("menu_control"):
			ws_listener.menu_control.connect(_on_menu_control)
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Connected to menu_control signal")
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have menu_control signal")
		
		if ws_listener.has_signal("ble_ready_command"):
			ws_listener.ble_ready_command.connect(_on_ble_ready_command)
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Connected to ble_ready_command signal")
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have ble_ready_command signal")
		
		# Connect to ble_start_command so the drill only starts when an explicit 'start' is received
		if ws_listener.has_signal("ble_start_command"):
			ws_listener.ble_start_command.connect(_on_ble_start_command)
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Connected to ble_start_command signal")
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have ble_start_command signal")
		
		# Connect to ble_end_command to complete the drill when 'end' is received
		if ws_listener.has_signal("ble_end_command"):
			ws_listener.ble_end_command.connect(_on_ble_end_command)
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Connected to ble_end_command signal")
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] ERROR: WebSocketListener does not have ble_end_command signal")
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] ERROR: WebSocketListener not found at /root/WebSocketListener")
		# Try again after a short delay
		await get_tree().create_timer(0.1).timeout
		_connect_to_websocket()

func _check_and_process_saved_ready_state():
	"""Check if there's a saved ready state from main_menu and process it"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Checking for saved ready state from main_menu")
	
	if not global_data:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] GlobalData not available, cannot check for saved ready state")
		return
	
	# Check if ready content was saved by main_menu in GlobalData.ble_ready_content
	var saved_ready_content = global_data.ble_ready_content
	
	if saved_ready_content != null and saved_ready_content.size() > 0:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Found saved ready state, processing it: ", saved_ready_content)
		
		# Process it as if we received the ready command
		_on_ble_ready_command(saved_ready_content)
		
		# Start auto-start fallback timer (drill will start if no 'start' command arrives)
		_start_auto_start_fallback()
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] No saved ready state found in GlobalData")

func _start_auto_start_fallback():
	"""Start a fallback timer that will auto-start the drill in first target mode if no 'start' command arrives"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Starting auto-start fallback timer (2 seconds)")
	
	await get_tree().create_timer(2.0).timeout
	
	# If drill has not been started yet (no BLE start command received), start it now
	if not drill_completed and target_instance == null:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Auto-start fallback triggered - no BLE start command received, starting drill")
		
		# Use is_first from saved ready content
		is_first = saved_ble_ready_content.get("isFirst", true)
		emit_signal("ui_mode_update", is_first)
		
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Operating in ", "first target" if is_first else "subsequent target", " mode (based on saved isFirst: ", is_first, ")")
		
		# Use saved timeout or default
		if saved_ble_ready_content.has("timeout"):
			timeout_seconds = float(saved_ble_ready_content["timeout"])
		else:
			timeout_seconds = 40.0
		
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Auto-starting drill with timeout: ", timeout_seconds)
		
		start_drill()
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Auto-start fallback cancelled - drill already started or will be started by BLE command")
			
func _on_netlink_status_loaded():
	"""Update device name when netlink status is loaded"""
	update_device_name_label()
			
func update_device_name_label():
	"""Update the device name label with work mode - device_name - bluetooth_name format"""
	var info = _get_netlink_identity()
	var device_name = info["device_name"]
	var bluetooth_name = info["bluetooth_name"]
	var work_mode = info["work_mode"]
	var normalized_work_mode = str(work_mode).to_lower()
	var is_master = (normalized_work_mode == "master")
	var mode = tr("work_mode_master") if is_master else tr("work_mode_slave")
	if is_master:
		# Master mode: show bluetooth_name
		device_name_label.text = mode + " - " + device_name + " - " + bluetooth_name
	else:
		# Slave mode: don't show bluetooth_name
		device_name_label.text = mode + " - " + device_name

	# Update the QR code for master devices
	update_master_qr_code(bluetooth_name, work_mode)
			

func update_master_qr_code(ble_name: String, work_mode: String):
	"""Draw QR code for the master device name when available"""
	if not qr_texture_rect:
		return

	var normalized_mode = str(work_mode).to_lower()
	if normalized_mode != "master" or ble_name.strip_edges().is_empty():
		_hide_master_qr()
		return

	if _is_any_target_visible():
		_hide_master_qr()
		return

	var qr = QR_CODE_GENERATOR.new()
	var image = qr.generate_image(ble_name, 4)
	if image:
		qr_texture_rect.texture = ImageTexture.create_from_image(image)
		qr_texture_rect.visible = true
	else:
		_hide_master_qr()

func _hide_master_qr():
	if not qr_texture_rect:
		return
	qr_texture_rect.texture = null
	qr_texture_rect.visible = false

func _is_any_target_visible() -> bool:
	return target_instance != null or final_target_instance != null

func _get_netlink_identity() -> Dictionary:
	var identity = {
		"device_name": "unknown_device",
		"work_mode": "slave",
		"bluetooth_name": ""
	}
	var status = null
	if global_data and global_data.netlink_status:
		status = global_data.netlink_status
	elif has_node("/root/GlobalData"):
		var fallback_data = get_node("/root/GlobalData")
		if fallback_data.netlink_status:
			status = fallback_data.netlink_status
	
	if status:
		if status.has("device_name"):
			identity["device_name"] = str(status["device_name"])
		if status.has("work_mode"):
			identity["work_mode"] = str(status["work_mode"])
		if status.has("bluetooth_name"):
			identity["bluetooth_name"] = str(status["bluetooth_name"])

	return identity

func _refresh_master_qr_code():
	var info = _get_netlink_identity()
	update_master_qr_code(info["device_name"], info["work_mode"])
	
func spawn_target():
	"""Spawn the single target"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Spawning target")
	
	# Clear any existing target
	if target_instance:
		target_instance.queue_free()
		target_instance = null
	
	# Instance the target
	target_instance = target_scene.instantiate()
	center_container.add_child(target_instance)
	
	# Offset rotation target by -200, 200 from center
	if current_target_type == "rotation":
		target_instance.position = Vector2(-200, 200)
	
	# Set drill active flag to false initially
	if target_instance.has_method("set"):
		target_instance.set("drill_active", false)
	
	# Connect to target hit signal if it exists
	if target_instance.has_signal("target_hit"):
		target_instance.target_hit.connect(_on_target_hit)
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Connected to target_hit signal")
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] WARNING: Target does not have target_hit signal")
	
	# Connect performance tracker to our target_hit signal
	target_hit.connect(performance_tracker._on_target_hit)
	
	# Start drill timer
	start_drill_timer()

	# Hide QR code now that the drill has started
	_refresh_master_qr_code()

func start_drill():
	"""Start the drill after delay"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Starting drill after delay")
	spawn_target()

func spawn_final_target():
	"""Spawn the final target after 2 shots on the last target"""
	final_target_spawned = true
	
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Removing last target before spawning final target")
	
	# Remove the last target after a delay to allow bullet effects to complete
	if target_instance:
		await get_tree().create_timer(0.5).timeout
		target_instance.queue_free()
		target_instance = null
	
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Spawning final target")
	
	# Clear any existing final target
	if final_target_instance:
		final_target_instance.queue_free()
		final_target_instance = null
	
	# Load and instantiate the final target scene
	var final_scene = load("res://scene/targets/final.tscn")
	if final_scene:
		final_target_instance = final_scene.instantiate()
		center_container.add_child(final_target_instance)
		
		# Connect to final_target_hit signal
		if final_target_instance.has_signal("final_target_hit"):
			final_target_instance.final_target_hit.connect(_on_final_target_hit)
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Connected to final_target_hit signal")
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] WARNING: Final target does not have final_target_hit signal")
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] ERROR: Could not load final target scene")

	# Hide QR whenever targets are visible
	_refresh_master_qr_code()

func _on_final_target_hit(hit_position: Vector2):
	"""Handle final target hit - send end acknowledgement"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Final target hit at position: ", hit_position)
	
	# Mark drill as completed to stop the timer updates
	drill_completed = true
	
	# Stop the drill timer
	if timeout_timer:
		timeout_timer.stop()
	
	# Emit timer stopped signal with final elapsed time
	emit_signal("ui_timer_stopped", elapsed_seconds)
	
	# Show completion overlay
	network_complete_overlay.show_completion(current_repeat)
	
	# Send netlink forward data with ack:end
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var drill_duration = elapsed_seconds
		drill_duration = round(drill_duration * 100.0) / 100.0
		
		var content_dict = {"ack": "end", "drill_duration": drill_duration}
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Sent end ack successfully")
			else:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Failed to send end ack: ", result, response_code)
		, content_dict)
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] HttpService not available; cannot send end ack")

func _on_target_hit(zone_or_id, points_or_zone, hit_pos_or_points, target_pos_or_hit_pos = null, target_rot = null, t: int = 0):
	"""Handle target hit - supports different target signal signatures.
	
	Target signal signatures:
	- Simple targets (ipsc_mini, black variants, hostage, popper): (zone, points, hit_position, t)
	- Container targets (paddle, 2poppers_simple): (id, zone, points, hit_position, t)
	- Rotation target (ipsc_mini_rotate): (zone, points, hit_position, target_position, target_rotation, t)
	"""
	# Ignore any shots after the drill has completed
	if drill_completed:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Ignoring target hit because drill is completed")
		return

	# Ignore shots that arrive before the timeout timer actually starts
	if timeout_timer and timeout_timer.is_stopped():
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Ignoring target hit because timeout timer has not started yet")
		return
	
	var zone: String
	var points: int
	var hit_position: Vector2
	var rotation_angle: float = 0.0
	var target_position: Vector2 = target_instance.global_position if target_instance else Vector2.ZERO
	
	# Determine target type and extract parameters accordingly
	if target_pos_or_hit_pos is int:
		# Simple target style: (zone, points, hit_position, t)
		# The t value came as 4th parameter because signals pass all params in order
		zone = zone_or_id as String
		points = int(points_or_zone)
		hit_position = hit_pos_or_points as Vector2
		t = int(target_pos_or_hit_pos)
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Simple target hit - zone: ", zone, ", points: ", points)
			
	elif target_pos_or_hit_pos != null and target_rot != null:
		# Rotation target style: (zone, points, hit_position, target_position, target_rotation, t)
		zone = zone_or_id as String
		points = int(points_or_zone)
		hit_position = hit_pos_or_points as Vector2
		target_position = target_pos_or_hit_pos as Vector2
		rotation_angle = float(target_rot)
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Rotation target hit - zone: ", zone, ", points: ", points, ", rotation: ", rotation_angle)
			
	elif target_pos_or_hit_pos != null and target_rot == null:
		# Container target style: (id, zone, points, hit_position, t)
		# First parameter is the container ID (paddle_id or popper_id), extract zone and points
		zone = points_or_zone as String
		points = int(hit_pos_or_points)
		hit_position = target_pos_or_hit_pos as Vector2
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Container target hit - zone: ", zone, ", points: ", points)
	else:
		# Fallback to simple target style
		zone = zone_or_id as String
		points = int(points_or_zone)
		hit_position = hit_pos_or_points as Vector2
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Unknown target style (fallback) - zone: ", zone, ", points: ", points)
	
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Target hit processed: zone=", zone, ", points=", points, ", hit_pos=", hit_position, ", t=", t)
	
	total_score += points
	# Track shots on the last target to trigger final spawn
	if is_last and not final_target_spawned:
		shots_on_last_target += 1
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Last target hit! Shot count: ", shots_on_last_target, "/2")
		
		# Check if ending target is enabled in settings
		var has_ending_target = false
		if global_data and global_data.settings_dict.has("has_ending_target"):
			has_ending_target = global_data.settings_dict.get("has_ending_target", false)
			if DEBUG_ENABLED:
				print("[DrillsNetwork] has_ending_target setting: ", has_ending_target)
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] has_ending_target setting not found in GlobalData, using default: false")
		
		# Spawn final target after 2 shots on last target only if ending target is enabled
		if shots_on_last_target >= 2:
			if has_ending_target:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Spawning final target after 2 shots on last target")
				spawn_final_target()
			else:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Ending target disabled in settings, waiting for mobile app to end the drill")
				# Mark final_target_spawned to prevent re-entry, but don't complete the drill yet
				final_target_spawned = true
	
	# Emit for performance tracking
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Emitting target_hit signal to performance tracker with t=", t)
	emit_signal("target_hit", current_target_type, hit_position, zone, rotation_angle, current_repeat, target_position, t)

func start_drill_timer():
	"""Start the drill timer"""
	# Reset performance tracker for new drill
	performance_tracker.reset_shot_timer()
	
	# Create timeout timer
	if timeout_timer:
		timeout_timer.queue_free()
	timeout_timer = Timer.new()
	timeout_timer.wait_time = timeout_seconds
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)
	
	# Start timer immediately for all targets
	timeout_timer.start()
	drill_start_time = Time.get_ticks_msec() / 1000.0
	elapsed_seconds = 0.0
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Drill timer started immediately")
	
	# Activate drill for target
	if target_instance and target_instance.has_method("set"):
		target_instance.set("drill_active", true)

func _process(_delta):
	"""Update timer"""
	if drill_start_time > 0 and not drill_completed:
		elapsed_seconds = (Time.get_ticks_msec() / 1000.0) - drill_start_time
		emit_signal("ui_timer_update", elapsed_seconds)

func _on_timeout():
	"""Handle drill timeout"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Drill timed out")
	drill_timed_out = true
	complete_drill()

func complete_drill():
	"""Complete the drill"""
	if drill_completed:
		return
	
	if DEBUG_ENABLED:
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
	
	# Show completion
	network_complete_overlay.show_completion(current_repeat)
	
	emit_signal("drills_finished")

func reset_drill_state():
	"""Reset the drill state to fresh start"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Resetting drill state to fresh start")
	
	drill_completed = false
	total_score = 0
	drill_timed_out = false
	elapsed_seconds = 0.0
	drill_start_time = 0.0
	shots_on_last_target = 0
	final_target_spawned = false
	
	# Stop and clean up timeout timer
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null
	
	# Remove existing target instance
	if target_instance:
		target_instance.queue_free()
		target_instance = null
	
	# Remove existing final target instance
	if final_target_instance:
		final_target_instance.queue_free()
		final_target_instance = null
	
	# Hide completion overlay
	network_complete_overlay.hide_completion()
	
	# Reset performance tracker
	performance_tracker.reset_shot_timer()
	
	# Reset UI timer
	emit_signal("ui_timer_update", 0.0)

	# Refresh QR code now that no targets are visible
	_refresh_master_qr_code()

func _on_menu_control(directive: String):
	"""Handle websocket menu control"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Received menu_control directive:", directive)
	
	# Handle navigation commands
	match directive:
		"volume_up":
			volume_up()
		"volume_down":
			volume_down()
		"power":
			power_off()
		"homepage", "back":
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			if global_data:
				global_data.return_source = "network"
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Set return_source to network")
			
			# Clear BLE ready content before exiting the scene
			if global_data:
				global_data.ble_ready_content.clear()
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Cleared ble_ready_content before returning to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		_:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Unknown directive:", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Sending volume up")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Sending volume down")

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Sending power off")

func _on_ble_ready_command(content: Dictionary):
	"""Handle BLE ready command"""
	if DEBUG_ENABLED:
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

	if DEBUG_ENABLED:
		print("[DrillsNetwork] BLE ready parameters saved: ", saved_ble_ready_content)

	# Acknowledge the ready command back to sender by forwarding a netlink message
	# Format: {"type":"netlink","action":"forward","device":"A","content":"ready"}
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var content_dict = {"ack":"ready"}
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Sent ready ack successfully")
			else:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] Failed to send ready ack: ", result, response_code)
		, content_dict)
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] HttpService not available; cannot send ready ack")

	# If drill is completed, reset to fresh start
	if drill_completed:
		reset_drill_state()

func _on_ble_start_command(content: Dictionary) -> void:
	"""Handle BLE start command: merge saved ready params with start payload and begin delay/start sequence."""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Received BLE start command: ", content)

	# Merge saved ready params (lowest priority) with start content (highest priority)
	var merged: Dictionary = {}
	for k in saved_ble_ready_content.keys():
		merged[k] = saved_ble_ready_content[k]
	for k in content.keys():
		merged[k] = content[k]

	# Determine isFirst from ready command
	is_first = merged.get("isFirst", false)
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Operating in ", "first target" if is_first else "subsequent target", " mode (based on isFirst: ", is_first, ")")
	
	# Update device name label with new mode
	update_device_name_label()
	
	# Set current repeat
	current_repeat = merged.get("repeat", 0)
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Current repeat set to: ", current_repeat)
	
	# Extract isLast flag
	is_last = merged.get("isLast", false)
	if DEBUG_ENABLED:
		print("[DrillsNetwork] isLast set to: ", is_last)
	
	# Notify UI of mode change
	emit_signal("ui_mode_update", is_first)

	# Apply merged parameters similar to original ready behavior
	if merged.has("targetType"):
		var target_type = merged["targetType"]
		current_target_type = target_type
		if target_type_to_scene.has(target_type):
			target_scene = load(target_type_to_scene[target_type])
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Set target scene for type '", target_type, "' to: ", target_type_to_scene[target_type])
		else:
			if DEBUG_ENABLED:
				print("[DrillsNetwork] Unknown targetType: ", target_type, ", using default")

	# Update UI target name if provided
	if merged.has("dest"):
		emit_signal("ui_target_name_update", merged["dest"])
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Updated target name to: ", merged["dest"])

	# Parse timeout from merged content
	if merged.has("timeout"):
		if is_first:
			timeout_seconds = float(merged["timeout"])
		else:
			timeout_seconds = float(merged["delay"]) + float(merged["timeout"])
		if DEBUG_ENABLED:
			print("[DrillsNetwork] Set timeout to: ", timeout_seconds)

	# Call start_game before starting the drill
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.start_game(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] start_game called successfully")
			else:
				if DEBUG_ENABLED:
					print("[DrillsNetwork] start_game failed: ", result, response_code)
		)
	else:
		if DEBUG_ENABLED:
			print("[DrillsNetwork] HttpService not available; cannot call start_game")
	
	# Start the drill immediately
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Starting drill immediately")
	start_drill()

func _on_ble_end_command(content: Dictionary) -> void:
	"""Handle BLE end command: complete the drill"""
	if DEBUG_ENABLED:
		print("[DrillsNetwork] Received BLE end command: ", content)
	
	# Complete the drill
	complete_drill()
