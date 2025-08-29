# Bullet Hole System Documentation

## Overview
The bullet hole system creates realistic visual feedback when targets are hit, with random bullet hole textures that remain attached to targets until they are replaced.

## Features

### 🎯 **Random Bullet Hole Textures**
- 6 different bullet hole textures available (`bullet_hole1.png` through `bullet_hole6.png`)
- Each hit randomly selects one of the 6 textures
- Creates visual variety and realism

### 🎨 **Visual Customization**
- **Random Rotation**: Each bullet hole is randomly rotated (0-360°)
- **Random Scale**: Size varies between 70% and 130% of original
- **Z-Index Management**: Bullet holes render behind target sprites
- **Local Positioning**: Holes positioned precisely at impact location

### 🎮 **Target Integration**
- **Target-Attached**: Bullet holes are children of target nodes
- **Persistent**: Holes remain visible until target is replaced
- **Automatic Cleanup**: Holes disappear when targets are removed
- **All Targets Supported**: Works on ipsc_mini, paddle, popper, and hostage targets

## Technical Implementation

### File Structure
```
scene/bullet_hole.tscn     # Main bullet hole scene
script/bullet_hole.gd     # Bullet hole logic and randomization
asset/bullet_hole1.png    # Texture variant 1
asset/bullet_hole2.png    # Texture variant 2
...                       # Up to bullet_hole6.png
```

### Target Script Integration
Each target script now includes:
```gdscript
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")

func spawn_bullet_hole(local_position: Vector2):
    var bullet_hole = BulletHoleScene.instantiate()
    add_child(bullet_hole)
    bullet_hole.set_hole_position(local_position)
```

### Bullet Hole Properties
- **Node Type**: Sprite2D (for optimal performance)
- **Parent**: Target that was hit
- **Position**: Local coordinates relative to target
- **Lifetime**: Until parent target is removed
- **Rendering**: Behind target sprite (z_index = -1)

## Behavior by Target Type

### 🎯 **IPSC Mini Target**
- Bullet holes spawn on A-Zone, C-Zone, and D-Zone hits
- Holes persist through multiple hits (2-shot progression)
- Visible during entire target lifecycle

### 🔄 **Paddle Target**
- Bullet holes spawn on circle area hits
- Holes remain visible during fall animation
- Disappear when paddle is replaced after falling

### 🎪 **Popper Target**  
- Bullet holes spawn on head, neck, and body hits
- Holes remain visible during fall animation
- Disappear when popper is replaced after falling

### 🎭 **Hostage Target (IPSC White)**
- Bullet holes spawn on both good and bad hits
- Penalty visualization for hitting hostage
- Holes persist through 2-shot progression

## Configuration Options

### In `bullet_hole.gd`:
```gdscript
@export var random_rotation: bool = true
@export var random_scale: bool = true  
@export var scale_range: Vector2 = Vector2(0.7, 1.3)
@export var z_index_offset: int = -1
```

### Customization Possibilities:
- **Disable randomization** for consistent appearance
- **Adjust scale range** for larger/smaller holes
- **Change z-index** for rendering order
- **Add fade effects** for gradual disappearance
- **Include sound effects** for bullet impact

## Visual Benefits

### 🎨 **Realism Enhancement**
- Provides immediate visual feedback for hits
- Creates accumulating damage appearance
- Enhances shooting experience immersion

### 📊 **Training Benefits**
- Shows shot grouping patterns
- Helps identify accuracy trends
- Provides visual hit confirmation

### 🎮 **Game Feel Improvement**
- Satisfying impact visualization
- Persistent progress tracking
- Professional shooting range appearance

## Performance Considerations
- **Lightweight**: Simple Sprite2D nodes with minimal overhead
- **Efficient**: No ongoing animations or complex logic
- **Clean Disposal**: Automatic cleanup with target replacement
- **Memory Safe**: No accumulating objects across drill sessions

## Future Enhancements
- **Bullet hole size by caliber**: Different sizes for different weapons
- **Damage accumulation**: Larger holes from multiple hits in same area
- **Material penetration**: Different hole styles for different target materials
- **Ballistic effects**: Accounting for bullet trajectory and angle
