extends Node

# Add this script as an autoload (singleton) in Project Settings > Autoload

const DEBUG_DISABLED = true

var base_url: String = "http://127.0.0.1"
#var base_url: String = "http://192.168.1.100"

var sb = null  # Signal bus reference

func _ready():
	sb = get_node_or_null("/root/SignalBus")

# Renamed to avoid conflict with Godot's built-in get()
func get_request(url: String, callback: Callable):
	if not DEBUG_DISABLED:
		print("[HttpService] GET ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "GET " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url)

func start_game(callback: Callable, mode: String = "free", waiting: int = 0):
	var url = base_url + "/game/start"
	var data = {"mode": mode, "waiting": waiting}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func stop_game(callback: Callable):
	var url = base_url + "/game/stop"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending stop game request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url, [], HTTPClient.METHOD_POST)

func shutdown(callback: Callable, mode: String = "free"):
	var url = base_url + "/system/shutdown"
	var data = {"mode": mode}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func volume_up(callback: Callable, mode: String = "free"):
	var url = base_url + "/system/volume/increase"
	var data = {"mode": mode}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func volume_down(callback: Callable, mode: String = "free"):
	var url = base_url + "/system/volume/decrease"
	var data = {"mode": mode}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func post(url: String, data: Dictionary, callback: Callable):
	if not DEBUG_DISABLED:
		print("[HttpService] POST ", url, " data: ", data)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func save_game(callback: Callable, data_id: String, content: Variant, ns: String = "default"):
	var url = base_url + "/game/save"
	var data = {
		"data_id": data_id,
		"content": content,
		"namespace": ns
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
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
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
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
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
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
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func netlink_config(callback: Callable, channel: int, target_name: String, workmode: String):
	var url = base_url + "/netlink/config"
	var data = {
		"channel": channel,
		"work_mode": workmode,
		"device_name": target_name

	}
	if not DEBUG_DISABLED:
		print("[HttpService] Sending netlink config request to ", url, " with data: ", data)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func netlink_start(callback: Callable):
	var url = base_url + "/netlink/start"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending netlink start request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func netlink_stop(callback: Callable):
	var url = base_url + "/netlink/stop"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending netlink stop request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func netlink_status(callback: Callable):
	var url = base_url + "/netlink/status"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending netlink status request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			if not DEBUG_DISABLED:
				print("[HttpService] Emitting debug info for netlink_status:", debug_msg)
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		else:
			if not DEBUG_DISABLED:
				print("[HttpService] SignalBus not found, cannot emit debug info")
		# Forward raw response to caller
		if callback and callback.is_valid():
			callback.call(result, response_code, headers, body)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func netlink_forward_data(callback: Callable, data: Dictionary):
	var url = base_url + "/netlink/forward-data"
	var wrapped_data = {"content": data}
	var json_data = JSON.stringify(wrapped_data)
	if not DEBUG_DISABLED:
		print("[HttpService] Sending netlink forward data request to ", url, " with data: ", data)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var _body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Data: " + str(data)
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func upgrade_engine(callback: Callable):
	var url = base_url + "/system/engine/upgrade"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending upgrade engine request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func embedded_status(callback: Callable):
	var url = base_url + "/system/embedded/status"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending embedded system status request to ", url)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		callback.call(result, response_code, headers, body)
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")

func embedded_set_threshold(callback: Callable, value: int):
	var url = base_url + "/system/embedded/threshold"
	if not DEBUG_DISABLED:
		print("[HttpService] Sending embedded system threshold request to ", url, " with value: ", value)
	
	# Validate value is within range (700-2000)
	if value < 700 or value > 2000:
		if not DEBUG_DISABLED:
			print("[HttpService] Warning: threshold value ", value, " is outside recommended range (700-2000)")
	
	var data = {
		"value": value
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		# Only call callback if it's valid (not null/empty)
		if callback and callback.is_valid():
			callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)
