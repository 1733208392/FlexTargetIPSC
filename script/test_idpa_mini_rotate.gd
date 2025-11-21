extends Node2D

func _ready():
	var mini_rotate = get_node("IDPAMiniRotate")
	if mini_rotate:
		mini_rotate.drill_active = true
		print("[test_idpa_mini_rotate] Set drill_active to true")
