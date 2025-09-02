extends Control

# Preload the scenes for the drill sequence
@export var ipsc_mini_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")
@export var hostage_scene: PackedScene = preload("res://scene/hostage.tscn")
@export var two_poppers_scene: PackedScene = preload("res://scene/2poppers.tscn")
#@export var paddle_scene: PackedScene = preload("res://scene/paddle.tscn")
@export var three_paddles_scene: PackedScene = preload("res://scene/3paddles.tscn")
@export var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")

# Theme styles for title
@export var golden_title_style: LabelSettings = preload("res://theme/target_title_settings.tres")
@export var tactical_title_style: LabelSettings = preload("res://theme/target_title_tactical.tres")
@export var competitive_title_style: LabelSettings = preload("res://theme/target_title_competitive.tres")
var current_theme_style: String = "golden"

# Drill sequence and progress tracking
var target_sequence: Array[String] = ["ipsc_mini","hostage", "2poppers", "3paddles", "ipsc_mini_rotate"]
var current_target_index: int = 0
var current_target_instance: Node = null
var total_drill_score: int = 0
var drill_completed: bool = false
var bullets_allowed: bool = false  # Track if bullet spawning is allowed
var rotating_target_hits: int = 0  # Track hits on the rotating target

# Elapsed time tracking
var elapsed_seconds: float = 0.0
var drill_start_time: float = 0.0

# Node references
@onready var center_container = $CenterContainer
@onready var target_type_title = $TopContainer/TopLayout/HeaderContainer/TargetTypeTitle
@onready var fps_label = $FPSLabel
@onready var shot_timer_overlay = $ShotTimerOverlay
@onready var drill_complete_overlay = $DrillCompleteOverlay
@onready var fastest_interval_label = $TopContainer/TopLayout/HeaderContainer/FastestContainer/FastestInterval
@onready var drill_timer = $DrillTimer
@onready var timer_label = $TopContainer/TopLayout/TimerContainer/Timer

# Performance tracking
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String)
signal drills_finished
@onready var performance_tracker = preload("res://script/performance_tracker.gd").new()

func _ready():
	"""Initialize the drill with the first target"""
	print("=== STARTING DRILL ===")
	apply_title_theme("golden")  # Set default theme
	
	# Clear any existing targets in the center container
	clear_current_target()
	
	# Ensure the center container doesn't block mouse input
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect shot timer signals
	shot_timer_overlay.timer_ready.connect(_on_shot_timer_ready)
	shot_timer_overlay.timer_reset.connect(_on_shot_timer_reset)
	
	# Connect drill timer signal
	drill_timer.timeout.connect(_on_drill_timer_timeout)
	
	# Instantiate and add performance tracker
	add_child(performance_tracker)
	target_hit.connect(performance_tracker._on_target_hit)
	drills_finished.connect(performance_tracker._on_drills_finished)
	
	# Show shot timer overlay before starting drill
	show_shot_timer()

func show_shot_timer():
	"""Show the shot timer overlay"""
	print("=== SHOWING SHOT TIMER OVERLAY ===")
	shot_timer_overlay.visible = true
	shot_timer_overlay.reset_timer()
	
	# Hide the completion overlay if visible
	drill_complete_overlay.visible = false
	
	# Disable bullet spawning during shot timer
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = false
	
	# No target should be visible during shot timer phase
	clear_current_target()

func hide_shot_timer():
	"""Hide the shot timer overlay"""
	print("=== HIDING SHOT TIMER OVERLAY ===")
	shot_timer_overlay.visible = false

func _on_shot_timer_ready():
	"""Handle when shot timer beep occurs - start the drill"""
	print("=== SHOT TIMER READY - STARTING DRILL ===")
	# Hide the shot timer overlay
	hide_shot_timer()
	# Enable bullet spawning now that target will appear
	bullets_allowed = true
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = true
	# Start the drill timer
	start_drill_timer()
	# Now spawn the target normally
	spawn_next_target()

func _on_shot_timer_reset():
	"""Handle when shot timer is reset"""
	print("=== SHOT TIMER RESET ===")
	# Could add additional logic here if needed

func _on_drill_timer_timeout():
	"""Handle drill timer timeout - update elapsed time display"""
	elapsed_seconds += 0.1
	update_timer_display()

func start_drill_timer():
	"""Start the drill elapsed time timer"""
	elapsed_seconds = 0.0
	drill_start_time = Time.get_unix_time_from_system()
	update_timer_display()
	drill_timer.start()
	
	# Reset performance tracker timing for accurate first shot measurement
	performance_tracker.reset_shot_timer()
	
	# Reset fastest time for the new drill
	performance_tracker.reset_fastest_time()
	update_fastest_interval_display()
	
	print("=== DRILL TIMER STARTED ===")

