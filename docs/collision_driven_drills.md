# Collision-Driven Drills System

## Overview
The drills system has been updated to use the new bullet collision detection mechanism instead of manual hit detection. The drill progresses through different target types only when exactly 2 bullet collisions are detected on each target.

## How It Works

### Drill Progression
1. **Initial Target**: ipsc_mini (standard IPSC target)
2. **After 2 hits**: Hostage scenario (ipsc_mini + ipsc_white)
3. **After 2 hits**: Popper target (falling metal target)
4. **After 2 hits**: Paddle target (reactive steel paddle)
5. **After 2 hits**: ipsc_mini_rotate (rotating IPSC target)
6. **Drill Complete**: Show final results

### Collision Detection
- Each target type now automatically detects bullet collisions
- Scoring is tracked per target and accumulated for total drill score
- Progress only happens when exactly `max_shots` (2) collisions are detected

### Supported Target Types

#### Simple Targets
- **ipsc_mini**: Direct collision detection with A/C/D zones
- **popper**: Collision detection for Head/Neck/Body/Stand areas
- **paddle**: Collision detection for Circle/Stand areas

#### Composite Targets  
- **hostage**: Contains both ipsc_mini and ipsc_white as children
- **ipsc_mini_rotate**: Contains rotating ipsc_mini as child

## Key Features

### Automatic Hit Detection
```gdscript
# No more manual hit radius checking!
# Collision system handles all hit detection automatically
func _on_target_hit(zone: String, points: int):
    total_drill_score += points
    handle_shot()
```

### Progressive Difficulty
- **ipsc_mini**: Standard precision shooting (5/3/1 points)
- **hostage**: Precision + target identification (avoid white target)
- **popper**: Reactive target with fall animation
- **paddle**: Steel target with physics response
- **ipsc_mini_rotate**: Moving target challenge

### Score Tracking
```gdscript
# Total score across all targets
var total_drill_score: int = 0

# Progress tracking
var targets_completed: int = 0
var total_targets: int = 5
```

### Signal Connections
The system automatically connects to appropriate targets:
```gdscript
# For simple targets
target.target_hit.connect(_on_target_hit)

# For composite targets (hostage)
ipsc_mini.target_hit.connect(_on_target_hit)
ipsc_white.target_hit.connect(_on_target_hit)

# For contained targets (ipsc_mini_rotate)
child_target.target_hit.connect(_on_target_hit)
```

## Usage

### Running the Drill
1. Load the drills scene
2. Click anywhere to spawn bullets
3. Hit targets to progress through the drill
4. Each target requires exactly 2 hits to advance
5. Complete all 5 targets to finish the drill

### Restarting the Drill
```gdscript
# Call this function to restart from the beginning
restart_drill()
```

### Monitoring Progress
```gdscript
# Check current progress
print("Score: ", total_drill_score)
print("Progress: ", targets_completed, "/", total_targets)
print("Current target: ", current_target_type)
print("Shots on current: ", shot_count, "/", max_shots)
```

## Benefits

1. **Accurate Detection**: Uses physics-based collision instead of radius approximation
2. **Automatic Scoring**: Each target type contributes appropriate points
3. **Flexible Progression**: Easy to modify shot requirements or target order
4. **Composite Target Support**: Handles targets with multiple child elements
5. **Complete Tracking**: Full drill statistics and progress monitoring

## Customization

### Changing Shot Requirements
```gdscript
# Modify shots needed per target
var max_shots: int = 3  # Change from 2 to 3 shots per target
```

### Adding New Targets
```gdscript
# Add new target to progression
elif current_target_type == "paddle":
    replace_paddle_with_new_target()
```

### Custom Scoring
```gdscript
# Modify scoring in _on_target_hit
func _on_target_hit(zone: String, points: int):
    var bonus_multiplier = get_target_difficulty_multiplier()
    total_drill_score += points * bonus_multiplier
```

The collision-driven drill system provides a robust, accurate, and extensible training platform for IPSC shooting practice!
