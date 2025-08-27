extends Control

@onready var list_container = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# History data structure to store drill results
var history_data = []

func _ready():
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Initialize history data with pseudo data
	initialize_history_data()
	
	# Make list items clickable
	setup_clickable_items()

func initialize_history_data():
	# Create pseudo data for the 30 history items
	for i in range(1, 31):
		var drill_data = {
			"drill_number": i,
			"total_time": get_random_time(8.0, 25.0),
			"fastest_shot": get_random_time(0.3, 1.8),
			"total_score": randf_range(65.0, 95.0),
			"targets": generate_target_data()
		}
		history_data.append(drill_data)

func generate_target_data() -> Array:
	# Generate pseudo target data for each drill
	var targets = []
	var target_types = ["A-Zone Target", "C-Zone Target", "D-Zone Target", "Steel Target", "Popper Target", "Paper Target"]
	
	for i in range(6):
		var target_data = {
			"name": target_types[i],
			"fastest_shot": "%.1fs" % randf_range(0.5, 1.5),
			"total_time": "%.1fs" % randf_range(10.0, 25.0),
			"shots_count": randi_range(3, 8),
			"average_time": "%.1fs" % randf_range(2.0, 4.0),
			"accuracy": "%d%%" % randi_range(65, 95),
			"points": "%d/%d" % [randi_range(15, 30), randi_range(25, 35)]
		}
		targets.append(target_data)
	
	return targets

func get_random_time(min_val: float, max_val: float) -> String:
	return "%.2fs" % randf_range(min_val, max_val)

func setup_clickable_items():
	# Convert each HBoxContainer item to clickable buttons
	if not list_container:
		return
	
	for i in range(list_container.get_child_count()):
		var item = list_container.get_child(i)
		if item is HBoxContainer:
			# Make the item clickable by detecting mouse input
			item.gui_input.connect(_on_item_clicked.bind(i))
			# Add visual feedback for hover
			item.mouse_entered.connect(_on_item_hover_enter.bind(item))
			item.mouse_exited.connect(_on_item_hover_exit.bind(item))

func _on_item_clicked(event: InputEvent, item_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("History item ", item_index + 1, " clicked")
		
		# Store the selected drill data in a way that can be accessed by the result scene
		if item_index < history_data.size():
			# Create a temporary file to store the drill data
			var file = FileAccess.open("user://selected_drill.dat", FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(history_data[item_index]))
				file.close()
		
		# Navigate to result scene
		get_tree().change_scene_to_file("res://scene/result.tscn")

func _on_item_hover_enter(item: HBoxContainer):
	# Add visual feedback when hovering over items
	item.modulate = Color(1.2, 1.2, 1.2, 1.0)  # Slightly brighter

func _on_item_hover_exit(item: HBoxContainer):
	# Remove visual feedback when not hovering
	item.modulate = Color.WHITE

func _on_back_pressed():
	# Navigate back to the previous scene (intro or main menu)
	print("Back button pressed - returning to intro")
	get_tree().change_scene_to_file("res://scene/intro.tscn")
