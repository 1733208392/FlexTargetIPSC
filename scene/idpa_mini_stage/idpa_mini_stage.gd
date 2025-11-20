extends Control

# Preload the IDPA mini scene
@export var idpa_mini_scene: PackedScene = preload("res://scene/idpa.tscn")
@export var idpa_mini_ns_scene: PackedScene = preload("res://scene/idpa_mini_stage/idpa-compose.tscn")
@export var idpa_hard_cover_1_scene: PackedScene = preload("res://scene/idpa-hard-cover-1.tscn")
@export var idpa_hard_cover_2_scene: PackedScene = preload("res://scene/idpa-hard-cover-2.tscn")
@export var footsteps_scene: PackedScene = preload("res://scene/footsteps.tscn")

# Drill sequence and progress tracking
var base_target_sequence: Array[String] = ["idpa", "idpa-ns", "idpa-hard-cover-1", "idpa-hard-cover-2"]
var target_sequence: Array[String] = []
var current_target_index: int = 0
var current_target_instance: Node = null
var total_drill_score: int = 0
var drill_completed: bool = false
var bullets_allowed: bool = false
var connected_hit_nodes: Array[Node] = []
var connected_disappear_nodes: Array[Node] = []
var observed_target_node: Node = null

# Elapsed time tracking
var elapsed_seconds: float = 0.0
var drill_start_time: float = 0.0

# Timeout functionality
var timeout_timer: Timer = null
var timeout_seconds: float = 40.0
var drill_timed_out: bool = false
var timeout_beep_player: AudioStreamPlayer = null
var last_beep_second: int = -1

# Node references
@onready var center_container = $CenterContainer
@onready var drill_timer = $DrillUI/DrillTimer
@onready var footsteps_node = $Footsteps

# Performance tracking
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float)
signal drills_finished

# Performance optimization
const DEBUG_DISABLED = false

# UI update signals
signal ui_timer_update(elapsed_seconds: float)
signal ui_target_title_update(target_index: int, total_targets: int)
signal ui_fastest_time_update(fastest_time: float)
signal ui_show_completion(final_time: float, fastest_time: float, final_score: int)
signal ui_show_completion_with_timeout(final_time: float, fastest_time: float, final_score: int, timed_out: bool)
signal ui_hide_completion()
signal ui_show_shot_timer()
signal ui_hide_shot_timer()
signal ui_theme_change(theme_name: String)
signal ui_score_update(score: int)
signal ui_progress_update(targets_completed: int)
signal ui_timeout_warning(remaining_seconds: float)

@onready var performance_tracker = preload("res://script/performance_tracker.gd").new()

func _ready():
	"""Initialize the drill"""
	# Initialize the target sequence
	initialize_target_sequence()
	
	if not DEBUG_DISABLED:
		print("=== STARTING IDPA MINI DRILL ===")
	emit_signal("ui_theme_change", "golden")
	emit_signal("ui_progress_update", 0)
	
	# Clear any existing targets
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
	
	# Create and setup timeout timer
	timeout_timer = Timer.new()
	timeout_timer.wait_time = timeout_seconds
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout_timer_timeout)
	add_child(timeout_timer)
	
	# Create and setup timeout beep audio player
	timeout_beep_player = AudioStreamPlayer.new()
	timeout_beep_player.stream = preload("res://audio/synthetic-shot-timer.wav")
	timeout_beep_player.volume_db = 0.0
	add_child(timeout_beep_player)
	
	# Instantiate and add performance tracker
	add_child(performance_tracker)
	target_hit.connect(performance_tracker._on_target_hit)
	drills_finished.connect(performance_tracker._on_drills_finished)
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not DEBUG_DISABLED:
			print("[IDPA] Connected to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[IDPA] WebSocketListener singleton not found!")
	
	# Hide status bar for drills
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = false
	
	# Show shot timer overlay before starting drill
	show_shot_timer()

func show_shot_timer():
	"""Show the shot timer overlay"""
	if not DEBUG_DISABLED:
		print("=== SHOWING SHOT TIMER OVERLAY ===")
	emit_signal("ui_show_shot_timer")
	
	# Disable bullet spawning during shot timer
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	# No target should be visible during shot timer phase
	clear_current_target()

