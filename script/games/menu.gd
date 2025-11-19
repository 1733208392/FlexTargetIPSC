extends Node2D

# Menu state
var current_row: int = 0  # 0 = main menu, 1 = language buttons
var selected_option: int = 0  # Selected option within current row
var main_menu_options: Array = []  # Main menu buttons (FruitCatcher, Monkey Duel, Mole Attack)
var language_options: Array = []  # Language buttons (EN, 中文, 繁中, 日本語)

# Node references
var button_fruitcatcher: TextureButton
var button_monkeyduel: TextureButton
var button_mole_attack: TextureButton
var english_button: Button
var chinese_button: Button
var traditional_button: Button
var japanese_button: Button
var fruitcatcher_label: Label
var monkeyduel_label: Label
var mole_attack_label: Label

func _ready():
	# Get node references for game buttons
	button_fruitcatcher = get_node("Panel/VBoxContainer2/HBoxContainer/1Player")
	button_monkeyduel = get_node("Panel/VBoxContainer2/HBoxContainer2/2Players")
	button_mole_attack = get_node("Panel/VBoxContainer2/HBoxContainer3/wackamole")
	
	# Get language button references
	english_button = get_node("Panel/VBoxContainer/LanguageContainer/EnglishButton")
	chinese_button = get_node("Panel/VBoxContainer/LanguageContainer/ChineseButton")
	traditional_button = get_node("Panel/VBoxContainer/LanguageContainer/TraditionalButton")
	japanese_button = get_node("Panel/VBoxContainer/LanguageContainer/JapaneseButton")
	
	# Get game name labels
	fruitcatcher_label = get_node("Panel/VBoxContainer2/HBoxContainer/Label")
	monkeyduel_label = get_node("Panel/VBoxContainer2/HBoxContainer2/Label")
	mole_attack_label = get_node("Panel/VBoxContainer2/HBoxContainer3/Label")
	
	# Populate menu options arrays
	main_menu_options = [button_fruitcatcher, button_monkeyduel, button_mole_attack]
	language_options = [english_button, chinese_button, traditional_button, japanese_button]
	
	# Connect button signals
	button_fruitcatcher.pressed.connect(_on_fruitcatcher_pressed)
	button_monkeyduel.pressed.connect(_on_monkeyduel_pressed)
	button_mole_attack.pressed.connect(_on_mole_attack_pressed)
	
	# Connect language button signals
	english_button.pressed.connect(_on_english_pressed)
	chinese_button.pressed.connect(_on_chinese_pressed)
	traditional_button.pressed.connect(_on_traditional_pressed)
	japanese_button.pressed.connect(_on_japanese_pressed)
	
	# Connect to remote control directives
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.connect(_on_remote_navigate)
		remote_control.enter_pressed.connect(_on_remote_enter)
		print("[Menu] Connected to RemoteControl signals")
	else:
		print("[Menu] RemoteControl autoload not found!")
	
	# Set translated game names
	if fruitcatcher_label:
		fruitcatcher_label.text = tr("FruitCatcher")
	if monkeyduel_label:
		monkeyduel_label.text = tr("Monkey Duel")
	if mole_attack_label:
		mole_attack_label.text = tr("Mole Attack")
	
	# Set FruitCatcher as default focus
	if button_fruitcatcher:
		button_fruitcatcher.grab_focus()
		selected_option = 0
		current_row = 0
		print("[Menu] FruitCatcher button has focus by default")

func _on_remote_navigate(direction: String):
	"""Handle navigation from remote control"""
	
	if direction == "left" or direction == "right":
		# Left/Right navigation only works in language buttons row
		if current_row == 1:
			if direction == "left":
				selected_option -= 1
				if selected_option < 0:
					selected_option = language_options.size() - 1
			elif direction == "right":
				selected_option += 1
				if selected_option >= language_options.size():
					selected_option = 0
			_update_selection()
	
	elif direction == "down":
		# Down moves vertically through: FruitCatcher → Monkey Duel → Mole Attack → Language Container
		if current_row == 0:  # In game buttons row
			selected_option += 1
			if selected_option >= main_menu_options.size():
				# Move to language buttons row
				current_row = 1
				selected_option = 0
			_update_selection()
	
	elif direction == "up":
		# Up moves vertically: Language Container → Mole Attack → Monkey Duel → FruitCatcher
		if current_row == 1:  # In language buttons row
			# Move back to game buttons row at the last button (Mole Attack)
			current_row = 0
			selected_option = main_menu_options.size() - 1
			_update_selection()
		elif current_row == 0:  # In game buttons row
			selected_option -= 1
			if selected_option < 0:
				# Already at FruitCatcher, stay there
				selected_option = 0
			_update_selection()

func _on_remote_enter():
	"""Handle enter press from remote control"""
	print("[Menu] Enter pressed - row: ", current_row, ", option: ", selected_option)
	if current_row == 0:  # Main menu row
		if selected_option == 0:
			_on_fruitcatcher_pressed()
		elif selected_option == 1:
			_on_monkeyduel_pressed()
		elif selected_option == 2:
			_on_mole_attack_pressed()
	elif current_row == 1:  # Language buttons row
		if selected_option == 0:
			_on_english_pressed()
		elif selected_option == 1:
			_on_chinese_pressed()
		elif selected_option == 2:
			_on_traditional_pressed()
		elif selected_option == 3:
			_on_japanese_pressed()

func _update_selection():
	"""Update the focus to the selected button in current row"""
	var current_array = _get_current_array()
	if selected_option >= 0 and selected_option < current_array.size():
		current_array[selected_option].grab_focus()
	print("[Menu] Selection updated to row: ", current_row, ", option: ", selected_option)

func _get_current_array() -> Array:
	"""Get the current array based on selected row"""
	if current_row == 0:
		return main_menu_options
	else:
		return language_options

func _on_fruitcatcher_pressed():
	"""Handle FruitCatcher button press"""
	print("[Menu] FruitCatcher selected")
	# Load the game scene
	get_tree().change_scene_to_file("res://scene/games/game.tscn")

func _on_monkeyduel_pressed():
	"""Handle Monkey Duel button press"""
	print("[Menu] Monkey Duel selected")
	get_tree().change_scene_to_file("res://scene/games/monkey/game_monkey.tscn")

func _on_mole_attack_pressed():
	"""Handle Mole Attack button press"""
	print("[Menu] Mole Attack selected")
	get_tree().change_scene_to_file("res://scene/games/wack-a-mole/game_mole.tscn")

func _on_english_pressed():
	"""Switch to English"""
	print("[Menu] Switching to English")
	TranslationServer.set_locale("en")

func _on_chinese_pressed():
	"""Switch to Simplified Chinese"""
	print("[Menu] Switching to Simplified Chinese")
	TranslationServer.set_locale("zh")

func _on_traditional_pressed():
	"""Switch to Traditional Chinese"""
	print("[Menu] Switching to Traditional Chinese")
	TranslationServer.set_locale("zh_TW")

func _on_japanese_pressed():
	"""Switch to Japanese"""
	print("[Menu] Switching to Japanese")
	TranslationServer.set_locale("ja")
