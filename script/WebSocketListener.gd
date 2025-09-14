extends Node

signal data_received(data)
signal bullet_hit(pos: Vector2)
signal menu_control(directive: String)

var socket: WebSocketPeer
var bullet_spawning_enabled: bool = true

# Message rate limiting for performance optimization
var last_message_time: float = 0.0
var message_cooldown: float = 0.016  # ~60fps (16ms minimum between messages)
var max_messages_per_frame: int = 5  # Maximum messages to process per frame
var processed_this_frame: int = 0

func _ready():
	socket = WebSocketPeer.new()
	#var err = socket.connect_to_url("ws://127.0.0.1/websocket")
	var err = socket.connect_to_url("ws://localhost:8080")
	if err != OK:
		print("Unable to connect")
		set_process(false)
	else:
		# Set highest priority for WebSocket processing to ensure immediate message handling
		set_process_priority(100)  # Higher priority than default (0)
		print("[WebSocket] Process priority set to maximum for immediate message processing")

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	
	# Reset per-frame message counter
	processed_this_frame = 0
	
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() and processed_this_frame < max_messages_per_frame:
			var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
			
			# Rate limiting check
			if (time_stamp - last_message_time) < message_cooldown:
				print("[WebSocket] Message rate limited (too fast - ", time_stamp - last_message_time, "s since last)")
				break
			
			var packet = socket.get_packet()
			var message = packet.get_string_from_utf8()
			# print("[WebSocket] Received raw message: ", message)
			data_received.emit(message)
			_process_websocket_json(message)
			
			last_message_time = time_stamp
			processed_this_frame += 1
			
		if socket.get_available_packet_count() > 0:
			print("[WebSocket] Rate limiting: ", socket.get_available_packet_count(), " messages queued for next frame")
			
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
	# print("[WebSocket] Processing JSON: ", json_string)
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("[WebSocket] Error parsing JSON: ", json_string)
		return
	
	var parsed = json.get_data()
	# print("[WebSocket] Parsed data: ", parsed)
	# Handle control directive
	if parsed and parsed.has("type") and parsed["type"] == "control" and parsed.has("directive"):
		print("[WebSocket] Emitting menu_control with directive: ", parsed["directive"])
		menu_control.emit(parsed["directive"])
		return
	
	# Handle bullet hit data
	if parsed and parsed.has("data"):
		# print("[WebSocket] Found data array with ", parsed["data"].size(), " entries")
		for entry in parsed["data"]:
			var x = entry.get("x", null)
			var y = entry.get("y", null)
			if x != null and y != null:
				if bullet_spawning_enabled:
					# Transform pos from WebSocket (268x476.4, origin bottom-left) to game (720x1280, origin top-left)
					var ws_width = 268.0
					var ws_height = 476.4
					var game_width = 720.0
					var game_height = 1280.0
					# Flip y and scale
					var x_new = x * (game_width / ws_width)
					var y_new = game_height - (y * (game_height / ws_height))
					var transformed_pos = Vector2(x_new, y_new)
					# print("[WebSocket] Raw position: Vector2(", x, ", ", y, ") -> Transformed: ", transformed_pos)
					bullet_hit.emit(transformed_pos)
				else:
					# print("[WebSocket] Bullet spawning disabled, ignoring hit at: Vector2(", x, ", ", y, ")")
			else:
				print("[WebSocket] Entry missing x or y: ", entry)
