extends Node

# Add this script as an autoload (singleton) in Project Settings > Autoload

const DEBUG_DISABLED = true

var base_url: String = "http://127.0.0.1"

func _ready():
	if not DEBUG_DISABLED:
		print("[HttpService] Ready.")

# Renamed to avoid conflict with Godot's built-in get()
func get_request(url: String, callback: Callable):
	if not DEBUG_DISABLED:
		print("[HttpService] GET ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	http.request(url)

func start_game(callback: Callable, mode: String = "free", waiting: int = 0):
	var url = base_url + "/game/start"
	var data = {"mode": mode, "waiting": waiting}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func stop_game(callback: Callable):
	var url = base_url + "/game/stop"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending stop game request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	http.request(url, [], HTTPClient.METHOD_POST)

func shutdown(callback: Callable, mode: String = "free"):
	var url = base_url + "/system/shutdown"
	var data = {"mode": mode}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func volume_up(callback: Callable, mode: String = "free"):
	var url = base_url + "/system/volume/increase"
	var data = {"mode": mode}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func volume_down(callback: Callable, mode: String = "free"):
	var url = base_url + "/system/volume/decrease"
	var data = {"mode": mode}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func post(url: String, data: Dictionary, callback: Callable):
	if not DEBUG_DISABLED:
		print("[HttpService] POST ", url, " data: ", data)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func save_game(callback: Callable, data_id: String, content: String, ns: String = "default"):
	var url = base_url + "/game/save"
	var data = {
		"data_id": data_id,
		"content": content,
		"namespace": ns
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func load_game(callback: Callable, data_id: String, ns: String = "default"):
	if not DEBUG_DISABLED:
		print("[HttpService] Sending load_game request for data_id: ", data_id, ", namespace: ", ns)
	var url = base_url + "/game/load"
	var data = {
		"data_id": data_id,
		"namespace": ns
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if not DEBUG_DISABLED:
			print("[HttpService] load_game response for data_id ", data_id, " - Result: ", result, ", Code: ", response_code)
		if result == HTTPRequest.RESULT_SUCCESS:
			var body_str = body.get_string_from_utf8()
			if not DEBUG_DISABLED:
				print("[HttpService] load_game response body: ", body_str)
		else:
			if not DEBUG_DISABLED:
				print("[HttpService] load_game request failed with result: ", result)
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	if not DEBUG_DISABLED:
		print("[HttpService] load_game request data: ", json_data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func wifi_scan(callback: Callable):
	var url = base_url + "/netlink/wifi/scan"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending wifi scan request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func wifi_connect(callback: Callable, ssid: String, password: String):
	var url = base_url + "/netlink/wifi/connect"
	var data = {
		"ssid": ssid,
		"password": password
	}
	if not DEBUG_DISABLED:
		print("[HttpService] Sending wifi connect request to ", url, " with data: ", data)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)
