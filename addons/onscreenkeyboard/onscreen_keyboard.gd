@tool
extends PanelContainer

###########################
## SETTINGS
###########################

@export var auto_show:bool = true
@export var animate:bool = true

@export_file var custom_layout_file
@export var set_tool_tip := true
@export_group("Style")
@export var separation:Vector2i = Vector2i(0,0)
var style_background:StyleBoxFlat = null
@export var background:StyleBoxFlat = null:
	set(new_val):
		style_background = new_val
		background = new_val
	get:
		return style_background
var style_normal:StyleBoxFlat = null
@export var normal:StyleBoxFlat = null:
	set(new_val):
		style_normal = new_val
		normal = new_val
	get:
		return style_normal
var style_hover:StyleBoxFlat = null
@export var hover:StyleBoxFlat = null:
	set(new_val):
		style_hover = new_val
		hover = new_val
	get:
		return style_hover
var style_pressed:StyleBoxFlat = null
@export var pressed:StyleBoxFlat = null:
	set(new_val):
		style_pressed = new_val
		pressed = new_val
	get:
		return style_pressed
var style_special_keys:StyleBoxFlat = null
@export var special_keys:StyleBoxFlat = null:
	set(new_val):
		style_special_keys = new_val
		special_keys = new_val
	get:
		return style_special_keys
@export_group("Font")
@export var font:FontFile
@export var font_size:int = 20
@export var font_color_normal:Color = Color(1,1,1)
@export var font_color_hover:Color = Color(1,1,1)
@export var font_color_pressed:Color = Color(1,1,1)
@export var debug_remote: bool = true

###########################
## SIGNALS
###########################

signal layout_changed

###########################
## PANEL 
###########################

func _enter_tree():
	if not get_tree().get_root().size_changed.is_connected(size_changed):
		get_tree().get_root().size_changed.connect(size_changed)
	_init_keyboard()

	# Connect to WebSocketListener.menu_control so remote directives can
	# move focus around the onscreen keyboard and simulate Enter.
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		# connect directly; duplicate connects are unlikely as _enter_tree runs once
		ws_listener.menu_control.connect(_on_ws_menu_control)

#func _exit_tree():
#    pass

#func _process(delta):
#    pass

func _input(event):
	_update_auto_display_on_input(event)


func size_changed():
	if auto_show and visible:
		_hide_keyboard()


###########################
## INIT
###########################
var KeyboardButton
var KeyListHandler

var layouts = []
var keys = []
var capslock_keys = []
var uppercase = false

var tween_position
var tween_speed = .2

var hide_position = Vector2()
var layout_key_matrices = {} # map layout_container -> 2D array of keys

func _init_keyboard():
	if custom_layout_file == null:
		var default_layout = preload("default_layout.gd").new()
		_create_keyboard(default_layout.data)
	else:
		_create_keyboard(_load_json(custom_layout_file))

	# init positioning without animation
	var tmp_anim = animate
	animate = false
	if visible:
		_hide_keyboard()
	elif visible:
		_show_keyboard()
	animate = tmp_anim


###########################
## HIDE/SHOW
###########################

var focus_object = null
var last_input_focus = null
var last_activated_key = null

func show():
	_show_keyboard()

func hide():
	_hide_keyboard()

var released = true
func _update_auto_display_on_input(event):
	if auto_show == false:
		return

	if event is InputEventMouseButton:
		released = !released
		if released == false:
			return

		var focus_object = get_viewport().gui_get_focus_owner()
		if focus_object != null:
			var click_on_input = Rect2(focus_object.global_position, focus_object.size).has_point(get_global_mouse_position())
			var click_on_keyboard = Rect2(global_position, size).has_point(get_global_mouse_position())

			if click_on_input:
				if is_keyboard_focus_object(focus_object):
					_show_keyboard()
			elif click_on_keyboard:
				_show_keyboard()
			else:
				_hide_keyboard()

	if event is InputEventKey:
		var focus_object = get_viewport().gui_get_focus_owner()
		if focus_object != null:
			if event.keycode == KEY_ENTER:
				if is_keyboard_focus_object_complete_on_enter(focus_object):
					focus_object.release_focus()
					_hide_keyboard()


func _hide_keyboard(key_data=null):
	if animate:
		var new_y_pos = get_viewport().get_visible_rect().size.y + 10
		animate_position(Vector2(position.x, new_y_pos), true)
	else:
		change_visibility(false)
		# clear stored input focus when keyboard is hidden
		last_input_focus = null


