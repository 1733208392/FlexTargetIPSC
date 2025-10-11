extends Node

# Global data storage for sharing information between scenes
var upper_level_scene: String = "res://scene/drills.tscn"
var settings_dict: Dictionary = {}
var selected_drill_data: Dictionary = {}  # Store selected drill data for replay
var latest_performance_data: Dictionary = {}  # Store latest performance data for fallback
var netlink_status: Dictionary = {}  # Store last known netlink status from server

# Signal emitted when settings are successfully loaded
signal settings_loaded
signal netlink_status_loaded

func _ready():
	print("GlobalData singleton initialized")
	load_settings_from_http()

func load_settings_from_http():
	print("GlobalData: Requesting settings from HttpService...")
	HttpService.load_game(Callable(self, "_on_settings_loaded"), "settings")

func _on_settings_loaded(_result, response_code, _headers, body):
	print("GlobalData: HTTP response received - Code: ", response_code)
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		print("GlobalData: Parsed JSON: ", json)
		if json and json.has("data"):
			var content_json = JSON.parse_string(json["data"])
			print("GlobalData: Parsed content JSON: ", content_json)
			if content_json:
				settings_dict = content_json
				# Ensure max_index is always an integer
				if settings_dict.has("max_index"):
					settings_dict["max_index"] = int(settings_dict["max_index"])
				# Ensure new auto restart fields have defaults
				if not settings_dict.has("auto_restart"):
					settings_dict["auto_restart"] = false
				if not settings_dict.has("auto_restart_pause_time"):
					settings_dict["auto_restart_pause_time"] = 5
				print("GlobalData: Settings loaded into dictionary: ", settings_dict)
				print("GlobalData: drill_sequence value: ", settings_dict.get("drill_sequence", "NOT_FOUND"))
				print("GlobalData: Settings keys: ", settings_dict.keys())
				# Emit signal to notify that settings are loaded
				settings_loaded.emit()
			else:
				print("GlobalData: Failed to parse settings content")
				# Emit signal even on failure so app doesn't hang
				settings_loaded.emit()
		else:
			print("GlobalData: No data field in response")
			# Emit signal even on failure so app doesn't hang
			settings_loaded.emit()
	else:
		print("GlobalData: Failed to load settings, response code: ", response_code)
		# Emit signal even on failure so app doesn't hang
		settings_loaded.emit()

func update_netlink_status_from_response(_result, response_code, _headers, body):
	print("GlobalData: Received netlink_status response - Code:", response_code)
	if response_code == 200 and _result == HTTPRequest.RESULT_SUCCESS:
		var body_str = body.get_string_from_utf8()
		print("GlobalData: netlink_status body: ", body_str)
		# Try to parse top-level response then data
		var json = JSON.parse_string(body_str)
		if json and json.has("data"):
			# 'data' may already be a dictionary encoded as object or a JSON string
			var data_field = json["data"]
			if typeof(data_field) == TYPE_STRING:
				var parsed = JSON.parse_string(data_field)
				if parsed:
					netlink_status = parsed
				else:
					netlink_status = {}
			else:
				netlink_status = data_field
			print("GlobalData: netlink_status updated: ", netlink_status)
			# Emit signal to notify listeners that netlink status is available
			netlink_status_loaded.emit()
		else:
			print("GlobalData: netlink_status response missing data field or failed to parse")
	else:
		print("GlobalData: netlink_status request failed or non-200 code: ", response_code)
