extends Control

@onready var list_container = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# History data structure to store drill results
var history_data = []
var current_focused_index = 0

func _ready():
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Load history data from saved files
	load_history_data()
	
	# Populate the list with data
	populate_list()
	
	# Update UI texts with translations
	update_ui_texts()
	
	# Make list items clickable
	setup_clickable_items()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[History] Connecting to WebSocketListener.menu_control signal")
	else:
		print("[History] WebSocketListener singleton not found!")

func load_history_data():
	history_data.clear()
	var dir = DirAccess.open("user://")
	if dir:
		var files = dir.get_files()
		var performance_files = []
		for file in files:
			if file.begins_with("performance_") and file.ends_with(".json"):
				performance_files.append(file)
		
		# Sort by index
		performance_files.sort_custom(func(a, b): return int(a.substr(12, 3)) < int(b.substr(12, 3)))
		
		for file_name in performance_files:
			var file = FileAccess.open("user://" + file_name, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()
				var json = JSON.new()
				var error = json.parse(json_string)
				if error == OK:
					var data = json.data
					var drill_summary = data["drill_summary"]
					var records = data["records"]
					
					var total_score = 0
					for record in records:
						total_score += record["score"]
					
					var hf = 0.0
					if drill_summary["total_elapsed_time"] > 0:
						hf = total_score / drill_summary["total_elapsed_time"]
					
					var drill_data = {
						"drill_number": int(file_name.substr(12, 3)),
						"total_time": "%.2fs" % drill_summary["total_elapsed_time"],
						"fastest_shot": "%.2fs" % (drill_summary["fastest_shot_interval"] if drill_summary["fastest_shot_interval"] != null else 0.0),
						"total_score": "%.1f" % total_score,
						"hf": "%.2f" % hf,
						"targets": records
					}
					history_data.append(drill_data)
				else:
					print("Failed to parse JSON in ", file_name)
			else:
				print("Failed to open ", file_name)
	else:
		print("Failed to access user directory")

func populate_list():
	if not list_container:
		return
	
	# Clear existing items
	for child in list_container.get_children():
		child.queue_free()
	
	# Create items dynamically
	for i in range(history_data.size()):
		var data = history_data[i]
		var item = HBoxContainer.new()
		item.layout_mode = 2
		
		# No label
		var no_label = Label.new()
		no_label.layout_mode = 2
		no_label.size_flags_horizontal = 3
		no_label.text = str(data["drill_number"])
		no_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(no_label)
		
		# VSeparator
		var sep1 = VSeparator.new()
		sep1.layout_mode = 2
		item.add_child(sep1)
		
		# TotalTime label
		var time_label = Label.new()
		time_label.layout_mode = 2
		time_label.size_flags_horizontal = 3
		time_label.text = data["total_time"]
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(time_label)
		
		# VSeparator
		var sep2 = VSeparator.new()
		sep2.layout_mode = 2
		item.add_child(sep2)
		
		# FastShot label
		var fast_label = Label.new()
		fast_label.layout_mode = 2
		fast_label.size_flags_horizontal = 3
		fast_label.text = data["fastest_shot"]
		fast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(fast_label)
		
		# VSeparator
		var sep3 = VSeparator.new()
		sep3.layout_mode = 2
		item.add_child(sep3)
		
		# Score label
		var score_label = Label.new()
		score_label.layout_mode = 2
		score_label.size_flags_horizontal = 3
		score_label.text = data["total_score"]
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(score_label)
		
		# VSeparator
		var sep4 = VSeparator.new()
		sep4.layout_mode = 2
		item.add_child(sep4)
		
		# HF label
		var hf_label = Label.new()
		hf_label.layout_mode = 2
		hf_label.size_flags_horizontal = 3
		hf_label.text = data["hf"]
		hf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(hf_label)
		
		list_container.add_child(item)

func setup_clickable_items():
	# Convert each HBoxContainer item to clickable buttons
	if not list_container:
		return
	
	for i in range(list_container.get_child_count()):
		var item = list_container.get_child(i)
		if item is HBoxContainer:
			# Make the item focusable
			item.focus_mode = Control.FOCUS_ALL
			# Make the item clickable by detecting mouse input
			item.gui_input.connect(_on_item_clicked.bind(i))
			# Add visual feedback for hover
			item.mouse_entered.connect(_on_item_hover_enter.bind(item))
			item.mouse_exited.connect(_on_item_hover_exit.bind(item))
			# Add focus feedback
			item.focus_entered.connect(_on_item_focus_enter.bind(item))
			item.focus_exited.connect(_on_item_focus_exit.bind(item))
			# Connect resize signal to update panel sizes
			item.resized.connect(_on_item_resized.bind(item))
	
	# Set focus to first item by default
	if list_container.get_child_count() > 0:
		var first_item = list_container.get_child(0)
		if first_item is HBoxContainer:
			first_item.grab_focus()
			current_focused_index = 0

func _on_item_clicked(event: InputEvent, item_index: int):
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.keycode == KEY_ENTER and event.pressed):
		print("History item ", item_index + 1, " selected")
		
		# Store the selected drill data in a way that can be accessed by the drill_replay scene
		if item_index < history_data.size():
			# Create a temporary file to store the drill data
			var file = FileAccess.open("user://selected_drill.dat", FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(history_data[item_index]))
				file.close()
		
		# Set the upper level scene for drill_replay
		var global_data = get_node("/root/GlobalData")
		if global_data:
			global_data.upper_level_scene = "res://scene/history.tscn"
		
		# Navigate to drill_replay scene
		get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func _on_item_hover_enter(item: HBoxContainer):
	# Add visual feedback when hovering over items
	var panel = Panel.new()
	panel.name = "HighlightPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Semi-transparent dark background
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.7, 0.7, 0.7, 1.0)  # Light border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Remove existing highlight if any
	var existing_panel = item.get_node_or_null("HighlightPanel")
	if existing_panel:
		existing_panel.queue_free()
	
	item.add_child(panel)
	item.move_child(panel, 0)  # Move to back
	# Size the panel to cover the entire item
	call_deferred("_size_panel", panel, item)

