extends Node

var records = []
var current_index = 0
var current_target_type = ""
var loaded_targets = {}
var upper_level_scene = "res://scene/drills.tscn"  # Default upper level scene

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
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Drill Replay] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Drill Replay] WebSocketListener singleton not found!")
	
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
	
	# Check if records contain rotation angle data
	if records.size() > 0:
		var first_record = records[0]
		if first_record.has("rotation_angle"):
			print("Rotation angle data found in records - will display target at recorded angles during replay")
		else:
			print("No rotation angle data found in records")
	
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
				
				# Stop the rotation animation for replay if it's a rotating target
				if target_type == "ipsc_mini_rotate":
					var animation_player = target_scene.get_node("AnimationPlayer")
					if animation_player:
						animation_player.stop()
						print("Drill Replay New: Stopped rotation animation for replay")
				
				# Disable input for target and its children
				disable_target_input(target_scene)
				loaded_targets[target_type] = {"scene": target_scene, "pos": target_pos, "bullet_holes": [], "labels": []}
			else:
				print("Unknown target type: ", target_type)
				return
		# Show current target
		loaded_targets[target_type]["scene"].visible = true
	
	add_bullet_hole_for_record(index)

func add_bullet_hole_for_record(index):
	var record = records[index]
	var target_type = record.get("target_type", "")
	if not loaded_targets.has(target_type):
		return
	
	var target_data = loaded_targets[target_type]
	
	# Set rotation angle for rotating targets
	if target_type == "ipsc_mini_rotate":
		var rotation_angle = record.get("rotation_angle", 0.0)
		var target_scene = target_data["scene"]
		var rotation_center = target_scene.get_node("RotationCenter")
		if rotation_center:
			rotation_center.rotation = rotation_angle
			print("Drill Replay New: Set target rotation to: ", rotation_angle, " radians (", rad_to_deg(rotation_angle), " degrees) for shot ", index + 1)
	
	# Add bullet hole
	var hit_pos = record["hit_position"]
	var pos = target_data["pos"]
	var bullet_hole = load("res://scene/bullet_hole.tscn").instantiate()
	bullet_hole.position = Vector2(hit_pos["x"], hit_pos["y"]) - pos - Vector2(360, 720)
	bullet_hole.z_index = 5  # Ensure it's above the target
	target_data["scene"].add_child(bullet_hole)
	target_data["bullet_holes"].append(bullet_hole)
	
	# Add time_diff label
	var time_diff = record.get("time_diff", 0.0)
	var label = Label.new()
	label.text = "%.2f" % time_diff
	label.position = bullet_hole.position + Vector2(30, -100)
	label.modulate = Color(0, 0, 0)
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 40)
	
	# Add rotation angle info for rotating targets
	if target_type == "ipsc_mini_rotate":
		var rotation_angle = record.get("rotation_angle", 0.0)
		label.text += "\n%.1f°" % rad_to_deg(rotation_angle)
	
	target_data["scene"].add_child(label)
	target_data["labels"].append(label)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_N and event.pressed:
		if current_index < records.size() - 1:
			# Make previous label 0.3 transparent
			if loaded_targets.has(current_target_type) and loaded_targets[current_target_type]["labels"].size() > 0:
				loaded_targets[current_target_type]["labels"].back().modulate.a = 0.3
			current_index += 1
			load_record(current_index)
	elif event is InputEventKey and event.keycode == KEY_P and event.pressed:
		if current_index > 0:
			# Remove current bullet hole and label from current target
			if loaded_targets.has(current_target_type):
				var target_data = loaded_targets[current_target_type]
				if target_data["bullet_holes"].size() > 0:
					var last_bullet_hole = target_data["bullet_holes"].back()
					last_bullet_hole.queue_free()
					target_data["bullet_holes"].pop_back()
				if target_data["labels"].size() > 0:
					var last_label = target_data["labels"].back()
					last_label.queue_free()
					target_data["labels"].pop_back()
					# Make the new last label fully visible
					if target_data["labels"].size() > 0:
						target_data["labels"].back().modulate.a = 1.0
			current_index -= 1
			
			# Check if target changed
			var new_record = records[current_index]
			var new_target_type = new_record.get("target_type", "")
			if new_target_type != current_target_type:
				# Hide current target
				if loaded_targets.has(current_target_type):
					loaded_targets[current_target_type]["scene"].visible = false
				current_target_type = new_target_type
				# Load new target if not loaded
				if not loaded_targets.has(current_target_type):
					if target_scenes.has(current_target_type):
						var scene_path = target_scenes[current_target_type]
						var target_scene = load(scene_path).instantiate()
						var target_pos = Vector2(-200, 200) if current_target_type == "ipsc_mini_rotate" else Vector2(0, 0)
						target_scene.position = target_pos
						add_child(target_scene)
						if current_target_type == "ipsc_mini_rotate":
							var animation_player = target_scene.get_node("AnimationPlayer")
							if animation_player:
								animation_player.stop()
						disable_target_input(target_scene)
						loaded_targets[current_target_type] = {"scene": target_scene, "pos": target_pos, "bullet_holes": [], "labels": []}
				loaded_targets[current_target_type]["scene"].visible = true
				# Set the last label of the new target to fully visible
				if loaded_targets[current_target_type]["labels"].size() > 0:
					loaded_targets[current_target_type]["labels"].back().modulate.a = 1.0

func disable_target_input(node: Node):
	"""Recursively disable input for a node and its children"""
	node.set_process_input(false)
	if node.has_method("_on_input_event"):
		node.input_event.disconnect(node._on_input_event)
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if node.has_method("_on_websocket_bullet_hit"):
			ws_listener.bullet_hit.disconnect(node._on_websocket_bullet_hit)
	
	# Stop any animations for replay mode
	if node is AnimationPlayer:
		node.stop()
	
	for child in node.get_children():
		disable_target_input(child)

func _on_menu_control(directive: String):
	print("[Drill Replay] Received menu_control signal with directive: ", directive)
	match directive:
		"volume_up":
			print("[Drill Replay] Volume up")
			volume_up()
		"volume_down":
			print("[Drill Replay] Volume down")
			volume_down()
		"power":
			print("[Drill Replay] Power off")
			power_off()
		"back":
			print("[Drill Replay] Back to upper level scene")
			back_to_upper_level()
		"homepage":
			print("[Drill Replay] Back to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		"left", "up":
			print("[Drill Replay] Previous bullet/target")
			navigate_previous()
		"right", "down":
			print("[Drill Replay] Next bullet/target")
			navigate_next()
		_:
			print("[Drill Replay] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Drill Replay] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		print("[Drill Replay] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Drill Replay] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		print("[Drill Replay] HttpService singleton not found!")

func _on_volume_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Drill Replay] Volume HTTP response:", result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Drill Replay] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		print("[Drill Replay] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Drill Replay] Shutdown HTTP response:", result, response_code, body_str)

func back_to_upper_level():
	# Go back to the recorded upper level scene
	print("[Drill Replay] Going back to upper level scene: ", upper_level_scene)
	get_tree().change_scene_to_file(upper_level_scene)

func navigate_previous():
	if current_index > 0:
		# Simulate pressing P key
		var event = InputEventKey.new()
		event.keycode = KEY_P
		event.pressed = true
		_input(event)

func navigate_next():
	if current_index < records.size() - 1:
		# Simulate pressing N key
		var event = InputEventKey.new()
		event.keycode = KEY_N
		event.pressed = true
		_input(event)

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
