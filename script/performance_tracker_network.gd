extends Node

# Performance optimization
const DEBUG_DISABLED = true  # Set to false for production release

# Target types with variable position/rotation (only these targets include rot and tgt_pos fields)
const VARIABLE_POSITION_TARGETS = ["rotation"]

func _ready():
	pass

func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float, repeat: int, target_position: Vector2, t: int = 0):
	print("PERFORMANCE TRACKER NETWORK: _on_target_hit called with:", target_type, hit_position, hit_area, rotation_angle, repeat, target_position, "t=", t)
	
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
		"std": "%.2f" % 0.0  # Placeholder for shot_timer_delay
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
