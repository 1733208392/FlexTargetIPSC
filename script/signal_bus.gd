extends Node

signal wifi_connected(ssid: String)

func emit_wifi_connected(ssid: String) -> void:
	wifi_connected.emit(ssid)
