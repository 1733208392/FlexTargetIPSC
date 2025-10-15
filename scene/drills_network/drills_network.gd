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
var is_master: bool = false

# Saved parameters from BLE 'ready' until a 'start' is received
var saved_ble_ready_content: Dictionary = {}

# Performance tracking
signal drills_finished
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float)

# UI update signals
signal ui_timer_update(elapsed_seconds: float)
signal ui_target_title_update(target_index: int, total_targets: int)
signal ui_target_name_update(target_name: String)
signal ui_show_shot_timer()
signal ui_hide_shot_timer()
signal ui_theme_change(theme_name: String)

@onready var performance_tracker = preload("res://script/performance_tracker_network.gd").new()

func _ready():
	"""Initialize the network drill with a single target"""
	print("[DrillsNetwork] Starting network drill")
	
	# Add performance tracker to scene tree first
	add_child(performance_tracker)
	
	# Connect performance tracker
	target_hit.connect(performance_tracker._on_target_hit)
	
	# Connect to WebSocketListener for menu control
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		ws_listener.ble_ready_command.connect(_on_ble_ready_command)
		# Connect to ble_start_command so the drill only starts when an explicit 'start' is received
		if ws_listener.has_signal("ble_start_command"):
			ws_listener.ble_start_command.connect(_on_ble_start_command)
		print("[DrillsNetwork] Connected to WebSocketListener menu_control and ble_ready_command")
	
	# Connect to shot timer ready signal
	var shot_timer = get_node("DrillUI/ShotTimerOverlay")
	if shot_timer and shot_timer.has_signal("timer_ready"):
		shot_timer.timer_ready.connect(_on_shot_timer_ready)
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
	
	# If a BLE ready command was stored on GlobalData by the previous scene, load it now
	var gd = get_node_or_null("/root/GlobalData")
	if gd:
		var content = null
		var settings = gd.get("settings_dict")
		if settings != null and typeof(settings) == TYPE_DICTIONARY and settings.has("ble_ready_content"):
			content = settings["ble_ready_content"]
			settings.erase("ble_ready_content")
		elif gd.get("ble_ready_content") != null:
			content = gd.get("ble_ready_content")
			gd.set("ble_ready_content", null)
		if content != null:
			print("[DrillsNetwork] Loaded ble_ready_content from GlobalData: ", content)
			# Merge into saved_ble_ready_content
			saved_ble_ready_content.clear()
			for k in content.keys():
				saved_ble_ready_content[k] = content[k]
			if saved_ble_ready_content.has("targetType"):
				current_target_type = saved_ble_ready_content["targetType"]
			print("[DrillsNetwork] Merged saved BLE ready params from GlobalData: ", saved_ble_ready_content)
			# Send ready ack to the sender as if we had just received the ready command
			var ws_listener_ack = get_node_or_null("/root/WebSocketListener")
			if ws_listener_ack and ws_listener_ack.has_method("send_netlink_forward"):
				var device_name = gd.netlink_status.get("device_name", "B")
				var err_ack = ws_listener_ack.send_netlink_forward(device_name, "ready")
				if err_ack != OK:
					print("[DrillsNetwork] Failed to send ready ack on startup: ", err_ack)
				else:
					print("[DrillsNetwork] Sent ready ack on startup via helper")
			else:
				print("[DrillsNetwork] WebSocketListener not available or missing helper; cannot send ready ack on startup")
	
	# Drill will be started by BLE ready command (or a stored ready command merged above)

func spawn_target():
	"""Spawn the single target"""
	print("[DrillsNetwork] Spawning target")
	
	# Clear any existing target
	if target_instance:
		target_instance.queue_free()
		target_instance = null
	
	# Instance the target
	target_instance = target_scene.instantiate()
	center_container.add_child(target_instance)
	
	# Connect to target hit signal if it exists
	if target_instance.has_signal("target_hit"):
		target_instance.target_hit.connect(_on_target_hit)
		print("[DrillsNetwork] Connected to target_hit signal")
	else:
		print("[DrillsNetwork] WARNING: Target does not have target_hit signal")
	
	# Connect performance tracker to our target_hit signal
	target_hit.connect(performance_tracker._on_target_hit)
	
	# Start drill timer
	start_drill_timer()
	
	# Show shot timer only in master mode
	if is_master:
		show_shot_timer()

func start_drill():
	"""Start the drill after delay"""
	print("[DrillsNetwork] Starting drill after delay")
	spawn_target()

