extends Node2D

const DEBUG_DISABLE = true

signal target_hit(zone: String, points: int, hit_position: Vector2)

var drill_active: bool = false:
	set(value):
		drill_active = value
		# Propagate to child IPSCMini
		var idpa = get_node_or_null("RotationCenter/IDPA")
		if idpa:
			idpa.drill_active = value
			if value:
				if not DEBUG_DISABLE: print("[idpa_rotate] Enabled drill_active on child IDPA Target")
			else:
				if not DEBUG_DISABLE: print("[idpa_rotate] Disabled drill_active on child IDPA Target")

var drill_finished: bool = false

func _ready():
	# Initialize drill_active to false by default
	drill_active = false
	
	# Get animation player but don't start continuous animations
	var animation_player = get_node_or_null("RotationCenter/AnimationPlayer")
	if animation_player:
		if not DEBUG_DISABLE: print("[idpa_rotation] Animation player ready")
	
	# Connect to WebSocket bullet hit signal and disconnect child's connection
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	var idpa = get_node_or_null("RotationCenter/IDPA")
	if ws_listener and idpa:
		ws_listener.bullet_hit.disconnect(Callable(idpa, "_on_websocket_bullet_hit"))
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		if not DEBUG_DISABLE: print("[idpa_rotate] Intercepted WebSocket bullet hit signal")
	
	# Connect to child's target_hit signal and forward it
	if idpa and idpa.has_signal("target_hit"):
		idpa.target_hit.connect(_on_child_target_hit)
		if not DEBUG_DISABLE: print("[idpa_rotate] Connected to child IDPA's target_hit signal")
	
	# Ensure IDPA max_shots is 2
	if idpa:
		idpa.max_shots = 2
		if not DEBUG_DISABLE: print("[idpa_rotate] Set IDPA max_shots to 2")
	
	# Connect to child's target_disappeared signal to finish drill
	if idpa and idpa.has_signal("target_disappeared"):
		idpa.target_disappeared.connect(_on_target_disappeared)
		if not DEBUG_DISABLE: print("[idpa_rotate] Connected to child IDPA's target_disappeared signal")
	
	# Connect to paddle's target_hit signal to trigger animations
	var paddle = get_node_or_null("Paddle")
	if paddle and paddle.has_signal("target_hit"):
		paddle.target_hit.connect(_on_paddle_hit)
		if not DEBUG_DISABLE: print("[idpa_rotate] Connected to paddle's target_hit signal")

func _play_random_animations_continuous(animation_player: AnimationPlayer):
	"""Continuously play random sequences of the 2 animations until drill finishes"""
	while not drill_finished:
		var animations = ["left2right", "up"]
		animations.shuffle()  # Randomize the order each sequence
		
		for anim in animations:
			animation_player.play(anim)
			if not DEBUG_DISABLE: print("[idpa_rotate] Playing animation: %s" % anim)
			await animation_player.animation_finished
	
	if not DEBUG_DISABLE: print("[idpa_rotate] Drill finished, stopping animations")

func _on_paddle_hit(_paddle_id: String, _zone: String, _points: int, _hit_position: Vector2):
	"""Handle paddle hit to start continuous random animation, but only if drill not finished"""
	if drill_finished:
		if not DEBUG_DISABLE: print("[idpa_rotate] Drill already finished, ignoring paddle hit")
		return
	
	var animation_player = get_node_or_null("RotationCenter/AnimationPlayer")
	if animation_player:
		if not DEBUG_DISABLE: print("[idpa_rotate] Paddle hit - starting continuous animation")
		_play_random_animations_continuous(animation_player)

func _on_child_target_hit(zone: String, points: int, hit_position: Vector2):
	# Forward the signal from child to root
	target_hit.emit(zone, points, hit_position)

func _on_target_disappeared():
	"""Called when the IDPA target disappears after 2 hits"""
	drill_finished = true
	if not DEBUG_DISABLE: print("[idpa_rotate] Target disappeared, drill finished")

func _on_websocket_bullet_hit(pos: Vector2):
	var idpa = get_node_or_null("RotationCenter/IDPA")
	if not idpa:
		return
	
	# Check if hit is in barrel wall
	var barrel_collision = get_node_or_null("BarrelWall/CollisionShape2D")
	if barrel_collision:
		var barrel_shape = barrel_collision.shape
		var barrel_transform = barrel_collision.global_transform
		var rect = barrel_shape.get_rect()
		rect.position = barrel_transform.origin + rect.position
		rect.size *= barrel_transform.get_scale()
		if rect.has_point(pos):
			# Block the bullet
			if not DEBUG_DISABLE: print("[idpa_rotate] Bullet blocked by barrel wall at pos: ", pos)
			return
	
	# Check if hit is in paddle collision circle
	var paddle_collision = get_node_or_null("Paddle/CollisionShape2D")
	if paddle_collision:
		var paddle_shape = paddle_collision.shape
		var paddle_center = paddle_collision.global_position
		var effective_radius = paddle_shape.radius * paddle_collision.get_parent().scale.x
		var dist = pos.distance_to(paddle_center)
		if dist <= effective_radius:
			# Trigger animation
			if not DEBUG_DISABLE: print("[idpa_rotate] Bullet hit paddle at pos: ", pos)
			_on_paddle_hit("", "", 0, pos)
			return
	
	# Otherwise, forward to IDPA for normal handling
	if not DEBUG_DISABLE: print("[idpa_rotate] Forwarding bullet hit to IDPA at pos: ", pos)
	idpa._on_websocket_bullet_hit(pos)
