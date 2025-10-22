# DEBUG_DISABLED Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    GLOBALDEBUG SINGLETON                        │
│                   (script/GlobalDebug.gd)                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  DEBUG_DISABLED: bool = true  ← Master Control (OFF)      │ │
│  │  debug_enabled: bool = false                              │ │
│  │  DEBUG_DISABLED: bool = false                              │ │
│  │                                                            │ │
│  │  Methods:                                                  │ │
│  │  • set_debug_enabled(bool)                                │ │
│  │  • is_debug_enabled() → bool                              │ │
│  │  • get_debug_status() → String                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  Registered in: project.godot [autoload] section                │
│  Available as: GlobalDebug (autoload singleton)                 │
└─────────────────────────────────────────────────────────────────┘
         ↓
         │ Used by all scripts in project
         ↓
┌─────────────────────────────────────────────────────────────────┐
│              LOCAL DEBUG FLAGS (Per Script)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Script File              │ Local Flag              │ Default    │
│  ─────────────────────────┼────────────────────────┼────────    │
│  option.gd                │ DEBUG_ENABLED          │ false      │
│  power_off_dialog.gd      │ DEBUG_ENABLED          │ false      │
│  drills_network.gd        │ DEBUG_ENABLED          │ false      │
│  drill_network_ui.gd      │ DEBUG_DISABLED          │ false      │
│  bootcamp.gd              │ DEBUG_DISABLED          │ false      │
│  drills.gd                │ DEBUG_DISABLED          │ false      │
│  (+ 18 more files)        │ DEBUG_DISABLED/ENABLED  │ false      │
│                                                                   │
│  Total: 24 files, 1893 print statements guarded                │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Flow

### Production Mode (Current State ✅)

```
Application Starts
         ↓
GlobalDebug Loaded (DEBUG_DISABLED = true)
         ↓
┌─ Script Executes ─┐
│                   │
│ if DEBUG_ENABLED: │  ← Local flag = false
│   print(...)      │
│                   │ Condition FALSE
└─────────┬─────────┘
          ↓
      PRINT SKIPPED ✅ (Silent execution)
          ↓
┌─ Another Script ──┐
│                   │
│ if DEBUG_DISABLED: │  ← Local flag = false
│   print(...)      │
│                   │ Condition FALSE
└─────────┬─────────┘
          ↓
      PRINT SKIPPED ✅ (Silent execution)
          ↓
    Production OK ✅
    (No debug output in logs)
```

### Development Mode (Runtime Enabled)

```
Application Starts
         ↓
GlobalDebug Loaded (DEBUG_DISABLED = true)
         ↓
Developer runs: GlobalDebug.set_debug_enabled(true)
         ↓
GlobalDebug.DEBUG_DISABLED = false ← Changed
GlobalDebug.debug_enabled = true   ← Changed
         ↓
┌─ Script Executes ─┐
│                   │
│ if DEBUG_ENABLED: │  ← Still false (local)
│   print(...)      │
│                   │ Condition still FALSE
└─────────┬─────────┘
          ↓
      PRINT SKIPPED (local flag not affected)
          ↓
┌─ Alternative usage ──┐
│                      │
│ if not GlobalDebug   │
│   .DEBUG_DISABLED:   │  ← Now false (global)
│   print(...)         │
│                      │ Condition TRUE
└──────────┬───────────┘
           ↓
       PRINT SHOWS ✅ (Debug output visible)
           ↓
   Development OK ✅
   (Full debug output in logs)
```

## Control Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│           GLOBAL CONTROL LEVEL (Highest Priority)           │
│                  GlobalDebug Singleton                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Controls ALL instances using: not GlobalDebug.        │  │
│  │ DEBUG_DISABLED or GlobalDebug.debug_enabled           │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          ↑ (Can override local flags)
          │
┌─────────────────────────────────────────────────────────────┐
│         LOCAL CONTROL LEVEL (Per-Script)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ const DEBUG_ENABLED = false (independent)             │  │
│  │ const DEBUG_DISABLED = false (independent)             │  │
│  │                                                        │  │
│  │ Controls ONLY that specific script's prints           │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          ↓ (Used by single script)
          │
