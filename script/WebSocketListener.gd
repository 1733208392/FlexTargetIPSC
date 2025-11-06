extends Node

const DEBUG_DISABLED = true
const WEBSOCKET_URL = "ws://127.0.0.1/websocket"
#const WEBSOCKET_URL = "ws://192.168.50.22/websocket"

signal data_received(data)
signal bullet_hit(pos: Vector2)
signal menu_control(directive: String)
signal ble_ready_command(content: Dictionary)
signal ble_start_command(content: Dictionary)

var socket: WebSocketPeer
var bullet_spawning_enabled: bool = true
var prev_socket_state: int = -1
var global_data: Node

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
	var err = socket.connect_to_url(WEBSOCKET_URL)
	if err != OK:
		if not DEBUG_DISABLED:
			print("Unable to connect")
		set_process(false)
	else:
		# Set highest priority for WebSocket processing to ensure immediate message handling
		set_process_priority(100)  # Higher priority than default (0)
		if not DEBUG_DISABLED:
			print("[WebSocket] Process priority set to maximum for immediate message processing")

	# Reconnect timer for retrying closed connections
	var reconnect_timer = Timer.new()
	reconnect_timer.set_name("WebSocketReconnectTimer")
	reconnect_timer.one_shot = true
	reconnect_timer.wait_time = 2.0 # seconds; initial retry delay
	reconnect_timer.connect("timeout", Callable(self, "_on_reconnect_timer_timeout"))
	add_child(reconnect_timer)

	# Connect watchdog timer: ensures a connect attempt actually reaches OPEN within a short timeout
	var connect_watchdog = Timer.new()
	connect_watchdog.set_name("WebSocketConnectWatchdog")
	connect_watchdog.one_shot = true
	connect_watchdog.wait_time = 3.0 # seconds; watchdog timeout for connect attempts
	connect_watchdog.connect("timeout", Callable(self, "_on_connect_watchdog_timeout"))
	add_child(connect_watchdog)

	global_data = get_node("/root/GlobalData")

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	# Detect state transitions and only announce real OPEN events
	if state != prev_socket_state:
		# When transitioning to OPEN, emit onboard debug and reset reconnect backoff/timers
		if state == WebSocketPeer.STATE_OPEN:
			var open_msg = "WebSocket connection opened"
			var sb = get_node_or_null("/root/SignalBus")
			if sb:
				sb.emit_onboard_debug_info(1, open_msg, "Godot Game")
			else:
				if not DEBUG_DISABLED:
					print(open_msg)

			# Reset timing trackers and reconnect timer backoff on real open
			last_message_time = Time.get_ticks_msec() / 1000.0
			last_shot_processing_time = 0.0
			var rt = get_node_or_null("WebSocketReconnectTimer")
			if rt:
				rt.wait_time = 2.0

			# Stop the connect watchdog if it is running
			var wd = get_node_or_null("WebSocketConnectWatchdog")
			if wd and wd.is_stopped() == false:
				wd.stop()

		prev_socket_state = state
	
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
		# Emit onboard debug info about the closure
		var close_msg = "WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1]
		if not DEBUG_DISABLED:
			print(close_msg)

		var sb = get_node_or_null("/root/SignalBus")
		if sb:
			sb.emit_onboard_debug_info(3, close_msg, "Websocket Listener")
		else:
			if not DEBUG_DISABLED:
				print("[WebSocket] SignalBus not available - close debug: ", close_msg)

		# Attempt immediate reconnect and schedule retries
		_attempt_reconnect()
		set_process(false) # Stop processing until reconnect attempt

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
	# Handle telemetry data
	if parsed and parsed.has("type") and parsed["type"] == "telemetry" and parsed.has("data"):
		var telemetry = parsed["data"]
		var telemetry_str = JSON.stringify(telemetry)
		var msg = "WebSocket telemetry received: " + telemetry_str
		var sb = get_node_or_null("/root/SignalBus")
		if sb:
			sb.emit_onboard_debug_info(2, msg, "WebSocket Listener")
		else:
			print(msg)
		return
	
	# print("[WebSocket] Parsed data: ", parsed)
	# Handle control directive
	if parsed and parsed.has("type") and parsed["type"] == "control" and parsed.has("directive"):
		if not DEBUG_DISABLED:
			print("[WebSocket] Emitting menu_control with directive: ", parsed["directive"])
		menu_control.emit(parsed["directive"])
		return
	
	# Handle BLE forwarded commands
	if parsed and parsed.has("type") and parsed["type"] == "netlink" and parsed.has("data"):
		_handle_ble_forwarded_command(parsed.data)
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
					if not DEBUG_DISABLED: print("[WebSocket] Raw position: Vector2(", x, ", ", y, ") -> Transformed: ", transformed_pos)
					bullet_hit.emit(transformed_pos)
				else:
					# When disabled, don't add to pending queue - just ignore
					pass
					if not DEBUG_DISABLED: print("[WebSocket] Bullet spawning disabled, ignoring hit at: Vector2(", x, ", ", y, ")")
			else:
				if not DEBUG_DISABLED:
					print("[WebSocket] Entry missing x or y: ", entry)

