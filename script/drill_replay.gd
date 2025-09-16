extends Node

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

var records = []
var current_index = 0
var current_target_type = ""
var loaded_targets = {}
var upper_level_scene = "res://scene/drills.tscn"  # Default upper level scene

var target_scenes = {
	"ipsc_mini": "res://scene/ipsc_mini.tscn",
	"ipsc_mini_black_1": "res://scene/ipsc_mini_black_1.tscn",
	"ipsc_mini_black_2": "res://scene/ipsc_mini_black_2.tscn",
	"hostage": "res://scene/hostage.tscn",
	"ipsc_mini_rotate": "res://scene/ipsc_mini_rotate.tscn",
	"3paddles": "res://scene/3paddles.tscn",
	"2poppers": "res://scene/2poppers.tscn",
	# Add more as needed
}

# UI references
var target_type_title: Label
var bullet_hole_labels = []  # Store sequence number labels for bullet holes

func _ready():
	if DEBUG_LOGGING:
						print("Drill Replay: Loading drill records...")
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_LOGGING:
			print("[Drill Replay] Connecting to WebSocketListener.menu_control signal")
	else:
		if DEBUG_LOGGING:
			print("[Drill Replay] WebSocketListener singleton not found!")
	
	# Get upper level scene and selected drill data from GlobalData
	var global_data = get_node("/root/GlobalData")
	if global_data:
		upper_level_scene = global_data.upper_level_scene
		if DEBUG_LOGGING:
			print("[Drill Replay] Upper level scene set to: ", upper_level_scene)
		
		# Check if drill data is available in GlobalData
		if global_data.selected_drill_data.size() > 0:
			if DEBUG_LOGGING:
				print("[Drill Replay] Found selected drill data in GlobalData")
			
			# Check if we need to load detailed performance data
			var drill_data = global_data.selected_drill_data
			if drill_data.has("records") and drill_data["records"].size() == 0 and drill_data.has("drill_number"):
				# Data came from leaderboard index - need to load full performance file
				if DEBUG_LOGGING:
					print("[Drill Replay] Empty records detected, loading performance file for drill ", drill_data["drill_number"])
				load_performance_from_http(drill_data["drill_number"])
			else:
				# Data already contains records (legacy path or direct performance data)
				load_selected_drill_data(global_data.selected_drill_data)
				# Clear the data after loading to prevent reuse
				global_data.selected_drill_data = {}
				# Initialize UI after data load
				initialize_ui()
			return
	
	# Fallback: use latest performance data from memory
	if DEBUG_LOGGING:
						print("[Drill Replay] No selected drill data found, checking in-memory latest performance")
	load_latest_performance_from_memory()
	# Initialize UI after fallback load
	initialize_ui()

func load_latest_performance_from_memory():
	"""Load the latest performance data from GlobalData (in-memory)"""
	if DEBUG_LOGGING:
		print("[Drill Replay] Loading latest performance from memory")
	
	var global_data = get_node("/root/GlobalData")
	if not global_data:
		if DEBUG_LOGGING:
			print("[Drill Replay] GlobalData not found")
		return
	
	# Check if we have latest performance data in memory
	if global_data.latest_performance_data.size() > 0:
		if DEBUG_LOGGING:
			print("[Drill Replay] Found latest performance data in memory")
		var data = global_data.latest_performance_data
		
		# Verify the data structure
		if data.has("drill_summary") and data.has("records"):
			if DEBUG_LOGGING:
				print("[Drill Replay] Successfully loaded latest performance data from memory")
			load_selected_drill_data(data)
			return
		else:
			if DEBUG_LOGGING:
				print("[Drill Replay] Invalid data structure in memory performance data")
	
	if DEBUG_LOGGING:
		print("[Drill Replay] No latest performance data in memory, nothing to display")

func load_performance_from_http(drill_index: int):
	# Load the detailed performance data from performance_[index].json file
	if DEBUG_LOGGING:
		print("[Drill Replay] Loading performance file for drill index: ", drill_index)
	
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		if DEBUG_LOGGING:
			print("[Drill Replay] HttpService not found, cannot load performance file")
		# Fallback to fallback loading
		load_latest_performance_from_memory()
		initialize_ui()
		return
	
	var file_id = "performance_" + str(drill_index)
	if DEBUG_LOGGING:
		print("[Drill Replay] Loading file: ", file_id)
	
	http_service.load_game(_on_performance_file_loaded, file_id)

