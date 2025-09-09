extends Control

# Bullet system
@export var bullet_scene: PackedScene = preload("res://scene/bullet.tscn")

# Collision areas for bullet interactions
@onready var area_restart = $VBoxContainer/RestartButton/AreaRestart
@onready var area_replay = $VBoxContainer/ReviewReplayButton/AreaReplay

func _ready():
	"""Initialize the drill complete overlay"""
	print("=== DRILL COMPLETE OVERLAY INITIALIZED ===")
	
	# Connect to WebSocket for bullet spawning
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[drill_complete_overlay] Connected to WebSocketListener bullet_hit signal")
	else:
		print("[drill_complete_overlay] WebSocketListener singleton not found!")
	
	# Set up for mouse input processing - Control nodes need special setup
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Make sure we can receive input when visible
	set_process_input(true)
	set_process_unhandled_input(true)
	# Ensure we can intercept input events with high priority
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect collision area signals for bullet interactions
	setup_collision_areas()

func _notification(what):
	"""Debug overlay visibility changes"""
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		print("[drill_complete_overlay] Visibility changed to: ", visible)
		print("[drill_complete_overlay] Size: ", size)
		print("[drill_complete_overlay] Position: ", position)
		if visible:
			print("[drill_complete_overlay] Overlay is now visible and ready for input")

func setup_collision_areas():
	"""Setup collision detection for the restart and replay areas"""
	if area_restart:
		# Set collision properties for bullets
		area_restart.collision_layer = 7  # Target layer
		area_restart.collision_mask = 8   # Bullet layer
		area_restart.area_entered.connect(_on_area_restart_hit)
		print("[drill_complete_overlay] AreaRestart collision setup complete")
	else:
		print("[drill_complete_overlay] AreaRestart not found!")
	
	if area_replay:
		# Set collision properties for bullets
		area_replay.collision_layer = 7  # Target layer
		area_replay.collision_mask = 8   # Bullet layer
		area_replay.area_entered.connect(_on_area_replay_hit)
		print("[drill_complete_overlay] AreaReplay collision setup complete")
	else:
		print("[drill_complete_overlay] AreaReplay not found!")

func _input(event):
	"""Handle mouse clicks for bullet spawning"""
	# Only process input when this overlay is visible
	if not visible:
		return
	
	# Debug: Log any input event
	print("[drill_complete_overlay] _input received event: ", event)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[drill_complete_overlay] Mouse click detected via _input")
		_handle_mouse_click(event)
		# Mark the event as handled to prevent parent nodes from processing it
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event):
	"""Handle mouse clicks for bullet spawning - backup method for Control nodes"""
	# Only process input when this overlay is visible
	if not visible:
		return
	
	# Debug: Log any unhandled input event
	print("[drill_complete_overlay] _unhandled_input received event: ", event)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[drill_complete_overlay] Mouse click detected via _unhandled_input")
		_handle_mouse_click(event)
		# Accept the event to prevent further processing
		get_viewport().set_input_as_handled()

func _handle_mouse_click(event):
	"""Process the mouse click for bullet spawning"""
	print("[drill_complete_overlay] Processing mouse click")
	
	# Check if bullet spawning is enabled through WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		print("[drill_complete_overlay] WebSocketListener found, bullet_spawning_enabled: ", ws_listener.bullet_spawning_enabled)
		if not ws_listener.bullet_spawning_enabled:
			print("[drill_complete_overlay] Bullet spawning disabled")
			return
	else:
		print("[drill_complete_overlay] WebSocketListener not found!")
		return
		
	var world_pos = get_global_mouse_position()
	print("[drill_complete_overlay] Spawning bullet at: ", world_pos)
	spawn_bullet_at_position(world_pos)

func _on_websocket_bullet_hit(position: Vector2):
	"""Handle bullet hit from WebSocket data"""
	# Only process websocket bullets when this overlay is visible
	if not visible:
		return
		
	print("[drill_complete_overlay] WebSocket bullet hit at: ", position)
	spawn_bullet_at_position(position)

func spawn_bullet_at_position(world_pos: Vector2):
	"""Spawn a bullet at the specified world position"""
	print("[drill_complete_overlay] Spawning bullet at world position: ", world_pos)
	
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		
		# Add the bullet to the scene
		add_child(bullet)
		
		# Set the bullet's spawn position
		if bullet.has_method("set_spawn_position"):
			bullet.set_spawn_position(world_pos)
		else:
			bullet.global_position = world_pos
		
		print("[drill_complete_overlay] Bullet spawned successfully")
	else:
		print("[drill_complete_overlay] ERROR: No bullet scene loaded!")

func _on_area_restart_hit(area: Area2D):
	"""Handle bullet collision with restart area"""
	print("[drill_complete_overlay] Bullet hit AreaRestart - restarting drill")
	
	# Hide the completion overlay
	visible = false
	
	# Find the drill manager and restart the drill
	var drill_ui = get_parent()
	if drill_ui:
		var drills_manager = drill_ui.get_parent()
		if drills_manager and drills_manager.has_method("restart_drill"):
			drills_manager.restart_drill()
			print("[drill_complete_overlay] Drill restarted successfully")
		else:
			print("[drill_complete_overlay] Warning: Could not find drills manager or restart_drill method")
	else:
		print("[drill_complete_overlay] Warning: Could not find drill UI parent")

func _on_area_replay_hit(area: Area2D):
	"""Handle bullet collision with replay area"""
	print("[drill_complete_overlay] Bullet hit AreaReplay - navigating to drill replay")
	
	# Navigate to the drill replay scene
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")