┌─────────────────────────────────────────────────────────────┐
│              OUTPUT LEVEL                                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ print(...) statements in script code                 │  │
│  │ Only executes if conditions above allow              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Debug Guard Patterns

### Pattern 1: Local Flag (Used by most scripts)
```gdscript
const DEBUG_ENABLED = false

func _ready():
    if DEBUG_ENABLED:
        print("Only prints if this script's local flag is true")
```
**Independence Level:** HIGH (not affected by global changes)

### Pattern 2: Global Flag
```gdscript
func _ready():
    if not GlobalDebug.DEBUG_DISABLED:
        print("Prints when GlobalDebug.DEBUG_DISABLED is false")
```
**Independence Level:** LOW (respects global control)

### Pattern 3: Alternative Global Flag
```gdscript
const DEBUG_DISABLED = false

func _ready():
    if DEBUG_DISABLED:
        print("Alternative local flag")
```
**Independence Level:** HIGH (local override)

## State Machine

```
                    ┌──────────────────┐
                    │  DISABLED STATE   │
                    │   (Production)    │
                    │  DEBUG_DISABLED   │
                    │    = true         │
                    │  debug_enabled    │
                    │    = false        │
                    └────────┬──────────┘
                             │
                 Call: set_debug_enabled(true)
                             │
                             ↓
                    ┌──────────────────┐
                    │  ENABLED STATE   │
                    │ (Development)    │
                    │  DEBUG_DISABLED  │
                    │    = false       │
                    │  debug_enabled   │
                    │    = true        │
                    └────────┬──────────┘
                             │
                 Call: set_debug_enabled(false)
                             │
                             ↓
                    ┌──────────────────┐
                    │  Back to DISABLED │
                    │  (Production)    │
                    └──────────────────┘
```

## Files Involved

```
project.godot
    ├─ [autoload] section
    │  └─ GlobalDebug="*res://script/GlobalDebug.gd" ← ADDED
    │
script/GlobalDebug.gd ← NEW FILE (Central Control)
    ├─ Properties: DEBUG_DISABLED, debug_enabled, DEBUG_DISABLED
    └─ Methods: set_debug_enabled(), is_debug_enabled(), get_debug_status()
    
Scene and Script Files (24 total)
    ├─ Local flags: DEBUG_ENABLED or DEBUG_DISABLED (all false)
    ├─ if guards: if DEBUG_ENABLED: print(...)
    ├─ Global access: if not GlobalDebug.DEBUG_DISABLED: print(...)
    └─ All 1893 prints guarded with conditionals
```

## Production Release Flow

```
Start Development
    ↓
Code & Test with DEBUG_ENABLED = true (locally)
    ↓
Prepare for Release
    ↓
Set all DEBUG_ENABLED = false ✅
Set all DEBUG_DISABLED = false ✅
Set GlobalDebug.DEBUG_DISABLED = true ✅
    ↓
Run Release Build Tests
    ↓
Verify NO debug output in logs ✅
    ↓
Build for Production ✅
    ↓
Deploy
    ↓
✅ Silent, efficient production application
```

## Runtime Enable/Disable Flow

```
Godot Console / Runtime Code:

                 Developer Actions
                        ↓
        ┌───────────────────────────────┐
        │ GlobalDebug.set_debug_enabled │
        │        (true/false)           │
        └───────────┬───────────────────┘
                    ↓
        ┌───────────────────────────────┐
        │ GlobalDebug.DEBUG_DISABLED    │
        │ GlobalDebug.debug_enabled     │
        │ Updated accordingly           │
        └───────────┬───────────────────┘
                    ↓
        ┌───────────────────────────────┐
        │ All guarded prints now respect │
        │ new global setting            │
        └───────────┬───────────────────┘
                    ↓
        Immediate effect (no restart needed)
```

---

**Legend:**
- ✅ = Production Ready / Correct State
- 📦 = Component/Module
- 🔄 = Process/Flow
- 🎯 = Action/Decision
