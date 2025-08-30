extends Control

@onready var start_button = $VBoxContainer/ipsc
@onready var bootcamp_button = $VBoxContainer/boot_camp
@onready var option_button = $VBoxContainer/option

var focused_index
var buttons = []

func _ready():
	# Connect button signals
	focused_index = 0
	buttons = [
		start_button,
		bootcamp_button,
		option_button]
		
	buttons[focused_index].grab_focus()

		# Use get_node instead of Engine.has_singleton
	var ws_listener = get_node("/root/WebSocketListener")
	if ws_listener:
		print("[Menu] Connecting to WebSocketListener.menu_control signal")
		ws_listener.menu_control.connect(_on_menu_control)
	else:
		print("[Menu] WebSocketListener singleton not found!")

	start_button.pressed.connect(on_StartButton_pressed)
	bootcamp_button.pressed.connect(_on_bootcamp_pressed)
	option_button.pressed.connect(_on_option_pressed)

func _on_menu_control(directive: String):
	print("[Menu] Received menu_control signal with directive: ", directive)
	match directive:
		"up":
			print("[Menu] Moving focus up")
			focused_index = (focused_index - 1) % buttons.size()
			buttons[focused_index].grab_focus()
		"down":
			print("[Menu] Moving focus down")
			focused_index = (focused_index + 1) % buttons.size()
			buttons[focused_index].grab_focus()
		"enter":
			print("[Menu] Simulating button press")
			buttons[focused_index].pressed.emit()
		"volume_up":
			print("[Menu] Volume up (TBD)")
		"volume_down":
			print("[Menu] Volume down (TBD)")
		"power":
			print("[Menu] Power off (TBD)")
		_:
			print("[Menu] Unknown directive: ", directive)

func on_StartButton_pressed():
	
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_start_game_response)
	else:
		print("[Menu] HttpService singleton not found!")

func _on_start_game_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Menu] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		print("[Menu] Start game success, changing scene.")
		get_tree().change_scene_to_file("res://scene/drills.tscn")
	else:
		print("[Menu] Start game failed or invalid response.")

func _on_start_pressed():
	print("Start button pressed - Load main game")
	get_tree().change_scene_to_file("res://scene/intro.tscn")

func _on_bootcamp_pressed():
	# TODO: Load the boot camp/training scene
	print("Boot Camp button pressed - Load training mode")
	get_tree().change_scene_to_file("res://scene/bootcamp.tscn")

func _on_option_pressed():
	# Load the options scene
	get_tree().change_scene_to_file("res://scene/option.tscn")


func _on_ipsc_pressed() -> void:
	print("Start button pressed - Load main game")
	get_tree().change_scene_to_file("res://scene/drills.tscn")
