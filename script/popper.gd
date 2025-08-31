extends Area2D

var last_click_frame = -1
var is_fallen = false
@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")

# Scoring system
var total_score: int = 0
signal target_hit(zone: String, points: int)
signal target_disappeared

func _ready():
	# Connect the input_event signal to handle mouse clicks
	input_event.connect(_on_input_event)
	
		# Connect to WebSocket bullet hit signal
	var ws_listener = get_node("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[ipsc_mini] Connected to WebSocketListener bullet_hit signal")
	else:
		print("[ipsc_mini] WebSocketListener singleton not found!")
	
	
	# Set up collision detection for bullets
	collision_layer = 7  # Target layer
	collision_mask = 0   # Don't detect other targets
	
	# Debug: Test if shader material is working
	test_shader_material()

func _input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if bullet spawning is enabled
		if not WebSocketListener.bullet_spawning_enabled:
			print("[popper] Bullet spawning disabled during shot timer")
			return
			
		var mouse_screen_pos = event.position
		var world_pos = get_global_mouse_position()
		print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", world_pos)
		spawn_bullet_at_position(world_pos)
	
	# Debug: Press T to test popper shader effects manually
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("T pressed - testing popper shader")
			test_shader_effects()
		elif event.keycode == KEY_Y:
			print("Y pressed - resetting popper")
			reset_popper()

func test_shader_material():
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		print("Popper shader material found!")
		print("Shader: ", shader_material.shader)
		print("Fall progress: ", shader_material.get_shader_parameter("fall_progress"))
	else:
		print("ERROR: No shader material found on popper sprite!")

func _on_input_event(_viewport, event, shape_idx):
	# Check for left mouse button click and if popper hasn't fallen yet
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_fallen:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Determine which area was clicked based on shape_idx
		match shape_idx:
			0:  # StandArea (index 0)
				print("Popper stand hit!")
				test_shader_effects()
			1:  # BodyArea (index 1) - Main scoring hit
				print("Popper body hit! Starting fall animation...")
				trigger_fall_animation()
			2:  # NeckArea (index 2) - Medium scoring hit
				print("Popper neck hit! Starting fall animation...")
				trigger_fall_animation()
			3:  # HeadArea (index 3) - High scoring hit
				print("Popper head hit! Starting fall animation...")
				trigger_fall_animation()
			_:
				print("Popper hit!")

func test_shader_effects():
	print("Testing popper shader effects manually...")
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		# Manually set shader parameters to test
		shader_material.set_shader_parameter("fall_progress", 0.5)
		shader_material.set_shader_parameter("rotation_angle", 45.0)
		shader_material.set_shader_parameter("perspective_strength", 2.0)
		print("Popper shader parameters set for testing")
	else:
		print("ERROR: Cannot test - no shader material!")

func trigger_fall_animation():
	if is_fallen:
		print("Popper already fallen, ignoring trigger")
		return
		
	print("=== TRIGGERING POPPER FALL ANIMATION ===")
	is_fallen = true
	
	# Debug: Check if we have the material
	var shader_material = sprite.material as ShaderMaterial
	if not shader_material:
		print("ERROR: No popper shader material found!")
		return
	
	print("Popper shader material found, setting parameters...")
	
	# Add some randomization to the fall - different from paddle
	var random_rotation = randf_range(-150.0, 150.0)  # More dramatic for popper
	var blur_intensity = randf_range(0.035, 0.065)    # Slightly stronger blur
	var motion_dir = Vector2(randf_range(-0.3, 0.3), 1.0).normalized()
	var perspective = randf_range(1.3, 2.2)           # Stronger perspective
	
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
	
	print("Starting popper animation 'fall_down'...")
	animation_player.play("fall_down")
	
	# Connect to animation finished signal to handle cleanup
	if not animation_player.animation_finished.is_connected(_on_fall_animation_finished):
		animation_player.animation_finished.connect(_on_fall_animation_finished)
	
	print("=== POPPER FALL ANIMATION TRIGGERED ===")

func _on_fall_animation_finished(anim_name: StringName):
	if anim_name == "fall_down":
		print("Popper fall animation completed!")
		# Optional: Add scoring, sound effects, or remove the popper
		# For now, just disable further interactions
		input_pickable = false
		
		# Emit signal to notify the drills system that the target has disappeared
		target_disappeared.emit()
		print("target_disappeared signal emitted")

# Optional: Function to reset the popper (for testing or game restart)
func reset_popper():
	is_fallen = false
	input_pickable = true
	position = Vector2(245, 407)  # Original position
	
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("fall_progress", 0.0)
		shader_material.set_shader_parameter("rotation_angle", 0.0)
	
	if animation_player:
		animation_player.stop()
		animation_player.seek(0.0)

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
	
	# Convert bullet world position to local coordinates
	var local_pos = to_local(bullet_position)
	
	var zone_hit = ""
	var points = 0
	
	# Check which collision area the bullet hit by testing point in shapes
	# We need to check each collision shape manually since we can't get shape_idx from collision
	if is_point_in_head_area(local_pos):
		zone_hit = "HeadArea"
		points = 5
		print("COLLISION: Popper head hit by bullet - 5 points!")
		trigger_fall_animation()
	elif is_point_in_neck_area(local_pos):
		zone_hit = "NeckArea"
		points = 3
		print("COLLISION: Popper neck hit by bullet - 3 points!")
		trigger_fall_animation()
	elif is_point_in_body_area(local_pos):
		zone_hit = "BodyArea"
		points = 2
		print("COLLISION: Popper body hit by bullet - 2 points!")
		trigger_fall_animation()
	elif is_point_in_stand_area(local_pos):
		zone_hit = "StandArea"
		points = 0
		print("COLLISION: Popper stand hit by bullet - 0 points!")
		test_shader_effects()
	else:
		zone_hit = "miss"
		points = 0
		print("COLLISION: Bullet hit popper but outside defined areas")
	
	# Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points)
	print("Total score: ", total_score)
	
	return zone_hit

func is_point_in_head_area(point: Vector2) -> bool:
	var head_area = get_node("HeadArea")
	if head_area and head_area is CollisionShape2D:
		var shape = head_area.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(head_area.position)
			return distance <= shape.radius
	return false

func is_point_in_neck_area(point: Vector2) -> bool:
	var neck_area = get_node("NeckArea")
	if neck_area and neck_area is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(point, neck_area.polygon)
	return false

func is_point_in_body_area(point: Vector2) -> bool:
	var body_area = get_node("BodyArea")
	if body_area and body_area is CollisionShape2D:
		var shape = body_area.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(body_area.position)
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
	print("Score reset to 0")

func _on_websocket_bullet_hit(pos: Vector2):
	# Check if bullet spawning is enabled
	if not WebSocketListener.bullet_spawning_enabled:
		print("[popper] WebSocket bullet spawning disabled during shot timer")
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
	print("[BlockSpawner] Received bullet hit at position (ws): ", pos, ", transformed to game: ", transformed_pos)
	#spawn_bullet_at_position
	spawn_bullet_at_position(transformed_pos)
