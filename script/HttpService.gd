extends Node

# Add this script as an autoload (singleton) in Project Settings > Autoload

var http := HTTPRequest.new()
var base_url: String = "http://127.0.0.1"

func _ready():
	add_child(http)
	print("[HttpService] Ready and HTTPRequest node added.")


# Renamed to avoid conflict with Godot's built-in get()
func get_request(url: String, callback: Callable):
	print("[HttpService] GET ", url)
	http.request_completed.connect(callback)
	http.request(url)

func start_game(callback: Callable, mode: String = "free"):
	var url = base_url + "/game/start"
	var data = {"mode": mode}
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func stop_game(callback: Callable):
	var url = base_url + "/game/stop"
	print("[HttpService] Sending stop game request to ", url)
	http.request_completed.connect(callback)
	http.request(url, [], HTTPClient.METHOD_POST)

func post(url: String, data: Dictionary, callback: Callable):
	print("[HttpService] POST ", url, " data: ", data)
	http.request_completed.connect(callback)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)
