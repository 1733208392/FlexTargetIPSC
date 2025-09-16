extends Node

# Test script to verify the leaderboard index functionality

func _ready():
	print("[Test] Testing leaderboard index functionality...")
	
	# Check if HttpService is available
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		print("[Test] ERROR: HttpService not found!")
		return
	
	# Check if PerformanceTracker is available
	var performance_tracker = get_node_or_null("/root/PerformanceTracker")
	if not performance_tracker:
		print("[Test] ERROR: PerformanceTracker not found!")
		return
	
	print("[Test] Both HttpService and PerformanceTracker found!")
	
	# Test loading the leader_board_index.json file
	print("[Test] Attempting to load leader_board_index.json...")
	http_service.load_game(_on_test_load_response, "leader_board_index")

func _on_test_load_response(result, response_code, headers, body):
	print("[Test] Load response - Result: ", result, ", Code: ", response_code)
	
	if response_code == 200:
		var body_str = body.get_string_from_utf8()
		print("[Test] leader_board_index.json exists and contains: ", body_str)
		
		# Try to parse the JSON
		var json = JSON.new()
		var parse_result = json.parse(body_str)
		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data") and response_data["code"] == 0:
				var index_json = JSON.new()
				var index_parse = index_json.parse(response_data["data"])
				if index_parse == OK:
					var index_data = index_json.data
					print("[Test] Successfully parsed leader_board_index.json with ", index_data.size(), " entries:")
					for entry in index_data:
						print("[Test]   Index: ", entry.get("index", "N/A"), 
							  ", HF: ", entry.get("hf", "N/A"), 
							  ", Score: ", entry.get("score", "N/A"), 
							  ", Time: ", entry.get("time", "N/A"))
				else:
					print("[Test] Failed to parse index data JSON")
			else:
				print("[Test] Invalid response data format")
		else:
			print("[Test] Failed to parse response JSON")
	elif response_code == 404:
		print("[Test] leader_board_index.json does not exist yet (this is normal for first run)")
	else:
		print("[Test] Failed to load leader_board_index.json with code: ", response_code)
	
	print("[Test] Test completed!")