func _show_keyboard(key_data=null):
	# Store the current focused input control so simulated key events
	# can be directed to it even when keyboard buttons have focus
	var fo = get_viewport().gui_get_focus_owner()
	if fo != null and is_keyboard_focus_object(fo):
		last_input_focus = fo

	change_visibility(true)
	if animate:
		var new_y_pos = get_viewport().get_visible_rect().size.y - size.y
		animate_position(Vector2(position.x, new_y_pos))


func animate_position(new_position, trigger_visibility:bool=false):
	var tween = get_tree().create_tween()
	if trigger_visibility:
		tween.finished.connect(change_visibility.bind(!visible))
	tween.tween_property(
		self,"position",
		Vector2(new_position),
		tween_speed
	).set_trans(Tween.TRANS_SINE)


func change_visibility(value):
	if value:
		super.show()
	else:
		_set_caps_lock(false)
		super.hide()
	visibility_changed.emit()


###########################
##  KEY LAYOUT
###########################

var prev_prev_layout = null
var previous_layout = null
var current_layout = null

func set_active_layout_by_name(name):
	for layout in layouts:
		if layout.get_meta("layout_name") == str(name):
			_show_layout(layout)
		else:
			_hide_layout(layout)


func _show_layout(layout):
	layout.show()
	current_layout = layout


func _hide_layout(layout):
	layout.hide()


func _switch_layout(key_data):
	prev_prev_layout = previous_layout
	previous_layout = current_layout
	layout_changed.emit(key_data.get("layout-name"))

	for layout in layouts:
		_hide_layout(layout)

	if key_data.get("layout-name") == "PREVIOUS-LAYOUT":
		if prev_prev_layout != null:
			_show_layout(prev_prev_layout)
			return

	for layout in layouts:
		if layout.get_meta("layout_name") == key_data.get("layout-name"):
			_show_layout(layout)
			return

	_set_caps_lock(false)


###########################
## KEY EVENTS
###########################

func _set_caps_lock(value: bool):
	uppercase = value
	if debug_remote:
		print("[onscreenkbd] _set_caps_lock: uppercase=", uppercase)
	for key in capslock_keys:
		if value:
			if key.get_draw_mode() != BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
		else:
			if key.get_draw_mode() == BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed

	for key in keys:
		key.change_uppercase(value)


func _trigger_uppercase(key_data):
	uppercase = !uppercase
	_set_caps_lock(uppercase)
	if debug_remote:
		print("[onscreenkbd] _trigger_uppercase: toggled uppercase=", uppercase, " key_data=", key_data)


func _key_released(key_data):
	if key_data.has("output"):
		var key_value = key_data.get("output")

		###########################
		## DISPATCH InputEvent 
		###########################

		var input_event_key = InputEventKey.new()
		input_event_key.shift_pressed = uppercase
		input_event_key.alt_pressed = false
		input_event_key.meta_pressed = false
		input_event_key.ctrl_pressed = false
		input_event_key.pressed = true

		# If we have a stored last input focus (LineEdit/TextEdit),
		# return focus to it so the parsed InputEventKey goes to the
		# intended control rather than remaining on the keyboard button.
		var target_focus = last_input_focus
		if target_focus == null:
			target_focus = get_viewport().gui_get_focus_owner()
		if target_focus != null and is_keyboard_focus_object(target_focus):
			target_focus.grab_focus()

		var key = KeyListHandler.get_key_from_string(key_value)
		if !uppercase && KeyListHandler.has_lowercase(key_value):
			key +=32

		input_event_key.keycode = key
		input_event_key.unicode = key

		# Deliver the key after the current call stack returns. Buttons call
		# release_focus() after emitting the 'released' signal which would
		# steal focus; deferring ensures we re-grab focus and then send the
		# InputEvent so the target control receives it.
		# determine proper target again (last_input_focus preferred)
		var tgt = last_input_focus
		if tgt == null:
			tgt = get_viewport().gui_get_focus_owner()
		if debug_remote:
			print("[onscreenkbd] _key_released: key=", key_value, " last_input_focus=", last_input_focus, " current_focus=", get_viewport().gui_get_focus_owner(), " chosen_tgt=", tgt)
		# schedule deferred delivery and pass the original key string so we
		# can fallback to direct insertion if the InputEvent is not handled
		call_deferred("_deliver_key_event", tgt, input_event_key, key_value)

		###########################
		## DISABLE CAPSLOCK AFTER 
		###########################
		# _set_caps_lock will be called after delivery in _deliver_key_event


