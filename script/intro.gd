extends Control

@onready var start_button = $BottomContainer/StartButton
@onready var drill_history_button = $TopBar/DrillHistoryButton
@onready var game_rule_image = $CenterContainer/GameRuleContainer/GameRuleImage

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	drill_history_button.pressed.connect(_on_drill_history_pressed)
	
	# Add some visual polish
	setup_ui_styles()

func setup_ui_styles():
	# Style the start button
	if start_button:
		start_button.add_theme_color_override("font_color", Color.WHITE)
		start_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
		start_button.add_theme_color_override("font_hover_color", Color.CYAN)
	
	# Style the drill history button
	if drill_history_button:
		drill_history_button.add_theme_color_override("font_color", Color.WHITE)
		drill_history_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
		drill_history_button.add_theme_color_override("font_hover_color", Color.CYAN)

func _on_start_pressed():
	# Navigate to main menu or game selection
	print("Start button pressed - Loading Drills")
	get_tree().change_scene_to_file("res://scene/drills.tscn")

func _on_drill_history_pressed():
	# Navigate to drill history scene (to be created)
	print("Drill History button pressed - Loading drill history")
	# TODO: Create drill history scene
	get_tree().change_scene_to_file("res://scene/history.tscn")
