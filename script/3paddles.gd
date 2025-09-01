extends Node2D

signal target_hit(paddle_id: String, zone: String, points: int)
signal target_disappeared(paddle_id: String)

var paddles_hit = []

func _ready():
	print("=== 3PADDLES READY ===")
	# Connect to all paddle signals
	connect_paddle_signals()

func connect_paddle_signals():
	"""Connect to signals from all paddle children"""
	print("=== CONNECTING TO PADDLE SIGNALS ===")
	
	for child in get_children():
		if child.has_signal("target_hit") and child.has_signal("target_disappeared"):
			print("Connecting to paddle: ", child.name)
			child.target_hit.connect(_on_paddle_hit)
			child.target_disappeared.connect(_on_paddle_disappeared)
		else:
			print("Child ", child.name, " doesn't have expected signals")

func _on_paddle_hit(paddle_id: String, zone: String, points: int):
	"""Handle when a paddle is hit"""
	print("=== PADDLE HIT IN 3PADDLES ===")
	print("Paddle ID: ", paddle_id, " Zone: ", zone, " Points: ", points)
	
	# Track which paddles have been hit
	if paddle_id not in paddles_hit:
		paddles_hit.append(paddle_id)
	
	# Emit the signal up to the drills manager
	target_hit.emit(paddle_id, zone, points)

func _on_paddle_disappeared(paddle_id: String):
	"""Handle when a paddle disappears"""
	print("=== PADDLE DISAPPEARED IN 3PADDLES ===")
	print("Paddle ID: ", paddle_id)
	
	# Check if all paddles have been hit
	if paddles_hit.size() >= 3:  # All 3 paddles hit
		print("All paddles have been hit - emitting target_disappeared")
		target_disappeared.emit("3paddles")
	else:
		print("Only ", paddles_hit.size(), " paddles hit so far")
