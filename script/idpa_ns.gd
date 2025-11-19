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

# Scoring system - IDPA No-Shoot variant: any hit = -5 points
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

		# Any hit on this no-shoot target scores -5
		handle_bullet_collision(event.global_position)
		return

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node_or_null(zone_name)
	if zone_node:
		if zone_node is CollisionPolygon2D:
			# For polygons, adjust point relative to the polygon's position
			var relative_point = point - zone_node.position
			var result = Geometry2D.is_point_in_polygon(relative_point, zone_node.polygon)
			if not DEBUG_DISABLED and result:
				print("[IDPA_NS] Point", point, "is in polygon zone", zone_name)
			return result
		elif zone_node is CollisionShape2D:
			# For shapes, check relative to the shape's position
			var shape = zone_node.shape
			if shape is CircleShape2D:
				var distance = point.distance_to(zone_node.position)
				var result = distance <= shape.radius
				if not DEBUG_DISABLED and result:
					print("[IDPA_NS] Point", point, "is in circle zone", zone_name)
				return result
			elif shape is RectangleShape2D:
				var rect = Rect2(zone_node.position - shape.size / 2, shape.size)
				var result = rect.has_point(point)
				if not DEBUG_DISABLED and result:
					print("[IDPA_NS] Point", point, "is in rectangle zone", zone_name)
				return result
	return false

func spawn_bullet_at_position(world_pos: Vector2):
	if BulletScene:
		var bullet = BulletScene.instantiate()

		# Find the top-level scene node to add bullet effects
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
		else:
			get_parent().add_child(bullet)

		bullet.set_spawn_position(world_pos)

func handle_bullet_collision(bullet_position: Vector2):
	"""Handle collision detection when a bullet hits this no-shoot target"""
	# Don't process if target is disappearing
	if is_disappearing:
		return "ignored"

	# IDPA_NS: Any hit on a no-shoot target scores -5 points
	var zone_hit = "no-shoot"
	var points = -5  # Penalty for hitting a no-shoot target

	# Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, bullet_position)

	# Increment shot count and check for disappearing animation
	shot_count += 1

	# Check if we've reached the maximum shots
	if shot_count >= max_shots:
		play_disappearing_animation()
	
	return zone_hit

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
	var animation_player = get_node_or_null("AnimationPlayer")
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
	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()

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

	# Reset score
	reset_score()

func initialize_bullet_hole_pool():
	"""Pre-allocate bullet holes for performance optimization"""
	for i in range(pool_size):
		var bullet_hole = BulletHoleScene.instantiate()
		bullet_hole.visible = false
		add_child(bullet_hole)
		bullet_hole_pool.append(bullet_hole)

func get_pooled_bullet_hole() -> Node:
	"""Get a bullet hole from the pool, or create a new one if all are in use"""
	# Look for an inactive bullet hole in the pool
	for bullet_hole in bullet_hole_pool:
		if not bullet_hole.visible:
			return bullet_hole

	# If all are in use, create a new one
	var bullet_hole = BulletHoleScene.instantiate()
	add_child(bullet_hole)
	bullet_hole_pool.append(bullet_hole)
	return bullet_hole

func spawn_bullet_hole(local_pos: Vector2):
	"""Spawn a bullet hole at the hit position"""
	var bullet_hole = get_pooled_bullet_hole()
	if bullet_hole:
		bullet_hole.position = local_pos
		bullet_hole.visible = true
		# Reset rotation if the bullet hole has one
		if bullet_hole is Node2D:
			bullet_hole.rotation = randf() * TAU
		# Add a slight random scale variation (0.9 - 1.1)
		if bullet_hole is CanvasItem:
			var scale_variance = randf_range(0.9, 1.1)
			bullet_hole.scale = Vector2(scale_variance, scale_variance)

func _on_websocket_bullet_hit(pos: Vector2):
	"""Handle WebSocket bullet hits"""
	if not drill_active:
		return

	# Handle the bullet hit with the -5 point penalty
	handle_websocket_bullet_hit_fast(pos)

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Fast path for WebSocket bullet hits - IDPA_NS always scores -5 points"""

	# Don't process if target is disappearing
	if is_disappearing:
		return

	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)

	# IDPA_NS: All hits score -5 points (no-shoot target penalty)
	var zone_hit = "no-shoot"
	var points = -5  # Penalty for hitting a no-shoot target
	var is_target_hit = true  # All hits count for disappearing animation

	if not DEBUG_DISABLED:
		print("[IDPA_NS] Hit detected at local_pos:", local_pos, " - penalty: ", points, " points")

	# Spawn bullet hole
	spawn_bullet_hole(local_pos)

	# Spawn bullet effects
	spawn_bullet_effects_at_position(world_pos, is_target_hit)

	# Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos)
	if not DEBUG_DISABLED:
		print("[IDPA_NS] Emitted target_hit signal: zone=", zone_hit, " points=", points, " total_score=", total_score)

	# Increment shot count and check for disappearing animation
	shot_count += 1

	# Check if we've reached the maximum shots
	if shot_count >= max_shots:
		play_disappearing_animation()

func spawn_bullet_effects_at_position(world_pos: Vector2, _is_target_hit: bool = true):
	"""Spawn bullet impact effects with throttling for performance"""

	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds

	# Load the effect scenes directly
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")

	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()

	# Throttled impact effect - ALWAYS spawn
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above bullet holes
		impact.z_index = 15
		last_impact_time = time_stamp

func _process(_delta):
	"""Main process loop"""
	pass

func set_target_drill_active(active: bool):
	"""Set whether the drill is active (used by drills manager)"""
	drill_active = active
	if not DEBUG_DISABLED:
		print("[IDPA_NS] Drill active set to: ", active)
