extends Control

@onready var list_container = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# History data structure to store drill results
var history_data = []

func _ready():
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Load history data from saved files
	load_history_data()
	
	# Populate the list with data
	populate_list()
	
	# Make list items clickable
	setup_clickable_items()

func load_history_data():
	history_data.clear()
	var dir = DirAccess.open("user://")
	if dir:
		var files = dir.get_files()
		var performance_files = []
		for file in files:
			if file.begins_with("performance_") and file.ends_with(".json"):
				performance_files.append(file)
		
		# Sort by index
		performance_files.sort_custom(func(a, b): return int(a.substr(12, 3)) < int(b.substr(12, 3)))
		
		for file_name in performance_files:
			var file = FileAccess.open("user://" + file_name, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()
				var json = JSON.new()
				var error = json.parse(json_string)
				if error == OK:
					var data = json.data
					var drill_summary = data["drill_summary"]
					var records = data["records"]
					
					var total_score = 0
					for record in records:
						total_score += record["score"]
					
					var hf = 0.0
					if drill_summary["total_elapsed_time"] > 0:
						hf = total_score / drill_summary["total_elapsed_time"]
					
					var drill_data = {
						"drill_number": int(file_name.substr(12, 3)),
						"total_time": "%.2fs" % drill_summary["total_elapsed_time"],
						"fastest_shot": "%.2fs" % (drill_summary["fastest_shot_interval"] if drill_summary["fastest_shot_interval"] != null else 0.0),
						"total_score": "%.1f" % total_score,
						"hf": "%.2f" % hf,
						"targets": records
					}
					history_data.append(drill_data)
				else:
					print("Failed to parse JSON in ", file_name)
			else:
				print("Failed to open ", file_name)
	else:
		print("Failed to access user directory")

func populate_list():
	if not list_container:
		return
	
	# Clear existing items
	for child in list_container.get_children():
		child.queue_free()
	
	# Create items dynamically
	for i in range(history_data.size()):
		var data = history_data[i]
		var item = HBoxContainer.new()
		item.layout_mode = 2
		
		# No label
		var no_label = Label.new()
		no_label.layout_mode = 2
		no_label.size_flags_horizontal = 3
		no_label.text = str(data["drill_number"])
		no_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(no_label)
		
		# VSeparator
		var sep1 = VSeparator.new()
		sep1.layout_mode = 2
		item.add_child(sep1)
		
		# TotalTime label
		var time_label = Label.new()
		time_label.layout_mode = 2
		time_label.size_flags_horizontal = 3
		time_label.text = data["total_time"]
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(time_label)
		
		# VSeparator
		var sep2 = VSeparator.new()
		sep2.layout_mode = 2
		item.add_child(sep2)
		
		# FastShot label
		var fast_label = Label.new()
		fast_label.layout_mode = 2
		fast_label.size_flags_horizontal = 3
		fast_label.text = data["fastest_shot"]
		fast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(fast_label)
		
		# VSeparator
		var sep3 = VSeparator.new()
		sep3.layout_mode = 2
		item.add_child(sep3)
		
		# Score label
		var score_label = Label.new()
		score_label.layout_mode = 2
		score_label.size_flags_horizontal = 3
		score_label.text = data["total_score"]
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(score_label)
		
		# VSeparator
		var sep4 = VSeparator.new()
		sep4.layout_mode = 2
		item.add_child(sep4)
		
		# HF label
		var hf_label = Label.new()
		hf_label.layout_mode = 2
		hf_label.size_flags_horizontal = 3
		hf_label.text = data["hf"]
		hf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(hf_label)
		
		list_container.add_child(item)

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
