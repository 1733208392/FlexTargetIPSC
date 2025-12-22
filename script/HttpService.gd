extends Node

# Add this script as an autoload (singleton) in Project Settings > Autoload

const DEBUG_DISABLED = true

var base_url: String = "http://127.0.0.1"
#var base_url: String = "http://192.168.0.108"

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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
			callback.call(result, response_code, headers, body)
	)
	var json_data = JSON.stringify(data)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_data)

func save_game(callback: Callable, data_id: String, content: Variant, ns: String = "default"):
	var url = base_url + "/game/save"
	
	# Pre-serialize content to ensure it's a string
	var content_str = ""
	if content is Dictionary or content is Array:
		content_str = JSON.stringify(content)
	else:
		content_str = str(content)
	
	var data = {
		"data_id": data_id,
		"content": content_str,
		"namespace": ns
	}
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if sb:
			var body_str = body.get_string_from_utf8()
			var debug_msg = "POST " + url + " - Result: " + str(result) + ", Code: " + str(response_code) + ", Body: " + body_str
			sb.emit_onboard_debug_info(2, debug_msg, "HttpService")
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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
		if callback and callback.is_valid():
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

func _send_image_chunks(base64_data: String, chunk_size: int, delay_ms: float, current_chunk: int, total_chunks: int, completion_callback: Callable):
	"""
	Recursively send image chunks with delay between each packet.
	"""
	
	# Base case: all chunks sent
	if current_chunk >= total_chunks:
		if not DEBUG_DISABLED:
			print("[HttpService] All ", total_chunks, " chunks sent successfully")
		
		# Send transfer complete signal
		var complete_data = {
			"command": "image_transfer_complete",
			"status": "success",
			"chunks_sent": total_chunks
		}
		
		netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if not DEBUG_DISABLED:
					print("[HttpService] Transfer complete signal sent successfully")
			else:
				if not DEBUG_DISABLED:
					print("[HttpService] Failed to send transfer complete signal")
			
			# Call completion callback
			if completion_callback and completion_callback.is_valid():
				completion_callback.call(true, "Image transfer complete")
		, complete_data)
		return
	
	# Extract chunk data
	var chunk_start = current_chunk * chunk_size
	var chunk_end = min(chunk_start + chunk_size, base64_data.length())
	var chunk_data = base64_data.substr(chunk_start, chunk_end - chunk_start)
	
	if not DEBUG_DISABLED:
		print("[HttpService] Preparing chunk %d/%d (size: %d bytes)" % [current_chunk, total_chunks, chunk_data.length()])
	
	# Send this chunk
	var chunk_dict = {
		"command": "image_chunk",
		"chunk_index": current_chunk,
		"data": chunk_data
	}
	
	netlink_forward_data(func(result, response_code, _headers, _body):
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			if not DEBUG_DISABLED:
				print("[HttpService] Failed to send chunk %d, result: %d, code: %d" % [current_chunk, result, response_code])
			if completion_callback and completion_callback.is_valid():
				completion_callback.call(false, "Failed to send chunk " + str(current_chunk))
			return
		
		
		if not DEBUG_DISABLED:
			print("[HttpService] Chunk %d/%d sent successfully" % [current_chunk + 1, total_chunks])
		
		# Schedule next chunk after delay
		var timer = get_tree().create_timer(delay_ms / 1000.0)
		timer.timeout.connect(func():
			_send_image_chunks(base64_data, chunk_size, delay_ms, current_chunk + 1, total_chunks, completion_callback)
		)
	, chunk_dict)

func send_captured_image(image: Image, chunk_size_bytes: int = 1024, packet_delay_ms: float = 50.0, completion_callback: Callable = Callable()):
	"""Send a captured Image object; it will be encoded to JPEG before transfer."""
	if not image:
		if not DEBUG_DISABLED:
			print("[HttpService] Error: Image is null")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "Image is null")
		return
	
	if image.is_empty():
		if not DEBUG_DISABLED:
			print("[HttpService] Error: Image is empty")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "Image is empty")
		return
	
	var jpg_bytes = image.save_jpg_to_buffer(0.5)
	if not jpg_bytes or jpg_bytes.is_empty():
		if not DEBUG_DISABLED:
			print("[HttpService] Error: Failed to convert image to JPG")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "Failed to convert image to JPG")
		return
	
	_send_captured_image_bytes_internal(jpg_bytes, chunk_size_bytes, packet_delay_ms, completion_callback)

func send_captured_image_bytes(jpg_bytes: PackedByteArray, chunk_size_bytes: int = 100, packet_delay_ms: float = 50.0, completion_callback: Callable = Callable()):
	"""Send a pre-encoded JPEG byte array (already compressed) to the mobile app."""
	if not jpg_bytes or jpg_bytes.is_empty():
		if not DEBUG_DISABLED:
			print("[HttpService] Error: JPEG byte array is empty")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "JPEG byte array is empty")
		return
	_send_captured_image_bytes_internal(jpg_bytes, chunk_size_bytes, packet_delay_ms, completion_callback)

func _send_captured_image_bytes_internal(jpg_bytes: PackedByteArray, chunk_size_bytes: int, packet_delay_ms: float, completion_callback: Callable) -> void:
	var base64_data = Marshalls.raw_to_base64(jpg_bytes)
	if not base64_data or base64_data.is_empty():
		if not DEBUG_DISABLED:
			print("[HttpService] Error: Failed to encode image to base64")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "Failed to encode image to base64")
		return
	
	var total_chunks = ceili(float(base64_data.length()) / float(chunk_size_bytes))
	
	if not DEBUG_DISABLED:
		print("[HttpService] Compressed size: ", jpg_bytes.size(), " bytes")
		print("[HttpService] Base64 size: ", base64_data.length(), " bytes")
		print("[HttpService] Chunk size: ", chunk_size_bytes, " bytes")
		print("[HttpService] Total chunks: ", total_chunks)

	var start_data = {
		"command": "image_transfer_start",
		"total_chunks": total_chunks,
		"chunk_size": chunk_size_bytes,
		"total_size": jpg_bytes.size()
	}

	netlink_forward_data(func(result, response_code, _headers, _body):
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			if not DEBUG_DISABLED:
				print("[HttpService] Failed to send image_transfer_start, result: ", result, " code: ", response_code)
			if completion_callback and completion_callback.is_valid():
				completion_callback.call(false, "Failed to send transfer start")
			return
		
		if not DEBUG_DISABLED:
			print("[HttpService] Transfer start signal sent successfully for captured image")
		
		_send_image_chunks(base64_data, chunk_size_bytes, packet_delay_ms, 0, total_chunks, completion_callback)
	
	, start_data)
	
