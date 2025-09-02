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

func _ready():
    # Initialize last_shot_time
    last_shot_time = Time.get_ticks_msec()

# Signal handler for target_hit
func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String):
    var current_time = Time.get_ticks_msec()
    var time_diff = (current_time - last_shot_time) / 1000.0  # in seconds
    last_shot_time = current_time
    
    # Update fastest time if this is faster
    if time_diff < fastest_time_diff:
        fastest_time_diff = time_diff
    
    var score = SCORES.get(hit_area, 0)  # Default to 0 if not found
    
    var record = {
        "target_type": target_type,
        "time_diff": time_diff,
        "hit_position": {"x": hit_position.x, "y": hit_position.y},
        "hit_area": hit_area,
        "score": score
    }
    
    records.append(record)
    print("Performance record added: ", record)

# Signal handler for drills finished
func _on_drills_finished():
    if records.size() == 0:
        return
    
    print("Performance records for this drill: ", records)
    
    var file_name = "performance_%03d.json" % current_index
    var file_path = "user://" + file_name
    
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(records)
        file.store_string(json_string)
        file.close()
        print("Performance data saved to: ", file_path)
    else:
        print("Failed to save performance data")
    
    records.clear()
    current_index += 1
    fastest_time_diff = 999.0  # Reset for next drill

# Get the fastest time difference recorded
func get_fastest_time_diff() -> float:
    return fastest_time_diff

# Reset the fastest time for a new drill
func reset_fastest_time():
    fastest_time_diff = 999.0
