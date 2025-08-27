extends Control

# References to UI elements
@onready var tab_container = $MarginContainer/tab_container
@onready var back_button = $MarginContainer/TopBar/BackButton

# Game Settings tab
@onready var easy_button = $"MarginContainer/tab_container/Game Settings/DifficultyContainer/EasyButton"
@onready var medium_button = $"MarginContainer/tab_container/Game Settings/DifficultyContainer/MediumButton"
@onready var hard_button = $"MarginContainer/tab_container/Game Settings/DifficultyContainer/HardButton"
@onready var target_spinbox = $"MarginContainer/tab_container/Game Settings/TargetSpinBox"
@onready var timer_spinbox = $"MarginContainer/tab_container/Game Settings/TimerSpinBox"

# Audio Settings tab
@onready var master_volume_slider = $"MarginContainer/tab_container/Audio Settings/MasterVolumeSlider"
@onready var master_volume_value = $"MarginContainer/tab_container/Audio Settings/MasterVolumeValue"
@onready var sfx_volume_slider = $"MarginContainer/tab_container/Audio Settings/SFXVolumeSlider"
@onready var sfx_volume_value = $"MarginContainer/tab_container/Audio Settings/SFXVolumeValue"
@onready var mute_checkbox = $"MarginContainer/tab_container/Audio Settings/MuteCheckBox"

# Controls tab
@onready var touch_controls_button = $"MarginContainer/tab_container/Controls/ControlContainer/TouchControlsButton"
@onready var accelerometer_button = $"MarginContainer/tab_container/Controls/ControlContainer/AccelerometerButton"
@onready var sensitivity_slider = $"MarginContainer/tab_container/Controls/SensitivitySlider"
@onready var sensitivity_value = $"MarginContainer/tab_container/Controls/SensitivityValue"

# Game settings
var current_difficulty = "Easy"
var target_count = 20
var time_limit = 120

# Audio settings
var master_volume = 75
var sfx_volume = 80
var is_muted = false

# Control settings
var control_scheme = "Touch"
var touch_sensitivity = 1.0

func _ready():
	# Make sure control container is visible
	var control_container = $"MarginContainer/tab_container/Controls/ControlContainer"
	if control_container:
		control_container.visible = true
	
	# Connect signals for game settings (with null checks)
	if easy_button:
		easy_button.pressed.connect(_on_difficulty_changed.bind("Easy"))
	if medium_button:
		medium_button.pressed.connect(_on_difficulty_changed.bind("Medium"))
	if hard_button:
		hard_button.pressed.connect(_on_difficulty_changed.bind("Hard"))
	if target_spinbox:
		target_spinbox.value_changed.connect(_on_target_count_changed)
	if timer_spinbox:
		timer_spinbox.value_changed.connect(_on_time_limit_changed)
	
	# Connect signals for audio settings (with null checks)
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if mute_checkbox:
		mute_checkbox.toggled.connect(_on_mute_toggled)
	
	# Connect signals for control settings (with null checks)
	if touch_controls_button:
		touch_controls_button.pressed.connect(_on_control_scheme_changed.bind("Touch"))
	if accelerometer_button:
		accelerometer_button.pressed.connect(_on_control_scheme_changed.bind("Accelerometer"))
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	# Connect back button if it exists
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Load saved settings
	load_settings()

func _on_back_pressed():
	# Return to main menu
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")

func _on_difficulty_changed(difficulty: String):
	current_difficulty = difficulty
	print("Difficulty changed to: ", difficulty)
	
	# Adjust default values based on difficulty
	match difficulty:
		"Easy":
			target_spinbox.value = 15
			timer_spinbox.value = 180
		"Medium":
			target_spinbox.value = 20
			timer_spinbox.value = 120
		"Hard":
			target_spinbox.value = 30
			timer_spinbox.value = 90
	
	save_settings()

func _on_target_count_changed(value: float):
	target_count = int(value)
	print("Target count changed to: ", target_count)
	save_settings()

func _on_time_limit_changed(value: float):
	time_limit = int(value)
	print("Time limit changed to: ", time_limit, " seconds")
	save_settings()

