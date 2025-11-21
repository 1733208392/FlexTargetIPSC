extends Area2D

var last_click_frame = -1

# Animation state tracking
var is_disappearing: bool = false

# Shot tracking for disappearing animation - only valid target hits count
var shot_count: int = 0
@export var max_shots: int = 2  # Exported so scenes can override in the editor; default 2

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
const DEBUG_DISABLED = true

# Performance optimization for rotating targets
var rotation_cache_angle: float = 0.0
var rotation_cache_time: float = 0.0
var rotation_cache_duration: float = 0.1  # Cache rotation for 100ms

# Bullet activity monitoring for animation pausing
var bullet_activity_count: int = 0
var activity_threshold: int = 3  # Pause rotation if 3+ bullets in flight
var activity_cooldown_timer: float = 0.0
var activity_cooldown_duration: float = 1.0  # Resume after 1 second of low activity
var animation_paused: bool = false

# Scoring system
var total_score: int = 0
var drill_active: bool = false  # Flag to ignore shots before drill starts
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
	# Set up collision detection for bullets
	# NOTE: Collision detection is now obsolete due to WebSocket fast path
	# collision_layer = 7  # Target layer
	# collision_mask = 0   # Don't detect other targets

	# If loaded by drills_network (networked drills loader), set max_shots high for testing
	var drills_network = get_node_or_null("/root/drills_network")
	if drills_network:
		max_shots = 1000

func _on_input_event(_viewport, event, _shape_idx):
	# Don't process input events if target is disappearing
	if is_disappearing:
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
		# Head zone has highest priority (5 points)
		if is_point_in_zone("head-0", local_pos):
			return

		# Heart zone has high priority (4 points)
		if is_point_in_zone("heart-0", local_pos):
			return

		# Body zone has medium priority (3 points)
		if is_point_in_zone("body-1", local_pos):
			return

		# Other zone has lowest priority (2 points)
		if is_point_in_zone("other-3", local_pos):
			return


func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if not zone_node:
		return false
	
	if zone_node is CollisionPolygon2D:
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
	elif zone_node is CollisionShape2D:
		var shape = zone_node.shape
		var local_point = point - zone_node.position
		if shape is CircleShape2D:
			return local_point.length() <= shape.radius
		elif shape is RectangleShape2D:
			var rect = shape.get_rect()
			rect.position -= shape.size / 2  # Center the rect
			return rect.has_point(local_point)
		# Add other shape types if needed
	return false

func spawn_bullet_at_position(world_pos: Vector2):

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

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	is_disappearing = true

	# Get the AnimationPlayer
	var animation_player = get_node("AnimationPlayer")
	if animation_player:
		# Connect to the animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

		# Play the disappear animation
		animation_player.play("disappear")
func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""

	# Disable collision detection completely
	# NOTE: Collision detection was already obsolete due to WebSocket fast path
	# set_collision_layer(0)
	# set_collision_mask(0)

	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()

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


func reset_bullet_hole_pool():
	"""Reset the bullet hole pool by hiding all active holes"""

	# Hide all active bullet holes
	for hole in active_bullet_holes:
		if is_instance_valid(hole):
			hole.visible = false

	# Clear active list
	active_bullet_holes.clear()


func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""

	if not BulletHoleScene:
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


func get_pooled_bullet_hole() -> Node:
	"""Get an available bullet hole from the pool, or create new if needed"""
	# Try to find an inactive bullet hole in the pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole) and not hole.visible:
			return hole

	# If no available holes in pool, create a new one (fallback)
	if BulletHoleScene:
		var new_hole = BulletHoleScene.instantiate()
		add_child(new_hole)
		bullet_hole_pool.append(new_hole)  # Add to pool for future use
		return new_hole

	return null

func return_bullet_hole_to_pool(hole: Node):
	"""Return a bullet hole to the pool by hiding it"""
	if is_instance_valid(hole):
		hole.visible = false
		# Remove from active list
		if hole in active_bullet_holes:
			active_bullet_holes.erase(hole)

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""

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

