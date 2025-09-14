extends Control

# Preload the scenes for the drill sequence
@export var ipsc_mini_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")
@export var hostage_scene: PackedScene = preload("res://scene/hostage.tscn")
@export var two_poppers_scene: PackedScene = preload("res://scene/2poppers.tscn")
#@export var paddle_scene: PackedScene = preload("res://scene/paddle.tscn")
@export var three_paddles_scene: PackedScene = preload("res://scene/3paddles.tscn")
@export var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")

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
@onready var drill_timer = $DrillUI/DrillTimer

# Performance tracking
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float)
signal drills_finished

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

# UI update signals
signal ui_timer_update(elapsed_seconds: float)
signal ui_target_title_update(target_index: int, total_targets: int)
signal ui_fastest_time_update(fastest_time: float)
signal ui_show_completion(final_time: float, fastest_time: float, final_score: int)
signal ui_show_shot_timer()
signal ui_hide_shot_timer()
signal ui_theme_change(theme_name: String)
signal ui_score_update(score: int)
signal ui_progress_update(targets_completed: int)

@onready var performance_tracker = preload("res://script/performance_tracker.gd").new()

func _ready():
	"""Initialize the drill with the first target"""
	if DEBUG_LOGGING:
		print("=== STARTING DRILL ===")
	emit_signal("ui_theme_change", "golden")  # Set default theme
	emit_signal("ui_progress_update", 0)  # Initialize progress bar
	
	# Clear any existing targets in the center container
	clear_current_target()
	
	# Ensure the center container doesn't block mouse input
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect shot timer signals via DrillUI
	var drill_ui = $DrillUI
	if drill_ui:
		var shot_timer_overlay = drill_ui.get_node("ShotTimerOverlay")
		if shot_timer_overlay:
			shot_timer_overlay.timer_ready.connect(_on_shot_timer_ready)
			shot_timer_overlay.timer_reset.connect(_on_shot_timer_reset)
	
	# Connect drill timer signal
	drill_timer.timeout.connect(_on_drill_timer_timeout)
	
	# Instantiate and add performance tracker
	add_child(performance_tracker)
	target_hit.connect(performance_tracker._on_target_hit)
	drills_finished.connect(performance_tracker._on_drills_finished)
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_LOGGING:
			print("[Drills] Connecting to WebSocketListener.menu_control signal")
	else:
		if DEBUG_LOGGING:
			print("[Drills] WebSocketListener singleton not found!")
	
	# Show shot timer overlay before starting drill
	show_shot_timer()

func show_shot_timer():
	"""Show the shot timer overlay"""
	if DEBUG_LOGGING:
		print("=== SHOWING SHOT TIMER OVERLAY ===")
	emit_signal("ui_show_shot_timer")
	
	# Disable bullet spawning during shot timer
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = false
	
	# No target should be visible during shot timer phase
	clear_current_target()

func hide_shot_timer():
	"""Hide the shot timer overlay"""
	if DEBUG_LOGGING:
		print("=== HIDING SHOT TIMER OVERLAY ===")
	emit_signal("ui_hide_shot_timer")

func _on_shot_timer_ready():
	"""Handle when shot timer beep occurs - start the drill"""
	if DEBUG_LOGGING:
		print("=== SHOT TIMER READY - STARTING DRILL ===")
	# Wait for the beep to finish and "Ready" text to disappear
	await get_tree().create_timer(0.5).timeout
	# Start the drill timer
	start_drill_timer()
	# Now spawn the target normally (this will enable bullet spawning when ready)
	await spawn_next_target()
	# Hide the shot timer overlay after target is spawned
	hide_shot_timer()

func _on_shot_timer_reset():
	"""Handle when shot timer is reset"""
	if DEBUG_LOGGING:
		print("=== SHOT TIMER RESET ===")
	# Could add additional logic here if needed

