extends Control

const Cell = preload("res://scene/games/tictactoe/cell.tscn")

@export_enum("Human", "AI") var play_with : String = "AI"
@export_enum("Easy", "Medium", "Hard", "Impossible") var ai_difficulty : String = "Hard"

var cells : Array = []
var turn : int = 0

var is_game_end : bool = false

# Difficulty buttons for remote focus navigation
@onready var btn_easy = $HBoxContainerDifficultLevel/Easy
@onready var btn_medium = $HBoxContainerDifficultLevel/Medium
@onready var btn_hard = $HBoxContainerDifficultLevel/Hard
@onready var btn_impossible = $HBoxContainerDifficultLevel/Impossible
var _difficulty_buttons: Array = []
var _focus_index: int = 0  # 0 = Easy, 1 = Medium, 2 = Hard, 3 = Impossible
const _difficulty_label_keys: Array = ["Easy", "Medium", "Hard", "Impossible"]

func _ready():
	for cell_count in range(9):
		var cell = Cell.instantiate()
		cell.main = self
		$Cells.add_child(cell)
		cells.append(cell)
		cell.cell_updated.connect(_on_cell_updated)

	# Connect to WebSocket bullet hits if available so physical shots can update the board
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if ws_listener.has_signal("bullet_hit"):
			ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
			print("[TicTacToe] Connected to WebSocketListener bullet_hit")
		else:
			print("[TicTacToe] WebSocketListener found but no bullet_hit signal")
	else:
		print("[TicTacToe] No WebSocketListener singleton found - live shots disabled")

	# Prepare difficulty button array and default focus (Easy)
	_difficulty_buttons = [btn_easy, btn_medium, btn_hard, btn_impossible]
	_focus_index = 0
	# Load persisted difficulty (if any). If HttpService is present this is async
	# and the load callback will call _apply_focus; otherwise the sync fallback
	# will call _apply_focus immediately.
	_load_difficulty_setting()
	_translate_difficulty_buttons()
	_translate_restart_button()

	# Connect to MenuController navigate for remote left/right directives
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller:
		menu_controller.navigate.connect(_on_menu_navigate)
		if menu_controller.has_signal("enter_pressed"):
			menu_controller.enter_pressed.connect(Callable(self, "_on_menu_enter"))
		if menu_controller.has_signal("back_pressed"):
			menu_controller.back_pressed.connect(Callable(self, "_on_menu_back_pressed"))
		if menu_controller.has_signal("homepage_pressed"):
			menu_controller.homepage_pressed.connect(Callable(self, "_on_menu_back_pressed"))
		print("[TicTacToe] Connected to MenuController.navigate for remote directives")

	# Connect difficulty buttons to change AI difficulty when pressed
	for i in range(_difficulty_buttons.size()):
		var b = _difficulty_buttons[i]
		if is_instance_valid(b) and b.has_signal("pressed"):
			b.pressed.connect(Callable(self, "_on_difficulty_button_pressed_focus").bind(i))

func _on_cell_updated(_cell):
	if is_game_end:
		return

	var match_result = check_match()
	print(match_result)

	if match_result:
		is_game_end = true
		start_win_animation(match_result)

	elif play_with == "AI" and turn == 1:
		# AI's turn (plays O). Choose move based on difficulty.
		var idx = choose_ai_move()
		if idx >= 0 and cells[idx].cell_value == "":
			cells[idx].draw_cell()

