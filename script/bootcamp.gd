extends Node2D

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

# Target sequence for bootcamp cycling
var target_sequence: Array[String] = ["ipsc_mini","ipsc_mini_black_1", "ipsc_mini_black_2", "hostage", "2poppers", "3paddles", "ipsc_mini_rotate"]
var current_target_index: int = 0
var current_target_instance = null

# Preload the scenes for bootcamp targets
@onready var ipsc_mini_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")
@onready var ipsc_mini_black_1_scene: PackedScene = preload("res://scene/ipsc_mini_black_1.tscn")
@onready var ipsc_mini_black_2_scene: PackedScene = preload("res://scene/ipsc_mini_black_2.tscn")
@onready var hostage_scene: PackedScene = preload("res://scene/hostage.tscn")
@onready var two_poppers_scene: PackedScene = preload("res://scene/2poppers_simple.tscn")
@onready var three_paddles_scene: PackedScene = preload("res://scene/3paddles_simple.tscn")
@onready var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")

@onready var ipsc = $IPSC
@onready var shot_labels = []
@onready var clear_button = $CanvasLayer/Control/BottomContainer/CustomButton
@onready var background_music = $BackgroundMusic

var shot_times = []
var drill_started = false  # Track if drill has been started
var game_start_requested = false  # Prevent multiple requests

func _ready():
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Initialize but don't start the drill yet
	if not DEBUG_DISABLED:
		print("[Bootcamp] Initializing bootcamp, waiting for HTTP start game response...")
	
	# Disable disappearing for bootcamp
	ipsc.max_shots = 1000
	
	# Temporarily disable target interaction until drill starts
	ipsc.input_pickable = false
	if not DEBUG_DISABLED:
		print("[Bootcamp] Target disabled until game start response received")
	
	# Connect to ipsc target_hit signal
	ipsc.target_hit.connect(_on_target_hit)
	
	# Connect clear button
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	else:
		if not DEBUG_DISABLED:
			print("ERROR: ClearButton not found!")
	
	# Get all shot labels
	for i in range(1, 11):
		var label = get_node("CanvasLayer/Control/ShotIntervalsOverlay/Shot" + str(i))
		if label:
			shot_labels.append(label)
			label.text = ""
		else:
			if not DEBUG_DISABLED:
				print("ERROR: Shot" + str(i) + " not found!")
	
	# Update UI texts with translations
	update_ui_texts()
	
	# Set clear button as default focus
	clear_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Connecting to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] WebSocketListener singleton not found!")
	
	# Load SFX volume from GlobalData and apply it
	var global_data_for_sfx = get_node_or_null("/root/GlobalData")
	if global_data_for_sfx and global_data_for_sfx.settings_dict.has("sfx_volume"):
		var sfx_volume = global_data_for_sfx.settings_dict.get("sfx_volume", 5)
		_apply_sfx_volume(sfx_volume)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Loaded SFX volume from GlobalData: ", sfx_volume)
	else:
		# Default to volume level 5 if not set
		_apply_sfx_volume(5)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Using default SFX volume: 5")
	
	# Send HTTP request to start the game and wait for response
	start_bootcamp_drill()

func start_bootcamp_drill():
	"""Send HTTP start game request and wait for OK response before starting drill"""
	if game_start_requested:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Game start already requested, ignoring duplicate call")
		return
	
	game_start_requested = true
	if not DEBUG_DISABLED:
		print("[Bootcamp] Sending start game HTTP request for bootcamp...")
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		# Send start game request with bootcamp mode
		http_service.start_game(_on_start_game_response, "bootcamp")
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] ERROR: HttpService singleton not found! Starting drill anyway...")
		_start_drill_immediately()

func _on_start_game_response(result, response_code, _headers, body):
	"""Handle the HTTP start game response"""
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Bootcamp] Start game HTTP response:", result, response_code, body_str)
	
	# Parse the JSON response
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Start game SUCCESS - starting bootcamp drill")
		_start_drill_immediately()
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Start game FAILED or invalid response - starting drill anyway")
		_start_drill_immediately()

