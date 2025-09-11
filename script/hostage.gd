extends Area2D

var last_click_frame = -1

# Animation state tracking
var is_disappearing: bool = false

# Shot tracking for disappearing animation
var shot_count: int = 0
var max_shots: int = 2

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")

# Scoring system
var total_score: int = 0
signal target_hit(zone: String, points: int, hit_position: Vector2)
signal target_disappeared

# Reference to drills manager
var drills_manager = null

func _ready():
	# Try to find the drills manager
	drills_manager = get_node("/root/drills") if get_node_or_null("/root/drills") else null
	if not drills_manager:
		# Try to find it in the scene tree
		var current = get_parent()
		while current and not drills_manager:
			if current.has_method("is_bullet_spawning_allowed"):
				drills_manager = current
				break
			current = current.get_parent()
	
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)
	
		# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[hostage] Connected to WebSocketListener bullet_hit signal")
	else:
		print("[hostage] WebSocketListener singleton not found!")
	
	# Set up collision detection for bullets
	collision_layer = 7  # Target layer
	collision_mask = 0   # Don't detect other targets

func _input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if bullet spawning is enabled
		var ws_listener = get_node_or_null("/root/WebSocketListener")
		if ws_listener and not ws_listener.bullet_spawning_enabled:
			print("[hostage] Bullet spawning disabled during shot timer")
			return
			
		var mouse_screen_pos = event.position
		var world_pos = get_global_mouse_position()
		print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", world_pos)
		spawn_bullet_at_position(world_pos)

func _on_input_event(_viewport, event, _shape_idx):
	# Don't process input events if target is disappearing
	if is_disappearing:
		print("Target is disappearing - ignoring input event")
		return
		
	# Check if it's a left mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Get the click position in local coordinates
		var local_pos = to_local(event.global_position)
		
		# Check zones in priority order (highest score first)
		if is_point_in_zone("WhiteZone", local_pos):
			print("WhiteZone clicked - -5 points!")
			return

		# A-Zone has highest priority (5 points)
		if is_point_in_zone("AZone", local_pos):
			print("Zone A clicked - 5 points!")
			return
		
		# C-Zone has medium priority (3 points)
		if is_point_in_zone("CZone", local_pos):
			print("Zone C clicked - 3 points!")
			return
		
		# D-Zone has lowest priority (1 point)
		if is_point_in_zone("DZone", local_pos):
			print("Zone D clicked - 1 point!")
			return
		
		print("Clicked outside target zones")

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Adjust the point by the zone's position offset
		var adjusted_point = point - zone_node.position
		# Check if the adjusted point is inside the polygon
		return Geometry2D.is_point_in_polygon(adjusted_point, zone_node.polygon)
	return false

func spawn_bullet_at_position(world_pos: Vector2):
	print("Spawning bullet at world position: ", world_pos)
	
	if BulletScene:
		var bullet = BulletScene.instantiate()
		
		# Find the top-level scene node to add bullet effects
		# This ensures effects don't get rotated with rotating targets
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
		else:
			# Fallback to immediate parent if scene_root not found
			get_parent().add_child(bullet)
		
		# Use the new set_spawn_position method to ensure proper positioning
		bullet.set_spawn_position(world_pos)
		
		print("Bullet spawned and position set to: ", world_pos)

func handle_bullet_collision(bullet_position: Vector2):
	"""Handle collision detection when a bullet hits this target"""
	# Don't process bullet collisions if target is disappearing
	if is_disappearing:
		print("Target is disappearing - ignoring bullet collision")
		return "ignored"
	
	print("Bullet collision detected at position: ", bullet_position)
	
	# Convert bullet world position to local coordinates for zone checking
	var local_pos = to_local(bullet_position)
	
	var zone_hit = ""
	var points = 0
	
	# Check which zone was hit (highest score first)
	if is_point_in_zone("WhiteZone", local_pos):
		zone_hit = "WhiteZone"
		points = -5
		print("COLLISION: WhiteZone hit by bullet - -5 points!")
	elif is_point_in_zone("AZone", local_pos):
		zone_hit = "AZone"
		points = 5
		print("COLLISION: Zone A hit by bullet - 5 points!")
	elif is_point_in_zone("CZone", local_pos):
		zone_hit = "CZone"
		points = 3
		print("COLLISION: Zone C hit by bullet - 3 points!")
	elif is_point_in_zone("DZone", local_pos):
		zone_hit = "DZone"
		points = 1
		print("COLLISION: Zone D hit by bullet - 1 point!")
	else:
		zone_hit = "miss"
		points = 0
		print("COLLISION: Bullet hit target but outside scoring zones")
	
	# Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, bullet_position)
	print("Total score: ", total_score)
	
	# Note: Bullet hole is now spawned by bullet script before this method is called
	
	# Increment shot count and check for disappearing animation
	shot_count += 1
	print("Shot count: ", shot_count, "/", max_shots)
	
	# Check if we've reached the maximum shots
	if shot_count >= max_shots:
		print("Maximum shots reached! Triggering disappearing animation...")
		play_disappearing_animation()
	
	return zone_hit

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position on this target"""
	if BulletHoleScene:
		var bullet_hole = BulletHoleScene.instantiate()
		add_child(bullet_hole)
		bullet_hole.set_hole_position(local_position)
		print("Bullet hole spawned on target at local position: ", local_position)
	else:
		print("ERROR: BulletHoleScene not found!")

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0
	print("Score reset to 0")

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	print("Starting disappearing animation for ipsc_mini")
	is_disappearing = true
	
	# Get the AnimationPlayer
	var animation_player = get_node("AnimationPlayer")
	if animation_player:
		# Connect to the animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		
		# Play the disappear animation
		animation_player.play("disappear")
		print("Disappear animation started")
	else:
		print("ERROR: AnimationPlayer not found")

func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		print("Disappear animation completed")
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""
	print("Target disappearing animation finished")
	
	# Disable collision detection completely
	set_collision_layer(0)
	set_collision_mask(0)
	
	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()
	print("target_disappeared signal emitted")
	
	# Keep the disappearing state active to prevent any further interactions
	# is_disappearing remains true

func reset_target():
	"""Reset the target to its original state (useful for restarting)"""
	# Reset animation state
	is_disappearing = false
	
	# Reset shot count
	shot_count = 0
	
	# Reset visual properties
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
	
	# Re-enable collision detection
	collision_layer = 7
	collision_mask = 0
	
	# Reset score
	reset_score()
	
	print("Target reset to original state")

func _on_websocket_bullet_hit(pos: Vector2):
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		print("[hostage] WebSocket bullet spawning disabled during shot timer")
		return
		
	print("[BlockSpawner] Received bullet hit at position: ", pos)
	spawn_bullet_at_position(pos)
