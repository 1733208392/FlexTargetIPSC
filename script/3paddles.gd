extends Node2D

# ===== PERFORMANCE OPTIMIZATIONS =====
# 1. Conditional debug logging to reduce print overhead during rapid firing
# 2. Dictionary-based tracking for O(1) lookup instead of Array linear search
# 3. Minimal essential logging only for errors
# =======================================

signal target_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2)
signal target_disappeared(paddle_id: String)

# Performance optimizations
const DEBUG_LOGGING = false  # Set to true for verbose debugging
var paddles_hit = {}  # Use Dictionary for O(1) lookup instead of Array

func _ready():
	if DEBUG_LOGGING:
		print("=== 3PADDLES READY ===")
	# Connect to all paddle signals
	connect_paddle_signals()

func connect_paddle_signals():
	"""Connect to signals from all paddle children"""
	if DEBUG_LOGGING:
		print("=== CONNECTING TO PADDLE SIGNALS ===")
	
	for child in get_children():
		if child.has_signal("target_hit") and child.has_signal("target_disappeared"):
			if DEBUG_LOGGING:
				print("Connecting to paddle: ", child.name)
			child.target_hit.connect(_on_paddle_hit)
			child.target_disappeared.connect(_on_paddle_disappeared)
		else:
			print("Child ", child.name, " doesn't have expected signals")  # Keep this as it indicates a setup error

func _on_paddle_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2):
	"""Handle when a paddle is hit - optimized for performance"""
	if DEBUG_LOGGING:
		print("=== PADDLE HIT IN 3PADDLES ===")
		print("Paddle ID: ", paddle_id, " Zone: ", zone, " Points: ", points, " Position: ", hit_position)
	
	# Track which paddles have been hit using O(1) Dictionary lookup
	if not paddles_hit.has(paddle_id):
		paddles_hit[paddle_id] = true
		if DEBUG_LOGGING:
			print("Marked paddle ", paddle_id, " as hit (total hit: ", paddles_hit.size(), ")")
	
	# Emit the signal up to the drills manager
	target_hit.emit(paddle_id, zone, points, hit_position)

func _on_paddle_disappeared(paddle_id: String):
	"""Handle when a paddle disappears - optimized for performance"""
	if DEBUG_LOGGING:
		print("=== PADDLE DISAPPEARED IN 3PADDLES ===")
		print("Paddle ID: ", paddle_id)
	
	# Check if all paddles have been hit using Dictionary size
	if paddles_hit.size() >= 3:  # All 3 paddles hit
		if DEBUG_LOGGING:
			print("All paddles have been hit - emitting target_disappeared")
		target_disappeared.emit("3paddles")
	else:
		if DEBUG_LOGGING:
			print("Only ", paddles_hit.size(), " paddles hit so far")