func _on_drill_timer_timeout():
	"""Handle drill timer timeout - update elapsed time display"""
	elapsed_seconds += 0.1
	emit_signal("ui_timer_update", elapsed_seconds)

func start_drill_timer():
	"""Start the drill elapsed time timer"""
	elapsed_seconds = 0.0
	drill_start_time = Time.get_unix_time_from_system()
	emit_signal("ui_timer_update", elapsed_seconds)
	drill_timer.start()
	
	# Reset performance tracker timing for accurate first shot measurement
	performance_tracker.reset_shot_timer()
	
	# Reset fastest time for the new drill
	performance_tracker.reset_fastest_time()
	emit_signal("ui_fastest_time_update", 999.0)  # Reset to show "--"
	
	if DEBUG_LOGGING:
		print("=== DRILL TIMER STARTED ===")

func stop_drill_timer():
	"""Stop the drill elapsed time timer"""
	drill_timer.stop()
	if DEBUG_LOGGING:
		print("=== DRILL TIMER STOPPED ===")

func _process(_delta):
	"""Main process loop - UI updates are handled by drill_ui.gd"""
	pass

# func _unhandled_input(_event):
# 	"""Handle input events for theme switching (testing purposes)"""
# 	# Don't process input if the completion overlay is visible
# 	var drill_ui = get_node_or_null("DrillUI")
# 	if drill_ui:
# 		var completion_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
# 		if completion_overlay and completion_overlay.visible:
# 			print("=== DRILLS.GD: Completion overlay is visible, ignoring input ===")
# 			return
	
# 	if _event is InputEventMouseButton and _event.pressed:
# 		print("=== DRILLS.GD received unhandled mouse click ===")
# 		print("Position: ", _event.global_position)
# 		print("Button: ", _event.button_index)
	
# 	if _event is InputEventKey and _event.pressed:
# 		match _event.keycode:
# 			KEY_1:
# 				emit_signal("ui_theme_change", "golden")
# 			KEY_2:
# 				emit_signal("ui_theme_change", "tactical")
# 			KEY_3:
# 				emit_signal("ui_theme_change", "competitive")
# 			KEY_R:
# 				restart_drill()

func update_target_title():
	"""Update the target title based on the current target number"""
	emit_signal("ui_target_title_update", current_target_index, target_sequence.size())
	if DEBUG_LOGGING:
		print("Updated title to: Target ", current_target_index + 1, "/", target_sequence.size())

func spawn_next_target():
	"""Spawn the next target in the sequence"""
	if current_target_index >= target_sequence.size():
		complete_drill()
		return
	
	var target_type = target_sequence[current_target_index]
	if DEBUG_LOGGING:
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
			if DEBUG_LOGGING:
				print("ERROR: Unknown target type: ", target_type)
			return
	
	# Update the title
	update_target_title()
	
	# Connect signals for the new target
	connect_target_signals()
	
	# Re-enable bullet spawning after target is fully ready
	await get_tree().process_frame  # Ensure target is fully initialized
	bullets_allowed = true
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = true
	if DEBUG_LOGGING:
		print("Bullet spawning re-enabled for new target: ", target_type)

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
	if DEBUG_LOGGING:
		print("IPSC Mini target spawned")

func spawn_hostage():
	"""Spawn a hostage target"""
	if DEBUG_LOGGING:
		print("=== SPAWNING HOSTAGE TARGET ===")
	var target = hostage_scene.instantiate()
	center_container.add_child(target)
	
	current_target_instance = target
	if DEBUG_LOGGING:
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
	if DEBUG_LOGGING:
		print("2poppers target spawned")

func spawn_3paddles():
	"""Spawn a 3paddles composite target"""
	var target = three_paddles_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	if DEBUG_LOGGING:
		print("3paddles target spawned")

