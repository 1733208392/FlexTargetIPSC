extends Control

@onready var start_button = $VBoxContainer/ipsc
@onready var bootcamp_button = $VBoxContainer/boot_camp
@onready var option_button = $VBoxContainer/option

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	bootcamp_button.pressed.connect(_on_bootcamp_pressed)
	option_button.pressed.connect(_on_option_pressed)

func _on_start_pressed():
	print("Start button pressed - Load main game")
	get_tree().change_scene_to_file("res://scene/intro.tscn")

func _on_bootcamp_pressed():
	# TODO: Load the boot camp/training scene
	print("Boot Camp button pressed - Load training mode")
	get_tree().change_scene_to_file("res://scene/bootcamp.tscn")

func _on_option_pressed():
	# Load the options scene
	get_tree().change_scene_to_file("res://scene/option.tscn")