###########################
## CONSTRUCT KEYBOARD
###########################

func _set_key_style(style_name:String, key: Control, style:StyleBoxFlat):
	if style != null:
		key.add_theme_stylebox_override(style_name, style)


func _deliver_key_event(target, input_event_key: InputEventKey, key_value = null):
	# If target is a LineEdit/TextEdit, ensure it has focus then deliver
	if target != null and is_keyboard_focus_object(target):
		target.grab_focus()
	# Finally, parse the input event so the focused control receives it
	if debug_remote:
		print("[onscreenkbd] _deliver_key_event: before parse current_focus=", get_viewport().gui_get_focus_owner(), " target=", target, " keycode=", input_event_key.keycode, " unicode=", input_event_key.unicode, " uppercase=", uppercase)
	# If the target control exposes _gui_input, deliver directly to it so
	# the control processes the InputEventKey as if it originated from UI.
	var delivered = false
	if target != null and target.has_method("_gui_input"):
		# call directly on the control
		target._gui_input(input_event_key)
		delivered = true
	else:
		# fallback to global input parsing
		Input.parse_input_event(input_event_key)
		delivered = true
	if debug_remote:
		print("[onscreenkbd] _deliver_key_event: after parse current_focus=", get_viewport().gui_get_focus_owner(), " delivered=", delivered)
	if debug_remote:
		print("[onscreenkbd] _deliver_key_event: after parse current_focus=", get_viewport().gui_get_focus_owner())

	# Once delivered, caps lock will be disabled in finalize step so
	# fallback insertion can consult the correct `uppercase` state.

	# Defer a finalization step so the control has time to process the event
	# and potentially update its text before we check and perform fallback insertion
	var before_text = null
	if key_value != null and target != null and is_keyboard_focus_object(target):
		if target.has_method("get_text"):
			before_text = target.get_text()
		elif target.has("text") or target.has_method("text"):
			# Some controls expose `text` as a property
			before_text = target.text
	call_deferred("_finalize_key_delivery", target, key_value, before_text)


