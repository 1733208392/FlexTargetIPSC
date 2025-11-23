extends Node2D

# Menu state
var selected_option: int = 0  # Selected option
var main_menu_options: Array = []  # Main menu buttons (FruitCatcher, Monkey Duel, Mole Attack)

# Node references
var button_fruitcatcher: TextureButton
var button_monkeyduel: TextureButton
var button_mole_attack: TextureButton
var fruitcatcher_label: Label
var monkeyduel_label: Label
var mole_attack_label: Label

func _ready():
	# Hide global status bar when entering games
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = false
		print("[Games Menu] Hid global status bar: ", status_bar.name)
	
	# Get node references for game buttons
	button_fruitcatcher = get_node("Panel/VBoxContainer2/HBoxContainer/1Player")
	button_monkeyduel = get_node("Panel/VBoxContainer2/HBoxContainer2/2Players")
	button_mole_attack = get_node("Panel/VBoxContainer2/HBoxContainer3/wackamole")

	# Get game name labels
	fruitcatcher_label = get_node("Panel/VBoxContainer2/HBoxContainer/Label")
	monkeyduel_label = get_node("Panel/VBoxContainer2/HBoxContainer2/Label")
	mole_attack_label = get_node("Panel/VBoxContainer2/HBoxContainer3/Label")

	# Populate menu options arrays
	main_menu_options = [button_fruitcatcher, button_monkeyduel, button_mole_attack]

	# Connect button signals
	button_fruitcatcher.pressed.connect(_on_fruitcatcher_pressed)
	button_monkeyduel.pressed.connect(_on_monkeyduel_pressed)
	button_mole_attack.pressed.connect(_on_mole_attack_pressed)

	# Connect to remote control directives
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.connect(_on_remote_navigate)
		remote_control.enter_pressed.connect(_on_remote_enter)
		remote_control.back_pressed.connect(_on_remote_back_pressed)
		print("[Menu] Connected to MenuController signals")
	else:
		print("[Menu] MenuController autoload not found!")

	# Set translated game names
	if fruitcatcher_label:
		fruitcatcher_label.text = tr("fruitcatcher")
	if monkeyduel_label:
		monkeyduel_label.text = tr("monkey_duel")
	if mole_attack_label:
		mole_attack_label.text = tr("mole_attack")

	# Set FruitCatcher as default focus
	if button_fruitcatcher:
		button_fruitcatcher.grab_focus()
		selected_option = 0
		print("[Menu] FruitCatcher button has focus by default")

func _on_remote_navigate(direction: String):
	"""Handle navigation from remote control"""

	if direction == "left":
		selected_option -= 1
		if selected_option < 0:
			selected_option = main_menu_options.size() - 1
		_update_selection()

	elif direction == "right":
		selected_option += 1
		if selected_option >= main_menu_options.size():
			selected_option = 0
		_update_selection()

	elif direction == "down":
		selected_option += 1
		if selected_option >= main_menu_options.size():
			selected_option = 0
		_update_selection()

	elif direction == "up":
		selected_option -= 1
		if selected_option < 0:
			selected_option = main_menu_options.size() - 1
		_update_selection()

func _on_remote_enter():
	"""Handle enter press from remote control"""
	print("[Menu] Enter pressed - option: ", selected_option)
	if selected_option == 0:
		_on_fruitcatcher_pressed()
	elif selected_option == 1:
		_on_monkeyduel_pressed()
	elif selected_option == 2:
		_on_mole_attack_pressed()

func _on_remote_back_pressed():
	"""Handle back press from remote control to return to main menu"""
	print("[Menu] Back pressed - returning to main menu")
	# Show global status bar when returning to main menu
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		print("[Games Menu] Showed global status bar: ", status_bar.name)
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")

func _update_selection():
	"""Update the focus to the selected button"""
	if selected_option >= 0 and selected_option < main_menu_options.size():
		main_menu_options[selected_option].grab_focus()
	print("[Menu] Selection updated to option: ", selected_option)

func _on_fruitcatcher_pressed():
	"""Handle FruitCatcher button press"""
	print("[Menu] FruitCatcher selected")
	# Load the game scene
	get_tree().change_scene_to_file("res://scene/games/fruitninja.tscn")

func _on_monkeyduel_pressed():
	"""Handle Monkey Duel button press"""
	print("[Menu] Monkey Duel selected")
	get_tree().change_scene_to_file("res://scene/games/monkey/game_monkey.tscn")

func _on_mole_attack_pressed():
	"""Handle Mole Attack button press"""
	print("[Menu] Mole Attack selected")
	get_tree().change_scene_to_file("res://scene/games/wack-a-mole/game_mole.tscn")
