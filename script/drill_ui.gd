extends Control

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

# Theme styles for title
@export var golden_title_style: LabelSettings = preload("res://theme/target_title_settings.tres")
@export var tactical_title_style: LabelSettings = preload("res://theme/target_title_tactical.tres")
@export var competitive_title_style: LabelSettings = preload("res://theme/target_title_competitive.tres")
var current_theme_style: String = "golden"

# Timeout warning state
var timeout_warning_active: bool = false

# UI Node references
@onready var target_type_title = $TopContainer/TopLayout/HeaderContainer/TargetTypeTitle
@onready var fps_label = $FPSLabel
@onready var shot_timer_overlay = $ShotTimerOverlay
@onready var drill_complete_overlay = $drill_complete_overlay
@onready var fastest_interval_label = $TopContainer/TopLayout/HeaderContainer/FastestContainer/FastestInterval
@onready var timer_label = $TopContainer/TopLayout/TimerContainer/Timer
@onready var score_label = $TopContainer/TopLayout/HeaderContainer/ScoreContainer/Score
@onready var progress_bar = $TopContainer/TopLayout/ProgressBarContainer/CustomProgressBar

func _ready():
	"""Initialize the drill UI"""
	if DEBUG_LOGGING:
		print("=== DRILL UI INITIALIZED ===")
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	apply_title_theme("golden")  # Set default theme
	
	# Connect to the parent drills manager signals
	var drills_manager = get_parent()
	if drills_manager:
		# Connect UI update signals
		if drills_manager.has_signal("ui_timer_update"):
			drills_manager.ui_timer_update.connect(_on_timer_update)
		if drills_manager.has_signal("ui_target_title_update"):
			drills_manager.ui_target_title_update.connect(_on_target_title_update)
		if drills_manager.has_signal("ui_fastest_time_update"):
			drills_manager.ui_fastest_time_update.connect(_on_fastest_time_update)
		if drills_manager.has_signal("ui_show_completion"):
			drills_manager.ui_show_completion.connect(_on_show_completion)
		if drills_manager.has_signal("ui_show_completion_with_timeout"):
			drills_manager.ui_show_completion_with_timeout.connect(_on_show_completion_with_timeout)
		if drills_manager.has_signal("ui_timeout_warning"):
			drills_manager.ui_timeout_warning.connect(_on_timeout_warning)
		if drills_manager.has_signal("ui_score_update"):
			drills_manager.ui_score_update.connect(_on_score_update)
		if drills_manager.has_signal("ui_theme_change"):
			drills_manager.ui_theme_change.connect(_on_theme_change)
		if drills_manager.has_signal("ui_show_shot_timer"):
			drills_manager.ui_show_shot_timer.connect(_on_show_shot_timer)
		if drills_manager.has_signal("ui_hide_shot_timer"):
			drills_manager.ui_hide_shot_timer.connect(_on_hide_shot_timer)
		if drills_manager.has_signal("ui_progress_update"):
			drills_manager.ui_progress_update.connect(_on_progress_update)
		
		if DEBUG_LOGGING:
			print("[DrillUI] Connected to drills manager UI signals")

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if DEBUG_LOGGING:
			print("[DrillUI] Loaded language from GlobalData: ", language)
	else:
		if DEBUG_LOGGING:
			print("[DrillUI] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh_CN"
		"Traditional Chinese":
			locale = "zh_TW"
		"Japanese":
			locale = "ja"
		_:
			locale = "en"  # Default to English
	TranslationServer.set_locale(locale)
	if DEBUG_LOGGING:
		print("[DrillUI] Set locale to: ", locale)

func _on_timer_update(time_elapsed: float):
	"""Update the timer display with the current elapsed time"""
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	var milliseconds = int((time_elapsed - int(time_elapsed)) * 100)
	
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
	timer_label.text = time_string
	
	# Change color to red if timeout warning is active
	if timeout_warning_active:
		timer_label.modulate = Color.RED
	else:
		timer_label.modulate = Color.WHITE

func _on_timeout_warning(remaining_seconds: float):
	"""Handle timeout warning - show red timer"""
	timeout_warning_active = true
	if DEBUG_LOGGING:
		print("[DrillUI] Timeout warning activated - %.1f seconds remaining" % remaining_seconds)

func _process(_delta):
	"""Update FPS counter every frame"""
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: " + str(fps)

func _on_target_title_update(target_index: int, total_targets: int):
	"""Update the target title based on the current target number"""
	var target_number = target_index + 1
	target_type_title.text = tr("target") + " " + str(target_number) + "/" + str(total_targets)
	if DEBUG_LOGGING:
		print("Updated title to: ", tr("target"), " ", target_number, "/", total_targets)

func _on_theme_change(theme_name: String):
	"""Apply a specific theme style to the target title"""
	apply_title_theme(theme_name)

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
			if DEBUG_LOGGING:
				print("Unknown theme: ", theme_name)
			return
	
	current_theme_style = theme_name
	if DEBUG_LOGGING:
		print("Applied theme: ", theme_name)

func _on_fastest_time_update(fastest_time: float):
	"""Update the fastest interval label with the current fastest time"""
	if fastest_time < 999.0:  # Only update if we have a valid time
		fastest_interval_label.text = "%.2fs" % fastest_time
	else:
		fastest_interval_label.text = "--"

func _on_score_update(score: int):
	"""Update the score display"""
	score_label.text = str(score)

func _on_progress_update(targets_completed: int):
	"""Update the progress bar based on targets completed"""
	if progress_bar and progress_bar.has_method("update_progress"):
		progress_bar.update_progress(targets_completed)
	else:
		if DEBUG_LOGGING:
			print("Warning: Progress bar not found or missing update_progress method")

func _on_show_completion(final_time: float, fastest_time: float, final_score: int):
	"""Show the completion overlay with drill statistics"""
	if DEBUG_LOGGING:
		print("Showing completion overlay")
	
	# Calculate hit factor (simple example: score / time)
	var hit_factor = 0.0
	if final_time > 0:
		hit_factor = final_score / final_time
	
	# Check if the overlay has its script properly attached
	if drill_complete_overlay.get_script() == null:
		if DEBUG_LOGGING:
			print("[drill_ui] Script missing from drill_complete_overlay, attempting to reattach")
		var script_path = "res://script/drill_complete_overlay.gd"
		var script = load(script_path)
		if script:
			drill_complete_overlay.set_script(script)
			if DEBUG_LOGGING:
				print("[drill_ui] Script reattached successfully")
		else:
			if DEBUG_LOGGING:
				print("[drill_ui] Failed to load drill_complete_overlay script")
	
	# Try to use the new method if available
	if drill_complete_overlay.has_method("show_drill_complete"):
		drill_complete_overlay.show_drill_complete(final_score, hit_factor, fastest_time)
		if DEBUG_LOGGING:
			print("Updated drill complete overlay with: score=%d, hit_factor=%.2f, fastest=%.2f" % [final_score, hit_factor, fastest_time])
	else:
		# Fallback to manual update
		if DEBUG_LOGGING:
			print("[drill_ui] Using fallback method to update overlay")
		
		# Update individual labels
		var completion_score_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Score")
		var hf_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/HitFactor")
		var fastest_shot_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/FastestShot")
		
		if completion_score_label:
			completion_score_label.text = "Score: %d points" % final_score
		if hf_label:
			hf_label.text = "Hit Factor: %.2f" % hit_factor
		if fastest_shot_label:
			var fastest_string = "%.2fs" % fastest_time if fastest_time < 999.0 else "--"
			fastest_shot_label.text = "Fastest Shot: " + fastest_string
		
		drill_complete_overlay.visible = true
	
	# Connect button signals and set up focus
	connect_completion_overlay_buttons()
	setup_overlay_focus()
	
	# Reset timeout warning state and timer color
	timeout_warning_active = false
	timer_label.modulate = Color.WHITE

func _on_show_completion_with_timeout(final_time: float, fastest_time: float, final_score: int, timed_out: bool):
	"""Show the completion overlay with timeout message"""
	if DEBUG_LOGGING:
		print("Showing completion overlay with timeout")
	
	# Calculate hit factor (simple example: score / time)
	var hit_factor = 0.0
	if final_time > 0:
		hit_factor = final_score / final_time
	
	# Check if the overlay has its script properly attached
	if drill_complete_overlay.get_script() == null:
		if DEBUG_LOGGING:
			print("[drill_ui] Script missing from drill_complete_overlay, attempting to reattach")
		var script_path = "res://script/drill_complete_overlay.gd"
		var script = load(script_path)
		if script:
			drill_complete_overlay.set_script(script)
			if DEBUG_LOGGING:
				print("[drill_ui] Script reattached successfully")
		else:
			if DEBUG_LOGGING:
				print("[drill_ui] Failed to load drill_complete_overlay script")
	
	# Try to use the new method if available
	if drill_complete_overlay.has_method("show_drill_complete_with_timeout"):
		drill_complete_overlay.show_drill_complete_with_timeout(final_score, hit_factor, fastest_time, timed_out)
		if DEBUG_LOGGING:
			print("Updated drill complete overlay with timeout: score=%d, hit_factor=%.2f, fastest=%.2f, timed_out=%s" % [final_score, hit_factor, fastest_time, timed_out])
	else:
		# Fallback to manual update with timeout handling
		if DEBUG_LOGGING:
			print("[drill_ui] Using fallback method to update overlay with timeout")
		
		# Update individual labels
		var title_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Title")
		var completion_score_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Score")
		var hf_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/HitFactor")
		var fastest_shot_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/FastestShot")
		
		# Set timeout title in red
		if title_label and timed_out:
			title_label.text = "TIMEOUT!"
			title_label.modulate = Color.RED
		elif title_label:
			title_label.text = "Drill Completed"
			title_label.modulate = Color.WHITE
		
		if completion_score_label:
			completion_score_label.text = "Score: %d points" % final_score
		if hf_label:
			hf_label.text = "Hit Factor: %.2f" % hit_factor
		if fastest_shot_label:
			var fastest_string = "%.2fs" % fastest_time if fastest_time < 999.0 else "--"
			fastest_shot_label.text = "Fastest Shot: " + fastest_string
		
		drill_complete_overlay.visible = true
	
	# Connect button signals and set up focus
	connect_completion_overlay_buttons()
	setup_overlay_focus()
	
	# Reset timeout warning state and timer color
	timeout_warning_active = false
	timer_label.modulate = Color.WHITE

func connect_completion_overlay_buttons():
	"""Connect the completion overlay button signals"""
	var restart_button = drill_complete_overlay.get_node("VBoxContainer/RestartButton")
	var review_replay_button = drill_complete_overlay.get_node("VBoxContainer/ReviewReplayButton")
	
	if restart_button:
		# Disconnect any existing connections to avoid duplicates
		if restart_button.pressed.is_connected(_on_restart_button_pressed):
			restart_button.pressed.disconnect(_on_restart_button_pressed)
		restart_button.pressed.connect(_on_restart_button_pressed)
		if DEBUG_LOGGING:
			print("Connected restart button signal")
	
	if review_replay_button:
		# Disconnect any existing connections to avoid duplicates
		if review_replay_button.pressed.is_connected(_on_review_replay_button_pressed):
			review_replay_button.pressed.disconnect(_on_review_replay_button_pressed)
		review_replay_button.pressed.connect(_on_review_replay_button_pressed)
		if DEBUG_LOGGING:
			print("Connected review replay button signal")

func _on_restart_button_pressed():
	"""Handle restart button click - restart the drill"""
	if DEBUG_LOGGING:
		print("Restart button pressed - restarting drill")
	
	# Reset timeout warning state
	timeout_warning_active = false
	
	# Reset timer color back to white
	timer_label.modulate = Color.WHITE
	
	# Hide the completion overlay
	drill_complete_overlay.visible = false
	
	# Call restart drill on the parent drills manager
	var drills_manager = get_parent()
	if drills_manager and drills_manager.has_method("restart_drill"):
		drills_manager.restart_drill()
	else:
		if DEBUG_LOGGING:
			print("Warning: Could not find drills manager or restart_drill method")

func _on_review_replay_button_pressed():
	"""Handle review and replay button click - navigate to drill replay scene"""
	if DEBUG_LOGGING:
		print("Review and replay button pressed - navigating to drill replay")
	
	# Navigate to the drill replay scene
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func _on_show_shot_timer():
	"""Show the shot timer overlay"""
	if DEBUG_LOGGING:
		print("=== DRILL_UI: Received ui_show_shot_timer signal ===")
		print("DEBUG: shot_timer_overlay node: ", shot_timer_overlay)
	shot_timer_overlay.visible = true
	
	# The shot_timer_overlay IS the shot timer, so call its methods directly
	if DEBUG_LOGGING:
		print("DEBUG: Calling start_timer_sequence() on shot_timer_overlay")
	shot_timer_overlay.start_timer_sequence()
	if DEBUG_LOGGING:
		print("[DrillUI] Started shot timer sequence")

	# Hide the completion overlay if visible
	drill_complete_overlay.visible = false

func _on_hide_shot_timer():
	"""Hide the shot timer overlay"""
	if DEBUG_LOGGING:
		print("=== HIDING SHOT TIMER OVERLAY ===")
	shot_timer_overlay.visible = false
	
	# The shot_timer_overlay IS the shot timer, so call its methods directly
	if shot_timer_overlay.has_method("reset_timer"):
		shot_timer_overlay.reset_timer()
		if DEBUG_LOGGING:
			print("[DrillUI] Reset shot timer")
	else:
		if DEBUG_LOGGING:
			print("[DrillUI] Warning: Shot timer overlay missing reset_timer method")

func setup_overlay_focus():
	"""Set up focus for the overlay buttons"""
	var restart_button = drill_complete_overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = drill_complete_overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if restart_button:
		restart_button.focus_mode = Control.FOCUS_ALL
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[drill_ui] Set up focus for restart button")
	
	if replay_button:
		replay_button.focus_mode = Control.FOCUS_ALL
		if DEBUG_LOGGING:
			print("[drill_ui] Set up focus for replay button")
