extends Node2D

# Signals for score and performance tracking  
signal target_hit(popper_id: String, zone: String, points: int, hit_position: Vector2)
signal target_disappeared(popper_id: String)

# WebSocket connection
var websocket_listener = null

# Bullet impact scene
const BulletImpactScene = preload("res://scene/bullet_impact.tscn")
# Note: BulletHoleScene removed - poppers are steel targets and don't create bullet holes

# Popper references
@onready var popper1_area = $Popper1Area
@onready var popper2_area = $Popper2Area
@onready var popper1_simple = $Popper1Area/Popper1_simple
@onready var popper2_simple = $Popper2Area/Popper2_simple

# Track which poppers have been hit
var popper1_hit = false
var popper2_hit = false

# Debug tracking
var hit_counter = 0
var drill_active: bool = false  # Flag to ignore shots before drill starts

# Track total poppers for target_disappeared signal
var total_poppers = 2
var poppers_disappeared = []

# Note: bullet_holes array removed - poppers are steel targets and don't create bullet holes

# Points per hit
const POPPER_POINTS = 5

func _ready():
	print("=== 2POPPERS_SIMPLE READY ===")
	
	# Debug: Check if all nodes are properly loaded
	print("2POPPERS_SIMPLE: Node validation:")
	print("  - popper1_simple: ", popper1_simple)
	print("  - popper2_simple: ", popper2_simple) 
	print("  - popper1_area: ", popper1_area)
	print("  - popper2_area: ", popper2_area)
	
	# Defer initialization to ensure all nodes are fully ready
	call_deferred("initialize_scene")

func initialize_scene():
	"""Initialize the scene after all nodes are ready"""
	print("2POPPERS_SIMPLE: Initializing scene...")
	
	# Connect to WebSocket for bullet shots
	connect_websocket()
	
	# Connect to popper disappeared signals
	connect_popper_signals()
	
	print("2POPPERS_SIMPLE: Scene initialization complete")

func validate_nodes() -> bool:
	"""Validate that all required nodes are loaded and not null"""
	if not popper1_simple:
		print("2POPPERS_SIMPLE: ERROR - popper1_simple is null")
		return false
	if not popper2_simple:
		print("2POPPERS_SIMPLE: ERROR - popper2_simple is null")
		return false
	if not popper1_area:
		print("2POPPERS_SIMPLE: ERROR - popper1_area is null")
		return false
	if not popper2_area:
		print("2POPPERS_SIMPLE: ERROR - popper2_area is null")
		return false
	return true

func connect_websocket():
	"""Connect to WebSocket to receive bullet shot positions"""
	websocket_listener = get_node_or_null("/root/WebSocketListener")
	if websocket_listener:
		# Check if already connected to avoid duplicate connections
		if not websocket_listener.bullet_hit.is_connected(_on_websocket_bullet_hit):
			websocket_listener.bullet_hit.connect(_on_websocket_bullet_hit)
			print("2POPPERS_SIMPLE: Connected to WebSocket for bullet hits")
		else:
			print("2POPPERS_SIMPLE: Already connected to WebSocket")
	else:
		print("2POPPERS_SIMPLE ERROR: Could not find WebSocketListener")

func connect_popper_signals():
	"""Connect to popper disappeared signals"""
	if popper1_simple:
		popper1_simple.popper_disappeared.connect(func(): _on_popper_disappeared("Popper1"))
		print("2POPPERS_SIMPLE: Connected to Popper1_simple signal")
	else:
		print("2POPPERS_SIMPLE ERROR: popper1_simple is null!")
		
	if popper2_simple:
		popper2_simple.popper_disappeared.connect(func(): _on_popper_disappeared("Popper2"))
		print("2POPPERS_SIMPLE: Connected to Popper2_simple signal")
	else:
		print("2POPPERS_SIMPLE ERROR: popper2_simple is null!")

