extends Node2D

signal target_hit(position: Vector2, score: int, area: String, is_hit: bool, rotation: float)
signal target_disappeared

@onready var animation_player: AnimationPlayer = $Target/AnimationPlayer
@onready var target_area: Area2D = $Target
@onready var cover_area: Area2D = $Cover
@onready var paddle_area: Area2D = $Paddle/Paddle
@onready var paddle_animation_player: AnimationPlayer = $Paddle/Paddle/AnimationPlayer

# Assuming these resources exist; adjust paths as needed
const BULLET_HOLE_SCENE = preload("res://scene/bullet_hole.tscn")
const IMPACT_SOUND = preload("res://audio/paper_hit.MP3")

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 8  # Keep 8 bullet holes pre-instantiated
var active_bullet_holes: Array[Node] = []

# Shot tracking for disappearing animation - only valid target hits count
var shot_count: int = 0
@export var max_shots: int = 2  # Exported so scenes can override in the editor; default 2

# Effect throttling for performance optimization
var last_sound_time: float = 0.0
var last_smoke_time: float = 0.0
var last_impact_time: float = 0.0
var sound_cooldown: float = 0.05  # 50ms minimum between sounds
var smoke_cooldown: float = 0.08  # 80ms minimum between smoke effects
var impact_cooldown: float = 0.06  # 60ms minimum between impact effects
var max_concurrent_sounds: int = 3  # Maximum number of concurrent sound effects
var active_sounds: int = 0

func _ready() -> void:
	# Connect to websocket signal (assuming it's emitted from a global manager or parent)
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
	
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()

func play_random_animation() -> void:
	var animations = ["up", "rotation"]
	var random_anim = animations[randi() % animations.size()]
	animation_player.play(random_anim)
	await animation_player.animation_finished
	play_random_animation()  # Loop continuously

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = get_global_mouse_position()
		simulate_bullet_hit(world_pos)

func simulate_bullet_hit(pos: Vector2) -> void:
	process_bullet_hit(pos)

func _on_websocket_bullet_hit(pos: Vector2) -> void:
	process_bullet_hit(pos)

func process_bullet_hit(pos: Vector2) -> void:
	var score: int = 0
	var area: String = ""
	var is_hit: bool = false
	
	# Check cover area first (highest priority)
	var cover_shapes = get_collision_shapes(cover_area)
	if is_point_in_shapes(pos, cover_shapes, cover_area.global_position):
		score = -5
		area = "cover"
		is_hit = false
	if is_instance_valid(paddle_area):
		var paddle_shapes = get_collision_shapes(paddle_area)
		if is_point_in_shapes(pos, paddle_shapes, paddle_area.global_position):
			score = -5
			area = "paddle"
			is_hit = false
			# Trigger paddle fall
			play_paddle_fall()
			# Start target animation since paddle is hit
			play_random_animation()
	
	# If neither cover nor paddle hit, check target
	if area == "":
		# Check target areas
		var target_shapes = get_collision_shapes(target_area)
		var hit_shape = get_hit_shape(pos, target_shapes, target_area.global_position)
		if hit_shape:
			is_hit = true
			var shape_name = hit_shape.name
			if shape_name.begins_with("head") or shape_name.begins_with("heart"):
				score = 0
				area = "head_heart"
			elif shape_name.begins_with("body"):
				score = -1
				area = "body"
			elif shape_name.begins_with("other"):
				score = -3
				area = "other"
			else:
				score = -5
				area = "miss"
		else:
			score = -5
			area = "miss"
			is_hit = false  # Miss still counts as hitting the target area
	
	# Spawn bullet hole only for target hits
	if is_hit:
		spawn_bullet_hole(target_area.to_local(pos))
	
	# Spawn bullet effects (impact/sound) for all hits
	spawn_bullet_effects_at_position(pos, is_hit)
	
	# Increment shot count and check for disappearing animation (only for valid target hits)
	if is_hit:
		shot_count += 1

		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()
		
		# Emit signal for target hits
		emit_signal("target_hit", pos, score, area, is_hit, target_area.rotation)

func get_collision_shapes(area: Area2D) -> Array:
	var shapes = []
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			shapes.append(child)
	return shapes

func is_point_in_shapes(point: Vector2, shapes: Array, offset: Vector2) -> bool:
	for shape_node in shapes:
		if is_point_in_shape(point, shape_node, offset + shape_node.position):
			return true
	return false

func is_point_in_shape(point: Vector2, shape_node, shape_pos: Vector2) -> bool:
	var local_point = point - shape_pos
	if shape_node is CollisionShape2D:
		var shape = shape_node.shape
		if shape is CircleShape2D:
			return local_point.length() <= shape.radius
		elif shape is RectangleShape2D:
			var half_size = shape.size / 2
			return abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y
	elif shape_node is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(local_point, shape_node.polygon)
	return false

func get_hit_shape(point: Vector2, shapes: Array, offset: Vector2):
	for shape_node in shapes:
		if is_point_in_shape(point, shape_node, offset + shape_node.position):
			return shape_node
	return null

func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""

	if not BULLET_HOLE_SCENE:
		return

	# Clear existing pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole):
			hole.queue_free()
	bullet_hole_pool.clear()
	active_bullet_holes.clear()

	# Pre-instantiate bullet holes
	for i in range(pool_size):
		var bullet_hole = BULLET_HOLE_SCENE.instantiate()
		target_area.add_child(bullet_hole)
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
	if BULLET_HOLE_SCENE:
		var new_hole = BULLET_HOLE_SCENE.instantiate()
		target_area.add_child(new_hole)
		bullet_hole_pool.append(new_hole)  # Add to pool for future use
		return new_hole

	return null

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
	# Throttled sound effect
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return

	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return

	if IMPACT_SOUND:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = IMPACT_SOUND
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

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	# Get the AnimationPlayer
	var anim_player = animation_player
	if anim_player:
		# Connect to the animation finished signal if not already connected
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

		# Play the disappear animation
		anim_player.play("disappear")

func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""
	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()

func play_paddle_fall():
	"""Trigger the paddle's fall_down animation"""
	if paddle_animation_player and paddle_animation_player.has_animation("fall_down"):
		paddle_animation_player.play("fall_down")
		# Connect to animation finished to queue_free after animation
		if not paddle_animation_player.animation_finished.is_connected(_on_paddle_fall_finished):
			paddle_animation_player.animation_finished.connect(_on_paddle_fall_finished)

func _on_paddle_fall_finished(animation_name: String):
	"""Called when paddle fall animation finishes"""
	if animation_name == "fall_down":
		if is_instance_valid(paddle_area):
			paddle_area.queue_free()
