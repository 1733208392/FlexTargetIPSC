extends Control

@onready var skew_shader = preload("res://shader/skew_shader.gdshader")
@onready var progress_segments = $ProgressContainer/ProgressSegments

# Progress configuration
const TOTAL_SEGMENTS = 15
const TOTAL_TARGETS = 5
const SEGMENTS_PER_TARGET = 3  # 15 segments / 5 targets = 3 segments per target

# Colors for progress states
const ACTIVE_COLOR = Color(1.0, 0.6, 0.0, 1.0)  # Orange
const INACTIVE_COLOR = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray

func _ready():
	# Apply skew shader to all SkewedBar nodes
	for segment in progress_segments.get_children():
		if segment.name.begins_with("Segment"):
			for child in segment.get_children():
				if child.name.begins_with("SkewedBar"):
					var shader_material = ShaderMaterial.new()
					shader_material.shader = skew_shader
					shader_material.set_shader_parameter("skew_amount", -0.3)  # Increased skew amount for more angle
					child.material = shader_material
	
	# Initialize with all segments inactive
	update_progress(0)

func update_progress(targets_completed: int):
	"""Update progress bar based on number of targets completed (0-5)"""
	var active_segments = min(targets_completed * SEGMENTS_PER_TARGET, TOTAL_SEGMENTS)
	
	# Update each segment's color based on progress
	for i in range(TOTAL_SEGMENTS):
		var segment = progress_segments.get_child(i)
		if segment and segment.name.begins_with("Segment"):
			var bar_node = segment.get_node("SkewedBar" + str(i + 1))
			if bar_node:
				if i < active_segments:
					bar_node.color = ACTIVE_COLOR  # Active/completed
				else:
					bar_node.color = INACTIVE_COLOR  # Inactive/not completed
	
	print("Progress updated: ", targets_completed, "/", TOTAL_TARGETS, " targets (", active_segments, "/", TOTAL_SEGMENTS, " segments)")

func reset_progress():
	"""Reset progress bar to empty state"""
	update_progress(0)