func spawn_ipsc_mini_rotate():
	"""Spawn an IPSC mini rotating target"""
	var target = ipsc_mini_rotate_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	
	target.position = Vector2(-200, 200)
	
	# Reset rotating target hit counter
	rotating_target_hits = 0
	if DEBUG_LOGGING:
		print("Rotating target hit counter reset to 0")
	
	# Wait for the node to be fully added to the scene
	await get_tree().process_frame
	
	if DEBUG_LOGGING:
		print("IPSC Mini Rotate target spawned and positioned")

func connect_target_signals():
	"""Connect to the current target's signals"""
	if not current_target_instance:
		if DEBUG_LOGGING:
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
	if DEBUG_LOGGING:
		print("=== CONNECTING SIMPLE TARGET SIGNALS ===")
		print("Target instance: ", current_target_instance)
	if current_target_instance:
		if DEBUG_LOGGING:
			print("Target name: ", current_target_instance.name)
			print("Target type: ", target_sequence[current_target_index])
	else:
		if DEBUG_LOGGING:
			print("Target name: None")
	
	if current_target_instance.has_signal("target_hit"):
		# Disconnect any existing connections
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		
		# Connect the signal
		current_target_instance.target_hit.connect(_on_target_hit)
		if DEBUG_LOGGING:
			print("Connected to target_hit signal")
	else:
		if DEBUG_LOGGING:
			print("WARNING: target_hit signal not found!")
	
	# Connect to disappear signal if available
	if current_target_instance.has_signal("target_disappeared"):
		if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
			current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
		current_target_instance.target_disappeared.connect(_on_target_disappeared)
		if DEBUG_LOGGING:
			print("Connected to target_disappeared signal")
	else:
		if DEBUG_LOGGING:
			print("WARNING: target_disappeared signal not found!")
	
	if DEBUG_LOGGING:
		print("=== SIGNAL CONNECTION COMPLETE ===")

func _on_target_disappeared(target_id: String = ""):
	"""Handle when a target has completed its disappear animation"""
	var current_target_type = target_sequence[current_target_index]
	if DEBUG_LOGGING:
		print("=== TARGET DISAPPEARED ===")
		print("Target type: ", current_target_type)
		print("Target ID: ", target_id)
		print("Target index: ", current_target_index)
		print("Moving to next target...")
	
	# Disable bullet spawning during target transition
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = false
	if DEBUG_LOGGING:
		print("Bullet spawning disabled during target transition")
	
	current_target_index += 1
	
	# Update progress bar - current_target_index now represents completed targets
	emit_signal("ui_progress_update", current_target_index)
	
	spawn_next_target()

func connect_ipsc_mini_rotate_signals():
	"""Connect signals for ipsc_mini_rotate target (has child ipsc_mini)"""
	var ipsc_mini = current_target_instance.get_node("RotationCenter/IPSCMini")
	if ipsc_mini and ipsc_mini.has_signal("target_hit"):
		if ipsc_mini.target_hit.is_connected(_on_target_hit):
			ipsc_mini.target_hit.disconnect(_on_target_hit)
		ipsc_mini.target_hit.connect(_on_target_hit)
		if DEBUG_LOGGING:
			print("Connected to ipsc_mini_rotate signals")
		
		# Connect disappear signal
		if ipsc_mini.has_signal("target_disappeared"):
			if ipsc_mini.target_disappeared.is_connected(_on_target_disappeared):
				ipsc_mini.target_disappeared.disconnect(_on_target_disappeared)
			ipsc_mini.target_disappeared.connect(_on_target_disappeared)

func connect_paddle_signals():
	"""Connect signals for paddle targets (3paddles composite target)"""
	if DEBUG_LOGGING:
		print("=== CONNECTING TO 3PADDLES SIGNALS ===")
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		current_target_instance.target_hit.connect(_on_target_hit)
		if DEBUG_LOGGING:
			print("Connected to 3paddles target_hit signal")
		
		# Connect disappear signal
		if current_target_instance.has_signal("target_disappeared"):
			if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
				current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
			current_target_instance.target_disappeared.connect(_on_target_disappeared)
			if DEBUG_LOGGING:
				print("Connected to 3paddles target_disappeared signal")
	else:
		if DEBUG_LOGGING:
			print("WARNING: 3paddles target doesn't have expected signals!")