func _start_drill_immediately():
	"""Actually start the bootcamp drill"""
	if drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Drill already started, ignoring duplicate call")
		return
	
	drill_started = true
	if not DEBUG_DISABLED:
		print("[Bootcamp] Bootcamp drill officially started!")
	
	# Initialize current target (starts with ipsc_mini)
	current_target_instance = ipsc
	current_target_index = 0
	
	# Enable target interactions (they might be disabled initially)
	if ipsc:
		ipsc.input_pickable = true
		ipsc.drill_active = true
		if not DEBUG_DISABLED:
			print("[Bootcamp] Target enabled for shooting practice")
	
	# Play background music
	if background_music:
		background_music.play()
		if not DEBUG_DISABLED:
			print("[Bootcamp] Playing background music")
	
	# Any additional drill initialization can go here
	# For bootcamp, the drill is already "active" since it's free practice

func _on_target_hit(_arg1, _arg2, _arg3, _arg4 = null):
	# Handle both signal signatures:
	# IPSC Mini: target_hit(zone, points, hit_position)
	# Poppers/Paddles: target_hit(id, zone, points, hit_position)
	
	# Only process hits if drill has started
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Target hit before drill started - ignoring")
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	shot_times.append(current_time)
	
	if shot_times.size() > 1:
		var time_diff = shot_times[-1] - shot_times[-2]
		_update_shot_list("+%.2fs" % time_diff)
	else:
		_update_shot_list("First shot")

func _update_shot_list(new_text: String):
	# Shift the list
	for i in range(shot_labels.size() - 1, 0, -1):
		shot_labels[i].text = shot_labels[i-1].text
	shot_labels[0].text = new_text

func _on_clear_pressed():
	# Clear shot list
	for label in shot_labels:
		label.text = ""
	shot_times.clear()
	
	# Clear bullet holes - get all children and check if they're bullet holes
	var children_to_remove = []
	if current_target_instance:
		for child in current_target_instance.get_children():
			# Check if it's a bullet hole (Sprite2D with bullet hole script)
			if child is Sprite2D and child.has_method("set_hole_position"):
				children_to_remove.append(child)
	
	# Remove all bullet holes
	for bullet_hole in children_to_remove:
		bullet_hole.queue_free()
		if not DEBUG_DISABLED:
			print("Removed bullet hole: ", bullet_hole.name)

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[Bootcamp] Received menu_control signal with directive: ", directive)
	match directive:
		"enter":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Enter pressed")
			_on_clear_pressed()
		"left":
			switch_to_previous_target()
		"right":
			switch_to_next_target()
		"back", "homepage":
			if not DEBUG_DISABLED:
				print("[Bootcamp] ", directive, " - navigating to main menu")
			
			# Deactivate current target before exiting
			if current_target_instance and current_target_instance.has_method("set"):
				current_target_instance.set("drill_active", false)
				if not DEBUG_DISABLED:
					print("[Bootcamp] Deactivated target before exiting")
			
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				if not DEBUG_DISABLED:
					print("[Bootcamp] Warning: Node not in tree, cannot change scene")
		"volume_up":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Volume up")
			volume_up()
		"volume_down":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Volume down")
			volume_down()
		"power":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Power off")
			power_off()
		_:
			if not DEBUG_DISABLED:
				print("[Bootcamp] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] HttpService singleton not found!")

func _on_volume_up_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Bootcamp] Volume up HTTP response:", result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] HttpService singleton not found!")

func _on_volume_down_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Bootcamp] Volume down HTTP response:", result, response_code, body_str)

func power_off():
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.set_alert_text(tr("power_off_alert"))
	add_child(dialog)

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Loaded language from GlobalData: ", language)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh_CN"
		"Traditional Chinese":
			locale = "zh_TW"
		"Japanese":
			locale = "ja"
		_:
			locale = "en"  # Default to English
	TranslationServer.set_locale(locale)
	if not DEBUG_DISABLED:
		print("[Bootcamp] Set locale to: ", locale)

func update_ui_texts():
	# Update static UI elements with translations
	var intervals_label = get_node_or_null("CanvasLayer/Control/ShotIntervalsOverlay/IntervalsLabel")
	
	if intervals_label:
		intervals_label.text = get_localized_shots_text()
	
	if clear_button:
		clear_button.text = tr("clear")

func get_localized_shots_text() -> String:
	# Since there's no specific "shots" translation key, create localized text based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "射击"
		"zh_TW":
			return "射擊"
		"ja":
			return "ショット"
		_:
			return "Shots"

