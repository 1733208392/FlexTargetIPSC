extends Node2D

@export var viewport_node: NodePath = NodePath("../CanvasLayer")
@export var thumbnail_target_pos: Vector2 = Vector2(80, 520)
@export var flash_duration: float = 0.25

@onready var shutter: ColorRect = $Overlay/Shutter
@onready var thumbnail: TextureRect = $Overlay/Thumbnail
@onready var capture_button: Button = $Overlay/UI/CaptureButton

# Last captured image for sending to mobile app
var last_captured_image: Image = null

func _ready() -> void:
	shutter.visible = false
	thumbnail.visible = false
	capture_button.pressed.connect(Callable(self, "_on_capture_pressed"))

func _on_capture_pressed() -> void:
	await capture_canvas()
	# Automatically send to mobile app after capture completes
	send_captured_to_mobile_app(Callable(self, "_on_capture_sent_to_mobile"))

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
	
	# Store the captured image for later sending
	last_captured_image = img
	
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

func send_captured_to_mobile_app(completion_callback: Callable = Callable()) -> void:
	"""
	Send the last captured screenshot to the mobile app through HttpService.
	
	Args:
		completion_callback: Optional callable to invoke when transfer is complete
			Signature: callback(success: bool, message: String)
	
	Example:
		var screenshot_manager = get_node("CaptureManager")
		screenshot_manager.send_captured_to_mobile_app(
			Callable(self, "_on_image_sent")
		)
	"""
	
	if not last_captured_image:
		push_error("screenshot_manager: No captured image to send")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "No captured image available")
		return
	
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		push_error("screenshot_manager: HttpService not found")
		if completion_callback and completion_callback.is_valid():
			completion_callback.call(false, "HttpService not available")
		return
	
	# Send the captured image with BLE-optimized settings (JPG compression)
	http_service.send_captured_image(
		last_captured_image,
		100,    # BLE-optimized chunk size (1 KB)
		50.0,   # BLE-optimized delay (50 ms)
		completion_callback
	)

func _on_capture_sent_to_mobile(success: bool, message: String) -> void:
	"""Callback when capture is sent to mobile app"""
	if success:
		print("[ScreenshotManager] ✅ Screenshot sent to mobile app: ", message)
	else:
		print("[ScreenshotManager] ❌ Failed to send screenshot: ", message)
