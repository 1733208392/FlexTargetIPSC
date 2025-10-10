extends CanvasLayer

const WIFI_IDLE := preload("res://asset/wifi.fill.idle.png")
const WIFI_CONNECTED := preload("res://asset/wifi.fill.connect.png")
const NET_IDLE := preload("res://asset/connectivity.idle.png")
const NET_CONNECTED := preload("res://asset/connectivity.active.png")

@onready var wifi_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/WifiIcon")
@onready var network_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/ConnectivityIcon")
@onready var root_control: Control = get_node_or_null("Root")

func _ready() -> void:
	add_to_group("status_bar")
	_set_wifi_connected(false)
	_set_network_started(false)
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if not signal_bus.wifi_connected.is_connected(_on_wifi_connected):
			signal_bus.wifi_connected.connect(_on_wifi_connected)
			print("StatusBar: Connected to SignalBus wifi_connected signal")
		else:
			print("StatusBar: Already connected to SignalBus wifi_connected signal")
		
		if not signal_bus.network_started.is_connected(_on_network_started):
			signal_bus.network_started.connect(_on_network_started)
			print("StatusBar: Connected to SignalBus network_started signal")
		else:
			print("StatusBar: Already connected to SignalBus network_started signal")
	else:
		print("StatusBar: SignalBus not found")
	
	# Update size after frame
	call_deferred("_update_size")
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _exit_tree() -> void:
	var signal_bus = get_node_or_null("/root/SignalBus")
	
	if signal_bus and signal_bus.wifi_connected.is_connected(_on_wifi_connected):
		signal_bus.wifi_connected.disconnect(_on_wifi_connected)

	if signal_bus and signal_bus.network_started.is_connected(_on_network_started):
		signal_bus.network_started.disconnect(_on_network_started)

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

func _on_network_started() -> void:
	print("StatusBar: Received network started signal")
	_set_network_started(true)

func _set_network_started(connected: bool) -> void:
	print("StatusBar: _set_network_started called, connected=", connected)
	if network_icon:
		network_icon.texture = NET_CONNECTED if connected else NET_IDLE
	else:
		print("StatusBar: network_icon NOT found.")
