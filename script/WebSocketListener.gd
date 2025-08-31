extends Node

signal data_received(data)
signal bullet_hit(pos: Vector2)
signal menu_control(directive: String)

var socket: WebSocketPeer
var bullet_spawning_enabled: bool = true

func _ready():
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url("ws://127.0.0.1/websocket")
	#var err = socket.connect_to_url("ws://localhost:8080")
	if err != OK:
		print("Unable to connect")
		set_process(false)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			var message = packet.get_string_from_utf8()
			print("[WebSocket] Received raw message: ", message)
			data_received.emit(message)
			_process_websocket_json(message)
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.

# Parse JSON and emit bullet_hit for each (x, y)
func _process_websocket_json(json_string):
	print("[WebSocket] Processing JSON: ", json_string)
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("[WebSocket] Error parsing JSON: ", json_string)
		return
	
	var parsed = json.get_data()
	print("[WebSocket] Parsed data: ", parsed)
	# Handle control directive
	if parsed and parsed.has("type") and parsed["type"] == "control" and parsed.has("directive"):
		print("[WebSocket] Emitting menu_control with directive: ", parsed["directive"])
		menu_control.emit(parsed["directive"])
		return
		
	# Handle bullet hit data
	if parsed and parsed.has("data"):
		print("[WebSocket] Found data array with ", parsed["data"].size(), " entries")
		for entry in parsed["data"]:
			var x = entry.get("x", null)
			var y = entry.get("y", null)
			if x != null and y != null:
				if bullet_spawning_enabled:
					print("[WebSocket] Emitting bullet_hit at: Vector2(", x, ", ", y, ")")
					bullet_hit.emit(Vector2(x, y))
				else:
					print("[WebSocket] Bullet spawning disabled, ignoring hit at: Vector2(", x, ", ", y, ")")
			else:
				print("[WebSocket] Entry missing x or y: ", entry)