func _on_master_volume_changed(value: float):
	master_volume = int(value)
	master_volume_value.text = str(master_volume) + "%"
	
	# Apply volume change to audio bus
	var db_value = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_value)
	print("Master volume changed to: ", master_volume, "%")
	save_settings()

func _on_sfx_volume_changed(value: float):
	sfx_volume = int(value)
	sfx_volume_value.text = str(sfx_volume) + "%"
	
	# Apply volume change to SFX bus (you may need to create this bus in your project)
	if AudioServer.get_bus_count() > 1:
		var db_value = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)
	print("SFX volume changed to: ", sfx_volume, "%")
	save_settings()

func _on_mute_toggled(is_pressed: bool):
	is_muted = is_pressed
	
	# Mute/unmute all audio
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)
	print("Audio muted: ", is_muted)
	save_settings()

func _on_control_scheme_changed(scheme: String):
	control_scheme = scheme
	print("Control scheme changed to: ", scheme)
	save_settings()

func _on_sensitivity_changed(value: float):
	touch_sensitivity = value
	sensitivity_value.text = str(value) + "x"
	print("Touch sensitivity changed to: ", touch_sensitivity)
	save_settings()

func save_settings():
	var config = ConfigFile.new()
	
	# Game settings
	config.set_value("game", "difficulty", current_difficulty)
	config.set_value("game", "target_count", target_count)
	config.set_value("game", "time_limit", time_limit)
	
	# Audio settings
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "is_muted", is_muted)
	
	# Control settings
	config.set_value("controls", "scheme", control_scheme)
	config.set_value("controls", "sensitivity", touch_sensitivity)
	
	config.save("user://settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return  # No saved settings file
	
	# Load game settings
	current_difficulty = config.get_value("game", "difficulty", "Easy")
	target_count = config.get_value("game", "target_count", 20)
	time_limit = config.get_value("game", "time_limit", 120)
	
	# Load audio settings
	master_volume = config.get_value("audio", "master_volume", 75)
	sfx_volume = config.get_value("audio", "sfx_volume", 80)
	is_muted = config.get_value("audio", "is_muted", false)
	
	# Load control settings
	control_scheme = config.get_value("controls", "scheme", "Touch")
	touch_sensitivity = config.get_value("controls", "sensitivity", 1.0)
	
	# Apply loaded settings to UI
	apply_settings_to_ui()

func apply_settings_to_ui():
	# Apply game settings (with null checks)
	match current_difficulty:
		"Easy":
			if easy_button:
				easy_button.button_pressed = true
		"Medium":
			if medium_button:
				medium_button.button_pressed = true
		"Hard":
			if hard_button:
				hard_button.button_pressed = true
	
	if target_spinbox:
		target_spinbox.value = target_count
	if timer_spinbox:
		timer_spinbox.value = time_limit
	
	# Apply audio settings (with null checks)
	if master_volume_slider:
		master_volume_slider.value = master_volume
	if master_volume_value:
		master_volume_value.text = str(master_volume) + "%"
	if sfx_volume_slider:
		sfx_volume_slider.value = sfx_volume
	if sfx_volume_value:
		sfx_volume_value.text = str(sfx_volume) + "%"
	if mute_checkbox:
		mute_checkbox.button_pressed = is_muted
	
	# Apply control settings (with null checks)
	match control_scheme:
		"Touch":
			if touch_controls_button:
				touch_controls_button.button_pressed = true
		"Accelerometer":
			if accelerometer_button:
				accelerometer_button.button_pressed = true
	
	if sensitivity_slider:
		sensitivity_slider.value = touch_sensitivity
	if sensitivity_value:
		sensitivity_value.text = str(touch_sensitivity) + "x"
	
	# Apply audio settings to audio server
	var master_db = linear_to_db(master_volume / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), is_muted)

# Function to get current settings (can be called from other scripts)
func get_game_settings() -> Dictionary:
	return {
		"difficulty": current_difficulty,
		"target_count": target_count,
		"time_limit": time_limit
	}

func get_audio_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"is_muted": is_muted
	}

func get_control_settings() -> Dictionary:
	return {
		"scheme": control_scheme,
		"sensitivity": touch_sensitivity
	}
