extends Control

@onready var scroll: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var list_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
var selected_index: int = -1

func _ready() -> void:
	# Populate initial messages from the onboard_debug_singleton (autoload)
	var ods = get_node_or_null("/root/OnboardDebugSingleton")
	if ods:
		# Add existing cached messages
		var msgs = ods.get_messages()
		for m in msgs:
			_append_row(int(m.get("priority", 0)), str(m.get("content", "")), str(m.get("sender", "")))
		# Listen for new messages appended while this UI is open
		var cb = Callable(self, "_on_message_appended")
		if not ods.is_connected("message_appended", cb):
			ods.connect("message_appended", cb)
			print("OnboardDebug: Connected to OnboardDebugSingleton.message_appended")
	else:
		print("OnboardDebug: OnboardDebugSingleton not found; live updates disabled")

	# Connect to MenuController for remote control directives (home/up/down)
	var mc = get_node_or_null("/root/MenuController")
	if mc:
		var cb2 = Callable(self, "_on_menu_control")
		if not mc.is_connected("menu_control", cb2):
			mc.connect("menu_control", cb2)
			print("OnboardDebug: Connected to MenuController.menu_control")
		else:
			print("OnboardDebug: Already connected to MenuController.menu_control")
		# Compose is handled by Option -> change_scene flow; no need to listen here
	else:
		print("OnboardDebug: MenuController not found; remote directives disabled")

func _on_compose_request() -> void:
	print("OnboardDebug: Received compose request")

func _exit_tree() -> void:
	var sb = get_node_or_null("/root/SignalBus")
	if sb:
		var cb = Callable(self, "_on_onboard_debug_info")
		if sb.is_connected("onboard_debug_info", cb):
			sb.disconnect("onboard_debug_info", cb)

	var mc = get_node_or_null("/root/MenuController")
	if mc:
		var cb2 = Callable(self, "_on_menu_control")
		if mc.is_connected("menu_control", cb2):
			mc.disconnect("menu_control", cb2)

func _on_onboard_debug_info(_priority: int, content: String, sender: String) -> void:
	# Keep compatibility: if this function is called directly, append a row
	_append_row(int(_priority), str(content), str(sender))

func _on_message_appended(priority: int, content: String, sender: String) -> void:
	# Called when singleton appends a new message while this UI is open
	_append_row(priority, content, sender)

func _append_row(_priority: int, content: String, sender: String) -> void:
	# Create a new panel row showing sender and content (allows background highlight)
	var row = Panel.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 100) # reasonable row height

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sender_label.custom_minimum_size = Vector2(48, 0)
	sender_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1))

	var content_label = Label.new()
	content_label.custom_minimum_size = Vector2(500, 0)
	content_label.autowrap_mode = 3 # Smart Word
	content_label.text = content

	hbox.add_child(sender_label)
	hbox.add_child(content_label)
	margin.add_child(hbox)
	row.add_child(margin)
	list_vbox.add_child(row)

	# If nothing is selected yet, select the first row by default
	if selected_index == -1:
		selected_index = 0
		_update_selection_visuals()

	# Auto-scroll to bottom
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var maxv = _get_vbar_max()
	scroll.scroll_vertical = int(maxv)


func _get_vbar_max() -> float:
	# Max scroll is content height - viewport height (can't be negative)
	var content_h = 0.0
	if list_vbox:
		content_h = list_vbox.get_combined_minimum_size().y
	var viewport_h = scroll.get_size().y if scroll else 0.0
	var maxv2 = max(0.0, content_h - viewport_h)
	return maxv2

func _on_menu_control(directive: String) -> void:
	# Handle remote directives for navigation: homepage/up/down
	if not scroll:
		return
	var count = list_vbox.get_child_count()
	if count == 0:
		return
	match directive:
		"homepage", "home":
			# Navigate to main menu
			print("OnboardDebug: homepage -> navigating to main menu")
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		"up":
			# Move selection up one row (wrap to last if none selected)
			if selected_index == -1:
				selected_index = count - 1
			else:
				selected_index = max(0, selected_index - 1)
			_update_selection_visuals()
			_ensure_selected_visible()
			print("OnboardDebug: up -> selected", selected_index)
		"down":
			# Move selection down one row
			if selected_index == -1:
				selected_index = 0
			else:
				selected_index = min(count - 1, selected_index + 1)
			_update_selection_visuals()
			_ensure_selected_visible()
			print("OnboardDebug: down -> selected", selected_index)
		_:
			# ignore other directives
			pass

func _update_selection_visuals() -> void:
	var children = list_vbox.get_children()
	for i in range(children.size()):
		var row = children[i]
		if i == selected_index:
			# row.modulate = Color(0.15, 0.25, 0.35, 1)
			# update text color to make sure it's readable
			var child0 = row.get_child(0)
			var hbox = child0
			# if there's a MarginContainer wrapper, descend into it
			if child0 is MarginContainer and child0.get_child_count() > 0:
				hbox = child0.get_child(0)
			for label in hbox.get_children():
				if label is Label:
					label.add_theme_color_override("font_color", Color(1, 0.8, 0))
		else:
			row.modulate = Color(1, 1, 1, 1)
			var child02 = row.get_child(0)
			var hbox2 = child02
			if child02 is MarginContainer and child02.get_child_count() > 0:
				hbox2 = child02.get_child(0)
			for label2 in hbox2.get_children():
				if label2 is Label:
					# reset theme override by setting a neutral color
					label2.add_theme_color_override("font_color", Color(0.8, 0.9, 1))

func _ensure_selected_visible() -> void:
	if not scroll:
		return
	if selected_index < 0 or selected_index >= list_vbox.get_child_count():
		return
	var row = list_vbox.get_child(selected_index)
	# use position (local to parent) to find vertical offset
	var y = row.position.y
	var viewport_h = scroll.get_size().y
	# center the selected row roughly in the viewport
	var target = y - viewport_h * 0.5
	var maxv = _get_vbar_max()
	var clamped = clamp(target, 0.0, maxv)
	scroll.scroll_vertical = int(clamped)
