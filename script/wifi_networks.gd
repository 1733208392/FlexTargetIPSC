extends Control

# Simple WiFi networks UI for testing remote navigation + onscreen keyboard
# The scene shows a list of fake networks. Remote navigation should move
# focus between network buttons. Pressing Enter on a network opens an
# overlay where user can input a password using the onscreen keyboard.

@onready var list_vbox = $CenterContainer/NetworksVBox
@onready var overlay = $Overlay
@onready var password_line = $Overlay/PanelContainer/VBoxContainer/PasswordLine
@onready var submit_btn = $Overlay/PanelContainer/VBoxContainer/SubmitButton

var networks = ["HomeNetwork","CafeWifi","OfficeNet","Guest","MyPhoneHotspot"]

func _ready():
	_build_list()
	overlay.visible = false

func _build_list():
	# clear existing children
	for c in list_vbox.get_children():
		c.queue_free()
	for net_name in networks:
		var b = Button.new()
		b.text = net_name
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.connect("pressed", Callable(self, "_on_network_selected").bind(net_name))
		list_vbox.add_child(b)

func _on_network_selected(_name):
	# Show overlay and focus password field
	overlay.visible = true
	password_line.text = ""
	password_line.grab_focus()

func _on_submit_pressed():
	var owner = get_viewport().gui_get_focus_owner()
	var focus_text = "(unknown)"
	if owner != null and owner is Button:
		focus_text = owner.text
	print("Submitting password for network: ", focus_text, " password=", password_line.text)
	overlay.visible = false

func _on_cancel_pressed():
	overlay.visible = false

# Allow closing overlay with ESC
func _input(event):
	if overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		overlay.visible = false
		get_viewport().gui_focus(null)
