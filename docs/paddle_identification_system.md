# Paddle Identification System

## Overview
The paddle system has been enhanced to support multiple paddles in a scene with unique identification and individual scoring tracking.

## Key Features

### 1. Paddle Identification
Each paddle now has a unique identifier that can be set and retrieved:
```gdscript
# Set a custom ID for the paddle
paddle.set_paddle_id("Paddle_TopLeft")

# Get the paddle's ID
var id = paddle.get_paddle_id()
```

### 2. Enhanced Signals
The `target_hit` and `target_disappeared` signals now include the paddle ID:
```gdscript
# Old signal
signal target_hit(zone: String, points: int)
signal target_disappeared

# New signal
signal target_hit(paddle_id: String, zone: String, points: int)
signal target_disappeared(paddle_id: String)
```

### 3. Improved Logging
All debug messages now include the paddle ID for easier tracking:
```
PADDLE Paddle_TopLeft: Bullet collision detected at position: (100, 200)
Paddle Paddle_TopRight circle area hit! Starting fall animation...
```

## Usage Example

### In a Scene Script (like 4paddles.gd):
```gdscript
extends Node2D

var paddle_scores = {}

func _ready():
    # Get paddle references
    var paddle1 = $Paddle1
    var paddle2 = $Paddle2
    
    # Set unique IDs
    paddle1.set_paddle_id("Left_Paddle")
    paddle2.set_paddle_id("Right_Paddle")
    
    # Connect signals
    paddle1.target_hit.connect(_on_paddle_hit)
    paddle2.target_hit.connect(_on_paddle_hit)
    
    # Initialize scoring
    paddle_scores["Left_Paddle"] = 0
    paddle_scores["Right_Paddle"] = 0

func _on_paddle_hit(paddle_id: String, zone: String, points: int):
    print("Paddle %s hit in %s for %d points" % [paddle_id, zone, points])
    paddle_scores[paddle_id] += points
```

## Scoring Zones
Each paddle has different scoring zones:
- **CircleArea**: 5 points (triggers fall animation)
- **StandArea**: 0 points (no fall animation)
- **GeneralHit**: 1 point (fallback for other areas)

## Testing
- Use the `4paddles.tscn` scene to test multiple paddles
- Press 'R' to reset all paddles
- Press 'S' to show score summary
- Each paddle will report hits with its unique ID

## Migration from Old System
If you have existing code using the old signals:
1. Update signal connections to include the new paddle_id parameter
2. Set unique IDs for all paddles in your scene
3. Update any scoring logic to track individual paddle performance

## Benefits
- **Individual Tracking**: Each paddle's performance can be monitored separately
- **Better Debugging**: Clear identification of which paddle triggered events
- **Scalable Design**: Easy to add more paddles without conflicts
- **Backward Compatible**: Existing single-paddle scenes continue to work
