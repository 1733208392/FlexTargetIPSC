extends Control

# Preload the scenes for the drill sequence
@export var ipsc_mini_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")
@export var hostage_scene: PackedScene = preload("res://scene/hostage.tscn")
@export var popper_scene: PackedScene = preload("res://scene/popper.tscn")
@export var paddle_scene: PackedScene = preload("res://scene/paddle.tscn")
@export var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")

# Theme styles for title
@export var golden_title_style: LabelSettings = preload("res://theme/target_title_settings.tres")
@export var tactical_title_style: LabelSettings = preload("res://theme/target_title_tactical.tres")
@export var competitive_title_style: LabelSettings = preload("res://theme/target_title_competitive.tres")
var current_theme_style: String = "golden"

# Drill sequence and progress tracking
var target_sequence: Array[String] = ["ipsc_mini","hostage", "popper", "paddle", "ipsc_mini_rotate"]
var current_target_index: int = 0
var current_target_instance: Node = null
var total_drill_score: int = 0
var drill_completed: bool = false

# Node references
@onready var center_container = $CenterContainer
@onready var target_type_title = $TopContainer/TopLayout/HeaderContainer/TargetTypeTitle
@onready var fps_label = $FPSLabel

func _ready():
	"""Initialize the drill with the first target"""
	print("=== STARTING DRILL ===")
	apply_title_theme("golden")  # Set default theme
	
	# Clear any existing targets in the center container
	clear_current_target()
	
	# Start the drill sequence
	spawn_next_target()

func _process(_delta):
	"""Update FPS counter every frame"""
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: " + str(fps)

func _input(_event):
	"""Handle input events for theme switching (testing purposes)"""
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
		"popper":
			spawn_popper()
		"paddle":
			spawn_paddle()
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

func spawn_popper():
	"""Spawn a popper target"""
	var target = popper_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	print("Popper target spawned")

func spawn_paddle():
	"""Spawn a paddle target"""
	var target = paddle_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	print("Paddle target spawned")

func spawn_ipsc_mini_rotate():
	"""Spawn an IPSC mini rotating target"""
	var target = ipsc_mini_rotate_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	
	# Wait for the node to be fully added to the scene
	await get_tree().process_frame
	
	# Position the rotation center appropriately
	var screen_height = get_viewport().get_visible_rect().size.y
	var bottom_offset = screen_height * 0.3
	target.position.y = bottom_offset
	
	print("IPSC Mini Rotate target spawned and positioned")

func connect_target_signals():
	"""Connect to the current target's signals"""
	if not current_target_instance:
		print("WARNING: No current target instance to connect signals")
		return
	
	var current_target_type = target_sequence[current_target_index]
	
	# Handle composite targets that contain child targets
	match current_target_type:
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

func _on_target_disappeared():
	"""Handle when a target has completed its disappear animation"""
	var current_target_type = target_sequence[current_target_index]
	print("=== TARGET DISAPPEARED ===")
	print("Target type: ", current_target_type)
	print("Target index: ", current_target_index)
	print("Moving to next target...")
	
	current_target_index += 1
	spawn_next_target()

func connect_ipsc_mini_rotate_signals():
	"""Connect signals for ipsc_mini_rotate target (has child ipsc_mini)"""
	var ipsc_mini = current_target_instance.get_node("IPSCMini")
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

func _on_target_hit(zone: String, points: int):
	"""Handle when a target is hit"""
	var current_target_type = target_sequence[current_target_index]
	print("Target hit: ", current_target_type, " in zone: ", zone, " for ", points, " points")
	
	total_drill_score += points
	print("Total drill score: ", total_drill_score)
	
	# The target will handle its own disappearing logic and emit target_disappeared when ready

func complete_drill():
	"""Complete the drill sequence"""
	print("=== DRILL COMPLETED! ===")
	print("Final score: ", total_drill_score)
	print("Targets completed: ", current_target_index, "/", target_sequence.size())
	drill_completed = true
	
	# You can add additional completion logic here
	# For example: show results screen, save score, transition to next drill, etc.

func restart_drill():
	"""Restart the drill from the beginning"""
	print("=== RESTARTING DRILL ===")
	
	# Reset all tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	
	# Clear the current target
	clear_current_target()
	
	# Start the drill again
	spawn_next_target()
	
	print("Drill restarted!")