func _finalize_key_delivery(target, key_value, before_text):
	# After control processed the InputEvent, check if text changed; if not,
	# insert it directly. This avoids timing issues where immediate checks
	# see no change.
	if debug_remote:
		print("[onscreenkbd] _finalize_key_delivery: target=", target, " key_value=", key_value, " before_text=", before_text, " last_activated_key=", last_activated_key)

	if target == null:
		# Still ensure we clear last_activated_key
		if last_activated_key != null:
			if last_activated_key.is_inside_tree():
				last_activated_key.grab_focus()
			last_activated_key = null
		return

	# Read text after the event
	var after_text = null
	if target is LineEdit:
		after_text = target.text
	elif target is TextEdit:
		after_text = target.get_text()
	if debug_remote:
		print("[onscreenkbd] _finalize_key_delivery: after_text=", after_text)

	# If text hasn't changed, insert the character directly or perform
	# special actions for control keys (Backspace/Delete).
	var did_insert = false
	if key_value != null and before_text != null:
		if after_text == before_text:
			# Ensure target has focus so insertion/deletion happens at cursor
			target.grab_focus()

			# Handle deletion keys specially
			if str(key_value) == "Backspace" or str(key_value) == "Delete":
				var text = ""
				# Read current text safely
				if target is LineEdit:
					if target.has_method("get_text"):
						text = str(target.get_text())
					elif target.has("text"):
						text = str(target.text)

					# Try to determine caret position
					var caret_pos = -1
					if target.has_method("get_caret_position"):
						caret_pos = int(target.get_caret_position())
					elif target.has("caret_position"):
						caret_pos = int(target.caret_position)
					else:
						# fallback to end of text
						caret_pos = text.length()

					if caret_pos > 0:
						var new_text = ""
						# remove character before caret
						if caret_pos <= text.length():
							new_text = text.substr(0, caret_pos - 1) + text.substr(caret_pos, text.length() - caret_pos)
						else:
							new_text = text.substr(0, max(0, text.length() - 1))

						# Write text back safely
						if target.has_method("set_text"):
							target.set_text(new_text)
						elif target.has("text"):
							target.text = new_text

						# restore caret position if possible
						if target.has_method("set_caret_position"):
							target.set_caret_position(max(0, caret_pos - 1))
						elif target.has("caret_position"):
							target.caret_position = max(0, caret_pos - 1)

						did_insert = true
					else:
						# nothing to delete
						did_insert = false

				elif target is TextEdit:
					# Use TextEdit get_text/set_text; try to delete at cursor if possible
					if target.has_method("get_text") and target.has_method("set_text"):
						var full = str(target.get_text())

						# Try to get a cursor index if available (best-effort):
						var cursor_idx = -1
						# Godot TextEdit doesn't expose a single index in all versions,
						# so default to deleting the last character as a safe fallback.
						cursor_idx = full.length()

						if cursor_idx > 0:
							var new_full = full.substr(0, max(0, cursor_idx - 1)) + full.substr(cursor_idx, full.length() - cursor_idx)
							target.set_text(new_full)
							did_insert = true

				# If target is neither LineEdit nor TextEdit, do nothing special

			# Note: LeftArrow/RightArrow are intentionally disabled here
			# to avoid conflicting with remote navigation directives.
			# Only Backspace/Delete should be routed to input controls.

			else:
				# Regular character insertion fallback (existing behavior)
				if target is LineEdit:
					var out_char = str(key_value)
					if not uppercase and KeyListHandler.has_lowercase(key_value):
						out_char = str(key_value).to_lower()
					if target.has_method("insert_text_at_cursor"):
						target.insert_text_at_cursor(out_char)
						did_insert = true
					else:
						# fallback: append to property or use get/set
						if target.has("text"):
							target.text = str(target.text) + out_char
							did_insert = true
						elif target.has_method("get_text") and target.has_method("set_text"):
							target.set_text(str(target.get_text()) + out_char)
							did_insert = true
				elif target is TextEdit:
					# TextEdit variations differ across Godot versions; use get/set_text fallback
					if target.has_method("get_text") and target.has_method("set_text"):
						var out_char = str(key_value)
						if not uppercase and KeyListHandler.has_lowercase(key_value):
							out_char = str(key_value).to_lower()
						target.set_text(str(target.get_text()) + out_char)
						did_insert = true

	if debug_remote:
		print("[onscreenkbd] _finalize_key_delivery: did_insert=", did_insert)

	# Restore focus to the activated key for websocket navigation
	if last_activated_key != null:
		if last_activated_key.is_inside_tree():
			last_activated_key.grab_focus()
		last_activated_key = null

	# Disable caps lock after we've finalized delivery
	_set_caps_lock(false)


func _refocus_last_activated_key():
	if last_activated_key != null and last_activated_key.is_inside_tree():
		last_activated_key.grab_focus()


