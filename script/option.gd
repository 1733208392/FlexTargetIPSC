extends Control

# Global variable for current language
static var current_language = "English"

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/LanguageContainer/ChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/LanguageContainer/EnglishButton"

func _ready():
	# Load saved settings
	load_settings()
	
	# Connect signals for language buttons
	if chinese_button:
		chinese_button.pressed.connect(_on_language_changed.bind("Chinese"))
	if japanese_button:
		japanese_button.pressed.connect(_on_language_changed.bind("Japanese"))
	if english_button:
		english_button.pressed.connect(_on_language_changed.bind("English"))
	
	# Set the initial pressed button based on current language
	set_language_button_pressed()

func _on_language_changed(language: String):
	current_language = language
	save_settings()
	print("Language changed to: ", language)

func set_language_button_pressed():
	match current_language:
		"Chinese":
			if chinese_button:
				chinese_button.button_pressed = true
		"Japanese":
			if japanese_button:
				japanese_button.button_pressed = true
		"English":
			if english_button:
				english_button.button_pressed = true

func save_settings():
	var config = ConfigFile.new()
	config.set_value("settings", "language", current_language)
	var err = config.save("user://settings.cfg")
	if err != OK:
		print("Failed to save settings: ", err)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		current_language = config.get_value("settings", "language", "English")
	else:
		print("No saved settings found, using default")

# Function to get current language (can be called from other scripts)
static func get_current_language() -> String:
	return current_language