func _handle_ble_forwarded_command(parsed):
	"""Handle BLE forwarded commands"""
	var sb = get_node_or_null("/root/SignalBus")
	
	# The new format has data directly as the command content, no dest/content wrapper
	var content = parsed
	if not DEBUG_DISABLED:
		print("[WebSocket] BLE forwarded command content: ", content)

	# Emit onboard debug info for forwarded BLE commands (sender: Mobile App)
	var content_str = JSON.stringify(content)
	if sb:
		sb.emit_onboard_debug_info(2, "BLE forwarded: " + content_str, "Mobile App")
	else:
		if not DEBUG_DISABLED:
			print("[WebSocket] SignalBus not available - BLE forwarded debug: ", content_str)

	#     let content: [String: Any] = [
	#     "command": "ready"/"start",
	#     "delay": delay,
	#     "targetType": target.targetType ?? "",
	#     "timeout": target.timeout,
	#     "countedShots": target.countedShots]

	# Determine command type from content. Common keys: 'command', 'cmd', or 'type'
	var command = null

	command = content["command"]

	if not DEBUG_DISABLED:
		print("[WebSocket] BLE forwarded command determined command: ", command)

	# Emit the appropriate signal based on the command value
	match command:
		"ready":
			if not DEBUG_DISABLED: print("[WebSocket] Emitting ble_ready_command signal with content: ", content)
			ble_ready_command.emit(content)
		"start":
			if not DEBUG_DISABLED: print("[WebSocket] Emitting ble_start_command signal with content: ", content)
			ble_start_command.emit(content)
		_:
			if not DEBUG_DISABLED:
				print("[WebSocket] BLE forwarded command unknown or unsupported command: ", command)

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
		if not DEBUG_DISABLED: print("[WebSocket] Cleared ", cleared_signals, " pending bullet hit signals")
	
	# Reset rate limiting timer to prevent immediate flood when re-enabled
	last_message_time = Time.get_ticks_msec() / 1000.0
	
	# Reset shot processing timer for clean restart
	last_shot_processing_time = 0.0

func send_netlink_forward(device: String, content_val: Dictionary) -> int:
	"""Helper to send a netlink forward message over the websocket socket.
	Returns OK on success, or the error code otherwise."""
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var ack_message = {
			"type": "netlink",
			"action": "forward",
			"device": device,
			"content": content_val
		}
		var json_string = JSON.stringify(ack_message)
		var err = socket.send_text(json_string)
		if err != OK:
			if not DEBUG_DISABLED:
				print("[WebSocket] send_netlink_forward failed: ", err)
			return err
		if not DEBUG_DISABLED:
			print("[WebSocket] send_netlink_forward sent: ", json_string)

		# Emit onboard debug info for outgoing netlink forwards (sender: Godot Game)
		var sb = get_node_or_null("/root/SignalBus")
		if sb:
			sb.emit_onboard_debug_info(1, "Netlink forward sent to device: " + str(device) + ", content: " + json_string, "Godot Game")
		else:
			if not DEBUG_DISABLED:
				print("[WebSocket] SignalBus not available - netlink forward debug: ", json_string)
		return OK
	else:
		if not DEBUG_DISABLED:
			print("[WebSocket] send_netlink_forward: socket not available or not open")
		return ERR_UNAVAILABLE

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


func _attempt_reconnect() -> void:
	"""Try to reopen the websocket connection immediately. If it fails, schedule the reconnect timer."""
	if not DEBUG_DISABLED:
		print("[WebSocket] Attempting reconnect...")

		# Try to create a fresh WebSocketPeer and initiate connection
		var new_socket = WebSocketPeer.new()
		var err = new_socket.connect_to_url(WEBSOCKET_URL)

		# If connect_to_url returns OK it means the connection process started successfully
		if err == OK:
			socket = new_socket
			# Enable processing so poll() can drive the connection state machine
			set_process(true)
			if not DEBUG_DISABLED:
				print("[WebSocket] Reconnect attempt started (connection in progress)")

			# Start the connect watchdog to ensure the connect finishes in a timely manner
			var watchdog = get_node_or_null("WebSocketConnectWatchdog")
			if watchdog:
				watchdog.start()
			return

		# If connect_to_url returned an error, schedule retry with backoff
		var timer = get_node_or_null("WebSocketReconnectTimer")
		if timer:
			var next = clamp(timer.wait_time * 2.0, 2.0, 60.0)
			timer.wait_time = next
			if not DEBUG_DISABLED:
				print("[WebSocket] Reconnect attempt failed to start (err=", err, ") - scheduling retry in ", timer.wait_time, "s")
			timer.start()


func _on_reconnect_timer_timeout() -> void:
	"""Handler called when reconnect timer fires; attempt reconnect."""
	_attempt_reconnect()


func _on_connect_watchdog_timeout() -> void:
	"""Called when a connect attempt didn't reach OPEN within the watchdog timeout.
	Schedules backoff retry and emits onboard debug info."""
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# Connection succeeded just before watchdog fired; nothing to do
		if not DEBUG_DISABLED:
			print("[WebSocket] Connect watchdog fired but socket already OPEN")
		return

	# Not open: schedule backoff retry
	var timer = get_node_or_null("WebSocketReconnectTimer")
	if timer:
		var next = clamp(timer.wait_time * 2.0, 2.0, 60.0)
		timer.wait_time = next
		if not DEBUG_DISABLED:
			print("[WebSocket] Connect watchdog timeout - scheduling retry in ", timer.wait_time, "s")
		timer.start()

	# Emit onboard debug info about the connect timeout
	var sb = get_node_or_null("/root/SignalBus")
	var msg = "WebSocket connect watchdog timeout: connection did not reach OPEN"
	if sb:
		sb.emit_onboard_debug_info(3, msg, "Websocket Listener")
	else:
		if not DEBUG_DISABLED:
			print("[WebSocket] SignalBus not available - watchdog timeout: ", msg)