func _on_websocket_bullet_hit(pos: Vector2) -> void:
	"""Handle incoming bullet hit positions and map them to a tic-tac-toe cell.
	Attempts to match the incoming global/screen `pos` to each cell's global rect
	and triggers the cell update if an empty cell was hit.
	"""
	# Try direct match against each cell's global rect
	# First check if the Restart button was hit (higher priority)
	var restart_btn = get_node_or_null("RestartButton")
	if restart_btn:
		var rrect: Rect2 = Rect2()
		if restart_btn.has_method("get_global_rect"):
			rrect = restart_btn.get_global_rect()
		else:
			var rgp = null
			if restart_btn.has_method("get_global_position"):
				rgp = restart_btn.get_global_position()
			elif "global_position" in restart_btn:
				rgp = restart_btn.global_position
			var rsize = Vector2()
			if "rect_size" in restart_btn:
				rsize = restart_btn.rect_size
			elif "size" in restart_btn:
				rsize = restart_btn.size
			if rgp != null:
				rrect = Rect2(rgp, rsize)
		if rrect.has_point(pos):
			print("[TicTacToe] WebSocket hit matched RestartButton")
			_on_restart_button_pressed()
			return
	for cell in cells:
		if not is_instance_valid(cell):
			continue
		# Prefer Control.get_global_rect() if available (returns a Rect2)
		var rect: Rect2 = Rect2()
		if cell.has_method("get_global_rect"):
			rect = cell.get_global_rect()
		else:
			# Fallback: try common properties used by different Godot versions
			var gp = null
			if cell.has_method("get_global_position"):
				gp = cell.get_global_position()
			elif "global_position" in cell:
				gp = cell.global_position
			elif "rect_global_position" in cell and "rect_size" in cell:
				rect = Rect2(cell.rect_global_position, cell.rect_size)
			# If we have a global position, construct rect from that and size if available
			if gp != null:
				var rect_size_vec = Vector2()
				if "rect_size" in cell:
					rect_size_vec = cell.rect_size
				elif "size" in cell:
					rect_size_vec = cell.size
				rect = Rect2(gp, rect_size_vec)
		if rect.has_point(pos):
			print("[TicTacToe] WebSocket hit matched cell index %d" % cells.find(cell))
			# Only update if the cell is empty
			if cell.cell_value == "":
				cell.draw_cell()
			else:
				print("[TicTacToe] Cell already occupied: %s" % cell.cell_value)
			return

	# If no direct match, log for debugging. Coordinate systems may differ (world vs UI).
	print("[TicTacToe] WebSocket hit did not match any cell rect: %s" % pos)

func _translate_difficulty_buttons() -> void:
	for i in range(_difficulty_buttons.size()):
		var btn = _difficulty_buttons[i]
		if btn and btn is Button and i < _difficulty_label_keys.size():
			btn.text = tr(_difficulty_label_keys[i])

func _translate_restart_button() -> void:
	var restart_btn = get_node_or_null("RestartButton")
	if restart_btn and restart_btn is Button:
		restart_btn.text = tr("restart")

func _apply_focus() -> void:
	# Safely grab focus on the default difficulty button
	if _difficulty_buttons.size() == 0:
		return
	var btn = _difficulty_buttons[_focus_index]
	if is_instance_valid(btn) and btn.has_method("grab_focus"):
		btn.grab_focus()
		print("[TicTacToe] Difficulty focus set to index %d" % _focus_index)

func _on_difficulty_button_pressed_focus(index: int) -> void:
	# Local mouse/touch press should set focus to the button index
	_focus_index = index
	_apply_focus()
	print("[TicTacToe] Difficulty button focused by local press, index= %d" % index)

func _on_menu_enter() -> void:
	# Remote Enter pressed: apply difficulty corresponding to focused button
	var focus_owner = get_viewport().gui_get_focus_owner()
	var index = _focus_index
	for i in range(_difficulty_buttons.size()):
		if is_instance_valid(_difficulty_buttons[i]) and _difficulty_buttons[i] == focus_owner:
			index = i
			break
	# Apply the difficulty and persist
	match index:
		0:
			ai_difficulty = "Easy"
		1:
			ai_difficulty = "Medium"
		2:
			ai_difficulty = "Hard"
		3:
			ai_difficulty = "Impossible"
	print("[TicTacToe] Remote Enter applied difficulty: %s (index %d)" % [ai_difficulty, index])
	# Persist selection
	_save_difficulty_setting()
	# Restart the game so new difficulty takes effect
	_on_restart_button_pressed()

func _difficulty_index_from_string(d: String) -> int:
	match d:
		"Easy":
			return 0
		"Medium":
			return 1
		"Hard":
			return 2
		"Impossible":
			return 3
	return 2

func _save_difficulty_setting() -> void:
	# Prefer using the HttpService autoload to persist into settings.json
	var http = get_node_or_null("/root/HttpService")
	if http and http.has_method("save_game"):
		# Build settings dict; send it to save_game asynchronously
		var settings = {"tictactoe": {"ai_difficulty": ai_difficulty}}
		http.save_game(Callable(self, "_on_http_save_game_result"), "settings", settings)
		return

	# Fallback: save to a local ConfigFile
	var cf = ConfigFile.new()
	cf.load("user://tictactoe.cfg")
	cf.set_value("tictactoe", "ai_difficulty", ai_difficulty)
	var err = cf.save("user://tictactoe.cfg")
	if err != OK:
		print("[TicTacToe] Warning: failed to save difficulty setting to ConfigFile, err= %d" % err)