func hide_shot_timer():
	"""Hide the shot timer overlay"""
	if not DEBUG_DISABLED:
		print("=== HIDING SHOT TIMER OVERLAY ===")
	emit_signal("ui_hide_shot_timer")

func set_target_drill_active(target: Node, active: bool):
	"""Set the drill_active flag on a target"""
	if target and target.has_method("set"):
		target.set("drill_active", active)
		if not DEBUG_DISABLED:
			print("Set drill_active to ", active, " on target: ", target.name)

func _on_shot_timer_ready(delay: float):
	"""Handle when shot timer beep occurs - start the drill"""
	if not DEBUG_DISABLED:
		print("=== SHOT TIMER READY - STARTING DRILL === Delay: ", delay, " seconds")
	
	# Pass the delay to performance tracker
	performance_tracker.set_shot_timer_delay(delay)
	
	# Wait for the beep to finish
	await get_tree().create_timer(0.5).timeout
	# Start the drill timer
	start_drill_timer()
	# Now spawn the first target
	await spawn_next_target()
	# Hide the shot timer overlay after target is spawned
	hide_shot_timer()
	# Activate drill on the spawned target
	if current_target_instance:
		set_target_drill_active(current_target_instance, true)

func _on_shot_timer_reset():
	"""Handle when shot timer is reset"""
	if not DEBUG_DISABLED:
		print("=== SHOT TIMER RESET ===")

func _on_drill_timer_timeout():
	"""Handle drill timer timeout - update elapsed time display"""
	elapsed_seconds += 0.1
	emit_signal("ui_timer_update", elapsed_seconds)
	
	# Check for timeout warning (5 seconds left)
	var remaining_time = timeout_seconds - elapsed_seconds
	if remaining_time <= 5.0 and remaining_time > 0.0:
		emit_signal("ui_timeout_warning", remaining_time)
		
		# Play beep for each remaining second during countdown
		var current_second = int(ceil(remaining_time))
		if current_second != last_beep_second and current_second <= 5:
			last_beep_second = current_second
			if timeout_beep_player:
				timeout_beep_player.play()
				if not DEBUG_DISABLED:
					print("=== TIMEOUT BEEP - %d seconds remaining ===" % current_second)

func start_drill_timer():
	"""Start the drill elapsed time timer"""
	elapsed_seconds = 0.0
	drill_start_time = Time.get_unix_time_from_system()
	drill_timed_out = false
	last_beep_second = -1
	emit_signal("ui_timer_update", elapsed_seconds)
	drill_timer.start()
	
	# Start the timeout timer
	timeout_timer.start()
	
	# Reset performance tracker timing
	performance_tracker.reset_shot_timer()
	performance_tracker.reset_fastest_time()
	emit_signal("ui_fastest_time_update", 999.0)
	
	if not DEBUG_DISABLED:
		print("=== DRILL TIMER STARTED ===")
		print("=== TIMEOUT TIMER STARTED (40 seconds) ===")

func _on_timeout_timer_timeout():
	"""Handle timeout when 40 seconds have elapsed"""
	if not DEBUG_DISABLED:
		print("=== DRILL TIMEOUT! ===")
	drill_timed_out = true
	complete_drill_with_timeout()

func initialize_target_sequence():
	"""Initialize the target sequence"""
	target_sequence = base_target_sequence.duplicate()
	print("\n[INIT DEBUG] === TARGET SEQUENCE INITIALIZED ===")
	print("[INIT DEBUG] Base target sequence: ", base_target_sequence)
	print("[INIT DEBUG] Target sequence: ", target_sequence)
	print("[INIT DEBUG] Sequence size: ", target_sequence.size())
	for i in range(target_sequence.size()):
		print("[INIT DEBUG] Target[", i, "]: ", target_sequence[i])
	print("[INIT DEBUG] === CHECKING SCENE PRELOADS ===")
	print("[INIT DEBUG] idpa_mini_scene: ", idpa_mini_scene)
	print("[INIT DEBUG] idpa_mini_ns_scene: ", idpa_mini_ns_scene)
	print("[INIT DEBUG] idpa_hard_cover_1_scene: ", idpa_hard_cover_1_scene)
	print("[INIT DEBUG] idpa_hard_cover_2_scene: ", idpa_hard_cover_2_scene)
	if not DEBUG_DISABLED:
		print("=== TARGET SEQUENCE INITIALIZED ===")
		print("Sequence: ", target_sequence)