func _on_websocket_bullet_hit(pos: Vector2):

	# Ignore shots if drill is not active yet
	if not drill_active:
		return

	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		return

	# Check if this target is part of a rotating scene (ipda_rotate)
	# Use optimized rotation-aware processing instead of bullet spawning
	var parent_node = get_parent()
	while parent_node:
		if parent_node.name.contains("IPDARotate") or parent_node.name.contains("RotationCenter"):
			# Use optimized direct hit processing for rotating targets
			handle_websocket_bullet_hit_rotating(pos)
			return
		parent_node = parent_node.get_parent()


	# FAST PATH: Direct bullet hole spawning for WebSocket hits (non-rotating targets only)
	handle_websocket_bullet_hit_fast(pos)

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""

	# Don't process if target is disappearing
	if is_disappearing:
		return

	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)

	# 1. FIRST: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false

	# Check which zone was hit (highest score first)
	# TODO: Update zone names and scoring for IPDA
	if is_point_in_zone("head-0", local_pos):
		zone_hit = "head-0"
		points = 0
		is_target_hit = true
	elif is_point_in_zone("heart-0", local_pos):
		zone_hit = "heart-0"
		points = 0
		is_target_hit = true
	elif is_point_in_zone("body-1", local_pos):
		zone_hit = "body-1"
		points = -1
		is_target_hit = true
	elif is_point_in_zone("other-3", local_pos):
		zone_hit = "other-3"
		points = -3
		is_target_hit = true
	else:
		zone_hit = "miss"
		points = -5
		is_target_hit = false

	# 2. CONDITIONAL: Only spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
	# 3. ALWAYS: Spawn bullet effects (impact/sound) but skip smoke for misses
	spawn_bullet_effects_at_position(world_pos, is_target_hit)

	# 4. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos)

	# 5. Increment shot count and check for disappearing animation (only for valid target hits)
	if is_target_hit:
		shot_count += 1

		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()
func spawn_bullet_effects_at_position(world_pos: Vector2, _is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""

	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds

	# Load the effect scenes directly
	# var bullet_smoke_scene = preload("res://scene/bullet_smoke.tscn")
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")

	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()

	# Throttled smoke effect - DISABLED for performance optimization
	# Smoke is the most expensive effect (GPUParticles2D) and not essential for gameplay
	if false:  # Completely disabled
		pass
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above bullet holes
		impact.z_index = 15
		last_impact_time = time_stamp
	# Throttled sound effect - only plays for hits since this function is only called for hits
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return

	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return

	# Load the paper impact sound for paper targets
	var impact_sound = preload("res://audio/paper_hit.MP3")

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
		)
func play_impact_sound_at_position(world_pos: Vector2):
	"""Play paper impact sound effect at specific position (legacy - non-throttled)"""
	# Load the paper impact sound for paper targets
	var impact_sound = preload("res://audio/paper_hit.MP3")

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
# ROTATION PERFORMANCE OPTIMIZATIONS

func get_cached_rotation_angle() -> float:
	"""Get the current rotation angle with caching for performance"""
	var current_time = Time.get_ticks_msec() / 1000.0

	# Use cached value if still valid
	if (current_time - rotation_cache_time) < rotation_cache_duration:
		return rotation_cache_angle

	# Update cache with current rotation
	var rotation_center = get_parent()
	if rotation_center and rotation_center.name == "RotationCenter":
		rotation_cache_angle = rotation_center.rotation
		rotation_cache_time = current_time
		return rotation_cache_angle

	return 0.0

