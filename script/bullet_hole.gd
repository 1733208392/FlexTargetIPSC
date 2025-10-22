extends Sprite2D

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

# Array of bullet hole textures
const BULLET_HOLE_TEXTURES = [
	"res://asset/bullet_hole1.png",
	"res://asset/bullet_hole2.png",
	"res://asset/bullet_hole3.png",
	"res://asset/bullet_hole4.png",
	"res://asset/bullet_hole5.png",
	"res://asset/bullet_hole6.png"
]

# Configuration
@export var random_rotation: bool = true   # Randomly rotate the bullet hole
@export var random_scale: bool = true      # Slightly randomize the scale
@export var scale_range: Vector2 = Vector2(0.6, 0.8)  # Min and max scale factors
@export var z_index_offset: int = 1       # Render in front of target sprite

func _ready():
	# Set z-index to render behind other elements
	z_index = z_index_offset
	
	# Randomly select a bullet hole texture
	randomize_texture()
	
	# Apply random transformations
	if random_rotation:
		rotation_degrees = randf() * 360.0
	
	if random_scale:
		var scale_factor = randf_range(scale_range.x, scale_range.y)
		scale = Vector2(scale_factor, scale_factor)
	
	# print("Bullet hole created with:")
	# print("  - Texture: ", texture.resource_path if texture else "none")
	# print("  - Position: ", position)
	# print("  - Scale: ", scale)
	# print("  - Z-index: ", z_index)
	# print("  - Visible: ", visible)
	# print("  - Modulate: ", modulate)

func randomize_texture():
	"""Randomly select one of the bullet hole textures"""
	if BULLET_HOLE_TEXTURES.size() > 0:
		var random_index = randi() % BULLET_HOLE_TEXTURES.size()
		var texture_path = BULLET_HOLE_TEXTURES[random_index]
		texture = load(texture_path)
		# print("Selected bullet hole texture ", random_index + 1, ": ", texture_path)
	else:
		print("ERROR: No bullet hole textures found!")

func set_hole_position(pos: Vector2):
	"""Set the local position of the bullet hole relative to parent"""
	position = pos
	if not DEBUG_DISABLED:
		print("Bullet hole positioned at local: ", pos)
