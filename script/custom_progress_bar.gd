extends Control

@onready var skew_shader = preload("res://shader/skew_shader.gdshader")

func _ready():
	# Apply skew shader to all SkewedBar nodes
	var progress_segments = $ProgressContainer/ProgressSegments
	for segment in progress_segments.get_children():
		if segment.name.begins_with("Segment"):
			for child in segment.get_children():
				if child.name.begins_with("SkewedBar"):
					var shader_material = ShaderMaterial.new()
					shader_material.shader = skew_shader
					shader_material.set_shader_parameter("skew_amount", -0.3)  # Increased skew amount for more angle
					child.material = shader_material