func stop_drill_timer():
	"""Stop the drill elapsed time timer"""
	drill_timer.stop()
	timeout_timer.stop()
	if not DEBUG_DISABLED:
		print("=== DRILL TIMER STOPPED ===")
		print("=== TIMEOUT TIMER STOPPED ===")

func _process(_delta):
	"""Main process loop"""
	pass

func update_target_title():
	"""Update the target title"""
	emit_signal("ui_target_title_update", current_target_index, target_sequence.size())
	if not DEBUG_DISABLED:
		print("Updated title to: Target ", current_target_index + 1, "/", target_sequence.size())

func _find_nodes_with_signal(parent_node: Node, signal_name: String, results: Array) -> void:
	if parent_node == null:
		return
	if parent_node.has_signal(signal_name):
		results.append(parent_node)
	for child in parent_node.get_children():
		if child is Node:
			_find_nodes_with_signal(child, signal_name, results)

func spawn_next_target():
	"""Spawn the next target in the sequence"""
	print("[SPAWN_NEXT] Current target index: ", current_target_index)
	print("[SPAWN_NEXT] Target sequence size: ", target_sequence.size())
	print("[SPAWN_NEXT] Full sequence: ", target_sequence)
	
	if current_target_index >= target_sequence.size():
		print("[SPAWN_NEXT] Index out of bounds - completing drill")
		complete_drill()
		return
	
	var target_type = target_sequence[current_target_index]
	if not DEBUG_DISABLED:
		print("=== SPAWNING TARGET: ", target_type, " (", current_target_index + 1, "/", target_sequence.size(), ") ===")
	
	# Clear any existing target
	clear_current_target()
	
	# Hide footsteps when target appears
	if footsteps_node:
		footsteps_node.visible = false
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
	
	# Spawn the IDPA target
	spawn_idpa_mini()
	
	# Update the title
	update_target_title()
	
	# Connect signals for the new target
	connect_target_signals()
	
	# Activate drill on the spawned target
	if current_target_instance:
		set_target_drill_active(current_target_instance, true)
	
	# Re-enable bullet spawning after target is fully ready
	await get_tree().process_frame
	bullets_allowed = true
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
	if not DEBUG_DISABLED:
		print("Bullet spawning re-enabled for new target: ", target_type)

func clear_current_target():
	"""Remove the current target from the scene"""
	# Disconnect and clear any connected signals from previous target
	for n in connected_hit_nodes:
		if is_instance_valid(n) and n.has_signal("target_hit") and n.target_hit.is_connected(_on_target_hit):
			n.target_hit.disconnect(_on_target_hit)
	connected_hit_nodes.clear()

	for n in connected_disappear_nodes:
		if is_instance_valid(n):
			if n.has_signal("target_disappeared") and n.target_disappeared.is_connected(_on_target_disappeared):
				n.target_disappeared.disconnect(_on_target_disappeared)
			if n.has_signal("composition_disappeared") and n.composition_disappeared.is_connected(_on_target_disappeared):
				n.composition_disappeared.disconnect(_on_target_disappeared)
	connected_disappear_nodes.clear()

	# Deactivate drill on observed node if any
	if observed_target_node:
		set_target_drill_active(observed_target_node, false)
	observed_target_node = null
	
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	
	current_target_instance = null

