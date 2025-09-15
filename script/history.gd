extends Control

# Performance optimization - disable debug prints in production
const DEBUG_PRINTS = false

@onready var list_container = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# History data structure to store drill results
var history_data = []
var current_focused_index = 0

# Sorting mode control
var sort_by_hit_factor = true  # When true, sort by hit factor; when false, sort by drill number

# Loading overlay components
var loading_overlay: Control
var loading_label: Label
var loading_timer: Timer
var dots_count = 0

# Loading state variables
var is_loading = false
var files_to_load = []
var current_file_index = 0
var max_index = 0

func _ready():
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Create loading overlay
	create_loading_overlay()
	
	# Update UI texts with translations
	update_ui_texts()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_PRINTS:
			print("[History] Connecting to WebSocketListener.menu_control signal")
	else:
		if DEBUG_PRINTS:
			print("[History] WebSocketListener singleton not found!")
	
	# Start loading history data
	load_history_data()

func _input(event):
	"""Handle direct keyboard input for sorting toggle"""
	if event is InputEventKey and event.pressed:
		# Toggle sort mode with 'S' or 'H' key
		if event.keycode == KEY_S or event.keycode == KEY_H:
			toggle_sort_mode()
			get_viewport().set_input_as_handled()  # Prevent further processing

func load_history_data():
	if DEBUG_PRINTS:
		print("[History] Starting to load history data via HTTP")
	history_data.clear()
	
	# Get max_index from GlobalData
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("max_index"):
		max_index = int(global_data.settings_dict.get("max_index", 0))
	else:
		max_index = 0
		if DEBUG_PRINTS:
			print("[History] No max_index found in GlobalData, no files to load")
		hide_loading_overlay()
		populate_list()
		setup_clickable_items()
		return
	
	if max_index <= 0:
		if DEBUG_PRINTS:
			print("[History] max_index is 0, no files to load")
		hide_loading_overlay()
		populate_list()
		setup_clickable_items()
		return
	
	# Prepare list of files to load
	files_to_load.clear()
	for i in range(1, max_index + 1):
		files_to_load.append(str(i))
	
	if DEBUG_PRINTS:
		print("[History] Loading ", files_to_load.size(), " files: ", files_to_load)
	
	# Show loading overlay and start loading
	show_loading_overlay()
	current_file_index = 0
	is_loading = true
	load_next_file()

func load_next_file():
	if current_file_index >= files_to_load.size():
		# All files loaded, finish up
		if DEBUG_PRINTS:
			print("[History] All files loaded successfully")
		
		# Sort history data based on current sort mode
		sort_history_data()
		
		hide_loading_overlay()
		populate_list()
		setup_clickable_items()
		update_hf_header_visual()  # Update header visual indicator
		return
	
	var file_id = files_to_load[current_file_index]
	if DEBUG_PRINTS:
		print("[History] Loading file ", current_file_index + 1, "/", files_to_load.size(), ": ", file_id)
	
	# Update loading progress
	update_loading_progress()
	
	# Load the file via HttpService
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.load_game(_on_file_loaded, file_id)
	else:
		if DEBUG_PRINTS:
			print("[History] HttpService not found, skipping file: ", file_id)
		current_file_index += 1
		load_next_file()

func _on_file_loaded(result, response_code, headers, body):
	var file_id = files_to_load[current_file_index]
	if DEBUG_PRINTS:
		print("[History] File load response for ", file_id, " - Result: ", result, ", Code: ", response_code)
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(body_str)
		
		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data"):
				var content_str = response_data["data"]
				var content_json = JSON.new()
				var content_parse_result = content_json.parse(content_str)
				
				if content_parse_result == OK:
					var data = content_json.data
					process_loaded_data(data, file_id)
				else:
					if DEBUG_PRINTS:
						print("[History] Failed to parse content JSON for ", file_id)
			else:
				if DEBUG_PRINTS:
					print("[History] No data field in response for ", file_id)
		else:
			if DEBUG_PRINTS:
				print("[History] Failed to parse response JSON for ", file_id)
	else:
		if DEBUG_PRINTS:
			print("[History] Failed to load file ", file_id, " - skipping")
	
	# Move to next file
	current_file_index += 1
	load_next_file()

