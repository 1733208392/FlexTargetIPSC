extends Control

@onready var save_button = $VBoxContainer/SaveButton
@onready var load_button = $VBoxContainer/LoadButton
@onready var response_text = $VBoxContainer/ResponseText

var current_focused_button = 0  # 0 for save, 1 for load

func _ready():
	# Connect buttons
	if save_button:
		save_button.focus_mode = Control.FOCUS_ALL
	if load_button:
		load_button.focus_mode = Control.FOCUS_ALL
	
	# Set initial focus
	set_focus_to_button(0)
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[TestHttp] Connected to WebSocketListener")
	else:
		print("[TestHttp] WebSocketListener not found")

func set_focus_to_button(index: int):
	current_focused_button = index
	if index == 0 and save_button:
		save_button.grab_focus()
	elif index == 1 and load_button:
		load_button.grab_focus()

func _on_menu_control(directive: String):
	print("[TestHttp] Received directive: ", directive)
	match directive:
		"up", "down":
			toggle_focus()
		"enter":
			perform_action()
		_:
			print("[TestHttp] Unknown directive: ", directive)

func toggle_focus():
	if current_focused_button == 0:
		set_focus_to_button(1)
	else:
		set_focus_to_button(0)

func perform_action():
	if current_focused_button == 0:
		save_settings()
	else:
		load_settings()

func save_settings():
	var file = FileAccess.open("res://asset/settings.json", FileAccess.READ)
	if not file:
		response_text.text = "Failed to open settings.json"
		return
	
	var content = file.get_as_text()
	file.close()
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		response_text.text = "Sending save request..."
		http_service.save_game(_on_save_response, "settings", content)
	else:
		response_text.text = "HttpService not found"

func _on_save_response(result, response_code, headers, body):
	var response_str = "Save Response:\nResult: %d\nCode: %d\nBody: %s" % [result, response_code, body.get_string_from_utf8()]
	response_text.text = response_str
	print("[TestHttp] Save response: ", response_str)

func load_settings():
	var http_service = get_node("/root/HttpService")
	if http_service:
		response_text.text = "Sending load request..."
		http_service.load_game(_on_load_response, "settings")
	else:
		response_text.text = "HttpService not found"

func _on_load_response(result, response_code, headers, body):
	var response_str = "Load Response:\nResult: %d\nCode: %d\nBody: %s" % [result, response_code, body.get_string_from_utf8()]
	response_text.text = response_str
	print("[TestHttp] Load response: ", response_str)