func _load_difficulty_setting() -> void:
	# Prefer HttpService.load_game to read settings.json
	var http = get_node_or_null("/root/HttpService")
	if http and http.has_method("load_game"):
		http.load_game(Callable(self, "_on_http_load_game_result"), "settings")
		# Async; callback will call _apply_focus when loaded (or on failure)
		return
	
	# Fallback: try local ConfigFile synchronously
	var cf = ConfigFile.new()
	if cf.load("user://tictactoe.cfg") == OK:
		var d = cf.get_value("tictactoe", "ai_difficulty", null)
		if d != null:
			ai_difficulty = str(d)
			_focus_index = _difficulty_index_from_string(ai_difficulty)
			print("[TicTacToe] Loaded persisted difficulty from ConfigFile: %s (focus index %d)" % [ai_difficulty, _focus_index])
		call_deferred("_apply_focus")
		return

func _on_http_load_game_result(result, response_code, _headers, body) -> void:
	# Callback for HttpService.load_game
	if response_code != 200 or result != HTTPRequest.RESULT_SUCCESS:
		print("[TicTacToe] HttpService.load_game failed, code= %s, result= %s" % [str(response_code), str(result)])
		# On failure, ensure default focus is Easy
		_focus_index = 0
		call_deferred("_apply_focus")
		return
	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	if not json:
		print("[TicTacToe] HttpService.load_game: JSON parse failed")
		_focus_index = 0
		call_deferred("_apply_focus")
		return
	if not json.has("data"):
		print("[TicTacToe] HttpService.load_game: no data field")
		_focus_index = 0
		call_deferred("_apply_focus")
		return
	var data = json["data"]
	var parsed = null
	if typeof(data) == TYPE_STRING:
		parsed = JSON.parse_string(data)
		if not parsed:
			parsed = null
	elif typeof(data) == TYPE_DICTIONARY:
		parsed = data
	if parsed and typeof(parsed) == TYPE_DICTIONARY and parsed.has("tictactoe"):
		var t = parsed["tictactoe"]
		if typeof(t) == TYPE_DICTIONARY and t.has("ai_difficulty"):
			ai_difficulty = str(t["ai_difficulty"])
			_focus_index = _difficulty_index_from_string(ai_difficulty)
			print("[TicTacToe] Loaded persisted difficulty from HttpService: %s (focus index %d)" % [ai_difficulty, _focus_index])
			# Now that we have loaded the persisted setting, apply focus to that button
			call_deferred("_apply_focus")
			return
	# No valid persisted difficulty found — default to Easy
	_focus_index = 0
	call_deferred("_apply_focus")

func _on_http_save_game_result(result, response_code, _headers, _body) -> void:
	# Callback for HttpService.save_game
	if response_code != 200 or result != HTTPRequest.RESULT_SUCCESS:
		print("[TicTacToe] HttpService.save_game failed, code= %s, result= %s" % [str(response_code), str(result)])
	else:
		print("[TicTacToe] Difficulty persisted to HttpService settings")

func _on_menu_navigate(direction: String) -> void:
	# Handle left/right navigation to change difficulty focus
	if direction != "left" and direction != "right":
		return
	if _difficulty_buttons.size() == 0:
		return
	# Update focus index
	if direction == "left":
		_focus_index = (_focus_index - 1) % _difficulty_buttons.size()
	else:
		_focus_index = (_focus_index + 1) % _difficulty_buttons.size()
	# Apply focus to the new button
	_apply_focus()
	# Optionally play cursor sound via MenuController
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller and menu_controller.has_method("play_cursor_sound"):
		menu_controller.play_cursor_sound()

