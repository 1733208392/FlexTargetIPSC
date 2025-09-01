# Paddle Position Animation Fix

## Problem
When the fall_down animation was triggered on Paddle2 (or any paddle not positioned at origin), the paddle would visually "jump" to the center (0,0) before starting the fall animation. This happened because:

1. The animation track for position was hardcoded to animate from `Vector2(0, 0)` to `Vector2(0, 120)`
2. This forced all paddles to start their animation from (0,0) regardless of their actual position in the scene
3. Paddle2 in test_paddle.tscn is positioned at (-203, 221), but the animation would move it to (0,0) first

## Root Cause
In the paddle.tscn animation:
```gdscript
tracks/2/path = NodePath(".:position")
tracks/2/keys = {
    "values": [Vector2(0, 0), Vector2(0, 120)]  // Hardcoded start position
}
```

This assumes all paddles start at (0,0), which is only true for the first paddle.

## Solution
Modified the paddle.gd script to:

1. **Store Initial Position**:
   ```gdscript
   var initial_position: Vector2
   
   func _ready():
       initial_position = position  // Store where paddle actually is
   ```

2. **Create Relative Animation**:
   ```gdscript
   func create_relative_animation():
       // Duplicate the original animation
       var new_animation = original_animation.duplicate()
       
       // Update position track to start from initial_position
       var start_pos = initial_position
       var end_pos = initial_position + fall_offset  // Add (0, 120) to current position
       
       new_animation.track_set_key_value(position_track, 0, start_pos)
       new_animation.track_set_key_value(position_track, 1, end_pos)
   ```

3. **Fix Reset Function**:
   ```gdscript
   func reset_paddle():
       position = initial_position  // Reset to original position, not (0,0)
   ```

## How It Works
- Each paddle stores its starting position when `_ready()` is called
- A unique animation is created that starts from the actual position
- The fall offset (0, 120) is added to the initial position to calculate the end position
- Reset restores the paddle to its original position

## Example
- Paddle1 at (0, 1): Falls from (0, 1) to (0, 121)
- Paddle2 at (-203, 221): Falls from (-203, 221) to (-203, 341)
- Each paddle falls from where it's positioned, not from (0,0)

## Testing
1. Run test_paddle.tscn with two paddles at different positions
2. Click on Paddle2 (positioned at -203, 221)
3. Paddle2 should fall straight down from its position, not jump to center first
4. Press 'R' to reset - paddles return to their original positions

## Benefits
- No more visual "jumping" to center before animation
- Each paddle animates from its actual scene position
- Maintains proper relative positioning in multi-paddle layouts
- Proper reset behavior restores original positions
