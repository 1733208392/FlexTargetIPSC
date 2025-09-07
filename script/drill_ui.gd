extends Control

# Theme styles for title
@export var golden_title_style: LabelSettings = preload("res://theme/target_title_settings.tres")
@export var tactical_title_style: LabelSettings = preload("res://theme/target_title_tactical.tres")
@export var competitive_title_style: LabelSettings = preload("res://theme/target_title_competitive.tres")
var current_theme_style: String = "golden"

# UI Node references
@onready var target_type_title = $TopContainer/TopLayout/HeaderContainer/TargetTypeTitle
@onready var fps_label = $FPSLabel
@onready var shot_timer_overlay = $ShotTimerOverlay
@onready var drill_complete_overlay = $DrillCompleteOverlay
@onready var fastest_interval_label = $TopContainer/TopLayout/HeaderContainer/FastestContainer/FastestInterval
@onready var timer_label = $TopContainer/TopLayout/TimerContainer/Timer
@onready var score_label = $TopContainer/TopLayout/HeaderContainer/ScoreContainer/Score

func _ready():
	"""Initialize the drill UI"""
	print("=== DRILL UI INITIALIZED ===")
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
		if drills_manager.has_signal("ui_show_shot_timer"):
			drills_manager.ui_show_shot_timer.connect(_on_show_shot_timer)
		if drills_manager.has_signal("ui_hide_shot_timer"):
			drills_manager.ui_hide_shot_timer.connect(_on_hide_shot_timer)
		if drills_manager.has_signal("ui_theme_change"):
			drills_manager.ui_theme_change.connect(_on_theme_change)
		if drills_manager.has_signal("ui_score_update"):
			drills_manager.ui_score_update.connect(_on_score_update)
		print("Connected to drills manager UI signals")

func _process(_delta):
	"""Update FPS counter every frame"""
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: " + str(fps)

func _on_timer_update(elapsed_seconds: float):
	"""Update the timer label with formatted elapsed time in MM:SS:MS format"""
	var total_seconds = int(elapsed_seconds)
	var milliseconds = int((elapsed_seconds - total_seconds) * 100)
	
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
	timer_label.text = time_string

func _on_target_title_update(target_index: int, total_targets: int):
	"""Update the target title based on the current target number"""
	var target_number = target_index + 1
	target_type_title.text = "Target " + str(target_number) + "/" + str(total_targets)
	print("Updated title to: Target ", target_number, "/", total_targets)

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
			print("Unknown theme: ", theme_name)
			return
	
	current_theme_style = theme_name
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

func _on_show_completion(final_time: float, fastest_time: float, final_score: int):
	"""Show the completion overlay with drill statistics"""
	print("Showing completion overlay")
	
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

func _on_show_shot_timer():
	"""Show the shot timer overlay"""
	print("=== SHOWING SHOT TIMER OVERLAY ===")
	shot_timer_overlay.visible = true
	shot_timer_overlay.reset_timer()
	
	# Hide the completion overlay if visible
	drill_complete_overlay.visible = false

func _on_hide_shot_timer():
	"""Hide the shot timer overlay"""
	print("=== HIDING SHOT TIMER OVERLAY ===")
	shot_timer_overlay.visible = false