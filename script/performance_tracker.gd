extends Node

# Scoring rule table for performance tracking
const SCORES = {
	"AZone": 5,
	"CZone": 3,
	"Miss": 0,
	"WhiteZone": -5,
	"Paddle": 2,
	"Popper": 2,
	# Add more scoring rules as needed
}

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
		print("PERFORMANCE TRACKER: First shot recorded at time:", current_time)
	else:
		# Subsequent shots - calculate interval
		time_diff = (current_time - last_shot_time) / 1000.0  # in seconds
		last_shot_time = current_time
		
		# Update fastest time if this is faster
		if time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		print("PERFORMANCE TRACKER: Shot interval:", time_diff, "seconds, fastest:", fastest_time_diff)
	
	var score = SCORES.get(hit_area, 0)  # Default to 0 if not found
	
	var record = {
		"target_type": target_type,
		"time_diff": time_diff,
		"hit_position": {"x": hit_position.x, "y": hit_position.y},
		"hit_area": hit_area,
		"score": score,
		"rotation_angle": rotation_angle
	}
	
	records.append(record)
	print("Performance record added: ", record)

# Signal handler for drills finished
func _on_drills_finished():
	if records.size() == 0:
		return
	
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
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		var json_string = JSON.stringify(pending_drill_data)
		var data_id = str(GlobalData.max_index + 1)
		http_service.save_game(_on_performance_saved, data_id, json_string)
	else:
		print("HttpService not found")

# Get the fastest time difference recorded
func get_fastest_time_diff() -> float:
	return fastest_time_diff

# Reset the fastest time for a new drill
func reset_fastest_time():
	fastest_time_diff = 999.0

# Reset the shot timer for accurate first shot measurement
func reset_shot_timer():
	last_shot_time = Time.get_ticks_msec()

# Set the total elapsed time for the drill
func set_total_elapsed_time(time_seconds: float):
	total_elapsed_time = time_seconds
	print("PERFORMANCE TRACKER: Total elapsed time set to:", total_elapsed_time, "seconds")

func _on_settings_saved(result, response_code, headers, body):
	if response_code == 200:
		print("Settings saved")
		var fastest_display = "N/A"
		if fastest_time_diff < 999.0:
			fastest_display = "%.2f" % fastest_time_diff
		print("Drill summary - Total time:", total_elapsed_time, "seconds, Fastest shot:", fastest_display)
		records.clear()
		pending_drill_data = null
	else:
		print("Failed to save settings")

func _on_performance_saved(result, response_code, headers, body):
	if response_code == 200:
		print("Performance data saved")
		var http_service = get_node("/root/HttpService")
		if http_service:
			GlobalData.max_index += 1
			var settings_data = {"max_index": GlobalData.max_index}
			var settings_json = JSON.stringify(settings_data)
			http_service.save_game(_on_settings_saved, "settings", settings_json)
		else:
			print("HttpService not found")
	else:
		print("Failed to save performance data")
