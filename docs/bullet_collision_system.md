# Bullet Collision Detection System

## Overview
The collision detection system allows bullets to automatically detect hits on targets even when the bullet doesn't physically move through space. This is achieved using Godot's Area2D collision detection.

## Supported Targets
All targets now support collision detection:
- **ipsc_mini**: A-Zone (5 pts), C-Zone (3 pts), D-Zone (1 pt)
- **ipsc_white**: D-Zone (1 pt)
- **popper**: HeadArea (5 pts), NeckArea (3 pts), BodyArea (2 pts), StandArea (0 pts)
- **paddle**: CircleArea (5 pts), StandArea (0 pts)

## How It Works

### Bullet Setup
- **Bullet is now Area2D**: Changed from Node2D to Area2D to enable collision detection
- **Collision Layer 8**: Bullets are on collision layer 8
- **Collision Mask 7**: Bullets detect objects on layer 7 (targets)
- **Small Collision Shape**: Uses a CapsuleShape2D with radius 5.0 and height 15.0

### Target Setup (All Targets)
- **Target is Area2D**: All targets extend Area2D for collision detection
- **Collision Layer 7**: All targets are on collision layer 7
- **Collision Mask 0**: Targets don't need to detect anything (bullets detect targets)
- **Zone Detection**: Each target uses appropriate collision shapes:
  - **ipsc_mini/ipsc_white**: CollisionPolygon2D for scoring zones
  - **popper**: Mixed CollisionShape2D (circles) and CollisionPolygon2D
  - **paddle**: CollisionShape2D (circle) and CollisionPolygon2D

## Collision Flow

1. **Mouse Click**: User clicks on screen
2. **Bullet Spawn**: Bullet Area2D is instantiated at click position
3. **Collision Detection**: If bullet overlaps with target, `area_entered` signal fires
4. **Zone Calculation**: Target calculates which zone was hit:
   - **ipsc_mini/ipsc_white**: Uses `Geometry2D.is_point_in_polygon()` for polygon zones
   - **popper**: Checks circle distance and polygon containment for different body parts
   - **paddle**: Checks circle distance for main target and polygon for stand
5. **Scoring**: Points are awarded based on zone hit and target type
6. **Animation**: Appropriate animations triggered (fall for popper/paddle, shader effects)
6. **Signal Emission**: `target_hit` signal is emitted with zone and points
7. **Effects**: Bullet impact effects (smoke, sound, visual) are triggered

## Key Features

### Automatic Collision Detection
- No need for manual hit detection - collision system handles it automatically
- Works even with stationary bullets (instant hit system)
- Accurate zone detection using polygon math

### Scoring System
```gdscript
# Connect to target hit signal
target.target_hit.connect(_on_target_hit)

func _on_target_hit(zone: String, points: int):
    print("Hit zone: ", zone, " for ", points, " points!")
```

### Score Management
```gdscript
# Get current score from any target
var score = target.get_total_score()

# Reset score on any target
target.reset_score()

# Connect to any target's hit signal
target.target_hit.connect(_on_target_hit)

func _on_target_hit(zone: String, points: int):
    print("Hit zone: ", zone, " for ", points, " points!")
```

### Target-Specific Zones

#### ipsc_mini
- A-Zone: 5 points (highest value center)
- C-Zone: 3 points (middle ring)
- D-Zone: 1 point (outer ring)

#### ipsc_white  
- D-Zone: 1 point (hostage target - low value)

#### popper
- HeadArea: 5 points (triggers fall animation)
- NeckArea: 3 points (triggers fall animation)
- BodyArea: 2 points (triggers fall animation)
- StandArea: 0 points (hit stand, no fall)

#### paddle
- CircleArea: 5 points (main target, triggers fall animation)
- StandArea: 0 points (hit stand/base)

## Benefits

1. **Accurate Detection**: Uses Godot's built-in physics for reliable collision detection
2. **Performance**: Efficient - only checks collisions between bullets and targets
3. **Flexible**: Easy to extend to other target types
4. **Visual Feedback**: Maintains all existing bullet impact effects
5. **Scoring Integration**: Built-in scoring system with signal support

## Usage Example

```gdscript
# In your scene, connect to any target's signal
func _ready():
    # Connect to different target types
    $IPSCMini.target_hit.connect(_on_target_hit)
    $IPSCWhite.target_hit.connect(_on_target_hit)
    $Popper.target_hit.connect(_on_target_hit)
    $Paddle.target_hit.connect(_on_target_hit)

func _on_target_hit(zone: String, points: int):
    print("Target hit in zone: ", zone, " for ", points, " points!")
    update_score_display()
    
    # Handle target-specific logic
    if zone in ["HeadArea", "NeckArea", "BodyArea", "CircleArea"]:
        print("Target will fall!")
```

## Collision Layers Reference

- **Layer 7**: All targets (ipsc_mini, ipsc_white, popper, paddle)
- **Layer 8**: Bullets
- **Layer 1**: Hostage targets (if different from main targets)
- **Layer 2**: Other game objects

The system is designed to be extensible - any new target type can use collision layer 7 to work with the bullet system automatically.
