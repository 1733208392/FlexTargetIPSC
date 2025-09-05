extends Node

# Global data storage for sharing information between scenes
var upper_level_scene: String = "res://scene/drills.tscn"
var max_index: int = 0
var language: String = "English"

func _ready():
	print("GlobalData singleton initialized")
	print("GlobalData singleton Max index:", max_index)
	print("GlobalData singleton Language:", language)
