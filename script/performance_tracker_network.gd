extends Node

# Performance optimization
const DEBUG_LOGGING = true  # Set to true for verbose debugging

# Performance tracking variables
var last_shot_time_usec = 0  # Changed to microseconds for better precision
var fastest_time_diff = 999.0  # Initialize with a large value
var first_shot = true  # Track if this is the first shot of the drill
var minimum_shot_interval = 0.01  # 10ms minimum realistic shot interval

func _ready():
	pass

func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float = 0.0):
	print("PERFORMANCE TRACKER NETWORK: _on_target_hit called with:", target_type, hit_position, hit_area, rotation_angle)
	var current_time_usec = Time.get_ticks_usec()  # Use microsecond precision
	var time_diff = 0.0  # Initialize to 0
	
	if first_shot:
		# First shot of the drill - calculate time from drill start (reset_shot_timer)
		time_diff = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		first_shot = false
		
		# Update fastest time if this first shot is realistic
		if time_diff >= minimum_shot_interval and time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if DEBUG_LOGGING:
			print("PERFORMANCE TRACKER NETWORK: First shot at time:", current_time_usec, ", time from drill start:", time_diff, "seconds")
	else:
		# Subsequent shots - calculate interval with microsecond precision
		time_diff = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		
		# Apply minimum time threshold to prevent unrealistic 0.0s intervals
		if time_diff < minimum_shot_interval:
			if DEBUG_LOGGING:
				print("PERFORMANCE TRACKER NETWORK: Shot interval too fast (", time_diff, "s), clamping to minimum (", minimum_shot_interval, "s)")
			time_diff = minimum_shot_interval
		
		# Update fastest time if this is faster (but still realistic)
		if time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if DEBUG_LOGGING:
			print("PERFORMANCE TRACKER NETWORK: Shot interval:", time_diff, "seconds, fastest:", fastest_time_diff)
	
	# Update last shot time for next calculation
	last_shot_time_usec = current_time_usec
	
	var record = {
		"target_type": target_type,
		"time_diff": time_diff,
		"hit_position": {"x": hit_position.x, "y": hit_position.y},
		"hit_area": hit_area,
		"rotation_angle": rotation_angle
	}
	
	# Send to websocket server
	_send_to_websocket(record)
	
	if DEBUG_LOGGING:
		print("Performance record sent: ", record)

# Send message to websocket server
func _send_to_websocket(record: Dictionary):
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and ws_listener.socket and ws_listener.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var content = {"command": "shot"}
		content.merge(record, true)  # Merge record into content
		var message = {
			"type": "netlink",
			"action": "forward",
			"device": "B",
			"content": content
		}
		var json_string = JSON.stringify(message)
		var err = ws_listener.socket.send_text(json_string)
		if err != OK:
			if DEBUG_LOGGING:
				print("Failed to send websocket message: ", err)
		else:
			if DEBUG_LOGGING:
				print("Sent websocket message: ", json_string)
	else:
		if DEBUG_LOGGING:
			print("WebSocket not available for sending")

# Get the fastest time difference recorded
func get_fastest_time_diff() -> float:
	return fastest_time_diff

# Reset the fastest time for a new drill
func reset_fastest_time():
	fastest_time_diff = 999.0

# Reset the shot timer for accurate first shot measurement
func reset_shot_timer():
	last_shot_time_usec = Time.get_ticks_usec()  # Use microsecond precision
	first_shot = true  # Reset first shot flag for new drill
