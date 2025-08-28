extends Area2D

var last_click_frame = -1
var is_fallen = false
@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

func _ready():
	# Connect the input_event signal to handle mouse clicks
	input_event.connect(_on_input_event)
	
	# Debug: Test if shader material is working
	test_shader_material()

func _input(event):
	# Debug: Press SPACE to test shader effects manually
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("SPACE pressed - testing shader")
			test_shader_effects()
		elif event.keycode == KEY_R:
			print("R pressed - resetting paddle")
			reset_paddle()

func test_shader_material():
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		print("Shader material found!")
		print("Shader: ", shader_material.shader)
		print("Fall progress: ", shader_material.get_shader_parameter("fall_progress"))
	else:
		print("ERROR: No shader material found on sprite!")

func _on_input_event(_viewport, event, shape_idx):
	# Check for left mouse button click and if paddle hasn't fallen yet
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_fallen:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Determine which area was clicked based on shape_idx
		match shape_idx:
			0:  # CircleArea (index 0) - Main target hit
				print("Paddle circle area hit! Starting fall animation...")
				trigger_fall_animation()
			1:  # StandArea (index 1) 
				print("Paddle stand area hit!")
				# Debug: Test shader manually
				test_shader_effects()
			_:
				print("Paddle hit!")

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
		print("Paddle already fallen, ignoring trigger")
		return
		
	print("=== TRIGGERING FALL ANIMATION ===")
	is_fallen = true
	
	# Debug: Check if we have the material
	var shader_material = sprite.material as ShaderMaterial
	if not shader_material:
		print("ERROR: No shader material found!")
		return
	
	print("Shader material found, setting parameters...")
	
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
	
	print("=== FALL ANIMATION TRIGGERED ===")

func _on_fall_animation_finished(anim_name: StringName):
	if anim_name == "fall_down":
		print("Paddle fall animation completed!")
		# Optional: Add scoring, sound effects, or remove the paddle
		# For now, just disable further interactions
		input_pickable = false

# Optional: Function to reset the paddle (for testing or game restart)
func reset_paddle():
	is_fallen = false
	input_pickable = true
	position = Vector2.ZERO
	
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("fall_progress", 0.0)
		shader_material.set_shader_parameter("rotation_angle", 0.0)
	
	if animation_player:
		animation_player.stop()
		animation_player.seek(0.0)
