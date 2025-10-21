extends Node

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

# Scoring rules are now loaded dynamically from settings_dict.target_rule

# Performance tracking variables
var records = []
var last_shot_time_usec = 0  # Changed to microseconds for better precision
var fastest_time_diff = 999.0  # Initialize with a large value
var first_shot = true  # Track if this is the first shot of the drill
var total_elapsed_time = 0.0  # Store the total elapsed time for the drill
var pending_drill_data = null
var minimum_shot_interval = 0.01  # 10ms minimum realistic shot interval
var shot_timer_delay = 0.0  # Store the shot timer delay duration

func _ready():
	pass

func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float = 0.0):
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
		
		if DEBUG_LOGGING:
			print("PERFORMANCE TRACKER: First shot - total time:", total_time, "s, shot timer delay:", shot_timer_delay, "s, reaction time:", time_diff, "s")
	else:
		# Subsequent shots - calculate interval with microsecond precision
		time_diff = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		
		# Apply minimum time threshold to prevent unrealistic 0.0s intervals
		if time_diff < minimum_shot_interval:
			if DEBUG_LOGGING:
				print("PERFORMANCE TRACKER: Shot interval too fast (", time_diff, "s), clamping to minimum (", minimum_shot_interval, "s)")
			time_diff = minimum_shot_interval
		
		# Update fastest time if this is faster (but still realistic)
		if time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if DEBUG_LOGGING:
			print("PERFORMANCE TRACKER: Shot interval:", time_diff, "seconds, fastest:", fastest_time_diff)
	
	# Update last shot time for next calculation
	last_shot_time_usec = current_time_usec
	
	# Get score from settings_dict.target_rule
	var score = _get_score_for_hit_area(hit_area)
	
	var record = {
		"target_type": target_type,
		"time_diff": round(time_diff * 100.0) / 100.0,
		"hit_position": {"x": round(hit_position.x * 10.0) / 10.0, "y": round(hit_position.y * 10.0) / 10.0},
		"hit_area": hit_area,
		"score": score,
		"rotation_angle": rotation_angle,
		"shot_timer_delay": round(shot_timer_delay * 100.0) / 100.0
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
		"Paddle": 5,
		"Popper": 5
	}
	return fallback_scores.get(hit_area, 0)

# Reset the fastest time for a new drill
func reset_fastest_time():
	fastest_time_diff = 999.0

# Reset the shot timer for accurate first shot measurement
func reset_shot_timer():
	last_shot_time_usec = Time.get_ticks_usec()  # Use microsecond precision
	first_shot = true  # Reset first shot flag for new drill

# Set the total elapsed time for the drill
func set_total_elapsed_time(time_seconds: float):
	total_elapsed_time = time_seconds
	if DEBUG_LOGGING:
		print("PERFORMANCE TRACKER: Total elapsed time set to:", total_elapsed_time, "seconds")

# Set the shot timer delay
func set_shot_timer_delay(delay: float):
	shot_timer_delay = round(delay * 100.0) / 100.0  # Ensure 2 decimal precision
	if DEBUG_LOGGING:
		print("PERFORMANCE TRACKER: Shot timer delay set to:", shot_timer_delay, "seconds")

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
			var global_data = get_node_or_null("/root/GlobalData")
			var settings_json = ""
			var next_index = 1
			
			if global_data and global_data.settings_dict != null:
				var current_index = int(global_data.settings_dict.get("max_index", 0))
				next_index = (current_index % 20) + 1
				global_data.settings_dict["max_index"] = next_index
				if DEBUG_LOGGING:
					print("[PerformanceTracker] Updated max_index from ", current_index, " to ", next_index, " (circular buffer 1-20)")
				# Preserve all existing settings, only update max_index
				settings_json = JSON.stringify(global_data.settings_dict)
			
			http_service.save_game(_on_settings_saved, "settings", settings_json)
			
			# Save/update leaderboard index
			_save_leaderboard_index(next_index)
		else:
			if DEBUG_LOGGING:
				print("HttpService not found")
	else:
		if DEBUG_LOGGING:
			print("Failed to save performance data")