func _create_keyboard(layout_data):
	if layout_data == null:
		print("ERROR. No layout file found")
		return

	KeyListHandler = preload("keylist.gd").new()
	KeyboardButton = preload("keyboard_button.gd")

	var ICON_DELETE = preload("icons/delete.png")
	var ICON_SHIFT = preload("icons/shift.png")
	var ICON_LEFT = preload("icons/left.png")
	var ICON_RIGHT = preload("icons/right.png")
	var ICON_HIDE = preload("icons/hide.png")
	var ICON_ENTER = preload("icons/enter.png")

	var data = layout_data

	if style_background != null:
		add_theme_stylebox_override('panel', style_background)

	var index = 0
	for layout in data.get("layouts"):

		var layout_container = PanelContainer.new()

		if style_background != null:
			layout_container.add_theme_stylebox_override('panel', style_background)

		# SHOW FIRST LAYOUT ON DEFAULT
		if index > 0:
			layout_container.hide()
		else:
			current_layout = layout_container

		var layout_name = layout.get("name")
		layout_container.set_meta("layout_name", layout_name)
		if set_tool_tip:
			layout_container.tooltip_text = layout_name
		layouts.push_back(layout_container)
		add_child(layout_container)

		var base_vbox = VBoxContainer.new()
		base_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		base_vbox.size_flags_vertical = SIZE_EXPAND_FILL
		# theme override for spacing
		base_vbox.add_theme_constant_override("separation", separation.y)

		# matrix for this layout
		var matrix = []

		for row in layout.get("rows"):

			var key_row = HBoxContainer.new()
			key_row.size_flags_horizontal = SIZE_EXPAND_FILL
			key_row.size_flags_vertical = SIZE_EXPAND_FILL
			key_row.add_theme_constant_override("separation", separation.x)

			# Collect row keys so we can support keyboard navigation via websocket
			var row_keys = []

			for key in row.get("keys"):
				var new_key = KeyboardButton.new(key)

				_set_key_style("normal",new_key, style_normal)
				_set_key_style("hover",new_key, style_hover)
				_set_key_style("pressed",new_key, style_pressed)

				new_key.set('theme_override_font_sizes/font_size', font_size)
				if font != null:
					new_key.set('theme_override_fonts/font', font)
				if font_color_normal != null:
					new_key.set('theme_override_colors/font_color', font_color_normal)
					new_key.set('theme_override_colors/font_hover_color', font_color_hover)
					new_key.set('theme_override_colors/font_pressed_color', font_color_pressed)
					new_key.set('theme_override_colors/font_disabled_color', font_color_normal)

				new_key.released.connect(_key_released)

				if key.has("type"):
					if key.get("type") == "switch-layout":
						new_key.released.connect(_switch_layout)
						_set_key_style("normal",new_key, style_special_keys)
					elif key.get("type") == "special":
						_set_key_style("normal",new_key, style_special_keys)
					elif key.get("type") == "special-shift":
						new_key.released.connect(_trigger_uppercase)
						new_key.toggle_mode = true
						capslock_keys.push_back(new_key)
						_set_key_style("normal",new_key, style_special_keys)
					elif key.get("type") == "special-hide-keyboard":
						new_key.released.connect(_hide_keyboard)
						_set_key_style("normal",new_key, style_special_keys)

				# SET ICONS
				if key.has("display-icon"):
					var icon_data = str(key.get("display-icon")).split(":")
					# PREDEFINED
					if str(icon_data[0])=="PREDEFINED":
						if str(icon_data[1])=="DELETE":
							new_key.set_icon(ICON_DELETE)
						elif str(icon_data[1])=="SHIFT":
							new_key.set_icon(ICON_SHIFT)
						elif str(icon_data[1])=="LEFT":
							new_key.set_icon(ICON_LEFT)
						elif str(icon_data[1])=="RIGHT":
							new_key.set_icon(ICON_RIGHT)
						elif str(icon_data[1])=="HIDE":
							new_key.set_icon(ICON_HIDE)
						elif str(icon_data[1])=="ENTER":
							new_key.set_icon(ICON_ENTER)
					# CUSTOM
					if str(icon_data[0])=="res":
						var texture = load(key.get("display-icon"))
						new_key.set_icon(texture)

					if font_color_normal != null:
						new_key.set_icon_color(font_color_normal)

				key_row.add_child(new_key)
				keys.push_back(new_key)
				row_keys.push_back(new_key)

			base_vbox.add_child(key_row)
			# push the completed row into the matrix for this layout
			matrix.push_back(row_keys)

		layout_container.add_child(base_vbox)
		# store matrix for this layout container so navigation can be layout-aware
		layout_key_matrices[layout_container] = matrix
		index += 1


###########################
## LOAD SETTINGS
###########################

func _load_json(file_path) -> Variant:
	var json = JSON.new()
	var json_string = _load_file(file_path)
	var error = json.parse(json_string)
	if error == OK:
		var data_received = json.data
		#        print(data_received)
		if typeof(data_received) == TYPE_DICTIONARY:
			return data_received
		else:
			return {"msg": "unexpected data => expected DICTIONARY"}
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return {"msg":json.get_error_message()}


func _load_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error loading File. Error: ")

	var content = file.get_as_text()
	file.close()
	return content


###########################
## HELPER
###########################

func is_keyboard_focus_object_complete_on_enter(focus_object):
	if focus_object is LineEdit:
		return true
	return false

func is_keyboard_focus_object(focus_object):
	if focus_object is LineEdit or focus_object is TextEdit:
		return true
	return false


# --- WebSocket menu_control handling ---------------------------------
func _on_ws_menu_control(directive: String):
	# only handle navigation when the keyboard is visible
	if not visible:
		return

	directive = str(directive)
	match directive:
		"up":
			_move_focus("up")
		"down":
			_move_focus("down")
		"left":
			_move_focus("left")
		"right":
			_move_focus("right")
		"enter":
			_simulate_enter()
		_:
			# ignore other directives
			pass


