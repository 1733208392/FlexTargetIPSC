extends Node2D

@export var viewport_node: NodePath = NodePath("../CanvasLayer")
@export var thumbnail_target_pos: Vector2 = Vector2(80, 520)
@export var flash_duration: float = 0.25

@onready var shutter: ColorRect = $Overlay/Shutter
@onready var thumbnail: TextureRect = $Overlay/Thumbnail
@onready var capture_button: Button = $Overlay/UI/CaptureButton

func _ready() -> void:
	shutter.visible = false
	thumbnail.visible = false
	capture_button.pressed.connect(Callable(self, "_on_capture_pressed"))

func _on_capture_pressed() -> void:
	await capture_canvas()

func capture_canvas() -> void:
	_flash_shutter()
	await get_tree().create_timer(flash_duration).timeout
	
	var canvas_layer = get_node_or_null(viewport_node) as CanvasLayer
	if not canvas_layer:
		push_error("screenshot_manager: CanvasLayer not found")
		return
	
	# Hide the overlay (shutter, button, etc) before capturing
	var overlay = $Overlay
	overlay.visible = false
	await get_tree().process_frame
	
	# Get the viewport and capture just the canvas layer's content
	var vp = get_viewport()
	var img = vp.get_texture().get_image()
	
	# Show overlay again
	overlay.visible = true
	
	var tex = ImageTexture.create_from_image(img)
	_animate_thumbnail(tex)

func _flash_shutter() -> void:
	shutter.visible = true
	shutter.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween = create_tween()
	tween.tween_property(shutter, "modulate:a", 0.85, flash_duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(shutter, "modulate:a", 0.0, flash_duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(flash_duration / 2)
	tween.tween_callback(Callable(self, "_on_shutter_hide")).set_delay(flash_duration)

func _on_shutter_hide() -> void:
	shutter.visible = false

func _animate_thumbnail(texture: Texture2D) -> void:
	thumbnail.texture = texture
	thumbnail.visible = true
	thumbnail.scale = Vector2.ONE
	thumbnail.modulate = Color(1.0, 1.0, 1.0, 1.0)
	thumbnail.position = Vector2(400, 300)
	var tween = create_tween()
	tween.tween_property(thumbnail, "position", thumbnail_target_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(thumbnail, "scale", Vector2(0.42, 0.42), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
