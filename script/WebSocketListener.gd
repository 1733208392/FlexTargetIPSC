extends Node

const DEBUG_DISABLED = false

signal data_received(data)
signal bullet_hit(pos: Vector2)
signal menu_control(directive: String)
signal ble_ready_command(content: Dictionary)

var socket: WebSocketPeer
var bullet_spawning_enabled: bool = true

# Message rate limiting for performance optimization
var last_message_time: float = 0.0
var message_cooldown: float = 0.050  # Increased to 50ms minimum between messages (was 32ms)
var max_messages_per_frame: int = 2  # Reduced from 3 to 2 for better spacing
var processed_this_frame: int = 0

# Enhanced timing tracking for better shot spacing
var last_shot_processing_time: float = 0.0
var minimum_shot_spacing: float = 0.015  # 15ms minimum between individual shots

# Queue management for clearing pending signals
var pending_bullet_hits: Array[Vector2] = []  # Track pending bullet hit signals

func _ready():
	socket = WebSocketPeer.new()
	#var err = socket.connect_to_url("ws://127.0.0.1/websocket")
	var err = socket.connect_to_url("ws://localhost:8080")
	if err != OK:
		if not DEBUG_DISABLED:
			print("Unable to connect")
		set_process(false)
	else:
		# Set highest priority for WebSocket processing to ensure immediate message handling
		set_process_priority(100)  # Higher priority than default (0)
		if not DEBUG_DISABLED:
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
				if not DEBUG_DISABLED:
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
			if not DEBUG_DISABLED:
				print("[WebSocket] Rate limiting: ", socket.get_available_packet_count(), " messages queued for next frame")
			
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		if not DEBUG_DISABLED:
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.

# Parse JSON and emit bullet_hit for each (x, y)
func _process_websocket_json(json_string):
	# print("[WebSocket] Processing JSON: ", json_string)
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		if not DEBUG_DISABLED:
			print("[WebSocket] Error parsing JSON: ", json_string)
		return
	
	var parsed = json.get_data()
	# print("[WebSocket] Parsed data: ", parsed)
	# Handle control directive
	if parsed and parsed.has("type") and parsed["type"] == "control" and parsed.has("directive"):
		if not DEBUG_DISABLED:
			print("[WebSocket] Emitting menu_control with directive: ", parsed["directive"])
		menu_control.emit(parsed["directive"])
		return
	
	# Handle BLE forwarded commands
	if parsed and parsed.has("type") and parsed["type"] == "netlink" and parsed.has("action") and parsed["action"] == "forward":
		_handle_ble_forwarded_command(parsed)
		return
	
	# Handle bullet hit data
	if parsed and parsed.has("data"):
		# print("[WebSocket] Found data array with ", parsed["data"].size(), " entries")
		for entry in parsed["data"]:
			var x = entry.get("x", null)
			var y = entry.get("y", null)
			if x != null and y != null:
				# Apply additional shot spacing to prevent burst processing
				var current_shot_time = Time.get_ticks_msec() / 1000.0
				if (current_shot_time - last_shot_processing_time) < minimum_shot_spacing:
					if not DEBUG_DISABLED:
						print("[WebSocket] Shot spacing too fast (", current_shot_time - last_shot_processing_time, "s), delaying processing")
					# Skip this shot to maintain minimum spacing
					continue
				
				last_shot_processing_time = current_shot_time
				
				# Transform pos from WebSocket (268x476.4, origin bottom-left) to game (720x1280, origin top-left)
				var ws_width = 268.0
				var ws_height = 476.4
				var game_width = 720.0
				var game_height = 1280.0
				# Flip y and scale
				var x_new = x * (game_width / ws_width)
				var y_new = game_height - (y * (game_height / ws_height))
				var transformed_pos = Vector2(x_new, y_new)
				
				if bullet_spawning_enabled:
					# Emit immediately when enabled
					print("[WebSocket] Raw position: Vector2(", x, ", ", y, ") -> Transformed: ", transformed_pos)
					bullet_hit.emit(transformed_pos)
				else:
					# When disabled, don't add to pending queue - just ignore
					pass
					print("[WebSocket] Bullet spawning disabled, ignoring hit at: Vector2(", x, ", ", y, ")")
			else:
				if not DEBUG_DISABLED:
					print("[WebSocket] Entry missing x or y: ", entry)

func _handle_ble_forwarded_command(parsed):
	"""Handle BLE forwarded commands"""
	if not parsed.has("dest"):
		if not DEBUG_DISABLED:
			print("[WebSocket] BLE forwarded command missing dest field")
		return
	
	var dest = parsed["dest"]
	# TODO: Implement proper dest validation
	if dest != "B":
		if not DEBUG_DISABLED:
			print("[WebSocket] BLE forwarded command dest validation failed: ", dest)
		return  # For now, only accept dest "B"
	
	if not parsed.has("content"):
		if not DEBUG_DISABLED:
			print("[WebSocket] BLE forwarded command missing content field")
		return
	
	var content = parsed["content"]
	if not DEBUG_DISABLED:
		print("[WebSocket] BLE forwarded command content: ", content)
	
	# Add dest to content for UI display
	content["dest"] = dest
	
	# Emit signal for BLE ready command
	print("[WebSocket] Emitting ble_ready_command signal with content: ", content)
	ble_ready_command.emit(content)

func clear_queued_signals():
	"""Clear all queued WebSocket packets and pending bullet hit signals"""
	if not DEBUG_DISABLED:
		print("[WebSocket] Clearing queued signals and packets")
	
	# Clear all pending WebSocket packets
	var cleared_packets = 0
	while socket.get_available_packet_count() > 0:
		socket.get_packet()  # Consume and discard the packet
		cleared_packets += 1
	
	if cleared_packets > 0:
		if not DEBUG_DISABLED:
			print("[WebSocket] Cleared ", cleared_packets, " queued WebSocket packets")
	
	# Clear pending bullet hit signals
	var cleared_signals = pending_bullet_hits.size()
	pending_bullet_hits.clear()
	
	if cleared_signals > 0:
		print("[WebSocket] Cleared ", cleared_signals, " pending bullet hit signals")
	
	# Reset rate limiting timer to prevent immediate flood when re-enabled
	last_message_time = Time.get_ticks_msec() / 1000.0
	
	# Reset shot processing timer for clean restart
	last_shot_processing_time = 0.0

func set_bullet_spawning_enabled(enabled: bool):
	"""Set bullet spawning enabled state and clear queues when disabled"""
	var previous_state = bullet_spawning_enabled
	bullet_spawning_enabled = enabled
	
	if not DEBUG_DISABLED:
		print("[WebSocket] Bullet spawning enabled changed from ", previous_state, " to ", enabled)
	
	# Clear queues when disabling bullet spawning
	if not enabled and previous_state:
		clear_queued_signals()

func get_bullet_spawning_enabled() -> bool:
	"""Get current bullet spawning enabled state"""
	return bullet_spawning_enabled
