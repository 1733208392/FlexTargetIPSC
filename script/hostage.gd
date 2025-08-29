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

# Zone priority order (higher index = higher priority)
var zone_priorities = ["DZone", "CZone", "AZone", "WhiteZone"]

# Collision tracking
var has_collided: bool = false

func _ready():
	# Set up collision detection for bullets
	collision_layer = 7  # Target layer
	collision_mask = 0   # Don't detect other targets

func _input(event):
	# Don't process input events if target is disappearing
	if is_disappearing:
		print("Hostage target is disappearing - ignoring input event")
		return
		
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_screen_pos = event.position
		var world_pos = get_global_mouse_position()
		print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", world_pos)
		spawn_bullet_at_position(world_pos)

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
	"""Handle collision detection when a bullet hits this target with zone priority"""
	# Don't process bullet collisions if target is disappearing
	if is_disappearing:
		print("Hostage target is disappearing - ignoring bullet collision")
		return "ignored"
		
	print("Bullet collision detected at position: ", bullet_position)
	
	# Convert bullet world position to local coordinates for zone checking
	var local_pos = to_local(bullet_position)
	
	var zone_hit = ""
	var highest_priority = -1
	
	# Check all zones and find the highest priority zone that contains the point
	for zone_name in zone_priorities:
		if is_point_in_zone(zone_name, local_pos):
			var zone_priority = zone_priorities.find(zone_name)
			if zone_priority > highest_priority:
				highest_priority = zone_priority
				zone_hit = zone_name
	
	# Process the hit
	if zone_hit != "":
		print("COLLISION: Hostage target hit in zone: ", zone_hit)
		# Spawn bullet hole at impact position
		spawn_bullet_hole(local_pos)
		
		# Increment shot count and check for disappearing animation
		shot_count += 1
		print("Shot count: ", shot_count, "/", max_shots)
		
		# Check if we've reached the maximum shots
		if shot_count >= max_shots:
			print("Maximum shots reached! Triggering disappearing animation...")
			play_disappearing_animation()
		
		return zone_hit
	else:
		print("COLLISION: Bullet hit target but outside all zones")
		return "miss"

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node_or_null(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Adjust point for zone position offset
		var adjusted_point = point - zone_node.position
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(adjusted_point, zone_node.polygon)
	return false

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position on this target"""
	if BulletHoleScene:
		var bullet_hole = BulletHoleScene.instantiate()
		add_child(bullet_hole)
		bullet_hole.set_hole_position(local_position)
		print("Bullet hole spawned on hostage target at local position: ", local_position)
	else:
		print("ERROR: BulletHoleScene not found!")

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	print("Starting disappearing animation for hostage target")
	is_disappearing = true
	
	# Get the AnimationPlayer
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		# Connect to the animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		
		# Play the disappear animation
		animation_player.play("disappear")
		print("Disappear animation started on hostage target")
	else:
		print("ERROR: AnimationPlayer not found on hostage target")

func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		print("Disappear animation completed on hostage target")
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""
	print("Hostage target disappearing animation finished")
	
	# Disable collision detection completely
	set_collision_layer(0)
	set_collision_mask(0)
	
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
	
	print("Hostage target reset to original state")
