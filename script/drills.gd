extends Control

# Preload the scenes
@export var hostage_scene: PackedScene = preload("res://scene/hostage.tscn")
@export var popper_scene: PackedScene = preload("res://scene/popper.tscn")
@export var paddle_scene: PackedScene = preload("res://scene/paddle.tscn")
@export var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")

# Theme styles for title
@export var golden_title_style: LabelSettings = preload("res://theme/target_title_settings.tres")
@export var tactical_title_style: LabelSettings = preload("res://theme/target_title_tactical.tres")
@export var competitive_title_style: LabelSettings = preload("res://theme/target_title_competitive.tres")
var current_theme_style: String = "golden"  # default theme

# Variables to track shots
var shot_count: int = 0
var max_shots: int = 2
var current_target_type: String = "target"  # "target", "hostage", "popper", "paddle", "ipsc_mini_rotate"
var current_target_instance: Node = null

# Drill progress tracking
var total_drill_score: int = 0
var targets_completed: int = 0
var total_targets: int = 5  # target, hostage, popper, paddle, ipsc_mini_rotate

# Node references
@onready var center_container = $CenterContainer
@onready var target_mini = $CenterContainer/TargetMini
@onready var target_type_title = $TopContainer/TopLayout/HeaderContainer/TargetTypeTitle

func update_target_title():
	"""Update the target title based on the current target number"""
	var target_number = targets_completed + 1
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

func _ready():
	# Simple initialization
	current_target_instance = target_mini
	# Connect to the initial target's collision signal
	connect_target_signals()
	# Update the title for the first target
	update_target_title()

func _input(_event):
	# Mouse clicks are now handled by individual targets through collision detection
	# This function can be used for other input handling if needed
	
	# Theme switching for testing (remove in production)
	if _event is InputEventKey and _event.pressed:
		match _event.keycode:
			KEY_1:
				apply_title_theme("golden")
			KEY_2:
				apply_title_theme("tactical")
			KEY_3:
				apply_title_theme("competitive")

func connect_target_signals():
	# Connect to the current target's collision signal
	# Handle composite targets (hostage, ipsc_mini_rotate) that contain child targets
	
	# For hostage target, connect to both child targets
	if current_target_type == "hostage":
		var ipsc_mini = current_target_instance.get_node("IPSCMini")
		var ipsc_white = current_target_instance.get_node("IPSCWhite")
		
		if ipsc_mini and ipsc_mini.has_signal("target_hit"):
			if ipsc_mini.target_hit.is_connected(_on_target_hit):
				ipsc_mini.target_hit.disconnect(_on_target_hit)
			ipsc_mini.target_hit.connect(_on_target_hit)
			print("Connected to hostage ipsc_mini collision signals")
		
		if ipsc_white and ipsc_white.has_signal("target_hit"):
			if ipsc_white.target_hit.is_connected(_on_target_hit):
				ipsc_white.target_hit.disconnect(_on_target_hit)
			ipsc_white.target_hit.connect(_on_target_hit)
			print("Connected to hostage ipsc_white collision signals")
		return
	
	# For ipsc_mini_rotate target, connect to child ipsc_mini
	if current_target_type == "ipsc_mini_rotate":
		var ipsc_mini = current_target_instance.get_node("IPSCMini")
		if ipsc_mini and ipsc_mini.has_signal("target_hit"):
			if ipsc_mini.target_hit.is_connected(_on_target_hit):
				ipsc_mini.target_hit.disconnect(_on_target_hit)
			ipsc_mini.target_hit.connect(_on_target_hit)
			print("Connected to ipsc_mini_rotate collision signals")
		return
	
	# For simple targets, connect directly
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		# Disconnect any previous connections
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		# Connect to the new target
		current_target_instance.target_hit.connect(_on_target_hit)
		print("Connected to target collision signals: ", current_target_type)
	else:
		print("Warning: Current target doesn't have target_hit signal")

func _on_target_hit(zone: String, points: int):
	# Handle bullet collision with current target
	print("Bullet collision detected on ", current_target_type, " in zone: ", zone, " for ", points, " points")
	total_drill_score += points
	print("Total drill score: ", total_drill_score)
	
	# Special handling for paddle and popper - they fall and immediately move to next target
	if current_target_type == "paddle" or current_target_type == "popper":
		print("Paddle/Popper hit! Moving to next target immediately...")
		targets_completed += 1
		print("Target completed! (", targets_completed, "/", total_targets, ")")
		
		# Progress to next target immediately
		if current_target_type == "paddle":
			replace_paddle_with_ipsc_mini_rotate()
		elif current_target_type == "popper":
			replace_popper_with_paddle()
		
		# Reset shot count for next target
		shot_count = 0
		# Update the target title
		update_target_title()
		return
	
	# For other targets, use normal shot counting logic
	handle_shot()

func check_target_hit(_mouse_pos: Vector2):
	# This function is no longer used - collision detection handles target hits
	# Keeping for backward compatibility
	pass

