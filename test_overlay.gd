extends Control

func _ready():
	print("=== TEST OVERLAY READY ===")
	var timer = $Timer
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	print("=== SHOWING DRILL COMPLETE OVERLAY ===")
	var overlay = $drill_complete_overlay
	if overlay and overlay.has_method("show_drill_complete"):
		overlay.show_drill_complete(100, 25.5, 1.2)
		print("=== OVERLAY SHOWN ===")
	else:
		print("=== ERROR: OVERLAY NOT FOUND OR MISSING METHOD ===")