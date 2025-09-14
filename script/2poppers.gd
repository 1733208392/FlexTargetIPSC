extends Node2D

# ===== PERFORMANCE OPTIMIZATIONS =====
# 1. Conditional debug logging to reduce print overhead during rapid firing
# 2. Dictionary-based tracking for O(1) lookup instead of Array linear search
# 3. Minimal essential logging only for errors
# =======================================

signal target_hit(popper_id: String, zone: String, points: int, hit_position: Vector2)
signal target_disappeared(popper_id: String)

# Performance optimizations
const DEBUG_LOGGING = false  # Set to true for verbose debugging
var poppers_hit = {}  # Use Dictionary for O(1) lookup instead of Array

func _ready():
	if DEBUG_LOGGING:
		print("=== 2POPPERS READY ===")
	# Set popper IDs for each child
	set_popper_ids()
	# Connect to all popper signals
	connect_popper_signals()

func set_popper_ids():
	"""Set unique IDs for each popper child"""
	for child in get_children():
		if child.has_method("set"):  # Check if it's a node that can have properties set
			child.popper_id = child.name
			if DEBUG_LOGGING:
				print("Set popper_id for ", child.name, " to: ", child.popper_id)

func connect_popper_signals():
	"""Connect to signals from all popper children"""
	if DEBUG_LOGGING:
		print("=== CONNECTING TO POPPER SIGNALS ===")
	
	for child in get_children():
		if child.has_signal("target_hit") and child.has_signal("target_disappeared"):
			if DEBUG_LOGGING:
				print("Connecting to popper: ", child.name)
			# Use a lambda/callable to pass the popper_id
			child.target_hit.connect(func(zone: String, points: int, hit_position: Vector2): _on_popper_hit(child.name, zone, points, hit_position))
			child.target_disappeared.connect(func(): _on_popper_disappeared(child.name))
		else:
			print("Child ", child.name, " doesn't have expected signals")  # Keep this as it indicates a setup error

func _on_popper_hit(popper_id: String, zone: String, points: int, hit_position: Vector2):
	"""Handle when a popper is hit - optimized for performance"""
	if DEBUG_LOGGING:
		print("=== POPPER HIT IN 2POPPERS ===")
		print("Popper ID: ", popper_id, " Zone: ", zone, " Points: ", points, " Position: ", hit_position)
	
	# Track which poppers have been hit using O(1) Dictionary lookup
	if not poppers_hit.has(popper_id):
		poppers_hit[popper_id] = true
		if DEBUG_LOGGING:
			print("Marked popper ", popper_id, " as hit (total hit: ", poppers_hit.size(), ")")
	
	# Emit the signal up to the drills manager
	target_hit.emit(popper_id, zone, points, hit_position)

func _on_popper_disappeared(popper_id: String):
	"""Handle when a popper disappears - optimized for performance"""
	if DEBUG_LOGGING:
		print("=== POPPER DISAPPEARED IN 2POPPERS ===")
		print("Popper ID: ", popper_id)
	
	# Check if all poppers have been hit using Dictionary size
	if poppers_hit.size() >= 2:  # All 2 poppers hit
		if DEBUG_LOGGING:
			print("All poppers have been hit - emitting target_disappeared")
		target_disappeared.emit("2poppers")
	else:
		if DEBUG_LOGGING:
			print("Only ", poppers_hit.size(), " poppers hit so far")