func connect_2poppers_signals():
	"""Connect signals for popper targets (2poppers composite target)"""
	if DEBUG_LOGGING:
		print("=== CONNECTING TO 2POPPERS SIGNALS ===")
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		current_target_instance.target_hit.connect(_on_target_hit)
		if DEBUG_LOGGING:
			print("Connected to 2poppers target_hit signal")
		
		# Connect disappear signal
		if current_target_instance.has_signal("target_disappeared"):
			if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
				current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
			current_target_instance.target_disappeared.connect(_on_target_disappeared)
			if DEBUG_LOGGING:
				print("Connected to 2poppers target_disappeared signal")
	else:
		if DEBUG_LOGGING:
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
		if DEBUG_LOGGING:
			print("Target hit: ", current_target_type, " paddle: ", paddle_id, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += actual_points
	elif current_target_type == "2poppers":
		# 2poppers sends: popper_id, zone, points, hit_position
		var popper_id = param1
		var zone = str(param2)
		var actual_points = param3
		hit_position = param4
		hit_area = "Popper"
		if DEBUG_LOGGING:
			print("Target hit: ", current_target_type, " popper: ", popper_id, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += actual_points
	else:
		# Simple targets send: zone, points, hit_position
		var zone = param1
		var actual_points = param2
		hit_position = param3
		hit_area = zone
		if DEBUG_LOGGING:
			print("Target hit: ", current_target_type, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += actual_points
	
	if DEBUG_LOGGING:
		print("Total drill score: ", total_drill_score)
	emit_signal("ui_score_update", total_drill_score)
	
	# Get rotation angle for rotating targets
	var rotation_angle = 0.0
	if current_target_type == "ipsc_mini_rotate" and current_target_instance:
		var rotation_center = current_target_instance.get_node("RotationCenter")
		if rotation_center:
			rotation_angle = rotation_center.rotation
			if DEBUG_LOGGING:
				print("Rotating target hit at rotation angle: ", rotation_angle, " radians (", rad_to_deg(rotation_angle), " degrees)")
	
	# Emit the enhanced target_hit signal for performance tracking
	emit_signal("target_hit", current_target_type, hit_position, hit_area, rotation_angle)
	
	# Special handling for rotating target
	if current_target_type == "ipsc_mini_rotate":
		rotating_target_hits += 1
		if DEBUG_LOGGING:
			print("Rotating target hit count: ", rotating_target_hits)
		
		# Check if we've reached 2 hits on the rotating target
		if rotating_target_hits >= 2:
			if DEBUG_LOGGING:
				print("2 hits on rotating target reached! Finishing drill immediately.")
			# Update progress - since this is the last target, set to completed
			current_target_index += 1  # Mark this target as completed
			emit_signal("ui_progress_update", current_target_index)
			complete_drill()
			# Don't return here - let the performance tracking signal be emitted
	
	# Update the fastest interval display
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_fastest_time_update", fastest_time)

func complete_drill():
	"""Complete the drill sequence and show completion overlay"""
	if DEBUG_LOGGING:
		print("=== DRILL COMPLETED! ===")
		print("Final score: ", total_drill_score)
		print("Targets completed: ", current_target_index, "/", target_sequence.size())
	drill_completed = true
	
	# Stop the drill timer
	stop_drill_timer()
	
	# Hide the shot timer since drill is complete
	hide_shot_timer()
	
	# Temporarily disable bullet spawning to freeze gameplay
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_spawning_enabled = false
	
	# Show the completion overlay
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_show_completion", elapsed_seconds, fastest_time, total_drill_score)
	
	# Set the total elapsed time in performance tracker before finishing
	performance_tracker.set_total_elapsed_time(elapsed_seconds)
	
	# Wait a moment to ensure the overlay is visible before enabling bullets
	await get_tree().create_timer(0.1).timeout
	
	# Re-enable bullet spawning for overlay interactions
	if ws_listener:
		ws_listener.bullet_spawning_enabled = true
		if DEBUG_LOGGING:
			print("=== BULLETS RE-ENABLED FOR COMPLETION OVERLAY ===")
	
	# Emit drills finished signal for performance tracking (after overlay is shown)
	emit_signal("drills_finished")
	
	# Clear the current target to prevent further interactions
	clear_current_target()
	
	# Reset tracking variables for next run - but keep UI state for display
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	rotating_target_hits = 0
	
	# DON'T reset progress bar, timer, or fastest time - keep them displayed
	# elapsed_seconds = 0.0  # Keep final time displayed
	# emit_signal("ui_timer_update", elapsed_seconds)
	# emit_signal("ui_progress_update", 0)  # Keep progress at 100%
	
	# Reset performance tracker for next drill - but don't update UI
	performance_tracker.reset_fastest_time()
	# emit_signal("ui_fastest_time_update", 999.0)  # Don't reset UI display

func restart_drill():
	"""Restart the drill from the beginning"""
	if DEBUG_LOGGING:
		print("=== RESTARTING DRILL ===")
	
	# Reset all tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	rotating_target_hits = 0
	
	# NOW reset all UI displays when restarting
	emit_signal("ui_progress_update", 0)  # Reset progress bar
	elapsed_seconds = 0.0
	emit_signal("ui_timer_update", elapsed_seconds)  # Reset timer display
	emit_signal("ui_score_update", 0)  # Reset score display
	
	# Reset performance tracker and UI
	performance_tracker.reset_fastest_time()
	performance_tracker.reset_shot_timer()
	emit_signal("ui_fastest_time_update", 999.0)  # Reset to show "--"
	
	# Clear the current target
	clear_current_target()
	
	# Show shot timer overlay again (which will spawn inactive target)
	show_shot_timer()
	
	if DEBUG_LOGGING:
		print("Drill restarted!")

func is_bullet_spawning_allowed() -> bool:
	"""Check if bullet spawning is currently allowed"""
	return bullets_allowed

func get_drills_manager():
	"""Return reference to this drills manager for targets to use"""
	return self

func _on_menu_control(directive: String):
	if DEBUG_LOGGING:
		print("[Drills] Received menu_control signal with directive: ", directive)
	
	# Check if drill complete overlay is visible and should handle navigation
	var drill_ui = get_node_or_null("DrillUI")
	var drill_complete_overlay = null
	if drill_ui:
		drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
	
	# Forward navigation commands to drill_complete_overlay if it's visible
	if drill_complete_overlay and drill_complete_overlay.visible and directive in ["up", "down", "enter"]:
		if DEBUG_LOGGING:
			print("[Drills] Forwarding navigation directive to drill_complete_overlay: ", directive)
			print("[Drills] drill_complete_overlay script: ", drill_complete_overlay.get_script())
			print("[Drills] drill_complete_overlay has method: ", drill_complete_overlay.has_method("_on_websocket_menu_control"))
		
		if drill_complete_overlay.has_method("_on_websocket_menu_control"):
			drill_complete_overlay._on_websocket_menu_control(directive)
		else:
			# Fallback: Call the navigation methods directly if the main method is missing
			if DEBUG_LOGGING:
				print("[Drills] Using fallback navigation methods")
			match directive:
				"up":
					if drill_complete_overlay.has_method("_navigate_up"):
						drill_complete_overlay._navigate_up()
					else:
						if DEBUG_LOGGING:
							print("[Drills] _navigate_up method not found")
						_manual_navigate_up(drill_complete_overlay)
				"down":
					if drill_complete_overlay.has_method("_navigate_down"):
						drill_complete_overlay._navigate_down()
					else:
						if DEBUG_LOGGING:
							print("[Drills] _navigate_down method not found")
						_manual_navigate_down(drill_complete_overlay)
				"enter":
					if drill_complete_overlay.has_method("_activate_focused_button"):
						drill_complete_overlay._activate_focused_button()
					else:
						if DEBUG_LOGGING:
							print("[Drills] _activate_focused_button method not found")
						# Manual button activation
						_manual_button_activation(drill_complete_overlay)
		return
	
	# Handle drills manager specific commands
	match directive:
		"volume_up":
			if DEBUG_LOGGING:
				print("[Drills] Volume up")
			volume_up()
		"volume_down":
			if DEBUG_LOGGING:
				print("[Drills] Volume down")
			volume_down()
		"power":
			if DEBUG_LOGGING:
				print("[Drills] Power off")
			power_off()
		"back", "homepage":
			if DEBUG_LOGGING:
				print("[Drills] ", directive, " - navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		_:
			if DEBUG_LOGGING:
				print("[Drills] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
			print("[Drills] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		if DEBUG_LOGGING:
			print("[Drills] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
			print("[Drills] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		if DEBUG_LOGGING:
			print("[Drills] HttpService singleton not found!")

func _on_volume_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
		print("[Drills] Volume HTTP response:", result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
			print("[Drills] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		if DEBUG_LOGGING:
			print("[Drills] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
		print("[Drills] Shutdown HTTP response:", result, response_code, body_str)

func _manual_button_activation(overlay):
	"""Manually activate the focused button when script methods are not available"""
	if DEBUG_LOGGING:
		print("[Drills] Attempting manual button activation")
	
	# Try to find the focused button in the overlay
	var restart_button = overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	# Check which button has focus using the viewport
	var focused_control = get_viewport().gui_get_focus_owner()
	
	if focused_control == restart_button:
		if DEBUG_LOGGING:
			print("[Drills] Manually activating restart button")
		_manual_restart_drill()
	elif focused_control == replay_button:
		if DEBUG_LOGGING:
			print("[Drills] Manually activating replay button")
		_manual_go_to_replay()
	else:
		# Default to restart if no focus
		if DEBUG_LOGGING:
			print("[Drills] No button focused, defaulting to restart")
		_manual_restart_drill()

func _manual_restart_drill():
	"""Manually restart the drill when script methods are not available"""
	if DEBUG_LOGGING:
		print("[Drills] Manual restart drill")
	
	# Hide the completion overlay
	var drill_ui = get_node_or_null("DrillUI")
	if drill_ui:
		var drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
		if drill_complete_overlay:
			drill_complete_overlay.visible = false
	
	# Restart the drill
	restart_drill()

func _manual_go_to_replay():
	"""Manually navigate to replay scene when script methods are not available"""
	if DEBUG_LOGGING:
		print("[Drills] Manual navigation to drill replay")
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func _manual_navigate_up(overlay):
	"""Manually navigate up between buttons"""
	if DEBUG_LOGGING:
		print("[Drills] Manual navigate up")
	var restart_button = overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	var focused_control = get_viewport().gui_get_focus_owner()
	
	if focused_control == replay_button and restart_button:
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[Drills] Focused restart button")
	elif restart_button:
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[Drills] Default focus to restart button")

func _manual_navigate_down(overlay):
	"""Manually navigate down between buttons"""
	if DEBUG_LOGGING:
		print("[Drills] Manual navigate down")
	var restart_button = overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	var focused_control = get_viewport().gui_get_focus_owner()
	
	if focused_control == restart_button and replay_button:
		replay_button.grab_focus()
		if DEBUG_LOGGING:
			print("[Drills] Focused replay button")
	elif restart_button:
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[Drills] Default focus to restart button")
