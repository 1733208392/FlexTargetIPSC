extends Node

signal wifi_connected(ssid: String)
signal network_started()

func emit_wifi_connected(ssid: String) -> void:
	wifi_connected.emit(ssid)

func emit_network_started() -> void:
	print("SignalBus: emit_network_started called")
	network_started.emit()