func process_loaded_data(data: Dictionary, file_id: String):
	# Extract the drill number from file_id (e.g., "1.json" -> 1)
	if DEBUG_PRINTS:
		print("[History] Processing file_id: ", file_id)
	var drill_number = int(file_id.replace(".json", ""))
	if DEBUG_PRINTS:
		print("[History] Extracted drill_number: ", drill_number)
	
	if data.has("drill_summary") and data.has("records"):
		var drill_summary = data["drill_summary"]
		var records = data["records"]
		
		var total_score = 0
		for record in records:
			if record.has("score"):
				total_score += record["score"]
		
		var hf = 0.0
		if drill_summary.has("total_elapsed_time") and drill_summary["total_elapsed_time"] > 0:
			hf = total_score / drill_summary["total_elapsed_time"]
		
		var drill_data = {
			"drill_number": drill_number,
			"total_time": "%.2fs" % (drill_summary.get("total_elapsed_time", 0.0)),
			"fastest_shot": "%.2fs" % (drill_summary.get("fastest_shot_interval", 0.0) if drill_summary.get("fastest_shot_interval") != null else 0.0),
			"total_score": "%.1f" % total_score,
			"hf": "%.2f" % hf,
			"records": records
		}
		history_data.append(drill_data)
		if DEBUG_PRINTS:
			print("[History] Created drill_data: ", drill_data)
			print("[History] history_data now has ", history_data.size(), " items")
	else:
		if DEBUG_PRINTS:
			print("[History] Invalid data structure in file ", file_id)

func create_loading_overlay():
	# Create loading overlay similar to splash_loading
	loading_overlay = Control.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse input
	
	# Background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)  # Semi-transparent black
	bg_panel.add_theme_stylebox_override("panel", style)
	loading_overlay.add_child(bg_panel)
	
	# Center container
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.add_child(center_container)
	
	# VBox for content
	var vbox = VBoxContainer.new()
	center_container.add_child(vbox)
	
	# Loading label
	loading_label = Label.new()
	loading_label.text = tr("loading")
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(loading_label)
	
	# Add to scene
	add_child(loading_overlay)
	loading_overlay.visible = false
	
	# Setup loading animation timer
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.5
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	add_child(loading_timer)

func show_loading_overlay():
	if loading_overlay:
		loading_overlay.visible = true
		dots_count = 0
		loading_timer.start()

func hide_loading_overlay():
	if loading_overlay:
		loading_overlay.visible = false
		loading_timer.stop()
		is_loading = false

func update_loading_progress():
	if loading_label and files_to_load.size() > 0:
		var progress_text = "(" + str(current_file_index + 1) + "/" + str(files_to_load.size()) + ")"
		loading_label.text = tr("loading") + " " + progress_text

func _on_loading_timer_timeout():
	if not is_loading:
		return
		
	dots_count = (dots_count + 1) % 4
	var dots = ""
	for i in range(dots_count):
		dots += "."
	
	var base_text = tr("loading")
	if files_to_load.size() > 0:
		base_text += " (" + str(current_file_index + 1) + "/" + str(files_to_load.size()) + ")"
	
	loading_label.text = base_text + dots

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
		no_label.add_theme_font_size_override("font_size", 20)
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
		time_label.add_theme_font_size_override("font_size", 20)
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
		fast_label.add_theme_font_size_override("font_size", 20)
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
		score_label.add_theme_font_size_override("font_size", 20)
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
		hf_label.add_theme_font_size_override("font_size", 20)
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
		if DEBUG_PRINTS:
			print("History item ", item_index + 1, " selected")
		
		# Store drill data in GlobalData instead of creating temp file
		if item_index < history_data.size():
			var drill_data = history_data[item_index]
			if DEBUG_PRINTS:
				print("[History] Storing drill data in GlobalData for drill ", drill_data["drill_number"])
			var global_data = get_node("/root/GlobalData")
			if global_data:
				global_data.selected_drill_data = drill_data
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
	if DEBUG_PRINTS:
		print("Back button pressed - returning to intro")
	get_tree().change_scene_to_file("res://scene/intro.tscn")

