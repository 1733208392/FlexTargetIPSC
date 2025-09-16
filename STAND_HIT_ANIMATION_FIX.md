# STAND HIT ANIMATION FIX

## Problem
Hitting the popper stand area only triggered shader effects (`test_shader_effects()`), not the falling animation. The user wanted stand hits to also trigger the normal falling animation.

## Changes Made

### 1. WebSocket Fast Path (Lines ~457 & ~487)
**Before:**
```gdscript
should_fall = false  // Stand hits don't fall
print("[popper %s] FAST: Stand hit - 0 points (no fall)" % popper_id)

elif zone_hit == "StandArea":
    print("[popper %s] FAST: Stand hit - testing shader effects only" % popper_id)
    test_shader_effects()
```

**After:**  
```gdscript
should_fall = true   // Stand hits now fall like other hits
print("[popper %s] FAST: Stand hit - 0 points (will fall)" % popper_id)

// Special case removed - stand hits now use normal fall animation
```

### 2. Mouse Click Handling (Line ~170)
**Before:**
```gdscript
print("Popper stand hit!")
test_shader_effects()
```

**After:**
```gdscript  
print("Popper stand hit! Starting fall animation...")
trigger_fall_animation()
```

### 3. Collision Detection (Line ~350)
**Before:**
```gdscript
print("COLLISION: Popper stand hit by bullet - 0 points!")
test_shader_effects()
```

**After:**
```gdscript
print("COLLISION: Popper stand hit by bullet - 0 points!")  
trigger_fall_animation()
```

### 4. Signal Emission Logic
**Fixed** all three paths to emit `target_hit` signals for stand hits (0 points) by removing the `points > 0` requirement:

- **Collision Detection**: `if zone_hit != "miss"` (was `zone_hit != "miss" and points > 0`)
- **Mouse Clicks**: `if zone_hit != "" and zone_hit != "unknown"` (was `+ and points > 0`)
- **WebSocket**: Already correct (uses `if is_target_hit`)

## Result
- ✅ **Stand hits now trigger falling animation** (same as head/neck/body hits)
- ✅ **Stand hits still score 0 points** (unchanged scoring)
- ✅ **Stand hits emit target_hit signals** (for performance tracking)
- ✅ **All hit detection paths consistent** (WebSocket, mouse, collision)
- ✅ **Debug functionality preserved** (T key still tests shader effects)

## Behavior Now
**Any hit to any part of the popper** (head, neck, body, OR stand) will:
1. Trigger the falling animation
2. Emit appropriate target_hit signal  
3. Score points based on zone (head=5, neck=3, body=2, stand=0)
4. Make the popper disappear when animation completes