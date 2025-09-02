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
var current_index = 1
var fastest_time_diff = 999.0  # Initialize with a large value
var first_shot = true  # Track if this is the first shot of the drill
var total_elapsed_time = 0.0  # Store the total elapsed time for the drill

func _ready():
    # Don't initialize last_shot_time here - let reset_shot_timer handle it
    pass

# Signal handler for target_hit
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
    
    var file_name = "performance_%03d.json" % current_index
    var file_path = "user://" + file_name
    
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(drill_data)
        file.store_string(json_string)
        file.close()
        print("Performance data saved to: ", file_path)
        var fastest_display = "N/A"
        if fastest_time_diff < 999.0:
            fastest_display = "%.2f" % fastest_time_diff
        print("Drill summary - Total time:", total_elapsed_time, "seconds, Fastest shot:", fastest_display)
    else:
        print("Failed to save performance data")
    
    records.clear()
    current_index += 1
    # Removed: fastest_time_diff = 999.0  # Reset for next drill

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
