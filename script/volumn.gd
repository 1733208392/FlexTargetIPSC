extends Control

@onready var progress_bar: ProgressBar = $VolumeContainer/ProgressBar
@onready var hide_timer: Timer = Timer.new()

var current_volume: float = 50.0  # Default volume level (0-100)

func _ready():
	# Setup the hide timer
	add_child(hide_timer)
	hide_timer.wait_time = 5.0
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	
	# Connect to WebSocket menu control signals
	var websocket_listener = get_node("/root/WebSocketListener")
	if websocket_listener:
		websocket_listener.menu_control.connect(_on_menu_control)
		print("[VolumeControl] Connected to WebSocketListener")
	else:
		print("[VolumeControl] Warning: WebSocketListener not found")
	
	# Initialize progress bar
	progress_bar.value = current_volume
	
	# Start hidden
	visible = false

func _on_menu_control(directive: String):
	# Only handle volume-related directives to avoid interference
	if directive == "volume_up":
		_increase_volume()
	elif directive == "volume_down":
		_decrease_volume()

func _increase_volume():
	print("[VolumeControl] Volume increase")
	current_volume = min(current_volume + 10.0, 100.0)
	_update_volume_display()
	
	# Call HttpService volume_up
	var http_service = get_node("/root/HttpService")
	if http_service:
		http_service.volume_up(_on_volume_response)

func _decrease_volume():
	print("[VolumeControl] Volume decrease")
	current_volume = max(current_volume - 10.0, 0.0)
	_update_volume_display()
	
	# Call HttpService volume_down
	var http_service = get_node("/root/HttpService")
	if http_service:
		http_service.volume_down(_on_volume_response)

func _update_volume_display():
	# Update progress bar
	progress_bar.value = current_volume
	
	# Show the volume control
	visible = true
	
	# Restart the hide timer
	hide_timer.stop()
	hide_timer.start()
	
	print("[VolumeControl] Volume updated to: ", current_volume, "%")

func _on_hide_timer_timeout():
	print("[VolumeControl] Hiding volume control after timeout")
	visible = false

func _on_volume_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("[VolumeControl] Volume command response: ", response_code)