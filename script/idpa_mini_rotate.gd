extends Node2D

const DEBUG_DISABLE = true

signal target_hit(zone: String, points: int, hit_position: Vector2)

var drill_active: bool = false:
	set(value):
		drill_active = value
		# Propagate to child IPSCMini
		var idpa = get_node_or_null("RotationCenter/IDPA")
		if idpa:
			idpa.drill_active = value
			if value:
				if not DEBUG_DISABLE: print("[idpa_rotate] Enabled drill_active on child IDPA Target")
			else:
				if not DEBUG_DISABLE: print("[idpa_rotate] Disabled drill_active on child IDPA Target")

func _ready():
	# Initialize drill_active to false by default
	drill_active = false
	
	# Get animation player and start continuous random animation sequence
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		if not DEBUG_DISABLE: print("[idpa_rotation] Starting continuous random animation sequence")
		_play_random_animations_continuous(animation_player)
	
	# Connect to child's target_hit signal and forward it
	var ipsc_mini = get_node_or_null("RotationCenter/IDPA")
	if ipsc_mini and ipsc_mini.has_signal("target_hit"):
		ipsc_mini.target_hit.connect(_on_child_target_hit)
		if not DEBUG_DISABLE: print("[idpa_rotate] Connected to child IDPA's target_hit signal")

func _play_random_animations_continuous(animation_player: AnimationPlayer):
	"""Continuously play random sequences of the 3 animations"""
	while true:
		var animations = ["left", "up", "right"]
		animations.shuffle()  # Randomize the order each sequence
		
		for anim in animations:
			animation_player.play(anim)
			if not DEBUG_DISABLE: print("[idpa_rotate] Playing animation: %s" % anim)
			await animation_player.animation_finished

func _on_child_target_hit(zone: String, points: int, hit_position: Vector2):
	# Forward the signal from child to root
	target_hit.emit(zone, points, hit_position)
