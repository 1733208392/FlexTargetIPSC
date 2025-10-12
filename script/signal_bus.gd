extends Node

signal wifi_connected(ssid: String)
signal network_started()
signal onboard_debug_info(priority: int, content: String, sender: String)

func emit_wifi_connected(ssid: String) -> void:
	wifi_connected.emit(ssid)

func emit_network_started() -> void:
	print("SignalBus: emit_network_started called")
	network_started.emit()

func emit_onboard_debug_info(priority: int, content: String, sender: String) -> void:
	# Emit structured onboard debug information for listeners
	onboard_debug_info.emit(priority, content, sender)