# PERFORMANCE TRACKING BUG FIX

## Problem
The performance tracker was recording more shots than were actually sent via WebSocket because:

1. **Multiple poppers processing same bullet**: In the 2poppers scene, both poppers were connected to the WebSocket `bullet_hit` signal
2. **Emitting signals for misses**: Poppers were emitting `target_hit` signals even when bullets missed them
3. **Duplicate performance records**: Each popper that processed a bullet (hit or miss) created a performance record

## Example Issue
- Sent 4 WebSocket bullets 
- Got 9 performance records
- Some bullets were processed by multiple poppers simultaneously

## Root Cause
In `script/popper.gd`, three functions were emitting `target_hit` signals even for misses:
1. `handle_websocket_bullet_hit_fast()` - line 476
2. `handle_bullet_collision()` - line 358  
3. `_on_input_event()` - line 198

## Solution
Modified all three functions to only emit `target_hit` signals for actual hits:

### 1. WebSocket Fast Path (line 476)
**Before:**
```gdscript
# Always emitted regardless of hit/miss
target_hit.emit(zone_hit, points, world_pos)
```

**After:**
```gdscript
# Only emit for actual hits
if is_target_hit:
    total_score += points
    target_hit.emit(zone_hit, points, world_pos)
    print("[popper %s] FAST: Target hit! Total score: %d" % [popper_id, total_score])
else:
    print("[popper %s] FAST: Bullet missed - no target_hit signal emitted" % popper_id)
```

### 2. Collision Detection (line 358)
**Before:**
```gdscript
# Always emitted even for misses
total_score += points
target_hit.emit(zone_hit, points, bullet_position)
```

**After:**
```gdscript
# Only emit for actual hits
if zone_hit != "miss" and points > 0:
    total_score += points
    target_hit.emit(zone_hit, points, bullet_position)
    print("COLLISION: Target hit! Total score: ", total_score)
else:
    print("COLLISION: Bullet missed - no target_hit signal emitted")
```

### 3. Mouse Click (line 198)
**Before:**
```gdscript
if zone_hit != "":
    # Could emit for unknown/invalid hits
```

**After:**
```gdscript
if zone_hit != "" and zone_hit != "unknown" and points > 0:
    total_score += points
    target_hit.emit(zone_hit, points, event.position)
    print("Mouse click target_hit emitted: ", zone_hit, " for ", points, " points at ", event.position)
else:
    print("Mouse click missed - no target_hit signal emitted")
```

## Result
Now the performance tracker will only record actual target hits, not misses or duplicate processing of the same bullet by multiple poppers.