extends Node

# Performance optimization
const DEBUG_DISABLED = true  # Set to false for production release

# Target types with variable position/rotation (only these targets include rot and tgt_pos fields)
const VARIABLE_POSITION_TARGETS = ["rotation"]

# Performance tracking variables
var last_shot_time_usec = 0  # Changed to microseconds for better precision
var fastest_time_diff = 999.0  # Initialize with a large value
var first_shot = true  # Track if this is the first shot of the drill
var minimum_shot_interval = 0.01  # 10ms minimum realistic shot interval
var shot_timer_delay = 0.0  # Store the shot timer delay duration

func _ready():
	pass

func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float, repeat: int, target_position: Vector2, t: int = 0):
	print("PERFORMANCE TRACKER NETWORK: _on_target_hit called with:", target_type, hit_position, hit_area, rotation_angle, repeat, target_position, "t=", t)
	var current_time_usec = Time.get_ticks_usec()  # Use microsecond precision
	var time_diff = 0.0  # Initialize to 0
	
	if first_shot:
		# First shot of the drill - calculate time from drill start (reset_shot_timer)
		var total_time = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		# Subtract shot timer delay to get actual reaction time after beep
		time_diff = total_time - shot_timer_delay
		# Ensure time_diff is not negative (in case of very fast reaction)
		if time_diff < 0:
			time_diff = 0.0
		first_shot = false
		
		# Update fastest time if this first shot is realistic (using the adjusted reaction time)
		if time_diff >= minimum_shot_interval and time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if not DEBUG_DISABLED:
			print("PERFORMANCE TRACKER NETWORK: First shot - total time:", total_time, "s, shot timer delay:", shot_timer_delay, "s, reaction time:", time_diff, "s")
	else:
		# Subsequent shots - calculate interval with microsecond precision
		time_diff = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		
		# Apply minimum time threshold to prevent unrealistic 0.0s intervals
		if time_diff < minimum_shot_interval:
			if not DEBUG_DISABLED:
				print("PERFORMANCE TRACKER NETWORK: Shot interval too fast (", time_diff, "s), clamping to minimum (", minimum_shot_interval, "s)")
			time_diff = minimum_shot_interval
		
		# Update fastest time if this is faster (but still realistic)
		if time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if not DEBUG_DISABLED:
			print("PERFORMANCE TRACKER NETWORK: Shot interval:", time_diff, "seconds, fastest:", fastest_time_diff)
	
	# Update last shot time for next calculation
	last_shot_time_usec = current_time_usec
	
	# Build record with abbreviated keys and conditional fields
	# Abbreviations: cmd=command, tt=target_type, t=sensor_time_seconds, hp=hit_position, 
	#                ha=hit_area, rot=rotation_angle, std=shot_timer_delay, 
	#                tgt_pos=targetPos, rep=repeat
	var record = {
		"cmd": "shot",
		"tt": target_type,
		"td": round((t / 1000.0) * 100.0) / 100.0,  # Convert sensor time from milliseconds to seconds, rounded to 2 decimals
		"hp": {"x": "%.1f" % hit_position.x, "y": "%.1f" % hit_position.y},
		"ha": hit_area,
		"rep": repeat,
		"std": "%.2f" % shot_timer_delay
	}
	
	# Only include rotation and target position for variable-position targets (e.g., rotation targets)
	if target_type in VARIABLE_POSITION_TARGETS:
		record["rot"] = "%.2f" % rotation_angle
		record["tgt_pos"] = {"x": "%.1f" % target_position.x, "y": "%.1f" % target_position.y}
	
	# Send to websocket server
	_send_to_app(record)
	
	if not DEBUG_DISABLED:
		print("Performance record sent: ", record)

# Send message to websocket server
func _send_to_app(record: Dictionary):
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:		
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if not DEBUG_DISABLED:
					print("Successfully sent performance data via HTTP")
			else:
				if not DEBUG_DISABLED:
					print("Failed to send performance data via HTTP: ", result, response_code)
		, record)
	else:
		if not DEBUG_DISABLED:
			print("HttpService not available for sending")

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

# Set the shot timer delay
func set_shot_timer_delay(delay: float):
	shot_timer_delay = round(delay * 100.0) / 100.0  # Ensure 2 decimal precision
	if not DEBUG_DISABLED:
		print("PERFORMANCE TRACKER NETWORK: Shot timer delay set to:", shot_timer_delay, "seconds")