func spawn_idpa_mini():
	"""Spawn an IDPA mini target based on current target type"""
	var target_type = target_sequence[current_target_index]
	var target: Node = null
	
	print("[SPAWN DEBUG] Target type requested: ", target_type)
	print("[SPAWN DEBUG] idpa_hard_cover_1_scene: ", idpa_hard_cover_1_scene)
	print("[SPAWN DEBUG] idpa_hard_cover_2_scene: ", idpa_hard_cover_2_scene)
	print("[SPAWN DEBUG] Entering spawn_idpa_mini - target_type is: '", target_type, "'")
	
	if target_type == "idpa":
		print("[SPAWN DEBUG] Match: idpa")
		target = idpa_mini_scene.instantiate()
		print("[SPAWN DEBUG] Instantiated idpa")
	elif target_type == "idpa-ns":
		print("[SPAWN DEBUG] Match: idpa-ns")
		target = idpa_mini_ns_scene.instantiate()
		print("[SPAWN DEBUG] Instantiated idpa-ns")
	elif target_type == "idpa-hard-cover-1":
		print("[SPAWN DEBUG] Match: idpa-hard-cover-1")
		print("[SPAWN DEBUG] About to instantiate idpa-hard-cover-1")
		target = idpa_hard_cover_1_scene.instantiate()
		print("[SPAWN DEBUG] Instantiated idpa-hard-cover-1, target is: ", target)
	elif target_type == "idpa-hard-cover-2":
		print("[SPAWN DEBUG] Match: idpa-hard-cover-2")
		print("[SPAWN DEBUG] About to instantiate idpa-hard-cover-2")
		target = idpa_hard_cover_2_scene.instantiate()
		print("[SPAWN DEBUG] Instantiated idpa-hard-cover-2, target is: ", target)
	else:
		print("ERROR: Unknown target type: ", target_type)
		return
	
	print("[SPAWN DEBUG] After spawn logic, target is: ", target)
	if target == null:
		print("ERROR: Failed to instantiate target! target_type was: ", target_type)
		return
	
	center_container.add_child(target)
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("IDPA target spawned - Type: ", target_type)

func connect_target_signals():
	"""Connect to the current target's signals"""
	if not current_target_instance:
		if not DEBUG_DISABLED:
			print("WARNING: No current target instance to connect signals")
		return
	
	if not DEBUG_DISABLED:
		print("=== CONNECTING IDPA TARGET SIGNALS ===")

	# Helper: using top-level _find_nodes_with_signal

	# Find and connect all target_hit signals in the instance or its children
	var hit_nodes: Array = []
	_find_nodes_with_signal(current_target_instance, "target_hit", hit_nodes)
	if hit_nodes.size() > 0:
		for n in hit_nodes:
			if n.target_hit.is_connected(_on_target_hit):
				n.target_hit.disconnect(_on_target_hit)
			n.target_hit.connect(_on_target_hit)
			connected_hit_nodes.append(n)
			if not DEBUG_DISABLED:
				print("Connected to target_hit on node:", n.name)
	else:
		if not DEBUG_DISABLED:
			print("WARNING: target_hit signal not found on instance or children!")

	# Find and connect target_disappeared or composition_disappeared
	var disp_nodes: Array = []
	_find_nodes_with_signal(current_target_instance, "target_disappeared", disp_nodes)
	_find_nodes_with_signal(current_target_instance, "composition_disappeared", disp_nodes)
	if disp_nodes.size() > 0:
		for n in disp_nodes:
			if n.has_signal("target_disappeared"):
				if n.target_disappeared.is_connected(_on_target_disappeared):
					n.target_disappeared.disconnect(_on_target_disappeared)
				n.target_disappeared.connect(_on_target_disappeared)
				connected_disappear_nodes.append(n)
				if not DEBUG_DISABLED:
					print("Connected to target_disappeared on node:", n.name)
			if n.has_signal("composition_disappeared"):
				if n.composition_disappeared.is_connected(_on_target_disappeared):
					n.composition_disappeared.disconnect(_on_target_disappeared)
				n.composition_disappeared.connect(_on_target_disappeared)
				connected_disappear_nodes.append(n)
				if not DEBUG_DISABLED:
					print("Connected to composition_disappeared on node:", n.name)
	else:
		if not DEBUG_DISABLED:
			print("WARNING: No disappearing signal found on instance or children!")
	
	if not DEBUG_DISABLED:
		print("=== SIGNAL CONNECTION COMPLETE ===")

