extends Node2D

# This script allows the composed IDPA scene to receive and forward WebSocket bullet hits
# to the contained IDPA and IDPA-NS targets

# Shot tracking
@export var max_shots: int = 2  # Default maximum shots before whole composition disappears
var total_shots: int = 0
signal composition_disappeared

var drill_active: bool = false:
	set(value):
		drill_active = value
		# Propagate to child targets so they process WebSocket hits correctly
		_propagate_drill_active(value)

var DEBUG_DISABLED: bool = false
var idpa_target: Node
var idpa_ns_target: Node

func _propagate_drill_active(value: bool) -> void:
	"""Propagate drill_active to all child targets"""
	# Try to get targets if not already cached
	if not idpa_target:
		idpa_target = get_node_or_null("IDPA")
	if not idpa_ns_target:
		idpa_ns_target = get_node_or_null("IDPA-NS")
	
	# Set on both targets
	if idpa_target:
		idpa_target.set("drill_active", value)
		if not DEBUG_DISABLED:
			print("[IDPA-Compose] Set drill_active=", value, " on IDPA")
	
	if idpa_ns_target:
		idpa_ns_target.set("drill_active", value)
		if not DEBUG_DISABLED:
			print("[IDPA-Compose] Set drill_active=", value, " on IDPA-NS")

func _ready() -> void:
	# Get references to the instantiated targets
	idpa_target = get_node_or_null("IDPA")
	idpa_ns_target = get_node_or_null("IDPA-NS")
	
	if not DEBUG_DISABLED:
		print("[IDPA-Compose] _ready() called")
	
	if not idpa_target:
		print("[IDPA-Compose] ERROR: Could not find IDPA target!")
	if not idpa_ns_target:
		print("[IDPA-Compose] ERROR: Could not find IDPA-NS target!")
	
	# Only track IDPA-NS hits (they block overlapped areas naturally)
	if idpa_ns_target and idpa_ns_target.has_signal("target_hit"):
		idpa_ns_target.target_hit.connect(_on_shot_detected)
	
	# Also track IDPA hits (for non-overlapped areas)
	if idpa_target and idpa_target.has_signal("target_hit"):
		idpa_target.target_hit.connect(_on_shot_detected)
	
	# Propagate current drill_active state to children
	_propagate_drill_active(drill_active)

func _on_shot_detected(_zone: String, _points: int, _hit_position: Vector2) -> void:
	"""Simple handler for any shot - just count it"""
	total_shots += 1
	if not DEBUG_DISABLED:
		print("[IDPA-Compose] Shot detected. Total: ", total_shots, "/", max_shots)
	
	# Check if we've reached max shots
	if total_shots >= max_shots:
		if not DEBUG_DISABLED:
			print("[IDPA-Compose] Max shots reached! Disappearing")
		play_disappearing_animation()

func play_disappearing_animation() -> void:
	"""Play disappearing animation for the whole composition"""
	# Create a simple fade-out tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)
	
	# Fade out over 0.5 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	
	# Emit signal and queue for deletion
	await tween.finished
	composition_disappeared.emit()
	queue_free()
