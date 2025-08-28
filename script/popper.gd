extends Area2D

var last_click_frame = -1
var is_fallen = false
@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")

func _ready():
	# Connect the input_event signal to handle mouse clicks
	input_event.connect(_on_input_event)
	
	# Debug: Test if shader material is working
	test_shader_material()

func _input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
