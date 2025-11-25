extends Node2D

@onready var animated_sprite = $AnimatedSprite2D

var is_moving_left = true
var original_x

func _ready():
	$AnimatedSprite2D/Area2D.connect("input_event", Callable(self, "_on_sprite_input_event"))
	original_x = animated_sprite.position.x

func _on_sprite_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tween = create_tween()
		if is_moving_left:
			animated_sprite.play()
			tween.tween_property(animated_sprite, "position:x", original_x + 200, 0.5)
		else:
			animated_sprite.play_backwards()
			tween.tween_property(animated_sprite, "position:x", original_x, 0.5)
		is_moving_left = not is_moving_left
