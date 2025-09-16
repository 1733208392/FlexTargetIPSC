# PERFORMANCE TRACKING MISMATCH ANALYSIS

## WebSocket Bullets Sent: 9
```
{"t":630,"x":134,"y":238.2,"a":1069}   -> (360.0, 640.0)
{"t":630,"x":200,"y":100,"a":1069}     -> (537.3, 1011.3) 
{"t":630,"x":10,"y":10,"a":1069}       -> (26.9, 1253.1)
{"t":630,"x":300,"y":200,"a":1069}     -> (806.0, 742.6)
{"t":630,"x":10,"y":10,"a":1069}       -> (26.9, 1253.1) [DUPLICATE]
{"t":630,"x":300,"y":200,"a":1069}     -> (806.0, 742.6) [DUPLICATE] 
{"t":630,"x":100,"y":200,"a":1069}     -> (268.7, 742.6)
{"t":630,"x":134,"y":238.2,"a":1069}   -> (360.0, 640.0) [DUPLICATE]
{"t":630,"x":200,"y":300,"a":1069}     -> (537.3, 474.0)
```

## Performance Records: 12
Analysis of performance_5.json shows double recording:

### Pattern 1: Hit + Miss for same position
- **(537.3, 1011.3)**: Popper hit (5 pts) + Miss (1 pt) 
- **(268.7, 742.6)**: Popper hit (5 pts) + Miss (1 pt)
- **(537.3, 474.0)**: Popper hit (5 pts) + Miss (1 pt)

### Pattern 2: Multiple misses for same position  
- **(360.0, 640.0)**: Two separate Miss records (1 pt each)

## Root Cause
The miss detection system in 2poppers.gd was creating **race conditions**:

1. **Individual popper** processes WebSocket bullet and emits hit signal
2. **2poppers miss detection** also processes the same bullet independently  
3. **Both systems** record the same bullet, creating duplicates

## Current Fix Applied
- ✅ **Removed WebSocket connection from 2poppers.gd**
- ✅ **Removed complex miss detection logic**  
- ✅ **Simplified to let individual poppers handle all WebSocket processing**

## Outstanding Issue
- ❌ **No miss detection** - bullets that miss both poppers won't be recorded
- ❌ **Miss score showing as 1 instead of 0** (secondary issue)

## Next Steps Required
Need to implement clean miss detection at the **drills level** for 2poppers target type only.