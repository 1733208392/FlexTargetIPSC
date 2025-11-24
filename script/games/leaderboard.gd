extends CanvasLayer

signal leaderboard_loaded(is_new: bool)

var http_service: Node
var leaderboard_data: Array = []
var current_score: int = 0
var highlight_index: int = -1
var is_new_file: bool = false

func _ready():
	http_service = get_node("/root/HttpService")
	
	# Connect to remote control for back/home button
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.back_pressed.connect(_on_remote_back_pressed)
		print("[Leaderboard] Connected to MenuController back_pressed signal")
	else:
		print("[Leaderboard] MenuController autoload not found!")
	
func load_leaderboard(score_to_add: int = -1):
	is_new_file = false  # Reset flag
	if http_service:
		current_score = score_to_add  # Store the score to add if file doesn't exist
		http_service.load_game(Callable(self, "_on_leaderboard_loaded"), "fruitblast_leaderboard")
		await get_tree().create_timer(0.1).timeout  # Wait a bit for the request
	else:
		print("HttpService not found")

func _on_leaderboard_loaded(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		print("[Leaderboard] Raw response body: ", body_str)
		var json_result = JSON.parse_string(body_str)
		if json_result != null:
			var response_data = json_result
			print("[Leaderboard] Parsed response: ", response_data)
			var code = response_data.get("code", -1)
			var msg = response_data.get("msg", "Unknown error")
			var data = response_data.get("data", {})
			print("[Leaderboard] Code: ", code, ", Msg: ", msg, ", Data: ", data)
			
			if code == 0:
				# Success - get the leaderboard content
				print("[Leaderboard] Data type: ", typeof(data), ", Data value: ", data)
				if typeof(data) == TYPE_STRING:
					# Data is a JSON string, parse it
					var parsed_data = JSON.parse_string(data)
					if parsed_data != null:
						if typeof(parsed_data) == TYPE_DICTIONARY:
							leaderboard_data = parsed_data.get("content", [])
						elif typeof(parsed_data) == TYPE_ARRAY:
							# Data is the leaderboard array directly
							leaderboard_data = parsed_data
						else:
							leaderboard_data = []
					else:
						leaderboard_data = []
				else:
					# Data is already a dictionary
					leaderboard_data = data.get("content", [])
				if typeof(leaderboard_data) != TYPE_ARRAY:
					leaderboard_data = []
			else:
				# Error - likely file doesn't exist, create it with current score as 1st place
				print("[Leaderboard] Load failed with code ", code, ": ", msg, " - Creating new leaderboard file with current score")
				is_new_file = true
				leaderboard_data = [{"total_score": current_score}]
				
				# Create the file with the current score
				if http_service:
					var leaderboard_json = JSON.stringify(leaderboard_data)
					http_service.save_game(Callable(self, "_on_leaderboard_created"), "fruitblast_leaderboard", leaderboard_json)
				else:
					print("[Leaderboard] HttpService not found, cannot create leaderboard")
				return
		else:
			print("[Leaderboard] Failed to parse JSON response: ", body_str)
			leaderboard_data = []
	else:
		print("[Leaderboard] HTTP request failed - Result: ", result, ", Response Code: ", response_code)
		leaderboard_data = []
	
	# Ensure it's an array of dicts with total_score
	for i in range(leaderboard_data.size()):
		if typeof(leaderboard_data[i]) != TYPE_DICTIONARY or not leaderboard_data[i].has("total_score"):
			leaderboard_data[i] = {"total_score": 0}
	
	# Sort by total_score descending
	leaderboard_data.sort_custom(func(a, b): return a["total_score"] > b["total_score"])
	
	# Keep only top 10
	if leaderboard_data.size() > 10:
		leaderboard_data.resize(10)
	
	emit_signal("leaderboard_loaded", false)

func update_leaderboard_with_score(score: int):
	current_score = score
	highlight_index = -1
	
	# Check if score qualifies for top 10
	var inserted = false
	for i in range(leaderboard_data.size()):
		if score > leaderboard_data[i]["total_score"]:
			leaderboard_data.insert(i, {"total_score": score})
			highlight_index = i
			inserted = true
			break
	
	if not inserted and leaderboard_data.size() < 10:
		leaderboard_data.append({"total_score": score})
		highlight_index = leaderboard_data.size() - 1
		inserted = true
	
	if inserted:
		# Keep only top 10
		if leaderboard_data.size() > 10:
			leaderboard_data.resize(10)
		
		# Save updated leaderboard
		if http_service:
			var leaderboard_json = JSON.stringify(leaderboard_data)
			http_service.save_game(Callable(self, "_on_leaderboard_saved"), "fruitblast_leaderboard", leaderboard_json)
		else:
			print("HttpService not found")
	
	display_leaderboard()

func _on_leaderboard_saved(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("Leaderboard saved successfully")
	else:
		print("Failed to save leaderboard")

func _on_leaderboard_created(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[Leaderboard] New leaderboard file created successfully")
		if is_new_file:
			# For new files, the current score is already in 1st place
			highlight_index = 0
			display_leaderboard()
		emit_signal("leaderboard_loaded", is_new_file)
	else:
		print("[Leaderboard] Failed to create leaderboard file")
		# Still emit signal with empty leaderboard
		emit_signal("leaderboard_loaded", false)

func display_leaderboard():
	var scores_container = $Control/Panel/VBoxContainer/ScoresContainer
	var score_labels = scores_container.get_children()
	
	for i in range(score_labels.size()):
		if i < leaderboard_data.size():
			var score = int(leaderboard_data[i]["total_score"])
			score_labels[i].text = str(i + 1) + ". " + str(score)
			if i == highlight_index:
				score_labels[i].add_theme_color_override("font_color", Color.YELLOW)
			else:
				score_labels[i].remove_theme_color_override("font_color")
		else:
			score_labels[i].text = str(i + 1) + ". --"
			score_labels[i].remove_theme_color_override("font_color")
	
	$Control/Panel/VBoxContainer/YourScoreLabel.text = "Your Score: " + str(current_score)

func _on_remote_back_pressed():
	"""Handle back/home directive from remote control to return to menu"""
	print("[Leaderboard] Remote back/home pressed - returning to menu...")
	_return_to_menu()

func _return_to_menu():
	print("[Leaderboard] Returning to menu scene")
	var tree = get_tree()
	if tree:
		var error = tree.change_scene_to_file("res://scene/games/menu/menu.tscn")
		if error != OK:
			print("[Leaderboard] Failed to change scene: ", error)
		else:
			print("[Leaderboard] Scene change initiated")
	else:
		print("[Leaderboard] Cannot change scene - scene tree is null")