func _on_target_hit(arg1, arg2, arg3, arg4 = null):
	"""Handle target hit - supports different target signal signatures"""
	# Ignore any shots after the drill has completed
	if drill_completed:
		print("[DrillsNetwork] Ignoring target hit because drill is completed")
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
	
	print("[DrillsNetwork] Target hit: zone=", zone, " points=", points, " pos=", hit_position)
	
	# Hide shot timer on first shot
	if shot_timer_visible:
		hide_shot_timer()
		shot_timer_visible = false
	
	total_score += points
	
	# Emit for performance tracking
	print("[DrillsNetwork] Emitting target_hit signal to performance tracker")
	emit_signal("target_hit", current_target_type, hit_position, zone, 0.0)
	
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
	
	if not is_master:
		# In slave mode, start timer immediately since no shot timer
		timeout_timer.start()
		drill_start_time = Time.get_ticks_msec() / 1000.0
		elapsed_seconds = 0.0
		print("[DrillsNetwork] Slave mode: Drill timer started immediately")
	else:
		print("[DrillsNetwork] Master mode: Drill timer created (waiting for shot timer ready)")

func _process(_delta):
	"""Update timer"""
	if drill_start_time > 0 and not drill_completed:
		elapsed_seconds = (Time.get_ticks_msec() / 1000.0) - drill_start_time
		emit_signal("ui_timer_update", elapsed_seconds)

func _on_timeout():
	"""Handle drill timeout"""
	print("[DrillsNetwork] Drill timed out")
	drill_timed_out = true
	complete_drill()

func complete_drill():
	"""Complete the drill"""
	if drill_completed:
		return
	
	print("[DrillsNetwork] Drill completed! Score:", total_score)
	drill_completed = true
	
	# Stop timers
	if timeout_timer:
		timeout_timer.stop()
	
	# Hide shot timer
	hide_shot_timer()
	
	# Show completion
	network_complete_overlay.show()
	
	emit_signal("drills_finished")

func reset_drill_state():
	"""Reset the drill state to fresh start"""
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
	network_complete_overlay.hide()
	
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
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		_:
			print("[DrillsNetwork] Unknown directive:", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[DrillsNetwork] Sending volume up")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[DrillsNetwork] Sending volume down")

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[DrillsNetwork] Sending power off")

func _on_ble_ready_command(content: Dictionary):
	"""Handle BLE ready command"""
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
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and ws_listener.has_method("send_netlink_forward"):
		var gd = get_node_or_null("/root/GlobalData")
		var device_name = "B"
		if gd:
			device_name = gd.netlink_status.get("device_name", "B")
		var err = ws_listener.send_netlink_forward(device_name, "ready")
		if err != OK:
			print("[DrillsNetwork] Failed to send ready ack: ", err)
		else:
			print("[DrillsNetwork] Sent ready ack via helper")
	else:
		print("[DrillsNetwork] WebSocketListener not available or missing helper; cannot send ready ack")

	# If drill is completed, reset to fresh start
	if drill_completed:
		reset_drill_state()

func _on_ble_start_command(content: Dictionary) -> void:
	"""Handle BLE start command: merge saved ready params with start payload and begin delay/start sequence."""
	print("[DrillsNetwork] Received BLE start command: ", content)

	# Merge saved ready params (lowest priority) with start content (highest priority)
	var merged: Dictionary = {}
	for k in saved_ble_ready_content.keys():
		merged[k] = saved_ble_ready_content[k]
	for k in content.keys():
		merged[k] = content[k]

	# Determine master/slave mode
	var gd = get_node_or_null("/root/GlobalData")
	if gd and gd.netlink_status.has("work_mode"):
		is_master = (gd.netlink_status["work_mode"] == "master")
	else:
		is_master = false  # Default to slave mode
	print("[DrillsNetwork] Operating in ", "master" if is_master else "slave", " mode")

	# Apply merged parameters similar to original ready behavior
	if merged.has("targetType"):
		var target_type = merged["targetType"]
		current_target_type = target_type
		if target_type_to_scene.has(target_type):
			target_scene = load(target_type_to_scene[target_type])
			print("[DrillsNetwork] Set target scene for type '", target_type, "' to: ", target_type_to_scene[target_type])
		else:
			print("[DrillsNetwork] Unknown targetType: ", target_type, ", using default")

	# Update UI target name if provided
	if merged.has("dest"):
		emit_signal("ui_target_name_update", merged["dest"])
		print("[DrillsNetwork] Updated target name to: ", merged["dest"])

	# Parse timeout from merged content
	if merged.has("timeout"):
		if is_master:
			timeout_seconds = float(merged["timeout"])
		else:
			timeout_seconds = 5.0 + float(merged["timeout"])
		print("[DrillsNetwork] Set timeout to: ", timeout_seconds)

	# Start the drill immediately
	print("[DrillsNetwork] Starting drill immediately")
	start_drill()
	if is_master:
		shot_timer_visible = true

func _on_shot_timer_ready():
	"""Handle shot timer ready - start the drill timeout timer and begin elapsed time tracking"""
	print("[DrillsNetwork] Shot timer ready - starting drill timeout timer and elapsed time tracking")
	if timeout_timer and not drill_completed:
		timeout_timer.start()
		# Start tracking elapsed time
		drill_start_time = Time.get_ticks_msec() / 1000.0
		elapsed_seconds = 0.0
