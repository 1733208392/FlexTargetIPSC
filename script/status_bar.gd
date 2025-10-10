extends CanvasLayer

const WIFI_IDLE := preload("res://asset/wifi.fill.idle.png")
const WIFI_CONNECTED := preload("res://asset/wifi.fill.connect.png")

@onready var wifi_icon: TextureRect = $Root/Panel/HBoxContainer/WifiIcon
@onready var root_control: Control = $Root

func _ready() -> void:
	add_to_group("status_bar")
	_set_wifi_connected(false)
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if not signal_bus.wifi_connected.is_connected(_on_wifi_connected):
			signal_bus.wifi_connected.connect(_on_wifi_connected)
			print("StatusBar: Connected to SignalBus wifi_connected signal")
		else:
			print("StatusBar: Already connected to SignalBus wifi_connected signal")
	else:
		print("StatusBar: SignalBus not found")
	
	# Update size after frame
	call_deferred("_update_size")
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _exit_tree() -> void:
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus and signal_bus.wifi_connected.is_connected(_on_wifi_connected):
		signal_bus.wifi_connected.disconnect(_on_wifi_connected)

func _on_viewport_size_changed() -> void:
	_update_size()

func _update_size() -> void:
	var window_size = DisplayServer.window_get_size()
	root_control.size.x = window_size.x
	root_control.size.y = 72.0
	print("StatusBar: Updated size to ", root_control.size)

func _on_wifi_connected(_ssid: String) -> void:
	print("StatusBar: Received wifi_connected signal for SSID: ", _ssid)
	_set_wifi_connected(true)

func _set_wifi_connected(connected: bool) -> void:
	if wifi_icon:
		wifi_icon.texture = WIFI_CONNECTED if connected else WIFI_IDLE
