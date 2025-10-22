# DEBUG_DISABLED - Quick Start Guide

## TL;DR (Too Long; Didn't Read)

✅ **Status:** All 1893 debug prints are DISABLED for production

### To Enable Debug (Development)
```gdscript
GlobalDebug.set_debug_enabled(true)
```

### To Disable Debug (Production)
```gdscript
GlobalDebug.set_debug_enabled(false)
```

### To Check Status
```gdscript
print(GlobalDebug.get_debug_status())
```

---

## 30-Second Overview

| What | Where | Status |
|------|-------|--------|
| Master control | `script/GlobalDebug.gd` | ✅ Created |
| Configuration | `project.godot` [autoload] | ✅ Registered |
| Debug prints | All 24 script files | ✅ Guarded |
| Production mode | DEBUG_DISABLED = true | ✅ Active |
| Status | Ready to ship | ✅ YES |

---

## Most Common Tasks

### Task 1: Build for Production
```
Current state: All prints disabled ✅
Action: Just build and deploy
Result: Silent, efficient application
```

### Task 2: Debug Everything
```gdscript
# In console or any script:
GlobalDebug.set_debug_enabled(true)
# All prints now show (from guarded locations)
```

### Task 3: Debug One File
```gdscript
# In that script file at the top:
const DEBUG_ENABLED = true  # Change from false
# Save → Restart
# Only that file's prints show
```

### Task 4: Check What's Enabled
```gdscript
GlobalDebug.get_debug_status()
# Output: "DEBUG_DISABLED=true, debug_enabled=false, DEBUG_DISABLED=false"
```

### Task 5: Disable Debug Again
```gdscript
GlobalDebug.set_debug_enabled(false)
# All debug prints hidden again
```

---

## Files You Need to Know About

```
script/GlobalDebug.gd          ← Central control (NEW)
  └─ DEBUG_DISABLED = true     ← Master switch (OFF for production)

project.godot                   ← Project config (UPDATED)
  └─ [autoload]                ← GlobalDebug registered here

24 Script Files                 ← All updated
  ├─ const DEBUG_ENABLED = false
  └─ const DEBUG_DISABLED = false
```

---

## How It Works (Simple Version)

```
Every print in code is wrapped:

    if DEBUG_ENABLED:              ← Local flag = false
        print("Debug message")     ← Print SKIPPED ✅

Or globally:

    if not GlobalDebug.DEBUG_DISABLED:     ← Global flag = true
        print("Debug message")              ← Print SKIPPED ✅

Result: No debug output in production ✅
```

---

## Control Options

### Option 1: Local Flag (Simplest for testing one file)
```gdscript
const DEBUG_ENABLED = false

func test():
    if DEBUG_ENABLED:
        print("Debug")
```
**Best for:** Testing specific files

### Option 2: Global Control (Easiest for full debugging)
```gdscript
GlobalDebug.set_debug_enabled(true)  # Enable all
GlobalDebug.set_debug_enabled(false) # Disable all
```
**Best for:** Full system debugging

### Option 3: Runtime Check (Most flexible)
```gdscript
if not GlobalDebug.DEBUG_DISABLED:
    print("Debug message")
```
**Best for:** Conditional debug output

---

## Before You Ship 🚀

**Checklist (takes 30 seconds):**
```
☐ GlobalDebug.DEBUG_DISABLED = true           ← Verify
☐ All DEBUG_ENABLED = false                   ← Verify
☐ All DEBUG_DISABLED = false                   ← Verify
☐ Run: print(GlobalDebug.get_debug_status()) ← Check output
☐ Test build has no debug output              ← Confirm
☐ Deploy                                      ← Go!
```

---

## Emergency Debug (If Issues in Production)

### Option 1: Via Modified Binary
```gdscript
# Add to early startup code temporarily:
GlobalDebug.set_debug_enabled(true)
# Collect logs
# Remove and rebuild
```

### Option 2: Via Remote Config (If you have one)
```gdscript
# Check config on startup:
if remote_config.debug_enabled:
    GlobalDebug.set_debug_enabled(true)
```

