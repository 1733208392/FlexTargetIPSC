# Circular Buffer Test Verification

Here's how the circular buffer logic works in the performance tracker:

## Current Implementation:

1. **File Naming**: Files are now named `performance_1.json` to `performance_30.json`

2. **Circular Logic**: 
   ```gdscript
   var next_index = (current_index % 30) + 1
   var data_id = "performance_" + str(next_index)
   ```

3. **Test Cases**:
   - current_index: 0 -> next_index: 1 -> file: performance_1.json
   - current_index: 1 -> next_index: 2 -> file: performance_2.json
   - current_index: 29 -> next_index: 30 -> file: performance_30.json
   - current_index: 30 -> next_index: 1 -> file: performance_1.json (WRAPS AROUND)
   - current_index: 31 -> next_index: 2 -> file: performance_2.json
   - current_index: 60 -> next_index: 1 -> file: performance_1.json

## Sequence for 35 drills:
1. performance_1.json
2. performance_2.json
...
29. performance_29.json
30. performance_30.json
31. performance_1.json (overwrites the first file)
32. performance_2.json (overwrites the second file)
33. performance_3.json
...

This ensures that only the latest 30 drills are kept, with older drills being overwritten in a circular fashion.

## History System Updates:
- Updated to load files with "performance_" prefix
- Checks all possible files performance_1 to performance_30
- Extracts drill numbers correctly from new file naming scheme

The implementation successfully creates a circular buffer that maintains only the latest 30 drill records.