func stop_drill_timer():
	"""Stop the drill elapsed time timer"""
	drill_timer.stop()
	print("=== DRILL TIMER STOPPED ===")

func update_timer_display():
	"""Update the timer label with formatted elapsed time in MM:SS:MS format"""
	var total_seconds = int(elapsed_seconds)
	var milliseconds = int((elapsed_seconds - total_seconds) * 100)
	
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
	timer_label.text = time_string

func _process(_delta):
	"""Update FPS counter every frame"""
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: " + str(fps)

func _unhandled_input(_event):
	"""Handle input events for theme switching (testing purposes)"""
	if _event is InputEventMouseButton and _event.pressed:
		print("=== DRILLS.GD received unhandled mouse click ===")
		print("Position: ", _event.global_position)
		print("Button: ", _event.button_index)
	
	if _event is InputEventKey and _event.pressed:
		match _event.keycode:
			KEY_1:
				apply_title_theme("golden")
			KEY_2:
				apply_title_theme("tactical")
			KEY_3:
				apply_title_theme("competitive")
			KEY_R:
				restart_drill()

func update_target_title():
	"""Update the target title based on the current target number"""
	var target_number = current_target_index + 1
	target_type_title.text = "Target " + str(target_number)
	print("Updated title to: Target ", target_number)

func apply_title_theme(theme_name: String):
	"""Apply a specific theme style to the target title"""
	match theme_name:
		"golden":
			target_type_title.label_settings = golden_title_style
		"tactical":
			target_type_title.label_settings = tactical_title_style
		"competitive":
			target_type_title.label_settings = competitive_title_style
		_:
			print("Unknown theme: ", theme_name)
			return
	
	current_theme_style = theme_name
	print("Applied theme: ", theme_name)

func spawn_next_target():
	"""Spawn the next target in the sequence"""
	if current_target_index >= target_sequence.size():
		complete_drill()
		return
	
	var target_type = target_sequence[current_target_index]
	print("=== SPAWNING TARGET: ", target_type, " (", current_target_index + 1, "/", target_sequence.size(), ") ===")
	
	# Clear any existing target
	clear_current_target()
	
	# Create the new target based on type
	match target_type:
		"ipsc_mini":
			spawn_ipsc_mini()
		"hostage":
			await spawn_hostage()
		"2poppers":
			spawn_2poppers()
		"3paddles":
			spawn_3paddles()
		"ipsc_mini_rotate":
			await spawn_ipsc_mini_rotate()
		_:
			print("ERROR: Unknown target type: ", target_type)
			return
	
	# Update the title
	update_target_title()
	
	# Connect signals for the new target
	connect_target_signals()

func clear_current_target():
	"""Remove the current target from the scene"""
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	
	current_target_instance = null

func spawn_ipsc_mini():
	"""Spawn an IPSC mini target"""
	var target = ipsc_mini_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	print("IPSC Mini target spawned")

func spawn_hostage():
	"""Spawn a hostage target"""
	print("=== SPAWNING HOSTAGE TARGET ===")
	var target = hostage_scene.instantiate()
	center_container.add_child(target)
	
	current_target_instance = target
	print("Hostage target spawned successfully")
	print("Hostage target has target_hit signal: ", target.has_signal("target_hit"))
	print("Hostage target has target_disappeared signal: ", target.has_signal("target_disappeared"))
	
	# Wait for the target to be fully ready before proceeding
	await get_tree().process_frame

func spawn_2poppers():
	"""Spawn a 2poppers composite target"""
	var target = two_poppers_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	print("2poppers target spawned")

func spawn_3paddles():
	"""Spawn a 3paddles composite target"""
	var target = three_paddles_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	print("3paddles target spawned")

func spawn_ipsc_mini_rotate():
	"""Spawn an IPSC mini rotating target"""
	var target = ipsc_mini_rotate_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	
	target.position = Vector2(-200, 200)
	
	# Reset rotating target hit counter
	rotating_target_hits = 0
	print("Rotating target hit counter reset to 0")
	
	# Wait for the node to be fully added to the scene
	await get_tree().process_frame
	
	# Position the rotation center appropriately
	#var screen_height = get_viewport().get_visible_rect().size.y
	#var bottom_offset = screen_height * 0.3
	#target.position.y = bottom_offset
	
	print("IPSC Mini Rotate target spawned and positioned")

func connect_target_signals():
	"""Connect to the current target's signals"""
	if not current_target_instance:
		print("WARNING: No current target instance to connect signals")
		return
	
	var current_target_type = target_sequence[current_target_index]
	
	# Handle composite targets that contain child targets
	match current_target_type:
		"2poppers":
			connect_2poppers_signals()
		"3paddles":
			connect_paddle_signals()
		"ipsc_mini_rotate":
			connect_ipsc_mini_rotate_signals()
		_:
			connect_simple_target_signals()