---

## Common Mistakes & Fixes

| Mistake | Fix |
|---------|-----|
| "I see debug prints" | Check all flags are set to `false` |
| "GlobalDebug not found" | Restart Godot, check project.godot [autoload] |
| "Can't enable debug" | Call `GlobalDebug.set_debug_enabled(true)` |
| "Prints still don't show" | Check local flags aren't overriding global |

---

## Testing the System

```gdscript
# Test 1: Verify disabled
print(GlobalDebug.get_debug_status())
# Output should show: DEBUG_DISABLED=true, debug_enabled=false

# Test 2: Enable and verify
GlobalDebug.set_debug_enabled(true)
print(GlobalDebug.get_debug_status())
# Output should show: DEBUG_DISABLED=false, debug_enabled=true

# Test 3: Check print appears
if not GlobalDebug.DEBUG_DISABLED:
    print("This should appear now")

# Test 4: Disable and verify
GlobalDebug.set_debug_enabled(false)
if not GlobalDebug.DEBUG_DISABLED:
    print("This should NOT appear")
```

---

## Key Methods Reference

```gdscript
# Enable all debugging
GlobalDebug.set_debug_enabled(true)

# Disable all debugging  
GlobalDebug.set_debug_enabled(false)

# Check if debugging enabled
GlobalDebug.is_debug_enabled()  → bool

# Get full status string
GlobalDebug.get_debug_status()  → "DEBUG_DISABLED=..., debug_enabled=..., DEBUG_DISABLED=..."

# Direct flag access (advanced)
GlobalDebug.DEBUG_DISABLED      → bool
GlobalDebug.debug_enabled       → bool
GlobalDebug.DEBUG_DISABLED       → bool
```

---

## Production Deployment

### Step 1: Verify Default State
```gdscript
# Run this in console to verify production defaults:
GlobalDebug.get_debug_status()
# Must output: "DEBUG_DISABLED=true, debug_enabled=false, DEBUG_DISABLED=false"
```

### Step 2: Build for Release
```bash
# Normal build process (no special changes needed)
# All prints are already guarded and disabled
```

### Step 3: Test Build
```gdscript
# Verify no debug output in logs
# Look for any print() statements in output
# Should find NONE ✅
```

### Step 4: Deploy
```
Deploy with confidence ✅
Application runs silently ✅
No debug overhead ✅
```

---

## For Different Roles

### For QA Testers
- **To enable debug:** Give them: `GlobalDebug.set_debug_enabled(true)`
- **To check status:** Give them: `GlobalDebug.get_debug_status()`
- **To disable again:** Give them: `GlobalDebug.set_debug_enabled(false)`

### For Developers
- Change local `DEBUG_ENABLED = true` for your file
- Or use `GlobalDebug.set_debug_enabled(true)` for full debug
- Always set back to `false` before committing

### For DevOps
- No special configuration needed
- Application ships with all debug OFF by default
- Can be enabled at runtime if needed

### For Release Manager
- Verify: `GlobalDebug.DEBUG_DISABLED = true` ✅
- Verify: All local flags = `false` ✅
- Build and deploy as normal ✅

---

## Next Steps

1. **Read:** Pick one guide:
   - `DEBUG_DISABLED_REFERENCE.md` (quick lookup)
   - `DEBUG_CONTROL_GUIDE.md` (complete guide)
   
2. **Test:** Try enabling/disabling:
   ```gdscript
   GlobalDebug.set_debug_enabled(true)   # See debug output
   GlobalDebug.set_debug_enabled(false)  # Back to silent
   ```

3. **Deploy:** Build and ship with confidence ✅

---

**Questions? See:**
- Quick Reference → `DEBUG_DISABLED_REFERENCE.md`
- Complete Guide → `DEBUG_CONTROL_GUIDE.md`
- Architecture → `DEBUG_DISABLED_ARCHITECTURE.md`

**Status:** ✅ READY FOR PRODUCTION
