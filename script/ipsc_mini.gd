extends Area2D

var last_click_frame = -1

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")

# Scoring system
var total_score: int = 0
signal target_hit(zone: String, points: int)

func _ready():
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)
	
	# Set up collision detection for bullets
	collision_layer = 7  # Target layer
	collision_mask = 0   # Don't detect other targets

func _input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_screen_pos = event.position
		var world_pos = get_global_mouse_position()
		print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", world_pos)
		spawn_bullet_at_position(world_pos)

func _on_input_event(_viewport, event, _shape_idx):
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
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
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
	print("Bullet collision detected at position: ", bullet_position)
	
	# Convert bullet world position to local coordinates for zone checking
	var local_pos = to_local(bullet_position)
	
	var zone_hit = ""
	var points = 0
	
	# Check which zone was hit (highest score first)
	if is_point_in_zone("AZone", local_pos):
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
	target_hit.emit(zone_hit, points)
	print("Total score: ", total_score)
	
	return zone_hit

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0
	print("Score reset to 0")
