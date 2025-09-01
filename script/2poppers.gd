extends Node2D

signal target_hit(popper_id: String, zone: String, points: int)
signal target_disappeared(popper_id: String)

var poppers_hit = []

func _ready():
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
			print("Set popper_id for ", child.name, " to: ", child.popper_id)

func connect_popper_signals():
	"""Connect to signals from all popper children"""
	print("=== CONNECTING TO POPPER SIGNALS ===")
	
	for child in get_children():
		if child.has_signal("target_hit") and child.has_signal("target_disappeared"):
			print("Connecting to popper: ", child.name)
			# Use a lambda/callable to pass the popper_id
			child.target_hit.connect(func(zone: String, points: int): _on_popper_hit(child.name, zone, points))
			child.target_disappeared.connect(func(): _on_popper_disappeared(child.name))
		else:
			print("Child ", child.name, " doesn't have expected signals")

func _on_popper_hit(popper_id: String, zone: String, points: int):
	"""Handle when a popper is hit"""
	print("=== POPPER HIT IN 2POPPERS ===")
	print("Popper ID: ", popper_id, " Zone: ", zone, " Points: ", points)
	
	# Track which poppers have been hit
	if popper_id not in poppers_hit:
		poppers_hit.append(popper_id)
	
	# Emit the signal up to the drills manager
	target_hit.emit(popper_id, zone, points)

func _on_popper_disappeared(popper_id: String):
	"""Handle when a popper disappears"""
	print("=== POPPER DISAPPEARED IN 2POPPERS ===")
	print("Popper ID: ", popper_id)
	
	# Check if all poppers have been hit
	if poppers_hit.size() >= 2:  # All 2 poppers hit
		print("All poppers have been hit - emitting target_disappeared")
		target_disappeared.emit("2poppers")
	else:
		print("Only ", poppers_hit.size(), " poppers hit so far")
