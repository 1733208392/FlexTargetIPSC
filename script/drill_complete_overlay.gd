extends Control

# Performance optimization
const DEBUG_LOGGING = false  # Set to true for verbose debugging

# Bullet system
@export var bullet_scene: PackedScene = preload("res://scene/bullet.tscn")

# Collision areas for bullet interactions
@onready var area_restart = $VBoxContainer/RestartButton/AreaRestart
@onready var area_replay = $VBoxContainer/ReviewReplayButton/AreaReplay

# UI elements for internationalization
@onready var title_label = get_node_or_null("VBoxContainer/TitleLabel")
@onready var score_label = get_node_or_null("VBoxContainer/ScoreLabel")
@onready var hit_factor_label = get_node_or_null("VBoxContainer/HitFactorLabel")
@onready var fastest_shot_label = get_node_or_null("VBoxContainer/FastestShotLabel")
@onready var restart_button = get_node_or_null("VBoxContainer/RestartButton")
@onready var replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")

func _ready():
	"""Initialize the drill complete overlay"""
	if DEBUG_LOGGING:
		print("=== DRILL COMPLETE OVERLAY INITIALIZED ===")
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Connect to WebSocket for bullet spawning
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		# Connect to WebSocket control directives
		ws_listener.menu_control.connect(_on_websocket_menu_control)
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Connected to WebSocketListener signals")
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] WebSocketListener singleton not found!")
	
	# Set up for mouse input processing - Control nodes need special setup
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Make sure we can receive input when visible
	set_process_input(true)
	set_process_unhandled_input(true)
	# Ensure we can intercept input events with high priority
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect collision area signals for bullet interactions
	setup_collision_areas()
	
	# Set up button focus management
	setup_button_focus()

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if DEBUG_LOGGING:
			print("[DrillComplete] Loaded language from GlobalData: ", language)
		call_deferred("update_ui_texts")
	else:
		if DEBUG_LOGGING:
			print("[DrillComplete] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
		call_deferred("update_ui_texts")

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
	if DEBUG_LOGGING:
		print("[DrillComplete] Set locale to: ", locale)

func update_ui_texts():
	# Update static text elements with translations
	if title_label:
		title_label.text = tr("complete")
	if restart_button:
		restart_button.text = tr("restart")
	if replay_button:
		replay_button.text = tr("replay")

func _notification(what):
	"""Debug overlay visibility changes"""
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Visibility changed to: ", visible)
			print("[drill_complete_overlay] Size: ", size)
			print("[drill_complete_overlay] Position: ", position)
		if visible:
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Overlay is now visible and ready for input")
			# Grab focus for the restart button when overlay becomes visible
			grab_restart_button_focus()

func setup_collision_areas():
	"""Setup collision detection for the restart and replay areas"""
	if area_restart:
		# Set collision properties for bullets
		area_restart.collision_layer = 7  # Target layer
		area_restart.collision_mask = 8   # Bullet layer
		area_restart.area_entered.connect(_on_area_restart_hit)
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] AreaRestart collision setup complete")
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] AreaRestart not found!")
	
	if area_replay:
		# Set collision properties for bullets
		area_replay.collision_layer = 7  # Target layer
		area_replay.collision_mask = 8   # Bullet layer
		area_replay.area_entered.connect(_on_area_replay_hit)
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] AreaReplay collision setup complete")
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] AreaReplay not found!")

func _input(event):
	"""Handle mouse clicks for bullet spawning"""
	# Only process input when this overlay is visible
	if not visible:
		return
	
	# Debug: Log any input event
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] _input received event: ", event)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Mouse click detected via _input")
		_handle_mouse_click(event)
		# Mark the event as handled to prevent parent nodes from processing it
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event):
	"""Handle mouse clicks for bullet spawning - backup method for Control nodes"""
	# Only process input when this overlay is visible
	if not visible:
		return
	
	# Debug: Log any unhandled input event
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] _unhandled_input received event: ", event)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Mouse click detected via _unhandled_input")
		_handle_mouse_click(event)
		# Accept the event to prevent further processing
		get_viewport().set_input_as_handled()

func _handle_mouse_click(event):
	"""Process the mouse click for bullet spawning"""
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Processing mouse click")
	
	# Check if bullet spawning is enabled through WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] WebSocketListener found, bullet_spawning_enabled: ", ws_listener.bullet_spawning_enabled)
		if not ws_listener.bullet_spawning_enabled:
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Bullet spawning disabled")
			return
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] WebSocketListener not found!")
		return
		
	var world_pos = get_global_mouse_position()
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Spawning bullet at: ", world_pos)
	spawn_bullet_at_position(world_pos)