func connect_simple_target_signals():
	"""Connect signals for simple targets (ipsc_mini, hostage, popper, paddle)"""
	print("=== CONNECTING SIMPLE TARGET SIGNALS ===")
	print("Target instance: ", current_target_instance)
	if current_target_instance:
		print("Target name: ", current_target_instance.name)
		print("Target type: ", target_sequence[current_target_index])
	else:
		print("Target name: None")
	
	if current_target_instance.has_signal("target_hit"):
		# Disconnect any existing connections
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		
		# Connect the signal
		current_target_instance.target_hit.connect(_on_target_hit)
		print("Connected to target_hit signal")
	else:
		print("WARNING: target_hit signal not found!")
	
	# Connect to disappear signal if available
	if current_target_instance.has_signal("target_disappeared"):
		if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
			current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
		current_target_instance.target_disappeared.connect(_on_target_disappeared)
		print("Connected to target_disappeared signal")
	else:
		print("WARNING: target_disappeared signal not found!")
	
	print("=== SIGNAL CONNECTION COMPLETE ===")

func _on_target_disappeared(target_id: String = ""):
	"""Handle when a target has completed its disappear animation"""
	var current_target_type = target_sequence[current_target_index]
	print("=== TARGET DISAPPEARED ===")
	print("Target type: ", current_target_type)
	print("Target ID: ", target_id)
	print("Target index: ", current_target_index)
	print("Moving to next target...")
	
	current_target_index += 1
	spawn_next_target()

func connect_ipsc_mini_rotate_signals():
	"""Connect signals for ipsc_mini_rotate target (has child ipsc_mini)"""
	var ipsc_mini = current_target_instance.get_node("RotationCenter/IPSCMini")
	if ipsc_mini and ipsc_mini.has_signal("target_hit"):
		if ipsc_mini.target_hit.is_connected(_on_target_hit):
			ipsc_mini.target_hit.disconnect(_on_target_hit)
		ipsc_mini.target_hit.connect(_on_target_hit)
		print("Connected to ipsc_mini_rotate signals")
		
		# Connect disappear signal
		if ipsc_mini.has_signal("target_disappeared"):
			if ipsc_mini.target_disappeared.is_connected(_on_target_disappeared):
				ipsc_mini.target_disappeared.disconnect(_on_target_disappeared)
			ipsc_mini.target_disappeared.connect(_on_target_disappeared)

func connect_paddle_signals():
	"""Connect signals for paddle targets (3paddles composite target)"""
	print("=== CONNECTING TO 3PADDLES SIGNALS ===")
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		current_target_instance.target_hit.connect(_on_target_hit)
		print("Connected to 3paddles target_hit signal")
		
		# Connect disappear signal
		if current_target_instance.has_signal("target_disappeared"):
			if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
				current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
			current_target_instance.target_disappeared.connect(_on_target_disappeared)
			print("Connected to 3paddles target_disappeared signal")
	else:
		print("WARNING: 3paddles target doesn't have expected signals!")

func connect_2poppers_signals():
	"""Connect signals for popper targets (2poppers composite target)"""
	print("=== CONNECTING TO 2POPPERS SIGNALS ===")
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		current_target_instance.target_hit.connect(_on_target_hit)
		print("Connected to 2poppers target_hit signal")
		
		# Connect disappear signal
		if current_target_instance.has_signal("target_disappeared"):
			if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
				current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
			current_target_instance.target_disappeared.connect(_on_target_disappeared)
			print("Connected to 2poppers target_disappeared signal")
	else:
		print("WARNING: 2poppers target doesn't have expected signals!")

