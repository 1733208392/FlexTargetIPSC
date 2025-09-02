extends Area2D

var last_click_frame = -1
var is_fallen = false
var initial_position: Vector2  # Store the paddle's starting position
@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

# Paddle identification
var paddle_id: String = ""  # Unique identifier for this paddle

# Bullet spawning
const BulletScene = preload("res://scene/bullet.tscn")
var debug_markers = true  # Set to false to disable debug markers

# Scoring system
var total_score: int = 0
signal target_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2)
signal target_disappeared(paddle_id: String)

func _ready():
	# Store the initial position for relative animation
	initial_position = position
	print("[paddle %s] Initial position stored: %s" % [paddle_id, initial_position])
	
	# Ensure input is enabled for mouse clicks
	input_pickable = true
	print("[paddle %s] Input pickable enabled" % paddle_id)
	
	# Connect the input_event signal to handle mouse clicks
	input_event.connect(_on_input_event)
	
	# Set default paddle ID if not already set
	if paddle_id == "":
		paddle_id = name  # Use node name as default ID
	
	# Create unique material instance to prevent shared shader parameters
	# This ensures each paddle has its own shader state
	if sprite.material:
		sprite.material = sprite.material.duplicate()
		print("[paddle %s] Created unique shader material instance" % paddle_id)
		
		# Create unique animation with correct starting position
		create_relative_animation()
	
		# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[paddle %s] Connected to WebSocketListener bullet_hit signal" % paddle_id)
	else:
		print("[paddle %s] WebSocketListener singleton not found!" % paddle_id)
	
	# Set up collision detection for bullets
	collision_layer = 7  # Target layer
	collision_mask = 0   # Don't detect other targets
	
	# Debug: Test if shader material is working
	test_shader_material()

func set_paddle_id(id: String):
	"""Set the unique identifier for this paddle"""
	paddle_id = id
	print("Paddle ID set to: %s" % paddle_id)

func get_paddle_id() -> String:
	"""Get the unique identifier for this paddle"""
	return paddle_id

func create_relative_animation():
	"""Create a unique animation that starts from the paddle's actual position"""
	if not animation_player:
		print("WARNING: Paddle %s: No AnimationPlayer found" % paddle_id)
		return
	
	if not animation_player.has_animation("fall_down"):
		print("WARNING: Paddle %s: Animation 'fall_down' not found" % paddle_id)
		return
	
	# Get the original animation
	var original_animation = animation_player.get_animation("fall_down")
	if not original_animation:
		print("ERROR: Paddle %s: Could not get 'fall_down' animation" % paddle_id)
		return
	
	# Create a duplicate animation
	var new_animation = original_animation.duplicate()
	
	# Find and update the position track
	for i in range(new_animation.get_track_count()):
		var track_path = new_animation.track_get_path(i)
		
		# Look for the position track
		if str(track_path) == ".:position":
			print("Paddle %s: Updating position track %d" % [paddle_id, i])
			
			# Get the original end position offset (0, 120)
			var original_keys = new_animation.track_get_key_value(i, 1)  # Get the end position
			var fall_offset = original_keys  # This should be Vector2(0, 120)
			
			# Calculate new positions relative to initial position
			var start_pos = initial_position
			var end_pos = initial_position + fall_offset
			
			print("Paddle %s: Position animation - Start: %s, End: %s" % [paddle_id, start_pos, end_pos])
			
			# Update the track keys
			new_animation.track_set_key_value(i, 0, start_pos)  # Start position
			new_animation.track_set_key_value(i, 1, end_pos)    # End position
			
			break
	
	# Create a new animation library with our updated animation
	var new_library = AnimationLibrary.new()
	new_library.add_animation("fall_down", new_animation)
	
	# Replace the animation library
	animation_player.remove_animation_library("")
	animation_player.add_animation_library("", new_library)
	
	print("Paddle %s: Created relative animation starting from %s" % [paddle_id, initial_position])

func _input(event):
	# Debug: Press SPACE to test shader effects manually
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("SPACE pressed - testing shader")
			test_shader_effects()
		elif event.keycode == KEY_R:
			print("R pressed - resetting paddle")
			reset_paddle()
		elif event.keycode == KEY_D:
			debug_markers = !debug_markers
			print("Debug markers ", "enabled" if debug_markers else "disabled")

func test_shader_material():
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		print("Paddle %s: Shader material found! Resource ID: %s" % [paddle_id, shader_material.get_instance_id()])
		print("Paddle %s: Shader: %s" % [paddle_id, shader_material.shader])
		print("Paddle %s: Fall progress: %s" % [paddle_id, shader_material.get_shader_parameter("fall_progress")])
	else:
		print("ERROR: Paddle %s: No shader material found on sprite!" % paddle_id)