func _on_performance_file_loaded(result, response_code, _headers, body):
	# Handle the loaded performance file
	if DEBUG_LOGGING:
		print("[Drill Replay] Performance file load response - Result: ", result, ", Code: ", response_code)
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(body_str)
		
		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data") and response_data["code"] == 0:
				var content_json = JSON.new()
				var content_parse = content_json.parse(response_data["data"])
				if content_parse == OK:
					var performance_data = content_json.data
					if DEBUG_LOGGING:
						print("[Drill Replay] Successfully loaded performance file with ", performance_data.get("records", []).size(), " records")
					load_selected_drill_data(performance_data)
					
					# Clear the selected drill data from GlobalData
					var global_data = get_node("/root/GlobalData")
					if global_data:
						global_data.selected_drill_data = {}
					
					# Initialize UI after successful load
					initialize_ui()
					return
				else:
					if DEBUG_LOGGING:
						print("[Drill Replay] Failed to parse performance file content")
			else:
				if DEBUG_LOGGING:
					print("[Drill Replay] Invalid response data structure")
		else:
			if DEBUG_LOGGING:
				print("[Drill Replay] Failed to parse performance file response")
	else:
		if response_code == 404:
			if DEBUG_LOGGING:
				print("[Drill Replay] Performance file not found (404) - drill may not have detailed records")
		else:
			if DEBUG_LOGGING:
				print("[Drill Replay] Failed to load performance file - Response code: ", response_code)
	
	# Fallback: try to load from memory or show error
	if DEBUG_LOGGING:
		print("[Drill Replay] Falling back to memory data or empty display")
	load_latest_performance_from_memory()
	initialize_ui()

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if DEBUG_LOGGING:
		print("[DrillReplay] GlobalData node found: ", global_data != null)
	
	if global_data:
		if DEBUG_LOGGING:
			print("[DrillReplay] GlobalData.settings_dict exists: ", global_data.settings_dict != null)
		if global_data.settings_dict:
			if DEBUG_LOGGING:
				print("[DrillReplay] settings_dict keys: ", global_data.settings_dict.keys())
			if DEBUG_LOGGING:
				print("[DrillReplay] settings_dict language value: ", global_data.settings_dict.get("language", "NOT_FOUND"))
		
		if global_data.settings_dict and global_data.settings_dict.has("language"):
			var language = global_data.settings_dict.get("language", "English")
			if DEBUG_LOGGING:
				print("[DrillReplay] Loading language from GlobalData: ", language)
			set_locale_from_language(language)
		else:
			if DEBUG_LOGGING:
				print("[DrillReplay] No language key found in settings_dict")
			set_locale_from_language("English")
	else:
		if DEBUG_LOGGING:
			print("[DrillReplay] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh_CN"
		"Traditional Chinese":
			locale = "zh_TW"
		"Japanese":
			locale = "ja"
		_:
			locale = "en"  # Default to English
	TranslationServer.set_locale(locale)
	if DEBUG_LOGGING:
		print("[DrillReplay] Set locale to: ", locale)

func get_localized_shot_text() -> String:
	# Since there's no specific "shot" translation key, create localized text based on locale
	var locale = TranslationServer.get_locale()
	if DEBUG_LOGGING:
		print("[DrillReplay] Current locale for shot text: ", locale)
	
	# Test if translation server is working with a known key
	var test_translation = tr("target")
	if DEBUG_LOGGING:
		print("[DrillReplay] Test translation for 'target': ", test_translation)
	
	match locale:
		"zh_CN":
			return "射击"
		"zh_TW":
			return "射擊"
		"ja":
			return "ショット"
		_:
			if DEBUG_LOGGING:
				print("[DrillReplay] Using default English for unknown locale: ", locale)
			return "Shot"

func load_selected_drill_data(data: Dictionary):
	"""Load drill data from the selected drill format"""
	if DEBUG_LOGGING:
						print("Loading selected drill data")
	if DEBUG_LOGGING:
						print("[Drill Replay] Data structure keys: ", data.keys())
	
	# Both history and performance tracker use "records" field
	if data.has("records"):
		records = data["records"]
		if DEBUG_LOGGING:
						print("[Drill Replay] Using 'records' field from data")
	else:
		if DEBUG_LOGGING:
						print("[Drill Replay] Error: No 'records' field found in data")
		return
	
	if records.size() == 0:
		if DEBUG_LOGGING:
						print("No records found in selected drill data")
		return
	
	# Clear any existing sequence labels
	clear_all_sequence_labels()
	
	# Check if records contain rotation angle data
	if records.size() > 0:
		var first_record = records[0]
		if first_record.has("rotation_angle"):
			if DEBUG_LOGGING:
						print("Rotation angle data found in records - will display target at recorded angles during replay")
		else:
			if DEBUG_LOGGING:
						print("No rotation angle data found in records")
	
	# Load the first record
	load_record(current_index)
	
	# Enable input for this node
	set_process_input(true)

func clear_all_sequence_labels():
	"""Clear all sequence number labels"""
	for label_data in bullet_hole_labels:
		if is_instance_valid(label_data["label"]):
			label_data["label"].queue_free()
	bullet_hole_labels.clear()

func load_performance_file(file_path: String):
	"""Load drill data from a performance file"""
	if DEBUG_LOGGING:
		print("Loading performance file: ", file_path)
	
	# Load the data
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		if DEBUG_LOGGING:
						print("Failed to open file: ", file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	if DEBUG_LOGGING:
						print("JSON string: ", json_string)
	
	var json = JSON.parse_string(json_string)
	if json == null:
		if DEBUG_LOGGING:
						print("Failed to parse JSON from: ", file_path)
		return
	
	if DEBUG_LOGGING:
						print("Parsed JSON type: ", typeof(json))
	if json is Dictionary:
		if DEBUG_LOGGING:
						print("Parsed JSON keys: ", json.keys())
		if json.has("records"):
			records = json["records"]
	elif json is Array:
		records = json
	else:
		if DEBUG_LOGGING:
						print("Unexpected JSON type")
		return
	
	if records.size() == 0:
		if DEBUG_LOGGING:
						print("No records found")
		return
	
	# Print the drill summary
	if json is Dictionary and json.has("drill_summary"):
		var summary = json["drill_summary"]
		if DEBUG_LOGGING:
						print("Drill Summary:")
		if DEBUG_LOGGING:
						print("  Total Elapsed Time: ", summary.get("total_elapsed_time", "N/A"), " seconds")
		if DEBUG_LOGGING:
						print("  Fastest Shot Interval: ", summary.get("fastest_shot_interval", "N/A"), " seconds")
		if DEBUG_LOGGING:
						print("  Total Shots: ", summary.get("total_shots", 0))
		if DEBUG_LOGGING:
						print("  Timestamp: ", summary.get("timestamp", "N/A"))
	
	# Check if records contain rotation angle data
	if records.size() > 0:
		var first_record = records[0]
		if first_record.has("rotation_angle"):
			if DEBUG_LOGGING:
						print("Rotation angle data found in records - will display target at recorded angles during replay")
		else:
			if DEBUG_LOGGING:
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
						if DEBUG_LOGGING:
							print("Drill Replay New: Stopped rotation animation for replay")
				
				# Disable input for target and its children
				disable_target_input(target_scene)
				loaded_targets[target_type] = {"scene": target_scene, "pos": target_pos, "bullet_holes": []}
			else:
				if DEBUG_LOGGING:
						print("Unknown target type: ", target_type)
				return
		# Show current target
		loaded_targets[target_type]["scene"].visible = true
	
	add_bullet_hole_for_record(index)
	update_shot_list()
	update_progress_title()
	update_bullet_hole_highlight()

func update_shot_list():
	var shot_list = get_node_or_null("CanvasLayer/ShotListOverlay/ScrollContainer/ShotList")
	var scroll_container = get_node_or_null("CanvasLayer/ShotListOverlay/ScrollContainer")
	if not shot_list or not scroll_container:
		if DEBUG_LOGGING:
			print("Shot list node not found, skipping update")
		return
	
	# Clear existing children immediately
	for child in shot_list.get_children():
		shot_list.remove_child(child)
		child.queue_free()
	
	# Get current target type
	if current_index >= records.size():
		return
	
	var current_record = records[current_index]
	var current_target = current_record.get("target_type", "")
	
	# Find all shots for the current target up to current index
	var current_target_shots = []
	var current_shot_index_in_target = -1
	
	for i in range(current_index + 1):
		var record = records[i]
		var target_type = record.get("target_type", "")
		
		if target_type == current_target:
			current_target_shots.append({"index": i, "record": record})
			if i == current_index:
				current_shot_index_in_target = current_target_shots.size() - 1
	
	# Add shot entries for current target only using global sequence numbers
	for i in range(current_target_shots.size()):
		var shot_data = current_target_shots[i]
		var record = shot_data["record"]
		var global_index = shot_data["index"]  # Global shot sequence number
		var time_diff = record.get("time_diff", 0.0)
		
		var label = Label.new()
		# Use global sequence number (1-based)
		var shot_text = get_localized_shot_text()
		label.text = "%s %d: %.2fs" % [shot_text, global_index + 1, time_diff]
		
		# Color scheme: grey for previous shots in current target, highlighted for current shot
		if i == current_shot_index_in_target:
			label.modulate = Color(1, 1, 0)  # Yellow for current shot
		else:
			label.modulate = Color(0.6, 0.6, 0.6)  # Grey for previous shots in current target
		
		shot_list.add_child(label)
	
	# Auto-scroll to the current shot
	if current_shot_index_in_target >= 0:
		# Wait for the layout to update
		await get_tree().process_frame
		
		# Calculate approximate position based on current shot index in target
		var label_height = 30  # Approximate label height
		var container_height = scroll_container.size.y
		
		# Calculate target scroll position
		var target_scroll = current_shot_index_in_target * label_height - (container_height / 2)
		target_scroll = max(0, target_scroll)  # Don't scroll above the top
		
		scroll_container.scroll_vertical = int(target_scroll)

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
			if DEBUG_LOGGING:
						print("Drill Replay New: Set target rotation to: ", rotation_angle, " radians (", rad_to_deg(rotation_angle), " degrees) for shot ", index + 1)
	
	# Add bullet hole
	var hit_pos = record["hit_position"]
	var pos = target_data["pos"]
	var bullet_hole = load("res://scene/bullet_hole.tscn").instantiate()
	bullet_hole.position = Vector2(hit_pos["x"], hit_pos["y"]) - pos - Vector2(360, 720)
	bullet_hole.z_index = 5  # Ensure it's above the target
	target_data["scene"].add_child(bullet_hole)
	target_data["bullet_holes"].append(bullet_hole)
	
	# Add sequence number label on top of bullet hole
	var seq_label = Label.new()
	seq_label.text = str(index + 1)  # Global sequence number (1-based)
	seq_label.add_theme_font_size_override("font_size", 24)  # Increased from 14 to 18
	seq_label.add_theme_color_override("font_color", Color.YELLOW)
	seq_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	seq_label.add_theme_constant_override("shadow_offset_x", 2)  # Increased shadow for better visibility
	seq_label.add_theme_constant_override("shadow_offset_y", 2)
	seq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seq_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seq_label.position = bullet_hole.position + Vector2(-12, -30)  # Adjusted position for larger font
	seq_label.size = Vector2(24, 24)  # Increased size for larger text
	seq_label.z_index = 6  # Above bullet hole
	target_data["scene"].add_child(seq_label)
	
	# Store label reference for highlighting
	bullet_hole_labels.append({"label": seq_label, "index": index, "target_type": target_type})
	

func initialize_ui():
	"""Initialize UI references and setup highlight system"""
	# Get UI references
	target_type_title = get_node_or_null("CanvasLayer/HeaderContainer/TargetTypeTitle")
	
	# Update title initially
	update_progress_title()

func update_progress_title():
	"""Update the progress title showing current shot and target sequence"""
	if not target_type_title:
		return
	
	if records.size() == 0:
		target_type_title.text = ""
		return
	
	# Calculate target sequence information
	var unique_targets = []
	var current_target_index = 0
	var target_found = false
	
	# Find all unique target types in order of appearance
	for i in range(records.size()):
		var record = records[i]
		var target_type = record.get("target_type", "")
		
		if target_type not in unique_targets:
			unique_targets.append(target_type)
		
		# Find which target index we're currently on
		if i == current_index and not target_found:
			current_target_index = unique_targets.find(target_type) + 1  # 1-based
			target_found = true
	
	# Format: "Shots: 3/41 on Target 2/7"
	var shots_text = "Shots: " + str(current_index + 1) + "/" + str(records.size())
	var target_text = "Target " + str(current_target_index) + "/" + str(unique_targets.size())
	var progress_text = shots_text + " on " + target_text
	
	target_type_title.text = progress_text

func update_bullet_hole_highlight():
	"""Update the sequence number highlighting for the current bullet hole"""
	# Reset all sequence number labels to normal color and size
	for label_data in bullet_hole_labels:
		var label = label_data["label"]
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.add_theme_font_size_override("font_size", 18)  # Normal size increased
	
	# Highlight the current shot's sequence number
	if current_index < records.size():
		for label_data in bullet_hole_labels:
			if label_data["index"] == current_index:
				var label = label_data["label"]
				if is_instance_valid(label):
					label.add_theme_color_override("font_color", Color.RED)
					label.add_theme_font_size_override("font_size", 24)  # Highlighted size increased
				break


func _input(event):
	if event is InputEventKey and event.keycode == KEY_N and event.pressed:
		if current_index < records.size() - 1:
			current_index += 1
			load_record(current_index)
			update_shot_list()
			update_progress_title()
			update_bullet_hole_highlight()
	elif event is InputEventKey and event.keycode == KEY_P and event.pressed:
		if current_index > 0:
			# Remove current bullet hole and sequence label from current target
			if loaded_targets.has(current_target_type):
				var target_data = loaded_targets[current_target_type]
				if target_data["bullet_holes"].size() > 0:
					var last_bullet_hole = target_data["bullet_holes"].back()
					last_bullet_hole.queue_free()
					target_data["bullet_holes"].pop_back()
			
			# Remove the corresponding sequence label
			for i in range(bullet_hole_labels.size() - 1, -1, -1):
				var label_data = bullet_hole_labels[i]
				if label_data["index"] == current_index:
					if is_instance_valid(label_data["label"]):
						label_data["label"].queue_free()
					bullet_hole_labels.remove_at(i)
					break
			
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
						loaded_targets[current_target_type] = {"scene": target_scene, "pos": target_pos, "bullet_holes": []}
				loaded_targets[current_target_type]["scene"].visible = true
			update_shot_list()
			update_progress_title()
			update_bullet_hole_highlight()

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
	if DEBUG_LOGGING:
						print("[Drill Replay] Received menu_control signal with directive: ", directive)
	match directive:
		"volume_up":
			if DEBUG_LOGGING:
						print("[Drill Replay] Volume up")
			volume_up()
		"volume_down":
			if DEBUG_LOGGING:
						print("[Drill Replay] Volume down")
			volume_down()
		"power":
			if DEBUG_LOGGING:
						print("[Drill Replay] Power off")
			power_off()
		"back":
			if DEBUG_LOGGING:
						print("[Drill Replay] Back to upper level scene")
			back_to_upper_level()
		"homepage":
			if DEBUG_LOGGING:
						print("[Drill Replay] Back to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		"left", "up":
			if DEBUG_LOGGING:
						print("[Drill Replay] Previous bullet/target")
			navigate_previous()
		"right", "down":
			if DEBUG_LOGGING:
						print("[Drill Replay] Next bullet/target")
			navigate_next()
		_:
			if DEBUG_LOGGING:
						print("[Drill Replay] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
						print("[Drill Replay] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		if DEBUG_LOGGING:
						print("[Drill Replay] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
						print("[Drill Replay] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		if DEBUG_LOGGING:
						print("[Drill Replay] HttpService singleton not found!")

func _on_volume_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
						print("[Drill Replay] Volume HTTP response:", result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_LOGGING:
						print("[Drill Replay] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		if DEBUG_LOGGING:
						print("[Drill Replay] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_LOGGING:
						print("[Drill Replay] Shutdown HTTP response:", result, response_code, body_str)

func back_to_upper_level():
	# Go back to the recorded upper level scene
	if DEBUG_LOGGING:
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
		if DEBUG_LOGGING:
						print("Failed to open user:// directory")
		return ""
	
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if DEBUG_LOGGING:
						print("Found file: ", file_name)
		if file_name.begins_with("performance_") and file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if DEBUG_LOGGING:
						print("Performance files found: ", files)
	
	if files.size() == 0:
		return ""
	
	# Sort by index
	files.sort_custom(func(a, b): return int(a.split("_")[1].split(".")[0]) > int(b.split("_")[1].split(".")[0]))
	
	return "user://" + files[0]
