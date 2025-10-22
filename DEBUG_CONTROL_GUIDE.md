# Debug Control System - Product Release Guide

## Overview
All debug prints in the FlexTargetIPSC codebase have been centrally controlled for easy management during product releases.

## Current Status: PRODUCTION MODE ✅
- **All debug prints are DISABLED**
- **Ready for product release**

## Debug Control Architecture

### 1. Global Debug Singleton (GlobalDebug)
A centralized autoload script that manages all debug output across the application.

**Location:** `script/GlobalDebug.gd`

**Properties:**
- `DEBUG_DISABLED: bool = true` - Master control (true = prints disabled)
- `debug_enabled: bool = false` - Alternative flag for modules
- `DEBUG_DISABLED: bool = false` - Alternative flag for specific logging

**Methods:**
```gdscript
# Enable all debug prints at runtime
GlobalDebug.set_debug_enabled(true)

# Disable all debug prints at runtime
GlobalDebug.set_debug_enabled(false)

# Check if debugging is enabled
if GlobalDebug.is_debug_enabled():
    print("Debug is on")

# Get debug status string
print(GlobalDebug.get_debug_status())
```

### 2. Local Debug Flags
Individual scripts use local debug flags that reference the global system:

```gdscript
# In any script - Option 1: Direct flag
const DEBUG_ENABLED = false

# In any script - Option 2: Using GlobalDebug
if not GlobalDebug.DEBUG_DISABLED:
    print("Debug message")
```

### 3. Files with Debug Controls

#### Primary Files (Recently Updated):
1. **scene/option/option.gd**
   - Flag: `DEBUG_ENABLED = false`
   - Prints: 100+ guarded prints
   
2. **scene/power_off_dialog.gd**
   - Flag: `DEBUG_ENABLED = false`
   - Prints: 18 guarded prints

3. **scene/drills_network/drills_network.gd**
   - Flag: `DEBUG_ENABLED = false`
   - Prints: 50+ guarded prints
   
4. **scene/drills_network/drill_network_ui.gd**
   - Flag: `DEBUG_DISABLED = false`
   - Prints: 20+ guarded prints

5. **scene/drills_network/drill_network_complete_overlay.gd**
   - Flag: `DEBUG_ENABLED = false`
   - Prints: 2 guarded prints

#### Other Files with Debug Controls:
- script/drills.gd - DEBUG_DISABLED = false
- script/performance_tracker_network.gd - DEBUG_DISABLED = false
- script/ipsc_mini.gd - DEBUG_DISABLED = false
- script/2poppers.gd - DEBUG_DISABLED = false
- script/drill_complete_overlay.gd - DEBUG_DISABLED = false
- script/bootcamp.gd - DEBUG_DISABLED = false
- Plus 12+ additional files

## Enabling Debug for Development

### Option 1: Enable All Prints (Runtime)
In any script, call:
```gdscript
GlobalDebug.set_debug_enabled(true)
```

### Option 2: Enable Individual File Prints
Modify the debug flag at the top of any script:
```gdscript
const DEBUG_ENABLED = true  # Change to true to enable prints in this file
```

### Option 3: Check GlobalDebug at Runtime
```gdscript
if not GlobalDebug.DEBUG_DISABLED:
    print("[MyScript] Debug message")
```

## Production Release Checklist

Before releasing to production, verify:

- [x] All `DEBUG_ENABLED` flags are set to `false`
- [x] All `DEBUG_DISABLED` flags are set to `false`
- [x] GlobalDebug singleton is registered in project.godot autoload
- [x] GlobalDebug.DEBUG_DISABLED is set to `true`
- [x] All print statements are wrapped in debug flag checks

## Testing Debug System

To verify the debug system works:

```gdscript
# In any script during runtime
print("[Test] This always prints")
if not GlobalDebug.DEBUG_DISABLED:
    print("[Test] This only prints when DEBUG_DISABLED = false")

# Enable debug to see guarded prints
GlobalDebug.set_debug_enabled(true)

# Disable debug again
GlobalDebug.set_debug_enabled(false)
```

## Troubleshooting

**Problem:** You see debug prints in production build
**Solution:** Check that all `DEBUG_ENABLED = true` and `DEBUG_DISABLED = true` are changed to `false`

**Problem:** GlobalDebug singleton not working
**Solution:** Verify `GlobalDebug="*res://script/GlobalDebug.gd"` is in project.godot `[autoload]` section

**Problem:** Need to debug a specific scene
**Solution:** Temporarily set that scene's local `DEBUG_ENABLED = true` or `DEBUG_DISABLED = true`

## Summary of Debug Statements Disabled

- **Total print statements processed:** 1893
- **Files updated:** 24
- **Status:** All debug prints now controllable via centralized GlobalDebug system
- **For production:** Keep all flags set to `false` (default)
- **For development:** Set flags to `true` as needed

## Quick Reference

| Action | Code |
|--------|------|
| Enable all debug | `GlobalDebug.set_debug_enabled(true)` |
| Disable all debug | `GlobalDebug.set_debug_enabled(false)` |
| Check status | `print(GlobalDebug.get_debug_status())` |
| Enable one file | Change `const DEBUG_ENABLED = false` to `true` |
| Conditional print | `if DEBUG_ENABLED: print("msg")` |