func _on_target_disappeared(target_id: String = ""):
	"""Handle when target has completed its disappear animation"""
	if not DEBUG_DISABLED:
		print("=== TARGET DISAPPEARED ===")
		print("Target ID: ", target_id)
		print("Target index: ", current_target_index)
	
	print("[TARGET_DISAPPEARED] Before increment - index: ", current_target_index, " size: ", target_sequence.size())
	
	# Disable bullet spawning during target transition
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	current_target_index += 1
	print("[TARGET_DISAPPEARED] After increment - index: ", current_target_index, " size: ", target_sequence.size())
	emit_signal("ui_progress_update", current_target_index)
	
	# Move to next target
	print("[TARGET_DISAPPEARED] Calling spawn_next_target()")
	spawn_next_target()

func _on_target_hit(param1, param2 = null, param3 = null, _param4 = null):
	"""Handle when a target is hit"""
	if current_target_index >= target_sequence.size():
		if not DEBUG_DISABLED:
			print("WARNING: target hit but current_target_index out of bounds")
		return
	
	var current_target_type = target_sequence[current_target_index]
	var hit_area = ""
	var hit_position = Vector2.ZERO
	
	# IDPA mini sends: zone, points, hit_position
	var zone = param1
	var actual_points = param2
	hit_position = param3
	hit_area = zone
	
	if not DEBUG_DISABLED:
		print("Target hit: ", current_target_type, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
	
	total_drill_score += actual_points
	
	if not DEBUG_DISABLED:
		print("Total drill score: ", total_drill_score)
	emit_signal("ui_score_update", total_drill_score)
	
	# Emit the target_hit signal for performance tracking
	var rotation_angle = 0.0
	emit_signal("target_hit", current_target_type, hit_position, hit_area, rotation_angle)
	
	# Update the fastest interval display
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_fastest_time_update", fastest_time)

func complete_drill():
	"""Complete the drill sequence and show completion overlay"""
	if not DEBUG_DISABLED:
		print("=== DRILL COMPLETED! ===")
		print("Final score: ", total_drill_score)
	drill_completed = true
	
	# Stop the drill timer
	stop_drill_timer()
	hide_shot_timer()
	
	# Temporarily disable bullet spawning
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	# Show the completion overlay
	var fastest_time = performance_tracker.get_fastest_time_diff()
	if drill_timed_out:
		emit_signal("ui_show_completion_with_timeout", elapsed_seconds, fastest_time, total_drill_score, true)
	else:
		emit_signal("ui_show_completion", elapsed_seconds, fastest_time, total_drill_score)
	
	# Set the total elapsed time in performance tracker
	performance_tracker.set_total_elapsed_time(elapsed_seconds)
	
	# Wait a moment to ensure the overlay is visible
	await get_tree().create_timer(0.1).timeout
	
	# Re-enable bullet spawning for overlay interactions
	bullets_allowed = true
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("=== BULLETS RE-ENABLED FOR COMPLETION OVERLAY ===")
	
	# Only emit drills finished signal if not timed out
	if not drill_timed_out:
		emit_signal("drills_finished")
	
	# Check for auto restart setting
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("auto_restart") and global_data.settings_dict.get("auto_restart", false):
		var pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		if not DEBUG_DISABLED:
			print("=== AUTO RESTART ENABLED - RESTARTING DRILL ===")
		
		var drill_ui = get_node_or_null("DrillUI")
		if drill_ui:
			var drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
			if drill_complete_overlay and drill_complete_overlay.has_method("start_countdown"):
				drill_complete_overlay.start_countdown(pause_time)
		
		await get_tree().create_timer(pause_time).timeout
		restart_drill()
		return
	
	clear_current_target()
	
	# Reset tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	drill_timed_out = false
	
	# Reset performance tracker
	performance_tracker.reset_fastest_time()

func complete_drill_with_timeout():
	"""Complete the drill due to timeout"""
	if not DEBUG_DISABLED:
		print("=== DRILL TIMED OUT! ===")
		print("Final score: ", total_drill_score)
	drill_completed = true
	drill_timed_out = true
	
	# Stop the drill timer
	stop_drill_timer()
	hide_shot_timer()
	
	# Disable bullet spawning
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	# Show the completion overlay with timeout indication
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_show_completion_with_timeout", elapsed_seconds, fastest_time, total_drill_score, true)
	
	await get_tree().create_timer(0.1).timeout
	
	# Re-enable bullet spawning for overlay interactions
	bullets_allowed = true
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("=== BULLETS RE-ENABLED FOR COMPLETION OVERLAY (TIMEOUT) ===")
	
	# Check for auto restart setting
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("auto_restart") and global_data.settings_dict.get("auto_restart", false):
		var pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		if not DEBUG_DISABLED:
			print("=== AUTO RESTART ENABLED - RESTARTING DRILL AFTER TIMEOUT ===")
		
		var drill_ui = get_node_or_null("DrillUI")
		if drill_ui:
			var drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
			if drill_complete_overlay and drill_complete_overlay.has_method("start_countdown"):
				drill_complete_overlay.start_countdown(pause_time)
		
		await get_tree().create_timer(pause_time).timeout
		restart_drill()
		return
	
	clear_current_target()
	
	# Reset tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	drill_timed_out = false
	
	# Reset performance tracker
	performance_tracker.reset_fastest_time()

func restart_drill():
	"""Restart the drill from the beginning"""
	if not DEBUG_DISABLED:
		print("=== RESTARTING DRILL ===")
	
	# Hide the completion overlay
	emit_signal("ui_hide_completion")
	
	# Reset all tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	drill_timed_out = false
	last_beep_second = -1
	
	# Stop any running timers
	if timeout_timer.is_stopped() == false:
		timeout_timer.stop()
	
	# Re-initialize target sequence
	initialize_target_sequence()
	
	# Reset all UI displays
	emit_signal("ui_progress_update", 0)
	elapsed_seconds = 0.0
	emit_signal("ui_timer_update", elapsed_seconds)
	emit_signal("ui_score_update", 0)
	
	# Reset performance tracker
	performance_tracker.reset_fastest_time()
	performance_tracker.reset_shot_timer()
	emit_signal("ui_fastest_time_update", 999.0)
	
	# Clear the current target
	clear_current_target()
	
	# Show shot timer overlay again
	show_shot_timer()
	
	if not DEBUG_DISABLED:
		print("Drill restarted!")

func is_bullet_spawning_allowed() -> bool:
	"""Check if bullet spawning is currently allowed"""
	return bullets_allowed

func get_drills_manager():
	"""Return reference to this drills manager for targets to use"""
	return self

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[IDPA] Received menu_control signal with directive: ", directive)
	
	# Check if drill complete overlay is visible and should handle navigation
	var drill_ui = get_node_or_null("DrillUI")
	var drill_complete_overlay = null
	if drill_ui:
		drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
	
	# Forward navigation commands to drill_complete_overlay if it's visible
	if drill_complete_overlay and drill_complete_overlay.visible and directive in ["up", "down", "enter"]:
		if not DEBUG_DISABLED:
			print("[IDPA] Forwarding navigation directive to drill_complete_overlay: ", directive)
		
		if drill_complete_overlay.has_method("_on_websocket_menu_control"):
			drill_complete_overlay._on_websocket_menu_control(directive)
		var menu_controller = get_node("/root/MenuController")
		if menu_controller:
			menu_controller.play_cursor_sound()
		return
	
	# Handle drills manager specific commands
	match directive:
		"volume_up":
			if not DEBUG_DISABLED:
				print("[IDPA] Volume up")
			volume_up()
		"volume_down":
			if not DEBUG_DISABLED:
				print("[IDPA] Volume down")
			volume_down()
		"power":
			if not DEBUG_DISABLED:
				print("[IDPA] Power off")
			power_off()
		"back", "homepage":
			if not DEBUG_DISABLED:
				print("[IDPA] ", directive, " - navigating to main menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "drills"
			
			# Show status bar when exiting
			if get_tree():
				var status_bars = get_tree().get_nodes_in_group("status_bar")
				for status_bar in status_bars:
					status_bar.visible = true
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[IDPA] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[IDPA] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)

func _on_volume_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[IDPA] Volume HTTP response:", result, response_code, body_str)

func power_off():
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.set_alert_text(tr("power_off_alert"))
	add_child(dialog)

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false
