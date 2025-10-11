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

	# Listen for netlink status updates so UI can reflect started state
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		var cb = Callable(self, "_on_netlink_status_loaded")
		if not global_data.is_connected("netlink_status_loaded", cb):
			global_data.connect("netlink_status_loaded", cb)
			print("StatusBar: Connected to GlobalData.netlink_status_loaded signal")
		else:
			print("StatusBar: Already connected to GlobalData.netlink_status_loaded signal")
	else:
		print("StatusBar: GlobalData singleton not found; cannot listen for netlink status updates")

	# ...existing code...

func _enter_tree() -> void:
	# Called earlier than _ready, request netlink status as soon as this node enters the SceneTree
	if has_node("/root/HttpService"):
		print("StatusBar: Requesting netlink status from HttpService at _enter_tree")
		HttpService.netlink_status(Callable(self, "_on_netlink_status_response"))
	else:
		print("StatusBar: HttpService autoload not found at _enter_tree, skipping netlink status request")

func _exit_tree() -> void:
	var signal_bus = get_node_or_null("/root/SignalBus")
	
	if signal_bus and signal_bus.wifi_connected.is_connected(_on_wifi_connected):
		signal_bus.wifi_connected.disconnect(_on_wifi_connected)

	if signal_bus and signal_bus.network_started.is_connected(_on_network_started):
		signal_bus.network_started.disconnect(_on_network_started)

	# Disconnect GlobalData signal
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		var cb = Callable(self, "_on_netlink_status_loaded")
		if global_data.is_connected("netlink_status_loaded", cb):
			global_data.disconnect("netlink_status_loaded", cb)

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

func _on_netlink_status_response(result, response_code, headers, body):
	print("StatusBar: netlink_status response - code:", response_code)
	# Forward to GlobalData to parse and store
	if has_node("/root/GlobalData"):
		GlobalData.update_netlink_status_from_response(result, response_code, headers, body)
	else:
		print("StatusBar: GlobalData singleton not found; cannot store netlink status")

func _on_netlink_status_loaded():
	print("StatusBar: Received GlobalData.netlink_status_loaded signal")
	var gd = get_node_or_null("/root/GlobalData")
	if not gd:
		print("StatusBar: GlobalData not found in _on_netlink_status_loaded")
		return

	var s = gd.netlink_status
	if s and typeof(s) == TYPE_DICTIONARY and s.has("started"):
		var started = bool(s.get("started", false))
		print("StatusBar: netlink started=", started)
		if started:
			_set_wifi_connected(true)
			_set_network_started(true)
		else:
			# Optional: set to false if not started
			_set_network_started(false)
			_set_wifi_connected(false)
			print("StatusBar: netlink not started, setting icons to idle")
	else:
		print("StatusBar: netlink_status missing 'started' field or invalid: ", s)