func _on_item_hover_exit(item: HBoxContainer):
	# Remove visual feedback when not hovering
	var panel = item.get_node_or_null("HighlightPanel")
	if panel:
		panel.queue_free()

func _on_item_focus_enter(item: HBoxContainer):
	# Add visual feedback when focusing on items
	var panel = Panel.new()
	panel.name = "FocusPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 0.7)  # Semi-transparent darker background for focus
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 1.0, 1.0, 1.0)  # White border for focus
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Remove existing focus highlight if any
	var existing_panel = item.get_node_or_null("FocusPanel")
	if existing_panel:
		existing_panel.queue_free()
	
	item.add_child(panel)
	item.move_child(panel, 0)  # Move to back
	# Size the panel to cover the entire item
	call_deferred("_size_panel", panel, item)

func _on_item_focus_exit(item: HBoxContainer):
	# Remove visual feedback when not focusing
	var panel = item.get_node_or_null("FocusPanel")
	if panel:
		panel.queue_free()

func _on_item_resized(item: HBoxContainer):
	# Update panel sizes when item is resized
	var hover_panel = item.get_node_or_null("HighlightPanel")
	if hover_panel:
		hover_panel.size = item.size
	
	var focus_panel = item.get_node_or_null("FocusPanel")
	if focus_panel:
		focus_panel.size = item.size

func _size_panel(panel: Panel, item: HBoxContainer):
	# Size the panel to cover the entire item
	if panel and item and is_instance_valid(panel) and is_instance_valid(item):
		# Use a small delay to ensure layout is complete
		var tree = get_tree()
		if tree:
			await tree.create_timer(0.01).timeout
			if panel and item and is_instance_valid(panel) and is_instance_valid(item):
				panel.size = item.size
				panel.position = Vector2.ZERO
		else:
			# Fallback if tree is not available
			if panel and item and is_instance_valid(panel) and is_instance_valid(item):
				panel.size = item.size
				panel.position = Vector2.ZERO