func _on_input_event(_viewport, event, shape_idx):
	# Check for left mouse button click and if paddle hasn't fallen yet
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_fallen:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Get the mouse position and convert to world coordinates (accounting for Camera2D)
		var mouse_screen_pos = event.global_position
		var camera = get_viewport().get_camera_2d()
		var mouse_world_pos: Vector2
		
		if camera:
			# Convert screen position to world position using camera transformation
			mouse_world_pos = camera.get_global_mouse_position()
			print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", mouse_world_pos)
		else:
			# Fallback if no camera
			mouse_world_pos = mouse_screen_pos
			print("No camera found, using screen position: ", mouse_world_pos)
		
		# Spawn bullet at correct world position
		spawn_bullet_at_position(mouse_world_pos)
		
		# Determine which area was clicked based on shape_idx
		match shape_idx:
			0:  # CircleArea (index 0) - Main target hit
				print("Paddle %s circle area hit! Starting fall animation..." % paddle_id)
				var points = 5
				total_score += points
				target_hit.emit(paddle_id, "CircleArea", points, event.position)
				trigger_fall_animation()
			1:  # StandArea (index 1) 
				print("Paddle %s stand area hit!" % paddle_id)
				var points = 0
				total_score += points
				target_hit.emit(paddle_id, "StandArea", points, event.position)
				# Debug: Test shader manually
				test_shader_effects()
			_:
				print("Paddle %s hit!" % paddle_id)
				var points = 1  # Default points for general hit
				total_score += points
				target_hit.emit(paddle_id, "GeneralHit", points, event.position)

func spawn_bullet_at_position(world_pos: Vector2):
	print("PADDLE: Spawning bullet at world position: ", world_pos)
	
	if BulletScene:
		var bullet = BulletScene.instantiate()
		print("PADDLE: Bullet instantiated: ", bullet)
		
		# Find the top-level scene node to add bullet effects
		# This ensures effects don't get rotated with rotating targets
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
			print("PADDLE: Bullet added to scene root: ", scene_root.name)
		else:
			# Fallback to immediate parent if scene_root not found
			get_parent().add_child(bullet)
			print("PADDLE: Bullet added to parent (fallback)")
		
		# Use the new set_spawn_position method to ensure proper positioning
		bullet.set_spawn_position(world_pos)
		
		print("PADDLE: Bullet spawned and position set to: ", world_pos)
	else:
		print("PADDLE ERROR: BulletScene is null!")

func handle_bullet_collision(bullet_position: Vector2):
	"""Handle collision detection when a bullet hits this target"""
	print("PADDLE %s: Bullet collision detected at position: %s" % [paddle_id, bullet_position])
	
	# If paddle has already fallen, ignore further collisions
	if is_fallen:
		print("PADDLE %s: Already fallen, ignoring collision" % paddle_id)
		return "already_fallen"
	
	# Convert bullet world position to local coordinates
	var local_pos = to_local(bullet_position)
	print("PADDLE %s: Local position: %s" % [paddle_id, local_pos])
	
	var zone_hit = ""
	var points = 0
	
	# Check which collision area the bullet hit
	if is_point_in_circle_area(local_pos):
		zone_hit = "CircleArea"
		points = 5
		print("COLLISION: Paddle %s circle area hit by bullet - %d points!" % [paddle_id, points])
		trigger_fall_animation()
	elif is_point_in_stand_area(local_pos):
		zone_hit = "StandArea"
		points = 0
		print("COLLISION: Paddle %s stand area hit by bullet - %d points!" % [paddle_id, points])
	else:
		zone_hit = "miss"
		points = 0
		print("COLLISION: Bullet hit paddle %s but outside defined areas" % paddle_id)
	
	# Update score and emit signal
	total_score += points
	target_hit.emit(paddle_id, zone_hit, points, bullet_position)
	print("PADDLE %s: Total score: %d" % [paddle_id, total_score])
	
	return zone_hit

func is_point_in_circle_area(point: Vector2) -> bool:
	var circle_area = get_node("CircleArea")
	if circle_area and circle_area is CollisionShape2D:
		var shape = circle_area.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(circle_area.position)
			return distance <= shape.radius
	return false

func is_point_in_stand_area(point: Vector2) -> bool:
	var stand_area = get_node("StandArea")
	if stand_area and stand_area is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(point, stand_area.polygon)
	return false

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0
	print("Paddle %s score reset to 0" % paddle_id)

func create_debug_marker(world_pos: Vector2):
	# Create a small visual marker to show where the click was detected
	var marker = ColorRect.new()
	marker.size = Vector2(10, 10)
	marker.color = Color.RED
	marker.global_position = world_pos - Vector2(5, 5)  # Center the marker
	get_parent().add_child(marker)
	
	# Remove marker after 1 second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func(): marker.queue_free(); timer.queue_free())
	get_parent().add_child(timer)
	timer.start()
	
	print("Debug marker created at: ", world_pos)