func _on_menu_control(directive: String):
	if DEBUG_PRINTS:
		print("[History] Received menu_control signal with directive: ", directive)
	match directive:
		"volume_up":
			if DEBUG_PRINTS:
				print("[History] Volume up")
			volume_up()
		"volume_down":
			if DEBUG_PRINTS:
				print("[History] Volume down")
			volume_down()
		"power":
			if DEBUG_PRINTS:
				print("[History] Power off")
			power_off()
		"back", "homepage":
			if DEBUG_PRINTS:
				print("[History] ", directive, " - navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu.tscn")
		"up":
			if DEBUG_PRINTS:
				print("[History] Moving focus up")
			navigate_up()
		"down":
			if DEBUG_PRINTS:
				print("[History] Moving focus down")
			navigate_down()
		"enter":
			if DEBUG_PRINTS:
				print("[History] Enter pressed")
			select_current_item()
		"sort", "toggle_sort":
			if DEBUG_PRINTS:
				print("[History] Sort mode toggle")
			toggle_sort_mode()
		_:
			if DEBUG_PRINTS:
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
		if DEBUG_PRINTS:
			print("History item ", current_focused_index + 1, " selected via keyboard")
		
		# Store drill data in GlobalData instead of creating temp file
		var drill_data = history_data[current_focused_index]
		if DEBUG_PRINTS:
			print("[History] Storing drill data in GlobalData for drill ", drill_data["drill_number"])
		var global_data = get_node("/root/GlobalData")
		if global_data:
			global_data.selected_drill_data = drill_data
			global_data.upper_level_scene = "res://scene/history.tscn"
		
		# Navigate to drill_replay scene
		get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_PRINTS:
			print("[History] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		if DEBUG_PRINTS:
			print("[History] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_PRINTS:
			print("[History] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		if DEBUG_PRINTS:
			print("[History] HttpService singleton not found!")

func _on_volume_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_PRINTS:
		print("[History] Volume HTTP response:", result, response_code, body_str)

func toggle_sort_mode():
	"""Toggle between sorting by hit factor and sorting by drill number"""
	sort_by_hit_factor = !sort_by_hit_factor
	if DEBUG_PRINTS:
		print("[History] Sort mode toggled - now sorting by: ", "Hit Factor (desc)" if sort_by_hit_factor else "Drill Number (asc)")
	
	# Re-sort and refresh the display
	sort_history_data()
	populate_list()
	setup_clickable_items()
	update_hf_header_visual()

func sort_history_data():
	"""Sort history data based on current sort mode"""
	if sort_by_hit_factor:
		# Sort by hit factor in descending order (highest first)
		history_data.sort_custom(func(a, b): return float(a["hf"]) > float(b["hf"]))
	else:
		# Sort by drill number in ascending order
		history_data.sort_custom(func(a, b): return a["drill_number"] < b["drill_number"])

func update_hf_header_visual():
	"""Update the HF header to show visual indication of sorting mode"""
	var hf_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/HFLabel")
	if hf_label:
		if sort_by_hit_factor:
			hf_label.text = "  HF ↓"  # Down arrow indicates descending sort
			hf_label.modulate = Color(1.0, 0.8, 0.2)  # Golden color to indicate active sorting
		else:
			hf_label.text = "  HF  "
			hf_label.modulate = Color.WHITE  # Default color

func power_off():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_PRINTS:
			print("[History] Sending power off HTTP request...")
		http_service.shutdown(_on_shutdown_response)
	else:
		if DEBUG_PRINTS:
			print("[History] HttpService singleton not found!")

func _on_shutdown_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_PRINTS:
		print("[History] Shutdown HTTP response:", result, response_code, body_str)

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if DEBUG_PRINTS:
			print("[History] Loaded language from GlobalData: ", language)
	else:
		if DEBUG_PRINTS:
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
	if DEBUG_PRINTS:
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
