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

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 8  # Keep 8 bullet holes pre-instantiated
var active_bullet_holes: Array[Node] = []

# Effect throttling for performance optimization
var last_sound_time: float = 0.0
var last_smoke_time: float = 0.0
var last_impact_time: float = 0.0
var sound_cooldown: float = 0.05  # 50ms minimum between sounds
var smoke_cooldown: float = 0.08  # 80ms minimum between smoke effects
var impact_cooldown: float = 0.06  # 60ms minimum between impact effects
var max_concurrent_sounds: int = 3  # Maximum number of concurrent sound effects
var active_sounds: int = 0

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

# Scoring system
var total_score: int = 0
signal target_hit(zone: String, points: int, hit_position: Vector2)
signal target_disappeared

func _ready():
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)
	
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[ipsc_mini] Connected to WebSocketListener bullet_hit signal")
	else:
		print("[ipsc_mini] WebSocketListener singleton not found!")
	
	# Set up collision detection for bullets
	# NOTE: Collision detection is now obsolete due to WebSocket fast path
	# collision_layer = 7  # Target layer
	# collision_mask = 0   # Don't detect other targets

func _unhandled_input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
	# NOTE: This collision handling is now obsolete due to WebSocket fast path
	# WebSocket hits use handle_websocket_bullet_hit_fast() instead
	
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
	# NOTE: Collision detection was already obsolete due to WebSocket fast path
	# set_collision_layer(0)
	# set_collision_mask(0)
	
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
	# NOTE: Collision detection disabled as it's obsolete due to WebSocket fast path
	# collision_layer = 7
	# collision_mask = 0
	
	# Reset score
	reset_score()
	
	# Reset bullet hole pool - hide all active holes
	reset_bullet_hole_pool()
	
	print("Target reset to original state")

func reset_bullet_hole_pool():
	"""Reset the bullet hole pool by hiding all active holes"""
	print("[ipsc_mini] Resetting bullet hole pool")
	
	# Hide all active bullet holes
	for hole in active_bullet_holes:
		if is_instance_valid(hole):
			hole.visible = false
	
	# Clear active list
	active_bullet_holes.clear()
	
	print("[ipsc_mini] Bullet hole pool reset - all holes returned to pool")

func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""
	print("[ipsc_mini] Initializing bullet hole pool with size: ", pool_size)
	
	if not BulletHoleScene:
		print("[ipsc_mini] ERROR: BulletHoleScene not found for pool initialization!")
		return
	
	# Clear existing pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole):
			hole.queue_free()
	bullet_hole_pool.clear()
	active_bullet_holes.clear()
	
	# Pre-instantiate bullet holes
	for i in range(pool_size):
		var bullet_hole = BulletHoleScene.instantiate()
		add_child(bullet_hole)
		bullet_hole.visible = false  # Hide until needed
		# Set z-index to ensure bullet holes appear below effects
		bullet_hole.z_index = 0
		bullet_hole_pool.append(bullet_hole)
		print("[ipsc_mini] Pre-instantiated bullet hole ", i + 1, "/", pool_size, " with z_index: 0")
	
	print("[ipsc_mini] Bullet hole pool initialized successfully with ", bullet_hole_pool.size(), " holes")

func get_pooled_bullet_hole() -> Node:
	"""Get an available bullet hole from the pool, or create new if needed"""
	# Try to find an inactive bullet hole in the pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole) and not hole.visible:
			print("[ipsc_mini] Reusing pooled bullet hole")
			return hole
	
	# If no available holes in pool, create a new one (fallback)
	print("[ipsc_mini] Pool exhausted, creating new bullet hole")
	if BulletHoleScene:
		var new_hole = BulletHoleScene.instantiate()
		add_child(new_hole)
		bullet_hole_pool.append(new_hole)  # Add to pool for future use
		return new_hole
	
	print("[ipsc_mini] ERROR: Cannot create new bullet hole - BulletHoleScene missing!")
	return null

func return_bullet_hole_to_pool(hole: Node):
	"""Return a bullet hole to the pool by hiding it"""
	if is_instance_valid(hole):
		hole.visible = false
		# Remove from active list
		if hole in active_bullet_holes:
			active_bullet_holes.erase(hole)
		print("[ipsc_mini] Bullet hole returned to pool, active holes: ", active_bullet_holes.size())

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""
	print("[ipsc_mini] POOL: Spawning bullet hole at local position: ", local_position)
	
	var bullet_hole = get_pooled_bullet_hole()
	if bullet_hole:
		# Configure the bullet hole
		bullet_hole.set_hole_position(local_position)
		bullet_hole.visible = true
		# Ensure bullet holes appear below smoke/debris effects
		bullet_hole.z_index = 0
		
		# Track as active
		if bullet_hole not in active_bullet_holes:
			active_bullet_holes.append(bullet_hole)
		
		print("[ipsc_mini] POOL: Bullet hole activated at position: ", local_position, " (Active: ", active_bullet_holes.size(), ") with z_index: 0")
	else:
		print("[ipsc_mini] POOL ERROR: Failed to get bullet hole from pool!")

