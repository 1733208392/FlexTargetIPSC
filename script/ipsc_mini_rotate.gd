extends Node2D

signal target_hit(zone: String, points: int, hit_position: Vector2)

var drill_active: bool = false:
	set(value):
		drill_active = value
		# Propagate to child IPSCMini
		var ipsc_mini = get_node_or_null("RotationCenter/IPSCMini")
		if ipsc_mini:
			ipsc_mini.drill_active = value
			if value:
				print("[ipsc_mini_rotate] Enabled drill_active on child IPSCMini")
			else:
				print("[ipsc_mini_rotate] Disabled drill_active on child IPSCMini")

func _ready():
	# Initialize drill_active to false by default
	drill_active = false
	
	# Connect to child's target_hit signal and forward it
	var ipsc_mini = get_node_or_null("RotationCenter/IPSCMini")
	if ipsc_mini and ipsc_mini.has_signal("target_hit"):
		ipsc_mini.target_hit.connect(_on_child_target_hit)
		print("[ipsc_mini_rotate] Connected to child IPSCMini's target_hit signal")

func _on_child_target_hit(zone: String, points: int, hit_position: Vector2):
	# Forward the signal from child to root
	target_hit.emit(zone, points, hit_position)
