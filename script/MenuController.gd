extends Node

# Global Menu Controller Singleton
# Handles remote control directives from WebSocketListener
# Emits signals that scenes can connect to for menu control

signal navigate(direction: String)
signal enter_pressed
signal back_pressed
signal volume_up_requested
signal volume_down_requested
signal power_off_requested
signal menu_control(directive: String)  # For compatibility with onscreen keyboard

var http_service = null

func _ready():
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		# print("[MenuController] Connected to WebSocketListener.menu_control signal")
	else:
		# print("[MenuController] WebSocketListener singleton not found!")
		pass
	
	# Get HttpService reference
	http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		# print("[MenuController] HttpService singleton not found!")
		pass

func _on_menu_control(directive: String):
	# print("[MenuController] Received directive: ", directive)
	
	# Emit the menu_control signal for compatibility with onscreen keyboard
	menu_control.emit(directive)
	
	match directive:
		"up", "down", "left", "right":
			navigate.emit(directive)
		"enter":
			enter_pressed.emit()
		"back", "homepage":
			back_pressed.emit()
		"volume_up":
			volume_up_requested.emit()
			_handle_volume_up()
		"volume_down":
			volume_down_requested.emit()
			_handle_volume_down()
		"power":
			power_off_requested.emit()
			_handle_power_off()
		_:
			# print("[MenuController] Unknown directive: ", directive)
			pass

func _handle_volume_up():
	if http_service:
		# print("[MenuController] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response.bind("up"))
	else:
		# print("[MenuController] HttpService not available for volume up")
		pass

func _handle_volume_down():
	if http_service:
		# print("[MenuController] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response.bind("down"))
	else:
		# print("[MenuController] HttpService not available for volume down")
		pass

func _handle_power_off():
	if http_service:
		# print("[MenuController] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		# print("[MenuController] HttpService not available for power off")
		pass

func _on_volume_response(_direction: String, _result, _response_code, _headers, _body):
	var _body_str = _body.get_string_from_utf8()
	# print("[MenuController] Volume ", direction, " HTTP response:", _result, response_code, body_str)

func _on_shutdown_response(_result, _response_code, _headers, _body):
	var _body_str = _body.get_string_from_utf8()
	# print("[MenuController] Shutdown HTTP response:", _result, response_code, body_str)
