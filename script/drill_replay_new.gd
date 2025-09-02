extends Node

var records = []
var current_index = 0
var current_target_type = ""
var loaded_targets = {}
var labels = []
var bullet_holes = []

var target_scenes = {
	"ipsc_mini": "res://scene/ipsc_mini.tscn",
	"hostage": "res://scene/hostage.tscn",
	"ipsc_mini_rotate": "res://scene/ipsc_mini_rotate.tscn",
	"3paddles": "res://scene/3paddles.tscn",
	"2poppers": "res://scene/2poppers.tscn",
	# Add more as needed
}

func _ready():
	print("Drill Replay: Loading drill records...")
	
	# Find the latest performance file
	var latest_file = find_latest_performance_file()
	if latest_file == "":
		print("No performance files found.")
		return
	
	print("Latest file found: ", latest_file)
	
	# Load the data
	var file = FileAccess.open(latest_file, FileAccess.READ)
	if not file:
		print("Failed to open file: ", latest_file)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	print("JSON string: ", json_string)
	
	var json = JSON.parse_string(json_string)
	if json == null:
		print("Failed to parse JSON from: ", latest_file)
		return
	
	print("Parsed JSON type: ", typeof(json))
	if json is Dictionary:
		print("Parsed JSON keys: ", json.keys())
		if json.has("records"):
			records = json["records"]
	elif json is Array:
		records = json
	else:
		print("Unexpected JSON type")
		return
	
	if records.size() == 0:
		print("No records found")
		return
	
	# Print the drill summary
	if json is Dictionary and json.has("drill_summary"):
		var summary = json["drill_summary"]
		print("Drill Summary:")
		print("  Total Elapsed Time: ", summary.get("total_elapsed_time", "N/A"), " seconds")
		print("  Fastest Shot Interval: ", summary.get("fastest_shot_interval", "N/A"), " seconds")
		print("  Total Shots: ", summary.get("total_shots", 0))
		print("  Timestamp: ", summary.get("timestamp", "N/A"))
	
	# Load the first record
	load_record(current_index)
	
	# Enable input for this node
	set_process_input(true)

func load_record(index):
	if index >= records.size():
		return
	
	var record = records[index]
	var target_type = record.get("target_type", "")
	
	# If target type changed, switch target
	if target_type != current_target_type:
		if current_target_type != "":
			# Hide previous target
			if loaded_targets.has(current_target_type):
				loaded_targets[current_target_type]["scene"].visible = false
		current_target_type = target_type
		if not loaded_targets.has(target_type):
			# Load new target
			if target_scenes.has(target_type):
				var scene_path = target_scenes[target_type]
				var target_scene = load(scene_path).instantiate()
				var target_pos = Vector2(-200, 200) if target_type == "ipsc_mini_rotate" else Vector2(0, 0)
				target_scene.position = target_pos
				add_child(target_scene)
				# Disable input for target and its children
				disable_target_input(target_scene)
				loaded_targets[target_type] = {"scene": target_scene, "pos": target_pos}
			else:
				print("Unknown target type: ", target_type)
				return
		# Show current target
		loaded_targets[target_type]["scene"].visible = true
	
	# Add bullet hole
	var hit_pos = record["hit_position"]
	var target_data = loaded_targets[target_type]
	var pos = target_data["pos"]
	var bullet_hole = load("res://scene/bullet_hole.tscn").instantiate()
	bullet_hole.position = Vector2(hit_pos["x"], hit_pos["y"]) -pos - Vector2(360, 720)
	bullet_hole.z_index = 5  # Ensure it's above the target
	target_data["scene"].add_child(bullet_hole)
	bullet_holes.append(bullet_hole)
	
	# Add time_diff label
	var time_diff = record.get("time_diff", 0.0)
	var label = Label.new()
	label.text = "%.2f" % time_diff
	label.position = bullet_hole.position + Vector2(30, -100)
	label.modulate = Color(0, 0, 0)
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 40)
	loaded_targets[target_type]["scene"].add_child(label)
	labels.append(label)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_N and event.pressed:
		if current_index < records.size() - 1:
			# Make previous label 0.3 transparent
			if labels.size() > 0:
				labels.back().modulate.a = 0.3
			current_index += 1
			load_record(current_index)

func disable_target_input(node: Node):
	"""Recursively disable input for a node and its children"""
	node.set_process_input(false)
	if node.has_method("_on_input_event"):
		node.input_event.disconnect(node._on_input_event)
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if node.has_method("_on_websocket_bullet_hit"):
			ws_listener.bullet_hit.disconnect(node._on_websocket_bullet_hit)
	for child in node.get_children():
		disable_target_input(child)

func find_latest_performance_file() -> String:
	var dir = DirAccess.open("user://")
	if not dir:
		print("Failed to open user:// directory")
		return ""
	
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		print("Found file: ", file_name)
		if file_name.begins_with("performance_") and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("Performance files found: ", files)
	
	if files.size() == 0:
		return ""
	
	# Sort by index
	files.sort_custom(func(a, b): return int(a.split("_")[1].split(".")[0]) > int(b.split("_")[1].split(".")[0]))
	
	return "user://" + files[0]
