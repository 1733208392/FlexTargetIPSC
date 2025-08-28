extends Node2D

@export var bullet_smoke_scene: PackedScene
@export var bullet_impact_scene: PackedScene
var impact_duration = 1  # How long the impact effect lasts
var show_bullet_sprite = false  # Set to true if you want to see the bullet sprite for debugging
var spawn_position: Vector2  # Store the actual spawn position

func set_spawn_position(pos: Vector2):
	spawn_position = pos
	global_position = pos
	print("Bullet spawn position set to: ", spawn_position)

func _ready():
	# Hide bullet sprite if not needed (since it's instant impact)
	var sprite = $Sprite2D
	if sprite and not show_bullet_sprite:
		sprite.visible = false
	
	# Wait a frame to ensure position is set, then trigger impact
	call_deferred("trigger_impact")

func trigger_impact():
	# Use spawn_position if it was set, otherwise use current global_position
	if spawn_position != Vector2.ZERO:
		global_position = spawn_position
	on_impact()

func on_impact():
	print("Bullet impact at position: ", global_position)
	
	# Use the bullet's exact global position for effects
	# This should match exactly where the bullet was spawned
	var impact_position = global_position
	
	print("Impact effects spawning at: ", impact_position)
	
	# Create smoke effect at exact impact position
	if bullet_smoke_scene:
		var smoke = bullet_smoke_scene.instantiate()
		smoke.global_position = impact_position
		get_parent().add_child(smoke)
		print("Smoke spawned at: ", smoke.global_position)
	
	# Create impact effect at exact impact position
	if bullet_impact_scene:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = impact_position
		get_parent().add_child(impact)
		print("Impact effect spawned at: ", impact.global_position)
	
	# Remove the bullet after a short duration to allow effects to play
	var timer = Timer.new()
	timer.wait_time = impact_duration
	timer.one_shot = true
	timer.timeout.connect(_on_impact_finished)
	add_child(timer)
	timer.start()

func _on_impact_finished():
	print("Bullet impact finished, removing bullet")
	queue_free()
