extends Node

func _ready():
	# Load settings from HttpService
	HttpService.load_game(Callable(self, "_on_load_settings"), "settings")

func _on_load_settings(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("content"):
			var content_json = JSON.parse_string(json["content"])
			if content_json:
				GlobalData.max_index = content_json.get("max_index", 0)
				GlobalData.language = content_json.get("language", "English")
				print("Settings loaded: max_index=", GlobalData.max_index, ", language=", GlobalData.language)
			else:
				_save_default_settings()
		else:
			_save_default_settings()
	else:
		_save_default_settings()

func _save_default_settings():
	var default = {"max_index": 0, "language": "English"}
	HttpService.save_game(Callable(self, "_on_save_settings"), "settings", JSON.stringify(default))

func _on_save_settings(result, response_code, headers, body):
	if response_code == 200:
		GlobalData.max_index = 0
		GlobalData.language = "English"
		print("Default settings saved and loaded")
	else:
		print("Failed to save settings")
