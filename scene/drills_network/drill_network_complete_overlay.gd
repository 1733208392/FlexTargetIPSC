extends Control

# Simple overlay that just shows "Drill ENDs" when network drill completes

func _ready():
	"""Initialize the drill network complete overlay"""
	# Make sure we're initially hidden
	visible = false

func show_completion():
	"""Show the drill network completion overlay"""
	visible = true
	print("[drill_network_complete_overlay] Network drill completion overlay shown")

func hide_completion():
	"""Hide the drill network completion overlay"""
	visible = false
	print("[drill_network_complete_overlay] Network drill completion overlay hidden")
