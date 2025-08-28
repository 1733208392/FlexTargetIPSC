extends Area2D

var last_click_frame = -1

func _ready():
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)

func _on_input_event(_viewport, event, _shape_idx):
	# Check if it's a left mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Get the click position in local coordinates
		var local_pos = to_local(event.global_position)
		
		# Check zones in priority order (highest score first)
		# A-Zone has highest priority (5 points)
		if is_point_in_zone("AZone", local_pos):
			print("Zone A clicked - 5 points!")
			return
		
		# C-Zone has medium priority (3 points)
		if is_point_in_zone("CZone", local_pos):
			print("Zone C clicked - 3 points!")
			return
		
		# D-Zone has lowest priority (1 point)
		if is_point_in_zone("DZone", local_pos):
			print("Zone D clicked - 1 point!")
			return
		
		print("Clicked outside target zones")

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
	return false