func handle_websocket_bullet_hit_rotating(world_pos: Vector2) -> void:
	"""Optimized hit processing for rotating targets without bullet spawning"""

	# Don't process if target is disappearing
	if is_disappearing:
		return

	# DISABLE animation pausing for rotating targets - let ipda_rotate.gd control animation
	# bullet_activity_count += 1
	# monitor_bullet_activity()

	# Convert world position to local coordinates (this handles rotation automatically)
	var local_pos = to_local(world_pos)

	# 1. FIRST: Check if bullet hit the BarrelWall (for rotating targets)
	var barrel_wall_hit = false
	var parent_scene = get_parent().get_parent()  # Get the IPDARotate scene
	if parent_scene and parent_scene.name.contains("IPDARotate"):
		var barrel_wall = parent_scene.get_node_or_null("BarrelWall")
		if barrel_wall:
			var collision_shape = barrel_wall.get_node_or_null("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				# Convert world position to barrel wall's local coordinate system
				var barrel_local_pos = barrel_wall.to_local(world_pos)
				# Check if point is inside barrel wall collision shape
				var shape = collision_shape.shape
				if shape is RectangleShape2D:
					var rect_shape = shape as RectangleShape2D
					var half_extents = rect_shape.size / 2.0
					var shape_pos = collision_shape.position
					var relative_pos = barrel_local_pos - shape_pos
					if abs(relative_pos.x) <= half_extents.x and abs(relative_pos.y) <= half_extents.y:
						barrel_wall_hit = true

	# 2. SECOND: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false

	if barrel_wall_hit:
		# Barrel wall hit - count as miss
		zone_hit = "barrel_miss"
		points = 0
		is_target_hit = false
	else:
		# Check target zones (highest score first)
		# TODO: Update zone names and scoring for IPDA
		if is_point_in_zone("head-0", local_pos):
			zone_hit = "head-0"
			points = 0
			is_target_hit = true
		elif is_point_in_zone("heart-0", local_pos):
			zone_hit = "heart-0"
			points = 0
			is_target_hit = true
		elif is_point_in_zone("body-1", local_pos):
			zone_hit = "body-1"
			points = -1
			is_target_hit = true
		elif is_point_in_zone("other-3", local_pos):
			zone_hit = "other-3"
			points = -3
			is_target_hit = true
		else:
			zone_hit = "miss"
			points = -5
			is_target_hit = false

	# 3. CONDITIONAL: Only spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
	# 4. ALWAYS: Spawn bullet effects (impact/sound) but skip smoke for misses
	spawn_bullet_effects_at_position(world_pos, is_target_hit)

	# 5. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos)

	# 6. Increment shot count and check for disappearing animation (only for valid target hits)
	if is_target_hit:
		shot_count += 1

		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()

func monitor_bullet_activity():
	"""Monitor bullet activity and pause/resume animation accordingly"""
	# Pause animation if activity is high
	if bullet_activity_count >= activity_threshold and not animation_paused:
		pause_rotation_animation()

	# Reset cooldown timer when activity increases
	if bullet_activity_count > 0:
		activity_cooldown_timer = 0.0
	else:
		# Increment cooldown timer when no activity
		activity_cooldown_timer += get_process_delta_time()

		# Resume animation after cooldown period
		if activity_cooldown_timer >= activity_cooldown_duration and animation_paused:
			resume_rotation_animation()

func pause_rotation_animation():
	"""Pause the rotation animation to improve performance"""
	var rotation_center = get_parent()
	if rotation_center and rotation_center.name == "RotationCenter":
		var animation_player = rotation_center.get_parent().get_node_or_null("AnimationPlayer")
		if animation_player and animation_player.is_playing():
			animation_player.pause()
			animation_paused = true

func resume_rotation_animation():
	"""Resume the rotation animation"""
	var rotation_center = get_parent()
	if rotation_center and rotation_center.name == "RotationCenter":
		var animation_player = rotation_center.get_parent().get_node_or_null("AnimationPlayer")
		if animation_player and not animation_player.is_playing():
			animation_player.play()
			animation_paused = false
			activity_cooldown_timer = 0.0
