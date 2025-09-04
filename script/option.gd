extends Control

# Global variable for current language
static var current_language = "English"

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/LanguageContainer/ChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/LanguageContainer/EnglishButton"

# References to labels that need translation
@onready var tab_container = $"VBoxContainer/MarginContainer/tab_container"
@onready var description_label = $"VBoxContainer/MarginContainer/tab_container/About/Left/DescriptionLabel"
@onready var copyright_label = $"VBoxContainer/MarginContainer/tab_container/About/Left/CopyrightLabel"

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
	
	# Update UI texts
	update_ui_texts()

func _on_language_changed(language: String):
	current_language = language
	set_locale_from_language(language)
	save_settings()
	update_ui_texts()
	print("Language changed to: ", language)

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh"
		"Japanese":
			locale = "ja"
	TranslationServer.set_locale(locale)

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

func update_ui_texts():
	if tab_container:
		tab_container.set_tab_title(0, tr("languages"))
		tab_container.set_tab_title(1, tr("about"))
	if description_label:
		description_label.text = tr("description")
	if copyright_label:
		copyright_label.text = tr("copyright")

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
		set_locale_from_language(current_language)
	else:
		print("No saved settings found, using default")
		set_locale_from_language(current_language)

# Function to get current language (can be called from other scripts)
static func get_current_language() -> String:
	return current_language
