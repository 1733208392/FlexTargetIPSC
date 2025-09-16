# MISS DETECTION IMPLEMENTATION

## Overview
Added miss detection to the 2poppers scene to record when bullets miss both poppers, including sound and impact effects for misses.

## How It Works

### 1. WebSocket Connection
The 2poppers script now connects to the WebSocket `bullet_hit` signal to monitor all incoming bullets.

### 2. Bullet Tracking
- Each incoming bullet gets a unique ID based on position and timestamp
- Bullets are tracked in a `pending_bullets` dictionary
- A 50ms timer is set for each bullet to check if it was processed

### 3. Hit Processing
When a popper reports a hit:
- Any pending bullets near that hit position (within 50 pixels) are marked as "processed"
- This prevents them from being counted as misses

### 4. Miss Detection
After 50ms delay:
- If a bullet is still marked as "not processed", it's considered a miss
- The miss is recorded in performance tracking with 0 points
- Miss effects are played (sound + impact, no bullet hole)

### 5. Miss Effects
**Sound**: Steel impact sound at lower volume (-8db) and pitch (0.8-0.9x) for differentiation
**Impact**: Visual impact effect at the miss location
**No Bullet Hole**: Poppers are steel targets, so no bullet holes for misses

## Performance Tracking
Misses are now recorded with:
- `hit_area`: "Miss"
- `score`: 0 points
- `target_type`: "2poppers"
- `hit_position`: The actual bullet position

## Files Modified
1. `script/2poppers.gd` - Added miss detection logic
2. `script/drills.gd` - Added handling for miss signals

## Configuration
- **Miss check delay**: 50ms (configurable via `miss_check_delay`)
- **Position tolerance**: 50 pixels (for matching bullets to hits)
- **Miss sound volume**: -8db (quieter than hits)
- **Miss sound pitch**: 0.8-0.9x (lower than hits)

## Benefits
- Accurate performance tracking includes both hits and misses
- Provides audio/visual feedback for all shots
- Maintains the 1:1 ratio between WebSocket bullets and performance records