func _on_websocket_bullet_hit(position: Vector2):
	"""Handle bullet hit from WebSocket data"""
	# Only process websocket bullets when this overlay is visible
	if not visible:
		return
		
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] WebSocket bullet hit at: ", position)
	spawn_bullet_at_position(position)

func spawn_bullet_at_position(world_pos: Vector2):
	"""Spawn a bullet at the specified world position"""
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Spawning bullet at world position: ", world_pos)
	
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		
		# Add the bullet to the scene
		add_child(bullet)
		
		# Set the bullet's spawn position
		if bullet.has_method("set_spawn_position"):
			bullet.set_spawn_position(world_pos)
		else:
			bullet.global_position = world_pos
		
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Bullet spawned successfully")
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] ERROR: No bullet scene loaded!")

func _on_area_restart_hit(area: Area2D):
	"""Handle bullet collision with restart area"""
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Bullet hit AreaRestart - restarting drill")
	
	# Hide the completion overlay
	visible = false
	
	# Find the drill manager and restart the drill
	var drill_ui = get_parent()
	if drill_ui:
		var drills_manager = drill_ui.get_parent()
		if drills_manager and drills_manager.has_method("restart_drill"):
			drills_manager.restart_drill()
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Drill restarted successfully")
		else:
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Warning: Could not find drills manager or restart_drill method")
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Warning: Could not find drill UI parent")

func _on_area_replay_hit(area: Area2D):
	"""Handle bullet collision with replay area"""
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Bullet hit AreaReplay - navigating to drill replay")
	
	# Navigate to the drill replay scene
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func setup_button_focus():
	"""Set up button focus management"""
	var restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if restart_button:
		restart_button.focus_mode = Control.FOCUS_ALL
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] RestartButton focus enabled")
	
	if replay_button:
		replay_button.focus_mode = Control.FOCUS_ALL
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] ReviewReplayButton focus enabled")

func update_drill_results(score: int, hit_factor: float, fastest_shot: float):
	"""Update the drill completion display with results"""
	var score_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Score")
	var hf_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/HitFactor")
	var fastest_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/FastestShot")
	
	if score_label:
		score_label.text = tr("score") + ": %d" % score
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Updated score: %d" % score)
	
	if hf_label:
		hf_label.text = tr("hit_factor") + ": %.2f" % hit_factor
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Updated hit factor: %.2f" % hit_factor)
	
	if fastest_label:
		fastest_label.text = tr("fastest_shot") + ": %.2fs" % fastest_shot
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Updated fastest shot: %.2fs" % fastest_shot)

func show_drill_complete(score: int = 0, hit_factor: float = 0.0, fastest_shot: float = 0.0):
	"""Show the drill complete overlay with updated results"""
	update_drill_results(score, hit_factor, fastest_shot)
	visible = true
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Drill complete overlay shown with results")

func grab_restart_button_focus():
	"""Grab focus for the restart button"""
	var restart_button = get_node_or_null("VBoxContainer/RestartButton")
	if restart_button:
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] RestartButton focus grabbed")
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] RestartButton not found for focus grab")

func _on_websocket_menu_control(directive: String):
	"""Handle WebSocket control directives for menu navigation"""
	if DEBUG_LOGGING:
		print("[drill_complete_overlay] Received control directive: ", directive)
	
	match directive:
		"up":
			_navigate_up()
		"down":
			_navigate_down()
		"enter":
			_activate_focused_button()
		_:
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Unknown directive: ", directive)

func _navigate_up():
	"""Navigate to previous button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if focused_control == replay_button and restart_button:
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Navigated up to RestartButton")
	elif focused_control == restart_button and replay_button:
		replay_button.grab_focus()
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Wrapped around to ReviewReplayButton")
	else:
		# Default to restart button if nothing focused
		if restart_button:
			restart_button.grab_focus()
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Default focus to RestartButton")

func _navigate_down():
	"""Navigate to next button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if focused_control == restart_button and replay_button:
		replay_button.grab_focus()
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Navigated down to ReviewReplayButton")
	elif focused_control == replay_button and restart_button:
		restart_button.grab_focus()
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Wrapped around to RestartButton")
	else:
		# Default to restart button if nothing focused
		if restart_button:
			restart_button.grab_focus()
			if DEBUG_LOGGING:
				print("[drill_complete_overlay] Default focus to RestartButton")

func _activate_focused_button():
	"""Activate the currently focused button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if focused_control == restart_button:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Activating RestartButton via WebSocket")
		_on_area_restart_hit(null)  # Trigger restart action
	elif focused_control == replay_button:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] Activating ReviewReplayButton via WebSocket")
		_on_area_replay_hit(null)  # Trigger replay action
	else:
		if DEBUG_LOGGING:
			print("[drill_complete_overlay] No button focused, defaulting to restart")
		_on_area_restart_hit(null)  # Default to restart