func _on_menu_back_pressed() -> void:
	print("[TicTacToe] Remote back/home pressed, returning to menu")
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	# Change to the shared menu scene
	var target = "res://scene/games/menu/menu.tscn"
	if ResourceLoader.exists(target):
		get_tree().change_scene_to_file(target)
	else:
		print("[TicTacToe] Menu scene not found: %s" % target)

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func check_match():
	for h in range(3):
		if cells[0+3*h].cell_value == "X" and cells[1+3*h].cell_value == "X" and cells[2+3*h].cell_value == "X":
			return ["X", 1+3*h, 2+3*h, 3+3*h]
	for v in range(3):
		if cells[0+v].cell_value == "X" and cells[3+v].cell_value == "X" and cells[6+v].cell_value == "X":
			return ["X", 1+v, 4+v, 7+v]
	if cells[0].cell_value == "X" and cells[4].cell_value == "X" and cells[8].cell_value == "X":
		return ["X", 1, 5, 9]
	elif cells[2].cell_value == "X" and cells[4].cell_value == "X" and cells[6].cell_value == "X":
		return ["X", 3, 5, 7]

	for h in range(3):
		if cells[0+3*h].cell_value == "O" and cells[1+3*h].cell_value == "O" and cells[2+3*h].cell_value == "O":
			return ["O", 1+3*h, 2+3*h, 3+3*h]
	for v in range(3):
		if cells[0+v].cell_value == "O" and cells[3+v].cell_value == "O" and cells[6+v].cell_value == "O":
			return ["O", 1+v, 4+v, 7+v]
	if cells[0].cell_value == "O" and cells[4].cell_value == "O" and cells[8].cell_value == "O":
		return ["O", 1, 5, 9]
	elif cells[2].cell_value == "O" and cells[4].cell_value == "O" and cells[6].cell_value == "O":
		return ["O", 3, 5, 7]

	var full = true
	for cell in cells:
		if cell.cell_value == "":
			full = false

	if full: return["Draw", 0, 0, 0]

func start_win_animation(match_result: Array):
	var color: Color

	if match_result[0] == "X":
		color = Color.BLUE
	elif match_result[0] == "O":
		color = Color.RED

	for c in range(3):
		cells[match_result[c+1]-1].glow(color)

# -----------------------
# AI / Difficulty helpers
# -----------------------

func board_array_from_cells() -> Array:
	var b = []
	for c in cells:
		b.append(c.cell_value)
	return b

func available_moves(board: Array) -> Array:
	var moves = []
	for i in range(board.size()):
		if board[i] == "":
			moves.append(i)
	return moves

func check_winner_on_board(board: Array):
	var wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]
	for w in wins:
		var a = board[w[0]]
		if a != "" and a == board[w[1]] and a == board[w[2]]:
			return a
	var full = true
	for v in board:
		if v == "":
			full = false
	if full:
		return "Draw"
	return null

func evaluate_board(board: Array) -> int:
	var winner = check_winner_on_board(board)
	if winner == "O":
		return 10
	elif winner == "X":
		return -10
	return 0

func minimax(board: Array, depth: int, is_maximizing: bool, alpha: int, beta: int) -> int:
	var score = evaluate_board(board)
	if score == 10 or score == -10:
		return score
	if check_winner_on_board(board) == "Draw":
		return 0

	if is_maximizing:
		var best = -1000
		for i in available_moves(board):
			board[i] = "O"
			var val = minimax(board, depth+1, false, alpha, beta)
			board[i] = ""
			best = max(best, val)
			alpha = max(alpha, best)
			if beta <= alpha:
				break
		return best
	else:
		var best = 1000
		for i in available_moves(board):
			board[i] = "X"
			var val = minimax(board, depth+1, true, alpha, beta)
			board[i] = ""
			best = min(best, val)
			beta = min(beta, best)
			if beta <= alpha:
				break
		return best

func find_best_move() -> int:
	var board = board_array_from_cells()
	var best_val = -1000
	var best_move = -1
	for i in available_moves(board):
		board[i] = "O"
		var move_val = minimax(board, 0, false, -1000, 1000)
		board[i] = ""
		if move_val > best_val:
			best_val = move_val
			best_move = i
	return best_move

func choose_ai_move() -> int:
	randomize()
	var board = board_array_from_cells()
	var moves = available_moves(board)
	if moves.size() == 0:
		return -1

	match ai_difficulty:
		"Easy":
			return moves[randi() % moves.size()]
		"Medium":
			# 50% optimal, 50% random
			if randi() % 100 < 50:
				return moves[randi() % moves.size()]
			return find_best_move()
		"Hard":
			# Mostly optimal, small chance to pick a suboptimal move
			if randi() % 100 < 10:
				return moves[randi() % moves.size()]
			return find_best_move()
		"Impossible":
			return find_best_move()
	return find_best_move()