func _on_websocket_bullet_hit(world_pos: Vector2):
	"""Handle bullet hits from WebSocket - check which area was hit"""
	
	# Ignore shots if drill is not active yet
	if not drill_active:
		print("2POPPERS_SIMPLE: Ignoring shot because drill is not active yet")
		return
	
	# Validate all nodes are ready before processing
	if not validate_nodes():
		print("2POPPERS_SIMPLE: ERROR - Nodes not ready, skipping WebSocket hit")
		return
		
	hit_counter += 1
	print("2POPPERS_SIMPLE: ========== WebSocket Hit Test #", hit_counter, " ==========")
	print("2POPPERS_SIMPLE: Received bullet hit at: ", world_pos)
	print("2POPPERS_SIMPLE: Current state - Popper1_hit: ", popper1_hit, ", Popper2_hit: ", popper2_hit)
	
	# Convert world position to local position for hit detection
	var local_pos = to_local(world_pos)
	print("2POPPERS_SIMPLE: Local position: ", local_pos)
	
	# Test each area individually
	var hit_popper1 = is_point_in_area(world_pos, popper1_area)
	var hit_popper2 = is_point_in_area(world_pos, popper2_area)
	
	print("2POPPERS_SIMPLE: Area test results:")
	print("  - Popper1Area hit: ", hit_popper1)
	print("  - Popper2Area hit: ", hit_popper2)
	
	# Print area positions for reference
	print("2POPPERS_SIMPLE: Area positions:")
	if popper1_area:
		print("  - Popper1Area at: ", popper1_area.global_position)
	else:
		print("  - Popper1Area: NULL!")
	if popper2_area:
		print("  - Popper2Area at: ", popper2_area.global_position)
	else:
		print("  - Popper2Area: NULL!")
	
	# Print popper positions for reference
	print("2POPPERS_SIMPLE: Popper positions:")
	if popper1_simple:
		print("  - Popper1_simple at: ", popper1_simple.global_position)
	else:
		print("  - Popper1_simple: NULL!")
	if popper2_simple:
		print("  - Popper2_simple at: ", popper2_simple.global_position)
	else:
		print("  - Popper2_simple: NULL!")
	
	print("2POPPERS_SIMPLE: ================================================")
	
	# Check which area was hit - prioritize closer hits and prevent double hits
	var should_hit_popper1 = hit_popper1 and not popper1_hit
	var should_hit_popper2 = hit_popper2 and not popper2_hit
	
	# Create bullet impact visual effect - only consider it a hit if the target hasn't fallen
	var is_hit = should_hit_popper1 or should_hit_popper2
	create_bullet_impact(world_pos, is_hit)
	
	print("2POPPERS_SIMPLE: Hit tests - Popper1: ", should_hit_popper1, ", Popper2: ", should_hit_popper2)
	
	# Only trigger one popper per hit, prioritize based on distance if both are hit
	if should_hit_popper1 and should_hit_popper2:
		# If both areas are hit, choose the closer one
		if popper1_simple and popper2_simple:
			var dist1 = world_pos.distance_to(popper1_simple.global_position)
			var dist2 = world_pos.distance_to(popper2_simple.global_position)
			print("2POPPERS_SIMPLE: Both areas hit, distances - P1: ", dist1, ", P2: ", dist2)
			
			if dist1 <= dist2:
				print("2POPPERS_SIMPLE: ✅ Triggering Popper1 (closer) - FALL ANIMATION WILL START")
				trigger_popper1_hit(world_pos)
			else:
				print("2POPPERS_SIMPLE: ✅ Triggering Popper2 (closer) - FALL ANIMATION WILL START")
				trigger_popper2_hit(world_pos)
		else:
			print("2POPPERS_SIMPLE: ERROR - One or both poppers are null!")
	elif should_hit_popper1:
		print("2POPPERS_SIMPLE: ✅ Hit detected on Popper1Area only! - FALL ANIMATION WILL START")
		trigger_popper1_hit(world_pos)
	elif should_hit_popper2:
		print("2POPPERS_SIMPLE: ✅ Hit detected on Popper2Area only! - FALL ANIMATION WILL START")
		trigger_popper2_hit(world_pos)
	else:
		print("2POPPERS_SIMPLE: ⭕ No hit detected or poppers already fallen - NO ANIMATION")
		# Emit miss signal if no popper was hit and not already fallen
		if not (popper1_hit and popper2_hit):
			print("2POPPERS_SIMPLE: 🎯 MISS - Emitting miss signal")
			target_hit.emit("miss", "Miss", 0, world_pos)  # 0 points for miss (performance tracker will score from settings)

func is_point_in_area(world_pos: Vector2, area: Area2D) -> bool:
	"""Check if a world position is inside an Area2D"""
	if not area:
		print("2POPPERS_SIMPLE: Area is null")
		return false
		
	print("2POPPERS_SIMPLE: Testing point ", world_pos, " against area at ", area.global_position)
		
	# Get all collision shapes in the area
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			# Convert world position to area's local coordinate system
			var area_local_pos = area.to_local(world_pos)
			print("2POPPERS_SIMPLE: Area local pos: ", area_local_pos)
			
			if child is CollisionPolygon2D:
				var polygon = child.polygon
				if polygon.size() > 0:
					# Convert world position to collision polygon's local coordinate system
					var collision_local_pos = child.to_local(area.to_global(area_local_pos))
					print("2POPPERS_SIMPLE: Testing polygon collision at: ", collision_local_pos)
					# Use Godot's built-in point-in-polygon test (same as popper.gd)
					var result = Geometry2D.is_point_in_polygon(collision_local_pos, polygon)
					print("2POPPERS_SIMPLE: Polygon test result: ", result)
					if result:
						return true
	
	return false