func _move_focus(direction: String):
	# Determine the active matrix for current_layout
	var matrix = layout_key_matrices.get(current_layout, null)
	if matrix == null:
		return

	# Find currently focused key in the matrix
	var focused_row = -1
	var focused_col = -1
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		for r in range(matrix.size()):
			for c in range(matrix[r].size()):
				if matrix[r][c] == focus_owner:
					focused_row = r
					focused_col = c
					break
			if focused_row != -1:
				break

	# If no focus, default to top-left (0,0)
	if focused_row == -1:
		focused_row = 0
		focused_col = 0

	var new_row = focused_row
	var new_col = focused_col

	match direction:
		"up":
			new_row = max(0, focused_row - 1)
			# keep same column if possible, otherwise clamp
			new_col = min(focused_col, matrix[new_row].size() - 1)
		"down":
			new_row = min(matrix.size() - 1, focused_row + 1)
			new_col = min(focused_col, matrix[new_row].size() - 1)
		"left":
			new_col = max(0, focused_col - 1)
			# ensure row is valid
			new_row = focused_row
		"right":
			new_col = min(matrix[focused_row].size() - 1, focused_col + 1)
			new_row = focused_row

	# If we didn't move, stop
	if new_row == focused_row and new_col == focused_col:
		return

	# Move focus to the new key
	var new_key = matrix[new_row][new_col]
	if new_key != null:
		new_key.grab_focus()


func _simulate_enter():
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		# If no focus, default to top-left key of current layout
		var matrix = layout_key_matrices.get(current_layout, null)
		if matrix == null or matrix.size() == 0:
			return
		var default_key = matrix[0][0]
		if default_key:
			# Simulate click by calling the keyboard button handler so behavior
			# matches a real button press; remember the activated key so we
			# can re-focus it after delivering input to the input control.
			last_activated_key = default_key
			default_key._on_button_up()
		else:
			return
	else:
		# If focus_owner is an input control (LineEdit/TextEdit), send an Enter key event
		if is_keyboard_focus_object(focus_owner):
			var ev = InputEventKey.new()
			ev.pressed = true
			ev.keycode = KEY_ENTER
			ev.unicode = KEY_ENTER
			# Prefer inserting into the focused control; ensure we remember it
			last_input_focus = focus_owner
			call_deferred("_deliver_key_event", focus_owner, ev)
			return

		# If focused owner is a keyboard button, emit its released
		if focus_owner is Button:
			# If the button is our keyboard button, simulate press and
			# remember it so we can re-focus after delivering input.
			last_activated_key = focus_owner
			if focus_owner.has_method("_on_button_up"):
				# call the button handler
				# If this button corresponds to a key that should act on
				# the input control (e.g. Backspace/LeftArrow/RightArrow/Delete)
				# and we have a stored last_input_focus, then dispatch the
				# InputEvent directly to that control so keyboard focus is
				# preserved for websocket-driven interactions.
				var handled_by_input_focus = false
				var kd = null
				if focus_owner.has_method("change_uppercase"):
					kd = focus_owner.key_data
				# kd may be null for generic Buttons
				if typeof(kd) == TYPE_DICTIONARY and kd.has("output") and last_input_focus != null and is_keyboard_focus_object(last_input_focus):
					var out = str(kd.get("output"))
					if out == "Backspace" or out == "Delete":
						# Build InputEventKey for this output and deliver to last_input_focus
						var ev = InputEventKey.new()
						ev.pressed = true
						var sc = KeyListHandler.get_key_from_string(out)
						if not uppercase and KeyListHandler.has_lowercase(out):
							sc += 32
						ev.keycode = sc
						ev.unicode = sc
						# deliver to stored input focus (deferred to maintain order)
						last_input_focus.grab_focus()
						call_deferred("_deliver_key_event", last_input_focus, ev, out)
						handled_by_input_focus = true
				if not handled_by_input_focus:
					# default behavior: call the button handler so normal keyboard
					# buttons animate and perform layout switches, etc.
					focus_owner._on_button_up()
					# If this is our KeyboardButton instance, check its key_data
					# to decide whether to keep focus on it after remote activation.
					if focus_owner.has_method("change_uppercase"):
						var kd2 = focus_owner.key_data
						if typeof(kd2) == TYPE_DICTIONARY and not kd2.has("output"):
							call_deferred("_refocus_last_activated_key")
			else:
				# Generic emit
				if focus_owner.has_signal("released"):
					focus_owner.released.emit({})
					# generic buttons may not have key_data; still try to refocus
					call_deferred("_refocus_last_activated_key")
