extends Node2D

var block_mini_events = false
var last_click_frame = -1

func _ready():
	# Connect to white target FIRST (higher priority)
	var ipsc_white = $IPSCWhite
	if ipsc_white:
		ipsc_white.input_event.connect(_on_white_target_clicked)
	
	# Connect to mini target SECOND (lower priority)
	var ipsc_mini = $IPSCMini  
	if ipsc_mini:
		ipsc_mini.input_event.connect(_on_mini_target_clicked)

func _on_white_target_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		var ipsc_white = $IPSCWhite
		var local_pos = ipsc_white.to_local(event.global_position)
		
		# Check if click is in D-zone of white target
		if is_point_in_zone(ipsc_white, "DZone", local_pos):
			print("HOSTAGE SHOT! Mission failed!")
			block_mini_events = true
			return
		
		# Any other click on white target is also hostage shot
		print("HOSTAGE SHOT! Mission failed!")
		block_mini_events = true  # Block mini target after ANY white target hit

func _on_mini_target_clicked(_viewport, event, _shape_idx):
	# Block all mini target events if white target was hit
	if block_mini_events:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Check if this click would also hit the white target (overlap area)
		var ipsc_white = $IPSCWhite
		if ipsc_white:
			var white_local_pos = ipsc_white.to_local(event.global_position)
			if (is_point_in_zone(ipsc_white, "DZone", white_local_pos) or is_point_in_zone(ipsc_white, "CZone", white_local_pos) or is_point_in_zone(ipsc_white, "AZone", white_local_pos)):
				# This click would hit the white target, so ignore it for mini target
				return
		
		var ipsc_mini = $IPSCMini
		var local_pos = ipsc_mini.to_local(event.global_position)
		
		# Check zones in priority order
		if is_point_in_zone(ipsc_mini, "AZone", local_pos):
			print("Target eliminated - Zone A hit! (5 points)")
		elif is_point_in_zone(ipsc_mini, "CZone", local_pos):
			print("Target eliminated - Zone C hit! (3 points)")
		elif is_point_in_zone(ipsc_mini, "DZone", local_pos):
			print("Target hit - Zone D! (1 point)")

func is_point_in_zone(target_node: Node, zone_name: String, point: Vector2) -> bool:
	var zone_node = target_node.get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
	return false