func trigger_popper1_hit(hit_position: Vector2):
	"""Trigger Popper1 animation and scoring"""
	if popper1_hit:
		print("2POPPERS_SIMPLE: Popper1 already hit, ignoring")
		return  # Already hit
		
	print("2POPPERS_SIMPLE: 🎯 TRIGGERING POPPER1 HIT")
	popper1_hit = true
	
	# Note: clear_bullet_holes() removed - poppers don't create bullet holes
	
	# Trigger the animation on popper_simple
	if popper1_simple and popper1_simple.has_method("trigger_fall_animation"):
		print("2POPPERS_SIMPLE: 🎬 Calling trigger_fall_animation() on Popper1_simple")
		popper1_simple.trigger_fall_animation()
		print("2POPPERS_SIMPLE: ✅ Popper1 fall animation triggered successfully")
	else:
		print("2POPPERS_SIMPLE: ❌ ERROR - Popper1_simple not found or missing method")
	
	# Emit scoring signal
	target_hit.emit("Popper1", "PopperZone", POPPER_POINTS, hit_position)
	print("2POPPERS_SIMPLE: 📊 Scored ", POPPER_POINTS, " points for Popper1 hit")

func trigger_popper2_hit(hit_position: Vector2):
	"""Trigger Popper2 animation and scoring"""
	if popper2_hit:
		print("2POPPERS_SIMPLE: Popper2 already hit, ignoring")
		return  # Already hit
		
	print("2POPPERS_SIMPLE: 🎯 TRIGGERING POPPER2 HIT")
	popper2_hit = true
	
	# Note: clear_bullet_holes() removed - poppers don't create bullet holes
	
	# Trigger the animation on popper_simple
	if popper2_simple and popper2_simple.has_method("trigger_fall_animation"):
		print("2POPPERS_SIMPLE: 🎬 Calling trigger_fall_animation() on Popper2_simple")
		popper2_simple.trigger_fall_animation()
		print("2POPPERS_SIMPLE: ✅ Popper2 fall animation triggered successfully")
	else:
		print("2POPPERS_SIMPLE: ❌ ERROR - Popper2_simple not found or missing method")
	
	# Emit scoring signal
	target_hit.emit("Popper2", "PopperZone", POPPER_POINTS, hit_position)
	print("2POPPERS_SIMPLE: 📊 Scored ", POPPER_POINTS, " points for Popper2 hit")

func _on_popper_disappeared(popper_id: String):
	"""Handle when a popper disappears after animation"""
	print("2POPPERS_SIMPLE: ", popper_id, " disappeared")
	
	# Track which poppers have disappeared
	if popper_id not in poppers_disappeared:
		poppers_disappeared.append(popper_id)
		print("2POPPERS_SIMPLE: ", poppers_disappeared.size(), "/", total_poppers, " poppers disappeared")
		
		# Only emit target_disappeared when ALL poppers have disappeared
		if poppers_disappeared.size() >= total_poppers:
			print("2POPPERS_SIMPLE: ✅ All poppers disappeared - emitting target_disappeared")
			target_disappeared.emit("2poppers_simple")
		else:
			print("2POPPERS_SIMPLE: Waiting for remaining poppers to disappear")
	else:
		print("2POPPERS_SIMPLE: ", popper_id, " already marked as disappeared")

func reset_scene():
	"""Reset both poppers to their initial state"""
	print("2POPPERS_SIMPLE: Resetting scene")
	
	popper1_hit = false
	popper2_hit = false
	poppers_disappeared.clear()
	hit_counter = 0
	
	# Note: clear_bullet_holes() removed - poppers don't create bullet holes
	
	if popper1_simple:
		popper1_simple.reset_popper()
	if popper2_simple:
		popper2_simple.reset_popper()

func create_bullet_impact(world_pos: Vector2, is_hit: bool = false):
	"""Create bullet impact visual effects at the hit position"""
	print("2POPPERS_SIMPLE: Creating bullet impact at: ", world_pos, " (hit: ", is_hit, ")")
	
	# Always create bullet impact effect (visual)
	if BulletImpactScene:
		var impact = BulletImpactScene.instantiate()
		get_parent().add_child(impact)  # Add to parent so it's not affected by this node's transform
		impact.global_position = world_pos
		print("2POPPERS_SIMPLE: Bullet impact visual created")
	
	# Only play impact sound for hits (not misses)
	if is_hit:
		play_impact_sound_at_position(world_pos)
		print("2POPPERS_SIMPLE: Impact sound played for hit")
	else:
		print("2POPPERS_SIMPLE: No sound played for miss")
	
	# NO BULLET HOLES: Poppers are steel targets, don't create bullet holes
	print("2POPPERS_SIMPLE: No bullet hole created - steel target")

func play_impact_sound_at_position(world_pos: Vector2):
	"""Play steel impact sound effect at specific position"""
	# Load the metal impact sound for steel targets
	var impact_sound = preload("res://audio/metal_hit.WAV")
	
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
		print("2POPPERS_SIMPLE: Steel impact sound played at: ", world_pos)
	else:
		print("2POPPERS_SIMPLE: No impact sound found!")
