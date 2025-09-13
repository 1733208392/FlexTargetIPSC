extends Node

# Global data storage for sharing information between scenes
var upper_level_scene: String = "res://scene/drills.tscn"
var settings_dict: Dictionary = {}
var selected_drill_data: Dictionary = {}  # Store selected drill data for replay

# Signal emitted when settings are successfully loaded
signal settings_loaded

func _ready():
	print("GlobalData singleton initialized")
	load_settings_from_http()

func load_settings_from_http():
	print("GlobalData: Requesting settings from HttpService...")
	HttpService.load_game(Callable(self, "_on_settings_loaded"), "settings")

func _on_settings_loaded(result, response_code, headers, body):
	print("GlobalData: HTTP response received - Code: ", response_code)
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("data"):
			var content_json = JSON.parse_string(json["data"])
			if content_json:
				settings_dict = content_json
				# Ensure max_index is always an integer
				if settings_dict.has("max_index"):
					settings_dict["max_index"] = int(settings_dict["max_index"])
				print("Settings loaded into dictionary: ", settings_dict)
				print("Settings keys: ", settings_dict.keys())
				# Emit signal to notify that settings are loaded
				settings_loaded.emit()
			else:
				print("Failed to parse settings content")
				# Emit signal even on failure so app doesn't hang
				settings_loaded.emit()
		else:
			print("No content field in response")
			# Emit signal even on failure so app doesn't hang
			settings_loaded.emit()
	else:
		print("Failed to load settings, response code: ", response_code)
		# Emit signal even on failure so app doesn't hang
		settings_loaded.emit()
