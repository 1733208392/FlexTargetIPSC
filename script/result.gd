extends Control

# Preload the target modal scene
const TargetModal = preload("res://scene/target_modal.tscn")

var current_modal: Control = null
var loaded_drill_data: Dictionary = {}

func _ready():
	# Initialize the scene
	load_drill_data()
	update_ui_with_drill_data()

func load_drill_data():
	# Try to load drill data from history selection
	var file = FileAccess.open("user://selected_drill.dat", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			loaded_drill_data = json.data
			print("Loaded drill data from history: ", loaded_drill_data)
		
		# Clean up the temporary file
		DirAccess.remove_absolute("user://selected_drill.dat")
	else:
		print("No drill data found, using default data")

func update_ui_with_drill_data():
	# Update the score label if we have loaded data
	var score_label = $MarginContainer/VBoxContainer/ScoreLabel
	if score_label and loaded_drill_data.has("total_score"):
		score_label.text = "Total Score: %.1f" % loaded_drill_data.total_score

func _on_target_button_pressed(target_name: String):
	# Show modal with target-specific information
	show_modal(target_name)

func show_modal(target_name: String):
	# Close existing modal if any
	if current_modal:
		current_modal.queue_free()
	
	# Create new modal instance
	current_modal = TargetModal.instantiate()
	add_child(current_modal)
	
	# Prepare target data (pseudo data for now)
	var target_data = get_target_data(target_name)
	
	# Setup the modal with target data
	current_modal.setup_modal(target_name, target_data)
	
	# Connect the modal closed signal
	current_modal.modal_closed.connect(_on_modal_closed)

func get_target_data(target_name: String) -> Dictionary:
	# First check if we have loaded drill data with target information
	if loaded_drill_data.has("targets") and loaded_drill_data.targets is Array:
		var target_index = get_target_index_from_name(target_name)
		if target_index >= 0 and target_index < loaded_drill_data.targets.size():
			return loaded_drill_data.targets[target_index]
	
	# Fall back to pseudo data based on target name
	match target_name:
		"Target1":
			return {
				"fastest_shot": "0.8s",
				"total_time": "15.2s",
				"shots_count": 6,
				"average_time": "2.5s",
				"accuracy": "83%",
				"points": "28/30"
			}
		"Target2":
			return {
				"fastest_shot": "1.2s",
				"total_time": "18.7s",
				"shots_count": 5,
				"average_time": "3.7s",
				"accuracy": "76%",
				"points": "23/25"
			}
		"Target3":
			return {
				"fastest_shot": "0.9s",
				"total_time": "22.1s",
				"shots_count": 8,
				"average_time": "2.8s",
				"accuracy": "88%",
				"points": "35/40"
			}
		"Target4":
			return {
				"fastest_shot": "0.6s",
				"total_time": "12.9s",
				"shots_count": 4,
				"average_time": "3.2s",
				"accuracy": "100%",
				"points": "20/20"
			}
		"Target5":
			return {
				"fastest_shot": "1.1s",
				"total_time": "16.4s",
				"shots_count": 7,
				"average_time": "2.3s",
				"accuracy": "71%",
				"points": "25/35"
			}
		"Target6":
			return {
				"fastest_shot": "0.7s",
				"total_time": "19.8s",
				"shots_count": 6,
				"average_time": "3.3s",
				"accuracy": "67%",
				"points": "20/30"
			}
		_:
			return {
				"fastest_shot": "0.0s",
				"total_time": "0.0s",
				"shots_count": 0,
				"average_time": "0.0s",
				"accuracy": "0%",
				"points": "0/0"
			}

func get_target_index_from_name(target_name: String) -> int:
	# Map target names to indices
	match target_name:
		"Target1": return 0
		"Target2": return 1
		"Target3": return 2
		"Target4": return 3
		"Target5": return 4
		"Target6": return 5
		_: return -1

func _on_modal_closed():
	# Clean up the modal reference
	current_modal = null
