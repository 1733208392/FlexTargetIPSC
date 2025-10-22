# Target Sequence Randomization Feature

## Overview
Added randomization capability to the IPSC drill target sequence to increase training variety and unpredictability.

## Implementation Details

### Key Components

1. **Base Sequence**: `base_target_sequence` contains the original fixed sequence
2. **Active Sequence**: `target_sequence` contains the actual sequence used (may be randomized)
3. **Control Variable**: `randomize_sequence` (exported) enables/disables randomization

### Target Types in Sequence
- `ipsc_mini` - Standard IPSC target
- `ipsc_mini_black_1` - Black IPSC variant 1  
- `ipsc_mini_black_2` - Black IPSC variant 2
- `hostage` - Hostage scenario target
- `2poppers` - Two popper targets
- `3paddles` - Three paddle targets
- `ipsc_mini_rotate` - Rotating IPSC target

### Randomization Algorithm
Uses Fisher-Yates shuffle algorithm for true randomness:
- Ensures each permutation has equal probability
- Maintains all original targets (no duplicates or missing targets)
- Preserves target count and types

### When Randomization Occurs
- Initial drill start (in `_ready()`)
- Every drill restart (manual or automatic)
- When randomization setting is changed

### Usage

#### Enable/Disable Randomization
```gdscript
# In editor: Set "Randomize Sequence" property to true/false
# In code:
drills_manager.set_randomization(true)   # Enable
drills_manager.set_randomization(false)  # Disable
drills_manager.toggle_randomization()    # Toggle current state
```

#### Debug Information
Set `DEBUG_DISABLED = true` in `drills.gd` to see:
- Original vs randomized sequences
- Randomization enable/disable events
- Current sequence for each drill run

## Benefits

1. **Training Variety**: Prevents muscle memory of fixed sequence
2. **Realistic Practice**: Simulates unpredictable competition scenarios  
3. **Mental Agility**: Requires adaptation and quick target assessment
4. **Balanced Training**: All target types still appear exactly once per drill

## Backward Compatibility

- Feature is enabled by default but can be disabled
- All existing drill logic unchanged
- Performance impact is minimal (only during drill initialization)
- Maintains same drill completion criteria and scoring