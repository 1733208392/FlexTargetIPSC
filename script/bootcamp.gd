extends Node2D

@onready var ipsc = $IPSC
@onready var shot_labels = []
@onready var clear_button = $CanvasLayer/Control/BottomContainer/ClearButton

var shot_times = []

func _ready():
	# Disable disappearing for bootcamp
	ipsc.max_shots = 1000
	
	# Connect to ipsc target_hit signal
	ipsc.target_hit.connect(_on_target_hit)
	
	# Connect clear button
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	else:
		print("ERROR: ClearButton not found!")
	
	# Get all shot labels
	for i in range(1, 21):
		var label = get_node("CanvasLayer/Control/ShotIntervalsOverlay/Shot" + str(i))
		if label:
			shot_labels.append(label)
			label.text = ""
		else:
			print("ERROR: Shot" + str(i) + " not found!")
	
	# Set clear button as default focus
	clear_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[Bootcamp] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[Bootcamp] WebSocketListener singleton not found!")

func _on_target_hit(_zone: String, _points: int, _hit_position: Vector2):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	shot_times.append(current_time)
	
	if shot_times.size() > 1:
		var time_diff = shot_times[-1] - shot_times[-2]
		_update_shot_list("+%.2fs" % time_diff)
	else:
		_update_shot_list("First shot")

func _update_shot_list(new_text: String):
	# Shift the list
	for i in range(shot_labels.size() - 1, 0, -1):
		shot_labels[i].text = shot_labels[i-1].text
	shot_labels[0].text = new_text

func _on_clear_pressed():
	# Clear shot list
	for label in shot_labels:
		label.text = ""
	shot_times.clear()
	
	# Clear bullet holes - get all children and check if they're bullet holes
	var children_to_remove = []
	for child in ipsc.get_children():
		# Check if it's a bullet hole (Sprite2D with bullet hole script)
		if child is Sprite2D and child.has_method("set_hole_position"):
			children_to_remove.append(child)
	
	# Remove all bullet holes
	for bullet_hole in children_to_remove:
		bullet_hole.queue_free()
		print("Removed bullet hole: ", bullet_hole.name)

func _on_menu_control(directive: String):
	print("[Bootcamp] Received menu_control signal with directive: ", directive)
	match directive:
		"enter":
			print("[Bootcamp] Enter pressed")
			_on_clear_pressed()
		"back", "homepage":
			print("[Bootcamp] ", directive, " - navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		"volume_up":
			print("[Bootcamp] Volume up")
			volume_up()
		"volume_down":
			print("[Bootcamp] Volume down")
			volume_down()
		"power":
			print("[Bootcamp] Power off")
			power_off()
		_:
			print("[Bootcamp] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Bootcamp] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		print("[Bootcamp] HttpService singleton not found!")

func _on_volume_up_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Bootcamp] Volume up HTTP response:", result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Bootcamp] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		print("[Bootcamp] HttpService singleton not found!")

func _on_volume_down_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Bootcamp] Volume down HTTP response:", result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[Bootcamp] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		print("[Bootcamp] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, headers, body):
	var body_str = body.get_string_from_utf8()
	print("[Bootcamp] Shutdown HTTP response:", result, response_code, body_str)
