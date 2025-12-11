extends Node2D

@export var radius: float = 30.0
@export var pulse_speed: float = 3.0
@export var highlight_color: Color = Color(1.0, 0.8, 0.2, 1.0)
@export var fade_color: Color = Color(1.0, 0.6, 0.1, 0.4)

var time: float = 0.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var t = (sin(time * pulse_speed) + 1.0) * 0.5
	var draw_scale = 0.85 + t * 0.25
	var alpha = 0.35 + t * 0.4
	draw_circle(Vector2.ZERO, radius * draw_scale, Color(highlight_color.r, highlight_color.g, highlight_color.b, alpha))
	draw_circle(Vector2.ZERO, radius * draw_scale * 0.6, Color(fade_color.r, fade_color.g, fade_color.b, alpha * 0.6))