func test_shader_effects():
	print("Testing shader effects manually...")
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		# Manually set shader parameters to test
		shader_material.set_shader_parameter("fall_progress", 0.5)
		shader_material.set_shader_parameter("rotation_angle", 45.0)
		shader_material.set_shader_parameter("perspective_strength", 2.0)
		print("Shader parameters set for testing")
	else:
		print("ERROR: Cannot test - no shader material!")

func trigger_fall_animation():
	if is_fallen:
		print("Paddle %s already fallen, ignoring trigger" % paddle_id)
		return
		
	print("=== TRIGGERING FALL ANIMATION FOR PADDLE %s ===" % paddle_id)
	is_fallen = true
	
	# Debug: Check if we have the material
	var shader_material = sprite.material as ShaderMaterial
	if not shader_material:
		print("ERROR: Paddle %s: No shader material found!" % paddle_id)
		return
	
	print("Paddle %s: Shader material found, setting parameters... (Resource ID: %s)" % [paddle_id, shader_material.get_instance_id()])
	
	# Add some randomization to the fall
	var random_rotation = randf_range(-120.0, 120.0)
	var blur_intensity = randf_range(0.03, 0.06)
	var motion_dir = Vector2(randf_range(-0.4, 0.4), 1.0).normalized()
	var perspective = randf_range(1.2, 2.0)
	
	print("Setting rotation_angle to: ", random_rotation)
	shader_material.set_shader_parameter("rotation_angle", random_rotation)
	
	print("Setting motion_blur_intensity to: ", blur_intensity)
	shader_material.set_shader_parameter("motion_blur_intensity", blur_intensity)
	
	print("Setting motion_direction to: ", motion_dir)
	shader_material.set_shader_parameter("motion_direction", motion_dir)
	
	print("Setting perspective_strength to: ", perspective)
	shader_material.set_shader_parameter("perspective_strength", perspective)
	
	# Play the fall animation
	if not animation_player:
		print("ERROR: No AnimationPlayer found!")
		return
		
	if not animation_player.has_animation("fall_down"):
		print("ERROR: Animation 'fall_down' not found!")
		return
	
	print("Starting animation 'fall_down'...")
	animation_player.play("fall_down")
	
	# Connect to animation finished signal to handle cleanup
	if not animation_player.animation_finished.is_connected(_on_fall_animation_finished):
		animation_player.animation_finished.connect(_on_fall_animation_finished)
	
	print("=== FALL ANIMATION TRIGGERED FOR PADDLE %s ===" % paddle_id)

func _on_fall_animation_finished(anim_name: StringName):
	if anim_name == "fall_down":
		print("Paddle %s fall animation completed!" % paddle_id)
		# Optional: Add scoring, sound effects, or remove the paddle
		# For now, just disable further interactions
		input_pickable = false
		
		# Emit signal to notify the drills system that the target has disappeared
		target_disappeared.emit(paddle_id)
		print("target_disappeared signal emitted for paddle %s" % paddle_id)

# Optional: Function to reset the paddle (for testing or game restart)
func reset_paddle():
	is_fallen = false
	input_pickable = true
	position = initial_position  # Reset to initial position, not (0,0)
	
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("fall_progress", 0.0)
		shader_material.set_shader_parameter("rotation_angle", 0.0)
		print("Paddle %s: Shader parameters reset (Resource ID: %s)" % [paddle_id, shader_material.get_instance_id()])
	else:
		print("WARNING: Paddle %s: No shader material to reset!" % paddle_id)
	
	if animation_player:
		animation_player.stop()
		animation_player.seek(0.0)
	
	print("Paddle %s reset to initial position %s" % [paddle_id, initial_position])
	
	print("Paddle %s reset" % paddle_id)

func _on_websocket_bullet_hit(pos: Vector2):
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		print("[paddle %s] WebSocket bullet spawning disabled during shot timer" % paddle_id)
		return
		
	# Transform pos from WebSocket (268x476.4, origin bottom-left) to game (720x1280, origin top-left)
	var ws_width = 268.0
	var ws_height = 476.4
	var game_width = 720.0
	var game_height = 1280.0
	# Flip y and scale
	var x_new = pos.x * (game_width / ws_width)
	var y_new = game_height - (pos.y * (game_height / ws_height))
	var transformed_pos = Vector2(x_new, y_new)
	print("[Paddle %s] Received bullet hit at position (ws): %s, transformed to game: %s" % [paddle_id, pos, transformed_pos])
	#spawn_bullet_at_position
	spawn_bullet_at_position(transformed_pos)
