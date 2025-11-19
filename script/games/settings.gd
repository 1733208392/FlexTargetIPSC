extends Control

var controls = []
var current_focus_index = 0

func _ready():
	print("[Settings] _ready called")
	
	# Load translations if not already loaded
	var translations = ["zh.po", "ja.po", "zh_TW.po"]
	for trans_file in translations:
		if not TranslationServer.get_loaded_locales().has(trans_file.get_basename()):
			var translation = load("res://translations/" + trans_file)
			if translation:
				TranslationServer.add_translation(translation)
				print("[Settings] Translation loaded: ", trans_file)
			else:
				print("[Settings] Failed to load translation: ", trans_file)
	
	# Set translatable texts
	$VBoxContainer/DifficultyLabel.text = tr("Difficulty Level")
	$VBoxContainer/DurationLabel.text = tr("Duration")
	$StartButton.text = tr("Start")
	
	# Set option button items
	$VBoxContainer/DifficultyOption.clear()
	$VBoxContainer/DifficultyOption.add_item(tr("Low"))
	$VBoxContainer/DifficultyOption.add_item(tr("Medium"))
	$VBoxContainer/DifficultyOption.add_item(tr("High"))
	
	$VBoxContainer/DurationOption.clear()
	$VBoxContainer/DurationOption.add_item(tr("20s"))
	$VBoxContainer/DurationOption.add_item(tr("30s"))
	$VBoxContainer/DurationOption.add_item(tr("60s"))
	$VBoxContainer/DurationOption.add_item(tr("90s"))
	
	controls = [$VBoxContainer/DifficultyOption, $VBoxContainer/DurationOption, $StartButton]
	print("[Settings] Controls: ", controls)
	current_focus_index = 2  # StartButton
	$StartButton.grab_focus()
	
	# Connect Start button pressed
	$StartButton.pressed.connect(_on_start_pressed)
	
	# Connect to remote control for controller support
	var remote_control = get_node_or_null("/root/RemoteControl")
	if remote_control:
		remote_control.navigate.connect(_on_remote_navigate)
		remote_control.enter_pressed.connect(_on_remote_enter)
		remote_control.back_pressed.connect(_on_remote_back_pressed)
		print("[Settings] Connected to RemoteControl signals")
	else:
		print("[Settings] RemoteControl autoload not found!")

func _on_remote_navigate(direction: String):
	"""Handle navigation from remote control"""
	print("[Settings] Remote navigate: ", direction)
	var current_control = controls[current_focus_index]
	if current_control is OptionButton and current_control.get_popup().visible:
		# Popup is open, send key to popup for navigation
		var event = InputEventKey.new()
		event.pressed = true
		if direction == "up":
			event.keycode = KEY_UP
		elif direction == "down":
			event.keycode = KEY_DOWN
		Input.parse_input_event(event)
	else:
		# Normal navigation
		if direction == "up" or direction == "left":
			current_focus_index = (current_focus_index - 1 + controls.size()) % controls.size()
		elif direction == "down" or direction == "right":
			current_focus_index = (current_focus_index + 1) % controls.size()
		print("[Settings] New focus index: ", current_focus_index)
		call_deferred("grab_focus_on_control", current_focus_index)

func _on_remote_enter():
	"""Handle enter press from remote control"""
	if not visible:
		return
	print("[Settings] Remote enter")
	var current_control = controls[current_focus_index]
	if current_control == $StartButton:
		print("[Settings] Start button focused, starting game")
		_on_start_pressed()
	else:
		print("[Settings] Enter on non-start control")
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		Input.parse_input_event(event)

func _on_start_pressed():
	"""Handle Start button pressed"""
	print("[Settings] Start button pressed")
	
	# Get selected options
	var difficulty_index = $VBoxContainer/DifficultyOption.selected
	var duration_index = $VBoxContainer/DurationOption.selected
	
	# Set growth speed based on difficulty
	var growth_speed = 1 if difficulty_index == 0 else 2 if difficulty_index == 1 else 3
	print("[Settings] Setting vine growth_speed to: ", growth_speed)
	
	# Set game duration based on selection
	var duration = 30.0 if duration_index == 0 else 60.0 if duration_index == 1 else 120.0
	print("[Settings] Setting game duration to: ", duration, " seconds")
	
	# Randomly choose start side
	var start_side = "left" if randi() % 2 == 0 else "right"
	print("[Settings] Randomly chose monkey_start_side: ", start_side)
	
	# Emit settings signal
	get_parent().settings_applied.emit(start_side, growth_speed, duration)
	
	visible = false
	get_parent().start_countdown()

func grab_focus_on_control(index: int):
	controls[index].grab_focus()

func _on_remote_back_pressed():
	"""Handle back/home directive from remote control to return to menu"""
	print("[Settings] Remote back/home pressed - returning to menu...")
	_return_to_menu()

func _return_to_menu():
	print("[Settings] Returning to menu scene")
	var error = get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
	if error != OK:
		print("[Settings] Failed to change scene: ", error)
	else:
		print("[Settings] Scene change initiated")
