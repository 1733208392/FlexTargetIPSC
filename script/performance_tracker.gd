extends Node

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

# Scoring rules are now loaded dynamically from settings_dict.target_rule

# Performance tracking variables
var records = []
var last_shot_time = 0
var fastest_time_diff = 999.0  # Initialize with a large value
var first_shot = true  # Track if this is the first shot of the drill
var total_elapsed_time = 0.0  # Store the total elapsed time for the drill
var pending_drill_data = null

func _ready():
	pass

func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float = 0.0):
	var current_time = Time.get_ticks_msec()
	var time_diff = 0.0  # Initialize to 0 for first shot
	
	if first_shot:
		# First shot of the drill - just record the time, don't calculate interval
		last_shot_time = current_time
		first_shot = false
		if DEBUG_LOGGING:
			print("PERFORMANCE TRACKER: First shot recorded at time:", current_time)
	else:
		# Subsequent shots - calculate interval
		time_diff = (current_time - last_shot_time) / 1000.0  # in seconds
		last_shot_time = current_time
		
		# Update fastest time if this is faster
		if time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if DEBUG_LOGGING:
			print("PERFORMANCE TRACKER: Shot interval:", time_diff, "seconds, fastest:", fastest_time_diff)
	
	# Get score from settings_dict.target_rule
	var score = _get_score_for_hit_area(hit_area)
	
	var record = {
		"target_type": target_type,
		"time_diff": time_diff,
		"hit_position": {"x": hit_position.x, "y": hit_position.y},
		"hit_area": hit_area,
		"score": score,
		"rotation_angle": rotation_angle
	}
	
	records.append(record)
	if DEBUG_LOGGING:
		print("Performance record added: ", record)

# Signal handler for drills finished
func _on_drills_finished():
	if records.size() == 0:
		return
	
	if DEBUG_LOGGING:
		print("Performance records for this drill: ", records)
	
	# Create the summary data
	var fastest_value = null
	if fastest_time_diff < 999.0:
		fastest_value = fastest_time_diff
	
	var drill_summary = {
		"total_elapsed_time": total_elapsed_time,
		"fastest_shot_interval": fastest_value,
		"total_shots": records.size(),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Create the final data structure
	var drill_data = {
		"drill_summary": drill_summary,
		"records": records.duplicate()  # Copy the records array
	}
	
	pending_drill_data = drill_data
	
	# Store latest performance data in GlobalData for immediate access
	var global_data = get_node("/root/GlobalData")
	if global_data:
		global_data.latest_performance_data = drill_data.duplicate()
		if DEBUG_LOGGING:
			print("[PerformanceTracker] Stored latest performance data in GlobalData")
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		var json_string = JSON.stringify(pending_drill_data)
		# Implement circular buffer: cycle through indices 1-20
		var current_index = int(global_data.settings_dict.get("max_index", 0)) if global_data else 0
		var next_index = (current_index % 20) + 1  # Circular buffer: 1-20
		var data_id = "performance_" + str(next_index)
		if DEBUG_LOGGING:
			print("[PerformanceTracker] Saving drill data to file: ", data_id, " (previous index: ", current_index, ", next index: ", next_index, ")")
		http_service.save_game(_on_performance_saved, data_id, json_string)
	else:
		if DEBUG_LOGGING:
			print("HttpService not found")

# Get the fastest time difference recorded
func get_fastest_time_diff() -> float:
	return fastest_time_diff

# Get score for hit area from settings_dict.target_rule
func _get_score_for_hit_area(hit_area: String) -> int:
	var global_data = get_node("/root/GlobalData")
	if global_data and global_data.settings_dict.has("target_rule"):
		var target_rule = global_data.settings_dict["target_rule"]
		# Handle case variations and mappings
		var area_key = hit_area
		if hit_area == "Miss":
			area_key = "miss"
		elif hit_area == "Paddle":
			area_key = "paddles"
		elif hit_area == "Popper":
			area_key = "popper"
		
		if target_rule.has(area_key):
			return int(target_rule[area_key])
	
	# Default fallback scores if settings not available
	var fallback_scores = {
		"AZone": 5,
		"CZone": 3,
		"Miss": 0,
		"WhiteZone": -5,
		"Paddle": 2,
		"Popper": 2
	}
	return fallback_scores.get(hit_area, 0)

# Reset the fastest time for a new drill
func reset_fastest_time():
	fastest_time_diff = 999.0

# Reset the shot timer for accurate first shot measurement
func reset_shot_timer():
	last_shot_time = Time.get_ticks_msec()

# Set the total elapsed time for the drill
func set_total_elapsed_time(time_seconds: float):
	total_elapsed_time = time_seconds
	if DEBUG_LOGGING:
		print("PERFORMANCE TRACKER: Total elapsed time set to:", total_elapsed_time, "seconds")

func _on_settings_saved(result, response_code, headers, body):
	if response_code == 200:
		if DEBUG_LOGGING:
			print("Settings saved")
		var fastest_display = "N/A"
		if fastest_time_diff < 999.0:
			fastest_display = "%.2f" % fastest_time_diff
		if DEBUG_LOGGING:
			print("Drill summary - Total time:", total_elapsed_time, "seconds, Fastest shot:", fastest_display)
		records.clear()
		pending_drill_data = null
	else:
		if DEBUG_LOGGING:
			print("Failed to save settings")

func _on_performance_saved(result, response_code, headers, body):
	if response_code == 200:
		if DEBUG_LOGGING:
			print("Performance data saved")
		var http_service = get_node("/root/HttpService")
		if http_service:
			# Update max_index with circular buffer logic: cycle 1-20
			var current_index = int(GlobalData.settings_dict.get("max_index", 0))
			var next_index = (current_index % 20) + 1
			GlobalData.settings_dict["max_index"] = next_index
			if DEBUG_LOGGING:
				print("[PerformanceTracker] Updated max_index from ", current_index, " to ", next_index, " (circular buffer 1-20)")
			# Preserve all existing settings, only update max_index
			var settings_json = JSON.stringify(GlobalData.settings_dict)
			http_service.save_game(_on_settings_saved, "settings", settings_json)
		else:
			if DEBUG_LOGGING:
				print("HttpService not found")
	else:
		if DEBUG_LOGGING:
			print("Failed to save performance data")