func switch_to_next_target():
	"""Switch to the next target in the sequence"""
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Drill not started yet, ignoring target switch")
		return
	
	# Deactivate current target
	if current_target_instance and current_target_instance.has_method("set"):
		current_target_instance.set("drill_active", false)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Deactivated current target")
	
	# Move to next target
	current_target_index = (current_target_index + 1) % target_sequence.size()
	
	if not DEBUG_DISABLED:
		print("[Bootcamp] Switching to next target: ", target_sequence[current_target_index], " (index: ", current_target_index, ")")
	
	spawn_target_by_type(target_sequence[current_target_index])

func switch_to_previous_target():
	"""Switch to the previous target in the sequence"""
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Drill not started yet, ignoring target switch")
		return
	
	# Deactivate current target
	if current_target_instance and current_target_instance.has_method("set"):
		current_target_instance.set("drill_active", false)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Deactivated current target")
	
	# Move to previous target
	current_target_index = (current_target_index - 1 + target_sequence.size()) % target_sequence.size()
	
	if not DEBUG_DISABLED:
		print("[Bootcamp] Switching to previous target: ", target_sequence[current_target_index], " (index: ", current_target_index, ")")
	
	spawn_target_by_type(target_sequence[current_target_index])

func spawn_target_by_type(target_type: String):
	"""Spawn a target of the specified type"""
	# Clear current target
	if current_target_instance:
		current_target_instance.queue_free()
	
	var target_scene = null
	
	# Select the appropriate scene
	match target_type:
		"ipsc_mini":
			target_scene = ipsc_mini_scene
		"ipsc_mini_black_1":
			target_scene = ipsc_mini_black_1_scene
		"ipsc_mini_black_2":
			target_scene = ipsc_mini_black_2_scene
		"hostage":
			target_scene = hostage_scene
		"2poppers":
			target_scene = two_poppers_scene
		"3paddles":
			target_scene = three_paddles_scene
		"ipsc_mini_rotate":
			target_scene = ipsc_mini_rotate_scene
		_:
			if not DEBUG_DISABLED:
				print("[Bootcamp] Unknown target type: ", target_type)
			return
	
	if target_scene:
		var target = target_scene.instantiate()
		add_child(target)
		current_target_instance = target
		
		# Center the target in the scene
		target.position = Vector2(360, 640)
		
		# Disable disappearing for bootcamp (set max_shots to high number)
		if target.has_method("set"):
			target.set("max_shots", 1000)
		
		# For composite targets, also set max_shots on child targets
		if target_type == "ipsc_mini_rotate":
			var inner_ipsc = target.get_node_or_null("RotationCenter/IPSCMini")
			if inner_ipsc and inner_ipsc.has_method("set"):
				inner_ipsc.set("max_shots", 1000)
				if not DEBUG_DISABLED:
					print("[Bootcamp] Set max_shots=1000 on inner IPSC mini for rotating target")
		
		# Special positioning for rotating target (offset from center)
		if target_type == "ipsc_mini_rotate":
			target.position = Vector2(160, 840)  # Center (360,640) + offset (-200,200)
		
		# Connect signals
		if target.has_signal("target_hit"):
			target.target_hit.connect(_on_target_hit)
		
		# Enable the target
		if target.has_method("set"):
			target.set("drill_active", true)
		
		if not DEBUG_DISABLED:
			print("[Bootcamp] Spawned and activated target: ", target_type, " at position: ", target.position)

func _on_sfx_volume_changed(volume: int):
	"""Handle SFX volume changes from Option scene.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	if not DEBUG_DISABLED:
		print("[Bootcamp] SFX volume changed to: ", volume)
	_apply_sfx_volume(volume)

func _apply_sfx_volume(volume: int):
	"""Apply SFX volume level to audio.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	# Convert volume (0-10) to Godot's decibel scale
	# 0 = silence (mute), 10 = full volume (0dB)
	# We use approximately -40dB for silence and 0dB for maximum
	if volume <= 0:
		# Stop all SFX
		if background_music:
			background_music.volume_db = -80  # Effectively mute
		if not DEBUG_DISABLED:
			print("[Bootcamp] Muted audio (volume=", volume, ")")
	else:
		# Map 1-10 to -40dB to 0dB
		# volume 1 = -40dB, volume 10 = 0dB
		var db = -40.0 + ((volume - 1) * (40.0 / 9.0))
		if background_music:
			background_music.volume_db = db
		if not DEBUG_DISABLED:
			print("[Bootcamp] Set audio volume_db to ", db, " (volume level: ", volume, ")")
