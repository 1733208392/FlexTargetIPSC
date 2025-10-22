# DEBUG_DISABLED - Quick Reference

## What is DEBUG_DISABLED?

`DEBUG_DISABLED` is the global debug control system for FlexTargetIPSC. It allows you to:
- ✅ Disable ALL debug prints for production releases
- ✅ Enable ALL debug prints for development/debugging
- ✅ Control debugging at runtime without recompiling
- ✅ Use both global and per-file debug flags

## For Product Release ✅

**Status: PRODUCTION MODE (All prints disabled)**

```
GlobalDebug.DEBUG_DISABLED = true  ← This means debugging IS DISABLED (prints OFF)
```

## How to Use

### Check Global Debug Status
```gdscript
# All these work the same:
if GlobalDebug.DEBUG_DISABLED:
    print("Debug message")  # Only prints if DEBUG_DISABLED = true (debugging OFF)

if not GlobalDebug.debug_enabled:
    print("Debug message")  # Only prints if debug_enabled = false

if GlobalDebug.DEBUG_DISABLED:  # Some files use this instead
    print("Debug message")
```

### Enable/Disable at Runtime
```gdscript
# Enable all debug prints
GlobalDebug.set_debug_enabled(true)
print(GlobalDebug.get_debug_status())  # Shows: DEBUG_DISABLED=false, debug_enabled=true, DEBUG_DISABLED=true

# Disable all debug prints
GlobalDebug.set_debug_enabled(false)
print(GlobalDebug.get_debug_status())  # Shows: DEBUG_DISABLED=true, debug_enabled=false, DEBUG_DISABLED=false
```

### Use Local Debug Flags (Per-File)
```gdscript
# At top of script:
const DEBUG_ENABLED = false  # Change to true to enable prints in THIS file only

func _ready():
    if DEBUG_ENABLED:
        print("This only prints if DEBUG_ENABLED = true in THIS file")
```

### Use Global Debug in Scripts
```gdscript
# Most scripts already have local flags, but you can also use:
if not GlobalDebug.DEBUG_DISABLED:
    print("[MyScript] Debug message that respects global setting")
```

## Understanding the Logic

| Setting | Meaning | Prints? |
|---------|---------|---------|
| `DEBUG_DISABLED = true` | Debugging is DISABLED | ❌ NO |
| `DEBUG_DISABLED = false` | Debugging is ENABLED | ✅ YES |
| `debug_enabled = false` | Debug features OFF | ❌ NO |
| `debug_enabled = true` | Debug features ON | ✅ YES |
| `DEBUG_DISABLED = false` | Logging OFF | ❌ NO |
| `DEBUG_DISABLED = true` | Logging ON | ✅ YES |

## Files Using GlobalDebug

**All of these are already configured with DEBUG flags (defaults shown):**

### Scene Scripts
- `scene/option/option.gd` - DEBUG_ENABLED = false
- `scene/power_off_dialog.gd` - DEBUG_ENABLED = false
- `scene/drills_network/drills_network.gd` - DEBUG_ENABLED = false
- `scene/drills_network/drill_network_ui.gd` - DEBUG_DISABLED = false
- `scene/drills_network/drill_network_complete_overlay.gd` - DEBUG_ENABLED = false
- `scene/main_menu/main_menu.gd` - DEBUG_DISABLED = false
- `scene/intro/intro.gd` - DEBUG_DISABLED = false

### Script Files
- `script/drills.gd` - DEBUG_DISABLED = false
- `script/bootcamp.gd` - DEBUG_DISABLED = false
- `script/performance_tracker_network.gd` - DEBUG_DISABLED = false
- `script/ipsc_mini.gd` - DEBUG_DISABLED = false
- `script/2poppers.gd` - DEBUG_DISABLED = false
- Plus 12+ other files

## Common Scenarios

### Scenario 1: Debug a Specific Scene (Development)
```gdscript
# In that scene's script, change:
const DEBUG_ENABLED = false
# To:
const DEBUG_ENABLED = true
# Save and restart - now that scene's prints will show
```

### Scenario 2: Debug Everything at Runtime
```gdscript
# In Godot console or any script during execution:
GlobalDebug.set_debug_enabled(true)
# All prints with debug guards will now show
```

### Scenario 3: Production Build - Ensure Prints are Off
```gdscript
# Verify before building:
GlobalDebug.DEBUG_DISABLED = true  # ✅ Correct
# Check each scene:
const DEBUG_ENABLED = false  # ✅ Correct
const DEBUG_DISABLED = false  # ✅ Correct
```

## Where is GlobalDebug?

- **Location:** `script/GlobalDebug.gd`
- **Type:** Autoload singleton (always available as `GlobalDebug`)
- **Registration:** Added to `project.godot` autoload list
- **Access:** From any script without imports: `GlobalDebug.property_name`

## Production Release Checklist

Before shipping to production:
- [ ] GlobalDebug.DEBUG_DISABLED = true
- [ ] All local DEBUG_ENABLED flags = false  
- [ ] All local DEBUG_DISABLED flags = false
- [ ] No unguarded print() calls in critical paths
- [ ] Run with release build settings
- [ ] Test that no debug output appears in logs

## Troubleshooting

**Q: I don't see GlobalDebug in my script**
A: It's an autoload - just use `GlobalDebug.` directly. Check project.godot has the autoload registered.

**Q: Debug prints still showing in production build**
A: Check all DEBUG_ENABLED and DEBUG_DISABLED flags are set to false, then rebuild.

**Q: How do I check current debug status?**
A: Use `print(GlobalDebug.get_debug_status())` - shows all flags

**Q: Which flag should I use in my script?**
A: Look at similar scripts - most use `DEBUG_ENABLED` or `DEBUG_DISABLED` locally

---

**For more details, see:** `DEBUG_CONTROL_GUIDE.md`