func _on_websocket_bullet_hit(pos: Vector2):
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		print("[ipsc_mini] WebSocket bullet spawning disabled during shot timer")
		return
	
	print("[ipsc_mini] Received bullet hit at position: ", pos)
	
	# FAST PATH: Direct bullet hole spawning for WebSocket hits
	handle_websocket_bullet_hit_fast(pos)

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""
	if DEBUG_LOGGING:
		print("[ipsc_mini] FAST PATH: Processing WebSocket bullet hit at: ", world_pos)
	
	# Don't process if target is disappearing
	if is_disappearing:
		if DEBUG_LOGGING:
			print("[ipsc_mini] Target is disappearing - ignoring WebSocket hit")
		return
	
	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)
	if DEBUG_LOGGING:
		print("[ipsc_mini] World pos: ", world_pos, " -> Local pos: ", local_pos)
	
	# 1. FIRST: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false
	
	# Check which zone was hit (highest score first)
	if is_point_in_zone("AZone", local_pos):
		zone_hit = "AZone"
		points = 5
		is_target_hit = true
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Zone A hit - 5 points!")
	elif is_point_in_zone("CZone", local_pos):
		zone_hit = "CZone"
		points = 3
		is_target_hit = true
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Zone C hit - 3 points!")
	elif is_point_in_zone("DZone", local_pos):
		zone_hit = "DZone"
		points = 1
		is_target_hit = true
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Zone D hit - 1 point!")
	else:
		zone_hit = "miss"
		points = 0
		is_target_hit = false
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Bullet missed target - no bullet hole")
	
	# 2. CONDITIONAL: Only spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Bullet hole spawned for target hit")
	else:
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: No bullet hole - bullet missed target")
	
	# 3. ALWAYS: Spawn bullet effects (impact/sound) but skip smoke for misses
	spawn_bullet_effects_at_position(world_pos, is_target_hit)
	
	# 4. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos)
	if DEBUG_LOGGING:
		print("[ipsc_mini] FAST: Total score: ", total_score)
	
	# 5. Increment shot count and check for disappearing animation (only for hits)
	if is_target_hit:
		shot_count += 1
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Shot count: ", shot_count, "/", max_shots)
		
		# Check if we've reached the maximum shots
		if shot_count >= max_shots:
			if DEBUG_LOGGING:
				print("[ipsc_mini] FAST: Maximum shots reached! Triggering disappearing animation...")
			play_disappearing_animation()
	else:
		if DEBUG_LOGGING:
			print("[ipsc_mini] FAST: Miss - shot count not incremented")

func spawn_bullet_effects_at_position(world_pos: Vector2, is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""
	if DEBUG_LOGGING:
		print("[ipsc_mini] Spawning bullet effects at: ", world_pos, " (Target hit: ", is_target_hit, ")")
	
	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Load the effect scenes directly
	var bullet_smoke_scene = preload("res://scene/bullet_smoke.tscn")
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")
	
	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()
	
	# Throttled smoke effect - DISABLED for performance optimization
	# Smoke is the most expensive effect (GPUParticles2D) and not essential for gameplay
	if false:  # Completely disabled
		pass
	else:
		if DEBUG_LOGGING:
			print("[ipsc_mini] Smoke effect disabled for performance optimization")
	
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above bullet holes
		impact.z_index = 15
		last_impact_time = time_stamp
		if DEBUG_LOGGING:
			print("[ipsc_mini] Impact effect spawned at: ", world_pos, " with z_index: 15")
	elif (time_stamp - last_impact_time) < impact_cooldown:
		if DEBUG_LOGGING:
			print("[ipsc_mini] Impact effect throttled (too fast)")
	
	# Throttled sound effect - ALWAYS play (for both hits and misses)
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		if DEBUG_LOGGING:
			print("[ipsc_mini] Sound effect throttled (too fast - ", current_time - last_sound_time, "s since last)")
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		if DEBUG_LOGGING:
			print("[ipsc_mini] Sound effect throttled (too many concurrent sounds: ", active_sounds, "/", max_concurrent_sounds, ")")
		return
	
	# Load the impact sound (same as bullet script)
	var impact_sound = preload("res://audio/rifle_steel_plate.mp3")
	
	if impact_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()
		
		# Update throttling state
		last_sound_time = current_time
		active_sounds += 1
		
		# Clean up audio player after sound finishes and decrease active count
		audio_player.finished.connect(func(): 
			active_sounds -= 1
			audio_player.queue_free()
			if DEBUG_LOGGING:
				print("[ipsc_mini] Sound finished, active sounds: ", active_sounds)
		)
		if DEBUG_LOGGING:
			print("[ipsc_mini] Steel impact sound played at: ", world_pos, " (Active sounds: ", active_sounds, ")")
	else:
		print("[ipsc_mini] No impact sound found!")  # Keep this as it indicates an error

func play_impact_sound_at_position(world_pos: Vector2):
	"""Play steel impact sound effect at specific position (legacy - non-throttled)"""
	# Load the impact sound (same as bullet script)
	var impact_sound = preload("res://audio/rifle_steel_plate.mp3")
	
	if impact_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()
		
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
		print("[ipsc_mini] Steel impact sound played at: ", world_pos)
	else:
		print("[ipsc_mini] No impact sound found!")
