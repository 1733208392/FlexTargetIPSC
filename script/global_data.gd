extends Node

# Global data storage for sharing information between scenes
var selected_drill_data: Dictionary = {}
var upper_level_scene: String = "res://scene/drills.tscn"

# Current game settings
var current_settings: Dictionary = {
	"difficulty": "Easy",
	"target_count": 20,
	"time_limit": 120
}

# Audio settings
var audio_settings: Dictionary = {
	"master_volume": 75,
	"sfx_volume": 80,
	"is_muted": false
}

# Control settings
var control_settings: Dictionary = {
	"scheme": "Touch",
	"sensitivity": 1.0
}

func _ready():
	print("GlobalData singleton initialized")

# Function to reset selected drill data
func clear_selected_drill():
	selected_drill_data.clear()

# Function to check if drill data is available
func has_selected_drill() -> bool:
	return not selected_drill_data.is_empty()