func _on_back_pressed():
	# Navigate back to the previous scene (intro or main menu)
	print("Back button pressed - returning to intro")
	get_tree().change_scene_to_file("res://scene/intro.tscn")

func _on_menu_control(directive: String):
	print("[History] Received menu_control signal with directive: ", directive)
	match directive:
		"volume_up":
			print("[History] Volume up")
			volume_up()
		"volume_down":
			print("[History] Volume down")
			volume_down()
		"power":
			print("[History] Power off")
			power_off()
		"back", "homepage":
			print("[History] ", directive, " - navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		"up":
			print("[History] Moving focus up")
			navigate_up()
		"down":
			print("[History] Moving focus down")
			navigate_down()
		"enter":
			print("[History] Enter pressed")
			select_current_item()
		_:
			print("[History] Unknown directive: ", directive)

func navigate_up():
	if list_container.get_child_count() == 0:
		return
	current_focused_index = (current_focused_index - 1 + list_container.get_child_count()) % list_container.get_child_count()
	var item = list_container.get_child(current_focused_index)
	if item is HBoxContainer:
		item.grab_focus()

func navigate_down():
	if list_container.get_child_count() == 0:
		return
	current_focused_index = (current_focused_index + 1) % list_container.get_child_count()
	var item = list_container.get_child(current_focused_index)
	if item is HBoxContainer:
		item.grab_focus()

func select_current_item():
	if current_focused_index < history_data.size():
		print("History item ", current_focused_index + 1, " selected via keyboard")
		
		# Store the selected drill data
		var file = FileAccess.open("user://selected_drill.dat", FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(history_data[current_focused_index]))
			file.close()
		
		# Set the upper level scene for drill_replay
		var global_data = get_node("/root/GlobalData")
		if global_data:
			global_data.upper_level_scene = "res://scene/history.tscn"
		
		# Navigate to drill_replay scene
		get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[History] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		print("[History] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[History] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		print("[History] HttpService singleton not found!")

func _on_volume_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[History] Volume HTTP response:", result, response_code, body_str)

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		print("[History] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		print("[History] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	print("[History] Shutdown HTTP response:", result, response_code, body_str)

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[History] Loaded language from GlobalData: ", language)
	else:
		print("[History] GlobalData not found or no language setting, using default English")
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
	print("[History] Set locale to: ", locale)

func update_ui_texts():
	# Update static UI elements with translations
	var title_label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
	var no_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/NoLabel")
	var time_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/TotalTimeLabel")
	var fast_shot_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/FastShotLabel")
	var score_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/ScoreLabel")
	var hf_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/HFLabel")
	var back_btn = get_node_or_null("MarginContainer/VBoxContainer/BackButton")
	
	if title_label:
		title_label.text = get_localized_title_text()
	if no_label:
		no_label.text = get_localized_no_text()
	if time_label:
		time_label.text = tr("time")
	if fast_shot_label:
		fast_shot_label.text = get_localized_fastest_shot_text()
	if score_label:
		score_label.text = tr("score")
	if hf_label:
		hf_label.text = tr("hit_factor_t")
	if back_btn:
		back_btn.text = get_localized_back_text()

func get_localized_title_text() -> String:
	# Since there's no "history" translation key, create localized text based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "训练记录"
		"zh_TW":
			return "訓練記錄"
		"ja":
			return "訓練履歴"
		_:
			return "Drill History"

func get_localized_no_text() -> String:
	# Create localized text for "No" based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "编号"
		"zh_TW":
			return "編號"
		"ja":
			return "番号"
		_:
			return "No"

func get_localized_fastest_shot_text() -> String:
	# Create localized short text for "Fastest Shot" based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "最快"
		"zh_TW":
			return "最快"
		"ja":
			return "最速"
		_:
			return "F'Shot"

func get_localized_back_text() -> String:
	# Create localized text for "Back" based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "返回"
		"zh_TW":
			return "返回"
		"ja":
			return "戻る"
		_:
			return "Back"
