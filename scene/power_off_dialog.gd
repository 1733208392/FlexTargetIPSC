extends CanvasLayer

@onready var ok_button = $CenterContainer/PanelContainer/VBoxContainer/OKButton
@onready var text_label = $CenterContainer/PanelContainer/VBoxContainer/TextLabel
var alert_text = ""

func _ready():
	print("[PowerOffDialog] Ready called")
	
	if ok_button == null:
		print("[PowerOffDialog] ERROR: ok_button is null!")
		return
	
	ok_button.pressed.connect(_on_ok_pressed)
	ok_button.grab_focus()
	print("[PowerOffDialog] Button connected and focused")
	
	# Connect to WebSocketListener for remote control
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[PowerOffDialog] Connected to WebSocketListener")
	else:
		print("[PowerOffDialog] WebSocketListener not found")

func set_alert_text(text: String):
	alert_text = text
	if text_label:
		text_label.text = text
	else:
		print("[PowerOffDialog] text_label not ready, will set later")
		call_deferred("set_text_deferred", text)

func set_text_deferred(text: String):
	if has_node("CenterContainer/PanelContainer/VBoxContainer/TextLabel"):
		$CenterContainer/PanelContainer/VBoxContainer/TextLabel.text = text
		print("[PowerOffDialog] Text set: ", text)

func _on_ok_pressed():
	queue_free()

func _on_menu_control(directive: String):
	# Only handle enter/power directives
	match directive:
		"enter":
			print("[PowerOffDialog] Enter pressed, closing dialog")
			_on_ok_pressed()
		"power":
			print("[PowerOffDialog] Power pressed, closing dialog")
			_on_ok_pressed()
		_:
			print("[PowerOffDialog] Ignoring directive: ", directive)