func handle_shot():
	shot_count += 1
	print("Shot fired! Count: ", shot_count, " on ", current_target_type)
	
	# Check if we've reached the maximum shots
	if shot_count >= max_shots:
		targets_completed += 1
		print("Target completed! (", targets_completed, "/", total_targets, ")")
		
		if current_target_type == "target":
			replace_target_with_hostage()
		elif current_target_type == "hostage":
			replace_hostage_with_popper()
		elif current_target_type == "popper":
			replace_popper_with_paddle()
		elif current_target_type == "paddle":
			replace_paddle_with_ipsc_mini_rotate()
		elif current_target_type == "ipsc_mini_rotate":
			complete_drill()
			return
		
		# Reset shot count for next target
		shot_count = 0
		# Update the target title
		update_target_title()

func complete_drill():
	print("=== DRILL COMPLETED! ===")
	print("Final score: ", total_drill_score)
	print("Targets completed: ", targets_completed, "/", total_targets)
	# You can add additional drill completion logic here
	# For example: show results screen, save score, etc.

func restart_drill():
	"""Restart the drill from the beginning"""
	print("=== RESTARTING DRILL ===")
	
	# Reset counters
	shot_count = 0
	total_drill_score = 0
	targets_completed = 0
	
	# Remove all children from center container
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	
	# Recreate the initial target
	var new_target_mini = preload("res://scene/ipsc_mini.tscn").instantiate()
	new_target_mini.name = "TargetMini"
	center_container.add_child(new_target_mini)
	
	# Update references
	target_mini = new_target_mini
	current_target_instance = target_mini
	current_target_type = "target"
	
	# Connect signals
	connect_target_signals()
	
	# Reset the title to Target 1
	update_target_title()
	
	print("Drill restarted!")

func replace_target_with_hostage():
	print("=== REPLACING TARGET WITH HOSTAGE ===")
	if target_mini and is_instance_valid(target_mini):
		# Remove the current target
		target_mini.queue_free()
		
		# Create and add the hostage scene
		var hostage_instance = hostage_scene.instantiate()
		center_container.add_child(hostage_instance)
		
		# Update references
		current_target_instance = hostage_instance
		current_target_type = "hostage"
		
		# Connect to new target's collision signals
		connect_target_signals()
		
		print("Target replaced with hostage!")
	else:
		print("ERROR: Could not replace target - target_mini not valid")

func replace_hostage_with_popper():
	print("=== REPLACING HOSTAGE WITH POPPER ===")
	# Remove all children from center container (this will remove the hostage)
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	
	# Create and add the popper scene
	var popper_instance = popper_scene.instantiate()
	center_container.add_child(popper_instance)
	
	# Update references
	current_target_instance = popper_instance
	current_target_type = "popper"
	
	# Connect to new target's collision signals
	connect_target_signals()
	
	print("Hostage replaced with popper!")

func replace_popper_with_paddle():
	print("=== REPLACING POPPER WITH PADDLE ===")
	# Remove all children from center container (this will remove the popper)
	for child in center_container.get_children():
		print("Removing child: ", child.name)
		center_container.remove_child(child)
		child.queue_free()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Create and add the paddle scene
	var paddle_instance = paddle_scene.instantiate()
	center_container.add_child(paddle_instance)
	
	# Update references
	current_target_instance = paddle_instance
	current_target_type = "paddle"
	
	print("Paddle instance created: ", paddle_instance)
	print("Paddle has collision detection: ", paddle_instance.has_method("handle_bullet_collision"))
	print("Paddle has target_hit signal: ", paddle_instance.has_signal("target_hit"))
	
	# Connect to new target's collision signals
	connect_target_signals()
	
	print("Popper replaced with paddle!")

func replace_paddle_with_ipsc_mini_rotate():
	print("=== REPLACING PADDLE WITH IPSC_MINI_ROTATE ===")
	# Remove all children from center container (this will remove the paddle)
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	
	# Create and add the ipsc_mini_rotate scene
	var ipsc_mini_rotate_instance = ipsc_mini_rotate_scene.instantiate()
	center_container.add_child(ipsc_mini_rotate_instance)
	
	# Position the rotation center at the bottom of the center_container
	# The center_container has no fixed size, so we'll use screen dimensions as reference
	# Get the center_container's rect and position the rotation center at its bottom
	await get_tree().process_frame  # Wait for the node to be fully added
	
	var screen_height = get_viewport().get_visible_rect().size.y
	
	# Position the ipsc_mini_rotate so its rotation center is at the bottom of the center area
	# Since the IPSCMini is positioned at (0, -540) relative to RotationCenter,
	# we need to offset the entire instance upward to bring the rotation center to the bottom
	var bottom_offset = screen_height * 0.3  # Position rotation center at 30% from bottom of screen
	ipsc_mini_rotate_instance.position.y = bottom_offset
	
	print("Rotation center positioned at bottom of center container (offset: ", bottom_offset, ")")
	
	# Update references
	current_target_instance = ipsc_mini_rotate_instance
	current_target_type = "ipsc_mini_rotate"
	
	# Connect to new target's collision signals
	connect_target_signals()
	
	print("Paddle replaced with ipsc_mini_rotate!")