func _on_target_hit(param1, param2 = null, param3 = null, param4 = null):
	"""Handle when a target is hit - supports both simple targets and composite targets"""
	var current_target_type = target_sequence[current_target_index]
	var hit_area = ""
	var hit_position = Vector2.ZERO
	
	# Handle different signal signatures
	if current_target_type == "3paddles":
		# 3paddles sends: paddle_id, zone, points, hit_position
		var paddle_id = param1
		var zone = str(param2)
		var actual_points = param3
		hit_position = param4
		hit_area = "Paddle"
		print("Target hit: ", current_target_type, " paddle: ", paddle_id, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += actual_points
	elif current_target_type == "2poppers":
		# 2poppers sends: popper_id, zone, points, hit_position
		var popper_id = param1
		var zone = str(param2)
		var actual_points = param3
		hit_position = param4
		hit_area = "Popper"
		print("Target hit: ", current_target_type, " popper: ", popper_id, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += actual_points
	else:
		# Simple targets send: zone, points, hit_position
		var zone = param1
		var actual_points = param2
		hit_position = param3
		hit_area = zone
		print("Target hit: ", current_target_type, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += actual_points
	
	print("Total drill score: ", total_drill_score)
	
	# Special handling for rotating target
	if current_target_type == "ipsc_mini_rotate":
		rotating_target_hits += 1
		print("Rotating target hit count: ", rotating_target_hits)
		
		# Check if we've reached 2 hits on the rotating target
		if rotating_target_hits >= 2:
			print("2 hits on rotating target reached! Finishing drill immediately.")
			finish_drill_immediately()
			return
	
	# Emit the enhanced target_hit signal for performance tracking
	emit_signal("target_hit", current_target_type, hit_position, hit_area)
	
	# Update the fastest interval display
	update_fastest_interval_display()

func complete_drill():
	"""Complete the drill sequence"""
	print("=== DRILL COMPLETED! ===")
	print("Final score: ", total_drill_score)
	print("Targets completed: ", current_target_index, "/", target_sequence.size())
	drill_completed = true
	
	# Stop the drill timer
	stop_drill_timer()
	
	# Emit drills finished signal for performance tracking
	emit_signal("drills_finished")
	
	# Reset for next run
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	rotating_target_hits = 0
	
	# Reset timer
	elapsed_seconds = 0.0
	update_timer_display()
	
	# Show shot timer overlay again for next run after a brief delay
	await get_tree().create_timer(2.0).timeout  # Wait 2 seconds before showing timer
	show_shot_timer()
	
	# You can add additional completion logic here
	# For example: show results screen, save score, transition to next drill, etc.

func finish_drill_immediately():
	"""Finish the drill immediately after 2 hits on rotating target"""
	print("=== DRILL FINISHED IMMEDIATELY! ===")
	print("Final score: ", total_drill_score)
	print("Targets completed: ", current_target_index, "/", target_sequence.size())
	drill_completed = true
	
	# Stop the drill timer
	stop_drill_timer()
	
	# Freeze the screen by disabling bullet spawning
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = false
	
	# Show the completion overlay
	show_completion_overlay()
	
	# Wait a moment to ensure the overlay is visible before resetting
	await get_tree().create_timer(0.5).timeout
	
	# Emit drills finished signal for performance tracking (after overlay is shown)
	emit_signal("drills_finished")
	
	# Clear the current target to prevent further interactions
	clear_current_target()
	
	# Reset tracking variables for next run
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	rotating_target_hits = 0
	
	# Reset timer
	elapsed_seconds = 0.0
	update_timer_display()
	
	# Reset performance tracker for next drill
	performance_tracker.reset_fastest_time()
	update_fastest_interval_display()

func show_completion_overlay():
	"""Show the completion overlay with drill statistics"""
	print("Showing completion overlay")
	
	# Get the final statistics
	var final_time = elapsed_seconds
	var fastest_time = performance_tracker.get_fastest_time_diff()
	var final_score = total_drill_score
	
	# Format the time display
	var total_seconds = int(final_time)
	var milliseconds = int((final_time - total_seconds) * 100)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
	
	# Format the fastest time
	var fastest_string = "--"
	if fastest_time < 999.0:
		fastest_string = "%.2fs" % fastest_time
	
	# Create the completion message
	var completion_text = """DRILL COMPLETE!

Total Time: %s
Fastest Shot: %s
Final Score: %d

Press R to restart""" % [time_string, fastest_string, final_score]
	
	drill_complete_overlay.text = completion_text
	drill_complete_overlay.visible = true

func update_fastest_interval_display():
	"""Update the fastest interval label with the current fastest time"""
	var fastest_time = performance_tracker.get_fastest_time_diff()
	if fastest_time < 999.0:  # Only update if we have a valid time
		fastest_interval_label.text = "%.2fs" % fastest_time
	else:
		fastest_interval_label.text = "--"

func restart_drill():
	"""Restart the drill from the beginning"""
	print("=== RESTARTING DRILL ===")
	
	# Reset all tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	rotating_target_hits = 0
	
	# Reset performance tracker
	performance_tracker.reset_fastest_time()
	performance_tracker.reset_shot_timer()
	update_fastest_interval_display()
	
	# Clear the current target
	clear_current_target()
	
	# Show shot timer overlay again (which will spawn inactive target)
	show_shot_timer()
	
	print("Drill restarted!")

func is_bullet_spawning_allowed() -> bool:
	"""Check if bullet spawning is currently allowed"""
	return bullets_allowed

func get_drills_manager():
	"""Return reference to this drills manager for targets to use"""
	return self
