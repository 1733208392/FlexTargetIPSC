extends Control

# Shot timer states
enum TimerState {
	WAITING,    # Waiting for user to start
	STANDBY,    # Showing "STANDBY" text
	READY       # After beep, ready to shoot
}

# Node references
@onready var standby_label = $CenterContainer/StandbyLabel
@onready var audio_player = $AudioStreamPlayer
@onready var animation_player = $AnimationPlayer
@onready var timer_delay = $TimerDelay
@onready var instructions = $Instructions

# Timer configuration
@export var min_delay: float = 2.0  # Minimum delay before beep (seconds)
@export var max_delay: float = 5.0  # Maximum delay before beep (seconds)

# State tracking
var current_state: TimerState = TimerState.WAITING
var start_time: float = 0.0
var beep_time: float = 0.0

func _ready():
	"""Initialize the shot timer"""
	print("=== SHOT TIMER INITIALIZED ===")
	
	# Connect timer signal
	timer_delay.timeout.connect(_on_timer_timeout)
	
	# Hide instructions (not needed anymore)
	instructions.visible = false
	
	# Start timer automatically
	start_timer_sequence()

func _input(_event):
	"""Handle input events - removed manual controls"""
	# No manual controls needed - timer starts automatically
	pass

func _process(_delta):
	"""Update timer display and check for state changes"""
	match current_state:
		TimerState.STANDBY:
			# Update standby display with pulsing animation
			pass
		TimerState.READY:
			# Calculate reaction time since beep
			var _reaction_time = Time.get_unix_time_from_system() - beep_time
			# You could display this or send it to a parent scene
			pass

func start_timer_sequence():
	"""Start the shot timer sequence"""
	print("=== STARTING SHOT TIMER SEQUENCE ===")
	
	# Hide instructions (not needed)
	instructions.visible = false
	
	# Set state to standby
	current_state = TimerState.STANDBY
	
	# Show STANDBY text
	standby_label.text = "STANDBY"
	standby_label.label_settings.font_color = Color.YELLOW
	standby_label.visible = true
	
	# Start pulsing animation
	animation_player.play("standby_pulse")
	
	# Set random delay between min_delay and max_delay
	var random_delay = randf_range(min_delay, max_delay)
	timer_delay.wait_time = random_delay
	timer_delay.start()
	
	print("Random delay set to: ", random_delay, " seconds")
	
	# Record start time
	start_time = Time.get_unix_time_from_system()

func _on_timer_timeout():
	"""Handle when the random delay timer expires - play beep and show ready"""
	if current_state != TimerState.STANDBY:
		return
	
	print("=== TIMER BEEP - READY TO SHOOT ===")
	
	# Record beep time
	beep_time = Time.get_unix_time_from_system()
	
	# Play the shot timer beep
	audio_player.play()
	
	# Change to ready state
	current_state = TimerState.READY
	
	# Update visual feedback
	standby_label.text = "SHOOT!"
	standby_label.label_settings.font_color = Color.GREEN
	
	# Stop pulsing animation and start flash animation
	animation_player.stop()
	animation_player.play("ready_flash")
	
	# Emit signal that timer is ready (for parent scenes to use)
	timer_ready.emit()

# Signals
signal timer_ready()
signal timer_reset()

func reset_timer():
	"""Reset the timer to initial state and start automatically"""
	print("=== RESETTING SHOT TIMER ===")
	
	# Stop all timers and animations
	timer_delay.stop()
	animation_player.stop()
	audio_player.stop()
	
	# Reset state
	current_state = TimerState.WAITING
	start_time = 0.0
	beep_time = 0.0
	
	# Reset visual elements
	standby_label.text = "STANDBY"
	standby_label.label_settings.font_color = Color.YELLOW
	standby_label.visible = true
	standby_label.scale = Vector2.ONE
	standby_label.modulate = Color.WHITE
	
	# Hide instructions (not needed anymore)
	instructions.visible = false
	
	# Start timer automatically after reset
	start_timer_sequence()
	
	# Emit reset signal
	timer_reset.emit()

func get_reaction_time() -> float:
	"""Get the current reaction time since beep (only valid in READY state)"""
	if current_state == TimerState.READY and beep_time > 0:
		return Time.get_unix_time_from_system() - beep_time
	return 0.0

func is_timer_ready() -> bool:
	"""Check if the timer is in ready state (after beep)"""
	return current_state == TimerState.READY

func is_timer_waiting() -> bool:
	"""Check if the timer is waiting for user to start"""
	return current_state == TimerState.WAITING

func get_current_state() -> TimerState:
	"""Get the current timer state"""
	return current_state