# Save/update leaderboard index with current drill performance
func _save_leaderboard_index(drill_index: int):
	if not pending_drill_data:
		if DEBUG_LOGGING:
			print("[PerformanceTracker] No pending drill data for leaderboard index")
		return
	
	var http_service = get_node("/root/HttpService")
	if not http_service:
		if DEBUG_LOGGING:
			print("[PerformanceTracker] HttpService not found for leaderboard index update")
		return
	
	# Calculate performance metrics from pending drill data
	var drill_summary = pending_drill_data.get("drill_summary", {})
	var records = pending_drill_data.get("records", [])
	
	# Calculate total score
	var total_score = 0
	for record in records:
		if record.has("score"):
			total_score += record["score"]
	
	# Calculate hit factor (hf)
	var hf = 0.0
	var total_time = drill_summary.get("total_elapsed_time", 0.0)
	if total_time > 0:
		hf = total_score / total_time
	
	# Get fastest shot interval
	var fastest_shot = drill_summary.get("fastest_shot_interval", null)
	var fastest_shot_time = 0.0
	if fastest_shot != null:
		fastest_shot_time = fastest_shot
	
	# Create leaderboard entry with exact format specified including fastest shot
	var leaderboard_entry = {
		"index": int(drill_index),  # Ensure index is always an integer
		"hf": round(hf * 10) / 10.0,  # Round to 1 decimal place
		"score": int(total_score),  # Ensure score is always an integer
		"time": round(total_time * 10) / 10.0,  # Round to 1 decimal place
		"fastest_shot": round(fastest_shot_time * 100) / 100.0  # Round to 2 decimal places
	}
	
	if DEBUG_LOGGING:
		print("[PerformanceTracker] Creating leaderboard index entry: ", leaderboard_entry)
	
	# Try to load existing leader_board_index.json or create new one if it doesn't exist
	http_service.load_game(func(result, response_code, headers, body): _on_index_file_loaded(leaderboard_entry, result, response_code, headers, body), "leader_board_index")

func _on_index_file_loaded(new_entry: Dictionary, result, response_code, headers, body):
	var http_service = get_node("/root/HttpService")
	if not http_service:
		return
	
	var index_data = []
	
	# If leader_board_index.json exists, load existing data for appending
	if response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(body_str)
		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data") and response_data["code"] == 0:
				# Check if data is empty string "{}" indicating file doesn't exist
				if response_data["data"] == "{}":
					# File doesn't exist - create new one
					if DEBUG_LOGGING:
						print("[PerformanceTracker] leader_board_index.json doesn't exist, creating new file")
				else:
					var index_json = JSON.new()
					var index_parse = index_json.parse(response_data["data"])
					if index_parse == OK:
						index_data = index_json.data
						# Normalize existing data to ensure correct types
						for i in range(index_data.size()):
							var entry = index_data[i]
							if entry.has("index"):
								entry["index"] = int(entry["index"])  # Ensure index is integer
							if entry.has("score"):
								entry["score"] = int(entry["score"])  # Ensure score is integer
							if entry.has("hf"):
								entry["hf"] = round(float(entry["hf"]) * 10) / 10.0  # Ensure hf is float with 1 decimal
							if entry.has("time"):
								entry["time"] = round(float(entry["time"]) * 10) / 10.0  # Ensure time is float with 1 decimal
							if entry.has("fastest_shot"):
								entry["fastest_shot"] = round(float(entry["fastest_shot"]) * 100) / 100.0  # Ensure fastest_shot is float with 2 decimals
							else:
								# Add fastest_shot field if missing (for backward compatibility)
								entry["fastest_shot"] = 0.0
						if DEBUG_LOGGING:
							print("[PerformanceTracker] Loaded and normalized existing leader_board_index.json with ", index_data.size(), " entries")
	else:
		# Unexpected response code - create new file
		if DEBUG_LOGGING:
			print("[PerformanceTracker] Unexpected response code ", response_code, ", creating new file")
	
	# Find if entry with same index exists and update it, otherwise append new entry
	var entry_updated = false
	for i in range(index_data.size()):
		if int(index_data[i].get("index")) == int(new_entry["index"]):
			index_data[i] = new_entry
			entry_updated = true
			if DEBUG_LOGGING:
				print("[PerformanceTracker] Updated existing entry at index ", new_entry["index"])
			break
	
	# If entry with this index doesn't exist, append the new entry
	if not entry_updated:
		index_data.append(new_entry)
		if DEBUG_LOGGING:
			print("[PerformanceTracker] Appended new entry at index ", new_entry["index"])
	
	# Sort index data by hit factor in descending order for better leaderboard presentation
	index_data.sort_custom(func(a, b): return a.get("hf", 0.0) > b.get("hf", 0.0))
	
	# Save updated leader_board_index.json
	var index_json = JSON.stringify(index_data)
	http_service.save_game(_on_index_file_saved, "leader_board_index", index_json)

func _on_index_file_saved(result, response_code, headers, body):
	if response_code == 200:
		if DEBUG_LOGGING:
			print("[PerformanceTracker] leader_board_index.json saved successfully")
	else:
		if DEBUG_LOGGING:
			print("[PerformanceTracker] Failed to save leader_board_index.json - Response code: ", response_code)
