extends Control

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
	"popper": "res://scene/2poppers.tscn"
}

# Node references
@onready var center_container = $CenterContainer
@onready var drill_timer = $DrillUI/DrillTimer
@onready var footsteps_node = $Footsteps
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

# Delay functionality
var delay_timer: Timer = null
var delay_seconds: float = 5.0

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
signal ui_score_update(score: int)
signal ui_progress_update(targets_completed: int)

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
		print("[DrillsNetwork] Connected to WebSocketListener menu_control and ble_ready_command")
	
	# Set theme
	emit_signal("ui_theme_change", "golden")
	
	# Initialize progress (1 target)
	emit_signal("ui_progress_update", 0)
	emit_signal("ui_target_title_update", 1, 1)
	
	# Drill will be started by BLE ready command

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
	
	# Show shot timer
	show_shot_timer()

func start_drill():
	"""Start the drill after delay"""
	print("[DrillsNetwork] Starting drill after delay")
	spawn_target()

func _on_target_hit(arg1, arg2, arg3, arg4 = null):
	"""Handle target hit - supports different target signal signatures"""
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
	emit_signal("ui_score_update", total_score)
	
	# Emit for performance tracking
	print("[DrillsNetwork] Emitting target_hit signal to performance tracker")
	emit_signal("target_hit", current_target_type, hit_position, zone, 0.0)
	
	# Update fastest time
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_fastest_time_update", fastest_time)
	
	# Drill continues until timeout

func start_drill_timer():
	"""Start the drill timer"""
	drill_start_time = Time.get_ticks_msec() / 1000.0
	elapsed_seconds = 0.0
	
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
	timeout_timer.start()
	
	print("[DrillsNetwork] Drill timer started")

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
	if delay_timer:
		delay_timer.stop()
	
	# Hide shot timer
	hide_shot_timer()
	
	# Show completion
	network_complete_overlay.show()
	
	emit_signal("drills_finished")

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
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
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
	print("[DrillsNetwork] Received BLE ready command: ", content)
	
	# Set target scene based on targetType
	if content.has("targetType"):
		var target_type = content["targetType"]
		current_target_type = target_type  # Store for later use
		if target_type_to_scene.has(target_type):
			target_scene = load(target_type_to_scene[target_type])
			print("[DrillsNetwork] Set target scene for type '", target_type, "' to: ", target_type_to_scene[target_type])
		else:
			print("[DrillsNetwork] Unknown targetType: ", target_type, ", using default")
	else:
		print("[DrillsNetwork] No targetType in command, using default target scene")
	
	# Parse dest and update target name
	if content.has("dest"):
		var dest = content["dest"]
		emit_signal("ui_target_name_update", dest)
		print("[DrillsNetwork] Updated target name to: ", dest)
	
	# Parse timeout and delay from content
	if content.has("timeout"):
		timeout_seconds = float(content["timeout"])
		print("[DrillsNetwork] Set timeout to: ", timeout_seconds)
	
	delay_seconds = content.get("delay", delay_seconds)
	print("[DrillsNetwork] Set delay to: ", delay_seconds)
	
	# Start delay timer
	if delay_timer:
		delay_timer.queue_free()
	delay_timer = Timer.new()
	delay_timer.wait_time = delay_seconds
	delay_timer.one_shot = true
	delay_timer.timeout.connect(_on_delay_timeout)
	add_child(delay_timer)
	delay_timer.start()
	
	print("[DrillsNetwork] Delay timer started for ", delay_seconds, " seconds")

func _on_delay_timeout():
	"""Handle delay timeout - start the drill"""
	print("[DrillsNetwork] Delay timeout - starting drill")
	start_drill()
	shot_timer_visible = true
